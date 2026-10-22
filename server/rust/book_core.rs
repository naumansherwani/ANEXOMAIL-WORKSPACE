//! book_core — Booking page (B7c): pure, std-only logic. No I/O, no clock (caller passes `now`).
//!
//! A visitor opens anexomail.com/book/<handle>, picks a free slot and books. This file decides WHICH slots are
//! free (working hours, out-of-office days, busy time, buffer, minimum notice, horizon — DST-safe on a 15-minute
//! grid) and builds the confirmation / cancellation e-mails. The database (E59) re-validates every booking and its
//! EXCLUDE constraint is the last wall against two people taking one slot; this file only has to be right for the
//! happy path and never offer a slot the database would refuse.
//!
//! Tests run on the server by the installer (std-only, `rustc --test book_core.rs`); cal_core.rs sits next to it.
#![allow(dead_code)]

#[cfg(test)]
#[path = "cal_core.rs"]
mod cal_core;
#[cfg(not(test))]
use crate::cal_core;

use cal_core::recur::{self, Tz};
use cal_core::{self as cal, Interval};
use std::collections::HashMap;

pub const GRID_MIN: i64 = 15;
pub const MAX_WINDOW_DAYS: i64 = 31;

/* ------------------------------------------------------------------ handle */

const RESERVED: [&str; 12] = [
    "admin", "api", "app", "auth", "book", "manage", "new", "support", "www", "anexomail", "founder", "billing",
];

/// Same rule as the SQL validator `booking_handle_ok`: 3-30 chars, a-z 0-9 and single '-', never at the ends.
pub fn handle_ok(h: &str) -> bool {
    let b = h.as_bytes();
    if b.len() < 3 || b.len() > 30 {
        return false;
    }
    let edge = |c: u8| c.is_ascii_lowercase() || c.is_ascii_digit();
    if !edge(b[0]) || !edge(b[b.len() - 1]) {
        return false;
    }
    if !b.iter().all(|c| edge(*c) || *c == b'-') || h.contains("--") {
        return false;
    }
    !(RESERVED.contains(&h) || h == "help")
}

/// A good default handle from the e-mail's local part ("Nauman.Sherwani+x@anexomail.com" -> "nauman-sherwani-x").
/// Always passes `handle_ok` (falls back to "me-<digits>" when nothing usable is left).
pub fn suggest_handle(email: &str) -> String {
    let local = email.split('@').next().unwrap_or("");
    let mut out = String::new();
    for c in local.chars().flat_map(|c| c.to_lowercase()) {
        if c.is_ascii_lowercase() || c.is_ascii_digit() {
            out.push(c);
        } else if !out.ends_with('-') && !out.is_empty() {
            out.push('-');
        }
    }
    let mut out: String = out.trim_matches('-').chars().take(30).collect();
    out = out.trim_end_matches('-').to_string();
    if out.len() < 3 {
        let digits: String = local.chars().filter(|c| c.is_ascii_digit()).take(4).collect();
        out = format!("{}{}", if out.is_empty() { "me" } else { out.as_str() }, if digits.is_empty() { "-1".to_string() } else { format!("-{}", digits) });
        out = out.replace("--", "-");
    }
    if !handle_ok(&out) {
        return "me-1".to_string().replace("me-1", "my-page");
    }
    out
}

pub fn durations_ok(d: &[i64]) -> bool {
    if d.is_empty() || d.len() > 5 {
        return false;
    }
    if d.iter().any(|m| *m < 5 || *m > 480) {
        return false;
    }
    let mut s = d.to_vec();
    s.sort_unstable();
    s.dedup();
    s.len() == d.len()
}

/// IANA-name shape only (the database and the zone loader do the real lookup).
pub fn tz_shape_ok(z: &str) -> bool {
    let b = z.as_bytes();
    !b.is_empty()
        && b.len() <= 64
        && b[0].is_ascii_alphabetic()
        && b.iter().all(|c| c.is_ascii_alphanumeric() || matches!(c, b'_' | b'+' | b'/' | b'-'))
        && !z.contains("..")
}

