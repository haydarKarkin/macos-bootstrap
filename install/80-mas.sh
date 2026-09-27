#!/usr/bin/env bash
# Mac App Store applications.

brew_shellenv || die "Homebrew missing"
has mas || die "mas missing — run 20-brew-bundle first"

masfile="$REPO_ROOT/Masfile"
if ! grep -qE '^\s*mas ' "$masfile" 2>/dev/null; then
  warn "Masfile is empty, skipping"
  return 0
fi

log "brew bundle (Masfile)…"
# mas can no longer tell whether you're signed in (there is no
# `mas account` any more), so a failed install is the only signal.
if ! brew bundle install --file="$masfile"; then
  warn "some App Store apps failed to install."
  warn "sign in to the App Store, then run: ./bootstrap.sh 80-mas"
fi
