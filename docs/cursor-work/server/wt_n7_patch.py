#!/usr/bin/env python3
# ANEXOMAIL — NOTE N7 fix: WebTransport error frame (bad_hello / token_required / unauthorized / token_and_conversation_required)
# bhejne ke baad server turant `return` karta tha -> connection drop -> frame aksar raaste mein kho jata (Chromium: "Connection lost", koi wajah nahi).
# Ab: frame likho -> `send.finish()` (peer ke ack tak, zyada se zyada 2s) -> phir band. Usage: wt_n7_patch.py <src/main.rs>. Anchor-based, idempotent;
# koi anchor na mile => exit 4, kuch nahi likha. Sirf wt_session ke 5 "error + return" raaste; mail/chat ki chalti loops ko haath nahi.
import re, sys
p = sys.argv[1]; m = open(p).read(); m0 = m
def fail(msg): print("PATCH FAIL: " + msg); sys.exit(4)
if "async fn wt_send_final(" in m:
    print("   main.rs: N7 pehle se laga hua"); sys.exit(0)
if p.endswith("src/main.rs"):
    cargo = open(p[: -len("src/main.rs")] + "Cargo.toml").read()
    if not re.search(r'^wtransport[ \t]*=[ \t]*"0\.7', cargo, re.M): fail("Cargo.toml mein wtransport 0.7 nahi (pehle wtransport-upgrade.sh)")
a = m.find("async fn wt_session(incoming: wtransport::endpoint::IncomingSession) {")
b = m.find("\nasync fn start_webtransport() {", a)
if a < 0 or b < 0: fail("wt_session / start_webtransport anchor nahi mila")
body = m[a:b]
subs = [
 ('            let _ = send\n                .write_all(b"{\\"type\\":\\"error\\",\\"code\\":\\"bad_hello\\"}\\n")\n                .await;\n            return;',
  '            wt_send_final(&mut send, b"{\\"type\\":\\"error\\",\\"code\\":\\"bad_hello\\"}\\n").await;\n            return;'),
 ('        let _ = send\n            .write_all(b"{\\"type\\":\\"error\\",\\"code\\":\\"token_required\\"}\\n")\n            .await;\n        return;',
  '        wt_send_final(&mut send, b"{\\"type\\":\\"error\\",\\"code\\":\\"token_required\\"}\\n").await;\n        return;'),
 ('        let _ = send\n            .write_all(b"{\\"type\\":\\"error\\",\\"code\\":\\"token_and_conversation_required\\"}\\n")\n            .await;\n        return;',
  '        wt_send_final(&mut send, b"{\\"type\\":\\"error\\",\\"code\\":\\"token_and_conversation_required\\"}\\n").await;\n        return;'),
]
for old, new in subs:
    if body.count(old) != 1: fail("anchor ek dafa nahi mila: " + old.strip().splitlines()[1].strip()[:70])
    body = body.replace(old, new)
OLDF = '                let _ = send.write_all(frame.as_bytes()).await;\n                return;'   # mail identity error (16 spaces)
OLDC = '            let _ = send.write_all(frame.as_bytes()).await;\n            return;'           # chat identity error (12 spaces)
if body.count(OLDF) != 1: fail("mail identity error anchor (1) nahi mila")
body = body.replace(OLDF, '                wt_send_final(&mut send, frame.as_bytes()).await;\n                return;')
if body.count(OLDC) != 1: fail("chat identity error anchor (1) nahi mila")
body = body.replace(OLDC, '            wt_send_final(&mut send, frame.as_bytes()).await;\n            return;')
helper = '''/// NOTE N7 (20 Oct 2026): aakhri (error) frame bhej kar stream ko gracefully band karo aur peer ke ack ka intezar karo
/// (`finish()` ack tak rukta hai; zyada se zyada 2s taake atka hua client server ko na roke). Pehle frame likh kar turant
/// `return` hota tha -> Connection drop -> frame aksar raaste mein kho jata, browser ko sirf "Connection lost" milta tha.
async fn wt_send_final(send: &mut wtransport::SendStream, frame: &[u8]) {
    if send.write_all(frame).await.is_ok() {
        let _ = tokio::time::timeout(Duration::from_secs(2), send.finish()).await;
    }
}

'''
m = m[:a] + helper + body + m[b:]
open(p, "w").write(m)
print("   main.rs: N7 laga — 5 error raaste ab frame pahuncha kar band hote hain")
