// CONTROL PLANE resolve.rs (phase 1m, card B13 step T3b, BL-46, 24 Nov 2026): Rule 52 on the SENDER-RESOLVE door. Own audience "desk-resolve", one closed method "resolve".
// The Desk asks: "this sender (domain, local part, did the mail authenticate as that domain?): which company is it?". The answer is ONE word and (only for "resolved") a tenant UUID, decided by the database function cp.resolve_sender (AD31).
// This door can only ASK. It cannot bind a case, grant access or open consent: the Desk decides what to do with the word. Strict shapes, fail closed, pure: the clock is passed in. Replay cache and boot time are the same as every other door.
use crate::verify::{signed_body, valid_id, Seen, EXPIRY, SKEW};
use serde_json::Value;

pub const AUD_RESOLVE: &str = "desk-resolve";
/// RFC 9421 section 2.2.6 idea (a signature covers the request target): the signed body carries the path it is meant for, so a signed resolve request cannot be replayed to another door even if an audience were ever reused.
pub const SIGNED_PATH: &str = "/control/v1/resolve";

#[derive(Debug, PartialEq)]
pub struct ResolveReq { pub request_id: String, pub domain: String, pub local: String, pub aligned: bool }

/// A mail domain exactly as the Desk writes it: lower case ASCII (punycode for international names), dot separated labels of 1..63 characters, no label starts or ends with a hyphen, at least two labels, at most 253 characters.
pub fn domain_ok(s: &str) -> bool {
    if s.len() < 3 || s.len() > 253 || !s.contains('.') { return false; }
    s.split('.').all(|l| (1..=63).contains(&l.len()) && !l.starts_with('-') && !l.ends_with('-') && l.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-'))
}
/// The local part of an address as the Desk writes it: lower case, 1..64 characters, letters, digits and . _ + - only (no spaces, no quotes, no @).
pub fn local_ok(s: &str) -> bool { (1..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || matches!(b, b'.' | b'_' | b'+' | b'-')) }
fn only(b: &Value, keys: &[&str]) -> bool { b.as_object().map(|m| m.len() == keys.len() && keys.iter().all(|k| m.contains_key(*k))).unwrap_or(false) }

pub fn verify_resolve(env: &str, desk_pub_hex: &str, seen: &Seen, now: i64) -> Result<ResolveReq, &'static str> {
    let b = signed_body(env, desk_pub_hex)?;
    if b["aud"].as_str() != Some(AUD_RESOLVE) || b["method"].as_str() != Some("resolve") { return Err("audience"); }
    if !only(&b, &["aud", "method", "request_id", "employee_id", "issued_at", "expires_at", "path", "domain", "local", "aligned"]) { return Err("field"); }
    if b["path"].as_str() != Some(SIGNED_PATH) { return Err("path"); }
    let (iat, exp) = (b["issued_at"].as_i64().ok_or("time")?, b["expires_at"].as_i64().ok_or("time")?);
    if iat < seen.boot() { return Err("before_boot"); }
    if exp - iat > EXPIRY || exp <= iat || iat > now + SKEW || exp < now { return Err("expired"); }
    let rid = b["request_id"].as_str().filter(|s| valid_id(s)).ok_or("request_id")?.to_string();
    b["employee_id"].as_str().filter(|s| !s.is_empty() && s.len() <= 64).ok_or("employee")?;
    let domain = b["domain"].as_str().filter(|s| domain_ok(s)).ok_or("domain")?.to_string();
    let local = b["local"].as_str().filter(|s| local_ok(s)).ok_or("local")?.to_string();
    let aligned = b["aligned"].as_bool().ok_or("aligned")?;
    if !seen.take(&rid, exp, now) { return Err("replay"); }
    Ok(ResolveReq { request_id: rid, domain, local, aligned })
}

