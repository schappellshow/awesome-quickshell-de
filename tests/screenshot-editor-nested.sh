#!/usr/bin/env bash
# End-to-end check of the screenshot editor in a nested session (never the
# live one). Starts a session from this checkout, opens a large PNG, places
# one of every shape through the `shoteditor` IPC target, exports, and
# verifies the file is the ORIGINAL resolution with the annotations burned
# in (and the redacted region really changed), then stops the session.
#
#   tests/screenshot-editor-nested.sh [session-name]
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
name=${1:-editor-test}
ns="$root/tests/nested-session"
work=$(mktemp -d)
cleanup() { "$ns" stop "$name" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
r() { "$ns" run "$name" -- "$@"; }

"$ns" start "$root" --name "$name" --seed-settings --no-picom >/dev/null
for _ in $(seq 40); do r qs ipc call shoteditor status >/dev/null 2>&1 && break; sleep 0.5; done

# Bigger than the 1600x900 nested screen, so the on-screen zoom is < 100%.
W=2400; H=1500
magick -size ${W}x${H} gradient:'#335577-#ddaa55' -font DejaVu-Sans -pointsize 90 \
    -fill black -annotate +100+300 'Secret: hunter2' -depth 8 "$work/in.png"

# The session reloads once while settling; keep asking until the editor is up.
for _ in $(seq 20); do
    r qs ipc call shoteditor open "$work/in.png" >/dev/null 2>&1 || true
    sleep 1.5
    r qs ipc call shoteditor status 2>/dev/null | grep -q '"visible":true' && break
done
st=$(r qs ipc call shoteditor status)
echo "$st"
zoom=$(echo "$st" | python3 -c 'import json,sys; print(json.load(sys.stdin)["zoom"])')
python3 -c "import sys; sys.exit(0 if float('$zoom') < 1 else 1)" || fail "expected a fitted zoom below 1, got $zoom"

r qs ipc call shoteditor drag rect 80 150 900 400 '#00ff00' 6 >/dev/null
r qs ipc call shoteditor drag arrow 300 1200 900 900 '#ff0000' 10 >/dev/null
r qs ipc call shoteditor drag pen 1200 200 2000 500 '#ffffff' 6 >/dev/null
r qs ipc call shoteditor drag hi 1200 700 2000 800 '#ffff00' 10 >/dev/null
r qs ipc call shoteditor text 1200 1000 'Label' '#ffffff' 10 >/dev/null
r qs ipc call shoteditor drag pix 90 230 880 330 '' 0 >/dev/null
sleep 1
r qs ipc call shoteditor status | grep -q '"shapes":6' || fail "expected 6 shapes"

out="$work/out.png"
r qs ipc call shoteditor exportPng "$out" >/dev/null
for _ in $(seq 20); do [ -s "$out" ] && break; sleep 0.5; done
[ -s "$out" ] || fail "no export written"

dims=$(magick identify -format '%wx%h' "$out")
[ "$dims" = "${W}x${H}" ] || fail "exported $dims, wanted ${W}x${H} (original resolution)"

# Each annotation changed pixels where it was placed...
changed() {  # <geometry> : mean absolute difference vs the original, 0..1
    magick compare -metric MAE "$work/in.png[$1]" "$out[$1]" null: 2>&1 | sed 's/.*(\(.*\))/\1/'
}
for region in "820x20+80+150" "60x60+1550+300" "800x100+1200+700" "200x80+1200+1000" "100x110+300+1100"; do
    d=$(changed "$region" || true)
    python3 -c "import sys; sys.exit(0 if float('${d:-0}') > 0.0005 else 1)" \
        || fail "region $region unchanged by annotations (diff=$d)"
done
# ...an area nothing touched is byte-for-byte the original...
d=$(changed "400x200+1800+1200" || true)
python3 -c "import sys; sys.exit(0 if float('${d:-1}') < 0.0001 else 1)" \
    || fail "untouched area differs (diff=$d)"
# ...and the redact box hid the text (it no longer looks like the original).
d=$(changed "780x80+100+240" || true)
python3 -c "import sys; sys.exit(0 if float('${d:-0}') > 0.005 else 1)" \
    || fail "redact box did not alter the text region (diff=$d)"

# Undo removes the last shape; Save writes a file the same size.
r qs ipc call shoteditor undo >/dev/null
r qs ipc call shoteditor status | grep -q '"shapes":5' || fail "undo did not remove a shape"
r qs ipc call shoteditor save >/dev/null
sleep 3
saved=$(r bash -c 'ls "$HOME"/Pictures/Screenshots/*.png | head -n1')
[ "$(magick identify -format '%wx%h' "$saved")" = "${W}x${H}" ] || fail "saved file is not ${W}x${H}"

echo "PASS: screenshot editor exports ${W}x${H} with annotations burned in"
