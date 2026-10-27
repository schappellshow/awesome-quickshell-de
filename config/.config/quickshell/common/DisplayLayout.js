// Pure functions shared by the display backend, editor and Node tests.
function parse(text) {
    const outputs = [];
    let current = null;
    for (const line of text.split("\n")) {
        let m = line.match(/^(\S+) (connected|disconnected)( primary)?(?: (\d+)x(\d+)([+-]\d+)([+-]\d+))?(?: (normal|left|right|inverted))?/);
        if (m) {
            current = null;
            if (m[2] === "connected") {
                current = {
                    name: m[1], primary: !!m[3], enabled: m[4] !== undefined,
                    width: Number(m[4] || 0), height: Number(m[5] || 0),
                    x: Number(m[6] || 0), y: Number(m[7] || 0),
                    rotation: m[8] || "normal", currentMode: "",
                    currentRate: "", modes: []
                };
                outputs.push(current);
            }
            continue;
        }
        m = line.match(/^\s+(\d+x\d+i?)\s+(.*)/);
        if (m && current) {
            if (current.modes.indexOf(m[1]) < 0)
                current.modes.push(m[1]);
            const rate = m[2].split(/\s+/).find(r => r.indexOf("*") >= 0);
            if (rate) {
                current.currentMode = m[1];
                current.currentRate = rate.replace(/[*+]/g, "");
            }
        }
    }
    return outputs;
}

function layout(outputs, profile) {
    return outputs.filter(o => o.enabled).map(o => {
        const p = profile[o.name] || {};
        const mode = p.mode || o.currentMode;
        const rotate = p.rotate || o.rotation;
        const size = mode.match(/^(\d+)x(\d+)i?$/);
        const portrait = rotate === "left" || rotate === "right";
        return {
            name: o.name, mode: mode, rotate: rotate,
            rate: mode === o.currentMode ? o.currentRate : "",
            primary: p.primary === undefined ? o.primary : p.primary,
            x: p.x === undefined ? o.x : p.x,
            y: p.y === undefined ? o.y : p.y,
            width: size ? Number(size[portrait ? 2 : 1]) : o.width,
            height: size ? Number(size[portrait ? 1 : 2]) : o.height
        };
    });
}

function bounds(rects) {
    if (!rects.length)
        return { x: 0, y: 0, width: 1, height: 1 };
    const x = Math.min.apply(null, rects.map(r => r.x));
    const y = Math.min.apply(null, rects.map(r => r.y));
    return {
        x: x, y: y,
        width: Math.max.apply(null, rects.map(r => r.x + r.width)) - x,
        height: Math.max.apply(null, rects.map(r => r.y + r.height)) - y
    };
}

function normalize(rects) {
    const b = bounds(rects);
    return rects.map(r => Object.assign({}, r, {
        x: Math.round(r.x - b.x), y: Math.round(r.y - b.y)
    }));
}

function overlaps(a, b) {
    return a.x < b.x + b.width && a.x + a.width > b.x
        && a.y < b.y + b.height && a.y + a.height > b.y;
}

function validate(rects) {
    if (!rects.length)
        return "No active displays detected. Refresh to try again.";
    if (rects.filter(r => r.primary).length !== 1)
        return "Choose exactly one primary display.";
    for (let i = 0; i < rects.length; i++) {
        const r = rects[i];
        if (!Number.isFinite(r.x) || !Number.isFinite(r.y)
                || r.width <= 0 || r.height <= 0)
            return "Display positions must be finite numbers with a valid resolution.";
        for (let j = i + 1; j < rects.length; j++) {
            if (overlaps(r, rects[j]))
                return r.name + " overlaps " + rects[j].name
                    + ". Drag them apart until their edges meet.";
        }
    }
    return "";
}

// Snap both touching edges and aligned edges/centres, in desktop pixels.
function snap(rect, others, threshold) {
    let dx = threshold + 1;
    let dy = threshold + 1;
    let x = rect.x;
    let y = rect.y;
    for (const other of others) {
        if (other.name === rect.name)
            continue;
        for (const candidate of [other.x - rect.width, other.x + other.width,
                other.x, other.x + other.width - rect.width,
                other.x + (other.width - rect.width) / 2]) {
            const distance = Math.abs(candidate - rect.x);
            if (distance <= threshold && distance < dx) {
                dx = distance;
                x = candidate;
            }
        }
        for (const candidate of [other.y - rect.height, other.y + other.height,
                other.y, other.y + other.height - rect.height,
                other.y + (other.height - rect.height) / 2]) {
            const distance = Math.abs(candidate - rect.y);
            if (distance <= threshold && distance < dy) {
                dy = distance;
                y = candidate;
            }
        }
    }
    return { x: Math.round(x), y: Math.round(y) };
}

function args(rects, outputs) {
    const result = [];
    for (const r of normalize(rects)) {
        result.push("--output", r.name, "--mode", r.mode,
            "--pos", r.x + "x" + r.y, "--rotate", r.rotate);
        if (r.rate)
            result.push("--rate", r.rate);
    }
    // A connected but disabled output must stay disabled.
    for (const o of outputs) {
        if (!o.enabled)
            result.push("--output", o.name, "--off");
    }
    // --noprimary clears the global primary output, even after an --output
    // clause. Select the primary once, LAST, never once per rectangle.
    const primary = rects.find(r => r.primary);
    if (primary)
        result.push("--output", primary.name, "--primary");
    else
        result.push("--noprimary");
    return result;
}

function snapshot(outputs) {
    // Do not normalize a rollback snapshot: restore the exact old positions.
    const result = [];
    for (const o of outputs) {
        result.push("--output", o.name);
        if (!o.enabled) {
            result.push("--off");
            continue;
        }
        result.push("--mode", o.currentMode, "--pos", o.x + "x" + o.y,
            "--rotate", o.rotation);
        if (o.currentRate)
            result.push("--rate", o.currentRate);
    }
    const primary = outputs.find(o => o.enabled && o.primary);
    if (primary)
        result.push("--output", primary.name, "--primary");
    else
        result.push("--noprimary");
    return result;
}

// Legacy displayCmd is an argument list, never a shell program. Accept only
// options this editor (or its predecessor) writes; never execute it via sh.
function savedArgs(command, connected) {
    const tokens = command.trim().split(/\s+/);
    const result = [];
    let keep = false;
    const options = {
        "--mode": /^\d+x\d+i?$/, "--pos": /^-?\d+x-?\d+$/,
        "--rotate": /^(normal|left|right|inverted)$/, "--rate": /^\d+(\.\d+)?$/
    };
    for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i];
        if (token === "--output") {
            const name = tokens[++i];
            if (!name || !/^[A-Za-z0-9_.:-]+$/.test(name))
                throw new Error("Invalid saved output name.");
            keep = connected.indexOf(name) >= 0;
            if (keep)
                result.push(token, name);
        } else if (options[token]) {
            const value = tokens[++i];
            if (!value || !options[token].test(value))
                throw new Error("Invalid saved display option: " + token);
            if (keep)
                result.push(token, value);
        } else if (["--primary", "--noprimary", "--off"].indexOf(token) >= 0) {
            if (keep)
                result.push(token);
        } else {
            throw new Error("Unsupported saved display option: " + token);
        }
    }
    return result;
}
