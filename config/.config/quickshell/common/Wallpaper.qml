pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper via feh, driven by Settings.wallpaperPath (set from the
// Settings app's Wallpaper page).
//
// On a fresh install that setting is empty, so rather than leaving a blank
// desktop we adopt a distro-shipped wallpaper: nearly every distribution
// ships images in /usr/share/wallpapers (KDE-family) or
// /usr/share/backgrounds (GNOME/Debian-family), often with a default.* as
// the vendor's pick. The discovered path is written back to Settings so the
// Wallpaper page shows it selected, and the user can change it from there.
Singleton {
    id: root

    // Called from shell.qml's startup chain (singletons are lazy)
    function init() {
        if (Settings.wallpaperPath === "")
            discoverProc.running = true;
    }

    // Prefer an explicit vendor default, else the first image found.
    Process {
        id: discoverProc
        command: ["sh", "-c", `
for d in /usr/share/wallpapers /usr/share/backgrounds; do
    [ -d "$d" ] || continue
    for n in default.jpg default.png default.jpeg; do
        [ -f "$d/$n" ] && { echo "$d/$n"; exit 0; }
    done
done
for d in /usr/share/wallpapers /usr/share/backgrounds; do
    [ -d "$d" ] || continue
    find -L "$d" -maxdepth 3 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' \\
         -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort | head -1
done | head -1
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                // Writing the setting triggers apply() via the binding below
                if (p !== "" && Settings.wallpaperPath === "")
                    Settings.wallpaperPath = p;
            }
        }
    }

    function expand(p) {
        return p.startsWith("~/") ? Quickshell.env("HOME") + p.slice(1) : p;
    }

    function apply() {
        if (Settings.wallpaperPath === "")
            return;
        const p = expand(Settings.wallpaperPath);
        // feh assigns one image per monitor, so a single path stretches
        // across the whole X screen on a multi-head setup. Repeat it once
        // per screen to fill each monitor individually (a 1-screen laptop
        // is unaffected — it just gets the single argument as before).
        const args = ["feh", "--bg-fill"];
        for (let i = 0; i < Math.max(1, Quickshell.screens.length); i++)
            args.push(p);
        Quickshell.execDetached(args);
        // Rebuild the lock screen's blurred/dimmed cache to match
        // (betterlockscreen lives in ~/.local/bin; skip silently if absent)
        Quickshell.execDetached(["sh", "-c",
            "command -v betterlockscreen >/dev/null && " +
            "betterlockscreen -u '" + p + "' >/dev/null 2>&1 || true"]);
    }

    Connections {
        target: Settings
        function onWallpaperPathChanged() { root.apply(); }
    }

    // Re-apply whenever the screen layout changes.
    //
    // feh paints for the geometry that exists at the moment it runs, and it
    // is fire-and-forget — nothing corrects it afterwards. At login the
    // startup chain calls this before DisplayConfig's xrandr has landed, so
    // the wallpaper was drawn for the pre-layout geometry: monitors ended up
    // showing a doubled or smeared image until feh was re-run by hand. The
    // same applies on hotplug, where the screen set changes mid-session.
    //
    // This MUST be a declarative binding, not a function called from
    // Quickshell.onScreensChanged. ShellScreen's x/y/width/height are
    // notified by that screen's own `geometryChanged`; screensChanged fires
    // only when outputs are added or removed. Rotating an output — exactly
    // what the saved layout does to the portrait monitor — keeps the same
    // three ShellScreens, so the old screensChanged handler never ran and
    // the login-time wallpaper was left painted for the pre-rotation
    // geometry (a 5760x1080 root pixmap under a 4920x1920 X screen: every
    // monitor offset, and the portrait one stretched past its bottom edge).
    //
    // Reading s.x/s.y/s.width/s.height inside the binding subscribes to each
    // screen's geometryChanged; reading Quickshell.screens subscribes to
    // screensChanged. So one property now covers both rotate/resize and
    // plug/unplug.
    readonly property string geometryKey: Quickshell.screens
        .map(s => s.name + ":" + s.x + "," + s.y + ":" + s.width + "x" + s.height)
        .sort()
        .join("|")

    onGeometryKeyChanged: settle.restart()

    // Debounce: a layout change emits several events, and xrandr may still
    // be mid-flight on the first one
    Timer {
        id: settle
        interval: 1500
        onTriggered: root.apply()
    }

    Component.onCompleted: apply()
}
