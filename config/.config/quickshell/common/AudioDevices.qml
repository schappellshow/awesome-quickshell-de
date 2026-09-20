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

    // Sink node ids seen on the previous nodes change, so an arrival can
    // be told from a node that was simply always there.
    property var knownSinkIds: []

    // Set while our own `pactl set-card-profile` is in flight, so the
    // resulting card event doesn't read as a fresh hotplug.
    property bool switching: false

    function init() {
        refresh();
        probeDrm();     // so drmProbed is trustworthy before the first card poll
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

    // Profiles chosen from the Settings page, as
    // { card: { profile, connected } }. The cable state at the moment of
    // choosing is stored alongside, because that is what makes the choice
    // expire: picking the laptop speakers while a TV is attached has to
    // stick, but it should not still be binding three days later with the
    // cable long gone. See applyHdmiPolicy.
    property var manualProfiles: ({})

    function setProfile(cardName, profileName, manual) {
        if (manual === true) {
            const m = manualProfiles;
            m[cardName] = { profile: profileName, connected: hdmiConnected };
            manualProfiles = m;
        }
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
        // Level-triggered, not edge: a resume can restore an HDMI profile
        // without the connector state ever changing, so there is no edge
        // to catch. Safe to re-run because the condition clears itself the
        // moment the switch lands.
        applyHdmiPolicy();
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

    // ── HDMI profiles ──────────────────────────────────────────────────
    //
    // An HDMI port's "available" flag is NOT a precondition for using it.
    // That flag reflects the ELD — the block of capability data the display
    // sends back — and on Intel the ELD frequently never arrives: i915
    // comes out of a resume without pushing it, so every pin reads
    // monitor_present 0 while DRM plainly reports the connector connected.
    //
    // Selecting such a profile anyway works. The card switches, the sink
    // appears, and sound plays: the ELD describes what the display can
    // decode, it is not permission to send. So availability is used to
    // *label* HDMI outputs here, never to hide them and never to gate
    // switching to one. Anything else makes HDMI vanish from the settings
    // exactly when the user needs it.

    function profileHasPort(cardObj, portObj) {
        return portObj.profiles.indexOf(cardObj.activeProfile) >= 0;
    }

    function isHdmiProfile(name) {
        return /hdmi/i.test(name);
    }

    function activeProfileIsHdmi(cardObj) {
        return isHdmiProfile(cardObj.activeProfile);
    }

    // Highest-priority profile carrying this port, availability ignored.
    // On Intel HDA that picks "Digital Stereo (HDMI) Output + Analog Stereo
    // Input" over plain HDMI output, so moving sound to a TV doesn't cost
    // you the microphone.
    function bestProfileFor(cardObj, portObj) {
        let best = null;
        for (const p of cardObj.profiles) {
            if (p.name === "off" || p.name === "pro-audio")
                continue;
            if (portObj.profiles.indexOf(p.name) < 0)
                continue;
            if (best === null || p.priority > best.priority)
                best = p;
        }
        return best;
    }

    // Every HDMI/DisplayPort output the card physically has, whether or not
    // the display has identified itself — one entry per socket, each with
    // the profile that switches to it. This is what makes HDMI a permanent
    // choice in the settings rather than one that comes and goes.
    readonly property var hdmiOptions: {
        const out = [];
        for (const c of cards) {
            for (const p of c.ports) {
                if (p.type !== "HDMI")
                    continue;
                const best = bestProfileFor(c, p);
                if (best === null)
                    continue;
                out.push({
                    card: c.name,
                    port: p.name,
                    profile: best.name,
                    description: p.description,
                    detected: p.detected,
                    active: profileHasPort(c, p)
                });
            }
        }
        return out;
    }

    function selectHdmi(opt) {
        setProfile(opt.card, opt.profile, true);
    }

    // ── Following the cable ────────────────────────────────────────────
    // Driven by the DRM connector, never by port availability. The old
    // trigger — a port flipping to "detected" — cannot fire at all on
    // hardware whose ELD never arrives, which is why plugging in a TV did
    // nothing. DRM knows a cable is in even when the sound card doesn't.
    //
    // Symmetric on purpose: connected promotes the card onto HDMI,
    // disconnected puts it back. Nothing else decides.

    function bestHdmiProfile(cardObj) {
        // Prefer a socket the display actually identified itself on; with
        // no ELD anywhere, fall back to the highest-priority HDMI output,
        // which is the primary socket. A card with several HDMI sockets and
        // no ELD is a guess — and the reason every socket is listed in the
        // settings, so a wrong guess is one click to correct.
        let best = null;
        let detected = null;
        for (const p of cardObj.ports) {
            if (p.type !== "HDMI")
                continue;
            const prof = bestProfileFor(cardObj, p);
            if (prof === null)
                continue;
            if (p.detected && (detected === null || prof.priority > detected.priority))
                detected = prof;
            if (best === null || prof.priority > best.priority)
                best = prof;
        }
        return detected !== null ? detected : best;
    }

    function bestNonHdmiProfile(cardObj) {
        let best = null;
        for (const p of cardObj.profiles) {
            if (!p.available || p.name === "off" || p.name === "pro-audio")
                continue;
            if (isHdmiProfile(p.name))
                continue;
            if (best === null || p.priority > best.priority)
                best = p;
        }
        return best;
    }

    function applyHdmiPolicy() {
        if (!Settings.audioAutoSwitch || switching || !drmProbed)
            return;

        for (const c of cards) {
            const onHdmi = activeProfileIsHdmi(c);
            if (onHdmi === hdmiConnected)
                continue;               // already where the cable says

            // A choice made by hand stands until the cable state changes —
            // then it is stale and the policy takes over again. Without
            // this, picking the laptop speakers while a TV is attached
            // would be undone within the second.
            const m = manualProfiles[c.name];
            if (m !== undefined && m.profile === c.activeProfile
                && m.connected === hdmiConnected)
                continue;

            const best = hdmiConnected ? bestHdmiProfile(c)
                                       : bestNonHdmiProfile(c);
            if (best !== null) {
                setProfile(c.name, best.name);
                return;                 // one card at a time; re-runs on refresh
            }
        }
    }

    // ── HDMI audio that a resume left behind ───────────────────────────
    // i915 can come back from suspend with the display fully alive but
    // without re-pushing its ELD to the HDA codec. DRM then reports the
    // connector connected while every HDA pin reports monitor_present 0,
    // so no HDMI port is available, no HDMI profile exists, and there is
    // no sink to select. The Audio page shows nothing — indistinguishable
    // from an unplugged cable, which is exactly how it reads to the user.
    //
    // Cycling the output forces the modeset that re-pushes the ELD. That
    // is a display-visible action, so it is offered as a button rather
    // than done on a heuristic: guessing wrong here blanks both screens.

    readonly property bool anyHdmiPortAvailable: {
        for (const c of cards)
            for (const p of c.ports)
                if (p.type === "HDMI" && p.available)
                    return true;
        return false;
    }

    // Whether a cable is actually in is asked of the DRM connector, and
    // of nothing else. The two obvious sources are both wrong here:
    //
    //   - the HDA port's "available" flag is the very thing this section
    //     works around. It is stale in both directions after a resume —
    //     stuck unavailable with a TV attached, stuck available after the
    //     cable is pulled.
    //   - Quickshell.screens lists *enabled* outputs, not connected ones.
    //     Unplugging a display that X still holds a CRTC on leaves it in
    //     the list at full size, while xrandr calls it disconnected.
    //
    // /sys/class/drm/<card>-<connector>/status is the kernel's own answer
    // and disagrees with neither reality nor itself.
    property bool hdmiConnected: false
    property bool drmProbed: false

    // Connector names are like "card0-HDMI-A-1" / "card0-DP-1"; eDP is the
    // internal panel and would otherwise match "DP".
    function isExternalConnector(path) {
        const name = path.replace(/^.*\/card\d+-/, "").replace(/\/status$/, "");
        return /^(HDMI|DP)/i.test(name);
    }

    Process {
        id: drmProc
        command: ["sh", "-c", "grep -H . /sys/class/drm/*/status 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let any = false;
                let seen = false;
                for (const line of text.split("\n")) {
                    const bits = line.split(":");
                    if (bits.length < 2)
                        continue;
                    if (!root.isExternalConnector(bits[0]))
                        continue;
                    seen = true;
                    if (bits[1].trim() === "connected")
                        any = true;
                }
                root.hdmiConnected = any;
                // Without a single external connector to read, the answer
                // is unknown rather than "nothing is plugged in" — and
                // acting on unknown would revert a card off HDMI for no
                // reason on any system this probe cannot see.
                root.drmProbed = seen;
                // Re-check on every probe, not on hdmiConnected changing:
                // the common case is the value staying put across the
                // probe that first makes it trustworthy, which emits no
                // change signal at all.
                policyWatch.restart();
            }
        }
    }

    function probeDrm() {
        if (!drmProc.running)
            drmProc.running = true;
    }

    // A display is attached but the card offers no HDMI audio for it.
    // Named for the UI: these are the outputs the Reconnect button acts
    // on, so it reports xrandr's names, not the kernel's connector names.
    readonly property var staleHdmiOutputs:
        (ready && drmProbed && hdmiConnected && !anyHdmiPortAvailable)
            ? DisplayConfig.outputs.filter(o => /^(HDMI|DP)/i.test(o.name))
            : []

    // Off, then back to exactly the geometry it had. --auto would silently
    // re-place a display the user had positioned by hand.
    function reconnect(outputName) {
        let geom = "--auto";
        for (const o of DisplayConfig.outputs) {
            if (o.name !== outputName)
                continue;
            geom = (o.currentMode !== "" ? "--mode " + o.currentMode : "--auto")
                 + " --pos " + o.x + "x" + o.y
                 + " --rotate " + o.rotation
                 + (o.primary ? " --primary" : "");
        }
        Quickshell.execDetached(["sh", "-c",
            "xrandr --output " + outputName + " --off; sleep 2; "
          + "xrandr --output " + outputName + " " + geom]);
        recheck.restart();
    }

    // The port flips available a moment after the modeset lands, and the
    // pactl subscribe burst may be swallowed by the debounce mid-cycle
    Timer {
        id: recheck
        interval: 6000
        onTriggered: root.refresh()
    }

    // Plugging or unplugging a display changes neither the screen set (X
    // keeps a CRTC on a dead output) nor, with a stale port, anything
    // pactl reports — so there is no event to hang this on and the
    // connector has to be asked. Cheap: one grep of four sysfs files.
    Timer {
        running: true
        repeat: true
        interval: 4000
        triggeredOnStart: true
        onTriggered: root.probeDrm()
    }

    // DRM sees the change before the card does
    Timer {
        id: policyWatch
        interval: 1200
        onTriggered: root.applyHdmiPolicy()
    }

    // ── Bluetooth / USB: follow a newly connected sink ─────────────────

    // Pipewire.nodes is a constant property holding a live model, so there
    // is no nodesChanged to connect to — the binding below re-evaluates
    // when the model's contents change, and its own change signal is what
    // drives the watch.
    readonly property var sinkNodes:
        Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)

    onSinkNodesChanged: sinkWatch.restart()

    // A sink whose arrival means "the user just connected something":
    // a bluetooth speaker or a USB headset. Built-in analog is excluded —
    // it never "arrives", and treating it as external would make every
    // profile switch land back on the laptop speakers.
    //
    // HDMI is deliberately NOT here even though it is plainly external.
    // An HDMI sink exists only while the card sits on an HDMI profile, so
    // it is not a device but a view of one — and pinning it writes
    // default.configured.audio.sink to a node that routinely vanishes,
    // leaving a sticky pin (which outlives reboots) aimed at nothing.
    // HDMI is handled one level down, by the profile switch.
    function isExternal(node) {
        const p = node.properties || {};
        if (p["device.api"] === "bluez5")
            return true;
        if (String(node.name).indexOf("bluez_output.") === 0)
            return true;
        return p["device.bus"] === "usb";
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
