#!/usr/bin/env python3
"""Wallpaper library for the shell (services/Wallpaper.qml). One-shot; JSON out.

    wallpaper.py index [--dir D]        incremental: thumbs, colours, theme fit, season guess
    wallpaper.py set <path> [--output NAME|all] [--placement crop|fit|span] [--transition T]
    wallpaper.py bootstrap [--write]    suggest themes / seasons for untagged images

Files:
    ~/.cache/rice/wallpapers/index.json      computed (rebuildable): sha, size, swatch, dist, season guess
    ~/.cache/rice/wallpapers/thumbs/*.webp   s = 360 px wide strip thumb, m = 1280 px preview
    ~/.cache/rice/wallpapers/span/*.png      per-monitor slices for "span"
    rice/data/wallpapers.json                yours (in git): themes, seasons, tags, fav — keyed by path
                                             relative to the library, with sha to re-link renames
    ~/.local/state/rice/wallpaper.json       what's shown where, recent history, use counts
"""
import argparse, hashlib, json, os, subprocess, sys, time
from pathlib import Path

HOME = Path.home()
RICE = Path(__file__).resolve().parent.parent
CACHE = HOME / ".cache/rice/wallpapers"
THUMBS = CACHE / "thumbs"
SPAN = CACHE / "span"
INDEX = CACHE / "index.json"
CURATED = RICE / "data/wallpapers.json"
STATE = HOME / ".local/state/rice/wallpaper.json"
EXTS = {".jpg", ".jpeg", ".png", ".webp"}
SEASONS = ["spring", "summer", "autumn", "winter"]


def load(p, default):
    try:
        return json.loads(Path(p).read_text())
    except Exception:
        return default


def save(p, data):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
    tmp.replace(p)


# --- colour --------------------------------------------------------------

def to_lab(rgb):
    """(n,3) uint8 sRGB → (n,3) CIE Lab (D65)."""
    import numpy as np
    c = rgb.astype("float64") / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]]).T
    xyz /= np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]), 200 * (f[:, 1] - f[:, 2])], axis=1)


def hexlab(h):
    import numpy as np
    h = h.lstrip("#")[-6:]
    return to_lab(np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)]], dtype="uint8"))[0]


def kmeans(lab, k=6, iters=12):
    import numpy as np
    rng = np.random.default_rng(1)
    cent = lab[rng.choice(len(lab), k, replace=False)]
    for _ in range(iters):
        d = ((lab[:, None, :] - cent[None, :, :]) ** 2).sum(2)
        lbl = d.argmin(1)
        for j in range(k):
            pts = lab[lbl == j]
            if len(pts):
                cent[j] = pts.mean(0)
    w = np.bincount(lbl, minlength=k) / len(lab)
    order = w.argsort()[::-1]
    return cent[order], w[order]


def lab_to_hex(lab):
    import numpy as np
    L, a, b = lab
    fy = (L + 16) / 116; fx = fy + a / 500; fz = fy - b / 200
    inv = lambda t: t ** 3 if t ** 3 > 0.008856 else (t - 16 / 116) / 7.787
    xyz = np.array([inv(fx) * 0.95047, inv(fy), inv(fz) * 1.08883])
    rgb = xyz @ np.array([[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]]).T
    rgb = np.where(rgb > 0.0031308, 1.055 * np.clip(rgb, 0, None) ** (1 / 2.4) - 0.055, 12.92 * rgb)
    return "#" + "".join(f"{int(max(0, min(1, v)) * 255 + 0.5):02x}" for v in rgb)


def theme_palettes():
    """theme id → Lab array of its background ramp + text + hues."""
    import numpy as np
    out = {}
    for f in sorted((RICE / "themes").glob("*.json")):
        if f.stem == "fonts":
            continue
        t = load(f, {})
        p = t.get("palette", {})
        cols = []
        for k in ("bg0", "bg1", "bg2", "bg3", "bg4", "fg0", "fg1", "grey", "red", "orange", "yellow", "green", "aqua", "blue", "purple"):
            v = p.get(k)
            if isinstance(v, list):
                v = v[0]
            if v:
                cols.append(hexlab(v))
        if cols:
            out[f.stem] = np.array(cols)
    return out


