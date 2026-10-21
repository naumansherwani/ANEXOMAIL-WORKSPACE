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

/// Calendar display preference values the account may hold (E58 CHECK constraints mirror these).
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
