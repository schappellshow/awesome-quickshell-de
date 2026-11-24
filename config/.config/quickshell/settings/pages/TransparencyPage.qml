import QtQuick
import "../components"
import "../../common"

// Transparency & blur: how see-through the desktop is, in one place.
//
// The picom values (blur, menus and tooltips, inactive windows) restart the
// compositor when they change, so they are applied once the control has been
// still for a moment, never per tick (common/PerformanceMode.qml). Everything
// else follows at once. Every default is the look the desktop shipped with.
SettingsPage {
    id: page

    title: "Transparency & blur"

    SectionLabel { text: "BLUR" }

    ToggleRow {
        label: "Blur behind windows"
        checked: Settings.blurEnabled
        onToggled: value => Settings.blurEnabled = value
    }

    SliderRow {
        visible: Settings.blurEnabled
        label: "Blur strength"
        from: 1; to: 10; step: 1
        value: Settings.blurStrength
        onMoved: v => Settings.blurStrength = v
    }

    HintText {
        text: Settings.blurEnabled
            ? "Blur applies to menus, tooltips, the dashboard and the ring, "
              + "and to windows that are see-through. Changes apply when you "
              + "let go; the screen flickers briefly as the compositor restarts."
            : "Blur is off everywhere. Surfaces that are see-through show the "
              + "windows behind them unblurred."
    }

    HintText {
        visible: PerformanceMode.active
        text: "Performance mode is on, which turns blur off whatever is set here."
        color: Theme.accentBright
    }

    SectionLabel { text: "WINDOWS" }

    SliderRow {
        label: "Inactive window opacity"
        from: 50; to: 100; step: 1; suffix: "%"
        value: Settings.inactiveOpacity
        onMoved: v => Settings.inactiveOpacity = v
    }

    HintText {
        text: "Windows without focus fade to this. 100% turns it off. "
            + "Performance mode ignores it."
    }

    SectionLabel { text: "MENUS" }

    SliderRow {
        label: "App menus, dropdowns and tooltips"
        from: 50; to: 100; step: 1; suffix: "%"
        value: Settings.popupOpacity
        onMoved: v => Settings.popupOpacity = v
    }

    HintText {
        text: "The menus, lists and tooltips programs open. The whole window "
            + "gets this opacity, text included, so very low values are hard "
            + "to read."
    }

    SliderRow {
        label: "Desktop and start menu"
        from: 20; to: 100; step: 1; suffix: "%"
        value: Settings.menuOpacity
        onMoved: v => Settings.menuOpacity = v
    }

    HintText {
        text: "The right-click menu on the desktop and the start button's "
            + "menu. Only the background fades; text stays solid. This is "
            + "how opaque the menu looks, not the layer value in the theme "
            + "(the menu is painted in two layers). Applies when you let go; "
            + "an open menu closes."
    }

    SectionLabel { text: "SHELL POPUPS" }

    SliderRow {
        label: "Dashboard opacity"
        from: 40; to: 100; step: 1; suffix: "%"
        value: Settings.dashboardOpacity
        onMoved: v => Settings.dashboardOpacity = v
    }

    ToggleRow {
        label: "Dashboard blur"
        checked: Settings.dashboardBlur
        onToggled: value => Settings.dashboardBlur = value
    }

    SliderRow {
        label: "Quick-actions ring opacity"
        from: 30; to: 100; step: 1; suffix: "%"
        value: Settings.ringOpacity
        onMoved: v => Settings.ringOpacity = v
    }

    ToggleRow {
        label: "Quick-actions ring blur"
        checked: Settings.ringBlur
        onToggled: value => Settings.ringBlur = value
    }

    HintText {
        text: "These are the same settings as the gear in the dashboard. "
            + "Without blur, the ring keeps at least 74% so it stays readable."
    }

    SectionLabel { text: "RESET" }

    ButtonRow {
        label: "Back to the defaults for this page"
        buttonText: "Reset to defaults"
        onClicked: Settings.resetTransparency()
    }
}
