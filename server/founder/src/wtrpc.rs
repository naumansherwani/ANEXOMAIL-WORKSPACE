//! K8d (founder lane, 11 Nov 2026): Rule 52, the founder API over WebTransport (HTTP/3 over QUIC) instead of `fetch`.
//!
//! The Rust WASM kernel (module `rpc@1`, already in the pinned kernel) opens ONE WebTransport session to `/wt/rpc` and sends every API call as its own bidirectional stream.
//! This file is the server half. NOTHING is duplicated: a call is turned into the same `http::Request` a browser would have sent over HTTP/3 and is run through the SAME axum
//! router with ALL its layers (host proof, signature gate, token gate, session gate, rate limits, headers), so every rule that guards the HTTP path guards this one.
//!
//! Wire format (kernel treats both as opaque bytes):
//!   request  = one JSON line `{"m":"GET|POST|PUT","p":"/founder/v1/...","h":{"authorization":"Bearer ..",...}}` + LF + the raw body bytes (stream end = request end)
//!   response = `S <status> <content-type>` + LF + the raw body bytes (stream end = response end)
//! Security shape (no loophole):
//! - Path must be `/founder/v1/...`, plain characters only, no `..`, no `//`, no `#`; never `/founder/v1/live/stream` (own WebTransport path), never `/founder/v1/dbsc/start` or `/dbsc/refresh` (Chrome calls those itself with its own cookie); `/dbsc/status` is an ordinary signed read and DOES go over the kernel (11 Nov 23:50: the old whole-prefix refusal made the Device-bound sessions card show HTTP 404).
//!   `/founder/v1/exchange` IS allowed since K8d-S4 (11 Nov 21:40): a device with a hybrid PROOF KEY (ES256 + ML-DSA-65, E164) proves itself with a signed proof instead of the cookie; the DBSC
//!   chip stays in the loop because the server also requires the chip to be alive. Every call that arrives here carries the request EXTENSION `WtCall` (set by this file only, never a header,
//!   so no client can forge it), which is how the exchange knows it came over the kernel.
//! - Only these request headers pass: authorization, content-type, accept, x-fo-ts, x-fo-sig, x-founder-kernel, x-device-proof. `host`, `x-real-ip`, `x-fo-proto`, cookies are never
//!   taken from the caller: the server sets host + the real peer address + user-agent/client-hints from the WebTransport handshake, and the protocol layer marks the call h3 (QUIC).
//! - Caps: request 1 MiB, response 8 MiB, 32 calls in flight per session, 15 s per call, session life 10 minutes (the kernel reconnects).
use std::{net::IpAddr, sync::Arc, time::Duration};
use axum::{body::Body, http::{HeaderName, HeaderValue, Method, Request, StatusCode, Version}, Router};
use http_body_util::BodyExt;
use tower::ServiceExt;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};

pub const MAX_REQ: usize = 1 << 20;
pub const MAX_RESP: usize = 8 << 20;
const MAX_HEAD: usize = 16384;
/// The hybrid device proof (ES256 + ML-DSA-65 signature) is about 5 KB; every other header stays small.
const MAX_PROOF: usize = 12288;   // = dbsc.rs parse_jwt limit: a hybrid REGISTRATION proof (ES256 + ML-DSA-65 key + signature) is ~8.5 KB; 8192 refused it live (11 Nov 23:50)
/// Marker stamped into the request EXTENSIONS of every call that came over the WebTransport kernel path.
#[derive(Clone, Copy, Debug)]
pub struct WtCall;
const MAX_INFLIGHT: usize = 32;
const CALL_WAIT: Duration = Duration::from_secs(15);
const LIFE: Duration = Duration::from_secs(600);
const ALLOW: &[&str] = &["authorization", "content-type", "accept", "x-fo-ts", "x-fo-sig", "x-founder-kernel", "x-device-proof"];

fn path_ok(p: &str) -> bool {
    p.len() <= 1024 && p.starts_with("/founder/v1/") && !p.contains("..") && !p.contains("//") && !p.contains('#')
        && p.bytes().all(|b| b.is_ascii_alphanumeric() || b"/_-.?=&%:~,+".contains(&b))
        && !p.starts_with("/founder/v1/live/stream") && !p.starts_with("/founder/v1/dbsc/start") && !p.starts_with("/founder/v1/dbsc/refresh")
}

