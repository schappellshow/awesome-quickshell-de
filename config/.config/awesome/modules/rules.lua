local awful     = require("awful")
local beautiful = require("beautiful")
local wibox     = require("wibox")
local gears     = require("gears")
local dpi       = require("beautiful.xresources").apply_dpi

local keys = require("modules.keys")

awful.rules.rules = {

    -- Default: all clients
    {
        rule = { },
        properties = {
            border_width      = beautiful.border_width,
            border_color      = beautiful.border_normal,
            focus             = awful.client.focus.filter,
            raise             = true,
            keys              = keys.clientkeys,
            buttons           = keys.clientbuttons,
            -- Spawn on the focused CLIENT's screen (keyboard-centric), not
            -- the mouse's — with sloppy focus the mouse can idle on another
            -- monitor while you work, and new windows followed it there.
            -- During awesome (re)start every client is re-managed: keep its
            -- existing screen then, or restarts scatter all windows onto
            -- whichever screen happened to be "focused".
            screen            = function(c)
                -- Quickshell surfaces (notification popups + center, OSD,
                -- ...) advertise _NET_WM_WINDOW_TYPE_NORMAL alongside DOCK,
                -- so awesome manages them as clients. They position
                -- themselves on a specific output (e.g. the bar screen), so
                -- keep them there instead of yanking them to the focused
                -- screen — that was landing notifications on the wrong
                -- monitor, floated mid-screen.
                if awesome.startup or c.name == "quickshell" then
                    return c.screen
                end
                return awful.screen.focused({ client = true })
            end,
            placement         = awful.placement.no_overlap + awful.placement.no_offscreen,
            titlebars_enabled = false,   -- no titlebars by default (Hyprland style)
        }
    },

    -- Floating clients
    {
        rule_any = {
            instance = { "DTA", "copyq", "pinentry" },
            class    = {
                "Arandr", "Blueman-manager", "Gpick", "Kruler",
                "MessageWin", "Sxiv", "Wpa_gui", "veromix",
                "xtightvncviewer", "Pavucontrol", "Nm-connection-editor",
                "pavucontrol-qt", "flameshot", "Proton Mail Bridge",
            },
            name  = { "Event Tester" },
            role  = { "AlarmWindow", "ConfigManager", "pop-up" },
        },
        properties = {
            floating  = true,
            placement = awful.placement.centered,
        }
    },

    -- Dialogs get titlebars (so they can be moved/closed)
    {
        rule_any  = { type = { "dialog" } },
        properties = {
            floating          = true,
            titlebars_enabled = true,
            placement         = awful.placement.centered,
        }
    },

    -- Ghostty: WM_CLASS is "com.mitchellh.ghostty" — verify with `xprop | grep WM_CLASS`
    {
        rule = { class = "com.mitchellh.ghostty" },
        properties = { titlebars_enabled = false }
    },

    -- Rofi: truly floating, no border, no titlebar
    {
        rule = { class = "Rofi" },
        properties = {
            floating          = true,
            border_width      = 0,
            titlebars_enabled = false,
        }
    },

    -- Conky (own_window_type=normal in the theme): a summon-on-demand
    -- dashboard, not a desktop widget — float where the SYS pill places it
    -- (hugging the bar), no border, on every tag, ABOVE other windows so
    -- the keybind shows it over whatever you're doing, never focused.
    -- ontop/below here override the conkyrc's 'below' window hint.
    {
        -- conky reports lowercase "conky"; match either casing
        rule_any = { class = { "Conky", "conky" } },
        properties = {
            floating          = true,
            border_width      = 0,
            titlebars_enabled = false,
            sticky            = true,
            ontop             = true,
            below             = false,
            focusable         = false,
            skip_taskbar      = true,
            -- Keep the position conky was launched with (-x/-y from the
            -- SYS pill); overrides the default rule's no_overlap placement
            placement         = false,
            -- Always on the bar's screen, even when another monitor has
            -- focus (the default rule would assign the focused screen and
            -- drag the window away from its bar-side position)
            screen            = function()
                return require("modules.quickshell").bar_screen()
            end,
        }
    },

    -- Quickshell's normal windows (settings app) float centered. type=normal
    -- keeps this off the bar, which is a dock window ("quickshell" is a Lua
    -- pattern, so it also matches an "org.quickshell" class).
    {
        rule = { class = "quickshell", type = "normal" },
        properties = {
            floating          = true,
            placement         = awful.placement.centered,
            titlebars_enabled = false,
        }
    },

    -- Fallback for the same window when it maps with class=nil (WM_CLASS
    -- not set yet — same quirk as the bar's class-nil rule below): match
    -- on its title instead, or it falls through to the default rule and
    -- tiles at nearly full-screen instead of floating at 840x560.
    {
        rule = { name = "Shell Settings" },
        properties = {
            floating          = true,
            placement         = awful.placement.centered,
            titlebars_enabled = false,
            width             = 840,
            height            = 560,
        }
    },

    -- Quickshell shell surfaces (bar, popups) sometimes map before their
    -- WM_CLASS/dock type is set, so awesome manages them as ordinary
    -- clients: bordered, focusable on hover — the "outline around the
    -- bar". They keep the name "quickshell"; strip all management effects.
    {
        rule = { name = "^quickshell$" },
        properties = {
            floating          = true,
            border_width      = 0,
            focusable         = false,
            titlebars_enabled = false,
            skip_taskbar      = true,
            placement         = false,
        }
    },

}

-- Titlebar builder — only fires when titlebars_enabled = true (dialogs)
client.connect_signal("request::titlebars", function(c)
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", { raise = true })
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", { raise = true })
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c, { size = dpi(28) }):setup {
        layout = wibox.layout.align.horizontal,
        {   -- Left: icon
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal,
        },
        {   -- Center: title
            { align = "center", widget = awful.titlebar.widget.titlewidget(c) },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal,
        },
        {   -- Right: buttons
            awful.titlebar.widget.floatingbutton(c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.closebutton(c),
            layout = wibox.layout.fixed.horizontal(),
        },
    }
end)
