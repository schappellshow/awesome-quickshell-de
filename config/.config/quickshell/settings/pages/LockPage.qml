import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../../common"

// Lock screen. Unlike every other page here, nothing on it is rendered by
// quickshell: the lock screen is i3lock-color, driven by bin/.local/bin/
// lock-screen, over a background baked by bin/.local/bin/lock-image. Both
// read these settings from settings.json at lock time.
//
// That split decides how this page behaves. Text, fonts and ring geometry are
// i3lock ARGUMENTS, so they apply to the next lock with no work. The panel and
// the background are pixels in a cached PNG, so changing them means
// regenerating that cache — which is why those live in their own section and
// kick off a rebuild.
SettingsPage {
    id: page
    title: "Lock Screen"

    // ── Layout arithmetic ───────────────────────────────────────────────────
    // Mirrors the derivation in lock-screen so the preview shows where things
    // actually land. If you change the formulas there, change them here too —
    // the script is the authority, this only has to agree with it.
    readonly property int ringMargin: 30
    readonly property int textInset: 20

    readonly property int ringX: Settings.lockPanelX + Settings.lockPanelWidth
                                 - Settings.lockRingRadius - page.ringMargin
    readonly property int ringY: Settings.lockPanelY - Settings.lockPanelHeight / 2

    readonly property int ascLg: Math.floor(Settings.lockClockSize * 72 / 100)
    readonly property int ascMd: Math.floor(Settings.lockTextSize * 75 / 100)
    readonly property int gap: Math.floor(Settings.lockTextSize * 625 / 1000)
    readonly property int baseGap: page.ascMd + page.gap
    readonly property int clockY: Math.trunc((page.ascLg - page.baseGap) / 2)
    readonly property int greetY: page.clockY + page.baseGap

    // Ring centre measured DOWN from the panel's top edge.
    readonly property int ringInPanel: Settings.lockPanelY - page.ringY

    // "rrggbbaa" (what i3lock and ImageMagick want) -> "#aarrggbb" (what QML
    // wants). Anything malformed falls back to opaque black rather than
    // throwing, so a half-typed value in the field below doesn't break the
    // preview mid-keystroke.
    readonly property color panelColor: {
        const v = Settings.lockPanelColor;
        if (/^[0-9a-fA-F]{8}$/.test(v))
            return "#" + v.slice(6, 8) + v.slice(0, 6);
        if (/^[0-9a-fA-F]{6}$/.test(v))
            return "#" + v;
        return "#000000";
    }

    // Background for the preview: the per-output cache, which lock-image
    // writes WITHOUT the panel painted on. Drawing the panel ourselves is what
    // lets panel colour and size preview live, with no rebuild.
    readonly property var previewScreen: Quickshell.screens.length > 0
        ? Quickshell.screens[0] : null

    // ── Preview ─────────────────────────────────────────────────────────────
    SectionLabel { text: "PREVIEW" }

    Rectangle {
        width: parent.width
        height: 148
        radius: 6
        color: Theme.base
        border.color: Theme.muted
        border.width: 1
        clip: true

        Item {
            id: panelPreview
            anchors.centerIn: parent
            width: Settings.lockPanelWidth
            height: Settings.lockPanelHeight

            // The same slice of wallpaper the panel sits on, so contrast
            // against the real background is visible rather than guessed at.
            Image {
                anchors.fill: parent
                fillMode: Image.Pad
                cache: false
                source: page.previewScreen
                    ? "file://" + Quickshell.env("HOME") + "/.cache/lock-screen/"
                      + page.previewScreen.name + ".png"
                    : ""
                sourceClipRect: page.previewScreen
                    ? Qt.rect(Settings.lockPanelX,
                              page.previewScreen.height - Settings.lockPanelY,
                              Settings.lockPanelWidth, Settings.lockPanelHeight)
                    : Qt.rect(0, 0, 0, 0)
            }

            Rectangle {
                anchors.fill: parent
                color: page.panelColor
            }

            FontMetrics { id: fmClock; font.family: Settings.lockFont; font.pixelSize: Settings.lockClockSize }
            FontMetrics { id: fmText;  font.family: Settings.lockFont; font.pixelSize: Settings.lockTextSize }

            // Positioned by BASELINE, matching i3lock: y = baseline - ascent.
            Text {
                x: page.textInset
                y: page.ringInPanel + page.clockY - fmClock.ascent
                text: Qt.formatDateTime(new Date(),
                        Settings.lockTimeFormat === "%I:%M %p" ? "hh:mm AP" : "HH:mm")
                font.family: Settings.lockFont
                font.pixelSize: Settings.lockClockSize
                color: "#ffffff"
            }

            Text {
                id: greeterPreview
                x: page.textInset
                y: page.ringInPanel + page.greetY - fmText.ascent
                text: Settings.lockText
                font.family: Settings.lockFont
                font.pixelSize: Settings.lockTextSize
                color: "#afb3bd"
            }

            Rectangle {
                width: Settings.lockRingRadius * 2
                height: width
                radius: width / 2
                x: page.ringX - Settings.lockPanelX - Settings.lockRingRadius
                y: page.ringInPanel - Settings.lockRingRadius
                color: "transparent"
                border.width: Settings.lockRingWidth
                border.color: Theme.accent
            }
        }
    }

    // The overlap this whole page exists to prevent. Measured against the real
    // rendered width, so it tracks font, size and message together instead of
    // guessing a character count.
    Text {
        width: parent.width
        readonly property int budget: page.ringX - Settings.lockRingRadius
                                      - (Settings.lockPanelX + page.textInset)
        readonly property bool overflows: greeterPreview.implicitWidth > budget
        text: overflows
            ? "⚠ The message is " + Math.round(greeterPreview.implicitWidth)
              + "px wide but only " + budget + "px clears the ring — it will "
              + "run underneath. Shorten it, or reduce Message size."
            : "Message fits: " + Math.round(greeterPreview.implicitWidth)
              + "px of " + budget + "px before the ring."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: overflows ? Theme.urgent : Theme.muted
    }

    // ── Applies on next lock ────────────────────────────────────────────────
    SectionLabel { text: "TEXT" }

    TextFieldRow {
        label: "Message (Enter to apply)"
        text: Settings.lockText
        placeholder: "Enter Password"
        onAccepted: value => Settings.lockText = value
    }

    FontRow {
        label: "Font"
        current: Settings.lockFont
        sample: "08:45 AM  Enter Password"
        onSelected: family => Settings.lockFont = family
    }

    TextFieldRow {
        label: "Clock format (strftime, Enter to apply)"
        text: Settings.lockTimeFormat
        placeholder: "%I:%M %p"
        onAccepted: value => { if (value !== "") Settings.lockTimeFormat = value; }
    }

    SliderRow {
        label: "Clock size"
        from: 16; to: 56; step: 1; suffix: "px"
        value: Settings.lockClockSize
        onMoved: value => Settings.lockClockSize = value
    }

    SliderRow {
        label: "Message size"
        from: 10; to: 28; step: 1; suffix: "px"
        value: Settings.lockTextSize
        onMoved: value => Settings.lockTextSize = value
    }

    SectionLabel { text: "INDICATOR" }

    SliderRow {
        label: "Ring radius"
        from: 12; to: 40; step: 1; suffix: "px"
        value: Settings.lockRingRadius
        onMoved: value => Settings.lockRingRadius = value
    }

    SliderRow {
        label: "Ring thickness"
        from: 2; to: 12; step: 1; suffix: "px"
        value: Settings.lockRingWidth
        onMoved: value => Settings.lockRingWidth = value
    }

    Text {
        width: parent.width
        text: "Everything above is passed to i3lock when the screen locks, so "
            + "it takes effect on the next lock with nothing to rebuild. Text "
            + "is positioned from these sizes, so the block stays centred in "
            + "the panel whatever you choose."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    // ── Needs the cache rebuilt ─────────────────────────────────────────────
    SectionLabel { text: "PANEL AND BACKGROUND" }

    SliderRow {
        label: "Panel width"
        from: 200; to: 600; step: 10; suffix: "px"
        value: Settings.lockPanelWidth
        onMoved: value => { Settings.lockPanelWidth = value; rebuild.restart(); }
    }

    SliderRow {
        label: "Panel height"
        from: 60; to: 200; step: 5; suffix: "px"
        value: Settings.lockPanelHeight
        onMoved: value => { Settings.lockPanelHeight = value; rebuild.restart(); }
    }

    SliderRow {
        label: "Panel from left edge"
        from: 0; to: 400; step: 5; suffix: "px"
        value: Settings.lockPanelX
        onMoved: value => { Settings.lockPanelX = value; rebuild.restart(); }
    }

    SliderRow {
        label: "Panel from bottom edge"
        from: 40; to: 500; step: 5; suffix: "px"
        value: Settings.lockPanelY
        onMoved: value => { Settings.lockPanelY = value; rebuild.restart(); }
    }

    TextFieldRow {
        label: "Panel colour (rrggbbaa, Enter to apply)"
        text: Settings.lockPanelColor
        placeholder: "232627cc"
        onAccepted: value => {
            if (/^[0-9a-fA-F]{8}$/.test(value)) {
                Settings.lockPanelColor = value.toLowerCase();
                rebuild.restart();
            }
        }
    }

    SliderRow {
        label: "Background dim"
        from: 0; to: 90; step: 5; suffix: "%"
        value: Settings.lockDim
        onMoved: value => { Settings.lockDim = value; rebuild.restart(); }
    }

    SliderRow {
        label: "Background blur"
        from: 0; to: 10; step: 1
        value: Settings.lockBlur
        onMoved: value => { Settings.lockBlur = value; rebuild.restart(); }
    }

    InfoRow {
        label: "Background cache"
        value: rebuildProc.running ? "rebuilding…"
             : rebuild.running     ? "pending…"
                                   : "up to date"
    }

    Text {
        width: parent.width
        text: "These are painted into a cached image rather than drawn at lock "
            + "time, so each change regenerates it — about four seconds, "
            + "batched a moment after you stop adjusting. The preview above "
            + "draws the panel itself, so it updates immediately either way."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    ButtonRow {
        label: "Test"
        buttonText: "Lock now"
        onClicked: Quickshell.execDetached(["lock-screen"])
    }

    // Blur at 0 still costs a full re-render, and the sliders emit on every
    // step, so coalesce: one rebuild once the value has settled.
    Timer {
        id: rebuild
        interval: 700
        onTriggered: rebuildProc.running = true
    }

    Process {
        id: rebuildProc
        // FORCE because the stamp only covers wallpaper and geometry; a
        // settings change is exactly the case it cannot see.
        command: ["sh", "-c", "LOCK_IMAGE_FORCE=1 exec lock-image"]
    }
}
