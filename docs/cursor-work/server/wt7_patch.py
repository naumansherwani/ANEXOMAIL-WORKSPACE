#!/usr/bin/env python3
# ANEXOMAIL — wtransport 0.1 -> 0.7 ka source patch (anchor-based, idempotent). Usage: wt7_patch.py <Cargo.toml> <src/main.rs>
# Sirf 2 cheezein: (1) Cargo.toml wtransport "0.1" -> "0.7"; (2) `.with_identity(&identity)` -> `.with_identity(identity)` (0.7 Identity by value leta hai).
# Saath mein jaanch: main.rs mein wtransport ke sirf wohi 4 istemal hon jo sandbox mein test hue — kuch aur mila to ruk jao (exit 4, kuch nahi likha).
import re, sys
cargo, main = sys.argv[1], sys.argv[2]
c = open(cargo).read(); m = open(main).read(); c0, m0 = c, m
def fail(msg): print("PATCH FAIL: " + msg); sys.exit(4)
wt = re.findall(r'^wtransport[ \t]*=.*$', c, re.M)
if len(wt) != 1: fail("Cargo.toml mein wtransport ki ek line nahi (%d)" % len(wt))
line = wt[0]
if re.search(r'"0\.7(\.\d+)?"', line): print("   Cargo.toml: wtransport pehle se 0.7")
else:
    new = re.sub(r'"0\.1(\.\d+)?"', '"0.7"', line, count=1)
    if new == line: fail("wtransport line ajeeb: " + line)
    c = c.replace(line, new, 1); print("   Cargo.toml: " + line + "  ->  " + new)
OLD = "        .with_identity(&identity)\n"; NEW = "        .with_identity(identity)\n"
if m.count(NEW) == 1 and OLD not in m: print("   main.rs: with_identity pehle se 0.7 wala")
elif m.count(OLD) == 1: m = m.replace(OLD, NEW); print("   main.rs: .with_identity(&identity) -> .with_identity(identity)")
else: fail("`.with_identity(&identity)` ek dafa nahi mila")
uses = sorted(set(re.findall(r'wtransport::[A-Za-z_:]+', m)))
known = {"wtransport::endpoint::IncomingSession", "wtransport::Identity::load_pemfiles", "wtransport::ServerConfig::builder", "wtransport::Endpoint::server"}
extra = [u for u in uses if u not in known]
if extra: fail("main.rs mein wtransport ke aur istemal bhi hain (sandbox mein test nahi hue): %s" % extra)
for f in ("with_bind_default(port)", "endpoint.accept().await", "request.accept().await", "connection.accept_bi().await"):
    if f not in m: fail("`%s` nahi mila — live code repo se alag hai, haath se dekhna" % f)
if c != c0: open(cargo, "w").write(c)
if m != m0: open(main, "w").write(m)
print("   patch: " + ("lag gaya" if (c != c0 or m != m0) else "pehle se laga hua"))
