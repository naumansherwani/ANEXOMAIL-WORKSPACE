// ANEXOMAIL ADMIN DESK sign.rs (R3d, 22 Nov 2026): Rule 52 for the Desk. The Desk's OWN Ed25519 answer signature + HMAC request binding.
// Wire format v1 is mirrored by the Desk's own WASM kernel (admin-desk/kernel/src/wire.rs); both carry the SAME known-answer test vector, so a drift fails a test.
// Nothing here is imported from the founder or awam code (DESK ISOLATION LAW). Pure functions: no database, no clock except the one the caller passes.
use ed25519_dalek::{Signer as _, SigningKey};
use hkdf::Hkdf;
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use subtle::ConstantTimeEq;

pub const DOMAIN: &str = "anexo-desk-v1";
pub const SKEW_SECS: i64 = 120;
const NONCE_CAP: usize = 100_000;

pub fn hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
pub fn unhex(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 || !s.bytes().all(|b| b.is_ascii_hexdigit()) { return None; }
    (0..s.len()).step_by(2).map(|i| u8::from_str_radix(&s[i..i + 2], 16).ok()).collect()
}
pub fn sha256_hex(b: &[u8]) -> String { hex(&Sha256::digest(b)) }
pub fn nonce_ok(n: &str) -> bool { n.len() == 32 && n.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f')) }

// The exact bytes both sides sign / MAC: domain, method, path, nonce, ts, SHA-256 of the body.
pub fn message(method: &str, path: &str, nonce: &str, ts: i64, body: &[u8]) -> Vec<u8> {
    format!("{DOMAIN}\n{method}\n{path}\n{nonce}\n{ts}\n{}", sha256_hex(body)).into_bytes()
}

// Request key: HKDF-SHA256 from the session token (never sent again), salt = domain, info = "req-mac".
pub fn req_key(token: &str) -> [u8; 32] {
    let mut k = [0u8; 32];
    Hkdf::<Sha256>::new(Some(DOMAIN.as_bytes()), token.as_bytes()).expand(b"req-mac", &mut k).expect("32 bytes");
    k
}
pub fn req_mac(token: &str, method: &str, path: &str, nonce: &str, ts: i64, body: &[u8]) -> String {
    let mut m = <Hmac<Sha256> as Mac>::new_from_slice(&req_key(token)).expect("hmac key");
    m.update(&message(method, path, nonce, ts, body)); hex(&m.finalize().into_bytes())
}
pub fn verify_req(token: &str, method: &str, path: &str, nonce: &str, ts: i64, body: &[u8], mac_hex: &str, now: i64) -> Result<(), &'static str> {
    if !nonce_ok(nonce) { return Err("bad_nonce"); }
    if (now - ts).abs() > SKEW_SECS { return Err("stale_request"); }
    let want = req_mac(token, method, path, nonce, ts, body);
    if mac_hex.len() == want.len() && bool::from(want.as_bytes().ct_eq(mac_hex.as_bytes())) { Ok(()) } else { Err("bad_mac") }
}

// Replay guard: a (token-hash, nonce) pair is accepted once inside the skew window.
#[derive(Default)] pub struct NonceCache(HashMap<String, i64>);
impl NonceCache {
    pub fn fresh(&mut self, who: &str, nonce: &str, now: i64) -> bool {
        self.0.retain(|_, t| now - *t <= SKEW_SECS * 2);
        if self.0.len() >= NONCE_CAP { return false; }
        self.0.insert(format!("{who}:{nonce}"), now).is_none()
    }
}

