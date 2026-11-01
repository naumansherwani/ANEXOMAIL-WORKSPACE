//! T256-1 (founder, 1 Nov 2026): a TLS 1.3 terminator that speaks AES-256-GCM ONLY, plus a prober that records what a client really negotiates.
//! Technology: Rust (rustls + tokio-rustls + hyper, ring provider), inside the founder binary. Caddy keeps 80/443; this listens on its own port (test: 8443).
//! Why it exists: Go's TLS 1.3 (Caddy) fixes the suite order (AES-128 first) and cannot be configured (golang/go#29349). Here the suite list has ONE entry,
//! so a client that offers AES-128 only is refused and everyone else lands on TLS_AES_256_GCM_SHA384. Off unless FOUNDER_TLS256_ADDR is set.
//! The prober never claims more than it saw: it reports the protocol, cipher and key-exchange group the handshake really ended on (ring has no ML-KEM, so it never claims post-quantum).
use std::sync::Arc;
use std::time::Duration;

use rustls::crypto::{ring as rp, CryptoProvider};
use rustls::pki_types::{pem::PemObject, CertificateDer, PrivateKeyDer, ServerName};
use rustls::{ClientConfig, RootCertStore, ServerConfig, SupportedCipherSuite};
use tokio::net::{TcpListener, TcpStream};
use tokio_rustls::{TlsAcceptor, TlsConnector};

const AES256: SupportedCipherSuite = rp::cipher_suite::TLS13_AES_256_GCM_SHA384;
const AES128: SupportedCipherSuite = rp::cipher_suite::TLS13_AES_128_GCM_SHA256;
const CHACHA: SupportedCipherSuite = rp::cipher_suite::TLS13_CHACHA20_POLY1305_SHA256;

fn provider(suites: Vec<SupportedCipherSuite>) -> Arc<CryptoProvider> {
    let mut p = rp::default_provider();
    p.cipher_suites = suites;
    Arc::new(p)
}

/// Server side: TLS 1.3 only, ONE cipher suite (AES-256-GCM-SHA384), HTTP/1.1.
pub fn server_config(cert_pem: &[u8], key_pem: &[u8]) -> Result<Arc<ServerConfig>, String> {
    let certs: Vec<CertificateDer<'static>> = CertificateDer::pem_slice_iter(cert_pem).collect::<Result<_, _>>().map_err(|e| format!("certificate: {e}"))?;
    if certs.is_empty() { return Err("certificate file has no certificate".into()); }
    let key = PrivateKeyDer::from_pem_slice(key_pem).map_err(|e| format!("private key: {e}"))?;
    let mut c = ServerConfig::builder_with_provider(provider(vec![AES256]))
        .with_protocol_versions(&[&rustls::version::TLS13]).map_err(|e| e.to_string())?
        .with_no_client_auth()
        .with_single_cert(certs, key).map_err(|e| e.to_string())?;
    c.alpn_protocols = vec![b"http/1.1".to_vec()];
    Ok(Arc::new(c))
}

/// Serve `router` over TLS on an already bound listener. One task per connection, 10 s to finish the handshake.
pub async fn serve(listener: TcpListener, cfg: Arc<ServerConfig>, router: axum::Router) {
    let acceptor = TlsAcceptor::from(cfg);
    loop {
        let Ok((tcp, _)) = listener.accept().await else { continue };
        let (acceptor, router) = (acceptor.clone(), router.clone());
        tokio::spawn(async move {
            let Ok(Ok(tls)) = tokio::time::timeout(Duration::from_secs(10), acceptor.accept(tcp)).await else { return };
            let svc = hyper_util::service::TowerToHyperService::new(router);
            let _ = hyper::server::conn::http1::Builder::new().serve_connection(hyper_util::rt::TokioIo::new(tls), svc).await;
        });
    }
}

/// What the prober offers. `Browser` mimics a normal browser (AES-128 first), which is exactly what decides what real users get.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Offer { Browser, Aes256Only, Aes128Only }
impl Offer {
    pub fn name(self) -> &'static str { match self { Offer::Browser => "browser", Offer::Aes256Only => "aes256_only", Offer::Aes128Only => "aes128_only" } }
    fn suites(self) -> Vec<SupportedCipherSuite> { match self { Offer::Browser => vec![AES128, AES256, CHACHA], Offer::Aes256Only => vec![AES256], Offer::Aes128Only => vec![AES128] } }
}

