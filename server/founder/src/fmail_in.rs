//! Q1b-3 (founder mailbox): INBOUND. A loopback-only LMTP server (RFC 2033) behind Postfix, a ClamAV INSTREAM client, and the ingest that seals every mail the moment it arrives.
//! Mail path: internet -> Postfix :25 (stays the front, it already does TLS and the reputation work) -> LMTP on 127.0.0.1 (this file) -> parse -> ClamAV -> seal (AES-256-GCM, or ML-KEM-768 hybrid) -> fmail_deliver_inbound -> ledger.
//! Rules this file keeps:
//!   * Postfix is never changed from here and the listener is OFF unless FMAIL_LMTP_BIND is set to a LOOPBACK address (anything else is refused at start).
//!   * Mail is never lost: any database or sealing trouble answers 451 (Postfix keeps the mail and tries again). A mail is 250-accepted only after it is stored sealed.
//!   * Fail closed on the scanner: infected = quarantine; a scanner that errors = quarantine too (the mail is kept, just not trusted). No scanner configured = 'skipped' (inbox).
//!   * The wire parsing (commands, dot-unstuffing, size cap, scanner reply) is PURE and tested here; the session talks to a `Backend` trait so tests need no network.
use crate::data::Sb;
use crate::{fmail_core as core, fmail_seal as seal};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt, BufReader};

pub const MAX_RCPT: usize = 50;
pub const MAX_LINE: u64 = 100_000;      // one protocol line (RFC 5321 says 998 for message lines; some senders break it, 100k is the hard stop)
pub const CMD_IDLE_S: u64 = 120;
pub const DATA_IDLE_S: u64 = 300;
pub const DATA_TOTAL_S: u64 = 900;      // a sender that trickles bytes forever is cut after 15 minutes in total
pub const MAX_CONN: usize = 32;

// ---------------------------------------------------------------- pure: commands

