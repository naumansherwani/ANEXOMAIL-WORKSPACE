//! Module `sha256@1` — streaming SHA-256 (bade attachment ka digest upload se PEHLE, browser mein; server dedup/quota isi hash par chalta hai).
use sha2::{Digest, Sha256};
use std::cell::RefCell;

thread_local! { static HASHERS: RefCell<Vec<Option<Sha256>>> = const { RefCell::new(Vec::new()) }; }

pub fn new_hasher() -> u32 {
    HASHERS.with(|h| {
        let mut h = h.borrow_mut();
        if let Some(i) = h.iter().position(|s| s.is_none()) {
            h[i] = Some(Sha256::new());
            return i as u32 + 1;
        }
        h.push(Some(Sha256::new()));
        h.len() as u32
    })
}

pub fn update(handle: u32, data: &[u8]) -> bool {
    HASHERS.with(|h| match h.borrow_mut().get_mut((handle as usize).wrapping_sub(1)) {
        Some(Some(s)) => {
            s.update(data);
            true
        }
        _ => false,
    })
}

/// Digest do aur handle band karo.
pub fn finish(handle: u32) -> Option<[u8; 32]> {
    HASHERS.with(|h| {
        let slot = h.borrow_mut().get_mut((handle as usize).wrapping_sub(1))?.take()?;
        Some(slot.finalize().into())
    })
}

pub fn drop_hasher(handle: u32) {
    HASHERS.with(|h| {
        if let Some(s) = h.borrow_mut().get_mut((handle as usize).wrapping_sub(1)) {
            *s = None;
        }
    })
}

pub fn hex(d: &[u8]) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn digest(chunks: &[&[u8]]) -> String {
        let h = new_hasher();
        for c in chunks {
            assert!(update(h, c));
        }
        hex(&finish(h).unwrap())
    }

    #[test]
    fn known_vectors() {
        assert_eq!(digest(&[b""]), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
        assert_eq!(digest(&[b"abc"]), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        assert_eq!(
            digest(&[b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"]),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        );
    }

    #[test]
    fn chunking_never_changes_the_digest() {
        let data: Vec<u8> = (0..100_000u32).map(|i| (i * 31 % 251) as u8).collect();
        let whole = digest(&[&data]);
        let parts: Vec<&[u8]> = data.chunks(777).collect();
        assert_eq!(digest(&parts), whole);
        let one_by_one: Vec<&[u8]> = data[..2000].chunks(1).collect();
        assert_eq!(digest(&one_by_one), digest(&[&data[..2000]]));
    }

    #[test]
    fn million_a() {
        let a = vec![b'a'; 1_000_000];
        assert_eq!(digest(&[&a]), "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0");
    }

    #[test]
    fn bad_handles_are_safe() {
        assert!(!update(0, b"x"));
        assert!(!update(9999, b"x"));
        assert!(finish(0).is_none());
        let h = new_hasher();
        drop_hasher(h);
        assert!(!update(h, b"x"), "dropped handle is dead");
        assert!(finish(h).is_none());
        let h2 = new_hasher();
        assert_eq!(h2, h, "slot reused");
        drop_hasher(h2);
    }
}

/* ------------------------------------------------------------ hmac-sha256 */
/// HMAC-SHA256 (RFC 2104). Browser mein signed links / webhook-style tags / chunk tag verify ke liye; key kernel se bahar nahi jati.
pub fn hmac_sha256(key: &[u8], msg: &[u8]) -> [u8; 32] {
    let mut k = [0u8; 64];
    if key.len() > 64 {
        k[..32].copy_from_slice(&Sha256::digest(key));
    } else {
        k[..key.len()].copy_from_slice(key);
    }
    let mut ipad = [0x36u8; 64];
    let mut opad = [0x5cu8; 64];
    for i in 0..64 {
        ipad[i] ^= k[i];
        opad[i] ^= k[i];
    }
    let mut inner = Sha256::new();
    inner.update(ipad);
    inner.update(msg);
    let inner = inner.finalize();
    let mut outer = Sha256::new();
    outer.update(opad);
    outer.update(inner);
    outer.finalize().into()
}

/// Constant-time barabari (timing se tag andaza nahi lagta).
pub fn ct_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

pub fn hmac_verify(key: &[u8], msg: &[u8], tag: &[u8]) -> bool {
    ct_eq(&hmac_sha256(key, msg), tag)
}

#[cfg(test)]
mod hmac_tests {
    use super::*;
    fn hex(b: &[u8]) -> String {
        b.iter().map(|x| format!("{x:02x}")).collect()
    }
    #[test]
    fn rfc4231_vectors() {
        assert_eq!(hex(&hmac_sha256(&[0x0b; 20], b"Hi There")), "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7");
        assert_eq!(hex(&hmac_sha256(b"Jefe", b"what do ya want for nothing?")), "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843");
        // key 64 baiton se lamba (case 6): pehle hash hota hai
        assert_eq!(
            hex(&hmac_sha256(&[0xaa; 131], b"Test Using Larger Than Block-Size Key - Hash Key First")),
            "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"
        );
    }
    #[test]
    fn verify_is_exact() {
        let t = hmac_sha256(b"k", b"m");
        assert!(hmac_verify(b"k", b"m", &t));
        assert!(!hmac_verify(b"k", b"m2", &t));
        assert!(!hmac_verify(b"k2", b"m", &t));
        assert!(!hmac_verify(b"k", b"m", &t[..31]));
    }
}
