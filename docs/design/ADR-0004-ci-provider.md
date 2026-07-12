# ADR-0004 — Continuous Integration Provider

- **Status**: accepted
- **Date**: 2026-07-12
- **Deciders**: @maintainer

## Context

Phase 0.5 requires standing up CI running build + lint + format + `make verify`
on every push/PR.

## Decision

Use **GitHub Actions** as the CI provider.

## Rationale

- The repository is hosted on GitHub; GitHub Actions is available without extra
  vendor onboarding.
- The workflow file is committed to `.github/workflows/`, making the CI
  configuration version-controlled and reviewable.
- `make verify` provides a vendor-neutral gate that can be migrated later if
  needed.

## Consequences

- `.github/workflows/ci.yml` triggers on push and pull requests to `main`.
- Required status checks + branch protection should be enabled in repository
  settings.
- The same `make verify` command runs locally and in CI.
