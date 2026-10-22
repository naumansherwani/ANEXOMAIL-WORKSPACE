// ============================================================================
// ics_core.rs — #4c: bahar ka calendar (ICS subscribe, SIRF PADHNE ke liye). Sirf std + cal_core; tests `rustc --test` se.
// (Network + DB `ics_glue.rs` mein. SQL: docs/cursor-work/sql/E73_calendar_subscriptions.sql)
//
// Kya yeh file karti hai:
//   - URL ki saaf shakl (webcal:// -> https://; sirf https, port 443, bina user:pass, bina local/internal naam) + SSRF ka dimaag `ip_allowed`
//   - ICS ka parser: line unfold, VEVENT, DTSTART/DTEND/DURATION, TZID (IANA + Windows naam), all-day, RRULE/EXDATE, RECURRENCE-ID overrides,
//     STATUS:CANCELLED. Kuch bhi ghalat/ajeeb ho to us event ko chhod deta hai aur ginti batata hai — kabhi crash nahi.
//   - `occurrences`: range ke andar asli events (RRULE cal_core::recur se), overrides master ki jagah leti hain, cancelled gayab
// Honest limits (stats mein ginti, chhupa nahi): floating time (bina zone) UTC maani jati hai (ya X-WR-TIMEZONE); VTIMEZONE block padha nahi
//   jata (IANA/Windows naam par bharosa); fancy RRULE (BYSETPOS wagera) ka jo hissa cal_core nahi samajhta wahi event sirf pehli baar dikhta hai.
// ============================================================================
#![allow(dead_code)]

#[cfg(test)]
#[path = "cal_core.rs"]
mod cal_core;
#[cfg(not(test))]
use crate::cal_core;

use cal_core::recur::{self, Tz};
use std::net::IpAddr;

pub const MAX_FEED_BYTES: usize = 5 * 1024 * 1024;
pub const MAX_EVENTS: usize = 2000;
pub const MAX_URL: usize = 2048;
const OLD_DAYS: i64 = 90;

/* ───────────────────────────── URL + SSRF ───────────────────────────── */

/// webcal(s):// -> https://. Sirf https, port 443, bina user:pass, bina local/internal naam. Ok(saaf url) ya Err(code).
pub fn normalize_url(raw: &str) -> Result<String, &'static str> {
    let t = raw.trim();
    if t.is_empty() || t.len() > MAX_URL || t.chars().any(|c| c.is_control() || c.is_whitespace()) {
        return Err("url_invalid");
    }
    let lower = t.to_ascii_lowercase();
    let rest = if let Some(r) = lower.strip_prefix("webcals://") {
        &t[t.len() - r.len()..]
    } else if let Some(r) = lower.strip_prefix("webcal://") {
        &t[t.len() - r.len()..]
    } else if let Some(r) = lower.strip_prefix("https://") {
        &t[t.len() - r.len()..]
    } else {
        return Err("url_not_https");
    };
    let end = rest.find(['/', '?', '#']).unwrap_or(rest.len());
    let authority = &rest[..end];
    if authority.is_empty() || authority.contains('@') {
        return Err("url_invalid");
    }
    let (host, port) = match authority.rsplit_once(':') {
        Some((h, p)) if !authority.starts_with('[') => (h, Some(p)),
        _ => (authority, None),
    };
    if let Some(p) = port {
        if p != "443" {
            return Err("url_port");
        }
    }
    if !host_name_ok(host) {
        return Err("url_host");
    }
    Ok(format!("https://{}{}", authority.to_ascii_lowercase(), &rest[end..]))
}

/// Naam ya IP literal. Local/internal naam rad. (IP literal ka asli faisla `ip_allowed`; yahan sirf shakl.)
pub fn host_name_ok(h: &str) -> bool {
    let h = h.trim_end_matches('.').to_ascii_lowercase();
    if h.is_empty() || h.len() > 253 || h.starts_with('[') {
        return false; // [v6] literal: calendar feeds ke liye zaroori nahi
    }
    if let Ok(ip) = h.parse::<IpAddr>() {
        return ip_allowed(ip);
    }
    if !h.contains('.') {
        return false; // "localhost", "intranet"
    }
    for bad in [".local", ".localhost", ".internal", ".lan", ".home", ".corp", ".intranet", ".private", ".test", ".invalid", ".example"] {
        if h.ends_with(bad) {
            return false;
        }
    }
    h.split('.').all(|l| !l.is_empty() && l.len() <= 63 && !l.starts_with('-') && !l.ends_with('-') && l.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-' || c >= 0x80))
}

/// SIRF public (global) IP. Loopback / private / link-local (169.254.169.254 metadata) / CGNAT / multicast / reserved sab band.
pub fn ip_allowed(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(v) => {
            let o = v.octets();
            !(v.is_unspecified()
                || v.is_loopback()
                || v.is_private()
                || v.is_link_local()
                || v.is_broadcast()
                || v.is_multicast()
                || o[0] == 0
                || (o[0] == 100 && (64..=127).contains(&o[1])) // CGNAT 100.64/10
                || (o[0] == 192 && o[1] == 0 && o[2] == 0)      // 192.0.0.0/24
                || (o[0] == 192 && o[1] == 0 && o[2] == 2)      // TEST-NET-1
                || (o[0] == 198 && (o[1] == 18 || o[1] == 19))  // benchmarking
                || (o[0] == 198 && o[1] == 51 && o[2] == 100)   // TEST-NET-2
                || (o[0] == 203 && o[1] == 0 && o[2] == 113)    // TEST-NET-3
                || o[0] >= 240)                                  // reserved + 255.x
        }
        IpAddr::V6(v) => {
            if let Some(m) = v.to_ipv4_mapped() {
                return ip_allowed(IpAddr::V4(m));
            }
            let s = v.segments();
            !(v.is_unspecified()
                || v.is_loopback()
                || v.is_multicast()
                || (s[0] & 0xfe00) == 0xfc00 // ULA fc00::/7
                || (s[0] & 0xffc0) == 0xfe80 // link-local
                || (s[0] == 0x0064 && s[1] == 0xff9b) // NAT64: andar v4 chhupa sakta hai
                || (s[0] == 0x2001 && s[1] == 0x0db8) // documentation
                || s[0] == 0x0100 && s[1] == 0 // discard
                || (s[0] & 0xe000) != 0x2000) // global unicast (2000::/3) ke bahar sab band
        }
    }
}

