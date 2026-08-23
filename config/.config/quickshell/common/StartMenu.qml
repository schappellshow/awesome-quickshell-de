pragma Singleton
import QtQuick
import Quickshell

// Where the start menu opens.
//
// awesome owns the menu itself — modules/keys.lua defines its items and
// theme.lua styles it — so both routes end in awesome-client. The only
// difference is the coordinates:
//
//   "mouse"   awesome places it at the pointer, as a desktop right-click does
//   "button"  the bar tells awesome where it drew the start button
//
// Anchoring has to come from the shell: awesome has no idea where quickshell
// drew anything, and the button moves whenever the bar's sections are
// rearranged. Nothing is cached for that reason — the position is read when
// the menu is asked for.
Singleton {
    id: root

    // Every start button currently drawn, in creation order.
    //
    // A list rather than "the" button, because quickshell builds a bar for
    // each screen and then trims back to the one the bar is configured for:
    // the last button to register is routinely one of the ones about to be
    // destroyed, and holding only that reference left the anchor null and the
    // menu quietly back at the pointer.
    property var buttons: []

    // Called by bar/StartButton.qml as it comes and goes.
    function register(item, window) {
        root.buttons.push({ item: item, window: window });
    }

    function unregister(item) {
        root.buttons = root.buttons.filter(e => e.item !== item);
    }

    // Where the menu should sit, relative to the origin of the button's
    // screen: `inner` is the bar's inner edge with the popup gap added,
    // `along` how far down (or across) the bar the button is. Same placement
    // the bar's own popups use, so the menu lines up with them.
    //
    // Null when there is no button to point at, which sends the caller back
    // to pointer placement rather than to a guess.
    function anchor() {
        // A destroyed item reads back as null even where unregister was
        // missed, so both halves are checked rather than trusted.
        const live = root.buttons.find(
            e => e.item && e.window && e.item.visible);
        if (!live)
            return null;
        const item = live.item;
        const win = live.window;
        const p = item.mapToItem(null, 0, 0);
        const edge = BarEdge.edge;
        const thick = BarEdge.vertical ? win.width : win.height;
        const span = BarEdge.vertical ? win.screen.width : win.screen.height;
        // Far-edge bars measure back from the other side of the screen; the
        // menu grows towards it, which awesome finishes off once it knows how
        // big the menu is.
        const inner = (edge === "left" || edge === "top")
            ? thick + BarEdge.gap
            : span - thick - BarEdge.gap;
        const along = BarEdge.vertical ? p.y : p.x;
        return {
            inner: Math.round(inner),
            along: Math.round(along),
            edge: edge,
            // Which monitor the bar is on, or "" when every monitor has one.
            // Same resolution BarSpace uses for awesome's padding: a name that
            // matches no connected output means bars everywhere.
            output: Quickshell.screens.some(s => s.name === Settings.barScreen)
                ? Settings.barScreen : ""
        };
    }

    function toggle() {
        const at = Settings.startMenuPlacement === "button" ? root.anchor() : null;
        if (!at) {
            AwesomeState.exec("main_menu_toggle()");
            return;
        }
        // Guarded the way WindowBorders guards set_border: an awesome that
        // has not been reloaded since this shipped has no main_menu_toggle_at,
        // and falling back to the pointer beats opening nothing at all.
        AwesomeState.exec(
            `if main_menu_toggle_at then main_menu_toggle_at(${at.inner}, `
            + `${at.along}, "${at.edge}", "${at.output}") `
            + `else main_menu_toggle() end`);
    }
}
