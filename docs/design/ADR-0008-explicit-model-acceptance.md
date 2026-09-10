# ADR-0008 — Explicit contract and real-model acceptance gates

- **Status**: accepted
- **Date**: 2026-09-10
- **Deciders**: Codex, within the authorized remediation scope
- **Supersedes**: the identical-local-and-CI command consequence in
  [ADR-0004](ADR-0004-ci-provider.md); GitHub Actions remains the provider.

## Context

The native test harness previously treated an unavailable real model as a
successful development stub. Corrected native loading fails closed. Model
weights are out-of-band assets absent from a fresh checkout, so CI must identify
its limited evidence without weakening the real-model acceptance command.

## Decision

Keep `make verify` and `make native.acceptance` strict, and use the explicitly
named `make verify.contracts` target for CI without model weights.

## Consequences

- Both targets share build, lint, formatting, framework, Dart and Go orchestration.
- Contract verification runs explicit stub/API/error/sanitizer tests and can run
  from a fresh recursive checkout. It does not certify real-model quality.
- The two Flutter model-measurement suites carry the `model_acceptance` tag.
  Contract verification explicitly excludes that tag; the full target includes
  it and missing weights fail instead of silently skipping. All model assertions
  remain active in the full suite.
- Real-model smoke and sanitizer acceptance require local verified weights and
  fail when unavailable. Physical-device and acting-quality evidence are
  separate acceptance gates.
- The Flutter API suite exercises real weights when available and explicitly
  selects the development backend otherwise; its count alone is never evidence
  of real-model acceptance.
- A future hosted acceptance job can supply checksum-pinned weights and run the
  existing strict target. No hosted run, deployment or release is performed here.

## Considered options

- **Explicit targets (chosen):** preserves strong real acceptance while making
  the evidence from a weight-free checkout visible and reproducible.
- **Treat unavailable weights as a pass:** rejected because it hides load and
  generation failures behind a different backend.
- **Download large models in every CI run:** deferred until a reviewed artifact
  cache, immutable model pins and bandwidth budget are configured; it would not
  replace device and acting-quality acceptance.
