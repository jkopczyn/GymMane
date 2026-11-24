#!/usr/bin/env bash
# Builds the release APK and compares the permissions it requests, including
# the ones merged in from libraries, with tool/gymmin_apk_permissions.txt.
# Pass --no-build to check the APK from an earlier build. Needs flutter on PATH
# and aapt2 at $AAPT2 or in $ANDROID_HOME/build-tools/36.0.0.
set -euo pipefail
cd "$(dirname "$0")/.."
list=tool/gymmin_apk_permissions.txt
apk=build/app/outputs/flutter-apk/app-release.apk
aapt2=${AAPT2:-$ANDROID_HOME/build-tools/36.0.0/aapt2}

if grep -nE 'INTERNET|\.health\.' "$list" >&2; then
  echo "The lines above in $list name a network or Health Connect permission." >&2
  exit 1
fi

if [[ "${1:-}" != "--no-build" ]]; then
  flutter build apk --release
fi

expected=$(grep -v '^$' "$list" | sort -u)
actual=$("$aapt2" dump permissions "$apk" | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" | sort -u)

if diff -u --label expected --label actual <(echo "$expected") <(echo "$actual"); then
  echo "The permissions in $apk match $list ($(echo "$expected" | wc -l) permissions)."
else
  echo "The permissions in $apk differ from $list (see the diff above)." >&2
  exit 1
fi
