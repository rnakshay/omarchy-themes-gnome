#!/bin/bash
# Omarchy Themes for GNOME: put omarchy-theme on PATH and the picker in Activities. Re-run after moving the repo.
# Nothing here needs root; ./install.sh --uninstall removes what it added.
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)
BIN=$HOME/.local/bin
APPS=$HOME/.local/share/applications
DESKTOP=$APPS/io.github.rnakshay.OmarchyThemes.desktop
UNIT_DIR=$HOME/.config/systemd/user
UNIT=omarchy-theme-follow-accent.service
EXT_UUID=omarchy-themes@rnakshay.github.io
ICONS_SRC=${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-themes-gnome/adwaita-colors

if [[ ${1:-} == --uninstall ]]; then
  systemctl --user disable --now "$UNIT" 2>/dev/null || true
  gnome-extensions uninstall "$EXT_UUID" 2>/dev/null || true
  rm -f "$BIN/omarchy-theme" "$BIN/omarchy-theme-picker" "$DESKTOP" "$UNIT_DIR/$UNIT"
  systemctl --user daemon-reload
  # Adwaita-colors icons stay; remove them with: $ICONS_SRC/setup -u
  echo "Removed. Applied settings are untouched; run 'omarchy-theme reset' first to restore them."
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

# Coloured folders: Adwaita-colors (github.com/dpejoh/Adwaita-colors, GPL-3.0) builds an
# Adwaita-<accent> icon theme per GNOME accent from the installed Adwaita. User-level, no sudo.
# Re-run this script after a GNOME update to rebuild them from the new Adwaita.
if [[ -d $ICONS_SRC/.git ]]; then
  git -C "$ICONS_SRC" pull --quiet --ff-only
else
  git clone --quiet --depth 1 https://github.com/dpejoh/Adwaita-colors "$ICONS_SRC"
fi
"$ICONS_SRC/setup" -i >/dev/null

# Keeps those folders on the accent colour, including when it is changed by hand in Settings.
mkdir -p "$UNIT_DIR"
cat >"$UNIT_DIR/$UNIT" <<UNITFILE
[Unit]
Description=Recolour folder icons to follow the GNOME accent colour
PartOf=graphical-session.target
After=graphical-session.target

[Service]
ExecStart=$BIN/omarchy-theme follow-accent
Restart=on-failure

[Install]
WantedBy=graphical-session.target
UNITFILE
systemctl --user daemon-reload
systemctl --user enable --now "$UNIT" >/dev/null 2>&1
systemctl --user restart "$UNIT"
# Quick Settings tile. GNOME Shell only loads a newly installed extension at the next login on
# Wayland; enabling it now means it appears then without a trip to the Extensions app.
TMP=$(mktemp -d)
gnome-extensions pack "$REPO/extension" --out-dir "$TMP" --force >/dev/null
gnome-extensions install --force "$TMP/$EXT_UUID.shell-extension.zip"
rm -r "$TMP"
gnome-extensions enable "$EXT_UUID" 2>/dev/null || \
  gsettings set org.gnome.shell enabled-extensions \
    "$(python3 -c 'import ast,sys; l=ast.literal_eval(sys.argv[1].replace("@as ","")); l+=[sys.argv[2]] if sys.argv[2] not in l else []; print(l)' \
      "$(gsettings get org.gnome.shell enabled-extensions)" "$EXT_UUID")"

echo "Installed: 'omarchy-theme' on PATH, 'Omarchy Themes' in Activities, folders follow the accent colour,
Quick Settings tile (log out and back in once to load it)."