#[derive(Debug, PartialEq)]
pub enum Cmd { Lhlo, Mail { size: Option<u64> }, Rcpt(String), Data, Rset, Noop, Quit, Vrfy, Bad(&'static str) }

/// "<a@b.c>" -> a@b.c (lower-cased, bracket required, no spaces or control characters). "<>" (null sender) -> Some("").
pub fn path_addr(rest: &str) -> Option<String> {
    let rest = rest.trim_start();
    let inner = rest.strip_prefix('<')?.split_once('>')?.0;
    if inner.is_empty() { return Some(String::new()); }
    let inner = inner.rsplit_once(':').map(|(_, a)| a).unwrap_or(inner);   // source route "@a,@b:user@host" -> user@host
    if inner.len() > 254 || inner.bytes().any(|b| b <= 32 || b == 127 || b == b'<' || b == b'>') || inner.matches('@').count() != 1 { return None; }
    Some(inner.to_ascii_lowercase())
}

pub fn parse_cmd(line: &str) -> Cmd {
    let l = line.trim_end_matches(['\r', '\n']);
    if l.len() > 2000 || l.bytes().any(|b| b == 0) { return Cmd::Bad("line too long or binary"); }
    let (verb, rest) = l.split_once(' ').unwrap_or((l, ""));
    match verb.to_ascii_uppercase().as_str() {
        "LHLO" | "EHLO" | "HELO" => Cmd::Lhlo,
        "MAIL" => {
            let up = rest.to_ascii_uppercase();
            let Some(after) = up.strip_prefix("FROM:") else { return Cmd::Bad("syntax: MAIL FROM:<address>") };
            if path_addr(&rest[5..]).is_none() { return Cmd::Bad("bad sender address"); }
            let size = after.split_whitespace().find_map(|p| p.strip_prefix("SIZE=")).and_then(|v| v.parse::<u64>().ok());
            Cmd::Mail { size }
        }
        "RCPT" => {
            let up = rest.to_ascii_uppercase();
            if !up.starts_with("TO:") { return Cmd::Bad("syntax: RCPT TO:<address>"); }
            match path_addr(&rest[3..]) { Some(a) if !a.is_empty() => Cmd::Rcpt(a), _ => Cmd::Bad("bad recipient address") }
        }
        "DATA" => Cmd::Data, "RSET" => Cmd::Rset, "NOOP" => Cmd::Noop, "QUIT" => Cmd::Quit, "VRFY" => Cmd::Vrfy,
        _ => Cmd::Bad("command not recognised"),
    }
}

/// Collects the DATA section: removes the SMTP dot-stuffing, stops at the lone ".", and keeps counting past the size cap without storing (so the connection stays in step).
pub struct DataBuf { pub buf: Vec<u8>, pub seen: usize, pub over: bool, cap: usize }
impl DataBuf {
    pub fn new(cap: usize) -> Self { DataBuf { buf: Vec::new(), seen: 0, over: false, cap } }
    /// One line including its line ending. Returns true when it was the terminator.
    pub fn push_line(&mut self, line: &[u8]) -> bool {
        if line == b".\r\n" || line == b".\n" { return true; }
        let l = if line.starts_with(b"..") { &line[1..] } else { line };
        self.seen += l.len();
        if self.seen > self.cap { self.over = true; self.buf = Vec::new(); } else if !self.over { self.buf.extend_from_slice(l); }
        false
    }
}

// ---------------------------------------------------------------- pure: scanner + routing

/// clamd reply -> state. Anything that is not an explicit "OK" or "FOUND" is an error (fail closed).
pub fn clam_state(reply: &str) -> &'static str {
    let r = reply.trim_matches(|c: char| c == '\0' || c.is_whitespace());
    if r.ends_with("FOUND") { "infected" } else if r.ends_with(": OK") || r == "OK" { "clean" } else { "error" }
}
/// Where a mail lands: ONLY a verified-clean mail reaches the inbox. Not scanned ("skipped"), scanner trouble ("error") and "infected" all go to quarantine (fail closed; Q1b-3 audit 13 Nov 04:30: "skipped" used to reach the inbox).
pub fn folder_for(scan: &str) -> &'static str { match scan { "clean" => "inbox", _ => "quarantine" } }

/// ClamAV cannot look inside what it cannot open, and its AlertEncrypted / AlertExceedsMax are OFF by default (clamd is shared with the awam side, so its config is not ours to change).
/// So the founder intake spots attachments that hide their content itself: password-protected ZIP (general-purpose bit 0 of any local header), encrypted PDF (/Encrypt),
/// encrypted Office files (an OLE container holding EncryptedPackage / EncryptionInfo). A "clean" verdict on such a mail is not trusted: it is quarantined.
/// Not detectable here without unpacking: encrypted 7z / RAR (named in Q-FIX-ORDER as a residual gap; clamd AlertEncrypted yes closes it, needs his haan because awam shares clamd).
pub fn opaque_attachment(raw: &[u8]) -> bool {
    use mail_parser::MimeHeaders;
    let Some(m) = mail_parser::MessageParser::default().parse(raw) else { return false };
    m.attachments().any(|a| is_opaque(a.contents()))
}
pub fn is_opaque(b: &[u8]) -> bool {
    if b.len() >= 4 && &b[..4] == b"PK\x03\x04" || b.windows(4).take(1 << 20).any(|w| w == b"PK\x03\x04") {
        let mut i = 0;
        while let Some(p) = b[i..].windows(4).position(|w| w == b"PK\x03\x04") {
            let h = i + p;
            if h + 8 <= b.len() && b[h + 6] & 1 == 1 { return true; }
            i = h + 4;
            if i >= b.len() { break; }
        }
    }
    if b.starts_with(b"%PDF") && b.windows(8).any(|w| w == b"/Encrypt") { return true; }
    if b.starts_with(&[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) {
        let u16le = |t: &str| -> Vec<u8> { t.encode_utf16().flat_map(|c| c.to_le_bytes()).collect() };
        for t in ["EncryptedPackage", "EncryptionInfo"] { let n = u16le(t); if b.windows(n.len()).any(|w| w == n.as_slice()) { return true; } }
    }
    false
}
/// PostgREST bytea literal.
pub fn bytea(b: &[u8]) -> String { format!("\\x{}", hex::encode(b)) }

/// clamd INSTREAM: `zINSTREAM\0`, then [u32 BE length][bytes] chunks, then a zero length. Works over TCP or a unix socket (anything async).
pub async fn clam_stream<S: AsyncRead + AsyncWrite + Unpin>(s: &mut S, data: &[u8]) -> Result<String, std::io::Error> {
    s.write_all(b"zINSTREAM\0").await?;
    for c in data.chunks(64 * 1024) { s.write_all(&(c.len() as u32).to_be_bytes()).await?; s.write_all(c).await?; }
    s.write_all(&0u32.to_be_bytes()).await?; s.flush().await?;
    let mut out = Vec::new(); let _ = (&mut *s).take(4096).read_to_end(&mut out).await?;
    Ok(String::from_utf8_lossy(&out).into_owned())
}
/// "host:port" (TCP) or "/path/to/clamd.ctl" (unix). Never panics, never waits more than 60 s.
pub async fn clam_scan(addr: &str, data: &[u8]) -> &'static str {
    let work = async {
        if addr.starts_with('/') { let mut s = tokio::net::UnixStream::connect(addr).await?; clam_stream(&mut s, data).await }
        else { let mut s = tokio::net::TcpStream::connect(addr).await?; clam_stream(&mut s, data).await }
    };
    match tokio::time::timeout(std::time::Duration::from_secs(60), work).await { Ok(Ok(r)) => clam_state(&r), _ => "error" }
}

// ---------------------------------------------------------------- the session (generic over the backend so tests need no network)

#[derive(Clone, Debug)]
pub struct Rcpt { pub addr: String, pub mailbox_id: String, pub seal_mode: String, pub key_id: String, pub pub_hex: Option<String> }
pub fn rcpt_from_json(addr: &str, v: &Value) -> Option<Rcpt> {
    if v["accept"] != true { return None; }
    let seal_mode = v["seal_mode"].as_str()?.to_string();
    let key_id = if seal_mode == "recipient_pq" { v["key_id"].as_str()? } else { v["vault_key_id"].as_str()? }.to_string();
    Some(Rcpt { addr: addr.to_string(), mailbox_id: v["mailbox_id"].as_str()?.to_string(), seal_mode, key_id, pub_hex: v["recipient_pub_hex"].as_str().map(str::to_string) })
}

pub trait Backend: Send + Sync {
    /// Ok(recipient) = accept; Err((smtp code, text)) = the answer for RCPT.
    fn rcpt(&self, addr: &str) -> impl std::future::Future<Output = Result<Rcpt, (u16, String)>> + Send;
    /// Store one mail for one recipient. Ok = stored sealed (or a duplicate that already is). Err = try again later (451).
    fn deliver(&self, raw: &[u8], r: &Rcpt) -> impl std::future::Future<Output = Result<(), String>> + Send;
    fn max_bytes(&self) -> usize;
}

async fn say<W: AsyncWrite + Unpin>(w: &mut W, s: &str) -> std::io::Result<()> { w.write_all(s.as_bytes()).await?; w.write_all(b"\r\n").await?; w.flush().await }

async fn read_line<R: AsyncBufRead2>(r: &mut R, idle: u64) -> Option<Vec<u8>> {
    let mut line = Vec::new();
    match tokio::time::timeout(std::time::Duration::from_secs(idle), (&mut *r).take(MAX_LINE).read_until(b'\n', &mut line)).await {
        Ok(Ok(n)) if n > 0 && line.ends_with(b"\n") => Some(line),
        _ => None,
    }
}
pub trait AsyncBufRead2: AsyncBufReadExt + AsyncRead + Unpin {}
impl<T: AsyncBufReadExt + AsyncRead + Unpin> AsyncBufRead2 for T {}

pub async fn session<S: AsyncRead + AsyncWrite + Unpin + Send, B: Backend>(stream: S, be: &B) {
    let (rd, mut wr) = tokio::io::split(stream);
    let mut rd = BufReader::new(rd);
    if say(&mut wr, "220 anexomail-founder LMTP ready").await.is_err() { return; }
    let (mut from_ok, mut rcpts): (bool, Vec<Rcpt>) = (false, vec![]);
    loop {
        let Some(line) = read_line(&mut rd, CMD_IDLE_S).await else { return };
        let text = String::from_utf8_lossy(&line).into_owned();
        let r = match parse_cmd(&text) {
            Cmd::Lhlo => say(&mut wr, &format!("250-anexomail-founder\r\n250-PIPELINING\r\n250-8BITMIME\r\n250-ENHANCEDSTATUSCODES\r\n250 SIZE {}", be.max_bytes())).await,
            Cmd::Mail { size } => {
                if from_ok { say(&mut wr, "503 5.5.1 sender already given").await }
                else if size.map_or(false, |s| s as usize > be.max_bytes()) { say(&mut wr, "552 5.3.4 message too big").await }
                else { from_ok = true; rcpts.clear(); say(&mut wr, "250 2.1.0 ok").await }
            }
            Cmd::Rcpt(a) => {
                if !from_ok { say(&mut wr, "503 5.5.1 MAIL first").await }
                else if rcpts.len() >= MAX_RCPT { say(&mut wr, "452 4.5.3 too many recipients").await }
                else if rcpts.iter().any(|x| x.addr == a) { say(&mut wr, "250 2.1.5 ok").await }
                else { match be.rcpt(&a).await { Ok(x) => { rcpts.push(x); say(&mut wr, "250 2.1.5 ok").await } Err((c, t)) => say(&mut wr, &format!("{c} {}.1.1 {t}", if c >= 500 { 5 } else { 4 })).await } }
            }
            Cmd::Data => {
                if !from_ok || rcpts.is_empty() { say(&mut wr, "503 5.5.1 need MAIL and RCPT first").await }
                else {
                    if say(&mut wr, "354 end with <CRLF>.<CRLF>").await.is_err() { return; }
                    let mut d = DataBuf::new(be.max_bytes());
                    let t0 = std::time::Instant::now();
                    loop { if t0.elapsed().as_secs() > DATA_TOTAL_S { return; } let Some(l) = read_line(&mut rd, DATA_IDLE_S).await else { return }; if d.push_line(&l) { break; } }
                    // LMTP: one reply per accepted recipient, in the order of the RCPT commands
                    for rc in &rcpts {
                        let reply = if d.over { "552 5.3.4 message too big".to_string() }
                                    else { match be.deliver(&d.buf, rc).await { Ok(()) => "250 2.0.0 stored".to_string(), Err(e) => format!("451 4.3.0 try again later ({})", e.chars().take(80).collect::<String>().replace(['\r', '\n'], " ")) } };
                        if say(&mut wr, &reply).await.is_err() { return; }
                    }
                    from_ok = false; rcpts.clear(); Ok(())
                }
            }
            Cmd::Rset => { from_ok = false; rcpts.clear(); say(&mut wr, "250 2.0.0 ok").await }
            Cmd::Noop => say(&mut wr, "250 2.0.0 ok").await,
            Cmd::Vrfy => say(&mut wr, "252 2.5.2 not disclosed").await,
            Cmd::Quit => { let _ = say(&mut wr, "221 2.0.0 bye").await; return; }
            Cmd::Bad(w) => say(&mut wr, &format!("500 5.5.2 {w}")).await,
        };
        if r.is_err() { return; }
    }
}

// ---------------------------------------------------------------- the real backend

pub struct Live { pub sb: Sb, pub master: seal::Key, pub clamd: Option<String>, pub max: usize }

impl Backend for Live {
    fn max_bytes(&self) -> usize { self.max }
    async fn rcpt(&self, addr: &str) -> Result<Rcpt, (u16, String)> {
        let v = self.sb.rpc("fmail_rcpt_resolve", json!({"p_address": addr})).await.ok_or((451u16, "database not answering".to_string()))?;
        rcpt_from_json(addr, &v).ok_or_else(|| (v["smtp"].as_u64().unwrap_or(550) as u16, match v["reason"].as_str() { Some("paused") => "mailbox paused".into(), Some("no_key") => "mailbox key not ready".into(), _ => "no such mailbox".into() }))
    }
    async fn deliver(&self, raw: &[u8], r: &Rcpt) -> Result<(), String> {
        let s = core::summarize(raw);
        let scan = match &self.clamd { Some(a) => clam_scan(a, raw).await, None => "skipped" };
        // a "clean" verdict is not trusted when an attachment hides its content (encrypted ZIP / PDF / Office): quarantine it, recorded as "opaque" (E171; the scan could not look inside)
        let scan = if scan == "clean" && opaque_attachment(raw) { "opaque" } else { scan };
        let pubkey = match (&*r.seal_mode, &r.pub_hex) { ("recipient_pq", Some(h)) => Some(hex::decode(h).map_err(|_| "bad stored key")?), ("recipient_pq", None) => return Err("mailbox key not ready".into()), _ => None };
        let wrap = match &pubkey { Some(p) => core::Wrap::Recipient { public: p, key_id: &r.key_id }, None => core::Wrap::Vault { master: &self.master, key_id: &r.key_id } };
        let sealed = core::seal_message(&self.master, &r.mailbox_id, "in", wrap, raw, &s).map_err(|e| e.to_string())?;
        let opt = |b: &Option<[u8; 32]>| b.as_ref().map(|x| Value::String(bytea(x))).unwrap_or(Value::Null);
        let out = self.sb.rpc_msg("fmail_deliver_inbound", json!({
            "p_mailbox": r.mailbox_id, "p_folder_kind": folder_for(scan), "p_seal_mode": r.seal_mode,
            "p_sealed_body": bytea(&sealed.sealed_body), "p_sealed_meta": bytea(&sealed.sealed_meta), "p_nonce_body": bytea(&sealed.nonce_body), "p_nonce_meta": bytea(&sealed.nonce_meta),
            "p_key_id": sealed.key_id, "p_key_wrap": bytea(&sealed.key_wrap), "p_aad_hash": bytea(&sealed.aad_hash),
            "p_msgid_blind": bytea(&sealed.msgid_blind), "p_parent_blind": opt(&sealed.parent_blind), "p_subject_blind": bytea(&sealed.subject_blind), "p_sender_blind": opt(&sealed.sender_blind),
            "p_sender_domain": sealed.sender_domain, "p_size": raw.len() as i64, "p_spf": "none", "p_dkim": "none", "p_dmarc": "none", "p_arc": "none",
            "p_lookalike": false, "p_spam": Value::Null, "p_tls": Value::Null,
        })).await.map_err(|(c, m)| format!("database {c}: {m}"))?;
        if out["stored"] != true {
            // a duplicate is fine (the mail is already stored); a full or locked mailbox is a temporary no
            return if out["reason"] == "duplicate" { Ok(()) } else { Err(format!("not stored: {}", out["reason"].as_str().unwrap_or("unknown"))) };
        }
        let Some(mid) = out["message_id"].as_str() else { return Err("no message id".into()) };
        // the ledger row (the database recomputes the hash of the stored ciphertext) and the scan result; a failure here is retried by the sweep, the mail itself is already safe
        let _ = self.sb.rpc("fmail_inbound_note169", json!({"p_mailbox": r.mailbox_id, "p_message": mid, "p_body_sha256": hex::encode(Sha256::digest(&sealed.sealed_body))})).await;
        let _ = self.sb.rpc("fmail_scan_set171", json!({"p_mailbox": r.mailbox_id, "p_message": mid, "p_state": scan})).await;
        Ok(())
    }
}

// ---------------------------------------------------------------- listener

pub struct Cfg { pub bind: std::net::SocketAddr, pub clamd: Option<String> }
/// FMAIL_LMTP_BIND=127.0.0.1:<port> (loopback ONLY). The port is chosen after the fresh `ss` list (PORT RED LINE). FMAIL_CLAMD=host:port or /path/clamd.ctl (optional).
pub fn from_env() -> Option<Result<Cfg, String>> { parse_bind(std::env::var("FMAIL_LMTP_BIND").ok(), std::env::var("FMAIL_CLAMD").ok()) }
pub fn parse_bind(bind: Option<String>, clamd: Option<String>) -> Option<Result<Cfg, String>> {
    let b = bind.filter(|v| !v.trim().is_empty())?;
    let bind: std::net::SocketAddr = match b.trim().parse() { Ok(a) => a, Err(_) => return Some(Err(format!("FMAIL_LMTP_BIND '{b}' is not ip:port"))) };
    if !bind.ip().is_loopback() { return Some(Err(format!("FMAIL_LMTP_BIND {bind} is not a loopback address: refused (mail intake must never face the internet directly)"))); }
    Some(Ok(Cfg { bind, clamd: clamd.filter(|v| !v.trim().is_empty()) }))
}

pub async fn spawn(sb: Sb, master: seal::Key, cfg: Cfg) {
    let l = match tokio::net::TcpListener::bind(cfg.bind).await { Ok(l) => l, Err(e) => { eprintln!("founder: mail intake (LMTP) NOT started on {}: {e}", cfg.bind); return } };
    // the size limit comes from the policy row, read once; if it cannot be read the 25 MiB default of E167 applies
    let max = sb.rows("fmail_policy?select=max_message_bytes&id=eq.1").await.and_then(|r| r.first().and_then(|x| x["max_message_bytes"].as_u64())).unwrap_or(26_214_400) as usize;
    eprintln!("founder: mail intake (LMTP) ON {} (loopback only, max {} MiB, ClamAV {}, sealed on arrival)", cfg.bind, max / 1_048_576, cfg.clamd.as_deref().unwrap_or("not configured: scan = skipped"));
    let be = Arc::new(Live { sb, master, clamd: cfg.clamd, max });
    let gate = Arc::new(tokio::sync::Semaphore::new(MAX_CONN));
    tokio::spawn(async move {
        loop {
            let Ok((s, peer)) = l.accept().await else { tokio::time::sleep(std::time::Duration::from_millis(200)).await; continue };
            if !peer.ip().is_loopback() { continue; }
            let Ok(permit) = gate.clone().try_acquire_owned() else { continue };   // over the limit: the connection is dropped, Postfix retries
            let be = be.clone();
            tokio::spawn(async move { session(s, &*be).await; drop(permit); });
        }
    });
}

#[cfg(test)]
mod tests {
    #[test]
    fn opaque_attachments_are_caught() {
        // ZIP local header with the encrypted flag (bit 0 of general purpose flags at offset 6)
        let mut z = b"PK\x03\x04\x14\x00".to_vec(); z.extend_from_slice(&[0x01, 0x00]); z.extend_from_slice(&[0u8; 20]);
        assert!(is_opaque(&z));
        let mut plain = b"PK\x03\x04\x14\x00".to_vec(); plain.extend_from_slice(&[0x00, 0x00]); plain.extend_from_slice(&[0u8; 20]);
        assert!(!is_opaque(&plain));
        // second entry encrypted, first plain
        let mut two = plain.clone(); two.extend_from_slice(&z); assert!(is_opaque(&two));
        assert!(is_opaque(b"%PDF-1.7\n1 0 obj\n<< /Encrypt 9 0 R >>")); assert!(!is_opaque(b"%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>"));
        let mut ole = vec![0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]; ole.extend("EncryptedPackage".encode_utf16().flat_map(|c| c.to_le_bytes())); assert!(is_opaque(&ole));
        assert!(!is_opaque(b"hello world")); assert!(!is_opaque(b""));
    }
    #[test]
    fn opaque_inside_a_real_mime_mail() {
        let mut z = b"PK\x03\x04\x14\x00".to_vec(); z.extend_from_slice(&[0x09, 0x00]); z.extend_from_slice(&[0u8; 20]);
        let b64 = { use base64::Engine; base64::engine::general_purpose::STANDARD.encode(&z) };
        let mail = format!("From: a@b.co\r\nTo: c@d.co\r\nSubject: x\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary=\"B\"\r\n\r\n--B\r\nContent-Type: text/plain\r\n\r\nhi\r\n--B\r\nContent-Type: application/zip\r\nContent-Disposition: attachment; filename=\"a.zip\"\r\nContent-Transfer-Encoding: base64\r\n\r\n{b64}\r\n--B--\r\n");
        assert!(opaque_attachment(mail.as_bytes()));
        assert!(!opaque_attachment(b"From: a@b.co\r\nSubject: x\r\n\r\nplain\r\n"));
    }

