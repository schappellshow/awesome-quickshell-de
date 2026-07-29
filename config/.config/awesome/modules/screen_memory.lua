-- Remember which output + tag each window lived on, and put it back when a
-- monitor returns.
--
-- When a screen disappears awesome has to evacuate its clients to a
-- surviving screen, and nothing brings them home again: unplug/replug (or a
-- monitor waking from DPMS) leaves windows piled on the wrong output, often
-- on the wrong tag index too. This records a client's home as an OUTPUT NAME
-- (stable across screen objects being destroyed/recreated) plus a tag name,
-- and restores it when that output comes back.

local awful = require("awful")
local gears = require("gears")

local M = {}

-- client -> { output = "DisplayPort-1", tag = "2" }
local home = setmetatable({}, { __mode = "k" })   -- weak keys: no leaks

-- Bookkeeping must FREEZE while the screen set is changing. Awesome emits
-- property::screen/tagged for every client it evacuates off a vanishing
-- screen; recording those would overwrite each window's real home with the
-- temporary dumping ground (and then "restore" would put them back wrong).
local frozen = false

local function output_of(s)
    if not s or not s.valid then return nil end
    -- A screen can report several outputs (mirroring); the sorted-first name
    -- is a stable, deterministic key.
    local names = {}
    for name in pairs(s.outputs) do names[#names + 1] = name end
    table.sort(names)
    return names[1]
end

local function screen_for_output(name)
    for s in screen do
        for n in pairs(s.outputs) do
            if n == name then return s end
        end
    end
    return nil
end

-- Record where a client currently lives (no-op while frozen).
--
-- Screen removal is only announced AFTER awesome has already evacuated and
-- re-tagged the clients, so a flag set in screen::removed arrives too late —
-- the corrupted tag is recorded first. Instead of trusting a flag alone,
-- refuse to record a home whose screen count doesn't match what we last saw
-- in a settled state: any change in the number of screens means we're inside
-- a hotplug transition and nothing observed there is trustworthy.
local settled_screen_count = 0

local function screen_count()
    local n = 0
    for _ in screen do n = n + 1 end
    return n
end

local function remember(c)
    if frozen or not c.valid then return end
    if screen_count() ~= settled_screen_count then return end
    local out = output_of(c.screen)
    if not out then return end
    local t = c.first_tag
    home[c] = { output = out, tag = t and t.name or nil }
end

-- Inspect the recorded homes (handy from awesome-client when debugging):
--   awesome-client 'return require("modules.screen_memory").dump()'
function M.dump()
    local out = {}
    for _, c in ipairs(client.get()) do
        local h = home[c]
        out[#out + 1] = tostring(c.class) .. "=" ..
            (h and (h.output .. ":" .. tostring(h.tag)) or "none")
    end
    return table.concat(out, "  ") .. "  [frozen=" .. tostring(frozen) .. "]"
end

function M.restore()
    -- Collect the moves first, then apply the tag in a second pass:
    -- move_to_screen() re-tags the client onto the target screen's selected
    -- tag, and it doesn't settle synchronously — setting the tag in the same
    -- breath gets clobbered and the window lands on the wrong tag.
    local pending = {}
    for _, c in ipairs(client.get()) do
        local h = home[c]
        if h and c.valid then
            local target = screen_for_output(h.output)
            -- Only move it if it's actually somewhere else now
            if target and target.valid and output_of(c.screen) ~= h.output then
                c:move_to_screen(target)
                if h.tag then
                    pending[#pending + 1] = { c = c, screen = target, tag = h.tag }
                end
            end
        end
    end

    if #pending == 0 then return end
    -- Keep a module-level reference: a timer held only by a local can be
    -- collected before it fires, which silently skipped the tag pass.
    M._tag_timer = gears.timer {
        timeout     = 0.5,
        single_shot = true,
        autostart   = true,
        callback    = function()
            for _, p in ipairs(pending) do
                if p.c.valid and p.screen.valid then
                    for _, t in ipairs(p.screen.tags) do
                        if t.name == p.tag then
                            p.c:move_to_tag(t)
                            break
                        end
                    end
                end
            end
        end,
    }
end

function M.setup()
    -- The screen count we consider "settled"; remember() refuses to record
    -- while the live count differs (i.e. mid-hotplug).
    settled_screen_count = screen_count()

    -- Track the home position as windows appear and are moved by hand
    client.connect_signal("manage", remember)
    client.connect_signal("tagged", remember)
    client.connect_signal("property::screen", remember)

    -- Freeze as soon as a screen goes away, so the evacuation that follows
    -- doesn't rewrite everyone's remembered home.
    screen.connect_signal("removed", function()
        frozen = true
    end)

    -- A returning monitor arrives as screen::added; awesome needs a moment
    -- to finish building its tags before clients can be placed on them.
    -- Timers are held on M so they can't be garbage-collected before firing.
    screen.connect_signal("added", function()
        M._restore_timer = gears.timer {
            timeout     = 1.5,
            single_shot = true,
            autostart   = true,
            callback    = function() M.restore() end,
        }
        -- Unfreeze well after restore()'s own deferred tag pass, or
        -- resuming bookkeeping would record the interim wrong tag. Adopt
        -- the new screen count as settled at the same moment.
        M._unfreeze_timer = gears.timer {
            timeout     = 4,
            single_shot = true,
            autostart   = true,
            callback    = function()
                settled_screen_count = screen_count()
                frozen = false
            end,
        }
    end)

    -- Safety net: if no screen ever comes back (monitor unplugged for good),
    -- adopt the reduced screen count so bookkeeping resumes rather than
    -- staying wedged forever.
    screen.connect_signal("removed", function()
        M._thaw_timer = gears.timer {
            timeout     = 15,
            single_shot = true,
            autostart   = true,
            callback    = function()
                settled_screen_count = screen_count()
                frozen = false
            end,
        }
    end)
end

return M
