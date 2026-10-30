//! Refresh speed (30 Oct): one page load fires 8-9 founder GETs at once and each used to ask the database two questions
//! ("is this a founder?", "is this device still approved?"), ~0.7 s per round trip. Concurrent asks for the SAME (account, device)
//! now share ONE answer, and a good answer is reused for at most `ttl` (5 s). Only a "yes to both" is ever kept: a no is never cached,
//! so an approval is seen at once and a revoke is seen within `ttl`. Writes (PUT/POST) never use this: they always ask fresh.
use std::{collections::HashMap, future::Future, sync::Arc, time::{Duration, Instant}};
use tokio::sync::{Mutex, OnceCell};

type Cell = Arc<OnceCell<bool>>;
pub struct AuthCache { ttl: Duration, m: Mutex<HashMap<(String, String), (Instant, Cell)>> }

impl AuthCache {
    pub fn new(ttl: Duration) -> Self { Self { ttl, m: Mutex::new(HashMap::new()) } }

    /// `ask` runs at most once per (sub, did) per ttl window, however many requests arrive together. Returns true only when both checks passed.
    pub async fn ok<F, Fut>(&self, sub: &str, did: &str, ask: F) -> bool where F: FnOnce() -> Fut, Fut: Future<Output = bool> {
        let key = (sub.to_string(), did.to_string());
        let cell: Cell = {
            let mut m = self.m.lock().await;
            if m.len() > 64 { let ttl = self.ttl; m.retain(|_, (t, _)| t.elapsed() < ttl); }
            match m.get(&key) {
                Some((t, c)) if t.elapsed() < self.ttl => c.clone(),
                _ => { let c: Cell = Arc::new(OnceCell::new()); m.insert(key.clone(), (Instant::now(), c.clone())); c }
            }
        };
        let r = *cell.get_or_init(ask).await;
        if !r { let mut m = self.m.lock().await; if m.get(&key).map(|(_, c)| Arc::ptr_eq(c, &cell)).unwrap_or(false) { m.remove(&key); } } // a "no" is never kept
        r
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering::SeqCst};

    #[tokio::test]
    async fn nine_parallel_asks_share_one_answer() {
        let c = Arc::new(AuthCache::new(Duration::from_secs(5))); let n = Arc::new(AtomicUsize::new(0));
        let mut hs = vec![];
        for _ in 0..9 { let (c, n) = (c.clone(), n.clone()); hs.push(tokio::spawn(async move { c.ok("u", "d", || async { n.fetch_add(1, SeqCst); tokio::time::sleep(Duration::from_millis(30)).await; true }).await })); }
        for h in hs { assert!(h.await.unwrap()); }
        assert_eq!(n.load(SeqCst), 1, "one database round trip for nine requests");
    }
    #[tokio::test]
    async fn a_yes_is_reused_until_ttl_then_asked_again() {
        let c = AuthCache::new(Duration::from_millis(60)); let n = AtomicUsize::new(0);
        assert!(c.ok("u", "d", || async { n.fetch_add(1, SeqCst); true }).await);
        assert!(c.ok("u", "d", || async { n.fetch_add(1, SeqCst); true }).await);
        assert_eq!(n.load(SeqCst), 1);
        tokio::time::sleep(Duration::from_millis(80)).await;
        assert!(c.ok("u", "d", || async { n.fetch_add(1, SeqCst); true }).await);
        assert_eq!(n.load(SeqCst), 2);
    }
    #[tokio::test]
    async fn a_no_is_never_kept_so_an_approval_is_seen_at_once() {
        let c = AuthCache::new(Duration::from_secs(5)); let n = AtomicUsize::new(0);
        assert!(!c.ok("u", "d", || async { n.fetch_add(1, SeqCst); false }).await);
        assert!(c.ok("u", "d", || async { n.fetch_add(1, SeqCst); true }).await);
        assert_eq!(n.load(SeqCst), 2);
    }
    #[tokio::test]
    async fn different_devices_never_share() {
        let c = AuthCache::new(Duration::from_secs(5));
        assert!(c.ok("u", "d1", || async { true }).await);
        assert!(!c.ok("u", "d2", || async { false }).await);
        assert!(c.ok("u", "d1", || async { false }).await, "d1 still served from its own entry");
    }
}
