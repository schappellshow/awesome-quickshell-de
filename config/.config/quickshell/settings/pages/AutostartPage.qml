import QtQuick
import "../components"
import "../../common"

// Extra user autostart commands, spawned by the shell at startup with a
// pgrep guard. Core daemons stay in awesome's autostart.lua.
SettingsPage {
    id: page

    title: "Autostart"

    function entries() {
        return Settings.autostartExtra || [];
    }

    function setEntries(list) {
        Settings.autostartExtra = list;
    }

    SectionLabel { text: "EXTRA COMMANDS" }

    Text {
        visible: page.entries().length === 0
        text: "Nothing here yet — add a command below."
        font.family: Theme.fontFamily
        font.pointSize: 9
        color: Theme.muted
    }

    readonly property var delayOptions: [0, 5, 10, 15, 20, 30, 45, 60]

    function moveEntry(index, delta) {
        const list = page.entries().slice();
        const j = index + delta;
        if (j < 0 || j >= list.length)
            return;
        const tmp = list[index];
        list[index] = list[j];
        list[j] = tmp;
        page.setEntries(list);
    }

    Repeater {
        model: Settings.autostartExtra

        Item {
            id: row

            required property var modelData
            required property int index

            readonly property int delaySec: Number(modelData.delay) || 0

            width: parent.width
            height: 28

            Rectangle {
                id: enableBox
                width: 18
                height: 18
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: row.modelData.enabled ? Theme.accent : Theme.surface

                Text {
                    anchors.centerIn: parent
                    visible: row.modelData.enabled
                    text: "✓"
                    font.pointSize: 9
                    color: Theme.text
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        const list = page.entries().map((e, i) => i === row.index
                            ? Object.assign({}, e, { enabled: !e.enabled }) : e);
                        page.setEntries(list);
                    }
                }
            }

            Text {
                x: 28
                width: parent.width - 28 - 216
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.command
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: row.modelData.enabled ? Theme.text : Theme.muted
            }

            // Delay chip: click cycles 0/5/10/15/20/30/45/60s, shown as a
            // countdown from session start (each entry delays
            // independently — see Autostart.qml)
            Rectangle {
                id: delayChip
                anchors.right: upBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 54
                height: 22
                radius: 7
                color: delayHover.hovered ? Theme.surfaceAlt : Theme.surface

                Text {
                    anchors.centerIn: parent
                    text: row.delaySec === 0 ? "no delay" : row.delaySec + "s"
                    font.family: Theme.fontFamily
                    font.pointSize: 8
                    color: Theme.accentBright
                }

                HoverHandler { id: delayHover }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        const opts = page.delayOptions;
                        const i = opts.indexOf(row.delaySec);
                        const next = opts[(i + 1) % opts.length];
                        const list = page.entries().map((e, idx) => idx === row.index
                            ? Object.assign({}, e, { delay: next }) : e);
                        page.setEntries(list);
                    }
                }
            }

            Text {
                id: upBtn
                anchors.right: downBtn.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "▲"
                font.pointSize: 8
                opacity: row.index === 0 ? 0.3 : 1
                color: upHover.hovered ? Theme.accentBright : Theme.muted

                HoverHandler { id: upHover }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: row.index > 0
                    onClicked: page.moveEntry(row.index, -1)
                }
            }

            Text {
                id: downBtn
                anchors.right: removeBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "▼"
                font.pointSize: 8
                opacity: row.index === page.entries().length - 1 ? 0.3 : 1
                color: downHover.hovered ? Theme.accentBright : Theme.muted

                HoverHandler { id: downHover }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: row.index < page.entries().length - 1
                    onClicked: page.moveEntry(row.index, 1)
                }
            }

            Text {
                id: removeBtn
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                font.pointSize: 10
                color: removeHover.hovered ? Theme.urgent : Theme.muted

                HoverHandler { id: removeHover }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: page.setEntries(
                        page.entries().filter((e, i) => i !== row.index))
                }
            }
        }
    }

    TextFieldRow {
        label: "Add command (Enter to add — runs at every login)"
        placeholder: "e.g. ~/.conky/conky-startup.sh"
        onAccepted: value => {
            if (value.trim() === "")
                return;
            page.setEntries(page.entries().concat(
                [{ command: value.trim(), enabled: true }]));
        }
    }

    Text {
        width: parent.width
        text: "New/re-enabled entries start at the next login or shell "
            + "restart; disabling doesn't kill a running process. ▲▼ "
            + "reorders the list (cosmetic — doesn't affect startup). "
            + "The delay chip counts seconds from session start before "
            + "that entry runs, independent of the others: e.g. Proton "
            + "Bridge at 0s and Mailspring at 10s gives Bridge a head "
            + "start without blocking anything else."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
