import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../common"

// StatusNotifierItem tray. Left-click activates, right-click opens the
// item's menu. Note: legacy XEmbed-only tray apps will not appear.
//
// Individual icons can be hidden from the Bar settings page; the Grid leaves
// invisible children out of its layout, so a hidden one costs no space.
Grid {
    id: root

    property var barWindow
    property bool vertical: BarEdge.vertical

    columns: root.vertical ? 1 : 99
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem

            required property var modelData

            visible: !TrayItems.isHidden(trayItem.modelData)

            width: 18
            height: 18

            IconImage {
                anchors.fill: parent
                source: TrayItems.fixIcon(trayItem.modelData.icon)
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.window: root.barWindow
            }

            // Open off the icon's inward-facing edge, so the menu unfolds
            // over the desktop rather than back across the bar.
            function openMenu() {
                const edge = BarEdge.edge;
                const px = root.vertical
                    ? (edge === "right" ? 0 : trayItem.width)
                    : trayItem.width / 2;
                const py = root.vertical
                    ? trayItem.height / 2
                    : (edge === "bottom" ? 0 : trayItem.height);
                const p = trayItem.mapToItem(null, px, py);
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
