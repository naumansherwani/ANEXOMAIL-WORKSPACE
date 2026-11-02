// ============================================================================
// signx_core.rs — the pure half of the sign-up / create-account doors (PX2b, founder 2 Nov 2026). Rust ONLY (no Bun twin: "bun banned hai").
//
// What is decided here (std-only, unit-tested with `rustc --edition 2024 --test signx_core.rs`):
//   * GEO1 country wall: Afghanistan (AF), Israel (IL), North Korea (KP) are not available. Same three dial prefixes: +93, +972, +850 (Palestine +970 is NOT touched).
//   * E.164 phone numbers: a person may keep several; we only check the shape (+, 7-15 digits, no leading 0) and refuse the three prefixes.
//   * Gmail-style suggestions: when an ANEXOMAIL name is taken, give a few valid alternatives (the glue then keeps only the ones that are free right now).
//   * Browser-timezone signal for the best-effort VPN layer (AF/IL/KP timezones).
// Nothing here talks to a database; nothing here is invented data.
// ============================================================================

#[cfg(test)]
#[path = "vault_core.rs"]
mod vault_core;
#[cfg(not(test))]
use crate::vault_core;

use std::collections::HashMap;

/// Countries that are not available (ISO 3166-1 alpha-2, upper case).
pub const BLOCKED_COUNTRIES: [&str; 3] = ["AF", "IL", "KP"];
/// E.164 country calling codes of those countries (digits only, no plus).
pub const BLOCKED_DIALS: [&str; 3] = ["93", "972", "850"];
/// IANA time zones of those countries (best-effort signal for the VPN layer, never the only reason).
pub const BLOCKED_TIMEZONES: [&str; 5] = ["Asia/Kabul", "Asia/Jerusalem", "Asia/Tel_Aviv", "Israel", "Asia/Pyongyang"];

/// ISO alpha-2 shape: exactly two ASCII letters (the caller upper-cases first).
pub fn country_shape_ok(iso2: &str) -> bool {
    let b = iso2.as_bytes();
    b.len() == 2 && b.iter().all(|c| c.is_ascii_uppercase())
}

pub fn country_blocked(iso2: &str) -> bool {
    let u = iso2.trim().to_ascii_uppercase();
    BLOCKED_COUNTRIES.contains(&u.as_str())
}

pub fn timezone_blocked(tz: &str) -> bool {
    BLOCKED_TIMEZONES.contains(&tz.trim())
}

/// "+92 300-1234567" / "0092 300 1234567" -> "+923001234567". Anything that is not a plausible international number -> None.
pub fn normalise_e164(raw: &str) -> Option<String> {
    let mut s: String = raw.chars().filter(|c| !matches!(c, ' ' | '-' | '(' | ')' | '.')).collect();
    if let Some(rest) = s.strip_prefix("00") {
        s = format!("+{rest}");
    }
    let digits = s.strip_prefix('+')?;
    let b = digits.as_bytes();
    if b.len() < 7 || b.len() > 15 || b[0] == b'0' || !b.iter().all(|c| c.is_ascii_digit()) {
        return None;
    }
    Some(s)
}

/// Calling code is one of the three blocked ones. Country calling codes are prefix-free, so a plain prefix test is exact.
pub fn dial_blocked(e164: &str) -> bool {
    let d = e164.strip_prefix('+').unwrap_or(e164);
    BLOCKED_DIALS.iter().any(|p| d.starts_with(p))
}

/// ANEXOMAIL handle rule: 3-30 chars, a-z 0-9 . -, starts and ends with a letter or digit (same as main.rs `regex_handle_ok`).
pub fn handle_ok(h: &str) -> bool {
    let b = h.as_bytes();
    if b.len() < 3 || b.len() > 30 {
        return false;
    }
    let ok_char = |c: u8| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'.' || c == b'-';
    b[0].is_ascii_alphanumeric() && b[b.len() - 1].is_ascii_alphanumeric() && b.iter().all(|&c| ok_char(c))
}

/// What the person typed -> a clean base (lower case, only allowed characters, no leading/trailing dots or dashes).
pub fn clean_base(raw: &str) -> String {
    let s: String = raw
        .trim()
        .to_ascii_lowercase()
        .chars()
        .map(|c| if c.is_ascii_lowercase() || c.is_ascii_digit() || c == '.' || c == '-' { c } else { '.' })
        .collect();
    let mut out = String::new();
    for c in s.chars() {
        if (c == '.' || c == '-') && matches!(out.chars().last(), Some('.') | Some('-') | None) {
            continue;
        }
        out.push(c);
    }
    out.trim_matches(|c| c == '.' || c == '-').to_string()
}

