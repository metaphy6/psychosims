#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  No-durable-transcript check"

# Fail if any Dart/Go/Python code writes a raw dialogue string to a durable store.
if grep -Riw "transcript" --include="*.dart" --include="*.go" --include="*.py" app server packages 2>/dev/null | grep -iw "write\|save\|persist\|store"; then
  echo "❌ Possible durable transcript write found" >&2
  exit 1
fi

echo "✅ No obvious durable transcript writes found"
