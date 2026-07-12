# Metrics contract

Metrics are a separate concern from logs. This document defines the minimal
schema and signal set that the cost model ([`INFRA-COST-MODEL`](../specs/INFRA-COST-MODEL.md))
and the Phase 6.6 balance oracle consume. No collection pipeline is built yet;
this is the contract future instrumentation must implement.

## Schema

Every metric sample is one of:

```json
{
  "ts": "2026-07-12T14:53:28.123Z",
  "name": "inference.latency_ms",
  "type": "timer",
  "value": 123.0,
  "unit": "ms",
  "scope": "native:inference",
  "correlation_id": "sess_...",
  "labels": {"model_tier": "A", "device_class": "mid"}
}
```

Types: `counter`, `timer`, `gauge`.

## Required signal set

| Metric | Type | Why |
|--------|------|-----|
| `session.turns_total` | counter | Usage basis for server cost estimates. |
| `inference.latency_ms` | timer | Device-viability gate (Phase 1.6). |
| `inference.tokens_per_sec` | gauge | Model acting-quality comparisons. |
| `model.ram_peak_mb` | gauge | Memory budget ([`DEVICE-SPEC`](../specs/DEVICE-SPEC.md)). |
| `model.download.bytes` | counter | CDN cost and data-cap tracking. |
| `api.request_total` | counter | Server load and abuse-limit monitoring. |
| `api.error_total` | counter | Aggregated by `error_kind`. |
| `economy.mint_total` | counter | Hard guard against currency inflation. |
| `economy.burn_total` | counter | Hard guard against currency deflation. |

## Privacy rules

- Metrics carry no transcripts, prompts, or PII.
- Labels may include coarse device class and model tier, never user id or session
text.
- Crash reporting is covered by the [telemetry contract](TELEMETRY.md), not metrics.

## Collection posture

- Client metrics are aggregated in-memory and flushed in batches on a background
isolate.
- Server metrics flush to the configured sink (TBD in Phase 6.6).
- All collection is opt-in where required by platform policy.
