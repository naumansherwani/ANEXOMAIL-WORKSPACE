// ============================================================================
// ANEXOMAIL — Calendar core (Rust, std ONLY: no crates, no network, no clock, no randomness)
//
// Yeh file `mod cal_core;` ki tarah main.rs mein judti hai (installer: docs/cursor-work/server/rust-calendar-install.sh).
// Sirf PURE functions: invitation (iMIP/iTIP) ICS + MIME, RSVP, busy-merge, common free slots, quota, SMTP reply parse.
// I/O (Supabase, SMTP socket) alag file `cal_glue.rs` mein hai — yahan kuch bhi bahar nahi jata,
// is liye sandbox mein `rustc --test` se poori tarah test hoti hai:
//
//   rustc --edition 2021 --test server/rust/cal_core.rs -o /tmp/cal_core_test && /tmp/cal_core_test
//
// Standards: RFC 5545 (iCalendar), RFC 5546 (iTIP), RFC 6047 (iMIP), RFC 2047 (header encoding),
//            RFC 5321 (SMTP dot-stuffing), RFC 4648 (base64).
// ============================================================================
#![allow(dead_code)]

/* ------------------------------------------------------------------ time */

/// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's algorithm).
pub fn days_from_civil(y: i64, m: u32, d: u32) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let mp = (m as i64 + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d as i64 - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe - 719468
}

pub fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}

/// "2026-10-20T14:00:00+00:00" / "...Z" / "2026-10-20 14:00:00+00" / fractional seconds -> epoch seconds (UTC).
pub fn parse_ts(s: &str) -> Option<i64> {
    let s = s.trim();
    let b = s.as_bytes();
    if b.len() < 19 {
        return None;
    }
    let num = |a: usize, n: usize| -> Option<i64> {
        let part = s.get(a..a + n)?;
        if !part.bytes().all(|c| c.is_ascii_digit()) {
            return None;
        }
        part.parse::<i64>().ok()
    };
    if b[4] != b'-'
        || b[7] != b'-'
        || (b[10] != b'T' && b[10] != b' ')
        || b[13] != b':'
        || b[16] != b':'
    {
        return None;
    }
    let (y, mo, d) = (num(0, 4)?, num(5, 2)?, num(8, 2)?);
    let (h, mi, se) = (num(11, 2)?, num(14, 2)?, num(17, 2)?);
    if !(1..=12).contains(&mo) || !(1..=31).contains(&d) || h > 23 || mi > 59 || se > 60 {
        return None;
    }
    let mut i = 19;
    if i < b.len() && b[i] == b'.' {
        i += 1;
        while i < b.len() && b[i].is_ascii_digit() {
            i += 1;
        }
    }
    let mut off = 0i64;
    if i < b.len() {
        match b[i] {
            b'Z' | b'z' => {}
            b'+' | b'-' => {
                let sign = if b[i] == b'+' { 1 } else { -1 };
                let rest: String = s[i + 1..].chars().filter(|c| *c != ':').collect();
                if rest.len() != 2 && rest.len() != 4 {
                    return None;
                }
                let oh: i64 = rest.get(0..2)?.parse().ok()?;
                let om: i64 = if rest.len() == 4 {
                    rest.get(2..4)?.parse().ok()?
                } else {
                    0
                };
                if oh > 14 || om > 59 {
                    return None;
                }
                off = sign * (oh * 3600 + om * 60);
            }
            _ => return None,
        }
    }
    Some(days_from_civil(y, mo as u32, d as u32) * 86400 + h * 3600 + mi * 60 + se - off)
}

fn two(n: i64) -> String {
    format!("{:02}", n)
}

/// 20261020T140000Z
pub fn fmt_ics(epoch: i64) -> String {
    let days = epoch.div_euclid(86400);
    let rem = epoch.rem_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    format!(
        "{:04}{}{}T{}{}{}Z",
        y,
        two(m as i64),
        two(d as i64),
        two(rem / 3600),
        two(rem % 3600 / 60),
        two(rem % 60)
    )
}

/// 2026-10-20T14:00:00Z
pub fn fmt_rfc3339(epoch: i64) -> String {
    let days = epoch.div_euclid(86400);
    let rem = epoch.rem_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    format!(
        "{:04}-{}-{}T{}:{}:{}Z",
        y,
        two(m as i64),
        two(d as i64),
        two(rem / 3600),
        two(rem % 3600 / 60),
        two(rem % 60)
    )
}

const WD: [&str; 7] = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"]; // 1970-01-01 was a Thursday
const MON: [&str; 12] = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

pub fn weekday_name(epoch: i64) -> &'static str {
    WD[epoch.div_euclid(86400).rem_euclid(7) as usize]
}

/// "Tue 20 Oct 2026, 14:00 UTC" — fallback label when the browser gave no local one.
pub fn fmt_human_utc(epoch: i64) -> String {
    let days = epoch.div_euclid(86400);
    let rem = epoch.rem_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    format!(
        "{} {} {} {}, {}:{} UTC",
        weekday_name(epoch),
        d,
        MON[(m - 1) as usize],
        y,
        two(rem / 3600),
        two(rem % 3600 / 60)
    )
}

/// RFC 5322 Date header: "Tue, 20 Oct 2026 14:00:00 +0000"
pub fn fmt_rfc2822(epoch: i64) -> String {
    let days = epoch.div_euclid(86400);
    let rem = epoch.rem_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    format!(
        "{}, {} {} {} {}:{}:{} +0000",
        weekday_name(epoch),
        d,
        MON[(m - 1) as usize],
        y,
        two(rem / 3600),
        two(rem % 3600 / 60),
        two(rem % 60)
    )
}

/* ------------------------------------------------------------------ text */

/// Header injection ka rasta band: koi CR/LF/NUL/control char header ya display-name mein nahi jata.
pub fn clean_line(s: &str, max: usize) -> String {
    let t: String = s
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect();
    let t = t.split_whitespace().collect::<Vec<_>>().join(" ");
    t.chars().take(max).collect()
}

pub fn html_escape(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 8);
    for c in s.chars() {
        match c {
            '&' => o.push_str("&amp;"),
            '<' => o.push_str("&lt;"),
            '>' => o.push_str("&gt;"),
            '"' => o.push_str("&quot;"),
            '\'' => o.push_str("&#39;"),
            _ => o.push(c),
        }
    }
    o
}

/// iCalendar TEXT escaping (RFC 5545 §3.3.11).
pub fn ics_escape(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 8);
    let mut prev_cr = false;
    for c in s.chars() {
        match c {
            '\\' => o.push_str("\\\\"),
            ';' => o.push_str("\\;"),
            ',' => o.push_str("\\,"),
            '\r' => {
                o.push_str("\\n");
                prev_cr = true;
                continue;
            }
            '\n' => {
                if !prev_cr {
                    o.push_str("\\n");
                }
            }
            c if c.is_control() && c != '\t' => {}
            c => o.push(c),
        }
        prev_cr = false;
    }
    o
}

