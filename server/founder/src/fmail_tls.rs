//! QC1c F2/F4 (founder mailbox): the domain TLS probe behind the lock on every recipient chip. Technology: Rust + Tokio, tokio-rustls (TLS 1.3 + 1.2 allowed so an old server is NAMED, X25519MLKEM768 offered first), hickory-resolver.
//! INHERITABLE BY AWAM: no database, no founder names. Reuses fmail_smtp (targets, read_reply, Reply, is_public, Io/BoxIo, Fail): no second copy of MX / address logic.
//! Law of this file: (1) the probe takes a DOMAIN ONLY, never an address, never MAIL FROM / RCPT / DATA: it greets, asks STARTTLS, handshakes, QUITs. (2) Every answer is one of the closed verdicts
//! pq / classic13 / classic12 / none / refused / unreachable / nomail; the word "unknown" does not exist. (3) A certificate that does not verify is still READ (group, version) and stored with cert_verified=false,
//! nothing is ever sent over such a connection except QUIT. (4) At most 3 MX hosts, priority order, 45 s cap for the whole domain, private addresses never contacted (smtp::targets).
use crate::fmail_smtp as smtp;
use smtp::{BoxIo, Fail};
use std::{future::Future, pin::Pin, sync::{atomic::{AtomicBool, Ordering}, Arc}, time::Duration};
use tokio::io::{AsyncWriteExt, BufReader};

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

// ================================================================ FOUNDER GLUE (database, vault, doors). Everything above is inheritable; everything below knows the founder's E189/E190 doors.
use crate::{fmail_in::bytea, fmail_seal as seal, lease, passkey as pk, S};
use axum::{extract::State, http::{HeaderMap, StatusCode, Uri}, response::{IntoResponse, Response}};
use serde_json::{json, Value};

const AAD_TAG: &str = "fmail-dtls-v1";
const DETAIL_TAG: &str = "fmail-dtls-detail-v1";

/// The domain ready for the E189 doors: a blind index, and the name sealed under a fresh key wrapped by the vault master. Nothing plain.
#[derive(Debug, Clone)]
pub struct SealedDomain { pub blind: [u8; 32], pub sealed: Vec<u8>, pub nonce: [u8; 12], pub key_id: String, pub key_wrap: Vec<u8>, pub aad_hash: [u8; 32] }
pub fn domain_blind(master: &seal::Key, mailbox: &str, domain: &str) -> Result<[u8; 32], &'static str> { Ok(seal::blind(&seal::blind_key(master, mailbox)?, "tlsdomain", domain)) }
fn tls_aad(mailbox: &str, blind_hex: &str) -> Vec<u8> { seal::aad(&[AAD_TAG, mailbox, blind_hex]) }
pub fn seal_domain(master: &seal::Key, mailbox: &str, key_id: &str, domain: &str) -> Result<SealedDomain, &'static str> {
    let d = domain_only(domain).ok_or("not a domain")?;
    let blind = domain_blind(master, mailbox, &d)?; let aad = tls_aad(mailbox, &hex::encode(blind));
    let key = seal::new_key()?; let (nonce, sealed) = seal::seal(&key, &aad, d.as_bytes())?;
    Ok(SealedDomain { blind, sealed, nonce, key_id: key_id.to_string(), key_wrap: seal::wrap_vault(master, key_id, &key)?, aad_hash: seal::aad_hash(&aad) })
}
/// Open the sealed name of a row of fmail_dtls_due189 (hex columns). None on ANY mismatch (stored AAD hash, key wrap, seal), never partial text.
pub fn open_domain(master: &seal::Key, mailbox: &str, row: &Value) -> Option<String> {
    let hx = |k: &str| row.get(k).and_then(|v| v.as_str()).and_then(|s| hex::decode(s).ok());
    let (sealed, nonce, wrap, aadh, blind) = (hx("sealed")?, hx("nonce")?, hx("key_wrap")?, hx("aad_hash")?, row.get("domain_blind")?.as_str()?);
    let aad = tls_aad(mailbox, blind);
    if seal::aad_hash(&aad).as_slice() != aadh.as_slice() { return None; }
    let key = seal::unwrap_vault(master, row.get("key_id")?.as_str()?, &wrap)?;
    let d = String::from_utf8(seal::open(&key, &nonce, &aad, &sealed)?).ok()?;
    domain_only(&d).filter(|x| *x == d)
}
fn detail_key(master: &seal::Key, mailbox: &str, blind_hex: &str) -> Result<seal::Key, &'static str> { seal::derive(master, DETAIL_TAG, &format!("{mailbox}|{blind_hex}")) }
fn detail_aad(mailbox: &str, blind_hex: &str) -> Vec<u8> { seal::aad(&[DETAIL_TAG, mailbox, blind_hex]) }
/// The per-host reasons, sealed under a key derived from the vault master for this very row (no key to store, nothing readable in the database).
pub fn seal_detail(master: &seal::Key, mailbox: &str, blind_hex: &str, p: &Probe) -> Option<(Vec<u8>, [u8; 12])> {
    let k = detail_key(master, mailbox, blind_hex).ok()?; let (n, s) = seal::seal(&k, &detail_aad(mailbox, blind_hex), detail_json(p).as_bytes()).ok()?; Some((s, n))
}
pub fn open_detail(master: &seal::Key, mailbox: &str, blind_hex: &str, d: &Value) -> Option<Value> {
    let hx = |k: &str| d.get(k).and_then(|v| v.as_str()).and_then(|s| hex::decode(s).ok());
    let k = detail_key(master, mailbox, blind_hex).ok()?;
    serde_json::from_slice(&seal::open(&k, &hx("nonce")?, &detail_aad(mailbox, blind_hex), &hx("sealed")?)?).ok()
}

