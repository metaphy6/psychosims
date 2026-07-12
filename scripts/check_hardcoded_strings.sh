#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Checking for hard-coded user-facing strings in app UI"

VIOLATIONS=0

# Look for obvious string literals inside Text widgets in app/lib.
# This is intentionally conservative: it flags candidates for review.
while IFS= read -r -d '' file; do
  # Skip generated files, tests, and shared stubs that intentionally return keys.
  case "$file" in
    */l10n.dart|*/generated_*|*/.dart_tool/*|*/test/*) continue ;;
  esac
  # Match Text("...") or Text('...') where the string contains a space or
  # sentence punctuation, which usually indicates real copy rather than a key.
  if grep -E -n "Text\s*\(\s*[\"'][^\"']*[ .!?,][^\"']*[\"']" "$file" >/dev/null 2>&1; then
    echo "  ❌ possible hard-coded string in $file:"
    grep -E -n "Text\s*\(\s*[\"'][^\"']*[ .!?,][^\"']*[\"']" "$file" | head -n 5 | sed 's/^/     /'
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done < <(find app/lib -name '*.dart' -print0)

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo ""
  echo "❌ Found $VIOLATIONS hard-coded string candidate(s). Externalize via app/lib/shared/l10n.dart or ARB files."
  echo "   See docs/code/LOCALIZATION.md"
  exit 1
fi

echo "✅ No obvious hard-coded UI strings found"
