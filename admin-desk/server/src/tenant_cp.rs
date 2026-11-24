// ANEXOMAIL ADMIN DESK tenant_cp.rs (BL-46 B13 step T4e, 25 Nov 2026): the Desk's CLIENT of the Control Plane "tenant exists" method (SQL AD31 cp.tenant_info). Rust + Tokio, HTTP/3 over the shared Plane (TLS 1.3 AES-256-GCM, X25519MLKEM768).
// RULE 52 COMBO: S = the request is signed with the Desk's WORKLOAD Ed25519 key (IETF WIMSE workload identity, never a human passkey) and covers audience desk-tenant, method tenant, request id, path /control/v1/tenant and a 60 s window (RFC 9421 covered-target idea);
// the ANSWER must be signed by the Control Plane's own key, kind "tenant", same request id, fresh 15 s, not older than the request, closed shape {exists, name}. M = no mail path. L = nothing is logged by this file; the company name never reaches the ledger.
// Fail closed: every fault = Reject::Unavailable (the Desk then says it cannot confirm the company, it never guesses a name). Bad input = Reject::Refused before anything leaves the Desk.
use crate::lookup::{ANS_DOMAIN, EXPIRY, FRESH, REQ_DOMAIN};
use crate::sign::{unhex, Signer};
use serde_json::{json, Value};
pub use crate::consent_cp::Reject;

pub const AUD_TENANT: &str = "desk-tenant";
pub const TENANT_PATH: &str = "/control/v1/tenant";

#[derive(Debug, PartialEq, Clone)]
pub enum Tenant { Exists(String), Missing }

/// Same shape as the Control Plane door (control-plane/src/tenant.rs): lower case hex 8-4-4-4-12, not the nil UUID.
pub fn uuid_ok(s: &str) -> bool {
    s.len() == 36 && s != "00000000-0000-0000-0000-000000000000"
        && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_digit() || (b'a'..=b'f').contains(&b) })
}

/// Read one verified answer: exactly {exists, name}; exists true needs a name text (at most 120 characters, no control characters); exists false needs name null.
pub fn read(r: &Value) -> Result<Tenant, ()> {
    let m = r.as_object().ok_or(())?;
    if m.len() != 2 || !m.contains_key("exists") || !m.contains_key("name") { return Err(()); }
    match (r["exists"].as_bool(), &r["name"]) {
        (Some(true), Value::String(n)) if n.chars().count() <= 120 && !n.chars().any(|c| c.is_control()) => Ok(Tenant::Exists(n.clone())),
        (Some(false), Value::Null) => Ok(Tenant::Missing),
        _ => Err(()),
    }
}

pub fn build_tenant(s: &Signer, rid: &str, employee: &str, tenant: &str, now: i64) -> String {
    let body = json!({"aud": AUD_TENANT, "method": "tenant", "request_id": rid, "employee_id": employee, "path": TENANT_PATH, "tenant": tenant, "issued_at": now, "expires_at": now + EXPIRY}).to_string();
    let sig = s.sign_raw(format!("{REQ_DOMAIN}\n{body}").as_bytes());
    json!({"kid": s.kid(), "body": body, "sig": sig}).to_string()
}

/// Verify the Control Plane answer to ONE tenant request. Refused (the database said no) is its own outcome; every other fault is Unavailable.
pub fn accept_tenant(env: &str, cp_pub_hex: &str, request_id: &str, issued: i64, now: i64) -> Result<Tenant, Reject> {
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};
    let e: Value = serde_json::from_str(env).map_err(|_| Reject::Unavailable)?;
    let body = e["body"].as_str().ok_or(Reject::Unavailable)?;
    let sig = unhex(e["sig"].as_str().ok_or(Reject::Unavailable)?).ok_or(Reject::Unavailable)?;
    let vk = unhex(cp_pub_hex).and_then(|b| <[u8; 32]>::try_from(b).ok()).and_then(|b| VerifyingKey::from_bytes(&b).ok()).ok_or(Reject::Unavailable)?;
    let sig = Signature::from_slice(&sig).map_err(|_| Reject::Unavailable)?;
    vk.verify(format!("{ANS_DOMAIN}\n{body}").as_bytes(), &sig).map_err(|_| Reject::Unavailable)?;
    let b: Value = serde_json::from_str(body).map_err(|_| Reject::Unavailable)?;
    if b["kind"].as_str() != Some("tenant") || b["request_id"].as_str() != Some(request_id) { return Err(Reject::Unavailable); }
    let at = b["answered_at"].as_i64().ok_or(Reject::Unavailable)?;
    if at > now + 5 || now - at > FRESH || at < issued - 2 { return Err(Reject::Unavailable); }
    match b["refused"].as_bool() { Some(true) => return Err(Reject::Refused), Some(false) => {}, None => return Err(Reject::Unavailable) }
    read(&b["result"]).map_err(|_| Reject::Unavailable)
}

