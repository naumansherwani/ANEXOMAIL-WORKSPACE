// ANEXOMAIL ADMIN DESK lookup.rs (D5a-3, 22 Nov 2026): the ONE door by which an employee asks his Control Plane about ONE company.
// Rust + Tokio + axum, behind signed::guard (Rule 52). Order is fixed: 1) check the input, 2) the database writes the audit line FIRST (AD4 fadm_lookup_begin,
// which also runs the permission check and the burst breaker), 3) a signed read-only request goes out (Ed25519, audience desk-lookup, 60 s expiry),
// 4) the answer is verified (its own key, same request id, fresh) and cut down to the contract whitelist, 5) the database closes the audit line.
// FAIL CLOSED: no address, no key, bad signature, stale, wrong id = "data_unavailable"; an old answer is never shown and nothing is stored here.
// Desk-only: no founder or awam code. The fields allowed come from contract/DESK-LOOKUP-CONTRACT.json INSIDE this crate (the installer builds only admin-desk/server);
// the test contract_copy_equals_the_gate_file keeps it byte-equal to gates/DESK-LOOKUP-CONTRACT.json, the file the commit gate reads.
use crate::bridge::owner;
use crate::door::{lit, rows};
use crate::sign::{hex, unhex, Signer};
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::{json, Map, Value};

const CONTRACT: &str = include_str!("../contract/DESK-LOOKUP-CONTRACT.json");
pub const AUD: &str = "desk-lookup";
pub const EXPIRY: i64 = 60;
/// D5a-5 (1i): a verified answer may be at most this old when it arrives (was 60 s); never older than the request it answers.
pub const FRESH: i64 = 15;
/// D5a-5 (1i): ONE total deadline for the whole Control Plane call and for the session/database check before it.
pub const DEADLINE_SECS: u64 = 6;
/// D5a-5 (1i): circuit breaker: BREAKER_FAILS failures inside BREAKER_WINDOW seconds open it for BREAKER_OPEN seconds.
pub const BREAKER_FAILS: i64 = 3; pub const BREAKER_WINDOW: i64 = 30; pub const BREAKER_OPEN: i64 = 15;
pub(crate) const REQ_DOMAIN: &str = "anexo-desk-lookup-v1";
pub(crate) const ANS_DOMAIN: &str = "anexo-control-answer-v1";

