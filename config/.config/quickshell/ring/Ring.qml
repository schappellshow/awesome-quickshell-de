import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Quick-actions ring: round buttons in a circle around the pointer.
//
// Opened by awesome (Super+middle-click, or the optional keyboard binding)
// through `qs ipc call ring open <x> <y> <win>`; modules/ring.lua explains the
// division of labor and the whole protocol. Short version:
//
//   * a quick click opens it and it stays up: click an action, click the
//     center or outside it, or press Escape, to leave;
//   * holding the button keeps it up while the pointer moves (awesome sends
//     `hover`) and releasing over an action runs it. Release in the center
//     or outside the ring cancels.
//
// Window actions act on `win`, the X id of the client that was under the
// pointer when the ring opened — not on the focused one — and are greyed out
// when the ring was opened over the bare desktop (win == "0").
//
// Under X11 the surface is override-redirect and never receives key events,
// so awesome grabs the keyboard while the ring is up and forwards a few keys
// through `ring key` (Escape, 1-9, arrows, Return).
Scope {
    id: root

    property bool shown: false
    // Client under the pointer at open time, as an X window id string.
    property string win: "0"
    readonly property bool hasWindow: /^[1-9][0-9]*$/.test(root.win)

    // Where the ring is: which screen, and its center in that screen's own
    // coordinates, already clamped so the whole ring stays on it.
    property var target: null
    property real cx: 0
    property real cy: 0

    // Highlighted entry: an index, -2 for the center, -1 for none.
    property int hot: -1

    readonly property var items: RingActions.resolve(Settings.ringActions)

    // Geometry (px). The window is the whole screen so a click outside
    // the ring can cancel; the ring is drawn within `half` of its center.
    readonly property real ringRadius: 92
    readonly property real buttonSize: 52
    readonly property real centerSize: 36
    readonly property real half: ringRadius + buttonSize / 2 + 12
    // The label hangs under the ring, so the bottom clamp leaves room for it.
    readonly property real labelSpace: 40

    // Animate only when window animations are on and performance mode is
    // not: the same two switches the compositor effects follow.
    readonly property bool animated:
        Settings.windowAnimations !== "off" && !PerformanceMode.active
    readonly property bool lively: Settings.windowAnimations === "lively"

    function actionEnabled(a) {
        return !a.window || root.hasWindow;
    }

    function openAt(x, y, winId) {
        if (!Settings.ringEnabled || root.items.length === 0)
            return;
        const screens = Quickshell.screens;
        const scr = screens.find(s => x >= s.x && x < s.x + s.width
                                      && y >= s.y && y < s.y + s.height)
            ?? screens.find(s => s.name === AwesomeState.focusedOutput)
            ?? screens[0];
        if (!scr)
            return;
        const h = root.half;
        root.target = scr;
        // Keep out of the space the bar reserves (none while it auto-hides,
        // the same rule BarSpace applies to awesome's padding), on whichever
        // edge it sits, and only on the screen that has a bar.
        const known = screens.some(s => s.name === Settings.barScreen);
        const hasBar = !known || scr.name === Settings.barScreen;
        const bar = hasBar && !Settings.barAutoHide ? Settings.barWidth + 3 : 0;
        const e = BarEdge.edge;
        const l = e === "left" ? bar : 0, r = e === "right" ? bar : 0;
        const t = e === "top" ? bar : 0, b = e === "bottom" ? bar : 0;
        root.cx = Math.max(l + h, Math.min(scr.width - r - h, x - scr.x));
        root.cy = Math.max(t + h, Math.min(scr.height - b - h - root.labelSpace, y - scr.y));
        root.win = /^[0-9]+$/.test(winId) ? winId : "0";
        root.hot = -1;
        root.shown = true;
    }

    function close() {
        root.shown = false;
    }

    onShownChanged: {
        // Awesome holds the keyboard for as long as the ring is up. Taken
        // here, once the ring has really opened, and dropped however it
        // closes (action, click, Escape) so it can never outlive the window.
        // The geometry goes with it so awesome can tell which entry the pointer
        // is over and report hover only when that changes.
        AwesomeState.exec(shown
            ? `ring_grab(); ring_geom(${Math.round(root.target.x + root.cx)}, `
              + `${Math.round(root.target.y + root.cy)}, ${root.items.length}, `
              + `${root.centerSize / 2 + 6}, ${root.ringRadius + root.buttonSize / 2 + 14})`
            : "ring_release()");
    }

    // Item under a global point: an index; -2 center; -1 nothing (outside
    // the ring, or on an entry that is greyed out).
    function entryAt(gx, gy) {
        if (!root.target)
            return -1;
        const dx = gx - root.target.x - root.cx;
        const dy = gy - root.target.y - root.cy;
        const d = Math.sqrt(dx * dx + dy * dy);
        if (d <= root.centerSize / 2 + 6)
            return -2;
        if (d > root.ringRadius + root.buttonSize / 2 + 14)
            return -1;
        const n = root.items.length;
        const step = 2 * Math.PI / n;
        // Angle clockwise from straight up.
        let ang = Math.atan2(dx, -dy);
        if (ang < 0)
            ang += 2 * Math.PI;
        const i = Math.round(ang / step) % n;
        return root.actionEnabled(root.items[i]) ? i : -1;
    }

    function activate(i) {
        if (i === -2) {
            root.close();
            return;
        }
        const a = root.items[i];
        if (!a || !root.actionEnabled(a))
            return;
        root.run(a.id);
    }

    function lua(code) {
        // The keyboard grab goes in the same call so it is dropped before
        // anything that takes the keyboard itself (the screenshot menu).
        AwesomeState.exec("ring_release(); " + code);
    }

    function windowAction(name) {
        root.lua(`ring_window_action("${name}", ${root.win})`);
    }

    // What each catalog id does. Everything here already exists elsewhere in
    // the shell or awesome; the ring only calls it.
    function run(id) {
        const a = RingActions.byId(id);
        if (!a || !root.actionEnabled(a))
            return;
        root.close();
        switch (id) {
        case "screenshot":
            AwesomeState.shortcutRun("misc.screenshot.menu.print");
            break;
        case "scratchpad":
            AwesomeState.shortcutRun("scratchpad.toggle");
            break;
        case "float":
        case "close":
        case "maximize":
        case "fullscreen":
        case "minimize":
        case "ontop":
            root.windowAction(id);
            break;
        case "overview":
            Quickshell.execDetached(["qs", "ipc", "call", "overview", "toggle"]);
            break;
        case "launcher":
            Quickshell.execDetached(["qs", "ipc", "call", "launcher", "toggle"]);
            break;
        case "lock":
            Quickshell.execDetached(["loginctl", "lock-session"]);
            break;
        case "perf":
            PerformanceMode.toggle();
            break;
        case "terminal":
            AwesomeState.shortcutRun("launcher.terminal");
            break;
        case "files":
            AwesomeState.shortcutRun("launcher.files");
            break;
        case "settings":
            Quickshell.execDetached(["qs", "ipc", "call", "settings", "toggle"]);
            break;
        case "power":
            AwesomeState.shortcutRun("awesome.power");
            break;
        case "clipboard":
            Quickshell.execDetached(["qs", "ipc", "call", "clipboard", "toggle"]);
            break;
        case "notifs":
            NotifHistory.toggleCenter();
            break;
        case "theme":
            Settings.darkMode = !Settings.darkMode;
            break;
        }
    }

    function handleKey(name) {
        const n = root.items.length;
        switch (name) {
        case "Escape":
            root.close();
            return;
        case "Left":
        case "Up":
            root.hot = root.hot < 0 ? n - 1 : (root.hot + n - 1) % n;
            return;
        case "Right":
        case "Down":
            root.hot = root.hot < 0 ? 0 : (root.hot + 1) % n;
            return;
        case "Return":
        case "KP_Enter":
            if (root.hot !== -1)
                root.activate(root.hot);
            return;
        }
        if (/^[1-9]$/.test(name) && Number(name) <= n)
            root.activate(Number(name) - 1);
    }

    IpcHandler {
        target: "ring"

        // x, y: pointer in global screen coordinates. win: X id of the
        // client under it, or 0. `qs ipc call ring open 800 400 0` by hand.
        function open(x: int, y: int, win: string): void {
            root.openAt(x, y, win);
        }

        function close(): void { root.close(); }

        function hover(x: int, y: int): void {
            if (root.shown)
                root.hot = root.entryAt(x, y);
        }

        // Button let go. Past the hold threshold that is a pick; before it,
        // a click, and the ring just stays up.
        function release(x: int, y: int, held: bool): void {
            if (!root.shown || !held)
                return;
            const i = root.entryAt(x, y);
            if (i >= 0)
                root.activate(i);
            else
                root.close();
        }

        function key(name: string): void {
            if (root.shown)
                root.handleKey(name);
        }

        // Test hook: run an action by catalog id as if clicked, with the
        // ring's current window target. Works only while the ring is open.
        function run(id: string): void {
            if (root.shown)
                root.run(id);
        }

        // One line of state, for tests: shown, screen, center, window, hot,
        // and the entries with a "-" on those that are greyed out.
        function status(): string {
            return (root.shown ? "shown" : "hidden")
                + " screen=" + (root.target ? root.target.name : "")
                + " center=" + Math.round(root.cx) + "," + Math.round(root.cy)
                + " win=" + root.win
                + " hot=" + root.hot
                + " items=" + root.items.map(a =>
                    (root.actionEnabled(a) ? "" : "-") + a.id).join(",");
        }
    }

    PanelWindow {
        id: panel

        screen: root.target ?? Quickshell.screens[0]
        visible: root.shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        anchors { top: true; bottom: true; left: true; right: true }

        // Click anywhere outside the ring: cancel.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.close()
        }

        Item {
            id: ring

            x: root.cx - root.half
            y: root.cy - root.half
            width: root.half * 2
            height: root.half * 2
            transformOrigin: Item.Center

            // 0 -> 1 on open. Not animated, it jumps straight to 1.
            property real shownT: 0
            opacity: shownT
            scale: 0.82 + 0.18 * shownT

            NumberAnimation {
                id: popIn
                target: ring
                property: "shownT"
                from: 0
                to: 1
                duration: root.lively ? 220 : 130
                easing.type: root.lively ? Easing.OutBack : Easing.OutCubic
            }

            Connections {
                target: root
                function onShownChanged() {
                    if (!root.shown)
                        return;
                    if (root.animated) {
                        ring.shownT = 0;
                        popIn.restart();
                    } else {
                        popIn.stop();
                        ring.shownT = 1;
                    }
                }
            }

            // Disc behind everything. Translucent rather than blurred:
            // picom leaves quickshell surfaces unblurred on purpose, so the
            // alpha is what lets the desktop show through.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.74)
                border.width: 1
                border.color: Theme.surfaceAlt

                // Swallow clicks on the disc between the buttons, so they
                // do not count as "outside".
                MouseArea { anchors.fill: parent }
            }

            // Center: close.
            Rectangle {
                id: centerButton
                width: root.centerSize
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: root.hot === -2 ? Theme.red : Theme.surface
                border.width: 1
                border.color: Theme.surfaceAlt

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: Theme.iconFont
                    font.pixelSize: 15
                    color: Theme.text
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.hot = -2
                    onExited: if (root.hot === -2) root.hot = -1
                    onClicked: root.close()
                }
            }

            Repeater {
                model: root.items

                Rectangle {
                    id: btn

                    required property var modelData
                    required property int index

                    readonly property bool usable: root.actionEnabled(modelData)
                    readonly property bool active: root.hot === index && usable
                    readonly property real angle:
                        index * 2 * Math.PI / root.items.length - Math.PI / 2

                    width: root.buttonSize
                    height: width
                    radius: width / 2
                    x: ring.width / 2 + root.ringRadius * Math.cos(angle) - width / 2
                    y: ring.height / 2 + root.ringRadius * Math.sin(angle) - height / 2
                    scale: active ? 1.14 : 1
                    opacity: usable ? 1 : 0.35
                    color: active ? RingActions.toneColor(modelData.tone)
                                  : Theme.surfaceAlt
                    border.width: 1
                    border.color: active ? Theme.text : Theme.subtext

                    Behavior on scale {
                        enabled: root.animated
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        enabled: root.animated
                        ColorAnimation { duration: 90 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: btn.modelData.glyph
                        font.family: Theme.iconFont
                        font.pixelSize: 22
                        color: btn.active ? Theme.base : Theme.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.hot = btn.index
                        onExited: if (root.hot === btn.index) root.hot = -1
                        onClicked: root.activate(btn.index)
                    }
                }
            }

            // Name of the highlighted entry, under the ring.
            Rectangle {
                readonly property var entry:
                    root.hot >= 0 ? root.items[root.hot] : null
                readonly property string label:
                    root.hot === -2 ? "Close"
                    : entry ? entry.label + (root.actionEnabled(entry) ? ""
                                                : " (needs a window)")
                    : ""

                visible: label !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height + 4
                width: labelText.implicitWidth + 20
                height: 26
                radius: height / 2
                color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.86)
                border.width: 1
                border.color: Theme.surfaceAlt

                Text {
                    id: labelText
                    anchors.centerIn: parent
                    text: parent.label
                    font.family: Theme.fontFamily
                    font.pointSize: 10
                    color: Theme.text
                }
            }
        }
    }
}
