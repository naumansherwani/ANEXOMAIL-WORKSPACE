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

/// Serve `router` over TLS on an already bound listener with a FIXED configuration (tests and simple use).
pub async fn serve(listener: TcpListener, cfg: Arc<ServerConfig>, router: axum::Router) { serve_store(listener, Arc::new(CertStore::fixed(cfg)), router).await }

/// K4.3: serve with a certificate store that can be swapped while running. Every NEW connection takes the store's current config; connections already open keep theirs.
pub async fn serve_store(listener: TcpListener, store: Arc<CertStore>, router: axum::Router) { serve_store_px(listener, store, router, false).await }

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// K4.5 (founder, 8 Nov 2026): behind the SNI front every client would look like 127.0.0.1. The front sends a PROXY protocol v1 line first; the terminator reads it BEFORE the
// TLS handshake, but only from a loopback peer (the front), and only when switched on (FOUNDER_TLS_PROXY=on). A TLS record never starts with 'P' (0x16), so a direct
// connection and a fronted one are told apart by the first bytes. The real client IP is handed to the app as `x-real-ip` (a client-sent one is always overwritten).
// ---------------------------------------------------------------------------------------------------------------------------------------------------
#[derive(Debug, PartialEq)]
pub enum Px { Need, Ok(Option<std::net::SocketAddr>, usize), Bad }

/// Strict PROXY v1 parser: "PROXY TCP4|TCP6 src dst sport dport\r\n" (<= 107 bytes) or "PROXY UNKNOWN\r\n". LF-only, v2 signature, wrong family, bad numbers = Bad.
pub fn parse_proxy_v1(b: &[u8]) -> Px {
    const SIG: &[u8] = b"PROXY ";
    let m = b.len().min(SIG.len());
    if b[..m] != SIG[..m] { return Px::Bad; }
    let lim = b.len().min(107);
    // The line ends at the first CR or LF: it must be exactly CR LF. A lone LF, a CR followed by anything else, or a control/non-ASCII byte is refused at once (no waiting for a timeout).
    let mut p = None;
    for (i, &c) in b[..lim].iter().enumerate() {
        match c {
            b'\r' => { match b.get(i + 1) { Some(b'\n') => { p = Some(i); break; } Some(_) => return Px::Bad, None => return Px::Need } }
            b'\n' => return Px::Bad,
            0x20..=0x7e => {}
            _ => return Px::Bad,
        }
    }
    let Some(p) = p else { return if b.len() >= 107 { Px::Bad } else { Px::Need } };
    let Ok(line) = std::str::from_utf8(&b[..p]) else { return Px::Bad };
    let used = p + 2;
    let f: Vec<&str> = line.split(' ').collect();
    if f.len() == 2 && f[1] == "UNKNOWN" { return Px::Ok(None, used); }
    if f.len() != 6 { return Px::Bad; }
    let (Ok(sp), Ok(_dp)) = (f[4].parse::<u16>(), f[5].parse::<u16>()) else { return Px::Bad };
    let ip: std::net::IpAddr = match f[1] {
        "TCP4" => match f[2].parse::<std::net::Ipv4Addr>() { Ok(a) if f[3].parse::<std::net::Ipv4Addr>().is_ok() => a.into(), _ => return Px::Bad },
        "TCP6" => match f[2].parse::<std::net::Ipv6Addr>() { Ok(a) if f[3].parse::<std::net::Ipv6Addr>().is_ok() => a.into(), _ => return Px::Bad },
        _ => return Px::Bad,
    };
    Px::Ok(Some(std::net::SocketAddr::new(ip, sp)), used)
}

/// FOUNDER_TLS_PROXY=on -> read the PROXY line from loopback peers. Default off.
pub fn proxy_from_env() -> bool { std::env::var("FOUNDER_TLS_PROXY").map(|v| v.eq_ignore_ascii_case("on")).unwrap_or(false) }

