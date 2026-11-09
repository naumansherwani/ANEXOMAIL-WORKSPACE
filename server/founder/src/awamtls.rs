//! K5a (9 Nov 2026, founder order: "AES-256 + no compromise, the technology is for the WHOLE awam website").
//! Technology: Rust (rustls + tokio-rustls, ring), inside the founder binary, beside the K4 front. Go/Caddy cannot be told to speak AES-256 only (golang/go#29349),
//! so the awam hosts go through this terminator: TLS 1.3 with ONE cipher suite (AES-256-GCM-SHA384), the certificate chosen by SNI from a directory of Caddy's own
//! Let's Encrypt copies (hot reload, a bad file never replaces a good one), ALPN h2 + http/1.1, and then a RE-ORIGINATION TUNNEL: an inner TLS connection to Caddy
//! (127.0.0.1:18443) with the SAME SNI and the SAME ALPN, a PROXY v1 line first (real client IP), and bytes copied both ways. Nothing is parsed, so h2, WebSockets,
//! SSE and streaming pass unchanged. Default OFF. Behind the K4 front: FOUNDER_FRONT_OTHER points here, the front sends the PROXY line.
use std::collections::HashMap;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};
use std::time::Duration;

use rustls::pki_types::{pem::PemObject, CertificateDer, PrivateKeyDer, ServerName};
use rustls::server::{ClientHello, ResolvesServerCert};
use rustls::sign::CertifiedKey;
use rustls::{ClientConfig, RootCertStore, ServerConfig};
use tokio::io::AsyncWriteExt;
use tokio::net::{TcpListener, TcpStream};
use tokio_rustls::{TlsAcceptor, TlsConnector};

use crate::tls256::{cert_validity, provider, real_client, AES256};

fn now_unix() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }

/// Every certificate of the directory, by lower-case host name, with the unix second it ends. Swapped under a lock; readers only clone an Arc.
#[derive(Default)]
pub struct HostCerts { map: RwLock<HashMap<String, (Arc<CertifiedKey>, i64)>> }
impl std::fmt::Debug for HostCerts { fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result { write!(f, "HostCerts({} hosts)", self.len()) } }

/// One host: certificate chain + key, checked like every K4.3 reload (the key must belong to the certificate, the dates must be valid now).
pub fn load_host(cert_pem: &[u8], key_pem: &[u8], now: i64) -> Result<(CertifiedKey, i64), String> {
    let certs: Vec<CertificateDer<'static>> = CertificateDer::pem_slice_iter(cert_pem).collect::<Result<_, _>>().map_err(|e| format!("certificate: {e}"))?;
    if certs.is_empty() { return Err("certificate file has no certificate".into()); }
    let key = PrivateKeyDer::from_pem_slice(key_pem).map_err(|e| format!("private key: {e}"))?;
    let signing = rustls::crypto::ring::sign::any_supported_type(&key).map_err(|e| format!("private key: {e}"))?;
    let (nb, na) = cert_validity(certs[0].as_ref()).ok_or("certificate dates unreadable")?;
    if now < nb { return Err("certificate is not valid yet".into()); }
    if now >= na { return Err("certificate has expired".into()); }
    let ck = CertifiedKey::new(certs, signing);
    ck.keys_match().map_err(|e| format!("the key does not belong to the certificate: {e}"))?;
    Ok((ck, na))
}

fn host_ok(h: &str) -> bool { !h.is_empty() && h.len() <= 253 && h.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'.' || b == b'-') && !h.starts_with('.') && !h.starts_with('-') }

