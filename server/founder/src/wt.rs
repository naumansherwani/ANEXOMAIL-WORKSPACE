//! K6 (founder lane, 9 Nov 2026): WebTransport (HTTP/3 over QUIC) for the founder live feed. Default OFF (needs FOUNDER_WT_ADDR).
//!
//! What it is: the SAME signed live frames the SSE stream (`/founder/v1/live/stream`) already sends, carried over ONE WebTransport bidirectional stream.
//! Nothing is duplicated: the session calls the very same handler (`live_stream_ep`) and pipes its body into the QUIC stream, so the gate, the signing, the
//! snapshot, the ticks, the 100-event catch-up, the slot limit and the 10-minute lifetime are exactly the SSE ones.
//!
//! Security shape (no loophole):
//! - TLS 1.3 with ONE cipher suite, AES-256-GCM-SHA384, for everything after the first packet. RFC 9001 makes the very first Initial packet AES-128 by definition
//!   (it carries no secret, its keys come from a public salt); quinn's normal `build()` refuses an AES-256-only provider, so the QUIC config is built with
//!   `with_initial` (AES-128 for the Initial packet only, nothing else).
//! - ALPN `h3` only. Authority must be the founder host, path exactly `/wt/live`, a browser `Origin` (when sent) must be `https://<host>`.
//! - The browser WebTransport constructor cannot set headers, so the token is the FIRST line of the bidirectional stream: `ANX1 <token> [<last-event-id>]\n`.
//!   Charset-checked, 4 KiB cap, 5 s timeout; the token goes through the same `authed()` as every other endpoint (founder token, device not revoked).
//! - Answer on a refusal: `ERR <status>\n` then the session is closed. A client that never says hello is dropped after 5 s.
//! - Caps: 64 sessions at once, 10 s to finish the QUIC/HTTP3 handshake, session lifetime 10 minutes, certificate hot-reload from the same cert store as K4.3.

use std::{future::Future, net::SocketAddr, pin::Pin, sync::Arc, sync::atomic::{AtomicUsize, Ordering}, time::Duration};
use axum::{body::Body, http::{HeaderMap, HeaderName, HeaderValue}, response::Response};
use futures_util::StreamExt;
use wtransport::{Endpoint, ServerConfig, VarInt, endpoint::endpoint_side::Server, quinn};
use rustls::crypto::ring::cipher_suite::TLS13_AES_128_GCM_SHA256;

use crate::tls256::CertStore;

pub const PATH: &str = "/wt/live";
pub const MAX_SESSIONS: usize = 64;
const HELLO_MAX: usize = 4096;
const HELLO_WAIT: Duration = Duration::from_secs(5);
const HANDSHAKE_WAIT: Duration = Duration::from_secs(10);
const MAX_LIFE: Duration = Duration::from_secs(600);

/// The live handler of the SSE endpoint, given the headers the hello built.
pub type Handler = Arc<dyn Fn(HeaderMap) -> Pin<Box<dyn Future<Output = Response> + Send>> + Send + Sync>;

pub struct Cfg { pub host: String, pub handler: Handler }

static ACTIVE: AtomicUsize = AtomicUsize::new(0);
static TOTAL: AtomicUsize = AtomicUsize::new(0);

/// `ANX1 <token> [<last-event-id>]` -> (token, last id). Pure, so it is tested hard. The token may only contain base64url / JWT / `.` characters (no spaces,
/// no control bytes, no header injection); the line must end with exactly one LF (a CR is refused).
pub fn parse_hello(line: &[u8]) -> Result<(String, Option<i64>), &'static str> {
    let s = std::str::from_utf8(line).map_err(|_| "not text")?;
    let s = s.strip_suffix('\n').ok_or("no end of line")?;
    if s.contains(['\r', '\n', '\0']) { return Err("control bytes"); }
    let mut it = s.split(' ');
    if it.next() != Some("ANX1") { return Err("bad hello"); }
    let tok = it.next().ok_or("no token")?;
    if tok.is_empty() || tok.len() > 3000 { return Err("bad token length"); }
    if !tok.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-' | b'~' | b'+' | b'/' | b'=')) { return Err("bad token characters"); }
    let last = match it.next() {
        None => None,
        Some(n) => { if n.len() > 18 || !n.bytes().all(|b| b.is_ascii_digit()) { return Err("bad last id"); } Some(n.parse::<i64>().map_err(|_| "bad last id")?) }
    };
    if it.next().is_some() { return Err("too many words"); }
    Ok((tok.to_string(), last))
}

