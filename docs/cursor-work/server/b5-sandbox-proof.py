#!/usr/bin/env python3
"""B5 (G40) SANDBOX differential proof — dev-time, server par nahi chalta.
Ek hi nakli Supabase (PostgREST + GoTrue/JWKS) par DO jawab-dene wale:
  * ASLI Bun routers (server/routes/movein.ts, release.ts, revenue.ts — express ke chhote shim par, route code ek akshar nahi badla)
  * ASLI Rust debug binary (b5_core + b5_glue)
Dono ko wahi sawal poochta hai aur jawab milata hai (seeded data par EXACT barabar; naye banne wale rows par id/waqt chhod kar).
Env: RUST_BIN, REPO, BUN_DIR (node_modules wala folder jahan `routes/` + harness copy hote hain; default /tmp/b5t/sj).
Exit 0 = sab PASS."""
import base64, hashlib, json, os, re, shutil, subprocess, sys, tempfile, threading, time, urllib.request, urllib.error, uuid
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

REPO = os.environ.get("REPO", "/home/claude/anexomail-workspace")
RUST_BIN = os.environ.get("RUST_BIN", "/tmp/claude-0/rs/target/debug/anexomail-rust")
BUN_DIR = os.environ.get("BUN_DIR", "/tmp/b5t/sj")
MOCK_PORT, BUN_PORT, RPC_PORT = 9941, 9931, 3200
RPC, BUN = f"http://127.0.0.1:{RPC_PORT}", f"http://127.0.0.1:{BUN_PORT}"
U = lambda: str(uuid.uuid4())
FOUNDER, FOUNDER_EMAIL = U(), "founder.test@anexomail.com"
CUST, CUST_EMAIL = U(), "cust.test@example.com"
OTHER, OTHER_EMAIL = U(), "other.test@example.com"
NODEALS, NODEALS_EMAIL = U(), "nodeals.test@example.com"
tmp = tempfile.mkdtemp()
fails = []

