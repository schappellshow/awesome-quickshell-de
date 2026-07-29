import QtQuick
import "../common"

// NTF bell: unread count (– when none, zZ in do-not-disturb).
// Left-click: notification center. Right-click: toggle do-not-disturb.
Item {
    id: root

    visible: Settings.showNotifBell
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "NTF"
            font.family: Theme.fontFamily
            font.bold: true
            font.pointSize: 7
            color: Theme.muted
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Settings.doNotDisturb ? "zZ"
                : NotifHistory.unread > 0 ? String(NotifHistory.unread) : "–"
            font.family: Theme.fontFamily
            font.pointSize: 9
            // OM magenta for DND (Theme.urgent/red is #cc2263, the brand
            // pink) — gold is reserved for "warning" levels like 70%+ load
            color: Settings.doNotDisturb ? Theme.urgent
                 : NotifHistory.unread > 0 ? Theme.accentBright
                 : Theme.subtext
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton)
                Settings.doNotDisturb = !Settings.doNotDisturb;
            else
                NotifHistory.toggleCenter();
        }
    }
}
