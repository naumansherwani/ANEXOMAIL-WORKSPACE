// ANEXOMAIL ADMIN DESK escalations.rs (D5c, phase 1l, 23 Nov 2026): an employee ESCALATES a problem to the owner side. Rust + Axum + Tokio + Ed25519. List: D5C-ESCALATE-LIST-23NOV.md (L1..L12).
// TWO PARTS. (1) The DOORS the employee uses (create, list): the sealed router (Rule 52) + a live Desk session; desk_app has NO table right, only the SECURITY DEFINER doors of SQL AD10
//   (fadm_escalation_create, fadm_escalation_list); the database decides who may and refuses a bad shape, a money or promise word, a flood, and a repeat (the same request id = the same case).
// (2) The SIGNED HAND-OVER to the founder side (L6): seal_handover() signs one outbox row with the Desk's OWN Ed25519 key over created + expires + nonce + the exact body (OWASP webhook rules, RFC 9421 style),
//   verify_handover() is the receiving side's check (one scheme version, 5 minute window, no replay). The founder-side puller is the later phase FOUNDER-ESCALATION-INBOX; until then no route hands
//   anything out (no unused door) and a case honestly stays "queued". Metadata + audit reference only: no amount, no card, no customer secret. Desk-only: no founder or awam code. // no-money-gate-ok
use crate::bridge::owner;
use crate::door::{lit, rows};
use crate::sign::{self, Signer};
use std::collections::HashMap;
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde::Deserialize;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

pub const REASONS: [&str; 10] = ["payment_not_active", "features_missing", "limit_reached", "grace_period", "suspended", "cannot_sign_in", "mail_not_delivered", "attachment_blocked", "many_customers", "other"];
pub const PRIORITIES: [&str; 3] = ["urgent", "high", "normal"];
pub const FLAGS: [&str; 5] = ["none", "payment_received_not_active", "limit_reached", "suspended", "many_customers"];
/// Same shape as the SQL CHECK.
pub fn valid_company(s: &str) -> bool { (3..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'_' | b'.' | b':' | b'-')) }
pub fn valid_request_id(s: &str) -> bool { (16..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-') }
fn valid_audit_ref(s: &str) -> bool { s.len() <= 80 && s.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'_' | b'.' | b':' | b'-')) }
fn valid_runbook_key(s: &str) -> bool { s.len() >= 2 && s.len() <= 3 && s.starts_with('R') && s[1..].bytes().all(|b| b.is_ascii_digit()) }

