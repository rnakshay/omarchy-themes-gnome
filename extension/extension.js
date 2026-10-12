// Omarchy Themes — Quick Settings tile.
//
// Deliberately thin: it lists themes and runs `omarchy-theme`, which does all the theming.
// The less this file does, the less a GNOME release can break.

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {QuickMenuToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';

const APP_ID = 'io.github.rnakshay.OmarchyThemes.desktop';
const ICON = 'preferences-desktop-appearance-symbolic';

const DATA = GLib.build_filenamev([GLib.get_user_data_dir(), 'omarchy-themes-gnome']);
const CONFIG = GLib.build_filenamev([GLib.get_user_config_dir(), 'omarchy-themes-gnome']);
const STATE = GLib.build_filenamev([GLib.get_user_state_dir(), 'omarchy-themes-gnome']);
const THEME_DIRS = [
    GLib.build_filenamev([DATA, 'upstream', 'themes']),
    GLib.build_filenamev([CONFIG, 'themes']),
];

function cliPath() {
    return GLib.find_program_in_path('omarchy-theme') ??
        GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'omarchy-theme']);
}

function title(name) {
    return name.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
}

function readText(path) {
    try {
        const [, bytes] = GLib.file_get_contents(path);
        return new TextDecoder().decode(bytes);
    } catch {
        return null;
    }
}

function readJson(path) {
    try {
        return JSON.parse(readText(path) ?? '{}');
    } catch {
        return {};
    }
}

function currentTheme() {
    return readText(GLib.build_filenamev([STATE, 'current']))?.trim() ?? null;
}

// Same rule as the CLI: a directory with a colors.toml (or an older alacritty.toml) is a theme.
function listThemes() {
    const names = new Set();
    for (const dir of THEME_DIRS) {
        let children;
        try {
            children = Gio.File.new_for_path(dir).enumerate_children(
                'standard::name,standard::type', Gio.FileQueryInfoFlags.NONE, null);
        } catch {
            continue;
        }
        for (const info of children) {
            if (info.get_file_type() !== Gio.FileType.DIRECTORY)
                continue;
            const name = info.get_name();
            if (['colors.toml', 'alacritty.toml'].some(f =>
                GLib.file_test(GLib.build_filenamev([dir, name, f]), GLib.FileTest.EXISTS)))
                names.add(name);
        }
    }
    return [...names].sort();
}

const ThemeToggle = GObject.registerClass(
class ThemeToggle extends QuickMenuToggle {
    _init() {
        super._init({
            title: 'Theme',
            iconName: ICON,
            toggleMode: false,
            menuButtonAccessibleName: 'Choose a theme',
        });
        this.checked = true; // a theme is always in effect; shown in the accent colour

        this.menu.setHeader(ICON, 'Omarchy Themes');

        // 23+ themes outgrow the screen, so the list scrolls. The section is added through
        // addMenuItem first so the menu wires up activation and keyboard navigation.
        this._themes = new PopupMenu.PopupMenuSection();
        this.menu.addMenuItem(this._themes);
        this.menu.box.remove_child(this._themes.actor);
        this._scroll = new St.ScrollView({
            style: 'max-height: 20em;',
            hscrollbar_policy: St.PolicyType.NEVER,
            vscrollbar_policy: St.PolicyType.AUTOMATIC,
            overlay_scrollbars: true,
            child: this._themes.actor,
        });
        this.menu.box.add_child(this._scroll);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._wallpaperSwitch = new PopupMenu.PopupSwitchMenuItem('Change wallpaper too', this._prefs().panel_wallpaper ?? true);
        this._wallpaperSwitch.connect('toggled', (_item, state) => this._savePref('panel_wallpaper', state));
        this.menu.addMenuItem(this._wallpaperSwitch);
        this.menu.addSettingsAction('Open Omarchy Themes…', APP_ID);

        this.connect('clicked', () => this.menu.open());
        this.menu.connect('open-state-changed', (_menu, open) => {
            if (open)
                this._rebuild();
        });

        // Follow switches made in the app or from the terminal.
        GLib.mkdir_with_parents(STATE, 0o755);
        this._monitor = Gio.File.new_for_path(GLib.build_filenamev([STATE, 'current']))
            .monitor_file(Gio.FileMonitorFlags.NONE, null);
        this._monitor.connect('changed', () => this._sync());

        this._sync();
    }

    _prefs() {
        return readJson(GLib.build_filenamev([CONFIG, 'settings.json']));
    }

    _savePref(key, value) {
        const path = GLib.build_filenamev([CONFIG, 'settings.json']);
        const settings = {...this._prefs(), [key]: value};
        GLib.mkdir_with_parents(CONFIG, 0o755);
        GLib.file_set_contents(path, `${JSON.stringify(settings, null, 2)}\n`);
    }

    _sync() {
        const current = currentTheme();
        this.subtitle = current ? title(current) : 'None';
        this.menu.setHeader(ICON, 'Omarchy Themes', current ? title(current) : '');
    }

    _rebuild() {
        this._themes.removeAll();
        const current = currentTheme();
        const themes = listThemes();
        if (themes.length === 0) {
            const item = new PopupMenu.PopupMenuItem('No themes yet — open the app once to fetch them');
            item.sensitive = false;
            this._themes.addMenuItem(item);
            return;
        }
        for (const name of themes) {
            const item = new PopupMenu.PopupMenuItem(title(name));
            item.setOrnament(name === current ? PopupMenu.Ornament.CHECK : PopupMenu.Ornament.NONE);
            item.connect('activate', () => this._apply(name));
            this._themes.addMenuItem(item);
        }
    }

    _apply(name) {
        const skip = [];
        if (!readJson(GLib.build_filenamev([CONFIG, 'picker.json'])).chrome)
            skip.push('chrome'); // its admin-password prompt doesn't belong in a quick switch
        if (!this._wallpaperSwitch.state)
            skip.push('wallpaper');
        const argv = [cliPath(), 'set', name, ...(skip.length ? ['--skip', skip.join(',')] : [])];

        this.subtitle = `Applying ${title(name)}…`;
        let proc;
        try {
            proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE);
        } catch (e) {
            Main.notifyError('Omarchy Themes', `Could not run omarchy-theme: ${e.message}`);
            this._sync();
            return;
        }
        proc.communicate_utf8_async(null, null, (p, result) => {
            let out = '';
            try {
                [, out] = p.communicate_utf8_finish(result);
            } catch (e) {
                out = e.message;
            }
            const failed = (out ?? '').split('\n').filter(l => l.includes('failed'));
            if (!p.get_successful())
                Main.notifyError('Omarchy Themes', (out ?? '').trim().split('\n').pop() || 'Applying the theme failed');
            else if (failed.length)
                Main.notifyError('Omarchy Themes', `${title(name)} applied, but: ${failed.join('; ').trim()}`);
            this._sync();
        });
    }

    destroy() {
        this._monitor?.cancel();
        this._monitor = null;
        super.destroy();
    }
});

const ThemeIndicator = GObject.registerClass(
class ThemeIndicator extends SystemIndicator {
    _init() {
        super._init();
        this.quickSettingsItems.push(new ThemeToggle());
    }

    destroy() {
        this.quickSettingsItems.forEach(item => item.destroy());
        super.destroy();
    }
});

export default class OmarchyThemesExtension extends Extension {
    enable() {
        this._indicator = new ThemeIndicator();
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
