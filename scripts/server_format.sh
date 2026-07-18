#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../server"

if [[ "${1:-}" == "--check" ]]; then
  echo "▶️  Server format check"
  unformatted="$(gofmt -l .)"
  if [[ -n "$unformatted" ]]; then
    echo "❌ gofmt found unformatted files:" >&2
    echo "$unformatted" >&2
    exit 1
  fi
else
  echo "▶️  Server format"
  gofmt -w .
fi

echo "✅ Server format done"
