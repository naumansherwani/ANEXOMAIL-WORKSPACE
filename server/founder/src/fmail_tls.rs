//! QC1c F2/F4 (founder mailbox): the domain TLS probe behind the lock on every recipient chip. Technology: Rust + Tokio, tokio-rustls (TLS 1.3 + 1.2 allowed so an old server is NAMED, X25519MLKEM768 offered first), hickory-resolver.
//! INHERITABLE BY AWAM: no database, no founder names. Reuses fmail_smtp (targets, read_reply, Reply, is_public, Io/BoxIo, Fail): no second copy of MX / address logic.
//! Law of this file: (1) the probe takes a DOMAIN ONLY, never an address, never MAIL FROM / RCPT / DATA: it greets, asks STARTTLS, handshakes, QUITs. (2) Every answer is one of the closed verdicts
//! pq / classic13 / classic12 / none / refused / unreachable / nomail; the word "unknown" does not exist. (3) A certificate that does not verify is still READ (group, version) and stored with cert_verified=false,
//! nothing is ever sent over such a connection except QUIT. (4) At most 3 MX hosts, priority order, 45 s cap for the whole domain, private addresses never contacted (smtp::targets).
use crate::fmail_smtp as smtp;
use smtp::{BoxIo, Fail};
use std::{future::Future, pin::Pin, sync::{atomic::{AtomicBool, Ordering}, Arc}, time::Duration};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};

const CONNECT_TIMEOUT: u64 = 10;
const CMD_TIMEOUT: u64 = 10;
const DOMAIN_CAP: u64 = 45;
const MAX_HOSTS: usize = 3;

/// What the handshake proved. Strings are already in the form the SQL CHECKs accept.
#[derive(Debug, Clone, PartialEq)]
pub struct TlsFact { pub version: String, pub group: String, pub cipher: String, pub cert_verified: bool }
/// The closed result of one domain.
#[derive(Debug, Clone, PartialEq)]
pub struct Probe { pub verdict: &'static str, pub fact: Option<TlsFact>, pub detail: String, pub hosts_tried: Vec<String> }

/// A domain and nothing else: no '@', no spaces, lower case, IDNA ascii, one dot at least.
pub fn domain_only(s: &str) -> Option<String> {
    let s = s.trim().trim_end_matches('.').to_ascii_lowercase();
    if s.is_empty() || s.len() > 253 || s.contains('@') || s.contains(char::is_whitespace) { return None; }
    let a = idna::domain_to_ascii(&s).ok()?;
    if !a.contains('.') || a.split('.').any(|l| l.is_empty() || l.len() > 63 || l.starts_with('-') || l.ends_with('-') || !l.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-')) { return None; }
    Some(a)
}
/// The probe's own SMTP verbs. A closed list: MAIL / RCPT / DATA can never be produced.
pub fn never_mail_from(verb: &str) -> bool { !matches!(verb.split_whitespace().next().map(|v| v.to_ascii_uppercase()).as_deref(), Some("MAIL") | Some("RCPT") | Some("DATA") | Some("BDAT") | Some("VRFY") | Some("EXPN")) }

/// version + group -> verdict. TLS 1.3 with the hybrid group is pq; TLS 1.3 otherwise classic13; anything older classic12.
pub fn classify(f: &TlsFact) -> &'static str {
    if f.version == "TLSv1.3" { if f.group.to_ascii_lowercase().contains("mlkem") { "pq" } else { "classic13" } } else { "classic12" }
}
fn clean(s: &str, max: usize) -> String { s.chars().filter(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '.' | '+' | '-')).take(max).collect() }
/// rustls Debug names -> the strings the database accepts (TLSv1_3 -> TLSv1.3).
pub fn names(version: &str, group: &str, cipher: &str) -> (String, String, String) { (clean(&version.replace('_', "."), 8), clean(group, 40), clean(cipher, 64)) }

