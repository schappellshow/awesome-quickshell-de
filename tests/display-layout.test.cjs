// Run with: node --test tests/display-layout.test.cjs
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const Layout = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname,
    "../config/.config/quickshell/common/DisplayLayout.js"), "utf8"), Layout);
const plain = value => JSON.parse(JSON.stringify(value));
const fixture = `Screen 0: minimum 320 x 200, current 4920 x 1920, maximum 16384 x 16384
DisplayPort-0 disconnected (normal left inverted right x axis y axis)
DisplayPort-1 connected 1920x1080+0+0 (normal left inverted right x axis y axis)
   1920x1080     60.00*+ 100.00 74.97
   1280x720      60.00
DisplayPort-2 connected primary 1920x1080+1920+0 (normal left inverted right x axis y axis)
   1920x1080     60.00*+ 50.00
HDMI-A-0 connected 1080x1920+3840+0 left (normal left inverted right x axis y axis)
   1920x1080     74.97*+ 60.00
DP-disabled connected (normal left inverted right x axis y axis)
   1920x1080     60.00+
`;
const outputs = () => Layout.parse(fixture);
const requested = {
    "HDMI-A-0": { x: 0, y: 0 },
    "DisplayPort-2": { x: 1080, y: 0 },
    "DisplayPort-1": { x: 3000, y: 0 }
};

test("parse connected, disabled, primary, mode, rate and rotated geometry", () => {
    const o = outputs();
    assert.equal(o.length, 4);
    assert.equal(o[1].primary, true);
    assert.equal(o[2].rotation, "left");
    assert.equal(o[2].width, 1080);
    assert.equal(o[2].height, 1920);
    assert.equal(o[2].currentMode, "1920x1080");
    assert.equal(o[2].currentRate, "74.97");
    assert.equal(o[3].enabled, false);
});

test("parse signed positions and all rotations", () => {
    for (const rotation of ["normal", "left", "right", "inverted"]) {
        const o = Layout.parse("DP-1 connected primary 1080x1920-1080-240 "
            + rotation + " (normal left inverted right)\n   1920x1080 60.00*+\n")[0];
        assert.equal(o.x, -1080);
        assert.equal(o.y, -240);
        assert.equal(o.rotation, rotation);
    }
});

test("requested HDMI-left DP2-primary DP1-right layout validates", () => {
    const rects = Layout.layout(outputs(), requested);
    assert.equal(Layout.validate(rects), "");
    assert.equal(rects.find(r => r.name === "HDMI-A-0").width, 1080);
    assert.equal(rects.find(r => r.primary).name, "DisplayPort-2");
});

test("rotation and resolution changes update canvas dimensions", () => {
    const rects = Layout.layout(outputs(), { "DisplayPort-1": {
        mode: "1280x720", rotate: "right"
    } });
    assert.equal(rects[0].width, 720);
    assert.equal(rects[0].height, 1280);
    assert.equal(rects[0].rate, "");
});

test("normalize negative positions without changing relative placement", () => {
    const rects = Layout.layout(outputs(), requested);
    const shifted = rects.map(r => ({ ...r, x: r.x - 1080, y: r.y - 200 }));
    assert.deepEqual(plain(Layout.normalize(shifted)), plain(rects));
});

test("overlap is rejected but touching edges are valid", () => {
    const rects = Layout.layout(outputs(), requested);
    assert.equal(Layout.validate(rects), "");
    rects[0].x = 1079;
    assert.match(Layout.validate(rects), /overlaps/);
});

test("invalid coordinates, empty layouts and missing primary are rejected", () => {
    assert.match(Layout.validate([]), /No active/);
    const rects = Layout.layout(outputs(), requested);
    rects[0].x = NaN;
    assert.match(Layout.validate(rects), /finite/);
    rects[0].x = 3000;
    for (const r of rects) r.primary = false;
    assert.match(Layout.validate(rects), /primary/);
});

test("snapping chooses nearby edges, alignments and centres", () => {
    const other = { name: "A", x: 0, y: 0, width: 1920, height: 1080 };
    const r = { name: "B", x: 1928, y: 8, width: 1080, height: 1920 };
    assert.deepEqual(plain(Layout.snap(r, [other], 20)), { x: 1920, y: 0 });
    assert.deepEqual(plain(Layout.snap({ ...r, x: 2100, y: 2100 }, [other], 20)),
        { x: 2100, y: 2100 });
    assert.equal(Layout.snap({ ...r, x: 425 }, [other], 20).x, 420);
});

test("generated args preserve rates, primary, portrait, disabled outputs", () => {
    const o = outputs();
    const args = Layout.args(Layout.layout(o, requested), o);
    const command = args.join(" ");
    assert.match(command, /DisplayPort-1 --mode 1920x1080 --pos 3000x0/);
    assert.match(command, /DisplayPort-2 --mode 1920x1080 --pos 1080x0 --rotate normal --rate 60.00/);
    assert.match(command, /HDMI-A-0 --mode 1920x1080 --pos 0x0 --rotate left --rate 74.97/);
    assert.match(command, /--output DP-disabled --off/);
    assert.equal(args.filter(a => a === "--primary").length, 1);
    assert.deepEqual(plain(args.slice(-3)), ["--output", "DisplayPort-2", "--primary"]);
    assert.equal(args.includes("--noprimary"), false);
    assert.deepEqual(plain(Layout.savedArgs(command, o.map(o => o.name))), plain(args));
});

test("rollback snapshots retain original positions and rates", () => {
    const command = Layout.snapshot(outputs()).join(" ");
    assert.match(command, /HDMI-A-0 --mode 1920x1080 --pos 3840x0 --rotate left --rate 74.97/);
    assert.match(command, /--output DP-disabled --off/);
    assert.match(command, /--output DisplayPort-2 --primary$/);
});

test("legacy saved layouts filter absent outputs and reject shell syntax", () => {
    assert.deepEqual(plain(Layout.savedArgs(
        "--output missing --mode 1920x1080 --pos 0x0 --output DP-1 --mode 1920x1080 --primary",
        ["DP-1"])), ["--output", "DP-1", "--mode", "1920x1080", "--primary"]);
    for (const cmd of [
        "--output DP-1;reboot --primary",
        "--output DP-1 --pos $(reboot)",
        "--output DP-1 --mode",
        "--output DP-1 --unknown 123"
    ]) {
        assert.throws(() => Layout.savedArgs(cmd, ["DP-1"]));
    }
});