/// Pure: bytes of one stream -> the request the router will see. Err = the HTTP status to answer.
pub fn parse(raw: &[u8], host: &str, peer: IpAddr, ua: Option<&str>, hint: Option<&str>) -> Result<Request<Body>, u16> {
    let nl = raw.iter().position(|b| *b == b'\n').ok_or(400u16)?;
    if nl > MAX_HEAD { return Err(431); }
    let head: serde_json::Value = serde_json::from_slice(&raw[..nl]).map_err(|_| 400u16)?;
    let body = &raw[nl + 1..];
    let method = match head["m"].as_str() { Some("GET") => Method::GET, Some("POST") => Method::POST, Some("PUT") => Method::PUT, _ => return Err(405) };
    let path = head["p"].as_str().ok_or(400u16)?;
    if !path_ok(path) { return Err(404); }
    if method == Method::GET && !body.is_empty() { return Err(400); }
    if body.len() > MAX_REQ { return Err(413); }
    let mut req = Request::builder().method(method).uri(path).version(Version::HTTP_3);
    let hm = req.headers_mut().ok_or(400u16)?;
    if let Some(obj) = head["h"].as_object() {
        for (k, v) in obj {
            let k = k.to_ascii_lowercase();
            if !ALLOW.contains(&k.as_str()) { continue; }
            let v = v.as_str().ok_or(400u16)?;
            if v.len() > (if k == "x-device-proof" { MAX_PROOF } else { 4096 }) || !v.bytes().all(|b| (0x20..0x7f).contains(&b)) { return Err(400); }
            hm.insert(HeaderName::from_bytes(k.as_bytes()).map_err(|_| 400u16)?, HeaderValue::from_str(v).map_err(|_| 400u16)?);
        }
    }
    hm.insert(HeaderName::from_static("host"), HeaderValue::from_str(host).map_err(|_| 400u16)?);
    hm.insert(HeaderName::from_static("x-real-ip"), HeaderValue::from_str(&peer.to_string()).map_err(|_| 400u16)?);
    for (n, v) in [("user-agent", ua), ("sec-ch-ua", hint)] {
        if let Some(v) = v.filter(|v| v.len() <= 512 && v.bytes().all(|b| (0x20..0x7f).contains(&b))) { if let Ok(hv) = HeaderValue::from_str(v) { hm.insert(HeaderName::from_static(n), hv); } }
    }
    let mut req = req.body(Body::from(body.to_vec())).map_err(|_| 400u16)?;
    req.extensions_mut().insert(WtCall);
    Ok(req)
}

/// Pure: the answer as the kernel receives it.
pub fn encode(status: u16, ctype: &str, body: &[u8]) -> Vec<u8> {
    let ct: String = ctype.chars().filter(|c| c.is_ascii() && !c.is_ascii_control()).take(100).collect();
    let mut out = format!("S {status} {}\n", if ct.is_empty() { "application/octet-stream" } else { &ct }).into_bytes();
    out.extend_from_slice(body);
    out
}

async fn one_call<W: AsyncWrite + Unpin, R: AsyncRead + Unpin>(router: Router, host: Arc<String>, peer: IpAddr, ua: Option<String>, hint: Option<String>, mut send: W, mut recv: R) {
    let mut raw = Vec::new(); let mut buf = [0u8; 16384];
    let got = tokio::time::timeout(CALL_WAIT, async { loop { match recv.read(&mut buf).await { Ok(n) if n > 0 => { raw.extend_from_slice(&buf[..n]); if raw.len() > MAX_REQ + MAX_HEAD + 1 { return false; } } Ok(_) => return true, Err(_) => return false } } }).await.unwrap_or(false);
    let answer = if !got { encode(413, "text/plain", b"The request was not accepted.") } else {
        match parse(&raw, &host, peer, ua.as_deref(), hint.as_deref()) {
            Err(c) => encode(c, "text/plain", b"The request was refused.\n"),
            Ok(req) => match tokio::time::timeout(CALL_WAIT, async { let resp = match router.oneshot(req).await { Ok(r) => r, Err(n) => match n {} }; let (parts, mut b) = resp.into_parts();
                    let mut out = Vec::new();
                    while let Some(f) = b.frame().await { match f { Ok(f) => if let Ok(d) = f.into_data() { if out.len() + d.len() > MAX_RESP { return None; } out.extend_from_slice(&d); }, Err(_) => return None } }
                    Some((parts.status.as_u16(), parts.headers.get("content-type").and_then(|v| v.to_str().ok()).unwrap_or("").to_string(), out)) }).await {
                Ok(Some((s, ct, out))) => encode(s, &ct, &out),
                Ok(None) => encode(502, "text/plain", b"The answer was too large."),
                Err(_) => encode(504, "text/plain", b"The server took too long."),
            },
        }
    };
    if send.write_all(&answer).await.is_ok() { let _ = send.shutdown().await; }
}

