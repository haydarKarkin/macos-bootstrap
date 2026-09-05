#!/usr/bin/env bash
#
# macOS bootstrap — runs every install step in order.
# Usage: ./bootstrap.sh [--list] [--dry-run] [step-name ...]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT

# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"

# Collect the steps up front. nullglob so an empty install/ yields an empty
# array instead of the literal pattern, which would later fail to source.
shopt -s nullglob
STEPS=("$REPO_ROOT"/install/*.sh)
shopt -u nullglob

[[ ${#STEPS[@]} -gt 0 ]] || die "no install steps found in $REPO_ROOT/install"

DRY_RUN=0
declare -a REQUESTED=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      for s in "${STEPS[@]}"; do
        printf '  %s\n' "$(basename "$s" .sh)"
      done
      exit 0
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '3,5p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) die "unknown option: $1" ;;
    *) REQUESTED+=("$1"); shift ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "this script only runs on macOS."

# Fail loudly on a typo instead of silently running nothing.
if [[ ${#REQUESTED[@]} -gt 0 ]]; then
  declare -a KNOWN=()
  for s in "${STEPS[@]}"; do KNOWN+=("$(basename "$s" .sh)"); done
  for want in "${REQUESTED[@]}"; do
    contains "$want" "${KNOWN[@]}" || die "unknown step: $want (see --list)"
  done
fi

sudo_keepalive

for script in "${STEPS[@]}"; do
  name="$(basename "$script" .sh)"

  if [[ ${#REQUESTED[@]} -gt 0 ]] && ! contains "$name" "${REQUESTED[@]}"; then
    continue
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] $name"
    continue
  fi

  log "$name"
  # Subshell, so a step cannot leak exports into the next one.
  ( source "$REPO_ROOT/lib/common.sh"; source "$script" )
done

log "Done."
cat <<'NOTES'

Manual steps left:
  1. Restart the terminal (or: exec zsh)
  2. p10k configure           — only to change the prompt
  3. gh auth login            — authenticate with GitHub
  4. Sign in to Fork, VS Code, Bitwarden, Spotify, Notion, Obsidian
  5. Restore Logi Options+ profiles
  6. Sign in to the App Store, then: ./bootstrap.sh 80-mas
  7. Remove any stale Ghostty config under ~/Library/Application Support

NOTES
