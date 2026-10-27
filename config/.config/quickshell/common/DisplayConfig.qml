pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "DisplayLayout.js" as Layout

// One serialized RandR writer. Only a successful, confirmed user Apply is
// persisted. Rollback belongs to this singleton, not the lazily loaded page.
Singleton {
    id: root

    property var outputs: []
    property string error: ""
    property string status: ""
    property bool replayed: false
    property bool initialized: false
    property string lastOutputs: ""
    property bool refreshPending: false
    property bool restorePending: false
    property string operation: ""
    property var pendingProfile: ({})
    property var pendingArgs: []
    property var rollbackArgs: []
    property string probeText: ""
    property string processError: ""
    property bool confirming: false
    property int secondsLeft: 0
    readonly property bool applying: operation !== "" || confirming
    readonly property bool probing: query.running
    signal applied()

    function init() {
        initialized = true;
        probe();
    }

    function probe() {
        if (query.running || writer.running) {
            refreshPending = true;
            return;
        }
        probeText = "";
        query.running = true;
    }

    function run(args, kind) {
        operation = kind;
        processError = "";
        writer.command = ["timeout", "15s", "xrandr"].concat(args);
        writer.running = true;
    }

    function restoreSaved() {
        if (!initialized || applying || Settings.displayCmd === "")
            return;
        replayed = true;
        restorePending = false;
        try {
            const args = Layout.savedArgs(Settings.displayCmd,
                outputs.map(o => o.name));
            if (args.length)
                run(args, "restore");
        } catch (e) {
            error = String(e);
        }
    }

    Connections {
        target: Settings
        function onDisplayCmdChanged() {
            if (!root.replayed && root.initialized)
                root.probe();
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() { hotplug.restart(); }
    }

    Timer {
        id: hotplug
        interval: 1200
        onTriggered: root.probe()
    }

    function apply(profile) {
        if (applying || query.running)
            return;
        error = "";
        status = "";
        pendingProfile = profile;
        // Probe immediately before applying: the page's snapshot may be old.
        operation = "prepare";
        probe();
    }

    function keep() {
        if (!confirming)
            return;
        confirmation.stop();
        confirming = false;
        replayed = true;
        Settings.displayCmd = pendingArgs.join(" ");
        status = "Layout saved. It will be restored at login and on hotplug.";
        applied();
        probe();
    }

    function revert() {
        if (!confirming)
            return;
        confirmation.stop();
        confirming = false;
        run(rollbackArgs, "rollback");
    }

    Timer {
        id: confirmation
        interval: 1000
        repeat: true
        onTriggered: {
            root.secondsLeft--;
            if (root.secondsLeft <= 0)
                root.revert();
        }
    }

    Process {
        id: query
        command: ["timeout", "10s", "xrandr", "--query"]
        stdout: StdioCollector { onStreamFinished: root.probeText = text }
        onExited: (code, exitStatus) => {
            if (code !== 0 || exitStatus !== 0) {
                root.error = "Could not query displays (exit " + code + ").";
                if (root.operation === "prepare")
                    root.operation = "";
                return;
            }
            const previousKey = root.lastOutputs;
            root.outputs = Layout.parse(root.probeText);
            root.lastOutputs = root.outputs.map(o => o.name).sort().join(",");
            if (previousKey !== "" && previousKey !== root.lastOutputs)
                root.restorePending = true;
            if (root.operation === "prepare") {
                const rects = Layout.layout(root.outputs, root.pendingProfile);
                root.error = Layout.validate(rects);
                if (root.error !== "") {
                    root.operation = "";
                    return;
                }
                root.rollbackArgs = Layout.snapshot(root.outputs);
                root.pendingArgs = Layout.args(rects, root.outputs);
                root.run(root.pendingArgs, "apply");
            } else if (root.initialized && !root.applying
                    && (!root.replayed || root.restorePending)) {
                root.restoreSaved();
            }
            if (root.refreshPending && !writer.running) {
                root.refreshPending = false;
                deferredProbe.restart();
            }
        }
    }

    Timer {
        id: deferredProbe
        interval: 100
        onTriggered: root.probe()
    }

    Process {
        id: writer
        stderr: StdioCollector { onStreamFinished: root.processError = text.trim() }
        onExited: (code, exitStatus) => {
            const kind = root.operation;
            root.operation = "";
            const success = code === 0 && exitStatus === 0;
            if (!success) {
                root.error = "Display " + kind + " failed (exit " + code + "). "
                    + root.processError;
                // RandR can partially apply a command before reporting failure.
                if (kind === "apply") {
                    root.run(root.rollbackArgs, "rollback");
                    return;
                }
            }
            if (success && kind === "apply") {
                root.secondsLeft = 20;
                root.confirming = true;
                root.status = "Keep this layout? Unconfirmed changes revert automatically.";
                confirmation.restart();
            } else if (success && kind === "rollback") {
                root.status = "Previous layout restored. Changes were not saved.";
                root.applied();
            }
            root.probe();
        }
    }
}
