//! Q1d (founder mailbox): the outgoing SMTP client. Technology: Rust + Tokio, tokio-rustls (TLS 1.3 only, X25519MLKEM768 first, ring ciphers), hickory-resolver (MX lookup, pure Rust).
//! INHERITABLE BY AWAM (docs/claude/AWAM-INHERITS-FOUNDER-TECH-LAW-13NOV.md): no database, no founder names; the session logic is generic over any async stream.
//! Rules this file enforces: (1) NO plain-text delivery: STARTTLS must be offered and must succeed, with the certificate checked against the MX host name (webpki roots); a remote that cannot do it is a
//! TEMPORARY failure, the mail waits and the founder sees why - it is never sent in the clear. (2) STARTTLS stripping / response injection: the read buffer must be empty before the TLS handshake.
//! (3) Replies are bounded (line 1000 bytes, 100 lines, timeouts on every step). (4) MX targets that resolve to private / loopback / link-local / CGNAT addresses are never contacted (no SSRF through a
//! recipient's DNS). (5) A null MX (RFC 7505) is a permanent failure. (6) Relay mode (FMAIL_SMTP_RELAY, a loopback Postfix) is the way out when the host provider blocks outbound port 25.
//! NOT HERE YET (registered open gaps in TECH-LAW-GATE.json): MTA-STS (RFC 8461), DANE (RFC 7672), TLS-RPT, and an unverified-certificate "opportunistic" mode.
use std::{future::Future, net::IpAddr, pin::Pin, sync::Arc, time::Duration};
use tokio::io::{AsyncBufReadExt, AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt, BufReader};

pub trait Io: AsyncRead + AsyncWrite + Unpin + Send {}
impl<T: AsyncRead + AsyncWrite + Unpin + Send> Io for T {}
pub type BoxIo = Box<dyn Io>;

#[derive(Debug, Clone, PartialEq)]
pub enum Fail { Temp(String), Perm(String) }
impl Fail { pub fn text(&self) -> &str { match self { Fail::Temp(s) | Fail::Perm(s) => s } } pub fn is_perm(&self) -> bool { matches!(self, Fail::Perm(_)) } }

#[derive(Debug, Clone, PartialEq)]
pub struct Reply { pub code: u16, pub lines: Vec<String> }
impl Reply {
    pub fn text(&self) -> String { let t = self.lines.join(" "); let t: String = t.chars().filter(|c| !c.is_control()).take(240).collect(); format!("{} {}", self.code, t) }
    pub fn has_ext(&self, name: &str) -> bool { self.lines.iter().skip(1).any(|l| l.split_whitespace().next().map_or(false, |w| w.eq_ignore_ascii_case(name))) }
    pub fn size_limit(&self) -> Option<u64> { self.lines.iter().skip(1).find_map(|l| { let mut w = l.split_whitespace(); if w.next()?.eq_ignore_ascii_case("SIZE") { w.next()?.parse().ok() } else { None } }) }
    fn fail(&self) -> Fail { if self.code >= 500 { Fail::Perm(self.text()) } else { Fail::Temp(self.text()) } }
}