/// Up to 12 valid alternatives for a taken name. `seed` only varies the numbers (the glue passes the clock), so repeated asks give different ideas.
pub fn handle_candidates(base_raw: &str, seed: u64) -> Vec<String> {
    let base = clean_base(base_raw);
    if base.len() < 2 {
        return Vec::new();
    }
    let n1 = 100 + (seed % 900);
    let n2 = 10 + ((seed / 7) % 90);
    let n3 = 1 + ((seed / 31) % 9);
    let mut out: Vec<String> = Vec::new();
    let mut push = |stem: &str, tail: String, joiner: &str| {
        let room = 30usize.saturating_sub(tail.len() + joiner.len());
        let s: String = stem.chars().take(room).collect();
        let c = format!("{}{}{}", s.trim_end_matches(|x| x == '.' || x == '-'), joiner, tail);
        if handle_ok(&c) && c != base && !out.contains(&c) {
            out.push(c);
        }
    };
    push(&base, n2.to_string(), "");
    push(&base, n2.to_string(), ".");
    push(&base, n3.to_string(), "");
    push(&base, n1.to_string(), "");
    push(&base, n2.to_string(), "-");
    push(&base, format!("{}{}", n3, n2), "");
    push(&base, "mail".to_string(), ".");
    push(&base, "hq".to_string(), ".");
    push(&base, "online".to_string(), ".");
    push(&base, format!("{}", n1 / 10), ".");
    push(&base, format!("{}", (seed / 3) % 99 + 1), "_".replace('_', "-").as_str());
    push(&base, "now".to_string(), ".");
    out
}


/// Percent-encode everything but unreserved characters (for PostgREST filters).
pub fn pct_simple(s: &str) -> String {
    let mut o = String::new();
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') {
            o.push(b as char);
        } else {
            o.push_str(&format!("%{b:02X}"));
        }
    }
    o
}

/// Plain e-mail shape: one @, 3-254 chars, a dot in the domain, no spaces. (Real proof of ownership is the mailed link, not this check.)
pub fn email_shape_ok(e: &str) -> bool {
    if e.len() < 6 || e.len() > 254 || e.contains(char::is_whitespace) {
        return false;
    }
    let mut it = e.split('@');
    let (l, d, rest) = (it.next().unwrap_or(""), it.next().unwrap_or(""), it.next());
    rest.is_none() && !l.is_empty() && l.len() <= 64 && d.len() >= 3 && d.contains('.') && !d.starts_with('.') && !d.ends_with('.') && !d.contains("..")
}

// ---- HMAC-SHA256 security layer (founder: "hmac sha 256 ... security lagao"; policy = docs/cursor-work/HASHING.md) ---------------------------------------
// Same primitives as the identity vault (vault_core: FIPS 180-4 SHA-256, RFC 2104 HMAC). Subkeys are domain-separated: HMAC(master, "anexomail/signx/v1/<purpose>").

fn subkey(master: &str, purpose: &str) -> [u8; 32] {
    let k = if master.is_empty() { "no-pepper" } else { master };
    vault_core::hmac_sha256(k.as_bytes(), format!("anexomail/signx/v1/{purpose}").as_bytes())
}

/// Constant-time equality (no early exit on the first different byte).
pub fn ct_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b.iter()).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

/// Public-door proof token. The browser first asks `signx.token` (server picks nonce + time), then must send it back with every public question.
/// token = hex(HMAC(subkey("door"), "<purpose>.<ts_secs>.<nonce>")). Stateless; a scanner has to fetch a fresh one every 10 minutes and is throttled per IP.
pub const TOKEN_TTL_SECS: u64 = 600;

pub fn make_token(master: &str, purpose: &str, ts_secs: u64, nonce: &str) -> String {
    let sk = subkey(master, "door");
    vault_core::hex(&vault_core::hmac_sha256(&sk, format!("{purpose}.{ts_secs}.{nonce}").as_bytes()))
}

pub fn nonce_ok(n: &str) -> bool {
    n.len() >= 16 && n.len() <= 64 && n.bytes().all(|c| c.is_ascii_hexdigit())
}