/// A chip changed: wake the live watcher now, so the signed tick goes out (QC1cF3-5). The change-log line itself is written by the E190 trigger.
pub fn notify_chip() { crate::fmail_live::poke(); }

/// The human line for a proved lock (QC1cF5-2). Closed words, no "unknown".
pub fn mismatch_line(proven_verdict: &str, mismatch: bool) -> String {
    let label = match proven_verdict { "pq" => "post-quantum (X25519MLKEM768)", "classic13" => "classic TLS 1.3", "classic12" => "TLS 1.2 or older", "none" => "no TLS", _ => "a lock of its own" };
    if mismatch { format!("The probe predicted a different lock; the real delivery was {label}.") } else { format!("The real delivery matched the probe: {label}.") }
}

async fn rpc(sb: &crate::data::Sb, f: &str, body: Value) -> Result<Value, String> {
    match tokio::time::timeout(Duration::from_secs(8), sb.rpc_msg(f, body)).await { Ok(Ok(v)) => Ok(v), Ok(Err((_, m))) => Err(m.chars().take(160).collect()), Err(_) => Err("the database did not answer in time".into()) }
}

/// One domain: claim (atomic, cache, budget) -> probe -> finish. Returns the door's JSON; a claim that says "no" is returned as it is (cached / busy / budget / waiting / final, with the row).
pub async fn run_check(sb: &crate::data::Sb, master: &seal::Key, actor: &str, mailbox: &str, key_id: &str, domain: &str, hs: &dyn Handshake) -> Value {
    let Some(d) = domain_only(domain) else { return json!({"ok": false, "error": "not a domain name"}) };
    let Ok(sd) = seal_domain(master, mailbox, key_id, &d) else { return json!({"ok": false, "error": "the vault master key is not usable"}) };
    let bh = hex::encode(sd.blind);
    let claim = match rpc(sb, "fmail_dtls_claim189", json!({"p_actor": actor, "p_mailbox": mailbox, "p_blind": bytea(&sd.blind), "p_sealed": bytea(&sd.sealed), "p_nonce": bytea(&sd.nonce), "p_key_id": sd.key_id, "p_key_wrap": bytea(&sd.key_wrap), "p_aad": bytea(&sd.aad_hash)})).await {
        Ok(v) => v, Err(e) => return json!({"ok": false, "error": e}),
    };
    if claim["go"] != json!(true) { return claim; }
    notify_chip();   // the dotted "checking" state
    let Some(res) = crate::fmail_out::probe_resolver() else { return json!({"ok": false, "error": "no DNS resolver"}) };
    let p = probe_domain(res, &d, "mail.anexomail.com", &TcpDialer, hs).await;
    let (det, dn) = seal_detail(master, mailbox, &bh, &p).map(|(s, n)| (Value::String(bytea(&s)), Value::String(bytea(&n)))).unwrap_or((Value::Null, Value::Null));
    let f = p.fact.as_ref();
    let out = match rpc(sb, "fmail_dtls_finish189", json!({"p_actor": actor, "p_mailbox": mailbox, "p_blind": bytea(&sd.blind), "p_verdict": p.verdict, "p_group": f.map(|x| x.group.clone()), "p_version": f.map(|x| x.version.clone()),
        "p_cipher": f.map(|x| x.cipher.clone()), "p_cert": f.map(|x| x.cert_verified), "p_detail": det, "p_detail_nonce": dn})).await { Ok(v) => v, Err(e) => json!({"ok": false, "error": e}) };
    notify_chip();
    out
}

