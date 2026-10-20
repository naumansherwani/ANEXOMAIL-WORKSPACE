#!/usr/bin/env python3
# ANEXOMAIL — Rust edition 2021 -> 2024 (anchor-based, idempotent). Usage: edition24_patch.py <Cargo.toml> <src/main.rs>
# Sandbox (`cargo fix --edition`, poora live-jaisa code): sirf 1 jagah badli — `fn err(..) -> impl IntoResponse` par `+ use<>`
# (2024 mein `impl Trait` saare lifetimes pakad leta hai; `use<>` = pehle jaisa, kuch nahi pakadta; 2021 mein bhi valid).
# Baqi 2024 lint sirf ek drop-order note (mig_glue dial(), error raaste par socket kab band ho) — asar nahi. Anchor na mile => exit 4, kuch nahi likha.
import re, sys
cargo, main = sys.argv[1], sys.argv[2]
c = open(cargo).read(); m = open(main).read(); c0, m0 = c, m
def fail(msg): print("PATCH FAIL: " + msg); sys.exit(4)
ed = re.findall(r'^edition[ \t]*=[ \t]*"(\d{4})"', c, re.M)
if len(ed) != 1: fail("Cargo.toml mein edition ki ek line nahi (%d)" % len(ed))
if ed[0] == "2024": print("   Cargo.toml: edition pehle se 2024")
elif ed[0] == "2021":
    c = re.sub(r'^(edition[ \t]*=[ \t]*)"2021"', r'\1"2024"', c, count=1, flags=re.M); print('   Cargo.toml: edition "2021" -> "2024"')
else: fail("edition ajeeb: " + ed[0])
OLD = "fn err(status: StatusCode, code: &str, message: &str) -> impl IntoResponse {"
NEW = "fn err(status: StatusCode, code: &str, message: &str) -> impl IntoResponse + use<> {"
if m.count(NEW) == 1: print("   main.rs: err() pehle se `+ use<>`")
elif m.count(OLD) == 1: m = m.replace(OLD, NEW); print("   main.rs: err() -> impl IntoResponse + use<>")
else: fail("`fn err(status: StatusCode, code: &str, message: &str) -> impl IntoResponse {` ek dafa nahi mila")
if c != c0: open(cargo, "w").write(c)
if m != m0: open(main, "w").write(m)
print("   patch: " + ("lag gaya" if (c != c0 or m != m0) else "pehle se laga hua"))
