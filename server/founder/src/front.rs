//! K4.4 (founder, 7 Nov 2026): the SNI front. It listens on one TCP port, reads ONLY the TLS ClientHello server name (it never decrypts, never holds a key),
//! and forwards the connection byte for byte: the founder host -> the Rust AES-256 terminator, every other name -> Caddy on an internal port, with a PROXY protocol v1
//! line first so Caddy still sees the real client address. Technology: Rust (tokio), a pure ClientHello parser + a small forwarder, inside the founder binary.
//! DEFAULT OFF (needs FOUNDER_FRONT_ADDR). Built and tested on a SPARE port; the real :443 stays Caddy until the founder says "haan" (K4.5) and a rollback is ready.
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;

use tokio::io::AsyncWriteExt;
use tokio::net::{TcpListener, TcpStream};

/// What a prefix of a connection tells us.
#[derive(Debug, PartialEq, Eq)]
pub enum Peek { Need, Name(String), NoName, NotTls }

fn take<'a>(b: &mut &'a [u8], n: usize) -> Option<&'a [u8]> { if b.len() < n { return None; } let (h, t) = b.split_at(n); *b = t; Some(h) }
fn u8_(b: &mut &[u8]) -> Option<usize> { Some(take(b, 1)?[0] as usize) }
fn u16_(b: &mut &[u8]) -> Option<usize> { let x = take(b, 2)?; Some(((x[0] as usize) << 8) | x[1] as usize) }

/// A host name from the wire: only the characters a DNS name can carry, lower-cased, at most 253 long.
fn clean_name(n: &[u8]) -> Option<String> {
    if n.is_empty() || n.len() > 253 || !n.iter().all(|c| c.is_ascii_alphanumeric() || *c == b'-' || *c == b'.' || *c == b'_') { return None; }
    Some(String::from_utf8_lossy(n).to_ascii_lowercase().trim_end_matches('.').to_string())
}

/// Read the server name out of the first bytes of a TLS connection. Pure: no I/O, never panics on any input.
/// Need = not enough bytes yet; NotTls = not a TLS ClientHello that fits one record; NoName = a ClientHello without a usable server_name.
pub fn peek_sni(b: &[u8]) -> Peek {
    if b.is_empty() { return Peek::Need; }
    if b[0] != 0x16 { return Peek::NotTls; }
    if b.len() < 5 { return Peek::Need; }
    if b[1] != 3 { return Peek::NotTls; }
    let rec = ((b[3] as usize) << 8) | b[4] as usize;
    if rec < 4 || rec > 16_384 { return Peek::NotTls; }
    if b.len() < 5 + rec { return Peek::Need; }
    let mut h = &b[5..5 + rec];
    if h[0] != 1 { return Peek::NotTls; }                                   // handshake type ClientHello
    let _ = take(&mut h, 1);
    let Some(l3) = take(&mut h, 3) else { return Peek::NotTls };
    let len = ((l3[0] as usize) << 16) | ((l3[1] as usize) << 8) | l3[2] as usize;
    if len > h.len() { return Peek::NotTls; }                                // a hello split over several records is not handled: it goes to the default backend
    let mut body = &h[..len];
    let r = (|| -> Option<Option<String>> {
        take(&mut body, 2 + 32)?;                                            // version, random
        let s = u8_(&mut body)?; take(&mut body, s)?;                        // session id
        let c = u16_(&mut body)?; take(&mut body, c)?;                       // cipher suites
        let m = u8_(&mut body)?; take(&mut body, m)?;                        // compression
        if body.is_empty() { return Some(None); }
        let el = u16_(&mut body)?; let mut ext = take(&mut body, el)?;
        while !ext.is_empty() {
            let t = u16_(&mut ext)?; let l = u16_(&mut ext)?; let mut d = take(&mut ext, l)?;
            if t != 0 { continue; }                                          // server_name extension
            let ll = u16_(&mut d)?; let mut list = take(&mut d, ll)?;
            while !list.is_empty() {
                let nt = u8_(&mut list)?; let nl = u16_(&mut list)?; let n = take(&mut list, nl)?;
                if nt == 0 { return Some(clean_name(n)); }                   // host_name
            }
        }
        Some(None)
    })();
    match r { Some(Some(n)) => Peek::Name(n), Some(None) => Peek::NoName, None => Peek::NotTls }
}

/// PROXY protocol v1 line for a connection from `src` to `dst` (what Caddy's proxy_protocol listener wrapper reads).
pub fn proxy_v1(src: SocketAddr, dst: SocketAddr) -> String {
    match (src, dst) {
        (SocketAddr::V4(s), SocketAddr::V4(d)) => format!("PROXY TCP4 {} {} {} {}\r\n", s.ip(), d.ip(), s.port(), d.port()),
        (SocketAddr::V6(s), SocketAddr::V6(d)) => format!("PROXY TCP6 {} {} {} {}\r\n", s.ip(), d.ip(), s.port(), d.port()),
        _ => "PROXY UNKNOWN\r\n".to_string(),
    }
}

