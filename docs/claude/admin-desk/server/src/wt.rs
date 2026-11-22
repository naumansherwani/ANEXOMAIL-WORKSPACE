//! ADMIN DESK Phase C (22 Nov 2026): the Desk's OWN WebTransport (HTTP/3 over QUIC) for the live Bridge. His law 22 Nov 04:38: HTTP fallback is BANNED; this is the ONLY live path.
//! It rides the SAME h3 endpoint and UDP port as the Desk HTTP/3 (4400), same TLS 1.3 / AES-256-GCM / X25519MLKEM768. Desk-own copy of the pattern (DESK ISOLATION LAW).
//! Rule 52 on the stream: the first line is a MAC-bound hello (`ANX1 <token> <nonce> <ts> <mac>`; the browser cannot set headers on a WebTransport CONNECT), every frame
//! that follows is ONE line holding a Desk-signed envelope (method "WT", path "/wt/bridge/<track>") whose body is `{"seq":n,"track":..,"data":..}`. The kernel verifies the
//! signature, requires seq to rise by one per track (a gap or a replay is refused) and marks the track STALE when no frame arrives for 12 s (heartbeat every 8 s).
//! The session token is re-checked at EVERY tick (sign-out or a revoked session ends the stream); the database decides what the person may see.
use std::{future::Future, pin::Pin, sync::{atomic::{AtomicUsize, Ordering}, Arc}, time::Duration};
use sha2::{Digest, Sha256};

pub const PATH: &str = "/wt/bridge";
pub const MAX_SESSIONS: usize = 64;
pub const HELLO_WAIT: Duration = Duration::from_secs(5);
pub const TICK: Duration = Duration::from_secs(4);
pub const HEARTBEAT: Duration = Duration::from_secs(8);
const MAX_LIFE: Duration = Duration::from_secs(900);
pub const TRACKS: [&str; 3] = ["summary", "services", "alerts"];

/// Source of one track: (token, track) -> JSON text, or the HTTP-style status of a refusal. Production = bridge::track; tests inject their own.
pub type Fetch = Arc<dyn Fn(String, &'static str) -> Pin<Box<dyn Future<Output = Result<String, u16>> + Send>> + Send + Sync>;
pub struct Cfg { pub host: String, pub fetch: Fetch }

static ACTIVE: AtomicUsize = AtomicUsize::new(0);
pub struct Active;
impl Active { pub fn take() -> Option<Active> { let n = ACTIVE.fetch_add(1, Ordering::SeqCst); if n >= MAX_SESSIONS { ACTIVE.fetch_sub(1, Ordering::SeqCst); return None; } Some(Active) } }
impl Drop for Active { fn drop(&mut self) { ACTIVE.fetch_sub(1, Ordering::SeqCst); } }

pub fn authority_host(a: &str) -> String { a.rsplit_once(':').filter(|(h, p)| !h.contains(':') && p.bytes().all(|b| b.is_ascii_digit())).map(|(h, _)| h).unwrap_or(a).to_ascii_lowercase() }
pub fn origin_ok(origin: Option<&str>, host: &str) -> bool { match origin { None => true, Some(o) => o.eq_ignore_ascii_case(&format!("https://{host}")) } }

pub struct Hello { pub token: String, pub nonce: String, pub ts: i64, pub mac: String }
/// `ANX1 <token 64 hex> <nonce 32 hex> <ts> <mac 64 hex>\n`. Pure: strict charset, one LF, nothing else.
pub fn parse_hello(line: &[u8]) -> Result<Hello, &'static str> {
    let s = std::str::from_utf8(line).map_err(|_| "not text")?;
    let s = s.strip_suffix('\n').ok_or("no end of line")?;
    let w: Vec<&str> = s.split(' ').collect();
    if w.len() != 5 || w[0] != "ANX1" { return Err("bad hello"); }
    let hex = |x: &str, n: usize| x.len() == n && x.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f' | b'A'..=b'F'));
    if !hex(w[1], 64) || !hex(w[2], 32) || !hex(w[4], 64) { return Err("bad field"); }
    if w[3].is_empty() || w[3].len() > 12 || !w[3].bytes().all(|b| b.is_ascii_digit()) { return Err("bad ts"); }
    Ok(Hello { token: w[1].to_string(), nonce: w[2].to_ascii_lowercase(), ts: w[3].parse().map_err(|_| "bad ts")?, mac: w[4].to_ascii_lowercase() })
}

