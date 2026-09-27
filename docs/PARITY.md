# PARITY — Śpiewnik iOS vs Android

Źródła:
- iOS: `AUDIT.md` w repozytorium starej aplikacji iOS (w prośbie nazwany `AUDIT-ios.md`). Opisuje stan HEAD `37f0a8e`, wersję `11.2024`, Core Data.
- Android: `docs/AUDIT.md` (w prośbie nazwany `AUDIT-flutter.md`). Opisuje kopię roboczą `1.2.1+5`, ObjectBox.

**Stan: przegląd przed wydaniem 12.0.0** (wrzesień 2026). Wiersze oznaczone „od 12.0.0” opisują
stan po migracji, redesignie i domknięciu parytetu. Sekcja 5 zbiera to, co zostaje na stałe.

Dokument pokazuje wyłącznie różnice i zgodności. Nie ocenia, która wersja jest właściwa. Oznaczenie **NIEPOTWIERDZONE** jest przeniesione z audytów. Numery linii są w audytach źródłowych.

Oznaczenia w kolumnie „Rozbieżność”:
- **—** zgodne,
- **R** różnica w zachowaniu lub wartościach,
- **B** funkcja tylko po jednej stronie.

---

## 1. Zestawienie funkcji

| Funkcja | iOS | Android | Rozbieżność |
|---|---|---|---|
| **Nawigacja główna** | `TabView`, 3 zakładki: „Śpiewnik”, „Ulubione”, „Moje pieśni” | Od 12.0.0 te same 3 zakładki we własnym `AppNavigationBar`; trzecia nazywa się „Moje”, bo poza własnymi pieśniami trzyma listy pieśni (ikona 17 dp, kreska 2 dp w akcencie, wysokość minimalna); `ConvexAppBar` usunięty | **—** co do zakładek, **R** wizualnie |
| Układ na tablet | Osobne widoki `*SplitView` (`NavigationSplitView`: lista + szczegóły) dla `.pad` | Bez zmian: ten sam układ na każdym ekranie, treść ograniczona do 34 × S szerokości, więc na tablecie nie rozlewa się na całą szerokość | **R** — **zaległość**, patrz „Różnice, które zostają na stałe” |
| Wejście do ustawień | Zębatka tylko w zakładce „Śpiewnik”; ustawienia otwierają się jako arkusz (`.sheet`) | Zębatka w pasku górnym, dostępna ze wszystkich trzech zakładek; `Navigator.push` | **R** — świadoma decyzja: ustawienia są ekranem, nie arkuszem, i nie chowają się pod jedną zakładką |
| Tytuł paska na liście | „Śpiewnik” / „Ulubione” / „Moje pieśni” zależnie od zakładki | Zawsze „Śpiewnik” | **R** — świadoma decyzja: od 12.0.0 nazwę zakładki niesie podpis w dolnej nawigacji, więc pasek nie powtarza jej drugi raz |
| **Lista pieśni: sortowanie** | Jawne: `number` rosnąco (`NSSortDescriptor`) | Od 12.0.0 jawne: `number` rosnąco w zapytaniu repozytorium | **—** |
| Lista pieśni: wygląd wiersza | `"<number>. "` (headline) + tytuł, 1 linia, serce przy ulubionych | Od 12.0.0 wspólny wiersz: tytuł (Newsreader 17), linia wiodąca z kropek, numer na prawej krawędzi, serce 11 dp przy tytule | **R** (wizualnie) |
| Ulubione: zawijanie długiego tytułu | 1 linia | Do 12.0.0 tytuł zawijał się do wielu linii (wiersz na `Card`, bez `maxLines`); od 12.0.0 jedna linia z wielokropkiem, jak na pozostałych listach | **—** świadoma zmiana z systemu wizualnego |
| Fallback pustego tytułu | `"Brak tytułu"` (lista główna, szczegóły) / `"Brak tytuł"` (ulubione, moje pieśni) | Niepotrzebny: `title` jest non-null, pieśni z assetu zawsze mają tytuł, a formularz własnej pieśni nie pozwala zapisać pustego („Podaj tytuł pieśni”) | **—** problem nie istnieje po stronie Androida |
 Jest: własny `SongScrollBar` — uchwyt przy prawej krawędzi, etykieta z numerem pieśni przy przeciąganiu, tylko na pełnej liście. Wróciło po tym, jak wypadło razem z `draggable_scrollbar` | **B** — świadome ulepszenie, przy 2000 pozycjach wyszukiwarka nie zastępuje przewijania |
