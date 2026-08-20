pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bridge to AwesomeWM. Awesome (modules/quickshell.lua) writes tag/layout
// state as JSON to $XDG_RUNTIME_DIR/awesomewm-state.json whenever it changes;
// we watch that file. Commands flow the other way via `awesome-client`.
Singleton {
    id: root

    // Array of { index, outputs: [names], layout,
    //            tags:   [{ index, name, selected, occupied, urgent, minimized }],
    //            hidden: [{ id, class, name }] }
    // `minimized` counts hidden clients on that tag; `hidden` lists the ones
    // on the tag(s) the screen is currently viewing, keyed by X window id.
    property var screens: []

    // Every client currently ON SCREEN across all monitors, already ordered
    // left to right by the bridge (it sorts on absolute geometry, which
    // orders across monitors and within a tiled screen in one pass — see
    // modules/quickshell.lua clients_json).
    //
    // Flat, not per-screen: the window list describes the whole desktop and
    // the bar lives on one monitor. Two windows of the same app on two
    // monitors are two entries, in their two places.
    // [{ id, class, instance, name, focused }]
    property var clients: []

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

    // Unminimize a specific client and focus it. Matched on X window id, so
    // it stays correct as the hidden list shifts underneath; awesome's own
    // awful.client.restore() can only pop the last-minimized one.
    function restoreClient(windowId) {
        exec(`for _, c in ipairs(client.get()) do `
            + `if c.window == ${windowId} then `
            + `c.minimized = false; `
            + `c:emit_signal("request::activate", "quickshell.restore", { raise = true }) `
            + `end end`);
    }

    // Focus a specific window, following it to whichever screen and tag it
    // is on. Matched on X window id like restoreClient, so it stays correct
    // as the list reorders underneath.
    function focusClient(windowId) {
        exec(`for _, c in ipairs(client.get()) do `
            + `if c.window == ${windowId} then `
            + `local t = c.first_tag; `
            + `if t then t:view_only() end; `
            + `require("awful").screen.focus(c.screen); `
            + `c:emit_signal("request::activate", "quickshell.focus", { raise = true }) `
            + `end end`);
    }

    // Focus one of our own dock surfaces (the launcher).
    //
    // A PanelWindow is a dock client, and awesome does not focus those on its
    // own — quickshell's `focusable: true` sets the input hint but nothing
    // acts on it, so the surface maps with the keyboard still pointed at
    // whatever you were using. Asking awesome directly does work.
    //
    // Matched on exact geometry: PanelWindow exposes no title or id (only
    // anchors, margins, exclusion, focusable and aboveWindows), so there is
    // nothing else to match on. The bar is a different shape, and the power
    // menu's backdrops — the only other full-screen dock surfaces — are
    // `visible: false` when closed and so are not clients at all. The two
    // menus are never open together.
    function focusOwnDock(x, y, w, h) {
        exec(`for _, c in ipairs(client.get()) do `
            + `local g = c:geometry(); `
            + `if c.type == "dock" and g.x == ${x} and g.y == ${y} `
            + `and g.width == ${w} and g.height == ${h} then `
            + `client.focus = c; `
            + `c:emit_signal("request::activate", "quickshell.launcher", { raise = true }) `
            + `end end`);
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
            root.clients = st.clients || [];
        } catch (e) {
            console.log("AwesomeState: failed to parse state file:", e);
        }
    }
}
