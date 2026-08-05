# Dependencies

What each component provides, so you can decide what to fix if
`install.sh` reports it missing. Only **quickshell** is load-bearing;
everything else costs you one feature.

## Required

| Package | Provides | If missing |
|---|---|---|
| `quickshell` | Bar, notifications, settings app, power menu, OSD | **No shell at all.** Build from [quickshell.outfoxxed.me](https://quickshell.outfoxxed.me) |
| `awesome` | Window management, keybindings, tags | No session to log into |
| `stow` | Links the config into `$HOME` | Install manually, or symlink the trees yourself |

## Core experience

| Package | Provides | If missing |
|---|---|---|
| `picom` | Compositing: transparency, blur, rounded corners | Bar/panels look flat and opaque |
| `rofi` | App launcher, run dialog, window switcher, clipboard | `Super+Space` and friends do nothing |
| `greenclip` *(binary)* | Clipboard history daemon behind `Super+/` | Clipboard picker opens empty and never records |
| `rofimoji` *(pip)* | Emoji picker on `Super+.` | `Super+.` does nothing |
| `feh` | Sets the wallpaper | No wallpaper |
| `xsettingsd` | Pushes GTK theme/icon changes to running apps | Theme changes need an app restart |
| `qt6ct` + a Qt platform theme | Qt apps follow dark/light and find icons | Qt apps and tray menus render light |
| Breeze icons | Icon theme used by the power menu and Qt apps | Missing icons in menus |
| Hack (or any mono font) | Bar and UI text | Falls back to a default font |
| JetBrainsMono Nerd Font | Bar glyphs (lock, network, bluetooth icons) | Those pills show blank boxes |

## Session services

| Package | Provides | If missing |
|---|---|---|
| `lxqt-policykit` | Password prompts for privileged actions | Mounting disks / admin actions silently fail |
| `kwallet` + `kwallet-pam` | Secret Service — apps store credentials | Apps re-prompt for logins every start |
| `xss-lock` *(source build)* | Idle lock, `loginctl lock-session`, lock-before-suspend | Screen never locks automatically |
| `xsecurelock` *(source build)* | Lock screen with a password prompt | Falls back to `i3lock-color`, then plain `i3lock` |
| `i3lock-color` | Lock screen fallback | Only matters if xsecurelock is absent too |
| `betterlockscreen` *(script)* | Blurred-wallpaper lock screen | Falls back to xsecurelock's plain screen |
| `imagemagick` | Builds betterlockscreen's blur/dim cache | betterlockscreen can't generate a lock image |
| `gammastep` *(often source)* | Night light / colour temperature | `Super+Shift+N` does nothing |
| `udiskie` *(often pip)* | Automounts USB sticks and SD cards | Mount removable media by hand |
| `brightnessctl` | Backlight keys | Brightness keys do nothing (desktops have no backlight anyway) |
| `xdg-desktop-portal` + `-gtk` | File dialogs, dark-mode for Electron/Flatpak apps | Browser save dialogs look wrong or don't open |

## Optional

| Package | Provides | If missing |
|---|---|---|
| `spectacle` | `Print` screenshot with region select + annotation. Runs in GUI mode so the editor stays open holding the clipboard — on X11 the copied image dies with the process that owns the selection. Its region overlay needs the placement rule in `modules/rules.lua` to cover every monitor | Falls back to `scrot` |
| `playerctl` | Media keys | Media keys do nothing |
| `pavucontrol-qt` | Per-app volume mixer | Settings → Audio still handles defaults/volume |
| `blueman` | Bluetooth pairing wizard | Bar widget still connects known devices |
| `networkmanager-applet` | `nm-connection-editor` for VPN/802.1X | Bar widget still does Wi-Fi scan/connect |
| `thunar` (or any file manager) | `Super+E` | Auto-detects pcmanfm/nemo/nautilus/dolphin instead |
| `system-config-printer` | Printer GUI | CUPS web UI at `localhost:631` still works |
| `conky` | `Super+Shift+M` system monitor popout | Toggle reports conky isn't installed |

## Backends assumed present

Not installed by this project — they're part of any modern Linux system,
and the desktop talks to them rather than shipping its own:

- **systemd** — session target, user services
- **NetworkManager** — the network widget drives `nmcli`
- **BlueZ** — the bluetooth widget talks to it over D-Bus
- **PipeWire** (or PulseAudio) — audio widget and OSD
- **UDisks2** — automounting
- **CUPS** — printing
- **polkit** — privilege escalation

## If this machine has Plasma installed

`kglobalacceld` is D-Bus activated by any KDE app you launch — spectacle, a
KWallet prompt — and then claims every shortcut in
`~/.config/kglobalshortcutsrc`. `Meta+Space` is KRunner's default, so it
silently shadows `Super+Space`, and a config migrated from Plasma typically
holds dozens more `Meta+` bindings that collide with this desktop's.

`install.sh` handles this by adding a drop-in to `plasma-kglobalaccel` and
`plasma-krunner`:

```ini
[Unit]
ConditionEnvironment=!AWESOME_SESSION=1
```

awesome sets `AWESOME_SESSION=1` at startup and clears it on logout, so the
units are skipped here and start normally in a Plasma session. Masking them
would have broken every Plasma shortcut, not just search.

If awesome ever exits without running its exit handler (an X server crash,
say), the variable can survive — the user manager lingers. Symptom: no
global shortcuts in Plasma. Clear it with
`systemctl --user unset-environment AWESOME_SESSION`, or reboot.

## Notes on source builds

`xss-lock`, `xsecurelock` and sometimes `gammastep` aren't packaged on most
distributions, so `install.sh` builds them. That's why the build toolchain
(compiler, cmake, X11 headers) is in the package list. Skip with
`SKIP_BUILDS=1` if you'd rather install them yourself.