/// One WebTransport session = many calls (one bidirectional stream each). `accept` hands out the next bidirectional stream (None = the session is over). The SAME code runs for the
/// wtransport endpoint (its own UDP port) and for h3-webtransport on UDP 443, so both carry every gate and cap above.
pub async fn run_with<A, F, W, R>(mut accept: A, peer: IpAddr, router: Router, host: Arc<String>, ua: Option<String>, hint: Option<String>)
where A: FnMut() -> F, F: std::future::Future<Output = Option<(W, R)>>, W: AsyncWrite + Unpin + Send + 'static, R: AsyncRead + Unpin + Send + 'static {
    let gate = Arc::new(tokio::sync::Semaphore::new(MAX_INFLIGHT));
    let life = tokio::time::sleep(LIFE);
    tokio::pin!(life);
    loop {
        tokio::select! {
            s = accept() => match s {
                Some((send, recv)) => {
                    let Ok(permit) = gate.clone().acquire_owned().await else { break };
                    let (r, h, u, c) = (router.clone(), host.clone(), ua.clone(), hint.clone());
                    tokio::spawn(async move { one_call(r, h, peer, u, c, send, recv).await; drop(permit); });
                }
                None => break,
            },
            _ = &mut life => break,
        }
    }
}

#[allow(dead_code)]
pub fn refused(c: u16) -> StatusCode { StatusCode::from_u16(c).unwrap_or(StatusCode::BAD_REQUEST) }

#[cfg(test)]
mod tests {
    use super::*;
    const IP: &str = "203.0.113.9";
    fn p(j: &str, body: &[u8]) -> Result<Request<Body>, u16> { let mut v = j.as_bytes().to_vec(); v.push(b'\n'); v.extend_from_slice(body); parse(&v, "founderworkspace.anexomail.com", IP.parse().unwrap(), Some("Mozilla/5.0 Chrome/130"), Some("\"Chromium\";v=\"130\"")) }