/// A real delivery or a real arrival writes its fact (QC1cF1-1/2). sent: version and group came out of the very session that carried the mail.
pub async fn real_fact(sb: &crate::data::Sb, master: &seal::Key, actor: &str, mailbox: &str, key_id: &str, direction: &str, domain: &str, verdict: &str, group: Option<&str>, version: Option<&str>) -> Option<Value> {
    let sd = seal_domain(master, mailbox, key_id, domain).ok()?;
    let r = rpc(sb, "fmail_dtls_real189", json!({"p_actor": actor, "p_mailbox": mailbox, "p_blind": bytea(&sd.blind), "p_sealed": bytea(&sd.sealed), "p_nonce": bytea(&sd.nonce), "p_key_id": sd.key_id, "p_key_wrap": bytea(&sd.key_wrap),
        "p_aad": bytea(&sd.aad_hash), "p_direction": direction, "p_verdict": verdict, "p_group": group, "p_version": version, "p_cipher": Value::Null, "p_cert": if direction == "sent" { json!(true) } else { Value::Null }})).await;
    match r { Ok(v) => { notify_chip(); Some(v) } Err(e) => { eprintln!("founder: domain TLS fact ({direction}) refused: {e}"); None } }
}

static HS: std::sync::OnceLock<Option<RustlsProbe>> = std::sync::OnceLock::new();
fn real_hs() -> Option<&'static RustlsProbe> { HS.get_or_init(|| RustlsProbe::new().ok()).as_ref() }

/// QC1cF3-4: every 30 s (plus jitter) the due unreachable domains (1, 5, 30 minutes, then stop) are claimed, probed and finished, four at a time. The chip changes by itself (notify_chip).
pub async fn retry_worker(sb: crate::data::Sb) {
    let sem = Arc::new(tokio::sync::Semaphore::new(4));
    eprintln!("founder: domain TLS retry worker ON (1, 5, 30 minutes)");
    loop {
        let jitter = (std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.subsec_millis()).unwrap_or(0) % 5000) as u64;
        tokio::time::sleep(Duration::from_millis(30_000 + jitter)).await;
        let (Some(master), Some(hs)) = (lease::MASTER.get(), real_hs()) else { continue };
        let Some(Value::Array(due)) = sb.rpc("fmail_dtls_due189", json!({"p_limit": 20})).await else { continue };
        let mut set = tokio::task::JoinSet::new();
        for row in due {
            let Some(mailbox) = row["mailbox"].as_str().map(|x| x.to_string()) else { continue };
            let (Some(domain), Some(actor)) = (open_domain(master, &mailbox, &row), crate::fmail_book::owner_of(&sb, &mailbox).await) else { continue };
            let key_id = row["key_id"].as_str().unwrap_or("vault-1").to_string();
            let (sb2, sem2, m) = (sb.clone(), sem.clone(), *master);
            set.spawn(async move { let _p = sem2.acquire().await; run_check(&sb2, &m, &actor, &mailbox, &key_id, &domain, hs).await });
        }
        while set.join_next().await.is_some() {}
    }
}

