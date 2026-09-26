#!/usr/bin/env bash
#
# Update what bootstrap.sh installed: Homebrew, mise, oh-my-zsh, gh
# extensions, Mac App Store apps. Old versions stay until scripts/clean.sh.
# Usage: ./scripts/update.sh [--list] [--dry-run] [target ...]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# shellcheck source=../lib/common.sh
source "$REPO_ROOT/lib/common.sh"

[[ "$(uname -s)" == "Darwin" ]] || die "this script only runs on macOS."
brew_shellenv || true

TARGETS=(brew mise omz gh mas)

# Casks that update themselves (VS Code, Spotify, …) are left to do so;
# `brew upgrade --greedy` by hand if you want them too.
update_brew() {
  brew_shellenv || die "Homebrew missing"
  # Only refreshes the package index, so it runs on --dry-run too.
  brew update
  if dry_run; then
    brew outdated
  else
    brew upgrade
  fi
}

# Stays inside the ranges in mise.toml (node '26' → newest 26.x). Moving to
# a new major is a config change: `mise upgrade --bump`, then commit.
update_mise() {
  has mise || die "mise missing"
  if dry_run; then
    mise upgrade --dry-run
  else
    mise upgrade
  fi
}

update_omz() {
  local zsh_dir="${ZSH:-$HOME/.oh-my-zsh}"
  local custom="${ZSH_CUSTOM:-$zsh_dir/custom}"
  local repo

  if [[ ! -d "$zsh_dir" ]]; then
    warn "oh-my-zsh not installed, skipping"
    return 0
  fi

  if dry_run; then
    printf '  would update %s\n' "$zsh_dir"
  else
    # `omz update` is a zsh function; this is the script it runs.
    ZSH="$zsh_dir" zsh -f "$zsh_dir/tools/upgrade.sh"
  fi

  # omz update only covers oh-my-zsh itself, not the theme and plugins
  # 30-dotfiles cloned into $ZSH_CUSTOM.
  for repo in "$custom"/themes/*/ "$custom"/plugins/*/; do
    [[ -d "$repo/.git" ]] || continue
    if dry_run; then
      printf '  would pull %s\n' "$(basename "$repo")"
    else
      git -C "$repo" pull --quiet --ff-only
      ok "$(basename "$repo") up to date"
    fi
  done
}

update_gh() {
  if ! has gh; then
    warn "gh missing, skipping"
    return 0
  fi
  if [[ -z "$(gh extension list 2>/dev/null)" ]]; then
    ok "no gh extensions installed"
    return 0
  fi
  if dry_run; then
    gh extension upgrade --all --dry-run
  else
    gh extension upgrade --all
  fi
}

update_mas() {
  if ! has mas; then
    warn "mas missing, skipping"
    return 0
  fi
  if dry_run; then
    mas outdated
  else
    mas upgrade
  fi
}

run_targets update "$@"
