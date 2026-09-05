#!/usr/bin/env bash
# oh-my-zsh, its custom theme/plugins, then symlink everything under dotfiles/.

# --- oh-my-zsh -------------------------------------------------------
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  ok "oh-my-zsh installed"
else
  log "Installing oh-my-zsh…"
  # KEEP_ZSHRC so the installer leaves our own .zshrc alone.
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "oh-my-zsh installed"
fi

# --- oh-my-zsh custom theme and plugins ------------------------------
# The prompt and the two zsh plugins come from git, not Homebrew, because
# .zshrc loads them through oh-my-zsh ($ZSH_THEME / plugins=(…)).
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

clone_or_pull() {
  local url="$1" dest="$2" name
  name="$(basename "$dest")"

  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" pull --quiet --ff-only && ok "$name up to date"
  else
    log "Cloning $name…"
    git clone --depth=1 --quiet "$url" "$dest"
    ok "$name cloned"
  fi
}

clone_or_pull https://github.com/romkatv/powerlevel10k.git \
              "$ZSH_CUSTOM/themes/powerlevel10k"
clone_or_pull https://github.com/zsh-users/zsh-autosuggestions.git \
              "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting.git \
              "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# --- symlinks --------------------------------------------------------
# Each dotfiles/<package>/ mirrors the layout of $HOME. Individual files
# are linked (not whole directories) so we never clobber a directory that
# something else also writes into.
log "Linking dotfiles…"

for pkg in "$REPO_ROOT"/dotfiles/*/; do
  [[ -d "$pkg" ]] || continue
  while IFS= read -r -d '' src; do
    rel="${src#"$pkg"}"
    link_file "$src" "$HOME/$rel"
  done < <(find "$pkg" -type f -not -name '.DS_Store' -print0)
done

# --- login shell -----------------------------------------------------
brew_shellenv || true
brew_zsh="$(brew --prefix 2>/dev/null)/bin/zsh"

if [[ -x "$brew_zsh" && "$SHELL" != "$brew_zsh" ]]; then
  grep -qxF "$brew_zsh" /etc/shells || echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null
  chsh -s "$brew_zsh"
  ok "login shell → $brew_zsh"
fi
