import QtQuick
import "../../common"

// One bar section: its order within a slot, which slot it sits in, and
// whether it's shown at all.
//
// The list these appear in is the bar's own order, so an arrow moves the
// section exactly one place in the direction it will move on screen.
Item {
    id: root

    property string label
    property string slotName: "End"
    property bool shown: true
    property bool canUp: true
    property bool canDown: true

    signal toggled(bool value)
    signal moved(int delta)
    signal slotCycled()

    width: parent.width
    height: 30

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: controls.left
        anchors.rightMargin: 10
        text: root.label
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: 10
        // A hidden section is still listed and still orderable — dimming it
        // says "off" without making it disappear from the arrangement.
        color: root.shown ? Theme.text : Theme.muted
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Arrow {
            glyph: "▴"
            active: root.canUp
            onClicked: root.moved(-1)
        }

        Arrow {
            glyph: "▾"
            active: root.canDown
            onClicked: root.moved(1)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: slotText.implicitWidth + 18
            height: 22
            radius: 11
            color: slotHover.hovered ? Theme.surfaceAlt : Theme.surface

            Text {
                id: slotText
                anchors.centerIn: parent
                text: root.slotName
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: Theme.accentBright
            }

            HoverHandler { id: slotHover }

            MouseArea {
                anchors.fill: parent
                onClicked: root.slotCycled()
            }
        }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 20
            radius: 10
            color: root.shown ? Theme.accent : Theme.surface

            Rectangle {
                width: 14
                height: 14
                radius: 7
                y: 3
                x: root.shown ? track.width - width - 3 : 3
                color: Theme.text
                Behavior on x {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.toggled(!root.shown)
            }
        }
    }

    component Arrow: Rectangle {
        id: arrow

        // `active` rather than `enabled`: Item already has an `enabled`,
        // and redeclaring it is an error.
        property string glyph
        property bool active: true

        signal clicked()

        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        radius: 6
        color: arrow.active && arrowHover.hovered ? Theme.surfaceAlt : "transparent"

        Text {
            anchors.centerIn: parent
            text: arrow.glyph
            font.family: Theme.fontFamily
            font.pointSize: 9
            // At the end of its slot there is nowhere to go; the arrow stays
            // in place so the row doesn't reflow, but goes quiet.
            color: arrow.active ? Theme.subtext : Theme.surfaceAlt
        }

        HoverHandler { id: arrowHover; enabled: arrow.active }

        MouseArea {
            anchors.fill: parent
            enabled: arrow.active
            onClicked: arrow.clicked()
        }
    }
}
