//! dav_core — CalDAV (#6, phase C1 = read-only) ka pure hissa. Koi I/O nahi, koi crate nahi: `rustc --edition 2024 --test dav_core.rs`.
//!
//! Kya yahan hai: HTTP Basic + app-password shape, URL map, PROPFIND/REPORT request ki tolerant parsing, multistatus XML banana,
//! etag/getlastmodified. Kya NAHI: database, hashing (sha2 glue mein), iCalendar banana (cal_core::build_ics wahi use hota hai).
//! Sach ke qaide: jo method hum nahi karte (PUT/DELETE/MKCOL/PROPPATCH) un par 405 — jhoota success kabhi nahi.

pub const MAX_BODY: usize = 64 * 1024;
pub const ALLOWED: &str = "OPTIONS, PROPFIND, REPORT, GET, HEAD";
pub const DAV_HEADER: &str = "1, calendar-access";

/* ------------------------------------------------------------------ auth */

fn b64_val(c: u8) -> Option<u8> {
    match c {
        b'A'..=b'Z' => Some(c - b'A'),
        b'a'..=b'z' => Some(c - b'a' + 26),
        b'0'..=b'9' => Some(c - b'0' + 52),
        b'+' => Some(62),
        b'/' => Some(63),
        _ => None,
    }
}

pub fn b64_decode(s: &str) -> Option<Vec<u8>> {
    let t: Vec<u8> = s.bytes().filter(|c| !c.is_ascii_whitespace()).collect();
    let t: &[u8] = {
        let mut n = t.len();
        while n > 0 && t[n - 1] == b'=' {
            n -= 1;
        }
        &t[..n]
    };
    if t.len() % 4 == 1 {
        return None;
    }
    let mut out = Vec::with_capacity(t.len() * 3 / 4);
    let (mut acc, mut bits) = (0u32, 0u32);
    for &c in t {
        acc = (acc << 6) | b64_val(c)? as u32;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push((acc >> bits) as u8);
            acc &= (1 << bits) - 1;
        }
    }
    Some(out)
}

/// `Authorization: Basic base64(user:password)` -> (email in lower case, password). Bahut lamba/ghalat shape = None.
pub fn parse_basic(h: &str) -> Option<(String, String)> {
    let h = h.trim();
    let rest = h.strip_prefix("Basic ").or_else(|| h.strip_prefix("basic "))?;
    if rest.len() > 400 {
        return None;
    }
    let raw = String::from_utf8(b64_decode(rest)?).ok()?;
    let (u, p) = raw.split_once(':')?;
    let u = u.trim().to_lowercase();
    if u.is_empty() || u.len() > 254 || p.is_empty() || p.len() > 120 {
        return None;
    }
    Some((u, p.to_string()))
}

const B32: &[u8; 32] = b"abcdefghijklmnopqrstuvwxyz234567";

/// 30 akshar a-z2-7 (10 token_id + 20 secret = 150 bit). Dashes/spaces/capital chalte hain (phone par type karte waqt).
pub fn split_app_password(pw: &str) -> Option<(String, String)> {
    let s: String = pw.chars().filter(|c| *c != '-' && !c.is_whitespace()).map(|c| c.to_ascii_lowercase()).collect();
    if s.len() != 30 || !s.bytes().all(|c| B32.contains(&c)) {
        return None;
    }
    Some((s[..10].to_string(), s[10..].to_string()))
}

/// 19 random bytes (152 bit) -> 30 base32 akshar -> (token_id, secret).
pub fn app_password_from_bytes(b: &[u8; 19]) -> (String, String) {
    let (mut acc, mut bits) = (0u32, 0u32);
    let mut out = String::with_capacity(30);
    for &x in b.iter() {
        acc = (acc << 8) | x as u32;
        bits += 8;
        while bits >= 5 && out.len() < 30 {
            bits -= 5;
            out.push(B32[((acc >> bits) & 31) as usize] as char);
        }
        acc &= (1 << bits) - 1;
    }
    (out[..10].to_string(), out[10..].to_string())
}

