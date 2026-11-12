//! Q1b-3 (founder mailbox): the PURE core of one mail message: parse the summary, seal it (AES-256-GCM, vault wrap or ML-KEM wrap), open it again, render it safely.
//! INHERITABLE BY AWAM (docs/claude/AWAM-INHERITS-FOUNDER-TECH-LAW-13NOV.md): no network, no database, no founder names; the awam mailbox migration lifts this file as it is.
//! The WHOLE raw RFC 822 message is the sealed body (attachments are inside it); the summary (subject, from, to, cc, date, snippet) is the sealed meta.
//! One message key per message. AAD = ("fmail-msg-v1", mailbox id, direction, blind message-id hex, part) so a sealed blob cannot be moved to another mailbox, direction or message.
//! Rendering never trusts the sender: text/plain first, HTML only as stripped text, no remote content, no scripts, ever.
use crate::fmail_seal as seal;
use mail_parser::{Address, MessageParser, MimeHeaders};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

pub const MAX_TEXT: usize = 200_000;
const AAD_TAG: &str = "fmail-msg-v1";

#[derive(Debug, Clone, Default, PartialEq)]
pub struct Summary {
    pub subject: String, pub from_addr: String, pub from_name: String, pub to: Vec<String>, pub cc: Vec<String>,
    pub date: String, pub message_id: String, pub in_reply_to: String, pub snippet: String, pub attach: usize,
}

/// Control characters out, runs of white space folded to one space, cut to `max` characters (never in the middle of a character).
pub fn clean(s: &str, max: usize) -> String {
    let mut out = String::with_capacity(s.len().min(max * 4));
    let mut last_space = true;
    for c in s.chars() {
        let c = if c.is_control() || c == '\u{2028}' || c == '\u{2029}' || c == '\u{202e}' || c == '\u{200f}' { ' ' } else { c };   // bidi override / RLM tricks are dropped too
        if c.is_whitespace() { if !last_space { out.push(' '); last_space = true; } } else { out.push(c); last_space = false; }
        if out.chars().count() >= max { break; }
    }
    out.trim().to_string()
}

fn addrs(a: Option<&Address>) -> Vec<String> { a.map(|x| x.iter().filter_map(|a| a.address()).map(|s| clean(s, 254)).filter(|s| !s.is_empty()).take(50).collect()).unwrap_or_default() }

/// Remove tags, scripts and styles, decode the few entities that matter. Output is PLAIN TEXT: the UI never receives HTML from a sender.
pub fn strip_html(h: &str) -> String {
    let mut out = String::with_capacity(h.len() / 2);
    let lower = h.to_ascii_lowercase();
    let bytes = h.as_bytes();
    let (mut i, n) = (0usize, h.len());
    while i < n {
        if bytes[i] == b'<' && bytes.get(i + 1).map_or(false, |c| c.is_ascii_alphabetic() || *c == b'/' || *c == b'!') {
            let rest = &lower[i..];
            let skip_to = |tag: &str| -> Option<usize> { rest.find(&format!("</{tag}")).map(|p| i + p) };
            if rest.starts_with("<script") { i = skip_to("script").and_then(|p| lower[p..].find('>').map(|q| p + q + 1)).unwrap_or(n); continue; }
            if rest.starts_with("<style") { i = skip_to("style").and_then(|p| lower[p..].find('>').map(|q| p + q + 1)).unwrap_or(n); continue; }
            if rest.starts_with("<!--") { i = rest.find("-->").map(|p| i + p + 3).unwrap_or(n); continue; }
            let is_break = rest.starts_with("<br") || rest.starts_with("<p") || rest.starts_with("</p") || rest.starts_with("<div") || rest.starts_with("</div") || rest.starts_with("<li") || rest.starts_with("<tr") || rest.starts_with("<h");
            i = rest.find('>').map(|p| i + p + 1).unwrap_or(n);
            if is_break { out.push('\n'); }
            continue;
        }
        let ch_len = h[i..].chars().next().map(|c| c.len_utf8()).unwrap_or(1);
        out.push_str(&h[i..i + ch_len]); i += ch_len;
    }
    let out = out.replace("&nbsp;", " ").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&amp;", "&");
    // collapse 3+ newlines, trim lines
    let mut res = String::new(); let mut nl = 0;
    for line in out.lines() { let t = line.trim_end(); if t.trim().is_empty() { nl += 1; if nl <= 1 { res.push('\n'); } } else { nl = 0; res.push_str(t.trim_start()); res.push('\n'); } }
    res.trim().to_string()
}

