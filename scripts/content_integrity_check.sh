#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Content integrity gate"

# List of banned real diagnostic / clinical terms.
BANNED=(
  "DSM-5"
  "DSM-IV"
  "ICD-10"
  "ICD-11"
  "schizophrenia"
  "bipolar disorder"
  "major depressive disorder"
)

FAIL=0
for term in "${BANNED[@]}"; do
  if grep -Riw "$term" content/ test_fixtures/ 2>/dev/null; then
    echo "❌ Banned clinical term found: $term" >&2
    FAIL=1
  fi
done

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

echo "✅ Content integrity gate passed"
