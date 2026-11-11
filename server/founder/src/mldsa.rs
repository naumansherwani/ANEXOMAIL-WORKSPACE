//! GAP 2 (K7, post-quantum): ML-DSA-65 (FIPS 204) verification for the device proof. Pure Rust (`fips204`, no unsafe, no heap, constant-time verify not needed: public data only).
//! The device proof is a HYBRID: ECDSA P-256 (WebCrypto, live) AND ML-DSA-65, both must verify (dbsc.rs `verify_proof_hybrid`). The DBSC cookie path stays ES256 (browser standard).
use fips204::ml_dsa_65 as m;
use fips204::traits::{SerDes, Verifier};

pub const PK_LEN: usize = m::PK_LEN;
pub const SIG_LEN: usize = m::SIG_LEN;
/// FIPS 204 context string: a signature made for another purpose never verifies here.
pub const CTX: &[u8] = b"anexo-founder-device-proof-v1";

/// True only for a well-formed key, a well-formed signature and a valid ML-DSA-65 signature over `msg`.
pub fn verify(pk: &[u8], msg: &[u8], sig: &[u8]) -> bool {
    let Ok(pk): Result<[u8; PK_LEN], _> = pk.try_into() else { return false };
    let Ok(sig): Result<[u8; SIG_LEN], _> = sig.try_into() else { return false };
    let Ok(pk) = m::PublicKey::try_from_bytes(pk) else { return false };
    pk.verify(msg, &sig, CTX)
}
/// A public key that parses (length + decoding), used at registration before it is stored.
pub fn key_ok(pk: &[u8]) -> bool { <[u8; PK_LEN]>::try_from(pk).ok().is_some_and(|k| m::PublicKey::try_from_bytes(k).is_ok()) }

/// S3b cross-check: the KERNEL's ML-DSA code (web-wasm/src/mldsa.rs, compiled into the browser wasm) is included here and its signatures must verify with the SERVER's verify.
#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use fips204::traits::{KeyGen, Signer};
    pub fn pair() -> (Vec<u8>, m::PrivateKey) { let (pk, sk) = m::KG::try_keygen().unwrap(); (pk.into_bytes().to_vec(), sk) }
    pub fn sign(sk: &m::PrivateKey, msg: &[u8]) -> Vec<u8> { sk.try_sign(msg, CTX).unwrap().to_vec() }
    /// Bytes made by the Rust WASM kernel (web-wasm/src/mldsa.rs, seed [42;32]) verify here, with the server's FIPS 204 context; the kernel crate has the matching test that keeps the file current.
    #[test]
    fn a_signature_made_by_the_browser_kernel_verifies_on_the_server_and_nothing_else_does() {
        let v = include_str!("mldsa_kernel_vector.txt");
        let un = |h: &str| -> Vec<u8> { (0..h.len() / 2).map(|i| u8::from_str_radix(&h[2 * i..2 * i + 2], 16).unwrap()).collect() };
        let mut l = v.lines();
        let (pk, sig) = (un(l.next().unwrap()), un(l.next().unwrap()));
        assert_eq!((pk.len(), sig.len()), (PK_LEN, SIG_LEN));
        assert!(verify(&pk, b"hybrid proof bytes", &sig) && key_ok(&pk), "kernel signature, server verify");
        assert!(!verify(&pk, b"other bytes", &sig));
        let mut bad = sig.clone(); bad[7] ^= 1; assert!(!verify(&pk, b"hybrid proof bytes", &bad));
    }
    #[test]
    fn ml_dsa_65_verifies_and_refuses() {
        let (pk, sk) = pair();
        let sig = sign(&sk, b"device proof");
        assert!(verify(&pk, b"device proof", &sig) && key_ok(&pk));
        assert!(!verify(&pk, b"device proof!", &sig), "other message");
        let mut bad = sig.clone(); bad[10] ^= 1; assert!(!verify(&pk, b"device proof", &bad), "flipped bit");
        let (pk2, _) = pair(); assert!(!verify(&pk2, b"device proof", &sig), "other key");
        assert!(!verify(&pk[..100], b"device proof", &sig) && !verify(&pk, b"device proof", &sig[..100]) && !key_ok(&[0u8; 5]), "short inputs");
        let other_ctx = sk.try_sign(b"device proof", b"another-purpose").unwrap(); assert!(!verify(&pk, b"device proof", &other_ctx), "other context");
        assert_eq!((PK_LEN, SIG_LEN), (1952, 3309));
    }
}