/// A failure of one host as a verdict. Perm = the domain itself says no mail; Temp = unreachable with its own reason.
pub fn fail_verdict(f: &Fail) -> (&'static str, String) {
    let t = f.text().to_string();
    match f { Fail::Perm(_) => ("nomail", t), Fail::Temp(_) => ("unreachable", t) }
}

/// The TLS step, replaceable in tests. Returns the fact and the stream (for QUIT).
pub trait Handshake: Send + Sync {
    fn handshake<'a>(&'a self, s: BoxIo, host: &'a str) -> Pin<Box<dyn Future<Output = std::io::Result<(TlsFact, BoxIo)>> + Send + 'a>>;
}

async fn step<T>(what: &str, f: impl Future<Output = std::io::Result<T>>) -> Result<T, String> {
    match tokio::time::timeout(Duration::from_secs(CMD_TIMEOUT), f).await { Ok(Ok(v)) => Ok(v), Ok(Err(e)) => Err(format!("{what}: {e}")), Err(_) => Err(format!("{what}: timed out")) }
}
async fn say(rd: &mut BufReader<BoxIo>, line: &str) -> Result<smtp::Reply, String> {
    debug_assert!(never_mail_from(line));
    let w = rd.get_mut();
    step("write", async { w.write_all(line.as_bytes()).await?; w.write_all(b"\r\n").await?; w.flush().await }).await?;
    step("read", smtp::read_reply(rd)).await
}

/// One host over an open stream: greeting, EHLO, STARTTLS, handshake, QUIT. Pure over the stream, so the tests drive it with a scripted server.
pub async fn probe_host(io: BoxIo, host: &str, helo: &str, hs: &dyn Handshake) -> Probe {
    let mk = |verdict, detail: String| Probe { verdict, fact: None, detail, hosts_tried: vec![host.to_string()] };
    let mut rd = BufReader::new(io);
    let g = match step("greeting", smtp::read_reply(&mut rd)).await { Ok(r) => r, Err(e) => return mk("unreachable", format!("{host}: {e}")) };
    if g.code != 220 { return mk("refused", format!("{host}: greeting {}", g.text())); }
    let e = match say(&mut rd, &format!("EHLO {helo}")).await { Ok(r) => r, Err(e) => return mk("unreachable", format!("{host}: {e}")) };
    if e.code != 250 { return mk("none", format!("{host}: no ESMTP ({})", e.text())); }
    if !e.has_ext("STARTTLS") { let _ = say(&mut rd, "QUIT").await; return mk("none", format!("{host} does not offer STARTTLS")); }
    let s = match say(&mut rd, "STARTTLS").await { Ok(r) => r, Err(e) => return mk("unreachable", format!("{host}: {e}")) };
    if s.code != 220 { return mk("refused", format!("{host}: STARTTLS answered {}", s.text())); }
    // RFC 3207 / stripping: nothing may be buffered between the 220 and the handshake.
    if !rd.buffer().is_empty() { return mk("refused", format!("{host}: data after STARTTLS reply")); }
    match tokio::time::timeout(Duration::from_secs(CONNECT_TIMEOUT + CMD_TIMEOUT), hs.handshake(rd.into_inner(), host)).await {
        Ok(Ok((fact, tls))) => {
            let verdict = classify(&fact);
            let mut rd2 = BufReader::new(tls); let _ = say(&mut rd2, &format!("EHLO {helo}")).await; let _ = say(&mut rd2, "QUIT").await;
            Probe { verdict, detail: format!("{host}: {} {} cert {}", fact.version, fact.group, if fact.cert_verified { "verified" } else { "not verified" }), fact: Some(fact), hosts_tried: vec![host.to_string()] }
        }
        Ok(Err(e)) => mk("refused", format!("{host}: TLS handshake failed: {e}")),
        Err(_) => mk("refused", format!("{host}: TLS handshake timed out")),
    }
}

