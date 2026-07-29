# Quickshell desktop shell (AwesomeWM + X11)

Quickshell provides the shell layer — bar, notifications, night light,
settings app, power menu, volume/brightness OSD — while AwesomeWM keeps
window management: tags, tiling, keybinds, rules.

## Layout

```
shell.qml                  root: bars per screen, notifications, settings, IPC
common/
  Theme.qml                OM palette; dark/light variants (dark default)
  Settings.qml             persistent settings (JSON in quickshell's state dir)
  AwesomeState.qml         watches awesome's state file; sends awesome-client cmds
  NightLight.qml           gammastep one-shot control
  Audio.qml                default-sink volume/mute via PipeWire
  Brightness.qml           backlight via brightnessctl (no-op without one)
  Network.qml              nmcli polling: status, wifi radio, saved connections
  PowerEvents.qml          low-battery notify at 15%, suspend at 5%
bar/                       vertical left bar (taglist / clock / tray / widgets)
  NetworkWidget/Panel      NET pill + popup (wifi toggle, connections, editor)
  BluetoothWidget/Panel    BT pill + popup (adapter toggle, paired devices)
  VolumeWidget             VOL pill (scroll/mute/right-click mixer)
  CalendarPopup            month grid on clock click
notifications/             org.freedesktop.Notifications daemon + popups
  NotificationCenter.qml   history panel (Super+Shift+B / NTF bell in bar)
settings/                  the Settings app (Super+Shift+s): sidebar + pages
  components/              ToggleRow, SliderRow, ComboRow, ... (shared rows)
  pages/                   Appearance, Wallpaper, Bar, Night Light,
                           Notifications, Displays, Audio, Network,
                           Bluetooth, Power, Keyboard, Mouse, Autostart, About
power/                     full-screen session menu (Super+BackSpace)
osd/                       volume/brightness on-screen display
```

## Awesome ↔ quickshell bridge

- `awesome/modules/quickshell.lua` writes tag/layout state per screen to
  `$XDG_RUNTIME_DIR/awesomewm-state.json` on every relevant signal.
- `common/AwesomeState.qml` watches that file and matches screens by output
  name (e.g. `eDP-1`); clicks call back via `awesome-client`.
- Awesome's naughty dbus module is stubbed out in `rc.lua` so quickshell can
  own `org.freedesktop.Notifications`; naughty still shows awesome's own
  startup/runtime errors.

## Install (OpenMandriva)

New machine: run `./install-desktop.sh` from the stow repo root — it
installs all packages (quickshell, picom, rofi, gammastep, portals, fonts,
...), stows the configs, fetches greenclip/rofimoji, and seeds the dark
theme. Minimal manual equivalent:

```sh
sudo dnf install quickshell quickshell-x11
```

## IPC

```sh
qs ipc call settings toggle      # Super+Shift+s
qs ipc call nightlight toggle    # Super+Shift+n
qs ipc call nightlight temp 2700
qs ipc call theme toggle         # Super+Shift+t (dark/light)
qs ipc call media toggle         # Super+a (media panel)
qs ipc call media playPause
qs ipc call power toggle         # Super+BackSpace (session menu)
qs ipc call audio raise          # volume keys / Ctrl+Up|Down (+ OSD)
qs ipc call audio muteToggle
qs ipc call brightness up        # XF86MonBrightness keys (+ OSD)
qs ipc call notifs toggle        # Super+Shift+b (notification center)
qs ipc call notifs dnd           # toggle do-not-disturb
qs ipc call sysmon toggle        # Super+Shift+m (conky dashboard popout)
```

## Session security

Locking is not quickshell's job: `xss-lock` (autostarted by awesome) runs
the `lock-screen` wrapper (from the `local` stow package) on idle (xset,
Settings → Power page), on `loginctl lock-session` (Ctrl+Alt+L), and before
suspend via systemd's sleep inhibitor. The wrapper prefers xsecurelock
(login-style password prompt, source-built by install-desktop.sh) and falls
back to i3lock-color's ring indicator. The polkit auth agent is
lxqt-policykit (Qt, no KDE deps), also autostarted by awesome.

## System-wide dark/light mode

`common/SystemTheme.qml` runs `~/.local/bin/system-theme-apply` (from the
`local` stow package) at shell startup and on every Super+Shift+t /
settings-app toggle. That script pushes the mode to every channel apps use
for the "system" theme: GSettings color-scheme/gtk-theme (read by the GTK
portal backend, which answers Electron apps like Slack — see
`.config/xdg-desktop-portal/portals.conf` for the routing), kdeglobals via
plasma-apply-colorscheme, qt6ct.conf (Qt apps), and xsettingsd + gtk
settings.ini (GTK apps). Files are created if missing, for fresh machines.

Qt apps read their palette *and* icon theme through
`QT_QPA_PLATFORMTHEME=qt6ct`, set in the stowed `shell/.xprofile`. The
xdgdesktopportal platform theme was tried first and rejected: it supplies a
color scheme but no icon theme, so Qt's icon lookup fails and
`Quickshell.iconPath()` returns `image://icon` URLs that never load. qt6ct
gives both, at the cost of reading a static file — hence system-theme-apply
rewriting its `color_scheme_path` (darker/airy) on each toggle. `qt6ct.conf`
is intentionally not tracked in git, since it is rewritten at runtime.

## Media player

`common/Media.qml` tracks MPRIS players (Spotify, browsers, mpv, ...). When
one exists, a play/pause section appears in the bar under the taglist:
left-click (or Super+a) opens a popup panel with album art, seekable
progress, and prev/play/next; right-click toggles play/pause directly.
Super+a asks awesome for the focused screen via `awesome-client`.

Settings persist to `~/.local/state/quickshell/by-shell/<id>/settings.json`,
not this repo. Quickshell hot-reloads when config files change.

## Testing outside awesome

The bar can be smoke-tested inside any X11 session (e.g. Plasma) with `qs`;
the taglist stays hidden until awesome writes its state file, and tray/menu
behavior may conflict with an existing shell.
