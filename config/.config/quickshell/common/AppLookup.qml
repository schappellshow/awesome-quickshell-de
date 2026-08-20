pragma Singleton
import QtQuick
import Quickshell

// WM_CLASS / desktop-entry-id resolution, in one place.
//
// Three consumers need this and they need it to agree: the hidden-window
// list, the visible-window list and the pinned launchers. A window pinned
// from the bar has to resolve to the same entry the Settings list would
// have offered, or unpinning it later silently fails to match.
//
// Kept as functions rather than folded into AppIcon.qml because pinning
// needs the ID without drawing anything.
Singleton {
    id: root

    // Names to try, best first. Neither half of WM_CLASS reliably equals the
    // desktop file id: awesome reports "Helium"/"helium" and
    // "dev.zed.Zed"/"dev.zed.Zed", so case cannot be normalised away
    // (lowercasing breaks dev.zed.Zed) and both halves have to be tried.
    //
    // Reverse-DNS classes are common and almost never match an icon name
    // whole: TeamViewer reports "com.teamviewer.TeamViewer", whose icon is
    // plain "teamviewer". So each name also contributes its last dotted
    // segment.
    function candidates(names) {
        const out = [];
        for (const n of names) {
            if (!n || n === "")
                continue;
            if (!out.includes(n))
                out.push(n);
            const tail = n.split(".").pop();
            if (tail !== "" && !out.includes(tail))
                out.push(tail);
        }
        return out;
    }

    // First desktop entry matching any candidate, or null.
    // heuristicLookup goes first because it also matches on StartupWMClass
    // and the entry's display name.
    function entryFor(names) {
        for (const n of root.candidates(names)) {
            // Lookups throw rather than return null on some quickshell
            // builds; a miss must not take the caller's binding down.
            try {
                const hit = DesktopEntries.heuristicLookup(n);
                if (hit)
                    return hit;
            } catch (e) {}
            try {
                const hit = DesktopEntries.byId(n);
                if (hit)
                    return hit;
            } catch (e) {}
        }
        return null;
    }

    // Stable identifier to persist for a pinned app. Prefer the desktop
    // entry's own id; fall back to the raw class so a window whose entry we
    // cannot find is still pinnable (it just resolves by class next time).
    function idFor(names) {
        const e = root.entryFor(names);
        if (e && e.id)
            return e.id;
        for (const n of names)
            if (n && n !== "")
                return n;
        return "";
    }

    // Icon source URL, or "" when nothing resolves.
    function iconFor(names) {
        const e = root.entryFor(names);
        const declared = e ? (e.icon || "") : "";
        // A desktop entry may declare an absolute path rather than a theme
        // icon name, and iconPath() only resolves names. Slack, Zed and
        // Helium all ship paths, so this is the common case, not an edge
        // case. (Helium's file has no extension; Qt sniffs the format.)
        if (declared.startsWith("/"))
            return "file://" + declared;
        if (declared !== "") {
            const p = Quickshell.iconPath(declared, true);
            if (p !== "")
                return p;
        }
        for (const n of root.candidates(names)) {
            const p = Quickshell.iconPath(n.toLowerCase(), true);
            if (p !== "")
                return p;
        }
        return "";
    }

    // Human-readable name, for tooltips and the Settings list.
    function nameFor(names) {
        const e = root.entryFor(names);
        if (e && e.name)
            return e.name;
        for (const n of names)
            if (n && n !== "")
                return n.split(".").pop();
        return "";
    }

    // Every launchable application, sorted by name, with its icon already
    // resolved. Shared by the Settings pin picker and the launcher so both
    // show the same list — and resolved ONCE here rather than per row,
    // because both filter as you type and would otherwise re-run ~90 theme
    // lookups per keystroke.
    //
    // noDisplay entries are the ones a menu is meant to hide (mime handlers,
    // settings panels), so they are dropped.
    readonly property var applications: {
        const out = [];
        try {
            for (const e of DesktopEntries.applications.values) {
                if (!e || e.noDisplay)
                    continue;
                const declared = e.icon || "";
                let src = "";
                if (declared.startsWith("/"))
                    src = "file://" + declared;
                else if (declared !== "")
                    src = Quickshell.iconPath(declared, true);
                out.push({ id: e.id, name: e.name || e.id, icon: src });
            }
        } catch (err) {}
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }

    // Name or id substring match. Case-insensitive; empty query means all.
    function search(query) {
        const q = (query || "").trim().toLowerCase();
        if (q === "")
            return root.applications;
        return root.applications.filter(a => a.name.toLowerCase().includes(q)
                                          || a.id.toLowerCase().includes(q));
    }

    function launch(entryId) {
        const e = root.entryFor([entryId]);
        if (e) {
            try {
                e.execute();
                return true;
            } catch (err) {}
        }
        return false;
    }
}
