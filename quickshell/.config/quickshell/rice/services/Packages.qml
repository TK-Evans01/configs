pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Settings › Packages: search (repo + AUR), details, installed, updates,
// bundles. Data from scripts/pkg.py (read-only, never root). Every change
// goes through run(): the command opens in a terminal you watch — password,
// prompts and AUR PKGBUILD review all happen there.
QtObject {
    id: root

    readonly property string _script: Quickshell.shellDir + "/scripts/pkg.py"
    property bool hasYay: true
    readonly property var _yayCheck: Process {
        running: true
        command: ["sh", "-c", "command -v yay"]
        onExited: code => root.hasYay = code === 0
    }

    // Page state lives here so IPC can drive the page.
    property string tab: "search"
    property string openKey: ""          // "repo/name" or "aur/name" with details shown

    // --- data ---
    property var results: null       // { query, repo: [...], aur: [...]|null, aurError }
    property bool searching: false
    property var details: ({})       // "repo/name" → info
    property var installed: null     // { total, all, explicit, foreign, orphans }
    readonly property var installedSet: {
        const s = {};
        for (const n of (installed ? installed.all : [])) s[n] = true;
        return s;
    }
    property var updates: null       // { repo, aur, lastUpgrade, checkupdates }
    property bool checkingUpdates: false
    property var cache: null
    property var bundles: []

    readonly property var _bundleFile: FileView {
        path: Quickshell.shellDir + "/config/package-bundles.json"
        onLoaded: { try { root.bundles = JSON.parse(text()).bundles; } catch (e) {} }
    }

    // One reader per kind, so a slow update check never blocks a search.
    function _json(text) { try { return JSON.parse(text); } catch (e) { return null; } }
    function search(q) {
        q = q.trim();
        if (q.length < 2) { results = null; return; }
        searching = true;
        _search.run([_script, "search", q]);
    }
    // Search as you type: only the newest query's results land.
    readonly property var _search: LatestRun {
        onDone: (stdout, stderr, code) => { root.results = root._json(stdout); root.searching = false; }
    }
    function info(name, repo) {
        const key = repo + "/" + name;
        _info.key = key;
        _info.run([_script, "info", name, repo]);
    }
    readonly property var _info: LatestRun {
        property string key: ""
        onDone: (stdout, stderr, code) => { const d = Object.assign({}, root.details); d[key] = root._json(stdout) || { error: "no answer" }; root.details = d; }
    }
    function loadInstalled() { if (!_inst.running) _inst.running = true; }
    readonly property var _inst: Process {
        command: [root._script, "installed"]
        stdout: StdioCollector { id: ins; waitForEnd: true }
        onExited: root.installed = root._json(ins.text)
    }
    function checkUpdates() { if (!_upd.running) { checkingUpdates = true; _upd.running = true; } }
    readonly property var _upd: Process {
        command: [root._script, "updates"]
        stdout: StdioCollector { id: ups; waitForEnd: true }
        onExited: { root.updates = root._json(ups.text); root.checkingUpdates = false; }
    }
    function loadCache() { if (!_cache.running) _cache.running = true; }
    readonly property var _cache: Process {
        command: [root._script, "cache"]
        stdout: StdioCollector { id: cs; waitForEnd: true }
        onExited: root.cache = root._json(cs.text)
    }

    // --- changes: build the exact command, then run it through the backend ---
    // spec: { title, cmd (string, shown to you first), refresh: [...] }
    function q(names) { return names.map(n => "'" + n.replace(/'/g, "") + "'").join(" "); }
    function installSpec(names, aur) {
        return aur ? { title: "install " + names.join(" "), cmd: "yay -S " + q(names) }
                   : { title: "install " + names.join(" "), cmd: "sudo pacman -S --needed " + q(names) };
    }
    function removeSpec(names) { return { title: "remove " + names.join(" "), cmd: "sudo pacman -Rns " + q(names) }; }
    function upgradeSpec() { return { title: "system upgrade", cmd: hasYay ? "yay -Syu" : "sudo pacman -Syu" }; }
    function orphansSpec(names) { return { title: "remove orphans", cmd: "sudo pacman -Rns " + q(names) }; }
    function cacheSpec() { return { title: "clean package cache", cmd: "sudo paccache -rk2 && sudo paccache -ruk0" }; }

    property bool busy: _term.running
    property string running: ""      // title of the change in progress
    property string lastResult: ""

    function run(spec) {
        if (busy) return;
        running = spec.title;
        _term.command = [Settings.terminal, "--title=rice · " + spec.title, "-e", "sh", "-c",
            'printf "\\033[1m$ %s\\033[0m\\n\\n" "$1"; sh -c "$1"; s=$?; echo; '
            + '[ $s = 0 ] && echo "✓ done" || echo "✗ exited with $s"; printf "press enter to close "; read -r _; exit $s',
            "sh", spec.cmd];
        _term.running = true;
    }
    readonly property var _term: Process {
        onExited: code => {
            root.lastResult = root.running + (code === 0 ? " — done" : " — exited with " + code);
            root.running = "";
            root.details = ({});
            root.loadInstalled();
            if (root.results) root.search(root.results.query);
            if (root.updates) root.checkUpdates();
            if (root.cache) root.loadCache();
        }
    }
}
