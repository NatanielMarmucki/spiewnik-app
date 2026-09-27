# Śpiewnik — instrukcja dla agentów

Aplikacja Flutter (3.47.4) na iOS i Androida, bez backendu. 2000 pieśni z `assets/songs_data.json` w ObjectBoksie,
ulubione jako pole `Song.favorite`, własne pieśni (`MySong`), ustawienia w SharedPreferences.
Wersja 12.0.0 wychodzi jako aktualizacja starej aplikacji iOS (Swift, Core Data) i aplikacji ze sklepu Play.
UI po polsku; kod, komentarze, commity i opisy PR po angielsku.

## Gdzie co leży

- `lib/main.dart` — start: store → asset pieśni → migracja z iOS → migracja ustawień → `runApp`.
  **Kolejność ma znaczenie:** migracja dopasowuje ulubione po numerze, więc pieśni muszą być już w bazie.
- `lib/model/` — encje ObjectBoksa (`Song`, `MySong`), `FontSizeModel`, `ReviewModel`, `polish_collation.dart`
  (polska kolejność liter i usuwanie ogonków do wyszukiwania). Po zmianie encji: `dart run build_runner build`.
- `lib/json_manager.dart` — parsowanie assetu (`SongsData`), aktualizacja pieśni z zachowaniem ulubionych, `dataVersion`.
- `lib/migration/` — jednorazowe migracje ze starej aplikacji iOS: czytnik bazy Core Data i zapis do ObjectBoksa,
  osobno rozmiar czcionki przez kanał platformy z `ios/Runner/AppDelegate.swift`. **Migracja jest skończona i przetestowana
  end-to-end** — nie zmieniaj jej bez ponownego testu (procedura w `docs/DEVELOPMENT.md`).
- `assets/data/kategorie.json` + `lib/model/song_categories.dart` — spis treści śpiewnika (4 kategorie, 24 podkategorie),
  trzymany w pamięci, nie w bazie; filtr w `SongViewModel`.
- Listy pieśni: encje `Playlist`/`PlaylistItem` (`lib/model/playlist_model.dart`), `PlaylistRepository`, `PlaylistViewModel`.
  Pieśń ze zbioru wskazywana numerem, własna — id. `lib/export/` — PDF listy i format pliku `.spiewnik`.
- `lib/viewmodel/` — view modele: zwykłe klasy z `ValueNotifier`, zależności przez konstruktor.
- `lib/view/` — ekrany. `SongDetailView` to `PageView` po całym śpiewniku: zmiana pieśni przewraca stronę, nie otwiera
  nowego ekranu. `ScreenWakeLock` (`view/screen_wake_lock.dart`) trzyma ekran włączony, gdy pieśń jest otwarta.
- `ios/`, `android/` — projekty natywne. Wtyczki iOS idą przez Swift Package Manager; w CocoaPods został tylko ObjectBox.
- Dokumenty: `README.md` (opis, uruchomienie, testy w skrócie), `docs/DEVELOPMENT.md` (szczegóły testów, CI,
  test migracji E2E, pułapki), `docs/RELEASING.md` (wydanie), `docs/PARITY.md` (różnice wobec starej aplikacji iOS),
  `docs/DESIGN-SYSTEM.md` (system wizualny), `docs/SCHEMA-ZMYSONG.md` (schemat bazy iOS), `test/fixtures/README.md`.
  Materiały historyczne, opisujące stan sprzed migracji i redesignu: `docs/AUDIT.md`,
  `docs/ARCHITECTURE-PROPOSAL.md` — czytaj je jako źródło decyzji, nie jako opis obecnego kodu.

## Zasady

- **Przed pierwszym commitem w sesji sprawdź gałąź: `git branch --show-current`.** Jeśli to `main`,
  załóż nową gałąź (`git switch -c feature/...`) i dopiero commituj. Nigdy nie commituj bezpośrednio
  na `main`, nawet drobiazgu: `main` jest chroniony (zmiany tylko przez PR z zielonym CI, bez force pusha),
  więc push na `main` i tak zostanie odrzucony. Po scaleniu PR-a sprawdź gałąź ponownie — merge może cię
  przestawić na `main`.
