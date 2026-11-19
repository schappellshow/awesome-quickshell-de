import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../bar"

// Workspace overview: `qs ipc call overview toggle` (Super+Tab).
//
// On every monitor, that monitor's tags drawn as scaled-down screens side by
// side, with each window as a rounded box at its real position and size.
// There are no live thumbnails and there cannot be: windows on hidden tags
// are unmapped on X11, so there is nothing to capture. A box carries the
// app's icon and the title instead.
//
//   click a window        close, focus it
//   click empty tag area  view that tag, close
//   drag a window         drop on any tag, on any monitor: move it there
//   type                  windows that do not match dim; Enter focuses the
//                         first match; arrows move between matches
//   Escape / Super+Tab / click outside the tags
//                         close
//
// Awesome is the source of truth: window geometry is the last-known one from
// the bridge's allClients, and every action goes back through awesome-client
// (shell_focus_client, shell_view_tag, shell_move_client).
//
// Keyboard: the same focusable-dock approach as the launcher, on the screen
// that had focus when the overview opened. The search box exists on every
// monitor (so the query reads the same everywhere) but only that screen's
// one takes input.
//
// Dragging is hand-rolled rather than Qt drag-and-drop because the drop
// target may be on another monitor, i.e. in another window. A button press
// keeps delivering pointer events to the window it started in even when the
// pointer leaves it, so each panel just reports the pointer in GLOBAL
// coordinates and every tag tests itself against that.
Scope {
    id: root

    property bool shown: false
    property string activeOutput: ""

    // Window list. A snapshot that follows AwesomeState while idle but is
    // frozen during a drag: a state update rebuilds every box, and the one
    // under the pointer must not be destroyed mid-gesture.
    property var windows: []
    property bool dragging: false

    property string query: ""
    property bool navigated: false
    property int sel: 0

    property int dragId: -1
    property real dragGx: 0
    property real dragGy: 0

    readonly property var live: AwesomeState.allClients
    onLiveChanged: if (!root.dragging) root.refresh()

    function refresh() {
        root.windows = root.live.filter(c => !c.scratchpad);
    }

    function open() {
        root.refresh();
        root.query = "";
        root.navigated = false;
        root.sel = 0;
        const name = AwesomeState.focusedOutput;
        root.activeOutput =
            (Quickshell.screens.find(s => s.name === name)
                ?? Quickshell.screens.find(s => s.name === Settings.barScreen)
                ?? Quickshell.screens[0])?.name ?? "";
        root.shown = true;
    }

    function close() {
        root.shown = false;
        root.dragging = false;
        root.dragId = -1;
    }

    // ── Search ───────────────────────────────────────────────────────────

    function matches(w) {
        const words = root.query.toLowerCase().split(/\s+/).filter(x => x !== "");
        if (words.length === 0)
            return true;
        const hay = (w.name + "\n" + w.class + "\n" + w.instance).toLowerCase();
        return words.every(x => hay.includes(x));
    }

    // Most recently used first, so "the first match" is the one you most
    // likely mean.
    readonly property var matched: root.windows
        .filter(w => root.matches(w))
        .sort((a, b) => a.focusRank - b.focusRank)

    readonly property int selectedId:
        (root.query !== "" || root.navigated) && root.matched.length > 0
            ? root.matched[Math.max(0, Math.min(root.sel, root.matched.length - 1))].id
            : -1

    function step(delta) {
        const n = root.matched.length;
        if (n === 0)
            return;
        root.navigated = true;
        root.sel = (root.sel + delta + n) % n;
    }

    function acceptSelected() {
        if (root.query === "" && !root.navigated)
            return;
        const id = root.selectedId;
        if (id < 0)
            return;
        root.focusWindow(id);
    }

    function focusWindow(id) {
        root.close();
        AwesomeState.shellFocusClient(id);
    }

    // ── Geometry ─────────────────────────────────────────────────────────

    // Where the tags sit inside a panel of W x H showing n of them: one row,
    // each tag the screen's own shape, centred. Pure function of the screen
    // size so a drop can be hit-tested against another monitor's layout.
    function layout(W, H, n) {
        const margin = 80, gap = 28, top = 90;
        const aspect = W / H;
        const count = Math.max(1, n);
        let tw = (W - 2 * margin - gap * (count - 1)) / count;
        let th = tw / aspect;
        const maxH = H - top - margin;
        if (th > maxH) {
            th = maxH;
            tw = th * aspect;
        }
        const total = tw * count + gap * (count - 1);
        return { tw: tw, th: th, gap: gap,
                 x0: (W - total) / 2, y0: top + (maxH - th) / 2 };
    }

    function tagRect(qs, awScr, tagIdx) {
        const L = root.layout(qs.width, qs.height, awScr.tags.length);
        return { x: qs.x + L.x0 + (tagIdx - 1) * (L.tw + L.gap),
                 y: qs.y + L.y0, w: L.tw, h: L.th };
    }

    // Window boxes for one tag, in the SCREEN's own pixel coordinates.
    // Geometry that cannot be drawn honestly (nothing there, never shown, or
    // mostly outside its screen — e.g. last seen on a monitor since
    // unplugged) is replaced by a cascade of half-screen boxes so the window
    // still has a place to be clicked.
    function boxesFor(qs, awScr, tagIdx) {
        const out = [];
        let fallbacks = 0;
        const list = root.windows
            .filter(w => w.screen === awScr.index && (w.tags || []).includes(tagIdx))
            // Stacking approximation: the focused window on top, then MRU.
            .sort((a, b) => b.focusRank - a.focusRank);
        for (const w of list) {
            let x = w.x - qs.x, y = w.y - qs.y, bw = w.width, bh = w.height;
            const ix = Math.max(0, Math.min(x + bw, qs.width) - Math.max(x, 0));
            const iy = Math.max(0, Math.min(y + bh, qs.height) - Math.max(y, 0));
            const usable = bw >= 20 && bh >= 20 && ix * iy >= 0.5 * bw * bh;
            if (!usable) {
                bw = qs.width * 0.5;
                bh = qs.height * 0.5;
                x = qs.width * 0.08 + fallbacks * qs.width * 0.05;
                y = qs.height * 0.08 + fallbacks * qs.height * 0.06;
                fallbacks += 1;
            }
            // Keep a partly off-screen window inside its tag.
            x = Math.max(0, Math.min(x, qs.width - bw));
            y = Math.max(0, Math.min(y, qs.height - bh));
            out.push({ w: w, x: x, y: y, bw: bw, bh: bh });
        }
        return out;
    }

    // Drop: find the tag under the pointer on any monitor and move there.
    function drop(id, gx, gy) {
        for (const qs of Quickshell.screens) {
            const aw = AwesomeState.forOutput(qs.name);
            if (!aw)
                continue;
            for (const t of aw.tags) {
                const r = root.tagRect(qs, aw, t.index);
                if (gx >= r.x && gx < r.x + r.w && gy >= r.y && gy < r.y + r.h) {
                    root.moveWindow(id, aw.index, t.index);
                    return;
                }
            }
        }
    }

    function moveWindow(id, screenIndex, tagIndex) {
        AwesomeState.shellMoveClient(id, screenIndex, tagIndex);
        // Show it at once; the bridge's confirmation replaces this a moment
        // later. Geometry is left as it was — if that is on another screen,
        // boxesFor() falls back to a cascade slot.
        root.windows = root.windows.map(w => w.id !== id ? w : Object.assign(
            {}, w, { screen: screenIndex, tags: [tagIndex] }));
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            if (root.shown)
                root.close();
            else
                root.open();
        }

        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            readonly property var aw: AwesomeState.forOutput(modelData.name)
            readonly property bool active: modelData.name === root.activeOutput

            screen: modelData
            visible: root.shown
            color: "transparent"
            focusable: true
            aboveWindows: true
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }

            readonly property var lay: root.layout(win.width, win.height,
                win.aw ? win.aw.tags.length : 1)

            onVisibleChanged: {
                if (visible && win.active) {
                    searchInput.text = "";
                    searchInput.forceActiveFocus();
                    focusTick.tries = 0;
                    focusTick.restart();
                }
            }

            // As in the launcher: the dock surface has to be focused by
            // awesome itself, a few tries to cover a slow map.
            Timer {
                id: focusTick
                property int tries: 0
                interval: 80
                repeat: true
                onTriggered: {
                    AwesomeState.focusOwnDock(win.modelData.x, win.modelData.y,
                        win.modelData.width, win.modelData.height);
                    tries += 1;
                    if (tries >= 3)
                        stop();
                }
            }

            // Backdrop; a click here is "outside the tags" and closes.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.6)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            // Search box (typing target on the active screen, a mirror of
            // the query elsewhere).
            Rectangle {
                id: searchBox
                anchors.horizontalCenter: parent.horizontalCenter
                y: 28
                width: 360
                height: 34
                radius: 8
                color: Theme.base
                border.width: 1
                border.color: win.active ? Theme.accent : Theme.surfaceAlt

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pointSize: 11
                    color: Theme.text
                    clip: true
                    enabled: win.active
                    visible: win.active
                    focus: win.active

                    onTextChanged: {
                        if (win.active) {
                            root.query = text;
                            root.sel = 0;
                        }
                    }
                    Keys.onEscapePressed: root.close()
                    Keys.onLeftPressed: root.step(-1)
                    Keys.onUpPressed: root.step(-1)
                    Keys.onRightPressed: root.step(1)
                    Keys.onDownPressed: root.step(1)
                    onAccepted: root.acceptSelected()
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    visible: !win.active || searchInput.text === ""
                    text: win.active ? "Type to find a window…" : root.query
                    font.family: Theme.fontFamily
                    font.pointSize: 11
                    color: win.active ? Theme.muted : Theme.text
                }
            }

            Repeater {
                model: win.aw ? win.aw.tags : []

                Item {
                    id: tagItem

                    required property var modelData
                    readonly property int tagIndex: modelData.index

                    readonly property real scale: win.lay.tw / win.width

                    x: win.lay.x0 + (tagIndex - 1) * (win.lay.tw + win.lay.gap)
                    y: win.lay.y0
                    width: win.lay.tw
                    height: win.lay.th

                    readonly property bool dropTarget: root.dragging
                        && root.dragGx >= win.modelData.x + x
                        && root.dragGx < win.modelData.x + x + width
                        && root.dragGy >= win.modelData.y + y
                        && root.dragGy < win.modelData.y + y + height

                    readonly property var boxes:
                        root.boxesFor(win.modelData, win.aw, tagIndex)

                    // The tag's screen.
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: tagItem.dropTarget ? Theme.surface : Theme.base
                        border.width: tagItem.dropTarget ? 3
                                    : tagItem.modelData.selected ? 2 : 1
                        border.color: tagItem.dropTarget ? Theme.accentBright
                                    : tagItem.modelData.selected ? Theme.accent
                                    : Theme.surface
                        clip: true

                        // Empty area: view this tag.
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.close();
                                AwesomeState.shellViewTag(win.aw.index, tagItem.tagIndex);
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 6
                        text: tagItem.modelData.name
                        font.family: Theme.fontFamily
                        font.pointSize: 10
                        font.bold: tagItem.modelData.selected
                        color: tagItem.modelData.selected ? Theme.accentBright : Theme.subtext
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: tagItem.boxes.length === 0
                        text: "empty"
                        font.family: Theme.fontFamily
                        font.pointSize: 9
                        color: Theme.muted
                    }

                    Repeater {
                        model: tagItem.boxes

                        Rectangle {
                            id: box

                            required property var modelData
                            readonly property var w: modelData.w

                            readonly property bool isMatch: root.matches(w)
                            readonly property bool isSelected: root.selectedId === w.id
                            readonly property bool beingDragged:
                                root.dragging && root.dragId === w.id

                            x: modelData.x * tagItem.scale
                            y: modelData.y * tagItem.scale
                            width: Math.max(14, modelData.bw * tagItem.scale)
                            height: Math.max(14, modelData.bh * tagItem.scale)
                            radius: 5
                            color: Theme.surfaceAlt
                            border.width: isSelected ? 3 : (w.focused || w.urgent) ? 2 : 1
                            border.color: isSelected ? Theme.text
                                        : w.urgent ? Theme.urgent
                                        : w.focused ? Theme.accentBright
                                        : Theme.surface
                            opacity: beingDragged ? 0.3
                                   : !isMatch ? 0.18
                                   : w.minimized ? 0.5 : 1

                            readonly property real iconSize:
                                Math.max(12, Math.min(40, Math.min(width, height) * 0.5))
                            readonly property bool roomForTitle: width > 70 && height > 54

                            AppIcon {
                                x: (parent.width - width) / 2
                                y: box.roomForTitle ? 6 : (parent.height - height) / 2
                                iconSize: box.iconSize
                                appClass: box.w.class
                                appInstance: box.w.instance
                            }

                            Text {
                                visible: box.roomForTitle
                                x: 4
                                y: 6 + box.iconSize + 3
                                width: parent.width - 8
                                height: parent.height - y - 3
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                text: (box.w.minimized ? "(min) " : "")
                                    + (box.w.name || box.w.class)
                                font.family: Theme.fontFamily
                                font.pointSize: 7
                                color: Theme.text
                            }

                            // Click focuses, a drag past a few pixels moves.
                            MouseArea {
                                id: boxMouse

                                anchors.fill: parent
                                property real px: 0
                                property real py: 0
                                property bool moved: false

                                function global(mouse) {
                                    const p = mapToItem(null, mouse.x, mouse.y);
                                    return Qt.point(win.modelData.x + p.x,
                                                    win.modelData.y + p.y);
                                }

                                onPressed: mouse => {
                                    const g = global(mouse);
                                    px = g.x; py = g.y; moved = false;
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return;
                                    const g = global(mouse);
                                    if (!moved && Math.hypot(g.x - px, g.y - py) < 6)
                                        return;
                                    if (!moved) {
                                        moved = true;
                                        root.dragId = box.w.id;
                                        root.dragging = true;
                                    }
                                    root.dragGx = g.x;
                                    root.dragGy = g.y;
                                }
                                onReleased: mouse => {
                                    if (moved) {
                                        const g = global(mouse);
                                        const id = box.w.id;
                                        root.dragging = false;
                                        root.dragId = -1;
                                        root.drop(id, g.x, g.y);
                                        root.refresh();
                                    } else {
                                        root.focusWindow(box.w.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // The window being carried, following the pointer on whichever
            // monitor it is over.
            Rectangle {
                id: ghost
                readonly property var dragged:
                    root.windows.find(w => w.id === root.dragId) ?? null
                visible: root.dragging && dragged !== null
                    && root.dragGx >= win.modelData.x
                    && root.dragGx < win.modelData.x + win.width
                    && root.dragGy >= win.modelData.y
                    && root.dragGy < win.modelData.y + win.height
                width: 120
                height: 72
                x: root.dragGx - win.modelData.x - width / 2
                y: root.dragGy - win.modelData.y - height / 2
                radius: 6
                color: Theme.surfaceAlt
                border.width: 2
                border.color: Theme.accentBright
                opacity: 0.9
                z: 100

                AppIcon {
                    x: (parent.width - width) / 2
                    y: 6
                    iconSize: 28
                    appClass: ghost.dragged ? ghost.dragged.class : ""
                    appInstance: ghost.dragged ? ghost.dragged.instance : ""
                }

                Text {
                    x: 4
                    y: 38
                    width: parent.width - 8
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    text: ghost.dragged ? (ghost.dragged.name || ghost.dragged.class) : ""
                    font.family: Theme.fontFamily
                    font.pointSize: 8
                    color: Theme.text
                }
            }
        }
    }
}
