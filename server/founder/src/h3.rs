//! K8b (founder, 11 Nov 2026): REAL HTTP/3 for the founder API. His rule (8 Nov 14:02 + 11 Nov 03:15): HTTP/3 (QUIC) is PRIMARY, h2 / http/1.1 are fallback only.
//! Technology: Rust, `h3` + `h3-quinn` on the SAME quinn/rustls (ring) stack as wt.rs, the SAME AES-256-GCM-only certificate store as the terminator (hot reload),
//! ALPN `h3`, address validation (QUIC Retry) so a spoofed source cannot use us for amplification. The request is handed to the SAME axum router as the TCP terminator
//! (one app, one set of gates), with `Version::HTTP_3` so the session ledger records "QUIC". Default OFF (env FOUNDER_H3_ADDR), its UDP port comes only from a fresh `ss` list.
//! Limits: header block (h3 default 16 KiB), body MAX_BODY, header wait 10 s, body wait 30 s, 100 concurrent requests per connection. A request for another host = 421.
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;

use axum::body::Body;
use axum::http::{header, HeaderName, HeaderValue, Request, Response, StatusCode, Version};
use bytes::{Buf, Bytes, BytesMut};
use http_body_util::BodyExt;
use tower::ServiceExt;

use crate::tls256::{host_from_authority, CertStore};

pub const MAX_BODY: usize = 2 * 1024 * 1024;
const HEADER_WAIT: Duration = Duration::from_secs(10);
const BODY_WAIT: Duration = Duration::from_secs(30);
const HOP: [&str; 6] = ["connection", "keep-alive", "proxy-connection", "transfer-encoding", "upgrade", "te"];

/// The Alt-Svc value that tells a browser "the same host speaks h3 on this UDP port" (K8e: 1 year + persist=1, so a browser keeps preferring h3 across restarts; refreshed on every answer).
pub fn alt_svc_value(port: u16) -> String { format!("h3=\":{port}\"; ma=31536000; persist=1") }

/// Response headers allowed on an HTTP/3 stream (no connection-specific headers, RFC 9114 §4.2).
pub fn h3_response_headers(h: &axum::http::HeaderMap) -> axum::http::HeaderMap {
    let mut o = axum::http::HeaderMap::new();
    for (k, v) in h { if !HOP.contains(&k.as_str()) { o.append(k.clone(), v.clone()); } }
    o
}

/// `authority` host (port and case stripped) must be exactly the founder host.
pub fn host_ok(req_host: Option<&str>, want: &str) -> bool { req_host.map(|h| h.eq_ignore_ascii_case(want)).unwrap_or(false) }

/// QUIC server configuration for the API: AES-256-GCM only (the terminator's rustls config), ALPN h3, many request streams, no 0-RTT.
pub fn quic_config(tls: &rustls::ServerConfig) -> Result<quinn::ServerConfig, String> { crate::wt::quic_config_n(tls, 100, 16) }

pub fn endpoint(addr: SocketAddr, tls: &rustls::ServerConfig) -> Result<quinn::Endpoint, String> {
    quinn::Endpoint::server(quic_config(tls)?, addr).map_err(|e| format!("bind udp {addr}: {e}"))
}

/// Follow the certificate store: a new certificate becomes the QUIC config for NEW connections without a restart.
fn follow_store(ep: quinn::Endpoint, store: Arc<CertStore>) {
    tokio::spawn(async move {
        let mut seen = Arc::as_ptr(&store.current()) as usize;
        loop {
            tokio::time::sleep(Duration::from_secs(60)).await;
            let cur = store.current(); let p = Arc::as_ptr(&cur) as usize;
            if p == seen { continue; }
            seen = p;
            match quic_config(&cur) { Ok(c) => { ep.set_server_config(Some(c)); eprintln!("founder: HTTP/3 certificate RELOADED"); } Err(e) => eprintln!("founder: HTTP/3 certificate reload REFUSED ({e})") }
        }
    });
}