/// Where each kind of connection goes.
pub struct FrontCfg { pub host: String, pub tls_backend: String, pub other_backend: String, pub proxy_other: bool }

/// FOUNDER_FRONT_ADDR + FOUNDER_FRONT_HOST + FOUNDER_FRONT_TLS + FOUNDER_FRONT_OTHER -> (listen address, config). None = off (the default).
pub fn from_env() -> Option<Result<(String, Arc<FrontCfg>), String>> {
    let addr = std::env::var("FOUNDER_FRONT_ADDR").ok().filter(|a| !a.trim().is_empty())?;
    let get = |k: &str| std::env::var(k).ok().filter(|v| !v.trim().is_empty()).ok_or(format!("{k} is not set"));
    Some((|| Ok((addr.clone(), Arc::new(FrontCfg { host: get("FOUNDER_FRONT_HOST")?.to_ascii_lowercase(), tls_backend: get("FOUNDER_FRONT_TLS")?, other_backend: get("FOUNDER_FRONT_OTHER")?, proxy_other: std::env::var("FOUNDER_FRONT_PROXY").map(|v| !matches!(v.trim().to_ascii_lowercase().as_str(), "off" | "0" | "no")).unwrap_or(true) }))))())
}

/// Decide the backend for one connection from its first bytes, then forward both directions until either side closes. 5 s to show a server name.
pub async fn serve_front(l: TcpListener, cfg: Arc<FrontCfg>) {
    loop {
        let Ok((client, peer)) = l.accept().await else { continue };
        let cfg = cfg.clone();
        tokio::spawn(async move { let _ = handle(client, peer, &cfg).await; });
    }
}

