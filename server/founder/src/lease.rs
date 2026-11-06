//! J8b: the dead-man VAULT LEASE signer (founder go 6 Nov 2026). SQL E143 decides (device approved, not revoked, rate limits, clock guard); this module only
//! (1) turns the SQL answer into one STRICTLY validated, domain-separated record that the normal Ed25519 envelope signs, (2) maps a refusal to an honest HTTP status,
//! (3) runs the sweep that logs leases which ran out on their own. Fail-closed: any answer that is not exactly right is NEVER signed (502), so a bad row cannot become a valid lease.
//! J8b2 (E144): the server half of the vault key = HKDF-SHA256(master held ONLY here, salt = `half_salt` held ONLY in SQL, info = device id). Revoke destroys the salt in SQL, so the half can never be derived again.
//! A renewal needs a PROOF from the device key (ECDSA P-256, WebCrypto, non-extractable): signature over `anexo-lease-proof@1|device|ts_ms`, key bound once by its RFC 7638 thumbprint.
//! The browser kernel (J8c) checks: signature, `type`, `expires_ms`, and that the serial never goes backwards.
use base64::{engine::general_purpose::URL_SAFE_NO_PAD as B64U, Engine as _};
use ring::{digest, hkdf, signature};
use serde_json::{json, Value};
use std::sync::OnceLock;

pub const TYPE: &str = "vault-lease@1";
pub const TTL_MIN: i64 = 60;
pub const TTL_MAX: i64 = 3600;

fn int(v: &Value, k: &str) -> Option<i64> { v.get(k).and_then(Value::as_i64) }
fn hex_n(s: &str, n: usize) -> bool { s.len() == n && s.bytes().all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase()) }
fn uuid_ok(s: &str) -> bool { s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_hexdigit() && !b.is_ascii_uppercase() }) }


/// 32-byte master secret (file 0400, env FOUNDER_VAULT_MASTER_FILE). Loaded once at start; never logged, never leaves this process.
pub static MASTER: OnceLock<[u8; 32]> = OnceLock::new();
pub fn load_master(path: &str) -> bool {
    let Ok(t) = std::fs::read_to_string(path) else { return false };
    let Ok(b) = hex::decode(t.trim()) else { return false };
    match <[u8; 32]>::try_from(b.as_slice()) { Ok(a) => MASTER.set(a).is_ok(), Err(_) => false }
}
pub fn gen_master(path: &str) -> Result<(), String> {
    use ring::rand::SecureRandom;
    let mut k = [0u8; 32];
    ring::rand::SystemRandom::new().fill(&mut k).map_err(|_| "random failed".to_string())?;
    std::fs::write(path, hex::encode(k)).map_err(|e| e.to_string())
}

struct Len(usize);
impl hkdf::KeyType for Len { fn len(&self) -> usize { self.0 } }
/// The server half of the vault key. None if the salt is not 64 lowercase hex chars or the device id is not a uuid.
pub fn half(master: &[u8; 32], device_id: &str, half_salt_hex: &str) -> Option<String> {
    if !uuid_ok(&device_id.to_ascii_lowercase()) || !hex_n(half_salt_hex, 64) { return None; }
    let salt = hex::decode(half_salt_hex).ok()?;
    let prk = hkdf::Salt::new(hkdf::HKDF_SHA256, &salt).extract(master);
    let info = format!("anexo-vault-half@1|{}", device_id.to_ascii_lowercase());
    let mut out = [0u8; 32];
    prk.expand(&[info.as_bytes()], Len(32)).ok()?.fill(&mut out).ok()?;
    Some(B64U.encode(out))
}

