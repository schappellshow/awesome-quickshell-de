pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent shell settings. Stored outside this repo in quickshell's
// per-shell state dir (~/.local/state/quickshell/by-shell/...) so runtime
// changes never dirty the config repo.
//
// This file is the source of truth for everything the Settings app manages;
// effects are applied by singletons watching these properties (SystemTheme,
// NightLight, Wallpaper, Keyboard, PowerConfig, ...).
Singleton {
    id: root

    // Appearance
    property alias darkMode: adapter.darkMode
    property alias accentColor: adapter.accentColor
    property alias iconTheme: adapter.iconTheme

    // Wallpaper
    property alias wallpaperPath: adapter.wallpaperPath

    // Night light
    property alias nightLightEnabled: adapter.nightLightEnabled
    property alias nightLightTemp: adapter.nightLightTemp
    property alias nightLightSchedule: adapter.nightLightSchedule
    property alias nightLightStart: adapter.nightLightStart
    property alias nightLightStop: adapter.nightLightStop

    // Bar
    property alias barPosition: adapter.barPosition
    property alias barWidth: adapter.barWidth
    property alias barScreen: adapter.barScreen
    property alias barOpacity: adapter.barOpacity
    property alias barBlur: adapter.barBlur
    // "" = follow Theme.fontFamily
    property alias fontLabels: adapter.fontLabels
    property alias fontClock: adapter.fontClock
    property alias fontApps: adapter.fontApps
    // Section arrangement: [{ id, slot }] — see common/BarSections.qml
    property alias barSections: adapter.barSections
    property alias showTags: adapter.showTags
    property alias showClock: adapter.showClock
    property alias showMediaPill: adapter.showMediaPill
    property alias showTray: adapter.showTray
    // Tray icons hidden by hand: [{ key, name }] — see common/TrayItems.qml
    property alias trayHidden: adapter.trayHidden
    property alias showBattery: adapter.showBattery
    property alias showLayoutBox: adapter.showLayoutBox
    property alias showNetwork: adapter.showNetwork
    property alias showBluetooth: adapter.showBluetooth
    property alias showVolume: adapter.showVolume
    property alias showNotifBell: adapter.showNotifBell
    property alias showSysMon: adapter.showSysMon
    property alias showScreenLock: adapter.showScreenLock
    property alias showNightLight: adapter.showNightLight

    // System monitor popout (conky)
    property alias conkyConfig: adapter.conkyConfig

    // Notifications
    property alias notifTimeoutMs: adapter.notifTimeoutMs
    property alias doNotDisturb: adapter.doNotDisturb
    // "top-right" | "top-left" | "bottom-right" | "bottom-left"
    property alias notifPosition: adapter.notifPosition

    // Displays (xrandr args, replayed at login)
    property alias displayCmd: adapter.displayCmd

    // Keyboard ("" = leave system layout alone; "us" or "us:intl")
    property alias kbLayout: adapter.kbLayout
    property alias kbRepeatDelay: adapter.kbRepeatDelay
    property alias kbRepeatRate: adapter.kbRepeatRate

    // Mouse / touchpad (libinput via xinput)
    property alias mouseAccel: adapter.mouseAccel
    property alias naturalScroll: adapter.naturalScroll
    property alias tapToClick: adapter.tapToClick

    // Power (0 = never)
    property alias keepAwake: adapter.keepAwake
    property alias blankMinutes: adapter.blankMinutes
    property alias dpmsMinutes: adapter.dpmsMinutes
    property alias batteryWarnPct: adapter.batteryWarnPct
    property alias batteryCriticalPct: adapter.batteryCriticalPct

    // Apps: start button, pinned launchers, open-window list. Three
    // independent sections rather than one "app mode", so they place and
    // order like every other section (see BarSections.qml).
    property alias showStart: adapter.showStart
    property alias showPinned: adapter.showPinned
    property alias showWindowList: adapter.showWindowList
    // Desktop entry ids, in strip order
    property alias pinnedApps: adapter.pinnedApps
    // Path or theme icon name; "" falls back to start-here, then a glyph
    property alias startIcon: adapter.startIcon

    // Lock screen. Read by bin/.local/bin/lock-screen (text, fonts, ring)
    // and bin/.local/bin/lock-image (panel, background) rather than by any
    // QML — the lock screen is i3lock-color, not a quickshell surface. The
    // scripts fall back to these same defaults when a key is absent, so an
    // unset value and the default below are the same thing.
    property alias lockText: adapter.lockText
    property alias lockFont: adapter.lockFont
    property alias lockTimeFormat: adapter.lockTimeFormat
    property alias lockClockSize: adapter.lockClockSize
    property alias lockTextSize: adapter.lockTextSize
    property alias lockSmallSize: adapter.lockSmallSize
    property alias lockRingRadius: adapter.lockRingRadius
    property alias lockRingWidth: adapter.lockRingWidth
    // These change the cached image, so they need lock-image to re-run
    property alias lockDim: adapter.lockDim
    property alias lockBlur: adapter.lockBlur
    property alias lockPanelWidth: adapter.lockPanelWidth
    property alias lockPanelHeight: adapter.lockPanelHeight
    property alias lockPanelColor: adapter.lockPanelColor
    property alias lockPanelX: adapter.lockPanelX
    property alias lockPanelY: adapter.lockPanelY

    // Autostart: [{ command: string, enabled: bool }]
    property alias autostartExtra: adapter.autostartExtra

    readonly property string path: Quickshell.statePath("settings.json")

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool darkMode: true
            property string accentColor: "#2080bb"
            property string iconTheme: ""

            // Empty on a fresh install: Wallpaper.qml then adopts a
            // distro-shipped wallpaper and writes the path back here.
            // "~" in a user-set path expands against $HOME at apply time.
            property string wallpaperPath: ""

            property bool nightLightEnabled: false
            property int nightLightTemp: 3000
            // Schedule is opt-in: off = night light is purely manual
            // (Super+Shift+N / settings toggle)
            property bool nightLightSchedule: false
            property string nightLightStart: "21:00"
            property string nightLightStop: "07:00"

            // Which edge the bar lives on: "left" | "right" | "top" |
            // "bottom". barWidth is its thickness on that edge, so a
            // horizontal bar is 36px tall rather than 36px wide.
            property string barPosition: "left"
            property int barWidth: 36
            // Output name (e.g. "DisplayPort-2") for a single bar;
            // "" or an unplugged output falls back to bars on every screen
            property string barScreen: ""
            // Bar background opacity, 0-100. 0 = the stock look: an
            // invisible bar with opaque pills floating on the desktop.
            // 100 = a solid bar, where the pills share its colour and read
            // as one surface. Anything between is a tinted glass bar.
            // Needs a compositor (picom) for anything but 100.
            property int barOpacity: 0
            // Blur strength, 0-100, applied to the wallpaper behind the bar.
            // Pairs with barOpacity: blur alone is frosted glass, blur plus
            // some opacity is tinted frosted glass.
            property int barBlur: 0

            // Bar fonts. Empty means "whatever Theme.fontFamily is", so a
            // fresh install follows the theme and an uninstalled font
            // degrades to the theme default rather than to Qt's fallback.
            property string fontLabels: ""
            property string fontClock: ""
            property string fontApps: ""

            // Which slot each bar section sits in and the order within it,
            // as [{ id, slot }]. Empty means the shipped arrangement; a
            // section missing from a saved list is restored to its default
            // position rather than dropped (common/BarSections.qml).
            property var barSections: []
            property bool showTags: true
            property bool showClock: true
            property bool showMediaPill: true
            property bool showTray: true

            // Tray icons hidden by hand, as [{ key, name }]. The name is
            // stored alongside the key so a hidden app can still be listed
            // (and un-hidden) while it isn't running — see
            // common/TrayItems.qml.
            property var trayHidden: []

            property bool showBattery: true
            property bool showLayoutBox: true
            property bool showNetwork: true
            property bool showBluetooth: true
            property bool showVolume: true
            property bool showNotifBell: true
            property bool showSysMon: true
            property bool showScreenLock: true
            property bool showNightLight: true
            property string conkyConfig: ""

            property int notifTimeoutMs: 6000
            property bool doNotDisturb: false
            property string notifPosition: "top-right"

            property string displayCmd: ""

            property string kbLayout: ""
            property int kbRepeatDelay: 400
            property int kbRepeatRate: 40

            property real mouseAccel: 0
            property bool naturalScroll: false
            property bool tapToClick: true

            // Manual keep-awake hold (Super+Z / the SCN pill). Persisted so
            // it survives a shell reload the same way night light does: a
            // hold you set by hand is a decision, not session state, and
            // having it silently lapse means re-setting it without noticing
            // it had gone.
            property bool keepAwake: false
            property int blankMinutes: 10
            property int dpmsMinutes: 15
            property int batteryWarnPct: 15
            property int batteryCriticalPct: 5

            // Apps sections. Off by default: a tiling setup does not need
            // a launcher strip, and an empty section that takes no space is
            // still one more thing in the arrangement list.
            property bool showStart: false
            property bool showPinned: false
            property bool showWindowList: false
            property var pinnedApps: []
            property string startIcon: ""

            // Lock screen — see the aliases above for who reads these.
            property string lockText: "Enter Password"
            property string lockFont: "Hack"
            property string lockTimeFormat: "%I:%M %p"
            property int lockClockSize: 32
            property int lockTextSize: 16
            property int lockSmallSize: 12
            property int lockRingRadius: 25
            property int lockRingWidth: 5
            property int lockDim: 40
            property int lockBlur: 1
            property int lockPanelWidth: 340
            property int lockPanelHeight: 100
            property string lockPanelColor: "232627cc"
            property int lockPanelX: 25
            property int lockPanelY: 130

            property var autostartExtra: []
        }
    }
}
