import QtQuick
import Quickshell
import "../components"
import "../../common"

SettingsPage {
    title: "Bar"

    SectionLabel { text: "GEOMETRY" }

    CycleRow {
        label: "Position"
        value: BarEdge.label(BarEdge.edge)
        onCycle: {
            const i = BarEdge.edges.indexOf(BarEdge.edge);
            Settings.barPosition = BarEdge.edges[(i + 1) % BarEdge.edges.length];
        }
    }

    SliderRow {
        // Width on a vertical bar, height on a horizontal one — one setting
        // either way, so it's named for what it always is.
        label: "Bar thickness"
        from: 28
        to: 48
        step: 2
        suffix: "px"
        value: Settings.barWidth
        onMoved: value => Settings.barWidth = value
    }

    SliderRow {
        label: "Background opacity"
        from: 0
        to: 100
        step: 5
        suffix: "%"
        value: Settings.barOpacity
        onMoved: value => Settings.barOpacity = value
    }

    SliderRow {
        label: "Background blur"
        from: 0
        to: 100
        step: 5
        suffix: "%"
        value: Settings.barBlur
        onMoved: value => Settings.barBlur = value
    }

    CycleRow {
        label: "Bar screen"
        value: Settings.barScreen === "" ? "All screens" : Settings.barScreen
        onCycle: {
            const opts = [""].concat(Quickshell.screens.map(s => s.name));
            const i = opts.indexOf(Settings.barScreen);
            Settings.barScreen = opts[(i + 1) % opts.length];
        }
    }

    ToggleRow {
        label: "Auto-hide the bar"
        checked: Settings.barAutoHide
        onToggled: value => Settings.barAutoHide = value
    }

    Text {
        width: parent.width
        text: "The bar slides out of view and windows use its space. Move "
            + "the pointer to the screen edge to bring it back; it stays "
            + "while the pointer is on it or one of its menus is open. "
            + "Over a fullscreen window the pointer has to rest on the edge "
            + "for a moment first."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel { text: "SECTIONS" }

    Text {
        width: parent.width
        text: "The bar has three groups — "
            + BarSections.slotLabel("start").toLowerCase() + ", " + BarSections.slotLabel("center").toLowerCase() + " and "
            + BarSections.slotLabel("end").toLowerCase() + " — each drawn as "
            + "one pill. Move a section between groups with its chip, and "
            + "reorder it inside a group with the arrows."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    // One block per slot, listing that slot's sections in bar order — so
    // this list is a small picture of the bar itself.
    Repeater {
        model: BarSections.slotIds

        Column {
            id: slotBlock

            required property var modelData

            readonly property var sections:
                BarSections.layout.filter(s => s.slot === slotBlock.modelData)

            width: parent.width
            spacing: 2

            Item {
                width: parent.width
                height: 22

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: BarSections.slotLabel(slotBlock.modelData)
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pointSize: 9
                    color: Theme.subtext
                }
            }

            // An empty group is a legitimate arrangement, and saying so
            // beats an unexplained gap.
            Text {
                visible: slotBlock.sections.length === 0
                text: "empty"
                font.family: Theme.fontFamily
                font.italic: true
                font.pointSize: 9
                color: Theme.muted
            }

            Repeater {
                model: slotBlock.sections

                SectionRow {
                    required property var modelData

                    label: modelData.label
                    slotName: BarSections.slotLabel(modelData.slot)
                    shown: modelData.shown
                    canUp: BarSections.canMove(modelData.id, -1)
                    canDown: BarSections.canMove(modelData.id, 1)

                    onToggled: value => BarSections.setShown(modelData.id, value)
                    onMoved: delta => BarSections.move(modelData.id, delta)
                    onSlotCycled: BarSections.cycleSlot(modelData.id)
                }
            }
        }
    }

    ButtonRow {
        label: "Restore the default arrangement"
        buttonText: "Reset"
        onClicked: BarSections.reset()
    }

    SectionLabel { text: "SYSTEM TRAY" }

    Text {
        width: parent.width
        text: "Everything in the tray right now, plus anything you've "
            + "hidden. Turning one off only removes its icon — the app keeps "
            + "running exactly as it was, and the icon returns the moment "
            + "you turn it back on."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    Text {
        visible: TrayItems.known.length === 0
        text: "Nothing in the tray at the moment."
        font.family: Theme.fontFamily
        font.italic: true
        font.pointSize: 9
        color: Theme.muted
    }

    Repeater {
        model: TrayItems.known

        TrayRow {
            required property var modelData

            label: modelData.name
            iconSource: modelData.item
                ? TrayItems.fixIcon(modelData.item.icon) : ""
            running: modelData.running
            shown: !modelData.hidden

            onToggled: value =>
                TrayItems.setHidden(modelData.key, modelData.name, !value)
        }
    }

    ButtonRow {
        // Only worth offering when something is actually hidden — otherwise
        // it's a button that does nothing, sitting under a list of things
        // that are all already on.
        visible: Settings.trayHidden.length > 0
        label: "Show every tray icon again"
        buttonText: "Reset"
        onClicked: TrayItems.reset()
    }

    SectionLabel { text: "SYSTEM MONITOR" }

    CycleRow {
        label: "CPU/RAM readout"
        value: Settings.sysmonMode === "always" ? "Always" : "Only when busy"
        onCycle: Settings.sysmonMode =
            Settings.sysmonMode === "always" ? "busy" : "always"
    }

    SliderRow {
        visible: Settings.sysmonMode !== "always"
        label: "CPU busy above"
        from: 50
        to: 100
        step: 5
        suffix: "%"
        value: Settings.sysmonCpuThreshold
        onMoved: value => Settings.sysmonCpuThreshold = value
    }

    SliderRow {
        visible: Settings.sysmonMode !== "always"
        label: "RAM busy above"
        from: 50
        to: 100
        step: 5
        suffix: "%"
        value: Settings.sysmonRamThreshold
        onMoved: value => Settings.sysmonRamThreshold = value
    }

    Text {
        visible: Settings.sysmonMode !== "always"
        width: parent.width
        text: "Each figure appears when it stays above its limit for about "
            + "five seconds, and goes away once it has stayed 15 points "
            + "below it for ten. Super+Shift+M still opens the dashboard "
            + "while the readout is hidden."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    CycleRow {
        label: "Dashboard"
        value: Settings.sysmonDashboard === "conky" ? "Conky" : "Quickshell"
        onCycle: Settings.sysmonDashboard =
            Settings.sysmonDashboard === "conky" ? "native" : "conky"
    }

    CycleRow {
        visible: Settings.sysmonDashboard !== "conky"
        label: "Display"
        value: Settings.dashboardMode === "pinned" ? "Pinned on desktop" : "Popout"
        onCycle: Settings.dashboardMode =
            Settings.dashboardMode === "pinned" ? "popout" : "pinned"
    }

    CycleRow {
        visible: Settings.sysmonDashboard !== "conky"
        label: "Position"
        value: DashboardState.positionLabel(DashboardState.position)
        onCycle: {
            const ids = DashboardState.positionIds;
            Settings.dashboardPosition =
                ids[(ids.indexOf(DashboardState.position) + 1) % ids.length];
        }
    }

    SliderRow {
        visible: Settings.sysmonDashboard !== "conky"
        label: "Dashboard opacity"
        from: 40
        to: 100
        step: 5
        suffix: "%"
        value: Math.round(DashboardState.bgAlpha * 100)
        onMoved: value => Settings.dashboardOpacity = value
    }

    ToggleRow {
        visible: Settings.sysmonDashboard !== "conky"
        label: "Blur behind the dashboard"
        checked: Settings.dashboardBlur
        onToggled: value => Settings.dashboardBlur = value
    }

    // One row per card, in dashboard order: show/hide and move up/down
    Repeater {
        model: Settings.sysmonDashboard !== "conky" ? DashboardState.order : []
        Item {
            id: cardRow
            required property string modelData
            required property int index
            width: parent ? parent.width : 0
            height: 28

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: DashboardState.cardTitle(cardRow.modelData) + " card"
                font.family: Theme.fontFamily
                font.pointSize: 10
                color: DashboardState.cardEnabled(cardRow.modelData) ? Theme.text : Theme.muted
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: [
                        { t: DashboardState.cardEnabled(cardRow.modelData) ? "Shown" : "Hidden", k: "toggle" },
                        { t: "\u25B2", k: "up" },
                        { t: "\u25BC", k: "down" }
                    ]
                    Rectangle {
                        id: pill
                        required property var modelData
                        width: pillText.implicitWidth + 20
                        height: 24
                        radius: 12
                        color: pillHover.hovered ? Theme.surfaceAlt : Theme.surface
                        opacity: (modelData.k === "up" && cardRow.index === 0)
                              || (modelData.k === "down"
                                  && cardRow.index === DashboardState.order.length - 1) ? 0.4 : 1
                        Text {
                            id: pillText
                            anchors.centerIn: parent
                            text: pill.modelData.t
                            font.family: Theme.fontFamily
                            font.pointSize: 9
                            color: pill.modelData.k === "toggle"
                                   && DashboardState.cardEnabled(cardRow.modelData)
                                   ? Theme.accentBright : Theme.text
                        }
                        HoverHandler { id: pillHover }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (pill.modelData.k === "toggle")
                                    DashboardState.setCardEnabled(cardRow.modelData,
                                        !DashboardState.cardEnabled(cardRow.modelData));
                                else
                                    DashboardState.moveCard(cardRow.modelData,
                                        pill.modelData.k === "up" ? -1 : 1);
                            }
                        }
                    }
                }
            }
        }
    }

    TextFieldRow {
        visible: Settings.sysmonDashboard === "conky"
        label: "Conky config for the popout (Enter to apply)"
        text: Settings.conkyConfig
        placeholder: "~/.conky/my.conkyrc (optional)"
        onAccepted: value => {
            if (value !== "")
                Settings.conkyConfig = value;
        }
    }

    Text {
        width: parent.width
        text: Settings.sysmonDashboard === "conky"
            ? "Click the CPU/RAM pill (or Super+Shift+M) to toggle the "
              + "conky dashboard — it pops out beside the bar, above your "
              + "windows, and toggles away again. Right-click opens htop."
            : Settings.dashboardMode === "pinned"
            ? "Pinned: the dashboard stays on the desktop beside the bar, "
              + "under your windows, and keeps sampling while it is there. "
              + "The CPU/RAM pill (or Super+Shift+M) lifts it above the "
              + "windows; press again to put it back. Right-click opens htop."
            : "Click the CPU/RAM pill (or Super+Shift+M) to toggle the "
              + "dashboard — it pops out beside the bar, above your "
              + "windows, and only samples while it is open. Right-click "
              + "opens htop."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
    SectionLabel { text: "FONTS" }

    FontRow {
        label: "Section labels"
        sample: "NGT  VOL  NET  CPU"
        current: Settings.fontLabels
        onSelected: family => Settings.fontLabels = family
    }

    FontRow {
        label: "Clock"
        sample: "07 48 AM"
        current: Settings.fontClock
        onSelected: family => Settings.fontClock = family
    }

    FontRow {
        label: "App names"
        sample: "Firefox  Ghostty  Slack"
        current: Settings.fontApps
        onSelected: family => Settings.fontApps = family
    }

    Text {
        width: parent.width
        text: "Icon glyphs always use the Nerd Font — that's glyph coverage, "
            + "not styling, and changing it would turn every bar icon into a "
            + "box. App names apply once the Apps section exists."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
