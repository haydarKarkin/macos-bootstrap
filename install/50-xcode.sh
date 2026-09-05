#!/usr/bin/env bash
# Xcode versions and simulator runtimes, driven by config/.
#
# Requires an Apple ID. Either let the script prompt, or export
# XCODES_USERNAME / XCODES_PASSWORD beforehand. Never commit the password —
# pull it out of Bitwarden at run time.

brew_shellenv || die "Homebrew missing"
has xcodes || die "xcodes missing — run 20-brew-bundle first"

versions_file="$REPO_ROOT/config/xcode-versions.txt"
runtimes_file="$REPO_ROOT/config/simulator-runtimes.txt"

# Strip comments and blank lines.
read_list() {
  [[ -f "$1" ]] || return 0
  grep -vE '^\s*(#|$)' "$1" || true
}

installed="$(xcodes installed 2>/dev/null || true)"

while IFS= read -r version; do
  [[ -n "$version" ]] || continue
  if grep -qF "$version" <<<"$installed"; then
    ok "Xcode $version installed"
    continue
  fi
  log "Downloading Xcode $version (this takes a while)…"
  xcodes install "$version" --experimental-unxip
done < <(read_list "$versions_file")

# The last listed version becomes the active one.
select_version="$(read_list "$versions_file" | tail -1)"
if [[ -n "$select_version" ]]; then
  log "Selecting Xcode $select_version…"
  sudo xcodes select "$select_version"
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
  ok "active: $(xcodebuild -version | head -1)"
fi

# --- simulator runtimes ----------------------------------------------
installed_rt="$(xcodes runtimes 2>/dev/null | grep -i installed || true)"

while IFS= read -r runtime; do
  [[ -n "$runtime" ]] || continue
  if grep -qF "$runtime" <<<"$installed_rt"; then
    ok "runtime installed: $runtime"
    continue
  fi
  log "Downloading runtime: $runtime"
  xcodes runtimes install "$runtime"
done < <(read_list "$runtimes_file")
