// vault_core.rs — identity vault, pure half (std only; unit-tested). Rust PRIMARY from Auth Phase A (Rule 45).
// Same bytes as SQL E68/E69 and server/lib/identity-mirror.ts (parity vectors below are also in CHECK_E69):
//   hmac_hex(kind, canon, key) = HMAC_SHA256( HMAC_SHA256(key, "anexomail/identity/v1/<kind>"), canon )
// Holds: SHA-256/HMAC, email canonicalisation, signal building, the local ban MIRROR and the sign-up decision policy.
// No I/O here: glue (feed fetch, LISTEN/poll, outbox file) lives in vault_glue.rs when sign-in moves to Rust.

use std::collections::HashMap;

// ---- SHA-256 / HMAC (FIPS 180-4 / RFC 2104) -------------------------------------------------------------------------
const K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

pub fn sha256(data: &[u8]) -> [u8; 32] {
    let mut h: [u32; 8] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
    let mut msg = data.to_vec();
    msg.push(0x80);
    while msg.len() % 64 != 56 {
        msg.push(0);
    }
    msg.extend_from_slice(&((data.len() as u64) * 8).to_be_bytes());
    for chunk in msg.chunks(64) {
        let mut w = [0u32; 64];
        for i in 0..16 {
            w[i] = u32::from_be_bytes([chunk[4 * i], chunk[4 * i + 1], chunk[4 * i + 2], chunk[4 * i + 3]]);
        }
        for i in 16..64 {
            let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
            let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16].wrapping_add(s0).wrapping_add(w[i - 7]).wrapping_add(s1);
        }
        let mut v = h;
        for i in 0..64 {
            let s1 = v[4].rotate_right(6) ^ v[4].rotate_right(11) ^ v[4].rotate_right(25);
            let ch = (v[4] & v[5]) ^ (!v[4] & v[6]);
            let t1 = v[7].wrapping_add(s1).wrapping_add(ch).wrapping_add(K[i]).wrapping_add(w[i]);
            let s0 = v[0].rotate_right(2) ^ v[0].rotate_right(13) ^ v[0].rotate_right(22);
            let maj = (v[0] & v[1]) ^ (v[0] & v[2]) ^ (v[1] & v[2]);
            let t2 = s0.wrapping_add(maj);
            v = [t1.wrapping_add(t2), v[0], v[1], v[2], v[3].wrapping_add(t1), v[4], v[5], v[6]];
        }
        for i in 0..8 {
            h[i] = h[i].wrapping_add(v[i]);
        }
    }
    let mut out = [0u8; 32];
    for (i, x) in h.iter().enumerate() {
        out[4 * i..4 * i + 4].copy_from_slice(&x.to_be_bytes());
    }
    out
}

pub fn hmac_sha256(key: &[u8], msg: &[u8]) -> [u8; 32] {
    let mut k = if key.len() > 64 { sha256(key).to_vec() } else { key.to_vec() };
    k.resize(64, 0);
    let mut inner: Vec<u8> = k.iter().map(|b| b ^ 0x36).collect();
    inner.extend_from_slice(msg);
    let ih = sha256(&inner);
    let mut outer: Vec<u8> = k.iter().map(|b| b ^ 0x5c).collect();
    outer.extend_from_slice(&ih);
    sha256(&outer)
}

pub fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{:02x}", x)).collect()
}

// ---- identity signals ---------------------------------------------------------------------------------------------
pub fn is_strong(kind: &str) -> bool {
    matches!(kind, "device_key" | "email" | "recovery" | "payment")
}

pub fn canon_email(raw: &str) -> Option<String> {
    let at = raw.find('@')?;
    if at < 1 {
        return None;
    }
    let mut parts = raw.split('@');
    let local0 = parts.next()?.trim().to_lowercase();
    let domain = parts.next().unwrap_or("").trim().to_lowercase();
    let local = local0.split('+').next().unwrap_or("").to_string();
    if domain == "gmail.com" || domain == "googlemail.com" {
        Some(format!("{}@gmail.com", local.replace('.', "")))
    } else {
        Some(format!("{}@{}", local, domain))
    }
}

