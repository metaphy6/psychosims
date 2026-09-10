#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Dart lint"

for pkg in config packages/psychemas packages/psycore tools app; do
  if [[ -d "$pkg" ]]; then
    echo "  • $pkg"
    (cd "$pkg" && dart analyze --fatal-infos)
  fi
done

echo "✅ Dart lint passed"
