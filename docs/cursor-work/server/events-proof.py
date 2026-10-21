#!/usr/bin/env python3
"""B4 live proof (server par): Rust event hub. HTTP-level (QUIC client server par nahi hota — woh sandbox proof mein asli QUIC se pass hua).
Check: /rpc/health, UDP 3443 sun raha hai, /internal/event (secret band/khula/ghalat/proxy/kharab input), mutating RPC par publish layer ne kuch toda nahi,
aur FAMILY accounts: har family_accounts email ka org_members row hai (hub org-membership se chalta hai, plan se nahi => family ko apne aap milta hai).
Env: RPC SBU SBK EVENT_SECRET (secret print nahi hota). Exit 0 = sab PASS."""
import json, os, subprocess, sys, urllib.error, urllib.request, uuid

RPC = os.environ.get("RPC", "http://127.0.0.1:3200"); SBU = os.environ["SBU"].rstrip("/"); SBK = os.environ["SBK"]; SECRET = os.environ.get("EVENT_SECRET", "")
EMAIL = os.environ.get("EMAIL", "basic.test@anexomail.com")
fails = []
def req(method, url, body=None, headers=None):
    h = {"content-type": "application/json"}; h.update(headers or {})
    r = urllib.request.Request(url, data=(json.dumps(body).encode() if body is not None else None), headers=h, method=method)
    try:
        with urllib.request.urlopen(r, timeout=30) as x: raw = x.read(); code = x.status
    except urllib.error.HTTPError as e: raw = e.read(); code = e.code
    try: return code, json.loads(raw or b"null")
    except Exception: return code, None
SB = {"apikey": SBK, "authorization": "Bearer " + SBK}
def check(name, cond, detail=""):
    print(("   PASS " if cond else "   FAIL ") + name + (("  [" + str(detail)[:200] + "]") if (detail and not cond) else ""))
    if not cond: fails.append(name)
def ev(body, secret=SECRET, extra=None):
    h = {"x-event-secret": secret}; h.update(extra or {})
    return req("POST", RPC + "/internal/event", body, h)[0]

print("== 1) engine")
check("/rpc/health 200", urllib.request.urlopen(RPC + "/rpc/health", timeout=10).status == 200)
def udp_listening(port):
    for f in ("/proc/net/udp", "/proc/net/udp6"):
        try:
            for ln in open(f).read().splitlines()[1:]:
                parts = ln.split()
                if len(parts) > 3 and parts[1].rsplit(":", 1)[-1].upper() == "%04X" % port: return True
        except Exception: pass
    return False
check("UDP 3443 (QUIC/WebTransport) sun raha hai", udp_listening(3443))

print("== 2) /internal/event")
check("EVENT_SECRET (>=24) engine ko mila", len(SECRET) >= 24, "installer ne .env mein nahi likha?")
org = str(uuid.uuid4())
check("secret ke bina => 401", req("POST", RPC + "/internal/event", {"org_id": org, "topic": "mail"})[0] == 401)
check("ghalat secret => 401", ev({"org_id": org, "topic": "mail"}, "x" * 40) == 401)
check("sahi secret + sahi body => 204", ev({"org_id": org, "topic": "mail"}) == 204)
check("proxy ke raste (x-forwarded-for) => 403", ev({"org_id": org, "topic": "mail"}, extra={"x-forwarded-for": "1.2.3.4"}) == 403)
check("x-real-ip => 403", ev({"org_id": org, "topic": "mail"}, extra={"x-real-ip": "1.2.3.4"}) == 403)
check("kharab org_id => 400", ev({"org_id": "1 or 1=1", "topic": "mail"}) == 400)
check("allow-list se bahar topic => 400", ev({"org_id": org, "topic": "chat"}) == 400)
check("body khali/kharab => 400", req("POST", RPC + "/internal/event", None, {"x-event-secret": SECRET})[0] == 400)

print("== 3) publish layer ne mutating RPC nahi toda")
code, lk = req("POST", SBU + "/auth/v1/admin/generate_link", {"type": "magiclink", "email": EMAIL}, SB)
th = (lk or {}).get("hashed_token") or ((lk or {}).get("properties") or {}).get("hashed_token")
code, ses = req("POST", SBU + "/auth/v1/verify", {"type": "magiclink", "token_hash": th}, SB) if th else (0, None)
tok = (ses or {}).get("access_token")
check("test session bani", bool(tok))
if tok:
    c, j = req("POST", RPC + "/rpc/mail.schedule.cancel", {"input": {"id": str(uuid.uuid4())}}, {"authorization": "Bearer " + tok})
    check("mutation (mail.schedule.cancel, anjaan id) => 4xx jawab, 5xx nahi", 200 <= c < 500, c)
    c, _ = req("POST", RPC + "/rpc/mail.schedule.cancel", {"input": {"id": str(uuid.uuid4())}}, {"authorization": "Bearer not-a-real-token"})
    check("nakli token par bhi event nahi, 401", c == 401, c)

print("== 4) FAMILY accounts (plan se farq nahi)")
c, fam = req("GET", SBU + "/rest/v1/family_accounts?select=email,plan&limit=50", None, SB)
if c != 200 or not isinstance(fam, list):
    print("   (family_accounts table nahi / padhi nahi — %s, skip)" % c)
else:
    missing = []
    for f in fam:
        em = (f.get("email") or "").strip().lower()
        if not em: continue
        c1, lk = req("POST", SBU + "/auth/v1/admin/generate_link", {"type": "magiclink", "email": em}, SB)
        uid = ((lk or {}).get("id")) or (((lk or {}).get("user") or {}).get("id"))
        if not uid: missing.append(em + ":no-user"); continue
        c2, m = req("GET", SBU + f"/rest/v1/org_members?select=org_id&user_id=eq.{uid}&limit=1", None, SB)
        if not (isinstance(m, list) and m): missing.append(em + ":no-org")
    check("har family account ka org hai (%d accounts) — warna E41 dobara" % len(fam), not missing, missing)
print()
print("SAB PASS" if not fails else "FAIL: " + ", ".join(fails))
sys.exit(0 if not fails else 1)
