// CONTROL PLANE census.rs (phase 1m-4, card B9 Customers and Plans, 23 Nov 2026): Rule 52 on the CENSUS request side. Own audience "desk-census" (a lookup request can never be replayed as a census or the reverse).
// The Desk's Ed25519 envelope, valid 60 s, never seen before, a reason, and ONE optional input: the seat promise of each package (counts only, closed key list). Anything else = refused (fail closed). Pure: the clock is passed in.
use crate::verify::{signed_body, valid_id, Seen, EXPIRY, SKEW};
use serde_json::{Map, Value};

pub const AUD_CENSUS: &str = "desk-census";
pub const PKGS: [&str; 6] = ["basic", "pro", "business", "business_pro", "business_premium", "business_max"];
const MAX_SEATS: i64 = 999_999;

#[derive(Debug, PartialEq)]
pub struct CensusReq { pub request_id: String, pub limits: Value }

pub const AUD_DELIV: &str = "desk-deliv";
/// Phase 1m-5 B6: the deliverability request. Own audience (a census request can never be replayed as this one), no input at all: a "limits" field is refused.
pub fn verify_deliv(env: &str, desk_pub_hex: &str, seen: &Seen, now: i64) -> Result<CensusReq, &'static str> { verify_inner(env, desk_pub_hex, seen, now, AUD_DELIV, false) }
pub fn verify_census(env: &str, desk_pub_hex: &str, seen: &Seen, now: i64) -> Result<CensusReq, &'static str> { verify_inner(env, desk_pub_hex, seen, now, AUD_CENSUS, true) }
fn verify_inner(env: &str, desk_pub_hex: &str, seen: &Seen, now: i64, aud: &str, with_limits: bool) -> Result<CensusReq, &'static str> {
    let b = signed_body(env, desk_pub_hex)?;
    if b["aud"].as_str() != Some(aud) || b["method"].as_str() != Some("read") { return Err("audience"); }
    let (iat, exp) = (b["issued_at"].as_i64().ok_or("time")?, b["expires_at"].as_i64().ok_or("time")?);
    if iat < seen.boot() { return Err("before_boot"); }
    if exp - iat > EXPIRY || exp <= iat || iat > now + SKEW || exp < now { return Err("expired"); }
    let rid = b["request_id"].as_str().filter(|s| valid_id(s)).ok_or("request_id")?;
    b["employee_id"].as_str().filter(|s| !s.is_empty() && s.len() <= 64).ok_or("employee")?;
    let reason = b["reason"].as_str().ok_or("reason")?.trim(); let n = reason.chars().count();
    if !(10..=300).contains(&n) || reason.contains('\n') || reason.contains('\r') { return Err("reason"); }
    let mut limits = Map::new();
    match b.get("limits") {
        None | Some(Value::Null) => {}
        Some(_) if !with_limits => return Err("limits"),
        Some(Value::Object(m)) => { for (k, v) in m { let n = v.as_i64().ok_or("limits")?; if !PKGS.contains(&k.as_str()) || !(0..=MAX_SEATS).contains(&n) { return Err("limits"); } limits.insert(k.clone(), Value::from(n)); } }
        _ => return Err("limits"),
    }
    if !seen.take(rid, exp, now) { return Err("replay"); }
    Ok(CensusReq { request_id: rid.to_string(), limits: Value::Object(limits) })
}

