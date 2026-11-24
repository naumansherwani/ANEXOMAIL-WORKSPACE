// CONTROL PLANE tenant.rs (phase 1m, card B13, step T4e, 25 Nov 2026): Rule 52 on the TENANT-EXISTS door. Own audience "desk-tenant", one closed method "tenant", signed path /control/v1/tenant.
// The Desk asks: "is this company UUID real, and what is its display NAME?". The answer is exactly {exists, name} from the read-only database function cp.tenant_info (AD31, T4e).
// RULE 52 COMBO: S = the signed body covers audience + method + request id + path + times (RFC 9421 section 2.2.6 idea: the covered target) and is signed with the Desk's workload Ed25519 key (IETF WIMSE workload identity); a human passkey can never stand in for it.
// This door can only ASK. It cannot bind, grant or change anything. Strict shapes, fail closed, pure: the clock is passed in. Replay cache and boot time are the same as every other door.
use crate::verify::{signed_body, valid_id, Seen, EXPIRY, SKEW};
use serde_json::Value;

pub const AUD_TENANT: &str = "desk-tenant";
pub const SIGNED_PATH: &str = "/control/v1/tenant";

#[derive(Debug, PartialEq)]
pub struct TenantReq { pub request_id: String, pub tenant: String }

/// A tenant UUID exactly as the Desk writes it: lower case hex, 8-4-4-4-12, 36 characters, not the nil UUID.
pub fn uuid_ok(s: &str) -> bool {
    s.len() == 36 && s != "00000000-0000-0000-0000-000000000000"
        && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_digit() || (b'a'..=b'f').contains(&b) })
}
fn only(b: &Value, keys: &[&str]) -> bool { b.as_object().map(|m| m.len() == keys.len() && keys.iter().all(|k| m.contains_key(*k))).unwrap_or(false) }

pub fn verify_tenant(env: &str, desk_pub_hex: &str, seen: &Seen, now: i64) -> Result<TenantReq, &'static str> {
    let b = signed_body(env, desk_pub_hex)?;
    if b["aud"].as_str() != Some(AUD_TENANT) || b["method"].as_str() != Some("tenant") { return Err("audience"); }
    if !only(&b, &["aud", "method", "request_id", "employee_id", "issued_at", "expires_at", "path", "tenant"]) { return Err("field"); }
    if b["path"].as_str() != Some(SIGNED_PATH) { return Err("path"); }
    let (iat, exp) = (b["issued_at"].as_i64().ok_or("time")?, b["expires_at"].as_i64().ok_or("time")?);
    if iat < seen.boot() { return Err("before_boot"); }
    if exp - iat > EXPIRY || exp <= iat || iat > now + SKEW || exp < now { return Err("expired"); }
    let rid = b["request_id"].as_str().filter(|s| valid_id(s)).ok_or("request_id")?.to_string();
    b["employee_id"].as_str().filter(|s| !s.is_empty() && s.len() <= 64).ok_or("employee")?;
    let tenant = b["tenant"].as_str().filter(|s| uuid_ok(s)).ok_or("tenant")?.to_string();
    if !seen.take(&rid, exp, now) { return Err("replay"); }
    Ok(TenantReq { request_id: rid, tenant })
}

