import QtQuick
import Quickshell
import "../common"

// Slide-out notification history panel (right edge), shown on the bar's
// screen(s). Toggled by the bar's NTF bell, Super+Shift+B, or
// `qs ipc call notifs toggle`.
Scope {
    id: root

    // Pin to the bar's screen with a single window bound to a stable
    // target — the same pattern as NotificationPopups. The old
    // `Variants { screen: modelData }` approach landed the panel on the
    // wrong monitor (a filtered-array binding whose element quickshell
    // resolved to the wrong output); a single fixed screen is reliable.
    property var targetScreen: null

    function updateTargetScreen() {
        const match = Quickshell.screens.filter(
            s => s.name === Settings.barScreen);
        root.targetScreen = match.length > 0 ? match[0] : Quickshell.screens[0];
    }

    Component.onCompleted: updateTargetScreen()

    Connections {
        target: Settings
        function onBarScreenChanged() { root.updateTargetScreen(); }
    }

    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: NotifHistory.centerOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true

            anchors {
                top: true
                right: true
                bottom: true
            }
            margins {
                top: 8
                right: 8
                bottom: 8
            }
            implicitWidth: 380

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.base
                border.color: Theme.surface
                border.width: 1

                Item {
                    id: header

                    x: 16
                    y: 12
                    width: parent.width - 32
                    height: 28

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications"
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pointSize: 12
                        color: Theme.text
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: dndLabel.implicitWidth + 16
                            height: 22
                            radius: 7
                            color: Settings.doNotDisturb ? Theme.gold
                                 : dndHover.hovered ? Theme.surfaceAlt : Theme.surface

                            Text {
                                id: dndLabel
                                anchors.centerIn: parent
                                text: "DND"
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pointSize: 8
                                color: Settings.doNotDisturb ? Theme.base : Theme.text
                            }

                            HoverHandler { id: dndHover }

                            MouseArea {
                                anchors.fill: parent
                                onClicked:
                                    Settings.doNotDisturb = !Settings.doNotDisturb
                            }
                        }

                        Rectangle {
                            width: clearLabel.implicitWidth + 16
                            height: 22
                            radius: 7
                            color: clearHover.hovered ? Theme.urgent : Theme.surface

                            Text {
                                id: clearLabel
                                anchors.centerIn: parent
                                text: "Clear"
                                font.family: Theme.fontFamily
                                font.pointSize: 8
                                color: Theme.text
                            }

                            HoverHandler { id: clearHover }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: NotifHistory.clear()
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: NotifHistory.entries.count === 0
                    text: "No notifications"
                    font.family: Theme.fontFamily
                    font.pointSize: 10
                    color: Theme.muted
                }

                ListView {
                    anchors.top: header.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.bottomMargin: 12
                    clip: true
                    spacing: 8
                    model: NotifHistory.entries

                    delegate: Rectangle {
                        id: entry

                        required property int index
                        required property string appName
                        required property string summary
                        required property string body
                        required property string image
                        required property string appIcon
                        required property string time

                        readonly property string iconSrc:
                            NotifHistory.iconSource(image, appIcon)
                        readonly property int textX: iconSrc !== "" ? 48 : 12

                        width: ListView.view.width
                        implicitHeight: Math.max(
                            bodyText.y + bodyText.implicitHeight + 10,
                            iconSrc !== "" ? 48 : 0)
                        radius: 8
                        color: Theme.surfaceAlt

                        Image {
                            x: 10
                            y: 10
                            width: 28
                            height: 28
                            // Hide cleanly rather than show a broken-image
                            // glyph for entries saved before NotifHistory
                            // stopped persisting ephemeral image handles
                            visible: entry.iconSrc !== "" && status !== Image.Error
                            source: entry.iconSrc
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 56
                        }

                        Text {
                            id: metaText
                            x: entry.textX
                            y: 7
                            width: parent.width - entry.textX - 30
                            text: (entry.appName || "notification") + "  ·  " + entry.time
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: 7
                            color: Theme.muted
                        }

                        Text {
                            id: summaryText
                            x: entry.textX
                            y: metaText.y + metaText.implicitHeight + 2
                            width: parent.width - entry.textX - 30
                            text: entry.summary
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pointSize: 9
                            color: Theme.text
                        }

                        Text {
                            id: bodyText
                            x: entry.textX
                            y: summaryText.y + summaryText.implicitHeight
                                + (text.length > 0 ? 3 : 0)
                            width: parent.width - entry.textX - 30
                            visible: text.length > 0
                            text: entry.body
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: 8
                            color: Theme.subtext
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            y: 7
                            text: "✕"
                            font.pointSize: 9
                            color: xHover.hovered ? Theme.urgent : Theme.muted

                            HoverHandler { id: xHover }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                onClicked: NotifHistory.removeAt(entry.index)
                            }
                        }
                    }
                }
            }
        }
    }
