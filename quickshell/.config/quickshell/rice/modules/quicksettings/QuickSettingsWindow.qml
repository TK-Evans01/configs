import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// Under the right island. Sub-pages slide sideways (forward when going in,
// back out on ‹ or Escape) and the panel follows the page height.
BarPopup {
    id: root

    required property string screenName
    readonly property string page: Svc.Ui.page

    wanted: Svc.Ui.isOpen("quicksettings", screenName)
    popupWidth: Settings.quickSettingsWidth
    contentHeight: current ? current.implicitHeight : 0
    keyTargets: [keys]
    onDismissed: Svc.Ui.dismiss()

    readonly property Item current: ({
        "": main, network: network, bluetooth: bt, sound: sound,
        nightlight: nightlight, screenshot: screenshot, focus: focus
    })[page] || main

    Item {
        id: keys
        Keys.onEscapePressed: e => {
            if (root.page === "") { e.accepted = false; return; }
            Svc.Ui.back();
        }
    }

    // Slide: the incoming page starts offset and fades in.
    onPageChanged: {
        slideIn.stop();
        slideIn.target = current;
        slideIn.from = page === "" ? -40 : 40;
        slideIn.start();
        fadeIn.target = current;
        fadeIn.restart();
    }
    NumberAnimation { id: slideIn; property: "x"; to: 0; duration: Theme.anim; easing.type: Theme.easing }
    NumberAnimation { id: fadeIn; property: "opacity"; from: 0; to: 1; duration: Theme.anim }

    MainPage { id: main; width: parent.width; visible: root.current === main }
    NetworkPage { id: network; width: parent.width; visible: root.current === network }
    BluetoothPage { id: bt; width: parent.width; visible: root.current === bt }
    SoundPage { id: sound; width: parent.width; visible: root.current === sound }
    NightLightPage { id: nightlight; width: parent.width; visible: root.current === nightlight }
    ScreenshotPage { id: screenshot; width: parent.width; visible: root.current === screenshot }
    FocusPage { id: focus; width: parent.width; visible: root.current === focus }
}
