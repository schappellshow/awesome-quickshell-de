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

    // No pinned sink means WirePlumber picks, which is what the Automatic
    // row stands for. Picking a device by hand writes the pin
    // (default.configured.audio.sink) and it then survives reboots — so
    // there has to be a way back out of it, or one click permanently stops
    // audio ever following anything you plug in.
    readonly property bool automatic:
        Pipewire.preferredDefaultAudioSink === null

    function nodeLabel(n) {
        return n.description || n.nickname || n.name;
    }

    // The pactl-side sink record matching the current default, for ports
    readonly property var defaultSinkInfo:
        Pipewire.defaultAudioSink !== null
            ? AudioDevices.sink(Pipewire.defaultAudioSink.name) : null

    readonly property var defaultSinkPorts:
        defaultSinkInfo !== null ? defaultSinkInfo.ports : []

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

    // Automatic: the default when nothing has been pinned, and the way back
    Item {
        width: parent.width
        height: 30

        Rectangle {
            width: 8
            height: 8
            radius: 4
            y: 6
            color: page.automatic ? Theme.green : Theme.surface
        }

        Text {
            x: 16
            y: 0
            width: parent.width - 16
            text: "Automatic"
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: page.automatic ? Theme.text : Theme.subtext
        }

        Text {
            x: 16
            y: 14
            width: parent.width - 16
            text: Pipewire.defaultAudioSink !== null
                ? "Following " + page.nodeLabel(Pipewire.defaultAudioSink)
                : "No output"
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: 8
            color: Theme.muted
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Pipewire.preferredDefaultAudioSink = null
        }
    }

    Repeater {
        model: page.sinks

        Item {
            id: sinkRow

            required property var modelData

            // Green tracks what is pinned, not what is merely playing —
            // otherwise Automatic and the active device would both look
            // selected and neither would explain the other.
            readonly property bool isPinned:
                Pipewire.preferredDefaultAudioSink === modelData

            width: parent.width
            height: 24

            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: sinkRow.isPinned ? Theme.green : Theme.surface
            }

            Text {
                x: 16
                width: parent.width - 16
                anchors.verticalCenter: parent.verticalCenter
                text: page.nodeLabel(sinkRow.modelData)
                    + (Pipewire.defaultAudioSink === sinkRow.modelData
                        && !sinkRow.isPinned ? "  (in use)" : "")
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: sinkRow.isPinned ? Theme.text : Theme.subtext
            }

            MouseArea {
                anchors.fill: parent
                onClicked:
                    Pipewire.preferredDefaultAudioSink = sinkRow.modelData
            }
        }
    }

    // ── Port ───────────────────────────────────────────────────────────
    // Which socket on the active device the sound leaves by: speakers vs
    // headphones vs HDMI. Hidden when there is only one, which is the case
    // for every bluetooth and USB sink.

    SectionLabel {
        text: "OUTPUT PORT"
        visible: page.defaultSinkPorts.length > 1
    }

    ComboRow {
        visible: page.defaultSinkPorts.length > 1
        label: page.defaultSinkInfo !== null
            ? page.defaultSinkInfo.description : ""
        current: page.defaultSinkInfo !== null
            ? page.defaultSinkInfo.activePort : ""
        options: page.defaultSinkPorts.map(p => ({
            label: p.description + (p.available ? "" : "  (not connected)"),
            value: p.name
        }))
        onSelected: value => {
            if (page.defaultSinkInfo !== null)
                AudioDevices.setPort(page.defaultSinkInfo.name, value);
        }
    }

    // ── Card profile ───────────────────────────────────────────────────
    // The control that actually decides whether an HDMI sink exists at all,
    // and the one whose absence made a TV unfixable from here. On a
    // bluetooth card the same list is A2DP vs headset, so this covers
    // "why is my speaker in call quality" too.

    SectionLabel {
        text: "DEVICE PROFILE"
        visible: AudioDevices.cards.length > 0
    }

    Repeater {
        model: AudioDevices.cards

        ComboRow {
            id: profileRow

            required property var modelData

            // Unavailable profiles are every HDMI output on an unplugged
            // laptop — 20-odd entries describing sockets with nothing in
            // them. The active one is kept regardless so the chip always
            // has something to name.
            readonly property var usable:
                profileRow.modelData.profiles.filter(
                    p => p.available || p.name === profileRow.modelData.activeProfile)

            label: modelData.description
            current: modelData.activeProfile
            options: usable.map(p => ({ label: p.description, value: p.name }))
            onSelected: value =>
                AudioDevices.setProfile(profileRow.modelData.name, value)
        }
    }

    InfoRow {
        visible: AudioDevices.ready && AudioDevices.cards.length === 0
        label: "Devices"
        value: "No sound cards found"
    }

    SectionLabel { text: "INPUT DEVICE" }

    Repeater {
        model: page.sources

        Item {
            id: srcRow

            required property var modelData

            readonly property bool isPinned:
                Pipewire.preferredDefaultAudioSource === modelData

            width: parent.width
            height: 24

            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: Pipewire.defaultAudioSource === srcRow.modelData
                    ? Theme.green : Theme.surface
            }

            Text {
                x: 16
                width: parent.width - 16
                anchors.verticalCenter: parent.verticalCenter
                text: page.nodeLabel(srcRow.modelData)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: Pipewire.defaultAudioSource === srcRow.modelData
                    ? Theme.text : Theme.subtext
            }

            MouseArea {
                anchors.fill: parent
                onClicked:
                    Pipewire.preferredDefaultAudioSource = srcRow.modelData
            }
        }
    }

    SectionLabel { text: "SWITCHING" }

    ToggleRow {
        label: "Follow newly connected devices"
        checked: Settings.audioAutoSwitch
        onToggled: value => Settings.audioAutoSwitch = value
    }

    Text {
        width: parent.width
        text: "Moves sound to a TV, bluetooth speaker or USB headset when "
            + "you connect it, and hands the choice back when you unplug "
            + "it. Picking a device above pins it instead — choose "
            + "Automatic to undo that."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    ButtonRow {
        label: "Per-app volumes and ports"
        buttonText: "Open mixer…"
        onClicked: Quickshell.execDetached(["pavucontrol-qt"])
    }
}
