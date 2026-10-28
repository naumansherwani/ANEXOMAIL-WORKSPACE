#!/usr/bin/env python3
"""F1a-1 end-to-end TEST HARNESS (test only — never part of production, FC26): real `anexomail-founder` binary + REAL Postgres (E102/E103/E104 applied)
behind a tiny PostgREST-shaped shim that signs ES256 session tokens like Supabase. Proves: exchange, first-device trust, pending/approve/revoke,
instant revoke on an already-issued token, legacy-token switch, cross-audience refusal, rate limit, audit chain.
Usage: e2e_exchange.py <founder-binary> <psql-db-name>   (needs postgres superuser via `su postgres`)"""
import base64, http.server, json, os, subprocess, sys, tempfile, threading, time, urllib.request, urllib.error, uuid
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

BIN, DB = sys.argv[1], sys.argv[2]
def psql(sql):
    r = subprocess.run(["su", "postgres", "-c", f"psql -X -At -d {DB} -v ON_ERROR_STOP=1 -c \"{sql.replace(chr(34), chr(92)+chr(34))}\""], capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr).strip()
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
KEY = ec.generate_private_key(ec.SECP256R1()); PUB = KEY.public_key().public_numbers()
def session_token(sub, port, exp_in=3600):
    h = b64(json.dumps({"alg": "ES256", "typ": "JWT", "kid": "sb1"}).encode())
    p = b64(json.dumps({"iss": f"http://127.0.0.1:{port}/auth/v1", "aud": "authenticated", "sub": sub, "email": "founder@test", "exp": int(time.time()) + exp_in}).encode())
    r, s = decode_dss_signature(KEY.sign(f"{h}.{p}".encode(), ec.ECDSA(hashes.SHA256())))
    return f"{h}.{p}.{b64(r.to_bytes(32,'big') + s.to_bytes(32,'big'))}"
FOUNDER = psql("select user_id from public.founder_accounts limit 1")[1]
q = lambda v: "'" + str(v).replace("'", "''") + "'"

PROFILES = {}  # test-only stand-in for public.account_profiles (the real table is Supabase; shape = PostgREST)
class Shim(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj):
        b = json.dumps(obj).encode(); self.send_response(code); self.send_header("content-type", "application/json"); self.send_header("content-length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path.startswith("/auth/v1/.well-known/jwks.json"):
            return self._send(200, {"keys": [{"kty": "EC", "crv": "P-256", "kid": "sb1", "alg": "ES256", "x": b64(PUB.x.to_bytes(32, "big")), "y": b64(PUB.y.to_bytes(32, "big"))}]})
        if self.path.startswith("/rest/v1/founder_accounts"):
            if "user_id=eq." not in self.path:
                return self._send(200, [{"user_id": u} for u in psql("select user_id from public.founder_accounts")[1].split()])
            uid = self.path.split("user_id=eq.")[1].split("&")[0]
            rc, out = psql(f"select count(*) from public.founder_accounts where user_id = {q(uid)}::uuid") if len(uid) == 36 else (1, "0")
            return self._send(200, [{"user_id": uid}] if out == "1" else [])
        if self.path.startswith("/rest/v1/account_profiles"):
            uid = self.path.split("user_id=eq.")[1].split("&")[0]
            return self._send(200, [PROFILES[uid]] if uid in PROFILES else [])
        self._send(404, {})
    def do_PATCH(self):
        if self.path.startswith("/rest/v1/account_profiles"):
            uid = self.path.split("user_id=eq.")[1].split("&")[0]; body = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
            if uid not in PROFILES: return self._send(200, [])
            PROFILES[uid].update(body); return self._send(200, [PROFILES[uid]])
        self._send(404, {})
    def do_POST(self):
        if self.path.startswith("/rest/v1/rpc/"):
            name = self.path.rsplit("/", 1)[1]; body = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
            args = ", ".join(f"{k} => {q(v)}" for k, v in body.items())
            rc, out = psql(f"select to_json(public.{name}({args}))")
            return self._send(200, json.loads(out)) if rc == 0 else self._send(400, {"message": out})
        self._send(404, {})

srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Shim); PORT = srv.server_address[1]; threading.Thread(target=srv.serve_forever, daemon=True).start()
tmp = tempfile.mkdtemp(); kf = os.path.join(tmp, "tok.p8"); os.makedirs(os.path.join(tmp, "web")); open(os.path.join(tmp, "web", "index.html"), "w").write("ok")
assert subprocess.run([BIN, "--gen-token-key", kf], capture_output=True, text=True).stdout.strip() == "generated"
assert oct(os.stat(kf).st_mode & 0o777) == "0o400", "key file must be 0400"
FPORT = 3299; proc = None
def start(legacy="1", keyfile=kf):
    global proc
    if proc: proc.terminate(); proc.wait()
    env = dict(os.environ, SUPABASE4_URL=f"http://127.0.0.1:{PORT}", SUPABASE4_SERVICE_ROLE_KEY="k", FOUNDER_HMAC_KEY="x" * 40, FOUNDER_BIND=f"127.0.0.1:{FPORT}",
               FOUNDER_TOKEN_KEY_FILE=keyfile, FOUNDER_LEGACY_TOKEN=legacy, FOUNDER_STATIC=os.path.join(tmp, "web"), EXPIRY_WATCH_FILE=os.path.join(tmp, "none"))
    proc = subprocess.Popen([BIN], env=env, stderr=subprocess.PIPE, text=True)
    for _ in range(50):
        try: urllib.request.urlopen(f"http://127.0.0.1:{FPORT}/healthz", timeout=1); return
        except Exception: time.sleep(0.1)
    raise SystemExit("founder binary did not start")