impl HostCerts {
    pub fn len(&self) -> usize { self.map.read().map(|m| m.len()).unwrap_or(0) }
    pub fn has(&self, host: &str) -> bool { self.map.read().map(|m| m.contains_key(host)).unwrap_or(false) }
    /// The earliest end among all certificates (unix seconds, 0 = none).
    pub fn soonest_end(&self) -> i64 { self.map.read().map(|m| m.values().map(|v| v.1).min().unwrap_or(0)).unwrap_or(0) }
    /// Read `<dir>/<host>.crt` + `<host>.key` for every host in the directory. A host whose files are bad keeps its OLD certificate (and is listed in the Err part of the
    /// result); a host that is new and bad is simply absent. Returns (hosts now served, refusals).
    pub fn reload(&self, dir: &Path, now: i64) -> Result<(usize, Vec<String>), String> {
        let rd = std::fs::read_dir(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
        let mut fresh: HashMap<String, (Arc<CertifiedKey>, i64)> = HashMap::new();
        let mut refused = Vec::new();
        for e in rd.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("crt") { continue; }
            let Some(host) = p.file_stem().and_then(|x| x.to_str()).map(|h| h.to_ascii_lowercase()) else { continue };
            if !host_ok(&host) { refused.push(format!("{host}: not a plain host name")); continue; }
            let key_path = p.with_extension("key");
            let one = (|| { let c = std::fs::read(&p).map_err(|e| e.to_string())?; let k = std::fs::read(&key_path).map_err(|e| e.to_string())?; load_host(&c, &k, now) })();
            match one { Ok((ck, na)) => { fresh.insert(host, (Arc::new(ck), na)); } Err(why) => refused.push(format!("{host}: {why}")) }
        }
        let mut cur = self.map.write().unwrap_or_else(|e| e.into_inner());
        let mut next = cur.clone();
        for (h, v) in fresh { next.insert(h, v); }
        if next.is_empty() { return Err(format!("no usable certificate in {}", dir.display())); }
        let n = next.len();
        *cur = next;
        Ok((n, refused))
    }
}

impl ResolvesServerCert for HostCerts {
    fn resolve(&self, ch: ClientHello<'_>) -> Option<Arc<CertifiedKey>> {
        let name = ch.server_name()?.to_ascii_lowercase();
        let m = self.map.read().ok()?;
        let (ck, na) = m.get(&name)?;
        if now_unix() >= *na { return None; } // an ended certificate is never offered
        Some(ck.clone())
    }
}

/// Server side: TLS 1.3 only, ONE cipher suite (AES-256-GCM-SHA384), ALPN h2 then http/1.1, the certificate picked by SNI.
pub fn server_config(certs: Arc<HostCerts>) -> Result<Arc<ServerConfig>, String> {
    let mut c = ServerConfig::builder_with_provider(provider(vec![AES256]))
        .with_protocol_versions(&[&rustls::version::TLS13]).map_err(|e| e.to_string())?
        .with_no_client_auth()
        .with_cert_resolver(certs);
    c.alpn_protocols = vec![b"h2".to_vec(), b"http/1.1".to_vec()];
    Ok(Arc::new(c))
}

pub struct TunnelCfg { pub upstream: SocketAddr, pub px_in: bool, pub max_conn: usize, inner_h2: Arc<ClientConfig>, inner_h1: Arc<ClientConfig>, inner_none: Arc<ClientConfig> }
impl TunnelCfg {
    /// `upstream_root`: an extra trusted root for the inner leg (tests). In production Caddy's Let's Encrypt certificate verifies against the public roots.
    pub fn new(upstream: SocketAddr, px_in: bool, max_conn: usize, upstream_root: Option<CertificateDer<'static>>) -> Result<Self, String> {
        let mk = |alpn: Vec<Vec<u8>>| -> Result<Arc<ClientConfig>, String> {
            let mut roots = RootCertStore::empty();
            roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
            if let Some(r) = &upstream_root { let _ = roots.add(r.clone()); }
            let mut c = ClientConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
                .with_protocol_versions(&[&rustls::version::TLS13]).map_err(|e| e.to_string())?
                .with_root_certificates(roots).with_no_client_auth();
            c.alpn_protocols = alpn;
            Ok(Arc::new(c))
        };
        Ok(TunnelCfg { upstream, px_in, max_conn: max_conn.max(1), inner_h2: mk(vec![b"h2".to_vec()])?, inner_h1: mk(vec![b"http/1.1".to_vec()])?, inner_none: mk(vec![])? })
    }
    fn inner_for(&self, alpn: Option<&[u8]>) -> &Arc<ClientConfig> { match alpn { Some(b"h2") => &self.inner_h2, Some(b"http/1.1") => &self.inner_h1, _ => &self.inner_none } }
}

/// Accept loop. At most `max_conn` tunnels at once (more are dropped at once, never queued); every step has a timeout except the byte copy itself (WebSockets live long).
pub async fn serve_tunnel(listener: TcpListener, cfg: Arc<ServerConfig>, t: Arc<TunnelCfg>) {
    let sem = Arc::new(tokio::sync::Semaphore::new(t.max_conn));
    loop {
        let Ok((tcp, peer)) = listener.accept().await else { continue };
        let Ok(permit) = sem.clone().try_acquire_owned() else { drop(tcp); continue };
        let (acceptor, t) = (TlsAcceptor::from(cfg.clone()), t.clone());
        tokio::spawn(async move { let _p = permit; let _ = tunnel_one(tcp, peer, acceptor, t).await; });
    }
}

