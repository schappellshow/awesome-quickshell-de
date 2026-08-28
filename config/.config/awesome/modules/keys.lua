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
local unpack = table.unpack or unpack

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
    awful.spawn("qs ipc call power open", false)
    power_grabber = awful.keygrabber.run(function(_, key, event)
        if event ~= "press" then
            return
        end
        -- Escape is handled here as well as in QML: if quickshell dies while
        -- the grab is active, this is the way out.
        if key == "Escape" then
            power_menu_release()
        end
        awful.spawn({ "qs", "ipc", "call", "power", "key", key }, false)
    end)
end

-- ── The registry ─────────────────────────────────────────────────────────
-- Every rebindable shortcut, as data rather than as a call to awful.key.
-- Settings -> Keyboard edits these, so the chord has to be a value the
-- shell can read and replace; the action stays here, where it belongs.
--
-- `id` is the stable name an override is stored against. It has to survive a
-- rebind, a relabel and a reorder — which is exactly what the chord, the
-- label and the position cannot do — so ids are written once and never
-- reused for something else.
--
-- `label` doubles as the cheatsheet description, so Super+s keeps showing
-- whatever the shortcut is actually bound to today rather than what it
-- shipped as.
--
-- Not everything is in here. The tag bindings are 27 keys generated in a
-- loop from one pattern, and the hardware media keys duplicate chords that
-- are already listed; both would cost more rows than they are worth. They
-- stay bound below, outside the registry, and the page says so.
local mods_super       = { modkey }
local mods_super_shift = { modkey, "Shift" }
local mods_super_ctrl  = { modkey, "Control" }

local function spawn(cmd)
    return function() awful.spawn(cmd) end
end

-- Startup notification is launch feedback: from the moment a spawn is
-- initiated, awesome paints the root cursor as a spinner and only clears it
-- when the new window claims the notification -- or when
-- libstartup-notification gives up, thirty seconds later. A command that
-- never maps a window can only ever hit that timeout, so every `qs ipc
-- call`, playerctl and loginctl would leave a spinning pointer over the
-- desktop for half a minute. `false` opts them out. Anything that does open
-- a window keeps the feedback, which is the case it was written for.
local function run(cmd)
    return function() awful.spawn(cmd, false) end
end

local function ipc(...)
    local args = { ... }
    return function()
        awful.spawn("qs ipc call " .. table.concat(args, " "), false)
    end
end

