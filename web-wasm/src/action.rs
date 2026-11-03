//! action@1 — J3. The browser re-derives the digest of a protected action BEFORE the founder touches the key.
//! Technology: Rust -> WASM kernel (Rule 52), SHA-256 only (the same hash module the HMAC request signing uses), no new crates.
//! The server hands over {action, target, params, nonce} and says "the WebAuthn challenge will be <challenge>, digest <hash>". The kernel builds the canonical text with the SAME rules as the SQL
//! `_fp_canonical` (E118), hashes it and compares: a server that changes the action after the founder read it, or sends a challenge for something else, is caught here and the key is never touched.
//! The decision lives HERE; the React-TS side shows the report. Vectors: server/rust/j3_action_vectors.json, made by the production SQL (hash, canonical text, and the inputs SQL refuses).
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

const B64: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
fn b64url(d: &[u8]) -> String {
    let mut o = String::new();
    for c in d.chunks(3) {
        let n = (c[0] as u32) << 16 | (*c.get(1).unwrap_or(&0) as u32) << 8 | *c.get(2).unwrap_or(&0) as u32;
        for i in 0..=c.len() { o.push(B64[(n >> (18 - 6 * i) & 63) as usize] as char); }
    }
    o
}
fn hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
fn control(s: &str) -> bool { s.chars().any(|c| c <= '\u{1f}' || c == '\u{7f}') }

/// `_fp_canonical`, rule for rule. Err = the plain-language reason SQL gives too.
pub fn canonical(action: &str, target: &str, params: &Value, nonce: &str) -> Result<String, &'static str> {
    let ab = action.as_bytes();
    let action_ok = (3..=64).contains(&ab.len()) && ab[0].is_ascii_lowercase() && ab.iter().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || *c == b'_' || *c == b'.');
    if !action_ok { return Err("bad action name"); }
    if target.chars().count() > 200 || control(target) { return Err("bad action target"); }
    let nb = nonce.as_bytes();
    if !(16..=64).contains(&nb.len()) || !nb.iter().all(|c| c.is_ascii_alphanumeric() || *c == b'_' || *c == b'-') { return Err("bad nonce"); }
    let Some(map) = params.as_object() else { return Err("params must be an object") };
    let mut lines: Vec<(String, String)> = Vec::new();
    for (k, v) in map {
        let kb = k.as_bytes();
        let key_ok = !kb.is_empty() && kb.len() <= 40 && kb[0].is_ascii_lowercase() && kb.iter().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || *c == b'_');
        let Some(val) = v.as_str() else { return Err("every param value must be a short string with a plain key") };
        if !key_ok || val.chars().count() > 200 || control(val) { return Err("every param value must be a short string with a plain key"); }
        lines.push((k.clone(), val.to_string()));
    }
    lines.sort_by(|a, b| a.0.as_bytes().cmp(b.0.as_bytes())); // collate "C" = byte order
    let body = lines.iter().map(|(k, v)| format!("{k}={v}")).collect::<Vec<_>>().join("\n");
    Ok(format!("anexo-action-v1\n{action}\n{target}\n{nonce}\n{body}"))
}

pub fn digest(canon: &str) -> ([u8; 32], String) {
    let mut o = [0u8; 32];
    o.copy_from_slice(&Sha256::digest(canon.as_bytes()));
    (o, hex(&o))
}

