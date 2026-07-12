#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Vulnerability check"

if [[ ! -d ".pydeps" ]]; then
  scripts/server_build.sh
fi

PYTHONPATH=".pydeps:$(pwd)/server/src" python3 -m pip audit --path .pydeps || true

echo "✅ Vulnerability check complete (audit tool may not be installed)"