| **Wyszukiwanie: pola** | `content` (po oczyszczeniu) + podciąg `number` | `content` (po oczyszczeniu) + podciąg `number` | **—** |
| Wyszukiwanie: tytuł | Nieprzeszukiwany: filtr sprawdza tylko treść i numer | Od 12.0.0 przeszukiwany razem z treścią i numerem, trafienie podświetlone akcentem w tytule | **R** — świadome ulepszenie z systemu wizualnego |
| Wyszukiwanie: białe znaki po usunięciu ignorowanych znaków | Usunięcie znaku wewnątrz tekstu zostawia podwójną spację (przycinane są tylko końce), więc „boży zmiłuj” nie pasuje do „Baranku Boży, x zmiłuj się”, a „boży  zmiłuj” tak | **Naprawione w 12.0.0:** po usunięciu ignorowanych znaków ciągi białych znaków zwijają się do jednej spacji, tak samo w treści i w zapytaniu — pasuje „boży zmiłuj” i „boży  zmiłuj” | **R** — naprawiony błąd, iOS zostaje z wadą |
| Wyszukiwanie: usuwane znaki z treści | `1 2 3 4 5 6 7 8 9 , . ; : ' [ ] ( ) ! ? - ” — „ x` | `"123456789,.;:'[]()!?-”—„x"` (ten sam zestaw) | **—** |
| Wyszukiwanie: obróbka zapytania | Tylko `lowercased()` | Od 12.0.0 zapytanie dzielone na słowa (spacje i interpunkcja); każde słowo musi wystąpić w tytule albo treści, w dowolnej kolejności: 1–2 litery jako całe słowo, 3–4 od początku słowa, od 5 liter od początku słowa po ucięciu polskiej końcówki („chwała” znajduje „chwały”, „matko” znajduje „matka”). Wcześniej `toLowerCase()` i szukanie całego zapytania jako jednego ciągu | **R** — świadome ulepszenie |
| Wyszukiwanie: kolejność wyników | Po numerze | Od 12.0.0 przy zapytaniu ze słów ranking: tytuł przed treścią, dokładna forma przed formą z rdzenia, słowa obok siebie w kolejności zapytania przed rozrzuconymi, wcześniejsza zwrotka przed późniejszą; remis po numerze. Bez zapytania i przy zapytaniu z samych cyfr po numerze, jak wcześniej | **R** — świadome ulepszenie |
| Wyszukiwanie: polskie znaki | Brak normalizacji diakrytyków | Od 12.0.0: polskie litery zamieniane na litery bazowe w treści i w zapytaniu (`removePolishDiacritics`), więc „zrodlo” znajduje „źródło” i odwrotnie | **R** — świadome ulepszenie, nie odtworzenie zachowania iOS (stara wersja Androida też tego nie miała) |
| Treść pieśni: renderowanie | Jeden `Text`, bez parsowania | Od 12.0.0 renderer zdejmuje znaczniki z toku tekstu: inicjał w pierwszej zwrotce, cyfra z linią w kolejnych, wersalik „REFREN” z wcięciem, znaki powtórzenia w akcencie, odstęp zamiast pustych wierszy | **R** — świadome ulepszenie z systemu wizualnego |
| Stan pusty listy | Tekst w środku ekranu | Od 12.0.0 ikona, nagłówek i zdanie mówiące co zrobić; przy braku wyników przycisk „Wyczyść wyszukiwanie” | **R** |
| Wyszukiwanie: wyzwalanie | Zależne od ustawienia: po zatwierdzeniu (`onCommit`) albo dynamicznie z debounce **0,5 s** | Zawsze dynamicznie, debounce **250 ms** | **R** |
| Wyszukiwanie: przycisk „Anuluj” | Jest (chowa klawiaturę, czyści) | Krzyżyk w polu (czyści, przewija na górę, cel 48 dp), podpowiedź „Szukaj” | **R** — świadoma decyzja z systemu wizualnego: pole jest widoczne zawsze, więc nie ma z czego „wychodzić” |
| Wyszukiwanie w ulubionych | Brak | Brak | **—** |
| Wyszukiwanie we własnych pieśniach | Pole widoczne, **nie filtruje** | Brak funkcji | **B** (i martwa funkcja po stronie iOS) |
| Własne pieśni: sortowanie listy | `title` rosnąco (`NSSortDescriptor` bez porównania uwzględniającego lokalizację): kolejność punktów kodowych Unicode, polskie znaki diakrytyczne za „Z”, wielkie litery przed małymi | Od 12.0.0: `title` rosnąco według polskiego alfabetu (Ł po L, Ż po Ź), bez rozróżniania wielkości liter; te same tytuły po `id` rosnąco | **R** — świadome ulepszenie, nie odtworzenie zachowania iOS |
| **Szczegóły: tytuł paska** | `"<number>. <title>"` | `'${song.number}. ${song.title}'` | **—** |
| Szczegóły: wyświetlanie treści | Jeden `Text`, bez parsowania | Od 12.0.0 renderer `SongContent` (patrz wiersz „Treść pieśni: renderowanie”), tekst od góry ekranu | **R** — świadome ulepszenie |
| **Przejście do numeru: wejście** | `UIAlertController`, klawiatura `.numberPad`, brak limitu długości | Dialog z systemu wizualnego: klawiatura numeryczna, tylko cyfry, podpowiedź z zakresem `1-N`, tytuł trafionej pieśni pod polem, Enter działa jak „Przejdź” | **R** — świadome ulepszenie |
| Przejście do numeru: zakres | 1…2000 (zakodowane) | Od 12.0.0: 1…liczba pieśni w bazie, bez zakodowanej wartości | **—** zachowanie takie samo przy pełnym śpiewniku |
| Przejście do numeru: błąd | Alert „Podano niepoprawny numer” / „W śpiewniku znajdują się 2000 pieśni.”; po OK dialog wejściowy otwiera się ponownie | Od 12.0.0 **nie ma błędu do pokazania**: „Przejdź” jest zablokowane, dopóki numer nie trafia w pieśń, a pod polem stoi powód („Nie ma pieśni o tym numerze”, „Podaj numer od 1 do N”) | **R** — świadome ulepszenie: zamiast alertu po fakcie, podpowiedź w trakcie pisania |
| Przejście do numeru: mechanizm | Podmiana `song` w tym samym widoku; `currentIndex` **nie** jest aktualizowany | Od 12.0.0 skok na stronę w `PageView` tego samego ekranu (`jumpToPage`), bez animacji; wcześniej `Navigator.pushReplacement` na nowy `SongDetailView` | **R** |
| **Swipe poprzednia/następna** | `DragGesture(minimumDistance: 50)`, rozstrzygane na końcu gestu; `width > 0` → poprzednia, pozostałe → następna | Od 12.0.0 `PageView`: treść idzie za palcem, strona przewraca się po szybkim ruchu albo po przeciągnięciu ponad połowę szerokości; paski stoją, poprzednia pieśń wjeżdża z lewej, następna z prawej; strzałki animują 200 ms. Wcześniej `onPanUpdate` przy każdym zdarzeniu z `\|dx\| > 10`: wolne przeciągnięcie nic nie robiło, a animacja zawsze szła jak przy następnej pieśni (wielokrotnego wyzwolenia nie potwierdzono). Na iOS przesunięcie od lewej krawędzi to nadal systemowy powrót do listy | **R** |
| Swipe i strzałki: dziura w numeracji | Nie dotyczy: dane bez luk (1…2000) | Od 12.0.0 kolejna strona to kolejna pieśń w śpiewniku, więc dziura jest przeskakiwana; wcześniej przejście zatrzymywało się na dziurze (`numer ± 1`). Przy danych bez luk bez zmiany dla użytkownika | **R** |
| Swipe: po przejściu do numeru | Liczy od pierwotnie otwartej pieśni | Liczy od wyświetlanej pieśni | **R** |
| **Ulubione: przełączanie** | Tylko z ekranu szczegółów | Tylko z ekranu szczegółów | **—** |
| Ulubione: sortowanie listy | Jawne: `number` rosnąco | Od 12.0.0 jawne: `number` rosnąco | **—** |
| Ulubione: komunikat pustej listy | „Lista ulubionych pieśni jest pusta” | Stan pusty z systemu wizualnego: ikona, nagłówek i zdanie mówiące co zrobić | **R** |
| **Udostępnianie** | Systemowy `UIActivityViewController`, tylko treść; **tylko iPhone** | Od 12.0.0 systemowy arkusz (`share_plus`) z numerem, tytułem i treścią, na obu platformach; wywoływany z arkusza opcji pod trzema kropkami | **—** (kotwica na iPadzie ustawiona, więc działa też na tablecie) |
| **Własne pieśni: dodawanie / edycja / usuwanie** | Jest (usuwanie tylko iPhone) | Jest, na obu platformach: dodawanie i edycja w formularzu z walidacją, usuwanie z podglądu (arkusz opcji) i gestem z listy, oba z potwierdzeniem | **—** |
| Skanowanie tekstu aparatem (Live Text) | Jest, warunkowo; zastępuje całą treść | Brak | **B** |
| **Rozmiar czcionki** | Klucz `isSize`; domyślnie 16 (iPhone) / 24 (iPad); zakres 10…30 (iPhone) / 24…44 (iPad), krok 2 | Klucz `fontSize`; od 12.0.0 domyślnie **19**, zakres 10…30. Wartości zapisane przez użytkownika zostają, spoza zakresu są przycinane | **R** — nowa domyślna z systemu wizualnego dotyczy tylko nowych instalacji |
| **Interlinia** | Klucz `isLineSpacing`; **dodatkowe punkty** (`lineSpacing`); domyślnie 0; zakres 0…10, krok 1 | Klucz `lineHeight`; **mnożnik**; od 12.0.0 domyślnie **1,62**, zakres **1,4…1,8** (wcześniej 1,0…3,0). Zapisane wartości spoza zakresu przycinane, nie resetowane | **R** (inna jednostka i semantyka) — świadome zawężenie: skrajne wartości psuły łamanie tekstu |
| Reset ustawień | `isLineSpacing = 0`, `isSize = 16` (także na iPadzie) | „Przywróć domyślny rozmiar i interlinię”: `fontSize = 19`, `lineHeight = 1,62`. **Nie rusza** motywu ani blokady ekranu — te mają własny model | **R** |
| Podgląd tekstu w ustawieniach | Jest (ten sam fragment „Alleluja, chwalcie Pana…”) | Jest, ten sam fragment, renderowany tym samym rendererem co pieśń i **pod obydwoma suwakami**, bez stałej wysokości (wcześniej 180 dp ucinało największą czcionkę) | **—** |
| Przełącznik „Dynamiczna wyszukiwarka” | Jest (`isSearchDynamic`) | Brak | **B** |
| **Tryb nocny** | Systemowy, brak przełącznika | Od 12.0.0 przełącznik w ustawieniach: „Jak w systemie” (domyślnie, jak dotąd), „Jasny”, „Ciemny”; klucz `themeMode` | **R** — świadome ulepszenie z systemu wizualnego; **R** (kolorystyka) |
| **Blokada wygaszania ekranu** | Brak | Zawsze włączona na ekranach szczegółów pieśni i własnej pieśni (`wakelock_plus`), od 12.0.0 z przełącznikiem „Nie gaś ekranu przy pieśni” w ustawieniach (klucz `keepScreenOn`, domyślnie włączony, czyli bez zmiany dla dotychczasowych użytkowników); wyłączenie działa od razu, także przy otwartej pieśni. **Zamyka A3.** **Naprawione w 12.0.0:** wcześniej po `pushReplacement` (przejście do numeru, przeciągnięcie na następną lub poprzednią pieśń) blokada się wyłączała, bo `dispose` starego ekranu wywoływał `disable` po `enable` nowego. Najpierw naprawione licznikiem otwartych ekranów (#16); od przejścia na `PageView` zmiana pieśni nie zamienia ekranu, więc `ScreenWakeLock` to znów zwykła para włącz/wyłącz, z notatką w kodzie, dlaczego licznik istniał; testy regresji w `test/song_detail_view_wakelock_test.dart` | **B** |
| Link „Kontakt” | `https://spiewnik.odoo.com/contactus` | `https://spiewnik.odoo.com/contactus` | **—** |
| Link „O mnie” | `https://spiewnik.odoo.com/about-us` | `https://spiewnik.odoo.com/about-us` | **—** |
| „Wesprzyj” | Link `https://suppi.pl/spiewnik` (+ niepodpięty kod zakupów) | Link `https://suppi.pl/spiewnik` | **—** w UI; **R** w kodzie |
| „Zgłoś błąd”: adres | `mailto:n.marmucki@icloud.com` | Ten sam adres, w stałej `SettingsViewModel.contactEmail` — jedyne miejsce w kodzie | **—** świadoma decyzja: adres zostaje jawny |
| „Zgłoś błąd”: temat | `Zgłoszenie błędu w aplikacji Śpiewnik <wersja>` | `Zgłoszenie błędu w aplikacji Śpiewnik (<wersja>)` — z nawiasami, `packageInfo.version` bez builda | **R** |
| „Zgłoś błąd”: obsługa błędu | Alerty „Błąd” / „Zgłoś błąd” z kopiowaniem adresu | Od 12.0.0 dialog „Nie udało się otworzyć” z adresem i przyciskiem „Kopiuj adres”, w kształcie dialogów z systemu wizualnego; to samo przy nieudanym otwarciu strony | **—** zachowanie odtworzone |
| **Changelog po aktualizacji** | Alert „Nowa wersja <v>” z tekstem dla `9.2024`/`10.2024`/`11.2024`; przyciski „OK”, „Zgłoś błąd”, „Wesprzyj”; także przy pierwszej instalacji | Brak. **Decyzja przed 12.0.0:** zamiast changelogu przy każdej aktualizacji powstanie **jednorazowy ekran powitalny po migracji** — osobny PR, warunki niżej | **R** — świadoma decyzja, węższy zakres niż iOS |
| **Prośba o ocenę: wyzwalacz** | `scenePhase == .active` + licznik uruchomień | Od 12.0.0 wyłącznie licznik uruchomień, raz na start, poza `build` (`ReviewService.onLaunch`). Wyzwalacz „pierwsza ulubiona w sesji” **usunięty** | **—** |
| Prośba o ocenę: progi | `[20, 50, 90, 140, 200, 270, 300, 390, 490, 640, 840, 1140, 1440, 1940]` | Od 12.0.0 te same progi | **—** |
| Prośba o ocenę: limit per wersja | Tak (`lastVersionPromptedForReviewKey`) | Od 12.0.0 tak, klucz `reviewAskedVersion` (wersja z numerem builda). Klucz nowy, więc pierwsza prośba w 12.0.0 pada niezależnie od historii | **—** |
| Prośba o ocenę: inkrementacja licznika | +2 na uruchomienie (`init` + `onAppear`) | +1 na uruchomienie, raz, poza `build` | **R** — iOS liczył podwójnie, więc jego progi wypadały dwa razy szybciej niż sugeruje liczba |
| Aktualizacja tekstów u istniejących użytkowników | Mechanizm `update()` wywoływany przy zmianie wersji; w HEAD funkcje puste | **Naprawione:** `JsonManager.applySongsData` porównuje `dataVersion` z assetu z zapisanym (`songs_data_version`) i aktualizuje tytuły oraz treści, zachowując ulubione | **R** — Android ma działający mechanizm, iOS nie |
| Zakupy w aplikacji | Kod StoreKit 1 i 2, **niepodpięty** | Brak | **B** (tylko martwy kod) |
| Orientacja | Portrait, LandscapeLeft, LandscapeRight; `UIRequiresFullScreen = true` | Bez blokady po żadnej stronie (iOS dziedziczy wpis z `Info.plist`, Android nie ma `screenOrientation`) | **—** w praktyce: obie wersje obracają się tak samo |
| Pasek statusu | `UIStatusBarHidden = true` (ukryty) | Widoczny na obu platformach: `UIStatusBarHidden` zostaje w `Info.plist`, ale Flutter i tak rysuje pasek statusu | **R** — **świadoma decyzja**: ukrywanie paska w aplikacji, z której korzysta się na nabożeństwie, zabierałoby zegarek i baterię bez powodu |
| Splash | `Launch Screen.storyboard` (obraz `applogo`) | `flutter_native_splash` (biały / czarny, `playstore-transparent.png`) | **R** |

---

## 2. Funkcje obecne tylko po jednej stronie

### Tylko iOS

| Funkcja | Uwagi z audytu |
|---|---|
| ~~„Moje pieśni”: lista, dodawanie, podgląd, edycja, usuwanie~~ | **Dorobione w 12.0.0** na obu platformach. Po stronie iOS usuwanie działało tylko na iPhonie, a wyszukiwarka w tej zakładce nie filtrowała |
| Skanowanie tekstu aparatem (Live Text) przy dodawaniu i edycji własnej pieśni | Warunkowo, gdy `captureTextFromCamera` jest dostępne |
| ~~Systemowy arkusz udostępniania~~ | Tylko iPhone. **Dorobione w 12.0.0** na obu platformach |
| Przełącznik „Dynamiczna wyszukiwarka” (tryb wyszukiwania po zatwierdzeniu) | — |
| Układ dwukolumnowy (`NavigationSplitView`) na iPadzie | — |
| Alert „Nowa wersja” z changelogiem | — |
| ~~Limit prośby o ocenę raz na wersję~~ | **Dorobione w 12.0.0** |
| Kod zakupów w aplikacji (StoreKit 1 + StoreKit 2, `Configuration.storekit`) | Niepodpięty, nieosiągalny z UI |
| Osobne rozmiary domyślne i zakresy czcionki dla iPada | — |

### Tylko Android

| Funkcja | Uwagi z audytu |
|---|---|
| Blokada wygaszania ekranu na ekranie szczegółów | Do 12.0.0 zawsze włączona, bez ustawienia; od 12.0.0 z przełącznikiem w ustawieniach |
| Kopiowanie treści do schowka z SnackBarem | Do 12.0.0 w miejscu udostępniania; od 12.0.0 osobna pozycja „Kopiuj tekst” w arkuszu opcji, obok udostępniania |
| ~~Prośba o ocenę po pierwszym dodaniu ulubionej~~ | **Usunięte w 12.0.0** — zostaje sam licznik uruchomień |
| Wejście do ustawień z każdej zakładki | Od 12.0.0 z trzech zakładek |
| Podpowiedź przy przejściu do numeru | Od 12.0.0 pod polem, w trakcie pisania, zamiast alertu po zatwierdzeniu |

---

## 3. Różnice w schemacie danych pieśni

### 3.1 Źródło i format

| Aspekt | iOS | Android |
|---|---|---|
| Plik źródłowy w repo | `Model.sqlite` (katalog główny repo, 1 732 608 B) | `assets/songs_data.json` (1 629 390 B) |
| Format | SQLite w formacie store’u Core Data | JSON: `{"songs": [ {...}, ... ]}` |
| Baza robocza na urządzeniu | Kopia pliku: `Documents/Model.sqlite` | ObjectBox: `<getApplicationDocumentsDirectory()>/objectbox` (dokładna ścieżka NIEPOTWIERDZONA) |
| Moment załadowania | Skopiowanie pliku, gdy nie istnieje | `putMany` z JSON, gdy box jest pusty |
| Liczba pozycji | 2000 | 2000 |
| Zakres `number` | 1…2000, unikalne, bez luk | 1…2000, unikalne, posortowane |
| Treść zawiera `\n` / `\r` | 1938 / 0 | 1938 / 0 |
| Dane wbudowane / pobierane | Wbudowane | Wbudowane |

### 3.2 Pola

| Pole logiczne | iOS: atrybut Core Data | iOS: kolumna SQLite | iOS: typ, opcjonalność | Android: pole Dart / ObjectBox | Android: typ, opcjonalność | Android: klucz JSON | Rozbieżność |
|---|---|---|---|---|---|---|---|
| Identyfikator techniczny | — (niejawny `Z_PK`) | `Z_PK INTEGER PRIMARY KEY` | — | `id` (`@Id()`) | `int`, auto; ObjectBox `type 6`, `flags 1` | brak w JSON | **R.** W bundlu iOS `Z_PK` = `ZNUMBER`; na Androidzie `id` jest nadawane przez ObjectBox. |
| Numer | `number` | `ZNUMBER INTEGER` | `Integer 64`, **optional = YES**, domyślnie `0` | `number` (`@Index()`) | `int`, **wymagane**; `type 6`, `flags 8` (indeks) | `number` (`as int`, wymagany) | **R.** Opcjonalność, indeks (iOS bez indeksu). Unikalność niewymuszona po obu stronach. |
| Tytuł | `title` | `ZTITLE VARCHAR` | `String`, **optional = YES** | `title` | `String`, **non-null**; `type 9` | `title` (`as String`, wymagany) | **R** (opcjonalność) |
| Treść | `content` | `ZCONTENT VARCHAR` | `String`, **optional = YES** | `content` | `String`, **non-null**; `type 9` | `content` (`as String`, wymagany) | **R** (opcjonalność) |
| Ulubiona | `favorite` | `ZFAVORITE INTEGER` | `Boolean` scalar, **optional = YES**, brak domyślnej w modelu; w bundlu `0` | `favorite` | `bool`, **non-null**; `type 1` | `favorite` (`as bool? ?? false`, **opcjonalny**; w pliku nie występuje) | **R** (opcjonalność, źródło wartości początkowej) |
| Kolumny techniczne | — | `Z_ENT` (NULL w bundlu), `Z_OPT` (1 w bundlu) | — | — | — | — | **B** (tylko iOS) |

Nazwy encji: iOS `Song` (tabela `ZSONG`), Android `Song` (UID encji `1:668007825265052091`).

### 3.3 Różnice w zawartości

| Aspekt | Wartość |
|---|---|
| Różne tytuły | 3: nr `923` (iOS `'Gdy idziesz sam'` / Android `'Zjednani sercem i ustami'`), nr `1497` i `1498` (tytuły zamienione miejscami) |
| Różne treści | 58 pozycji; pierwsze: `292`, `450`, `686`, `898`, `900`, `923`, `930`, `939`, `944`, `959` |
| Konwencje zapisu treści | Zgodne: `"1. "`, `"Refren: "`, `\n\n` między akapitami, `[:…:]`, `/…/3x` |
| Zawartość na urządzeniach użytkowników | iOS: może różnić się od repo (historyczne poprawki przez `update()`). Android: aktualizowana przy zmianie `dataVersion` w assecie, z zachowaniem ulubionych. |

### 3.4 Aktualizacja danych pieśni

| Aspekt | iOS | Android |
|---|---|---|
| Wyzwalacz | Zmiana `CFBundleShortVersionString` względem `lastInstalledVersion` | Zmiana `"<version>+<buildNumber>"` względem `last_run_app_version` |
| Zakres | Pojedyncze pieśni wskazane w kodzie (`update(number:title:content:)`) | Cały plik JSON |
| Zachowanie `favorite` | Zachowane | Zachowane (dopasowanie po `number`) |
| Dodawanie nowych numerów | Brak | Tak |
| Usuwanie numerów spoza źródła | Brak | Tak, razem ze statusem ulubionej |
| Stan obecny | Funkcje puste w HEAD | Działa: wersja zapisywana dopiero po udanym zapisie pieśni |

---

## 4. Różnice w sposobie zapisu danych użytkownika

### 4.1 Mechanizmy

| Rodzaj danych | iOS: mechanizm | Android: mechanizm | Rozbieżność |
|---|---|---|---|
| Ulubione | Core Data (SQLite), ten sam plik co teksty | ObjectBox, ten sam obiekt co teksty | **R** (silnik); **—** (brak rozdzielenia od treści po obu stronach) |
| Własne pieśni | Core Data, encja `MySong` | ObjectBox, encja `MySong` (`title`, `content`, `createdAt`, `updatedAt`) | **—** silniki się różnią, funkcja jest po obu stronach |
| Historia / ostatnio otwierane | Brak | Brak | **—** |
| Ustawienia wyświetlania | `UserDefaults.standard` | `SharedPreferences` (legacy API) | **R** |
| Metadane (licznik, wersje) | `UserDefaults.standard` (w tym `@AppStorage`) | `SharedPreferences` | **R** |
| Synchronizacja chmurowa | Brak | Brak | **—** |
| Wersjonowanie schematu | Jedna wersja modelu Core Data, brak mapping models; `MySong` dopisany bez wersjonowania (niejawna migracja lekka, NIEPOTWIERDZONA) | `objectbox-model.json` (UID-y, `version: 1`), brak własnych migracji | **R** |

### 4.2 Ulubione

| Aspekt | iOS | Android |
|---|---|---|
| Lokalizacja | `Documents/Model.sqlite` (+ ewent. `-wal`, `-shm`, NIEPOTWIERDZONE) | katalog `objectbox` (nazwy plików NIEPOTWIERDZONE) |
| Tabela / encja | `ZSONG` / `Song` | `Song` |
| Kolumna / pole | `ZFAVORITE` / `favorite` | `favorite` |
| Typ zapisany | INTEGER `0`/`1` | ObjectBox Bool (`type 1`) |
| Powiązanie z pieśnią | Ten sam wiersz; `ZNUMBER` | Ten sam obiekt; `number` (i `id`) |
| Kolejność / data dodania | Nie zapisywana | Nie zapisywana |
| Moment zapisu | `save()` po przełączeniu + zapis kontekstu przy przejściu w tło | `box.put(song)` od razu |

### 4.3 Własne pieśni

| Aspekt | iOS | Android |
|---|---|---|
| Encja | `MySong` | `MySong` (ObjectBox) |
| Pola | `title` (`String`, optional), `content` (`String`, optional) | `title`, `content` (oba non-null) |
| Identyfikator | Brak własnego (tylko `Z_PK`) | `id` nadawane przez ObjectBox |
| Daty | Brak | `createdAt` i `updatedAt`; migracja ze starej aplikacji nadaje rosnące czasy w kolejności odczytu z `ZMYSONG` |
| Tabela na urządzeniu | `ZMYSONG` wg konwencji Core Data; brak w bundlu, kolumny i `Z_ENT` NIEPOTWIERDZONE | katalog `objectbox`, ta sama baza co pieśni |
| Sortowanie listy | `title` rosnąco, kolejność punktów kodowych | `title` rosnąco według polskiego alfabetu, bez rozróżniania wielkości liter, remisy po `id` |

### 4.4 Klucze ustawień i metadanych

| Znaczenie | iOS: klucz (`UserDefaults`) | iOS: typ, domyślna | Android: klucz w kodzie | Android: klucz fizyczny | Android: typ fizyczny, domyślna |
|---|---|---|---|---|---|
| Rozmiar czcionki | `isSize` | `CGFloat` (NSNumber); 16 iPhone / 24 iPad | `fontSize` | `flutter.fontSize` | `String` z prefiksem `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu`; od 12.0.0 domyślnie 19.0 |
| Interlinia | `isLineSpacing` (punkty) | `CGFloat`; 0 | `lineHeight` (mnożnik) | `flutter.lineHeight` | `String` z prefiksem jw.; od 12.0.0 domyślnie 1.62 |
| Tryb wyszukiwarki | `isSearchDynamic` | `Bool`; `false` | — | — | — |
| Rozmiar ikon | `isSizeImg` (tylko odczyt; zapis trafia pod `isSize`) | `CGFloat`; 16 / 24 | — | — | — |
| Nieużywany licznik | `counter` | `Int`; 0 | — | — | — |
| Licznik uruchomień | `engagementCounterKey` | `Int`; 0 | `launch_count` | `flutter.launch_count` | `long`; 0 |
| Ostatnia wersja (zmiana wersji) | `lastInstalledVersion` | `String`, format `M.RRRR` (np. `11.2024`); `""` | `last_run_app_version` | `flutter.last_run_app_version` | `String`, format `<version>+<build>` (np. `1.2.1+5`); `null` |
| Wersja ostatniej prośby o ocenę | `lastVersionPromptedForReviewKey` | `String` | `reviewAskedVersion` | `flutter.reviewAskedVersion` | `String`, format `<version>+<build>`; brak |

Klucze dodane w 12.0.0: `themeMode` (`flutter.themeMode`, `String`: `system`/`light`/`dark`, domyślnie
`system`), `keepScreenOn` (`flutter.keepScreenOn`, `bool`, domyślnie `true`), `reviewAskedVersion`.

Plik fizyczny na Androidzie: `FlutterSharedPreferences`. Na iOS klucze leżą bez prefiksu w `UserDefaults.standard`. Z kodu pakietu `shared_preferences` (legacy) wynika, że Flutter na iOS zapisuje klucze z prefiksem `flutter.` w `NSUserDefaults`.

### 4.5 Kopia robocza iOS (niewydana, dla kompletności)

| Element | Wartość |
|---|---|
| Nowe klucze `UserDefaults` | `RealmMigrationCompleted` (`Bool`), `ObjectBoxMigrationCompleted` (`Bool`) |
| Realm `Song` | `id: ObjectId` (PK), `number: Int`, `title: String`, `content: String`, `favorite: Bool`, `lastModified: Date` |
| Realm `MySong` | `id: ObjectId` (PK), `title`, `content`, `createdAt: Date`, `lastModified: Date` |
| ObjectBox `SongEntity` | `id: UInt64`, `number: Int64`, `title`, `content`, `category: String`, `favorite: Bool` |
| ObjectBox `MySongEntity` | `id: UInt64`, `title`, `content`, `createdDate: Date` |
| Różnica względem Androida | Encja ObjectBox iOS ma dodatkowe pole `category`; nazwy encji `SongEntity` vs `Song`; typ `number` `Int64` vs `int` (Dart int 64-bit) |

---

## 5. Różnice, które zostają na stałe

Przegląd całego dokumentu przed wydaniem 12.0.0. Wszystko, co wyżej nie jest oznaczone jako
naprawione albo dorobione, mieści się w jednej z tych kategorii.

### 5.1 Świadome decyzje — nie zamierzamy ich zmieniać

| Różnica | Dlaczego zostaje |
|---|---|
| Wyszukiwanie obejmuje tytuł, iOS tylko treść i numer | Szukanie po tytule jest tym, czego użytkownik próbuje najpierw. Trafienie jest podświetlone w wierszu |
| Brak diakrytyków w wyszukiwaniu (iOS ich nie normalizuje) | „zrodlo” ma znajdować „źródło”. Pisanie z ogonkami na telefonie kosztuje, a nic nie wnosi |
| Białe znaki zwijane po usunięciu ignorowanych znaków | iOS zostaje z błędem, przez który „boży zmiłuj” nie znajdowało pieśni. Nie odtwarzamy cudzych wad |
| Własne pieśni sortowane polskim alfabetem | Kolejność punktów kodowych wypychała polskie litery za „Z”. Dla listy po polsku to bezużyteczne |
| Tytuł paska zawsze „Śpiewnik” | Nazwę zakładki niesie podpis w dolnej nawigacji; pasek nie powtarza jej drugi raz |
| Ustawienia jako ekran, dostępne z każdej zakładki | iOS chował je pod jedną zakładką i otwierał jako arkusz. Ekran jest przewidywalny i mieści więcej |
| Brak przycisku „Anuluj” przy wyszukiwarce | Pole jest widoczne zawsze, więc nie ma z czego wychodzić; czyści krzyżyk w polu |
| Pasek statusu widoczny (iOS go ukrywał) | Aplikacji używa się na nabożeństwie — zegarek i bateria są tam potrzebne bardziej niż dwie dodatkowe linijki tekstu |
| Interlinia zawężona do 1,4–1,8 | Skrajne wartości ze starego zakresu psuły łamanie i rozbijały zwrotki |
| Nowe domyślne 19 / 1,62 | Dotyczą tylko nowych instalacji; zapisane ustawienia są przycinane, nie resetowane |
| Przełącznik motywu (iOS ma tylko systemowy) | Kościół bywa ciemny, telefon nie zawsze przełącza się sam |
| Szybkie przewijanie z etykietą numeru (iOS nie ma) | Przy 2000 pozycjach wyszukiwarka nie zastępuje przewijania |
| Blokada wygaszania ekranu (iOS nie ma) | Pieśń śpiewa się dłużej niż trwa wygaszanie ekranu. Od 12.0.0 z przełącznikiem |
| Kopiowanie treści do schowka (iOS nie ma) | Kosztuje jedną pozycję w arkuszu, a bywa wygodniejsze niż udostępnianie |

### 5.2 Zaległości — możliwe do zrobienia, świadomie odłożone

| Różnica | Stan |
|---|---|
| Układ dwukolumnowy na tablecie | Nie zaczęte. Aplikacja działa na tablecie, ale nie korzysta z szerokości. Osobna praca, nie na wydanie 12.0.0 |
| Skanowanie tekstu aparatem przy dodawaniu własnej pieśni | Nie zaczęte. Wymaga uprawnienia do aparatu i osobnego ekranu |
| Alert z changelogiem po aktualizacji | Zastąpiony jednorazowym ekranem powitalnym po migracji; warunki w sekcji 5.4 |
| Aktualizacja tekstów pieśni po stronie iOS | Dotyczy starej aplikacji, która znika razem z tym wydaniem. Bezprzedmiotowe |

### 5.3 Różnice, które znikają razem ze starą aplikacją

Kod zakupów w aplikacji (StoreKit, niepodpięty), przełącznik „Dynamiczna wyszukiwarka”, osobne
zakresy czcionki dla iPada, podwójne liczenie uruchomień, martwa wyszukiwarka w zakładce „Moje
pieśni”, `isSizeImg` zapisywane pod cudzym kluczem. Nie odtwarzamy ich, bo to albo martwy kod,
albo błędy.

### 5.4 Ekran powitalny po migracji — uzgodnione warunki

Zamiast changelogu przy każdej aktualizacji (jak w iOS) powstanie **jeden ekran, pokazany raz**.
Powód: dla użytkownika starej aplikacji iOS wydanie 12.0.0 zmienia wszystko, co widzi, i przenosi
jego dane — to warte słowa wyjaśnienia. Przy zwykłej aktualizacji Androida nie ma czego tłumaczyć.

Zrobione w issue #37 (`lib/post_migration_welcome.dart`, `lib/view/welcome_view.dart`). Warunki:

- pokazywany **raz**, tylko użytkownikom przychodzącym ze starej aplikacji iOS — czyli gdy
  `coreDataMigrationDone` zostało ustawione **w tej sesji**, a nie kiedyś wcześniej;
- **nie** pokazywany przy czystej instalacji ani na Androidzie;
- **jedno wyjście**, bez przycisków „Wesprzyj” i „Zgłoś błąd”;
- zbudowany na tokenach z `docs/DESIGN-SYSTEM.md`;
- własna flaga w `SharedPreferences`, żeby nie wracał przy kolejnym starcie.
- doprecyzowane przy wdrożeniu: migracja musiała **coś przenieść** (ulubione, własne pieśni albo
  rozmiar czcionki) i **nie** mogła skończyć się błędem — wtedy użytkownik widzi komunikat w
  ustawieniach, a chwalenie się nowym wyglądem byłoby nie na miejscu.
- gdy przeniosły się **tylko ustawienia** (rozmiar czcionki), bez ulubionych i własnych pieśni,
  pierwszy akapit brzmi „Twoje ustawienia przeniosły się razem z aplikacją.”, reszta ekranu jest
  taka sama. Nie obiecujemy pieśni, których użytkownik nie miał.
