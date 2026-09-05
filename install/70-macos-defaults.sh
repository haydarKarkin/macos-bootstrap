#!/usr/bin/env bash
# macOS system preferences. Comment out anything you disagree with.

log "Writing system preferences…"

# --- keyboard --------------------------------------------------------
# Holding a key should repeat it, not open the accent picker.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Autocorrect and smart punctuation are a menace when writing code.
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# --- Finder ----------------------------------------------------------
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # list view
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search current folder
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Stop littering .DS_Store files on network and USB volumes.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# --- Dock ------------------------------------------------------------
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock tilesize -int 44
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false       # don't reorder Spaces
defaults write com.apple.dock minimize-to-application -bool true

# --- screenshots -----------------------------------------------------
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# --- misc ------------------------------------------------------------
# Crash reports as notifications instead of modal dialogs.
defaults write com.apple.CrashReporter UseUNC -bool true

# Always show the expanded save panel.
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Skip the "are you sure you want to open this" prompt for downloads.
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Let Tab reach every control, not just text fields.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

log "Restarting affected applications…"
for app in Finder Dock SystemUIServer; do
  killall "$app" >/dev/null 2>&1 || true
done

warn "some settings need a logout/login to take effect."
