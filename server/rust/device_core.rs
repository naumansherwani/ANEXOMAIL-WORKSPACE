// ============================================================================
// device_core.rs — pure half of the account-integrity device record (Rust PRIMARY; any signed-in user, every plan).
//
// Why it exists (live login 20 Oct 2026): the device record ("we seal a device record from five coarse signals when you sign
// in" — /privacy) lived behind the CHAT gate (`chat_identity` -> chat_access()). Basic has no chat, so for every Basic user
// the record was NEVER sealed (403 `chat_not_entitled` on every page) and the "3 accounts / 24 h on one device" abuse check
// never saw them. Account integrity is not a chat feature; this module serves the same three procedures to everyone.
//
// Rules kept from the chat arm (main.rs PHASE 19/20): only the five coarse signals reach the database — canvas, audio,
// fonts, webgl and ip are always stripped here, whatever the browser sends. std-only: `rustc --edition 2024 --test`.
// ============================================================================

/// Keys that must never be stored (fingerprinting / network identity).
pub const FORBIDDEN_SIGNALS: [&str; 5] = ["canvas", "audio", "fonts", "webgl", "ip"];

/// The only states a user may set on their own device (the SQL also checks; this answers 400 before a round-trip).
pub const USER_STATES: [&str; 3] = ["trusted", "suspicious", "revoked"];

pub fn is_forbidden_signal(k: &str) -> bool {
    let k = k.to_ascii_lowercase();
    FORBIDDEN_SIGNALS.iter().any(|f| k == *f || k.starts_with(&format!("{f}_")))
}

pub fn valid_user_state(s: &str) -> bool {
    USER_STATES.contains(&s)
}

/// A device hash from the client: hex/base64url-ish, bounded — never a path or a filter fragment.
pub fn valid_device_hash(s: &str) -> bool {
    !s.is_empty() && s.len() <= 128 && s.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'+' | b'/' | b'='))
}


/// JWT ke payload se `session_id` (uuid) — signature VERIFY NAHI (token pehle `auth_user` se verify ho chuka hota hai; yahan sirf link ke liye padhte hain,
/// aur SQL `device_session_link` khud dekhta hai ke session isi user ki maujood hai). Galat shakal => None.
pub fn jwt_session_id(token: &str) -> Option<String> {
    let payload = token.split('.').nth(1)?;
    let mut out = Vec::with_capacity(payload.len() * 3 / 4);
    let (mut buf, mut bits) = (0u32, 0u32);
    for c in payload.trim_end_matches('=').bytes() {
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
    let text = String::from_utf8(out).ok()?;
    let i = text.find("\"session_id\"")?;
    let rest = &text[i + 12..];
    let q1 = rest.find('"')?;
    let rest2 = &rest[q1 + 1..];
    let q2 = rest2.find('"')?;
    let id = &rest2[..q2];
    let b = id.as_bytes();
    let ok = b.len() == 36 && b.iter().enumerate().all(|(i, c)| if matches!(i, 8 | 13 | 18 | 23) { *c == b'-' } else { c.is_ascii_hexdigit() });
    if ok { Some(id.to_string()) } else { None }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_every_fingerprinting_key_any_case() {
        for k in ["canvas", "Canvas", "audio", "fonts", "WEBGL", "ip", "webgl_vendor", "canvas_hash"] {
            assert!(is_forbidden_signal(k), "{k}");
        }
        for k in ["ua", "platform_class", "browser_class", "tz_offset_minutes", "screen_bucket", "language", "iphone"] {
            assert!(!is_forbidden_signal(k), "{k}");
        }
    }

    #[test]
    fn user_states() {
        assert!(valid_user_state("trusted") && valid_user_state("revoked") && valid_user_state("suspicious"));
        assert!(!valid_user_state("banned") && !valid_user_state("") && !valid_user_state("Trusted"));
    }

    #[test]
    fn session_id_from_jwt() {
        // {"sub":"s","session_id":"11111111-0000-0000-0000-000000000001"}
        let tok = "h.eyJzdWIiOiJzIiwic2Vzc2lvbl9pZCI6IjExMTExMTExLTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMSJ9.sig";
        assert_eq!(jwt_session_id(tok).as_deref(), Some("11111111-0000-0000-0000-000000000001"));
        assert_eq!(jwt_session_id("garbage"), None);
        assert_eq!(jwt_session_id("a.b.c"), None);
        // uuid nahi => None (injection ka raasta band)
        // {"session_id":"x' or 1=1"}
        assert_eq!(jwt_session_id("h.eyJzZXNzaW9uX2lkIjoieCcgb3IgMT0xIn0.s"), None);
    }

    #[test]
    fn device_hash_shape() {
        assert!(valid_device_hash("a1B2-c3_d4+e5/f6="));
        assert!(!valid_device_hash(""));
        assert!(!valid_device_hash("abc&user_id=eq.x"));
        assert!(!valid_device_hash(&"a".repeat(129)));
    }
}