pub fn hmac_hex(kind: &str, canon: &str, key: &str) -> Option<String> {
    if canon.trim().is_empty() {
        return None;
    }
    let k = if key.is_empty() { "no-pepper" } else { key };
    let sub = hmac_sha256(k.as_bytes(), format!("anexomail/identity/v1/{}", kind).as_bytes());
    Some(hex(&hmac_sha256(&sub, canon.as_bytes())))
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Signal {
    pub kind: String,
    pub hmac: String,
}

#[derive(Default)]
pub struct RawIdentity<'a> {
    pub email: Option<&'a str>,
    pub recovery: Option<&'a str>,
    pub device_key: Option<&'a str>,
    pub shape: Option<&'a str>,
    pub network: Option<&'a str>,
}

pub fn signals_raw(r: &RawIdentity, key: &str) -> Vec<Signal> {
    let lower = |v: Option<&str>| v.map(|x| x.trim().to_lowercase());
    let rows: [(&str, Option<String>); 5] = [
        ("email", r.email.and_then(canon_email)),
        ("recovery", r.recovery.and_then(canon_email)),
        ("device_key", lower(r.device_key)),
        ("device_shape", lower(r.shape)),
        ("network", lower(r.network)),
    ];
    rows.iter()
        .filter_map(|(k, c)| c.as_ref().and_then(|c| hmac_hex(k, c, key)).map(|h| Signal { kind: (*k).to_string(), hmac: h }))
        .collect()
}

// ---- local mirror ---------------------------------------------------------------------------------------------------
#[derive(Debug, Clone)]
pub struct FeedRow {
    pub kind: String,
    pub hmac: String,
    pub active: bool,
    pub expires: Option<i64>,
}

#[derive(Default)]
pub struct Mirror {
    set: HashMap<String, Option<i64>>,
    pub ready: bool,
}

impl Mirror {
    pub fn apply(&mut self, rows: &[FeedRow], full: bool) {
        if full {
            self.set.clear();
        }
        for r in rows {
            let ok = is_strong(&r.kind) && r.hmac.len() == 64 && r.hmac.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b));
            if !ok {
                continue;
            }
            let key = format!("{}:{}", r.kind, r.hmac);
            if r.active {
                self.set.insert(key, r.expires);
            } else {
                self.set.remove(&key);
            }
        }
        self.ready = true;
    }
    pub fn size(&self) -> usize {
        self.set.len()
    }
    pub fn deny(&self, signals: &[Signal], now_s: i64) -> Vec<String> {
        let mut hit: Vec<String> = Vec::new();
        for s in signals {
            if !is_strong(&s.kind) {
                continue;
            }
            if let Some(exp) = self.set.get(&format!("{}:{}", s.kind, s.hmac)) {
                if exp.map_or(true, |e| e > now_s) && !hit.contains(&s.kind) {
                    hit.push(s.kind.clone());
                }
            }
        }
        hit.sort();
        hit
    }
}

// ---- policy ----------------------------------------------------------------------------------------------------------
#[derive(Debug, PartialEq, Eq)]
pub enum Db {
    Deny,
    Review,
    Allow,
    Down,
    NotInstalled,
}

#[derive(Debug, PartialEq, Eq)]
pub enum Verdict {
    Deny,
    Allow,
    Review,
    Closed,
}