pub fn verify_token(master: &str, purpose: &str, ts_secs: u64, nonce: &str, token: &str, now_secs: u64) -> bool {
    if !nonce_ok(nonce) || token.len() != 64 {
        return false;
    }
    if ts_secs > now_secs + 5 || now_secs.saturating_sub(ts_secs) > TOKEN_TTL_SECS {
        return false;
    }
    ct_eq(make_token(master, purpose, ts_secs, nonce).as_bytes(), token.as_bytes())
}

/// Blind index of a phone number: HMAC(subkey("phone/v1"), e164). Lets us ask "does another account hold this number?" for abuse work
/// WITHOUT ever searching on or logging the plain number. The key never leaves the server env (DEVICE_VAULT_KEY), never in repo/DB/logs.
pub fn phone_blind_index(master: &str, e164: &str) -> Option<String> {
    if e164.trim().is_empty() {
        return None;
    }
    let sk = subkey(master, "phone/v1");
    Some(vault_core::hex(&vault_core::hmac_sha256(&sk, e164.as_bytes())))
}

/// Per-key sliding window (in memory). true = TOO MANY, the caller answers 429.
#[derive(Default)]
pub struct Window {
    hits: HashMap<String, Vec<u64>>,
}

impl Window {
    pub fn too_many(&mut self, key: &str, now_ms: u64, window_ms: u64, max: usize) -> bool {
        let mut w: Vec<u64> = self.hits.get(key).map(|v| v.iter().copied().filter(|t| now_ms.saturating_sub(*t) < window_ms).collect()).unwrap_or_default();
        if w.len() >= max {
            self.hits.insert(key.to_string(), w);
            return true;
        }
        w.push(now_ms);
        self.hits.insert(key.to_string(), w);
        if self.hits.len() > 20_000 {
            self.hits.clear();
        }
        false
    }
}

