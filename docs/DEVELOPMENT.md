# Development

Details that do not fit in the README: how the tests get their native libraries, CI, the end-to-end test
of the migration from the old iOS app, and known pitfalls.

## Tests

### Native libraries

Tests that use the ObjectBox database need the native ObjectBox library in `lib/` (`libobjectbox.dylib` on macOS,
`libobjectbox.so` on Linux). The library is not in the repository, so after cloning and on CI it has to be
downloaded first:

```sh
tools/fetch_objectbox_lib.sh
flutter test
```

The script downloads `objectbox-c` in the version that matches the `objectbox` package in `pubspec.lock` and
verifies the archive checksum. It supports macOS and Linux x64 and aarch64. After an update of the `objectbox`
package the script stops, and the library version and checksums in it have to be bumped.

The tests of the old iOS database reader (`test/core_data_reader_test.dart`, `test/core_data_migration_test.dart`)
use SQLite through `sqflite_common_ffi`. The `sqlite3` package (from version 3) downloads a precompiled library from
the `sqlite3.dart` releases on GitHub (verified by checksum) through a build hook into `.dart_tool/hooks_runner/`
on the first test run, so the first run, on CI too, needs network access. On Linux the `sqflite_common_ffi`
README still recommends the `libsqlite3-dev` package.

`sqflite_common_ffi` is a dev dependency: the SQLite library from the hook ends up in debug builds (debug APK,
iOS simulator app), but not in the release APK or the IPA archive. The app on a device reads the old iOS database
through `sqflite`, that is the system SQLite.

### Golden tests

`test/golden/` holds images of every screen in the light and dark theme. Font rasterization differs between
systems, so **the images are generated only on Linux**, in a container with a pinned Flutter
(`tools/golden.Dockerfile`, version 3.47.4, the same as on CI).

```sh
tools/golden.sh            # checks that the UI matches the images in the repository
tools/golden.sh --update   # writes new images after an intended UI change
```

The first run builds the Docker image (a few minutes); later runs reuse it.

A local `flutter test` on macOS **skips** these tests (they are tagged `golden` and skipped outside Linux) to keep
the work loop fast. On CI they run normally and they are what keeps the UI from changing by accident. When a
golden test fails on CI, the run artifacts (`golden-failures`) contain three images for every difference: the
expected one, the actual one and a diff map.

## CI

GitHub Actions, `.github/workflows/`:

| Workflow | When | What it does |
|---|---|---|
| `ci.yml`, job "Analyze and test" | every pull request and push to `main` | `flutter analyze --no-fatal-infos` and `flutter test` on Ubuntu, golden tests included |
| `ci.yml`, job "Build the Android app" | same, in parallel | `flutter build apk --debug --target-platform android-arm64` |
| `ios-build.yml` | every pull request, and manually (Actions → "iOS build" → "Run workflow") | `flutter build ios --simulator --no-codesign` on macOS |

Both `ci.yml` jobs run in parallel, so the test result arrives after about two minutes, regardless of the longer
Android build. The debug build is made only for `android-arm64`: that is enough to catch compile and link errors,
and a full build does the same thing three times.

Flutter is pinned to 3.47.4, the same version as the project. Before the tests CI installs `libsqlite3-dev`
and downloads the ObjectBox library with `tools/fetch_objectbox_lib.sh`. Any failed step stops the run,
so red tests block the merge.

CI runs `flutter analyze --no-fatal-infos`: without the flag the analysis fails on every issue, including
the "info" level. The "info" issues (among others `print` and the deprecated `canLaunch`) are known and will go
away with the cleanup of the views; errors and warnings stop the run.

The iOS workflow runs on pull requests. Minutes on the macOS runner count ten times, but the repository is
public, so they are free. Manual runs stay available, which is useful before a release.

The same locally:

```sh
tools/fetch_objectbox_lib.sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --target-platform android-arm64
flutter build ios --simulator --no-codesign   # macOS only
```

## End-to-end test of the migration from the old iOS app

