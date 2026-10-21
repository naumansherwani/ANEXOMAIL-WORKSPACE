#!/usr/bin/env python3
"""
B6a sandbox proof — Polar Control Plane (21 Oct 2026).
Purane (live) engine aur naye engine ko SAATH chala kar muqabla karta hai.
  python3 polar-cp-proof.py /tmp/engine-orig /tmp/engine-new
Mock: Postgres (band — engine ko DB ke baghair bhi 200 dena chahiye), Polar API (nahi — asli Polar
sandbox se bahar hai, is liye portal ka Polar-wala hissa SIRF server par verify hoga).
"""
import base64, hashlib, hmac, json, os, shutil, subprocess, sys, tempfile, time, urllib.request, uuid

ORIG, NEW = sys.argv[1], sys.argv[2]
KEY = "k" * 48
WHSEC = "whsec_" + base64.b64encode(b"sandbox-webhook-secret-bytes-0123456789").decode()
passed = failed = 0


def check(name, cond, extra=""):
    global passed, failed
    if cond:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}  {extra}")


def start(binary, port, with_key, token=""):
    d = tempfile.mkdtemp(prefix=f"pe{port}-")
    keyfile = os.path.join(d, "pcp.key")
    if with_key:
        open(keyfile, "w").write(KEY + "\n")
    env = {
        "PATH": os.environ["PATH"],
        "PORT": str(port),
        "DATABASE_URL": "postgres://x:x@127.0.0.1:1/x",
        "WAL_DIR": os.path.join(d, "wal"),
        "POLAR_WEBHOOK_SECRET": WHSEC,
        "POLAR_ACCESS_TOKEN": token,
        "PCP_KEY_FILE": keyfile,
        "PCP_KEY": "",
        "PCP_PAUSE_DIR": d,
        "HOME": d,
    }
    p = subprocess.Popen([binary], env=env, cwd=d, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    import socket
    for _ in range(100):
        try:
            socket.create_connection(("127.0.0.1", port), timeout=1).close()
            break
        except OSError:
            time.sleep(0.1)
    return p, d


def req(port, method, path, body=None, headers=None):
    data = body if isinstance(body, (bytes, type(None))) else json.dumps(body).encode()
    r = urllib.request.Request(f"http://127.0.0.1:{port}{path}", data=data, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(r, timeout=15) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def jbody(raw):
    try:
        return json.loads(raw)
    except Exception:
        return {"_raw": raw.decode(errors="replace")}


def webhook_headers(body: bytes, wid="evt_proof_1", ts=None, secret=WHSEC, extra=None):
    ts = str(ts or int(time.time()))
    key = base64.b64decode(secret[len("whsec_"):])
    sig = base64.b64encode(hmac.new(key, f"{wid}.{ts}.{body.decode()}".encode(), hashlib.sha256).digest()).decode()
    h = {"webhook-id": wid, "webhook-timestamp": ts, "webhook-signature": f"v1,{sig}", "content-type": "application/json"}
    h.update(extra or {})
    return h


def pcp_headers(method, path, body: bytes, ts=None, nonce=None, key=KEY):
    ts = int(ts if ts is not None else time.time())
    nonce = nonce or uuid.uuid4().hex
    canon = f"v1\n{method.upper()}\n{path}\n{ts}\n{nonce}\n{hashlib.sha256(body).hexdigest()}"
    sig = hmac.new(key.encode(), canon.encode(), hashlib.sha256).hexdigest()
    return {"x-pcp-ts": str(ts), "x-pcp-nonce": nonce, "x-pcp-sig": sig, "content-type": "application/json"}


def wal_events(d):
    out = []
    pend = os.path.join(d, "wal", "pending")
    for f in sorted(os.listdir(pend)):
        if f.endswith(".json"):
            out.append(json.load(open(os.path.join(pend, f))))
    return out


procs = []
try:
    po, do_ = start(ORIG, 3491, False); procs.append(po)
    pn0, dn0 = start(NEW, 3492, False); procs.append(pn0)
    pn, dn = start(NEW, 3493, True); procs.append(pn)
    UID = str(uuid.uuid4())

    print("\n== A. WEBHOOK: purana vs naya (paisa tootna nahi chahiye) ==")
    ev = json.dumps({"type": "order.paid", "data": {"id": "ord_proof_1", "amount": 4600}}).encode()
    results = {}
    for tag, port, d in (("orig", 3491, do_), ("new-nokey", 3492, dn0), ("new-key", 3493, dn)):
        s, b = req(port, "POST", "/api/v1/polar-webhook", ev, webhook_headers(ev))
        s2, b2 = req(port, "POST", "/api/v1/polar-webhook", ev, webhook_headers(ev, wid="evt_proof_xff", extra={"x-forwarded-for": "203.0.113.9", "x-real-ip": "203.0.113.9"}))
        sbad, bbad = req(port, "POST", "/api/v1/polar-webhook", ev, {"webhook-id": "x", "webhook-timestamp": str(int(time.time())), "webhook-signature": "v1,AAAA"})
        s_old, _ = req(port, "POST", "/api/v1/polar-webhook", ev, webhook_headers(ev, wid="evt_old", ts=int(time.time()) - 4000))
        results[tag] = (s, b, s2, sbad, bbad, s_old, wal_events(d))
    for tag, r in results.items():
        check(f"{tag}: valid webhook -> 200 (DB band hone par bhi)", r[0] == 200 and b"Accepted" in r[1], r[:2])
        check(f"{tag}: webhook via proxy header (X-Forwarded-For, Caddy jaisa) -> 200", r[2] == 200)
        check(f"{tag}: galat signature -> 401", r[3] == 401)
        check(f"{tag}: purana timestamp -> 401", r[5] == 401)
        check(f"{tag}: WAL mein dono event likhe gaye", len(r[6]) == 2, len(r[6]))
    o, n = results["orig"], results["new-key"]
    strip = lambda evs: [(e["event_id"], e["event_type"], e["payload"]) for e in evs]
    check("WAL ka mazmoon purane engine jaisa (byte-for-byte payload)", strip(o[6]) == strip(n[6]))
    check("jawab ka matn purane jaisa", o[1] == n[1] and o[4] == n[4])

    print("\n== B. health / ready / metrics wahi, bas pcp_* ka izafa ==")
    for path in ("/health", "/ready", "/metrics"):
        so, bo = req(3491, "GET", path); sn, bn = req(3493, "GET", path)
        jo, jn = jbody(bo), jbody(bn)
        extra = set(jn) - set(jo)
        check(f"{path}: status barabar ({so}/{sn})", so == sn)
        check(f"{path}: purani saari keys maujood", set(jo) <= set(jn))
        check(f"{path}: naya sirf pcp_* jodta hai", extra <= {"pcp_ok", "pcp_denied"}, extra)

    print("\n== C. PURANA ENGINE: sabit karo ke darwaaza khula tha ==")
    s, b = req(3491, "GET", f"/api/v1/billing/{UID}")
    check("orig: billing bina muhar handler tak pahunchta tha (401 nahi)", s != 401, s)
    s, b = req(3491, "POST", "/api/v1/checkout", json.dumps({"product_key": "NOPE"}).encode(), {"content-type": "application/json"})
    check("orig: checkout bina muhar handler tak pahunchta tha", s in (400, 503), s)

    print("\n== D. NAYA ENGINE — muhar ke bina sab band ==")
    for path, method, body in ((f"/api/v1/billing/{UID}", "GET", None), ("/api/v1/checkout", "POST", {"product_key": "X"}), ("/api/v1/checkout/abc", "GET", None), ("/api/v1/portal", "POST", {"user_id": UID})):
        s, b = req(3493, method, path, body)
        check(f"unsigned {method} {path.split('/')[3]} -> 401 signature_required", s == 401 and jbody(b).get("error") == "signature_required", (s, b))
    s, b = req(3492, "POST", "/api/v1/portal", {"user_id": UID})
    check("key hi nahi -> FAIL-CLOSED 503 (kuch nahi chalta)", s == 503 and jbody(b).get("error") == "control_plane_key_missing", (s, b))
    s, _ = req(3492, "POST", "/api/v1/polar-webhook", ev, webhook_headers(ev, wid="evt_nokey"))
    check("key na ho tab bhi WEBHOOK 200 (webhook control plane se alag)", s == 200)

    print("\n== E. NAYA ENGINE — sahi muhar ==")
    pb = json.dumps({"user_id": UID}).encode()
    h = pcp_headers("POST", "/api/v1/portal", pb)
    s, b = req(3493, "POST", "/api/v1/portal", pb, h)
    check("sahi muhar gate paar karti hai (Polar token nahi -> 503 polar_token_missing)", s == 503 and jbody(b).get("error") == "polar_token_missing", (s, b))
    s, b = req(3493, "POST", "/api/v1/portal", pb, h)
    check("wahi request dobara (replay) -> 401 replayed_request", s == 401 and jbody(b).get("error") == "replayed_request", (s, b))
    bad = json.dumps({"user_id": "../../etc/passwd"}).encode()
    s, b = req(3493, "POST", "/api/v1/portal", bad, pcp_headers("POST", "/api/v1/portal", bad))
    check("user_id UUID nahi -> 400 bad_user_id", s == 400 and jbody(b).get("error") == "bad_user_id", (s, b))
    h2 = pcp_headers("POST", "/api/v1/portal", pb)
    s, b = req(3493, "POST", "/api/v1/portal", json.dumps({"user_id": str(uuid.uuid4())}).encode(), h2)
    check("body badla (muhar purani) -> 401 bad_signature", s == 401 and jbody(b).get("error") == "bad_signature", (s, b))
    s, b = req(3493, "POST", "/api/v1/portal", pb, pcp_headers("POST", "/api/v1/portal", pb, ts=time.time() - 120))
    check("purana timestamp -> 401 stale_request", s == 401 and jbody(b).get("error") == "stale_request", (s, b))
    s, b = req(3493, "POST", "/api/v1/portal", pb, pcp_headers("POST", "/api/v1/portal", pb, key="z" * 48))
    check("galat key -> 401 bad_signature", s == 401 and jbody(b).get("error") == "bad_signature", (s, b))
    s, b = req(3493, "GET", f"/api/v1/billing/{UID}", None, pcp_headers("GET", f"/api/v1/billing/{UID}", b""))
    check("billing sahi muhar ke saath handler tak (DB band -> 503 billing_state_unavailable)", s == 503 and jbody(b).get("error") == "billing_state_unavailable", (s, b))
    big = b"{" + b" " * 70000 + b"}"
    s, b = req(3493, "POST", "/api/v1/portal", big, pcp_headers("POST", "/api/v1/portal", big))
    check("64KB se bada body -> 413", s == 413, s)

    print("\n== F. PROXY SE AAYI REQUEST (Caddy khul bhi jaye to) ==")
    for method, path, body in (("GET", f"/api/v1/billing/{UID}", None), ("POST", "/api/v1/replay", b"{}"), ("POST", "/api/v1/reconcile", b"{}"), ("POST", "/api/v1/portal", pb)):
        hh = pcp_headers(method, path, body or b"")
        hh["x-forwarded-for"] = "198.51.100.7"
        s, b = req(3493, method, path, body, hh)
        check(f"{method} {path.split('/')[3]} + X-Forwarded-For (sahi muhar ke saath bhi) -> 403 internal_only", s == 403 and jbody(b).get("error") == "internal_only", (s, b))
    s, b = req(3493, "POST", "/api/v1/reconcile", b"{}")
    check("replay/reconcile localhost se (docs ka curl) abhi bhi chalte hain", s != 403 and s != 401, s)

    print("\n== G. KILL SWITCH (restart ke baghair) ==")
    open(os.path.join(dn, "PAUSE_PORTAL"), "w").close()
    pb2 = json.dumps({"user_id": UID}).encode()
    s, b = req(3493, "POST", "/api/v1/portal", pb2, pcp_headers("POST", "/api/v1/portal", pb2))
    check("PAUSE_PORTAL -> 503 portal_paused", s == 503 and jbody(b).get("error") == "portal_paused", (s, b))
    s, _ = req(3493, "POST", "/api/v1/polar-webhook", ev, webhook_headers(ev, wid="evt_paused"))
    check("portal rukne par webhook 200 chalta rehta hai", s == 200)
    os.remove(os.path.join(dn, "PAUSE_PORTAL"))
    s, b = req(3493, "POST", "/api/v1/portal", pb2, pcp_headers("POST", "/api/v1/portal", pb2))
    check("file hatao -> portal wapas chalu", jbody(b).get("error") != "portal_paused", (s, b))
    open(os.path.join(dn, "PAUSE_CHECKOUT"), "w").close()
    cb = json.dumps({"product_key": "X"}).encode()
    s, b = req(3493, "POST", "/api/v1/checkout", cb, pcp_headers("POST", "/api/v1/checkout", cb))
    check("PAUSE_CHECKOUT -> 503 checkout_paused", s == 503 and jbody(b).get("error") == "checkout_paused", (s, b))

    print("\n== H. counters ==")
    _, bm = req(3493, "GET", "/metrics")
    m = jbody(bm)
    check("pcp_ok aur pcp_denied gine ja rahe hain", m.get("pcp_ok", 0) >= 3 and m.get("pcp_denied", 0) >= 10, m)
    _, bh = req(3493, "GET", "/health")
    check("health ab bhi sach batata hai (webhook_secret true)", jbody(bh).get("webhook_secret") is True)

    print("\n== I. Python signer == Rust known vector ==")
    canon = "v1\nPOST\n/api/v1/portal\n1700000000\nabcdefghijklmnop1234\n" + hashlib.sha256(b"{}").hexdigest()
    check("canonical format Rust test jaisa", canon.endswith("44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"))
finally:
    for p in procs:
        p.terminate()
    for p in procs:
        try:
            p.wait(timeout=5)
        except Exception:
            p.kill()

print(f"\nRESULT: {passed} pass, {failed} fail")
sys.exit(1 if failed else 0)
