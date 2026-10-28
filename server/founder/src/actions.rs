//! One-click action ka darwaza: tap 1 (kholna) + wajah + tap 2 (pakka). Executor F8 tak band — lekin KOSHISH bhi audit chain mein likhi jati hai.
pub fn valid_key(k: &str) -> bool {
    k.len() >= 3 && k.len() <= 64 && k.split('.').count() >= 2
        && k.chars().all(|c| c.is_ascii_lowercase() || c == '_' || c == '.')
        && !k.starts_with('.') && !k.ends_with('.') && !k.contains("..")
}
/// Wajah: trim ke baad 8..=500 akshar (DB bhi yahi qaida lagata hai).
pub fn clean_reason(r: &str) -> Option<String> {
    let t = r.trim();
    let n = t.chars().count();
    (8..=500).contains(&n).then(|| t.to_string())
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn keys() {
        assert!(valid_key("release.pull_web"));
        assert!(!valid_key("release"));
        assert!(!valid_key("Release.pull"));
        assert!(!valid_key("a..b"));
        assert!(!valid_key("release.pull;drop"));
        assert!(!valid_key(".a.b"));
    }
    #[test]
    fn reasons() {
        assert_eq!(clean_reason("  customer ne manga  ").as_deref(), Some("customer ne manga"));
        assert!(clean_reason("chhota").is_none());
        assert!(clean_reason(&"x".repeat(501)).is_none());
    }
}
