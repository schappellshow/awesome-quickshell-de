import QtQuick
import Quickshell
import QtQuick.Effects
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
        // This screen first (its label is the bold one), then the other
        // monitors in physical left→right order. All sections render
        // identically; only the label weight distinguishes them.
        sections.sort((a, b) => (b.isHere - a.isHere) || (a.x - b.x));
        return sections;
    }

    anchors {
        left: true
        top: true
        bottom: true
    }
    implicitWidth: Settings.barWidth

    // Background is built up in layers below (blur, then tint), so the
    // window itself contributes nothing.
    color: "transparent"

    // ── Blurred wallpaper ───────────────────────────────────────────────
    // The bar blurs its OWN copy of the wallpaper rather than whatever the
    // compositor has behind it — an X client can't read the screen beneath
    // itself. The copy is faithful here because awesome pads the screen by
    // the bar's width (modules/quickshell.lua apply_bar_padding), so no
    // tiled window is ever underneath: what's back there IS the wallpaper.
    // A floating window straying under the bar won't show through the blur,
    // which is the one visible cost of doing it this way.
    Item {
        anchors.fill: parent
        visible: Settings.barBlur > 0 && wallCopy.status === Image.Ready
        clip: true

        Image {
            id: wallCopy
            // The bar sits on the screen's edge, so its top-left coincides
            // with the screen's: draw the wallpaper at full screen size from
            // 0,0 and the slice showing through lines up with what feh
            // painted. PreserveAspectCrop matches feh --bg-fill.
            x: 0
            y: 0
            width: bar.screen.width
            height: bar.screen.height
            fillMode: Image.PreserveAspectCrop
            visible: false          // drawn only through the effect below
            asynchronous: true
            source: {
                const p = Settings.wallpaperPath;
                if (p === "")
                    return "";
                return "file://" + (p.startsWith("~/")
                    ? Quickshell.env("HOME") + p.slice(1) : p);
            }
        }

        MultiEffect {
            x: wallCopy.x
            y: wallCopy.y
            width: wallCopy.width
            height: wallCopy.height
            source: wallCopy
            blurEnabled: true
            blurMax: 48
            blur: Settings.barBlur / 100
        }
    }

    // ── Tint ────────────────────────────────────────────────────────────
    // Sits over the blur, so the two sliders compose: opacity alone is
    // tinted glass over the live desktop, blur alone is frosted glass, and
    // together they're tinted frosted glass. At 100% opacity the tint is
    // solid and the blur beneath it stops mattering.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b,
                       Settings.barOpacity / 100)
    }

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
                        // Every monitor is labelled now that the sections
                        // render identically; this screen's label is bold,
                        // which is the only thing marking it as the one the
                        // bar lives on.
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: bar.tagSections.length > 1
                        text: section.modelData.label
                        font.family: Theme.labelFont
                        font.bold: section.modelData.isHere
                        font.pointSize: 6
                        color: section.modelData.isHere ? Theme.subtext : Theme.muted
                    }

                    Workspaces {
                        anchors.horizontalCenter: parent.horizontalCenter
                        awScreen: section.modelData.aw
                    }

                    // Hidden windows sit directly beneath the tags they
                    // belong to, so nothing extra is needed to say which
                    // monitor they're on. Absent unless something is hidden.
                    HiddenWindows {
                        anchors.horizontalCenter: parent.horizontalCenter
                        awScreen: section.modelData.aw
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

            // Directly above the lock, and behaves the same way: click or
            // keybind (Super+Shift+N) both land on NightLight.toggle().
            NightLightWidget {
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
