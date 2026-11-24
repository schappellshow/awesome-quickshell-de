import QtQuick
import Quickshell
import "../common"

// Native system dashboard — the Quickshell replacement for the conky
// popout. Cards: System, Processors, Memory, Drives, Network, GPU, each
// switchable in Settings -> Bar. Numbers come from common/SysStats.qml,
// which only samples while this window exists; the window itself only
// exists while DashboardState.visible (LazyLoader), so closed costs nothing.
//
// Placement (Settings.dashboardPosition, set from the gear): by default on
// the bar's screen in the corner beside the bar (so it grows away from
// whichever edge the bar is on), the same spot conky used; or a screen
// corner, the center, or a custom spot dragged by the header. Always kept
// on screen and clear of the bar.
// Cards flow left, right, left, right in Settings.dashOrder; the gear in the
// header opens a panel with position, card order, opacity and blur.
// Popout mode draws it above the windows; pinned mode draws it below them
// (a desktop widget) until DashboardState.raised lifts it. It never takes
// focus and never reserves space.
Scope {
    id: root

    property var targetScreen: null

    function updateTargetScreen() {
        const match = Quickshell.screens.filter(
            s => s.name === Settings.barScreen);
        root.targetScreen = match.length > 0 ? match[0] : Quickshell.screens[0];
        DashboardState.screenName = root.targetScreen ? root.targetScreen.name : "";
    }

    Component.onCompleted: updateTargetScreen()

    Connections {
        target: Settings
        function onBarScreenChanged() { root.updateTargetScreen(); }
    }

    // ── Formatting ──
    function fmtBytes(b) {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (b >= 100 || i === 0 ? b.toFixed(0) : b.toFixed(1)) + " " + u[i];
    }

    function fmtRate(b) { return fmtBytes(b) + "/s"; }

    function fmtUptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
              m = Math.floor(s % 3600 / 60);
        return (d > 0 ? d + "d " : "") + h + "h " + m + "m";
    }

    function usageColor(p) {
        return p >= 90 ? Theme.urgent : p >= 70 ? Theme.gold : Theme.green;
    }

    // ── Pieces ──
    component Label: Text {
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.subtext
        elide: Text.ElideRight
    }

    // Left label, right-aligned value
    component KV: Item {
        id: kv
        property string k
        property string v
        property color vColor: Theme.text
        width: parent.width
        height: 15
        Label { text: kv.k; color: Theme.muted }
        Label {
            anchors.right: parent.right
            width: parent.width - 70
            horizontalAlignment: Text.AlignRight
            text: kv.v
            color: kv.vColor
        }
    }

    // Horizontal usage bar with a caption on the left and a value on the right
    component UsageBar: Item {
        id: ub
        property string caption
        property string valueText
        property real fraction: 0
        width: parent.width
        height: 28
        Label { text: ub.caption; color: Theme.muted }
        Label { anchors.right: parent.right; text: ub.valueText; color: Theme.text }
        Rectangle {
            y: 16; width: parent.width; height: 6; radius: 3
            color: Theme.surfaceAlt
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, ub.fraction))
                height: parent.height; radius: 3
                color: root.usageColor(ub.fraction * 100)
            }
        }
    }

    // History graph, newest sample at the right, one column per sample.
    // maxValue 0 = autoscale (never below `floor`, so a quiet line stays
    // flat instead of noisy). Plain rectangles rather than a Shape: they
    // render everywhere, including software GL, and the graph is small.
    component Spark: Item {
        id: sp
        property var values: []
        property real maxValue: 100
        property real floor: 1
        property color color: Theme.accentBright
        readonly property real peak: maxValue > 0 ? maxValue
            : Math.max(floor, Math.max.apply(null, values.length ? values : [0]))
        readonly property real step: width / SysStats.historyLen
        height: 30
        width: parent.width
        clip: true
        Rectangle { anchors.fill: parent; radius: 4; color: DashboardState.fade(Theme.base); opacity: 0.5 }
        Repeater {
            model: sp.values.length
            Rectangle {
                required property int index
                readonly property real v: Math.min(1, sp.values[index] / sp.peak)
                x: sp.width - (sp.values.length - index) * sp.step
                width: Math.max(1, sp.step - 1)
                height: Math.max(1, v * (sp.height - 2))
                anchors.bottom: parent.bottom
                color: sp.color
                opacity: 0.8
            }
        }
    }

    // Titled rounded card; children go in the column
    component Card: Rectangle {
        id: card
        property string title
        default property alias content: body.data
        width: parent.width
        height: body.implicitHeight + 34
        radius: 8
        color: DashboardState.fade(Theme.surface)
        Label {
            x: 10; y: 8
            text: card.title
            font.bold: true
            font.letterSpacing: 1.5
            color: Theme.accentBright
        }
        Column {
            id: body
            x: 10; y: 26
            width: parent.width - 20
            spacing: 4
        }
    }

    // One process row: name, CPU %, MEM %
    component ProcTable: Column {
        id: pt
        property var rows: []
        property bool byCpu: true
        width: parent.width
        spacing: 1
        Item {
            width: parent.width; height: 14
            Label { text: "process"; color: Theme.muted; font.pointSize: 7 }
            Label { x: parent.width - 80; text: "CPU"; color: pt.byCpu ? Theme.accentBright : Theme.muted; font.pointSize: 7 }
            Label { x: parent.width - 38; text: "MEM"; color: pt.byCpu ? Theme.muted : Theme.accentBright; font.pointSize: 7 }
        }
        // Always nine rows, so the card does not change height as the
        // list fills in or a process has no CPU yet
        Repeater {
            model: 9
            Item {
                id: row
                required property int index
                readonly property var p: pt.rows[index]
                width: pt.width; height: 14
                Label { width: parent.width - 90; text: row.p ? row.p.name : ""; color: Theme.text }
                Label { x: parent.width - 80; text: row.p ? row.p.cpu.toFixed(1) + "%" : "" }
                Label { x: parent.width - 38; text: row.p ? row.p.mem.toFixed(1) + "%" : "" }
            }
        }
    }

    // The window is only mapped while shown; its contents are built by the
    // Loader below, so closed holds no scene and samples nothing.
    Item {
        PanelWindow {
            id: win

            screen: root.targetScreen
            // Mapped only once the cards are built and the height is known,
            // so the first placement is already the final one.
            visible: DashboardState.visible && implicitHeight > 0
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // Popout: over the windows. Pinned: on the desktop, under them.
            aboveWindows: DashboardState.above

            // Compositor blur behind the dashboard (common/BlurHint.qml).
            // The frame fills the window with Theme.radius corners, so the
            // blur uses the same radius. Moving the dashboard changes its
            // margins, not its size, so a move needs an explicit refresh.
            readonly property bool blurWanted: Settings.dashboardBlur
            BlurHint {
                id: blurHint
                window: win
                enabled: win.blurWanted
                radius: Theme.radius
            }
            onPlaceChanged: blurHint.refresh()

            // ── Placement ──
            // The window is always anchored top-left and positioned by
            // margins, so every mode (bar spot, corners, center, dragged) is
            // one computation. Coordinates are relative to the screen.
            readonly property int edgeGap: 12
            readonly property int clear: Settings.barWidth + BarEdge.gap + 2
            readonly property bool screenKnown:
                Quickshell.screens.some(s => s.name === Settings.barScreen)
            // All placement maths uses the screen the dashboard was ASSIGNED
            // (root.targetScreen), never the window's own `screen`: Qt
            // re-derives that from where X first maps the window, which can be
            // another monitor (a portrait one at 0,0 here). Reading it made
            // the dashboard place itself with that monitor's size, land off
            // screen, flip screens again and chase itself, a resize loop that
            // hung awesome on 2026-11-24.
            readonly property var home: root.targetScreen
            readonly property bool hasBar: !screenKnown || (home && home.name === Settings.barScreen)
            // What the bar reserves on its edge: nothing while it auto-hides
            readonly property int reserve:
                hasBar && !Settings.barAutoHide ? clear : edgeGap
            readonly property int insetL: BarEdge.edge === "left" ? reserve : edgeGap
            readonly property int insetR: BarEdge.edge === "right" ? reserve : edgeGap
            readonly property int insetT: BarEdge.edge === "top" ? reserve : edgeGap
            readonly property int insetB: BarEdge.edge === "bottom" ? reserve : edgeGap
            readonly property real sw: home ? home.width : 1920
            readonly property real sh: home ? home.height : 1080

            // A pending drag, in screen coordinates; null when not dragging
            property var drag: null

            function clampX(x) {
                return Math.max(insetL, Math.min(x, sw - insetR - implicitWidth));
            }
            function clampY(y) {
                return Math.max(insetT, Math.min(y, sh - insetB - implicitHeight));
            }

            // Top-left for a named position
            function spot(mode) {
                const w = implicitWidth, h = implicitHeight;
                switch (mode) {
                case "topleft":     return [insetL, insetT];
                case "topright":    return [sw - insetR - w, insetT];
                case "bottomleft":  return [insetL, sh - insetB - h];
                case "bottomright": return [sw - insetR - w, sh - insetB - h];
                case "center":
                    return [insetL + (sw - insetL - insetR - w) / 2,
                            insetT + (sh - insetT - insetB - h) / 2];
                case "custom": {
                    const p = DashboardState.customPos(home ? home.name : "");
                    if (p)
                        return [p[0], p[1]];
                    // fall through: never placed, start where it would be
                }
                default:
                    // Beside the bar: against the bar's edge, the other
                    // axis pinned to the opposite screen corner's gap
                    return [BarEdge.edge === "right" ? sw - clear - w
                            : BarEdge.edge === "left" ? clear : edgeGap,
                            BarEdge.edge === "bottom" ? sh - clear - h
                            : BarEdge.edge === "top" ? clear : edgeGap];
                }
            }

            readonly property var place: drag ? drag : spot(DashboardState.position)

            // Called by the header drag; remembers the spot and switches to
            // custom so the placement sticks
            function dragBy(dx, dy) {
                const cur = win.drag ? win.drag
                    : win.spot(DashboardState.position === "custom" ? "custom"
                               : DashboardState.position);
                win.drag = [win.clampX(cur[0] + dx), win.clampY(cur[1] + dy)];
            }

            function dragEnd() {
                if (!win.drag)
                    return;
                const name = home ? home.name : "";
                DashboardState.setCustomPos(name, win.drag[0], win.drag[1]);
                Settings.dashboardPosition = "custom";
                win.drag = null;
            }

            // Switch position; "custom" keeps the dashboard where it is
            function usePosition(mode) {
                if (mode === "custom" && !DashboardState.customPos(home ? home.name : "")) {
                    const here = win.spot(DashboardState.position);
                    DashboardState.setCustomPos(home ? home.name : "",
                                                win.clampX(here[0]), win.clampY(here[1]));
                }
                Settings.dashboardPosition = mode;
            }

            anchors { top: true; left: true }
            margins {
                left: Math.round(win.clampX(win.place[0]))
                top: Math.round(win.clampY(win.place[1]))
            }

            implicitWidth: 760
            implicitHeight: body.item ? body.item.implicitHeight : 0

            Loader {
                id: body
                anchors.fill: parent
                // Built as soon as the dashboard is wanted, before the window
                // maps (see visible above); torn down when it closes.
                active: DashboardState.visible
                sourceComponent: frameComp
            }

            Component { id: frameComp
            Rectangle {
                id: frame
                anchors.fill: parent
                readonly property int headerH: 24
                implicitHeight: Math.max(cardsBottom - headerH - 10,
                    DashboardState.settingsOpen ? gearPanel.implicitHeight : 0)
                    + headerH + 10 + 10
                radius: Theme.radius
                color: DashboardState.fade(Theme.base)
                border.color: DashboardState.above ? Theme.accentBright : Theme.surface
                border.width: 2

                // ── header: drag handle, gear ──
                Item {
                    id: header
                    x: 2; y: 2
                    width: parent.width - 4
                    height: frame.headerH
                    HoverHandler { id: headerHover; cursorShape: Qt.SizeAllCursor }
                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: DashboardState.settingsOpen ? "DASHBOARD SETTINGS" : "SYSTEM"
                        font.family: Theme.fontFamily
                        font.pointSize: 8
                        font.bold: true
                        font.letterSpacing: 1.5
                        color: Theme.muted
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 34
                        property real px: 0
                        property real py: 0
                        onPressed: m => { px = m.x; py = m.y; }
                        // The window follows the pointer, so each move is
                        // the lag still to catch up
                        onPositionChanged: m => { if (pressed) win.dragBy(m.x - px, m.y - py); }
                        onReleased: win.dragEnd()
                        onCanceled: win.dragEnd()
                    }
                    Rectangle {
                        id: gear
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 11
                        color: DashboardState.settingsOpen ? Theme.accent
                             : gearHover.hovered ? Theme.surfaceAlt : "transparent"
                        // Unobtrusive: only while the pointer is on the header
                        opacity: DashboardState.settingsOpen || headerHover.hovered
                                 || gearHover.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\u2699"
                            font.pointSize: 11
                            color: DashboardState.settingsOpen ? Theme.base : Theme.subtext
                        }
                        HoverHandler { id: gearHover }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: DashboardState.settingsOpen = !DashboardState.settingsOpen
                        }
                    }
                }

                // ── cards: left, right, left, right in the saved order ──
                // Every card exists; the ones in DashboardState.shownCards
                // are visible and stacked by cardX/cardY.
                readonly property real colW: (width - 30) / 2
                readonly property var cardItems: ({
                    system: cSystem, cpu: cCpu, memory: cMemory,
                    drives: cDrives, network: cNetwork, gpu: cGpu })
                function shown(id) { return DashboardState.shownCards.includes(id); }
                function cardX(id) {
                    return 10 + (DashboardState.shownCards.indexOf(id) % 2) * (colW + 10);
                }
                // Stack height of one column, up to (not including) index `upto`
                function stackTo(col, upto) {
                    let y = frame.headerH + 10;
                    const ids = DashboardState.shownCards;
                    for (let i = col; i < upto && i < ids.length; i += 2)
                        y += cardItems[ids[i]].height + 8;
                    return y;
                }
                function cardY(id) {
                    const i = DashboardState.shownCards.indexOf(id);
                    return i < 0 ? 0 : stackTo(i % 2, i);
                }
                readonly property real cardsBottom: Math.max(
                    stackTo(0, DashboardState.shownCards.length),
                    stackTo(1, DashboardState.shownCards.length)) - 8

                // ── gear panel: covers the cards ──
                Rectangle {
                    id: gearPanel
                    visible: DashboardState.settingsOpen
                    z: 10
                    x: 6; y: frame.headerH + 4
                    width: parent.width - 12
                    height: parent.height - y - 6
                    implicitHeight: Math.max(panelLeft.implicitHeight, panelRight.implicitHeight) + 28
                    radius: Theme.radius - 2
                    // See the opacity change through it while dragging the slider
                    color: Theme.base
                    opacity: opacitySlider.pressed ? 0.1 : 1
                    Behavior on opacity { NumberAnimation { duration: 100 } }

                    // Swallow clicks so nothing underneath reacts
                    MouseArea { anchors.fill: parent }

                    Column {
                        id: panelLeft
                        x: 12; y: 12
                        width: (parent.width - 36) / 2
                        spacing: 8

                        Label { text: "POSITION"; font.bold: true; font.letterSpacing: 1.5; color: Theme.accentBright }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: DashboardState.positionIds
                                DashChip {
                                    required property string modelData
                                    text: DashboardState.positionLabel(modelData)
                                    active: DashboardState.position === modelData
                                    onClicked: win.usePosition(modelData)
                                }
                            }
                        }
                        Label {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: "Drag the header to place it yourself; the spot is remembered per screen."
                            color: Theme.muted
                        }

                        Label { text: "BACKGROUND"; font.bold: true; font.letterSpacing: 1.5; color: Theme.accentBright; topPadding: 6 }
                        Item {
                            width: parent.width; height: 20
                            Label { text: "Opacity"; anchors.verticalCenter: parent.verticalCenter; color: Theme.text }
                            Label {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: Settings.dashboardOpacity + "%"
                                color: Theme.subtext
                            }
                        }
                        MiniSlider {
                            id: opacitySlider
                            width: parent.width
                            from: 40; to: 100
                            value: Math.round(DashboardState.bgAlpha * 100)
                            onMoved: v => Settings.dashboardOpacity = v
                        }
                        Item {
                            width: parent.width; height: 24
                            Label { text: "Blur behind"; anchors.verticalCenter: parent.verticalCenter; color: Theme.text }
                            DashChip {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: Settings.dashboardBlur ? "On" : "Off"
                                active: Settings.dashboardBlur
                                onClicked: Settings.dashboardBlur = !Settings.dashboardBlur
                            }
                        }
                    }

                    Column {
                        id: panelRight
                        x: 24 + panelLeft.width; y: 12
                        width: panelLeft.width
                        spacing: 4

                        Label { text: "CARDS"; font.bold: true; font.letterSpacing: 1.5; color: Theme.accentBright }
                        Repeater {
                            model: DashboardState.order
                            Item {
                                id: orow
                                required property string modelData
                                required property int index
                                width: panelRight.width; height: 26
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: DashboardState.cardTitle(orow.modelData)
                                    color: DashboardState.cardEnabled(orow.modelData) ? Theme.text : Theme.muted
                                }
                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    DashChip {
                                        text: DashboardState.cardEnabled(orow.modelData) ? "Shown" : "Hidden"
                                        active: DashboardState.cardEnabled(orow.modelData)
                                        onClicked: DashboardState.setCardEnabled(
                                            orow.modelData, !DashboardState.cardEnabled(orow.modelData))
                                    }
                                    DashChip {
                                        text: "\u25B2"
                                        dim: orow.index === 0
                                        onClicked: DashboardState.moveCard(orow.modelData, -1)
                                    }
                                    DashChip {
                                        text: "\u25BC"
                                        dim: orow.index === DashboardState.order.length - 1
                                        onClicked: DashboardState.moveCard(orow.modelData, 1)
                                    }
                                }
                            }
                        }
                        Label {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: "Cards fill left, right, left, right in this order."
                            color: Theme.muted
                        }
                    }
                }

                Card {
                    id: cSystem
                    readonly property string cid: "system"
                    visible: frame.shown(cid)
                    x: frame.cardX(cid); y: frame.cardY(cid)
                    width: frame.colW

                        title: "SYSTEM"
                        KV { k: "host"; v: SysStats.hostname }
                        KV { k: "distro"; v: SysStats.distro }
                        KV { k: "kernel"; v: SysStats.kernel }
                        KV { k: "uptime"; v: root.fmtUptime(SysStats.uptimeSec) }
                }

                Card {
                    id: cCpu
                    readonly property string cid: "cpu"
                    visible: frame.shown(cid)
                    x: frame.cardX(cid); y: frame.cardY(cid)
                    width: frame.colW

                        title: "PROCESSORS"
                        KV {
                            k: "usage"
                            v: SysStats.cpuPct.toFixed(0) + "%   "
                               + (SysStats.cpuMhz / 1000).toFixed(2) + " GHz"
                            vColor: root.usageColor(SysStats.cpuPct)
                        }
                        KV {
                            k: "temperature"
                            v: SysStats.cpuTemp < 0 ? "n/a" : SysStats.cpuTemp.toFixed(0) + " °C"
                            vColor: SysStats.cpuTemp >= 85 ? Theme.urgent
                                  : SysStats.cpuTemp >= 70 ? Theme.gold : Theme.text
                        }
                        Spark { values: SysStats.cpuHist; color: Theme.accentBright }
                        // One column per thread
                        Row {
                            id: coreRow
                            width: parent.width
                            height: 34
                            spacing: 2
                            Repeater {
                                model: SysStats.cores
                                Item {
                                    required property real modelData
                                    width: Math.max(2, (coreRow.width - 2 * (SysStats.cores.length - 1))
                                                       / Math.max(1, SysStats.cores.length))
                                    height: coreRow.height
                                    Rectangle { anchors.fill: parent; radius: 2; color: Theme.surfaceAlt }
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(1, parent.height * modelData / 100)
                                        radius: 2
                                        color: root.usageColor(modelData)
                                    }
                                }
                            }
                        }
                        ProcTable { rows: SysStats.topCpu; byCpu: true }
                }

                Card {
                    id: cMemory
                    readonly property string cid: "memory"
                    visible: frame.shown(cid)
                    x: frame.cardX(cid); y: frame.cardY(cid)
                    width: frame.colW

                        title: "MEMORY"
                        UsageBar {
                            caption: "RAM"
                            valueText: root.fmtBytes(SysStats.memUsed) + " / " + root.fmtBytes(SysStats.memTotal)
                            fraction: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
                        }
                        UsageBar {
                            caption: "swap"
                            valueText: root.fmtBytes(SysStats.swapUsed) + " / " + root.fmtBytes(SysStats.swapTotal)
                            fraction: SysStats.swapTotal > 0 ? SysStats.swapUsed / SysStats.swapTotal : 0
                        }
                        ProcTable { rows: SysStats.topMem; byCpu: false }
                }

                Card {
                    id: cDrives
                    readonly property string cid: "drives"
                    visible: frame.shown(cid)
                    x: frame.cardX(cid); y: frame.cardY(cid)
                    width: frame.colW

                        title: "DRIVES"
                        UsageBar {
                            caption: "/"
                            valueText: root.fmtBytes(SysStats.rootUsed) + " / " + root.fmtBytes(SysStats.rootSize)
                            fraction: SysStats.rootSize > 0 ? SysStats.rootUsed / SysStats.rootSize : 0
                        }
                        KV { k: "read"; v: root.fmtRate(SysStats.diskRead) }
                        Spark { values: SysStats.diskReadHist; maxValue: 0; floor: 1048576; color: Theme.teal; height: 22 }
                        KV { k: "write"; v: root.fmtRate(SysStats.diskWrite) }
                        Spark { values: SysStats.diskWriteHist; maxValue: 0; floor: 1048576; color: Theme.orange; height: 22 }
                }

                Card {
                    id: cNetwork
                    readonly property string cid: "network"
                    visible: frame.shown(cid)
                    x: frame.cardX(cid); y: frame.cardY(cid)
                    width: frame.colW

                        title: "NETWORK"
                        KV {
                            k: SysStats.iface === "" ? "interface" : SysStats.iface
                               + (SysStats.wifi ? " (wifi)" : "")
                            v: SysStats.iface === "" ? "no route"
                               : (SysStats.ip !== "" ? SysStats.ip : "no address")
                        }
                        KV {
                            visible: SysStats.wifi && Network.ssid !== ""
                            k: "network"
                            v: Network.ssid + "  " + Network.signalStrength + "%"
                        }
                        KV { k: "down"; v: root.fmtRate(SysStats.netDown) }
                        Spark { values: SysStats.netDownHist; maxValue: 0; floor: 102400; color: Theme.green; height: 22 }
                        KV { k: "up"; v: root.fmtRate(SysStats.netUp) }
                        Spark { values: SysStats.netUpHist; maxValue: 0; floor: 102400; color: Theme.blue; height: 22 }
                }

                Card {
                    id: cGpu
                    readonly property string cid: "gpu"
                    visible: frame.shown(cid)
                    x: frame.cardX(cid); y: frame.cardY(cid)
                    width: frame.colW

                        title: "GPU"
                        Label {
                            visible: !SysStats.gpuPresent
                            text: "no readable GPU sensors"
                            color: Theme.muted
                        }
                        Column {
                            visible: SysStats.gpuPresent
                            width: parent.width
                            spacing: 4
                            KV {
                                k: "utilization"
                                v: SysStats.gpuPct.toFixed(0) + "%"
                                    + (SysStats.gpuTemp < 0 ? "" : "   " + SysStats.gpuTemp.toFixed(0) + " °C")
                                vColor: root.usageColor(SysStats.gpuPct)
                            }
                            Spark { values: SysStats.gpuHist; color: Theme.purple }
                            UsageBar {
                                caption: "VRAM"
                                valueText: root.fmtBytes(SysStats.vramUsed) + " / " + root.fmtBytes(SysStats.vramTotal)
                                fraction: SysStats.vramTotal > 0 ? SysStats.vramUsed / SysStats.vramTotal : 0
                            }
                        }
                }
            }
            }
        }
    }
}
