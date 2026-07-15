#!/usr/bin/env bash
#
# Runs the capability showcase scripts headlessly — no Flutter, no model — and
# writes human-readable Markdown reports under docs/reports/showcase/<phase>/,
# one folder per roadmap phase, each with its own INDEX.md, plus a root
# INDEX.md linking the phases.
#
# Layout:
#   tools/showcase/report.dart        — shared report helper (all phases)
#   tools/showcase/<phase>/*.dart     — that phase's showcase scripts
#   docs/reports/showcase/<phase>/    — that phase's generated reports
#
# Add a new phase by creating tools/showcase/phaseN/ with its scripts; this
# runner discovers it automatically.
#
# Usage: scripts/showcase.sh
set -euo pipefail

cd "$(dirname "$0")/.."   # repo root
OUT="docs/reports/showcase"
mkdir -p "$OUT"

echo "▶️  Resolving tools package"
(cd tools && dart pub get >/dev/null)

shopt -s nullglob
for phase_dir in tools/showcase/phase*/; do
  phase="$(basename "$phase_dir")"      # e.g. phase2
  phase_num="${phase#phase}"            # e.g. 2
  scripts=("$phase_dir"showcase_*.dart)
  [ ${#scripts[@]} -gt 0 ] || continue

  echo "▶️  Running ${phase} showcases"
  mkdir -p "$OUT/$phase"
  for f in "${scripts[@]}"; do
    echo "  • $f"
    dart run "$f"
  done

  echo "▶️  Writing $OUT/$phase/INDEX.md"
  {
    echo "# Phase ${phase_num} — Capability Showcase"
    echo
    echo "_Generated $(date -u +%Y-%m-%dT%H:%MZ) by \`scripts/showcase.sh\`._"
    echo
    echo "Each report is a headless run of the pure deterministic core"
    echo "(\`packages/psycore\` + \`packages/psychemas\`) — no Flutter, no LLM, no"
    echo "model binary. Regenerate with \`scripts/showcase.sh\`."
    echo
    for md in "$OUT/$phase"/[0-9]*.md; do
      [ -e "$md" ] || continue
      title=$(head -1 "$md" | sed 's/^# //')
      echo "- [$title]($(basename "$md"))"
    done
  } > "$OUT/$phase/INDEX.md"
done

echo "▶️  Writing $OUT/INDEX.md"
{
  echo "# Capability Showcase"
  echo
  echo "_Generated $(date -u +%Y-%m-%dT%H:%MZ) by \`scripts/showcase.sh\`._"
  echo
  echo "Headless runs of the pure deterministic core, organised one folder per"
  echo "roadmap phase. Regenerate with \`scripts/showcase.sh\`."
  echo
  for idx in "$OUT"/phase*/INDEX.md; do
    [ -e "$idx" ] || continue
    phase="$(basename "$(dirname "$idx")")"
    phase_num="${phase#phase}"
    echo "- [Phase ${phase_num}](${phase}/INDEX.md)"
  done
} > "$OUT/INDEX.md"

echo "✅ Showcase complete → $OUT/INDEX.md"
