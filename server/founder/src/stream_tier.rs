//! QLIVE per-package live-stream limits (18 Nov 2026, his order: "package ke hisaab se stream limit lagao, duniya ki advance research ke saath").
//!
//! RESEARCH (18 Nov 2026): Dovecot refuses a new IMAP login once `mail_max_userip_connections` (per user + IP) is reached; Stalwart has per-account concurrent-connection
//! limits in its rate-limit settings; Gmail caps IMAP at 15 connections per account. The common lesson (and the common complaint on the support forums: "Maximum number of
//! concurrent IMAP connections exceeded") is that a limit must be (1) per ACCOUNT, not global, (2) enforced at ADMISSION with a clear reason, (3) released by an RAII guard
//! so a dead tab can never leak a slot, and (4) never silent: the refused client must know why and fall back. We do exactly that: the 503 says `stream_limit`, the browser
//! simply keeps its honest 5 s read (QLIVE fallback), and nothing is evicted behind the user's back (an eviction would make two tabs fight each other in a reconnect loop).
//!
//! The numbers are the SQL table `fmail_tier_limits187` (E187), the single source of truth. `tests::the_table_equals_the_sql_table` PARSES that SQL file, so the Rust
//! copy can never drift. Premium and MAX are kept (built = false) and are refused by `admit` until the package is built.
use std::{collections::HashMap, sync::{Arc, Mutex, OnceLock}};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Tier { Founder, Basic, Pro, Business, BusinessPro, BusinessPremium, BusinessMax }
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Limits { pub live_streams: usize, pub keep_days: i32, pub keep_rows: i32, pub built: bool }

