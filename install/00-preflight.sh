#!/usr/bin/env bash
# Xcode Command Line Tools and Rosetta 2.

if xcode-select -p >/dev/null 2>&1; then
  ok "Command Line Tools installed"
else
  log "Installing Command Line Tools (a GUI dialog will open)…"
  xcode-select --install || true
  until xcode-select -p >/dev/null 2>&1; do
    printf '  … waiting for the installation to finish\n'
    sleep 20
  done
  ok "Command Line Tools installed"
fi

# Needed on Apple Silicon for the occasional Intel-only binary.
if [[ "$(uname -m)" == "arm64" ]]; then
  if /usr/bin/pgrep -q oahd; then
    ok "Rosetta 2 installed"
  else
    log "Installing Rosetta 2…"
    sudo softwareupdate --install-rosetta --agree-to-license
    ok "Rosetta 2 installed"
  fi
fi
