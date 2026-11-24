import QtQuick
import "../common"

// Percent slider for the gear panel
Item {
    id: ms
    property real from: 40
    property real to: 100
    property real value: 100
    property alias pressed: msArea.pressed
    signal moved(real value)
    height: 20
    readonly property real ratio: (ms.value - ms.from) / (ms.to - ms.from)
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 4; radius: 2
        color: Theme.surfaceAlt
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: ms.ratio * parent.width; height: 4; radius: 2
        color: Theme.accent
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: ms.ratio * (parent.width - width)
        width: 14; height: 14; radius: 7
        color: Theme.accentBright
    }
    MouseArea {
        id: msArea
        anchors.fill: parent
        function update(mx) {
            const r = Math.max(0, Math.min(1, mx / width));
            ms.moved(Math.round(ms.from + r * (ms.to - ms.from)));
        }
        onPressed: m => update(m.x)
        onPositionChanged: m => { if (pressed) update(m.x); }
    }
}
