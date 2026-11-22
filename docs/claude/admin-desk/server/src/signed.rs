// ANEXOMAIL ADMIN DESK signed.rs (R3d stage B, 22 Nov 2026): Rule 52 on the wire. Every /desk/v1/* answer behind this layer is SIGNED with the
// Desk's OWN Ed25519 key (sign.rs) and bound to the caller's nonce + method + path; every call after sign-in must carry the HKDF/HMAC request MAC.
// The Desk kernel in the browser (admin-desk/kernel) refuses any answer that is not signed this way. Key file: DESK_SIGN_SEED_FILE (default
// /etc/anexomail-desk/sign.seed, 64 hex, written once by desk-install, owner anexomail-desk, mode 400). No key = 503, never an unsigned answer.
use crate::{door, sign};
use axum::{body::{to_bytes, Body}, extract::Request, http::{header, HeaderValue, StatusCode}, middleware::Next, response::{IntoResponse, Response}};
use std::sync::{Mutex, OnceLock};

const SEED_FILE: &str = "/etc/anexomail-desk/sign.seed";
const MAX_REQ: usize = 64 * 1024;
const MAX_RES: usize = 4 * 1024 * 1024;
static SIGNER: OnceLock<Option<sign::Signer>> = OnceLock::new();
static NONCES: Mutex<Option<sign::NonceCache>> = Mutex::new(None);

/// Phase C: the same replay cache the doors use (one nonce, once, per session token) for the WebTransport hello.
pub fn nonce_fresh(token: &str, nonce: &str) -> bool {
    let who = sign::sha256_hex(token.as_bytes());
    NONCES.lock().map(|mut g| g.get_or_insert_with(Default::default).fresh(&who, nonce, now())).unwrap_or(false)
}
/// Phase C: a stream frame sealed with the Desk key exactly like a door answer (method "WT", path "/wt/bridge/<track>"), so the kernel's one verify path accepts it.
pub fn seal_frame(path: &str, nonce: &str, body: &str) -> Option<String> { signer().map(|s| s.envelope("WT", path, nonce, now(), body)) }
pub fn now_secs() -> i64 { now() }
#[cfg(test)] pub fn public_hex() -> Option<String> { signer().map(|s| s.public_hex()) }

pub fn init() {
    let path = std::env::var("DESK_SIGN_SEED_FILE").unwrap_or_else(|_| SEED_FILE.to_string());
    let s = match std::fs::read_to_string(&path) {
        Ok(t) => match sign::Signer::from_seed_hex(&t) { Ok(s) => { eprintln!("desk: Rule 52 signing key ready (ed25519, kid {})", s.kid()); Some(s) } Err(e) => { eprintln!("desk: signing key REFUSED ({path}): {e}"); None } },
        Err(e) => { eprintln!("desk: signing key missing ({path}): {e}; signed doors answer 503"); None }
    };
    let _ = SIGNER.set(s);
}
/// Bridge probe: a real sign + verify round trip with the Desk key. False when the key is missing or broken (never a cached answer).
pub fn selftest() -> bool {
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};
    let Some(s) = signer() else { return false };
    let env = s.envelope("GET", "/desk/v1/probe", "00112233445566778899aabbccddeeff", now(), "{}");
    let Ok(e) = serde_json::from_str::<serde_json::Value>(&env) else { return false };
    let (Some(pubk), Some(sig), Some(body), Some(ts)) = (sign::unhex(&s.public_hex()), e["sig"].as_str().and_then(sign::unhex), e["body"].as_str(), e["ts"].as_i64()) else { return false };
    let Ok(arr) = <[u8; 32]>::try_from(pubk) else { return false };
    let (Ok(vk), Ok(sg)) = (VerifyingKey::from_bytes(&arr), Signature::from_slice(&sig)) else { return false };
    vk.verify(&sign::message("GET", "/desk/v1/probe", "00112233445566778899aabbccddeeff", ts, body.as_bytes()), &sg).is_ok()
}
pub(crate) fn signer() -> Option<&'static sign::Signer> { SIGNER.get().and_then(|s| s.as_ref()) }
fn now() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }
fn plain(status: StatusCode, err: &str) -> Response { (status, [(header::CONTENT_TYPE, "application/json")], serde_json::json!({"error": err}).to_string()).into_response() }
fn hdr<'a>(r: &'a Request, k: &str) -> Option<&'a str> { r.headers().get(k).and_then(|v| v.to_str().ok()) }

