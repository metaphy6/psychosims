#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Server lint"

cd server

go vet ./...

unformatted="$(gofmt -l .)"
if [[ -n "$unformatted" ]]; then
  echo "❌ gofmt found unformatted files:" >&2
  echo "$unformatted" >&2
  echo "   run 'make server.format' to fix" >&2
  exit 1
fi

echo "✅ Server lint passed"
