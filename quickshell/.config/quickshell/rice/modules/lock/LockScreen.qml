import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"
import "../../services" as Svc

// Session lock, one surface per output. Typing goes to Svc.Lock.buffer, so
// every screen shows the same prompt. Same look as the SDDM theme (sddm/rice).
WlSessionLock {
    id: lock

    locked: true
    property bool unlocking: false
    onSecureChanged: Svc.Lock.secure = secure

    WlSessionLockSurface {
        id: surface
        color: Theme.surface0

        property date now: new Date()
        property bool shown: false
        Component.onCompleted: Qt.callLater(() => shown = true)

        // Unlock sequence runs once, from whichever surface hears it first.
        Connections {
            target: Svc.Lock
            function onAuthSucceeded() {
                if (lock.unlocking) return;
                lock.unlocking = true;
                unlockDelay.start();
            }
        }
        Timer {
            id: unlockDelay
            interval: Theme.anim
            onTriggered: {
                lock.locked = false;
                Svc.Lock.finishUnlock();
            }
        }
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: surface.now = new Date()
        }

        // --- background: this output's wallpaper, blurred and dimmed ---
        Image {
            id: wall
            anchors.fill: parent
            source: {
                const p = Svc.Lock.wallpapers[surface.screen ? surface.screen.name : ""];
                return p ? "file://" + p : "";
            }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Half resolution is invisible under the blur, and keeps a
            // 30 MP original from decoding at full size (~119 MB) per screen.
            sourceSize: Qt.size(Math.ceil(surface.width / 2), Math.ceil(surface.height / 2))
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wall
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            visible: wall.status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.surface0
            opacity: 0.62
        }

        Item {
            id: content
            anchors.fill: parent
            opacity: surface.shown && !lock.unlocking ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animLong } }

            focus: true
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) Svc.Lock.submit();
                else if (e.key === Qt.Key_Backspace) {
                    if (e.modifiers & Qt.ControlModifier) Svc.Lock.clear(); else Svc.Lock.backspace();
                }
                else if (e.key === Qt.Key_Escape) Svc.Lock.clear();
                else if (e.key === Qt.Key_CapsLock) capsDelay.restart();
                else if (e.text && e.text.length === 1 && e.text.charCodeAt(0) >= 32) Svc.Lock.type(e.text);
                else return;
                e.accepted = true;
            }
            // Caps state settles after the key event.
            Timer { id: capsDelay; interval: 80; onTriggered: Svc.Lock.checkCaps() }
            MouseArea { anchors.fill: parent; onClicked: content.forceActiveFocus() }

            // --- top strip (looks like the bar) ---
            Rectangle {
                id: strip
                width: parent.width
                height: Settings.barHeight
                color: Theme.background
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.border; color: Theme.surface2 }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing
                    Label { text: "󰌾"; size: Theme.iconSize; color: Theme.accent }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "locked since " + Qt.formatTime(Svc.Lock.lockedAt, "HH:mm")
                        size: Theme.fontBase
                        color: Theme.subtext
                    }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacing
                    Label { text: Qt.formatTime(surface.now, "HH:mm"); font.bold: true; color: Theme.textBright }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(surface.now, "ddd dd MMM").toLowerCase()
                        size: Theme.fontBase
                        color: Theme.subtext
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.pad

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Svc.Mpris.running
                        spacing: Theme.spacing
                        MouseArea {
                            width: playGlyph.implicitWidth
                            height: playGlyph.implicitHeight
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Svc.Mpris.togglePlay()
                            Label {
                                id: playGlyph
                                text: Svc.Mpris.playing ? "󰏤" : "󰐊"
                                size: Theme.iconSize
                                color: Theme.catMedia
                            }
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Svc.Mpris.title + (Svc.Mpris.artist ? " · " + Svc.Mpris.artist : "")
                            size: Theme.fontBase
                            color: Svc.Mpris.playing ? Theme.catMedia : Theme.subtext
                            width: Math.min(implicitWidth, 320)
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle { width: 1; height: Settings.barHeight / 2; color: Theme.surface2; anchors.verticalCenter: parent.verticalCenter }
                    PowerRow {
                        anchors.verticalCenter: parent.verticalCenter
                        actions: Svc.Desktop.actions.filter(a => a.id !== "logout" && a.id !== "lock")
                        onFire: id => Svc.Desktop.power(id)
                    }
                }
            }

            // --- clock + card ---
            ColumnLayout {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -Settings.barHeight / 2
                spacing: Theme.pad * 2

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatTime(surface.now, "HH:mm")
                    size: 132
                    color: Theme.textBright
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: -Theme.pad * 2
                    text: Qt.formatDate(surface.now, "dddd, dd MMMM").toLowerCase()
                    color: Theme.text
                }

                Rectangle {
                    radius: Theme.radius
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.pad * 2
                    implicitWidth: 460
                    implicitHeight: card.implicitHeight + Theme.pad * 4
                    color: Qt.alpha(Theme.background, 0.94)
                    border.width: Theme.border
                    border.color: Svc.Lock.failed ? Theme.error : Theme.surface2
                    Behavior on border.color { ColorAnimation { duration: Theme.anim } }

                    // Shake on a wrong password.
                    transform: Translate { id: shake }
                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: shake; property: "x"; to: -10; duration: 40 }
                        NumberAnimation { target: shake; property: "x"; to: 10; duration: 60 }
                        NumberAnimation { target: shake; property: "x"; to: -6; duration: 60 }
                        NumberAnimation { target: shake; property: "x"; to: 0; duration: 40 }
                    }
                    Connections {
                        target: Svc.Lock
                        function onFailedChanged() { if (Svc.Lock.failed) shakeAnim.restart(); }
                    }

                    ColumnLayout {
                        id: card
                        anchors.centerIn: parent
                        width: parent.width - Theme.pad * 4
                        spacing: Theme.pad

                        // avatar
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 96
                            implicitHeight: 96
                            Image {
                                id: face
                                anchors.fill: parent
                                source: "file://" + Settings.avatar
                                sourceSize.width: 192
                                sourceSize.height: 192
                                smooth: true
                                mipmap: true
                                visible: status === Image.Ready
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: face.visible ? "transparent" : Theme.accent
                                border.width: 2
                                border.color: Svc.Lock.failed ? Theme.error : Theme.text
                            }
                        }
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: Svc.Desktop.user
                            size: Theme.fontLg
                            color: Theme.textBright
                        }

                        // password prompt
                        Rectangle {
                            radius: Theme.radiusSmall
                            Layout.fillWidth: true
                            implicitHeight: Theme.fontMd + Theme.pad * 2
                            color: Theme.surface0
                            border.width: Theme.border
                            border.color: Svc.Lock.failed ? Theme.error : Theme.accent

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.pad
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacing
                                Label { text: ">"; font.bold: true; color: Theme.accent }
                                Label {
                                    text: "●".repeat(Math.min(Svc.Lock.buffer.length, 24))
                                    color: Theme.textBright
                                    size: Theme.fontBase
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    width: Math.round(Theme.fontMd * 0.6)
                                    height: Theme.fontMd
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Svc.Lock.authenticating ? Theme.subtext : Theme.accent
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: !Svc.Lock.authenticating
                                        NumberAnimation { to: 1; duration: 0 }
                                        PauseAnimation { duration: 530 }
                                        NumberAnimation { to: 0; duration: 0 }
                                        PauseAnimation { duration: 530 }
                                    }
                                }
                            }
                            Label {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.pad
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Svc.Lock.buffer === "" && !Svc.Lock.authenticating
                                text: "password"
                                size: Theme.fontBase
                                color: Theme.muted
                            }
                        }

                        // status line
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: Svc.Lock.authenticating ? "checking…"
                                : Svc.Lock.failed ? Svc.Lock.failMessage + (Svc.Lock.attempts > 1 ? "  (" + Svc.Lock.attempts + ")" : "")
                                : Svc.Lock.capsLock ? "󰌎  caps lock is on"
                                : "enter to unlock  ·  esc to clear"
                            size: Theme.fontSm
                            color: Svc.Lock.failed ? Theme.error : Svc.Lock.capsLock ? Theme.warning : Theme.subtext
                        }
                    }
                }
            }
        }
    }
}
