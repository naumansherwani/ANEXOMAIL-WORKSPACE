// ============================================================================
// promx_core — compose "Business Outcomes": wada (promise) ledger + thread economics ka HISAAB. Sirf std (installer `rustc --edition 2021 --test`).
// Browser WASM kernel (intent@1) text se wada pakadta hai; server yahan sirf VALIDATE karta hai aur SQL E97 (commitment_record, HMAC-SEALED
// append-only ledger) se atomically task + calendar hold banata hai. Server kabhi client ki baat par bharosa nahi karta: tareekh, status, rate, list sab yahan jaanche jaate hain.
// Gate: Pro+ (Basic 403 feature_not_available). I/O promx_glue.rs mein.
// ============================================================================

pub const NO_ACCESS: &str = "Promise tracking and thread economics are on Pro and above.";

pub fn owns_name(proc: &str) -> bool {
    matches!(proc, "commit.record" | "commit.status" | "commit.list" | "commit.verify" | "commit.economics" | "commit.rate" | "commit.rateSet" | "file.context")
}

/// SQL commitment_set_status() ke saath mel: fulfilled / broken / snoozed / cancelled.
pub fn valid_status(s: &str) -> bool {
    matches!(s, "fulfilled" | "broken" | "snoozed" | "cancelled")
}

pub fn uuid_ok(s: &str) -> bool {
    s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_hexdigit() })
}

fn leap(y: i64) -> bool {
    (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
}

/// "YYYY-MM-DD" asli tareekh hai? (30 Feb jaisi tareekh reject). Wapas wahi string (normalised).
pub fn clean_date(raw: &str) -> Option<String> {
    let t = raw.trim();
    let p: Vec<&str> = t.split('-').collect();
    if p.len() != 3 || p[0].len() != 4 || p[1].len() != 2 || p[2].len() != 2 {
        return None;
    }
    let (y, m, d) = (p[0].parse::<i64>().ok()?, p[1].parse::<i64>().ok()?, p[2].parse::<i64>().ok()?);
    let dim = match m {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 => if leap(y) { 29 } else { 28 },
        _ => return None,
    };
    if !(2000..=2100).contains(&y) || d < 1 || d > dim {
        return None;
    }
    Some(t.to_string())
}

/// Wade ka jumla: 4..=1000 akshar, control characters hata kar, beech ki khali jagah ek.
pub fn clean_phrase(raw: &str) -> Option<String> {
    let t: String = raw.chars().filter(|c| !c.is_control() || c.is_whitespace()).collect::<String>().split_whitespace().collect::<Vec<_>>().join(" ");
    let n = t.chars().count();
    if n < 4 || n > 1000 {
        None
    } else {
        Some(t)
    }
}

/// Task title: kaam ka chhota naam, max 140.
pub fn clean_action(raw: &str, fallback: &str) -> String {
    let t = raw.split_whitespace().collect::<Vec<_>>().join(" ");
    let t = if t.is_empty() { fallback.split_whitespace().collect::<Vec<_>>().join(" ") } else { t };
    t.chars().take(140).collect()
}

/// Jis se wada kiya (recipients): lowercase, '@' wale, dedupe, max 20.
pub fn clean_to(list: &[String]) -> Vec<String> {
    let mut out: Vec<String> = vec![];
    for a in list {
        let e = a.trim().to_lowercase();
        if e.contains('@') && e.len() <= 254 && !e.contains(' ') && !out.contains(&e) {
            out.push(e);
            if out.len() >= 20 {
                break;
            }
        }
    }
    out
}

pub fn clamp_conf(v: f64) -> f64 {
    if v.is_nan() { 0.0 } else { v.max(0.0).min(100.0).round() }
}

pub fn lang_of(raw: &str) -> &'static str {
    if raw == "ur" { "ur" } else { "en" }
}

/// Economics ke hadd: words 0..=200000, recipients 0..=500.
pub fn clamp_counts(words: i64, recipients: i64) -> (i64, i64) {
    (words.max(0).min(200_000), recipients.max(0).min(500))
}

