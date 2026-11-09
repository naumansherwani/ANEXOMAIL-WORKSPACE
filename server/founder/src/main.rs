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
mod settings_s2;
mod ambient;
mod authcache;
mod hostproof;
mod live;
mod inbox;
mod ledger;
#[path = "../../rust/checkpoint_core.rs"]
#[allow(dead_code)]
mod checkpoint_core;
#[path = "../../rust/anchor_core.rs"]
#[allow(dead_code)]
mod anchor_core;
mod signedcp;
mod anchors;
mod portable;
mod tls256;
mod wt;
mod front;
mod fproxy;
#[path = "../../rust/passkey_core.rs"]
#[allow(dead_code)]
mod passkey_core;
mod passkey;
mod flare;
mod lease;

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
fn envelope(st: &St, data: &Value) -> Value {
    let ts = now_s();
    let txt = serde_json::to_string(data).unwrap_or_default();
    let sig = sign::sign(&st.hmac_key, ts, &txt);
    // F2a: Ed25519 over the same message. `sig` (HMAC) stays until the browser kernel (F2b) verifies Ed25519 and enforces it.
    match &st.ed {
        Some(ed) => json!({"data": data, "ts": ts, "sig": sig, "alg": "ed25519", "kid": sign::ED_KID, "sig_ed": ed.sign(ts, &txt)}),
        None => json!({"data": data, "ts": ts, "sig": sig}),
    }
}

fn signed(st: &St, data: Value) -> axum::response::Response { Json(envelope(st, &data)).into_response() }

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

// ---------- Settings S2 (step 6, SQL E113): Time machine, Drift, Scheduled changes, Explain / Blast radius ----------
fn bad(msg: &str) -> axum::response::Response { (StatusCode::BAD_REQUEST, Json(json!({"error": msg}))).into_response() }

/// Read: one signed answer from one E113 RPC. `args` already whitelisted by the caller. Missing SQL says so (never invented).
async fn s2_read(st: &S, h: &HeaderMap, rpc: &str, args: impl FnOnce(&str) -> Value) -> axum::response::Response {
    let c = match authed(st, h).await { Ok(c) => c, Err(code) => return code.into_response() };
    match st.sb.as_ref().unwrap().rpc(rpc, args(&c.sub)).await {
        Some(v) if !v.is_null() => signed(st, json!({"available": true, "data": v})),
        _ => signed(st, settings_s2::missing()),
    }
}
async fn amb_read(st: &S, h: &HeaderMap, rpc: &str, args: Value) -> axum::response::Response {
    if let Err(code) = authed(st, h).await { return code.into_response(); }
    match st.sb.as_ref().unwrap().rpc(rpc, args).await {
        Some(v) if !v.is_null() => signed(st, json!({"available": true, "data": v})),
        _ => signed(st, ambient::missing()),
    }
}
async fn amb_catalog_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response { amb_read(&st, &h, "founder_ambient_catalog", json!({})).await }
async fn amb_describe_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let r = match ambient::parse_recipe(uri.query()) { Ok(r) => r, Err(e) => return bad(e) };
    amb_read(&st, &h, "founder_ambient_describe", json!({"p_r": r.to_json()})).await
}
async fn amb_step_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let r = match ambient::parse_recipe(uri.query()) { Ok(r) => r, Err(e) => return bad(e) };
    let d = match ambient::parse_delta(uri.query()) { Ok(d) => d, Err(e) => return bad(e) };
    amb_read(&st, &h, "founder_ambient_step", json!({"p_r": r.to_json(), "p_delta": d})).await
}
async fn amb_neighbours_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let r = match ambient::parse_recipe(uri.query()) { Ok(r) => r, Err(e) => return bad(e) };
    let n = match ambient::parse_each(uri.query()) { Ok(n) => n, Err(e) => return bad(e) };
    amb_read(&st, &h, "founder_ambient_neighbours", json!({"p_r": r.to_json(), "p_each": n})).await
}
async fn amb_surprise_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let n = match ambient::parse_entropy(uri.query()) { Ok(n) => n, Err(e) => return bad(e) };
    amb_read(&st, &h, "founder_ambient_surprise", json!({"p_entropy": n})).await
}
async fn s2_history_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let q = match settings_s2::parse_history(uri.query()) { Ok(q) => q, Err(e) => return bad(e) };
    s2_read(&st, &h, "founder_settings_history_list", |u| json!({"p_uid": u, "p_key": q.key, "p_before_id": q.before, "p_limit": q.limit})).await
}
async fn s2_at_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let t = match settings_s2::parse_at(uri.query()) { Ok(t) => t, Err(e) => return bad(e) };
    s2_read(&st, &h, "founder_settings_at", |u| json!({"p_uid": u, "p_ts": settings_s2::iso_from_ms(t)})).await
}
async fn s2_diff_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let (a, b) = match settings_s2::parse_diff(uri.query()) { Ok(x) => x, Err(e) => return bad(e) };
    s2_read(&st, &h, "founder_settings_diff", |u| json!({"p_uid": u, "p_from": settings_s2::iso_from_ms(a), "p_to": settings_s2::iso_from_ms(b)})).await
}
async fn s2_timeline_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let l = match settings_s2::parse_limit(uri.query(), 60) { Ok(l) => l, Err(e) => return bad(e) };
    s2_read(&st, &h, "founder_settings_timeline", |u| json!({"p_uid": u, "p_limit": l})).await
}
async fn s2_drift_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response { s2_read(&st, &h, "founder_settings_drift", |u| json!({"p_uid": u})).await }
async fn s2_pulse_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response { s2_read(&st, &h, "founder_settings_pulse", |u| json!({"p_uid": u})).await }
async fn s2_scheduled_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let l = match settings_s2::parse_limit(uri.query(), 50) { Ok(l) => l, Err(e) => return bad(e) };
    s2_read(&st, &h, "founder_settings_schedule_list", |u| json!({"p_uid": u, "p_limit": l})).await
}
async fn s2_explain_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let k = match settings_s2::parse_key(uri.query()) { Ok(k) => k, Err(e) => return bad(e) };
    s2_read(&st, &h, "founder_setting_explain", |_| json!({"p_key": k})).await
}
async fn s2_blast_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    let k = match settings_s2::parse_key(uri.query()) { Ok(k) => k, Err(e) => return bad(e) };
    s2_read(&st, &h, "founder_setting_blast", |u| json!({"p_uid": u, "p_key": k})).await
}

