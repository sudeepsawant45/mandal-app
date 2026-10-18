# Flutter validation checklist (run on a machine that has Flutter + the Android SDK)

**Status of the Flutter app: NOT COMPILED, NOT ANALYZED, NOT TESTED, NO APK BUILT.**
The authoring environment had no Flutter, Dart or Android SDK (and cannot reach pub.dev), so nothing in `lib/` or `test/` has ever
been run through a compiler. Everything below is for you to run. Until every step in section 3 has passed on a real machine,
do not describe the app as "build-ready", "tested" or "working".

What *was* done without Flutter (details in section 5): a manual static review, a JavaScript test that cross-checks the Dart client
against the Node backend (`backend/test/flutter_contract.test.js` (lives in the backend repository)), and a simulated run of `scripts/bootstrap_android.sh` against a stub `flutter`.

---

## 1. Requirements

| Need | Notes |
|---|---|
| Flutter **stable ≥ 3.27** (includes Dart ≥ 3.6) | `pubspec.yaml` says `sdk: ^3.6.0`, `flutter: ">=3.27.0"`. Install from <https://docs.flutter.dev/get-started/install> |
| Android SDK: platform + build-tools, command-line tools | Easiest via Android Studio. Then `flutter doctor --android-licenses` |
| JDK 17 (the JDK bundled with Android Studio is fine) | the Gradle version Flutter generates decides the exact need - `flutter doctor -v` reports problems |
| Internet access to `pub.dev`, `dl.google.com`, Maven Central, Gradle plugin portal | the first Gradle build downloads a lot |
| A **real HTTPS API domain** (only for the release build/run against a server) | see section 4 |

## 2. One-time setup

Run from the repository root (the folder that contains `pubspec.yaml`).

```bash
flutter doctor -v                 # every Android line must be a green check; fix what it says before continuing
./scripts/bootstrap_android.sh    # generates android/, then applies the edits below; safe to re-run
```

`bootstrap_android.sh` (written, **never run against real Flutter**) does the following, and prints `ok`/`FAIL` for each item it can check with `grep`:
* runs `flutter create --platforms=android --project-name ganpati_mandal .` only if `android/` does not exist yet;
* restores any of your files `flutter create` changed (`lib/`, `test/`, `pubspec.yaml`, `README.md`, `analysis_options.yaml`, `.gitignore`) from a backup and **deletes the sample `test/widget_test.dart`** it generates (that sample references a `MyApp` class this app does not have and would break `flutter test`);
* adds the `INTERNET` permission;
* sets `android:allowBackup="false"` and points `fullBackupContent` / `dataExtractionRules` at "exclude everything" files, so the encrypted session token is never backed up or transferred;
* raises `minSdk` to at least 23 (`maxOf(23, flutter.minSdkVersion)`), required by `flutter_secure_storage`.

If it prints `FAIL`, read the message; typical causes are an `allowBackup` value that already existed or a Gradle layout from a newer Flutter. **Open `android/app/src/main/AndroidManifest.xml` and `android/app/build.gradle(.kts)` and look at them yourself** - the generated project has not been verified.

## 3. The checks (run in this order, stop at the first failure)

```bash
flutter pub get
flutter analyze
flutter test
```

Then the release build (needs a real domain - section 4):

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-PRODUCTION-DOMAIN
```

Record the outcome honestly:

| Step | Command | Result (fill in) |
|---|---|---|
| 1 | `flutter doctor -v` | |
| 2 | `./scripts/bootstrap_android.sh` | |
| 3 | `flutter pub get` | |
| 4 | `flutter analyze` | |
| 5 | `flutter test` | |
| 6 | `flutter build apk --release --dart-define=API_BASE_URL=https://<your real domain>` | |

### What to expect and how to treat failures

* **`flutter pub get` fails or resolves different versions.** `pubspec.lock` does not exist in the repository, so versions were never resolved. Dependencies marked `UNRESOLVED` in `pubspec.yaml` are *guesses*:
  * `flutter_secure_storage: ^9.2.4` - the code uses `AndroidOptions(encryptedSharedPreferences: true)`, valid in 9.x. Version 10.x changed the Android options; do **not** just bump the constraint, change `lib/services/token_store.dart` deliberately and re-test.
  * `flutter_riverpod: ^2.6.1` - the code uses the 2.x API (`StateNotifier`, `StateProvider`, `valueOrNull`). Riverpod 3 moves these to a legacy import; stay on 2.x.
  * `share_plus: ^11.0.0` - the code uses `SharePlus.instance.share(ShareParams(...))` (API of 11.x).
  * `path_provider ^2.1.5`, `pdf ^3.13.1`, `uuid ^4.6.0`, `flutter_lints ^5.0.0` - could not be checked against pub.dev here.
  After a green run, commit `pubspec.lock`. Do **not** run `flutter pub upgrade` to "fix" things without reading what changes.