/// Dikhane ki shakal: paanch-paanch ke 6 group.
pub fn display_app_password(token_id: &str, secret: &str) -> String {
    let all = format!("{token_id}{secret}");
    all.as_bytes().chunks(5).map(|c| String::from_utf8_lossy(c).to_string()).collect::<Vec<_>>().join("-")
}

pub fn ct_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut d = 0u8;
    for (x, y) in a.iter().zip(b.iter()) {
        d |= x ^ y;
    }
    d == 0
}

/* ---------------------------------------------------------------- routes */

#[derive(Debug, PartialEq, Eq)]
pub enum Route {
    Root,
    Principal,
    Home,
    Calendar(String),
    Event(String, String),
    NotFound,
}

pub fn calendar_key_ok(k: &str) -> bool {
    !k.is_empty() && k.len() <= 24 && k.bytes().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'_' || c == b'-')
}

pub fn uuid_ok(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 36 && b.iter().enumerate().all(|(i, c)| if [8, 13, 18, 23].contains(&i) { *c == b'-' } else { c.is_ascii_hexdigit() })
}

/// `/dav/...` raasta. Khali segment, `..`, ya ghalat shape = NotFound (kabhi panic nahi).
pub fn parse_route(path: &str) -> Route {
    let p = path.split('?').next().unwrap_or("");
    let rest = match p.strip_prefix("/dav") {
        Some(r) => r,
        None => return Route::NotFound,
    };
    let segs: Vec<&str> = rest.split('/').filter(|s| !s.is_empty()).collect();
    match segs.as_slice() {
        [] => Route::Root,
        ["p"] => Route::Principal,
        ["p", "home"] => Route::Home,
        ["c", k] if calendar_key_ok(k) => Route::Calendar((*k).to_string()),
        ["c", k, f] if calendar_key_ok(k) => match f.strip_suffix(".ics") {
            Some(id) if uuid_ok(id) => Route::Event((*k).to_string(), id.to_string()),
            _ => Route::NotFound,
        },
        _ => Route::NotFound,
    }
}

pub fn href_calendar(k: &str) -> String {
    format!("/dav/c/{k}/")
}
pub fn href_event(k: &str, id: &str) -> String {
    format!("/dav/c/{k}/{id}.ics")
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Depth {
    Zero,
    One,
    Infinity,
}

pub fn depth_of(h: Option<&str>) -> Depth {
    match h.map(|s| s.trim()) {
        Some("0") => Depth::Zero,
        Some("1") => Depth::One,
        Some(s) if s.eq_ignore_ascii_case("infinity") => Depth::Infinity,
        _ => Depth::Infinity, // RFC 4918: header na ho to infinity — hum 403 dete hain jahan bharee ho
    }
}

/* -------------------------------------------------------------- xml parse */

#[derive(Debug, PartialEq, Eq)]
struct Tag {
    local: String,
    close: bool,
    selfclose: bool,
    attrs: String,
    end: usize, // index just after '>'
}

fn next_tag(s: &str, from: usize) -> Option<(Tag, usize)> {
    let b = s.as_bytes();
    let mut i = from;
    while i < b.len() {
        if b[i] == b'<' {
            if s[i..].starts_with("<!--") {
                i = s[i..].find("-->").map(|k| i + k + 3)?;
                continue;
            }
            if s[i..].starts_with("<?") || s[i..].starts_with("<!") {
                i = s[i..].find('>').map(|k| i + k + 1)?;
                continue;
            }
            let start = i;
            let close_at = s[i..].find('>')? + i;
            let inner = &s[i + 1..close_at];
            let close = inner.starts_with('/');
            let selfclose = inner.ends_with('/');
            let body = inner.trim_start_matches('/').trim_end_matches('/');
            let (name, attrs) = match body.find(|c: char| c.is_whitespace()) {
                Some(k) => (&body[..k], body[k..].trim()),
                None => (body, ""),
            };
            let local = name.rsplit(':').next().unwrap_or("").to_ascii_lowercase();
            return Some((Tag { local, close, selfclose, attrs: attrs.to_string(), end: close_at + 1 }, start));
        }
        i += 1;
    }
    None
}

pub fn unesc_xml(s: &str) -> String {
    s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'").replace("&amp;", "&")
}

pub fn esc_xml(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 8);
    for c in s.chars() {
        match c {
            '&' => o.push_str("&amp;"),
            '<' => o.push_str("&lt;"),
            '>' => o.push_str("&gt;"),
            '"' => o.push_str("&quot;"),
            c if (c as u32) < 0x20 && c != '\n' && c != '\t' && c != '\r' => {} // XML 1.0 mein allowed nahi
            c => o.push(c),
        }
    }
    o
}

