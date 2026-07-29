pragma Singleton
import QtQuick
import Quickshell

// User-managed autostart entries (Settings app → Autostart page).
// Stack-critical daemons (picom, greenclip, xss-lock, ...) stay in
// awesome's autostart.lua; this is for extras like conky.
Singleton {
    id: root

    // Settings load asynchronously: at startup-chain time the list may be
    // the [] default, so spawning also triggers when the real value
    // arrives. Guarded to one run per shell start; later edits to the list
    // only take effect next login (matches the Settings page's note).
    property bool spawned: false

    function init() {
        trySpawn();
    }

    function trySpawn() {
        const list = Settings.autostartExtra || [];
        if (spawned || list.length === 0)
            return;
        spawned = true;
        for (const e of list) {
            if (!e || e.enabled !== true || !e.command)
                continue;
            // pgrep guard so a shell restart doesn't spawn duplicates.
            // ^ anchor: the guard's own `sh -c pgrep ...` command line
            // contains the command string, so an unanchored -f pattern
            // matches itself and nothing ever spawns.
            const q = "'^" + e.command.replace(/'/g, "'\\''") + "'";
            let guarded = "pgrep -u $USER -f " + q + " >/dev/null || (" +
                e.command + " >/dev/null 2>&1 &)";
            // Delay is relative to session start, not to other entries —
            // each command backgrounds independently, so a later entry
            // waiting on an earlier one (e.g. Proton Bridge before
            // Mailspring) just needs a delay longer than the dependency
            // takes to come up.
            const delay = Number(e.delay) || 0;
            if (delay > 0)
                guarded = "sleep " + delay + "; " + guarded;
            Quickshell.execDetached(["sh", "-c", guarded]);
        }
    }

    Connections {
        target: Settings
        function onAutostartExtraChanged() { root.trySpawn(); }
    }
}