/// Content line folding: max 75 octets per physical line, never inside a UTF-8 sequence (RFC 5545 §3.1).
pub fn fold_line(line: &str) -> String {
    let mut out = String::with_capacity(line.len() + line.len() / 70 * 3);
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
    out
}

/// Parameter value (CN=...) — always quoted, quotes stripped.
fn param_quote(s: &str) -> String {
    let t: String = clean_line(s, 120).chars().filter(|c| *c != '"').collect();
    format!("\"{}\"", t)
}

/* ---------------------------------------------------------------- base64 */

const B64: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

pub fn base64(data: &[u8]) -> String {
    let mut o = String::with_capacity(data.len() * 4 / 3 + 4);
    for ch in data.chunks(3) {
        let b = [ch[0], *ch.get(1).unwrap_or(&0), *ch.get(2).unwrap_or(&0)];
        let n = ((b[0] as u32) << 16) | ((b[1] as u32) << 8) | b[2] as u32;
        o.push(B64[(n >> 18) as usize & 63] as char);
        o.push(B64[(n >> 12) as usize & 63] as char);
        o.push(if ch.len() > 1 {
            B64[(n >> 6) as usize & 63] as char
        } else {
            '='
        });
        o.push(if ch.len() > 2 {
            B64[n as usize & 63] as char
        } else {
            '='
        });
    }
    o
}

/// base64 for a MIME body: 76-char lines, CRLF.
pub fn base64_mime(data: &[u8]) -> String {
    let flat = base64(data);
    let mut o = String::with_capacity(flat.len() + flat.len() / 76 * 2 + 2);
    let bytes = flat.as_bytes();
    for chunk in bytes.chunks(76) {
        o.push_str(std::str::from_utf8(chunk).unwrap_or(""));
        o.push_str("\r\n");
    }
    o
}

/// RFC 2047 encoded-word for a header value that is not pure ASCII.
pub fn encode_header(s: &str) -> String {
    let t = clean_line(s, 300);
    if t.is_ascii() {
        return t;
    }
    // chunk on char boundaries so each encoded-word stays under 75 chars (<= 36 raw bytes -> 48 base64)
    let mut words: Vec<String> = Vec::new();
    let mut cur = String::new();
    for c in t.chars() {
        if cur.len() + c.len_utf8() > 36 {
            words.push(format!("=?UTF-8?B?{}?=", base64(cur.as_bytes())));
            cur.clear();
        }
        cur.push(c);
    }
    if !cur.is_empty() {
        words.push(format!("=?UTF-8?B?{}?=", base64(cur.as_bytes())));
    }
    words.join("\r\n ")
}

/// `"Display Name" <a@b.c>` — name encoded/quoted safely, address must already be validated.
pub fn mailbox(name: Option<&str>, address: &str) -> String {
    match name.map(|n| clean_line(n, 120)).filter(|n| !n.is_empty()) {
        Some(n) if n.is_ascii() => {
            let q: String = n.chars().filter(|c| *c != '"' && *c != '\\').collect();
            format!("\"{}\" <{}>", q, address)
        }
        Some(n) => format!("{} <{}>", encode_header(&n), address),
        None => format!("<{}>", address),
    }
}

/* -------------------------------------------------------------- addresses */

/// Strict, boring email check. Header-injection characters can never pass.
pub fn valid_email(s: &str) -> bool {
    let s = s.trim();
    if s.len() < 6 || s.len() > 254 {
        return false;
    }
    let mut parts = s.split('@');
    let (Some(local), Some(domain), None) = (parts.next(), parts.next(), parts.next()) else {
        return false;
    };
    if local.is_empty() || local.len() > 64 || domain.len() < 4 {
        return false;
    }
    let ok_local = local
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || "!#$%&'*+-/=?^_`{|}~.".contains(c))
        && !local.starts_with('.')
        && !local.ends_with('.')
        && !local.contains("..");
    if !ok_local || !domain.contains('.') {
        return false;
    }
    let labels: Vec<&str> = domain.split('.').collect();
    labels.iter().all(|l| {
        !l.is_empty()
            && l.len() <= 63
            && !l.starts_with('-')
            && !l.ends_with('-')
            && l.chars().all(|c| c.is_ascii_alphanumeric() || c == '-')
    }) && labels
        .last()
        .map(|t| t.len() >= 2 && t.chars().all(|c| c.is_ascii_alphabetic()))
        .unwrap_or(false)
}

pub struct AttendeeList {
    pub kept: Vec<String>,
    pub invalid: usize,
    pub duplicate: usize,
    pub over_cap: usize,
}

/// Lower-cases, validates and de-duplicates. The organiser is always first. `cap` counts everyone except the organiser.
pub fn normalise_attendees(list: &[String], organiser: &str, cap: usize) -> AttendeeList {
    let org = organiser.trim().to_lowercase();
    let mut out = AttendeeList {
        kept: vec![org.clone()],
        invalid: 0,
        duplicate: 0,
        over_cap: 0,
    };
    for raw in list {
        let a = raw
            .trim()
            .trim_matches(|c| c == '<' || c == '>')
            .to_lowercase();
        if a.is_empty() {
            continue;
        }
        if !valid_email(&a) {
            out.invalid += 1;
        } else if out.kept.contains(&a) {
            out.duplicate += 1;
        } else if out.kept.len() - 1 >= cap {
            out.over_cap += 1;
        } else {
            out.kept.push(a);
        }
    }
    out
}

/* ------------------------------------------------------------------ RSVP */

/// yes|maybe|no (and the iCalendar words) -> the value stored in calendar_attendees.response
pub fn rsvp_value(s: &str) -> Option<&'static str> {
    match s.trim().to_lowercase().as_str() {
        "yes" | "accept" | "accepted" => Some("accepted"),
        "maybe" | "tentative" => Some("tentative"),
        "no" | "decline" | "declined" => Some("declined"),
        _ => None,
    }
}

pub fn partstat(response: &str) -> &'static str {
    match response {
        "accepted" => "ACCEPTED",
        "tentative" => "TENTATIVE",
        "declined" => "DECLINED",
        _ => "NEEDS-ACTION",
    }
}

/// RSVP token is a DB-issued random uuid (calendar_attendees.rsvp_token). Only its SHAPE is checked here so that
/// nothing odd ever reaches a PostgREST filter.
pub fn token_shape_ok(t: &str) -> bool {
    t.len() == 36
        && t.char_indices().all(|(i, c)| {
            if [8, 13, 18, 23].contains(&i) {
                c == '-'
            } else {
                c.is_ascii_hexdigit()
            }
        })
}

