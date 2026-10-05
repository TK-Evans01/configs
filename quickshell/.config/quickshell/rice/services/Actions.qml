pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// The shell's action allowlist (config/actions.json) plus one action per
// installed theme. The launcher's > mode, settings search and the voice
// assistant pick from here; running one is an IPC call on target `rice`,
// the same path a keybind takes.
QtObject {
    id: root

    property var _static: []
    readonly property var all: _static.concat(Theme.themeIds.map(id => ({
        id: "theme." + id, title: "Theme: " + id, icon: "󰏘", group: "look",
        call: ["theme", id], aliases: ["theme", "colours", "colors"], confirm: "none", voice: true
    })))

    readonly property var _file: FileView {
        path: Quickshell.shellDir + "/config/actions.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root._static = JSON.parse(text()).actions || []; }
            catch (e) { console.warn("Actions: bad actions.json", e); }
        }
    }

    function byId(id) { return all.find(a => a.id === id) || null; }

    // Ranked matches on title, aliases and group.
    function search(query) {
        const q = query.trim().toLowerCase();
        if (!q) return all;
        const hits = [];
        for (const a of all) {
            const s = Math.max(
                Launcher.score(q, a.title),
                a.aliases.reduce((m, k) => Math.max(m, Launcher.score(q, k)), 0) * 0.8,
                Launcher.score(q, a.group) * 0.5);
            if (s > 0) hits.push({ a: a, s: s });
        }
        hits.sort((x, y) => y.s - x.s);
        return hits.map(h => h.a);
    }

    function run(a) {
        if (!a) return;
        Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "rice"].concat(a.call));
    }
}
