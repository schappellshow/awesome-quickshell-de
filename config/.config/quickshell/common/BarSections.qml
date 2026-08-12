pragma Singleton
import QtQuick
import Quickshell

// The bar's section layout: what a section is, which slot it sits in, and
// the order of the sections within that slot.
//
// The bar has three slots — start, center and end — and each is drawn as one
// pill. That mirrors how the bar already looked (taglist pill at the top,
// clock in the middle, status cluster at the bottom) while letting any
// section be moved to any slot, so "clock next to the tray" is a setting
// rather than an edit.
//
// This file owns the *arrangement* only. Whether a section is shown is still
// its own Settings flag (showTray, showVolume, ...), read by the widget
// itself; `layout` republishes those as `shown` so the settings page can put
// arrangement and visibility on one row.
Singleton {
    id: root

    readonly property var slotIds: ["start", "center", "end"]

    // Canonical sections, in the order a fresh install gets them. This list
    // is also where a section that is new to a *saved* layout gets spliced
    // in, so adding one here doesn't strand existing users without it.
    readonly property var defaults: [
        { id: "tags",          label: "Tags",               slot: "start"  },
        { id: "clock",         label: "Clock",              slot: "center" },
        { id: "media",         label: "Media button",       slot: "end"    },
        { id: "tray",          label: "System tray",        slot: "end"    },
        { id: "notifications", label: "Notification bell",  slot: "end"    },
        { id: "volume",        label: "Volume",             slot: "end"    },
        { id: "network",       label: "Network",            slot: "end"    },
        { id: "bluetooth",     label: "Bluetooth",          slot: "end"    },
        { id: "sysmon",        label: "CPU/RAM",            slot: "end"    },
        { id: "nightlight",    label: "Night light",        slot: "end"    },
        { id: "lock",          label: "Screen lock",        slot: "end"    },
        { id: "battery",       label: "Battery",            slot: "end"    },
        { id: "layout",        label: "Layout indicator",   slot: "end"    }
    ]

    // Visibility, read explicitly so the bindings below are real
    // dependencies. A lookup by computed name (Settings["show" + id]) would
    // read the same values but is far easier to get subtly wrong, and this
    // is the one place the mapping is needed.
    readonly property var shownById: ({
        "tags":          Settings.showTags,
        "clock":         Settings.showClock,
        "media":         Settings.showMediaPill,
        "tray":          Settings.showTray,
        "notifications": Settings.showNotifBell,
        "volume":        Settings.showVolume,
        "network":       Settings.showNetwork,
        "bluetooth":     Settings.showBluetooth,
        "sysmon":        Settings.showSysMon,
        "nightlight":    Settings.showNightLight,
        "lock":          Settings.showScreenLock,
        "battery":       Settings.showBattery,
        "layout":        Settings.showLayoutBox
    })

    // The arrangement in effect: the saved order, with anything it doesn't
    // mention restored to its default position, and anything it mentions
    // that no longer exists dropped.
    //
    // Deliberately free of visibility, so the bar can rebuild its pills on
    // an arrangement change alone. Folding `shown` in here would re-home
    // every section on every visibility toggle.
    readonly property var arrangement: {
        const known = {};
        for (const d of defaults)
            known[d.id] = d;

        const out = [];
        const placed = {};

        // Saved entries first, in saved order.
        for (const s of (Settings.barSections || [])) {
            const d = s ? known[s.id] : null;
            if (!d || placed[d.id])
                continue;
            placed[d.id] = true;
            out.push({
                id: d.id,
                slot: root.slotIds.includes(s.slot) ? s.slot : d.slot
            });
        }

        // Then anything the save didn't know about, put back where it would
        // have been: straight after the nearest earlier default that IS
        // present, so a new section lands beside its neighbours rather than
        // at the bottom of the bar.
        for (let i = 0; i < defaults.length; i++) {
            const d = defaults[i];
            if (placed[d.id])
                continue;
            let at = out.length;
            for (let j = i - 1; j >= 0; j--) {
                const k = out.findIndex(o => o.id === defaults[j].id);
                if (k >= 0) {
                    at = k + 1;
                    break;
                }
            }
            out.splice(at, 0, { id: d.id, slot: d.slot });
            placed[d.id] = true;
        }
        return out;
    }

    // The arrangement dressed for the settings page: label and current
    // visibility alongside the position.
    readonly property var layout: {
        const labels = {};
        for (const d of defaults)
            labels[d.id] = d.label;
        return arrangement.map(s => ({
            id: s.id,
            slot: s.slot,
            label: labels[s.id],
            shown: root.shownById[s.id] !== false
        }));
    }

    function sectionsIn(slot) {
        return layout.filter(s => s.slot === slot);
    }

    // Slots are named for where they land, not for the abstraction: "start"
    // is the top of a vertical bar and the left of a horizontal one, and the
    // settings page should say which.
    function slotLabel(slot) {
        if (slot === "center")
            return "Middle";
        if (BarEdge.vertical)
            return slot === "start" ? "Top" : "Bottom";
        return slot === "start" ? "Left" : "Right";
    }

    // `arrangement` is a binding's value; the reordering helpers below work
    // on a copy so a half-finished rearrangement is never visible through it.
    function copyOf(entries) {
        return entries.map(s => ({ id: s.id, slot: s.slot }));
    }

    // Persist `entries` (a layout-shaped array) as the saved arrangement.
    // Only id and slot are stored: labels come from `defaults` so they can
    // be reworded, and visibility lives in its own settings.
    function persist(entries) {
        Settings.barSections = entries.map(s => ({ id: s.id, slot: s.slot }));
    }

    // Move a section one place earlier (-1) or later (+1) within its slot.
    // Sections in other slots are stepped over, so the arrows always move
    // the section by exactly one visible position on the bar.
    function move(id, delta) {
        const entries = copyOf(arrangement);
        const from = entries.findIndex(s => s.id === id);
        if (from < 0)
            return;
        const slot = entries[from].slot;

        let to = -1;
        for (let i = from + delta; i >= 0 && i < entries.length; i += delta)
            if (entries[i].slot === slot) {
                to = i;
                break;
            }
        if (to < 0)
            return;

        const swap = entries[from];
        entries[from] = entries[to];
        entries[to] = swap;
        persist(entries);
    }

    function canMove(id, delta) {
        const entries = arrangement;
        const from = entries.findIndex(s => s.id === id);
        if (from < 0)
            return false;
        for (let i = from + delta; i >= 0 && i < entries.length; i += delta)
            if (entries[i].slot === entries[from].slot)
                return true;
        return false;
    }

    // Send a section to `slot`, landing it at the end of that slot's run so
    // it appears where the eye expects — last in the group it just joined.
    function setSlot(id, slot) {
        const entries = copyOf(arrangement);
        const from = entries.findIndex(s => s.id === id);
        if (from < 0 || !slotIds.includes(slot))
            return;

        const moved = entries[from];
        moved.slot = slot;
        entries.splice(from, 1);

        let at = entries.length;
        for (let i = entries.length - 1; i >= 0; i--)
            if (entries[i].slot === slot) {
                at = i + 1;
                break;
            }
        entries.splice(at, 0, moved);
        persist(entries);
    }

    function cycleSlot(id) {
        const entry = arrangement.find(s => s.id === id);
        if (!entry)
            return;
        const i = slotIds.indexOf(entry.slot);
        setSlot(id, slotIds[(i + 1) % slotIds.length]);
    }

    function setShown(id, value) {
        switch (id) {
        case "tags":          Settings.showTags       = value; break;
        case "clock":         Settings.showClock      = value; break;
        case "media":         Settings.showMediaPill  = value; break;
        case "tray":          Settings.showTray       = value; break;
        case "notifications": Settings.showNotifBell  = value; break;
        case "volume":        Settings.showVolume     = value; break;
        case "network":       Settings.showNetwork    = value; break;
        case "bluetooth":     Settings.showBluetooth  = value; break;
        case "sysmon":        Settings.showSysMon     = value; break;
        case "nightlight":    Settings.showNightLight = value; break;
        case "lock":          Settings.showScreenLock = value; break;
        case "battery":       Settings.showBattery    = value; break;
        case "layout":        Settings.showLayoutBox  = value; break;
        }
    }

    // Back to the shipped arrangement. Visibility is left alone — it's a
    // separate decision, and silently re-showing sections someone turned off
    // would be a surprise.
    function reset() {
        Settings.barSections = [];
    }
}
