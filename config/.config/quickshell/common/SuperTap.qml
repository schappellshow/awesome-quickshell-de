pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Super tapped on its own opens the start menu.
//
// The detection lives in bin/.local/bin/super-tap, which reads the X RECORD
// stream because awesome cannot see the keys it has not grabbed (the script's
// header explains why that matters). All this does is decide whether that
// watcher should be running.
//
// Which makes the setting genuinely conditional: off means no process, no
// grab, and Super is an ordinary modifier again — not a binding that exists
// and declines to act.
Singleton {
    id: root

    readonly property string helper:
        Quickshell.env("HOME") + "/.local/bin/super-tap"

    // Tied to the start button: the tap opens that button's menu, so leaving
    // it live while the button is hidden would be a shortcut to something the
    // user has put away. AppsPage says so where the switch is.
    readonly property bool enabled: Settings.startSuperKey && Settings.showStart

    // Called from shell.qml's startup chain: singletons are lazy, and one
    // that only ever reacts to changes would never come to life at all.
    function init() {
        root.sync();
    }

    // Assigned, never bound. A declarative `running: root.enabled` looks
    // right until the watcher exits on its own — quickshell writes false back
    // into the property, which destroys the binding, and the switch then does
    // nothing for the rest of the session.
    function sync() {
        watcher.running = root.enabled;
    }

    onEnabledChanged: root.sync()

    Process {
        id: watcher
        // Through the shell rather than straight to awesome-client (which is
        // what the watcher does on its own): only the shell knows where the
        // bar drew the start button, and so which coordinates to send.
        command: [root.helper, "--", "qs", "ipc", "call", "startmenu", "toggle"]
    }
}
