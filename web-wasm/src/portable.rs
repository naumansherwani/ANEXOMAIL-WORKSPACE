//! portable@1 — G5d part 3. ONE call in the browser verifies a whole portable-pin bundle (the canonical text of `GET /founder/v1/audit/portable`). Technology: Rust -> WASM kernel (Rule 52).
//! A brand-new browser with no remembered pin asks: "is this the history that existed at time T, extended without change?" This module answers it WITHOUT trusting the server:
//!   1. sha256(text) equals the sha the server committed to (the bytes the UI shows are the bytes that were hashed);
//!   2. the horizon note and the head note are canonical C2SP notes with a valid Ed25519 signature from the audit-log key listed in the bundle (`checkpoint@1` rules);
//!   3. the horizon note's sha256 is the digest the outside evidence binds, and the evidence holds: >= 2 DIFFERENT time-stamp authorities (RFC 3161, distinct signer pins) or a Bitcoin
//!      attestation (`anchor@1` rules); no authority may date the seal before the seal existed (300 s clock allowance); the anchored time the server claims must be the one the tokens show;
//!   4. ONE RFC 9162 consistency proof joins the horizon root to the head root, and its sizes and roots are exactly the signed notes' (`merkle@2` rules).
//! Honest limits (never over-claimed): the TSA CMS signature is checked by the founder server, not here (the kernel has no RSA/ECDSA, same as `anchor@1`); entries before the horizon are not
//! covered; a Bitcoin attestation is counted (the commitment chain is checked) but its block time is not proven here; "nothing here is witnessed".
//! The decision logic lives HERE and only here: the React-TS side only displays this report.
use crate::{anchor, checkpoint, ed, merkle};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;

pub const MAX_TEXT: usize = 2_000_000;
/// Independent authorities a horizon needs. The server's policy may ask for MORE; it can never lower this floor.
pub const MIN_TSA: usize = 2;
/// An authority's clock may run this far behind the server's (ms) before "dated before the seal existed" is called.
pub const SKEW_MS: i64 = 300_000;

fn hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
fn h32(s: &str) -> Option<[u8; 32]> {
    if s.len() != 64 || !s.bytes().all(|c| c.is_ascii_digit() || (b'a'..=b'f').contains(&c)) { return None; }
    let mut o = [0u8; 32];
    for i in 0..32 { o[i] = u8::from_str_radix(&s[2 * i..2 * i + 2], 16).ok()?; }
    Some(o)
}
fn s<'a>(v: &'a Value, k: &str) -> Result<&'a str, String> { v.get(k).and_then(|x| x.as_str()).ok_or_else(|| format!("missing text field `{k}`")) }
fn u(v: &Value, k: &str) -> Result<u64, String> { v.get(k).and_then(|x| x.as_u64()).ok_or_else(|| format!("missing number field `{k}`")) }

/// One signed note, judged with the shared C2SP rules and the kernel's strict Ed25519.
fn check_note(part: &Value, keys: &[Value], what: &str) -> Result<String, String> {
    let (note, origin, root, size) = (s(part, "note")?, s(part, "origin")?, s(part, "root")?, u(part, "size")?);
    let kid = u(part, "key_id")?;
    let key = keys.iter().find(|k| k.get("id").and_then(|x| x.as_u64()) == Some(kid)).ok_or_else(|| format!("the {what} names key {kid}, which the bundle does not list"))?;
    if s(key, "name")? != origin { return Err(format!("the {what} origin is not the key name")); }
    let pub_hex = s(key, "pub_hex")?;
    let pk = h32(pub_hex).ok_or_else(|| "a public key is not 64 lowercase hex characters".to_string())?;
    let r = h32(root).ok_or_else(|| format!("the {what} root is not 64 lowercase hex characters"))?;
    match checkpoint::verify(note, origin, &pk, size, &r, &|m, sig| ed::verify(&pk, m, sig)) {
        checkpoint::Verdict::Ok => Ok(pub_hex.to_string()),
        checkpoint::Verdict::Bad(why) => Err(format!("the {what} note does not verify: {why}")),
    }
}

