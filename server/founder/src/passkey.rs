//! J3 — founder passkeys (WebAuthn Level 3), Rust half. The database (E139 + E117 + E118) is the brain and keeps every rule; this file
//! only does what SQL cannot: parse CBOR / authData, verify the signature with `ring`, and talk to the SQL doors.
//!
//! One implementation of the WebAuthn byte-level rules: the shared, already-tested `passkey_core.rs` (CBOR, COSE EC/RSA, authData, clientData).
//! Added here, founder-side only (the shared file is read-only, Rule 73):
//!   * Ed25519 (COSE kty 1 / crv 6 / alg -8) — verified with `ring::signature::ED25519`
//!   * Level 3 flags: BE (0x08) and BS (0x10) read from the authenticator flags, `BS=1` without `BE=1` refused
//!   * AAGUID read from the attested credential data, shown as a UUID
//!   * the COSE algorithm id is read and must agree with the key type (no alg confusion)
//! Honest limit: the attestation STATEMENT (attStmt) is not verified, so attestation_trust is always 'none'; the AAGUID is the model the
//! authenticator CLAIMS. "Hardware" only ever comes from the founder's own AAGUID allow-list (E118), and E139 checks the claimed model against the
//! FIDO Metadata Service ledger (status, compromise) before and after every sign-in.
use crate::passkey_core as pc;
use ring::signature::{self, UnparsedPublicKey};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

/// Everything the registration proves, in the shape `founder_webauthn_register` takes (plus the key itself).
#[derive(Debug, PartialEq)]
pub struct Reg {
    pub credential_id: String,
    pub key: Value,
    pub facts: Value,
    pub sign_count: u32,
}

/// Everything an assertion proves, in the shape `founder_webauthn_assert` takes.
#[derive(Debug, PartialEq)]
pub struct Asr {
    pub credential_id: String,
    pub facts: Value,
}

pub fn sha256(b: &[u8]) -> [u8; 32] {
    let mut o = [0u8; 32];
    o.copy_from_slice(&Sha256::digest(b));
    o
}

pub fn random_challenge() -> Result<String, &'static str> {
    use ring::rand::{SecureRandom, SystemRandom};
    let mut b = [0u8; 32];
    SystemRandom::new().fill(&mut b).map_err(|_| "rng_failed")?;
    Ok(pc::b64url_encode(&b))
}

/// 16 bytes -> 8-4-4-4-12 lower-case hex (the form the SQL CHECKs accept).
pub fn aaguid_text(b: &[u8]) -> String {
    let h: String = b.iter().map(|x| format!("{x:02x}")).collect();
    format!("{}-{}-{}-{}-{}", &h[0..8], &h[8..12], &h[12..16], &h[16..20], &h[20..32])
}

pub fn is_uuid(s: &str) -> bool {
    s.len() == 36 && s.bytes().enumerate().all(|(i, c)| if matches!(i, 8 | 13 | 18 | 23) { c == b'-' } else { c.is_ascii_hexdigit() })
}

fn int_of(v: &pc::Cbor) -> Option<i64> {
    match v { pc::Cbor::Uint(u) => i64::try_from(*u).ok(), pc::Cbor::Nint(n) => Some(*n), _ => None }
}

/// COSE key -> (stored JWK, cose alg, public key byte length). EC and RSA go through the shared core; Ed25519 is handled here.
pub fn cose_key(cose: &pc::Cbor) -> Result<(Value, i64, usize), &'static str> {
    let kty = cose.get_int(1).and_then(int_of).ok_or("cose_kty")?;
    let alg = cose.get_int(3).and_then(int_of);
    match kty {
        1 => {
            if cose.get_int(-1).and_then(int_of) != Some(6) { return Err("cose_curve_unsupported"); }
            if alg.is_some() && alg != Some(-8) { return Err("cose_alg_mismatch"); }
            let x = cose.get_int(-2).and_then(|v| v.bytes()).ok_or("cose_bytes")?;
            if x.len() != 32 { return Err("cose_okp_len"); }
            Ok((json!({"kty": "OKP", "crv": "Ed25519", "x": pc::b64url_encode(x)}), -8, 32))
        }
        2 => {
            if alg.is_some() && alg != Some(-7) { return Err("cose_alg_mismatch"); }
            let k = pc::cose_to_pubkey(cose)?;
            let pc::PubKey::Ec { x, y } = &k else { return Err("cose_kty_unsupported") };
            Ok((json!({"kty": "EC", "crv": "P-256", "x": pc::b64url_encode(x), "y": pc::b64url_encode(y)}), -7, x.len() + y.len()))
        }
        3 => {
            if alg.is_some() && alg != Some(-257) { return Err("cose_alg_mismatch"); }
            let k = pc::cose_to_pubkey(cose)?;
            let pc::PubKey::Rsa { n, e } = &k else { return Err("cose_kty_unsupported") };
            Ok((json!({"kty": "RSA", "n": pc::b64url_encode(n), "e": pc::b64url_encode(e), "alg": "RS256"}), -257, n.len() + e.len()))
        }
        _ => Err("cose_kty_unsupported"),
    }
}

fn st(v: &Value, k: &str) -> String { v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string() }

/// clientDataJSON -> (raw bytes, type, challenge, origin). Cross-origin iframes (`crossOrigin: true`) and top-origin tricks are refused.
fn client_data(b64: &str) -> Result<(Vec<u8>, String, String, String), &'static str> {
    let raw = pc::b64url_decode(b64).map_err(|_| "clientData_invalid")?;
    if raw.len() > 4096 { return Err("clientData_invalid"); }
    let v: Value = serde_json::from_slice(&raw).map_err(|_| "clientData_invalid")?;
    if v.get("crossOrigin").and_then(|x| x.as_bool()) == Some(true) { return Err("clientData_cross_origin"); }
    Ok((raw, st(&v, "type"), st(&v, "challenge"), st(&v, "origin")))
}

/// Level 3 flags of the authenticator data: (BE, BS, UV). BS without BE is impossible per the spec and refused here too.
pub fn flags(f: u8) -> Result<(bool, bool, bool), &'static str> {
    let (be, bs, uv) = (f & 0x08 != 0, f & 0x10 != 0, f & 0x04 != 0);
    if bs && !be { return Err("backup_state_without_eligibility"); }
    Ok((be, bs, uv))
}