def call(method, path, tok=None, body=None):
    req = urllib.request.Request(f"http://127.0.0.1:{FPORT}{path}", method=method, data=json.dumps(body).encode() if body is not None else None, headers={"content-type": "application/json", **({"authorization": f"Bearer {tok}"} if tok else {})})
    try:
        with urllib.request.urlopen(req, timeout=8) as r: return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read() or b"{}")
        except Exception: return e.code, {}
fails = []
def check(name, cond, extra=""):
    print(("PASS " if cond else "FAIL ") + name + (f"  {extra}" if not cond and extra else "")); 
    if not cond: fails.append(name)

psql("delete from public.founder_devices")  # saaf shuruaat (sandbox DB)
start()
S = session_token(FOUNDER, PORT); A = "A" * 40; B = "B" * 40
check("exchange without bearer = 401", call("POST", "/founder/v1/exchange", None, {"device_id": A})[0] == 401)
check("exchange with non-founder session = 403", call("POST", "/founder/v1/exchange", session_token(str(uuid.uuid4()), PORT), {"device_id": A})[0] == 403)
check("exchange bad device id = 400", call("POST", "/founder/v1/exchange", S, {"device_id": "short"})[0] == 400)
c, r = call("POST", "/founder/v1/exchange", S, {"device_id": A, "label": "Test Laptop"})
check("first device trusted on first use -> founder token", c == 200 and r.get("first") is True and r.get("expires_in") == 900, str((c, r)))
TA = r.get("token", "")
check("founder token opens /me", call("GET", "/founder/v1/me", TA)[0] == 200)
check("legacy session token still accepted (grace)", call("GET", "/founder/v1/me", S)[0] == 200)
check("junk token = 401", call("GET", "/founder/v1/me", "a.b.c")[0] == 401)
c, r = call("POST", "/founder/v1/exchange", S, {"device_id": B, "label": "Phone"})
check("second device = 403 device_pending + code", c == 403 and r.get("error") == "device_pending" and len(r.get("code", "")) == 8, str((c, r)))
code = r.get("code", "")
check("pending device cannot get token on retry", call("POST", "/founder/v1/exchange", S, {"device_id": B})[0] == 403)
rc, out = psql(f"select public.founder_device_approve({q(FOUNDER)}::uuid, {q(code)}, 'approved by e2e from server')")
check("approve (server side RPC)", rc == 0, out)
c, r = call("POST", "/founder/v1/exchange", S, {"device_id": B, "label": "Phone"}); TB = r.get("token", "")
check("approved device now gets token", c == 200 and TB != "", str((c, r)))
check("device B token works", call("GET", "/founder/v1/bridge", TB)[0] in (200,))
rc, out = psql(f"select public.founder_device_revoke({q(FOUNDER)}::uuid, {q(code)}, 'revoked by e2e from server')")
check("revoke (server side RPC)", rc == 0, out)
check("ALREADY-ISSUED token of revoked device dies immediately", call("GET", "/founder/v1/me", TB)[0] == 401)
check("revoked device cannot exchange", call("POST", "/founder/v1/exchange", S, {"device_id": B})[0] == 403)
check("device A token unaffected", call("GET", "/founder/v1/me", TA)[0] == 200)
# aud separation: founder token is not a session token, session token is not a founder token
start(legacy="0")
check("legacy OFF: session token refused", call("GET", "/founder/v1/me", S)[0] == 401)
check("legacy OFF: founder token works", call("GET", "/founder/v1/me", TA)[0] == 200)
check("legacy OFF: exchange still works with session token", call("POST", "/founder/v1/exchange", S, {"device_id": A})[0] == 200)
# wrong key file: a token minted by another key is refused
other = os.path.join(tmp, "other.p8"); subprocess.run([BIN, "--gen-token-key", other], capture_output=True)
start(legacy="0", keyfile=other)
check("token from a different key = 401", call("GET", "/founder/v1/me", TA)[0] == 401)
start(legacy="1", keyfile=os.path.join(tmp, "missing.p8"))
check("no key file: exchange = 503 (never fake)", call("POST", "/founder/v1/exchange", S, {"device_id": A})[0] == 503)
start()
codes = []
for i in range(6):
    codes.append(call("POST", "/founder/v1/exchange", S, {"device_id": ("C%d" % i) * 20})[0])