/// Everything the list and the sealed meta need. Never panics and never fails: an unreadable message still gets a summary ("(unreadable message)").
pub fn summarize(raw: &[u8]) -> Summary {
    let Some(m) = MessageParser::default().parse(raw) else { return Summary { subject: "(unreadable message)".into(), ..Default::default() } };
    let from = m.from().and_then(|a| a.first());
    let text = m.body_text(0).map(|t| t.into_owned()).or_else(|| m.body_html(0).map(|h| strip_html(&h))).unwrap_or_default();
    let in_reply = m.in_reply_to().as_text().map(str::to_string).or_else(|| m.in_reply_to().as_text_list().and_then(|l| l.first().map(|s| s.to_string()))).unwrap_or_default();
    Summary {
        subject: clean(m.subject().unwrap_or(""), 300),
        from_addr: from.and_then(|a| a.address()).map(|s| clean(s, 254)).unwrap_or_default(),
        from_name: from.and_then(|a| a.name()).map(|s| clean(s, 120)).unwrap_or_default(),
        to: addrs(m.to()), cc: addrs(m.cc()),
        date: m.date().map(|d| d.to_rfc3339()).unwrap_or_default(),
        message_id: clean(m.message_id().unwrap_or(""), 300), in_reply_to: clean(&in_reply, 300),
        snippet: clean(&text, 160), attach: m.attachment_count().min(100),
    }
}

pub fn summary_json(s: &Summary) -> Value {
    json!({"subject": s.subject, "from": s.from_addr, "from_name": s.from_name, "to": s.to, "cc": s.cc, "date": s.date, "message_id": s.message_id, "snippet": s.snippet, "attach": s.attach})
}

/// Safe view of a whole message for the reader: plain text only (HTML becomes stripped text), the attachment list (name, type, size), a flag that remote content was removed.
pub fn render(raw: &[u8]) -> Value {
    let Some(m) = MessageParser::default().parse(raw) else { return json!({"text": "(this message could not be read)", "had_html": false, "attachments": []}) };
    let had_html = m.body_html(0).is_some();
    let text = match m.body_text(0) { Some(t) => t.into_owned(), None => m.body_html(0).map(|h| strip_html(&h)).unwrap_or_default() };
    let mut text = text.replace('\r', "").trim().to_string();
    if text.chars().count() > MAX_TEXT { text = text.chars().take(MAX_TEXT).collect::<String>() + "\n[message cut here]"; }
    let atts: Vec<Value> = m.attachments().take(100).map(|p| json!({
        "name": clean(p.attachment_name().unwrap_or("attachment"), 200),
        "type": p.content_type().map(|c| format!("{}/{}", c.ctype(), c.subtype().unwrap_or("octet-stream"))).unwrap_or_else(|| "application/octet-stream".into()),
        "size": p.contents().len()})).collect();
    json!({"text": text, "had_html": had_html, "remote_content_blocked": had_html, "attachments": atts})
}

pub fn hex(b: &[u8]) -> String { hex::encode(b) }

/// AAD of one sealed part. `part` is "meta" or "body".
pub fn part_aad(mailbox_id: &str, direction: &str, msgid_hex: &str, part: &str) -> Vec<u8> { seal::aad(&[AAD_TAG, mailbox_id, direction, msgid_hex, part]) }
/// The hash the database stores in fmail_messages.aad_hash (the base AAD without the part).
pub fn base_aad_hash(mailbox_id: &str, direction: &str, msgid_hex: &str) -> [u8; 32] { seal::aad_hash(&seal::aad(&[AAD_TAG, mailbox_id, direction, msgid_hex])) }

