#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

FORMAT_FLAGS=()
if [[ "${1:-}" == "--check" ]]; then
  FORMAT_FLAGS=(--output=none --set-exit-if-changed)
fi

echo "▶️  Dart format"

dart format "${FORMAT_FLAGS[@]}" config packages app tools

echo "✅ Dart format done"
