pragma Singleton
import QtQuick
import Quickshell

// The window outline awesome draws, kept in step with the shell's palette.
//
// The colours are deliberately NOT separate settings. theme.lua's
// border_normal/border_focus were already Theme.surface and
// Theme.accentBright, so pushing those two means every colour scheme themes
// the window borders too, and a scheme file needs no extra keys to do it.
// Width and corner radius are taste rather than palette, so those are
// settings, on the Windows page.
Singleton {
    id: root

    // Called from shell.qml's startup chain (singletons are lazy)
    function init() {
        apply();
    }

    function apply() {
        // Guarded: set_border arrives with modules/quickshell.lua, so a
        // shell that reloaded before awesome did would otherwise raise a
        // Lua error on every colour change until the next awesome reload.
        AwesomeState.exec(
            `local ok, qs = pcall(require, "modules.quickshell"); `
            + `if ok and qs.set_border then qs.set_border(`
            + `"${Theme.surface}", "${Theme.accentBright}", `
            + `${Settings.borderWidth}, ${Settings.borderRadius}) end`);
    }

    // awesome restarting resets beautiful to theme.lua's values, so the
    // epoch has to be a trigger here for the same reason it is in
    // WindowMode: it changes once per awesome process and nothing else.
    readonly property string trigger: [
        String(Theme.surface),
        String(Theme.accentBright),
        Settings.borderWidth,
        Settings.borderRadius,
        AwesomeState.epoch
    ].join("|")

    onTriggerChanged: settle.restart()

    // Dragging a width slider emits a value per pixel, and awesome restyles
    // every client on each call — coalesce into one apply.
    Timer {
        id: settle
        interval: 250
        onTriggered: root.apply()
    }
}
