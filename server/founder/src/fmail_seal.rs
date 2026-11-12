//! Q1b (founder mailbox): SEALING. Every mail body, subject, address list and attachment name is AES-256-GCM sealed here BEFORE it reaches the database
//! (E167 has no plain column). Pure + ring: no network, no database. One message key per message; the key is then wrapped (fmail_kem.rs for the
//! post-quantum recipient mode, `wrap_vault` for the vault mode). Blind indexes (HMAC-SHA-256, a per-mailbox key derived from the vault master) let the
//! database thread and filter by equality without ever seeing the text. Tests below are the proof; nothing here is a mock.
use ring::{aead, hkdf, hmac, rand::{SecureRandom, SystemRandom}};
use sha2::{Digest, Sha256};

pub const NONCE_LEN: usize = 12;
pub const TAG_LEN: usize = 16;
pub type Key = [u8; 32];

struct Len(usize);
impl hkdf::KeyType for Len { fn len(&self) -> usize { self.0 } }

/// A fresh random 256-bit message key.
pub fn new_key() -> Result<Key, &'static str> { let mut k = [0u8; 32]; SystemRandom::new().fill(&mut k).map_err(|_| "random failed")?; Ok(k) }

/// Length-prefixed fields: a field can never run into the next one, so the AAD has ONE reading (same idea as the ledger hash).
pub fn aad(parts: &[&str]) -> Vec<u8> {
    let mut v = Vec::with_capacity(32 + parts.iter().map(|p| p.len() + 6).sum::<usize>());
    v.extend_from_slice(b"fmail-aad-v1");
    for p in parts { v.extend_from_slice(&(p.len() as u32).to_be_bytes()); v.extend_from_slice(p.as_bytes()); }
    v
}
/// SHA-256 of the AAD: stored next to the message (E167 aad_hash), so the engine can later prove which mailbox / id / direction / time a seal is bound to.
pub fn aad_hash(aad: &[u8]) -> [u8; 32] { Sha256::digest(aad).into() }

/// Seal `plain` with AES-256-GCM. Returns (nonce, ciphertext || tag). The nonce is random 96-bit: with ONE key per message and at most a handful of seals
/// per key (body, meta, names) the collision risk is nil; a counter nonce is used only for attachment chunks (fmail_att, kernel stream@1).
pub fn seal(key: &Key, aad: &[u8], plain: &[u8]) -> Result<([u8; NONCE_LEN], Vec<u8>), &'static str> {
    let mut nonce = [0u8; NONCE_LEN]; SystemRandom::new().fill(&mut nonce).map_err(|_| "random failed")?;
    let k = aead::LessSafeKey::new(aead::UnboundKey::new(&aead::AES_256_GCM, key).map_err(|_| "bad key")?);
    let mut buf = plain.to_vec();
    k.seal_in_place_append_tag(aead::Nonce::assume_unique_for_key(nonce), aead::Aad::from(aad), &mut buf).map_err(|_| "seal failed")?;
    Ok((nonce, buf))
}
/// Open. None on ANY mismatch (wrong key, wrong aad, flipped bit, truncated): never a partial plain text.
pub fn open(key: &Key, nonce: &[u8], aad: &[u8], sealed: &[u8]) -> Option<Vec<u8>> {
    if nonce.len() != NONCE_LEN || sealed.len() < TAG_LEN { return None; }
    let n: [u8; NONCE_LEN] = nonce.try_into().ok()?;
    let k = aead::LessSafeKey::new(aead::UnboundKey::new(&aead::AES_256_GCM, key).ok()?);
    let mut buf = sealed.to_vec();
    let out = k.open_in_place(aead::Nonce::assume_unique_for_key(n), aead::Aad::from(aad), &mut buf).ok()?;
    Some(out.to_vec())
}