M.registry = {
    -- ── Awesome ──────────────────────────────────────────────────────────
    -- Two entries for the reference, not one: F1 for full keyboards, S for
    -- 60% boards where F1 needs Fn (and Super+Fn is the Everest's Game Mode
    -- chord — avoid holding them together).
    { id = "awesome.help",      group = "awesome", label = "show keybindings",
      mods = mods_super, key = "F1", fn = hotkeys_popup.show_help },
    { id = "awesome.help.alt",  group = "awesome", label = "show keybindings (alt)",
      mods = mods_super, key = "s", fn = hotkeys_popup.show_help },
    { id = "awesome.restart",   group = "awesome", label = "reload config",
      mods = mods_super_ctrl, key = "r", fn = awesome.restart },
    { id = "awesome.quit",      group = "awesome", label = "quit awesome",
      mods = mods_super_ctrl, key = "q", fn = awesome.quit },
    { id = "awesome.power",     group = "awesome", label = "power menu",
      mods = mods_super, key = "BackSpace", fn = power_menu_open },
    { id = "awesome.lock",      group = "awesome", label = "lock screen",
      mods = { "Control", "Mod1" }, key = "l",
      fn = run("loginctl lock-session") },

    -- ── Launchers ────────────────────────────────────────────────────────
    { id = "launcher.terminal", group = "launcher", label = "open terminal",
      mods = mods_super, key = "Return",
      fn = function() awful.spawn(terminal) end },
    { id = "launcher.files",    group = "launcher", label = "file manager",
      mods = mods_super, key = "e",
      fn = function() awful.spawn(filemanager) end },
    -- The rofi family, all rooted at Super+Space
    { id = "launcher.apps",     group = "launcher", label = "app launcher (rofi)",
      mods = mods_super, key = "space", fn = spawn("rofi -show drun") },
    { id = "launcher.run",      group = "launcher", label = "run command (rofi)",
      mods = mods_super_shift, key = "space", fn = spawn("rofi -show run") },
    { id = "launcher.windows",  group = "launcher", label = "window switcher (rofi)",
      mods = mods_super_ctrl, key = "space", fn = spawn("rofi -show window") },
    { id = "launcher.windows.alt", group = "launcher", label = "window switcher (alt)",
      mods = mods_super, key = "Tab", fn = spawn("rofi -show window") },
    { id = "launcher.clipboard", group = "launcher", label = "clipboard history",
      mods = mods_super, key = "/",
      fn = spawn("rofi -modi 'clipboard:greenclip print' -show clipboard") },
    { id = "launcher.emoji",    group = "launcher", label = "emoji picker",
      mods = mods_super, key = ".", fn = spawn("rofimoji") },

    -- ── Shell panels ─────────────────────────────────────────────────────
    { id = "shell.settings",    group = "misc", label = "shell settings",
      mods = mods_super_shift, key = "s", fn = ipc("settings", "toggle") },
    { id = "shell.theme",       group = "misc", label = "toggle dark/light mode",
      mods = mods_super_shift, key = "t", fn = ipc("theme", "toggle") },
    { id = "shell.nightlight",  group = "misc", label = "toggle night light",
      mods = mods_super_shift, key = "n", fn = ipc("nightlight", "toggle") },
    { id = "shell.notifs",      group = "misc", label = "notification center",
      mods = mods_super_shift, key = "b", fn = ipc("notifs", "toggle") },
    { id = "shell.notifs.clear", group = "misc", label = "clear notifications",
      mods = mods_super_shift, key = "x", fn = ipc("notifs", "clearAll") },
    { id = "shell.dnd",         group = "misc", label = "toggle do not disturb",
      mods = mods_super, key = "d", fn = ipc("notifs", "dnd") },
    { id = "shell.sysmon",      group = "misc", label = "system monitor (conky)",
      mods = mods_super_shift, key = "m", fn = ipc("sysmon", "toggle") },
    { id = "shell.calendar",    group = "misc", label = "calendar",
      mods = mods_super, key = "v", fn = ipc("calendar", "toggle") },
    { id = "shell.keepawake",   group = "misc", label = "toggle keep awake",
      mods = mods_super, key = "z", fn = ipc("keepawake", "toggle") },
    { id = "shell.media",       group = "media", label = "media player panel",
      mods = mods_super, key = "a", fn = ipc("media", "toggle") },

    -- ── Focus (directional, vim-style; crosses monitor edges) ────────────
    { id = "client.focus.left",  group = "client", label = "focus left",
      mods = mods_super, key = "h",
      fn = function() awful.client.focus.global_bydirection("left") end },
    { id = "client.focus.right", group = "client", label = "focus right",
      mods = mods_super, key = "l",
      fn = function() awful.client.focus.global_bydirection("right") end },
    { id = "client.focus.down",  group = "client", label = "focus down",
      mods = mods_super, key = "j",
      fn = function() awful.client.focus.global_bydirection("down") end },
    { id = "client.focus.up",    group = "client", label = "focus up",
      mods = mods_super, key = "k",
      fn = function() awful.client.focus.global_bydirection("up") end },

    -- ── Window swap (also crosses monitor edges) ─────────────────────────
    { id = "layout.swap.left",  group = "layout", label = "swap left",
      mods = mods_super_shift, key = "h",
      fn = function() awful.client.swap.global_bydirection("left") end },
    { id = "layout.swap.right", group = "layout", label = "swap right",
      mods = mods_super_shift, key = "l",
      fn = function() awful.client.swap.global_bydirection("right") end },
    { id = "layout.swap.down",  group = "layout", label = "swap down",
      mods = mods_super_shift, key = "j",
      fn = function() awful.client.swap.global_bydirection("down") end },
    { id = "layout.swap.up",    group = "layout", label = "swap up",
      mods = mods_super_shift, key = "k",
      fn = function() awful.client.swap.global_bydirection("up") end },

    -- ── Master sizing ────────────────────────────────────────────────────
    { id = "layout.master.shrink", group = "layout", label = "shrink master",
      mods = mods_super_ctrl, key = "h",
      fn = function() awful.tag.incmwfact(-0.05) end },
    { id = "layout.master.grow",   group = "layout", label = "expand master",
      mods = mods_super_ctrl, key = "l",
      fn = function() awful.tag.incmwfact(0.05) end },

    -- ── Layout cycling ───────────────────────────────────────────────────
    { id = "layout.next", group = "layout", label = "next layout",
      mods = mods_super, key = "\\",
      fn = function() awful.layout.inc(1) end },
    { id = "layout.prev", group = "layout", label = "previous layout",
      mods = mods_super_shift, key = "\\",
      fn = function() awful.layout.inc(-1) end },

    -- ── Tag navigation ───────────────────────────────────────────────────
    { id = "tag.prev", group = "tag", label = "previous tag",
      mods = mods_super, key = "Left", fn = awful.tag.viewprev },
    { id = "tag.next", group = "tag", label = "next tag",
      mods = mods_super, key = "Right", fn = awful.tag.viewnext },
    { id = "tag.last", group = "tag", label = "last tag",
      mods = mods_super, key = "Escape", fn = awful.tag.history.restore },

    -- ── Restore minimized ────────────────────────────────────────────────
    { id = "client.unminimize", group = "client", label = "restore minimized",
      mods = mods_super_ctrl, key = "n",
      fn = function()
          local c = awful.client.restore()
          if c then
              c:emit_signal("request::activate", "key.unminimize", { raise = true })
          end
      end },

    -- ── Screenshot ───────────────────────────────────────────────────────
    -- "Print" covers both full keyboards and 60% boards where Fn+K → Print
    -- keycode. If your 60% sends a different keycode, rebind it in
    -- Settings -> Keyboard rather than editing this file.
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
    { id = "misc.screenshot.region", group = "misc", label = "screenshot (region)",
      mods = {}, key = "Print",
      fn = function()
          awful.spawn.with_shell([[
if command -v spectacle >/dev/null 2>&1; then
    spectacle -r
else
    scrot -s '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/Screenshots/'
fi]])
      end },
    -- Full screen straight to disk: no editor, no clipboard, so background
    -- mode is the right call here. -n suppresses the "saved" notification
    -- (the file lands where you expect); spectacle needs an explicit -o or
    -- it uses its own configured directory.
    { id = "misc.screenshot.full", group = "misc", label = "screenshot (full)",
      mods = { "Shift" }, key = "Print",
      fn = function()
          awful.spawn.with_shell([[
if command -v spectacle >/dev/null 2>&1; then
    spectacle -f -b -n -o ~/Pictures/Screenshots/"$(date +%Y-%m-%d_%H-%M-%S)".png
else
    scrot '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/Screenshots/'
fi]])
      end },

    -- ── Media controls ───────────────────────────────────────────────────
    { id = "media.playpause", group = "media", label = "play/pause",
      mods = { "Control" }, key = "space", fn = run("playerctl play-pause") },
    { id = "media.prev", group = "media", label = "previous track",
      mods = { "Control" }, key = "Left", fn = run("playerctl previous") },
    { id = "media.next", group = "media", label = "next track",
      mods = { "Control" }, key = "Right", fn = run("playerctl next") },
    -- Volume goes through the shell (qs ipc) so the on-screen display fires
    { id = "media.volume.up", group = "media", label = "volume up",
      mods = { "Control" }, key = "Up", fn = ipc("audio", "raise") },
    { id = "media.volume.down", group = "media", label = "volume down",
      mods = { "Control" }, key = "Down", fn = ipc("audio", "lower") },
    { id = "media.mute", group = "media", label = "mute",
      mods = {}, key = "XF86AudioMute", fn = ipc("audio", "muteToggle") },
    -- Backlight (no-op on machines without a backlight device)
    { id = "media.brightness.up", group = "media", label = "brightness up",
      mods = {}, key = "XF86MonBrightnessUp", fn = ipc("brightness", "up") },
    { id = "media.brightness.down", group = "media", label = "brightness down",
      mods = {}, key = "XF86MonBrightnessDown", fn = ipc("brightness", "down") },

    -- ── Per-client (bound on the focused window, via rules.lua) ──────────
    { id = "window.close", group = "client", label = "close", client = true,
      mods = mods_super, key = "q", fn = function(c) c:kill() end },
    { id = "window.fullscreen", group = "client", label = "fullscreen", client = true,
      mods = mods_super, key = "f",
      fn = function(c) c.fullscreen = not c.fullscreen; c:raise() end },
    { id = "window.floating", group = "client", label = "toggle floating", client = true,
      mods = mods_super_shift, key = "f", fn = awful.client.floating.toggle },
    { id = "window.maximize", group = "client", label = "maximize", client = true,
      mods = mods_super, key = "m",
      fn = function(c) c.maximized = not c.maximized; c:raise() end },
    { id = "window.minimize", group = "client", label = "minimize", client = true,
      mods = mods_super, key = "n", fn = function(c) c.minimized = true end },
    { id = "window.ontop", group = "client", label = "toggle on-top", client = true,
      mods = mods_super, key = "t", fn = function(c) c.ontop = not c.ontop end },
    { id = "window.promote", group = "client", label = "promote to master", client = true,
      mods = mods_super_ctrl, key = "Return",
      fn = function(c) c:swap(awful.client.getmaster()) end },
    { id = "window.tonextscreen", group = "client", label = "move to next screen",
      client = true, mods = mods_super, key = "o",
      fn = function(c) c:move_to_screen() end },
}