/// Decide the real client address of a fresh connection. Ok(addr) = go on with TLS (header bytes already consumed); Err = drop the connection.
async fn real_client(tcp: &mut TcpStream, peer: std::net::SocketAddr) -> Result<std::net::SocketAddr, ()> {
    let mut first = [0u8; 1];
    let n = tokio::time::timeout(Duration::from_secs(3), tcp.peek(&mut first)).await.map_err(|_| ())?.map_err(|_| ())?;
    if n == 0 { return Err(()); }
    if first[0] != b'P' { return Ok(peer); } // a TLS record starts with 0x16: direct connection, nothing to read
    if !peer.ip().is_loopback() { return Err(()); } // the internet may never send a PROXY line
    let mut buf = [0u8; 107];
    let read = async {
        loop {
            let got = tcp.peek(&mut buf).await.map_err(|_| ())?;
            match parse_proxy_v1(&buf[..got]) {
                Px::Ok(a, used) => { let mut sink = vec![0u8; used]; tokio::io::AsyncReadExt::read_exact(tcp, &mut sink).await.map_err(|_| ())?; return Ok(a.unwrap_or(peer)); }
                Px::Bad => return Err(()),
                Px::Need => { if got == 107 { return Err(()); } tokio::time::sleep(Duration::from_millis(10)).await; }
            }
        }
    };
    tokio::time::timeout(Duration::from_secs(3), read).await.map_err(|_| ())?
}

/// Same as `serve_store`; with `px` on, a loopback peer's PROXY v1 line gives the real client IP, which the app sees as `x-real-ip`.
pub async fn serve_store_px(listener: TcpListener, store: Arc<CertStore>, router: axum::Router, px: bool) {
    loop {
        let Ok((mut tcp, peer)) = listener.accept().await else { continue };
        let (acceptor, router) = (TlsAcceptor::from(store.current()), router.clone());
        tokio::spawn(async move {
            let client = if px { match real_client(&mut tcp, peer).await { Ok(a) => a, Err(()) => return } } else { peer };
            if px && client != peer { static SEEN: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0); let n = SEEN.fetch_add(1, std::sync::atomic::Ordering::Relaxed) + 1; if n <= 5 || n % 1000 == 0 { eprintln!("founder: PROXY v1 accepted from {peer}: real client {client} (connection #{n})"); } } // proof line for the journal; quiet after the first five
            let Ok(Ok(tls)) = tokio::time::timeout(Duration::from_secs(10), acceptor.accept(tcp)).await else { return };
            let ip = client.ip().to_string();
            let router = router.layer(axum::middleware::from_fn(move |mut req: axum::extract::Request, next: axum::middleware::Next| {
                let ip = ip.clone();
                async move { if let Ok(v) = axum::http::HeaderValue::from_str(&ip) { req.headers_mut().insert("x-real-ip", v); } next.run(req).await }
            }));
            let svc = hyper_util::service::TowerToHyperService::new(router);
            let _ = hyper::server::conn::http1::Builder::new().serve_connection(hyper_util::rt::TokioIo::new(tls), svc).await;
        });
    }
}

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// K4.3 (founder, 7 Nov 2026): the certificate is a COPY of Caddy's Let's Encrypt certificate and Let's Encrypt renews it about every 60 days. The copy must be picked up
// WITHOUT a restart, and a bad copy (half written, wrong key, expired, not yet valid) must NEVER replace a good one. Pure functions + a small watcher.
// ---------------------------------------------------------------------------------------------------------------------------------------------------

/// The live server configuration plus the end of its certificate. Swapped atomically; readers take a cheap Arc clone.
pub struct CertStore { cur: std::sync::RwLock<Arc<ServerConfig>>, not_after: std::sync::atomic::AtomicI64 }
impl CertStore {
    pub fn fixed(cfg: Arc<ServerConfig>) -> Self { CertStore { cur: std::sync::RwLock::new(cfg), not_after: std::sync::atomic::AtomicI64::new(0) } }
    pub fn new(cfg: Arc<ServerConfig>, not_after: i64) -> Self { CertStore { cur: std::sync::RwLock::new(cfg), not_after: std::sync::atomic::AtomicI64::new(not_after) } }
    pub fn current(&self) -> Arc<ServerConfig> { self.cur.read().map(|g| g.clone()).unwrap_or_else(|e| e.into_inner().clone()) }
    fn swap(&self, cfg: Arc<ServerConfig>, not_after: i64) { *self.cur.write().unwrap_or_else(|e| e.into_inner()) = cfg; self.not_after.store(not_after, std::sync::atomic::Ordering::Relaxed); }
    /// Unix seconds when the serving certificate ends (0 = unknown).
    pub fn not_after(&self) -> i64 { self.not_after.load(std::sync::atomic::Ordering::Relaxed) }
}

