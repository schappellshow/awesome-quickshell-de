pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Performance mode, and window animations.
//
// Both are compositor settings, so both end in one call to
// bin/.local/bin/picom-effects, which restarts the picom of THIS display on
// the matching config parts (config/.config/picom/): the animation preset
// from Settings, and performance on/off. Performance mode wins: it turns
// blur, shadows, fades, animations and inactive transparency off and lets a
// fullscreen window bypass the compositor; turning it off puts back exactly
// what Settings says, preset included, because the preset is never
// overwritten — it is only not applied while performance mode is on.
//
// Performance mode is on when EITHER
//   * it was turned on by hand (`manual`: Super+Alt+G, `qs ipc call perf
//     toggle`, the Settings switch), or
//   * Settings.perfAutoGame is set and Feral GameMode reports a running game.
// So a game ending switches it off again, unless it was also turned on by
// hand, in which case it stays on. If you switch it off while a game is
// still running, that is respected until the game count next reaches zero.
//
// None of the on/off state is persisted: a restart starts with it off (and
// picks a running game up again from GameMode).
//
// GameMode is watched over the session bus: dbus-monitor follows the
// GameRegistered / GameUnregistered signals and NameOwnerChanged, and each
// one triggers a fresh read of the ClientCount property rather than
// counting signals, so a missed signal can't leave the count wrong.
// dbus-monitor/dbus-send are used because nothing in quickshell speaks to
// arbitrary D-Bus services.
Singleton {
    id: root

    // Switched on by hand.
    property bool manual: false
    // Running games according to GameMode.
    property int gameCount: 0
    // Hand-switched off while a game was driving it; lasts until gameCount
    // is next 0.
    property bool gameSuppressed: false

    readonly property bool gameDriven:
        Settings.perfAutoGame && gameCount > 0 && !gameSuppressed
    readonly property bool active: manual || gameDriven

    // Why it is on, for the bar indicator's tooltip: "manual" (by hand,
    // even if a game is also running), "game" (only because GameMode
    // reports one) or "" (off).
    readonly property string reason: manual ? "manual" : gameDriven ? "game" : ""

    // Called from shell.qml's startup chain, if it chooses to: singletons
    // are lazy. SysMon also touches `active`, which brings this to life
    // wherever the system monitor is alive.
    function init() {
        applyTimer.restart();
    }

    function set(on: bool): void {
        if (on === active)
            return;
        if (on) {
            manual = true;
        } else {
            manual = false;
            if (gameDriven)
                gameSuppressed = true;
        }
    }

    function toggle(): void { set(!active); }

    // ── Compositor ────────────────────────────────────────────────────
    readonly property string trigger:
        Settings.windowAnimations + "|" + (active ? "1" : "0")
    onTriggerChanged: { applyTimer.interval = 250; applyTimer.restart(); }

    // The user's transparency and blur values (Settings -> Transparency &
    // blur), handed to picom-effects, which writes them into the generated
    // config and restarts picom only if they differ from what it is running.
    // Each apply restarts picom (a flicker), so a slider being dragged must
    // not apply per tick: wait until it has been still for a moment.
    readonly property var fxArgs: [
        "blur=" + (Settings.blurEnabled ? "1" : "0"),
        "blur-strength=" + Settings.blurStrength,
        "inactive-opacity=" + Settings.inactiveOpacity,
        "popup-opacity=" + Settings.popupOpacity
    ]
    onFxArgsChanged: { applyTimer.interval = 400; applyTimer.restart(); }

    // Coalesce changes (and the several that arrive at startup) into one
    // picom restart.
    Timer {
        id: applyTimer
        interval: 250
        onTriggered: {
            Quickshell.execDetached(["sh", "-c",
                "p=$(command -v picom-effects || echo \"$HOME/.local/bin/picom-effects\"); " +
                "exec \"$p\" apply \"$@\"",
                "picom-effects", Settings.windowAnimations, root.active ? "1" : "0"]
                .concat(root.fxArgs));
        }
    }

    // ── On-screen message ─────────────────────────────────────────────
    onActiveChanged: {
        Quickshell.execDetached(["qs", "ipc", "call", "osd", "text",
            active ? "Performance mode on" : "Performance mode off"]);
    }
    IpcHandler {
        target: "perf"

        function toggle(): void { root.toggle(); }
        function on(): void { root.set(true); }
        function off(): void { root.set(false); }
        function status(): string { return root.active ? "on" : "off"; }
    }

    // ── GameMode ──────────────────────────────────────────────────────
    function refreshCount() {
        countProc.running = false;
        countProc.running = true;
    }

    // Reads ClientCount, but only if GameMode is already on the bus:
    // asking it directly would start gamemoded just to be told 0.
    Process {
        id: countProc
        command: ["sh", "-c",
            "dest=com.feralinteractive.GameMode; " +
            "dbus-send --session --print-reply --dest=org.freedesktop.DBus " +
            "  /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner string:$dest " +
            "  2>/dev/null | grep -q 'boolean true' || { echo 0; exit 0; }; " +
            "dbus-send --session --print-reply --dest=$dest /com/feralinteractive/GameMode " +
            "  org.freedesktop.DBus.Properties.Get string:$dest string:ClientCount " +
            "  2>/dev/null | awk '/int32/ { print $NF; found = 1 } END { if (!found) print 0 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim());
                root.gameCount = isNaN(n) ? 0 : n;
                if (root.gameCount === 0)
                    root.gameSuppressed = false;
            }
        }
    }

    Timer {
        id: recount
        interval: 150
        onTriggered: root.refreshCount()
    }

    Process {
        id: monitor
        running: true
        command: ["dbus-monitor", "--session",
            "type='signal',interface='com.feralinteractive.GameMode'",
            "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'," +
            "arg0='com.feralinteractive.GameMode'"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("member=GameRegistered") >= 0
                        || line.indexOf("member=GameUnregistered") >= 0
                        || line.indexOf("member=NameOwnerChanged") >= 0)
                    recount.restart();
            }
        }
        // The bus going away, or dbus-monitor missing: try again later.
        onExited: retry.restart()
    }

    Timer {
        id: retry
        interval: 30000
        onTriggered: monitor.running = true
    }

    Component.onCompleted: {
        refreshCount();
    }
}
