-- One-slot scratchpad: a floating window you summon over whatever tag you are
-- on and send away again with the same key.
--
-- How the slot is represented
-- ---------------------------
-- The scratchpad is an ordinary client that
--   * carries the X property _AWESOME_SCRATCHPAD (set on the window itself),
--   * is floating, and
--   * is PARKED by minimizing it.
-- There is no table of "the" scratchpad client to lose: the slot is whichever
-- client has the property, so closing the window empties the slot with no
-- bookkeeping, and nothing here needs unwinding on unmanage.
--
-- Why an X property and not a Lua field: awesome.restart() throws every Lua
-- object away, but the property lives on the window and the new awesome reads
-- it back as the client is re-managed. Parking by minimizing survives a
-- restart for the same reason (WM_STATE iconic is kept by the server side of
-- the window, hidden-by-tag state is not something we can rely on).
--
-- Why minimize rather than moving it to an empty tag: awesome would have to
-- invent a tag for it, and a client with no tags is re-tagged arbitrarily on
-- restart. The cost of minimizing is that the bar's "hidden windows" list and
-- the tag occupancy pips would show it; quickshell.lua filters it out of both
-- via M.is().

local awful = require("awful")

local M = {}

local PROP = "_AWESOME_SCRATCHPAD"
awesome.register_xproperty(PROP, "boolean")

-- Fraction of the work area the window takes when summoned.
local WIDTH, HEIGHT = 0.70, 0.60

function M.is(c)
    return c ~= nil and c.valid and c:get_xproperty(PROP) == true
end

-- The occupant of the slot, or nil.
function M.get()
    for _, c in ipairs(client.get()) do
        if M.is(c) then return c end
    end
    return nil
end

-- True while WE are changing minimized/tags, so the handler below that reacts
-- to somebody else un-minimizing the scratchpad does not recurse into us.
local busy = false

-- Centre on the focused screen's work area (which already excludes the
-- padding reserved for the bar), on the current tag, on top, focused.
function M.show(c)
    c = c or M.get()
    if not c or not c.valid then return end
    busy = true
    local s = awful.screen.focused()
    local t = s.selected_tag
    c.fullscreen, c.maximized = false, false
    c.floating = true
    if c.screen ~= s then c.screen = s end
    if t then c:tags({ t }) end
    c.minimized = false
    c.ontop = true
    local wa = s.workarea
    local w, h = math.floor(wa.width * WIDTH), math.floor(wa.height * HEIGHT)
    c:geometry({
        x = wa.x + math.floor((wa.width - w) / 2),
        y = wa.y + math.floor((wa.height - h) / 2),
        width = w, height = h,
    })
    c:raise()
    client.focus = c
    busy = false
end

function M.hide(c)
    c = c or M.get()
    if c and c.valid then
        busy = true
        c.minimized = true
        busy = false
    end
end

-- Shown on the screen+tag you are looking at right now?
local function visible_here(c)
    local s = awful.screen.focused()
    return not c.minimized and c.screen == s and c:isvisible()
end

-- Give the window back to the tag you are on as an ordinary tiled window.
function M.release(c)
    if not (c and c.valid) then return end
    busy = true
    c:set_xproperty(PROP, nil)
    local s = awful.screen.focused()
    if c.screen ~= s then c.screen = s end
    if s.selected_tag then c:tags({ s.selected_tag }) end
    c.ontop = false
    c.floating = false
    c.minimized = false
    busy = false
    c:emit_signal("request::activate", "scratchpad.release", { raise = true })
end

-- Put a window in the slot (returning any previous occupant to the current tag
-- first) and park it.
function M.adopt(c, park)
    local old = M.get()
    if old and old ~= c then M.release(old) end
    c:set_xproperty(PROP, true)
    c.floating = true
    if park ~= false then M.hide(c) end
end

-- ── spawning ─────────────────────────────────────────────────────────────
-- Terminals disagree about how a window gets a class or title (ghostty
-- --class, kitty --class, alacritty --class, xterm -class, foot --app-id...)
-- and some hand the request to an already-running server, so neither a
-- launch flag nor the child PID is reliable. Two independent ways to
-- recognise the new window; either one is enough:
--   1. awful.spawn's own startup-notification / PID matching (the callback);
--   2. failing that, the first new normal window that appears shortly after
--      the request and whose class mentions the terminal's binary name.
local pending_until = 0
local pending_bin   = nil
local FALLBACK_WINDOW = 8   -- seconds

local function adopt_new(c)
    pending_until = 0
    M.adopt(c, false)
    M.show(c)
end

local function spawn_terminal()
    local cmd = terminal
    pending_bin = (cmd:match("^%S+") or ""):match("[^/]+$"):lower()
    pending_until = os.time() + FALLBACK_WINDOW
    awful.spawn(cmd, { callback = adopt_new })
end

client.connect_signal("manage", function(c)
    if M.is(c) then
        -- Re-managed after awesome.restart(): rules have tiled it again.
        c.floating = true
        c.ontop = true
        return
    end
    if pending_until > os.time() and c.type == "normal" and pending_bin ~= "" then
        local hay = ((c.class or "") .. " " .. (c.instance or "")):lower()
        if hay:find(pending_bin, 1, true) then
            adopt_new(c)
        end
    end
end)

-- Somebody else un-minimized it (Super+Ctrl+N, the rofi switcher): treat that
-- as a summon so it comes to where you are instead of popping up on a tag you
-- are not looking at.
client.connect_signal("property::minimized", function(c)
    if not busy and M.is(c) and not c.minimized then
        M.show(c)
    end
end)

-- ── the two keys ─────────────────────────────────────────────────────────
function M.toggle()
    local c = M.get()
    if not c then
        spawn_terminal()
    elseif visible_here(c) then
        M.hide(c)
    else
        M.show(c)
    end
end

-- Focused window -> slot; the scratchpad window itself -> back to the tag.
function M.send()
    local c = client.focus
    if not c then return end
    if M.is(c) then
        M.release(c)
    else
        M.adopt(c)
    end
end

return M
