import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../components"
import "../../common"

SettingsPage {
    id: page

    title: "Audio"

    readonly property var sinks:
        Pipewire.nodes.values.filter(n => n.isSink && n.audio !== null)
    readonly property var sources:
        Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio !== null)

    PwObjectTracker { objects: page.sinks.concat(page.sources) }

    function nodeLabel(n) {
        return n.description || n.nickname || n.name;
    }

    SectionLabel { text: "MASTER" }

    SliderRow {
        label: "Volume"
        from: 0
        to: 100
        step: 1
        suffix: "%"
        value: Math.round(Audio.volume * 100)
        onMoved: value => Audio.setVolume(value / 100)
    }

    ToggleRow {
        label: "Mute"
        checked: Audio.muted
        onToggled: value => {
            if (value !== Audio.muted)
                Audio.toggleMute();
        }
    }

    SectionLabel { text: "OUTPUT DEVICE" }

    Repeater {
        model: page.sinks

        Item {
            id: sinkRow

            required property var modelData

            readonly property bool isDefault:
                Pipewire.defaultAudioSink === modelData

            width: parent.width
            height: 24

            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: sinkRow.isDefault ? Theme.green : Theme.surface
            }

            Text {
                x: 16
                width: parent.width - 16
                anchors.verticalCenter: parent.verticalCenter
                text: page.nodeLabel(sinkRow.modelData)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: sinkRow.isDefault ? Theme.text : Theme.subtext
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached(
                    ["wpctl", "set-default", String(sinkRow.modelData.id)])
            }
        }
    }

    SectionLabel { text: "INPUT DEVICE" }

    Repeater {
        model: page.sources

        Item {
            id: srcRow

            required property var modelData

            readonly property bool isDefault:
                Pipewire.defaultAudioSource === modelData

            width: parent.width
            height: 24

            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: srcRow.isDefault ? Theme.green : Theme.surface
            }

            Text {
                x: 16
                width: parent.width - 16
                anchors.verticalCenter: parent.verticalCenter
                text: page.nodeLabel(srcRow.modelData)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: srcRow.isDefault ? Theme.text : Theme.subtext
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached(
                    ["wpctl", "set-default", String(srcRow.modelData.id)])
            }
        }
    }

    ButtonRow {
        label: "Per-app volumes and ports"
        buttonText: "Open mixer…"
        onClicked: Quickshell.execDetached(["pavucontrol-qt"])
    }
}
