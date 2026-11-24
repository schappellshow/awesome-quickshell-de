import QtQuick
import Quickshell
import "../common"

// One screen's share of the pick overlay: the frozen grab, dimmed, with the
// drag rectangle (region / text) or the magnifier (colour) on top.
//
// The selection lives in Screenshot.qml in X screen coordinates and every
// window draws its part of it, so a drag can start on one monitor and end
// on another: the pointer stays grabbed by the window the press began in
// and keeps reporting positions, which map to global coordinates by adding
// this screen's origin.
PanelWindow {
    id: win

    required property var shot       // the Screenshot.qml root

    readonly property bool active: shot.phase === "pick"
    readonly property bool picking: shot.mode === "color"
    readonly property real ox: screen ? screen.x : 0
    readonly property real oy: screen ? screen.y : 0

    visible: active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    anchors { top: true; bottom: true; left: true; right: true }

    // The pixel under the pointer, read back through a 1x1 canvas so the
    // magnifier can show its value live without spawning a process per move.
    property string hover: ""

    Item {
        anchors.fill: parent
        clip: true

        Image {
            id: grab
            x: -win.ox
            y: -win.oy
            source: win.active && win.shot.frozen !== "" ? "file://" + win.shot.frozen : ""
            cache: false
            asynchronous: false
            smooth: false
        }

        // Dim everything outside the selection; plain dim for the picker.
        Rectangle {
            readonly property rect s: win.shot.selection
            readonly property bool has: !win.picking && (win.shot.dragging || s.width > 0)
            anchors.fill: parent
            color: "transparent"

            Rectangle {   // whole-screen dim when nothing is selected
                anchors.fill: parent
                visible: !parent.has
                color: Qt.rgba(0, 0, 0, win.picking ? 0.15 : 0.4)
            }
            // four slabs around the hole
            Rectangle { visible: parent.has; color: Qt.rgba(0, 0, 0, 0.5)
                x: 0; y: 0; width: parent.width; height: Math.max(0, parent.s.y - win.oy) }
            Rectangle { visible: parent.has; color: Qt.rgba(0, 0, 0, 0.5)
                x: 0; y: parent.s.y - win.oy + parent.s.height
                width: parent.width; height: Math.max(0, parent.height - y) }
            Rectangle { visible: parent.has; color: Qt.rgba(0, 0, 0, 0.5)
                x: 0; y: parent.s.y - win.oy
                width: Math.max(0, parent.s.x - win.ox); height: parent.s.height }
            Rectangle { visible: parent.has; color: Qt.rgba(0, 0, 0, 0.5)
                x: parent.s.x - win.ox + parent.s.width; y: parent.s.y - win.oy
                width: Math.max(0, parent.width - x); height: parent.s.height }

            Rectangle {   // the frame
                visible: parent.has
                x: parent.s.x - win.ox
                y: parent.s.y - win.oy
                width: parent.s.width
                height: parent.s.height
                color: "transparent"
                border.width: 1
                border.color: Theme.accentBright
            }

            Rectangle {   // size label
                readonly property bool show: parent.has && parent.s.width > 0
                visible: show
                x: Math.min(parent.width - width, Math.max(0, parent.s.x - win.ox))
                y: parent.s.y - win.oy > height + 4
                    ? parent.s.y - win.oy - height - 4
                    : parent.s.y - win.oy + 4
                width: sizeText.implicitWidth + 14
                height: sizeText.implicitHeight + 8
                radius: 6
                color: Theme.base
                Text {
                    id: sizeText
                    anchors.centerIn: parent
                    text: Math.round(win.shot.selection.width) + " × "
                        + Math.round(win.shot.selection.height)
                    font.family: Theme.fontFamily
                    font.pointSize: 9
                    color: Theme.text
                }
            }
        }

        // Instruction chip, on the screen the pointer is on.
        Rectangle {
            visible: !win.shot.dragging && win.shot.selection.width === 0
                && win.shot.pointer.x >= win.ox
                && win.shot.pointer.x < win.ox + win.width
            anchors.horizontalCenter: parent.horizontalCenter
            y: 24
            width: hint.implicitWidth + 24
            height: hint.implicitHeight + 14
            radius: Theme.radius
            color: Theme.base
            Text {
                id: hint
                anchors.centerIn: parent
                text: win.picking ? "Click a pixel · Esc to cancel"
                                  : "Drag to select, click a window · Esc to cancel"
                font.family: Theme.fontFamily
                font.pointSize: 10
                color: Theme.text
            }
        }

        // ── Magnifier (colour picker) ───────────────────────────────────
        Rectangle {
            id: mag
            readonly property int cells: 15       // source pixels across
            readonly property int zoom: 10
            readonly property real px: win.shot.pointer.x - win.ox
            readonly property real py: win.shot.pointer.y - win.oy
            visible: win.picking
                && px >= 0 && px < win.width && py >= 0 && py < win.height
            width: cells * zoom + 4
            height: width + 28
            x: px + 24 + width > win.width ? px - 24 - width : px + 24
            y: py + 24 + height > win.height ? py - 24 - height : py + 24
            radius: 8
            color: Theme.base
            border.width: 1
            border.color: Theme.surface

            Item {
                x: 2; y: 2
                width: mag.cells * mag.zoom
                height: width
                clip: true

                Image {
                    anchors.fill: parent
                    source: grab.source
                    cache: false
                    smooth: false
                    // Source pixels centred on the pointer, drawn at 10x.
                    sourceClipRect: Qt.rect(
                        Math.round(win.shot.pointer.x) - Math.floor(mag.cells / 2),
                        Math.round(win.shot.pointer.y) - Math.floor(mag.cells / 2),
                        mag.cells, mag.cells)
                    fillMode: Image.Stretch
                }
                Rectangle {   // the centre pixel
                    anchors.centerIn: parent
                    width: mag.zoom + 2; height: width
                    color: "transparent"
                    border.width: 1
                    border.color: "white"
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 1
                        color: "transparent"
                        border.width: 1
                        border.color: "black"
                    }
                }
            }
            Text {
                x: 8
                y: mag.cells * mag.zoom + 8
                text: win.hover !== "" ? win.hover : "…"
                font.family: Theme.fontFamily
                font.pointSize: 10
                color: Theme.text
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                y: mag.cells * mag.zoom + 8
                width: 16; height: 16; radius: 3
                color: win.hover !== "" ? win.hover : "transparent"
                border.width: 1
                border.color: Theme.muted
            }
        }

        // 1x1 canvas that copies the pixel under the pointer, for the hex.
        Canvas {
            id: probe
            width: 1; height: 1
            x: 0; y: 0
            opacity: 0.01
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Immediate
            property string src: grab.source
            onSrcChanged: if (src !== "") loadImage(src)
            onImageLoaded: requestPaint()
            property int sx: Math.round(win.shot.pointer.x)
            property int sy: Math.round(win.shot.pointer.y)
            onSxChanged: if (win.picking) requestPaint()
            onSyChanged: if (win.picking) requestPaint()
            onPaint: {
                if (!win.picking || src === "" || !isImageLoaded(src))
                    return;
                const c = getContext("2d");
                c.clearRect(0, 0, 1, 1);
                c.drawImage(src, sx, sy, 1, 1, 0, 0, 1, 1);
                const d = c.getImageData(0, 0, 1, 1).data;
                const h = v => (v < 16 ? "0" : "") + v.toString(16);
                win.hover = "#" + h(d[0]) + h(d[1]) + h(d[2]);
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.CrossCursor

            function global(m) { return Qt.point(m.x + win.ox, m.y + win.oy); }

            onPositionChanged: m => {
                const g = global(m);
                win.shot.pointer = g;
                if (win.shot.dragging)
                    win.shot.selB = g;
            }
            onPressed: m => {
                if (m.button === Qt.RightButton) {
                    win.shot.finish();
                    return;
                }
                const g = global(m);
                win.shot.pointer = g;
                if (!win.picking) {
                    win.shot.selA = g;
                    win.shot.selB = g;
                    win.shot.dragging = true;
                }
            }
            onReleased: m => {
                if (m.button !== Qt.LeftButton)
                    return;
                const g = global(m);
                if (win.picking) {
                    win.shot.pickDone(Qt.rect(0, 0, 0, 0), g.x, g.y);
                } else if (win.shot.dragging) {
                    win.shot.selB = g;
                    win.shot.dragging = false;
                    const r = win.shot.selection;
                    if (r.width >= 3 && r.height >= 3)
                        win.shot.pickDone(r, 0, 0);
                    else {
                        win.shot.selB = win.shot.selA;   // a click, not a drag:
                        win.shot.clickPick(g.x, g.y);    // take the window under it
                    }
                }
            }
        }
    }
}