/// File dhoondne ka sawal: control chars hata kar, 2..=120 akshar. Jo sirf punctuation ho woh nahi.
pub fn clean_file_query(raw: &str) -> Option<String> {
    let t: String = raw.chars().filter(|c| !c.is_control()).collect::<String>().split_whitespace().collect::<Vec<_>>().join(" ");
    let n = t.chars().count();
    if !(2..=120).contains(&n) || !t.chars().any(|c| c.is_alphanumeric()) {
        None
    } else {
        Some(t)
    }
}

pub fn file_limit(n: i64) -> i64 {
    n.max(1).min(5)
}

pub const RATE_MIN: i64 = 100; // minor unit / ghanta (£1)
pub const RATE_MAX: i64 = 1_000_000; // £10,000
pub fn rate_ok(minor: i64) -> bool {
    (RATE_MIN..=RATE_MAX).contains(&minor)
}
pub fn wpm_ok(wpm: i64) -> bool {
    (60..=600).contains(&wpm)
}
pub fn currency_ok(c: &str) -> bool {
    c.len() == 3 && c.bytes().all(|b| b.is_ascii_uppercase())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ownership_and_status() {
        for p in ["commit.record", "commit.status", "commit.list", "commit.verify", "commit.economics", "commit.rate", "commit.rateSet"] {
            assert!(owns_name(p), "{p}");
        }
        assert!(!owns_name("commit") && !owns_name(""));
        assert!(valid_status("fulfilled") && valid_status("snoozed") && !valid_status("linked") && !valid_status(""));
    }

    #[test]
    fn dates_are_real() {
        assert_eq!(clean_date("2026-10-30").as_deref(), Some("2026-10-30"));
        assert_eq!(clean_date(" 2028-02-29 ").as_deref(), Some("2028-02-29"));
        assert!(clean_date("2026-02-29").is_none() && clean_date("2026-13-01").is_none() && clean_date("2026-10-32").is_none());
        assert!(clean_date("26-10-30").is_none() && clean_date("2026/10/30").is_none() && clean_date("1999-01-01").is_none() && clean_date("").is_none());
    }

    #[test]
    fn phrase_and_action() {
        assert!(clean_phrase("hi").is_none());
        assert_eq!(clean_phrase("  I will   send\tit\u{0}  by Friday ").unwrap(), "I will send it by Friday");
        assert!(clean_phrase(&"x".repeat(1001)).is_none());
        assert_eq!(clean_action("", "  Follow   up "), "Follow up");
        assert_eq!(clean_action(&"y".repeat(300), "z").chars().count(), 140);
    }

    #[test]
    fn recipients_cleaned() {
        let v = clean_to(&["A@x.com".into(), "a@x.com".into(), "bad".into(), "b c@x.com".into(), " Z@y.org ".into()]);
        assert_eq!(v, vec!["a@x.com".to_string(), "z@y.org".to_string()]);
        let many: Vec<String> = (0..50).map(|i| format!("u{i}@x.com")).collect();
        assert_eq!(clean_to(&many).len(), 20);
    }

    #[test]
    fn file_query_and_limit() {
        assert_eq!(clean_file_query("  crm \u{0} sheet ").as_deref(), Some("crm sheet"));
        assert!(clean_file_query("a").is_none() && clean_file_query("!!").is_none() && clean_file_query(&"x".repeat(121)).is_none());
        assert_eq!((file_limit(0), file_limit(3), file_limit(99)), (1, 3, 5));
        assert!(owns_name("file.context"));
    }

    #[test]
    fn bounds() {
        assert_eq!(clamp_conf(f64::NAN), 0.0);
        assert_eq!(clamp_conf(250.0), 100.0);
        assert_eq!(clamp_conf(91.6), 92.0);
        assert_eq!(clamp_counts(-5, 9999), (0, 500));
        assert!(rate_ok(6000) && !rate_ok(99) && !rate_ok(1_000_001));
        assert!(wpm_ok(220) && !wpm_ok(30) && !wpm_ok(601));
        assert!(currency_ok("GBP") && !currency_ok("gbp") && !currency_ok("GB"));
        assert!(uuid_ok("00000000-0000-4000-8000-0000000e9700") && !uuid_ok("nope"));
        assert_eq!(lang_of("ur"), "ur");
        assert_eq!(lang_of("fr"), "en");
    }
}
