//! Q1b (founder mailbox): POST-QUANTUM key wrap. A message key is wrapped to the founder's public key = ML-KEM-768 (FIPS 203) + X25519, hybrid:
//! the wrap stays safe if EITHER one of the two is broken (the same hybrid idea as X25519MLKEM768 in TLS and as the OpenPGP PQC suite of RFC 9980).
//! The SERVER only ever has the PUBLIC key (1184-byte ML-KEM encaps key + 32-byte X25519 key = 1216 bytes). The private halves live on his device
//! (wrapped by his passkey) and are used by the browser kernel to open the wrap (decapsulation is in the kernel, not here). After this wrap the server can
//! NOT open the message again: that is the zero-knowledge point of seal_mode 'recipient_pq'.
//! Blob layout (v1, 1181 bytes): 0x01 | ML-KEM ct (1088) | ephemeral X25519 pub (32) | nonce (12) | AES-256-GCM(msg key) (48).
//! KDF: HKDF-SHA256(salt = ct || eph pub || SHA-256(whole 1216-byte recipient key), ikm = mlkem_ss || x25519_ss, info = "fmail-kem-wrap-v1" || key id).
use fips203::ml_kem_768::{CipherText, EncapsKey, CT_LEN, EK_LEN};
use fips203::traits::{Encaps, SerDes};
use ring::{agreement, hkdf, rand::SystemRandom};
use sha2::{Digest, Sha256};
use zeroize::{Zeroize, Zeroizing};
use crate::fmail_seal as seal;

pub const PUB_LEN: usize = EK_LEN + 32;           // 1216
pub const BLOB_LEN: usize = 1 + CT_LEN + 32 + seal::NONCE_LEN + 32 + seal::TAG_LEN;   // 1181
const VER: u8 = 1;
struct Len(usize);
impl hkdf::KeyType for Len { fn len(&self) -> usize { self.0 } }

/// `rcpt_pub` is the WHOLE 1216-byte recipient key: its SHA-256 goes into the salt, so the derived key is bound to both recipient halves (ML-KEM key and X25519 key), like the X-Wing combiner.
fn kdf(ss_kem: &[u8], ss_x: &[u8], ct: &[u8], eph: &[u8], rcpt_pub: &[u8], key_id: &str) -> Result<seal::Key, &'static str> {
    let mut salt = Vec::with_capacity(ct.len() + 64); salt.extend_from_slice(ct); salt.extend_from_slice(eph); salt.extend_from_slice(&Sha256::digest(rcpt_pub));
    let mut ikm = Zeroizing::new(Vec::with_capacity(64)); ikm.extend_from_slice(ss_kem); ikm.extend_from_slice(ss_x);
    let prk = hkdf::Salt::new(hkdf::HKDF_SHA256, &salt).extract(&ikm);
    let info = [b"fmail-kem-wrap-v1".as_slice(), key_id.as_bytes()];
    let mut out = [0u8; 32]; prk.expand(&info, Len(32)).map_err(|_| "hkdf")?.fill(&mut out).map_err(|_| "hkdf")?; salt.zeroize(); Ok(out)
}

/// Wrap `msg_key` to the recipient public key (1216 bytes). `key_id` is bound into the KDF and the AAD, so a wrap made for key A never opens under key B.
pub fn wrap(recipient_pub: &[u8], key_id: &str, msg_key: &seal::Key) -> Result<Vec<u8>, &'static str> {
    if recipient_pub.len() != PUB_LEN { return Err("recipient key must be 1216 bytes"); }
    let ek_bytes: [u8; EK_LEN] = recipient_pub[..EK_LEN].try_into().map_err(|_| "ek")?;
    let rcpt_x: [u8; 32] = recipient_pub[EK_LEN..].try_into().map_err(|_| "x25519")?;
    let ek = EncapsKey::try_from_bytes(ek_bytes).map_err(|_| "invalid ML-KEM public key")?;
    let (ss_kem, ct) = ek.try_encaps().map_err(|_| "encaps failed")?;
    let ct_b = ct.into_bytes();
    let rng = SystemRandom::new();
    let eph = agreement::EphemeralPrivateKey::generate(&agreement::X25519, &rng).map_err(|_| "x25519 keygen")?;
    let eph_pub = eph.compute_public_key().map_err(|_| "x25519 pub")?;
    let ss_x = agreement::agree_ephemeral(eph, &agreement::UnparsedPublicKey::new(&agreement::X25519, &rcpt_x), |s| Zeroizing::new(s.to_vec())).map_err(|_| "x25519 agree (low-order key?)")?;
    let ss_kem_b = Zeroizing::new(ss_kem.into_bytes());
    let wk = Zeroizing::new(kdf(&*ss_kem_b, &ss_x, &ct_b, eph_pub.as_ref(), recipient_pub, key_id)?);
    let (n, sealed) = seal::seal(&*wk, &seal::aad(&["kem-wrap", key_id]), msg_key)?;
    let mut out = Vec::with_capacity(BLOB_LEN); out.push(VER); out.extend_from_slice(&ct_b); out.extend_from_slice(eph_pub.as_ref()); out.extend_from_slice(&n); out.extend_from_slice(&sealed);
    debug_assert_eq!(out.len(), BLOB_LEN); Ok(out)
}