#[derive(Deserialize)] #[serde(deny_unknown_fields)]
struct CreateIn { request_id: String, company_ref: String, reason: String, priority: String, #[serde(default = "none")] flag: String, #[serde(default)] audit_ref: String, #[serde(default)] runbook_key: Option<String>, #[serde(default)] note: String }
fn none() -> String { "none".into() }
#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct ListIn { #[serde(default)] company_ref: Option<String> }

fn shape_ok(c: &CreateIn) -> bool {
    valid_request_id(&c.request_id) && valid_company(&c.company_ref) && REASONS.contains(&c.reason.as_str()) && PRIORITIES.contains(&c.priority.as_str()) && FLAGS.contains(&c.flag.as_str())
        && valid_audit_ref(&c.audit_ref) && c.note.chars().count() <= 280 && c.note.chars().all(|ch| !ch.is_control()) && c.runbook_key.as_deref().map(valid_runbook_key).unwrap_or(true)
}

/// POST /desk/v1/escalations {request_id, company_ref, reason, priority, flag?, audit_ref?, runbook_key?, note?}: open a case. 200 {case_no,status,duplicate}; 409 refused (the database said no); 400 bad shape.
pub async fn create(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 2048 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<CreateIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if !shape_ok(&b) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    let rb = b.runbook_key.as_deref().map(lit).unwrap_or_else(|| "NULL".into());
    let q = format!("select desk.fadm_escalation_create('{o}'::uuid, {}, {}, {}, {}, {}, {}, {}, {})::text", lit(&b.request_id), lit(&b.company_ref), lit(&b.reason), lit(&b.priority), lit(&b.flag), lit(&b.audit_ref), rb, lit(&b.note));
    match rows(&c, &q).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) { Some(j) => out(StatusCode::OK, j.to_string()), None => err(StatusCode::CONFLICT, "refused") },
        Err(e) => { eprintln!("desk escalations: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/escalations/list {company_ref?}: the cases of one company, or (no company) my own. Case number + status + the acknowledge target, nothing more.
pub async fn list(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 1024 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<ListIn>(if body.is_empty() { b"{}" } else { &body }) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if b.company_ref.as_deref().map(|s| !valid_company(s)).unwrap_or(false) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    let co = b.company_ref.as_deref().map(lit).unwrap_or_else(|| "NULL".into());
    match rows(&c, &format!("select desk.fadm_escalation_list('{o}'::uuid, {co})::text")).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) { Some(j) => out(StatusCode::OK, j.to_string()), None => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk escalations: db: {e}"); unavailable() }
    }
}

// ------------------------------------------------------------------ the SIGNED HAND-OVER (L6) ------------------------------------------------------------------
pub const HANDOVER_SCHEME: &str = "anexo-desk-handover-v1";
pub const HANDOVER_TTL: i64 = 300;     // 5 minute window (OWASP: small tolerance, fresh signature on every retry)
pub const HANDOVER_SKEW: i64 = 30;     // clock drift allowed for "created in the future"
/// Replay cache of the RECEIVING side: a nonce is kept for TWICE the window (OWASP: at least 2 x tolerance), capped so a flood cannot grow it. (The door cache in sign.rs keeps nonces for a shorter time, so this one is its own.)
#[derive(Default)] pub struct HandoverSeen(HashMap<String, i64>);
impl HandoverSeen {
    pub fn fresh(&mut self, kid: &str, nonce: &str, now: i64) -> bool {
        self.0.retain(|_, t| now - *t <= 2 * HANDOVER_TTL);
        if self.0.len() >= 100_000 { return false; }
        self.0.insert(format!("{kid}:{nonce}"), now).is_none()
    }
    #[cfg(test)] pub fn len(&self) -> usize { self.0.len() }
}
/// The exact bytes that are signed: scheme version, kid, created, expires, nonce and the SHA-256 of the exact body (covered components, RFC 9421 style).
pub fn handover_message(kid: &str, created: i64, expires: i64, nonce: &str, body: &str) -> Vec<u8> {
    format!("{HANDOVER_SCHEME}\n{kid}\n{created}\n{expires}\n{nonce}\n{}", sign::sha256_hex(body.as_bytes())).into_bytes()
}
fn fresh_nonce() -> String { use ring::rand::{SecureRandom, SystemRandom}; let mut b = [0u8; 16]; SystemRandom::new().fill(&mut b).expect("system random"); sign::hex(&b) }
/// Seal one outbox payload. A NEW nonce, created and expires on EVERY call, so every retry carries a fresh signature.
#[allow(dead_code)] // used by the founder-side puller (phase FOUNDER-ESCALATION-INBOX); tested here
pub fn seal_handover(s: &Signer, payload: &str, now: i64) -> String {
    let (nonce, expires) = (fresh_nonce(), now + HANDOVER_TTL); let kid = s.kid();
    let sig = s.sign_raw(&handover_message(&kid, now, expires, &nonce, payload));
    serde_json::json!({"scheme": HANDOVER_SCHEME, "kid": kid, "created": now, "expires": expires, "nonce": nonce, "body": payload, "sig": sig}).to_string()
}
/// The RECEIVING side's check. One accepted scheme version, a known key (kid), a window no longer than the TTL, not expired, not from the future, a nonce never seen, then the signature.
/// Generic reasons only (the caller answers 401 with no detail). `keys` = (kid, public key hex) pairs, two of them during a rotation overlap.
#[allow(dead_code)]
pub fn verify_handover(keys: &[(&str, &str)], env: &str, now: i64, seen: &mut HandoverSeen) -> Result<serde_json::Value, &'static str> {
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};
    let v: serde_json::Value = serde_json::from_str(env).map_err(|_| "bad_envelope")?;
    if v["scheme"].as_str() != Some(HANDOVER_SCHEME) { return Err("bad_scheme"); }
    let (kid, nonce, body, sig) = (v["kid"].as_str().ok_or("bad_envelope")?, v["nonce"].as_str().ok_or("bad_envelope")?, v["body"].as_str().ok_or("bad_envelope")?, v["sig"].as_str().ok_or("bad_envelope")?);
    let (created, expires) = (v["created"].as_i64().ok_or("bad_envelope")?, v["expires"].as_i64().ok_or("bad_envelope")?);
    if !sign::nonce_ok(nonce) { return Err("bad_nonce"); }
    if expires <= created || expires - created > HANDOVER_TTL { return Err("bad_window"); }
    if now > expires { return Err("expired"); }
    if created > now + HANDOVER_SKEW { return Err("from_future"); }
    let pk = keys.iter().find(|(k, _)| *k == kid).map(|(_, p)| *p).ok_or("unknown_key")?;
    let vk = VerifyingKey::from_bytes(&sign::unhex(pk).and_then(|b| b.try_into().ok()).ok_or("bad_key")?).map_err(|_| "bad_key")?;
    let sg = Signature::from_slice(&sign::unhex(sig).ok_or("bad_signature")?).map_err(|_| "bad_signature")?;
    vk.verify_strict(&handover_message(kid, created, expires, nonce, body), &sg).map_err(|_| "bad_signature")?;   // constant-time inside the library
    if !seen.fresh(kid, nonce, now) { return Err("replay"); }                                                       // only AFTER the signature is good, so a forger cannot fill the cache
    serde_json::from_str(body).map_err(|_| "bad_body")
}