/// True when the zone really exists in the OS database (a wrong name silently degrades to a fixed offset otherwise).
pub fn tz_known(z: &str) -> bool {
    if !tz_shape_ok(z) {
        return false;
    }
    if z.eq_ignore_ascii_case("UTC") || z == "Etc/UTC" {
        return true;
    }
    !matches!(&*recur::load_tz(z, 1), Tz::Fixed(1))
}

/* ---------------------------------------------------------- working hours */

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Day {
    pub on: bool,
    /// minutes after local midnight
    pub start: i64,
    pub end: i64,
}

/// Index 0 = Monday ... 6 = Sunday (same as the calendar settings).
pub type Week = [Day; 7];

pub fn default_week() -> Week {
    let wd = Day { on: true, start: 9 * 60, end: 17 * 60 };
    let we = Day { on: false, start: 9 * 60, end: 17 * 60 };
    [wd, wd, wd, wd, wd, we, we]
}

pub fn parse_hhmm(s: &str) -> Option<i64> {
    let (h, m) = s.split_once(':')?;
    let (h, m): (i64, i64) = (h.trim().parse().ok()?, m.trim().get(..2).unwrap_or(m.trim()).parse().ok()?);
    if (0..=24).contains(&h) && (0..60).contains(&m) && !(h == 24 && m > 0) {
        Some(h * 60 + m)
    } else {
        None
    }
}

/* ------------------------------------------------------------------ slots */

pub struct Params<'a> {
    pub tz: &'a Tz,
    pub week: Week,
    /// inclusive "YYYY-MM-DD" ranges the host is out of office
    pub ooo: &'a [(String, String)],
    pub minutes: i64,
    pub buffer_min: i64,
    pub min_notice_min: i64,
    pub max_days: i64,
    pub now: i64,
}

fn date_string(day: i64) -> String {
    let (y, m, d) = cal::civil_from_days(day);
    format!("{:04}-{:02}-{:02}", y, m, d)
}

/// Does [start, end) (plus `buffer_min` on both sides) touch any busy interval?
pub fn clashes(busy: &[Interval], start: i64, end: i64, buffer_min: i64) -> bool {
    let b = buffer_min * 60;
    busy.iter().any(|i| i.start < end + b && i.end > start - b)
}

/// Every bookable start (UTC epoch seconds) with `start` in [from, to). Sorted. Rules mirror SQL `booking_slot_problem`.
pub fn slots(p: &Params, from: i64, to: i64, busy: &[Interval]) -> Vec<i64> {
    if p.minutes < 5 || p.minutes > 480 || to <= from {
        return vec![];
    }
    let lo = from.max(p.now + p.min_notice_min * 60);
    // one minute inside the database's own horizon so the two never disagree on the last second
    let hi = (to - 1).min(p.now + p.max_days * 86_400 - 60);
    if hi < lo {
        return vec![];
    }
    let first_day = p.tz.to_local(lo).div_euclid(86_400) - 1;
    let last_day = p.tz.to_local(hi).div_euclid(86_400) + 1;
    let mut out = Vec::new();
    for day in first_day..=last_day {
        let date = date_string(day);
        if p.ooo.iter().any(|(a, b)| a.as_str() <= date.as_str() && date.as_str() <= b.as_str()) {
            continue;
        }
        let w = p.week[(day + 3).rem_euclid(7) as usize];
        if !w.on || w.end <= w.start {
            continue;
        }
        // grid anchored to local midnight, so 09:00, 09:15 ... whatever the zone offset is
        let mut t = (w.start + GRID_MIN - 1) / GRID_MIN * GRID_MIN;
        while t + p.minutes <= w.end {
            let local = day * 86_400 + t * 60;
            let start = p.tz.local_to_utc(local);
            let end = start + p.minutes * 60;
            t += GRID_MIN;
            // skip DST gaps / ambiguous hours and slots that straddle a clock change: wall time must be exact both ends
            if p.tz.to_local(start) != local || p.tz.to_local(end) != local + p.minutes * 60 {
                continue;
            }
            if start < lo || start > hi {
                continue;
            }
            if clashes(busy, start, end, p.buffer_min) {
                continue;
            }
            out.push(start);
        }
    }
    out.sort_unstable();
    out.dedup();
    out
}

