pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colours from the wallpaper: runs bin/wallpaper-palette on the current
// wallpaper and either holds the result as a PREVIEW (Settings -> Appearance
// shows it, and nothing changes until Apply) or, with "Follow wallpaper
// changes" on, applies it straight away.
//
// Applying goes through the ordinary scheme machinery: the palette is saved
// as a named scheme file and made live exactly as picking it from the scheme
// list would, so the OpenMandriva default (Reset) or any other scheme is one
// click away and nothing here is special-cased downstream.
//
// The extraction is a separate process, so the UI never waits on it.
Singleton {
    id: root

    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/wallpaper-palette"

    // Following writes ONE scheme that is overwritten on each wallpaper
    // change, so it cannot pile up a scheme per wallpaper.
    readonly property string followName: "Wallpaper (following)"

    property bool busy: false
    property string error: ""
    // The derived scheme being previewed, or null. Never applied by itself.
    property var preview: null
    property string previewSource: ""

    property string runPath: ""
    property bool runFollow: false
    // A request that arrived while one was running: only the newest matters.
    property var queued: null

    function init() {}

    function sourcePath() {
        return Wallpaper.expand(Settings.wallpaperPath);
    }

    function baseName(p) {
        return p.split("/").pop();
    }

    function schemeName(p) {
        return "Wallpaper — " + baseName(p);
    }

    // follow=false: fill `preview`. follow=true: apply when done.
    function request(follow) {
        const p = sourcePath();
        if (p === "") {
            error = "No wallpaper is set.";
            return;
        }
        if (busy) {
            queued = { path: p, follow: follow };
            return;
        }
        error = "";
        busy = true;
        runPath = p;
        runFollow = follow;
        proc.command = [helper, p];
        proc.running = true;
    }

    function generate() {
        request(false);
    }

    function cancel() {
        preview = null;
        previewSource = "";
        error = "";
    }

    // Save + apply the previewed palette under the per-wallpaper name.
    function applyPreview() {
        if (preview === null)
            return;
        commit(schemeName(previewSource), preview, previewSource);
        cancel();
    }

    function commit(name, scheme, source) {
        Settings.paletteSource = source;
        ColorScheme.saveAndApply(name, scheme);
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                let scheme = null;
                try {
                    scheme = JSON.parse(text);
                } catch (e) {
                    root.error = "Could not read the wallpaper.";
                }
                if (scheme !== null) {
                    if (root.runFollow)
                        root.commit(root.followName, scheme, root.runPath);
                    else {
                        root.preview = scheme;
                        root.previewSource = root.runPath;
                    }
                }
                root.busy = false;
                if (root.queued !== null) {
                    const q = root.queued;
                    root.queued = null;
                    root.request(q.follow);
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && root.busy) {
                root.error = "Colour extraction failed.";
                root.busy = false;
            }
        }
    }

    // Follow: react to a different wallpaper, not to the path being loaded
    // from settings.json at start-up (paletteSource remembers what the
    // current colours came from).
    //
    // Settings arrives property by property while the file loads, so the
    // check waits for the dust to settle rather than judging half a file.
    function followIfChanged() {
        followSettle.restart();
    }

    Timer {
        id: followSettle
        interval: 600
        onTriggered: {
            if (!Settings.followWallpaper)
                return;
            const p = root.sourcePath();
            if (p !== "" && p !== Settings.paletteSource)
                root.request(true);
        }
    }

    // Scriptable from a terminal or a keybinding:
    //   qs ipc call palette generate | apply | cancel | reset
    IpcHandler {
        target: "palette"

        function generate(): void { root.generate(); }
        function apply(): void { root.applyPreview(); }
        function cancel(): void { root.cancel(); }
        // Back to the built-in OpenMandriva palette (Settings -> Appearance
        // -> Reset).
        function reset(): void { ColorScheme.resetAll(); }
    }

    Connections {
        target: Settings
        function onWallpaperPathChanged() { root.followIfChanged(); }
        // Turning it on derives for the wallpaper that is showing now.
        function onFollowWallpaperChanged() { root.followIfChanged(); }
    }
}
