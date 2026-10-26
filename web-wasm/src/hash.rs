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
