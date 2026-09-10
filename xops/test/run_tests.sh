#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

echo "▶️  xops framework tests"

# Exercise project checkers with isolated tools and planted failures.
python3 -m unittest discover -s xops/test -p 'test_*.py' -v

make doctor

echo "✅ xops tests passed"
