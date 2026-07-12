#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CHECK_FLAG=""
if [[ "${1:-}" == "--check" ]]; then
  CHECK_FLAG="--set-exit-if-changed"
fi

echo "▶️  Dart format"

dart format $CHECK_FLAG config packages app || true

echo "✅ Dart format done"
