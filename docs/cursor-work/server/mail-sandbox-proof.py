#!/usr/bin/env python3
"""B3 SANDBOX proof (dev-time, server par nahi chalta): nakli Supabase (PostgREST+GoTrue JWKS) + capture SMTP + ASLI Rust debug binary
+ ASLI Bun sendmail.ts. Dikhata hai: (1) Rust ka MIME Bun ke bytes jaisa HI hai (boundary/date/message-id normalise karke), (2) attachments,
(3) hostile inputs (CRLF header injection, foreign thread, bad send_at, 101 rcpts), (4) SMTP fail => koi row nahi bachti, (5) org.mailboxes.*
(role, limit, duplicate, writes switch).  Env: RUST_BIN (default /tmp/claude-0/rs/target/debug/anexomail-rust), REPO (workspace).
Exit 0 = sab PASS."""
import base64, hashlib, json, os, re, shutil, socket, socketserver, subprocess, sys, tempfile, threading, time, urllib.request, urllib.error, uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, unquote

REPO = os.environ.get("REPO", "/home/claude/anexomail-workspace")
RUST_BIN = os.environ.get("RUST_BIN", "/tmp/claude-0/rs/target/debug/anexomail-rust")
HTTP_PORT, SMTP_PORT, RPC_PORT = 9921, 9922, 3200
RPC = f"http://127.0.0.1:{RPC_PORT}"
ORG_A, ORG_B = str(uuid.uuid4()), str(uuid.uuid4())
OWNER, MEMBER = str(uuid.uuid4()), str(uuid.uuid4())
OWNER_EMAIL, MEMBER_EMAIL = "owner.test@anexomail.com", "member.test@anexomail.com"
FOREIGN_THREAD = str(uuid.uuid4())
tmp = tempfile.mkdtemp()
ATTACH = os.path.join(tmp, "attach"); os.makedirs(ATTACH)
fails = []