/// mirror deny wins; database is authoritative otherwise; DB down => mirror (if loaded) else CLOSED; not installed => out of the way.
pub fn decide(mirror_ready: bool, mirror_deny: &[String], db: Db) -> Verdict {
    if !mirror_deny.is_empty() {
        return Verdict::Deny;
    }
    match db {
        Db::Deny => Verdict::Deny,
        Db::Review => Verdict::Review,
        Db::Allow | Db::NotInstalled => Verdict::Allow,
        Db::Down => {
            if mirror_ready {
                Verdict::Allow
            } else {
                Verdict::Closed
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sha256_known_answers() {
        assert_eq!(hex(&sha256(b"")), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
        assert_eq!(hex(&sha256(b"abc")), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        let long = vec![b'a'; 1000];
        assert_eq!(hex(&sha256(&long)), "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3");
    }

    #[test]
    fn hmac_rfc4231_case_2() {
        assert_eq!(hex(&hmac_sha256(b"Jefe", b"what do ya want for nothing?")), "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843");
    }

    #[test]
    fn parity_with_sql_and_bun() {
        assert_eq!(hmac_hex("email", "a@b.com", "k").unwrap(), "63421a113608fece1cb4ee68e688cce63c4fa2fec389a00b32f99f3d493452b6");
        assert_eq!(hmac_hex("device_key", "dk-1", "k").unwrap(), "ff7275b6820ec180d412d136d6db70aa3b438b4bc0c62dea759db9e1d2ed326f");
        assert_eq!(canon_email("Ali.Khan+x@GoogleMail.com").unwrap(), "alikhan@gmail.com");
        assert_eq!(canon_email("A+b@Outlook.com").unwrap(), "a@outlook.com");
        assert!(canon_email("nope").is_none());
        assert!(canon_email("@x.com").is_none());
    }

    #[test]
    fn signals_only_given_and_lowercased() {
        let s = signals_raw(&RawIdentity { email: Some("a@b.com"), device_key: Some("DK-1"), ..Default::default() }, "k");
        assert_eq!(s.iter().map(|x| x.kind.as_str()).collect::<Vec<_>>(), vec!["email", "device_key"]);
        assert_eq!(s[1].hmac, "ff7275b6820ec180d412d136d6db70aa3b438b4bc0c62dea759db9e1d2ed326f");
    }

    #[test]
    fn mirror_apply_remove_expire_weak() {
        let h = |c: char| c.to_string().repeat(64);
        let row = |k: &str, c: char, a: bool, e: Option<i64>| FeedRow { kind: k.into(), hmac: h(c), active: a, expires: e };
        let mut m = Mirror::default();
        assert!(!m.ready);
        m.apply(&[row("email", 'a', true, None), row("device_key", 'b', true, Some(100)), row("network", 'c', true, None), row("email", 'Z', true, None)], true);
        assert!(m.ready);
        assert_eq!(m.size(), 2);
        let sig = |k: &str, c: char| Signal { kind: k.into(), hmac: h(c) };
        assert_eq!(m.deny(&[sig("email", 'a')], 50), vec!["email".to_string()]);
        assert_eq!(m.deny(&[sig("device_key", 'b')], 50), vec!["device_key".to_string()]);
        assert!(m.deny(&[sig("device_key", 'b')], 100).is_empty());
        assert!(m.deny(&[sig("network", 'c')], 50).is_empty());
        m.apply(&[row("email", 'a', false, None)], false);
        assert!(m.deny(&[sig("email", 'a')], 50).is_empty());
        m.apply(&[], true);
        assert_eq!(m.size(), 0);
    }

    #[test]
    fn policy() {
        let none: Vec<String> = vec![];
        let hit = vec!["email".to_string()];
        assert_eq!(decide(true, &hit, Db::Down), Verdict::Deny);
        assert_eq!(decide(true, &none, Db::Deny), Verdict::Deny);
        assert_eq!(decide(true, &none, Db::Review), Verdict::Review);
        assert_eq!(decide(false, &none, Db::Allow), Verdict::Allow);
        assert_eq!(decide(true, &none, Db::Down), Verdict::Allow);
        assert_eq!(decide(false, &none, Db::Down), Verdict::Closed);
        assert_eq!(decide(false, &none, Db::NotInstalled), Verdict::Allow);
    }
}