// The public half, unsigned by nature (it is what the kernel pins on first sight; a later change of kid is refused by the kernel).
pub async fn key() -> Response {
    match signer() {
        Some(s) => (StatusCode::OK, [(header::CONTENT_TYPE, "application/json")], serde_json::json!({"v":1,"alg":"ed25519","kid":s.kid(),"pub":s.public_hex(),"aud":"desk"}).to_string()).into_response(),
        None => plain(StatusCode::SERVICE_UNAVAILABLE, "signing_not_configured"),
    }
}
pub async fn ping() -> Response { (StatusCode::OK, [(header::CONTENT_TYPE, "application/json")], serde_json::json!({"pong": now()}).to_string()).into_response() }

// Paths that need no session (the sign-in itself): the answer is still signed, only the request MAC is not possible yet.
fn pre_session(path: &str) -> bool { path == "/desk/v1/auth/login" }

pub async fn guard(req: Request, next: Next) -> Response {
    let Some(s) = signer() else { return plain(StatusCode::SERVICE_UNAVAILABLE, "signing_not_configured") };
    let method = req.method().as_str().to_string();
    let path = req.uri().path().to_string();
    if req.uri().query().is_some() { return plain(StatusCode::BAD_REQUEST, "query_not_allowed"); }
    let Some(nonce) = hdr(&req, "x-desk-nonce").filter(|n| sign::nonce_ok(n)).map(str::to_string) else { return plain(StatusCode::BAD_REQUEST, "unsigned_request") };
    let sealed = |status: StatusCode, body: String| -> Response {
        let mut r = (status, s.envelope(&method, &path, &nonce, now(), &body)).into_response();
        r.headers_mut().insert(header::CONTENT_TYPE, HeaderValue::from_static("application/json")); r
    };
    let mac = hdr(&req, "x-desk-mac").map(str::to_string);
    let ts = hdr(&req, "x-desk-ts").and_then(|t| t.parse::<i64>().ok());
    let token = door::token_of(req.headers());
    let (parts, body) = req.into_parts();
    let Ok(bytes) = to_bytes(body, MAX_REQ).await else { return sealed(StatusCode::PAYLOAD_TOO_LARGE, serde_json::json!({"error":"too_large"}).to_string()) };
    if !pre_session(&path) {
        let (Some(t), Some(m), Some(ts)) = (token.as_deref(), mac.as_deref(), ts) else { return sealed(StatusCode::UNAUTHORIZED, serde_json::json!({"error":"unsigned_request"}).to_string()) };
        if let Err(e) = sign::verify_req(t, &method, &path, &nonce, ts, &bytes, m, now()) { return sealed(StatusCode::UNAUTHORIZED, serde_json::json!({"error": e}).to_string()); }
        let who = sign::sha256_hex(t.as_bytes());
        let fresh = NONCES.lock().map(|mut g| g.get_or_insert_with(Default::default).fresh(&who, &nonce, now())).unwrap_or(false);
        if !fresh { return sealed(StatusCode::UNAUTHORIZED, serde_json::json!({"error":"replayed_request"}).to_string()); }
    }
    let res = next.run(Request::from_parts(parts, Body::from(bytes))).await;
    let (mut rp, rb) = res.into_parts();
    let Ok(out) = to_bytes(rb, MAX_RES).await else { return sealed(StatusCode::INTERNAL_SERVER_ERROR, serde_json::json!({"error":"answer_too_large"}).to_string()) };
    let body = String::from_utf8_lossy(&out).into_owned();
    rp.headers.insert(header::CONTENT_TYPE, HeaderValue::from_static("application/json"));
    rp.headers.remove(header::CONTENT_LENGTH);
    Response::from_parts(rp, Body::from(s.envelope(&method, &path, &nonce, now(), &body)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{routing::get, Router, middleware};
    use tower::ServiceExt;
    const NONCE: &str = "00112233445566778899aabbccddeeff";
    fn app() -> Router {
        let f = std::env::temp_dir().join("desk-sign-test.seed");
        std::fs::write(&f, "0202020202020202020202020202020202020202020202020202020202020202").unwrap();
        unsafe { std::env::set_var("DESK_SIGN_SEED_FILE", &f); }
        init();
        Router::new().route("/desk/v1/sig/ping", get(ping)).layer(middleware::from_fn(guard))
    }
    async fn call(a: Router, nonce: Option<&str>, tok: Option<&str>, mac: Option<String>, ts: i64) -> (StatusCode, String) {
        let mut b = Request::builder().uri("/desk/v1/sig/ping");
        if let Some(n) = nonce { b = b.header("x-desk-nonce", n); }
        if let Some(t) = tok { b = b.header("authorization", format!("Bearer {t}")); }
        if let Some(m) = mac { b = b.header("x-desk-mac", m).header("x-desk-ts", ts.to_string()); }
        let r = a.oneshot(b.body(Body::empty()).unwrap()).await.unwrap();
        let st = r.status(); (st, String::from_utf8(to_bytes(r.into_body(), 1 << 20).await.unwrap().to_vec()).unwrap())
    }
    fn verify(env: &str, nonce: &str) -> Option<String> {
        use ed25519_dalek::{Signature, Verifier, VerifyingKey};
        let e: serde_json::Value = serde_json::from_str(env).ok()?; let s = signer()?;
        let vk = VerifyingKey::from_bytes(&sign::unhex(&s.public_hex())?.try_into().ok()?).ok()?;
        let sig = Signature::from_slice(&sign::unhex(e["sig"].as_str()?)?).ok()?;
        let body = e["body"].as_str()?;
        vk.verify(&sign::message("GET", "/desk/v1/sig/ping", nonce, e["ts"].as_i64()?, body.as_bytes()), &sig).ok()?; Some(body.to_string())
    }
    #[tokio::test] async fn bridge_signer_probe_is_a_real_round_trip() { let _ = app(); assert!(selftest()); }
    #[tokio::test] async fn sealed_door_signs_good_calls_and_refuses_bad_ones() {
        let a = app(); let t = "ef".repeat(32); let ts = now();
        let (st, _) = call(a.clone(), None, Some(&t), None, ts).await; assert_eq!(st, StatusCode::BAD_REQUEST);
        let (st, body) = call(a.clone(), Some(NONCE), None, None, ts).await; assert_eq!(st, StatusCode::UNAUTHORIZED); assert!(verify(&body, NONCE).unwrap().contains("unsigned_request"));
        let mac = sign::req_mac(&t, "GET", "/desk/v1/sig/ping", NONCE, ts, b"");
        let (st, body) = call(a.clone(), Some(NONCE), Some(&t), Some(mac.clone()), ts).await; assert_eq!(st, StatusCode::OK);
        assert!(verify(&body, NONCE).unwrap().contains("pong"), "signed answer must verify");
        assert!(verify(&body.replace("pong", "pang"), NONCE).is_none(), "tampered answer must fail");
        let (st, body) = call(a.clone(), Some(NONCE), Some(&t), Some(mac), ts).await; assert_eq!(st, StatusCode::UNAUTHORIZED); assert!(verify(&body, NONCE).unwrap().contains("replayed_request"));
        let n2 = "ffeeddccbbaa99887766554433221100"; let bad = sign::req_mac(&"aa".repeat(32), "GET", "/desk/v1/sig/ping", n2, ts, b"");
        let (st, body) = call(a, Some(n2), Some(&t), Some(bad), ts).await; assert_eq!(st, StatusCode::UNAUTHORIZED); assert!(verify(&body, n2).unwrap().contains("bad_mac"));
    }
}
