// Run with: node --test tests/editor-shapes.test.cjs
// The screenshot editor's geometry and hit testing (EditorShapes.js). The
// drawing itself is checked end to end by tests/screenshot-editor-nested.sh.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");

const S = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname,
    "../config/.config/quickshell/screenshot/EditorShapes.js"), "utf8"), S);
const plain = v => JSON.parse(JSON.stringify(v));

test("a box drawn backwards has the same bounds as one drawn forwards", () => {
    const a = { t: "rect", c: "#fff", w: 3, x1: 10, y1: 20, x2: 110, y2: 70 };
    const b = { t: "rect", c: "#fff", w: 3, x1: 110, y1: 70, x2: 10, y2: 20 };
    assert.deepEqual(plain(S.bounds(a)), { x: 10, y: 20, w: 100, h: 50 });
    assert.deepEqual(plain(S.bounds(b)), plain(S.bounds(a)));
});

test("a freehand stroke is bounded by its points", () => {
    const s = { t: "pen", c: "#fff", w: 6, pts: [[5, 40], [50, 10], [30, 90]] };
    assert.deepEqual(plain(S.bounds(s)), { x: 5, y: 10, w: 45, h: 80 });
});

test("the highlighter is wider than the pen at the same setting", () => {
    assert.ok(S.strokeWidth({ t: "hi", w: 6 }) > S.strokeWidth({ t: "pen", w: 6 }));
});

test("arrows reserve room for their head so it is not clipped", () => {
    const arrow = { t: "arrow", c: "#f00", w: 6, x1: 0, y1: 0, x2: 100, y2: 0 };
    const rect = Object.assign({}, arrow, { t: "rect" });
    assert.ok(S.pad(arrow) > S.pad(rect));
});

test("picking returns the topmost shape under the point, or -1", () => {
    const shapes = [
        { t: "rect", c: "#fff", w: 3, x1: 0, y1: 0, x2: 100, y2: 100 },
        { t: "rect", c: "#fff", w: 3, x1: 50, y1: 50, x2: 150, y2: 150 },
    ];
    assert.equal(S.pick(shapes, 70, 70, 0), 1);
    assert.equal(S.pick(shapes, 10, 10, 0), 0);
    assert.equal(S.pick(shapes, 400, 400, 0), -1);
});

test("a redact box is clamped to the image", () => {
    const s = S.clampBox({ t: "pix", x1: -20, y1: 10, x2: 500, y2: 900 }, 300, 200);
    assert.deepEqual(plain(S.bounds(s)), { x: 0, y: 10, w: 300, h: 190 });
});

test("redact blocks are coarse enough to hide a word but never degenerate", () => {
    const small = { t: "pix", x1: 0, y1: 0, x2: 20, y2: 10 };
    const big = { t: "pix", x1: 0, y1: 0, x2: 900, y2: 600 };
    assert.equal(S.pixBlock(small), 8);
    assert.equal(S.pixBlock(big), 40);
});

test("label outline contrasts with the label color", () => {
    assert.equal(S.contrast("#ffffff"), "#000000");
    assert.equal(S.contrast("#000000"), "#ffffff");
});
