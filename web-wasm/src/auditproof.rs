//! auditproof@1 - QUI-H4 (Q series). The browser kernel proves that ONE mail's ledger row is inside the founder audit Merkle tree, without trusting the server.
//! Chain of proof (all re-computed here): (1) the mail ledger row re-hashes with the fmail-ledger-v1 formula (mailledger::row_hash); (2) its anchor row in
//! founder_audit re-hashes with the E102 `_fa_hash` formula (SHA-256 over 4-byte big-endian BYTE-length prefixed fields, PostgreSQL int4send); (3) the anchor row's
//! meta binds THIS ledger row (fmail_seq, fmail_hash) and its action/target match; (4) the RFC 6962 inclusion path (merkle_core, same code as merkle@1) leads from
//! that audit row hash to the root the server names. Honest limit: this proves "inside the tree with this root"; that the root is signed by the audit key is the
//! existing checkpoint verify, so the report says root_signed=false until that is wired into the chip.
//! Technology: Rust -> WASM kernel (Rule 52), `sha2` + `serde_json` already in the kernel, no new crate. Pure function. Input = SQL door `fmail_anchor_proof173` (E173).
use crate::{mailledger, merkle};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

fn hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
/// E102 `_fa_lp`: 4-byte big-endian length in BYTES + the UTF-8 bytes.
fn lp4(out: &mut Vec<u8>, s: &str) { out.extend_from_slice(&(s.len() as u32).to_be_bytes()); out.extend_from_slice(s.as_bytes()); }
/// E102 `_fa_hash(prev, seq, actor, action, target, reason, ts, meta)`.
pub fn audit_hash(prev: &str, seq: &str, actor: &str, action: &str, target: &str, reason: &str, ts: &str, meta: &str) -> String {
    let mut b = Vec::new();
    for f in [prev, seq, actor, action, target, reason, ts, meta] { lp4(&mut b, f); }
    hex(&Sha256::digest(&b))
}
fn s<'a>(v: &'a Value, k: &str) -> Option<&'a str> { v.get(k).and_then(Value::as_str) }
fn bad(p: &str) -> (bool, String) { (false, json!({"ok": false, "problem": p}).to_string()) }

