pragma Singleton
import QtQuick
import Quickshell
import "../config"

// RSS / Atom reader for the sidebar's Feeds tab (Settings.feeds). Fetched in
// QML, no helper process. Read items are remembered in memory per session.
QtObject {
    id: root

    // [{ feed, title, link, date (Date|null), summary, read }], newest first.
    property var items: []
    property var errors: ({})        // feed name → message
    property bool loading: false
    property date updated: new Date(0)
    property var _read: ({})         // link → true
    readonly property int unread: items.filter(i => !_read[i.link]).length

    function refresh() {
        let pending = Settings.feeds.length;
        if (!pending) return;
        loading = true;
        const all = [], errs = {};
        for (const f of Settings.feeds) {
            const xhr = new XMLHttpRequest();
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                if (xhr.status === 200) {
                    try { all.push(..._parse(f.name, xhr.responseText).slice(0, Settings.feedsPerSource)); }
                    catch (e) { errs[f.name] = "can't parse"; }
                } else errs[f.name] = xhr.status ? "HTTP " + xhr.status : "offline";
                if (--pending === 0) {
                    all.sort((a, b) => (b.date ? b.date.getTime() : 0) - (a.date ? a.date.getTime() : 0));
                    root.items = all;
                    root.errors = errs;
                    root.loading = false;
                    root.updated = new Date();
                }
            };
            xhr.timeout = 15000;
            xhr.ontimeout = () => { errs[f.name] = "timed out"; if (--pending === 0) { root.items = all; root.errors = errs; root.loading = false; root.updated = new Date(); } };
            xhr.open("GET", f.url);
            xhr.setRequestHeader("User-Agent", "rice-feeds/1");
            xhr.send();
        }
    }

    function isRead(item) { return _read[item.link] === true; }
    function open(item) {
        if (!/^https?:\/\//i.test(item.link || "")) return;   // feeds are untrusted: web links only
        const r = Object.assign({}, _read); r[item.link] = true; _read = r;
        Quickshell.execDetached(["xdg-open", item.link]);
    }
    function markAllRead() {
        const r = Object.assign({}, _read);
        for (const i of items) r[i.link] = true;
        _read = r;
    }

    function _text(s) {
        return (s || "").replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1").replace(/<[^>]*>/g, " ")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'")
            .replace(/&#(\d+);/g, (m, n) => String.fromCharCode(Number(n))).replace(/&amp;/g, "&")
            .replace(/\s+/g, " ").trim();
    }
    function _tag(block, name) {
        const m = new RegExp("<" + name + "(?:\\s[^>]*)?>([\\s\\S]*?)</" + name + ">", "i").exec(block);
        return m ? m[1] : "";
    }
    // RSS <item> or Atom <entry>.
    function _parse(feed, xml) {
        const out = [];
        const re = /<(item|entry)[\s>][\s\S]*?<\/\1>/gi;
        let m;
        while ((m = re.exec(xml)) !== null) {
            const b = m[0];
            let link = _text(_tag(b, "link"));
            if (!link) {
                const l = /<link[^>]*href="([^"]+)"/i.exec(b);
                link = l ? l[1] : "";
            }
            const d = _text(_tag(b, "pubDate") || _tag(b, "updated") || _tag(b, "published") || _tag(b, "dc:date"));
            const date = d ? new Date(d) : null;
            // hnrss descriptions are just "Article URL: … Comments URL: …".
            let summary = _text(_tag(b, "description") || _tag(b, "summary"));
            if (/^Article URL:/.test(summary)) summary = "";
            out.push({
                feed: feed,
                title: _text(_tag(b, "title")),
                link: link,
                date: date && !isNaN(date.getTime()) ? date : null,
                summary: summary.slice(0, 240)
            });
        }
        return out;
    }

    readonly property var _timer: Timer {
        interval: Settings.feedsRefreshMin * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
