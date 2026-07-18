# Phase 3.5 — Signing-key custody & rotation plan

## Status

Interface + rotation mechanism implemented; production custody automation is
**⏭ hardened later** (Phase 7.6 / 0.6 security hardening pass).

## What is implemented now

- `devicekeys.Service.Provision` certifies a per-device Ed25519 public key and
  binds it to a server-authoritative account.
- `devicekeys.Service.Recover` re-provisions a key on reinstall / device-switch
  and optionally revokes the previous key.
- `devicekeys.RotationPolicy` defines an overlapping validity window so a record
  signed under the previous suite remains verifiable during rotation.
- `devicekeys.Service.VerifyRecord` enforces the rotation window and rejects
  revoked keys.
- The revocation list is published via `devicekeys.RevocationHandler` with
  `ETag` / `Cache-Control` so clients can drop revoked entries cheaply.
- The server signing key for presence records is injected at startup; no private
  key material lives in the repository.

## Production custody hardening (future)

- Server signing keys: store in a managed KMS/HSM (e.g. AWS KMS, Google Cloud
  HSM, HashiCorp Vault) and perform signing operations through the KMS API.
- Device private keys: remain on-device in platform secure storage
  (Keychain / Keystore / OS credential store); never transmit private bytes.
- Rotation cadence: rotate server signing keys on a documented schedule (e.g.
  annually or on suspected compromise), using overlapping validity windows.
- Access control: restrict key-management operations to audited break-glass
  roles with MFA; log every rotation and revocation to the hash-chained audit
  trail.

## References

- `server/internal/devicekeys/devicekeys.go`
- `server/internal/devicekeys/revocation.go`
- `docs/project/SIGNING-KEY-CUSTODY.md` (Phase 0.6 baseline)