/// The body of one frame. `data` is the already-valid JSON text the database returned, embedded as is.
pub fn frame_body(seq: u64, track: &str, data: &str) -> String { format!("{{\"seq\":{seq},\"track\":\"{track}\",\"data\":{data}}}") }
/// A per-frame nonce (32 hex): bound to the session salt and the frame number, so no two frames ever share one.
pub fn frame_nonce(salt: &str, seq: u64) -> String { let mut h = Sha256::new(); h.update(salt.as_bytes()); h.update(seq.to_be_bytes()); h.finalize().iter().take(16).map(|b| format!("{b:02x}")).collect() }

/// One session on one bidirectional stream. Returns the QUIC close code (0 done, 2 bad hello, 3 refused, 4 ended by sign-out).
pub async fn session<W, R>(send: &mut W, recv: &mut R, cfg: &Cfg) -> u32
where W: tokio::io::AsyncWrite + Unpin, R: tokio::io::AsyncRead + Unpin {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    let mut buf = Vec::with_capacity(256);
    let got = tokio::time::timeout(HELLO_WAIT, async {
        let mut one = [0u8; 256];
        loop { match recv.read(&mut one).await { Ok(k) if k > 0 => { buf.extend_from_slice(&one[..k]); if buf.contains(&b'\n') { return true; } if buf.len() > 512 { return false; } } _ => return false } }
    }).await.unwrap_or(false);
    if !got { let _ = send.write_all(b"ERR 400\n").await; let _ = send.shutdown().await; return 2; }
    let end = buf.iter().position(|b| *b == b'\n').map(|i| i + 1).unwrap_or(buf.len());
    let h = match parse_hello(&buf[..end]) { Ok(h) => h, Err(_) => { let _ = send.write_all(b"ERR 400\n").await; let _ = send.shutdown().await; return 2; } };
    let now = crate::signed::now_secs();
    if let Err(e) = crate::sign::verify_req(&h.token, "WT", PATH, &h.nonce, h.ts, b"", &h.mac, now) { let _ = send.write_all(format!("ERR 401 {e}\n").as_bytes()).await; let _ = send.shutdown().await; return 3; }
    if !crate::signed::nonce_fresh(&h.token, &h.nonce) { let _ = send.write_all(b"ERR 401 replayed_request\n").await; let _ = send.shutdown().await; return 3; }
    let salt = format!("{}{}", h.nonce, h.mac);
    let started = tokio::time::Instant::now();
    let mut seq = [0u64; 3];
    let mut last: [Option<String>; 3] = [None, None, None];
    let mut sent_at = [tokio::time::Instant::now(); 3];
    let mut n: u64 = 0;
    let mut first = true;
    loop {
        for (i, t) in TRACKS.iter().enumerate() {
            match (cfg.fetch)(h.token.clone(), t).await {
                Ok(data) => {
                    let due = first || last[i].as_deref() != Some(data.as_str()) || sent_at[i].elapsed() >= HEARTBEAT;
                    if due {
                        seq[i] += 1; n += 1;
                        // seq = this track's own counter (what the kernel checks); the nonce uses the session-wide frame number
                        let Some(line) = seal_seq(&salt, n, seq[i], t, &data) else { let _ = send.write_all(b"ERR 503\n").await; return 3 };
                        if send.write_all(&line).await.is_err() { return 0; }
                        last[i] = Some(data); sent_at[i] = tokio::time::Instant::now();
                    }
                }
                Err(code) => { let _ = send.write_all(format!("ERR {code}\n").as_bytes()).await; let _ = send.shutdown().await; return if code == 401 { 4 } else { 3 }; }
            }
        }
        first = false;
        if started.elapsed() >= MAX_LIFE { break; }
        tokio::select! {
            _ = tokio::time::sleep(TICK) => {}
            r = async { let mut b = [0u8; 64]; recv.read(&mut b).await } => { if !matches!(r, Ok(k) if k > 0) { return 0; } }
        }
    }
    let _ = send.shutdown().await;
    0
}

