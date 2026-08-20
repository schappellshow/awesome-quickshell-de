import QtQuick
import Quickshell
import "../../common"

// Browse installed applications and pick one.
//
// Not a ComboRow: that draws its options as an unclipped Column, and there
// are ~90 visible desktop entries on a normal system — a 2000px list inside a
// 560px window. This caps its height, scrolls, and filters as you type, which
// is what makes "scroll through and try some" actually work.
Column {
    id: root

    property string label: "Add an application"
    // Ids already chosen, greyed out so you can see what is spoken for.
    property var excluded: []

    signal picked(string id)

    width: parent.width
    spacing: 6

    // DesktopEntries.applications is an UntypedObjectModel; .values is the
    // plain list. noDisplay entries are the ones a menu is meant to hide
    // (settings panels, mime handlers), so they are dropped here too.
    readonly property var allApps: AppLookup.applications

    readonly property var matches: AppLookup.search(filterInput.text)

    Text {
        text: root.label
        font.family: Theme.fontFamily
        font.pointSize: 10
        color: Theme.text
    }

    Rectangle {
        width: parent.width
        height: 28
        radius: 8
        color: Theme.surfaceAlt
        border.width: filterInput.activeFocus ? 1 : 0
        border.color: Theme.accent

        TextInput {
            id: filterInput
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: Theme.text
            clip: true
            selectByMouse: true
        }

        Text {
            anchors.fill: filterInput
            verticalAlignment: Text.AlignVCenter
            visible: filterInput.text.length === 0 && !filterInput.activeFocus
            text: "Type to filter…"
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: Theme.muted
        }
    }

    Rectangle {
        width: parent.width
        height: 200
        radius: 8
        color: Theme.surfaceAlt
        clip: true

        Flickable {
            id: list
            anchors.fill: parent
            anchors.margins: 4
            contentHeight: listCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: listCol
                width: list.width

                Repeater {
                    model: root.matches

                    Rectangle {
                        id: appRow

                        required property var modelData

                        readonly property bool already: root.excluded.includes(appRow.modelData.id)

                        width: listCol.width
                        height: 28
                        radius: 6
                        color: rowHover.hovered && !appRow.already
                            ? Theme.surface : "transparent"
                        opacity: appRow.already ? 0.4 : 1

                        Image {
                            id: rowIcon
                            anchors.verticalCenter: parent.verticalCenter
                            x: 6
                            width: 18
                            height: 18
                            source: appRow.modelData.icon
                            sourceSize.width: 36
                            sourceSize.height: 36
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        // Not every icon renders: a theme can ship a
                        // malformed SVG (Vivid-Glassy-Dark's
                        // libreoffice-base.svg references gradients it never
                        // defines), and some entries declare no icon at all.
                        // Fall back to the initial so the row is never blank.
                        Text {
                            anchors.centerIn: rowIcon
                            visible: rowIcon.status !== Image.Ready
                            text: appRow.modelData.name.charAt(0).toUpperCase()
                            font.family: Theme.labelFont
                            font.bold: true
                            font.pointSize: 9
                            color: Theme.subtext
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 30
                            width: parent.width - 40
                            elide: Text.ElideRight
                            text: appRow.already
                                ? appRow.modelData.name + "  (pinned)"
                                : appRow.modelData.name
                            font.family: Theme.fontFamily
                            font.pointSize: 9
                            color: Theme.text
                        }

                        HoverHandler { id: rowHover }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !appRow.already
                            onClicked: root.picked(appRow.modelData.id)
                        }
                    }
                }
            }
        }

        // Same hand-rolled indicator as the settings sidebar — this codebase
        // does not pull in QtQuick.Controls (see ComboRow.qml).
        Rectangle {
            readonly property bool needed: list.contentHeight > list.height

            visible: needed
            width: 3
            radius: 1.5
            color: Theme.muted
            opacity: list.moving ? 0.9 : 0.35
            x: parent.width - 6
            y: 4 + (list.contentY / Math.max(1, list.contentHeight)) * list.height
            height: needed
                ? Math.max(24, (list.height / list.contentHeight) * list.height)
                : 0

            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    Text {
        width: parent.width
        text: root.matches.length + " of " + root.allApps.length + " applications"
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