#[derive(Debug, Clone, PartialEq)]
pub struct Probe { pub ok: bool, pub protocol: Option<String>, pub cipher: Option<String>, pub kex: Option<String>, pub error: Option<String> }
impl Probe { fn fail(e: impl ToString) -> Probe { Probe { ok: false, protocol: None, cipher: None, kex: None, error: Some(e.to_string().chars().take(200).collect()) } } }

/// One real handshake against host:port (certificate verified against the public web roots, plus `extra_root` for tests). Never throws; failure is a result.
pub async fn probe(host: &str, port: u16, offer: Offer, extra_root: Option<CertificateDer<'static>>) -> Probe {
    let mut roots = RootCertStore::empty();
    roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    if let Some(r) = extra_root { let _ = roots.add(r); }
    let cfg = match ClientConfig::builder_with_provider(provider(offer.suites())).with_protocol_versions(&[&rustls::version::TLS13]) {
        Ok(b) => b.with_root_certificates(roots).with_no_client_auth(),
        Err(e) => return Probe::fail(e),
    };
    let Ok(name) = ServerName::try_from(host.to_string()) else { return Probe::fail("bad host name") };
    let t = Duration::from_secs(8);
    let tcp = match tokio::time::timeout(t, TcpStream::connect((host, port))).await { Ok(Ok(s)) => s, Ok(Err(e)) => return Probe::fail(e), Err(_) => return Probe::fail("connect timeout") };
    match tokio::time::timeout(t, TlsConnector::from(Arc::new(cfg)).connect(name, tcp)).await {
        Ok(Ok(tls)) => {
            let (_, c) = tls.get_ref();
            Probe { ok: true, protocol: c.protocol_version().map(|v| format!("{v:?}")), cipher: c.negotiated_cipher_suite().map(|s| format!("{:?}", s.suite())),
                    kex: c.negotiated_key_exchange_group().map(|g| format!("{:?}", g.name())), error: None }
        }
        Ok(Err(e)) => Probe::fail(e),
        Err(_) => Probe::fail("handshake timeout"),
    }
}

/// FOUNDER_TLS256_* env -> a running listener. None = switched off (the default); Err = switched on but misconfigured (the caller logs it, the main port is unaffected).
pub fn from_env() -> Option<Result<(String, Arc<ServerConfig>), String>> {
    let addr = std::env::var("FOUNDER_TLS256_ADDR").ok().filter(|a| !a.trim().is_empty())?;
    let read = |k: &str| std::env::var(k).map_err(|_| format!("{k} is not set")).and_then(|p| std::fs::read(&p).map_err(|e| format!("{p}: {e}")));
    Some((|| { let cfg = server_config(&read("FOUNDER_TLS256_CERT")?, &read("FOUNDER_TLS256_KEY")?)?; Ok((addr.clone(), cfg)) })())
}

/// FOUNDER_TLS_PROBE="host:port,host:port" -> targets for the periodic prober.
pub fn probe_targets() -> Vec<(String, u16)> {
    std::env::var("FOUNDER_TLS_PROBE").unwrap_or_default().split(',').filter_map(|t| { let (h, p) = t.trim().rsplit_once(':')?; Some((h.to_string(), p.parse().ok()?)) }).collect()
}

