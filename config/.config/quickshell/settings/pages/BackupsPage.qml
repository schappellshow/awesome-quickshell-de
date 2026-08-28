import QtQuick
import "../components"
import "../../common"

// Backups. Off on a fresh install and off until this page turns it on: the
// timer ships disabled and the destination ships empty, so the job has both
// no schedule and nowhere to write.
//
// The shipped job is one borg snapshot of $HOME, daily. It is not trying to
// be a backup suite — if you already have restic, Vorta, rsnapshot or a NAS
// doing this, leave the switch off and nothing here runs.
SettingsPage {
    id: page

    title: "Backups"

    Component.onCompleted: {
        Backup.refresh();
        Backup.refreshArchives();
    }

    readonly property var st: Backup.status
    readonly property var last: Backup.status.last

    readonly property string lastLine: {
        if (!page.last)
            return "Never run";
        const s = page.last.state;
        const when = page.last.when || "";
        if (s === "ok")
            return "Succeeded " + when;
        // A warning means the snapshot was written and one file moved under
        // borg while it read it — the normal state of backing up a machine
        // that is switched on, so it reads as done, with a footnote.
        if (s === "warned")
            return "Succeeded " + when + " (with warnings)";
        if (s === "running")
            return "In progress since " + when;
        if (s === "failed")
            return "Failed " + when + " — " + (page.last.message || "");
        if (s === "skipped")
            return "Skipped " + when + " — " + (page.last.message || "");
        return when;
    }

    readonly property color lastColor: {
        if (!page.last)
            return Theme.muted;
        if (page.last.state === "failed")
            return Theme.urgent;
        if (page.last.state === "skipped" || page.last.state === "warned")
            return Theme.orange;
        return Theme.subtext;
    }

    SectionLabel { text: "STATUS" }

    // borg is an optional dependency — the installer reports it rather than
    // failing on it — so the page has to be usable on a machine without it,
    // and say why nothing works there.
    Text {
        visible: page.st.borgInstalled === false
        width: parent.width
        text: "borg isn't installed, so the shipped backup job can't run. "
            + "Install it (borgbackup on most distributions) and reopen this "
            + "page, or leave backups off and use your own tool."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 9
        color: Theme.orange
    }

    ToggleRow {
        label: "Daily backup"
        checked: page.st.enabled === true
        onToggled: value => value ? Backup.enable() : Backup.disable()
    }

    InfoRow {
        label: "Last run"
        value: page.lastLine
    }

    Text {
        visible: page.last && page.last.state === "warned"
        width: parent.width
        text: page.last ? page.last.message : ""
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    InfoRow {
        visible: page.st.enabled === true && page.st.next !== ""
        label: "Next run"
        value: page.st.next
    }

    InfoRow {
        visible: page.st.repoReady === true
        label: "Stored"
        value: Backup.formatSize(page.st.sizeBytes) + " · "
            + page.st.archives + " snapshot" + (page.st.archives === 1 ? "" : "s")
    }

    ButtonRow {
        label: "Run a backup now"
        buttonText: page.st.running === true ? "Running…" : "Back up now"
        onClicked: {
            if (page.st.running !== true)
                Backup.runNow();
        }
    }

    Text {
        width: parent.width
        text: "A run with the backup disk absent is recorded above and "
            + "nothing else — no notification. That is deliberate: a laptop "
            + "away from its disk would otherwise pop one at every login, "
            + "which is how people learn to ignore backup warnings. Only a "
            + "backup that actually fails speaks up."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    ToggleRow {
        label: "Notify when a backup finishes"
        checked: Settings.backupNotify
        onToggled: value => Settings.backupNotify = value
    }

    SectionLabel { text: "DESTINATION" }

    TextFieldRow {
        label: "Backup folder (Enter to apply)"
        text: Settings.backupDest
        placeholder: "/mnt/backup"
        onAccepted: value => {
            Settings.backupDest = value.trim();
            Backup.refresh();
        }
    }

    InfoRow {
        visible: page.st.repo !== ""
        label: "Repository"
        value: page.st.repo
    }

    // Creating the repository is a button, not something the nightly run does
    // when it finds the folder empty. An unmounted backup disk usually leaves
    // a writable mount point behind, so a job that created a repository
    // wherever it was pointed would fill the system disk with what you
    // believed was going to the backup drive — and it would look like it was
    // working the whole time.
    ButtonRow {
        visible: Settings.backupDest !== "" && page.st.repoReady !== true
        label: "No repository at that path yet"
        buttonText: "Create repository"
        onClicked: Backup.initRepo()
    }

    Text {
        width: parent.width
        text: "One repository per machine, so several can share one disk. "
            + "The repository is unencrypted: a passphrase kept on the "
            + "machine being backed up defends against the disk walking off "
            + "and nothing else, and storing one where an unattended timer "
            + "can use it is a keyring problem this doesn't try to solve. If "
            + "you want encryption, run `borg init -e repokey-blake2` at the "
            + "path above yourself — the job uses whatever repository it "
            + "finds."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel { text: "SCHEDULE" }

    TextFieldRow {
        label: "Run at (HH:MM, Enter to apply)"
        text: Settings.backupTime
        placeholder: "20:00"
        onAccepted: value => {
            if (/^\d{1,2}:\d{2}$/.test(value)) {
                Settings.backupTime = value;
                Backup.syncSchedule();
            }
        }
    }

    Text {
        width: parent.width
        text: "A run missed while the machine was off happens at the next "
            + "login instead, give or take fifteen minutes so it isn't "
            + "competing with everything else that starts at once."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel { text: "RETENTION" }

    SliderRow {
        label: "Keep daily"
        from: 0
        to: 30
        value: Settings.backupKeepDaily
        onMoved: value => Settings.backupKeepDaily = value
    }

    SliderRow {
        label: "Keep weekly"
        from: 0
        to: 26
        value: Settings.backupKeepWeekly
        onMoved: value => Settings.backupKeepWeekly = value
    }

    SliderRow {
        label: "Keep monthly"
        from: 0
        to: 24
        value: Settings.backupKeepMonthly
        onMoved: value => Settings.backupKeepMonthly = value
    }

    Text {
        width: parent.width
        text: "Snapshots outside all three windows are pruned after each "
            + "run, so the disk doesn't quietly fill. Borg deduplicates, so "
            + "keeping more history costs far less than the numbers suggest "
            + "— what a snapshot adds is roughly what changed that day."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel { text: "EXCLUDE" }

    Repeater {
        model: Settings.backupExclude

        Item {
            id: exRow

            required property var modelData
            required property int index

            width: parent.width
            height: 26

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30
                text: exRow.modelData
                elide: Text.ElideMiddle
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: Theme.text
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                font.pointSize: 10
                color: exHover.hovered ? Theme.urgent : Theme.muted

                HoverHandler { id: exHover }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: Settings.backupExclude =
                        (Settings.backupExclude || []).filter(
                            (e, i) => i !== exRow.index)
                }
            }
        }
    }

    Text {
        visible: (Settings.backupExclude || []).length === 0
        text: "Nothing excluded — the whole home directory is backed up."
        font.family: Theme.fontFamily
        font.pointSize: 9
        color: Theme.muted
    }

    TextFieldRow {
        label: "Add an exclusion (Enter to add)"
        placeholder: "Videos  ·  .local/share/Steam  ·  /data/scratch"
        onAccepted: value => {
            const v = value.trim();
            if (v !== "" && (Settings.backupExclude || []).indexOf(v) < 0)
                Settings.backupExclude = (Settings.backupExclude || []).concat([v]);
        }
    }

    ButtonRow {
        label: "Back to the shipped exclusions"
        buttonText: "Restore defaults"
        onClicked: Settings.backupExclude =
            [".cache", ".local/share/Trash", ".thumbnails"]
    }

    Text {
        width: parent.width
        text: "A path without a leading / is relative to your home "
            + "directory. Caches and Trash are excluded by default because "
            + "they are large, churn daily and restore to nothing you would "
            + "miss. Virtual machine images and ISO libraries are the usual "
            + "next candidates."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel {
        visible: Backup.archives.length > 0
        text: "SNAPSHOTS"
    }

    Repeater {
        model: Backup.archives.slice(0, 12)

        InfoRow {
            required property var modelData
            label: modelData.name
            value: String(modelData.time).replace("T", " ").slice(0, 16)
        }
    }

    Text {
        visible: Backup.archives.length > 0
        width: parent.width
        text: "Restore with borg directly: `borg mount "
            + page.st.repo + "::<snapshot> /mnt/point` browses one as a "
            + "filesystem, and `borg extract` pulls single paths out. "
            + "Neither needs this desktop, which is the point of using a "
            + "standard format."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
