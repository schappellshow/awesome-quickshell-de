pragma Singleton
import QtQuick
import Quickshell

// The pinned launcher strip's model.
//
// Stored as desktop entry ids in Settings.pinnedApps, resolved through
// AppLookup so a window pinned from the bar and an app chosen in Settings
// end up as the same string — otherwise unpinning silently fails to match.
Singleton {
    id: root

    readonly property var ids: Settings.pinnedApps || []

    function isPinned(id) {
        return root.ids.includes(id);
    }

    function pin(id) {
        if (id === "" || root.isPinned(id))
            return;
        // Reassign rather than push: a JsonAdapter list property only
        // persists when the property itself changes, and mutating the array
        // in place does not count as a change.
        Settings.pinnedApps = root.ids.concat([id]);
    }

    function unpin(id) {
        Settings.pinnedApps = root.ids.filter(x => x !== id);
    }

    function toggle(id) {
        if (root.isPinned(id))
            root.unpin(id);
        else
            root.pin(id);
    }

    // Right-click on a running window. Resolves through the same path the
    // Settings list uses, so the two agree on the stored id.
    function pinFromWindow(client) {
        if (!client)
            return;
        const id = AppLookup.idFor([client.class || "", client.instance || ""]);
        root.toggle(id);
    }

    function move(from, to) {
        if (from === to || from < 0 || to < 0
                || from >= root.ids.length || to >= root.ids.length)
            return;
        const next = root.ids.slice();
        next.splice(to, 0, next.splice(from, 1)[0]);
        Settings.pinnedApps = next;
    }
}
