//! G5d part 2 — the PORTABLE-PIN OBSERVER and its route. Technology: Rust (axum 0.8 + tokio). The decision logic lives in SQL (E131 horizon + bundle, E138 lease / tick / serve);
//! the browser WASM kernel does the verifying (part 3). This file does three honest jobs and nothing else:
//!   1. TICK (~60 s, from the live loop): ask SQL to take the lease and observe. When the outcome is `observed` (a new or changed horizon) Rust fetches the canonical text and
//!      CHECKS IT AGAIN with its own code (second witness): sha256 of the text, the shape, and the RFC 9162 proof with `merkle_core`. A disagreement is written to the
//!      SQL tick chain as a failure (`founder_portable_tick_fail`), so the gauge shows it; it is never swallowed.
//!   2. VIEW (GET /founder/v1/audit/portable): the status + the canonical bundle text as a STRING (the browser hashes exactly these bytes) + the Rust re-check.
//!   3. NEVER decide trust: this file does not say "portable"; SQL's level and the kernel's own check do.
//! Honest limits: Rust and SQL share the server, so they are not independent of a server that lies about everything; the independent check is the kernel in the browser.
use crate::data::Sb;
use crate::ledger;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::sync::OnceLock;

/// The lease holder name of THIS process: `founder-<pid>-<boot seconds>`. Same shape rule as SQL (`_fm_ptick_holder_ok`).
pub fn holder() -> &'static str {
    static H: OnceLock<String> = OnceLock::new();
    H.get_or_init(|| {
        let boot = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
        format!("founder-{}-{}", std::process::id(), boot)
    })
}

/// Mirror of SQL `^[a-z0-9][a-z0-9._:-]{2,63}$` (3..=64 characters).
pub fn holder_ok(s: &str) -> bool {
    let b = s.as_bytes();
    (3..=64).contains(&b.len()) && b[0].is_ascii_lowercase() | b[0].is_ascii_digit() && b[1..].iter().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || b"._:-".contains(c))
}

fn sha_hex(t: &str) -> String { Sha256::digest(t.as_bytes()).iter().map(|x| format!("{x:02x}")).collect() }

/// Rust's own re-check of one canonical bundle. Ok(facts) only when ALL of these hold: sha256(text) == the sha SQL committed to; the text is the v1 shape; the head is not older than the
/// horizon; the proof (if the ledger grew) joins exactly the horizon root and the head root and VERIFIES (RFC 9162, `merkle_core`); the horizon carries evidence; keys are present.
pub fn check_bundle(text: &str, sha: &str) -> Result<Value, String> {
    if sha.len() != 64 || !sha.bytes().all(|c| c.is_ascii_digit() || (b'a'..=b'f').contains(&c)) { return Err("the committed sha is not 64 lowercase hex characters".into()); }
    if sha_hex(text) != sha { return Err("sha256 of the canonical text is not the sha SQL committed to".into()); }
    let v: Value = serde_json::from_str(text).map_err(|_| "the canonical text is not JSON".to_string())?;
    if v.get("v").and_then(|x| x.as_u64()) != Some(1) { return Err("unknown bundle version".into()); }
    let (h, hd) = (v.get("horizon").ok_or("no horizon")?, v.get("head").ok_or("no head")?);
    let (hc, dc) = (h.get("cp_id").and_then(|x| x.as_i64()).ok_or("horizon has no cp_id")?, hd.get("cp_id").and_then(|x| x.as_i64()).ok_or("head has no cp_id")?);
    let (hs, ds) = (h.get("size").and_then(|x| x.as_u64()).ok_or("horizon has no size")?, hd.get("size").and_then(|x| x.as_u64()).ok_or("head has no size")?);
    if dc < hc || ds < hs { return Err("the head is older than the horizon".into()); }
    let (hr, dr) = (h.get("root").and_then(|x| x.as_str()).ok_or("horizon has no root")?, hd.get("root").and_then(|x| x.as_str()).ok_or("head has no root")?);
    if !h.get("evidence").and_then(|e| e.as_array()).map(|e| !e.is_empty()).unwrap_or(false) { return Err("the horizon carries no evidence".into()); }
    if !v.get("keys").map(|k| k.is_array() || k.is_object()).unwrap_or(false) || v["keys"].is_null() { return Err("no signing keys in the bundle".into()); }
    let p = v.get("proof").filter(|p| !p.is_null()).ok_or_else(|| format!("no proof: {}", v.get("proof_problem").and_then(|x| x.as_str()).unwrap_or("none given")))?;
    if p.get("first").and_then(|x| x.as_u64()) != Some(hs) || p.get("second").and_then(|x| x.as_u64()) != Some(ds) { return Err("the proof sizes are not the horizon and head sizes".into()); }
    if p.get("first_root").and_then(|x| x.as_str()) != Some(hr) || p.get("second_root").and_then(|x| x.as_str()) != Some(dr) { return Err("the proof roots are not the signed roots".into()); }
    if !ledger::check_consistency(p) { return Err("the consistency proof does not verify".into()); }
    Ok(json!({"horizon_cp": hc, "head_cp": dc, "horizon_size": hs, "head_size": ds, "proof_hashes": p.get("proof").and_then(|x| x.as_array()).map(|a| a.len()).unwrap_or(0)}))
}

