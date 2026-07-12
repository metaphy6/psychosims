#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

echo "▶️  xops framework tests"

# Framework has no standalone test suite yet; doctor covers wiring.
make doctor

echo "✅ xops tests passed"
