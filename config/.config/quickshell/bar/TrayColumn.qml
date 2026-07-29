import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../common"

// StatusNotifierItem tray. Left-click activates, right-click opens the
// item's menu. Note: legacy XEmbed-only tray apps will not appear.
Column {
    id: root

    property var barWindow

    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem

            required property var modelData

            width: 18
            height: 18

            // quickshell can't search SNI custom icon paths (apps like
            // Spotify ship "image://icon/<name>?path=<dir>") — rebuild
            // those into direct file URLs so they don't render as the
            // missing-icon checkerboard.
            function fixIcon(icon) {
                const m = /^image:\/\/icon\/(.*)\?path=(.*)$/.exec(icon);
                if (m) {
                    // Some apps (rustdesk) put an absolute path in the icon
                    // NAME — joining it onto the dir doubles the path
                    if (m[1].startsWith("/"))
                        return "file://" + m[1];
                    return "file://" + m[2] + "/" + m[1]
                        + (m[1].includes(".") ? "" : ".png");
                }
                return icon;
            }

            IconImage {
                anchors.fill: parent
                source: trayItem.fixIcon(trayItem.modelData.icon)
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.window: root.barWindow
            }

            function openMenu() {
                const p = trayItem.mapToItem(null, trayItem.width, trayItem.height / 2);
                menuAnchor.anchor.rect = Qt.rect(p.x, p.y, 1, 1);
                menuAnchor.open();
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouseEvent => {
                    if (mouseEvent.button === Qt.RightButton) {
                        if (trayItem.modelData.hasMenu)
                            trayItem.openMenu();
                    } else if (mouseEvent.button === Qt.MiddleButton) {
                        trayItem.modelData.secondaryActivate();
                    } else if (trayItem.modelData.onlyMenu) {
                        trayItem.openMenu();
                    } else {
                        trayItem.modelData.activate();
                    }
                }
            }
        }
    }
}