/* ───────────────────────────── parser ───────────────────────────── */

#[derive(Debug, Clone, PartialEq)]
pub struct SubEvent {
    pub uid: String,
    /// 0 = master; warna is override ki asli (original) shuruaat ka UTC epoch
    pub rid: i64,
    pub title: String,
    pub location: String,
    pub description: String,
    pub start: i64, // UTC epoch (all-day: us din ki UTC aadhi raat)
    pub duration: i64, // seconds
    pub all_day: bool,
    pub tzid: String, // IANA naam ("UTC" bhi)
    pub rrule: String, // "" = ek baar
    pub exdates: Vec<i64>,
    pub cancelled: bool,
}

#[derive(Debug, Default, Clone, PartialEq)]
pub struct Stats {
    pub found: usize,
    pub kept: usize,
    pub recurring: usize,
    pub all_day: usize,
    pub cancelled: usize,
    pub skipped_bad: usize,
    pub skipped_old: usize,
    pub unknown_zone: usize,
    pub floating_as_utc: usize,
    pub rrule_unreadable: usize,
    pub truncated: bool,
}

#[derive(Debug, Default, Clone)]
pub struct Feed {
    pub name: String,
    pub events: Vec<SubEvent>,
    pub stats: Stats,
}

/// RFC 5545 unfold: CRLF/LF + space/tab se shuru agli line pichli ka hissa.
pub fn unfold(text: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for raw in text.split('\n') {
        let line = raw.strip_suffix('\r').unwrap_or(raw);
        if (line.starts_with(' ') || line.starts_with('\t')) && !out.is_empty() {
            out.last_mut().unwrap().push_str(&line[1..]);
        } else {
            out.push(line.to_string());
        }
    }
    out
}

struct Prop {
    name: String,
    params: Vec<(String, String)>,
    value: String,
}

fn parse_line(line: &str) -> Option<Prop> {
    let mut in_q = false;
    let mut idx = None;
    for (i, c) in line.char_indices() {
        if c == '"' {
            in_q = !in_q;
        } else if c == ':' && !in_q {
            idx = Some(i);
            break;
        }
    }
    let idx = idx?;
    if idx == 0 {
        return None;
    }
    let (head, value) = (&line[..idx], &line[idx + 1..]);
    let mut parts = head.split(';');
    let name = parts.next()?.to_ascii_uppercase();
    let params = parts
        .filter_map(|p| p.split_once('=').map(|(k, v)| (k.to_ascii_uppercase(), v.trim_matches('"').to_string())))
        .collect();
    Some(Prop { name, params, value: value.to_string() })
}

impl Prop {
    fn param(&self, k: &str) -> Option<&str> {
        self.params.iter().find(|(n, _)| n == k).map(|(_, v)| v.as_str())
    }
}

fn unescape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut it = s.chars().peekable();
    while let Some(c) = it.next() {
        if c == '\\' {
            match it.next() {
                Some('n') | Some('N') => out.push('\n'),
                Some(x) => out.push(x),
                None => {}
            }
        } else {
            out.push(c);
        }
    }
    out
}

fn clip(s: &str, max: usize) -> String {
    let cleaned: String = s.chars().filter(|c| !c.is_control() || *c == '\n').collect();
    let t = cleaned.trim();
    t.chars().take(max).collect()
}

const WINDOWS_ZONES: &[(&str, &str)] = &[
    ("GMT Standard Time", "Europe/London"), ("Greenwich Standard Time", "Atlantic/Reykjavik"), ("W. Europe Standard Time", "Europe/Berlin"),
    ("Central Europe Standard Time", "Europe/Budapest"), ("Central European Standard Time", "Europe/Warsaw"), ("Romance Standard Time", "Europe/Paris"),
    ("GTB Standard Time", "Europe/Athens"), ("E. Europe Standard Time", "Europe/Chisinau"), ("FLE Standard Time", "Europe/Kiev"),
    ("Russian Standard Time", "Europe/Moscow"), ("Turkey Standard Time", "Europe/Istanbul"), ("Israel Standard Time", "Asia/Jerusalem"),
    ("Arab Standard Time", "Asia/Riyadh"), ("Arabian Standard Time", "Asia/Dubai"), ("Pakistan Standard Time", "Asia/Karachi"),
    ("India Standard Time", "Asia/Kolkata"), ("Bangladesh Standard Time", "Asia/Dhaka"), ("SE Asia Standard Time", "Asia/Bangkok"),
    ("China Standard Time", "Asia/Shanghai"), ("Singapore Standard Time", "Asia/Singapore"), ("Tokyo Standard Time", "Asia/Tokyo"),
    ("Korea Standard Time", "Asia/Seoul"), ("AUS Eastern Standard Time", "Australia/Sydney"), ("E. Australia Standard Time", "Australia/Brisbane"),
    ("New Zealand Standard Time", "Pacific/Auckland"), ("South Africa Standard Time", "Africa/Johannesburg"), ("Egypt Standard Time", "Africa/Cairo"),
    ("W. Central Africa Standard Time", "Africa/Lagos"), ("E. Africa Standard Time", "Africa/Nairobi"), ("Eastern Standard Time", "America/New_York"),
    ("Central Standard Time", "America/Chicago"), ("Mountain Standard Time", "America/Denver"), ("US Mountain Standard Time", "America/Phoenix"),
    ("Pacific Standard Time", "America/Los_Angeles"), ("Alaskan Standard Time", "America/Anchorage"), ("Hawaiian Standard Time", "Pacific/Honolulu"),
    ("Canada Central Standard Time", "America/Regina"), ("Atlantic Standard Time", "America/Halifax"), ("E. South America Standard Time", "America/Sao_Paulo"),
    ("Argentina Standard Time", "America/Argentina/Buenos_Aires"), ("Mexico Standard Time", "America/Mexico_City"), ("UTC", "UTC"),
];

