#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Server build"

mkdir -p .pydeps

if PYTHONPATH=".pydeps:$(pwd)/server/src" python3 -c "import fastapi, pytest, ruff, mypy" 2>/dev/null; then
  echo "  (dependencies already present)"
else
  python3 -m pip install \
    --target .pydeps \
    -e "./server[dev]" \
    --quiet
fi

echo "✅ Server build done"