#[derive(Debug, Default, PartialEq, Eq)]
pub struct PropFind {
    pub all: bool,
    pub names_only: bool,
    pub props: Vec<String>,
}

/// Khali body = allprop. `<prop>` ke seedhe bachche (local naam, chhote akshar). Ghalat/adhoora xml = jo mila wohi (panic nahi).
pub fn parse_propfind(body: &str) -> PropFind {
    let mut pf = PropFind::default();
    if body.trim().is_empty() || body.len() > MAX_BODY {
        pf.all = body.len() <= MAX_BODY;
        return pf;
    }
    let (mut depth_in_prop, mut in_prop, mut pos) = (0i32, false, 0usize);
    while let Some((t, _)) = next_tag(body, pos) {
        pos = t.end;
        match t.local.as_str() {
            "allprop" if !t.close => pf.all = true,
            "propname" if !t.close => pf.names_only = true,
            "prop" if !in_prop && !t.close && !t.selfclose => in_prop = true,
            "prop" if in_prop && t.close && depth_in_prop == 0 => in_prop = false,
            name if in_prop => {
                if t.close {
                    depth_in_prop -= 1;
                } else {
                    if depth_in_prop == 0 && !pf.props.iter().any(|p| p == name) && pf.props.len() < 64 {
                        pf.props.push(name.to_string());
                    }
                    if !t.selfclose {
                        depth_in_prop += 1;
                    }
                }
            }
            _ => {}
        }
    }
    if pf.props.is_empty() && !pf.names_only {
        pf.all = true;
    }
    pf
}

#[derive(Debug, PartialEq, Eq)]
pub enum Report {
    Query { from: Option<i64>, to: Option<i64> },
    Multiget { hrefs: Vec<String> },
    Unsupported(String),
}

pub fn parse_ics_utc(s: &str) -> Option<i64> {
    let b = s.trim().as_bytes();
    if b.len() != 16 || b[8] != b'T' || b[15] != b'Z' || !b[..8].iter().chain(b[9..15].iter()).all(|c| c.is_ascii_digit()) {
        return None;
    }
    let n = |a: usize, z: usize| -> i64 { std::str::from_utf8(&b[a..z]).unwrap().parse().unwrap() };
    let (y, m, d, hh, mm, ss) = (n(0, 4), n(4, 6), n(6, 8), n(9, 11), n(11, 13), n(13, 15));
    if !(1970..=2100).contains(&y) || !(1..=12).contains(&m) || !(1..=31).contains(&d) || hh > 23 || mm > 59 || ss > 60 {
        return None;
    }
    // days from civil (Howard Hinnant) — Feb 30 jaisi tareekh wapas date mein badli to reject
    let y2 = if m <= 2 { y - 1 } else { y };
    let era = y2.div_euclid(400);
    let yoe = y2 - era * 400;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146097 + doe - 719468;
    let (cy, cm, cd) = civil_from_days(days);
    if (cy, cm, cd) != (y, m, d) {
        return None;
    }
    Some(days * 86400 + hh * 3600 + mm * 60 + ss.min(59))
}

