//! ANEXOMAIL WASM KERNEL — ek kernel, andar modules (Rule 52). Rust async + Tokio (LocalSet) -> wasm32; WebTransport/QUIC browser ka, Rust usay chalata hai.
//! Naya client-side-heavy feature = naya module yahin + MODULES mein entry + VERSION bump. Bikhri hui wasm files nahi.
//!
//! ABI (version 1): sab kuch plain `extern "C"` — wasm-bindgen nahi. JS ke liye src/lib/kernel/ (loader + typed API).
//!   memory      : kernel_alloc/kernel_free (JS bytes andar rakhta hai), kernel_out_ptr/len (jawab bytes)
//!   sync modules: sha256_*, sniff_check, rank_run
//!   async       : kernel_tick (executor), kernel_host_complete (JS ka jawab), live_*, rpc_*
//!   JS imports  : env.host_wake / env.host_call / env.host_emit (sys.rs)
#![allow(async_fn_in_trait)] // Transport/Host/Sink sirf is crate ke andar, ek thread (LocalSet) — Send bound ki zaroorat nahi
pub mod exec;
pub mod frame;
pub mod hash;
pub mod intent;
pub mod host;
pub mod live;
pub mod rank;
pub mod rpc;
pub mod sniff;
pub mod sys;

use std::cell::{Cell, RefCell};
use std::collections::HashMap;
use std::rc::Rc;

pub const ABI: u32 = 1;
pub const VERSION: (u32, u32, u32) = (0, 3, 0);
/// Naam@module-version. Naya module ya badla hua module => yahan entry + VERSION bump (Cargo.toml bhi).
pub const MODULES: &[&str] = &["sha256@1", "hmac@1", "sniff@1", "rank@1", "live@1", "rpc@1", "intent@1"];

thread_local! {
    static OUT: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
    static LIVES: RefCell<HashMap<u32, Live>> = RefCell::new(HashMap::new());
    static NEXT_LIVE: Cell<u32> = const { Cell::new(1) };
}

struct Live {
    cfg: Rc<RefCell<live::Cfg>>,
    stop: Rc<Cell<bool>>,
}

fn set_out(b: Vec<u8>) -> u32 {
    OUT.with(|o| {
        let n = b.len() as u32;
        *o.borrow_mut() = b;
        n
    })
}

pub fn info_json() -> String {
    let mods = MODULES.iter().map(|m| format!("\"{m}\"")).collect::<Vec<_>>().join(",");
    format!("{{\"kernel\":\"anexo-kernel\",\"version\":\"{}.{}.{}\",\"abi\":{ABI},\"modules\":[{mods}]}}", VERSION.0, VERSION.1, VERSION.2)
}

/// SAFETY: JS ne `kernel_alloc` se di hui [ptr, ptr+len) memory dI hai.
unsafe fn bytes<'a>(ptr: u32, len: u32) -> &'a [u8] {
    if len == 0 { &[] } else { unsafe { std::slice::from_raw_parts(ptr as usize as *const u8, len as usize) } }
}
unsafe fn text<'a>(ptr: u32, len: u32) -> &'a str {
    std::str::from_utf8(unsafe { bytes(ptr, len) }).unwrap_or("")
}