/// VAULT wrap of a message key (seal_mode 'vault'): AES-256-GCM under a key derived from the vault master + the key id. Layout = nonce(12) || sealed key(48).
pub fn wrap_vault(master: &Key, key_id: &str, msg_key: &Key) -> Result<Vec<u8>, &'static str> {
    let k = derive(master, "fmail-vault-wrap-v1", key_id)?;
    let (n, ct) = seal(&k, &aad(&["vault-wrap", key_id]), msg_key)?;
    let mut out = n.to_vec(); out.extend_from_slice(&ct); Ok(out)
}
pub fn unwrap_vault(master: &Key, key_id: &str, blob: &[u8]) -> Option<Key> {
    if blob.len() != NONCE_LEN + 32 + TAG_LEN { return None; }
    let k = derive(master, "fmail-vault-wrap-v1", key_id).ok()?;
    let pt = open(&k, &blob[..NONCE_LEN], &aad(&["vault-wrap", key_id]), &blob[NONCE_LEN..])?;
    pt.try_into().ok()
}

/// HKDF-SHA256 domain-separated derivation from the vault master (the same master file the vault lease uses; the `info` strings never overlap).
pub fn derive(master: &Key, purpose: &str, ctx: &str) -> Result<Key, &'static str> {
    let prk = hkdf::Salt::new(hkdf::HKDF_SHA256, b"anexomail-fmail-v1").extract(master);
    let info = [purpose.as_bytes(), b"|", ctx.as_bytes()];
    let mut out = [0u8; 32];
    prk.expand(&info, Len(32)).map_err(|_| "hkdf")?.fill(&mut out).map_err(|_| "hkdf")?; Ok(out)
}
/// The per-mailbox blind-index key.
pub fn blind_key(master: &Key, mailbox_id: &str) -> Result<Key, &'static str> { derive(master, "fmail-blind-v1", mailbox_id) }

/// Blind index: HMAC-SHA-256(key, field || 0x00 || value). `field` separates the index spaces (a subject can never equal an address).
pub fn blind(key: &Key, field: &str, value: &str) -> [u8; 32] {
    let k = hmac::Key::new(hmac::HMAC_SHA256, key);
    let mut ctx = hmac::Context::with_key(&k); ctx.update(field.as_bytes()); ctx.update(&[0]); ctx.update(value.as_bytes());
    let t = ctx.sign(); let mut o = [0u8; 32]; o.copy_from_slice(t.as_ref()); o
}

