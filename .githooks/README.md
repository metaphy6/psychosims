# Git hooks

Local hooks that mirror CI. Install with:

```bash
git config core.hooksPath .githooks
```

## pre-commit

Runs `make format.check`, `make lint`, and `make test` before allowing a commit.
