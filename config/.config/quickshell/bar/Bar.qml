import QtQuick
import Quickshell
import QtQuick.Effects
import "../common"

// Edge bar, one per screen. Transparent window; content sits in floating
// pills, one per slot (see common/BarSections.qml for what a slot is and how
// sections are assigned to them).
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    // Awesome's view of this screen (tags, layout), matched by output name
    readonly property var awScreen: AwesomeState.forOutput(bar.screen.name)

    readonly property bool vertical: BarEdge.vertical

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

    // Anchored to three edges: the two the bar spans, and the one it sits
    // on. The unanchored side is the one barWidth then measures, so the same
    // setting is the bar's width when it's vertical and its height when it
    // isn't.
    anchors {
        left: BarEdge.edge !== "right"
        right: BarEdge.edge !== "left"
        top: BarEdge.edge !== "bottom"
        bottom: BarEdge.edge !== "top"
    }
    implicitWidth: Settings.barWidth
    implicitHeight: Settings.barWidth

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
            // Draw the whole wallpaper at screen size, offset so that the
            // slice showing through the bar lines up with what feh painted
            // underneath it. On the left or top edge the bar's origin is the
            // screen's, so the offset is zero; on the right or bottom it is
            // however far in from that edge the bar starts.
            // PreserveAspectCrop matches feh --bg-fill.
            x: BarEdge.edge === "right" ? -(bar.screen.width - bar.width) : 0
            y: BarEdge.edge === "bottom" ? -(bar.screen.height - bar.height) : 0
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

    // No strut: X11 struts can't reserve an inner edge of a middle monitor.
    // Awesome pads the screen instead (modules/quickshell.lua
    // apply_bar_padding, re-pushed by common/BarSpace.qml on changes).
    exclusionMode: ExclusionMode.Ignore

    // ── Sections ────────────────────────────────────────────────────────
    // Every section is declared once, here, and then reparented into the
    // pill for its slot. Declaring them statically (rather than loading
    // them from a component map) is what lets the panels below keep plain
    // `id` references to the widgets they hang off, and keeps each
    // section's wiring — screen index, bar window, layout name — where it
    // can be read.
    //
    // Nothing is ever drawn in the pool itself: reflow() runs before the
    // first frame and empties it.
    Item {
        id: pool
        visible: false

        Grid {
            id: tagsGroup
            visible: Settings.showTags && bar.tagSections.length > 0
            columns: bar.vertical ? 1 : 99
            spacing: 6
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater {
                model: bar.tagSections

                // The screen's label sits above its tags on a vertical bar
                // and beside them on a horizontal one — stacked, the group
                // is taller than a horizontal bar is thick.
                Grid {
                    id: tagScreen

                    required property var modelData

                    columns: bar.vertical ? 1 : 99
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter
                    spacing: 3

                    Text {
                        // Every monitor is labelled now that the sections
                        // render identically; this screen's label is bold,
                        // which is the only thing marking it as the one the
                        // bar lives on.
                        visible: bar.tagSections.length > 1
                        text: tagScreen.modelData.label
                        font.family: Theme.labelFont
                        font.bold: tagScreen.modelData.isHere
                        font.pointSize: 6
                        color: tagScreen.modelData.isHere ? Theme.subtext : Theme.muted
                    }

                    Workspaces {
                        awScreen: tagScreen.modelData.aw
                    }

                    // Hidden windows sit directly beneath the tags they
                    // belong to, so nothing extra is needed to say which
                    // monitor they're on. Absent unless something is hidden.
                    HiddenWindows {
                        awScreen: tagScreen.modelData.aw
                    }
                }
            }
        }

        // Clock plus the click target that opens the calendar. Wrapping
        // them means the calendar keeps working wherever the clock is
        // moved to.
        Item {
            id: clockGroup
            visible: Settings.showClock
            implicitWidth: clockStack.implicitWidth
            implicitHeight: clockStack.implicitHeight

            ClockStack {
                id: clockStack
                anchors.centerIn: parent
                }

            MouseArea {
                anchors.fill: parent
                onClicked: BarState.toggleCalendar()
            }
        }

        // Media button — only there when an MPRIS player exists.
        // Left-click: media panel; right-click: play/pause.
        Item {
            id: mediaButton

            visible: Media.active !== null && Settings.showMediaPill
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

        TraySection {
            id: traySection
            barWindow: bar
            visible: Settings.showTray
        }

        NotifBell { id: notifBell }
        VolumeWidget { id: volumeWidget }
        NetworkWidget { id: networkWidget }
        BluetoothWidget { id: bluetoothWidget }
        SysMonWidget { id: sysMonWidget }

        // Behaves the same way as the keybind (Super+Shift+N): both land
        // on NightLight.toggle().
        NightLightWidget { id: nightLightWidget }

        ScreenLockWidget { id: screenLockWidget }
        Battery { id: batteryWidget }

        LayoutBox {
            id: layoutBox
            visible: Settings.showLayoutBox
            screenIndex: bar.awScreen ? bar.awScreen.index : 1
            layoutName: bar.awScreen ? bar.awScreen.layout : ""
        }
    }

    readonly property var sectionItems: ({
        "tags":          tagsGroup,
        "clock":         clockGroup,
        "media":         mediaButton,
        "tray":          traySection,
        "notifications": notifBell,
        "volume":        volumeWidget,
        "network":       networkWidget,
        "bluetooth":     bluetoothWidget,
        "sysmon":        sysMonWidget,
        "nightlight":    nightLightWidget,
        "lock":          screenLockWidget,
        "battery":       batteryWidget,
        "layout":        layoutBox
    })

    // Re-home every section into its slot's pill. A positioner orders by
    // child order and reparenting appends, so emptying the pills first and
    // then re-adding in layout order is what makes the order come out
    // right — there is no "insert at index" for a QML positioner.
    function reflow() {
        const slots = {
            "start": startPill.container,
            "center": centerPill.container,
            "end": endPill.container
        };
        for (const id in bar.sectionItems)
            bar.sectionItems[id].parent = pool;
        for (const section of BarSections.arrangement) {
            const item = bar.sectionItems[section.id];
            if (item)
                item.parent = slots[section.slot] || slots["end"];
        }
    }

    Component.onCompleted: bar.reflow()

    Connections {
        target: BarSections
        function onArrangementChanged() { bar.reflow(); }
    }

    Item {
        anchors.fill: parent

        // Placed by x/y rather than anchors. Flipping a set of anchors as
        // the bar changes edge goes through a moment where left and
        // horizontalCenter are both set — an invalid combination that leaves
        // the pill sized wrong afterwards. Arithmetic has no such state.
        Pill {
            id: startPill
            x: bar.vertical ? (parent.width - width) / 2 : 8
            y: bar.vertical ? 8 : (parent.height - height) / 2
        }

        Pill {
            id: centerPill
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
        }

        Pill {
            id: endPill
            x: bar.vertical ? (parent.width - width) / 2
                            : parent.width - width - 8
            y: bar.vertical ? parent.height - height - 8
                            : (parent.height - height) / 2
        }
    }

    MediaPanel {
        barWindow: bar
        anchorItem: mediaButton
    }

    CalendarPopup {
        barWindow: bar
        anchorItem: clockGroup
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
