#!/usr/bin/env bash
# Mac App Store applications.

brew_shellenv || die "Homebrew missing"
has mas || die "mas missing — run 20-brew-bundle first"

masfile="$REPO_ROOT/Masfile"
if ! grep -qE '^\s*mas ' "$masfile" 2>/dev/null; then
  warn "Masfile is empty, skipping"
  return 0
fi

if ! mas account >/dev/null 2>&1; then
  warn "not signed in to the App Store — skipping this step."
  warn "sign in, then run: ./bootstrap.sh 80-mas"
  return 0
fi

log "brew bundle (Masfile)…"
brew bundle install --file="$masfile" --no-lock
