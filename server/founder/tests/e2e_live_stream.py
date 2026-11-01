# 4b-2 TEST HARNESS (test only, never production): real binary + a tiny PostgREST-shaped mock; proves snapshot, tick every 5 s, events frame on change, 401 without token. Usage: e2e_live_stream.py <founder-binary>
import base64, http.server, json, os, subprocess, sys, threading, time, urllib.request, socket
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
BIN=sys.argv[1]; UID="11111111-2222-3333-4444-555555555555"
b64=lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
KEY=ec.generate_private_key(ec.SECP256R1()); N=KEY.public_key().public_numbers()
calls={"tick":0,"report":[],"open":0,"close":[],"sweep":0,"v2":0,"pending":0}
class H(http.server.BaseHTTPRequestHandler):
    def log_message(s,*a): pass
    def send_j(s,o):
        b=json.dumps(o).encode(); s.send_response(200); s.send_header("content-type","application/json"); s.send_header("content-length",str(len(b))); s.end_headers(); s.wfile.write(b)
    def do_GET(s):
        if "jwks" in s.path: return s.send_j({"keys":[{"kty":"EC","crv":"P-256","alg":"ES256","kid":"sb1","x":b64(N.x.to_bytes(32,'big')),"y":b64(N.y.to_bytes(32,'big'))}]})
        if "founder_accounts" in s.path: return s.send_j([{"user_id":UID}])
        s.send_j([])
    def do_POST(s):
        n=int(s.headers.get("content-length",0)); body=json.loads(s.rfile.read(n) or b"{}")
        name=s.path.rsplit("/",1)[1]
        if name=="founder_live_tick":
            calls["tick"]+=1; return s.send_j({"version": 0 if calls["tick"]<2 else 2, "changed": [] if calls["tick"]<2 else ["leads"]})
        if name=="founder_live_snapshot_v2": calls["v2"]+=1; return s.send_j({"version":0,"sources":[],"trouble":{"level":"ok","items":[]},"pending_channels":["support"],"channels":[],"tick_health":{"level":"unknown"}})
        if name=="founder_live_tick_report": calls["report"].append(body); return s.send_j(None)
        if name=="founder_live_session_open": calls["open"]+=1; return s.send_j(41)
        if name=="founder_live_session_close": calls["close"].append(body); return s.send_j(True)
        if name=="founder_live_session_sweep": calls["sweep"]+=1; return s.send_j(0)
        if name=="founder_live_snapshot": return s.send_j({"version":0,"sources":[],"trouble":{"level":"ok","items":[]}})
        if name=="founder_live_since": return s.send_j({"version":2,"events":[{"id":1,"source":"leads","kind":"change"},{"id":2,"source":"leads","kind":"change"}],"gap":False})
        s.send_j(None)
sv=http.server.ThreadingHTTPServer(("127.0.0.1",0),H); port=sv.server_port; threading.Thread(target=sv.serve_forever,daemon=True).start()
fp=socket.socket(); fp.bind(("127.0.0.1",0)); fport=fp.getsockname()[1]; fp.close()
env=dict(os.environ,SUPABASE4_URL=f"http://127.0.0.1:{port}",SUPABASE4_SERVICE_ROLE_KEY="k",FOUNDER_HMAC_KEY="x"*40,FOUNDER_BIND=f"127.0.0.1:{fport}",FOUNDER_STATIC="/tmp",FOUNDER_TELEMETRY="on")
pr=subprocess.Popen([BIN],env=env,stderr=subprocess.PIPE,text=True); time.sleep(1.5)
h=b64(json.dumps({"alg":"ES256","typ":"JWT","kid":"sb1"}).encode())
p=b64(json.dumps({"iss":f"http://127.0.0.1:{port}/auth/v1","aud":"authenticated","sub":UID,"email":"f@t","exp":int(time.time())+600}).encode())
r,s_=decode_dss_signature(KEY.sign(f"{h}.{p}".encode(),ec.ECDSA(hashes.SHA256()))); tok=f"{h}.{p}.{b64(r.to_bytes(32,'big')+s_.to_bytes(32,'big'))}"
req=urllib.request.Request(f"http://127.0.0.1:{fport}/founder/v1/live/stream",headers={"authorization":"Bearer "+tok})
resp=urllib.request.urlopen(req,timeout=30); print("status",resp.status,resp.headers.get("content-type"))
t0=time.time(); buf=b""; frames=[]
while time.time()-t0<13:
    line=resp.readline()
    if not line: break
    if line.startswith(b"event:") or line.startswith(b"id:") or line.startswith(b": hb"): frames.append((round(time.time()-t0,1),line.decode().strip()))
print(frames)
try: urllib.request.urlopen(urllib.request.Request(f"http://127.0.0.1:{fport}/founder/v1/live/stream"),timeout=5)
except Exception as e: print("no token ->",getattr(e,"code",e))
resp.close(); time.sleep(0.6)
print("TELEMETRY", {"v2":calls["v2"],"sweep":calls["sweep"],"open":calls["open"],"reports":len(calls["report"]),"close":calls["close"]})
assert calls["v2"]>=1 and calls["sweep"]==1 and calls["open"]==1, "snapshot_v2/sweep/session_open not called"
assert len(calls["report"])>=2 and all(set(r)=={"p_ok","p_ms"} for r in calls["report"]), "tick_report missing or wrong shape"
assert len(calls["close"])==1 and calls["close"][0]["p_id"]==41 and calls["close"][0]["p_reason"] in ("client_gone","slow_client") and calls["close"][0]["p_frames"]>=3, calls["close"]
print("E2E TELEMETRY OK")
pr.terminate(); print(pr.stderr.read()[-400:])
