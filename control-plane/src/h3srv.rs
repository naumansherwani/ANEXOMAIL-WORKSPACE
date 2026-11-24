// CONTROL PLANE h3srv.rs (D5a-3b): HTTP/3 over QUIC only. TLS 1.3, AES-256-GCM only, X25519MLKEM768 first, ALPN h3, no 0-RTT, BBR. Routes: POST /control/v1/lookup, census, deliverability, consent, resolve (T3b).
use crate::core::Core;
use bytes::{Buf, Bytes};
use rustls::crypto::ring as rp;
use std::{sync::Arc, time::Duration};

pub const PATH: &str = "/control/v1/lookup";
pub const CENSUS_PATH: &str = "/control/v1/census";
pub const DELIV_PATH: &str = "/control/v1/deliverability";
pub const CONSENT_PATH: &str = "/control/v1/consent";
pub const RESOLVE_PATH: &str = "/control/v1/resolve";
pub const TENANT_PATH: &str = "/control/v1/tenant";
const MAX_BODY: usize = 16 * 1024;

/// The ONE list of doors this server answers (T4e fix, 25 Nov 2026: the tenant door was added to the dispatcher but not to this list, so the live proof got a 404). A test below proves every path constant is here.
pub fn known_path(p: &str) -> bool { [PATH, CENSUS_PATH, DELIV_PATH, CONSENT_PATH, RESOLVE_PATH, TENANT_PATH].contains(&p) }

pub fn provider() -> Arc<rustls::crypto::CryptoProvider> {
    let mut p = rp::default_provider();
    p.cipher_suites = vec![rp::cipher_suite::TLS13_AES_256_GCM_SHA384];
    p.kx_groups.insert(0, rustls_post_quantum::X25519MLKEM768);
    Arc::new(p)
}
pub fn server_config(cert_pem: &[u8], key_pem: &[u8]) -> Result<rustls::ServerConfig, String> {
    let certs = rustls_pemfile::certs(&mut &*cert_pem).collect::<Result<Vec<_>, _>>().map_err(|e| format!("certificate: {e}"))?;
    if certs.is_empty() { return Err("certificate file has no certificate".into()); }
    let key = rustls_pemfile::private_key(&mut &*key_pem).map_err(|e| format!("private key: {e}"))?.ok_or("private key file has no key")?;
    let mut c = rustls::ServerConfig::builder_with_provider(provider()).with_protocol_versions(&[&rustls::version::TLS13]).map_err(|e| e.to_string())?
        .with_no_client_auth().with_single_cert(certs, key).map_err(|e| e.to_string())?;
    c.alpn_protocols = vec![b"h3".to_vec()]; c.max_early_data_size = 0; Ok(c)
}
pub fn quic_config(tls: rustls::ServerConfig) -> Result<quinn::ServerConfig, String> {
    let initial = rp::cipher_suite::TLS13_AES_128_GCM_SHA256.tls13().and_then(|s| s.quic_suite()).ok_or("no QUIC initial suite")?;
    let q = quinn::crypto::rustls::QuicServerConfig::with_initial(Arc::new(tls), initial).map_err(|e| e.to_string())?;
    let mut sc = quinn::ServerConfig::with_crypto(Arc::new(q));
    let mut t = quinn::TransportConfig::default();
    t.max_idle_timeout(Some(Duration::from_secs(30).try_into().map_err(|_| "idle timeout")?));
    t.max_concurrent_bidi_streams(16u32.into()); t.max_concurrent_uni_streams(8u32.into());
    t.congestion_controller_factory(Arc::new(quinn::congestion::BbrConfig::default()));
    sc.transport_config(Arc::new(t)); Ok(sc)
}
pub fn now_secs() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }

pub async fn serve(ep: quinn::Endpoint, core: Arc<Core>) {
    let gate = Arc::new(tokio::sync::Semaphore::new(64));
    while let Some(incoming) = ep.accept().await {
        let Ok(permit) = gate.clone().try_acquire_owned() else { incoming.refuse(); continue };
        let core = core.clone();
        tokio::spawn(async move {
            let _p = permit;
            let Ok(Ok(conn)) = tokio::time::timeout(Duration::from_secs(10), async { incoming.await }).await else { return };
            let Ok(mut h3c) = h3::server::builder().build::<_, Bytes>(h3_quinn::Connection::new(conn)).await else { return };
            loop {
                let Ok(Some(resolver)) = h3c.accept().await else { break };
                let Ok(Ok((req, mut st))) = tokio::time::timeout(Duration::from_secs(5), resolver.resolve_request()).await else { continue };
                let core = core.clone();
                tokio::spawn(async move {
                    let reply = |code: u16| http::Response::builder().status(code).header("content-type", "application/json").body(()).unwrap();
                    let path = req.uri().path().to_string(); if req.method() != http::Method::POST || (!known_path(&path)) { let _ = st.send_response(reply(404)).await; let _ = st.finish().await; return; }
                    let mut got = Vec::new();
                    let read = tokio::time::timeout(Duration::from_secs(5), async { while let Ok(Some(mut b)) = st.recv_data().await { let n = b.remaining(); got.extend_from_slice(&b.copy_to_bytes(n)); if got.len() > MAX_BODY { return false; } } true }).await;
                    if !matches!(read, Ok(true)) { let _ = st.send_response(reply(413)).await; let _ = st.finish().await; return; }
                    let Ok(body) = String::from_utf8(got) else { let _ = st.send_response(reply(400)).await; let _ = st.finish().await; return };
                    let (code, out) = if path == CENSUS_PATH { core.handle_census(&body, now_secs()).await } else if path == DELIV_PATH { core.handle_deliv(&body, now_secs()).await } else if path == CONSENT_PATH { core.handle_consent(&body, now_secs()).await } else if path == RESOLVE_PATH { core.handle_resolve(&body, now_secs()).await } else if path == TENANT_PATH { core.handle_tenant(&body, now_secs()).await } else { core.handle(&body, now_secs()).await };
                    let _ = st.send_response(reply(code)).await; if !out.is_empty() { let _ = st.send_data(Bytes::from(out)).await; } let _ = st.finish().await;
                });
            }
        });
    }
}

#[cfg(test)]
mod route_t {
    use super::*;
    #[test] fn every_door_path_is_in_the_known_list_and_nothing_else_is() {
        for p in [PATH, CENSUS_PATH, DELIV_PATH, CONSENT_PATH, RESOLVE_PATH, TENANT_PATH] { assert!(known_path(p), "{p}"); }
        for p in ["/", "/control/v1", "/control/v1/tenant/", "/control/v1/bind", "/control/v1/TENANT"] { assert!(!known_path(p), "{p}"); }
    }
}