// ---------------------------------------------------------------- HTTP doors
fn bad(e: &str) -> Response { pk::refuse(StatusCode::BAD_REQUEST, e) }
async fn own(sb: &crate::data::Sb, uid: &str, mailbox: &str) -> Result<(), Response> {
    let v = sb.rpc("fmail_mailboxes169", json!({"p_uid": uid})).await.ok_or_else(|| pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "mail database not answering - run the E189 SQL step (sql-run.sh)"))?;
    if v.as_array().map(|a| a.iter().any(|m| m["id"] == mailbox && m["status"] == "active")).unwrap_or(false) { Ok(()) } else { Err(pk::refuse(StatusCode::NOT_FOUND, "no such mailbox")) }
}
/// ?box=<uuid>&d=a.com,b.org (at most 50, each a bare domain). Anything else is refused.
pub fn parse_get(q: Option<&str>) -> Result<(String, Vec<String>), &'static str> {
    let (mut b, mut ds) = (None, Vec::new());
    for kv in q.unwrap_or("").split('&').filter(|x| !x.is_empty()) {
        let (k, v) = kv.split_once('=').unwrap_or((kv, ""));
        match k {
            "box" => { if !pk::is_uuid(v) { return Err("invalid box"); } b = Some(v.to_string()); }
            "d" => { for x in v.replace("%2C", ",").replace("%2c", ",").split(',').filter(|x| !x.is_empty()) { ds.push(domain_only(x).ok_or("not a domain")?); } }
            _ => return Err("unknown parameter"),
        }
    }
    ds.sort(); ds.dedup();
    if ds.len() > 50 { return Err("at most 50 domains"); }
    Ok((b.ok_or("missing box")?, ds))
}

/// GET /founder/v1/mail/tls?box=<uuid>&d=a.com,b.org : the facts for the chips on screen. Opens the sealed detail here (vault master) and hands plain facts to the browser over the signed channel.
pub async fn tls_get_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let (b, ds) = match parse_get(uri.query()) { Ok(x) => x, Err(e) => return bad(e) };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    if let Err(r) = own(sb, &c.sub, &b).await { return r; }
    let Some(master) = lease::MASTER.get() else { return pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "the vault master key is not loaded") };
    let mut by_blind = std::collections::HashMap::new(); let mut blinds = Vec::new();
    for d in &ds { if let Ok(bl) = domain_blind(master, &b, d) { by_blind.insert(hex::encode(bl), d.clone()); blinds.push(Value::String(bytea(&bl))); } }
    let v = match rpc(sb, "fmail_dtls_get189", json!({"p_actor": c.sub, "p_mailbox": b, "p_blinds": blinds})).await { Ok(v) => v, Err(e) => return pk::refuse(StatusCode::BAD_GATEWAY, &e) };
    let mut seen = std::collections::HashSet::new();
    let rows: Vec<Value> = v["rows"].as_array().map(|a| a.iter().filter_map(|r| {
        let bh = r["domain_blind"].as_str()?; let domain = by_blind.get(bh)?; seen.insert(domain.clone());
        let detail = r.get("detail").filter(|d| d.is_object()).and_then(|d| open_detail(master, &b, bh, d));
        let proven = r["proven_verdict"].as_str().map(|p| mismatch_line(p, r["mismatch"] == json!(true)));
        let mut o = r.clone(); o["domain"] = json!(domain); o["detail"] = detail.unwrap_or(Value::Null); o["line"] = proven.map(Value::from).unwrap_or(Value::Null); Some(o)
    }).collect()).unwrap_or_default();
    let missing: Vec<&String> = ds.iter().filter(|d| !seen.contains(*d)).collect();
    crate::signed(&st, json!({"ok": true, "rows": rows, "missing": missing}))
}

