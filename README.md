# omarchy-themes-gnome

Use [Omarchy](https://github.com/omacom/omarchy)'s themes on a regular GNOME desktop.
Unofficial — not affiliated with Omarchy or Basecamp.

Pick a theme and it is applied to:

| | |
|---|---|
| GNOME | dark/light mode, nearest accent colour, the theme's icon set (if installed) |
| GNOME apps | *opt-in* (`omarchy-theme recolor on`): window, sidebar, header and exact accent colours |
| Wallpaper | the theme's own backgrounds, cycled with `next-wallpaper` |
| Ptyxis | a generated terminal palette |
| VS Code | the theme's named VS Code theme, or one generated from its colours |
| btop | Omarchy's btop template |
| Chrome / Chromium | toolbar colour via browser policy (asks for an admin password) |

## Install

```bash
./install.sh            # omarchy-theme on PATH, "Themes" in Activities
```

Requires Python 3.11+, git, PyGObject with GTK 4 / libadwaita 1.6+, and `dwebp` (libwebp-tools).

## Use

Open **Themes** from Activities and click one to preview it full screen: Omarchy's screenshot,
then each wallpaper (←/→ or swipe), and ↑/↓ moves to the previous/next theme. **Apply** (or Enter)
uses the theme and wallpaper on screen; Esc closes. Or:

```bash
omarchy-theme list
omarchy-theme set osaka-jade [--skip chrome,vscode] [--wallpaper 2]
omarchy-theme next-wallpaper
omarchy-theme colors tokyo-night     # preview the palette in the terminal
omarchy-theme sync                   # pull new and updated themes from Omarchy
omarchy-theme reset                  # restore everything from before the first theme
```

## Design: stay small, survive updates

- **Supported interfaces by default**: gsettings, Ptyxis palette files, VS Code settings, btop
  themes, Chrome enterprise policy. No GNOME Shell themes.
- **The one unsupported piece is opt-in.** App recolour uses libadwaita's documented CSS
  variables via `gtk.css`, which GNOME doesn't promise to keep honouring.
  `tests/check-gtk-recolor.py` renders a real libadwaita window and checks the pixels, so a
  GNOME update that breaks it shows up as a failing test. `recolor off` removes it entirely.
- **Themes are not copied.** They are read from a sparse clone of Omarchy, and Omarchy's own
  templates are reused, so upstream fixes arrive with `sync`.
- `tests/check-upstream.py` checks the colour resolver still matches Omarchy's
  `omarchy-theme-color` for every theme, and that every template renders. Run it after `sync`.
- The picker is an ordinary GTK app, not a Shell extension, so GNOME releases don't break it.

## License

MIT. Themes, templates and wallpapers come from Omarchy (MIT) and are fetched, not bundled.
