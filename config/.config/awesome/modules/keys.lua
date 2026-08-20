local awful         = require("awful")
local gears         = require("gears")
local hotkeys_popup = require("awful.hotkeys_popup")
require("awful.hotkeys_popup.keys")

-- The cheatsheet prints raw X keysyms, so hardware keys show up as
-- "XF86MonBrightnessUp". Build the default popup ourselves (show_help
-- creates it lazily, so this must run before the first Super+s) and add
-- readable labels on top of awesome's built-in ones.
-- Note: the require above already builds default_widget (it registers the
-- bundled app hotkeys through it), so create one only as a fallback and
-- always apply the labels — guarding the whole block on "not
-- default_widget" silently skips them.
local hotkeys_widget = require("awful.hotkeys_popup.widget")
if not hotkeys_widget.default_widget then
    hotkeys_widget.default_widget = hotkeys_widget.new()
end
for keysym, label in pairs({
    XF86AudioMute         = "Mute",
    XF86MonBrightnessUp   = "Bright+",
    XF86MonBrightnessDown = "Bright-",
}) do
    hotkeys_widget.default_widget.labels[keysym] = label
end

local modkey = "Mod4"

local M = {}

-- ── Power menu keyboard ──────────────────────────────────────────────────
-- quickshell draws the power menu in an override-redirect window, which a
-- window manager cannot focus and X therefore never sends key events to, so
-- the menu's own QML Keys handlers can't fire under X11 (`focusable: true`
-- is a Wayland layer-shell concept). Awesome owns the keyboard, so grab it
-- here and forward keysyms over IPC; power/PowerMenu.qml stays the single
-- definition of what each key does.
local power_grabber = nil

local function power_menu_release()
    if power_grabber then
        awful.keygrabber.stop(power_grabber)
        power_grabber = nil
    end
end

-- PowerMenu.qml calls this through awesome-client whenever the menu closes
-- — including a mouse click or an action picked with the mouse — so the
-- grab can never outlive the menu and strand the keyboard.
_G.power_menu_release = power_menu_release

local function power_menu_open()
    power_menu_release()
    awful.spawn("qs ipc call power open")
    power_grabber = awful.keygrabber.run(function(_, key, event)
        if event ~= "press" then
            return
        end
        -- Escape is handled here as well as in QML: if quickshell dies while
        -- the grab is active, this is the way out.
        if key == "Escape" then
            power_menu_release()
        end
        awful.spawn({ "qs", "ipc", "call", "power", "key", key })
    end)
end