    use super::*;
    use std::sync::Mutex;
    #[test]
    fn addresses_in_angle_brackets_only() {
        assert_eq!(path_addr("<A@B.co>").as_deref(), Some("a@b.co")); assert_eq!(path_addr(" <>").as_deref(), Some(""));
        assert_eq!(path_addr("<@relay.example:user@host.co>").as_deref(), Some("user@host.co"));
        for bad in ["a@b.co", "<a@b.co", "<a b@c.co>", "<a@@b.co>", "<nobody>", "<a@b.co\u{0}>"] { assert_eq!(path_addr(bad), None, "{bad}"); }
        assert_eq!(path_addr(&format!("<{}@x.co>", "a".repeat(300))), None);
    }
    #[test]
    fn commands_parse_and_junk_is_refused() {
        assert_eq!(parse_cmd("LHLO mx.example\r\n"), Cmd::Lhlo); assert_eq!(parse_cmd("quit\r\n"), Cmd::Quit);
        assert_eq!(parse_cmd("MAIL FROM:<a@b.co> SIZE=1234\r\n"), Cmd::Mail { size: Some(1234) }); assert_eq!(parse_cmd("MAIL FROM:<>\r\n"), Cmd::Mail { size: None });
        assert_eq!(parse_cmd("RCPT TO:<N@Anexomail.com>\r\n"), Cmd::Rcpt("n@anexomail.com".into()));
        for bad in ["MAIL <a@b.co>", "RCPT TO:<>", "RCPT TO:x@y.co", "STARTTLS", "AUTH LOGIN", "x\u{0}y", &"A".repeat(3000)] { assert!(matches!(parse_cmd(bad), Cmd::Bad(_)), "{bad:.20}"); }
    }
    #[test]
    fn dot_stuffing_terminator_and_size_cap() {
        let mut d = DataBuf::new(1000);
        assert!(!d.push_line(b"Subject: x\r\n")); assert!(!d.push_line(b"..hidden dot line\r\n")); assert!(!d.push_line(b".\x20not end\r\n")); assert!(d.push_line(b".\r\n"));
        assert_eq!(String::from_utf8(d.buf).unwrap(), "Subject: x\r\n.hidden dot line\r\n. not end\r\n");
        let mut d = DataBuf::new(10); assert!(!d.push_line(b"0123456789ABC\r\n")); assert!(d.over && d.buf.is_empty()); assert!(!d.push_line(b"more\r\n")); assert!(d.push_line(b".\r\n")); assert!(d.over);
    }
    #[test]
    fn scanner_replies_fail_closed() {
        assert_eq!(clam_state("stream: OK\0"), "clean"); assert_eq!(clam_state("stream: Eicar-Test-Signature FOUND\0"), "infected");
        for e in ["INSTREAM size limit exceeded. ERROR", "", "stream: lstat() failed ERROR", "garbage", "OKAY not"] { assert_eq!(clam_state(e), "error", "{e}"); }
        assert_eq!(folder_for("clean"), "inbox"); assert_eq!(folder_for("skipped"), "quarantine"); assert_eq!(folder_for("infected"), "quarantine"); assert_eq!(folder_for("error"), "quarantine"); assert_eq!(folder_for("opaque"), "quarantine"); assert_eq!(folder_for("whatever"), "quarantine");
        assert_eq!(bytea(&[0xab, 0x01]), "\\xab01");
    }
    #[tokio::test]
    async fn instream_framing_is_exact() {
        let (mut a, mut b) = tokio::io::duplex(1 << 20);
        let t = tokio::spawn(async move { let mut got = Vec::new(); let mut hdr = [0u8; 10]; b.read_exact(&mut hdr).await.unwrap(); assert_eq!(&hdr, b"zINSTREAM\0");
            loop { let mut l = [0u8; 4]; b.read_exact(&mut l).await.unwrap(); let n = u32::from_be_bytes(l) as usize; if n == 0 { break; } let mut c = vec![0u8; n]; b.read_exact(&mut c).await.unwrap(); got.extend(c); }
            b.write_all(b"stream: OK\0").await.unwrap(); b.shutdown().await.unwrap(); got });
        let data: Vec<u8> = (0..150_000u32).map(|i| (i % 251) as u8).collect();
        let r = clam_stream(&mut a, &data).await.unwrap(); assert_eq!(clam_state(&r), "clean"); assert_eq!(t.await.unwrap(), data);
    }
    #[test]
    fn rcpt_json_and_env_rules() {
        let v = json!({"accept": true, "mailbox_id": "m1", "seal_mode": "vault", "vault_key_id": "vk-1", "key_id": null, "recipient_pub_hex": null});
        let r = rcpt_from_json("a@b.co", &v).unwrap(); assert_eq!((r.mailbox_id.as_str(), r.key_id.as_str(), r.seal_mode.as_str()), ("m1", "vk-1", "vault"));
        assert!(rcpt_from_json("a@b.co", &json!({"accept": false, "smtp": 550})).is_none());
        assert!(rcpt_from_json("a@b.co", &json!({"accept": true, "mailbox_id": "m1", "seal_mode": "recipient_pq", "key_id": null})).is_none(), "a pq mailbox without a key id is not accepted");
    }
    struct Probe { got: Mutex<Vec<(String, Vec<u8>)>>, fail: bool }
    impl Backend for Probe {
        fn max_bytes(&self) -> usize { 2000 }
        async fn rcpt(&self, a: &str) -> Result<Rcpt, (u16, String)> { if a.starts_with("nobody@") { Err((550, "no such mailbox".into())) } else { Ok(Rcpt { addr: a.into(), mailbox_id: "m".into(), seal_mode: "vault".into(), key_id: "k".into(), pub_hex: None }) } }
        async fn deliver(&self, raw: &[u8], r: &Rcpt) -> Result<(), String> { if self.fail { return Err("db down".into()); } self.got.lock().unwrap().push((r.addr.clone(), raw.to_vec())); Ok(()) }
    }
    async fn talk(be: &Probe, script: &str) -> String {
        let script = script.to_string();
        let (a, b) = tokio::io::duplex(1 << 16);
        let h = tokio::spawn({ async move { let (mut r, mut w) = tokio::io::split(b); w.write_all(script.as_bytes()).await.unwrap(); w.shutdown().await.unwrap(); let mut o = String::new(); r.read_to_string(&mut o).await.unwrap(); o } });
        session(a, be).await; h.await.unwrap()
    }
    #[tokio::test]
    async fn full_session_one_reply_per_recipient_and_dot_unstuffing() {
        let be = Probe { got: Mutex::new(vec![]), fail: false };
        let out = talk(&be, "LHLO x\r\nMAIL FROM:<s@o.co>\r\nRCPT TO:<a@anexomail.com>\r\nRCPT TO:<nobody@anexomail.com>\r\nRCPT TO:<b@anexomail.com>\r\nDATA\r\nSubject: hi\r\n\r\n..dot\r\n.\r\nQUIT\r\n").await;
        assert!(out.starts_with("220 ")); assert!(out.contains("550 5.1.1 no such mailbox")); assert_eq!(out.matches("250 2.0.0 stored").count(), 2); assert!(out.trim_end().ends_with("221 2.0.0 bye"));
        let got = be.got.lock().unwrap(); assert_eq!(got.len(), 2); assert_eq!(got[0].0, "a@anexomail.com"); assert_eq!(String::from_utf8_lossy(&got[0].1), "Subject: hi\r\n\r\n.dot\r\n");
    }
    #[tokio::test]
    async fn order_size_and_trouble_are_answered_correctly() {
        let be = Probe { got: Mutex::new(vec![]), fail: false };
        let out = talk(&be, "RCPT TO:<a@anexomail.com>\r\nDATA\r\nMAIL FROM:<s@o.co> SIZE=999999\r\nMAIL FROM:<s@o.co>\r\nDATA\r\nSTARTTLS\r\nRSET\r\nQUIT\r\n").await;
        assert!(out.contains("503 5.5.1 MAIL first")); assert!(out.contains("503 5.5.1 need MAIL and RCPT first")); assert!(out.contains("552 5.3.4 message too big")); assert!(out.contains("500 5.5.2 command not recognised")); assert!(be.got.lock().unwrap().is_empty());
        let big = "x".repeat(3000);
        let out = talk(&be, &format!("MAIL FROM:<s@o.co>\r\nRCPT TO:<a@anexomail.com>\r\nDATA\r\n{big}\r\n.\r\nQUIT\r\n")).await;
        assert!(out.contains("552 5.3.4 message too big") && be.got.lock().unwrap().is_empty(), "an oversize mail is refused and not stored");
        let be2 = Probe { got: Mutex::new(vec![]), fail: true };
        let out = talk(&be2, "MAIL FROM:<s@o.co>\r\nRCPT TO:<a@anexomail.com>\r\nDATA\r\nSubject: z\r\n.\r\nQUIT\r\n").await;
        assert!(out.contains("451 4.3.0 try again later (db down)"), "a database failure is a temporary no: Postfix keeps the mail");
    }
    #[test]
    fn listener_refuses_a_public_address() {
        let p = |b: &str| parse_bind(Some(b.to_string()), None);
        assert!(matches!(p("0.0.0.0:2525"), Some(Err(e)) if e.contains("loopback"))); assert!(matches!(p("10.0.0.5:2525"), Some(Err(_)))); assert!(matches!(p("nonsense"), Some(Err(_))));
        assert!(matches!(p("127.0.0.1:2525"), Some(Ok(_)))); assert!(matches!(p("[::1]:2525"), Some(Ok(_)))); assert!(parse_bind(None, None).is_none()); assert!(parse_bind(Some("  ".into()), None).is_none());
    }
}
