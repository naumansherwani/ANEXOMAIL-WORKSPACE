// export_core.rs — ASLI data export ka pure-std hissa (G36). Koi crate nahi, koi network nahi: sab unit-tested.
//   * ZipStream: streaming ZIP (store, data-descriptor) — file ke bytes pehle se jaanne ki zaroorat nahi, < 4 GB.
//   * mbox / CSV / vCard / iCalendar likhne ke helper (RFC 4155 mboxrd, RFC 4180, RFC 6350 v3, RFC 5545).
// Glue (export_glue.rs) DB se rows laata hai (E44 SQL) aur yahan ke helpers se bytes banata hai.
#![allow(dead_code)]

// ───────────────────────── CRC-32 (IEEE) ─────────────────────────
pub struct Crc32 {
    state: u32,
}
static CRC_TABLE: std::sync::OnceLock<[u32; 256]> = std::sync::OnceLock::new();
fn table() -> &'static [u32; 256] {
    CRC_TABLE.get_or_init(|| {
        let mut t = [0u32; 256];
        for i in 0..256u32 {
            let mut c = i;
            for _ in 0..8 {
                c = if c & 1 != 0 { 0xEDB8_8320 ^ (c >> 1) } else { c >> 1 };
            }
            t[i as usize] = c;
        }
        t
    })
}
impl Crc32 {
    pub fn new() -> Self {
        Crc32 { state: 0xFFFF_FFFF }
    }
    pub fn update(&mut self, data: &[u8]) {
        let t = table();
        let mut c = self.state;
        for &b in data {
            c = t[((c ^ b as u32) & 0xFF) as usize] ^ (c >> 8);
        }
        self.state = c;
    }
    pub fn finish(&self) -> u32 {
        self.state ^ 0xFFFF_FFFF
    }
}
pub fn crc32(data: &[u8]) -> u32 {
    let mut c = Crc32::new();
    c.update(data);
    c.finish()
}

// ───────────────────────── tareekh ─────────────────────────
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

/// ISO-8601 / Postgres timestamptz ("2026-10-20T14:03:11.123+05:00", "2026-10-20 14:03:11+00", "…Z") -> unix seconds (UTC).
pub fn parse_iso(s: &str) -> Option<i64> {
    let s = s.trim();
    let b = s.as_bytes();
    if b.len() < 10 || b[4] != b'-' || b[7] != b'-' {
        return None;
    }
    let num = |a: usize, z: usize| -> Option<i64> { s.get(a..z)?.parse::<i64>().ok() };
    let (y, mo, d) = (num(0, 4)?, num(5, 7)?, num(8, 10)?);
    if !(1..=12).contains(&mo) || !(1..=31).contains(&d) {
        return None;
    }
    let (mut h, mut mi, mut se) = (0, 0, 0);
    let mut rest = "";
    if b.len() > 10 {
        if b[10] != b'T' && b[10] != b' ' {
            return None;
        }
        h = num(11, 13)?;
        mi = num(14, 16)?;
        let mut p = 16;
        if b.len() > 16 && b[16] == b':' {
            se = num(17, 19)?;
            p = 19;
        }
        if b.len() > p && b[p] == b'.' {
            p += 1;
            while p < b.len() && b[p].is_ascii_digit() {
                p += 1;
            }
        }
        rest = &s[p..];
    }
    if h > 23 || mi > 59 || se > 60 {
        return None;
    }
    let mut off = 0i64;
    let r = rest.trim();
    if !r.is_empty() && r != "Z" && r != "z" {
        let sign = match r.as_bytes()[0] {
            b'+' => 1,
            b'-' => -1,
            _ => return None,
        };
        let digits: String = r[1..].chars().filter(|c| c.is_ascii_digit()).collect();
        let (oh, om) = match digits.len() {
            2 => (digits.parse::<i64>().ok()?, 0),
            4 => (digits[0..2].parse::<i64>().ok()?, digits[2..4].parse::<i64>().ok()?),
            _ => return None,
        };
        off = sign * (oh * 3600 + om * 60);
    }
    Some(days_from_civil(y, mo, d) * 86400 + h * 3600 + mi * 60 + se - off)
}

const WD: [&str; 7] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MON: [&str; 12] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

