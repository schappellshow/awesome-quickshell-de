import QtQuick
import "../../common"

// Font picker. Same shape as ComboRow, but every family is drawn IN ITSELF —
// a list of names set in one typeface tells you nothing about how the bar
// will actually look, which is the whole reason for choosing a font.
//
// Above the list sits a fixed sample rendered at bar sizes in the currently
// selected family, so you can judge the pick in context before committing.
Column {
    id: root

    property string label
    // Current family, or "" for "follow the theme default".
    property string current: ""
    // Shown in the sample line; pages pass something representative of
    // where the font will actually be used.
    property string sample: "NGT  07:48 AM"
    signal selected(string family)

    property bool expanded: false
    property bool showAll: false

    readonly property var families: showAll ? Fonts.all : Fonts.preferred()
    readonly property string effective: current !== "" ? current : Theme.fontFamily

    width: parent.width
    spacing: 6

    // ── Header: label + current family, set in that family ──────────────
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
                text: (root.current !== "" ? root.current : "Theme default")
                    + (root.expanded ? "  ▴" : "  ▾")
                // The chip is itself a preview.
                font.family: root.effective
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

    // ── Live sample at bar sizes ────────────────────────────────────────
    Rectangle {
        width: parent.width
        implicitHeight: sampleCol.implicitHeight + 16
        radius: 8
        color: Theme.base

        Column {
            id: sampleCol
            x: 12
            y: 8
            spacing: 2

            Text {
                text: root.sample
                font.family: root.effective
                font.bold: true
                font.pointSize: 13
                color: Theme.text
            }

            Text {
                text: root.effective
                font.family: Theme.fontFamily
                font.pointSize: 8
                color: Theme.muted
            }
        }
    }

    // ── Family list ─────────────────────────────────────────────────────
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

            // Monospace-only by default: 248 families are installed here
            // and only ~53 are mono, so the useful ones would otherwise be
            // buried among proportional faces no one wants in a 36px bar.
            Item {
                width: optCol.width
                height: 26

                Text {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.showAll
                        ? "Showing all " + Fonts.all.length + " families"
                        : "Showing " + Fonts.preferred().length + " monospace families"
                    font.family: Theme.fontFamily
                    font.pointSize: 8
                    color: Theme.muted
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: toggleText.implicitWidth + 16
                    height: 20
                    radius: 10
                    color: toggleHover.hovered ? Theme.surface : "transparent"
                    border.width: 1
                    border.color: Theme.muted

                    Text {
                        id: toggleText
                        anchors.centerIn: parent
                        text: root.showAll ? "Monospace only" : "Show all"
                        font.family: Theme.fontFamily
                        font.pointSize: 8
                        color: Theme.accentBright
                    }

                    HoverHandler { id: toggleHover }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.showAll = !root.showAll
                    }
                }
            }

            // "Theme default" is a real choice, not the absence of one —
            // it keeps following Theme.fontFamily if that ever changes.
            Rectangle {
                width: optCol.width
                height: 26
                radius: 6
                color: defHover.hovered ? Theme.surface : "transparent"

                Text {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Theme default (" + Theme.fontFamily + ")"
                    font.family: Theme.fontFamily
                    font.pointSize: 9
                    color: root.current === "" ? Theme.accentBright : Theme.text
                }

                HoverHandler { id: defHover }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.expanded = false;
                        root.selected("");
                    }
                }
            }

            Repeater {
                model: root.families

                Rectangle {
                    id: optRow

                    required property var modelData

                    width: optCol.width
                    height: 26
                    radius: 6
                    color: optHover.hovered ? Theme.surface : "transparent"

                    // Each name drawn in its own family — this is the
                    // preview.
                    Text {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - nameFallback.width - 24
                        text: optRow.modelData
                        elide: Text.ElideRight
                        font.family: optRow.modelData
                        font.pointSize: 10
                        color: optRow.modelData === root.current
                            ? Theme.accentBright : Theme.text
                    }

                    // ...which is unreadable for symbol families, whose name
                    // renders as glyphs (this is what "Cursor" looks like).
                    // Repeat it in the theme font so every row can still be
                    // identified. Redundant for text fonts, and quiet enough
                    // not to matter there.
                    Text {
                        id: nameFallback
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: optRow.modelData
                        font.family: Theme.fontFamily
                        font.pointSize: 8
                        color: Theme.muted
                    }

                    HoverHandler { id: optHover }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.expanded = false;
                            root.selected(optRow.modelData);
                        }
                    }
                }
            }
        }
    }
}
