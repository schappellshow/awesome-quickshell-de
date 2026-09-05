pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Card profiles, ports, and the "follow what you just plugged in" policy.
//
// Quickshell's Pipewire service models nodes but has no device/card type,
// so everything at card level — which profiles exist, which ports are
// available, what the card is currently on — comes from `pactl -f json`.
//
// That gap matters more than it sounds. On a laptop with a single HDA card
// the HDMI sink does not exist until the card is switched to an HDMI
// profile, so "no sound on the TV" is usually not a wrong-default-sink
// problem you could fix by picking a device: there is no device to pick.
// Sinks alone (which is all AudioPage used to show) cannot express that.
//
// Two independent switches therefore live here:
//   - profile-level, for HDMI: an output port going available promotes the
//     card onto a profile that carries it
//   - node-level, for bluetooth/USB: a new external sink becomes the
//     default, and stops being it when unplugged
Singleton {
    id: root

    // [{ name, description, activeProfile,
    //    profiles: [{ name, description, available, priority }],
    //    ports:    [{ name, description, type, available, profiles }] }]
    property var cards: []

    // [{ name, description, card, activePort,
    //    ports: [{ name, description, type, available, priority }] }]
    //
    // Separate from `cards` because a port is chosen on the sink
    // (`set-sink-port`) even though it is described on the card, and only
    // the sink knows which one is currently active.
    property var sinks: []

    // False until the first pactl listing lands, so the Audio page can say
    // "no card control" rather than flash an empty section at startup.
    property bool ready: false

    // Port availability from the previous poll, as { "card:port": bool }.
    // The HDMI switch is edge-triggered off this: acting on the level
    // instead would re-issue set-card-profile on every poll and fight both
    // WirePlumber and the user's own choice.
    property var portWasAvailable: ({})

    // Sink node ids seen on the previous nodes change, for the same reason.
    property var knownSinkIds: []

    // Set while our own `pactl set-card-profile` is in flight, so the
    // resulting card event doesn't read as a fresh hotplug.
    property bool switching: false

    property bool primed: false

    function init() {
        refresh();
        monitor.running = true;
    }

    // ── Model ──────────────────────────────────────────────────────────

    function refresh() {
        if (!cardProc.running)
            cardProc.running = true;
        if (!sinkProc.running)
            sinkProc.running = true;
    }

    function card(name) {
        for (const c of cards)
            if (c.name === name)
                return c;
        return null;
    }

    function sink(name) {
        for (const s of sinks)
            if (s.name === name)
                return s;
        return null;
    }

    function setProfile(cardName, profileName) {
        switching = true;
        switchGuard.restart();
        Quickshell.execDetached(
            ["pactl", "set-card-profile", cardName, profileName]);
        settle.restart();
    }

    function setPort(sinkName, portName) {
        Quickshell.execDetached(
            ["pactl", "set-sink-port", sinkName, portName]);
        settle.restart();
    }

    Timer {
        id: switchGuard
        interval: 4000
        onTriggered: root.switching = false
    }

    // pactl reports the new state a moment after the command lands
    Timer {
        id: settle
        interval: 600
        onTriggered: root.refresh()
    }

    Process {
        id: cardProc
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector { onStreamFinished: root.parseCards(text) }
    }

    Process {
        id: sinkProc
        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector { onStreamFinished: root.parseSinks(text) }
    }

    // `pactl subscribe` prints a line per event; cards appear/disappear and
    // change profile, sinks come and go. Cheaper and far more responsive
    // than polling, and it is the only way to see a port flip to available
    // without a timer.
    Process {
        id: monitor
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: line => {
                if (/ on (card|sink|server)/.test(line))
                    debounce.restart();
            }
        }
    }

    // A single hotplug emits a burst of events
    Timer {
        id: debounce
        interval: 400
        onTriggered: root.refresh()
    }

    function parseCards(text) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return;                 // pactl absent or output truncated
        }

        const out = [];
        for (const c of data) {
            const profiles = [];
            for (const name in c.profiles) {
                const p = c.profiles[name];
                profiles.push({
                    name: name,
                    description: p.description || name,
                    available: p.available !== false,
                    priority: p.priority || 0
                });
            }
            profiles.sort((a, b) => b.priority - a.priority);

            const ports = [];
            for (const name in c.ports) {
                const p = c.ports[name];
                ports.push({
                    name: name,
                    description: p.description || name,
                    type: p.type || "",
                    // pactl spells this "availability unknown" for ports
                    // that cannot be probed (built-in speakers). Unknown
                    // means usable — only an explicit "not available" is a
                    // port that isn't there.
                    available: p.availability !== "not available",
                    // Whether the port was *detected*, as opposed to merely
                    // not disprovable. Only a detected port should promote
                    // a card onto a new profile.
                    detected: p.availability === "available",
                    priority: p.priority || 0,
                    profiles: p.profiles || []
                });
            }
            ports.sort((a, b) => b.priority - a.priority);

            out.push({
                name: c.name,
                description: (c.properties
                    && c.properties["device.description"]) || c.name,
                activeProfile: c.active_profile || "",
                profiles: profiles,
                ports: ports
            });
        }

        cards = out;
        ready = true;
        autoSwitchProfiles();
    }

    function parseSinks(text) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return;
        }

        const out = [];
        for (const s of data) {
            const ports = [];
            for (const p of (s.ports || [])) {
                ports.push({
                    name: p.name,
                    description: p.description || p.name,
                    type: p.type || "",
                    available: p.availability !== "not available",
                    priority: p.priority || 0
                });
            }
            ports.sort((a, b) => b.priority - a.priority);

            out.push({
                name: s.name,
                description: s.description || s.name,
                card: (s.properties
                    && s.properties["device.name"]) || "",
                // pactl prints the string "null" (not JSON null) when a
                // sink has no ports at all, which every virtual sink does
                activePort: (s.active_port && s.active_port !== "null")
                    ? s.active_port : "",
                ports: ports
            });
        }
        sinks = out;
    }

    // ── HDMI: promote the card when an output port shows up ────────────

    function profileHasPort(cardObj, portObj) {
        return portObj.profiles.indexOf(cardObj.activeProfile) >= 0;
    }

    // Best profile carrying this port: highest priority among the card's
    // available ones. On Intel HDA that picks "Digital Stereo (HDMI) Output
    // + Analog Stereo Input" over plain HDMI output, so plugging in a TV
    // doesn't cost you the microphone.
    function bestProfileFor(cardObj, portObj) {
        let best = null;
        for (const p of cardObj.profiles) {
            if (!p.available || p.name === "off")
                continue;
            if (portObj.profiles.indexOf(p.name) < 0)
                continue;
            if (best === null || p.priority > best.priority)
                best = p;
        }
        return best;
    }

    function autoSwitchProfiles() {
        const seen = {};
        let act = null;

        for (const c of cards) {
            for (const p of c.ports) {
                const key = c.name + ":" + p.name;
                seen[key] = p.detected;

                // Only outputs, only HDMI/DisplayPort. Headphones already
                // switch by port within the analog profile, which works.
                if (p.type !== "HDMI")
                    continue;
                // Edge: not previously detected, detected now
                if (!p.detected || portWasAvailable[key] === true)
                    continue;
                // Already on a profile that carries it — nothing to do,
                // WirePlumber got there first
                if (profileHasPort(c, p))
                    continue;

                // Ports are sorted by priority, so the first port that
                // wants a switch is the best one to honour — plugging into
                // two HDMI sockets at once should follow the primary.
                const best = bestProfileFor(c, p);
                if (best !== null && act === null)
                    act = { card: c.name, profile: best.name };
            }
        }

        const first = !primed;
        portWasAvailable = seen;
        primed = true;

        // The first poll of a session establishes the baseline; every port
        // looks "new" then, and a display connected at login was already
        // handled by WirePlumber.
        if (first || !Settings.audioAutoSwitch || switching || act === null)
            return;

        setProfile(act.card, act.profile);
    }

    // ── Bluetooth / USB: follow a newly connected sink ─────────────────

    // Pipewire.nodes is a constant property holding a live model, so there
    // is no nodesChanged to connect to — the binding below re-evaluates
    // when the model's contents change, and its own change signal is what
    // drives the watch.
    readonly property var sinkNodes:
        Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)

    onSinkNodesChanged: sinkWatch.restart()

    // A sink that arriving means "the user just connected something": a
    // bluetooth speaker, a USB headset, an HDMI display. Built-in analog
    // is excluded — it never "arrives", and treating it as external would
    // make every profile switch back to the laptop speakers.
    function isExternal(node) {
        const p = node.properties || {};
        if (p["device.api"] === "bluez5")
            return true;
        if (String(node.name).indexOf("bluez_output.") === 0)
            return true;
        if (p["device.bus"] === "usb")
            return true;
        return String(p["api.alsa.path"] || node.name).indexOf("hdmi") >= 0;
    }

    // Nodes land in several steps (the node, then its audio interface,
    // then its properties), so read the set once it has settled
    Timer {
        id: sinkWatch
        interval: 500
        onTriggered: root.autoSwitchSink()
    }

    function autoSwitchSink() {
        const ids = [];
        let arrived = null;

        for (const n of sinkNodes) {
            ids.push(n.id);
            if (knownSinkIds.indexOf(n.id) < 0 && isExternal(n))
                arrived = n;
        }

        const pinned = Pipewire.preferredDefaultAudioSink;
        const pinnedGone = pinned !== null && ids.indexOf(pinned.id) < 0;
        const first = knownSinkIds.length === 0;
        knownSinkIds = ids;

        if (!Settings.audioAutoSwitch)
            return;

        // The pinned device was unplugged. Clearing the pin rather than
        // pointing it somewhere else hands the choice back to WirePlumber,
        // which is what "automatic" should mean — and stops a dead
        // bluetooth speaker from suppressing every later auto-switch.
        if (pinnedGone) {
            Pipewire.preferredDefaultAudioSink = null;
            return;
        }

        if (first || arrived === null)
            return;

        Pipewire.preferredDefaultAudioSink = arrived;
    }
}