pub fn check(input: &str) -> (bool, String) {
    let Ok(j) = serde_json::from_str::<Value>(input) else { return bad("the answer is not JSON") };
    if s(&j, "v") != Some("fmail-anchor-v1") { return bad("the answer is not fmail-anchor-v1"); }
    if j.get("found").and_then(Value::as_bool) != Some(true) { return bad("the message was not found"); }
    if j.get("anchored").and_then(Value::as_bool) != Some(true) { return bad("no checkpoint covers this message yet"); }
    let (Some(msg), Some(chain), Some(a), Some(mk)) = (s(&j, "message"), j.get("chain"), j.get("audit"), j.get("merkle")) else { return bad("message, chain, audit or merkle part is missing") };
    // (1) the ledger slice from the mail's own row up to the checkpoint row re-hashes and links (mailledger@1 rules, first row's prev is taken as given)
    let Some(rows) = chain.get("rows").and_then(Value::as_array) else { return bad("no ledger rows") };
    if rows.len() < 2 || rows.len() > 1000 { return bad("the ledger slice has a wrong size"); }
    let first = &rows[0]; let last = &rows[rows.len() - 1];
    let (Some(fprev), Some(fseq)) = (s(first, "prev"), s(first, "seq").and_then(|x| x.parse::<u64>().ok())) else { return bad("the first ledger row is malformed") };
    let mut c = chain.clone();
    c["after_seq"] = json!(fseq.saturating_sub(1)); c["after_hash"] = json!(if fseq == 1 { "0".repeat(64) } else { fprev.to_string() });
    let (ok, rep) = mailledger::check(&c.to_string());
    if !ok { return (false, rep); }
    // (2) first row = THIS mail's inbound_ok row, last row = a checkpoint
    if s(first, "action") != Some("inbound_ok") || s(first, "target") != Some(msg) { return bad("the first ledger row is not this message's inbound_ok row"); }
    if s(last, "action") != Some("ledger_checkpoint") { return bad("the last ledger row is not a checkpoint"); }
    let (Some(lseq), Some(lhash)) = (s(last, "seq"), s(last, "hash")) else { return bad("the checkpoint row is malformed") };
    // (3) the checkpoint's audit anchor row re-hashes (E102 formula) and names exactly this checkpoint row
    let g = |k: &str| s(a, k);
    let (Some(aprev), Some(aseq), Some(ats), Some(aactor), Some(aaction), Some(atarget), Some(areason), Some(ameta), Some(ahash)) =
        (g("prev"), g("seq"), g("ts"), g("actor"), g("action"), g("target"), g("reason"), g("meta"), g("hash")) else { return bad("an audit field is missing") };
    if audit_hash(aprev, aseq, aactor, aaction, atarget, areason, ats, ameta) != ahash { return bad("the audit anchor row does not re-hash to its hash"); }
    let Ok(meta_v) = serde_json::from_str::<Value>(ameta) else { return bad("the audit meta is not JSON") };
    let bound_seq = meta_v.get("fmail_seq").and_then(|x| x.as_u64().map(|n| n.to_string()).or_else(|| x.as_str().map(str::to_string)));
    if bound_seq.as_deref() != Some(lseq) || s(&meta_v, "fmail_hash") != Some(lhash) { return bad("the audit anchor does not name this checkpoint row"); }
    if aaction != "fmail_ledger_checkpoint" || Some(atarget) != s(last, "target") { return bad("the audit anchor action or target does not match the checkpoint"); }
    // (4) the RFC 6962 inclusion path from the audit row to the root
    let (Some(root), Some(leaf)) = (s(mk, "root"), s(mk, "leaf")) else { return bad("root or leaf is missing") };
    let Some(ah) = merkle::from_hex(ahash) else { return bad("the audit hash is not 32 bytes of hex") };
    if merkle::to_hex(&merkle::leaf(&ah)) != leaf { return bad("the leaf is not the leaf hash of the audit row"); }
    let Some(path) = mk.get("path").and_then(Value::as_array) else { return bad("the path is missing") };
    let mut txt = Vec::new();
    for p in path {
        let (Some(sd), Some(h)) = (s(p, "s"), s(p, "h")) else { return bad("a path step is malformed") };
        txt.push(format!("{sd}:{h}"));
    }
    if !merkle::verify_text(ahash, &txt.join(","), root) { return bad("the inclusion path does not lead to the root"); }
    (true, json!({"ok": true, "mail_seq": fseq, "checkpoint_seq": lseq, "audit_seq": aseq, "ledger_rows": rows.len(), "root": root, "upto": mk.get("upto"), "hops": txt.len(), "root_signed": false}).to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::merkle as m;
    const REAL: &str = include_str!("../../server/rust/q_anchor_vector.json");
    fn run(v: &Value) -> (bool, Value) { let (ok, r) = check(&v.to_string()); (ok, serde_json::from_str(&r).unwrap()) }
    fn real() -> Value { serde_json::from_str(REAL).unwrap() }
    #[test] fn the_real_postgres_door_answer_verifies() {
        let (ok, r) = run(&real()); assert!(ok, "{r}"); assert_eq!(r["root_signed"], false); assert_eq!(r["ledger_rows"], 3);
    }
    #[test] fn every_tamper_of_the_real_answer_is_caught() {
        let muts: Vec<(&str, Box<dyn Fn(&mut Value)>)> = vec![
            ("mail row reason", Box::new(|v| v["chain"]["rows"][0]["reason"] = json!("changed reason here"))),
            ("middle row meta", Box::new(|v| v["chain"]["rows"][1]["meta"] = json!("{}"))),
            ("checkpoint hash", Box::new(|v| { let n = v["chain"]["rows"].as_array().unwrap().len(); v["chain"]["rows"][n - 1]["hash"] = json!("0".repeat(64)); })),
            ("drop a middle row", Box::new(|v| { v["chain"]["rows"].as_array_mut().unwrap().remove(1); })),
            ("another message id", Box::new(|v| v["message"] = json!("cccccccc-0000-0000-0000-000000000001"))),
            ("audit reason", Box::new(|v| v["audit"]["reason"] = json!("changed reason here"))),
            ("audit meta", Box::new(|v| v["audit"]["meta"] = json!(r#"{"fmail_seq": 1}"#))),
            ("audit action", Box::new(|v| v["audit"]["action"] = json!("fmail_send_ok"))),
            ("root", Box::new(|v| v["merkle"]["root"] = json!("0".repeat(64)))),
            ("leaf", Box::new(|v| v["merkle"]["leaf"] = json!("0".repeat(64)))),
            ("path flip", Box::new(|v| { let sd = v["merkle"]["path"][0]["s"].as_str().unwrap().to_string(); v["merkle"]["path"][0]["s"] = json!(if sd == "L" { "R" } else { "L" }); })),
            ("path hop", Box::new(|v| v["merkle"]["path"][0]["h"] = json!("1".repeat(64)))),
            ("not anchored", Box::new(|v| v["anchored"] = json!(false))),
            ("wrong version", Box::new(|v| v["v"] = json!("x"))),
        ];
        for (name, f) in muts { let mut v = real(); f(&mut v); let (ok, r) = run(&v); assert!(!ok, "{name} must fail: {r}"); }
    }
    #[test] fn garbage_never_panics() { for g in ["", "{}", "[]", "null", "{\"v\":\"fmail-anchor-v1\"}"] { assert!(!check(g).0); } }
    #[test] fn the_audit_formula_uses_byte_lengths() {
        let a = audit_hash("p", "1", "a", "x", "t", "é", "9", "{}");
        let mut b = Vec::new(); for f in ["p", "1", "a", "x", "t", "é", "9", "{}"] { b.extend_from_slice(&(f.len() as u32).to_be_bytes()); b.extend_from_slice(f.as_bytes()); }
        assert_eq!(a, hex(&Sha256::digest(&b)));
    }
    #[test] fn a_merkle_path_for_many_shapes_still_verifies_with_the_same_leaf_rule() {
        for n in 1..=33usize { let hs: Vec<m::H32> = (0..n).map(|i| m::from_hex(&hex(&Sha256::digest(format!("r{i}")))).unwrap()).collect();
            let lf: Vec<m::H32> = hs.iter().map(m::leaf).collect(); let lv = m::levels(&lf); let root = m::to_hex(&m::root_of(&lf).unwrap());
            for i in [0, n / 2, n - 1] { let p = m::path(&lv, i).unwrap(); let t: Vec<String> = p.iter().map(|(sd, h)| format!("{}:{}", if matches!(sd, m::Side::L) { "L" } else { "R" }, m::to_hex(h))).collect();
                assert!(m::verify_text(&m::to_hex(&hs[i]), &t.join(","), &root)); } }
    }
}
