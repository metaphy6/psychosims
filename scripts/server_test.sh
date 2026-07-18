#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Server tests"

(cd server && go test ./...)

echo "✅ Server tests passed"
