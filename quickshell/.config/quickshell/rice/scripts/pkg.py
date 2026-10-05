#!/usr/bin/env python3
"""Package data for settings › Packages. Read-only, never root; prints JSON.

    pkg.py search <query>        repo (pacman -Ss) + AUR (RPC v5) matches
    pkg.py info <name> <repo|aur>
    pkg.py installed             explicit / foreign (AUR) / orphans
    pkg.py updates               checkupdates (repo) + yay -Qua (AUR), last upgrade time
    pkg.py cache                 pacman cache size, what paccache would remove

Installing / removing is not here: the shell builds the command and runs it
through its installer backend (a terminal today).
"""
import json, re, subprocess, sys, urllib.request, urllib.parse, shutil, os
from datetime import datetime, timezone

AUR = "https://aur.archlinux.org/rpc/v5"


def sh(cmd, timeout=60):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def aur(path, **params):
    url = f"{AUR}/{path}?" + urllib.parse.urlencode(params, doseq=True)
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "rice-pkg/1"}), timeout=10) as r:
            return json.load(r).get("results", [])
    except Exception:
        return None


def installed_set():
    return {l.split()[0]: l.split()[1] for l in sh(["pacman", "-Q"]).splitlines() if l.strip()}


def aur_entry(r, inst):
    return {
        "name": r["Name"], "repo": "aur", "version": r["Version"], "desc": r.get("Description") or "",
        "installed": r["Name"] in inst, "votes": r.get("NumVotes", 0), "popularity": round(r.get("Popularity", 0), 2),
        "maintainer": r.get("Maintainer"), "outOfDate": bool(r.get("OutOfDate")),
        "updated": datetime.fromtimestamp(r.get("LastModified", 0), timezone.utc).strftime("%Y-%m-%d"),
    }


def search(q):
    inst = installed_set()
    repo = []
    lines = sh(["pacman", "-Ss", "--", q]).splitlines()
    for i in range(0, len(lines) - 1, 2):
        m = re.match(r"^(\S+)/(\S+) (\S+)(.*)$", lines[i])
        if not m:
            continue
        repo.append({"name": m[2], "repo": m[1], "version": m[3], "desc": lines[i + 1].strip(),
                     "installed": m[2] in inst, "groups": re.findall(r"\(([^)]*)\)", m[4])})
    # Exact / prefix name matches first, then the rest as pacman orders them.
    ql = q.lower()
    repo.sort(key=lambda p: (p["name"] != ql, not p["name"].startswith(ql)))
    res = aur("search/" + urllib.parse.quote(q), by="name-desc")
    aurl = None if res is None else sorted((aur_entry(r, inst) for r in res),
                                           key=lambda p: (p["name"] != ql, ql not in p["name"].lower(), -p["popularity"]))[:40]
    return {"query": q, "repo": repo[:60], "aur": aurl, "aurError": res is None}


def parse_info(text):
    info, key = {}, None
    for line in text.splitlines():
        m = re.match(r"^([A-Za-z][A-Za-z ]+?)\s*: (.*)$", line)
        if m:
            key = m[1]; info[key] = m[2].strip()
        elif key and line.startswith(" "):
            info[key] += " " + line.strip()
    return info


