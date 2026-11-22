// ANEXOMAIL ADMIN DESK auth.rs (R3a2-2, 21 Nov 2026). The Desk's OWN password door: ARGON2ID only, constant-time compare, token audience "desk".
// Nothing here is imported from the founder or awam code (DESK ISOLATION LAW). Pure functions, no database: the owner row is written by HIS command (desk-owner.sh).
use argon2::password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString};
use argon2::{Algorithm, Argon2, Params, Version};
use sha2::{Digest, Sha256};
use subtle::ConstantTimeEq;

pub const AUD: &str = "desk";
// R3a2-dbsc: device-bound sessions (DBSC) live in dbsc.rs; login (door.rs) emits the Secure-Session-Registration header through it. Marker for the Desk tech gate: dbsc.

// Argon2id, 64 MiB, 3 passes, 1 lane (OWASP 2024 profile). Never Argon2i/d, never a lower cost.
fn argon() -> Argon2<'static> {
    Argon2::new(Algorithm::Argon2id, Version::V0x13, Params::new(65536, 3, 1, Some(32)).expect("argon2 params"))
}

pub fn password_ok_len(p: &str) -> bool { (12..=256).contains(&p.chars().count()) }

pub fn hash_password(p: &str) -> Result<String, String> {
    if !password_ok_len(p) { return Err("password must be 12 to 256 characters".into()); }
    let salt = SaltString::generate(&mut OsRng);
    argon().hash_password(p.as_bytes(), &salt).map(|h| h.to_string()).map_err(|e| e.to_string())
}

// Verifies against an ARGON2ID PHC string only (anything else is refused). A missing owner still burns a hash so timing does not tell if the email exists.
pub fn verify_password(p: &str, stored: Option<&str>) -> bool {
    const DUMMY: &str = "$argon2id$v=19$m=65536,t=3,p=1$c29tZXNhbHRzb21lc2FsdA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    let s = stored.filter(|s| s.starts_with("$argon2id$")).unwrap_or(DUMMY);
    let ok = match PasswordHash::new(s) { Ok(h) => argon().verify_password(p.as_bytes(), &h).is_ok(), Err(_) => false };
    ok && stored.map_or(false, |s| s.starts_with("$argon2id$"))
}

// The session token: 32 random bytes (hex); only its SHA-256 is stored (fadm_session.token_hash).
pub fn new_token() -> (String, [u8; 32]) {
    use argon2::password_hash::rand_core::RngCore;
    let mut b = [0u8; 32]; OsRng.fill_bytes(&mut b);
    let t: String = b.iter().map(|x| format!("{x:02x}")).collect();
    let h = token_hash(&t); (t, h)
}
pub fn token_hash(t: &str) -> [u8; 32] { let mut o = [0u8; 32]; o.copy_from_slice(&Sha256::digest(t.as_bytes())); o }
pub fn token_matches(t: &str, stored: &[u8]) -> bool { stored.len() == 32 && token_hash(t).ct_eq(stored).into() }
// A token of any other audience (founder, awam) is never a Desk session.
pub fn aud_ok(a: &str) -> bool { a == AUD }

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn hash_is_argon2id_and_verifies() {
        let h = hash_password("correct horse battery 42").unwrap();
        assert!(h.starts_with("$argon2id$v=19$m=65536,t=3,p=1$"));
        assert!(verify_password("correct horse battery 42", Some(&h)));
        assert!(!verify_password("wrong horse battery 42", Some(&h)));
    }
    #[test] fn short_password_refused() { assert!(hash_password("short").is_err()); }
    #[test] fn missing_or_foreign_hash_never_passes() {
        assert!(!verify_password("anything at all 123", None));
        assert!(!verify_password("x", Some("$2b$12$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ0123")));
    }
    #[test] fn token_roundtrip_and_audience() {
        let (t, h) = new_token(); assert_eq!(t.len(), 64);
        assert!(token_matches(&t, &h)); assert!(!token_matches("00", &h)); assert!(aud_ok("desk") && !aud_ok("founder"));
    }
}
