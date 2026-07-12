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

  echo "=== Python packages ==="
  if [[ -d ".pydeps" ]]; then
    PYTHONPATH=".pydeps:$(pwd)/server/src" python3 -m pip freeze --path .pydeps
  else
    echo "(run scripts/server_build.sh first)"
  fi
} > reports/sbom.txt

echo "✅ SBOM written to reports/sbom.txt"
