// mig_mime.rs — a careful, std-only reader for one RFC 5322 / MIME message (part of mig_core).
//
// What it gives the migration worker: who/when/subject/ids, the readable text + html body, and the NAMES and SIZES of
// attachments (the attachment bytes are measured, never decoded or kept — the worker holds one message at a time).
//
// Honest limits (also shown to the person before they start):
//   * charsets: UTF-8, US-ASCII, ISO-8859-1/15 and Windows-1252 are exact. Other legacy charsets (GB2312, Shift-JIS,
//     KOI8-R, Windows-1251 ...) are kept as far as ASCII goes and flagged `lossy`; the SHA-256 of the raw message is
//     recorded either way.
//   * bodies are cut at MAX_TEXT / MAX_HTML characters (the same limits the live inbound mail path uses) and flagged.

pub const MAX_TEXT: usize = 200_000;
pub const MAX_HTML: usize = 400_000;
const MAX_DEPTH: usize = 8;
const MAX_PARTS: usize = 600;

#[derive(Debug, Clone, PartialEq, Default)]
pub struct Addr {
    pub name: Option<String>,
    pub address: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Attachment {
    pub filename: String,
    pub mime: String,
    pub size: usize,
}

/// Where an attachment's body sits inside the raw message (G38b): byte offset + length + Content-Transfer-Encoding.
/// Same order and count as `Parsed.attachments`. The import worker ignores it; the inbound-attachment worker decodes from it.
#[derive(Debug, Clone, PartialEq)]
pub struct AttachSrc {
    pub off: usize,
    pub len: usize,
    pub cte: String,
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct Parsed {
    pub message_id: Option<String>,
    pub in_reply_to: Option<String>,
    pub references: Vec<String>,
    pub from: Option<Addr>,
    pub to: Vec<String>,
    pub cc: Vec<String>,
    pub subject: Option<String>,
    /// Date header, unix seconds UTC
    pub date: Option<i64>,
    pub text: String,
    pub html: Option<String>,
    pub attachments: Vec<Attachment>,
    pub attachment_src: Vec<AttachSrc>,
    pub lossy: bool,
    pub truncated: bool,
}

/* ------------------------------------------------------------------ small helpers */

fn find_sub(h: &[u8], n: &[u8], from: usize) -> Option<usize> {
    if n.is_empty() || h.len() < n.len() || from > h.len() - n.len() {
        return None;
    }
    let first = n[0];
    let mut i = from;
    let last = h.len() - n.len();
    while i <= last {
        if h[i] == first && &h[i..i + n.len()] == n {
            return Some(i);
        }
        i += 1;
    }
    None
}

/// header block / body split: first blank line (CRLF or bare LF).
fn split_head_body(raw: &[u8]) -> (&[u8], &[u8]) {
    let mut i = 0;
    while i < raw.len() {
        if raw[i] == b'\n' {
            if i + 1 < raw.len() && raw[i + 1] == b'\n' {
                return (&raw[..i], &raw[i + 2..]);
            }
            if i + 2 < raw.len() && raw[i + 1] == b'\r' && raw[i + 2] == b'\n' {
                return (&raw[..i], &raw[i + 3..]);
            }
        }
        i += 1;
    }
    (raw, &[])
}

fn latin1(b: &[u8]) -> String {
    b.iter().map(|&c| c as char).collect()
}

/// bytes of a header line: UTF-8 if valid, otherwise Latin-1 (old clients put raw 8-bit text in headers).
fn header_text(b: &[u8]) -> String {
    match std::str::from_utf8(b) {
        Ok(s) => s.to_string(),
        Err(_) => latin1(b),
    }
}

/// lower-cased name -> unfolded value, in order
pub fn parse_headers(head: &[u8]) -> Vec<(String, String)> {
    let mut out: Vec<(String, Vec<u8>)> = Vec::new();
    for line in head.split(|&c| c == b'\n') {
        let line = if line.last() == Some(&b'\r') { &line[..line.len() - 1] } else { line };
        if line.is_empty() {
            continue;
        }
        if (line[0] == b' ' || line[0] == b'\t') && !out.is_empty() {
            let last = out.last_mut().unwrap();
            last.1.push(b' ');
            let t = line.iter().position(|&c| c != b' ' && c != b'\t').unwrap_or(line.len());
            last.1.extend_from_slice(&line[t..]);
            continue;
        }
        if let Some(i) = line.iter().position(|&c| c == b':') {
            let name = String::from_utf8_lossy(&line[..i]).trim().to_lowercase();
            if name.is_empty() || name.contains(' ') {
                continue;
            }
            let v = &line[i + 1..];
            let t = v.iter().position(|&c| c != b' ' && c != b'\t').unwrap_or(v.len());
            out.push((name, v[t..].to_vec()));
        }
    }
    out.into_iter().map(|(k, v)| (k, header_text(&v).trim().to_string())).collect()
}

fn hget<'a>(h: &'a [(String, String)], name: &str) -> Option<&'a str> {
    h.iter().find(|(k, _)| k == name).map(|(_, v)| v.as_str())
}

/* ------------------------------------------------------------------ charsets and transfer encodings */

const CP1252: [char; 32] = [
    '€', '\u{81}', '‚', 'ƒ', '„', '…', '†', '‡', 'ˆ', '‰', 'Š', '‹', 'Œ', '\u{8d}', 'Ž', '\u{8f}', '\u{90}', '‘', '’', '“', '”', '•',
    '–', '—', '˜', '™', 'š', '›', 'œ', '\u{9d}', 'ž', 'Ÿ',
];

