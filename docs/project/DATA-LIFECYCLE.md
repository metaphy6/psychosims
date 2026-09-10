# Data lifecycle, classification and erasure

This is the engineering baseline for durable data. Implementation acceptance is
recorded in ROADMAP and the execution evidence; a policy statement alone does
not close an erasure, encryption or restore gate.

## Classification and permitted destinations

| Data | Permitted destination | Required boundary |
| --- | --- | --- |
| Provider identity subject and account link | Dedicated identity tables | Keep separate from gameplay payloads; authenticated account linkage only |
| Access/refresh tokens and device private keys | Platform secure storage; server token digests or protected retry material as required by its protocol | Never source control, plaintext client files, logs or ordinary gameplay storage |
| Authoritative profile and receipt outbox | Account/API-origin-scoped encrypted client snapshots with keys in platform secure storage | Authenticated encryption, bounded size, atomic replace, no plaintext fallback; preserve pending retries across restart |
| Local practice career and structured checkpoints | Local save files | Typed state/actions only; no authority over online balances; online snapshots require the encrypted account boundary |
| Accepted receipt projection, inventory and ledger | Authoritative PostgreSQL tables | Typed supported fields, pseudonymous account/case IDs, transaction/audit boundaries; client signature alone is insufficient |
| Rejected receipt diagnostics | Bounded error code, producer/account ID and payload hash | Never the rejected raw body or dialogue |
| Prompt, model response, recent dialogue | Process memory only | No durable transcript, even inside ciphertext; checkpoint replay reconstructs structured state |
| Metrics and application logs | Bounded operational records | Counts, timings, status/correlation identifiers; no tokens, keys, prompts, responses or receipt bodies |
| Age/consent and moderation identity data | Separate restricted records when implemented | Do not append this information to gameplay histories or the ledger |

Pseudonymous identifiers can still link to an individual through identity
records. Separation reduces exposure; it is not a claim of anonymity.

## Persistence and recovery checks

`make security.privacy` runs the client serializers/storage regressions and the
real PostgreSQL suite. Test dialogue sentinels must be absent from the actual
persisted checkpoint/receipt bytes and rejection records. Encrypted snapshots
must reject tampering and missing keys without silently replacing data or
falling back to plaintext. Raw dialogue must be rejected before encryption.

The server authenticates the exact received signed bytes but retains a supported
structured projection and the original hash. These are distinct records; the
stored projection must not be represented as the original signed wire payload.
Future signed histories require their own explicit signing/version contract.

## Retention and erasure

The local [maintenance tool](../../server/MAINTENANCE.md) performs bounded,
transactional cleanup based on actual token expiry plus a 24-hour retry grace.
It retains permanent receipt/session operation markers to prevent renewed
authority or double acceptance. Accepted structured receipt projections expire
after 90 days by default; hashes, original verdicts, ledger, certified cures and
audit remain. This is an engineering default, not an approved legal retention
schedule. Explicit invocations and local PostgreSQL tests exercise cleanup;
no production scheduler has been enabled.

A completed erasure workflow must revoke sessions and device authority, remove
provider/account links and client keys, invalidate cached profiles, update any
signed-history revocation list and prevent a restored backup from reactivating
the account. Retain only the minimum anti-replay/audit tombstones with the
appropriate account-link removal. Age/consent records follow the same erasure
request. Local server erasure now revokes authority, removes profile/provider
links and preserves a pseudonymous account fence. A separately fsynced journal
must be replayed before a restored backup becomes available to clients; the
[actual dump/restore drill](../reports/2026-09-10-local-database-recovery.md)
proves this behavior. Client erasure and signed-history/age-consent integration
remain pending. Retained account IDs, audit and ledger are still linkable and
must not be described as anonymized.

## Backup and disaster recovery

The existing design targets an RPO of one hour and an RTO of four hours for the
authoritative store. The [backup runbook](../reports/phase3/backup_runbook.md) is a
procedure; the linked local recovery evidence now measures restored
receipt/profile/audit consistency and replay/deletion invariants. Cloud backups,
PITR and production SLOs are not verified by a local container test.
