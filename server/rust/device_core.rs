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
    fn device_hash_shape() {
        assert!(valid_device_hash("a1B2-c3_d4+e5/f6="));
        assert!(!valid_device_hash(""));
        assert!(!valid_device_hash("abc&user_id=eq.x"));
        assert!(!valid_device_hash(&"a".repeat(129)));
    }
}
