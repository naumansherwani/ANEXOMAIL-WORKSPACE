import json, subprocess, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
TOK = {"tokA": ("00000000-0000-0000-0000-0000000000a1","a@x"), "tokB": ("00000000-0000-0000-0000-0000000000b2","b@x"),
       "tokC": ("00000000-0000-0000-0000-0000000000c3","c@x")}
def lit(v):
    if v is None: return "null"
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int, float)): return str(v)
    if isinstance(v, dict): return "'" + json.dumps(v).replace("'", "''") + "'::jsonb"
    if isinstance(v, list): return "'{" + ",".join(str(x) for x in v) + "}'::uuid[]"
    return "'" + str(v).replace("'", "''") + "'"
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, code, obj):
        b = json.dumps(obj).encode(); self.send_response(code); self.send_header("content-type","application/json"); self.send_header("content-length",str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path.startswith("/auth/v1/user"):
            a = self.headers.get("authorization","").replace("Bearer ","")
            if a in TOK: return self.send(200, {"id": TOK[a][0], "email": TOK[a][1]})
            return self.send(401, {"msg":"bad"})
        self.send(404, {})
    def do_POST(self):
        n = int(self.headers.get("content-length","0")); body = json.loads(self.rfile.read(n) or b"{}")
        if self.path.startswith("/rest/v1/rpc/"):
            fn = self.path.split("/rpc/")[1]
            args = ", ".join(f"{k} => {lit(v)}" for k, v in body.items())
            sql = f"select public.{fn}({args})"
            r = subprocess.run(["psql","-h","/var/run/postgresql","-U","postgres","-d","e48","-At","-c",sql], capture_output=True, text=True)
            if r.returncode != 0: sys.stderr.write(r.stderr); return self.send(400, {"message": r.stderr[:300]})
            out = r.stdout.strip().split("\n")[0]
            return self.send(200, json.loads(out) if out else None)
        self.send(404, {})
ThreadingHTTPServer(("127.0.0.1", 4010), H).serve_forever()