def info(name, repo):
    inst = installed_set()
    if repo == "aur":
        res = aur("info", **{"arg[]": [name]})
        if not res:
            return {"error": "not found on the AUR"}
        r = res[0]
        e = aur_entry(r, inst)
        e.update({"url": r.get("URL"), "depends": r.get("Depends", []), "makedepends": r.get("MakeDepends", []),
                  "license": ", ".join(r.get("License") or []), "aurPage": f"https://aur.archlinux.org/packages/{name}",
                  "submitted": datetime.fromtimestamp(r.get("FirstSubmitted", 0), timezone.utc).strftime("%Y-%m-%d"),
                  "installedVersion": inst.get(name)})
        return e
    i = parse_info(sh(["pacman", "-Si", name]) or sh(["pacman", "-Qi", name]))
    if not i:
        return {"error": "not found"}
    q = parse_info(sh(["pacman", "-Qi", name])) if name in inst else {}
    none = lambda v: [] if not v or v == "None" else v.split()
    return {
        "name": name, "repo": i.get("Repository", repo), "version": i.get("Version"), "desc": i.get("Description", ""),
        "url": i.get("URL"), "license": i.get("Licenses"), "depends": none(i.get("Depends On")),
        "optional": [d for d in re.split(r"\s{2,}|(?<=\S) (?=[a-z0-9][\w.+-]*:)", i.get("Optional Deps", "")) if d and d != "None"],
        "download": i.get("Download Size"), "size": i.get("Installed Size"), "packager": i.get("Packager"),
        "built": i.get("Build Date"), "installed": name in inst, "installedVersion": inst.get(name),
        "requiredBy": none(q.get("Required By")), "reason": q.get("Install Reason"),
    }


def installed():
    def names(flag):
        return [l.split()[0] for l in sh(["pacman", flag]).splitlines() if l.strip()]
    explicit = {l.split()[0]: l.split()[1] for l in sh(["pacman", "-Qe"]).splitlines() if l.strip()}
    foreign = set(names("-Qm"))
    return {
        "total": len(installed_set()),
        "all": sorted(installed_set()),
        "explicit": [{"name": n, "version": v, "aur": n in foreign} for n, v in sorted(explicit.items())],
        "foreign": sorted(foreign),
        "orphans": [l.strip() for l in sh(["pacman", "-Qdtq"]).splitlines() if l.strip()],
    }


def last_upgrade():
    try:
        with open("/var/log/pacman.log", errors="replace") as f:
            last = None
            for line in f:
                if "starting full system upgrade" in line:
                    last = line[1:line.index("]")]
            return last
    except OSError:
        return None


def updates():
    out = {"repo": [], "aur": [], "lastUpgrade": last_upgrade(), "checkupdates": bool(shutil.which("checkupdates"))}
    if out["checkupdates"]:
        for l in sh(["checkupdates", "--nocolor"], timeout=120).splitlines():
            m = re.match(r"^(\S+) (\S+) -> (\S+)", l)
            if m:
                out["repo"].append({"name": m[1], "from": m[2], "to": m[3]})
    if shutil.which("yay"):
        for l in sh(["yay", "-Qua", "--color", "never"], timeout=120).splitlines():
            m = re.match(r"^(\S+) (\S+) -> (\S+)", l)
            if m:
                out["aur"].append({"name": m[1], "from": m[2], "to": m[3]})
    return out


def cache():
    d = "/var/cache/pacman/pkg"
    total = sum(os.path.getsize(os.path.join(d, f)) for f in os.listdir(d) if os.path.isfile(os.path.join(d, f))) if os.path.isdir(d) else 0
    out = {"bytes": total, "paccache": bool(shutil.which("paccache"))}
    if out["paccache"]:
        # Dry runs: keep the last 2 versions; drop everything for uninstalled packages.
        for key, args in (("keep2", ["-dk2"]), ("uninstalled", ["-duk0"])):
            m = re.search(r"finished dry run: (\d+) candidates? \(disk space saved: ([^)]+)\)", sh(["paccache"] + args))
            out[key] = {"count": int(m[1]), "saves": m[2]} if m else {"count": 0, "saves": "0 B"}
    return out


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else ""
    if cmd == "search" and len(a) > 1:
        r = search(a[1])
    elif cmd == "info" and len(a) > 2:
        r = info(a[1], a[2])
    elif cmd == "installed":
        r = installed()
    elif cmd == "updates":
        r = updates()
    elif cmd == "cache":
        r = cache()
    else:
        print(__doc__, file=sys.stderr); sys.exit(2)
    print(json.dumps(r))


if __name__ == "__main__":
    main()
