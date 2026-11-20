-- Float or tile just the current tag (Super+Ctrl+F).
--
-- Flips the selected tag of the focused screen between the floating layout
-- and whatever layout it had before. The previous layout is remembered per
-- tag, in memory only. Windows keep their positions on the way in: the
-- floating layout never moves a client, so each one stays where the tiling
-- layout last put it, and only then becomes free to drag around.
--
-- How this meets the global window mode
-- -------------------------------------
-- quickshell's common/WindowMode.qml owns the DEFAULT layout. Whenever its
-- inputs change -- the setting, a monitor appearing or going, or awesome
-- restarting -- it writes that default onto EVERY tag of the affected
-- outputs, and it does not look at what a tag was doing. It never polices in
-- between, so a flip made here is not undone the moment you make it. Three
-- consequences, all deliberate:
--   * A per-tag float is temporary. The next apply (restart, hotplug, a
--     change in Settings -> Windows) puts that tag back on the global
--     layout, which for a tiling mode is exactly "the layout it had before".
--   * When that happens the remembered layout is stale, so any layout change
--     that does not come from this module drops it (the property::layout
--     hook below). A later press then restores the automatic layout rather
--     than a layout the tag no longer relates to.
--   * Under the global Floating mode every tag is floating and nothing is
--     remembered, so pressing this key on such a tag TILES it (automatic
--     layout for the monitor's orientation) instead of doing nothing.

local awful = require("awful")

local M = {}

local floating = awful.layout.suit.floating

-- tag -> the layout to go back to. Weak keys, so a removed tag is not kept.
local remembered = setmetatable({}, { __mode = "k" })

-- Set while we change the layout ourselves, so the hook below can tell our
-- own writes from somebody else's.
local ours = false

-- rc.lua's orientation heuristic, the same one WindowMode.automaticFor uses.
local function automatic(s)
    if s.geometry.height > s.geometry.width then
        return awful.layout.suit.tile.bottom
    end
    return awful.layout.layouts[1]
end

tag.connect_signal("property::layout", function(t)
    if not ours then
        remembered[t] = nil
    end
end)

function M.toggle(s)
    s = s or awful.screen.focused()
    local t = s and s.selected_tag
    if not t then return end

    ours = true
    if t.layout == floating then
        local back = remembered[t]
        if not back or back == floating then
            back = automatic(s)
        end
        t.layout = back
        remembered[t] = nil
    else
        remembered[t] = t.layout
        t.layout = floating
    end
    ours = false
end

return M
