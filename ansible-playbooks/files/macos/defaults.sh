#!/bin/sh

set -eu

# Stop immediately on non-macOS systems so this script is safe to call from
# shared tooling.
if [ "$(uname -s)" != "Darwin" ]; then
	echo "macOS defaults skipped: this host is not running Darwin."
	exit 0
fi

# Disable natural scrolling so wheel/trackpad scrolling follows the traditional
# direction used by most Linux desktop setups.
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Disable press-and-hold character popovers so holding a key repeats the key
# instead of opening the accent picker.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Reduce the delay before a held key starts repeating.
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Increase the key repeat rate once repeat has started.
defaults write NSGlobalDomain KeyRepeat -int 2

# Disable smart quotes because they are hostile to shell commands, code, and
# plain-text notes.
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable smart dashes because they can silently replace command-line friendly
# hyphens with typographic dashes.
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable automatic spelling correction globally to avoid unwanted edits in
# terminals, editors, browsers, and text fields.
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Show all filename extensions in Finder and standard file dialogs.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show Finder's path bar at the bottom of Finder windows.
defaults write com.apple.finder ShowPathbar -bool true

# Show Finder's status bar with item counts and free disk space.
defaults write com.apple.finder ShowStatusBar -bool true

# Show the POSIX path in Finder window titles so the active folder is
# unambiguous.
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Search the current folder by default when using Finder search.
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Avoid warning prompts when changing file extensions.
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store metadata files on network shares.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Avoid creating .DS_Store metadata files on USB and other removable volumes.
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Save screenshots as PNG files.
defaults write com.apple.screencapture type -string "png"

# Leave screenshot location unmanaged so macOS keeps its default Desktop target,
# or whatever location was selected manually.

# Disable the modern desktop-click behavior that hides windows and shows the
# desktop when clicking the wallpaper.
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

# Restart Finder so Finder-specific defaults above are picked up immediately.
killall Finder >/dev/null 2>&1 || true

# Restart SystemUIServer so screenshot and menu-bar related defaults are picked
# up without logging out.
killall SystemUIServer >/dev/null 2>&1 || true

# Flush the user defaults cache so newly written preferences are visible to
# future processes as soon as possible.
killall cfprefsd >/dev/null 2>&1 || true
