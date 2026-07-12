# ADR-0005: GetX for state management, dependency injection, and navigation

## Status

Accepted per [DECISION 0016](../project/DECISION_LOG.md).

## Context

The Flutter client needs:

- Reactive UI state.
- A single dependency-injection seam for the config authority and shared services.
- Typed navigation with deep-link readiness for desktop OAuth callbacks.

## Decision

Use **GetX** as the single state-management + DI + routing layer.

## Consequences

- Every feature module follows the same skeleton:
  `features/<domain>/{controller,binding,screen,service,widgets,tests}`.
- Config and services are injected via `Get.put()` / `Get.find()`; no globals.
- Navigation uses `Get.toNamed()` with named routes defined centrally.
- No `build_runner` codegen is required, keeping build times low.

## Alternatives considered

- **Riverpod / Bloc**: stronger typing but more boilerplate and codegen; rejected
  to keep the small team’s iteration speed high.
- **Provider + go_router**: two separate systems; rejected to keep one convention.

## References

- [DECISION 0016](../project/DECISION_LOG.md)
- `app/lib/shared/injection.dart`
