#!/bin/bash
# Put omarchy-theme on PATH and the Themes picker in Activities. Re-run after moving the repo.
# Nothing here needs root; ./install.sh --uninstall removes what it added.
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)
BIN=$HOME/.local/bin
APPS=$HOME/.local/share/applications
DESKTOP=$APPS/io.github.rnakshay.OmarchyThemes.desktop

if [[ ${1:-} == --uninstall ]]; then
  rm -f "$BIN/omarchy-theme" "$BIN/omarchy-theme-picker" "$DESKTOP"
  echo "Removed. Applied settings are untouched; run 'omarchy-theme reset' first to restore them."
  exit 0
fi

mkdir -p "$BIN" "$APPS"
ln -sf "$REPO/bin/omarchy-theme" "$BIN/omarchy-theme"
ln -sf "$REPO/bin/omarchy-theme-picker" "$BIN/omarchy-theme-picker"
cat >"$DESKTOP" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Themes
GenericName=Omarchy Themes
Comment=Switch the desktop, terminal and editor to an Omarchy theme
Exec=$BIN/omarchy-theme-picker
Icon=preferences-desktop-appearance
Categories=Settings;DesktopSettings;GTK;
Keywords=omarchy;theme;colors;wallpaper;dark;light;
StartupNotify=true
DBusActivatable=false
DESKTOP
update-desktop-database "$APPS" 2>/dev/null || true
echo "Installed: 'omarchy-theme' on PATH, 'Themes' in Activities."