/// Input JSON: {action, target, params, nonce, hash?, challenge?}. 1 = canonical text built, and every value the server claimed (hash, WebAuthn challenge) is what the kernel computed.
/// Report JSON: {ok, hash, challenge, canonical} or {ok:false, problem}. A missing claim is not a pass: with neither `hash` nor `challenge` the answer is still 1 only if asked with `need_claim:false`.
pub fn check(input: &str) -> (bool, String) {
    let fail = |p: &str| (false, json!({"ok": false, "problem": p}).to_string());
    let Ok(v) = serde_json::from_str::<Value>(input) else { return fail("input is not JSON") };
    let g = |k: &str| v.get(k).and_then(|x| x.as_str()).unwrap_or("");
    let canon = match canonical(g("action"), g("target"), v.get("params").unwrap_or(&Value::Null), g("nonce")) { Ok(c) => c, Err(e) => return fail(e) };
    let (raw, h) = digest(&canon);
    let ch = b64url(&raw);
    let claimed_hash = v.get("hash").and_then(|x| x.as_str());
    let claimed_ch = v.get("challenge").and_then(|x| x.as_str());
    if v.get("need_claim").and_then(|x| x.as_bool()).unwrap_or(true) && claimed_hash.is_none() && claimed_ch.is_none() { return fail("the server made no claim to check"); }
    if let Some(c) = claimed_hash { if c != h { return fail("the digest the server sent is not the digest of this action"); } }
    if let Some(c) = claimed_ch { if c != ch { return fail("the WebAuthn challenge is not the digest of this action: do not touch the key"); } }
    (true, json!({"ok": true, "hash": h, "challenge": ch, "canonical": canon}).to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    const V: &str = include_str!("../../server/rust/j3_action_vectors.json");
    #[test]
    fn matches_the_production_sql_for_every_vector() {
        let d: Value = serde_json::from_str(V).unwrap();
        let ok = d["ok"].as_array().unwrap();
        assert!(ok.len() >= 4);
        for c in ok {
            let canon = canonical(c["action"].as_str().unwrap(), c["target"].as_str().unwrap(), &c["params"], c["nonce"].as_str().unwrap()).unwrap();
            assert_eq!(canon, c["canonical"].as_str().unwrap());
            assert_eq!(digest(&canon).1, c["hash"].as_str().unwrap());
            let inp = json!({"action": c["action"], "target": c["target"], "params": c["params"], "nonce": c["nonce"], "hash": c["hash"], "challenge": b64url(&digest(&canon).0)}).to_string();
            assert!(check(&inp).0);
        }
    }
    #[test]
    fn refuses_exactly_what_sql_refuses() {
        let d: Value = serde_json::from_str(V).unwrap();
        for c in d["bad"].as_array().unwrap() {
            assert!(canonical(c["action"].as_str().unwrap(), c["target"].as_str().unwrap(), &c["params"], c["nonce"].as_str().unwrap()).is_err(), "{c}");
        }
        assert!(canonical("a.bcd", "t\u{7f}", &json!({}), "AAAAAAAAAAAAAAAA").is_err());
        assert!(canonical("a.bcd", &"x".repeat(201), &json!({}), "AAAAAAAAAAAAAAAA").is_err());
        assert!(canonical("a.bcd", "t", &json!({"k": "a\nb"}), "AAAAAAAAAAAAAAAA").is_err());
    }
    #[test]
    fn a_swapped_action_or_challenge_is_caught() {
        let d: Value = serde_json::from_str(V).unwrap();
        let c = &d["ok"][0];
        let canon = canonical(c["action"].as_str().unwrap(), c["target"].as_str().unwrap(), &c["params"], c["nonce"].as_str().unwrap()).unwrap();
        let good_ch = b64url(&digest(&canon).0);
        let mk = |target: &str, hash: &str, ch: &str| json!({"action": c["action"], "target": target, "params": c["params"], "nonce": c["nonce"], "hash": hash, "challenge": ch}).to_string();
        assert!(check(&mk(c["target"].as_str().unwrap(), c["hash"].as_str().unwrap(), &good_ch)).0);
        let (ok, rep) = check(&mk("another-credential", c["hash"].as_str().unwrap(), &good_ch));
        assert!(!ok && rep.contains("not the digest of this action"));
        let (ok, rep) = check(&mk(c["target"].as_str().unwrap(), c["hash"].as_str().unwrap(), "AAAA"));
        assert!(!ok && rep.contains("do not touch the key"));
        // no claim at all is not a pass
        assert!(!check(&json!({"action": c["action"], "target": c["target"], "params": c["params"], "nonce": c["nonce"]}).to_string()).0);
        assert!(!check("not json").0);
    }
    #[test]
    fn b64url_matches_known_values() {
        assert_eq!(b64url(&[0u8; 32]), "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
        assert_eq!(b64url(b"foobar"), "Zm9vYmFy");
        assert_eq!(b64url(b"fo"), "Zm8");
    }
}