def analyse(path, palettes):
    import numpy as np
    from PIL import Image
    with Image.open(path) as im:
        w, h = im.size
        small = im.convert("RGB")
        small.thumbnail((96, 96))
        px = np.asarray(small).reshape(-1, 3)
    lab = to_lab(px)
    cent, wt = kmeans(lab)
    chroma = np.hypot(lab[:, 1], lab[:, 2])
    hue = (np.degrees(np.arctan2(lab[:, 2], lab[:, 1])) + 360) % 360
    # Fit to a theme: weighted mean of each swatch colour's nearest palette colour (ΔE76).
    dist = {}
    for tid, pal in palettes.items():
        d = np.sqrt(((cent[:, None, :] - pal[None, :, :]) ** 2).sum(2)).min(1)
        dist[tid] = round(float((d * wt).sum()), 1)
    # Season guess from colour shares (paintings mostly land on "any").
    green = float(((chroma > 15) & (hue > 95) & (hue < 170)).mean())
    warm = float(((chroma > 20) & ((hue < 75) | (hue > 340))).mean())
    snow = float(((lab[:, 0] > 82) & (chroma < 8)).mean())
    guess = []
    if snow > 0.25: guess.append("winter")
    if green > 0.25: guess += ["spring", "summer"]
    if warm > 0.30: guess.append("autumn")
    return {
        "w": w, "h": h,
        "L": round(float(lab[:, 0].mean()), 1), "chroma": round(float(chroma.mean()), 1),
        "swatch": [{"hex": lab_to_hex(c), "w": round(float(x), 3)} for c, x in zip(cent, wt)],
        "dist": dict(sorted(dist.items(), key=lambda kv: kv[1])),
        "season": {"guess": guess or ["any"], "green": round(green, 3), "warm": round(warm, 3), "snow": round(snow, 3)},
    }


def sha12(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:12]


def thumbs(path, sha):
    from PIL import Image
    THUMBS.mkdir(parents=True, exist_ok=True)
    out = {}
    with Image.open(path) as im:
        im = im.convert("RGB")
        for tag, width in (("s", 360), ("m", 1280)):
            p = THUMBS / f"{sha}-{tag}.webp"
            if not p.exists():
                t = im.copy()
                t.thumbnail((width, width * 2))
                t.save(p, "WEBP", quality=82, method=4)
            out[tag] = str(p)
    return out


def palettes_hash():
    h = hashlib.sha1()
    for f in sorted((RICE / "themes").glob("*.json")):
        h.update(f.read_bytes())
    return h.hexdigest()[:8]


def cmd_index(a):
    root = Path(a.dir).expanduser()
    old = load(INDEX, {})
    items_old = old.get("items", {})
    ph = palettes_hash()
    palettes = None
    items = {}
    for p in sorted(root.rglob("*")):
        if p.suffix.lower() not in EXTS or not p.is_file():
            continue
        key = str(p.relative_to(root))
        st = p.stat()
        prev = items_old.get(key)
        if prev and prev.get("mtime") == int(st.st_mtime) and prev.get("bytes") == st.st_size \
                and old.get("themesHash") == ph and all(Path(v).exists() for v in prev.get("thumbs", {}).values()):
            items[key] = prev
            continue
        if palettes is None:
            palettes = theme_palettes()
        try:
            e = analyse(p, palettes)
        except Exception as ex:
            print(f"skip {key}: {ex}", file=sys.stderr)
            continue
        sha = prev["sha"] if prev and prev.get("mtime") == int(st.st_mtime) else sha12(p)
        e.update({"sha": sha, "mtime": int(st.st_mtime), "bytes": st.st_size, "path": str(p),
                  "folder": str(p.parent.relative_to(root)) if p.parent != root else "",
                  "thumbs": thumbs(p, sha)})
        items[key] = e
    # Drop thumbs of images that are gone.
    live = {e["sha"] for e in items.values()}
    if THUMBS.exists():
        for t in THUMBS.glob("*.webp"):
            if t.name.split("-")[0] not in live:
                t.unlink(missing_ok=True)
    idx = {"schema": 1, "root": str(root), "built": int(time.time()), "themesHash": ph, "items": items}
    save(INDEX, idx)
    print(json.dumps(idx))


# --- applying --------------------------------------------------------------

def monitors():
    try:
        ms = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True).stdout)
    except Exception:
        return []
    return sorted(ms, key=lambda m: (m["x"], m["y"]))