-- ── Chords ───────────────────────────────────────────────────────────────
-- A chord is one string, "Mod4+Shift+space": that is what the shell stores,
-- what it shows, and what comes back from a capture, so there is one spelling
-- to agree on rather than a modifier list crossing the bridge as data.
--
-- Super first, because that is the order this config's cheatsheet and README
-- already read in. Lock and Mod2 are deliberately absent: they are Caps Lock
-- and Num Lock, which are states rather than chords, and a capture taken with
-- Num Lock on would otherwise bind a shortcut that only works with Num Lock
-- on.
local MOD_ORDER = { "Mod4", "Mod1", "Control", "Shift" }
local MOD_KNOWN = { Mod4 = true, Mod1 = true, Control = true, Shift = true }

function M.chord(mods, key)
    local out = {}
    for _, name in ipairs(MOD_ORDER) do
        for _, held in ipairs(mods or {}) do
            if held == name then
                out[#out + 1] = name
            end
        end
    end
    out[#out + 1] = key
    return table.concat(out, "+")
end

-- "Mod4+Shift+space" -> { "Mod4", "Shift" }, "space".
-- The key is whatever follows the last +, so a chord on the + key itself
-- ("plus", as X names it) survives the round trip.
function M.parse(chord)
    local parts = {}
    for part in tostring(chord):gmatch("[^+]+") do
        parts[#parts + 1] = part
    end
    if #parts == 0 then
        return nil
    end
    local key = table.remove(parts)
    local mods = {}
    for _, name in ipairs(parts) do
        if MOD_KNOWN[name] then
            mods[#mods + 1] = name
        end
    end
    return mods, key
end

-- ── Building ─────────────────────────────────────────────────────────────
M.overrides = {}

-- Shortcuts the user invented, as { chord, command } — a chord bound to a
-- command rather than to anything this file knows how to do. They have no
-- default and no id here: the shell owns the list, and awesome is only told
-- what to bind. See common/Shortcuts.qml.
M.custom = {}

local function entry_chord(entry)
    local override = M.overrides[entry.id]
    if override and override ~= "" then
        return override
    end
    return M.chord(entry.mods, entry.key)
end

-- One awful.key from one registry entry, or nil if the chord is unusable.
--
-- pcall rather than trust: an override arrives from a settings file that can
-- be hand-edited or imported from someone else. An unresolvable keysym does
-- not raise — awful.key builds a binding that never fires, costing that one
-- shortcut and nothing else — but malformed input further in does, and losing
-- one shortcut to a bad chord beats losing every shortcut after it.
local function build_key(entry)
    local mods, key = M.parse(entry_chord(entry))
    if not mods or key == "" then
        return nil
    end
    local ok, k = pcall(awful.key, mods, key, entry.fn,
        { description = entry.label, group = entry.group })
    if not ok then
        return nil
    end
    return k
end

function M.build()
    local globals = {}
    local clients = {}
    for _, entry in ipairs(M.registry) do
        local k = build_key(entry)
        if k then
            local into = entry.client and clients or globals
            into[#into + 1] = k
        end
    end

    -- The user's own. with_shell rather than a bare spawn: this is a command
    -- somebody typed into a text field, and pipes, quoting and ~ are exactly
    -- what they will expect to work. The command doubles as the cheatsheet
    -- description, so Super+s lists these next to everything else.
    for _, entry in ipairs(M.custom) do
        local mods, key = M.parse(entry.chord)
        if mods and key ~= "" and entry.command ~= "" then
            local ok, k = pcall(awful.key, mods, key,
                function() awful.spawn.with_shell(entry.command) end,
                { description = entry.command, group = "custom" })
            if ok then
                globals[#globals + 1] = k
            end
        end
    end

    -- Tag bindings: Super+[1-9], Super+Shift+[1-9], Super+Ctrl+[1-9].
    -- Generated rather than listed, and so left out of the registry — see
    -- the note above it.
    for i = 1, 9 do
        globals[#globals + 1] = awful.key({ modkey }, "#" .. i + 9,
            function()
                local s   = awful.screen.focused()
                local tag = s.tags[i]
                if tag then tag:view_only() end
            end,
            { description = "tag " .. i, group = "tag" })
        globals[#globals + 1] = awful.key({ modkey, "Control" }, "#" .. i + 9,
            function()
                local s   = awful.screen.focused()
                local tag = s.tags[i]
                if tag then awful.tag.viewtoggle(tag) end
            end,
            { description = "toggle tag " .. i, group = "tag" })
        globals[#globals + 1] = awful.key({ modkey, "Shift" }, "#" .. i + 9,
            function()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then client.focus:move_to_tag(tag) end
                end
            end,
            { description = "move to tag " .. i, group = "tag" })
    end

    -- Hardware media keys (the Fn row). These duplicate chords already in the
    -- registry, so they carry no description: a key without one still works
    -- but stays out of the Super+s cheatsheet, which otherwise listed every
    -- function twice under an unreadable "XF86Audio..." label. Fixed, for the
    -- same reason — rebinding a key that is already engraved with its job is
    -- not a setting anyone wants.
    for keysym, fn in pairs({
        XF86AudioRaiseVolume = ipc("audio", "raise"),
        XF86AudioLowerVolume = ipc("audio", "lower"),
        XF86AudioPlay        = run("playerctl play-pause"),
        XF86AudioPrev        = run("playerctl previous"),
        XF86AudioNext        = run("playerctl next"),
    }) do
        globals[#globals + 1] = awful.key({}, keysym, fn)
    end

    -- awful.key returns a TABLE of key objects (one per modifier variant),
    -- which is why every awesome config joins them rather than appending.
    M.globalkeys = gears.table.join(unpack(globals))
    M.clientkeys = gears.table.join(unpack(clients))
end

-- ── Overrides from the shell ─────────────────────────────────────────────
-- Applied live: root.keys re-grabs, and every managed client is handed the
-- new per-client table, so a rebind takes effect without a reload.
--
-- The payload is newline-separated "id=chord" rather than JSON, because
-- awesome has no JSON parser and a key name can never contain a newline —
-- which no other separator can promise, given that ; | and , are all keys
-- somebody might bind.
function M.apply(payload, custom)
    local seen = {}
    for _, entry in ipairs(M.registry) do
        seen[entry.id] = true
    end

    M.overrides = {}
    for line in tostring(payload or ""):gmatch("[^\n]+") do
        local id, chord = line:match("^([^=]+)=(.*)$")
        -- Unknown ids are dropped rather than kept: they are shortcuts that
        -- have been removed or renamed, and holding them would quietly
        -- resurrect one the day an id gets reused.
        if id and seen[id] then
            M.overrides[id] = chord
        end
    end

    -- Same shape, but the other way round: here the chord is the key and
    -- everything after the FIRST = is the command, which is free text and can
    -- perfectly well contain more of them.
    M.custom = {}
    for line in tostring(custom or ""):gmatch("[^\n]+") do
        local chord, command = line:match("^([^=]+)=(.*)$")
        if chord and command and command ~= "" then
            M.custom[#M.custom + 1] = { chord = chord, command = command }
        end
    end

    M.build()
    root.keys(M.globalkeys)
    for _, c in ipairs(client.get()) do
        pcall(function() c:keys(M.clientkeys) end)
    end
end

_G.apply_shortcuts = function(payload, custom) M.apply(payload, custom) end

-- ── Publishing the registry ──────────────────────────────────────────────
-- Written where quickshell can read it, so Settings -> Keyboard generates
-- its shortcut list from this file rather than from a copy that would drift.
-- Rewritten on every awesome start, which is also every time this list can
-- have changed.
local registry_path =
    (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/awesomewm-shortcuts.json"

local function esc(s)
    local out = tostring(s):gsub('[\\"]', "\\%0"):gsub("\n", "\\n")
    return out
end

function M.write_registry()
    local parts = {}
    for _, entry in ipairs(M.registry) do
        parts[#parts + 1] = string.format(
            '{"id":"%s","group":"%s","label":"%s","chord":"%s","client":%s}',
            esc(entry.id), esc(entry.group), esc(entry.label),
            esc(M.chord(entry.mods, entry.key)), tostring(entry.client == true))
    end
    local f = io.open(registry_path, "w")
    if not f then
        return
    end
    f:write("[" .. table.concat(parts, ",") .. "]")
    f:close()
end

-- ── Capture ──────────────────────────────────────────────────────────────
-- Recording a chord has to happen here, not in the settings window: awesome
-- has grabbed most of the interesting combinations, so Super+Space would
-- open rofi long before Qt saw a key event. Grabbing the keyboard the way the
-- power menu does gets the whole chord — and gets it as X keysyms, which is
-- what a binding needs anyway.
local capture_grabber = nil

local function capture_stop()
    if capture_grabber then
        awful.keygrabber.stop(capture_grabber)
        capture_grabber = nil
    end
end

-- Held on their own these are not a chord, they are the run-up to one.
local MODIFIER_KEYS = {
    Super_L = true, Super_R = true, Control_L = true, Control_R = true,
    Shift_L = true, Shift_R = true, Alt_L = true, Alt_R = true,
    Meta_L = true, Meta_R = true, Hyper_L = true, Hyper_R = true,
    ISO_Level3_Shift = true, Caps_Lock = true, Num_Lock = true,
}

function M.capture(id)
    capture_stop()
    capture_grabber = awful.keygrabber.run(function(mods, key, event)
        if event ~= "press" or MODIFIER_KEYS[key] then
            return
        end
        capture_stop()
        -- Escape cancels; there is no way to bind Escape itself from here,
        -- which is the trade every settings app makes for having a way out.
        if key == "Escape" then
            awful.spawn({ "qs", "ipc", "call", "shortcuts", "cancel" }, false)
            return
        end
        awful.spawn({ "qs", "ipc", "call", "shortcuts", "captured",
                      id, M.chord(mods, key) }, false)
    end)
end

-- Called by the shell when the row is closed or the window loses focus, so a
-- grab can never outlive the thing that asked for it and strand the keyboard.
_G.shortcut_capture = function(id) M.capture(id) end
_G.shortcut_capture_stop = capture_stop

-- ── Menus and mouse ──────────────────────────────────────────────────────
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
        { "Apps",           function() awful.spawn("qs ipc call launcher toggle", false) end },
        { "Terminal",       function() awful.spawn(terminal) end },
        { "Files",          function() awful.spawn(filemanager) end },
        { "Settings",       function() awful.spawn("qs ipc call settings open appearance", false) end },
        { "System Monitor", function() awful.spawn("qs ipc call sysmon toggle", false) end },
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

-- The same menu, placed beside the bar's start button instead of at the
-- pointer. Settings -> Apps offers the choice, because the Super tap has no
-- pointer to speak of.
--
-- Coordinates arrive relative to a screen origin: the shell cannot know which
-- monitor you are working on and awesome can. `inner` is the bar's inner edge,
-- gap included; `along` is how far down (or across) the bar the button sits;
-- `output` names the monitor the bar is on, or "" when every monitor has one.
-- A tap on a monitor with no bar has no button to point at, so it falls back
-- to the pointer rather than to a spot where nothing is.
--
-- The menu is placed after the show rather than through show's own coords,
-- because its size is only settled once it has been laid out and the right
-- and bottom edges need that size to grow back towards the screen. Leaving it
-- to awful.menu's clamping would not do: that clamps to the workarea, which
-- does not account for the padding this config reserves for the bar.
_G.main_menu_toggle_at = function(inner, along, edge, output)
    local menu = M.mainmenu
    if menu.wibox.visible then
        menu:hide()
        return
    end

    local s = awful.screen.focused()
    local here = s ~= nil and output == ""
    if s and output ~= "" then
        for name in pairs(s.outputs) do
            if name == output then here = true end
        end
    end
    if not here then
        menu:show({ coords = mouse.coords() })
        return
    end

    local g = s.geometry
    menu:show({ coords = { x = g.x, y = g.y } })

    local w, h = menu.wibox.width, menu.wibox.height
    local x, y
    if edge == "left" then
        x, y = inner, along
    elseif edge == "right" then
        x, y = inner - w, along
    elseif edge == "top" then
        x, y = along, inner
    else
        x, y = along, inner - h
    end

    -- Keep it on the monitor: a button near the far end of a long bar would
    -- otherwise hang the menu over the edge.
    if edge == "left" or edge == "right" then
        y = math.max(0, math.min(y, g.height - h))
    else
        x = math.max(0, math.min(x, g.width - w))
    end

    menu.wibox.x = g.x + x
    menu.wibox.y = g.y + y
end

-- Root (desktop) mouse buttons — right-click menu; scroll to switch tags.
-- Scroll down (button 5) = next tag, matching the bar taglist direction.
M.rootbuttons = gears.table.join(
    awful.button({ }, 3, function() M.mainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewprev),
    awful.button({ }, 5, awful.tag.viewnext)
)

M.build()
M.write_registry()

return M