/// The evidence on the horizon. Returns (distinct TSA signers, bitcoin attestations, earliest token time).
fn check_evidence(h: &Value, digest: &str) -> Result<(usize, usize, Option<i64>), String> {
    let ev = h.get("evidence").and_then(|e| e.as_array()).ok_or("the horizon has no evidence list")?;
    let signed = h.get("signed_ms").and_then(|x| x.as_i64()).ok_or("the horizon has no signed_ms")?;
    let (mut pins, mut btc, mut first): (BTreeSet<String>, BTreeSet<String>, Option<i64>) = (BTreeSet::new(), BTreeSet::new(), None);
    for e in ev {
        let (kind, stage, hexev) = (s(e, "kind")?, s(e, "stage")?, s(e, "evidence_hex")?);
        match (kind, stage) {
            ("rfc3161", "tsa_token") => {
                // a token that does not bind THIS digest is not evidence: it is ignored, never half-counted
                let Some(o) = anchor::inspect(1, hexev, digest) else { continue };
                let f: Vec<&str> = o.split('|').collect();
                let (gen_ms, pin) = (f.first().and_then(|x| x.parse::<i64>().ok()).ok_or("a token has no time")?, f.get(2).copied().ok_or("a token has no signer")?);
                if gen_ms + SKEW_MS < signed { return Err(format!("an authority dated the seal {} s before it existed", (signed - gen_ms) / 1000)); }
                pins.insert(pin.to_string());
                first = Some(first.map_or(gen_ms, |x: i64| x.min(gen_ms)));
            }
            ("ots", "ots_bitcoin") => {
                if let Some(o) = anchor::inspect(2, hexev, digest) { if o.starts_with("bitcoin|") { btc.insert(o); } }
            }
            _ => {}
        }
    }
    let min_tsa = h.get("min_tsa").and_then(|x| x.as_u64()).unwrap_or(MIN_TSA as u64).max(MIN_TSA as u64) as usize;
    if pins.len() < min_tsa && btc.is_empty() {
        return Err(format!("only {} different time-stamp authorit{} proven (need {} or a Bitcoin attestation)", pins.len(), if pins.len() == 1 { "y" } else { "ies" }, min_tsa));
    }
    if let (Some(claim), Some(shown)) = (h.get("anchored_ms").and_then(|x| x.as_i64()), first) {
        if !pins.is_empty() && claim != shown && btc.is_empty() { return Err("the anchored time the server claims is not the time the tokens show".into()); }
    }
    Ok((pins.len(), btc.len(), first))
}

/// The whole judgement. Ok(report) only when every step holds; Err(first problem). `steps` lists the steps that PASSED, in order.
fn judge(text: &str, sha: &str, steps: &mut Vec<&'static str>) -> Result<Value, String> {
    if text.len() > MAX_TEXT { return Err("the bundle is larger than the kernel accepts".into()); }
    if h32(sha).is_none() { return Err("the committed sha is not 64 lowercase hex characters".into()); }
    if hex(&Sha256::digest(text.as_bytes())) != sha { return Err("sha256 of the text is not the sha the server committed to".into()); }
    steps.push("sha256");
    let v: Value = serde_json::from_str(text).map_err(|_| "the bundle text is not JSON".to_string())?;
    if v.get("v").and_then(|x| x.as_u64()) != Some(1) { return Err("unknown bundle version".into()); }
    let (h, d) = (v.get("horizon").ok_or("no horizon")?, v.get("head").ok_or("no head")?);
    let keys = v.get("keys").and_then(|k| k.as_array()).ok_or("no signing keys")?;
    steps.push("shape");
    let (hsize, dsize, hcp, dcp) = (u(h, "size")?, u(d, "size")?, u(h, "cp_id")?, u(d, "cp_id")?);
    if dsize < hsize || dcp < hcp { return Err("the head is older than the horizon".into()); }
    let pub_h = check_note(h, keys, "horizon")?;
    steps.push("horizon_note");
    let pub_d = check_note(d, keys, "head")?;
    if pub_h != pub_d { return Err("the horizon and the head are signed by different keys".into()); }
    steps.push("head_note");
    let digest = hex(&Sha256::digest(s(h, "note")?.as_bytes()));
    if let Some(claim) = h.get("digest_hex").and_then(|x| x.as_str()) { if claim != digest { return Err("the horizon digest is not the sha256 of its signed note".into()); } }
    let (tsa, btc, anchored) = check_evidence(h, &digest)?;
    steps.push("outside_time");
    let p = v.get("proof").filter(|p| !p.is_null()).ok_or_else(|| format!("no proof: {}", v.get("proof_problem").and_then(|x| x.as_str()).unwrap_or("none given")))?;
    if u(p, "first")? != hsize || u(p, "second")? != dsize { return Err("the proof sizes are not the sizes of the signed notes".into()); }
    if s(p, "first_root")? != s(h, "root")? || s(p, "second_root")? != s(d, "root")? { return Err("the proof roots are not the roots of the signed notes".into()); }
    let hashes: Vec<&str> = p.get("proof").and_then(|x| x.as_array()).ok_or("the proof has no hashes")?.iter().map(|x| x.as_str().unwrap_or("")).collect();
    if !merkle::verify_consistency_text(hsize, dsize, s(p, "first_root")?, s(p, "second_root")?, &hashes.join(",")) { return Err("the consistency proof does not verify".into()); }
    steps.push("consistency");
    Ok(json!({"horizon_cp": hcp, "head_cp": dcp, "horizon_size": hsize, "head_size": dsize, "origin": s(h, "origin")?, "tsa": tsa, "bitcoin": btc, "anchored_ms": anchored,
              "proof_hashes": hashes.len(), "not_covered_rows": hsize}))
}

