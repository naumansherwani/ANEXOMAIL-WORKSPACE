// ============================================================================
// mail_core.rs — std-only half of B3 (R1): outbound mail on Rust. MIME build, attachments wrap, local-Postfix SMTP submit.
// Behaviour is the SAME as server/mail/sendmail.ts + attachments.ts (proved by mail-proof.py: Bun and Rust bytes compared on a
// capture SMTP server), plus loopholes closed: every address is shape-checked (CR/LF/space/<>/quote can never reach a header or
// an SMTP command), recipients are capped, From-name is quoted when it holds specials, no unbounded reads.
// Only `std` — unit-tested with plain `rustc --test` by the installer, before anything is built.
// ============================================================================

use std::io::{Read, Write};
use std::net::{TcpStream, ToSocketAddrs};
use std::time::Duration;

pub const DOMAIN: &str = "anexomail.com";
pub const MAX_RCPT: usize = 100;
pub const MAX_ATTACH: usize = 50;

// ── base64 / percent / names ────────────────────────────────────────────────
const B64: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

pub fn b64(data: &[u8]) -> String {
    let mut out = String::with_capacity(data.len().div_ceil(3) * 4);
    for c in data.chunks(3) {
        let n = (c[0] as u32) << 16 | (*c.get(1).unwrap_or(&0) as u32) << 8 | *c.get(2).unwrap_or(&0) as u32;
        out.push(B64[(n >> 18) as usize & 63] as char);
        out.push(B64[(n >> 12) as usize & 63] as char);
        out.push(if c.len() > 1 { B64[(n >> 6) as usize & 63] as char } else { '=' });
        out.push(if c.len() > 2 { B64[n as usize & 63] as char } else { '=' });
    }
    out
}

/// 76-char lines joined by CRLF (same as attachments.ts b64Lines).
pub fn b64_lines(data: &[u8]) -> String {
    let s = b64(data);
    let mut out = String::with_capacity(s.len() + s.len() / 76 * 2);
    for (i, ch) in s.as_bytes().chunks(76).enumerate() {
        if i > 0 {
            out.push_str("\r\n");
        }
        out.push_str(std::str::from_utf8(ch).unwrap_or(""));
    }
    out
}

pub fn pct(s: &str) -> String {
    let mut o = String::new();
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') {
            o.push(b as char);
        } else {
            o.push_str(&format!("%{:02X}", b));
        }
    }
    o
}

/// Control chars, bidi/zero-width marks, quote, slash, backslash -> "_" (same set as attachments.ts cleanName).
pub fn clean_name(n: &str) -> String {
    let s: String = n
        .chars()
        .map(|c| {
            let u = c as u32;
            if u < 0x20
                || u == 0x7f
                || (0x200b..=0x200f).contains(&u)
                || (0x202a..=0x202e).contains(&u)
                || (0x2060..=0x2069).contains(&u)
                || u == 0xfeff
                || c == '"'
                || c == '\\'
                || c == '/'
            {
                '_'
            } else {
                c
            }
        })
        .collect();
    let t = s.trim();
    if t.is_empty() { "file".to_string() } else { t.to_string() }
}

pub fn ascii_name(n: &str) -> String {
    n.chars().map(|c| if (' '..='~').contains(&c) && c != '"' { c } else { '_' }).collect()
}

pub fn clean_mime(m: &str) -> String {
    let v = m.split(';').next().unwrap_or("").trim().to_lowercase();
    let b = v.as_bytes();
    let slash = v.find('/');
    let ok = v.len() <= 100
        && slash.is_some_and(|i| {
            let (a, c) = (&b[..i], &b[i + 1..]);
            !a.is_empty()
                && !c.is_empty()
                && a[0].is_ascii_alphanumeric()
                && c[0].is_ascii_alphanumeric()
                && a.iter().all(|x| x.is_ascii_lowercase() || x.is_ascii_digit() || matches!(x, b'.' | b'+' | b'-'))
                && c.iter().all(|x| x.is_ascii_lowercase() || x.is_ascii_digit() || matches!(x, b'.' | b'+' | b'-' | b'_'))
        });
    if ok { v } else { "application/octet-stream".to_string() }
}

// ── ids / paths (attachments.ts) ────────────────────────────────────────────
pub fn is_uuid(s: &str) -> bool {
    let b = s.as_bytes();
    if b.len() != 36 {
        return false;
    }
    b.iter().enumerate().all(|(i, c)| if matches!(i, 8 | 13 | 18 | 23) { *c == b'-' } else { c.is_ascii_hexdigit() })
}