#[cfg(test)]
mod t {
    use super::*; use crate::verify::{hex, REQ_DOMAIN}; use ed25519_dalek::{Signer, SigningKey}; use serde_json::json;
    const T1: &str = "11111111-1111-4111-8111-111111111111";
    fn key() -> (SigningKey, String) { let k = SigningKey::from_bytes(&[3u8; 32]); let p = hex(k.verifying_key().as_bytes()); (k, p) }
    fn env(k: &SigningKey, extra: Value, domain: &str) -> String {
        let mut b = json!({"aud": AUD_TENANT, "method": "tenant", "request_id": "11111111-2222-4333-8444-555555555555", "employee_id": "emp-1", "issued_at": 1000, "expires_at": 1060, "path": SIGNED_PATH, "tenant": T1});
        for (a, v) in extra.as_object().unwrap() { b[a] = v.clone(); }
        let body = b.to_string(); json!({"kid": "x", "body": body, "sig": hex(&k.sign(format!("{domain}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    #[test] fn a_good_request_passes_once() {
        let (k, p) = key(); let s = Seen::new(0);
        assert_eq!(verify_tenant(&env(&k, json!({}), REQ_DOMAIN), &p, &s, 1010).unwrap(), TenantReq { request_id: "11111111-2222-4333-8444-555555555555".into(), tenant: T1.into() });
        assert_eq!(verify_tenant(&env(&k, json!({}), REQ_DOMAIN), &p, &s, 1011), Err("replay"));
    }
    #[test] fn every_bad_request_fails_closed() {
        let (k, p) = key(); let other = SigningKey::from_bytes(&[4u8; 32]); let s = Seen::new(0);
        let rid = |n: u8| format!("{:08x}-2222-4333-8444-555555555555", n);
        assert_eq!(verify_tenant(&env(&other, json!({}), REQ_DOMAIN), &p, &s, 1010), Err("signature"));
        assert_eq!(verify_tenant(&env(&k, json!({}), "anexo-desk-v1"), &p, &s, 1010), Err("signature"), "wrong signing domain");
        let bad = |n: u8, extra: Value| { let mut e = extra.clone(); e["request_id"] = json!(rid(n)); verify_tenant(&env(&k, e, REQ_DOMAIN), &p, &s, 1010) };
        assert_eq!(bad(1, json!({"aud": "desk-resolve"})), Err("audience"), "a resolve request is not a tenant request");
        assert_eq!(bad(2, json!({"aud": "desk-consent"})), Err("audience"));
        assert_eq!(bad(3, json!({"method": "bind"})), Err("audience"), "there is no bind method");
        assert_eq!(bad(4, json!({"expires_at": 2000})), Err("expired"));
        assert_eq!(bad(5, json!({"issued_at": 1100, "expires_at": 1150})), Err("expired"), "from the future");
        assert_eq!(bad(6, json!({"tenant": "11111111-1111-4111-8111-11111111111G"})), Err("tenant"), "not hex");
        assert_eq!(bad(7, json!({"tenant": "11111111-1111-4111-8111-11111111111A"})), Err("tenant"), "upper case is not accepted");
        assert_eq!(bad(8, json!({"tenant": "00000000-0000-0000-0000-000000000000"})), Err("tenant"), "the nil UUID is refused");
        assert_eq!(bad(9, json!({"tenant": "1111111111114111811111111111111111"})), Err("tenant"), "no dashes");
        assert_eq!(bad(10, json!({"tenant": 7})), Err("tenant"), "a string only");
        assert_eq!(bad(11, json!({"surprise": 1})), Err("field"), "unknown field");
        assert_eq!(bad(12, json!({"path": "/control/v1/resolve"})), Err("path"), "a request signed for another door is refused here");
        assert_eq!(bad(13, json!({"path": "/control/v1/tenant/"})), Err("path"), "exact path only");
        assert_eq!(verify_tenant("not json", &p, &s, 1010), Err("envelope"));
        let s2 = Seen::new(1005); assert_eq!(verify_tenant(&env(&k, json!({"request_id": rid(15)}), REQ_DOMAIN), &p, &s2, 1010), Err("before_boot"));
    }
    #[test] fn uuid_shapes() {
        assert!(uuid_ok(T1) && uuid_ok("abcdef01-2345-4678-9abc-def012345678"));
        assert!(!uuid_ok("") && !uuid_ok("x") && !uuid_ok(&T1.replace('-', "_")) && !uuid_ok(&format!("{T1}0")));
    }
    #[test] fn the_other_doors_refuse_a_tenant_request() {
        let (k, p) = key(); let s = Seen::new(0); let e = env(&k, json!({"request_id": "44444444-2222-4333-8444-555555555555"}), REQ_DOMAIN);
        assert_eq!(crate::census::verify_census(&e, &p, &s, 1010), Err("audience")); assert_eq!(crate::verify::verify(&e, &p, &s, 1010), Err("audience"));
        assert_eq!(crate::consent::verify_consent(&e, &p, &s, 1010), Err("audience")); assert_eq!(crate::resolve::verify_resolve(&e, &p, &s, 1010), Err("audience"));
    }
}