/// One DER element: (tag, content, rest). None on any malformed or truncated input.
fn tlv(b: &[u8]) -> Option<(u8, &[u8], &[u8])> {
    let (&tag, r) = b.split_first()?;
    let (&l0, r) = r.split_first()?;
    let (len, r) = if l0 < 0x80 { (l0 as usize, r) } else {
        let n = (l0 & 0x7f) as usize;
        if n == 0 || n > 4 || r.len() < n { return None; }
        (r[..n].iter().fold(0usize, |a, &x| (a << 8) | x as usize), &r[n..])
    };
    if r.len() < len { return None; }
    Some((tag, &r[..len], &r[len..]))
}

/// Days from 1970-01-01 for a civil date (proleptic Gregorian, Howard Hinnant's algorithm).
fn days_from_civil(y: i64, m: i64, d: i64) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    era * 146097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719468
}

/// ASN.1 UTCTime (YYMMDDHHMMSSZ, tag 0x17) or GeneralizedTime (YYYYMMDDHHMMSSZ, tag 0x18) -> unix seconds.
fn asn1_time(tag: u8, c: &[u8]) -> Option<i64> {
    let t = std::str::from_utf8(c).ok()?;
    let (yr, rest) = match tag { 0x17 if t.len() == 13 => { let yy: i64 = t[..2].parse().ok()?; (if yy >= 50 { 1900 + yy } else { 2000 + yy }, &t[2..]) }, 0x18 if t.len() == 15 => (t[..4].parse().ok()?, &t[4..]), _ => return None };
    if !rest.ends_with('Z') { return None; }
    let n = |i: usize| rest.get(i..i + 2)?.parse::<i64>().ok();
    let (mo, d, h, mi, se) = (n(0)?, n(2)?, n(4)?, n(6)?, n(8)?);
    if !(1..=12).contains(&mo) || !(1..=31).contains(&d) || h > 23 || mi > 59 || se > 60 { return None; }
    Some(days_from_civil(yr, mo, d) * 86400 + h * 3600 + mi * 60 + se)
}

/// (notBefore, notAfter) of a DER certificate as unix seconds. No X.509 library: only the few fixed fields of the TBS part are walked.
pub fn cert_validity(der: &[u8]) -> Option<(i64, i64)> {
    let (_, cert, _) = tlv(der)?;                 // Certificate ::= SEQUENCE
    let (_, tbs, _) = tlv(cert)?;                 // TBSCertificate ::= SEQUENCE
    let mut r = tbs;
    let (t0, _, after) = tlv(r)?;
    if t0 == 0xA0 { r = after; }                  // [0] version (optional)
    for _ in 0..3 { r = tlv(r)?.2; }              // serialNumber, signature, issuer
    let (_, validity, _) = tlv(r)?;               // Validity ::= SEQUENCE { notBefore, notAfter }
    let (t1, nb, rest) = tlv(validity)?;
    let (t2, na, _) = tlv(rest)?;
    Some((asn1_time(t1, nb)?, asn1_time(t2, na)?))
}

/// Parse + prove a certificate/key pair for serving at `now` (unix seconds). Ok = (config, notAfter). Err = a plain reason; nothing is swapped on Err.
pub fn load_checked(cert_pem: &[u8], key_pem: &[u8], now: i64) -> Result<(Arc<ServerConfig>, i64), String> {
    let cfg = server_config(cert_pem, key_pem)?;                                  // also fails when the key does not belong to the certificate
    let leaf = CertificateDer::pem_slice_iter(cert_pem).next().ok_or("no certificate")?.map_err(|e| format!("certificate: {e}"))?;
    let (nb, na) = cert_validity(leaf.as_ref()).ok_or("certificate dates unreadable")?;
    if now < nb { return Err("certificate is not valid yet".into()); }
    if now >= na { return Err("certificate has expired".into()); }
    Ok((cfg, na))
}

fn now_unix() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }

/// Read both files, check them, and swap them in. Err leaves the store exactly as it was.
pub fn reload_once(store: &CertStore, cert_path: &std::path::Path, key_path: &std::path::Path, now: i64) -> Result<i64, String> {
    let c = std::fs::read(cert_path).map_err(|e| format!("{}: {e}", cert_path.display()))?;
    let k = std::fs::read(key_path).map_err(|e| format!("{}: {e}", key_path.display()))?;
    let (cfg, na) = load_checked(&c, &k, now)?;
    store.swap(cfg, na);
    Ok(na)
}

fn stamp(p: &std::path::Path) -> Option<(std::time::SystemTime, u64)> { let m = std::fs::metadata(p).ok()?; Some((m.modified().ok()?, m.len())) }