/// `<uuid>/<2hex>/<64hex>-<8hex>` and the third part starts with the second.
pub fn rel_path_valid(rel: &str) -> bool {
    let p: Vec<&str> = rel.split('/').collect();
    if p.len() != 3 || !is_uuid(p[0]) {
        return false;
    }
    let lowhex = |s: &str| s.bytes().all(|c| c.is_ascii_digit() || (b'a'..=b'f').contains(&c));
    if p[1].len() != 2 || !lowhex(p[1]) {
        return false;
    }
    let Some((h, t)) = p[2].split_once('-') else { return false };
    h.len() == 64 && t.len() == 8 && lowhex(h) && lowhex(t) && h.starts_with(p[1])
}

/// Client's attachment_ids -> clean lower-case unique uuid list. Err(code) like the Bun route.
pub fn normalise_ids(raw: &[String]) -> Result<Vec<String>, &'static str> {
    if raw.len() > MAX_ATTACH {
        return Err("too_many_attachments");
    }
    let mut out: Vec<String> = Vec::new();
    for v in raw {
        if !is_uuid(v) {
            return Err("attachment_ids_invalid");
        }
        let id = v.to_lowercase();
        if !out.contains(&id) {
            out.push(id);
        }
    }
    Ok(out)
}

// ── addresses ───────────────────────────────────────────────────────────────
/// Strict single address: local@domain, nothing that can break a header or an SMTP command.
pub fn valid_addr(a: &str) -> bool {
    if a.is_empty() || a.len() > 254 {
        return false;
    }
    let Some((local, dom)) = a.rsplit_once('@') else { return false };
    if local.is_empty() || local.len() > 64 || dom.len() < 3 || !dom.contains('.') {
        return false;
    }
    let lok = local.bytes().all(|c| c.is_ascii_alphanumeric() || b"!#$%&'*+/=?^_`{|}~.-".contains(&c));
    if !lok || local.starts_with('.') || local.ends_with('.') || local.contains("..") {
        return false;
    }
    dom.split('.').all(|l| {
        !l.is_empty() && l.len() <= 63 && !l.starts_with('-') && !l.ends_with('-') && l.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-')
    }) && dom.rsplit('.').next().is_some_and(|t| t.len() >= 2 && t.bytes().all(|c| c.is_ascii_alphabetic()))
}

/// Bun `list()` = trim + drop empties (string => split on commas). Here: trim, drop empties, then every item must be a valid address.
pub fn clean_addrs(items: &[String]) -> Result<Vec<String>, String> {
    let mut out = Vec::new();
    for i in items {
        let t = i.trim();
        if t.is_empty() {
            continue;
        }
        if !valid_addr(t) {
            return Err(t.chars().take(80).collect());
        }
        out.push(t.to_string());
    }
    Ok(out)
}

pub fn split_commas(s: &str) -> Vec<String> {
    s.split(',').map(|x| x.trim().to_string()).filter(|x| !x.is_empty()).collect()
}

/// org.ts mailboxAddress(): `^[a-z0-9._+-]+@[a-z0-9.-]+\.[a-z]{2,}$` after trim+lowercase.
pub fn mailbox_address(raw: &str) -> Option<String> {
    let a = raw.trim().to_lowercase();
    let (l, d) = a.split_once('@')?;
    if l.is_empty() || !l.bytes().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || matches!(c, b'.' | b'_' | b'+' | b'-')) {
        return None;
    }
    if d.is_empty() || d.contains('@') || !d.bytes().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || matches!(c, b'.' | b'-')) {
        return None;
    }
    let tld = d.rsplit('.').next()?;
    if !d.contains('.') || tld.len() < 2 || !tld.bytes().all(|c| c.is_ascii_lowercase()) || d.len() > 253 || a.len() > 254 {
        return None;
    }
    Some(a)
}

/// CAP_ROLES["org.mailboxes.create"] = owner | admin | manager (founder passes elsewhere).
pub fn role_may_create_mailbox(role: &str) -> bool {
    matches!(role.trim().to_lowercase().as_str(), "owner" | "admin" | "manager")
}

