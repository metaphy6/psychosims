# ADR-0009 — Bounded authoritative derivation and certified outcomes

- **Status**: accepted
- **Date**: 2026-09-10
- **Deciders**: authorized implementation, independently reviewed in this workspace
- **Supersedes**: the prohibition on server-derived Doubt, operational pressure
  and Trauma Severity in [ADR-0006](ADR-0006-server-runtime-go.md); Go remains
  the server runtime and gameplay simulation remains in Dart.

## Context

[C-9](../specs/SERVER-DERIVED-QUANTITIES.md) requires the server to derive bounded
cross-session quantities from accepted evidence. ADR-0006 contradicts that
requirement. Device signatures authenticate bytes but do not prove a claimed
cure, delta, currency amount, or entitlement. The repaired receipt service
therefore holds unproven payouts while a trusted outcome path is implemented.

## Decision

Derive bounded rewards and cross-session quantities from authoritative catalog,
profile, clock and accepted evidence, using pure-Dart-generated winning witnesses
to certify an initial subset of terminal outcomes without running the sim in Go.

## Consequences

- A content-build tool runs the production Dart core and records a replayable
  witness bound to manifest checksum/catalog version, ruleset, exact start state,
  seed, loadout, controllers and ordered actions. Only validated build output
  enters the trusted server catalog; clients cannot submit their own certificate.
- Session authorization selects those inputs from the catalog and authoritative
  inventory/ownership. Receipt acceptance compares exact bound inputs/actions
  to the certificate; it never treats the client outcome or ledger as authority.
- Payout amounts, eligibility, cooldowns and caps come from server configuration
  and catalog metadata and are posted once within the acceptance transaction.
- Unmatched action sequences remain accepted or rejected according to structural
  rules but receive no certified cure payout. A successful local practice result
  does not imply an authoritative online reward. This limitation must be visible
  in session authorization and reconciliation.
- Pressure uses accepted cadence and trusted case tier; Doubt uses accepted
  action classifications and authoritative price history. Severity multipliers
  require trusted outcome/provenance history and anti-collusion guards. Client
  delta labels or claimed trauma never supply those inputs.
- Signature verification stays over exact received bytes. Go does not reproduce
  the Dart PRNG, fixed-point simulation or canonical signing serializer.
- Certification is conservative and may hold legitimate alternative wins.
  Expanding the certified set is content-build work; it must not silently turn
  arbitrary client assertions into authoritative state.

## Considered options

- **Certified witnesses plus bounded server derivation (selected):** reuses the
  existing tested core, gives a concrete trusted payout path, and respects C-9.
- **Trust signed client outcomes:** rejected because the player controls the
  signing device and can fabricate outcomes and amounts.
- **Port the full simulation into Go:** rejected because it creates a second
  deterministic engine and violates the established architecture.
- **Hold every payout permanently:** safe as an interim repair, but cannot
  complete the intended online progression loop.

## Acceptance

Cross-language fixtures must prove exact witness matching and rejection after
altering the manifest, seed, start axes, inventory, controllers or actions.
Real PostgreSQL/HTTP tests must prove one payout under retries/restarts,
transaction rollback, budget/cooldown enforcement, and zero payouts for
uncertified or revoked evidence. No cloud deployment or release is involved.

The initial certificate path passed independent compiler, server transaction
and client privacy/UI reviews. Real Dart/Go/PostgreSQL acceptance covers a fresh
one-card starter and retained four-card recipes, with exact reward/replay and
rollback checks. See the current [execution evidence](../planning/EXECUTION-2026-09-10.md).
This accepts the authority decision and initial finite cure path. General
outcome coverage, non-cure practice rewards, cross-session quantities and the
full economy retain their Phase 5 acceptance gates.
