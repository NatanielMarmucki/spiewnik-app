#!/usr/bin/env python3
"""Buduje assets/songs_data_v2.json na podstawie decyzji z diffs/NNNN.md.

Źródłem decyzji są sekcje `## DECYZJA`, `## MANUAL-TYTUŁ`, `## MANUAL-TREŚĆ`
w plikach diffs/NNNN.md. DECISIONS.md jest indeksem: jego kolumna „decyzja”
musi zgadzać się z plikami, a zestaw wierszy — z plikami i z aktualnym
porównaniem źródeł.

Skrypt odmawia działania, gdy:
  - brakuje którejkolwiek decyzji (wypisuje numery),
  - indeks i pliki się rozjeżdżają,
  - źródła zmieniły się od porównania (inny zestaw pieśni do decyzji),
  - wynik nie przechodzi walidacji (2000 pozycji, numery 1–2000, niepuste pola,
    brak niewidocznych znaków sterujących w tytułach i treściach).

Użycie:
    python3 build_songs.py --work KATALOG [--src KATALOG] [--out PLIK] [--data-version N]
    python3 build_songs.py --work KATALOG --sync-index   # przepisuje kolumnę decyzji z plików
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
import unicodedata
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import songsrc
from songsrc import (
    DECISION_HEADER,
    EXPECTED_COUNT,
    MANUAL_CONTENT_HEADER,
    MANUAL_CONTENT_PLACEHOLDER,
    MANUAL_TITLE_HEADER,
    MANUAL_TITLE_PLACEHOLDER,
    SongComparison,
    SourceError,
    compare_sources,
    diff_filename,
    load_sources,
    render_index_decision,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPO_ROOT / "assets" / "songs_data_v2.json"
PROTECTED_OUTPUT_NAMES = {"songs_data.json"}


class BuildError(Exception):
    pass


@dataclass
class Decision:
    number: int
    title: str  # "" gdy brak
    content: str
    manual_title: str
    manual_content: str


# --- DECISIONS.md -------------------------------------------------------------

def parse_index(path: Path) -> Dict[int, Tuple[str, str, int]]:
    """numer -> (komórka decyzji, komórka pliku diffa, numer linii)."""
    if not path.is_file():
        raise BuildError(f"Brak pliku {path}")
    rows: Dict[int, Tuple[str, str, int]] = {}
    duplicates = []
    for line_no, line in enumerate(path.read_text(encoding="utf-8").split("\n"), start=1):
        if not re.match(r"^\|\s*\d+\s*\|", line):
            continue
        cells = [c.strip() for c in re.split(r"(?<!\\)\|", line.strip())[1:-1]]
        if len(cells) != 5:
            raise BuildError(f"{path}:{line_no}: wiersz ma {len(cells)} kolumn zamiast 5")
        number = int(cells[0])
        if number in rows:
            duplicates.append(number)
        rows[number] = (cells[4], cells[3], line_no)
    if duplicates:
        raise BuildError(f"{path}: zduplikowane wiersze dla numerów {sorted(set(duplicates))}")
    return rows


def sync_index(path: Path, decisions: Dict[int, Decision]) -> List[int]:
    lines = path.read_text(encoding="utf-8").split("\n")
    changed = []
    for i, line in enumerate(lines):
        if not re.match(r"^\|\s*\d+\s*\|", line):
            continue
        parts = re.split(r"(?<!\\)\|", line)
        number = int(parts[1].strip())
        if number not in decisions:
            continue
        decision = decisions[number]
        expected = render_index_decision(decision.title, decision.content)
        if parts[5].strip() != expected:
            parts[5] = f" {expected} " if expected else " "
            lines[i] = "|".join(parts)
            changed.append(number)
    path.write_text("\n".join(lines), encoding="utf-8")
    return changed


# --- diffs/NNNN.md ------------------------------------------------------------

_HEADERS_RE = re.compile(
    r"^(" + "|".join(re.escape(h) for h in (DECISION_HEADER, MANUAL_TITLE_HEADER, MANUAL_CONTENT_HEADER)) + r")[ \t]*$",
    re.M,
)


def _manual_body(body: str, placeholder: str) -> str:
    lines = [line for line in body.split("\n") if line.strip() != placeholder]
    text = "\n".join(lines).strip("\n")
    fenced = re.fullmatch(r"(`{3,})[^\n]*\n(.*)\n\1[ \t]*", text, re.S)
    if fenced:
        return fenced.group(2)
    return text.rstrip()


def parse_decision_file(path: Path, number: int) -> Decision:
    text = path.read_text(encoding="utf-8")
    matches = list(re.finditer(rf"^{re.escape(DECISION_HEADER)}[ \t]*$", text, re.M))
    if not matches:
        raise BuildError(f"{path}: brak sekcji '{DECISION_HEADER}'")
    tail = text[matches[-1].start():]
    parts = _HEADERS_RE.split(tail)
    sections: Dict[str, List[str]] = {}
    for header, body in zip(parts[1::2], parts[2::2]):
        sections.setdefault(header, []).append(body)
    for header in (DECISION_HEADER, MANUAL_TITLE_HEADER, MANUAL_CONTENT_HEADER):
        count = len(sections.get(header, []))
        if count != 1:
            raise BuildError(f"{path}: sekcja '{header}' występuje {count}× (oczekiwano 1× po ostatnim '{DECISION_HEADER}')")

    values: Dict[str, str] = {}
    for label, keys in (("tytuł", ("tytuł", "tytul")), ("treść", ("treść", "tresc"))):
        found = re.findall(
            rf"^(?:{'|'.join(keys)})[ \t]*:[ \t]*(.*?)[ \t]*$", sections[DECISION_HEADER][0], re.M | re.I
        )
        if len(found) != 1:
            raise BuildError(f"{path}: w '{DECISION_HEADER}' linia '{label}:' występuje {len(found)}× (oczekiwano 1×)")
        value = found[0].strip().lower()
        if value in ("", "?"):
            value = ""
        elif value not in songsrc.DECISION_VALUES:
            raise BuildError(
                f"{path}: niedozwolona wartość '{label}: {found[0]}' — dozwolone: {' | '.join(songsrc.DECISION_VALUES)}"
            )
        values[label] = value

    manual_title = _manual_body(sections[MANUAL_TITLE_HEADER][0], MANUAL_TITLE_PLACEHOLDER)
    manual_content = _manual_body(sections[MANUAL_CONTENT_HEADER][0], MANUAL_CONTENT_PLACEHOLDER)
    return Decision(number, values["tytuł"], values["treść"], manual_title, manual_content)


# --- Budowanie ----------------------------------------------------------------

def check_consistency(needs: Dict[int, SongComparison], index: Dict[int, Tuple[str, str, int]],
                      diffs_dir: Path) -> List[str]:
    errors = []
    files = {int(p.stem): p for p in diffs_dir.glob("[0-9][0-9][0-9][0-9].md")} if diffs_dir.is_dir() else {}
    need_set, index_set, file_set = set(needs), set(index), set(files)

    def listing(numbers) -> str:
        return ", ".join(map(str, sorted(numbers)))

    if need_set - index_set:
        errors.append(f"Źródła wymagają decyzji, a brak wierszy w DECISIONS.md: {listing(need_set - index_set)}"
                      " (źródła zmieniły się od porównania?)")
    if index_set - need_set:
        errors.append(f"Wiersze w DECISIONS.md dla pieśni, które w źródłach już się nie różnią: {listing(index_set - need_set)}"
                      " (źródła zmieniły się od porównania?)")
    if index_set - file_set:
        errors.append(f"Wiersze w DECISIONS.md bez pliku w diffs/: {listing(index_set - file_set)}")
    if file_set - index_set:
        errors.append(f"Pliki w diffs/ bez wiersza w DECISIONS.md: {listing(file_set - index_set)}")
    for number, (_, link_cell, line_no) in sorted(index.items()):
        expected = f"diffs/{diff_filename(number)}"
        if expected not in link_cell:
            errors.append(f"DECISIONS.md:{line_no}: nr {number} wskazuje '{link_cell}', oczekiwano '{expected}'")
    return errors


def resolve_field(song: SongComparison, decision: Decision, field_name: str) -> Tuple[Optional[str], Optional[str]]:
    """Zwraca (wartość, błąd)."""
    choice = decision.title if field_name == "title" else decision.content
    label = "tytuł" if field_name == "title" else "treść"
    manual = decision.manual_title if field_name == "title" else decision.manual_content
    if choice == "manual":
        return manual, None
    items = song.entries.get(choice, [])
    if len(items) != 1:
        state = "brak pieśni" if not items else f"{len(items)} wpisy (duplikat)"
        return None, f"nr {song.number}: {label}: {choice} — w tym źródle {state}; wybierz inne źródło albo manual"
    return getattr(items[0], field_name), None


# Kategorie Unicode odrzucane w tytułach i treściach: Cc (znaki sterujące, np. \r, \t, NUL),
# Cf (znaki formatujące, np. U+200B ZERO WIDTH SPACE, U+FEFF BOM, znaczniki kierunku tekstu),
# Zl (U+2028 LINE SEPARATOR) i Zp (U+2029 PARAGRAPH SEPARATOR). Są niewidoczne, psują wyszukiwanie
# i dzielenie tekstu, a w polskich tekstach pieśni nie mają zastosowania.
FORBIDDEN_CATEGORIES = ("Cc", "Cf", "Zl", "Zp")
# Wyjątki: \n dzieli zwrotki; U+00AD SOFT HYPHEN to typograficzna wskazówka podziału wyrazu
# (występuje w zatwierdzonych danych, pieśń 118). Zwykła spacja i pozostałe Zs nie należą
# do odrzucanych kategorii.
ALLOWED_CHARACTERS = frozenset({"\n", "­"})


# --- corrections.json ---------------------------------------------------------

CORRECTIONS_PATH = Path(__file__).resolve().parent / "corrections.json"


def apply_corrections(songs: List[Dict[str, object]], corrections: List[Dict[str, object]]) -> List[str]:
    """Nakłada poprawki redakcyjne na gotowe pieśni, w miejscu. Poprawka to `{"number", "from", "to", "why"}`:
    fragment `from` musi wystąpić w treści tej pieśni dokładnie raz. Zwraca listę błędów (pusta = wszystko
    nałożone). Poprawki dotyczą błędów wspólnych dla wszystkich źródeł, których nie da się rozstrzygnąć
    decyzją w diffs/ (np. niesparowane znaki powtórzenia, #30)."""
    by_number = {song["number"]: song for song in songs}
    errors = []
    for fix in corrections:
        song = by_number.get(fix["number"])
        if song is None:
            errors.append(f"nr {fix['number']}: nie ma takiej pieśni")
            continue
        occurrences = song["content"].count(fix["from"])
        if occurrences != 1:
            errors.append(f"nr {fix['number']}: fragment {fix['from']!r} występuje {occurrences} razy, oczekiwano 1")
            continue
        song["content"] = song["content"].replace(fix["from"], fix["to"])
    return errors


def forbidden_characters(text: str) -> Counter:
    return Counter(
        ch for ch in text
        if ch not in ALLOWED_CHARACTERS and unicodedata.category(ch) in FORBIDDEN_CATEGORIES
    )


def validate_output(songs: List[Dict[str, object]]) -> List[str]:
    errors = []
    if len(songs) != EXPECTED_COUNT:
        errors.append(f"liczba pozycji: {len(songs)}, oczekiwano {EXPECTED_COUNT}")
    numbers = [s["number"] for s in songs]
    duplicates = sorted(n for n, c in Counter(numbers).items() if c > 1)
    if duplicates:
        errors.append(f"zduplikowane numery: {duplicates}")
    expected = set(range(1, EXPECTED_COUNT + 1))
    missing = sorted(expected - set(numbers))
    extra = sorted(set(numbers) - expected)
    if missing:
        errors.append(f"brakujące numery: {missing}")
    if extra:
        errors.append(f"numery spoza 1–{EXPECTED_COUNT}: {extra}")
    for song in songs:
        for name in ("title", "content"):
            value = song[name]
            if not isinstance(value, str) or not value.strip():
                errors.append(f"nr {song['number']}: pole '{name}' jest puste lub nie jest tekstem")

    offending: Dict[object, List[str]] = {}
    for song in songs:
        for name in ("title", "content"):
            value = song[name]
            if not isinstance(value, str):
                continue
            counts = forbidden_characters(value)
            if counts:
                details = ", ".join(
                    f"U+{ord(ch):04X} {unicodedata.name(ch, '<control>')} ×{count}"
                    for ch, count in sorted(counts.items())
                )
                offending.setdefault(song["number"], []).append(f"{name}: {details}")
    if offending:
        errors.append(
            f"niewidoczne znaki sterujące w {len(offending)} pieśniach: "
            + ", ".join(str(number) for number in offending)
        )
        errors += [f"nr {number}: {'; '.join(fields)}" for number, fields in offending.items()]
    return errors


def write_json_atomic(path: Path, payload: Dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    fd, tmp = tempfile.mkstemp(prefix=path.name, dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(data)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--work", type=Path, default=Path.cwd(), help="katalog z DECISIONS.md i diffs/")
    parser.add_argument("--src", type=Path, default=None, help="katalog ze źródłami (domyślnie = --work)")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT, help=f"plik wynikowy (domyślnie {DEFAULT_OUTPUT})")
    parser.add_argument("--data-version", type=int, default=1, help="wartość dataVersion (domyślnie 1)")
    parser.add_argument("--sync-index", action="store_true",
                        help="przepisz kolumnę „decyzja” w DECISIONS.md z plików diffs/ i zakończ")
    parser.add_argument("--corrections", type=Path, default=CORRECTIONS_PATH,
                        help=f"poprawki redakcyjne nakładane na wynik (domyślnie {CORRECTIONS_PATH.name})")
    parser.add_argument("--no-device", action="store_true",
                        help="tryb bez ios-device.sqlite (musi zgadzać się z trybem compare.py)")
    args = parser.parse_args()
    songsrc.configure(with_device=not args.no_device)

    work = args.work.resolve()
    src = (args.src or args.work).resolve()
    out = args.out.resolve()
    diffs_dir = work / "diffs"
    index_path = work / "DECISIONS.md"

    try:
        if out.name in PROTECTED_OUTPUT_NAMES:
            raise BuildError(f"Odmowa zapisu do {out}: ten plik podmienia się ręcznie, osobnym commitem.")
        if args.data_version < 1:
            raise BuildError("--data-version musi być ≥ 1")

        if index_path.is_file():
            recorded = re.search(r"^Tryb porównania: .*$", index_path.read_text(encoding="utf-8"), re.M)
            if not recorded or recorded.group(0).strip() != songsrc.mode_line():
                raise BuildError(
                    f"Tryb nie zgadza się z DECISIONS.md: w pliku "
                    f"'{recorded.group(0).strip() if recorded else '(brak)'}', teraz '{songsrc.mode_line()}'. "
                    "Uruchom z tym samym --no-device co compare.py."
                )

        sources = load_sources(src)
        comparison = compare_sources(sources)
        needs = {n: s for n, s in comparison.items() if s.needs_decision}
        index = parse_index(index_path)

        errors = check_consistency(needs, index, diffs_dir)
        if errors:
            raise BuildError("Indeks, pliki diffów i źródła się rozjeżdżają:\n  - " + "\n  - ".join(errors))

        decisions: Dict[int, Decision] = {}
        parse_errors = []
        for number in sorted(needs):
            try:
                decisions[number] = parse_decision_file(diffs_dir / diff_filename(number), number)
            except BuildError as exc:
                parse_errors.append(str(exc))
        if parse_errors:
            raise BuildError("Błędy w plikach decyzji:\n  - " + "\n  - ".join(parse_errors))

        if args.sync_index:
            changed = sync_index(index_path, decisions)
            print(f"Zaktualizowano kolumnę „decyzja” w {len(changed)} wierszach"
                  + (f": {', '.join(map(str, changed))}" if changed else "."))
            return 0

        incomplete = [n for n, d in decisions.items() if not d.title or not d.content]
        if incomplete:
            detail = []
            for n in incomplete:
                missing = [label for label, value in (("tytuł", decisions[n].title), ("treść", decisions[n].content)) if not value]
                detail.append(f"{n} ({', '.join(missing)})")
            raise BuildError(
                f"Brak decyzji dla {len(incomplete)} pieśni: " + ", ".join(detail)
            )

        manual_errors = []
        warnings = []
        for number, d in decisions.items():
            for label, choice, body in (("tytuł", d.title, d.manual_title), ("treść", d.content, d.manual_content)):
                section = MANUAL_TITLE_HEADER if label == "tytuł" else MANUAL_CONTENT_HEADER
                if choice == "manual" and not body.strip():
                    manual_errors.append(f"nr {number}: {label}: manual, ale sekcja '{section}' jest pusta")
                if choice != "manual" and body.strip():
                    manual_errors.append(f"nr {number}: {label}: {choice}, ale sekcja '{section}' jest wypełniona")
            if d.title == "manual" and "\n" in d.manual_title.strip():
                manual_errors.append(f"nr {number}: tytuł manual zawiera kilka linii")
            if d.content == "manual" and re.search(r"[ \t]+$|\r", d.manual_content, re.M):
                warnings.append(f"nr {number}: treść manual zawiera spacje na końcach linii lub \\r")
        if manual_errors:
            raise BuildError("Błędy w sekcjach MANUAL:\n  - " + "\n  - ".join(manual_errors))

        mismatches = []
        for number, d in decisions.items():
            expected = render_index_decision(d.title, d.content)
            cell, _, line_no = index[number]
            if " ".join(cell.split()) != expected:
                mismatches.append(f"DECISIONS.md:{line_no} nr {number}: w tabeli '{cell}', w pliku '{expected}'")
        if mismatches:
            raise BuildError(
                "Kolumna „decyzja” w DECISIONS.md nie zgadza się z plikami diffs/:\n  - "
                + "\n  - ".join(mismatches)
                + "\nPopraw ręcznie albo uruchom z --sync-index."
            )

        result: List[Dict[str, object]] = []
        stats = {"tytuł": Counter(), "treść": Counter()}
        resolve_errors = []
        for number in sorted(comparison):
            song = comparison[number]
            if number not in decisions:
                title, content = song.value(songsrc.BASE, "title"), song.value(songsrc.BASE, "content")
                stats["tytuł"]["identyczne (bez decyzji)"] += 1
                stats["treść"]["identyczne (bez decyzji)"] += 1
            else:
                d = decisions[number]
                title, error_t = resolve_field(song, d, "title")
                content, error_c = resolve_field(song, d, "content")
                resolve_errors += [e for e in (error_t, error_c) if e]
                auto = " (auto-whitespace)" if song.auto_whitespace else ""
                stats["tytuł"][d.title + auto] += 1
                stats["treść"][d.content + auto] += 1
            result.append({"number": number, "title": title, "content": content})
        if resolve_errors:
            raise BuildError("Nie da się pobrać wartości ze wskazanych źródeł:\n  - " + "\n  - ".join(resolve_errors))

        corrections = json.loads(args.corrections.read_text(encoding="utf-8"))
        correction_errors = apply_corrections(result, corrections)
        if correction_errors:
            raise BuildError("Nie da się nałożyć poprawek z corrections.json:\n  - " + "\n  - ".join(correction_errors))

        validation = validate_output(result)
        if validation:
            raise BuildError("Walidacja wyniku nie przeszła:\n  - " + "\n  - ".join(validation))

        if out.exists():
            try:
                previous = json.loads(out.read_text(encoding="utf-8"))
                if previous.get("songs") != result and isinstance(previous.get("dataVersion"), int) \
                        and previous["dataVersion"] >= args.data_version:
                    warnings.append(
                        f"{out.name} już istnieje z dataVersion={previous['dataVersion']} i inną treścią, "
                        f"a zapisujesz dataVersion={args.data_version}. Jeśli ta wersja trafiła już do użytkowników, "
                        "zmiana bez podbicia dataVersion nie nadpisze u nich tekstów."
                    )
            except (json.JSONDecodeError, AttributeError):
                warnings.append(f"{out} istnieje i nie jest poprawnym JSON-em — zostanie nadpisany")

        write_json_atomic(out, {"dataVersion": args.data_version, "songs": result})
    except (BuildError, SourceError) as exc:
        print(f"BŁĄD: {exc}", file=sys.stderr)
        return 2

    print(f"Zapisano {out} (dataVersion={args.data_version}, pieśni: {len(result)})")
    print(f"Poprawki z corrections.json: {len(corrections)}")
    print(f"Z decyzją: {len(decisions)} (auto-whitespace: {sum(1 for n in decisions if comparison[n].auto_whitespace)})")
    mixed = sum(1 for d in decisions.values() if d.title != d.content)
    print(f"Tytuł i treść z różnych źródeł: {mixed}")
    for label in ("tytuł", "treść"):
        print(f"{label.capitalize()}:")
        for key, count in sorted(stats[label].items(), key=lambda kv: (-kv[1], kv[0])):
            print(f"  {key}: {count}")
    for warning in warnings:
        print(f"UWAGA: {warning}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
