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
mod ftoken;
mod polar;
mod settings;
mod authcache;
mod hostproof;

use axum::{Json, Router, extract::State, http::{HeaderMap, HeaderName, HeaderValue, StatusCode}, response::IntoResponse, routing::get};
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD as B64};
use serde_json::{Value, json};
use std::sync::Arc;
use tokio::sync::RwLock;
use tower_http::set_header::SetResponseHeaderLayer;

fn hdr(n: &'static str, v: &'static str) -> SetResponseHeaderLayer<HeaderValue> {
    SetResponseHeaderLayer::overriding(HeaderName::from_static(n), HeaderValue::from_static(v))
}

pub struct St { pub sb: Option<data::Sb>, pub hmac_key: Vec<u8>, pub jwks: RwLock<Vec<jwt_core::Jwk>>, pub lim: std::sync::Mutex<login::Limiter>, pub ft: Option<ftoken::Keys>, pub legacy: bool, pub polar: Arc<polar::Live>, pub hook: std::sync::Mutex<Option<(i64, Value)>>, pub ed: Option<sign::EdKeys>, pub reqsig: bool, pub gate: authcache::AuthCache }
type S = Arc<St>;

fn now_s() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }

/// Jawab: {data, ts, sig} — sig = HMAC(key, ts.sha256(data)); kernel browser mein verify karta hai.
fn signed(st: &St, data: Value) -> axum::response::Response {
    let ts = now_s();
    let txt = serde_json::to_string(&data).unwrap_or_default();
    let sig = sign::sign(&st.hmac_key, ts, &txt);
    // F2a: Ed25519 over the same message. `sig` (HMAC) stays until the browser kernel (F2b) verifies Ed25519 and enforces it.
    match &st.ed {
        Some(ed) => Json(json!({"data": data, "ts": ts, "sig": sig, "alg": "ed25519", "kid": sign::ED_KID, "sig_ed": ed.sign(ts, &txt)})).into_response(),
        None => Json(json!({"data": data, "ts": ts, "sig": sig})).into_response(),
    }
}

/// Public verification key (public by design). The kernel in the browser (F2b) pins it; the private key never leaves the server.
async fn keys_ep(State(st): State<S>) -> axum::response::Response {
    match &st.ed {
        Some(ed) => Json(json!({"alg": "ed25519", "kid": sign::ED_KID, "public_key": ed.public_b64(), "message": "<ts>.<sha256hex(data_json)>"})).into_response(),
        None => (StatusCode::SERVICE_UNAVAILABLE, Json(json!({"error": "signing key not configured"}))).into_response(),
    }
}

/// Write requests (POST/PUT) must carry x-fo-ts + x-fo-sig made with the per-token key from the exchange answer.
/// Legacy session tokens (grace) have no such key and are only accepted while FOUNDER_LEGACY_TOKEN != 0 (authed() already decided that).
fn write_ok(st: &St, h: &HeaderMap, method: &str, path: &str, body: &[u8]) -> Result<(), axum::response::Response> {
    if !st.reqsig { return Ok(()); }
    let Some(tok) = gate::bearer(h.get("authorization").and_then(|v| v.to_str().ok())) else { return Err(StatusCode::UNAUTHORIZED.into_response()) };
    if !ftoken::looks_founder(tok) { return Ok(()); }
    let ts = h.get("x-fo-ts").and_then(|v| v.to_str().ok()).and_then(|v| v.parse::<i64>().ok());
    let sig = h.get("x-fo-sig").and_then(|v| v.to_str().ok());
    let key = sign::req_key(&st.hmac_key, tok);
    match (ts, sig) {
        (Some(ts), Some(sig)) if sign::req_verify(&key, method, path, ts, body, sig, now_s()) => Ok(()),
        _ => Err((StatusCode::UNAUTHORIZED, Json(json!({"error": "request signature missing or invalid"}))).into_response()),
    }
}

