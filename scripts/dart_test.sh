#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Dart tests"

for pkg in config packages/psychemas packages/psycore; do
  echo "  • $pkg"
  (cd "$pkg" && dart pub get >/dev/null 2>&1 && dart test)
done

echo "✅ Dart tests passed"
