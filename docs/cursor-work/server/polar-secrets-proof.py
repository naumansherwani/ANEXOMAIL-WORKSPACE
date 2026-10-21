import base64,hashlib,hmac,json,os,socket,subprocess,sys,tempfile,time,urllib.request,urllib.error
B=sys.argv[1]; ok=bad=0
def sec(n): return "whsec_"+base64.b64encode(n.encode()*4).decode()
S1,S2,S3=sec("one-secret-"),sec("two-secret-"),sec("evil-secret")
def start(port,env_extra):
    d=tempfile.mkdtemp(); k=os.path.join(d,"pcp.key"); open(k,"w").write("k"*48)
    env={"PATH":os.environ["PATH"],"PORT":str(port),"DATABASE_URL":"postgres://x:x@127.0.0.1:1/x","WAL_DIR":d+"/wal","POLAR_ACCESS_TOKEN":"","PCP_KEY_FILE":k,"PCP_KEY":"","PCP_PAUSE_DIR":d,"HOME":d}; env.update(env_extra)
    p=subprocess.Popen([B],env=env,cwd=d,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    for _ in range(100):
        try: socket.create_connection(("127.0.0.1",port),timeout=1).close(); break
        except OSError: time.sleep(.1)
    return p
def hook(port,secret):
    body=b'{"type":"test.event","data":{}}'; ts=str(int(time.time())); wid="evt_"+ts
    key=base64.b64decode(secret[6:]); sig=base64.b64encode(hmac.new(key,f"{wid}.{ts}.{body.decode()}".encode(),hashlib.sha256).digest()).decode()
    r=urllib.request.Request(f"http://127.0.0.1:{port}/api/v1/polar-webhook",data=body,method="POST",headers={"content-type":"application/json","webhook-id":wid,"webhook-timestamp":ts,"webhook-signature":"v1,"+sig})
    try: return urllib.request.urlopen(r,timeout=10).status
    except urllib.error.HTTPError as e: return e.code
def health(port): return json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/health",timeout=40))
def chk(n,c):
    global ok,bad
    print(("  PASS  " if c else "  FAIL  ")+n); ok+=c; bad+=(not c)
p=start(5611,{"POLAR_WEBHOOK_SECRETS":f"{S1}, {S2}"})
h=health(5611)
chk("2 secrets (comma+space) load => count 2",h.get("webhook_secrets")==2)
chk("secrets_complete true",h.get("secrets_complete") is True)
chk("endpoint-1 secret ki delivery 200",hook(5611,S1)==200)
chk("endpoint-2 secret ki delivery 200",hook(5611,S2)==200)
chk("anjaan secret 401",hook(5611,S3)==401)
p.kill()
p=start(5612,{"POLAR_WEBHOOK_SECRET":S1})
h=health(5612)
chk("sirf 1 secret => secrets_complete false (alarm)",h.get("secrets_complete") is False and h.get("webhook_secrets")==1)
chk("purana POLAR_WEBHOOK_SECRET abhi bhi chalta hai",hook(5612,S1)==200)
chk("doosre endpoint ki delivery 401 (yehi bug tha)",hook(5612,S2)==401)
p.kill()
p=start(5613,{"POLAR_WEBHOOK_SECRET":S1,"POLAR_WEBHOOK_SECRETS":f'"{S1}"\n{S2}'})
chk("dedupe + quotes/newline theek",health(5613).get("webhook_secrets")==2)
p.kill()
print(f"\n{ok} pass, {bad} fail"); sys.exit(1 if bad else 0)
