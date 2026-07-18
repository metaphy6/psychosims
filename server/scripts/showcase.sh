#!/usr/bin/env bash
#
# Runs the Phase 3 Go capability showcase scripts headlessly and writes
# Markdown reports under docs/reports/showcase/phase3/.
#
# Usage: server/scripts/showcase.sh
set -euo pipefail

cd "$(dirname "$0")/../.."   # repo root
OUT="docs/reports/showcase/phase3"
mkdir -p "$OUT"

echo "▶️  Running Phase 3 Go showcases"
(cd server/tools/showcase/phase3 && go run .)

echo "▶️  Writing $OUT/INDEX.md"
{
  echo "# Phase 3 — Server-Side Capability Showcase"
  echo
  echo "_Generated $(date -u +%Y-%m-%dT%H:%MZ) by \`server/scripts/showcase.sh\`._"
  echo
  echo "Each report is a headless run of the Go control-plane packages — no Flutter,"
  echo "no LLM, no model binary. Regenerate with \`server/scripts/showcase.sh\`."
  echo
  for md in "$OUT"/*.md; do
    [ -e "$md" ] || continue
    title=$(head -1 "$md" | sed 's/^# //')
    echo "- [$title]($(basename "$md"))"
  done
} > "$OUT/INDEX.md"

echo "✅ Phase 3 showcase complete → $OUT/INDEX.md"