const LINE_MAX: usize = 1000;
const LINES_MAX: usize = 100;
async fn timed<T>(secs: u64, what: &str, f: impl Future<Output = std::io::Result<T>>) -> Result<T, Fail> {
    match tokio::time::timeout(Duration::from_secs(secs), f).await { Ok(Ok(v)) => Ok(v), Ok(Err(e)) => Err(Fail::Temp(format!("{what}: {e}"))), Err(_) => Err(Fail::Temp(format!("{what}: timed out"))) }
}
/// One (possibly multi-line) SMTP reply, bounded.
pub async fn read_reply<R: AsyncBufReadExt + Unpin>(r: &mut R) -> std::io::Result<Reply> {
    let mut lines = Vec::new(); let mut code = 0u16;
    loop {
        let mut buf = Vec::new();
        let n = (&mut *r).take(LINE_MAX as u64 + 2).read_until(b'\n', &mut buf).await?;
        if n == 0 { return Err(std::io::Error::new(std::io::ErrorKind::UnexpectedEof, "connection closed")); }
        if !buf.ends_with(b"\n") { return Err(std::io::Error::new(std::io::ErrorKind::InvalidData, "reply line too long")); }
        let line = String::from_utf8_lossy(&buf).trim_end_matches(['\r', '\n']).to_string();
        if line.len() < 3 || !line.as_bytes()[..3].iter().all(|b| b.is_ascii_digit()) { return Err(std::io::Error::new(std::io::ErrorKind::InvalidData, "not an SMTP reply")); }
        let c: u16 = line[..3].parse().unwrap_or(0);
        if lines.is_empty() { code = c; } else if c != code { return Err(std::io::Error::new(std::io::ErrorKind::InvalidData, "reply code changed inside a reply")); }
        let more = line.as_bytes().get(3) == Some(&b'-');
        lines.push(line.get(4..).unwrap_or("").to_string());
        if lines.len() > LINES_MAX { return Err(std::io::Error::new(std::io::ErrorKind::InvalidData, "reply too long")); }
        if !more { return Ok(Reply { code, lines }); }
    }
}

/// Upgrades a plain stream to TLS. Returns the new stream and the label stored in the outbox (`tls13` or `tls13_pq`).
pub trait Upgrade: Send + Sync {
    fn upgrade<'a>(&'a self, s: BoxIo, host: &'a str) -> Pin<Box<dyn Future<Output = std::io::Result<(BoxIo, &'static str)>> + Send + 'a>>;
}

#[derive(Debug, Clone, PartialEq)]
pub struct Rcpt { pub addr: String, pub result: Result<String, Fail> }
#[derive(Debug, Clone, PartialEq)]
pub struct Outcome { pub rcpts: Vec<Rcpt>, pub data: Result<String, Fail>, pub tls: &'static str }
impl Outcome {
    /// Delivered = the DATA was accepted and at least one recipient took it.
    pub fn delivered(&self) -> bool { self.data.is_ok() && self.rcpts.iter().any(|r| r.result.is_ok()) }
    pub fn accepted(&self) -> usize { self.rcpts.iter().filter(|r| r.result.is_ok()).count() }
    pub fn summary(&self) -> String {
        let bad: Vec<String> = self.rcpts.iter().filter_map(|r| r.result.as_ref().err().map(|e| format!("{}: {}", r.addr, e.text()))).collect();
        let head = match &self.data { Ok(t) => t.clone(), Err(e) => e.text().to_string() };
        let s = if bad.is_empty() { head } else { format!("{head} | not delivered to {} of {}: {}", bad.len(), self.rcpts.len(), bad.join("; ")) };
        s.chars().take(290).collect()
    }
}

pub struct Session<'a> { pub helo: &'a str, pub require_tls: bool, pub upgrader: &'a dyn Upgrade, pub host: &'a str }

struct Conn { rd: BufReader<BoxIo> }
impl Conn {
    async fn send(&mut self, line: &str, secs: u64) -> Result<(), Fail> {
        let w = self.rd.get_mut();
        timed(secs, "write", async { w.write_all(line.as_bytes()).await?; w.write_all(b"\r\n").await?; w.flush().await }).await
    }
    async fn reply(&mut self, secs: u64) -> Result<Reply, Fail> { timed(secs, "read", read_reply(&mut self.rd)).await }
    async fn cmd(&mut self, line: &str, secs: u64) -> Result<Reply, Fail> { self.send(line, secs).await?; self.reply(secs).await }
}
fn param_ok(s: &str) -> bool { !s.is_empty() && s.len() <= 320 && s.bytes().all(|b| b.is_ascii_graphic() && !matches!(b, b'<' | b'>')) }

