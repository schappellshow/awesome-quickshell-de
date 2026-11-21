pragma Singleton
import QtQuick
import Quickshell

// What the quick-actions ring (ring/Ring.qml) can offer. This is the catalog
// only — id, label, glyph, whether it needs a window — and Settings.ringActions
// picks and orders from it. What each id DOES lives in Ring.qml's run(), next
// to the code that has to know about awesome and the other shell surfaces.
//
// `window: true` marks an action that acts on the client that was under the
// pointer when the ring opened; those are greyed out over the bare desktop.
//
// Glyphs are Nerd Font (Font Awesome range) code points, drawn in
// Theme.iconFont, so they take the theme color like every other icon here.
Singleton {
    id: root

    readonly property var all: [
        { id: "screenshot", label: "Screenshot",    glyph: "", window: false, tone: "blue"   },
        { id: "scratchpad", label: "Scratchpad",    glyph: "", window: false, tone: "teal"   },
        { id: "float",      label: "Float / tile",  glyph: "", window: true,  tone: "purple" },
        { id: "close",      label: "Close window",  glyph: "", window: true,  tone: "red"    },
        { id: "overview",   label: "Overview",      glyph: "", window: false, tone: "gold"   },
        { id: "launcher",   label: "Apps",          glyph: "", window: false, tone: "green"  },
        { id: "lock",       label: "Lock screen",   glyph: "", window: false, tone: "orange" },
        { id: "perf",       label: "Performance mode", glyph: "", window: false, tone: "brightBlue" },

        // Not in the default ring, available from Settings -> Mouse.
        { id: "terminal",   label: "Terminal",      glyph: "", window: false, tone: "teal"   },
        { id: "files",      label: "Files",         glyph: "", window: false, tone: "gold"   },
        { id: "settings",   label: "Settings",      glyph: "", window: false, tone: "blue"   },
        { id: "power",      label: "Power menu",    glyph: "", window: false, tone: "red"    },
        { id: "clipboard",  label: "Clipboard",     glyph: "", window: false, tone: "green"  },
        { id: "notifs",     label: "Notifications", glyph: "", window: false, tone: "orange" },
        { id: "theme",      label: "Dark / light",  glyph: "", window: false, tone: "purple" },
        { id: "maximize",   label: "Maximize",      glyph: "", window: true,  tone: "blue"   },
        { id: "fullscreen", label: "Fullscreen",    glyph: "", window: true,  tone: "teal"   },
        { id: "minimize",   label: "Minimize",      glyph: "", window: true,  tone: "gold"   },
        { id: "ontop",      label: "Keep on top",   glyph: "", window: true,  tone: "purple" }
    ]

    // The most that fit round one ring without the buttons touching.
    readonly property int maxItems: 8

    function byId(id) {
        return root.all.find(a => a.id === id) ?? null;
    }

    // Settings.ringActions -> catalog entries, in order, with unknown and
    // repeated ids dropped (a hand-edited file, or an id from a later
    // version) and the list cut to what fits.
    function resolve(ids) {
        const seen = {};
        const out = [];
        for (const id of (ids || [])) {
            const a = root.byId(id);
            if (a && !seen[id] && out.length < root.maxItems) {
                seen[id] = true;
                out.push(a);
            }
        }
        return out;
    }

    // Theme color for an entry. Looked up by name so the catalog stays plain
    // data and the colors keep following the wallpaper palette.
    function toneColor(tone) {
        switch (tone) {
        case "red":        return Theme.red;
        case "green":      return Theme.green;
        case "orange":     return Theme.orange;
        case "blue":       return Theme.blue;
        case "purple":     return Theme.purple;
        case "teal":       return Theme.teal;
        case "gold":       return Theme.gold;
        case "brightBlue": return Theme.brightBlue;
        }
        return Theme.accent;
    }
}