#[cfg(test)]
mod t {
    use super::*; use crate::verify::{hex, REQ_DOMAIN}; use ed25519_dalek::{Signer, SigningKey}; use serde_json::json;
    fn key() -> (SigningKey, String) { let k = SigningKey::from_bytes(&[3u8; 32]); let p = hex(k.verifying_key().as_bytes()); (k, p) }
    fn env(k: &SigningKey, mut b: Value, domain: &str) -> String {
        for (key, v) in [("aud", json!(AUD_RESOLVE)), ("method", json!("resolve")), ("request_id", json!("11111111-2222-4333-8444-555555555555")), ("employee_id", json!("emp-1")), ("issued_at", json!(1000)), ("expires_at", json!(1060)), ("path", json!(SIGNED_PATH)), ("domain", json!("acme.example")), ("local", json!("ann")), ("aligned", json!(true))] { if b.get(key).is_none() { b[key] = v; } }
        let body = b.to_string(); json!({"kid": "x", "body": body, "sig": hex(&k.sign(format!("{domain}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    #[test] fn a_good_request_passes_once() {
        let (k, p) = key(); let s = Seen::new(0);
        let r = verify_resolve(&env(&k, json!({}), REQ_DOMAIN), &p, &s, 1010).unwrap();
        assert_eq!(r, ResolveReq { request_id: "11111111-2222-4333-8444-555555555555".into(), domain: "acme.example".into(), local: "ann".into(), aligned: true });
        assert_eq!(verify_resolve(&env(&k, json!({}), REQ_DOMAIN), &p, &s, 1011), Err("replay"));
    }
    #[test] fn every_bad_request_fails_closed() {
        let (k, p) = key(); let other = SigningKey::from_bytes(&[4u8; 32]); let s = Seen::new(0);
        let rid = |n: u8| format!("{:08x}-2222-4333-8444-555555555555", n);
        assert_eq!(verify_resolve(&env(&other, json!({}), REQ_DOMAIN), &p, &s, 1010), Err("signature"));
        assert_eq!(verify_resolve(&env(&k, json!({}), "anexo-desk-v1"), &p, &s, 1010), Err("signature"));
        let bad = |n: u8, extra: Value| { let mut b = json!({}); b["request_id"] = json!(rid(n)); for (a, v) in extra.as_object().unwrap() { b[a] = v.clone(); } verify_resolve(&env(&k, b, REQ_DOMAIN), &p, &s, 1010) };
        assert_eq!(bad(1, json!({"aud": "desk-consent"})), Err("audience"), "a consent request is not a resolve request");
        assert_eq!(bad(2, json!({"aud": "desk-lookup"})), Err("audience"));
        assert_eq!(bad(3, json!({"method": "bind"})), Err("audience"), "there is no bind method");
        assert_eq!(bad(4, json!({"expires_at": 2000})), Err("expired"));
        assert_eq!(bad(5, json!({"issued_at": 1100, "expires_at": 1150})), Err("expired"), "from the future");
        assert_eq!(bad(6, json!({"domain": "Acme.Example"})), Err("domain"), "upper case is not accepted");
        assert_eq!(bad(7, json!({"domain": "localhost"})), Err("domain"), "one label is not a mail domain");
        assert_eq!(bad(8, json!({"domain": "a_b.example"})), Err("domain"));
        assert_eq!(bad(9, json!({"domain": "-a.example"})), Err("domain"));
        assert_eq!(bad(10, json!({"local": "ann@x"})), Err("local"), "no @ in the local part");
        assert_eq!(bad(11, json!({"local": ""})), Err("local"));
        assert_eq!(bad(12, json!({"local": "a b"})), Err("local"));
        assert_eq!(bad(13, json!({"aligned": "yes"})), Err("aligned"), "a real boolean only");
        assert_eq!(bad(14, json!({"surprise": 1})), Err("field"), "unknown field");
        assert_eq!(bad(16, json!({"path": "/control/v1/consent"})), Err("path"), "a request signed for another door is refused here (RFC 9421 covered target)");
        assert_eq!(bad(17, json!({"path": "/control/v1/resolve/"})), Err("path"), "exact path only");
        assert_eq!(verify_resolve("not json", &p, &s, 1010), Err("envelope"));
        let s2 = Seen::new(1005); assert_eq!(verify_resolve(&env(&k, json!({"request_id": rid(15)}), REQ_DOMAIN), &p, &s2, 1010), Err("before_boot"));
    }
    #[test] fn domain_and_local_shapes() {
        assert!(domain_ok("acme.example") && domain_ok("mail.acme-co.example") && domain_ok("xn--bcher-kva.example"));
        assert!(!domain_ok("") && !domain_ok("a.") && !domain_ok(".a.b") && !domain_ok("a..b") && !domain_ok("a b.example") && !domain_ok(&format!("{}.example", "a".repeat(64))));
        assert!(local_ok("ann") && local_ok("a.b+tag_1-x") && !local_ok("Ann") && !local_ok("a\"b") && !local_ok(&"a".repeat(65)));
    }
    #[test] fn the_other_doors_refuse_a_resolve_request() {
        let (k, p) = key(); let s = Seen::new(0); let e = env(&k, json!({"request_id": "44444444-2222-4333-8444-555555555555"}), REQ_DOMAIN);
        assert_eq!(crate::census::verify_census(&e, &p, &s, 1010), Err("audience")); assert_eq!(crate::census::verify_deliv(&e, &p, &s, 1010), Err("audience")); assert_eq!(crate::verify::verify(&e, &p, &s, 1010), Err("audience"));
        assert_eq!(crate::consent::verify_consent(&e, &p, &s, 1010), Err("audience"));
    }
}
