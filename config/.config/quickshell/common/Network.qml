pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Network state via nmcli polling (quickshell has no NetworkManager service
// on X11, so this shells out every 5s — cheap, and matches what the bar
// needs). Connection secrets and captive flows stay in nm-connection-editor.
Singleton {
    id: root

    property bool connected: false
    property string type: ""            // "ethernet" | "wifi" | ""
    property string connectionName: ""
    property string ssid: ""
    property int signalStrength: 0      // wifi only, 0-100
    property bool wifiEnabled: true

    // [{ name, ctype, active }] for the bar popup; refreshed on demand
    property var savedConnections: []

    // Wi-Fi scan results: [{ ssid, signal, secured, active, known }], and
    // the SSIDs we already have a saved profile for (→ no password needed).
    property var wifiNetworks: []
    property var knownWifiSsids: []
    property bool scanning: false
    property int scanTicks: 0

    // Connect feedback: connecting while nmcli runs, connectError set (and
    // sticky) when it fails — a bad password is the usual cause.
    property bool connecting: false
    property string connectingSsid: ""
    property string connectError: ""

    function refresh() {
        statusProc.running = true;
        radioProc.running = true;
    }

    function refreshConnections() {
        consProc.running = true;
    }

    // Rescan nearby Wi-Fi, then list. Rescan is async in NetworkManager and
    // errors if requested too soon, so we fire it and read the (possibly
    // updated) cache after a short delay either way.
    function scan() {
        scanning = true;
        scanTicks = 0;
        knownProc.running = true;
        Quickshell.execDetached(["nmcli", "dev", "wifi", "rescan"]);
        scanTimer.restart();
    }

    // ssid: connect, reusing a saved profile if password is empty; with a
    // password, create/replace the profile. Array args → no shell quoting
    // needed for SSIDs/passwords with spaces or specials.
    function connectWifi(ssid, password) {
        connectError = "";
        connecting = true;
        connectingSsid = ssid;
        // -w 20: bound nmcli's wait so a bad-password activation can't hang
        const args = ["nmcli", "-w", "20", "dev", "wifi", "connect", ssid];
        if (password && password.length > 0)
            args.push("password", password);
        connectProc.command = args;
        connectProc.running = true;
    }

    // nmcli -t escapes ':' and '\' in field values; split on unescaped ':'
    function splitNmcli(line) {
        const f = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line.charAt(i);
            if (c === "\\" && i + 1 < line.length)
                cur += line.charAt(++i);
            else if (c === ":") { f.push(cur); cur = ""; }
            else cur += c;
        }
        f.push(cur);
        return f;
    }

    // A rescan clears NM's cache then repopulates over a few seconds, so a
    // single snapshot lands mid-scan; list a few times as it fills in.
    Timer {
        id: scanTimer
        interval: 1600
        repeat: true
        onTriggered: {
            wifiListProc.running = true;
            root.scanTicks++;
            if (root.scanTicks >= 3) {
                stop();
                root.scanning = false;
            }
        }
    }

    // After a connect, refresh the list so the active marker updates
    Timer {
        id: rescanListTimer
        interval: 3000
        onTriggered: wifiListProc.running = true
    }

    function toggleWifi() {
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"]);
        wifiEnabled = !wifiEnabled;   // optimistic; settle re-reads the truth
        settle.restart();
    }

    function activate(name) {
        Quickshell.execDetached(["nmcli", "connection", "up", name]);
        settle.restart();
    }

    function deactivate(name) {
        Quickshell.execDetached(["nmcli", "connection", "down", name]);
        settle.restart();
    }

    Timer {
        id: settle
        interval: 1500
        onTriggered: {
            root.refresh();
            root.refreshConnections();
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev", "status"]
        stdout: StdioCollector { onStreamFinished: root.parseStatus(text) }
    }

    function parseStatus(t) {
        // e.g. "wifi:connected:HomeNet" / "ethernet:connected:Wired connection 1"
        // (loopback reports "connected (externally)" and is skipped)
        let found = null;
        for (const line of t.split("\n")) {
            const parts = line.split(":");
            if (parts.length < 3 || parts[1] !== "connected")
                continue;
            if (parts[0] === "ethernet") {
                found = { type: "ethernet", name: parts.slice(2).join(":") };
                break;
            }
            if (parts[0] === "wifi" && !found)
                found = { type: "wifi", name: parts.slice(2).join(":") };
        }
        connected = found !== null;
        type = found ? found.type : "";
        connectionName = found ? found.name : "";
        if (type === "wifi") {
            wifiProc.running = true;
        } else {
            ssid = "";
            signalStrength = 0;
        }
    }

    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    if (!line.startsWith("*:"))
                        continue;
                    const parts = line.split(":");
                    root.ssid = parts.slice(1, -1).join(":");
                    root.signalStrength = parseInt(parts[parts.length - 1]) || 0;
                    return;
                }
            }
        }
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
        }
    }

    // SSIDs of saved Wi-Fi profiles (profile NAME can differ from SSID, so
    // read the actual 802-11-wireless.ssid of each wireless connection)
    Process {
        id: knownProc
        command: ["sh", "-c",
            "nmcli -t -f NAME,TYPE connection show | while IFS=: read -r n t; do " +
            "case \"$t\" in *wireless*) nmcli -g 802-11-wireless.ssid connection show \"$n\" 2>/dev/null;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished:
                root.knownWifiSsids = text.split("\n").map(s => s.trim()).filter(s => s !== "")
        }
    }

    Process {
        id: wifiListProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.parseWifi(text) }
    }

    Process {
        id: connectProc
        stderr: StdioCollector { id: connectErr }
        onExited: (exitCode, exitStatus) => {
            root.connecting = false;
            if (exitCode === 0) {
                root.connectError = "";
                settle.restart();
                rescanListTimer.restart();
            } else {
                // nmcli's own message is verbose; connecting to a secured
                // network and getting a non-zero exit almost always means
                // the password was wrong.
                root.connectError = "Couldn't connect to \"" + root.connectingSsid
                    + "\" — check the password and try again.";
            }
        }
    }

    function parseWifi(t) {
        const idx = {};
        const list = [];
        for (const line of t.split("\n")) {
            if (line === "")
                continue;
            const p = root.splitNmcli(line);
            if (p.length < 4)
                continue;
            const ssid = p[1];
            if (ssid === "")             // hidden network
                continue;
            const active = p[0] === "*";
            const signal = parseInt(p[2]) || 0;
            const secured = p[3] !== "" && p[3] !== "--";
            if (idx[ssid] !== undefined) {        // dedup: keep strongest AP
                const e = list[idx[ssid]];
                e.active = e.active || active;
                if (signal > e.signal)
                    e.signal = signal;
                continue;
            }
            idx[ssid] = list.length;
            list.push({
                ssid: ssid, signal: signal, secured: secured, active: active,
                known: root.knownWifiSsids.indexOf(ssid) >= 0
            });
        }
        list.sort((a, b) => b.signal - a.signal);
        root.wifiNetworks = list;
    }

    Process {
        id: consProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const parts = line.split(":");
                    if (parts.length < 3)
                        continue;
                    const ctype = parts[parts.length - 2];
                    const device = parts[parts.length - 1];
                    const name = parts.slice(0, -2).join(":");
                    if (ctype.includes("wireless"))
                        out.push({ name: name, ctype: "wifi", active: device !== "" });
                    else if (ctype.includes("ethernet"))
                        out.push({ name: name, ctype: "ethernet", active: device !== "" });
                }
                root.savedConnections = out;
            }
        }
    }
}