/// TZID -> IANA naam jo is server par mojood ho. None = nahi samjha.
pub fn resolve_zone(tzid: &str) -> Option<String> {
    let t = tzid.trim().trim_start_matches('/');
    if t.is_empty() {
        return None;
    }
    if t.eq_ignore_ascii_case("utc") || t.eq_ignore_ascii_case("z") || t.eq_ignore_ascii_case("etc/utc") {
        return Some("UTC".into());
    }
    let name = WINDOWS_ZONES.iter().find(|(w, _)| w.eq_ignore_ascii_case(t)).map(|(_, i)| (*i).to_string()).unwrap_or_else(|| t.to_string());
    if name == "UTC" {
        return Some(name);
    }
    // asli zone: tzdata se load ho to Zone, warna Fixed (== nahi mila)
    match &*recur::load_tz(&name, 0) {
        Tz::Fixed(_) => None,
        _ => Some(name),
    }
}

struct Dt {
    local_or_utc: i64, // Z ho to UTC epoch; warna "wall clock as if UTC" (zone baad mein lagti hai)
    all_day: bool,
    utc: bool,
    tzid: Option<String>,
}

fn parse_dt(p: &Prop) -> Option<Dt> {
    let v = p.value.trim();
    let b = v.as_bytes();
    if b.len() < 8 || !b[..8].iter().all(|c| c.is_ascii_digit()) {
        return None;
    }
    let n = |a: usize, z: usize| v.get(a..z)?.parse::<i64>().ok();
    let (y, mo, d) = (n(0, 4)?, n(4, 6)? as u32, n(6, 8)? as u32);
    if !(1..=12).contains(&mo) || d < 1 || d > recur::days_in_month(y, mo) || !(1970..=2200).contains(&y) {
        return None;
    }
    let date_only = p.param("VALUE").is_some_and(|x| x.eq_ignore_ascii_case("DATE")) || b.len() == 8;
    let days = cal_core::days_from_civil(y, mo, d);
    if date_only {
        return Some(Dt { local_or_utc: days * 86_400, all_day: true, utc: true, tzid: None });
    }
    if b.len() < 15 || b[8] != b'T' {
        return None;
    }
    let (h, mi, s) = (n(9, 11)?, n(11, 13)?, n(13, 15)?);
    if h > 23 || mi > 59 || s > 60 {
        return None;
    }
    let utc = b.len() >= 16 && b[15] == b'Z';
    Some(Dt { local_or_utc: days * 86_400 + h * 3600 + mi * 60 + s.min(59), all_day: false, utc, tzid: p.param("TZID").map(|x| x.to_string()) })
}

/// ISO-8601 duration ("PT1H30M", "P1D", "P1W") -> seconds
pub fn parse_duration(v: &str) -> Option<i64> {
    let s = v.trim();
    let (neg, s) = match s.strip_prefix('-') {
        Some(r) => (true, r),
        None => (false, s.strip_prefix('+').unwrap_or(s)),
    };
    let s = s.strip_prefix('P')?;
    let (mut total, mut num, mut in_time, mut any) = (0i64, String::new(), false, false);
    for c in s.chars() {
        match c {
            'T' => in_time = true,
            '0'..='9' => num.push(c),
            'W' | 'D' | 'H' | 'M' | 'S' => {
                let n: i64 = num.parse().ok()?;
                num.clear();
                any = true;
                total += n * match (c, in_time) {
                    ('W', _) => 604_800,
                    ('D', _) => 86_400,
                    ('H', true) => 3600,
                    ('M', true) => 60,
                    ('S', true) => 1,
                    _ => return None,
                };
            }
            _ => return None,
        }
    }
    if !num.is_empty() || !any {
        return None;
    }
    Some(if neg { -total } else { total })
}

struct Ctx {
    default_zone: Option<String>,
}

/// Ek Dt ko UTC epoch banana. (epoch, tz_naam, floating_ho, zone_nahi_samjha)
fn to_utc(d: &Dt, ctx: &Ctx) -> (i64, String, bool, bool) {
    if d.all_day || d.utc {
        return (d.local_or_utc, "UTC".into(), false, false);
    }
    let zone = match &d.tzid {
        Some(t) => resolve_zone(t),
        None => ctx.default_zone.clone(),
    };
    match zone {
        Some(z) => {
            let tz = recur::load_tz(&z, 0);
            (tz.local_to_utc(d.local_or_utc), z, d.tzid.is_none(), false)
        }
        None => (d.local_or_utc, "UTC".into(), d.tzid.is_none(), d.tzid.is_some()),
    }
}

