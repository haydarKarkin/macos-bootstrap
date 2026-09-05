#!/usr/bin/env bash
# SSH key, agent, GitHub upload, and SSH-based commit signing.
#
# SSH signing rather than GPG on purpose: one key does both authentication
# and signing, and there is no separate keyring to babysit. If you want GPG
# instead, install gnupg + pinentry-mac and change the [gpg] block in
# dotfiles/git/.gitconfig.

brew_shellenv || true

key="$HOME/.ssh/id_ed25519"
email="${GIT_EMAIL:-}"

if [[ -z "$email" ]]; then
  read -r -p "  commit email address: " email
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# --- key -------------------------------------------------------------
if [[ -f "$key" ]]; then
  ok "SSH key already exists: $key"
else
  log "Generating an ed25519 key…"
  ssh-keygen -t ed25519 -C "$email" -f "$key" -N ""
  ok "generated: $key"
fi

# --- ssh config ------------------------------------------------------
if ! grep -q "UseKeychain" "$HOME/.ssh/config" 2>/dev/null; then
  log "Writing ~/.ssh/config…"
  cat >>"$HOME/.ssh/config" <<CONF

Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile $key
CONF
  chmod 600 "$HOME/.ssh/config"
fi

ssh-add --apple-use-keychain "$key" 2>/dev/null || ssh-add -K "$key" 2>/dev/null || true

# --- commit signing --------------------------------------------------
signers="$HOME/.ssh/allowed_signers"
pubkey="$(cat "$key.pub")"

if ! grep -qF "$pubkey" "$signers" 2>/dev/null; then
  printf '%s %s\n' "$email" "$pubkey" >>"$signers"
  ok "allowed_signers updated"
fi

# Personal identity lives here, outside the repo.
if [[ ! -f "$HOME/.gitconfig.local" ]]; then
  read -r -p "  git user.name: " gitname
  cat >"$HOME/.gitconfig.local" <<CONF
[user]
	name = $gitname
	email = $email
	signingkey = $key.pub
CONF
  ok "created ~/.gitconfig.local"
fi

# --- GitHub ----------------------------------------------------------
if has gh && gh auth status >/dev/null 2>&1; then
  title="$(scutil --get ComputerName 2>/dev/null || hostname)"
  gh ssh-key add "$key.pub" --title "$title" 2>/dev/null \
    && ok "auth key uploaded to GitHub" \
    || warn "auth key may already be present"
  gh ssh-key add "$key.pub" --title "$title (signing)" --type signing 2>/dev/null \
    && ok "signing key uploaded to GitHub" \
    || warn "signing key may already be present"
else
  warn "not authenticated with gh. Run: gh auth login"
  warn "then: gh ssh-key add $key.pub --type signing"
fi