/// The same parse the kernel does (kept here so the format has one reference and the tests can prove the round trip). Returns the parts (ct, eph, nonce, sealed).
pub fn parts(blob: &[u8]) -> Option<(&[u8], &[u8], &[u8], &[u8])> {
    if blob.len() != BLOB_LEN || blob[0] != VER { return None; }
    let b = &blob[1..]; Some((&b[..CT_LEN], &b[CT_LEN..CT_LEN + 32], &b[CT_LEN + 32..CT_LEN + 44], &b[CT_LEN + 44..]))
}

#[cfg(test)]
mod tests {
    use super::*;
    use fips203::ml_kem_768::{DecapsKey, KG};
    use fips203::traits::{Decaps, KeyGen};
    use ring::signature::KeyPair as _;
    // test-only recipient: ML-KEM keypair + X25519 keypair (ring gives ephemeral only, so the x25519 side uses one ephemeral key we keep for the test)
    fn recipient() -> (Vec<u8>, DecapsKey, agreement::EphemeralPrivateKey) {
        let (ek, dk) = KG::try_keygen().unwrap();
        let x = agreement::EphemeralPrivateKey::generate(&agreement::X25519, &SystemRandom::new()).unwrap();
        let mut p = ek.into_bytes().to_vec(); p.extend_from_slice(x.compute_public_key().unwrap().as_ref()); (p, dk, x)
    }
    fn open_wrap(pubk: &[u8], dk: &DecapsKey, x: agreement::EphemeralPrivateKey, blob: &[u8], key_id: &str) -> Option<seal::Key> {
        let (ct, eph, nonce, sealed) = parts(blob)?;
        let ctb: [u8; CT_LEN] = ct.try_into().ok()?; let ss_kem = dk.try_decaps(&CipherText::try_from_bytes(ctb).ok()?).ok()?;
        let ss_x = agreement::agree_ephemeral(x, &agreement::UnparsedPublicKey::new(&agreement::X25519, eph), |s| s.to_vec()).ok()?;
        let wk = kdf(&ss_kem.into_bytes(), &ss_x, ct, eph, pubk, key_id).ok()?;
        seal::open(&wk, nonce, &seal::aad(&["kem-wrap", key_id]), sealed)?.try_into().ok()
    }
    #[test]
    fn hybrid_wrap_roundtrips_with_the_private_halves() {
        let (p, dk, x) = recipient(); let mk = seal::new_key().unwrap();
        let blob = wrap(&p, "pqk-1", &mk).unwrap(); assert_eq!(blob.len(), BLOB_LEN); assert_eq!(BLOB_LEN, 1181);
        assert_eq!(open_wrap(&p, &dk, x, &blob, "pqk-1").unwrap(), mk);
    }
    #[test]
    fn a_wrap_for_one_key_id_does_not_open_under_another() {
        let (p, dk, x) = recipient(); let mk = seal::new_key().unwrap(); let blob = wrap(&p, "pqk-1", &mk).unwrap();
        assert!(open_wrap(&p, &dk, x, &blob, "pqk-2").is_none());
    }
    #[test]
    fn a_wrong_recipient_cannot_open_and_a_flipped_bit_is_refused() {
        let (p, _dk, _x) = recipient(); let (p2, dk2, x2) = recipient(); let mk = seal::new_key().unwrap();
        let blob = wrap(&p, "pqk-1", &mk).unwrap();
        assert!(open_wrap(&p2, &dk2, x2, &blob, "pqk-1").is_none(), "another person's keys");
        let (p3, dk3, x3) = recipient(); let blob3 = wrap(&p3, "k", &mk).unwrap();
        assert!(open_wrap(&p3, &dk3, x3, &blob3, "k").is_some(), "control: the untouched blob opens");
        let (p4, dk4, x4) = recipient(); let blob4 = wrap(&p4, "k", &mk).unwrap(); let mut bad = blob4.clone(); bad[600] ^= 1;
        assert!(open_wrap(&p4, &dk4, x4, &bad, "k").is_none(), "tampered ML-KEM ciphertext");
        let (p5, dk5, x5) = recipient(); let blob5 = wrap(&p5, "k", &mk).unwrap(); let mut bad = blob5.clone(); bad[1175] ^= 1;
        assert!(open_wrap(&p5, &dk5, x5, &bad, "k").is_none(), "tampered sealed key");
    }
    #[test]
    fn two_wraps_of_the_same_key_differ_and_bad_input_is_refused() {
        let (p, _, _) = recipient(); let mk = seal::new_key().unwrap();
        assert_ne!(wrap(&p, "k", &mk).unwrap(), wrap(&p, "k", &mk).unwrap());
        assert!(wrap(&p[..1215], "k", &mk).is_err()); assert!(wrap(&[0u8; 1217], "k", &mk).is_err());
        assert!(parts(&[0u8; 1181]).is_none(), "version byte"); assert!(parts(&[1u8; 10]).is_none());
    }
}
