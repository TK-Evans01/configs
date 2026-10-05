pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Who is using the mic, the webcam or the screen — from PipeWire's graph,
// event-driven (no polling):
//   mic     audio-input streams (an app recording); speaker-monitor meters skipped
//   camera  an active link out of a v4l2 / libcamera video source
//   screen  an active link out of any other video source (screencast portal)
// Apps that open /dev/video* directly, bypassing PipeWire, aren't seen.
QtObject {
    id: root

    readonly property var _nodes: Pipewire.nodes.values
    readonly property var _groups: Pipewire.linkGroups.values
    // Link state and node properties only update for tracked objects.
    readonly property var _track: PwObjectTracker { objects: root._nodes.concat(root._groups) }

    function _p(n, k) { return n && n.properties ? (n.properties[k] || "") : ""; }
    function _app(n) {
        return _p(n, "application.name") || _p(n, "application.process.binary") || _p(n, "node.description") || (n ? n.name : "?");
    }
    function _isCamera(n) {
        const api = _p(n, "device.api"), name = n ? n.name || "" : "";
        return api === "v4l2" || api === "libcamera" || name.startsWith("v4l2_") || name.startsWith("libcamera");
    }

    readonly property var micApps: {
        const out = [];
        for (const n of _nodes) {
            if (!n.isStream || _p(n, "media.class") !== "Stream/Input/Audio") continue;
            if (_p(n, "stream.monitor") === "true" || _p(n, "stream.capture.sink") === "true") continue;
            const a = _app(n);
            if (out.indexOf(a) < 0) out.push(a);
        }
        return out;
    }
    function _videoUsers(camera) {
        const out = [];
        for (const g of _groups) {
            const s = g.source, t = g.target;
            if (!s || _p(s, "media.class") !== "Video/Source" || _isCamera(s) !== camera) continue;
            if (g.state !== PwLinkState.Active) continue;
            const a = _app(t);
            if (out.indexOf(a) < 0) out.push(a);
        }
        return out;
    }
    readonly property var cameraApps: _videoUsers(true)
    readonly property var screenApps: _videoUsers(false)

    readonly property bool mic: micApps.length > 0
    readonly property bool camera: cameraApps.length > 0
    readonly property bool screen: screenApps.length > 0
    readonly property bool any: mic || camera || screen

    function describe() {
        const parts = [];
        if (mic) parts.push("mic: " + micApps.join(", "));
        if (camera) parts.push("camera: " + cameraApps.join(", "));
        if (screen) parts.push("screen: " + screenApps.join(", "));
        return parts.join("\n");
    }
}
