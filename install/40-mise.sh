#!/usr/bin/env bash
# CLI tools and language runtimes via mise.
# The config must already be symlinked by 30-dotfiles.

brew_shellenv || die "Homebrew missing"
has mise || die "mise missing — run 20-brew-bundle first"

cfg="$HOME/.config/mise/config.toml"
[[ -f "$cfg" ]] || die "$cfg missing — run 30-dotfiles first"

log "mise install…"
mise trust "$cfg"
mise install --yes

log "Installed tools:"
mise ls --current
