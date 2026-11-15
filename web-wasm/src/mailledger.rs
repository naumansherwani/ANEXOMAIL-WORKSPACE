//! mailledger@1 — QUI-H3 (Q series). The browser recomputes the founder MAIL LEDGER hash chain ITSELF.
//! Why: a verifier must not be the party being verified (RFC 6962 principle; Proton Key Transparency and Apple CKV verify on the client). Until now the SERVER said "the chain is fine".
//! Technology: Rust -> WASM kernel (Rule 52), SHA-256 from the same `sha2` crate as every other kernel module, no new crate. Pure function, no clock, no network.
//! Formula = SQL `fmail_ledger_hash_167` rule for rule: SHA-256 over lp('fmail-ledger-v1') lp(prev) lp(seq) lp(ts) lp(actor) lp(action) lp(target) lp(reason) lp(meta),
//! lp(s) = "<number of Unicode characters>:" + s (PostgreSQL length() counts characters, so this counts `chars()`, not bytes), bytes = UTF-8. `meta` is the jsonb::text exactly as the
//! SQL door (`fmail_ledger_rows172`, E172) sent it, so no JSON re-serialisation can change a byte. Vectors: server/rust/q_ledger_vectors.json, made by the production SQL itself.
//! Input JSON: the door answer {v, zero, rows:[{seq,ts,actor,action,target,reason,meta,prev,hash}], more} plus `after_seq` + `after_hash` (the row before this page; 0 + 64 zeros for page one)
//! and optionally `claim_head_seq` + `claim_head_hash` (what the server says the head is). Report JSON: {ok, checked, first_seq, last_seq, head_hash, more} or {ok:false, problem, bad_seq?}.
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

const V: &str = "fmail-ledger-v1";
const ZERO: &str = "0000000000000000000000000000000000000000000000000000000000000000";
fn hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
fn lp(out: &mut Vec<u8>, s: &str) { out.extend_from_slice(format!("{}:", s.chars().count()).as_bytes()); out.extend_from_slice(s.as_bytes()); }
fn is_hash(s: &str) -> bool { s.len() == 64 && s.bytes().all(|c| c.is_ascii_digit() || (b'a'..=b'f').contains(&c)) }

/// The one hash formula. Fields are the exact texts of the row.
pub fn row_hash(prev: &str, seq: &str, ts: &str, actor: &str, action: &str, target: &str, reason: &str, meta: &str) -> String {
    let mut b = Vec::new();
    for f in [V, prev, seq, ts, actor, action, target, reason, meta] { lp(&mut b, f); }
    hex(&Sha256::digest(&b))
}

fn bad(problem: &str, seq: Option<u64>) -> (bool, String) {
    let mut r = json!({"ok": false, "problem": problem});
    if let Some(s) = seq { r["bad_seq"] = json!(s); }
    (false, r.to_string())
}