/* ------------------------------------------------------------------ memory */
#[unsafe(no_mangle)]
pub extern "C" fn kernel_alloc(len: u32) -> u32 {
    let mut v: Vec<u8> = Vec::with_capacity(len.max(1) as usize);
    let p = v.as_mut_ptr();
    std::mem::forget(v);
    p as usize as u32
}
#[unsafe(no_mangle)]
pub extern "C" fn kernel_free(ptr: u32, len: u32) {
    if ptr != 0 {
        unsafe { drop(Vec::from_raw_parts(ptr as usize as *mut u8, 0, len.max(1) as usize)) }
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn kernel_out_ptr() -> u32 {
    OUT.with(|o| o.borrow().as_ptr() as usize as u32)
}
#[unsafe(no_mangle)]
pub extern "C" fn kernel_out_len() -> u32 {
    OUT.with(|o| o.borrow().len() as u32)
}
#[unsafe(no_mangle)]
pub extern "C" fn kernel_abi() -> u32 {
    ABI
}
/// JSON {kernel, version, abi, modules[]} -> out buffer; length wapas.
#[unsafe(no_mangle)]
pub extern "C" fn kernel_info() -> u32 {
    set_out(info_json().into_bytes())
}

/* --------------------------------------------------------------- executor */
#[unsafe(no_mangle)]
pub extern "C" fn kernel_tick() {
    exec::tick();
}
#[unsafe(no_mangle)]
pub extern "C" fn kernel_host_complete(req_id: u32, status: i32, ptr: u32, len: u32) -> u32 {
    exec::complete(req_id, status, unsafe { bytes(ptr, len) }.to_vec()) as u32
}

/* ------------------------------------------------------------------ sha256 */
#[unsafe(no_mangle)]
pub extern "C" fn sha256_new() -> u32 {
    hash::new_hasher()
}
#[unsafe(no_mangle)]
pub extern "C" fn sha256_update(h: u32, ptr: u32, len: u32) -> u32 {
    hash::update(h, unsafe { bytes(ptr, len) }) as u32
}
/// 32 bytes out buffer mein; wapas 32 (0 = bura handle).
#[unsafe(no_mangle)]
pub extern "C" fn sha256_finish(h: u32) -> u32 {
    match hash::finish(h) {
        Some(d) => set_out(d.to_vec()),
        None => 0,
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn sha256_drop(h: u32) {
    hash::drop_hasher(h)
}

/* -------------------------------------------------------------- hmac-sha256 */
/// HMAC-SHA256(key, msg): 32 bytes out buffer mein; wapas 32.
#[unsafe(no_mangle)]
pub extern "C" fn hmac_sha256(kp: u32, kl: u32, mp: u32, ml: u32) -> u32 {
    set_out(hash::hmac_sha256(unsafe { bytes(kp, kl) }, unsafe { bytes(mp, ml) }).to_vec())
}
/// 1 = tag sahi (constant-time), 0 = nahi.
#[unsafe(no_mangle)]
pub extern "C" fn hmac_verify(kp: u32, kl: u32, mp: u32, ml: u32, tp: u32, tl: u32) -> u32 {
    hash::hmac_verify(unsafe { bytes(kp, kl) }, unsafe { bytes(mp, ml) }, unsafe { bytes(tp, tl) }) as u32
}

/* -------------------------------------------------------------- sniff/rank */
#[unsafe(no_mangle)]
pub extern "C" fn sniff_check(name_ptr: u32, name_len: u32, head_ptr: u32, head_len: u32) -> i32 {
    sniff::check(unsafe { text(name_ptr, name_len) }, unsafe { bytes(head_ptr, head_len) })
}
/// Indices (u32 LE, best-pehle) out buffer mein; wapas gintI.
#[unsafe(no_mangle)]
pub extern "C" fn rank_run(q_ptr: u32, q_len: u32, items_ptr: u32, items_len: u32, limit: u32) -> u32 {
    let idx = rank::rank(unsafe { text(q_ptr, q_len) }, unsafe { text(items_ptr, items_len) }, limit as usize);
    let n = idx.len() as u32;
    set_out(idx.iter().flat_map(|i| i.to_le_bytes()).collect());
    n
}

/* -------------------------------------------------------------------- intent (wada + deadline, paisa/waqt) */
/// Text mein wade dhoondo. `now_unix` UTC seconds, `tz_min` user ka UTC se farq. Jawab JSON bytes (kernel_out), length wapas.
#[unsafe(no_mangle)]
pub extern "C" fn intent_scan(ptr: u32, len: u32, now_unix: i64, tz_min: i32) -> u32 {
    set_out(intent::scan_json(unsafe { text(ptr, len) }, now_unix, tz_min).into_bytes())
}

/// Email ka waqt/paisa: words x recipients x rate (minor unit/ghanta). wpm 0 => default.
#[unsafe(no_mangle)]
pub extern "C" fn intent_cost(words: u32, recipients: u32, rate_minor_per_hour: u32, wpm: u32) -> u32 {
    set_out(intent::cost_json(words, recipients, rate_minor_per_hour, wpm).into_bytes())
}

/* -------------------------------------------------------------------- live */
#[unsafe(no_mangle)]
pub extern "C" fn live_start(url_ptr: u32, url_len: u32, tok_ptr: u32, tok_len: u32, seed: u32) -> u32 {
    let cfg = Rc::new(RefCell::new(live::Cfg { url: unsafe { text(url_ptr, url_len) }.to_string(), token: unsafe { text(tok_ptr, tok_len) }.to_string() }));
    let stop = Rc::new(Cell::new(false));
    let id = NEXT_LIVE.with(|n| {
        let id = n.get();
        n.set(id + 1);
        id
    });
    LIVES.with(|l| l.borrow_mut().insert(id, Live { cfg: cfg.clone(), stop: stop.clone() }));
    exec::spawn(async move {
        live::run(cfg, host::WtTransport::new, host::HostEnv::new(seed), host::HostSink, stop).await;
    });
    id
}
#[unsafe(no_mangle)]
pub extern "C" fn live_set_token(h: u32, tok_ptr: u32, tok_len: u32) {
    LIVES.with(|l| {
        if let Some(x) = l.borrow().get(&h) {
            x.cfg.borrow_mut().token = unsafe { text(tok_ptr, tok_len) }.to_string();
        }
    })
}
#[unsafe(no_mangle)]
pub extern "C" fn live_stop(h: u32) {
    LIVES.with(|l| {
        if let Some(x) = l.borrow_mut().remove(&h) {
            x.stop.set(true);
        }
    });
    exec::spawn(async {}); // ek tick: soye hue loop ko jagao
}

/* --------------------------------------------------------------------- rpc */
#[unsafe(no_mangle)]
pub extern "C" fn rpc_start(url_ptr: u32, url_len: u32, seed: u32) {
    rpc::start(unsafe { text(url_ptr, url_len) }, seed);
}
#[unsafe(no_mangle)]
pub extern "C" fn rpc_stop() {
    rpc::stop();
}
#[unsafe(no_mangle)]
pub extern "C" fn rpc_mark_down() {
    rpc::mark_down();
}
#[unsafe(no_mangle)]
pub extern "C" fn rpc_is_up() -> u32 {
    rpc::is_up() as u32
}
/// Jawab `host_emit(EMIT_RPC_DONE, call_id, status, bytes)` se aata hai.
#[unsafe(no_mangle)]
pub extern "C" fn rpc_call(call_id: u32, ptr: u32, len: u32) {
    rpc::call_bytes(call_id, unsafe { bytes(ptr, len) }.to_vec());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn info_lists_every_module_and_matches_cargo() {
        let j = frame::flat_strings(&info_json()).unwrap();
        let ver = j.iter().find(|(k, _)| k == "version").unwrap().1.clone();
        assert_eq!(ver, env!("CARGO_PKG_VERSION"), "VERSION bump Cargo.toml ke saath");
        assert!(info_json().contains("\"abi\":1"));
        for m in ["sha256@1", "hmac@1", "sniff@1", "rank@1", "live@1", "rpc@1", "intent@1"] {
            assert!(info_json().contains(m), "{m}");
        }
    }

    #[test]
    fn out_buffer_roundtrip() {
        assert_eq!(set_out(vec![1, 2, 3]), 3);
        assert_eq!(kernel_out_len(), 3);
    }
}
