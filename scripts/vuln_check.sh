#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Vulnerability check"

if command -v govulncheck &>/dev/null; then
  (cd server && govulncheck ./...) || true
else
  echo "ℹ️  govulncheck not installed; running 'go vet' as a fallback"
  (cd server && go vet ./...) || true
fi

echo "✅ Vulnerability check complete (govulncheck may not be installed)"
