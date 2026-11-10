//! G-MIX stage 2a (founder, 9 Nov 2026): the NATIVE founder sign-in. Technology: Rust (axum 0.8 + reqwest/rustls) inside the founder binary; no Bun, no Node, no old app.
//! SEPARATION LAW: the founder host must never depend on the awam app. These three doors replace `/api/auth/login|refresh|logout` of the old app for founder accounts only:
//!   POST /founder/v1/auth/login   {email, password}     -> {token, refresh_token, expires_at}
//!   POST /founder/v1/auth/refresh {refresh_token}       -> {token, refresh_token, expires_at}
//!   POST /founder/v1/auth/logout  (Bearer session token) -> 204
//! Rules (all pure and tested): (1) only an account that is in `founder_accounts` ever gets a token; every other outcome is the SAME generic 401, so the door is no account oracle;
//! (2) the identity service session of a non-founder is ended at once (best effort) and never returned; (3) an account with a verified second factor is refused here (fail closed) until stage 2b
//! brings passkey/MFA, so this door can never be weaker than the old one; (4) 5 failures per 15 min per email AND per client address lock the door (HTTP 429); (5) a transient identity-service
//! failure is 503 + retry, never "wrong password"; (6) tokens and passwords are never logged and never placed in a URL.
use axum::extract::State;
use axum::http::{HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde::Deserialize;
use serde_json::{json, Value};

use crate::S;

#[derive(Deserialize)]
pub struct LoginIn { pub email: String, pub password: String }
#[derive(Deserialize)]
pub struct RefreshIn { pub refresh_token: String }

/// What the identity service (GoTrue) said, reduced to what we decide on.
#[derive(Debug, PartialEq)]
pub enum Grant {
    Session { token: String, refresh: String, expires_at: Option<i64>, uid: String, second_factor: bool },
    Invalid,
    Transient,
}

/// Trim + lowercase + shape check. None = refuse before any network call.
pub fn clean_email(e: &str) -> Option<String> {
    let e = e.trim().to_lowercase();
    if crate::login::valid_email(&e) { Some(e) } else { None }
}

/// Lock keys: one per email and one per client address (the terminator overwrites x-real-ip, a client cannot forge it).
pub fn lock_keys(h: &HeaderMap, email: &str) -> [String; 2] {
    let ip = h.get("x-real-ip").and_then(|v| v.to_str().ok()).map(|s| s.trim().chars().take(64).collect::<String>()).filter(|s| !s.is_empty()).unwrap_or_else(|| "-".into());
    [format!("flogin:e:{email}"), format!("flogin:ip:{ip}")]
}

/// Reduce a GoTrue token answer. 2xx with tokens = Session; 400/401/403/422 = Invalid; everything else (429, 5xx, no answer) = Transient.
pub fn parse_grant(status: u16, body: &Value) -> Grant {
    match status {
        200..=299 => {
            let s = |k: &str| body[k].as_str().filter(|v| !v.is_empty()).map(str::to_string);
            let (Some(token), Some(refresh), Some(uid)) = (s("access_token"), s("refresh_token"), body["user"]["id"].as_str().map(str::to_string)) else { return Grant::Invalid };
            let second_factor = body["user"]["factors"].as_array().map(|f| f.iter().any(|x| x["status"].as_str() == Some("verified"))).unwrap_or(false);
            Grant::Session { token, refresh, expires_at: body["expires_at"].as_i64(), uid, second_factor }
        }
        400 | 401 | 403 | 422 => Grant::Invalid,
        _ => Grant::Transient,
    }
}

pub(crate) fn generic_401() -> Response { (StatusCode::UNAUTHORIZED, Json(json!({"error": "invalid_credentials"}))).into_response() }
pub(crate) fn busy_503() -> Response { (StatusCode::SERVICE_UNAVAILABLE, Json(json!({"error": "auth_temporarily_unavailable", "retry": true}))).into_response() }
pub(crate) fn locked_429() -> Response { (StatusCode::TOO_MANY_REQUESTS, Json(json!({"error": "too_many_attempts", "message": "Too many attempts. Try again in 15 minutes."}))).into_response() }
pub(crate) fn no_store(mut r: Response) -> Response { r.headers_mut().insert(axum::http::header::CACHE_CONTROL, axum::http::HeaderValue::from_static("no-store")); r }

/// One call to the identity service. Err = unreachable/unreadable.
pub(crate) async fn gotrue(sb: &crate::data::Sb, path_q: &str, body: Option<Value>, bearer: Option<&str>) -> Result<(u16, Value), ()> {
    let mut rq = sb.http.post(format!("{}/auth/v1/{}", sb.url, path_q)).header("apikey", &sb.key);
    if let Some(b) = bearer { rq = rq.header("authorization", format!("Bearer {b}")); }
    if let Some(b) = body { rq = rq.json(&b); }
    let r = rq.send().await.map_err(|_| ())?;
    let st = r.status().as_u16();
    let v: Value = r.json().await.unwrap_or(Value::Null);
    Ok((st, v))
}

pub(crate) async fn end_session(sb: &crate::data::Sb, token: &str) { let _ = gotrue(sb, "logout", None, Some(token)).await; }

fn session_json(token: &str, refresh: &str, expires_at: Option<i64>) -> Response {
    no_store(Json(json!({"token": token, "refresh_token": refresh, "expires_at": expires_at})).into_response())
}

/// Shared tail of login and refresh: founder-only, no second factor path here, else the same generic denial.
async fn decide(sb: &crate::data::Sb, g: Grant) -> Result<(String, String, Option<i64>, String), Response> {
    match g {
        Grant::Transient => Err(busy_503()),
        Grant::Invalid => Err(generic_401()),
        Grant::Session { token, refresh, expires_at, uid, second_factor } => {
            if !sb.is_founder(&uid).await || second_factor {
                end_session(sb, &token).await; // a non-founder (or a factor we cannot honour here yet) leaves no live session behind
                return Err(generic_401());
            }
            Ok((token, refresh, expires_at, uid))
        }
    }
}

pub async fn login_ep(State(st): State<S>, h: HeaderMap, Json(b): Json<LoginIn>) -> Response {
    let Some(sb) = st.sb.as_ref() else { return busy_503() };
    let Some(email) = clean_email(&b.email) else { return generic_401() };
    if b.password.is_empty() || b.password.len() > 1024 { return generic_401(); }
    let (keys, now) = (lock_keys(&h, &email), std::time::Instant::now());
    if { let mut l = st.lim.lock().unwrap(); keys.iter().any(|k| l.locked(k, now)) } { return locked_429(); }
    let Ok((code, body)) = gotrue(sb, "token?grant_type=password", Some(json!({"email": email, "password": b.password})), None).await else { return busy_503() };
    match decide(sb, parse_grant(code, &body)).await {
        // S2 (10 Nov 2026): a correct password is only the FIRST step. The sign-in ceremony (E151/E152 doors, signin.rs) decides whether a session is handed out.
        Ok((t, r, e, uid)) => {
            let resp = crate::signin::after_password(&st, &h, uid, t, r, e).await;
            if resp.status() == StatusCode::OK { let mut l = st.lim.lock().unwrap(); for k in &keys { l.clear(k); } }
            resp
        }
        Err(resp) => { if resp.status() == StatusCode::UNAUTHORIZED { let mut l = st.lim.lock().unwrap(); for k in &keys { l.fail(k, now); } } resp }
    }
}

pub async fn refresh_ep(State(st): State<S>, Json(b): Json<RefreshIn>) -> Response {
    let Some(sb) = st.sb.as_ref() else { return busy_503() };
    let rt = b.refresh_token.trim();
    if rt.is_empty() || rt.len() > 512 { return (StatusCode::BAD_REQUEST, Json(json!({"error": "refresh_token_required"}))).into_response(); }
    let Ok((code, body)) = gotrue(sb, "token?grant_type=refresh_token", Some(json!({"refresh_token": rt})), None).await else { return busy_503() };
    match decide(sb, parse_grant(code, &body)).await {
        Ok((t, r, e, _uid)) => session_json(&t, &r, e),
        Err(resp) if resp.status() == StatusCode::UNAUTHORIZED => no_store((StatusCode::UNAUTHORIZED, Json(json!({"error": "refresh_invalid"}))).into_response()),
        Err(resp) => resp,
    }
}

pub async fn logout_ep(State(st): State<S>, h: HeaderMap) -> Response {
    let (Some(sb), Some(tok)) = (st.sb.as_ref(), crate::gate::bearer(h.get("authorization").and_then(|v| v.to_str().ok()))) else { return StatusCode::UNAUTHORIZED.into_response() };
    end_session(sb, tok).await;
    no_store(StatusCode::NO_CONTENT.into_response())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn email_is_cleaned_and_junk_refused() {
        assert_eq!(clean_email("  Nauman@Anexomail.com ").as_deref(), Some("nauman@anexomail.com"));
        for bad in ["", "a", "a b@c.com", "@c.com", "a@@c.com", "x@y .com"] { assert!(clean_email(bad).is_none(), "{bad}"); }
    }
    #[test]
    fn grant_reduction_is_closed() {
        let ok = json!({"access_token": "a.b.c", "refresh_token": "r", "expires_at": 99, "user": {"id": "u1", "factors": []}});
        assert_eq!(parse_grant(200, &ok), Grant::Session { token: "a.b.c".into(), refresh: "r".into(), expires_at: Some(99), uid: "u1".into(), second_factor: false });
        let mfa = json!({"access_token": "a", "refresh_token": "r", "user": {"id": "u1", "factors": [{"status": "unverified"}, {"status": "verified"}]}});
        assert!(matches!(parse_grant(200, &mfa), Grant::Session { second_factor: true, .. }));
        assert_eq!(parse_grant(200, &json!({"access_token": "a"})), Grant::Invalid); // a 200 without the full set is never a session
        assert_eq!(parse_grant(200, &Value::Null), Grant::Invalid);
        for c in [400, 401, 403, 422] { assert_eq!(parse_grant(c, &json!({})), Grant::Invalid, "{c}"); }
        for c in [0, 429, 500, 502, 503, 504] { assert_eq!(parse_grant(c, &json!({})), Grant::Transient, "{c}"); }
    }
    #[test]
    fn lock_keys_use_the_real_address_and_never_panic() {
        let mut h = HeaderMap::new();
        assert_eq!(lock_keys(&h, "a@b.com")[1], "flogin:ip:-");
        h.insert("x-real-ip", "203.0.113.9".parse().unwrap());
        assert_eq!(lock_keys(&h, "a@b.com"), ["flogin:e:a@b.com".to_string(), "flogin:ip:203.0.113.9".to_string()]);
        h.insert("x-real-ip", "x".repeat(500).parse().unwrap());
        assert!(lock_keys(&h, "a@b.com")[1].len() < 100);
    }

    // ---- end to end: the real axum routes against a loopback stand-in of the identity service + the founder table ----
    use axum::body::Body;
    use axum::http::Request;
    use std::sync::{Arc, Mutex};
    use tower::ServiceExt;

    #[derive(Clone, Default)]
    struct Standin { logouts: Arc<Mutex<Vec<String>>>, calls: Arc<Mutex<u32>> }

    async fn spawn_standin() -> (String, Standin) {
        use axum::{routing::{get, post}, Router, extract::{Query, State as St2}};
        let m = Standin::default();
        let app = Router::new()
            .route("/auth/v1/token", post(|St2(m): St2<Standin>, Query(q): Query<std::collections::HashMap<String, String>>, Json(b): Json<Value>| async move {
                *m.calls.lock().unwrap() += 1;
                let who = if q.get("grant_type").map(String::as_str) == Some("refresh_token") { b["refresh_token"].as_str().unwrap_or("").to_string() } else { b["email"].as_str().unwrap_or("").to_string() };
                let (uid, ok, fac) = match (who.as_str(), b["password"].as_str()) {
                    ("founder@x.com", Some("right")) => ("11111111-1111-1111-1111-111111111111", true, false),
                    ("rt-founder", _) => ("11111111-1111-1111-1111-111111111111", true, false),
                    ("mfa@x.com", Some("right")) => ("33333333-3333-3333-3333-333333333333", true, true),
                    ("awam@x.com", Some("right")) => ("22222222-2222-2222-2222-222222222222", true, false),
                    ("down@x.com", _) => return (StatusCode::BAD_GATEWAY, Json(json!({}))),
                    _ => ("", false, false),
                };
                if !ok { return (StatusCode::BAD_REQUEST, Json(json!({"error": "invalid_grant"}))); }
                (StatusCode::OK, Json(json!({"access_token": format!("tok-{uid}"), "refresh_token": "next-rt", "expires_at": 4102444800i64, "user": {"id": uid, "factors": if fac { json!([{"status": "verified"}]) } else { json!([]) }}})))
            }))
            .route("/auth/v1/logout", post(|St2(m): St2<Standin>, h: HeaderMap| async move {
                m.logouts.lock().unwrap().push(h.get("authorization").and_then(|v| v.to_str().ok()).unwrap_or("").to_string()); StatusCode::NO_CONTENT
            }))
            // S2: the sign-in ceremony doors (E151/E152) the password path now goes through; this stand-in says "one factor, complete, released"
            .route("/rest/v1/rpc/{name}", post(|axum::extract::Path(name): axum::extract::Path<String>| async move {
                Json(match name.as_str() {
                    "founder_signin_locked" => json!({"locked": false}),
                    "founder_signin_open" => json!({"ok": true, "state": "complete", "need": [], "second_required": false}),
                    "founder_signin_release_v2" => json!({"ok": true, "uid": "11111111-1111-1111-1111-111111111111", "method": "password", "new_net": false, "risk": {"level": "low"}}),
                    _ => json!({"ok": true}),
                })
            }))
            .route("/rest/v1/founder_accounts", get(|Query(q): Query<std::collections::HashMap<String, String>>| async move {
                let is = q.get("user_id").map(|v| v.contains("11111111-1111")).unwrap_or(false);
                Json(if is { json!([{"user_id": "11111111-1111-1111-1111-111111111111"}]) } else { json!([]) })
            }))
            .with_state(m.clone());
        let l = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}", l.local_addr().unwrap());
        tokio::spawn(async move { axum::serve(l, app).await.unwrap(); });
        (url, m)
    }
    fn st_for(url: &str) -> crate::S {
        let sb = crate::data::Sb { url: url.into(), key: "svc".into(), http: reqwest::Client::new() };
        Arc::new(crate::St { sb: Some(sb), hmac_key: b"k".to_vec(), jwks: tokio::sync::RwLock::new(vec![]), lim: Default::default(), ft: None, legacy: true, polar: crate::polar::Live::off(), hook: Default::default(), ed: None, reqsig: true, gate: crate::authcache::AuthCache::new(std::time::Duration::from_secs(5)), dbsc: crate::dbsc::Mode::Off })
    }
    async fn post_json(st: &crate::S, path: &str, body: Value, ip: &str) -> (StatusCode, Value, Option<String>) {
        let r = crate::app(st.clone()).oneshot(Request::post(path).header("content-type", "application/json").header("x-real-ip", ip).body(Body::from(body.to_string())).unwrap()).await.unwrap();
        let (s, cc) = (r.status(), r.headers().get("cache-control").and_then(|v| v.to_str().ok()).map(str::to_string));
        let b = axum::body::to_bytes(r.into_body(), 1 << 20).await.unwrap();
        (s, serde_json::from_slice(&b).unwrap_or(Value::Null), cc)
    }

    #[tokio::test]
    async fn a_founder_signs_in_refreshes_and_signs_out_and_nobody_else_does() {
        let (url, m) = spawn_standin().await; let st = st_for(&url);
        // founder: token set, never cached
        let (s, j, cc) = post_json(&st, "/founder/v1/auth/login", json!({"email": " Founder@X.com ", "password": "right"}), "198.51.100.1").await;
        assert_eq!(s, 200); assert_eq!(j["token"], "tok-11111111-1111-1111-1111-111111111111"); assert_eq!(j["refresh_token"], "next-rt"); assert_eq!(cc.as_deref(), Some("no-store"));
        // wrong password and unknown account are the SAME answer
        let (s1, j1, _) = post_json(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "wrong"}), "198.51.100.2").await;
        let (s2, j2, _) = post_json(&st, "/founder/v1/auth/login", json!({"email": "nobody@x.com", "password": "wrong"}), "198.51.100.3").await;
        assert_eq!((s1, &j1), (s2, &j2)); assert_eq!(s1, 401);
        // a REAL awam account with the right password gets the same generic 401, no token, and its session is ended
        let (s, j, _) = post_json(&st, "/founder/v1/auth/login", json!({"email": "awam@x.com", "password": "right"}), "198.51.100.4").await;
        assert_eq!(s, 401); assert_eq!(j, json!({"error": "invalid_credentials"})); assert!(j.get("token").is_none());
        assert_eq!(m.logouts.lock().unwrap().as_slice(), ["Bearer tok-22222222-2222-2222-2222-222222222222"]);
        // an account with a verified second factor is refused here (fail closed) and its session ended
        let (s, _, _) = post_json(&st, "/founder/v1/auth/login", json!({"email": "mfa@x.com", "password": "right"}), "198.51.100.5").await;
        assert_eq!(s, 401); assert_eq!(m.logouts.lock().unwrap().len(), 2);
        // identity service down = 503 retry, never "wrong password", and it does not count as a failed attempt
        let (s, j, _) = post_json(&st, "/founder/v1/auth/login", json!({"email": "down@x.com", "password": "right"}), "198.51.100.6").await;
        assert_eq!(s, 503); assert_eq!(j["retry"], true);
        // junk is refused before any network call
        let before = *m.calls.lock().unwrap();
        for b in [json!({"email": "", "password": "x"}), json!({"email": "a@b.com", "password": ""}), json!({"email": "a b@c.com", "password": "x"})] { assert_eq!(post_json(&st, "/founder/v1/auth/login", b, "198.51.100.7").await.0, 401); }
        assert_eq!(*m.calls.lock().unwrap(), before);
        // refresh: founder ok, dead token 401 refresh_invalid, empty 400
        let (s, j, _) = post_json(&st, "/founder/v1/auth/refresh", json!({"refresh_token": "rt-founder"}), "198.51.100.1").await;
        assert_eq!(s, 200); assert_eq!(j["token"], "tok-11111111-1111-1111-1111-111111111111");
        let (s, j, _) = post_json(&st, "/founder/v1/auth/refresh", json!({"refresh_token": "dead"}), "198.51.100.1").await;
        assert_eq!(s.as_u16(), 401); assert_eq!(j["error"].as_str(), Some("refresh_invalid"));
        assert_eq!(post_json(&st, "/founder/v1/auth/refresh", json!({"refresh_token": ""}), "198.51.100.1").await.0, 400);
        // logout: needs a bearer, ends the session at the identity service
        let r = crate::app(st.clone()).oneshot(Request::post("/founder/v1/auth/logout").body(Body::empty()).unwrap()).await.unwrap(); assert_eq!(r.status(), 401);
        let r = crate::app(st.clone()).oneshot(Request::post("/founder/v1/auth/logout").header("authorization", "Bearer abc.def.ghi").body(Body::empty()).unwrap()).await.unwrap(); assert_eq!(r.status(), 204);
        assert_eq!(m.logouts.lock().unwrap().last().unwrap(), "Bearer abc.def.ghi");
    }

    #[tokio::test]
    async fn five_failures_lock_the_email_and_the_address_but_a_success_clears_it() {
        let (url, _m) = spawn_standin().await; let st = st_for(&url);
        for _ in 0..5 { assert_eq!(post_json(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "bad"}), "203.0.113.50").await.0, 401); }
        // even the RIGHT password is refused while locked (email lock), and a different address cannot get around the email lock
        assert_eq!(post_json(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "right"}), "203.0.113.50").await.0, 429);
        assert_eq!(post_json(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "right"}), "203.0.113.99").await.0, 429);
        // one address spraying many different emails is locked too
        for i in 0..5 { assert_eq!(post_json(&st, "/founder/v1/auth/login", json!({"email": format!("n{i}@x.com"), "password": "bad"}), "203.0.113.77").await.0, 401); }
        assert_eq!(post_json(&st, "/founder/v1/auth/login", json!({"email": "other@x.com", "password": "bad"}), "203.0.113.77").await.0, 429);
        // success clears: 3 failures then the right password then 3 more failures are NOT a lock
        let st = st_for(&url);
        for _ in 0..3 { post_json(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "bad"}), "203.0.113.60").await; }
        assert_eq!(post_json(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "right"}), "203.0.113.60").await.0, 200);
        for _ in 0..3 { assert_eq!(post_json(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "bad"}), "203.0.113.60").await.0, 401); }
    }
}