The unit tests of the migration (`test/core_data_*`, `test/legacy_settings_migration_test.dart`) run on fixtures.
Every change that touches the migration (`lib/migration/`, `ios/Runner/AppDelegate.swift`, ObjectBox,
`shared_preferences`) also needs the full path on a simulator: the old Swift app from 11.2024 with data, and the
Flutter build installed over it without uninstalling. The state cannot be kept around permanently, so before the
test it is recreated with this procedure.

> **Warning:** `flutter test integration_test -d <simulator>` uninstalls the app and deletes its data. Do not run
> integration tests on a simulator prepared for this test.

**1. The old Swift project.** The iOS repository, commit `37f0a8e` ("update 11.2024", the App Store version).
The project does not use CocoaPods. The repository is missing the `Preview Content` directory, without which
the build fails.

**Pass the simulator only by UDID**, never by name. Names repeat: "iPhone 17" is currently three different
devices (iOS 26.0, 26.3, 27.0). `xcodebuild` builds with an ambiguous name without complaint, and `simctl`
picks a random one of them (`Unable to lookup in current state: Shutdown`). The old app then lands on a different
simulator than the Flutter build, and the test "fails" because of the procedure, not the code.

```sh
xcrun simctl list devices available   # copy the UDID of the right device
SIM="EEE75C35-E60A-47AA-9739-659B160776DE"
OLD=$(mktemp -d)
git -C /path/to/ios-repo archive 37f0a8e | tar -x -C "$OLD"
mkdir -p "$OLD/Spiewnik/Preview Content"
xcrun simctl uninstall "$SIM" com.natanielmarmucki.Spiewnik   # only if a newer version is on the simulator
xcodebuild -project "$OLD/Spiewnik.xcodeproj" -scheme Spiewnik -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$OLD/dd" build
xcrun simctl install "$SIM" "$OLD/dd/Build/Products/Debug-iphonesimulator/Spiewnik.app"
```

The old app has a scene manifest (`UIApplicationSupportsMultipleScenes`) in its `Info.plist`, so it also starts
on iOS 27: the test can run on the same system version you check the new build on.

**2. Data in the old app** (by hand in the simulator):

- 3 favorites, for example songs 3, 5 and 8;
- 2 user songs: one with several paragraphs (an empty line between verses), the other with Polish characters
  in the title and the text (for example "Pieśń na drogę", "Żółta gęś, ćma i źdźbło.");
- a font size other than the default in the settings.

Then leave the app to the home screen (Core Data saves) and close it:
`xcrun simctl terminate "$SIM" com.natanielmarmucki.Spiewnik`.

**3. Copy of the state before the test.** New data is usually only in `Model.sqlite-wal`, so copy all three files
and **do not open the database inside the container** with `sqlite3` (it checkpoints and changes the files):

```sh
C=$(xcrun simctl get_app_container "$SIM" com.natanielmarmucki.Spiewnik data)
BEFORE=$(mktemp -d)
cp "$C"/Documents/Model.sqlite* "$BEFORE"/
cp "$C/Library/Preferences/com.natanielmarmucki.Spiewnik.plist" "$BEFORE"/
(cd "$C/Documents" && shasum -a 256 Model.sqlite*) > "$BEFORE/sha256.txt"
plutil -p "$BEFORE/com.natanielmarmucki.Spiewnik.plist" | grep isSize
```

Check the contents on the copy: `sqlite3 "$BEFORE/Model.sqlite" "SELECT ZNUMBER FROM ZSONG WHERE ZFAVORITE = 1; SELECT ZTITLE FROM ZMYSONG;"`.

**4. The Flutter build on top, without uninstalling:**

```sh
flutter build ios --simulator
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$SIM" com.natanielmarmucki.Spiewnik
```

After the install the container gets a new directory, so get the `C` path again. The data stays.

**5. Checks** (after closing the app, first and second launch):

```sh
C=$(xcrun simctl get_app_container "$SIM" com.natanielmarmucki.Spiewnik data)
plutil -p "$C/Library/Preferences/com.natanielmarmucki.Spiewnik.plist" | grep -E 'flutter\.|isSize'
(cd "$C/Documents" && shasum -a 256 Model.sqlite*) | diff "$BEFORE/sha256.txt" - && echo "Model.sqlite untouched"
xcrun simctl spawn "$SIM" log show --last 5m --style compact --predicate 'process == "Runner"' | grep -F migration
```

