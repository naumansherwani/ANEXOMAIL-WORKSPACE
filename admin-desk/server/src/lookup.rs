// ANEXOMAIL ADMIN DESK lookup.rs (D5a-3, 22 Nov 2026): the ONE door by which an employee asks his Control Plane about ONE company.
// Rust + Tokio + axum, behind signed::guard (Rule 52). Order is fixed: 1) check the input, 2) the database writes the audit line FIRST (AD4 fadm_lookup_begin,
// which also runs the permission check and the burst breaker), 3) a signed read-only request goes out (Ed25519, audience desk-lookup, 60 s expiry),
// 4) the answer is verified (its own key, same request id, fresh) and cut down to the contract whitelist, 5) the database closes the audit line.
// FAIL CLOSED: no address, no key, bad signature, stale, wrong id = "data_unavailable"; an old answer is never shown and nothing is stored here.
// Desk-only: no founder or awam code. The fields allowed come from gates/DESK-LOOKUP-CONTRACT.json (read at build time, one source of truth).
use crate::bridge::owner;
use crate::door::{lit, rows};
use crate::sign::{hex, unhex, Signer};
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::{json, Map, Value};

const CONTRACT: &str = include_str!("../../gates/DESK-LOOKUP-CONTRACT.json");
pub const AUD: &str = "desk-lookup";
pub const EXPIRY: i64 = 60;
const REQ_DOMAIN: &str = "anexo-desk-lookup-v1";
const ANS_DOMAIN: &str = "anexo-control-answer-v1";

