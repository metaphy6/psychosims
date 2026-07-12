#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -d ".pydeps" ]]; then
  scripts/server_build.sh
fi

if [[ "${1:-}" == "--check" ]]; then
  echo "▶️  Server format check"
  PYTHONPATH=".pydeps:$(pwd)/server/src" python3 -m ruff format --check server/src server/tests
else
  echo "▶️  Server format"
  PYTHONPATH=".pydeps:$(pwd)/server/src" python3 -m ruff format server/src server/tests
fi

echo "✅ Server format done"