/// Subject for threading: strip leading Re:/Fwd:/Fw:/Aw:/Sv: (repeated, any case), collapse white space, lowercase, cap 300 chars.
pub fn norm_subject(s: &str) -> String {
    let mut t = s.trim();
    loop {
        let l = t.to_ascii_lowercase();
        let cut = ["re:", "fwd:", "fw:", "aw:", "sv:", "re :"].iter().find(|p| l.starts_with(**p)).map(|p| p.len());
        match cut { Some(n) => t = t[n..].trim_start(), None => break }
    }
    let mut out = String::with_capacity(t.len());
    for w in t.split_whitespace() { if !out.is_empty() { out.push(' '); } out.push_str(w); }
    out.to_lowercase().chars().take(300).collect()
}
/// Address for matching: lowercase, no angle brackets, no surrounding space.
pub fn norm_addr(a: &str) -> String { a.trim().trim_start_matches('<').trim_end_matches('>').trim().to_ascii_lowercase() }
/// Message-ID for matching: no angle brackets, lowercase.
pub fn norm_msgid(m: &str) -> String { m.trim().trim_start_matches('<').trim_end_matches('>').trim().to_ascii_lowercase() }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn seal_open_roundtrip_and_every_tamper_fails() {
        let k = new_key().unwrap(); let a = aad(&["mb1", "msg1", "in", "1700000000000"]);
        let (n, ct) = seal(&k, &a, b"top secret body").unwrap();
        assert_eq!(ct.len(), 15 + TAG_LEN); assert_eq!(open(&k, &n, &a, &ct).unwrap(), b"top secret body");
        let mut bad = ct.clone(); bad[3] ^= 1; assert!(open(&k, &n, &a, &bad).is_none(), "flipped bit");
        assert!(open(&k, &n, &aad(&["mb1", "msg1", "out", "1700000000000"]), &ct).is_none(), "aad binds the direction");
        assert!(open(&k, &n, &aad(&["mb2", "msg1", "in", "1700000000000"]), &ct).is_none(), "aad binds the mailbox");
        let k2 = new_key().unwrap(); assert!(open(&k2, &n, &a, &ct).is_none(), "wrong key");
        assert!(open(&k, &n, &a, &ct[..ct.len() - 1]).is_none(), "truncated");
        assert!(open(&k, &n[..11], &a, &ct).is_none(), "short nonce");
        assert!(open(&k, &n, &a, &ct[..5]).is_none(), "shorter than a tag");
    }
    #[test]
    fn two_seals_of_the_same_text_differ() {
        let k = new_key().unwrap(); let a = aad(&["x"]);
        let (n1, c1) = seal(&k, &a, b"same").unwrap(); let (n2, c2) = seal(&k, &a, b"same").unwrap();
        assert!(n1 != n2 && c1 != c2, "random nonce: equal texts must not look equal");
    }
    #[test]
    fn aad_fields_cannot_run_together() { assert_ne!(aad(&["ab", "c"]), aad(&["a", "bc"])); assert_eq!(aad_hash(&aad(&["a"])).len(), 32); }
    #[test]
    fn vault_wrap_roundtrip_and_binds_the_key_id() {
        let m = new_key().unwrap(); let mk = new_key().unwrap();
        let w = wrap_vault(&m, "vk-1", &mk).unwrap(); assert_eq!(w.len(), 60);
        assert_eq!(unwrap_vault(&m, "vk-1", &w).unwrap(), mk);
        assert!(unwrap_vault(&m, "vk-2", &w).is_none()); assert!(unwrap_vault(&new_key().unwrap(), "vk-1", &w).is_none());
        let mut bad = w.clone(); bad[40] ^= 1; assert!(unwrap_vault(&m, "vk-1", &bad).is_none()); assert!(unwrap_vault(&m, "vk-1", &w[..59]).is_none());
    }
    #[test]
    fn derivation_is_domain_separated_and_stable() {
        let m = [7u8; 32];
        assert_eq!(derive(&m, "a", "x").unwrap(), derive(&m, "a", "x").unwrap());
        assert_ne!(derive(&m, "a", "x").unwrap(), derive(&m, "b", "x").unwrap()); assert_ne!(derive(&m, "a", "x").unwrap(), derive(&m, "a", "y").unwrap());
        assert_ne!(blind_key(&m, "mb1").unwrap(), blind_key(&m, "mb2").unwrap());
    }
    #[test]
    fn blind_index_equality_only() {
        let k = blind_key(&[1u8; 32], "mb1").unwrap();
        assert_eq!(blind(&k, "subject", "hello"), blind(&k, "subject", "hello"));
        assert_ne!(blind(&k, "subject", "hello"), blind(&k, "sender", "hello"), "fields are separate spaces");
        assert_ne!(blind(&k, "subject", "hello"), blind(&k, "subject", "hellp"));
        assert_ne!(blind(&k, "subject", "hello"), blind(&blind_key(&[1u8; 32], "mb2").unwrap(), "subject", "hello"), "per mailbox");
    }
    #[test]
    fn subject_threading_normalisation() {
        assert_eq!(norm_subject("Re: RE: Fwd:  Quarterly   Plan "), "quarterly plan");
        assert_eq!(norm_subject("AW: Sv: hello"), "hello"); assert_eq!(norm_subject("Reply later"), "reply later");
        assert_eq!(norm_subject("Re:"), ""); assert_eq!(norm_subject(&"x".repeat(900)).len(), 300);
        assert_eq!(norm_addr(" <Boss@Example.ORG> "), "boss@example.org"); assert_eq!(norm_msgid(" <AbC@Host> "), "abc@host");
    }
}