/// Every 10 minutes: if the certificate or key file changed (time or size), try to load it. A refused change is logged once and the current certificate keeps serving.
pub fn spawn_reloader(store: Arc<CertStore>, cert_path: std::path::PathBuf, key_path: std::path::PathBuf) {
    tokio::spawn(async move {
        let mut seen = (stamp(&cert_path), stamp(&key_path));
        loop {
            tokio::time::sleep(Duration::from_secs(600)).await;
            let now_s = (stamp(&cert_path), stamp(&key_path));
            if now_s == seen { continue; }
            seen = now_s;
            match reload_once(&store, &cert_path, &key_path, now_unix()) {
                Ok(na) => eprintln!("founder: TLS-256 certificate RELOADED, valid for {} more days", (na - now_unix()) / 86400),
                Err(e) => eprintln!("founder: TLS-256 certificate change REFUSED ({e}); the current certificate keeps serving"),
            }
        }
    });
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

/// FOUNDER_TLS256_* env -> (address, store, cert path, key path). None = switched off (the default); Err = switched on but misconfigured (the caller logs it, the main port is unaffected).
/// The first load is checked like every reload: a start with an expired or mismatched certificate is refused with a plain reason.
pub fn from_env() -> Option<Result<(String, Arc<CertStore>, std::path::PathBuf, std::path::PathBuf), String>> {
    let addr = std::env::var("FOUNDER_TLS256_ADDR").ok().filter(|a| !a.trim().is_empty())?;
    let path = |k: &str| std::env::var(k).map(std::path::PathBuf::from).map_err(|_| format!("{k} is not set"));
    Some((|| {
        let (cp, kp) = (path("FOUNDER_TLS256_CERT")?, path("FOUNDER_TLS256_KEY")?);
        let rd = |p: &std::path::Path| std::fs::read(p).map_err(|e| format!("{}: {e}", p.display()));
        let (cfg, na) = load_checked(&rd(&cp)?, &rd(&kp)?, now_unix())?;
        Ok((addr.clone(), Arc::new(CertStore::new(cfg, na)), cp, kp))
    })())
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

    #[test]
    fn k43_dates_are_read_and_a_bad_or_expired_certificate_never_loads() {
        let Some((c, k)) = test_cert() else { return };
        let der = CertificateDer::pem_slice_iter(&c).next().unwrap().unwrap();
        let (nb, na) = cert_validity(der.as_ref()).expect("dates");
        let now = now_unix();
        assert!(nb <= now + 5 && now < na, "fresh 1-day certificate is valid now");
        assert!((na - nb) >= 86_000 && (na - nb) <= 87_000, "one day long");
        assert!(load_checked(&c, &k, now).is_ok());
        assert_eq!(load_checked(&c, &k, na + 1).err().as_deref(), Some("certificate has expired"));
        assert_eq!(load_checked(&c, &k, nb - 10).err().as_deref(), Some("certificate is not valid yet"));
        assert!(load_checked(&c, b"garbage", now).is_err());
        let (_, k2) = test_cert().unwrap();               // a different key for the same certificate = inconsistent pair
        assert!(load_checked(&c, &k2, now).is_err(), "key that does not belong to the certificate");
        assert!(cert_validity(b"\x30\x03\x02\x01").is_none() && cert_validity(&[]).is_none());
    }

    #[test]
    fn k43_asn1_time_forms() {
        assert_eq!(asn1_time(0x17, b"700101000000Z"), Some(0));
        assert_eq!(asn1_time(0x18, b"20000101000000Z"), Some(946_684_800));
        assert_eq!(asn1_time(0x17, b"491231235959Z"), Some(2_524_607_999));   // YY < 50 means 20YY
        assert!(asn1_time(0x17, b"7001010000Z").is_none() && asn1_time(0x18, b"20001301000000Z").is_none());
    }

    #[test]
    fn k43_reload_swaps_a_good_file_and_refuses_a_bad_one_without_touching_the_live_config() {
        let Some((c1, k1)) = test_cert() else { return };
        let d = std::env::temp_dir().join(format!("k43-{}-{:?}", std::process::id(), std::thread::current().id()));
        let _ = std::fs::create_dir_all(&d);
        let (cp, kp) = (d.join("c.pem"), d.join("k.pem"));
        std::fs::write(&cp, &c1).unwrap(); std::fs::write(&kp, &k1).unwrap();
        let now = now_unix();
        let (cfg, na) = load_checked(&c1, &k1, now).unwrap();
        let store = CertStore::new(cfg, na);
        let first = store.current();
        // a half-written file: refused, the live config is the SAME Arc
        std::fs::write(&cp, &c1[..40]).unwrap();
        assert!(reload_once(&store, &cp, &kp, now).is_err());
        assert!(Arc::ptr_eq(&first, &store.current()));
        // a wrong key: refused
        let (_, k2) = test_cert().unwrap();
        std::fs::write(&cp, &c1).unwrap(); std::fs::write(&kp, &k2).unwrap();
        assert!(reload_once(&store, &cp, &kp, now).is_err());
        assert!(Arc::ptr_eq(&first, &store.current()));
        // an expired certificate: refused
        std::fs::write(&kp, &k1).unwrap();
        assert!(reload_once(&store, &cp, &kp, na + 1).is_err());
        assert!(Arc::ptr_eq(&first, &store.current()));
        // a new good pair: swapped, and not_after is updated
        let (c3, k3) = test_cert().unwrap();
        std::fs::write(&cp, &c3).unwrap(); std::fs::write(&kp, &k3).unwrap();
        let na3 = reload_once(&store, &cp, &kp, now).expect("good pair loads");
        assert!(!Arc::ptr_eq(&first, &store.current()));
        assert_eq!(store.not_after(), na3);
    }

    #[tokio::test]
    async fn k43_a_running_server_serves_the_new_certificate_to_new_connections_after_a_reload() {
        let Some((c1, k1)) = test_cert() else { return };
        let (c2, k2) = test_cert().unwrap();
        let (cfg, na) = load_checked(&c1, &k1, now_unix()).unwrap();
        let store = Arc::new(CertStore::new(cfg, na));
        let l = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = l.local_addr().unwrap().port();
        tokio::spawn(serve_store(l, store.clone(), axum::Router::new().route("/healthz", axum::routing::get(|| async { "ok" }))));
        let root1 = CertificateDer::pem_slice_iter(&c1).next().unwrap().unwrap();
        let root2 = CertificateDer::pem_slice_iter(&c2).next().unwrap().unwrap();
        assert!(probe("localhost", port, Offer::Browser, Some(root1.clone())).await.ok, "cert 1 trusted before the swap");
        assert!(!probe("localhost", port, Offer::Browser, Some(root2.clone())).await.ok, "cert 2 is not trusted yet");
        let (cfg2, na2) = load_checked(&c2, &k2, now_unix()).unwrap();
        store.swap(cfg2, na2);
        assert!(probe("localhost", port, Offer::Browser, Some(root2)).await.ok, "new connections now get cert 2, no restart");
        assert!(!probe("localhost", port, Offer::Browser, Some(root1)).await.ok, "cert 1 no longer served");
    }

    #[test]
    fn k45_proxy_v1_parser_is_strict() {
        assert_eq!(parse_proxy_v1(b"PROXY TCP4 1.2.3.4 9.9.9.9 5555 443\r\nXX"), Px::Ok(Some("1.2.3.4:5555".parse().unwrap()), 37));
        assert_eq!(parse_proxy_v1(b"PROXY TCP6 2001:db8::1 ::2 1 443\r\n"), Px::Ok(Some("[2001:db8::1]:1".parse().unwrap()), 34));
        assert_eq!(parse_proxy_v1(b"PROXY UNKNOWN\r\n"), Px::Ok(None, 15));
        // prefixes need more bytes, never a verdict
        for n in 0..37 { assert_eq!(parse_proxy_v1(&b"PROXY TCP4 1.2.3.4 9.9.9.9 5555 443\r\n"[..n]), Px::Need, "{n}"); }
        // everything wrong is Bad
        for bad in [&b"GET / HTTP/1.1\r\n"[..], b"\x16\x03\x01", b"PROXY TCP4 1.2.3.4 9.9.9.9 5555 443\n", b"PROXY TCP4 1.2.3.4 9.9.9.9 99999 443\r\n", b"PROXY TCP4 ::1 ::2 1 443\r\n", b"PROXY TCP6 1.2.3.4 9.9.9.9 1 443\r\n", b"PROXY UDP4 1.2.3.4 9.9.9.9 1 443\r\n", b"PROXY TCP4 1.2.3.4 9.9.9.9 1\r\n", b"\r\n\r\n\0\r\nQUIT\n\x21\x11", b"PROXY TCP4 \xff\xfe 1 2 3\r\n"] { assert_eq!(parse_proxy_v1(bad), Px::Bad, "{:?}", String::from_utf8_lossy(bad)); }
        // a line that never ends is Bad once it is as long as the spec allows
        assert_eq!(parse_proxy_v1(&[b"PROXY TCP4 ".as_slice(), &[b'1'; 200]].concat()), Px::Bad);
    }

    #[tokio::test]
    async fn k45_real_client_rules() {
        use tokio::io::AsyncWriteExt;
        async fn pair() -> (TcpStream, TcpStream) { let l = TcpListener::bind("127.0.0.1:0").await.unwrap(); let a = l.local_addr().unwrap(); let c = TcpStream::connect(a).await.unwrap(); let (s, _) = l.accept().await.unwrap(); (c, s) }
        let lo: std::net::SocketAddr = "127.0.0.1:40000".parse().unwrap();
        let net: std::net::SocketAddr = "203.0.113.9:40000".parse().unwrap();
        // loopback + valid line: the real address, line consumed, TLS bytes left untouched
        let (mut c, mut s) = pair().await; c.write_all(b"PROXY TCP4 198.51.100.7 10.0.0.1 5555 443\r\n\x16\x03\x01").await.unwrap();
        assert_eq!(real_client(&mut s, lo).await, Ok("198.51.100.7:5555".parse().unwrap()));
        let mut rest = [0u8; 3]; tokio::io::AsyncReadExt::read_exact(&mut s, &mut rest).await.unwrap(); assert_eq!(rest, [0x16, 3, 1]);
        // the internet may never send a line
        let (mut c, mut s) = pair().await; c.write_all(b"PROXY TCP4 198.51.100.7 10.0.0.1 5555 443\r\n").await.unwrap();
        assert_eq!(real_client(&mut s, net).await, Err(()));
        // junk after P from loopback is dropped
        let (mut c, mut s) = pair().await; c.write_all(b"PUT / HTTP/1.1\r\n").await.unwrap();
        assert_eq!(real_client(&mut s, lo).await, Err(()));
        // a plain TLS start is a direct connection: peer address, nothing consumed
        let (mut c, mut s) = pair().await; c.write_all(&[0x16, 3, 1]).await.unwrap();
        assert_eq!(real_client(&mut s, net).await, Ok(net));
        let mut rest = [0u8; 3]; tokio::io::AsyncReadExt::read_exact(&mut s, &mut rest).await.unwrap(); assert_eq!(rest, [0x16, 3, 1]);
    }

    #[tokio::test]
    async fn k45_the_app_sees_the_real_client_ip_and_a_forged_header_never_wins() {
        let Some((c, k)) = test_cert() else { eprintln!("openssl missing: skipped"); return };
        let l = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = l.local_addr().unwrap().port();
        let router = axum::Router::new().route("/ip", axum::routing::get(|h: axum::http::HeaderMap| async move { h.get("x-real-ip").and_then(|v| v.to_str().ok()).unwrap_or("-").to_string() }));
        tokio::spawn(serve_store_px(l, Arc::new(CertStore::fixed(server_config(&c, &k).unwrap())), router, true));
        let root = CertificateDer::pem_slice_iter(&c).next().unwrap().unwrap();
        let mut roots = RootCertStore::empty(); roots.add(root).unwrap();
        let conn = TlsConnector::from(Arc::new(ClientConfig::builder_with_provider(provider(vec![AES256])).with_protocol_versions(&[&rustls::version::TLS13]).unwrap().with_root_certificates(roots).with_no_client_auth()));
        let ask = |prefix: &'static [u8]| { let conn = conn.clone(); async move {
            let mut tcp = TcpStream::connect(("127.0.0.1", port)).await.unwrap();
            tcp.write_all(prefix).await.unwrap();
            let mut tls = conn.connect(ServerName::try_from("localhost").unwrap(), tcp).await.unwrap();
            tls.write_all(b"GET /ip HTTP/1.1\r\nHost: localhost\r\nx-real-ip: 6.6.6.6\r\nConnection: close\r\n\r\n").await.unwrap();
            let mut out = String::new(); let _ = tls.read_to_string(&mut out).await; out
        } };
        // fronted: the PROXY line carries the real client, the forged header from the client is overwritten
        let a = ask(b"PROXY TCP4 198.51.100.7 10.0.0.1 5555 443\r\n").await;
        assert!(a.ends_with("198.51.100.7"), "{a}");
        // direct (no line): the peer address, the forged header is overwritten too
        let b = ask(b"").await;
        assert!(b.ends_with("127.0.0.1"), "{b}");
    }
}