fn exdates_of(props: &[Prop], ctx: &Ctx) -> Vec<i64> {
    let mut out = Vec::new();
    for p in props.iter().filter(|p| p.name == "EXDATE") {
        for part in p.value.split(',') {
            let q = Prop { name: "EXDATE".into(), params: p.params.clone(), value: part.to_string() };
            if let Some(d) = parse_dt(&q) {
                out.push(to_utc(&d, ctx).0);
            }
        }
    }
    out.sort_unstable();
    out.dedup();
    out.truncate(500);
    out
}

/// Poori .ics file ko events mein. `now` = UTC epoch (purane ek-baar wale events chhodne ke liye).
pub fn parse_feed(text: &str, now: i64) -> Feed {
    let mut feed = Feed::default();
    let lines = unfold(text);
    let mut ctx = Ctx { default_zone: None };
    let mut cal_name = String::new();
    let mut depth_event: Option<Vec<Prop>> = None;
    let mut seen_calendar = false;
    for line in &lines {
        let up = line.trim();
        if up.eq_ignore_ascii_case("BEGIN:VCALENDAR") {
            seen_calendar = true;
            continue;
        }
        if up.eq_ignore_ascii_case("BEGIN:VEVENT") {
            depth_event = Some(Vec::new());
            continue;
        }
        if up.eq_ignore_ascii_case("END:VEVENT") {
            if let Some(props) = depth_event.take() {
                feed.stats.found += 1;
                if feed.events.len() >= MAX_EVENTS {
                    feed.stats.truncated = true;
                    continue;
                }
                match build_event(&props, &ctx, now, &mut feed.stats) {
                    Some(e) => feed.events.push(e),
                    None => {}
                }
            }
            continue;
        }
        if let Some(ev) = depth_event.as_mut() {
            if ev.len() < 200 {
                if let Some(p) = parse_line(line) {
                    ev.push(p);
                }
            }
            continue;
        }
        if seen_calendar && cal_name.is_empty() {
            if let Some(p) = parse_line(line) {
                match p.name.as_str() {
                    "X-WR-CALNAME" | "NAME" => cal_name = clip(&unescape(&p.value), 80),
                    "X-WR-TIMEZONE" => ctx.default_zone = resolve_zone(&p.value),
                    _ => {}
                }
            }
        } else if let Some(p) = parse_line(line) {
            if p.name == "X-WR-TIMEZONE" {
                ctx.default_zone = resolve_zone(&p.value);
            }
        }
    }
    feed.name = cal_name;
    feed.stats.kept = feed.events.len();
    feed
}

fn build_event(props: &[Prop], ctx: &Ctx, now: i64, st: &mut Stats) -> Option<SubEvent> {
    let get = |n: &str| props.iter().find(|p| p.name == n);
    let uid = get("UID").map(|p| clip(&p.value, 200)).unwrap_or_default();
    if uid.is_empty() {
        st.skipped_bad += 1;
        return None;
    }
    let Some(ds) = get("DTSTART").and_then(parse_dt) else {
        st.skipped_bad += 1;
        return None;
    };
    let (start, tzid, floating, unknown) = to_utc(&ds, ctx);
    if floating && !ds.all_day {
        st.floating_as_utc += 1;
    }
    if unknown {
        st.unknown_zone += 1;
    }
    let duration = if let Some(de) = get("DTEND").and_then(parse_dt) {
        let (end, ..) = to_utc(&de, ctx);
        (end - start).max(0)
    } else if let Some(d) = get("DURATION").and_then(|p| parse_duration(&p.value)) {
        d.max(0)
    } else if ds.all_day {
        86_400
    } else {
        0
    };
    let duration = duration.min(366 * 86_400);
    let rid = match get("RECURRENCE-ID").and_then(parse_dt) {
        Some(r) => to_utc(&r, ctx).0.max(1),
        None => 0,
    };
    let cancelled = get("STATUS").is_some_and(|p| p.value.trim().eq_ignore_ascii_case("CANCELLED"));
    let mut rrule = String::new();
    if rid == 0 {
        if let Some(r) = get("RRULE") {
            match recur::parse(r.value.trim()) {
                Ok(_) => rrule = r.value.trim().to_string(),
                Err(_) => st.rrule_unreadable += 1, // sirf pehli baar dikhega
            }
        }
    }
    if rrule.is_empty() && rid == 0 && start + duration < now - OLD_DAYS * 86_400 {
        st.skipped_old += 1;
        return None;
    }
    if !rrule.is_empty() {
        st.recurring += 1;
    }
    if ds.all_day {
        st.all_day += 1;
    }
    if cancelled {
        st.cancelled += 1;
    }
    Some(SubEvent {
        uid,
        rid,
        title: clip(&unescape(&get("SUMMARY").map(|p| p.value.clone()).unwrap_or_default()), 200),
        location: clip(&unescape(&get("LOCATION").map(|p| p.value.clone()).unwrap_or_default()), 200),
        description: clip(&unescape(&get("DESCRIPTION").map(|p| p.value.clone()).unwrap_or_default()), 1500),
        start,
        duration,
        all_day: ds.all_day,
        tzid,
        rrule,
        exdates: exdates_of(props, ctx),
        cancelled,
    })
}

/* ───────────────────────────── occurrences ───────────────────────────── */

#[derive(Debug, Clone, PartialEq)]
pub struct Occ {
    pub index: usize, // events slice ka index (naam/rang/title wahin se)
    pub start: i64,
    pub end: i64,
}

pub const MAX_OCC: usize = 3000;