// ── header / message ────────────────────────────────────────────────────────
pub fn encode_header(v: &str) -> String {
    let v: String = {
        let mut o = String::with_capacity(v.len());
        let mut in_br = false;
        for c in v.chars() {
            if c == '\r' || c == '\n' {
                if !in_br {
                    o.push(' ');
                }
                in_br = true;
            } else {
                in_br = false;
                o.push(c);
            }
        }
        o
    };
    if v.is_ascii() { v } else { format!("=?UTF-8?B?{}?=", b64(v.as_bytes())) }
}

/// Display name for From: RFC 2047 when non-ASCII; quoted-string when ASCII with specials (Bun left these bare = malformed header).
fn display_name(n: &str) -> String {
    let e = encode_header(n);
    if e.starts_with("=?UTF-8?B?") {
        return e;
    }
    if e.bytes().any(|c| b"()<>[]:;@\\,.\"".contains(&c)) {
        format!("\"{}\"", e.replace('\\', "\\\\").replace('"', "\\\""))
    } else {
        e
    }
}

pub struct Msg<'a> {
    pub from: &'a str,
    pub from_name: Option<&'a str>,
    pub to: &'a [String],
    pub cc: &'a [String],
    pub reply_to: Option<&'a str>,
    pub subject: &'a str,
    pub text: &'a str,
    pub html: Option<&'a str>,
    pub message_id: &'a str,
    pub date: &'a str,
    pub boundary: &'a str,
}

/// Mirrors sendmail.ts buildMessage() byte for byte (ASCII names), so Brain's fallback and Rust give identical mail.
pub fn build_message(m: &Msg) -> String {
    let from_h = match m.from_name.filter(|n| !n.trim().is_empty()) {
        Some(n) => format!("{} <{}>", display_name(n), m.from),
        None => m.from.to_string(),
    };
    let mut h: Vec<String> = vec![format!("From: {from_h}"), format!("To: {}", m.to.join(", "))];
    if !m.cc.is_empty() {
        h.push(format!("Cc: {}", m.cc.join(", ")));
    }
    if let Some(r) = m.reply_to.filter(|r| !r.is_empty()) {
        h.push(format!("Reply-To: {r}"));
    }
    h.push(format!("Subject: {}", encode_header(m.subject)));
    h.push(format!("Message-ID: <{}>", m.message_id));
    h.push(format!("Date: {}", m.date));
    h.push("MIME-Version: 1.0".to_string());
    match m.html.filter(|x| !x.is_empty()) {
        Some(html) => {
            h.push(format!("Content-Type: multipart/alternative; boundary=\"{}\"", m.boundary));
            let b = m.boundary;
            let body = format!(
                "--{b}\r\nContent-Type: text/plain; charset=\"UTF-8\"\r\nContent-Transfer-Encoding: 8bit\r\n\r\n{}\r\n--{b}\r\nContent-Type: text/html; charset=\"UTF-8\"\r\nContent-Transfer-Encoding: 8bit\r\n\r\n{}\r\n--{b}--\r\n",
                m.text, html
            );
            format!("{}\r\n\r\n{}", h.join("\r\n"), body)
        }
        None => {
            h.push("Content-Type: text/plain; charset=\"UTF-8\"".to_string());
            h.push("Content-Transfer-Encoding: 8bit".to_string());
            format!("{}\r\n\r\n{}\r\n", h.join("\r\n"), m.text)
        }
    }
}

pub struct AttData {
    pub filename: String,
    pub mime: String,
    pub data: Vec<u8>,
}

/// attachments.ts wrapWithAttachments(): original Content-Type / CTE move into the first part, rest of headers stay.
pub fn wrap_with_attachments(base: &str, files: &[AttData], mx: &str) -> Result<String, &'static str> {
    if files.is_empty() {
        return Ok(base.to_string());
    }
    let cut = base.find("\r\n\r\n").ok_or("message_shape_unexpected")?;
    let body = &base[cut + 4..];
    let mut keep: Vec<&str> = Vec::new();
    let mut moved: Vec<&str> = Vec::new();
    for l in base[..cut].split("\r\n") {
        let low = l.to_ascii_lowercase();
        if low.starts_with("content-type:") || low.starts_with("content-transfer-encoding:") {
            moved.push(l);
        } else {
            keep.push(l);
        }
    }
    if moved.is_empty() {
        return Err("message_shape_unexpected");
    }
    let ct = format!("Content-Type: multipart/mixed; boundary=\"{mx}\"");
    keep.push(&ct);
    let mut parts: Vec<String> = Vec::new();
    parts.push(format!("--{mx}\r\n{}\r\n\r\n{}", moved.join("\r\n"), body.trim_end_matches("\r\n")));
    for f in files {
        let n = clean_name(&f.filename);
        let asc = ascii_name(&n);
        let enc = format!("UTF-8''{}", pct(&n));
        parts.push(format!(
            "--{mx}\r\nContent-Type: {}; name=\"{asc}\"; name*={enc}\r\nContent-Disposition: attachment; filename=\"{asc}\"; filename*={enc}\r\nContent-Transfer-Encoding: base64\r\n\r\n{}",
            clean_mime(&f.mime),
            b64_lines(&f.data)
        ));
    }
    Ok(format!("{}\r\n\r\n{}\r\n--{mx}--\r\n", keep.join("\r\n"), parts.join("\r\n")))
}

