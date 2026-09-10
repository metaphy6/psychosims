#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▶️  Native tests"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --contracts-only ) ]]; then
  echo "usage: $0 [--contracts-only]" >&2
  exit 64
fi
pwd
python3 native/test/native_build_test.py
scripts/native_build.sh
build_dir="${PSY_NATIVE_BUILD_DIR:-$PWD/native/build/current}"
pwd
"$build_dir/test/native_sampling_test"
pwd
"$build_dir/test/native_smoke_test" --contracts-only
if [[ "${1:-}" == --contracts-only ]]; then
  echo "✅ Native contracts passed; real-model acceptance was explicitly not requested"
else
  pwd
  "$build_dir/test/native_smoke_test" "${PSY_MODEL_PATH:-$PWD/assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf}"
  echo "✅ Native contracts and real-model inference passed"
fi
