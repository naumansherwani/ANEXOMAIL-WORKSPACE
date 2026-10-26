//! Host-backed (browser) implementations: WebTransport JS ke paas, Rust usay `sys` ABI se chalata hai.
use crate::exec::{self, Reply};
use crate::live::{Host, Sink, Transport};
use crate::sys;
use std::cell::Cell;

fn le_u32(d: &[u8]) -> Option<u32> {
    Some(u32::from_le_bytes(d.get(..4)?.try_into().ok()?))
}

pub async fn call(op: u32, handle: u32, data: &[u8]) -> Reply {
    let owned = data.to_vec(); // host_call ke dauran buffer zinda rahe
    exec::host_call(|id| sys::call(op, id, handle, &owned)).await
}

pub struct WtTransport {
    session: u32,
    stream: u32,
}
impl WtTransport {
    pub fn new() -> Self {
        Self { session: 0, stream: 0 }
    }
}
impl Transport for WtTransport {
    async fn open(&mut self, url: &str) -> Result<(), String> {
        let r = call(sys::OP_CONNECT, 0, url.as_bytes()).await;
        self.session = (r.status == 0).then(|| le_u32(&r.data)).flatten().ok_or("connect failed")?;
        let b = call(sys::OP_BIDI, self.session, &[]).await;
        self.stream = (b.status == 0).then(|| le_u32(&b.data)).flatten().ok_or("stream failed")?;
        Ok(())
    }
    async fn write(&mut self, data: &[u8]) -> Result<(), String> {
        (call(sys::OP_WRITE, self.stream, data).await.status == 0).then_some(()).ok_or_else(|| "write failed".to_string())
    }
    async fn read(&mut self) -> Result<Option<Vec<u8>>, String> {
        let r = call(sys::OP_READ, self.stream, &[]).await;
        match r.status {
            0 if r.data.is_empty() => Ok(None),
            0 => Ok(Some(r.data)),
            _ => Err("read failed".into()),
        }
    }
    fn close(&mut self) {
        // fire-and-forget: jawab ka intezar nahi
        if self.session != 0 {
            sys::call(sys::OP_CLOSE, 0, self.session, &[]);
            self.session = 0;
            self.stream = 0;
        }
    }
}

pub struct HostEnv {
    seed: Cell<u32>,
}
impl HostEnv {
    pub fn new(seed: u32) -> Self {
        Self { seed: Cell::new(seed | 1) }
    }
}
impl Host for HostEnv {
    async fn sleep(&self, ms: u64) {
        call(sys::OP_SLEEP, ms.min(u32::MAX as u64) as u32, &[]).await;
    }
    fn rand(&self) -> f64 {
        // xorshift32 — jitter ke liye kaafi; crypto nahi
        let mut x = self.seed.get();
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.seed.set(x);
        (x as f64) / 4_294_967_296.0
    }
}

pub struct HostSink;
impl Sink for HostSink {
    fn state(&self, webtransport: bool, detail: &str) {
        sys::emit(sys::EMIT_LIVE_STATE, webtransport as u32, 0, detail.as_bytes());
    }
    fn event(&self, topic: usize) {
        sys::emit(sys::EMIT_LIVE_EVENT, topic as u32, 0, &[]);
    }
    fn resync(&self) {
        sys::emit(sys::EMIT_LIVE_RESYNC, 0, 0, &[]);
    }
}
