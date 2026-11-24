-- Opt-in background blur for quickshell surfaces.
--
-- picom blurs behind a window only if a rule in picom/fx-normal.conf says so,
-- and the rule for docks (every PanelWindow, the bar included) turns blur
-- off. A surface that wants it carries the X property _AQS_BLUR (a CARDINAL
-- level, 1-5, see the rules at the end of fx-normal.conf for what each level
-- means) and picom blurs behind it.
--
-- Quickshell cannot set an X property, and a PanelWindow exposes neither its
-- title nor its X window id, so the shell cannot say "this window". It says
-- "the window at this rectangle" instead (common/BlurHint.qml) and this module
-- finds the client with exactly that geometry. Requests are remembered, not
-- just applied, because the client does not exist yet when the surface is
-- first shown and its geometry settles a moment after it maps: every new
-- client and every geometry change is checked against the list again.
--
--   shell_blur(key, x, y, w, h, level)   ask for blur on that rectangle
--   shell_blur_clear(key)                withdraw the request
--
-- `key` identifies the requester (one per BlurHint), so a surface that moves
-- replaces its old rectangle instead of leaving a stale one behind.

local M = {}

awesome.register_xproperty("_AQS_BLUR", "number")

local wanted = {}   -- key -> { x, y, w, h, level }

local function level_for(c)
    if c.type ~= "dock" then return nil end
    local g = c:geometry()
    for _, r in pairs(wanted) do
        if g.x == r.x and g.y == r.y and g.width == r.w and g.height == r.h then
            return r.level
        end
    end
    return nil
end

local function refresh(c)
    if not c.valid then return end
    local want = level_for(c)
    if c:get_xproperty("_AQS_BLUR") ~= want then
        c:set_xproperty("_AQS_BLUR", want)
    end
end

local function refresh_all()
    for _, c in ipairs(client.get()) do refresh(c) end
end

client.connect_signal("manage", refresh)
client.connect_signal("property::geometry", refresh)
client.connect_signal("property::type", refresh)

_G.shell_blur = function(key, x, y, w, h, level)
    wanted[tostring(key)] = {
        x = math.floor(x), y = math.floor(y),
        w = math.floor(w), h = math.floor(h), level = level,
    }
    refresh_all()
end

_G.shell_blur_clear = function(key)
    wanted[tostring(key)] = nil
    refresh_all()
end

return M
