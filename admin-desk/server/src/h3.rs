//! ADMIN DESK R3a0-s2 (21 Nov 2026): the Desk's OWN HTTP/3 (QUIC) listener. His word 09:18: HTTP/3 is the ONLY HTTP, every older HTTP version is banned.
//! Technology: Rust, Tokio, quinn + h3 (ring provider), TLS 1.3 with ONE cipher suite (TLS13_AES_256_GCM_SHA384), key exchange X25519MLKEM768 FIRST
//! (rustls_post_quantum, post-quantum hybrid), ALPN h3 only, QUIC address validation (Retry) under flood, connection migration on, no 0-RTT.
//! It is the Desk's own copy of the pattern (DESK ISOLATION LAW: nothing imported from the founder crate). The request goes to the SAME axum router
//! as the loopback listener (one app, one host gate, one set of headers). OFF unless DESK_H3_ADDR is set; its UDP port comes only from his fresh `ss` paste.
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;

use axum::body::Body;
use axum::http::{HeaderName, HeaderValue, Request, Response, StatusCode, Version, header};
use bytes::{Buf, Bytes, BytesMut};
use http_body_util::BodyExt;
use rustls::crypto::ring as rp;
use rustls::pki_types::{CertificateDer, PrivateKeyDer};
use tower::ServiceExt;

pub const MAX_BODY: usize = 1024 * 1024;
const HEADER_WAIT: Duration = Duration::from_secs(10);
const BODY_WAIT: Duration = Duration::from_secs(30);
pub const RETRY_ABOVE: usize = 32;
const HOP: [&str; 6] = ["connection", "keep-alive", "proxy-connection", "transfer-encoding", "upgrade", "te"];
static HANDSHAKES: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);

/// Alt-Svc value for the TCP answers: "the same host speaks h3 on this UDP port" (1 year, persist).
pub fn alt_svc_value(port: u16) -> String { format!("h3=\":{port}\"; ma=31536000; persist=1") }
pub fn host_ok(authority_host: Option<&str>, want: &str) -> bool { authority_host.map(|h| h.eq_ignore_ascii_case(want)).unwrap_or(false) }
pub fn need_retry(validated: bool, in_flight: usize) -> bool { !validated && in_flight >= RETRY_ABOVE }
pub fn h3_response_headers(h: &axum::http::HeaderMap) -> axum::http::HeaderMap {
    let mut o = axum::http::HeaderMap::new();
    for (k, v) in h { if !HOP.contains(&k.as_str()) { o.append(k.clone(), v.clone()); } }
    o
}

/// The crypto provider: ring ciphers cut down to AES-256-GCM-SHA384 ONLY, the post-quantum hybrid group X25519MLKEM768 inserted FIRST (from aws-lc-rs: ring has no ML-KEM).
pub fn provider() -> Arc<rustls::crypto::CryptoProvider> {
    let mut p = rp::default_provider();
    p.cipher_suites = vec![rp::cipher_suite::TLS13_AES_256_GCM_SHA384];
    p.kx_groups.insert(0, rustls_post_quantum::X25519MLKEM768);
    Arc::new(p)
}

/// TLS 1.3 only, one cipher suite, ALPN h3 only, no client auth.
pub fn server_config(cert_pem: &[u8], key_pem: &[u8]) -> Result<rustls::ServerConfig, String> {
    let certs: Vec<CertificateDer<'static>> = rustls_pemfile::certs(&mut &*cert_pem).collect::<Result<_, _>>().map_err(|e| format!("certificate: {e}"))?;
    if certs.is_empty() { return Err("certificate file has no certificate".into()); }
    let key: PrivateKeyDer<'static> = rustls_pemfile::private_key(&mut &*key_pem).map_err(|e| format!("private key: {e}"))?.ok_or("private key file has no key")?;
    let mut c = rustls::ServerConfig::builder_with_provider(provider())
        .with_protocol_versions(&[&rustls::version::TLS13]).map_err(|e| e.to_string())?
        .with_no_client_auth()
        .with_single_cert(certs, key).map_err(|e| e.to_string())?;
    c.alpn_protocols = vec![b"h3".to_vec()];
    c.max_early_data_size = 0; // no 0-RTT
    Ok(c)
}

/// QUIC needs the AES-128 INITIAL suite only for the very first (public-key-less) packets; every session key afterwards is AES-256-GCM.
pub fn quic_config(tls: rustls::ServerConfig) -> Result<quinn::ServerConfig, String> {
    let initial = rp::cipher_suite::TLS13_AES_128_GCM_SHA256.tls13().and_then(|s| s.quic_suite()).ok_or("no QUIC initial suite")?;
    let q = quinn::crypto::rustls::QuicServerConfig::with_initial(Arc::new(tls), initial).map_err(|e| e.to_string())?;
    let mut sc = quinn::ServerConfig::with_crypto(Arc::new(q));
    let mut t = quinn::TransportConfig::default();
    t.max_idle_timeout(Some(Duration::from_secs(30).try_into().map_err(|_| "idle timeout")?));
    t.keep_alive_interval(Some(Duration::from_secs(10)));
    t.max_concurrent_bidi_streams(64u32.into());
    t.max_concurrent_uni_streams(8u32.into());
    sc.transport_config(Arc::new(t));
    sc.migration(true);
    Ok(sc)
}

