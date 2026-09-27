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

# $HOME/foo -> ~/foo, for output. Not ${p/#$HOME/\~}: bash 3.2 prints the
# backslash, and bash 5 expands an unescaped ~ right back to $HOME.
pretty_path() {
  case "$1" in
    "$HOME"|"$HOME"/*) printf '~%s\n' "${1#"$HOME"}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Symlink src -> dst, moving anything already there out of the way.
link_file() {
  local src="$1" dst="$2" backup

  if [[ -L "$dst" ]]; then
    # Already pointing at us: nothing to do.
    [[ "$(readlink "$dst")" == "$src" ]] && return 0
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
    warn "$(pretty_path "$dst") exists → $(basename "$backup")"
    mv "$dst" "$backup"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "$(pretty_path "$dst")"
}

# Strip comments and blank lines from a config list.
read_list() {
  [[ -f "$1" ]] || return 0
  grep -vE '^\s*(#|$)' "$1" || true
}

# Installed Xcodes, one per line, by the name xcodes gives them ("26.5",
# "27.0 Beta 3"). config/xcode-versions.txt lists the same names.
#   26.5 (17F42) [Apple Silicon] (Selected)	/Applications/Xcode-26.5.0.app
xcodes_installed_versions() {
  xcodes installed 2>/dev/null | sed 's/ (.*//' || true
}

dry_run() { [[ "${DRY_RUN:-0}" -eq 1 ]]; }

# y/N prompt. Reads the terminal, not stdin, so it works inside a
# `while read` loop; with no terminal it answers no.
confirm() {
  local reply
  ( : </dev/tty ) 2>/dev/null || return 1
  read -r -p "  $1 [y/N] " reply </dev/tty || return 1
  [[ "$reply" == [yY] ]]
}

# Argument parsing and dispatch shared by scripts/update.sh and
# scripts/clean.sh. Calls <prefix>_<target> for each requested target, or
# when none are given, for $DEFAULT_TARGETS if set, else all of $TARGETS.
# A failing target is reported and the rest still run.
run_targets() {
  local prefix="$1"; shift
  local -a requested=() failed=()
  local t

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list)
        for t in "${TARGETS[@]}"; do
          if [[ -n "${DEFAULT_TARGETS+x}" ]] && ! contains "$t" "${DEFAULT_TARGETS[@]}"; then
            printf '  %s (only when named)\n' "$t"
          else
            printf '  %s\n' "$t"
          fi
        done
        exit 0
        ;;
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help)
        sed -n '3,/^$/p' "$0" | sed -e 's/^# \{0,1\}//' -e '/^$/d'
        exit 0
        ;;
      -*) die "unknown option: $1" ;;
      *)
        contains "$1" "${TARGETS[@]}" || die "unknown target: $1 (see --list)"
        requested+=("$1"); shift
        ;;
    esac
  done

  if [[ ${#requested[@]} -eq 0 ]]; then
    if [[ -n "${DEFAULT_TARGETS+x}" ]]; then
      requested=("${DEFAULT_TARGETS[@]}")
    else
      requested=("${TARGETS[@]}")
    fi
  fi

  for t in "${requested[@]}"; do
    log "$prefix $t"
    # Subshell with errexit back on: `set -e` is ignored inside anything
    # tested by `||` or `if`, so the status is collected by hand instead.
    set +e
    ( set -e; "${prefix}_$t" )
    # shellcheck disable=SC2181
    [[ $? -eq 0 ]] || failed+=("$t")
    set -e
  done

  [[ ${#failed[@]} -eq 0 ]] || die "failed: ${failed[*]}"
  log "Done."
}