fn parts(unix: i64) -> (i64, i64, i64, i64, i64, i64, usize) {
    let days = unix.div_euclid(86400);
    let secs = unix.rem_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    let wd = (days + 4).rem_euclid(7) as usize; // 1970-01-01 = Thursday
    (y, m, d, secs / 3600, (secs % 3600) / 60, secs % 60, wd)
}
/// "Tue, 20 Oct 2026 14:03:11 +0000"
pub fn rfc2822(unix: i64) -> String {
    let (y, m, d, h, mi, s, wd) = parts(unix);
    format!("{}, {:02} {} {:04} {:02}:{:02}:{:02} +0000", WD[wd], d, MON[(m - 1) as usize], y, h, mi, s)
}
/// mbox "From " line ka waqt: "Tue Oct 20 14:03:11 2026"
pub fn asctime(unix: i64) -> String {
    let (y, m, d, h, mi, s, wd) = parts(unix);
    format!("{} {} {:2} {:02}:{:02}:{:02} {:04}", WD[wd], MON[(m - 1) as usize], d, h, mi, s, y)
}
/// iCalendar UTC: "20261020T140311Z"
pub fn ics_utc(unix: i64) -> String {
    let (y, m, d, h, mi, s, _) = parts(unix);
    format!("{:04}{:02}{:02}T{:02}{:02}{:02}Z", y, m, d, h, mi, s)
}
pub fn ics_date(unix: i64) -> String {
    let (y, m, d, ..) = parts(unix);
    format!("{:04}{:02}{:02}", y, m, d)
}

// ───────────────────────── base64 (sirf RFC 2047 subject ke liye) ─────────────────────────
pub fn b64(data: &[u8]) -> String {
    const A: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity(data.len().div_ceil(3) * 4);
    for c in data.chunks(3) {
        let n = (c[0] as u32) << 16 | (*c.get(1).unwrap_or(&0) as u32) << 8 | *c.get(2).unwrap_or(&0) as u32;
        out.push(A[(n >> 18) as usize & 63] as char);
        out.push(A[(n >> 12) as usize & 63] as char);
        out.push(if c.len() > 1 { A[(n >> 6) as usize & 63] as char } else { '=' });
        out.push(if c.len() > 2 { A[n as usize & 63] as char } else { '=' });
    }
    out
}

// ───────────────────────── mbox ─────────────────────────
#[derive(Default, Clone)]
pub struct MailMsg {
    pub from_name: String,
    pub from_addr: String,
    pub to: Vec<String>,
    pub cc: Vec<String>,
    pub subject: String,
    pub unix: i64,
    pub message_id: String,
    pub in_reply_to: String,
    pub body_text: String,
    pub body_html: String,
    pub folder: String,
}

/// header value: CR/LF/NUL hatao (header injection band)
fn hv(s: &str) -> String {
    s.chars().map(|c| if c == '\r' || c == '\n' || c == '\0' { ' ' } else { c }).collect::<String>().trim().to_string()
}
fn encode_word(s: &str) -> String {
    let s = hv(s);
    if s.is_ascii() {
        s
    } else {
        format!("=?UTF-8?B?{}?=", b64(s.as_bytes()))
    }
}
fn addr_clean(s: &str) -> String {
    hv(s).chars().filter(|c| !matches!(c, '<' | '>' | '"' | ',' | ';')).collect()
}
/// mboxrd: "From " (aur ">From ", ">>From " ...) se shuru hone wali body lines ko ek ">" aage
fn mbox_body(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 16);
    for line in s.replace("\r\n", "\n").replace('\r', "\n").split('\n') {
        let t = line.trim_start_matches('>');
        if t.starts_with("From ") {
            out.push('>');
        }
        out.push_str(line);
        out.push('\n');
    }
    out
}

