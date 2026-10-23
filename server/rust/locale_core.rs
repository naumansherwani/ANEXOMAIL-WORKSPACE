// ============================================================================
// locale_core.rs — the pure half of the 28-language overlay (Rust PRIMARY for /rpc/locale.*; Bun /api/locale/* = fallback only).
//
// Why it exists: every signed-in page asked Rust for `locale.pref` + `locale.bundle`, Rust answered 404, and the browser
// then asked Bun again — two round-trips and red 404s in the console on EVERY page (NOTE N3, live login 20 Oct 2026).
//
// Same rules as the TypeScript twin (server/routes/locale.ts):
//   * only the 28 locked tags (phase64 locale_registry) are ever accepted or returned;
//   * a missing translation is simply absent (the UI falls back to English) — no row is ever invented;
//   * a non-English row whose text equals its English key is dropped (it is an untranslated placeholder, not a translation).
// std-only: unit-tested with `rustc --edition 2024 --test locale_core.rs`.
// ============================================================================

use std::time::{SystemTime, UNIX_EPOCH};

/// The 28 locked locales, in registry order (phase64_crm_locale.sql `sort_n`).
pub const TAGS: [&str; 28] = [
    "en-GB", "hi-IN", "ur-PK", "ar-SA", "es-ES", "fr-FR", "de-DE", "de-CH", "pt-BR", "zh-CN", "ja-JP", "ko-KR", "tr-TR", "it-IT",
    "ro-RO", "ru-RU", "nl-NL", "pl-PL", "uk-UA", "id-ID", "ms-MY", "vi-VN", "th-TH", "bn-BD", "pa-IN", "fa-IR", "el-GR", "sv-SE",
];

pub const DEFAULT_TAG: &str = "en-GB";

/// Exact, case-sensitive match — the same as the TS `TAGS.has(tag)`.
pub fn is_tag(tag: &str) -> bool {
    TAGS.contains(&tag)
}

/// Keep a `ui_copy` row in the bundle? (key and text both non-empty; a non-English row identical to its key is a placeholder.)
pub fn keep_row(tag: &str, english_key: &str, text: &str) -> bool {
    if english_key.is_empty() || text.is_empty() {
        return false;
    }
    !(tag != DEFAULT_TAG && text == english_key)
}

/// Percent-encode a value for a PostgREST filter (`user_id=eq.<v>`): only unreserved characters pass through.
pub fn pct(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{b:02X}"));
        }
    }
    out
}

/// Unix seconds -> RFC 3339 UTC (`2026-10-20T00:41:07Z`). Howard Hinnant's civil-from-days; valid for all dates after 1970.
pub fn rfc3339_utc(unix: u64) -> String {
    let days = (unix / 86_400) as i64;
    let rem = unix % 86_400;
    let (h, mi, s) = (rem / 3600, (rem % 3600) / 60, rem % 60);
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + if m <= 2 { 1 } else { 0 };
    format!("{y:04}-{m:02}-{d:02}T{h:02}:{mi:02}:{s:02}Z")
}

/// Calendar display preference values the account may hold (E57 CHECK constraints mirror these).
pub fn clock_ok(s: &str) -> bool {
    matches!(s, "auto" | "12" | "24")
}

pub fn layout_ok(s: &str) -> bool {
    matches!(s, "classic" | "expanded")
}

pub fn now_rfc3339() -> String {
    rfc3339_utc(SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn twenty_eight_unique_tags_english_first() {
        assert_eq!(TAGS.len(), 28);
        let mut v = TAGS.to_vec();
        v.sort();
        v.dedup();
        assert_eq!(v.len(), 28);
        assert_eq!(TAGS[0], DEFAULT_TAG);
    }

    #[test]
    fn tag_match_is_exact() {
        assert!(is_tag("ur-PK"));
        assert!(is_tag("de-CH"));
        assert!(!is_tag("ur-pk"));
        assert!(!is_tag("en"));
        assert!(!is_tag(""));
        assert!(!is_tag("en-GB "));
        assert!(!is_tag("xx-XX"));
    }

    #[test]
    fn placeholder_rows_dropped_except_english() {
        assert!(keep_row("en-GB", "Inbox", "Inbox"));
        assert!(!keep_row("ur-PK", "Inbox", "Inbox"));
        assert!(keep_row("ur-PK", "Inbox", "ان باکس"));
        assert!(!keep_row("ur-PK", "", "x"));
        assert!(!keep_row("ur-PK", "x", ""));
    }

    #[test]
    fn ui_pref_values_are_exact() {
        assert!(clock_ok("auto") && clock_ok("12") && clock_ok("24"));
        assert!(!clock_ok("") && !clock_ok("12h") && !clock_ok("AUTO") && !clock_ok("24 "));
        assert!(layout_ok("classic") && layout_ok("expanded"));
        assert!(!layout_ok("") && !layout_ok("Classic") && !layout_ok("dual"));
    }

    #[test]
    fn pct_encodes_everything_but_unreserved() {
        assert_eq!(pct("e4201816-19de-487d"), "e4201816-19de-487d");
        assert_eq!(pct("a,b&c=d"), "a%2Cb%26c%3Dd");
        assert_eq!(pct("ü"), "%C3%BC");
    }

    #[test]
    fn rfc3339_known_points() {
        assert_eq!(rfc3339_utc(0), "1970-01-01T00:00:00Z");
        assert_eq!(rfc3339_utc(951_782_400), "2000-02-29T00:00:00Z");
        assert_eq!(rfc3339_utc(1_709_164_799), "2024-02-28T23:59:59Z");
        assert_eq!(rfc3339_utc(1_709_251_200), "2024-03-01T00:00:00Z");
        assert_eq!(rfc3339_utc(1_792_456_867), "2026-10-20T00:41:07Z");
        assert_eq!(rfc3339_utc(4_102_444_800), "2100-01-01T00:00:00Z");
    }
}

/// World-clock pins: at most 6 IANA-style names (shape only), no duplicates, no path tricks.
pub fn clocks_ok(names: &[&str]) -> Result<(), &'static str> {
    if names.len() > 6 {
        return Err("at most 6 world clocks");
    }
    for (i, z) in names.iter().enumerate() {
        let b = z.as_bytes();
        let shape = !b.is_empty()
            && b.len() <= 64
            && b[0].is_ascii_alphabetic()
            && b.iter().all(|c| c.is_ascii_alphanumeric() || matches!(c, b'_' | b'/' | b'+' | b'-'))
            && !z.contains("..");
        if !shape {
            return Err("a world clock must be a time zone name like Europe/London");
        }
        if names[..i].contains(z) {
            return Err("the same time zone is pinned twice");
        }
    }
    Ok(())
}

