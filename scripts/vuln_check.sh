#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Vulnerability check"

if [[ -x .tools/bin/govulncheck ]]; then
  scanner="$PWD/.tools/bin/govulncheck"
elif command -v govulncheck &>/dev/null; then
  scanner="$(command -v govulncheck)"
else
  echo "❌ govulncheck is required; run scripts/bootstrap.sh to install the pinned project-local scanner" >&2
  exit 127
fi

(cd server && "$scanner" ./...)
bash scripts/sbom.sh
python3 scripts/dependency_scan.py

echo "✅ Vulnerability check passed"