pub fn mbox_entry(m: &MailMsg) -> Vec<u8> {
    let from = if m.from_addr.is_empty() { "unknown@invalid".to_string() } else { addr_clean(&m.from_addr) };
    let mut o = String::new();
    o.push_str(&format!("From {} {}\n", from.replace(' ', "_"), asctime(m.unix)));
    if m.from_name.trim().is_empty() {
        o.push_str(&format!("From: <{}>\n", from));
    } else {
        o.push_str(&format!("From: {} <{}>\n", encode_word(&m.from_name).replace('"', "'"), from));
    }
    if !m.to.is_empty() {
        o.push_str(&format!("To: {}\n", m.to.iter().map(|x| addr_clean(x)).collect::<Vec<_>>().join(", ")));
    }
    if !m.cc.is_empty() {
        o.push_str(&format!("Cc: {}\n", m.cc.iter().map(|x| addr_clean(x)).collect::<Vec<_>>().join(", ")));
    }
    o.push_str(&format!("Subject: {}\n", encode_word(&m.subject)));
    o.push_str(&format!("Date: {}\n", rfc2822(m.unix)));
    if !m.message_id.trim().is_empty() {
        o.push_str(&format!("Message-ID: <{}>\n", hv(&m.message_id).trim_matches(|c| c == '<' || c == '>')));
    }
    if !m.in_reply_to.trim().is_empty() {
        o.push_str(&format!("In-Reply-To: <{}>\n", hv(&m.in_reply_to).trim_matches(|c| c == '<' || c == '>')));
    }
    if !m.folder.trim().is_empty() {
        o.push_str(&format!("X-Anexomail-Folder: {}\n", hv(&m.folder)));
    }
    o.push_str("MIME-Version: 1.0\n");
    let text = m.body_text.trim_end();
    let html = m.body_html.trim_end();
    if !html.is_empty() && !text.is_empty() {
        let bd = format!("=_axexport_{:08x}", crc32(format!("{}{}", m.message_id, m.unix).as_bytes()));
        o.push_str(&format!("Content-Type: multipart/alternative; boundary=\"{}\"\n\n", bd));
        o.push_str(&format!("--{}\nContent-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: 8bit\n\n", bd));
        o.push_str(&mbox_body(text));
        o.push_str(&format!("--{}\nContent-Type: text/html; charset=utf-8\nContent-Transfer-Encoding: 8bit\n\n", bd));
        o.push_str(&mbox_body(html));
        o.push_str(&format!("--{}--\n", bd));
    } else if !html.is_empty() {
        o.push_str("Content-Type: text/html; charset=utf-8\nContent-Transfer-Encoding: 8bit\n\n");
        o.push_str(&mbox_body(html));
    } else {
        o.push_str("Content-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: 8bit\n\n");
        o.push_str(&mbox_body(text));
    }
    o.push('\n');
    o.into_bytes()
}

// ───────────────────────── CSV / vCard / iCalendar ─────────────────────────
/// RFC 4180. Spreadsheet formula injection se bachne ke liye = + - @ se shuru hone wali text ko ' se shuru.
pub fn csv_field(s: &str) -> String {
    let mut v = s.to_string();
    if matches!(v.chars().next(), Some('=') | Some('+') | Some('-') | Some('@') | Some('\t') | Some('\r')) {
        v.insert(0, '\'');
    }
    if v.contains(['"', ',', '\n', '\r']) {
        format!("\"{}\"", v.replace('"', "\"\""))
    } else {
        v
    }
}
pub fn csv_row(fields: &[&str]) -> String {
    let mut s = fields.iter().map(|f| csv_field(f)).collect::<Vec<_>>().join(",");
    s.push_str("\r\n");
    s
}

fn vesc(s: &str) -> String {
    s.replace('\\', "\\\\").replace('\r', "").replace('\n', "\\n").replace(',', "\\,").replace(';', "\\;")
}
/// RFC 6350/2426 v3.0
pub fn vcard(name: &str, emails: &[String], title: &str, org: &str, note: &str) -> String {
    let mut s = String::from("BEGIN:VCARD\r\nVERSION:3.0\r\n");
    let n = if name.trim().is_empty() { emails.first().cloned().unwrap_or_default() } else { name.to_string() };
    s.push_str(&fold(&format!("FN:{}", vesc(&n))));
    s.push_str(&fold(&format!("N:{};;;;", vesc(&n))));
    for e in emails {
        if !e.trim().is_empty() {
            s.push_str(&fold(&format!("EMAIL;TYPE=INTERNET:{}", vesc(e))));
        }
    }
    if !title.trim().is_empty() {
        s.push_str(&fold(&format!("TITLE:{}", vesc(title))));
    }
    if !org.trim().is_empty() {
        s.push_str(&fold(&format!("ORG:{}", vesc(org))));
    }
    if !note.trim().is_empty() {
        s.push_str(&fold(&format!("NOTE:{}", vesc(note))));
    }
    s.push_str("END:VCARD\r\n");
    s
}

