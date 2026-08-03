import QtQuick
import Quickshell
import "../common"

// Month-grid calendar, popped out beside the clock pill. Pure JS Date math;
// scroll or arrows change month, click the header to jump back to today.
PopupWindow {
    id: panel

    property var barWindow
    property Item anchorItem
    property bool shown: false

    // First day shown is the Sunday on/before the 1st of the viewed month
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    // The wall clock has to be a property, not a `new Date()` read inside
    // the cells binding. QML can only re-run a binding when something it
    // depends on changes, and it cannot watch the clock — so the "today"
    // ring froze at whenever cells last ran (component creation, or the last
    // month change) and stayed there for as long as quickshell was up.
    // Refreshed on every open, which is the only time it can be seen.
    property var today: new Date()

    onShownChanged: {
        if (shown)
            goToday();
    }

    function goToday() {
        // Re-read the clock first: assigning viewYear/viewMonth values they
        // already hold emits no change, so on the common path (opening the
        // popup during the current month) this assignment is what makes the
        // cells binding re-evaluate at all.
        today = new Date();
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    function shiftMonth(delta) {
        const d = new Date(viewYear, viewMonth + delta, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }

    readonly property var monthNames: ["January", "February", "March", "April",
        "May", "June", "July", "August", "September", "October", "November",
        "December"]

    // 42 cells: { day, inMonth, isToday }
    readonly property var cells: {
        const first = new Date(viewYear, viewMonth, 1);
        const start = new Date(viewYear, viewMonth, 1 - first.getDay());
        const today = panel.today;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(),
                start.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === viewMonth,
                isToday: d.getFullYear() === today.getFullYear()
                    && d.getMonth() === today.getMonth()
                    && d.getDate() === today.getDate()
            });
        }
        return out;
    }

    visible: shown
    color: "transparent"
    implicitWidth: 236
    implicitHeight: card.implicitHeight

    anchor.window: barWindow
    anchor.rect.x: barWindow ? barWindow.implicitWidth + 6 : 42
    anchor.rect.y: {
        // Referencing `shown` re-evaluates this on every open — mapToItem
        // isn't reactive, and the at-creation value put the popup at the
        // top of the screen
        if (!anchorItem || !shown)
            return 100;
        const p = anchorItem.mapToItem(null, 0, anchorItem.height / 2);
        return Math.max(8, p.y - panel.implicitHeight / 2);
    }

    Rectangle {
        id: card

        width: parent.width
        implicitHeight: col.implicitHeight + 24
        radius: Theme.radius
        color: Theme.base
        border.color: Theme.accentBright
        border.width: 2

        MouseArea {
            anchors.fill: parent
            onWheel: wheelEvent =>
                panel.shiftMonth(wheelEvent.angleDelta.y > 0 ? -1 : 1)
        }

        Column {
            id: col

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            // Header: ◀ Month Year ▶
            Item {
                width: parent.width
                height: 18

                Text {
                    text: "◀"
                    font.pointSize: 9
                    color: Theme.subtext
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: panel.shiftMonth(-1)
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.monthNames[panel.viewMonth] + " " + panel.viewYear
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pointSize: 10
                    color: Theme.text
                    MouseArea {
                        anchors.fill: parent
                        onClicked: panel.goToday()
                    }
                }

                Text {
                    anchors.right: parent.right
                    text: "▶"
                    font.pointSize: 9
                    color: Theme.subtext
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: panel.shiftMonth(1)
                    }
                }
            }

            // Day-of-week header
            Grid {
                columns: 7
                width: parent.width

                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]

                    Item {
                        required property string modelData
                        width: col.width / 7
                        height: 16

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pointSize: 7
                            color: Theme.muted
                        }
                    }
                }
            }

            Grid {
                columns: 7
                width: parent.width

                Repeater {
                    model: panel.cells

                    Item {
                        id: cell

                        required property var modelData

                        width: col.width / 7
                        height: 24

                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            color: cell.modelData.isToday ? Theme.accent : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.day
                            font.family: Theme.fontFamily
                            font.pointSize: 8
                            color: cell.modelData.isToday ? Theme.text
                                 : cell.modelData.inMonth ? Theme.subtext
                                 : Theme.muted
                        }
                    }
                }
            }
        }
    }
}