/// Run one delivery on an already-connected stream. `from` and `rcpts` are normalised addresses; `data` is the DATA payload from `fmail_mime::data_payload`.
pub async fn deliver(io: BoxIo, s: &Session<'_>, from: &str, rcpts: &[String], data: &[u8]) -> Result<Outcome, Fail> {
    if !param_ok(from) || rcpts.is_empty() || rcpts.iter().any(|r| !param_ok(r)) { return Err(Fail::Perm("refused: unsafe envelope address".into())); }
    if !s.helo.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'-') || s.helo.is_empty() { return Err(Fail::Perm("refused: bad HELO name".into())); }
    let mut c = Conn { rd: BufReader::new(io) };
    let greet = c.reply(120).await?;
    if greet.code != 220 { return Err(greet.fail()); }
    let mut ehlo = c.cmd(&format!("EHLO {}", s.helo), 120).await?;
    if ehlo.code != 250 { return Err(ehlo.fail()); }
    let mut tls = "none";
    if ehlo.has_ext("STARTTLS") {
        let r = c.cmd("STARTTLS", 120).await?;
        if r.code != 220 { return Err(Fail::Temp(format!("STARTTLS refused: {}", r.text()))); }
        // response injection (CVE-2011-0411 class): nothing may sit in the read buffer when the handshake starts
        if !c.rd.buffer().is_empty() { return Err(Fail::Temp("refused: data arrived before the TLS handshake (possible STARTTLS injection)".into())); }
        let plain = c.rd.into_inner();
        match tokio::time::timeout(Duration::from_secs(60), s.upgrader.upgrade(plain, s.host)).await {
            Ok(Ok((enc, label))) => { c = Conn { rd: BufReader::new(enc) }; tls = label; }
            Ok(Err(e)) => return Err(Fail::Temp(format!("TLS handshake with {} failed: {e}", s.host))),
            Err(_) => return Err(Fail::Temp(format!("TLS handshake with {} timed out", s.host))),
        }
        ehlo = c.cmd(&format!("EHLO {}", s.helo), 120).await?;
        if ehlo.code != 250 { return Err(ehlo.fail()); }
    } else if s.require_tls {
        return Err(Fail::Temp(format!("{} does not offer STARTTLS; the mail is not sent in the clear and will be retried", s.host)));
    }
    if let Some(max) = ehlo.size_limit() { if max > 0 && (data.len() as u64) > max { return Err(Fail::Perm(format!("message ({} bytes) is bigger than the remote limit ({max})", data.len()))); } }
    let r = c.cmd(&format!("MAIL FROM:<{from}> SIZE={}", data.len()), 300).await?;
    if r.code != 250 { let _ = c.send("QUIT", 10).await; return Err(r.fail()); }
    let mut out: Vec<Rcpt> = Vec::new();
    for a in rcpts {
        let r = c.cmd(&format!("RCPT TO:<{a}>"), 300).await?;
        out.push(Rcpt { addr: a.clone(), result: if r.code == 250 || r.code == 251 { Ok(r.text()) } else { Err(r.fail()) } });
    }
    if !out.iter().any(|r| r.result.is_ok()) {
        let _ = c.cmd("RSET", 30).await; let _ = c.send("QUIT", 10).await;
        let data = Err(out.iter().find_map(|r| r.result.as_ref().err().cloned()).unwrap_or(Fail::Perm("no recipient accepted".into())));
        return Ok(Outcome { rcpts: out, data, tls });
    }
    let r = c.cmd("DATA", 300).await?;
    if r.code != 354 { let _ = c.send("QUIT", 10).await; return Err(r.fail()); }
    timed(600, "send data", async { let w = c.rd.get_mut(); w.write_all(data).await?; w.flush().await }).await?;
    let fin = c.reply(600).await?;
    let _ = c.send("QUIT", 10).await;
    Ok(Outcome { rcpts: out, data: if fin.code == 250 { Ok(fin.text()) } else { Err(fin.fail()) }, tls })
}

// ---------------------------------------------------------------- finding the server