async fn tunnel_one(mut tcp: TcpStream, peer: SocketAddr, acceptor: TlsAcceptor, t: Arc<TunnelCfg>) -> Result<(), ()> {
    let client = if t.px_in { real_client(&mut tcp, peer).await? } else { peer };
    let mut inbound = tokio::time::timeout(Duration::from_secs(10), acceptor.accept(tcp)).await.map_err(|_| ())?.map_err(|_| ())?;
    let (alpn, sni) = { let c = inbound.get_ref().1; (c.alpn_protocol().map(|a| a.to_vec()), c.server_name().map(|s| s.to_string())) };
    let sni = sni.ok_or(())?;
    let name = ServerName::try_from(sni.clone()).map_err(|_| ())?;
    let mut up = tokio::time::timeout(Duration::from_secs(5), TcpStream::connect(t.upstream)).await.map_err(|_| ())?.map_err(|_| ())?;
    let _ = up.set_nodelay(true);
    let line = crate::front::proxy_v1(client, up.peer_addr().map_err(|_| ())?);
    up.write_all(line.as_bytes()).await.map_err(|_| ())?;
    let mut outbound = tokio::time::timeout(Duration::from_secs(10), TlsConnector::from(t.inner_for(alpn.as_deref()).clone()).connect(name, up)).await.map_err(|_| ())?.map_err(|_| ())?;
    if outbound.get_ref().1.alpn_protocol() != alpn.as_deref() { return Err(()); } // both legs must speak the same protocol, else the bytes would not match
    static SEEN: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let n = SEEN.fetch_add(1, std::sync::atomic::Ordering::Relaxed) + 1;
    if n <= 5 || n % 1000 == 0 {
        let cipher = inbound.get_ref().1.negotiated_cipher_suite().map(|s| format!("{:?}", s.suite())).unwrap_or_default();
        eprintln!("founder: awam tunnel #{n}: {sni} client {client} {cipher} alpn {}", alpn.as_deref().map(|a| String::from_utf8_lossy(a).into_owned()).unwrap_or_else(|| "none".into()));
    }
    tokio::io::copy_bidirectional(&mut inbound, &mut outbound).await.map(|_| ()).map_err(|_| ())
}

/// Every 10 minutes: re-read the directory. A refusal is logged once per distinct message; the old certificate of that host keeps serving.
pub fn spawn_reloader(certs: Arc<HostCerts>, dir: PathBuf) {
    tokio::spawn(async move {
        let mut last = String::new();
        loop {
            tokio::time::sleep(Duration::from_secs(600)).await;
            match certs.reload(&dir, now_unix()) {
                Ok((n, bad)) => { let msg = format!("{n}|{}", bad.join(";")); if msg != last { if bad.is_empty() { eprintln!("founder: awam TLS-256 certificates reloaded: {n} hosts, first end in {} days", (certs.soonest_end() - now_unix()) / 86400); } else { eprintln!("founder: awam TLS-256 certificates reloaded: {n} hosts; REFUSED (old copy keeps serving): {}", bad.join("; ")); } last = msg; } }
                Err(e) => { if e != last { eprintln!("founder: awam TLS-256 reload FAILED ({e}); the old certificates keep serving"); last = e; } }
            }
        }
    });
}