#[cfg(test)]
mod clocks_tests {
    use super::clocks_ok;
    #[test]
    fn world_clock_pins() {
        assert!(clocks_ok(&["Europe/London", "Asia/Karachi", "America/Argentina/Buenos_Aires", "Etc/GMT+5"]).is_ok());
        assert!(clocks_ok(&[]).is_ok());
        assert!(clocks_ok(&["A/B", "C/D", "E/F", "G/H", "I/J", "K/L", "M/N"]).is_err(), "7 is too many");
        assert!(clocks_ok(&["Asia/Karachi", "Asia/Karachi"]).is_err());
        assert!(clocks_ok(&["../etc/passwd"]).is_err());
        assert!(clocks_ok(&["Asia/Kar achi"]).is_err());
        assert!(clocks_ok(&[""]).is_err());
        assert!(clocks_ok(&["9bad"]).is_err());
    }
}

// ---------------------------------------------------------------------------------------------------------------
// W4 — server clock (drift badge) and the "Travelling" status. Pure, std-only, tested.
// ---------------------------------------------------------------------------------------------------------------

/// Server time in milliseconds since 1970 (`time.now`). The browser compares it with its own clock using the round-trip.
pub fn now_ms() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(0)
}

/// Days since 1970-01-01 for a civil date (Howard Hinnant's days-from-civil); the inverse of what `rfc3339_utc` does.
fn days_from_civil(y: i64, m: i64, d: i64) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let mp = if m > 2 { m - 3 } else { m + 9 };
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

/// `YYYY-MM-DDTHH:MM:SS[.fff]Z` (UTC, exactly what `Date.toISOString()` gives; fraction ignored) -> unix seconds.
/// Anything else (offsets like +05:00, missing Z, impossible dates such as Feb 30) -> None. Years 2000..2100 only.
pub fn parse_utc_secs(s: &str) -> Option<i64> {
    let b = s.as_bytes();
    if b.len() < 20 || b[b.len() - 1] != b'Z' {
        return None;
    }
    let shape = |i: usize, c: u8| b.get(i) == Some(&c);
    if !(shape(4, b'-') && shape(7, b'-') && shape(10, b'T') && shape(13, b':') && shape(16, b':')) {
        return None;
    }
    let num = |from: usize, len: usize| -> Option<i64> {
        let part = s.get(from..from + len)?;
        if !part.bytes().all(|c| c.is_ascii_digit()) {
            return None;
        }
        part.parse().ok()
    };
    let (y, mo, d, h, mi, sec) = (num(0, 4)?, num(5, 2)?, num(8, 2)?, num(11, 2)?, num(14, 2)?, num(17, 2)?);
    // after the seconds: either "Z" (len 20) or ".f…fZ" with 1..=9 digits
    let tail = &s[19..];
    if tail != "Z" {
        let frac = tail.strip_prefix('.')?.strip_suffix('Z')?;
        if frac.is_empty() || frac.len() > 9 || !frac.bytes().all(|c| c.is_ascii_digit()) {
            return None;
        }
    }
    if !(2000..=2100).contains(&y) || !(1..=12).contains(&mo) || !(0..24).contains(&h) || !(0..60).contains(&mi) || !(0..60).contains(&sec) {
        return None;
    }
    let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
    let dim = [31, if leap { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][(mo - 1) as usize];
    if !(1..=dim).contains(&d) {
        return None;
    }
    Some(days_from_civil(y, mo, d) * 86_400 + h * 3600 + mi * 60 + sec)
}

/// The longest trip the status accepts (a long-haul flight plus a transfer day). Longer = a mistake, not a journey.
pub const TRAVEL_MAX_SECS: i64 = 72 * 3600;

/// Validate a user-entered trip and return both times in one canonical form (`…Z`, seconds only).
/// Rules: both parse; arrival strictly after departure; at most 72 h long; the trip may not already be over by more than
/// 48 h, nor start more than a year ahead (a stale or absurd entry is refused instead of silently kept).
pub fn travel_window(depart: &str, arrive: &str, now_s: i64) -> Result<(String, String), &'static str> {
    let d = parse_utc_secs(depart).ok_or("departure must be a UTC time like 2026-10-23T09:30:00Z")?;
    let a = parse_utc_secs(arrive).ok_or("arrival must be a UTC time like 2026-10-23T18:45:00Z")?;
    if a <= d {
        return Err("arrival must be after departure");
    }
    if a - d > TRAVEL_MAX_SECS {
        return Err("a trip can be at most 72 hours long");
    }
    if a < now_s - 48 * 3600 {
        return Err("this trip ended more than 48 hours ago");
    }
    if d > now_s + 366 * 86_400 {
        return Err("departure is more than a year away");
    }
    Ok((rfc3339_utc(d as u64), rfc3339_utc(a as u64)))
}

