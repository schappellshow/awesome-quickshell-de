import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../common"

// Freedesktop notification daemon + popup stack (top-right), styled like the
// old naughty theme. Requires naughty's dbus module to be disabled in
// awesome's rc.lua so quickshell can own org.freedesktop.Notifications.
// Every notification is also copied into NotifHistory for the center panel;
// do-not-disturb suppresses popups but history still records.
Scope {
    id: root

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: notification => {
            notification.tracked = true;
            NotifHistory.add(notification);
        }
    }

    // Popups on the bar's screen (all quickshell windows need an explicit
    // screen under UseQApplication, or they lose their dock anchoring and
    // land at 0,0 on the first monitor). Only one popup stack is ever
    // needed, so this binds directly instead of going through Variants —
    // Variants recreates its whole window (tearing down every card and
    // its Timer) whenever the model array is reassigned, and a plain
    // `Quickshell.screens.filter(...)` produces a brand-new array on every
    // reactive re-evaluation even when the matched screen hasn't changed,
    // which was silently destroying and rebuilding the popups mid-display.
    property var targetScreen: null

    function updateTargetScreen() {
        const match = Quickshell.screens.filter(
            s => s.name === Settings.barScreen);
        root.targetScreen = match.length > 0 ? match[0] : Quickshell.screens[0];
    }

    Component.onCompleted: updateTargetScreen()

    // Only recompute on an actual Settings.barScreen change — a plain
    // reactive `Quickshell.screens.filter(...)` binding re-evaluates (and
    // hands PanelWindow a brand-new array/object) on every unrelated
    // signal too, which was tearing down and rebuilding the popup window
    // and its cards mid-display.
    Connections {
        target: Settings
        function onBarScreenChanged() { root.updateTargetScreen(); }
    }

    PanelWindow {
        id: win

        screen: root.targetScreen

        visible: server.trackedNotifications.values.length > 0
              && !Settings.doNotDisturb

        readonly property bool posTop: !Settings.notifPosition.startsWith("bottom")
        readonly property bool posLeft: Settings.notifPosition.endsWith("left")

        // Fixed full-height window so the compositor never sees a geometry
        // change while a notification is up. A content-sized window
        // oscillated between 1px and full height during the notification's
        // own lifetime (a QML relayout quirk) — a violent flicker,
        // especially bottom-anchored where the card jumped ~70px each
        // frame. Cards sit in a corner-anchored Column inside; `mask`
        // limits input to just the cards so clicks pass through the rest
        // of the transparent strip. aboveWindows keeps it over other
        // windows on the busy primary output.
        anchors { top: true; bottom: true; left: win.posLeft; right: !win.posLeft }
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        implicitWidth: 384
        color: "transparent"
        mask: Region { item: stack }

        Column {
            id: stack
            width: 360
            spacing: 8

            anchors.top: win.posTop ? parent.top : undefined
            anchors.bottom: win.posTop ? undefined : parent.bottom
            anchors.left: win.posLeft ? parent.left : undefined
            anchors.right: win.posLeft ? undefined : parent.right
            anchors.margins: 12

            Repeater {
                model: server.trackedNotifications

                delegate: Rectangle {
                    id: card

                    required property var modelData

                    readonly property string iconSrc: NotifHistory.iconSource(
                        modelData.image || "", modelData.appIcon || "")

                    width: stack.width
                    implicitHeight: content.implicitHeight + 24
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: card.modelData.urgency === NotificationUrgency.Critical
                        ? Theme.urgent : Theme.accentBright
                    border.width: 2
                    opacity: 0.95

                    Row {
                        id: content

                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 10

                        Image {
                            id: icon
                            width: 32
                            height: 32
                            // Some apps (Slack, ...) send raw icon pixmap
                            // data rather than a themed name; Quickshell
                            // serves that through an internal handle that
                            // can die mid-load if the notification is
                            // quickly replaced (a common Slack pattern for
                            // unread-count updates) — load synchronously
                            // to close that race, and hide cleanly rather
                            // than show a broken-image glyph if it still
                            // misses.
                            visible: card.iconSrc !== "" && status !== Image.Error
                            source: card.iconSrc
                            fillMode: Image.PreserveAspectFit
                            asynchronous: false
                            sourceSize.width: 64
                        }

                        Column {
                            width: content.width
                                - (card.iconSrc !== "" ? 42 : 0)
                            spacing: 3

                            Text {
                                width: parent.width
                                text: card.modelData.appName || "notification"
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: 7
                                color: Theme.muted
                            }

                            Text {
                                width: parent.width
                                text: card.modelData.summary
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pointSize: 10
                                color: Theme.text
                            }

                            Text {
                                width: parent.width
                                visible: text.length > 0
                                text: card.modelData.body
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: 9
                                color: Theme.subtext
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.modelData.dismiss()
                    }

                    // Per the notification spec, expireTimeout is -1 ("use
                    // the server's default"), 0 ("never auto-expire — wait
                    // for the app or user to dismiss"), or a positive ms
                    // count. We were treating 0 as "use our default" (so
                    // apps requesting persistence still got timed out) and
                    // passing tiny app-requested values straight through —
                    // some apps ask for a few hundred ms, which reads as a
                    // flicker of the border with no time to see the text.
                    // Clamp any explicit positive request to a readable
                    // floor instead of trusting it verbatim.
                    readonly property int popupInterval: {
                        const t = card.modelData.expireTimeout;
                        if (t === 0)
                            return -1;
                        if (t > 0)
                            return Math.max(t, 3000);
                        return Settings.notifTimeoutMs;
                    }

                    Timer {
                        interval: card.popupInterval > 0 ? card.popupInterval : 1
                        running: card.popupInterval > 0
                        onTriggered: card.modelData.expire()
                    }
                }
            }
        }
    }
}
