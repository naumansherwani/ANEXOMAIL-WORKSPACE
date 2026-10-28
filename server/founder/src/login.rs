//! Founder login (password pehla qadam; passkey step-up F1a mein lazmi hoga — abhi NAHI, UI mein saaf likha).
//! Awam login se alag: yahan se sirf `founder_accounts` wala uid token paata hai; baqi ko generic inkar, token fauran phenk diya.
use std::collections::HashMap;
use std::time::{Duration, Instant};

const MAX_FAILS: usize = 5;
const WINDOW: Duration = Duration::from_secs(15 * 60);

#[derive(Default)]
pub struct Limiter { fails: HashMap<String, Vec<Instant>> }

impl Limiter {
    pub fn locked(&mut self, key: &str, now: Instant) -> bool {
        let v = self.fails.entry(key.to_string()).or_default();
        v.retain(|t| now.duration_since(*t) < WINDOW);
        v.len() >= MAX_FAILS
    }
    pub fn fail(&mut self, key: &str, now: Instant) { self.fails.entry(key.to_string()).or_default().push(now); }
    pub fn clear(&mut self, key: &str) { self.fails.remove(key); }
}

pub fn valid_email(e: &str) -> bool {
    e.len() <= 254 && e.matches('@').count() == 1 && !e.starts_with('@') && !e.ends_with('@') && !e.chars().any(|c| c.is_whitespace() || c.is_control())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn locks_after_five_and_clears() {
        let mut l = Limiter::default();
        let t = Instant::now();
        for _ in 0..4 { l.fail("a", t); }
        assert!(!l.locked("a", t));
        l.fail("a", t);
        assert!(l.locked("a", t));
        assert!(!l.locked("b", t));
        l.clear("a");
        assert!(!l.locked("a", t));
    }
    #[test]
    fn window_expires() {
        let mut l = Limiter::default();
        let t = Instant::now();
        for _ in 0..5 { l.fail("a", t); }
        assert!(!l.locked("a", t + WINDOW + Duration::from_secs(1)));
    }
    #[test]
    fn email_shapes() {
        assert!(valid_email("a@b.com"));
        assert!(!valid_email("a b@c.com"));
        assert!(!valid_email("@c.com"));
        assert!(!valid_email("a@@c.com"));
    }
}
