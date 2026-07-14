#!/usr/bin/env bash
# Core purity gate for packages/psycore.
#
# Fails the build if deterministic code paths contain banned constructs:
#   - dart:math Random
#   - double literals/types outside the fixed-point config-boundary file
#   - DateTime.now or other wall-clock reads
#   - mutable top-level/static state
#
# This is a conservative smoke test; the fixed-point boundary file is exempt
# from the double ban because it owns the single documented conversion seam.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Core purity gate"

fail=0

# Ban dart:math Random in core.
if grep -R --include='*.dart' -n "import 'dart:math'" packages/psycore/lib; then
  echo "❌ dart:math import found in packages/psycore/lib" >&2
  fail=1
fi

# Ban Random constructor/use in core (skip comments containing the word).
if grep -R --include='*.dart' -nE '\bRandom[(:]' packages/psycore/lib | grep -vE '^[^:]*:[0-9]+:[[:space:]]*//'; then
  echo "❌ Random usage found in packages/psycore/lib" >&2
  fail=1
fi

# Ban DateTime.now in core (wall-clock leak).
if grep -R --include='*.dart' -n 'DateTime\.now(' packages/psycore/lib; then
  echo "❌ DateTime.now found in packages/psycore/lib" >&2
  fail=1
fi

# Ban double literals/types in core except the fixed-point boundary file and
# comments/strings. Uses Python to strip line comments before scanning.
python3 - <<'PY' || fail=1
import re, sys, pathlib
root = pathlib.Path('packages/psycore/lib')
for path in root.rglob('*.dart'):
    if path.name == 'fixed_point.dart':
        continue
    text = path.read_text()
    # Strip line comments (not string-safe, but good enough for smoke test).
    lines = text.splitlines()
    for i, line in enumerate(lines, start=1):
        code = line.split('//')[0]
        # Remove string literals to avoid false positives.
        code = re.sub(r"'[^']*'", "''", code)
        code = re.sub(r'"[^"]*"', '""', code)
        if re.search(r'\bdouble\b|[0-9]+\.[0-9]+', code):
            print(f'{path}:{i}: {line.strip()}')
            sys.exit(1)
PY

# Ban mutable top-level/static state.
# Flags top-level `var`/`late`, class-level `static var`/`static late`, and
# `static final` collection declarations (Map/List/Set) because the `final`
# reference does not make the collection immutable. Use `static const` for
# immutable collections.
python3 - <<'PY' || fail=1
import re, pathlib, sys
root = pathlib.Path('packages/psycore/lib')
for path in root.rglob('*.dart'):
    text = path.read_text()
    lines = text.splitlines()
    for i, line in enumerate(lines, start=1):
        code = line.split('//')[0]
        if re.search(r'^\s*static\s+(?:var|late)\b', code):
            print(f'{path}:{i}: {line.strip()}')
            sys.exit(1)
        if re.search(r'^(?:var|late)\b', code):
            print(f'{path}:{i}: {line.strip()}')
            sys.exit(1)
        if re.search(r'^\s*static\s+final\s+(?:Map|List|Set)\s*<', code):
            print(f'{path}:{i}: {line.strip()}')
            sys.exit(1)
PY

if [ "$fail" -eq 1 ]; then
  echo "❌ Core purity gate failed" >&2
  exit 1
fi

echo "✅ Core purity gate passed"