pub async fn serve(ep: quinn::Endpoint, store: Arc<CertStore>, router: axum::Router, host: String, wt: Option<Arc<crate::wt::Cfg>>) {
    follow_store(ep.clone(), store);
    let host = Arc::new(host);
    while let Some(incoming) = ep.accept().await {
        // address validation: an unvalidated source gets a Retry first (anti-amplification); a validated one proceeds
        if !incoming.remote_address_validated() { let _ = incoming.retry(); continue; }
        let (router, host, wt) = (router.clone(), host.clone(), wt.clone());
        tokio::spawn(async move {
            let Ok(Ok(conn)) = tokio::time::timeout(Duration::from_secs(10), async { incoming.await }).await else { return };
            let peer = conn.remote_address();
            let mut b = h3::server::builder();
            if wt.is_some() { b.enable_webtransport(true).enable_extended_connect(true).enable_datagram(true).max_webtransport_sessions(crate::wt::MAX_SESSIONS as u64); }
            let Ok(mut h3c) = b.build::<_, Bytes>(h3_quinn::Connection::new(conn)).await else { return };
            loop {
                let Ok(Some(resolver)) = h3c.accept().await else { break };
                // the request head is read here (not in a task) so a WebTransport CONNECT can take the connection over; a slow head only delays this one connection
                let Ok(Ok((req, stream))) = tokio::time::timeout(HEADER_WAIT, resolver.resolve_request()).await else { continue };
                if req.method() == axum::http::Method::CONNECT && req.extensions().get::<h3::ext::Protocol>() == Some(&h3::ext::Protocol::WEB_TRANSPORT) {
                    let Some(cfg) = wt.clone() else { let mut s = stream; reply(&mut s, StatusCode::NOT_IMPLEMENTED, "Not served.").await; continue };
                    webtransport(req, stream, h3c, cfg, peer).await;
                    return; // the connection now belongs to the WebTransport session
                }
                let (router, host) = (router.clone(), host.clone());
                tokio::spawn(async move { request(req, stream, router, peer, host).await });
            }
        });
    }
}

/// A WebTransport CONNECT on the HTTP/3 endpoint. The same rules as the separate WebTransport port: exact host, only /wt/live or /wt/rpc, same-origin Origin, session cap.
async fn webtransport(req: Request<()>, mut stream: h3::server::RequestStream<h3_quinn::BidiStream<Bytes>, Bytes>, h3c: h3::server::Connection<h3_quinn::Connection, Bytes>, cfg: Arc<crate::wt::Cfg>, peer: SocketAddr) {
    use crate::wt::{authority_host, origin_ok, PATH, RPC_PATH};
    let path = req.uri().path().to_string();
    let rpc = path == RPC_PATH && cfg.rpc.is_some();
    let host_ok = req.uri().authority().map(|a| authority_host(a.as_str()) == cfg.host).unwrap_or(false);
    if !host_ok || (path != PATH && !rpc) { reply(&mut stream, StatusCode::NOT_FOUND, "Not found.").await; return; }
    let origin = req.headers().get(header::ORIGIN).and_then(|v| v.to_str().ok());
    if !origin_ok(origin, &cfg.host) { reply(&mut stream, StatusCode::FORBIDDEN, "Wrong origin.").await; return; }
    let Some(_slot) = crate::wt::Active::take() else { reply(&mut stream, StatusCode::TOO_MANY_REQUESTS, "Busy.").await; return };
    let ua = req.headers().get(header::USER_AGENT).and_then(|v| v.to_str().ok()).map(String::from);
    let hint = req.headers().get("sec-ch-ua").and_then(|v| v.to_str().ok()).map(String::from);
    let Ok(session) = h3_webtransport::server::WebTransportSession::accept(req, stream, h3c).await else { return };
    let session = Arc::new(session);
    if rpc {
        if let Some(router) = cfg.rpc.clone() {
            let s = session.clone();
            crate::wtrpc::run_with(move || { let s = s.clone(); async move { loop { match s.accept_bi().await { Ok(Some(h3_webtransport::server::AcceptedBi::BidiStream(_, bi))) => { let (r, w) = tokio::io::split(bi); return Some((w, r)); } Ok(Some(h3_webtransport::server::AcceptedBi::Request(_, mut st))) => { tokio::spawn(async move { reply(&mut st, StatusCode::MISDIRECTED_REQUEST, "Open a new connection.").await }); continue } _ => return None } } } }, peer.ip(), router, Arc::new(cfg.host.clone()), ua, hint).await;
        }
        return;
    }
    crate::wt::count_session(peer);
    let first = tokio::time::timeout(crate::wt::HELLO_WAIT, session.accept_bi()).await;
    let Ok(Ok(Some(h3_webtransport::server::AcceptedBi::BidiStream(_, bi)))) = first else { return };
    let (mut recv, mut send) = tokio::io::split(bi);
    // `closed` = the peer closed the session (audit 14 Nov: without it an idle stream held its slot for the whole 10 minutes after the browser left); a pooled plain request on this connection gets 421
    let s2 = session.clone();
    let closed = async move { loop { match s2.accept_bi().await { Ok(Some(h3_webtransport::server::AcceptedBi::Request(_, mut st))) => { tokio::spawn(async move { reply(&mut st, StatusCode::MISDIRECTED_REQUEST, "Open a new connection.").await }); } Ok(Some(_)) => continue, _ => break } } };
    let _ = crate::wt::live_session(&mut send, &mut recv, &cfg, closed).await;
    // graceful end: the stream is finished, now give the peer a moment to read the last frames and close; dropping the session at once would cut them off
    let _ = tokio::time::timeout(Duration::from_secs(5), async { loop { match session.accept_bi().await { Ok(Some(_)) => continue, _ => break } } }).await;
}

