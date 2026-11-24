// CONTROL PLANE consent.rs (phase 1m, card B13 step Z4b, BL-46, 24 Nov 2026): Rule 52 on the CONSENT door. Own audience "desk-consent".
// Three closed methods: push (a staff request goes DOWN to the customer's company), cancel (staff withdraw it), poll (the Desk asks what the customer answered).
// The Control Plane can NEVER decide: there is no decide method here and the database role has no right to the decide door (CP5.sql). Strict shapes, fail closed. Pure: the clock is passed in.
use crate::verify::{signed_body, valid_id, Seen, EXPIRY, SKEW};
use serde_json::Value;

pub const AUD_CONSENT: &str = "desk-consent";
pub const SCOPES: [&str; 3] = ["metadata", "headers", "content"];

#[derive(Debug, PartialEq)]
pub enum Call {
    Push { consent: String, company: String, case_ref: String, scope: String, reason: String },
    Cancel { consent: String },
    Poll { consents: Vec<String> },
}
#[derive(Debug, PartialEq)]
pub struct ConsentReq { pub request_id: String, pub call: Call }

pub fn uuid_ok(s: &str) -> bool {
    let p: Vec<&str> = s.split('-').collect();
    p.len() == 5 && [8, 4, 4, 4, 12].iter().zip(&p).all(|(n, x)| x.len() == *n) && s.bytes().all(|b| b == b'-' || b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}
fn case_ok(s: &str) -> bool { (4..=40).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-') }
fn only(b: &Value, keys: &[&str]) -> bool { b.as_object().map(|m| m.keys().all(|k| keys.contains(&k.as_str()))).unwrap_or(false) }

pub fn verify_consent(env: &str, desk_pub_hex: &str, seen: &Seen, now: i64) -> Result<ConsentReq, &'static str> {
    let b = signed_body(env, desk_pub_hex)?;
    if b["aud"].as_str() != Some(AUD_CONSENT) { return Err("audience"); }
    let method = b["method"].as_str().ok_or("audience")?;
    let (iat, exp) = (b["issued_at"].as_i64().ok_or("time")?, b["expires_at"].as_i64().ok_or("time")?);
    if iat < seen.boot() { return Err("before_boot"); }
    if exp - iat > EXPIRY || exp <= iat || iat > now + SKEW || exp < now { return Err("expired"); }
    let rid = b["request_id"].as_str().filter(|s| valid_id(s)).ok_or("request_id")?.to_string();
    b["employee_id"].as_str().filter(|s| !s.is_empty() && s.len() <= 64).ok_or("employee")?;
    let call = match method {
        "push" => {
            if !only(&b, &["aud", "method", "request_id", "employee_id", "issued_at", "expires_at", "consent", "company_ref", "case_ref", "scope", "reason"]) { return Err("field"); }
            let consent = b["consent"].as_str().filter(|s| uuid_ok(s)).ok_or("consent")?.to_string();
            let company = b["company_ref"].as_str().filter(|s| uuid_ok(s)).ok_or("company")?.to_string();
            let case_ref = b["case_ref"].as_str().filter(|s| case_ok(s)).ok_or("case")?.to_string();
            let scope = b["scope"].as_str().filter(|s| SCOPES.contains(s)).ok_or("scope")?.to_string();
            let reason = b["reason"].as_str().ok_or("reason")?.trim().to_string(); let n = reason.chars().count();
            if !(20..=300).contains(&n) || reason.contains('\n') || reason.contains('\r') { return Err("reason"); }
            Call::Push { consent, company, case_ref, scope, reason }
        }
        "cancel" => {
            if !only(&b, &["aud", "method", "request_id", "employee_id", "issued_at", "expires_at", "consent"]) { return Err("field"); }
            Call::Cancel { consent: b["consent"].as_str().filter(|s| uuid_ok(s)).ok_or("consent")?.to_string() }
        }
        "poll" => {
            if !only(&b, &["aud", "method", "request_id", "employee_id", "issued_at", "expires_at", "consents"]) { return Err("field"); }
            let a = b["consents"].as_array().ok_or("consents")?;
            if a.is_empty() || a.len() > 50 { return Err("consents"); }
            let mut v = Vec::new(); for x in a { v.push(x.as_str().filter(|s| uuid_ok(s)).ok_or("consents")?.to_string()); }
            Call::Poll { consents: v }
        }
        _ => return Err("audience"),
    };
    if !seen.take(&rid, exp, now) { return Err("replay"); }
    Ok(ConsentReq { request_id: rid, call })
}

#[cfg(test)]
mod t {
    use super::*; use crate::verify::{hex, REQ_DOMAIN}; use ed25519_dalek::{Signer, SigningKey}; use serde_json::json;
    const U1: &str = "aaaaaaaa-0000-4000-8000-000000000001"; const CO: &str = "bbbbbbbb-0000-4000-8000-000000000002";
    fn key() -> (SigningKey, String) { let k = SigningKey::from_bytes(&[3u8; 32]); let p = hex(k.verifying_key().as_bytes()); (k, p) }
    fn env(k: &SigningKey, mut b: Value, domain: &str) -> String {
        for (key, v) in [("aud", json!(AUD_CONSENT)), ("request_id", json!("11111111-2222-4333-8444-555555555555")), ("employee_id", json!("emp-1")), ("issued_at", json!(1000)), ("expires_at", json!(1060))] { if b.get(key).is_none() { b[key] = v; } }
        let body = b.to_string(); json!({"kid": "x", "body": body, "sig": hex(&k.sign(format!("{domain}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    fn push(extra: Value) -> Value { let mut b = json!({"method": "push", "consent": U1, "company_ref": CO, "case_ref": "CASE-0001", "scope": "metadata", "reason": "customer says mail is missing since noon"}); for (a, v) in extra.as_object().unwrap() { b[a] = v.clone(); } b }
    #[test] fn good_push_cancel_poll_pass_once() {
        let (k, p) = key(); let s = Seen::new(0);
        let r = verify_consent(&env(&k, push(json!({})), REQ_DOMAIN), &p, &s, 1010).unwrap();
        assert_eq!(r.call, Call::Push { consent: U1.into(), company: CO.into(), case_ref: "CASE-0001".into(), scope: "metadata".into(), reason: "customer says mail is missing since noon".into() });
        assert_eq!(verify_consent(&env(&k, push(json!({})), REQ_DOMAIN), &p, &s, 1011), Err("replay"));
        let c = verify_consent(&env(&k, json!({"method": "cancel", "consent": U1, "request_id": "22222222-2222-4333-8444-555555555555"}), REQ_DOMAIN), &p, &s, 1010).unwrap(); assert_eq!(c.call, Call::Cancel { consent: U1.into() });
        let q = verify_consent(&env(&k, json!({"method": "poll", "consents": [U1, CO], "request_id": "33333333-2222-4333-8444-555555555555"}), REQ_DOMAIN), &p, &s, 1010).unwrap(); assert_eq!(q.call, Call::Poll { consents: vec![U1.into(), CO.into()] });
    }
    #[test] fn there_is_no_way_to_decide_through_this_door() {
        let (k, p) = key(); let s = Seen::new(0);
        for (i, m) in ["decide", "approve", "revoke", "read", "write"].iter().enumerate() {
            let rid = format!("{:08x}-2222-4333-8444-555555555555", i + 100);
            assert_eq!(verify_consent(&env(&k, json!({"method": m, "consent": U1, "request_id": rid}), REQ_DOMAIN), &p, &s, 1010), Err("audience"), "method {m}");
        }
    }
    #[test] fn every_bad_request_fails_closed() {
        let (k, p) = key(); let other = SigningKey::from_bytes(&[4u8; 32]); let s = Seen::new(0);
        let rid = |n: u8| format!("{:08x}-2222-4333-8444-555555555555", n);
        assert_eq!(verify_consent(&env(&other, push(json!({})), REQ_DOMAIN), &p, &s, 1010), Err("signature"));
        assert_eq!(verify_consent(&env(&k, push(json!({})), "anexo-desk-v1"), &p, &s, 1010), Err("signature"));
        let bad = |n: u8, extra: Value| { let mut b = push(extra); b["request_id"] = json!(rid(n)); verify_consent(&env(&k, b, REQ_DOMAIN), &p, &s, 1010) };
        assert_eq!(bad(1, json!({"aud": "desk-census"})), Err("audience"), "a census request is not a consent request");
        assert_eq!(bad(2, json!({"aud": "desk-lookup"})), Err("audience"));
        assert_eq!(bad(3, json!({"expires_at": 2000})), Err("expired"));
        assert_eq!(bad(4, json!({"issued_at": 1100, "expires_at": 1150})), Err("expired"), "from the future");
        assert_eq!(bad(5, json!({"scope": "everything"})), Err("scope"));
        assert_eq!(bad(6, json!({"reason": "too short"})), Err("reason"));
        assert_eq!(bad(7, json!({"consent": "not-a-uuid"})), Err("consent"));
        assert_eq!(bad(8, json!({"company_ref": "BBBBBBBB-0000-4000-8000-000000000002"})), Err("company"), "upper case is not accepted");
        assert_eq!(bad(9, json!({"case_ref": "a b"})), Err("case"));
        assert_eq!(bad(10, json!({"surprise": 1})), Err("field"), "unknown field");
        assert_eq!(bad(11, json!({"reason": "twenty chars or more\nsecond line here"})), Err("reason"), "no line breaks");
        let mut c = json!({"method": "cancel", "consent": U1, "request_id": rid(12), "reason": "x"}); c["scope"] = json!("metadata");
        assert_eq!(verify_consent(&env(&k, c, REQ_DOMAIN), &p, &s, 1010), Err("field"), "cancel takes only the consent id");
        assert_eq!(verify_consent(&env(&k, json!({"method": "poll", "consents": [], "request_id": rid(13)}), REQ_DOMAIN), &p, &s, 1010), Err("consents"));
        let many: Vec<&str> = vec![U1; 51]; assert_eq!(verify_consent(&env(&k, json!({"method": "poll", "consents": many, "request_id": rid(14)}), REQ_DOMAIN), &p, &s, 1010), Err("consents"));
        assert_eq!(verify_consent("not json", &p, &s, 1010), Err("envelope"));
        let s2 = Seen::new(1005); assert_eq!(verify_consent(&env(&k, push(json!({})), REQ_DOMAIN), &p, &s2, 1010), Err("before_boot"));
    }
    #[test] fn the_other_doors_refuse_a_consent_request() {
        let (k, p) = key(); let s = Seen::new(0); let e = env(&k, push(json!({"request_id": "44444444-2222-4333-8444-555555555555"})), REQ_DOMAIN);
        assert_eq!(crate::census::verify_census(&e, &p, &s, 1010), Err("audience")); assert_eq!(crate::census::verify_deliv(&e, &p, &s, 1010), Err("audience")); assert_eq!(crate::verify::verify(&e, &p, &s, 1010), Err("audience"));
    }
}
