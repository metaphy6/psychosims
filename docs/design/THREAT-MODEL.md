# Threat model stub

## Boundaries

- Client (`app/`) ↔ Native (`native/`) over FFI
- Client ↔ Server (`server/`) over HTTPS/WebSocket
- Server ↔ Database (BaaS Postgres)
- Server ↔ CDN (signed manifests)

## Assets

- Authoritative profile + economy ledger (server database)
- Receipt idempotency keys and ownership proofs
- Auth tokens and signing keys
- The local model file (integrity, license compliance)

## Threats

1. **Forged receipts** → mitigated by server-side validation + ruleset pinning.
2. **Double-spend of ownership** → mitigated by atomic server-side arbitration.
3. **Secret leakage** → mitigated by secret-by-reference + scanning.
4. **Model tampering** → mitigated by checksum/signature verification on fetch.
5. **Prompt injection via UGC** → mitigated by schema whitelisting + sanitization.
6. **Data loss of authoritative store** → mitigated by backup/DR conventions.

## Deferred to Phase 2 / Phase 3

Detailed abuse-prevention rules, audit-trail implementation, backup drills, and
key-custody automation begin after the Phase 1 PoC exit gates pass.