/// Client address from a trusted single reverse proxy (Caddy appends the real peer as the LAST X-Forwarded-For entry; earlier entries are client-supplied and ignored).
pub fn client_ip_from_xff(xff: &str) -> String {
    xff.rsplit(',').next().map(|s| s.trim().to_string()).filter(|s| !s.is_empty() && s.len() <= 45).unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_countries_are_blocked_and_nobody_else() {
        for c in ["AF", "il", "KP", " af "] {
            assert!(country_blocked(c), "{c}");
        }
        for c in ["PK", "GB", "PS", "IR", "AE", "IN", "US", "JO", ""] {
            assert!(!country_blocked(c), "{c}");
        }
    }

    #[test]
    fn dial_prefixes_are_exact() {
        for n in ["+93701234567", "+972501234567", "+850191234567", "93701234567"] {
            assert!(dial_blocked(n), "{n}");
        }
        for n in ["+923001234567", "+970599123456", "+971501234567", "+447700900123", "+12025550100", "+98912345678", "+962791234567"] {
            assert!(!dial_blocked(n), "{n}");
        }
    }

    #[test]
    fn e164_shapes() {
        assert_eq!(normalise_e164("+92 300-1234567").as_deref(), Some("+923001234567"));
        assert_eq!(normalise_e164("0092 300 1234567").as_deref(), Some("+923001234567"));
        assert_eq!(normalise_e164("(+44) 7700 900123").as_deref(), Some("+447700900123"));
        for bad in ["03001234567", "+0300123456", "+12", "+1234567890123456", "+92abc", "", "++923001234567"] {
            assert!(normalise_e164(bad).is_none(), "{bad}");
        }
    }

    #[test]
    fn timezones() {
        assert!(timezone_blocked("Asia/Kabul") && timezone_blocked("Asia/Jerusalem") && timezone_blocked("Asia/Pyongyang"));
        assert!(!timezone_blocked("Asia/Karachi") && !timezone_blocked("Asia/Gaza") && !timezone_blocked("Europe/London"));
    }

    #[test]
    fn country_shape() {
        assert!(country_shape_ok("PK") && !country_shape_ok("pk") && !country_shape_ok("PAK") && !country_shape_ok("P1"));
    }

    #[test]
    fn base_is_cleaned() {
        assert_eq!(clean_base("  Ali.Khan "), "ali.khan");
        assert_eq!(clean_base("--ali__khan--"), "ali.khan");
        assert_eq!(clean_base("Ali Khan!!"), "ali.khan");
        assert_eq!(clean_base("..."), "");
    }

    #[test]
    fn candidates_are_valid_unique_and_differ_from_base() {
        let c = handle_candidates("Ali.Khan", 12345);
        assert!(c.len() >= 6, "{c:?}");
        for h in &c {
            assert!(handle_ok(h), "{h}");
            assert_ne!(h, "ali.khan");
        }
        let mut u = c.clone();
        u.sort();
        u.dedup();
        assert_eq!(u.len(), c.len());
        assert_ne!(handle_candidates("ali.khan", 1), handle_candidates("ali.khan", 99999));
    }

    #[test]
    fn long_base_is_trimmed_not_broken() {
        let c = handle_candidates("abcdefghijklmnopqrstuvwxyz0123456789", 5);
        assert!(!c.is_empty());
        assert!(c.iter().all(|h| h.len() <= 30 && handle_ok(h)));
        assert!(handle_candidates("a", 1).is_empty());
    }

    #[test]
    fn token_roundtrip_expiry_and_tamper() {
        let n = "0123456789abcdef0123456789abcdef";
        let t = make_token("master", "suggest", 1000, n);
        assert_eq!(t.len(), 64);
        assert!(verify_token("master", "suggest", 1000, n, &t, 1100));
        assert!(!verify_token("master", "suggest", 1000, n, &t, 1000 + TOKEN_TTL_SECS + 1), "expired");
        assert!(!verify_token("master", "other", 1000, n, &t, 1100), "purpose bound");
        assert!(!verify_token("master2", "suggest", 1000, n, &t, 1100), "key bound");
        assert!(!verify_token("master", "suggest", 1001, n, &t, 1100), "time bound");
        assert!(!verify_token("master", "suggest", 1000, "ffffffffffffffffffffffffffffffff", &t, 1100), "nonce bound");
        assert!(!verify_token("master", "suggest", 5000, n, &make_token("master", "suggest", 5000, n), 1100), "future");
        let mut bad = t.clone();
        bad.replace_range(0..1, if t.starts_with('a') { "b" } else { "a" });
        assert!(!verify_token("master", "suggest", 1000, n, &bad, 1100));
        assert!(!verify_token("master", "suggest", 1000, "short", &t, 1100));
    }

    #[test]
    fn hmac_matches_rfc4231_case_2() {
        // RFC 4231 test case 2: key "Jefe", data "what do ya want for nothing?"
        let h = vault_core::hex(&vault_core::hmac_sha256(b"Jefe", b"what do ya want for nothing?"));
        assert_eq!(h, "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843");
    }

    #[test]
    fn constant_time_compare() {
        assert!(ct_eq(b"abc", b"abc") && !ct_eq(b"abc", b"abd") && !ct_eq(b"abc", b"abcd"));
    }

    #[test]
    fn phone_blind_index_is_keyed_and_stable() {
        let a = phone_blind_index("k1", "+923001234567").unwrap();
        assert_eq!(a, phone_blind_index("k1", "+923001234567").unwrap());
        assert_ne!(a, phone_blind_index("k2", "+923001234567").unwrap());
        assert_ne!(a, phone_blind_index("k1", "+923001234568").unwrap());
        assert_eq!(a.len(), 64);
        assert!(phone_blind_index("k1", " ").is_none());
    }

    #[test]
    fn window_limits_per_key() {
        let mut w = Window::default();
        for i in 0..5 {
            assert!(!w.too_many("ip", 1000 + i, 60_000, 5));
        }
        assert!(w.too_many("ip", 2000, 60_000, 5));
        assert!(!w.too_many("other", 2000, 60_000, 5));
        assert!(!w.too_many("ip", 1000 + 60_001, 60_000, 5));
    }

    #[test]
    fn xff_takes_the_proxy_added_last_entry() {
        assert_eq!(client_ip_from_xff("6.6.6.6, 203.0.113.9"), "203.0.113.9");
        assert_eq!(client_ip_from_xff("203.0.113.9"), "203.0.113.9");
        assert_eq!(client_ip_from_xff(""), "");
    }

    #[test]
    fn pct_and_email_shape() {
        assert_eq!(pct_simple("a.b-c_d~e"), "a.b-c_d~e");
        assert_eq!(pct_simple("a b&c=d"), "a%20b%26c%3Dd");
        assert!(email_shape_ok("ali@gmail.com") && email_shape_ok("a.b+c@outlook.co.uk"));
        for bad in ["", "ali", "ali@", "@x.com", "a@b", "a b@x.com", "a@@x.com", "a@x..com", "a@.com"] {
            assert!(!email_shape_ok(bad), "{bad}");
        }
    }
}
