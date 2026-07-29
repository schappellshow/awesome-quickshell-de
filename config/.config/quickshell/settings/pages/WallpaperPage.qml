import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../../common"

SettingsPage {
    id: page

    title: "Wallpaper"

    property var files: []

    Process {
        id: lsProc
        running: true
        // Your own wallpapers first, then whatever the distro ships —
        // /usr/share/wallpapers on KDE-family distros,
        // /usr/share/backgrounds on GNOME/Debian-family ones. -L because
        // ~/Pictures/Wallpapers is often a symlink (e.g. into a dotfiles
        // repo), and depth 3 because vendor packs nest per-theme dirs.
        command: ["sh", "-c",
            "for d in \"$HOME/Pictures/Wallpapers\" /usr/share/wallpapers " +
            "/usr/share/backgrounds; do [ -d \"$d\" ] || continue; " +
            "find -L \"$d\" -maxdepth 3 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " +
            "-o -iname '*.webp' \\) 2>/dev/null; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished:
                page.files = text.trim().split("\n").filter(s => s !== "")
        }
    }

    SectionLabel { text: "AVAILABLE WALLPAPERS" }

    Grid {
        columns: 3
        columnSpacing: 10
        rowSpacing: 10
        width: parent.width

        Repeater {
            model: page.files

            Rectangle {
                id: thumb

                required property string modelData

                readonly property bool current:
                    Wallpaper.expand(Settings.wallpaperPath) === modelData

                width: (page.width - 48 - 20) / 3
                height: width * 9 / 16
                radius: 8
                color: Theme.surfaceAlt
                border.width: current ? 2 : 0
                border.color: Theme.accentBright

                Image {
                    anchors.fill: parent
                    anchors.margins: thumb.current ? 2 : 0
                    source: "file://" + thumb.modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 400
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 4
                    width: parent.width - 8
                    text: thumb.modelData.split("/").pop()
                    elide: Text.ElideMiddle
                    font.family: Theme.fontFamily
                    font.pointSize: 7
                    color: Theme.text
                    style: Text.Outline
                    styleColor: Theme.base
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Settings.wallpaperPath = thumb.modelData
                }
            }
        }
    }

    SectionLabel { text: "CUSTOM PATH" }

    TextFieldRow {
        label: "Image path (Enter to apply)"
        text: Settings.wallpaperPath
        placeholder: "~/Pictures/other.jpg"
        onAccepted: value => {
            if (value !== "")
                Settings.wallpaperPath = value;
        }
    }
}