/// RFC 5545 line folding: 75 octet se lambi line ko CRLF+space (UTF-8 character ke beech nahi tordte)
pub fn fold(line: &str) -> String {
    let mut out = String::new();
    let mut cur = 0usize;
    for ch in line.chars() {
        let l = ch.len_utf8();
        if cur + l > 75 {
            out.push_str("\r\n ");
            cur = 1;
        }
        out.push(ch);
        cur += l;
    }
    out.push_str("\r\n");
    out
}
fn iesc(s: &str) -> String {
    s.replace('\\', "\\\\").replace('\r', "").replace('\n', "\\n").replace(',', "\\,").replace(';', "\\;")
}
pub struct IcsEvent {
    pub uid: String,
    pub title: String,
    pub start: i64,
    pub end: i64,
    pub all_day: bool,
    pub location: String,
    pub description: String,
    pub status: String,
    pub organiser: String,
    pub attendees: Vec<String>,
}
pub fn ics_calendar_begin() -> String {
    "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//ANEXOMAIL//Export//EN\r\nCALSCALE:GREGORIAN\r\n".to_string()
}
pub fn ics_calendar_end() -> String {
    "END:VCALENDAR\r\n".to_string()
}
pub fn ics_event(e: &IcsEvent) -> String {
    let mut s = String::from("BEGIN:VEVENT\r\n");
    s.push_str(&fold(&format!("UID:{}@anexomail.com", iesc(&e.uid))));
    s.push_str(&fold(&format!("DTSTAMP:{}", ics_utc(e.start))));
    if e.all_day {
        s.push_str(&format!("DTSTART;VALUE=DATE:{}\r\n", ics_date(e.start)));
        s.push_str(&format!("DTEND;VALUE=DATE:{}\r\n", ics_date(e.end.max(e.start + 86400))));
    } else {
        s.push_str(&format!("DTSTART:{}\r\n", ics_utc(e.start)));
        s.push_str(&format!("DTEND:{}\r\n", ics_utc(e.end.max(e.start))));
    }
    s.push_str(&fold(&format!("SUMMARY:{}", iesc(&e.title))));
    if !e.location.trim().is_empty() {
        s.push_str(&fold(&format!("LOCATION:{}", iesc(&e.location))));
    }
    if !e.description.trim().is_empty() {
        s.push_str(&fold(&format!("DESCRIPTION:{}", iesc(&e.description))));
    }
    let st = match e.status.to_lowercase().as_str() {
        "cancelled" | "canceled" => "CANCELLED",
        "tentative" => "TENTATIVE",
        _ => "CONFIRMED",
    };
    s.push_str(&format!("STATUS:{}\r\n", st));
    if e.organiser.contains('@') {
        s.push_str(&fold(&format!("ORGANIZER:mailto:{}", e.organiser.trim())));
    }
    for a in &e.attendees {
        if a.contains('@') {
            s.push_str(&fold(&format!("ATTENDEE:mailto:{}", a.trim())));
        }
    }
    s.push_str("END:VEVENT\r\n");
    s
}


// ───────────────────────── blocked-account guard ke pure helpers (G37) ─────────────────────────
fn b64url_decode(s: &str) -> Option<Vec<u8>> {
    let mut out = Vec::with_capacity(s.len() * 3 / 4);
    let (mut buf, mut bits) = (0u32, 0u32);
    for c in s.trim_end_matches('=').bytes() {
        let v = match c {
            b'A'..=b'Z' => c - b'A',
            b'a'..=b'z' => c - b'a' + 26,
            b'0'..=b'9' => c - b'0' + 52,
            b'-' | b'+' => 62,
            b'_' | b'/' => 63,
            _ => return None,
        } as u32;
        buf = (buf << 6) | v;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push((buf >> bits) as u8);
            buf &= (1 << bits) - 1;
        }
    }
    Some(out)
}
pub fn valid_uuid(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 36 && b.iter().enumerate().all(|(i, c)| if matches!(i, 8 | 13 | 18 | 23) { *c == b'-' } else { c.is_ascii_hexdigit() })
}
/// JWT ka `sub` — SIGNATURE VERIFY NAHI (sirf "kis ka token hai" dekhne ke liye; asli verify baad mein Supabase karta hai).
/// Jhoota sub sirf us user ki halat dikhata hai; kisi ko access nahi deta.
pub fn jwt_sub(token: &str) -> Option<String> {
    let payload = token.split('.').nth(1)?;
    let bytes = b64url_decode(payload)?;
    let text = String::from_utf8(bytes).ok()?;
    let i = text.find("\"sub\"")?;
    let rest = &text[i + 5..];
    let q1 = rest.find('"')?;
    let rest2 = &rest[q1 + 1..];
    let q2 = rest2.find('"')?;
    let sub = &rest2[..q2];
    if valid_uuid(sub) { Some(sub.to_string()) } else { None }
}
/// Blocked account jo calls kar sakta hai (export, apni halat, apna delete).
pub fn allowed_when_blocked(proc: &str) -> bool {
    matches!(
        proc,
        "whoami" | "account.export.ticket" | "account.integrity.me" | "account.integrity.appeal" | "account.delete.state" | "account.delete.request" | "account.delete.cancel"
    )
}

/// E70: sign-up review (HOLD) ya rejected account sirf apni pehchan (whoami) pooch sakta hai — export bhi nahi, kuch bhi nahi.
pub fn allowed_when_held(proc: &str) -> bool {
    matches!(proc, "whoami")
}

/// E71: probation mein jo procs SIRF NAAM se band hain (input dekhne ki zaroorat nahi). Jawab = SQL `identity_probation_take` ka kind.
/// (calendar.create ka guest-invite wala hissa cal_glue mein, input dekh kar, usi SQL function se.)
pub fn probation_proc_kind(proc: &str) -> Option<&'static str> {
    match proc {
        "calendar.invites.resend" | "team.invites.create" | "team.invites.resend" => Some("invite"),
        "booking.page.set" => Some("public_link"),
        "people.import" => Some("bulk"),
        _ => None,
    }
}