    #[test]
    fn a_good_call_becomes_the_http3_request_the_router_expects() {
        let r = p(r#"{"m":"POST","p":"/founder/v1/devices/revoke?x=1","h":{"Authorization":"Bearer abc","content-type":"application/json","x-fo-ts":"1","x-fo-sig":"ab"}}"#, b"{\"a\":1}").unwrap();
        assert_eq!((r.method().as_str(), r.uri().path(), r.uri().query(), r.version()), ("POST", "/founder/v1/devices/revoke", Some("x=1"), Version::HTTP_3));
        let h = r.headers();
        assert_eq!(h["authorization"], "Bearer abc");
        assert_eq!(h["host"], "founderworkspace.anexomail.com");
        assert_eq!(h["x-real-ip"], IP);
        assert!(h["user-agent"].to_str().unwrap().contains("Chrome") && h["sec-ch-ua"].to_str().unwrap().contains("Chromium"));
    }
    #[test]
    fn nothing_but_the_allowlisted_headers_pass_and_the_caller_never_sets_host_ip_proto_or_cookies() {
        let r = p(r#"{"m":"GET","p":"/founder/v1/bridge","h":{"host":"evil.example","x-real-ip":"1.1.1.1","x-fo-proto":"h1","cookie":"__Host-anx_fdbsc=zz","user-agent":"curl","authorization":"Bearer t"}}"#, b"").unwrap();
        let h = r.headers();
        assert_eq!(h["host"], "founderworkspace.anexomail.com");
        assert_eq!(h["x-real-ip"], IP);
        assert!(h.get("x-fo-proto").is_none() && h.get("cookie").is_none());
        assert!(h["user-agent"].to_str().unwrap().contains("Mozilla"), "the user-agent comes from the QUIC handshake, not the caller");
    }
    #[test]
    fn the_paths_that_must_stay_on_plain_https_or_leave_the_api_are_refused() {
        for bad in ["/founder/v1/live/stream", "/founder/v1/dbsc/start", "/founder/v1/dbsc/refresh", "/other", "/founder/v1/../x", "/founder/v1//x", "/founder/v1/a#b", "founder/v1/x", "/founder/v1/a b", "/founder/v1/é"] {
            assert_eq!(p(&format!(r#"{{"m":"GET","p":"{bad}"}}"#), b"").err(), Some(404), "{bad}");
        }
    }
    #[test]
    fn a_hybrid_registration_proof_of_8_5_kb_passes_and_a_giant_one_does_not() {
        let ok = format!(r#"{{"m":"POST","p":"/founder/v1/proofkey/register","h":{{"authorization":"Bearer t","x-device-proof":"{}"}}}}"#, "a".repeat(8600));
        assert!(p(&ok, b"{}").is_ok(), "the real registration proof is 8525 bytes");
        let big = format!(r#"{{"m":"POST","p":"/founder/v1/proofkey/register","h":{{"x-device-proof":"{}"}}}}"#, "a".repeat(12300));
        assert_eq!(p(&big, b"{}").err(), Some(400));
    }
    #[test]
    fn the_dbsc_status_read_goes_over_the_kernel_but_chromes_own_start_and_refresh_never_do() {
        assert!(p(r#"{"m":"GET","p":"/founder/v1/dbsc/status"}"#, b"").is_ok(), "the board's status read must not 404 over the kernel");
        for bad in ["/founder/v1/dbsc/start", "/founder/v1/dbsc/refresh", "/founder/v1/dbsc/refresh?x=1"] { assert_eq!(p(&format!(r#"{{"m":"POST","p":"{bad}"}}"#), b"").err(), Some(404), "{bad}"); }
    }
    #[test]
    fn the_exchange_may_come_over_the_kernel_and_is_marked_so_but_only_by_the_server() {
        let r = p(r#"{"m":"POST","p":"/founder/v1/exchange","h":{"authorization":"Bearer t","x-device-proof":"a.b.c.d","x-wt-call":"1"}}"#, b"{}").unwrap();
        assert!(r.extensions().get::<WtCall>().is_some(), "the server stamps the kernel marker");
        assert!(r.headers().get("x-wt-call").is_none(), "a header can never fake the marker");
        let big = "A".repeat(6000);
        assert!(p(&format!(r#"{{"m":"POST","p":"/founder/v1/exchange","h":{{"x-device-proof":"{big}"}}}}"#), b"{}").is_ok(), "a hybrid proof (~5 KB) fits");
        assert_eq!(p(&format!(r#"{{"m":"POST","p":"/founder/v1/exchange","h":{{"authorization":"{big}"}}}}"#), b"{}").err(), Some(400), "every other header stays at 4 KB");
        assert_eq!(p(&format!(r#"{{"m":"POST","p":"/founder/v1/exchange","h":{{"x-device-proof":"{}"}}}}"#, "A".repeat(13000)), b"{}").err(), Some(400), "even the proof has a cap");
    }
    #[test]
    fn methods_bodies_and_shapes_are_checked() {
        assert_eq!(p(r#"{"m":"DELETE","p":"/founder/v1/x"}"#, b"").err(), Some(405));
        assert_eq!(p(r#"{"m":"GET","p":"/founder/v1/x"}"#, b"body").err(), Some(400), "a GET with a body is refused");
        assert_eq!(p(r#"{"m":"POST","p":"/founder/v1/x"}"#, &vec![0u8; MAX_REQ + 1]).err(), Some(413));
        assert_eq!(parse(b"no newline", "h", IP.parse().unwrap(), None, None).err(), Some(400));
        assert_eq!(p("not json", b"").err(), Some(400));
        assert_eq!(p(r#"{"m":"GET","p":"/founder/v1/x","h":{"authorization":"Bearer a\u0001b"}}"#, b"").err(), Some(400), "control bytes in a header value are refused");
        assert_eq!(p(r#"{"m":"GET","p":"/founder/v1/x","h":{"authorization":5}}"#, b"").err(), Some(400));
    }
    #[test]
    fn the_answer_is_framed_for_the_kernel() {
        assert_eq!(encode(200, "application/json", b"{}"), b"S 200 application/json\n{}".to_vec());
        assert_eq!(encode(401, "", b""), b"S 401 application/octet-stream\n".to_vec());
        assert!(!encode(200, "a\nb", b"").contains(&b'\r'), "no header injection through the content type");
        assert_eq!(encode(200, "a\nb", b"x"), b"S 200 ab\nx".to_vec());
    }
}
