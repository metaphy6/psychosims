#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
repo_root="$PWD"
echo "▶️  Native build"

# A missing dependency is a build failure, never an implicit stub build.
if [[ ! -f native/third_party/llama.cpp/CMakeLists.txt ]]; then
  echo "❌ Missing llama.cpp submodule. Run git submodule update --init --recursive." >&2
  exit 1
fi
for patch in native/patches/*.patch; do
  [[ -e "$patch" ]] || continue
  abs_patch="$repo_root/$patch"
  pwd
  if git -C native/third_party/llama.cpp apply --check "$abs_patch" 2>/dev/null; then
    git -C native/third_party/llama.cpp apply "$abs_patch"
    echo "  ✓ applied $(basename "$patch")"
  elif git -C native/third_party/llama.cpp apply --reverse --check "$abs_patch" 2>/dev/null; then
    echo "  ✓ already applied $(basename "$patch")"
  else
    echo "❌ Incompatible pinned patch: $patch" >&2
    git -C native/third_party/llama.cpp apply --check "$abs_patch"
    exit 1
  fi
done

# Keep legacy native/build/CMakeCache.txt intact. CMake caches embed absolute
# paths; preserve any relocated build and configure a fresh directory.
build_dir="${PSY_NATIVE_BUILD_DIR:-$repo_root/native/build/current}"
mkdir -p "$build_dir"
build_dir="$(cd "$build_dir" && pwd)"
if [[ -f "$build_dir/CMakeCache.txt" ]]; then
  cache_source="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$build_dir/CMakeCache.txt")"
  cache_build="$(sed -n 's/^CMAKE_CACHEFILE_DIR:INTERNAL=//p' "$build_dir/CMakeCache.txt")"
  if [[ "$cache_source" != "$repo_root/native" || "$cache_build" != "$build_dir" ]]; then
    preserved="$build_dir.relocated.$(date -u +%Y%m%dT%H%M%SZ).$$"
    mv "$build_dir" "$preserved"
    echo "  • preserved relocated CMake artifacts at $preserved"
  fi
fi
jobs="${CMAKE_BUILD_PARALLEL_LEVEL:-4}"
pwd
cmake -S native -B "$build_dir" -DCMAKE_BUILD_TYPE=Release \
  -DPSY_NATIVE_LIBRARY_DIR="$repo_root/native/build" "$@"
pwd
cmake --build "$build_dir" --target psychosims_native native_smoke_test native_sanitizer_cycles native_sampling_test -j"$jobs"
echo "✅ Native build done (llama.cpp)"
