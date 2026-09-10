# Git hooks

Full `scripts/bootstrap.sh` installs these hooks in the repository's local Git
configuration after dependencies succeed. To install them separately:

```bash
bash scripts/install_git_hooks.sh
```

## pre-commit

Runs `make verify.contracts` before allowing a commit and propagates any gate
failure. Real model acceptance remains a separate explicit gate.

Installation is idempotent. A different effective `core.hooksPath` or any existing
default hook file is preserved; the installer fails with an integration message
instead of replacing it. This includes hooks such as `pre-push`, `commit-msg`,
and `post-checkout`, including symlinks and disabled files. Git's unused
`*.sample` files do not prevent installation. Global Git configuration is never changed.
`scripts/bootstrap.sh --tools-only`, used in CI, does not install hooks or change
Git configuration. Full bootstrap enforces the committed lockfiles for the app,
config, both shared Dart packages, and content tools; it does not install SDKs.
