//! Q1d (founder mailbox): the PURE side of writing a mail: validate what the person typed, build the RFC 5322 / MIME message, read the envelope back, strip Bcc for the wire,
//! dot-stuff for SMTP DATA, and the touch target that binds a passkey touch to the exact mail.
//! INHERITABLE BY AWAM (docs/claude/AWAM-INHERITS-FOUNDER-TECH-LAW-13NOV.md): no network, no database, no founder names.
//! Technology: Rust. Safety first: a CR or LF in ANY header value is refused (header injection), addresses are checked by a strict grammar (no quoted local parts, no comments, no IP literals),
//! non-ASCII text goes out as RFC 2047 encoded words / UTF-8 base64 body, the body is base64 so no line can ever be a lone "." or contain a bare CR.
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use mail_parser::MessageParser;
use serde_json::Value;
use sha2::{Digest, Sha256};

pub const MAX_RCPT: usize = 100;
pub const MAX_SUBJECT: usize = 300;
pub const MAX_TEXT: usize = 2 * 1024 * 1024;

#[derive(Debug, Clone, PartialEq, Default)]
pub struct Compose {
    pub to: Vec<String>, pub cc: Vec<String>, pub bcc: Vec<String>, pub subject: String, pub text: String,
    pub in_reply_to: Option<String>, pub references: Vec<String>,
}

/// Strict address grammar: dot-atom local part (letters digits . _ % + - , <= 64), a hostname with at least one dot (labels <= 63, whole <= 253). Lower-cased. No quotes, no comments, no IP literals.
pub fn norm_addr(a: &str) -> Option<String> {
    let a = a.trim().to_ascii_lowercase();
    let (l, d) = a.split_once('@')?;
    if l.is_empty() || l.len() > 64 || d.len() > 253 || l.starts_with('.') || l.ends_with('.') || l.contains("..") { return None; }
    if !l.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'%' | b'+' | b'-')) { return None; }
    let labels: Vec<&str> = d.split('.').collect();
    if labels.len() < 2 { return None; }
    for lb in &labels { if lb.is_empty() || lb.len() > 63 || lb.starts_with('-') || lb.ends_with('-') || !lb.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') { return None; } }
    if labels.last().map_or(true, |t| t.len() < 2 || t.bytes().all(|b| b.is_ascii_digit())) { return None; }
    Some(a)
}
pub fn domain_of(a: &str) -> &str { a.rsplit_once('@').map_or("", |x| x.1) }

fn no_ctl(s: &str) -> bool { !s.chars().any(|c| c.is_control() && c != '\t') && !s.contains('\u{2028}') && !s.contains('\u{2029}') && !s.contains('\u{202e}') }
fn msgid_ok(s: &str) -> bool {
    let t = s.trim().trim_start_matches('<').trim_end_matches('>');
    !t.is_empty() && t.len() <= 200 && t.contains('@') && t.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'%' | b'+' | b'-' | b'@' | b'=' | b'$' | b'~'))
}

fn list(v: &Value, k: &str) -> Result<Vec<String>, &'static str> {
    let Some(a) = v.get(k) else { return Ok(vec![]) };
    let a = a.as_array().ok_or("recipients must be a list")?;
    let mut out: Vec<String> = Vec::new();
    for x in a { let s = x.as_str().ok_or("a recipient must be text")?; let n = norm_addr(s).ok_or("an address is not valid")?; if !out.contains(&n) { out.push(n); } }
    Ok(out)
}