#[cfg(test)]
mod t {
    use super::*; use crate::verify::{hex, REQ_DOMAIN}; use ed25519_dalek::{Signer, SigningKey}; use serde_json::json;
    fn key() -> (SigningKey, String) { let k = SigningKey::from_bytes(&[3u8; 32]); let p = hex(k.verifying_key().as_bytes()); (k, p) }
    pub fn env(k: &SigningKey, mut b: Value, domain: &str) -> String {
        for (key, v) in [("aud", json!(AUD_CENSUS)), ("method", json!("read")), ("request_id", json!("11111111-2222-4333-8444-555555555555")), ("employee_id", json!("emp-1")), ("reason", json!("customers and plans board opened")), ("issued_at", json!(1000)), ("expires_at", json!(1060))] {
            if b.get(key).is_none() { b[key] = v; }
        }
        let body = b.to_string(); json!({"kid": "x", "body": body, "sig": hex(&k.sign(format!("{domain}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    #[test] fn good_census_request_passes_once_and_keeps_the_limits() {
        let (k, p) = key(); let s = Seen::new(0); let e = env(&k, json!({"limits": {"pro": 20, "basic": 5}}), REQ_DOMAIN);
        let r = verify_census(&e, &p, &s, 1010).unwrap(); assert_eq!(r.limits, json!({"basic": 5, "pro": 20}));
        assert_eq!(verify_census(&e, &p, &s, 1011), Err("replay"));
        let none = verify_census(&env(&k, json!({"request_id": "aaaaaaaa-2222-4333-8444-555555555555"}), REQ_DOMAIN), &p, &s, 1010).unwrap(); assert_eq!(none.limits, json!({}));
    }
    #[test] fn every_bad_census_request_fails_closed() {
        let (k, p) = key(); let other = SigningKey::from_bytes(&[4u8; 32]); let s = Seen::new(0);
        let rid = |n: u8| format!("{:08x}-2222-4333-8444-555555555555", n);
        assert_eq!(verify_census(&env(&other, json!({}), REQ_DOMAIN), &p, &s, 1010), Err("signature"));
        assert_eq!(verify_census(&env(&k, json!({}), "anexo-desk-v1"), &p, &s, 1010), Err("signature"));
        let bad = |n: u8, b: Value| { let mut b = b; b["request_id"] = json!(rid(n)); verify_census(&env(&k, b, REQ_DOMAIN), &p, &s, 1010) };
        assert_eq!(bad(1, json!({"aud": "desk-lookup"})), Err("audience"), "a lookup request is not a census request");
        assert_eq!(bad(2, json!({"method": "write"})), Err("audience"));
        assert_eq!(bad(3, json!({"expires_at": 2000})), Err("expired"));
        assert_eq!(bad(4, json!({"issued_at": 1100, "expires_at": 1150})), Err("expired"), "from the future");
        assert_eq!(bad(5, json!({"reason": "short"})), Err("reason"));
        assert_eq!(bad(6, json!({"limits": {"evil": 1}})), Err("limits"), "unknown package");
        assert_eq!(bad(7, json!({"limits": {"pro": -1}})), Err("limits"));
        assert_eq!(bad(8, json!({"limits": {"pro": 1000000}})), Err("limits"));
        assert_eq!(bad(9, json!({"limits": {"pro": "5"}})), Err("limits"), "a string is not a number");
        assert_eq!(bad(10, json!({"limits": [1]})), Err("limits"));
        assert_eq!(verify_census("not json", &p, &s, 1010), Err("envelope"));
        let s2 = Seen::new(1005); assert_eq!(verify_census(&env(&k, json!({}), REQ_DOMAIN), &p, &s2, 1010), Err("before_boot"));
    }
    #[test] fn deliverability_request_has_its_own_audience_and_takes_no_input() {
        let (k, p) = key(); let s = Seen::new(0);
        let d = |rid: &str, extra: Value| { let mut b = json!({"aud": AUD_DELIV, "request_id": rid}); for (a, v) in extra.as_object().unwrap() { b[a] = v.clone(); } env(&k, b, REQ_DOMAIN) };
        assert!(verify_deliv(&d("aaaaaaaa-2222-4333-8444-555555555555", json!({})), &p, &s, 1010).is_ok());
        assert_eq!(verify_deliv(&d("bbbbbbbb-2222-4333-8444-555555555555", json!({"limits": {"pro": 5}})), &p, &s, 1010), Err("limits"), "no input allowed");
        assert_eq!(verify_deliv(&env(&k, json!({"request_id": "cccccccc-2222-4333-8444-555555555555"}), REQ_DOMAIN), &p, &s, 1010), Err("audience"), "a census request is not a deliverability request");
        assert_eq!(verify_census(&d("dddddddd-2222-4333-8444-555555555555", json!({})), &p, &s, 1010), Err("audience"), "and the other way round");
    }
}