pub struct Signer { key: SigningKey }
impl Signer {
    pub fn from_seed_hex(s: &str) -> Result<Self, String> {
        let b = unhex(s.trim()).filter(|b| b.len() == 32).ok_or("DESK_SIGN_SEED must be 64 hex characters (32 bytes)")?;
        let mut a = [0u8; 32]; a.copy_from_slice(&b); Ok(Signer { key: SigningKey::from_bytes(&a) })
    }
    pub fn public_hex(&self) -> String { hex(self.key.verifying_key().as_bytes()) }
    pub fn kid(&self) -> String { sha256_hex(self.key.verifying_key().as_bytes())[..16].to_string() }
    // Envelope: the body travels as a STRING so the exact signed bytes arrive; the kernel refuses anything else.
    pub fn envelope(&self, method: &str, path: &str, nonce: &str, ts: i64, body: &str) -> String {
        let sig = hex(&self.key.sign(&message(method, path, nonce, ts, body.as_bytes())).to_bytes());
        serde_json::json!({"v":1,"kid":self.kid(),"nonce":nonce,"ts":ts,"body":body,"sig":sig}).to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    const SEED: &str = "0101010101010101010101010101010101010101010101010101010101010101";
    const NONCE: &str = "000102030405060708090a0b0c0d0e0f";
    #[test] fn message_layout_is_fixed() {
        let m = String::from_utf8(message("GET", "/desk/v1/sig/ping", NONCE, 1000, b"")).unwrap();
        assert_eq!(m, format!("anexo-desk-v1\nGET\n/desk/v1/sig/ping\n{NONCE}\n1000\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"));
    }
    #[test] fn request_mac_accepts_good_refuses_altered_stale_and_replay() {
        let t = "ab".repeat(32); let mac = req_mac(&t, "GET", "/desk/v1/sig/ping", NONCE, 1000, b"");
        assert_eq!(verify_req(&t, "GET", "/desk/v1/sig/ping", NONCE, 1000, b"", &mac, 1010), Ok(()));
        assert_eq!(verify_req(&t, "GET", "/desk/v1/other", NONCE, 1000, b"", &mac, 1010), Err("bad_mac"));
        assert_eq!(verify_req(&t, "POST", "/desk/v1/sig/ping", NONCE, 1000, b"", &mac, 1010), Err("bad_mac"));
        assert_eq!(verify_req(&t, "GET", "/desk/v1/sig/ping", NONCE, 1000, b"x", &mac, 1010), Err("bad_mac"));
        assert_eq!(verify_req(&"cd".repeat(32), "GET", "/desk/v1/sig/ping", NONCE, 1000, b"", &mac, 1010), Err("bad_mac"));
        assert_eq!(verify_req(&t, "GET", "/desk/v1/sig/ping", NONCE, 1000, b"", &mac, 1000 + SKEW_SECS + 1), Err("stale_request"));
        assert_eq!(verify_req(&t, "GET", "/desk/v1/sig/ping", "zz", 1000, b"", &mac, 1010), Err("bad_nonce"));
        let mut c = NonceCache::default(); assert!(c.fresh("w", NONCE, 1000)); assert!(!c.fresh("w", NONCE, 1001)); assert!(c.fresh("w2", NONCE, 1001));
    }
    #[test] fn envelope_verifies_with_dalek_and_tamper_fails() {
        use ed25519_dalek::{Signature, Verifier, VerifyingKey};
        let s = Signer::from_seed_hex(SEED).unwrap(); let env: serde_json::Value = serde_json::from_str(&s.envelope("GET", "/desk/v1/sig/ping", NONCE, 1000, "{\"pong\":1}")).unwrap();
        let vk = VerifyingKey::from_bytes(&unhex(&s.public_hex()).unwrap().try_into().unwrap()).unwrap();
        let sig = Signature::from_slice(&unhex(env["sig"].as_str().unwrap()).unwrap()).unwrap();
        assert!(vk.verify(&message("GET", "/desk/v1/sig/ping", NONCE, 1000, env["body"].as_str().unwrap().as_bytes()), &sig).is_ok());
        assert!(vk.verify(&message("GET", "/desk/v1/sig/ping", NONCE, 1000, b"{\"pong\":2}"), &sig).is_err());
        assert!(vk.verify(&message("GET", "/desk/v1/other", NONCE, 1000, env["body"].as_str().unwrap().as_bytes()), &sig).is_err());
        assert_eq!(env["kid"].as_str().unwrap().len(), 16);
    }
    #[test] fn seed_must_be_32_bytes_hex() { assert!(Signer::from_seed_hex("00").is_err()); assert!(Signer::from_seed_hex("zz".repeat(32).as_str()).is_err()); assert!(Signer::from_seed_hex(SEED).is_ok()); }
}
