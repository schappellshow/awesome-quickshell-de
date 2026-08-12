pragma Singleton
import QtQuick
import Quickshell

// Which edge the bar is on, and everything that follows from it.
//
// Four things have to agree about the bar's edge — the bar itself, the
// popups that hang off it, the conky popout, and awesome's screen padding —
// so the reading of the setting and the placement maths live here rather
// than being re-derived in each of them.
Singleton {
    id: root

    readonly property var edges: ["left", "right", "top", "bottom"]

    // A settings.json written by hand, or by a newer version, can say
    // anything; fall back to the shipped edge rather than to a bar with no
    // anchors at all.
    readonly property string edge: root.edges.includes(Settings.barPosition)
        ? Settings.barPosition : "left"

    readonly property bool vertical: root.edge === "left" || root.edge === "right"

    // Gap between the bar's inner edge and a popup hanging off it.
    readonly property int gap: 6

    function label(which) {
        switch (which) {
        case "left":   return "Left";
        case "right":  return "Right";
        case "top":    return "Top";
        default:       return "Bottom";
        }
    }

    // Keep a popup on screen: `v` is its preferred offset along the bar,
    // `size` its length in that direction, `span` the screen's. Clamping to
    // at least 8 rather than to `span - size - 8` last means a popup taller
    // than the screen still starts at the top instead of off it.
    function clamp(v, size, span) {
        return Math.max(8, Math.min(v, span - size - 8));
    }

    // Popup placement, in the bar window's coordinates. Off the bar's inner
    // edge (negative when the bar is on the right or bottom, so the popup
    // sits back towards the screen) and centred on whatever opened it.
    function popupX(barWindow, anchorItem, w) {
        if (!barWindow)
            return 42;
        if (root.edge === "left")
            return barWindow.width + root.gap;
        if (root.edge === "right")
            return -(w + root.gap);
        const cx = anchorItem
            ? anchorItem.mapToItem(null, anchorItem.width / 2, 0).x
            : barWindow.width / 2;
        return root.clamp(cx - w / 2, w, barWindow.width);
    }

    function popupY(barWindow, anchorItem, h) {
        if (!barWindow)
            return 100;
        if (root.edge === "top")
            return barWindow.height + root.gap;
        if (root.edge === "bottom")
            return -(h + root.gap);
        const cy = anchorItem
            ? anchorItem.mapToItem(null, 0, anchorItem.height / 2).y
            : barWindow.height / 2;
        return root.clamp(cy - h / 2, h, barWindow.height);
    }
}
