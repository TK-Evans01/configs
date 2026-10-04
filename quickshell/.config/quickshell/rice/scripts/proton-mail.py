#!/usr/bin/env python3
"""Unread mail from Proton Mail Bridge (local IMAP) as one JSON line.

Credentials: ~/.config/rice/proton-bridge.netrc (chmod 600, never in git)
    machine 127.0.0.1 login <bridge username> password <bridge password>
Opens INBOX read-only and fetches headers with BODY.PEEK: never marks mail read.

Output: {"state": "ok", "unread": N, "total": N, "messages": [{uid, from, subject, date}]}
        {"state": "unconfigured" | "offline" | "error", "error": "..."}
"""
import email.header
import email.utils
import imaplib
import json
import netrc
import os
import ssl
import sys

CFG = os.path.expanduser("~/.config/rice/proton-bridge.netrc")
HOST = "127.0.0.1"
PORT = int(os.environ.get("BRIDGE_IMAP_PORT", "1143"))
LIMIT = int(os.environ.get("MAIL_LIMIT", "12"))


def done(**kw):
    print(json.dumps(kw))
    sys.exit(0)


def decode(value):
    try:
        return str(email.header.make_header(email.header.decode_header(value or ""))).strip()
    except Exception:
        return (value or "").strip()


if not os.path.exists(CFG):
    done(state="unconfigured")
try:
    auth = netrc.netrc(CFG).authenticators(HOST)
except Exception as exc:
    done(state="error", error=f"netrc: {exc}")
if not auth:
    done(state="error", error=f"no 'machine {HOST}' entry in {CFG}")
login, _, password = auth

# Bridge serves a self-signed cert on localhost.
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

try:
    imap = imaplib.IMAP4(HOST, PORT, timeout=10)
except (ConnectionRefusedError, OSError):
    done(state="offline")
try:
    imap.starttls(ctx)
    imap.login(login, password)
    typ, data = imap.select("INBOX", readonly=True)
    total = int(data[0]) if typ == "OK" else 0
    typ, data = imap.uid("search", None, "UNSEEN")
    uids = data[0].split() if typ == "OK" and data[0] else []
    messages = []
    if uids:
        want = b",".join(uids[-LIMIT:])
        typ, data = imap.uid("fetch", want, "(UID BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])")
        for part in data:
            if not isinstance(part, tuple):
                continue
            meta, raw = part
            uid = meta.split(b"UID ")[1].split()[0].decode() if b"UID " in meta else ""
            msg = email.message_from_bytes(raw)
            name, addr = email.utils.parseaddr(decode(msg.get("From")))
            try:
                when = email.utils.parsedate_to_datetime(msg.get("Date")).timestamp()
            except Exception:
                when = 0
            messages.append({
                "uid": uid,
                "from": name or addr,
                "address": addr,
                "subject": decode(msg.get("Subject")) or "(no subject)",
                "date": when,
            })
    messages.sort(key=lambda m: m["date"], reverse=True)
    imap.logout()
    done(state="ok", unread=len(uids), total=total, messages=messages)
except imaplib.IMAP4.error as exc:
    done(state="error", error=str(exc))
except Exception as exc:
    done(state="error", error=f"{type(exc).__name__}: {exc}")
