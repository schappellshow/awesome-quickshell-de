pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard shortcuts, as edited in Settings -> Keyboard.
//
// The list of shortcuts is NOT defined here. awesome's modules/keys.lua owns
// it — the id, the label, the default chord and the function behind it are
// one entry there — and writes the first four to a file on every start. This
// reads that file, so the page is generated from the bindings rather than
// from a copy of them that would drift the first time one was added.
//
// Only what differs from the default is stored, the same rule the rest of
// settings.json follows: an untouched shortcut has no entry, so changing a
// default in keys.lua reaches everyone who never rebound it.
Singleton {
    id: root

    // [{ id, group, label, chord, client }] — chord is the DEFAULT.
    property var registry: []

    // Set while awesome has the keyboard grabbed, waiting for a chord. Empty
    // when nothing is being recorded.
    property string capturing: ""

    // Set when a capture landed on a chord that is already spoken for; the
    // row shows it and nothing is written.
    property string conflict: ""

    readonly property string registryPath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/awesomewm-shortcuts.json"

    readonly property var overrides: Settings.shortcuts || ({})

    // The user's own shortcuts: [{ id, command, chord }]. Ids are prefixed so
    // one function can tell which store an id belongs to without asking.
    readonly property var custom: Settings.customShortcuts || []

    // ── Reading ──────────────────────────────────────────────────────────

    function entry(id) {
        return root.registry.find(e => e.id === id) ?? null;
    }

    function isCustom(id) {
        return String(id).startsWith("custom.");
    }

    function customEntry(id) {
        return root.custom.find(e => e.id === id) ?? null;
    }

    function chordFor(id) {
        if (root.isCustom(id)) {
            const c = root.customEntry(id);
            return c ? (c.chord || "") : "";
        }
        const over = root.overrides[id];
        if (over !== undefined && over !== "")
            return over;
        const e = root.entry(id);
        return e ? e.chord : "";
    }

    // What to call a shortcut in a message. A custom one has no name of its
    // own beyond the command it runs, which is the honest thing to show.
    function labelFor(id) {
        if (root.isCustom(id)) {
            const c = root.customEntry(id);
            return c ? c.command : id;
        }
        const e = root.entry(id);
        return e ? e.label : id;
    }

    function isOverridden(id) {
        const over = root.overrides[id];
        return over !== undefined && over !== "" && over !== root.defaultFor(id);
    }

    function defaultFor(id) {
        const e = root.entry(id);
        return e ? e.chord : "";
    }

    // The shortcut already using this chord, or null. Global and per-client
    // bindings share one namespace on purpose: a client key shadows a global
    // one whenever a window has focus, which is a clash however it is filed.
    function holderOf(chord, exceptId) {
        const hit = root.registry.find(
            e => e.id !== exceptId && root.chordFor(e.id) === chord);
        if (hit)
            return hit.id;
        const mine = root.custom.find(
            e => e.id !== exceptId && (e.chord || "") === chord);
        return mine ? mine.id : null;
    }

    // The groups present, in registry order rather than alphabetically — the
    // registry is already ordered the way the cheatsheet reads.
    function groups() {
        const out = [];
        for (const e of root.registry)
            if (!out.includes(e.group))
                out.push(e.group);
        return out;
    }

    function inGroup(group) {
        return root.registry.filter(e => e.group === group);
    }

    // ── Display ──────────────────────────────────────────────────────────

    readonly property var modLabels: ({
        "Mod4": "Super", "Mod1": "Alt", "Control": "Ctrl", "Shift": "Shift"
    })

    // Keys whose X name is not what anyone calls them. Anything absent is
    // shown as-is, with a lone letter capitalised.
    readonly property var keyLabels: ({
        "space": "Space", "Return": "Enter", "BackSpace": "Backspace",
        "Escape": "Esc", "Print": "Print", "Tab": "Tab",
        "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
        "XF86AudioMute": "Mute",
        "XF86MonBrightnessUp": "Bright+",
        "XF86MonBrightnessDown": "Bright-"
    })

    function pretty(chord) {
        if (chord === "")
            return "—";
        const parts = String(chord).split("+");
        const key = parts.pop();
        const out = parts.map(m => root.modLabels[m] || m);
        out.push(root.keyLabels[key]
            || (key.length === 1 ? key.toUpperCase() : key));
        return out.join("+");
    }

    // ── Writing ──────────────────────────────────────────────────────────

    // JsonAdapter only persists a var on reassignment, so every change is a
    // copy, a mutation and an assignment rather than an edit in place.
    function store(next) {
        Settings.shortcuts = next;
    }

    function setChord(id, chord) {
        const clash = root.holderOf(chord, id);
        if (clash) {
            root.conflict = root.labelFor(clash);
            return false;
        }
        root.conflict = "";
        if (root.isCustom(id)) {
            Settings.customShortcuts = root.custom.map(
                e => e.id === id ? Object.assign({}, e, { chord: chord }) : e);
            return true;
        }
        const next = JSON.parse(JSON.stringify(root.overrides));
        if (chord === root.defaultFor(id))
            delete next[id];
        else
            next[id] = chord;
        root.store(next);
        return true;
    }

    // ── The user's own ───────────────────────────────────────────────────

    // Added without a chord: a shortcut with nothing bound to it is inert,
    // and asking for the command and the chord in one step would mean a
    // dialog where the rest of this page has rows.
    function addCustom(command) {
        const clean = String(command).replace(/[\r\n]+/g, " ").trim();
        if (clean === "")
            return;
        const id = "custom." + Date.now().toString(36)
            + Math.floor(Math.random() * 1296).toString(36);
        Settings.customShortcuts = root.custom.concat(
            [{ id: id, command: clean, chord: "" }]);
    }

    function removeCustom(id) {
        root.conflict = "";
        Settings.customShortcuts = root.custom.filter(e => e.id !== id);
    }

    function reset(id) {
        if (root.isCustom(id))
            return;
        root.conflict = "";
        const next = JSON.parse(JSON.stringify(root.overrides));
        delete next[id];
        root.store(next);
    }

    function resetAll() {
        root.conflict = "";
        root.store({});
    }

    function overriddenCount() {
        return root.registry.filter(e => root.isOverridden(e.id)).length;
    }

    // ── Capture ──────────────────────────────────────────────────────────

    function startCapture(id) {
        root.conflict = "";
        root.capturing = id;
        giveUp.restart();
        AwesomeState.exec(
            `if shortcut_capture then shortcut_capture("${id}") end`);
    }

    // Nothing comes back if awesome has not been reloaded since the capture
    // entry point shipped, or if it dies holding the grab. Without this the
    // row sits on "Press a chord…" for the rest of the session.
    Timer {
        id: giveUp
        interval: 15000
        onTriggered: root.stopCapture()
    }

    // Also the way out when the settings window closes mid-capture: awesome
    // is holding the keyboard, and nothing else would ever hand it back.
    function stopCapture() {
        if (root.capturing === "")
            return;
        root.capturing = "";
        giveUp.stop();
        AwesomeState.exec(
            "if shortcut_capture_stop then shortcut_capture_stop() end");
    }

    // Called from shell.qml's IPC handler when awesome has a chord.
    function captured(id, chord) {
        root.capturing = "";
        giveUp.stop();
        root.setChord(id, chord);
    }

    // ── Pushing to awesome ───────────────────────────────────────────────

    function init() {
        settle.restart();
    }

    // "id=chord" per line. Not JSON: awesome has no parser for it, and a key
    // name can never contain a newline — which no other separator can
    // promise, since ; | and , are all keys somebody might bind.
    function payload() {
        const lines = [];
        for (const e of root.registry) {
            const chord = root.chordFor(e.id);
            if (chord !== "" && chord !== e.chord)
                lines.push(e.id + "=" + chord);
        }
        return lines.join("\n");
    }

    // "chord=command" per line, the other way round from the overrides: the
    // command is free text and can contain further = signs, so it has to be
    // the half that runs to the end of the line.
    function customPayload() {
        const lines = [];
        for (const e of root.custom) {
            if ((e.chord || "") !== "" && (e.command || "") !== "")
                lines.push(e.chord + "=" + e.command);
        }
        return lines.join("\n");
    }

    // Escaped for the Lua string literal it lands in, backslash first so the
    // escapes added after it are not escaped again. It matters twice here:
    // the layout-cycling key IS a backslash, and a command is whatever
    // somebody typed.
    function luaString(text) {
        return text
            .replace(/\\/g, "\\\\")
            .replace(/"/g, '\\"')
            .replace(/\n/g, "\\n");
    }

    function push() {
        AwesomeState.exec(
            "if apply_shortcuts then apply_shortcuts(\""
            + root.luaString(root.payload()) + "\", \""
            + root.luaString(root.customPayload()) + "\") end");
    }

    // A restart rebuilds every binding from keys.lua's defaults, so the
    // overrides have to go back on — the same reason WindowMode watches it.
    readonly property string trigger:
        JSON.stringify(root.overrides) + "|" + JSON.stringify(root.custom)
            + "|" + AwesomeState.epoch + "|" + root.registry.length

    onTriggerChanged: settle.restart()

    Timer {
        id: settle
        interval: 250
        onTriggered: root.push()
    }

    FileView {
        id: file
        path: root.registryPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.registry = JSON.parse(file.text());
            } catch (e) {
                root.registry = [];
            }
        }
        onLoadFailed: root.registry = []
    }
}
