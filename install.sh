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

# ── Requirements ─────────────────────────────────────────────────────────────
# Missing required pieces stop the install with the packages to add; recommended ones only warn.
. /etc/os-release 2>/dev/null || true
case " ${ID:-} ${ID_LIKE:-} " in
  *" fedora "*|*" rhel "*) FAMILY=fedora ;;
  *" debian "*|*" ubuntu "*) FAMILY=debian ;;
  *" arch "*) FAMILY=arch ;;
  *) FAMILY=other ;;
esac
pkg() {  # pkg <fedora> <debian> <arch> <description>
  case $FAMILY in
    fedora) echo "$1" ;; debian) echo "$2" ;; arch) echo "$3" ;; *) echo "$4" ;;
  esac
}

missing=() warnings=()
python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null ||
  missing+=("Python 3.11 or newer")
command -v git >/dev/null || missing+=("$(pkg git-core git git 'git')")
command -v gsettings >/dev/null || missing+=("$(pkg glib2 libglib2.0-bin glib2 'gsettings (GLib)')")
python3 -c 'import gi; gi.require_version("Gtk", "4.0"); from gi.repository import Gtk' 2>/dev/null ||
  missing+=("$(pkg 'python3-gobject gtk4' 'python3-gi gir1.2-gtk-4.0' 'python-gobject gtk4' 'PyGObject with GTK 4')")
python3 - <<'PY' 2>/dev/null || missing+=("$(pkg libadwaita gir1.2-adw-1 libadwaita 'libadwaita') (version 1.6 or newer)")
import gi, sys
gi.require_version("Adw", "1")
from gi.repository import Adw
sys.exit((Adw.MAJOR_VERSION, Adw.MINOR_VERSION) < (1, 6))
PY
command -v dwebp >/dev/null ||
  warnings+=("$(pkg libwebp-tools webp libwebp 'dwebp (libwebp)') — most themes' wallpapers are .webp and can't be applied without it")
python3 -c 'import gi; gi.require_version("Gly", "2"); gi.require_version("GlyGtk4", "2"); from gi.repository import Gly, GlyGtk4' 2>/dev/null ||
  warnings+=("$(pkg 'glycin-libs glycin-gtk4-libs' "glycin's GObject bindings" "glycin's GObject bindings" "glycin's GObject bindings") — the preview can't show .webp wallpapers without it")
[[ ${XDG_CURRENT_DESKTOP:-} == *GNOME* ]] ||
  warnings+=("this doesn't look like a GNOME session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset}); it is made for GNOME")

if (( ${#missing[@]} )); then
  echo "Can't install yet — missing:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  [[ $FAMILY == fedora ]] && echo "On Fedora: sudo dnf install <the packages above>" >&2
  [[ $FAMILY == debian ]] && echo "On Debian/Ubuntu: sudo apt install <the packages above>" >&2
  [[ $FAMILY == arch ]] && echo "On Arch: sudo pacman -S <the packages above>" >&2
  exit 1
fi
for w in "${warnings[@]}"; do echo "Note: $w" >&2; done

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