* **`flutter analyze` exits non-zero on infos and warnings too**, not only errors. Newer Flutter releases deprecate APIs; fix real *errors* first, then read each warning/info. Do not silence the analyzer globally or delete lints to get a green run.
* **`flutter test`** runs the Dart tests, including `test/api_client_test.dart`, `session_controller_test.dart`, `repositories_test.dart` (written against a fake transport; no network). The `no_secrets_test.dart` also scans `android/`, so run it *after* bootstrap.
* **`flutter build apk --release`** with the template's default signing uses the **debug key**: fine for installing on your own phone, not for a store. Creating a release keystore is not covered and must never be committed.

## 4. The API URL (must be replaced)

* `YOUR-PRODUCTION-DOMAIN` in the build command is a **placeholder**. Replace it with the real production domain of the deployed backend, for example `https://your-project.vercel.app` (no trailing slash, **no** `/api` suffix: the app appends `/api/...` itself).
* The URL must be **https**. `ApiClient` refuses any non-https base URL in release builds (plain `http://` is accepted only in debug builds, e.g. `http://10.0.2.2:3000` for the emulator).
* Use the **production domain**, not a Vercel preview or per-deployment URL: those sit behind Vercel's login/Deployment Protection and answer with an HTML page instead of JSON.
* The value is compiled into the APK with `--dart-define`. It is public information, not a secret; never put credentials in it.
* A build made with a placeholder or a wrong domain **still compiles and installs**; every request then fails (the app shows a network/service error). If no `API_BASE_URL` is given at all, the app shows the "not configured" error. The final APK is only meaningful once the backend is deployed (that needs your explicit approval - nothing has been deployed) and you have checked, from a terminal, that `curl -i https://<domain>/api/auth/me` answers **HTTP 401 with a JSON body** `{"ok":false,...}`.
* To try the app against a local backend instead, run `cd backend && npm run dev` (needs the Vercel CLI and a `.env` with test credentials) and start the app in debug mode with `--dart-define=API_BASE_URL=http://10.0.2.2:3000`. Do not point a debug build at production data while testing.

## 5. What was verified without Flutter (and what it does *not* prove)

| Check | How | Result | What it does NOT prove |
|---|---|---|---|
| Backend tests | `cd backend && npm test` | see the final report / re-run it | nothing about Dart |
| Client ↔ server contract | `backend/test/flutter_contract.test.js` (lives in the backend repository) reads the Dart sources as **text**: every `/api/...` path and HTTP verb used by the app exists on the server; `LedgerEntry.toApiBody()` keys equal the server's accepted keys (the server rejects unknown keys); master-data bodies use allowed keys; enum and category vocabularies match; response keys the app reads are produced by the server | passes (6 tests) | that the Dart compiles, or that JSON types decode as written |
| Manual static review | read `pubspec.yaml`, `lib/services/*`, `lib/models/*`, providers, `AuthGate`, login, report export, l10n, tests | see section 6 | not a compile; subtle type errors can remain |
| Import resolution | script: every `import` in `lib/` and `test/` points to an existing file or a declared package | 0 problems | symbols inside the files |
| l10n parity | script: English and Marathi key sets are identical (224 each); every `err_*`/`v_*`/`cat_*`/`fund_*`/`pm_*`/`role_*` key the code uses exists | 0 missing | translation quality |
| `bootstrap_android.sh` | `bash -n` syntax check and a run against a **stub** `flutter` that imitates the template's files; second run left the files unchanged | passed on the stub | behaviour with the real `flutter create` output |

## 6. Findings of the static review

Fixed (clear defects, minimal change):
1. **`test/api_client_test.dart` would have failed**: it expected `http://` to be refused, but `flutter test` runs in debug mode where `ApiClient` deliberately allows plain http (`kDebugMode`). `ApiClient` now takes an `allowInsecureHttp` parameter (default `kDebugMode`, so app behaviour is unchanged); `FakeApi` passes `false` so the test checks the release rule, and a new test covers the explicit debug opt-in.
2. **`scripts/bootstrap_android.sh`** would have left the generated `test/widget_test.dart` (references a non-existent `MyApp`) in place, was not idempotent, did not set `minSdk` or `allowBackup`, and did not restore files `flutter create` may overwrite. Rewritten (see section 2).

Open / for you to decide (not changed):
* No `pubspec.lock` exists, so no dependency version has been resolved (section 3).
* `ApiClient` writes request bodies without setting `Content-Length` (Dart sends chunked encoding). The Vercel Node handler reads the stream itself, so this is expected to work, but it has not been tried against a real deployment.
* `ReportRepository.fetch` receives the server's `totals` but the PDF/report is built by the Dart `ReportBuilder` from the returned `entries`. There is no code that compares the two, so a difference between the Dart and the server calculators would not be noticed. They share the same inputs; a numeric parity test (same entries through both calculators) is still missing. The financial calculations were intentionally **not** touched.
* The `StreamController`s in the repositories are never closed (they live as long as the signed-in session; harmless but untidy).
* `SessionController` replaces its `AppUser` every 5 minutes, which rebuilds widgets that watch `currentUserProvider`/`actorProvider` (cosmetic).
* Deprecation warnings from newer Flutter releases are possible and cannot be predicted here.