/// E71: SQL ke `reason` ka insani lafz. Fingerprint / hold / vault ka zikr kabhi nahi.
pub fn probation_message(reason: &str, limit: Option<i64>, until: Option<&str>) -> String {
    let tail = match until {
        Some(u) if u.len() >= 10 => format!(" These limits end on {}, or as soon as you subscribe to a plan.", &u[..10]),
        _ => " These limits end when your account is a few days old, or as soon as you subscribe to a plan.".to_string(),
    };
    let head = match reason {
        "probation_recipients" => format!("New accounts can send to up to {} people per message.", limit.unwrap_or(20)),
        "probation_daily" => format!("New accounts can send up to {} messages per day. You can send more tomorrow.", limit.unwrap_or(50)),
        "probation_invites" => "Invitations are not available on a brand-new account yet.".to_string(),
        "probation_links" => "Public links are not available on a brand-new account yet.".to_string(),
        "probation_bulk" => "Bulk imports are not available on a brand-new account yet.".to_string(),
        _ => "This is not available on a brand-new account yet.".to_string(),
    };
    format!("{head}{tail}")
}

// ───────────────────────── file ka naam ─────────────────────────
/// ZIP entry ka naam: path-traversal / control chars hata kar. `dir/` prefix glue deta hai.
pub fn safe_name(s: &str) -> String {
    let base = s.rsplit(['/', '\\']).next().unwrap_or("");
    let cleaned: String = base
        .chars()
        .map(|c| if c.is_control() || matches!(c, ':' | '*' | '?' | '"' | '<' | '>' | '|') { '_' } else { c })
        .collect();
    let cleaned = cleaned.trim().trim_matches('.').to_string();
    let cleaned: String = cleaned.chars().take(120).collect();
    if cleaned.is_empty() { "file".to_string() } else { cleaned }
}

// ───────────────────────── ZIP (streaming, store) ─────────────────────────
struct Entry {
    name: String,
    crc: u32,
    size: u64,
    offset: u64,
    dos_time: u16,
    dos_date: u16,
}
struct Cur {
    name: String,
    crc: Crc32,
    size: u64,
    offset: u64,
    dos_time: u16,
    dos_date: u16,
}
pub const ZIP_LIMIT: u64 = 4_000_000_000;

