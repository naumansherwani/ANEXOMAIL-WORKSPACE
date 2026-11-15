//! QPERF-2 (founder mailbox): the mail speed meter. Times the stages of every inbound mail (accept, scan, seal, commit, total) and hands the numbers to the database ledger (SQL E174).
//! Design rules (docs/claude/QPERF-PLAN-15NOV.md):
//!   * The mail path NEVER waits for the meter: `record` is a non-blocking `try_send` into a bounded Tokio channel; when the channel is full the sample is dropped and COUNTED (shown, never hidden).
//!   * Only a duration, an outcome class and a size bucket leave this file: no address, no subject, no message id, no sender.
//!   * One writer task: batches of up to 500 samples every 2 s to `fmail_perf_ingest174`; a failed batch is retried once, then counted as lost.
//!   * The same task rolls closed minutes into the histogram every 60 s (`fmail_perf_rollup174`) and seals the previous UTC day once (`fmail_perf_seal174`).
use crate::data::Sb;
use serde_json::{json, Value};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::OnceLock;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::sync::mpsc;

pub const BATCH_MAX: usize = 500;
pub const FLUSH_MS: u64 = 2000;
pub const QUEUE_CAP: usize = 8192;
const MAX_DUR_US: u64 = 3_600_000_000;

#[derive(Clone, Debug, PartialEq)]
pub struct Sample { pub ts_ms: u64, pub stage: &'static str, pub outcome: &'static str, pub size: &'static str, pub dur_us: u64 }

static TX: OnceLock<mpsc::Sender<Sample>> = OnceLock::new();
pub static DROPPED: AtomicU64 = AtomicU64::new(0);
pub static LOST: AtomicU64 = AtomicU64::new(0);
pub static SENT: AtomicU64 = AtomicU64::new(0);
pub static REFUSED: AtomicU64 = AtomicU64::new(0);   // the database refused them (a sealed day, a rolled-up minute, a bad value): shown, never hidden

/// The closed lists of E174 (the database refuses anything else, so this file never invents a value).
pub const STAGES: [&str; 5] = ["accept", "scan", "seal", "commit", "total"];
pub const OUTCOMES: [&str; 4] = ["ok", "quarantine", "reject", "error"];

pub fn size_bucket(bytes: usize) -> &'static str {
    match bytes { 0..=16_383 => "xs", 16_384..=262_143 => "s", 262_144..=2_097_151 => "m", 2_097_152..=10_485_759 => "l", _ => "xl" }
}
pub fn now_ms() -> u64 { SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(0) }

/// Non-blocking. A no-op until `start` ran (tests, or the intake switched off), so the mail path has no cost and no failure mode here.
pub fn record(stage: &'static str, outcome: &'static str, size: &'static str, since: Instant) {
    let Some(tx) = TX.get() else { return };
    let dur_us = (since.elapsed().as_micros() as u64).min(MAX_DUR_US);
    if tx.try_send(Sample { ts_ms: now_ms(), stage, outcome, size, dur_us }).is_err() { DROPPED.fetch_add(1, Ordering::Relaxed); }
}

/// The JSON array the database door takes. Pure, so it is tested.
pub fn batch_json(b: &[Sample]) -> Value {
    Value::Array(b.iter().map(|s| json!({"ts_ms": s.ts_ms, "stage": s.stage, "outcome": s.outcome, "size": s.size, "dur_us": s.dur_us})).collect())
}

/// Civil date (UTC) of a unix day count: Howard Hinnant's algorithm, no calendar crate needed.
pub fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719_468; let era = z.div_euclid(146_097); let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365; let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100); let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32; let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}
/// "YYYY-MM-DD" of the UTC day that `back` days before the day of `now_ms`.
pub fn utc_day(now_ms: u64, back: i64) -> String { let (y, m, d) = civil_from_days((now_ms / 86_400_000) as i64 - back); format!("{y:04}-{m:02}-{d:02}") }

/// What the database says about a batch: (accepted, refused). A missing or odd answer counts the whole batch as accepted-unknown = refused 0 (never a made-up number).
pub fn accepted_refused(v: &Value, n: usize) -> (u64, u64) {
    let a = v["accepted"].as_u64().unwrap_or(n as u64).min(n as u64);
    (a, v["rejected"].as_u64().unwrap_or(n as u64 - a).min(n as u64))
}

/// Take what is waiting, up to BATCH_MAX, without blocking.
pub fn drain(rx: &mut mpsc::Receiver<Sample>, out: &mut Vec<Sample>) { while out.len() < BATCH_MAX { match rx.try_recv() { Ok(s) => out.push(s), Err(_) => break } } }

