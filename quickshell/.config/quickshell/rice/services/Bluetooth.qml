pragma Singleton
import QtQuick
import Quickshell.Io
import "../config"
import Quickshell.Bluetooth as QsBt

// BlueZ via Quickshell's native bindings — reactive over DBus, no polling.
// New devices go pair -> trust -> connect; trust lets controllers and earbuds
// reconnect on their own when powered on.
QtObject {
    id: root

    readonly property var adapter: QsBt.Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool enabled: present && adapter.enabled
    readonly property bool discovering: enabled && adapter.discovering

    // Known devices first, then scan hits. Some earbuds (Raycon) advertise a
    // device class but no name until paired, so a known icon counts too; only
    // bare MACs with neither (BLE beacons etc.) are skipped.
    readonly property var devices: {
        if (!present) return [];
        const all = adapter.devices.values.filter(d => d.paired || d.connected || d.deviceName !== "" || d.icon !== "");
        const rank = d => d.connected ? 0 : (d.paired ? 1 : 2);
        return all.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
    }

    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property bool anyConnected: connectedDevices.length > 0
    readonly property bool busy: {
        for (const d of devices)
            if (d.pairing || d.state === QsBt.BluetoothDeviceState.Connecting) return true;
        return false;
    }

    // Quickshell registers no pairing agent, and without one BlueZ rejects
    // Pair(). Keep bluetoothctl alive as the default agent; NoInputNoOutput
    // means "just works" pairing, which is what headsets and pads use.
    readonly property var _agent: Process {
        running: true
        command: Settings.tether.concat(["bluetoothctl", "--agent", "NoInputNoOutput"])
        stdinEnabled: true
        onStarted: write("default-agent\n")
        onRunningChanged: if (!running) root._agentRestart.restart()
    }

    readonly property var _agentRestart: Timer {
        interval: 5000
        onTriggered: root._agent.running = true
    }

    // One pairing at a time. Once it lands, trust + connect.
    property var _pairing: null

    readonly property var _pairWatch: Connections {
        target: root._pairing
        ignoreUnknownSignals: true
        function onPairedChanged() {
            const d = root._pairing;
            if (!d || !d.paired) return;
            d.trusted = true;
            d.connect();
            root._pairing = null;
            if (root.adapter) root.adapter.discovering = false;
        }
        function onPairingChanged() {
            const d = root._pairing;
            if (d && !d.pairing && !d.paired) root._pairing = null;   // failed / cancelled
        }
    }

    // Scanning is noisy on the radio; don't leave it on.
    readonly property var _scanTimeout: Timer {
        interval: 60000
        running: root.discovering
        onTriggered: if (root.adapter) root.adapter.discovering = false
    }

    function togglePower() {
        if (present) adapter.enabled = !adapter.enabled;
    }

    function toggleScan() {
        if (!present) return;
        if (!adapter.enabled) adapter.enabled = true;
        adapter.discovering = !adapter.discovering;
    }

    function activate(d) {
        if (d.pairing) { d.cancelPair(); return; }
        if (d.connected) { d.disconnect(); return; }
        if (d.paired) {
            d.trusted = true;
            d.connect();
            return;
        }
        root._pairing = d;
        d.trusted = true;
        d.pair();
    }

    function forget(d) { d.forget(); }
}