#[cfg(test)]
mod w4_tests {
    use super::*;

    #[test]
    fn parses_what_the_browser_sends_and_round_trips() {
        assert_eq!(parse_utc_secs("1970-01-01T00:00:00Z"), None, "before 2000 is refused");
        assert_eq!(parse_utc_secs("2026-10-23T09:30:00.000Z"), parse_utc_secs("2026-10-23T09:30:00Z"));
        let s = parse_utc_secs("2026-10-23T09:30:15Z").unwrap();
        assert_eq!(rfc3339_utc(s as u64), "2026-10-23T09:30:15Z");
        assert_eq!(parse_utc_secs("2000-01-01T00:00:00Z"), Some(946_684_800));
        assert_eq!(parse_utc_secs("2024-02-29T12:00:00Z").map(|x| rfc3339_utc(x as u64)), Some("2024-02-29T12:00:00Z".into()));
    }

    #[test]
    fn rejects_anything_that_is_not_plain_utc() {
        for bad in [
            "", "2026-10-23", "2026-10-23T09:30:00", "2026-10-23T09:30:00+05:00", "2026-10-23 09:30:00Z", "2026-13-01T00:00:00Z",
            "2026-02-30T00:00:00Z", "2025-02-29T00:00:00Z", "2026-10-23T24:00:00Z", "2026-10-23T09:60:00Z", "2026-10-23T09:30:00.Z",
            "2026-10-23T09:30:00.1234567890Z", "2026-10-23T09:30:0xZ", "2101-01-01T00:00:00Z", "abcd-ef-ghTij:kl:mnZ",
        ] {
            assert!(parse_utc_secs(bad).is_none(), "should refuse {bad:?}");
        }
    }

    #[test]
    fn trip_rules() {
        let now = parse_utc_secs("2026-10-23T12:00:00Z").unwrap();
        let ok = travel_window("2026-10-23T14:00:00.000Z", "2026-10-23T22:30:45.123Z", now).unwrap();
        assert_eq!(ok, ("2026-10-23T14:00:00Z".to_string(), "2026-10-23T22:30:45Z".to_string()), "canonical, seconds only");
        assert!(travel_window("2026-10-23T14:00:00Z", "2026-10-23T14:00:00Z", now).is_err(), "zero length");
        assert!(travel_window("2026-10-23T14:00:00Z", "2026-10-23T13:00:00Z", now).is_err(), "arrives before leaving");
        assert!(travel_window("2026-10-23T14:00:00Z", "2026-10-26T14:00:01Z", now).is_err(), "over 72 h");
        assert!(travel_window("2026-10-23T14:00:00Z", "2026-10-26T14:00:00Z", now).is_ok(), "exactly 72 h is fine");
        assert!(travel_window("2026-10-19T00:00:00Z", "2026-10-20T00:00:00Z", now).is_err(), "ended days ago");
        assert!(travel_window("2026-10-21T10:00:00Z", "2026-10-21T20:00:00Z", now).is_ok(), "ended 40 h ago: still kept (landing note)");
        assert!(travel_window("2028-01-01T00:00:00Z", "2028-01-01T10:00:00Z", now).is_err(), "more than a year ahead");
        assert!(travel_window("not a time", "2026-10-23T22:00:00Z", now).is_err());
    }

    #[test]
    fn server_clock_is_sane() {
        // 2026-01-01 .. 2100: the exact value is not testable, but it must be a plausible modern millisecond count
        let n = now_ms();
        assert!(n > 1_767_225_600_000 && n < 4_102_444_800_000, "now_ms {n}");
    }
}
