# Performance budgets

These targets anchor the Phase 1.6 device-viability gate. They are **targets**
now and **measured baselines** once the PoC is running.

## Device floor

See [`DEVICE-SPEC`](../specs/DEVICE-SPEC.md). The minimum viable device class is:

- 4 GB RAM Android / 8 GB RAM desktop
- OpenGL ES 3.0 / Vulkan 1.0 compatible GPU
- 64-bit ARMv8 or x86_64 CPU

## Budgets

| Concern | Target | Measured at | Notes |
|---------|--------|-------------|-------|
| App cold start | ≤ 2.5 s | Phase 1.6 | From tap to interactive home screen. |
| First model download | resumable, ≤ 2 GB over Wi-Fi | Phase 1.6 | Cellular deferrable; see networking convention. |
| Model load into RAM | ≤ 8 s | Phase 1.6 | From download complete to first token. |
| Inference latency (turn) | ≤ 2.5 s p95 | Phase 1.6 | End-to-end prompt → first usable token. |
| Inference throughput | ≥ 8 tok/s on min-spec | Phase 1.6 | Sustained generation speed. |
| Peak RAM with model | ≤ 2.5 GB on 4 GB device | Phase 1.6 | Leaves headroom for OS and UI. |
| UI frame time | ≤ 16.6 ms (60 fps) | Phase 1.6 | Inference and heavy work off UI isolate. |
| Final APK/IPA overhead | ≤ 150 MB excluding model | Phase 1.6 | Code + assets before first download. |
| Binary size (desktop) | ≤ 250 MB excluding model | Phase 1.6 | Steam / direct-download installer. |
| Receipt upload | ≤ 5 s on 3G | Phase 3 | Mutating request with idempotency key. |

## Measurement rules

- Use release/profile builds, not debug builds.
- Run on the minimum-spec reference device and a mid-tier comparator.
- Report p50, p95, and max over at least 20 turns.
- Any regression > 10 % from the measured baseline fails the gate.

## Files

- Budgets live here.
- Measured results are recorded in `docs/reports/<date>-device-viability-assessment.md`.
- The `make verify` gate checks that these files exist and are referenced.
