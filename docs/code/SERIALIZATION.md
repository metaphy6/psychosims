# Canonical serialization

Manifests, receipts, and structured deltas use a byte-stable JSON encoding so
that signatures, checksums, and golden fixtures are reproducible across runs and
machines.

## Rules

1. **Field order is fixed** — `toJson()` uses a literal `Map` in declaration order;
   serialization libraries must preserve insertion order.
2. **No extra whitespace** in canonical form.
3. **Numbers are plain JSON numbers**; fixed-point values serialize as scaled
   integers (e.g. `cents` not `dollars`).
4. **No platform locale** in number or date formatting.
5. **Null optional fields are omitted** unless the schema marks them required.
6. **Unknown fields are ignored on parse** but preserved only if the owning
   schema allows `additionalProperties`.

## Canonical form

```json
{"id":"ent_...","schemaVersion":"0.1.0","rulesetVersion":"0.1.0","nameKey":"...","presentationKey":"..."}
```

## Golden fixtures

Every schema change that alters canonical output must update:

- `test_fixtures/manifests/sample_patient.json`
- `test_fixtures/receipts/sample_receipt.json`
- Determinism tests in `packages/psycore/`

A green test suite is the proof that serialization is stable.

## Wire compatibility

- Additive changes are allowed if old clients ignore unknown fields.
- Removing or retyping a field requires a new schema version.
- The `ruleset_version` registry records supported ranges.
