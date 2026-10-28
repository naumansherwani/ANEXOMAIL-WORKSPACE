//! anexomail-founder — F1b foundation: sirf health + military-level headers. Login/RPC agle phases mein.
#[allow(dead_code)]
#[path = "../../rust/jwt_core.rs"]
mod jwt_core;
mod audit;
mod gate;
mod sign;
mod bridge;
mod data;
mod login;
mod actions;

use axum::{Json, Router, extract::State, http::{HeaderMap, HeaderName, HeaderValue, StatusCode}, response::IntoResponse, routing::get};
use serde_json::{Value, json};
use std::sync::Arc;
use tokio::sync::RwLock;
use tower_http::set_header::SetResponseHeaderLayer;

fn hdr(n: &'static str, v: &'static str) -> SetResponseHeaderLayer<HeaderValue> {
    SetResponseHeaderLayer::overriding(HeaderName::from_static(n), HeaderValue::from_static(v))
}

pub struct St { pub sb: Option<data::Sb>, pub hmac_key: Vec<u8>, pub jwks: RwLock<Vec<jwt_core::Jwk>>, pub lim: std::sync::Mutex<login::Limiter> }
type S = Arc<St>;

fn now_s() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }

/// Jawab: {data, ts, sig} — sig = HMAC(key, ts.sha256(data)); kernel browser mein verify karta hai.
fn signed(st: &St, data: Value) -> axum::response::Response {
    let ts = now_s();
    let txt = serde_json::to_string(&data).unwrap_or_default();
    let sig = sign::sign(&st.hmac_key, ts, &txt);
    Json(json!({"data": data, "ts": ts, "sig": sig})).into_response()
}

async fn authed(st: &St, h: &HeaderMap) -> Result<jwt_core::Claims, StatusCode> {
    let Some(sb) = &st.sb else { return Err(StatusCode::SERVICE_UNAVAILABLE) };
    let tok = gate::bearer(h.get("authorization").and_then(|v| v.to_str().ok())).ok_or(StatusCode::UNAUTHORIZED)?;
    let iss = format!("{}/auth/v1", sb.url);
    let mut v = gate::verify_token(tok, &st.jwks.read().await, &iss, now_s());
    if matches!(v, Err(jwt_core::JwtErr::UnknownKid)) {
        *st.jwks.write().await = sb.jwks().await; // key rotation
        v = gate::verify_token(tok, &st.jwks.read().await, &iss, now_s());
    }
    let claims = match v { Ok(c) => c, Err(_) => return Err(StatusCode::UNAUTHORIZED) };
    let founder = sb.is_founder(&claims.sub).await;
    match gate::decide(Ok(claims), |_| founder) {
        gate::Gate::Ok(c) => Ok(c),
        gate::Gate::Forbidden => Err(StatusCode::FORBIDDEN),
        gate::Gate::Unauthorized => Err(StatusCode::UNAUTHORIZED),
    }
}

async fn me(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    match authed(&st, &h).await {
        Ok(c) => signed(&st, json!({"uid": c.sub, "email": c.email, "founder": true})),
        Err(code) => code.into_response(),
    }
}

async fn bridge_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    let path = std::env::var("EXPIRY_WATCH_FILE").unwrap_or_else(|_| "/var/lib/anexomail/expiry-watch.json".into());
    let (accs, target, queue, leads, expiry) = tokio::join!(
        sb.rows("revenue_accounts?select=status,mrr_gbp"),
        sb.rows("revenue_targets?select=target_gbp&order=month.desc&limit=1"),
        sb.count("mail_outbox?select=id&state=in.(queued,failed)"),
        sb.count("revenue_leads?select=id&stage=eq.new"),
        read_expiry(&path),
    );
    let tgt = target.and_then(|r| r.first().cloned()).and_then(|r| r.get("target_gbp").and_then(|v| v.as_f64().or_else(|| v.as_str().and_then(|s| s.parse().ok()))));
    signed(&st, json!({
        "money": bridge::money(accs.as_deref(), tgt),
        "trouble": bridge::trouble(queue, expiry.as_ref()),
        "voice": bridge::voice(leads),
    }))
}

async fn read_expiry(path: &str) -> Option<Value> {
    let text = tokio::fs::read_to_string(path).await.ok()?;
    let mut v: Value = serde_json::from_str(&text).ok()?;
    let age = tokio::fs::metadata(path).await.ok()?.modified().ok()?.elapsed().ok()?.as_secs();
    if let Some(o) = v.as_object_mut() { o.insert("available".into(), json!(true)); o.insert("stale".into(), json!(age > 36 * 3600)); o.insert("age_secs".into(), json!(age)); }
    Some(v)
}


