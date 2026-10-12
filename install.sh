#!/bin/bash
# Omarchy Themes for GNOME: put omarchy-theme on PATH and the picker in Activities. Re-run after moving the repo.
# Nothing here needs root; ./install.sh --uninstall removes what it added.
# Optional parts (coloured folders, GNOME app colours, …) are switched on from the app's ☰ menu
# or `omarchy-theme enable <option>`, not here.
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)
BIN=$HOME/.local/bin
APPS=$HOME/.local/share/applications
DESKTOP=$APPS/io.github.rnakshay.OmarchyThemes.desktop

if [[ ${1:-} == --uninstall ]]; then
  # Coloured folders is the one option with a running service and installed icons; take it down.
  "$REPO/bin/omarchy-theme" disable folders >/dev/null 2>&1 || true
  rm -f "$BIN/omarchy-theme" "$BIN/omarchy-theme-picker" "$DESKTOP"
  echo "Removed. Applied colours are untouched; run 'omarchy-theme reset' first to restore them."
  exit 0
fi

mkdir -p "$BIN" "$APPS"
ln -sf "$REPO/bin/omarchy-theme" "$BIN/omarchy-theme"
ln -sf "$REPO/bin/omarchy-theme-picker" "$BIN/omarchy-theme-picker"
cat >"$DESKTOP" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Omarchy Themes
GenericName=Omarchy Themes for GNOME
Comment=Switch the desktop, terminal and editor to an Omarchy theme
Exec=$BIN/omarchy-theme-picker
Icon=preferences-desktop-appearance
Categories=Settings;DesktopSettings;GTK;
Keywords=omarchy;themes;theme;colors;wallpaper;dark;light;
StartupNotify=true
DBusActivatable=false
DESKTOP
update-desktop-database "$APPS" 2>/dev/null || true
echo "Installed: 'Omarchy Themes' in Activities and 'omarchy-theme' on PATH."
echo "Optional parts (coloured folders, GNOME app colours, …) are in the app's ☰ menu."
