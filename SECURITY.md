# Security policy

## Trust boundary

The Flutter client is untrusted for authoritative progression. A valid device
signature identifies the registered producer; it does not prove honest gameplay.
The server checks account ownership, equipment, its own session authorization,
lease expiry, ruleset and idempotency before committing a receipt. Acceptance,
profile state, deduplication and audit writes share one PostgreSQL transaction.

Receipt schema 0.3 does not itself prove terminal gameplay. Only exact matches
to an operator-pinned, real-Dart-compiled winning witness can earn the initial
server-configured cure rewards. The same transaction writes the paired ledger,
cured ownership, original verdict and permanent replay fence. Unmatched paths
remain `held_unproven`; client-supplied ledger payouts are rejected. Eligibility,
cooldown and window limits can withhold rewards even for a proven cure. No Go
copy of the Dart simulation is used to justify payouts.

## Current controls and acceptance boundaries

| Threat | Implemented control | Remaining acceptance |
| --- | --- | --- |
| Forged/replayed progression | Account-bound keys, trusted session permits, exact finite-witness matching and transactional exactly-once cure/reward acceptance | Broader gameplay certification and later economy/anti-collusion rules |
| Stolen or replayed login material | Validated local JWKS/code-exchange adapters, durable session/refresh revocation and request-bound retry recovery | Live provider registration, real-device secure custody and operational rotation |
| Secret leakage | Gitleaks checks both staged bytes and tracked/untracked working files, redacts findings and rejects scanner errors | Operations must keep runtime secret files and credential stores outside source control |
| Dependency substitution | Committed locks, enforced resolution, exact native pin/patches and deterministic inventory drift checks | Platform binary inventories and release provenance |
| Vulnerable dependencies | Pinned govulncheck plus OSV scans of every inventoried Pub/Go version and native commit; missing coverage fails | Advisory databases cannot establish absence of undiscovered vulnerabilities |
| Unexpected license terms | Installed license texts are classified; unknown/incompatible results and fingerprint drift fail | Distribution notices, covered-source availability and platform-specific review |
| Unsafe generated dialogue | Untrusted prompt input isolation, token budgets, required-clue validation and bounded fallback | Expanded model/device acting-quality acceptance |
| Durable dialogue leakage | Typed structured checkpoints, account/origin-bound encrypted outbox/profile projection, supported server receipt fields and rejection hashes/codes; actual privacy gate passes | New content/history/UGC stores must extend this boundary and its tests |

Online authentication and API wiring are tested against real local HTTP,
cryptographic fixtures and PostgreSQL. Browser sign-in stays disabled until
registered channels, redirects and authorization origins are configured. No
live provider account, cloud deployment or release is implied by local tests.

## Data handling

[Data lifecycle and classification](docs/project/DATA-LIFECYCLE.md) defines the
allowed durable fields, identity separation, deletion and backup obligations.
Do not log authorization headers, provider tokens, signing keys, prompts,
responses, receipt bodies or raw model output. Logs and dead letters use bounded
operational identifiers, status/error codes and hashes.

Raw transcripts are ephemeral even when encrypted. Encryption is not permission
to retain dialogue. A pseudonymous account identifier is linkable data; it must
not be described as automatically anonymous or exempt from deletion controls.

## Required development gates

- `make security.secrets`: real planted-key acceptance, narrow false-positive
  policy tests, then staged/worktree scans. The installed pre-commit hook runs
  `make verify.contracts`, including lint and the same scanner. Full bootstrap
  installs it locally and preserves existing custom/default hooks by refusing
  conflicting setup. No inline allow comments bypass the scanner.
- `make security.dependencies`: locked resolution, read-only inventory comparison,
  installed-license classification, planted unknown/incompatible license and
  known-vulnerable-version tests, then actual vulnerability checks.
- `make security.privacy`: exercises production client persistence with dialogue
  sentinels and the real PostgreSQL storage/rejection regression suite. It needs
  a disposable local PostgreSQL test database; missing prerequisites fail.

Pinned tool versions and installation are in [bootstrap.sh](scripts/bootstrap.sh).
The license classifier's database is generated in an owned project-local copy;
shared Go module caches are not modified. [LICENSES.md](LICENSES.md) records model
attribution and the exact-component source-availability obligations.

The reviewed inventory covers source dependency resolutions, not every future
platform binary. Its default command is read-only; `scripts/sbom.sh --write`
explicitly prepares a new inventory for review. CI fails until drift is resolved.

## Operational work still tracked

Bounded replay retention/GC, limiter/metrics storage and local server account
erasure have tested implementations. Actual local PostgreSQL load and backup/
restore drills pass, including external erasure-journal replay against an older
backup. [Maintenance](server/MAINTENANCE.md) documents the preserved linkable
tombstones, dry-run defaults, legal holds and crash-durability ordering.
Production scheduling/custody, large-scale capacity, complete client/history
erasure and external policy approval remain roadmap work. Cloud provisioning,
provider credentials, physical-device acceptance and release are not established
by the local gates.

## Responsible disclosure

Report security issues privately to the repository maintainer through an existing
private contact channel. Do not open a public issue containing an undisclosed
exploit, credentials or personal data.
