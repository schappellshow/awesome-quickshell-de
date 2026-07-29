local awful = require("awful")

-- Spawn a program if it isn't already running. The [f]irst-char bracket
-- keeps pgrep -f from matching this guard's own shell command line
-- (and -x can't be used: it only sees the 15-char comm, so patterns with
-- arguments like "greenclip daemon" never matched and respawned dupes).
local function run_once(cmd_arr)
    local findme  = cmd_arr[1]
    local firstarg = cmd_arr[2]
    if firstarg then
        findme = findme .. " " .. firstarg
    end
    findme = findme:gsub("^(.)", "[%1]")
    awful.spawn.with_shell(string.format(
        "pgrep -u $USER -f '%s' > /dev/null || (%s)",
        findme,
        table.concat(cmd_arr, " ")
    ))
end

-- Tie the systemd user session lifecycle to this session: services hooked
-- to graphical-session.target (espanso, ...) start here like they did
-- under Plasma. The matching stop lives in rc.lua's exit handler.
awful.spawn.with_shell(
    "systemctl --user import-environment DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP DESKTOP_SESSION 2>/dev/null; "
    .. "systemctl --user start awesome-session.target"
)

-- Kill the system-default xcompmgr before picom claims the compositing slot
awful.spawn.with_shell(
    "pkill -x xcompmgr; sleep 0.5 && picom --config ~/.config/picom/picom.conf --daemon"
)

-- Wallpaper is quickshell's job now (Settings app → Wallpaper page;
-- common/Wallpaper.qml runs feh from Settings.wallpaperPath at startup).

-- Quickshell: bar, notifications, settings app (config in ~/.config/quickshell)
awful.spawn.with_shell(
    "pgrep -x quickshell >/dev/null || pgrep -x qs >/dev/null || qs >/dev/null 2>&1 &"
)

-- Clipboard daemon (feeds Super+/ rofi clipboard picker)
run_once({ "greenclip", "daemon" })

-- xsettingsd propagates GTK/icon theme to running apps
run_once({ "xsettingsd" })

-- Automount removable media (USB sticks, SD cards): udiskie watches
-- udisks2 and mounts + notifies on insert. --no-tray keeps it headless;
-- eject/unmount is available from Thunar's sidebar.
run_once({ "udiskie", "--no-tray" })

-- Serve org.freedesktop.ScreenSaver so a video playing fullscreen keeps
-- the screen awake. Browsers/players call that API; with nobody owning it
-- the screen blanked and locked mid-video.
run_once({ os.getenv("HOME") .. "/.local/bin/screensaver-inhibitor" })

-- Secret Service (org.freedesktop.secrets) for apps that vault
-- credentials (Mailspring, browsers, ...): ksecretd, KWallet's KF6
-- secrets daemon — the deliberate KDE exception on this setup.
-- Not run_once: kwallet-pam leaves a bus-less `ksecretd --pam-login`
-- running that registers nothing but satisfies any pgrep guard, so the
-- script checks D-Bus name ownership instead (see ensure-secret-service).
awful.spawn.with_shell(os.getenv("HOME") .. "/.local/bin/ensure-secret-service")

-- Polkit authentication agent (lxqt-policykit: Qt-native, no KDE deps).
-- [l] bracket trick: without it, pgrep -f matches this guard's own shell
-- command line and the agent never starts.
awful.spawn.with_shell(
    "pgrep -u $USER -f '[l]xqt-policykit-agent' > /dev/null || /usr/libexec/lxqt-policykit-agent &"
)

-- Screen locking: xss-lock bridges X screensaver + systemd (loginctl
-- lock-session, lock-before-suspend) to the lock-screen wrapper script.
awful.spawn.with_shell(
    "pgrep -u $USER -x xss-lock > /dev/null || xss-lock --transfer-sleep-lock -- lock-screen &"
)

-- Idle/DPMS timeouts are quickshell's job now (Settings app → Power page;
-- common/PowerConfig.qml runs xset from settings at startup and on change).

return {}