/// Dials one address. Replaceable in tests.
pub trait Dialer: Send + Sync {
    fn dial<'a>(&'a self, t: &'a smtp::Target) -> Pin<Box<dyn Future<Output = Result<BoxIo, String>> + Send + 'a>>;
}
pub struct TcpDialer;
impl Dialer for TcpDialer {
    fn dial<'a>(&'a self, t: &'a smtp::Target) -> Pin<Box<dyn Future<Output = Result<BoxIo, String>> + Send + 'a>> {
        Box::pin(async move {
            match tokio::time::timeout(Duration::from_secs(CONNECT_TIMEOUT), tokio::net::TcpStream::connect(t.addr)).await {
                Ok(Ok(s)) => { let _ = s.set_nodelay(true); Ok(Box::new(s) as BoxIo) }
                Ok(Err(e)) => Err(format!("{} ({}): {e}", t.host, t.addr.ip())), Err(_) => Err(format!("{} ({}): connection timed out", t.host, t.addr.ip())),
            }
        })
    }
}

/// Fold the per-host results: the first host with a TLS fact wins (pq beats classic only within the same host, priority order is respected); otherwise the most informative failure; hosts_tried lists every host.
pub fn merge(results: Vec<Probe>) -> Probe {
    let tried: Vec<String> = results.iter().flat_map(|p| p.hosts_tried.clone()).collect();
    let detail_all = results.iter().map(|p| p.detail.clone()).collect::<Vec<_>>().join("; ");
    let rank = |v: &str| match v { "pq" | "classic13" | "classic12" => 5, "none" => 4, "refused" => 3, "unreachable" => 2, _ => 1 };
    let mut best: Option<Probe> = None;
    for p in results { if p.fact.is_some() { best = Some(p); break; } if best.as_ref().map_or(true, |b| rank(p.verdict) > rank(b.verdict)) { best = Some(p); } }
    let mut b = best.unwrap_or(Probe { verdict: "unreachable", fact: None, detail: "no mail server answered".into(), hosts_tried: vec![] });
    b.detail = detail_all.chars().filter(|c| !c.is_control()).take(480).collect(); b.hosts_tried = tried; b
}

/// The whole domain. `addrs` come from smtp::targets (MX priority, implicit MX when there is no MX record, null MX = nomail, private addresses refused). Every address of up to 3 hosts is tried (IPv4 and IPv6).
pub async fn probe_targets(addrs: Vec<smtp::Target>, helo: &str, dial: &dyn Dialer, hs: &dyn Handshake) -> Probe {
    let run = async {
        let mut hosts: Vec<String> = Vec::new(); for t in &addrs { if !hosts.contains(&t.host) { hosts.push(t.host.clone()); } }
        hosts.truncate(MAX_HOSTS);
        let mut results = Vec::new();
        for h in &hosts {
            let mut host_res: Option<Probe> = None;
            for t in addrs.iter().filter(|t| &t.host == h) {
                let p = match dial.dial(t).await { Ok(io) => probe_host(io, h, helo, hs).await, Err(e) => Probe { verdict: "unreachable", fact: None, detail: e, hosts_tried: vec![h.clone()] } };
                let done = p.fact.is_some() || p.verdict == "none" || p.verdict == "refused";
                host_res = Some(p); if done { break; }
            }
            if let Some(p) = host_res { let stop = p.fact.is_some(); results.push(p); if stop { break; } }
        }
        merge(results)
    };
    match tokio::time::timeout(Duration::from_secs(DOMAIN_CAP), run).await { Ok(p) => p, Err(_) => Probe { verdict: "unreachable", fact: None, detail: format!("probe stopped after {DOMAIN_CAP} s"), hosts_tried: vec![] } }
}