/// The whole call: validate, sign, send over HTTP/3, verify. Bad input = Refused before anything leaves the Desk. Never cached: a deleted company must show at once.
pub(crate) async fn tenant_info(p: &crate::lookup::Plane, s: &Signer, cp_pub_hex: &str, employee: &str, tenant: &str, now: i64) -> Result<Tenant, Reject> {
    if !uuid_ok(tenant) || employee.is_empty() || employee.len() > 64 { return Err(Reject::Refused); }
    let rid = crate::lookup::uuid4();
    let env = build_tenant(s, &rid, employee, tenant, now);
    let ans = p.ask_path(TENANT_PATH, &env).await.ok_or(Reject::Unavailable)?;
    accept_tenant(&ans, cp_pub_hex, &rid, now, crate::signed::now_secs())
}

/// The staff doors call this: one signed question with the live Desk key and the pinned Control Plane key. Desk key missing or Control Plane not configured = Unavailable (fail closed).
pub(crate) async fn ask(employee: &str, tenant: &str) -> Result<Tenant, Reject> {
    let Some(s) = crate::signed::signer() else { return Err(Reject::Unavailable) };
    let p = crate::lookup::plane(); if matches!(p, crate::lookup::Plane::Off) { return Err(Reject::Unavailable); }
    tenant_info(&p, s, &crate::lookup::cp_pub(), employee, tenant, crate::signed::now_secs()).await
}