/// (text, lossy)
pub fn decode_charset(charset: &str, b: &[u8]) -> (String, bool) {
    let cs = charset.trim().trim_matches('"').to_lowercase();
    match cs.as_str() {
        "" | "utf-8" | "utf8" | "us-ascii" | "ascii" | "ansi_x3.4-1968" => match std::str::from_utf8(b) {
            Ok(s) => (s.to_string(), false),
            Err(_) => {
                // declared ASCII/UTF-8 but is not: many senders lie about Latin-1. Keep the readable letters.
                (String::from_utf8_lossy(b).into_owned(), true)
            }
        },
        "iso-8859-1" | "latin1" | "iso8859-1" | "l1" => (latin1(b), false),
        "windows-1252" | "cp1252" | "x-cp1252" => (
            b.iter()
                .map(|&c| if (0x80..0xa0).contains(&c) { CP1252[(c - 0x80) as usize] } else { c as char })
                .collect(),
            false,
        ),
        "iso-8859-15" | "latin9" => (
            b.iter()
                .map(|&c| match c {
                    0xa4 => '€',
                    0xa6 => 'Š',
                    0xa8 => 'š',
                    0xb4 => 'Ž',
                    0xb8 => 'ž',
                    0xbc => 'Œ',
                    0xbd => 'œ',
                    0xbe => 'Ÿ',
                    _ => c as char,
                })
                .collect(),
            false,
        ),
        _ => {
            // unknown legacy charset: valid UTF-8 passes, otherwise ASCII survives and the rest becomes U+FFFD
            match std::str::from_utf8(b) {
                Ok(s) => (s.to_string(), false),
                Err(_) => (b.iter().map(|&c| if c < 0x80 { c as char } else { '\u{fffd}' }).collect(), true),
            }
        }
    }
}

fn b64_val(c: u8) -> Option<u8> {
    match c {
        b'A'..=b'Z' => Some(c - b'A'),
        b'a'..=b'z' => Some(c - b'a' + 26),
        b'0'..=b'9' => Some(c - b'0' + 52),
        b'+' | b'-' => Some(62),
        b'/' | b'_' => Some(63),
        _ => None,
    }
}

pub fn base64_decode(s: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(s.len() / 4 * 3 + 3);
    let mut acc: u32 = 0;
    let mut bits = 0u32;
    for &c in s {
        if c == b'=' {
            break;
        }
        if let Some(v) = b64_val(c) {
            acc = (acc << 6) | v as u32;
            bits += 6;
            if bits >= 8 {
                bits -= 8;
                out.push((acc >> bits) as u8);
                acc &= (1 << bits) - 1;
            }
        }
    }
    out
}

/// decoded size of a base64 body without decoding it (attachments are only measured)
pub fn base64_len(s: &[u8]) -> usize {
    let mut n = 0usize;
    for &c in s {
        if c == b'=' {
            break;
        }
        if b64_val(c).is_some() {
            n += 1;
        }
    }
    n * 6 / 8
}

fn hexv(c: u8) -> Option<u8> {
    match c {
        b'0'..=b'9' => Some(c - b'0'),
        b'a'..=b'f' => Some(c - b'a' + 10),
        b'A'..=b'F' => Some(c - b'A' + 10),
        _ => None,
    }
}

/// body quoted-printable (soft line breaks removed)
pub fn qp_decode(s: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(s.len());
    let mut i = 0;
    while i < s.len() {
        let c = s[i];
        if c == b'=' {
            if i + 1 < s.len() && (s[i + 1] == b'\n' || s[i + 1] == b'\r') {
                // soft line break
                i += 1;
                if s[i] == b'\r' && i + 1 < s.len() && s[i + 1] == b'\n' {
                    i += 1;
                }
                i += 1;
                continue;
            }
            if i + 2 < s.len() {
                if let (Some(a), Some(b)) = (hexv(s[i + 1]), hexv(s[i + 2])) {
                    out.push(a * 16 + b);
                    i += 3;
                    continue;
                }
            }
            out.push(c);
            i += 1;
        } else {
            out.push(c);
            i += 1;
        }
    }
    out
}

/// header Q-encoding: `_` is a space
fn q_decode_word(s: &[u8]) -> Vec<u8> {
    let t: Vec<u8> = s.iter().map(|&c| if c == b'_' { b' ' } else { c }).collect();
    qp_decode(&t)
}

fn decode_transfer(cte: &str, body: &[u8]) -> Vec<u8> {
    match cte.trim().to_lowercase().as_str() {
        "base64" => base64_decode(body),
        "quoted-printable" => qp_decode(body),
        _ => body.to_vec(),
    }
}

/// RFC 2047 encoded words inside a header value. Whitespace between two adjacent encoded words is dropped.
pub fn decode_words(v: &str) -> (String, bool) {
    let mut out = String::new();
    let mut lossy = false;
    let mut rest = v;
    let mut prev_encoded = false;
    while let Some(start) = rest.find("=?") {
        let (before, after) = rest.split_at(start);
        let tail = &after[2..];
        // =?charset?enc?text?=
        let parsed = (|| {
            let c1 = tail.find('?')?;
            let charset = &tail[..c1];
            let r1 = &tail[c1 + 1..];
            let c2 = r1.find('?')?;
            let enc = &r1[..c2];
            let r2 = &r1[c2 + 1..];
            let c3 = r2.find("?=")?;
            let text = &r2[..c3];
            if enc.len() != 1 || charset.is_empty() || charset.len() > 60 || text.contains(' ') {
                return None;
            }
            let bytes = match enc {
                "B" | "b" => base64_decode(text.as_bytes()),
                "Q" | "q" => q_decode_word(text.as_bytes()),
                _ => return None,
            };
            let cs = charset.split('*').next().unwrap_or(charset); // RFC 2231 language suffix
            let consumed = 2 + c1 + 1 + c2 + 1 + c3 + 2;
            Some((decode_charset(cs, &bytes), consumed))
        })();
        match parsed {
            Some(((s, l), consumed)) => {
                if !(prev_encoded && before.chars().all(|c| c.is_whitespace())) {
                    out.push_str(before);
                }
                out.push_str(&s);
                lossy |= l;
                rest = &after[consumed..];
                prev_encoded = true;
            }
            None => {
                out.push_str(before);
                out.push_str("=?");
                rest = &after[2..];
                prev_encoded = false;
            }
        }
    }
    out.push_str(rest);
    (out, lossy)
}

