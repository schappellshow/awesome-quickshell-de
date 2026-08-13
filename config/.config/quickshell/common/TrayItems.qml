pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Which tray icons the bar draws.
//
// The tray shows whatever registers itself, which is not the same as what
// you want to look at all day — a mail bridge you only care about when mail
// stops arriving earns its place in the process list, not in the bar. Hiding
// one here removes the icon and nothing else: the app is untouched and still
// running, and turning it back on brings the icon straight back.
//
// Settings.trayHidden holds [{ key, name }] rather than bare keys so a hidden
// app still has a row in the settings list while it isn't running. Without
// the name, hiding something and then quitting it would leave nothing to
// click to bring it back.
Singleton {
    id: root

    // A tray item's identity, stable enough to save.
    //
    // The SNI id is the app's own name for itself and is usually stable
    // ("Proton Mail Bridge", "spotify-client"), but some apps build it out
    // of their PID — rustdesk registers "tray-icon tray app 713019-1", which
    // is a different id on every launch. A run of four or more digits is a
    // number the app made up, not part of its name, so collapsing those runs
    // keeps the key the same across restarts.
    function keyFor(item) {
        if (!item)
            return "";
        return String(item.id || item.title || "")
            .trim().toLowerCase().replace(/\d{4,}/g, "#");
    }

    // What to call it in the settings list. Chromium-based apps leave the
    // title empty and use ids like "Mailspring_status_icon_1", which is
    // machinery rather than a name — trim that back to the part a person
    // would recognise.
    //
    // Deliberately not the tooltip, which is status rather than identity:
    // Mailspring's reads "4 unread messages" and Slack's "You have unread
    // messages", so a list built from tooltips would rename itself as the
    // day went on, and a hidden app's saved name would be whatever it
    // happened to say at the moment it was hidden.
    function nameFor(item) {
        if (!item)
            return "";
        const raw = String(item.title || item.id || "").trim();
        let name = raw.replace(/[_ -]?status[_ -]?icon[_ -]?\d*$/i, "")
                      .replace(/[_-]+/g, " ")
                      .trim();
        if (name === "")
            name = raw;
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    // quickshell can't search SNI custom icon paths (apps like Spotify ship
    // "image://icon/<name>?path=<dir>") — rebuild those into direct file
    // URLs so they don't render as the missing-icon checkerboard. Lives here
    // rather than in the bar because the settings list draws the same icons.
    function fixIcon(icon) {
        const m = /^image:\/\/icon\/(.*)\?path=(.*)$/.exec(icon);
        if (m) {
            // Some apps (rustdesk) put an absolute path in the icon NAME —
            // joining it onto the dir doubles the path
            if (m[1].startsWith("/"))
                return "file://" + m[1];
            return "file://" + m[2] + "/" + m[1]
                + (m[1].includes(".") ? "" : ".png");
        }
        return icon;
    }

    // Reads Settings.trayHidden, so anything binding to this re-evaluates
    // when an icon is hidden or shown.
    function isHidden(item) {
        const key = root.keyFor(item);
        if (key === "")
            return false;
        return Settings.trayHidden.some(e => e.key === key);
    }

    function setHidden(key, name, hidden) {
        if (key === "")
            return;
        const list = Settings.trayHidden.filter(e => e.key !== key);
        if (hidden)
            list.push({ key: key, name: name });
        Settings.trayHidden = list;
    }

    function reset() {
        Settings.trayHidden = [];
    }

    // Every tray app the settings list should offer: what's in the tray now,
    // plus anything hidden that isn't running at the moment. One row per app
    // — an app that registers two items would otherwise get two identical
    // rows wired to the same key.
    readonly property var known: {
        const out = [];
        const seen = ({});

        for (const item of SystemTray.items.values) {
            const key = root.keyFor(item);
            if (key === "" || seen[key])
                continue;
            seen[key] = true;
            out.push({
                key: key,
                name: root.nameFor(item),
                // The item itself, not a copy of its icon: several apps
                // serve theirs from an in-process pixmap whose URL carries a
                // change counter ("image://qspixmap/3/113"), so a snapshot
                // taken here goes stale the next time the app redraws its
                // badge. Binding through the item keeps it live.
                item: item,
                running: true,
                hidden: root.isHidden(item)
            });
        }

        for (const entry of Settings.trayHidden) {
            if (seen[entry.key])
                continue;
            seen[entry.key] = true;
            out.push({
                key: entry.key,
                name: entry.name,
                item: null,
                running: false,
                hidden: true
            });
        }

        // Alphabetical: tray order is whatever order the apps happened to
        // start in, which is no order at all to hunt through.
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }
}
