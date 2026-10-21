#!/usr/bin/env python3
"""B6 SANDBOX end-to-end proof: ASLI Rust app (b6 module) -> ASLI naya Polar engine -> mock Polar, + Bun signer.
  RUST_BIN=<anexomail-rust debug> ENGINE_BIN=<polar-rust-payment new debug> python3 b6-sandbox-proof.py
Mock: Supabase (sirf auth: JWKS + /auth/v1/user), Polar API (customer-sessions). Asli Polar sirf server par."""
import base64, json, os, subprocess, sys, tempfile, threading, time, urllib.request, urllib.error, uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

RUST_BIN = os.environ.get("RUST_BIN", "/tmp/claude-0/rs/target/debug/anexomail-rust")
ENGINE_BIN = os.environ.get("ENGINE_BIN", "/tmp/engine-new")
MOCK, POLAR, ENG, RPC = 9951, 9952, 3493, 3200
KEY = "p" * 48
U = lambda: str(uuid.uuid4())
USER_OK, USER_NOCUST, USER_EVIL, USER_5XX = U(), U(), U(), U()
tmp = tempfile.mkdtemp(); passed = failed = 0
polar_calls = []

def check(n, c, x=""):
    global passed, failed
    if c: passed += 1; print("  PASS ", n)
    else: failed += 1; print("  FAIL ", n, x)

def _b(x): return base64.urlsafe_b64encode(x).rstrip(b"=").decode()
subprocess.check_call(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", tmp + "/k.pem"], stderr=subprocess.DEVNULL)
_der = subprocess.check_output(["openssl", "ec", "-in", tmp + "/k.pem", "-pubout", "-outform", "DER"], stderr=subprocess.DEVNULL)[-65:]
JWKS = {"keys": [{"kty": "EC", "crv": "P-256", "kid": "k1", "x": _b(_der[1:33]), "y": _b(_der[33:65]), "alg": "ES256"}]}
def _raw(sig):
    rl = sig[3]; r = sig[4:4 + rl]; j = 4 + rl + 2; sl = sig[4 + rl + 1]; s = sig[j:j + sl]
    return r.lstrip(b"\x00").rjust(32, b"\x00") + s.lstrip(b"\x00").rjust(32, b"\x00")
def mint(uid, email="u@example.com"):
    h = _b(json.dumps({"alg": "ES256", "typ": "JWT", "kid": "k1"}).encode())
    p = _b(json.dumps({"sub": uid, "email": email, "aud": "authenticated", "iss": f"http://127.0.0.1:{MOCK}/auth/v1", "exp": int(time.time()) + 3600, "session_id": U()}).encode())
    open(tmp + "/m", "wb").write((h + "." + p).encode())
    sig = subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", tmp + "/k.pem", tmp + "/m"], stderr=subprocess.DEVNULL)
    return h + "." + p + "." + _b(_raw(sig))
def jwt_user(tok):
    p = tok.split(".")[1]; p += "=" * (-len(p) % 4); return json.loads(base64.urlsafe_b64decode(p))

class MockSupabase(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, body):
        b = json.dumps(body).encode(); self.send_response(code); self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self): self.h()
    def do_POST(self): self.h()
    def h(self):
        p = self.path.split("?")[0]
        n = int(self.headers.get("content-length") or 0); self.rfile.read(n) if n else b""
        if p == "/auth/v1/.well-known/jwks.json": return self._send(200, JWKS)
        if p == "/auth/v1/user":
            try: c = jwt_user((self.headers.get("authorization") or "")[7:]); return self._send(200, {"id": c["sub"], "email": c["email"]})
            except Exception: return self._send(401, {"message": "bad token"})
        if p.startswith("/rest/v1/rpc/auth_session_alive"): return self._send(200, True)
        return self._send(200, [])

class MockPolar(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        n = int(self.headers.get("content-length") or 0); body = json.loads(self.rfile.read(n) or b"{}")
        polar_calls.append((self.path, self.headers.get("authorization"), body))
        def send(code, o):
            b = json.dumps(o).encode(); self.send_response(code); self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(b))); self.end_headers(); self.wfile.write(b)
        if self.path != "/v1/customer-sessions/": return send(404, {})
        who = body.get("external_customer_id")
        if who == USER_OK: return send(201, {"customer_portal_url": "https://polar.sh/anexomail/portal?customer_session_token=abc123", "expires_at": "2026-10-21T20:00:00Z"})
        if who == USER_NOCUST: return send(422, {"detail": "customer does not exist"})
        if who == USER_EVIL: return send(201, {"customer_portal_url": "https://polar.sh.evil.example/portal"})
        return send(500, {"detail": "boom"})

def serve(port, handler):
    s = ThreadingHTTPServer(("127.0.0.1", port), handler); threading.Thread(target=s.serve_forever, daemon=True).start(); return s

def post(url, body, headers=None):
    r = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST", headers={"content-type": "application/json", **(headers or {})})
    try:
        with urllib.request.urlopen(r, timeout=30) as resp: return resp.status, json.loads(resp.read() or b"null")
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read() or b"null")
        except Exception: return e.code, None

def portal(tok):
    return post(f"http://127.0.0.1:{RPC}/rpc/billing.portal", {"input": {}}, {"authorization": f"Bearer {tok}"} if tok else {})

