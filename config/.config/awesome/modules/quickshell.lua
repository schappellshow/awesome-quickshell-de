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
                '{"index":%d,"name":"%s","selected":%s,"occupied":%s,"urgent":%s}',
                i, esc(t.name),
                tostring(t.selected),
                tostring(#t:clients() > 0),
                tostring(t.urgent or false)
            )
        end

        screens[#screens + 1] = string.format(
            '{"index":%d,"outputs":[%s],"layout":"%s","tags":[%s]}',
            s.index,
            table.concat(outputs, ","),
            esc(awful.layout.getname(awful.layout.get(s))),
            table.concat(tags, ",")
        )
    end
    return '{"screens":[' .. table.concat(screens, ",") .. "]}"
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
-- barScreen from quickshell's settings.json; quickshell re-invokes this
-- via awesome-client when those settings change (common/BarSpace.qml).
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

function M.apply_bar_padding()
    local content = read_qs_settings()
    local width  = tonumber(content:match('"barWidth"%s*:%s*(%d+)')) or 36
    local target = content:match('"barScreen"%s*:%s*"([^"]*)"') or ""

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
        s.padding = has_bar and { left = width + 3 } or { left = 0 }
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
    screen.connect_signal("list",             schedule)
    screen.connect_signal("list",             M.apply_bar_padding)
    M.apply_bar_padding()
    write_state()
end

return M