pub fn civil_from_days(z: i64) -> (i64, i64, i64) {
    let z = z + 719468;
    let era = z.div_euclid(146097);
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    (if m <= 2 { y + 1 } else { y }, m, d)
}

fn attr_of(attrs: &str, name: &str) -> Option<String> {
    let key = format!("{name}=");
    let i = attrs.find(&key)?;
    let rest = &attrs[i + key.len()..];
    let q = rest.chars().next()?;
    if q != '"' && q != '\'' {
        return None;
    }
    let end = rest[1..].find(q)?;
    Some(rest[1..1 + end].to_string())
}

/// REPORT: calendar-query (time-range start/end) ya calendar-multiget (href list). sync-collection waghera = Unsupported (C2).
pub fn parse_report(body: &str) -> Report {
    if body.len() > MAX_BODY {
        return Report::Unsupported("body too large".into());
    }
    let mut pos = 0usize;
    let mut kind = String::new();
    let (mut from, mut to) = (None, None);
    let mut hrefs: Vec<String> = Vec::new();
    while let Some((t, _)) = next_tag(body, pos) {
        pos = t.end;
        if kind.is_empty() && !t.close {
            kind = t.local.clone();
        }
        match t.local.as_str() {
            "time-range" if !t.close => {
                from = attr_of(&t.attrs, "start").and_then(|s| parse_ics_utc(&s));
                to = attr_of(&t.attrs, "end").and_then(|s| parse_ics_utc(&s));
            }
            "href" if !t.close && !t.selfclose => {
                if let Some(e) = body[pos..].find('<') {
                    if hrefs.len() < 500 {
                        hrefs.push(unesc_xml(body[pos..pos + e].trim()));
                    }
                }
            }
            _ => {}
        }
    }
    match kind.as_str() {
        "calendar-query" => Report::Query { from, to },
        "calendar-multiget" => Report::Multiget { hrefs },
        other => Report::Unsupported(other.to_string()),
    }
}

/* ---------------------------------------------------------- xml respond */

pub fn etag(id: &str, rev: i64) -> String {
    format!("\"{id}-{rev}\"")
}

pub fn http_date(epoch: i64) -> String {
    let days = epoch.div_euclid(86400);
    let secs = epoch.rem_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    let wd = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"][days.rem_euclid(7) as usize];
    let mon = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][(m - 1) as usize];
    format!("{wd}, {d:02} {mon} {y} {:02}:{:02}:{:02} GMT", secs / 3600, secs % 3600 / 60, secs % 60)
}

/// prop ka local naam -> XML ka qualified naam (prefix + namespace jo multistatus ke root par declare hain). Unknown = None.
pub fn qname(local: &str) -> Option<&'static str> {
    Some(match local {
        "resourcetype" => "D:resourcetype",
        "displayname" => "D:displayname",
        "getetag" => "D:getetag",
        "getcontenttype" => "D:getcontenttype",
        "getlastmodified" => "D:getlastmodified",
        "getcontentlength" => "D:getcontentlength",
        "current-user-principal" => "D:current-user-principal",
        "principal-url" => "D:principal-URL",
        "owner" => "D:owner",
        "supported-report-set" => "D:supported-report-set",
        "current-user-privilege-set" => "D:current-user-privilege-set",
        "sync-token" => "D:sync-token",
        "calendar-home-set" => "C:calendar-home-set",
        "calendar-user-address-set" => "C:calendar-user-address-set",
        "supported-calendar-component-set" => "C:supported-calendar-component-set",
        "supported-calendar-data" => "C:supported-calendar-data",
        "calendar-data" => "C:calendar-data",
        "calendar-description" => "C:calendar-description",
        "getctag" => "CS:getctag",
        "calendar-color" => "A:calendar-color",
        _ => return None,
    })
}