pub fn allowed() -> Vec<String> {
    serde_json::from_str::<Value>(CONTRACT).ok().and_then(|v| v["allowed_fields"].as_array().map(|a| a.iter().filter_map(|x| x.as_str().map(str::to_string)).collect())).unwrap_or_default()
}
pub fn valid_ref(s: &str) -> bool { (6..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-') }
pub fn valid_reason(s: &str) -> bool { let t = s.trim(); let n = t.chars().count(); (10..=300).contains(&n) && !t.contains('\n') && !t.contains('\r') }
/// Requested fields: non-empty, no duplicates, every one on the whitelist.
pub fn valid_fields(f: &[String]) -> bool {
    let ok = allowed(); !f.is_empty() && f.len() <= ok.len() && f.iter().all(|x| ok.contains(x)) && { let mut s = f.to_vec(); s.sort(); s.dedup(); s.len() == f.len() }
}
fn uuid4() -> String {
    use argon2::password_hash::rand_core::{OsRng, RngCore};
    let mut b = [0u8; 16]; OsRng.fill_bytes(&mut b); b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80;
    let h = hex(&b); format!("{}-{}-{}-{}-{}", &h[0..8], &h[8..12], &h[12..16], &h[16..20], &h[20..32])
}

/// The signed read-only request envelope: {"kid","body","sig"}; the body travels as a string so the exact signed bytes arrive.
pub fn build_request(s: &Signer, request_id: &str, employee: &str, company: &str, reason: &str, fields: &[String], now: i64) -> String {
    let body = json!({"aud": AUD, "method": "read", "request_id": request_id, "employee_id": employee, "company_ref": company, "reason": reason.trim(), "requested_fields": fields, "issued_at": now, "expires_at": now + EXPIRY}).to_string();
    let sig = s.sign_raw(format!("{REQ_DOMAIN}\n{body}").as_bytes());
    json!({"kid": s.kid(), "body": body, "sig": sig}).to_string()
}

#[derive(Debug, PartialEq)]
pub enum Reject { Unavailable, Refused }
/// Verify the Control Plane answer and keep ONLY the requested whitelist fields. Anything wrong = Unavailable (fail closed).
pub fn accept(env: &str, cp_pub_hex: &str, request_id: &str, company: &str, requested: &[String], now: i64) -> Result<Map<String, Value>, Reject> {
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};
    let e: Value = serde_json::from_str(env).map_err(|_| Reject::Unavailable)?;
    let body = e["body"].as_str().ok_or(Reject::Unavailable)?;
    let sig = unhex(e["sig"].as_str().ok_or(Reject::Unavailable)?).ok_or(Reject::Unavailable)?;
    let vk = unhex(cp_pub_hex).and_then(|b| <[u8; 32]>::try_from(b).ok()).and_then(|b| VerifyingKey::from_bytes(&b).ok()).ok_or(Reject::Unavailable)?;
    let sig = Signature::from_slice(&sig).map_err(|_| Reject::Unavailable)?;
    vk.verify(format!("{ANS_DOMAIN}\n{body}").as_bytes(), &sig).map_err(|_| Reject::Unavailable)?;
    let b: Value = serde_json::from_str(body).map_err(|_| Reject::Unavailable)?;
    if b["request_id"].as_str() != Some(request_id) || b["company_ref"].as_str() != Some(company) { return Err(Reject::Unavailable); }
    let at = b["answered_at"].as_i64().ok_or(Reject::Unavailable)?;
    if at > now + 5 || now - at > EXPIRY { return Err(Reject::Unavailable); }
    if b["refused"].as_bool() == Some(true) { return Err(Reject::Refused); }
    let ok = allowed(); let got = b["fields"].as_object().ok_or(Reject::Unavailable)?;
    let mut out = Map::new();
    for f in requested { if ok.contains(f) { if let Some(v) = got.get(f) { out.insert(f.clone(), v.clone()); } } }
    Ok(out)
}

/// Where the Control Plane is reached. Off = not configured: every lookup is "unavailable" (honest, fail closed).
pub enum Plane { Off, #[cfg(test)] Double(Box<dyn Fn(&str) -> Option<String> + Send + Sync>) }
impl Plane {
    async fn ask(&self, _env: &str) -> Option<String> { match self { Plane::Off => None, #[cfg(test)] Plane::Double(f) => f(_env) } }
}
fn plane() -> Plane { Plane::Off }   // the real HTTP/3 client lands when his Control Plane address + public key are given
fn cp_pub() -> String { std::env::var("DESK_CONTROL_PLANE_PUBKEY").unwrap_or_default() }

fn out(status: StatusCode, body: Value) -> Response { (status, [(header::CONTENT_TYPE, "application/json")], body.to_string()).into_response() }
fn unavailable(rid: &str) -> Response { out(StatusCode::SERVICE_UNAVAILABLE, json!({"error": "data_unavailable", "request_id": rid, "freshness": null})) }

/// POST /desk/v1/customer/lookup  {company_ref, reason, fields:[..]}
pub async fn lookup(h: HeaderMap, body: Bytes) -> Response { run(&h, &body, &plane(), &cp_pub(), crate::signed::now_secs()).await }

pub(crate) async fn run(h: &HeaderMap, body: &[u8], plane: &Plane, cp_key: &str, now: i64) -> Response {
    let Ok(v) = serde_json::from_slice::<Value>(body) else { return out(StatusCode::UNPROCESSABLE_ENTITY, json!({"error": "refused"})) };
    let company = v["company_ref"].as_str().unwrap_or(""); let reason = v["reason"].as_str().unwrap_or("");
    let fields: Vec<String> = v["fields"].as_array().map(|a| a.iter().filter_map(|x| x.as_str().map(str::to_string)).collect()).unwrap_or_default();
    if !valid_ref(company) || !valid_reason(reason) || !valid_fields(&fields) { return out(StatusCode::UNPROCESSABLE_ENTITY, json!({"error": "refused"})); }
    let (c, who) = match owner(h).await { Ok(x) => x, Err(r) => return r };
    let rid = uuid4();
    let arr = format!("array[{}]::text[]", fields.iter().map(|f| lit(f)).collect::<Vec<_>>().join(","));
    // 2) audit line first (also the permission check + burst breaker inside PostgreSQL)
    let begin = format!("select desk.fadm_lookup_begin('{who}'::uuid, {}, {}, {arr}, '{rid}'::uuid)::text", lit(company), lit(reason.trim()));
    match rows(&c, &begin).await {
        Ok(r) => if r.first().and_then(|x| x.get(0)).is_none() { return out(StatusCode::TOO_MANY_REQUESTS, json!({"error": "frozen"})); },
        Err(e) => return match e.code() {
            Some(k) if *k == tokio_postgres::error::SqlState::INSUFFICIENT_PRIVILEGE => out(StatusCode::FORBIDDEN, json!({"error": "not_allowed"})),
            Some(k) if *k == tokio_postgres::error::SqlState::CHECK_VIOLATION => out(StatusCode::UNPROCESSABLE_ENTITY, json!({"error": "refused"})),
            _ => { eprintln!("desk lookup: db: {e}"); out(StatusCode::SERVICE_UNAVAILABLE, json!({"error": "db_unavailable"})) }
        },
    }
    let finish = |o: &'static str| format!("select desk.fadm_lookup_finish('{who}'::uuid, '{rid}'::uuid, '{o}')::text");
    // 3) signed request out
    let Some(s) = crate::signed::signer() else { let _ = rows(&c, &finish("unavailable")).await; return unavailable(&rid) };
    let env = build_request(s, &rid, &who, company, reason, &fields, now);
    let Some(ans) = plane.ask(&env).await else { let _ = rows(&c, &finish("unavailable")).await; return unavailable(&rid) };
    // 4) verify + whitelist, 5) close the audit line; if it cannot be closed, nothing is shown
    match accept(&ans, cp_key, &rid, company, &fields, now) {
        Ok(f) => {
            if rows(&c, &finish("answered")).await.is_err() { return unavailable(&rid); }
            out(StatusCode::OK, json!({"request_id": rid, "company_ref": company, "answered_at": now, "fields": f}))
        }
        Err(Reject::Refused) => { let _ = rows(&c, &finish("refused")).await; out(StatusCode::FORBIDDEN, json!({"error": "control_plane_refused", "request_id": rid})) }
        Err(Reject::Unavailable) => { let _ = rows(&c, &finish("unavailable")).await; unavailable(&rid) }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signer as _, SigningKey, Verifier, VerifyingKey, Signature};
    const SEED: &str = "0101010101010101010101010101010101010101010101010101010101010101";
    const RID: &str = "11111111-2222-4333-8444-555555555555";
    fn cp() -> (SigningKey, String) { let k = SigningKey::from_bytes(&[7u8; 32]); let p = hex(k.verifying_key().as_bytes()); (k, p) }
    fn answer(k: &SigningKey, rid: &str, company: &str, at: i64, fields: Value, refused: bool) -> String {
        let body = json!({"request_id": rid, "company_ref": company, "answered_at": at, "fields": fields, "refused": refused}).to_string();
        let sig = hex(&k.sign(format!("{ANS_DOMAIN}\n{body}").as_bytes()).to_bytes());
        json!({"body": body, "sig": sig}).to_string()
    }
    fn f(v: &[&str]) -> Vec<String> { v.iter().map(|x| x.to_string()).collect() }
    #[test] fn contract_has_whitelist_and_inputs_are_checked() {
        assert!(allowed().contains(&"service_state".to_string()) && allowed().len() >= 14);
        assert!(valid_ref("acme-1234") && !valid_ref("short") && !valid_ref("Acme Ltd, 10 High Street") && !valid_ref(&"a".repeat(65)));
        assert!(valid_reason("customer says mail is missing") && !valid_reason("short") && !valid_reason("two\nlines of reason here") && !valid_reason(&"x".repeat(301)));
        assert!(valid_fields(&f(&["service_state", "usage_seats"])) && !valid_fields(&[]) && !valid_fields(&f(&["service_state", "service_state"])) && !valid_fields(&f(&["anything_else"])));
    }
    #[test] fn request_is_signed_audience_bound_and_expires_in_60s() {
        let s = Signer::from_seed_hex(SEED).unwrap();
        let env: Value = serde_json::from_str(&build_request(&s, RID, "emp-1", "acme-1234", "  customer says mail is missing  ", &f(&["service_state"]), 1000)).unwrap();
        let body = env["body"].as_str().unwrap(); let b: Value = serde_json::from_str(body).unwrap();
        assert_eq!(b["aud"], "desk-lookup"); assert_eq!(b["method"], "read"); assert_eq!(b["expires_at"].as_i64().unwrap() - b["issued_at"].as_i64().unwrap(), 60);
        assert_eq!(b["reason"], "customer says mail is missing"); assert_eq!(b["request_id"], RID);
        let vk = VerifyingKey::from_bytes(&unhex(&s.public_hex()).unwrap().try_into().unwrap()).unwrap();
        let sig = Signature::from_slice(&unhex(env["sig"].as_str().unwrap()).unwrap()).unwrap();
        assert!(vk.verify(format!("{REQ_DOMAIN}\n{body}").as_bytes(), &sig).is_ok());
        assert!(vk.verify(format!("{REQ_DOMAIN}\n{}", body.replace("acme-1234", "other-9999")).as_bytes(), &sig).is_err());
        assert!(vk.verify(format!("anexo-desk-v1\n{body}").as_bytes(), &sig).is_err(), "another audience's signature must not verify");
    }
    #[test] fn good_answer_is_cut_to_requested_whitelist_fields() {
        let (k, p) = cp();
        let a = answer(&k, RID, "acme-1234", 1000, json!({"service_state": "active", "usage_seats": 12, "limit_seats": 25, "unlisted_field": "x", "surprise": 1}), false);
        let m = accept(&a, &p, RID, "acme-1234", &f(&["service_state", "usage_seats"]), 1010).unwrap();
        assert_eq!(m.len(), 2); assert_eq!(m["service_state"], "active"); assert_eq!(m["usage_seats"], 12);
        assert!(!m.contains_key("limit_seats") && !m.contains_key("unlisted_field") && !m.contains_key("surprise"));
    }
    #[test] fn every_wrong_answer_fails_closed() {
        let (k, p) = cp(); let req = f(&["service_state"]); let ok = json!({"service_state": "active"});
        let good = answer(&k, RID, "acme-1234", 1000, ok.clone(), false);
        assert!(accept(&good, &p, RID, "acme-1234", &req, 1010).is_ok());
        assert_eq!(accept(&good, &p, RID, "acme-1234", &req, 1000 + EXPIRY + 1), Err(Reject::Unavailable), "stale");
        assert_eq!(accept(&good, &p, RID, "acme-1234", &req, 900), Err(Reject::Unavailable), "from the future");
        assert_eq!(accept(&good, &p, "99999999-2222-4333-8444-555555555555", "acme-1234", &req, 1010), Err(Reject::Unavailable), "other request id (replay)");
        assert_eq!(accept(&good, &p, RID, "other-9999", &req, 1010), Err(Reject::Unavailable), "other company");
        let (_, wrong) = { let k2 = SigningKey::from_bytes(&[8u8; 32]); (0, hex(k2.verifying_key().as_bytes())) };
        assert_eq!(accept(&good, &wrong, RID, "acme-1234", &req, 1010), Err(Reject::Unavailable), "wrong key");
        assert_eq!(accept(&good, "", RID, "acme-1234", &req, 1010), Err(Reject::Unavailable), "no key configured");
        let tampered = good.replace("active", "suspended");
        assert_eq!(accept(&tampered, &p, RID, "acme-1234", &req, 1010), Err(Reject::Unavailable), "tampered body");
        assert_eq!(accept("not json", &p, RID, "acme-1234", &req, 1010), Err(Reject::Unavailable));
        assert_eq!(accept(&answer(&k, RID, "acme-1234", 1000, ok, true), &p, RID, "acme-1234", &req, 1010), Err(Reject::Refused));
    }
    #[tokio::test] async fn plane_off_means_no_answer_and_double_round_trips() {
        assert!(Plane::Off.ask("x").await.is_none());
        let (k, p) = cp(); let s = Signer::from_seed_hex(SEED).unwrap();
        let sp = s.public_hex();
        let d = Plane::Double(Box::new(move |env| {   // the test double checks OUR signature before it answers, like the real one must
            let e: Value = serde_json::from_str(env).ok()?; let body = e["body"].as_str()?;
            let vk = VerifyingKey::from_bytes(&unhex(&sp)?.try_into().ok()?).ok()?;
            vk.verify(format!("{REQ_DOMAIN}\n{body}").as_bytes(), &Signature::from_slice(&unhex(e["sig"].as_str()?)?).ok()?).ok()?;
            let b: Value = serde_json::from_str(body).ok()?; if b["aud"] != "desk-lookup" { return None; }
            Some(answer(&k, b["request_id"].as_str()?, b["company_ref"].as_str()?, b["issued_at"].as_i64()?, json!({"service_state": "grace_period", "grace_days_left": 4}), false))
        }));
        let req = build_request(&s, RID, "emp-1", "acme-1234", "customer says mail is missing", &f(&["service_state", "grace_days_left"]), 1000);
        let ans = d.ask(&req).await.expect("double answers a signed request");
        let m = accept(&ans, &p, RID, "acme-1234", &f(&["service_state", "grace_days_left"]), 1005).unwrap();
        assert_eq!(m["service_state"], "grace_period");
        let forged = req.replace("acme-1234", "other-9999"); assert!(d.ask(&forged).await.is_none(), "a request altered after signing is refused");
    }
}
