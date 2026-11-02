// ============================================================================
// latency_core.rs — lock-free p50 / p95 / p99 telemetry, std only, no crate, no Mutex, ZERO allocation on the hot path (founder 2 Nov 2026, "latency_telemetry.rs").
// Rust ONLY (Bun banned). Same module serves awam, ANEXOChat and every website product: one static probe per area, recorded inline inside the Tokio handlers.
//
// Design (HdrHistogram idea, std only): values in MICROSECONDS go into log-linear buckets: 8 linear steps inside every power of two,
// so the answer is never off by more than 12.5% (the founder's first sketch used one bucket per power of two = up to 100% off, and a percentile
// returned the bucket's LOWER edge, which makes a slow tail look faster than it is). Here a percentile returns the bucket's UPPER edge (never flattering).
// Fixes versus the first sketch: (1) `63 - leading_zeros` panicked/underflowed for 0 µs; (2) `p50 == 0` was used as "not yet found", which breaks when the
// answer really is 0; (3) rank = ceil(q * n) (at least 1) instead of floor.
// Honest limits: atomics are Relaxed, so a snapshot taken while threads are writing is a few samples blurred, not torn. Mean is shown only as context:
// the tail (p95/p99) is the number to watch. 496 buckets * 8 bytes = 3.9 KB per probe.
// ============================================================================

use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

const SUB: usize = 8; // linear steps per power of two
pub const NB: usize = 496; // 8 exact values (0..7) + 61 octaves * 8

pub struct Quantizer {
    buckets: [AtomicU64; NB],
    count: AtomicU64,
    sum_us: AtomicU64,
    max_us: AtomicU64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct Snapshot {
    pub count: u64,
    pub mean_us: u64,
    pub p50_us: u64,
    pub p95_us: u64,
    pub p99_us: u64,
    pub max_us: u64,
}

#[inline]
fn index_of(v: u64) -> usize {
    if v < SUB as u64 {
        return v as usize;
    }
    let msb = 63 - v.leading_zeros() as usize; // >= 3 here, so no underflow
    SUB * (msb - 2) + ((v >> (msb - 3)) & 7) as usize
}

/// Largest value that lands in bucket `i` (inclusive). Reported percentile = this, so it is an upper bound.
fn upper_of(i: usize) -> u64 {
    if i < SUB {
        return i as u64;
    }
    let msb = i / SUB + 2;
    let sub = (i % SUB) as u64;
    let step = 1u64 << (msb - 3);
    (8 + sub + 1).checked_mul(step).map(|x| x - 1).unwrap_or(u64::MAX)
}

impl Quantizer {
    pub const fn new() -> Self {
        Self { buckets: [const { AtomicU64::new(0) }; NB], count: AtomicU64::new(0), sum_us: AtomicU64::new(0), max_us: AtomicU64::new(0) }
    }

    /// Hot path: four atomic adds/max, no allocation, no lock, never panics (0 µs and u64::MAX are fine).
    #[inline]
    pub fn record_us(&self, us: u64) {
        let i = index_of(us).min(NB - 1);
        self.buckets[i].fetch_add(1, Ordering::Relaxed);
        self.count.fetch_add(1, Ordering::Relaxed);
        self.sum_us.fetch_add(us.min(1 << 40), Ordering::Relaxed);
        self.max_us.fetch_max(us, Ordering::Relaxed);
    }

    #[inline]
    pub fn record(&self, d: Duration) {
        self.record_us(d.as_micros().min(u64::MAX as u128) as u64);
    }

    /// Upper-bound percentile for `permille` (500 = p50, 950 = p95, 990 = p99, 999 = p99.9). 0 when there are no samples.
    pub fn percentile_permille(&self, permille: u64) -> u64 {
        let n = self.count.load(Ordering::Relaxed);
        if n == 0 {
            return 0;
        }
        let rank = (n.saturating_mul(permille.min(1000)) + 999) / 1000; // ceil
        let rank = rank.max(1);
        let mut acc = 0u64;
        for (i, b) in self.buckets.iter().enumerate() {
            acc += b.load(Ordering::Relaxed);
            if acc >= rank {
                return upper_of(i);
            }
        }
        self.max_us.load(Ordering::Relaxed)
    }