/* ------------------------------------------------------------------ parameters (Content-Type, Content-Disposition) */

fn pct_decode(s: &str) -> Vec<u8> {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() {
            if let (Some(x), Some(y)) = (hexv(b[i + 1]), hexv(b[i + 2])) {
                out.push(x * 16 + y);
                i += 3;
                continue;
            }
        }
        out.push(b[i]);
        i += 1;
    }
    out
}

/// "text/html; charset=utf-8; name*=..." -> (value lowercased, params)
pub fn parse_params(v: &str) -> (String, Vec<(String, String)>) {
    let mut parts: Vec<String> = Vec::new();
    let mut cur = String::new();
    let mut inq = false;
    let mut esc = false;
    for c in v.chars() {
        if inq {
            cur.push(c);
            if esc {
                esc = false;
            } else if c == '\\' {
                esc = true;
            } else if c == '"' {
                inq = false;
            }
        } else if c == '"' {
            inq = true;
            cur.push(c);
        } else if c == ';' {
            parts.push(std::mem::take(&mut cur));
        } else {
            cur.push(c);
        }
    }
    parts.push(cur);
    let main = parts.first().map(|s| s.trim().to_lowercase()).unwrap_or_default();
    let mut raw: Vec<(String, String)> = Vec::new();
    for p in parts.iter().skip(1) {
        if let Some((k, val)) = p.split_once('=') {
            let k = k.trim().to_lowercase();
            let mut val = val.trim().to_string();
            if val.starts_with('"') && val.ends_with('"') && val.len() >= 2 {
                val = val[1..val.len() - 1].replace("\\\"", "\"").replace("\\\\", "\\");
            }
            raw.push((k, val));
        }
    }
    // RFC 2231: name*=utf-8''%41 ; name*0=..., name*1=... ; name*0*=utf-8''..
    let mut out: Vec<(String, String)> = Vec::new();
    let mut names: Vec<String> = Vec::new();
    for (k, _) in &raw {
        let base = k.split('*').next().unwrap_or(k).to_string();
        if !names.contains(&base) {
            names.push(base);
        }
    }
    for base in names {
        if let Some((_, v)) = raw.iter().find(|(k, _)| *k == base) {
            out.push((base.clone(), v.clone()));
            continue;
        }
        let mut pieces: Vec<(usize, bool, String)> = Vec::new();
        for (k, v) in &raw {
            if let Some(rest) = k.strip_prefix(&format!("{base}*")) {
                let (idx, enc) = match rest {
                    "" => (0usize, true),
                    r if r.ends_with('*') => (r.trim_end_matches('*').parse().unwrap_or(0), true),
                    r => (r.parse().unwrap_or(0), false),
                };
                pieces.push((idx, enc, v.clone()));
            }
        }
        pieces.sort_by_key(|p| p.0);
        let mut charset = String::new();
        let mut bytes: Vec<u8> = Vec::new();
        for (n, (_, enc, v)) in pieces.iter().enumerate() {
            if *enc {
                let mut val = v.as_str();
                if n == 0 {
                    if let Some((cs, rest)) = val.split_once('\'') {
                        charset = cs.to_string();
                        val = rest.split_once('\'').map(|x| x.1).unwrap_or(rest);
                    }
                }
                bytes.extend(pct_decode(val));
            } else {
                bytes.extend(v.as_bytes());
            }
        }
        out.push((base, decode_charset(&charset, &bytes).0));
    }
    (main, out)
}

fn param<'a>(p: &'a [(String, String)], k: &str) -> Option<&'a str> {
    p.iter().find(|(n, _)| n == k).map(|(_, v)| v.as_str())
}

/* ------------------------------------------------------------------ addresses, ids, dates */

fn strip_comments(s: &str) -> String {
    let mut out = String::new();
    let mut depth = 0;
    let mut inq = false;
    for c in s.chars() {
        if inq {
            out.push(c);
            if c == '"' {
                inq = false;
            }
            continue;
        }
        match c {
            '"' if depth == 0 => {
                inq = true;
                out.push(c);
            }
            '(' => depth += 1,
            ')' if depth > 0 => depth -= 1,
            _ if depth == 0 => out.push(c),
            _ => {}
        }
    }
    out
}

fn split_list(s: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut cur = String::new();
    let mut inq = false;
    let mut angle = false;
    for c in s.chars() {
        match c {
            '"' => {
                inq = !inq;
                cur.push(c);
            }
            '<' if !inq => {
                angle = true;
                cur.push(c);
            }
            '>' if !inq => {
                angle = false;
                cur.push(c);
            }
            ',' | ';' if !inq && !angle => {
                if !cur.trim().is_empty() {
                    out.push(cur.trim().to_string());
                }
                cur.clear();
            }
            _ => cur.push(c),
        }
    }
    if !cur.trim().is_empty() {
        out.push(cur.trim().to_string());
    }
    out
}

