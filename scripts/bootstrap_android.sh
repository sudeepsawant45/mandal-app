#!/usr/bin/env bash
# One-time (and safe to re-run) helper: generate the Android platform folder, then
# apply the manual edits this app needs.
#
# STATUS: WRITTEN BUT NOT RUN. Authored on a machine without Flutter, so neither the
# script nor the Android project it generates has been verified. Read the output.
#
# Usage: ./scripts/bootstrap_android.sh [org-id, default com.example]
#
# Idempotent: every edit checks whether it is already applied; re-running does not
# duplicate attributes or permissions. It never touches backend/ or any Dart file
# you wrote (files that `flutter create` changed are restored from a backup).
set -euo pipefail
cd "$(dirname "$0")/.."
ORG="${1:-com.example}"

command -v flutter >/dev/null || { echo "flutter not found on PATH (see docs/FLUTTER_VALIDATION.md)"; exit 1; }

PROTECTED_FILES=(pubspec.yaml README.md analysis_options.yaml .gitignore)

# Safety net: keep a copy of hand-written sources in case `flutter create` touches them.
BK="$(mktemp -d)"
cp -r lib test "$BK"/
for f in "${PROTECTED_FILES[@]}"; do [ -e "$f" ] && cp "$f" "$BK"/"$f"; done
echo "Backup of lib/ test/ and ${PROTECTED_FILES[*]}: $BK"

MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ]; then
  echo "android/ already exists - skipping 'flutter create' (delete android/ to regenerate)"
else
  flutter create --platforms=android --org "$ORG" --project-name ganpati_mandal .
fi

# `flutter create .` can overwrite files and adds a sample test (test/widget_test.dart)
# that references a MyApp class this app does not have; it would break `flutter test`.
for f in "${PROTECTED_FILES[@]}"; do
  if [ -e "$BK/$f" ] && ! cmp -s "$BK/$f" "$f"; then cp "$BK/$f" "$f"; echo "restored $f"; fi
done
while IFS= read -r f; do
  if ! cmp -s "$BK/$f" "$f" 2>/dev/null; then cp "$BK/$f" "$f"; echo "restored $f"; fi
done < <(cd "$BK" && find lib test -type f)
if [ -f test/widget_test.dart ] && [ ! -f "$BK/test/widget_test.dart" ]; then
  rm test/widget_test.dart; echo "removed generated test/widget_test.dart"
fi

[ -f "$MANIFEST" ] || { echo "!! $MANIFEST was not generated; stop here and check the flutter create output"; exit 1; }

# 1. INTERNET permission (the release manifest of the template does not have it).
if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  sed -i 's#<manifest xmlns:android="http://schemas.android.com/apk/res/android">#&\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$MANIFEST"
fi

# 2. Backups: the session token lives in Android encrypted storage; it must never be
#    copied to cloud backup or device-to-device transfer (the keystore key would not
#    follow it anyway, leaving a broken entry). Disable backup and exclude everything.
XML_DIR=android/app/src/main/res/xml
mkdir -p "$XML_DIR"
cat > "$XML_DIR/data_extraction_rules.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup><exclude domain="root" path="."/></cloud-backup>
    <device-transfer><exclude domain="root" path="."/></device-transfer>
</data-extraction-rules>
XML
cat > "$XML_DIR/backup_rules.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content><exclude domain="root" path="."/></full-backup-content>
XML
if ! grep -q "android:allowBackup" "$MANIFEST"; then
  sed -i 's#<application#<application\n        android:allowBackup="false"\n        android:fullBackupContent="@xml/backup_rules"\n        android:dataExtractionRules="@xml/data_extraction_rules"#' "$MANIFEST"
fi

# 3. minSdk >= 23 (flutter_secure_storage). maxOf/Math.max keeps a higher Flutter default.
for G in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$G" ] || continue
  if grep -q "maxOf(23\|Math.max(23" "$G"; then continue; fi
  sed -i -E 's/minSdk = flutter\.minSdkVersion/minSdk = maxOf(23, flutter.minSdkVersion)/; s/minSdkVersion flutter\.minSdkVersion/minSdkVersion Math.max(23, flutter.minSdkVersion)/' "$G"
done

# ---- verification of what this script is responsible for (not a build) ----
FAIL=0
chk() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAIL=1; fi; }
chk "INTERNET permission"            "grep -q 'android.permission.INTERNET' '$MANIFEST'"
chk "allowBackup=false"              "grep -q 'android:allowBackup=\"false\"' '$MANIFEST'"
chk "data extraction rules wired"    "grep -q 'android:dataExtractionRules=\"@xml/data_extraction_rules\"' '$MANIFEST'"
chk "minSdk >= 23 (maxOf/Math.max)"  "grep -qE 'maxOf\\(23|Math\\.max\\(23' android/app/build.gradle.kts android/app/build.gradle 2>/dev/null"
chk "no generated sample test"       "[ ! -f test/widget_test.dart ] || [ -f '$BK/test/widget_test.dart' ]"
chk "no Firebase / Google Services"  "! grep -rqi 'google-services\\|firebase' android --include=*.gradle --include=*.kts --include=*.xml --include=*.json"
if [ "$FAIL" -ne 0 ]; then
  echo
  echo "Some checks failed. If allowBackup already had a value, or the manifest merger reports a conflict,"
  echo "edit $MANIFEST by hand: add xmlns:tools to <manifest> and tools:replace=\"android:allowBackup\" on <application>."
  echo "If minSdk was written differently by your Flutter version, set it to at least 23 manually."
  exit 1
fi

echo
echo "Done (checked by grep only - the generated Android project has NOT been built)."
echo "Next: flutter pub get && flutter analyze && flutter test, then the release build in docs/FLUTTER_VALIDATION.md."
echo "Backup of your sources, in case anything looks wrong: $BK"
