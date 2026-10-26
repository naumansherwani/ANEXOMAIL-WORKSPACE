// billx_core — Batch C1: billing ke PADHNE wale / jodne wale chhote raaste (paisa BANANE wale nahi). std-only.
// Bun twin: server/routes/billing-sync.ts (GET /state, GET /state-health, POST /claim-guest).
// Paisa banane wale (intent, change-plan, guest-intent, cron sync, pull-truth) C2 hain — founder ki ijazat + shadow-mode ke baad.

pub const PROCS: [&str; 3] = ["billing.state", "billing.stateHealth", "billing.claimGuest"];

pub fn owns_name(p: &str) -> bool {
    PROCS.contains(&p)
}

/// Guest token: 8..=200 chars, sirf alnum - _ . (PostgREST/rpc body mein jata hai, phir bhi galat shakal pehle hi rok do).
pub fn guest_token_ok(t: &str) -> Option<String> {
    let s = t.trim();
    if s.len() >= 8 && s.len() <= 200 && s.chars().all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.')) {
        Some(s.to_string())
    } else {
        None
    }
}

/// state-health sirf founder ke liye (Bun mein koi bhi login wala dekh sakta tha — loophole).
pub fn health_allowed(is_founder: bool) -> bool {
    is_founder
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn names() {
        assert!(owns_name("billing.state"));
        assert!(owns_name("billing.stateHealth"));
        assert!(owns_name("billing.claimGuest"));
        assert!(!owns_name("billing.intent"));
        assert!(!owns_name("billing.settle"));
    }
    #[test]
    fn tokens() {
        assert_eq!(guest_token_ok(" abcdef12-_. ").as_deref(), Some("abcdef12-_."));
        assert!(guest_token_ok("short").is_none());
        assert!(guest_token_ok("bad token with spaces!!").is_none());
        assert!(guest_token_ok(&"a".repeat(201)).is_none());
        assert!(guest_token_ok("").is_none());
    }
    #[test]
    fn health_gate() {
        assert!(health_allowed(true));
        assert!(!health_allowed(false));
    }
}
