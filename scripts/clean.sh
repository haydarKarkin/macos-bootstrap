#!/usr/bin/env bash
#
# Remove what updates leave behind: old Homebrew and mise versions, caches,
# dead simulators, and Xcodes no longer in config/xcode-versions.txt.
# Usage: ./scripts/clean.sh [--list] [--dry-run] [target ...]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# shellcheck source=../lib/common.sh
source "$REPO_ROOT/lib/common.sh"

[[ "$(uname -s)" == "Darwin" ]] || die "this script only runs on macOS."
brew_shellenv || true

TARGETS=(brew mise gem xcode)
# gem only runs when named: see clean_gem.
DEFAULT_TARGETS=(brew mise xcode)

clean_brew() {
  brew_shellenv || die "Homebrew missing"
  if dry_run; then
    brew autoremove --dry-run
    brew cleanup --prune=all --dry-run
  else
    # Dependencies nothing needs any more, then old versions and the
    # whole download cache.
    brew autoremove
    brew cleanup --prune=all
  fi

  # Report only: something installed by hand may be there on purpose.
  # Add it to the Brewfile or `brew uninstall` it. Without --force, brew
  # still offers to remove everything on a terminal, so stdin is closed.
  # The type flags keep out Mac App Store apps (they're in the Masfile),
  # npm/uv/cargo globals and the rest. Its own "run --force" hint is
  # dropped, because run bare, that would remove all of those.
  log "installed but not in the Brewfile:"
  brew bundle cleanup --file="$REPO_ROOT/Brewfile" --formula --cask --tap </dev/null 2>&1 \
    | grep -v 'brew bundle cleanup --force' || true
}

# mise remembers every config it has loaded (see `mise ls --prunable`). A
# version is kept while any of those still asks for it, so an iOS project's
# pinned tuist survives; a deleted project's does not.
clean_mise() {
  has mise || die "mise missing"
  if dry_run; then
    mise prune --dry-run
    mise cache prune --dry-run
  else
    mise prune --yes
    mise cache prune
  fi
}

# Old versions of gems in the global ruby's GEM_HOME. Not run by default:
# gem cleanup knows nothing about Gemfile.lock, so it also removes the
# older versions projects pin, and they need a `bundle install` again.
clean_gem() {
  has mise || die "mise missing"
  # The global ruby, not whatever the current directory pins.
  cd "$HOME"
  if ! mise which gem >/dev/null 2>&1; then
    warn "no mise-managed ruby, skipping"
    return 0
  fi
  if dry_run; then
    mise exec -- gem cleanup --dry-run
  else
    mise exec -- gem cleanup
  fi
}

clean_xcode() {
  # --- simulators ------------------------------------------------------
  # Devices whose runtime is gone can never boot again.
  if dry_run; then
    xcrun simctl list devices unavailable
  else
    xcrun simctl delete unavailable
  fi

  # Runtimes Apple marks unusable, or superseded by a newer build.
  local mode
  for mode in --unusable --outdated; do
    if dry_run; then
      xcrun simctl runtime delete "$mode" --dry-run || warn "simctl runtime delete $mode failed"
    else
      xcrun simctl runtime delete "$mode" || warn "simctl runtime delete $mode failed"
    fi
  done

  # --- Xcode versions --------------------------------------------------
  if ! has xcodes; then
    warn "xcodes missing, skipping Xcode versions"
    return 0
  fi

  local wanted line version
  wanted="$(read_list "$REPO_ROOT/config/xcode-versions.txt")"
  # An empty list would make every Xcode a candidate.
  if [[ -z "$wanted" ]]; then
    warn "config/xcode-versions.txt is empty, not removing any Xcode"
    return 0
  fi

  while IFS= read -r line; do
    # 26.5 (17F42) [Apple Silicon] (Selected)	/Applications/Xcode-26.5.0.app
    version="${line%% (*}"
    [[ -n "$version" ]] || continue
    grep -qxF "$version" <<<"$wanted" && continue

    if [[ "$line" == *"(Selected)"* ]]; then
      warn "Xcode $version is selected but not in config/xcode-versions.txt, keeping it"
      continue
    fi

    if dry_run; then
      printf '  would remove Xcode %s\n' "$version"
    elif confirm "remove Xcode $version (not in config/xcode-versions.txt)?"; then
      # Moves it to the Trash; empty that to get the space back.
      xcodes uninstall "$version"
      ok "Xcode $version moved to the Trash"
    else
      ok "kept Xcode $version"
    fi
  done < <(xcodes installed 2>/dev/null || true)
}

run_targets clean "$@"