pub fn start(sb: Sb) {
    let (tx, mut rx) = mpsc::channel::<Sample>(QUEUE_CAP);
    if TX.set(tx).is_err() { return; }
    eprintln!("founder: mail speed meter ON (queue {QUEUE_CAP}, batch {BATCH_MAX} every {} s, durations only)", FLUSH_MS / 1000);
    tokio::spawn(async move {
        let mut buf: Vec<Sample> = Vec::with_capacity(BATCH_MAX);
        let (mut last_roll, mut sealed_day) = (Instant::now(), String::new());
        loop {
            tokio::time::sleep(Duration::from_millis(FLUSH_MS)).await;
            loop {
                drain(&mut rx, &mut buf);
                if buf.is_empty() { break; }
                let body = json!({"p_batch": batch_json(&buf)});
                let mut ans = sb.rpc("fmail_perf_ingest174", body.clone()).await;
                if ans.is_none() { tokio::time::sleep(Duration::from_millis(500)).await; ans = sb.rpc("fmail_perf_ingest174", body).await; }
                match ans {
                    Some(v) => { let (a, r) = accepted_refused(&v, buf.len()); SENT.fetch_add(a, Ordering::Relaxed); REFUSED.fetch_add(r, Ordering::Relaxed); }
                    None => { LOST.fetch_add(buf.len() as u64, Ordering::Relaxed); eprintln!("founder: mail speed meter: {} samples lost (database not answering twice)", buf.len()); }
                }
                buf.clear();
            }
            if last_roll.elapsed() >= Duration::from_secs(60) {
                last_roll = Instant::now();
                let _ = sb.rpc("fmail_perf_rollup174", json!({})).await;
                let day = utc_day(now_ms(), 1);
                if day != sealed_day && sb.rpc("fmail_perf_seal174", json!({"p_day": day})).await.is_some() { sealed_day = day; }
            }
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn size_buckets_have_exact_edges() {
        assert_eq!((size_bucket(0), size_bucket(16_383), size_bucket(16_384), size_bucket(262_143), size_bucket(262_144)), ("xs", "xs", "s", "s", "m"));
        assert_eq!((size_bucket(2_097_151), size_bucket(2_097_152), size_bucket(10_485_759), size_bucket(10_485_760)), ("m", "l", "l", "xl"));
    }
    #[test] fn every_value_is_in_the_closed_lists_of_e174() {
        for s in ["accept", "scan", "seal", "commit", "total"] { assert!(STAGES.contains(&s)); }
        for o in ["ok", "quarantine", "reject", "error"] { assert!(OUTCOMES.contains(&o)); }
        for n in [0usize, 20_000, 300_000, 3_000_000, 30_000_000] { assert!(["xs", "s", "m", "l", "xl"].contains(&size_bucket(n))); }
    }
    #[test] fn the_batch_holds_only_durations_and_classes() {
        let j = batch_json(&[Sample { ts_ms: 1_700_000_000_000, stage: "scan", outcome: "ok", size: "s", dur_us: 1234 }]);
        let o = j[0].as_object().unwrap();
        let mut keys: Vec<&str> = o.keys().map(|k| k.as_str()).collect(); keys.sort();
        assert_eq!(keys, vec!["dur_us", "outcome", "size", "stage", "ts_ms"], "no address, subject or id can be in a sample");
    }
    #[test] fn utc_days_are_right() {
        assert_eq!(utc_day(0, 0), "1970-01-01");
        assert_eq!(utc_day(1_700_000_000_000, 0), "2023-11-14");
        assert_eq!(utc_day(1_700_000_000_000, 1), "2023-11-13");
        assert_eq!(utc_day(1_709_164_800_000, 1), "2024-02-28");   // 2024-02-29 00:00 UTC minus one day (leap year)
        assert_eq!(utc_day(1_793_000_000_000, 0), "2026-10-26");
    }
    #[tokio::test] async fn a_full_queue_drops_and_counts_and_never_blocks() {
        let (tx, mut rx) = mpsc::channel::<Sample>(2);
        let s = Sample { ts_ms: 1, stage: "total", outcome: "ok", size: "xs", dur_us: 5 };
        let mut dropped = 0; for _ in 0..5 { if tx.try_send(s.clone()).is_err() { dropped += 1; } }
        assert_eq!(dropped, 3);
        let mut out = vec![]; drain(&mut rx, &mut out); assert_eq!(out.len(), 2);
    }
    #[tokio::test] async fn drain_never_takes_more_than_one_batch() {
        let (tx, mut rx) = mpsc::channel::<Sample>(2000);
        for i in 0..1200 { tx.try_send(Sample { ts_ms: i, stage: "seal", outcome: "ok", size: "m", dur_us: 1 }).unwrap(); }
        let mut out = vec![]; drain(&mut rx, &mut out); assert_eq!(out.len(), BATCH_MAX);
        out.clear(); drain(&mut rx, &mut out); assert_eq!(out.len(), BATCH_MAX);
        out.clear(); drain(&mut rx, &mut out); assert_eq!(out.len(), 200);
    }
    #[test] fn the_database_answer_is_read_exactly() {
        assert_eq!(accepted_refused(&json!({"accepted": 3, "rejected": 1}), 4), (3, 1));
        assert_eq!(accepted_refused(&json!({}), 4), (4, 0));
        assert_eq!(accepted_refused(&json!({"accepted": 99, "rejected": 99}), 4), (4, 4));
    }
    #[test] fn record_before_start_is_a_noop() { record("total", "ok", "xs", Instant::now()); }
}
