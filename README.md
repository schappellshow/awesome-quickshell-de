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
- Notification daemon with popups, history center, and do-not-disturb
- **Settings app** (`Super+Shift+S`) — 15 pages: appearance, wallpaper,
  bar, night light, notifications, displays, audio, network (incl. Wi-Fi
  scan/connect), bluetooth, power, keyboard, mouse, autostart, default
  apps, about
- Power menu, volume/brightness OSD, night light with optional schedule

**Session**
- Screen locking (xsecurelock, falling back to i3lock-color) wired to idle,
  `loginctl lock-session`, and lock-before-suspend
- Polkit agent, Secret Service, XDG autostart, automounting
- System-wide dark/light theming across GTK, Qt and portal-consuming apps
- Monitor hotplug: restores your saved layout *and* returns windows to the
  screen and tag they came from

**Window management (AwesomeWM)**
- Tiling with per-orientation defaults (portrait monitors stack vertically)
- Directional focus/swap that crosses monitor boundaries
- 4 tags per screen, rofi launcher, spectacle screenshots

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
2. **Wallpaper** — a distro-shipped wallpaper is adopted automatically;
   pick another here (it lists `~/Pictures/Wallpapers` and the system dirs)
3. **Displays** — arrange monitors, then Apply. This is also what teaches
   the session your layout so it can be restored at login and on hotplug
4. **Bar** — choose which screen the bar lives on, and which pills to show

---

## Keybindings

`Super+S` (or `Super+F1`) shows this list live.

| Keys | Action |
|---|---|
| `Super+Return` | Terminal |
| `Super+E` | File manager |
| `Super+Space` | App launcher (rofi) |
| `Super+Shift+Space` / `Super+Ctrl+Space` | Run command / window switcher |
| `Super+/` · `Super+.` | Clipboard history · emoji picker |
| `Super+H/J/K/L` | Focus left/down/up/right (crosses monitors) |
| `Super+Shift+H/J/K/L` | Swap window in that direction |
| `Super+Ctrl+H/L` | Shrink / expand master |
| `Super+1..4` | Switch tag (`Super+Shift+N` move window, `Super+Ctrl+N` toggle) |
| `Super+O` | Move window to next screen |
| `Super+Q` · `Super+F` · `Super+M` · `Super+N` | Close · fullscreen · maximise · minimise |
| `Super+Shift+F` · `Super+T` | Toggle floating · keep on top |
| `Super+\` | Cycle layout |
| `Super+Shift+S` | Settings app |
| `Super+Shift+B` · `Super+Shift+X` · `Super+D` | Notification center · clear · do-not-disturb |
| `Super+V` · `Super+A` | Calendar · media panel |
| `Super+Z` | Keep awake (inhibit auto-lock) |
| `Super+Shift+T` · `Super+Shift+N` | Dark/light mode · night light |
| `Super+Shift+M` | System monitor popout (conky, optional) |
| `Super+BackSpace` · `Ctrl+Alt+L` | Power menu · lock now |
| `Print` · `Shift+Print` | Screenshot region · full |
| `Super+Ctrl+R` · `Super+Ctrl+Q` | Reload awesome · quit |

---

## How it fits together

```
AwesomeWM ──── tags/layout state ────▶ $XDG_RUNTIME_DIR/awesomewm-state.json
   ▲                                              │
   └──────── awesome-client commands ──────── Quickshell (bar, settings, …)
                                                  │
                                    settings.json (state, outside the repo)
                                                  │
              ┌───────────────────────────────────┴──────────────┐
        apply singletons                                    session glue
   xrandr · feh · xset · setxkbmap · xinput            systemd user units
   system-theme-apply · icon-theme-apply               autostart · secrets
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

---

## Per-machine state (not in this repo)

Deliberately kept out so the repo stays portable and your runtime changes
never dirty git:

| What | Where |
|---|---|
| All preferences (wallpaper, bar, display layout, …) | `~/.local/state/quickshell/by-shell/*/settings.json` |
| Qt theme config (rewritten on dark/light toggle) | `~/.config/qt6ct/qt6ct.conf` |
| Lock screen image cache (built by `lock-image`) | `~/.cache/lock-screen/` |
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

**Bar/notifications missing** — Quickshell isn't running. `qs` in a
terminal shows the error; `qs -vv` is more verbose.

**Qt menus or dialogs look light in a dark session** — `~/.xprofile` isn't
being sourced. Confirm with `echo $QT_QPA_PLATFORMTHEME` (expect `qt6ct`).
Some display managers skip `.xprofile`; the installer chains it from
`~/.bash_profile` for that reason.

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

MIT — see [LICENSE](LICENSE).