M.globalkeys = gears.table.join(

    -- ── Awesome ────────────────────────────────────────────────────────────
    -- Both open the keybind reference: F1 for full keyboards, S for 60%
    -- boards where F1 needs Fn (and Super+Fn is the Everest's Game Mode
    -- chord — avoid holding them together).
    awful.key({ modkey }, "F1", hotkeys_popup.show_help,
        { description = "show keybindings", group = "awesome" }),
    awful.key({ modkey }, "s", hotkeys_popup.show_help,
        { description = "show keybindings", group = "awesome" }),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
        { description = "reload config", group = "awesome" }),
    awful.key({ modkey, "Control" }, "q", awesome.quit,
        { description = "quit awesome", group = "awesome" }),

    -- ── Launchers ──────────────────────────────────────────────────────────
    awful.key({ modkey }, "Return",
        function() awful.spawn(terminal) end,
        { description = "open terminal", group = "launcher" }),
    awful.key({ modkey }, "e",
        function() awful.spawn(filemanager) end,
        { description = "file manager (Thunar)", group = "launcher" }),

    -- Rofi family — all rooted at Super+Space
    awful.key({ modkey }, "space",
        function() awful.spawn("rofi -show drun") end,
        { description = "app launcher (rofi)", group = "launcher" }),
    awful.key({ modkey, "Shift" }, "space",
        function() awful.spawn("rofi -show run") end,
        { description = "run command (rofi)", group = "launcher" }),
    awful.key({ modkey, "Control" }, "space",
        function() awful.spawn("rofi -show window") end,
        { description = "window switcher (rofi)", group = "launcher" }),
    awful.key({ modkey }, "Tab",
        function() awful.spawn("rofi -show window") end,
        { description = "window switcher (rofi)", group = "launcher" }),
    awful.key({ modkey }, "/",
        function() awful.spawn("rofi -modi 'clipboard:greenclip print' -show clipboard") end,
        { description = "clipboard history", group = "launcher" }),
    awful.key({ modkey }, ".",
        function() awful.spawn("rofimoji") end,
        { description = "emoji picker", group = "launcher" }),
    awful.key({ modkey, "Shift" }, "n",
        function() awful.spawn("qs ipc call nightlight toggle") end,
        { description = "toggle night light", group = "misc" }),
    awful.key({ modkey, "Shift" }, "s",
        function() awful.spawn("qs ipc call settings toggle") end,
        { description = "shell settings", group = "misc" }),
    awful.key({ modkey, "Shift" }, "t",
        function() awful.spawn("qs ipc call theme toggle") end,
        { description = "toggle dark/light mode", group = "misc" }),
    awful.key({ modkey }, "a",
        function() awful.spawn("qs ipc call media toggle") end,
        { description = "media player panel", group = "media" }),

    -- ── Session ────────────────────────────────────────────────────────────
    awful.key({ modkey }, "BackSpace", power_menu_open,
        { description = "power menu", group = "awesome" }),
    awful.key({ "Control", "Mod1" }, "l",
        function() awful.spawn("loginctl lock-session") end,
        { description = "lock screen", group = "awesome" }),
    awful.key({ modkey, "Shift" }, "b",
        function() awful.spawn("qs ipc call notifs toggle") end,
        { description = "notification center", group = "misc" }),
    awful.key({ modkey, "Shift" }, "x",
        function() awful.spawn("qs ipc call notifs clearAll") end,
        { description = "clear notifications", group = "misc" }),
    awful.key({ modkey }, "d",
        function() awful.spawn("qs ipc call notifs dnd") end,
        { description = "toggle do not disturb", group = "misc" }),
    awful.key({ modkey, "Shift" }, "m",
        function() awful.spawn("qs ipc call sysmon toggle") end,
        { description = "system monitor (conky)", group = "misc" }),
    awful.key({ modkey }, "v",
        function() awful.spawn("qs ipc call calendar toggle") end,
        { description = "calendar", group = "misc" }),
    awful.key({ modkey }, "z",
        function() awful.spawn("qs ipc call keepawake toggle") end,
        { description = "toggle keep awake", group = "misc" }),

    -- ── Focus (directional, vim-style; crosses monitor edges) ─────────────
    awful.key({ modkey }, "h",
        function() awful.client.focus.global_bydirection("left")  end,
        { description = "focus left",  group = "client" }),
    awful.key({ modkey }, "l",
        function() awful.client.focus.global_bydirection("right") end,
        { description = "focus right", group = "client" }),
    awful.key({ modkey }, "j",
        function() awful.client.focus.global_bydirection("down")  end,
        { description = "focus down",  group = "client" }),
    awful.key({ modkey }, "k",
        function() awful.client.focus.global_bydirection("up")    end,
        { description = "focus up",    group = "client" }),

    -- ── Window swap (also crosses monitor edges) ───────────────────────────
    awful.key({ modkey, "Shift" }, "h",
        function() awful.client.swap.global_bydirection("left")  end,
        { description = "swap left",  group = "layout" }),
    awful.key({ modkey, "Shift" }, "l",
        function() awful.client.swap.global_bydirection("right") end,
        { description = "swap right", group = "layout" }),
    awful.key({ modkey, "Shift" }, "j",
        function() awful.client.swap.global_bydirection("down")  end,
        { description = "swap down",  group = "layout" }),
    awful.key({ modkey, "Shift" }, "k",
        function() awful.client.swap.global_bydirection("up")    end,
        { description = "swap up",    group = "layout" }),

    -- ── Master sizing ──────────────────────────────────────────────────────
    awful.key({ modkey, "Control" }, "h",
        function() awful.tag.incmwfact(-0.05) end,
        { description = "shrink master", group = "layout" }),
    awful.key({ modkey, "Control" }, "l",
        function() awful.tag.incmwfact(0.05) end,
        { description = "expand master", group = "layout" }),

    -- ── Layout cycling ─────────────────────────────────────────────────────
    awful.key({ modkey }, "\\",
        function() awful.layout.inc( 1) end,
        { description = "next layout", group = "layout" }),
    awful.key({ modkey, "Shift" }, "\\",
        function() awful.layout.inc(-1) end,
        { description = "previous layout", group = "layout" }),

    -- ── Tag navigation ─────────────────────────────────────────────────────
    awful.key({ modkey }, "Left",
        awful.tag.viewprev,
        { description = "previous tag", group = "tag" }),
    awful.key({ modkey }, "Right",
        awful.tag.viewnext,
        { description = "next tag", group = "tag" }),
    awful.key({ modkey }, "Escape",
        awful.tag.history.restore,
        { description = "last tag", group = "tag" }),

    -- ── Restore minimized ──────────────────────────────────────────────────
    awful.key({ modkey, "Control" }, "n",
        function()
            local c = awful.client.restore()
            if c then
                c:emit_signal("request::activate", "key.unminimize", { raise = true })
            end
        end,
        { description = "restore minimized", group = "client" }),

    -- ── Screenshot ─────────────────────────────────────────────────────────
    -- "Print" covers both full keyboards and 60% boards where Fn+K → Print keycode.
    -- If your 60% sends a different keycode, run `xev` to find it and add it here.
    -- spectacle preferred (region select + annotation); scrot as fallback.
    --
    -- The fallback is chosen on whether spectacle EXISTS, never on how it
    -- exits. `cmd && spectacle -r || scrot` looks equivalent but is not:
    -- these tools return non-zero when a selection is cancelled with Escape,
    -- so that form silently saved a full-screen scrot every time you changed
    -- your mind — and, if the capture tool is broken, on every keypress,
    -- which looks exactly like the key doing nothing at all.
    --
    -- `spectacle -r` deliberately runs in GUI mode rather than background
    -- (-b) mode. On X11 a clipboard selection is served on demand by the
    -- process holding it, so it dies the instant that process exits: `-b`
    -- copies and quits, leaving Ctrl+V pasting whatever came before. In GUI
    -- mode the editor stays open after Copy (install.sh pins
    -- quitAfterSaveCopyExport=false) and keeps serving the image, so paste
    -- into a doc/message works for as long as that window is open.
    awful.key({ }, "Print",
        function()
            awful.spawn.with_shell([[
if command -v spectacle >/dev/null 2>&1; then
    spectacle -r
else
    scrot -s '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/Screenshots/'
fi]])
        end,
        { description = "screenshot (region)", group = "misc" }),
    -- Full screen straight to disk: no editor, no clipboard, so background
    -- mode is the right call here. -n suppresses the "saved" notification
    -- (the file lands where you expect); spectacle needs an explicit -o or
    -- it uses its own configured directory.
    awful.key({ "Shift" }, "Print",
        function()
            awful.spawn.with_shell([[
if command -v spectacle >/dev/null 2>&1; then
    spectacle -f -b -n -o ~/Pictures/Screenshots/"$(date +%Y-%m-%d_%H-%M-%S)".png
else
    scrot '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/Screenshots/'
fi]])
        end,
        { description = "screenshot (full)", group = "misc" }),

    -- ── Media controls ─────────────────────────────────────────────────────
    awful.key({ "Control" }, "space",
        function() awful.spawn("playerctl play-pause") end,
        { description = "play/pause", group = "media" }),
    awful.key({ "Control" }, "Left",
        function() awful.spawn("playerctl previous") end,
        { description = "previous track", group = "media" }),
    awful.key({ "Control" }, "Right",
        function() awful.spawn("playerctl next") end,
        { description = "next track", group = "media" }),
    -- Volume goes through the shell (qs ipc) so the on-screen display fires
    awful.key({ "Control" }, "Up",
        function() awful.spawn("qs ipc call audio raise") end,
        { description = "volume up", group = "media" }),
    awful.key({ "Control" }, "Down",
        function() awful.spawn("qs ipc call audio lower") end,
        { description = "volume down", group = "media" }),

    -- Hardware media keys (the Fn row). These duplicate the Ctrl chords
    -- above, so they carry no description: a key without one still works
    -- but stays out of the Super+s cheatsheet, which otherwise listed
    -- every function twice under an unreadable "XF86Audio..." label.
    awful.key({ }, "XF86AudioRaiseVolume",
        function() awful.spawn("qs ipc call audio raise") end),
    awful.key({ }, "XF86AudioLowerVolume",
        function() awful.spawn("qs ipc call audio lower") end),
    awful.key({ }, "XF86AudioPlay",
        function() awful.spawn("playerctl play-pause") end),
    awful.key({ }, "XF86AudioPrev",
        function() awful.spawn("playerctl previous") end),
    awful.key({ }, "XF86AudioNext",
        function() awful.spawn("playerctl next") end),

    -- These have no chord equivalent, so they stay documented — the
    -- labels table below renders them as Mute / Bright+ / Bright-.
    awful.key({ }, "XF86AudioMute",
        function() awful.spawn("qs ipc call audio muteToggle") end,
        { description = "mute", group = "media" }),

    -- Backlight (no-op on machines without a backlight device)
    awful.key({ }, "XF86MonBrightnessUp",
        function() awful.spawn("qs ipc call brightness up") end,
        { description = "brightness up", group = "media" }),
    awful.key({ }, "XF86MonBrightnessDown",
        function() awful.spawn("qs ipc call brightness down") end,
        { description = "brightness down", group = "media" })
)

