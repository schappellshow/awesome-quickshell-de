import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "EditorShapes.js" as Shapes

// Screenshot annotation editor. Opened by Screenshot.qml after a capture
// (`edit` below), or on any PNG with `qs ipc call shoteditor open <path>`.
//
// Everything is drawn in IMAGE pixels inside `scene`, which `view` scales to
// fit the window. Saving grabs `scene` itself at its natural size, so the
// file is the original resolution with the annotations burned in, whatever
// the zoom was; the screen is never the source of the saved pixels.
//
// Undo is a stack of snapshots of the shape list (small: a shape is a few
// numbers), which also makes delete and redo trivial.
//
// It is an ordinary window, unlike the menu and overlays, so it gets keys
// directly; awesome floats, centers and focuses it (rules.lua).
FloatingWindow {
    id: win

    title: "Screenshot Editor"
    visible: false
    color: Theme.base

    // ── Document ─────────────────────────────────────────────────────────
    property string source: ""
    // Natural size of the picture. Plain properties set from the image's
    // status rather than bindings to its implicit size, which loop (the
    // scene is sized from them and the image sits in the scene).
    property int imgW: 0
    property int imgH: 0
    property var shapes: []
    property var undoStack: []
    property var redoStack: []
    property int selected: -1          // index into shapes, -1 = none
    property int rev: 0                // bumped by every change
    property int cleanRev: 0           // rev at the last save / copy
    readonly property bool dirty: shapes.length > 0 && rev !== cleanRev
    property string status: ""
    property bool confirmClose: false

    // ── Tool state ───────────────────────────────────────────────────────
    property string tool: "arrow"
    property color penColor: Theme.red
    property int penWidth: 6
    property var draft: null           // the shape being dragged out
    property bool typing: false        // a text label is being entered
    property point typingAt: Qt.point(0, 0)

    readonly property var tools: [
        { id: "select", label: "Select",    key: "v" },
        { id: "arrow",  label: "Arrow",     key: "a" },
        { id: "rect",   label: "Rectangle", key: "r" },
        { id: "pen",    label: "Pen",       key: "p" },
        { id: "hi",     label: "Highlight", key: "h" },
        { id: "text",   label: "Text",      key: "t" },
        { id: "pix",    label: "Redact",    key: "b" }
    ]
    readonly property var widths: [3, 6, 10]
    readonly property var colors: [Theme.red, Theme.orange, Theme.gold, Theme.green,
                                   Theme.accent, "#ffffff", "#000000"]

    // Fit: never enlarge past 100%, shrink to what the window leaves.
    readonly property real zoom: imgW > 0
        ? Math.min(1, (stage.width - 24) / imgW, (stage.height - 24) / imgH) : 1

    // ── Opening ──────────────────────────────────────────────────────────
    // Sized to the image where it fits on the screen the pointer is on.
    function edit(path) {
        pendingPath = path;
        ptr.running = true;
    }
    property string pendingPath: ""

    function show(path, scr) {
        shapes = []; undoStack = []; redoStack = [];
        selected = -1; draft = null; typing = false; confirmClose = false;
        rev = 0; cleanRev = 0; status = "";
        imgW = 0; imgH = 0;
        // Drop the old picture first: assigning a path equal to the current
        // one is no change, so a still-open editor would keep the old image.
        source = "";
        source = path;
        const probe = Qt.createQmlObject('import QtQuick; Image { cache: false; visible: false }', win);
        probe.statusChanged.connect(() => {
            if (probe.status === Image.Ready) {
                const maxW = scr.width * 0.9, maxH = scr.height * 0.88;
                const z = Math.min(1, (maxW - 24) / probe.implicitWidth,
                                      (maxH - 24 - chrome) / probe.implicitHeight);
                implicitWidth = Math.max(820, Math.round(probe.implicitWidth * z) + 24);
                implicitHeight = Math.max(420, Math.round(probe.implicitHeight * z) + 24 + chrome);
                imgW = probe.implicitWidth; imgH = probe.implicitHeight;
                visible = true;
                probe.destroy();
            } else if (probe.status === Image.Error) {
                status = "Could not open " + path;
                probe.destroy();
            }
        });
        probe.source = "file://" + path;
        keys.forceActiveFocus();
    }
    readonly property int chrome: 52 + 44      // toolbar + bottom bar

    Process {
        id: ptr
        command: ["xdotool", "getmouselocation", "--shell"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0) m[line.slice(0, i)] = parseInt(line.slice(i + 1));
                }
                let scr = Quickshell.screens.length > 0 ? Quickshell.screens[0] : { width: 1920, height: 1080 };
                for (const s of Quickshell.screens)
                    if ((m.X || 0) >= s.x && (m.X || 0) < s.x + s.width
                        && (m.Y || 0) >= s.y && (m.Y || 0) < s.y + s.height)
                        scr = s;
                win.show(win.pendingPath, scr);
            }
        }
    }

    // ── History ──────────────────────────────────────────────────────────
    function push(next) {
        undoStack = undoStack.concat([shapes]);
        redoStack = [];
        shapes = next;
        rev++;
    }

    function addShape(s) {
        push(shapes.concat([s]));
        selected = shapes.length - 1;
    }

    function undo() {
        if (typing) { typing = false; return; }
        if (undoStack.length === 0) return;
        redoStack = redoStack.concat([shapes]);
        shapes = undoStack[undoStack.length - 1];
        undoStack = undoStack.slice(0, -1);
        selected = -1;
        rev++;
    }

    function redo() {
        if (redoStack.length === 0) return;
        undoStack = undoStack.concat([shapes]);
        shapes = redoStack[redoStack.length - 1];
        redoStack = redoStack.slice(0, -1);
        selected = -1;
        rev++;
    }

    function deleteSelected() {
        if (selected < 0 || selected >= shapes.length) return;
        const next = shapes.slice();
        next.splice(selected, 1);
        push(next);
        selected = -1;
    }

    // ── Drawing ──────────────────────────────────────────────────────────
    function beginDraft(t, x, y) {
        const c = penColor.toString();
        if (t === "pen" || t === "hi")
            draft = { t: t, c: c, w: penWidth, pts: [[x, y]] };
        else
            draft = { t: t, c: c, w: penWidth, x1: x, y1: y, x2: x, y2: y };
    }

    function updateDraft(x, y) {
        if (!draft) return;
        const d = Object.assign({}, draft);
        if (d.pts) {
            const last = d.pts[d.pts.length - 1];
            if (Math.hypot(x - last[0], y - last[1]) < 1.5) return;
            d.pts = d.pts.concat([[x, y]]);
        } else {
            d.x2 = x; d.y2 = y;
        }
        draft = d;
    }

    function commitDraft() {
        const d = draft;
        draft = null;
        if (!d) return;
        if (d.pts) {
            addShape(d);
        } else {
            if (Math.hypot(d.x2 - d.x1, d.y2 - d.y1) < 3) return;   // a click, not a drag
            addShape(d.t === "pix" ? Shapes.clampBox(d, imgW, imgH) : d);
        }
    }

    // Text: a TextEdit sits on the image at the click until Enter / focus
    // loss commits it or Escape drops it.
    function beginText(x, y) {
        typingAt = Qt.point(x, y);
        editBox.text = "";
        typing = true;
        editBox.forceActiveFocus();
    }

    function commitText() {
        if (!typing) return;
        typing = false;
        keys.forceActiveFocus();
        const t = editBox.text.replace(/\s+$/, "");
        if (t !== "")
            placeText(typingAt.x, typingAt.y, t);
    }

    function placeText(x, y, t) {
        measurer.text = t;
        measurer.font.pixelSize = Shapes.fontPx(penWidth);
        addShape({ t: "text", c: penColor.toString(), w: penWidth, x: x, y: y,
                   text: t, bw: Math.ceil(measurer.implicitWidth),
                   bh: Math.ceil(measurer.implicitHeight) });
    }

    // ── Output ───────────────────────────────────────────────────────────
    // Grab the scene at its natural size. The selection outline and the live
    // text box are not part of the picture; hide them for the grab.
    property bool exporting: false

    function exportTo(path, done) {
        if (imgW === 0) { done(false); return; }
        exporting = true;
        // One frame for the hidden overlays to leave the scene.
        Qt.callLater(() => scene.grabToImage(r => {
            const ok = r.saveToFile(path);
            exporting = false;
            done(ok);
        }, Qt.size(imgW, imgH)));
    }

    readonly property string tmpCopy: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/screenshot/edit-copy.png"

    function copy() {
        commitText();
        exportTo(tmpCopy, ok => {
            if (!ok) { status = "Copy failed"; return; }
            Quickshell.execDetached(["screenshot", "copy", tmpCopy]);
            cleanRev = rev;
            status = "Copied to the clipboard";
        });
    }

    function save() {
        commitText();
        namer.running = true;
    }

    function saveAs() {
        commitText();
        chooser.running = true;
    }

    function writeTo(path) {
        exportTo(path, ok => {
            if (!ok) { status = "Could not save " + path; return; }
            Quickshell.execDetached(["screenshot", "saved", path]);
            cleanRev = rev;
            status = "Saved " + path.replace(Quickshell.env("HOME"), "~");
            lastSaved = path;
            if (closeAfterSave) closeNow();
        });
    }
    property string lastSaved: ""
    property bool closeAfterSave: false

    Process {
        id: namer
        command: ["screenshot", "newpath"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "") win.writeTo(text.trim())
        }
    }

    Process {
        id: chooser
        command: ["screenshot", "pickpath"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim();
                if (p === "") return;
                if (!/\.png$/i.test(p)) p += ".png";
                win.writeTo(p);
            }
        }
    }

    // ── Closing ──────────────────────────────────────────────────────────
    function requestClose() {
        if (typing) { typing = false; keys.forceActiveFocus(); return; }
        if (draft) { draft = null; return; }
        if (dirty && !confirmClose) { confirmClose = true; return; }
        closeNow();
    }

    function closeNow() {
        closeAfterSave = false;
        visible = false;
        confirmClose = false;
        typing = false;
        draft = null;
        source = "";
    }

    onRevChanged: status = ""
    onVisibleChanged: if (!visible) { typing = false; confirmClose = false; }

    // ── Test hooks (also useful for scripting) ───────────────────────────
    IpcHandler {
        target: "shoteditor"

        // Open the editor on a PNG.
        function open(path: string): void { win.edit(path); }
        // Open without probing the pointer (tests: size to a given screen).
        function close(): void { win.closeNow(); }
        // Draw through the same path the mouse uses:
        //   drag <tool> <x1> <y1> <x2> <y2> [color] [width]   in image pixels
        function drag(tool: string, x1: real, y1: real, x2: real, y2: real,
                      color: string, width: int): void {
            if (color !== "") win.penColor = color;
            if (width > 0) win.penWidth = width;
            win.beginDraft(tool, x1, y1);
            if (tool === "pen" || tool === "hi") {
                for (let i = 1; i <= 12; i++)
                    win.updateDraft(x1 + (x2 - x1) * i / 12,
                                    y1 + (y2 - y1) * i / 12 + Math.sin(i) * 12);
            } else {
                win.updateDraft(x2, y2);
            }
            win.commitDraft();
        }
        function text(x: real, y: real, t: string, color: string, width: int): void {
            if (color !== "") win.penColor = color;
            if (width > 0) win.penWidth = width;
            win.placeText(x, y, t);
        }
        // Start typing a label at a point, as a click with the Text tool does;
        // the keyboard (xdotool in the nested session) does the rest.
        function beginText(x: real, y: real): void { win.beginText(x, y); }
        function undo(): void { win.undo(); }
        function redo(): void { win.redo(); }
        function remove(index: int): void { win.selected = index; win.deleteSelected(); }
        function copy(): void { win.copy(); }
        function save(): void { win.save(); }
        // Write the annotated image to a path; the reply is the path once
        // written, "failed" otherwise (checked with `status`).
        function exportPng(path: string): void {
            win.exportTo(path, ok => { win.status = ok ? "exported " + path : "export failed"; });
        }
        function status(): string {
            return JSON.stringify({ visible: win.visible, source: win.source,
                w: win.imgW, h: win.imgH, zoom: win.zoom, shapes: win.shapes.length,
                dirty: win.dirty, selected: win.selected, status: win.status,
                kinds: win.shapes.map(s => s.t) });
        }
    }

    // ── UI ───────────────────────────────────────────────────────────────
    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (win.typing) return;
            const ctrl = event.modifiers & Qt.ControlModifier;
            const shift = event.modifiers & Qt.ShiftModifier;
            event.accepted = true;
            if (ctrl && event.key === Qt.Key_Z) { shift ? win.redo() : win.undo(); }
            else if (ctrl && event.key === Qt.Key_Y) win.redo();
            else if (ctrl && event.key === Qt.Key_C) win.copy();
            else if (ctrl && event.key === Qt.Key_S) { shift ? win.saveAs() : win.save(); }
            else if (event.key === Qt.Key_Escape) win.requestClose();
            else if (event.key === Qt.Key_Delete || event.key === Qt.Key_BackSpace) win.deleteSelected();
            else if (!ctrl) {
                let hit = false;
                for (const t of win.tools)
                    if (event.text.toLowerCase() === t.key) { win.tool = t.id; hit = true; }
                if (!hit) event.accepted = false;
            } else event.accepted = false;
        }

        // ── Toolbar ──────────────────────────────────────────────────────
        Rectangle {
            id: toolbar
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 52
            color: Theme.surface

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 4

                Repeater {
                    model: win.tools
                    EditorButton {
                        required property var modelData
                        label: modelData.label
                        active: win.tool === modelData.id
                        onClicked: { win.commitText(); win.tool = modelData.id; }
                    }
                }

                Item { width: 10; height: 1 }

                Repeater {
                    model: win.colors
                    EditorButton {
                        required property var modelData
                        isSwatch: true
                        swatch: modelData
                        anchors.verticalCenter: parent.verticalCenter
                        active: Qt.colorEqual(win.penColor, modelData)
                        onClicked: win.penColor = modelData
                    }
                }

                Item { width: 10; height: 1 }

                Repeater {
                    model: win.widths
                    EditorButton {
                        required property int modelData
                        required property int index
                        label: ["S", "M", "L"][index]
                        active: win.penWidth === modelData
                        onClicked: win.penWidth = modelData
                    }
                }

                Item { width: 10; height: 1 }

                EditorButton { label: "Undo"; enabled: win.undoStack.length > 0; onClicked: win.undo() }
                EditorButton { label: "Redo"; enabled: win.redoStack.length > 0; onClicked: win.redo() }
            }
        }

        // ── Canvas area ──────────────────────────────────────────────────
        Item {
            id: stage
            anchors { left: parent.left; right: parent.right; top: toolbar.bottom; bottom: bottomBar.top }
            clip: true

            Rectangle { anchors.fill: parent; color: Qt.darker(Theme.base, 1.25) }

            Item {
                id: view
                width: win.imgW
                height: win.imgH
                scale: win.zoom
                transformOrigin: Item.TopLeft
                x: Math.round((stage.width - win.imgW * win.zoom) / 2)
                y: Math.round((stage.height - win.imgH * win.zoom) / 2)

                // The picture. Everything in here is what gets exported.
                Item {
                    id: scene
                    width: win.imgW
                    height: win.imgH

                    Image {
                        id: img
                        source: win.source !== "" ? "file://" + win.source : ""
                        cache: false
                        onStatusChanged: {
                            if (status === Image.Ready) {
                                win.imgW = implicitWidth;
                                win.imgH = implicitHeight;
                            }
                        }
                        smooth: win.zoom < 1
                        mipmap: win.zoom < 1
                    }

                    Repeater {
                        model: win.shapes
                        EditorShape {
                            required property var modelData
                            shape: modelData
                            image: img
                        }
                    }

                    EditorShape { shape: win.draft; image: img }

                    // Selection outline (not exported).
                    Rectangle {
                        readonly property var s: win.selected >= 0 && win.selected < win.shapes.length
                            ? win.shapes[win.selected] : null
                        readonly property var b: s ? Shapes.bounds(s) : ({ x: 0, y: 0, w: 0, h: 0 })
                        readonly property real m: 4 + (s ? Shapes.pad(s) : 0)
                        visible: s !== null && !win.exporting
                        x: b.x - m; y: b.y - m
                        width: b.w + 2 * m; height: b.h + 2 * m
                        color: "transparent"
                        border.width: Math.max(1, 2 / win.zoom)
                        border.color: Theme.accentBright
                    }

                    // Live text entry (not exported until committed).
                    TextEdit {
                        id: editBox
                        visible: win.typing && !win.exporting
                        x: win.typingAt.x
                        y: win.typingAt.y
                        color: win.penColor
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Shapes.fontPx(win.penWidth)
                        selectByMouse: true
                        onActiveFocusChanged: if (!activeFocus && win.typing) win.commitText()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                win.typing = false;
                                keys.forceActiveFocus();
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                       && !(event.modifiers & Qt.ShiftModifier)) {
                                win.commitText();
                                event.accepted = true;
                            }
                        }
                        Rectangle {
                            z: -1
                            anchors.fill: parent
                            anchors.margins: -4
                            color: "transparent"
                            border.width: Math.max(1, 1 / win.zoom)
                            border.color: Theme.accentBright
                        }
                    }
                }

                Text {
                    id: measurer
                    visible: false
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: scene
                    acceptedButtons: Qt.LeftButton
                    cursorShape: win.tool === "select" ? Qt.ArrowCursor
                               : win.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor

                    onPressed: m => {
                        win.confirmClose = false;
                        if (win.typing) win.commitText();
                        if (win.tool === "select")
                            win.selected = Shapes.pick(win.shapes, m.x, m.y, 4 / win.zoom);
                        else if (win.tool === "text")
                            win.beginText(m.x, m.y);
                        else
                            win.beginDraft(win.tool, m.x, m.y);
                    }
                    onPositionChanged: m => win.updateDraft(m.x, m.y)
                    onReleased: win.commitDraft()
                }
            }

            // Unsaved-annotations prompt.
            Rectangle {
                visible: win.confirmClose
                anchors.centerIn: parent
                width: promptRow.implicitWidth + 40
                height: 64
                radius: Theme.radius
                color: Theme.base
                border.width: 1
                border.color: Theme.accent
                Row {
                    id: promptRow
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Discard your annotations?"
                        font.family: Theme.fontFamily
                        font.pointSize: 10
                        color: Theme.text
                    }
                    EditorButton { label: "Discard"; onClicked: win.closeNow() }
                    EditorButton { label: "Save & close"; onClicked: { win.closeAfterSave = true; win.save(); win.confirmClose = false; } }
                    EditorButton { label: "Keep editing"; onClicked: win.confirmClose = false }
                }
            }
        }

        // ── Bottom bar ───────────────────────────────────────────────────
        Rectangle {
            id: bottomBar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 44
            color: Theme.surface

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: actions.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideMiddle
                text: win.status !== "" ? win.status
                    : win.imgW + " × " + win.imgH + "  ·  " + Math.round(win.zoom * 100) + "%"
                      + (win.dirty ? "  ·  unsaved annotations" : "")
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: Theme.subtext
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                EditorButton { label: "Copy"; hint: "Ctrl+C"; onClicked: win.copy() }
                EditorButton { label: "Save"; hint: "Ctrl+S"; onClicked: win.save() }
                EditorButton { label: "Save as…"; hint: "Ctrl+Shift+S"; onClicked: win.saveAs() }
                EditorButton { label: "Close"; hint: "Esc"; onClicked: win.requestClose() }
            }
        }
    }
}
