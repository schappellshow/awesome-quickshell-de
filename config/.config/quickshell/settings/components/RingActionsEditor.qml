import QtQuick
import "../../common"

// Choose and order the quick-actions ring's entries. Shown actions come
// first, in ring order (clockwise from the top) with arrows to move them;
// the rest follow with a plain switch. Writes Settings.ringActions, which
// holds only ids, so a catalog change never strands a stale entry.
Column {
    id: root

    width: parent.width
    spacing: 2

    readonly property var chosen: RingActions.resolve(Settings.ringActions)
    readonly property var rest: RingActions.all.filter(
        a => !root.chosen.some(c => c.id === a.id))
    readonly property bool full: chosen.length >= RingActions.maxItems

    function ids() { return root.chosen.map(a => a.id); }

    function setIds(list) { Settings.ringActions = list; }

    function move(i, delta) {
        const list = root.ids();
        const j = i + delta;
        if (j < 0 || j >= list.length)
            return;
        const t = list[i];
        list[i] = list[j];
        list[j] = t;
        root.setIds(list);
    }

    function remove(i) {
        const list = root.ids();
        // The ring needs something to show.
        if (list.length <= 1)
            return;
        list.splice(i, 1);
        root.setIds(list);
    }

    function add(id) {
        if (root.full)
            return;
        root.setIds(root.ids().concat([id]));
    }

    component Arrow: Rectangle {
        id: arrow
        property string glyph
        property bool live: true
        signal clicked()
        width: 26
        height: 22
        radius: 6
        opacity: live ? 1 : 0.3
        color: hover.hovered && live ? Theme.accent : Theme.surface
        Text {
            anchors.centerIn: parent
            text: arrow.glyph
            font.family: Theme.iconFont
            font.pixelSize: 11
            color: Theme.text
        }
        HoverHandler { id: hover }
        MouseArea {
            anchors.fill: parent
            enabled: arrow.live
            onClicked: arrow.clicked()
        }
    }

    component Entry: Item {
        id: entry
        property var action
        property bool on
        property int slot: -1
        property bool canEnable: true
        width: root.width
        height: 30

        // Switch
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 20
            radius: 10
            opacity: entry.on || entry.canEnable ? 1 : 0.35
            color: entry.on ? Theme.accent : Theme.surface
            Rectangle {
                width: 14
                height: 14
                radius: 7
                y: 3
                x: entry.on ? track.width - width - 3 : 3
                color: Theme.text
            }
            MouseArea {
                anchors.fill: parent
                onClicked: entry.on ? root.remove(entry.slot) : root.add(entry.action.id)
            }
        }

        Text {
            anchors.left: track.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: (entry.on ? (entry.slot + 1) + ".  " : "")
                + entry.action.label
                + (entry.action.window ? "  (needs a window)" : "")
            font.family: Theme.fontFamily
            font.pointSize: 10
            color: entry.on ? Theme.text : Theme.subtext
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: entry.on
            Arrow {
                glyph: ""
                live: entry.slot > 0
                onClicked: root.move(entry.slot, -1)
            }
            Arrow {
                glyph: ""
                live: entry.slot < root.chosen.length - 1
                onClicked: root.move(entry.slot, 1)
            }
        }
    }

    Repeater {
        model: root.chosen
        Entry {
            required property var modelData
            required property int index
            action: modelData
            slot: index
            on: true
        }
    }

    Repeater {
        model: root.rest
        Entry {
            required property var modelData
            action: modelData
            on: false
            canEnable: !root.full
        }
    }
}
