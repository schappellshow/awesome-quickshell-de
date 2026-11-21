import QtQuick
import Quickshell
import "../common"

// Native system dashboard — the Quickshell replacement for the conky
// popout. Cards: System, Processors, Memory, Drives, Network, GPU, each
// switchable in Settings -> Bar. Numbers come from common/SysStats.qml,
// which only samples while this window exists; the window itself only
// exists while DashboardState.visible (LazyLoader), so closed costs nothing.
//
// Placement: on the bar's screen, in the corner beside the bar (so it grows
// away from whichever edge the bar is on), the same spot conky used.
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
        Rectangle { anchors.fill: parent; radius: 4; color: Theme.base; opacity: 0.5 }
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
        color: Theme.surface
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
            visible: DashboardState.visible
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // Popout: over the windows. Pinned: on the desktop, under them.
            aboveWindows: DashboardState.above

            readonly property int clear: Settings.barWidth + BarEdge.gap + 2
            anchors {
                top: BarEdge.edge !== "bottom"
                bottom: BarEdge.edge === "bottom"
                left: BarEdge.edge !== "right"
                right: BarEdge.edge === "right"
            }
            margins {
                left: BarEdge.edge === "left" ? win.clear : 12
                right: BarEdge.edge === "right" ? win.clear : 12
                top: BarEdge.edge === "top" ? win.clear : 12
                bottom: BarEdge.edge === "bottom" ? win.clear : 12
            }

            implicitWidth: 760
            implicitHeight: body.item ? body.item.implicitHeight : 0

            Loader {
                id: body
                anchors.fill: parent
                active: win.visible
                sourceComponent: frameComp
            }

            Component { id: frameComp
            Rectangle {
                id: frame
                anchors.fill: parent
                implicitHeight: Math.max(left.implicitHeight, right.implicitHeight) + 20
                radius: Theme.radius
                color: Theme.base
                border.color: DashboardState.above ? Theme.accentBright : Theme.surface
                border.width: 2

                // ── left column ──
                Column {
                    id: left
                    x: 10; y: 10
                    width: (parent.width - 30) / 2
                    spacing: 8

                    Card {
                        visible: Settings.dashSectionSystem
                        title: "SYSTEM"
                        KV { k: "host"; v: SysStats.hostname }
                        KV { k: "distro"; v: SysStats.distro }
                        KV { k: "kernel"; v: SysStats.kernel }
                        KV { k: "uptime"; v: root.fmtUptime(SysStats.uptimeSec) }
                    }

                    Card {
                        visible: Settings.dashSectionCpu
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
                        visible: Settings.dashSectionGpu
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

                // ── right column ──
                Column {
                    id: right
                    x: 20 + left.width; y: 10
                    width: left.width
                    spacing: 8

                    Card {
                        visible: Settings.dashSectionMemory
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
                        visible: Settings.dashSectionDrives
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
                        visible: Settings.dashSectionNetwork
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
                }
            }
            }
        }
    }
}
