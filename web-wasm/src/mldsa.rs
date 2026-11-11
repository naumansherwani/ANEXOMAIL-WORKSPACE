//! K7 GAP 2, stage S3b (Rule 52, ONE kernel): ML-DSA-65 (FIPS 204) INSIDE the Rust WASM kernel, for browsers whose WebCrypto cannot make ML-DSA keys (Safari, Firefox today).
//! Module `mldsa@1`. Pure functions, no network, no DOM, NO randomness inside the kernel: the caller (the browser, `crypto.getRandomValues`) hands in a 32-byte seed for the key
//! (key = deterministic function of the seed, so only the seed is stored) and a fresh 32-byte value per signature (FIPS 204 hedged signing). Same crate and same context string as the
//! server (`server/founder/src/mldsa.rs`), so a kernel signature verifies there. Honest limit: unlike a WebCrypto key this seed is readable by script in the page; the server is told
//! (`pq.src = "kernel"`) and the Devices board says so.
use fips204::ml_dsa_65 as m;
use fips204::traits::{KeyGen, SerDes, Signer, Verifier};

pub const PK_LEN: usize = m::PK_LEN;
pub const SIG_LEN: usize = m::SIG_LEN;
/// FIPS 204 context: must equal the server's `mldsa::CTX` and the browser's `PQ_CONTEXT`.
pub const CTX: &[u8] = b"anexo-founder-device-proof-v1";

/// Public key for a 32-byte seed. None = the seed is not 32 bytes.
pub fn public_key(seed: &[u8]) -> Option<Vec<u8>> {
    let seed: [u8; 32] = seed.try_into().ok()?;
    let (pk, _sk) = m::KG::keygen_from_seed(&seed);
    Some(pk.into_bytes().to_vec())
}
/// Signature over `msg` with the key of `seed`, hedged with the caller's fresh 32 bytes `rnd`. None = a wrong input size or a (practically impossible) signing give-up.
pub fn sign(seed: &[u8], rnd: &[u8], msg: &[u8]) -> Option<Vec<u8>> {
    let (seed, rnd): ([u8; 32], [u8; 32]) = (seed.try_into().ok()?, rnd.try_into().ok()?);
    let (_pk, sk) = m::KG::keygen_from_seed(&seed);
    sk.try_sign_with_seed(&rnd, msg, CTX).ok().map(|s| s.to_vec())
}
pub fn verify(pk: &[u8], msg: &[u8], sig: &[u8]) -> bool {
    let (Ok(pk), Ok(sig)): (Result<[u8; PK_LEN], _>, Result<[u8; SIG_LEN], _>) = (pk.try_into(), sig.try_into()) else { return false };
    m::PublicKey::try_from_bytes(pk).is_ok_and(|k| k.verify(msg, &sig, CTX))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn a_seed_gives_one_key_and_a_signature_that_verifies_and_only_for_that_message() {
        let seed = [7u8; 32];
        let pk = public_key(&seed).unwrap();
        assert_eq!((pk.len(), pk, ), (PK_LEN, public_key(&seed).unwrap()), "same seed, same key");
        let sig = sign(&seed, &[9u8; 32], b"proof").unwrap();
        assert_eq!(sig.len(), SIG_LEN);
        let pk = public_key(&seed).unwrap();
        assert!(verify(&pk, b"proof", &sig));
        assert!(!verify(&pk, b"proof!", &sig), "other message");
        assert!(!verify(&public_key(&[8u8; 32]).unwrap(), b"proof", &sig), "other seed");
        let mut bad = sig.clone(); bad[5] ^= 1; assert!(!verify(&pk, b"proof", &bad), "flipped bit");
        assert_ne!(sig, sign(&seed, &[10u8; 32], b"proof").unwrap(), "fresh randomness gives a fresh signature");
        assert!(public_key(&[0u8; 31]).is_none() && sign(&seed, &[0u8; 5], b"x").is_none() && sign(&[1u8; 3], &[0u8; 32], b"x").is_none(), "wrong sizes are refused");
        assert!(!verify(&pk[..10], b"proof", &sig) && !verify(&pk, b"proof", &sig[..10]));
    }
    /// The cross-implementation vector shared with the server crate (server/founder/src/mldsa_kernel_vector.txt): line 1 = public key hex, line 2 = signature hex, made by THIS code
    /// from seed [42;32], randomness [43;32], message "hybrid proof bytes". The server test verifies the same bytes without compiling any kernel source (his server has no web-wasm folder).
    #[test]
    fn the_kernel_output_equals_the_vector_the_server_verifies() {
        let v = include_str!("../../server/founder/src/mldsa_kernel_vector.txt");
        let mut l = v.lines();
        let (pk, sig) = (l.next().unwrap(), l.next().unwrap());
        let hex = |b: &[u8]| b.iter().map(|x| format!("{x:02x}")).collect::<String>();
        assert_eq!(hex(&public_key(&[42u8; 32]).unwrap()), pk, "kernel public key changed: regenerate the vector");
        assert_eq!(hex(&sign(&[42u8; 32], &[43u8; 32], b"hybrid proof bytes").unwrap()), sig, "kernel signature changed: regenerate the vector");
    }
    #[test]
    #[ignore]
    fn print_the_vector() {
        let hex = |b: &[u8]| b.iter().map(|x| format!("{x:02x}")).collect::<String>();
        std::fs::write("../server/founder/src/mldsa_kernel_vector.txt", format!("{}\n{}\n", hex(&public_key(&[42u8; 32]).unwrap()), hex(&sign(&[42u8; 32], &[43u8; 32], b"hybrid proof bytes").unwrap()))).unwrap();
    }
}