#[derive(Debug, Default, Clone)]
pub struct Resp {
    pub href: String,
    /// (prop local naam, andar ka xml/matn jo already escape hai)
    pub found: Vec<(String, String)>,
    pub missing: Vec<String>,
}

pub fn multistatus(rs: &[Resp]) -> String {
    let mut o = String::from(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<D:multistatus xmlns:D=\"DAV:\" xmlns:C=\"urn:ietf:params:xml:ns:caldav\" xmlns:CS=\"http://calendarserver.org/ns/\" xmlns:A=\"http://apple.com/ns/ical/\">\n",
    );
    for r in rs {
        o.push_str("<D:response><D:href>");
        o.push_str(&esc_xml(&r.href));
        o.push_str("</D:href>");
        if !r.found.is_empty() {
            o.push_str("<D:propstat><D:prop>");
            for (n, v) in &r.found {
                let q = qname(n).unwrap_or("D:unknown");
                o.push_str(&format!("<{q}>{v}</{q}>"));
            }
            o.push_str("</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>");
        }
        if !r.missing.is_empty() {
            o.push_str("<D:propstat><D:prop>");
            for n in &r.missing {
                match qname(n) {
                    Some(q) => o.push_str(&format!("<{q}/>")),
                    None => o.push_str(&format!("<D:{}/>", esc_xml(&n.chars().filter(|c| c.is_ascii_alphanumeric() || *c == '-').collect::<String>()))),
                }
            }
            o.push_str("</D:prop><D:status>HTTP/1.1 404 Not Found</D:status></D:propstat>");
        }
        o.push_str("</D:response>\n");
    }
    o.push_str("</D:multistatus>\n");
    o
}

pub fn not_found_response(href: &str) -> String {
    format!("<D:response><D:href>{}</D:href><D:status>HTTP/1.1 404 Not Found</D:status></D:response>\n", esc_xml(href))
}

