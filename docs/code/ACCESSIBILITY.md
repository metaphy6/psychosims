# Accessibility baseline

Accessibility is built in from the first screen, not corrected later.

## Requirements

- **Semantic labels** on every interactive element.
- **Scalable text** — layouts reflow up to the largest dynamic type.
- **Sufficient contrast** — WCAG 2.1 AA minimum.
- **Input alternatives** — keyboard, switch, and pointer support for every
  card-driven interaction.

## Motion

- Honour OS reduce-motion and high-contrast settings.
- The chromatic-fracture and ink-wash shaders must dampen or disable when
  reduce-motion is on.
- Hit targets meet platform minimums and reflow with dynamic type.

## Core purity

`core/` emits stable tokens/keys. The presentation layer resolves them to
localized, accessible strings. No localization or accessibility logic leaks into
the deterministic core.
