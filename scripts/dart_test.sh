#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Dart tests"

for pkg in config packages/psychemas packages/psycore; do
  echo "  • $pkg"
  (cd "$pkg" && dart pub get >/dev/null 2>&1 && dart test)
done

if command -v flutter >/dev/null 2>&1; then
  echo "  • app"
  (cd app && flutter pub get >/dev/null 2>&1 && flutter test)
else
  echo "  ⚠️  flutter not found; skipping app tests"
fi

echo "✅ Dart tests passed"
