//! Har founder jawab par HMAC-SHA256: sig = HMAC(key, "<ts>.<sha256hex(data)>"). WASM kernel (Rule 52) browser mein yahi verify karta hai;
//! sig na mile/ghalat ho to jawab screen par nahi aata (enforce).
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD as B64};
use hmac::{Hmac, Mac};
use ring::{hkdf, rand::SystemRandom, signature::{ED25519, Ed25519KeyPair, KeyPair, UnparsedPublicKey}};
use sha2::{Digest, Sha256};

/// The one message every signature covers: "<ts>.<sha256hex(data_json)>".
pub fn message(ts: i64, data_json: &str) -> String { format!("{}.{}", ts, hex::encode(Sha256::digest(data_json.as_bytes()))) }

// ---- F2a: Ed25519 (server -> browser). Private key = file 0400 on the server; the browser kernel (F2b) holds only the public key. ----
pub struct EdKeys { pair: Ed25519KeyPair }
pub const ED_KID: &str = "s1";
impl EdKeys {
    pub fn generate_pkcs8() -> Option<Vec<u8>> { Ed25519KeyPair::generate_pkcs8(&SystemRandom::new()).ok().map(|d| d.as_ref().to_vec()) }
    pub fn from_pkcs8(der: &[u8]) -> Option<EdKeys> { Ed25519KeyPair::from_pkcs8(der).ok().map(|pair| EdKeys { pair }) }
    pub fn sign(&self, ts: i64, data_json: &str) -> String { B64.encode(self.pair.sign(message(ts, data_json).as_bytes()).as_ref()) }
    pub fn public_b64(&self) -> String { B64.encode(self.pair.public_key().as_ref()) }
}
pub fn ed_verify(public_b64: &str, ts: i64, data_json: &str, sig_b64: &str) -> bool {
    let (Ok(p), Ok(s)) = (B64.decode(public_b64), B64.decode(sig_b64)) else { return false };
    UnparsedPublicKey::new(&ED25519, p).verify(message(ts, data_json).as_bytes(), &s).is_ok()
}

// ---- F2a: request integrity (browser -> server). Per-token key via HKDF; the browser gets it once, in the exchange answer (TLS), memory only. ----
struct Len(usize);
impl hkdf::KeyType for Len { fn len(&self) -> usize { self.0 } }
/// key = HKDF-SHA256(salt = server secret, ikm = sha256(founder token), info = "anexo-founder-req-v1"). Dies with the token (15 min).
pub fn req_key(master: &[u8], token: &str) -> [u8; 32] {
    let ikm = Sha256::digest(token.as_bytes());
    let mut out = [0u8; 32];
    hkdf::Salt::new(hkdf::HKDF_SHA256, master).extract(&ikm).expand(&[b"anexo-founder-req-v1"], Len(32)).expect("hkdf len").fill(&mut out).expect("hkdf fill");
    out
}
/// sig = HMAC-SHA256(key, "METHOD\npath\nts\nsha256hex(body)") — binds verb, path, time and exact body.
pub fn req_sig(key: &[u8], method: &str, path: &str, ts: i64, body: &[u8]) -> String {
    let mut m = Hmac::<Sha256>::new_from_slice(key).expect("hmac key");
    m.update(format!("{}\n{}\n{}\n{}", method, path, ts, hex::encode(Sha256::digest(body))).as_bytes());
    hex::encode(m.finalize().into_bytes())
}
pub const REQ_SKEW_SECS: i64 = 60;
pub fn req_verify(key: &[u8], method: &str, path: &str, ts: i64, body: &[u8], sig: &str, now: i64) -> bool {
    if (now - ts).abs() > REQ_SKEW_SECS { return false; }
    let want = req_sig(key, method, path, ts, body);
    want.len() == sig.len() && want.bytes().zip(sig.bytes()).fold(0u8, |a, (x, y)| a | (x ^ y)) == 0
}

pub fn sign(key: &[u8], ts: i64, data_json: &str) -> String {
    let mut m = Hmac::<Sha256>::new_from_slice(key).expect("hmac key");
    m.update(format!("{}.{}", ts, hex::encode(Sha256::digest(data_json.as_bytes()))).as_bytes());
    hex::encode(m.finalize().into_bytes())
}

pub fn verify(key: &[u8], ts: i64, data_json: &str, sig: &str) -> bool {
    let want = sign(key, ts, data_json);
    // constant-time barabari
    want.len() == sig.len() && want.bytes().zip(sig.bytes()).fold(0u8, |a, (x, y)| a | (x ^ y)) == 0
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ed25519_roundtrip_tamper_and_wrong_key() {
        let k = EdKeys::from_pkcs8(&EdKeys::generate_pkcs8().unwrap()).unwrap();
        let other = EdKeys::from_pkcs8(&EdKeys::generate_pkcs8().unwrap()).unwrap();
        let sig = k.sign(100, r#"{"a":1}"#);
        assert!(ed_verify(&k.public_b64(), 100, r#"{"a":1}"#, &sig));
        assert!(!ed_verify(&k.public_b64(), 100, r#"{"a":2}"#, &sig), "data tamper");
        assert!(!ed_verify(&k.public_b64(), 101, r#"{"a":1}"#, &sig), "ts tamper");
        assert!(!ed_verify(&other.public_b64(), 100, r#"{"a":1}"#, &sig), "wrong key");
        assert!(!ed_verify(&k.public_b64(), 100, r#"{"a":1}"#, "!!!"), "garbage sig");
        assert!(EdKeys::from_pkcs8(b"junk").is_none());
    }
    #[test]
    fn req_key_is_per_token_and_per_secret() {
        let a = req_key(b"master-secret-0123456789", "tok.a.b"); let b = req_key(b"master-secret-0123456789", "tok.a.c"); let c = req_key(b"other-secret-0123456789", "tok.a.b");
        assert_ne!(a, b); assert_ne!(a, c); assert_eq!(a, req_key(b"master-secret-0123456789", "tok.a.b"));
    }
    #[test]
    fn request_sig_binds_method_path_time_body_and_expires() {
        let k = req_key(b"m", "t"); let body = br#"{"x":1}"#;
        let s = req_sig(&k, "POST", "/founder/v1/action", 1000, body);
        assert!(req_verify(&k, "POST", "/founder/v1/action", 1000, body, &s, 1030));
        assert!(!req_verify(&k, "PUT", "/founder/v1/action", 1000, body, &s, 1000), "method");
        assert!(!req_verify(&k, "POST", "/founder/v1/other", 1000, body, &s, 1000), "path");
        assert!(!req_verify(&k, "POST", "/founder/v1/action", 1000, br#"{"x":2}"#, &s, 1000), "body");
        assert!(!req_verify(&k, "POST", "/founder/v1/action", 1000, body, &s, 1100), "stale (replay later)");
        assert!(!req_verify(&k, "POST", "/founder/v1/action", 1000, body, &s, 900), "future ts");
        assert!(!req_verify(&req_key(b"m", "t2"), "POST", "/founder/v1/action", 1000, body, &s, 1000), "other token key");
    }
    #[test]
    fn roundtrip_and_tamper() {
        let s = sign(b"k", 100, r#"{"a":1}"#);
        assert!(verify(b"k", 100, r#"{"a":1}"#, &s));
        assert!(!verify(b"k", 100, r#"{"a":2}"#, &s));
        assert!(!verify(b"k", 101, r#"{"a":1}"#, &s));
        assert!(!verify(b"x", 100, r#"{"a":1}"#, &s));
    }
}