pub fn parse_address(s: &str) -> Option<Addr> {
    let s = strip_comments(s);
    let s = s.trim();
    if s.is_empty() {
        return None;
    }
    if let (Some(a), Some(b)) = (s.rfind('<'), s.rfind('>')) {
        if a < b {
            let address = s[a + 1..b].trim().to_lowercase();
            if !address.contains('@') {
                return None;
            }
            let mut name = s[..a].trim().to_string();
            if name.starts_with('"') && name.ends_with('"') && name.len() >= 2 {
                name = name[1..name.len() - 1].replace("\\\"", "\"");
            }
            let name = decode_words(&name).0.trim().to_string();
            return Some(Addr { name: if name.is_empty() { None } else { Some(name) }, address });
        }
    }
    let a = s.trim_matches(|c| c == '<' || c == '>').trim().to_lowercase();
    if a.contains('@') && !a.contains(' ') {
        Some(Addr { name: None, address: a })
    } else {
        None
    }
}

pub fn parse_address_list(s: &str) -> Vec<Addr> {
    split_list(&strip_comments(s)).iter().filter_map(|x| parse_address(x)).collect()
}

/// `<abc@x>` -> `abc@x` (the same shape the live inbound path stores)
pub fn clean_id(s: &str) -> Option<String> {
    let t = s.trim();
    let inner = match (t.find('<'), t.find('>')) {
        (Some(a), Some(b)) if a < b => &t[a + 1..b],
        _ => t,
    };
    let inner = inner.trim();
    if inner.is_empty() || inner.len() > 998 || inner.contains(char::is_whitespace) {
        None
    } else {
        Some(inner.to_string())
    }
}

fn all_ids(s: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut rest = s;
    while let Some(a) = rest.find('<') {
        match rest[a..].find('>') {
            Some(b) => {
                if let Some(id) = clean_id(&rest[a..a + b + 1]) {
                    out.push(id);
                }
                rest = &rest[a + b + 1..];
            }
            None => break,
        }
    }
    out
}

fn days_from_civil(y: i64, m: i64, d: i64) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let mp = (m + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe - 719468
}

fn civil_from_days(z: i64) -> (i64, i64, i64) {
    let z = z + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    (if m <= 2 { y + 1 } else { y }, m, d)
}

/// unix seconds -> "2026-10-19T04:10:00Z"
pub fn iso_utc(secs: i64) -> String {
    let days = secs.div_euclid(86400);
    let rem = secs.rem_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    format!("{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z", rem / 3600, (rem % 3600) / 60, rem % 60)
}

const MONTHS: [&str; 12] = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];

/// RFC 5322 date (and the older forms seen in the wild) -> unix seconds UTC. IMAP INTERNALDATE ("19-Oct-2026 04:10:00 +0500") works too.
pub fn parse_date(s: &str) -> Option<i64> {
    let s = strip_comments(s);
    let s = s.replace(',', " ");
    let tok: Vec<&str> = s.split_whitespace().collect();
    let mut i = 0;
    // optional weekday
    if let Some(t) = tok.first() {
        let l = t.to_lowercase();
        if ["mon", "tue", "wed", "thu", "fri", "sat", "sun"].iter().any(|d| l.starts_with(d)) && !t.contains('-') {
            i = 1;
        }
    }
    let rest = &tok[i..];
    if rest.len() < 3 {
        return None;
    }
    let (day, mon, year, tpos) = if rest[0].contains('-') {
        // 19-Oct-2026
        let p: Vec<&str> = rest[0].split('-').collect();
        if p.len() != 3 {
            return None;
        }
        (p[0], p[1], p[2], 1)
    } else {
        if rest.len() < 4 {
            return None;
        }
        (rest[0], rest[1], rest[2], 3)
    };
    let d: i64 = day.parse().ok()?;
    let mi = MONTHS.iter().position(|m| mon.to_lowercase().starts_with(m))? as i64 + 1;
    let mut y: i64 = year.parse().ok()?;
    if year.len() <= 2 {
        y += if y < 50 { 2000 } else { 1900 };
    } else if year.len() == 3 {
        y += 1900;
    }
    let time = rest.get(tpos).copied().unwrap_or("00:00:00");
    let tp: Vec<&str> = time.split(':').collect();
    let hh: i64 = tp.first()?.parse().ok()?;
    let mm: i64 = tp.get(1).and_then(|x| x.parse().ok()).unwrap_or(0);
    let ss: i64 = tp.get(2).and_then(|x| x.parse().ok()).unwrap_or(0);
    if !(1..=31).contains(&d) || hh > 24 || mm > 59 || ss > 60 || !(1970..=2200).contains(&y) {
        return None;
    }
    let zone = rest.get(tpos + 1).copied().unwrap_or("+0000");
    let off: i64 = {
        let z = zone.to_uppercase();
        match z.as_str() {
            "GMT" | "UT" | "UTC" | "Z" => 0,
            "EST" => -5 * 3600,
            "EDT" => -4 * 3600,
            "CST" => -6 * 3600,
            "CDT" => -5 * 3600,
            "MST" => -7 * 3600,
            "MDT" => -6 * 3600,
            "PST" => -8 * 3600,
            "PDT" => -7 * 3600,
            _ => {
                let b = z.as_bytes();
                if b.len() >= 5 && (b[0] == b'+' || b[0] == b'-') && b[1..5].iter().all(|c| c.is_ascii_digit()) {
                    let h: i64 = z[1..3].parse().ok()?;
                    let m: i64 = z[3..5].parse().ok()?;
                    let v = h * 3600 + m * 60;
                    if b[0] == b'-' {
                        -v
                    } else {
                        v
                    }
                } else {
                    0
                }
            }
        }
    };
    // a day that does not exist (31 Feb) is a corrupt header, not a date
    let days = days_from_civil(y, mi, d);
    if civil_from_days(days) != (y, mi, d) {
        return None;
    }
    Some(days * 86400 + hh * 3600 + mm * 60 + ss - off)
}