/// Every 6 hours (first run 20 s after start) probe each FOUNDER_TLS_PROBE target three ways and write the REAL result through the E119 door. No mock rows, ever.
pub fn spawn_prober(sb: crate::data::Sb) {
    let targets = probe_targets();
    if targets.is_empty() { return; }
    tokio::spawn(async move {
        tokio::time::sleep(Duration::from_secs(20)).await;
        loop {
            for (host, port) in &targets {
                for offer in [Offer::Browser, Offer::Aes256Only, Offer::Aes128Only] {
                    let p = probe(host, *port, offer, None).await;
                    let _ = sb.rpc("founder_tls_check_record", serde_json::json!({
                        "p_host": host, "p_port": port, "p_offered": offer.name(), "p_ok": p.ok,
                        "p_protocol": p.protocol, "p_cipher": p.cipher, "p_kex": p.kex, "p_error": p.error, "p_source": "rust"})).await;
                }
            }
            tokio::time::sleep(Duration::from_secs(6 * 3600)).await;
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    /// A throw-away self-signed certificate for `localhost`, made with the openssl CLI (the test is skipped when it is missing).
    fn test_cert() -> Option<(Vec<u8>, Vec<u8>)> {
        let d = std::env::temp_dir().join(format!("t256-{}-{:?}", std::process::id(), std::thread::current().id()));
        let _ = std::fs::create_dir_all(&d);
        let (k, c) = (d.join("k.pem"), d.join("c.pem"));
        let ok = std::process::Command::new("openssl").args(["req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes", "-days", "1", "-subj", "/CN=localhost",
            "-addext", "subjectAltName=DNS:localhost", "-addext", "basicConstraints=critical,CA:FALSE", "-keyout", k.to_str()?, "-out", c.to_str()?]).output().ok()?.status.success();
        if !ok { return None; }
        Some((std::fs::read(c).ok()?, std::fs::read(k).ok()?))
    }

    async fn up(cert: &[u8], key: &[u8]) -> u16 {
        let l = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = l.local_addr().unwrap().port();
        let cfg = server_config(cert, key).unwrap();
        let router = axum::Router::new().route("/healthz", axum::routing::get(|| async { "ok" }));
        tokio::spawn(serve(l, cfg, router));
        port
    }

    #[tokio::test]
    async fn aes256_only_server_forces_256_for_a_browser_style_client() {
        let Some((c, k)) = test_cert() else { eprintln!("openssl missing: skipped"); return };
        let port = up(&c, &k).await;
        let root = CertificateDer::pem_slice_iter(&c).next().unwrap().unwrap();
        // a browser offers AES-128 first; the server has no AES-128, so it must land on AES-256
        let p = probe("localhost", port, Offer::Browser, Some(root.clone())).await;
        assert!(p.ok, "{p:?}");
        assert_eq!(p.protocol.as_deref(), Some("TLSv1_3"));
        assert_eq!(p.cipher.as_deref(), Some("TLS13_AES_256_GCM_SHA384"));
        let p = probe("localhost", port, Offer::Aes256Only, Some(root.clone())).await;
        assert!(p.ok && p.cipher.as_deref() == Some("TLS13_AES_256_GCM_SHA384"), "{p:?}");
        // a client that can ONLY do AES-128 is refused (that is the point of "256 at every cost")
        let p = probe("localhost", port, Offer::Aes128Only, Some(root)).await;
        assert!(!p.ok && p.error.is_some() && p.cipher.is_none(), "{p:?}");
    }

    #[tokio::test]
    async fn the_terminator_really_serves_the_app_and_refuses_an_untrusted_certificate() {
        let Some((c, k)) = test_cert() else { eprintln!("openssl missing: skipped"); return };
        let port = up(&c, &k).await;
        let root = CertificateDer::pem_slice_iter(&c).next().unwrap().unwrap();
        let mut roots = RootCertStore::empty(); roots.add(root).unwrap();
        let cfg = ClientConfig::builder_with_provider(provider(vec![AES256])).with_protocol_versions(&[&rustls::version::TLS13]).unwrap().with_root_certificates(roots).with_no_client_auth();
        let tcp = TcpStream::connect(("localhost", port)).await.unwrap();
        let mut tls = TlsConnector::from(Arc::new(cfg)).connect(ServerName::try_from("localhost").unwrap(), tcp).await.unwrap();
        tls.write_all(b"GET /healthz HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n").await.unwrap();
        let mut out = String::new(); let _ = tls.read_to_string(&mut out).await;
        assert!(out.starts_with("HTTP/1.1 200") && out.ends_with("ok"), "{out}");
        // without the test root the self-signed certificate must NOT verify
        let p = probe("localhost", port, Offer::Browser, None).await;
        assert!(!p.ok, "an unknown certificate was accepted: {p:?}");
    }

    #[test]
    fn config_errors_are_plain_and_the_default_is_off() {
        assert!(server_config(b"", b"").is_err());
        assert!(server_config(b"not a pem", b"not a pem").is_err());
        assert_eq!(Offer::Browser.suites().len(), 3);
        assert_eq!(Offer::Aes256Only.name(), "aes256_only");
        // env parsing of the probe list
        unsafe { std::env::set_var("FOUNDER_TLS_PROBE", "a.example:443, b.example:8443,bad,c:x"); }
        assert_eq!(probe_targets(), vec![("a.example".to_string(), 443), ("b.example".to_string(), 8443)]);
    }
}