/// Write: signed envelope (G2: two taps + reason in the body), then one SQL door that audits inside the same transaction.
async fn s2_write(st: &S, h: &HeaderMap, path: &str, body: &axum::body::Bytes, rpc: &str, build: impl FnOnce(&str, &[u8]) -> Result<Value, &'static str>) -> axum::response::Response {
    let c = match authed_w(st, h).await { Ok(c) => c, Err(code) => return code.into_response() };
    if let Err(r) = write_ok(st, h, "POST", path, body) { return r; }
    let args = match build(&c.sub, body) { Ok(a) => a, Err(e) => return bad(e) };
    match st.sb.as_ref().unwrap().rpc_msg(rpc, args).await {
        Ok(v) => signed(st, json!({"ok": true, "result": v})),
        Err((404, m)) => (StatusCode::BAD_GATEWAY, Json(json!({"error": m}))).into_response(),
        Err((s, m)) if (400..500).contains(&s) && !m.is_empty() => bad(&m),
        Err(_) => (StatusCode::BAD_GATEWAY, Json(json!({"error": "The database did not answer. Nothing was changed."}))).into_response(),
    }
}
async fn s2_revert_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> axum::response::Response {
    s2_write(&st, &h, "/founder/v1/settings/revert", &body, "founder_setting_revert", |u, b| {
        let i: settings_s2::RevertIn = serde_json::from_slice(b).map_err(|_| "invalid body")?;
        settings_s2::check_revert(&i)?;
        Ok(json!({"p_uid": u, "p_history_id": i.history_id, "p_reason": i.reason.trim()}))
    }).await
}
async fn s2_schedule_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> axum::response::Response {
    s2_write(&st, &h, "/founder/v1/settings/schedule", &body, "founder_settings_schedule_create", |u, b| {
        let i: settings_s2::ScheduleIn = serde_json::from_slice(b).map_err(|_| "invalid body")?;
        settings_s2::check_schedule(&i, now_s() * 1000)?;
        Ok(json!({"p_uid": u, "p_key": i.key, "p_value": i.value, "p_apply_at": settings_s2::iso_from_ms(i.apply_at_ms), "p_rollback_minutes": i.rollback_minutes, "p_reason": i.reason.trim()}))
    }).await
}
async fn s2_cancel_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> axum::response::Response {
    s2_write(&st, &h, "/founder/v1/settings/schedule/cancel", &body, "founder_settings_schedule_cancel", |u, b| {
        let i: settings_s2::IdReasonIn = serde_json::from_slice(b).map_err(|_| "invalid body")?;
        settings_s2::check_id_reason(&i)?;
        Ok(json!({"p_uid": u, "p_id": i.id, "p_reason": i.reason.trim()}))
    }).await
}
async fn s2_confirm_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> axum::response::Response {
    s2_write(&st, &h, "/founder/v1/settings/schedule/confirm", &body, "founder_settings_schedule_confirm", |u, b| {
        let i: settings_s2::IdReasonIn = serde_json::from_slice(b).map_err(|_| "invalid body")?;
        settings_s2::check_id_reason(&i)?;
        Ok(json!({"p_uid": u, "p_id": i.id, "p_reason": i.reason.trim()}))
    }).await
}