/// The columns of one sealed message exactly as fmail_deliver_inbound takes them.
#[derive(Debug, Clone)]
pub struct Sealed {
    pub sealed_body: Vec<u8>, pub sealed_meta: Vec<u8>, pub nonce_body: [u8; 12], pub nonce_meta: [u8; 12], pub key_id: String, pub key_wrap: Vec<u8>, pub aad_hash: [u8; 32],
    pub msgid_blind: [u8; 32], pub parent_blind: Option<[u8; 32]>, pub subject_blind: [u8; 32], pub sender_blind: Option<[u8; 32]>, pub sender_domain: Option<String>,
}

/// How the per-message key is wrapped: `Vault` = AES-256-GCM under the vault master (the server can open it again after an authenticated, touch-gated request),
/// `Recipient` = ML-KEM-768 + X25519 hybrid (only the owner of the private halves can open it: the server cannot).
pub enum Wrap<'a> { Vault { master: &'a seal::Key, key_id: &'a str }, Recipient { public: &'a [u8], key_id: &'a str } }

fn domain_of(addr: &str) -> Option<String> {
    let d = addr.rsplit_once('@')?.1.to_ascii_lowercase();
    if d.is_empty() || d.len() > 253 || !d.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'-') { None } else { Some(d) }
}

/// Seal one message. `blind_master` is the vault master (the blind-index key of the mailbox is derived from it, whatever the wrap mode is).
pub fn seal_message(blind_master: &seal::Key, mailbox_id: &str, direction: &str, wrap: Wrap, raw: &[u8], s: &Summary) -> Result<Sealed, &'static str> {
    let bk = seal::blind_key(blind_master, mailbox_id)?;
    let mid = seal::norm_msgid(&s.message_id);
    let mid = if mid.is_empty() { format!("raw-{}", hex(&Sha256::digest(raw))) } else { mid };
    let msgid_blind = seal::blind(&bk, "msgid", &mid);
    let msgid_hex = hex(&msgid_blind);
    let key = seal::new_key()?;
    let (nonce_meta, sealed_meta) = seal::seal(&key, &part_aad(mailbox_id, direction, &msgid_hex, "meta"), summary_json(s).to_string().as_bytes())?;
    let (nonce_body, sealed_body) = seal::seal(&key, &part_aad(mailbox_id, direction, &msgid_hex, "body"), raw)?;
    let (key_id, key_wrap) = match wrap {
        Wrap::Vault { master, key_id } => (key_id.to_string(), seal::wrap_vault(master, key_id, &key)?),
        Wrap::Recipient { public, key_id } => (key_id.to_string(), crate::fmail_kem::wrap(public, key_id, &key)?),
    };
    let parent = seal::norm_msgid(&s.in_reply_to);
    Ok(Sealed {
        sealed_body, sealed_meta, nonce_body, nonce_meta, key_id, key_wrap, aad_hash: base_aad_hash(mailbox_id, direction, &msgid_hex), msgid_blind,
        parent_blind: if parent.is_empty() { None } else { Some(seal::blind(&bk, "msgid", &parent)) },
        subject_blind: seal::blind(&bk, "subject", &seal::norm_subject(&s.subject)),
        sender_blind: if s.from_addr.is_empty() { None } else { Some(seal::blind(&bk, "sender", &seal::norm_addr(&s.from_addr))) },
        sender_domain: domain_of(&s.from_addr),
    })
}

/// What the database returned for one vault-mode message (all fields as the SQL doors give them: base64 / hex text).
pub struct Row<'a> { pub mailbox_id: &'a str, pub direction: &'a str, pub key_id: &'a str, pub msgid_hex: &'a str, pub aad_hash_hex: &'a str, pub key_wrap: &'a [u8], pub nonce_meta: &'a [u8], pub meta: &'a [u8],
                     pub body: Option<(&'a [u8], &'a [u8])> }

/// Open a vault-mode message: checks the stored AAD hash first, then the key wrap, then each part. Any failure = Err (never partial plaintext).
pub fn open_vault(master: &seal::Key, r: &Row) -> Result<(Value, Option<Vec<u8>>), &'static str> {
    if hex(&base_aad_hash(r.mailbox_id, r.direction, r.msgid_hex)) != r.aad_hash_hex { return Err("this message does not belong where it is stored"); }
    let key = seal::unwrap_vault(master, r.key_id, r.key_wrap).ok_or("the message key cannot be unwrapped")?;
    let meta = seal::open(&key, r.nonce_meta, &part_aad(r.mailbox_id, r.direction, r.msgid_hex, "meta"), r.meta).ok_or("the sealed summary does not verify")?;
    let meta: Value = serde_json::from_slice(&meta).map_err(|_| "the sealed summary is not valid")?;
    let body = match r.body { Some((nonce, ct)) => Some(seal::open(&key, nonce, &part_aad(r.mailbox_id, r.direction, r.msgid_hex, "body"), ct).ok_or("the sealed message does not verify")?), None => None };
    Ok((meta, body))
}