procs = []
try:
    serve(MOCK, MockSupabase); serve(POLAR, MockPolar)
    open(tmp + "/pcp.key", "w").write(KEY + "\n")
    ed = tmp + "/eng"; os.makedirs(ed)
    ee = dict(os.environ, PORT=str(ENG), DATABASE_URL="postgres://x:x@127.0.0.1:1/x", WAL_DIR=ed + "/wal", POLAR_WEBHOOK_SECRET="whsec_dGVzdA==",
              POLAR_ACCESS_TOKEN="polar_oat_test", PCP_KEY_FILE=tmp + "/pcp.key", PCP_PAUSE_DIR=ed, PCP_POLAR_API=f"http://127.0.0.1:{POLAR}")
    procs.append(subprocess.Popen([ENGINE_BIN], env=ee, cwd=ed, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    re_ = dict(os.environ, SUPABASE4_URL=f"http://127.0.0.1:{MOCK}", SUPABASE4_SERVICE_ROLE_KEY="svc-test", PCP_KEY_FILE=tmp + "/pcp.key",
               POLAR_ENGINE_URL=f"http://127.0.0.1:{ENG}", RUST_LOG="error")
    procs.append(subprocess.Popen([RUST_BIN], env=re_, stdout=open(tmp + "/rust.log", "w"), stderr=subprocess.STDOUT))
    import socket
    for port in (ENG, RPC):
        for _ in range(150):
            try: socket.create_connection(("127.0.0.1", port), timeout=1).close(); break
            except OSError: time.sleep(0.2)

    print("\n== 1) Rust app -> signed -> naya engine -> mock Polar")
    s, j = portal(mint(USER_OK))
    url = (j or {}).get("result", {}).get("data", {}).get("url")
    check("asli user: 200 + Polar portal URL", s == 200 and url == "https://polar.sh/anexomail/portal?customer_session_token=abc123", (s, j))
    check("mock Polar ko sahi customer + Bearer token gaya", polar_calls and polar_calls[-1][2] == {"external_customer_id": USER_OK} and polar_calls[-1][1] == "Bearer polar_oat_test", polar_calls[-1:])
    s, j = portal(mint(USER_OK)); check("dobara call bhi chalta hai (naya nonce)", s == 200, (s, j))

    print("\n== 2) galat/ajeeb halat")
    s, j = portal(mint(USER_NOCUST))
    check("Polar mein customer nahi -> 422 no_billing_account", s == 422 and j["error"]["code"] == "no_billing_account", (s, j))
    s, j = portal(mint(USER_EVIL))
    check("Polar ne ghalat host ka URL diya -> reject (502 portal_unavailable), URL client tak nahi", s == 502 and "evil" not in json.dumps(j), (s, j))
    s, j = portal(mint(USER_5XX))
    check("Polar 500 -> 502 portal_unavailable", s == 502 and j["error"]["code"] == "portal_unavailable", (s, j))
    s, j = portal(None); check("bina login -> 401", s == 401, (s, j))
    s, j = portal("not.a.jwt"); check("kharab token -> 401", s == 401, (s, j))
    s, j = post(f"http://127.0.0.1:{RPC}/rpc/billing.portal", {"input": {"user_id": USER_NOCUST}}, {"authorization": "Bearer " + mint(USER_OK)})
    check("body mein dusre user ka user_id bhejne se kuch nahi badla (token ka user hi chalta hai)", s == 200 and polar_calls[-1][2] == {"external_customer_id": USER_OK}, (s, j))

    print("\n== 3) kill switch + engine band")
    open(ed + "/PAUSE_PORTAL", "w").close()
    s, j = portal(mint(USER_OK)); check("PAUSE_PORTAL -> 409 portal_paused", s == 409 and j["error"]["code"] == "portal_paused", (s, j))
    os.remove(ed + "/PAUSE_PORTAL")
    s, j = portal(mint(USER_OK)); check("file hatao -> wapas chalu", s == 200, (s, j))
    procs[0].terminate(); procs[0].wait(timeout=5); time.sleep(0.5)
    s, j = portal(mint(USER_OK)); check("engine band -> 502 portal_unavailable (Rust crash nahi)", s == 502 and j["error"]["code"] == "portal_unavailable", (s, j))
    s, _ = post(f"http://127.0.0.1:{RPC}/rpc/health", {}); 

    print("\n== 4) Bun signer (billing-sync.ts pcpHeaders) bhi isi engine se")
    procs[0] = subprocess.Popen([ENGINE_BIN], env=ee, cwd=ed, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(100):
        try: socket.create_connection(("127.0.0.1", ENG), timeout=1).close(); break
        except OSError: time.sleep(0.2)
    src = open(os.path.dirname(os.path.abspath(__file__)) + "/../../../server/routes/billing-sync.ts").read()
    a = src.index("export function pcpHeaders"); b = src.index('authRouter.post("/portal"')
    open(tmp + "/pcp.ts", "w").write('import { createHash, createHmac, randomBytes } from "node:crypto";\n' + src[a:b])
    open(tmp + "/run.ts", "w").write(f'''import {{ pcpHeaders }} from "./pcp.ts";
const body = JSON.stringify({{ user_id: "{USER_OK}" }});
const r = await fetch("http://127.0.0.1:{ENG}/api/v1/portal", {{ method: "POST", headers: pcpHeaders("{KEY}", "POST", "/api/v1/portal", body), body }});
console.log(r.status, await r.text());''')
    out = subprocess.run(["bun", "run", tmp + "/run.ts"], capture_output=True, text=True, env=dict(os.environ, NO_PROXY="127.0.0.1", no_proxy="127.0.0.1")).stdout.strip()
    check("Bun ne muhar lagayi -> engine ne 200 + URL diya", out.startswith("200") and "polar.sh/anexomail/portal" in out, out)
finally:
    for p in procs:
        try: p.terminate(); p.wait(timeout=5)
        except Exception: pass
print(f"\nRESULT: {passed} pass, {failed} fail"); sys.exit(1 if failed else 0)
