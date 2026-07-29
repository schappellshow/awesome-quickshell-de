pcall(require, "luarocks.loader")

-- Quickshell owns org.freedesktop.Notifications; stub out naughty's dbus
-- module BEFORE naughty loads so awesome doesn't claim the name. naughty
-- still renders internal errors (startup/runtime) directly.
package.loaded["naughty.dbus"] = {}

local gears     = require("gears")
local awful     = require("awful")
local beautiful = require("beautiful")
local naughty   = require("naughty")
require("awful.autofocus")

-- Error handling must come before anything else
if awesome.startup_errors then
    naughty.notify({
        preset = naughty.config.presets.critical,
        title  = "Startup error",
        text   = awesome.startup_errors,
    })
end
do
    local in_error = false
    awesome.connect_signal("debug::error", function(err)
        if in_error then return end
        in_error = true
        naughty.notify({
            preset = naughty.config.presets.critical,
            title  = "Runtime error",
            text   = tostring(err),
        })
        in_error = false
    end)
end

beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")

-- Pick the first installed candidate so a fresh clone works without
-- editing this file; override any of them with the matching env var
-- (TERMINAL / FILE_MANAGER / EDITOR), e.g. in ~/.xprofile.
local function first_installed(candidates, fallback)
    for _, cmd in ipairs(candidates) do
        local bin = cmd:match("^%S+")
        if os.execute("command -v " .. bin .. " >/dev/null 2>&1") then
            return cmd
        end
    end
    return fallback
end

terminal    = os.getenv("TERMINAL") or first_installed(
    { "ghostty", "kitty", "alacritty", "wezterm", "foot", "konsole",
      "gnome-terminal", "xfce4-terminal" }, "xterm")
filemanager = os.getenv("FILE_MANAGER") or first_installed(
    { "thunar", "pcmanfm-qt", "pcmanfm", "nemo", "nautilus", "dolphin" },
    "xdg-open ~")
editor      = os.getenv("EDITOR") or first_installed(
    { "micro", "nano", "vim", "nvim" }, "vi")
modkey      = "Mod4"

awful.layout.layouts = {
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.fair,
    awful.layout.suit.max,
    awful.layout.suit.floating,
}

local keys      = require("modules.keys")
local qs_bridge = require("modules.quickshell")
local scr_mem   = require("modules.screen_memory")
local _rules    = require("modules.rules")
local _auto     = require("modules.autostart")

awful.screen.connect_for_each_screen(function(s)
    -- Portrait monitors stack windows vertically (master on top, new
    -- windows below); landscape screens keep dwindle.
    local default = s.geometry.height > s.geometry.width
        and awful.layout.suit.tile.bottom
        or awful.layout.layouts[1]
    -- 4 tags is plenty; bump this list if more are ever needed
    -- (Super+[1-9] bindings already cover up to 9)
    awful.tag(
        { "1", "2", "3", "4" },
        s,
        default
    )
end)

-- Cold boot ordering: awesome creates tags before quickshell replays the
-- saved xrandr layout, so a to-be-rotated screen still reads landscape at
-- tag creation and gets the wrong default. When a screen's orientation
-- changes, retarget only tags still sitting on the other orientation's
-- default — manual layout choices survive untouched.
screen.connect_signal("property::geometry", function(s)
    local portrait = s.geometry.height > s.geometry.width
    local from = portrait and awful.layout.suit.spiral.dwindle
                          or  awful.layout.suit.tile.bottom
    local to   = portrait and awful.layout.suit.tile.bottom
                          or  awful.layout.suit.spiral.dwindle
    for _, t in ipairs(s.tags) do
        if t.layout == from then
            t.layout = to
        end
    end
end)

-- The bar itself is quickshell (spawned in autostart.lua); this feeds it
-- tag/layout state.
qs_bridge.setup()

-- Remember each window's output+tag so a monitor coming back doesn't leave
-- windows piled on the wrong screen (see modules/screen_memory.lua)
scr_mem.setup()

-- Stop the systemd session target on real logout (not on Super+Ctrl+R),
-- so graphical-session services (espanso, ...) shut down like under Plasma.
awesome.connect_signal("exit", function(restarting)
    if not restarting then
        awful.spawn.with_shell("systemctl --user stop awesome-session.target")
    end
end)

-- Some GTK apps (ghostty) send a post-map configure request to move
-- themselves to absolute coordinates; honoring it yanked freshly spawned
-- tiled windows onto the leftmost monitor. Only floating clients may
-- reposition themselves — the layout owns tiled geometry.
client.disconnect_signal("request::geometry", awful.ewmh.client_geometry_requests)
client.connect_signal("request::geometry", function(c, context, hints)
    if c.floating then
        awful.ewmh.client_geometry_requests(c, context, hints)
    end
end)

root.keys(keys.globalkeys)
root.buttons(keys.rootbuttons)

-- Rounded corners via XCB shape extension on every new client
client.connect_signal("manage", function(c)
    if not awesome.startup then
        awful.client.setslave(c)
    end
    c.shape = function(cr, w, h)
        gears.shape.rounded_rect(cr, w, h, beautiful.border_radius)
    end
end)

client.connect_signal("focus",   function(c) c.border_color = beautiful.border_focus  end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

-- Sloppy focus (mouse-follows-focus like Hyprland default)
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", { raise = false })
end)
