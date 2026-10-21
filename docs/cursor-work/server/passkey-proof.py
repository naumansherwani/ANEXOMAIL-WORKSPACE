#!/usr/bin/env python3
"""B2 live proof (server par). Software authenticator: openssl EC P-256 key; credential test account ke naam par REST se daalta hai,
phir Rust :3200 par poora passkey login chalata hai, aur AAKHIR mein sab saaf kar deta hai. Koi secret print nahi hota.
Env: RPC SBU SBK EMAIL BRAIN (PUBLIC_ONLY=1: sandbox mock — token waali jaanchen chhod do). Exit 0 = sab PASS."""
import base64, hashlib, json, os, subprocess, sys, tempfile, urllib.request, urllib.error

RPC = os.environ.get("RPC", "http://127.0.0.1:3200"); BRAIN = os.environ.get("BRAIN", "http://127.0.0.1:3100")
SBU = os.environ["SBU"].rstrip("/"); SBK = os.environ["SBK"]; EMAIL = os.environ.get("EMAIL", "basic.test@anexomail.com")
ORIGIN = "https://anexomail.com"; UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
fails = []

def b64(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()
def req(method, url, body=None, headers=None):
    h = {"content-type": "application/json"}; h.update(headers or {})
    r = urllib.request.Request(url, data=(json.dumps(body).encode() if body is not None else None), headers=h, method=method)
    try:
        with urllib.request.urlopen(r, timeout=20) as x: raw = x.read(); code = x.status
    except urllib.error.HTTPError as e: raw = e.read(); code = e.code
    try: return code, json.loads(raw or b"null")
    except Exception: return code, None
def sb(method, path, body=None, extra=None):
    return req(method, SBU + path, body, dict({"apikey": SBK, "authorization": "Bearer " + SBK, "prefer": "return=representation"}, **(extra or {})))
def rpc(proc, inp, origin=ORIGIN, auth=None):
    h = {"origin": origin, "user-agent": UA}
    if auth: h["authorization"] = "Bearer " + auth
    code, j = req("POST", f"{RPC}/rpc/{proc}", {"input": inp}, h)
    data = ((j or {}).get("result") or {}).get("data"); e = (j or {}).get("error") or {}
    return code, data, e.get("code")
def check(name, cond, detail=""):
    print(("   PASS " if cond else "   FAIL ") + name + (("  [" + str(detail) + "]") if (detail and not cond) else ""))
    if not cond: fails.append(name)

tmp = tempfile.mkdtemp()
subprocess.check_call(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", tmp + "/k.pem"], stderr=subprocess.DEVNULL)
der = subprocess.check_output(["openssl", "ec", "-in", tmp + "/k.pem", "-pubout", "-outform", "DER"], stderr=subprocess.DEVNULL)
pt = der[-65:]; assert pt[0] == 4
x, y = pt[1:33], pt[33:65]
cred_id = b64(os.urandom(32))
code, uid = req("POST", SBU + "/rest/v1/rpc/auth_user_id_by_email", {"_email": EMAIL}, {"apikey": SBK, "authorization": "Bearer " + SBK})
if not isinstance(uid, str):
    print("   FAIL test account nahi mila:", EMAIL); sys.exit(2)

def sign(data):
    open(tmp + "/d", "wb").write(data)
    return subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", tmp + "/k.pem", tmp + "/d"], stderr=subprocess.DEVNULL)
def assertion(challenge, counter, tamper=False, origin=ORIGIN):
    cd = json.dumps({"type": "webauthn.get", "challenge": challenge, "origin": origin}, separators=(",", ":")).encode()
    auth = hashlib.sha256(b"anexomail.com").digest() + bytes([0x05]) + counter.to_bytes(4, "big")
    sig = sign(auth + hashlib.sha256(cd + (b"x" if tamper else b"")).digest())
    return {"id": cred_id, "rawId": cred_id, "type": "public-key",
            "response": {"clientDataJSON": b64(cd), "authenticatorData": b64(auth), "signature": b64(sig)}}

token = None
try:
    c, _ = sb("POST", "/rest/v1/webauthn_credentials", {"user_id": uid, "credential_id": cred_id, "public_key": {"kty": "EC", "crv": "P-256", "x": b64(x), "y": b64(y)},
                                                       "sign_count": 0, "device_name": "B2 proof (auto-delete)", "transports": ["internal"]})
    check("test passkey daakhil hua", c in (200, 201), c)
    # 1 options
    c, d, e = rpc("auth.passkey.options", {"email": EMAIL})
    ch = ((d or {}).get("publicKey") or {}).get("challenge")
    ids = [a.get("id") for a in ((d or {}).get("publicKey") or {}).get("allowCredentials", [])]
    check("options: 200 + challenge + hamara credential", c == 200 and ch and cred_id in ids, (c, e))
    # 2 hostile origin
    c, _, e = rpc("auth.passkey.options", {"email": EMAIL}, origin="https://evil.example")
    check("options: ghalat origin band (400)", c == 400 and e == "passkey_host_not_allowed", (c, e))
    # 3 unknown account == no-passkey account (same answer, no enumeration)
    c1, _, e1 = rpc("auth.passkey.options", {"email": "nobody-b2-proof@anexomail.com"})
    check("options: anjaan account -> 400 no_passkey", c1 == 400 and e1 == "no_passkey", (c1, e1))
    # 4 tampered assertion fails AND burns the challenge
    c, _, e = rpc("auth.passkey.verify", assertion(ch, 1, tamper=True))
    check("verify: tamper signature rad (400)", c == 400 and e == "assertion_signature", (c, e))
    c, _, e = rpc("auth.passkey.verify", assertion(ch, 1))
    check("verify: ghalat koshish ke baad wohi challenge jal chuka (400)", c == 400 and e == "passkey_challenge_expired", (c, e))
    # 5 happy path
    c, d, e = rpc("auth.passkey.options", {"email": EMAIL}); ch2 = ((d or {}).get("publicKey") or {}).get("challenge")
    good = assertion(ch2, 1)
    c, d, e = rpc("auth.passkey.verify", good)
    token = (d or {}).get("token")
    check("verify: asli assertion -> 200 + token + refresh_token", c == 200 and token and (d or {}).get("refresh_token"), (c, e))
    if token and not os.environ.get("PUBLIC_ONLY"):
        c, _, e = rpc("chat.conversations.list", {}, auth=token)
        check("naye token par Rust auth chali (401 nahi)", c != 401, c)
        r = urllib.request.Request(BRAIN + "/api/auth/session", headers={"authorization": "Bearer " + token}); 
        try: bc = urllib.request.urlopen(r, timeout=20).status
        except urllib.error.HTTPError as ex: bc = ex.code
        check("naye token par Brain /api/auth/session 200", bc == 200, bc)
        c, d, e = rpc("auth.passkey.status", {}, auth=token)
        check("status: test account exempt", c == 200 and (d or {}).get("exempt") is True, (c, d))
    # 6 replay of the very same assertion
    c, _, e = rpc("auth.passkey.verify", good)
    check("replay: wohi assertion dobara -> 400", c == 400 and e == "passkey_challenge_expired", (c, e))
    # 7 sign counter must go forward (clone detection): counter 1 again with a fresh challenge
    c, d, e = rpc("auth.passkey.options", {"email": EMAIL}); ch3 = ((d or {}).get("publicKey") or {}).get("challenge")
    c, _, e = rpc("auth.passkey.verify", assertion(ch3, 1))
    check("clone detection: counter wapas = rad (400)", c == 400 and e == "sign_count_cloned", (c, e))
    # 8 recovery: wrong code
    c, _, e = rpc("auth.recovery.redeem", {"email": EMAIL, "code": "AAAA-AAAA-AAAA"})
    check("recovery: ghalat code -> 400 invalid", c == 400 and e == "invalid", (c, e))
    # 9 garbage never reaches a filter
    c, _, e = rpc("auth.passkey.verify", {"id": "x)&or=(id.gt.0", "response": {"clientDataJSON": b64(b'{"type":"webauthn.get","challenge":"a,b","origin":"https://anexomail.com"}')}})
    check("filter-injection waala challenge -> 400", c == 400, c)
finally:
    sb("DELETE", "/rest/v1/webauthn_credentials?credential_id=eq." + cred_id)
    sb("DELETE", "/rest/v1/webauthn_challenges?user_id=eq." + uid)
    if token:
        req("POST", SBU + "/auth/v1/logout?scope=local", None, {"apikey": SBK, "authorization": "Bearer " + token})
        th = hashlib.sha256(token.encode()).hexdigest()
        sb("DELETE", "/rest/v1/account_sessions?token_hash=eq." + th)
    print("   (test credential + challenges + session saaf kar diye)")
print("PROOF:", "SAB PASS" if not fails else "FAIL -> " + ", ".join(fails))
sys.exit(0 if not fails else 1)
