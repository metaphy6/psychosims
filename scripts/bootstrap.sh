#!/usr/bin/env bash
set -euo pipefail

# One-command reproducible dev-environment bootstrap for Psychosims.
# Installs / verifies pinned toolchains and prints version diagnostics.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "▶️  Psychosims dev bootstrap"

# Official Go vulnerability scanner, pinned and installed only in this repo.
# https://go.dev/doc/security/vuln/
install_tools() {
  command -v go >/dev/null || { echo "❌ go is required" >&2; return 127; }
  mkdir -p "$REPO_ROOT/.tools/bin"
  GOBIN="$REPO_ROOT/.tools/bin" go install golang.org/x/vuln/cmd/govulncheck@v1.8.0
  GOBIN="$REPO_ROOT/.tools/bin" go install github.com/zricethezav/gitleaks/v8@v8.30.1
  GOBIN="$REPO_ROOT/.tools/bin" go install github.com/google/osv-scanner/v2/cmd/osv-scanner@v2.5.1
  # This upstream release embeds the generated licenses.db, but its module zip
  # omits that database. Generate it in our own copy, never the shared Go cache.
  local classifier_version=v0.0.0-20260218193730-3cfbab2d0e0d
  local classifier_copy="$REPO_ROOT/.tools/licenseclassifier"
  GOBIN="$REPO_ROOT/.tools/bin" go install "github.com/google/licenseclassifier/tools/license_serializer@$classifier_version"
  local classifier_cache
  classifier_cache="$(go env GOMODCACHE)/github.com/google/licenseclassifier@$classifier_version"
  mkdir -p "$classifier_copy"
  cp -R "$classifier_cache/." "$classifier_copy/"
  chmod -R u+w "$classifier_copy"
  "$REPO_ROOT/.tools/bin/license_serializer" -output "$classifier_copy/licenses"
  (cd "$classifier_copy" && go build -o "$REPO_ROOT/.tools/bin/identify_license" ./tools/identify_license)
}

if [[ "$#" -eq 1 && "$1" == "--tools-only" ]]; then
  install_tools
  exit 0
elif [[ "$#" -ne 0 ]]; then
  echo "Usage: scripts/bootstrap.sh [--tools-only]" >&2
  exit 64
fi

# Verify Python 3.12+
if command -v python3 &>/dev/null; then
  PYTHON_VERSION=$(python3 --version | awk '{print $2}')
  echo "ℹ️  Python: $PYTHON_VERSION"
  if [[ ! "$PYTHON_VERSION" =~ ^3\.([1-9][2-9]|[2-9][0-9])\. ]]; then
    echo "⚠️  Python 3.12+ recommended" >&2
  fi
else
  echo "❌ python3 not found" >&2
  exit 1
fi

# Verify the Flutter toolchain (CI pins 3.38.5).
if command -v flutter &>/dev/null; then
  FLUTTER_VERSION=$(flutter --version | head -n 1 | awk '{print $3}')
  echo "ℹ️  Flutter: $FLUTTER_VERSION"
else
  echo "⚠️  flutter not found; CI uses Flutter 3.38.5 to build app/" >&2
fi

# Verify Dart (Flutter 3.38.5 bundles Dart 3.10.4).
if command -v dart &>/dev/null; then
  DART_VERSION=$(dart --version | awk '{print $4}')
  echo "ℹ️  Dart: $DART_VERSION"
else
  echo "⚠️  dart not found" >&2
fi

# Verify clang / CMake
if command -v clang &>/dev/null; then
  echo "ℹ️  clang: $(clang --version | head -n 1)"
else
  echo "⚠️  clang not found; needed for native/ builds" >&2
fi

if command -v cmake &>/dev/null; then
  echo "ℹ️  CMake: $(cmake --version | head -n 1)"
else
  echo "⚠️  cmake not found; needed for native/ builds" >&2
fi

# Install Go server dependencies
if [[ -f "server/go.mod" ]]; then
  if command -v go &>/dev/null; then
    echo "ℹ️  Go: $(go version | awk '{print $3}')"
    echo "▶️  Building server module..."
    (cd server && go build ./...)
  else
    echo "⚠️  go not found; install Go 1.26+ to build server/" >&2
  fi
fi

# Fetch Dart dependencies
if [[ -d "app" ]] && command -v flutter &>/dev/null; then
  echo "▶️  Fetching app dependencies..."
  (cd app && flutter pub get --enforce-lockfile)
fi

for pkg in config packages/psychemas packages/psycore tools; do
  if [[ -d "$pkg" ]] && command -v dart &>/dev/null; then
    echo "▶️  Fetching $pkg dependencies..."
    (cd "$pkg" && dart pub get --enforce-lockfile)
  fi
done

install_tools
bash "$REPO_ROOT/scripts/install_git_hooks.sh"

echo "✅ bootstrap complete"
