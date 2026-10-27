pragma ComponentBehavior: Bound
import QtQuick
import "../components"
import "../../common"
import "../../common/DisplayLayout.js" as Layout

SettingsPage {
    id: page

    title: "Displays"

    // Pending edits never affect X until Apply, nor disk until Keep.
    property var chosen: ({})
    readonly property var rects: Layout.layout(DisplayConfig.outputs, chosen)
    readonly property string validation: Layout.validate(rects)
    property bool draggingMonitor: false
    property var frozenBounds: ({ x: 0, y: 0, width: 1, height: 1 })
    interactive: !draggingMonitor

    Component.onCompleted: DisplayConfig.probe()
    Connections {
        target: DisplayConfig
        function onApplied() { page.chosen = ({}); }
    }

    function rect(name) {
        return rects.find(r => r.name === name);
    }

    function setChosen(name, patch) {
        const c = {};
        for (const k in chosen)
            c[k] = chosen[k];
        c[name] = Object.assign({}, c[name] || {}, patch);
        chosen = c;
    }
    function position(name, axis, value) {
        if (!/^-?\d+$/.test(value.trim()))
            return;
        const patch = {};
        patch[axis] = Number(value);
        setChosen(name, patch);
    }
    Text {
        width: parent.width
        text: "Drag the screens to match your desk. Edges and centres snap "
            + "into alignment. Changes take effect only after Apply; choose "
            + "Keep within 20 seconds or the previous layout returns."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 9
        color: Theme.subtext
    }

    // Confirmation stays above the controls; its timer lives in DisplayConfig
    // so closing Settings or changing pages still rolls the layout back.
    Column {
        width: parent.width
        spacing: 8
        visible: DisplayConfig.confirming

        Text {
            text: "Keep this layout? Reverting in " + DisplayConfig.secondsLeft + "s"
            color: Theme.orange
            font.family: Theme.fontFamily
            font.bold: true
        }
        ButtonRow {
            label: "Use and save this arrangement"
            buttonText: "Keep"
            onClicked: DisplayConfig.keep()
        }
        ButtonRow {
            label: "Return to the previous arrangement"
            buttonText: "Revert"
            onClicked: DisplayConfig.revert()
        }
    }

    Text {
        width: parent.width
        visible: text !== ""
        text: DisplayConfig.error || DisplayConfig.status
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 9
        color: DisplayConfig.error !== "" ? Theme.red : Theme.subtext
    }

    Rectangle {
        id: canvas
        objectName: "monitorCanvas"
        width: parent.width
        height: 290
        radius: 10
        color: Theme.surfaceAlt
        clip: true
        enabled: !DisplayConfig.applying && !DisplayConfig.probing

        readonly property var view: page.draggingMonitor
            ? page.frozenBounds : Layout.bounds(page.rects)
        // Spare space permits dragging a monitor past the current left/top.
        readonly property real previewScale: Math.max(0.005,
            Math.min((width - 40) / (view.width + 1600),
                     (height - 40) / (view.height + 1000)))
        readonly property real originX: (width - view.width * previewScale) / 2
            - view.x * previewScale
        readonly property real originY: (height - view.height * previewScale) / 2
            - view.y * previewScale

        Repeater {
            model: DisplayConfig.outputs.filter(o => o.enabled)

            Rectangle {
                id: monitor
                required property var modelData
                objectName: "monitor-" + modelData.name
                readonly property var geometry: page.rect(modelData.name)
                x: canvas.originX + (geometry ? geometry.x : 0) * canvas.previewScale
                y: canvas.originY + (geometry ? geometry.y : 0) * canvas.previewScale
                width: geometry ? geometry.width * canvas.previewScale : 0
                height: geometry ? geometry.height * canvas.previewScale : 0
                radius: 5
                color: hover.hovered ? Theme.surface : Theme.base
                border.width: 2
                border.color: geometry && geometry.primary ? Theme.accent : Theme.muted
                z: dragArea.pressed ? 2 : 1

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    spacing: 4

                    Text {
                        width: parent.width
                        text: monitor.modelData.name
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.text
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: monitor.geometry && monitor.geometry.primary ? "PRIMARY" : ""
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.accent
                    }
                }

                HoverHandler { id: hover }
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    preventStealing: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property real startX
                    property real startY
                    property real pointerX
                    property real pointerY
                    onPressed: mouse => {
                        page.frozenBounds = Layout.bounds(page.rects);
                        page.draggingMonitor = true;
                        startX = monitor.geometry.x;
                        startY = monitor.geometry.y;
                        const p = mapToItem(canvas, mouse.x, mouse.y);
                        pointerX = p.x;
                        pointerY = p.y;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return;
                        const p = mapToItem(canvas, mouse.x, mouse.y);
                        const moved = Object.assign({}, monitor.geometry, {
                            x: startX + (p.x - pointerX) / canvas.previewScale,
                            y: startY + (p.y - pointerY) / canvas.previewScale
                        });
                        page.setChosen(monitor.modelData.name,
                            Layout.snap(moved, page.rects, 10 / canvas.previewScale));
                    }
                    onReleased: page.draggingMonitor = false
                    onCanceled: page.draggingMonitor = false
                }
            }
        }
    }

    Text {
        width: parent.width
        text: page.validation
        visible: text !== "" && !DisplayConfig.confirming
        wrapMode: Text.Wrap
        color: Theme.orange
        font.family: Theme.fontFamily
        font.pointSize: 9
    }

    ButtonRow {
        label: DisplayConfig.applying ? "Applying display changes…"
            : "Test the pending arrangement"
        buttonText: "Apply"
        enabled: !DisplayConfig.applying && !DisplayConfig.probing
            && page.validation === ""
        opacity: enabled ? 1 : 0.5
        onClicked: DisplayConfig.apply(page.chosen)
    }

    ButtonRow {
        label: "Discard pending edits and read current positions"
        buttonText: "Refresh / Reset"
        enabled: !DisplayConfig.applying && !DisplayConfig.probing
        onClicked: {
            page.chosen = ({});
            DisplayConfig.probe();
        }
    }

    function setPrimary(name) {
        const c = {};
        for (const o of DisplayConfig.outputs)
            c[o.name] = Object.assign({}, chosen[o.name] || {},
                { primary: o.name === name });
        chosen = c;
    }

    Repeater {
        model: DisplayConfig.outputs.filter(o => o.enabled)

        Column {
            id: outCol

            required property var modelData

            width: parent.width
            spacing: 10
            enabled: !DisplayConfig.applying && !DisplayConfig.probing

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

            TextFieldRow {
                label: "Horizontal position (pixels; Enter to set)"
                text: String(page.rect(outCol.modelData.name).x)
                onAccepted: value => page.position(outCol.modelData.name, "x", value)
            }

            TextFieldRow {
                label: "Vertical position (pixels; Enter to set)"
                text: String(page.rect(outCol.modelData.name).y)
                onAccepted: value => page.position(outCol.modelData.name, "y", value)
            }
        }
    }


    Text {
        width: parent.width
        text: "Negative coordinates are allowed while arranging. Apply shifts "
            + "the whole layout to start at 0,0 without changing the relative "
            + "positions. Disabled displays are left disabled."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
