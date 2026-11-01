//! 4b-2 (founder live data, E109): ONE background tick for the whole process + an SSE stream every browser tab can read.
//! Technology: Rust, tokio (task, interval, broadcast, mpsc). No new database objects: it only calls the E109 functions
//! `founder_live_tick`, `founder_live_snapshot` and `founder_live_since`. Every frame the browser receives is a SIGNED envelope
//! (same Ed25519 as every other answer) so the WASM kernel verifies it before anything is drawn.
//! Honest by construction: a tick that fails is published as `ok:false`; nothing is guessed or replayed as "fresh".
use crate::data::Sb;
use axum::body::Bytes;
use futures_core::Stream;
use serde_json::{Value, json};
use std::{convert::Infallible, pin::Pin, sync::{Arc, OnceLock, atomic::{AtomicUsize, Ordering}}, task::{Context, Poll}, time::Duration};
use tokio::sync::{broadcast, mpsc};

pub const TICK_EVERY: Duration = Duration::from_secs(5);
pub const HEARTBEAT: Duration = Duration::from_secs(15);
pub const MAX_STREAMS: usize = 20;
pub const MAX_LIFETIME: Duration = Duration::from_secs(600);

#[derive(Clone, Debug, PartialEq)]
pub struct Tick { pub version: i64, pub changed: Vec<String>, pub at_s: i64, pub ok: bool }

pub struct Hub { pub tx: broadcast::Sender<Tick>, pub last: std::sync::Mutex<Option<Tick>>, pub streams: AtomicUsize }

static HUB: OnceLock<Arc<Hub>> = OnceLock::new();
pub fn hub() -> Arc<Hub> {
    HUB.get_or_init(|| Arc::new(Hub { tx: broadcast::channel(16).0, last: std::sync::Mutex::new(None), streams: AtomicUsize::new(0) })).clone()
}

/// Read the answer of `founder_live_tick`. None if it is not the shape SQL promises (never invented).
pub fn parse_tick(v: &Value, now_s: i64) -> Option<Tick> {
    let version = v.get("version")?.as_i64()?;
    let changed = v.get("changed").and_then(|c| c.as_array()).map(|a| a.iter().filter_map(|x| x.as_str().map(String::from)).collect()).unwrap_or_default();
    Some(Tick { version, changed, at_s: now_s, ok: true })
}

pub fn tick_json(t: &Tick) -> Value { json!({"version": t.version, "changed": t.changed, "at": t.at_s, "ok": t.ok}) }

/// One SSE frame. `data` must be a single line (compact JSON), so no escaping of newlines is needed.
pub fn sse_frame(id: Option<i64>, event: &str, data: &str) -> String {
    let mut s = String::new();
    if let Some(i) = id { s.push_str(&format!("id: {i}\n")); }
    s.push_str(&format!("event: {event}\ndata: {data}\n\n"));
    s
}

fn now_s() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }

/// Start the single process-wide tick. Safe to call once from main. FOUNDER_LIVE_TICK=off disables it (rollback switch).
/// E111 telemetry on? `FOUNDER_TELEMETRY=off` is the rollback switch (registry + snapshot_v2 keep working, only the writes stop).
pub fn telemetry_on() -> bool { std::env::var("FOUNDER_TELEMETRY").map(|v| v != "off").unwrap_or(true) }

/// Open a stream session row. None = telemetry off / E111 missing / database slow (2 s cap): never blocks or breaks the stream.
pub async fn session_open(sb: &Sb, kind: &str) -> Option<i64> {
    if !telemetry_on() { return None; }
    let r = tokio::time::timeout(Duration::from_secs(2), sb.rpc("founder_live_session_open", json!({"p_auth_kind": kind}))).await.ok()??;
    r.as_i64()
}

/// Close it with the real reason and frame count. Fire-and-forget (spawned): the closing path never waits for the database.
pub async fn session_close(sb: &Sb, id: Option<i64>, reason: &'static str, frames: i32) {
    let Some(id) = id else { return };
    let sb = sb.clone();
    tokio::spawn(async move { let _ = sb.rpc("founder_live_session_close", json!({"p_id": id, "p_reason": reason, "p_frames": frames})).await; });
}