# ── key + jwt ───────────────────────────────────────────────────────────────
def _b(x): return base64.urlsafe_b64encode(x).rstrip(b"=").decode()
subprocess.check_call(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", tmp + "/k.pem"], stderr=subprocess.DEVNULL)
_der = subprocess.check_output(["openssl", "ec", "-in", tmp + "/k.pem", "-pubout", "-outform", "DER"], stderr=subprocess.DEVNULL)[-65:]
JWKS = {"keys": [{"kty": "EC", "crv": "P-256", "kid": "k1", "x": _b(_der[1:33]), "y": _b(_der[33:65]), "alg": "ES256"}]}
def _raw(sig):
    rl = sig[3]; r = sig[4:4 + rl]; j = 4 + rl + 2; sl = sig[4 + rl + 1]; s = sig[j:j + sl]
    return r.lstrip(b"\x00").rjust(32, b"\x00") + s.lstrip(b"\x00").rjust(32, b"\x00")
def mint(uid, email):
    h = _b(json.dumps({"alg": "ES256", "typ": "JWT", "kid": "k1"}).encode())
    p = _b(json.dumps({"sub": uid, "email": email, "aud": "authenticated", "iss": f"http://127.0.0.1:{HTTP_PORT}/auth/v1",
                       "exp": int(time.time()) + 3600, "session_id": str(uuid.uuid4())}).encode())
    open(tmp + "/m", "wb").write((h + "." + p).encode())
    sig = subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", tmp + "/k.pem", tmp + "/m"], stderr=subprocess.DEVNULL)
    return h + "." + p + "." + _b(_raw(sig))

# ── mock Supabase ───────────────────────────────────────────────────────────
T = {
    "org_members": [{"user_id": OWNER, "org_id": ORG_A, "role": "owner"}, {"user_id": MEMBER, "org_id": ORG_A, "role": "member"}],
    "mailboxes": [{"id": str(uuid.uuid4()), "org_id": ORG_A, "address": "hello@anexomail.com", "box_type": "mailbox", "display_name": "hello", "active": True, "purpose": "x"}],
    "workspace_subscriptions": [{"org_id": ORG_A, "plan": "business"}],
    "storage_plans": [{"plan_id": "business", "mailbox_limit": 3}],
    "mail_threads": [{"id": FOREIGN_THREAD, "org_id": ORG_B, "message_count": 7, "subject": "foreign"}],
    "mail_messages": [], "mail_scheduled": [], "org_addresses": [], "mail_accounts": [], "storage_log": [], "deny_storage": [], "org_switches": [], "staged": [], "outbox": [], "chain": [], "commits": [], "founder_accounts": [],
}
def match(row, q):
    for k, vals in q.items():
        if k in ("select", "limit", "on_conflict", "order"): continue
        for v in vals:
            op, _, val = v.partition(".")
            cur = row.get(k)
            if op == "eq" and str(cur) != val: return False
            if op == "neq" and str(cur) == val: return False
            if op == "like" and not str(cur).startswith(unquote(val).rstrip("*")): return False
    return True
class MockH(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, body, headers=None):
        b = json.dumps(body).encode(); self.send_response(code); self.send_header("content-type", "application/json")
        for k, v in (headers or {}).items(): self.send_header(k, v)
        self.send_header("content-length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self): self.h("GET")
    def do_POST(self): self.h("POST")
    def do_DELETE(self): self.h("DELETE")
    def do_PATCH(self): self.h("PATCH")
    def h(self, m):
        u = urlparse(self.path); p = u.path; q = parse_qs(u.query, keep_blank_values=True)
        n = int(self.headers.get("content-length") or 0); raw = self.rfile.read(n) if n else b""
        try: body = json.loads(raw) if raw else None
        except Exception: body = None
        if p == "/auth/v1/.well-known/jwks.json": return self._send(200, JWKS)
        if p == "/auth/v1/admin/generate_link": return self._send(200, {"hashed_token": "h-" + uuid.uuid4().hex})
        if p == "/auth/v1/verify": return self._send(200, {"access_token": mint(OWNER, OWNER_EMAIL), "user": {"id": OWNER}})
        if p.startswith("/auth/v1/admin/users/"):
            uid = p.rsplit("/", 1)[1]
            return self._send(200, {"id": uid, "email": {OWNER: OWNER_EMAIL, MEMBER: MEMBER_EMAIL}.get(uid, "")})
        if p.startswith("/rest/v1/rpc/"):
            fn = p.split("/")[-1]
            if fn == "auth_session_alive": return self._send(200, True)
            if fn == "mail_attach_stage_check":
                files = [f for f in T["staged"] if f["id"] in body["_ids"] and f.get("org") == body["_org"] and f.get("user") == body["_user"]]
                if len(files) != len(body["_ids"]): return self._send(200, {"ok": False, "error": "attachment_not_found"})
                return self._send(200, {"ok": True, "files": files, "total_bytes": sum(f["size_bytes"] for f in files)})
            now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            if fn == "mail_queue_release":
                k = 0
                for r in T["mail_scheduled"]:
                    if r["status"] == "holding" and r["send_at"] <= now: r["status"] = "queued"; k += 1
                return self._send(200, k)
            if fn == "mail_queue_claim":
                out = []
                for r in T["mail_scheduled"]:
                    if r["status"] == "queued" and r["send_at"] <= now and not r.get("claimed_at"):
                        r["claimed_at"] = now; out.append(dict(r))
                return self._send(200, out[: body.get("_limit", 20)])
            if fn == "mail_queue_cancel":
                for r in T["mail_scheduled"]:
                    if r["id"] == body["_id"] and r["org_id"] == body["_org"] and r["user_id"] == body["_user"] and r["status"] in ("holding", "queued") and not r.get("claimed_at"):
                        r["status"] = "cancelled"; return self._send(200, True)
                return self._send(200, False)
            if fn == "chat_ensure_workspace": return self._send(200, "ws-" + body["_user"][:8])
            if fn == "storage_reserve":
                T["storage_log"].append(("reserve", body["_bytes"]))
                return self._send(200, {"allowed": False, "reason": "storage_limit_exceeded"} if T["deny_storage"] else {"allowed": True})
            if fn in ("storage_commit", "storage_release"): T["storage_log"].append((fn[8:], body["_bytes"])); return self._send(200, None)
            if fn == "mail_attach_commit": T["commits"].append(body); return self._send(200, {"ok": True})
            if fn == "mail_outbox_record":
                T["outbox"].append(body["payload"]); T.setdefault("mail_outbox_log", []).append(dict(body["payload"])); return self._send(200, None)
            if fn == "org_chain_append": T["chain"].append(body); return self._send(200, None)
            return self._send(404, {"message": "no " + fn})
        mm = re.match(r"/rest/v1/(\w+)", p)
        if mm:
            name = mm.group(1); tb = T.setdefault(name, [])
            if m == "GET":
                rows = [r for r in tb if match(r, q)]
                if "order" in q:
                    f = q["order"][0].split(".")[0]; rows.sort(key=lambda r: str(r.get(f)))
                if "limit" in q: rows = rows[: int(q["limit"][0])]
                return self._send(200, rows, {"content-range": f"0-0/{len(rows)}"})
            if m == "POST":
                if name == "mailboxes" and any(r.get("address") == body.get("address") for r in tb):
                    return self._send(409, {"code": "23505", "message": "duplicate key value violates unique constraint"})
                row = dict(body); row.setdefault("id", str(uuid.uuid4())); tb.append(row); return self._send(201, [row])
            if m == "DELETE":
                gone = [r for r in tb if match(r, q)]; T[name] = [r for r in tb if r not in gone]; return self._send(200, gone)
            if m == "PATCH":
                for r in tb:
                    if match(r, q): r.update(body)
                return self._send(204, None)
        return self._send(404, {"message": "nope " + p})

# ── capture SMTP ────────────────────────────────────────────────────────────
CAP = []
class SmtpH(socketserver.StreamRequestHandler):
    def handle(self):
        w = lambda s: (self.wfile.write(s.encode()), self.wfile.flush())
        w("220 capture ESMTP\r\n"); frm = None; rc = []
        while True:
            line = self.rfile.readline().decode(errors="replace").rstrip("\r\n")
            if not line: return
            u = line.upper()
            if u.startswith("EHLO"): w("250-capture\r\n250 8BITMIME\r\n")
            elif u.startswith("MAIL FROM:"): frm = line[10:].strip("<>"); w("250 ok\r\n")
            elif u.startswith("RCPT TO:"):
                a = line[8:].strip("<>")
                if a.startswith("reject@"): w("550 5.1.1 no such user\r\n"); continue
                rc.append(a); w("250 ok\r\n")
            elif u == "DATA":
                w("354 go\r\n"); buf = b""
                while not buf.endswith(b"\r\n.\r\n"): buf += self.rfile.read1(65536) if hasattr(self.rfile, "read1") else self.rfile.read(1)
                data = buf[:-5].decode("utf-8", "replace").replace("\r\n..", "\r\n.")
                CAP.append({"from": frm, "rcpts": rc, "data": data}); w("250 2.0.0 queued as CAP%d\r\n" % len(CAP))
            elif u == "QUIT": w("221 bye\r\n"); return
            else: w("500 ?\r\n")
class TS(socketserver.ThreadingTCPServer): allow_reuse_address = True; daemon_threads = True

# ── helpers ─────────────────────────────────────────────────────────────────
def req(method, url, body=None, headers=None):
    h = {"content-type": "application/json"}; h.update(headers or {})
    r = urllib.request.Request(url, data=(json.dumps(body).encode() if body is not None else None), headers=h, method=method)
    try:
        with urllib.request.urlopen(r, timeout=30) as x: raw = x.read(); code = x.status
    except urllib.error.HTTPError as e: raw = e.read(); code = e.code
    try: return code, json.loads(raw or b"null")
    except Exception: return code, None
def call(proc, inp, tok, org=None):
    h = {"authorization": "Bearer " + tok}
    if org: h["x-org-id"] = org
    code, j = req("POST", f"{RPC}/rpc/{proc}", {"input": inp}, h)
    data = ((j or {}).get("result") or {}).get("data"); e = (j or {}).get("error") or {}
    return code, data, e
def check(name, cond, detail=""):
    print(("  PASS  " if cond else "  FAIL  ") + name + (("  — " + str(detail)[:200]) if (detail and not cond) else ""))
    if not cond: fails.append(name)
def norm(m):
    m = re.sub(r"Message-ID: <[^>]+>", "Message-ID: <ID>", m); m = re.sub(r"Date: [^\r]+", "Date: D", m)
    return re.sub(r"(ax|mx)_[0-9a-f]{32}", r"\1_B", m)
def bun_send(inp):
    """ASLI sendmail.ts ko capture SMTP par chalata hai."""
    n = len(CAP)
    js = ("import {sendMail} from '%s/server/mail/sendmail.ts'; const i=JSON.parse(process.env.IN!); "
          "const r=await sendMail(i); console.log(JSON.stringify(r));" % REPO)
    p = subprocess.run(["bun", "-e", js], env=dict(os.environ, IN=json.dumps(inp), MAIL_SMTP_PORT=str(SMTP_PORT), MAIL_SMTP_HOST="127.0.0.1"),
                       capture_output=True, text=True, timeout=60)
    if p.returncode != 0: print(p.stderr[:400])
    return CAP[n] if len(CAP) > n else None

def main():
    threading.Thread(target=lambda: ThreadingHTTPServer(("127.0.0.1", HTTP_PORT), MockH).serve_forever(), daemon=True).start()
    smtp = TS(("127.0.0.1", SMTP_PORT), SmtpH); threading.Thread(target=smtp.serve_forever, daemon=True).start()
    env = dict(os.environ, SUPABASE4_URL=f"http://127.0.0.1:{HTTP_PORT}", SUPABASE4_SERVICE_ROLE_KEY="svc-test", MAIL_SMTP_PORT=str(SMTP_PORT),
               MAIL_SMTP_HOST="127.0.0.1", ATTACH_DIR=ATTACH, ATTACH_MOUNT="none", RUST_LOG="error")
    log = open(tmp + "/rust.log", "w")
    proc = subprocess.Popen([RUST_BIN], env=env, stdout=log, stderr=log)
    try:
        for _ in range(100):
            try:
                if req("GET", RPC + "/rpc/health")[0] == 200: break
            except Exception: pass
            time.sleep(0.2)
        else:
            print("Rust start nahi hua:", open(tmp + "/rust.log").read()[-500:]); return 2
        tok, mtok = mint(OWNER, OWNER_EMAIL), mint(MEMBER, MEMBER_EMAIL)
        print("== 1) mail.send — Bun sendmail.ts ke bytes se muqabla")
        cases = [
            {"subject": "Hello", "body": "plain body\nline2", "to": ["a@example.com", "b@example.org"]},
            {"subject": "Salaam — héllo", "body": "Café ☕", "html": "<p>Café <b>☕</b></p>", "to": ["a@example.com"], "cc": ["c@example.com"],
             "bcc": ["secret@example.com"], "reply_to": "r@example.com", "from_name": "Anexo Team"},
            {"subject": "dots", "body": ".leading dot\n..two\nend", "to": ["a@example.com"]},
        ]
        for i, c in enumerate(cases):
            n = len(CAP)
            code, d, e = call("mail.send", c, tok)
            check(f"case{i}: Rust 200 ok", code == 200 and d and d.get("ok") is True, (code, d, e))
            rc = CAP[n] if len(CAP) > n else None
            bi = {"from": "hello@anexomail.com", "fromName": c.get("from_name"), "to": c["to"], "cc": c.get("cc"), "bcc": c.get("bcc"),
                  "subject": c["subject"], "text": c["body"], "html": c.get("html"), "replyTo": c.get("reply_to")}
            bc = bun_send(bi)
            check(f"case{i}: dono ne mail bheji", rc is not None and bc is not None)
            if rc and bc:
                check(f"case{i}: MIME bytes Bun ke barabar", norm(rc["data"]) == norm(bc["data"]), "\n--RUST--\n" + norm(rc["data"])[:500] + "\n--BUN--\n" + norm(bc["data"])[:500])
                check(f"case{i}: envelope (from+rcpts) barabar", rc["from"] == bc["from"] and rc["rcpts"] == bc["rcpts"], (rc["from"], rc["rcpts"], bc["rcpts"]))
        sec = [m for m in CAP if "secret@example.com" in m["rcpts"]]
        check("bcc sirf envelope mein", sec and "secret@example.com" not in sec[0]["data"])
        check("Sent row + thread bani (message_count real)", len([m for m in T["mail_messages"] if m["direction"] == "out"]) == 3 and all(t.get("message_count") == 1 for t in T["mail_threads"] if t["org_id"] == ORG_A))
        check("mail_outbox_record proof likha", len(T["outbox"]) >= 3 and all(o["ok"] for o in T["outbox"]))
        print("== 2) attachments")
        data = os.urandom(5000); sha = hashlib.sha256(data).hexdigest(); aid = str(uuid.uuid4())
        rel = f"{ORG_A}/{sha[:2]}/{sha}-0123abcd"; os.makedirs(os.path.dirname(os.path.join(ATTACH, rel)))
        open(os.path.join(ATTACH, rel), "wb").write(data)
        T["staged"].append({"id": aid, "org": ORG_A, "user": OWNER, "filename": "rep\"ort é.pdf", "mime_type": "application/pdf", "size_bytes": len(data), "sha256": sha, "rel_path": rel})
        n = len(CAP); code, d, e = call("mail.send", {"to": ["a@example.com"], "subject": "att", "body": "see file", "attachment_ids": [aid]}, tok)
        check("attachment mail 200", code == 200 and d and d.get("ok"), (code, d, e))
        m = CAP[n]["data"] if len(CAP) > n else ""
        check("multipart/mixed + base64 asli bytes", "multipart/mixed" in m and base64.b64encode(data).decode()[:76] in m)
        check("attach commit hua", any(c["_ids"] == [aid] for c in T["commits"]))
        open(os.path.join(ATTACH, rel), "ab").write(b"X")
        n = len(CAP); code, d, e = call("mail.send", {"to": ["a@example.com"], "subject": "att2", "body": "x", "attachment_ids": [aid]}, tok)
        check("badli hui file => 409 attachment_unavailable, mail NAHI gayi", code == 409 and e.get("code") == "attachment_unavailable" and len(CAP) == n, (code, e))
        code, d, e = call("mail.send", {"to": ["a@example.com"], "subject": "x", "body": "x", "attachment_ids": [str(uuid.uuid4())]}, tok)
        check("anjaan attachment id => 400", code == 400 and e.get("code") == "attachment_not_found", (code, e))
        code, d, e = call("mail.send", {"to": ["a@example.com"], "subject": "x", "body": "x", "attachment_ids": ["../../etc/passwd"]}, tok)
        check("path-jaisi id => 400 attachment_ids_invalid", code == 400 and e.get("code") == "attachment_ids_invalid", (code, e))
        print("== 3) hostile inputs — kuch bhi SMTP tak nahi pahunchna")
        n = len(CAP); rows_before = len(T["mail_messages"]); thr_before = len(T["mail_threads"])
        hostile = [
            ("CRLF in to", {"to": ["a@example.com\r\nBcc: evil@x.com"], "subject": "s", "body": "b"}, "invalid_recipient"),
            ("angle in to", {"to": ["<a@example.com>"], "subject": "s", "body": "b"}, "invalid_recipient"),
            ("space in cc", {"to": ["a@example.com"], "cc": ["x y@z.com"], "subject": "s", "body": "b"}, "invalid_recipient"),
            ("CRLF reply_to", {"to": ["a@example.com"], "reply_to": "r@x.com\r\nBcc: e@x.com", "subject": "s", "body": "b"}, "invalid_reply_to"),
            ("to missing", {"subject": "s", "body": "b"}, "to_required"),
            ("101 rcpts", {"to": [f"u{i}@example.com" for i in range(101)], "subject": "s", "body": "b"}, "too_many_recipients"),
            ("object in to", {"to": [{"a": 1}], "subject": "s", "body": "b"}, "invalid_recipient"),
            ("bad send_at", {"to": ["a@example.com"], "subject": "s", "body": "b", "send_at": "tomorrow"}, "send_at_invalid"),
            ("thread not uuid", {"to": ["a@example.com"], "subject": "s", "body": "b", "thread_id": "x&org_id=neq.1"}, "thread_id_invalid"),
            ("foreign thread", {"to": ["a@example.com"], "subject": "s", "body": "b", "thread_id": FOREIGN_THREAD}, "thread_not_found"),
        ]
        for name, inp, want in hostile:
            code, d, e = call("mail.send", inp, tok)
            check(f"{name} => 400/404 {want}", code in (400, 404) and e.get("code") == want, (code, e))
        check("hostile: koi mail/row nahi bani", len(CAP) == n and len(T["mail_messages"]) == rows_before and len(T["mail_threads"]) == thr_before)
        check("foreign thread ka message_count nahi chheda", [t for t in T["mail_threads"] if t["id"] == FOREIGN_THREAD][0]["message_count"] == 7)
        code, d, e = call("mail.send", {"to": ["a@example.com"], "subject": "s", "body": "b"}, "not.a.token")
        check("nakli token => 401", code == 401, code)
        print("== 4) SMTP fail => saaf state; scheduled; reply on own thread")
        rows_before = len(T["mail_messages"]); thr_before = len(T["mail_threads"]); n = len(CAP)
        code, d, e = call("mail.send", {"to": ["reject@example.com"], "subject": "s", "body": "b"}, tok)
        check("SMTP ne mana => 424 smtp_failed (502 nahi: client Bun par dobara bhej deta)", code == 424 and e.get("code") == "smtp_failed", (code, e))
        check("fail ke baad na message row na thread bachi", len(T["mail_messages"]) == rows_before and len(T["mail_threads"]) == thr_before)
        check("fail ka proof outbox mein ok=false", T["outbox"][-1]["ok"] is False)
        code, d, e = call("mail.send", {"to": ["a@example.com"], "subject": "later", "body": "b", "send_at": "2099-01-01T00:00:00Z"}, tok)
        check("future send_at => scheduled, SMTP nahi", code == 200 and d.get("scheduled_at", "").startswith("2099-01-01T00:00:00") and len(CAP) == n, (code, d, e))
        tid = [m for m in T["mail_messages"] if m.get("subject") == "Hello"][0]["thread_id"]
        code, d, e = call("mail.send", {"to": ["a@example.com"], "subject": "Re: Hello", "body": "reply", "thread_id": tid}, tok)
        thr = [t for t in T["mail_threads"] if t["id"] == tid][0]
        check("apni thread mein reply: ok, message_count=2", code == 200 and d["thread_id"] == tid and thr["message_count"] == 2, (code, d, thr))
        print("== 5) org.mailboxes.*")
        code, d, e = call("org.mailboxes.list", {}, tok)
        check("list: plan business, limit 3, used 1, remaining", code == 200 and d["plan"] == "business" and d["limit"] == 3 and d["used"] == 1 and d["remaining"] is True, (code, d, e))
        code, d, e = call("org.mailboxes.create", {"address": "sales@anexomail.com"}, mtok)
        check("member create => 403 forbidden", code == 403 and e.get("code") == "forbidden", (code, e))
        code, d, e = call("org.mailboxes.create", {"address": "not an address"}, tok)
        check("ghalat address => 400", code == 400 and e.get("code") == "address_required", (code, e))
        code, d, e = call("org.mailboxes.create", {"address": "Sales@AnexoMail.com "}, tok)
        check("owner create ok (lowercase)", code == 200 and d["mailbox"]["address"] == "sales@anexomail.com" and d["mailbox"]["display_name"] == "sales", (code, d, e))
        code, d, e = call("org.mailboxes.create", {"address": "sales@anexomail.com"}, tok)
        check("duplicate => 409 address_taken", code == 409 and e.get("code") == "address_taken", (code, e))
        code, d, e = call("org.mailboxes.create", {"address": "ops@anexomail.com"}, tok)
        check("3rd mailbox ok", code == 200 and d["remaining"] is False, (code, d, e))
        code, d, e = call("org.mailboxes.create", {"address": "more@anexomail.com"}, tok)
        check("limit par 403 mailbox_limit", code == 403 and e.get("code") == "mailbox_limit" and e.get("used") == 3, (code, e))
        T["storage_plans"][0]["mailbox_limit"] = 10; T["org_switches"].append({"key": "org_writes_enabled", "value": False})
        code, d, e = call("org.mailboxes.create", {"address": "more@anexomail.com"}, tok)
        check("org_writes off => 423", code == 423 and e.get("code") == "org_writes_disabled", (code, e))
        check("ledger (org_chain_append) likha gaya", any(c["p_action"] == "mailbox.create" for c in T["chain"]))
        code, d, e = call("org.mailboxes.list", {}, tok, org=ORG_B)
        check("doosre org ka x-org-id (member nahi) => apna org hi", code == 200 and all(b["org_id"] == ORG_A for b in d["mailboxes"]) if code == 200 else False, (code, e))
        code, d, e = call("org.mailboxes.list", {}, tok, org="x&org_id=neq.1")
        check("x-org-id mein injection => ignore, apna org", code == 200, (code, e))
        print("== 6) hold / undo-send queue + Rust worker")
        def wait(pred, secs=25):
            t0 = time.time()
            while time.time() - t0 < secs:
                if pred(): return True
                time.sleep(0.5)
            return False
        rowof = lambda i: [r for r in T["mail_scheduled"] if r["id"] == i][0]
        n = len(CAP)
        code, d, e = call("mail.schedule", {"to": "a@example.com, b@example.org", "cc": "c@example.com", "bcc": "hid@example.com", "subject": "Held mail", "body": "from queue\nsecond", "hold_seconds": 0}, tok)
        check("schedule 200 {id,status:holding}", code == 200 and d and d.get("status") == "holding" and d.get("id"), (code, d, e))
        sid = d["id"]
        check("Rust worker ne bheji + status=sent", wait(lambda: rowof(sid)["status"] == "sent"), rowof(sid))
        m = CAP[n] if len(CAP) > n else None
        check("queue mail SMTP tak pahunchi, bcc envelope mein", m is not None and m["rcpts"] == ["a@example.com", "b@example.org", "c@example.com", "hid@example.com"] and "hid@example.com" not in m["data"], m and m["rcpts"])
        bc = bun_send({"from": OWNER_EMAIL, "to": ["a@example.com", "b@example.org"], "cc": ["c@example.com"], "bcc": ["hid@example.com"], "subject": "Held mail", "text": "from queue\nsecond"})
        check("worker MIME bytes Bun worker ke barabar", m is not None and bc is not None and norm(m["data"]) == norm(bc["data"]))
        check("From = user ka asli address", m is not None and m["from"] == OWNER_EMAIL, m and m["from"])
        sent_copy = [x for x in T["mail_messages"] if x.get("subject") == "Held mail"]
        check("Sent copy (thread + message, dono addr columns)", len(sent_copy) == 1 and sent_copy[0].get("to_addrs") == ["a@example.com", "b@example.org"] and sent_copy[0].get("to_addresses") == sent_copy[0].get("to_addrs"), sent_copy)
        check("storage reserve + commit hua (release nahi)", [x[0] for x in T["storage_log"]][-2:] == ["reserve", "commit"], T["storage_log"][-3:])
        n = len(CAP)
        code, d, e = call("mail.schedule", {"to": "a@example.com", "subject": "Undo me", "body": "x", "hold_seconds": 60}, tok)
        uid_ = d["id"]
        code, d2, e2 = call("mail.schedule.cancel", {"id": uid_}, tok)
        check("hold ke andar cancel ok", code == 200 and d2.get("ok") is True and rowof(uid_)["status"] == "cancelled", (code, d2, e2))
        code, d2, e2 = call("mail.schedule.cancel", {"id": uid_}, tok)
        check("dobara cancel => 409 already_sent", code == 409 and e2.get("code") == "already_sent", (code, e2))
        code, d2, e2 = call("mail.schedule.cancel", {"id": sid}, tok)
        check("bheji ja chuki mail cancel nahi hoti (409)", code == 409, (code, e2))
        code, d3, e3 = call("mail.schedule", {"to": "a@example.com", "subject": "x", "body": "x", "hold_seconds": 60}, tok)
        code, d2, e2 = call("mail.schedule.cancel", {"id": d3["id"]}, mtok)
        check("doosre user ki mail cancel nahi (409)", code == 409 and rowof(d3["id"])["status"] == "holding", (code, e2))
        rowof(d3["id"])["claimed_at"] = "2026-01-01T00:00:00Z"
        code, d2, e2 = call("mail.schedule.cancel", {"id": d3["id"]}, tok)
        check("worker ne uthayi row cancel nahi hoti (409)", code == 409 and rowof(d3["id"])["status"] == "holding", (code, e2))
        time.sleep(6)
        check("cancelled / held rows ki mail kabhi nahi gayi", len(CAP) == n, len(CAP) - n)
        code, d2, e2 = call("mail.schedule", {"to": "a@example.com", "subject": "spoof", "body": "x", "identity": "ceo@bigbank.com"}, tok)
        check("parai identity => 403 identity_not_allowed", code == 403 and e2.get("code") == "identity_not_allowed", (code, e2))
        code, d2, e2 = call("mail.schedule", {"to": "a@example.com", "subject": "alias", "body": "x", "identity": "Hello@Anexomail.com", "hold_seconds": 0}, tok)
        check("apne org ka mailbox identity ok", code == 200, (code, d2, e2))
        n = len(CAP); wait(lambda: rowof(d2["id"])["status"] == "sent")
        check("identity ne From banaya", len(CAP) > n and CAP[n]["from"] == "hello@anexomail.com", CAP[n:] and CAP[n]["from"])
        for name, inp, want in [("CRLF to", {"to": "a@example.com\r\nBcc: z@z.com", "subject": "s"}, "invalid_recipient"), ("to missing", {"subject": "s"}, "to_required"),
                                ("foreign thread", {"to": "a@example.com", "thread_id": FOREIGN_THREAD}, "thread_not_found"), ("bad send_at", {"to": "a@example.com", "send_at": "kal"}, "send_at_invalid")]:
            code, d2, e2 = call("mail.schedule", inp, tok)
            check(f"schedule hostile: {name} => {want}", code in (400, 404) and e2.get("code") == want, (code, e2))
        T["deny_storage"].append(1); n = len(CAP)
        code, d2, e2 = call("mail.schedule", {"to": "a@example.com", "subject": "no space", "body": "x", "hold_seconds": 0}, tok)
        check("storage full: row failed + reason, mail NAHI gayi", wait(lambda: rowof(d2["id"])["status"] == "failed") and rowof(d2["id"]).get("error") == "storage_limit_exceeded" and len(CAP) == n, rowof(d2["id"]))
        T["deny_storage"].clear()
        code, d2, e2 = call("mail.schedule", {"to": "reject@example.com", "subject": "bounce", "body": "x", "hold_seconds": 0}, tok)
        check("SMTP ne mana: row failed + storage release", wait(lambda: rowof(d2["id"])["status"] == "failed") and "550" in str(rowof(d2["id"]).get("error")) and T["storage_log"][-1][0] == "release", (rowof(d2["id"]), T["storage_log"][-2:]))
        data2 = os.urandom(3000); sha2 = hashlib.sha256(data2).hexdigest(); aid2 = str(uuid.uuid4())
        rel2 = f"{ORG_A}/{sha2[:2]}/{sha2}-89abcdef"; os.makedirs(os.path.dirname(os.path.join(ATTACH, rel2)), exist_ok=True); open(os.path.join(ATTACH, rel2), "wb").write(data2)
        T["staged"].append({"id": aid2, "org": ORG_A, "user": OWNER, "filename": "q.bin", "mime_type": "application/octet-stream", "size_bytes": len(data2), "sha256": sha2, "rel_path": rel2})
        n = len(CAP); code, d2, e2 = call("mail.schedule", {"to": "a@example.com", "subject": "queued att", "body": "x", "hold_seconds": 0, "attachment_ids": [aid2]}, tok)
        check("attachment ke saath schedule ok", code == 200, (code, e2))
        check("worker ne attachment ke saath bheji + commit", wait(lambda: rowof(d2["id"])["status"] == "sent") and base64.b64encode(data2).decode()[:76] in CAP[n]["data"] and any(c["_ids"] == [aid2] for c in T["commits"]))
        code, d2, e2 = call("mail.schedule", {"to": "a@example.com", "subject": "tamper", "body": "x", "hold_seconds": 5, "attachment_ids": [aid2]}, tok)
        open(os.path.join(ATTACH, rel2), "ab").write(b"X"); n = len(CAP)
        check("schedule ke baad badli file: row failed, mail nahi gayi", wait(lambda: rowof(d2["id"])["status"] == "failed", 30) and "attachments" in str(rowof(d2["id"]).get("error")) and len(CAP) == n, rowof(d2["id"]))
        print("== 7) server wala live proof (mail-proof.py) isi sandbox par")
        pr = subprocess.run([sys.executable, "-I", os.path.join(REPO, "docs/cursor-work/server/mail-proof.py")],
                            env=dict(os.environ, RPC=RPC, SBU=f"http://127.0.0.1:{HTTP_PORT}", SBK="svc-test", EMAIL=OWNER_EMAIL), capture_output=True, text=True, timeout=300)
        print(pr.stdout[-3500:] + pr.stderr[-800:])
        check("mail-proof.py (installer ka saboot) sandbox par SAB PASS", pr.returncode == 0, pr.returncode)
    finally:
        proc.terminate()
        try: proc.wait(5)
        except Exception: proc.kill()
        shutil.rmtree(tmp, ignore_errors=True)
    print("\n" + ("SAB PASS" if not fails else "FAIL: " + ", ".join(fails)))
    return 0 if not fails else 1
sys.exit(main())
