-- Quick-actions ring: the awesome half.
--
-- The ring itself (ring/Ring.qml) is a quickshell surface. Awesome owns what
-- quickshell cannot see or do under X11:
--
--   * the pointer position and the client under it when Super+middle is
--     pressed (quickshell only knows its own windows),
--   * the button RELEASE, which is what makes press-and-hold work: while the
--     button is down X delivers every event to whoever received the press —
--     awesome — so the ring window never sees the pointer move or let go,
--   * the keyboard (the ring is override-redirect and cannot take focus, so
--     a keygrabber forwards Escape / digits / arrows over IPC, the same way
--     the power menu does),
--   * every action that touches a client: those are named by X window id and
--     run here, so they act on the window the ring was opened over, never on
--     whatever happens to have focus when an entry is clicked.
--
-- Protocol, all through `qs ipc call ring ...` (coordinates are global):
--   open <x> <y> <win>        show the ring; <win> is the X id of the client
--                             under the pointer, or 0 for the bare desktop
--   hover <x> <y>             pointer moved while the button is held
--   release <x> <y> <held>    button let go; held is true past HOLD seconds
--   key <name>                Escape, 1-9, Left, Right, Return
-- and back from quickshell:
--   ring_grab() / ring_release()          keyboard grab on / off
--   ring_window_action(name, win)         float, close, maximize, ...

local awful = require("awful")
local gears = require("gears")

local M = {}

-- Held longer than this and a release counts as a pick (release over an
-- action runs it, anywhere else cancels). Shorter is a click: the ring stays
-- up so you can click an action.
local HOLD = 0.25
-- Pointer must have travelled this far before hover updates are sent, so a
-- twitch while clicking does not spawn a process.
local WOBBLE = 8
local TICK = 0.06

local function ipc(...)
    local cmd = { "qs", "ipc", "call", "ring", ... }
    for i, v in ipairs(cmd) do cmd[i] = tostring(v) end
    awful.spawn(cmd, false)
end

-- ── Keyboard grab ────────────────────────────────────────────────────────
local grabber = nil

local function release_keys()
    if grabber then
        awful.keygrabber.stop(grabber)
        grabber = nil
    end
end

local FORWARD = {
    Escape = true, Left = true, Right = true, Up = true, Down = true,
    Return = true, KP_Enter = true,
}

-- Taken by the shell once it has actually opened the ring (so a disabled ring
-- never grabs anything) and dropped whenever it closes, however it closes.
_G.ring_grab = function()
    release_keys()
    grabber = awful.keygrabber.run(function(_, key, event)
        if event ~= "press" then return end
        if key == "Escape" then release_keys() end
        if FORWARD[key] or key:match("^%d$") then
            ipc("key", key)
        end
    end)
end
_G.ring_release = release_keys

-- ── Client actions ───────────────────────────────────────────────────────
local function client_by_window(win)
    win = tonumber(win)
    if not win or win == 0 then return nil end
    for _, c in ipairs(client.get()) do
        if c.window == win then return c end
    end
    return nil
end

local actions = {
    close    = function(c) c:kill() end,
    float    = function(c) awful.client.floating.toggle(c); c:raise() end,
    maximize = function(c) c.maximized = not c.maximized; c:raise() end,
    fullscreen = function(c) c.fullscreen = not c.fullscreen; c:raise() end,
    minimize = function(c) c.minimized = true end,
    ontop    = function(c) c.ontop = not c.ontop end,
}

_G.ring_window_action = function(name, win)
    local c = client_by_window(win)
    local fn = actions[name]
    if c and c.valid and fn then
        fn(c)
        return true
    end
    return false
end

-- ── Opening ──────────────────────────────────────────────────────────────
-- The client whose window is under the pointer. Desktop, dock and splash
-- windows are not something Close should be offered on.
local SKIP_TYPES = { desktop = true, dock = true, splash = true }

local function under_pointer(c)
    if not c then
        local ok, cc = pcall(function() return mouse.current_client end)
        c = ok and cc or nil
    end
    if c and c.valid and not SKIP_TYPES[c.type] then
        return c
    end
    return nil
end

function M.open(c)
    local co = mouse.coords()
    c = under_pointer(c)
    ipc("open", co.x, co.y, c and c.window or 0)
    return co
end

-- ── Super+middle: press, hold, release ───────────────────────────────────
-- Why a mousegrabber and not the button's own release callback: awesome only
-- fires a release for a button whose modifiers still match, and the release
-- callback was never seen to fire in testing. A mousegrabber owns the pointer
-- from the press on, reports every button change whatever the keyboard is
-- doing (Super may come up before the button), and gives the live position.
local press = nil   -- { x, y, held, timer, poll, lx, ly }

local function stop_press(in_grabber)
    local p = press
    if not p then return end
    press = nil
    if p.timer then p.timer:stop() end
    if p.poll then p.poll:stop() end
    if p.grabbing and not in_grabber then
        pcall(mousegrabber.stop)
    end
end

local function finish(in_grabber)
    local p = press
    if not p then return end
    local co = mouse.coords()
    stop_press(in_grabber)
    ipc("release", co.x, co.y, p.held and "true" or "false")
end

function M.press(c)
    stop_press()
    local co = M.open(c)
    local p = { x = co.x, y = co.y, held = false, lx = co.x, ly = co.y }
    p.timer = gears.timer.start_new(HOLD, function()
        if press == p then p.held = true end
        return false
    end)
    p.poll = gears.timer.start_new(TICK, function()
        if press ~= p then return false end
        local now = mouse.coords()
        if (now.x ~= p.lx or now.y ~= p.ly)
            and math.abs(now.x - p.x) + math.abs(now.y - p.y) > WOBBLE then
            p.lx, p.ly = now.x, now.y
            ipc("hover", now.x, now.y)
        end
        return true
    end)
    press = p
    -- Already let go (a very quick click): nothing to track.
    if not (co.buttons and co.buttons[2]) then
        finish(false)
        return
    end
    p.grabbing = pcall(mousegrabber.run, function(m)
        if press ~= p then return false end
        if not m.buttons[2] then
            finish(true)
            return false
        end
        return true
    end, "left_ptr")
end

-- The button's own release callback, kept as a fallback for when the
-- mousegrabber could not start (another grab was running).
function M.release()
    finish(false)
end

-- Open from the keyboard: there is no button to hold, so it is click mode.
function M.open_kbd()
    stop_press()
    M.open(nil)
end

return M
