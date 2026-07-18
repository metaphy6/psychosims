#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Checking for raw print/stdout writes outside allowed zones"

# Allowed zones where direct output is acceptable:
#   - scripts/ (CLI tooling)
#   - xops/    (ops/debug scripts)
#   - native/test/ (test harnesses)
#   - native/include/psychosims_log.h (the canonical logger implementation)
# We forbid raw writes in app/lib, native/src, server/, packages/*.

VIOLATIONS=0

scan() {
  local dir="$1"; local pattern="$2"; local desc="$3"; shift 3
  if [[ -d "$dir" ]]; then
    while IFS= read -r -d '' file; do
      # Skip generated files.
      case "$file" in
        */generated_*|*/Flutter/*|*/ephemeral/*|*/.dart_tool/*) continue ;;
      esac
      if grep -E -n "$pattern" "$file" >/dev/null 2>&1; then
        echo "  ❌ $desc in $file:"
        grep -E -n "$pattern" "$file" | head -n 5 | sed 's/^/     /'
        VIOLATIONS=$((VIOLATIONS + 1))
      fi
    done < <(find "$dir" "$@" -type f \( -name '*.dart' -o -name '*.py' -o -name '*.go' -o -name '*.cpp' -o -name '*.c' -o -name '*.h' -o -name '*.hpp' \) -print0)
  fi
}

# Dart: raw print() in app/lib or packages/ (tests are allowed for debugging).
scan app/lib 'print\(' 'raw print()'
scan packages 'print\(' 'raw print()'

# Go: bare fmt.Print / fmt.Printf / fmt.Println in the server module.
# The canonical logger writes via fmt.Fprintln(os.Stderr, ...), which is allowed.
scan server 'fmt\.Print' 'raw stdout write (use psylog)'

# C/C++: std::cout / printf / NSLog in native src/include.
scan native/src 'std::cout|printf\(|NSLog\(' 'raw stdout/log write'
# Exclude the canonical logger header; it is the only file allowed to emit.
scan native/include 'std::cout|printf\(|NSLog\(' 'raw stdout/log write' -not -name 'psychosims_log.h'

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo ""
  echo "❌ Found $VIOLATIONS raw output violation(s). Use the shared logger instead."
  echo "   See docs/code/LOGGING.md"
  exit 1
fi

echo "✅ No raw print/stdout writes found"
