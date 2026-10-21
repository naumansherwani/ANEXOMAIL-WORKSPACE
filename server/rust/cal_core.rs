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
/// Floating local time for ICS (`20261027T090000`) from wall-clock seconds.
pub fn fmt_ics_local(local: i64) -> String {
    let d = local.div_euclid(86_400);
    let t = local.rem_euclid(86_400);
    let (y, m, dd) = civil_from_days(d);
    format!("{:04}{:02}{:02}T{:02}{:02}{:02}", y, m, dd, t / 3600, (t % 3600) / 60, t % 60)
}

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
    /// recurrence (B7b): RRULE text on the series master; exdates = UTC starts that were removed / replaced
    pub rrule: Option<String>,
    pub exdates: Vec<i64>,
    /// set on an exception ("only this meeting"): ORIGINAL start of the instance it replaces; `id` is then the master's id
    pub recurrence_id: Option<i64>,
    /// IANA zone name + loaded zone — only used so repeating meetings keep their wall-clock time across DST in guests' calendars
    pub tz: Option<(String, recur::Tz)>,
}

pub const DOMAIN: &str = "anexomail.com";

pub fn build_ics(method: Method, ev: &EventSpec, app_url: &str) -> String {
    let mut l: Vec<String> = vec![
        "BEGIN:VCALENDAR".into(),
        "PRODID:-//ANEXOMAIL//Calendar//EN".into(),
        "VERSION:2.0".into(),
        "CALSCALE:GREGORIAN".into(),
        format!("METHOD:{}", method.word()),
    ];
    // repeating meetings travel in the organiser's real zone (with a VTIMEZONE) so DST never shifts them in a guest's calendar
    let zone: Option<(&str, String)> = match (&ev.tz, ev.rrule.is_some() || ev.recurrence_id.is_some()) {
        (Some((name, z)), true) if recur::ics_zone_name_ok(name) => z.vtimezone(name, ev.starts).map(|v| (name.as_str(), v)),
        _ => None,
    };
    if let Some((_, v)) = &zone {
        for line in v.lines() {
            l.push(line.to_string());
        }
    }
    let when = |t: i64| -> String {
        match (&zone, &ev.tz) {
            (Some((n, _)), Some((_, z))) => format!(";TZID={}:{}", n, fmt_ics_local(z.to_local(t))),
            _ => format!(":{}", fmt_ics(t)),
        }
    };
    l.extend(vec![
        "BEGIN:VEVENT".into(),
        format!("UID:{}@{}", clean_line(&ev.id, 64), DOMAIN),
        format!("DTSTAMP:{}", fmt_ics(ev.now)),
        format!("DTSTART{}", when(ev.starts)),
        format!("DTEND{}", when(ev.ends)),
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
    ]);
    if let Some(r) = ev.rrule.as_deref().filter(|r| recur::parse(r).is_ok()) {
        l.push(format!("RRULE:{}", r.trim().trim_start_matches("RRULE:")));
        if !ev.exdates.is_empty() {
            let v: Vec<String> = ev.exdates.iter().take(400).map(|t| match (&zone, &ev.tz) {
                (Some(_), Some((_, z))) => fmt_ics_local(z.to_local(*t)),
                _ => fmt_ics(*t),
            }).collect();
            match (&zone, &ev.tz) {
                (Some((n, _)), _) => l.push(format!("EXDATE;TZID={}:{}", n, v.join(","))),
                _ => l.push(format!("EXDATE:{}", v.join(","))),
            }
        }
    }
    if let Some(rid) = ev.recurrence_id {
        l.push(format!("RECURRENCE-ID{}", when(rid)));
    }
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

/* ---------------------------------------------------- calendar reads (20 Oct 2026) */

/// For each event (start,end): does it overlap ANY other event in the list? Touching edges are not a clash.
pub fn mark_conflicts(ev: &[Interval]) -> Vec<bool> {
    let mut out = vec![false; ev.len()];
    for i in 0..ev.len() {
        for j in (i + 1)..ev.len() {
            if ev[i].start < ev[j].end && ev[j].start < ev[i].end {
                out[i] = true;
                out[j] = true;
            }
        }
    }
    out
}

/// Meeting minutes inside [from,to): only the part of each meeting that falls in the window counts.
pub fn minutes_in(ev: &[Interval], from: i64, to: i64) -> i64 {
    merge_intervals(ev.to_vec())
        .iter()
        .map(|i| (i.end.min(to) - i.start.max(from)).max(0))
        .sum::<i64>()
        / 60
}

/// Overloaded = more than half of the working time (8h per weekday-ish: 5/7 of the days) is meetings.
pub fn overloaded(minutes: i64, from: i64, to: i64) -> bool {
    let days = ((to - from).max(0) as f64) / 86_400.0;
    let work_minutes = days * 5.0 / 7.0 * 8.0 * 60.0;
    work_minutes >= 60.0 && (minutes as f64) > work_minutes * 0.5
}

#[cfg(test)]
mod read_tests {
    use super::*;
    #[test]
    fn reads() {
        let a = Interval { start: 0, end: 3600 };
        let b = Interval { start: 1800, end: 5400 };
        let c = Interval { start: 5400, end: 7200 };
        assert_eq!(mark_conflicts(&[a, b, c]), vec![true, true, false]);
        assert_eq!(mark_conflicts(&[a, c]), vec![false, false]);
        assert_eq!(minutes_in(&[a, b, c], 0, 7200), 120);
        assert_eq!(minutes_in(&[a], 1800, 99999), 30);
        assert!(!overloaded(600, 0, 7 * 86_400));
        assert!(overloaded(1300, 0, 7 * 86_400));
        assert!(!overloaded(500, 0, 3600));
    }
}

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
            rrule: None, exdates: vec![], recurrence_id: None, tz: None,
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
    fn ics_recurring_in_zone() {
        let ny = match std::fs::read("/usr/share/zoneinfo/America/New_York").ok().and_then(|b| recur::parse_tzif(&b)) { Some(z) => z, None => return };
        let mut e = ev();
        e.starts = parse_ts("2026-10-27T13:00:00Z").unwrap();
        e.ends = e.starts + 3600;
        e.rrule = Some("FREQ=WEEKLY;BYDAY=TU".into());
        e.exdates = vec![parse_ts("2026-11-03T14:00:00Z").unwrap()];
        e.tz = Some(("America/New_York".into(), ny));
        let ics = build_ics(Method::Request, &e, "");
        assert!(ics.contains("BEGIN:VTIMEZONE\r\nTZID:America/New_York"), "{}", ics);
        assert!(ics.contains("DTSTART;TZID=America/New_York:20261027T090000"), "{}", ics);
        assert!(ics.contains("RRULE:FREQ=WEEKLY;BYDAY=TU"), "{}", ics);
        assert!(ics.contains("EXDATE;TZID=America/New_York:20261103T090000"), "{}", ics);
        // exception row: RECURRENCE-ID, no RRULE
        let mut x = ev();
        x.recurrence_id = Some(parse_ts("2026-11-10T14:00:00Z").unwrap());
        let ics = build_ics(Method::Request, &x, "");
        assert!(ics.contains("RECURRENCE-ID:20261110T140000Z") && !ics.contains("RRULE"), "{}", ics);
        // a bad rule never reaches a guest's calendar
        let mut b = ev();
        b.rrule = Some("FREQ=SECONDLY".into());
        assert!(!build_ics(Method::Request, &b, "").contains("RRULE"));
        // one-off meetings are byte-for-byte what they were: UTC, no VTIMEZONE
        let plain = build_ics(Method::Request, &ev(), "");
        assert!(plain.contains("DTSTART:20261020T140000Z") && !plain.contains("VTIMEZONE"));
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

/* ====================================================================== recurrence (B7b, 22 Oct 2026)
 * RFC 5545 RRULE (DAILY/WEEKLY/MONTHLY/YEARLY, INTERVAL, COUNT, UNTIL, BYDAY[+nth], BYMONTHDAY[+negative], BYMONTH, WKST)
 * + time zones WITHOUT any crate: TZif (/usr/share/zoneinfo) + POSIX footer rule, so DST is right for every user,
 * every package. Fixed-offset fallback when the zone file is missing. Pure std — no clock, no network.
 */
pub mod recur {
    use super::{civil_from_days, days_from_civil};
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex, OnceLock};

    pub const MAX_COUNT: u32 = 1000;
    pub const MAX_INSTANCES: usize = 800;

    #[derive(Clone, Copy, Debug, PartialEq)]
    pub enum Freq { Daily, Weekly, Monthly, Yearly }

    #[derive(Clone, Debug, PartialEq)]
    pub struct Rule {
        pub freq: Freq,
        pub interval: i64,
        pub count: Option<u32>,
        pub until: Option<i64>,          // UTC epoch, inclusive
        pub byday: Vec<(i8, u8)>,        // (nth or 0, weekday 0=Sun..6=Sat)
        pub bymonthday: Vec<i8>,
        pub bymonth: Vec<u8>,
        pub wkst: u8,                    // 0=Sun..6=Sat (default Monday = 1)
    }

    fn wd_code(s: &str) -> Option<u8> {
        Some(match s { "SU" => 0, "MO" => 1, "TU" => 2, "WE" => 3, "TH" => 4, "FR" => 5, "SA" => 6, _ => return None })
    }

    /// 1970-01-01 was a Thursday. 0 = Sunday.
    pub fn weekday_of_day(days: i64) -> u8 { (days + 4).rem_euclid(7) as u8 }

    pub fn days_in_month(y: i64, m: u32) -> u32 {
        match m { 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31, 4 | 6 | 9 | 11 => 30,
            _ => if (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 { 29 } else { 28 } }
    }

    fn parse_until(v: &str) -> Option<i64> {
        let b = v.as_bytes();
        if b.len() < 8 || !b[..8].iter().all(|c| c.is_ascii_digit()) { return None; }
        let n = |a: usize, z: usize| v.get(a..z)?.parse::<i64>().ok();
        let (y, mo, d) = (n(0, 4)?, n(4, 6)? as u32, n(6, 8)? as u32);
        if !(1..=12).contains(&mo) || d < 1 || d > days_in_month(y, mo) { return None; }
        let (h, mi, s) = if b.len() >= 15 && b[8] == b'T' { (n(9, 11)?, n(11, 13)?, n(13, 15)?) } else { (23, 59, 59) };
        Some(days_from_civil(y, mo, d) * 86_400 + h * 3600 + mi * 60 + s)
    }

    pub fn parse(src: &str) -> Result<Rule, String> {
        let src = src.trim();
        let src = src.strip_prefix("RRULE:").unwrap_or(src);
        if src.is_empty() || src.len() > 300 { return Err("rrule_empty".into()); }
        let mut r = Rule { freq: Freq::Daily, interval: 1, count: None, until: None, byday: vec![], bymonthday: vec![], bymonth: vec![], wkst: 1 };
        let mut have_freq = false;
        for part in src.split(';') {
            let (k, v) = part.split_once('=').ok_or("rrule_syntax")?;
            let (k, v) = (k.trim().to_ascii_uppercase(), v.trim().to_ascii_uppercase());
            match k.as_str() {
                "FREQ" => {
                    r.freq = match v.as_str() { "DAILY" => Freq::Daily, "WEEKLY" => Freq::Weekly, "MONTHLY" => Freq::Monthly, "YEARLY" => Freq::Yearly, _ => return Err("rrule_freq".into()) };
                    have_freq = true;
                }
                "INTERVAL" => { r.interval = v.parse::<i64>().map_err(|_| "rrule_interval")?; if !(1..=99).contains(&r.interval) { return Err("rrule_interval".into()); } }
                "COUNT" => { let c = v.parse::<u32>().map_err(|_| "rrule_count")?; if c == 0 || c > MAX_COUNT { return Err("rrule_count".into()); } r.count = Some(c); }
                "UNTIL" => r.until = Some(parse_until(&v).ok_or("rrule_until")?),
                "WKST" => r.wkst = wd_code(&v).ok_or("rrule_wkst")?,
                "BYDAY" => {
                    for d in v.split(',') {
                        let d = d.trim();
                        if d.len() < 2 { return Err("rrule_byday".into()); }
                        let (num, code) = d.split_at(d.len() - 2);
                        let n: i8 = if num.is_empty() { 0 } else { num.parse().map_err(|_| "rrule_byday")? };
                        if !(-5..=5).contains(&n) { return Err("rrule_byday".into()); }
                        r.byday.push((n, wd_code(code).ok_or("rrule_byday")?));
                    }
                }
                "BYMONTHDAY" => for d in v.split(',') { let n: i8 = d.trim().parse().map_err(|_| "rrule_monthday")?; if n == 0 || !(-31..=31).contains(&n) { return Err("rrule_monthday".into()); } r.bymonthday.push(n); },
                "BYMONTH" => for d in v.split(',') { let n: u8 = d.trim().parse().map_err(|_| "rrule_month")?; if !(1..=12).contains(&n) { return Err("rrule_month".into()); } r.bymonth.push(n); },
                _ => return Err("rrule_unsupported".into()),   // BYSETPOS, BYHOUR… not offered — better a clear error than a wrong calendar
            }
        }
        if !have_freq { return Err("rrule_freq".into()); }
        if r.count.is_some() && r.until.is_some() { return Err("rrule_count_until".into()); }
        if r.freq == Freq::Weekly && r.byday.iter().any(|d| d.0 != 0) { return Err("rrule_byday".into()); }
        Ok(r)
    }

    pub fn to_string(r: &Rule) -> String {
        let mut s = String::from(match r.freq { Freq::Daily => "FREQ=DAILY", Freq::Weekly => "FREQ=WEEKLY", Freq::Monthly => "FREQ=MONTHLY", Freq::Yearly => "FREQ=YEARLY" });
        if r.interval != 1 { s.push_str(&format!(";INTERVAL={}", r.interval)); }
        if let Some(c) = r.count { s.push_str(&format!(";COUNT={}", c)); }
        if let Some(u) = r.until { s.push_str(&format!(";UNTIL={}", super::fmt_ics(u))); }
        if !r.byday.is_empty() {
            let n = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
            let v: Vec<String> = r.byday.iter().map(|(k, d)| if *k == 0 { n[*d as usize].to_string() } else { format!("{}{}", k, n[*d as usize]) }).collect();
            s.push_str(&format!(";BYDAY={}", v.join(",")));
        }
        if !r.bymonthday.is_empty() { s.push_str(&format!(";BYMONTHDAY={}", r.bymonthday.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(","))); }
        if !r.bymonth.is_empty() { s.push_str(&format!(";BYMONTH={}", r.bymonth.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(","))); }
        if r.wkst != 1 { s.push_str(&format!(";WKST={}", ["SU", "MO", "TU", "WE", "TH", "FR", "SA"][r.wkst as usize])); }
        s
    }

    /* -------------------------------------------------------------- time zones */

    #[derive(Clone, Debug)]
    pub struct PosixRule { m: u32, w: u32, d: u32, time: i64 }
    #[derive(Clone, Debug)]
    pub struct Posix { std: i32, dst: Option<(i32, PosixRule, PosixRule)> }

    #[derive(Clone, Debug)]
    pub enum Tz {
        Fixed(i32),
        Zone { trans: Vec<(i64, usize)>, types: Vec<i32>, initial: i32, footer: Option<Posix> },
    }

    fn parse_posix_name(b: &[u8], i: &mut usize) -> bool {
        if *i < b.len() && b[*i] == b'<' { while *i < b.len() && b[*i] != b'>' { *i += 1; } if *i >= b.len() { return false; } *i += 1; return true; }
        let s = *i; while *i < b.len() && b[*i].is_ascii_alphabetic() { *i += 1; } *i - s >= 3
    }
    fn parse_hms(b: &[u8], i: &mut usize) -> Option<i64> {
        let mut sign = 1i64;
        if *i < b.len() && (b[*i] == b'+' || b[*i] == b'-') { if b[*i] == b'-' { sign = -1; } *i += 1; }
        let mut parts = [0i64; 3]; let mut p = 0;
        loop {
            let s = *i; while *i < b.len() && b[*i].is_ascii_digit() { *i += 1; }
            if s == *i { return None; }
            parts[p] = std::str::from_utf8(&b[s..*i]).ok()?.parse().ok()?;
            p += 1;
            if p < 3 && *i < b.len() && b[*i] == b':' { *i += 1; } else { break; }
        }
        Some(sign * (parts[0] * 3600 + parts[1] * 60 + parts[2]))
    }
    fn parse_rule(b: &[u8], i: &mut usize) -> Option<PosixRule> {
        if *i >= b.len() || b[*i] != b'M' { return None; }
        *i += 1;
        let mut nums = [0u32; 3];
        for k in 0..3 {
            let s = *i; while *i < b.len() && b[*i].is_ascii_digit() { *i += 1; }
            nums[k] = std::str::from_utf8(&b[s..*i]).ok()?.parse().ok()?;
            if k < 2 { if *i >= b.len() || b[*i] != b'.' { return None; } *i += 1; }
        }
        let mut time = 7200;
        if *i < b.len() && b[*i] == b'/' { *i += 1; time = parse_hms(b, i)?; }
        Some(PosixRule { m: nums[0], w: nums[1], d: nums[2], time })
    }
    fn parse_posix(s: &str) -> Option<Posix> {
        let b = s.as_bytes(); let mut i = 0;
        if !parse_posix_name(b, &mut i) { return None; }
        let std = -(parse_hms(b, &mut i)? as i32);
        if i >= b.len() { return Some(Posix { std, dst: None }); }
        if !parse_posix_name(b, &mut i) { return None; }
        let mut dst = std + 3600;
        if i < b.len() && b[i] != b',' { dst = -(parse_hms(b, &mut i)? as i32); }
        if i >= b.len() || b[i] != b',' { return Some(Posix { std, dst: None }); }
        i += 1; let a = parse_rule(b, &mut i)?;
        if i >= b.len() || b[i] != b',' { return None; }
        i += 1; let z = parse_rule(b, &mut i)?;
        Some(Posix { std, dst: Some((dst, a, z)) })
    }
    /// Local wall-clock seconds (as if UTC) of "month m, week w (5=last), weekday d" of `y`, plus time-of-day.
    fn rule_local(y: i64, r: &PosixRule) -> i64 {
        let first = days_from_civil(y, r.m, 1);
        let mut day = first + ((r.d as i64 - weekday_of_day(first) as i64).rem_euclid(7)) + 7 * (r.w as i64 - 1);
        while day >= first + days_in_month(y, r.m) as i64 { day -= 7; }
        day * 86_400 + r.time
    }
    impl Posix {
        fn offset_at(&self, t: i64) -> i32 {
            let (dst, a, z) = match &self.dst { Some(x) => x, None => return self.std };
            let y = civil_from_days((t + self.std as i64).div_euclid(86_400)).0;
            let start = rule_local(y, a) - self.std as i64;
            let end = rule_local(y, z) - *dst as i64;
            let on = if start < end { t >= start && t < end } else { !(t >= end && t < start) };
            if on { *dst } else { self.std }
        }
    }

    fn be32(b: &[u8], o: usize) -> Option<i64> { Some(i32::from_be_bytes(b.get(o..o + 4)?.try_into().ok()?) as i64) }
    fn be64(b: &[u8], o: usize) -> Option<i64> { Some(i64::from_be_bytes(b.get(o..o + 8)?.try_into().ok()?)) }

    pub fn parse_tzif(b: &[u8]) -> Option<Tz> {
        if b.get(0..4)? != b"TZif" { return None; }
        let ver = *b.get(4)?;
        let hdr = |o: usize| -> Option<[usize; 6]> {
            let mut c = [0usize; 6];
            for k in 0..6 { c[k] = be32(b, o + 20 + 4 * k)? as usize; }
            Some(c)           // isutcnt, isstdcnt, leapcnt, timecnt, typecnt, charcnt
        };
        let h1 = hdr(0)?;
        let v1_len = h1[3] * 5 + h1[4] * 6 + h1[5] + h1[2] * 8 + h1[1] + h1[0];
        let (base, tsz, h) = if ver >= b'2' { let o = 44 + v1_len; (o, 8usize, hdr(o)?) } else { (0usize, 4usize, h1) };
        let (timecnt, typecnt, charcnt, leapcnt, isstd, isut) = (h[3], h[4], h[5], h[2], h[1], h[0]);
        let mut o = base + 44;
        let mut times = Vec::with_capacity(timecnt);
        for k in 0..timecnt { times.push(if tsz == 8 { be64(b, o + 8 * k)? } else { be32(b, o + 4 * k)? }); }
        o += timecnt * tsz;
        let idx: Vec<usize> = b.get(o..o + timecnt)?.iter().map(|x| *x as usize).collect();
        o += timecnt;
        let mut types = Vec::with_capacity(typecnt);
        for k in 0..typecnt { types.push(be32(b, o + 6 * k)? as i32); }
        o += typecnt * 6 + charcnt + leapcnt * (tsz + 4) + isstd + isut;
        let mut footer = None;
        if ver >= b'2' {
            if let Some(rest) = b.get(o..) {
                if rest.first() == Some(&b'\n') {
                    if let Some(end) = rest[1..].iter().position(|c| *c == b'\n') { footer = std::str::from_utf8(&rest[1..1 + end]).ok().and_then(parse_posix); }
                }
            }
        }
        if types.is_empty() { return None; }
        if idx.iter().any(|i| *i >= types.len()) { return None; }
        let initial = types[0];
        Some(Tz::Zone { trans: times.into_iter().zip(idx).collect(), types, initial, footer })
    }

    impl Tz {
        pub fn utc() -> Tz { Tz::Fixed(0) }
        /// Offset (seconds east of UTC) in force at the UTC instant `t`.
        pub fn offset_at(&self, t: i64) -> i32 {
            match self {
                Tz::Fixed(o) => *o,
                Tz::Zone { trans, types, initial, footer } => {
                    let beyond = trans.last().map_or(true, |l| t >= l.0);
                    if beyond { if let Some(f) = footer { return f.offset_at(t); } }
                    if trans.is_empty() || t < trans[0].0 { return *initial; }
                    let p = trans.partition_point(|x| x.0 <= t);
                    types[trans[p - 1].1]
                }
            }
        }
        /// Wall-clock `local` (seconds, as if UTC) -> UTC instant. Fold (clocks back) = first occurrence; gap (clocks forward) = shifted forward.
        pub fn local_to_utc(&self, local: i64) -> i64 {
            let a = self.offset_at(local - 86_400) as i64;
            let b = self.offset_at(local + 86_400) as i64;
            let ok = |o: i64| self.offset_at(local - o) as i64 == o;
            match (ok(a), ok(b)) {
                (true, true) => (local - a).min(local - b),
                (true, false) => local - a,
                (false, true) => local - b,
                (false, false) => local - a,   // gap: use the offset from before the jump
            }
        }
        pub fn to_local(&self, t: i64) -> i64 { t + self.offset_at(t) as i64 }

        /// iCalendar VTIMEZONE block (LF-joined, no trailing newline) so guests' calendars repeat in this zone with correct DST.
        /// None for a fixed-offset fallback (then the invite stays in UTC).
        pub fn vtimezone(&self, name: &str, at: i64) -> Option<String> {
            let footer = match self { Tz::Zone { footer, .. } => footer, Tz::Fixed(_) => return None };
            let off = |o: i32| { let a = o.abs(); format!("{}{:02}{:02}", if o < 0 { "-" } else { "+" }, a / 3600, (a % 3600) / 60) };
            let day = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
            let tod = |t: i64| { let t = t.clamp(0, 86_399); format!("19700101T{:02}{:02}{:02}", t / 3600, (t % 3600) / 60, t % 60) };
            let rr = |r: &PosixRule| format!("FREQ=YEARLY;BYMONTH={};BYDAY={}{}", r.m, if r.w >= 5 { "-1".to_string() } else { r.w.to_string() }, day[(r.d % 7) as usize]);
            let mut v: Vec<String> = vec!["BEGIN:VTIMEZONE".into(), format!("TZID:{}", name)];
            match footer {
                Some(Posix { std, dst: Some((d, a, z)) }) => {
                    v.extend([format!("BEGIN:DAYLIGHT"), format!("DTSTART:{}", tod(a.time)), format!("TZOFFSETFROM:{}", off(*std)), format!("TZOFFSETTO:{}", off(*d)), format!("RRULE:{}", rr(a)), "END:DAYLIGHT".to_string()]);
                    v.extend([format!("BEGIN:STANDARD"), format!("DTSTART:{}", tod(z.time)), format!("TZOFFSETFROM:{}", off(*d)), format!("TZOFFSETTO:{}", off(*std)), format!("RRULE:{}", rr(z)), "END:STANDARD".to_string()]);
                }
                other => {
                    let o = match other { Some(Posix { std, .. }) => *std, None => self.offset_at(at) };
                    v.extend(["BEGIN:STANDARD".to_string(), "DTSTART:19700101T000000".to_string(), format!("TZOFFSETFROM:{}", off(o)), format!("TZOFFSETTO:{}", off(o)), "END:STANDARD".to_string()]);
                }
            }
            v.push("END:VTIMEZONE".into());
            Some(v.join("\n"))
        }
    }

    /// TZID written into an .ics must be a plain IANA name (no header injection, no odd characters).
    pub fn ics_zone_name_ok(n: &str) -> bool { zone_name_ok(n) && !n.contains('+') || n == "Etc/GMT+0" }

    /// Short English description for invitation mails ("every 2 weeks on Mon, Thu until 31 Dec 2026").
    pub fn human(r: &Rule) -> String {
        let unit = match r.freq { Freq::Daily => "day", Freq::Weekly => "week", Freq::Monthly => "month", Freq::Yearly => "year" };
        let mut s = if r.interval == 1 { format!("every {}", unit) } else { format!("every {} {}s", r.interval, unit) };
        if !r.byday.is_empty() {
            let n = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            let v: Vec<String> = r.byday.iter().map(|(k, d)| match *k { 0 => n[*d as usize].to_string(), -1 => format!("last {}", n[*d as usize]), k => format!("{} {}", ["", "1st", "2nd", "3rd", "4th", "5th"][k.unsigned_abs() as usize % 6], n[*d as usize]) }).collect();
            s.push_str(&format!(" on {}", v.join(", ")));
        }
        if let Some(c) = r.count { s.push_str(&format!(", {} times", c)); }
        if let Some(u) = r.until { s.push_str(&format!(" until {}", super::fmt_human_utc(u).split(',').next().unwrap_or(""))); }
        s
    }

    fn zone_name_ok(n: &str) -> bool {
        !n.is_empty() && n.len() <= 64 && !n.contains("..") && !n.starts_with('/')
            && n.bytes().all(|c| c.is_ascii_alphanumeric() || matches!(c, b'_' | b'-' | b'+' | b'/'))
    }

    /// Real zone from the OS database (cached). Missing/bad name -> `Fixed(fallback_offset_secs)`.
    pub fn load_tz(name: &str, fallback_offset_secs: i32) -> Arc<Tz> {
        static CACHE: OnceLock<Mutex<HashMap<String, Arc<Tz>>>> = OnceLock::new();
        let cache = CACHE.get_or_init(|| Mutex::new(HashMap::new()));
        let key = name.to_string();
        if let Ok(m) = cache.lock() { if let Some(t) = m.get(&key) { return t.clone(); } }
        let tz = if zone_name_ok(name) {
            ["/usr/share/zoneinfo/", "/usr/lib/zoneinfo/", "/usr/share/lib/zoneinfo/"].iter()
                .find_map(|d| std::fs::read(format!("{}{}", d, name)).ok())
                .and_then(|b| parse_tzif(&b))
        } else { None };
        match tz {
            Some(t) => { let a = Arc::new(t); if let Ok(mut m) = cache.lock() { if m.len() < 400 { m.insert(key, a.clone()); } } a }
            None => Arc::new(Tz::Fixed(fallback_offset_secs)),   // not cached: a late-installed tzdata is picked up
        }
    }

    /* -------------------------------------------------------------- expansion */

    fn nth_weekday(y: i64, m: u32, nth: i8, wd: u8) -> Option<i64> {
        let dim = days_in_month(y, m) as i64;
        let first = days_from_civil(y, m, 1);
        if nth > 0 {
            let d = (wd as i64 - weekday_of_day(first) as i64).rem_euclid(7) + 7 * (nth as i64 - 1);
            if d < dim { Some(first + d) } else { None }
        } else {
            let last = first + dim - 1;
            let d = (weekday_of_day(last) as i64 - wd as i64).rem_euclid(7) + 7 * (-(nth as i64) - 1);
            if d < dim { Some(last - d) } else { None }
        }
    }
    fn month_days(y: i64, m: u32, r: &Rule, start_day_of_month: u32, start_wd: u8) -> Vec<i64> {
        let dim = days_in_month(y, m);
        let first = days_from_civil(y, m, 1);
        let mut out: Vec<i64> = Vec::new();
        if !r.byday.is_empty() {
            for (n, wd) in &r.byday {
                if *n == 0 { for d in 0..dim as i64 { if weekday_of_day(first + d) == *wd { out.push(first + d); } } }
                else if let Some(x) = nth_weekday(y, m, *n, *wd) { out.push(x); }
            }
            if !r.bymonthday.is_empty() {
                let md: Vec<i64> = r.bymonthday.iter().filter_map(|d| { let d = if *d > 0 { *d as i64 } else { dim as i64 + 1 + *d as i64 }; if d >= 1 && d <= dim as i64 { Some(first + d - 1) } else { None } }).collect();
                out.retain(|x| md.contains(x));
            }
        } else if !r.bymonthday.is_empty() {
            for d in &r.bymonthday { let d = if *d > 0 { *d as i64 } else { dim as i64 + 1 + *d as i64 }; if d >= 1 && d <= dim as i64 { out.push(first + d - 1); } }
        } else if start_day_of_month <= dim { out.push(first + start_day_of_month as i64 - 1); }
        let _ = start_wd;
        out.sort_unstable(); out.dedup(); out
    }

    /// Occurrence start instants (UTC epoch) of a series that begins at `start` (UTC), in the wall-clock of `tz`,
    /// overlapping [from, to) given a fixed `duration`; `exdates` (UTC starts) are skipped but still count toward COUNT.
    /// Result sorted, capped at MAX_INSTANCES.
    pub fn expand(rule: &Rule, start: i64, duration: i64, tz: &Tz, exdates: &[i64], from: i64, to: i64) -> Vec<i64> {
        let mut out = Vec::new();
        let local0 = tz.to_local(start);
        let day0 = local0.div_euclid(86_400);
        let tod = local0.rem_euclid(86_400);
        let (y0, m0, d0) = civil_from_days(day0);
        let wd0 = weekday_of_day(day0);
        let step = rule.interval;
        let counted = rule.count.is_some();
        let want_end = |u: i64| u < to;
        let mut produced: u32 = 0;
        // fast-forward when COUNT does not force us to walk from the start
        let from_day = tz.to_local(from - duration.max(0) - 86_400).div_euclid(86_400);
        let mut k: i64 = if counted { 0 } else { match rule.freq {
            Freq::Daily => ((from_day - day0) / step - 1).max(0),
            Freq::Weekly => ((from_day - day0) / (7 * step) - 1).max(0),
            Freq::Monthly => { let (fy, fm, _) = civil_from_days(from_day); (((fy * 12 + fm as i64 - 1) - (y0 * 12 + m0 as i64 - 1)) / step - 1).max(0) }
            Freq::Yearly => { let (fy, _, _) = civil_from_days(from_day); ((fy - y0) / step - 1).max(0) }
        } };
        let mut guard = 0u32;
        loop {
            guard += 1; if guard > 40_000 { break; }
            let days: Vec<i64> = match rule.freq {
                Freq::Daily => { let d = day0 + k * step; vec![d] }
                Freq::Weekly => {
                    let wk0 = day0 - ((wd0 as i64 - rule.wkst as i64).rem_euclid(7));
                    let ws = wk0 + 7 * step * k;
                    let mut set: Vec<u8> = if rule.byday.is_empty() { vec![wd0] } else { rule.byday.iter().map(|x| x.1).collect() };
                    set.sort_unstable(); set.dedup();
                    let mut v: Vec<i64> = set.iter().map(|w| ws + ((*w as i64 - rule.wkst as i64).rem_euclid(7))).collect();
                    v.sort_unstable(); v
                }
                Freq::Monthly => {
                    let mi = y0 * 12 + m0 as i64 - 1 + k * step;
                    let (y, m) = (mi.div_euclid(12), (mi.rem_euclid(12) + 1) as u32);
                    if !rule.bymonth.is_empty() && !rule.bymonth.contains(&(m as u8)) { vec![] } else { month_days(y, m, rule, d0, wd0) }
                }
                Freq::Yearly => {
                    let y = y0 + k * step;
                    let months: Vec<u32> = if rule.bymonth.is_empty() { vec![m0] } else { let mut v: Vec<u32> = rule.bymonth.iter().map(|x| *x as u32).collect(); v.sort_unstable(); v };
                    let mut v = Vec::new();
                    for m in months { v.extend(month_days(y, m, rule, d0, wd0)); }
                    v
                }
            };
            let mut period_min = i64::MAX;
            for d in days {
                // daily/weekly/yearly BY* filters
                if matches!(rule.freq, Freq::Daily) {
                    if !rule.byday.is_empty() && !rule.byday.iter().any(|x| x.1 == weekday_of_day(d)) { continue; }
                    if !rule.bymonth.is_empty() && !rule.bymonth.contains(&(civil_from_days(d).1 as u8)) { continue; }
                    if !rule.bymonthday.is_empty() { let (y, m, dd) = civil_from_days(d); let dim = days_in_month(y, m) as i64; if !rule.bymonthday.iter().any(|x| (if *x > 0 { *x as i64 } else { dim + 1 + *x as i64 }) == dd as i64) { continue; } }
                }
                if matches!(rule.freq, Freq::Weekly) && !rule.bymonth.is_empty() && !rule.bymonth.contains(&(civil_from_days(d).1 as u8)) { continue; }
                if d < day0 || (d == day0 && false) { continue; }
                let u = tz.local_to_utc(d * 86_400 + tod);
                if u < start { continue; }
                period_min = period_min.min(u);
                if let Some(un) = rule.until { if u > un { return out; } }
                produced += 1;
                if let Some(c) = rule.count { if produced > c { return out; } }
                if exdates.iter().any(|e| *e == u) { continue; }
                if u + duration > from && want_end(u) { out.push(u); if out.len() >= MAX_INSTANCES { return out; } }
            }
            if period_min != i64::MAX && period_min >= to && !matches!(rule.freq, Freq::Daily) { break; }
            if matches!(rule.freq, Freq::Daily) && (day0 + k * step) * 86_400 > to + 2 * 86_400 { break; }
            if matches!(rule.freq, Freq::Weekly) && (day0 + 7 * step * k) * 86_400 > to + 8 * 86_400 { break; }
            if matches!(rule.freq, Freq::Monthly) && k * step > 12 * 200 { break; }
            if matches!(rule.freq, Freq::Yearly) && k * step > 200 { break; }
            if (matches!(rule.freq, Freq::Monthly) || matches!(rule.freq, Freq::Yearly)) && period_min == i64::MAX {
                // empty period (e.g. 31st in short month): keep going, but stop once we are far past `to`
                let probe = match rule.freq { Freq::Monthly => { let mi = y0 * 12 + m0 as i64 - 1 + k * step; days_from_civil(mi.div_euclid(12), (mi.rem_euclid(12) + 1) as u32, 1) }, _ => days_from_civil(y0 + k * step, 1, 1) };
                if probe * 86_400 > to + 400 * 86_400 { break; }
            }
            k += 1;
        }
        out
    }

    /// Instance id: "<uuid>~<original start epoch>".
    pub fn occ_id(master: &str, start: i64) -> String { format!("{}~{}", master, start) }
    pub fn split_occ(id: &str) -> (&str, Option<i64>) {
        match id.split_once('~') { Some((m, e)) => (m, e.parse::<i64>().ok()), None => (id, None) }
    }

    #[cfg(test)]
    mod tests {
        use super::*;
        use super::super::parse_ts as ts;
        fn t(s: &str) -> i64 { ts(s).unwrap() }
        fn iso(v: &[i64]) -> Vec<String> { v.iter().map(|x| super::super::fmt_rfc3339(*x)).collect() }

        #[test]
        fn parse_and_print() {
            let r = parse("RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=6").unwrap();
            assert_eq!(to_string(&r), "FREQ=WEEKLY;INTERVAL=2;COUNT=6;BYDAY=MO,WE");
            assert!(parse("FREQ=HOURLY").is_err());
            assert!(parse("FREQ=DAILY;COUNT=5;UNTIL=20261231").is_err());
            assert!(parse("FREQ=DAILY;BYSETPOS=1").is_err());
            assert!(parse("FREQ=DAILY;COUNT=99999").is_err());
            assert!(parse("FREQ=WEEKLY;BYDAY=1MO").is_err());
            assert!(parse("").is_err());
        }

        #[test]
        fn daily_count_and_exdate() {
            let r = parse("FREQ=DAILY;COUNT=4").unwrap();
            let s = t("2026-10-20T09:00:00Z");
            let v = expand(&r, s, 1800, &Tz::utc(), &[], 0, s + 30 * 86_400);
            assert_eq!(v.len(), 4);
            let v = expand(&r, s, 1800, &Tz::utc(), &[s + 86_400], 0, s + 30 * 86_400);
            assert_eq!(v.len(), 3);           // exdate removed, COUNT still 4 instances long
            assert_eq!(v[1], s + 2 * 86_400);
        }

        #[test]
        fn weekly_byday_interval() {
            let r = parse("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH").unwrap();
            let s = t("2026-10-22T10:00:00Z");   // Thursday
            let v = expand(&r, s, 3600, &Tz::utc(), &[], s, s + 40 * 86_400);
            assert_eq!(iso(&v)[..4], ["2026-10-22T10:00:00Z", "2026-11-02T10:00:00Z", "2026-11-05T10:00:00Z", "2026-11-16T10:00:00Z"].map(String::from));
        }

        #[test]
        fn monthly_rules() {
            let s = t("2026-01-31T08:00:00Z");
            let r = parse("FREQ=MONTHLY").unwrap();                         // 31st: months without 31 are skipped
            let v = expand(&r, s, 60, &Tz::utc(), &[], s, t("2026-06-30T00:00:00Z"));
            assert_eq!(iso(&v), ["2026-01-31T08:00:00Z", "2026-03-31T08:00:00Z", "2026-05-31T08:00:00Z"].map(String::from));
            let r = parse("FREQ=MONTHLY;BYDAY=-1FR").unwrap();               // last Friday
            let s2 = t("2026-10-30T12:00:00Z");
            let v = expand(&r, s2, 60, &Tz::utc(), &[], s2, t("2027-01-31T00:00:00Z"));
            assert_eq!(iso(&v), ["2026-10-30T12:00:00Z", "2026-11-27T12:00:00Z", "2026-12-25T12:00:00Z", "2027-01-29T12:00:00Z"].map(String::from));
            let r = parse("FREQ=MONTHLY;BYDAY=2TU").unwrap();                // 2nd Tuesday
            let s3 = t("2026-10-13T12:00:00Z");
            let v = expand(&r, s3, 60, &Tz::utc(), &[], s3, t("2026-12-31T00:00:00Z"));
            assert_eq!(iso(&v), ["2026-10-13T12:00:00Z", "2026-11-10T12:00:00Z", "2026-12-08T12:00:00Z"].map(String::from));
            let r = parse("FREQ=MONTHLY;BYMONTHDAY=-1").unwrap();            // last day
            let s4 = t("2026-02-28T12:00:00Z");
            let v = expand(&r, s4, 60, &Tz::utc(), &[], s4, t("2026-05-01T00:00:00Z"));
            assert_eq!(iso(&v), ["2026-02-28T12:00:00Z", "2026-03-31T12:00:00Z", "2026-04-30T12:00:00Z"].map(String::from));
        }

        #[test]
        fn yearly_and_leap() {
            let r = parse("FREQ=YEARLY").unwrap();
            let s = t("2024-02-29T10:00:00Z");
            let v = expand(&r, s, 60, &Tz::utc(), &[], s, t("2033-01-01T00:00:00Z"));
            assert_eq!(iso(&v), ["2024-02-29T10:00:00Z", "2028-02-29T10:00:00Z", "2032-02-29T10:00:00Z"].map(String::from));
        }

        #[test]
        fn until_inclusive_and_window_fastforward() {
            let r = parse("FREQ=DAILY;UNTIL=20261024T090000Z").unwrap();
            let s = t("2026-10-20T09:00:00Z");
            let v = expand(&r, s, 60, &Tz::utc(), &[], 0, s + 90 * 86_400);
            assert_eq!(v.len(), 5);
            // long-running series seen through a 7-day window far from its start
            let r = parse("FREQ=DAILY").unwrap();
            let s = t("2020-01-01T09:00:00Z");
            let w0 = t("2026-10-19T00:00:00Z");
            let v = expand(&r, s, 60, &Tz::utc(), &[], w0, w0 + 7 * 86_400);
            assert_eq!(v.len(), 7);
            let r = parse("FREQ=WEEKLY;BYDAY=TU").unwrap();
            let s = t("2020-01-07T09:00:00Z");
            let v = expand(&r, s, 60, &Tz::utc(), &[], w0, w0 + 14 * 86_400);
            assert_eq!(iso(&v), ["2026-10-20T09:00:00Z", "2026-10-27T09:00:00Z"].map(String::from));
        }

        #[test]
        fn overlap_counts_running_instance() {
            let r = parse("FREQ=DAILY").unwrap();
            let s = t("2026-10-20T23:00:00Z");
            let v = expand(&r, s, 7200, &Tz::utc(), &[], t("2026-10-21T00:30:00Z"), t("2026-10-21T01:00:00Z"));
            assert_eq!(iso(&v), ["2026-10-20T23:00:00Z"].map(String::from));   // started yesterday, still running
        }

        #[test]
        fn fixed_zone_karachi() {
            let tz = Tz::Fixed(5 * 3600);
            let r = parse("FREQ=DAILY;COUNT=2").unwrap();
            let s = t("2026-10-22T04:00:00Z");        // 09:00 PKT
            let v = expand(&r, s, 60, &tz, &[], 0, s + 5 * 86_400);
            assert_eq!(iso(&v), ["2026-10-22T04:00:00Z", "2026-10-23T04:00:00Z"].map(String::from));
        }

        fn zone(n: &str) -> Option<Tz> { std::fs::read(format!("/usr/share/zoneinfo/{}", n)).ok().and_then(|b| parse_tzif(&b)) }

        #[test]
        fn dst_new_york_weekly_keeps_wall_clock() {
            let tz = match zone("America/New_York") { Some(z) => z, None => return };
            let r = parse("FREQ=WEEKLY").unwrap();
            let s = t("2026-10-27T13:00:00Z");        // Tue 09:00 EDT
            let v = expand(&r, s, 3600, &tz, &[], s, t("2026-11-12T00:00:00Z"));
            // US DST ends Sun 1 Nov 2026 -> from 3 Nov the same 09:00 is 14:00Z
            assert_eq!(iso(&v), ["2026-10-27T13:00:00Z", "2026-11-03T14:00:00Z", "2026-11-10T14:00:00Z"].map(String::from));
        }

        #[test]
        fn dst_footer_far_future_and_london() {
            let ny = match zone("America/New_York") { Some(z) => z, None => return };
            assert_eq!(ny.offset_at(t("2040-07-01T12:00:00Z")), -4 * 3600);
            assert_eq!(ny.offset_at(t("2040-01-15T12:00:00Z")), -5 * 3600);
            let ld = match zone("Europe/London") { Some(z) => z, None => return };
            assert_eq!(ld.offset_at(t("2026-03-29T00:59:00Z")), 0);
            assert_eq!(ld.offset_at(t("2026-03-29T01:00:00Z")), 3600);
            let khi = match zone("Asia/Karachi") { Some(z) => z, None => return };
            assert_eq!(khi.offset_at(t("2026-10-22T00:00:00Z")), 5 * 3600);
            let syd = match zone("Australia/Sydney") { Some(z) => z, None => return };
            assert_eq!(syd.offset_at(t("2026-01-15T00:00:00Z")), 11 * 3600);   // southern summer
            assert_eq!(syd.offset_at(t("2026-07-15T00:00:00Z")), 10 * 3600);
            assert_eq!(syd.offset_at(t("2045-01-15T00:00:00Z")), 11 * 3600);
        }

        #[test]
        fn dst_gap_and_fold() {
            let ny = match zone("America/New_York") { Some(z) => z, None => return };
            // 2026-03-08 02:30 local does not exist -> shifted forward to 03:30 EDT = 07:30Z
            let local = days_from_civil(2026, 3, 8) * 86_400 + 2 * 3600 + 1800;
            assert_eq!(super::super::fmt_rfc3339(ny.local_to_utc(local)), "2026-03-08T07:30:00Z");
            // 2026-11-01 01:30 local happens twice -> first (EDT) = 05:30Z
            let local = days_from_civil(2026, 11, 1) * 86_400 + 3600 + 1800;
            assert_eq!(super::super::fmt_rfc3339(ny.local_to_utc(local)), "2026-11-01T05:30:00Z");
        }

        #[test]
        fn human_text() {
            assert_eq!(human(&parse("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH;COUNT=6").unwrap()), "every 2 weeks on Mon, Thu, 6 times");
            assert_eq!(human(&parse("FREQ=MONTHLY;BYDAY=-1FR").unwrap()), "every month on last Fri");
            assert_eq!(human(&parse("FREQ=DAILY").unwrap()), "every day");
        }

        #[test]
        fn vtimezone_block() {
            let ny = match zone("America/New_York") { Some(z) => z, None => return };
            let v = ny.vtimezone("America/New_York", 0).unwrap();
            assert!(v.contains("BEGIN:DAYLIGHT") && v.contains("TZOFFSETTO:-0400") && v.contains("BYMONTH=3;BYDAY=2SU"), "{}", v);
            assert!(v.contains("BEGIN:STANDARD") && v.contains("TZOFFSETTO:-0500") && v.contains("BYMONTH=11;BYDAY=1SU"), "{}", v);
            let k = match zone("Asia/Karachi") { Some(z) => z, None => return };
            let v = k.vtimezone("Asia/Karachi", t("2026-10-22T00:00:00Z")).unwrap();
            assert!(!v.contains("DAYLIGHT") && v.contains("TZOFFSETTO:+0500"), "{}", v);
            assert!(Tz::Fixed(3600).vtimezone("x", 0).is_none());
            assert!(!ics_zone_name_ok("a\r\nX:1") && ics_zone_name_ok("Europe/London"));
        }

        #[test]
        fn occ_ids() {
            assert_eq!(split_occ("abc~123"), ("abc", Some(123)));
            assert_eq!(split_occ("abc"), ("abc", None));
            assert_eq!(occ_id("m", 5), "m~5");
        }

        #[test]
        fn zone_names_are_safe() {
            assert!(!zone_name_ok("../etc/passwd"));
            assert!(!zone_name_ok("/etc/passwd"));
            assert!(zone_name_ok("America/Argentina/Buenos_Aires"));
            assert!(matches!(&*load_tz("../../x", 3600), Tz::Fixed(3600)));
        }
    }
}