/// Verify a `navigator.credentials.create()` answer. `want_challenge` / `want_origin` / `rp_id` come from the server-side ceremony row.
pub fn verify_registration(cred: &Value, want_challenge: &str, want_origin: &str, rp_id: &str) -> Result<Reg, &'static str> {
    let r = cred.get("response").unwrap_or(cred);
    let (_raw, typ, ch, origin) = client_data(&st(r, "clientDataJSON"))?;
    pc::check_client_data(&typ, &ch, &origin, "webauthn.create", want_challenge, want_origin)?;
    let att = pc::b64url_decode(&st(r, "attestationObject")).map_err(|_| "authData_missing")?;
    let (map, _) = pc::cbor_parse(&att)?;
    let fmt = match map.get_text("fmt") { Some(pc::Cbor::Text(t)) => t.clone(), _ => "none".to_string() };
    let fmt = if ["none", "packed", "tpm", "android-key", "android-safetynet", "fido-u2f", "apple", "compound"].contains(&fmt.as_str()) { fmt } else { return Err("attestation_fmt_unknown") };
    let auth = pc::auth_data_from_attestation(&att)?;
    let ad = pc::parse_auth_data(&auth, &sha256(rp_id.as_bytes()), true)?;
    let (be, bs, uv) = flags(ad.flags)?;
    let (Some(cid), Some(cose)) = (ad.credential_id.as_ref(), ad.cose.as_ref()) else { return Err("attested_credential_missing") };
    let (key, alg, pk_bytes) = cose_key(cose)?;
    let credential_id = pc::b64url_encode(cid);
    // the id the browser reports must be the id inside the authenticator data (no swapping)
    let reported = cred.get("id").or_else(|| cred.get("rawId")).and_then(|x| x.as_str()).unwrap_or("");
    if reported != credential_id { return Err("credential_id_mismatch"); }
    let transports: Vec<String> = r.get("transports").and_then(|t| t.as_array()).map(|a| a.iter().filter_map(|x| x.as_str())
        .filter(|t| ["usb", "nfc", "ble", "internal", "hybrid", "smart-card"].contains(t)).map(String::from).collect()).unwrap_or_default();
    let attachment = match cred.get("authenticatorAttachment").and_then(|x| x.as_str()) { Some("platform") => "platform", Some("cross-platform") => "cross-platform", _ => "unknown" };
    let facts = json!({
        "origin": origin, "rp_id": rp_id, "aaguid": aaguid_text(&auth[37..53]), "cose_alg": alg, "pk_bytes": pk_bytes,
        "attestation_fmt": fmt, "attestation_trust": "none", "transports": transports, "attachment": attachment,
        "discoverable": cred.get("clientExtensionResults").and_then(|e| e.get("credProps")).and_then(|c| c.get("rk")).and_then(|x| x.as_bool()).unwrap_or(true),
        "be": be, "bs": bs, "uv_initialized": uv,
        "prf_enabled": cred.get("clientExtensionResults").and_then(|e| e.get("prf")).and_then(|p| p.get("enabled")).and_then(|x| x.as_bool()).unwrap_or(false),
        "large_blob": cred.get("clientExtensionResults").and_then(|e| e.get("largeBlob")).and_then(|p| p.get("supported")).and_then(|x| x.as_bool()).unwrap_or(false),
    });
    Ok(Reg { credential_id, key, facts, sign_count: ad.sign_count })
}

/// ring verification of one signature with the stored JWK (EC P-256, RSA PKCS1 SHA-256, Ed25519).
pub fn verify_signature(jwk: &Value, signed: &[u8], sig: &[u8]) -> Result<(), &'static str> {
    match st(jwk, "kty").as_str() {
        "EC" => {
            let (x, y) = (pc::b64url_decode(&st(jwk, "x")).map_err(|_| "assertion_key")?, pc::b64url_decode(&st(jwk, "y")).map_err(|_| "assertion_key")?);
            if x.len() != 32 || y.len() != 32 { return Err("assertion_key"); }
            UnparsedPublicKey::new(&signature::ECDSA_P256_SHA256_ASN1, &pc::ec_point(&x, &y)).verify(signed, sig).map_err(|_| "assertion_signature")
        }
        "RSA" => {
            let (n, e) = (pc::b64url_decode(&st(jwk, "n")).map_err(|_| "assertion_key")?, pc::b64url_decode(&st(jwk, "e")).map_err(|_| "assertion_key")?);
            UnparsedPublicKey::new(&signature::RSA_PKCS1_2048_8192_SHA256, &pc::rsa_public_der(&n, &e)).verify(signed, sig).map_err(|_| "assertion_signature")
        }
        "OKP" => {
            if st(jwk, "crv") != "Ed25519" { return Err("assertion_key"); }
            let x = pc::b64url_decode(&st(jwk, "x")).map_err(|_| "assertion_key")?;
            if x.len() != 32 { return Err("assertion_key"); }
            UnparsedPublicKey::new(&signature::ED25519, &x).verify(signed, sig).map_err(|_| "assertion_signature")
        }
        _ => Err("assertion_key"),
    }
}

/// Verify a `navigator.credentials.get()` answer against the stored key. The sign counter and every flag go to SQL, which decides.
pub fn verify_assertion(cred: &Value, jwk: &Value, want_challenge: &str, want_origin: &str, rp_id: &str) -> Result<Asr, &'static str> {
    let r = cred.get("response").unwrap_or(cred);
    let (raw, typ, ch, origin) = client_data(&st(r, "clientDataJSON"))?;
    pc::check_client_data(&typ, &ch, &origin, "webauthn.get", want_challenge, want_origin)?;
    let auth = pc::b64url_decode(&st(r, "authenticatorData")).map_err(|_| "authData_short")?;
    let ad = pc::parse_auth_data(&auth, &sha256(rp_id.as_bytes()), false)?;
    let (be, bs, uv) = flags(ad.flags)?;
    let sig = pc::b64url_decode(&st(r, "signature")).map_err(|_| "assertion_signature")?;
    verify_signature(jwk, &pc::signed_data(&auth, &sha256(&raw)), &sig)?;
    let credential_id = cred.get("id").or_else(|| cred.get("rawId")).and_then(|x| x.as_str()).unwrap_or("").to_string();
    if !pc::is_b64url_token(&credential_id, 1400) { return Err("credential_id_invalid"); }
    Ok(Asr { credential_id, facts: json!({"sign_count": ad.sign_count, "up": ad.flags & 1 != 0, "uv": uv, "be": be, "bs": bs, "origin": origin, "rp_id": rp_id}) })
}

/// The WebAuthn challenge of a protected action: the 32 raw bytes of `founder_action_hash` (SQL computes it, one implementation).
pub fn challenge_of_action_hash(hex_hash: &str) -> Result<String, &'static str> {
    if hex_hash.len() != 64 || !hex_hash.bytes().all(|c| c.is_ascii_hexdigit()) { return Err("action_hash_invalid"); }
    let mut b = [0u8; 32];
    for i in 0..32 { b[i] = u8::from_str_radix(&hex_hash[i * 2..i * 2 + 2], 16).map_err(|_| "action_hash_invalid")?; }
    Ok(pc::b64url_encode(&b))
}