/// Addresses we never connect to for a recipient's domain.
pub fn is_public(ip: &IpAddr) -> bool {
    match ip {
        IpAddr::V4(v) => { let o = v.octets(); !(v.is_loopback() || v.is_private() || v.is_link_local() || v.is_unspecified() || v.is_broadcast() || v.is_multicast() || v.is_documentation()
            || (o[0] == 100 && (o[1] & 0xc0) == 64) || o[0] == 0 || (o[0] == 198 && (o[1] & 0xfe) == 18) || o[0] >= 240) }
        IpAddr::V6(v) => { let s = v.segments(); !(v.is_loopback() || v.is_unspecified() || v.is_multicast() || (s[0] & 0xfe00) == 0xfc00 || (s[0] & 0xffc0) == 0xfe80
            || v.to_ipv4_mapped().map_or(false, |m| !is_public(&IpAddr::V4(m))) || (s[0] == 0x2001 && s[1] == 0x0db8)) }
    }
}
/// MX hosts by preference (lowest first), equal preferences shuffled by the caller. Pure so it is tested.
pub fn order_mx(mut v: Vec<(u16, String)>) -> Vec<String> { v.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.1.cmp(&b.1))); v.into_iter().map(|x| x.1).collect() }

#[derive(Debug, Clone)]
pub struct Target { pub host: String, pub addr: std::net::SocketAddr }
pub enum Route { Mx, Relay(std::net::SocketAddr) }

/// Resolve where to deliver for `domain`. MX records first; no MX at all -> the domain's own address (RFC 5321 5.1); a null MX -> permanent failure.
pub async fn targets(res: &hickory_resolver::TokioResolver, domain: &str) -> Result<Vec<Target>, Fail> {
    let mut mx: Vec<(u16, String)> = Vec::new(); let mut none = false;
    match res.mx_lookup(format!("{domain}.")).await {
        Ok(l) => { for m in l.iter() { let h = m.exchange().to_utf8().trim_end_matches('.').to_ascii_lowercase(); if h.is_empty() { return Err(Fail::Perm(format!("{domain} does not accept mail (null MX)"))); } mx.push((m.preference(), h)); } if mx.is_empty() { none = true; } }
        Err(e) => { if e.is_no_records_found() { none = true; } else { return Err(Fail::Temp(format!("DNS lookup for {domain} failed: {e}"))); } }
    }
    let hosts = if none { vec![domain.to_string()] } else { order_mx(mx) };
    let mut out = Vec::new(); let mut private = 0;
    for h in hosts.iter().take(5) {
        match res.lookup_ip(format!("{h}.")).await {
            Ok(ips) => for ip in ips.iter() { if is_public(&ip) { out.push(Target { host: h.clone(), addr: std::net::SocketAddr::new(ip, 25) }); } else { private += 1; } },
            Err(_) => continue,
        }
    }
    if out.is_empty() { return Err(if private > 0 { Fail::Perm(format!("{domain} points to a private address; not contacted")) } else if none { Fail::Perm(format!("{domain} has no mail server")) } else { Fail::Temp(format!("no address found for the mail servers of {domain}")) }); }
    out.truncate(6); Ok(out)
}

// ---------------------------------------------------------------- real TLS

pub struct RustlsUpgrade { cfg: Arc<rustls::ClientConfig> }
impl RustlsUpgrade {
    /// TLS 1.3 only. Key exchange: X25519MLKEM768 first (post-quantum hybrid), then X25519 / P-256. Ciphers: AES-256-GCM first, then ChaCha20 and AES-128 so that strangers' servers still work
    /// (the AES-256-only rule is for OUR listeners). Certificates are verified against the MX host name with the webpki roots.
    pub fn new() -> Result<Self, String> {
        use rustls::crypto::ring as rp;
        let mut p = rp::default_provider();
        p.cipher_suites = vec![rp::cipher_suite::TLS13_AES_256_GCM_SHA384, rp::cipher_suite::TLS13_CHACHA20_POLY1305_SHA256, rp::cipher_suite::TLS13_AES_128_GCM_SHA256];
        p.kx_groups.insert(0, rustls_post_quantum::X25519MLKEM768);
        let mut roots = rustls::RootCertStore::empty(); roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
        let cfg = rustls::ClientConfig::builder_with_provider(Arc::new(p)).with_protocol_versions(&[&rustls::version::TLS13]).map_err(|e| e.to_string())?.with_root_certificates(roots).with_no_client_auth();
        Ok(Self { cfg: Arc::new(cfg) })
    }
}
impl Upgrade for RustlsUpgrade {
    fn upgrade<'a>(&'a self, s: BoxIo, host: &'a str) -> Pin<Box<dyn Future<Output = std::io::Result<(BoxIo, &'static str)>> + Send + 'a>> {
        Box::pin(async move {
            let name = rustls::pki_types::ServerName::try_from(host.to_string()).map_err(|_| std::io::Error::new(std::io::ErrorKind::InvalidInput, "bad server name"))?;
            let tls = tokio_rustls::TlsConnector::from(self.cfg.clone()).connect(name, s).await?;
            let pq = tls.get_ref().1.negotiated_key_exchange_group().map_or(false, |g| format!("{:?}", g.name()).contains("MLKEM"));
            Ok((Box::new(tls) as BoxIo, if pq { "tls13_pq" } else { "tls13" }))
        })
    }
}

