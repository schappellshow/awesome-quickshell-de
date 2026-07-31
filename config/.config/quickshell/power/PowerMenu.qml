import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Full-screen session menu on every screen, toggled with
// `qs ipc call power toggle` (Super+BackSpace).
// Mouse: click a button, or click anywhere else to dismiss.
// Keyboard: Left/Right + Enter, Escape dismisses (needs focus; see focusable).
Scope {
    id: root

    property bool shown: false
    property int selected: 0

    // Per-output blurred wallpaper backgrounds, borrowed from
    // betterlockscreen's cache so the menu matches the lock screen.
    // Missing cache (or a monitor without one) falls back to plain dim.
    property var bgs: ({})

    // name -> absolute icon file. Qt's icon-theme lookup finds nothing under
    // QT_QPA_PLATFORMTHEME=xdgdesktopportal (only the qt6ct and kde platform
    // themes feed Qt a theme name), so Quickshell.iconPath() returns an
    // image://icon URL that fails to load. Resolve the files ourselves
    // instead, walking the active theme then breeze, which is what the
    // theme's own Inherits= chain would reach anyway.
    property var icons: ({})

    Component.onCompleted: iconProbe.running = true

    onShownChanged: {
        if (shown) {
            bgProbe.running = true;
            iconProbe.running = true;   // pick up an icon-theme change
        } else {
            // Awesome holds a keyboard grab for as long as the menu is up
            // (see modules/keys.lua). Release it however the menu closed —
            // key, mouse click on an action, or click on the backdrop —
            // so the grab can never outlive the window.
            Quickshell.execDetached(["awesome-client", "power_menu_release()"]);
        }
    }

    Process {
        id: iconProbe
        command: ["sh", "-c",
            'theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "\'"); ' +
            'for n in system-lock-screen system-log-out system-suspend system-reboot system-shutdown; do ' +
            '  for d in "$HOME/.local/share/icons/$theme" "/usr/share/icons/$theme" ' +
            '           /usr/share/icons/breeze-dark /usr/share/icons/breeze; do ' +
            '    [ -d "$d" ] || continue; ' +
            '    p=$(find -L "$d" -name "$n.svg" 2>/dev/null | head -1); ' +
            '    [ -n "$p" ] && { echo "$n $p"; break; }; ' +
            '  done; ' +
            'done']
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf(" ");
                    if (i > 0)
                        map[line.slice(0, i)] = line.slice(i + 1);
                }
                root.icons = map;
            }
        }
    }

    Process {
        id: bgProbe
        command: ["sh", "-c",
            "for d in \"$HOME\"/.cache/betterlockscreen/*/; do " +
            "n=${d%/}; n=${n##*/}; n=${n#*-}; " +
            "[ -f \"$d/dimblur.png\" ] && echo \"$n $d/dimblur.png\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf(" ");
                    if (i > 0)
                        map[line.slice(0, i)] = line.slice(i + 1);
                }
                root.bgs = map;
            }
        }
    }

    // Icons come from the icon theme: Vivid-Glassy-Dark-Icons has no session
    // icons of its own but inherits breeze-dark → breeze → Adwaita → hicolor,
    // so these standard freedesktop names resolve to breeze's.
    // `key` is the single-press shortcut. Shut Down is P (for power off)
    // because Suspend already owns S.
    readonly property var actions: [
        { label: "Lock",      key: "l", icon: "system-lock-screen",
          color: Theme.blue,   cmd: ["loginctl", "lock-session"] },
        { label: "Log Out",   key: "o", icon: "system-log-out",
          color: Theme.teal,   cmd: ["awesome-client", "awesome.quit()"] },
        { label: "Suspend",   key: "s", icon: "system-suspend",
          color: Theme.gold,   cmd: ["systemctl", "suspend"] },
        { label: "Restart",   key: "r", icon: "system-reboot",
          color: Theme.orange, cmd: ["systemctl", "reboot"] },
        { label: "Shut Down", key: "p", icon: "system-shutdown",
          color: Theme.red,    cmd: ["systemctl", "poweroff"] }
    ]

    function activate(index) {
        const cmd = actions[index].cmd;
        shown = false;
        Quickshell.execDetached(cmd);
    }

    // Returns the action index for a typed character, or -1
    function indexForKey(text) {
        const k = (text || "").toLowerCase();
        if (k === "")
            return -1;
        for (let i = 0; i < actions.length; i++) {
            if (actions[i].key === k)
                return i;
        }
        return -1;
    }

    // Single entry point for keyboard input, whether it arrives from QML's
    // own Keys handlers or is forwarded by awesome's keygrabber (X11, where
    // this window can't hold focus). Takes an X keysym name, so single
    // letters arrive as "s" and named keys as "Left"/"Return"/"Escape".
    function handleKey(name) {
        switch (name) {
        case "Escape":
        case "BackSpace":       // the same chord that opened the menu
            shown = false;
            return;
        case "Left":
            selected = (selected + actions.length - 1) % actions.length;
            return;
        case "Right":
            selected = (selected + 1) % actions.length;
            return;
        case "Return":
        case "KP_Enter":
            activate(selected);
            return;
        }
        const i = indexForKey(name);
        if (i >= 0)
            activate(i);
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.selected = 0;
            root.shown = !root.shown;
        }

        function open(): void {
            root.selected = 0;
            root.shown = true;
        }

        function close(): void {
            root.shown = false;
        }

        // Keysym forwarded by awesome's keygrabber while the menu is open.
        function key(name: string): void {
            if (root.shown)
                root.handleKey(name);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: root.shown
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            focusable: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Image {
                id: bgImage
                anchors.fill: parent
                source: root.bgs[win.modelData.name] !== undefined
                    ? "file://" + root.bgs[win.modelData.name] : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false   // wallpaper changes rewrite the same paths
            }

            Rectangle {
                anchors.fill: parent
                // Lighter veil when the blurred wallpaper is behind it
                color: bgImage.status === Image.Ready
                    ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0, 0, 0, 0.65)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.shown = false
                }

                Item {
                    anchors.fill: parent
                    focus: true

                    // Used only where this window can actually hold keyboard
                    // focus. Under X11 it can't (override-redirect), and
                    // nothing arrives here — awesome forwards keysyms to the
                    // `key` IPC call above instead. Both routes end up in
                    // handleKey(), so the behaviour is defined once.
                    Keys.onEscapePressed: root.handleKey("Escape")
                    Keys.onLeftPressed: root.handleKey("Left")
                    Keys.onRightPressed: root.handleKey("Right")
                    Keys.onReturnPressed: root.handleKey("Return")
                    Keys.onEnterPressed: root.handleKey("Return")

                    // Single-key shortcuts (l/o/s/r/p). Only accept the event
                    // on a match, so Escape/arrows/Enter still reach their
                    // own handlers above.
                    Keys.onPressed: event => {
                        const i = root.indexForKey(event.text);
                        if (i >= 0) {
                            root.activate(i);
                            event.accepted = true;
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 24

                        Repeater {
                            model: root.actions

                            Column {
                                id: entry

                                required property var modelData
                                required property int index

                                readonly property bool current: root.selected === index

                                spacing: 10

                                // Circle rather than a rounded square, to suit
                                // the round icons; transparent at rest so the
                                // accent reads as a highlight ring around the
                                // icon on hover/selection.
                                Rectangle {
                                    width: 96
                                    height: 96
                                    radius: width / 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: hover.hovered || entry.current
                                        ? entry.modelData.color : "transparent"
                                    border.width: entry.current ? 2 : 0
                                    border.color: Theme.text

                                    Behavior on color {
                                        ColorAnimation { duration: 100 }
                                    }

                                    Image {
                                        id: iconImg
                                        anchors.centerIn: parent
                                        width: 48
                                        height: 48
                                        source: root.icons[entry.modelData.icon] !== undefined
                                            ? "file://" + root.icons[entry.modelData.icon] : ""
                                        // SVGs rasterise at sourceSize, so ask
                                        // for 2x to stay crisp
                                        sourceSize.width: 96
                                        sourceSize.height: 96
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }

                                    // Degraded fallback if no icon file was
                                    // found: show the shortcut key, which
                                    // (unlike the label's first letter) is
                                    // unique per action.
                                    Text {
                                        anchors.centerIn: parent
                                        visible: iconImg.status !== Image.Ready
                                        text: entry.modelData.key.toUpperCase()
                                        font.family: Theme.fontFamily
                                        font.bold: true
                                        font.pointSize: 30
                                        color: Theme.text
                                    }

                                    HoverHandler { id: hover }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.activate(entry.index)
                                    }
                                }

                                // Label plus a muted hint for the single-key
                                // shortcut, so the bindings are discoverable
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: entry.modelData.label
                                        + '  <font color="' + Theme.muted + '">'
                                        + entry.modelData.key.toUpperCase()
                                        + '</font>'
                                    textFormat: Text.StyledText
                                    font.family: Theme.fontFamily
                                    font.pointSize: 11
                                    color: Theme.text
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
