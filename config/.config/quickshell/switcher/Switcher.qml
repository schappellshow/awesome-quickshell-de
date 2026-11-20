import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../bar"

// Alt+Tab popup. Awesome owns the keyboard (a key grab that lasts while Alt
// is held, see modules/keys.lua) and drives this over IPC:
//
//   switcher open     Alt+Tab pressed: snapshot the windows, highlight the
//                     previously used one
//   switcher next     Tab again          switcher prev   Shift+Tab
//   switcher accept   Alt released: focus the highlighted window, close
//   switcher cancel   Escape: close, change nothing
//
// So this window never takes focus (focusable stays false): the grab is what
// receives the keys, and a surface that grabbed focus would only fight it.
//
// The list is snapshotted at `open` and every decision is made on that
// snapshot, not on what is on screen. Open is driven by a held key and the
// next IPC call can arrive before the popup has been drawn; `accept` must
// still focus the right window then, and it does because it never looks at
// the view. The snapshot also keeps the order still while you cycle —
// focus changes elsewhere would otherwise reshuffle the MRU list under you.
//
// A mouse click on an entry focuses it and ends awesome's grab itself
// (`switcher_release`), since no Alt release is coming that awesome would
// act on. Clicking outside cancels the same way.
Scope {
    id: root

    property bool shown: false
    property var windows: []
    property int current: 0
    property var target: null

    function open() {
        // Normal windows on every tag and screen, most recently used first.
        // The scratchpad is a drawer, not a place you Alt+Tab to.
        const list = AwesomeState.allClients
            .filter(c => !c.scratchpad)
            .sort((a, b) => a.focusRank - b.focusRank);
        root.windows = list;
        // Index 0 is the window you are in; the point of Alt+Tab is the one
        // before it. With a single window there is nothing else to pick.
        root.current = list.length > 1 ? 1 : 0;

        const name = AwesomeState.focusedOutput;
        root.target = Quickshell.screens.find(s => s.name === name)
            ?? Quickshell.screens.find(s => s.name === Settings.barScreen)
            ?? Quickshell.screens[0];
        root.shown = list.length > 0;
    }

    function step(delta) {
        const n = root.windows.length;
        if (n === 0)
            return;
        root.current = (root.current + delta + n) % n;
    }

    function accept() {
        const w = root.windows[root.current];
        root.shown = false;
        root.windows = [];
        if (w)
            AwesomeState.shellFocusClient(w.id);
    }

    function cancel() {
        root.shown = false;
        root.windows = [];
    }

    // Closing by mouse: awesome never sees an Alt release it can act on
    // (the user is holding the mouse, not the key), so tell it to drop the grab.
    function pick(index) {
        const w = root.windows[index];
        root.cancel();
        if (w)
            AwesomeState.shellFocusClient(w.id);
        AwesomeState.switcherRelease();
    }

    function dismiss() {
        root.cancel();
        AwesomeState.switcherRelease();
    }

    IpcHandler {
        target: "switcher"

        function open(): void { root.open(); }
        function next(): void { root.step(1); }
        function prev(): void { root.step(-1); }
        function accept(): void { root.accept(); }
        function cancel(): void { root.cancel(); }
    }

    // "DP-1 · 2": where a window lives, shown only when it is not obvious.
    // On a single monitor the screen part is noise; the tag still helps.
    function placeOf(c) {
        const scr = AwesomeState.screens.find(s => s.index === c.screen);
        const tagNames = (c.tags || []).map(i => {
            const t = scr ? scr.tags.find(x => x.index === i) : null;
            return t ? t.name : String(i);
        });
        const parts = [];
        if (Quickshell.screens.length > 1 && c.output)
            parts.push(c.output);
        if (tagNames.length > 0)
            parts.push(tagNames.join(","));
        return parts.join(" · ");
    }

    PanelWindow {
        id: win

        screen: root.target ?? Quickshell.screens[0]
        visible: root.shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        anchors { top: true; bottom: true; left: true; right: true }

        readonly property int cellW: 132
        readonly property int cellH: 112
        readonly property int cols: Math.max(1, Math.min(root.windows.length,
            Math.floor((win.width - 120) / cellW)))

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Rectangle {
            anchors.centerIn: parent
            width: flow.width + 24
            height: flow.height + 24
            radius: Theme.radius
            color: Theme.base
            border.width: 1
            border.color: Theme.surfaceAlt

            MouseArea { anchors.fill: parent }

            Flow {
                id: flow
                anchors.centerIn: parent
                width: win.cols * win.cellW

                Repeater {
                    model: root.windows

                    Rectangle {
                        id: cell

                        required property var modelData
                        required property int index

                        readonly property bool isCurrent: index === root.current

                        width: win.cellW
                        height: win.cellH
                        radius: 8
                        color: isCurrent ? Theme.accent : "transparent"
                        opacity: modelData.minimized && !isCurrent ? 0.55 : 1

                        AppIcon {
                            x: (parent.width - width) / 2
                            y: 10
                            iconSize: 48
                            appClass: cell.modelData.class
                            appInstance: cell.modelData.instance
                        }

                        Text {
                            x: 6
                            y: 62
                            width: parent.width - 12
                            height: 28
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            text: cell.modelData.name || cell.modelData.class
                            font.family: Theme.fontFamily
                            font.pointSize: 8
                            color: Theme.text
                        }

                        Text {
                            x: 6
                            y: 90
                            width: parent.width - 12
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            text: (cell.modelData.minimized ? "minimized · " : "")
                                + root.placeOf(cell.modelData)
                            font.family: Theme.fontFamily
                            font.pointSize: 7
                            color: cell.isCurrent ? Theme.text : Theme.muted
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.pick(cell.index)
                        }
                    }
                }
            }
        }
    }
}