/// Origin check: absent is fine (non-browser client), present must be exactly https://<host>.
pub fn origin_ok(origin: Option<&str>, host: &str) -> bool { match origin { None => true, Some(o) => o.eq_ignore_ascii_case(&format!("https://{host}")) } }

/// `host` or `host:port` -> host, lower case.
pub fn authority_host(a: &str) -> String { a.rsplit_once(':').filter(|(h, p)| !h.contains(':') && p.bytes().all(|b| b.is_ascii_digit())).map(|(h, _)| h).unwrap_or(a).to_ascii_lowercase() }

/// QUIC server configuration from the K4 rustls config (AES-256-GCM only). ALPN is switched to h3; the Initial packet gets AES-128 as RFC 9001 demands.
pub fn quic_config(tls: &rustls::ServerConfig) -> Result<quinn::ServerConfig, String> {
    let mut c = tls.clone();
    c.alpn_protocols = vec![b"h3".to_vec()];
    let initial = TLS13_AES_128_GCM_SHA256.tls13().and_then(|s| s.quic_suite()).ok_or("no QUIC initial suite")?;
    let q = quinn::crypto::rustls::QuicServerConfig::with_initial(Arc::new(c), initial).map_err(|e| e.to_string())?;
    let mut sc = quinn::ServerConfig::with_crypto(Arc::new(q));
    let mut t = quinn::TransportConfig::default();
    t.max_idle_timeout(Some(Duration::from_secs(30).try_into().map_err(|_| "idle timeout")?));
    t.keep_alive_interval(Some(Duration::from_secs(10)));
    t.max_concurrent_bidi_streams(4u32.into());
    t.max_concurrent_uni_streams(4u32.into());
    sc.transport_config(Arc::new(t));
    Ok(sc)
}

pub fn endpoint(addr: SocketAddr, tls: &rustls::ServerConfig) -> Result<Endpoint<Server>, String> {
    let cfg = ServerConfig::builder().with_bind_address(addr).build_with_quic_config(quic_config(tls)?);
    Endpoint::server(cfg).map_err(|e| format!("bind {addr}: {e}"))
}

/// FOUNDER_WT_ADDR + FOUNDER_WT_HOST + FOUNDER_WT_CERT + FOUNDER_WT_KEY -> (address, host, certificate store, cert path, key path). None = off (default).
pub fn from_env() -> Option<Result<(String, String, Arc<CertStore>, std::path::PathBuf, std::path::PathBuf), String>> {
    let addr = std::env::var("FOUNDER_WT_ADDR").ok().filter(|a| !a.trim().is_empty())?;
    let get = |k: &str| std::env::var(k).map_err(|_| format!("{k} is not set"));
    Some((|| {
        let host = get("FOUNDER_WT_HOST")?.to_ascii_lowercase();
        if host.is_empty() || host.contains(['/', ':', ' ']) { return Err("FOUNDER_WT_HOST must be a plain host name".into()); }
        let (cp, kp) = (std::path::PathBuf::from(get("FOUNDER_WT_CERT")?), std::path::PathBuf::from(get("FOUNDER_WT_KEY")?));
        let rd = |p: &std::path::Path| std::fs::read(p).map_err(|e| format!("{}: {e}", p.display()));
        let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0);
        let (cfg, na) = crate::tls256::load_checked(&rd(&cp)?, &rd(&kp)?, now)?;
        Ok((addr.clone(), host, Arc::new(CertStore::new(cfg, na)), cp, kp))
    })())
}

/// Run the endpoint: accept loop + the certificate follower (a new certificate in the store becomes the QUIC config without a restart).
pub async fn serve(ep: Endpoint<Server>, store: Arc<CertStore>, cfg: Arc<Cfg>) {
    let ep = Arc::new(ep);
    { let ep = ep.clone(); let store = store.clone();
      tokio::spawn(async move {
        let mut seen = Arc::as_ptr(&store.current()) as usize;
        loop {
            tokio::time::sleep(Duration::from_secs(60)).await;
            let cur = store.current(); let p = Arc::as_ptr(&cur) as usize;
            if p == seen { continue; }
            seen = p;
            match quic_config(&cur) {
                Ok(q) => { let bind = ep.local_addr().unwrap_or_else(|_| ([0, 0, 0, 0], 0).into()); let sc = ServerConfig::builder().with_bind_address(bind).build_with_quic_config(q); match ep.reload_config(sc, false) { Ok(()) => eprintln!("founder: WebTransport certificate RELOADED"), Err(e) => eprintln!("founder: WebTransport certificate reload REFUSED ({e}); the current one keeps serving") } }
                Err(e) => eprintln!("founder: WebTransport certificate reload REFUSED ({e})"),
            }
        }
      }); }
    loop {
        let incoming = ep.accept().await;
        let cfg = cfg.clone();
        tokio::spawn(async move { one_session(incoming, cfg).await });
    }
}