# ── jwt ────────────────────────────────────────────────────────────────────
def _b(x): return base64.urlsafe_b64encode(x).rstrip(b"=").decode()
subprocess.check_call(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", tmp + "/k.pem"], stderr=subprocess.DEVNULL)
_der = subprocess.check_output(["openssl", "ec", "-in", tmp + "/k.pem", "-pubout", "-outform", "DER"], stderr=subprocess.DEVNULL)[-65:]
JWKS = {"keys": [{"kty": "EC", "crv": "P-256", "kid": "k1", "x": _b(_der[1:33]), "y": _b(_der[33:65]), "alg": "ES256"}]}
def _raw(sig):
    rl = sig[3]; r = sig[4:4 + rl]; j = 4 + rl + 2; sl = sig[4 + rl + 1]; s = sig[j:j + sl]
    return r.lstrip(b"\x00").rjust(32, b"\x00") + s.lstrip(b"\x00").rjust(32, b"\x00")
def mint(uid, email):
    h = _b(json.dumps({"alg": "ES256", "typ": "JWT", "kid": "k1"}).encode())
    p = _b(json.dumps({"sub": uid, "email": email, "aud": "authenticated", "iss": f"http://127.0.0.1:{MOCK_PORT}/auth/v1",
                       "exp": int(time.time()) + 3600, "session_id": U()}).encode())
    open(tmp + "/m", "wb").write((h + "." + p).encode())
    sig = subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", tmp + "/k.pem", tmp + "/m"], stderr=subprocess.DEVNULL)
    return h + "." + p + "." + _b(_raw(sig))
def jwt_user(tok):
    p = tok.split(".")[1]; p += "=" * (-len(p) % 4)
    return json.loads(base64.urlsafe_b64decode(p))

# ── seed ────────────────────────────────────────────────────────────────────
DEAL_C, DEAL_O = U(), U()
RUN_OLD, RUN_NEW = U(), U()
CHK = [U() for _ in range(4)]
LEAD_A, LEAD_B, LEAD_C = U(), U(), U()
now = time.time()
iso = lambda off: time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime(now + off))
T = {
    "founder_accounts": [],
    "movein_capacity_state": [{"month": "2026-11", "slots": 4, "booked": 1}, {"month": "2026-12", "slots": 4, "booked": 0}, {"month": "2027-01", "slots": 6, "booked": 2}],
    "movein_deals": [{"id": DEAL_C, "user_id": CUST, "owner_id": None, "created_at": iso(-100)}, {"id": DEAL_O, "user_id": OTHER, "owner_id": None, "created_at": iso(-50)}],
    "release_runs": [
        {"id": RUN_OLD, "user_id": FOUNDER, "suite": "all", "started_at": iso(-5000), "finished_at": iso(-4990), "passed": 30, "warned": 1, "failed": 0, "skipped": 0, "total": 31, "ms": 900, "verdict": "watch"},
        {"id": RUN_NEW, "user_id": FOUNDER, "suite": "all", "started_at": iso(-3000), "finished_at": iso(-2990), "passed": 28, "warned": 1, "failed": 2, "skipped": 1, "total": 32, "ms": 1100, "verdict": "red"}],
    "release_checks": [
        {"id": CHK[0], "run_id": RUN_NEW, "suite": "routes", "name": "health", "status": "pass", "ms": 12, "code": 200, "detail": "/api/health", "at": iso(-2999)},
        {"id": CHK[1], "run_id": RUN_NEW, "suite": "routes", "name": "contacts", "status": "fail", "ms": 90, "code": 500, "detail": "/api/contacts returned 500", "at": iso(-2999)},
        {"id": CHK[2], "run_id": RUN_NEW, "suite": "database", "name": "table mail_threads", "status": "warn", "ms": 1600, "code": 200, "detail": "3 rows", "at": iso(-2999)},
        {"id": CHK[3], "run_id": RUN_NEW, "suite": "speed", "name": "Open inbox", "status": "pass", "ms": None, "code": None, "detail": None, "at": iso(-2999)}],
    "release_checklist": [
        {"id": U(), "area": "mail", "label": "SPF aligned", "detail": "dns", "state": "done", "owner": "f", "updated_at": iso(-10)},
        {"id": U(), "area": "mail", "label": "DKIM rotated", "detail": None, "state": "blocker", "owner": None, "updated_at": None},
        {"id": U(), "area": "web", "label": "Lighthouse", "detail": "90+", "state": "open", "owner": None, "updated_at": None},
        {"id": U(), "area": "billing", "label": "Polar webhook", "detail": None, "state": "open", "owner": None, "updated_at": None}],
    "release_locks": [{"id": U(), "version": "0.9.0", "signed_by": "f@x.com", "user_id": FOUNDER, "run_id": RUN_OLD, "verdict": "watch", "signature_hash": "ab" * 32, "frozen_at": iso(-9000), "notes": "first", "override_reason": None}],
    "deployments": [{"id": U(), "target": "web", "commit_sha": "abc1234", "commit_subject": "ship", "actor": "pull.sh", "started_at": iso(-400 - i), "finished_at": iso(-390 - i), "ms": 9000, "state": "ok", "rollback_of": None, "changed_since_green": ["a.ts"] if i == 0 else None} for i in range(3)],
    "roadmap_items": [{"id": U(), "title": "WT push", "area": "tech", "impact": 5, "effort": "2", "revenue_link": None, "state": "shipped", "created_at": iso(-300)},
                      {"id": U(), "title": "Billing", "area": "money", "impact": 4, "effort": 4, "revenue_link": "mrr", "state": "next", "created_at": iso(-200)}],
    "revenue_accounts": [{"plan": "business", "seats": 5, "mrr_gbp": 425, "sla_addon": True, "state": "active"}, {"plan": "pro", "seats": 2, "mrr_gbp": "80.50", "sla_addon": False, "state": "active"},
                         {"plan": "basic", "seats": 1, "mrr_gbp": 20, "sla_addon": True, "state": "cancelled"}],
    "revenue_leads": [
        {"id": LEAD_A, "reference": "MIG-202610-AAAA", "company": "Acme", "kind": "migration", "stage": "won", "seats": 10, "quote_gbp": 1200, "created_at": iso(-30)},
        {"id": LEAD_B, "reference": "PTR-202610-BBBB", "company": "Beta", "kind": "partner", "stage": "qualified", "seats": None, "quote_gbp": None, "created_at": iso(-20)},
        {"id": LEAD_C, "reference": "LED-202610-CCCC", "company": "Gamma", "kind": "plan", "stage": "lost", "seats": 3, "quote_gbp": None, "created_at": iso(-10)},
        {"id": U(), "reference": "SLA-202610-DDDD", "company": "Delta", "kind": "sla", "stage": "proposal", "seats": 4, "quote_gbp": None, "created_at": iso(-5)}],
    "revenue_targets": [{"month": "2026-10", "target_gbp": 1500}],
    "revenue_partners": [{"company": "P1", "tier": "gold", "live_seats": 4, "commission_gbp": 60, "stage": "active"}, {"company": "P2", "tier": "reseller", "live_seats": 0, "commission_gbp": "15.5", "stage": "applied"}],
    "subscription_pipeline": [{"lead_id": LEAD_B, "plan_seats": 7, "expected_mrr_gbp": 280, "stage": "x"}],
    "incidents": [{"title": "DB failover", "started_at": iso(-86400), "resolved_at": iso(-80000)}],
    "mail_domains": [{"domain": "ok.example", "dkim": "pass", "spf": "green", "dmarc": True, "mx": "pass"}, {"domain": "bad.example", "dkim": "fail", "spf": "pass", "dmarc": "pending", "mx": None}],
    "mail_outbox": [{"id": U(), "state": "queued", "idempotency_key": "seed", "user_id": CUST}, {"id": U(), "state": "failed", "idempotency_key": "seed2", "user_id": CUST}, {"id": U(), "state": "sent", "idempotency_key": "seed3", "user_id": CUST}],
    "perf_budgets": [{"action": "open_inbox", "label": "Open inbox", "budget_ms": 300}, {"action": "send", "label": "Send mail", "budget_ms": 500}, {"action": "search", "label": "Search", "budget_ms": 200}],
    "perf_samples": [{"action": "open_inbox", "duration_ms": 100 + i, "at": iso(-3600)} for i in range(20)] + [{"action": "send", "duration_ms": 700, "at": iso(-3600)} for _ in range(5)] + [{"action": "send", "duration_ms": 900, "at": iso(-3600)}],
    "diagnostic_probes": [{"probe": "spf", "target": "ok.example", "result": "pass", "ms": 20, "at": iso(-100)}, {"probe": "dkim", "target": "bad.example", "result": "fail", "ms": 21, "at": iso(-99)},
                          {"probe": "spf", "target": "ok.example", "result": "fail", "ms": 22, "at": iso(-98)}, {"probe": "tls", "target": None, "result": "slow", "ms": None, "at": iso(-97)}],
}
LOG = []          # (table, method, row) for inserts — to inspect what each implementation wrote
UNIQUE = {"release_locks": "version", "mail_outbox": "idempotency_key"}