#[cfg(test)]
mod tests {
    use super::*;
    const SEED: &str = "0202020202020202020202020202020202020202020202020202020202020202";
    const SEED2: &str = "0303030303030303030303030303030303030303030303030303030303030303";
    fn good() -> CreateIn { CreateIn { request_id: "req-aaaaaaaaaaaaaaaa".into(), company_ref: "TESTCO001".into(), reason: "suspended".into(), priority: "high".into(), flag: "none".into(), audit_ref: "audit:abc".into(), runbook_key: Some("R5".into()), note: "asked twice".into() } }
    #[test] fn shape_blocks_odd_input() {
        assert!(shape_ok(&good()));
        for f in [|c: &mut CreateIn| c.company_ref = "a'; drop table x;--".into(), |c: &mut CreateIn| c.company_ref = "ab".into(), |c: &mut CreateIn| c.reason = "weird".into(), |c: &mut CreateIn| c.priority = "asap".into(),
            |c: &mut CreateIn| c.flag = "x".into(), |c: &mut CreateIn| c.request_id = "short".into(), |c: &mut CreateIn| c.note = "x".repeat(281), |c: &mut CreateIn| c.note = "line\nbreak".into(),
            |c: &mut CreateIn| c.runbook_key = Some("R1; --".into()), |c: &mut CreateIn| c.audit_ref = "a b".into()] { let mut c = good(); f(&mut c); assert!(!shape_ok(&c)); }
    }
    #[test] fn bodies_reject_unknown_fields_and_wrong_types() {
        assert!(serde_json::from_str::<CreateIn>(r#"{"request_id":"req-aaaaaaaaaaaaaaaa","company_ref":"TESTCO001","reason":"other","priority":"normal"}"#).is_ok());
        assert!(serde_json::from_str::<CreateIn>(r#"{"request_id":"req-aaaaaaaaaaaaaaaa","company_ref":"TESTCO001","reason":"other","priority":"normal","amount":5}"#).is_err()); // no-money-gate-ok
        assert!(serde_json::from_str::<CreateIn>(r#"{"request_id":1,"company_ref":"TESTCO001","reason":"other","priority":"normal"}"#).is_err());
        assert!(serde_json::from_str::<ListIn>(r#"{"company_ref":"TESTCO001","x":1}"#).is_err());
    }
    #[test] fn handover_good_is_accepted_and_replay_refused() {
        let s = Signer::from_seed_hex(SEED).unwrap(); let (kid, pk) = (s.kid(), s.public_hex()); let keys = [(kid.as_str(), pk.as_str())];
        let env = seal_handover(&s, r#"{"case_no":"ESC-231123-00001","company_ref":"TESTCO001"}"#, 1000); let mut seen = HandoverSeen::default();
        assert_eq!(verify_handover(&keys, &env, 1010, &mut seen).unwrap()["company_ref"], "TESTCO001");
        assert_eq!(verify_handover(&keys, &env, 1011, &mut seen), Err("replay"));
        let again = seal_handover(&s, "{}", 1000); assert_ne!(serde_json::from_str::<serde_json::Value>(&env).unwrap()["nonce"], serde_json::from_str::<serde_json::Value>(&again).unwrap()["nonce"], "every retry has its own nonce");
        assert!(verify_handover(&keys, &again, 1012, &mut seen).is_ok());
    }
    #[test] fn handover_refuses_tamper_wrong_key_old_future_and_other_scheme() {
        let s = Signer::from_seed_hex(SEED).unwrap(); let o = Signer::from_seed_hex(SEED2).unwrap(); let (kid, pk) = (s.kid(), s.public_hex()); let keys = [(kid.as_str(), pk.as_str())];
        let env = seal_handover(&s, r#"{"a":1}"#, 1000); let mut seen = HandoverSeen::default();
        let mut v: serde_json::Value = serde_json::from_str(&env).unwrap(); v["body"] = r#"{"a":2}"#.into(); assert_eq!(verify_handover(&keys, &v.to_string(), 1001, &mut seen), Err("bad_signature"));
        let mut v: serde_json::Value = serde_json::from_str(&env).unwrap(); v["expires"] = 99999.into(); assert_eq!(verify_handover(&keys, &v.to_string(), 1001, &mut seen), Err("bad_window"));
        let mut v: serde_json::Value = serde_json::from_str(&env).unwrap(); v["scheme"] = "anexo-desk-handover-v0".into(); assert_eq!(verify_handover(&keys, &v.to_string(), 1001, &mut seen), Err("bad_scheme"));
        let forged = seal_handover(&o, r#"{"a":1}"#, 1000); let mut v: serde_json::Value = serde_json::from_str(&forged).unwrap(); v["kid"] = kid.clone().into(); assert_eq!(verify_handover(&keys, &v.to_string(), 1001, &mut seen), Err("bad_signature"), "another key under our kid");
        assert_eq!(verify_handover(&keys, &forged, 1001, &mut seen), Err("unknown_key"));
        assert_eq!(verify_handover(&keys, &env, 1000 + HANDOVER_TTL + 1, &mut seen), Err("expired"));
        assert_eq!(verify_handover(&keys, &env, 1000 - HANDOVER_SKEW - 1, &mut seen), Err("from_future"));
        assert_eq!(verify_handover(&keys, "not json", 1001, &mut seen), Err("bad_envelope"));
        assert!(seen.len() == 0, "a refused hand-over never fills the replay cache");
    }
    #[test] fn replay_is_remembered_for_the_whole_window_and_a_bit_more() {
        let s = Signer::from_seed_hex(SEED).unwrap(); let (kid, pk) = (s.kid(), s.public_hex()); let keys = [(kid.as_str(), pk.as_str())]; let mut seen = HandoverSeen::default();
        let env = seal_handover(&s, "{}", 1000); assert!(verify_handover(&keys, &env, 1001, &mut seen).is_ok());
        assert_eq!(verify_handover(&keys, &env, 1000 + HANDOVER_TTL, &mut seen), Err("replay"), "still inside the window: replay, not accepted");
        assert_eq!(verify_handover(&keys, &env, 1000 + HANDOVER_TTL + 1, &mut seen), Err("expired"));
    }
    #[test] fn handover_key_rotation_accepts_old_and_new_kid() {
        let a = Signer::from_seed_hex(SEED).unwrap(); let b = Signer::from_seed_hex(SEED2).unwrap(); let (ka, pa, kb, pb) = (a.kid(), a.public_hex(), b.kid(), b.public_hex());
        let keys = [(ka.as_str(), pa.as_str()), (kb.as_str(), pb.as_str())]; let mut seen = HandoverSeen::default();
        assert!(verify_handover(&keys, &seal_handover(&a, "{}", 1000), 1001, &mut seen).is_ok()); assert!(verify_handover(&keys, &seal_handover(&b, "{}", 1000), 1001, &mut seen).is_ok());
        assert_eq!(verify_handover(&keys[..1], &seal_handover(&b, "{}", 1000), 1001, &mut seen), Err("unknown_key"), "a revoked key is refused");
    }
    /// Rust -> PostgreSQL on the scratch database (needs DESK_TEST_ADMIN_URL with AD1..AD10; skipped otherwise).
    #[tokio::test] async fn database_doors_create_repeat_list_and_refuse() {
        let Ok(admin) = std::env::var("DESK_TEST_ADMIN_URL") else { eprintln!("no DESK_TEST_ADMIN_URL: skipped"); return; };
        let (a, conn) = tokio_postgres::connect(&admin, tokio_postgres::NoTls).await.unwrap(); tokio::spawn(conn);
        let hx = |b: &[u8]| b.iter().map(|x| format!("{x:02x}")).collect::<String>();
        let sfx = hx(&crate::auth::token_hash(&format!("es{:?}", std::time::SystemTime::now()))[..4]);
        let h = "$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo";
        let ag = rows(&a, &format!("insert into desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) values ('es-a-{sfx}@selftest.invalid','ES Agent','agent',NULL,true,'active',true) returning id::text")).await.unwrap()[0].get(0).unwrap().to_string();
        let ta = format!("{sfx}{}", "cd".repeat(28));
        rows(&a, &format!("select desk.fadm_session_create('{ag}'::uuid, '\\x{}'::bytea, 600)::text", hx(&crate::auth::token_hash(&ta)))).await.unwrap();
        let _ = h; rows(&a, "alter role desk_app login password 'scratch'").await.unwrap();
        let url = format!("postgres://desk_app:scratch@{}/{}?sslmode=disable", admin.split('@').next_back().unwrap().split('/').next().unwrap(), admin.rsplit('/').next().unwrap());
        unsafe { std::env::set_var("DESK_APP_URL", &url); }
        let body = |r: Response| async move { let st = r.status(); let b = axum::body::to_bytes(r.into_body(), 1 << 22).await.unwrap(); (st, serde_json::from_slice::<serde_json::Value>(&b).unwrap_or_default()) };
        let hd = |t: &str| { let mut m = HeaderMap::new(); m.insert(header::AUTHORIZATION, format!("Bearer {t}").parse().unwrap()); m };
        let co = format!("ES{sfx}01"); let rid = format!("req-{sfx}-0000000001");
        let mk = |rid: &str, co: &str, note: &str| Bytes::from(format!(r#"{{"request_id":"{rid}","company_ref":"{co}","reason":"suspended","priority":"high","flag":"suspended","audit_ref":"audit:x1","runbook_key":"R5","note":"{note}"}}"#));
        let (st, _) = body(create(HeaderMap::new(), mk(&rid, &co, "")).await).await; assert_eq!(st, StatusCode::UNAUTHORIZED);
        let (st, v) = body(create(hd(&ta), mk(&rid, &co, "asked twice")).await).await; assert_eq!(st, StatusCode::OK, "{v}");
        assert_eq!(v["status"], "queued"); assert_eq!(v["duplicate"], false); let no = v["case_no"].as_str().unwrap().to_string(); assert!(no.starts_with("ESC-"));
        let (st, v) = body(create(hd(&ta), mk(&rid, &co, "asked twice")).await).await; assert_eq!(st, StatusCode::OK); assert_eq!(v["duplicate"], true); assert_eq!(v["case_no"], no.as_str(), "a repeat is the same case");
        let (st, v) = body(create(hd(&ta), mk(&format!("req-{sfx}-0000000002"), &co, "")).await).await; assert_eq!(st, StatusCode::OK); assert_eq!(v["duplicate"], true, "one open problem, one case");
        let (st, v) = body(create(hd(&ta), mk(&format!("req-{sfx}-0000000003"), &format!("ES{sfx}02"), "please refund them")).await).await; assert_eq!(st, StatusCode::CONFLICT, "a money word is refused: {v}");   // no-money-gate-ok
        let (st, _) = body(create(hd(&ta), Bytes::from(r#"{"request_id":"x","company_ref":"y"}"#)).await).await; assert_eq!(st, StatusCode::BAD_REQUEST);
        let (st, v) = body(list(hd(&ta), Bytes::from(format!(r#"{{"company_ref":"{co}"}}"#))).await).await; assert_eq!(st, StatusCode::OK, "{v}");
        let arr = v.as_array().unwrap(); assert_eq!(arr.len(), 1); assert_eq!(arr[0]["case_no"], no.as_str()); assert_eq!(arr[0]["status"], "queued"); assert_eq!(arr[0]["target_minutes"], 60); assert!(arr[0].get("note").is_none() && arr[0].get("audit_ref").is_none(), "the list shows number + status only");
        let (_, v) = body(list(hd(&ta), Bytes::from(format!(r#"{{"company_ref":"ES{sfx}99"}}"#))).await).await; assert_eq!(v.as_array().unwrap().len(), 0, "another company sees nothing");
        let (st, _) = body(list(HeaderMap::new(), Bytes::new()).await).await; assert_eq!(st, StatusCode::UNAUTHORIZED);
        // the hand-over payload sits in the outbox and seals + verifies with the Desk key
        let pay = rows(&a, &format!("select payload::text from desk.fadm_escalation_outbox o join desk.fadm_escalation c on c.id = o.case_id where c.case_no = '{no}'")).await.unwrap()[0].get(0).unwrap().to_string();
        let s = Signer::from_seed_hex(SEED).unwrap(); let (kid, pk) = (s.kid(), s.public_hex()); let mut seen = HandoverSeen::default();
        let v = verify_handover(&[(kid.as_str(), pk.as_str())], &seal_handover(&s, &pay, 5000), 5001, &mut seen).unwrap(); assert_eq!(v["case_no"], no.as_str()); assert!(v.get("amount").is_none()); // no-money-gate-ok
    }
}
