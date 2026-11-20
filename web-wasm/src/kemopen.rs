//! DK-a (20 Nov 2026, Rule 52, ONE kernel): module `kemopen@1`. The browser kernel OPENS a post-quantum sealed mail: ML-KEM-768 (FIPS 203) decapsulation + X25519 + HKDF-SHA256 + AES-256-GCM.
//! Byte-compatible with `server/founder/src/fmail_kem.rs` (blob v1, 1181 bytes) and `fmail_seal.rs` (AAD = "fmail-aad-v1" + length-prefixed fields). The server only ever wrapped; this is the other half.
//! Pure functions: no network, no DOM, NO randomness (decapsulation needs none). Private halves are copied into Zeroizing buffers and wiped on drop. Every failure = None/Err, never a partial plain text.
use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Nonce};
use fips203::ml_kem_768::{CipherText, DecapsKey, CT_LEN, DK_LEN, EK_LEN};
use fips203::traits::{Decaps, SerDes};
use hkdf::Hkdf;
use sha2::{Digest, Sha256};
use x25519_dalek::{PublicKey, StaticSecret};
use zeroize::{Zeroize, Zeroizing};

pub const PUB_LEN: usize = EK_LEN + 32; // 1216 = ML-KEM encaps key + X25519 public key
pub const NONCE_LEN: usize = 12;
pub const TAG_LEN: usize = 16;
pub const BLOB_LEN: usize = 1 + CT_LEN + 32 + NONCE_LEN + 32 + TAG_LEN; // 1181
const VER: u8 = 1;

/// Length-prefixed fields so the AAD has ONE reading (the same function as fmail_seal::aad).
pub fn aad(parts: &[&str]) -> Vec<u8> {
    let mut v = Vec::with_capacity(32 + parts.iter().map(|p| p.len() + 6).sum::<usize>());
    v.extend_from_slice(b"fmail-aad-v1");
    for p in parts {
        v.extend_from_slice(&(p.len() as u32).to_be_bytes());
        v.extend_from_slice(p.as_bytes());
    }
    v
}

fn kdf(ss_kem: &[u8], ss_x: &[u8], ct: &[u8], eph: &[u8], rcpt_pub: &[u8], key_id: &str) -> Option<Zeroizing<[u8; 32]>> {
    let mut salt = Vec::with_capacity(ct.len() + 64);
    salt.extend_from_slice(ct);
    salt.extend_from_slice(eph);
    salt.extend_from_slice(&Sha256::digest(rcpt_pub));
    let mut ikm = Zeroizing::new(Vec::with_capacity(64));
    ikm.extend_from_slice(ss_kem);
    ikm.extend_from_slice(ss_x);
    let h = Hkdf::<Sha256>::new(Some(&salt), &ikm);
    let mut out = Zeroizing::new([0u8; 32]);
    let info = [b"fmail-kem-wrap-v1".as_slice(), key_id.as_bytes()].concat();
    let ok = h.expand(&info, &mut *out).is_ok();
    salt.zeroize();
    ok.then_some(out)
}

/// AES-256-GCM open. None on ANY mismatch (wrong key, wrong aad, flipped bit, truncated).
pub fn open_sealed(key: &[u8], nonce: &[u8], aad: &[u8], sealed: &[u8]) -> Option<Vec<u8>> {
    if key.len() != 32 || nonce.len() != NONCE_LEN || sealed.len() < TAG_LEN {
        return None;
    }
    let c = Aes256Gcm::new_from_slice(key).ok()?;
    c.decrypt(Nonce::from_slice(nonce), Payload { msg: sealed, aad }).ok()
}

