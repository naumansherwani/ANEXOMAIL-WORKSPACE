import re,os,collections
import sys
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HELD={'/api/ai/billing/','/api/knowledge/'}  # AI plans COMING SOON (July 2027): jaan-boojh ke HELD
prefixes=["","/chat","/chat/file","/leo","/auth","/workspace","/dashboard","/integrations","/founder","/settings","/admin","/security","/perf","/public","/ai/credits","/mail/predict","/mail","/trial","/account-deletion","/billing","/movein","/storage","/internal"]
routes=set()
rt=re.compile(r'\b[A-Za-z_]\w*\.(get|post|put|patch|delete|all)\(\s*["\'`](/[^"\'`]*)["\'`]')
for d,_,fs in list(os.walk(root+'/server'))+list(os.walk(root+'/anexochat'))+list(os.walk(root+'/portal')):
    if '/rust' in d or 'node_modules' in d: continue
    for f in fs:
        if f.endswith('.ts') and '.test.' not in f:
            s=open(os.path.join(d,f),errors='ignore').read()
            for m in rt.finditer(s): routes.add(m.group(2))
# rust routes
rust_routes=set()
for f in os.listdir(root+'/server/rust'):
    if f.endswith('.rs'):
        s=open(root+'/server/rust/'+f,errors='ignore').read()
        for m in re.finditer(r'\.route\(\s*"([^"]+)"',s): rust_routes.add(m.group(1))
def rx(r): return re.compile('^'+re.sub(r':[A-Za-z_]+|\*[A-Za-z_]*','[^/]+',re.escape(r).replace('\\:',':'))+'/?$')
allr=[]
for r in routes:
    for p in prefixes: allr.append(('/api'+p+r))
allr+= list(rust_routes)
allrx=[(a,re.compile('^'+re.sub(r':[A-Za-z_]+','[^/]+',a.replace('*','.*'))+'/?$')) for a in set(allr)]
calls=collections.defaultdict(set)
cp=re.compile(r'["\'`](/api/[A-Za-z0-9_\-/\.${}:]+)(?:\?[^"\'`]*)?["\'`]')
for d,_,fs in os.walk(root+'/src'):
    for f in fs:
        if f.endswith(('.ts','.tsx')) and '.gen.' not in f and '.test.' not in f:
            p=os.path.join(d,f); s=open(p,errors='ignore').read()
            for m in cp.finditer(s):
                u=re.sub(r'\$\{[^}]*\}','X',m.group(1)).split('?')[0]
                calls[u].add(p.replace(root+'/src/',''))
miss=[]
def seg_match(call, route):
    a=call.rstrip('/').split('/'); b=route.rstrip('/').split('/')
    if len(a)!=len(b): return False
    return all(x==y or x=='X' or y.startswith(':') or y.startswith('*') for x,y in zip(a,b))
for u,fl in sorted(calls.items()):
    if not any(rx_.match(u) for _,rx_ in allrx) and not any(seg_match(u,a) for a,_ in allrx): miss.append((u,sorted(fl)[0]))
# Rust primary: rpcOrRest("proc", {path}) — agar proc Rust ya Bun mein hai to REST path ka na hona wire-gap nahi (fallback hai).
procs=set()
for d,_,fs in os.walk(root+'/server'):
    if 'node_modules' in d: continue
    for f in fs:
        if f.endswith(('.rs','.ts')) and '.test.' not in f:
            t=open(os.path.join(d,f),errors='ignore').read()
            procs.update(re.findall(r'"([a-zA-Z]+(?:\.[a-zA-Z]+)+)"',t))
uses=collections.defaultdict(set)
for d,_,fs in os.walk(root+'/src'):
    for f in fs:
        if f.endswith(('.ts','.tsx')) and '.test.' not in f:
            p=os.path.join(d,f); t=open(p,errors='ignore').read()
            for m in re.finditer(r'["\x60]([a-zA-Z]+(?:\.[a-zA-Z]+)+\.?)(?:\$\{[^}]*\})?["\x60][\s\S]{0,160}?path:\s*[`"\'](/api/[^`"\'?]*)',t):
                uses[re.sub(r'\$\{[^}]*\}','X',m.group(2))].add(m.group(1))
real=[];held=[];covered=[]
for u,f in miss:
    pr=uses.get(u,set())
    if any(u.startswith(h) for h in HELD): held.append((u,f))
    elif pr and all(p in procs or any(q.startswith(p+'.') or q.startswith(p) for q in procs) for p in pr): covered.append((u,sorted(pr)[0]))
    else: real.append((u,f))
print(len(calls),"api paths in frontend;",len(covered),"REST fallback only (Rust/Bun proc maujood);",len(held),"HELD (AI, COMING SOON);",len(real),"REAL GAP")
for u,f in real: print("GAP",u,'<-',f)
sys.exit(1 if real else 0)
