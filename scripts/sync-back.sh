#!/usr/bin/env bash
#
# Dotfiles are symlinks, so they stay in sync on their own. This dumps the
# rest of the machine state into the repo so it can be diffed and merged.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> brew bundle dump"
brew bundle dump --force --describe --file="$REPO_ROOT/Brewfile.dump"
echo "    diff Brewfile.dump against Brewfile by hand"

echo "==> mise ls"
mise ls --current > "$REPO_ROOT/mise-installed.txt"

echo "==> xcodes"
xcodes installed > "$REPO_ROOT/xcode-installed.txt" 2>/dev/null || true

echo "Done. Review with: git diff"