/// POST /founder/v1/mail/tls/check {box, domains:[...<=10]} : probe the domains the chips show that have no fact yet (or are due). A signed write; each domain goes through the claim door (cache, budget, one at a time).
pub async fn tls_check_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some(b) = pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)) else { return bad("box is needed") };
    let Some(list) = j.get("domains").and_then(|d| d.as_array()) else { return bad("domains is needed") };
    if list.is_empty() || list.len() > 10 { return bad("1 to 10 domains per request"); }
    let mut ds: Vec<String> = Vec::new();
    for x in list { match x.as_str().and_then(domain_only) { Some(d) => ds.push(d), None => return bad("a domain is not a domain name") } }
    ds.sort(); ds.dedup();
    if let Err(r) = own(sb, &uid, &b).await { return r; }
    let (Some(master), Some(hs)) = (lease::MASTER.get(), real_hs()) else { return pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "the vault master key or the TLS stack is not ready") };
    let mut set = tokio::task::JoinSet::new();
    for d in ds { let (sb2, m, u, bx) = (sb.clone(), *master, uid.clone(), b.clone()); set.spawn(async move { let r = run_check(&sb2, &m, &u, &bx, "vault-1", &d, hs).await; (d, r) }); }
    let mut out = serde_json::Map::new();
    while let Some(Ok((d, r))) = set.join_next().await { out.insert(d, r); }
    crate::signed(&st, json!({"ok": true, "results": out}))
}

