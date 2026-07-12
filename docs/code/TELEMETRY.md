# Privacy-scrubbed telemetry & crash-reporting contract

This document defines what the Phase 6.6 balance oracle (and any other analytics)
is allowed to receive. It is a **contract**, not a pipeline: no telemetry is
collected in Phase 0.

## Opt-in posture

Per [DECISION 0006](../project/DECISION_LOG.md), telemetry and crash reporting
are **opt-in** except where platform policy requires otherwise. The default
build ships with collection disabled.

## Allowed schema

Telemetry events carry only the following fields:

```json
{
  "ts": "2026-07-12T14:53:28.123Z",
  "event": "session_summary",
  "session_id_hash": "sha256:<hash>",
  "kv": {
    "turns": 12,
    "model_tier": "A",
    "device_class": "mid",
    "outcome": "completed"
  }
}
```

- `session_id_hash` is a one-way hash of the correlation id; it cannot be used
to recover transcript or identity.
- `kv` values are numeric or enum only. No strings that originated from gameplay.

## Scrubbing rules

| Never transmit | Rationale |
|----------------|-----------|
| Raw dialogue transcripts | §17 no-durable-transcript rule. |
| Prompt text | Includes user-controlled input; scrub to token count + content hash. |
| Patient names / manifests with narrative fields | Narrative fields are PII-adjacent. |
| Account id / email / OAuth tokens | Pseudonymous session hash only. |
| Device serial / advertising id | Use coarse device class instead. |
| IP address | Stripped at ingest; use coarse geo if needed. |

## Crash / error reporting

Crash reports contain:

- Stack trace with symbols (no local variable values that could contain text).
- Error code from the taxonomy.
- Device class and OS version.
- Whether the crash occurred during inference, network, or UI.

They do **not** contain:

- Last prompt or model output.
- Screenshot or view hierarchy text.
- User state or receipt payloads.

## Server-log retention & redaction

- Server logs retain 7 days in staging, 30 days in production.
- Request/response bodies are never logged.
- Query parameters containing ids are redacted.
- Logs are scrubbed before long-term storage.

## Implementation note

The shared loggers implement redaction at the source. Any future telemetry sink
consumes logs/metrics that have already been scrubbed; it does not do its own
PII detection.
