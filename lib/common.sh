#!/usr/bin/env bash
# Shared helpers. Sourced by bootstrap.sh and by every install step.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m  ✗\033[0m %s\n' "$*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

contains() {
  local needle="$1"; shift
  local item
  for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done
  return 1
}

# Locate Homebrew for this architecture and load it into the environment.
brew_shellenv() {
  local prefix
  for prefix in /opt/homebrew /usr/local; do
    if [[ -x "$prefix/bin/brew" ]]; then
      eval "$("$prefix/bin/brew" shellenv)"
      return 0
    fi
  done
  return 1
}

# Ask for the sudo password once and keep the timestamp alive for the run.
sudo_keepalive() {
  sudo -v
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" 2>/dev/null || exit
  done 2>/dev/null &
}

# Symlink src -> dst, moving anything already there out of the way.
link_file() {
  local src="$1" dst="$2"

  if [[ -L "$dst" ]]; then
    # Already pointing at us: nothing to do.
    [[ "$(readlink "$dst")" == "$src" ]] && return 0
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    local backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
    warn "${dst/#$HOME/\~} exists → $(basename "$backup")"
    mv "$dst" "$backup"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "${dst/#$HOME/\~}"
}
