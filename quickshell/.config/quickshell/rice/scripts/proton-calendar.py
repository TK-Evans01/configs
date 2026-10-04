#!/usr/bin/env python3
"""Events from a Proton Calendar share link (ICS) as one JSON line.

Link: ~/.config/rice/proton-calendar.url (chmod 600, never in git) — Proton
Calendar › Settings › calendar › "Share via link". Anyone holding the link can
read the calendar, so it only lives in that file.

Expands recurrences (RRULE / EXDATE / RECURRENCE-ID overrides) from yesterday
to +DAYS days, converts TZIDs to local time, caches the result so the shell
still shows events offline.

Output: {"state": "ok"|"stale", "events": [{start, end, allDay, title, location}]}
        {"state": "unconfigured" | "error", "error": "..."}
"""
import datetime as dt
import json
import os
import re
import sys
import urllib.request
from zoneinfo import ZoneInfo

from dateutil import rrule

URL_FILE = os.path.expanduser("~/.config/rice/proton-calendar.url")
CACHE = os.path.expanduser("~/.cache/quickshell/calendar.json")
DAYS = int(os.environ.get("CAL_DAYS", "60"))
LOCAL = dt.datetime.now().astimezone().tzinfo


def done(**kw):
    print(json.dumps(kw))
    sys.exit(0)


def unescape(v):
    return re.sub(r"\\([\;,nN])", lambda m: "\n" if m.group(1) in "nN" else m.group(1), v)


def parse_props(lines):
    """[(NAME, {PARAM: value}, value)] from unfolded lines."""
    out = []
    for line in lines:
        if ":" not in line:
            continue
        head, value = line.split(":", 1)
        parts = head.split(";")
        params = {}
        for p in parts[1:]:
            if "=" in p:
                k, v = p.split("=", 1)
                params[k.upper()] = v.strip('"')
        out.append((parts[0].upper(), params, value))
    return out


def to_dt(value, params):
    """(aware datetime, all_day)."""
    value = value.strip()
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        d = dt.datetime.strptime(value[:8], "%Y%m%d")
        return d.replace(tzinfo=LOCAL), True
    if value.endswith("Z"):
        return dt.datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=dt.timezone.utc), False
    naive = dt.datetime.strptime(value[:15], "%Y%m%dT%H%M%S")
    tz = LOCAL
    if "TZID" in params:
        try:
            tz = ZoneInfo(params["TZID"])
        except Exception:
            tz = LOCAL
    return naive.replace(tzinfo=tz), False


def fix_until(rule, tzinfo):
    """dateutil wants UNTIL in UTC when DTSTART is aware."""
    def repl(m):
        v = m.group(1)
        if v.endswith("Z"):
            return "UNTIL=" + v
        if len(v) == 8:
            d = dt.datetime.strptime(v, "%Y%m%d").replace(hour=23, minute=59, second=59, tzinfo=tzinfo)
        else:
            d = dt.datetime.strptime(v[:15], "%Y%m%dT%H%M%S").replace(tzinfo=tzinfo)
        return "UNTIL=" + d.astimezone(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return re.sub(r"UNTIL=([0-9TZ]+)", repl, rule)


def events_from(ics, start_win, end_win):
    lines = []
    for raw in ics.replace("\r\n", "\n").split("\n"):
        if raw[:1] in (" ", "\t") and lines:
            lines[-1] += raw[1:]
        else:
            lines.append(raw)

    blocks, cur = [], None
    for line in lines:
        if line == "BEGIN:VEVENT":
            cur = []
        elif line == "END:VEVENT" and cur is not None:
            blocks.append(parse_props(cur))
            cur = None
        elif cur is not None:
            cur.append(line)

    masters, overrides = {}, []
    for props in blocks:
        ev = {"exdates": [], "rrule": None}
        for name, params, value in props:
            if name == "DTSTART":
                ev["start"], ev["allDay"] = to_dt(value, params)
            elif name == "DTEND":
                ev["end"], _ = to_dt(value, params)
            elif name == "DURATION":
                m = re.fullmatch(r"P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?", value)
                if m:
                    w, d, h, mi, s = (int(x or 0) for x in m.groups())
                    ev["duration"] = dt.timedelta(weeks=w, days=d, hours=h, minutes=mi, seconds=s)
            elif name == "SUMMARY":
                ev["title"] = unescape(value)
            elif name == "LOCATION":
                ev["location"] = unescape(value)
            elif name == "UID":
                ev["uid"] = value
            elif name == "RRULE":
                ev["rrule"] = value
            elif name == "EXDATE":
                for v in value.split(","):
                    ev["exdates"].append(to_dt(v, params)[0])
            elif name == "RECURRENCE-ID":
                ev["recurrenceId"] = to_dt(value, params)[0]
            elif name == "STATUS":
                ev["status"] = value.upper()
        if "start" not in ev:
            continue
        if "end" not in ev:
            ev["end"] = ev["start"] + ev.get("duration", dt.timedelta(days=1) if ev["allDay"] else dt.timedelta(0))
        if "recurrenceId" in ev:
            overrides.append(ev)
        else:
            masters[ev.get("uid", id(ev))] = ev

    replaced = {(o.get("uid"), o["recurrenceId"]) for o in overrides}
    out = []

    def emit(ev, start):
        if ev.get("status") == "CANCELLED":
            return
        end = start + (ev["end"] - ev["start"])
        if end < start_win or start > end_win:
            return
        out.append({
            "start": start.timestamp(),
            "end": end.timestamp(),
            "allDay": ev["allDay"],
            "title": ev.get("title", "(untitled)"),
            "location": ev.get("location", ""),
        })

    for uid, ev in masters.items():
        if not ev["rrule"]:
            emit(ev, ev["start"])
            continue
        rs = rrule.rruleset()
        try:
            rs.rrule(rrule.rrulestr(fix_until(ev["rrule"], ev["start"].tzinfo), dtstart=ev["start"]))
        except Exception:
            emit(ev, ev["start"])
            continue
        for x in ev["exdates"]:
            rs.exdate(x)
        span = ev["end"] - ev["start"]
        for occ in rs.between(start_win - span, end_win, inc=True):
            if (uid, occ) in replaced:
                continue
            emit(ev, occ)
    for o in overrides:
        emit(o, o["start"])

    out.sort(key=lambda e: (e["start"], not e["allDay"]))
    return out


if not os.path.exists(URL_FILE):
    done(state="unconfigured")
url = open(URL_FILE).read().strip()
if not url:
    done(state="unconfigured")

now = dt.datetime.now(LOCAL)
start_win = (now - dt.timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
end_win = start_win + dt.timedelta(days=DAYS + 1)

try:
    req = urllib.request.Request(url, headers={"User-Agent": "rice-quickshell"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        ics = resp.read().decode("utf-8", "replace")
    if "BEGIN:VCALENDAR" not in ics:
        raise ValueError("not an iCalendar feed")
    events = events_from(ics, start_win, end_win)
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    with open(CACHE, "w") as f:
        json.dump({"fetched": now.timestamp(), "events": events}, f)
    done(state="ok", events=events)
except Exception as exc:
    try:
        cached = json.load(open(CACHE))
        done(state="stale", error=str(exc), events=cached.get("events", []))
    except Exception:
        done(state="error", error=f"{type(exc).__name__}: {exc}")