/// DESK_H3_ADDR (UDP, e.g. 0.0.0.0:<port from his ss>) + DESK_H3_CERT + DESK_H3_KEY. None = off (default).
pub fn from_env() -> Option<Result<(SocketAddr, rustls::ServerConfig), String>> {
    let a = std::env::var("DESK_H3_ADDR").ok().filter(|a| !a.trim().is_empty())?;
    Some((|| {
        let sa: SocketAddr = a.parse().map_err(|e| format!("DESK_H3_ADDR: {e}"))?;
        let get = |k: &str| std::env::var(k).map_err(|_| format!("{k} is not set"));
        let rd = |p: String| std::fs::read(&p).map_err(|e| format!("{p}: {e}"));
        Ok((sa, server_config(&rd(get("DESK_H3_CERT")?)?, &rd(get("DESK_H3_KEY")?)?)?))
    })())
}

pub async fn serve(ep: quinn::Endpoint, router: axum::Router, host: String) {
    let host = Arc::new(host);
    while let Some(incoming) = ep.accept().await {
        if need_retry(incoming.remote_address_validated(), HANDSHAKES.load(std::sync::atomic::Ordering::Relaxed)) { let _ = incoming.retry(); continue; }
        let (router, host) = (router.clone(), host.clone());
        HANDSHAKES.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        tokio::spawn(async move {
            let hs = tokio::time::timeout(Duration::from_secs(10), async { incoming.await }).await;
            HANDSHAKES.fetch_sub(1, std::sync::atomic::Ordering::Relaxed);
            let Ok(Ok(conn)) = hs else { return };
            let Ok(mut h3c) = h3::server::builder().build::<_, Bytes>(h3_quinn::Connection::new(conn)).await else { return };
            loop {
                let Ok(Some(resolver)) = h3c.accept().await else { break };
                let Ok(Ok((req, stream))) = tokio::time::timeout(HEADER_WAIT, resolver.resolve_request()).await else { continue };
                let (router, host) = (router.clone(), host.clone());
                tokio::spawn(async move { request(req, stream, router, host).await });
            }
        });
    }
}

async fn reply<S: h3::quic::SendStream<Bytes>>(s: &mut h3::server::RequestStream<S, Bytes>, code: StatusCode, msg: &'static str) {
    let r = Response::builder().status(code).header(header::CACHE_CONTROL, "no-store").header(header::CONTENT_TYPE, "text/plain; charset=utf-8").body(()).unwrap();
    if s.send_response(r).await.is_ok() { let _ = s.send_data(Bytes::from_static(msg.as_bytes())).await; let _ = s.finish().await; }
}

async fn request(req: Request<()>, mut stream: h3::server::RequestStream<h3_quinn::BidiStream<Bytes>, Bytes>, router: axum::Router, host: Arc<String>) {
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
    // the router's host gate reads the Host header; an HTTP/3 request carries :authority instead
    if let Some(a) = parts.uri.authority().map(|a| a.as_str().to_string()) { if let Ok(v) = HeaderValue::from_str(&a) { parts.headers.insert(header::HOST, v); } }
    let req = Request::from_parts(parts, Body::from(body.freeze()));
    let resp = match router.oneshot(req).await { Ok(r) => r, Err(never) => match never {} };
    let (parts, mut rbody) = resp.into_parts();
    let head = { let mut r = Response::new(()); *r.status_mut() = parts.status; *r.headers_mut() = h3_response_headers(&parts.headers); r };
    if stream.send_response(head).await.is_err() { return; }
    while let Some(frame) = rbody.frame().await {
        match frame { Ok(f) => if let Ok(d) = f.into_data() { if !d.is_empty() && stream.send_data(d).await.is_err() { return; } }, Err(_) => return }
    }
    let _ = stream.finish().await;
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn alt_svc_names_the_udp_port() { assert_eq!(alt_svc_value(7443), "h3=\":7443\"; ma=31536000; persist=1"); }
    #[test] fn only_the_desk_host_is_served() { assert!(host_ok(Some("AdminDesk.anexomail.com"), "admindesk.anexomail.com")); assert!(!host_ok(Some("founderworkspace.anexomail.com"), "admindesk.anexomail.com")); assert!(!host_ok(None, "x")); }
    #[test] fn retry_only_for_unvalidated_under_flood() { assert!(!need_retry(true, 999)); assert!(!need_retry(false, 1)); assert!(need_retry(false, RETRY_ABOVE)); }
    #[test] fn connection_headers_never_go_on_an_h3_stream() {
        let mut h = axum::http::HeaderMap::new();
        for (k, v) in [("connection", "close"), ("transfer-encoding", "chunked"), ("content-type", "a")] { h.insert(HeaderName::from_static(k), HeaderValue::from_static(v)); }
        let o = h3_response_headers(&h);
        assert!(o.get("connection").is_none() && o.get("transfer-encoding").is_none() && o.get("content-type").is_some());
    }
    #[test] fn provider_has_one_cipher_and_the_pq_group_first() {
        let p = provider();
        assert_eq!(p.cipher_suites.len(), 1);
        assert_eq!(format!("{:?}", p.cipher_suites[0].suite()), "TLS13_AES_256_GCM_SHA384");
        assert!(format!("{:?}", p.kx_groups[0].name()).contains("MLKEM"), "{:?}", p.kx_groups[0].name());
    }
}