// ── date ────────────────────────────────────────────────────────────────────
/// RFC 7231/5322 date in GMT, same shape as JS `toUTCString()` ("Wed, 21 Oct 2026 01:02:03 GMT").
pub fn rfc_date(unix: i64) -> String {
    let days = unix.div_euclid(86400);
    let sod = unix.rem_euclid(86400);
    let z = days + 719468;
    let era = z.div_euclid(146097);
    let doe = z.rem_euclid(146097);
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    let wd = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][(days + 4).rem_euclid(7) as usize];
    let mon = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][(m - 1) as usize];
    format!("{wd}, {d:02} {mon} {y:04} {:02}:{:02}:{:02} GMT", sod / 3600, sod % 3600 / 60, sod % 60)
}

/// RFC 3339 / JS ISO ("2026-10-21T01:02:03Z", ".123Z", "+05:00") -> unix seconds. None if malformed (client send_at).
pub fn parse_iso(t: &str) -> Option<i64> {
    let b = t.trim().as_bytes();
    if b.len() < 20 || b.len() > 40 {
        return None;
    }
    let num = |a: usize, n: usize| -> Option<i64> {
        let sl = b.get(a..a + n)?;
        if sl.iter().all(|c| c.is_ascii_digit()) { std::str::from_utf8(sl).ok()?.parse().ok() } else { None }
    };
    let (y, mo, d, h, mi, se) = (num(0, 4)?, num(5, 2)?, num(8, 2)?, num(11, 2)?, num(14, 2)?, num(17, 2)?);
    if b[4] != b'-' || b[7] != b'-' || !(b[10] == b'T' || b[10] == b't' || b[10] == b' ') || b[13] != b':' || b[16] != b':' {
        return None;
    }
    if !(1..=12).contains(&mo) || !(1..=31).contains(&d) || h > 23 || mi > 59 || se > 60 {
        return None;
    }
    let mut i = 19;
    if b.get(i) == Some(&b'.') {
        i += 1;
        let st = i;
        while b.get(i).is_some_and(|c| c.is_ascii_digit()) {
            i += 1;
        }
        if i == st {
            return None;
        }
    }
    let off = match b.get(i)? {
        b'Z' | b'z' if i + 1 == b.len() => 0,
        sign @ (b'+' | b'-') => {
            let (oh, om) = (num(i + 1, 2)?, num(i + 4, 2)?);
            if b.get(i + 3) != Some(&b':') || i + 6 != b.len() || oh > 23 || om > 59 {
                return None;
            }
            (oh * 3600 + om * 60) * if *sign == b'+' { 1 } else { -1 }
        }
        _ => return None,
    };
    let (yy, mm) = if mo <= 2 { (y - 1, mo + 9) } else { (y, mo - 3) };
    let era = yy.div_euclid(400);
    let yoe = yy.rem_euclid(400);
    let doy = (153 * mm + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146097 + doe - 719468;
    Some(days * 86400 + h * 3600 + mi * 60 + se - off)
}

/// identity.ts sendableFrom(): rows (address, box_type|kind, active) -> lower-case addresses allowed as From. Alias (forward-only) never.
pub fn sendable_from(rows: &[(String, Option<String>, Option<bool>)]) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for (addr, kind, active) in rows {
        let a = addr.trim().to_lowercase();
        if a.is_empty() || !a.contains('@') || *active == Some(false) {
            continue;
        }
        if kind.as_deref().unwrap_or("mailbox").to_lowercase() == "alias" {
            continue;
        }
        if !out.contains(&a) {
            out.push(a);
        }
    }
    out
}