pub struct Setup { pub addr: String, pub certs: Arc<HostCerts>, pub cfg: Arc<ServerConfig>, pub tunnel: Arc<TunnelCfg>, pub dir: PathBuf }
/// FOUNDER_AWAM_TLS_ADDR (listen, e.g. 127.0.0.1:18081) + FOUNDER_AWAM_TLS_DIR (<host>.crt/.key copies) [+ FOUNDER_AWAM_TLS_UPSTREAM default 127.0.0.1:18443,
/// FOUNDER_AWAM_TLS_PROXY=on to read the front's PROXY line, FOUNDER_AWAM_TLS_MAX default 20000]. None = off (the default); Err = on but misconfigured (the caller logs it).
pub fn from_env() -> Option<Result<Setup, String>> {
    let addr = std::env::var("FOUNDER_AWAM_TLS_ADDR").ok().filter(|a| !a.trim().is_empty())?;
    Some((|| {
        let dir = PathBuf::from(std::env::var("FOUNDER_AWAM_TLS_DIR").map_err(|_| "FOUNDER_AWAM_TLS_DIR is not set".to_string())?);
        let upstream: SocketAddr = std::env::var("FOUNDER_AWAM_TLS_UPSTREAM").unwrap_or_else(|_| "127.0.0.1:18443".into()).parse().map_err(|_| "FOUNDER_AWAM_TLS_UPSTREAM must be ip:port".to_string())?;
        if !upstream.ip().is_loopback() { return Err("FOUNDER_AWAM_TLS_UPSTREAM must be a loopback address".into()); }
        let px = std::env::var("FOUNDER_AWAM_TLS_PROXY").map(|v| v.eq_ignore_ascii_case("on")).unwrap_or(false);
        let max = std::env::var("FOUNDER_AWAM_TLS_MAX").ok().and_then(|v| v.parse().ok()).unwrap_or(20000usize);
        let certs = Arc::new(HostCerts::default());
        let (n, bad) = certs.reload(&dir, now_unix())?;
        if !bad.is_empty() { eprintln!("founder: awam TLS-256: {n} hosts loaded, REFUSED at start: {}", bad.join("; ")); }
        let cfg = server_config(certs.clone())?;
        Ok(Setup { addr: addr.clone(), certs, cfg, tunnel: Arc::new(TunnelCfg::new(upstream, px, max, None)?), dir })
    })())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    /// Throw-away self-signed certificates (openssl CLI; the tests skip when it is missing) written as <dir>/<host>.crt + .key.
    fn mkcert(dir: &Path, host: &str, days: &str) -> bool {
        let (k, c) = (dir.join(format!("{host}.key")), dir.join(format!("{host}.crt")));
        std::process::Command::new("openssl").args(["req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes", "-days", days, "-subj", &format!("/CN={host}"),
            "-addext", &format!("subjectAltName=DNS:{host}"), "-addext", "basicConstraints=critical,CA:FALSE", "-keyout", k.to_str().unwrap(), "-out", c.to_str().unwrap()])
            .output().map(|o| o.status.success()).unwrap_or(false)
    }
    fn tmp(tag: &str) -> PathBuf { let d = std::env::temp_dir().join(format!("awam-{tag}-{}-{:?}", std::process::id(), std::thread::current().id())); let _ = std::fs::remove_dir_all(&d); std::fs::create_dir_all(&d).unwrap(); d }
    fn der(dir: &Path, host: &str) -> CertificateDer<'static> { CertificateDer::pem_slice_iter(&std::fs::read(dir.join(format!("{host}.crt"))).unwrap()).next().unwrap().unwrap() }

    /// A fake "Caddy": reads the PROXY line, then speaks TLS (h2 + http/1.1) and for every connection answers `pong:<what it read>`; reports (proxy line, alpn) on a channel.
    async fn fake_caddy(dir: &Path) -> (SocketAddr, tokio::sync::mpsc::UnboundedReceiver<(String, Option<Vec<u8>>)>) {
        let l = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = l.local_addr().unwrap();
        let certs = Arc::new(HostCerts::default()); certs.reload(dir, now_unix()).unwrap();
        let mut sc = ServerConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider())).with_protocol_versions(&[&rustls::version::TLS13]).unwrap().with_no_client_auth().with_cert_resolver(certs);
        sc.alpn_protocols = vec![b"h2".to_vec(), b"http/1.1".to_vec()];
        let acc = TlsAcceptor::from(Arc::new(sc));
        let (tx, rx) = tokio::sync::mpsc::unbounded_channel();
        tokio::spawn(async move { loop {
            let Ok((mut s, _)) = l.accept().await else { continue };
            let (acc, tx) = (acc.clone(), tx.clone());
            tokio::spawn(async move {
                let mut line = Vec::new(); let mut b = [0u8; 1];
                while !line.ends_with(b"\r\n") { if s.read_exact(&mut b).await.is_err() { return; } line.push(b[0]); if line.len() > 107 { return; } }
                let Ok(mut t) = acc.accept(s).await else { return };
                let alpn = t.get_ref().1.alpn_protocol().map(|a| a.to_vec());
                let _ = tx.send((String::from_utf8_lossy(&line).into_owned(), alpn));
                let mut buf = [0u8; 64]; let n = t.read(&mut buf).await.unwrap_or(0);
                let _ = t.write_all(format!("pong:{}", String::from_utf8_lossy(&buf[..n])).as_bytes()).await; let _ = t.shutdown().await;
            });
        } });
        (addr, rx)
    }

    fn client(offer: Vec<rustls::SupportedCipherSuite>, alpn: &[&[u8]], root: CertificateDer<'static>) -> TlsConnector {
        let mut roots = RootCertStore::empty(); roots.add(root).unwrap();
        let mut c = ClientConfig::builder_with_provider(provider(offer)).with_protocol_versions(&[&rustls::version::TLS13]).unwrap().with_root_certificates(roots).with_no_client_auth();
        c.alpn_protocols = alpn.iter().map(|a| a.to_vec()).collect();
        TlsConnector::from(Arc::new(c))
    }

    async fn tunnel(dir: &Path, upstream: SocketAddr, px_in: bool) -> SocketAddr {
        let certs = Arc::new(HostCerts::default()); certs.reload(dir, now_unix()).unwrap();
        let l = TcpListener::bind("127.0.0.1:0").await.unwrap(); let addr = l.local_addr().unwrap();
        tokio::spawn(serve_tunnel(l, server_config(certs).unwrap(), Arc::new(TunnelCfg::new(upstream, px_in, 100, Some(der(dir, "a.test"))).unwrap())));
        addr
    }

    #[tokio::test]
    async fn the_tunnel_is_aes256_only_keeps_h2_and_http11_and_passes_the_real_ip() {
        let d = tmp("tun");
        if !mkcert(&d, "a.test", "2") || !mkcert(&d, "b.test", "2") { eprintln!("openssl missing: skipped"); return; }
        let (up, mut seen) = fake_caddy(&d).await;
        let t = tunnel(&d, up, false).await;
        let (a256, a128) = (vec![AES256], vec![rustls::crypto::ring::cipher_suite::TLS13_AES_128_GCM_SHA256]);
        // h2 offered first: the client lands on h2, AES-256, and bytes go both ways
        let tcp = TcpStream::connect(t).await.unwrap();
        let mut c = client(a256.clone(), &[b"h2", b"http/1.1"], der(&d, "a.test")).connect(ServerName::try_from("a.test").unwrap(), tcp).await.unwrap();
        assert_eq!(c.get_ref().1.alpn_protocol(), Some(&b"h2"[..]));
        assert_eq!(format!("{:?}", c.get_ref().1.negotiated_cipher_suite().unwrap().suite()), "TLS13_AES_256_GCM_SHA384");
        c.write_all(b"ping").await.unwrap();
        let mut out = String::new(); let _ = c.read_to_string(&mut out).await;
        assert_eq!(out, "pong:ping");
        let (line, alpn) = seen.recv().await.unwrap();
        assert!(line.starts_with("PROXY TCP4 127.0.0.1 127.0.0.1 "), "{line}");
        assert_eq!(alpn.as_deref(), Some(&b"h2"[..]));
        // http/1.1 only: both legs stay on http/1.1
        let tcp = TcpStream::connect(t).await.unwrap();
        let mut c = client(a256.clone(), &[b"http/1.1"], der(&d, "a.test")).connect(ServerName::try_from("a.test").unwrap(), tcp).await.unwrap();
        c.write_all(b"GET").await.unwrap(); let mut out = String::new(); let _ = c.read_to_string(&mut out).await; assert_eq!(out, "pong:GET");
        assert_eq!(seen.recv().await.unwrap().1.as_deref(), Some(&b"http/1.1"[..]));
        // a client that can ONLY do AES-128 is refused
        let tcp = TcpStream::connect(t).await.unwrap();
        assert!(client(a128, &[b"h2"], der(&d, "a.test")).connect(ServerName::try_from("a.test").unwrap(), tcp).await.is_err(), "AES-128-only was accepted");
        // an unknown name has no certificate: refused
        let tcp = TcpStream::connect(t).await.unwrap();
        assert!(client(a256.clone(), &[b"h2"], der(&d, "a.test")).connect(ServerName::try_from("evil.test").unwrap(), tcp).await.is_err(), "an unknown host got a certificate");
        // the certificate is picked by SNI: b.test gets b.test's own certificate
        let tcp = TcpStream::connect(t).await.unwrap();
        let c = client(a256, &[b"h2"], der(&d, "b.test")).connect(ServerName::try_from("b.test").unwrap(), tcp).await.unwrap();
        assert_eq!(c.get_ref().1.peer_certificates().unwrap()[0].as_ref(), der(&d, "b.test").as_ref());
    }

    #[tokio::test]
    async fn the_front_proxy_line_gives_the_real_client_ip_and_a_garbage_line_is_dropped() {
        let d = tmp("px");
        if !mkcert(&d, "a.test", "2") { eprintln!("openssl missing: skipped"); return; }
        let (up, mut seen) = fake_caddy(&d).await;
        let t = tunnel(&d, up, true).await;
        let mut tcp = TcpStream::connect(t).await.unwrap();
        tcp.write_all(b"PROXY TCP4 203.0.113.9 62.238.98.98 4000 443\r\n").await.unwrap();
        let mut c = client(vec![AES256], &[b"h2"], der(&d, "a.test")).connect(ServerName::try_from("a.test").unwrap(), tcp).await.unwrap();
        c.write_all(b"x").await.unwrap(); let mut out = String::new(); let _ = c.read_to_string(&mut out).await; assert_eq!(out, "pong:x");
        let (line, _) = seen.recv().await.unwrap();
        assert!(line.starts_with("PROXY TCP4 203.0.113.9 127.0.0.1 4000 "), "the real client must reach Caddy: {line}");
        let mut bad = TcpStream::connect(t).await.unwrap();
        bad.write_all(b"PROXY junk\n").await.unwrap();
        let mut buf = [0u8; 8]; let n = tokio::time::timeout(Duration::from_secs(5), bad.read(&mut buf)).await.unwrap_or(Ok(1)).unwrap_or(0);
        assert_eq!(n, 0, "a malformed PROXY line must close the connection");
    }

    #[test]
    fn a_bad_new_file_never_replaces_a_good_certificate_and_a_wrong_key_is_refused() {
        let d = tmp("rl");
        if !mkcert(&d, "a.test", "2") || !mkcert(&d, "b.test", "2") { eprintln!("openssl missing: skipped"); return; }
        let hc = HostCerts::default();
        let (n, bad) = hc.reload(&d, now_unix()).unwrap();
        assert_eq!((n, bad.len()), (2, 0));
        assert!(hc.has("a.test") && hc.has("b.test") && !hc.has("evil.test"));
        // half-written certificate file: refused, the old copy keeps serving
        std::fs::write(d.join("a.test.crt"), b"-----BEGIN CERTIFICATE-----\nAAAA").unwrap();
        let (n, bad) = hc.reload(&d, now_unix()).unwrap();
        assert_eq!(n, 2); assert_eq!(bad.len(), 1); assert!(bad[0].starts_with("a.test:"), "{bad:?}"); assert!(hc.has("a.test"));
        // b's certificate with a's key: the key does not belong to the certificate
        let k = std::fs::read(d.join("a.test.key")).unwrap(); std::fs::write(d.join("b.test.key"), k).unwrap();
        let (_, bad) = hc.reload(&d, now_unix()).unwrap(); assert!(bad.iter().any(|b| b.starts_with("b.test:")), "{bad:?}");
        // a certificate that has ended is refused at load time, and a host name with odd characters never loads
        let c = std::fs::read(d.join("b.test.crt")).unwrap(); let k2 = std::fs::read(d.join("a.test.key")).unwrap();
        assert!(load_host(&c, &k2, now_unix() + 40 * 86400).is_err());
        std::fs::write(d.join("Bad Host!.crt"), b"x").unwrap();
        let (_, bad) = hc.reload(&d, now_unix()).unwrap(); assert!(bad.iter().any(|b| b.contains("not a plain host name")), "{bad:?}");
        // an empty directory is an error, never an empty server
        assert!(HostCerts::default().reload(&tmp("empty"), now_unix()).is_err());
    }

    #[test]
    fn the_default_is_off_and_the_upstream_must_be_loopback() {
        unsafe { std::env::remove_var("FOUNDER_AWAM_TLS_ADDR"); }
        assert!(from_env().is_none());
        unsafe { std::env::set_var("FOUNDER_AWAM_TLS_ADDR", "127.0.0.1:0"); std::env::set_var("FOUNDER_AWAM_TLS_DIR", "/nonexistent-awam-dir"); std::env::set_var("FOUNDER_AWAM_TLS_UPSTREAM", "8.8.8.8:443"); }
        assert!(matches!(from_env(), Some(Err(e)) if e.contains("loopback")));
        unsafe { std::env::remove_var("FOUNDER_AWAM_TLS_ADDR"); std::env::remove_var("FOUNDER_AWAM_TLS_DIR"); std::env::remove_var("FOUNDER_AWAM_TLS_UPSTREAM"); }
    }
}
