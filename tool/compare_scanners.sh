#!/usr/bin/env bash
# Reproduces the scanner comparison on the practice-mock artifacts.
#
# Usage: tool/compare_scanners.sh [output-folder]
#
# Generates the demo artifacts (all keys are random fakes), then runs
# flutter-key-audit and, if they are installed, gitleaks and trufflehog with
# their default settings. Those tools target source repositories; the point is
# to show what a default run reports for Flutter build output, not to rank them.
set -u

OUT="${1:-${TMPDIR:-/tmp}/fka-compare}"
mkdir -p "$OUT"

echo "== generating practice-mock artifacts in $OUT"
dart run bin/flutter_key_audit.dart demo --lang en --out "$OUT" > /dev/null || exit 1
# A real AOT ELF file (the format of Flutter's libapp.so) with a fake key.
dart run bin/flutter_key_audit.dart demo --aot --lang en --out "$OUT" > /dev/null || exit 1

echo
echo "== flutter-key-audit (direct artifacts, binary mode)"
dart run bin/flutter_key_audit.dart scan "$OUT/direct/app-release.apk" "$OUT/direct/web" \
  "$OUT/aot/keyapp_plain.aot" --format json --fail-on none |
  grep -E '"(rule|billing|review|info)"' | sort | uniq -c

if command -v gitleaks > /dev/null 2>&1; then
  echo
  echo "== gitleaks $(gitleaks version) (default config)"
  gitleaks dir "$OUT/direct" --redact -v --no-banner --no-color 2>&1 | grep -E 'RuleID|File|leaks' || echo "nothing reported"
  echo "-- AOT ELF file:"
  gitleaks dir "$OUT/aot" --redact -v --no-banner --no-color 2>&1 | grep -E 'RuleID|File|leaks|scanned'
else
  echo "(gitleaks not installed, skipped)"
fi

if command -v trufflehog > /dev/null 2>&1; then
  echo
  echo "== trufflehog $(trufflehog --version 2>&1 | tail -1) (--no-verification)"
  trufflehog filesystem "$OUT/direct" "$OUT/aot" --no-verification --no-update 2>&1 |
    grep -E 'Detector Type|File|chunks|bytes' || echo "nothing reported"
else
  echo "(trufflehog not installed, skipped)"
fi
