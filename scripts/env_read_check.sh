#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Checking for raw environment reads outside config/"

# Fail if any Dart file outside config/ reads Platform.environment.
if grep -R "Platform.environment" --include="*.dart" app packages tools 2>/dev/null; then
  echo "❌ Raw environment reads found outside config/" >&2
  exit 1
fi

echo "✅ No raw environment reads outside config/"
