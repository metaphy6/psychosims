#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Generating SBOM"

mkdir -p reports

# Dart SBOM via pubspec.lock when available; fallback to pubspec.yaml summaries.
{
  echo "=== Dart packages ==="
  for pkg in config packages/psychemas packages/psycore app; do
    echo "--- $pkg ---"
    (cd "$pkg" && cat pubspec.yaml)
  done

  echo "=== Go modules ==="
  if [[ -f "server/go.mod" ]]; then
    (cd server && go list -m all 2>/dev/null || cat go.mod)
  else
    echo "(no server/go.mod found)"
  fi
} > reports/sbom.txt

echo "✅ SBOM written to reports/sbom.txt"
