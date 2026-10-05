//@ pragma UseQApplication
//@ pragma IconTheme Gruvbox-Plus-Dark
import Quickshell
import Quickshell.Io
import QtQuick
import "modules/bar"
import "modules/lock"
import "modules/settings"
import "services" as Svc
import "config"

ShellRoot {
    // Singletons are created on first use; the clipboard watcher has to run
    // from startup, so touch it here.
    readonly property bool _clipboardReady: Svc.Clipboard.available
    // Idle lock, screen-off and lock-before-sleep live in the Lock singleton.
    readonly property bool _lockReady: Svc.Lock.locked
    // The notification daemon must own its D-Bus name from startup.
    readonly property int _notifyReady: Svc.Notifications.unread
    // Keeps Hyprland's rounding / borders on the committed theme.
    readonly property int _themeSyncReady: Svc.ThemeSync.windowRounding
    // A focus session survives reloads; its timer must run from startup.
    readonly property bool _focusReady: Svc.Focus.active
    // Wallpaper rotation replaces the old cron job.
    readonly property int _wallReady: Svc.Wallpaper.ranked.length

    Loader {
        active: Svc.Lock.locked
        sourceComponent: LockScreen {}
    }
    // Loaded only while open: the whole window is freed on close.
    Loader {
        active: Svc.Ui.settingsOpen
        sourceComponent: SettingsWindow {}
    }
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screenRef: modelData
        }
    }

    // Keybind hooks, e.g. in hyprland.conf:
    //   bind = $mainMod, D, exec, qs -c rice ipc call rice dashboard overview
    //   bind = $mainMod, Q, exec, qs -c rice ipc call rice quicksettings ""
    IpcHandler {
        target: "rice"

        function focused(): string {
            const m = Svc.Hyprland.focusedMonitor;
            return m ? m.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
        }
        function dashboard(tab: string): void { Svc.Ui.toggle("dashboard", focused(), tab); }
        function quicksettings(page: string): void { Svc.Ui.toggle("quicksettings", focused(), page); }
        function close(): void { Svc.Ui.close(); }
        function refresh(): void { Svc.Weather.refresh(); Svc.Mail.refresh(); Svc.Calendar.refresh(); Svc.Github.refresh(); }
        function music(): void { Svc.Mpris.launch(); }
        function playpause(): void { Svc.Mpris.togglePlay(); }
        function next(): void { Svc.Mpris.next(); }
        function previous(): void { Svc.Mpris.previous(); }
        function mail(): void { Svc.Ui.toggle("sidebar", focused(), "notifications"); }
        function sidebar(tab: string): void { Svc.Ui.toggle("sidebar", focused(), tab); }
        // Settings window, optionally on a page (appearance, bar, sound, …).
        // Same page again while open closes it.
        function settings(page: string): void {
            if (Svc.Ui.settingsOpen && (page === "" || page === Svc.Ui.settingsPage)) { Svc.Ui.settingsOpen = false; return; }
            const wasOpen = Svc.Ui.settingsOpen;
            Svc.Ui.openSettings(page);
            if (wasOpen) Svc.Hyprland.dispatch("focuswindow title:^rice settings$");
        }
        // Settings › Connections. preview on|off walks the login flows safely.
        function connectorsPreview(state: string): string { Svc.Connectors.preview = state === "on"; return "preview " + (Svc.Connectors.preview ? "on" : "off"); }
        function connectors(): string {
            Svc.Connectors.checkAll();
            return Svc.Connectors.defs.map(d => d.id + "\t" + ((Svc.Connectors.status[d.id] || {}).state || "?") + "\t" + ((Svc.Connectors.status[d.id] || {}).detail || "")).join("\n");
        }
        function connectorTest(id: string): void { Svc.Connectors.check(id); }
        function connectorLogin(id: string): void { Svc.Connectors.login(id); }
        function connectorLogout(id: string): void { Svc.Connectors.logout(id); }
        // Preview only: typed values never go on a real command line.
        function connectorSave(id: string, field: string, value: string): string {
            if (!Svc.Connectors.preview) return "connectorSave works in preview only; type real values in Settings › Connections";
            Svc.Connectors.save(id, field, value); return "ok";
        }
        // Settings › Packages, for testing / voice: tab, search, show a package.
        function packagesTab(tab: string): void { Svc.Ui.openSettings("packages"); Svc.Packages.tab = tab; }
        function packagesSearch(q: string): void { Svc.Ui.openSettings("packages"); Svc.Packages.tab = "search"; Svc.Packages.search(q); }
        function packagesShow(name: string, repo: string): void {
            Svc.Packages.openKey = (repo === "aur" ? "aur" : "repo") + "/" + name;
            Svc.Packages.info(name, repo === "aur" ? "aur" : "repo");
        }
        // Focus mode. profile "" = default, minutes 0 = the profile's own.
        function focus(profile: string, minutes: int): string {
            if (profile !== "" && !Settings.focusProfiles.find(p => p.id === profile)) return "unknown profile: " + profile;
            if (!Svc.Focus.start(profile, minutes)) return "already focusing until " + Svc.Focus.endsText;
            return "focusing until " + Svc.Focus.endsText;
        }
        // Sessions can't be cancelled; this only reports when it ends.
        function focusStop(): string { return Svc.Focus.active ? "can't stop: focus runs until " + Svc.Focus.endsText : "not focusing"; }
        function focusStatus(): string { Svc.Focus._checkStatus(); return Svc.Focus.statusJson(); }
        function focusProfiles(): string { return Settings.focusProfiles.map(p => p.id + "\t" + p.label + "\t" + p.minutes + " min").join("\n"); }
        // Wallpaper picker; wallpaperNext rotates now (best for theme + season).
        function wallpaper(): void { Svc.Ui.toggle("wallpaper", focused(), ""); }
        function wallpaperNext(): void { Svc.Wallpaper.next("all"); }
        function session(): void { Svc.Ui.toggle("session", focused(), ""); }
        function dnd(): void { Svc.Notifications.toggleDnd(); }
        function lock(): void { Svc.Lock.lock(); }
        function caffeine(): void { Svc.Lock.caffeine = !Svc.Lock.caffeine; }
        function nightlight(): void { Svc.Desktop.toggleNightLight(); }
        // Idempotent setters (voice, focus profiles): "on" | "off".
        function dndSet(state: string): void { Svc.Notifications.setDnd(state === "on"); }
        function nightlightSet(state: string): void { Svc.Desktop.setNightLight(state === "on"); }
        function caffeineSet(state: string): void { Svc.Lock.caffeine = state === "on"; }
        function power(id: string): string {
            if (!Svc.Desktop.actions.find(a => a.id === id)) return "unknown: " + id;
            Svc.Desktop.power(id); return "ok";
        }
        function launcher(): void { Svc.Ui.toggle("launcher", focused(), ""); }
        function clipboard(): void { Svc.Ui.toggle("launcher", focused(), "clipboard"); }
        function keybinds(): void { Svc.Ui.toggle("launcher", focused(), "keybinds"); }
        function screenshot(target: string, action: string): void { Svc.Screenshot.take(target || "area", action || ""); }

        // Action catalogue (config/actions.json + themes): list, or run one by id.
        // Confirm-tier actions need "confirm" as the second argument.
        function actions(): string { return Svc.Actions.all.map(a => a.id + "\t" + a.title).join("\n"); }
        function action(id: string, confirm: string): string {
            const a = Svc.Actions.byId(id);
            if (!a) return "unknown action: " + id;
            if (a.confirm === "confirm" && confirm !== "confirm") return "needs confirm: action " + id + " confirm";
            Svc.Actions.run(a); return "ok";
        }

        // Settings overrides (what the settings window writes). value is JSON:
        //   setting weatherImperial false · setting feedsRefreshMin 60
        function setting(key: string, value: string): string {
            if (!(key in Settings)) return "unknown setting: " + key;
            let v;
            try { v = JSON.parse(value); } catch (e) { v = value; }
            Prefs.override(key, v); return "ok";
        }
        function settingReset(key: string): string { Prefs.reset(key); return "ok"; }
        function settingGet(key: string): string { return key in Settings ? JSON.stringify(Settings[key]) : "unknown setting: " + key; }

        // Look. Empty shape/font = the theme's default.
        function themes(): string { return Theme.themeIds.join("\n"); }
        function theme(id: string): string {
            if (Theme.themeIds.indexOf(id) < 0) return "unknown theme: " + id;
            Prefs.set("theme", id); return "ok";
        }
        function shape(s: string): string {
            if (["", "square", "round"].indexOf(s) < 0) return "shape is square, round or \"\"";
            Prefs.set("shape", s); return "ok";
        }
        function font(id: string): string {
            if (id !== "" && !Theme.fonts.find(f => f.id === id)) return "unknown font: " + id;
            Prefs.set("font", id);
            return Theme.fontInstalled(Theme.fonts.find(f => f.id === id)) || id === "" ? "ok" : "ok (not installed; using DepartureMono)";
        }
        // Re-push the theme to Hyprland, ghostty, tmux, nvim, btop, zathura, SDDM.
        function themeApply(): string { Svc.ThemeSync.apply(); return "applying " + Theme.themeId; }
        function themeApplied(): string { return Svc.ThemeSync.lastResult; }
        function fonts(): string { return Theme.fonts.map(f => f.id + (Theme.fontInstalled(f) ? "" : "  (not installed)")).join("\n"); }
    }
}
