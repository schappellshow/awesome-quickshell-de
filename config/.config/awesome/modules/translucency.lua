-- Opacity of awesome's own menus (desktop right-click, start button).
--
-- Settings -> Transparency & blur stores the RESULTING opacity of the menu,
-- as a percent (settings.json: menuOpacity). awful.menu paints its
-- background color twice, on the menu window and again behind every entry,
-- so the alpha of one layer is not what you see: two layers of alpha a give
-- 1 - (1 - a)^2. This module turns the percent back into the per-layer alpha
-- the theme needs.
--
--   hex_for(percent)      "#rrggbbaa" for theme.menu_bg_normal
--   stored_percent()      what settings.json says (DEFAULT if unset)
--   apply(percent)        set the theme color now; the caller rebuilds the
--                         menu, which only reads the theme when it is created

local beautiful = require("beautiful")

local M = {}

-- 75% resulting = per-layer alpha 0x80, the look this shipped with.
M.DEFAULT = 75
M.MIN, M.MAX = 20, 100

local SURFACE = "#444444"   -- theme.lua's om.surface

local function clamp(p)
    p = tonumber(p) or M.DEFAULT
    return math.max(M.MIN, math.min(M.MAX, math.floor(p + 0.5)))
end

function M.hex_for(percent)
    local result = clamp(percent) / 100
    local alpha = 1 - math.sqrt(1 - result)
    return string.format("%s%02x", SURFACE, math.floor(alpha * 255 + 0.5))
end

function M.stored_percent()
    local f = io.popen("cat " .. os.getenv("HOME")
        .. "/.local/state/quickshell/by-shell/*/settings.json 2>/dev/null")
    local content = ""
    if f then
        content = f:read("*a") or ""
        f:close()
    end
    return clamp(content:match('"menuOpacity"%s*:%s*(%d+)') or M.DEFAULT)
end

function M.apply(percent)
    beautiful.get().menu_bg_normal = M.hex_for(percent)
end

return M
