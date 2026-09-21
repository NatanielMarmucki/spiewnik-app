# Releasing

How to ship a new version of Śpiewnik on Android and iOS. Done by hand, step by step.

Console UI names are given in English with the Polish name in parentheses, because both consoles are used in Polish
as well: **Test and release** (**Testowanie i publikowanie**). Some of these names are not verified yet (the English
names of Play Console errors and of **+ Wersja**, and the Polish names of the other App Store Connect items); confirm
them at the next release.

**The order matters: Android first, then iOS.** Android is less risky (no migration from Core Data), and it allows
a staged rollout and halting the change. App Store review takes a few days, so a fix after release costs much more
there.

---

## What Release Please does, and what stays manual

`.github/workflows/release-please.yml` watches the Conventional Commits on `main` and keeps a release
pull request open, titled `chore(main): release <version>`. That pull request writes `CHANGELOG.md` and
the version in `pubspec.yaml`, including the build number (**+1 per release**). Merging it tags
`v<version>` and publishes a GitHub Release with the same notes. The bot never merges anything.

- **In the changelog:** `feat`, `fix`, `perf`, `revert`. Hidden: `build`, `chore`, `ci`, `docs`,
  `refactor`, `style`, `test`. A `feat` bumps the minor version, a `fix` the patch one; a
  `Release-As: 12.0.1` footer in a commit forces a version.
- **Still by hand: everything below in this document** — the builds, the checks, Play Console,
  App Store Connect, TestFlight, the store listings and the screenshots.
