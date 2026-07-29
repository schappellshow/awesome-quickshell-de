import QtQuick
import Quickshell
import Quickshell.Widgets
import "../common"

// Media player panel: album art, track info, seekable progress, controls.
// Pops out to the right of the bar, level with the media button. Opened by
// clicking the bar's media section or Super+a (qs ipc call media toggle).
PopupWindow {
    id: panel

    property var barWindow
    property Item anchorItem

    readonly property var player: Media.active

    visible: player !== null && barWindow && Media.openOn === barWindow.screen.name
    color: "transparent"
    implicitWidth: 250
    implicitHeight: card.implicitHeight

    anchor.window: barWindow
    anchor.rect.x: barWindow ? barWindow.implicitWidth + 6 : 42
    anchor.rect.y: {
        if (!anchorItem)
            return 100;
        const p = anchorItem.mapToItem(null, 0, anchorItem.height / 2);
        return Math.max(8, p.y - panel.implicitHeight / 2);
    }

    function fmtTime(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // MPRIS position doesn't update reactively; poll while visible + playing
    Timer {
        interval: 1000
        repeat: true
        running: panel.visible && panel.player !== null
              && panel.player.isPlaying && panel.player.positionSupported
        onTriggered: panel.player.positionChanged()
    }

    Rectangle {
        id: card

        width: parent.width
        implicitHeight: col.implicitHeight + 28
        radius: Theme.radius
        color: Theme.base
        border.color: Theme.accentBright
        border.width: 2

        Column {
            id: col

            x: 14
            y: 14
            width: parent.width - 28
            spacing: 8

            Text {
                width: parent.width
                text: panel.player ? panel.player.identity : ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: 7
                color: Theme.muted
            }

            ClippingRectangle {
                width: parent.width
                height: width
                radius: 8
                color: Theme.surfaceAlt

                Image {
                    anchors.fill: parent
                    source: panel.player ? panel.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !panel.player || panel.player.trackArtUrl === ""
                    text: "♪"
                    font.pointSize: 42
                    color: Theme.muted
                }
            }

            Text {
                width: parent.width
                text: panel.player ? (panel.player.trackTitle || "Unknown title") : ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.bold: true
                font.pointSize: 10
                color: Theme.text
            }

            Text {
                width: parent.width
                text: panel.player ? panel.player.trackArtist : ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: Theme.subtext
            }

            Item {
                width: parent.width
                height: 14
                visible: panel.player !== null && panel.player.lengthSupported

                readonly property real ratio: panel.player && panel.player.length > 0
                    ? Math.min(1, panel.player.position / panel.player.length) : 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.surface
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.ratio * parent.width
                    height: 4
                    radius: 2
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouseEvent => {
                        if (panel.player && panel.player.canSeek && panel.player.length > 0)
                            panel.player.position = (mouseEvent.x / width) * panel.player.length;
                    }
                }
            }

            Item {
                width: parent.width
                height: posText.implicitHeight
                visible: panel.player !== null && panel.player.lengthSupported

                Text {
                    id: posText
                    text: panel.player ? panel.fmtTime(panel.player.position) : ""
                    font.family: Theme.fontFamily
                    font.pointSize: 7
                    color: Theme.muted
                }

                Text {
                    anchors.right: parent.right
                    text: panel.player ? panel.fmtTime(panel.player.length) : ""
                    font.family: Theme.fontFamily
                    font.pointSize: 7
                    color: Theme.muted
                }
            }

            Item {
                width: parent.width
                height: 40

                // Drawn/non-emoji controls: ⏮⏸⏭ fall back to the color
                // emoji font, which ignores QML colors — same fix as the
                // bar's media pill.
                Row {
                    anchors.centerIn: parent
                    spacing: 22

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "◄◄"
                        font.pointSize: 10
                        font.letterSpacing: -2
                        color: Theme.subtext
                        opacity: panel.player && panel.player.canGoPrevious ? 1 : 0.35

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (panel.player) panel.player.previous()
                        }
                    }

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: Theme.surface

                        Row {
                            anchors.centerIn: parent
                            visible: panel.player !== null && panel.player.isPlaying
                            spacing: 4

                            Rectangle { width: 4; height: 13; radius: 1; color: Theme.text }
                            Rectangle { width: 4; height: 13; radius: 1; color: Theme.text }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: panel.player === null || !panel.player.isPlaying
                            text: "►"
                            font.pointSize: 11
                            color: Theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (panel.player) panel.player.togglePlaying()
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "►►"
                        font.pointSize: 10
                        font.letterSpacing: -2
                        color: Theme.subtext
                        opacity: panel.player && panel.player.canGoNext ? 1 : 0.35

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (panel.player) panel.player.next()
                        }
                    }
                }
            }
        }
    }
}