/* -------------------------------------------------------- local time text */

const MONTHS: [&str; 12] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const WEEKDAYS: [&str; 7] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

/// "Tue 27 Oct 2026, 14:30" in zone `tz` (no zone suffix; caller adds the zone name).
pub fn fmt_local(epoch: i64, tz: &Tz) -> String {
    let local = tz.to_local(epoch);
    let days = local.div_euclid(86_400);
    let rem = local.rem_euclid(86_400);
    let (y, m, d) = cal::civil_from_days(days);
    format!(
        "{} {} {} {}, {:02}:{:02}",
        WEEKDAYS[(days + 3).rem_euclid(7) as usize],
        d,
        MONTHS[(m - 1) as usize],
        y,
        rem / 3600,
        rem % 3600 / 60
    )
}

/// "Tue 27 Oct 2026, 14:30–15:00 (Asia/Karachi)"
pub fn when_label(start: i64, end: i64, zone_name: &str, tz: &Tz) -> String {
    let e = tz.to_local(end).rem_euclid(86_400);
    format!("{}–{:02}:{:02} ({})", fmt_local(start, tz), e / 3600, e % 3600 / 60, cal::clean_line(zone_name, 64))
}

/* ---------------------------------------------------------------- throttle */

/// Sliding-window limiter, keyed by client address + purpose. In memory only (a restart forgets — that is fine).
#[derive(Default)]
pub struct Throttle {
    hits: HashMap<String, Vec<u64>>,
}

impl Throttle {
    /// Records the hit and returns true when it is allowed.
    pub fn allow(&mut self, key: &str, now_ms: u64, limit: usize, window_ms: u64) -> bool {
        if self.hits.len() > 5_000 {
            self.hits.retain(|_, v| v.last().map_or(false, |t| now_ms.saturating_sub(*t) < window_ms));
        }
        let v = self.hits.entry(key.to_string()).or_default();
        v.retain(|t| now_ms.saturating_sub(*t) < window_ms);
        if v.len() >= limit {
            return false;
        }
        v.push(now_ms);
        true
    }
}

/* ------------------------------------------------------------------- mail */

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Kind {
    Confirmed,
    Cancelled,
    Rescheduled,
}

pub struct MailIn<'a> {
    pub kind: Kind,
    /// who the mail is FROM (the host's own address — Postfix signs it with DKIM like every other mail)
    pub from_address: &'a str,
    pub from_name: Option<&'a str>,
    pub to_address: &'a str,
    pub to_name: Option<&'a str>,
    pub title: &'a str,
    pub host_name: &'a str,
    pub visitor_name: &'a str,
    pub when_label: &'a str,
    pub location: Option<&'a str>,
    pub note: Option<&'a str>,
    /// visitor mails carry the manage link; the host mail points at the calendar instead
    pub manage_url: Option<&'a str>,
    pub rebook_url: Option<&'a str>,
    /// RFC 5545 body (None for the host copy)
    pub ics: Option<&'a str>,
    pub message_id: &'a str,
    pub now: i64,
}

pub fn subject_for(m: &MailIn) -> String {
    let t = cal::clean_line(m.title, 100);
    let w = cal::clean_line(m.when_label, 80);
    match m.kind {
        Kind::Confirmed => format!("Confirmed: {} @ {}", t, w),
        Kind::Rescheduled => format!("Moved: {} @ {}", t, w),
        Kind::Cancelled => format!("Cancelled: {} @ {}", t, w),
    }
}

