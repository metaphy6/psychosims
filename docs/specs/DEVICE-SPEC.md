# 📱 C-1 — Minimum device specification

> **Closes register item C-1** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> The concrete hardware floor the §1 device-viability gate measures against.
> Without this, that gate is meaningless. Section refs (§N) → [`STARTER.md`](../../STARTER.md).

- **Status:** drafted (a *target floor*; confirmed on physical hardware in Phase 1.6)
- **Owner:** @maintainer
- **Consumed by:** Phase 1.1 (FFI integration), Phase 1.6 (device-viability gate), Phase 7.6 (store minimums)

## Why a written floor exists first

The PoC's device-viability gate (§1) measures tokens/sec and peak RAM "on at
least one physical minimum-spec device." That sentence is undefined until *this*
document names the floor. The shipped model size (§5) is an **outcome** of
measuring against this floor — not an assumption.

## The floor (target, per platform)

The binding constraint is RAM headroom for a ~1.8 GB quantized model plus the
Flutter app plus the OS. A 3B Q4 model needs meaningfully more than its file
size at runtime (KV cache + weights + working set).

| Platform | Floor target | Rationale |
|---|---|---|
| **Android** | 6 GB RAM, arm64-v8a, Android 10 (API 29)+, 2021+ mid-range SoC | 6 GB leaves headroom for a 3B Q4 model; 4 GB devices route to the 1–1.5B fallback (§5). |
| **iOS** | A13 Bionic (iPhone 11)+, iOS 15+, 4 GB RAM | A13+ NPU/CPU class runs small GGUF acceptably; older devices excluded. |
| **Linux desktop** | x86-64 with AVX2, 8 GB RAM | Dev baseline + player floor; AVX2 is llama.cpp's practical CPU floor. |
| **Windows desktop** | Windows 10 (64-bit)+, x86-64 AVX2, 8 GB RAM | Matches Linux; ARM Windows deferred. |
| **macOS** | Apple Silicon (M1)+, macOS 12+ | Metal-accelerated; Intel Macs deferred pending measurement. |

## The two-tier model policy (ties to §5)

- **Tier A — primary (~3B Q4, ~1.8 GB):** targets the 6 GB Android floor and all desktops.
- **Tier B — fallback (1–1.5B Q4, smaller footprint):** shipped to 4 GB-class devices.
  Selecting Tier B makes the acting-quality bar harder, so the two are measured
  **together** at the PoC (§1). Which tier a device receives is resolved by a
  device-capability check at first run, configured through the central config
  authority (Principle 1).

## Falsifiable gate (measured in Phase 1.6, not here)

On a physical floor device (never the emulator — §1):
- **Peak RAM** stays within the device budget with the OS + app resident.
- **Tokens/sec** clears a playability threshold (target owned by the PoC report).
- If the primary tier fails the 6 GB floor, the Tier B fallback is validated in the same pass.

## Open (resolved at measurement time)

- Exact tokens/sec playability threshold — set in the Phase 1.6 PoC exit report.
- Whether the Android floor can drop to 4 GB on Tier B alone — a measurement outcome.
- Physical-device testing is a **human-gated** milestone (§1); until opened, this
  floor is a target and the viability gate is explicitly *pending*.