/* ------------------------------------------------------------------ html -> text */

fn decode_entities(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut rest = s;
    while let Some(p) = rest.find('&') {
        out.push_str(&rest[..p]);
        let tail = &rest[p..];
        if let Some(semi) = tail.as_bytes().iter().take(12).position(|&c| c == b';') {
            let ent = &tail[1..semi];
            let rep: Option<String> = match ent {
                "amp" => Some("&".into()),
                "lt" => Some("<".into()),
                "gt" => Some(">".into()),
                "quot" => Some("\"".into()),
                "apos" => Some("'".into()),
                "nbsp" => Some(" ".into()),
                _ if ent.starts_with("#x") || ent.starts_with("#X") => {
                    u32::from_str_radix(&ent[2..], 16).ok().and_then(char::from_u32).map(|c| c.to_string())
                }
                _ if ent.starts_with('#') => ent[1..].parse::<u32>().ok().and_then(char::from_u32).map(|c| c.to_string()),
                _ => None,
            };
            if let Some(r) = rep {
                out.push_str(&r);
                rest = &tail[semi + 1..];
                continue;
            }
        }
        out.push('&');
        rest = &tail[1..];
    }
    out.push_str(rest);
    out
}

pub fn html_to_text(html: &str) -> String {
    let lower = html.to_ascii_lowercase();
    let mut out = String::with_capacity(html.len() / 2);
    let mut i = 0;
    let b = html.as_bytes();
    while i < b.len() {
        if b[i] == b'<' {
            let tail = &lower[i..];
            // drop whole script/style/head blocks
            let mut skipped = false;
            for tag in ["script", "style", "head"] {
                if tail.starts_with(&format!("<{tag}")) {
                    let close = format!("</{tag}");
                    if let Some(e) = lower[i..].find(&close) {
                        let after = i + e;
                        i = lower[after..].find('>').map(|g| after + g + 1).unwrap_or(b.len());
                    } else {
                        i = b.len();
                    }
                    skipped = true;
                    break;
                }
            }
            if skipped {
                continue;
            }
            let end = lower[i..].find('>').map(|g| i + g + 1).unwrap_or(b.len());
            let name: String = lower[i + 1..end.min(lower.len())]
                .trim_start_matches('/')
                .chars()
                .take_while(|c| c.is_ascii_alphanumeric())
                .collect();
            if matches!(name.as_str(), "br" | "p" | "div" | "tr" | "li" | "h1" | "h2" | "h3" | "h4" | "blockquote" | "table") {
                if !out.ends_with('\n') {
                    out.push('\n');
                }
            } else if matches!(name.as_str(), "td" | "th") {
                out.push(' ');
            }
            i = end;
        } else {
            let next = html[i..].find('<').map(|g| i + g).unwrap_or(b.len());
            out.push_str(&html[i..next]);
            i = next;
        }
    }
    let dec = decode_entities(&out);
    let mut lines: Vec<String> = Vec::new();
    for l in dec.lines() {
        let t = l.split_whitespace().collect::<Vec<_>>().join(" ");
        if t.is_empty() && lines.last().map(|x| x.is_empty()).unwrap_or(true) {
            continue;
        }
        lines.push(t);
    }
    lines.join("\n").trim().to_string()
}

/* ------------------------------------------------------------------ the message */

struct Walk<'a> {
    out: &'a mut Parsed,
    parts: usize,
    /// address of the first byte of the raw message — attachment bodies are sub-slices of it
    base: usize,
}

fn cut(s: String, max: usize, truncated: &mut bool) -> String {
    if s.chars().count() <= max {
        return s;
    }
    *truncated = true;
    s.chars().take(max).collect()
}

