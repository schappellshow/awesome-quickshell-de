pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Named colour schemes: the storage and editing behind Settings → Appearance.
// Theme resolves the live palette out of Settings.colors; everything that
// puts values *into* Settings.colors lives here.
//
// Schemes are files handled by bin/color-scheme, one self-contained JSON per
// scheme, so sharing one is sending a file. A saved scheme always holds the
// FULL resolved palette rather than only the keys that differ from the
// default — a scheme is meant to travel, and half a palette would render as
// the recipient's defaults filling in the gaps rather than the author's
// design.
Singleton {
    id: root

    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/color-scheme"

    property var schemes: []
    property string directory: ""

    Component.onCompleted: {
        refresh();
        dirProc.running = true;
    }

    function refresh() {
        listProc.running = true;
    }

    // Every colour as it currently renders, defaults included.
    function fullPalette() {
        const out = { dark: ({}), light: ({}), palette: ({}) };
        for (const group of ["dark", "light"])
            for (const k of Theme.surfaceKeys)
                out[group][k.key] = String(Theme.colorOf(group, k.key));
        for (const k of Theme.paletteKeys)
            out.palette[k.key] = String(Theme.colorOf("palette", k.key));
        out.accent = String(Settings.accentColor);
        return out;
    }

    // JsonAdapter only persists a `var` on reassignment, so every edit
    // rebuilds the object rather than mutating the stored one.
    function setColor(group, key, value) {
        const all = JSON.parse(JSON.stringify(Settings.colors || ({})));
        if (all[group] === undefined || all[group] === null)
            all[group] = ({});
        all[group][key] = value;
        Settings.colors = all;
        Settings.colorScheme = "";   // no longer the scheme it was loaded from
    }

    function resetColor(group, key) {
        const all = JSON.parse(JSON.stringify(Settings.colors || ({})));
        if (all[group] !== undefined && all[group] !== null)
            delete all[group][key];
        Settings.colors = all;
        Settings.colorScheme = "";
    }

    // Back to Theme's built-in palette. Only ever called from the Appearance
    // page's own button.
    function resetAll() {
        Settings.colors = ({});
        Settings.accentColor = Theme.defaultColors.palette.blue;
        Settings.colorScheme = "";
    }

    function apply(scheme) {
        const next = ({});
        for (const group of ["dark", "light", "palette"])
            if (scheme[group] !== undefined && scheme[group] !== null)
                next[group] = scheme[group];
        Settings.colors = next;
        if (scheme.accent !== undefined && scheme.accent !== "")
            Settings.accentColor = scheme.accent;
        Settings.colorScheme = scheme.name !== undefined ? scheme.name : "";
    }

    function save(name) {
        if (name.trim() === "")
            return;
        saveProc.command = [root.helper, "save", name.trim(),
                            JSON.stringify(fullPalette())];
        saveProc.running = true;
        Settings.colorScheme = name.trim();
    }

    function remove(name) {
        removeProc.command = [root.helper, "delete", name];
        removeProc.running = true;
        if (Settings.colorScheme === name)
            Settings.colorScheme = "";
    }

    Process {
        id: listProc
        command: [root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.schemes = JSON.parse(text);
                } catch (e) {
                    root.schemes = [];
                }
            }
        }
    }

    Process {
        id: dirProc
        command: [root.helper, "dir"]
        stdout: StdioCollector {
            onStreamFinished: root.directory = text.trim()
        }
    }

    Process {
        id: saveProc
        onExited: (exitCode, exitStatus) => root.refresh()
    }

    Process {
        id: removeProc
        onExited: (exitCode, exitStatus) => root.refresh()
    }
}
