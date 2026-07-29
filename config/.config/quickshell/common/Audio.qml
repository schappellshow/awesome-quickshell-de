pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default-sink volume/mute via PipeWire. All volume paths (hotkeys through
// `qs ipc call audio ...`, future bar pill) go through here so the OSD and
// any widgets always agree. Volume is capped at 100%.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink

    // Nodes only expose their properties while tracked
    PwObjectTracker { objects: [root.sink] }

    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false

    function setVolume(v) {
        if (ready)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function raise() { setVolume(volume + 0.05); }
    function lower() { setVolume(volume - 0.05); }

    function toggleMute() {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }
}