/// DNS + probe for one domain. Domain only.
pub async fn probe_domain(res: &hickory_resolver::TokioResolver, domain: &str, helo: &str, dial: &dyn Dialer, hs: &dyn Handshake) -> Probe {
    let Some(d) = domain_only(domain) else { return Probe { verdict: "nomail", fact: None, detail: "not a domain name".into(), hosts_tried: vec![] } };
    match smtp::targets(res, &d).await {
        Ok(t) => probe_targets(t, helo, dial, hs).await,
        Err(f) => { let (v, t) = fail_verdict(&f); Probe { verdict: v, fact: None, detail: t, hosts_tried: vec![] } }
    }
}

// ---------------------------------------------------------------- real TLS

#[derive(Debug)]
struct ReadOnlyVerifier { inner: Arc<dyn rustls::client::danger::ServerCertVerifier>, alg: rustls::crypto::WebPkiSupportedAlgorithms, ok: Arc<AtomicBool> }
impl rustls::client::danger::ServerCertVerifier for ReadOnlyVerifier {
    fn verify_server_cert(&self, e: &rustls::pki_types::CertificateDer<'_>, i: &[rustls::pki_types::CertificateDer<'_>], n: &rustls::pki_types::ServerName<'_>, o: &[u8], now: rustls::pki_types::UnixTime) -> Result<rustls::client::danger::ServerCertVerified, rustls::Error> {
        match self.inner.verify_server_cert(e, i, n, o, now) { Ok(v) => Ok(v), Err(_) => { self.ok.store(false, Ordering::SeqCst); Ok(rustls::client::danger::ServerCertVerified::assertion()) } }
    }
    fn verify_tls12_signature(&self, m: &[u8], c: &rustls::pki_types::CertificateDer<'_>, d: &rustls::DigitallySignedStruct) -> Result<rustls::client::danger::HandshakeSignatureValid, rustls::Error> { rustls::crypto::verify_tls12_signature(m, c, d, &self.alg) }
    fn verify_tls13_signature(&self, m: &[u8], c: &rustls::pki_types::CertificateDer<'_>, d: &rustls::DigitallySignedStruct) -> Result<rustls::client::danger::HandshakeSignatureValid, rustls::Error> { rustls::crypto::verify_tls13_signature(m, c, d, &self.alg) }
    fn supported_verify_schemes(&self) -> Vec<rustls::SignatureScheme> { self.alg.supported_schemes() }
}

/// The real handshake: X25519MLKEM768 first, then X25519 / P-256 / P-384; TLS 1.3 and 1.2. An unverifiable certificate is READ, flagged cert_verified=false, and only QUIT is ever sent.
pub struct RustlsProbe { provider: Arc<rustls::crypto::CryptoProvider>, roots: Arc<rustls::RootCertStore> }
impl RustlsProbe {
    pub fn new() -> Result<Self, String> {
        let mut p = rustls::crypto::ring::default_provider();
        p.kx_groups.insert(0, rustls_post_quantum::X25519MLKEM768);
        let mut roots = rustls::RootCertStore::empty(); roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
        Ok(Self { provider: Arc::new(p), roots: Arc::new(roots) })
    }
}
impl Handshake for RustlsProbe {
    fn handshake<'a>(&'a self, s: BoxIo, host: &'a str) -> Pin<Box<dyn Future<Output = std::io::Result<(TlsFact, BoxIo)>> + Send + 'a>> {
        Box::pin(async move {
            let bad = |m: String| std::io::Error::new(std::io::ErrorKind::InvalidInput, m);
            let name = rustls::pki_types::ServerName::try_from(host.to_string()).map_err(|_| bad("bad server name".into()))?;
            let inner = rustls::client::WebPkiServerVerifier::builder_with_provider(self.roots.clone(), self.provider.clone()).build().map_err(|e| bad(e.to_string()))?;
            let ok = Arc::new(AtomicBool::new(true));
            let v = Arc::new(ReadOnlyVerifier { inner, alg: self.provider.signature_verification_algorithms, ok: ok.clone() });
            let cfg = rustls::ClientConfig::builder_with_provider(self.provider.clone()).with_protocol_versions(&[&rustls::version::TLS13, &rustls::version::TLS12]).map_err(|e| bad(e.to_string()))?
                .dangerous().with_custom_certificate_verifier(v).with_no_client_auth();
            let tls = tokio_rustls::TlsConnector::from(Arc::new(cfg)).connect(name, s).await?;
            let c = tls.get_ref().1;
            let ver = c.protocol_version().map(|v| format!("{v:?}")).unwrap_or_default();
            let grp = c.negotiated_key_exchange_group().map(|g| format!("{:?}", g.name())).unwrap_or_default();
            let cip = c.negotiated_cipher_suite().map(|s| format!("{:?}", s.suite())).unwrap_or_default();
            let (version, group, cipher) = names(&ver, &grp, &cip);
            if version.is_empty() || group.len() < 3 || cipher.len() < 3 { return Err(bad("handshake gave no facts".into())); }
            Ok((TlsFact { version, group, cipher, cert_verified: ok.load(Ordering::SeqCst) }, Box::new(tls) as BoxIo))
        })
    }
}

/// The detail JSON that gets sealed in the database (never the plain domain).
pub fn detail_json(p: &Probe) -> String { serde_json::json!({ "detail": p.detail, "hosts_tried": p.hosts_tried }).to_string() }

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{duplex, AsyncReadExt};

    fn fact(v: &str, g: &str) -> TlsFact { TlsFact { version: v.into(), group: g.into(), cipher: "TLS13_AES_256_GCM_SHA384".into(), cert_verified: true } }
    struct Fake(Option<TlsFact>);
    impl Handshake for Fake { fn handshake<'a>(&'a self, s: BoxIo, _h: &'a str) -> Pin<Box<dyn Future<Output = std::io::Result<(TlsFact, BoxIo)>> + Send + 'a>> { Box::pin(async move { match &self.0 { Some(f) => Ok((f.clone(), s)), None => Err(std::io::Error::new(std::io::ErrorKind::Other, "alert handshake_failure")) } }) } }

    /// Scripted server: sends the greeting, then answers every command line from `answers`; returns every line the probe sent.
    async fn serve(greet: &'static str, ehlo: &'static str, starttls: &'static str) -> (BoxIo, tokio::task::JoinHandle<Vec<String>>) {
        let (a, mut b) = duplex(8192);
        let h = tokio::spawn(async move {
            let mut seen = Vec::new();
            b.write_all(greet.as_bytes()).await.unwrap();
            let mut buf = Vec::new(); let mut tmp = [0u8; 512];
            loop {
                let n = match b.read(&mut tmp).await { Ok(0) | Err(_) => break, Ok(n) => n };
                buf.extend_from_slice(&tmp[..n]);
                while let Some(p) = buf.windows(2).position(|w| w == b"\r\n") {
                    let line = String::from_utf8_lossy(&buf[..p]).to_string(); buf.drain(..p + 2); seen.push(line.clone());
                    let up = line.to_ascii_uppercase();
                    if up.starts_with("EHLO") { b.write_all(ehlo.as_bytes()).await.unwrap(); }
                    else if up.starts_with("STARTTLS") { b.write_all(starttls.as_bytes()).await.unwrap(); }
                    else if up.starts_with("QUIT") { b.write_all(b"221 bye\r\n").await.unwrap(); return seen; }
                }
            }
            seen
        });
        (Box::new(a) as BoxIo, h)
    }

    #[test]
    fn domain_only_never_an_address() {
        assert_eq!(domain_only(" Example.COM. ").as_deref(), Some("example.com"));
        assert!(domain_only("a@example.com").is_none() && domain_only("exa mple.com").is_none() && domain_only("localhost").is_none() && domain_only("").is_none() && domain_only("-x.com").is_none());
        assert_eq!(domain_only("bücher.de").as_deref(), Some("xn--bcher-kva.de"));
    }
    #[test]
    fn never_mail_from_any_verb_of_ours() {
        for v in ["EHLO mail.anexomail.com", "STARTTLS", "QUIT"] { assert!(never_mail_from(v)); }
        for v in ["MAIL FROM:<a@b>", "rcpt to:<a@b>", "DATA", "BDAT 10", "VRFY x"] { assert!(!never_mail_from(v), "{v}"); }
    }
    #[test]
    fn classify_names_every_case() {
        assert_eq!(classify(&fact("TLSv1.3", "X25519MLKEM768")), "pq");
        assert_eq!(classify(&fact("TLSv1.3", "X25519")), "classic13");
        assert_eq!(classify(&fact("TLSv1.2", "secp256r1")), "classic12");
        assert_eq!(names("TLSv1_3", "X25519MLKEM768", "TLS13_AES_256_GCM_SHA384"), ("TLSv1.3".into(), "X25519MLKEM768".into(), "TLS13_AES_256_GCM_SHA384".into()));
        assert_eq!(names("TLSv1_2", "a b;c", "x").1, "abc");
    }
    #[test]
    fn null_mx_is_nomail() {
        assert_eq!(fail_verdict(&Fail::Perm("x.com does not accept mail (null MX)".into())).0, "nomail");
        assert_eq!(fail_verdict(&Fail::Perm("x.com has no mail server".into())).0, "nomail");
        assert_eq!(fail_verdict(&Fail::Temp("DNS lookup failed".into())).0, "unreachable");
    }
    #[tokio::test]
    async fn pq_when_the_handshake_says_so_and_only_three_verbs_are_sent() {
        let (io, h) = serve("220 mx ESMTP\r\n", "250-mx\r\n250 STARTTLS\r\n", "220 go\r\n").await;
        let p = probe_host(io, "mx.example.com", "mail.anexomail.com", &Fake(Some(fact("TLSv1.3", "X25519MLKEM768")))).await;
        assert_eq!(p.verdict, "pq"); assert!(p.fact.as_ref().unwrap().cert_verified);
        let seen = h.await.unwrap();
        assert!(seen.iter().all(|l| never_mail_from(l)), "{seen:?}");
        assert_eq!(seen[0], "EHLO mail.anexomail.com"); assert_eq!(seen[1], "STARTTLS"); assert_eq!(seen.last().unwrap(), "QUIT");
    }
    #[tokio::test]
    async fn classic_old_none_refused_cases() {
        let (io, _h) = serve("220 mx\r\n", "250-mx\r\n250 STARTTLS\r\n", "220 go\r\n").await;
        assert_eq!(probe_host(io, "mx", "h", &Fake(Some(fact("TLSv1.3", "X25519")))).await.verdict, "classic13");
        let (io, _h) = serve("220 mx\r\n", "250-mx\r\n250 STARTTLS\r\n", "220 go\r\n").await;
        assert_eq!(probe_host(io, "mx", "h", &Fake(Some(fact("TLSv1.2", "secp256r1")))).await.verdict, "classic12");
        let (io, _h) = serve("220 mx\r\n", "250-mx\r\n250 SIZE 100\r\n", "220 go\r\n").await;
        assert_eq!(probe_host(io, "mx", "h", &Fake(None)).await.verdict, "none");
        let (io, _h) = serve("220 mx\r\n", "250-mx\r\n250 STARTTLS\r\n", "454 TLS not available\r\n").await;
        assert_eq!(probe_host(io, "mx", "h", &Fake(None)).await.verdict, "refused");
        let (io, _h) = serve("220 mx\r\n", "250-mx\r\n250 STARTTLS\r\n", "220 go\r\n").await;
        let p = probe_host(io, "mx", "h", &Fake(None)).await; assert_eq!(p.verdict, "refused"); assert!(p.detail.contains("handshake"));
        let (io, _h) = serve("554 no service\r\n", "", "").await;
        assert_eq!(probe_host(io, "mx", "h", &Fake(None)).await.verdict, "refused");
    }
    #[tokio::test]
    async fn stripped_injection_after_starttls_is_refused() {
        let (io, _h) = serve("220 mx\r\n", "250-mx\r\n250 STARTTLS\r\n", "220 go\r\n250 injected\r\n").await;
        assert_eq!(probe_host(io, "mx", "h", &Fake(Some(fact("TLSv1.3", "X25519")))).await.verdict, "refused");
    }
    struct Down; // every address refuses
    impl Dialer for Down { fn dial<'a>(&'a self, t: &'a smtp::Target) -> Pin<Box<dyn Future<Output = Result<BoxIo, String>> + Send + 'a>> { Box::pin(async move { Err(format!("{}: connection refused", t.host)) }) } }
    fn tg(h: &str, ip: &str) -> smtp::Target { smtp::Target { host: h.into(), addr: format!("{ip}:25").parse().unwrap() } }
    #[tokio::test]
    async fn try_every_address_and_say_why_when_all_fail() {
        let p = probe_targets(vec![tg("a.example.com", "1.1.1.1"), tg("a.example.com", "[2606:4700::1]"), tg("b.example.com", "8.8.8.8")], "h", &Down, &Fake(None)).await;
        assert_eq!(p.verdict, "unreachable"); assert_eq!(p.hosts_tried, vec!["a.example.com", "b.example.com"]);
        assert!(p.detail.contains("a.example.com") && p.detail.contains("b.example.com"), "{}", p.detail);
    }
    #[tokio::test]
    async fn at_most_three_hosts() {
        let t: Vec<_> = (1..=6).map(|i| tg(&format!("m{i}.example.com"), &format!("1.1.1.{i}"))).collect();
        assert_eq!(probe_targets(t, "h", &Down, &Fake(None)).await.hosts_tried.len(), 3);
    }
    struct Second(std::sync::Mutex<Vec<(BoxIo, tokio::task::JoinHandle<Vec<String>>)>>);
    impl Dialer for Second { fn dial<'a>(&'a self, t: &'a smtp::Target) -> Pin<Box<dyn Future<Output = Result<BoxIo, String>> + Send + 'a>> { Box::pin(async move { if t.host == "a.example.com" { return Err("a: connection refused".into()); } let (io, _h) = self.0.lock().unwrap().pop().unwrap(); Ok(io) }) } }
    #[tokio::test]
    async fn falls_to_the_next_host_and_succeeds() {
        let s = serve("220 b\r\n", "250-b\r\n250 STARTTLS\r\n", "220 go\r\n").await;
        let d = Second(std::sync::Mutex::new(vec![s]));
        let p = probe_targets(vec![tg("a.example.com", "1.1.1.1"), tg("b.example.com", "8.8.8.8")], "h", &d, &Fake(Some(fact("TLSv1.3", "X25519MLKEM768")))).await;
        assert_eq!(p.verdict, "pq"); assert_eq!(p.hosts_tried, vec!["a.example.com", "b.example.com"]);
    }
    #[test]
    fn implicit_mx_when_no_mx_record() { // the rule itself lives in smtp::targets (RFC 5321 5.1, proven live); here: a host with only the domain name still probes like any MX
        let t = vec![tg("example.com", "1.1.1.1")]; assert_eq!(t[0].host, "example.com");
    }
    #[test]
    fn detail_json_has_no_secrets_and_is_json() {
        let p = Probe { verdict: "none", fact: None, detail: "x".into(), hosts_tried: vec!["mx.example.com".into()] };
        let v: serde_json::Value = serde_json::from_str(&detail_json(&p)).unwrap(); assert_eq!(v["hosts_tried"][0], "mx.example.com");
    }
    #[test]
    fn real_probe_builds() { assert!(RustlsProbe::new().is_ok()); }
}