fn walk(w: &mut Walk, head: &[(String, String)], body: &[u8], depth: usize) {
    w.parts += 1;
    if w.parts > MAX_PARTS || depth > MAX_DEPTH {
        w.out.lossy = true;
        return;
    }
    let ct_raw = hget(head, "content-type").unwrap_or("text/plain");
    let (ctype, cparams) = parse_params(ct_raw);
    let cte = hget(head, "content-transfer-encoding").unwrap_or("7bit").to_lowercase();
    let (disp, dparams) = parse_params(hget(head, "content-disposition").unwrap_or(""));

    if let Some(top) = ctype.strip_prefix("multipart/") {
        let _ = top;
        let boundary = match param(&cparams, "boundary") {
            Some(b) if !b.is_empty() => b.to_string(),
            _ => {
                w.out.lossy = true;
                return;
            }
        };
        let delim = format!("--{boundary}");
        let d = delim.as_bytes();
        let mut starts: Vec<usize> = Vec::new();
        let mut from = 0;
        while let Some(p) = find_sub(body, d, from) {
            // a delimiter sits at the start of a line
            // ... and is followed by the end of the line (or the closing "--"): "--B1" is not the delimiter "--B"
            let nxt = body.get(p + d.len()).copied();
            let line_ok = p == 0 || body[p - 1] == b'\n';
            let tail_ok = match nxt {
                None | Some(b'\r') | Some(b'\n') | Some(b' ') | Some(b'\t') => true,
                Some(b'-') => body.get(p + d.len() + 1) == Some(&b'-'),
                _ => false,
            };
            if line_ok && tail_ok {
                starts.push(p);
            }
            from = p + d.len();
        }
        for (n, &s) in starts.iter().enumerate() {
            let after = s + d.len();
            if body[after..].starts_with(b"--") {
                break;
            }
            // part runs from the end of the delimiter line to just before the next delimiter (minus its line break)
            let line_end = body[after..].iter().position(|&c| c == b'\n').map(|x| after + x + 1).unwrap_or(body.len());
            let mut end = starts.get(n + 1).copied().unwrap_or(body.len());
            if end > line_end && body[end - 1] == b'\n' {
                end -= 1;
                if end > line_end && body[end - 1] == b'\r' {
                    end -= 1;
                }
            }
            if line_end >= end {
                continue;
            }
            let part = &body[line_end..end];
            let (ph, pb) = split_head_body(part);
            let phead = parse_headers(ph);
            walk(w, &phead, pb, depth + 1);
            if w.parts > MAX_PARTS {
                return;
            }
        }
        return;
    }

    let filename = param(&dparams, "filename").or_else(|| param(&cparams, "name")).map(|s| decode_words(s).0);
    let is_attachment_disp = disp == "attachment";
    let is_text = ctype == "text/plain" || ctype == "text/html";
    let has_cid = hget(head, "content-id").is_some();

    if !is_text || is_attachment_disp || (filename.is_some() && disp != "inline") {
        // attachment (or any non-text part, message/rfc822 included): measure, never keep
        let size = match cte.trim() {
            "base64" => base64_len(body),
            "quoted-printable" => qp_decode(body).len(),
            _ => body.len(),
        };
        let name = filename.unwrap_or_else(|| {
            if ctype == "message/rfc822" {
                "message.eml".to_string()
            } else if has_cid {
                "inline-image".to_string()
            } else {
                "unnamed".to_string()
            }
        });
        w.out.attachments.push(Attachment { filename: name, mime: ctype, size });
        w.out.attachment_src.push(AttachSrc { off: (body.as_ptr() as usize).saturating_sub(w.base), len: body.len(), cte: cte.trim().to_string() });
        return;
    }

    let charset = param(&cparams, "charset").unwrap_or("");
    let bytes = decode_transfer(&cte, body);
    let (text, lossy) = decode_charset(charset, &bytes);
    w.out.lossy |= lossy;
    if ctype == "text/html" {
        if w.out.html.is_none() {
            w.out.html = Some(text);
        }
    } else if w.out.text.is_empty() {
        w.out.text = text;
    } else {
        w.out.text.push_str("\n\n");
        w.out.text.push_str(&text);
    }
}

/// The decoded bytes of one attachment found by `parse` (G38b). Only called by the inbound-attachment worker, one at a time.
pub fn attachment_bytes(raw: &[u8], src: &AttachSrc) -> Vec<u8> {
    let end = src.off.saturating_add(src.len).min(raw.len());
    let body = raw.get(src.off..end).unwrap_or(&[]);
    match src.cte.to_ascii_lowercase().as_str() {
        "base64" => base64_decode(body),
        "quoted-printable" => qp_decode(body),
        _ => body.to_vec(),
    }
}

pub fn parse(raw: &[u8]) -> Parsed {
    let (head_b, body) = split_head_body(raw);
    let head = parse_headers(head_b);
    let mut p = Parsed::default();

    let mut lossy = false;
    let dec = |v: &str, lossy: &mut bool| {
        let (s, l) = decode_words(v);
        *lossy |= l;
        s
    };
    p.subject = hget(&head, "subject").map(|v| dec(v, &mut lossy).trim().to_string()).filter(|s| !s.is_empty());
    p.message_id = hget(&head, "message-id").and_then(clean_id);
    p.in_reply_to = hget(&head, "in-reply-to").and_then(|v| all_ids(v).into_iter().next().or_else(|| clean_id(v)));
    p.references = hget(&head, "references").map(all_ids).unwrap_or_default();
    p.from = hget(&head, "from").and_then(|v| parse_address_list(v).into_iter().next());
    p.to = hget(&head, "to").map(|v| parse_address_list(v).into_iter().map(|a| a.address).collect()).unwrap_or_default();
    p.cc = hget(&head, "cc").map(|v| parse_address_list(v).into_iter().map(|a| a.address).collect()).unwrap_or_default();
    p.date = hget(&head, "date").and_then(parse_date);
    p.lossy = lossy;

    {
        let mut w = Walk { out: &mut p, parts: 0, base: raw.as_ptr() as usize };
        walk(&mut w, &head, body, 0);
    }
    if p.html.is_some() && p.text.trim().is_empty() {
        p.text = html_to_text(p.html.as_deref().unwrap_or(""));
    }
    if let Some(h) = p.html.take() {
        let mut t = p.truncated;
        let cutd = cut(h, MAX_HTML, &mut t);
        p.truncated = t;
        p.html = Some(cutd);
    }
    let mut t = p.truncated;
    p.text = cut(std::mem::take(&mut p.text), MAX_TEXT, &mut t);
    p.truncated = t;
    p
}

#[cfg(test)]
mod tests {
    use super::*;

    fn crlf(s: &str) -> Vec<u8> {
        s.replace('\n', "\r\n").into_bytes()
    }

