pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// The wallpaper library: index (scripts/wallpaper.py: thumbs, colours, fit to
// each theme), your tags (data/wallpapers.json: themes, seasons, favourite)
// and what's shown (state). Ranks for the current theme + season, applies
// through awww, and rotates on a timer (Settings.wallpaperRotateMin).
QtObject {
    id: root

    readonly property string _script: Quickshell.shellDir + "/scripts/wallpaper.py"
    readonly property string _curatedPath: Quickshell.shellDir + "/data/wallpapers.json"
    readonly property string _statePath: Quickshell.env("HOME") + "/.local/state/rice/wallpaper.json"

    property var index: ({})        // key → computed entry
    property var curated: ({})      // key → { themes, seasons, tags, fav, auto, reviewed }
    property var state: ({ outputs: {}, history: [], uses: {} })
    property bool indexing: false
    property string error: ""

    // --- season (meteorological, northern hemisphere) ---
    property date today: new Date()
    readonly property string season: {
        const m = today.getMonth();
        return m >= 2 && m <= 4 ? "spring" : m >= 5 && m <= 7 ? "summer" : m >= 8 && m <= 10 ? "autumn" : "winter";
    }

    // --- loading ---
    function reindex() { if (!_index.running) { indexing = true; _index.running = true; } }
    readonly property var _index: Process {
        command: ["python3", root._script, "index", "--dir", Settings.wallpaperDir]
        stdout: StdioCollector { id: ix; waitForEnd: true }
        stderr: StdioCollector { id: ixErr; waitForEnd: true }
        onExited: code => {
            root.indexing = false;
            try { root.index = JSON.parse(ix.text).items || {}; root.error = ""; }
            catch (e) { root.error = ixErr.text.trim().split("\n").pop() || "index failed"; }
        }
    }
    readonly property var _curatedFile: FileView {
        path: root._curatedPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.curated = JSON.parse(text()).items || {}; } catch (e) {} }
    }
    readonly property var _stateFile: FileView {
        path: root._statePath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.state = JSON.parse(text()); } catch (e) {} }
    }
    Component.onCompleted: reindex()

    function shownOn(output) { const o = state.outputs && state.outputs[output]; return o ? o.path : ""; }

    // --- ranking ---
    // A record for the UI: computed + tags + score for the current theme / season.
    function record(key) {
        const e = index[key];
        if (!e) return null;
        const c = curated[key] || { themes: [], seasons: [], fav: false, auto: { themes: true, seasons: true } };
        const themeHit = (c.themes || []).indexOf(Theme.themeId) >= 0;
        const seasons = c.seasons || [];
        const seasonHit = seasons.indexOf(season) >= 0 || seasons.indexOf("any") >= 0 || seasons.length === 0;
        const dist = e.dist ? (e.dist[Theme.themeId] || 99) : 99;
        const uses = state.uses && state.uses[e.path] ? state.uses[e.path] : { n: 0, last: 0 };
        let score = 0;
        if (themeHit) score += c.auto && c.auto.themes ? 30 : 40;
        if (seasonHit) score += seasons.indexOf(season) >= 0 ? 15 : 8;
        if (c.fav) score += 10;
        score -= Math.min(30, dist);
        return Object.assign({}, e, {
            key: key, name: key.split("/").pop().replace(/\.[^.]+$/, "").replace(/[_-]+/g, " "),
            themes: c.themes || [], seasons: seasons, tags: c.tags || [], fav: !!c.fav,
            autoThemes: !c.auto || c.auto.themes !== false, autoSeasons: !c.auto || c.auto.seasons !== false,
            reviewed: !!c.reviewed, themeHit: themeHit, seasonHit: seasonHit, fit: dist, score: score,
            lastUsed: uses.last, uses: uses.n
        });
    }
    // Every wallpaper, best for the current theme + season first; nothing is
    // ever filtered out (non-matches sort lower and the picker dims them).
    readonly property var ranked: {
        Theme.themeId; season; curated; state;
        return Object.keys(index).map(k => record(k)).filter(x => x).sort((a, b) => b.score - a.score || a.fit - b.fit);
    }
    readonly property var suggested: ranked.filter(r => r.themeHit && r.seasonHit)

    // --- tags (written to data/wallpapers.json; edited fields stop being auto) ---
    function _writeCurated(c) {
        curated = c;
        const keys = Object.keys(c).sort(), items = {};
        for (const k of keys) items[k] = c[k];
        _curatedFile.setText(JSON.stringify({ schema: 1, items: items }, null, 1) + "\n");
    }
    function _rec(key) {
        const e = index[key] || {};
        return Object.assign({ sha: e.sha || "", themes: [], seasons: [], tags: [], fav: false,
                               auto: { themes: true, seasons: true }, reviewed: false }, curated[key] || {});
    }
    function toggleTheme(key, id) {
        const r = _rec(key);
        r.themes = r.themes.indexOf(id) >= 0 ? r.themes.filter(t => t !== id) : r.themes.concat([id]);
        r.auto = Object.assign({}, r.auto, { themes: false }); r.reviewed = true;
        const c = Object.assign({}, curated); c[key] = r; _writeCurated(c);
    }
    function toggleSeason(key, s) {
        const r = _rec(key);
        r.seasons = r.seasons.indexOf(s) >= 0 ? r.seasons.filter(t => t !== s) : r.seasons.filter(t => s === "any" ? false : t !== "any").concat([s]);
        r.auto = Object.assign({}, r.auto, { seasons: false }); r.reviewed = true;
        const c = Object.assign({}, curated); c[key] = r; _writeCurated(c);
    }
    function toggleFav(key) {
        const r = _rec(key); r.fav = !r.fav;
        const c = Object.assign({}, curated); c[key] = r; _writeCurated(c);
    }

    // --- applying ---
    property string lastResult: ""
    function apply(key, output, placement) {
        const r = index[key];
        if (!r) return;
        _applyQ.run(["python3", _script, "set", r.path, "--output", output || "all", "--placement", placement || Settings.wallpaperPlacement]);
        // "follow": the wallpaper's own theme comes with it.
        const c = curated[key];
        if (Settings.wallpaperThemePolicy === "follow" && c && c.themes && c.themes.length && c.themes.indexOf(Theme.themeId) < 0)
            Prefs.set("theme", c.themes[0]);
    }
    // Applies run one after another (a rotation tick during a pick isn't lost).
    readonly property var _applyQ: CmdQueue { onDrained: root._stateFile.reload() }

    // Pick the next one: among the best few for now, not recently shown.
    function next(output) {
        const recent = (state.history || []).slice(0, 5);
        const pool = ranked.filter(r => recent.indexOf(r.path) < 0).slice(0, 6);
        const pick = (pool.length ? pool : ranked)[Math.floor(Math.random() * Math.max(1, Math.min(pool.length || ranked.length, 6)))];
        if (pick) apply(pick.key, output || "all", Settings.wallpaperPlacement);
    }
    readonly property var _rotate: Timer {
        interval: Math.max(1, Settings.wallpaperRotateMin) * 60000
        running: Settings.wallpaperRotateMin > 0 && Object.keys(root.index).length > 0
        repeat: true
        onTriggered: { root.today = new Date(); root.next("all"); }
    }
}