/* ------------------------------------------------------------------- ICS */

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Method {
    Request,
    Cancel,
}

impl Method {
    pub fn word(self) -> &'static str {
        match self {
            Method::Request => "REQUEST",
            Method::Cancel => "CANCEL",
        }
    }
}

#[derive(Clone, Debug)]
pub struct Person {
    pub address: String,
    pub name: Option<String>,
}

#[derive(Clone, Debug)]
pub struct Guest {
    pub address: String,
    pub name: Option<String>,
    pub optional: bool,
    /// stored response: needs_action | accepted | tentative | declined
    pub response: String,
}

#[derive(Clone, Debug)]
pub struct EventSpec {
    /// stable id — the calendar_events.id uuid; becomes `<id>@anexomail.com`
    pub id: String,
    pub sequence: u32,
    pub title: String,
    pub agenda: Option<String>,
    pub starts: i64,
    pub ends: i64,
    pub location: Option<String>,
    pub organiser: Person,
    pub guests: Vec<Guest>,
    pub now: i64,
}

pub const DOMAIN: &str = "anexomail.com";

pub fn build_ics(method: Method, ev: &EventSpec, app_url: &str) -> String {
    let mut l: Vec<String> = vec![
        "BEGIN:VCALENDAR".into(),
        "PRODID:-//ANEXOMAIL//Calendar//EN".into(),
        "VERSION:2.0".into(),
        "CALSCALE:GREGORIAN".into(),
        format!("METHOD:{}", method.word()),
        "BEGIN:VEVENT".into(),
        format!("UID:{}@{}", clean_line(&ev.id, 64), DOMAIN),
        format!("DTSTAMP:{}", fmt_ics(ev.now)),
        format!("DTSTART:{}", fmt_ics(ev.starts)),
        format!("DTEND:{}", fmt_ics(ev.ends)),
        format!("SEQUENCE:{}", ev.sequence),
        format!(
            "STATUS:{}",
            if method == Method::Cancel {
                "CANCELLED"
            } else {
                "CONFIRMED"
            }
        ),
        format!("SUMMARY:{}", ics_escape(&clean_line(&ev.title, 200))),
    ];
    let mut desc = String::new();
    if let Some(a) = ev.agenda.as_deref().filter(|a| !a.trim().is_empty()) {
        desc.push_str(a.trim());
    }
    if !app_url.is_empty() {
        if !desc.is_empty() {
            desc.push_str("\n\n");
        }
        desc.push_str(&format!("Details and RSVP: {}", app_url));
    }
    if !desc.is_empty() {
        l.push(format!("DESCRIPTION:{}", ics_escape(&desc)));
    }
    if let Some(loc) = ev.location.as_deref().filter(|x| !x.trim().is_empty()) {
        l.push(format!("LOCATION:{}", ics_escape(&clean_line(loc, 300))));
    }
    l.push(format!(
        "ORGANIZER;CN={}:mailto:{}",
        param_quote(
            ev.organiser
                .name
                .as_deref()
                .unwrap_or(&ev.organiser.address)
        ),
        ev.organiser.address
    ));
    for g in &ev.guests {
        l.push(format!(
            "ATTENDEE;CUTYPE=INDIVIDUAL;ROLE={};PARTSTAT={};RSVP=TRUE;CN={}:mailto:{}",
            if g.optional {
                "OPT-PARTICIPANT"
            } else {
                "REQ-PARTICIPANT"
            },
            partstat(&g.response),
            param_quote(g.name.as_deref().unwrap_or(&g.address)),
            g.address
        ));
    }
    l.push("TRANSP:OPAQUE".into());
    if !app_url.is_empty() {
        l.push(format!("URL:{}", app_url));
    }
    l.push(format!("X-ANEXOMAIL-EVENT:{}", clean_line(&ev.id, 64)));
    l.push("END:VEVENT".into());
    l.push("END:VCALENDAR".into());
    let mut out = String::new();
    for line in l {
        out.push_str(&fold_line(&line));
        out.push_str("\r\n");
    }
    out
}

/* ------------------------------------------------------------ invitation */

pub struct InviteLinks {
    pub yes: String,
    pub maybe: String,
    pub no: String,
    pub view: String,
}

pub struct InviteMail {
    pub to: String,
    pub subject: String,
    pub message_id: String,
    pub raw: String,
}

pub fn subject_for(method: Method, ev: &EventSpec, when_label: &str) -> String {
    let t = clean_line(&ev.title, 120);
    let w = clean_line(when_label, 80);
    match (method, ev.sequence) {
        (Method::Cancel, _) => format!("Cancelled: {} @ {}", t, w),
        (Method::Request, 0) => format!("Invitation: {} @ {}", t, w),
        (Method::Request, _) => format!("Updated invitation: {} @ {}", t, w),
    }
}

fn text_body(
    method: Method,
    ev: &EventSpec,
    when_label: &str,
    links: &InviteLinks,
    guest: &Guest,
) -> String {
    let org = ev
        .organiser
        .name
        .as_deref()
        .unwrap_or(&ev.organiser.address);
    let mut s = String::new();
    match method {
        Method::Cancel => s.push_str(&format!("{} cancelled this meeting.\n\n", org)),
        Method::Request if ev.sequence > 0 => {
            s.push_str(&format!("{} changed this meeting.\n\n", org))
        }
        Method::Request => s.push_str(&format!("{} invited you to a meeting.\n\n", org)),
    }
    s.push_str(&format!(
        "{}\nWhen: {}\n",
        clean_line(&ev.title, 200),
        clean_line(when_label, 100)
    ));
    if let Some(l) = ev.location.as_deref().filter(|x| !x.trim().is_empty()) {
        s.push_str(&format!("Where: {}\n", clean_line(l, 300)));
    }
    s.push_str(&format!(
        "Organiser: {} <{}>\n",
        clean_line(org, 120),
        ev.organiser.address
    ));
    let others: Vec<String> = ev
        .guests
        .iter()
        .filter(|g| g.address != ev.organiser.address)
        .map(|g| g.address.clone())
        .collect();
    if !others.is_empty() {
        s.push_str(&format!("Guests: {}\n", others.join(", ")));
    }
    if let Some(a) = ev.agenda.as_deref().filter(|a| !a.trim().is_empty()) {
        s.push_str(&format!("\nAgenda:\n{}\n", a.trim()));
    }
    if method == Method::Request {
        s.push_str(&format!(
            "\nWill you come, {}?\n  Yes:   {}\n  Maybe: {}\n  No:    {}\n",
            clean_line(guest.name.as_deref().unwrap_or(&guest.address), 80),
            links.yes,
            links.maybe,
            links.no
        ));
    }
    s.push_str(&format!("\nOpen in ANEXOMAIL: {}\n", links.view));
    s
}

