import QtQuick
import "../components"
import "../../common"

// v1: per-output mode + primary; positions are kept as-is. Applied via
// xrandr and replayed at every login from Settings.displayCmd.
SettingsPage {
    id: page

    title: "Displays"

    // outputName → { mode, primary } (pending, until Apply)
    property var chosen: ({})

    Component.onCompleted: DisplayConfig.probe()

    function setChosen(name, patch) {
        const c = {};
        for (const k in chosen)
            c[k] = chosen[k];
        c[name] = Object.assign({}, c[name] || {}, patch);
        chosen = c;
    }

    function setPrimary(name) {
        const c = {};
        for (const o of DisplayConfig.outputs)
            c[o.name] = Object.assign({}, chosen[o.name] || {},
                { primary: o.name === name });
        chosen = c;
    }

    Repeater {
        model: DisplayConfig.outputs

        Column {
            id: outCol

            required property var modelData

            width: parent.width
            spacing: 10

            SectionLabel { text: outCol.modelData.name.toUpperCase() }

            ComboRow {
                label: "Resolution"
                options: outCol.modelData.modes
                current: (page.chosen[outCol.modelData.name] || {}).mode
                    || outCol.modelData.currentMode
                onSelected: value =>
                    page.setChosen(outCol.modelData.name, { mode: value })
            }

            ComboRow {
                label: "Rotation"
                options: [
                    { label: "Landscape", value: "normal" },
                    { label: "Portrait (left)", value: "left" },
                    { label: "Portrait (right)", value: "right" },
                    { label: "Upside down", value: "inverted" }
                ]
                current: (page.chosen[outCol.modelData.name] || {}).rotate
                    || outCol.modelData.rotation
                onSelected: value =>
                    page.setChosen(outCol.modelData.name, { rotate: value })
            }

            ToggleRow {
                label: "Primary display"
                checked: (page.chosen[outCol.modelData.name] || {}).primary
                    !== undefined
                    ? page.chosen[outCol.modelData.name].primary
                    : outCol.modelData.primary
                onToggled: value => {
                    if (value)
                        page.setPrimary(outCol.modelData.name);
                }
            }

            InfoRow {
                label: "Position"
                value: outCol.modelData.x + ", " + outCol.modelData.y
            }
        }
    }

    ButtonRow {
        label: "Apply and save layout"
        buttonText: "Apply"
        onClicked: {
            DisplayConfig.apply(page.chosen);
            page.chosen = ({});
        }
    }

    Text {
        width: parent.width
        text: "Position arranging isn't managed yet — use arandr for complex "
            + "layouts, then Apply here to re-read and persist modes."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