/// Supabase (awam-session) token verify + founder check. `exchange` sirf isi se andar aata hai (founder token se nahi).
async fn authed_session(st: &St, h: &HeaderMap) -> Result<jwt_core::Claims, StatusCode> {
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

/// Har founder endpoint ka darwaza: (1) founder token (aud=anexo-founder, device ab bhi approved) YA (2) grace mein purana session token (FOUNDER_LEGACY_TOKEN=0 par band).
async fn authed(st: &St, h: &HeaderMap) -> Result<jwt_core::Claims, StatusCode> { authed_with(st, h, false).await }
/// Writes (PUT/POST) always ask the database fresh: no cache, a revoke is honoured at once.
async fn authed_w(st: &St, h: &HeaderMap) -> Result<jwt_core::Claims, StatusCode> { authed_with(st, h, true).await }
async fn authed_with(st: &St, h: &HeaderMap, fresh: bool) -> Result<jwt_core::Claims, StatusCode> {
    let Some(sb) = &st.sb else { return Err(StatusCode::SERVICE_UNAVAILABLE) };
    let tok = gate::bearer(h.get("authorization").and_then(|v| v.to_str().ok())).ok_or(StatusCode::UNAUTHORIZED)?;
    if ftoken::looks_founder(tok) {
        let Some(k) = &st.ft else { return Err(StatusCode::UNAUTHORIZED) };
        let c = k.verify(tok, now_s()).map_err(|_| StatusCode::UNAUTHORIZED)?;
        // L2 (30 Oct): dono DB checks ek saath (pehle line se, 2 round-trip); natija wahi: founder nahi => 403, device revoke => 401 (foran band)
        if !fresh && st.gate.ok(&c.sub, &c.did, || async { let (f, d) = tokio::join!(sb.is_founder(&c.sub), sb.device_ok(&c.sub, &c.did)); f && d }).await {
            return Ok(jwt_core::Claims { sub: c.sub, email: c.email, session_id: None, exp: c.exp }); // 30 Oct refresh speed: same (account, device) shares one answer for 5 s
        }
        let (founder, dev) = tokio::join!(sb.is_founder(&c.sub), sb.device_ok(&c.sub, &c.did));
        if !founder { return Err(StatusCode::FORBIDDEN); }
        if !dev { return Err(StatusCode::UNAUTHORIZED); }
        return Ok(jwt_core::Claims { sub: c.sub, email: c.email, session_id: None, exp: c.exp });
    }
    if !st.legacy { return Err(StatusCode::UNAUTHORIZED); }
    authed_session(st, h).await
}

async fn me(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    match authed(&st, &h).await {
        Ok(c) => signed(&st, json!({"uid": c.sub, "email": c.email, "founder": true})),
        Err(code) => code.into_response(),
    }
}

/// GET: the founder's own settings + the registry (kinds + defaults) so the UI never invents either.
async fn settings_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    let c = match authed(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    let s = st.sb.as_ref().unwrap().settings(&c.sub).await;
    signed(&st, json!({"email": c.email, "available": s.is_some(), "settings": s.unwrap_or_else(|| json!({})), "registry": settings::registry_json(),
        "note": if st.sb.is_some() { Value::Null } else { json!("database not configured") }}))
}

#[derive(serde::Deserialize)]
struct SetIn { key: String, #[serde(default)] value: Value }

/// PUT {key, value}: signed write (x-fo-ts/x-fo-sig). value null = back to default.
async fn settings_put(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> axum::response::Response {
    let c = match authed_w(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    if let Err(r) = write_ok(&st, &h, "PUT", "/founder/v1/settings", &body) { return r; }
    let Ok(b) = serde_json::from_slice::<SetIn>(&body) else { return (StatusCode::BAD_REQUEST, Json(json!({"error": "invalid body"}))).into_response() };
    if !settings::valid(&b.key, &b.value) { return (StatusCode::BAD_REQUEST, Json(json!({"error": "invalid setting or value"}))).into_response(); }
    match st.sb.as_ref().unwrap().setting_set(&c.sub, &b.key, &b.value).await {
        Ok(r) => signed(&st, json!({"ok": true, "key": b.key, "changed": r["changed"], "value": b.value})),
        Err((400, msg)) => (StatusCode::BAD_REQUEST, Json(json!({"error": if msg.is_empty() { "invalid setting or value".to_string() } else { msg }}))).into_response(),
        Err((_, _)) => (StatusCode::BAD_GATEWAY, Json(json!({"error": "The server's settings table is older than this app. Run the E108 SQL step (sql-run.sh) once, then try again."}))).into_response(),
    }
}

async fn bridge_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    let path = std::env::var("EXPIRY_WATCH_FILE").unwrap_or_else(|_| "/var/lib/anexomail/expiry-watch.json".into());
    let (accs, target, queue, leads, expiry, polar_hook) = tokio::join!(
        sb.rows("revenue_accounts?select=status,mrr_gbp"),
        sb.rows("revenue_targets?select=target_gbp&order=month.desc&limit=1"),
        sb.count("mail_outbox?select=id&state=in.(queued,failed)"),
        sb.count("revenue_leads?select=id&stage=eq.new"),
        read_expiry(&path),
        hook_view(&st),
    );
    let tgt = target.and_then(|r| r.first().cloned()).and_then(|r| r.get("target_gbp").and_then(|v| v.as_f64().or_else(|| v.as_str().and_then(|s| s.parse().ok()))));
    signed(&st, json!({
        "money": bridge::money(accs.as_deref(), tgt),
        "trouble": bridge::trouble(queue, expiry.as_ref()),
        "voice": bridge::voice(leads),
        "polar": st.polar.view(now_s()),
        "polar_hook": polar_hook,
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
struct ExchangeIn { device_id: String, #[serde(default)] label: String }

/// POST /founder/v1/exchange — maujooda session (Bearer) -> founder token (15 min, device-bound). Naya device => pending (server par approve), pehla device => trust-on-first-use.
async fn exchange_ep(State(st): State<S>, h: HeaderMap, Json(b): Json<ExchangeIn>) -> axum::response::Response {
    let c = match authed_session(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    let (Some(sb), Some(keys)) = (st.sb.as_ref(), st.ft.as_ref()) else {
        return (StatusCode::SERVICE_UNAVAILABLE, Json(json!({"error": "token service not configured"}))).into_response();
    };
    if !ftoken::valid_device_id(&b.device_id) { return (StatusCode::BAD_REQUEST, Json(json!({"error": "invalid device id"}))).into_response(); }
    let (key, now) = (format!("ex:{}", c.sub), std::time::Instant::now());
    if st.lim.lock().unwrap().locked(&key, now) { return (StatusCode::TOO_MANY_REQUESTS, Json(json!({"error": "too many attempts, try again in 15 minutes"}))).into_response(); }
    let Some(r) = sb.rpc("founder_device_exchange", json!({"p_uid": c.sub, "p_device_hash": ftoken::device_hash(&b.device_id), "p_label": ftoken::clean_label(&b.label)})).await else {
        return (StatusCode::BAD_GATEWAY, Json(json!({"error": "device service unavailable — run the E104 SQL (sql-run.sh)"}))).into_response();
    };
    match r["state"].as_str() {
        Some("approved") => {
            let did = r["device_id"].as_str().unwrap_or("");
            let Some((token, exp)) = keys.mint(&c.sub, &c.email, did, now_s()) else { return StatusCode::INTERNAL_SERVER_ERROR.into_response(); };
            st.lim.lock().unwrap().clear(&key);
            { // L5 v2: where was this founder session made? (fire and forget, never slows or fails the sign-in)
                let (sb2, host) = (sb.clone(), hostproof::host_of(&h)); let fh = hostproof::is_founder_host(&host, &hostproof::founder_hosts());
                tokio::spawn(async move { let _ = sb2.rpc("founder_host_record", json!({"p_source": "rust", "p_kind": "exchange", "p_host": host, "p_founder_host": fh, "p_is_founder": true, "p_mode": "n/a", "p_decision": "allow"})).await; });
            }
            let req_key = B64.encode(sign::req_key(&st.hmac_key, &token));
            Json(json!({"token": token, "req_key": req_key, "exp": exp, "expires_in": ftoken::TTL_SECS, "device": r["label"], "first": r["first"].as_bool().unwrap_or(false)})).into_response()
        }
        Some("pending") => { st.lim.lock().unwrap().fail(&key, now); (StatusCode::FORBIDDEN, Json(json!({"error": "device_pending", "code": r["code"]}))).into_response() }
        Some("revoked") => { st.lim.lock().unwrap().fail(&key, now); (StatusCode::FORBIDDEN, Json(json!({"error": "device_revoked"}))).into_response() }
        Some("limit") => (StatusCode::TOO_MANY_REQUESTS, Json(json!({"error": "too many pending devices — approve or wait 7 days for old requests to expire"}))).into_response(),
        _ => StatusCode::BAD_GATEWAY.into_response(),
    }
}


/// Polar webhook pulse (E105 RPC, read-only), cached 5 s so a refreshing browser never hammers the database.
async fn hook_view(st: &St) -> Value {
    let now = now_s();
    if let Some((t, v)) = st.hook.lock().unwrap().clone() { if now - t < 5 { return v; } }
    let (pulse, rejects) = match &st.sb { Some(sb) => tokio::join!(sb.rpc("founder_polar_pulse", json!({})), sb.rpc("founder_polar_rejects", json!({}))), None => (None, None) };
    let mut v = match &st.sb { Some(_) => pulse.unwrap_or_else(|| json!({"webhook": {"connected": false, "note": "pulse unavailable — run the E105 SQL (sql-run.sh) or the database did not answer"}})), None => json!({"webhook": {"connected": false, "note": "database not configured"}}) };
    if let (Some(sb), Some(o)) = (&st.sb, v.as_object_mut()) { // E106: why signatures were rejected (counts only); absent until E106 is applied
        let _ = sb; if let Some(r) = rejects { o.insert("rejects".into(), r); }
    }
    *st.hook.lock().unwrap() = Some((now, v.clone()));
    v
}

async fn polar_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    signed(&st, json!({"metrics": st.polar.view(now_s()), "hook": hook_view(&st).await}))
}

async fn actions_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    match sb.rows("founder_actions?select=key,deck,title,summary,danger,enabled,reversible&order=deck,key").await {
        Some(rows) => signed(&st, json!({"connected": true, "actions": rows})),
        None => signed(&st, json!({"connected": false, "note": "founder_actions not found — run the E102 SQL (sql-run.sh)"})),
    }
}

/// GET /founder/v1/hostguard — proof of "founder only on the founder host" straight from E110 (signed like every answer).
async fn hostguard_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("founder_host_proof", json!({})).await {
        Some(p) => signed(&st, p),
        None => signed(&st, json!({"connected": false, "note": "founder_host_proof not found - run the E110 SQL (sql-run.sh)"})),
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
        None => signed(&st, json!({"connected": false, "note": "founder_audit not found — run the E102 SQL (sql-run.sh)"})),
        Some(rows) => signed(&st, json!({"connected": true, "entries": rows, "head": head, "chain_ok": bad.as_ref().map(|v| v.is_null()), "first_bad_seq": bad})),
    }
}

#[derive(serde::Deserialize)]
struct ActIn { key: String, reason: String }

async fn action_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> axum::response::Response {
    let c = match authed_w(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    if let Err(r) = write_ok(&st, &h, "POST", "/founder/v1/action", &body) { return r; }
    let Ok(b) = serde_json::from_slice::<ActIn>(&body) else { return (StatusCode::BAD_REQUEST, Json(json!({"error": "invalid body"}))).into_response() };
    let sb = st.sb.as_ref().unwrap();
    if !actions::valid_key(&b.key) { return (StatusCode::BAD_REQUEST, Json(json!({"error": "invalid action key"}))).into_response(); }
    let Some(reason) = actions::clean_reason(&b.reason) else { return (StatusCode::BAD_REQUEST, Json(json!({"error": "reason must be at least 8 characters"}))).into_response(); };
    let row = sb.rows(&format!("founder_actions?select=key,enabled,danger&key=eq.{}&limit=1", b.key)).await.and_then(|r| r.into_iter().next());
    let Some(row) = row else { return (StatusCode::NOT_FOUND, Json(json!({"error": "unknown action"}))).into_response(); };
    let enabled = row["enabled"].as_bool().unwrap_or(false);
    // koshish HAMESHA audit mein (chalna ho ya na chalna): kis ne, kya, kyun
    let a = sb.rpc("founder_audit_append", json!({"p_actor": c.sub, "p_action": format!("attempt.{}", b.key), "p_target": b.key, "p_reason": reason, "p_meta": {"enabled": enabled, "danger": row["danger"]}})).await;
    let Some(a) = a else { return (StatusCode::BAD_GATEWAY, Json(json!({"error": "audit write failed — action blocked"}))).into_response(); };
    // executor F8 mein: tab tak chalta nahi (koi side-effect nahi)
    (StatusCode::CONFLICT, Json(json!({"error": "executor not enabled yet (F8) — attempt recorded in audit", "audit": a}))).into_response()
}

pub fn app(st: S) -> Router {
    let static_dir = std::env::var("FOUNDER_STATIC").unwrap_or_else(|_| "/opt/anexomail-founder/web".into());
    Router::new()
        .route("/healthz", get(|| async { "ok" }))
        .route("/founder/v1/exchange", axum::routing::post(exchange_ep))
        .route("/founder/v1/keys", get(keys_ep))
        .route("/founder/v1/me", get(me))
        .route("/founder/v1/bridge", get(bridge_ep))
        .route("/founder/v1/settings", get(settings_ep).put(settings_put))
        .route("/founder/v1/finance/polar", get(polar_ep))
        .route("/founder/v1/actions", get(actions_ep))
        .route("/founder/v1/audit", get(audit_ep))
        .route("/founder/v1/hostguard", get(hostguard_ep))
        .route("/founder/v1/action", axum::routing::post(action_ep))
        .fallback_service(tower_http::services::ServeDir::new(static_dir).append_index_html_on_directories(true).precompressed_gzip())
        .with_state(st)
        .layer(hdr("content-security-policy", "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'; require-trusted-types-for 'script'"))
        .layer(hdr("strict-transport-security", "max-age=63072000; includeSubDomains; preload"))
        .layer(hdr("x-content-type-options", "nosniff"))
        .layer(hdr("referrer-policy", "no-referrer"))
        .layer(hdr("cross-origin-opener-policy", "same-origin"))
        .layer(hdr("cross-origin-embedder-policy", "require-corp"))
        .layer(hdr("cache-control", "no-store"))
        .layer(axum::middleware::from_fn(asset_cache))
}

/// Speed (30 Oct): Vite file names carry a content hash, so `/assets/*` can be cached for a year without ever being stale.
/// Everything else (index.html, every /founder/v1 answer) stays `no-store`. Outermost layer, so it wins over the global no-store.
async fn asset_cache(req: axum::extract::Request, next: axum::middleware::Next) -> axum::response::Response {
    // hashed bundles AND the versioned kernel file (its SHA-256 is pinned inside the worker, so a cached copy can only ever be the right bytes)
    let hashed = req.uri().path().starts_with("/assets/") || req.uri().path().starts_with("/kernel/anexo-kernel-");
    let mut res = next.run(req).await;
    if hashed && res.status() == StatusCode::OK {
        res.headers_mut().insert(HeaderName::from_static("cache-control"), HeaderValue::from_static("public, max-age=31536000, immutable"));
    }
    res
}

#[tokio::main]
async fn main() {
    if let Some(i) = std::env::args().position(|a| a == "--gen-token-key") { // installer: ek baar, key file 0400 (service user ke liye chown installer karta hai)
        let path = std::env::args().nth(i + 1).expect("path lazmi");
        if std::path::Path::new(&path).exists() { println!("exists"); return; }
        let der = ftoken::Keys::generate_pkcs8().expect("keygen");
        std::fs::write(&path, &der).expect("write");
        #[cfg(unix)] { use std::os::unix::fs::PermissionsExt; std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o400)).expect("chmod"); }
        println!("generated");
        return;
    }
    if let Some(i) = std::env::args().position(|a| a == "--gen-sign-key") { // installer: Ed25519 signing key, once, file 0400
        let path = std::env::args().nth(i + 1).expect("path lazmi");
        if std::path::Path::new(&path).exists() { println!("exists"); return; }
        std::fs::write(&path, sign::EdKeys::generate_pkcs8().expect("keygen")).expect("write");
        #[cfg(unix)] { use std::os::unix::fs::PermissionsExt; std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o400)).expect("chmod"); }
        println!("generated");
        return;
    }
    let sb = data::Sb::from_env();
    let ft = std::env::var("FOUNDER_TOKEN_KEY_FILE").unwrap_or_else(|_| "/etc/anexomail/founder-token.p8".into());
    let ft = std::fs::read(&ft).ok().and_then(|d| ftoken::Keys::from_pkcs8(&d));
    let legacy = std::env::var("FOUNDER_LEGACY_TOKEN").map(|v| v != "0").unwrap_or(true);
    eprintln!("founder: token service {} · legacy session token {}", if ft.is_some() { "ON" } else { "OFF (no key file)" }, if legacy { "accepted (grace)" } else { "REFUSED" });
    let ed = std::fs::read(std::env::var("FOUNDER_SIGN_KEY_FILE").unwrap_or_else(|_| "/etc/anexomail/founder-sign.p8".into())).ok().and_then(|d| sign::EdKeys::from_pkcs8(&d));
    let reqsig = std::env::var("FOUNDER_REQSIG").map(|v| v != "off").unwrap_or(true);
    eprintln!("founder: Ed25519 signing {} · write-request signature {}", match &ed { Some(e) => format!("ON kid {} pub {}", sign::ED_KID, e.public_b64()), None => "OFF (no key file)".into() }, if reqsig { "ENFORCED" } else { "off" });
    let key = std::env::var("FOUNDER_HMAC_KEY").expect("FOUNDER_HMAC_KEY lazmi (kam az kam 32 bytes)");
    assert!(key.len() >= 32, "FOUNDER_HMAC_KEY chhoti hai");
    let jwks = match &sb { Some(s) => s.jwks().await, None => vec![] };
    let (polar, pcfg) = match polar::Cfg::from_env() { Some(c) => (polar::Live::new(true), Some(c)), None => (polar::Live::off(), None) };
    eprintln!("founder: polar reader {}", if pcfg.is_some() { "ON (read-only, metrics API)" } else { "OFF (no FOUNDER_POLAR_READ_TOKEN)" });
    if let Some(c) = pcfg { polar::spawn(polar.clone(), c, now_s); }
    let st = Arc::new(St { sb, hmac_key: key.into_bytes(), jwks: RwLock::new(jwks), lim: Default::default(), ft, legacy, polar, hook: Default::default(), ed, reqsig, gate: authcache::AuthCache::new(std::time::Duration::from_secs(5)) });
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
        let r = app(Arc::new(St{sb:None,hmac_key:b"k".to_vec(),jwks:RwLock::new(vec![]),lim:Default::default(),ft:None,legacy:true,polar:polar::Live::off(),hook:Default::default(),ed:None,reqsig:true, gate:authcache::AuthCache::new(std::time::Duration::from_secs(5))})).oneshot(Request::get("/healthz").body(Body::empty()).unwrap()).await.unwrap();
        assert_eq!(r.status(), 200);
        let h = r.headers();
        assert!(h["content-security-policy"].to_str().unwrap().contains("frame-ancestors 'none'"));
        assert!(h["content-security-policy"].to_str().unwrap().contains("font-src 'self'")); // 30 Oct: without it Inter was blocked by default-src 'none'
        assert!(h["content-security-policy"].to_str().unwrap().contains("'wasm-unsafe-eval'")); // F2b kernel
        assert_eq!(h["cache-control"], "no-store");
    }

    #[tokio::test]
    async fn hashed_assets_cached_but_pages_and_api_not() {
        let dir = std::env::temp_dir().join(format!("fo-static-{}", std::process::id()));
        std::fs::create_dir_all(dir.join("assets")).unwrap();
        std::fs::create_dir_all(dir.join("kernel")).unwrap();
        std::fs::write(dir.join("kernel/anexo-kernel-9.9.9.wasm"), b"x").unwrap();
        std::fs::write(dir.join("assets/a-1.js"), b"x").unwrap();
        std::fs::write(dir.join("index.html"), b"<html></html>").unwrap();
        unsafe { std::env::set_var("FOUNDER_STATIC", &dir); }
        let st = || Arc::new(St{sb:None,hmac_key:b"k".to_vec(),jwks:RwLock::new(vec![]),lim:Default::default(),ft:None,legacy:true,polar:polar::Live::off(),hook:Default::default(),ed:None,reqsig:Default::default(), gate:authcache::AuthCache::new(std::time::Duration::from_secs(5))});
        let get = |p: &'static str| { let r = app(st()); async move { r.oneshot(Request::builder().uri(p).body(Body::empty()).unwrap()).await.unwrap() } };
        assert_eq!(get("/assets/a-1.js").await.headers()["cache-control"], "public, max-age=31536000, immutable");
        assert_eq!(get("/kernel/anexo-kernel-9.9.9.wasm").await.headers()["cache-control"], "public, max-age=31536000, immutable");
        assert_eq!(get("/assets/missing.js").await.headers()["cache-control"], "no-store");
        assert_eq!(get("/index.html").await.headers()["cache-control"], "no-store");
        assert_eq!(get("/founder/v1/me").await.headers()["cache-control"], "no-store");
    }

    fn st_with_sb() -> S {
        let sb = data::Sb { url: "http://127.0.0.1:1".into(), key: "k".into(), http: reqwest::Client::new() };
        Arc::new(St { sb: Some(sb), hmac_key: b"k".to_vec(), jwks: RwLock::new(vec![]), lim: Default::default(), ft: None, legacy: true, polar: polar::Live::off(), hook: Default::default(), ed: None, reqsig: true, gate: authcache::AuthCache::new(std::time::Duration::from_secs(5)) })
    }
    #[tokio::test]
    async fn founder_routes_need_bearer() {
        for path in ["/founder/v1/me", "/founder/v1/bridge", "/founder/v1/settings", "/founder/v1/finance/polar", "/founder/v1/actions", "/founder/v1/audit"] {
            let r = app(st_with_sb()).oneshot(Request::get(path).body(Body::empty()).unwrap()).await.unwrap();
            assert_eq!(r.status(), 401, "{path}");
            let r = app(st_with_sb()).oneshot(Request::get(path).header("authorization", "Bearer a.b.c").body(Body::empty()).unwrap()).await.unwrap();
            assert_eq!(r.status(), 401, "{path} junk token");
        }
    }
    #[tokio::test]
    async fn unconfigured_is_503_not_open() {
        let st = Arc::new(St { sb: None, hmac_key: b"k".to_vec(), jwks: RwLock::new(vec![]), lim: Default::default(), ft: None, legacy: true, polar: polar::Live::off(), hook: Default::default(), ed: None, reqsig: true, gate: authcache::AuthCache::new(std::time::Duration::from_secs(5)) });
        let r = app(st).oneshot(Request::get("/founder/v1/me").header("authorization", "Bearer a.b.c").body(Body::empty()).unwrap()).await.unwrap();
        assert_eq!(r.status(), 503);
    }
    #[tokio::test]
    async fn action_post_needs_bearer() {
        let r = app(st_with_sb()).oneshot(Request::post("/founder/v1/action").header("content-type", "application/json").body(Body::from(r#"{"key":"release.pull_web","reason":"test wajah"}"#)).unwrap()).await.unwrap();
        assert_eq!(r.status(), 401);
    }
}
