#!/usr/bin/env bash
set -euo pipefail

# Install only this repository's hooks. Never replace a developer's custom hook
# configuration or mutate global Git settings. Full bootstrap calls this last;
# bootstrap --tools-only intentionally does not call it.
if [[ "$#" -ne 0 ]]; then
  echo "Usage: scripts/install_git_hooks.sh" >&2
  exit 64
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"
pwd
actual_root="$(git rev-parse --show-toplevel)"
if [[ "$(cd "$actual_root" && pwd -P)" != "$REPO_ROOT" ]]; then
  echo "Refusing hook installation outside this repository root." >&2
  exit 1
fi
if [[ ! -f .githooks/pre-commit || ! -x .githooks/pre-commit ]]; then
  echo "Expected an executable .githooks/pre-commit; restore its repository file mode first." >&2
  exit 1
fi

# Check effective configuration, including inherited and worktree settings, so
# adding a local value cannot silently shadow another configured hook directory.
pwd
if configured_path="$(git config --get core.hooksPath)"; then
  if [[ "$configured_path" == .githooks || "$configured_path" == "$REPO_ROOT/.githooks" ]]; then
    echo "Repository hooks are already installed."
    exit 0
  fi
  echo "Refusing to replace custom core.hooksPath; integrate .githooks/pre-commit with your existing hooks explicitly." >&2
  exit 1
else
  status=$?
  if [[ "$status" -ne 1 ]]; then
    exit "$status"
  fi
fi

pwd
default_hooks="$(git rev-parse --git-path hooks)"
# core.hooksPath replaces the whole hook directory, not only pre-commit. Keep
# every non-sample hook file (including symlinks and currently disabled files)
# effective until the developer explicitly integrates their custom hooks.
shopt -s nullglob dotglob
for default_hook in "$default_hooks"/*; do
  [[ "$default_hook" == *.sample ]] && continue
  if [[ -f "$default_hook" || -L "$default_hook" ]]; then
    echo "Refusing to bypass an existing default ${default_hook##*/} hook; integrate the repository hooks explicitly." >&2
    exit 1
  fi
done

pwd
git config --local core.hooksPath .githooks
echo "Installed repository hooks locally (.githooks)."