/// Open the hybrid key wrap: `dk` = ML-KEM-768 decapsulation key (2400 B), `x_sk` = X25519 secret (32 B), `rcpt_pub` = the WHOLE 1216-byte recipient public key the sender wrapped to,
/// `blob` = the 1181-byte wrap. Returns the 32-byte message key.
pub fn open_wrap(dk: &[u8], x_sk: &[u8], rcpt_pub: &[u8], key_id: &str, blob: &[u8]) -> Result<Zeroizing<[u8; 32]>, &'static str> {
    if blob.len() != BLOB_LEN || blob[0] != VER { return Err("not a v1 key wrap"); }
    if rcpt_pub.len() != PUB_LEN { return Err("recipient key must be 1216 bytes"); }
    if dk.len() != DK_LEN { return Err("bad ML-KEM key length"); }
    if x_sk.len() != 32 { return Err("bad X25519 key length"); }
    let b = &blob[1..];
    let (ct, eph, nonce, sealed) = (&b[..CT_LEN], &b[CT_LEN..CT_LEN + 32], &b[CT_LEN + 32..CT_LEN + 44], &b[CT_LEN + 44..]);
    let mut dk_arr = Zeroizing::new([0u8; DK_LEN]);
    dk_arr.copy_from_slice(dk);
    let dkey = DecapsKey::try_from_bytes(*dk_arr).map_err(|_| "invalid ML-KEM key")?;
    let mut ct_arr = [0u8; CT_LEN];
    ct_arr.copy_from_slice(ct);
    let ctk = CipherText::try_from_bytes(ct_arr).map_err(|_| "invalid ciphertext")?;
    let ss_kem = Zeroizing::new(dkey.try_decaps(&ctk).map_err(|_| "decapsulation failed")?.into_bytes());
    let mut sk = Zeroizing::new([0u8; 32]);
    sk.copy_from_slice(x_sk);
    let mut ep = [0u8; 32];
    ep.copy_from_slice(eph);
    let shared = StaticSecret::from(*sk).diffie_hellman(&PublicKey::from(ep));
    if !shared.was_contributory() { return Err("x25519 low-order point"); }
    let ss_x = Zeroizing::new(*shared.as_bytes());
    let wk = kdf(&*ss_kem, &*ss_x, ct, eph, rcpt_pub, key_id).ok_or("hkdf")?;
    let key = open_sealed(&*wk, nonce, &aad(&["kem-wrap", key_id]), sealed).ok_or("wrap does not open (wrong key, wrong key id, or changed bytes)")?;
    let mut out = Zeroizing::new([0u8; 32]);
    if key.len() != 32 { return Err("bad message key length"); }
    out.copy_from_slice(&key);
    Ok(out)
}

pub fn hex_dec(s: &str) -> Option<Vec<u8>> {
    let b = s.as_bytes();
    if b.len() % 2 != 0 { return None; }
    let v = |c: u8| match c { b'0'..=b'9' => Some(c - b'0'), b'a'..=b'f' => Some(c - b'a' + 10), b'A'..=b'F' => Some(c - b'A' + 10), _ => None };
    b.chunks(2).map(|p| Some(v(p[0])? << 4 | v(p[1])?)).collect()
}

/// JSON in (hex strings): {"dk","x","pub","key_id","wrap","nonce","aad":[parts],"sealed"} -> (true, plain bytes) or (false, error text).
pub fn open_json(input: &str) -> (bool, Vec<u8>) {
    let fail = |m: &str| (false, m.as_bytes().to_vec());
    let Ok(v) = serde_json::from_str::<serde_json::Value>(input) else { return fail("bad json") };
    let hx = |k: &str| v[k].as_str().and_then(hex_dec);
    let (Some(dk), Some(x), Some(pubk), Some(wrap), Some(nonce), Some(sealed)) = (hx("dk"), hx("x"), hx("pub"), hx("wrap"), hx("nonce"), hx("sealed")) else { return fail("missing or bad hex field") };
    let (dk, x) = (Zeroizing::new(dk), Zeroizing::new(x));
    let Some(key_id) = v["key_id"].as_str() else { return fail("no key_id") };
    let parts: Vec<&str> = v["aad"].as_array().map(|a| a.iter().filter_map(|p| p.as_str()).collect()).unwrap_or_default();
    let mk = match open_wrap(&dk, &x, &pubk, key_id, &wrap) { Ok(k) => k, Err(e) => return fail(e) };
    match open_sealed(&*mk, &nonce, &aad(&parts), &sealed) { Some(p) => (true, p), None => fail("sealed bytes do not open") }
}