/// (all steps held?, JSON report). The report always names the steps that passed and, when something failed, the first problem in plain words.
pub fn verify(text: &str, sha: &str) -> (bool, String) {
    let mut steps = Vec::new();
    let all = ["sha256", "shape", "horizon_note", "head_note", "outside_time", "consistency"];
    match judge(text, sha, &mut steps) {
        Ok(facts) => (true, json!({"ok": true, "passed": steps, "facts": facts}).to_string()),
        Err(why) => {
            let failed = all.get(steps.len()).copied().unwrap_or("shape");
            (false, json!({"ok": false, "passed": steps, "failed_step": failed, "problem": why}).to_string())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn good() -> (String, String, Value) {
        let v: Value = serde_json::from_str(include_str!("../../server/rust/g5d_kernel_vector.json")).unwrap();
        (v["good"]["text"].as_str().unwrap().to_string(), v["good"]["sha"].as_str().unwrap().to_string(), v["facts"].clone())
    }
    fn resigned(f: impl FnOnce(&mut Value)) -> (bool, Value) {
        let (t, _, _) = good();
        let mut v: Value = serde_json::from_str(&t).unwrap();
        f(&mut v);
        let t2 = v.to_string();
        let (ok, rep) = verify(&t2, &hex(&Sha256::digest(t2.as_bytes())));
        (ok, serde_json::from_str(&rep).unwrap())
    }

    #[test]
    fn a_bundle_made_by_independent_tools_passes_every_step() {
        let (t, s, facts) = good();
        let (ok, rep) = verify(&t, &s);
        let r: Value = serde_json::from_str(&rep).unwrap();
        assert!(ok, "{rep}");
        assert_eq!(r["passed"].as_array().unwrap().len(), 6);
        for k in ["horizon_cp", "head_cp", "horizon_size", "head_size", "tsa", "anchored_ms", "proof_hashes"] { assert_eq!(r["facts"][k], facts[k], "{k}"); }
        assert_eq!(r["facts"]["not_covered_rows"], 4);
    }
    #[test]
    fn every_byte_flip_of_the_text_is_caught_by_the_sha() {
        let (t, s, _) = good();
        let mut n = 0;
        for i in (0..t.len()).step_by(7) {
            let mut b = t.clone().into_bytes();
            b[i] = if b[i] == b'1' { b'2' } else { b'1' };
            if let Ok(m) = String::from_utf8(b) { if m != t { let (ok, rep) = verify(&m, &s); assert!(!ok, "flip at {i}"); assert!(rep.contains("\"failed_step\":\"sha256\""), "{rep}"); n += 1; } }
        }
        assert!(n > 500);
    }
    #[test]
    fn bad_or_missing_sha_is_refused() {
        let (t, s, _) = good();
        for bad in [s.to_uppercase(), s[..63].to_string(), "0".repeat(64), String::new()] { assert!(!verify(&t, &bad).0); }
        assert!(!verify(&"x".repeat(MAX_TEXT + 1), &s).0);
    }
    #[test]
    fn a_tampered_note_with_an_honest_sha_fails_at_the_signature() {
        // the server could re-hash a changed note: the sha cannot save it, the Ed25519 signature does
        let (ok, r) = resigned(|v| { let n = v["horizon"]["note"].as_str().unwrap().replacen("\n4\n", "\n5\n", 1); v["horizon"]["note"] = json!(n); });
        assert!(!ok); assert_eq!(r["failed_step"], "horizon_note"); assert!(r["problem"].as_str().unwrap().contains("does not verify"), "{r}");
        let (ok, r) = resigned(|v| { let n = v["head"]["note"].as_str().unwrap().replacen("\n9\n", "\n8\n", 1); v["head"]["note"] = json!(n); });
        assert!(!ok); assert_eq!(r["failed_step"], "head_note");
        let (ok, r) = resigned(|v| v["keys"][0]["pub_hex"] = json!("11".repeat(32)));
        assert!(!ok); assert_eq!(r["failed_step"], "horizon_note");
        let (ok, r) = resigned(|v| v["head"]["key_id"] = json!(7));
        assert!(!ok); assert!(r["problem"].as_str().unwrap().contains("does not list"), "{r}");
    }
    #[test]
    fn outside_time_needs_two_different_authorities_or_bitcoin() {
        let (ok, r) = resigned(|v| { v["horizon"]["evidence"].as_array_mut().unwrap().pop(); });
        assert!(!ok); assert_eq!(r["failed_step"], "outside_time"); assert!(r["problem"].as_str().unwrap().contains("only 1 different"), "{r}");
        let (ok, r) = resigned(|v| { let e = v["horizon"]["evidence"][0].clone(); v["horizon"]["evidence"][1] = e; });   // the SAME authority twice is still one
        assert!(!ok); assert!(r["problem"].as_str().unwrap().contains("only 1"), "{r}");
        let (ok, _) = resigned(|v| v["horizon"]["evidence"] = json!([])); assert!(!ok);
        let (ok, r) = resigned(|v| v["horizon"]["min_tsa"] = json!(3)); assert!(!ok, "{r}");   // the server may ask for more
        let (ok, _) = resigned(|v| v["horizon"]["min_tsa"] = json!(1)); assert!(ok);            // ... but never lower the kernel's floor of 2 (two are present here)
        let (ok, r) = resigned(|v| { v["horizon"]["evidence"].as_array_mut().unwrap().pop(); v["horizon"]["min_tsa"] = json!(1); });
        assert!(!ok, "a server policy of 1 must not lower the floor: {r}");
    }
    #[test]
    fn a_token_for_another_digest_is_not_evidence() {
        let (ok, r) = resigned(|v| {
            let n = v["horizon"]["note"].as_str().unwrap().to_string();
            // a different (still canonical) note body would have a different digest: the tokens no longer bind it
            v["horizon"]["digest_hex"] = json!(hex(&Sha256::digest(n.as_bytes())));
            v["horizon"]["evidence"][0]["evidence_hex"] = json!(v["horizon"]["evidence"][0]["evidence_hex"].as_str().unwrap().replacen("a", "b", 1));
        });
        assert!(!ok, "{r}");
        let (ok, r) = resigned(|v| v["horizon"]["digest_hex"] = json!("00".repeat(32)));
        assert!(!ok); assert!(r["problem"].as_str().unwrap().contains("sha256 of its signed note"), "{r}");
    }
    #[test]
    fn an_authority_cannot_date_the_seal_before_it_existed() {
        let (ok, r) = resigned(|v| { let t = v["horizon"]["signed_ms"].as_i64().unwrap(); v["horizon"]["signed_ms"] = json!(t + 3_600_000); });
        assert!(!ok); assert!(r["problem"].as_str().unwrap().contains("before it existed"), "{r}");
        let (ok, r) = resigned(|v| { let t = v["horizon"]["anchored_ms"].as_i64().unwrap(); v["horizon"]["anchored_ms"] = json!(t + 86_400_000); });
        assert!(!ok); assert!(r["problem"].as_str().unwrap().contains("claims"), "{r}");
    }
    #[test]
    fn the_proof_must_join_exactly_the_signed_notes() {
        let (ok, r) = resigned(|v| v["proof"]["proof"][0] = json!("00".repeat(32)));
        assert!(!ok); assert_eq!(r["failed_step"], "consistency");
        let (ok, _) = resigned(|v| { v["proof"]["proof"].as_array_mut().unwrap().pop(); }); assert!(!ok);
        let (ok, r) = resigned(|v| v["proof"]["first"] = json!(3)); assert!(!ok); assert!(r["problem"].as_str().unwrap().contains("sizes"), "{r}");
        let (ok, r) = resigned(|v| { let x = v["proof"]["second_root"].clone(); v["proof"]["second_root"] = v["proof"]["first_root"].clone(); v["proof"]["first_root"] = x; });
        assert!(!ok); assert!(r["problem"].as_str().unwrap().contains("roots"), "{r}");
        let (ok, r) = resigned(|v| { v["proof"] = Value::Null; v["proof_problem"] = json!("the ledger is larger than the proof limit"); });
        assert!(!ok); assert!(r["problem"].as_str().unwrap().contains("larger than the proof limit"), "{r}");
        let (ok, _) = resigned(|v| v["v"] = json!(2)); assert!(!ok);
        let (ok, _) = resigned(|v| { let x = v["head"].clone(); v["head"] = v["horizon"].clone(); v["horizon"] = x; }); assert!(!ok, "head older than horizon");
    }
    #[test]
    fn a_bundle_from_the_production_sql_fails_only_at_the_signature() {
        // made by E131/E138 on a scratch Postgres with FAKE signatures (sandbox): everything before the Ed25519 check is well formed, the signature is what stops it
        let v: Value = serde_json::from_str(include_str!("../../server/rust/g5d_bundle_vector.json")).unwrap();
        let (ok, rep) = verify(v["text"].as_str().unwrap(), v["sha"].as_str().unwrap());
        let r: Value = serde_json::from_str(&rep).unwrap();
        assert!(!ok); assert_eq!(r["failed_step"], "horizon_note"); assert_eq!(r["passed"], json!(["sha256", "shape"]));
    }
}