def match_row(row, q):
    for k, vals in q.items():
        if k in ("select", "limit", "order", "on_conflict"): continue
        for v in vals:
            if k == "or":
                inner = v.strip("()").split(",")
                if not any(match_row(row, {c.split(".", 1)[0]: [c.split(".", 1)[1]]}) for c in inner): return False
                continue
            op, _, val = v.partition("."); cur = row.get(k)
            if op == "eq" and str(cur) != val: return False
            if op == "neq" and str(cur) == val: return False
            if op == "gt" and not (str(cur) > val): return False
            if op == "is" and not (cur is None and val == "null"): return False
            if op in ("in", "not"):
                neg = op == "not"; spec = val
                if neg:
                    _, _, spec = val.partition(".")
                items = [x.strip().strip('"') for x in spec.strip("()").split(",")]
                hit = str(cur) in items
                if hit == neg: return False
    return True

class MockH(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, body, headers=None):
        b = b"" if body is None else json.dumps(body).encode(); self.send_response(code); self.send_header("content-type", "application/json")
        for k, v in (headers or {}).items(): self.send_header(k, v)
        self.send_header("content-length", str(len(b))); self.end_headers()
        if self.command != "HEAD": self.wfile.write(b)
    def do_GET(self): self.h("GET")
    def do_POST(self): self.h("POST")
    def do_PATCH(self): self.h("PATCH")
    def do_HEAD(self): self.h("HEAD")
    def h(self, m):
        u = urlparse(self.path); p = u.path; q = parse_qs(u.query, keep_blank_values=True)
        n = int(self.headers.get("content-length") or 0); raw = self.rfile.read(n) if n else b""
        try: body = json.loads(raw) if raw else None
        except Exception: body = None
        prefer = self.headers.get("prefer", ""); accept = self.headers.get("accept", "")
        if p == "/auth/v1/.well-known/jwks.json": return self._send(200, JWKS)
        if p == "/auth/v1/user":
            tok = (self.headers.get("authorization") or "")[7:]
            try:
                c = jwt_user(tok); return self._send(200, {"id": c["sub"], "email": c["email"]})
            except Exception: return self._send(401, {"message": "bad token"})
        if p.startswith("/rest/v1/rpc/"):
            fn = p.split("/")[-1]; body = body or {}
            if fn == "auth_session_alive": return self._send(200, True)
            if fn == "movein_open_deal": return self._send(200, {"ok": True, "deal_id": "deal-" + body["p_company"], "args": body})
            if fn == "movein_cockpit": return self._send(200, {"deals": [{"id": DEAL_C}, {"id": DEAL_O}], "n": 2})
            if fn == "movein_evidence_bundle": return self._send(200, {"id": body["p_deal"], "evidence": [1, 2]})
            if fn == "movein_customer_view": return self._send(200, {"id": body["p_deal"], "state": "SCHEDULED"})
            return self._send(404, {"message": "no " + fn})
        mm = re.match(r"/rest/v1/(\w+)", p)
        if not mm: return self._send(404, {"message": "nope"})
        name = mm.group(1); tb = T.setdefault(name, [])
        if m in ("GET", "HEAD"):
            rows = [dict(r) for r in tb if match_row(r, q)]
            if "order" in q:
                for spec in reversed(q["order"][0].split(",")):
                    f, _, d = spec.partition("."); rows.sort(key=lambda r: (r.get(f) is None, str(r.get(f) if r.get(f) is not None else "")), reverse=(d == "desc"))
            total = len(rows)
            if "limit" in q: rows = rows[: int(q["limit"][0])]
            hdr = {"content-range": (f"*/{total}" if m == "HEAD" else f"0-{max(total - 1, 0)}/{total}")} if "count" in prefer or self.headers.get("range") else {}
            if "pgrst.object" in accept:
                return self._send(200, rows[0], hdr) if len(rows) == 1 else self._send(406, {"code": "PGRST116", "message": "no/many rows"}, hdr)
            return self._send(200, rows, hdr)
        if m == "POST":
            items = body if isinstance(body, list) else [body]; out = []
            for it in items:
                col = UNIQUE.get(name)
                if col and any(r.get(col) == it.get(col) for r in tb): return self._send(409, {"code": "23505", "message": "duplicate key value violates unique constraint"})
                row = dict(it); row.setdefault("id", U()); row.setdefault("created_at", iso(0))
                if name == "release_checks": row.setdefault("at", iso(0))
                tb.append(row); out.append(row); LOG.append((name, dict(row)))
            if "representation" in prefer:
                return self._send(201, out[0] if "pgrst.object" in accept else out)
            return self._send(201, None)
        if m == "PATCH":
            hit = []
            for r in tb:
                if match_row(r, q): r.update(body); hit.append(dict(r))
            if "representation" in prefer: return self._send(200, hit[0] if ("pgrst.object" in accept and len(hit) == 1) else hit)
            return self._send(204, None)
        return self._send(404, {"message": "nope"})

# ── http helpers ────────────────────────────────────────────────────────────
def req(method, url, body=None, headers=None):
    h = {"content-type": "application/json"}; h.update(headers or {})
    r = urllib.request.Request(url, data=(json.dumps(body).encode() if body is not None else None), headers=h, method=method)
    try:
        with urllib.request.urlopen(r, timeout=60) as x: raw = x.read(); code = x.status
    except urllib.error.HTTPError as e: raw = e.read(); code = e.code
    try: return code, json.loads(raw or b"null")
    except Exception: return code, None
def rust(proc, inp, tok=None, ip=None):
    h = {}
    if tok: h["authorization"] = "Bearer " + tok
    if ip: h["x-forwarded-for"] = ip
    code, j = req("POST", f"{RPC}/rpc/{proc}", {"input": inp}, h)
    return code, ((j or {}).get("result") or {}).get("data"), ((j or {}).get("error") or {})
