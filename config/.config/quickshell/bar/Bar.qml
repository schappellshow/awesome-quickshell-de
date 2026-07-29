import QtQuick
import Quickshell
import "../common"

// Vertical left bar, one per screen. Transparent window; content sits in
// floating pills (taglist top, clock center, tray/battery/layout bottom).
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    // Awesome's view of this screen (tags, layout), matched by output name
    readonly property var awScreen: AwesomeState.forOutput(bar.screen.name)

    // Tags are per-screen in awesome; with one bar we show every screen's
    // taglist, ordered to match the physical left→right arrangement.
    // Clicks/scrolls in a section drive THAT screen (the bridge commands
    // take a screen index).
    readonly property var tagSections: {
        const sections = [];
        for (const aws of AwesomeState.screens) {
            let x = 999999;
            let label = "?";
            let isHere = false;
            for (const out of (aws.outputs || [])) {
                for (const qs of Quickshell.screens)
                    if (qs.name === out)
                        x = Math.min(x, qs.x);
                if (out === bar.screen.name)
                    isHere = true;
                label = out.replace("DisplayPort-", "DP")
                           .replace("HDMI-A-", "HD");
            }
            sections.push({ aw: aws, x: x, label: label, isHere: isHere });
        }
        // This screen's full list first, then the other monitors'
        // compact sections in physical left→right order
        sections.sort((a, b) => (b.isHere - a.isHere) || (a.x - b.x));
        return sections;
    }

    anchors {
        left: true
        top: true
        bottom: true
    }
    implicitWidth: Settings.barWidth
    color: "transparent"

    // No strut: X11 struts can't reserve the left edge of a middle monitor.
    // Awesome pads the screen instead (modules/quickshell.lua
    // apply_bar_padding, re-pushed by common/BarSpace.qml on changes).
    exclusionMode: ExclusionMode.Ignore

    Item {
        anchors.fill: parent

        Pill {
            id: tagPill
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            visible: bar.tagSections.length > 0

            Repeater {
                model: bar.tagSections

                Column {
                    id: section

                    required property var modelData

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3

                    Text {
                        // Label only the OTHER monitors' compact sections;
                        // the full list is implicitly this screen
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: bar.tagSections.length > 1
                            && !section.modelData.isHere
                        text: section.modelData.label
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pointSize: 6
                        color: Theme.muted
                    }

                    Workspaces {
                        anchors.horizontalCenter: parent.horizontalCenter
                        awScreen: section.modelData.aw
                        compact: !section.modelData.isHere
                    }
                }
            }
        }

        // Media section — only there when an MPRIS player exists; sits
        // just above the bottom status cluster.
        // Left-click: media panel; right-click: play/pause.
        Pill {
            id: mediaPill
            anchors.bottom: bottomPill.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Media.active !== null && Settings.showMediaPill
            padV: 5

            Item {
                width: 20
                height: 20

                // Drawn pause bars + non-emoji play glyph: ⏸/▶ fall back
                // to the color emoji font, which ignores `color` entirely
                // (that was the orange pause button)
                Row {
                    anchors.centerIn: parent
                    visible: Media.active !== null && Media.active.isPlaying
                    spacing: 3

                    Rectangle { width: 3; height: 11; radius: 1; color: Theme.muted }
                    Rectangle { width: 3; height: 11; radius: 1; color: Theme.muted }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Media.active === null || !Media.active.isPlaying
                    text: "►"
                    font.pointSize: 9
                    color: Theme.muted
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouseEvent => {
                        if (mouseEvent.button === Qt.RightButton) {
                            if (Media.active)
                                Media.active.togglePlaying();
                        } else {
                            Media.toggleOn(bar.screen.name);
                        }
                    }
                }
            }
        }

        Pill {
            id: clockPill
            anchors.centerIn: parent
            padH: 6

            ClockStack {}
        }

        // Click the clock for the calendar (Pill routes children into its
        // column, so the MouseArea overlays it from outside)
        MouseArea {
            anchors.fill: clockPill
            onClicked: BarState.toggleCalendar()
        }

        Pill {
            id: bottomPill
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            padV: 6

            // Pill stacks children top-aligned at x=0; center each one
            TrayColumn {
                anchors.horizontalCenter: parent.horizontalCenter
                barWindow: bar
                visible: Settings.showTray
            }

            NotifBell {
                anchors.horizontalCenter: parent.horizontalCenter
            }

            VolumeWidget {
                id: volumeWidget
                anchors.horizontalCenter: parent.horizontalCenter
            }

            NetworkWidget {
                id: networkWidget
                anchors.horizontalCenter: parent.horizontalCenter
            }

            BluetoothWidget {
                id: bluetoothWidget
                anchors.horizontalCenter: parent.horizontalCenter
            }

            SysMonWidget {
                anchors.horizontalCenter: parent.horizontalCenter
            }

            ScreenLockWidget {
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Battery {
                anchors.horizontalCenter: parent.horizontalCenter
            }

            LayoutBox {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Settings.showLayoutBox
                screenIndex: bar.awScreen ? bar.awScreen.index : 1
                layoutName: bar.awScreen ? bar.awScreen.layout : ""
            }
        }
    }

    MediaPanel {
        barWindow: bar
        anchorItem: mediaPill
    }

    CalendarPopup {
        barWindow: bar
        anchorItem: clockPill
        shown: BarState.calendarOpen
    }

    NetworkPanel {
        barWindow: bar
        anchorItem: networkWidget
        shown: networkWidget.panelOpen
        onDismiss: networkWidget.panelOpen = false
    }

    BluetoothPanel {
        barWindow: bar
        anchorItem: bluetoothWidget
        shown: bluetoothWidget.panelOpen
        onDismiss: bluetoothWidget.panelOpen = false
    }
}
