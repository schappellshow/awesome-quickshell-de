pragma Singleton
import QtQuick
import Quickshell

// Open/closed state of the native system dashboard (dashboard/Dashboard.qml),
// and the one toggle the SYS pill and `qs ipc call sysmon toggle` share.
//
// Two display modes (Settings.dashboardMode):
//   popout  hidden until toggled; hugs the bar, above windows.
//   pinned  always on the bar screen's desktop, below every window. The
//           pill / key then *raises* it above the windows until pressed again
//           (a peek), instead of hiding it.
// Which dashboard exists at all is Settings.sysmonDashboard: "native" (this)
// or "conky" (SysMon.toggleConky, unchanged).
Singleton {
    id: root

    readonly property bool useNative: Settings.sysmonDashboard !== "conky"
    readonly property bool pinned: useNative && Settings.dashboardMode === "pinned"

    // Popout shown / pinned dashboard raised
    property bool open: false
    property bool raised: false

    // The window exists (and sampling runs) only while this is true
    readonly property bool visible: useNative && (pinned || open)
    // Drawn above the windows
    readonly property bool above: useNative && (pinned ? raised : open)

    function toggle() {
        if (pinned)
            raised = !raised;
        else
            open = !open;
    }

    // A mode or dashboard change starts from a clean state
    onUseNativeChanged: { open = false; raised = false; }
    onPinnedChanged: { open = false; raised = false; }

    // ── Layout (gear panel in the dashboard, mirrored in Settings -> Bar) ──

    // Name of the screen the dashboard is on (set by Dashboard.qml)
    property string screenName: ""

    // The gear panel is open. Never outlives the window.
    property bool settingsOpen: false
    onVisibleChanged: if (!visible) settingsOpen = false

    readonly property var cardIds: ["system", "cpu", "memory", "drives", "network", "gpu"]
    readonly property var defaultOrder: ["system", "memory", "cpu", "drives", "gpu", "network"]

    function cardTitle(id) {
        switch (id) {
        case "system":  return "System";
        case "cpu":     return "Processors";
        case "memory":  return "Memory";
        case "drives":  return "Drives";
        case "network": return "Network";
        default:        return "GPU";
        }
    }

    // Whether a card is shown: the existing dashSection* switches, so a
    // settings.json from before the order existed keeps working.
    function cardEnabled(id) {
        switch (id) {
        case "system":  return Settings.dashSectionSystem;
        case "cpu":     return Settings.dashSectionCpu;
        case "memory":  return Settings.dashSectionMemory;
        case "drives":  return Settings.dashSectionDrives;
        case "network": return Settings.dashSectionNetwork;
        default:        return Settings.dashSectionGpu;
        }
    }

    function setCardEnabled(id, on) {
        switch (id) {
        case "system":  Settings.dashSectionSystem = on; break;
        case "cpu":     Settings.dashSectionCpu = on; break;
        case "memory":  Settings.dashSectionMemory = on; break;
        case "drives":  Settings.dashSectionDrives = on; break;
        case "network": Settings.dashSectionNetwork = on; break;
        default:        Settings.dashSectionGpu = on; break;
        }
    }

    // Saved order, repaired: unknown or repeated ids dropped, missing ones
    // appended in default order, so a hand-edited value cannot lose a card.
    function normalizeOrder(text) {
        const out = [];
        for (const raw of String(text).split(",")) {
            const id = raw.trim();
            if (root.cardIds.includes(id) && !out.includes(id))
                out.push(id);
        }
        for (const id of root.defaultOrder)
            if (!out.includes(id))
                out.push(id);
        return out;
    }

    readonly property var order: root.normalizeOrder(Settings.dashOrder)

    // Visible cards in order; they flow left, right, left, right.
    readonly property var shownCards: root.order.filter(id => root.cardEnabled(id))
    readonly property var leftCards: root.shownCards.filter((id, i) => i % 2 === 0)
    readonly property var rightCards: root.shownCards.filter((id, i) => i % 2 === 1)

    function moveCard(id, delta) {
        const o = root.order.slice();
        const i = o.indexOf(id), j = i + delta;
        if (i < 0 || j < 0 || j >= o.length)
            return;
        o[i] = o[j];
        o[j] = id;
        Settings.dashOrder = o.join(",");
    }

    readonly property var positionIds:
        ["bar", "topleft", "topright", "bottomleft", "bottomright", "center", "custom"]

    function positionLabel(id) {
        switch (id) {
        case "topleft":     return "Top left";
        case "topright":    return "Top right";
        case "bottomleft":  return "Bottom left";
        case "bottomright": return "Bottom right";
        case "center":      return "Center";
        case "custom":      return "Custom";
        default:            return "Beside bar";
        }
    }

    readonly property string position:
        root.positionIds.includes(Settings.dashboardPosition) ? Settings.dashboardPosition : "bar"

    // Remembered spot of the "custom" position: ONE offset, the window's
    // top-left in global coordinates minus the primary monitor's top-left
    // (common/PrimaryScreen.qml), saved as "[dx, dy]". Offsets rather than
    // per-screen spots because the dashboard may sit on any monitor.
    //
    // Older files saved per screen name, {"DP-3": [44, 470]} with the spot
    // local to that screen. Those are read as: the primary's entry, else any
    // entry, converted through that screen's origin (or taken as is if the
    // monitor is gone). The next save writes the new form.
    function customOffset() {
        const prim = PrimaryScreen.screen;
        if (!prim)
            return null;
        const ok = p => Array.isArray(p) && p.length === 2
            && isFinite(p[0]) && isFinite(p[1]);
        try {
            const v = JSON.parse(Settings.dashboardCustomPos || "{}");
            if (ok(v))
                return [Number(v[0]), Number(v[1])];
            if (typeof v !== "object" || v === null || Array.isArray(v))
                return null;
            const name = ok(v[prim.name]) ? prim.name
                : Object.keys(v).find(k => ok(v[k]));
            if (name === undefined)
                return null;
            const src = Quickshell.screens.find(s => s.name === name);
            return src ? [src.x + Number(v[name][0]) - prim.x,
                          src.y + Number(v[name][1]) - prim.y]
                       : [Number(v[name][0]), Number(v[name][1])];
        } catch (e) {}
        return null;
    }

    // The saved spot in global coordinates, or null if never placed
    function customGlobal() {
        const off = root.customOffset();
        const prim = PrimaryScreen.screen;
        return off && prim ? [prim.x + off[0], prim.y + off[1]] : null;
    }

    // Remember a spot given in global coordinates
    function setCustomGlobal(gx, gy) {
        const prim = PrimaryScreen.screen;
        if (!prim)
            return;
        Settings.dashboardCustomPos = JSON.stringify(
            [Math.round(gx - prim.x), Math.round(gy - prim.y)]);
    }

    // Background opacity of the panel and cards, 0.4–1; text is unaffected.
    readonly property real bgAlpha: Math.max(40, Math.min(100, Settings.dashboardOpacity)) / 100

    function fade(c) { return Qt.rgba(c.r, c.g, c.b, c.a * root.bgAlpha); }

    Binding {
        target: SysStats
        property: "active"
        value: root.visible
    }
}
