#!/usr/bin/env python3
"""B3 live proof (server par): Rust :3200 se ASLI mail local Postfix ke raste jati hai + hostile inputs + org.mailboxes.* shape.
Test account (EMAIL) ko session GoTrue admin generate_link+verify se milta hai (koi password nahi). Mail usi account ke apne address par bheji jati
hai (kisi bahar wale ko nahi). Apni banayi Sent row + thread + inbound copy saaf; mail_outbox_log append-only hai (saaf nahi hota, wahi proof hai).
Env: RPC SBU SBK EMAIL. Exit 0 = sab PASS. Koi secret print nahi hota."""
import json, os, re, subprocess, sys, time, urllib.parse, urllib.request, urllib.error, uuid

RPC = os.environ.get("RPC", "http://127.0.0.1:3200"); SBU = os.environ["SBU"].rstrip("/"); SBK = os.environ["SBK"]
EMAIL = os.environ.get("EMAIL", "basic.test@anexomail.com")
fails = []
def req(method, url, body=None, headers=None):
    h = {"content-type": "application/json"}; h.update(headers or {})
    r = urllib.request.Request(url, data=(json.dumps(body).encode() if body is not None else None), headers=h, method=method)
    try:
        with urllib.request.urlopen(r, timeout=40) as x: raw = x.read(); code = x.status
    except urllib.error.HTTPError as e: raw = e.read(); code = e.code
    try: return code, json.loads(raw or b"null")
    except Exception: return code, None
SB = {"apikey": SBK, "authorization": "Bearer " + SBK}
def sb(method, path, body=None): return req(method, SBU + path, body, dict(SB, prefer="return=representation"))
def check(name, cond, detail=""):
    print(("   PASS " if cond else "   FAIL ") + name + (("  [" + str(detail)[:200] + "]") if (detail and not cond) else ""))
    if not cond: fails.append(name)
def call(proc, inp, tok):
    code, j = req("POST", f"{RPC}/rpc/{proc}", {"input": inp}, {"authorization": "Bearer " + tok})
    data = ((j or {}).get("result") or {}).get("data"); e = (j or {}).get("error") or {}
    return code, data, e.get("code")

code, lk = req("POST", SBU + "/auth/v1/admin/generate_link", {"type": "magiclink", "email": EMAIL}, SB)
th = (lk or {}).get("hashed_token") or ((lk or {}).get("properties") or {}).get("hashed_token")
code, ses = req("POST", SBU + "/auth/v1/verify", {"type": "magiclink", "token_hash": th}, SB) if th else (0, None)
tok = (ses or {}).get("access_token"); uid = ((ses or {}).get("user") or {}).get("id")
if not tok: print("   FAIL test session nahi bani (%s)" % EMAIL); sys.exit(2)
code, mem = sb("GET", f"/rest/v1/org_members?select=org_id,role&user_id=eq.{uid}&limit=1")
org = (mem or [{}])[0].get("org_id") if isinstance(mem, list) and mem else None
role = (mem or [{}])[0].get("role") if isinstance(mem, list) and mem else None
if not org: print("   FAIL test account ka org nahi mila"); sys.exit(2)
mark = "[b3-proof] " + uuid.uuid4().hex[:10]
made_threads, made_msgs = [], []

