#!/usr/bin/env bash
# Install the AwesomeWM + Quickshell desktop environment.
#
#   git clone https://github.com/schappellshow/awesome-quickshell-de
#   cd awesome-quickshell-de && ./install.sh
#
# Idempotent: safe to re-run after a pull.
#
# Package names differ per distribution, so every package is checked
# against the repos before install and anything missing is reported at the
# end rather than aborting the run — a missing optional package costs you
# one feature, not the whole desktop.
#
# Tested on OpenMandriva. The other package managers are best-effort: the
# mappings are correct as far as I know but are not CI-tested, so treat a
# "not in your repos" list as something to resolve by hand.
set -uo pipefail
cd "$(dirname "$0")"

info()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m  !!\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }

MISSING=()
ASSUME_YES="${ASSUME_YES:-0}"
[ "${1:-}" = "-y" ] && ASSUME_YES=1

# ── Package manager detection ────────────────────────────────────────────
if   command -v dnf     >/dev/null 2>&1; then PM=dnf
elif command -v apt-get >/dev/null 2>&1; then PM=apt
elif command -v pacman  >/dev/null 2>&1; then PM=pacman
elif command -v zypper  >/dev/null 2>&1; then PM=zypper
else
    echo "No supported package manager found (dnf/apt/pacman/zypper)." >&2
    echo "Install the dependencies listed in docs/DEPENDENCIES.md by hand," >&2
    echo "then re-run with SKIP_PACKAGES=1 to do just the config + services." >&2
    PM=none
fi
[ "$PM" != none ] && info "Package manager: $PM"

pm_has() {   # is this package name known to the repos?
    case "$PM" in
        dnf)    dnf -q repoquery --qf '%{name}' "$1" 2>/dev/null | grep -qx "$1" ;;
        apt)    apt-cache show "$1" >/dev/null 2>&1 ;;
        pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
        zypper) zypper -q se -x "$1" 2>/dev/null | grep -q "^i\?\s*|\s*$1\s*|" ;;
        *)      return 1 ;;
    esac
}

pm_install() {
    [ $# -eq 0 ] && return 0
    case "$PM" in
        dnf)    sudo dnf install --allowerasing -y "$@" ;;
        apt)    sudo apt-get install -y "$@" ;;
        pacman) sudo pacman -S --needed --noconfirm "$@" ;;
        zypper) sudo zypper install -y "$@" ;;
    esac
}

