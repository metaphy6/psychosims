#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Native tests"

scripts/native_build.sh

g++ -std=c++17 \
  -I native/include \
  native/test/native_smoke_test.cpp \
  -L native/build \
  -lpsychosims_native \
  -Wl,-rpath,native/build \
  -o native/build/native_smoke_test

LD_LIBRARY_PATH=native/build ./native/build/native_smoke_test

echo "✅ Native tests passed"