impl Tier {
    pub const ALL: [(Tier, &'static str); 7] = [(Tier::Founder, "founder"), (Tier::Basic, "basic"), (Tier::Pro, "pro"), (Tier::Business, "business"), (Tier::BusinessPro, "business_pro"), (Tier::BusinessPremium, "business_premium"), (Tier::BusinessMax, "business_max")];
    pub fn name(self) -> &'static str { Self::ALL.iter().find(|(t, _)| *t == self).map(|(_, n)| *n).unwrap_or("founder") }
    pub fn parse(s: &str) -> Option<Tier> { Self::ALL.iter().find(|(_, n)| *n == s).map(|(t, _)| *t) }
    /// Same numbers as E187 `fmail_tier_limits187`.
    pub fn limits(self) -> Limits {
        match self {
            Tier::Founder => Limits { live_streams: 20, keep_days: 14, keep_rows: 20000, built: true },
            Tier::Basic => Limits { live_streams: 1, keep_days: 3, keep_rows: 2000, built: true },
            Tier::Pro => Limits { live_streams: 2, keep_days: 7, keep_rows: 5000, built: true },
            Tier::Business => Limits { live_streams: 5, keep_days: 14, keep_rows: 20000, built: true },
            Tier::BusinessPro => Limits { live_streams: 10, keep_days: 14, keep_rows: 20000, built: true },
            Tier::BusinessPremium => Limits { live_streams: 25, keep_days: 30, keep_rows: 50000, built: false },
            Tier::BusinessMax => Limits { live_streams: 100, keep_days: 30, keep_rows: 100000, built: false },
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum Denied { /// this account already holds its package's number of live streams
    Limit { cap: usize }, /// the package exists as preserved code only
    NotBuilt }
impl Denied { pub fn reason(&self) -> &'static str { match self { Denied::Limit { .. } => "stream_limit", Denied::NotBuilt => "tier_not_built" } } }

/// Per-account open-stream counter. `admit` returns a guard; dropping the guard frees the slot (a closed tab, a crashed QUIC session, a panic: all drop it).
#[derive(Default)]
pub struct Registry { open: Mutex<HashMap<String, usize>> }
pub struct AccountSlot { reg: Arc<Registry>, account: String }
impl Registry {
    pub fn admit(self: &Arc<Self>, account: &str, tier: Tier) -> Result<AccountSlot, Denied> {
        let l = tier.limits();
        if !l.built { return Err(Denied::NotBuilt); }
        let mut m = self.open.lock().unwrap_or_else(|e| e.into_inner());
        let n = m.entry(account.to_string()).or_insert(0);
        if *n >= l.live_streams { return Err(Denied::Limit { cap: l.live_streams }); }
        *n += 1;
        Ok(AccountSlot { reg: self.clone(), account: account.to_string() })
    }
    pub fn open_for(&self, account: &str) -> usize { self.open.lock().unwrap_or_else(|e| e.into_inner()).get(account).copied().unwrap_or(0) }
}
impl Drop for AccountSlot {
    fn drop(&mut self) {
        let mut m = self.reg.open.lock().unwrap_or_else(|e| e.into_inner());
        if let Some(n) = m.get_mut(&self.account) { *n = n.saturating_sub(1); if *n == 0 { m.remove(&self.account); } } // an idle account keeps no entry: the map never grows
    }
}
pub fn registry() -> Arc<Registry> { static R: OnceLock<Arc<Registry>> = OnceLock::new(); R.get_or_init(|| Arc::new(Registry::default())).clone() }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn each_account_has_its_own_budget_and_a_dropped_slot_is_freed() {
        let r = Arc::new(Registry::default());
        let a1 = r.admit("alice", Tier::Basic).unwrap();
        assert_eq!(r.admit("alice", Tier::Basic).err(), Some(Denied::Limit { cap: 1 }));
        let _b = r.admit("bob", Tier::Basic).unwrap(); // another account is untouched
        drop(a1);
        assert_eq!(r.open_for("alice"), 0);
        assert!(r.admit("alice", Tier::Basic).is_ok());
    }
    #[test]
    fn caps_follow_the_package_and_never_cross_accounts() {
        let r = Arc::new(Registry::default());
        let held: Vec<_> = (0..5).map(|_| r.admit("biz", Tier::Business).unwrap()).collect();
        assert_eq!(r.admit("biz", Tier::Business).err().map(|d| d.reason()), Some("stream_limit"));
        assert_eq!(r.open_for("biz"), 5);
        let more: Vec<_> = (0..10).map(|_| r.admit("bp", Tier::BusinessPro).unwrap()).collect();
        assert!(r.admit("bp", Tier::BusinessPro).is_err());
        drop(held); drop(more);
        assert_eq!((r.open_for("biz"), r.open_for("bp")), (0, 0));
        assert!(r.open.lock().unwrap().is_empty(), "idle accounts leave no entry");
    }
    #[test]
    fn premium_and_max_are_preserved_but_refused_until_built() {
        let r = Arc::new(Registry::default());
        assert_eq!(r.admit("x", Tier::BusinessPremium).err(), Some(Denied::NotBuilt));
        assert_eq!(r.admit("x", Tier::BusinessMax).err().map(|d| d.reason()), Some("tier_not_built"));
        assert_eq!((Tier::BusinessPremium.limits().live_streams, Tier::BusinessMax.limits().live_streams), (25, 100)); // the codes are kept
    }
    #[test]
    fn founder_cap_equals_the_global_stream_ceiling() { assert_eq!(Tier::Founder.limits().live_streams, crate::live::MAX_STREAMS); }
    #[test]
    fn names_round_trip() { for (t, n) in Tier::ALL { assert_eq!(Tier::parse(n), Some(t)); assert_eq!(t.name(), n); } assert_eq!(Tier::parse("gold"), None); }
    #[test]
    fn the_table_equals_the_sql_table() {
        // E187 is the single source of truth: parse its insert lines `('tier', streams, days, rows, built, '...')` and compare every number.
        let sql = include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/../../docs/cursor-work/sql/E187_founder_mail_live_change_log.sql"));
        let mut seen = 0;
        for line in sql.lines().map(str::trim).filter(|l| l.starts_with("('") && l.contains("', ")) {
            let inner = line.trim_start_matches('(');
            let mut p = inner.split(',').map(str::trim);
            let name = p.next().unwrap().trim_matches('\'');
            let Some(t) = Tier::parse(name) else { continue };
            let (s, d, k): (usize, i32, i32) = (p.next().unwrap().parse().unwrap(), p.next().unwrap().parse().unwrap(), p.next().unwrap().parse().unwrap());
            let built = p.next().unwrap() == "true";
            assert_eq!(t.limits(), Limits { live_streams: s, keep_days: d, keep_rows: k, built }, "tier {name} drifted from E187");
            seen += 1;
        }
        assert_eq!(seen, 7, "all 7 tiers must be found in the SQL file");
    }
}