def span_slices(src, mons):
    """Scale to the desktop height, centre-crop to the full width, cut per monitor."""
    from PIL import Image
    if len(mons) < 2 or len({m["y"] for m in mons}) != 1 or len({m["height"] for m in mons}) != 1:
        return None
    sw, sh = sum(m["width"] for m in mons), mons[0]["height"]
    SPAN.mkdir(parents=True, exist_ok=True)
    tag = hashlib.sha1(f"{src}:{sw}x{sh}".encode()).hexdigest()[:12]
    out = {m["name"]: SPAN / f"{tag}-{m['name']}.png" for m in mons}
    if not all(p.exists() for p in out.values()):
        with Image.open(src) as im:
            nw = round(im.width * sh / im.height)
            im = im.convert("RGB").resize((max(nw, sw), sh if nw >= sw else round(im.height * sw / im.width)), Image.LANCZOS)
            x0, y0 = (im.width - sw) // 2, (im.height - sh) // 2
            im = im.crop((x0, y0, x0 + sw, y0 + sh))
            off = 0
            for m in mons:
                im.crop((off, 0, off + m["width"], sh)).save(out[m["name"]])
                off += m["width"]
    for f in SPAN.glob("*.png"):
        if f not in out.values():
            f.unlink(missing_ok=True)
    return out


def awww(img, output=None, resize="crop", transition="fade"):
    cmd = ["awww", "img", str(img), "--resize", resize,
           "--transition-type", transition, "--transition-duration", "1.5", "--transition-fps", "60"]
    if output:
        cmd += ["-o", output]
    return subprocess.run(cmd, capture_output=True, text=True)


def cmd_set(a):
    src = Path(a.path).expanduser()
    if not src.is_file():
        sys.exit(f"no such file: {src}")
    if subprocess.run(["pgrep", "-x", "awww-daemon"], capture_output=True).returncode != 0:
        subprocess.Popen(["setsid", "-f", "awww-daemon"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.6)
    mons = monitors()
    names = [m["name"] for m in mons]
    state = load(STATE, {"outputs": {}, "history": [], "uses": {}})
    shown = {}
    if a.placement == "span":
        sl = span_slices(src, mons)
        if sl:
            for n, p in sl.items():
                awww(p, n, "crop", a.transition)
                shown[n] = str(src)
    if not shown:
        targets = names if a.output in ("all", "") else [a.output]
        resize = "fit" if a.placement == "fit" else "crop"
        for n in targets:
            r = awww(src, n, resize, a.transition)
            if r.returncode != 0:
                sys.exit(r.stderr.strip() or "awww failed")
            shown[n] = str(src)
    state["outputs"].update({n: {"path": p, "placement": a.placement} for n, p in shown.items()})
    key = str(src)
    state["history"] = ([key] + [h for h in state.get("history", []) if h != key])[:30]
    u = state.setdefault("uses", {}).setdefault(key, {"n": 0, "last": 0})
    u["n"] += 1
    u["last"] = int(time.time())
    save(STATE, state)
    print(json.dumps({"shown": shown, "placement": a.placement}))


# --- bootstrap tags ----------------------------------------------------------

def cmd_bootstrap(a):
    idx = load(INDEX, {})
    cur = load(CURATED, {"schema": 1, "items": {}})
    items = cur.setdefault("items", {})
    changed = 0
    for key, e in idx.get("items", {}).items():
        rec = items.get(key)
        if rec is None:
            # Re-link a renamed file by content hash.
            old = next((k for k, r in items.items() if r.get("sha") == e["sha"]), None)
            if old:
                items[key] = items.pop(old)
                rec = items[key]
        if rec is None:
            rec = items[key] = {"sha": e["sha"], "themes": [], "seasons": [], "tags": [], "fav": False,
                                "auto": {"themes": True, "seasons": True}, "reviewed": False}
        rec["sha"] = e["sha"]
        auto = rec.setdefault("auto", {"themes": True, "seasons": True})
        if auto.get("themes"):
            best = list(e["dist"].items())
            top = best[0][1] if best else 0
            new = [t for t, d in best if d <= top + 4][:3]
            if new != rec.get("themes"):
                rec["themes"] = new; changed += 1
        if auto.get("seasons"):
            new = e["season"]["guess"]
            if new != rec.get("seasons"):
                rec["seasons"] = new; changed += 1
    cur["items"] = dict(sorted(items.items()))
    if a.write:
        save(CURATED, cur)
    print(json.dumps({"changed": changed, "written": a.write, "count": len(items)}))


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    i = sp.add_parser("index"); i.add_argument("--dir", default=str(HOME / "Pictures/Wallpapers"))
    s = sp.add_parser("set"); s.add_argument("path"); s.add_argument("--output", default="all")
    s.add_argument("--placement", default="crop", choices=["crop", "fit", "span"])
    s.add_argument("--transition", default="fade")
    b = sp.add_parser("bootstrap"); b.add_argument("--write", action="store_true")
    a = ap.parse_args()
    {"index": cmd_index, "set": cmd_set, "bootstrap": cmd_bootstrap}[a.cmd](a)


if __name__ == "__main__":
    main()