    #[test]
    fn simple_plain_message() {
        let raw = crlf("From: \"Sara Khan\" <Sara@Acme.co.uk>\nTo: me@x.com, Bob <bob@x.com>\nCc: c@x.com\nSubject: Hello there\nMessage-ID: <abc.123@acme.co.uk>\nIn-Reply-To: <prev@acme.co.uk>\nReferences: <a@x> <b@x>\nDate: Mon, 19 Oct 2026 04:10:00 +0500\n\nHi,\nHow are you?\n");
        let p = parse(&raw);
        assert_eq!(p.subject.as_deref(), Some("Hello there"));
        assert_eq!(p.message_id.as_deref(), Some("abc.123@acme.co.uk"));
        assert_eq!(p.in_reply_to.as_deref(), Some("prev@acme.co.uk"));
        assert_eq!(p.references, vec!["a@x", "b@x"]);
        assert_eq!(p.from, Some(Addr { name: Some("Sara Khan".into()), address: "sara@acme.co.uk".into() }));
        assert_eq!(p.to, vec!["me@x.com", "bob@x.com"]);
        assert_eq!(p.cc, vec!["c@x.com"]);
        assert_eq!(iso_utc(p.date.unwrap()), "2026-10-18T23:10:00Z");
        assert!(p.text.starts_with("Hi,\r\nHow are you?"));
        assert!(p.html.is_none() && p.attachments.is_empty() && !p.lossy);
    }

    #[test]
    fn encoded_words_in_subject_and_name() {
        let raw = crlf("From: =?UTF-8?B?w4lsw6g=?= <e@x.com>\nSubject: =?UTF-8?Q?Caf=C3=A9_menu?= =?UTF-8?Q?_2026?=\n\nbody");
        let p = parse(&raw);
        assert_eq!(p.subject.as_deref(), Some("Café menu 2026"));
        assert_eq!(p.from.unwrap().name.as_deref(), Some("Élè"));
        let (s, _) = decode_words("=?iso-8859-1?Q?J=F6rg?= says =?windows-1252?B?k2hp1A==?=");
        assert_eq!(s, "Jörg says “hiÔ");
        // broken encoded word is left alone, never panics
        assert_eq!(decode_words("=?utf-8?X?abc?=").0, "=?utf-8?X?abc?=");
        assert_eq!(decode_words("a =? b").0, "a =? b");
    }

    #[test]
    fn multipart_alternative_with_attachment() {
        let raw = crlf("Subject: Offer\nContent-Type: multipart/mixed; boundary=\"MIX\"\n\n--MIX\nContent-Type: multipart/alternative; boundary=ALT\n\n--ALT\nContent-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: quoted-printable\n\nPrice is =E2=82=AC10 =\nonly\n--ALT\nContent-Type: text/html; charset=utf-8\n\n<p>Price is <b>&euro;10</b></p>\n--ALT--\n\n--MIX\nContent-Type: application/pdf; name=\"quote.pdf\"\nContent-Disposition: attachment; filename=\"quote 2026.pdf\"\nContent-Transfer-Encoding: base64\n\nJVBERi0xLjQKJcfsj6IKNSAwIG9iago8PC9MZW5ndGggNiAwIFI+PgpzdHJlYW0K\n\n--MIX--\n");
        let p = parse(&raw);
        assert!(p.text.contains("Price is €10 only"), "{:?}", p.text);
        assert!(p.html.as_deref().unwrap().contains("<b>"));
        assert_eq!(p.attachments.len(), 1);
        assert_eq!(p.attachments[0].filename, "quote 2026.pdf");
        assert_eq!(p.attachments[0].mime, "application/pdf");
        assert_eq!(p.attachments[0].size, 48);
    }

    #[test]
    fn html_only_message_gets_a_text_version() {
        let raw = crlf("Content-Type: text/html; charset=utf-8\n\n<html><head><style>p{color:red}</style></head><body><p>Hello&nbsp;<b>World</b></p><script>x()</script><div>Line two &amp; more</div></body></html>");
        let p = parse(&raw);
        assert_eq!(p.text, "Hello World\nLine two & more");
        assert!(p.html.is_some());
    }

    #[test]
    fn inline_image_and_unnamed_parts_count_as_attachments() {
        let raw = crlf("Content-Type: multipart/related; boundary=R\n\n--R\nContent-Type: text/html\n\n<img src=cid:a>\n--R\nContent-Type: image/png\nContent-ID: <a>\nContent-Transfer-Encoding: base64\n\niVBORw0KGgo=\n--R--\n");
        let p = parse(&raw);
        assert_eq!(p.attachments.len(), 1);
        assert_eq!(p.attachments[0].filename, "inline-image");
        assert_eq!(p.attachments[0].size, 8);
    }

    #[test]
    fn rfc2231_filename_and_continuations() {
        let (_, p) = parse_params("attachment; filename*=UTF-8''r%C3%A9sum%C3%A9.pdf");
        assert_eq!(param(&p, "filename"), Some("résumé.pdf"));
        let (_, p) = parse_params("attachment; filename*0=\"long-na\"; filename*1=\"me.txt\"");
        assert_eq!(param(&p, "filename"), Some("long-name.txt"));
        let (_, p) = parse_params("attachment; filename*0*=utf-8''%D8%A7; filename*1*=%D8%A8.txt");
        assert_eq!(param(&p, "filename"), Some("اب.txt"));
        let (_, p) = parse_params("text/plain; charset=\"us-ascii\"; q=\"a;b\"");
        assert_eq!(param(&p, "q"), Some("a;b"));
    }

