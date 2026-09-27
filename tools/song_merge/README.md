# song_merge — scalanie tekstów pieśni z trzech źródeł

> **In English:** a one-off tool that merged the song texts from three sources (the database in the old iOS app's
> repository, the old iOS app's database from a real device and the old Android app's JSON), with a Markdown file
> per differing song where the right version was chosen by hand. Its output became `assets/songs_data.json`.
> It stays in Polish on purpose: the decision files it reads have Polish section headers (`## DECYZJA`,
> `## MANUAL-TREŚĆ`), which are part of the data format, and the job is done. Run it again only to rebuild
> the song data.

## Wejście

Katalog źródeł (`--src`) musi zawierać:

- `ios-device.sqlite` **razem z `ios-device.sqlite-wal` i `ios-device.sqlite-shm`, jeśli istnieją**,
- `ios-repo.sqlite`,
- `android.json`.

Bez `ios-device.sqlite` skrypty odmawiają działania. Źródła są tylko czytane: bazy SQLite są kopiowane do
katalogu tymczasowego i dopiero kopia jest otwierana, a sumy kontrolne oryginałów są sprawdzane przed
odczytem i po nim.

Baza z urządzenia zawiera dane użytkownika (ulubione). Katalog roboczy najlepiej trzymać poza repozytorium.

## Kroki

```sh
cd tools/song_merge

# 1–3: REPORT.md, diffs/NNNN.md, DECISIONS.md
python3 compare.py --src ~/song_merge_work

# decyzje wpisujesz w diffs/NNNN.md, potem kopiujesz je do kolumny w DECISIONS.md:
python3 build_songs.py --work ~/song_merge_work --sync-index

# 4: assets/songs_data_v2.json
python3 build_songs.py --work ~/song_merge_work --data-version 2 --no-device
```

`compare.py` nie nadpisze istniejących `DECISIONS.md` ani `diffs/` bez `--force`.

## Decyzje

W każdym `diffs/NNNN.md`:

```
## DECYZJA
tytuł: ios-device | ios-repo | android | manual
treść: ios-device | ios-repo | android | manual
uwagi:

## MANUAL-TYTUŁ
(wypełnij tylko gdy tytuł: manual)

## MANUAL-TREŚĆ
(wypełnij tylko gdy treść: manual)
```

Tekst w `MANUAL-TREŚĆ` można objąć blokiem ` ``` `, wtedy jest brany dokładnie tak, jak jest zapisany.
Bez bloku usuwane są puste linie na początku i końcu oraz białe znaki na samym końcu tekstu.

Automatycznie wypełniane są tylko pieśni różniące się wyłącznie białymi znakami lub końcami linii
(`auto-whitespace`, decyzja `ios-device`). Wszystkie pozostałe decyzje są puste.

## Poprawki redakcyjne

`corrections.json` (w repozytorium) to błędy wspólne dla wszystkich źródeł, których nie rozstrzygnie wybór
źródła w `diffs/`, np. niesparowane znaki powtórzenia (#30). Każda poprawka to
`{"number", "from", "to", "why"}`; fragment `from` musi wystąpić w treści tej pieśni dokładnie raz, inaczej
skrypt przerywa działanie. Poprawki nakładane są na gotowy wynik, przed walidacją. Po zmianie tego pliku
przebuduj asset z podbitym `--data-version`.

## Wynik

`assets/songs_data_v2.json`: `{"dataVersion": N, "songs": [{"number", "title", "content"}]}`.
Skrypt nigdy nie zapisuje do `songs_data.json`.

Skrypt przerywa działanie i wypisuje numery pieśni, jeśli tytuł lub treść zawiera niewidoczne znaki
z kategorii Unicode Cc, Cf, Zl lub Zp (np. `U+2028`, `U+2029`, `\r`, `\t`, `U+200B`, `U+FEFF`).
Dozwolone są `\n` i `U+00AD` SOFT HYPHEN.

## Testy

```sh
cd tools/song_merge
python3 -m unittest test_build_songs.py
```

Każda zmiana tekstów w tym pliku wymaga podbicia `--data-version`, bo to ta liczba wyzwala nadpisanie
tekstów u użytkowników. Przy nadpisywaniu pliku z inną treścią i niepodbitą wersją skrypt wypisze
ostrzeżenie.