pub fn start(sb: Sb) {
    if std::env::var("FOUNDER_LIVE_TICK").map(|v| v == "off").unwrap_or(false) { eprintln!("founder: live tick OFF (FOUNDER_LIVE_TICK=off)"); return; }
    let hub = hub();
    tokio::spawn(async move {
        if telemetry_on() { let _ = sb.rpc("founder_live_session_sweep", json!({})).await; } // streams left "open" by a crashed/restarted process -> orphan
        let mut iv = tokio::time::interval(TICK_EVERY);
        iv.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
        let mut fails = 0u32;
        loop {
            iv.tick().await;
            let t0 = std::time::Instant::now();
            let t = match sb.rpc("founder_live_tick", json!({"p_record": true})).await.and_then(|v| parse_tick(&v, now_s())) {
                Some(t) => { if fails > 0 { eprintln!("founder: live tick recovered after {fails} failures"); } fails = 0; t }
                None => { fails += 1; if fails == 1 || fails % 60 == 0 { eprintln!("founder: live tick failed ({fails} in a row) - E109 missing or database not answering"); }
                          Tick { version: hub.last.lock().ok().and_then(|g| g.as_ref().map(|x| x.version)).unwrap_or(0), changed: vec![], at_s: now_s(), ok: false } }
            };
            if telemetry_on() {
                let (sb2, ok, ms) = (sb.clone(), t.ok, t0.elapsed().as_millis().min(600_000) as i64);
                tokio::spawn(async move { let _ = sb2.rpc("founder_live_tick_report", json!({"p_ok": ok, "p_ms": ms})).await; });
            }
            if let Ok(mut g) = hub.last.lock() { *g = Some(t.clone()); }
            let _ = hub.tx.send(t); // Err = nobody is listening: fine
        }
    });
    eprintln!("founder: live tick ON every {}s", TICK_EVERY.as_secs());
}

/// A byte stream fed by a channel (no extra crates): the response body of the SSE endpoint.
pub struct RxStream(pub mpsc::Receiver<Bytes>);
impl Stream for RxStream {
    type Item = Result<Bytes, Infallible>;
    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        self.0.poll_recv(cx).map(|o| o.map(Ok))
    }
}

/// RAII counter so a dropped client always frees its slot.
pub struct Slot(Arc<Hub>);
impl Slot {
    pub fn take(h: &Arc<Hub>) -> Option<Slot> {
        let n = h.streams.fetch_add(1, Ordering::SeqCst);
        if n >= MAX_STREAMS { h.streams.fetch_sub(1, Ordering::SeqCst); return None; }
        Some(Slot(h.clone()))
    }
}
impl Drop for Slot { fn drop(&mut self) { self.0.streams.fetch_sub(1, Ordering::SeqCst); } }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parses_the_sql_shape_and_refuses_other_shapes() {
        let t = parse_tick(&json!({"version": 7, "changed": ["mail_outbox","leads"], "recorded": 3}), 100).unwrap();
        assert_eq!((t.version, t.changed.len(), t.at_s, t.ok), (7, 2, 100, true));
        assert_eq!(parse_tick(&json!({"version": 0}), 1).unwrap().changed.len(), 0);
        assert!(parse_tick(&json!(null), 1).is_none());
        assert!(parse_tick(&json!({"note": "x"}), 1).is_none());
    }
    #[test]
    fn sse_frame_is_wire_correct() {
        assert_eq!(sse_frame(Some(5), "tick", "{\"a\":1}"), "id: 5\nevent: tick\ndata: {\"a\":1}\n\n");
        assert_eq!(sse_frame(None, "hello", "{}"), "event: hello\ndata: {}\n\n");
    }
    #[tokio::test]
    async fn broadcast_reaches_every_listener_and_stream_slots_are_capped_and_freed() {
        let h = Arc::new(Hub { tx: broadcast::channel(16).0, last: std::sync::Mutex::new(None), streams: AtomicUsize::new(0) });
        let (mut a, mut b) = (h.tx.subscribe(), h.tx.subscribe());
        h.tx.send(Tick { version: 3, changed: vec![], at_s: 1, ok: true }).unwrap();
        assert_eq!(a.recv().await.unwrap().version, 3);
        assert_eq!(b.recv().await.unwrap().version, 3);
        let slots: Vec<_> = (0..MAX_STREAMS).map(|_| Slot::take(&h).unwrap()).collect();
        assert!(Slot::take(&h).is_none(), "21st stream must be refused");
        drop(slots);
        assert_eq!(h.streams.load(Ordering::SeqCst), 0);
        assert!(Slot::take(&h).is_some());
    }
    #[tokio::test]
    async fn rx_stream_yields_what_was_sent_then_ends() {
        use std::future::poll_fn;
        let (tx, rx) = mpsc::channel(2);
        let mut s = RxStream(rx);
        tx.send(Bytes::from("x")).await.unwrap();
        drop(tx);
        let first = poll_fn(|cx| Pin::new(&mut s).poll_next(cx)).await;
        assert_eq!(first.unwrap().unwrap(), Bytes::from("x"));
        assert!(poll_fn(|cx| Pin::new(&mut s).poll_next(cx)).await.is_none());
    }
}