    #[test]
    fn charsets() {
        assert_eq!(decode_charset("iso-8859-1", b"caf\xe9"), ("café".to_string(), false));
        assert_eq!(decode_charset("windows-1252", b"\x93hi\x94 \x80"), ("“hi” €".to_string(), false));
        assert_eq!(decode_charset("iso-8859-15", b"\xa4"), ("€".to_string(), false));
        assert_eq!(decode_charset("utf-8", "اردو".as_bytes()), ("اردو".to_string(), false));
        let (s, l) = decode_charset("gb2312", b"ab\xc4\xe3");
        assert_eq!(s, "ab\u{fffd}\u{fffd}");
        assert!(l);
        // a lie: declared ascii, really latin-1
        assert!(decode_charset("us-ascii", b"caf\xe9").1);
    }

    #[test]
    fn dates() {
        assert_eq!(iso_utc(parse_date("Mon, 19 Oct 2026 04:10:00 +0500").unwrap()), "2026-10-18T23:10:00Z");
        assert_eq!(parse_date("Mon, 19 Oct 2026 04:10:00 +0500"), parse_date("Sun, 18 Oct 2026 23:10:00 GMT"));
        assert_eq!(iso_utc(parse_date("Thu, 1 Jan 2026 00:00:00 +0000").unwrap()), "2026-01-01T00:00:00Z");
        assert_eq!(iso_utc(parse_date("1 Jan 26 00:00 EST").unwrap()), "2026-01-01T05:00:00Z");
        assert_eq!(iso_utc(parse_date("19-Oct-2026 04:10:00 +0500").unwrap()), "2026-10-18T23:10:00Z");
        assert_eq!(iso_utc(parse_date("Fri, 29 Feb 2028 12:00:00 -0800 (PST)").unwrap()), "2028-02-29T20:00:00Z");
        assert_eq!(parse_date("Tue, 31 Feb 2026 12:00:00 +0000"), None);
        assert_eq!(parse_date("garbage"), None);
        assert_eq!(parse_date("32 Jan 2026 00:00:00"), None);
        assert_eq!(iso_utc(0), "1970-01-01T00:00:00Z");
    }

    #[test]
    fn address_forms() {
        let l = parse_address_list("\"Doe, John\" <John@X.com>, plain@y.com, Undisclosed recipients:;, Bob (the boss) <bob@z.org>");
        let addrs: Vec<&str> = l.iter().map(|a| a.address.as_str()).collect();
        assert_eq!(addrs, vec!["john@x.com", "plain@y.com", "bob@z.org"]);
        assert_eq!(l[0].name.as_deref(), Some("Doe, John"));
        assert!(parse_address("not an address").is_none());
        assert_eq!(clean_id("<a@b>").as_deref(), Some("a@b"));
        assert!(clean_id("<a b@c>").is_none());
    }

    #[test]
    fn base64_and_qp() {
        assert_eq!(base64_decode(b"SGVsbG8gd29ybGQ="), b"Hello world");
        assert_eq!(base64_decode(b"SGVs\r\nbG8="), b"Hello");
        assert_eq!(base64_len(b"SGVsbG8gd29ybGQ="), 11);
        assert_eq!(qp_decode(b"a=3Db=\r\nc=E9"), b"a=bc\xe9");
        assert_eq!(qp_decode(b"100%=\n"), b"100%");
        assert_eq!(qp_decode(b"end="), b"end=");
        assert_eq!(qp_decode(b"=Z1"), b"=Z1");
    }

    #[test]
    fn hostile_input_never_panics_and_stays_bounded() {
        // boundary missing, deeply nested, huge part count, binary garbage, truncated header, empty
        let mut deep = String::new();
        for i in 0..40 {
            deep.push_str(&format!("Content-Type: multipart/mixed; boundary=b{i}\n\n--b{i}\n"));
        }
        deep.push_str("Content-Type: text/plain\n\nhi\n");
        let cases: Vec<Vec<u8>> = vec![
            b"".to_vec(),
            b"\n\n\n".to_vec(),
            b"Subject".to_vec(),
            b"Content-Type: multipart/mixed\n\nbody".to_vec(),
            crlf(&deep),
            (0..=255u8).cycle().take(5000).collect(),
            b"From: <<<>>>\nTo: ,,,;;;\nDate: ((((\n\n=?=?=?=".to_vec(),
        ];
        for c in &cases {
            let _ = parse(c);
        }
        let mut many = String::from("Content-Type: multipart/mixed; boundary=B\n\n");
        for _ in 0..2000 {
            many.push_str("--B\nContent-Type: text/plain\n\nx\n");
        }
        many.push_str("--B--\n");
        let p = parse(&crlf(&many));
        assert!(p.lossy, "part cap must be reported");
    }

    #[test]
    fn long_bodies_are_cut_and_reported() {
        let big = "a".repeat(MAX_TEXT + 50);
        let raw = crlf(&format!("Content-Type: text/plain\n\n{big}"));
        let p = parse(&raw);
        assert_eq!(p.text.chars().count(), MAX_TEXT);
        assert!(p.truncated);
    }

    #[test]
    fn bare_lf_and_8bit_headers() {
        let raw = "Subject: Caf\u{e9}\nFrom: a@b.com\n\nbody".as_bytes().to_vec();
        let p = parse(&raw);
        assert_eq!(p.subject.as_deref(), Some("Café"));
        let mut raw2 = b"Subject: caf\xe9\n\nx".to_vec();
        raw2.extend_from_slice(b"");
        assert_eq!(parse(&raw2).subject.as_deref(), Some("café"));
        assert_eq!(parse(&raw).text, "body");
    }
}
