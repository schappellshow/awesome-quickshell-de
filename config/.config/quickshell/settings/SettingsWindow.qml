import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "./components"

// The Settings app: two-level sidebar (top-level pages, plus groups such as
// Appearance and Power that drill down into a sub-list with a back row) and
// lazily loaded pages, System Settings style. Toggled with
// `qs ipc call settings toggle` (Super+Shift+s); deep-link with
// `qs ipc call settings open <pageId>` (a page id, or a group id for its
// first sub-page).
FloatingWindow {
    id: win

    title: "Shell Settings"
    visible: false
    implicitWidth: 840
    implicitHeight: 560
    color: Theme.base

    // currentPage is always a LEAF id (a page that has a source); groups
    // are only navigation. openGroup is the group whose sub-list the sidebar
    // is showing, or "" for the top-level list.
    property string currentPage: "display"
    property string openGroup: "appearance"

    // A shortcut capture has awesome holding the keyboard on this window's
    // behalf. Closing the window without saying so would strand that grab,
    // so the window is what ends it.
    onVisibleChanged: if (!visible) Shortcuts.stopCapture()

    // Top-level sidebar entries. An entry with `children` is a group: it has
    // no page of its own, and clicking it drills into its sub-list.
    readonly property var pages: [
        { id: "appearance", title: "Appearance", children: [
            { id: "display",    title: "Displays",    source: "pages/DisplayPage.qml" },
            { id: "windows",    title: "Windows",     source: "pages/WindowsPage.qml" },
            { id: "theme",      title: "Theme",       source: "pages/AppearancePage.qml" },
            { id: "bar",        title: "Bar",         source: "pages/BarPage.qml" },
            { id: "startmenu",  title: "Start Menu",  source: "pages/StartMenuPage.qml" },
            { id: "nightlight", title: "Night Light", source: "pages/NightLightPage.qml" },
            { id: "wallpaper",  title: "Wallpaper",   source: "pages/WallpaperPage.qml" }
        ] },
        { id: "notifications", title: "Notifications", source: "pages/NotificationsPage.qml" },
        { id: "audio",         title: "Audio",         source: "pages/AudioPage.qml" },
        { id: "connections", title: "Connections", children: [
            { id: "network",   title: "Network",   source: "pages/NetworkPage.qml" },
            { id: "bluetooth", title: "Bluetooth", source: "pages/BluetoothPage.qml" }
        ] },
        { id: "power", title: "Power", children: [
            { id: "lock",       title: "Lock Screen", source: "pages/LockPage.qml" },
            { id: "screenlock", title: "Screen Lock", source: "pages/ScreenLockPage.qml" },
            { id: "battery",    title: "Battery",     source: "pages/BatteryPage.qml" }
        ] },
        { id: "keyboard",      title: "Keyboard",      source: "pages/KeyboardPage.qml" },
        { id: "mouse",         title: "Mouse",         source: "pages/MousePage.qml" },
        { id: "autostart",     title: "Autostart",     source: "pages/AutostartPage.qml" },
        { id: "defaultapps",   title: "Default Apps",  source: "pages/DefaultAppsPage.qml" },
        { id: "backups",       title: "Backups",       source: "pages/BackupsPage.qml" },
        { id: "about",         title: "About",         source: "pages/AboutPage.qml" }
    ]

    function groupById(id) {
        for (const p of pages)
            if (p.children && p.id === id)
                return p;
        return null;
    }

    // Which group (id) a leaf lives in, or "" for a top-level page.
    function groupOf(leafId) {
        for (const p of pages)
            if (p.children)
                for (const c of p.children)
                    if (c.id === leafId)
                        return p.id;
        return "";
    }

    // Always returns a leaf (something with a source): a group id resolves
    // to its first sub-page, an unknown id to the first page, so the Loader
    // source is always valid.
    function pageById(id) {
        for (const p of pages) {
            if (p.id === id)
                return p.children ? p.children[0] : p;
            if (p.children)
                for (const c of p.children)
                    if (c.id === id)
                        return c;
        }
        return pages[0].children[0];
    }

    // Show a page and put the sidebar on the level that contains it.
    function showPage(id) {
        const leaf = pageById(id);
        currentPage = leaf.id;
        openGroup = groupOf(leaf.id);
    }

    // What the sidebar list currently shows.
    readonly property var sidebarEntries: {
        const g = groupById(openGroup);
        return g ? g.children : pages;
    }

    onOpenGroupChanged: pageList.contentY = 0

    IpcHandler {
        target: "settings"

        function toggle(): void {
            win.visible = !win.visible;
        }

        function open(page: string): void {
            if (page !== "")
                win.showPage(page);
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

        // Heading sits outside the scrolling area: it is a heading for the
        // list, not an item in it, and scrolling it away leaves the sidebar
        // looking like a stray column of buttons. Inside a group it becomes
        // a back row plus the group's name.
        Rectangle {
            id: backRow

            visible: win.openGroup !== ""
            x: 10
            y: 10
            width: sidebar.width - 20
            height: 28
            radius: 8
            color: backHover.hovered ? Theme.surface : "transparent"

            Text {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "\u2039 Settings"
                font.family: Theme.fontFamily
                font.pointSize: 10
                color: Theme.subtext
            }

            HoverHandler { id: backHover }

            MouseArea {
                anchors.fill: parent
                onClicked: win.openGroup = ""
            }
        }

        Text {
            id: sidebarTitle
            x: 18
            y: backRow.visible ? backRow.y + backRow.height + 8 : 16
            text: win.openGroup !== "" ? win.groupById(win.openGroup).title : "Settings"
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
                    model: win.sidebarEntries

                    Rectangle {
                        id: entry

                        required property var modelData

                        readonly property bool isGroup: modelData.children !== undefined
                        // A group row lights up while its page is the one shown
                        readonly property bool current: isGroup
                            ? win.groupOf(win.currentPage) === modelData.id
                            : win.currentPage === modelData.id

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

                        Text {
                            visible: entry.isGroup
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u203a"
                            font.family: Theme.fontFamily
                            font.pointSize: 10
                            color: entry.current ? Theme.text : Theme.subtext
                        }

                        HoverHandler { id: entryHover }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (entry.isGroup) {
                                    // Entering a group shows its first sub-page,
                                    // unless the page already shown is inside it
                                    // (Battery -> Back -> Power stays on Battery)
                                    if (win.groupOf(win.currentPage) !== entry.modelData.id)
                                        win.currentPage = entry.modelData.children[0].id;
                                    win.openGroup = entry.modelData.id;
                                } else {
                                    win.currentPage = entry.modelData.id;
                                }
                            }
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
            y: pageList.y + (needed ? (pageList.contentY / pageList.contentHeight) * pageList.height : 0)
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