fn button(href: &str, label: &str, bg: &str, fg: &str) -> String {
    format!(
        "<a href=\"{}\" style=\"display:inline-block;margin:0 8px 8px 0;padding:11px 22px;border-radius:8px;background:{};color:{};font:600 14px/1 Arial,Helvetica,sans-serif;text-decoration:none\">{}</a>",
        html_escape(href),
        bg,
        fg,
        html_escape(label)
    )
}

fn html_body(
    method: Method,
    ev: &EventSpec,
    when_label: &str,
    links: &InviteLinks,
    guest: &Guest,
) -> String {
    let org = ev
        .organiser
        .name
        .as_deref()
        .unwrap_or(&ev.organiser.address);
    let lead = match method {
        Method::Cancel => format!(
            "{} cancelled this meeting.",
            html_escape(&clean_line(org, 120))
        ),
        Method::Request if ev.sequence > 0 => format!(
            "{} changed this meeting.",
            html_escape(&clean_line(org, 120))
        ),
        Method::Request => format!(
            "{} invited you to a meeting.",
            html_escape(&clean_line(org, 120))
        ),
    };
    let title_style = if method == Method::Cancel {
        "text-decoration:line-through;color:#6b7280"
    } else {
        "color:#0f172a"
    };
    let mut rows = format!(
        "<tr><td style=\"padding:4px 14px 4px 0;color:#64748b\">When</td><td style=\"padding:4px 0;color:#0f172a\">{}</td></tr>",
        html_escape(&clean_line(when_label, 100))
    );
    if let Some(l) = ev.location.as_deref().filter(|x| !x.trim().is_empty()) {
        rows.push_str(&format!(
            "<tr><td style=\"padding:4px 14px 4px 0;color:#64748b\">Where</td><td style=\"padding:4px 0;color:#0f172a\">{}</td></tr>",
            html_escape(&clean_line(l, 300))
        ));
    }
    rows.push_str(&format!(
        "<tr><td style=\"padding:4px 14px 4px 0;color:#64748b\">Organiser</td><td style=\"padding:4px 0;color:#0f172a\">{} &lt;{}&gt;</td></tr>",
        html_escape(&clean_line(org, 120)),
        html_escape(&ev.organiser.address)
    ));
    let others: Vec<String> = ev
        .guests
        .iter()
        .filter(|g| g.address != ev.organiser.address)
        .map(|g| html_escape(&g.address))
        .collect();
    if !others.is_empty() {
        rows.push_str(&format!(
            "<tr><td style=\"padding:4px 14px 4px 0;color:#64748b;vertical-align:top\">Guests</td><td style=\"padding:4px 0;color:#0f172a\">{}</td></tr>",
            others.join(", ")
        ));
    }
    let agenda = ev
        .agenda
        .as_deref()
        .filter(|a| !a.trim().is_empty())
        .map(|a| {
            format!(
                "<p style=\"margin:18px 0 4px;color:#64748b;font:600 12px/1 Arial,sans-serif;letter-spacing:.06em;text-transform:uppercase\">Agenda</p><p style=\"margin:0;color:#0f172a;white-space:pre-wrap\">{}</p>",
                html_escape(a.trim())
            )
        })
        .unwrap_or_default();
    let buttons =
        if method == Method::Request {
            format!(
            "<p style=\"margin:22px 0 8px;color:#0f172a\">Will you come, {}?</p><div>{}{}{}</div>",
            html_escape(&clean_line(guest.name.as_deref().unwrap_or(&guest.address), 80)),
            button(&links.yes, "Yes", "#0f172a", "#ffffff"),
            button(&links.maybe, "Maybe", "#e2e8f0", "#0f172a"),
            button(&links.no, "No", "#e2e8f0", "#0f172a"),
        )
        } else {
            String::new()
        };
    format!(
        "<!doctype html><html><body style=\"margin:0;background:#f1f5f9;padding:24px 12px;font:15px/1.5 Arial,Helvetica,sans-serif\"><div style=\"max-width:560px;margin:0 auto;background:#ffffff;border-radius:12px;padding:26px 28px\"><p style=\"margin:0 0 6px;color:#64748b;font-size:13px\">{}</p><h1 style=\"margin:0 0 14px;font:700 22px/1.25 Arial,Helvetica,sans-serif;{}\">{}</h1><table role=\"presentation\" style=\"border-collapse:collapse;font-size:14px\">{}</table>{}{}<p style=\"margin:22px 0 0\"><a href=\"{}\" style=\"color:#2563eb;font-size:13px\">Open in ANEXOMAIL</a></p></div><p style=\"max-width:560px;margin:12px auto 0;color:#94a3b8;font-size:12px\">Sent from {}'s ANEXOMAIL calendar. Replying to this email writes to {}.</p></body></html>",
        lead,
        title_style,
        html_escape(&clean_line(&ev.title, 200)),
        rows,
        agenda,
        buttons,
        html_escape(&links.view),
        html_escape(&ev.organiser.address),
        html_escape(&ev.organiser.address)
    )
}

