local xresources   = require("beautiful.xresources")
local dpi          = xresources.apply_dpi
local gfs          = require("gears.filesystem")
local gears        = require("gears")

local theme = {}

-- OpenMandriva color palette (from ghostty config)
local om = {
    base        = "#232627",   -- background / terminal color 0
    surface     = "#444444",   -- selection-background
    text        = "#ffffff",   -- foreground
    subtext     = "#afb3bd",   -- color 7
    muted       = "#767676",   -- color 8
    near_white  = "#ecf2ff",   -- color 15

    red         = "#cc2263",   -- color 1
    green       = "#40da76",   -- color 2
    orange      = "#da7340",   -- color 3
    blue        = "#2080bb",   -- color 4  (primary OM accent)
    purple      = "#a740da",   -- color 5
    teal        = "#61c583",   -- color 6
    bright_red  = "#e2266e",   -- color 9
    bright_grn  = "#4bff8a",   -- color 10
    gold        = "#dac040",   -- color 11
    bright_blue = "#40a5da",   -- color 12 (secondary OM accent, used for borders/focus)
    bright_pur  = "#c14afd",   -- color 13
    bright_teal = "#72e69a",   -- color 14

    cursor      = "#d0d0d0",
    sel_fg      = "#cecece",
}

-- Fonts
theme.font                         = "Hack 10"
theme.taglist_font                 = "Hack Bold 9"
theme.hotkeys_font                 = "Hack 10"
theme.hotkeys_description_font     = "Hack 9"

-- NOTE: the bar/taglist/notifications now live in quickshell
-- (~/.config/quickshell); this theme only covers what awesome still draws:
-- borders, gaps, titlebars, menu, hotkeys popup, and internal naughty errors.

-- Window borders (the "outline around the bar" was awesome managing the
-- bar window itself and bordering it — see the quickshell rule in
-- rules.lua, not these colors)
theme.border_width  = dpi(2)
theme.border_normal = om.surface
theme.border_focus  = om.bright_blue
theme.border_radius = dpi(10)   -- custom property read in rc.lua manage signal

-- Gaps between tiled windows
theme.useless_gap = dpi(3)

-- Global bg/fg
theme.bg_normal   = om.base
theme.bg_focus    = om.surface
theme.bg_urgent   = om.red
theme.bg_minimize = om.muted

theme.fg_normal   = om.subtext
theme.fg_focus    = om.text
theme.fg_urgent   = om.text
theme.fg_minimize = om.muted

-- Notifications (naughty — internal awesome errors only; regular
-- notifications are handled by quickshell)
theme.notification_font         = "Hack 10"
theme.notification_bg           = om.surface
theme.notification_fg           = om.text
theme.notification_border_color = om.bright_blue
theme.notification_border_width = dpi(2)
theme.notification_shape        = function(cr, w, h)
    gears.shape.rounded_rect(cr, w, h, dpi(10))
end
theme.notification_opacity   = 0.95
theme.notification_margin    = dpi(12)
theme.notification_width     = dpi(360)
theme.notification_max_height = dpi(120)

-- Menu
theme.menu_bg_normal    = om.surface
theme.menu_fg_normal    = om.text
theme.menu_bg_focus     = om.blue
theme.menu_fg_focus     = om.text
theme.menu_border_color = om.muted
theme.menu_border_width = dpi(1)
theme.menu_height       = dpi(24)
theme.menu_width        = dpi(180)

-- Titlebars (only shown on dialogs)
theme.titlebar_bg_normal = om.base
theme.titlebar_bg_focus  = om.surface
theme.titlebar_fg_normal = om.muted
theme.titlebar_fg_focus  = om.subtext

local themes_path = gfs.get_themes_dir()
theme.titlebar_close_button_normal               = themes_path.."default/titlebar/close_normal.png"
theme.titlebar_close_button_focus                = themes_path.."default/titlebar/close_focus.png"
theme.titlebar_minimize_button_normal            = themes_path.."default/titlebar/minimize_normal.png"
theme.titlebar_minimize_button_focus             = themes_path.."default/titlebar/minimize_focus.png"
theme.titlebar_maximized_button_normal_inactive  = themes_path.."default/titlebar/maximized_normal_inactive.png"
theme.titlebar_maximized_button_focus_inactive   = themes_path.."default/titlebar/maximized_focus_inactive.png"
theme.titlebar_maximized_button_normal_active    = themes_path.."default/titlebar/maximized_normal_active.png"
theme.titlebar_maximized_button_focus_active     = themes_path.."default/titlebar/maximized_focus_active.png"

-- feh sets the wallpaper in autostart.lua
theme.wallpaper = nil

-- Hotkeys popup
theme.hotkeys_bg           = om.base
theme.hotkeys_fg           = om.text
theme.hotkeys_border_color = om.bright_blue
theme.hotkeys_border_width = dpi(2)
theme.hotkeys_shape        = function(cr, w, h)
    gears.shape.rounded_rect(cr, w, h, dpi(12))
end
theme.hotkeys_modifiers_fg = om.bright_blue
theme.hotkeys_label_bg     = om.surface
theme.hotkeys_label_fg     = om.text

return theme
