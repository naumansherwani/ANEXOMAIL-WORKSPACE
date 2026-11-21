// ANEXOMAIL ADMIN DESK KERNEL lib.rs (R3d): the browser side of Rule 52 for the Desk. Pure Rust in wire.rs; the WASM exports below are thin.
// The page NEVER trusts a Desk answer by itself: verify_answer() must return the body, or the call is refused.
pub mod wire;
use wasm_bindgen::prelude::*;

/// Build the three request headers (nonce, ts, mac). nonce_hex = 16 random bytes from crypto.getRandomValues (JS), ts = unix seconds.
#[wasm_bindgen]
pub fn request_headers(token: &str, method: &str, path: &str, nonce_hex: &str, ts: f64, body: &str) -> Result<String, JsError> {
    wire::request_headers(token, method, path, nonce_hex, ts as i64, body.as_bytes()).map_err(|e| JsError::new(e))
}

/// Verify a Desk answer envelope against the pinned public key. Returns the BODY string only when the signature, path, method, nonce and clock all match.
#[wasm_bindgen]
pub fn verify_answer(pinned_pub_hex: &str, method: &str, path: &str, nonce_hex: &str, now: f64, envelope: &str) -> Result<String, JsError> {
    wire::verify_answer(pinned_pub_hex, method, path, nonce_hex, now as i64, envelope).map_err(|e| JsError::new(e))
}
