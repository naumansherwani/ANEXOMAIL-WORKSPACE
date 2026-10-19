#!/usr/bin/env python3
# ANEXOMAIL — axum 0.7 -> 0.8 ka source patch (anchor-based, idempotent). Usage: axum8_patch.py <Cargo.toml> <src/main.rs>
# Sirf 3 cheezein: (1) Cargo.toml axum "0.7" -> "0.8"; (2) route "/rpc/:proc" -> "/rpc/{proc}" (0.8 mein ':' wala path startup par panic);
# (3) dispatch ka body: `Option<Json<Value>>` -> raw bytes + `rpc_json_body` (0.8 mein Option<Json> galat Content-Type/kharab body par
#     request reject karta hai; 0.7 chupke se `{}` banata tha — wohi bartao jaisa ka taisa rakha). Anchor na mile => exit 4, kuch nahi likha.
import re, sys
cargo, main = sys.argv[1], sys.argv[2]
c = open(cargo).read(); m = open(main).read(); c0, m0 = c, m
def fail(msg): print("PATCH FAIL: " + msg); sys.exit(4)

# 1) Cargo.toml
ax = re.findall(r'^axum[ \t]*=.*$', c, re.M)
if len(ax) != 1: fail("Cargo.toml mein axum ki ek line nahi mili (%d)" % len(ax))
line = ax[0]
if re.search(r'"0\.8(\.\d+)?"', line): print("   Cargo.toml: axum pehle se 0.8")
else:
    new = re.sub(r'"0\.7(\.\d+)?"', '"0.8"', line, count=1)
    if new == line: fail("axum line ajeeb: " + line)
    c = c.replace(line, new, 1); print("   Cargo.toml: " + line + "  ->  " + new)

# 2) route syntax
OLD_R = '.route("/rpc/:proc", post(dispatch).get(dispatch))'
NEW_R = '.route("/rpc/{proc}", post(dispatch).get(dispatch))'
if m.count(NEW_R) == 1: print("   main.rs: route pehle se /rpc/{proc}")
elif m.count(OLD_R) == 1: m = m.replace(OLD_R, NEW_R); print("   main.rs: route /rpc/:proc -> /rpc/{proc}")
else: fail("`%s` ek dafa nahi mila" % OLD_R)
left = re.findall(r'\.(?:route|nest|route_service|nest_service)\(\s*"[^"]*/[:*][A-Za-z_]', m)
if left: fail("aur purane-syntax paths bache: %s" % left[:5])

# 3) dispatch body
OLD_B = ('    body: Option<Json<Value>>,\n) -> axum::response::Response {\n'
         '    let raw = body.map(|Json(v)| v).unwrap_or(json!({}));')
NEW_B = ('    body: Result<axum::body::Bytes, axum::extract::rejection::BytesRejection>,\n) -> axum::response::Response {\n'
         '    let raw = rpc_json_body(&headers, body.ok()).unwrap_or(json!({}));')
HELPER = '''/// axum 0.7 ke `Option<Json<Value>>` ka bartao jaisa ka taisa (axum 0.8 mein `Option<Json>` galat Content-Type / kharab body par
/// request ko reject karne laga, pehle sab kuch chupke se `None` ban jata tha): body tab hi parse hoti hai jab Content-Type JSON ho
/// (`application/json` ya `application/*+json`); koi bhi gadbad (type, syntax, size) => None => input `{}`.
fn rpc_json_body(headers: &HeaderMap, body: Option<axum::body::Bytes>) -> Option<Value> {
    let bytes = body?;
    let ct = headers.get(axum::http::header::CONTENT_TYPE)?.to_str().ok()?;
    let mime = ct.split(';').next()?.trim().to_ascii_lowercase();
    let is_json = mime == "application/json" || (mime.starts_with("application/") && mime.ends_with("+json"));
    if !is_json {
        return None;
    }
    serde_json::from_slice::<Value>(&bytes).ok()
}

'''
if "fn rpc_json_body(" in m and NEW_B in m: print("   main.rs: dispatch body pehle se 0.8 wala")
else:
    if m.count(OLD_B) != 1: fail("dispatch ka `body: Option<Json<Value>>` + `let raw = ...` (exact) ek dafa nahi mila")
    if "fn rpc_json_body(" in m: fail("rpc_json_body pehle se hai par dispatch purana — adhoora, haath se dekhna")
    A = re.search(r'^async fn dispatch\(\n    Path\(proc\): Path<String>,\n    headers: HeaderMap,\n', m, re.M)
    if not A: fail("`async fn dispatch(Path(proc), headers: HeaderMap, ...` anchor nahi mila")
    m = m[:A.start()] + HELPER + m[A.start():]
    m = m.replace(OLD_B, NEW_B); print("   main.rs: dispatch body -> rpc_json_body (0.7 jaisa bartao)")
code = "\n".join(l for l in m.splitlines() if not l.lstrip().startswith("//"))
others = re.findall(r'Option<(?:Json|Query|Path|Extension|TypedHeader|Form)<', code)
if others: fail("main.rs mein aur Option<extractor> bhi hain (%d) — 0.8 mein bartao badalta hai, haath se dekhna" % len(others))
if c != c0: open(cargo, "w").write(c)
if m != m0: open(main, "w").write(m)
print("   patch: " + ("lag gaya" if (c != c0 or m != m0) else "pehle se laga hua"))
