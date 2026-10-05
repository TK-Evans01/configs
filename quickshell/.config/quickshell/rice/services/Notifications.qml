pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../config"

// The notification daemon (org.freedesktop.Notifications; dunst must not
// run). Every notification lands in `history`, grouped by source (mail,
// chat, dev, media, system — Settings.notifySources). Toasts pop up unless
// DND is on (critical always shows) or the source is over its rate limit.
// History survives restarts in ~/.local/state/rice/notifications.json.
QtObject {
    id: root

    // [{ id, app, source, summary, body, urgency, icon, image, time (ms), read }], newest first.
    property var history: []
    // ids currently shown as toasts, oldest first.
    property var toasts: []
    readonly property bool dnd: Prefs.dnd
    readonly property int unread: history.filter(h => !h.read).length
    // The sidebar shows the history: while it is open nothing pops up and
    // everything counts as read.
    property bool panelOpen: false
    onPanelOpenChanged: if (panelOpen) { toasts = []; markAllRead(); }

    function setDnd(on) { Prefs.set("dnd", on); }
    function toggleDnd() { setDnd(!dnd); }

    // Live Notification objects by id (actions, dismiss); gone after a restart.
    property var _live: ({})

    function sourceOf(app) {
        const a = (app || "").toLowerCase();
        for (const s of Settings.notifySources)
            if (s.apps.some(x => a === x || a.indexOf(x) >= 0)) return s.id;
        return "system";
    }
    function sourceInfo(id) {
        return Settings.notifySources.find(s => s.id === id) || Settings.notifySources[Settings.notifySources.length - 1];
    }

    // [{ id, label, icon, items, unread }] in Settings order, empty groups dropped.
    readonly property var groups: Settings.notifySources.map(s => {
        const items = history.filter(h => h.source === s.id);
        return { id: s.id, label: s.label, icon: s.icon, items: items, unread: items.filter(h => !h.read).length };
    }).filter(g => g.items.length > 0)

    readonly property var server: NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        onNotification: n => root._add(n)
    }

    function _add(n) {
        n.tracked = true;
        const rec = {
            id: n.id,
            app: n.appName || "unknown",
            source: sourceOf(n.appName),
            summary: n.summary || "",
            body: (n.body || "").replace(/<[^>]*>/g, ""),
            urgency: n.urgency === NotificationUrgency.Critical ? "critical" : n.urgency === NotificationUrgency.Low ? "low" : "normal",
            icon: n.appIcon || "",
            image: n.image || "",
            time: Date.now(),
            read: panelOpen,
            actions: (n.actions || []).map(a => ({ id: a.identifier, text: a.text }))
        };
        const live = Object.assign({}, _live); live[n.id] = n; _live = live;
        n.closed.connect(() => { const l = Object.assign({}, root._live); delete l[rec.id]; root._live = l; root._dropToast(rec.id); });
        // Apps replace a notification in place (progress, now playing): keep the record current.
        const refresh = () => root._update(rec.id, { summary: n.summary || "", body: (n.body || "").replace(/<[^>]*>/g, "") });
        n.summaryChanged.connect(refresh);
        n.bodyChanged.connect(refresh);
        // Replacement (same id): update in place.
        const rest = history.filter(h => h.id !== rec.id);
        const all = [rec].concat(rest);
        // Records that fall off the end let go of their live notification too.
        for (const h of all.slice(Settings.notifyHistory)) if (_live[h.id]) _live[h.id].dismiss();
        history = all.slice(0, Settings.notifyHistory);
        _maybeToast(rec);
        _save.restart();
    }

    // --- toasts ---
    property var _sent: ({})     // source → [timestamps]
    function _maybeToast(rec) {
        if (panelOpen) return;
        if (dnd && rec.urgency !== "critical") return;
        // Focus mode: "focus" lets only critical through, "total" nothing.
        if (Focus.quiet === "total" || (Focus.quiet === "focus" && rec.urgency !== "critical")) return;
        if (rec.urgency === "low") return;
        const now = Date.now();
        const sent = (_sent[rec.source] || []).filter(t => now - t < Settings.toastPerSourceWindow);
        if (rec.urgency !== "critical" && sent.length >= Settings.toastPerSourceMax) return;
        const s = Object.assign({}, _sent); s[rec.source] = sent.concat([now]); _sent = s;
        toasts = toasts.filter(id => id !== rec.id).concat([rec.id]).slice(-Settings.toastMax);
        const t = timeoutFor(rec.id);
        const e = Object.assign({}, toastEnds); e[rec.id] = t > 0 ? now + t : 0; toastEnds = e;
        toastNow = now;
    }

    // Toast deadlines live here (not in the delegates, which a model change
    // rebuilds): id → end (ms, 0 = stays). Hover pauses one toast.
    property var toastEnds: ({})
    property var _paused: ({})          // id → ms left when paused
    property real toastNow: Date.now()
    function pauseToast(id) {
        if (!(id in toastEnds) || toastEnds[id] === 0 || id in _paused) return;
        const p = Object.assign({}, _paused); p[id] = Math.max(0, toastEnds[id] - Date.now()); _paused = p;
    }
    function resumeToast(id) {
        if (!(id in _paused)) return;
        const e = Object.assign({}, toastEnds); e[id] = Date.now() + _paused[id]; toastEnds = e;
        const p = Object.assign({}, _paused); delete p[id]; _paused = p;
    }
    // 0..1 of the toast's time left (for its bar); 1 while paused or sticky.
    function toastLeft(id) {
        const end = toastEnds[id], total = timeoutFor(id);
        if (!end || !total) return 1;
        if (id in _paused) return _paused[id] / total;
        return Math.max(0, Math.min(1, (end - toastNow) / total));
    }
    readonly property var _toastTick: Timer {
        interval: 100
        repeat: true
        running: root.toasts.length > 0
        onTriggered: {
            root.toastNow = Date.now();
            for (const id of root.toasts) {
                const end = root.toastEnds[id];
                if (end && !(id in root._paused) && root.toastNow >= end) root.expireToast(id);
            }
        }
    }
    function _dropToast(id) {
        toasts = toasts.filter(t => t !== id);
        if (id in toastEnds) { const e = Object.assign({}, toastEnds); delete e[id]; toastEnds = e; }
        if (id in _paused) { const p = Object.assign({}, _paused); delete p[id]; _paused = p; }
    }
    function byId(id) { return history.find(h => h.id === id) || null; }
    // How long a toast stays: the app's timeout, else ours; critical stays.
    function timeoutFor(id) {
        const r = byId(id), n = _live[id];
        if (r && r.urgency === "critical") return 0;
        return n && n.expireTimeout > 0 ? n.expireTimeout : Settings.toastTimeout;
    }
    function expireToast(id) {
        _dropToast(id);
        const n = _live[id];
        if (n) n.expire();
    }

    // --- actions on a record ---
    function hasLive(id) { return _live[id] !== undefined; }
    function invoke(id, actionId) {
        const n = _live[id];
        if (!n) return;
        const a = (n.actions || []).find(x => x.identifier === actionId);
        if (a) a.invoke();
        _dropToast(id);
    }
    // Default action, if the app offered one.
    function activate(id) {
        const r = byId(id);
        if (r && r.actions.some(a => a.id === "default")) invoke(id, "default");
        else _dropToast(id);
        markRead(id);
    }
    function dismiss(id) {
        const n = _live[id];
        if (n) n.dismiss();
        history = history.filter(h => h.id !== id);
        _dropToast(id);
        _save.restart();
    }
    function clearSource(source) {
        for (const h of history) if (h.source === source && _live[h.id]) _live[h.id].dismiss();
        history = history.filter(h => h.source !== source);
        _save.restart();
    }
    function clearAll() {
        for (const id in _live) _live[id].dismiss();
        history = [];
        toasts = [];
        _save.restart();
    }
    function _update(id, change) {
        history = history.map(h => h.id === id ? Object.assign({}, h, change) : h);
        _save.restart();
    }
    function markRead(id) {
        history = history.map(h => h.id === id && !h.read ? Object.assign({}, h, { read: true }) : h);
        _save.restart();
    }
    function markAllRead() {
        if (unread === 0) return;
        history = history.map(h => h.read ? h : Object.assign({}, h, { read: true }));
        _save.restart();
    }

    // After a reload the server keeps its tracked notifications: take them
    // back so their actions and dismiss still work.
    function _adopt() {
        for (const n of server.trackedNotifications.values) {
            if (_live[n.id]) continue;
            if (history.some(h => h.id === n.id)) { const l = Object.assign({}, _live); l[n.id] = n; _live = l; }
            else _add(n);
        }
    }

    // --- persistence ---
    readonly property string _path: Quickshell.env("HOME") + "/.local/state/rice/notifications.json"
    property bool _restored: false
    readonly property var _file: FileView {
        path: root._path
        atomicWrites: true
        onLoaded: {
            try {
                const saved = JSON.parse(text()).history || [];
                // Keep anything that arrived before the file loaded.
                // Server ids restart at 1, so restored entries get their own.
                root.history = root.history.concat(saved.map((h, i) =>
                    Object.assign({}, h, { id: "r" + h.time + "-" + i, actions: [] })))
                    .slice(0, Settings.notifyHistory);
            } catch (e) { console.warn("Notifications: bad history file", e); }
            root._restored = true;
            root._adopt();
            root._save.restart();   // anything that arrived before the file loaded
        }
        onLoadFailed: { root._restored = true; root._adopt(); root._save.restart(); }
    }
    readonly property var _save: Timer {
        interval: 500
        onTriggered: if (root._restored) root._file.setText(JSON.stringify({ schema: 1, history: root.history.map(h => Object.assign({}, h, { actions: [] })) }))
    }
}