async fn reply<S: h3::quic::SendStream<Bytes>>(s: &mut h3::server::RequestStream<S, Bytes>, code: StatusCode, msg: &'static str) {
    let r = Response::builder().status(code).header(header::CACHE_CONTROL, "no-store").header(header::CONTENT_TYPE, "text/plain; charset=utf-8").body(()).unwrap();
    if s.send_response(r).await.is_ok() { let _ = s.send_data(Bytes::from_static(msg.as_bytes())).await; let _ = s.finish().await; }
}

async fn request(req: Request<()>, mut stream: h3::server::RequestStream<h3_quinn::BidiStream<Bytes>, Bytes>, router: axum::Router, peer: SocketAddr, host: Arc<String>) {
    let want = req.uri().authority().map(|a| a.host().to_string());
    if !host_ok(want.as_deref(), &host) { reply(&mut stream, StatusCode::MISDIRECTED_REQUEST, "Wrong host.").await; return; }
    let mut body = BytesMut::new();
    let got = tokio::time::timeout(BODY_WAIT, async {
        loop {
            match stream.recv_data().await {
                Ok(Some(mut b)) => { if body.len() + b.remaining() > MAX_BODY { return Err(StatusCode::PAYLOAD_TOO_LARGE); } let n = b.remaining(); body.extend_from_slice(&b.copy_to_bytes(n)); }
                Ok(None) => return Ok(()),
                Err(_) => return Err(StatusCode::BAD_REQUEST),
            }
        }
    }).await;
    match got { Ok(Ok(())) => {}, Ok(Err(c)) => { reply(&mut stream, c, "The request body was not accepted.").await; return; }, Err(_) => { reply(&mut stream, StatusCode::REQUEST_TIMEOUT, "The request body took too long.").await; return; } }
    let (mut parts, _) = req.into_parts();
    parts.version = Version::HTTP_3;
    let mut req = Request::from_parts(parts, Body::from(body.freeze()));
    if let Ok(v) = HeaderValue::from_str(&peer.ip().to_string()) { req.headers_mut().insert(HeaderName::from_static("x-real-ip"), v); } // a client-sent x-real-ip is always overwritten
    host_from_authority(&mut req);
    let resp = match router.oneshot(req).await { Ok(r) => r, Err(never) => match never {} };
    let (parts, mut rbody) = resp.into_parts();
    let head = {
        let mut r = Response::new(()); *r.status_mut() = parts.status; *r.headers_mut() = h3_response_headers(&parts.headers); r
    };
    if stream.send_response(head).await.is_err() { return; }
    while let Some(frame) = rbody.frame().await {
        match frame {
            Ok(f) => if let Ok(d) = f.into_data() { if !d.is_empty() && stream.send_data(d).await.is_err() { return; } },
            Err(_) => return,
        }
    }
    let _ = stream.finish().await;
}

