#!/usr/bin/env bash
# Homebrew.

if brew_shellenv; then
  ok "Homebrew installed ($(brew --prefix))"
else
  log "Installing Homebrew…"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew_shellenv || die "Homebrew installed but could not be located"
  ok "Homebrew installed"
fi

log "brew update…"
brew update
