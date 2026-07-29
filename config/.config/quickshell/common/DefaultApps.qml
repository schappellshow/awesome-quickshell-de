pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Default applications (the "what opens a PDF / a link / an image" list),
// read and written with xdg-mime — the freedesktop tool every DE's own
// defaults panel drives underneath. State lives in ~/.config/mimeapps.list,
// not in our settings.json: it is the shared standard other apps read.
Singleton {
    id: root

    // The handful worth exposing; the full MIME database is thousands of
    // types and a settings page is not a MIME editor.
    readonly property var categories: [
        { key: "web",   label: "Web browser",  mime: "x-scheme-handler/http" },
        { key: "mail",  label: "Email",        mime: "x-scheme-handler/mailto" },
        { key: "pdf",   label: "PDF viewer",   mime: "application/pdf" },
        { key: "image", label: "Images",       mime: "image/png" },
        { key: "video", label: "Video",        mime: "video/mp4" },
        { key: "audio", label: "Audio",        mime: "audio/mpeg" },
        { key: "text",  label: "Text files",   mime: "text/plain" },
        { key: "dir",   label: "Folders",      mime: "inode/directory" }
    ]

    // mime -> current handler .desktop id
    property var current: ({})
    // mime -> [{ label, value }] candidate handlers
    property var choices: ({})
    // .desktop id -> human name, for showing a readable current value
    property var appNames: ({})

    function refresh() {
        queryProc.running = true;
    }

    function setDefault(mime, desktopId) {
        // xdg-mime writes mimeapps.list; also point the matching scheme/type
        // pairs at it so a browser choice covers http+https+html together.
        const extra = {
            "x-scheme-handler/http":
                ["x-scheme-handler/https", "text/html"],
            "image/png":
                ["image/jpeg", "image/gif", "image/webp"],
            "video/mp4":
                ["video/x-matroska", "video/webm", "video/quicktime"],
            "audio/mpeg":
                ["audio/flac", "audio/x-wav", "audio/ogg"]
        };
        const types = [mime].concat(extra[mime] || []);
        Quickshell.execDetached(
            ["xdg-mime", "default", desktopId].concat(types));
        settle.restart();
    }

    Timer {
        id: settle
        interval: 600
        onTriggered: root.refresh()
    }

    // One shell pass: for each category print the current handler, then the
    // candidate handlers, then a name lookup for every .desktop involved.
    Process {
        id: queryProc
        command: ["sh", "-c", `
# Explicit list rather than a word-split variable: this runs under whatever
# /bin/sh is, and word splitting of an unquoted var is not something to rely
# on across shells.
set -- x-scheme-handler/http x-scheme-handler/mailto application/pdf \\
       image/png video/mp4 audio/mpeg text/plain inode/directory
# Read with gio, not \`xdg-mime query\`: the latter is a shell script using an
# older resolution path that can disagree with what is actually configured
# (it kept reporting okular for application/pdf while mimeapps.list — and
# every app that opens PDFs — had PDF Studio Viewer). gio is what GTK apps,
# Thunar and friends consult. Fall back to xdg-mime where gio is absent.
for m in "$@"; do
    if command -v gio >/dev/null 2>&1; then
        v=$(gio mime "$m" 2>/dev/null | head -1 | sed 's/.*: //')
        case "$v" in *.desktop) ;; *) v="" ;; esac
    fi
    [ -n "\${v:-}" ] || v=$(xdg-mime query default "$m" 2>/dev/null)
    printf 'CUR\\t%s\\t%s\\n' "$m" "$v"
done
# Every applications dir on the XDG data path, not just the obvious two:
# AM installs AppImages to /usr/local/share/applications and flatpak to its
# own exports dir, so a hardcoded pair silently hides those apps (Zen
# Browser was missing from the list for exactly this reason).
dirs="$HOME/.local/share/applications"
for p in $(echo "\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' ' '); do
    dirs="$dirs $p/applications"
done

# Candidates: any .desktop advertising the type in its MimeType= line
for m in "$@"; do
    for d in $dirs; do
        [ -d "$d" ] || continue
        grep -lE "^MimeType=.*(^|;)$(echo "$m" | sed 's|/|\\\\/|')(;|$)" "$d"/*.desktop 2>/dev/null |
        while read -r f; do
            printf 'OPT\\t%s\\t%s\\n' "$m" "\${f##*/}"
        done
    done
done
# Readable names for every .desktop we might show
for d in $dirs; do
    [ -d "$d" ] || continue
    for f in "$d"/*.desktop; do
        [ -f "$f" ] || continue
        n=$(awk -F= '/^\\[Desktop Entry\\]/{e=1;next} e&&/^\\[/{exit} e&&/^Name=/{print $2; exit}' "$f")
        [ -n "$n" ] && printf 'NAME\\t%s\\t%s\\n' "\${f##*/}" "$n"
    done
done
`]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    function parse(t) {
        const cur = {}, opts = {}, names = {};
        for (const line of t.split("\n")) {
            const p = line.split("\t");
            if (p.length < 3)
                continue;
            if (p[0] === "CUR") {
                if (p[2] !== "")
                    cur[p[1]] = p[2];
            } else if (p[0] === "OPT") {
                if (!opts[p[1]])
                    opts[p[1]] = [];
                if (opts[p[1]].indexOf(p[2]) < 0)
                    opts[p[1]].push(p[2]);
            } else if (p[0] === "NAME") {
                names[p[1]] = p[2];
            }
        }
        // Turn the raw ids into {label, value} once names are known, and
        // make sure the current handler is always offered even if its
        // .desktop doesn't advertise the type.
        const built = {};
        for (const c of root.categories) {
            const ids = (opts[c.mime] || []).slice();
            if (cur[c.mime] && ids.indexOf(cur[c.mime]) < 0)
                ids.push(cur[c.mime]);
            ids.sort((a, b) =>
                (names[a] || a).localeCompare(names[b] || b));
            built[c.mime] = ids.map(id => ({ label: names[id] || id, value: id }));
        }
        root.appNames = names;
        root.current = cur;
        root.choices = built;
    }
}
