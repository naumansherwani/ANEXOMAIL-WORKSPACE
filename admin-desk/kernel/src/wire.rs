// ANEXOMAIL ADMIN DESK KERNEL wire.rs (R3d): wire format v1, mirrored byte for byte by the server (server/src/sign.rs). Pure, host-testable.
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use hkdf::Hkdf;
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};

pub const DOMAIN: &str = "anexo-desk-v1";
pub const SKEW_SECS: i64 = 120;

pub fn hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
pub fn unhex(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 || !s.bytes().all(|b| b.is_ascii_hexdigit()) { return None; }
    (0..s.len()).step_by(2).map(|i| u8::from_str_radix(&s[i..i + 2], 16).ok()).collect()
}
fn sha256_hex(b: &[u8]) -> String { hex(&Sha256::digest(b)) }
fn nonce_ok(n: &str) -> bool { n.len() == 32 && n.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f')) }
fn method_ok(m: &str) -> bool { matches!(m, "GET" | "POST" | "PUT" | "PATCH" | "DELETE") }
fn path_ok(p: &str) -> bool { p.starts_with("/desk/v1/") && p.len() <= 200 && p.bytes().all(|b| b.is_ascii_graphic()) }

pub fn message(method: &str, path: &str, nonce: &str, ts: i64, body: &[u8]) -> Vec<u8> {
    format!("{DOMAIN}\n{method}\n{path}\n{nonce}\n{ts}\n{}", sha256_hex(body)).into_bytes()
}
fn req_key(token: &str) -> [u8; 32] {
    let mut k = [0u8; 32];
    Hkdf::<Sha256>::new(Some(DOMAIN.as_bytes()), token.as_bytes()).expand(b"req-mac", &mut k).expect("32 bytes"); k
}

/// JSON {"nonce","ts","mac"} for the headers x-desk-nonce, x-desk-ts, x-desk-mac.
pub fn request_headers(token: &str, method: &str, path: &str, nonce: &str, ts: i64, body: &[u8]) -> Result<String, &'static str> {
    if !method_ok(method) { return Err("bad_method"); }
    if !path_ok(path) { return Err("bad_path"); }
    if !nonce_ok(nonce) { return Err("bad_nonce"); }
    if token.len() != 64 || !token.bytes().all(|b| b.is_ascii_hexdigit()) { return Err("no_session"); }
    let mut m = <Hmac<Sha256> as Mac>::new_from_slice(&req_key(token)).map_err(|_| "bad_key")?;
    m.update(&message(method, path, nonce, ts, body));
    Ok(serde_json::json!({"nonce": nonce, "ts": ts, "mac": hex(&m.finalize().into_bytes())}).to_string())
}