async fn bridge_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    let path = std::env::var("EXPIRY_WATCH_FILE").unwrap_or_else(|_| "/var/lib/anexomail/expiry-watch.json".into());
    let (accs, target, queue, leads, expiry, polar_hook, pending) = tokio::join!(
        sb.rows("revenue_accounts?select=status,mrr_gbp"),
        sb.rows("revenue_targets?select=target_gbp&order=month.desc&limit=1"),
        sb.count("mail_outbox?select=id&state=in.(queued,failed)"),
        sb.count("revenue_leads?select=id&stage=eq.new"),
        read_expiry(&path),
        hook_view(&st),
        sb.rpc("founder_channels_pending", json!({})),
    );
    let pending = pending.as_ref().and_then(bridge::pending_from);
    let tgt = target.and_then(|r| r.first().cloned()).and_then(|r| r.get("target_gbp").and_then(|v| v.as_f64().or_else(|| v.as_str().and_then(|s| s.parse().ok()))));
    signed(&st, json!({
        "money": bridge::money(accs.as_deref(), tgt),
        "trouble": bridge::trouble(queue, expiry.as_ref()),
        "voice": bridge::voice(leads, pending),
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
    let (key, now) = (ftoken::exchange_key(&c.sub, &b.device_id), std::time::Instant::now());   // per device: a waiting phone never locks the approved desktop
    let locked = st.lim.lock().unwrap().locked(&key, now);   // 6 Nov 2026: a lock may only slow a device that is NOT approved. An approved device always gets its token (his phone was approved and still showed "Too many device attempts" because the lock was checked first).
    let Some(r) = sb.rpc("founder_device_exchange", json!({"p_uid": c.sub, "p_device_hash": ftoken::device_hash(&b.device_id), "p_label": ftoken::clean_label(&b.label)})).await else {
        return (StatusCode::BAD_GATEWAY, Json(json!({"error": "device service unavailable — run the E104 SQL (sql-run.sh)"}))).into_response();
    };
    if ftoken::exchange_blocked(locked, r["state"].as_str()) { return (StatusCode::TOO_MANY_REQUESTS, Json(json!({"error": "too many attempts, try again in 15 minutes"}))).into_response(); }
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

/// GET /founder/v1/tls — what every probed host REALLY negotiated (E119 `founder_tls_posture`): browser-style client, AES-256-only client, AES-128-only client. Signed like every answer.
async fn tls_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("founder_tls_posture", json!({})).await {
        Some(p) => signed(&st, p),
        None => signed(&st, json!({"connected": false, "note": "founder_tls_posture not found - run the E119 SQL (sql-run.sh)"})),
    }
}

/// 4b-1 (founder live data, E109): ONE signed answer with every live number. One database call (`founder_live_snapshot`), nothing invented; if the SQL is missing the answer says so.
async fn live_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    signed(&st, live_snapshot(sb).await)
}

/// The one snapshot used by /live and the stream's first frame: E111 `founder_live_snapshot_v2` (channels + reliability + tick health); if E111 is not
/// installed it falls back to the E109 `founder_live_snapshot`; if that is missing too, the answer says so (never invented).
async fn live_snapshot(sb: &data::Sb) -> Value {
    if let Some(v) = sb.rpc("founder_live_snapshot_v2", json!({})).await { if v.is_object() { return v; } }
    match sb.rpc("founder_live_snapshot", json!({})).await { Some(v) if v.is_object() => v, _ => live_missing() }
}

/// 4b-2: SSE stream of signed frames. Connect = `snapshot` frame (everything now), then a `tick` frame per tick (+ an `events` frame with the real changes
/// since the last id when something changed), `: hb` heartbeat every 15 s. Ends after 10 minutes (the browser reconnects and is re-authorised).
/// Needs the same token as every other endpoint; the SPA reads it with fetch (EventSource cannot send the Authorization header).
async fn live_stream_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response { live_stream_core(st, h, "sse").await }

/// The one live stream, whatever carries it: `transport` is "sse" (HTTP) or "webtransport" (QUIC, K6/wt.rs). It is a PARAMETER, never read from a header,
/// so a client cannot label its own session.
async fn live_stream_core(st: S, h: HeaderMap, transport: &'static str) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let Some(sb) = st.sb.clone() else { return StatusCode::SERVICE_UNAVAILABLE.into_response() };
    let hub = live::hub();
    let Some(slot) = live::Slot::take(&hub) else { return (StatusCode::SERVICE_UNAVAILABLE, "too many live streams").into_response() };
    let mut last_id: i64 = h.get("last-event-id").and_then(|v| v.to_str().ok()).and_then(|v| v.parse().ok()).unwrap_or(0);
    let mut rx = hub.tx.subscribe(); // subscribe BEFORE the snapshot so no tick is missed in between
    let (tx, body_rx) = tokio::sync::mpsc::channel::<axum::body::Bytes>(8);
    let kind = if st.ft.is_some() { "device" } else { "legacy" };
    tokio::spawn(async move {
        let _slot = slot;
        let sid = live::session_open(&sb, kind, transport).await; // E111 telemetry, fire-and-forget: None = off or not installed, the stream is unaffected
        let mut frames: i32 = 0;
        let reason: &'static str = async {
        let gone = || if tx.is_closed() { "client_gone" } else { "slow_client" }; // receiver dropped = browser left; queue full = it could not keep up
        let mut send = |frame: String| { frames += 1; tx.try_send(axum::body::Bytes::from(frame)).is_ok() }; // full queue = slow client: drop it, it reconnects with Last-Event-ID
        let snap = live_snapshot(&sb).await;
        if let Some(v) = snap.get("version").and_then(|v| v.as_i64()) { last_id = v; }
        let line = |st: &St, d: &Value| serde_json::to_string(&envelope(st, d)).unwrap_or_default();
        if !send(live::sse_frame(Some(last_id), "snapshot", &line(&st, &snap))) { return gone(); }
        let end = tokio::time::Instant::now() + live::MAX_LIFETIME;
        let mut hb = tokio::time::interval(live::HEARTBEAT);
        hb.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        hb.tick().await;
        loop {
            tokio::select! {
                _ = tokio::time::sleep_until(end) => return "lifetime",
                _ = tx.closed() => return "client_gone",
                _ = hb.tick() => { if !send(": hb\n\n".to_string()) { return gone(); } }
                r = rx.recv() => match r {
                    Ok(t) => {
                        if !send(live::sse_frame(Some(t.version), "tick", &line(&st, &live::tick_json(&t)))) { return gone(); }
                        if t.ok && t.version > last_id {
                            if let Some(d) = sb.rpc("founder_live_since", json!({"p_after": last_id, "p_limit": 100})).await {
                                if let Some(v) = d.get("version").and_then(|v| v.as_i64()) { last_id = v.max(last_id); }
                                if !send(live::sse_frame(Some(last_id), "events", &line(&st, &d))) { return gone(); }
                            }
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => return "lagged", // fell behind: end, the client reconnects and gets a fresh snapshot
                    Err(_) => return "server_stop",
                }
            }
        }
        }.await;
        live::session_close(&sb, sid, reason, frames).await;
    });
    let mut res = axum::body::Body::from_stream(live::RxStream(body_rx)).into_response();
    let hd = res.headers_mut();
    hd.insert(HeaderName::from_static("content-type"), HeaderValue::from_static("text/event-stream"));
    hd.insert(HeaderName::from_static("cache-control"), HeaderValue::from_static("no-store"));
    hd.insert(HeaderName::from_static("x-accel-buffering"), HeaderValue::from_static("no"));
    res
}

/// 5 (Audit ledger Merkle, E107): cheap pulse for the Dashboard gauge (counts + last checkpoint; the full chain is NOT re-hashed every 5 s).
async fn merkle_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    let (p, rule) = tokio::join!(sb.rpc("founder_audit_merkle_pulse", json!({})), sb.rpc("founder_audit_merkle_rule", json!({})));
    match p { Some(v) if v.is_object() => signed(&st, json!({"connected": true, "pulse": v, "rule": rule})), _ => signed(&st, ledger::missing()) }
}
/// Full check (re-hashes the chain and recent checkpoints): the Audit ledger page asks this, not the Dashboard.
async fn merkle_stats_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    let (s, l) = tokio::join!(sb.rpc("founder_audit_merkle_stats", json!({})), sb.rpc("founder_audit_checkpoint_list", json!({"p_limit": 10})));
    match s { Some(v) if v.is_object() => signed(&st, json!({"connected": true, "stats": v, "checkpoints": l})), _ => signed(&st, ledger::missing()) }
}
/// G5b: newest C2SP signed checkpoint + keys. The browser kernel verifies the signature; this only delivers it.
/// POST /founder/v1/vault/lease: renew THIS device's vault lease (J8b). The device is the one inside the founder token (`did`); SQL E143 decides; a lease is signed (Ed25519 envelope) only
/// when the answer passes `lease::lease_data`. Write path: always asks the database fresh, so a revoke is honoured at once.
async fn vault_lease_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> axum::response::Response {
    let c = match authed_w(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    let Some(sb) = st.sb.as_ref() else { return StatusCode::SERVICE_UNAVAILABLE.into_response() };
    let Some(master) = lease::MASTER.get() else { return (StatusCode::SERVICE_UNAVAILABLE, Json(json!({"error": "Vault lease key is not set up on the server yet."}))).into_response() };
    let did = match (gate::bearer(h.get("authorization").and_then(|v| v.to_str().ok())), &st.ft) {
        (Some(t), Some(k)) if ftoken::looks_founder(t) => match k.verify(t, now_s()) { Ok(f) => f.did, Err(_) => return StatusCode::UNAUTHORIZED.into_response() },
        _ => return (StatusCode::FORBIDDEN, Json(json!({"error": "A vault lease needs a device-bound founder session."}))).into_response(),
    };
    // J8b2: the device must prove it holds its own key. Body: {"jwk": {...}, "ts": <ms>, "proof": "<base64url r||s>"}
    let b: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    let (Some(ts), Some(proof), Some(jwk)) = (b.get("ts").and_then(|v| v.as_i64()), b.get("proof").and_then(|v| v.as_str()), b.get("jwk")) else {
        return (StatusCode::BAD_REQUEST, Json(json!({"error": "The device proof is missing.", "why": "key_required"}))).into_response() };
    let Some(thumb) = lease::verify_proof(&did, ts, jwk, proof) else { return (StatusCode::FORBIDDEN, Json(json!({"error": "The device proof is not valid.", "why": "key_required"}))).into_response() };
    let Some(r) = sb.rpc("founder_vault_lease_grant", json!({"p_uid": c.sub, "p_device": did, "p_key_thumb": thumb, "p_proof_ms": ts, "p_ttl_s": 900})).await else { return (StatusCode::SERVICE_UNAVAILABLE, Json(json!({"error": "Vault lease is not installed yet."}))).into_response() };
    if r.get("ok").and_then(|v| v.as_bool()) == Some(false) {
        let why = r.get("why").and_then(|v| v.as_str()).unwrap_or("");
        return (StatusCode::from_u16(lease::refusal_status(why)).unwrap_or(StatusCode::BAD_GATEWAY), Json(json!({"error": lease::refusal_text(why), "why": why}))).into_response();
    }
    let half = r.get("half_salt").and_then(|v| v.as_str()).and_then(|salt| lease::half(master, &did, salt));
    match half.and_then(|hf| lease::lease_data(&r, &did, &hf)) {
        Some(d) => { let mut resp = signed(&st, d); resp.headers_mut().insert(axum::http::header::CACHE_CONTROL, axum::http::HeaderValue::from_static("no-store")); resp }
        None => (StatusCode::BAD_GATEWAY, Json(json!({"error": "The lease answer was not valid, so nothing was signed."}))).into_response(),
    }
}
/// GET /founder/v1/vault/status: every approved device with its lease state (live / expired / revoked / none), seconds left and ledger head. Signed answer.
async fn vault_status_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    let c = match authed(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    let Some(sb) = st.sb.as_ref() else { return StatusCode::SERVICE_UNAVAILABLE.into_response() };
    match sb.rpc("founder_vault_lease_status", json!({"p_uid": c.sub})).await { Some(v) => signed(&st, v), None => (StatusCode::SERVICE_UNAVAILABLE, Json(json!({"error": "Vault lease is not installed yet."}))).into_response() }
}

/// GET /founder/v1/flare/key: the VAPID public key the phone subscribes with (public by nature, still behind the founder session).
async fn flare_key_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    signed(&st, json!({"enabled": flare::PUBLIC.get().is_some(), "key": flare::PUBLIC.get()}))
}