fn lines(m: &MailIn) -> Vec<String> {
    let mut v = Vec::new();
    let head = match (m.kind, m.manage_url.is_some()) {
        (Kind::Confirmed, true) => format!("Your meeting with {} is confirmed.", cal::clean_line(m.host_name, 80)),
        (Kind::Rescheduled, true) => format!("Your meeting with {} was moved.", cal::clean_line(m.host_name, 80)),
        (Kind::Cancelled, true) => format!("Your meeting with {} was cancelled.", cal::clean_line(m.host_name, 80)),
        (Kind::Confirmed, false) => format!("{} booked a time with you.", cal::clean_line(m.visitor_name, 80)),
        (Kind::Rescheduled, false) => format!("{} moved their booking.", cal::clean_line(m.visitor_name, 80)),
        (Kind::Cancelled, false) => format!("{} cancelled their booking.", cal::clean_line(m.visitor_name, 80)),
    };
    v.push(head);
    v.push(String::new());
    v.push(format!("What:  {}", cal::clean_line(m.title, 120)));
    v.push(format!("When:  {}", cal::clean_line(m.when_label, 120)));
    if let Some(l) = m.location.map(|l| cal::clean_line(l, 200)).filter(|l| !l.is_empty()) {
        v.push(format!("Where: {}", l));
    }
    if let Some(n) = m.note.map(|n| cal::clean_line(n, 500)).filter(|n| !n.is_empty()) {
        v.push(format!("Note:  {}", n));
    }
    v.push(String::new());
    if m.kind != Kind::Cancelled {
        if let Some(u) = m.manage_url {
            v.push(format!("Need to change plans? Move or cancel here: {}", u));
        }
    } else if let Some(u) = m.rebook_url {
        v.push(format!("Book another time: {}", u));
    }
    v
}

/// One complete RFC 5322 message: text + html + (optional) calendar part, every part base64 so UTF-8 is always safe.
pub fn build_mail(m: &MailIn) -> (String, String) {
    let subject = subject_for(m);
    let ls = lines(m);
    let text = ls.join("\r\n") + "\r\n";
    let mut html = String::from("<div style=\"font-family:system-ui,Segoe UI,Arial,sans-serif;font-size:15px;line-height:1.5;color:#111\">");
    for (i, l) in ls.iter().enumerate() {
        if l.is_empty() {
            continue;
        }
        let esc = cal::html_escape(l);
        let esc = match (l.find("https://"), i) {
            (Some(p), _) => {
                let url = cal::html_escape(l[p..].trim());
                format!("{}<a href=\"{}\">{}</a>", cal::html_escape(&l[..p]), url, url)
            }
            _ => esc,
        };
        html.push_str(&format!("<p style=\"margin:0 0 6px\">{}</p>", esc));
    }
    html.push_str("</div>");
    let seed: String = m.message_id.chars().filter(|c| c.is_ascii_alphanumeric()).take(40).collect();
    let alt = format!("axb_{}", seed);
    let mut o = String::new();
    o.push_str(&format!("From: {}\r\n", cal::mailbox(m.from_name, m.from_address)));
    o.push_str(&format!("To: {}\r\n", cal::mailbox(m.to_name, m.to_address)));
    o.push_str(&format!("Reply-To: <{}>\r\n", m.from_address));
    o.push_str(&format!("Subject: {}\r\n", cal::encode_header(&subject)));
    o.push_str(&format!("Date: {}\r\n", cal::fmt_rfc2822(m.now)));
    o.push_str(&format!("Message-ID: <{}>\r\n", m.message_id));
    o.push_str("MIME-Version: 1.0\r\n");
    o.push_str(&format!("Content-Type: multipart/alternative; boundary=\"{}\"\r\n\r\n", alt));
    o.push_str(&format!("--{}\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n{}", alt, cal::base64_mime(text.as_bytes())));
    o.push_str(&format!("--{}\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n{}", alt, cal::base64_mime(html.as_bytes())));
    if let Some(ics) = m.ics {
        let method = if m.kind == Kind::Cancelled { "CANCEL" } else { "REQUEST" };
        o.push_str(&format!(
            "--{}\r\nContent-Type: text/calendar; charset=UTF-8; method={}\r\nContent-Transfer-Encoding: base64\r\n\r\n{}",
            alt,
            method,
            cal::base64_mime(ics.as_bytes())
        ));
    }
    o.push_str(&format!("--{}--\r\n", alt));
    (subject, o)
}

