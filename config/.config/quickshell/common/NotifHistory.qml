pragma Singleton
import QtQuick
import Quickshell

// Notification history (cap 50) + unread count + center-panel state.
// Fed by NotificationPopups' server; displayed by NotificationCenter and
// the bar's NTF bell. Stores plain copies — the original notification
// objects die when dismissed/expired.
Singleton {
    id: root

    property ListModel entries: ListModel {}
    property int unread: 0
    property bool centerOpen: false

    function add(n) {
        // Quickshell serves raw notification pixmap data (the "image"
        // hint — Slack avatars, etc.) through an internal
        // image://qsimage/<id>/<serial> handle that's only valid for the
        // live Notification object's lifetime. Persisting that string in
        // history means the entry's picture starts failing to load the
        // moment the real notification expires or gets replaced — only
        // keep it if it's a real, stable reference; a themed appIcon name
        // remains resolvable indefinitely so it's always safe to keep.
        const stableImage = (n.image && !n.image.startsWith("image://")) ? n.image : "";
        entries.insert(0, {
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            image: stableImage,
            appIcon: n.appIcon || "",
            time: new Date().toLocaleTimeString(Qt.locale(), "hh:mm")
        });
        while (entries.count > 50)
            entries.remove(entries.count - 1);
        if (!centerOpen)
            unread++;
    }

    function removeAt(i) {
        entries.remove(i);
    }

    function clear() {
        entries.clear();
        unread = 0;
    }

    function toggleCenter() {
        centerOpen = !centerOpen;
    }

    onCenterOpenChanged: {
        if (centerOpen)
            unread = 0;
    }

    // Resolve a notification's image/appIcon to something Image can load
    function iconSource(image, appIcon) {
        if (image !== "")
            return image.startsWith("/") ? "file://" + image : image;
        if (appIcon !== "") {
            if (appIcon.startsWith("/"))
                return "file://" + appIcon;
            return Quickshell.iconPath(appIcon, true);
        }
        return "";
    }
}
