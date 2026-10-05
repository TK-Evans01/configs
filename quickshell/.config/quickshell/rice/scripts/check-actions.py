#!/usr/bin/env python3
"""Check config/actions.json against the IpcHandler in shell.qml.

Every action must call an existing IPC function with the right number of
arguments, ids must be unique. Exit 1 on any problem.
    scripts/check-actions.py
"""
import json, re, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
shell = (root / "shell.qml").read_text()
ipc = shell[shell.index("IpcHandler"):]
fns = {m.group(1): [a for a in m.group(2).split(",") if a.strip()]
       for m in re.finditer(r"function\s+(\w+)\s*\(([^)]*)\)", ipc)}

actions = json.loads((root / "config/actions.json").read_text())["actions"]
bad, seen = [], set()
for a in actions:
    if a["id"] in seen:
        bad.append(f"{a['id']}: duplicate id")
    seen.add(a["id"])
    fn, args = a["call"][0], a["call"][1:]
    if fn not in fns:
        bad.append(f"{a['id']}: no IPC function {fn}()")
    elif len(args) != len(fns[fn]):
        bad.append(f"{a['id']}: {fn}() takes {len(fns[fn])} args, got {len(args)}")
    if a.get("confirm", "none") not in ("none", "confirm"):
        bad.append(f"{a['id']}: confirm must be none|confirm")

for b in bad:
    print(b)
print(f"{len(actions)} actions, {len(fns)} IPC functions, {len(bad)} problems")
sys.exit(1 if bad else 0)
