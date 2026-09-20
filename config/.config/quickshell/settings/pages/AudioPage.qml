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

    // staleHdmiOutputs is computed against xrandr's view, which is only
    // re-read on hotplug — and the case this catches involves no hotplug
    Component.onCompleted: DisplayConfig.probe()

    // ── HDMI audio missing after a resume ──────────────────────────────

    SectionLabel {
        text: "HDMI AUDIO"
        visible: AudioDevices.staleHdmiOutputs.length > 0
    }

    Text {
        visible: AudioDevices.staleHdmiOutputs.length > 0
        width: parent.width
        text: "A display is connected but never told the sound card what "
            + "it can play, so HDMI shows as not detected below. You can "
            + "still select it and it will work. Reconnecting the output "
            + "asks the graphics driver to send that information again, "
            + "which restores surround formats and the display's name — "
            + "the screen will blank for a couple of seconds."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    Repeater {
        model: AudioDevices.staleHdmiOutputs

        ButtonRow {
            required property var modelData

            label: modelData.name + " — no audio"
            buttonText: "Reconnect"
            onClicked: AudioDevices.reconnect(modelData.name)
        }
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

    // HDMI sockets the machine has but isn't currently using. Listed
    // whether or not the display has identified itself, because "not
    // detected" is routinely wrong — the sound card can miss a TV that
    // DRM, X and your eyes all agree is plugged in. Selecting one forces
    // the card onto it, which works regardless.
    Repeater {
        model: AudioDevices.hdmiOptions.filter(o => !o.active)

        Item {
            id: hdmiRow

            required property var modelData

            width: parent.width
            height: 30

            Rectangle {
                width: 8
                height: 8
                radius: 4
                y: 6
                color: Theme.surface
            }

            Text {
                x: 16
                y: 0
                width: parent.width - 16
                text: hdmiRow.modelData.description
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: Theme.subtext
            }

            Text {
                x: 16
                y: 14
                width: parent.width - 16
                text: hdmiRow.modelData.detected
                    ? "Display detected — click to use it"
                    : "No display detected here — click to use it anyway"
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: 8
                color: Theme.muted
            }

            MouseArea {
                anchors.fill: parent
                onClicked: AudioDevices.selectHdmi(hdmiRow.modelData)
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

            // Unavailable profiles are mostly surround variants of sockets
            // with nothing in them — 20-odd entries of noise. An HDMI
            // *stereo* profile is the exception and is always kept:
            // "not available" there means the display never identified
            // itself, which is a routine lie on Intel and no reason to
            // refuse the choice. The active profile is kept regardless so
            // the chip always has something to name.
            readonly property var usable:
                profileRow.modelData.profiles.filter(p =>
                    p.available
                    || p.name === profileRow.modelData.activeProfile
                    || (/hdmi/i.test(p.name) && !/surround/i.test(p.name)))

            label: modelData.description
            current: modelData.activeProfile
            options: usable.map(p => ({
                label: p.description + (p.available ? "" : "  (not detected)"),
                value: p.name
            }))
            onSelected: value =>
                AudioDevices.setProfile(profileRow.modelData.name, value, true)
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
