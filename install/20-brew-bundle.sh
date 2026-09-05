#!/usr/bin/env bash
# Install everything listed in the Brewfile.

brew_shellenv || die "Homebrew missing — run 10-homebrew first"

log "brew bundle…"
brew bundle install --file="$REPO_ROOT/Brewfile" --no-lock

log "brew cleanup…"
brew cleanup --prune=all