/// [from, to) ke andar ke asli occurrences, sorted. Overrides master ki jagah leti hain; cancelled gayab.
pub fn occurrences(events: &[SubEvent], from: i64, to: i64) -> Vec<Occ> {
    let mut out: Vec<Occ> = Vec::new();
    let overlaps = |s: i64, d: i64| s < to && (s + d > from || (d == 0 && s >= from));
    for (i, e) in events.iter().enumerate() {
        if e.rid != 0 {
            // override: sirf apni nayi jagah par
            if !e.cancelled && overlaps(e.start, e.duration) {
                out.push(Occ { index: i, start: e.start, end: e.start + e.duration });
            }
            continue;
        }
        if e.cancelled && e.rrule.is_empty() {
            continue;
        }
        if e.rrule.is_empty() {
            if !e.cancelled && overlaps(e.start, e.duration) {
                out.push(Occ { index: i, start: e.start, end: e.start + e.duration });
            }
            continue;
        }
        let Ok(rule) = recur::parse(&e.rrule) else {
            if overlaps(e.start, e.duration) {
                out.push(Occ { index: i, start: e.start, end: e.start + e.duration });
            }
            continue;
        };
        let tz = if e.all_day { std::sync::Arc::new(Tz::Fixed(0)) } else { recur::load_tz(&e.tzid, 0) };
        let overridden: Vec<i64> = events.iter().filter(|o| o.uid == e.uid && o.rid != 0).map(|o| o.rid).collect();
        let mut ex = e.exdates.clone();
        ex.extend(overridden);
        for s in recur::expand(&rule, e.start, e.duration, &tz, &ex, from, to) {
            if !e.cancelled {
                out.push(Occ { index: i, start: s, end: s + e.duration });
            }
        }
        if out.len() > MAX_OCC {
            break;
        }
    }
    out.sort_by_key(|o| (o.start, o.index));
    out.truncate(MAX_OCC);
    out
}

/* ───────────────────────────── refresh ka hisaab ───────────────────────────── */

/// Fail ke baad kitni der baad dobara koshish: refresh_minutes * 2^min(fails,5), din se zyada nahi.
pub fn backoff_minutes(refresh_minutes: i64, fails: i64) -> i64 {
    let r = refresh_minutes.clamp(15, 1440);
    (r << fails.clamp(0, 5)).min(1440)
}