-- Tag number bindings (Super+[1-9], Super+Shift+[1-9], Super+Ctrl+[1-9])
for i = 1, 9 do
    M.globalkeys = gears.table.join(M.globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
            function()
                local s   = awful.screen.focused()
                local tag = s.tags[i]
                if tag then tag:view_only() end
            end,
            { description = "tag " .. i, group = "tag" }),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
            function()
                local s   = awful.screen.focused()
                local tag = s.tags[i]
                if tag then awful.tag.viewtoggle(tag) end
            end,
            { description = "toggle tag " .. i, group = "tag" }),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
            function()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then client.focus:move_to_tag(tag) end
                end
            end,
            { description = "move to tag " .. i, group = "tag" })
    )
end

-- Per-client keybindings (bound in rules.lua)
M.clientkeys = gears.table.join(
    awful.key({ modkey }, "q",
        function(c) c:kill() end,
        { description = "close", group = "client" }),
    awful.key({ modkey }, "f",
        function(c) c.fullscreen = not c.fullscreen; c:raise() end,
        { description = "fullscreen", group = "client" }),
    awful.key({ modkey, "Shift" }, "f",
        awful.client.floating.toggle,
        { description = "toggle floating", group = "client" }),
    awful.key({ modkey }, "m",
        function(c) c.maximized = not c.maximized; c:raise() end,
        { description = "maximize", group = "client" }),
    awful.key({ modkey }, "n",
        function(c) c.minimized = true end,
        { description = "minimize", group = "client" }),
    awful.key({ modkey }, "t",
        function(c) c.ontop = not c.ontop end,
        { description = "toggle on-top", group = "client" }),
    awful.key({ modkey, "Control" }, "Return",
        function(c) c:swap(awful.client.getmaster()) end,
        { description = "promote to master", group = "client" }),
    awful.key({ modkey }, "o",
        function(c) c:move_to_screen() end,
        { description = "move to next screen", group = "client" })
)

