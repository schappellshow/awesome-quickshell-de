import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Clipboard history: filter, scroll, click to copy, click the pin to keep.
//
// Replaces `rofi -modi clipboard:greenclip print` on Super+/. rofi renders
// rows as text and a click selects the whole row — it has no per-row hover
// state and no sub-row hit region, so a pin button on the right of a line is
// not expressible there at any amount of config. That is the only reason
// this exists rather than a rofi keybinding.
//
// A PanelWindow with focusable: true, for the reasons AppLauncher.qml
// documents at length — a FloatingWindow gets adopted by whichever tag's
// tiling layout it is dragged onto, and an unfocusable dock surface cannot
// take the typing this needs for its filter field.
//
// Pinning is greenclip's `static_history`, written by bin/clipboard-pin.
// Entries there are exempt from max_history_length, and `greenclip print`
// re-reads the config per invocation, so a pin shows up in the next listing
// with no daemon restart.
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Settings.barScreen)
            ?? Quickshell.screens[0]

    anchors { top: true; bottom: true; left: true; right: true }

    visible: false
    color: "transparent"
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    // Wider than the app launcher: these rows are sentences, not app names.
    readonly property int cardW: 560
    readonly property int cardH: 480

    // Raw `greenclip print` output, and the pinned subset.
    property var rawEntries: []
    property var pinned: []

    property int selected: 0

    // Deduped, annotated view.
    //
    // A pinned entry appears twice in `greenclip print`: once at its position
    // in the rolling history, and again in the static block appended at the
    // end. Keeping the FIRST occurrence is what produces the behaviour you
    // want — a freshly pinned item stays where it is, drifts down as new
    // copies arrive, and once it ages out of the 50 it is still there, parked
    // at the bottom, until unpinned.
    readonly property var entries: {
        const seen = ({});
        const out = [];
        for (const line of win.rawEntries) {
            if (line === "" || seen[line])
                continue;
            seen[line] = true;
            out.push({ text: line, pinned: win.pinned.indexOf(line) >= 0 });
        }
        return out;
    }

    readonly property var matches: {
        const q = filterInput.text.toLowerCase();
        if (q === "")
            return win.entries;
        return win.entries.filter(e => e.text.toLowerCase().includes(q));
    }

    readonly property string pinTool:
        Quickshell.env("HOME") + "/.local/bin/clipboard-pin"

    function refresh(): void {
        listProc.running = true;
        pinsProc.running = true;
    }

    function close(): void {
        win.visible = false;
    }

    function copySelected(): void {
        const m = win.matches;
        if (m.length === 0)
            return;
        const i = Math.max(0, Math.min(win.selected, m.length - 1));
        // The same contract rofi's script mode used: handing a displayed line
        // back to greenclip is what puts the full entry on the clipboard.
        Quickshell.execDetached(["greenclip", "print", m[i].text]);
        win.close();
    }

    function togglePin(text): void {
        pinProc.command = [win.pinTool, "toggle", text];
        pinProc.running = true;
    }

    function togglePinSelected(): void {
        const m = win.matches;
        if (m.length === 0)
            return;
        const i = Math.max(0, Math.min(win.selected, m.length - 1));
        win.togglePin(m[i].text);
    }

    onVisibleChanged: {
        if (visible) {
            filterInput.text = "";
            win.selected = 0;
            win.refresh();
            filterInput.forceActiveFocus();
            focusTick.tries = 0;
            focusTick.restart();
        }
    }

    // awesome will not focus a dock surface unless asked; see AppLauncher.
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

    Process {
        id: listProc
        command: ["greenclip", "print"]
        stdout: StdioCollector {
            onStreamFinished: win.rawEntries = text.split("\n")
        }
    }

    Process {
        id: pinsProc
        command: [win.pinTool, "list"]
        stdout: StdioCollector {
            onStreamFinished: win.pinned = text.split("\n").filter(l => l !== "")
        }
    }

    // Re-read both after a pin toggle: the pinned set decides the icon, and
    // the listing itself changes because static entries are part of it.
    Process {
        id: pinProc
        onExited: win.refresh()
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            win.visible = !win.visible;
        }

        function open(): void {
            win.visible = true;
        }

        function close(): void {
            win.visible = false;
        }
    }

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

            x: 10
            y: 10
            width: parent.width - 20
            height: 30
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
                font.pointSize: 10
                color: Theme.text
                clip: true
                selectByMouse: true
                focus: true

                onTextChanged: win.selected = 0

                Keys.onDownPressed: win.selected =
                    Math.min(win.selected + 1, win.matches.length - 1)
                Keys.onUpPressed: win.selected = Math.max(win.selected - 1, 0)
                Keys.onEscapePressed: win.close()
                onAccepted: win.copySelected()

                // Ctrl+P pins without leaving the keyboard, mirroring the
                // click target. Ctrl rather than a bare key so it cannot
                // collide with typing a filter.
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_P
                            && (event.modifiers & Qt.ControlModifier)) {
                        win.togglePinSelected();
                        event.accepted = true;
                    }
                }
            }

            Text {
                anchors.fill: filterInput
                verticalAlignment: Text.AlignVCenter
                visible: filterInput.text.length === 0 && !filterInput.activeFocus
                text: "Filter clipboard…"
                font.family: Theme.fontFamily
                font.pointSize: 10
                color: Theme.muted
            }
        }

        Flickable {
            id: list

            x: 10
            y: filterBox.y + filterBox.height + 8
            width: parent.width - 20
            height: parent.height - y - 26
            contentHeight: listCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // Keep the keyboard selection on screen; 50 entries always
            // overflow this card.
            function ensureVisible(rowY, rowH) {
                if (rowY < contentY)
                    contentY = rowY;
                else if (rowY + rowH > contentY + height)
                    contentY = rowY + rowH - height;
            }

            Column {
                id: listCol
                width: list.width

                Repeater {
                    model: win.matches

                    Rectangle {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool current: index === win.selected

                        width: listCol.width
                        height: 30
                        radius: 6
                        color: row.current ? Theme.accent
                             : rowHover.hovered ? Theme.surface : "transparent"

                        onCurrentChanged: if (current) list.ensureVisible(y, height)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10
                            width: parent.width - 44
                            elide: Text.ElideRight
                            text: row.modelData.text
                            font.family: Theme.fontFamily
                            font.pointSize: 10
                            color: Theme.text
                        }

                        HoverHandler { id: rowHover }

                        // Row click copies. Declared before the pin so the
                        // pin's own area, being later, wins where they
                        // overlap.
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                win.selected = row.index;
                                win.copySelected();
                            }
                        }

                        // The pin. Always shown once pinned, so the state is
                        // readable at a glance; otherwise it appears on hover
                        // so the list stays quiet until you reach for it.
                        Text {
                            id: pinGlyph

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            visible: row.modelData.pinned || rowHover.hovered
                            text: String.fromCodePoint(0xf08d)   // thumbtack
                            font.family: Theme.iconFont
                            font.pointSize: 10
                            color: row.modelData.pinned
                                ? Theme.gold
                                : (pinHover.hovered ? Theme.text : Theme.muted)

                            HoverHandler { id: pinHover }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6   // a comfortable target
                                onClicked: win.togglePin(row.modelData.text)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            readonly property bool needed: list.contentHeight > list.height

            visible: needed
            width: 3
            radius: 1.5
            color: Theme.muted
            opacity: list.moving ? 0.9 : 0.35
            x: card.width - 7
            y: list.y + (list.contentY / Math.max(1, list.contentHeight)) * list.height
            height: needed
                ? Math.max(20, (list.height / list.contentHeight) * list.height)
                : 0

            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Text {
            x: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            text: win.matches.length === 0
                ? "No matches"
                : win.matches.length + " of " + win.entries.length
                  + "  ·  " + win.pinned.length + " pinned  ·  Ctrl+P to pin"
            font.family: Theme.fontFamily
            font.pointSize: 7
            color: Theme.muted
        }
    }
}