/// Parse and validate the JSON the Compose form posts. `own` = the mailbox address (never a recipient of its own send by accident? it is allowed: sending to yourself is legal).
pub fn parse_compose(v: &Value) -> Result<Compose, &'static str> {
    let (to, cc, bcc) = (list(v, "to")?, list(v, "cc")?, list(v, "bcc")?);
    if to.is_empty() { return Err("add at least one recipient in To"); }
    let mut all: Vec<&String> = to.iter().chain(cc.iter()).chain(bcc.iter()).collect(); all.sort(); all.dedup();
    if all.len() > MAX_RCPT { return Err("too many recipients"); }
    let subject = v.get("subject").and_then(|x| x.as_str()).unwrap_or("").trim().to_string();
    if subject.chars().count() > MAX_SUBJECT { return Err("the subject is too long"); }
    if !no_ctl(&subject) { return Err("the subject has a control character"); }
    let text = v.get("text").and_then(|x| x.as_str()).unwrap_or("").to_string();
    if text.len() > MAX_TEXT { return Err("the message is too long"); }
    if text.contains('\0') { return Err("the message has a NUL character"); }
    if subject.is_empty() && text.trim().is_empty() { return Err("an empty mail with no subject is not sent"); }
    let in_reply_to = match v.get("in_reply_to").and_then(|x| x.as_str()) { Some(s) if !s.is_empty() => { if !msgid_ok(s) { return Err("in_reply_to is not a Message-ID"); } Some(s.trim().trim_start_matches('<').trim_end_matches('>').to_string()) } _ => None };
    let mut references = Vec::new();
    if let Some(a) = v.get("references").and_then(|x| x.as_array()) { for r in a.iter().take(20) { let s = r.as_str().ok_or("a reference must be text")?; if !msgid_ok(s) { return Err("a reference is not a Message-ID"); } references.push(s.trim().trim_start_matches('<').trim_end_matches('>').to_string()); } }
    Ok(Compose { to, cc, bcc, subject, text, in_reply_to, references })
}

// ---------------------------------------------------------------- building

/// RFC 2047 encoded words (UTF-8, base64) of at most 45 source bytes each, never cut inside a character. ASCII without specials is returned as is.
pub fn encode_word(s: &str) -> String {
    if s.bytes().all(|b| (0x20..0x7f).contains(&b) && !matches!(b, b'=' | b'?' | b'"' | b'\\')) { return s.to_string(); }
    let mut parts: Vec<String> = Vec::new(); let mut cur = String::new();
    for c in s.chars() { if cur.len() + c.len_utf8() > 45 { parts.push(std::mem::take(&mut cur)); } cur.push(c); }
    if !cur.is_empty() { parts.push(cur); }
    parts.iter().map(|p| format!("=?utf-8?B?{}?=", B64.encode(p.as_bytes()))).collect::<Vec<_>>().join("\r\n ")
}
fn fold_list(prefix: &str, items: &[String]) -> String {
    let mut out = String::from(prefix); let mut col = prefix.len();
    for (i, it) in items.iter().enumerate() {
        let piece = if i + 1 < items.len() { format!("{it},") } else { it.clone() };
        if i > 0 { if col + 1 + piece.len() > 76 { out.push_str("\r\n "); col = 1; } else { out.push(' '); col += 1; } }
        out.push_str(&piece); col += piece.len();
    }
    out
}
/// `Fri, 13 Nov 2026 03:00:00 +0000` from a unix time (UTC).
pub fn rfc2822(unix: u64) -> String {
    let (days, rem) = ((unix / 86400) as i64, unix % 86400);
    let (h, mi, s) = (rem / 3600, (rem % 3600) / 60, rem % 60);
    let z = days + 719468; let era = z.div_euclid(146097); let doe = z.rem_euclid(146097);
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365; let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100); let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1; let m = if mp < 10 { mp + 3 } else { mp - 9 }; let y = if m <= 2 { y + 1 } else { y };
    const WD: [&str; 7] = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"]; const MN: [&str; 12] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    format!("{}, {:02} {} {} {:02}:{:02}:{:02} +0000", WD[(days.rem_euclid(7)) as usize], d, MN[(m - 1) as usize], y, h, mi, s)
}
/// A fresh Message-ID on the sender's own domain: 128 random bits.
pub fn new_message_id(domain: &str) -> Result<String, &'static str> {
    use ring::rand::{SecureRandom, SystemRandom};
    let mut b = [0u8; 16]; SystemRandom::new().fill(&mut b).map_err(|_| "random failed")?;
    Ok(format!("{}@{}", hex::encode(b), domain))
}

