#!/usr/bin/env bash
# Runs the test suite with every GymMin switch off and compares the failing
# tests with tool/gymmin_expected_failures.txt. Each line of that file is
# "<test file>: <test name> ## <reason>". Needs flutter and jq on PATH.
set -uo pipefail
cd "$(dirname "$0")/.."
list=tool/gymmin_expected_failures.txt
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if grep -v '^$' "$list" | grep -v ' ## [^ ]' >&2; then
  echo "The lines above in $list have no reason after ' ## '." >&2
  exit 1
fi
sed -n 's/ ## .*//p' "$list" | sort -u > "$tmp/expected"

flutter test --dart-define=GYMMIN_OFF=true --reporter json 2>/dev/null | grep '^{' > "$tmp/events"
jq -r -s '
  (map(select(.type == "suite") | {key: (.suite.id | tostring), value: .suite.path}) | from_entries) as $files
  | (map(select(.type == "testStart") | {key: (.test.id | tostring), value: .test}) | from_entries) as $tests
  | .[] | select(.type == "testDone" and .result != "success")
  | $tests[.testID | tostring] | "\($files[.suiteID | tostring]): \(.name)"
' "$tmp/events" | sed "s|$PWD/||g" | sort -u > "$tmp/actual"

if diff -u --label expected --label actual "$tmp/expected" "$tmp/actual"; then
  echo "Failures with switches off match $list ($(wc -l < "$tmp/expected") expected)."
else
  echo "Failures with switches off differ from $list (see the diff above)." >&2
  exit 1
fi
