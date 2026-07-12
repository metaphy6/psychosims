#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Coverage report"

for pkg in config packages/psychemas packages/psycore; do
  echo "  • $pkg"
  (cd "$pkg" && dart test --coverage=coverage && dart pub global run coverage:format_coverage --in=coverage --out=coverage/lcov.info --report-on=lib)
done

echo "✅ Coverage reports written to coverage/lcov.info in each package"