/// FOUNDER_H3_ADDR (UDP, e.g. 0.0.0.0:443) + FOUNDER_H3_HOST (default the founder host). None = off (default).
pub fn from_env() -> Option<Result<(SocketAddr, String), String>> {
    let a = std::env::var("FOUNDER_H3_ADDR").ok().filter(|a| !a.trim().is_empty())?;
    Some((|| {
        let sa: SocketAddr = a.parse().map_err(|e| format!("FOUNDER_H3_ADDR: {e}"))?;
        let host = std::env::var("FOUNDER_H3_HOST").unwrap_or_else(|_| crate::fproxy::HOST.to_string()).to_ascii_lowercase();
        if host.is_empty() || host.contains(['/', ':', ' ']) { return Err("FOUNDER_H3_HOST must be a plain host name".into()); }
        Ok((sa, host))
    })())
}

#[cfg(test)]
mod tests {
    use super::*;
    use rustls::pki_types::pem::PemObject;
    #[test] fn alt_svc_names_the_udp_port() { assert_eq!(alt_svc_value(443), "h3=\":443\"; ma=31536000; persist=1"); }
    #[test] fn only_the_founder_host_is_served() { assert!(host_ok(Some("FounderWorkspace.anexomail.com"), "founderworkspace.anexomail.com")); assert!(!host_ok(Some("anexomail.com"), "founderworkspace.anexomail.com")); assert!(!host_ok(None, "x")); }
    #[test] fn connection_headers_never_go_on_an_h3_stream() {
        let mut h = axum::http::HeaderMap::new();
        for (k, v) in [("connection", "close"), ("transfer-encoding", "chunked"), ("keep-alive", "1"), ("content-type", "a"), ("alt-svc", "h3=\":443\"")] { h.insert(HeaderName::from_static(k), HeaderValue::from_static(v)); }
        let o = h3_response_headers(&h);
        assert!(o.get("connection").is_none() && o.get("transfer-encoding").is_none() && o.get("keep-alive").is_none());
        assert!(o.get("content-type").is_some() && o.get("alt-svc").is_some());
    }

    fn test_cert() -> Option<(Vec<u8>, Vec<u8>)> {
        let d = std::env::temp_dir().join(format!("h3-{}-{:?}", std::process::id(), std::thread::current().id()));
        let _ = std::fs::create_dir_all(&d);
        let (k, c) = (d.join("k.pem"), d.join("c.pem"));
        let ok = std::process::Command::new("openssl").args(["req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes", "-days", "1", "-subj", "/CN=localhost",
            "-addext", "subjectAltName=DNS:localhost", "-addext", "basicConstraints=critical,CA:FALSE", "-keyout", k.to_str()?, "-out", c.to_str()?]).output().ok()?.status.success();
        if !ok { return None; }
        Some((std::fs::read(c).ok()?, std::fs::read(k).ok()?))
    }

    /// END TO END: a real HTTP/3 client (QUIC, AES-256-GCM) asks the axum app through the h3 listener: the answer is 200, the app saw Version::HTTP_3, x-real-ip is the peer,
    /// a POST body arrives intact, a wrong host gets 421, and Alt-Svc/connection headers are handled.
    #[tokio::test]
    async fn a_real_http3_client_gets_the_app_over_quic() {
        let Some((c, k)) = test_cert() else { eprintln!("openssl missing: skipped"); return };
        let cfg = crate::tls256::server_config(&c, &k).unwrap();
        let store = Arc::new(CertStore::fixed(cfg.clone()));
        let ep = endpoint("127.0.0.1:0".parse().unwrap(), &cfg).unwrap();
        let port = ep.local_addr().unwrap().port();
        let app = axum::Router::new()
            .route("/v", axum::routing::get(|req: Request<Body>| async move { format!("{:?} {}", req.version(), req.headers().get("x-real-ip").and_then(|v| v.to_str().ok()).unwrap_or("-")) }))
            .route("/echo", axum::routing::post(|b: axum::body::Bytes| async move { format!("{}", b.len()) }));
        let wtc = Arc::new(crate::wt::Cfg { host: "localhost".into(), handler: Arc::new(|_h| Box::pin(async { Response::builder().status(200).body(Body::empty()).unwrap() })), rpc: None });
        tokio::spawn(serve(ep, store, app, "localhost".into(), Some(wtc))); // WebTransport ON must not disturb plain HTTP/3 requests
        // client
        let root = rustls::pki_types::CertificateDer::from_pem_slice(&c).unwrap();
        let mut roots = rustls::RootCertStore::empty(); roots.add(root).unwrap();
        let prov = { let mut p = rustls::crypto::ring::default_provider(); p.cipher_suites = vec![rustls::crypto::ring::cipher_suite::TLS13_AES_256_GCM_SHA384, rustls::crypto::ring::cipher_suite::TLS13_AES_128_GCM_SHA256]; Arc::new(p) };
        let mut cc = rustls::ClientConfig::builder_with_provider(prov).with_protocol_versions(&[&rustls::version::TLS13]).unwrap().with_root_certificates(roots).with_no_client_auth();
        cc.alpn_protocols = vec![b"h3".to_vec()];
        let qc = quinn::ClientConfig::new(Arc::new(quinn::crypto::rustls::QuicClientConfig::try_from(cc).unwrap()));
        let mut cep = quinn::Endpoint::client("127.0.0.1:0".parse().unwrap()).unwrap(); cep.set_default_client_config(qc);
        let conn = cep.connect(([127, 0, 0, 1], port).into(), "localhost").unwrap().await.unwrap();
        let (mut driver, mut send) = h3::client::new(h3_quinn::Connection::new(conn)).await.unwrap();
        tokio::spawn(async move { let _ = std::future::poll_fn(|cx| driver.poll_close(cx)).await; });
        let ask = |mut send: h3::client::SendRequest<h3_quinn::OpenStreams, Bytes>, uri: &'static str, method: &'static str, body: &'static [u8]| async move {
            let r = Request::builder().method(method).uri(uri).body(()).unwrap();
            let mut s = send.send_request(r).await.unwrap();
            if !body.is_empty() { s.send_data(Bytes::from_static(body)).await.unwrap(); }
            s.finish().await.unwrap();
            let resp = s.recv_response().await.unwrap();
            let mut out = Vec::new(); while let Some(mut b) = s.recv_data().await.unwrap() { let n = b.remaining(); out.extend_from_slice(&b.copy_to_bytes(n)); }
            (resp.status(), String::from_utf8(out).unwrap())
        };
        let (st, b) = ask(send.clone(), "https://localhost/v", "GET", b"").await;
        assert_eq!(st, 200); assert_eq!(b, "HTTP/3.0 127.0.0.1", "{b}");
        let (st, b) = ask(send.clone(), "https://localhost/echo", "POST", b"hello h3").await;
        assert_eq!((st.as_u16(), b.as_str()), (200, "8"));
        let (st, _) = ask(send.clone(), "https://evil.example/v", "GET", b"").await;
        assert_eq!(st.as_u16(), 421);
        let _ = &mut send;
    }
    #[test] fn env_off_by_default_and_bad_host_refused() {
        assert!(std::env::var("FOUNDER_H3_ADDR").is_err() || from_env().is_some());
    }
}
