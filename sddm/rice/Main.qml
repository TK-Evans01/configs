import QtQuick
import QtQuick.Layouts

// Rice: retro gruvbox SDDM theme. Same look as the shell's lock screen
// (quickshell rice/modules/lock): bar-style top strip, big pixel clock, square
// card with the avatar, "> " prompt with a block cursor, status line.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: c.bg0

    // Colours from theme.conf.user, which the rice shell rewrites on a theme
    // switch (theme-apply.py); gruvbox-material when it isn't there.
    QtObject {
        id: c
        function pick(k, d) { const v = config.stringValue(k); return v ? v : d; }
        readonly property color bg0: pick("bg0", "#1d2021")
        readonly property color bg1: pick("bg1", "#282828")
        readonly property color bg2: pick("bg2", "#32302f")
        readonly property color bg3: pick("bg3", "#45403d")
        readonly property color fg0: pick("fg0", "#d4be98")
        readonly property color fg1: pick("fg1", "#ddc7a1")
        readonly property color grey: pick("grey", "#a89984")
        readonly property color greyDim: pick("greyDim", "#7c6f64")
        readonly property color red: pick("red", "#ea6962")
        readonly property color orange: pick("orange", "#e78a4e")
        readonly property color yellow: pick("yellow", "#d8a657")
        readonly property color purple: pick("purple", "#d3869b")
        readonly property color blue: pick("blue", "#7daea3")
        readonly property color outline: pick("outline", "#d4be98")
    }
    // DepartureMono ships with the theme: the greeter can't see ~/.local fonts.
    FontLoader { id: pixel; source: "fonts/DepartureMonoNerdFontMono-Regular.otf" }
    readonly property string font: pixel.status === FontLoader.Ready ? pixel.name : "monospace"
    readonly property int barH: 44

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // --- users / sessions ---
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    function userData(role) { return userModel.data(userModel.index(userIndex, 0), Qt.UserRole + role); }
    readonly property string userName: userData(1) || ""
    readonly property string userIcon: userData(4) || ""
    readonly property string sessionName: sessionModel.data(sessionModel.index(sessionIndex, 0), Qt.UserRole + 4) || ""
    function cycleUser(step) { userIndex = (userIndex + step + userModel.count) % userModel.count; }
    function cycleSession(step) { sessionIndex = (sessionIndex + step + sessionModel.rowCount()) % sessionModel.rowCount(); }

    property bool failed: false
    property bool busy: false
    function login() {
        if (pass.text === "" || busy) return;
        busy = true;
        failed = false;
        sddm.login(userName, pass.text, sessionIndex);
    }
    Connections {
        target: sddm
        function onLoginFailed() { root.busy = false; root.failed = true; pass.text = ""; shakeAnim.restart(); }
        function onLoginSucceeded() { root.busy = false; }
    }

    component Txt: Text {
        property int size: 18
        font.family: root.font
        font.pixelSize: size
        color: c.fg0
        verticalAlignment: Text.AlignVCenter
    }
    component Btn: Rectangle {
        id: btn
        property string glyph: ""
        property string label: ""
        property color fg: c.fg0
        property bool armed: false
        signal clicked()
        implicitHeight: 34
        implicitWidth: label === "" ? 34 : row.implicitWidth + 22
        color: armed ? c.red : (ma.containsMouse ? c.bg3 : c.bg2)
        border.width: 1
        border.color: armed ? c.red : c.bg3
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Txt { text: btn.glyph; color: btn.armed ? c.bg0 : btn.fg }
            Txt { visible: btn.label !== ""; text: btn.label; size: 14; color: btn.armed ? c.bg0 : btn.fg }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }

    // --- background ---
    // Blur + darkening are baked into the image (sddm/make-background.sh), so
    // it looks the same under X11, weston or software rendering.
    Image {
        anchors.fill: parent
        source: config.stringValue("background")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle { anchors.fill: parent; color: c.bg0; opacity: config.realValue("dim") }

    // --- top strip (looks like the bar) ---
    Rectangle {
        width: parent.width
        height: root.barH
        color: c.bg1
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: c.bg3 }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Txt { text: "󰣇"; size: 22; color: c.blue }
            Txt { text: sddm.hostName; size: 14; color: c.grey; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            anchors.centerIn: parent
            spacing: 8
            Txt { text: Qt.formatTime(root.now, "HH:mm"); font.bold: true; color: c.fg1 }
            Txt { text: Qt.formatDate(root.now, "ddd dd MMM").toLowerCase(); size: 14; color: c.grey; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            id: power
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            property string armed: ""
            Timer { id: disarm; interval: 3000; onTriggered: power.armed = "" }
            function act(id, run) {
                if (armed === id) { armed = ""; run(); } else { armed = id; disarm.restart(); }
            }
            Btn {
                visible: config.boolValue("showSessionPicker")
                glyph: "󰍹"
                label: root.sessionName.toLowerCase() + "  ›"
                onClicked: root.cycleSession(1)
            }
            Item { width: 8; height: 1 }
            Btn { visible: sddm.canSuspend; glyph: "󰤄"; armed: power.armed === "suspend"; onClicked: power.act("suspend", () => sddm.suspend()) }
            Btn { visible: sddm.canReboot; glyph: "󰜉"; armed: power.armed === "reboot"; onClicked: power.act("reboot", () => sddm.reboot()) }
            Btn { visible: sddm.canPowerOff; glyph: "󰐥"; fg: c.red; armed: power.armed === "poweroff"; onClicked: power.act("poweroff", () => sddm.powerOff()) }
        }
    }

    // --- clock + card ---
    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.barH / 2
        spacing: 22

        Txt { Layout.alignment: Qt.AlignHCenter; text: Qt.formatTime(root.now, "HH:mm"); size: 132; color: c.fg1 }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -22
            text: Qt.formatDate(root.now, "dddd, dd MMMM").toLowerCase()
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 22
            implicitWidth: 460
            implicitHeight: card.implicitHeight + 44
            color: Qt.rgba(0.157, 0.157, 0.157, 0.94)
            border.width: 1
            border.color: root.failed ? c.red : c.bg3
            transform: Translate { id: shake }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shake; property: "x"; to: -10; duration: 40 }
                NumberAnimation { target: shake; property: "x"; to: 10; duration: 60 }
                NumberAnimation { target: shake; property: "x"; to: -6; duration: 60 }
                NumberAnimation { target: shake; property: "x"; to: 0; duration: 40 }
            }

            ColumnLayout {
                id: card
                anchors.centerIn: parent
                width: parent.width - 44
                spacing: 11

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 96
                    implicitHeight: 96
                    Image {
                        id: face
                        anchors.fill: parent
                        source: root.userIcon
                        sourceSize.width: 192
                        sourceSize.height: 192
                        smooth: true
                        mipmap: true
                        visible: status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: face.visible ? "transparent" : c.yellow
                        border.width: 2
                        border.color: root.failed ? c.red : c.fg0
                        Txt {
                            anchors.centerIn: parent
                            visible: !face.visible
                            text: root.userName.charAt(0).toUpperCase()
                            size: 40
                            color: c.bg0
                        }
                    }
                }

                // user (‹ › when there's more than one)
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14
                    Txt {
                        visible: userModel.count > 1
                        text: "‹"; size: 22; color: c.grey
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cycleUser(-1) }
                    }
                    Txt { text: root.userName; size: 22; color: c.fg1 }
                    Txt {
                        visible: userModel.count > 1
                        text: "›"; size: 22; color: c.grey
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cycleUser(1) }
                    }
                }

                // password prompt
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    color: c.bg0
                    border.width: 1
                    border.color: root.failed ? c.red : c.yellow
                    Txt {
                        id: prompt
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        text: ">"
                        font.bold: true
                        color: c.yellow
                    }
                    TextInput {
                        id: pass
                        anchors.left: prompt.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        font.family: root.font
                        font.pixelSize: 14
                        color: c.fg1
                        selectionColor: c.yellow
                        selectedTextColor: c.bg0
                        focus: true
                        enabled: !root.busy
                        onTextEdited: root.failed = false
                        onAccepted: root.login()
                        Keys.onEscapePressed: text = ""
                        cursorDelegate: Rectangle {
                            width: 11
                            color: c.yellow
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: true
                                NumberAnimation { to: 1; duration: 0 }
                                PauseAnimation { duration: 530 }
                                NumberAnimation { to: 0; duration: 0 }
                                PauseAnimation { duration: 530 }
                            }
                        }
                    }
                    Txt {
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pass.text === ""
                        text: "password"
                        size: 14
                        color: c.greyDim
                    }
                }

                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.busy ? "logging in…"
                        : root.failed ? "wrong password"
                        : keyboard.capsLock ? "󰌎  caps lock is on"
                        : "enter to log in  ·  esc to clear"
                    size: 13
                    color: root.failed ? c.red : keyboard.capsLock ? c.orange : c.grey
                }
            }
        }
    }

    Component.onCompleted: pass.forceActiveFocus()
}