/// `anexomail-desk tenant-selftest`: the real end-to-end proof on his server (no login): Desk key -> HTTP/3 -> Control Plane -> read-only function cp.tenant_info -> signed answer -> Desk verifies.
/// Proves: a random UUID = Missing; the SAME request again is refused (replay); the answer checked against a WRONG key is refused; the nil UUID never leaves the Desk.
pub async fn selftest() -> Result<String, String> {
    crate::signed::init();
    let Some(s) = crate::signed::signer() else { return Err("Desk signing key not loaded".into()) };
    let p = crate::lookup::plane(); if matches!(p, crate::lookup::Plane::Off) { return Err("DESK_CONTROL_PLANE_ADDR / _HOST are not set".into()); }
    let key = crate::lookup::cp_pub(); let now = crate::signed::now_secs();
    let random = crate::lookup::uuid4();
    match tenant_info(&p, s, &key, "selftest", &random, now).await { Ok(Tenant::Missing) => {}, Ok(v) => return Err(format!("a random UUID answered {v:?}")), Err(e) => return Err(format!("probe failed: {e:?}")) }
    let rid = crate::lookup::uuid4(); let env = build_tenant(s, &rid, "selftest", &random, now);
    let ans = p.ask_path(TENANT_PATH, &env).await.ok_or("no answer over HTTP/3 (Control Plane down, certificate not trusted, or request refused)")?;
    accept_tenant(&ans, &key, &rid, now, crate::signed::now_secs()).map_err(|e| format!("answer not accepted: {e:?}"))?;
    if p.ask_path(TENANT_PATH, &env).await.is_some() { return Err("REPLAY WAS ANSWERED (must be refused)".into()); }
    if accept_tenant(&ans, &crate::sign::hex(&[9u8; 32]), &rid, now, crate::signed::now_secs()).is_ok() { return Err("answer accepted under a wrong key".into()); }
    if tenant_info(&p, s, &key, "selftest", "00000000-0000-0000-0000-000000000000", now).await != Err(Reject::Refused) { return Err("the nil UUID was not refused inside the Desk".into()); }
    Ok("TENANT SELFTEST OK: signed answer verified (unknown company = missing), replay refused, wrong key refused, nil UUID never leaves the Desk".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    const T: &str = "3f2b8c1e-5a4d-4e7a-9c1b-0a1b2c3d4e5f";
    #[test] fn uuid_shapes() { assert!(uuid_ok(T)); assert!(!uuid_ok("")); assert!(!uuid_ok("00000000-0000-0000-0000-000000000000")); assert!(!uuid_ok(&T.to_uppercase())); assert!(!uuid_ok(&T.replace('-', ""))); }
    #[test] fn the_closed_answer_shape() {
        assert_eq!(read(&json!({"exists": true, "name": "Acme Ltd"})), Ok(Tenant::Exists("Acme Ltd".into())));
        assert_eq!(read(&json!({"exists": false, "name": null})), Ok(Tenant::Missing));
        assert!(read(&json!({"exists": true, "name": null})).is_err(), "a real company has a name text");
        assert!(read(&json!({"exists": false, "name": "Acme"})).is_err(), "a missing company has no name");
        assert!(read(&json!({"exists": "yes", "name": "Acme"})).is_err());
        assert!(read(&json!({"exists": true, "name": "Ac\u{7}me"})).is_err(), "control characters are refused");
        assert!(read(&json!({"exists": true, "name": "x".repeat(121)})).is_err(), "over 120 characters is refused");
        assert!(read(&json!({"exists": true, "name": "A", "extra": 1})).is_err(), "unknown field");
        assert!(read(&json!({"exists": true})).is_err());
        assert!(read(&json!("text")).is_err());
    }
    fn signed_answer(cp: &ed25519_dalek::SigningKey, kind: &str, rid: &str, at: i64, refused: bool, result: Value) -> String {
        use ed25519_dalek::Signer as _;
        let body = json!({"kind": kind, "request_id": rid, "answered_at": at, "result": result, "refused": refused}).to_string();
        json!({"kid": "cp", "body": body, "sig": crate::sign::hex(&cp.sign(format!("{ANS_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    #[test] fn answers_are_accepted_only_when_signed_fresh_and_for_this_request() {
        let cp = ed25519_dalek::SigningKey::from_bytes(&[7u8; 32]); let pubhex = crate::sign::hex(cp.verifying_key().as_bytes());
        let good = json!({"exists": true, "name": "Acme Ltd"});
        assert_eq!(accept_tenant(&signed_answer(&cp, "tenant", "r1", 1000, false, good.clone()), &pubhex, "r1", 1000, 1005), Ok(Tenant::Exists("Acme Ltd".into())));
        assert_eq!(accept_tenant(&signed_answer(&cp, "tenant", "r2", 1000, false, good.clone()), &pubhex, "r1", 1000, 1005), Err(Reject::Unavailable), "another request's answer");
        assert_eq!(accept_tenant(&signed_answer(&cp, "resolve", "r1", 1000, false, good.clone()), &pubhex, "r1", 1000, 1005), Err(Reject::Unavailable), "another kind of answer");
        assert_eq!(accept_tenant(&signed_answer(&cp, "tenant", "r1", 1000, false, good.clone()), &pubhex, "r1", 1000, 1100), Err(Reject::Unavailable), "stale");
        assert_eq!(accept_tenant(&signed_answer(&cp, "tenant", "r1", 1000, false, good.clone()), &crate::sign::hex(&[9u8; 32]), "r1", 1000, 1005), Err(Reject::Unavailable), "wrong key");
        assert_eq!(accept_tenant(&signed_answer(&cp, "tenant", "r1", 1000, true, Value::Null), &pubhex, "r1", 1000, 1005), Err(Reject::Refused));
        assert_eq!(accept_tenant(&signed_answer(&cp, "tenant", "r1", 1000, false, json!({"exists": false, "name": null})), &pubhex, "r1", 1000, 1005), Ok(Tenant::Missing));
        assert_eq!(accept_tenant("not json", &pubhex, "r1", 1000, 1005), Err(Reject::Unavailable));
    }
    #[tokio::test] async fn bad_input_never_leaves_the_desk() {
        let p = crate::lookup::Plane::Off; let s = crate::sign::Signer::from_seed_hex(&"07".repeat(32)).unwrap();
        assert_eq!(tenant_info(&p, &s, "00", "e", "not-a-uuid", 1000).await, Err(Reject::Refused));
        assert_eq!(tenant_info(&p, &s, "00", "e", "00000000-0000-0000-0000-000000000000", 1000).await, Err(Reject::Refused));
        assert_eq!(tenant_info(&p, &s, "00", "", T, 1000).await, Err(Reject::Refused));
        assert_eq!(tenant_info(&p, &s, "00", "e", T, 1000).await, Err(Reject::Unavailable), "Plane off = no answer = unavailable");
    }
}