-- Client mouse buttons
M.clientbuttons = gears.table.join(
    awful.button({ }, 1, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
    end),
    awful.button({ modkey }, 1, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
        awful.mouse.client.resize(c)
    end)
)

-- Desktop right-click menu (styled by theme.lua's menu_* settings)
M.mainmenu = awful.menu({
    items = {
        -- Browsing, not typing: a scrollable list you can read through,
        -- versus rofi's type-to-filter prompt. Rofi keeps its own keys
        -- (Super+d drun, Super+r run) for when you know the name already.
        { "Apps",           function() awful.spawn("qs ipc call launcher toggle") end },
        { "Terminal",       function() awful.spawn(terminal) end },
        { "Files",          function() awful.spawn(filemanager) end },
        { "Settings",       function() awful.spawn("qs ipc call settings open appearance") end },
        { "System Monitor", function() awful.spawn("qs ipc call sysmon toggle") end },
        { "Keybindings",    function() hotkeys_popup.show_help() end },
        { "Awesome", {
            { "Reload",  awesome.restart },
            { "Log Out", function() awesome.quit() end },
        } },
        { "Power",          power_menu_open },
    },
})

-- The bar's start button opens this same menu through awesome-client, so it
-- needs a global entry point. Toggling (not showing) means a second click on
-- the button dismisses it, matching how right-click on the desktop behaves.
--
-- :toggle() places the menu at the mouse by default, which is wrong for a
-- button click: the pointer is over the bar, so coordinates come from the
-- button's own corner instead. awesome clamps it on screen from there.
_G.main_menu_toggle = function()
    M.mainmenu:toggle({ coords = mouse.coords() })
end

-- Root (desktop) mouse buttons — right-click menu; scroll to switch tags.
-- Scroll down (button 5) = next tag, matching the bar taglist direction.
M.rootbuttons = gears.table.join(
    awful.button({ }, 3, function() M.mainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewprev),
    awful.button({ }, 5, awful.tag.viewnext)
)

return M
