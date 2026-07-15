#!/usr/bin/env bash
#
# Runs the Phase 2 showcase scripts (tools/showcase/*) headlessly — no Flutter,
# no model — and writes human-readable Markdown reports to
# docs/reports/showcase/, plus an INDEX.md linking them.
#
# Usage: scripts/showcase.sh
set -euo pipefail

cd "$(dirname "$0")/.."   # repo root
OUT="docs/reports/showcase"
mkdir -p "$OUT"

echo "▶️  Resolving tools package"
(cd tools && dart pub get >/dev/null)

echo "▶️  Running Phase 2 showcases"
for f in tools/showcase/showcase_*.dart; do
  echo "  • $f"
  dart run "$f"
done

echo "▶️  Writing $OUT/INDEX.md"
{
  echo "# Phase 2 — Deterministic Game Core: Capability Showcase"
  echo
  echo "_Generated $(date -u +%Y-%m-%dT%H:%MZ) by \`scripts/showcase.sh\`._"
  echo
  echo "Each report is a headless run of the pure deterministic core"
  echo "(\`packages/psycore\` + \`packages/psychemas\`) — no Flutter, no LLM, no"
  echo "model binary. Regenerate with \`scripts/showcase.sh\`."
  echo
  for md in "$OUT"/[0-9]*.md; do
    [ -e "$md" ] || continue
    title=$(head -1 "$md" | sed 's/^# //')
    echo "- [$title]($(basename "$md"))"
  done
} > "$OUT/INDEX.md"

echo "✅ Showcase complete → $OUT/INDEX.md"
