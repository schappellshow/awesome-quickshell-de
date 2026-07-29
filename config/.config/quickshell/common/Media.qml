pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// MPRIS media state. `active` is the player the bar/panel shows: the first
// one actually playing, else the first available (Spotify, browsers, mpv...).
// The panel opens on one screen at a time, tracked by output name in openOn.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    readonly property var active: players.find(p => p.isPlaying)
                                  ?? (players.length > 0 ? players[0] : null)

    // Output name of the screen whose panel is open, or "" when closed
    property string openOn: ""

    function toggleOn(screenName) {
        openOn = (openOn === screenName) ? "" : screenName;
    }

    function close() {
        openOn = "";
    }

    // Super+a: open on awesome's focused screen. Asks awesome because focus
    // is mouse/keyboard state quickshell can't see; falls back to the first
    // screen if awesome isn't running (e.g. testing under Plasma).
    function toggleFocused() {
        if (openOn !== "") {
            openOn = "";
            return;
        }
        focusQuery.handled = false;
        focusQuery.running = true;
    }

    function openFallback() {
        root.openOn = Quickshell.screens[0]?.name ?? "";
    }

    Process {
        id: focusQuery

        property bool handled: false

        command: ["awesome-client", 'return require("awful").screen.focused().index']

        stdout: SplitParser {
            onRead: data => {
                if (focusQuery.handled)
                    return;
                focusQuery.handled = true;

                const m = data.match(/(\d+)/);
                const scr = m ? AwesomeState.screens.find(s => s.index === parseInt(m[1])) : null;
                if (scr && (scr.outputs || []).length > 0)
                    root.openOn = scr.outputs[0];
                else
                    root.openFallback();
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (!handled) {
                handled = true;
                root.openFallback();
            }
        }
    }
}
