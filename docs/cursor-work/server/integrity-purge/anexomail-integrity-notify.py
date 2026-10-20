#!/usr/bin/env python3
"""ANEXOMAIL — integrity notices bhejna (warn / block / 24h reminder / deleted). Har 5 minute (systemd timer).
Supabase RPC `account_integrity_notice_claim` se pending notice leta hai, local Postfix (127.0.0.1:25, DKIM signing, koi SMTP password nahi)
se bhejta hai, phir `account_integrity_notice_done`. Bhejne ke baad SQL pate mita deta hai. Secret print nahi hota. Sirf stdlib."""
import json, os, smtplib, ssl, sys, time, urllib.request, uuid
from email.message import EmailMessage
from email.utils import formatdate, make_msgid

ENV_FILE = os.environ.get("ENV_FILE", "/opt/anexomail-web/.env")
SMTP_HOST = os.environ.get("MAIL_SMTP_HOST", "127.0.0.1")
SMTP_PORT = int(os.environ.get("MAIL_SMTP_PORT", "25"))
FROM = os.environ.get("NOTICE_FROM", "ANEXOMAIL <noreply@anexomail.com>")
REPLY_TO = "resolved@anexomail.com"


def load_env(path):
    try:
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    except OSError:
        pass


def rpc(url, key, name, body):
    req = urllib.request.Request(f"{url}/rest/v1/rpc/{name}", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode() or "null")


def build(n):
    m = EmailMessage()
    m["From"], m["To"], m["Subject"] = FROM, ", ".join(n["to"]), n["subject"]
    m["Reply-To"] = REPLY_TO
    m["Date"] = formatdate(localtime=False)
    m["Message-ID"] = make_msgid(idstring=uuid.uuid4().hex[:12], domain="anexomail.com")
    m["Auto-Submitted"] = "auto-generated"
    m.set_content(n["body"])
    return m


def send(msg):
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as s:
        s.send_message(msg)


def main():
    load_env(ENV_FILE)
    url = os.environ.get("SUPABASE4_URL") or os.environ.get("SUPABASE_URL") or ""
    key = os.environ.get("SUPABASE4_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    if not url or not key:
        print("integrity-notify: Supabase env nahi mila (%s)" % ENV_FILE); return 2
    try:
        res = rpc(url, key, "account_integrity_notice_claim", {"_limit": 20})
    except Exception as e:  # SQL E46 na chala ho to bhi kuch nahi tootta
        print("integrity-notify: claim fail (E46 chala hai?): %s" % str(e)[:160]); return 1
    notices = (res or {}).get("notices") or []
    sent = failed = 0
    for n in notices:
        try:
            send(build(n)); ok, err = True, None
        except Exception as e:
            ok, err = False, str(e)[:250]
        try:
            rpc(url, key, "account_integrity_notice_done", {"_id": n["id"], "_ok": ok, "_err": err})
        except Exception as e:
            print("integrity-notify: done fail id=%s: %s" % (n["id"], str(e)[:120]))
        sent += 1 if ok else 0; failed += 0 if ok else 1
    print("integrity-notify %s claimed=%d sent=%d failed=%d" % (time.strftime("%FT%TZ", time.gmtime()), len(notices), sent, failed))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
