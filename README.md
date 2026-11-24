# AwesomeWM + Quickshell Desktop Environment

A complete desktop environment built from two pieces rather than one
monolith: **AwesomeWM** does window management, and **Quickshell** (QML)
provides everything you'd otherwise get from a desktop shell — bar,
notifications, settings app, power menu, OSD, lock integration.

It aims to be a *replacement* for KDE Plasma or GNOME rather than a bare
tiling WM: things like automounting a USB stick, a graphical settings app,
notification history, monitor hotplug, and "don't blank the screen while a
video is playing" all work out of the box.

Built and daily-driven on OpenMandriva Lx; the installer supports
dnf/apt/pacman/zypper, though only dnf is regularly tested (see
[Distribution support](#distribution-support)).

---

## What you get

**Shell (Quickshell)**
- Vertical bar: per-screen tags, media controls, clock + calendar popup,
  system tray, volume, network, bluetooth, CPU/RAM, screen-lock state,
  battery, layout indicator — every element toggleable
- Bar indicators that appear only when relevant: **PRF** while performance
  mode is on (hover says whether by hand or because a game is running; click
  turns it off), **CPU/RAM** only while one of them is high (Settings → Bar
  chooses *Always* or *Only when busy* and the thresholds), and **DRV** while
  a removable drive (USB stick, SD card, external disk) is plugged in — its
  popup opens, mounts, unmounts or safely ejects each one via `udisksctl`
- **System dashboard** (the CPU/RAM pill or `Super+Shift+M`): a native
  replacement for the conky popout — cards for system, processors (per-core
  bars, top processes), memory, drives (I/O graphs), network (default-route
  interface) and GPU (amdgpu sysfs), with sparklines. Settings → Bar picks
  Quickshell or conky, *Popout* or *Pinned on desktop*, and which cards show.
  It samples only while visible. See [System dashboard](#system-dashboard)
- Notification daemon with popups, history center, and do-not-disturb
- Optional desktop-style bar: start button, pinned apps, open-window list —
  and a bare `Super` tap can open the start menu, the way a floating desktop
  does, without disturbing any `Super+` shortcut. It opens at the pointer or
  beside the button, whichever you prefer
- **Quick-actions ring** — `Super`+middle-click anywhere (desktop or over a
  window) opens a ring of round buttons around the pointer: screenshot menu,
  scratchpad, float/close the window under the pointer, overview, app
  launcher, lock, performance mode. Click one, or hold the button, move toward
  an action and let go over it (let go in the middle or outside to cancel;
  `Escape` or a click outside also cancels). Window actions act on the window
  that was under the pointer, not the focused one, and are grayed out over the
  bare desktop. Which actions appear, and in what order, is Settings → Mouse;
  there is also an unbound-by-default keyboard shortcut (Settings → Keyboard)
  and `qs ipc call ring open <x> <y> <window-id>`
- **Settings app** (`Super+Shift+S`) — 19 pages: appearance, wallpaper,
  bar, apps, windows, night light, notifications, displays, audio, network
  (incl. Wi-Fi scan/connect), bluetooth, power, lock screen,
  keyboard (incl. shortcuts), mouse (incl. cursor theme), autostart,
  default apps, backups, about
- Every keybinding is rebindable from Settings → Keyboard: click one, press
  the combination, done — no reload, no config file. You can add your own
  too: any command on any chord, so a second terminal gets its own key
- Power menu, volume/brightness OSD, night light with optional schedule

**Session**
- Screen locking (xsecurelock, falling back to i3lock-color) wired to idle,
  `loginctl lock-session`, and lock-before-suspend
- Polkit agent, Secret Service, XDG autostart, automounting
- System-wide dark/light theming across GTK, Qt and portal-consuming apps,
  plus icon and mouse cursor themes
- Every shell color is editable and saveable as a named scheme — one
  self-contained JSON file, so a theme is something you can send someone
- Colors from the wallpaper: Settings → Appearance derives an accent, the
  eight palette colors and a gentle background tint from the current
  wallpaper, shows a preview, and saves it as a scheme only when you press
  Apply (or follows wallpaper changes, off by default). Text stays neutral and
  every color is lightness-adjusted to a stated contrast ratio
  (`bin/.local/bin/wallpaper-palette --report <image>` prints the numbers).
  The active scheme, wallpaper-derived or not, also colors rofi, through a
  generated `~/.cache/quickshell/rofi-colors.rasi` that falls back to the
  OpenMandriva colors when absent
- Monitor hotplug: restores your saved layout *and* returns windows to the
  screen and tag they came from
- Audio follows what you plug in: connect a TV over HDMI, a bluetooth
  speaker or a USB headset and sound moves to it, then moves back when it
  goes away. Settings → Audio also exposes the card profile and output port
  directly, so when the automatic choice is wrong it's one click to fix
  rather than a trip to pavucontrol
- Bluetooth that turns on: the adapter's power toggle clears an rfkill soft
  block first, which BlueZ will not do for you and which otherwise makes the
  switch a silent no-op that survives reboots
- Optional daily backups — **off until you turn them on** — with the
  destination, schedule, retention and exclusions all in Settings → Backups

**Window management (AwesomeWM)**
- Tiling with per-orientation defaults (portrait monitors stack vertically),
  a global tiling/floating mode, and per-monitor layout overrides
- Window outline (width, corner radius) is configurable, and its colors
  follow the active color scheme
- Directional focus/swap that crosses monitor boundaries
- 4 tags per screen, rofi launcher, screenshots with an annotation editor

---

## Requirements

The only hard requirement is **[Quickshell](https://quickshell.outfoxxed.me)**
— the bar, notifications and settings app are built on it. It's packaged on
few distributions; if `install.sh` reports it missing, build it before
logging in.

Everything else degrades gracefully: a missing package costs you one
feature, not the desktop. See [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md)
for what each provides.

---

## Install

```sh
git clone https://github.com/schappellshow/awesome-quickshell-de
cd awesome-quickshell-de
./install.sh
```

The installer resolves package names for your distribution, checks each
against your repos, installs what exists, builds the few tools that are
rarely packaged (xss-lock, xsecurelock, gammastep), links the config with
GNU stow, and reports anything it couldn't get.

Then **log out and pick the "awesome" session** at your display manager.

Useful switches: `SKIP_PACKAGES=1` (config only), `SKIP_BUILDS=1` (no
source builds).

### First run

1. `Super+Shift+S` → **Settings**
2. **Appearance** — dark/light, then any color you like: edit the palette
   directly and save it as a named scheme
3. **Wallpaper** — a distro-shipped wallpaper is adopted automatically;
   pick another here (it lists `~/Pictures/Wallpapers` and the system dirs)
4. **Displays** — drag the labeled screens to match your desk (edges and
   centers snap), choose the primary display, then **Apply** and **Keep**.
   Unconfirmed changes revert after 20 seconds; only Keep saves the layout
   for login and hotplug. Pixel coordinates are editable below the preview;
   press Enter to stage each value. Refresh / Reset discards pending edits.
5. **Bar** — choose which screen the bar lives on, and which pills to show

---

## Keybindings

`Super+S` shows this list live (`Super+F1` opens awesome's own cheatsheet,
which still works without the shell), and Settings → Keyboard
rebinds any of it — the table below is the defaults.

| Keys | Action |
|---|---|
| `Super+Return` | Terminal |
| `Super+E` | File manager |
| `Super+Space` | App launcher (rofi) |
| `Super+Shift+Space` / `Super+Ctrl+Space` | Run command / window switcher (rofi) |
| `Alt+Tab` / `Alt+Shift+Tab` | Window switcher: hold Alt, Tab cycles, release to switch, `Esc` cancels. A quick tap flips between the last two windows |
| `Super+Tab` | Window overview (was the rofi switcher) |
| `Super+'` (apostrophe) | Scratchpad: summon a floating window over the current tag, same key hides it; starts a terminal if empty |
| `Super+Shift+'` | Send the focused window to the scratchpad; on the scratchpad itself, take it back out as a tiled window |
| `Super+Ctrl+F` | Float / tile just this tag (windows keep their positions) |
| `Super+left-drag` · `Super+right-drag` | Move · resize the window under the pointer (floating windows) |
| `Super+middle-click` | Quick-actions ring at the pointer: click an action, or hold, move and release over one (Settings → Mouse) |
| `Super+Alt+G` | Performance mode |
| `Super+/` · `Super+.` | Clipboard history · emoji picker |
| `Super+H/J/K/L` | Focus left/down/up/right (crosses monitors) |
| `Super+Shift+H/J/K/L` | Swap window in that direction |
| `Super+Ctrl+H/L` | Shrink / expand master |
| `Super+1..4` | Switch tag (`Super+Shift+N` move window, `Super+Ctrl+N` toggle) |
| `Super+O` | Move window to next screen |
| `Super+Q` · `Super+F` · `Super+M` · `Super+N` | Close · fullscreen · maximize · minimize |
| `Super+Shift+F` · `Super+T` | Toggle floating · keep on top |
| `Super+\` | Cycle layout |
| `Super+S` · `Super+F1` | Shortcut list · awesome's cheatsheet |
| `Super+Shift+S` | Settings app |
| `Super+Shift+B` · `Super+Shift+X` · `Super+D` | Notification center · clear · do-not-disturb |
| `Super+V` · `Super+A` | Calendar · media panel |
| `Super+Z` | Keep awake (inhibit auto-lock) |
| `Super+B` | Rebuild the bar — recovers a section that draws blank, or a bar left on the wrong screen |
| `Super+Shift+T` · `Super+Shift+N` | Dark/light mode · night light |
| `Super+Shift+M` | System dashboard: native Quickshell popout (default), or lifts the pinned one above windows; conky if chosen in Settings → Bar |
| `Super+BackSpace` · `Ctrl+Alt+L` | Power menu · lock now |
| `Print` · `Shift+Print` | Screenshot region → annotation editor · full screen straight to disk |
| `Alt+Print` | Screenshot menu — see [Screenshots](#screenshots) |
| `Super+Ctrl+R` · `Super+Ctrl+Q` | Reload awesome · quit |
| `Super` (tap alone) | Start menu — off by default, Settings → Apps |

---

## System dashboard

Settings → Bar → System monitor. **Dashboard** chooses Quickshell (default)
or conky; conky behaves exactly as before and keeps its config field.

- **Popout** (default): hidden until the pill / `Super+Shift+M` toggles it.
  It sits beside the bar on whichever edge the bar is on, on the bar's
  screen, above windows, never focused, no space reserved.
- **Pinned on desktop**: always shown beside the bar, *below* every window
  (so fullscreen covers it), not focusable. The pill / key then lifts it
  above the windows to peek; press again to put it back.

**Customizing it.** Hover the dashboard's header and click the gear to open
its settings panel in place (the same controls are in Settings → Bar):

- **Position**: beside the bar (default), the four screen corners, center, or
  custom. Drag the header to place it yourself; that switches to custom and
  the spot is remembered per screen. It always stays on screen and clear of
  the bar, in both popout and pinned modes.
- **Cards**: show/hide and move each of System, Processors, Memory, Drives,
  Network and GPU up or down. Cards fill left, right, left, right in order.
- **Opacity** (40–100%) of the panel and cards; text stays fully opaque.
- **Blur behind** (default on): the setting is stored as `dashboardBlur`;
  the compositor hint that acts on it is wired separately.

For scripts: `qs ipc call sysmon settings true|false`, `position <name>`,
`placeAt <x> <y>`, `opacity <percent>`, `blur <bool>`, `move <card> <±1>`.

Nothing is sampled or running while it is closed; open, one small script runs
every 2 s (6 s in performance mode). Pinned mode is "always open", so it keeps
sampling. Readings: `/proc`, `df`, `ip`, and sysfs for the CPU temperature
(k10temp/coretemp hwmon) and the GPU (`/sys/class/drm/card*/device`
`gpu_busy_percent`, `mem_info_vram_*`, hwmon `temp1_input`) — all readable
without root. `qs ipc call sysmon status` reports the state.

## Screenshots

`Print` freezes the screen, lets you drag a region and opens the annotation
editor on it (see below); `Esc` at any point cancels with nothing saved.
`Shift+Print` saves the whole screen to `~/Pictures/Screenshots/`, copies it
and notifies, with no editor. Spectacle is only a fallback now, used when
quickshell is not running. `Alt+Print` opens the screenshot menu. On a 60% board where Print is `Fn+K`, hold Right Alt:
X receives `Alt_R` + `Sys_Req`, so the menu is bound to both `Alt+Sys_Req`
and `Alt+Print`; either is rebindable in Settings → Keyboard.

Menu (keys, mouse, or `Up`/`Down` + `Enter`; `Esc` or a click outside closes):
**R**egion, **W**indow (the one focused when the menu opened), **S**creen
(monitor under the pointer), **A**ll screens, **T**ext (OCR), **C**olor
picker, and a delay of none / 3 / 5 / 10 s (`Left`/`Right`/`D`) for the four
captures, with a countdown pill (click it to cancel). The menu is gone
before the grab. **E** (or the *Open in editor* chip) sends a Region, Window,
Screen or All-screens capture to the editor instead of saving it. Captures go to `~/Pictures/Screenshots/` as PNG, onto the
clipboard as an image (kept alive by an `xclip` holder until something else
is copied), and a notification offers *Open* / *Show in folder*. Text
recognition copies the text and shows its first lines; the color picker
shows a magnifier, copies `#rrggbb` and shows a swatch.

All of it runs on one frozen grab of the screen, so a region is cut from
exactly the pixels you dragged over, across monitors. Scripting:
`qs ipc call screenshot capture region|window|screen|all|ocr|color [delay]`,
or `screenshot now screen` outside the shell. Needs ImageMagick, `xclip`,
`xdotool`, `notify-send`; OCR needs `tesseract` with English data.

### Annotation editor

A window showing the capture at a fitting zoom (never enlarged past 100%),
floated, centered and focused on the screen the pointer is on. Tools, by
click or key: **V** select, **A** arrow, **R** rectangle, **P** pen,
**H** highlighter (wide, translucent), **T** text (`Enter` places it,
`Shift+Enter` is a new line), **B** redact (pixelates the box). Seven colors
(Theme red/orange/gold/green/accent, white, black) and three widths S/M/L.
`Ctrl+Z` / `Ctrl+Shift+Z` undo and redo; `Delete` removes the selected
shape (the last one placed, or the one clicked with the select tool).
`Ctrl+C` copies, `Ctrl+S` saves to `~/Pictures/Screenshots/` under the usual
timestamp name, `Ctrl+Shift+S` is *Save as…* (kdialog, else zenity).
`Esc` closes; if there are annotations you have not saved or copied it asks
first (`Esc` again discards). The clipboard survives the editor closing, and
the saved file is the original resolution with the annotations burned in,
whatever the on-screen zoom.

Scripting: `qs ipc call shoteditor open <png>` opens any PNG, and
`drag`, `text`, `undo`, `redo`, `exportPng <path>`, `status` drive it without
a pointer (`tests/screenshot-editor-nested.sh` uses them). The capture can
also be started directly: `qs ipc call screenshot captureEdit region|window|screen|all [delay]`.

Note: tesseract 5.5.4 as packaged on OpenMandriva crashes (SIGFPE in
`compute_block_xheight`) unless `-c textord_old_xheight=1` is passed, which
the script does.

---

## Backups

**Off by default, and off until you turn them on.** The timer ships disabled
and the destination ships empty, so a fresh install has no schedule and
nowhere to write. Nothing else in the desktop depends on this.

### The recommended setup

This is what the shipped job does, and it is the setup this desktop is
developed against:

| | |
|---|---|
| Tool | [borg](https://borgbackup.org) — deduplicated, compressed, versioned snapshots |
| What | Your home directory, minus caches and Trash (editable) |
| Where | One repository per machine, `<destination>/<hostname>-home.borg` |
| When | Daily, at a time you pick; a run missed while the machine was off happens at the next login |
| History | 7 daily, 4 weekly, 6 monthly by default, pruned after each run |

To set it up: install `borg`, plug in (or mount) the disk you want to back up
to, then open **Settings → Backups**, put the folder in *Backup folder*,
press **Create repository**, and turn **Daily backup** on. *Back up now*
proves it works without waiting for the timer.

**Already have a borg repository?** Rename it to `<hostname>-home.borg`
inside your chosen destination and the job adopts it — every existing
archive, and dedup against them, intact. Nothing is re-uploaded. Check the
exclusions afterwards: they now come from this page rather than from
whatever script used to run the job.

The repository is **unencrypted**. A passphrase stored on the machine being
backed up protects against the disk walking off and nothing else, and keeping
one somewhere an unattended timer can reach is a keyring problem this doesn't
try to solve. If you want encryption, create the repository yourself with
`borg init -e repokey-blake2 <path>` — the job uses whatever repository it
finds at that path.

### Restoring

Borg is a standard format and none of this is needed to read a backup:

```sh
borg list   /mnt/backup/$(uname -n)-home.borg
borg mount  /mnt/backup/$(uname -n)-home.borg::home-2026-08-28_2000 /mnt/point
borg extract /mnt/backup/$(uname -n)-home.borg::home-2026-08-28_2000 home/you/Documents
```

### Using something else

If you already have restic, Vorta, rsnapshot, Timeshift, a NAS or a
filesystem doing snapshots, leave **Daily backup** off and schedule yours
however you like. Nothing reads this page's settings but the job it drives,
and no other part of the desktop asks whether backups exist.

### It does not nag

A run with the backup disk absent is recorded on the page and produces **no
notification**. That is deliberate: a laptop away from its disk would
otherwise pop a warning at every single login, which is how people learn to
dismiss backup warnings without reading them. Only a backup that genuinely
fails — borg ran and returned an error — says anything, and then at normal
urgency.

Warnings are treated the same way. Borg reports one when a file changed
while it was being read, which any running database, log or browser profile
does on a machine that is switched on. The snapshot is complete; the page
says "succeeded, with warnings" and names the file, and nothing pops up.

---

## How it fits together

```
AwesomeWM ──┬─ tags/layout state ────▶ $XDG_RUNTIME_DIR/awesomewm-state.json
   ▲        └─ shortcut registry ────▶ $XDG_RUNTIME_DIR/awesomewm-shortcuts.json
   │                                              │
   └──────── awesome-client commands ──────── Quickshell (bar, settings, …)
                                                  │
                                    settings.json (state, outside the repo)
                                                  │
              ┌───────────────────────────────────┴──────────────┐
        apply singletons                                    session glue
   xrandr · feh · xset · setxkbmap · xinput            systemd user units
   system-theme-apply · icon-theme-apply               autostart · secrets
   cursor-theme-apply · color-scheme · super-tap
   wallpaper-palette · rofi-colors
```

- **AwesomeWM** owns windows and publishes tag/layout state to a JSON file.
- **Quickshell** watches that file for its taglist and sends commands back
  via `awesome-client`.
- **`settings.json`** (in `~/.local/state/quickshell/`, deliberately *not*
  in this repo) is the source of truth for user preferences. Singletons
  watch it and project changes onto the system — X11 state like xrandr and
  key repeat doesn't persist, so it's re-applied at every login.

### Repo layout

| Path | Stows to | Contents |
|---|---|---|
| `config/` | `~/.config` | awesome, quickshell, picom, rofi, portal routing, systemd user units |
| `bin/` | `~/.local` | session scripts + the Settings `.desktop` entry |
| `session/` | `~` | `.xprofile` (session environment) |
| `tests/` | not stowed | display tests and the nested test session |

---

## Per-machine state (not in this repo)

Deliberately kept out so the repo stays portable and your runtime changes
never dirty git:

| What | Where |
|---|---|
| All preferences (wallpaper, bar, display layout, …) | `~/.local/state/quickshell/by-shell/*/settings.json` |
| Qt theme config (rewritten on dark/light toggle) | `~/.config/qt6ct/qt6ct.conf` |
| Chosen cursor theme (what X falls back on) | `~/.icons/default/index.theme` |
| Cursor theme previews (built by `cursor-preview`) | `~/.cache/cursor-previews/` |
| Saved color schemes (drop a file here to install one) | `~/.local/share/quickshell/color-schemes/` |
| Lock screen image cache (built by `lock-image`) | `~/.cache/lock-screen/` |
| Backup result + last run log | `~/.local/state/backup-plan/` |
| Backup run time (written from Settings) | `~/.config/systemd/user/backup-plan.timer.d/` |
| Your autostart apps | `~/.config/autostart/*.desktop` |

---

## Distribution support

| Package manager | Status |
|---|---|
| `dnf` (OpenMandriva, Fedora) | Developed and daily-driven on OpenMandriva |
| `apt` · `pacman` · `zypper` | Best-effort mappings, not regularly tested |

The installer never assumes a package exists — it queries your repos first
and reports gaps — so an untested distro should degrade to "most things
installed, here's the list of what I couldn't find" rather than a broken
run. Corrections to the package maps in `install.sh` are welcome.

---

## Troubleshooting

**Monitor positions are wrong** — open Settings → Displays and drag the
labeled rectangles into their physical arrangement. Portrait previews
follow the Rotation setting. Screens must not overlap; negative coordinates
are allowed while editing and are shifted together to start at 0,0 on Apply.
Apply tests the layout, and **Keep** saves it; **Revert** restores the previous
layout immediately, and the 20-second countdown does so automatically even
if you close the page without confirming. Errors
are shown on the page rather than saving a command that failed. Refresh /
Reset reads the live layout if another tool changed it. Connected displays
that are disabled are left disabled by this editor.

**Bar/notifications missing** — Quickshell isn't running. `qs` in a
terminal shows the error; `qs -vv` is more verbose.

**Qt menus or dialogs look light in a dark session** — tray right-click
menus are native Qt menus, so they follow Qt's platform theme rather than
this shell's colors. Two causes:

*`~/.xprofile` isn't being sourced.* Confirm with
`echo $QT_QPA_PLATFORMTHEME` — empty means it never ran. Some display
managers skip `.xprofile`; the installer chains it from `~/.bash_profile`
for that reason.

*Qt cannot load the platform theme.* A plugin built against an older Qt
stays on disk and is ignored without a warning, and Qt quietly reverts to
Fusion's light palette. Ask Qt what it can see:

```sh
qtdiag6 | sed -n '/^Theme:/,/^$/p'
```

If the `available` list does not contain the theme named in
`$QT_QPA_PLATFORMTHEME`, that is the problem, and it is your distribution's
packaging rather than this config — the fix is a rebuilt package.
`.xprofile` already prefers whichever of `qt6ct` or `kde` Qt reports as
available, so installing `plasma-integration` gives it something to fall
back to in the meantime.

**Windows land on a different monitor after `Super`+`Ctrl`+`R`** — awesome's
screen *order* and X's disagree. awesome numbers screens when it starts; if
the monitor layout is applied afterwards, geometries update but the screen
objects keep their original order, and a restart re-enumerates into the real
order — so every window follows its index onto a different output.

`~/.xprofile` applies the saved layout before awesome starts so the two
orders match from the outset. If it recurs, compare them:

```sh
awesome-client 'local o={} for s in screen do local n={} for k in pairs(s.outputs) do n[#n+1]=k end o[#o+1]=s.index..": "..table.concat(n,",") end return table.concat(o,"  ")'
xrandr --listmonitors
```

Note this is separate from a monitor being unplugged and replugged mid-session,
which `modules/screen_memory.lua` handles by output name.

**Screen locks while watching video** — the screensaver inhibitor isn't
running. Check with
`busctl --user status org.freedesktop.ScreenSaver`.

**Apps can't save passwords** — nothing owns the Secret Service.
`~/.local/bin/ensure-secret-service` starts it; note some Electron apps
also need an explicit `--password-store` flag.

**Reset a setting** — edit or delete `settings.json` (see above); it's
recreated with defaults.

---

## License

Copyright (C) 2026 Mike Schappell

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version. See [LICENSE](LICENSE) for the full text.

SPDX-License-Identifier: GPL-3.0-or-later

Versions up to and including commit `af1ed25` were released under the MIT
License.

## Display tests

Run `node --test tests/display-layout.test.cjs` for the standalone RandR
parser, geometry, snapping, validation and command-generation tests.
Run `python3 tests/display-integration.py` for offscreen QML pointer-drag
tests, apply/confirmation/rollback checks and login replay, with a fake
`xrandr` and isolated settings (requires Quickshell and QtTest). These tests
never change the real monitor layout.

## Trying a branch in a nested session

`tests/nested-session` runs a checkout's awesome, picom and quickshell on
a separate X display with its own D-Bus, home and runtime directories and a
clean environment, so nothing it does reaches the running desktop. Commands
with system-wide effects (systemctl, nmcli, pactl, lockers, theme writers,
pkill, ...) are replaced by stubs that only log the call.

```sh
tests/nested-session start ~/path/to/worktree --xephyr   # visible window
tests/nested-session run <name> -- awesome-client 'return #client.get()'
tests/nested-session stop <name>
```

Without `--xephyr` the display is an invisible Xvfb, useful for scripted
checks (`run <name> -- xdotool ...`, `run <name> -- import -window root
shot.png`). Inside Xephyr, Ctrl+Shift grabs the keyboard and mouse. picom
may repaint stale frames in a nested display, so judge animations and blur on
the real desktop.
