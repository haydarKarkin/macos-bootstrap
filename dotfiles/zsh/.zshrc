# =====================================================================
#  ~/.zshrc — symlinked here by macos-bootstrap.
#  Edit dotfiles/zsh/.zshrc in the repo; this path is just a symlink.
#  Machine-specific or secret things go in ~/.zshrc.local (not committed).
# =====================================================================

# =========================
# 1) POWERLEVEL10K INSTANT PROMPT (MUST STAY FIRST)
# =========================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# =========================
# 2) HOMEBREW
# =========================
# Resolve the prefix instead of hardcoding it, so this file also works on
# an Intel Mac (/usr/local) without editing. Sets HOMEBREW_PREFIX,
# HOMEBREW_CELLAR, HOMEBREW_REPOSITORY, PATH, MANPATH and INFOPATH.
for _brew_prefix in /opt/homebrew /usr/local; do
  if [[ -x "$_brew_prefix/bin/brew" ]]; then
    eval "$("$_brew_prefix/bin/brew" shellenv)"
    break
  fi
done
unset _brew_prefix


# =========================
# 3) OH-MY-ZSH CORE
# =========================
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

# powerlevel10k, zsh-autosuggestions and zsh-syntax-highlighting are cloned
# into $ZSH_CUSTOM by install/30-dotfiles.sh.
# zsh-syntax-highlighting must always be last in this list.
plugins=(
  git
  gh
  macos
  fzf
  direnv
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"


# =========================
# 4) POWERLEVEL10K CONFIG
# =========================
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# =========================
# 5) PATH / ENV
# =========================
export LANG="en_US.UTF-8"
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export LESS="-R"

# Ruby gems. GEM_HOME itself is not executable — binaries live in its bin/.
export GEM_HOME="$HOME/.gem"

# Mint (Swift CLI package manager).
export MINT_PATH="$HOME/.mint"
export MINT_LINK_PATH="$MINT_PATH/bin"

# Always $HOME, never a hardcoded /Users/<name> — this file has to survive
# a different username on a new machine.
path=(
  "$HOME/.local/bin"
  "$GEM_HOME/bin"
  "$MINT_LINK_PATH"
  "$HOME/.opencode/bin"
  "$HOME/.lmstudio/bin"      # LM Studio CLI (lms)
  $path
)
# Drop entries that don't exist on this machine, and de-duplicate.
path=(${^path}(N-/))
typeset -U path PATH


# =========================
# 6) TOOL INIT
# =========================
# mise owns the language runtimes (node, ruby, …) and most CLI tools.
# Use `activate` OR shims, never both — two mechanisms fighting over PATH
# is how you end up with the wrong ruby.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi


# =========================
# 7) HISTORY
# =========================
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"

setopt EXTENDED_HISTORY       # record timestamps
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE      # a leading space keeps it out of history
setopt HIST_VERIFY            # show !! expansion before running it
setopt SHARE_HISTORY


# =========================
# 8) ALIASES
# =========================
alias c='clear'
alias cat='bat --paging=never'

# Deliberately not aliasing `ls` or `grep` — muscle memory for the real
# flags is worth more than the prettier output.
alias ll='eza -l --git --group-directories-first'
alias la='eza -la --git --group-directories-first'
alias lt='eza --tree --level=2'

alias g='git'
alias gs='git status --short --branch'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias lg='lazygit'

alias v='nvim'
alias t='tmux'
alias ta='tmux attach'

alias reload='exec zsh'
alias zshrc='$EDITOR ~/.zshrc'
alias bootstrap='cd ~/dev/macos-bootstrap && ./bootstrap.sh'

# Update everything in one go.
alias up='brew update && brew upgrade && brew cleanup && mise upgrade && omz update'


# =========================
# 9) FUNCTIONS
# =========================
# Force every booted simulator to en_BZ, which surfaces untranslated
# strings and unformatted dates during localisation work.
sim-set-lang() {
  xcrun simctl list -j "devices" |
    jq -r '.devices | map(.[])[].udid' |
    parallel 'xcrun simctl boot {}; xcrun simctl spawn {} defaults write "Apple Global Domain" AppleLanguages -array en_BZ; xcrun simctl spawn {} defaults write "Apple Global Domain" AppleLocale -string en_BZ; xcrun simctl shutdown {}'
}


# =========================
# 10) LOCAL OVERRIDES (never committed)
# =========================
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