/// One complete RFC 5322 message for ONE guest (own RSVP links). Pure: caller passes message id + clock.
pub fn build_invite_mail(
    method: Method,
    ev: &EventSpec,
    to: &Guest,
    links: &InviteLinks,
    app_url: &str,
    when_label: &str,
    message_id: &str,
) -> InviteMail {
    let subject = subject_for(method, ev, when_label);
    let ics = build_ics(method, ev, app_url);
    let seed: String = message_id
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .take(40)
        .collect();
    let mix = format!("axm_{}", seed);
    let alt = format!("axa_{}", seed);
    let mut m = String::new();
    m.push_str(&format!(
        "From: {}\r\n",
        mailbox(ev.organiser.name.as_deref(), &ev.organiser.address)
    ));
    m.push_str(&format!(
        "To: {}\r\n",
        mailbox(to.name.as_deref(), &to.address)
    ));
    m.push_str(&format!("Reply-To: <{}>\r\n", ev.organiser.address));
    m.push_str(&format!("Subject: {}\r\n", encode_header(&subject)));
    m.push_str(&format!(
        "Message-ID: <{}>\r\n",
        clean_line(message_id, 120).replace(' ', "")
    ));
    m.push_str(&format!("Date: {}\r\n", fmt_rfc2822(ev.now)));
    m.push_str("MIME-Version: 1.0\r\n");
    m.push_str(&format!(
        "X-ANEXOMAIL-Event: {}\r\n",
        clean_line(&ev.id, 64)
    ));
    m.push_str(&format!(
        "Content-Type: multipart/mixed; boundary=\"{}\"\r\n\r\n",
        mix
    ));
    m.push_str(&format!(
        "--{}\r\nContent-Type: multipart/alternative; boundary=\"{}\"\r\n\r\n",
        mix, alt
    ));
    m.push_str(&format!(
        "--{}\r\nContent-Type: text/plain; charset=\"UTF-8\"\r\nContent-Transfer-Encoding: base64\r\n\r\n{}",
        alt,
        base64_mime(text_body(method, ev, when_label, links, to).as_bytes())
    ));
    m.push_str(&format!(
        "--{}\r\nContent-Type: text/html; charset=\"UTF-8\"\r\nContent-Transfer-Encoding: base64\r\n\r\n{}",
        alt,
        base64_mime(html_body(method, ev, when_label, links, to).as_bytes())
    ));
    m.push_str(&format!(
        "--{}\r\nContent-Type: text/calendar; charset=\"UTF-8\"; method={}\r\nContent-Transfer-Encoding: base64\r\n\r\n{}",
        alt,
        method.word(),
        base64_mime(ics.as_bytes())
    ));
    m.push_str(&format!("--{}--\r\n", alt));
    m.push_str(&format!(
        "--{}\r\nContent-Type: application/ics; name=\"invite.ics\"\r\nContent-Disposition: attachment; filename=\"invite.ics\"\r\nContent-Transfer-Encoding: base64\r\n\r\n{}",
        mix,
        base64_mime(ics.as_bytes())
    ));
    m.push_str(&format!("--{}--\r\n", mix));
    InviteMail {
        to: to.address.clone(),
        subject,
        message_id: message_id.to_string(),
        raw: m,
    }
}

/* ------------------------------------------------------------------ SMTP */

/// Final reply code of a (possibly multi-line) SMTP reply block, e.g. "250-a\r\n250 ok\r\n" -> 250.
/// None while the reply is still incomplete (last line has a '-' after the code).
pub fn smtp_reply_code(block: &str) -> Option<u16> {
    let last = block
        .trim_end_matches(['\r', '\n'])
        .rsplit('\n')
        .next()?
        .trim_end_matches('\r');
    if last.len() < 3 || !last.as_bytes()[..3].iter().all(|b| b.is_ascii_digit()) {
        return None;
    }
    if last.len() > 3 && last.as_bytes()[3] == b'-' {
        return None;
    }
    last[..3].parse().ok()
}

/// RFC 5321 §4.5.2 — a line that starts with '.' gets one more '.', and every line ends with CRLF.
pub fn dot_stuff(data: &str) -> String {
    let mut out = String::with_capacity(data.len() + 16);
    for line in data.replace("\r\n", "\n").split('\n') {
        if line.starts_with('.') {
            out.push('.');
        }
        out.push_str(line);
        out.push_str("\r\n");
    }
    // `split` yields a trailing empty piece when data ended with a newline: drop that extra blank line
    if data.ends_with('\n') && out.ends_with("\r\n\r\n") {
        out.truncate(out.len() - 2);
    }
    out
}

/* --------------------------------------------------------- busy / slots */

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Interval {
    pub start: i64,
    pub end: i64,
}

pub fn merge_intervals(mut v: Vec<Interval>) -> Vec<Interval> {
    v.retain(|i| i.end > i.start);
    v.sort_by_key(|i| (i.start, i.end));
    let mut out: Vec<Interval> = Vec::with_capacity(v.len());
    for i in v {
        match out.last_mut() {
            Some(l) if i.start <= l.end => l.end = l.end.max(i.end),
            _ => out.push(i),
        }
    }
    out
}

/// Start times (aligned to `step` seconds, e.g. 900) where EVERY person is free for `duration` seconds, with a
/// `buffer` of free time before and after other meetings. `windows` are the candidate hours, already in UTC
/// (the browser knows each person's time zone and working hours; the engine only does exact interval maths).
pub fn common_free_slots(
    busy: &[Vec<Interval>],
    windows: &[Interval],
    duration: i64,
    step: i64,
    buffer: i64,
    limit: usize,
) -> Vec<Interval> {
    if duration <= 0 || step <= 0 || limit == 0 {
        return vec![];
    }
    let mut all: Vec<Interval> = Vec::new();
    for person in busy {
        for i in person {
            all.push(Interval {
                start: i.start - buffer,
                end: i.end + buffer,
            });
        }
    }
    let all = merge_intervals(all);
    let mut out = Vec::new();
    let mut idx = 0usize;
    for w in merge_intervals(windows.to_vec()) {
        let mut t = (w.start + step - 1).div_euclid(step) * step;
        while t + duration <= w.end {
            while idx < all.len() && all[idx].end <= t {
                idx += 1;
            }
            // `all` is sorted and disjoint: the first interval ending after t decides
            let clash = idx < all.len() && all[idx].start < t + duration;
            if clash {
                // jump to the end of the blocking interval (aligned) instead of crawling step by step
                t = (all[idx].end + step - 1).div_euclid(step) * step;
                continue;
            }
            out.push(Interval {
                start: t,
                end: t + duration,
            });
            if out.len() >= limit {
                return out;
            }
            t += step;
        }
        // windows are sorted; `idx` only moves forward, which is valid because t only moves forward
    }
    out
}

/// How many invitation emails this organiser may still send in a rolling 24 hours.
pub fn invite_quota_left(sent_last_24h: i64, cap: i64) -> i64 {
    (cap - sent_last_24h.max(0)).max(0)
}

/* ------------------------------------------------------------------ tests */

#[cfg(test)]
mod tests {
    use super::*;

    fn ev() -> EventSpec {
        EventSpec {
            id: "11111111-2222-3333-4444-555555555555".into(),
            sequence: 0,
            title: "Q4 plan, v2; final".into(),
            agenda: Some("Decide the budget.\nBring numbers.".into()),
            starts: parse_ts("2026-10-20T14:00:00+00:00").unwrap(),
            ends: parse_ts("2026-10-20T14:30:00+00:00").unwrap(),
            location: Some("https://meet.example.com/x".into()),
            organiser: Person {
                address: "ali@anexomail.com".into(),
                name: Some("Ali Khan".into()),
            },
            guests: vec![
                Guest {
                    address: "ali@anexomail.com".into(),
                    name: Some("Ali Khan".into()),
                    optional: false,
                    response: "accepted".into(),
                },
                Guest {
                    address: "sara@gmail.com".into(),
                    name: None,
                    optional: false,
                    response: "needs_action".into(),
                },
            ],
            now: parse_ts("2026-10-18T04:00:00Z").unwrap(),
        }
    }

