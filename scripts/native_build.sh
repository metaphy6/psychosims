#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Native build"

# Apply pinned patches to the vendored llama.cpp submodule. Idempotent: each
# patch is applied only when it applies cleanly (i.e. not already applied), so
# re-running the build on an already-patched tree is a no-op. This keeps arm64
# reproducibility from silently depending on an unrecorded working-tree edit.
if [[ -d native/third_party/llama.cpp/.git || -f native/third_party/llama.cpp/.git ]]; then
  for patch in native/patches/*.patch; do
    [[ -e "$patch" ]] || continue
    abs_patch="$(cd "$(dirname "$patch")" && pwd)/$(basename "$patch")"
    if git -C native/third_party/llama.cpp apply --check "$abs_patch" 2>/dev/null; then
      git -C native/third_party/llama.cpp apply "$abs_patch"
      echo "  ✓ applied $(basename "$patch")"
    else
      echo "  • skipped $(basename "$patch") (already applied or not applicable)"
    fi
  done
fi

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
