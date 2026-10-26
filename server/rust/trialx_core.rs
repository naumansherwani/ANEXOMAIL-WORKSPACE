// ============================================================================
// trialx_core — Trial lifecycle ke 3 baaqi procs ka HISAAB (account.signup.security / events / holds). Sirf std (installer `rustc --edition 2021 --test`).
// Bun server/routes/trial.ts (POST /security, GET /events, GET /mail-holds) ka Rust (Tokio) port. Gate: sirf login (har plan, har account — Basic aur Pro dono).
// ============================================================================

pub fn owns_name(proc: &str) -> bool {
    matches!(proc, "account.signup.security" | "account.signup.events" | "account.signup.holds")
}

/// recovery_hint ki hadd (Bun `.slice(0,120)`).
pub const HINT_MAX: usize = 120;

pub fn clamp_hint(raw: &str) -> String {
    raw.chars().take(HINT_MAX).collect()
}

/// Bun: `!passkey && !kind` => 400 nothing_to_set.
pub fn nothing_to_set(passkey: bool, kind: &str) -> bool {
    !passkey && kind.trim().is_empty()
}

/// Khali string => None (SQL ko null).
pub fn opt(raw: &str) -> Option<String> {
    if raw.is_empty() { None } else { Some(raw.to_string()) }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names() {
        assert!(owns_name("account.signup.security") && owns_name("account.signup.events") && owns_name("account.signup.holds"));
        assert!(!owns_name("account.signup.state") && !owns_name("account.signup.claim"));
    }

    #[test]
    fn hint_and_empty() {
        assert_eq!(clamp_hint(&"x".repeat(300)).chars().count(), 120);
        assert_eq!(clamp_hint("short"), "short");
        assert!(nothing_to_set(false, ""));
        assert!(nothing_to_set(false, "  "));
        assert!(!nothing_to_set(true, ""));
        assert!(!nothing_to_set(false, "phone"));
        assert_eq!(opt(""), None);
        assert_eq!(opt("a"), Some("a".to_string()));
    }
}
