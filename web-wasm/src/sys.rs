//! Host (JS) ke saath seema. wasm32 mein asli `extern "C"` imports; native tests mein kuch nahi karta (tests Transport/Host/Sink mock karte hain).

#[cfg(target_arch = "wasm32")]
mod imp {
    #[link(wasm_import_module = "env")]
    unsafe extern "C" {
        pub fn host_wake();
        /// op, req_id, handle, ptr, len — jawab `kernel_host_complete(req_id, status, ptr, len)` se.
        pub fn host_call(op: u32, req_id: u32, handle: u32, ptr: u32, len: u32);
        /// kind, a, b, ptr, len — JS ko khabar (events, rpc jawab).
        pub fn host_emit(kind: u32, a: u32, b: u32, ptr: u32, len: u32);
    }
}

pub const OP_CONNECT: u32 = 1; // url -> session handle (4 bytes LE)
pub const OP_BIDI: u32 = 2; // handle=session -> stream handle (4 bytes LE)
pub const OP_WRITE: u32 = 3; // handle=stream, bytes
pub const OP_READ: u32 = 4; // handle=stream -> chunk; status 0 + khali = EOF
pub const OP_FINISH: u32 = 5; // handle=stream: likhna band
pub const OP_CLOSE: u32 = 6; // handle=stream ya session
pub const OP_SLEEP: u32 = 7; // handle=ms

pub const EMIT_LIVE_STATE: u32 = 1; // a=1 webtransport / 0 poll, data=detail
pub const EMIT_LIVE_EVENT: u32 = 2; // a=topic index
pub const EMIT_LIVE_RESYNC: u32 = 3;
pub const EMIT_RPC_STATE: u32 = 4; // a=1 up / 0 down
pub const EMIT_RPC_DONE: u32 = 5; // a=call id, b=status, data=jawab

#[cfg(target_arch = "wasm32")]
pub fn wake() {
    unsafe { imp::host_wake() }
}
#[cfg(not(target_arch = "wasm32"))]
pub fn wake() {}

#[cfg(target_arch = "wasm32")]
pub fn call(op: u32, req_id: u32, handle: u32, data: &[u8]) {
    unsafe { imp::host_call(op, req_id, handle, data.as_ptr() as u32, data.len() as u32) }
}
#[cfg(not(target_arch = "wasm32"))]
pub fn call(_op: u32, _req_id: u32, _handle: u32, _data: &[u8]) {}

#[cfg(target_arch = "wasm32")]
pub fn emit(kind: u32, a: u32, b: u32, data: &[u8]) {
    unsafe { imp::host_emit(kind, a, b, data.as_ptr() as u32, data.len() as u32) }
}
#[cfg(not(target_arch = "wasm32"))]
pub fn emit(_kind: u32, _a: u32, _b: u32, _data: &[u8]) {}
