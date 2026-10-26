//! Module `rpc@1` — poori website ke liye EK WebTransport/QUIC connection, EK generic call. Alag endpoint/page ka code nahi:
//! har proc (jo server ke /rpc/<proc> par hai) isi se guzarta hai; server par ek hi `/wt/rpc` wohi dispatcher chalata hai.
//! Har call = ek naya bidi stream (QUIC mein sasta, ek doosre ko block nahi karta): request bytes likho, finish, jawab EOF tak padho.
//! Kernel bytes ko opaque rakhta hai: request {"token","proc","input"} aur jawab {"status":N,"body":..} JS (src/lib/kernel) banata/padhta hai.
use crate::exec;
use crate::frame;
use crate::host::call;
use crate::sys;
use std::cell::Cell;
use std::rc::Rc;
use tokio::sync::Notify;

pub const MAX_REQUEST: usize = 1 << 20; // 1 MiB — server bhi yahi rokta hai
pub const MAX_RESPONSE: usize = 8 << 20; // 8 MiB

pub const ST_OK: i32 = 200;
pub const ST_UNAVAILABLE: i32 = 503; // session nahi — JS plain fetch par jaye
pub const ST_TOO_BIG: i32 = 413;

#[derive(Default)]
struct State {
    session: Cell<u32>,
    stop: Cell<bool>,
    started: Cell<bool>,
    down: Notify,
}

thread_local! { static RPC: Rc<State> = Rc::new(State::default()); }

fn state() -> Rc<State> {
    RPC.with(|s| s.clone())
}

fn le_u32(d: &[u8]) -> Option<u32> {
    Some(u32::from_le_bytes(d.get(..4)?.try_into().ok()?))
}

pub fn is_up() -> bool {
    state().session.get() != 0
}

/// Supervisor: connect -> up -> (call ne session gira di / server ne band kiya) -> backoff -> dobara. Ek hi baar shuru hota hai.
pub fn start(base_url: &str, seed: u32) {
    let st = state();
    if st.started.replace(true) {
        return;
    }
    st.stop.set(false);
    let url = format!("{}/wt/rpc", base_url.trim_end_matches('/'));
    let env = crate::host::HostEnv::new(seed);
    exec::spawn(async move {
        use crate::live::Host;
        let mut attempt = 0u32;
        while !st.stop.get() {
            let r = call(sys::OP_CONNECT, 0, url.as_bytes()).await;
            match (r.status == 0).then(|| le_u32(&r.data)).flatten() {
                Some(h) => {
                    st.session.set(h);
                    attempt = 0;
                    sys::emit(sys::EMIT_RPC_STATE, 1, 0, &[]);
                    st.down.notified().await; // koi call ya host ne session gira diya
                    let dead = st.session.replace(0);
                    sys::emit(sys::EMIT_RPC_STATE, 0, 0, &[]);
                    if dead != 0 {
                        sys::call(sys::OP_CLOSE, 0, dead, &[]);
                    }
                }
                None => {
                    sys::emit(sys::EMIT_RPC_STATE, 0, 0, &[]);
                }
            }
            if st.stop.get() {
                break;
            }
            let wait = frame::backoff_ms(attempt, env.rand());
            attempt = attempt.saturating_add(1);
            call(sys::OP_SLEEP, wait.min(u32::MAX as u64) as u32, &[]).await;
        }
        st.started.set(false);
    });
}

pub fn stop() {
    let st = state();
    st.stop.set(true);
    st.down.notify_one();
}

/// Session ko foran gira do (host ne dekha ke connection mar gaya).
pub fn mark_down() {
    state().down.notify_one();
}

/// Ek call. Jawab `EMIT_RPC_DONE(call_id, status, bytes)` se JS tak jata hai; kabhi hang nahi (session nahi to foran 503).
pub fn call_bytes(call_id: u32, request: Vec<u8>) {
    if request.is_empty() || request.len() > MAX_REQUEST {
        sys::emit(sys::EMIT_RPC_DONE, call_id, ST_TOO_BIG as u32, &[]);
        return;
    }
    let st = state();
    exec::spawn(async move {
        let session = st.session.get();
        if session == 0 {
            sys::emit(sys::EMIT_RPC_DONE, call_id, ST_UNAVAILABLE as u32, &[]);
            return;
        }
        let (status, body) = exchange(session, &request).await.unwrap_or_else(|dead| {
            if dead {
                st.down.notify_one();
            }
            (ST_UNAVAILABLE, Vec::new())
        });
        sys::emit(sys::EMIT_RPC_DONE, call_id, status as u32, &body);
    });
}

/// Err(true) = session mar gaya; Err(false) = sirf yeh stream kharab.
async fn exchange(session: u32, request: &[u8]) -> Result<(i32, Vec<u8>), bool> {
    let b = call(sys::OP_BIDI, session, &[]).await;
    let stream = (b.status == 0).then(|| le_u32(&b.data)).flatten().ok_or(true)?;
    let result = async {
        if call(sys::OP_WRITE, stream, request).await.status != 0 {
            return Err(false);
        }
        if call(sys::OP_FINISH, stream, &[]).await.status != 0 {
            return Err(false);
        }
        let mut out: Vec<u8> = Vec::new();
        loop {
            let r = call(sys::OP_READ, stream, &[]).await;
            if r.status != 0 {
                return Err(false);
            }
            if r.data.is_empty() {
                return Ok((ST_OK, out));
            }
            if out.len() + r.data.len() > MAX_RESPONSE {
                return Ok((ST_TOO_BIG, Vec::new()));
            }
            out.extend_from_slice(&r.data);
        }
    }
    .await;
    sys::call(sys::OP_CLOSE, 0, stream, &[]);
    result
}
