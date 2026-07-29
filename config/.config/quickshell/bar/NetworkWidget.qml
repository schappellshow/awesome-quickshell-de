import QtQuick
import Quickshell
import "../common"

// NET indicator: icon reflects connection — ethernet port when wired, wifi
// arcs when wireless (both blue), network-tree gray when disconnected.
// Left-click: network popup. Right-click: nm-connection-editor.
Item {
    id: root

    property bool panelOpen: false

    // Nerd Font glyphs: md-ethernet (U+F0200, supplementary → fromCodePoint),
    // fa-wifi (U+F1EB), fa-sitemap (U+F0E8, disconnected).
    readonly property string glyph: !Network.connected ? ""
        : Network.type === "wifi" ? ""
        : String.fromCodePoint(0xf0200)

    visible: Settings.showNetwork
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "NET"
            font.family: Theme.fontFamily
            font.bold: true
            font.pointSize: 7
            color: Theme.muted
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.glyph
            font.family: Theme.iconFont
            font.pointSize: 10
            color: Network.connected ? Theme.accentBright : Theme.subtext
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton) {
                Quickshell.execDetached(["nm-connection-editor"]);
            } else {
                if (!root.panelOpen)
                    Network.refreshConnections();
                root.panelOpen = !root.panelOpen;
            }
        }
    }
}
