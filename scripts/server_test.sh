#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Server tests"

if [[ ! -d ".pydeps" ]]; then
  scripts/server_build.sh
fi

PYTHONPATH=".pydeps:$(pwd)/server/src" python3 -m pytest server/tests -q

echo "✅ Server tests passed"
