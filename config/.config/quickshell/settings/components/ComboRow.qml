import QtQuick
import "../../common"

// Label + expandable option list (inline dropdown, no QtQuick.Controls).
// options: array of { label, value } or plain strings.
Column {
    id: root

    property string label
    property var options: []
    property var current
    property bool expanded: false
    signal selected(var value)

    width: parent.width
    spacing: 4

    function optLabel(o) {
        return typeof o === "object" ? o.label : String(o);
    }

    function optValue(o) {
        return typeof o === "object" ? o.value : o;
    }

    readonly property string currentLabel: {
        for (const o of options)
            if (optValue(o) === current)
                return optLabel(o);
        return current !== undefined && current !== "" ? String(current) : "—";
    }

    Item {
        width: parent.width
        height: 28

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pointSize: 10
            color: Theme.text
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: chip.implicitWidth + 20
            height: 24
            radius: 12
            color: headHover.hovered || root.expanded ? Theme.surfaceAlt : Theme.surface

            Text {
                id: chip
                anchors.centerIn: parent
                text: root.currentLabel + (root.expanded ? "  ▴" : "  ▾")
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: Theme.accentBright
            }

            HoverHandler { id: headHover }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    Rectangle {
        visible: root.expanded
        width: parent.width
        implicitHeight: optCol.implicitHeight + 8
        radius: 8
        color: Theme.surfaceAlt

        Column {
            id: optCol
            x: 4
            y: 4
            width: parent.width - 8

            Repeater {
                model: root.options

                Rectangle {
                    id: optRow

                    required property var modelData

                    width: optCol.width
                    height: 24
                    radius: 6
                    color: optHover.hovered ? Theme.surface : "transparent"

                    Text {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 16
                        text: root.optLabel(optRow.modelData)
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: 9
                        color: root.optValue(optRow.modelData) === root.current
                            ? Theme.accentBright : Theme.text
                    }

                    HoverHandler { id: optHover }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.expanded = false;
                            root.selected(root.optValue(optRow.modelData));
                        }
                    }
                }
            }
        }
    }
}
