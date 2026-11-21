// Run with: node --test tests/drives.test.cjs
// The removable-drives pill's list/visibility logic against lsblk fixtures
// (tests/fixtures/drives-*.lsblk). Real drives cannot be plugged into the
// nested session, so the shell reads the same fixture format from
// $XDG_RUNTIME_DIR/aqs-drives-fixture (see common/Drives.qml).
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");

const Drives = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname,
    "../config/.config/quickshell/common/Drives.js"), "utf8"), Drives);
const fixture = name => fs.readFileSync(path.join(__dirname, "fixtures", name), "utf8");
const plain = value => JSON.parse(JSON.stringify(value));

test("only removable drives appear; internal and system disks never do", () => {
    const list = plain(Drives.parse(fixture("drives-mixed.lsblk")));
    assert.deepEqual(list.map(d => d.dev), ["/dev/sdb", "/dev/sdc", "/dev/mmcblk0"]);
});

test("a mounted stick reports label, size, usage and mount point", () => {
    const [stick] = plain(Drives.parse(fixture("drives-mixed.lsblk")));
    assert.equal(stick.name, "Ultra Fit");
    assert.equal(stick.mounted, true);
    assert.deepEqual(stick.volumes, [{
        dev: "/dev/sdb1", label: "PHOTOS", fstype: "vfat", size: 32014630912,
        used: 12400000000, avail: 19600000000,
        mountpoint: "/run/media/mike/PHOTOS", mounted: true }]);
});

test("unmounted volumes are listed; LUKS containers are not volumes", () => {
    const ssd = plain(Drives.parse(fixture("drives-mixed.lsblk")))[1];
    assert.equal(ssd.mounted, false);
    assert.deepEqual(ssd.volumes.map(v => v.dev), ["/dev/sdc1"]);
    assert.equal(ssd.volumes[0].used, -1);
});

test("an SD card is recognised only when sysfs says so", () => {
    const text = fixture("drives-mixed.lsblk");
    assert.ok(plain(Drives.parse(text)).some(d => d.dev === "/dev/mmcblk0"));
    const without = text.replace(/^#SD.*$/m, "");
    assert.ok(!plain(Drives.parse(without)).some(d => d.dev === "/dev/mmcblk0"));
});

test("nothing plugged in means no drives, and garbage means no drives", () => {
    assert.deepEqual(plain(Drives.parse('{"blockdevices": []}')), []);
    assert.deepEqual(plain(Drives.parse("not json")), []);
    assert.deepEqual(plain(Drives.parse("")), []);
});

test("humanSize", () => {
    assert.equal(Drives.humanSize(32015679488), "32.0 GB");
    assert.equal(Drives.humanSize(1000204886016), "1.0 TB");
    assert.equal(Drives.humanSize(-1), "");
});
