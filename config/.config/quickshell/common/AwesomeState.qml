pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bridge to AwesomeWM. Awesome (modules/quickshell.lua) writes tag/layout
// state as JSON to $XDG_RUNTIME_DIR/awesomewm-state.json whenever it changes;
// we watch that file. Commands flow the other way via `awesome-client`.
Singleton {
    id: root

    // Array of { index, outputs: [names], layout, tags: [{index, name, selected, occupied, urgent}] }
    property var screens: []

    readonly property string statePath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/awesomewm-state.json"

    // Match a quickshell screen (by connector name, e.g. "eDP-1") to the
    // awesome screen that owns that output.
    function forOutput(name) {
        return root.screens.find(s => (s.outputs || []).includes(name)) ?? null;
    }

    function exec(lua) {
        Quickshell.execDetached(["awesome-client", lua]);
    }

    function viewTag(screenIndex, tagIndex) {
        exec(`local t = screen[${screenIndex}].tags[${tagIndex}]; if t then t:view_only() end`);
    }

    function toggleTag(screenIndex, tagIndex) {
        exec(`local t = screen[${screenIndex}].tags[${tagIndex}]; if t then require("awful").tag.viewtoggle(t) end`);
    }

    function viewNext(screenIndex) {
        exec(`require("awful").tag.viewnext(screen[${screenIndex}])`);
    }

    function viewPrev(screenIndex) {
        exec(`require("awful").tag.viewprev(screen[${screenIndex}])`);
    }

    function cycleLayout(screenIndex, dir) {
        exec(`require("awful").layout.inc(${dir}, screen[${screenIndex}])`);
    }

    FileView {
        id: file
        path: root.statePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse()
        onLoadFailed: root.screens = []
    }

    function parse() {
        try {
            const st = JSON.parse(file.text());
            root.screens = st.screens || [];
        } catch (e) {
            console.log("AwesomeState: failed to parse state file:", e);
        }
    }
}
