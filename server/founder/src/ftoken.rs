//! Founder token (F1a): ES256 JWT, `aud=iss=anexo-founder`, TTL 15 min, device-bound (`did`). Awam/Supabase token se ALAG key (alag trust).
//! Browser ise sirf MEMORY mein rakhta hai (storage kabhi nahi). Sirf audited crate `ring`; apna crypto nahi (FC15).
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD as B64};
use ring::rand::SystemRandom;
use ring::signature::{ECDSA_P256_SHA256_FIXED, ECDSA_P256_SHA256_FIXED_SIGNING, EcdsaKeyPair, KeyPair, UnparsedPublicKey};
use serde_json::{Value, json};

pub const AUD: &str = "anexo-founder";
pub const KID: &str = "f1";
pub const TTL_SECS: i64 = 900;
const SKEW: i64 = 60;

pub struct Keys { pair: EcdsaKeyPair, public: Vec<u8> }

#[derive(Debug, PartialEq, Clone)]
pub struct FClaims { pub sub: String, pub email: String, pub did: String, pub exp: i64 }

#[derive(Debug, PartialEq)]
pub enum FErr { Malformed, Alg, Kid, Signature, Aud, Expired, NotYet, Ttl }

impl Keys {
    /// PKCS#8 (DER) se. Galat file => None (server band nahi, bas exchange 503 dega).
    pub fn from_pkcs8(der: &[u8]) -> Option<Keys> {
        let pair = EcdsaKeyPair::from_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, der, &SystemRandom::new()).ok()?;
        let public = pair.public_key().as_ref().to_vec();
        Some(Keys { pair, public })
    }
    /// Naya key (installer ek baar chalata hai: `anexomail-founder --gen-token-key <file>`).
    pub fn generate_pkcs8() -> Option<Vec<u8>> {
        EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, &SystemRandom::new()).ok().map(|d| d.as_ref().to_vec())
    }
    pub fn mint(&self, sub: &str, email: &str, did: &str, now: i64) -> Option<(String, i64)> {
        let exp = now + TTL_SECS;
        let mut jti = [0u8; 16];
        ring::rand::SecureRandom::fill(&SystemRandom::new(), &mut jti).ok()?;
        let h = B64.encode(json!({"alg": "ES256", "typ": "JWT", "kid": KID}).to_string());
        let p = B64.encode(json!({"iss": AUD, "aud": AUD, "sub": sub, "email": email, "did": did, "iat": now, "exp": exp, "jti": B64.encode(jti)}).to_string());
        let msg = format!("{h}.{p}");
        let sig = self.pair.sign(&SystemRandom::new(), msg.as_bytes()).ok()?;
        Some((format!("{msg}.{}", B64.encode(sig.as_ref())), exp))
    }
    pub fn verify(&self, token: &str, now: i64) -> Result<FClaims, FErr> { verify(token, &self.public, now) }
}

/// Token ki header se sirf "kya yeh founder token hai" (verify nahi): kid == f1.
pub fn looks_founder(token: &str) -> bool {
    let Some(h) = token.split('.').next() else { return false };
    let Ok(raw) = B64.decode(h) else { return false };
    serde_json::from_slice::<Value>(&raw).ok().and_then(|v| v["kid"].as_str().map(|k| k == KID)).unwrap_or(false)
}

pub fn verify(token: &str, public: &[u8], now: i64) -> Result<FClaims, FErr> {
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() != 3 || token.len() > 4096 { return Err(FErr::Malformed); }
    let hdr: Value = serde_json::from_slice(&B64.decode(parts[0]).map_err(|_| FErr::Malformed)?).map_err(|_| FErr::Malformed)?;
    if hdr["alg"].as_str() != Some("ES256") { return Err(FErr::Alg); } // none / HS256 / RS256: kabhi nahi
    if hdr["kid"].as_str() != Some(KID) { return Err(FErr::Kid); }
    let sig = B64.decode(parts[2]).map_err(|_| FErr::Malformed)?;
    let msg = format!("{}.{}", parts[0], parts[1]);
    UnparsedPublicKey::new(&ECDSA_P256_SHA256_FIXED, public).verify(msg.as_bytes(), &sig).map_err(|_| FErr::Signature)?;
    let c: Value = serde_json::from_slice(&B64.decode(parts[1]).map_err(|_| FErr::Malformed)?).map_err(|_| FErr::Malformed)?;
    if c["aud"].as_str() != Some(AUD) || c["iss"].as_str() != Some(AUD) { return Err(FErr::Aud); }
    let (iat, exp) = (c["iat"].as_i64().ok_or(FErr::Malformed)?, c["exp"].as_i64().ok_or(FErr::Malformed)?);
    if exp <= now { return Err(FErr::Expired); }
    if iat > now + SKEW { return Err(FErr::NotYet); }
    if exp - iat > TTL_SECS { return Err(FErr::Ttl); }
    let s = |k: &str| c[k].as_str().filter(|x| !x.is_empty()).map(String::from).ok_or(FErr::Malformed);
    Ok(FClaims { sub: s("sub")?, email: c["email"].as_str().unwrap_or("").to_string(), did: s("did")?, exp })
}

