#!/usr/bin/env python3
"""Fails if a libadwaita update stops honouring the recolour.

Renders a real libadwaita window off-screen with the generated CSS (in a throwaway
XDG_CONFIG_HOME, so the live config is untouched) and compares pixels to the theme.
"""
import importlib.machinery
import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
THEMES = sys.argv[1:] or ["osaka-jade", "catppuccin-latte", "gruvbox"]

PROBE = r'''
import sys, gi
gi.require_version("Gtk", "4.0"); gi.require_version("Adw", "1"); gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Adw, Gtk, GLib

def activate(app):
    win = Adw.ApplicationWindow(application=app, default_width=200, default_height=120)
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    box.append(Gtk.Label(label=" ", vexpand=True))
    button = Gtk.Button(label=" ")
    button.add_css_class("suggested-action")
    box.append(button)
    win.set_content(box)
    win.present()

    def shot():
        paintable = Gtk.WidgetPaintable(widget=win)
        snap = Gtk.Snapshot()
        paintable.snapshot(snap, win.get_width(), win.get_height())
        texture = win.get_native().get_renderer().render_texture(snap.to_node(), None)
        texture.save_to_png(sys.argv[1])
        app.quit()
    GLib.timeout_add(800, shot)

app = Adw.Application(application_id="io.github.rnakshay.OmarchyThemes.Probe")
app.connect("activate", activate)
app.run([])
'''


def load_cli():
    loader = importlib.machinery.SourceFileLoader("ot", str(REPO / "bin/omarchy-theme"))
    spec = importlib.util.spec_from_loader("ot", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def pixel(png, x, y):
    import gi
    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import GdkPixbuf
    pb = GdkPixbuf.Pixbuf.new_from_file(str(png))
    y = y if y >= 0 else pb.get_height() + y
    i = y * pb.get_rowstride() + x * pb.get_n_channels()
    return "#%02x%02x%02x" % tuple(pb.get_pixels()[i:i + 3])


def close(a, b, tolerance=3):
    return all(abs(int(a[i:i + 2], 16) - int(b[i:i + 2], 16)) <= tolerance for i in (1, 3, 5))


ot = load_cli()
themes = ot.all_themes()
failures = 0
for name in THEMES:
    c = ot.resolve(themes[name][0])
    colors = {**c, **ot.gtk_colors(c), "title": name}
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "gtk-4.0").mkdir()
        (Path(tmp) / "gtk-4.0/gtk.css").write_text(ot.template("gtk4.css.tpl", colors))
        png = Path(tmp) / "shot.png"
        env = {**os.environ, "XDG_CONFIG_HOME": tmp}
        subprocess.run([sys.executable, "-c", PROBE, str(png)], env=env, timeout=30,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if not png.is_file():
            print(f"FAIL {name}: window did not render")
            failures += 1
            continue
        window, button = pixel(png, 100, 30), pixel(png, 100, -15)
    ok = close(window, c["background"]) and close(button, colors["gtk_accent"])
    print(f"{'ok  ' if ok else 'FAIL'} {name}: window {window} (want {c['background']}), "
          f"button {button} (want {colors['gtk_accent']})")
    failures += not ok

sys.exit(1 if failures else 0)
