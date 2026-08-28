pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backups: the state and the verbs behind Settings → Backups.
//
// The work is bin/.local/bin/backup-plan — this singleton only asks it
// questions and relays button presses. Two things live outside settings.json
// and so have to be read rather than remembered:
//
//   * whether the job is on, which is `systemctl --user is-enabled` and not a
//     stored bool. A second copy of that answer would drift the first time
//     the timer was touched from a terminal, and it would drift silently.
//   * what the last run did, which the script records when it runs — possibly
//     hours ago, possibly while the shell was not running.
//
// So `status` is polled, not bound. Everything the *user* chooses
// (destination, schedule, retention, exclusions) is ordinary settings.json.
Singleton {
    id: root

    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/backup-plan"

    // Shape of `backup-plan status`; the defaults are what an unconfigured
    // machine reports, so the page renders correctly before the first probe
    // comes back rather than flashing "enabled" for a frame.
    property var status: ({
        enabled: false, running: false, repoReady: false,
        dest: "", repo: "", next: "", sizeBytes: "", archives: 0,
        borgInstalled: true, last: null
    })

    property var archives: []
    property bool busy: false

    function refresh() {
        statusProc.running = true;
    }

    function refreshArchives() {
        archivesProc.running = true;
    }

    function enable() {
        act(["enable"]);
    }

    function disable() {
        act(["disable"]);
    }

    // Creating the repository is a button rather than something `run` does on
    // demand, because the failure it prevents is silent: an unmounted backup
    // disk usually leaves a writable directory behind, and a job that inits
    // whatever it finds there would fill the root filesystem instead. See the
    // script's header.
    function initRepo() {
        act(["init"]);
    }

    function runNow() {
        act(["run"]);
    }

    // Push the run time into the timer's drop-in. Called on change rather
    // than at startup: a daemon-reload every login to re-assert a value that
    // has not moved is noise.
    function syncSchedule() {
        act(["sync"]);
    }

    function act(args) {
        if (busy)
            return;
        busy = true;
        actProc.command = [root.helper].concat(args);
        actProc.running = true;
    }

    // Human-readable size; the script hands back bytes as a string because
    // borg reports a number QML would otherwise round through a double.
    function formatSize(bytes) {
        const n = Number(bytes);
        if (!n)
            return "—";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        let v = n;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (v < 10 && i > 0 ? v.toFixed(1) : Math.round(v)) + " " + units[i];
    }

    Process {
        id: statusProc
        command: [root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text);
                    // The size probe never waits for borg's repository lock,
                    // so a status taken during a backup comes back with no
                    // size and no count. That is "could not look", not
                    // "nothing there" — keep what the last successful look
                    // found rather than flashing 0 snapshots for the length
                    // of the run.
                    if (next.sizeBytes === "" && root.status.sizeBytes !== "") {
                        next.sizeBytes = root.status.sizeBytes;
                        next.archives = root.status.archives;
                    }
                    root.status = next;
                } catch (e) {
                    // A helper that isn't installed yet (fresh clone, not
                    // stowed) reports nothing. Leaving the last good status
                    // alone beats replacing the page with an error.
                }
            }
        }
    }

    Process {
        id: archivesProc
        command: [root.helper, "archives"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.archives = JSON.parse(text);
                } catch (e) {
                    root.archives = [];
                }
            }
        }
    }

    Process {
        id: actProc
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            root.refresh();
            root.refreshArchives();
        }
    }

    // A backup takes minutes to hours, so the page has to keep asking while
    // one is in flight. Idle, this does nothing: the timer only runs while
    // the last status said a run was in progress.
    Timer {
        interval: 3000
        repeat: true
        running: root.status.running === true
        onTriggered: root.refresh()
    }
}
