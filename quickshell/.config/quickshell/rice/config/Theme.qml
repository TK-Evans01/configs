pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel

// Design tokens. Colours come from the theme file `themes/<id>.json`
// (Prefs.theme), shape and font from Prefs or the theme's defaults; see
// docs/ui-rules.md. Colour roles cross-fade when the theme changes.
//
// A theme file gives a `palette` (bg0..4, fg0/1, grey, greyDim, and the
// seven hues as "#hex" or [base, dim, bright]) and may override `roles`
// with a palette key or a hex. `preview(id)` swaps the palette only, until
// `endPreview()`; shape and font always follow the committed theme.
Singleton {
    id: root

    readonly property string themesDir: Quickshell.shellDir + "/themes"
    readonly property string themeId: Prefs.theme || "gruvbox-material-dark"
    property string previewId: ""
    // Drop the last previewed palette at once so it can't flash under the next.
    onPreviewIdChanged: _preview = ({})
    // Ids of the presets in themes/ (fonts.json excluded).
    readonly property var themeIds: {
        const out = [];
        for (let i = 0; i < _folder.count; i++) {
            const n = _folder.get(i, "fileBaseName");
            if (n !== "fonts") out.push(n);
        }
        return out;
    }
    readonly property var _folder: FolderListModel {
        folder: "file://" + root.themesDir
        nameFilters: ["*.json"]
        showDirs: false
    }
    function preview(id) { previewId = id === themeId ? "" : id; }
    function endPreview() { previewId = ""; }

    // Parsed theme files: the committed one and, while previewing, the preview.
    property var _theme: ({})
    property var _preview: ({})
    readonly property var _pal: previewId !== "" && _preview.palette ? _preview : _theme

    readonly property var _themeFile: FileView {
        path: root.themesDir + "/" + root.themeId + ".json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._theme = root._parse(text())
        onLoadFailed: { console.warn("Theme: no theme file", path); root._theme = ({}); }
    }
    readonly property var _previewFile: FileView {
        path: root.previewId !== "" ? root.themesDir + "/" + root.previewId + ".json" : ""
        onLoaded: root._preview = root._parse(text())
    }
    function _parse(t) {
        try { return JSON.parse(t); } catch (e) { console.warn("Theme: bad JSON", e); return ({}); }
    }

    readonly property var _defaults: ({"bg0": "#1d2021", "bg1": "#282828", "bg2": "#32302f", "bg3": "#45403d", "bg4": "#5a524c", "fg0": "#d4be98", "fg1": "#ddc7a1", "grey": "#a89984", "greyDim": "#7c6f64", "red": ["#ea6962", "#a94b47", "#f28985"], "orange": ["#e78a4e", "#a55f35", "#f0a670"], "yellow": ["#d8a657", "#9c763e", "#e8bf7c"], "green": ["#a9b665", "#788348", "#c2cf85"], "aqua": ["#89b482", "#5e815a", "#a7c9a1"], "blue": ["#7daea3", "#567c73", "#9ec5bb"], "purple": ["#d3869b", "#9d6b82", "#e8a5b8"]})

    // Palette key (or "#hex") → colour. Hues may be "#hex" or [base, dim, bright];
    // missing dim/bright variants are derived from the base.
    function _key(k) {
        if (typeof k === "string" && k.charAt(0) === "#") return k;
        const pal = (_pal && _pal.palette) || {};
        const m = /^(red|orange|yellow|green|aqua|blue|purple)(Dim|Bright)?$/.exec(k);
        if (m) {
            const v = pal[m[1]] !== undefined ? pal[m[1]] : _defaults[m[1]];
            const arr = Array.isArray(v) ? v : [v];
            if (!m[2]) return arr[0];
            if (m[2] === "Dim") return arr[1] || Qt.darker(arr[0], 1.45);
            return arr[2] || Qt.lighter(arr[0], 1.18);
        }
        return pal[k] !== undefined ? pal[k] : (_defaults[k] || "#ff00ff");
    }
    function _role(name, fallbackKey) {
        const r = _pal && _pal.roles ? _pal.roles[name] : undefined;
        return _key(r !== undefined ? r : fallbackKey);
    }

    // --- raw palette ---
    property color bg0: _key("bg0")
    property color bg1: _key("bg1")
    property color bg2: _key("bg2")
    property color bg3: _key("bg3")
    property color bg4: _key("bg4")
    property color fg0: _key("fg0")
    property color fg1: _key("fg1")
    property color grey: _key("grey")
    property color greyDim: _key("greyDim")
    property color red: _key("red")
    property color redDim: _key("redDim")
    property color redBright: _key("redBright")
    property color orange: _key("orange")
    property color orangeDim: _key("orangeDim")
    property color orangeBright: _key("orangeBright")
    property color yellow: _key("yellow")
    property color yellowDim: _key("yellowDim")
    property color yellowBright: _key("yellowBright")
    property color green: _key("green")
    property color greenDim: _key("greenDim")
    property color greenBright: _key("greenBright")
    property color aqua: _key("aqua")
    property color aquaDim: _key("aquaDim")
    property color aquaBright: _key("aquaBright")
    property color blue: _key("blue")
    property color blueDim: _key("blueDim")
    property color blueBright: _key("blueBright")
    property color purple: _key("purple")
    property color purpleDim: _key("purpleDim")
    property color purpleBright: _key("purpleBright")

    // --- semantic roles (what components bind to) ---
    property color background: _role("background", "bg1")   // bar + popup panels
    property color surface0: _role("surface0", "bg0")   // cards sit darker than the panel
    property color surface1: _role("surface1", "bg2")   // hover / raised
    property color surface2: _role("surface2", "bg3")   // borders, tracks, pressed
    property color surface3: _role("surface3", "bg4")
    property color text: _role("text", "fg0")
    property color textBright: _role("textBright", "fg1")
    property color textReverse: _role("textReverse", "bg0")   // text on a filled accent
    property color subtext: _role("subtext", "grey")
    property color muted: _role("muted", "greyDim")
    property color accent: _role("accent", "yellow")
    property color success: _role("success", "green")
    property color warning: _role("warning", "orange")
    property color error: _role("error", "red")
    property color info: _role("info", "blue")
    property color pending: _role("pending", "yellow")   // in progress: connecting, starting, scanning
    property color catMedia: _role("catMedia", "purple")
    property color catMediaBright: _role("catMediaBright", "purpleBright")
    property color outline: _role("outline", "fg0")   // outer edge of shell surfaces (bar, popups, panels)
    property color catSystem: _role("catSystem", "blue")
    property color catNet: _role("catNet", "green")   // VPN, connectivity
    property color catTime: _role("catTime", "aqua")   // clock, calendar, agenda
    property color catWeather: _role("catWeather", "aqua")
    property color catDev: _role("catDev", "green")   // GitHub
    property color catNotify: _role("catNotify", "purple")
    // Data series (meters, sparklines) in a fixed order: cpu, gpu, mem, disk.
    readonly property var series: [blue, purple, aqua, yellow]

    // Raw hues (red…purple) are part of every theme; use them only when the
    // hue is the meaning (sun, rain, warmth, PR/issue tags, weekend).

    // Cross-fade every role on a theme switch.
    Behavior on background { ColorAnimation { duration: root.animLong } }
    Behavior on surface0 { ColorAnimation { duration: root.animLong } }
    Behavior on surface1 { ColorAnimation { duration: root.animLong } }
    Behavior on surface2 { ColorAnimation { duration: root.animLong } }
    Behavior on surface3 { ColorAnimation { duration: root.animLong } }
    Behavior on text { ColorAnimation { duration: root.animLong } }
    Behavior on textBright { ColorAnimation { duration: root.animLong } }
    Behavior on textReverse { ColorAnimation { duration: root.animLong } }
    Behavior on subtext { ColorAnimation { duration: root.animLong } }
    Behavior on muted { ColorAnimation { duration: root.animLong } }
    Behavior on accent { ColorAnimation { duration: root.animLong } }
    Behavior on success { ColorAnimation { duration: root.animLong } }
    Behavior on warning { ColorAnimation { duration: root.animLong } }
    Behavior on error { ColorAnimation { duration: root.animLong } }
    Behavior on info { ColorAnimation { duration: root.animLong } }
    Behavior on pending { ColorAnimation { duration: root.animLong } }
    Behavior on catMedia { ColorAnimation { duration: root.animLong } }
    Behavior on catMediaBright { ColorAnimation { duration: root.animLong } }
    Behavior on catSystem { ColorAnimation { duration: root.animLong } }
    Behavior on outline { ColorAnimation { duration: root.animLong } }
    Behavior on catNet { ColorAnimation { duration: root.animLong } }
    Behavior on catTime { ColorAnimation { duration: root.animLong } }
    Behavior on catWeather { ColorAnimation { duration: root.animLong } }
    Behavior on catDev { ColorAnimation { duration: root.animLong } }
    Behavior on catNotify { ColorAnimation { duration: root.animLong } }

    // Usage → color: calm under 75%, warm under 90%, red past it.
    function usageColor(pct, calm) {
        if (pct >= 90) return red;
        if (pct >= 75) return orange;
        return calm === undefined ? text : calm;
    }
    function tempColor(c) {
        if (c >= 85) return red;
        if (c >= 70) return orange;
        return subtext;
    }

    // --- type: one named scale per font (themes/fonts.json) ---
    property var fonts: []
    readonly property var _fontsFile: FileView {
        path: root.themesDir + "/fonts.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.fonts = (root._parse(text()).fonts || [])
    }
    // Installed families only: Qt silently substitutes a missing one.
    function fontInstalled(f) { return f && Qt.fontFamilies().indexOf(f.family) >= 0; }
    readonly property string fontId: Prefs.font || _theme.font || "departure-mono"
    readonly property var _font: {
        const want = fonts.find(f => f.id === fontId);
        if (fontInstalled(want)) return want;
        return fonts.find(f => f.id === "departure-mono") || null;
    }
    function _size(k, d) { return _font && _font.sizes && _font.sizes[k] ? _font.sizes[k] : d; }

    readonly property string fontFamily: _font ? _font.family : "DepartureMono Nerd Font Mono"
    readonly property int fontXs: _size("xs", 11)        // captions, axis labels, hints
    readonly property int fontSm: _size("sm", 12)        // meta lines: sublabels, ages, counts
    readonly property int fontBase: _size("base", 14)    // body
    readonly property int fontTitle: _size("title", 15)  // row / tile / bar item titles
    readonly property int fontMd: _size("md", 18)        // glyphs in rows, emphasis
    readonly property int fontLg: _size("lg", 22)        // page glyphs, big values
    readonly property int fontXl: _size("xl", 44)        // hero numbers
    readonly property int fontHuge: _size("huge", 66)    // clock
    readonly property int iconSize: _size("icon", 22)
    readonly property int iconSizeLarge: _size("iconLg", 33)

    // --- shape: "square" (retro) or "round". Radii and the accent style follow it.
    readonly property string shape: {
        const s = Prefs.shape || _theme.shape || "square";
        return s === "round" ? "round" : "square";
    }
    readonly property bool round: shape === "round"
    readonly property int radius: round ? 8 : 0          // cards, panels, tiles
    readonly property int radiusSmall: round ? 4 : 0     // buttons, inputs, chips, rows
    readonly property int radiusPill: round ? 999 : 0    // tracks, handles (Qt clamps to h/2)
    // Where shell surfaces meet (bar + popup, panel + screen edge): inverted
    // corners of this radius make them one surface. 0 in square mode.
    readonly property int joinRadius: round ? 14 : 0
    // square: a 2px underline / side bar marks the selected item.
    // round:  a soft pill fills behind it.
    readonly property string accentStyle: round ? "pill" : "underline"

    // --- geometry ---
    readonly property int pad: 11
    readonly property int gap: 16
    readonly property int spacing: 8
    readonly property int border: 1
    readonly property int outlineWidth: 2        // outer edge of shell surfaces
    readonly property int accentThickness: 2
    readonly property int rowHeight: 44          // list rows with title + subtitle
    readonly property int rowHeightCompact: 32   // single-line rows (menus)
    readonly property int controlHeight: fontMd + spacing * 2   // buttons, inputs, chips

    // --- motion --- (a theme with "motion": "none", e.g. e-ink, snaps instead)
    readonly property bool still: _theme.motion === "none"
    readonly property int animShort: still ? 0 : 120
    readonly property int anim: still ? 0 : 200
    readonly property int animLong: still ? 0 : 320
    readonly property int easing: Easing.OutCubic
}
