pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Installed font families, for the pickers on the Bar settings page.
//
// Qt.fontFamilies() is the authority on what Qt can actually render, but it
// says nothing about which families are monospaced — and on this machine
// that's 248 families of which only ~53 are mono. A bar at 36px wants a
// mono face, so offer that as the default view and keep the rest behind a
// toggle.
//
// fontconfig knows the spacing (`:spacing=100` is mono), so ask it and
// intersect with Qt's list: fontconfig may know families Qt won't load, and
// listing a family the bar then can't render is worse than omitting it.
Singleton {
    id: root

    // Every family Qt can render, sorted.
    readonly property var all: {
        const f = Qt.fontFamilies();
        return f.slice().sort((a, b) => a.localeCompare(b));
    }

    // Monospaced subset. Starts as `all` so the picker is never empty on the
    // first frame, and narrows once fontconfig answers.
    property var mono: all

    // Families the user is most likely to want, first.
    function preferred() {
        return mono.length > 0 ? mono : all;
    }

    Process {
        id: monoProc
        running: true
        // charset=41 is Latin capital "A": it drops symbol and cursor fonts
        // that fontconfig calls monospaced but which render text as shapes
        // ("Cursor" was an unpickable row of glyphs). A family that cannot
        // draw an A cannot draw a bar label, so this is the honest filter
        // rather than a blocklist of names.
        command: ["sh", "-c", "fc-list ':spacing=100:charset=41' family 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                // fc-list prints comma-separated aliases per line; each
                // alias is a usable family name.
                const seen = {};
                for (const line of text.split("\n"))
                    for (const part of line.split(","))
                        if (part.trim() !== "")
                            seen[part.trim()] = true;

                const qt = {};
                for (const f of root.all)
                    qt[f] = true;

                const out = [];
                for (const name in seen)
                    if (qt[name])
                        out.push(name);

                // fontconfig missing or matching nothing Qt knows: keep the
                // full list rather than presenting an empty picker.
                if (out.length > 0)
                    root.mono = out.sort((a, b) => a.localeCompare(b));
            }
        }
    }
}