/// The ONLY way a Desk answer becomes trusted: right key, right method+path+nonce (so no answer can be replayed for another call), fresh clock, exact signed body.
pub fn verify_answer(pinned_pub_hex: &str, method: &str, path: &str, nonce: &str, now: i64, envelope: &str) -> Result<String, &'static str> {
    if !method_ok(method) { return Err("bad_method"); }
    if !path_ok(path) { return Err("bad_path"); }
    if !nonce_ok(nonce) { return Err("bad_nonce"); }
    let e: serde_json::Value = serde_json::from_str(envelope).map_err(|_| "unsigned_answer")?;
    if e["v"] != 1 { return Err("unsigned_answer"); }
    if e["nonce"].as_str() != Some(nonce) { return Err("answer_for_another_call"); }
    let ts = e["ts"].as_i64().ok_or("unsigned_answer")?;
    if (now - ts).abs() > SKEW_SECS { return Err("stale_answer"); }
    let body = e["body"].as_str().ok_or("unsigned_answer")?;
    let sig = unhex(e["sig"].as_str().ok_or("unsigned_answer")?).and_then(|b| Signature::from_slice(&b).ok()).ok_or("unsigned_answer")?;
    let pk: [u8; 32] = unhex(pinned_pub_hex).and_then(|b| b.try_into().ok()).ok_or("bad_pinned_key")?;
    let vk = VerifyingKey::from_bytes(&pk).map_err(|_| "bad_pinned_key")?;
    vk.verify(&message(method, path, nonce, ts, body.as_bytes()), &sig).map_err(|_| "bad_signature")?;
    Ok(body.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signer, SigningKey};
    const NONCE: &str = "000102030405060708090a0b0c0d0e0f";
    fn envelope(sk: &SigningKey, method: &str, path: &str, nonce: &str, ts: i64, body: &str) -> String {
        let sig = hex(&sk.sign(&message(method, path, nonce, ts, body.as_bytes())).to_bytes());
        serde_json::json!({"v":1,"kid":"x","nonce":nonce,"ts":ts,"body":body,"sig":sig}).to_string()
    }
    // SAME fixed layout as the server test message_layout_is_fixed (server/src/sign.rs): a drift on either side fails a test.
    #[test] fn message_layout_matches_server() {
        let m = String::from_utf8(message("GET", "/desk/v1/sig/ping", NONCE, 1000, b"")).unwrap();
        assert_eq!(m, format!("anexo-desk-v1\nGET\n/desk/v1/sig/ping\n{NONCE}\n1000\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"));
    }
    #[test] fn good_answer_accepted_and_tampered_or_replayed_refused() {
        let sk = SigningKey::from_bytes(&[1u8; 32]); let pk = hex(sk.verifying_key().as_bytes());
        let env = envelope(&sk, "GET", "/desk/v1/sig/ping", NONCE, 1000, "{\"pong\":1}");
        assert_eq!(verify_answer(&pk, "GET", "/desk/v1/sig/ping", NONCE, 1010, &env).unwrap(), "{\"pong\":1}");
        let tampered = env.replace("{\\\"pong\\\":1}", "{\\\"pong\\\":2}"); assert_ne!(tampered, env);
        assert_eq!(verify_answer(&pk, "GET", "/desk/v1/sig/ping", NONCE, 1010, &tampered), Err("bad_signature"));
        assert_eq!(verify_answer(&pk, "GET", "/desk/v1/me", NONCE, 1010, &env), Err("bad_signature"));
        assert_eq!(verify_answer(&pk, "GET", "/desk/v1/sig/ping", "ffffffffffffffffffffffffffffffff", 1010, &env), Err("answer_for_another_call"));
        assert_eq!(verify_answer(&pk, "GET", "/desk/v1/sig/ping", NONCE, 1000 + SKEW_SECS + 1, &env), Err("stale_answer"));
        assert_eq!(verify_answer(&pk, "GET", "/desk/v1/sig/ping", NONCE, 1010, "{\"pong\":1}"), Err("unsigned_answer"));
        assert_eq!(verify_answer(&pk, "GET", "/desk/v1/sig/ping", NONCE, 1010, "not json"), Err("unsigned_answer"));
    }
    #[test] fn wrong_key_refused_even_with_valid_signature() {
        let a = SigningKey::from_bytes(&[1u8; 32]); let b = SigningKey::from_bytes(&[2u8; 32]);
        let env = envelope(&a, "GET", "/desk/v1/sig/ping", NONCE, 1000, "{}");
        assert_eq!(verify_answer(&hex(b.verifying_key().as_bytes()), "GET", "/desk/v1/sig/ping", NONCE, 1000, &env), Err("bad_signature"));
        assert_eq!(verify_answer("00", "GET", "/desk/v1/sig/ping", NONCE, 1000, &env), Err("bad_pinned_key"));
    }
    #[test] fn request_headers_validate_inputs() {
        let t = "ab".repeat(32);
        assert!(request_headers(&t, "GET", "/desk/v1/sig/ping", NONCE, 1000, b"").is_ok());
        assert_eq!(request_headers(&t, "GET", "/other", NONCE, 1000, b""), Err("bad_path"));
        assert_eq!(request_headers("short", "GET", "/desk/v1/x", NONCE, 1000, b""), Err("no_session"));
        assert_eq!(request_headers(&t, "TRACE", "/desk/v1/x", NONCE, 1000, b""), Err("bad_method"));
    }
}