/// Options for `navigator.credentials.create()`. `policy` is the E139 policy row; nothing is invented here.
pub fn create_options(policy: &Value, challenge: &str, uid: &str, email: &str, exclude: &[String], timeout_ms: u64) -> Value {
    let algs: Vec<Value> = policy["allowed_algs"].as_array().cloned().unwrap_or_default().into_iter().map(|a| json!({"type": "public-key", "alg": a})).collect();
    json!({"rp": {"id": policy["rp_id"], "name": "Anexomail Founder"},
        "user": {"id": pc::b64url_encode(uid.as_bytes()), "name": email, "displayName": "Founder"},
        "challenge": challenge, "pubKeyCredParams": algs, "timeout": timeout_ms,
        "excludeCredentials": exclude.iter().map(|c| json!({"type": "public-key", "id": c})).collect::<Vec<_>>(),
        "authenticatorSelection": {"residentKey": "required", "requireResidentKey": true, "userVerification": "required"},
        "attestation": policy["attestation_pref"], "extensions": {"credProps": true, "prf": {}, "largeBlob": {"support": "preferred"}},
        "hints": ["security-key", "client-device", "hybrid"]})
}

/// Options for `navigator.credentials.get()`.
pub fn get_options(policy: &Value, challenge: &str, allow: &[String], timeout_ms: u64) -> Value {
    json!({"rpId": policy["rp_id"], "challenge": challenge, "timeout": timeout_ms, "userVerification": "required",
        "allowCredentials": allow.iter().map(|c| json!({"type": "public-key", "id": c})).collect::<Vec<_>>()})
}