    pub fn snapshot(&self) -> Snapshot {
        let n = self.count.load(Ordering::Relaxed);
        if n == 0 {
            return Snapshot::default();
        }
        let max = self.max_us.load(Ordering::Relaxed);
        let clamp = |v: u64| v.min(max); // an upper edge can never be above the real maximum
        Snapshot {
            count: n,
            mean_us: self.sum_us.load(Ordering::Relaxed) / n,
            p50_us: clamp(self.percentile_permille(500)),
            p95_us: clamp(self.percentile_permille(950)),
            p99_us: clamp(self.percentile_permille(990)),
            max_us: max,
        }
    }
}

impl Default for Quantizer {
    fn default() -> Self {
        Self::new()
    }
}

/// One static probe per area: no map, no heap, no registration. The same names are used by awam, ANEXOChat and the websites.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Probe {
    Rpc = 0,
    WtRpc = 1,
    Auth = 2,
    Mail = 3,
    Chat = 4,
    Web = 5,
    Db = 6,
    Other = 7,
}

pub const PROBE_NAMES: [&str; 8] = ["rpc", "wt_rpc", "auth", "mail", "chat", "web", "db", "other"];
static PROBES: [Quantizer; 8] = [const { Quantizer::new() }; 8];

pub fn probe(p: Probe) -> &'static Quantizer {
    &PROBES[p as usize]
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;

    #[test]
    fn buckets_are_contiguous_monotonic_and_within_12_5_percent() {
        let mut last = 0usize;
        for v in (0..5000u64).chain([1 << 20, (1 << 20) + 12345, 1 << 33, u64::MAX >> 4]) {
            let i = index_of(v);
            assert!(i >= last || v > 5000, "monotonic at {v}");
            last = i;
            assert!(upper_of(i) >= v, "upper edge must cover {v}");
            if v >= 8 {
                let rel = (upper_of(i) - v) as f64 / v as f64;
                assert!(rel <= 0.125 + 1e-9, "{v}: error {rel}");
            }
        }
        assert_eq!(index_of(0), 0);
        assert_eq!(index_of(7), 7);
        assert_eq!(index_of(8), 8);
        assert_eq!(index_of(15), 15);
        assert_eq!(index_of(16), 16);
        assert!(index_of(u64::MAX) < NB);
    }

    #[test]
    fn zero_microseconds_and_extremes_do_not_panic() {
        let q = Quantizer::new();
        q.record_us(0);
        q.record_us(u64::MAX);
        q.record(Duration::from_secs(10_000_000_000));
        let s = q.snapshot();
        assert_eq!(s.count, 3);
        assert_eq!(s.p50_us <= s.p99_us, true);
    }

    #[test]
    fn empty_is_all_zero() {
        assert_eq!(Quantizer::new().snapshot(), Snapshot::default());
    }

    #[test]
    fn uniform_1_to_1000_us() {
        let q = Quantizer::new();
        for v in 1..=1000u64 {
            q.record_us(v);
        }
        let s = q.snapshot();
        assert!((500..=563).contains(&s.p50_us), "{s:?}");
        assert!((950..=1000).contains(&s.p95_us), "{s:?}");
        assert!((990..=1000).contains(&s.p99_us), "{s:?}");
        assert_eq!(s.max_us, 1000);
        assert_eq!(s.count, 1000);
    }

    #[test]
    fn mean_hides_the_tail_p99_shows_it() {
        let q = Quantizer::new();
        for _ in 0..980 {
            q.record_us(100);
        }
        for _ in 0..20 {
            q.record_us(50_000);
        }
        let s = q.snapshot();
        assert!(s.mean_us < 1_500, "mean looks fine: {s:?}");
        assert!(s.p50_us <= 113 && s.p95_us <= 113, "{s:?}");
        assert!(s.p99_us >= 50_000 * 8 / 9, "p99 must expose the slow 2%: {s:?}");
    }

    #[test]
    fn percentile_never_flatters_a_single_sample() {
        let q = Quantizer::new();
        q.record_us(1234);
        let s = q.snapshot();
        assert!(s.p50_us >= 1234 * 8 / 9 && s.p50_us <= 1234, "{s:?}");
        assert_eq!(s.p99_us, s.p50_us);
    }

    #[test]
    fn many_threads_lose_nothing() {
        let q = Arc::new(Quantizer::new());
        let hs: Vec<_> = (0..8)
            .map(|t| {
                let q = q.clone();
                std::thread::spawn(move || {
                    for i in 0..20_000u64 {
                        q.record_us(10 + (i + t) % 500);
                    }
                })
            })
            .collect();
        for h in hs {
            h.join().unwrap();
        }
        assert_eq!(q.snapshot().count, 160_000);
    }

    #[test]
    fn static_probes_are_independent() {
        probe(Probe::Chat).record_us(5);
        assert!(probe(Probe::Chat).snapshot().count >= 1);
        assert_eq!(probe(Probe::Db).snapshot().count, 0);
        assert_eq!(PROBE_NAMES[Probe::WtRpc as usize], "wt_rpc");
    }
}
