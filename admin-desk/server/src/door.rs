// ANEXOMAIL ADMIN DESK door.rs (R3a2-3, 21 Nov 2026): the Desk's OWN login door. /desk/v1/auth/login, /me, /logout.
// ARGON2ID check (auth.rs) -> session row in desk.fadm_session (SHA-256 of the token only) -> HttpOnly Secure SameSite=Strict cookie `anexo.desk.session` (audience "desk").
// Talks to PostgreSQL ONLY as the role desk_app (DESK_APP_URL), only schema desk. Never imports founder or awam code.
// Speed: ONE long-lived database connection (opened at start-up), a login = 2 round trips (lookup, then fadm_session_create). simple_query only, so a transaction-mode pooler works.
use crate::auth;
use axum::{extract::Request, http::{header, HeaderMap, HeaderValue, StatusCode}, response::{IntoResponse, Response}, Json};
use serde::Deserialize;
use std::{collections::HashMap, sync::Mutex, time::{Duration, Instant}};
use tokio_postgres::{AsyncMessage, Client, Config, NoTls};

/// B9c (1m-9): the in-process bus a PostgreSQL NOTIFY on `desk_plans` (a plan release, sent at COMMIT) wakes. Every open live stream session subscribes and re-reads at once.
pub fn plans_bus() -> &'static tokio::sync::broadcast::Sender<()> {
    static BUS: std::sync::OnceLock<tokio::sync::broadcast::Sender<()>> = std::sync::OnceLock::new();
    BUS.get_or_init(|| tokio::sync::broadcast::channel(16).0)
}
/// Drives a connection; with `listen` every NOTIFY on desk_plans pings the bus.
async fn drive<S, T>(mut conn: tokio_postgres::Connection<S, T>, listen: bool)
where S: tokio::io::AsyncRead + tokio::io::AsyncWrite + Unpin, T: tokio::io::AsyncRead + tokio::io::AsyncWrite + Unpin {
    while let Some(m) = futures_util::future::poll_fn(|cx| conn.poll_message(cx)).await {
        match m { Ok(AsyncMessage::Notification(n)) => { if listen && n.channel() == "desk_plans" { let _ = plans_bus().send(()); } } Ok(_) => {} Err(_) => break }
    }
}
/// Keeps ONE dedicated connection LISTENing on desk_plans (reconnects with backoff, and pings the bus after every reconnect so no release is missed).
pub async fn listen_plans() {
    let mut wait = 1u64;
    loop {
        match open(true).await {
            Ok(c) => match c.batch_execute("LISTEN desk_plans").await {
                Ok(()) => { wait = 1; let _ = plans_bus().send(()); eprintln!("desk plans: LISTEN desk_plans ready"); while !c.is_closed() { tokio::time::sleep(Duration::from_secs(2)).await; } }
                Err(e) => eprintln!("desk plans: LISTEN failed: {e}"),
            },
            Err(e) => eprintln!("desk plans: listener connection failed: {e}"),
        }
        tokio::time::sleep(Duration::from_secs(wait)).await; wait = (wait * 2).min(30);
    }
}

pub const COOKIE: &str = "anexo.desk.session";
const TTL_SECS: i64 = 12 * 3600;
const MAX_FAILS: u32 = 5;
const WINDOW: Duration = Duration::from_secs(15 * 60);
static FAILS: Mutex<Option<HashMap<String, (u32, Instant)>>> = Mutex::new(None);

