#!/usr/bin/env bash
#
# Remove what updates leave behind: old Homebrew and mise versions, caches,
# dead simulators, stale device support, and Xcodes no longer in
# config/xcode-versions.txt.
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
  clean_simulators
  clean_device_support
  clean_xcode_versions
}

clean_simulators() {
  # Only full Xcode has simctl, not the Command Line Tools alone.
  if ! xcrun --find simctl >/dev/null 2>&1; then
    warn "simctl not found (no Xcode selected?), skipping simulators"
    return 0
  fi

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
}

# Symbols Xcode copies off each physical device, one directory per OS
# version, a few GB each. The age is when Xcode wrote the directory, not
# when that device was last plugged in, so a phone that has stayed on one
# iOS version gets offered too: hence the per-entry prompt. Anything
# removed is copied again the next time a device on that version connects.
DEVICE_SUPPORT_DAYS="${DEVICE_SUPPORT_DAYS:-90}"

clean_device_support() {
  local dir entry
  local -a old=()

  for dir in "$HOME"/Library/Developer/Xcode/*" DeviceSupport"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' entry; do
      old+=("$entry")
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -mtime +"$DEVICE_SUPPORT_DAYS" -print0)
  done

  if [[ ${#old[@]} -eq 0 ]]; then
    ok "no device support older than $DEVICE_SUPPORT_DAYS days"
    return 0
  fi

  local size
  for entry in "${old[@]}"; do
    size="$(du -sh "$entry" | awk '{ print $1 }')"
    if dry_run; then
      printf '  would offer %s (%s)\n' "$(pretty_path "$entry")" "$size"
    elif confirm "remove $(pretty_path "$entry") ($size)?"; then
      rm -rf -- "$entry"
      ok "removed $(basename "$entry")"
    else
      ok "kept $(basename "$entry")"
    fi
  done
}

clean_xcode_versions() {
  if ! has xcodes; then
    warn "xcodes missing, skipping Xcode versions"
    return 0
  fi

  local wanted selected version
  wanted="$(read_list "$REPO_ROOT/config/xcode-versions.txt")"
  # An empty list would make every Xcode a candidate.
  if [[ -z "$wanted" ]]; then
    warn "config/xcode-versions.txt is empty, not removing any Xcode"
    return 0
  fi
  selected="$(xcodes installed 2>/dev/null | grep -F '(Selected)' | sed 's/ (.*//' || true)"

  while IFS= read -r version; do
    [[ -n "$version" ]] || continue
    grep -qxF "$version" <<<"$wanted" && continue

    if [[ "$version" == "$selected" ]]; then
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
  done < <(xcodes_installed_versions)
}

# Free space on the data volume, reported when the script exits. Xcodes
# sit in the Trash until it is emptied, so they don't show up here yet.
free_gb() { df -g "$HOME" | awk 'NR == 2 { print $4 }'; }
FREE_BEFORE="$(free_gb)"

report_free() {
  local now
  dry_run && return 0
  now="$(free_gb)"
  [[ "$now" == "$FREE_BEFORE" ]] || log "free space: $FREE_BEFORE GB → $now GB"
}
trap report_free EXIT

run_targets clean "$@"