/* ------------------------------------------------------------------ tests */

#[cfg(test)]
mod tests {
    use super::*;

    fn utc() -> Tz {
        Tz::utc()
    }
    fn day0(y: i64, m: u32, d: u32) -> i64 {
        cal::days_from_civil(y, m, d) * 86_400
    }
    fn params<'a>(tz: &'a Tz, ooo: &'a [(String, String)], now: i64) -> Params<'a> {
        Params { tz, week: default_week(), ooo, minutes: 30, buffer_min: 0, min_notice_min: 0, max_days: 60, now }
    }

    #[test]
    fn handle_rules_match_sql() {
        for ok in ["nauman", "a1b", "my-page", "x9-y8-z7"] {
            assert!(handle_ok(ok), "{}", ok);
        }
        for bad in ["ab", "-ab", "ab-", "a--b", "Abc", "a_b", "admin", "book", "help", "x".repeat(31).as_str(), "a b"] {
            assert!(!handle_ok(bad), "{}", bad);
        }
        assert!(handle_ok(&"x".repeat(30)));
    }

    #[test]
    fn suggest_always_valid() {
        assert_eq!(suggest_handle("Nauman.Sherwani+x@anexomail.com"), "nauman-sherwani-x");
        assert_eq!(suggest_handle("a@x.com"), "a-1");
        assert_eq!(suggest_handle("admin@x.com"), "my-page");
        for e in ["", "@x", "..@x", "12@x", "ÜÖ@x", "a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w@x", "x--y@x"] {
            assert!(handle_ok(&suggest_handle(e)), "{:?} -> {:?}", e, suggest_handle(e));
        }
    }

    #[test]
    fn durations_and_tz_shape() {
        assert!(durations_ok(&[15, 30, 60]));
        assert!(!durations_ok(&[]) && !durations_ok(&[30, 30]) && !durations_ok(&[4]) && !durations_ok(&[481]));
        assert!(!durations_ok(&[5, 10, 15, 20, 25, 30]));
        assert!(tz_shape_ok("Asia/Karachi") && tz_shape_ok("America/Argentina/Buenos_Aires"));
        assert!(!tz_shape_ok("../etc") && !tz_shape_ok("") && !tz_shape_ok("1abc") && !tz_shape_ok("a b"));
        assert!(tz_known("Asia/Karachi") && tz_known("UTC") && !tz_known("Mars/Olympus"));
    }

    #[test]
    fn hhmm() {
        assert_eq!(parse_hhmm("09:30"), Some(570));
        assert_eq!(parse_hhmm("24:00"), Some(1440));
        assert_eq!(parse_hhmm("24:30"), None);
        assert_eq!(parse_hhmm("9"), None);
        assert_eq!(parse_hhmm("ab:cd"), None);
    }

    #[test]
    fn weekday_grid_utc() {
        // Mon 2026-10-26 08:00 UTC "now"; window Mon..Tue
        let tz = utc();
        let now = day0(2026, 10, 26) + 8 * 3600;
        let p = params(&tz, &[], now);
        let s = slots(&p, now, day0(2026, 10, 28), &[]);
        // 09:00..16:30 on a 15-minute grid = 31 starts per day, 2 days
        assert_eq!(s.len(), 62);
        assert_eq!(s[0], day0(2026, 10, 26) + 9 * 3600);
        assert_eq!(*s.last().unwrap(), day0(2026, 10, 27) + 16 * 3600 + 1800);
    }