- **Build numbers between releases:** a round of test builds needs its own build number, bumped by hand
  (`build: bump the build number to N`, like #53). The bot adds +1 to whatever is in `pubspec.yaml` on
  `main`, so a manual bump never collides with it.
- **Token:** the workflow uses the `RELEASE_PLEASE_TOKEN` secret, a fine-grained personal access token
  limited to this repository with **Contents** and **Pull requests** set to read and write. The built-in
  `GITHUB_TOKEN` is not enough: this repository does not let Actions open pull requests, and a pull
  request opened with it would not start CI, which `main` requires before merging. The token expires;
  check its date in GitHub → Settings → Developer settings → Personal access tokens and renew it before
  then. Symptom of an expired token: the Release Please job fails with a 403 and no release pull request
  appears.

---

## 0. Before the release

```bash
git checkout main && git pull
git status                      # the tree must be clean
flutter test                    # everything green
flutter analyze
```

Bump the version in `pubspec.yaml` if this is a new release (a release from the Release Please pull
request already carries the new version and build number):

```yaml
version: 12.0.1+7
```

The first part is `versionName` (shown to users); the part after `+` is `versionCode` and `CFBundleVersion`.
**Both have to grow.** The stores reject a build with a number that has already been used.

Check which numbers are in the stores:
- Play Console → **Test and release** (**Testowanie i publikowanie**) → **App bundle explorer**
  (**Eksplorator pakietów aplikacji**)
- App Store Connect → Śpiewnik → the version page

When the song data changes, also bump `dataVersion` in `assets/songs_data.json`: without it the fixes will not
reach existing users.

---

## 1. Android

### 1.1 Build

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

The file is over 130 MB: that is debug symbols, which stay in Play for crash symbolication. Users download about
10 MB.

Signing works automatically as long as `android/key.properties` exists and points to the keystore. If the build
fails on `:app:signReleaseBundle` with a `NullPointerException`, that file is missing.

### 1.2 Upload to internal testing

1. [play.google.com/console](https://play.google.com/console) → **Śpiewnik**
2. **Test and release** (**Testowanie i publikowanie**) → **Testing** (**Testowanie**) → **Internal testing**
   (**Test wewnętrzny**)
3. **Testers** (**Testerzy**) tab: an email list with Google accounts, **Save** (**Zapisz**), copy the invite link
4. **Releases** (**Wersje**) tab → **Create new release** (**Utwórz nową wersję**)
5. **Upload** (**Prześlij**) → choose `app-release.aab`
   (in the macOS file picker: ⌘⇧G and paste the path)
6. The console shows the version number. **A signing error means stop**: the key does not match
7. **Release notes** (**Informacje o wersji**): paste the text inside the `<pl-PL>` tags, up to 500 characters
8. **Next** (**Dalej**) → review the warnings
   - yellow ones about debug symbols and the mapping file: ignore
   - red ones: stop and resolve them
9. **Save and publish** (**Zapisz i opublikuj**) → **Start rollout to Internal testing**
   (**Rozpocznij wdrażanie w ramach testu wewnętrznego**)

Internal testing does not go through Google's review: the build is available within minutes.

On the phone: open the link from step 3 → **Become a tester** (**Zostań testerem**) → update in the Play Store.

### 1.3 Production rollout

Only after checking the build on your own device.

1. In the internal testing release: **Promote release** (**Promuj wersję**) → **Production** (**Produkcja**)
2. Remove the parts of the notes meant for testers
3. Set a **staged rollout at 20%** (**stopniowe wdrażanie**)
4. **Save and publish** (**Zapisz i opublikuj**) → **Start rollout** (**Rozpocznij wdrażanie**)

Watch for 2–3 days: Android Vitals → crashes and ANRs. If it is clean, come back and raise it to 100%.

If there is a problem: **Halt rollout** (**Wstrzymaj wdrażanie**). Users who have already updated stay on the new
version; halting only stops further users from getting it.

---

## 2. iOS

### 2.1 Build

```bash
flutter build ipa
```

Output: `build/ios/ipa/spiewnik.ipa`

Requires an **Apple Distribution** certificate in the keychain:

```bash
security find-identity -v -p codesigning
```

### 2.2 Validation (optional, but worth it)

Keep the identifiers out of the repository. Create `~/.spiewnik-release.env`
(outside the project directory, `chmod 600`):

```bash
export ASC_KEY_ID=...        # from the file name AuthKey_<KeyID>.p8
export ASC_ISSUER_ID=...     # App Store Connect → Users and Access → Integrations
export ASC_APP_ID=...        # numeric App Store ID of the app
export IOS_BUNDLE_ID=...     # bundle identifier
```

Before a release: `source ~/.spiewnik-release.env`

```bash
xcrun altool --validate-app -f build/ios/ipa/spiewnik.ipa -t ios \
  --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" \
  --apple-id "$ASC_APP_ID" --output-format json
```

It looks for errors without uploading. **It does not check the reasons in `PrivacyInfo`**: those are verified only
when the uploaded build is processed.

### 2.3 Upload to TestFlight

```bash
source ~/.spiewnik-release.env

xcrun altool --upload-package build/ios/ipa/spiewnik.ipa -t ios \
  --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" \
  --apple-id "$ASC_APP_ID" --bundle-id "$IOS_BUNDLE_ID" \
  --bundle-version <build number> \
  --bundle-short-version-string <version> --wait
```

Replace the version numbers with the ones from `pubspec.yaml`.

The API key lives in `~/.appstoreconnect/private_keys/AuthKey_<KeyID>.p8`
(do not rename the file: altool looks it up by Key ID).

**Alternative without the terminal:** the **Transporter** app from the Mac App Store: drag in the `.ipa`, sign in,
click **Deliver**.

### 2.4 Processing

App Store Connect → **Śpiewnik** → **TestFlight** → status **Processing**.
It takes from a dozen or so minutes to an hour.

Two emails arrive: a receipt confirmation and the processing result.

**If the email mentions `ITMS-91053`**, Apple questioned the API usage reasons in `PrivacyInfo.xcprivacy`. The build
still reaches TestFlight, but it will be rejected when submitted to the App Store. Fix it and upload a new build
with a higher number.

### 2.5 TestFlight

1. **TestFlight** → **Internal Testing** → add a group and yourself
2. Internal testers need no Apple review: the build is available right away
3. On the iPhone: the **TestFlight** app → install

If it asks about export compliance, it should pass automatically thanks to
`ITSAppUsesNonExemptEncryption = false` in `Info.plist`.

### 2.6 Submit to the App Store

Only after checking on your own device and after Android has settled.

1. App Store Connect → **Śpiewnik** → **+ Version** (**+ Wersja**) (if it does not exist yet)
2. Fill in **What's New in This Version** (**Co nowego w tej wersji**): in Polish, without the parts meant for testers
3. Choose the build from the list
4. **Add for Review** → **Submit to App Review**

Review usually takes 1–3 days. You can choose automatic release after approval or manual release; for a big change
manual is better, so you can pick the moment.

---

## 3. After the release

- Watch crashes: Android Vitals and App Store Connect → Metrics
- Check reviews in both stores during the first week
- Tag the release in the repo: `git tag v12.0.0 && git push --tags`

---

## What to check on a device before production

Install the build **on top of** the previous version, without uninstalling:

- favorites survived the update
- user songs have their full text
- the chosen text size was kept
- the song screen reads well at the normal font size
- fast scrolling lands where it should
- search by number and by title
- on iOS: the welcome screen appeared once and did not come back after a restart

Uninstalling and a clean install is a different case: check it separately.

---

## Common problems

**Play: "signed with the wrong key"** (**„nieznany klucz podpisywania”**): `key.properties` points to a different
keystore. Compare the fingerprint: `keytool -printcert -file android/upload_certificate.pem`
with the one in Play Console → **App integrity** (**Integralność aplikacji**).

**Play: "version code has already been used"** (**„numer wersji już istnieje”**): bump the part after `+` in
`pubspec.yaml`.

**iOS: "No signing certificate"**: no Apple Distribution certificate in the keychain.
Xcode → Settings → Accounts → Manage Certificates → + → Apple Distribution.

**iOS: "PLA Update available"**: a license agreement was not accepted.
Go to [developer.apple.com/account](https://developer.apple.com/account), accept it and restart Xcode.

**altool cannot find the key**: the file must be named exactly `AuthKey_<KeyID>.p8` and live in
`~/.appstoreconnect/private_keys/`. Also check that the variables from `~/.spiewnik-release.env` are loaded
(`echo $ASC_KEY_ID`).

**Do not put identifiers or keys in the repository.** This repository is public.
`~/.spiewnik-release.env` and the `.p8` file stay outside the project.