- Nowa funkcja: widok w `lib/view/`, logika w view modelu, dane przez repozytorium (po PR-ach 2 i 3).
  `Store` i `Box` tylko w `lib/data/`, `lib/migration/`, `lib/json_manager.dart` i `lib/main.dart` — nigdy w widokach ani view modelach.
- **Testy view modeli i widoków nie mogą wymagać prawdziwej bazy** (po PR-ach 2 i 3): używaj fake'ów repozytoriów.
  Na `TestStore` i fixtures testuj tylko repozytoria, `JsonManager` i migracje.
- Wtyczki platformy (wakelock, share, url_launcher, in_app_review, package_info) testuj atrapami kanałów
  z `test/support/platform_fakes.dart` albo owijaj w klasę wstrzykiwaną.
- Czas przez wstrzykiwane `DateTime Function() now`, ścieżki i platformę przez parametry (wzorzec: `CoreDataMigration.runOnStartup`).
- Logowanie przez wstrzykiwany `Logger`, nie `print`.
- Każda zmiana z testem. Conventional commits, osobny commit na logiczną zmianę, gałąź `feature/...` od `main`.

## Czego nie ruszać

- `lib/objectbox-model.json` — UID-y schematu. Usunięcie oznacza niezgodną bazę u użytkowników.
- `lib/objectbox.g.dart` — tylko przez `build_runner`.
- `test/fixtures/*.sqlite*` — prawdziwe bazy z iOS, tylko do odczytu. Dane syntetyczne twórz na kopiach
  (`CoreDataFixtures.copyTo` + `changeCopy`) i oznaczaj komentarzem `SYNTHETIC DATA`. Puste `-wal` i `-shm` są celowe.
- Klucze SharedPreferences (`mySongsShowLists`, `playlistReorderHintSeen`, `fontSize`, `lineHeight`, `launch_count`, `last_run_app_version`, `songs_data_version`,
  `coreDataMigration*`, `legacySettingsMigrationDone`, `postMigrationWelcomeShown`) — są na urządzeniach użytkowników.
- `assets/songs_data.json` — generowany przez `tools/song_merge/`, nie edytować ręcznie.
- `android/key.properties` i `android/upload_certificate.pem` — nie otwierać, nie cytować.

## Testy

```sh
tools/fetch_objectbox_lib.sh   # raz po klonie: pobiera lib/libobjectbox.dylib (poza gitem)
flutter test
flutter analyze
```

## Pułapki

- Bez `lib/libobjectbox.dylib` padają wszystkie testy używające `TestStore`. To brak biblioteki, nie błąd w kodzie.
- `openStore()` w `testWidgets` nigdy nie kończy działania (path_provider bez implementacji). Zawsze `TestStore.open()`.
- Pierwsze `flutter test` pobiera przez build hook bibliotekę SQLite (potrzebna sieć).
- `dart run flutter_native_splash:create` nadpisuje `ios/Runner/Info.plist` (ustawia `UIStatusBarHidden` na `false`)
  i zasoby splasha Androida. Po uruchomieniu przywróć — szczegóły w `docs/DEVELOPMENT.md`.
- `flutter test integration_test -d <urządzenie>` **odinstalowuje aplikację i kasuje jej dane**. Nie uruchamiaj go na
  symulatorze przygotowanym do testu migracji.
- Migracja z iOS działa raz (flaga `coreDataMigrationDone`), po błędzie nie ponawia, nigdy nie rzuca i nigdy nie usuwa
  starej bazy. Nie filtruj po `Z_ENT` (patrz `docs/SCHEMA-ZMYSONG.md`).
- Zmiana wersji aplikacji (także numeru builda) nadpisuje tytuły i treści wszystkich pieśni z assetu.
- Android: po zmianie wersji wtyczek potrafi zostać nieaktualny cache Gradle (dziwne błędy Kotlina, brakujące klasy
  wtyczek) — pomaga `flutter clean`.
