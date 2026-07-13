#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Native sanitizer build + cycles"

rm -rf native/build-san

cmake -S native -B native/build-san \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_FLAGS="-fsanitize=address,leak -g" \
  -DCMAKE_C_FLAGS="-fsanitize=address,leak -g" \
  -DCMAKE_SHARED_LINKER_FLAGS="-fsanitize=address,leak" \
  -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,leak" \
  -DGGML_CCACHE=OFF

cmake --build native/build-san --target psychosims_native -j"$(nproc)"

g++ -std=c++17 -fsanitize=address,leak -g \
  -I native/include \
  native/test/native_sanitizer_cycles.cpp \
  -L native/build-san \
  -lpsychosims_native \
  -Wl,-rpath,native/build-san \
  -o native/build-san/native_sanitizer_cycles

LD_LIBRARY_PATH=native/build-san \
  ASAN_OPTIONS=detect_leaks=1:abort_on_error=0 \
  ./native/build-san/native_sanitizer_cycles

echo "✅ Native sanitizer cycles passed"
