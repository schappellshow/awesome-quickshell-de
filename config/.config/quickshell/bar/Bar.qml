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
    // bar.screen goes null for a moment when its monitor is unplugged, before
    // the shell hands this window to another one (or destroys it); everything
    // below reads the screen through these guarded copies.
    readonly property string screenName: bar.screen ? bar.screen.name : ""
    readonly property int screenX: bar.screen ? bar.screen.x : 0
    readonly property int screenY: bar.screen ? bar.screen.y : 0
    readonly property int screenW: bar.screen ? bar.screen.width : 0
    readonly property int screenH: bar.screen ? bar.screen.height : 0

    readonly property var awScreen: AwesomeState.forOutput(bar.screenName)

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
                if (out === bar.screenName)
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
    // While auto-hidden the window shrinks to a thin strip on the screen
    // edge. It is what the pointer lands on to bring the bar back, and it
    // keeps the window mapped so no re-creation is needed.
    implicitWidth: bar.thickness
    implicitHeight: bar.thickness

    // ── Auto-hide ───────────────────────────────────────────────────────
    // Settings.barAutoHide off (the default): wantShown is always true, the
    // window is always barWidth thick and nothing below changes anything.
    //
    // On: awesome stops reserving the strip (common/BarSpace.qml), so the bar
    // has to be over the windows when it is shown. It is shown while
    //   * the pointer has been on its edge for a moment (`pointerRevealed`),
    //   * any popup or menu hanging off it is open (`popupOpen`), or
    //   * something wants attention (`attention`: an urgent tag, for a few
    //     seconds),
    // and goes away `hideDelay` after the last of those lapses.
    // Each screen's bar decides for itself.
    readonly property int hotSize: 2
    readonly property int hideDelay: 500
    readonly property int revealDelay: 80
    // Over a fullscreen window a stray flick must not pop the bar over a
    // game or a video, so the pointer has to rest on the edge for longer.
    readonly property int fullscreenRevealDelay: 700

    property bool pointerRevealed: false
    property bool attention: false

    readonly property bool popupOpen: BarState.calendarOpen
        || networkWidget.panelOpen || bluetoothWidget.panelOpen
        || drivesWidget.panelOpen || traySection.openMenus > 0
        || Media.openOn === bar.screenName

    readonly property bool wantShown: !Settings.barAutoHide
        || pointerRevealed || popupOpen || attention

    // 0 = fully out of view, 1 = fully in. The window stays full size for
    // as long as any of the bar is still visible, and only shrinks to the
    // hot strip once it has slid all the way out.
    property real shown: wantShown ? 1 : 0
    Behavior on shown {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    readonly property bool expanded: wantShown || shown > 0.001
    readonly property int thickness: expanded ? Settings.barWidth : bar.hotSize

    // How far the bar's drawing is pushed off its edge, in the direction
    // the bar's own edge is in.
    readonly property real shiftX: !vertical ? 0
        : (BarEdge.edge === "left" ? -1 : 1) * (1 - shown) * Settings.barWidth
    readonly property real shiftY: vertical ? 0
        : (BarEdge.edge === "top" ? -1 : 1) * (1 - shown) * Settings.barWidth

    // Is a window covering this whole screen? awesome's state carries
    // geometry but no fullscreen flag; a fullscreen client is the one kind
    // that reaches the screen's own bounds (borders are outside a client's
    // geometry, so a tiled or maximized one never does).
    readonly property bool fullscreenHere: {
        const tagsShown = {};
        for (const t of (bar.awScreen ? bar.awScreen.tags || [] : []))
            if (t.selected)
                tagsShown[t.index] = true;
        return AwesomeState.allClients.some(c =>
            c.output === bar.screenName && !c.minimized
            && (c.tags || []).some(t => tagsShown[t])
            && c.x <= bar.screenX && c.y <= bar.screenY
            && c.width >= bar.screenW && c.height >= bar.screenH);
    }

    Timer {
        id: revealTimer
        interval: bar.fullscreenHere ? bar.fullscreenRevealDelay : bar.revealDelay
        onTriggered: bar.pointerRevealed = true
    }

    Timer {
        id: hideTimer
        interval: bar.hideDelay
        onTriggered: {
            if (!edgeHover.hovered && !bar.popupOpen)
                bar.pointerRevealed = false;
        }
    }

    // A popup that closes with the pointer already away starts the clock.
    onPopupOpenChanged: if (!popupOpen && !edgeHover.hovered) hideTimer.restart()

    // Turning auto-hide off drops any left-over reveal so that turning it
    // on again starts out of view.
    Connections {
        target: Settings
        function onBarAutoHideChanged() {
            bar.pointerRevealed = false;
            bar.attention = false;
        }
    }

    // Urgent tags on this screen: reveal briefly when a new one appears.
    // (Notifications pop up by themselves and don't need the bar too.)
    readonly property int urgentCount: {
        let n = 0;
        for (const t of (bar.awScreen ? bar.awScreen.tags || [] : []))
            if (t.urgent)
                n++;
        return n;
    }
    onUrgentCountChanged: {
        if (Settings.barAutoHide && urgentCount > 0) {
            attention = true;
            attentionTimer.restart();
        }
    }
    Timer {
        id: attentionTimer
        interval: 3000
        onTriggered: bar.attention = false
    }

    // Always as big as the window, so the pointer is noticed on the hot
    // strip as well as on the full bar.
    Item {
        anchors.fill: parent

        HoverHandler {
            id: edgeHover
            onHoveredChanged: {
                if (!Settings.barAutoHide)
                    return;
                if (hovered) {
                    hideTimer.stop();
                    if (!bar.pointerRevealed)
                        revealTimer.restart();
                } else {
                    revealTimer.stop();
                    hideTimer.restart();
                }
            }
        }
    }

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
            && bar.shown > 0
        clip: true
        transform: Translate { x: bar.shiftX; y: bar.shiftY }

        Image {
            id: wallCopy
            // Draw the whole wallpaper at screen size, offset so that the
            // slice showing through the bar lines up with what feh painted
            // underneath it. On the left or top edge the bar's origin is the
            // screen's, so the offset is zero; on the right or bottom it is
            // however far in from that edge the bar starts.
            // PreserveAspectCrop matches feh --bg-fill.
            x: BarEdge.edge === "right" ? -(bar.screenW - bar.width) : 0
            y: BarEdge.edge === "bottom" ? -(bar.screenH - bar.height) : 0
            width: bar.screenW
            height: bar.screenH
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
        visible: bar.shown > 0
        transform: Translate { x: bar.shiftX; y: bar.shiftY }
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

        StartButton {
            id: startButton
            barWindow: bar
        }

        PinnedStrip { id: pinnedStrip }

        WindowList { id: windowList }

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
                        Media.toggleOn(bar.screenName);
                    }
                }
            }
        }

        TraySection {
            id: traySection
            barWindow: bar
            visible: Settings.showTray
        }

        DrivesWidget { id: drivesWidget; barWindow: bar }
        NotifBell { id: notifBell }
        VolumeWidget { id: volumeWidget }
        NetworkWidget { id: networkWidget }
        BluetoothWidget { id: bluetoothWidget }
        SysMonWidget { id: sysMonWidget }

        // Behaves the same way as the keybind (Super+Shift+N): both land
        // on NightLight.toggle().
        NightLightWidget { id: nightLightWidget }

        ScreenLockWidget { id: screenLockWidget }
        PerfWidget { id: perfWidget; barWindow: bar }
        Battery { id: batteryWidget }

        LayoutBox {
            id: layoutBox
            visible: Settings.showLayoutBox
            screenIndex: bar.awScreen ? bar.awScreen.index : 1
            layoutName: bar.awScreen ? bar.awScreen.layout : ""
        }
    }

    readonly property var sectionItems: ({
        "start":         startButton,
        "pinned":        pinnedStrip,
        "windows":       windowList,
        "tags":          tagsGroup,
        "clock":         clockGroup,
        "media":         mediaButton,
        "tray":          traySection,
        "drives":        drivesWidget,
        "notifications": notifBell,
        "volume":        volumeWidget,
        "network":       networkWidget,
        "bluetooth":     bluetoothWidget,
        "sysmon":        sysMonWidget,
        "nightlight":    nightLightWidget,
        "lock":          screenLockWidget,
        "perf":          perfWidget,
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

    // ── Self-check support (see common/BarHealth.qml) ───────────────────
    // Sections that always have something to draw while they are visible:
    // the taglist always has tag numbers, the clock always has a time.
    // Anything that can legitimately be empty (tray, media, drives...) is
    // left out so an empty one is never mistaken for a blank one.
    readonly property var paintedIds: ["tags", "clock"]

    // Grab each of those sections to <prefix>-<id>.png and call
    // done(paths, missing) once every grab has come back. `paths` are the
    // files written; `missing` lists sections that should have been grabbed
    // but could not be (zero size, not in a pill) — a section that is laid
    // out with no size at all counts as a failure too.
    function snapshotSections(prefix, done) {
        const jobs = [];
        const paths = [];
        const missing = [];
        for (const id of bar.paintedIds) {
            const item = bar.sectionItems[id];
            if (!item || !item.visible || item.parent === pool)
                continue;      // not shown in this arrangement
            jobs.push({ id: id, item: item });
        }
        let left = jobs.length;
        if (left === 0 || bar.shown < 1) {
            done([], []);
            return;
        }
        for (const job of jobs) {
            const path = prefix + "-" + job.id + ".png";
            const ok = job.item.grabToImage(result => {
                if (result.saveToFile(path))
                    paths.push(path);
                else
                    missing.push(job.id);
                if (--left === 0)
                    done(paths, missing);
            });
            if (!ok) {
                missing.push(job.id);
                if (--left === 0)
                    done(paths, missing);
            }
        }
    }

    Connections {
        target: BarSections
        function onArrangementChanged() { bar.reflow(); }
    }

    Item {
        anchors.fill: parent
        visible: bar.shown > 0
        transform: Translate { x: bar.shiftX; y: bar.shiftY }

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

    DrivesPanel {
        barWindow: bar
        anchorItem: drivesWidget
        shown: drivesWidget.panelOpen && drivesWidget.visible
        onDismiss: drivesWidget.panelOpen = false
    }

    BluetoothPanel {
        barWindow: bar
        anchorItem: bluetoothWidget
        shown: bluetoothWidget.panelOpen
        onDismiss: bluetoothWidget.panelOpen = false
    }
}