/// POST /founder/v1/flare/ack {"t": "<32-char token>"}: the phone's service worker returns the one-time token it found inside the encrypted push. No session (a service worker holds no
/// credential); the 192-bit token is the credential, it works once and only for that alert (E141). The answer never says why a token failed.
async fn flare_ack_ep(State(st): State<S>, body: axum::body::Bytes) -> axum::response::Response {
    if !flare::ack_allowed(now_s()) { return StatusCode::TOO_MANY_REQUESTS.into_response(); }
    let t = serde_json::from_slice::<Value>(&body).ok().and_then(|v| v.get("t").and_then(|t| t.as_str()).map(str::to_owned)).filter(|t| flare::ack_token_ok(t));
    let (Some(t), Some(sb)) = (t, st.sb.as_ref()) else { return StatusCode::BAD_REQUEST.into_response() };
    let ok = sb.rpc("founder_push_ack", json!({"p_token": t})).await.and_then(|v| v.get("ok").and_then(|o| o.as_bool())).unwrap_or(false);
    (if ok { StatusCode::OK } else { StatusCode::NOT_FOUND }).into_response()
}

async fn signed_cp_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    signed(&st, signedcp::view(st.sb.as_ref().unwrap()).await)
}
/// G5c: newest time-anchored checkpoint (RFC 3161 / OpenTimestamps evidence). The kernel re-verifies; this only delivers.
async fn anchors_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    signed(&st, anchors::view(st.sb.as_ref().unwrap()).await)
}
/// G5d part 2 (E138): the portable-pin bundle. The canonical text goes out as a STRING (the kernel hashes exactly these bytes) with Rust's own re-check next to SQL's status.
async fn portable_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    let c = match authed(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    signed(&st, portable::view(st.sb.as_ref().unwrap(), &c.sub).await)
}
async fn merkle_proof_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let q = match ledger::parse_proof(uri.query()) { Ok(q) => q, Err(e) => return (StatusCode::BAD_REQUEST, Json(json!({"error": e}))).into_response() };
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("founder_audit_merkle_proof", json!({"p_seq": q.seq, "p_upto": q.upto})).await { Some(v) if v.is_object() => signed(&st, v), _ => signed(&st, ledger::missing()) }
}
/// G4 (E120): one seal by number, so the browser can compare the seal it pinned earlier with what the server says now (rollback / rewrite check).
async fn merkle_seal_get_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let id = match ledger::parse_seal(uri.query()) { Ok(i) => i, Err(e) => return (StatusCode::BAD_REQUEST, Json(json!({"error": e}))).into_response() };
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("founder_audit_checkpoint_get", json!({"p_id": id})).await { Some(v) if v.is_object() => signed(&st, v), _ => signed(&st, ledger::missing()) }
}
/// G5a (E121): RFC 9162 consistency proof between two ledger sizes. Rust ALSO checks the proof with its own verifier before answering (second witness); the browser kernel (merkle@2) is the third.
async fn merkle_consistency_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let (first, second) = match ledger::parse_consistency(uri.query()) { Ok(q) => q, Err(e) => return (StatusCode::BAD_REQUEST, Json(json!({"error": e}))).into_response() };
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("founder_audit_consistency_proof", json!({"p_first": first, "p_second": second})).await {
        Some(mut v) if v.is_object() => { let ok = ledger::check_consistency(&v); v["rust_check"] = json!({"ok": ok}); signed(&st, v) }
        _ => signed(&st, ledger::missing()),
    }
}
/// Rows + proofs from SQL, then Rust checks every proof itself (second witness) before the browser kernel does its own.
async fn merkle_export_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let q = match ledger::parse_range(uri.query()) { Ok(q) => q, Err(e) => return (StatusCode::BAD_REQUEST, Json(json!({"error": e}))).into_response() };
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("founder_audit_export", json!({"p_from": q.from, "p_to": q.to})).await {
        Some(mut v) if v.is_object() => { let c = ledger::check_export(&v); v["rust_check"] = c; signed(&st, v) }
        _ => signed(&st, ledger::missing()),
    }
}
#[derive(serde::Deserialize, Default)]
struct SealIn { reason: Option<String> }
/// Founder presses "Seal now": a signed write (G2), audited inside SQL. Same checkpoint the automatic one makes.
async fn merkle_seal_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> axum::response::Response {
    let c = match authed_w(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    if let Err(r) = write_ok(&st, &h, "POST", "/founder/v1/audit/checkpoint", &body) { return r; }
    let b: SealIn = if body.is_empty() { SealIn::default() } else { match serde_json::from_slice(&body) { Ok(b) => b, Err(_) => return (StatusCode::BAD_REQUEST, Json(json!({"error": "invalid body"}))).into_response() } };
    let reason = b.reason.map(|r| r.trim().to_string()).filter(|r| !r.is_empty()).unwrap_or_else(|| "manual checkpoint (founder pressed Seal now)".into());
    if reason.chars().count() < 8 || reason.chars().count() > 300 || reason.chars().any(|c| c.is_control()) { return (StatusCode::BAD_REQUEST, Json(json!({"error": "reason must be 8-300 characters"}))).into_response(); }
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("founder_audit_checkpoint", json!({"p_actor": c.sub, "p_reason": reason})).await { Some(v) if v.is_object() => signed(&st, v), _ => signed(&st, ledger::missing()) }
}

/// 4d (Founder Inbox, E112): ONE signed answer = stats + SLA watch + week + channel evidence + chain health. Read only; missing SQL says so.
async fn inbox_ep(State(st): State<S>, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("founder_inbox_snapshot", json!({})).await { Some(v) if v.is_object() => signed(&st, v), _ => signed(&st, inbox::missing()) }
}

/// The issues (grouped reports) without any message body or reporter. Query is whitelisted in `inbox::parse_list`.
async fn inbox_list_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let q = match inbox::parse_list(uri.query()) { Ok(q) => q, Err(e) => return (StatusCode::BAD_REQUEST, Json(json!({"error": e}))).into_response() };
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("founder_inbox_list", inbox::list_args(&q)).await { Some(v) if v.is_object() => signed(&st, v), _ => signed(&st, inbox::missing()) }
}

