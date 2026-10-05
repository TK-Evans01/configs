#!/bin/bash
# Picks a random wallpaper. Images wide enough to span all monitors are
# sliced per-output so a single picture runs continuously across the desktop;
# everything else is displayed on every output as before.
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

# cron gives us no session env, so recover Hyprland's instance signature from
# the runtime dir (newest instance wins) or hyprctl cannot talk to the compositor.
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n1)
    export HYPRLAND_INSTANCE_SIGNATURE
fi

WALLPAPER_DIR="$HOME/Pictures/Wallpapers/dore"
CACHE_DIR="$HOME/.cache/wallpaper-span"
# An image spans only if it is at least this fraction of the full desktop aspect.
SPAN_THRESHOLD=0.85

TRANSITION=(--transition-type fade --transition-duration 2 --transition-fps 60)

pgrep -x awww-daemon >/dev/null || { awww-daemon & sleep 0.5; }

CURRENT=$(awww query 2>/dev/null | awk -F': ' '{print $NF}' | head -n1)
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) ! -path "$CURRENT" | shuf -n 1)
[ -n "$WALLPAPER" ] || exit 0

# Monitor geometry, left-to-right: "NAME X Y W H" per line.
MONITORS=$(hyprctl monitors -j | python3 -c '
import json,sys
for m in sorted(json.load(sys.stdin), key=lambda m: (m["x"], m["y"])):
    print(m["name"], m["x"], m["y"], m["width"], m["height"])
')

SLICES=$(MONITORS="$MONITORS" python3 - "$WALLPAPER" "$CACHE_DIR" "$SPAN_THRESHOLD" <<'PY'
import hashlib, os, sys
from PIL import Image

src, cache_dir, threshold = sys.argv[1], sys.argv[2], float(sys.argv[3])
mons = [l.split() for l in os.environ["MONITORS"].split("\n") if l.strip()]
mons = [(n, int(x), int(y), int(w), int(h)) for n, x, y, w, h in mons]
if len(mons) < 2:
    sys.exit(0)

# Only handle a single horizontal row of monitors.
if len({y for _, _, y, _, h in mons}) != 1 or len({h for *_, h in mons}) != 1:
    sys.exit(0)

span_w = sum(w for *_, w, _ in mons)
span_h = mons[0][4]
with Image.open(src) as im:
    if im.width / im.height < (span_w / span_h) * threshold:
        sys.exit(0)  # not wide enough, let awww handle it normally

    # Scale to the desktop height, then centre-crop to the exact span.
    new_w = round(im.width * span_h / im.height)
    im = im.convert("RGB").resize((new_w, span_h), Image.LANCZOS)
    x0 = (new_w - span_w) // 2
    im = im.crop((x0, 0, x0 + span_w, span_h))

    os.makedirs(cache_dir, exist_ok=True)
    tag = hashlib.sha1(f"{src}:{span_w}x{span_h}".encode()).hexdigest()[:12]
    off = 0
    for name, _, _, w, _ in mons:
        out = os.path.join(cache_dir, f"{tag}-{name}.png")
        im.crop((off, 0, off + w, span_h)).save(out)
        print(f"{name}\t{out}")
        off += w
PY
)

if [ -n "$SLICES" ]; then
    # Purge slices from previous wallpapers so the cache does not grow forever.
    KEEP=$(cut -f2 <<<"$SLICES")
    find "$CACHE_DIR" -type f -name '*.png' | grep -vxF "$KEEP" | xargs -r rm -f
    while IFS=$'\t' read -r output image; do
        awww img "$image" -o "$output" --resize crop "${TRANSITION[@]}"
    done <<<"$SLICES"
else
    awww img "$WALLPAPER" "${TRANSITION[@]}"
fi
