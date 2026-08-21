pragma Singleton
import QtQuick
import Quickshell

// Global window mode, imposed on awesome.
//
// awesome has no concept of a global layout: layout is a per-tag property and
// each screen has its own tags, so three different layouts can be live at
// once. A "mode" is therefore not something awesome can hold — it is
// something we apply, and re-apply whenever awesome forgets.
//
// Resolution, most specific first:
//   monitorLayouts[output]  ->  defaultLayout  ->  rc.lua's own choice
//
// The last tier matters: leaving defaultLayout empty means we send nothing at
// all, which preserves rc.lua's orientation heuristic (portrait monitors get
// tile.bottom). A global default would otherwise flatten that.
//
// This applies the settings; it does NOT police them. Cycling a layout by
// hand — the bar's layout indicator, Super+Space — sticks until the next
// restart or hotplug. The setting is a default, not a cage.
Singleton {
    id: root

    readonly property var layouts: [
        "dwindle", "tile", "tileleft", "tilebottom", "fairv", "max", "floating"
    ]

    readonly property bool floating: Settings.windowMode === "floating"

    // rc.lua's orientation heuristic, reproduced here.
    //
    // It has to live in BOTH places. rc.lua applies it when a screen is first
    // set up, which is right for a fresh session. But once Floating mode has
    // overwritten every tag, "Automatic" needs something to RESTORE, and
    // sending nothing just leaves the tags floating — which is exactly what
    // happened the first time this shipped. So Automatic is a real choice
    // that gets applied, not an absence of one.
    function automaticFor(screen) {
        return screen.height > screen.width ? "tilebottom" : "dwindle";
    }

    // The layout that should apply to one output. Never "" in tiling mode:
    // see automaticFor above.
    function layoutFor(screen) {
        if (root.floating)
            return "floating";
        const overrides = Settings.monitorLayouts || ({});
        if (overrides[screen.name])
            return overrides[screen.name];
        if (Settings.defaultLayout !== "")
            return Settings.defaultLayout;
        return root.automaticFor(screen);
    }

    // Called from shell.qml's startup chain: singletons are lazy, and one
    // that only ever reacts to changes would never come to life at all.
    function init() {
        settle.restart();
    }

    function apply() {
        for (const s of Quickshell.screens) {
            const l = root.layoutFor(s);
            if (l !== "")
                AwesomeState.setScreenLayout(s.name, l);
        }
    }

    function setMonitorLayout(outputName, layoutName) {
        const next = Object.assign({}, Settings.monitorLayouts || ({}));
        if (layoutName === "")
            delete next[outputName];
        else
            next[outputName] = layoutName;
        // Reassign rather than mutate: a JsonAdapter property only persists
        // when the property itself changes.
        Settings.monitorLayouts = next;
    }

    function clearOverrides() {
        Settings.monitorLayouts = ({});
    }

    // Re-apply when the settings change, when monitors come and go, and when
    // awesome restarts (which resets every tag to rc.lua's defaults). The
    // epoch is constant for the life of an awesome process, so a change to it
    // is a restart and nothing else.
    readonly property string trigger: [
        Settings.windowMode,
        Settings.defaultLayout,
        JSON.stringify(Settings.monitorLayouts || ({})),
        AwesomeState.epoch,
        Quickshell.screens.map(s => s.name).join(",")
    ].join("|")

    onTriggerChanged: settle.restart()

    // awesome rewrites its state in bursts on restart, and the screen list
    // can change several times during a hotplug. One apply once it settles.
    Timer {
        id: settle
        interval: 400
        onTriggered: root.apply()
    }
}
