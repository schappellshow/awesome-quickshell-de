pragma Singleton
import QtQuick
import Quickshell

// Pushes the shell's dark/light mode out to every system theming channel
// (GSettings/portal for Electron apps, kdeglobals for Qt, xsettingsd + gtk
// inis for GTK) via the system-theme-apply script in this repo's `bin`
// package, and does the same for the icon and cursor themes.
// apply() runs at shell startup, so dark is enforced every login.
// Absolute path because the SDDM/awesome session PATH may lack ~/.local/bin.
Singleton {
    id: root

    function apply() {
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.local/bin/system-theme-apply",
            Settings.darkMode ? "dark" : "light"
        ]);
        applyIcon();
        applyCursor();
    }

    function applyIcon() {
        if (Settings.iconTheme !== "")
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.local/bin/icon-theme-apply",
                Settings.iconTheme
            ]);
    }

    // Runs even when the theme is empty, unlike applyIcon: an empty name is
    // the script's "revert to the distribution default" case, which has to
    // reach it to undo a previous choice.
    function applyCursor() {
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.local/bin/cursor-theme-apply",
            Settings.cursorTheme,
            String(Settings.cursorSize)
        ]);
    }

    Connections {
        target: Settings
        function onDarkModeChanged() { root.apply(); }
        function onIconThemeChanged() { root.applyIcon(); }
        function onCursorThemeChanged() { root.applyCursor(); }
        function onCursorSizeChanged() { root.applyCursor(); }
    }
}