/// ILIKE pattern value for an exact, case-insensitive address match (escapes % _ \ and percent-encodes for the URL).
pub fn ilike_exact(addr: &str) -> String {
    let esc: String = addr.chars().flat_map(|c| if matches!(c, '%' | '_' | '\\') { vec!['\\', c] } else { vec![c] }).collect();
    pct(&esc)
}

/// worker's size estimate for the storage reservation (mail-worker.ts estimateBytes).
pub fn estimate_bytes(subject: &str, body: &str) -> i64 {
    512 + subject.len() as i64 + body.len() as i64
}

// ── SMTP (local Postfix, plaintext, no auth) ────────────────────────────────
/// CRLF-normalise and dot-stuff EVERY line that starts with "." (Bun missed a leading dot on line 1; headers always come first, so equal in practice).
pub fn dot_stuff(data: &str) -> String {
    let norm = data.replace("\r\n", "\n").replace('\r', "\n");
    let mut out = String::with_capacity(norm.len() + 16);
    for (i, line) in norm.split('\n').enumerate() {
        if i > 0 {
            out.push_str("\r\n");
        }
        if line.starts_with('.') {
            out.push('.');
        }
        out.push_str(line);
    }
    out
}

fn read_reply(s: &mut TcpStream) -> Result<(u16, String), String> {
    let mut buf: Vec<u8> = Vec::new();
    let mut byte = [0u8; 1024];
    loop {
        let n = s.read(&mut byte).map_err(|e| format!("SMTP read: {e}"))?;
        if n == 0 {
            return Err("SMTP closed".to_string());
        }
        buf.extend_from_slice(&byte[..n]);
        if buf.len() > 64 * 1024 {
            return Err("SMTP reply too long".to_string());
        }
        if buf.ends_with(b"\r\n") {
            let txt = String::from_utf8_lossy(&buf).to_string();
            let last = txt.trim_end().rsplit("\r\n").next().unwrap_or("").to_string();
            if last.len() >= 4 && last.as_bytes()[3] == b'-' {
                continue;
            }
            let code = last.get(..3).and_then(|c| c.parse::<u16>().ok()).unwrap_or(0);
            return Ok((code, last));
        }
    }
}