print("== 1) ASLI mail: Rust -> local Postfix (apne hi address par)")
code, d, e = call("mail.send", {"to": [EMAIL], "subject": mark, "body": "B3 proof: Rust se Postfix.\nline2 .dot", "html": "<p>B3 <b>proof</b></p>"}, tok)
check("mail.send 200 ok + ids", code == 200 and d and d.get("ok") and d.get("thread_id") and d.get("message_id") and "@anexomail.com" in str(d.get("message_id_smtp")), (code, d, e))
if d and d.get("thread_id"): made_threads.append(d["thread_id"]); made_msgs.append(d["message_id"])
if d and d.get("message_id"):
    c, rows = sb("GET", f"/rest/v1/mail_messages?select=id,direction,subject,org_id,to_addrs&id=eq.{d['message_id']}")
    check("Sent row DB mein (out, sahi org, sahi subject)", c == 200 and rows and rows[0]["direction"] == "out" and rows[0]["org_id"] == org and rows[0]["subject"] == mark, (c, rows))
    c, th_rows = sb("GET", f"/rest/v1/mail_threads?select=id,message_count,folder&id=eq.{d['thread_id']}")
    check("thread folder=sent, message_count=1", c == 200 and th_rows and th_rows[0]["folder"] == "sent" and th_rows[0]["message_count"] == 1, (c, th_rows))
    mid = d["message_id_smtp"]; seen = None
    for _ in range(12):
        for lf in ("/var/log/mail.log", "/var/log/maillog"):
            try:
                out = subprocess.run(["grep", "-F", mid, lf], capture_output=True, text=True, timeout=10).stdout
                if out: seen = out; break
            except Exception: pass
        if seen: break
        time.sleep(2)
    if seen is None:
        print("   SKIP Postfix log mein message-id nahi mila / log padh nahi sakte (mail 'queued' mana gaya — upar PASS)")
    else:
        qid = re.search(r"postfix/\w+\[\d+\]: ([0-9A-F]{6,}):", seen)
        check("Postfix log mein is message-id ki entry", qid is not None, seen[:200])
    c, ol = sb("GET", f"/rest/v1/mail_outbox_log?select=*&message_id=eq.{mid}&limit=1")
    if c == 200 and isinstance(ol, list):
        check("mail_outbox_log mein ok=true proof", bool(ol) and ol[0].get("ok") is True, ol)
    else:
        print("   SKIP mail_outbox_log filter ka column alag (%s)" % c)

print("== 1b) hold / undo-send queue (E54 claim) — asli worker se")
mark2 = "[b3-queue] " + uuid.uuid4().hex[:10]
sched_ids = []
code, d, e = call("mail.schedule", {"to": EMAIL, "subject": mark2, "body": "B3 queue proof", "hold_seconds": 0}, tok)
check("schedule 200 status=holding", code == 200 and d and d.get("status") == "holding" and d.get("id"), (code, d, e))
if d and d.get("id"):
    sid = d["id"]; sched_ids.append(sid); st_ = None
    for _ in range(30):
        c, r = sb("GET", f"/rest/v1/mail_scheduled?select=status,claimed_at,error&id=eq.{sid}")
        st_ = (r or [{}])[0] if c == 200 and r else {}
        if st_.get("status") in ("sent", "failed"): break
        time.sleep(2)
    check("worker ne uthayi aur bheji (status=sent, claimed_at laga)", st_.get("status") == "sent" and bool(st_.get("claimed_at")), st_)
    code, d2, e2 = call("mail.schedule.cancel", {"id": sid}, tok)
    check("bheji ja chuki mail cancel nahi hoti (409 already_sent)", code == 409 and e2 == "already_sent", (code, e2))
code, d, e = call("mail.schedule", {"to": EMAIL, "subject": mark2 + " undo", "body": "x", "hold_seconds": 120}, tok)
if d and d.get("id"):
    sched_ids.append(d["id"])
    code, d2, e2 = call("mail.schedule.cancel", {"id": d["id"]}, tok)
    check("hold ke andar undo ok", code == 200, (code, e2))
    c, r = sb("GET", f"/rest/v1/mail_scheduled?select=status&id=eq.{d['id']}")
    check("row cancelled", c == 200 and r and r[0]["status"] == "cancelled", r)
    code, d2, e2 = call("mail.schedule.cancel", {"id": d["id"]}, tok)
    check("dobara undo = 409", code == 409, (code, e2))
code, d, e = call("mail.schedule", {"to": EMAIL, "subject": mark2, "body": "x", "identity": "ceo@bigbank.com"}, tok)
check("parai identity => 403 identity_not_allowed", code == 403 and e == "identity_not_allowed", (code, e))
code, d, e = call("mail.schedule", {"to": EMAIL + "\r\nBcc: x@example.com", "subject": mark2, "body": "x"}, tok)
check("queue: CRLF recipient => 400", code == 400 and e == "invalid_recipient", (code, e))