pub fn allowed() -> Vec<String> {
    serde_json::from_str::<Value>(CONTRACT).ok().and_then(|v| v["allowed_fields"].as_array().map(|a| a.iter().filter_map(|x| x.as_str().map(str::to_string)).collect())).unwrap_or_default()
}
pub fn valid_ref(s: &str) -> bool { (6..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-') }
pub fn valid_reason(s: &str) -> bool { let t = s.trim(); let n = t.chars().count(); (10..=300).contains(&n) && !t.contains('\n') && !t.contains('\r') }
/// Requested fields: non-empty, no duplicates, every one on the whitelist.
pub fn valid_fields(f: &[String]) -> bool {
    let ok = allowed(); !f.is_empty() && f.len() <= ok.len() && f.iter().all(|x| ok.contains(x)) && { let mut s = f.to_vec(); s.sort(); s.dedup(); s.len() == f.len() }
}
pub(crate) fn uuid4() -> String {
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
    accept_for(env, cp_pub_hex, request_id, company, requested, now - FRESH, now)
}
/// Same, and the answer must also be NOT OLDER than the request it answers (`issued` = the request's own issued_at, 2 s clock skew allowed).
pub fn accept_for(env: &str, cp_pub_hex: &str, request_id: &str, company: &str, requested: &[String], issued: i64, now: i64) -> Result<Map<String, Value>, Reject> {
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
    if at > now + 5 || now - at > FRESH || at < issued - 2 { return Err(Reject::Unavailable); }
    if b["refused"].as_bool() == Some(true) { return Err(Reject::Refused); }
    let ok = allowed(); let got = b["fields"].as_object().ok_or(Reject::Unavailable)?;
    let mut out = Map::new();
    for f in requested { if ok.contains(f) { if let Some(v) = got.get(f) { out.insert(f.clone(), v.clone()); } } }
    Ok(out)
}

/// D5a-5 (1i) circuit breaker. Pure state machine (testable): `fails` inside the window open it; while open every call is answered unavailable at once;
/// after BREAKER_OPEN seconds ONE probe is let through (half-open); a success closes it, a failure re-opens it.
#[derive(Default)]
pub struct Breaker { st: std::sync::Mutex<(i64, i64, i64)> } // (fail count, first fail time, open until)
impl Breaker {
    pub fn allow(&self, now: i64) -> bool {
        let mut g = self.st.lock().unwrap_or_else(|e| e.into_inner());
        if g.2 == 0 || now >= g.2 { if g.2 != 0 { g.2 = now + BREAKER_OPEN; } return true; } // closed, or half-open: this ONE probe goes out and the gate shuts again
        false
    }
    pub fn ok(&self) { *self.st.lock().unwrap_or_else(|e| e.into_inner()) = (0, 0, 0); }
    pub fn fail(&self, now: i64) {
        let mut g = self.st.lock().unwrap_or_else(|e| e.into_inner());
        if now - g.1 > BREAKER_WINDOW { g.0 = 0; g.1 = now; }
        g.0 += 1;
        if g.0 >= BREAKER_FAILS || g.2 != 0 { g.2 = now + BREAKER_OPEN; }
    }
    #[allow(dead_code)]
    pub fn is_open(&self, now: i64) -> bool { let g = self.st.lock().unwrap_or_else(|e| e.into_inner()); g.2 != 0 && now < g.2 }
}
static BREAKER: std::sync::OnceLock<Breaker> = std::sync::OnceLock::new();
fn breaker() -> &'static Breaker { BREAKER.get_or_init(Breaker::default) }

/// `anexomail-desk version`: ONE line that proves WHICH build is running and that it carries the D5a-5 fail-closed code (the installer prints it as its last lines).
pub fn version_line() -> String {
    format!("DESK BUILD {} | fail-closed: fresh {}s, deadline {}s, breaker {} fails/{}s open {}s, no-store | lookup contract {} fields", option_env!("DESK_BUILD_COMMIT").unwrap_or("unknown"), FRESH, DEADLINE_SECS, BREAKER_FAILS, BREAKER_WINDOW, BREAKER_OPEN, allowed().len())
}

/// Where the Control Plane is reached. Off = not configured: every lookup is "unavailable" (honest, fail closed).
pub enum Plane { Off, H3 { addr: std::net::SocketAddr, host: String, ca_pem: Option<Vec<u8>> }, #[cfg(test)] Double(Box<dyn Fn(&str) -> Option<String> + Send + Sync>) }
impl Plane {
    async fn ask(&self, env: &str) -> Option<String> { self.ask_path(CP_PATH, env).await }
    /// Phase 1m-4: the same HTTP/3 client for another Control Plane route (the census).
    pub(crate) async fn ask_path(&self, path: &str, _env: &str) -> Option<String> { match self { Plane::Off => None, Plane::H3 { addr, host, ca_pem } => h3_post(*addr, host, ca_pem.as_deref(), path, _env).await, #[cfg(test)] Plane::Double(f) => { let _ = path; f(_env) } } }
}
pub const CP_PATH: &str = "/control/v1/lookup";
/// The real Control Plane is reached ONLY when his address (DESK_CONTROL_PLANE_ADDR = ip:udp-port) and host name (DESK_CONTROL_PLANE_HOST) are set; otherwise Off = fail closed.
pub(crate) fn plane() -> Plane {
    let (Ok(a), Ok(h)) = (std::env::var("DESK_CONTROL_PLANE_ADDR"), std::env::var("DESK_CONTROL_PLANE_HOST")) else { return Plane::Off };
    let Ok(addr) = a.parse() else { return Plane::Off };
    let ca_pem = std::env::var("DESK_CONTROL_PLANE_CA").ok().and_then(|p| std::fs::read(p).ok());
    Plane::H3 { addr, host: h, ca_pem }
}
/// HTTP/3 POST to the Control Plane. The client offers ONLY TLS 1.3, AES-256-GCM and X25519MLKEM768 (a finished handshake proves the Control Plane agreed to all three); 8 s to connect, 10 s to answer; any failure = None.
pub async fn h3_post(addr: std::net::SocketAddr, host: &str, ca_pem: Option<&[u8]>, path: &str, body: &str) -> Option<String> {
    use bytes::Buf; use rustls::crypto::ring as rp; use std::{sync::Arc, time::Duration};
    let mut p = rp::default_provider();
    p.cipher_suites = vec![rp::cipher_suite::TLS13_AES_256_GCM_SHA384];
    p.kx_groups = vec![rustls_post_quantum::X25519MLKEM768];
    let mut roots = rustls::RootCertStore::empty();
    match ca_pem { Some(pem) => for c in rustls_pemfile::certs(&mut &*pem).flatten() { roots.add(c).ok()?; }, None => for c in rustls_native_certs::load_native_certs().certs { let _ = roots.add(c); } }
    let mut cc = rustls::ClientConfig::builder_with_provider(Arc::new(p)).with_protocol_versions(&[&rustls::version::TLS13]).ok()?.with_root_certificates(roots).with_no_client_auth();
    cc.alpn_protocols = vec![b"h3".to_vec()];
    let initial = rp::cipher_suite::TLS13_AES_128_GCM_SHA256.tls13().and_then(|s| s.quic_suite())?;
    let qc = quinn::ClientConfig::new(Arc::new(quinn::crypto::rustls::QuicClientConfig::with_initial(Arc::new(cc), initial).ok()?));
    let bind: std::net::SocketAddr = if addr.is_ipv6() { "[::]:0" } else { "0.0.0.0:0" }.parse().ok()?;
    let mut ep = quinn::Endpoint::client(bind).ok()?; ep.set_default_client_config(qc);
    let conn = tokio::time::timeout(Duration::from_secs(8), ep.connect(addr, host).ok()?).await.ok()?.ok()?;
    let (mut driver, mut send) = h3::client::new(h3_quinn::Connection::new(conn)).await.ok()?;
    tokio::spawn(async move { let _ = std::future::poll_fn(|cx| driver.poll_close(cx)).await; });
    let req = axum::http::Request::builder().method("POST").uri(format!("https://{host}{path}")).header("content-type", "application/json").body(()).ok()?;
    let work = async {
        let mut st = send.send_request(req).await.ok()?;
        st.send_data(bytes::Bytes::copy_from_slice(body.as_bytes())).await.ok()?; st.finish().await.ok()?;
        if st.recv_response().await.ok()?.status() != StatusCode::OK { return None; }
        let mut got = Vec::new();
        while let Some(mut b) = st.recv_data().await.ok()? { let n = b.remaining(); got.extend_from_slice(&b.copy_to_bytes(n)); if got.len() > 64 * 1024 { return None; } }
        String::from_utf8(got).ok()
    };
    tokio::time::timeout(Duration::from_secs(10), work).await.ok().flatten()
}
/// `anexomail-desk lookup-selftest <company_ref>`: the real end-to-end proof on his server without a Desk login. Signs a request with the Desk's own key, sends it over HTTP/3 to the Control Plane
/// (env DESK_CONTROL_PLANE_*), verifies the signed answer, then proves three refusals: the SAME request again (replay), the answer checked against a WRONG key, and a company the database does not know.
pub async fn selftest(company: &str) -> Result<String, String> {
    crate::signed::init();
    let Some(s) = crate::signed::signer() else { return Err("Desk signing key not loaded".into()) };
    let p = plane(); if matches!(p, Plane::Off) { return Err("DESK_CONTROL_PLANE_ADDR / _HOST are not set".into()); }
    let key = cp_pub(); let now = crate::signed::now_secs();
    let fields: Vec<String> = ["service_state", "usage_seats", "package_id", "data_freshness"].iter().map(|x| x.to_string()).collect();
    let rid = uuid4(); let env = build_request(s, &rid, "selftest", company, "installer end to end self test", &fields, now);
    let ans = p.ask(&env).await.ok_or("no answer over HTTP/3 (Control Plane down, certificate not trusted, or request refused)")?;
    let got = accept(&ans, &key, &rid, company, &fields, now).map_err(|e| format!("answer not accepted: {e:?}"))?;
    if p.ask(&env).await.is_some() { return Err("REPLAY WAS ANSWERED (must be refused)".into()); }
    if accept(&ans, &hex(&[9u8; 32]), &rid, company, &fields, now).is_ok() { return Err("answer accepted under a wrong key".into()); }
    let rid2 = uuid4(); let env2 = build_request(s, &rid2, "selftest", "no-such-company-0000", "installer end to end self test", &fields, now);
    let a2 = p.ask(&env2).await.ok_or("no answer for the unknown-company probe")?;
    if accept(&a2, &key, &rid2, "no-such-company-0000", &fields, now) != Err(Reject::Refused) { return Err("unknown company was not refused".into()); }
    Ok(format!("LOOKUP SELFTEST OK: signed answer verified, replay refused, wrong key refused, unknown company refused; fields {}", Value::Object(got)))
}
pub(crate) fn cp_pub() -> String { std::env::var("DESK_CONTROL_PLANE_PUBKEY").unwrap_or_default() }

fn out(status: StatusCode, body: Value) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body.to_string()).into_response() }
/// ONE honest shape for every failure (D5a-5 F5): no fields, no cause, freshness null. The cause goes to the server log only.
fn unavailable(rid: &str) -> Response { out(StatusCode::SERVICE_UNAVAILABLE, json!({"error": "data_unavailable", "request_id": rid, "freshness": null})) }

/// POST /desk/v1/customer/lookup  {company_ref, reason, fields:[..]}
pub async fn lookup(h: HeaderMap, body: Bytes) -> Response { run(&h, &body, &plane(), &cp_pub(), crate::signed::now_secs(), breaker()).await }

/// ONE total deadline over the whole Control Plane call (connect + request + answer). Slow, hanging or silent = None = unavailable.
pub(crate) async fn ask_bounded(plane: &Plane, env: &str, secs: u64) -> Option<String> { tokio::time::timeout(std::time::Duration::from_secs(secs), plane.ask(env)).await.ok().flatten() }

pub(crate) async fn run(h: &HeaderMap, body: &[u8], plane: &Plane, cp_key: &str, now: i64, brk: &Breaker) -> Response {
    let Ok(v) = serde_json::from_slice::<Value>(body) else { return out(StatusCode::UNPROCESSABLE_ENTITY, json!({"error": "refused"})) };
    let company = v["company_ref"].as_str().unwrap_or(""); let reason = v["reason"].as_str().unwrap_or("");
    let fields: Vec<String> = v["fields"].as_array().map(|a| a.iter().filter_map(|x| x.as_str().map(str::to_string)).collect()).unwrap_or_default();
    if !valid_ref(company) || !valid_reason(reason) || !valid_fields(&fields) { return out(StatusCode::UNPROCESSABLE_ENTITY, json!({"error": "refused"})); }
    // D20: the session + database check has its own deadline; a database that is down or slow = the SAME unavailable shape, nothing shown
    let (c, who) = match tokio::time::timeout(std::time::Duration::from_secs(DEADLINE_SECS), owner(h)).await {
        Err(_) => { eprintln!("desk lookup: session check timed out"); return unavailable("") }
        Ok(Err(r)) if r.status() == StatusCode::SERVICE_UNAVAILABLE => { eprintln!("desk lookup: database unavailable before the audit line"); return unavailable("") }
        Ok(Err(r)) => return r,
        Ok(Ok(x)) => x,
    };
    let rid = uuid4();
    let arr = format!("array[{}]::text[]", fields.iter().map(|f| lit(f)).collect::<Vec<_>>().join(","));
    // 2) audit line first (also the permission check + burst breaker inside PostgreSQL)
    let begin = format!("select desk.fadm_lookup_begin('{who}'::uuid, {}, {}, {arr}, '{rid}'::uuid)::text", lit(company), lit(reason.trim()));
    match rows(&c, &begin).await {
        Ok(r) => if r.first().and_then(|x| x.get(0)).is_none() { return out(StatusCode::TOO_MANY_REQUESTS, json!({"error": "frozen"})); },
        Err(e) => return match e.code() {
            Some(k) if *k == tokio_postgres::error::SqlState::INSUFFICIENT_PRIVILEGE => out(StatusCode::FORBIDDEN, json!({"error": "not_allowed"})),
            Some(k) if *k == tokio_postgres::error::SqlState::CHECK_VIOLATION => out(StatusCode::UNPROCESSABLE_ENTITY, json!({"error": "refused"})),
            _ => { eprintln!("desk lookup: db: {e}"); unavailable("") }
        },
    }
    let finish = |o: &'static str| format!("select desk.fadm_lookup_finish('{who}'::uuid, '{rid}'::uuid, '{o}')::text");
    // 3) signed request out
    let Some(s) = crate::signed::signer() else { let _ = rows(&c, &finish("unavailable")).await; return unavailable(&rid) };
    let env = build_request(s, &rid, &who, company, reason, &fields, now);
    // D5a-5: breaker open = answer unavailable at once (the audit line is still closed); otherwise ONE total deadline for the whole call
    let started = std::time::Instant::now();
    let allowed_now = brk.allow(now);
    let asked = if allowed_now { ask_bounded(plane, &env, DEADLINE_SECS).await } else { eprintln!("desk lookup: breaker open"); None };
    let Some(ans) = asked else { if allowed_now { brk.fail(now); } let _ = rows(&c, &finish("unavailable")).await; return unavailable(&rid) };
    let now2 = now + started.elapsed().as_secs() as i64;
    match accept_for(&ans, cp_key, &rid, company, &fields, now, now2) {
        Ok(f) => {
            brk.ok();
            if rows(&c, &finish("answered")).await.is_err() { return unavailable(&rid); }
            out(StatusCode::OK, json!({"request_id": rid, "company_ref": company, "answered_at": now, "fields": f}))
        }
        Err(Reject::Refused) => { brk.ok(); let _ = rows(&c, &finish("refused")).await; out(StatusCode::FORBIDDEN, json!({"error": "control_plane_refused", "request_id": rid})) }
        Err(Reject::Unavailable) => { brk.fail(now); let _ = rows(&c, &finish("unavailable")).await; unavailable(&rid) }
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
    #[test] fn contract_copy_equals_the_gate_file() {
        let g = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../gates/DESK-LOOKUP-CONTRACT.json");
        if let Ok(t) = std::fs::read_to_string(&g) { assert_eq!(t, CONTRACT, "copy the gate file into server/contract/"); }
    }
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

    fn double_fn(sp: String, k: SigningKey) -> impl Fn(&str) -> Option<String> + Send + Sync + 'static {
        move |env| {
            let e: Value = serde_json::from_str(env).ok()?; let body = e["body"].as_str()?;
            let vk = VerifyingKey::from_bytes(&unhex(&sp)?.try_into().ok()?).ok()?;
            vk.verify(format!("{REQ_DOMAIN}\n{body}").as_bytes(), &Signature::from_slice(&unhex(e["sig"].as_str()?)?).ok()?).ok()?;
            let b: Value = serde_json::from_str(body).ok()?; if b["aud"] != "desk-lookup" { return None; }
            Some(answer(&k, b["request_id"].as_str()?, b["company_ref"].as_str()?, b["issued_at"].as_i64()?, json!({"service_state": "active", "usage_seats": 12, "unlisted_field": "x"}), false))
        }
    }
    /// REAL HTTP/3 loopback: our client (TLS 1.3, AES-256-GCM, X25519MLKEM768 only) -> a quinn/h3 server standing in for the Control Plane, signed request in, signed answer out.
    #[tokio::test] async fn real_h3_round_trip_to_a_control_plane_double() {
        let d = std::env::temp_dir().join(format!("deskcp-{}", std::process::id())); let _ = std::fs::create_dir_all(&d);
        let (kf, cf) = (d.join("k.pem"), d.join("c.pem"));
        let ok = std::process::Command::new("openssl").args(["req","-x509","-newkey","ec","-pkeyopt","ec_paramgen_curve:prime256v1","-nodes","-days","1","-subj","/CN=controlplane.test","-addext","subjectAltName=DNS:controlplane.test","-addext","basicConstraints=critical,CA:FALSE","-keyout",kf.to_str().unwrap(),"-out",cf.to_str().unwrap()]).output().map(|o| o.status.success()).unwrap_or(false);
        if !ok { eprintln!("no openssl: skipped"); return; }
        let (cert, key) = (std::fs::read(&cf).unwrap(), std::fs::read(&kf).unwrap());
        let ep = quinn::Endpoint::server(crate::h3::quic_config(crate::h3::server_config(&cert, &key).unwrap()).unwrap(), "127.0.0.1:0".parse().unwrap()).unwrap();
        let addr = ep.local_addr().unwrap();
        let s = Signer::from_seed_hex(SEED).unwrap(); let (k, p) = cp();
        let dbl = std::sync::Arc::new(double_fn(s.public_hex(), k));
        let router = axum::Router::new().route(CP_PATH, axum::routing::post(move |body: String| { let dbl = dbl.clone(); async move { match dbl(&body) { Some(a) => (StatusCode::OK, a), None => (StatusCode::FORBIDDEN, String::new()) } } }));
        tokio::spawn(crate::h3::serve(ep, router, "controlplane.test".into(), None));
        let plane = Plane::H3 { addr, host: "controlplane.test".into(), ca_pem: Some(cert.clone()) };
        let req = build_request(&s, RID, "emp-1", "acme-1234", "customer says mail is missing", &f(&["service_state"]), 1000);
        let ans = plane.ask(&req).await.expect("answer over real HTTP/3");
        assert_eq!(accept(&ans, &p, RID, "acme-1234", &f(&["service_state"]), 1005).unwrap()["service_state"], "active");
        assert!(plane.ask(&req.replace("acme-1234", "other-9999")).await.is_none(), "altered request: the Control Plane refuses");
        let untrusted = Plane::H3 { addr, host: "controlplane.test".into(), ca_pem: Some(Vec::new()) };
        assert!(untrusted.ask(&req).await.is_none(), "a Control Plane whose certificate we do not trust gets nothing");
    }
    #[test] fn answer_must_be_fresh_and_not_older_than_the_request() {
        let (k, p) = cp(); let req = f(&["service_state"]); let ok = json!({"service_state": "active"});
        let a = answer(&k, RID, "acme-1234", 1000, ok.clone(), false);
        assert!(accept(&a, &p, RID, "acme-1234", &req, 1000 + FRESH).is_ok(), "exactly at the limit");
        assert_eq!(accept(&a, &p, RID, "acme-1234", &req, 1000 + FRESH + 1), Err(Reject::Unavailable), "16 s old = refused (was 60 s)");
        assert_eq!(accept_for(&a, &p, RID, "acme-1234", &req, 1100, 1101), Err(Reject::Unavailable), "genuine but older than the request it claims to answer");
        assert!(accept_for(&a, &p, RID, "acme-1234", &req, 1002, 1005).is_ok(), "2 s clock skew allowed");
        assert_eq!(accept_for(&a, &p, RID, "acme-1234", &req, 1003, 1005), Err(Reject::Unavailable), "3 s older than the request");
        assert_eq!(accept(&answer(&k, RID, "acme-1234", 1006, ok, false), &p, RID, "acme-1234", &req, 1000), Err(Reject::Unavailable), "more than 5 s in the future");
    }
    #[test] fn breaker_opens_after_three_fails_probes_once_and_closes_on_success() {
        let b = Breaker::default();
        assert!(b.allow(100)); b.fail(100); b.fail(101); assert!(!b.is_open(101), "two failures: still closed");
        b.fail(102); assert!(b.is_open(102) && !b.allow(102) && !b.allow(110), "third failure opens it");
        assert!(b.allow(102 + BREAKER_OPEN), "after 15 s ONE probe goes out"); assert!(!b.allow(102 + BREAKER_OPEN), "and the gate shuts again until it reports");
        b.fail(102 + BREAKER_OPEN); assert!(b.is_open(102 + BREAKER_OPEN + 1), "a failed probe re-opens it");
        assert!(b.allow(102 + 2 * BREAKER_OPEN)); b.ok(); assert!(!b.is_open(102 + 2 * BREAKER_OPEN) && b.allow(102 + 2 * BREAKER_OPEN + 1), "a success closes it");
        let c = Breaker::default(); c.fail(0); c.fail(10); c.fail(31); assert!(!c.is_open(31), "failures older than the 30 s window do not count");
    }
    #[test] fn version_line_names_the_fail_closed_numbers() {
        let v = version_line(); assert!(v.starts_with("DESK BUILD ")); assert!(v.contains("fresh 15s") && v.contains("deadline 6s") && v.contains("breaker 3 fails/30s open 15s") && v.contains("no-store"), "{v}");
    }
    #[test] fn every_response_is_no_store_and_unavailable_has_no_data() {
        let r = unavailable("rid-1"); assert_eq!(r.status(), StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(r.headers().get(header::CACHE_CONTROL).unwrap(), "no-store");
        assert_eq!(out(StatusCode::OK, json!({})).headers().get(header::CACHE_CONTROL).unwrap(), "no-store");
    }
    #[tokio::test] async fn a_control_plane_that_never_answers_is_cut_at_the_deadline() {
        let d = std::env::temp_dir().join(format!("deskcp-hang-{}", std::process::id())); let _ = std::fs::create_dir_all(&d);
        let (kf, cf) = (d.join("k.pem"), d.join("c.pem"));
        let ok = std::process::Command::new("openssl").args(["req","-x509","-newkey","ec","-pkeyopt","ec_paramgen_curve:prime256v1","-nodes","-days","1","-subj","/CN=controlplane.test","-addext","subjectAltName=DNS:controlplane.test","-keyout",kf.to_str().unwrap(),"-out",cf.to_str().unwrap()]).output().map(|o| o.status.success()).unwrap_or(false);
        if !ok { eprintln!("no openssl: skipped"); return; }
        let (cert, key) = (std::fs::read(&cf).unwrap(), std::fs::read(&kf).unwrap());
        let ep = quinn::Endpoint::server(crate::h3::quic_config(crate::h3::server_config(&cert, &key).unwrap()).unwrap(), "127.0.0.1:0".parse().unwrap()).unwrap();
        let addr = ep.local_addr().unwrap();
        let router = axum::Router::new().route(CP_PATH, axum::routing::post(|_b: String| async { tokio::time::sleep(std::time::Duration::from_secs(60)).await; (StatusCode::OK, String::new()) }));
        tokio::spawn(crate::h3::serve(ep, router, "controlplane.test".into(), None));
        let plane = Plane::H3 { addr, host: "controlplane.test".into(), ca_pem: Some(cert) };
        let t = std::time::Instant::now();
        assert!(ask_bounded(&plane, "{}", 1).await.is_none(), "silence = no answer");
        assert!(t.elapsed().as_secs() < 3, "cut at the deadline, not after the 10 s inner timeout");
        // nothing listens at all: connection refused/timeout also ends as None within the deadline
        let dead = Plane::H3 { addr: "127.0.0.1:9".parse().unwrap(), host: "controlplane.test".into(), ca_pem: None };
        let t = std::time::Instant::now(); assert!(ask_bounded(&dead, "{}", 2).await.is_none()); assert!(t.elapsed().as_secs() < 4);
    }
    /// Rust -> PostgreSQL: audit line BEFORE the answer, outcome closed after, refusal and unavailable paths, on the scratch database (needs DESK_TEST_ADMIN_URL; skipped otherwise).
    #[tokio::test(flavor = "multi_thread")] async fn database_flow_audit_first_and_fail_closed() {
        let Ok(admin) = std::env::var("DESK_TEST_ADMIN_URL") else { eprintln!("no DESK_TEST_ADMIN_URL: skipped"); return; };
        let (a, conn) = tokio_postgres::connect(&admin, tokio_postgres::NoTls).await.unwrap(); tokio::spawn(conn);
        let q = |sql: String| { let a = &a; async move { crate::door::rows(a, &sql).await.unwrap() } };
        let sfx = &uuid4()[..8]; let h = "$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo";
        let o = q(format!("insert into desk.fadm_owner (email, display_name, role, pw_hash) values ('o-{sfx}@selftest.invalid','T Owner','owner','{h}') returning id::text")).await[0].get(0).unwrap().to_string();
        let mk = |tag: &str| format!("insert into desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) values ('{tag}-{sfx}@selftest.invalid','T {tag}','agent',NULL,true,'active',true) returning id::text");
        let agent = q(mk("a")).await[0].get(0).unwrap().to_string(); let loner = q(mk("l")).await[0].get(0).unwrap().to_string();
        q(format!("select desk.fadm_access_grant('{o}'::uuid, '{agent}'::uuid, desk.fadm_unit_id('department','desk'), 'agent')::text")).await;
        let sess = |who: String| { let q = &q; async move {
            let t = format!("{}{}", hex(&uuid4().into_bytes()).chars().take(32).collect::<String>(), hex(&uuid4().into_bytes()).chars().take(32).collect::<String>());
            q(format!("select desk.fadm_session_create('{who}'::uuid, '\\x{}'::bytea, 600)::text", hex(&crate::auth::token_hash(&t)))).await;
            let mut hd = HeaderMap::new(); hd.insert(header::AUTHORIZATION, format!("Bearer {t}").parse().unwrap()); hd } };
        let (h_agent, h_loner) = (sess(agent.clone()).await, sess(loner).await);
        q("alter role desk_app login password 'scratch'".to_string()).await;
        let url = format!("postgres://desk_app:scratch@{}/{}?sslmode=disable", admin.split('@').next_back().unwrap().split('/').next().unwrap(), admin.rsplit('/').next().unwrap());
        let f_ = std::env::temp_dir().join("desk-sign-test.seed"); std::fs::write(&f_, "0202020202020202020202020202020202020202020202020202020202020202").unwrap();
        unsafe { std::env::set_var("DESK_APP_URL", &url); std::env::set_var("DESK_SIGN_SEED_FILE", &f_); }
        crate::signed::init(); let sg = crate::signed::signer().expect("signer");
        let (k, p) = cp(); let plane = Plane::Double(Box::new(double_fn(sg.public_hex(), k)));
        let now = crate::signed::now_secs();
        let body = br#"{"company_ref":"acme-1234","reason":"customer says mail is missing","fields":["service_state","usage_seats"]}"#;
        let outcomes = |rid: String| { let q = &q; async move { q(format!("select outcome from desk.fadm_lookup where request_id='{rid}'::uuid order by id")).await.iter().map(|r| r.get(0).unwrap().to_string()).collect::<Vec<_>>() } };
        let rid_of = |r: Value| r["request_id"].as_str().unwrap().to_string();
        let jbody = |r: Response| async move { let st = r.status(); let b = axum::body::to_bytes(r.into_body(), 1 << 20).await.unwrap(); (st, serde_json::from_slice::<Value>(&b).unwrap()) };
        // 1) good path: 200, only the requested whitelist fields, audit line first then answered
        let (st, v) = jbody(run(&h_agent, body, &plane, &p, now, &Breaker::default()).await).await;
        assert_eq!(st, StatusCode::OK, "{v}"); assert_eq!(v["fields"]["service_state"], "active"); assert_eq!(v["fields"]["usage_seats"], 12); assert!(v["fields"].get("unlisted_field").is_none());
        assert_eq!(outcomes(rid_of(v)).await, vec!["requested", "answered"]);
        // 2) Control Plane not configured: unavailable, nothing shown, line closed as unavailable
        let (st, v) = jbody(run(&h_agent, body, &Plane::Off, &p, now, &Breaker::default()).await).await;
        assert_eq!(st, StatusCode::SERVICE_UNAVAILABLE); assert_eq!(v["error"], "data_unavailable"); assert!(v.get("fields").is_none());
        assert_eq!(outcomes(rid_of(v)).await, vec!["requested", "unavailable"]);
        // 3) answer signed by a key we do not trust: unavailable
        let (st, v) = jbody(run(&h_agent, body, &plane, &hex(SigningKey::from_bytes(&[9u8; 32]).verifying_key().as_bytes()), now, &Breaker::default()).await).await;
        assert_eq!(st, StatusCode::SERVICE_UNAVAILABLE); assert_eq!(outcomes(rid_of(v)).await, vec!["requested", "unavailable"]);
        // 4) a person with no access: refused by PostgreSQL, no lookup row at all
        let before = q("select count(*)::text from desk.fadm_lookup".to_string()).await[0].get(0).unwrap().to_string();
        let (st, _) = jbody(run(&h_loner, body, &plane, &p, now, &Breaker::default()).await).await; assert_eq!(st, StatusCode::FORBIDDEN);
        // 5) bad input never reaches the database; no session = 401
        let (st, _) = jbody(run(&h_agent, br#"{"company_ref":"x","reason":"short","fields":["service_state"]}"#, &plane, &p, now, &Breaker::default()).await).await; assert_eq!(st, StatusCode::UNPROCESSABLE_ENTITY);
        let (st, _) = jbody(run(&HeaderMap::new(), body, &plane, &p, now, &Breaker::default()).await).await; assert_eq!(st, StatusCode::UNAUTHORIZED);
        assert_eq!(q("select count(*)::text from desk.fadm_lookup".to_string()).await[0].get(0).unwrap(), before);
        // ---- D5a-5 (1i) ----
        let dbl_at = |delta: i64, other_company: bool| { let (sp, k2) = (sg.public_hex(), SigningKey::from_bytes(&[7u8; 32])); let _ = &k2; let key = cp().0; Plane::Double(Box::new(move |env| {
            let e: Value = serde_json::from_str(env).ok()?; let body = e["body"].as_str()?; let _ = &sp;
            let b: Value = serde_json::from_str(body).ok()?;
            Some(answer(&key, b["request_id"].as_str()?, if other_company { "other-9999" } else { b["company_ref"].as_str()? }, b["issued_at"].as_i64()? + delta, json!({"service_state": "active"}), false))
        })) };
        let unavailable_cases: Vec<(&str, Plane)> = vec![("old but genuine answer (30 s)", dbl_at(-30, false)), ("answer from the future (60 s)", dbl_at(60, false)), ("answer for another company", dbl_at(0, true))];
        for (name, pl) in unavailable_cases {
            let (st, v) = jbody(run(&h_agent, body, &pl, &p, now, &Breaker::default()).await).await;
            assert_eq!(st, StatusCode::SERVICE_UNAVAILABLE, "{name}"); assert_eq!(v["error"], "data_unavailable", "{name}"); assert!(v.get("fields").is_none(), "{name}");
            assert_eq!(outcomes(rid_of(v)).await, vec!["requested", "unavailable"], "{name}");
        }
        let (st, v) = jbody(run(&h_agent, body, &dbl_at(0, false), &p, now, &Breaker::default()).await).await; assert_eq!(st, StatusCode::OK, "a fresh answer still works: {v}");
        // breaker: three bad answers open it; while open the Control Plane is not asked (a double that would answer is never reached) and the line is still audited
        let bk = Breaker::default(); for _ in 0..3 { let _ = run(&h_agent, body, &Plane::Off, &p, now, &bk).await; }
        assert!(bk.is_open(now));
        let (st, v) = jbody(run(&h_agent, body, &dbl_at(0, false), &p, now, &bk).await).await;
        assert_eq!(st, StatusCode::SERVICE_UNAVAILABLE, "breaker open: unavailable at once even though the Control Plane could answer"); assert_eq!(outcomes(rid_of(v)).await, vec!["requested", "unavailable"]);
        let (st, _) = jbody(run(&h_agent, body, &dbl_at(0, false), &p, now + BREAKER_OPEN + 1, &bk).await).await; assert_eq!(st, StatusCode::OK, "half-open probe succeeds and closes the breaker");
        assert!(!bk.is_open(now + BREAKER_OPEN + 1));
        // D20 database down BEFORE the audit line: same unavailable shape, no fields, no row
        let good_url = std::env::var("DESK_APP_URL").unwrap();
        q("select pg_terminate_backend(pid)::text from pg_stat_activity where usename = 'desk_app'".to_string()).await; tokio::time::sleep(std::time::Duration::from_millis(500)).await;
        unsafe { std::env::set_var("DESK_APP_URL", "postgres://desk_app:x@127.0.0.1:1/none?sslmode=disable"); }
        let rows_before = q("select count(*)::text from desk.fadm_lookup".to_string()).await[0].get(0).unwrap().to_string();
        let (st, v) = jbody(run(&h_agent, body, &plane, &p, now, &Breaker::default()).await).await;
        unsafe { std::env::set_var("DESK_APP_URL", &good_url); }
        assert_eq!(st, StatusCode::SERVICE_UNAVAILABLE); assert_eq!(v["error"], "data_unavailable"); assert!(v.get("fields").is_none());
        assert_eq!(q("select count(*)::text from desk.fadm_lookup".to_string()).await[0].get(0).unwrap(), rows_before);
        // D20 database LOST between the audit line and its closing: the answer is NOT shown, the line stays requested (the AD4b sweep makes it abandoned)
        let adm = std::sync::Arc::new({ let (c2, cn) = tokio_postgres::connect(&admin, tokio_postgres::NoTls).await.unwrap(); tokio::spawn(cn); c2 });
        let (k9, _) = cp(); let key9 = k9;
        let killer = Plane::Double(Box::new(move |env| {
            let e: Value = serde_json::from_str(env).ok()?; let b: Value = serde_json::from_str(e["body"].as_str()?).ok()?;
            let a2 = adm.clone();
            tokio::task::block_in_place(|| tokio::runtime::Handle::current().block_on(a2.simple_query("select pg_terminate_backend(pid) from pg_stat_activity where usename = 'desk_app' and pid <> pg_backend_pid()"))).ok()?;
            Some(answer(&key9, b["request_id"].as_str()?, b["company_ref"].as_str()?, b["issued_at"].as_i64()?, json!({"service_state": "active"}), false))
        }));
        let (st, v) = jbody(run(&h_agent, body, &killer, &p, now, &Breaker::default()).await).await;
        assert_eq!(st, StatusCode::SERVICE_UNAVAILABLE, "{v}"); assert_eq!(v["error"], "data_unavailable"); assert!(v.get("fields").is_none(), "no answer is shown when the audit line cannot be closed");
        let rid = v["request_id"].as_str().unwrap().to_string();
        assert_eq!(outcomes(rid).await, vec!["requested"], "the line is left open, never 'answered'");
    }
}
