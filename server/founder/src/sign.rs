//! Har founder jawab par HMAC-SHA256: sig = HMAC(key, "<ts>.<sha256hex(data)>"). WASM kernel (Rule 52) browser mein yahi verify karta hai;
//! sig na mile/ghalat ho to jawab screen par nahi aata (enforce).
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};

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
    fn roundtrip_and_tamper() {
        let s = sign(b"k", 100, r#"{"a":1}"#);
        assert!(verify(b"k", 100, r#"{"a":1}"#, &s));
        assert!(!verify(b"k", 100, r#"{"a":2}"#, &s));
        assert!(!verify(b"k", 101, r#"{"a":1}"#, &s));
        assert!(!verify(b"x", 100, r#"{"a":1}"#, &s));
    }
}