    fn links() -> InviteLinks {
        InviteLinks {
            yes: "https://anexomail.com/rsvp?t=T&r=yes".into(),
            maybe: "https://anexomail.com/rsvp?t=T&r=maybe".into(),
            no: "https://anexomail.com/rsvp?t=T&r=no".into(),
            view: "https://anexomail.com/rsvp?t=T".into(),
        }
    }

    #[test]
    fn civil_round_trip() {
        for z in [-800000i64, -1, 0, 1, 365, 10957, 20381, 2932896] {
            let (y, m, d) = civil_from_days(z);
            assert_eq!(days_from_civil(y, m, d), z);
        }
        assert_eq!(days_from_civil(1970, 1, 1), 0);
        assert_eq!(days_from_civil(2000, 3, 1), 11017);
        assert_eq!(civil_from_days(20744), (2026, 10, 18));
        assert_eq!(days_from_civil(2026, 10, 18), 20744);
    }

    #[test]
    fn parse_timestamps() {
        assert_eq!(parse_ts("1970-01-01T00:00:00Z"), Some(0));
        assert_eq!(parse_ts("1970-01-01T01:00:00+01:00"), Some(0));
        assert_eq!(parse_ts("1970-01-01 05:30:00+05:30"), Some(0));
        assert_eq!(parse_ts("1970-01-01T00:00:00.123456+00:00"), Some(0));
        assert_eq!(parse_ts("1969-12-31T19:00:00-05:00"), Some(0));
        assert_eq!(
            parse_ts("2026-10-20T14:00:00+00"),
            parse_ts("2026-10-20T14:00:00Z")
        );
        assert_eq!(parse_ts("2026-13-20T14:00:00Z"), None);
        assert_eq!(parse_ts("garbage"), None);
        assert_eq!(parse_ts("2026-10-20T14:00:00+99:00"), None);
    }

    #[test]
    fn formatting() {
        let t = parse_ts("2026-10-20T14:05:09Z").unwrap();
        assert_eq!(fmt_ics(t), "20261020T140509Z");
        assert_eq!(fmt_rfc3339(t), "2026-10-20T14:05:09Z");
        assert_eq!(weekday_name(t), "Tue");
        assert_eq!(fmt_human_utc(t), "Tue 20 Oct 2026, 14:05 UTC");
        assert_eq!(fmt_rfc2822(t), "Tue, 20 Oct 2026 14:05:09 +0000");
        assert_eq!(weekday_name(0), "Thu");
        assert_eq!(fmt_ics(-1), "19691231T235959Z");
    }

    #[test]
    fn escaping_and_folding() {
        assert_eq!(ics_escape("a,b;c\\d\r\ne\nf"), "a\\,b\\;c\\\\d\\ne\\nf");
        assert_eq!(
            html_escape("<a href=\"x\">&'</a>"),
            "&lt;a href=&quot;x&quot;&gt;&amp;&#39;&lt;/a&gt;"
        );
        let long = format!("SUMMARY:{}", "é".repeat(60));
        let folded = fold_line(&long);
        for phys in folded.split("\r\n") {
            assert!(phys.len() <= 75, "physical line too long: {}", phys.len());
        }
        // unfolding gives the original back (RFC 5545 §3.1: remove CRLF + one space)
        assert_eq!(folded.replace("\r\n ", ""), long);
        assert_eq!(fold_line("short"), "short");
    }

    #[test]
    fn header_injection_is_impossible() {
        assert_eq!(
            clean_line("Hi\r\nBcc: evil@x.com", 100),
            "Hi Bcc: evil@x.com"
        );
        let mut e = ev();
        e.title = "Plan\r\nBcc: evil@x.com".into();
        let m = build_invite_mail(
            Method::Request,
            &e,
            &e.guests[1],
            &links(),
            "https://anexomail.com/x",
            "Tue",
            "id1@anexomail.com",
        );
        assert!(!m.raw.contains("\r\nBcc:"));
        assert!(!m.subject.contains('\n'));
        let mb = mailbox(Some("Bad\r\nName"), "a@b.co");
        assert!(!mb.contains('\n') && !mb.contains('\r'));
        assert!(!valid_email("a@b.co\r\nBcc: x@y.zz"));
    }

    #[test]
    fn base64_known_vectors() {
        assert_eq!(base64(b""), "");
        assert_eq!(base64(b"f"), "Zg==");
        assert_eq!(base64(b"fo"), "Zm8=");
        assert_eq!(base64(b"foo"), "Zm9v");
        assert_eq!(base64(b"foob"), "Zm9vYg==");
        assert_eq!(base64(b"fooba"), "Zm9vYmE=");
        assert_eq!(base64(b"foobar"), "Zm9vYmFy");
        let mime = base64_mime(&[b'a'; 200]);
        assert!(mime.split("\r\n").all(|l| l.len() <= 76));
    }

    #[test]
    fn header_encoding() {
        assert_eq!(encode_header("Plain ASCII"), "Plain ASCII");
        let e = encode_header("Mulaqat — nayi میٹنگ");
        assert!(e.starts_with("=?UTF-8?B?"));
        for w in e.split("\r\n ") {
            assert!(w.len() <= 75);
        }
        assert_eq!(mailbox(None, "a@b.co"), "<a@b.co>");
        assert_eq!(
            mailbox(Some("Ali \"Boss\" Khan"), "a@b.co"),
            "\"Ali Boss Khan\" <a@b.co>"
        );
    }

    #[test]
    fn email_validation() {
        for ok in ["a@b.co", "ali.khan+tag@anexomail.com", "x_y@sub.domain.org"] {
            assert!(valid_email(ok), "{}", ok);
        }
        for bad in [
            "",
            "a",
            "a@b",
            "a@b.c",
            "@b.com",
            "a@@b.com",
            "a b@c.com",
            "a@b..com",
            ".a@b.com",
            "a@-b.com",
            "a@b.com>",
            "a<b>@c.com",
            "a@b.c0m",
        ] {
            assert!(!valid_email(bad), "{}", bad);
        }
    }

    #[test]
    fn attendee_list() {
        let raw: Vec<String> = [
            "Sara@Gmail.com",
            "sara@gmail.com",
            "bad",
            "<omar@x.org>",
            "ali@anexomail.com",
            "",
            "z@z.zz",
            "y@y.yy",
        ]
        .iter()
        .map(|s| s.to_string())
        .collect();
        let r = normalise_attendees(&raw, "Ali@anexomail.com", 3);
        assert_eq!(
            r.kept,
            vec![
                "ali@anexomail.com",
                "sara@gmail.com",
                "omar@x.org",
                "z@z.zz"
            ]
        );
        assert_eq!(r.invalid, 1);
        assert_eq!(r.duplicate, 2); // second sara + the organiser listed again
        assert_eq!(r.over_cap, 1);
    }