    #[test]
    fn weekend_and_ooo_are_empty() {
        let tz = utc();
        let now = day0(2026, 10, 22) + 3600;
        let p = params(&tz, &[], now);
        assert!(slots(&p, day0(2026, 10, 24), day0(2026, 10, 26), &[]).is_empty()); // Sat+Sun
        let ooo = vec![("2026-10-26".to_string(), "2026-10-27".to_string())];
        let p = params(&tz, &ooo, now);
        let s = slots(&p, day0(2026, 10, 26), day0(2026, 10, 29), &[]);
        assert_eq!(s.len(), 31); // only Wednesday
        assert_eq!(s[0], day0(2026, 10, 28) + 9 * 3600);
    }

    #[test]
    fn notice_and_horizon() {
        let tz = utc();
        let now = day0(2026, 10, 26) + 9 * 3600;
        let mut p = params(&tz, &[], now);
        p.min_notice_min = 240; // earliest 13:00
        let s = slots(&p, now, day0(2026, 10, 27), &[]);
        assert_eq!(s[0], day0(2026, 10, 26) + 13 * 3600);
        p.min_notice_min = 0;
        p.max_days = 1;
        let s = slots(&p, now, day0(2026, 11, 20), &[]);
        assert!(s.iter().all(|t| *t <= now + 86_400 - 60));
        assert!(!s.is_empty());
    }

    #[test]
    fn busy_and_buffer() {
        let tz = utc();
        let now = day0(2026, 10, 26);
        let mut p = params(&tz, &[], now);
        let busy = [Interval { start: now + 10 * 3600, end: now + 11 * 3600 }];
        let s = slots(&p, now, now + 86_400, &busy);
        assert!(!s.contains(&(now + 10 * 3600)) && !s.contains(&(now + 10 * 3600 + 1800)));
        assert!(s.contains(&(now + 9 * 3600 + 1800)) && s.contains(&(now + 11 * 3600)));
        p.buffer_min = 15;
        let s = slots(&p, now, now + 86_400, &busy);
        assert!(!s.contains(&(now + 9 * 3600 + 1800)) && !s.contains(&(now + 11 * 3600)));
        assert!(s.contains(&(now + 9 * 3600)) && s.contains(&(now + 11 * 3600 + 900)));
        // 45-minute meeting that would run into the busy block is refused
        p.buffer_min = 0;
        p.minutes = 45;
        let s = slots(&p, now, now + 86_400, &busy);
        assert!(!s.contains(&(now + 9 * 3600 + 1800)));
        assert!(s.contains(&(now + 9 * 3600 + 900)));
    }

    #[test]
    fn fixed_offset_zone_is_local() {
        let tz = Tz::Fixed(5 * 3600); // Karachi
        let now = day0(2026, 10, 26) - 86_400;
        let p = params(&tz, &[], now);
        let s = slots(&p, now, day0(2026, 10, 28), &[]);
        // 09:00 Karachi = 04:00 UTC
        assert_eq!(s[0], day0(2026, 10, 26) + 4 * 3600);
        assert_eq!(fmt_local(s[0], &tz), "Mon 26 Oct 2026, 09:00");
    }

