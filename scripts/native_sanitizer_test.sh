#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▶️  Native sanitizer build + cycles"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --contracts-only ) ]]; then
  echo "usage: $0 [--contracts-only]" >&2
  exit 64
fi
build_dir="$PWD/native/build-san/current"
PSY_NATIVE_BUILD_DIR="$build_dir" scripts/native_build.sh \
  -DCMAKE_BUILD_TYPE=Debug \
  -DPSY_NATIVE_LIBRARY_DIR="$build_dir" \
  -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g" \
  -DCMAKE_C_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g" \
  -DCMAKE_SHARED_LINKER_FLAGS="-fsanitize=address,undefined" \
  -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined" \
  -DGGML_CCACHE=OFF
export ASAN_OPTIONS=detect_leaks=1:abort_on_error=1
export UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1
pwd
# safe-run uses stdbuf, whose inherited preload would precede linked libasan.
env -u LD_PRELOAD "$build_dir/test/native_sampling_test"
pwd
env -u LD_PRELOAD "$build_dir/test/native_smoke_test" --contracts-only
if [[ "${1:-}" == --contracts-only ]]; then
  echo "✅ Sanitized native contracts passed; real-model cycles were explicitly not requested"
else
  pwd
  env -u LD_PRELOAD "$build_dir/test/native_sanitizer_cycles" "${PSY_MODEL_PATH:-$PWD/assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf}"
  echo "✅ Native sanitizer real-model cycles passed"
fi