/// One tick. Returns the SQL outcome string ("observed", "throttled", "no_horizon", "failed", "lease_denied") or None when the E138 SQL step has not been run.
pub async fn tick(sb: &Sb) -> Option<String> {
    let t = sb.rpc("founder_portable_tick", json!({"p_holder": holder()})).await?;
    let out = t.get("outcome").and_then(|o| o.as_str())?.to_string();
    if out == "observed" {
        // a new or changed horizon: re-check the very text the browser will hash. Failure goes into the SQL chain, where the pulse reads it.
        if let Err(why) = recheck_current(sb).await { let _ = sb.rpc("founder_portable_tick_fail", json!({"p_holder": holder(), "p_error": format!("rust re-check: {why}")})).await; }
    }
    Some(out)
}

async fn recheck_current(sb: &Sb) -> Result<Value, String> {
    let b = sb.rpc("founder_portable_bundle_text", json!({})).await.ok_or("the canonical bundle could not be read")?;
    if b.get("found").and_then(|f| f.as_bool()) != Some(true) { return Err("no canonical bundle although a horizon was observed".into()); }
    check_bundle(b.get("text").and_then(|t| t.as_str()).ok_or("no text")?, b.get("sha").and_then(|t| t.as_str()).ok_or("no sha")?)
}