async fn open(listen: bool) -> Result<Client, String> {
    let url = std::env::var("DESK_APP_URL").map_err(|_| "DESK_APP_URL not set".to_string())?;
    let cfg: Config = url.parse().map_err(|_| "DESK_APP_URL is not a valid postgres url".to_string())?;
    if cfg.get_ssl_mode() == tokio_postgres::config::SslMode::Disable {
        let (c, conn) = cfg.connect(NoTls).await.map_err(|e| e.to_string())?;
        tokio::spawn(drive(conn, listen)); return Ok(c);
    }
    let mut roots = rustls::RootCertStore::empty();
    for c in rustls_native_certs::load_native_certs().certs { let _ = roots.add(c); }
    // DESK_DB_CA: the database's own CA (PEM), when its certificate is not signed by a public root (written by desk-appdb.sh, root-only).
    if let Ok(p) = std::env::var("DESK_DB_CA") {
        let pem = std::fs::read(&p).map_err(|e| format!("DESK_DB_CA {p}: {e}"))?;
        for c in rustls_pemfile::certs(&mut pem.as_slice()).flatten() { roots.add(c).map_err(|e| format!("DESK_DB_CA cert: {e}"))?; }
    }
    let tls = rustls::ClientConfig::builder_with_provider(std::sync::Arc::new(rustls::crypto::ring::default_provider()))
        .with_safe_default_protocol_versions().map_err(|e| e.to_string())?.with_root_certificates(roots).with_no_client_auth();
    let (c, conn) = cfg.connect(tokio_postgres_rustls::MakeRustlsConnect::new(tls)).await.map_err(|e| { let mut m = e.to_string(); let mut s: Option<&dyn std::error::Error> = std::error::Error::source(&e); while let Some(x) = s { m.push_str(": "); m.push_str(&x.to_string()); s = x.source(); } m })?;
    tokio::spawn(drive(conn, listen)); Ok(c)
}
static DB: tokio::sync::Mutex<Option<std::sync::Arc<Client>>> = tokio::sync::Mutex::const_new(None);
pub async fn connect() -> Result<std::sync::Arc<Client>, String> {
    let mut g = DB.lock().await;
    if let Some(c) = g.as_ref() { if !c.is_closed() { return Ok(c.clone()); } }
    let c = std::sync::Arc::new(open(false).await?); *g = Some(c.clone()); Ok(c)
}
pub async fn warm() { match connect().await { Ok(_) => eprintln!("desk door: database connection ready (role desk_app)"), Err(e) => eprintln!("desk door: database not ready yet: {e}") } }
// every value below is validated or generated here (hex token hash, uuid, allowlisted email), so no prepared statement is needed.
pub(crate) fn lit(s: &str) -> String { format!("'{}'", s.replace('\'', "''")) }
fn email_ok(e: &str) -> bool { e.len() <= 200 && e.contains('@') && e.bytes().all(|b| b.is_ascii_alphanumeric() || b"._%+-@".contains(&b)) }
fn hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
pub(crate) async fn rows(c: &Client, q: &str) -> Result<Vec<tokio_postgres::SimpleQueryRow>, tokio_postgres::Error> {
    Ok(c.simple_query(q).await?.into_iter().filter_map(|m| if let tokio_postgres::SimpleQueryMessage::Row(r) = m { Some(r) } else { None }).collect())
}

fn throttled(key: &str) -> bool {
    let mut g = FAILS.lock().unwrap(); let m = g.get_or_insert_with(HashMap::new);
    match m.get(key) { Some((n, t)) if t.elapsed() < WINDOW => *n >= MAX_FAILS, _ => false }
}
fn fail(key: &str) { let mut g = FAILS.lock().unwrap(); let m = g.get_or_insert_with(HashMap::new);
    let e = m.entry(key.to_string()).or_insert((0, Instant::now())); if e.1.elapsed() >= WINDOW { *e = (0, Instant::now()); } e.0 += 1; }
fn clear(key: &str) { if let Some(m) = FAILS.lock().unwrap().as_mut() { m.remove(key); } }

pub fn cookie_token(h: &HeaderMap) -> Option<String> {
    let raw = h.get(header::COOKIE)?.to_str().ok()?;
    raw.split(';').filter_map(|p| p.trim().split_once('=')).find(|(k, _)| *k == COOKIE).map(|(_, v)| v.to_string()).filter(|v| v.len() == 64 && v.bytes().all(|b| b.is_ascii_hexdigit()))
}
fn set_cookie(token: &str, max_age: i64) -> HeaderValue {
    HeaderValue::from_str(&format!("{COOKIE}={token}; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age={max_age}")).unwrap()
}
fn json(status: StatusCode, body: serde_json::Value) -> Response { (status, [(header::CONTENT_TYPE, "application/json")], body.to_string()).into_response() }

#[derive(Deserialize)] pub struct Login { email: String, password: String }

pub async fn login(Json(b): Json<Login>) -> Response {
    let email = b.email.trim().to_lowercase();
    if !email_ok(&email) || b.password.len() > 256 { return json(StatusCode::UNAUTHORIZED, serde_json::json!({"error":"bad_credentials"})); }
    if throttled(&email) { return json(StatusCode::TOO_MANY_REQUESTS, serde_json::json!({"error":"too_many_attempts"})); }
    let c = match connect().await { Ok(c) => c, Err(e) => { eprintln!("desk door: db: {e}"); return json(StatusCode::SERVICE_UNAVAILABLE, serde_json::json!({"error":"db_unavailable"})); } };
    let row = rows(&c, &format!("select id::text, pw_hash, passkey_required::text from desk.fadm_login_lookup({})", lit(&email))).await.ok().and_then(|v| v.into_iter().next());
    let stored: Option<String> = row.as_ref().and_then(|r| r.get(1)).map(str::to_string);
    let pw = b.password.clone();
    let ok = tokio::task::spawn_blocking(move || auth::verify_password(&pw, stored.as_deref())).await.unwrap_or(false);
    let Some(row) = row.filter(|_| ok) else { fail(&email); return json(StatusCode::UNAUTHORIZED, serde_json::json!({"error":"bad_credentials"})); };
    let owner = row.get(0).unwrap_or("").to_string();
    if owner.len() != 36 || !owner.bytes().all(|b| b.is_ascii_hexdigit() || b == b'-') { return json(StatusCode::SERVICE_UNAVAILABLE, serde_json::json!({"error":"db_unavailable"})); }
    if row.get(2) == Some("true") { return json(StatusCode::FORBIDDEN, serde_json::json!({"error":"passkey_required"})); }
    clear(&email);
    let (token, th) = auth::new_token();
    if let Err(e) = rows(&c, &format!("select desk.fadm_session_create('{owner}'::uuid, '\\x{}'::bytea, {TTL_SECS})::text", hex(&th))).await { eprintln!("desk door: session create: {e}"); return json(StatusCode::SERVICE_UNAVAILABLE, serde_json::json!({"error":"db_unavailable"})); }
    let mut resp = json(StatusCode::OK, serde_json::json!({"token": token, "expires_in": TTL_SECS}));
    resp.headers_mut().insert(header::SET_COOKIE, set_cookie(&token, TTL_SECS));
    if let Some((k, v)) = crate::dbsc::registration_header(&th) { resp.headers_mut().insert(k, v); }   // R3a2-dbsc D1: the browser may now bind this session to its device key
    resp
}

