#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Server lint"

if [[ ! -d ".pydeps" ]]; then
  scripts/server_build.sh
fi

PYTHONPATH=".pydeps:$(pwd)/server/src" python3 -m ruff check server/src server/tests
PYTHONPATH=".pydeps:$(pwd)/server/src" python3 -m mypy server/src

echo "✅ Server lint passed"