/// The message exactly as it is stored (sealed) and sent. `from_name` may be empty. Bcc is written too: it is the sender's own copy; `strip_bcc` removes it for the wire.
pub fn build(c: &Compose, from_addr: &str, from_name: &str, message_id: &str, unix: u64) -> Result<Vec<u8>, &'static str> {
    if norm_addr(from_addr).as_deref() != Some(from_addr) { return Err("the sender address is not valid"); }
    if !no_ctl(from_name) || from_name.chars().count() > 120 { return Err("the display name is not valid"); }
    if !msgid_ok(message_id) { return Err("bad Message-ID"); }
    let mut h = String::new();
    let from = if from_name.trim().is_empty() { from_addr.to_string() } else { format!("{} <{}>", encode_word(from_name.trim()), from_addr) };
    h.push_str(&format!("From: {from}\r\n"));
    h.push_str(&fold_list("To: ", &c.to)); h.push_str("\r\n");
    if !c.cc.is_empty() { h.push_str(&fold_list("Cc: ", &c.cc)); h.push_str("\r\n"); }
    if !c.bcc.is_empty() { h.push_str(&fold_list("Bcc: ", &c.bcc)); h.push_str("\r\n"); }
    h.push_str(&format!("Subject: {}\r\n", encode_word(&c.subject)));
    h.push_str(&format!("Date: {}\r\nMessage-ID: <{message_id}>\r\n", rfc2822(unix)));
    if let Some(r) = &c.in_reply_to { h.push_str(&format!("In-Reply-To: <{r}>\r\n")); }
    if !c.references.is_empty() { h.push_str(&fold_list("References: ", &c.references.iter().map(|r| format!("<{r}>")).collect::<Vec<_>>())); h.push_str("\r\n"); }
    h.push_str("MIME-Version: 1.0\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n");
    let body = c.text.replace("\r\n", "\n").replace('\r', "\n").replace('\n', "\r\n");
    let enc = B64.encode(body.as_bytes());
    for chunk in enc.as_bytes().chunks(76) { h.push_str(std::str::from_utf8(chunk).unwrap_or("")); h.push_str("\r\n"); }
    Ok(h.into_bytes())
}

// ---------------------------------------------------------------- reading it back for the wire

/// (From address, deduplicated To+Cc+Bcc addresses). Mail that has no valid From or no recipient is refused.
pub fn envelope(raw: &[u8]) -> Result<(String, Vec<String>), &'static str> {
    let m = MessageParser::default().parse(raw).ok_or("the stored message does not parse")?;
    let from = m.from().and_then(|a| a.first()).and_then(|a| a.address()).and_then(norm_addr).ok_or("the message has no valid From")?;
    let mut out: Vec<String> = Vec::new();
    for a in [m.to(), m.cc(), m.bcc()].into_iter().flatten() { for x in a.iter() { if let Some(n) = x.address().and_then(norm_addr) { if !out.contains(&n) { out.push(n); } } } }
    if out.is_empty() { return Err("the message has no recipient"); }
    Ok((from, out))
}
/// Remove the Bcc header (and its folded lines) from the header block. The body is untouched.
pub fn strip_bcc(raw: &[u8]) -> Vec<u8> {
    let end = raw.windows(4).position(|w| w == b"\r\n\r\n").map_or(raw.len(), |i| i + 2);
    let (head, rest) = raw.split_at(end);
    let mut out: Vec<u8> = Vec::with_capacity(raw.len()); let mut skipping = false;
    for line in head.split_inclusive(|b| *b == b'\n') {
        let cont = line.first().map_or(false, |b| *b == b' ' || *b == b'\t');
        if cont { if skipping { continue; } } else { skipping = line.len() >= 4 && line[..4].eq_ignore_ascii_case(b"bcc:"); }
        if !skipping { out.extend_from_slice(line); }
    }
    out.extend_from_slice(rest); out
}
/// SMTP DATA payload: CRLF line ends, a leading "." doubled, ends with CRLF + "." + CRLF.
pub fn data_payload(raw: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(raw.len() + 16); let mut at_line_start = true; let mut i = 0;
    while i < raw.len() {
        let b = raw[i];
        if b == b'\r' && raw.get(i + 1) == Some(&b'\n') { out.extend_from_slice(b"\r\n"); at_line_start = true; i += 2; continue; }
        if b == b'\n' { out.extend_from_slice(b"\r\n"); at_line_start = true; i += 1; continue; }
        if b == b'\r' { out.extend_from_slice(b"\r\n"); at_line_start = true; i += 1; continue; }
        if at_line_start && b == b'.' { out.push(b'.'); }
        out.push(b); at_line_start = false; i += 1;
    }
    if !out.ends_with(b"\r\n") { out.extend_from_slice(b"\r\n"); }
    out.extend_from_slice(b".\r\n"); out
}