pub struct ZipStream {
    entries: Vec<Entry>,
    cur: Option<Cur>,
    pos: u64,
}
fn dos(unix: i64) -> (u16, u16) {
    let (y, m, d, h, mi, s, _) = parts(unix);
    let y = y.clamp(1980, 2107);
    (((h << 11) | (mi << 5) | (s / 2)) as u16, (((y - 1980) << 9) | (m << 5) | d) as u16)
}
fn le16(v: &mut Vec<u8>, n: u16) {
    v.extend_from_slice(&n.to_le_bytes());
}
fn le32(v: &mut Vec<u8>, n: u32) {
    v.extend_from_slice(&n.to_le_bytes());
}
impl ZipStream {
    pub fn new() -> Self {
        ZipStream { entries: vec![], cur: None, pos: 0 }
    }
    /// Local header (flag bit 3: sizes baad mein descriptor mein; bit 11: UTF-8 naam). Bytes jo client ko bhejne hain.
    pub fn begin_file(&mut self, name: &str, unix: i64) -> Vec<u8> {
        assert!(self.cur.is_none(), "pehli file band karo");
        let (t, d) = dos(unix);
        let nb = name.as_bytes();
        let mut h = Vec::with_capacity(30 + nb.len());
        le32(&mut h, 0x0403_4B50);
        le16(&mut h, 20);
        le16(&mut h, 0x0808);
        le16(&mut h, 0); // store
        le16(&mut h, t);
        le16(&mut h, d);
        le32(&mut h, 0);
        le32(&mut h, 0);
        le32(&mut h, 0);
        le16(&mut h, nb.len() as u16);
        le16(&mut h, 0);
        h.extend_from_slice(nb);
        self.cur = Some(Cur { name: name.to_string(), crc: Crc32::new(), size: 0, offset: self.pos, dos_time: t, dos_date: d });
        self.pos += h.len() as u64;
        h
    }
    /// Data ka hissa: crc/size/offset update karta hai. Caller wahi bytes client ko bhejta hai.
    pub fn account(&mut self, data: &[u8]) {
        let c = self.cur.as_mut().expect("file khuli nahi");
        c.crc.update(data);
        c.size += data.len() as u64;
        self.pos += data.len() as u64;
    }
    pub fn end_file(&mut self) -> Vec<u8> {
        let c = self.cur.take().expect("file khuli nahi");
        let crc = c.crc.finish();
        let mut d = Vec::with_capacity(16);
        le32(&mut d, 0x0807_4B50);
        le32(&mut d, crc);
        le32(&mut d, c.size as u32);
        le32(&mut d, c.size as u32);
        self.pos += d.len() as u64;
        self.entries.push(Entry { name: c.name, crc, size: c.size, offset: c.offset, dos_time: c.dos_time, dos_date: c.dos_date });
        d
    }
    /// 4 GB ki hadd paar hone wali hai? (glue export rok kar sach batata hai)
    pub fn would_exceed(&self, more: u64) -> bool {
        self.pos + more + 4096 + (self.entries.len() as u64 + 1) * 120 > ZIP_LIMIT
    }
    pub fn position(&self) -> u64 {
        self.pos
    }
    pub fn files(&self) -> usize {
        self.entries.len()
    }
    pub fn finish(&mut self) -> Vec<u8> {
        assert!(self.cur.is_none(), "file khuli hai");
        let start = self.pos;
        let mut cd = Vec::new();
        for e in &self.entries {
            let nb = e.name.as_bytes();
            le32(&mut cd, 0x0201_4B50);
            le16(&mut cd, 20);
            le16(&mut cd, 20);
            le16(&mut cd, 0x0808);
            le16(&mut cd, 0);
            le16(&mut cd, e.dos_time);
            le16(&mut cd, e.dos_date);
            le32(&mut cd, e.crc);
            le32(&mut cd, e.size as u32);
            le32(&mut cd, e.size as u32);
            le16(&mut cd, nb.len() as u16);
            le16(&mut cd, 0);
            le16(&mut cd, 0);
            le16(&mut cd, 0);
            le16(&mut cd, 0);
            le32(&mut cd, 0);
            le32(&mut cd, e.offset as u32);
            cd.extend_from_slice(nb);
        }
        let size = cd.len() as u32;
        le32(&mut cd, 0x0605_4B50);
        le16(&mut cd, 0);
        le16(&mut cd, 0);
        le16(&mut cd, self.entries.len() as u16);
        le16(&mut cd, self.entries.len() as u16);
        le32(&mut cd, size);
        le32(&mut cd, start as u32);
        le16(&mut cd, 0);
        self.pos += cd.len() as u64;
        cd
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn crc_known() {
        assert_eq!(crc32(b"123456789"), 0xCBF4_3926);
        assert_eq!(crc32(b""), 0);
        let mut c = Crc32::new();
        c.update(b"1234");
        c.update(b"56789");
        assert_eq!(c.finish(), 0xCBF4_3926);
    }

    #[test]
    fn iso_and_formats() {
        // 2026-10-20T14:03:11Z
        let u = parse_iso("2026-10-20T14:03:11.123+00:00").unwrap();
        assert_eq!(rfc2822(u), "Tue, 20 Oct 2026 14:03:11 +0000");
        assert_eq!(asctime(u), "Tue Oct 20 14:03:11 2026");
        assert_eq!(ics_utc(u), "20261020T140311Z");
        assert_eq!(parse_iso("2026-10-20 19:03:11+05").unwrap(), u);
        assert_eq!(parse_iso("2026-10-20T19:03:11+0500").unwrap(), u);
        assert_eq!(parse_iso("2026-10-20T14:03:11Z").unwrap(), u);
        assert_eq!(parse_iso("2026-10-20").unwrap(), u - 14 * 3600 - 3 * 60 - 11);
        assert_eq!(parse_iso("1970-01-01T00:00:00Z"), Some(0));
        assert_eq!(rfc2822(0), "Thu, 01 Jan 1970 00:00:00 +0000");
        assert_eq!(rfc2822(951_782_400), "Tue, 29 Feb 2000 00:00:00 +0000"); // leap day
        assert!(parse_iso("nonsense").is_none());
        assert!(parse_iso("2026-13-01").is_none());
        assert!(parse_iso("2026-10-20T25:00:00Z").is_none());
    }

    #[test]
    fn b64_vectors() {
        assert_eq!(b64(b""), "");
        assert_eq!(b64(b"f"), "Zg==");
        assert_eq!(b64(b"fo"), "Zm8=");
        assert_eq!(b64(b"foo"), "Zm9v");
        assert_eq!(b64(b"foobar"), "Zm9vYmFy");
    }

    #[test]
    fn mbox_basic_and_escaping() {
        let m = MailMsg {
            from_name: "Ann \"A\"".into(),
            from_addr: "ann@x.com".into(),
            to: vec!["me@anexomail.com".into()],
            subject: "Hello\r\nBcc: evil@x.com".into(),
            unix: 0,
            message_id: "<abc@x>".into(),
            body_text: "hi\nFrom here\n>From there\n>>From deep\nbye".into(),
            folder: "inbox".into(),
            ..Default::default()
        };
        let s = String::from_utf8(mbox_entry(&m)).unwrap();
        assert!(s.starts_with("From ann@x.com Thu Jan  1 00:00:00 1970\n"));
        assert!(s.contains("Subject: Hello  Bcc: evil@x.com\n")); // header injection band
        assert!(!s.contains("\nBcc:"));
        assert!(s.contains("\n>From here\n"));
        assert!(s.contains("\n>>From there\n"));
        assert!(s.contains("\n>>>From deep\n"));
        assert!(s.contains("Message-ID: <abc@x>\n"));
        assert!(s.contains("X-Anexomail-Folder: inbox\n"));
        assert!(s.ends_with("bye\n\n"));
        if let Ok(p) = std::env::var("AX_MBOX_OUT") {
            let mut all = mbox_entry(&m);
            all.extend(mbox_entry(&MailMsg { from_addr: "z@z.z".into(), subject: "second".into(), body_text: "two".into(), unix: 86400, ..Default::default() }));
            std::fs::write(p, all).unwrap();
        }
    }

    #[test]
    fn mbox_unicode_subject_and_multipart() {
        let m = MailMsg { from_addr: "a@b.c".into(), subject: "Salām".into(), body_text: "t".into(), body_html: "<p>t</p>".into(), unix: 1, message_id: "m".into(), ..Default::default() };
        let s = String::from_utf8(mbox_entry(&m)).unwrap();
        assert!(s.contains("Subject: =?UTF-8?B?U2FsxIFt?=\n"));
        assert!(s.contains("multipart/alternative"));
        assert_eq!(s.matches("--=_axexport_").count(), 3);
    }

    #[test]
    fn csv_quoting_and_injection() {
        assert_eq!(csv_field("plain"), "plain");
        assert_eq!(csv_field("a,b"), "\"a,b\"");
        assert_eq!(csv_field("say \"hi\""), "\"say \"\"hi\"\"\"");
        assert_eq!(csv_field("=SUM(A1)"), "'=SUM(A1)");
        assert_eq!(csv_field("-5"), "'-5");
        assert_eq!(csv_row(&["a", "b c", "d\ne"]), "a,b c,\"d\ne\"\r\n");
    }

    #[test]
    fn vcard_and_ics() {
        let v = vcard("Ann, Jr", &["ann@x.com".to_string()], "CEO", "X; Inc", "line1\nline2");
        assert!(v.contains("FN:Ann\\, Jr\r\n"));
        assert!(v.contains("EMAIL;TYPE=INTERNET:ann@x.com\r\n"));
        assert!(v.contains("ORG:X\\; Inc\r\n"));
        assert!(v.contains("NOTE:line1\\nline2\r\n"));
        assert!(v.ends_with("END:VCARD\r\n"));
        let e = IcsEvent { uid: "u1".into(), title: "Sync; team".into(), start: 0, end: 3600, all_day: false, location: "".into(), description: "d".into(), status: "cancelled".into(), organiser: "o@x.com".into(), attendees: vec!["a@x.com".into(), "junk".into()] };
        let s = ics_event(&e);
        assert!(s.contains("DTSTART:19700101T000000Z\r\n"));
        assert!(s.contains("DTEND:19700101T010000Z\r\n"));
        assert!(s.contains("SUMMARY:Sync\\; team\r\n"));
        assert!(s.contains("STATUS:CANCELLED\r\n"));
        assert!(s.contains("ATTENDEE:mailto:a@x.com\r\n"));
        assert!(!s.contains("junk"));
        let all = IcsEvent { all_day: true, ..e };
        assert!(ics_event(&all).contains("DTSTART;VALUE=DATE:19700101\r\n"));
    }

    #[test]
    fn folding_respects_utf8() {
        let long = "SUMMARY:".to_string() + &"é".repeat(60);
        let f = fold(&long);
        for l in f.split("\r\n").filter(|l| !l.is_empty()) {
            assert!(l.len() <= 75, "line {} bytes", l.len());
        }
        assert_eq!(f.replace("\r\n ", "").trim_end(), long);
    }

    #[test]
    fn names_are_safe() {
        assert_eq!(safe_name("../../etc/passwd"), "passwd");
        assert_eq!(safe_name("C:\\x\\y.pdf"), "y.pdf");
        assert_eq!(safe_name("a:b*c?.txt"), "a_b_c_.txt");
        assert_eq!(safe_name("..."), "file");
        assert_eq!(safe_name(""), "file");
        assert_eq!(safe_name("ok name.pdf"), "ok name.pdf");
    }

    #[test]
    fn jwt_sub_and_guard_helpers() {
        // header.payload.sig  — payload {"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}
        let payload = b64("{\"sub\":\"00000000-0000-0000-0000-0000000000a1\",\"role\":\"authenticated\"}".as_bytes())
            .replace('+', "-").replace('/', "_").trim_end_matches('=').to_string();
        let tok = format!("eyJhbGciOiJIUzI1NiJ9.{payload}.sig");
        assert_eq!(jwt_sub(&tok).as_deref(), Some("00000000-0000-0000-0000-0000000000a1"));
        assert_eq!(jwt_sub("garbage"), None);
        assert_eq!(jwt_sub("a.b.c"), None);
        let bad = b64("{\"sub\":\"x' or 1=1\"}".as_bytes()).replace('+', "-").replace('/', "_").trim_end_matches('=').to_string();
        assert_eq!(jwt_sub(&format!("h.{bad}.s")), None);
        assert!(valid_uuid("00000000-0000-0000-0000-0000000000a1"));
        assert!(!valid_uuid("00000000000000000000000000000000"));
        assert!(!valid_uuid("00000000-0000-0000-0000-0000000000a1; drop"));
        assert!(allowed_when_blocked("account.export.ticket"));
        assert!(allowed_when_blocked("account.integrity.me"));
        assert!(allowed_when_blocked("account.integrity.appeal"));
        assert!(!allowed_when_blocked("mail.send"));
        assert!(!allowed_when_blocked("chat.send"));
    }

    #[test]
    fn held_account_gets_only_whoami() {
        assert!(allowed_when_held("whoami"));
        for p in ["account.export.ticket", "account.integrity.me", "mail.send", "calendar.create", "account.delete.request", "x"] {
            assert!(!allowed_when_held(p), "{p}");
        }
    }

    #[test]
    fn probation_closes_invites_links_and_bulk_by_name() {
        assert_eq!(probation_proc_kind("calendar.invites.resend"), Some("invite"));
        assert_eq!(probation_proc_kind("team.invites.create"), Some("invite"));
        assert_eq!(probation_proc_kind("team.invites.resend"), Some("invite"));
        assert_eq!(probation_proc_kind("booking.page.set"), Some("public_link"));
        assert_eq!(probation_proc_kind("people.import"), Some("bulk"));
        for p in ["calendar.create", "calendar.busy", "booking.public.book", "team.members.list", "mail.send", "whoami"] {
            assert_eq!(probation_proc_kind(p), None, "{p}");
        }
    }

    #[test]
    fn probation_messages_state_the_limit_and_never_leak_internals() {
        let m = probation_message("probation_recipients", Some(20), Some("2026-10-30T10:00:00Z"));
        assert!(m.contains("20 people") && m.contains("2026-10-30"));
        assert!(probation_message("probation_daily", None, None).contains("50 messages"));
        for r in ["probation_recipients", "probation_daily", "probation_invites", "probation_links", "probation_bulk", "zzz"] {
            let t = probation_message(r, None, None).to_lowercase();
            for bad in ["finger", "vault", "hold", "banned", "review", "match"] {
                assert!(!t.contains(bad), "{r}: {bad}");
            }
        }
        // short / odd `until` never panics
        assert!(!probation_message("probation_bulk", None, Some("x")).is_empty());
    }

    #[test]
    fn zip_layout_is_consistent() {
        let mut z = ZipStream::new();
        let mut out = Vec::new();
        out.extend(z.begin_file("a.txt", 0));
        let a = b"hello world";
        z.account(a);
        out.extend_from_slice(a);
        out.extend(z.end_file());
        out.extend(z.begin_file("dir/b.bin", 1_700_000_000));
        let b: Vec<u8> = (0..=255u8).collect();
        z.account(&b[..100]);
        z.account(&b[100..]);
        out.extend_from_slice(&b);
        out.extend(z.end_file());
        out.extend(z.begin_file("empty.txt", 0));
        out.extend(z.end_file());
        out.extend(z.finish());
        assert_eq!(z.files(), 3);
        assert_eq!(z.position(), out.len() as u64);
        // EOCD
        let n = out.len();
        assert_eq!(&out[n - 22..n - 18], &[0x50, 0x4b, 0x05, 0x06]);
        assert_eq!(u16::from_le_bytes([out[n - 12], out[n - 11]]), 3);
        if let Ok(p) = std::env::var("AX_ZIP_OUT") {
            std::fs::write(p, &out).unwrap();
        }
    }
}