/// The labels a ceremony may carry (kept in the ceremony state, never trusted from the verify call).
pub fn clean_label(raw: &str) -> Option<String> {
    let t = raw.trim();
    let n = t.chars().count();
    ((1..=40).contains(&n) && !t.chars().any(|c| c.is_control() || c == '<' || c == '>')).then(|| t.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use ring::rand::SystemRandom;
    use ring::signature::{EcdsaKeyPair, Ed25519KeyPair, KeyPair, ECDSA_P256_SHA256_ASN1_SIGNING};

    fn cbor_uint(out: &mut Vec<u8>, major: u8, n: u64) {
        if n < 24 { out.push(major << 5 | n as u8); } else if n < 256 { out.extend([major << 5 | 24, n as u8]); } else { out.extend([major << 5 | 25, (n >> 8) as u8, n as u8]); }
    }
    fn cint(out: &mut Vec<u8>, i: i64) { if i >= 0 { cbor_uint(out, 0, i as u64) } else { cbor_uint(out, 1, (-1 - i) as u64) } }
    fn cbytes(out: &mut Vec<u8>, b: &[u8]) { cbor_uint(out, 2, b.len() as u64); out.extend(b); }
    fn ctext(out: &mut Vec<u8>, t: &str) { cbor_uint(out, 3, t.len() as u64); out.extend(t.as_bytes()); }
    fn cose_ed(x: &[u8], alg: Option<i64>) -> Vec<u8> {
        let mut o = vec![0xa0 + 3 + alg.is_some() as u8]; cint(&mut o, 1); cint(&mut o, 1); if let Some(a) = alg { cint(&mut o, 3); cint(&mut o, a); }
        cint(&mut o, -1); cint(&mut o, 6); cint(&mut o, -2); cbytes(&mut o, x); o
    }
    fn cose_ec(x: &[u8], y: &[u8]) -> Vec<u8> {
        let mut o = vec![0xa5]; cint(&mut o, 1); cint(&mut o, 2); cint(&mut o, 3); cint(&mut o, -7); cint(&mut o, -1); cint(&mut o, 1);
        cint(&mut o, -2); cbytes(&mut o, x); cint(&mut o, -3); cbytes(&mut o, y); o
    }
    const RP: &str = "founderworkspace.anexomail.com";
    const ORIGIN: &str = "https://founderworkspace.anexomail.com";
    fn auth_data(flags: u8, count: u32, cred: Option<(&[u8; 16], &[u8], Vec<u8>)>) -> Vec<u8> {
        let mut a = sha256(RP.as_bytes()).to_vec(); a.push(flags); a.extend(count.to_be_bytes());
        if let Some((aag, id, cose)) = cred { a.extend(aag); a.extend((id.len() as u16).to_be_bytes()); a.extend(id); a.extend(cose); }
        a
    }
    fn attestation(auth: &[u8], fmt: &str) -> Vec<u8> {
        let mut o = vec![0xa3]; ctext(&mut o, "fmt"); ctext(&mut o, fmt); ctext(&mut o, "attStmt"); o.push(0xa0); ctext(&mut o, "authData"); cbytes(&mut o, auth); o
    }
    fn cd(typ: &str, ch: &str, origin: &str) -> String { pc::b64url_encode(format!(r#"{{"type":"{typ}","challenge":"{ch}","origin":"{origin}"}}"#).as_bytes()) }
    fn reg_cred(flags: u8, cose: Vec<u8>, id: &[u8], fmt: &str, ch: &str) -> Value {
        let aag = [0x2f, 0xc0, 0x57, 0x9f, 0x81, 0x13, 0x47, 0xea, 0xb1, 0x16, 0xbb, 0x5a, 0x8d, 0xb9, 0x20, 0x2a];
        let auth = auth_data(flags, 0, Some((&aag, id, cose)));
        json!({"id": pc::b64url_encode(id), "authenticatorAttachment": "cross-platform", "clientExtensionResults": {"credProps": {"rk": true}, "prf": {"enabled": true}},
               "response": {"clientDataJSON": cd("webauthn.create", ch, ORIGIN), "attestationObject": pc::b64url_encode(&attestation(&auth, fmt)), "transports": ["usb", "nfc", "bogus"]}})
    }

    #[test]
    fn registers_ed25519_with_level3_facts() {
        let kp = Ed25519KeyPair::from_seed_unchecked(&[7u8; 32]).unwrap();
        let r = verify_registration(&reg_cred(0x45 | 0x40 & 0, cose_ed(kp.public_key().as_ref(), Some(-8)), b"cred-one-0123456789", "packed", "abc"), "abc", ORIGIN, RP);
        // flags 0x45 = UP|UV|AT, no BE/BS: a device-bound key
        let r = r.unwrap_or_else(|e| panic!("{e}"));
        assert_eq!(r.facts["cose_alg"], -8);
        assert_eq!(r.facts["be"], false);
        assert_eq!(r.facts["aaguid"], "2fc0579f-8113-47ea-b116-bb5a8db9202a");
        assert_eq!(r.facts["attestation_trust"], "none");
        assert_eq!(r.facts["transports"], json!(["usb", "nfc"]));
        assert_eq!(r.facts["prf_enabled"], true);
        assert_eq!(r.key["kty"], "OKP");
    }
    #[test]
    fn registration_refusals() {
        let kp = Ed25519KeyPair::from_seed_unchecked(&[7u8; 32]).unwrap();
        let ok = |flags: u8, cose: Vec<u8>, ch: &str| verify_registration(&reg_cred(flags, cose, b"cred-one-0123456789", "none", ch), "abc", ORIGIN, RP);
        let ed = cose_ed(kp.public_key().as_ref(), Some(-8));
        assert!(ok(0x45, ed.clone(), "abc").is_ok());
        assert_eq!(ok(0x45, ed.clone(), "other").unwrap_err(), "clientData_challenge");
        assert_eq!(ok(0x41, ed.clone(), "abc").unwrap_err(), "user_not_verified");
        assert_eq!(ok(0x55, ed.clone(), "abc").unwrap_err(), "backup_state_without_eligibility");
        assert!(ok(0x5d, ed.clone(), "abc").is_ok()); // UP|UV|BE|BS|AT: a synced passkey
        assert_eq!(ok(0x45, cose_ed(kp.public_key().as_ref(), Some(-7)), "abc").unwrap_err(), "cose_alg_mismatch");
        assert_eq!(ok(0x45, cose_ed(&[1u8; 31], None), "abc").unwrap_err(), "cose_okp_len");
        assert_eq!(verify_registration(&reg_cred(0x45, ed.clone(), b"cred-one-0123456789", "none", "abc"), "abc", "https://evil.example.com", RP).unwrap_err(), "clientData_origin");
        assert_eq!(verify_registration(&reg_cred(0x45, ed.clone(), b"cred-one-0123456789", "none", "abc"), "abc", ORIGIN, "anexomail.com").unwrap_err(), "rpId_mismatch");
        assert_eq!(verify_registration(&reg_cred(0x45, ed.clone(), b"cred-one-0123456789", "made-up", "abc"), "abc", ORIGIN, RP).unwrap_err(), "attestation_fmt_unknown");
        let mut swapped = reg_cred(0x45, ed, b"cred-one-0123456789", "none", "abc");
        swapped["id"] = json!("AAAA");
        assert_eq!(verify_registration(&swapped, "abc", ORIGIN, RP).unwrap_err(), "credential_id_mismatch");
    }
    #[test]
    fn cross_origin_frames_are_refused() {
        let b = pc::b64url_encode(br#"{"type":"webauthn.get","challenge":"c","origin":"https://x.y","crossOrigin":true}"#);
        assert_eq!(client_data(&b).unwrap_err(), "clientData_cross_origin");
    }
    fn assertion(sign: impl Fn(&[u8]) -> Vec<u8>, flags: u8, count: u32, ch: &str, origin: &str, id: &str) -> Value {
        let auth = auth_data(flags, count, None);
        let cdj = format!(r#"{{"type":"webauthn.get","challenge":"{ch}","origin":"{origin}"}}"#);
        let sig = sign(&pc::signed_data(&auth, &sha256(cdj.as_bytes())));
        json!({"id": id, "response": {"clientDataJSON": pc::b64url_encode(cdj.as_bytes()), "authenticatorData": pc::b64url_encode(&auth), "signature": pc::b64url_encode(&sig)}})
    }
    #[test]
    fn ed25519_assertion_verifies_and_tamper_fails() {
        let kp = Ed25519KeyPair::from_seed_unchecked(&[9u8; 32]).unwrap();
        let jwk = json!({"kty": "OKP", "crv": "Ed25519", "x": pc::b64url_encode(kp.public_key().as_ref())});
        let sign = |m: &[u8]| kp.sign(m).as_ref().to_vec();
        let a = verify_assertion(&assertion(sign, 0x1d, 12, "chal", ORIGIN, "AbC_-123"), &jwk, "chal", ORIGIN, RP).unwrap();
        assert_eq!(a.facts["sign_count"], 12);
        assert_eq!(a.facts["be"], true);
        assert_eq!(a.facts["bs"], true);
        assert_eq!(a.facts["uv"], true);
        let wrong_key = json!({"kty": "OKP", "crv": "Ed25519", "x": pc::b64url_encode(Ed25519KeyPair::from_seed_unchecked(&[1u8; 32]).unwrap().public_key().as_ref())});
        assert_eq!(verify_assertion(&assertion(sign, 0x05, 1, "chal", ORIGIN, "AbC"), &wrong_key, "chal", ORIGIN, RP).unwrap_err(), "assertion_signature");
        assert_eq!(verify_assertion(&assertion(sign, 0x05, 1, "chal", ORIGIN, "AbC"), &jwk, "other", ORIGIN, RP).unwrap_err(), "clientData_challenge");
        assert_eq!(verify_assertion(&assertion(sign, 0x01, 1, "chal", ORIGIN, "AbC"), &jwk, "chal", ORIGIN, RP).unwrap_err(), "user_not_verified");
        assert_eq!(verify_assertion(&assertion(sign, 0x15, 1, "chal", ORIGIN, "AbC"), &jwk, "chal", ORIGIN, RP).unwrap_err(), "backup_state_without_eligibility");
        let mut t = assertion(sign, 0x05, 1, "chal", ORIGIN, "AbC");
        let mut s = pc::b64url_decode(t["response"]["signature"].as_str().unwrap()).unwrap(); s[0] ^= 1;
        t["response"]["signature"] = json!(pc::b64url_encode(&s));
        assert_eq!(verify_assertion(&t, &jwk, "chal", ORIGIN, RP).unwrap_err(), "assertion_signature");
    }
    #[test]
    fn es256_assertion_and_registration_key_roundtrip() {
        let rng = SystemRandom::new();
        let pkcs8 = EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_ASN1_SIGNING, &rng).unwrap();
        let kp = EcdsaKeyPair::from_pkcs8(&ECDSA_P256_SHA256_ASN1_SIGNING, pkcs8.as_ref(), &rng).unwrap();
        let pt = kp.public_key().as_ref();
        let r = verify_registration(&reg_cred(0x45, cose_ec(&pt[1..33], &pt[33..65]), b"cred-two-0123456789", "none", "abc"), "abc", ORIGIN, RP).unwrap();
        assert_eq!(r.facts["cose_alg"], -7);
        assert_eq!(r.facts["pk_bytes"], 64);
        let sign = |m: &[u8]| kp.sign(&rng, m).unwrap().as_ref().to_vec();
        verify_assertion(&assertion(sign, 0x05, 3, "c", ORIGIN, "AbC"), &r.key, "c", ORIGIN, RP).unwrap();
        // an Ed25519 key can never be used as an EC key (no algorithm confusion)
        assert_eq!(verify_signature(&json!({"kty": "OKP", "crv": "P-256", "x": "AAAA"}), b"m", b"s").unwrap_err(), "assertion_key");
        assert_eq!(verify_signature(&json!({"kty": "none"}), b"m", b"s").unwrap_err(), "assertion_key");
    }
    #[test]
    fn helpers() {
        assert_eq!(aaguid_text(&[0u8; 16]), "00000000-0000-0000-0000-000000000000");
        assert!(is_uuid("2fc0579f-8113-47ea-b116-bb5a8db9202a") && !is_uuid("2fc0579f811347eab116bb5a8db9202a") && !is_uuid("zzzzzzzz-8113-47ea-b116-bb5a8db9202a"));
        assert_eq!(flags(0x08 | 0x10).unwrap(), (true, true, false));
        assert!(flags(0x10).is_err());
        assert_eq!(challenge_of_action_hash(&"00".repeat(32)).unwrap(), pc::b64url_encode(&[0u8; 32]));
        assert!(challenge_of_action_hash("xyz").is_err());
        assert!(challenge_of_action_hash(&"gg".repeat(32)).is_err());
        assert_eq!(clean_label("  Yubikey 5C  ").as_deref(), Some("Yubikey 5C"));
        assert!(clean_label("").is_none() && clean_label("<b>").is_none() && clean_label(&"x".repeat(41)).is_none());
        let c1 = random_challenge().unwrap(); let c2 = random_challenge().unwrap();
        assert_ne!(c1, c2);
        assert!(pc::is_b64url_token(&c1, 64));
        let pol = json!({"rp_id": RP, "allowed_algs": [-7, -8], "attestation_pref": "direct"});
        let o = create_options(&pol, "c", "u1", "a@b.com", &["id1".to_string()], 60000);
        assert_eq!(o["pubKeyCredParams"].as_array().unwrap().len(), 2);
        assert_eq!(o["authenticatorSelection"]["userVerification"], "required");
        assert_eq!(o["excludeCredentials"][0]["id"], "id1");
        assert_eq!(get_options(&pol, "c", &[], 1)["userVerification"], "required");
    }
}

// ═══════════════════════════════ ROUTES (I/O) ═══════════════════════════════════════════════════════════════════════════════════════════════
// Everything below only moves JSON between the browser and the SQL doors. Every rule (origin, risk, clone, tier, grant) stays in SQL.
use crate::{S, St};
use axum::{Json, extract::State, http::{HeaderMap, StatusCode}, response::{IntoResponse, Response}};

fn refuse(code: StatusCode, msg: &str) -> Response { (code, Json(json!({"error": msg}))).into_response() }
/// SQL refusal (PostgREST status + the database's own words) -> the same class of HTTP status, never a 500 for a rule that said no.
fn sql_err((status, msg): (u16, String)) -> Response {
    let code = match status { 400 => StatusCode::BAD_REQUEST, 401 => StatusCode::UNAUTHORIZED, 403 => StatusCode::FORBIDDEN, 404 | 409 => StatusCode::CONFLICT, 0 => StatusCode::SERVICE_UNAVAILABLE, _ => StatusCode::BAD_GATEWAY };
    refuse(code, if msg.is_empty() { "the database refused" } else { &msg })
}

/// (uid, email, device id) of a founder token; signed-write rules (x-fo-sig) apply to POSTs. Legacy session tokens have no device and cannot do passkey work.
pub(crate) async fn ctx(st: &St, h: &HeaderMap, path: &str, body: &[u8], write: bool) -> Result<(String, String, String), Response> {
    let c = if write { crate::authed_w(st, h).await } else { crate::authed(st, h).await }.map_err(|c| c.into_response())?;
    if write { crate::write_ok(st, h, "POST", path, body)?; }
    let tok = crate::gate::bearer(h.get("authorization").and_then(|v| v.to_str().ok())).unwrap_or("");
    let did = st.ft.as_ref().and_then(|k| k.verify(tok, crate::now_s()).ok()).map(|c| c.did).filter(|d| is_uuid(d));
    match did { Some(d) => Ok((c.sub, c.email, d)), None => Err(refuse(StatusCode::UNAUTHORIZED, "a founder device token is needed for passkey work")) }
}
/// The device id inside a founder token (None for legacy session tokens).
pub(crate) fn did_of(st: &St, h: &HeaderMap) -> Option<String> {
    let tok = crate::gate::bearer(h.get("authorization").and_then(|v| v.to_str().ok()))?;
    st.ft.as_ref()?.verify(tok, crate::now_s()).ok().map(|c| c.did).filter(|d| is_uuid(d))
}

/// What the tier of an action means for ONE attempt (pure, tested). Unlisted actions keep the old behaviour (attempt recorded, executor closed).
#[derive(Debug, PartialEq)]
pub enum TierGate { Open, NeedGrant, T3Only }
pub fn tier_gate(tier: Option<i64>) -> TierGate { match tier { Some(2) => TierGate::NeedGrant, Some(t) if t >= 3 => TierGate::T3Only, _ => TierGate::Open } }

fn sbx(st: &St) -> Result<&crate::data::Sb, Response> { st.sb.as_ref().ok_or_else(|| refuse(StatusCode::SERVICE_UNAVAILABLE, "database not configured")) }
fn body_json(body: &[u8]) -> Result<Value, Response> { serde_json::from_slice(body).map_err(|_| refuse(StatusCode::BAD_REQUEST, "invalid body")) }
fn txt(v: &Value, k: &str, max: usize) -> Option<String> { v.get(k).and_then(|x| x.as_str()).filter(|s| s.chars().count() <= max).map(String::from) }

async fn policy(sb: &crate::data::Sb) -> Result<Value, Response> {
    sb.rows("founder_webauthn_policy?select=rp_id,origins,challenge_secs,allowed_algs,attestation_pref&limit=1").await.and_then(|r| r.into_iter().next())
        .ok_or_else(|| refuse(StatusCode::BAD_GATEWAY, "WebAuthn policy missing - run the E139 SQL step (sql-run.sh)"))
}
/// The browser's Origin must be one the policy lists (SQL decides); the exact string is then bound into the ceremony.
async fn origin_of(sb: &crate::data::Sb, h: &HeaderMap) -> Result<String, Response> {
    let o = h.get("origin").and_then(|v| v.to_str().ok()).unwrap_or("").to_string();
    if o.is_empty() || o.len() > 200 { return Err(refuse(StatusCode::BAD_REQUEST, "no origin")); }
    match sb.rpc("founder_webauthn_origin_ok", json!({"p_origin": o})).await { Some(Value::Bool(true)) => Ok(o), _ => Err(refuse(StatusCode::FORBIDDEN, "this origin is not allowed for founder passkeys")) }
}
async fn active(sb: &crate::data::Sb, uid: &str) -> Vec<Value> { sb.rpc("founder_passkey_active", json!({"p_uid": uid})).await.and_then(|v| v.as_array().cloned()).unwrap_or_default() }

/// Purposes a ceremony can have, and the action fields each one needs.
const PURPOSES: [&str; 6] = ["register", "signin", "action", "t3_begin", "t3_approve", "t3_execute"];

/// POST /founder/v1/passkey/options  {purpose, label?, action?, target?, params?, nonce?, request?}
pub async fn options_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, email, did) = match ctx(&st, &h, "/founder/v1/passkey/options", &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    let b = match body_json(&body) { Ok(b) => b, Err(r) => return r };
    let purpose = txt(&b, "purpose", 16).unwrap_or_default();
    if !PURPOSES.contains(&purpose.as_str()) { return refuse(StatusCode::BAD_REQUEST, "unknown purpose"); }
    let (pol, origin) = match tokio::join!(policy(sb), origin_of(sb, &h)) { (Ok(p), Ok(o)) => (p, o), (Err(r), _) | (_, Err(r)) => return r };
    let act = active(sb, &uid).await;
    let ids: Vec<String> = act.iter().filter_map(|a| a["credential_id"].as_str().map(String::from)).collect();
    if purpose != "register" && ids.is_empty() { return refuse(StatusCode::CONFLICT, "no active passkey: register one first"); }
    let secs = pol["challenge_secs"].as_u64().unwrap_or(120).clamp(30, 300);
    let mut state = json!({"purpose": purpose, "origin": origin, "device": did});
    let challenge = if matches!(purpose.as_str(), "action" | "t3_begin" | "t3_approve" | "t3_execute") {
        let (Some(action), Some(target)) = (txt(&b, "action", 64), txt(&b, "target", 200)) else { return refuse(StatusCode::BAD_REQUEST, "action and target are needed") };
        let params = if b["params"].is_object() { b["params"].clone() } else { json!({}) };
        let nonce = match txt(&b, "nonce", 64) { Some(n) if n.len() >= 8 => n, _ => match random_challenge() { Ok(c) => c, Err(e) => return refuse(StatusCode::INTERNAL_SERVER_ERROR, e) } };
        let Some(Value::String(hash)) = sb.rpc("founder_action_hash", json!({"p_action": action, "p_target": target, "p_params": params, "p_nonce": nonce})).await else { return refuse(StatusCode::BAD_GATEWAY, "action digest unavailable - run the E118 SQL step") };
        let ch = match challenge_of_action_hash(&hash) { Ok(c) => c, Err(e) => return refuse(StatusCode::BAD_GATEWAY, e) };
        state["action"] = json!(action); state["target"] = json!(target); state["params"] = params; state["nonce"] = json!(nonce); state["hash"] = json!(hash);
        if let Some(rq) = txt(&b, "request", 36).filter(|r| is_uuid(r)) { state["request"] = json!(rq); }
        ch
    } else { match random_challenge() { Ok(c) => c, Err(e) => return refuse(StatusCode::INTERNAL_SERVER_ERROR, e) } };
    state["challenge"] = json!(challenge); state["rp_id"] = pol["rp_id"].clone();
    if purpose == "register" { match txt(&b, "label", 80).and_then(|l| clean_label(&l)) { Some(l) => state["label"] = json!(l), None => return refuse(StatusCode::BAD_REQUEST, "passkey name: 1 to 40 characters") } }
    let kind = if purpose == "register" { "register" } else { "authenticate" };
    let Some(Value::String(cid)) = sb.rpc("founder_passkey_ceremony_begin", json!({"p_uid": uid, "p_kind": kind, "p_state": state})).await else { return refuse(StatusCode::TOO_MANY_REQUESTS, "too many open ceremonies or the maximum of 5 passkeys") };
    let opts = if purpose == "register" { create_options(&pol, &challenge, &uid, &email, &ids, secs * 1000) } else { get_options(&pol, &challenge, &ids, secs * 1000) };
    crate::signed(&st, json!({"ceremony": cid, "purpose": purpose, "options": opts, "nonce": state["nonce"], "hash": state["hash"]}))
}

async fn ceremony_take(sb: &crate::data::Sb, uid: &str, id: &str, kind: &str) -> Result<Value, Response> {
    if !is_uuid(id) { return Err(refuse(StatusCode::BAD_REQUEST, "bad ceremony id")); }
    sb.rpc_msg("founder_passkey_ceremony_take", json!({"p_uid": uid, "p_id": id, "p_kind": kind})).await.map_err(sql_err)
}

/// POST /founder/v1/passkey/verify  {ceremony, credential}
pub async fn verify_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _email, did) = match ctx(&st, &h, "/founder/v1/passkey/verify", &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    let b = match body_json(&body) { Ok(b) => b, Err(r) => return r };
    let cred = &b["credential"];
    let is_reg = cred["response"]["attestationObject"].is_string();
    let state = match ceremony_take(sb, &uid, b["ceremony"].as_str().unwrap_or(""), if is_reg { "register" } else { "authenticate" }).await { Ok(s) => s, Err(r) => return r };
    if state["device"].as_str() != Some(did.as_str()) { return refuse(StatusCode::FORBIDDEN, "this ceremony belongs to another device"); }
    let (ch, origin, rp) = (st_s(&state, "challenge"), st_s(&state, "origin"), st_s(&state, "rp_id"));
    if is_reg && state["purpose"] == "register" { return register_step(&st, sb, &uid, &did, cred, &state, (&ch, &origin, &rp)).await; }
    if is_reg || state["purpose"] == "register" { return refuse(StatusCode::BAD_REQUEST, "this answer does not match the ceremony"); }
    assert_step(&st, sb, &uid, &did, cred, &state, (&ch, &origin, &rp)).await
}
fn st_s(v: &Value, k: &str) -> String { v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string() }

async fn register_step(st: &St, sb: &crate::data::Sb, uid: &str, did: &str, cred: &Value, state: &Value, (ch, origin, rp): (&str, &str, &str)) -> Response {
    let reg = match verify_registration(cred, ch, origin, rp) { Ok(r) => r, Err(e) => return refuse(StatusCode::BAD_REQUEST, e) };
    let label = st_s(state, "label");
    let first = active(sb, uid).await.is_empty();
    if first { return finish_register(st, sb, uid, did, &reg, &label, None, None, "first").await; }
    // 2nd and later keys are a T2 action on the NEW credential id: park the verified registration in a fresh ceremony, the browser then proves a step-up for it
    let nonce = match random_challenge() { Ok(n) => n, Err(e) => return refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    let parked = json!({"purpose": "register_pending", "device": did, "reg": {"credential_id": reg.credential_id, "key": reg.key, "facts": reg.facts}, "label": label, "nonce": nonce});
    let Some(Value::String(cid)) = sb.rpc("founder_passkey_ceremony_begin", json!({"p_uid": uid, "p_kind": "register", "p_state": parked})).await else { return refuse(StatusCode::TOO_MANY_REQUESTS, "too many open ceremonies") };
    crate::signed(st, json!({"ok": true, "needs_stepup": true, "ceremony": cid, "credential_id": reg.credential_id, "action": "passkey.add", "target": reg.credential_id, "params": {"label": label}, "nonce": nonce}))
}

#[allow(clippy::too_many_arguments)]
async fn finish_register(st: &St, sb: &crate::data::Sb, uid: &str, did: &str, reg: &Reg, label: &str, grant: Option<&str>, nonce: Option<&str>, via: &str) -> Response {
    let aaguid = reg.facts["aaguid"].as_str().unwrap_or("");
    let added = match sb.rpc_msg("founder_passkey_add", json!({"p_uid": uid, "p_device": did, "p_credential_id": reg.credential_id, "p_passkey": reg.key, "p_label": label, "p_aaguid": aaguid, "p_grant": grant, "p_nonce": nonce})).await { Ok(v) => v, Err(e) => return sql_err(e) };
    let facts = match sb.rpc_msg("founder_webauthn_register", json!({"p_uid": uid, "p_credential_id": reg.credential_id, "p_facts": reg.facts})).await { Ok(v) => v, Err(e) => return sql_err(e) };
    if facts["ok"].as_bool() != Some(true) {
        // fail closed: a key without facts cannot sign in (assert denies unknown credentials); take it out of the active set too
        if let Some(id) = added["id"].as_str().filter(|i| is_uuid(i)) {
            let _ = sb.http.patch(format!("{}/rest/v1/founder_passkeys?id=eq.{id}&revoked_at=is.null", sb.url)).header("apikey", &sb.key).header("authorization", format!("Bearer {}", sb.key))
                .json(&json!({"revoked_at": "now()", "revoked_reason": "registration refused by the WebAuthn policy"})).send().await;
        }
        return (StatusCode::FORBIDDEN, Json(json!({"error": "the WebAuthn policy refused this key", "reasons": facts["reasons"], "kind": facts["kind"]}))).into_response();
    }
    // first key => the 10 one-time recovery codes, shown once
    let codes = if added["active"].as_i64() == Some(1) { sb.rpc("founder_recovery_codes_generate", json!({"p_uid": uid, "p_device": did, "p_grant": Value::Null, "p_nonce": Value::Null})).await } else { None };
    crate::signed(st, json!({"ok": true, "added": added, "facts": facts, "via": via, "recovery_codes": codes}))
}

async fn assert_step(st: &St, sb: &crate::data::Sb, uid: &str, did: &str, cred: &Value, state: &Value, (ch, origin, rp): (&str, &str, &str)) -> Response {
    let cid = cred.get("id").and_then(|x| x.as_str()).unwrap_or("");
    let act = active(sb, uid).await;
    let Some(key) = act.iter().find(|a| a["credential_id"].as_str() == Some(cid)).map(|a| a["passkey"].clone()) else { return refuse(StatusCode::FORBIDDEN, "unknown or revoked passkey") };
    let asr = match verify_assertion(cred, &key, ch, origin, rp) {
        Ok(a) => a,
        Err(e) => { let _ = sb.rpc("founder_webauthn_fail", json!({"p_uid": uid, "p_credential_id": cid, "p_reason": e})).await; return refuse(StatusCode::FORBIDDEN, e); }
    };
    let verdict = match sb.rpc_msg("founder_webauthn_assert", json!({"p_uid": uid, "p_credential_id": asr.credential_id, "p_in": asr.facts})).await { Ok(v) => v, Err(e) => return sql_err(e) };
    if verdict["decision"] != "allow" {
        return (StatusCode::FORBIDDEN, Json(json!({"error": if verdict["decision"] == "stepup" { "extra proof needed: use a hardware key" } else { "sign-in refused" }, "decision": verdict["decision"], "risk": verdict["risk"], "reasons": verdict["reasons"], "kind": verdict["kind"]}))).into_response();
    }
    let (action, target, params, nonce) = (st_s(state, "action"), st_s(state, "target"), state["params"].clone(), st_s(state, "nonce"));
    let (name, args) = match st_s(state, "purpose").as_str() {
        "signin" => ("founder_stepup_issue", json!({"p_uid": uid, "p_device": did, "p_credential_id": cid, "p_scope": "signin"})),
        "action" => ("founder_stepup_issue", json!({"p_uid": uid, "p_device": did, "p_credential_id": cid, "p_action": action, "p_target": target, "p_params": params, "p_nonce": nonce})),
        "t3_begin" => ("founder_t3_begin", json!({"p_uid": uid, "p_device": did, "p_credential_id": cid, "p_action": action, "p_target": target, "p_params": params, "p_nonce": nonce})),
        "t3_approve" => ("founder_t3_approve", json!({"p_uid": uid, "p_device": did, "p_request": state["request"], "p_credential_id": cid, "p_action": action, "p_target": target, "p_params": params, "p_nonce": nonce})),
        "t3_execute" => ("founder_t3_execute", json!({"p_uid": uid, "p_device": did, "p_request": state["request"], "p_action": action, "p_target": target, "p_params": params, "p_nonce": nonce})),
        _ => return refuse(StatusCode::BAD_REQUEST, "this ceremony cannot be answered with an assertion"),
    };
    match sb.rpc_msg(name, args).await {
        Ok(r) => crate::signed(st, json!({"ok": true, "decision": verdict["decision"], "risk": verdict["risk"], "result": r, "hardware": verdict["device_bound"]})),
        Err(e) => sql_err(e),
    }
}

/// POST /founder/v1/passkey/finish  {ceremony, grant?}  — completes a second/third key after its step-up grant.
pub async fn finish_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, did) = match ctx(&st, &h, "/founder/v1/passkey/finish", &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    let b = match body_json(&body) { Ok(b) => b, Err(r) => return r };
    let state = match ceremony_take(sb, &uid, b["ceremony"].as_str().unwrap_or(""), "register").await { Ok(s) => s, Err(r) => return r };
    if state["purpose"] != "register_pending" || state["device"].as_str() != Some(did.as_str()) { return refuse(StatusCode::FORBIDDEN, "not a pending registration of this device"); }
    let grant = b["grant"].as_str().filter(|g| is_uuid(g));
    if grant.is_none() { return refuse(StatusCode::FORBIDDEN, "the step-up grant is missing"); }
    let r = &state["reg"];
    let reg = Reg { credential_id: st_s(r, "credential_id"), key: r["key"].clone(), facts: r["facts"].clone(), sign_count: 0 };
    let nonce = st_s(&state, "nonce");
    finish_register(&st, sb, &uid, &did, &reg, &st_s(&state, "label"), grant, Some(&nonce), "t2").await
}

/// GET /founder/v1/passkey/list — keys, E139 status, open Signal API calls, protocol status. One signed answer.
pub async fn list_ep(State(st): State<S>, h: HeaderMap) -> Response {
    let (uid, _e, _d) = match ctx(&st, &h, "/founder/v1/passkey/list", b"", false).await { Ok(x) => x, Err(r) => return r };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    let (keys, wa, sig, proto, pq) = tokio::join!(sb.rpc("founder_passkey_list", json!({"p_uid": uid})), sb.rpc("founder_webauthn_status", json!({"p_uid": uid})),
        sb.rpc("founder_webauthn_signal_next", json!({"p_uid": uid})), sb.rpc("founder_protocol_status", json!({"p_uid": uid})), sb.rpc("founder_webauthn_pq_report", json!({})));
    // E117's list shows only the first 8 characters; a protected step on a key needs the full id (it is the action's target), so join it in by row id
    let full = sb.rows(&format!("founder_passkeys?select=id,credential_id&user_id=eq.{uid}&revoked_at=is.null")).await.unwrap_or_default();
    let mut keys = keys.unwrap_or(json!([]));
    if let Some(a) = keys.as_array_mut() { for k in a { if let Some(f) = full.iter().find(|f| f["id"] == k["id"]) { k["credential_id"] = f["credential_id"].clone(); } } }
    crate::signed(&st, json!({"available": true, "keys": keys, "webauthn": wa, "signals": sig.map(|s| s["signals"].clone()).unwrap_or(json!([])), "protocol": proto, "post_quantum": pq}))
}

/// The SQL doors the browser may call through /founder/v1/chairman/<door> (POST, signed). Argument names are fixed here; shapes are checked here and again in SQL.
pub fn door_spec(door: &str) -> Option<(&'static str, &'static [(&'static str, char)])> {
    // (sql function, [(argument, shape)])  shapes: u uuid, s short text, t text, j object, b bool, n integer, g grant uuid-or-null, o nonce-or-null
    Some(match door {
        "recovery_codes" => ("founder_recovery_codes_generate", &[("p_grant", 'g'), ("p_nonce", 'o')]),
        "aaguid_allow" => ("founder_aaguid_allow_set", &[("p_aaguid", 's'), ("p_label", 's'), ("p_enabled", 'b'), ("p_grant", 'u'), ("p_nonce", 's')]),
        "t2_hardware" => ("founder_protocol_t2_hardware", &[("p_on", 'b'), ("p_grant", 'u'), ("p_nonce", 's')]),
        "t3_cancel" => ("founder_t3_cancel", &[("p_request", 'u'), ("p_reason", 't')]),
        "flare_set" => ("founder_mobile_flare_set", &[("p_e164", 's'), ("p_grant", 'u'), ("p_nonce", 's')]),
        "flare_remove" => ("founder_mobile_flare_remove", &[("p_grant", 'u'), ("p_nonce", 's')]),
        "revoke" => ("founder_passkey_revoke", &[("p_id", 'u'), ("p_reason", 't'), ("p_grant", 'u'), ("p_nonce", 's')]),
        "recovery_cancel" => ("founder_recovery_cancel", &[("p_request", 'u'), ("p_reason", 't')]),
        "mds" => ("founder_mds_ingest", &[("p_blob_no", 'n'), ("p_entries", 'a')]),
        "signal_ack" => ("founder_webauthn_signal_ack", &[("p_id", 'u')]),
        _ => return None,
    })
}
/// Build the RPC body from the browser's JSON: only the named arguments, each in its shape; uid and device come from the token, never from the body.
pub fn door_args(spec: &[(&str, char)], b: &Value, uid: &str, did: &str, door: &str) -> Result<Value, &'static str> {
    let mut o = serde_json::Map::new();
    o.insert("p_uid".into(), json!(uid));
    if !matches!(door, "mds" | "signal_ack") { o.insert("p_device".into(), json!(did)); }
    for (name, shape) in spec {
        let v = b.get(*name);
        let ok = match shape {
            'u' => v.and_then(|x| x.as_str()).is_some_and(is_uuid),
            'g' => v.is_none_or(|x| x.is_null() || x.as_str().is_some_and(is_uuid)),
            'o' => v.is_none_or(|x| x.is_null() || x.as_str().is_some_and(|s| (8..=64).contains(&s.len()))),
            's' => v.and_then(|x| x.as_str()).is_some_and(|s| !s.is_empty() && s.len() <= 64),
            't' => v.and_then(|x| x.as_str()).is_some_and(|s| !s.trim().is_empty() && s.chars().count() <= 500),
            'b' => v.is_some_and(|x| x.is_boolean()),
            'n' => v.and_then(|x| x.as_i64()).is_some_and(|n| (1..=1_000_000_000).contains(&n)),
            'a' => v.and_then(|x| x.as_array()).is_some_and(|a| a.len() <= 2000),
            _ => false,
        };
        if !ok { return Err("a field is missing or has the wrong shape"); }
        o.insert((*name).into(), v.cloned().unwrap_or(Value::Null));
    }
    Ok(Value::Object(o))
}

/// POST /founder/v1/chairman/{door}
pub async fn door_ep(State(st): State<S>, axum::extract::Path(door): axum::extract::Path<String>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let path = format!("/founder/v1/chairman/{door}");
    let (uid, _e, did) = match ctx(&st, &h, &path, &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    let Some((func, spec)) = door_spec(&door) else { return refuse(StatusCode::NOT_FOUND, "unknown door") };
    let b = match body_json(&body) { Ok(b) => b, Err(r) => return r };
    let args = match door_args(spec, &b, &uid, &did, &door) { Ok(a) => a, Err(e) => return refuse(StatusCode::BAD_REQUEST, e) };
    match sb.rpc_msg(func, args).await { Ok(r) => crate::signed(&st, json!({"ok": true, "door": door, "result": r})), Err(e) => sql_err(e) }
}

#[cfg(test)]
mod route_tests {
    use super::*;
    const U: &str = "2fc0579f-8113-47ea-b116-bb5a8db9202a";
    #[test]
    fn doors_are_whitelisted_and_shaped() {
        assert!(door_spec("drop_table").is_none());
        let (f, spec) = door_spec("t3_cancel").unwrap();
        assert_eq!(f, "founder_t3_cancel");
        let a = door_args(spec, &json!({"p_request": U, "p_reason": "changed my mind", "p_uid": "attacker", "p_device": "x"}), "me", "dev", "t3_cancel").unwrap();
        assert_eq!(a["p_uid"], "me");          // the body can never choose the uid
        assert_eq!(a["p_device"], "dev");      // nor the device
        assert!(a.get("extra").is_none());
        assert!(door_args(spec, &json!({"p_request": "no", "p_reason": "x"}), "me", "dev", "t3_cancel").is_err());
        assert!(door_args(spec, &json!({"p_request": U}), "me", "dev", "t3_cancel").is_err());
        let (_, rc) = door_spec("recovery_codes").unwrap();
        assert!(door_args(rc, &json!({}), "me", "dev", "recovery_codes").is_ok()); // first-key path: grant and nonce may be null
        assert!(door_args(rc, &json!({"p_grant": "nope"}), "me", "dev", "recovery_codes").is_err());
        let (_, fl) = door_spec("flare_set").unwrap();
        assert!(door_args(fl, &json!({"p_e164": "+923001234567", "p_grant": U, "p_nonce": "nonce-123456"}), "me", "dev", "flare_set").is_ok());
        assert!(door_args(fl, &json!({"p_e164": "", "p_grant": U, "p_nonce": "n"}), "me", "dev", "flare_set").is_err());
        let (_, m) = door_spec("mds").unwrap();
        let a = door_args(m, &json!({"p_blob_no": 7, "p_entries": []}), "me", "dev", "mds").unwrap();
        assert!(a.get("p_device").is_none());
        assert!(door_args(m, &json!({"p_blob_no": 0, "p_entries": []}), "me", "dev", "mds").is_err());
    }
    #[test]
    fn tiers_decide_the_gate() {
        assert_eq!(tier_gate(None), TierGate::Open);
        assert_eq!(tier_gate(Some(1)), TierGate::Open);
        assert_eq!(tier_gate(Some(2)), TierGate::NeedGrant);
        assert_eq!(tier_gate(Some(3)), TierGate::T3Only);
        assert_eq!(tier_gate(Some(9)), TierGate::T3Only);
    }
    #[test]
    fn every_door_matches_a_real_sql_signature_name() {
        for d in ["recovery_codes", "aaguid_allow", "t2_hardware", "t3_cancel", "flare_set", "flare_remove", "revoke", "recovery_cancel", "mds", "signal_ack"] {
            let (f, spec) = door_spec(d).unwrap();
            assert!(f.starts_with("founder_") && !spec.is_empty() || d == "recovery_codes");
        }
    }
}