def bun(method, path, body=None, tok=None, ip=None):
    h = {}
    if tok: h["authorization"] = "Bearer " + tok
    if ip: h["x-forwarded-for"] = ip
    return req(method, BUN + path, body, h)
def check(name, cond, detail=""):
    print(("  PASS  " if cond else "  FAIL  ") + name + (("  — " + str(detail)[:400]) if (detail and not cond) else ""))
    if not cond: fails.append(name)
def strip(o, keys):
    if isinstance(o, dict): return {k: strip(v, keys) for k, v in o.items() if k not in keys}
    if isinstance(o, (list, tuple)): return [strip(x, keys) for x in o]
    return o
def same(name, a, b, ignore=()):
    a, b = strip(a, set(ignore)), strip(b, set(ignore))
    check(name, a == b, f"\n   bun : {json.dumps(a, sort_keys=True)[:600]}\n   rust: {json.dumps(b, sort_keys=True)[:600]}")

def main():
    threading.Thread(target=lambda: ThreadingHTTPServer(("127.0.0.1", MOCK_PORT), MockH).serve_forever(), daemon=True).start()
    mock = f"http://127.0.0.1:{MOCK_PORT}"
    # Bun harness (asli routes) ---------------------------------------------------------------
    for f in ("movein", "release", "revenue"): os.makedirs(BUN_DIR + "/routes", exist_ok=True); shutil.copy(f"{REPO}/server/routes/{f}.ts", f"{BUN_DIR}/routes/{f}.ts")
    shutil.copy(f"{REPO}/docs/cursor-work/server/tests/b5/bun-harness.ts", BUN_DIR + "/bun-harness.ts")
    shim = f"{BUN_DIR}/node_modules/express"; os.makedirs(shim, exist_ok=True)
    shutil.copy(f"{REPO}/docs/cursor-work/server/tests/b5/express-shim.js", shim + "/index.js"); open(shim + "/package.json", "w").write('{"name":"express","version":"0.0.0-shim","main":"index.js"}')
    benv = dict(os.environ, PORT=str(BUN_PORT), SUPABASE4_URL=mock, SUPABASE4_SERVICE_ROLE_KEY="svc-test", SELF_ORIGIN=BUN)
    blog = open(tmp + "/bun.log", "w"); bp = subprocess.Popen(["bun", "bun-harness.ts"], cwd=BUN_DIR, env=benv, stdout=blog, stderr=blog)
    renv = dict(os.environ, SUPABASE4_URL=mock, SUPABASE4_SERVICE_ROLE_KEY="svc-test", SELF_ORIGIN=BUN, FOUNDER_EMAILS=FOUNDER_EMAIL, RUST_LOG="error")
    rlog = open(tmp + "/rust.log", "w"); rp = subprocess.Popen([RUST_BIN], env=renv, stdout=rlog, stderr=rlog)
    try:
        for _ in range(100):
            try:
                if req("GET", RPC + "/rpc/health")[0] == 200 and req("GET", BUN + "/api/health")[0] == 200: break
            except Exception: pass
            time.sleep(0.2)
        else:
            print("start nahi hua\nrust:", open(tmp + "/rust.log").read()[-400:], "\nbun:", open(tmp + "/bun.log").read()[-400:]); return 2
        F, C, O, N = mint(FOUNDER, FOUNDER_EMAIL), mint(CUST, CUST_EMAIL), mint(OTHER, OTHER_EMAIL), mint(NODEALS, NODEALS_EMAIL)

        print("== 1) public: capacity / request / status")
        bc, bj = bun("GET", "/api/public/movein/capacity"); rc, rj, _ = rust("movein.capacity", {})
        check("capacity: dono 200", bc == 200 and rc == 200, (bc, rc)); same("capacity: jawab barabar", bj, rj)
        body = {"company": "Acme Ltd", "email": "boss@acme.com", "mailboxes": "12", "domain": "acme.com", "provider": "google", "contact_name": "Ali", "month": "2026-12"}
        bc, bj = bun("POST", "/api/public/movein/request", body); rc, rj, _ = rust("movein.request", body)
        check("request: dono 200", bc == 200 and rc == 200, (bc, rc)); same("request: RPC ko wahi arguments gaye (mailboxes '12' -> 12)", bj, rj)
        for label, b in [("company nahi", {"email": "a@b.co"}), ("email nahi", {"company": "X"}), ("mailboxes 0 -> 1", {"company": "X", "email": "a@b.co", "mailboxes": 0})]:
            bc, bj = bun("POST", "/api/public/movein/request", b); rc, rj, re_ = rust("movein.request", b)
            if "nahi" in label: check(f"request ({label}): dono 400, code barabar", bc == 400 == rc and bj.get("error") == re_.get("code"), (bc, bj, rc, re_))
            else: same(f"request ({label})", bj, rj)
        bc, bj = bun("GET", "/api/public/status"); rc, rj, _ = rust("status.public", {})
        check("status: dono 200", bc == 200 and rc == 200, (bc, rc)); same("status: jawab barabar (updated_at = latest run ka finished_at)", bj, rj)
        check("status: Workspace 'down' (routes mein 1 fail), Storage 'degraded'", [c["state"] for c in rj["components"]][:2] == ["down", "degraded"], rj)

        print("== 2) revenue lead (asli rows + 5/10-min throttle)")
        n0 = len(LOG)
        lead = {"kind": "migration", "company": "  Zeta Co ", "email": " z@zeta.io ", "name": "Zed", "domain": "zeta.io", "seats": "7.6", "quote_gbp": 1001, "message": "hi", "detail": {"tier": "gold"}}
        bc, bj = bun("POST", "/api/public/revenue/lead", lead, ip="10.0.0.1"); mid = len(LOG)
        rc, rj, _ = rust("revenue.lead", lead, ip="10.0.0.2"); end = len(LOG)
        check("lead: dono 200 + reference/id/kind/created_at", bc == 200 and rc == 200 and all(k in rj for k in ("id", "reference", "kind", "created_at")), (bc, rc, rj))
        brows, rrows = [r for r in LOG[n0:mid]], [r for r in LOG[mid:end]]
        same("lead: likhi gayi rows (leads + migration job) barabar", [(t, r) for t, r in brows], [(t, r) for t, r in rrows], ignore=("id", "reference", "created_at", "lead_id", "source_ip"))
        if fails and fails[-1].startswith("lead: likhi"): print("   bun rows :", json.dumps(brows, sort_keys=True)[:900]); print("   rust rows:", json.dumps(rrows, sort_keys=True)[:900])
        check("lead: migration job mein deposit = round(quote/2) = 501", [r for t, r in rrows if t == "revenue_jobs"][0]["deposit_gbp"] == 501)
        check("lead: reference shape MIG-YYYYMM-XXXX", re.fullmatch(r"MIG-\d{6}-[A-Z0-9]{4}", rj["reference"]) is not None, rj)
        n0 = len(LOG); pl = {"kind": "partner", "company": "Pt", "email": "p@pt.io", "detail": {"tier": "platinum", "rate": 0.25}}
        bun("POST", "/api/public/revenue/lead", pl, ip="10.0.0.1"); mid = len(LOG); rust("revenue.lead", pl, ip="10.0.0.2"); end = len(LOG)
        same("partner lead: partner row barabar (tier+rate)", LOG[n0:mid], LOG[mid:end], ignore=("id", "reference", "created_at", "lead_id", "source_ip"))
        for label, b in [("bad kind", {"kind": "zzz", "company": "A", "email": "a@b.co"}), ("bad email", {"kind": "plan", "company": "A", "email": "nope"}), ("no company", {"kind": "plan", "email": "a@b.co"})]:
            bc, bj = bun("POST", "/api/public/revenue/lead", b, ip="10.0.0.3"); rc, rj, re_ = rust("revenue.lead", b, ip="10.0.0.4")
            check(f"lead ({label}): dono 400, code barabar", bc == 400 == rc and bj.get("error") == re_.get("code"), (bc, bj, rc, re_))
        # throttle: 5 allowed, 6th blocked. (bad requests above already counted 3 for 10.0.0.3/4)
        okc = []
        for i in range(4):
            okc.append((bun("POST", "/api/public/revenue/lead", {"kind": "plan", "company": "T", "email": "t@t.co"}, ip="10.0.0.9")[0], rust("revenue.lead", {"kind": "plan", "company": "T", "email": "t@t.co"}, ip="10.0.0.8")[0]))
        bc = bun("POST", "/api/public/revenue/lead", {"kind": "plan", "company": "T", "email": "t@t.co"}, ip="10.0.0.9")[0]
        rc = rust("revenue.lead", {"kind": "plan", "company": "T", "email": "t@t.co"}, ip="10.0.0.8")[0]
        bc6 = bun("POST", "/api/public/revenue/lead", {"kind": "plan", "company": "T", "email": "t@t.co"}, ip="10.0.0.9")[0]
        rc6 = rust("revenue.lead", {"kind": "plan", "company": "T", "email": "t@t.co"}, ip="10.0.0.8")[0]
        check("throttle: 5 ho gayi (Bun 200, Rust 200), 6th dono 429", (bc, rc) == (200, 200) and (bc6, rc6) == (429, 429), (okc, bc, rc, bc6, rc6))

        print("== 3) customer portal (movein.deal)")
        bc, bj = bun("GET", "/api/movein/deal", tok=C); rc, rj, _ = rust("movein.deal", {}, C)
        check("deal (apni newest): dono 200", bc == rc == 200, (bc, rc)); same("deal (apni newest): barabar", bj, rj)
        bc, bj = bun("GET", f"/api/movein/deal/{DEAL_C}", tok=C); rc, rj, _ = rust("movein.deal", {"id": DEAL_C}, C); same("deal/:id (apni): barabar", bj, rj)
        bc, bj = bun("GET", f"/api/movein/deal/{DEAL_O}", tok=C); rc, rj, re_ = rust("movein.deal", {"id": DEAL_O}, C)
        check("deal/:id (kisi aur ki): dono 404", bc == 404 == rc and bj.get("error") == re_.get("code"), (bc, bj, rc, re_))
        bc, bj = bun("GET", "/api/movein/deal", tok=N); rc, rj, _ = rust("movein.deal", {}, N); same("deal (user ke paas deal nahi): {deal:null}", bj, rj)
        check("deal: bina token dono 401", bun("GET", "/api/movein/deal")[0] == 401 == rust("movein.deal", {})[0])
        check("deal: hostile id ('x;drop') => 404, URL tak nahi pahunchi", rust("movein.deal", {"id": "x'; drop table"}, C)[0] == 404)

        print("== 4) founder reads — Bun se exact barabar")
        pairs = [("cockpit", "GET", "/api/founder/movein/cockpit", "founder.movein.cockpit", {}),
                 ("deal evidence", "GET", f"/api/founder/movein/deal/{DEAL_C}", "founder.movein.deal", {"id": DEAL_C}),
                 ("release.checks", "GET", "/api/founder/release/checks", "founder.release.checks", {}),
                 ("release.overview", "GET", "/api/founder/release/overview", "founder.release.overview", {}),
                 ("checklist", "GET", "/api/founder/release/checklist", "founder.release.checklist", {}),
                 ("deployments", "GET", "/api/founder/release/deployments", "founder.release.deployments", {}),
                 ("lock list", "GET", "/api/founder/release/lock", "founder.release.lock.list", {}),
                 ("roadmap list", "GET", "/api/founder/release/roadmap", "founder.release.roadmap.list", {}),
                 ("revenue pipeline", "GET", "/api/founder/revenue/pipeline", "founder.revenue.pipeline", {})]
        for label, m, path, proc, inp in pairs:
            bc, bj = bun(m, path, tok=F); rc, rj, e = rust(proc, inp, F)
            check(f"{label}: dono 200", bc == 200 and rc == 200, (bc, rc, e)); same(f"{label}: JSON barabar", bj, rj)
        _, ov, _ = rust("founder.release.overview", {}, F)
        check("overview: gate 'locked' (lock maujood), blockers = 1 checklist + 1 failed check seeded", ov["gate"] == "locked" and len(ov["blockers"]) == 2 and ov["checklist_open"] == 3, ov)
        _, pp, _ = rust("founder.revenue.pipeline", {}, F)
        check("pipeline: committed = 425 + 80.5 (live) + 790 (1 live SLA, locked £790) + 60 (active partner) = 1355.5 -> 1356; gap = round(1500-1355.5) = 145", pp["committed_mrr_gbp"] == 1356 and pp["gap_gbp"] == 145 and pp["one_off_cash_gbp"] == 1200, pp)

        print("== 4b) founder command centre (founder.brain.command)")
        T["revenue_leads"].append({"id": U(), "reference": "LED-202610-NEW1", "company": "Fresh", "kind": "plan", "stage": "new", "seats": 1, "quote_gbp": None, "created_at": iso(-26 * 3600)})
        bc_, br, berr = rust("founder.brain.command", {}, F)
        check("brain.command: 200 aur result shape", bc_ == 200 and isinstance(br, dict) and {"light", "attention", "blind_spots", "pulse", "release", "movein", "money"} <= set(br), (bc_, berr))
        ids = [a["id"] for a in br["attention"]]
        check("brain: seeded truth -> qa_failed + release_blockers + new_leads + outbox_held + revenue_gap + checklist_open", {"qa_failed", "release_blockers", "new_leads", "outbox_held", "revenue_gap", "checklist_open"} <= set(ids), ids)
        check("brain: 26 ghante purani new lead => 'high' (late)", [a for a in br["attention"] if a["id"] == "new_leads"][0]["level"] == "high")
        sev = [a["severity"] for a in br["attention"]]
        check("brain: list severity ke hisab se sorted aur light amber (koi critical nahi)", sev == sorted(sev) and br["light"] == "amber", (sev, br["light"]))
        check("brain: money == pipeline page ka same number (1356 / gap 145) - ek hi definition", br["money"]["committed_mrr_gbp"] == pp["committed_mrr_gbp"] == 1356 and br["money"]["gap_gbp"] == 145 and br["money"]["priority_support_mrr_gbp"] == 790, br["money"])
        check("brain: release gate 'locked', version 0.9.0, blockers 1 (checklist), checklist_open 3", br["release"]["gate"] == "locked" and br["release"]["version"] == "0.9.0" and br["release"]["blockers"] == 1 and br["release"]["checklist_open"] == 3, br["release"])
        check("brain: outbox held = 2 (queued+failed, sent nahi)", br["pulse"]["outbox_held"] == 2 and br["pulse"]["brain"]["status"] in ("pass", "warn"), br["pulse"])
        check("brain: movein mock mein khali -> 0 (blind spot nahi, jawab aaya)", br["movein"] is not None and br["movein"]["blocked"] == 0 and "move-in" not in br["blind_spots"], br["movein"])
        check("brain: har item ka href '/app/founder' ya '/app/founder/...' (bahar ka link nahi)", all(a["href"].startswith("/app/founder") for a in br["attention"]))
        T["revenue_leads"][:] = [r for r in T["revenue_leads"] if r.get("stage") != "new"]

        print("== 5) founder gate")
        for proc, inp in [("founder.release.run", {}), ("founder.release.lock.create", {"version": "9"}), ("founder.revenue.pipeline", {}), ("founder.movein.cockpit", {}), ("founder.brain.command", {})]:
            c1 = rust(proc, inp, C)[0]; c2 = rust(proc, inp)[0]
            check(f"{proc}: user 403, bina token 401", c1 == 403 and c2 == 401, (c1, c2))

        print("== 6) checklist item / roadmap create / outbox")
        blk = [r for r in T["release_checklist"] if r["state"] == "blocker"][0]["id"]
        bc, bj = bun("POST", "/api/founder/release/checklist/item", {"id": blk, "state": "done"}, tok=F)
        rc, rj, _ = rust("founder.release.checklist.item", {"id": blk, "state": "blocker"}, F)
        check("checklist.item: dono 200", bc == rc == 200, (bc, rc)); same("checklist.item: shakl barabar", bj, rj, ignore=("updated_at", "state"))
        check("checklist.item: owner = founder ka email, state badli", rj["owner"] == FOUNDER_EMAIL and rj["state"] == "blocker" and bj["state"] == "done")
        for label, b in [("bad state", {"id": blk, "state": "zzz"}), ("id nahi", {"state": "done"})]:
            bc, _ = bun("POST", "/api/founder/release/checklist/item", b, tok=F); rc, _, _ = rust("founder.release.checklist.item", b, F)
            check(f"checklist.item ({label}): dono 400", bc == rc == 400, (bc, rc))
        check("checklist.item (hostile id): Rust 400, URL tak nahi pahunchi", rust("founder.release.checklist.item", {"id": "x'; drop", "state": "done"}, F)[0] == 400)
        rm = {"title": " Ship B5 ", "area": "tech", "impact": 99, "effort": "x", "revenue_link": "mrr", "state": "building"}
        bc, bj = bun("POST", "/api/founder/release/roadmap", rm, tok=F); rc, rj, _ = rust("founder.release.roadmap.create", rm, F)
        check("roadmap.create: dono 200", bc == rc == 200, (bc, rc, rj))
        check("roadmap.create: impact 99 -> 5, effort 'x' -> 3 (Rust); title trim; state", rj["impact"] == 5 and rj["effort"] == 3 and rj["title"] == "Ship B5" and rj["state"] == "building", rj)
        same("roadmap.create: baqi fields barabar", bj, rj, ignore=("id", "effort"))
        check("roadmap.create: title nahi => dono 400", bun("POST", "/api/founder/release/roadmap", {}, tok=F)[0] == 400 == rust("founder.release.roadmap.create", {}, F)[0])
        ob = {"idempotency_key": "k-1", "to": "x@y.co", "subject": "S", "body": "B"}
        bc, bj = bun("POST", "/api/mail/outbox/send", ob, tok=C); rc, rj, _ = rust("outbox.send", dict(ob, idempotency_key="k-2"), C)
        check("outbox: pehli baar queued, duplicate false (dono)", bc == rc == 200 and bj["state"] == rj["state"] == "queued" and bj["duplicate"] is False and rj["duplicate"] is False, (bj, rj))
        bc, bj = bun("POST", "/api/mail/outbox/send", ob, tok=C); rc, rj2, _ = rust("outbox.send", dict(ob, idempotency_key="k-2"), C)
        check("outbox: dobara wohi key => wohi row, duplicate true (dono)", bj["duplicate"] is True and rj2["duplicate"] is True and rj2["id"] == rj["id"], (bj, rj2))
        n_before = len([r for r in T["mail_outbox"] if r.get("idempotency_key") == "k-2"])
        with ThreadPoolExecutor(4) as ex: res = list(ex.map(lambda _: rust("outbox.send", dict(ob, idempotency_key="k-race"), C), range(4)))
        rows_k = [r for r in T["mail_outbox"] if r.get("idempotency_key") == "k-race"]
        check("outbox: 4 ek saath tap => DB mein sirf 1 row, sab ko 200", n_before == 1 and len(rows_k) == 1 and all(r[0] == 200 for r in res), ([r[0] for r in res], len(rows_k)))
        c403 = rust("outbox.send", dict(ob, idempotency_key="k-2"), O)
        check("outbox: kisi aur ki key => 409 (Bun us ka row dikha deta tha — Rust nahi)", c403[0] == 409 and c403[2].get("code") == "idempotency_conflict", c403)
        check("outbox: to/key nahi => dono 400", bun("POST", "/api/mail/outbox/send", {"to": "a@b.co"}, tok=C)[0] == 400 == rust("outbox.send", {"to": "a@b.co"}, C)[0] == 400)
        check("outbox: bina token dono 401", bun("POST", "/api/mail/outbox/send", ob)[0] == 401 == rust("outbox.send", ob)[0])

        print("== 7) release.run — asli probes, Bun ke saath barabar")
        bc, bj = bun("POST", "/api/founder/release/run", {"suite": "all"}, tok=F)
        rc, rj, _ = rust("founder.release.run", {"suite": "all"}, F)
        check("run: dono 200", bc == rc == 200, (bc, rc, rj))
        key = lambda c: (c["suite"], c["name"])
        # release_checks / release_runs ki row-ginti is liye alag: pehle Bun ki run ne unhein barha diya (sequential test)
        det = lambda c: None if c["name"] in ("table release_checks", "table release_runs") else c["detail"]
        bchk = {key(c): (c["status"], c["code"], det(c)) for c in bj["checks"]}
        rchk = {key(c): (c["status"], c["code"], det(c)) for c in rj["checks"]}
        extra = {k: v for k, v in rchk.items() if k not in bchk}
        check("run: Rust ka har check Bun ke barabar (status/code/detail) — sirf 1 ZYADA: 'rust engine health'", {k: v for k, v in rchk.items() if k in bchk} == bchk and list(extra) == [("routes", "rust engine health")] and extra[("routes", "rust engine health")][0] == "pass",
              (set(bchk) ^ set(rchk), [(k, bchk[k], rchk.get(k)) for k in bchk if bchk[k] != rchk.get(k)][:5]))
        for f in ("passed", "warned", "failed", "skipped", "total"):
            exp = bj["run"][f] + (1 if (f in ("passed", "total")) else 0)
            check(f"run.{f}: Bun {bj['run'][f]} (+1 rust health) = Rust {rj['run'][f]}", rj["run"][f] == exp, (bj["run"], rj["run"]))
        check("run: verdict barabar", bj["run"]["verdict"] == rj["run"]["verdict"] == "red", (bj["run"]["verdict"], rj["run"]["verdict"]))
        check("run: DB mein release_runs + release_checks likhe gaye (run id aur UUID shape)", any(r["id"] == rj["run"]["id"] for r in T["release_runs"]) and sum(1 for c in T["release_checks"] if c["run_id"] == rj["run"]["id"]) == rj["run"]["total"] and re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}", rj["run"]["id"]) is not None)
        sp = {c["name"]: c["status"] for c in rj["checks"] if c["suite"] == "speed"}
        check("speed: Open inbox pass, Send mail p95 900 vs 500 => fail? (nearest-rank p95 of 6 samples = 900 > 750 => fail), Search skip", sp == {"Open inbox": "pass", "Send mail": "fail", "Search": "skip"}, sp)
        mp = {c["name"]: c["status"] for c in rj["checks"] if c["suite"] == "mail"}
        check("mail: ok.example pass, bad.example fail, backlog 2 queued/failed => warn", mp == {"domain ok.example": "pass", "domain bad.example": "fail", "outbox backlog": "warn"}, mp)
        with ThreadPoolExecutor(2) as ex: two = list(ex.map(lambda _: rust("founder.release.run", {"suite": "mail"}, F)[0], range(2)))
        check("run: do ek saath => ek 200, ek 409 run_in_flight", sorted(two) == [200, 409], two)
        check("run: ek suite ('speed') => sirf wahi suite ke checks", {c["suite"] for c in rust("founder.release.run", {"suite": "speed"}, F)[1]["checks"]} == {"speed"})

        print("== 8) version lock")
        last = rust("founder.release.checks", {}, F)[1]
        # abhi latest run RED hai (failed>0) => bina override 412 gate_red (Bun jaisa)
        bc, bj = bun("POST", "/api/founder/release/lock", {"version": "1.0.0"}, tok=F); rc, rj, re_ = rust("founder.release.lock.create", {"version": "1.0.0"}, F)
        check("lock (gate red, override nahi): dono 412 gate_red", bc == rc == 412 and bj["error"] == re_["code"] == "gate_red", (bc, bj, rc, re_))
        bc, bj = bun("POST", "/api/founder/release/lock", {"version": "1.0.0", "override_reason": "founder ne zimmedari li", "notes": "n"}, tok=F)
        rc, rj, _ = rust("founder.release.lock.create", {"version": "1.0.1", "override_reason": "founder ne zimmedari li", "notes": "n"}, F)
        check("lock (override): dono 200, verdict override(...)", bc == rc == 200 and bj["verdict"].startswith("override(") and rj["verdict"].startswith("override("), (bj, rj))
        same("lock: baqi shakl barabar", bj, rj, ignore=("id", "version", "signature_hash", "frozen_at", "verdict"))
        row = [r for r in T["release_locks"] if r["version"] == "1.0.1"][0]; rrun = row["run_id"]; run = [r for r in T["release_runs"] if r["id"] == rrun][0]
        payload = "|".join(["1.0.1", FOUNDER_EMAIL, row["frozen_at"], run["id"], run["verdict"], str(run["passed"]), str(run["failed"]), "founder ne zimmedari li"])
        check("lock: signature = sha256(version|email|frozen_at|run|verdict|passed|failed|override) (python se dobara nikala)", rj["signature_hash"] == hashlib.sha256(payload.encode()).hexdigest(), (payload, rj["signature_hash"]))
        brow = [r for r in T["release_locks"] if r["version"] == "1.0.0"][0]; brun = [r for r in T["release_runs"] if r["id"] == brow["run_id"]][0]
        bpay = "|".join(["1.0.0", FOUNDER_EMAIL, brow["frozen_at"], brun["id"], brun["verdict"], str(brun["passed"]), str(brun["failed"]), "founder ne zimmedari li"])
        check("lock: Bun ki signature bhi usi formula se (formula barabar sabit)", bj["signature_hash"] == hashlib.sha256(bpay.encode()).hexdigest())
        bc, bj = bun("POST", "/api/founder/release/lock", {"version": "1.0.0"}, tok=F); rc, rj, re_ = rust("founder.release.lock.create", {"version": "1.0.1"}, F)
        check("lock dobara: dono 409 already_locked", bc == rc == 409 and bj["error"] == re_["code"] == "already_locked", (bc, bj, rc, re_))
        check("lock: version nahi => dono 400", bun("POST", "/api/founder/release/lock", {}, tok=F)[0] == 400 == rust("founder.release.lock.create", {}, F)[0])
        saved = T["release_runs"][:]; T["release_runs"].clear()
        bc, bj = bun("POST", "/api/founder/release/lock", {"version": "2.0.0"}, tok=F); rc, rj, re_ = rust("founder.release.lock.create", {"version": "2.0.0"}, F)
        check("lock (koi run nahi): dono 412 no_run", bc == rc == 412 and bj["error"] == re_["code"] == "no_run", (bc, bj, rc, re_))
        T["release_runs"][:] = saved

        print("== 9) hostile / robustness")
        check("founder.movein.deal: hostile id => 400", rust("founder.movein.deal", {"id": "1'; drop table x;--"}, F)[0] == 400)
        check("revenue.lead: bohat lambi company 200 char par kat'ti hai", len([r for t, r in LOG if t == "revenue_leads" and r.get("company", "").startswith("LONG")][-1:] or [{"company": ""}]) >= 0)
        rc, rj, _ = rust("revenue.lead", {"kind": "plan", "company": "LONG" + "x" * 500, "email": "l@l.co"}, ip="10.0.9.9")
        check("revenue.lead: 504 chars company => DB mein 200", rc == 200 and [r for t, r in LOG if t == "revenue_leads" and r["company"].startswith("LONG")][-1]["company"].__len__() == 200)
        rc, rj, _ = rust("status.public", {}); check("status.public: bina token kaam karta hai", rc == 200 and rj["state"] in ("operational", "degraded", "down"))
        saved_t = {k: T[k] for k in ("release_runs", "incidents")}
        check("rust process zinda + health 200 (sab ke baad)", req("GET", RPC + "/rpc/health")[0] == 200 and rp.poll() is None)
    finally:
        rp.terminate(); bp.terminate()
        try: rp.wait(5); bp.wait(5)
        except Exception: rp.kill(); bp.kill()
    print("\n" + ("SAB PASS" if not fails else f"{len(fails)} FAIL: " + "; ".join(fails)))
    if fails:
        print("rust log tail:", open(tmp + "/rust.log").read()[-600:]); print("bun log tail:", open(tmp + "/bun.log").read()[-600:])
    return 1 if fails else 0

if __name__ == "__main__":
    sys.exit(main())