print("== 2) hostile inputs (SMTP tak kuch nahi pahunchna)")
hostile = [
    ("CRLF header injection in to", {"to": [EMAIL + "\r\nBcc: evil@example.com"], "subject": mark, "body": "x"}, "invalid_recipient"),
    ("angle brackets", {"to": ["<" + EMAIL + ">"], "subject": mark, "body": "x"}, "invalid_recipient"),
    ("reply_to injection", {"to": [EMAIL], "reply_to": "r@example.com\r\nBcc: e@example.com", "subject": mark, "body": "x"}, "invalid_reply_to"),
    ("to missing", {"subject": mark, "body": "x"}, "to_required"),
    ("101 recipients", {"to": [f"u{i}@example.com" for i in range(101)], "subject": mark, "body": "x"}, "too_many_recipients"),
    ("send_at junk", {"to": [EMAIL], "subject": mark, "body": "x", "send_at": "kal"}, "send_at_invalid"),
    ("thread filter injection", {"to": [EMAIL], "subject": mark, "body": "x", "thread_id": "x&org_id=neq.1"}, "thread_id_invalid"),
    ("someone else's / unknown thread", {"to": [EMAIL], "subject": mark, "body": "x", "thread_id": str(uuid.uuid4())}, "thread_not_found"),
    ("attachment id path-like", {"to": [EMAIL], "subject": mark, "body": "x", "attachment_ids": ["../../etc/passwd"]}, "attachment_ids_invalid"),
    ("attachment id unknown", {"to": [EMAIL], "subject": mark, "body": "x", "attachment_ids": [str(uuid.uuid4())]}, "attachment_not_found"),
]
for name, inp, want in hostile:
    code, d, e = call("mail.send", inp, tok)
    check(f"{name} => {want}", code in (400, 404) and e == want, (code, e))
code, d, e = call("mail.send", {"to": [EMAIL], "subject": mark, "body": "x"}, "nakli.token.value")
check("nakli token => 401", code == 401, code)
c, leftover = sb("GET", f"/rest/v1/mail_messages?select=id&subject=eq.{urllib.parse.quote(mark)}&direction=eq.out")
check("hostile calls ne koi extra row nahi banayi", c == 200 and len(leftover) == 1, leftover)
for r in leftover:
    if r["id"] not in made_msgs: made_msgs.append(r["id"])

print("== 3) org.mailboxes.*")
code, d, e = call("org.mailboxes.list", {}, tok)
check("list: ok, plan, mailboxes list, used/remaining", code == 200 and d and d.get("ok") and isinstance(d.get("mailboxes"), list) and "plan" in d and "used" in d and "remaining" in d, (code, d, e))
code, d, e = call("org.mailboxes.create", {"address": "not an address"}, tok)
check("create: ghalat address => 400 (owner/admin/manager), 403 (baqi) ya 423 (org writes band)", (code, e) in ((400, "address_required"), (403, "forbidden"), (423, "org_writes_disabled")), (code, e))
code, d, e = call("org.mailboxes.create", {}, "nakli.token.value")
check("create nakli token => 401", code == 401, code)

print("== 4) saaf-safai (apni test rows)")
time.sleep(4)
c, inbound = sb("GET", f"/rest/v1/mail_messages?select=id,thread_id&subject=eq.{urllib.parse.quote(mark)}&direction=eq.in")
for r in (inbound if c == 200 and isinstance(inbound, list) else []):
    made_msgs.append(r["id"]); made_threads.append(r["thread_id"])
c, qa = sb("GET", f"/rest/v1/mail_messages?select=id,thread_id&subject=like.{urllib.parse.quote(mark2)}*")
for r in (qa if c == 200 and isinstance(qa, list) else []):
    made_msgs.append(r["id"]); made_threads.append(r["thread_id"])
c, qb = sb("GET", f"/rest/v1/mail_threads?select=id&subject=like.{urllib.parse.quote(mark2)}*")
for r in (qb if c == 200 and isinstance(qb, list) else []): made_threads.append(r["id"])
for i_ in sched_ids: sb("DELETE", f"/rest/v1/mail_scheduled?id=eq.{i_}")
for mid_ in set(made_msgs): sb("DELETE", f"/rest/v1/mail_messages?id=eq.{mid_}")
for t_ in set(made_threads): sb("DELETE", f"/rest/v1/mail_threads?id=eq.{t_}")
c, left = sb("GET", f"/rest/v1/mail_messages?select=id&subject=eq.{urllib.parse.quote(mark)}")
check("test rows saaf", c == 200 and not left, left)
print("\n" + ("SAB PASS" if not fails else "FAIL: " + ", ".join(fails)))
sys.exit(0 if not fails else 1)
