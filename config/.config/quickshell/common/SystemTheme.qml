pragma Singleton
import QtQuick
import Quickshell

// Pushes the shell's dark/light mode out to every system theming channel
// (GSettings/portal for Electron apps, kdeglobals for Qt, xsettingsd + gtk
// inis for GTK) via the system-theme-apply script in the `local` stow
// package. apply() runs at shell startup, so dark is enforced every login.
// Absolute path because the SDDM/awesome session PATH may lack ~/.local/bin.
Singleton {
    id: root

    function apply() {
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.local/bin/system-theme-apply",
            Settings.darkMode ? "dark" : "light"
        ]);
        applyIcon();
    }

    function applyIcon() {
        if (Settings.iconTheme !== "")
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.local/bin/icon-theme-apply",
                Settings.iconTheme
            ]);
    }

    Connections {
        target: Settings
        function onDarkModeChanged() { root.apply(); }
        function onIconThemeChanged() { root.applyIcon(); }
    }
}
