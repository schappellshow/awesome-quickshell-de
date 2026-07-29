import QtQuick
import Quickshell.Io
import "../components"
import "../../common"

SettingsPage {
    id: page

    title: "About"

    property string osName: "…"
    property string kernel: "…"
    property string cpu: "…"
    property string mem: "…"
    property string qsVersion: "…"

    Process {
        running: true
        command: ["sh", "-c",
            ". /etc/os-release && echo \"$PRETTY_NAME\"; " +
            "uname -r; " +
            "awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo; " +
            "awk '/MemTotal/{printf \"%.1f GiB\\n\", $2/1048576}' /proc/meminfo; " +
            "qs --version 2>/dev/null | head -1 | sed 's/,.*//'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                page.osName = lines[0] || "?";
                page.kernel = lines[1] || "?";
                page.cpu = lines[2] || "?";
                page.mem = lines[3] || "?";
                page.qsVersion = lines[4] || "?";
            }
        }
    }

    Image {
        width: 72
        height: 72
        source: "file:///usr/share/icons/openmandriva.svg"
        sourceSize.width: 144
        fillMode: Image.PreserveAspectFit
    }

    SectionLabel { text: "SYSTEM" }

    InfoRow { label: "OS"; value: page.osName }
    InfoRow { label: "Kernel"; value: page.kernel }
    InfoRow { label: "CPU"; value: page.cpu }
    InfoRow { label: "Memory"; value: page.mem }

    SectionLabel { text: "SHELL" }

    InfoRow { label: "Quickshell"; value: page.qsVersion }
    InfoRow { label: "WM"; value: "AwesomeWM (X11)" }
    InfoRow { label: "Compositor"; value: "picom" }
}
