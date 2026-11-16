//! SYS-LIVE (his 16 Nov 07:10 order): the Systems page shows a LIVE pulse of the running Rust process, not a file written at build time.
//! Technology: Rust + Tokio (RuntimeMetrics: workers, alive tasks, queue depth), axum, the kernel-signed answer (the WASM kernel verifies the Ed25519 envelope), server clock inside the signed body.
//! Honest by construction: every number is read at the moment of the request; a value that cannot be read is null, never 0 and never replayed.
use serde_json::{Value, json};
use std::sync::OnceLock;
use std::time::{Instant, SystemTime, UNIX_EPOCH};

static SEQ: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static START: OnceLock<(Instant, u128)> = OnceLock::new();
/// Called once at boot so uptime counts from the real start.
pub fn mark_start() { START.get_or_init(|| (Instant::now(), now_ms())); }
pub fn now_ms() -> u128 { SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis()).unwrap_or(0) }
pub fn build() -> &'static str { option_env!("ANX_BUILD").unwrap_or("unknown") }
pub fn build_time() -> &'static str { option_env!("ANX_BUILD_TIME").unwrap_or("unknown") }

/// Pure: the body of the pulse from the facts (testable without a server).
pub fn body(seq: u64, now_ms: u128, started_ms: u128, up_s: u64, build: &str, build_time: &str, workers: usize, alive: usize, queue: usize, db_ms: Option<u64>, sending: Option<Value>) -> Value {
    json!({
        "connected": true, "seq": seq, "now_ms": now_ms as u64, "started_ms": started_ms as u64, "uptime_s": up_s,
        "build": build, "build_time": build_time,
        "tokio": { "workers": workers, "alive_tasks": alive, "queue_depth": queue },
        "db_ms": db_ms, "sending": sending,
    })
}

pub async fn read(sb: Option<&crate::data::Sb>) -> Value {
    let (t0, s_ms) = *START.get_or_init(|| (Instant::now(), now_ms()));
    let m = tokio::runtime::Handle::current().metrics();
    let (db_ms, sending) = match sb {
        Some(sb) => { let t = Instant::now(); let r = sb.rpc("fmail_sending_state182", json!({})).await; let ms = t.elapsed().as_millis() as u64; match r { Some(v) if v.is_object() => (Some(ms), Some(v)), _ => (None, None) } }
        None => (None, None),
    };
    body(SEQ.fetch_add(1, std::sync::atomic::Ordering::Relaxed) + 1, now_ms(), s_ms, t0.elapsed().as_secs(), build(), build_time(), m.num_workers(), m.num_alive_tasks(), m.global_queue_depth(), db_ms, sending)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn body_has_the_facts_and_nulls_stay_null() {
        let b = body(5, 1_700_000_000_123, 1_700_000_000_000, 7, "abc1234", "t", 4, 9, 0, None, None);
        assert_eq!(b["uptime_s"], 7); assert_eq!(b["seq"], 5); assert_eq!(b["build"], "abc1234"); assert_eq!(b["tokio"]["alive_tasks"], 9); assert!(b["db_ms"].is_null()); assert!(b["sending"].is_null());
        assert_eq!(b["now_ms"], 1_700_000_000_123u64);
    }
    #[test] fn build_is_unknown_without_the_env() { if option_env!("ANX_BUILD").is_none() { assert_eq!(build(), "unknown"); } }
    #[tokio::test] async fn read_without_a_database_answers_honestly() { mark_start(); let v = read(None).await; assert!(v["db_ms"].is_null() && v["sending"].is_null()); assert!(v["tokio"]["workers"].as_u64().unwrap() >= 1); }
}
