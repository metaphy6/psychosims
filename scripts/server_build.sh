#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Server build"

(cd server && go build ./...)

echo "✅ Server build done"