/// sha256(device_id) hex — DB mein raw device_id kabhi nahi.
pub fn device_hash(device_id: &str) -> String { hex::encode(ring::digest::digest(&ring::digest::SHA256, device_id.as_bytes()).as_ref()) }

/// device_id: browser ka random (kam az kam 32 akshar, sirf url-safe), warna reject.
pub fn valid_device_id(d: &str) -> bool { (32..=128).contains(&d.len()) && d.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_') }

pub fn clean_label(l: &str) -> String {
    let s: String = l.chars().filter(|c| (' '..='~').contains(c)).take(80).collect();
    let s = s.trim().to_string();
    if s.is_empty() { "Browser".into() } else { s }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn keys() -> Keys { Keys::from_pkcs8(&Keys::generate_pkcs8().unwrap()).unwrap() }
    #[test]
    fn roundtrip_and_claims() {
        let k = keys();
        let (t, exp) = k.mint("u1", "a@b.c", "dev-1", 1000).unwrap();
        assert_eq!(exp, 1900);
        let c = k.verify(&t, 1100).unwrap();
        assert_eq!((c.sub.as_str(), c.did.as_str(), c.exp), ("u1", "dev-1", 1900));
        assert!(looks_founder(&t));
    }
    #[test]
    fn expired_and_future() {
        let k = keys();
        let (t, _) = k.mint("u1", "e", "d", 1000).unwrap();
        assert_eq!(k.verify(&t, 1900), Err(FErr::Expired));
        assert_eq!(k.verify(&t, 900), Err(FErr::NotYet));
    }
    #[test]
    fn wrong_key_rejected() {
        let (a, b) = (keys(), keys());
        let (t, _) = a.mint("u1", "e", "d", 1000).unwrap();
        assert_eq!(b.verify(&t, 1100), Err(FErr::Signature));
    }
    #[test]
    fn tampered_payload_rejected() {
        let k = keys();
        let (t, _) = k.mint("u1", "e", "d", 1000).unwrap();
        let p: Vec<&str> = t.split('.').collect();
        let evil = B64.encode(json!({"iss": AUD, "aud": AUD, "sub": "attacker", "email": "e", "did": "d", "iat": 1000, "exp": 1900}).to_string());
        assert_eq!(k.verify(&format!("{}.{}.{}", p[0], evil, p[2]), 1100), Err(FErr::Signature));
    }
    #[test]
    fn alg_none_and_hs256_never() {
        let k = keys();
        let (t, _) = k.mint("u1", "e", "d", 1000).unwrap();
        let p: Vec<&str> = t.split('.').collect();
        for alg in ["none", "HS256", "RS256"] {
            let h = B64.encode(json!({"alg": alg, "typ": "JWT", "kid": KID}).to_string());
            assert_eq!(k.verify(&format!("{h}.{}.{}", p[1], p[2]), 1100), Err(FErr::Alg), "{alg}");
        }
        let h = B64.encode(json!({"alg": "ES256", "kid": "other"}).to_string());
        assert_eq!(k.verify(&format!("{h}.{}.{}", p[1], p[2]), 1100), Err(FErr::Kid));
    }
    #[test]
    fn aud_and_ttl_checked() {
        let k = keys();
        // sahi key se sign par ghalat aud / lamba TTL
        let mk = |aud: &str, iat: i64, exp: i64| {
            let h = B64.encode(json!({"alg": "ES256", "typ": "JWT", "kid": KID}).to_string());
            let p = B64.encode(json!({"iss": AUD, "aud": aud, "sub": "u", "email": "e", "did": "d", "iat": iat, "exp": exp}).to_string());
            let m = format!("{h}.{p}");
            format!("{m}.{}", B64.encode(k.pair.sign(&SystemRandom::new(), m.as_bytes()).unwrap().as_ref()))
        };
        assert_eq!(k.verify(&mk("authenticated", 1000, 1900), 1100), Err(FErr::Aud)); // awam token ka aud founder par nahi chalta
        assert_eq!(k.verify(&mk(AUD, 1000, 99999), 1100), Err(FErr::Ttl));
        assert!(k.verify(&mk(AUD, 1000, 1900), 1100).is_ok());
    }
    #[test]
    fn malformed_shapes() {
        let k = keys();
        for t in ["", "a", "a.b", "a.b.c.d", "!!.@@.##", &"x".repeat(5000)] { assert_eq!(k.verify(t, 1), Err(FErr::Malformed), "{t:?}"); }
        assert!(!looks_founder("garbage"));
    }
    #[test]
    fn device_helpers() {
        assert_eq!(device_hash("abc").len(), 64);
        assert_ne!(device_hash("a"), device_hash("b"));
        assert!(valid_device_id(&"a".repeat(32)));
        assert!(!valid_device_id("short") && !valid_device_id(&"a".repeat(129)) && !valid_device_id(&format!("{}!", "a".repeat(40))));
        assert_eq!(clean_label("  My Laptop\u{202e}\n "), "My Laptop");
        assert_eq!(clean_label("\u{1F600}"), "Browser");
    }
    #[test]
    fn pkcs8_roundtrip_garbage() {
        assert!(Keys::from_pkcs8(b"not a key").is_none());
        assert!(Keys::from_pkcs8(&Keys::generate_pkcs8().unwrap()).is_some());
    }
}