/// Blocking; call inside spawn_blocking. Returns the " | "-joined server lines on success.
pub fn smtp_send(host: &str, port: u16, env_from: &str, rcpts: &[String], data: &str) -> Result<String, String> {
    if rcpts.is_empty() || rcpts.len() > MAX_RCPT {
        return Err("bad recipient count".to_string());
    }
    if !valid_addr(env_from) || rcpts.iter().any(|r| !valid_addr(r)) {
        return Err("bad envelope address".to_string());
    }
    let addr = (host, port).to_socket_addrs().map_err(|e| format!("SMTP resolve: {e}"))?.next().ok_or("SMTP resolve: none")?;
    let mut s = TcpStream::connect_timeout(&addr, Duration::from_secs(10)).map_err(|e| format!("SMTP socket: {e}"))?;
    s.set_read_timeout(Some(Duration::from_secs(30))).ok();
    s.set_write_timeout(Some(Duration::from_secs(30))).ok();
    let mut log: Vec<String> = Vec::new();
    let (c, l) = read_reply(&mut s)?;
    if c != 220 {
        return Err(format!("SMTP greeting: {l}"));
    }
    log.push(l);
    let mut cmds: Vec<String> = vec![format!("EHLO {DOMAIN}"), format!("MAIL FROM:<{env_from}>")];
    cmds.extend(rcpts.iter().map(|r| format!("RCPT TO:<{r}>")));
    for c in &cmds {
        s.write_all(format!("{c}\r\n").as_bytes()).map_err(|e| format!("SMTP write: {e}"))?;
        let (code, l) = read_reply(&mut s)?;
        if code >= 400 || code == 0 {
            return Err(format!("{c} → {l}"));
        }
        log.push(l);
    }
    s.write_all(b"DATA\r\n").map_err(|e| format!("SMTP write: {e}"))?;
    let (code, l) = read_reply(&mut s)?;
    if code != 354 {
        return Err(format!("DATA refused: {l}"));
    }
    log.push(l);
    s.write_all(format!("{}\r\n.\r\n", dot_stuff(data)).as_bytes()).map_err(|e| format!("SMTP write: {e}"))?;
    let (code, l) = read_reply(&mut s)?;
    if code >= 400 || code == 0 {
        return Err(format!("message refused: {l}"));
    }
    log.push(l);
    let _ = s.write_all(b"QUIT\r\n");
    Ok(log.join(" | "))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::TcpListener;

    fn s(v: &[&str]) -> Vec<String> {
        v.iter().map(|x| x.to_string()).collect()
    }

    #[test]
    fn base64_matches_known() {
        assert_eq!(b64(b""), "");
        assert_eq!(b64(b"f"), "Zg==");
        assert_eq!(b64(b"fo"), "Zm8=");
        assert_eq!(b64(b"foo"), "Zm9v");
        assert_eq!(b64("héllo".as_bytes()), "aMOpbGxv");
        let long = vec![b'a'; 100];
        let l = b64_lines(&long);
        assert_eq!(l.split("\r\n").next().unwrap().len(), 76);
        assert!(!l.ends_with("\r\n"));
    }

    #[test]
    fn address_shapes() {
        for a in ["a@b.co", "first.last+tag@sub.example.com", "x_y@anexomail.com"] {
            assert!(valid_addr(a), "{a}");
        }
        for a in ["", "a", "a@b", "a@b.c", "a b@c.com", "a@b.com\r\nBcc: x@y.com", "<a@b.com>", "a@b.com>", "a\"@b.com", "a@@b.com", ".a@b.com", "a..b@b.com", "a@-b.com", "a@b.c0m", "a,b@c.com"] {
            assert!(!valid_addr(a), "{a:?}");
        }
        assert!(clean_addrs(&s(&["a@b.com", " ", "c@d.org "])).unwrap().len() == 2);
        assert!(clean_addrs(&s(&["a@b.com", "evil\r\nBcc: z@z.com"])).is_err());
        assert_eq!(split_commas("a@b.com, ,c@d.org"), s(&["a@b.com", "c@d.org"]));
    }

    #[test]
    fn mailbox_address_matches_org_ts() {
        assert_eq!(mailbox_address("  Sales@AnexoMail.com ").as_deref(), Some("sales@anexomail.com"));
        assert_eq!(mailbox_address("a.b+c_d-e@x-y.example.io").as_deref(), Some("a.b+c_d-e@x-y.example.io"));
        for bad in ["", "nope", "a@b", "a@b.c", "@b.com", "a@.com x", "a b@c.com", "a\n@b.com", "a@b@c.com", "ä@b.com"] {
            assert!(mailbox_address(bad).is_none(), "{bad:?}");
        }
        assert!(role_may_create_mailbox("Manager") && role_may_create_mailbox("owner") && role_may_create_mailbox(" admin "));
        assert!(!role_may_create_mailbox("member") && !role_may_create_mailbox("viewer") && !role_may_create_mailbox(""));
    }

    #[test]
    fn header_injection_and_encoding() {
        assert_eq!(encode_header("Hello"), "Hello");
        assert_eq!(encode_header("a\r\nBcc: x@y.com"), "a Bcc: x@y.com");
        assert_eq!(encode_header("héllo"), "=?UTF-8?B?aMOpbGxv?=");
        assert_eq!(display_name("Sales Team"), "Sales Team");
        assert_eq!(display_name("Doe, John"), "\"Doe, John\"");
        assert_eq!(display_name("a\"b"), "\"a\\\"b\"");
    }

    fn msg<'a>(to: &'a [String], cc: &'a [String], html: Option<&'a str>) -> Msg<'a> {
        Msg {
            from: "hello@anexomail.com",
            from_name: Some("Anexo"),
            to,
            cc,
            reply_to: Some("r@x.com"),
            subject: "Hi",
            text: "plain",
            html,
            message_id: "id1@anexomail.com",
            date: "Wed, 21 Oct 2026 01:02:03 GMT",
            boundary: "ax_b",
        }
    }

    #[test]
    fn plain_message_exact() {
        let to = s(&["a@b.com", "c@d.org"]);
        let cc = s(&[]);
        let m = build_message(&msg(&to, &cc, None));
        assert_eq!(
            m,
            "From: Anexo <hello@anexomail.com>\r\nTo: a@b.com, c@d.org\r\nReply-To: r@x.com\r\nSubject: Hi\r\nMessage-ID: <id1@anexomail.com>\r\nDate: Wed, 21 Oct 2026 01:02:03 GMT\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=\"UTF-8\"\r\nContent-Transfer-Encoding: 8bit\r\n\r\nplain\r\n"
        );
    }

    #[test]
    fn alternative_message_exact() {
        let to = s(&["a@b.com"]);
        let cc = s(&["c@d.org"]);
        let m = build_message(&msg(&to, &cc, Some("<p>x</p>")));
        assert!(m.contains("Cc: c@d.org\r\n"));
        assert!(m.contains("Content-Type: multipart/alternative; boundary=\"ax_b\"\r\n\r\n--ax_b\r\n"));
        assert!(m.ends_with("<p>x</p>\r\n--ax_b--\r\n"));
        assert!(!m.contains("Bcc"));
    }

    #[test]
    fn wrap_moves_content_headers_and_adds_parts() {
        let to = s(&["a@b.com"]);
        let cc = s(&[]);
        let base = build_message(&msg(&to, &cc, None));
        let f = AttData { filename: "re\"p/ort.pdf".into(), mime: "Application/PDF; x=y".into(), data: vec![1, 2, 3, 4] };
        let w = wrap_with_attachments(&base, &[f], "mx_1").unwrap();
        let (head, rest) = w.split_once("\r\n\r\n").unwrap();
        assert!(head.contains("Content-Type: multipart/mixed; boundary=\"mx_1\""));
        assert!(!head.contains("text/plain"));
        assert!(rest.starts_with("--mx_1\r\nContent-Type: text/plain"));
        assert!(rest.contains("Content-Type: application/pdf; name=\"re_p_ort.pdf\"; name*=UTF-8''re_p_ort.pdf\r\n"));
        assert!(rest.contains("Content-Transfer-Encoding: base64\r\n\r\nAQIDBA=="));
        assert!(rest.ends_with("\r\n--mx_1--\r\n"));
        assert_eq!(wrap_with_attachments(&base, &[], "x").unwrap(), base);
        assert!(wrap_with_attachments("no-body", &[AttData { filename: "a".into(), mime: "a/b".into(), data: vec![] }], "x").is_err());
    }

    #[test]
    fn names_mimes_paths_ids() {
        assert_eq!(clean_name("  a/b\\c\"d\u{202e}.txt "), "a_b_c_d_.txt");
        assert_eq!(clean_name("   "), "file");
        assert_eq!(ascii_name("é\"x"), "__x");
        assert_eq!(pct("a b/é"), "a%20b%2F%C3%A9");
        assert_eq!(clean_mime("text/HTML; charset=x"), "text/html");
        assert_eq!(clean_mime("nonsense"), "application/octet-stream");
        assert_eq!(clean_mime("a/b\r\nX: y"), "application/octet-stream");
        let id = "0b9a1c52-1111-4222-8333-444455556666";
        let h = format!("ab{}", "c".repeat(62));
        assert!(rel_path_valid(&format!("{id}/ab/{h}-0123abcd")));
        assert!(!rel_path_valid(&format!("{id}/ab/{h}-0123abcd/..")));
        assert!(!rel_path_valid(&format!("{id}/cd/{h}-0123abcd")));
        assert!(!rel_path_valid(&format!("../{id}/ab/{h}-0123abcd")));
        assert!(!rel_path_valid(&format!("{id}/AB/{h}-0123abcd")));
        assert_eq!(normalise_ids(&s(&[id, &id.to_uppercase()])).unwrap(), vec![id.to_string()]);
        assert_eq!(normalise_ids(&s(&["x"])), Err("attachment_ids_invalid"));
        assert_eq!(normalise_ids(&vec![id.to_string(); 51]), Err("too_many_attachments"));
    }

    #[test]
    fn date_format_matches_js() {
        assert_eq!(rfc_date(0), "Thu, 01 Jan 1970 00:00:00 GMT");
        assert_eq!(rfc_date(951782400), "Tue, 29 Feb 2000 00:00:00 GMT");
        assert_eq!(rfc_date(1792544523), "Wed, 21 Oct 2026 01:02:03 GMT");
        assert_eq!(rfc_date(-1), "Wed, 31 Dec 1969 23:59:59 GMT");
    }

    #[test]
    fn parse_iso_cases() {
        assert_eq!(parse_iso("2026-10-21T01:02:03Z"), Some(1792544523));
        assert_eq!(parse_iso("2026-10-21T01:02:03.456Z"), Some(1792544523));
        assert_eq!(parse_iso("2026-10-21T06:02:03+05:00"), Some(1792544523));
        assert_eq!(parse_iso("2026-10-20T20:02:03-05:00"), Some(1792544523));
        assert_eq!(parse_iso("1970-01-01T00:00:00Z"), Some(0));
        assert_eq!(parse_iso("2000-02-29T00:00:00Z"), Some(951782400));
        for bad in ["", "tomorrow", "2026-13-21T01:02:03Z", "2026-10-21T25:02:03Z", "2026-10-21T01:02:03", "2026-10-21T01:02:03Zjunk", "2026-10-21T01:02:03.Z"] {
            assert_eq!(parse_iso(bad), None, "{bad}");
        }
    }

    #[test]
    fn sender_rules() {
        let rows = vec![
            ("Hello@AnexoMail.com ".to_string(), Some("mailbox".to_string()), Some(true)),
            ("alias@anexomail.com".to_string(), Some("alias".to_string()), None),
            ("off@anexomail.com".to_string(), None, Some(false)),
            ("shared@anexomail.com".to_string(), Some("SHARED".to_string()), None),
            ("noat".to_string(), None, None),
            ("hello@anexomail.com".to_string(), None, None),
        ];
        assert_eq!(sendable_from(&rows), vec!["hello@anexomail.com", "shared@anexomail.com"]);
        assert_eq!(ilike_exact("a_b%c@x.com"), "a%5C_b%5C%25c%40x.com");
        assert_eq!(estimate_bytes("abc", "defg"), 519);
    }

    #[test]
    fn dot_stuffing() {
        assert_eq!(dot_stuff("a\n.b\r\n..c\r\nd"), "a\r\n..b\r\n...c\r\nd");
        assert_eq!(dot_stuff(".x"), "..x");
    }

    fn fake_smtp(reply_rcpt: &'static str) -> (u16, std::thread::JoinHandle<String>) {
        let l = TcpListener::bind("127.0.0.1:0").unwrap();
        let port = l.local_addr().unwrap().port();
        let h = std::thread::spawn(move || {
            let (mut c, _) = l.accept().unwrap();
            let mut seen = String::new();
            c.write_all(b"220 fake ESMTP\r\n").unwrap();
            let mut buf = [0u8; 4096];
            let mut in_data = false;
            loop {
                let n = c.read(&mut buf).unwrap_or(0);
                if n == 0 {
                    break;
                }
                seen.push_str(&String::from_utf8_lossy(&buf[..n]));
                if in_data {
                    if seen.ends_with("\r\n.\r\n") {
                        c.write_all(b"250 2.0.0 Ok: queued as ABC\r\n").unwrap();
                        in_data = false;
                    }
                    continue;
                }
                let last = seen.rsplit("\r\n").nth(1).unwrap_or("").to_string();
                if last.starts_with("EHLO") {
                    c.write_all(b"250-fake\r\n250 8BITMIME\r\n").unwrap();
                } else if last.starts_with("MAIL") {
                    c.write_all(b"250 2.1.0 Ok\r\n").unwrap();
                } else if last.starts_with("RCPT") {
                    c.write_all(format!("{reply_rcpt}\r\n").as_bytes()).unwrap();
                } else if last == "DATA" {
                    c.write_all(b"354 go\r\n").unwrap();
                    in_data = true;
                } else if last == "QUIT" {
                    break;
                }
            }
            seen
        });
        (port, h)
    }

    #[test]
    fn smtp_roundtrip_and_refusal() {
        let (port, h) = fake_smtp("250 2.1.5 Ok");
        let r = smtp_send("127.0.0.1", port, "a@anexomail.com", &s(&["b@x.com", "c@y.org"]), "Subject: t\r\n\r\n.dot\r\nbody").unwrap();
        assert!(r.contains("queued as ABC"), "{r}");
        let seen = h.join().unwrap();
        assert!(seen.contains("MAIL FROM:<a@anexomail.com>\r\nRCPT TO:<b@x.com>\r\nRCPT TO:<c@y.org>\r\nDATA\r\n"), "{seen}");
        assert!(seen.contains("\r\n..dot\r\nbody\r\n.\r\n"), "{seen}");
        let (port2, h2) = fake_smtp("550 5.1.1 no such user");
        let e = smtp_send("127.0.0.1", port2, "a@anexomail.com", &s(&["b@x.com"]), "x").unwrap_err();
        assert!(e.contains("550"), "{e}");
        drop(h2);
        assert!(smtp_send("127.0.0.1", 1, "a@anexomail.com", &s(&["b@x.com\r\nDATA"]), "x").is_err());
        assert!(smtp_send("127.0.0.1", 1, "a@anexomail.com", &[], "x").is_err());
    }
}