// R3d: the kernel's bearer token comes FIRST (it is the one the request MAC is keyed on), the HttpOnly cookie second.
pub fn token_of(h: &HeaderMap) -> Option<String> {
    h.get(header::AUTHORIZATION).and_then(|v| v.to_str().ok()).and_then(|v| v.strip_prefix("Bearer ")).map(str::to_string).filter(|v| v.len() == 64 && v.bytes().all(|b| b.is_ascii_hexdigit())).or_else(|| cookie_token(h))
}

pub async fn me(req: Request) -> Response {
    let Some(t) = token_of(req.headers()) else { return json(StatusCode::UNAUTHORIZED, serde_json::json!({"error":"no_session"})) };
    if !crate::dbsc::enforce_ok(req.headers(), &auth::token_hash(&t)).await { return json(StatusCode::UNAUTHORIZED, serde_json::json!({"error":"dbsc_required"})); }
    let Ok(c) = connect().await else { return json(StatusCode::SERVICE_UNAVAILABLE, serde_json::json!({"error":"db_unavailable"})) };
    match rows(&c, &format!("select email, display_name, role, expires_at::text from desk.fadm_session_lookup('\\x{}'::bytea)", hex(&auth::token_hash(&t)))).await {
        Ok(v) => match v.first() {
            Some(r) => json(StatusCode::OK, serde_json::json!({"email": r.get(0), "name": r.get(1), "role": r.get(2), "expires_at": r.get(3), "aud": auth::AUD})),
            None => json(StatusCode::UNAUTHORIZED, serde_json::json!({"error":"no_session"})) },
        Err(_) => json(StatusCode::SERVICE_UNAVAILABLE, serde_json::json!({"error":"db_unavailable"})),
    }
}

pub async fn logout(req: Request) -> Response {
    let mut resp = json(StatusCode::OK, serde_json::json!({"ok": true}));
    resp.headers_mut().insert(header::SET_COOKIE, set_cookie("", 0));
    if let (Some(t), Ok(c)) = (token_of(req.headers()), connect().await) { let _ = rows(&c, &format!("select desk.fadm_session_revoke('\\x{}'::bytea)::text", hex(&auth::token_hash(&t)))).await; }
    resp
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn cookie_parse_needs_exact_name_and_64_hex() {
        let mut h = HeaderMap::new(); let t = "a".repeat(64);
        h.insert(header::COOKIE, HeaderValue::from_str(&format!("x=1; {COOKIE}={t}; y=2")).unwrap()); assert_eq!(cookie_token(&h), Some(t));
        let mut hdr_b = HeaderMap::new(); hdr_b.insert(header::COOKIE, HeaderValue::from_str("anexo.desk.session=short").unwrap()); assert_eq!(cookie_token(&hdr_b), None);
        let mut hdr_c = HeaderMap::new(); hdr_c.insert(header::COOKIE, HeaderValue::from_str(&format!("anexo.founder.session={}", "b".repeat(64))).unwrap()); assert_eq!(cookie_token(&hdr_c), None);
    }
    #[test] fn throttle_after_five_fails() { let k = "t@x.test"; clear(k); for _ in 0..5 { assert!(!throttled(k)); fail(k); } assert!(throttled(k)); clear(k); assert!(!throttled(k)); }
    #[test] fn email_allowlist_blocks_sql() { assert!(email_ok("a.b+c@anexomail.com")); assert!(!email_ok("a'; drop table x;--@b")); assert!(!email_ok("a b@c")); assert_eq!(lit("o'k"), "'o''k'"); }
    #[test] fn cookie_is_httponly_secure_strict() { let c = set_cookie(&"c".repeat(64), 60); let s = c.to_str().unwrap(); assert!(s.contains("HttpOnly") && s.contains("Secure") && s.contains("SameSite=Strict")); }
}
