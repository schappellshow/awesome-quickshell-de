import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Screenshot menu — `qs ipc call screenshot menu`, bound to Alt+Print
// (see modules/keys.lua). Region / Window / Screen / All screens captures,
// text recognition (OCR) and a colour picker, with an optional delay.
//
// All pixel work is done by bin/screenshot; this file is the interface:
//
//   idle ──menu()──▶ menu ──pick──▶ wait ──(countdown)──▶ settle ──▶ freeze
//                                                                      │
//        window / screen / all: `screenshot now` saves it, back to idle │
//        region / text / colour: ──▶ pick (overlays on a frozen grab) ◀─┘
//
// "settle" is the short pause after the menu (and the countdown pill) has
// been hidden, so the compositor has repainted without them before the grab:
// the menu must never be in its own screenshot. The grab is taken ONCE and
// the region / pixel is cut from that same image, so what you drag over is
// exactly what you get.
//
// Keyboard: quickshell's windows are override-redirect under X11, so they
// never receive key events. Awesome grabs the keyboard while the menu or
// the overlays are up and forwards keysyms to `key` below (the same
// arrangement as the power menu; see screenshot_grab in modules/keys.lua).
// During the countdown the grab is released on purpose — that time is for
// arranging whatever you are about to capture — and a click on the
// countdown pill cancels instead.
Scope {
    id: root

    property string phase: "idle"      // idle | menu | wait | settle | freeze | pick
    property int selected: 0
    property int delay: 0              // seconds, applies to region/window/screen/all
    property int remaining: 0
    property string mode: ""
    property string activeWin: ""      // X window id that had focus when the menu opened
    property string frozen: ""         // path of the frozen grab while picking
    property point pointer: Qt.point(0, 0)      // pointer, X screen coordinates
    property string menuScreen: ""     // output the menu card is drawn on

    // Selection while dragging (X screen coordinates).
    property bool dragging: false
    property point selA: Qt.point(0, 0)
    property point selB: Qt.point(0, 0)
    readonly property rect selection: Qt.rect(
        Math.min(selA.x, selB.x), Math.min(selA.y, selB.y),
        Math.abs(selA.x - selB.x), Math.abs(selA.y - selB.y))

    readonly property var delays: [0, 3, 5, 10]

    // key: single-press shortcut in the menu.
    readonly property var items: [
        { id: "region", label: "Region",       key: "r", color: Theme.blue,
          hint: "drag a rectangle" },
        { id: "window", label: "Window",       key: "w", color: Theme.teal,
          hint: "the window you were in" },
        { id: "screen", label: "Screen",       key: "s", color: Theme.gold,
          hint: "monitor under the pointer" },
        { id: "all",    label: "All screens",  key: "a", color: Theme.orange,
          hint: "every monitor" },
        { id: "ocr",    label: "Text (OCR)",   key: "t", color: Theme.purple,
          hint: "drag over text, copy it" },
        { id: "color",  label: "Color picker", key: "c", color: Theme.red,
          hint: "click any pixel" }
    ]

    // ── Keyboard ─────────────────────────────────────────────────────────
    function grabKeys(on) {
        Quickshell.execDetached(["awesome-client",
            on ? "screenshot_grab()" : "screenshot_release()"]);
    }

    function handleKey(name) {
        if (phase === "menu") {
            switch (name) {
            case "Escape":
                finish(); return;
            case "Up":
                selected = (selected + items.length - 1) % items.length; return;
            case "Down":
            case "Tab":
                selected = (selected + 1) % items.length; return;
            case "Left":
                delay = delays[(delays.indexOf(delay) + delays.length - 1) % delays.length]; return;
            case "Right":
            case "d":
                delay = delays[(delays.indexOf(delay) + 1) % delays.length]; return;
            case "Return":
            case "KP_Enter":
                begin(items[selected].id, delay); return;
            }
            for (const it of items) {
                if (it.key === name) { begin(it.id, delay); return; }
            }
        } else if (phase !== "idle" && name === "Escape") {
            finish();
        }
    }

    // ── Flow ─────────────────────────────────────────────────────────────
    function open() {
        if (phase !== "idle")
            finish();
        selected = 0;
        activeWin = "";
        winProbe.running = true;
        ptrProbe.running = true;
        phase = "menu";
        grabKeys(true);
    }

    // Back to idle from anywhere; releases the keyboard however we got here.
    function finish() {
        const wasIdle = phase === "idle";
        phase = "idle";
        dragging = false;
        countdown.stop();
        settle.stop();
        frozen = "";
        if (!wasIdle)
            grabKeys(false);
    }

    function needsPick(m) { return m === "region" || m === "ocr" || m === "color"; }

    function begin(m, secs) {
        mode = m;
        const d = (m === "ocr" || m === "color") ? 0 : secs;
        if (m === "window" && activeWin === "")
            winProbe.running = true;
        remaining = d;
        if (d > 0) {
            phase = "wait";
            grabKeys(false);            // free to arrange the scene
            countdown.restart();
        } else {
            phase = "settle";
            settle.restart();
        }
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.remaining -= 1;
            if (root.remaining <= 0) {
                stop();
                root.phase = "settle";      // pill goes away with the phase
                settle.restart();
            }
        }
    }

    // Long enough for picom to finish unmapping the menu / pill (its
    // fade-out included) before the grab; see the README note.
    Timer {
        id: settle
        interval: 450
        onTriggered: {
            root.phase = "freeze";
            if (root.needsPick(root.mode)) {
                freezer.running = true;
            } else {
                run(["screenshot", "now", root.mode, root.activeWin]);
                root.finish();
            }
        }
    }

    Process {
        id: freezer
        command: ["screenshot", "freeze"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.phase !== "freeze")
                    return;
                const p = text.trim();
                if (p === "") {
                    root.finish();
                    return;
                }
                root.frozen = p;
                root.dragging = false;
                root.selB = root.selA;
                root.phase = "pick";
                root.grabKeys(true);
            }
        }
    }

    Process {
        id: winProbe
        command: ["xdotool", "getactivewindow"]
        stdout: StdioCollector {
            onStreamFinished: root.activeWin = text.trim()
        }
    }

    // Pointer position, to put the menu on the monitor you are looking at.
    Process {
        id: ptrProbe
        command: ["xdotool", "getmouselocation", "--shell"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0) m[line.slice(0, i)] = parseInt(line.slice(i + 1));
                }
                const px = m.X || 0, py = m.Y || 0;
                root.pointer = Qt.point(px, py);
                let name = "";
                for (const s of Quickshell.screens) {
                    if (px >= s.x && px < s.x + s.width && py >= s.y && py < s.y + s.height)
                        name = s.name;
                }
                root.menuScreen = name !== "" ? name
                    : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
            }
        }
    }

    // Fire-and-forget: the result arrives as a notification.
    function run(cmd) { Quickshell.execDetached(cmd); }

    // The overlay reports the finished drag / click here.
    function pickDone(r, px, py) {
        const m = mode;
        finish();
        if (m === "color") {
            run(["screenshot", "color", String(Math.round(px)), String(Math.round(py))]);
        } else {
            const g = Math.round(r.width) + "x" + Math.round(r.height)
                + "+" + Math.round(r.x) + "+" + Math.round(r.y);
            run(["screenshot", m === "ocr" ? "ocr" : "save", g]);
        }
    }

    IpcHandler {
        target: "screenshot"

        function menu(): void { root.open(); }
        function close(): void { root.finish(); }

        // Keysym forwarded by awesome's keygrabber (see handleKey).
        function key(name: string): void { root.handleKey(name); }

        // Direct capture without the menu, for scripting and tests:
        //   qs ipc call screenshot capture region|window|screen|all|ocr|color [delay]
        function capture(what: string, secs: int): void {
            if (["region", "window", "screen", "all", "ocr", "color"].indexOf(what) < 0)
                return;
            if (root.phase !== "idle")
                root.finish();
            root.activeWin = "";
            winProbe.running = true;
            root.begin(what, secs);
        }

        function status(): string { return root.phase; }
    }

    // ── Menu ─────────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            visible: root.phase === "menu"
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors { top: true; bottom: true; left: true; right: true }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.35)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.finish()
                }

                Rectangle {
                    id: card
                    visible: win.modelData.name === root.menuScreen
                    anchors.centerIn: parent
                    width: 340
                    height: col.implicitHeight + 32
                    radius: Theme.radius
                    color: Theme.base
                    border.width: 1
                    border.color: Theme.surface

                    // Swallow clicks so they do not reach the backdrop.
                    MouseArea { anchors.fill: parent }

                    Column {
                        id: col
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 4

                        Text {
                            text: "Screenshot"
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pointSize: 11
                            color: Theme.text
                            bottomPadding: 6
                        }

                        Repeater {
                            model: root.items

                            Rectangle {
                                id: row
                                required property var modelData
                                required property int index
                                readonly property bool current: root.selected === index

                                width: col.width
                                height: 44
                                radius: 8
                                color: hover.hovered || current ? Theme.surface : "transparent"

                                Rectangle {
                                    id: badge
                                    x: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30; height: 30; radius: 15
                                    color: row.modelData.color
                                    Text {
                                        anchors.centerIn: parent
                                        text: row.modelData.key.toUpperCase()
                                        font.family: Theme.fontFamily
                                        font.bold: true
                                        font.pointSize: 10
                                        color: Theme.base
                                    }
                                }

                                Column {
                                    anchors.left: badge.right
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: row.modelData.label
                                        font.family: Theme.fontFamily
                                        font.pointSize: 10
                                        color: Theme.text
                                    }
                                    Text {
                                        text: row.modelData.hint
                                        font.family: Theme.fontFamily
                                        font.pointSize: 8
                                        color: Theme.muted
                                    }
                                }

                                HoverHandler {
                                    id: hover
                                    onHoveredChanged: if (hovered) root.selected = row.index
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.begin(row.modelData.id, root.delay)
                                }
                            }
                        }

                        // Delay chooser: Left/Right or D from the keyboard.
                        Item { width: 1; height: 6 }
                        Row {
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Delay"
                                font.family: Theme.fontFamily
                                font.pointSize: 9
                                color: Theme.muted
                                rightPadding: 6
                            }
                            Repeater {
                                model: root.delays

                                Rectangle {
                                    id: chip
                                    required property int modelData
                                    readonly property bool on: root.delay === modelData
                                    width: 52; height: 28; radius: 14
                                    color: on ? Theme.accent : (chipHover.hovered ? Theme.surface : "transparent")
                                    border.width: on ? 0 : 1
                                    border.color: Theme.surface

                                    Text {
                                        anchors.centerIn: parent
                                        text: chip.modelData === 0 ? "none" : chip.modelData + " s"
                                        font.family: Theme.fontFamily
                                        font.pointSize: 9
                                        color: chip.on ? Theme.base : Theme.text
                                    }
                                    HoverHandler { id: chipHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.delay = chip.modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Countdown pill ───────────────────────────────────────────────────
    // Our own rather than the volume OSD: that one lingers 1.5 s after its
    // last message, so it would be in the very capture it is counting down
    // to. This is hidden by the phase change, before the settle pause.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: pill
            required property var modelData

            screen: modelData
            visible: root.phase === "wait"
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors.bottom: true
            margins.bottom: 48
            implicitWidth: 300
            implicitHeight: 48

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.base
                border.width: 1
                border.color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "Capturing in " + root.remaining + " s   (click to cancel)"
                    font.family: Theme.fontFamily
                    font.pointSize: 10
                    color: Theme.text
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.finish()
                }
            }
        }
    }

    // ── Overlays on the frozen grab ──────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PickWindow {
            required property var modelData
            screen: modelData
            shot: root
        }
    }
}
