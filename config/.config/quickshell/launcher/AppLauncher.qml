import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Application launcher: filter, scroll, click to run.
//
// Reached from the desktop right-click menu and the bar's start button
// ("Apps" in modules/keys.lua), which used to shell out to `rofi -show drun`.
// Rofi is still bound to its own keys — this is the pointer-driven path, for
// someone browsing rather than someone who already knows the name.
//
// A PanelWindow, so awesome never manages it as a client.
//
// It began as a FloatingWindow and that was wrong twice over. awesome layouts
// are PER TAG, and each screen has its own tags — so "floating" set on one
// tag says nothing about the others, and dragging the launcher to another
// monitor handed it straight to that tag's tiling layout. A PanelWindow is a
// dock surface (the bar is one), which no layout ever touches.
//
// focusable: true is what keeps the search field usable: without it this
// would be an override-redirect surface that cannot take keyboard input
// without awesome holding a keygrabber on its behalf (the power_menu_release
// dance in modules/keys.lua).
PanelWindow {
    id: win

    // Covers the bar's screen entirely, with the card placed inside it.
    //
    // The window is full-screen and transparent so that clicking anywhere
    // outside the card dismisses it: a dock surface only receives clicks
    // within its own rect, so a 340x440 window could never see the click
    // that should close it. The power menu takes the same approach.
    screen: Quickshell.screens.find(s => s.name === Settings.barScreen)
            ?? Quickshell.screens[0]

    anchors { top: true; bottom: true; left: true; right: true }

    visible: false
    color: "transparent"
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    // Menu-sized card, not a window: this hangs off a button, so it should
    // read as that button's menu. Placed under the start button by following
    // the bar's edge and thickness.
    readonly property int cardW: 340
    readonly property int cardH: 440

    readonly property int cardX: BarEdge.vertical
        ? (BarEdge.edge === "left" ? Settings.barWidth + BarEdge.gap
                                   : win.width - cardW - Settings.barWidth - BarEdge.gap)
        : BarEdge.gap
    readonly property int cardY: BarEdge.vertical
        ? BarEdge.gap
        : (BarEdge.edge === "top" ? Settings.barWidth + BarEdge.gap
                                  : win.height - cardH - Settings.barWidth - BarEdge.gap)

    readonly property var matches: AppLookup.search(filterInput.text)

    // Index into `matches`, for keyboard selection. Clamped rather than
    // reset on every keystroke so the highlight survives a backspace.
    property int selected: 0

    function close(): void {
        win.visible = false;
    }

    function launchSelected(): void {
        const m = win.matches;
        if (m.length === 0)
            return;
        const i = Math.max(0, Math.min(win.selected, m.length - 1));
        AppLookup.launch(m[i].id);
        win.close();
    }

    onVisibleChanged: {
        if (visible) {
            filterInput.text = "";
            win.selected = 0;
            filterInput.forceActiveFocus();
            // forceActiveFocus only moves focus WITHIN this window. The
            // window itself is a dock surface, which awesome will not focus
            // unless asked, so without this the keyboard stays pointed at
            // whatever you were using and the search field silently ignores
            // you. Deferred a frame so the surface exists to be focused.
            focusTick.tries = 0;
            focusTick.restart();
        }
    }

    // Retries rather than guessing one delay: the surface has to be mapped
    // before awesome can focus it, and how long that takes is not ours to
    // predict. Three attempts covers a slow map without spinning.
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
        target: "launcher"

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

    // Card, matching the bar's popup panels: the window itself is
    // transparent so the rounded corners are real rather than painted.
    // Click-away. Sits below the card in child order, so the card's own
    // MouseAreas win where they overlap.
    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Rectangle {
        id: card

        x: win.cardX
        y: win.cardY
        width: win.cardW
        height: win.cardH
        radius: 10
        color: Theme.base
        border.width: 1
        border.color: Theme.surfaceAlt

        // Swallow clicks that land on the card but not on a row, so they do
        // not reach the backdrop and close the menu.
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

                // Arrows and Enter drive the list from the filter field, so
                // you never have to leave it to pick something.
                Keys.onDownPressed: win.selected =
                    Math.min(win.selected + 1, win.matches.length - 1)
                Keys.onUpPressed: win.selected = Math.max(win.selected - 1, 0)
                Keys.onEscapePressed: win.close()
                onAccepted: win.launchSelected()
            }

            Text {
                anchors.fill: filterInput
                verticalAlignment: Text.AlignVCenter
                visible: filterInput.text.length === 0 && !filterInput.activeFocus
                text: "Search…"
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

            Column {
                id: listCol
                width: list.width

                Repeater {
                    model: win.matches

                    Rectangle {
                        id: appRow

                        required property var modelData
                        required property int index

                        readonly property bool current: index === win.selected

                        width: listCol.width
                        height: 30
                        radius: 6
                        color: appRow.current ? Theme.accent
                             : rowHover.hovered ? Theme.surface : "transparent"

                        Image {
                            id: rowIcon
                            anchors.verticalCenter: parent.verticalCenter
                            x: 7
                            width: 18
                            height: 18
                            source: appRow.modelData.icon
                            sourceSize.width: 36
                            sourceSize.height: 36
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        // A theme can ship a malformed SVG (Vivid-Glassy-Dark's
                        // libreoffice-base.svg references gradients it never
                        // defines) and some entries declare no icon at all, so
                        // the row falls back to an initial rather than a blank.
                        Text {
                            anchors.centerIn: rowIcon
                            visible: rowIcon.status !== Image.Ready
                            text: appRow.modelData.name.charAt(0).toUpperCase()
                            font.family: Theme.labelFont
                            font.bold: true
                            font.pointSize: 9
                            color: Theme.subtext
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 32
                            width: parent.width - 40
                            elide: Text.ElideRight
                            text: appRow.modelData.name
                            font.family: Theme.fontFamily
                            font.pointSize: 10
                            color: Theme.text
                        }

                        HoverHandler { id: rowHover }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                win.selected = appRow.index;
                                win.launchSelected();
                            }
                        }
                    }
                }
            }
        }

        // Hand-rolled indicator, as elsewhere: no QtQuick.Controls here.
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
                : win.matches.length + " of " + AppLookup.applications.length
            font.family: Theme.fontFamily
            font.pointSize: 7
            color: Theme.muted
        }
    }
}
