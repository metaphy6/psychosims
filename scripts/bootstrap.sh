#!/usr/bin/env bash
set -euo pipefail

# One-command reproducible dev-environment bootstrap for Psychosims.
# Installs / verifies pinned toolchains and prints version diagnostics.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "▶️  Psychosims dev bootstrap"

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

# Verify Flutter 3.22+
if command -v flutter &>/dev/null; then
  FLUTTER_VERSION=$(flutter --version | head -n 1 | awk '{print $3}')
  echo "ℹ️  Flutter: $FLUTTER_VERSION"
else
  echo "⚠️  flutter not found; install Flutter 3.22+ to build app/" >&2
fi

# Verify Dart 3.4+
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
    (cd server && go build ./...) || true
  else
    echo "⚠️  go not found; install Go 1.26+ to build server/" >&2
  fi
fi

# Fetch Dart dependencies
if [[ -d "app" ]] && command -v flutter &>/dev/null; then
  echo "▶️  Fetching app dependencies..."
  (cd app && flutter pub get) || true
fi

for pkg in config packages/psychemas packages/psycore; do
  if [[ -d "$pkg" ]] && command -v dart &>/dev/null; then
    echo "▶️  Fetching $pkg dependencies..."
    (cd "$pkg" && dart pub get) || true
  fi
done

echo "✅ bootstrap complete"