#[cfg(test)]
mod tests {
    use super::*;
    const MBOX: &str = "0b9d1c2e-0000-4000-8000-000000000001";
    fn raw() -> Vec<u8> {
        b"From: =?UTF-8?B?SGFuYSBPcnRlZ2E=?= <hana@example.org>\r\nTo: nauman@anexomail.com, b@example.com\r\nCc: c@example.com\r\nSubject: =?UTF-8?Q?Seminar_contract=3A_clause_7?=\r\nMessage-ID: <Abc123@Example.ORG>\r\nIn-Reply-To: <prev@example.org>\r\nDate: Fri, 13 Nov 2026 09:41:00 +0500\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nClause 7 needs one change:\r\n30 days, not 14.\r\n".to_vec()
    }
    #[test]
    fn summary_decodes_headers_and_never_panics() {
        let s = summarize(&raw());
        assert_eq!(s.subject, "Seminar contract: clause 7"); assert_eq!(s.from_addr, "hana@example.org"); assert_eq!(s.from_name, "Hana Ortega");
        assert_eq!(s.to, vec!["nauman@anexomail.com", "b@example.com"]); assert_eq!(s.cc, vec!["c@example.com"]); assert_eq!(s.message_id, "Abc123@Example.ORG");
        assert!(s.snippet.starts_with("Clause 7 needs one change: 30 days")); assert!(s.date.starts_with("2026-11-13"));
        for junk in [&b""[..], b"\x00\x01\x02garbage", b"Subject: x\r\n", &[0xff; 4000][..]] { let _ = summarize(junk); let _ = render(junk); }
    }
    #[test]
    fn control_and_bidi_tricks_are_removed() {
        assert_eq!(clean("a\u{0}b\r\n\tc\u{202e}d", 50), "a b c d");
        assert_eq!(clean("  x   y  ", 50), "x y"); assert_eq!(clean("abcdef", 3), "abc");
    }
    #[test]
    fn html_becomes_plain_text_without_scripts_styles_or_tags() {
        let h = "<html><head><style>p{x:y}</style></head><body><script>alert(1)</script><p>Hello &amp; <b>welcome</b></p><img src=\"http://track.example/p.gif\"><div>Line two</div><!-- hidden --></body></html>";
        let t = strip_html(h);
        assert!(t.contains("Hello & welcome") && t.contains("Line two")); assert!(!t.contains("alert") && !t.contains("track.example") && !t.contains("hidden") && !t.contains('<'));
        assert_eq!(strip_html("<script>never closed"), ""); assert_eq!(strip_html("a < b"), "a < b");
        let _ = strip_html("<<<<>>>> é<p");
    }
    #[test]
    fn render_blocks_remote_content_and_lists_attachments() {
        let m = b"From: a@b.co\r\nSubject: s\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary=XX\r\n\r\n--XX\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<p>Hi <img src=\"http://t.example/x.gif\"></p>\r\n--XX\r\nContent-Type: application/pdf; name=\"c.pdf\"\r\nContent-Disposition: attachment; filename=\"c.pdf\"\r\nContent-Transfer-Encoding: base64\r\n\r\nJVBERi0xLjQK\r\n--XX--\r\n";
        let v = render(m);
        assert_eq!(v["text"], "Hi"); assert_eq!(v["remote_content_blocked"], true);
        assert_eq!(v["attachments"][0]["name"], "c.pdf"); assert_eq!(v["attachments"][0]["type"], "application/pdf"); assert_eq!(v["attachments"][0]["size"], 9);
    }
    fn master() -> seal::Key { [7u8; 32] }
    #[test]
    fn vault_seal_then_open_roundtrip_and_blind_indexes_are_stable() {
        let s = summarize(&raw()); let m = master();
        let a = seal_message(&m, MBOX, "in", Wrap::Vault { master: &m, key_id: "vk-1" }, &raw(), &s).unwrap();
        let b = seal_message(&m, MBOX, "in", Wrap::Vault { master: &m, key_id: "vk-1" }, &raw(), &s).unwrap();
        assert_eq!(a.msgid_blind, b.msgid_blind, "the same Message-ID always gives the same blind index (duplicate detection)"); assert_ne!(a.sealed_body, b.sealed_body, "fresh key and nonce every time");
        assert_eq!(a.sender_domain.as_deref(), Some("example.org")); assert!(a.parent_blind.is_some());
        let mh = hex(&a.msgid_blind);
        let row = Row { mailbox_id: MBOX, direction: "in", key_id: "vk-1", msgid_hex: &mh, aad_hash_hex: &hex(&a.aad_hash), key_wrap: &a.key_wrap, nonce_meta: &a.nonce_meta, meta: &a.sealed_meta, body: Some((&a.nonce_body, &a.sealed_body)) };
        let (meta, body) = open_vault(&m, &row).unwrap();
        assert_eq!(meta["subject"], "Seminar contract: clause 7"); assert_eq!(body.unwrap(), raw());
        assert!(!String::from_utf8_lossy(&a.sealed_body).contains("Clause 7") && !String::from_utf8_lossy(&a.sealed_meta).contains("Seminar"), "no plain text in what the database stores");
    }
    #[test]
    fn a_sealed_message_cannot_be_moved_or_tampered_with() {
        let s = summarize(&raw()); let m = master();
        let a = seal_message(&m, MBOX, "in", Wrap::Vault { master: &m, key_id: "vk-1" }, &raw(), &s).unwrap(); let mh = hex(&a.msgid_blind); let ah = hex(&a.aad_hash);
        let mk = |mbox: &'static str, dir: &'static str, kid: &'static str, wrap: &Vec<u8>, ct: &Vec<u8>| -> Result<(Value, Option<Vec<u8>>), &'static str> {
            let r = Row { mailbox_id: mbox, direction: dir, key_id: kid, msgid_hex: &mh, aad_hash_hex: &ah, key_wrap: wrap, nonce_meta: &a.nonce_meta, meta: ct, body: None }; open_vault(&m, &r) };
        assert!(mk(MBOX, "in", "vk-1", &a.key_wrap, &a.sealed_meta).is_ok());
        assert!(mk("0b9d1c2e-0000-4000-8000-000000000002", "in", "vk-1", &a.key_wrap, &a.sealed_meta).is_err(), "another mailbox");
        assert!(mk(MBOX, "out", "vk-1", &a.key_wrap, &a.sealed_meta).is_err(), "another direction");
        assert!(mk(MBOX, "in", "vk-2", &a.key_wrap, &a.sealed_meta).is_err(), "another key id");
        let mut bad = a.sealed_meta.clone(); bad[0] ^= 1; assert!(mk(MBOX, "in", "vk-1", &a.key_wrap, &bad).is_err(), "flipped bit");
        let mut badw = a.key_wrap.clone(); badw[5] ^= 1; assert!(mk(MBOX, "in", "vk-1", &badw, &a.sealed_meta).is_err(), "flipped wrap");
        assert!(open_vault(&[8u8; 32], &Row { mailbox_id: MBOX, direction: "in", key_id: "vk-1", msgid_hex: &mh, aad_hash_hex: &ah, key_wrap: &a.key_wrap, nonce_meta: &a.nonce_meta, meta: &a.sealed_meta, body: None }).is_err(), "another master key");
    }
    #[test]
    fn a_message_without_a_message_id_still_dedupes_on_its_content() {
        let r = b"From: a@b.co\r\nSubject: x\r\n\r\nbody".to_vec(); let s = summarize(&r); let m = master();
        let a = seal_message(&m, MBOX, "in", Wrap::Vault { master: &m, key_id: "vk-1" }, &r, &s).unwrap();
        let b = seal_message(&m, MBOX, "in", Wrap::Vault { master: &m, key_id: "vk-1" }, &r, &s).unwrap();
        assert_eq!(a.msgid_blind, b.msgid_blind);
    }
}