/// The touch target of a send: SHA-256 over the length-prefixed fields (mailbox, to, cc, bcc, subject, text, schedule), 64 hex. The browser computes the SAME value (mail_pure.ts sendTarget)
/// and asks for a touch on it, so a touch given for one mail can never send another. List order is the order typed (the server does not re-sort).
pub fn send_target(mailbox: &str, c: &Compose, schedule: &str) -> String {
    let mut h = Sha256::new();
    let mut f = |s: &str| { h.update((s.len() as u64).to_be_bytes()); h.update(s.as_bytes()); };
    f("fmail-send-v1"); f(mailbox); f(&c.to.join(",")); f(&c.cc.join(",")); f(&c.bcc.join(",")); f(&c.subject); f(&c.text); f(schedule);
    hex::encode(h.finalize())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test] fn addresses() {
        assert_eq!(norm_addr(" A.B+c@Example.ORG ").as_deref(), Some("a.b+c@example.org"));
        for bad in ["", "a", "a@b", "a@b.c", "@x.com", "a b@x.com", "a@x..com", "\"a\"@x.com", "a@[127.0.0.1]", "a@x.com\r\nBcc: z@z.com", ".a@x.com", "a.@x.com", "a@-x.com", "a@x.123", "<a@x.com>"] { assert!(norm_addr(bad).is_none(), "{bad:?}"); }
    }
    #[test] fn parse_refuses_injection_and_empties() {
        let ok = json!({"to": ["A@x.com", "a@x.com"], "subject": "Hi", "text": "hello"});
        let c = parse_compose(&ok).unwrap(); assert_eq!(c.to, vec!["a@x.com"]);
        assert!(parse_compose(&json!({"to": [], "subject": "x"})).is_err());
        assert!(parse_compose(&json!({"to": ["a@x.com"], "subject": "x\r\nBcc: evil@x.com"})).is_err());
        assert!(parse_compose(&json!({"to": ["a@x.com\r\nBcc: e@x.com"], "subject": "x"})).is_err());
        assert!(parse_compose(&json!({"to": ["a@x.com"], "subject": "", "text": "  "})).is_err());
        assert!(parse_compose(&json!({"to": ["a@x.com"], "subject": "x", "text": "a\0b"})).is_err());
        assert!(parse_compose(&json!({"to": ["a@x.com"], "subject": "x", "in_reply_to": "<a b@x>"})).is_err());
        let many: Vec<String> = (0..101).map(|i| format!("u{i}@x.com")).collect();
        assert!(parse_compose(&json!({"to": many, "subject": "x"})).is_err());
        assert!(parse_compose(&json!({"to": ["a@x.com"], "subject": "x".repeat(301)})).is_err());
    }
    #[test] fn dates() {
        assert_eq!(rfc2822(0), "Thu, 01 Jan 1970 00:00:00 +0000");
        assert_eq!(rfc2822(1_794_538_800), "Fri, 13 Nov 2026 03:00:00 +0000");
        assert_eq!(rfc2822(951_782_400), "Tue, 29 Feb 2000 00:00:00 +0000");
    }
    #[test] fn encoded_words() {
        assert_eq!(encode_word("Hello world"), "Hello world");
        let e = encode_word("Ahmed \u{0627}\u{062d}\u{0645}\u{062f} café"); assert!(e.starts_with("=?utf-8?B?"));
        for part in e.split("\r\n ") { assert!(part.len() <= 75, "{part}"); }
        assert!(encode_word("a=b").starts_with("=?utf-8?B?"));
        let long = "é".repeat(100); for part in encode_word(&long).split("\r\n ") { let inner = part.trim_start_matches("=?utf-8?B?").trim_end_matches("?="); assert!(String::from_utf8(B64.decode(inner).unwrap()).is_ok()); }
    }
    fn sample() -> Compose { parse_compose(&json!({"to": ["a@x.com", "b@y.org"], "cc": ["c@z.net"], "bcc": ["secret@h.io"], "subject": "Grüße \u{0627}", "text": "Line one\n.dot line\r\nlast", "in_reply_to": "<p1@x.com>", "references": ["<p0@x.com>", "p1@x.com"]})).unwrap() }
    #[test] fn build_parse_round_trip_and_bcc_strip() {
        let c = sample(); let raw = build(&c, "me@anexomail.com", "Nauman S", "abc@anexomail.com", 1_794_538_800).unwrap();
        let s = String::from_utf8(raw.clone()).unwrap(); assert!(s.contains("\r\nBcc: secret@h.io\r\n")); assert!(!s.contains("\r\r")); assert!(s.lines().all(|l| l.len() <= 998));
        let (from, rc) = envelope(&raw).unwrap(); assert_eq!(from, "me@anexomail.com"); assert_eq!(rc, vec!["a@x.com", "b@y.org", "c@z.net", "secret@h.io"]);
        let wire = strip_bcc(&raw); let ws = String::from_utf8(wire.clone()).unwrap(); assert!(!ws.to_lowercase().contains("bcc:")); assert!(!ws.contains("secret@h.io")); assert!(ws.contains("To: a@x.com,"));
        let m = MessageParser::default().parse(&wire).unwrap();
        assert_eq!(m.subject(), Some("Grüße \u{0627}")); assert_eq!(m.body_text(0).unwrap().replace("\r\n", "\n"), "Line one\n.dot line\nlast");
        assert_eq!(m.message_id(), Some("abc@anexomail.com")); assert_eq!(m.in_reply_to().as_text(), Some("p1@x.com"));
    }
    #[test] fn strip_bcc_handles_folded_and_case() {
        let raw = b"From: a@x.com\r\nBCC: one@x.com,\r\n two@x.com\r\nTo: t@x.com\r\n\r\nBcc: in body stays\r\n";
        let w = String::from_utf8(strip_bcc(raw)).unwrap(); assert_eq!(w, "From: a@x.com\r\nTo: t@x.com\r\n\r\nBcc: in body stays\r\n");
    }
    #[test] fn data_payload_stuffs_dots_and_terminates() {
        assert_eq!(data_payload(b"a\n.b\n..c\n"), b"a\r\n..b\r\n...c\r\n.\r\n");
        assert_eq!(data_payload(b".x"), b"..x\r\n.\r\n");
        assert_eq!(data_payload(b"a\rb\r\n"), b"a\r\nb\r\n.\r\n");
        let body = build(&sample(), "me@anexomail.com", "", "m@anexomail.com", 1).unwrap();
        let p = data_payload(&body); assert!(p.ends_with(b"\r\n.\r\n")); assert!(!p[..p.len() - 3].windows(5).any(|w| w == b"\r\n.\r\n"), "no early terminator");
    }
    #[test] fn refuses_bad_sender_or_name() {
        let c = sample();
        assert!(build(&c, "ME@anexomail.com", "", "a@b.c", 1).is_err()); assert!(build(&c, "me@anexomail.com", "x\r\nBcc: e@x.com", "a@b.c", 1).is_err()); assert!(build(&c, "me@anexomail.com", "", "bad id@b.c", 1).is_err());
    }
    #[test] fn send_target_binds_every_field() {
        let c = sample(); let t = send_target("mb1", &c, "");
        assert_eq!(t.len(), 64); assert_eq!(t, send_target("mb1", &c, ""));
        let mut d = c.clone(); d.text.push('x'); assert_ne!(t, send_target("mb1", &d, ""));
        let mut d = c.clone(); d.bcc.push("z@z.com".into()); assert_ne!(t, send_target("mb1", &d, ""));
        let mut d = c.clone(); d.subject.push('x'); assert_ne!(t, send_target("mb1", &d, ""));
        assert_ne!(t, send_target("mb2", &c, "")); assert_ne!(t, send_target("mb1", &c, "2026-12-01T00:00:00Z"));
        // length prefixes: moving a byte between two fields changes the hash
        let mut a = c.clone(); a.subject = "ab".into(); a.text = "c".into(); let mut b = c.clone(); b.subject = "a".into(); b.text = "bc".into(); assert_ne!(send_target("m", &a, ""), send_target("m", &b, ""));
    }
    #[test] fn send_target_golden_vectors_match_the_browser() {
        let a = Compose { to: vec!["a@x.com".into()], subject: "Hi".into(), text: "body".into(), ..Default::default() };
        assert_eq!(send_target("mb1", &a, ""), "9ffbc152919d43cc0c97cc688c722fb24361db540ebde020685ca9e6fe36f523");
        let b = Compose { to: vec!["a@x.com".into(), "b@y.org".into()], bcc: vec!["c@z.net".into()], subject: "Gr\u{fc}\u{df}e".into(), text: "line\n.dot".into(), ..Default::default() };
        assert_eq!(send_target("mb1", &b, "2026-12-01T00:00:00Z"), "2e90639f113e4e64ce55ea935cd21b045d89fd1e4bf17d383c91b11f02821140");
    }
    #[test] fn message_id_is_unique_and_valid() { let (a, b) = (new_message_id("anexomail.com").unwrap(), new_message_id("anexomail.com").unwrap()); assert_ne!(a, b); assert!(msgid_ok(&a)); }
}
