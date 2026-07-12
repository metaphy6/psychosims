# Shared-schema strategy

The server runtime decision ([ADR-0003](../design/ADR-0003-server-runtime.md))
chose Python/FastAPI for the authoritative server while the client is
Dart/Flutter. This means the schema contract must stay aligned across two
languages.

## Strategy: one canonical Dart package + one mirrored Pydantic module

- **Dart** owns the canonical in-memory schema under `packages/psychemas/`.
- **Python** mirrors it under `server/src/psychosims_server/schemas.py`.
- Both derive their `schemaVersion` and `rulesetVersion` from the same
  [`config/ruleset_registry.yaml`](../config/ruleset_registry.yaml).

## Language-neutral contract

A JSON Schema description of each payload lives in `packages/psychemas/schema/`
(planned). It is the arbiter when the two implementations disagree:

- New fields are added to the JSON Schema first.
- Dart and Python implementations are updated in the same commit.
- Contract tests assert round-trip parity.

## Current payloads

| Payload | Dart | Python | Golden fixture |
|---------|------|--------|----------------|
| `PatientManifest` | `packages/psychemas/lib/src/manifest.dart` | `server/src/psychosims_server/schemas.py` | `test_fixtures/manifests/sample_patient.json` |
| `SessionReceipt` | `packages/psychemas/lib/src/receipt.dart` | `server/src/psychosims_server/schemas.py` | `test_fixtures/receipts/sample_receipt.json` |
| `StructuredDelta` | `packages/psychemas/lib/src/structured_delta.dart` | `server/src/psychosims_server/schemas.py` | inline in receipt fixture |

## Change discipline

- A schema change requires updates to Dart, Python, fixtures, and tests in one
  commit.
- The `schemaVersion` field in each payload must match the registry.
- A mismatch fails `make verify`.