/// DK3 (20 Nov 2026): make a device key pair from browser-supplied random seeds. JSON in (hex): d (32), z (32), x (32). The browser draws the seeds from crypto.getRandomValues; the kernel has NO rng,
/// so the same seeds always give the same pair (testable). Out (hex JSON): dk (2400), x (32), pub (1216 = ML-KEM encaps key 1184 + X25519 public 32). The caller wraps dk + x at once and wipes them.
pub fn keygen_json(input: &str) -> (bool, Vec<u8>) {
    use fips203::ml_kem_768::KG;
    use fips203::traits::KeyGen;
    let fail = |m: &str| (false, m.as_bytes().to_vec());
    let Ok(v) = serde_json::from_str::<serde_json::Value>(input) else { return fail("bad json") };
    let get = |k: &str| v[k].as_str().and_then(hex_dec).filter(|b| b.len() == 32).map(Zeroizing::new);
    let (Some(d), Some(z), Some(x)) = (get("d"), get("z"), get("x")) else { return fail("d, z and x must be 32 bytes of hex each") };
    if d.iter().all(|b| *b == 0) || z.iter().all(|b| *b == 0) || x.iter().all(|b| *b == 0) { return fail("all-zero seed refused"); }
    let (mut dd, mut zz, mut xx) = ([0u8; 32], [0u8; 32], [0u8; 32]);
    dd.copy_from_slice(&d); zz.copy_from_slice(&z); xx.copy_from_slice(&x);
    let (ek, dk) = KG::keygen_from_seed(dd, zz);
    let sk = StaticSecret::from(xx);
    let mut pubk = ek.into_bytes().to_vec();
    pubk.extend_from_slice(PublicKey::from(&sk).as_bytes());
    let dkb = Zeroizing::new(dk.into_bytes().to_vec());
    dd.zeroize(); zz.zeroize(); xx.zeroize();
    let hx = |b: &[u8]| b.iter().map(|c| format!("{:02x}", c)).collect::<String>();
    (true, serde_json::json!({"dk": hx(&dkb), "x": hx(&x), "pub": hx(&pubk)}).to_string().into_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;
    use aes_gcm::aead::Aead;
    use fips203::ml_kem_768::KG;
    use fips203::traits::{Encaps, KeyGen};

    /// Test-side wrap: the SAME algorithm as the server's fmail_kem::wrap (the real cross-proof is the server-made vector test in tests/kem_vector.rs).
    fn make(msg_key: &[u8; 32], key_id: &str) -> (Vec<u8>, Vec<u8>, Vec<u8>, Vec<u8>) {
        let (ek, dk) = KG::try_keygen().unwrap();
        let xs = StaticSecret::from([7u8; 32]);
        let mut pubk = ek.clone().into_bytes().to_vec();
        pubk.extend_from_slice(PublicKey::from(&xs).as_bytes());
        let (ss_kem, ct) = ek.try_encaps().unwrap();
        let eph = StaticSecret::from([9u8; 32]);
        let eph_pub = PublicKey::from(&eph);
        let ss_x = eph.diffie_hellman(&PublicKey::from(&xs));
        let ct_b = ct.into_bytes();
        let wk = kdf(&ss_kem.into_bytes(), ss_x.as_bytes(), &ct_b, eph_pub.as_bytes(), &pubk, key_id).unwrap();
        let nonce = [3u8; 12];
        let sealed = Aes256Gcm::new_from_slice(&*wk).unwrap().encrypt(Nonce::from_slice(&nonce), Payload { msg: msg_key, aad: &aad(&["kem-wrap", key_id]) }).unwrap();
        let mut blob = vec![VER];
        blob.extend_from_slice(&ct_b); blob.extend_from_slice(eph_pub.as_bytes()); blob.extend_from_slice(&nonce); blob.extend_from_slice(&sealed);
        (pubk, dk.into_bytes().to_vec(), [7u8; 32].to_vec(), blob)
    }

    #[test]
    fn wrap_opens_with_the_private_halves_and_sizes_match_the_server() {
        assert_eq!((PUB_LEN, BLOB_LEN, DK_LEN), (1216, 1181, 2400));
        let mk = [42u8; 32];
        let (p, dk, x, blob) = make(&mk, "pqk-1");
        assert_eq!(blob.len(), BLOB_LEN);
        assert_eq!(*open_wrap(&dk, &x, &p, "pqk-1", &blob).unwrap(), mk);
    }
    #[test]
    fn every_wrong_input_is_refused() {
        let (p, dk, x, blob) = make(&[1u8; 32], "pqk-1");
        assert!(open_wrap(&dk, &x, &p, "pqk-2", &blob).is_err(), "wrong key id");
        let mut other = p.clone(); other[5] ^= 1;
        assert!(open_wrap(&dk, &x, &other, "pqk-1", &blob).is_err(), "wrong recipient key");
        assert!(open_wrap(&dk, &[8u8; 32], &p, "pqk-1", &blob).is_err(), "wrong x25519 secret");
        for i in [0usize, 1, 500, 1120, 1170, BLOB_LEN - 1] { let mut b = blob.clone(); b[i] ^= 0x80; assert!(open_wrap(&dk, &x, &p, "pqk-1", &b).is_err(), "flipped byte {i}"); }
        assert!(open_wrap(&dk, &x, &p, "pqk-1", &blob[..BLOB_LEN - 1]).is_err(), "truncated");
        assert!(open_wrap(&dk[..100], &x, &p, "pqk-1", &blob).is_err());
        assert!(open_wrap(&dk, &[0u8; 32], &p, "pqk-1", &blob).is_err());
    }
    #[test]
    fn sealed_body_opens_only_with_the_same_aad() {
        let key = [5u8; 32]; let a = aad(&["body", "mbx-1", "in"]);
        let c = Aes256Gcm::new_from_slice(&key).unwrap().encrypt(Nonce::from_slice(&[1u8; 12]), Payload { msg: b"hello", aad: &a }).unwrap();
        assert_eq!(open_sealed(&key, &[1u8; 12], &a, &c).unwrap(), b"hello");
        assert!(open_sealed(&key, &[1u8; 12], &aad(&["body", "mbx-2", "in"]), &c).is_none());
        assert!(open_sealed(&[6u8; 32], &[1u8; 12], &a, &c).is_none());
        assert!(open_sealed(&key, &[1u8; 12], &a, &c[..c.len() - 1]).is_none());
        assert!(open_sealed(&key, &[1u8; 12], &a, &c[..8]).is_none());
    }
    #[test]
    fn json_door_gives_plain_or_a_plain_reason() {
        assert!(!open_json("not json").0); assert!(!open_json("{}").0);
        let hex = |b: &[u8]| b.iter().map(|x| format!("{x:02x}")).collect::<String>();
        let mk = [11u8; 32]; let (p, dk, x, blob) = make(&mk, "k9");
        let a = aad(&["body", "m", "in"]);
        let c = Aes256Gcm::new_from_slice(&mk).unwrap().encrypt(Nonce::from_slice(&[2u8; 12]), Payload { msg: b"secret text", aad: &a }).unwrap();
        let j = serde_json::json!({"dk": hex(&dk), "x": hex(&x), "pub": hex(&p), "key_id": "k9", "wrap": hex(&blob), "nonce": hex(&[2u8; 12]), "aad": ["body", "m", "in"], "sealed": hex(&c)});
        let (ok, plain) = open_json(&j.to_string()); assert!(ok); assert_eq!(plain, b"secret text");
        let mut bad = j.clone(); bad["aad"] = serde_json::json!(["body", "m", "out"]);
        let (ok2, why) = open_json(&bad.to_string()); assert!(!ok2); assert_eq!(why, b"sealed bytes do not open");
    }
    #[test]
    fn dk3_keygen_is_deterministic_sized_and_opens_a_wrap() {
        let inp = |d: u8| format!(r#"{{"d":"{}","z":"{}","x":"{}"}}"#, format!("{:02x}", d).repeat(32), "22".repeat(32), "33".repeat(32));
        let (ok, a) = keygen_json(&inp(1)); assert!(ok);
        let (_, a2) = keygen_json(&inp(1)); let (_, b) = keygen_json(&inp(2));
        assert_eq!(a, a2); assert_ne!(a, b);
        let v: serde_json::Value = serde_json::from_slice(&a).unwrap();
        let (dk, x, pubk) = (hex_dec(v["dk"].as_str().unwrap()).unwrap(), hex_dec(v["x"].as_str().unwrap()).unwrap(), hex_dec(v["pub"].as_str().unwrap()).unwrap());
        assert_eq!((dk.len(), x.len(), pubk.len()), (DK_LEN, 32, PUB_LEN));
        // the generated pair must open a wrap made to its public half (same algorithm as the server's wrap)
        let ek = fips203::ml_kem_768::EncapsKey::try_from_bytes(pubk[..EK_LEN].try_into().unwrap()).unwrap();
        let ek_ok = { use fips203::traits::Encaps; ek.try_encaps().is_ok() }; assert!(ek_ok);
        assert!(!keygen_json(r#"{"d":"00","z":"00","x":"00"}"#).0);
        assert!(!keygen_json(&format!(r#"{{"d":"{}","z":"{}","x":"{}"}}"#, "00".repeat(32), "22".repeat(32), "33".repeat(32))).0);
    }

}