/// What the browser asks for. `uid` = the founder (from the authenticated token). Nothing here is cached: a stale bundle would be a stale claim.
pub async fn view(sb: &Sb, uid: &str) -> Value {
    let (s, b) = tokio::join!(sb.rpc("founder_portable_status", json!({})), sb.rpc("founder_portable_serve", json!({"p_actor": uid})));
    let (Some(status), Some(bundle)) = (s, b) else { return json!({"connected": false, "reason": "Run the E138 SQL step (sql-run.sh) once."}) };
    if bundle.get("found").and_then(|f| f.as_bool()) != Some(true) {
        return json!({"connected": true, "status": status, "found": false, "why": bundle.get("why").cloned().unwrap_or(Value::Null)});
    }
    let (text, sha) = (bundle.get("text").and_then(|t| t.as_str()).unwrap_or(""), bundle.get("sha").and_then(|t| t.as_str()).unwrap_or(""));
    let rust_check = match check_bundle(text, sha) {
        Ok(f) => json!({"ok": true, "facts": f}),
        Err(why) => {
            // report it into the chain (only the lease holder may; if another process holds the lease this is refused by SQL and the route still tells the founder)
            let _ = sb.rpc("founder_portable_tick_fail", json!({"p_holder": holder(), "p_error": format!("rust re-check on serve: {why}")})).await;
            json!({"ok": false, "problem": why})
        }
    };
    json!({"connected": true, "status": status, "found": true, "bundle_text": text, "bundle_sha": sha,
           "horizon_cp": bundle.get("horizon_cp"), "head_cp": bundle.get("head_cp"), "bytes": bundle.get("bytes"), "logged": bundle.get("logged"), "rust_check": rust_check})
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ledger::merkle;

    /// A REAL bundle built with the production Merkle code (no hand-typed hashes): 9 leaves, horizon at 4, head at 9, the proof from `merkle_core`.
    fn real_bundle(first: usize, second: usize) -> (String, String) {
        let leaves: Vec<_> = (1..=second).map(|g| merkle::leaf(&Sha256::digest(format!("portable-vector-{g}").as_bytes()).into())).collect();
        let (r1, r2) = (merkle::to_hex(&merkle::root_of(&leaves[..first]).unwrap()), merkle::to_hex(&merkle::root_of(&leaves).unwrap()));
        let proof: Vec<String> = if first == second { vec![] } else { merkle::consistency_proof(&leaves, first, second).unwrap().iter().map(merkle::to_hex).collect() };
        let t = json!({"v": 1, "horizon": {"cp_id": 2, "size": first, "root": r1, "evidence": [{"stage": "tsa_token"}]}, "head": {"cp_id": 3, "size": second, "root": r2},
                       "keys": [{"name": "k"}], "proof": {"first": first, "second": second, "first_root": r1, "second_root": r2, "proof": proof}, "proof_problem": null}).to_string();
        let s = sha_hex(&t);
        (t, s)
    }

    #[test]
    fn holder_names_match_the_sql_rule() {
        for ok in ["abc", "founder-1234-1793000000", "a.b_c:d-e", "0aa", &format!("a{}", "b".repeat(63))] { assert!(holder_ok(ok), "{ok}"); }
        for bad in ["", "ab", "Abc", "-abc", ".abc", "has space", "a/b", "ünï", &format!("a{}", "b".repeat(64)), "abc\n"] { assert!(!holder_ok(bad), "{bad:?}"); }
        assert!(holder_ok(holder()), "this process's own name must pass the SQL rule: {}", holder());
    }
    #[test]
    fn a_real_bundle_passes_with_and_without_growth() {
        let (t, s) = real_bundle(4, 9);
        let f = check_bundle(&t, &s).unwrap();
        assert_eq!((f["horizon_cp"].as_i64(), f["head_cp"].as_i64(), f["horizon_size"].as_u64(), f["head_size"].as_u64()), (Some(2), Some(3), Some(4), Some(9)));
        assert!(f["proof_hashes"].as_u64().unwrap() >= 1);
        let (t, s) = real_bundle(7, 7);   // nothing newer was signed: empty proof, same root
        assert_eq!(check_bundle(&t, &s).unwrap()["proof_hashes"], 0);
    }
    #[test]
    fn every_byte_flip_of_the_text_is_caught() {
        let (t, s) = real_bundle(4, 9);
        let mut caught = 0;
        for i in 0..t.len() {
            let mut b = t.clone().into_bytes();
            b[i] = if b[i] == b'1' { b'2' } else { b'1' };
            if let Ok(m) = String::from_utf8(b) { if m != t { assert!(check_bundle(&m, &s).is_err(), "flip at {i} was accepted"); caught += 1; } }
        }
        assert!(caught > 100);
    }
    #[test]
    fn a_wrong_or_malformed_sha_is_refused() {
        let (t, s) = real_bundle(4, 9);
        assert!(check_bundle(&t, &s.to_uppercase()).is_err());
        assert!(check_bundle(&t, &s[..63]).is_err());
        assert!(check_bundle(&t, &"0".repeat(64)).is_err());
        assert!(check_bundle(&t, "").is_err());
    }
    /// Re-sign the changed text so only the INNER rule can catch it (the sha is honest about the tampered bytes).
    fn resigned(mut v: Value, f: impl FnOnce(&mut Value)) -> Result<Value, String> { f(&mut v); let t = v.to_string(); let s = sha_hex(&t); check_bundle(&t, &s) }
    #[test]
    fn inner_rules_catch_a_bundle_whose_sha_is_honest() {
        let (t, _) = real_bundle(4, 9);
        let v: Value = serde_json::from_str(&t).unwrap();
        assert!(resigned(v.clone(), |_| {}).is_ok());
        assert!(resigned(v.clone(), |v| v["v"] = json!(2)).is_err(), "version");
        assert!(resigned(v.clone(), |v| v["head"]["size"] = json!(3)).is_err(), "head smaller than horizon");
        assert!(resigned(v.clone(), |v| v["head"]["cp_id"] = json!(1)).is_err(), "head cp older");
        assert!(resigned(v.clone(), |v| v["horizon"]["evidence"] = json!([])).is_err(), "no evidence");
        assert!(resigned(v.clone(), |v| v["keys"] = Value::Null).is_err(), "no keys");
        assert!(resigned(v.clone(), |v| v["proof"] = Value::Null).is_err(), "no proof");
        assert!(resigned(v.clone(), |v| v["proof"]["first"] = json!(5)).is_err(), "proof size");
        assert!(resigned(v.clone(), |v| { let r = v["head"]["root"].clone(); v["horizon"]["root"] = r; }).is_err(), "swapped root");
        assert!(resigned(v.clone(), |v| v["proof"]["proof"][0] = json!("00".repeat(32))).is_err(), "changed proof hash");
        assert!(resigned(v.clone(), |v| { v["proof"]["proof"].as_array_mut().unwrap().pop(); }).is_err(), "short proof");
        assert!(resigned(v.clone(), |v| v["proof"]["second_root"] = json!("zz")).is_err(), "bad root hex");
        assert!(resigned(v, |v| { v["head"]["root"] = json!("11".repeat(32)); v["proof"]["second_root"] = json!("11".repeat(32)); }).is_err(), "a different head root with a matching claim");
    }
    /// The vector was MADE BY THE PRODUCTION SQL (E131 `founder_portable_bundle` -> E138 `founder_portable_bundle_text`) on a scratch Postgres with 9+3 real ledger rows and a real RFC 9162 proof.
    /// This is the cross-layer proof: the text SQL commits to is accepted by Rust's own check, and every byte of it is protected by the sha.
    #[test]
    fn sql_made_bundle_passes_rust_recheck() {
        let v: Value = serde_json::from_str(include_str!("../../rust/g5d_bundle_vector.json")).unwrap();
        let (t, s) = (v["text"].as_str().unwrap(), v["sha"].as_str().unwrap());
        let f = check_bundle(t, s).unwrap();
        assert!(f["head_size"].as_u64().unwrap() > f["horizon_size"].as_u64().unwrap() && f["proof_hashes"].as_u64().unwrap() >= 1);
        let mut m = t.to_string();
        let at = m.find("\"size\"").unwrap();
        m.replace_range(at + 8..at + 9, "9");   // one digit of a size changes
        assert!(check_bundle(&m, s).is_err());
    }
    #[test]
    fn a_missing_proof_says_why() {
        let (t, _) = real_bundle(4, 9);
        let mut v: Value = serde_json::from_str(&t).unwrap();
        v["proof"] = Value::Null; v["proof_problem"] = json!("the ledger is larger than the proof limit");
        let t2 = v.to_string();
        let e = check_bundle(&t2, &sha_hex(&t2)).unwrap_err();
        assert!(e.contains("larger than the proof limit"), "{e}");
    }
    #[tokio::test]
    async fn view_without_the_sql_step_is_honest_not_empty() {
        let sb = Sb { url: "http://127.0.0.1:1".into(), key: "k".into(), http: reqwest::Client::new() };
        let v = view(&sb, "00000000-0000-0000-0000-000000000000").await;
        assert_eq!(v["connected"], false);
        assert!(v["reason"].as_str().unwrap().contains("E138"));
        assert!(tick(&sb).await.is_none());
    }
}
