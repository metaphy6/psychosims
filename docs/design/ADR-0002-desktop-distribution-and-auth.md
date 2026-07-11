# 📐 ADR-0002: Desktop distribution & authentication channels

- **Status**: accepted
- **Date**: 2026-07-11
- **Deciders**: @maintainer
- **Supersedes**: none
- **Superseded by**: none

> **Closes register item C-5** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> §3 names mobile auth (Apple/Google) but leaves desktop (Linux/Windows/macOS)
> distribution and sign-in an explicit open decision. All five claimed platforms
> (§1) must have a named channel + sign-in path before Phase 3 is complete.
> Section refs (§N) → [`STARTER.md`](../../STARTER.md).

## Context

The client ships on iOS, Android, Windows, macOS, and Linux (§1). Mobile has an
obvious channel (App Store / Play Store) and identity provider (Apple / Google
Sign-In). Desktop does not: it can distribute via a store (Steam, Microsoft
Store, Mac App Store, Snap/Flatpak) or a direct download, and each implies a
different identity flow. Server-authoritative identity ([ADR-0001](ADR-0001-server-authoritative-control-plane.md))
requires every platform to resolve to one account.

## Decision

- **Identity is unified via OAuth over one server-authoritative account.** Every
  platform signs in with **Google and/or Apple OAuth** (both are cross-platform
  web OAuth providers usable from desktop), producing the same server identity.
  No desktop-only account silo is created.
- **Distribution (launch):**
  - **Windows/macOS:** **Steam** as the primary desktop store (one pipeline, both OSes, built-in updates).
  - **Linux:** **direct signed download** (AppImage/tarball) at launch; Steam Linux as a fast-follow; Flatpak deferred.
  - **Mobile:** App Store (iOS) + Play Store (Android), unchanged.
- **No Sign-in-with-Steam identity.** Steam is a *distribution* channel only;
  identity stays Google/Apple OAuth so the account is portable across every channel.

## Consequences

- ➕ One identity model across all five platforms; a player is the same account
  everywhere, satisfying ADR-0001 and enabling presence/ownership/royalties.
- ➕ Steam covers Windows + macOS distribution and auto-update with one pipeline.
- ➖ Direct Linux download means we own signing + an update/retry path there.
- ➖ Steam's cut applies to desktop store revenue — folded into the C-3 cost/revenue view.
- 🔁 Reversible: adding Microsoft Store / Mac App Store / Flatpak later is additive;
  the OAuth identity layer does not change.

## Considered options

- **Direct download everywhere + OAuth** — rejected as primary: we'd rebuild
  store-grade update/trust plumbing on Windows/macOS that Steam already provides.
- **Per-store native identity (Sign-in-with-Steam, MS account)** — rejected:
  fragments identity across silos, breaking the single server-authoritative account.
- **Mobile-only launch, desktop later** — rejected: §1 claims five platforms;
  desktop is the dev baseline (Linux) and a first-class target.

## Follow-through

- Built in **Phase 3.1** (auth + distribution channels).
- Store-specific age-rating/compliance handled in **Phase 7.5** (see [C-6](../specs/AGE-RATING-AND-CONTENT-STRATEGY.md)).
