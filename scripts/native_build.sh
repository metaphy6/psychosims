#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Native build"

mkdir -p native/build
g++ -std=c++17 -shared -fPIC \
  -I native/include \
  native/src/psychosims_native.cpp \
  -o native/build/libpsychosims_native.so

echo "✅ Native build done"
