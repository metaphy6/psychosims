# Cross-stack logging convention

Every layer of Psychosims emits **one structured log line shape**, whether the
line originates in the Dart client, the C/C++ llama.cpp FFI shim, or the Go
server. The convention prioritizes:

1. **Readability in dev** — balanced emoji + aligned columns so a human can scan.
2. **Parsability in production** — the same event can be emitted as JSON.
3. **No transcript leakage** — the log schema never carries raw session dialogue
   or prompt text (see §17 / [`THREAT-MODEL.md`](../design/THREAT-MODEL.md)).

## Canonical log-line schema

| Field | Required | Type | Example | Notes |
|-------|----------|------|---------|-------|
| `ts` | yes | ISO-8601 UTC | `2026-07-12T14:53:28.123Z` | High-resolution, monotonic source preferred for ordering. |
| `level` | yes | enum | `info` | `debug`, `info`, `success`, `warn`, `error`, `fatal`. |
| `scope` | yes | string | `app:session` | `<stack>:<module>`; lowercase, colon-separated. |
| `event` | yes | string | `turn_started` | Lowercase snake_case action name. |
| `correlation_id` | yes* | string | `sess_2aF...` | Always on trust-boundary-crossing flows; may be `none` for fire-and-forget startup. |
| `kv` | optional | object | `{ "turn": 7, "seed": 42 }` | Structured key–values; never includes raw text. |
| `error_kind` | when error | enum | `system` | `user`, `system`, `external`, `offline`. |
| `message` | dev only | string | `Turn 7 started` | Human summary; absent in JSON prod mode. |

> *`correlation_id` is mandatory for any log emitted inside a client session,
> server request, or receipt flow. See [IDENTIFIERS.md](IDENTIFIERS.md).

## Emoji severity map

Exactly one leading emoji per line, mapped to level:

| Level | Emoji | Usage |
|-------|-------|-------|
| debug | 🔍 | Diagnostics, noisy internals. |
| info | ℹ️ | Normal lifecycle events. |
| success | ✅ | Completed work, green gates. |
| warn | ⚠️ | Degraded but continuing. |
| error | ❌ | Failure that needs attention. |
| fatal | 🛑 | Abort/crash path. |

Rules:

- **No decorative emoji elsewhere.** The leading emoji is the only one.
- **No emoji inside machine-parsed fields** (`scope`, `event`, `kv` keys, JSON).
- Columns should be padded enough for quick scanning but not so wide they wrap.

## Text rendering modes

Mode is selected by the config authority (see [`config/`](../config/)):

- **dev** — text lines with emoji, aligned columns, human `message`.
- **staging/prod** — compact JSON, one object per line, no emoji, no free text
  summaries that could hold PII.

Both modes carry the **identical field set**; only rendering differs.

## Per-stack logger homes

| Stack | Logger path | Notes |
|-------|-------------|-------|
| Dart / Flutter | `app/lib/shared/logger.dart` | Uses the config authority for mode/level. |
| C/C++ FFI | `native/include/psychosims_log.h` | Thin shim that renders the same line and forwards to Dart/stdout. |
| Go server | `server/internal/psylog/psylog.go` | Same schema; redacts secrets and never logs request bodies. |

## Forbidden outputs

Direct un-scoped writes are forbidden because they bypass redaction, level
control, and correlation-id propagation:

- Dart: `print(...)`
- C/C++: `std::cout`, `printf`, `NSLog`
- Python: `sys.stdout.write`, bare `print` outside a CLI entrypoint

CI enforces this with [`scripts/no_raw_print_check.sh`](../../scripts/no_raw_print_check.sh).

## Privacy rule

Raw session transcripts, prompts, and user messages are **never** log fields.
If a diagnostic must capture model input, it is replaced by a content hash and
metadata (token count, schema version) only.
