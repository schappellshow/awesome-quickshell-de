//@ pragma UseQApplication
// (required for QsMenuAnchor — tray right-click menus are silent no-ops
// without it)

import QtQuick
import Quickshell
import Quickshell.Io
import "./common"
import "./bar"
import "./notifications"
import "./settings"
import "./power"
import "./launcher"
import "./clipboard"
import "./osd"

ShellRoot {
    // Startup apply chain: settings.json is the source of truth, but X11
    // state (theme channels, wallpaper, xrandr, setxkbmap, xset, xinput)
    // doesn't persist across logins — re-apply everything, idempotently.
    // init() also forces the lazy singletons to life.
    Component.onCompleted: {
        updateBarScreens();
        SystemTheme.apply();
        Wallpaper.init();
        DisplayConfig.init();
        AudioDevices.init();
        BluetoothPower.init();
        Keyboard.init();
        InputDevices.init();
        PowerConfig.init();
        PowerEvents.init();
        EventSounds.init();
        Autostart.init();
        BarSpace.init();
        WindowMode.init();
        WindowBorders.init();
        SuperTap.init();
        Shortcuts.init();
    }

    // One bar on Settings.barScreen; if it's unset or that output isn't
    // connected (laptop away from the dock), bars on every screen.
    //
    // Held in a property rather than bound live: a
    // `Quickshell.screens.filter(...)` expression hands Variants a brand
    // new array every time it re-evaluates (which an awesome restart
    // triggers), and Variants then re-points the existing window at a
    // different screen — the bar jumped from DP2 to DP1 on Super+Ctrl+R,
    // same window id, and the notification surfaces had the same bug.
    property var barScreens: []

    function updateBarScreens() {
        const match = Quickshell.screens.filter(
            s => s.name === Settings.barScreen);
        barScreens = match.length > 0 ? match : Quickshell.screens;
    }

    Connections {
        target: Settings
        function onBarScreenChanged() { updateBarScreens(); }
    }

    Variants {
        model: barScreens
        Bar {}
    }

    // `qs ipc call bar recreate` — Super+b.
    //
    // A bar section can end up laying out correctly while painting nothing:
    // the pill is sized for it, toggling its show* setting resizes the pill
    // by exactly the right number of pixels, and no QML error appears. A
    // config reload, a full qs restart and even a reboot all fail to clear
    // it. The one thing that does is destroying and recreating the
    // PanelWindows, which is what cycling Settings -> Bar -> Bar screen was
    // really doing — handing Variants a different screen list.
    //
    // This does that directly: empty the model, then rebuild it a frame
    // later. Same recreate, without walking the bar to another monitor and
    // back, so it cannot be left on the wrong screen if interrupted.
    //
    // It also recovers the other failure this file already describes: an
    // awesome restart sometimes still leaves the bar on the wrong screen,
    // showing DP1 while Settings says DP2. Rebuilding re-derives the screen
    // from Settings.barScreen, so the bar returns to where the setting says
    // it should be — holding barScreens as a stable property reduced that
    // drift but evidently did not end it.
    //
    // Deliberately manual. Doing this automatically at startup would fight
    // the reason barScreens is a stable property (see above) and cost a
    // flicker every login, to work around a bug whose cause is still not
    // established.
    IpcHandler {
        target: "bar"

        function recreate(): void {
            barScreens = [];
            barRecreate.restart();
        }
    }

    Timer {
        id: barRecreate
        interval: 50
        onTriggered: updateBarScreens()
    }

    NotificationPopups {}

    NotificationCenter {}

    SettingsWindow {}

    AppLauncher {}

    // Clipboard history — `qs ipc call clipboard toggle`, bound to Super+/
    ClipboardPanel {}

    // Session menu — `qs ipc call power toggle`, bound to Super+BackSpace
    PowerMenu {}

    // Volume/brightness pill, driven by the audio/brightness handlers below
    Osd { id: osd }

    // `qs ipc call audio raise|lower|muteToggle` — volume keys in awesome
    IpcHandler {
        target: "audio"

        function raise(): void {
            Audio.raise();
            osd.showVolume();
        }

        function lower(): void {
            Audio.lower();
            osd.showVolume();
        }

        function muteToggle(): void {
            Audio.toggleMute();
            osd.showVolume();
        }
    }

    // `qs ipc call shortcuts captured <id> <chord>` — awesome grabs the
    // keyboard to record a chord (Settings -> Keyboard) and hands the
    // result back here. See modules/keys.lua's capture block for why the
    // recording cannot happen in the settings window itself.
    IpcHandler {
        target: "shortcuts"

        function captured(id: string, chord: string): void {
            Shortcuts.captured(id, chord);
        }

        function cancel(): void {
            Shortcuts.stopCapture();
        }
    }

    // `qs ipc call startmenu toggle` — the Super tap (bin/super-tap) comes
    // through here rather than calling awesome directly, because the menu's
    // placement setting needs the bar's view of where the button is.
    IpcHandler {
        target: "startmenu"

        function toggle(): void {
            StartMenu.toggle();
        }
    }

    // `qs ipc call inhibit set|clear` — called by the screensaver-inhibitor
    // daemon when an app (browser playing video, mpv, ...) asks the session
    // to stay awake via org.freedesktop.ScreenSaver
    IpcHandler {
        target: "inhibit"

        function set(): void {
            PowerConfig.appInhibited = true;
        }

        function clear(): void {
            PowerConfig.appInhibited = false;
        }

        function status(): string {
            return PowerConfig.appInhibited ? "inhibited" : "idle";
        }
    }

    // `qs ipc call sysmon toggle` — Super+Shift+m in awesome (conky popout)
    IpcHandler {
        target: "sysmon"

        function toggle(): void {
            SysMon.toggleConky();
        }
    }

    // `qs ipc call calendar toggle` — Super+v in awesome
    IpcHandler {
        target: "calendar"

        function toggle(): void {
            BarState.toggleCalendar();
        }
    }

    // `qs ipc call keepawake toggle` — Super+z in awesome. Suspends the
    // xset blank/DPMS timers (and with them the idle lock) until toggled
    // off; notifies through our own daemon for KDE-style feedback.
    IpcHandler {
        target: "keepawake"

        function toggle(): void {
            PowerConfig.toggleAwake();
            const on = PowerConfig.keepAwake;
            Quickshell.execDetached(["notify-send",
                on ? "Keep awake: ON" : "Keep awake: off",
                on ? "Screen blanking, locking and display-off disabled"
                   : "Normal idle timeouts restored"]);
        }
    }

    // `qs ipc call notifs toggle` — Super+Shift+b in awesome
    IpcHandler {
        target: "notifs"

        function toggle(): void {
            NotifHistory.toggleCenter();
        }

        function close(): void {
            NotifHistory.centerOpen = false;
        }

        function clearAll(): void {
            NotifHistory.clear();
        }

        function dnd(): void {
            Settings.doNotDisturb = !Settings.doNotDisturb;
        }
    }

    // `qs ipc call brightness up|down` — XF86MonBrightness keys in awesome
    IpcHandler {
        target: "brightness"

        function up(): void {
            Brightness.up();
            osd.showBrightness();
        }

        function down(): void {
            Brightness.down();
            osd.showBrightness();
        }
    }

    // `qs ipc call nightlight toggle` — bound to Super+Shift+n in awesome
    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            NightLight.toggle();
        }

        function temp(kelvin: int): void {
            Settings.nightLightTemp = kelvin;
        }
    }

    // `qs ipc call media toggle` — bound to Super+a in awesome
    IpcHandler {
        target: "media"

        function toggle(): void {
            Media.toggleFocused();
        }

        function playPause(): void {
            if (Media.active)
                Media.active.togglePlaying();
        }
    }

    // `qs ipc call theme toggle` — bound to Super+Shift+t in awesome
    IpcHandler {
        target: "theme"

        function toggle(): void {
            Settings.darkMode = !Settings.darkMode;
        }

        function dark(): void {
            Settings.darkMode = true;
        }

        function light(): void {
            Settings.darkMode = false;
        }
    }
}