/// Seedhe maange hue props ko found/missing mein baantne ka madadgar: `have` mein jo hum jante hain.
pub fn pick(pf: &PropFind, have: &[(&str, String)]) -> (Vec<(String, String)>, Vec<String>) {
    if pf.all || pf.names_only {
        let found = have.iter().map(|(n, v)| ((*n).to_string(), if pf.names_only { String::new() } else { v.clone() })).collect();
        return (found, vec![]);
    }
    let (mut f, mut m) = (vec![], vec![]);
    for p in &pf.props {
        match have.iter().find(|(n, _)| n == p) {
            Some((n, v)) => f.push(((*n).to_string(), v.clone())),
            None => m.push(p.clone()),
        }
    }
    (f, m)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn basic_auth_parses_and_rejects_junk() {
        // "Me@X.test:pw123" -> TWVAWC50ZXN0OnB3MTIz
        assert_eq!(parse_basic("Basic TWVAWC50ZXN0OnB3MTIz"), Some(("me@x.test".into(), "pw123".into())));
        assert_eq!(parse_basic("Bearer abc"), None);
        assert_eq!(parse_basic("Basic !!!"), None);
        assert_eq!(parse_basic("Basic Og=="), None); // ":"
        assert_eq!(parse_basic(&format!("Basic {}", "A".repeat(500))), None);
    }

    #[test]
    fn app_password_roundtrip_and_shape() {
        let bytes: [u8; 19] = core::array::from_fn(|i| (i as u8).wrapping_mul(37).wrapping_add(11));
        let (t, s) = app_password_from_bytes(&bytes);
        assert_eq!((t.len(), s.len()), (10, 20));
        assert!(t.bytes().chain(s.bytes()).all(|c| B32.contains(&c)));
        let shown = display_app_password(&t, &s);
        assert_eq!(shown.matches('-').count(), 5);
        assert_eq!(split_app_password(&shown), Some((t.clone(), s.clone())));
        assert_eq!(split_app_password(&shown.to_uppercase()), Some((t, s)));
        assert_eq!(split_app_password("short"), None);
        assert_eq!(split_app_password(&"1".repeat(30)), None); // '1' base32 mein nahi
        assert_eq!(split_app_password(&format!("{}!", "a".repeat(29))), None);
    }

    #[test]
    fn different_bytes_give_different_keys() {
        let a = app_password_from_bytes(&[1u8; 19]);
        let b = app_password_from_bytes(&[2u8; 19]);
        assert_ne!(a, b);
    }

    #[test]
    fn constant_time_compare() {
        assert!(ct_eq(b"abc", b"abc"));
        assert!(!ct_eq(b"abc", b"abd"));
        assert!(!ct_eq(b"abc", b"ab"));
    }

    #[test]
    fn routes() {
        let id = "0f8fad5b-d9cb-469f-a165-70867728950e";
        assert_eq!(parse_route("/dav"), Route::Root);
        assert_eq!(parse_route("/dav/"), Route::Root);
        assert_eq!(parse_route("/dav/p/"), Route::Principal);
        assert_eq!(parse_route("/dav/p/home/"), Route::Home);
        assert_eq!(parse_route("/dav/c/personal/"), Route::Calendar("personal".into()));
        assert_eq!(parse_route(&format!("/dav/c/work/{id}.ics")), Route::Event("work".into(), id.into()));
        assert_eq!(parse_route(&format!("/dav/c/work/{id}.txt")), Route::NotFound);
        assert_eq!(parse_route("/dav/c/../etc/passwd"), Route::NotFound);
        assert_eq!(parse_route("/dav/c/Work/"), Route::NotFound);
        assert_eq!(parse_route("/dav/c/a/not-a-uuid.ics"), Route::NotFound);
        assert_eq!(parse_route("/other"), Route::NotFound);
        assert_eq!(parse_route("/dav/p/home/x/y"), Route::NotFound);
    }

    #[test]
    fn propfind_variants() {
        let pf = parse_propfind("<?xml version=\"1.0\"?><d:propfind xmlns:d=\"DAV:\" xmlns:cs=\"http://calendarserver.org/ns/\"><d:prop><d:resourcetype/><d:displayname/><cs:getctag/><d:getetag></d:getetag></d:prop></d:propfind>");
        assert_eq!(pf.props, vec!["resourcetype", "displayname", "getctag", "getetag"]);
        assert!(!pf.all);
        assert!(parse_propfind("").all);
        assert!(parse_propfind("<propfind xmlns=\"DAV:\"><allprop/></propfind>").all);
        assert!(parse_propfind("<propfind xmlns=\"DAV:\"><propname/></propfind>").names_only);
        // nested element prop ke andar (jaise calendar-data ke bachche) naya prop nahi banata
        let n = parse_propfind("<propfind><prop><C:calendar-data><C:comp name=\"VCALENDAR\"/></C:calendar-data><getetag/></prop></propfind>");
        assert_eq!(n.props, vec!["calendar-data", "getetag"]);
        // adhoora xml panic nahi karta
        let _ = parse_propfind("<propfind><prop><getet");
    }

    #[test]
    fn report_query_multiget_unsupported() {
        let q = parse_report("<C:calendar-query xmlns:C=\"urn:ietf:params:xml:ns:caldav\" xmlns:D=\"DAV:\"><D:prop><D:getetag/></D:prop><C:filter><C:comp-filter name=\"VCALENDAR\"><C:comp-filter name=\"VEVENT\"><C:time-range start=\"20261001T000000Z\" end=\"20261101T000000Z\"/></C:comp-filter></C:comp-filter></C:filter></C:calendar-query>");
        assert_eq!(q, Report::Query { from: Some(1790812800), to: Some(1793491200) });
        let m = parse_report("<C:calendar-multiget xmlns:C=\"urn:ietf:params:xml:ns:caldav\" xmlns:D=\"DAV:\"><D:prop><D:getetag/></D:prop><D:href>/dav/c/personal/a.ics</D:href><D:href>/dav/c/personal/b%26.ics</D:href></C:calendar-multiget>");
        assert_eq!(m, Report::Multiget { hrefs: vec!["/dav/c/personal/a.ics".into(), "/dav/c/personal/b%26.ics".into()] });
        assert_eq!(parse_report("<D:sync-collection xmlns:D=\"DAV:\"/>"), Report::Unsupported("sync-collection".into()));
        assert_eq!(parse_report("<C:calendar-query><C:time-range start=\"bad\"/></C:calendar-query>"), Report::Query { from: None, to: None });
    }

    #[test]
    fn ics_time_parsing_is_strict() {
        assert_eq!(parse_ics_utc("19700101T000000Z"), Some(0));
        assert_eq!(parse_ics_utc("20261023T020000Z"), Some(1792720800));
        assert_eq!(parse_ics_utc("20260230T000000Z"), None); // Feb 30
        assert_eq!(parse_ics_utc("20261023T020000"), None); // Z nahi
        assert_eq!(parse_ics_utc("20261323T020000Z"), None);
        assert_eq!(parse_ics_utc("21010101T000000Z"), None);
    }

    #[test]
    fn xml_is_escaped_and_valid_chars_only() {
        assert_eq!(esc_xml("a&b<c>\"d\u{1}e"), "a&amp;b&lt;c&gt;&quot;de");
        assert_eq!(unesc_xml("a&amp;b&lt;"), "a&b<");
    }

    #[test]
    fn multistatus_shape() {
        let r = Resp {
            href: "/dav/c/personal/".into(),
            found: vec![("displayname".into(), "Personal &amp; Co".into()), ("getctag".into(), "7".into())],
            missing: vec!["calendar-color".into(), "x-weird".into()],
        };
        let x = multistatus(&[r]);
        assert!(x.starts_with("<?xml"));
        assert!(x.contains("<D:href>/dav/c/personal/</D:href>"));
        assert!(x.contains("<D:displayname>Personal &amp; Co</D:displayname>"));
        assert!(x.contains("<CS:getctag>7</CS:getctag>"));
        assert!(x.contains("<A:calendar-color/>"));
        assert!(x.contains("<D:x-weird/>"));
        assert!(x.contains("HTTP/1.1 200 OK") && x.contains("HTTP/1.1 404 Not Found"));
        assert!(x.ends_with("</D:multistatus>\n"));
    }

    #[test]
    fn pick_splits_found_and_missing() {
        let have = [("getetag", "\"e\"".to_string()), ("displayname", "X".to_string())];
        let pf = PropFind { all: false, names_only: false, props: vec!["getetag".into(), "nope".into()] };
        let (f, m) = pick(&pf, &have);
        assert_eq!(f, vec![("getetag".to_string(), "\"e\"".to_string())]);
        assert_eq!(m, vec!["nope".to_string()]);
        let names = pick(&PropFind { names_only: true, ..Default::default() }, &have);
        assert!(names.0.iter().all(|(_, v)| v.is_empty()));
    }

    #[test]
    fn etag_and_http_date() {
        assert_eq!(etag("abc", 3), "\"abc-3\"");
        assert_eq!(http_date(0), "Thu, 01 Jan 1970 00:00:00 GMT");
        assert_eq!(http_date(1792720800), "Fri, 23 Oct 2026 02:00:00 GMT");
    }

    #[test]
    fn depth_header() {
        assert_eq!(depth_of(Some("0")), Depth::Zero);
        assert_eq!(depth_of(Some("1")), Depth::One);
        assert_eq!(depth_of(None), Depth::Infinity);
        assert_eq!(depth_of(Some("Infinity")), Depth::Infinity);
    }
}