#[derive(serde::Deserialize)]
struct LoginIn { email: String, password: String }

async fn login_ep(State(st): State<S>, Json(b): Json<LoginIn>) -> axum::response::Response {
    let Some(sb) = &st.sb else { return StatusCode::SERVICE_UNAVAILABLE.into_response() };
    let email = b.email.trim().to_lowercase();
    let deny = || (StatusCode::FORBIDDEN, Json(json!({"error": "inkar"}))).into_response(); // hamesha ek hi jawab: kaun sa hissa ghalat, nahi batate
    if !login::valid_email(&email) || b.password.is_empty() || b.password.len() > 256 { return deny(); }
    let now = std::time::Instant::now();
    if st.lim.lock().unwrap().locked(&email, now) { return (StatusCode::TOO_MANY_REQUESTS, Json(json!({"error": "bohat koshishen, 15 min baad"}))).into_response(); }
    let r = sb.http.post(format!("{}/auth/v1/token?grant_type=password", sb.url))
        .header("apikey", &sb.key).json(&json!({"email": email, "password": b.password})).send().await;
    let ok = match r { Ok(r) if r.status().is_success() => r.json::<Value>().await.ok(), _ => None };
    let Some(tok) = ok else { st.lim.lock().unwrap().fail(&email, now); return deny(); };
    let (Some(access), Some(uid)) = (tok["access_token"].as_str(), tok["user"]["id"].as_str()) else { return deny(); };
    if !sb.is_founder(uid).await { st.lim.lock().unwrap().fail(&email, now); return deny(); } // awam user: token phenk do
    st.lim.lock().unwrap().clear(&email);
    Json(json!({"access_token": access, "expires_in": tok["expires_in"], "passkey": "pending_F1a"})).into_response()
}


async fn actions_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    match sb.rows("founder_actions?select=key,deck,title,summary,danger,enabled,reversible&order=deck,key").await {
        Some(rows) => signed(&st, json!({"connected": true, "actions": rows})),
        None => signed(&st, json!({"connected": false, "note": "founder_actions nahi mili — E102 SQL chalayein (sql-run.sh)"})),
    }
}

async fn audit_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    let (rows, bad, head) = tokio::join!(
        sb.rows("founder_audit?select=seq,ts_ms,action,target,reason,hash,prev_hash&order=seq.desc&limit=15"),
        sb.rpc("founder_audit_verify", json!({"p_from": 1})),
        sb.rpc("founder_audit_head", json!({})),
    );
    match rows {
        None => signed(&st, json!({"connected": false, "note": "founder_audit nahi mili — E102 SQL chalayein (sql-run.sh)"})),
        Some(rows) => signed(&st, json!({"connected": true, "entries": rows, "head": head, "chain_ok": bad.as_ref().map(|v| v.is_null()), "first_bad_seq": bad})),
    }
}

#[derive(serde::Deserialize)]
struct ActIn { key: String, reason: String }