fn seal_seq(salt: &str, nonce_n: u64, seq: u64, track: &str, data: &str) -> Option<Vec<u8>> {
    let body = frame_body(seq, track, data);
    let mut line = crate::signed::seal_frame(&format!("{PATH}/{track}"), &frame_nonce(salt, nonce_n), &body)?.into_bytes();
    line.push(b'\n'); Some(line)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{h3, sign, signed};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    const TOK: &str = "ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12";
    fn hello(tok: &str, nonce: &str, ts: i64) -> String { format!("ANX1 {tok} {nonce} {ts} {}\n", sign::req_mac(tok, "WT", PATH, nonce, ts, b"")) }

    #[test] fn hello_parser_accepts_the_shape_and_refuses_everything_else() {
        let good = hello(TOK, "00112233445566778899aabbccddeeff", 1000);
        let h = parse_hello(good.as_bytes()).unwrap(); assert_eq!(h.token, TOK); assert_eq!(h.ts, 1000);
        let mac = sign::req_mac(TOK, "WT", PATH, "00112233445566778899aabbccddeeff", 1000, b"");
        for bad in [format!("ANX1 {TOK} 00112233445566778899aabbccddeeff 1000 {mac}"), format!("ANX2 {TOK} 00112233445566778899aabbccddeeff 1000 {mac}\n"), format!("ANX1 {TOK} 00112233445566778899aabbccddeeff 1000 {mac}\r\n"),
            format!("ANX1 {TOK} 0011 1000 {mac}\n"), format!("ANX1 {TOK} 00112233445566778899aabbccddeeff -5 {mac}\n"), format!("ANX1 {TOK} 00112233445566778899aabbccddeeff 1000 {mac} x\n"),
            format!("ANX1 {}\" 00112233445566778899aabbccddeeff 1000 {mac}\n", &TOK[..63]), "GET /\n".into(), "ANX1\n".into()] {
            assert!(parse_hello(bad.as_bytes()).is_err(), "must refuse {bad:?}");
        }
    }
    #[test] fn origin_and_authority_rules() {
        assert!(origin_ok(None, "admindesk.anexomail.com") && origin_ok(Some("https://AdminDesk.anexomail.com"), "admindesk.anexomail.com"));
        for bad in ["http://admindesk.anexomail.com", "https://evil.com", "https://admindesk.anexomail.com.evil.com", "https://admindesk.anexomail.com:4400", "https://founderworkspace.anexomail.com", "null", ""] { assert!(!origin_ok(Some(bad), "admindesk.anexomail.com"), "{bad}"); }
        assert_eq!(authority_host("AdminDesk.anexomail.com:4400"), "admindesk.anexomail.com");
    }
    #[test] fn frame_body_and_nonce_are_unique_and_valid() {
        assert_eq!(frame_body(3, "summary", "{\"p1\":0}"), "{\"seq\":3,\"track\":\"summary\",\"data\":{\"p1\":0}}");
        assert!(serde_json::from_str::<serde_json::Value>(&frame_body(1, "alerts", "[]")).is_ok());
        let (a, b) = (frame_nonce("s", 1), frame_nonce("s", 2)); assert_ne!(a, b); assert!(sign::nonce_ok(&a) && sign::nonce_ok(&b)); assert_ne!(frame_nonce("t", 1), a);
    }

    fn test_cert() -> Option<(Vec<u8>, Vec<u8>)> {
        static N: AtomicUsize = AtomicUsize::new(0);
        let dir = std::env::temp_dir().join(format!("desk-wt-{}-{}", std::process::id(), N.fetch_add(1, Ordering::SeqCst)));
        std::fs::create_dir_all(&dir).ok()?;
        let (c, k) = (dir.join("c.pem"), dir.join("k.pem"));
        let ok = std::process::Command::new("openssl").args(["req","-x509","-newkey","ec","-pkeyopt","ec_paramgen_curve:prime256v1","-nodes","-days","1","-subj","/CN=localhost","-addext","subjectAltName=DNS:localhost,IP:127.0.0.1","-addext","basicConstraints=critical,CA:FALSE","-keyout",k.to_str().unwrap(),"-out",c.to_str().unwrap()]).output().map(|o| o.status.success()).unwrap_or(false);
        if !ok { return None; }
        Some((std::fs::read(c).ok()?, std::fs::read(k).ok()?))
    }
    fn client(cert_pem: &[u8]) -> wtransport::Endpoint<wtransport::endpoint::endpoint_side::Client> {
        use rustls::pki_types::{CertificateDer, pem::PemObject};
        let mut p = rustls::crypto::ring::default_provider();
        p.cipher_suites = vec![rustls::crypto::ring::cipher_suite::TLS13_AES_256_GCM_SHA384];
        let mut roots = rustls::RootCertStore::empty();
        for c in CertificateDer::pem_slice_iter(cert_pem) { roots.add(c.unwrap()).unwrap(); }
        let mut c = rustls::ClientConfig::builder_with_provider(Arc::new(p)).with_protocol_versions(&[&rustls::version::TLS13]).unwrap().with_root_certificates(roots).with_no_client_auth();
        c.alpn_protocols = vec![b"h3".to_vec()];
        let initial = rustls::crypto::ring::cipher_suite::TLS13_AES_128_GCM_SHA256.tls13().unwrap().quic_suite().unwrap();
        let q = quinn::crypto::rustls::QuicClientConfig::with_initial(Arc::new(c), initial).unwrap();
        wtransport::Endpoint::client(wtransport::ClientConfig::builder().with_bind_address("127.0.0.1:0".parse().unwrap()).build_with_quic_config(quinn::ClientConfig::new(Arc::new(q)))).unwrap()
    }
    use wtransport::quinn;

    fn fake(deny: Option<u16>) -> Fetch {
        Arc::new(move |_t: String, track: &'static str| Box::pin(async move {
            if let Some(c) = deny { return Err(c); }
            Ok(match track { "summary" => r#"{"p1":0}"#.to_string(), "services" => r#"[{"name":"db"}]"#.to_string(), _ => "[]".to_string() })
        }))
    }
    async fn start(fetch: Fetch) -> Option<(u16, Vec<u8>)> {
        let (c, k) = test_cert()?;
        let f = std::env::temp_dir().join("desk-wt-test.seed");
        std::fs::write(&f, "0303030303030303030303030303030303030303030303030303030303030303").unwrap();
        unsafe { std::env::set_var("DESK_SIGN_SEED_FILE", &f); }
        signed::init();
        let ep = quinn::Endpoint::server(h3::quic_config(h3::server_config(&c, &k).unwrap()).unwrap(), "127.0.0.1:0".parse().unwrap()).unwrap();
        let port = ep.local_addr().unwrap().port();
        let router = axum::Router::new().route("/desk/v1/health", axum::routing::get(|| async { "ok" }));
        tokio::spawn(h3::serve(ep, router, "localhost".into(), Some(Arc::new(Cfg { host: "localhost".into(), fetch }))));
        Some((port, c))
    }
    /// Connect with `path`, send `hello`, read for up to `wait`.
    async fn talk(port: u16, cert: &[u8], path: &str, hello: &str, wait: Duration) -> Result<Vec<u8>, String> {
        let cl = client(cert);
        let conn = tokio::time::timeout(Duration::from_secs(5), cl.connect(format!("https://localhost:{port}{path}"))).await.map_err(|_| "connect timeout".to_string())?.map_err(|e| format!("connect: {e}"))?;
        let (mut s, mut r) = conn.open_bi().await.map_err(|e| e.to_string())?.await.map_err(|e| e.to_string())?;
        s.write_all(hello.as_bytes()).await.map_err(|e| e.to_string())?;
        let mut out = Vec::new(); let mut b = [0u8; 4096];
        let end = tokio::time::Instant::now() + wait;
        loop { match tokio::time::timeout_at(end, r.read(&mut b)).await { Ok(Ok(Some(n))) => out.extend_from_slice(&b[..n]), _ => break } }
        Ok(out)
    }
    fn verify_line(line: &str) -> Option<serde_json::Value> {
        use ed25519_dalek::{Signature, Verifier, VerifyingKey};
        let e: serde_json::Value = serde_json::from_str(line).ok()?;
        let body = e["body"].as_str()?; let b: serde_json::Value = serde_json::from_str(body).ok()?;
        let path = format!("{PATH}/{}", b["track"].as_str()?);
        let vk = VerifyingKey::from_bytes(&sign::unhex(&signed::public_hex()?)?.try_into().ok()?).ok()?;
        let sig = Signature::from_slice(&sign::unhex(e["sig"].as_str()?)?).ok()?;
        vk.verify(&sign::message("WT", &path, e["nonce"].as_str()?, e["ts"].as_i64()?, body.as_bytes()), &sig).ok()?;
        Some(b)
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn signed_frames_flow_over_quic_h3_with_rising_seq_and_the_kernel_can_verify_them() {
        let Some((port, cert)) = start(fake(None)).await else { eprintln!("openssl missing: skipped"); return };
        let ts = signed::now_secs();
        let out = talk(port, &cert, PATH, &hello(TOK, "0a0b0c0d0e0f00112233445566778899", ts), Duration::from_millis(1500)).await.unwrap();
        let text = String::from_utf8(out).unwrap();
        let lines: Vec<&str> = text.lines().collect();
        assert_eq!(lines.len(), 3, "one frame per track at start: {text}");
        let mut tracks = vec![];
        for l in &lines { let b = verify_line(l).expect("every frame must verify with the Desk key"); assert_eq!(b["seq"], 1); tracks.push(b["track"].as_str().unwrap().to_string()); }
        assert_eq!(tracks, ["summary", "services", "alerts"]);
        let mut t = lines[0].to_string(); t = t.replace("p1", "p2"); assert!(verify_line(&t).is_none(), "a tampered frame must fail");
    }
    #[tokio::test(flavor = "multi_thread")]
    async fn bad_hello_wrong_mac_replay_and_a_dead_session_never_get_data() {
        let Some((port, cert)) = start(fake(None)).await else { eprintln!("openssl missing: skipped"); return };
        let ts = signed::now_secs(); let n = "1a1b1c1d1e1f00112233445566778899";
        let w = Duration::from_millis(800);
        assert_eq!(String::from_utf8(talk(port, &cert, PATH, "GET /\n", w).await.unwrap()).unwrap(), "ERR 400\n");
        let bad_mac = format!("ANX1 {TOK} {n} {ts} {}\n", "0".repeat(64));
        assert!(String::from_utf8(talk(port, &cert, PATH, &bad_mac, w).await.unwrap()).unwrap().starts_with("ERR 401 bad_mac"));
        assert!(String::from_utf8(talk(port, &cert, PATH, &hello(TOK, n, ts - 600), w).await.unwrap()).unwrap().starts_with("ERR 401 stale_request"));
        let h = hello(TOK, n, ts);
        let first = String::from_utf8(talk(port, &cert, PATH, &h, w).await.unwrap()).unwrap(); assert!(first.contains("seq") && first.lines().count() == 3, "first: {first:?}");
        assert!(String::from_utf8(talk(port, &cert, PATH, &h, w).await.unwrap()).unwrap().starts_with("ERR 401 replayed_request"), "the same hello must not work twice");
        assert!(talk(port, &cert, "/other", &hello(TOK, "2a2b2c2d2e2f00112233445566778899", ts), w).await.is_err(), "wrong path refused");
    }
    #[tokio::test(flavor = "multi_thread")]
    async fn a_refused_or_ended_session_gets_err_and_no_frame() {
        let Some((port, cert)) = start(fake(Some(401))).await else { eprintln!("openssl missing: skipped"); return };
        let ts = signed::now_secs();
        assert_eq!(String::from_utf8(talk(port, &cert, PATH, &hello(TOK, "3a3b3c3d3e3f00112233445566778899", ts), Duration::from_millis(800)).await.unwrap()).unwrap(), "ERR 401\n");
        let Some((port, cert)) = start(fake(Some(403))).await else { return };
        assert_eq!(String::from_utf8(talk(port, &cert, PATH, &hello(TOK, "4a4b4c4d4e4f00112233445566778899", ts), Duration::from_millis(800)).await.unwrap()).unwrap(), "ERR 403\n");
    }
}
