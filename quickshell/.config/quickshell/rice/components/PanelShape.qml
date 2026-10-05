import QtQuick
import QtQuick.Shapes
import "../config"

// The silhouette of a panel attached to the bar, traced as one path (after
// caelestia's ShapePath backgrounds): concave joins where it meets the bar
// (and, for side panels, the screen bottom), rounded free corners, and an
// outline that continues the bar's own. Fill and outline share the geometry,
// so they can't drift apart.
//
//   attach "top"   — hangs from the bar (popups, OSD). Body is `bodyWidth`
//                    wide, starting `ear` px in; ears on both sides.
//   attach "right" / "left" — full-height side panel against that screen edge,
//                    ears on the inner side at the top (bar) and bottom (screen edge).
//
// The outline's centre line runs `strokeWidth / 2` below the top, so its two
// rows land exactly on the bar's outline rows (the window overlaps the bar by
// strokeWidth).
Shape {
    id: root

    property string attach: "top"
    property real bodyWidth: 0
    property real bodyHeight: 0        // top: the body; sides: the whole height
    property real ear: Theme.joinRadius
    property real corner: Theme.joinRadius   // free (convex) corners
    property color fill: Theme.background
    property color stroke: Theme.outline
    property real strokeWidth: Theme.outlineWidth

    readonly property real h: strokeWidth / 2
    width: attach === "top" ? bodyWidth + ear * 2 : bodyWidth + ear
    height: bodyHeight

    // Round shape has curves: smooth them with the curve renderer. Square is
    // all straight lines: no extra GPU buffers.
    preferredRendererType: Theme.round ? Shape.CurveRenderer : Shape.GeometryRenderer

    // Points of the outline's centre line, in order, plus arcs. For "left" the
    // "right" path is mirrored. All attachments share one description:
    // [x, y] for lines, [x, y, r, ccw] for arcs ending at (x, y). On screen,
    // the concave joins turn clockwise, the convex corners counter-clockwise.
    readonly property var _outline: {
        const e = ear, c = Math.min(corner, bodyWidth / 2), h = root.h;
        // Without ears (square) the side lines sit h inside the body so the
        // whole stroke stays visible.
        const s = e > 0 ? e : h;
        if (attach === "top") {
            const W = bodyWidth + 2 * e, H = bodyHeight;
            return [[0, h], [s, h + e, e, false], [s, H - c], [s + c, H, c, true],
                    [W - s - c, H], [W - s, H - c, c, true], [W - s, h + e], [W, h, e, false]];
        }
        const H = bodyHeight;
        const pts = [[0, h], [s, h + e, e, false], [s, H - e], [0, H, e, false]];
        if (attach === "left") {
            const W = bodyWidth + e;
            return pts.map(p => p.length > 2 ? [W - p[0], p[1], p[2], !p[3]] : [W - p[0], p[1]]);
        }
        return pts;
    }
    // The fill closes the outline back along the far edges and the top.
    readonly property var _fillClose: {
        const W = width, H = bodyHeight;
        if (attach === "top") return [[W, 0], [0, 0]];
        if (attach === "right") return [[W, H], [W, 0], [0, 0]];
        return [[0, H], [0, 0], [W, 0]];
    }

    // The outline as an SVG path string: no QML objects are created when the
    // geometry changes (a popup's height animates every frame).
    function _svg(list, close) {
        let d = "M " + list[0][0] + " " + list[0][1];
        for (const p of list.slice(1)) {
            if (p.length > 2 && p[2] > 0)
                d += " A " + p[2] + " " + p[2] + " 0 0 " + (p[3] ? 0 : 1) + " " + p[0] + " " + p[1];
            else
                d += " L " + p[0] + " " + p[1];
        }
        return close ? d + " Z" : d;
    }

    ShapePath {
        strokeWidth: -1
        fillColor: root.fill
        PathSvg { path: root._svg(root._outline.concat(root._fillClose), true) }
    }
    ShapePath {
        fillColor: "transparent"
        strokeColor: root.stroke
        strokeWidth: root.strokeWidth
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.MiterJoin
        PathSvg { path: root._svg(root._outline, false) }
    }
}
