// CONTROL PLANE verify.rs (D5a-3b): Rule 52 on the request side. Every Desk request must be an Ed25519 envelope from the Desk's own key,
// audience desk-lookup, valid 60 s, never seen before, asking only for whitelist fields. Anything else = refused (fail closed). Pure: the clock is passed in.
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use serde_json::Value;
use std::{collections::HashMap, sync::Mutex};

pub const REQ_DOMAIN: &str = "anexo-desk-lookup-v1";
pub const ANS_DOMAIN: &str = "anexo-control-answer-v1";
pub const AUD: &str = "desk-lookup";
pub const EXPIRY: i64 = 60;
pub const SKEW: i64 = 5;
const CACHE_CAP: usize = 50_000;
const CONTRACT: &str = include_str!("../contract/DESK-LOOKUP-CONTRACT.json");

pub fn hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
pub fn unhex(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 || !s.bytes().all(|b| b.is_ascii_hexdigit()) { return None; }
    (0..s.len()).step_by(2).map(|i| u8::from_str_radix(&s[i..i + 2], 16).ok()).collect()
}
pub fn allowed() -> Vec<String> {
    serde_json::from_str::<Value>(CONTRACT).ok().and_then(|v| v["allowed_fields"].as_array().map(|a| a.iter().filter_map(|x| x.as_str().map(str::to_string)).collect())).unwrap_or_default()
}
pub fn valid_ref(s: &str) -> bool { (6..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-') }
pub(crate) fn valid_id(s: &str) -> bool { (8..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') }

#[derive(Debug, PartialEq)]
pub struct Req { pub request_id: String, pub company: String, pub fields: Vec<String> }

/// request_id replay cache: bounded; expired entries are dropped first; a full cache of live entries refuses (never forgets a live id).
/// `boot` closes the restart hole: the cache lives in memory, so a request signed BEFORE this process started is refused (it could be a replay of one already answered).
pub struct Seen(Mutex<HashMap<String, i64>>, i64);
impl Seen {
    pub fn new(boot: i64) -> Self { Seen(Mutex::new(HashMap::new()), boot) }
    pub(crate) fn boot(&self) -> i64 { self.1 }
    pub(crate) fn take(&self, id: &str, exp: i64, now: i64) -> bool {
        let mut m = self.0.lock().unwrap_or_else(|e| e.into_inner());
        if m.len() >= CACHE_CAP { m.retain(|_, e| *e > now); }
        if m.len() >= CACHE_CAP || m.contains_key(id) { return false; }
        m.insert(id.to_string(), exp); true
    }
}

/// The signature half shared by every Desk request: envelope shape, Ed25519 over REQ_DOMAIN + body, body parsed. Anything wrong = refused.
pub fn signed_body(env: &str, desk_pub_hex: &str) -> Result<Value, &'static str> {
    let e: Value = serde_json::from_str(env).map_err(|_| "envelope")?;
    let body = e["body"].as_str().ok_or("envelope")?;
    let sig = unhex(e["sig"].as_str().ok_or("envelope")?).ok_or("signature")?;
    let vk = unhex(desk_pub_hex).and_then(|b| <[u8; 32]>::try_from(b).ok()).and_then(|b| VerifyingKey::from_bytes(&b).ok()).ok_or("desk key")?;
    let sig = Signature::from_slice(&sig).map_err(|_| "signature")?;
    vk.verify(format!("{REQ_DOMAIN}\n{body}").as_bytes(), &sig).map_err(|_| "signature")?;
    serde_json::from_str(body).map_err(|_| "body")
}

pub fn verify(env: &str, desk_pub_hex: &str, seen: &Seen, now: i64) -> Result<Req, &'static str> {
    let b = signed_body(env, desk_pub_hex)?;
    if b["aud"].as_str() != Some(AUD) || b["method"].as_str() != Some("read") { return Err("audience"); }
    let (iat, exp) = (b["issued_at"].as_i64().ok_or("time")?, b["expires_at"].as_i64().ok_or("time")?);
    if iat < seen.1 { return Err("before_boot"); }
    if exp - iat > EXPIRY || exp <= iat || iat > now + SKEW || exp < now { return Err("expired"); }
    let rid = b["request_id"].as_str().filter(|s| valid_id(s)).ok_or("request_id")?;
    let emp = b["employee_id"].as_str().filter(|s| !s.is_empty() && s.len() <= 64).ok_or("employee")?; let _ = emp;
    let company = b["company_ref"].as_str().filter(|s| valid_ref(s)).ok_or("company")?;
    let reason = b["reason"].as_str().ok_or("reason")?.trim(); let n = reason.chars().count();
    if !(10..=300).contains(&n) || reason.contains('\n') || reason.contains('\r') { return Err("reason"); }
    let ok = allowed();
    let fields: Vec<String> = b["requested_fields"].as_array().ok_or("fields")?.iter().map(|x| x.as_str().map(str::to_string)).collect::<Option<_>>().ok_or("fields")?;
    let mut d = fields.clone(); d.sort(); d.dedup();
    if fields.is_empty() || d.len() != fields.len() || !fields.iter().all(|f| ok.contains(f)) { return Err("fields"); }
    if !seen.take(rid, exp, now) { return Err("replay"); }
    Ok(Req { request_id: rid.to_string(), company: company.to_string(), fields })
}

#[cfg(test)]
mod t {
    use super::*; use ed25519_dalek::{Signer, SigningKey}; use serde_json::json;
    fn key() -> (SigningKey, String) { let k = SigningKey::from_bytes(&[3u8; 32]); let p = hex(k.verifying_key().as_bytes()); (k, p) }
    fn env(k: &SigningKey, mut b: Value, domain: &str) -> String {
        for (key, v) in [("aud", json!("desk-lookup")), ("method", json!("read")), ("request_id", json!("11111111-2222-4333-8444-555555555555")), ("employee_id", json!("emp-1")), ("company_ref", json!("acme-1234")), ("reason", json!("customer says mail is missing")), ("requested_fields", json!(["service_state"])), ("issued_at", json!(1000)), ("expires_at", json!(1060))] { if b.get(key).is_none() { b[key] = v; } }
        let body = b.to_string(); json!({"kid": "x", "body": body, "sig": hex(&k.sign(format!("{domain}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    #[test] fn contract_copy_equals_the_gate_file() { assert_eq!(CONTRACT, include_str!("../../docs/claude/admin-desk/gates/DESK-LOOKUP-CONTRACT.json")); assert_eq!(allowed().len(), 18); }
    #[test] fn good_request_passes_once_and_replay_is_refused() {
        let (k, p) = key(); let s = Seen::new(0); let e = env(&k, json!({}), REQ_DOMAIN);
        let r = verify(&e, &p, &s, 1010).unwrap(); assert_eq!((r.company.as_str(), r.fields), ("acme-1234", vec!["service_state".to_string()]));
        assert_eq!(verify(&e, &p, &s, 1011), Err("replay"));
    }
    #[test] fn every_bad_request_fails_closed() {
        let (k, p) = key(); let other = SigningKey::from_bytes(&[4u8; 32]); let s = Seen::new(0);
        let bad = |b: Value| verify(&env(&k, b, REQ_DOMAIN), &p, &s, 1010);
        assert_eq!(verify(&env(&other, json!({}), REQ_DOMAIN), &p, &s, 1010), Err("signature"), "another key");
        assert_eq!(verify(&env(&k, json!({}), "anexo-desk-v1"), &p, &s, 1010), Err("signature"), "another domain");
        assert_eq!(bad(json!({"aud": "founder"})), Err("audience"));
        assert_eq!(bad(json!({"method": "write"})), Err("audience"));
        assert_eq!(bad(json!({"expires_at": 2000})), Err("expired"), "longer than 60 s");
        assert_eq!(verify(&env(&k, json!({"request_id": "aaaaaaaa-2222-4333-8444-555555555555"}), REQ_DOMAIN), &p, &s, 1100), Err("expired"), "old");
        assert_eq!(bad(json!({"issued_at": 1100, "expires_at": 1150, "request_id": "bbbbbbbb-2222-4333-8444-555555555555"})), Err("expired"), "from the future");
        assert_eq!(bad(json!({"requested_fields": ["amount"], "request_id": "cccccccc-2222-4333-8444-555555555555"})), Err("fields"));
        assert_eq!(bad(json!({"requested_fields": [], "request_id": "dddddddd-2222-4333-8444-555555555555"})), Err("fields"));
        assert_eq!(bad(json!({"requested_fields": ["service_state", "service_state"], "request_id": "eeeeeeee-2222-4333-8444-555555555555"})), Err("fields"));
        assert_eq!(bad(json!({"company_ref": "x'; drop", "request_id": "ffffffff-2222-4333-8444-555555555555"})), Err("company"));
        assert_eq!(bad(json!({"reason": "short", "request_id": "99999999-2222-4333-8444-555555555555"})), Err("reason"));
        assert_eq!(verify("not json", &p, &s, 1010), Err("envelope"));
        assert_eq!(verify(&env(&k, json!({}), REQ_DOMAIN), "zz", &s, 1010), Err("desk key"));
    }
    #[test] fn a_request_signed_before_the_restart_is_refused() {
        let (k, p) = key(); let s = Seen::new(1005); assert_eq!(verify(&env(&k, json!({}), REQ_DOMAIN), &p, &s, 1010), Err("before_boot"));
        let s0 = Seen::new(1000); assert!(verify(&env(&k, json!({}), REQ_DOMAIN), &p, &s0, 1010).is_ok());
    }
    #[test] fn replay_cache_is_bounded_and_forgets_only_expired() {
        let s = Seen::new(0); for i in 0..CACHE_CAP { assert!(s.take(&format!("id{i}"), 2000, 1000)); }
        assert!(!s.take("fresh", 2000, 1000), "full of live ids: refuse, never forget a live one");
        assert!(s.take("fresh", 3000, 2001), "expired ones are dropped");
    }
}