async fn handle(mut client: TcpStream, peer: SocketAddr, cfg: &FrontCfg) -> std::io::Result<()> {
    let mut buf = vec![0u8; 5 + 16_384];
    let verdict = tokio::time::timeout(Duration::from_secs(5), async {
        let mut last = 0usize;
        loop {
            let n = client.peek(&mut buf).await?;
            if n == 0 { return Ok::<Peek, std::io::Error>(Peek::NotTls); }
            match peek_sni(&buf[..n]) { Peek::Need => { if n == last { tokio::time::sleep(Duration::from_millis(15)).await; } last = n; } v => return Ok(v) }
        }
    }).await;
    let to_terminator = matches!(verdict, Ok(Ok(Peek::Name(ref n))) if *n == cfg.host);
    let mut backend = TcpStream::connect(if to_terminator { &cfg.tls_backend } else { &cfg.other_backend }).await?;
    if !to_terminator && cfg.proxy_other { backend.write_all(proxy_v1(peer, client.local_addr().unwrap_or(peer)).as_bytes()).await?; }
    tokio::io::copy_bidirectional(&mut client, &mut backend).await.map(|_| ())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    /// A REAL ClientHello made by rustls for `name`.
    fn hello(name: &str) -> Vec<u8> {
        let cfg = rustls::ClientConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider())).with_safe_default_protocol_versions().unwrap()
            .with_root_certificates(rustls::RootCertStore::empty()).with_no_client_auth();
        let mut c = rustls::ClientConnection::new(Arc::new(cfg), rustls::pki_types::ServerName::try_from(name.to_string()).unwrap()).unwrap();
        let mut out = Vec::new(); c.write_tls(&mut out).unwrap(); out
    }

    #[test]
    fn a_real_client_hello_gives_its_server_name_and_a_prefix_asks_for_more() {
        let h = hello("FounderWorkspace.Anexomail.com");
        assert_eq!(peek_sni(&h), Peek::Name("founderworkspace.anexomail.com".into()));
        for cut in [0usize, 1, 4, 5, 20, h.len() - 1] { assert_eq!(peek_sni(&h[..cut]), Peek::Need, "prefix {cut}"); }
        assert_eq!(peek_sni(&hello("anexomail.com")), Peek::Name("anexomail.com".into()));
    }

    #[test]
    fn junk_and_hostile_input_never_panics_and_never_names_a_host() {
        assert_eq!(peek_sni(b"GET / HTTP/1.1\r\n\r\n"), Peek::NotTls);
        assert_eq!(peek_sni(&[0x16, 0x03, 0x01, 0x00, 0x00]), Peek::NotTls);          // empty record
        assert_eq!(peek_sni(&[0x16, 0x03, 0x01, 0xff, 0xff]), Peek::NotTls);          // record longer than 16 KB
        assert_eq!(peek_sni(&[0x16, 0x02, 0x01, 0x00, 0x05]), Peek::NotTls);          // wrong record version
        let mut h = hello("anexomail.com");
        for i in 5..h.len() { let s = h[i]; for v in [0u8, 0xff, s ^ 0x55] { h[i] = v; let _ = peek_sni(&h); } h[i] = s; }   // flip every byte: must not panic
        let mut cut = hello("anexomail.com"); cut.truncate(60); cut[3] = 0; cut[4] = 55;   // record claims 55 bytes, hello inside is cut short
        assert!(matches!(peek_sni(&cut), Peek::NotTls | Peek::NoName | Peek::Need));
        assert!(clean_name(b"bad name").is_none() && clean_name(b"").is_none() && clean_name(&[b'a'; 300]).is_none() && clean_name(b"a.b-c.example.").unwrap() == "a.b-c.example");
    }

    #[test]
    fn proxy_line_shapes() {
        assert_eq!(proxy_v1("1.2.3.4:5555".parse().unwrap(), "9.9.9.9:443".parse().unwrap()), "PROXY TCP4 1.2.3.4 9.9.9.9 5555 443\r\n");
        assert_eq!(proxy_v1("[::1]:1".parse().unwrap(), "[::2]:443".parse().unwrap()), "PROXY TCP6 ::1 ::2 1 443\r\n");
        assert_eq!(proxy_v1("1.2.3.4:1".parse().unwrap(), "[::2]:443".parse().unwrap()), "PROXY UNKNOWN\r\n");
    }

    /// A backend that answers "<tag>|<first line or first bytes>" once it has read something.
    async fn backend(tag: &'static str) -> String {
        let l = TcpListener::bind("127.0.0.1:0").await.unwrap(); let addr = l.local_addr().unwrap().to_string();
        tokio::spawn(async move { loop { let Ok((mut s, _)) = l.accept().await else { continue };
            tokio::spawn(async move { let mut b = vec![0u8; 4096]; let n = s.read(&mut b).await.unwrap_or(0); let head = String::from_utf8_lossy(&b[..n.min(60)]).split("\r\n").next().unwrap_or("").to_string();
                let _ = s.write_all(format!("{tag}|{}", if head.starts_with("PROXY") { head } else { "tls-bytes".into() }).as_bytes()).await; }); } });
        addr
    }
    async fn through_front(cfg: Arc<FrontCfg>, first: Vec<u8>) -> String {
        let l = TcpListener::bind("127.0.0.1:0").await.unwrap(); let a = l.local_addr().unwrap();
        tokio::spawn(serve_front(l, cfg));
        let mut c = TcpStream::connect(a).await.unwrap(); c.write_all(&first).await.unwrap();
        let mut out = vec![0u8; 256]; let n = tokio::time::timeout(Duration::from_secs(5), c.read(&mut out)).await.expect("front answered").unwrap();
        String::from_utf8_lossy(&out[..n]).to_string()
    }

    #[tokio::test]
    async fn the_founder_host_goes_to_the_terminator_and_every_other_name_goes_to_caddy_with_a_proxy_line() {
        let (t, o) = (backend("TERMINATOR").await, backend("CADDY").await);
        let cfg = Arc::new(FrontCfg { host: "founderworkspace.anexomail.com".into(), tls_backend: t, other_backend: o, proxy_other: true });
        assert_eq!(through_front(cfg.clone(), hello("founderworkspace.anexomail.com")).await, "TERMINATOR|tls-bytes", "founder host: plain bytes, the terminator sees the untouched ClientHello");
        let other = through_front(cfg.clone(), hello("anexomail.com")).await;
        assert!(other.starts_with("CADDY|PROXY TCP4 127.0.0.1 127.0.0.1 "), "other host: PROXY line first: {other}");
        let nosni = through_front(cfg.clone(), b"\x16\x03\x01\x00\x05hello".to_vec()).await;
        assert!(nosni.starts_with("CADDY|PROXY"), "not a usable hello goes to the default backend (Caddy): {nosni}");
    }

    #[tokio::test]
    async fn with_the_proxy_line_switched_off_the_other_backend_gets_the_untouched_bytes() {
        let (t, o) = (backend("TERMINATOR").await, backend("CADDY").await);
        let cfg = Arc::new(FrontCfg { host: "founderworkspace.anexomail.com".into(), tls_backend: t, other_backend: o, proxy_other: false });
        assert_eq!(through_front(cfg, hello("anexomail.com")).await, "CADDY|tls-bytes", "spare-port test mode: Caddy's normal :443 can be the other backend");
    }

    #[test]
    fn env_is_off_by_default_and_plain_when_half_set() {
        unsafe { std::env::remove_var("FOUNDER_FRONT_ADDR"); }
        assert!(from_env().is_none());
        unsafe { std::env::set_var("FOUNDER_FRONT_ADDR", "0.0.0.0:8445"); std::env::remove_var("FOUNDER_FRONT_HOST"); }
        assert!(matches!(from_env(), Some(Err(e)) if e.contains("FOUNDER_FRONT_HOST")));
        unsafe { std::env::remove_var("FOUNDER_FRONT_ADDR"); }
    }
}
