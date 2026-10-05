pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../config"

// Audio through Quickshell's PipeWire service: event-driven, no processes.
// Default output / input (volume %, mute), device lists, per-app streams.
// Volumes are percent (0–150) like pactl.
QtObject {
    id: root

    readonly property var _sink: Pipewire.defaultAudioSink
    readonly property var _source: Pipewire.defaultAudioSource
    readonly property var _nodes: Pipewire.nodes.values

    // Volume / mute / names update only for tracked nodes.
    readonly property var _track: PwObjectTracker {
        objects: [root._sink, root._source].filter(n => n).concat(root.streamsWanted ? root._streamNodes : [])
    }

    function _pct(n) { return n && n.audio ? Math.round(n.audio.volume * 100) : 0; }

    readonly property int outPercent: _pct(_sink)
    readonly property bool outMuted: _sink && _sink.audio ? _sink.audio.muted : false
    readonly property string outDefault: _sink ? _sink.name : ""
    readonly property int inPercent: _pct(_source)
    readonly property bool inMuted: _source && _source.audio ? _source.audio.muted : false
    readonly property string inDefault: _source ? _source.name : ""

    function _isDevice(n, sink) {
        return n.audio && !n.isStream && n.isSink === sink
            && (n.properties["media.class"] || "").indexOf(sink ? "Audio/Sink" : "Audio/Source") === 0;
    }
    readonly property var outputs: _nodes.filter(n => _isDevice(n, true)).map(n => ({ name: n.name, description: n.description || n.nickname || n.name }))
    readonly property var inputs: _nodes.filter(n => _isDevice(n, false)).map(n => ({ name: n.name, description: n.description || n.nickname || n.name }))

    // --- per-app playback streams (only tracked while something shows them) ---
    property bool streamsWanted: false
    readonly property var _streamNodes: _nodes.filter(n => n.isStream && n.audio && (n.properties["media.class"] || "") === "Stream/Output/Audio")
    readonly property var streams: _streamNodes.map(n => ({
        id: n.id,
        app: n.properties["application.name"] || n.properties["application.process.binary"] || n.name || "app",
        bin: n.properties["application.process.binary"] || "",
        icon: n.properties["application.icon_name"] || "",
        title: n.properties["media.name"] || "",
        volume: _pct(n),
        muted: n.audio.muted
    }))
    function _node(id) { return _nodes.find(n => n.id === id) || null; }

    // --- setters ---
    function _setVol(n, p) { if (n && n.audio) n.audio.volume = Math.max(0, Math.min(150, Math.round(p))) / 100; }
    function setOutputVolume(p) { _setVol(_sink, p); }
    function setInputVolume(p)  { _setVol(_source, p); }
    function toggleMute()       { if (_sink && _sink.audio) _sink.audio.muted = !_sink.audio.muted; }
    function toggleInputMute()  { if (_source && _source.audio) _source.audio.muted = !_source.audio.muted; }
    function setDefaultSink(name)   { const n = _nodes.find(x => x.name === name); if (n) Pipewire.preferredDefaultAudioSink = n; }
    function setDefaultSource(name) { const n = _nodes.find(x => x.name === name); if (n) Pipewire.preferredDefaultAudioSource = n; }
    function setStreamVolume(id, p) { _setVol(_node(id), p); }
    function toggleStreamMute(id)   { const n = _node(id); if (n && n.audio) n.audio.muted = !n.audio.muted; }
}
