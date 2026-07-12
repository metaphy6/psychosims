# Signing-key custody plan

## Keys in scope

| Key | Purpose | Location | Rotation |
|---|---|---|---|
| Mobile app signing | iOS/Android app-store releases | Platform developer portals + HSM/YubiKey | per platform policy |
| Desktop app signing | Windows/macOS/Linux notarization | Build-machine keychain + CI secret | annually |
| Server signing | receipts, manifests, presence tokens | Server HSM / KMS, never in repo | quarterly |
| Model signature | GGUF integrity | Separate offline key, published pubkey only | per model release |

## Rules

- Private keys never leave their custody location.
- CI sees only references to secrets, never key values.
- Rotation is scripted and audited.
- This document is a plan; HSM/KMS automation is implemented in Phase 3/4.