check("rate limit kicks in (429 after repeated pending)", 429 in codes, str(codes))
# server-side helper script (founder-device.sh) against the same shim
envf = os.path.join(tmp, "founder.env"); open(envf, "w").write(f"SUPABASE4_URL=http://127.0.0.1:{PORT}\nSUPABASE4_SERVICE_ROLE_KEY=k\n")
SH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../docs/cursor-work/server/founder-device.sh")
sh = lambda *a, **e: subprocess.run(["bash", SH, *a], capture_output=True, text=True, env=dict(os.environ, FOUNDER_ENV=envf, **e))
r = sh("list"); check("founder-device.sh list shows devices", r.returncode == 0 and "approved" in r.stdout and "CODE" in r.stdout, r.stdout + r.stderr)
start()  # fresh rate-limit window
c, rr = call("POST", "/founder/v1/exchange", S, {"device_id": "L" * 40})
check("pending cap (5) answers 429 'too many pending devices'", c == 429 and "pending" in str(rr), str((c, rr)))
psql("delete from public.founder_devices where approved_at is null and revoked_at is null")  # test-only cleanup of the pending rows made above
start()
D = "D" * 40; c, rr = call("POST", "/founder/v1/exchange", S, {"device_id": D, "label": "Tablet"}); dcode = rr.get("code", "")
check("new device D pending", c == 403 and len(dcode) == 8, str((c, rr)))
r = sh("approve", dcode, REASON="approved by e2e through script"); check("founder-device.sh approve", r.returncode == 0 and r.stdout.startswith("OK"), r.stdout + r.stderr)
check("device D can now exchange", call("POST", "/founder/v1/exchange", S, {"device_id": D})[0] == 200)
r = sh("revoke", dcode, REASON="revoked by e2e through script"); check("founder-device.sh revoke", r.returncode == 0 and r.stdout.startswith("OK"), r.stdout + r.stderr)
r = sh("approve", "ZZZZZZZZ"); check("script rejects bad code", r.returncode != 0)
# --- profile photo (Account menu) ---
PROFILES[FOUNDER] = {"display_name": "Test Founder", "legal_name": "T F", "avatar_url": None}
c, r = call("GET", "/founder/v1/profile", TA); d = r.get("data", {})
check("profile read: name + email, no photo yet", c == 200 and d.get("display_name") == "Test Founder" and d.get("avatar_url") is None and d.get("profile_found") is True, str((c, r)))
check("profile needs a token", call("GET", "/founder/v1/profile")[0] == 401)
PNG = "data:image/png;base64,iVBORw0KGgo="
c, r = call("PUT", "/founder/v1/profile/avatar", TA, {"avatar_url": PNG}); check("photo save", c == 200, str((c, r)))
check("photo is now stored and returned", call("GET", "/founder/v1/profile", TA)[1]["data"]["avatar_url"] == PNG)
check("svg / script photo refused (400)", call("PUT", "/founder/v1/profile/avatar", TA, {"avatar_url": "data:image/svg+xml;base64,PHN2Zz4="})[0] == 400 and call("PUT", "/founder/v1/profile/avatar", TA, {"avatar_url": "javascript:alert(1)"})[0] == 400)
check("refused photo did not overwrite the good one", call("GET", "/founder/v1/profile", TA)[1]["data"]["avatar_url"] == PNG)
check("photo remove (null)", call("PUT", "/founder/v1/profile/avatar", TA, {"avatar_url": None})[0] == 200 and call("GET", "/founder/v1/profile", TA)[1]["data"]["avatar_url"] is None)
check("photo save without token = 401", call("PUT", "/founder/v1/profile/avatar", None, {"avatar_url": PNG})[0] == 401)
PROFILES.pop(FOUNDER); check("no profile row -> honest 502, nothing invented", call("PUT", "/founder/v1/profile/avatar", TA, {"avatar_url": PNG})[0] == 502)
rc, out = psql("select string_agg(action, ',' order by seq) from public.founder_audit where action like 'profile.%'")
check("photo changes are in the audit ledger", "profile.avatar_set" in out and "profile.avatar_removed" in out, out)
rc, out = psql("select public.founder_audit_verify(1) is null")
check("audit chain intact", out == "t", out)
rc, out = psql("select string_agg(action, ',' order by seq) from public.founder_audit where action like 'founder.device.%'")
check("audit has first_approved/pending/approved/revoked", all(x in out for x in ["first_approved", "pending", "approved", "revoked"]), out)
rc, out = psql("select count(*) from public.founder_devices where ua_hash ~ '^[0-9a-f]{64}$' and ua_hash not like '%AAAA%'")
check("only hashes stored (raw device ids never)", rc == 0 and int(out) >= 2)
if proc: proc.terminate()
print(f"\n{'ALL PASS' if not fails else 'FAILED: ' + ', '.join(fails)}"); sys.exit(1 if fails else 0)
