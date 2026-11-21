pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Drives.js" as DrivesJs

// Removable drives (USB sticks, SD cards, external disks) for the bar's
// "drives" section and its popup.
//
// Data: `lsblk -J` run on demand, never on the UI thread. It is re-read when
// udev reports a block-device event, when an action finishes, when the popup
// opens (refresh()), and every 30 s as a safety net. What counts as
// removable, and what must never be offered, is decided in Drives.js, which
// the Node tests exercise (tests/drives.test.cjs).
//
// Actions go through udisksctl, the same UDisks2 front-end desktops use, so
// no root is needed: mounting under /run/media/$USER, unmounting, and
// powering a disk off after unmounting ("eject"). Failures, "target is
// busy" above all, are kept in `error` for the popup to show.
//
// Test hook: if $XDG_RUNTIME_DIR/aqs-drives-fixture exists it is read
// instead of lsblk, in the same format (lsblk JSON, then optional `#SD
// mmcblk0` lines). `qs ipc call drives refresh` re-reads it at once. The
// nested-session harness stubs udisksctl and logs its calls to
// stub-calls.log, so the actions can be exercised without a real drive.
Singleton {
    id: root

    // [{ dev, name, size, tran, readOnly, volumes: [...], mounted }]
    property var list: []
    readonly property bool any: list.length > 0

    // Result of the last action: "" when there is nothing to report.
    property string error: ""
    // What is running ("" when idle); one action at a time.
    property string busy: ""

    function refresh() {
        scan.running = false;
        scan.running = true;
    }

    // ── Actions ───────────────────────────────────────────────────────
    function openVolume(volume) {
        if (volume.mounted)
            Quickshell.execDetached(["xdg-open", volume.mountpoint]);
    }

    function mount(volume) {
        run("Mounting " + (volume.label || volume.dev),
            ["udisksctl", "mount", "-b", volume.dev]);
    }

    function unmount(volume) {
        run("Unmounting " + (volume.label || volume.dev),
            ["udisksctl", "unmount", "-b", volume.dev]);
    }

    // Unmount every mounted volume of the disk, then power it off so it is
    // safe to pull. A disk that cannot be powered off (many SD readers) is
    // still safe once unmounted, and the message says so.
    function eject(drive) {
        const mounted = drive.volumes.filter(v => v.mounted).map(v => v.dev);
        run("Ejecting " + drive.name,
            ["sh", "-c",
             "disk=$1; shift; " +
             "for v in \"$@\"; do udisksctl unmount -b \"$v\" || exit 1; done; " +
             "udisksctl power-off -b \"$disk\" || " +
             "echo 'Unmounted. This drive cannot be powered off, but it is safe to remove.'",
             "eject", drive.dev].concat(mounted));
    }

    function run(what, argv) {
        if (busy !== "")
            return;
        error = "";
        busy = what;
        // stderr folded into stdout: udisksctl reports its errors there.
        action.command = ["sh", "-c", "exec \"$@\" 2>&1", "udisks"].concat(argv);
        action.running = true;
    }

    // "Error unmounting /dev/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error
    // .DeviceBusy: target is busy" is accurate and unreadable.
    function explain(text) {
        const t = text.trim();
        if (/busy/i.test(t))
            return "Still in use. Close anything open on it, then try again.";
        if (/not authorized|authori[sz]ation/i.test(t))
            return "Not allowed. This account may not manage that drive.";
        const line = t.split("\n").filter(l => l.trim() !== "")[0] || "";
        return line.replace(/^Error[^:]*:\s*/, "").replace(/GDBus\.Error:[^:]*:\s*/, "");
    }

    Process {
        id: action
        stdout: StdioCollector { id: actionOut }
        onExited: (code, status) => {
            if (code !== 0)
                root.error = root.explain(actionOut.text) || "Failed (exit " + code + ")";
            else if (/safe to remove/.test(actionOut.text))
                root.error = actionOut.text.trim();
            root.busy = "";
            root.refresh();
        }
    }

    // ── Scanning ──────────────────────────────────────────────────────
    Process {
        id: scan
        command: ["sh", "-c",
            "f=\"$XDG_RUNTIME_DIR/aqs-drives-fixture\"; " +
            "if [ -r \"$f\" ]; then cat \"$f\"; exit 0; fi; " +
            "lsblk -J -b -o NAME,PATH,LABEL,MODEL,SIZE,FSTYPE,FSUSED,FSAVAIL," +
            "MOUNTPOINTS,RM,HOTPLUG,TRAN,TYPE,PKNAME,RO 2>/dev/null; " +
            "for d in /sys/block/mmcblk*; do " +
            "  [ \"$(cat \"$d/device/type\" 2>/dev/null)\" = SD ] && echo \"#SD ${d##*/}\"; " +
            "done; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = DrivesJs.parse(text);
                // Skip the assignment when nothing changed, so an idle
                // 30 s rescan doesn't rebuild the popup under the pointer.
                if (JSON.stringify(next) !== JSON.stringify(root.list))
                    root.list = next;
            }
        }
    }

    Timer {
        id: debounce
        interval: 400
        onTriggered: root.refresh()
    }

    // udev says when a block device appears, goes, or changes (mounting
    // does not emit one, hence the refresh after each action).
    Process {
        id: monitor
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("(block)") >= 0)
                    debounce.restart();
            }
        }
        onExited: retry.restart()
    }

    Timer {
        id: retry
        interval: 30000
        onTriggered: monitor.running = true
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "drives"
        function refresh(): void { root.refresh(); }
        function status(): string { return JSON.stringify(root.list); }
    }

    Component.onCompleted: refresh()
}