- `flutter.coreDataMigrationDone` and `flutter.legacySettingsMigrationDone` = `true`, no `flutter.coreDataMigrationFailed`;
- `flutter.fontSize` equal to `isSize` (clamped to 10–30);
- log: "marked 3 favorites, added 2 user songs", and on the second launch "already done, skipping";
- in the app: the same favorites, user songs with their full text, no duplicates after the second launch;
- on the first launch the welcome screen "Śpiewnik w nowej odsłonie", `flutter.postMigrationWelcomeShown` = `true`
  and "Welcome screen: showing it once" in the log; on the second launch the song list right away. The screen does
  not come back even when the app was closed without tapping "Zaczynajmy": the flag is saved before the screen
  is shown;
- after uninstalling and a clean install of the same build there is **no** welcome screen (log: "no database of
  the old iOS app", no `flutter.postMigrationWelcomeShown`);
- `Model.sqlite`, `-wal` and `-shm` identical to the copy.

## Known pitfalls

### In Xcode 27 the simulator window is DeviceHub

`Simulator.app` no longer exists: `open -a Simulator` ends with "no such file", which looks like a broken
installation, but is not. The simulator window is opened with:

```sh
open "/Applications/Xcode.app/Contents/Applications/DeviceHub.app"
```

All of `xcrun simctl` works without the window anyway (`boot`, `install`, `launch`, `io <udid> screenshot`,
`ui <udid> appearance dark|light`), so screenshots and installs need no GUI. What `simctl` **cannot** do is tap
the screen: tapping needs the DeviceHub window.

### `flutter_native_splash` overwrites `UIStatusBarHidden` and Android resources

Besides the launch screen, `dart run flutter_native_splash:create` changes files it should not touch:

- in `ios/Runner/Info.plist` it sets **`UIStatusBarHidden` to `false`** (the `fullscreen` option defaults to `false`)
  and reformats the whole file. The app must have `true`, like the previous App Store version. Setting
  `fullscreen: true` in `pubspec.yaml` is not a solution, because it also changes the launch screen on Android;
- it regenerates the Android splash images in `android/app/src/main/res/drawable*/` (same picture, different bytes)
  and creates `android/app/src/main/res/values/styles.xml`, which the project does not have.

After every run of the generator:

```sh
git checkout -- ios/Runner/Info.plist     # restores UIStatusBarHidden = true
plutil -p ios/Runner/Info.plist | grep UIStatusBarHidden   # must show: true
git status android                        # revert Android changes unless they were intended:
git checkout -- android && rm -f android/app/src/main/res/values/styles.xml
```

If a change in `Info.plist` was intended in the same commit, do not restore the whole file; set
`UIStatusBarHidden` back to `true` instead.

### The iOS privacy manifest does not cover libraries without their own manifest

App Store Connect rejects a build whose code uses a required-reason API (UserDefaults, file dates, free disk space
and others) that no manifest declares. Plugins added through Swift Package Manager bring their own
`PrivacyInfo.xcprivacy`, but not all of them declare what they use: `package_info_plus` reads the app bundle dates,
and ObjectBox (Swift Package Manager, `ObjectBox.framework`) has no manifest at all. `ios/Runner/PrivacyInfo.xcprivacy` declares these reasons.

After adding or bumping an iOS plugin, build the app and check what the binaries without a manifest use:

```sh
flutter build ios --release --no-codesign
find build/ios/iphoneos/Runner.app -name PrivacyInfo.xcprivacy   # which libraries have a manifest
xcrun nm -u -j build/ios/iphoneos/Runner.app/Frameworks/ObjectBox.framework/ObjectBox \
  | grep -E '^_(f?stat|fstatat|lstat|statv?fs|getattrlist|mach_absolute_time)'
strings -a build/ios/iphoneos/Runner.app/Runner \
  | grep -xE 'fileModificationDate|fileCreationDate|creationDate|systemUptime|standardUserDefaults'
```

Plugins added through SPM are linked statically into `Runner`, so their calls show up in its binary.
