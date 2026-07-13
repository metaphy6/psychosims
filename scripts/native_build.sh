#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Native build"

# Use CMake when llama.cpp is present as a submodule; fall back to the g++ stub
# build when the submodule is empty (e.g. CI without submodule checkout).
if [[ -f native/third_party/llama.cpp/CMakeLists.txt ]]; then
  cmake -S native -B native/build -DCMAKE_BUILD_TYPE=Release
  cmake --build native/build --target psychosims_native -j"$(nproc)"
else
  echo "⚠️  llama.cpp submodule not present; building stub backend"
  mkdir -p native/build
  g++ -std=c++17 -shared -fPIC \
    -I native/include \
    native/src/psychosims_native.cpp \
    -o native/build/libpsychosims_native.so
fi

echo "✅ Native build done"