# Map a generic component to this distro's package name(s).
# Empty output = not packaged here (handled as a reported gap).
pkg_for() {
    local key="$1"
    case "$PM:$key" in
        # --- core, same name nearly everywhere ---
        *:awesome)        echo awesome ;;
        *:picom)          echo picom ;;
        *:rofi)           echo rofi ;;
        *:feh)            echo feh ;;
        *:xsettingsd)     echo xsettingsd ;;
        *:playerctl)      echo playerctl ;;
        *:flameshot)      echo flameshot ;;
        *:brightnessctl)  echo brightnessctl ;;
        *:blueman)        echo blueman ;;
        *:thunar)         echo thunar ;;
        *:qt6ct)          echo qt6ct ;;
        *:stow)           echo stow ;;
        *:git)            echo git ;;
        *:curl)           echo curl ;;
        *:conky)          echo conky ;;

        # --- quickshell: the one hard dependency that is rarely packaged ---
        dnf:quickshell)    echo "quickshell quickshell-x11" ;;
        pacman:quickshell) echo quickshell ;;   # AUR
        *:quickshell)      echo "" ;;

        # --- portals ---
        *:portal)          echo "xdg-desktop-portal xdg-desktop-portal-gtk" ;;

        # --- polkit agent ---
        *:polkit)          echo lxqt-policykit ;;

        # --- secret service (KWallet's ksecretd) ---
        dnf:kwallet)       echo "kf6-kwallet kwallet-pam" ;;
        pacman:kwallet)    echo "kwallet kwallet-pam" ;;
        zypper:kwallet)    echo "kwallet6 kwallet-pam" ;;
        apt:kwallet)       echo "kwalletmanager" ;;

        # --- lock screen ---
        dnf:i3lock)        echo i3lock-color ;;
        pacman:i3lock)     echo i3lock-color ;;   # AUR
        *:i3lock)          echo i3lock ;;         # plain fallback

        # --- audio mixer ---
        *:mixer)           echo pavucontrol-qt ;;

        # --- printing ---
        dnf:printer)       echo system-config-printer-gui ;;
        *:printer)         echo system-config-printer ;;

        # --- automount ---
        dnf:udiskie)       echo "" ;;   # not packaged; pip fallback
        *:udiskie)         echo udiskie ;;

        # --- betterlockscreen's blur/dim cache is built with `convert` ---
        zypper:imagemagick) echo ImageMagick ;;
        *:imagemagick)     echo imagemagick ;;

        # --- icons ---
        dnf:icons)         echo kf6-breeze-icons ;;
        apt:icons)         echo breeze-icon-theme ;;
        pacman:icons)      echo breeze-icons ;;
        zypper:icons)      echo breeze5-icons ;;

        # --- fonts ---
        dnf:font-mono)     echo fonts-ttf-hack ;;
        apt:font-mono)     echo fonts-hack-ttf ;;
        pacman:font-mono)  echo ttf-hack ;;
        zypper:font-mono)  echo hack-fonts ;;
        dnf:font-nerd)     echo fonts-ttf-nerd-jetbrains-mono ;;
        pacman:font-nerd)  echo ttf-jetbrains-mono-nerd ;;
        *:font-nerd)       echo "" ;;   # often unpackaged; see docs

        # --- build deps for the source-built tools ---
        dnf:build)         echo "gcc make cmake pkgconf autoconf automake libtool \
                                 gettext intltool lib64x11-devel lib64xcb-devel \
                                 lib64xcb-util-devel lib64xxf86vm-devel \
                                 lib64glib2.0-devel lib64pam-devel \
                                 lib64xext-devel lib64xfixes-devel lib64xmu-devel \
                                 lib64xrandr-devel lib64xscrnsaver-devel \
                                 lib64xcomposite-devel lib64xft-devel" ;;
        apt:build)         echo "build-essential cmake pkg-config autoconf automake \
                                 libtool gettext libx11-dev libxcb1-dev \
                                 libxcb-util-dev libxxf86vm-dev libglib2.0-dev \
                                 libpam0g-dev libxext-dev libxfixes-dev libxmu-dev \
                                 libxrandr-dev libxss-dev libxcomposite-dev libxft-dev" ;;
        pacman:build)      echo "base-devel cmake libx11 libxcb xcb-util libxxf86vm \
                                 glib2 pam libxext libxfixes libxmu libxrandr \
                                 libxss libxcomposite libxft" ;;
        zypper:build)      echo "gcc make cmake pkg-config autoconf automake libtool \
                                 gettext-tools libX11-devel libxcb-devel \
                                 xcb-util-devel glib2-devel pam-devel" ;;
        *)                 echo "" ;;
    esac
}

# ── Packages ─────────────────────────────────────────────────────────────
if [ "$PM" != none ] && [ "${SKIP_PACKAGES:-0}" != 1 ]; then
    info "Resolving packages for $PM"
    want=()
    for key in awesome quickshell picom rofi feh xsettingsd playerctl flameshot \
               brightnessctl blueman thunar qt6ct stow git curl portal polkit \
               kwallet i3lock mixer printer udiskie icons font-mono font-nerd \
               imagemagick build; do
        names="$(pkg_for "$key")"
        if [ -z "$names" ]; then
            MISSING+=("$key (not packaged for $PM)")
            continue
        fi
        for n in $names; do
            if pm_has "$n"; then want+=("$n"); else MISSING+=("$n"); fi
        done
    done
    info "Installing ${#want[@]} packages"
    pm_install "${want[@]}" || warn "some packages failed; see the summary below"
fi

# ── Source builds (not packaged on most distros) ─────────────────────────
build_from_git() {   # name  repo  build-commands...
    local name="$1" repo="$2"; shift 2
    if command -v "$name" >/dev/null 2>&1; then ok "$name already installed"; return; fi
    info "Building $name from source ($repo)"
    local d; d="$(mktemp -d)"
    if ! git clone --depth 1 "$repo" "$d" >/dev/null 2>&1; then
        warn "could not clone $repo — skipping $name"; rm -rf "$d"; MISSING+=("$name (clone failed)"); return
    fi
    ( cd "$d" && eval "$*" ) || { warn "$name build failed"; MISSING+=("$name (build failed)"); }
    rm -rf "$d"
}