/// HTTP jawab ka khulasa -> kya karna hai
#[derive(Debug, PartialEq)]
pub enum FetchPlan {
    Apply,
    NotModified,
    Redirect,
    Fail(&'static str),
}

pub fn plan_for_status(status: u16) -> FetchPlan {
    match status {
        200 => FetchPlan::Apply,
        304 => FetchPlan::NotModified,
        301 | 302 | 303 | 307 | 308 => FetchPlan::Redirect,
        401 | 403 => FetchPlan::Fail("feed_forbidden"),
        404 | 410 => FetchPlan::Fail("feed_not_found"),
        429 => FetchPlan::Fail("feed_rate_limited"),
        500..=599 => FetchPlan::Fail("feed_server_error"),
        _ => FetchPlan::Fail("feed_bad_status"),
    }
}

/// Body sach mein calendar hai? (HTML login page / JSON na ho)
pub fn looks_like_ics(body: &str) -> bool {
    let head: String = body.trim_start_matches('\u{feff}').trim_start().chars().take(64).collect();
    head.to_ascii_uppercase().starts_with("BEGIN:VCALENDAR")
}


/// Error code -> (HTTP status, insaan ke liye wajah). Web isi text ko dikhata hai.
pub fn error_text(code: &str) -> (u16, &'static str) {
    match code {
        "url_invalid" => (400, "That does not look like a calendar link."),
        "url_not_https" => (400, "Only secure (https:// or webcal://) calendar links can be added."),
        "url_port" => (400, "Calendar links must use the standard secure port."),
        "url_host" => (400, "That address is not a public website, so it cannot be used as a calendar link."),
        "bad_input" => (400, "Something in that request was not valid."),
        "already_added" => (409, "You already follow this calendar."),
        "limit_reached" => (409, "You can follow up to 10 outside calendars. Remove one first."),
        "not_found" => (404, "That calendar was not found."),
        "feed_blocked_address" => (422, "That link points to a private or internal address, so it was not fetched."),
        "feed_dns" => (422, "That website could not be found."),
        "feed_unreachable" => (502, "The calendar website did not answer in time."),
        "feed_too_big" => (422, "That calendar file is too large (limit 5 MB)."),
        "feed_not_calendar" => (422, "That link did not return a calendar file. Use the calendar's secret iCal / ICS address."),
        "feed_too_many_redirects" => (422, "That link redirects too many times."),
        "feed_forbidden" => (422, "The calendar website refused access. The secret link may have been reset."),
        "feed_not_found" => (422, "The calendar website says this calendar no longer exists."),
        "feed_rate_limited" => (429, "The calendar website asked us to slow down. It will retry later."),
        "feed_server_error" => (502, "The calendar website had an error. It will retry later."),
        "feed_bad_status" => (422, "The calendar website gave an unexpected answer."),
        "too_many_events" => (422, "That calendar has too many events."),
        "refresh_too_soon" => (429, "This calendar was refreshed a moment ago. Try again in a minute."),
        "range_invalid" => (400, "Choose a time range of up to 100 days."),
        "sql_missing" => (501, "Calendar subscriptions are not set up on this server yet."),
        _ => (500, "Something went wrong with that calendar."),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ev(uid: &str, rid: i64, start: i64, dur: i64, rrule: &str) -> SubEvent {
        SubEvent { uid: uid.into(), rid, title: uid.into(), location: String::new(), description: String::new(), start, duration: dur, all_day: false, tzid: "UTC".into(), rrule: rrule.into(), exdates: vec![], cancelled: false }
    }

    #[test]
    fn url_rules() {
        assert_eq!(normalize_url("webcal://cal.example.com/a.ics").unwrap(), "https://cal.example.com/a.ics");
        assert_eq!(normalize_url("WEBCALS://Cal.Example.com/a.ics?x=1").unwrap(), "https://cal.example.com/a.ics?x=1");
        assert_eq!(normalize_url(" https://calendar.google.com/calendar/ical/x/basic.ics ").unwrap(), "https://calendar.google.com/calendar/ical/x/basic.ics");
        assert_eq!(normalize_url("https://cal.example.com:443/a.ics").unwrap(), "https://cal.example.com:443/a.ics");
        for (bad, why) in [
            ("http://cal.example.com/a.ics", "url_not_https"),
            ("ftp://x.example.com/a", "url_not_https"),
            ("https://user:pw@cal.example.com/a.ics", "url_invalid"),
            ("https://cal.example.com:8080/a.ics", "url_port"),
            ("https://localhost/a.ics", "url_host"),
            ("https://intranet/a.ics", "url_host"),
            ("https://printer.local/a.ics", "url_host"),
            ("https://127.0.0.1/a.ics", "url_host"),
            ("https://169.254.169.254/latest/meta-data", "url_host"),
            ("https://10.0.0.5/a.ics", "url_host"),
            ("https://[::1]/a.ics", "url_host"),
            ("", "url_invalid"),
            ("https://", "url_invalid"),
            ("https://a b.example.com/", "url_invalid"),
        ] {
            assert_eq!(normalize_url(bad), Err(why), "{bad}");
        }
        assert_eq!(normalize_url(&format!("https://a.example.com/{}", "x".repeat(2100))), Err("url_invalid"));
        assert_eq!(normalize_url("https://a.example.com/a.ics\r\nHost: evil"), Err("url_invalid"));
    }

    #[test]
    fn ssrf_ip_policy() {
        let ok = |s: &str| ip_allowed(s.parse().unwrap());
        for pub_ip in ["8.8.8.8", "1.1.1.1", "142.250.80.46", "2606:4700:4700::1111", "2a00:1450:4001:81b::200e"] {
            assert!(ok(pub_ip), "{pub_ip}");
        }
        for bad in [
            "127.0.0.1", "10.1.2.3", "172.16.0.1", "172.31.255.255", "192.168.1.1", "169.254.169.254", "0.0.0.0", "100.64.0.1", "100.127.255.255",
            "224.0.0.1", "255.255.255.255", "198.18.0.1", "192.0.0.5", "240.0.0.1", "192.0.2.4", "203.0.113.9", "::1", "::", "fe80::1", "fc00::1", "fd12::1",
            "ff02::1", "::ffff:127.0.0.1", "::ffff:10.0.0.1", "::ffff:169.254.169.254", "64:ff9b::7f00:1", "2001:db8::1",
        ] {
            assert!(!ok(bad), "{bad}");
        }
        assert!(ok("100.63.255.255") && ok("100.128.0.1"), "CGNAT range ke bahar wale theek");
        assert!(ok("172.32.0.1") && ok("172.15.255.255"));
    }

    #[test]
    fn unfold_and_unescape() {
        let l = unfold("SUMMARY:Hello\r\n  world\r\nX:1\r\n");
        assert_eq!(l[0], "SUMMARY:Hello world");
        assert_eq!(unescape(r"a\, b\; c\nd\\e"), "a, b; c\nd\\e");
    }

    #[test]
    fn durations() {
        assert_eq!(parse_duration("PT1H30M"), Some(5400));
        assert_eq!(parse_duration("P1D"), Some(86_400));
        assert_eq!(parse_duration("P1W"), Some(604_800));
        assert_eq!(parse_duration("-PT15M"), Some(-900));
        assert_eq!(parse_duration("P1DT2H"), Some(93_600));
        for bad in ["", "P", "PT", "1H", "PT1X", "P1H", "PTM"] {
            assert_eq!(parse_duration(bad), None, "{bad}");
        }
    }

    const NOW: i64 = 1_792_000_000; // ~ Oct 2026

    #[test]
    fn simple_utc_event() {
        let f = parse_feed("BEGIN:VCALENDAR\r\nX-WR-CALNAME:Cricket\\, PSL\r\nBEGIN:VEVENT\r\nUID:a1\r\nDTSTART:20261101T150000Z\r\nDTEND:20261101T163000Z\r\nSUMMARY:Match\\, day 1\r\nLOCATION:Karachi\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n", NOW);
        assert_eq!(f.name, "Cricket, PSL");
        assert_eq!(f.events.len(), 1);
        let e = &f.events[0];
        assert_eq!((e.uid.as_str(), e.title.as_str(), e.location.as_str()), ("a1", "Match, day 1", "Karachi"));
        assert_eq!(e.duration, 5400);
        assert_eq!(cal_core::fmt_rfc3339(e.start), "2026-11-01T15:00:00Z");
        assert_eq!(f.stats.found, 1);
        assert_eq!(f.stats.kept, 1);
    }

    #[test]
    fn tzid_iana_and_windows() {
        if std::fs::metadata("/usr/share/zoneinfo/Asia/Karachi").is_err() {
            return; // tzdata nahi: server par hota hai
        }
        let mk = |tz: &str| format!("BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:z\nDTSTART;TZID={tz}:20261102T090000\nDTEND;TZID={tz}:20261102T100000\nSUMMARY:S\nEND:VEVENT\nEND:VCALENDAR\n");
        let k = parse_feed(&mk("Asia/Karachi"), NOW);
        assert_eq!(cal_core::fmt_rfc3339(k.events[0].start), "2026-11-02T04:00:00Z");
        let w = parse_feed(&mk("Pakistan Standard Time"), NOW);
        assert_eq!(w.events[0].start, k.events[0].start);
        let ny = parse_feed(&mk("America/New_York"), NOW);
        assert_eq!(cal_core::fmt_rfc3339(ny.events[0].start), "2026-11-02T14:00:00Z"); // EST (Nov 1 ke baad)
        let bad = parse_feed(&mk("Mars/Olympus"), NOW);
        assert_eq!(bad.stats.unknown_zone, 1);
        assert_eq!(bad.events.len(), 1, "ajeeb zone par bhi event rakha, UTC maana, ginti batayi");
    }

    #[test]
    fn floating_time_and_calendar_zone() {
        let f = parse_feed("BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:f\nDTSTART:20261105T100000\nDTEND:20261105T110000\nSUMMARY:F\nEND:VEVENT\nEND:VCALENDAR\n", NOW);
        assert_eq!(f.stats.floating_as_utc, 1);
        assert_eq!(cal_core::fmt_rfc3339(f.events[0].start), "2026-11-05T10:00:00Z");
        if std::fs::metadata("/usr/share/zoneinfo/Asia/Karachi").is_ok() {
            let g = parse_feed("BEGIN:VCALENDAR\nX-WR-TIMEZONE:Asia/Karachi\nBEGIN:VEVENT\nUID:f\nDTSTART:20261105T100000\nDTEND:20261105T110000\nSUMMARY:F\nEND:VEVENT\nEND:VCALENDAR\n", NOW);
            assert_eq!(cal_core::fmt_rfc3339(g.events[0].start), "2026-11-05T05:00:00Z");
        }
    }

    #[test]
    fn all_day_events() {
        let f = parse_feed("BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:d\nDTSTART;VALUE=DATE:20261201\nDTEND;VALUE=DATE:20261203\nSUMMARY:Holiday\nEND:VEVENT\nBEGIN:VEVENT\nUID:d2\nDTSTART;VALUE=DATE:20261210\nSUMMARY:One day\nEND:VEVENT\nEND:VCALENDAR\n", NOW);
        assert!(f.events[0].all_day);
        assert_eq!(f.events[0].duration, 2 * 86_400);
        assert_eq!(f.events[1].duration, 86_400);
        assert_eq!(f.stats.all_day, 2);
    }

    #[test]
    fn duration_property_and_zero_length() {
        let f = parse_feed("BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:a\nDTSTART:20261110T100000Z\nDURATION:PT45M\nSUMMARY:A\nEND:VEVENT\nBEGIN:VEVENT\nUID:b\nDTSTART:20261110T100000Z\nSUMMARY:B\nEND:VEVENT\nEND:VCALENDAR\n", NOW);
        assert_eq!(f.events[0].duration, 2700);
        assert_eq!(f.events[1].duration, 0);
    }

    #[test]
    fn broken_events_are_skipped_not_fatal() {
        let f = parse_feed("BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\nDTSTART:garbage\nSUMMARY:bad\nEND:VEVENT\nBEGIN:VEVENT\nSUMMARY:no uid\nDTSTART:20261110T100000Z\nEND:VEVENT\nBEGIN:VEVENT\nUID:ok\nDTSTART:20261110T100000Z\nSUMMARY:fine\nEND:VEVENT\nBEGIN:VEVENT\nUID:feb\nDTSTART:20261331T100000Z\nEND:VEVENT\nEND:VCALENDAR\n", NOW);
        assert_eq!(f.events.len(), 1);
        assert_eq!(f.stats.found, 4);
        assert_eq!(f.stats.skipped_bad, 3);
    }

    #[test]
    fn old_single_events_dropped_recurring_kept() {
        let f = parse_feed("BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:old\nDTSTART:20200101T100000Z\nDTEND:20200101T110000Z\nEND:VEVENT\nBEGIN:VEVENT\nUID:rec\nDTSTART:20200101T100000Z\nDTEND:20200101T110000Z\nRRULE:FREQ=WEEKLY\nEND:VEVENT\nEND:VCALENDAR\n", NOW);
        assert_eq!(f.events.len(), 1);
        assert_eq!(f.events[0].uid, "rec");
        assert_eq!(f.stats.skipped_old, 1);
    }

    #[test]
    fn caps_and_text_limits() {
        let mut s = String::from("BEGIN:VCALENDAR\n");
        for i in 0..2100 {
            s.push_str(&format!("BEGIN:VEVENT\nUID:e{i}\nDTSTART:20261110T100000Z\nSUMMARY:{}\nEND:VEVENT\n", "x".repeat(500)));
        }
        let f = parse_feed(&s, NOW);
        assert_eq!(f.events.len(), MAX_EVENTS);
        assert!(f.stats.truncated);
        assert_eq!(f.events[0].title.chars().count(), 200);
    }

    #[test]
    fn control_chars_are_stripped() {
        let f = parse_feed("BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:c\nDTSTART:20261110T100000Z\nSUMMARY:a\u{0}b\u{7}c\u{202E}d\nEND:VEVENT\nEND:VCALENDAR\n", NOW);
        assert!(!f.events[0].title.contains('\u{0}') && !f.events[0].title.contains('\u{7}'));
    }

    #[test]
    fn weekly_series_with_exdate_override_and_cancel() {
        // har Somwar 10:00 UTC; 9 Nov cancel (EXDATE), 16 Nov ko 11:00 par shift (override), 23 Nov STATUS:CANCELLED override
        let ics = "BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:w\nDTSTART:20261102T100000Z\nDTEND:20261102T110000Z\nRRULE:FREQ=WEEKLY;BYDAY=MO\nEXDATE:20261109T100000Z\nSUMMARY:Standup\nEND:VEVENT\n\
BEGIN:VEVENT\nUID:w\nRECURRENCE-ID:20261116T100000Z\nDTSTART:20261116T110000Z\nDTEND:20261116T120000Z\nSUMMARY:Standup (moved)\nEND:VEVENT\n\
BEGIN:VEVENT\nUID:w\nRECURRENCE-ID:20261123T100000Z\nDTSTART:20261123T100000Z\nDTEND:20261123T110000Z\nSTATUS:CANCELLED\nSUMMARY:x\nEND:VEVENT\nEND:VCALENDAR\n";
        let f = parse_feed(ics, NOW);
        assert_eq!(f.events.len(), 3);
        let from = cal_core::parse_ts("2026-11-01T00:00:00Z").unwrap();
        let to = cal_core::parse_ts("2026-12-01T00:00:00Z").unwrap();
        let occ = occurrences(&f.events, from, to);
        let got: Vec<String> = occ.iter().map(|o| format!("{}|{}", cal_core::fmt_rfc3339(o.start), f.events[o.index].title)).collect();
        assert_eq!(
            got,
            vec![
                "2026-11-02T10:00:00Z|Standup",
                "2026-11-16T11:00:00Z|Standup (moved)",
                "2026-11-30T10:00:00Z|Standup",
            ],
            "9 Nov EXDATE, 16 Nov shift, 23 Nov cancel"
        );
    }

    #[test]
    fn range_filter_for_single_events() {
        let evs = vec![ev("a", 0, 1000, 100, ""), ev("b", 0, 5000, 100, ""), ev("c", 0, 900, 100, "")];
        assert_eq!(occurrences(&evs, 1000, 2000).iter().map(|o| o.index).collect::<Vec<_>>(), vec![0]);
        assert_eq!(occurrences(&evs, 950, 1001).iter().map(|o| o.index).collect::<Vec<_>>(), vec![2, 0], "chalta hua event bhi aata hai");
        assert!(occurrences(&evs, 2000, 4000).is_empty());
    }

    #[test]
    fn cancelled_single_event_hidden() {
        let mut e = ev("a", 0, 1000, 100, "");
        e.cancelled = true;
        assert!(occurrences(&[e], 0, 5000).is_empty());
    }

    #[test]
    fn unreadable_rrule_degrades_to_first_occurrence() {
        let f = parse_feed("BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:r\nDTSTART:20261110T100000Z\nDTEND:20261110T110000Z\nRRULE:FREQ=SECONDLY\nEND:VEVENT\nEND:VCALENDAR\n", NOW);
        assert_eq!(f.stats.rrule_unreadable, 1);
        assert_eq!(f.events[0].rrule, "");
        assert_eq!(occurrences(&f.events, 0, i64::MAX / 4).len(), 1);
    }

    #[test]
    fn backoff_grows_and_caps() {
        assert_eq!(backoff_minutes(60, 0), 60);
        assert_eq!(backoff_minutes(60, 1), 120);
        assert_eq!(backoff_minutes(60, 3), 480);
        assert_eq!(backoff_minutes(60, 9), 1440);
        assert_eq!(backoff_minutes(1, 0), 15, "15 minute se kam nahi");
        assert_eq!(backoff_minutes(99_999, 0), 1440);
    }

    #[test]
    fn status_plans() {
        assert_eq!(plan_for_status(200), FetchPlan::Apply);
        assert_eq!(plan_for_status(304), FetchPlan::NotModified);
        assert_eq!(plan_for_status(301), FetchPlan::Redirect);
        assert_eq!(plan_for_status(404), FetchPlan::Fail("feed_not_found"));
        assert_eq!(plan_for_status(403), FetchPlan::Fail("feed_forbidden"));
        assert_eq!(plan_for_status(503), FetchPlan::Fail("feed_server_error"));
        assert_eq!(plan_for_status(418), FetchPlan::Fail("feed_bad_status"));
    }

    #[test]
    fn every_error_has_text() {
        for c in ["url_invalid", "url_not_https", "url_port", "url_host", "already_added", "limit_reached", "not_found", "feed_blocked_address", "feed_dns", "feed_unreachable", "feed_too_big", "feed_not_calendar", "feed_forbidden", "feed_server_error", "range_invalid"] {
            let (s, m) = error_text(c);
            assert!((400..600).contains(&s) && !m.is_empty() && s != 500, "{c}");
        }
        assert_eq!(error_text("zzz").0, 500);
    }

    #[test]
    fn html_page_is_not_a_calendar() {
        assert!(looks_like_ics("BEGIN:VCALENDAR\r\nVERSION:2.0"));
        assert!(looks_like_ics("\u{feff}  begin:vcalendar\n"));
        assert!(!looks_like_ics("<!doctype html><html>Please sign in"));
        assert!(!looks_like_ics("{\"error\":1}"));
        assert!(!looks_like_ics(""));
    }

    #[test]
    fn weird_input_never_panics() {
        for s in ["", "BEGIN:VEVENT", "END:VEVENT\nEND:VEVENT", "BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\n", "::::\n;;;;\n", "BEGIN:VEVENT\nDTSTART:\u{1F600}\nEND:VEVENT"] {
            let _ = parse_feed(s, NOW);
        }
        let junk: String = (0..5000).map(|i| char::from_u32(32 + (i * 7919) % 90).unwrap()).collect();
        let _ = parse_feed(&junk, NOW);
    }
}