pub fn check(input: &str) -> (bool, String) {
    let Ok(j) = serde_json::from_str::<Value>(input) else { return bad("the answer is not JSON", None) };
    if j.get("v").and_then(Value::as_str) != Some(V) { return bad("the ledger answer is not fmail-ledger-v1", None); }
    if j.get("zero").and_then(Value::as_str) != Some(ZERO) { return bad("the genesis value is not 64 zeros", None); }
    let Some(rows) = j.get("rows").and_then(Value::as_array) else { return bad("no rows list", None) };
    let after_seq = j.get("after_seq").and_then(Value::as_u64).unwrap_or(0);
    let after_hash = j.get("after_hash").and_then(Value::as_str).unwrap_or(ZERO);
    if !is_hash(after_hash) || (after_seq == 0 && after_hash != ZERO) { return bad("the starting hash is not valid for this page", None); }
    let mut want_seq = after_seq + 1;
    let mut prev = after_hash.to_string();
    let claim_seq = j.get("claim_head_seq").and_then(Value::as_u64);
    let claim_hash = j.get("claim_head_hash").and_then(Value::as_str);
    let mut claim_ok = claim_seq.map_or(true, |c| c <= after_seq);
    for r in rows {
        let f = |k: &str| r.get(k).and_then(Value::as_str);
        let (Some(seq), Some(ts), Some(actor), Some(action), Some(target), Some(reason), Some(meta), Some(rp), Some(rh)) =
            (f("seq"), f("ts"), f("actor"), f("action"), f("target"), f("reason"), f("meta"), f("prev"), f("hash")) else { return bad("a row misses a field", Some(want_seq)) };
        let Ok(n) = seq.parse::<u64>() else { return bad("a row has a bad sequence number", Some(want_seq)) };
        if seq != n.to_string() { return bad("a sequence number is not plain digits", Some(n)); }
        if n != want_seq { return bad("a row is missing, repeated or out of order", Some(want_seq)); }
        if !is_hash(rp) || !is_hash(rh) { return bad("a hash is not 64 lowercase hex characters", Some(n)); }
        if rp != prev { return bad("the row does not point at the hash of the row before it", Some(n)); }
        if row_hash(rp, seq, ts, actor, action, target, reason, meta) != rh { return bad("the row's content does not match its hash", Some(n)); }
        if Some(n) == claim_seq { if Some(rh) != claim_hash { return bad("the server's claimed head hash is not the row's hash", Some(n)); } claim_ok = true; }
        prev = rh.to_string(); want_seq = n + 1;
    }
    let more = j.get("more").and_then(Value::as_bool).unwrap_or(false);
    if !claim_ok && !more { return bad("the server claims a head the rows never contained", claim_seq); }
    let checked = rows.len();
    (true, json!({"ok": true, "checked": checked, "first_seq": if checked > 0 { Some(after_seq + 1) } else { None }, "last_seq": after_seq + checked as u64, "head_hash": prev, "more": more}).to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn door() -> Value { serde_json::from_str::<Value>(include_str!("../../server/rust/q_ledger_vectors.json")).unwrap()["door"].clone() }
    fn run(mut v: Value, extra: Value) -> (bool, Value) { for (k, x) in extra.as_object().unwrap() { v[k] = x.clone(); } let (ok, r) = check(&v.to_string()); (ok, serde_json::from_str(&r).unwrap()) }
    #[test] fn production_sql_chain_passes_including_unicode() {
        let (ok, r) = run(door(), json!({})); assert!(ok, "{r}"); assert_eq!(r["checked"], 4); assert_eq!(r["last_seq"], 4);
        assert_eq!(r["head_hash"], door()["rows"][3]["hash"]);
    }
    #[test] fn the_vector_really_has_multi_byte_text() { let d = door().to_string(); assert!(d.contains("é") && d.contains("日") && d.contains("😀")); }
    #[test] fn every_changed_field_is_caught_at_its_row() {
        for (k, nv) in [("target", "tampered"), ("reason", "another reason text"), ("action", "send_cancel"), ("meta", "{}"), ("ts", "1"), ("actor", "00000000-0000-0000-0000-000000000009")] {
            let mut d = door(); d["rows"][1][k] = json!(nv);
            let (ok, r) = run(d, json!({})); assert!(!ok, "{k}"); assert_eq!(r["bad_seq"], 2, "{k}");
        }
    }
    #[test] fn a_dropped_or_swapped_row_is_caught() {
        let mut d = door(); d["rows"].as_array_mut().unwrap().remove(1); let (ok, r) = run(d, json!({})); assert!(!ok); assert_eq!(r["bad_seq"], 2);
        let mut d = door(); d["rows"].as_array_mut().unwrap().swap(1, 2); assert!(!run(d, json!({})).0);
    }
    #[test] fn a_forged_link_is_caught_even_with_a_matching_row_hash() {
        let mut d = door(); d["rows"][2]["prev"] = json!(ZERO); let (ok, r) = run(d, json!({})); assert!(!ok); assert_eq!(r["bad_seq"], 3);
    }
    #[test] fn pages_chain_together_and_a_wrong_start_is_refused() {
        let all = door()["rows"].as_array().unwrap().clone();
        let mut p1 = door(); p1["rows"] = json!(all[..2]); p1["more"] = json!(true);
        let (ok, r) = run(p1, json!({})); assert!(ok); let h = r["head_hash"].as_str().unwrap().to_string(); assert_eq!(r["last_seq"], 2);
        let mut p2 = door(); p2["rows"] = json!(all[2..]);
        assert!(run(p2.clone(), json!({"after_seq": 2, "after_hash": h})).0);
        assert!(!run(p2.clone(), json!({"after_seq": 2, "after_hash": ZERO})).0);
        assert!(!run(p2, json!({"after_seq": 1, "after_hash": h})).0);
    }
    #[test] fn the_claimed_head_must_match() {
        let h = door()["rows"][3]["hash"].as_str().unwrap().to_string();
        assert!(run(door(), json!({"claim_head_seq": 4, "claim_head_hash": h})).0);
        assert!(!run(door(), json!({"claim_head_seq": 4, "claim_head_hash": ZERO})).0);
        assert!(!run(door(), json!({"claim_head_seq": 9, "claim_head_hash": h})).0, "a head the rows never contained");
    }
    #[test] fn garbage_is_a_refusal_not_a_pass() {
        for s in ["", "[]", "{}", r#"{"v":"fmail-ledger-v1"}"#, r#"{"v":"x","zero":"","rows":[]}"#] { assert!(!check(s).0, "{s}"); }
    }
    #[test] fn an_empty_ledger_is_a_pass_with_zero_rows() {
        let mut d = door(); d["rows"] = json!([]); let (ok, r) = run(d, json!({})); assert!(ok); assert_eq!(r["checked"], 0);
    }
}