    #[test]
    fn rsvp_words() {
        assert_eq!(rsvp_value("Yes"), Some("accepted"));
        assert_eq!(rsvp_value("tentative"), Some("tentative"));
        assert_eq!(rsvp_value("DECLINE"), Some("declined"));
        assert_eq!(rsvp_value("later"), None);
        assert_eq!(partstat("needs_action"), "NEEDS-ACTION");
        assert_eq!(partstat("accepted"), "ACCEPTED");
        assert!(token_shape_ok("3f2504e0-4f89-41d3-9a0c-0305e82c3301"));
        assert!(!token_shape_ok("3f2504e0-4f89-41d3-9a0c-0305e82c330"));
        assert!(!token_shape_ok("3f2504e0-4f89-41d3-9a0c-0305e82c33zz"));
        assert!(!token_shape_ok(
            "')--; drop table x; --xxxxxxxxxxxxxxxxxxxxxx"
        ));
    }

    #[test]
    fn ics_request_is_valid_shape() {
        let ics = build_ics(Method::Request, &ev(), "https://anexomail.com/rsvp?t=T");
        assert!(ics.starts_with("BEGIN:VCALENDAR\r\n"));
        assert!(ics.ends_with("END:VCALENDAR\r\n"));
        for line in ics.split("\r\n") {
            assert!(line.len() <= 75);
        }
        let flat = ics.replace("\r\n ", "");
        for must in [
            "METHOD:REQUEST",
            "UID:11111111-2222-3333-4444-555555555555@anexomail.com",
            "DTSTART:20261020T140000Z",
            "DTEND:20261020T143000Z",
            "DTSTAMP:20261018T040000Z",
            "SEQUENCE:0",
            "STATUS:CONFIRMED",
            "SUMMARY:Q4 plan\\, v2\\; final",
            "ORGANIZER;CN=\"Ali Khan\":mailto:ali@anexomail.com",
            "ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;RSVP=TRUE;CN=\"Ali Khan\":mailto:ali@anexomail.com",
            "ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=\"sara@gmail.com\":mailto:sara@gmail.com",
            "LOCATION:https://meet.example.com/x",
            "X-ANEXOMAIL-EVENT:11111111-2222-3333-4444-555555555555",
        ] {
            assert!(flat.contains(must), "missing: {}\n{}", must, flat);
        }
        assert!(flat.contains("DESCRIPTION:Decide the budget.\\nBring numbers.\\n\\nDetails and RSVP: https://anexomail.com/rsvp?t=T"));
        assert_eq!(ics.matches("BEGIN:VEVENT").count(), 1);
    }

    #[test]
    fn ics_cancel_and_update() {
        let mut e = ev();
        e.sequence = 2;
        let c = build_ics(Method::Cancel, &e, "");
        assert!(
            c.contains("METHOD:CANCEL\r\n")
                && c.contains("STATUS:CANCELLED\r\n")
                && c.contains("SEQUENCE:2\r\n")
        );
        assert!(!c.contains("URL:"));
        assert_eq!(
            subject_for(Method::Request, &ev(), "Tue 14:00"),
            "Invitation: Q4 plan, v2; final @ Tue 14:00"
        );
        assert_eq!(
            subject_for(Method::Request, &e, "Tue 14:00"),
            "Updated invitation: Q4 plan, v2; final @ Tue 14:00"
        );
        assert_eq!(
            subject_for(Method::Cancel, &e, "Tue 14:00"),
            "Cancelled: Q4 plan, v2; final @ Tue 14:00"
        );
    }

    fn decode_b64(s: &str) -> Vec<u8> {
        let mut out = Vec::new();
        let mut buf = 0u32;
        let mut bits = 0;
        for c in s
            .bytes()
            .filter(|c| *c != b'\r' && *c != b'\n' && *c != b'=')
        {
            let v = B64.iter().position(|x| *x == c).expect("b64 char") as u32;
            buf = (buf << 6) | v;
            bits += 6;
            if bits >= 8 {
                bits -= 8;
                out.push((buf >> bits) as u8 & 0xff);
            }
        }
        out
    }

