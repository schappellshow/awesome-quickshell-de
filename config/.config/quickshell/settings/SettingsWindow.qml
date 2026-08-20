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
        { id: "apps",          title: "Apps",          source: "pages/AppsPage.qml" },
        { id: "nightlight",    title: "Night Light",   source: "pages/NightLightPage.qml" },
        { id: "notifications", title: "Notifications", source: "pages/NotificationsPage.qml" },
        { id: "display",       title: "Displays",      source: "pages/DisplayPage.qml" },
        { id: "audio",         title: "Audio",         source: "pages/AudioPage.qml" },
        { id: "network",       title: "Network",       source: "pages/NetworkPage.qml" },
        { id: "bluetooth",     title: "Bluetooth",     source: "pages/BluetoothPage.qml" },
        { id: "power",         title: "Power",         source: "pages/PowerPage.qml" },
        { id: "lock",          title: "Lock Screen",   source: "pages/LockPage.qml" },
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

        // Title sits outside the scrolling area: it is a heading for the
        // list, not an item in it, and scrolling it away leaves the sidebar
        // looking like a stray column of buttons.
        Text {
            id: sidebarTitle
            x: 18
            y: 16
            text: "Settings"
            font.family: Theme.fontFamily
            font.bold: true
            font.pointSize: 13
            color: Theme.text
        }

        // The page list scrolls. It used to be a plain Column, which was fine
        // until the list outgrew the window: with no clip and no scrolling,
        // entries past the bottom edge were simply unreachable, and nothing
        // on screen said they existed. At 16 pages it needed 546px in a 560px
        // window, so "About" was already being clipped.
        Flickable {
            id: pageList

            x: 10
            y: sidebarTitle.y + sidebarTitle.implicitHeight + 12
            width: sidebar.width - 20
            height: sidebar.height - y - 12

            contentHeight: pageCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 6000

            Column {
                id: pageCol

                width: pageList.width
                spacing: 2

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
        }

        // Scroll indicator. Hand-rolled because this codebase does not pull
        // in QtQuick.Controls (see components/ComboRow.qml), and absent
        // entirely while everything fits, so the sidebar looks unchanged
        // until the list actually overflows.
        Rectangle {
            readonly property bool needed: pageList.contentHeight > pageList.height

            visible: needed
            width: 3
            radius: 1.5
            color: Theme.muted
            opacity: pageList.moving ? 0.9 : 0.35
            x: sidebar.width - 6
            y: pageList.y + (pageList.contentY / pageList.contentHeight) * pageList.height
            height: needed
                ? Math.max(24, (pageList.height / pageList.contentHeight) * pageList.height)
                : 0

            Behavior on opacity { NumberAnimation { duration: 150 } }
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