/// One issue in full (the founder is the only reader of the message text).
async fn inbox_group_ep(State(st): State<S>, uri: axum::http::Uri, h: HeaderMap) -> axum::response::Response {
    if let Err(code) = authed(&st, &h).await { return code.into_response(); }
    let id = match inbox::parse_group(uri.query()) { Ok(i) => i, Err(e) => return (StatusCode::BAD_REQUEST, Json(json!({"error": e}))).into_response() };
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("founder_inbox_get", json!({"p_group": id})).await { Some(v) if v.is_object() => signed(&st, v), _ => signed(&st, inbox::missing()) }
}

fn live_missing() -> serde_json::Value {
    json!({"connected": false, "note": "founder_live_snapshot not answering - run the E109 SQL (sql-run.sh)"})
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
struct ActIn { key: String, reason: String, #[serde(default)] grant: Option<String>, #[serde(default)] nonce: Option<String>, #[serde(default)] target: Option<String>, #[serde(default)] params: Option<Value> }

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
    // J5: tiers are ENFORCED here, before anything is recorded as accepted. T2 = a fresh passkey grant for exactly this action (digest of action, target, params, nonce); T3 = never through this door.
    let tier = sb.rows(&format!("founder_action_tiers?select=tier&action=eq.{}&limit=1", b.key)).await.and_then(|r| r.into_iter().next()).and_then(|r| r["tier"].as_i64());
    let mut gate_note = json!({"tier": tier});
    match passkey::tier_gate(tier) {
        passkey::TierGate::Open => {}
        passkey::TierGate::T3Only => {
            let _ = sb.rpc("founder_audit_append", json!({"p_actor": c.sub, "p_action": format!("refused.{}", b.key), "p_target": b.key, "p_reason": reason, "p_meta": {"why": "T3 action sent to the T2 door"}})).await;
            return (StatusCode::FORBIDDEN, Json(json!({"error": "This is a T3 action: it needs two hardware keys and a delay (Security keys)."}))).into_response();
        }
        passkey::TierGate::NeedGrant => {
            let (Some(did), Some(grant), Some(nonce)) = (passkey::did_of(&st, &h), b.grant.as_deref().filter(|g| passkey::is_uuid(g)), b.nonce.as_deref()) else {
                let _ = sb.rpc("founder_audit_append", json!({"p_actor": c.sub, "p_action": format!("refused.{}", b.key), "p_target": b.key, "p_reason": reason, "p_meta": {"why": "T2 step-up grant missing"}})).await;
                return (StatusCode::FORBIDDEN, Json(json!({"error": "This step needs a passkey approval first.", "needs": "stepup", "tier": 2}))).into_response();
            };
            let target = b.target.clone().unwrap_or_else(|| b.key.clone());
            let params = b.params.clone().unwrap_or_else(|| json!({}));
            if let Err((_, msg)) = sb.rpc_msg("founder_stepup_consume", json!({"p_uid": c.sub, "p_device": did, "p_grant": grant, "p_action": b.key, "p_target": target, "p_params": params, "p_nonce": nonce})).await {
                let _ = sb.rpc("founder_audit_append", json!({"p_actor": c.sub, "p_action": format!("refused.{}", b.key), "p_target": b.key, "p_reason": reason, "p_meta": {"why": "T2 grant refused", "detail": msg}})).await;
                return (StatusCode::FORBIDDEN, Json(json!({"error": if msg.is_empty() { "The passkey approval was refused.".to_string() } else { msg }, "needs": "stepup", "tier": 2}))).into_response();
            }
            gate_note["stepup"] = json!("consumed");
        }
    }
    // koshish HAMESHA audit mein (chalna ho ya na chalna): kis ne, kya, kyun
    let a = sb.rpc("founder_audit_append", json!({"p_actor": c.sub, "p_action": format!("attempt.{}", b.key), "p_target": b.key, "p_reason": reason, "p_meta": {"enabled": enabled, "danger": row["danger"], "gate": gate_note}})).await;
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
        .route("/founder/v1/settings/history", get(s2_history_ep))
        .route("/founder/v1/settings/at", get(s2_at_ep))
        .route("/founder/v1/settings/diff", get(s2_diff_ep))
        .route("/founder/v1/settings/timeline", get(s2_timeline_ep))
        .route("/founder/v1/settings/drift", get(s2_drift_ep))
        .route("/founder/v1/settings/pulse", get(s2_pulse_ep))
        .route("/founder/v1/settings/scheduled", get(s2_scheduled_ep))
        .route("/founder/v1/settings/explain", get(s2_explain_ep))
        .route("/founder/v1/settings/blast", get(s2_blast_ep))
        .route("/founder/v1/settings/revert", axum::routing::post(s2_revert_ep))
        .route("/founder/v1/settings/schedule", axum::routing::post(s2_schedule_ep))
        .route("/founder/v1/settings/schedule/cancel", axum::routing::post(s2_cancel_ep))
        .route("/founder/v1/settings/schedule/confirm", axum::routing::post(s2_confirm_ep))
        .route("/founder/v1/ambient/catalog", get(amb_catalog_ep))
        .route("/founder/v1/ambient/describe", get(amb_describe_ep))
        .route("/founder/v1/ambient/step", get(amb_step_ep))
        .route("/founder/v1/ambient/neighbours", get(amb_neighbours_ep))
        .route("/founder/v1/ambient/surprise", get(amb_surprise_ep))
        .route("/founder/v1/finance/polar", get(polar_ep))
        .route("/founder/v1/actions", get(actions_ep))
        .route("/founder/v1/audit", get(audit_ep))
        .route("/founder/v1/hostguard", get(hostguard_ep))
        .route("/founder/v1/tls", get(tls_ep))
        .route("/founder/v1/live", get(live_ep))
        .route("/founder/v1/live/stream", get(live_stream_ep))
        .route("/founder/v1/audit/merkle", get(merkle_ep))
        .route("/founder/v1/audit/merkle/stats", get(merkle_stats_ep))
        .route("/founder/v1/audit/proof", get(merkle_proof_ep))
        .route("/founder/v1/audit/signed", get(signed_cp_ep))
        .route("/founder/v1/audit/anchors", get(anchors_ep))
        .route("/founder/v1/audit/portable", get(portable_ep))
        .route("/founder/v1/audit/export", get(merkle_export_ep))
        .route("/founder/v1/audit/checkpoint", axum::routing::post(merkle_seal_ep))
        .route("/founder/v1/audit/seal", get(merkle_seal_get_ep))
        .route("/founder/v1/audit/consistency", get(merkle_consistency_ep))
        .route("/founder/v1/passkey/options", axum::routing::post(passkey::options_ep))
        .route("/founder/v1/passkey/verify", axum::routing::post(passkey::verify_ep))
        .route("/founder/v1/passkey/finish", axum::routing::post(passkey::finish_ep))
        .route("/founder/v1/passkey/list", get(passkey::list_ep))
        .route("/founder/v1/passkey/pending", get(passkey::pending_ep))
        .route("/founder/v1/flare/key", get(flare_key_ep))
        .route("/founder/v1/vault/lease", axum::routing::post(vault_lease_ep))
        .route("/founder/v1/vault/status", get(vault_status_ep))
        .route("/founder/v1/flare/ack", axum::routing::post(flare_ack_ep))
        .route("/founder/v1/chairman/{door}", axum::routing::post(passkey::door_ep))
        .route("/founder/v1/inbox", get(inbox_ep))
        .route("/founder/v1/inbox/list", get(inbox_list_ep))
        .route("/founder/v1/inbox/group", get(inbox_group_ep))
        .route("/founder/v1/action", axum::routing::post(action_ep))
        .fallback_service(tower_http::services::ServeDir::new(static_dir).append_index_html_on_directories(true).precompressed_gzip())
        .with_state(st)
        .layer(hdr("content-security-policy", "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; manifest-src 'self'; worker-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'; require-trusted-types-for 'script'"))
        .layer(hdr("strict-transport-security", "max-age=63072000; includeSubDomains; preload"))
        .layer(hdr("x-content-type-options", "nosniff"))
        .layer(hdr("x-frame-options", "DENY"))
        .layer(hdr("permissions-policy", "camera=(), microphone=(), geolocation=(), payment=(), usb=(), serial=(), bluetooth=(), publickey-credentials-get=(self), publickey-credentials-create=(self)"))
        .layer(hdr("referrer-policy", "no-referrer"))
        .layer(hdr("cross-origin-opener-policy", "same-origin"))
        .layer(hdr("cross-origin-embedder-policy", "require-corp"))
        .layer(hdr("cache-control", "no-store"))
        .layer(axum::middleware::from_fn(asset_cache))
        .layer(axum::middleware::from_fn(strip_cc)) // K4: the SPA is built for the /_cc/ prefix (Caddy strips it); the own TLS terminator has no Caddy, so it strips it itself
}

/// `/_cc/assets/x.js` -> `/assets/x.js` (and `/_cc`, `/_cc/` -> `/`). Only a path that starts with exactly `/_cc` + `/` or the end; `/_ccx` and `/a/_cc/` are left alone. The query string is kept.
pub fn strip_cc_path(p: &str) -> Option<String> {
    if p == "/_cc" { return Some("/".into()); }
    p.strip_prefix("/_cc/").map(|rest| format!("/{rest}"))
}
async fn strip_cc(mut req: axum::extract::Request, next: axum::middleware::Next) -> axum::response::Response {
    if let Some(np) = strip_cc_path(req.uri().path()) {
        let pq = match req.uri().query() { Some(q) => format!("{np}?{q}"), None => np };
        let mut parts = req.uri().clone().into_parts();
        if let Ok(v) = pq.parse() { parts.path_and_query = Some(v); if let Ok(u) = axum::http::Uri::from_parts(parts) { *req.uri_mut() = u; } }
    }
    next.run(req).await
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
    if let Some(i) = std::env::args().position(|a| a == "--gen-vapid-key") { // installer (J6): P-256 key for Web Push (VAPID), once, file 0400; the service itself cannot write /etc (ProtectSystem=strict)
        let path = std::env::args().nth(i + 1).expect("path lazmi");
        if std::path::Path::new(&path).exists() { println!("exists"); return; }
        match flare::Vapid::load_or_create(&path, "https://invalid.example") { Some(v) => println!("generated public {}", v.public_b64()), None => { eprintln!("vapid keygen failed"); std::process::exit(1); } }
        return;
    }
    if let Some(i) = std::env::args().position(|a| a == "--gen-vault-master") { // installer (J8b2): 32-byte master for the vault key half, once, file 0400
        let path = std::env::args().nth(i + 1).expect("path lazmi");
        if std::path::Path::new(&path).exists() { println!("exists"); return; }
        lease::gen_master(&path).expect("write");
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
    { let mp = std::env::var("FOUNDER_VAULT_MASTER_FILE").unwrap_or_else(|_| "/etc/anexomail/founder-vault-master.key".into());
      if lease::load_master(&mp) { eprintln!("founder: vault lease key ON (server half = HKDF, master file loaded)"); } else { eprintln!("founder: vault lease key OFF (no usable {mp}); POST /founder/v1/vault/lease answers 503"); } }
    if let Some(s) = &sb { lease::spawn_sweep(s.clone()); }
    match (&sb, flare::Cfg::from_env()) { (Some(s), Some(c)) => flare::spawn(s.clone(), c), (_, None) => eprintln!("founder: flare sender OFF (FOUNDER_FLARE=off or no usable VAPID key)"), _ => {} }
    if let Some(s) = &sb { live::start(s.clone()); } // 4b-2: the one process-wide live tick
    let st = Arc::new(St { sb, hmac_key: key.into_bytes(), jwks: RwLock::new(jwks), lim: Default::default(), ft, legacy, polar, hook: Default::default(), ed, reqsig, gate: authcache::AuthCache::new(std::time::Duration::from_secs(5)) });
    fproxy::init_from_env(std::env::var("FOUNDER_TLS256_ADDR").ok().as_deref());
    match tls256::from_env() { // T256-1: own TLS 1.3 terminator, AES-256-GCM only, on its own port (default OFF); the main port above is never touched
        None => eprintln!("founder: TLS-256 terminator OFF (no FOUNDER_TLS256_ADDR)"),
        Some(Err(e)) => eprintln!("founder: TLS-256 terminator NOT started: {e}"),
        Some(Ok((a, store, cert_path, key_path))) => match tokio::net::TcpListener::bind(&a).await {
            Ok(l) => { eprintln!("founder: TLS-256 terminator ON {a} (TLS 1.3, AES-256-GCM only, certificate hot-reload, {} days left)", (store.not_after() - std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)) / 86400); tls256::spawn_reloader(store.clone(), cert_path, key_path); tokio::spawn(tls256::serve_store_px(l, store, app(st.clone()).layer(hdr("alt-svc", "clear")).layer(axum::middleware::from_fn(fproxy::layer)), tls256::proxy_from_env())); }
            Err(e) => eprintln!("founder: TLS-256 terminator NOT started: bind {a}: {e}"),
        },
    }
    match front::from_env() { // K4.4: SNI front (default OFF), tested on a spare port first; the real :443 is switched only with the founder's "haan"
        None => {},
        Some(Err(e)) => eprintln!("founder: SNI front NOT started: {e}"),
        Some(Ok((a, fcfg))) => match tokio::net::TcpListener::bind(&a).await {
            Ok(l) => { eprintln!("founder: SNI front ON {a}: {} -> {}, everything else -> {}", fcfg.host, fcfg.tls_backend, fcfg.other_backend); tokio::spawn(front::serve_front(l, fcfg)); }
            Err(e) => eprintln!("founder: SNI front NOT started: bind {a}: {e}"),
        },
    }
    match wt::from_env() { // K6: WebTransport (QUIC/HTTP3, AES-256) carrying the same live frames as the SSE stream; UDP port of its own (default OFF)
        None => eprintln!("founder: WebTransport OFF (no FOUNDER_WT_ADDR)"),
        Some(Err(e)) => eprintln!("founder: WebTransport NOT started: {e}"),
        Some(Ok((a, host, store, cp, kp))) => match a.parse::<std::net::SocketAddr>().map_err(|e| e.to_string()).and_then(|sa| wt::endpoint(sa, &store.current())) {
            Ok(ep) => {
                eprintln!("founder: WebTransport ON udp {a} for {host}{} (QUIC, TLS 1.3, AES-256-GCM, certificate hot-reload)", wt::PATH);
                tls256::spawn_reloader(store.clone(), cp, kp);
                let stw = st.clone();
                let handler: wt::Handler = Arc::new(move |h: HeaderMap| { let stw = stw.clone(); Box::pin(async move { live_stream_core(stw, h, "webtransport").await }) });
                tokio::spawn(wt::serve(ep, store, Arc::new(wt::Cfg { host, handler })));
            }
            Err(e) => eprintln!("founder: WebTransport NOT started: {e}"),
        },
    }
    if let Some(sb) = st.sb.clone() { tls256::spawn_prober(sb); }
    let addr = std::env::var("FOUNDER_BIND").unwrap_or_else(|_| "127.0.0.1:3210".into());
    let l = tokio::net::TcpListener::bind(&addr).await.expect("bind");
    axum::serve(l, app(st)).await.expect("serve");
}

#[cfg(test)]
mod tests {
    #[test]
    fn the_cc_prefix_is_stripped_only_when_it_is_the_prefix() {
        assert_eq!(strip_cc_path("/_cc/assets/index-x.js").as_deref(), Some("/assets/index-x.js"));
        assert_eq!(strip_cc_path("/_cc/").as_deref(), Some("/"));
        assert_eq!(strip_cc_path("/_cc").as_deref(), Some("/"));
        assert_eq!(strip_cc_path("/_cc/kernel/anexo-kernel-0.13.0.wasm").as_deref(), Some("/kernel/anexo-kernel-0.13.0.wasm"));
        for p in ["/", "/_ccx/a", "/a/_cc/b", "/founder/v1/me", "/assets/a.js", "/_c"] { assert_eq!(strip_cc_path(p), None, "{p}"); }
    }

    use super::*;
    use axum::{body::Body, http::Request};
    use tower::ServiceExt;
    #[test]
    fn live_missing_never_pretends() {
        let v = live_missing();
        assert_eq!(v["connected"], false);
        assert!(v["note"].as_str().unwrap().contains("E109"));
        assert!(v.get("version").is_none() && v.get("money").is_none());
    }
    #[tokio::test]
    async fn health_has_hardening_headers() {
        let r = app(Arc::new(St{sb:None,hmac_key:b"k".to_vec(),jwks:RwLock::new(vec![]),lim:Default::default(),ft:None,legacy:true,polar:polar::Live::off(),hook:Default::default(),ed:None,reqsig:true, gate:authcache::AuthCache::new(std::time::Duration::from_secs(5))})).oneshot(Request::get("/healthz").body(Body::empty()).unwrap()).await.unwrap();
        assert_eq!(r.status(), 200);
        let h = r.headers();
        assert!(h["content-security-policy"].to_str().unwrap().contains("frame-ancestors 'none'"));
        assert!(h["content-security-policy"].to_str().unwrap().contains("font-src 'self'")); // 30 Oct: without it Inter was blocked by default-src 'none'
        assert!(h["content-security-policy"].to_str().unwrap().contains("'wasm-unsafe-eval'")); // F2b kernel
        assert!(h["content-security-policy"].to_str().unwrap().contains("manifest-src 'self'") && h["content-security-policy"].to_str().unwrap().contains("worker-src 'self'")); // J6: the iPhone manifest + push service worker
        assert_eq!(h["x-frame-options"], "DENY");
        assert!(h["permissions-policy"].to_str().unwrap().contains("publickey-credentials-get=(self)") && h["permissions-policy"].to_str().unwrap().contains("camera=()")); // passkeys must keep working
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
        for path in ["/founder/v1/ambient/catalog", "/founder/v1/ambient/describe?palette=60&pattern=1&speed=9&intensity=6&blend=0&seed=0", "/founder/v1/ambient/step?palette=60&pattern=1&speed=9&intensity=6&blend=0&seed=0&delta=1", "/founder/v1/ambient/neighbours?palette=60&pattern=1&speed=9&intensity=6&blend=0&seed=0", "/founder/v1/ambient/surprise?n=7", "/founder/v1/me", "/founder/v1/bridge", "/founder/v1/settings", "/founder/v1/settings/history", "/founder/v1/settings/at?t=1793000000000", "/founder/v1/settings/diff?from=1700000000000&to=1790000000000", "/founder/v1/settings/timeline", "/founder/v1/settings/drift", "/founder/v1/settings/pulse", "/founder/v1/settings/scheduled", "/founder/v1/settings/explain?key=personal.home", "/founder/v1/settings/blast?key=personal.home", "/founder/v1/finance/polar", "/founder/v1/actions", "/founder/v1/audit", "/founder/v1/hostguard", "/founder/v1/live", "/founder/v1/live/stream", "/founder/v1/inbox", "/founder/v1/inbox/list", "/founder/v1/inbox/group", "/founder/v1/audit/merkle", "/founder/v1/audit/merkle/stats", "/founder/v1/audit/proof?seq=1", "/founder/v1/audit/signed", "/founder/v1/audit/anchors", "/founder/v1/audit/portable", "/founder/v1/audit/export?from=1&to=2"] {
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
