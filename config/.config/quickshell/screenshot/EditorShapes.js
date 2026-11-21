// Pure helpers for the screenshot editor's annotations: geometry, hit
// testing and Canvas painting. No QML types, so Node can load it (see
// tests/editor-shapes.test.cjs) and the same code draws in the shell.
//
// A shape is a plain object in IMAGE pixels, never screen pixels, so the
// export at the original resolution is the same drawing as the on-screen
// one at any zoom:
//   { t: "arrow"|"rect"|"pen"|"hi"|"text"|"pix",
//     c: "#rrggbb", w: stroke width (px),
//     x1, y1, x2, y2           arrow / rect / pix
//     pts: [[x, y], ...]       pen / hi
//     x, y, text, bw, bh       text (bw/bh = measured size)  }

function strokeWidth(s) { return s.t === "hi" ? s.w * 3.5 : s.w; }

function headLength(s) { return Math.max(14, s.w * 4.5); }

// Font size of a text label for a given stroke width choice.
function fontPx(w) { return Math.round(w * 3 + 14); }

// Pixelation block for a redact box: coarse enough to hide a word.
function pixBlock(s) {
    const b = bounds(s);
    return Math.max(8, Math.min(40, Math.round(Math.min(b.w, b.h) / 3)));
}

function bounds(s) {
    if (s.t === "text")
        return { x: s.x, y: s.y, w: s.bw || 1, h: s.bh || 1 };
    if (s.t === "pen" || s.t === "hi") {
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (const p of s.pts) {
            x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]);
            x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]);
        }
        return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
    }
    return { x: Math.min(s.x1, s.x2), y: Math.min(s.y1, s.y2),
             w: Math.abs(s.x2 - s.x1), h: Math.abs(s.y2 - s.y1) };
}

// Room around the bounds that the stroke, cap or arrow head spills into.
function pad(s) {
    if (s.t === "text" || s.t === "pix") return 0;
    return Math.ceil(strokeWidth(s) / 2 + (s.t === "arrow" ? headLength(s) : 0) + 2);
}

function hit(s, px, py, slop) {
    const b = bounds(s), m = (slop || 0) + pad(s);
    return px >= b.x - m && px <= b.x + b.w + m && py >= b.y - m && py <= b.y + b.h + m;
}

// Topmost shape under the point, or -1.
function pick(shapes, px, py, slop) {
    for (let i = shapes.length - 1; i >= 0; i--)
        if (hit(shapes[i], px, py, slop)) return i;
    return -1;
}

// Keep a box inside the image so a redact never samples outside it.
function clampBox(s, iw, ih) {
    const c = v => Math.max(0, v);
    s.x1 = c(Math.min(iw, s.x1)); s.x2 = c(Math.min(iw, s.x2));
    s.y1 = c(Math.min(ih, s.y1)); s.y2 = c(Math.min(ih, s.y2));
    return s;
}

// Paint one shape on a 2D context whose origin is (ox, oy) in image space.
// Text and pixelation are drawn by QML items, not here.
function paint(ctx, s, ox, oy) {
    ctx.save();
    ctx.translate(-ox, -oy);
    ctx.strokeStyle = s.c;
    ctx.fillStyle = s.c;
    ctx.lineWidth = strokeWidth(s);
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    if (s.t === "hi") ctx.globalAlpha = 0.4;

    if (s.t === "rect") {
        const b = bounds(s);
        ctx.strokeRect(b.x, b.y, b.w, b.h);
    } else if (s.t === "arrow") {
        const dx = s.x2 - s.x1, dy = s.y2 - s.y1, len = Math.hypot(dx, dy);
        if (len > 0.5) {
            const ux = dx / len, uy = dy / len;
            const head = Math.min(headLength(s), len);   // short arrows stay all head
            const bx = s.x2 - ux * head * 0.8, by = s.y2 - uy * head * 0.8;
            ctx.beginPath();
            ctx.moveTo(s.x1, s.y1);
            ctx.lineTo(bx, by);
            ctx.stroke();
            const a = 0.45;   // half-angle of the head, radians
            ctx.beginPath();
            ctx.moveTo(s.x2, s.y2);
            ctx.lineTo(s.x2 - head * (ux * Math.cos(a) - uy * Math.sin(a)),
                       s.y2 - head * (uy * Math.cos(a) + ux * Math.sin(a)));
            ctx.lineTo(s.x2 - head * (ux * Math.cos(a) + uy * Math.sin(a)),
                       s.y2 - head * (uy * Math.cos(a) - ux * Math.sin(a)));
            ctx.closePath();
            ctx.fill();
        }
    } else if (s.t === "pen" || s.t === "hi") {
        const p = s.pts;
        ctx.beginPath();
        if (p.length === 1) {
            ctx.arc(p[0][0], p[0][1], strokeWidth(s) / 2, 0, Math.PI * 2);
            ctx.fill();
        } else {
            ctx.moveTo(p[0][0], p[0][1]);
            // Quadratic through midpoints: smooth without a spline library.
            for (let i = 1; i < p.length - 1; i++)
                ctx.quadraticCurveTo(p[i][0], p[i][1],
                    (p[i][0] + p[i + 1][0]) / 2, (p[i][1] + p[i + 1][1]) / 2);
            ctx.lineTo(p[p.length - 1][0], p[p.length - 1][1]);
            ctx.stroke();
        }
    }
    ctx.restore();
}

// Black or white, whichever reads against the color (text outline).
function contrast(hex) {
    const n = parseInt(hex.slice(1, 7), 16);
    const l = 0.299 * (n >> 16) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255);
    return l > 150 ? "#000000" : "#ffffff";
}