if [ "${SKIP_BUILDS:-0}" != 1 ]; then
    # Night light. Packaged on some distros but often stale.
    if ! command -v gammastep >/dev/null 2>&1 && ! pm_has gammastep; then
        build_from_git gammastep https://gitlab.com/chinstrap/gammastep.git \
            "./bootstrap && ./configure --enable-randr --enable-vidmode --disable-gui && make -j$(nproc) && sudo make install"
    fi
    # Bridges X screensaver + systemd to the locker. Rarely packaged.
    build_from_git xss-lock https://github.com/xdbob/xss-lock.git \
        "cmake . && make -j$(nproc) && sudo make install"
    # Login-style lock screen; falls back to i3lock-color if absent.
    pam_service=system-auth; [ -f /etc/pam.d/system-auth ] || pam_service=login
    build_from_git xsecurelock https://github.com/google/xsecurelock.git \
        "sh autogen.sh && ./configure --prefix=/usr/local --with-pam-service-name=$pam_service && make -j$(nproc) && sudo make install"
fi

# ── Single-file tools (essentially unpackaged everywhere) ───────────────
# Each is used by a binding or script in this repo, so a missing one is a
# feature that silently does nothing rather than an obvious failure.
mkdir -p "$HOME/.local/bin"

# Clipboard history: the daemon feeds rofi's clipboard mode (Super+/), and
# awesome autostarts it. Ships as a static binary; only the AUR packages it.
if ! command -v greenclip >/dev/null 2>&1; then
    info "greenclip (clipboard history daemon)"
    gc_url="$(curl -fsSL https://api.github.com/repos/erebe/greenclip/releases/latest 2>/dev/null \
        | grep -o '"browser_download_url": *"[^"]*"' | grep -o 'https://[^"]*' | head -1)"
    if [ -n "${gc_url:-}" ] && curl -fL "$gc_url" -o "$HOME/.local/bin/greenclip" 2>/dev/null; then
        chmod +x "$HOME/.local/bin/greenclip"
        ok "greenclip installed"
    else
        rm -f "$HOME/.local/bin/greenclip"
        MISSING+=("greenclip (fetch failed; https://github.com/erebe/greenclip/releases)")
    fi
fi

# Blurred-wallpaper lock screen. A single shell script wrapping i3lock-color;
# lock-screen prefers it, and Wallpaper.qml rebuilds its cache on every
# wallpaper change. Needs imagemagick, installed above.
if ! command -v betterlockscreen >/dev/null 2>&1; then
    info "betterlockscreen (blurred-wallpaper lock screen)"
    if curl -fsSL https://raw.githubusercontent.com/betterlockscreen/betterlockscreen/main/betterlockscreen \
            -o "$HOME/.local/bin/betterlockscreen" 2>/dev/null; then
        chmod +x "$HOME/.local/bin/betterlockscreen"
        ok "betterlockscreen installed"
    else
        rm -f "$HOME/.local/bin/betterlockscreen"
        MISSING+=("betterlockscreen (fetch failed; falls back to xsecurelock)")
    fi
fi

# Emoji picker behind Super+. — python, rarely packaged.
if ! command -v rofimoji >/dev/null 2>&1; then
    info "rofimoji (emoji picker)"
    if command -v pipx >/dev/null 2>&1 && pipx --version >/dev/null 2>&1; then
        pipx install rofimoji || MISSING+=("rofimoji (pipx install failed)")
    elif command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1; then
        python3 -m pip install --user rofimoji || MISSING+=("rofimoji (pip install failed)")
    else
        MISSING+=("rofimoji (no pipx/pip; install python3-pip)")
    fi
fi

# udiskie: needs the system PyGObject, so pip --user rather than an
# isolated venv. Only when the distro doesn't package it.
if ! command -v udiskie >/dev/null 2>&1; then
    if command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1; then
        info "Installing udiskie (pip --user)"
        python3 -m pip install --user udiskie || MISSING+=("udiskie (pip install failed)")
    else
        MISSING+=("udiskie (no pip; install python3-pip)")
    fi
fi

# ── Link the configuration ───────────────────────────────────────────────
info "Linking configuration into \$HOME (GNU stow)"
if ! command -v stow >/dev/null 2>&1; then
    echo "stow is required to link the config. Install it and re-run." >&2
    exit 1
fi
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/applications"
if ! stow -t "$HOME" config bin session; then
    warn "stow reported conflicts — existing files are in the way."
    warn "Move or remove the listed files, then re-run. Nothing was overwritten."
    exit 1
fi
ok "config, bin and session linked"

# ~/.xprofile carries the session env (Qt theme, XDG_CURRENT_DESKTOP), but
# some display managers never source it. A login shell always reads
# ~/.bash_profile, so chain it from there if it isn't already.
if [ -f "$HOME/.bash_profile" ] && ! grep -q '\.xprofile' "$HOME/.bash_profile"; then
    printf '\n# Session environment for the awesome desktop\nif [ -f ~/.xprofile ]; then\n    . ~/.xprofile\nfi\n' >> "$HOME/.bash_profile"
    ok "chained ~/.xprofile from ~/.bash_profile"
elif [ ! -f "$HOME/.bash_profile" ]; then
    printf '# Session environment for the awesome desktop\nif [ -f ~/.xprofile ]; then\n    . ~/.xprofile\nfi\n' > "$HOME/.bash_profile"
    ok "created ~/.bash_profile chaining ~/.xprofile"
fi

# ── Keep KDE's shortcut daemon out of this session ──────────────────────
# On a machine that has, or used to have, Plasma installed, kglobalacceld is
# D-Bus activated by any KDE app that happens to run — spectacle, a KWallet
# prompt — and then claims every shortcut left in ~/.config/kglobalshortcutsrc.
# Meta+Space is KRunner's default, so it silently shadows the rofi launcher,
# and a migrated config usually holds dozens more Meta+ bindings.
#
# Masking the units would stop that but would also break every global
# shortcut in a Plasma session, since kglobalaccel serves the whole session
# and both units are D-Bus activated rather than started by a target. Gate
# them instead on a variable awesome sets while it runs and clears when it
# exits (modules/autostart.lua, rc.lua), so a Plasma session is untouched.
for unit in plasma-kglobalaccel plasma-krunner; do
    found=""
    for d in /usr/lib/systemd/user /usr/local/lib/systemd/user /etc/systemd/user; do
        [ -f "$d/$unit.service" ] && found=1 && break
    done
    [ -n "$found" ] || continue
    dropin="$HOME/.config/systemd/user/$unit.service.d"
    mkdir -p "$dropin"
    cat >"$dropin/zz-awesome-session.conf" <<'EOF'
# Installed by awesome-quickshell-de.
# Skips this KDE unit while the awesome session is running. A Plasma session,
# where AWESOME_SESSION is unset, starts it normally — so KRunner and the
# rest of Plasma's global shortcuts keep working there.
# Delete this file to restore stock behaviour.
[Unit]
ConditionEnvironment=!AWESOME_SESSION=1
EOF
    ok "$unit gated on AWESOME_SESSION"
done

info "systemd user units"
systemctl --user daemon-reload 2>/dev/null || true

mkdir -p "$HOME/Pictures/Screenshots"

# ── Flameshot: background instance, no tray icon ─────────────────────────
# modules/autostart.lua keeps a flameshot instance running so its Copy button
# survives the capture (on X11 the copied image dies with the process that owns
# the selection). That instance ships a tray icon by default, which this
# desktop doesn't need — the Print key is the entry point and the bar has its
# own tray. Seed the setting only when the key is absent, so re-running the
# installer never overrides a tray icon somebody turned back on deliberately.
# The key is flameshot's own spelling: disabledTrayIcon, not showTrayIcon.
if command -v flameshot >/dev/null 2>&1 \
   && ! grep -q '^disabledTrayIcon=' "$HOME/.config/flameshot/flameshot.ini" 2>/dev/null; then
    if flameshot config --trayicon false >/dev/null 2>&1; then
        ok "flameshot tray icon disabled (background instance still runs)"
    fi
fi

# ── Summary ──────────────────────────────────────────────────────────────
echo
if [ ${#MISSING[@]} -gt 0 ]; then
    warn "Not installed (${#MISSING[@]}):"
    for m in "${MISSING[@]}"; do echo "       - $m"; done
    echo
    echo "  Each maps to one feature, not the whole desktop — see"
    echo "  docs/DEPENDENCIES.md for what each provides and how to get it."
    if printf '%s\n' "${MISSING[@]}" | grep -q quickshell; then
        echo
        warn "quickshell is REQUIRED (bar, notifications, settings app)."
        warn "Build it from https://quickshell.outfoxxed.me before logging in."
    fi
fi

info "Done. Log out and pick the \"awesome\" session at your display manager."
echo "  First run: Settings (Super+Shift+S) to set wallpaper, displays, etc."
echo "  Keybindings: Super+S"
