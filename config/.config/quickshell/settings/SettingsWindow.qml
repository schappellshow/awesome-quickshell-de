import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "./components"

// The Settings app: sidebar navigation + lazily loaded pages, System
// Settings style. Toggled with `qs ipc call settings toggle`
// (Super+Shift+s); deep-link with `qs ipc call settings open <pageId>`.
FloatingWindow {
    id: win

    title: "Shell Settings"
    visible: false
    implicitWidth: 840
    implicitHeight: 560
    color: Theme.base

    property string currentPage: "appearance"

    readonly property var pages: [
        { id: "appearance",    title: "Appearance",    source: "pages/AppearancePage.qml" },
        { id: "wallpaper",     title: "Wallpaper",     source: "pages/WallpaperPage.qml" },
        { id: "bar",           title: "Bar",           source: "pages/BarPage.qml" },
        { id: "nightlight",    title: "Night Light",   source: "pages/NightLightPage.qml" },
        { id: "notifications", title: "Notifications", source: "pages/NotificationsPage.qml" },
        { id: "display",       title: "Displays",      source: "pages/DisplayPage.qml" },
        { id: "audio",         title: "Audio",         source: "pages/AudioPage.qml" },
        { id: "network",       title: "Network",       source: "pages/NetworkPage.qml" },
        { id: "bluetooth",     title: "Bluetooth",     source: "pages/BluetoothPage.qml" },
        { id: "power",         title: "Power",         source: "pages/PowerPage.qml" },
        { id: "keyboard",      title: "Keyboard",      source: "pages/KeyboardPage.qml" },
        { id: "mouse",         title: "Mouse",         source: "pages/MousePage.qml" },
        { id: "autostart",     title: "Autostart",     source: "pages/AutostartPage.qml" },
        { id: "defaultapps",   title: "Default Apps",  source: "pages/DefaultAppsPage.qml" },
        { id: "about",         title: "About",         source: "pages/AboutPage.qml" }
    ]

    function pageById(id) {
        for (const p of pages)
            if (p.id === id)
                return p;
        return pages[0];
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            win.visible = !win.visible;
        }

        function open(page: string): void {
            if (page !== "")
                win.currentPage = win.pageById(page).id;
            win.visible = true;
        }

        function close(): void {
            win.visible = false;
        }
    }

    Rectangle {
        id: sidebar

        width: 190
        height: parent.height
        color: Theme.surfaceAlt

        Column {
            x: 10
            y: 16
            width: parent.width - 20
            spacing: 2

            Text {
                x: 8
                text: "Settings"
                font.family: Theme.fontFamily
                font.bold: true
                font.pointSize: 13
                color: Theme.text
            }

            Item { width: 1; height: 10 }

            Repeater {
                model: win.pages

                Rectangle {
                    id: entry

                    required property var modelData

                    readonly property bool current: win.currentPage === modelData.id

                    width: parent.width
                    height: 30
                    radius: 8
                    color: current ? Theme.accent
                         : entryHover.hovered ? Theme.surface : "transparent"

                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.title
                        font.family: Theme.fontFamily
                        font.pointSize: 10
                        color: entry.current ? Theme.text : Theme.subtext
                    }

                    HoverHandler { id: entryHover }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: win.currentPage = entry.modelData.id
                    }
                }
            }
        }

        Text {
            x: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            width: parent.width - 36
            text: Settings.path
            wrapMode: Text.WrapAnywhere
            font.family: Theme.fontFamily
            font.pointSize: 6
            color: Theme.muted
        }
    }

    Loader {
        anchors.left: sidebar.right
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // Pages probe the system (xrandr, ls, ...) on load, so only build
        // while the window is open
        active: win.visible
        source: win.pageById(win.currentPage).source
    }
}
