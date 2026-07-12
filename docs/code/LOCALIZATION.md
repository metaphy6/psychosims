# Localization & string discipline

All user-facing strings are externalized; no hard-coded copy lives in UI code.

## String ownership

- Copy lives in ARB files under `app/lib/l10n/` (created when the first feature
  lands).
- The presentation layer resolves keys to localized strings using `AppLocalizations`.
- The deterministic `core/` emits stable tokens/keys only; it never contains
  localized prose.

## Locale-aware formatting

- Numbers, currencies, dates, and pluralization use `intl` helpers keyed to the
  config-selected locale.
- RTL readiness is a shared convention: start/end alignment, bidirectional text
  support, and mirrored layouts where required.

## Keys

Keys are lower-case dot-separated paths:

- `manifests.p001.name`
- `economy.currency_symbol`
- `errors.lifecycle_invalid_transition`

## Hard-coded-string gate

CI runs `scripts/check_hardcoded_strings.sh` to catch planted hard-coded strings.
Allowed exceptions:

- Empty strings.
- Developer-only `assert` / `debugPrint` messages.
- URLs and package names that are not user-facing.