    fn part_after<'a>(raw: &'a str, content_type: &str) -> &'a str {
        let i = raw.find(content_type).expect("part present");
        let rest = &raw[i..];
        let body = rest.find("\r\n\r\n").expect("blank line") + 4;
        let end = rest[body..]
            .find("\r\n--")
            .map(|e| body + e)
            .unwrap_or(rest.len());
        &rest[body..end]
    }

    #[test]
    fn invite_mail_structure_and_round_trip() {
        let e = ev();
        let m = build_invite_mail(
            Method::Request,
            &e,
            &e.guests[1],
            &links(),
            "https://anexomail.com/rsvp?t=T",
            "Tue 20 Oct, 14:00",
            "abc123.9@anexomail.com",
        );
        assert_eq!(m.to, "sara@gmail.com");
        assert_eq!(
            m.subject,
            "Invitation: Q4 plan, v2; final @ Tue 20 Oct, 14:00"
        );
        let raw = &m.raw;
        assert!(
            raw.starts_with("From: \"Ali Khan\" <ali@anexomail.com>\r\nTo: <sara@gmail.com>\r\n")
        );
        assert!(raw.contains("Message-ID: <abc123.9@anexomail.com>\r\n"));
        assert!(raw.contains("Date: Sun, 18 Oct 2026 04:00:00 +0000\r\n"));
        assert!(
            raw.contains("Content-Type: multipart/mixed; boundary=\"axm_abc1239anexomailcom\"\r\n")
        );
        assert!(raw.contains("multipart/alternative; boundary=\"axa_abc1239anexomailcom\""));
        assert!(raw.contains("text/calendar; charset=\"UTF-8\"; method=REQUEST"));
        assert!(raw.contains("Content-Disposition: attachment; filename=\"invite.ics\""));
        // every physical line within RFC 5322 limits
        assert!(raw.split("\r\n").all(|l| l.len() <= 998));
        assert!(raw.ends_with("--axm_abc1239anexomailcom--\r\n"));
        // what a mail client decodes
        let text =
            String::from_utf8(decode_b64(part_after(raw, "Content-Type: text/plain"))).unwrap();
        assert!(text.contains("Ali Khan invited you to a meeting."));
        assert!(text.contains("Yes:   https://anexomail.com/rsvp?t=T&r=yes"));
        assert!(text.contains("Agenda:\nDecide the budget."));
        let html =
            String::from_utf8(decode_b64(part_after(raw, "Content-Type: text/html"))).unwrap();
        assert!(html.contains("Q4 plan, v2; final"));
        assert!(html.contains("href=\"https://anexomail.com/rsvp?t=T&amp;r=maybe\""));
        let ics =
            String::from_utf8(decode_b64(part_after(raw, "Content-Type: text/calendar"))).unwrap();
        assert!(ics.starts_with("BEGIN:VCALENDAR"));
        let att = String::from_utf8(decode_b64(part_after(raw, "Content-Type: application/ics")))
            .unwrap();
        assert_eq!(att, ics);
    }

    #[test]
    fn cancel_mail_has_no_rsvp_buttons() {
        let mut e = ev();
        e.sequence = 1;
        let m = build_invite_mail(
            Method::Cancel,
            &e,
            &e.guests[1],
            &links(),
            "",
            "Tue 20 Oct, 14:00",
            "c1@anexomail.com",
        );
        let text =
            String::from_utf8(decode_b64(part_after(&m.raw, "Content-Type: text/plain"))).unwrap();
        assert!(text.contains("cancelled this meeting"));
        assert!(!text.contains("Will you come"));
        let html =
            String::from_utf8(decode_b64(part_after(&m.raw, "Content-Type: text/html"))).unwrap();
        assert!(!html.contains("Will you come"));
        assert!(m.raw.contains("method=CANCEL"));
    }

    #[test]
    fn html_is_escaped() {
        let mut e = ev();
        e.title = "<script>alert(1)</script>".into();
        e.agenda = Some("<img src=x onerror=alert(1)>".into());
        e.location = Some("\"><b>".into());
        let m = build_invite_mail(
            Method::Request,
            &e,
            &e.guests[1],
            &links(),
            "",
            "x",
            "i@anexomail.com",
        );
        let html =
            String::from_utf8(decode_b64(part_after(&m.raw, "Content-Type: text/html"))).unwrap();
        assert!(
            !html.contains("<script>") && !html.contains("<img src=x") && !html.contains("\"><b>")
        );
        assert!(html.contains("&lt;script&gt;"));
    }

    #[test]
    fn smtp_helpers() {
        assert_eq!(smtp_reply_code("220 mail ESMTP\r\n"), Some(220));
        assert_eq!(smtp_reply_code("250-a\r\n250-b\r\n250 ok\r\n"), Some(250));
        assert_eq!(smtp_reply_code("250-a\r\n250-b\r\n"), None);
        assert_eq!(smtp_reply_code("550 5.1.1 no such user"), Some(550));
        assert_eq!(smtp_reply_code("xyz"), None);
        assert_eq!(smtp_reply_code(""), None);
        assert_eq!(dot_stuff("a\n.b\n..c\n"), "a\r\n..b\r\n...c\r\n");
        assert_eq!(dot_stuff("a\r\n.\r\nb"), "a\r\n..\r\nb\r\n");
    }

    fn iv(a: i64, b: i64) -> Interval {
        Interval { start: a, end: b }
    }

    #[test]
    fn merging() {
        assert_eq!(
            merge_intervals(vec![iv(5, 9), iv(1, 3), iv(2, 4), iv(9, 10), iv(7, 7)]),
            vec![iv(1, 4), iv(5, 10)]
        );
        assert_eq!(merge_intervals(vec![]), vec![]);
    }

    #[test]
    fn free_slots_basic() {
        // two people; window 09:00-12:00 (in minutes*60 for readability) ; step 30 min; 30 min meeting; no buffer
        let m = 60;
        let a = vec![iv(9 * 60 * m, 10 * 60 * m)]; // A busy 09-10
        let b = vec![iv(10 * 60 * m + 30 * m, 11 * 60 * m)]; // B busy 10:30-11
        let w = vec![iv(9 * 60 * m, 12 * 60 * m)];
        let s = common_free_slots(&[a, b], &w, 30 * m, 30 * m, 0, 10);
        let starts: Vec<i64> = s.iter().map(|x| x.start / m).collect();
        assert_eq!(starts, vec![600, 660, 690]); // 10:00, 11:00 and 11:30 (10:30 clashes with B)
        assert!(s.iter().all(|x| x.end - x.start == 30 * m));
    }

    #[test]
    fn free_slots_buffer_limit_and_alignment() {
        let m = 60;
        let a = vec![iv(10 * 60 * m, 11 * 60 * m)];
        let w = vec![iv(9 * 60 * m + 7 * m, 13 * 60 * m)]; // starts at 09:07 -> first aligned start 09:15
        let s = common_free_slots(&[a.clone()], &w, 30 * m, 15 * m, 10 * m, 3);
        assert_eq!(s.len(), 3);
        assert_eq!(s[0].start, (9 * 60 + 15) * m);
        // 10-minute buffer: 09:15-09:45 ok, 09:30-10:00 would touch the buffer (09:50) -> not allowed
        assert!(s
            .iter()
            .all(|x| x.end <= (10 * 60 - 10) * m || x.start >= (11 * 60 + 10) * m));
        // limit respected, empty inputs safe
        assert!(common_free_slots(&[a], &w, 30 * m, 15 * m, 0, 0).is_empty());
        assert!(common_free_slots(&[], &[], 30 * m, 15 * m, 0, 5).is_empty());
        // nobody busy: slots are dense
        let dense = common_free_slots(&[], &[iv(0, 3600)], 1800, 900, 0, 10);
        assert_eq!(
            dense.iter().map(|x| x.start).collect::<Vec<_>>(),
            vec![0, 900, 1800]
        );
    }

    #[test]
    fn free_slots_multiple_windows_and_overlap() {
        let m = 60;
        // person 1 has two overlapping meetings (merge to 0-160), person 2 is busy 400-410
        let busy = vec![
            vec![iv(0, 100 * m), iv(50 * m, 160 * m)],
            vec![iv(400 * m, 410 * m)],
        ];
        // window 1 (0-200) has no 30-minute slot left after 160 on a 30-minute grid (180+30 > 200);
        // window 2 (390-450): 390 clashes with 400-410, the first free grid start is 420
        let w = vec![iv(0, 200 * m), iv(390 * m, 450 * m)];
        let s = common_free_slots(&busy, &w, 30 * m, 30 * m, 0, 50);
        assert_eq!(s.iter().map(|x| x.start / m).collect::<Vec<_>>(), vec![420]);
        // same busy, wider first window: 180 becomes available
        let w2 = vec![iv(0, 240 * m)];
        let s2 = common_free_slots(&busy, &w2, 30 * m, 30 * m, 0, 50);
        assert_eq!(
            s2.iter().map(|x| x.start / m).collect::<Vec<_>>(),
            vec![180, 210]
        );
    }

    #[test]
    fn quota() {
        assert_eq!(invite_quota_left(10, 200), 190);
        assert_eq!(invite_quota_left(250, 200), 0);
        assert_eq!(invite_quota_left(-5, 200), 200);
    }
}
