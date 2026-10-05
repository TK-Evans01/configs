pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// App search for the launcher: desktop entries ranked by fuzzy match + how
// often they were launched (kept in ~/.cache/quickshell/launcher-usage.json).
QtObject {
    id: root

    readonly property var apps: {
        const seen = {};
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay || seen[e.id] || Settings.launcherHidden.indexOf(e.id) >= 0) continue;
            seen[e.id] = true;
            out.push(e);
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }

    property var usage: ({})
    function uses(e) { return usage[e.id] || 0; }

    // Most launched first, ties by name.
    readonly property var frequent: apps.filter(e => uses(e) > 0)
        .sort((a, b) => uses(b) - uses(a) || a.name.localeCompare(b.name))
        .slice(0, Settings.launcherFrequent)

    // 0 = no match. Exact > prefix > word start > substring > in-order letters.
    function _score(q, text) {
        if (!text) return 0;
        const s = text.toLowerCase();
        if (s === q) return 1000;
        if (s.startsWith(q)) return 900 - Math.min(100, s.length);
        const i = s.indexOf(q);
        if (i > 0 && /[\s\-_.]/.test(s[i - 1])) return 700 - i;
        if (i >= 0) return 500 - i;
        let pos = -1, gaps = 0;
        for (const ch of q) {
            const n = s.indexOf(ch, pos + 1);
            if (n < 0) return 0;
            gaps += n - pos - 1;
            pos = n;
        }
        // Letters scattered across the whole name aren't a real match.
        if (gaps > q.length * 3) return 0;
        return Math.max(1, 300 - gaps * 10);
    }

    // Fuzzy score for other searches (actions, windows): 0 = no match.
    function score(q, text) { return _score(q, text); }

    // Focus mode can block an app until the session ends.
    function blocked(e) { return Focus.blocksEntry(e); }

    function search(query) {
        const q = query.trim().toLowerCase();
        if (!q) return [];
        const hits = [];
        for (const e of apps) {
            const bin = (e.command && e.command.length ? e.command[0] : "").split("/").pop();
            const s = Math.max(
                _score(q, e.name),
                _score(q, e.genericName) * 0.7,
                (e.keywords || []).reduce((m, k) => Math.max(m, _score(q, k)), 0) * 0.6,
                _score(q, bin) * 0.6);
            if (s > 0) hits.push({ entry: e, score: s + Math.min(150, uses(e) * 10) });
        }
        hits.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return hits.slice(0, 50).map(h => h.entry);
    }

    // "= 2*(3+4)" → "14", or "" when it isn't plain arithmetic.
    function calc(query) {
        const m = query.match(/^\s*=\s*(.+)$/);
        if (!m) return "";
        const expr = m[1].replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**").replace(/,/g, "");
        if (!/^[0-9+\-*/%().\s*e]+$/i.test(expr)) return "";
        try {
            const v = Function('"use strict"; return (' + expr + ')')();
            if (typeof v !== "number" || !isFinite(v)) return "";
            return String(Math.round(v * 1e10) / 1e10);
        } catch (err) {
            return "";
        }
    }

    function launch(e) {
        if (Focus.blocksEntry(e)) {
            Quickshell.execDetached(["notify-send", "-a", "Focus", e.name + " is blocked", "focus ends at " + Focus.endsText]);
            return;
        }
        if (!e) return;
        const next = Object.assign({}, usage);
        next[e.id] = (next[e.id] || 0) + 1;
        usage = next;
        usageFile.setText(JSON.stringify(usage));
        if (e.runInTerminal)
            Quickshell.execDetached([Settings.terminal, "-e"].concat(e.command));
        else
            e.execute();
    }

    function copy(text) {
        Quickshell.execDetached(["wl-copy", "--", text]);
    }

    readonly property var _mkdir: Process {
        running: true
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"]
    }

    readonly property var usageFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell/launcher-usage.json"
        printErrors: false
        onLoaded: {
            try { root.usage = JSON.parse(text()) || {}; } catch (err) { root.usage = {}; }
        }
    }
}