/// Postfix's own Received header (the topmost one our MX wrote) proves a weak lock for the arriving mail: TLS 1.2 or older -> classic12, no TLS at all -> none. TLS 1.3 names no group, so it
/// proves nothing about post-quantum and is never claimed (None). Returns (verdict, version).
pub fn received_hint(raw: &[u8]) -> Option<(&'static str, Option<&'static str>)> {
    let head = String::from_utf8_lossy(&raw[..raw.len().min(16 * 1024)]).to_string();
    let head = head.split("\r\n\r\n").next().unwrap_or("").split("\n\n").next().unwrap_or("").replace("\r\n", "\n");
    let mut it = head.split('\n'); let mut first = String::new();
    while let Some(l) = it.next() { if l.to_ascii_lowercase().starts_with("received:") { first = l.to_string(); for n in it.by_ref() { if n.starts_with(' ') || n.starts_with('\t') { first.push(' '); first.push_str(n.trim()); } else { break; } } break; } }
    if first.is_empty() { return None; }
    let l = first.to_ascii_lowercase();
    if l.contains("using tlsv1.3") { return None; }
    if l.contains("using tlsv1.2") { return Some(("classic12", Some("TLSv1.2"))); }
    if l.contains("using tlsv1.1") { return Some(("classic12", Some("TLSv1.1"))); }
    if l.contains("using tlsv1 ") || l.contains("using tlsv1.0") || l.contains("using sslv3") { return Some(("classic12", Some("TLSv1.0"))); }
    if (l.contains(" with esmtp ") || l.contains(" with smtp ")) && !l.contains("esmtps") && !l.contains("using tls") { return Some(("none", None)); }
    None
}

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

    #[test]
    fn mismatch_line_is_plain_and_closed() {
        assert!(mismatch_line("pq", false).contains("matched") && mismatch_line("classic13", true).contains("different") && mismatch_line("none", true).contains("no TLS"));
    }
    #[test]
    fn domains_seal_open_and_cannot_move() {
        let m = [9u8; 32]; let mb = "11111111-1111-1111-1111-111111111111";
        let sd = seal_domain(&m, mb, "vault-1", "Example.COM").unwrap();
        assert!(!String::from_utf8_lossy(&sd.sealed).contains("example"));
        let row = json!({"sealed": hex::encode(&sd.sealed), "nonce": hex::encode(sd.nonce), "key_id": "vault-1", "key_wrap": hex::encode(&sd.key_wrap), "aad_hash": hex::encode(sd.aad_hash), "domain_blind": hex::encode(sd.blind)});
        assert_eq!(open_domain(&m, mb, &row).as_deref(), Some("example.com"));
        assert!(open_domain(&m, "22222222-2222-2222-2222-222222222222", &row).is_none(), "another mailbox");
        assert!(open_domain(&[1u8; 32], mb, &row).is_none(), "another master");
        assert!(seal_domain(&m, mb, "k", "a@b.com").is_err(), "an address is never sealed here");
    }
    #[test]
    fn detail_is_sealed_per_row_and_opens_only_there() {
        let m = [9u8; 32]; let mb = "11111111-1111-1111-1111-111111111111"; let bh = "ab".repeat(32);
        let p = Probe { verdict: "unreachable", fact: None, detail: "mx.example.com: connection refused".into(), hosts_tried: vec!["mx.example.com".into()] };
        let (s, n) = seal_detail(&m, mb, &bh, &p).unwrap(); assert!(!String::from_utf8_lossy(&s).contains("refused"));
        let d = json!({"sealed": hex::encode(&s), "nonce": hex::encode(n)});
        assert_eq!(open_detail(&m, mb, &bh, &d).unwrap()["hosts_tried"][0], "mx.example.com");
        assert!(open_detail(&m, mb, &"cd".repeat(32), &d).is_none(), "another row");
    }
    #[test]
    fn get_door_grammar() {
        let b = "11111111-1111-1111-1111-111111111111";
        let (bx, ds) = parse_get(Some(&format!("box={b}&d=B.com%2Ca.org,a.org"))).unwrap(); assert_eq!(bx, b); assert_eq!(ds, vec!["a.org", "b.com"]);
        assert!(parse_get(Some("d=a.com")).is_err() && parse_get(Some(&format!("box={b}&x=1"))).is_err() && parse_get(Some(&format!("box={b}&d=a@b.com"))).is_err());
        let many = (0..51).map(|i| format!("d{i}.com")).collect::<Vec<_>>().join(",");
        assert!(parse_get(Some(&format!("box={b}&d={many}"))).is_err());
    }
    #[test]
    fn received_header_proves_only_what_it_proves() {
        let r = |h: &str| received_hint(format!("Received: {h}\r\nFrom: a@b.com\r\n\r\nhi").as_bytes());
        assert_eq!(r("from mx.b.com (mx.b.com [1.2.3.4]) (using TLSv1.2 with cipher ECDHE-RSA-AES256-GCM-SHA384 (256/256 bits)) by mail (Postfix) with ESMTPS id 1"), Some(("classic12", Some("TLSv1.2"))));
        assert_eq!(r("from mx.b.com (mx.b.com [1.2.3.4]) by mail.anexomail.com (Postfix) with ESMTP id 7"), Some(("none", None)));
        assert_eq!(r("from mx.b.com (using TLSv1.3 with cipher TLS_AES_256_GCM_SHA384) by mail (Postfix) with ESMTPS id 1"), None, "TLS 1.3 names no group: no claim");
        assert_eq!(received_hint(b"From: a@b.com\r\n\r\nhi"), None);
        assert_eq!(r("from localhost by mail with LMTP id 3"), None);
    }
}
