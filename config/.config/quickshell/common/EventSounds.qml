pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Silence system alert sounds while Do Not Disturb is on, leaving anything
// you actually asked to hear alone.
//
// The shell plays no sound of its own — notification audio comes from the
// application that sent the notification, not from the daemon that draws it.
// That is why DND could suppress a popup while its ping still came through:
// there was never anything on our side to mute.
//
// PipeWire tags each stream with media.role, which is the only thing that
// distinguishes an alert from content. libcanberra — what GTK apps use for
// event sounds — sets role=event, while Spotify reports role=music and video
// players report video or nothing. So muting role=event silences alerts and
// leaves music and video playing.
//
// KNOWN GAP, and it is not small: an app that plays its own audio file
// without tagging a role is indistinguishable from media here, and will still
// ping. Most Electron apps (Slack, Mailspring, Discord) do exactly that. The
// only lever for those is muting the whole application, which would also kill
// its call audio — so it is left to the app's own notification settings.
Singleton {
    id: root

    readonly property bool active:
        Settings.doNotDisturb && Settings.dndSilenceSounds

    // Alert roles only. Media roles are the whole point of the exercise, and
    // accessibility is never something to silence behind DND.
    //
    // Matched lower-cased against both spellings on purpose. Quickshell hands
    // back a display name rather than the raw PipeWire value — a stream that
    // pactl reports as `media.role = "event"` reads here as "Notification",
    // and `music` reads as "Music". Carrying both keeps this working whichever
    // form a future quickshell exposes.
    readonly property var silencedRoles: ["event", "notification"]

    function isSilenced(role) {
        return role !== undefined
            && root.silencedRoles.indexOf(String(role).toLowerCase()) >= 0;
    }

    // Same live-model pattern as AudioDevices: Pipewire.nodes is a constant
    // property holding a live model, so there is no nodesChanged to connect
    // to — this binding re-evaluates when the model's contents change, and
    // its own change signal is what tells us a stream appeared.
    //
    // EVERY stream is tracked, not just the ones we want. `properties` is
    // empty until a node is tracked, so filtering by media.role before
    // tracking finds nothing and tracks nothing — the roles read back as
    // undefined even for a stream pactl reports as music. Tracking first and
    // filtering afterwards is what breaks that circle.
    readonly property var streams:
        Pipewire.nodes.values.filter(n => n.isStream)

    PwObjectTracker { objects: root.streams }

    function init(): void {
        apply();
    }

    function apply(): void {
        let pending = false;
        for (const n of root.streams) {
            const role = (n.properties || {})["media.role"];
            if (role === undefined) {
                // Tracking has not bound this node's properties yet, so we
                // cannot tell what it is. Come back for it.
                pending = true;
                continue;
            }
            if (!root.isSilenced(role))
                continue;
            if (n.audio)
                n.audio.muted = root.active;
            else
                pending = true;
        }
        // A node exists a frame or two before tracking binds its properties
        // and audio object. Retry briefly rather than guess a single delay,
        // and give up rather than spin — a stream that legitimately carries no
        // role (a browser video) never resolves, and that is not a failure.
        if (pending && settle.tries < 8)
            settle.restart();
    }

    // Drives the mute in both directions, which is not optional: PulseAudio's
    // stream-restore persists mute state PER ROLE (the streams carry
    // module-stream-restore.id = "sink-input-by-media-role:event"). Muting
    // once therefore teaches it to mute every future alert, so leaving DND
    // would silence notification sounds permanently. Setting muted = active on
    // every alert stream we see undoes that as soon as one appears.
    onActiveChanged: {
        settle.tries = 0;
        apply();
    }

    onStreamsChanged: {
        settle.tries = 0;
        apply();
    }

    Timer {
        id: settle

        property int tries: 0

        interval: 40
        onTriggered: {
            settle.tries += 1;
            root.apply();
        }
    }
}
