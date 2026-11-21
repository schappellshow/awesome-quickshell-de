// Pure helpers for the removable-drives pill: turn `lsblk -J` output into the
// list of drives worth showing. No QML types, so Node tests can load it (see
// tests/drives.test.cjs) and the same code runs in the shell.
//
// Input is the JSON `lsblk` prints, optionally followed by lines of the form
//     #SD mmcblk0
// naming the mmc block devices that are SD cards. lsblk cannot tell an SD
// card in a built-in reader from the machine's soldered eMMC, so the shell
// asks sysfs (device/type) and appends the answer.

// A disk is never offered if any partition, or anything stacked on one, is
// mounted at one of these: it is somebody's system disk, whatever its bus.
const SYSTEM_MOUNT = /^(\/|\/boot(\/.*)?|\/efi|\/home(\/.*)?|\/usr(\/.*)?|\/var(\/.*)?|\/etc|\/opt|\/nix(\/.*)?|\[SWAP\])$/;

// Filesystems that are not something you can mount and browse.
const NOT_A_VOLUME = ["swap", "crypto_LUKS", "LVM2_member",
                      "linux_raid_member", "zfs_member", "isw_raid_member"];

function mountOf(node) {
    return (node.mountpoints || []).filter(m => m)[0] || "";
}

function allMounts(node) {
    let out = (node.mountpoints || []).filter(m => m);
    for (const c of (node.children || []))
        out = out.concat(allMounts(c));
    return out;
}

function volumeOf(node) {
    const mnt = mountOf(node);
    return {
        dev: node.path || ("/dev/" + node.name),
        label: node.label || "",
        fstype: node.fstype,
        size: Number(node.size) || 0,
        used: node.fsused === null || node.fsused === undefined ? -1 : Number(node.fsused),
        avail: node.fsavail === null || node.fsavail === undefined ? -1 : Number(node.fsavail),
        mountpoint: mnt,
        mounted: mnt !== ""
    };
}

// Is this top-level lsblk entry something a person plugs in and pulls out?
function isRemovable(disk, sdCards) {
    if (disk.type !== "disk")
        return false;
    if (/^(loop|zram|ram|nbd|dm-|md|sr|fd)/.test(disk.name))
        return false;
    if (allMounts(disk).some(m => SYSTEM_MOUNT.test(m)))
        return false;
    // USB (sticks, enclosures), the kernel's own removable flag, or an
    // SD card. A bare "hotplug" flag is deliberately not enough: internal
    // SATA/NVMe bays set it too.
    return disk.rm === true || disk.rm === "1" || disk.tran === "usb"
        || sdCards.indexOf(disk.name) >= 0;
}

function parse(text) {
    const sdCards = [];
    const json = [];
    for (const line of String(text).split("\n")) {
        const m = line.match(/^#SD\s+(\S+)/);
        if (m)
            sdCards.push(m[1]);
        else
            json.push(line);
    }
    let data;
    try {
        data = JSON.parse(json.join("\n"));
    } catch (e) {
        return [];
    }
    const drives = [];
    for (const disk of (data.blockdevices || [])) {
        if (!isRemovable(disk, sdCards))
            continue;
        // A stick formatted without a partition table carries its
        // filesystem on the disk itself.
        const nodes = (disk.children && disk.children.length > 0)
            ? disk.children : [disk];
        const volumes = nodes
            .filter(n => n.fstype && NOT_A_VOLUME.indexOf(n.fstype) < 0)
            .map(volumeOf);
        const model = (disk.model || "").trim();
        drives.push({
            dev: disk.path || ("/dev/" + disk.name),
            name: model || (volumes[0] && volumes[0].label) || "Removable drive",
            size: Number(disk.size) || 0,
            tran: disk.tran || "",
            readOnly: disk.ro === true,
            volumes: volumes,
            mounted: volumes.some(v => v.mounted)
        });
    }
    return drives;
}

function humanSize(bytes) {
    if (bytes < 0 || isNaN(bytes))
        return "";
    const units = ["B", "KB", "MB", "GB", "TB"];
    let v = bytes;
    let i = 0;
    while (v >= 1000 && i < units.length - 1) {
        v /= 1000;
        i++;
    }
    return (v >= 100 || i === 0 ? v.toFixed(0) : v.toFixed(1)) + " " + units[i];
}
