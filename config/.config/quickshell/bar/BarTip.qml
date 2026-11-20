import QtQuick
import Quickshell
import "../common"

// Hover tooltip for a bar item: a small card beside the bar, placed with the
// same maths as the bar's popups so it follows the bar to any edge. The bar
// had no tooltips before; this is the one every indicator can share.
//
// `shown` is the owner's hover state; the card appears after a short dwell so
// sweeping the pointer across the bar doesn't flash one at every item.
PopupWindow {
    id: tip

    property var barWindow
    property Item anchorItem
    property string text: ""
    property bool hovered: false

    // Debounced `hovered`
    property bool shown: false
    onHoveredChanged: {
        if (hovered)
            dwell.restart();
        else {
            dwell.stop();
            shown = false;
        }
    }
    Timer {
        id: dwell
        interval: 450
        onTriggered: tip.shown = tip.hovered
    }

    visible: shown && text !== "" && barWindow !== undefined
    color: "transparent"
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    anchor.window: barWindow
    anchor.rect.x: BarEdge.popupX(tip.barWindow, tip.anchorItem, tip.implicitWidth)
    anchor.rect.y: BarEdge.popupY(tip.barWindow, tip.anchorItem, tip.implicitHeight)

    Rectangle {
        id: card
        implicitWidth: label.implicitWidth + 20
        implicitHeight: label.implicitHeight + 14
        radius: Theme.radius
        color: Theme.base
        border.color: Theme.muted
        border.width: 1

        Text {
            id: label
            anchors.centerIn: parent
            text: tip.text
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: Theme.text
        }
    }
}
