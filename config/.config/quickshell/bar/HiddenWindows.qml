import QtQuick
import Quickshell
import "../common"

// Minimized windows on the tag(s) this screen is currently viewing.
//
// The inverse of a tasklist: it deliberately does NOT show running windows,
// because the tiling layout already does. It shows only what the layout
// can't — the windows you hid and would otherwise have no trace of. So it
// is empty, and takes no space, in the normal case.
//
// Click an icon to restore that specific window (awesome's Super+Ctrl+N can
// only pop the most recently minimized one).
Column {
    id: root

    property var awScreen

    readonly property var items: root.awScreen ? (root.awScreen.hidden || []) : []

    spacing: 4
    visible: root.items.length > 0

    Repeater {
        model: root.items

        delegate: Rectangle {
            id: entry

            required property var modelData

            // Resolve WM_CLASS -> desktop entry -> icon. Neither half of
            // WM_CLASS reliably equals the desktop file id: awesome reports
            // "Helium"/"helium" and "dev.zed.Zed"/"dev.zed.Zed", so case
            // can't be normalised away (lowercasing breaks dev.zed.Zed) and
            // both halves have to be tried. heuristicLookup goes first
            // because it also matches on StartupWMClass and entry name.
            readonly property string appClass: modelData.class || ""
            readonly property string appInstance: modelData.instance || ""
            readonly property var candidates:
                [entry.appClass, entry.appInstance].filter(n => n !== "")

            readonly property var entryMatch: {
                for (const n of entry.candidates) {
                    // Lookups throw rather than return null on some
                    // quickshell builds; a missing icon must not take the
                    // whole binding down with it.
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

            // iconPath(name, true) checks the theme and returns "" when the
            // name resolves to nothing, so each step can be tested in turn.
            readonly property string iconSource: {
                const declared = entry.entryMatch ? (entry.entryMatch.icon || "") : "";
                // A desktop entry may declare an absolute path rather than a
                // theme icon name, and iconPath() only resolves names. Slack,
                // Zed and Helium all ship paths, so this is the common case
                // here, not an edge case. (Helium's file has no extension;
                // Qt sniffs the format from content.)
                if (declared.startsWith("/"))
                    return "file://" + declared;
                if (declared !== "") {
                    const p = Quickshell.iconPath(declared, true);
                    if (p !== "")
                        return p;
                }
                for (const n of entry.candidates) {
                    const p = Quickshell.iconPath(n.toLowerCase(), true);
                    if (p !== "")
                        return p;
                }
                return "";
            }

            width: 24
            height: 24
            radius: 6
            anchors.horizontalCenter: parent.horizontalCenter
            // Dimmed at rest: these windows are hidden, and shouldn't pull
            // attention the way the taglist or an urgent tag does.
            color: hover.hovered ? Theme.surface : "transparent"
            opacity: hover.hovered ? 1.0 : 0.75

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            Image {
                id: icon
                anchors.centerIn: parent
                width: 18
                height: 18
                source: entry.iconSource
                sourceSize.width: 36
                sourceSize.height: 36
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: status === Image.Ready
            }

            // Degraded fallback when nothing resolved: the class initial.
            Text {
                anchors.centerIn: parent
                visible: icon.status !== Image.Ready
                text: entry.candidates.length === 0
                    ? "?" : entry.candidates[0].charAt(0).toUpperCase()
                font.family: Theme.fontFamily
                font.bold: true
                font.pointSize: 9
                color: Theme.subtext
            }

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                onClicked: AwesomeState.restoreClient(entry.modelData.id)
            }
        }
    }
}
