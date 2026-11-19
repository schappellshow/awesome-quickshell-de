import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Searchable shortcut list: `qs ipc call keyhints toggle` (Super+S).
//
// Lists every shortcut in awesome's registry (Shortcuts.registry, which
// watches $XDG_RUNTIME_DIR/awesomewm-shortcuts.json and so already follows a
// rebind) with the chord it is bound to TODAY, grouped as the registry
// groups them. Typing filters on description, group and chord; Up/Down move
// the highlight; Enter closes the panel and runs the highlighted shortcut
// through awesome (`shortcut_run`); Escape or a click outside closes.
//
// Below the registry sits a static block of keys that are bound in a loop
// rather than registered (tag keys, mouse chords). They are listed so the
// panel really is the whole picture, and are drawn without a highlight
// because there is nothing to run.
//
// Keyboard input is the launcher's approach, for the same reason: a
// focusable PanelWindow plus an explicit awesome-side focus, because a dock
// surface is never focused by awesome on its own. (The power menu needs
// awesome's keygrabber instead only because it is override-redirect-like
// and sits over every monitor; one text field on one screen is the case a
// focusable dock handles.) The panel opens on the screen that has focus.
PanelWindow {
    id: win

    // Fixed when the panel opens: re-deriving it live would walk the window
    // to another monitor whenever focus state changed under it.
    property var target: null

    screen: win.target ?? Quickshell.screens[0]

    anchors { top: true; bottom: true; left: true; right: true }

    visible: false
    color: "transparent"
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    readonly property int cardW: Math.min(640, win.width - 40)
    readonly property int cardH: Math.min(620, win.height - 80)

    // Keys that exist but are not in the registry. `chord` is display text.
    readonly property var fixedKeys: [
        { label: "view tag 1–9",                 chord: "Super+1…9" },
        { label: "toggle tag 1–9 into the view", chord: "Super+Ctrl+1…9" },
        { label: "move window to tag 1–9",       chord: "Super+Shift+1…9" },
        { label: "move window with the mouse",   chord: "Super+Left drag" },
        { label: "resize window with the mouse", chord: "Super+Right drag" },
        { label: "next / previous tag",          chord: "Scroll on desktop" },
        { label: "desktop menu",                 chord: "Right click on desktop" }
    ]

    function groupTitle(g) {
        const s = String(g);
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // Registry entries then custom ones, as { id, group, label, chord }.
    // `chord` is the pretty form of what is bound now (an override beats the
    // default); an unbound shortcut keeps its row — it can still be run.
    readonly property var entries: {
        const out = [];
        for (const g of Shortcuts.groups()) {
            for (const e of Shortcuts.inGroup(g)) {
                out.push({ id: e.id, group: win.groupTitle(g), label: e.label,
                           raw: Shortcuts.chordFor(e.id),
                           chord: Shortcuts.pretty(Shortcuts.chordFor(e.id)) });
            }
        }
        for (const c of Shortcuts.custom) {
            out.push({ id: c.id, group: "Custom", label: c.command,
                       raw: c.chord || "", chord: Shortcuts.pretty(c.chord || "") });
        }
        return out;
    }

    function matches(query, fields) {
        // Every word must hit some field, so "super tag" narrows rather than
        // matching only the literal phrase.
        const words = query.toLowerCase().split(/\s+/).filter(w => w !== "");
        const hay = fields.join("\n").toLowerCase();
        return words.every(w => hay.includes(w));
    }

    // Flat display model: headers and rows interleaved. `idx` is the row's
    // place among the runnable ones (-1 for headers and fixed keys), which is
    // what the highlight and Enter work on.
    readonly property var model: {
        const q = filterInput.text;
        const rows = [];
        const run = [];
        let last = "";
        for (const e of win.entries) {
            if (!win.matches(q, [e.label, e.group, e.chord, e.raw]))
                continue;
            if (e.group !== last) {
                rows.push({ kind: "header", text: e.group, idx: -1 });
                last = e.group;
            }
            rows.push({ kind: "item", id: e.id, label: e.label, chord: e.chord,
                        idx: run.length });
            run.push(rows.length - 1);
        }
        let fixedHeader = false;
        for (const f of win.fixedKeys) {
            if (!win.matches(q, [f.label, "fixed keys", f.chord]))
                continue;
            if (!fixedHeader) {
                rows.push({ kind: "header", text: "Fixed keys (not rebindable, not runnable)",
                            idx: -1 });
                fixedHeader = true;
            }
            rows.push({ kind: "fixed", label: f.label, chord: f.chord, idx: -1 });
        }
        return { rows: rows, runnable: run };
    }

    property int selected: 0

    function close(): void {
        win.visible = false;
    }

    function open(): void {
        const name = AwesomeState.focusedOutput;
        win.target = Quickshell.screens.find(s => s.name === name)
            ?? Quickshell.screens.find(s => s.name === Settings.barScreen)
            ?? Quickshell.screens[0];
        win.visible = true;
    }

    function runSelected(): void {
        const run = win.model.runnable;
        if (run.length === 0)
            return;
        const row = win.model.rows[run[Math.max(0, Math.min(win.selected, run.length - 1))]];
        win.close();
        // Let the panel go and focus return to the window underneath first:
        // client shortcuts act on whichever window has focus when they fire.
        runTimer.runId = row.id;
        runTimer.restart();
    }

    Timer {
        id: runTimer
        property string runId: ""
        interval: 120
        onTriggered: AwesomeState.shortcutRun(runTimer.runId)
    }

    function move(delta): void {
        const n = win.model.runnable.length;
        if (n === 0)
            return;
        win.selected = Math.max(0, Math.min(n - 1, win.selected + delta));
        list.positionViewAtIndex(win.model.runnable[win.selected], ListView.Contain);
    }

    // A new filter starts at the top again: the old index points at a
    // different row once the list changes under it.
    Connections {
        target: filterInput
        function onTextChanged() { win.selected = 0; }
    }

    onVisibleChanged: {
        if (visible) {
            filterInput.text = "";
            win.selected = 0;
            filterInput.forceActiveFocus();
            // See AppLauncher: forceActiveFocus only works inside the
            // window; the dock surface itself needs awesome to focus it.
            focusTick.tries = 0;
            focusTick.restart();
        }
    }

    Timer {
        id: focusTick

        property int tries: 0

        interval: 80
        repeat: true
        onTriggered: {
            const s = win.screen;
            if (s)
                AwesomeState.focusOwnDock(s.x, s.y, s.width, s.height);
            focusTick.tries += 1;
            if (focusTick.tries >= 3)
                focusTick.stop();
        }
    }

    IpcHandler {
        target: "keyhints"

        function toggle(): void {
            if (win.visible)
                win.close();
            else
                win.open();
        }

        function open(): void {
            win.open();
        }

        function close(): void {
            win.close();
        }
    }

    // Click-away: the window is full-screen so a click outside the card
    // lands somewhere we can see it.
    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: win.cardW
        height: win.cardH
        radius: 10
        color: Theme.base
        border.width: 1
        border.color: Theme.surfaceAlt

        MouseArea { anchors.fill: parent }

        Rectangle {
            id: filterBox

            x: 12
            y: 12
            width: parent.width - 24
            height: 34
            radius: 7
            color: Theme.surfaceAlt
            border.width: filterInput.activeFocus ? 1 : 0
            border.color: Theme.accent

            TextInput {
                id: filterInput

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.pointSize: 11
                color: Theme.text
                clip: true
                selectByMouse: true
                focus: true

                Keys.onDownPressed: win.move(1)
                Keys.onUpPressed: win.move(-1)
                Keys.onEscapePressed: win.close()
                onAccepted: win.runSelected()
            }

            Text {
                anchors.fill: filterInput
                verticalAlignment: Text.AlignVCenter
                visible: filterInput.text.length === 0
                text: "Search shortcuts…  Enter runs the highlighted one"
                font.family: Theme.fontFamily
                font.pointSize: 11
                color: Theme.muted
            }
        }

        ListView {
            id: list

            x: 12
            y: filterBox.y + filterBox.height + 8
            width: parent.width - 24
            height: parent.height - y - 28
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: win.model.rows
            reuseItems: false

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                readonly property bool isHeader: modelData.kind === "header"
                readonly property bool current: modelData.idx >= 0
                    && modelData.idx === win.selected

                width: list.width
                height: isHeader ? 30 : 28

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    radius: 6
                    visible: !row.isHeader
                    color: row.current ? Theme.accent
                         : (rowHover.hovered && row.modelData.idx >= 0) ? Theme.surface
                         : "transparent"
                }

                Text {
                    visible: row.isHeader
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: row.modelData.text ?? ""
                    font.family: Theme.labelFont
                    font.bold: true
                    font.pointSize: 8
                    font.capitalization: Font.AllUppercase
                    color: Theme.accentBright
                }

                Text {
                    visible: !row.isHeader
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: chordBox.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.modelData.label ?? ""
                    font.family: Theme.fontFamily
                    font.pointSize: 10
                    color: row.modelData.kind === "fixed" ? Theme.subtext : Theme.text
                }

                Rectangle {
                    id: chordBox
                    visible: !row.isHeader
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: chordText.implicitWidth + 14
                    height: 20
                    radius: 5
                    color: row.current ? Qt.rgba(0, 0, 0, 0.25) : Theme.surfaceAlt

                    Text {
                        id: chordText
                        anchors.centerIn: parent
                        text: row.modelData.chord ?? ""
                        font.family: Theme.fontFamily
                        font.pointSize: 9
                        color: row.modelData.kind === "fixed" ? Theme.muted : Theme.text
                    }
                }

                HoverHandler { id: rowHover }

                MouseArea {
                    anchors.fill: parent
                    enabled: row.modelData.idx >= 0
                    onClicked: {
                        win.selected = row.modelData.idx;
                        win.runSelected();
                    }
                }
            }
        }

        Text {
            x: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: win.model.runnable.length === 0
                ? "No matches"
                : win.model.runnable.length + " shortcuts · ↑↓ choose · Enter run · Esc close"
            font.family: Theme.fontFamily
            font.pointSize: 7
            color: Theme.muted
        }
    }
}