    #[test]
    fn dst_zone_keeps_wall_clock_and_never_offers_gap() {
        let ny = recur::load_tz("America/New_York", 0);
        if matches!(&*ny, Tz::Fixed(_)) {
            panic!("America/New_York must exist on this machine");
        }
        // DST ends Sun 2026-11-01 -> Mon 2 Nov is EST: 09:00 local = 14:00 UTC; Fri 30 Oct EDT: 09:00 = 13:00 UTC
        let now = day0(2026, 10, 28);
        let p = params(&ny, &[], now);
        let s = slots(&p, day0(2026, 10, 30), day0(2026, 11, 4), &[]);
        assert!(s.contains(&(day0(2026, 10, 30) + 13 * 3600)));
        assert!(s.contains(&(day0(2026, 11, 2) + 14 * 3600)));
        assert!(!s.contains(&(day0(2026, 11, 2) + 13 * 3600)));
        // a host who works through the spring-forward gap (Sun 2027-03-14, 02:00-03:00 does not exist)
        let mut p2 = params(&ny, &[], day0(2027, 3, 10));
        p2.week = [Day { on: true, start: 60, end: 5 * 60 }; 7];
        let s = slots(&p2, day0(2027, 3, 14), day0(2027, 3, 15), &[]);
        for t in &s {
            let l = ny.to_local(*t).rem_euclid(86_400);
            assert!(!(l >= 2 * 3600 && l < 3 * 3600), "gap slot offered: {}", l);
            assert_eq!(ny.to_local(*t + 1800) - ny.to_local(*t), 1800);
        }
        assert!(!s.is_empty());
    }

    #[test]
    fn labels() {
        let tz = Tz::Fixed(5 * 3600);
        let s = day0(2026, 10, 27) + 9 * 3600; // 14:00 Karachi
        assert_eq!(when_label(s, s + 1800, "Asia/Karachi", &tz), "Tue 27 Oct 2026, 14:00–14:30 (Asia/Karachi)");
    }

    #[test]
    fn throttle_window() {
        let mut t = Throttle::default();
        for i in 0..3 {
            assert!(t.allow("ip:book", 1000 + i, 3, 60_000));
        }
        assert!(!t.allow("ip:book", 2000, 3, 60_000));
        assert!(t.allow("other:book", 2000, 3, 60_000));
        assert!(t.allow("ip:book", 70_000, 3, 60_000));
    }

    fn mail<'a>(kind: Kind, ics: Option<&'a str>, manage: Option<&'a str>) -> MailIn<'a> {
        MailIn {
            kind,
            from_address: "host@anexomail.com",
            from_name: Some("Host\r\nBcc: evil@x.com"),
            to_address: "v@example.com",
            to_name: Some("Ünï <script>"),
            title: "Intro call",
            host_name: "Host",
            visitor_name: "Visitor",
            when_label: "Tue 27 Oct 2026, 14:00–14:30 (Asia/Karachi)",
            location: Some("https://meet.example/x"),
            note: Some("Hello <b>there</b>"),
            manage_url: manage,
            rebook_url: Some("https://anexomail.com/book/host"),
            ics,
            message_id: "axb.test.1@anexomail.com",
            now: 1_800_000_000,
        }
    }

    #[test]
    fn mail_is_safe_and_complete() {
        let m = mail(Kind::Confirmed, Some("BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"), Some("https://anexomail.com/book/manage?t=abc"));
        let (subject, raw) = build_mail(&m);
        assert!(subject.starts_with("Confirmed: Intro call @ "));
        // header injection impossible: no raw CR/LF-separated extra header from the display name
        assert!(!raw.contains("\r\nBcc:"));
        assert!(raw.contains("Content-Type: text/calendar; charset=UTF-8; method=REQUEST"));
        assert!(raw.contains("multipart/alternative"));
        assert!(raw.ends_with("--\r\n"));
        // the body is base64, so the html-escaping is checked on the decoded text
        let (_, c) = build_mail(&mail(Kind::Cancelled, Some("X"), Some("https://anexomail.com/book/manage?t=abc")));
        assert!(c.contains("method=CANCEL"));
        let (hs, host_raw) = build_mail(&mail(Kind::Confirmed, None, None));
        assert!(hs.starts_with("Confirmed:") && !host_raw.contains("text/calendar"));
    }
}