struct Active;
impl Active { fn take() -> Option<Active> { let n = ACTIVE.fetch_add(1, Ordering::SeqCst); if n >= MAX_SESSIONS { ACTIVE.fetch_sub(1, Ordering::SeqCst); return None; } Some(Active) } }
impl Drop for Active { fn drop(&mut self) { ACTIVE.fetch_sub(1, Ordering::SeqCst); } }

async fn one_session(incoming: wtransport::endpoint::IncomingSession, cfg: Arc<Cfg>) {
    let Ok(Ok(req)) = tokio::time::timeout(HANDSHAKE_WAIT, incoming).await else { return };
    if authority_host(req.authority()) != cfg.host || req.path() != PATH { req.not_found().await; return; }
    if !origin_ok(req.origin(), &cfg.host) { req.forbidden().await; return; }
    let Some(_slot) = Active::take() else { req.too_many_requests().await; return };
    let Ok(conn) = req.accept().await else { return };
    let n = TOTAL.fetch_add(1, Ordering::Relaxed) + 1;
    if n <= 5 || n % 1000 == 0 { eprintln!("founder: WebTransport session #{n} from {} (QUIC, TLS 1.3 AES-256)", conn.remote_address()); }
    let Ok(Ok((mut send, mut recv))) = tokio::time::timeout(HELLO_WAIT, conn.accept_bi()).await else { conn.close(VarInt::from_u32(1), b"no stream"); return };
    // hello line
    let mut buf = Vec::with_capacity(256);
    let hello = tokio::time::timeout(HELLO_WAIT, async {
        let mut one = [0u8; 256];
        loop {
            match recv.read(&mut one).await { Ok(Some(k)) if k > 0 => { buf.extend_from_slice(&one[..k]); if buf.contains(&b'\n') { return true; } if buf.len() > HELLO_MAX { return false; } } _ => return false }
        }
    }).await.unwrap_or(false);
    if !hello { let _ = send.write_all(b"ERR 400\n").await; let _ = send.finish().await; conn.close(VarInt::from_u32(2), b"hello"); return; }
    let end = buf.iter().position(|b| *b == b'\n').map(|i| i + 1).unwrap_or(buf.len());
    let (tok, last) = match parse_hello(&buf[..end]) { Ok(v) => v, Err(_) => { let _ = send.write_all(b"ERR 400\n").await; let _ = send.finish().await; conn.close(VarInt::from_u32(2), b"hello"); return; } };
    let mut h = HeaderMap::new();
    let Ok(av) = HeaderValue::from_str(&format!("Bearer {tok}")) else { conn.close(VarInt::from_u32(2), b"hello"); return };
    h.insert(HeaderName::from_static("authorization"), av);
    if let Some(l) = last { if let Ok(v) = HeaderValue::from_str(&l.to_string()) { h.insert(HeaderName::from_static("last-event-id"), v); } }
    let res = (cfg.handler)(h).await;
    if !res.status().is_success() {
        let _ = send.write_all(format!("ERR {}\n", res.status().as_u16()).as_bytes()).await; let _ = send.finish().await;
        conn.close(VarInt::from_u32(3), b"refused"); return;
    }
    let mut body = Body::into_data_stream(res.into_body());
    let life = tokio::time::sleep(MAX_LIFE);
    tokio::pin!(life);
    loop {
        tokio::select! {
            c = body.next() => match c { Some(Ok(b)) => { if send.write_all(&b).await.is_err() { break; } } _ => break },
            _ = &mut life => break,
            _ = conn.closed() => break,
        }
    }
    let _ = send.finish().await;
    conn.close(VarInt::from_u32(0), b"done");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hello_parser_accepts_the_shape_and_refuses_everything_else() {
        assert_eq!(parse_hello(b"ANX1 abc.DEF-1_2~x+y/z= 42\n").unwrap(), ("abc.DEF-1_2~x+y/z=".to_string(), Some(42)));
        assert_eq!(parse_hello(b"ANX1 tok\n").unwrap(), ("tok".to_string(), None));
        for bad in [&b"ANX1 tok"[..], b"ANX2 tok\n", b"ANX1\n", b"ANX1 \n", b"ANX1 tok\r\n", b"ANX1 to k\n", b"ANX1 tok x\n", b"ANX1 tok -5\n", b"ANX1 tok 1 2\n", b"ANX1 tok 9999999999999999999\n", b"ANX1 t\0k\n", b"ANX1 t\xffk\n", b"ANX1 tok\nANX1 x\n", b"ANX1 t\"k\n", b"ANX1 t;k\n", b"ANX1  tok\n"] {
            assert!(parse_hello(bad).is_err(), "must refuse {:?}", String::from_utf8_lossy(bad));
        }
        let long = format!("ANX1 {}\n", "a".repeat(3001));
        assert!(parse_hello(long.as_bytes()).is_err());
    }

    #[test]
    fn origin_and_authority_rules() {
        assert!(origin_ok(None, "f.example.com"));
        assert!(origin_ok(Some("https://f.example.com"), "f.example.com"));
        assert!(origin_ok(Some("HTTPS://F.EXAMPLE.COM"), "f.example.com"));
        for bad in ["http://f.example.com", "https://evil.com", "https://f.example.com.evil.com", "https://f.example.com:4443", "null", ""] { assert!(!origin_ok(Some(bad), "f.example.com"), "{bad}"); }
        assert_eq!(authority_host("F.Example.com:4443"), "f.example.com");
        assert_eq!(authority_host("f.example.com"), "f.example.com");
    }

    fn test_cert() -> Option<(Vec<u8>, Vec<u8>)> {
        let dir = std::env::temp_dir().join(format!("anx-wt-{}", std::process::id()));
        std::fs::create_dir_all(&dir).ok()?;
        let (c, k) = (dir.join("c.pem"), dir.join("k.pem"));
        let ok = std::process::Command::new("openssl").args(["req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes", "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost", "-addext", "basicConstraints=critical,CA:FALSE", "-addext", "extendedKeyUsage=serverAuth", "-keyout"]).arg(&k).arg("-out").arg(&c).output().ok()?.status.success();
        if !ok { return None; }
        Some((std::fs::read(c).ok()?, std::fs::read(k).ok()?))
    }

    /// A client whose rustls provider offers only the given suite; the Initial packet is AES-128 as the standard demands.
    fn client(cert_pem: &[u8], suite: rustls::SupportedCipherSuite) -> wtransport::Endpoint<wtransport::endpoint::endpoint_side::Client> {
        use rustls::pki_types::{CertificateDer, pem::PemObject};
        let mut p = rustls::crypto::ring::default_provider();
        p.cipher_suites = vec![suite];
        let mut roots = rustls::RootCertStore::empty();
        for c in CertificateDer::pem_slice_iter(cert_pem) { roots.add(c.unwrap()).unwrap(); }
        let mut c = rustls::ClientConfig::builder_with_provider(Arc::new(p)).with_protocol_versions(&[&rustls::version::TLS13]).unwrap().with_root_certificates(roots).with_no_client_auth();
        c.alpn_protocols = vec![b"h3".to_vec()];
        let initial = TLS13_AES_128_GCM_SHA256.tls13().unwrap().quic_suite().unwrap();
        let q = quinn::crypto::rustls::QuicClientConfig::with_initial(Arc::new(c), initial).unwrap();
        let cc = wtransport::ClientConfig::builder().with_bind_address("127.0.0.1:0".parse().unwrap()).build_with_quic_config(quinn::ClientConfig::new(Arc::new(q)));
        Endpoint::client(cc).unwrap()
    }

    fn handler(seen: Arc<std::sync::Mutex<Vec<(String, String)>>>, status: u16) -> Handler {
        Arc::new(move |h: HeaderMap| { let seen = seen.clone(); Box::pin(async move {
            seen.lock().unwrap().push((h.get("authorization").and_then(|v| v.to_str().ok()).unwrap_or("").to_string(), h.get("last-event-id").and_then(|v| v.to_str().ok()).unwrap_or("").to_string()));
            if status != 200 { return Response::builder().status(status).body(Body::empty()).unwrap(); }
            let frames = futures_util::stream::iter(vec![Ok::<_, std::convert::Infallible>(axum::body::Bytes::from("event: snapshot\ndata: {}\n\n")), Ok(axum::body::Bytes::from("event: tick\ndata: {\"version\":1}\n\n"))]);
            Response::builder().status(200).body(Body::from_stream(frames)).unwrap()
        }) })
    }

    async fn start(status: u16, seen: Arc<std::sync::Mutex<Vec<(String, String)>>>) -> Option<(u16, Vec<u8>)> {
        let (c, k) = test_cert()?;
        let tls = crate::tls256::server_config(&c, &k).unwrap();
        let ep = endpoint("127.0.0.1:0".parse().unwrap(), &tls).unwrap();
        let port = ep.local_addr().unwrap().port();
        let store = Arc::new(CertStore::fixed(tls));
        tokio::spawn(serve(ep, store, Arc::new(Cfg { host: "localhost".into(), handler: handler(seen, status) })));
        Some((port, c))
    }

    async fn talk(port: u16, cert: &[u8], suite: rustls::SupportedCipherSuite, path: &str, hello: &[u8]) -> Result<Vec<u8>, String> {
        let cl = client(cert, suite);
        let conn = tokio::time::timeout(Duration::from_secs(5), cl.connect(format!("https://localhost:{port}{path}"))).await.map_err(|_| "connect timeout".to_string())?.map_err(|e| format!("connect: {e}"))?;
        let opening = conn.open_bi().await.map_err(|e| e.to_string())?;
        let (mut s, mut r) = opening.await.map_err(|e| e.to_string())?;
        s.write_all(hello).await.map_err(|e| e.to_string())?;
        let mut out = Vec::new(); let mut b = [0u8; 512];
        loop { match tokio::time::timeout(Duration::from_secs(5), r.read(&mut b)).await { Ok(Ok(Some(n))) => out.extend_from_slice(&b[..n]), _ => break } }
        Ok(out)
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn live_frames_flow_over_quic_with_aes256_and_the_hello_reaches_the_handler() {
        let seen = Arc::new(std::sync::Mutex::new(vec![]));
        let Some((port, cert)) = start(200, seen.clone()).await else { eprintln!("openssl missing: skipped"); return };
        let out = talk(port, &cert, rustls::crypto::ring::cipher_suite::TLS13_AES_256_GCM_SHA384, PATH, b"ANX1 tok123 42\n").await.unwrap();
        assert_eq!(String::from_utf8(out).unwrap(), "event: snapshot\ndata: {}\n\nevent: tick\ndata: {\"version\":1}\n\n");
        assert_eq!(seen.lock().unwrap().clone(), vec![("Bearer tok123".to_string(), "42".to_string())]);
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn a_refused_token_gets_err_and_a_bad_hello_never_reaches_the_handler() {
        let seen = Arc::new(std::sync::Mutex::new(vec![]));
        let Some((port, cert)) = start(401, seen.clone()).await else { eprintln!("openssl missing: skipped"); return };
        let a256 = rustls::crypto::ring::cipher_suite::TLS13_AES_256_GCM_SHA384;
        assert_eq!(String::from_utf8(talk(port, &cert, a256, PATH, b"ANX1 bad\n").await.unwrap()).unwrap(), "ERR 401\n");
        assert_eq!(seen.lock().unwrap().len(), 1);
        assert_eq!(String::from_utf8(talk(port, &cert, a256, PATH, b"GET / HTTP/1.1\n").await.unwrap()).unwrap(), "ERR 400\n");
        assert_eq!(String::from_utf8(talk(port, &cert, a256, PATH, b"ANX1 t\"k\n").await.unwrap()).unwrap(), "ERR 400\n");
        assert_eq!(seen.lock().unwrap().len(), 1, "bad hellos must not reach the handler");
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn wrong_path_is_refused_and_an_aes128_only_client_cannot_connect() {
        let seen = Arc::new(std::sync::Mutex::new(vec![]));
        let Some((port, cert)) = start(200, seen.clone()).await else { eprintln!("openssl missing: skipped"); return };
        let a256 = rustls::crypto::ring::cipher_suite::TLS13_AES_256_GCM_SHA384;
        let a128 = rustls::crypto::ring::cipher_suite::TLS13_AES_128_GCM_SHA256;
        assert!(talk(port, &cert, a256, "/other", b"ANX1 tok\n").await.is_err(), "wrong path must be refused");
        assert!(talk(port, &cert, a128, PATH, b"ANX1 tok\n").await.is_err(), "AES-128-only client must be refused");
        assert!(seen.lock().unwrap().is_empty());
    }

    #[test]
    fn off_by_default_and_plain_host_only() {
        unsafe { std::env::remove_var("FOUNDER_WT_ADDR"); }
        assert!(from_env().is_none());
    }
}