/// RFC 7638 thumbprint of an EC P-256 JWK (members in lexicographic order, no spaces).
pub fn thumbprint(x: &str, y: &str) -> String { B64U.encode(digest::digest(&digest::SHA256, format!(r#"{{"crv":"P-256","kty":"EC","x":"{x}","y":"{y}"}}"#).as_bytes())) }

/// The device proof. `jwk` = {"kty":"EC","crv":"P-256","x","y"}; `sig` = base64url of the 64-byte r||s that WebCrypto ECDSA returns. Returns the thumbprint when (and only when) the signature is valid.
pub fn verify_proof(device_id: &str, ts_ms: i64, jwk: &Value, sig_b64: &str) -> Option<String> {
    if jwk.get("kty")?.as_str()? != "EC" || jwk.get("crv")?.as_str()? != "P-256" { return None; }
    let (x, y) = (jwk.get("x")?.as_str()?, jwk.get("y")?.as_str()?);
    let (xb, yb) = (B64U.decode(x).ok()?, B64U.decode(y).ok()?);
    if xb.len() != 32 || yb.len() != 32 || B64U.encode(&xb) != x || B64U.encode(&yb) != y { return None; }   // canonical encoding only: one key, one thumbprint
    let mut pubkey = vec![4u8]; pubkey.extend_from_slice(&xb); pubkey.extend_from_slice(&yb);
    let sig = B64U.decode(sig_b64).ok()?;
    if sig.len() != 64 { return None; }
    let msg = format!("anexo-lease-proof@1|{}|{}", device_id.to_ascii_lowercase(), ts_ms);
    signature::UnparsedPublicKey::new(&signature::ECDSA_P256_SHA256_FIXED, &pubkey).verify(msg.as_bytes(), &sig).ok()?;
    Some(thumbprint(x, y))
}

/// The record that gets signed. None when the SQL answer is anything but a perfectly formed, internally consistent lease.
pub fn lease_data(r: &Value, expect_device: &str, half_b64: &str) -> Option<Value> {
    if r.get("ok").and_then(Value::as_bool) != Some(true) { return None; }
    let device = r.get("device_id")?.as_str()?;
    let nonce = r.get("nonce")?.as_str()?;
    let key_thumb = r.get("key_thumb")?.as_str()?;
    if key_thumb.len() != 43 || half_b64.len() != 43 || !key_thumb.bytes().chain(half_b64.bytes()).all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_') { return None; }
    let (serial, issued, expires, ttl) = (int(r, "serial")?, int(r, "issued_ms")?, int(r, "expires_ms")?, int(r, "ttl_s")?);
    if !uuid_ok(device) || device != expect_device.to_ascii_lowercase() || !hex_n(nonce, 32) { return None; }
    if serial < 1 || issued <= 0 || !(TTL_MIN..=TTL_MAX).contains(&ttl) || expires != issued.checked_add(ttl.checked_mul(1000)?)? { return None; }
    Some(json!({"type": TYPE, "device_id": device, "serial": serial, "issued_ms": issued, "expires_ms": expires, "ttl_s": ttl, "nonce": nonce, "key_thumb": key_thumb, "half": half_b64}))
}

/// Refusal reason (from E143) to HTTP status. Unknown reasons are a server fault, never a silent 200.
pub fn refusal_status(why: &str) -> u16 {
    match why { "revoked" | "not_approved" | "not_your_device" | "unknown_device" => 403, "too_fast" | "too_many" => 429, "clock_back" | "proof_replayed" => 409, "key_mismatch" | "proof_stale" | "key_required" => 403, _ => 502 }
}
/// Words for the person (the UI shows them; no internal names).
pub fn refusal_text(why: &str) -> &'static str {
    match why {
        "revoked" => "This device was revoked. Its vault stays locked.",
        "not_approved" => "This device is not approved yet.",
        "not_your_device" | "unknown_device" => "This device is not known to the account.",
        "too_fast" => "Renewed a moment ago. Try again shortly.",
        "too_many" => "Too many renewals this hour. Wait and try again.",
        "clock_back" => "The server clock went backwards; no lease was given.",
        "key_mismatch" => "This is not the device key the lease was bound to.",
        "key_required" | "proof_stale" => "The device proof was missing or out of date.",
        "proof_replayed" => "That device proof was already used.",
        _ => "No lease was given.",
    }
}

/// Every 60 s: log leases that ended by themselves (once each). Silent when the SQL is not installed yet.
pub fn spawn_sweep(sb: crate::data::Sb) {
    tokio::spawn(async move {
        loop {
            let _ = sb.rpc("founder_vault_lease_sweep", json!({})).await;
            tokio::time::sleep(std::time::Duration::from_secs(60)).await;
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    const D: &str = "0f8fad5b-d9cb-469f-a165-70867728950e";
    fn good() -> Value { json!({"ok": true, "device_id": D, "serial": 3, "issued_ms": 1_700_000_000_000i64, "expires_ms": 1_700_000_900_000i64, "ttl_s": 900, "nonce": "0123456789abcdef0123456789abcdef", "key_thumb": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}) }
    const H: &str = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";

    #[test] fn a_good_answer_becomes_one_typed_record() {
        let d = lease_data(&good(), D, H).unwrap();
        assert_eq!(d["type"], TYPE); assert_eq!(d["serial"], 3); assert_eq!(d["ttl_s"], 900);
        assert_eq!(d.as_object().unwrap().len(), 9, "exactly these fields, nothing the SQL added by accident");
    }
    #[test] fn the_device_in_the_answer_must_be_the_caller() {
        assert!(lease_data(&good(), "ffffffff-d9cb-469f-a165-70867728950e", H).is_none());
        assert!(lease_data(&good(), &D.to_ascii_uppercase(), H).is_some(), "case does not matter for the caller id");
    }
    #[test] fn not_ok_or_missing_fields_are_never_signed() {
        let mut r = good(); r["ok"] = json!(false); assert!(lease_data(&r, D, H).is_none());
        for k in ["device_id", "serial", "issued_ms", "expires_ms", "ttl_s", "nonce", "ok", "key_thumb"] { let mut r = good(); r.as_object_mut().unwrap().remove(k); assert!(lease_data(&r, D, H).is_none(), "{k}"); }
        assert!(lease_data(&json!(null), D, H).is_none() && lease_data(&json!({}), D, H).is_none());
    }
    #[test] fn the_times_must_agree_exactly() {
        let mut r = good(); r["expires_ms"] = json!(1_700_000_900_001i64); assert!(lease_data(&r, D, H).is_none(), "expires must be issued + ttl");
        let mut r = good(); r["ttl_s"] = json!(59); r["expires_ms"] = json!(1_700_000_059_000i64); assert!(lease_data(&r, D, H).is_none(), "ttl floor");
        let mut r = good(); r["ttl_s"] = json!(3601); r["expires_ms"] = json!(1_700_003_601_000i64); assert!(lease_data(&r, D, H).is_none(), "ttl cap");
        let mut r = good(); r["serial"] = json!(0); assert!(lease_data(&r, D, H).is_none());
        let mut r = good(); r["issued_ms"] = json!(i64::MAX); r["expires_ms"] = json!(i64::MAX); assert!(lease_data(&r, D, H).is_none(), "no overflow");
    }
    #[test] fn nonce_and_ids_have_a_strict_shape() {
        for n in ["short", "0123456789ABCDEF0123456789ABCDEF", "0123456789abcdef0123456789abcdeg", "0123456789abcdef0123456789abcdef00"] { let mut r = good(); r["nonce"] = json!(n); assert!(lease_data(&r, D, H).is_none(), "{n}"); }
        let mut r = good(); r["device_id"] = json!("not-a-uuid"); assert!(lease_data(&r, "not-a-uuid", H).is_none());
    }
    #[test] fn refusals_map_to_honest_statuses() {
        for (w, s) in [("revoked", 403), ("not_approved", 403), ("not_your_device", 403), ("unknown_device", 403), ("too_fast", 429), ("too_many", 429), ("clock_back", 409), ("proof_replayed", 409), ("key_mismatch", 403), ("proof_stale", 403), ("key_required", 403), ("surprise", 502)] { assert_eq!(refusal_status(w), s, "{w}"); }
        assert!(refusal_text("revoked").contains("revoked") && !refusal_text("zzz").is_empty());
    }

    #[test] fn the_half_and_thumb_must_be_43_url_safe_chars() {
        assert!(lease_data(&good(), D, "short").is_none() && lease_data(&good(), D, &"B".repeat(44)).is_none() && lease_data(&good(), D, &format!("{}+", "B".repeat(42))).is_none());
        let mut r = good(); r["key_thumb"] = json!("x"); assert!(lease_data(&r, D, H).is_none());
    }
    #[test] fn hkdf_half_is_stable_device_bound_and_salt_bound() {
        let m = [7u8; 32]; let salt = "ab".repeat(32);
        let a = half(&m, D, &salt).unwrap();
        assert_eq!(a.len(), 43); assert_eq!(a, half(&m, D, &salt).unwrap(), "same inputs, same half (the vault must reopen)");
        assert_ne!(a, half(&m, "ffffffff-d9cb-469f-a165-70867728950e", &salt).unwrap(), "device bound");
        assert_ne!(a, half(&m, D, &"cd".repeat(32)).unwrap(), "salt bound: a destroyed salt means no half");
        assert_ne!(a, half(&[8u8; 32], D, &salt).unwrap(), "master bound");
        assert!(half(&m, D, "zz").is_none() && half(&m, "nope", &salt).is_none() && half(&m, D, &"AB".repeat(32)).is_none());
        assert_eq!(half(&m, D, &salt), half(&m, &D.to_ascii_uppercase(), &salt), "case of the device id does not matter");
    }
    // A real WebCrypto-shaped proof: ECDSA P-256 over the proof text, raw r||s, JWK with x/y.
    fn key() -> (ring::signature::EcdsaKeyPair, Value) {
        let rng = ring::rand::SystemRandom::new();
        let pk8 = ring::signature::EcdsaKeyPair::generate_pkcs8(&ring::signature::ECDSA_P256_SHA256_FIXED_SIGNING, &rng).unwrap();
        let kp = ring::signature::EcdsaKeyPair::from_pkcs8(&ring::signature::ECDSA_P256_SHA256_FIXED_SIGNING, pk8.as_ref(), &rng).unwrap();
        let p = ring::signature::KeyPair::public_key(&kp).as_ref().to_vec();
        let jwk = json!({"kty": "EC", "crv": "P-256", "x": B64U.encode(&p[1..33]), "y": B64U.encode(&p[33..65])});
        (kp, jwk)
    }
    fn proof(kp: &ring::signature::EcdsaKeyPair, dev: &str, ts: i64) -> String { B64U.encode(kp.sign(&ring::rand::SystemRandom::new(), format!("anexo-lease-proof@1|{dev}|{ts}").as_bytes()).unwrap().as_ref()) }
    #[test] fn a_valid_device_proof_returns_the_thumbprint() {
        let (kp, jwk) = key();
        let t = verify_proof(D, 1_700_000_000_000, &jwk, &proof(&kp, D, 1_700_000_000_000)).unwrap();
        assert_eq!(t.len(), 43); assert_eq!(t, thumbprint(jwk["x"].as_str().unwrap(), jwk["y"].as_str().unwrap()));
    }
    #[test] fn a_proof_is_bound_to_device_time_and_key() {
        let (kp, jwk) = key(); let s = proof(&kp, D, 5);
        assert!(verify_proof(D, 6, &jwk, &s).is_none(), "other time");
        assert!(verify_proof("ffffffff-d9cb-469f-a165-70867728950e", 5, &jwk, &s).is_none(), "other device");
        let (_, other) = key(); assert!(verify_proof(D, 5, &other, &s).is_none(), "other key");
        assert!(verify_proof(D, 5, &jwk, &s[..s.len() - 2]).is_none() && verify_proof(D, 5, &jwk, "").is_none(), "short / empty signature");
        let mut bad = jwk.clone(); bad["crv"] = json!("P-384"); assert!(verify_proof(D, 5, &bad, &s).is_none());
        let mut bad = jwk.clone(); bad["x"] = json!(format!("{}=", jwk["x"].as_str().unwrap())); assert!(verify_proof(D, 5, &bad, &s).is_none(), "non-canonical base64 is refused");
    }
    #[test] fn thumbprint_is_rfc7638_shaped() {
        // RFC 7638 section 3.1 example is for RSA; here we pin the exact canonical JSON text so it can never drift.
        assert_eq!(thumbprint("a", "b"), B64U.encode(digest::digest(&digest::SHA256, br#"{"crv":"P-256","kty":"EC","x":"a","y":"b"}"#).as_ref()));
    }
}