/// Connect (TCP, 15 s) to the first reachable target.
pub async fn connect(ts: &[Target]) -> Result<(BoxIo, Target), Fail> {
    let mut last = String::from("no server reachable");
    for t in ts {
        match tokio::time::timeout(Duration::from_secs(15), tokio::net::TcpStream::connect(t.addr)).await {
            Ok(Ok(s)) => { let _ = s.set_nodelay(true); return Ok((Box::new(s) as BoxIo, t.clone())); }
            Ok(Err(e)) => last = format!("{}: {e}", t.host), Err(_) => last = format!("{}: connection timed out", t.host),
        }
    }
    Err(Fail::Temp(last))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::duplex;

    struct NoTls; // test double: the "upgrade" returns the same stream (the scripted server does not speak TLS) and reports tls13
    impl Upgrade for NoTls { fn upgrade<'a>(&'a self, s: BoxIo, _h: &'a str) -> Pin<Box<dyn Future<Output = std::io::Result<(BoxIo, &'static str)>> + Send + 'a>> { Box::pin(async move { Ok((s, "tls13")) }) } }
    struct FailTls;
    impl Upgrade for FailTls { fn upgrade<'a>(&'a self, _s: BoxIo, _h: &'a str) -> Pin<Box<dyn Future<Output = std::io::Result<(BoxIo, &'static str)>> + Send + 'a>> { Box::pin(async move { Err(std::io::Error::new(std::io::ErrorKind::Other, "certificate not valid for mx.example.org")) }) } }

    /// Scripted server: greeting, then for each client line the matching reply. DATA collects up to CRLF.CRLF and returns what it saw.
    async fn serve(mut s: tokio::io::DuplexStream, greet: &str, replies: Vec<(&'static str, &'static str)>, inject_after_starttls: bool) -> (Vec<String>, Vec<u8>) {
        let mut seen = Vec::new(); let mut data = Vec::new();
        s.write_all(greet.as_bytes()).await.unwrap();
        let mut rd = BufReader::new(s);
        let mut i = 0;
        loop {
            let mut line = String::new();
            if rd.read_line(&mut line).await.unwrap() == 0 { break; }
            let l = line.trim_end().to_string(); seen.push(l.clone());
            if l == "QUIT" { break; }
            let rep = replies.iter().skip(i).find(|(p, _)| l.starts_with(p)).map(|x| x.1).unwrap_or("500 unexpected\r\n"); i += 1;
            let w = rd.get_mut();
            w.write_all(rep.as_bytes()).await.unwrap();
            if inject_after_starttls && l == "STARTTLS" { w.write_all(b"250 INJECTED\r\n").await.unwrap(); }
            if l == "DATA" && rep.starts_with("354") { loop { let mut b = Vec::new(); let n = rd.read_until(b'\n', &mut b).await.unwrap(); data.extend_from_slice(&b); if n == 0 || data.ends_with(b"\r\n.\r\n") { break; } } rd.get_mut().write_all(b"250 2.0.0 queued as ABC\r\n").await.unwrap(); }
        }
        (seen, data)
    }
    const EHLO_TLS: &str = "250-mx.example.org\r\n250-SIZE 1000000\r\n250-STARTTLS\r\n250 8BITMIME\r\n";
    const EHLO_PLAIN: &str = "250-mx.example.org\r\n250 SIZE 1000000\r\n";
    fn sess<'a>(u: &'a dyn Upgrade, req: bool) -> Session<'a> { Session { helo: "mail.anexomail.com", require_tls: req, upgrader: u, host: "mx.example.org" } }

    #[tokio::test] async fn happy_path_with_starttls_and_dot_stuffing() {
        let (c, s) = duplex(1 << 16);
        let srv = tokio::spawn(serve(s, "220 hi\r\n", vec![("EHLO", EHLO_TLS), ("STARTTLS", "220 go\r\n"), ("EHLO", EHLO_TLS), ("MAIL FROM", "250 ok\r\n"), ("RCPT TO:<a@x.com>", "250 ok\r\n"), ("RCPT TO:<b@x.com>", "550 5.1.1 no such user\r\n"), ("DATA", "354 go\r\n")], false));
        let payload = crate::fmail_mime::data_payload(b"Subject: s\r\n\r\n.dot\r\nbody\r\n");
        let o = deliver(Box::new(c), &sess(&NoTls, true), "me@anexomail.com", &["a@x.com".into(), "b@x.com".into()], &payload).await.unwrap();
        assert!(o.delivered()); assert_eq!(o.accepted(), 1); assert_eq!(o.tls, "tls13"); assert!(o.rcpts[1].result.as_ref().unwrap_err().is_perm());
        assert!(o.summary().contains("b@x.com") && o.summary().contains("queued as ABC"));
        let (seen, data) = srv.await.unwrap();
        assert_eq!(seen[0], "EHLO mail.anexomail.com"); assert_eq!(seen[1], "STARTTLS"); assert!(seen[3].starts_with("MAIL FROM:<me@anexomail.com> SIZE=")); assert!(String::from_utf8_lossy(&data).contains("\r\n..dot\r\n"));
    }
    #[tokio::test] async fn no_starttls_is_never_sent_in_clear() {
        let (c, s) = duplex(1 << 16);
        let srv = tokio::spawn(serve(s, "220 hi\r\n", vec![("EHLO", EHLO_PLAIN)], false));
        let e = deliver(Box::new(c), &sess(&NoTls, true), "me@anexomail.com", &["a@x.com".into()], b".\r\n").await.unwrap_err();
        assert!(matches!(e, Fail::Temp(ref m) if m.contains("not sent in the clear")), "{e:?}");
        let (seen, _) = srv.await.unwrap(); assert!(!seen.iter().any(|l| l.starts_with("MAIL FROM") || l == "DATA"), "{seen:?}");
    }
    #[tokio::test] async fn plain_relay_mode_is_allowed_when_tls_is_not_required() {
        let (c, s) = duplex(1 << 16);
        let srv = tokio::spawn(serve(s, "220 hi\r\n", vec![("EHLO", EHLO_PLAIN), ("MAIL", "250 ok\r\n"), ("RCPT", "250 ok\r\n"), ("DATA", "354 go\r\n")], false));
        let o = deliver(Box::new(c), &sess(&NoTls, false), "me@anexomail.com", &["a@x.com".into()], b"x\r\n.\r\n").await.unwrap(); assert!(o.delivered() && o.tls == "none"); srv.await.unwrap();
    }
    #[tokio::test] async fn starttls_injection_is_refused() {
        let (c, s) = duplex(1 << 16);
        let srv = tokio::spawn(serve(s, "220 hi\r\n", vec![("EHLO", EHLO_TLS), ("STARTTLS", "220 go\r\n")], true));
        let e = deliver(Box::new(c), &sess(&NoTls, true), "me@anexomail.com", &["a@x.com".into()], b".\r\n").await.unwrap_err();
        assert!(matches!(e, Fail::Temp(ref m) if m.contains("injection")), "{e:?}"); drop(srv);
    }
    #[tokio::test] async fn failed_handshake_is_temporary_and_says_why() {
        let (c, s) = duplex(1 << 16);
        let srv = tokio::spawn(serve(s, "220 hi\r\n", vec![("EHLO", EHLO_TLS), ("STARTTLS", "220 go\r\n")], false));
        let e = deliver(Box::new(c), &sess(&FailTls, true), "me@anexomail.com", &["a@x.com".into()], b".\r\n").await.unwrap_err();
        assert!(matches!(e, Fail::Temp(ref m) if m.contains("certificate not valid")), "{e:?}"); drop(srv);
    }
    #[tokio::test] async fn greylist_and_permanent_codes_are_told_apart() {
        let (c, s) = duplex(1 << 16);
        tokio::spawn(serve(s, "220 hi\r\n", vec![("EHLO", EHLO_TLS), ("STARTTLS", "220 go\r\n"), ("EHLO", EHLO_TLS), ("MAIL", "250 ok\r\n"), ("RCPT", "451 4.7.1 greylisted, try later\r\n"), ("RSET", "250 ok\r\n")], false));
        let o = deliver(Box::new(c), &sess(&NoTls, true), "me@anexomail.com", &["a@x.com".into()], b".\r\n").await.unwrap();
        assert!(!o.delivered()); assert!(matches!(o.data, Err(Fail::Temp(_))));
        let (c, s) = duplex(1 << 16);
        tokio::spawn(serve(s, "554 5.7.1 go away\r\n", vec![], false));
        assert!(matches!(deliver(Box::new(c), &sess(&NoTls, true), "me@anexomail.com", &["a@x.com".into()], b".\r\n").await, Err(Fail::Perm(_))));
    }
    #[tokio::test] async fn remote_size_limit_and_unsafe_envelope() {
        let (c, s) = duplex(1 << 16);
        tokio::spawn(serve(s, "220 hi\r\n", vec![("EHLO", "250-mx\r\n250-SIZE 10\r\n250 STARTTLS\r\n"), ("STARTTLS", "220 go\r\n"), ("EHLO", "250-mx\r\n250 SIZE 10\r\n")], false));
        assert!(matches!(deliver(Box::new(c), &sess(&NoTls, true), "me@anexomail.com", &["a@x.com".into()], &[b'x'; 100]).await, Err(Fail::Perm(m)) if m.contains("bigger")));
        let (c, _s) = duplex(64);
        assert!(matches!(deliver(Box::new(c), &sess(&NoTls, true), "me@anexomail.com", &["a@x.com>\r\nRCPT TO:<z@z.com".into()], b".\r\n").await, Err(Fail::Perm(_))));
    }
    #[tokio::test] async fn replies_are_bounded() {
        let long = format!("250 {}\r\n", "a".repeat(2000)); let mut r = BufReader::new(long.as_bytes()); assert!(read_reply(&mut r).await.is_err());
        let many = "250-x\r\n".repeat(120) + "250 end\r\n"; let mut r = BufReader::new(many.as_bytes()); assert!(read_reply(&mut r).await.is_err());
        let mixed = "250-x\r\n251 y\r\n"; let mut r = BufReader::new(mixed.as_bytes()); assert!(read_reply(&mut r).await.is_err());
        let ok = "250-a\r\n250-SIZE 99\r\n250 STARTTLS\r\n"; let mut r = BufReader::new(ok.as_bytes()); let rep = read_reply(&mut r).await.unwrap(); assert!(rep.has_ext("starttls") && rep.size_limit() == Some(99) && !rep.has_ext("a"));
    }
    #[test] fn private_addresses_are_never_contacted() {
        for ip in ["127.0.0.1", "10.1.2.3", "192.168.0.9", "172.16.5.5", "169.254.169.254", "100.64.0.1", "0.0.0.0", "224.0.0.1", "198.18.0.1", "::1", "fe80::1", "fc00::1", "::ffff:127.0.0.1", "2001:db8::1", "240.0.0.1"] { assert!(!is_public(&ip.parse().unwrap()), "{ip}"); }
        for ip in ["8.8.8.8", "142.250.1.1", "2606:4700::1111"] { assert!(is_public(&ip.parse().unwrap()), "{ip}"); }
    }
    #[test] fn mx_order() { assert_eq!(order_mx(vec![(20, "b.x".into()), (10, "z.x".into()), (10, "a.x".into())]), vec!["a.x", "z.x", "b.x"]); }
    #[test] fn real_tls_config_builds() { assert!(RustlsUpgrade::new().is_ok()); }
}
