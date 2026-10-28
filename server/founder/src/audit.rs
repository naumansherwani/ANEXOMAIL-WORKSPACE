//! founder_audit: append-only SHA-256 hash chain + HMAC signature (Rule 61).
//! row_hash = SHA256(prev_hash | seq | actor | action | reason | ts); sig = HMAC(key, row_hash).
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};

pub const GENESIS: &str = "0000000000000000000000000000000000000000000000000000000000000000";

#[derive(Clone, Debug, PartialEq)]
pub struct Entry {
    pub seq: u64,
    pub actor: String,
    pub action: String,
    pub reason: String,
    pub ts: i64,
    pub prev_hash: String,
    pub hash: String,
    pub sig: String,
}

fn hash_of(prev: &str, seq: u64, actor: &str, action: &str, reason: &str, ts: i64) -> String {
    let mut h = Sha256::new();
    for part in [prev, &seq.to_string(), actor, action, reason, &ts.to_string()] {
        h.update((part.len() as u32).to_be_bytes()); // length-prefix: field-boundary confusion nahi
        h.update(part.as_bytes());
    }
    hex::encode(h.finalize())
}

fn sign(key: &[u8], hash: &str) -> String {
    let mut m = Hmac::<Sha256>::new_from_slice(key).expect("hmac key");
    m.update(hash.as_bytes());
    hex::encode(m.finalize().into_bytes())
}

pub fn append(chain: &[Entry], key: &[u8], actor: &str, action: &str, reason: &str, ts: i64) -> Entry {
    let (prev, seq) = chain.last().map(|e| (e.hash.clone(), e.seq + 1)).unwrap_or((GENESIS.into(), 1));
    let hash = hash_of(&prev, seq, actor, action, reason, ts);
    let sig = sign(key, &hash);
    Entry { seq, actor: actor.into(), action: action.into(), reason: reason.into(), ts, prev_hash: prev, hash, sig }
}

/// Poori chain jaanchta hai; pehli kharabi ka seq lautata hai.
pub fn verify(chain: &[Entry], key: &[u8]) -> Result<(), u64> {
    let mut prev = GENESIS.to_string();
    for (i, e) in chain.iter().enumerate() {
        let ok = e.seq == i as u64 + 1
            && e.prev_hash == prev
            && e.hash == hash_of(&prev, e.seq, &e.actor, &e.action, &e.reason, e.ts)
            && e.sig == sign(key, &e.hash);
        if !ok {
            return Err(e.seq);
        }
        prev = e.hash.clone();
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    const K: &[u8] = b"test-key";
    fn chain() -> Vec<Entry> {
        let mut c = vec![];
        for (i, a) in ["plan.change", "user.suspend", "refund"].iter().enumerate() {
            let e = append(&c, K, "founder", a, "wajah", 1000 + i as i64);
            c.push(e);
        }
        c
    }
    #[test]
    fn good_chain_verifies() {
        assert_eq!(verify(&chain(), K), Ok(()));
    }
    #[test]
    fn tamper_detected() {
        let mut c = chain();
        c[1].reason = "badla hua".into();
        assert_eq!(verify(&c, K), Err(2));
    }
    #[test]
    fn deleted_row_detected() {
        let mut c = chain();
        c.remove(1);
        assert_eq!(verify(&c, K), Err(3)); // row 3 ab position 2 par: seq ka silsila toot gaya
    }
    #[test]
    fn wrong_key_detected() {
        assert_eq!(verify(&chain(), b"other"), Err(1));
    }
}