async fn action_ep(State(st): State<S>, h: HeaderMap, Json(b): Json<ActIn>) -> axum::response::Response {
    let c = match authed(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    let sb = st.sb.as_ref().unwrap();
    if !actions::valid_key(&b.key) { return (StatusCode::BAD_REQUEST, Json(json!({"error": "action ka naam ghalat"}))).into_response(); }
    let Some(reason) = actions::clean_reason(&b.reason) else { return (StatusCode::BAD_REQUEST, Json(json!({"error": "wajah kam az kam 8 akshar"}))).into_response(); };
    let row = sb.rows(&format!("founder_actions?select=key,enabled,danger&key=eq.{}&limit=1", b.key)).await.and_then(|r| r.into_iter().next());
    let Some(row) = row else { return (StatusCode::NOT_FOUND, Json(json!({"error": "yeh action catalogue mein nahi"}))).into_response(); };
    let enabled = row["enabled"].as_bool().unwrap_or(false);
    // koshish HAMESHA audit mein (chalna ho ya na chalna): kis ne, kya, kyun
    let a = sb.rpc("founder_audit_append", json!({"p_actor": c.sub, "p_action": format!("attempt.{}", b.key), "p_target": b.key, "p_reason": reason, "p_meta": {"enabled": enabled, "danger": row["danger"]}})).await;
    let Some(a) = a else { return (StatusCode::BAD_GATEWAY, Json(json!({"error": "audit likha nahi ja saka — action roka gaya"}))).into_response(); };
    // executor F8 mein: tab tak chalta nahi (koi side-effect nahi)
    (StatusCode::CONFLICT, Json(json!({"error": "executor abhi nahi (F8) — sirf koshish audit mein likhi gayi", "audit": a}))).into_response()
}

pub fn app(st: S) -> Router {
    let static_dir = std::env::var("FOUNDER_STATIC").unwrap_or_else(|_| "/opt/anexomail-founder/web".into());
    Router::new()
        .route("/healthz", get(|| async { "ok" }))
        .route("/founder/v1/login", axum::routing::post(login_ep))
        .route("/founder/v1/me", get(me))
        .route("/founder/v1/bridge", get(bridge_ep))
        .route("/founder/v1/actions", get(actions_ep))
        .route("/founder/v1/audit", get(audit_ep))
        .route("/founder/v1/action", axum::routing::post(action_ep))
        .fallback_service(tower_http::services::ServeDir::new(static_dir).append_index_html_on_directories(true))
        .with_state(st)
        .layer(hdr("content-security-policy", "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'; require-trusted-types-for 'script'"))
        .layer(hdr("strict-transport-security", "max-age=63072000; includeSubDomains; preload"))
        .layer(hdr("x-content-type-options", "nosniff"))
        .layer(hdr("referrer-policy", "no-referrer"))
        .layer(hdr("cross-origin-opener-policy", "same-origin"))
        .layer(hdr("cross-origin-embedder-policy", "require-corp"))
        .layer(hdr("cache-control", "no-store"))
}

#[tokio::main]
async fn main() {
    let sb = data::Sb::from_env();
    let key = std::env::var("FOUNDER_HMAC_KEY").expect("FOUNDER_HMAC_KEY lazmi (kam az kam 32 bytes)");
    assert!(key.len() >= 32, "FOUNDER_HMAC_KEY chhoti hai");
    let jwks = match &sb { Some(s) => s.jwks().await, None => vec![] };
    let st = Arc::new(St { sb, hmac_key: key.into_bytes(), jwks: RwLock::new(jwks), lim: Default::default() });
    let addr = std::env::var("FOUNDER_BIND").unwrap_or_else(|_| "127.0.0.1:3210".into());
    let l = tokio::net::TcpListener::bind(&addr).await.expect("bind");
    axum::serve(l, app(st)).await.expect("serve");
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{body::Body, http::Request};
    use tower::ServiceExt;
    #[tokio::test]
    async fn health_has_hardening_headers() {
        let r = app(Arc::new(St{sb:None,hmac_key:b"k".to_vec(),jwks:RwLock::new(vec![]),lim:Default::default()})).oneshot(Request::get("/healthz").body(Body::empty()).unwrap()).await.unwrap();
        assert_eq!(r.status(), 200);
        let h = r.headers();
        assert!(h["content-security-policy"].to_str().unwrap().contains("frame-ancestors 'none'"));
        assert_eq!(h["cache-control"], "no-store");
    }

    fn st_with_sb() -> S {
        let sb = data::Sb { url: "http://127.0.0.1:1".into(), key: "k".into(), http: reqwest::Client::new() };
        Arc::new(St { sb: Some(sb), hmac_key: b"k".to_vec(), jwks: RwLock::new(vec![]), lim: Default::default() })
    }
    #[tokio::test]
    async fn founder_routes_need_bearer() {
        for path in ["/founder/v1/me", "/founder/v1/bridge", "/founder/v1/actions", "/founder/v1/audit"] {
            let r = app(st_with_sb()).oneshot(Request::get(path).body(Body::empty()).unwrap()).await.unwrap();
            assert_eq!(r.status(), 401, "{path}");
            let r = app(st_with_sb()).oneshot(Request::get(path).header("authorization", "Bearer a.b.c").body(Body::empty()).unwrap()).await.unwrap();
            assert_eq!(r.status(), 401, "{path} junk token");
        }
    }
    #[tokio::test]
    async fn unconfigured_is_503_not_open() {
        let st = Arc::new(St { sb: None, hmac_key: b"k".to_vec(), jwks: RwLock::new(vec![]), lim: Default::default() });
        let r = app(st).oneshot(Request::get("/founder/v1/me").header("authorization", "Bearer a.b.c").body(Body::empty()).unwrap()).await.unwrap();
        assert_eq!(r.status(), 503);
    }
    #[tokio::test]
    async fn action_post_needs_bearer() {
        let r = app(st_with_sb()).oneshot(Request::post("/founder/v1/action").header("content-type", "application/json").body(Body::from(r#"{"key":"release.pull_web","reason":"test wajah"}"#)).unwrap()).await.unwrap();
        assert_eq!(r.status(), 401);
    }
}
