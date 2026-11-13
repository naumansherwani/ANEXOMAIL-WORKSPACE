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
/// K8d: the founder API over WebTransport (see wtrpc.rs). Only served when the router is given.
pub const RPC_PATH: &str = "/wt/rpc";
pub const MAX_SESSIONS: usize = 64;
const HELLO_MAX: usize = 4096;
pub const HELLO_WAIT: Duration = Duration::from_secs(5);
const HANDSHAKE_WAIT: Duration = Duration::from_secs(10);
const MAX_LIFE: Duration = Duration::from_secs(600);

/// The live handler of the SSE endpoint, given the headers the hello built.
pub type Handler = Arc<dyn Fn(HeaderMap) -> Pin<Box<dyn Future<Output = Response> + Send>> + Send + Sync>;

pub struct Cfg { pub host: String, pub handler: Handler, pub rpc: Option<axum::Router> }

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
pub fn quic_config(tls: &rustls::ServerConfig) -> Result<quinn::ServerConfig, String> { quic_config_n(tls, 64, 4) } // K8d: up to 64 concurrent calls (bidi streams) per session

/// Same, with the number of concurrent request (bidi) and unidirectional streams (the HTTP/3 API needs many, WebTransport live few).
pub fn quic_config_n(tls: &rustls::ServerConfig, bidi: u32, uni: u32) -> Result<quinn::ServerConfig, String> {
    let mut c = tls.clone();
    c.alpn_protocols = vec![b"h3".to_vec()];
    let initial = TLS13_AES_128_GCM_SHA256.tls13().and_then(|s| s.quic_suite()).ok_or("no QUIC initial suite")?;
    let q = quinn::crypto::rustls::QuicServerConfig::with_initial(Arc::new(c), initial).map_err(|e| e.to_string())?;
    let mut sc = quinn::ServerConfig::with_crypto(Arc::new(q));
    let mut t = quinn::TransportConfig::default();
    t.max_idle_timeout(Some(Duration::from_secs(30).try_into().map_err(|_| "idle timeout")?));
    t.keep_alive_interval(Some(Duration::from_secs(10)));
    t.max_concurrent_bidi_streams(bidi.into());
    t.max_concurrent_uni_streams(uni.into());
    sc.transport_config(Arc::new(t));
    sc.migration(true); // KP3: QUIC connection migration stays ON explicitly (Wi-Fi -> mobile data keeps the session: same connection ids, new address); quinn's default is true, this line stops it being lost silently
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

pub struct Active;
impl Active { pub fn take() -> Option<Active> { let n = ACTIVE.fetch_add(1, Ordering::SeqCst); if n >= MAX_SESSIONS { ACTIVE.fetch_sub(1, Ordering::SeqCst); return None; } Some(Active) } }
impl Drop for Active { fn drop(&mut self) { ACTIVE.fetch_sub(1, Ordering::SeqCst); } }

async fn one_session(incoming: wtransport::endpoint::IncomingSession, cfg: Arc<Cfg>) {
    let Ok(Ok(req)) = tokio::time::timeout(HANDSHAKE_WAIT, incoming).await else { return };
    let rpc = req.path() == RPC_PATH && cfg.rpc.is_some();
    if authority_host(req.authority()) != cfg.host || (req.path() != PATH && !rpc) { req.not_found().await; return; }
    if !origin_ok(req.origin(), &cfg.host) { req.forbidden().await; return; }
    let Some(_slot) = Active::take() else { req.too_many_requests().await; return };
    let (ua, hint) = (req.user_agent().map(String::from), req.headers().get("sec-ch-ua").cloned());
    let Ok(conn) = req.accept().await else { return };
    let peer = conn.remote_address();
    if rpc { if let Some(router) = cfg.rpc.clone() { let c = conn.clone(); crate::wtrpc::run_with(|| { let c = c.clone(); async move { c.accept_bi().await.ok() } }, peer.ip(), router, Arc::new(cfg.host.clone()), ua, hint).await; } conn.close(VarInt::from_u32(0), b"done"); return; }
    count_session(peer);
    let Ok(Ok((mut send, mut recv))) = tokio::time::timeout(HELLO_WAIT, conn.accept_bi()).await else { conn.close(VarInt::from_u32(1), b"no stream"); return };
    let code = live_session(&mut send, &mut recv, &cfg, conn.closed()).await;
    // graceful end (tokio shutdown only finishes the stream): give the peer a moment to read the last frames and close, then close ourselves
    let _ = tokio::time::timeout(Duration::from_secs(5), conn.closed()).await;
    conn.close(VarInt::from_u32(code), b"done");
}

/// One /wt/live session on one bidirectional stream, the SAME code for every transport (wtransport on its own UDP port, h3-webtransport on UDP 443): hello line -> token check
/// through the live handler -> frames until the stream ends, the 10-minute life is over or the peer closes. Returns the QUIC application close code (0 done, 2 bad hello, 3 refused).
/// Count + log a new live session (first five, then every thousandth).
pub fn count_session(peer: SocketAddr) { let n = TOTAL.fetch_add(1, Ordering::Relaxed) + 1; if n <= 5 || n % 1000 == 0 { eprintln!("founder: WebTransport session #{n} from {peer} (QUIC UDP 443, TLS 1.3 AES-256)"); } }

pub async fn live_session<W, R, C>(send: &mut W, recv: &mut R, cfg: &Cfg, closed: C) -> u32
where W: tokio::io::AsyncWrite + Unpin, R: tokio::io::AsyncRead + Unpin, C: std::future::Future {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    let mut buf = Vec::with_capacity(256);
    let hello = tokio::time::timeout(HELLO_WAIT, async {
        let mut one = [0u8; 256];
        loop {
            match recv.read(&mut one).await { Ok(k) if k > 0 => { buf.extend_from_slice(&one[..k]); if buf.contains(&b'\n') { return true; } if buf.len() > HELLO_MAX { return false; } } _ => return false }
        }
    }).await.unwrap_or(false);
    if !hello { let _ = send.write_all(b"ERR 400\n").await; let _ = send.shutdown().await; return 2; }
    let end = buf.iter().position(|b| *b == b'\n').map(|i| i + 1).unwrap_or(buf.len());
    let (tok, last) = match parse_hello(&buf[..end]) { Ok(v) => v, Err(_) => { let _ = send.write_all(b"ERR 400\n").await; let _ = send.shutdown().await; return 2; } };
    let mut h = HeaderMap::new();
    let Ok(av) = HeaderValue::from_str(&format!("Bearer {tok}")) else { return 2 };
    h.insert(HeaderName::from_static("authorization"), av);
    if let Some(l) = last { if let Ok(v) = HeaderValue::from_str(&l.to_string()) { h.insert(HeaderName::from_static("last-event-id"), v); } }
    let res = (cfg.handler)(h).await;
    if !res.status().is_success() {
        let _ = send.write_all(format!("ERR {}\n", res.status().as_u16()).as_bytes()).await; let _ = send.shutdown().await;
        return 3;
    }
    let mut body = Body::into_data_stream(res.into_body());
    let life = tokio::time::sleep(MAX_LIFE);
    tokio::pin!(life); tokio::pin!(closed);
    loop {
        tokio::select! {
            c = body.next() => match c { Some(Ok(b)) => { if send.write_all(&b).await.is_err() { break; } } _ => break },
            _ = &mut life => break,
            _ = &mut closed => break,
        }
    }
    let _ = send.shutdown().await;
    0
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
        // one directory PER CALL: the tests run in parallel, and sharing c.pem/k.pem let one test overwrite another's pair (flaky "server_config unwrap" on his server, 10 Nov 2026)
        static N: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
        let dir = std::env::temp_dir().join(format!("anx-wt-{}-{}", std::process::id(), N.fetch_add(1, std::sync::atomic::Ordering::SeqCst)));
        std::fs::create_dir_all(&dir).ok()?;
        let (c, k) = (dir.join("c.pem"), dir.join("k.pem"));
        let ok = std::process::Command::new("openssl").args(["req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes", "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1", "-addext", "basicConstraints=critical,CA:FALSE", "-addext", "extendedKeyUsage=serverAuth", "-keyout"]).arg(&k).arg("-out").arg(&c).output().ok()?.status.success();
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
        tokio::spawn(serve(ep, store, Arc::new(Cfg { host: "127.0.0.1".into(), handler: handler(seen, status), rpc: None })));
        Some((port, c))
    }

    async fn talk(port: u16, cert: &[u8], suite: rustls::SupportedCipherSuite, path: &str, hello: &[u8]) -> Result<Vec<u8>, String> {
        let cl = client(cert, suite);
        let conn = tokio::time::timeout(Duration::from_secs(5), cl.connect(format!("https://127.0.0.1:{port}{path}"))).await.map_err(|_| "connect timeout".to_string())?.map_err(|e| format!("connect: {e}"))?;
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

    #[tokio::test(flavor = "multi_thread")]
    async fn k8d_the_api_runs_over_quic_through_the_router_and_the_exchange_now_runs_there_marked_as_a_kernel_call() {
        use axum::{routing::{get, post}, Router, http::HeaderMap as H};
        let router = Router::new()
            .route("/founder/v1/echo", post(|h: H, b: axum::body::Bytes| async move { format!("{}|{}|{}|{}", h.get("authorization").and_then(|v| v.to_str().ok()).unwrap_or(""), h.get("host").and_then(|v| v.to_str().ok()).unwrap_or(""), h.get("x-real-ip").and_then(|v| v.to_str().ok()).unwrap_or(""), String::from_utf8_lossy(&b)) }))
            .route("/founder/v1/exchange", get(|wt: Option<axum::Extension<crate::wtrpc::WtCall>>| async move { if wt.is_some() { "kernel-call" } else { "plain" } }))
            .route("/founder/v1/big", get(|| async { vec![b'a'; 1000] }));
        let Some((c, k)) = test_cert() else { eprintln!("openssl missing: skipped"); return };
        let tls = crate::tls256::server_config(&c, &k).unwrap();
        let ep = endpoint("127.0.0.1:0".parse().unwrap(), &tls).unwrap();
        let port = ep.local_addr().unwrap().port();
        let seen = Arc::new(std::sync::Mutex::new(vec![]));
        tokio::spawn(serve(ep, Arc::new(CertStore::fixed(tls)), Arc::new(Cfg { host: "127.0.0.1".into(), handler: handler(seen, 200), rpc: Some(router) })));
        let cl = client(&c, rustls::crypto::ring::cipher_suite::TLS13_AES_256_GCM_SHA384);
        let conn = tokio::time::timeout(Duration::from_secs(5), cl.connect(format!("https://127.0.0.1:{port}{RPC_PATH}"))).await.unwrap().unwrap();
        async fn call(conn: &wtransport::Connection, head: &str, body: &[u8]) -> Vec<u8> {
            let (mut s, mut r) = conn.open_bi().await.unwrap().await.unwrap();
            let mut req = head.as_bytes().to_vec(); req.push(b'\n'); req.extend_from_slice(body);
            s.write_all(&req).await.unwrap(); s.finish().await.unwrap();
            let mut out = Vec::new(); let mut b = [0u8; 4096];
            loop { match tokio::time::timeout(Duration::from_secs(5), r.read(&mut b)).await { Ok(Ok(Some(n))) => out.extend_from_slice(&b[..n]), _ => break } }
            out
        }
        // two calls on ONE session, one after the other, each its own stream
        let a = call(&conn, r#"{"m":"POST","p":"/founder/v1/echo","h":{"authorization":"Bearer t1","host":"evil"}}"#, b"hello").await;
        assert_eq!(String::from_utf8(a).unwrap(), "S 200 text/plain; charset=utf-8\nBearer t1|127.0.0.1|127.0.0.1|hello");
        let b = call(&conn, r#"{"m":"GET","p":"/founder/v1/exchange"}"#, b"").await;
        assert!(String::from_utf8(b).unwrap().ends_with("kernel-call"), "K8d-S4: the exchange runs over WebTransport and the handler sees the server-stamped kernel marker");
        let b = call(&conn, r#"{"m":"GET","p":"/founder/v1/dbsc/start"}"#, b"").await;
        assert!(String::from_utf8(b).unwrap().starts_with("S 404 "), "the DBSC routes stay browser-only");
        let c3 = call(&conn, r#"{"m":"GET","p":"/founder/v1/big"}"#, b"").await;
        assert!(c3.starts_with(b"S 200 ") && c3.ends_with(&[b'a'; 1000]));
        let d = call(&conn, r#"{"m":"GET","p":"/founder/v1/nothere"}"#, b"").await;
        assert!(String::from_utf8(d).unwrap().starts_with("S 404 "), "an unknown route is the router's own 404");
    }

    #[test]
    fn off_by_default_and_plain_host_only() {
        unsafe { std::env::remove_var("FOUNDER_WT_ADDR"); }
        assert!(from_env().is_none());
    }

    /// KP3: the SAME live and RPC code, but on the HTTP/3 endpoint (one UDP socket, h3 + h3-webtransport), reached by a real QUIC client with AES-256.
    async fn start_h3(status: u16, seen: Arc<std::sync::Mutex<Vec<(String, String)>>>, rpc: Option<axum::Router>) -> Option<(u16, Vec<u8>)> {
        let (c, k) = test_cert()?;
        let tls = crate::tls256::server_config(&c, &k).unwrap();
        let ep = crate::h3::endpoint("127.0.0.1:0".parse().unwrap(), &tls).unwrap();
        let port = ep.local_addr().unwrap().port();
        let app = axum::Router::new().route("/v", axum::routing::get(|| async { "plain" }));
        let cfg = Arc::new(Cfg { host: "127.0.0.1".into(), handler: handler(seen, status), rpc });
        tokio::spawn(crate::h3::serve(ep, Arc::new(CertStore::fixed(tls)), app, "127.0.0.1".into(), Some(cfg)));
        Some((port, c))
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn kp3_live_frames_flow_on_the_http3_endpoint_with_aes256() {
        let seen = Arc::new(std::sync::Mutex::new(vec![]));
        let Some((port, cert)) = start_h3(200, seen.clone(), None).await else { eprintln!("openssl missing: skipped"); return };
        let out = talk(port, &cert, rustls::crypto::ring::cipher_suite::TLS13_AES_256_GCM_SHA384, PATH, b"ANX1 tok123 42\n").await.unwrap();
        assert_eq!(String::from_utf8(out).unwrap(), "event: snapshot\ndata: {}\n\nevent: tick\ndata: {\"version\":1}\n\n");
        assert_eq!(seen.lock().unwrap().clone(), vec![("Bearer tok123".to_string(), "42".to_string())]);
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn kp3_refused_token_bad_hello_wrong_path_and_aes128_are_all_refused_on_the_http3_endpoint() {
        let seen = Arc::new(std::sync::Mutex::new(vec![]));
        let Some((port, cert)) = start_h3(401, seen.clone(), None).await else { eprintln!("openssl missing: skipped"); return };
        let a256 = rustls::crypto::ring::cipher_suite::TLS13_AES_256_GCM_SHA384;
        let a128 = rustls::crypto::ring::cipher_suite::TLS13_AES_128_GCM_SHA256;
        assert_eq!(String::from_utf8(talk(port, &cert, a256, PATH, b"ANX1 bad\n").await.unwrap()).unwrap(), "ERR 401\n");
        assert_eq!(String::from_utf8(talk(port, &cert, a256, PATH, b"GET / HTTP/1.1\n").await.unwrap()).unwrap(), "ERR 400\n");
        assert!(talk(port, &cert, a256, "/other", b"ANX1 tok\n").await.is_err(), "a path that is not /wt/live or /wt/rpc is refused");
        assert!(talk(port, &cert, a256, RPC_PATH, b"ANX1 tok\n").await.is_err(), "/wt/rpc is refused when no router is given");
        assert!(talk(port, &cert, a128, PATH, b"ANX1 tok\n").await.is_err(), "AES-128-only client must be refused");
        assert_eq!(seen.lock().unwrap().len(), 1, "only the well-formed hello reached the handler");
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn kp3_the_founder_api_runs_over_the_http3_endpoint_through_the_same_router_and_gates() {
        use axum::{routing::{get, post}, Router, http::HeaderMap as H};
        let router = Router::new()
            .route("/founder/v1/echo", post(|h: H, b: axum::body::Bytes| async move { format!("{}|{}|{}", h.get("authorization").and_then(|v| v.to_str().ok()).unwrap_or(""), h.get("host").and_then(|v| v.to_str().ok()).unwrap_or(""), String::from_utf8_lossy(&b)) }))
            .route("/founder/v1/exchange", get(|wt: Option<axum::Extension<crate::wtrpc::WtCall>>| async move { if wt.is_some() { "kernel-call" } else { "plain" } }));
        let seen = Arc::new(std::sync::Mutex::new(vec![]));
        let Some((port, c)) = start_h3(200, seen, Some(router)).await else { eprintln!("openssl missing: skipped"); return };
        let cl = client(&c, rustls::crypto::ring::cipher_suite::TLS13_AES_256_GCM_SHA384);
        let conn = tokio::time::timeout(Duration::from_secs(5), cl.connect(format!("https://127.0.0.1:{port}{RPC_PATH}"))).await.unwrap().unwrap();
        async fn call(conn: &wtransport::Connection, head: &str, body: &[u8]) -> Vec<u8> {
            let (mut s, mut r) = conn.open_bi().await.unwrap().await.unwrap();
            let mut req = head.as_bytes().to_vec(); req.push(b'\n'); req.extend_from_slice(body);
            s.write_all(&req).await.unwrap(); s.finish().await.unwrap();
            let mut out = Vec::new(); let mut b = [0u8; 4096];
            loop { match tokio::time::timeout(Duration::from_secs(5), r.read(&mut b)).await { Ok(Ok(Some(n))) => out.extend_from_slice(&b[..n]), _ => break } }
            out
        }
        let a = call(&conn, r#"{"m":"POST","p":"/founder/v1/echo","h":{"authorization":"Bearer t1","host":"evil"}}"#, b"hello").await;
        assert_eq!(String::from_utf8(a).unwrap(), "S 200 text/plain; charset=utf-8\nBearer t1|127.0.0.1|hello", "the caller never sets the host");
        let b = call(&conn, r#"{"m":"GET","p":"/founder/v1/exchange"}"#, b"").await;
        assert!(String::from_utf8(b).unwrap().ends_with("kernel-call"));
        let d = call(&conn, r#"{"m":"GET","p":"/founder/v1/dbsc/start"}"#, b"").await;
        assert!(String::from_utf8(d).unwrap().starts_with("S 404 "), "the browser-only DBSC routes stay refused");
    }
}
