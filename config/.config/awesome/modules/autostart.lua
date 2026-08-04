local awful = require("awful")

-- Spawn a program if it isn't already running.
--
-- The check and the launch have to be separate processes. Three traps sit
-- between here and the obvious one-liner:
--
--  1. `sh -c "pgrep -f 'x' || x"` can never start anything: the command in
--     the || branch puts the pattern into the guard's *own* command line,
--     so pgrep -f matches the guard, which concludes the program is already
--     running. The [f]irst-char bracket only hides the pattern from itself,
--     not the unbracketed command sitting next to it in the same argv.
--  2. `pgrep -x` can't replace -f: it matches the 15-char comm only, so it
--     can't see arguments ("greenclip daemon") and truncates long names
--     ("lxqt-policykit-agent").
--  3. awful.spawn.easy_async would avoid the shell entirely, but it is
--     broken on current glib — Gio.UnixInputStream moved to
--     GioUnix.InputStream, so it raises "attempt to index a nil value
--     (field 'UnixInputStream')" on awesome 4.3.
--
-- So the probe runs pgrep alone, where the bracket trick genuinely works
-- because the pattern is the only thing in that command line, and the
-- launch is a plain shell-less awful.spawn afterwards.
local function run_once(cmd_arr)
    local pattern = table.concat(cmd_arr, " ")
    -- Extra parens: gsub returns (string, count), and a bare call would
    -- pass the count to format as a second argument.
    local guarded = (pattern:gsub("^(.)", "[%1]"))
    -- Single-quoted for the shell: the patterns are fixed strings from this
    -- file (names, flags, paths), none of which contain a single quote.
    local probe = io.popen(
        'pgrep -u "$USER" -f -- \'' .. guarded .. '\' >/dev/null 2>&1; echo $?')
    if not probe then
        return
    end
    local status = probe:read("*a") or ""
    probe:close()
    if not status:match("^0") then
        awful.spawn(cmd_arr, false)
    end
end

-- Tie the systemd user session lifecycle to this session: services hooked
-- to graphical-session.target (espanso, ...) start here like they did
-- under Plasma. The matching stop lives in rc.lua's exit handler.
-- AWESOME_SESSION marks "this session is awesome, not Plasma" for the
-- drop-ins install.sh adds to plasma-kglobalaccel/plasma-krunner: those
-- units are skipped while it is set, so KDE's shortcut daemon can't claim
-- Meta+Space (KRunner's default) away from the rofi launcher. Cleared again
-- in rc.lua's exit handler. A variable we own is used rather than
-- XDG_CURRENT_DESKTOP because the user manager lingers, so its environment
-- outlives the session and a stale value would follow you into Plasma.
awful.spawn.with_shell(
    "systemctl --user import-environment DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP DESKTOP_SESSION 2>/dev/null; "
    .. "systemctl --user set-environment AWESOME_SESSION=1 2>/dev/null; "
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

-- Flameshot's background instance. This is what makes the Copy button work:
-- on X11 a clipboard selection is served on demand by the process that
-- owns it, so it lives exactly as long as that process does. `flameshot gui`
-- launched cold takes the shot, copies, and exits — and CLIPBOARD is left
-- with no owner the moment it does, so the Copy button appeared to do
-- nothing and Ctrl+V pasted whatever came before. greenclip doesn't cover
-- for it either; it never claims ownership of the image.
--
-- With this running, Print's `flameshot gui` hands the capture to the
-- background instance over D-Bus and that instance keeps holding the
-- selection, so the image stays pasteable for the rest of the session.
-- install.sh turns its tray icon off; the bar has its own tray and Print is
-- the entry point. Harmless where flameshot isn't installed (Print falls
-- back to scrot).
run_once({ "flameshot" })

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
run_once({ "/usr/libexec/lxqt-policykit-agent" })

-- Screen locking: xss-lock bridges X screensaver + systemd (loginctl
-- lock-session, lock-before-suspend) to the lock-screen wrapper script.
run_once({ "xss-lock", "--transfer-sleep-lock", "--", "lock-screen" })

-- Idle/DPMS timeouts are quickshell's job now (Settings app → Power page;
-- common/PowerConfig.qml runs xset from settings at startup and on change).

return {}
