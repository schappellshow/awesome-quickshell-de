-- Bridge to quickshell: serialize per-screen tag/layout state to a JSON file
-- ($XDG_RUNTIME_DIR/awesomewm-state.json) that quickshell watches. Commands
-- come back the other way via `awesome-client` (see AwesomeState.qml).

local awful = require("awful")
local gears = require("gears")

local M = {}

local state_path = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/awesomewm-state.json"

local function esc(s)
    local out = tostring(s):gsub('[\\"]', "\\%0"):gsub("\n", "\\n")
    return out
end

-- Minimized clients are invisible everywhere else: the tiling layout drops
-- them, so without this they can only be found through the rofi switcher.
-- The per-tag count drives the taglist's "something is hidden here" pip;
-- the per-screen list drives the bar's hidden-windows section.
local function minimized_on(t)
    local out = {}
    for _, c in ipairs(t:clients()) do
        if c.minimized then
            out[#out + 1] = c
        end
    end
    return out
end

-- Minimized clients on the tag(s) this screen is currently viewing. Keyed
-- by X window id, which is stable and is what the restore command matches
-- on. Deduped because a client can carry several of the selected tags.
local function hidden_json(s)
    local seen, out = {}, {}
    for _, t in ipairs(s.selected_tags or {}) do
        for _, c in ipairs(minimized_on(t)) do
            if not seen[c.window] then
                seen[c.window] = true
                -- Both halves of WM_CLASS: they differ in case and content
                -- ("Helium"/"helium"), and either may be the one that
                -- matches a desktop entry. Either can also be nil.
                out[#out + 1] = string.format(
                    '{"id":%d,"class":"%s","instance":"%s","name":"%s"}',
                    c.window, esc(c.class or ""), esc(c.instance or ""),
                    esc(c.name or "")
                )
            end
        end
    end
    return table.concat(out, ",")
end

-- Constant for the life of this awesome process, so quickshell can tell a
-- restart from an ordinary state update. Layout settings are applied by
-- quickshell (common/WindowMode.qml), and awesome resets every tag to
-- rc.lua's defaults when it restarts — without this there is no signal that
-- the settings need re-imposing.
local epoch = string.format("%d-%d", os.time(), math.random(1, 1000000))

-- Every client currently ON SCREEN, across all monitors, in the order you
-- would read them: left to right.
--
-- Ordering is by ABSOLUTE geometry, which is the whole trick. awesome's
-- screen indices are not spatial (here screen 3 is the left-most monitor),
-- but client x/y are in global coordinates, so one sort by (x, y) orders
-- both across monitors and within a tiled screen. No per-screen pass, and a
-- window moved anywhere lands in the right place by construction.
--
-- Deliberately flat rather than per-screen: the bar shows one list for the
-- whole desktop, and it lives on a single monitor.
local function clients_json()
    local vis = {}
    for _, c in ipairs(client.get()) do
        -- type ~= "normal" drops the bar itself, which awesome manages as a
        -- "dock" client and would otherwise appear as a class-less icon.
        -- isvisible() is already tag-aware; the minimized test is belt and
        -- braces, since the hidden section owns those.
        if c.type == "normal" and not c.minimized and c:isvisible() then
            vis[#vis + 1] = c
        end
    end

    table.sort(vis, function(a, b)
        local ga, gb = a:geometry(), b:geometry()
        if ga.x ~= gb.x then return ga.x < gb.x end
        if ga.y ~= gb.y then return ga.y < gb.y end
        return a.window < b.window
    end)

    local out = {}
    for _, c in ipairs(vis) do
        out[#out + 1] = string.format(
            '{"id":%d,"class":"%s","instance":"%s","name":"%s","focused":%s}',
            c.window, esc(c.class or ""), esc(c.instance or ""),
            esc(c.name or ""), tostring(c == client.focus)
        )
    end
    return table.concat(out, ",")
end

local function collect()
    local screens = {}
    for s in screen do
        local outputs = {}
        for name in pairs(s.outputs) do
            outputs[#outputs + 1] = '"' .. esc(name) .. '"'
        end

        local tags = {}
        for i, t in ipairs(s.tags) do
            tags[#tags + 1] = string.format(
                '{"index":%d,"name":"%s","selected":%s,"occupied":%s,"urgent":%s,"minimized":%d}',
                i, esc(t.name),
                tostring(t.selected),
                tostring(#t:clients() > 0),
                tostring(t.urgent or false),
                #minimized_on(t)
            )
        end

        screens[#screens + 1] = string.format(
            '{"index":%d,"outputs":[%s],"layout":"%s","tags":[%s],"hidden":[%s]}',
            s.index,
            table.concat(outputs, ","),
            esc(awful.layout.getname(awful.layout.get(s))),
            table.concat(tags, ","),
            hidden_json(s)
        )
    end
    return '{"screens":[' .. table.concat(screens, ",")
        .. '],"clients":[' .. clients_json()
        .. '],"epoch":"' .. epoch .. '"}'
end

local function write_state()
    local f = io.open(state_path, "w")
    if not f then return end
    f:write(collect())
    f:close()
end

-- Coalesce signal bursts (e.g. a client moving between tags) into one write
local timer = gears.timer {
    timeout     = 0.05,
    single_shot = true,
    callback    = write_state,
}
local function schedule()
    if timer.started then timer:stop() end
    timer:start()
end

-- Reserve space for the quickshell bar. X11 struts can't express "left
-- edge of a middle monitor", so the bar sets no strut (ExclusionMode.
-- Ignore) and we pad the screen(s) it lives on instead. Reads barWidth/
-- barScreen/barPosition from quickshell's settings.json; quickshell
-- re-invokes this via awesome-client when those settings change
-- (common/BarSpace.qml).
local function read_qs_settings()
    local content = ""
    local f = io.popen("cat " .. os.getenv("HOME")
        .. "/.local/state/quickshell/by-shell/*/settings.json 2>/dev/null")
    if f then
        content = f:read("*a") or ""
        f:close()
    end
    return content
end

-- The screen quickshell draws its bar on (falls back to primary) — used
-- by the Conky rule so the dashboard always pops up beside the bar, no
-- matter which monitor has focus.
function M.bar_screen()
    local target = read_qs_settings():match('"barScreen"%s*:%s*"([^"]*)"') or ""
    if target ~= "" then
        for s in screen do
            for name in pairs(s.outputs) do
                if name == target then return s end
            end
        end
    end
    return screen.primary
end

local BAR_EDGES = { left = true, right = true, top = true, bottom = true }

function M.apply_bar_padding()
    local content = read_qs_settings()
    local width  = tonumber(content:match('"barWidth"%s*:%s*(%d+)')) or 36
    local target = content:match('"barScreen"%s*:%s*"([^"]*)"') or ""
    local edge   = content:match('"barPosition"%s*:%s*"([^"]*)"') or "left"
    if not BAR_EDGES[edge] then edge = "left" end

    -- Unplugged/unknown output → quickshell falls back to bars on every
    -- screen; mirror that here
    local found = false
    for s in screen do
        for name in pairs(s.outputs) do
            if name == target then found = true end
        end
    end
    if not found then target = "" end

    for s in screen do
        local has_bar = (target == "")
        for name in pairs(s.outputs) do
            if name == target then has_bar = true end
        end
        -- Write every side, so a bar that moved doesn't leave the padding
        -- it reserved on its old edge behind
        local pad = { left = 0, right = 0, top = 0, bottom = 0 }
        if has_bar then pad[edge] = width + 3 end
        s.padding = pad
    end
end

function M.setup()
    tag.connect_signal("property::selected",  schedule)
    tag.connect_signal("property::urgent",    schedule)
    tag.connect_signal("property::layout",    schedule)
    tag.connect_signal("property::activated", schedule)
    client.connect_signal("tagged",           schedule)
    client.connect_signal("untagged",         schedule)
    client.connect_signal("property::urgent", schedule)
    -- Minimizing changes neither tags nor occupancy, so without this the
    -- hidden-window state would never reach the bar. manage/unmanage keep
    -- the list correct when a minimized client is closed outright.
    client.connect_signal("property::minimized", schedule)
    client.connect_signal("manage",              schedule)
    client.connect_signal("unmanage",            schedule)
    -- The window list is ordered by geometry and marks the focused entry, so
    -- it has to follow both. Retiling fires a burst of geometry changes; the
    -- 0.05s coalescing timer above collapses them into one write.
    client.connect_signal("property::geometry",  schedule)
    client.connect_signal("focus",               schedule)
    client.connect_signal("unfocus",             schedule)
    screen.connect_signal("list",             schedule)
    screen.connect_signal("list",             M.apply_bar_padding)
    M.apply_bar_padding()
    write_state()
end

-- Window borders, driven by Settings -> Appearance / Windows. The colours are
-- not stored separately: quickshell sends Theme.surface and Theme.accentBright,
-- which is exactly what theme.lua's border_normal/border_focus already were,
-- so any colour scheme themes the borders without carrying extra keys.
--
-- Which clients get a border is NOT re-derived here. rules.lua deliberately
-- leaves the bar, rofi, conky, spectacle and zoom's toolbar unbordered, and
-- duplicating that list would rot the moment a rule changed -- so ask the
-- rules themselves. A client matched by any rule setting border_width = 0 is
-- left alone, which also means a width of 0 doesn't erase the distinction.
function M.set_border(normal, focus, width, radius)
    local beautiful = require("beautiful")
    local theme = beautiful.get()

    theme.border_normal = normal
    theme.border_focus  = focus
    theme.border_width  = width
    theme.border_radius = radius

    local focused = client.focus
    for _, c in ipairs(client.get()) do
        local exempt = false
        for _, r in ipairs(awful.rules.matching_rules(c, awful.rules.rules)) do
            if r.properties and r.properties.border_width == 0 then
                exempt = true
            end
        end
        if not exempt then
            c.border_width = width
            c.border_color = (c == focused) and focus or normal
            -- Reassigning the closure is what re-shapes an existing client;
            -- the radius is read when the shape is drawn, not when it is set.
            c.shape = function(cr, w, h)
                gears.shape.rounded_rect(cr, w, h, radius)
            end
        end
    end
end

return M
