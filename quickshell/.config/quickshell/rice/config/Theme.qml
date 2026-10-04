pragma Singleton
import QtQuick

QtObject {
    // --- gruvbox-material palette ---
    readonly property color bg0: "#1d2021"
    readonly property color bg1: "#282828"
    readonly property color bg2: "#32302f"
    readonly property color bg3: "#45403d"
    readonly property color bg4: "#5a524c"
    readonly property color fg0: "#d4be98"
    readonly property color fg1: "#ddc7a1"
    readonly property color grey: "#a89984"
    readonly property color greyDim: "#7c6f64"
    readonly property color red: "#ea6962"
    readonly property color redDim: "#a94b47"
    readonly property color redBright: "#f28985"
    readonly property color orange: "#e78a4e"
    readonly property color orangeDim: "#a55f35"
    readonly property color orangeBright: "#f0a670"
    readonly property color yellow: "#d8a657"
    readonly property color yellowDim: "#9c763e"
    readonly property color yellowBright: "#e8bf7c"
    readonly property color green: "#a9b665"
    readonly property color greenDim: "#788348"
    readonly property color greenBright: "#c2cf85"
    readonly property color aqua: "#89b482"
    readonly property color aquaDim: "#5e815a"
    readonly property color aquaBright: "#a7c9a1"
    readonly property color blue: "#7daea3"
    readonly property color blueDim: "#567c73"
    readonly property color blueBright: "#9ec5bb"
    readonly property color purple: "#d3869b"
    readonly property color purpleDim: "#9d6b82"
    readonly property color purpleBright: "#e8a5b8"

    // --- semantic roles (what components bind to) ---
    readonly property color background: bg1     // bar + popup panels
    readonly property color surface0: bg0       // cards sit darker than the panel
    readonly property color surface1: bg2       // hover / raised
    readonly property color surface2: bg3       // borders, tracks, pressed
    readonly property color surface3: bg4
    readonly property color text: fg0
    readonly property color textBright: fg1
    readonly property color textReverse: bg0
    readonly property color subtext: grey
    readonly property color muted: greyDim
    readonly property color accent: yellow
    readonly property color success: green
    readonly property color warning: orange
    readonly property color error: red
    readonly property color info: blue

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

    // --- type ---
    readonly property string fontFamily: "DepartureMono Nerd Font Mono"
    readonly property int fontSizeSmall: 14
    readonly property int fontSize: 18
    readonly property int fontSizeLarge: 22
    readonly property int fontSizeHuge: 66
    // Bar glyphs; DepartureMono is drawn on an 11px grid, 22 stays crisp.
    readonly property int iconSize: 22
    readonly property int iconSizeLarge: 33

    // --- geometry (retro: square, hairline borders, underline accents) ---
    readonly property int pad: 11
    readonly property int gap: 16
    readonly property int spacing: 8
    readonly property int radius: 0
    readonly property int border: 1
    readonly property int accentThickness: 2

    // --- motion ---
    readonly property int animShort: 120
    readonly property int anim: 200
    readonly property int animLong: 320
}
