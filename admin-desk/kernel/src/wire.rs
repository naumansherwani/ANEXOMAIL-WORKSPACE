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

// ---- Phase C2 (22 Nov 2026): the live Bridge stream (WebTransport /wt/bridge). Same Rule 52, per frame. ----
pub const STREAM_PATH: &str = "/wt/bridge";
pub const STALE_SECS: i64 = 12;
const TRACKS: [&str; 3] = ["summary", "services", "alerts"];

/// The first line of the stream: `ANX1 <token> <nonce> <ts> <mac>\n` (the browser cannot set headers on a WebTransport CONNECT, so the request MAC rides the hello).
pub fn stream_hello(token: &str, nonce: &str, ts: i64) -> Result<String, &'static str> {
    if !nonce_ok(nonce) { return Err("bad_nonce"); }
    if token.len() != 64 || !token.bytes().all(|b| b.is_ascii_hexdigit()) { return Err("no_session"); }
    let mut m = <Hmac<Sha256> as Mac>::new_from_slice(&req_key(token)).map_err(|_| "bad_key")?;
    m.update(&message("WT", STREAM_PATH, nonce, ts, b""));
    Ok(format!("ANX1 {token} {nonce} {ts} {}\n", hex(&m.finalize().into_bytes())))
}

/// ONE stream line -> the trusted frame JSON {"seq","track","data"}, or a refusal. Checks: Desk key (pinned), signature over method WT + path /wt/bridge/<track> + nonce + ts + exact body,
/// fresh clock, a known track, and seq == last_seq + 1 for that track (a replayed, skipped or reordered frame is REFUSED).
pub fn verify_frame(pinned_pub_hex: &str, now: i64, last_seq: u64, line: &str) -> Result<String, &'static str> {
    let e: serde_json::Value = serde_json::from_str(line.trim_end_matches('\n')).map_err(|_| "unsigned_frame")?;
    if e["v"] != 1 { return Err("unsigned_frame"); }
    let nonce = e["nonce"].as_str().filter(|n| nonce_ok(n)).ok_or("bad_nonce")?;
    let ts = e["ts"].as_i64().ok_or("unsigned_frame")?;
    if (now - ts).abs() > SKEW_SECS { return Err("stale_frame"); }
    let body = e["body"].as_str().ok_or("unsigned_frame")?;
    let b: serde_json::Value = serde_json::from_str(body).map_err(|_| "unsigned_frame")?;
    let track = b["track"].as_str().filter(|t| TRACKS.contains(t)).ok_or("bad_track")?;
    let sig = unhex(e["sig"].as_str().ok_or("unsigned_frame")?).and_then(|x| Signature::from_slice(&x).ok()).ok_or("unsigned_frame")?;
    let pk: [u8; 32] = unhex(pinned_pub_hex).and_then(|x| x.try_into().ok()).ok_or("bad_pinned_key")?;
    let vk = VerifyingKey::from_bytes(&pk).map_err(|_| "bad_pinned_key")?;
    vk.verify(&message("WT", &format!("{STREAM_PATH}/{track}"), nonce, ts, body.as_bytes()), &sig).map_err(|_| "bad_signature")?;
    let seq = b["seq"].as_u64().ok_or("bad_seq")?;
    if seq != last_seq + 1 { return Err("frame_out_of_order"); }
    Ok(body.to_string())
}
/// A track is STALE when its last verified frame is older than 12 s (the server sends a heartbeat every 8 s).
pub fn is_stale(last_frame_ts: i64, now: i64) -> bool { now - last_frame_ts > STALE_SECS }

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

    fn frame(sk: &SigningKey, nonce: &str, ts: i64, track: &str, seq: u64) -> String {
        let body = format!("{{\"seq\":{seq},\"track\":\"{track}\",\"data\":{{\"p1\":0}}}}");
        let sig = hex(&sk.sign(&message("WT", &format!("/wt/bridge/{track}"), nonce, ts, body.as_bytes())).to_bytes());
        serde_json::json!({"v":1,"kid":"x","nonce":nonce,"ts":ts,"body":body,"sig":sig}).to_string()
    }
    #[test] fn stream_frames_verified_and_order_enforced() {
        let sk = SigningKey::from_bytes(&[1u8; 32]); let pk = hex(sk.verifying_key().as_bytes());
        let f1 = frame(&sk, NONCE, 1000, "summary", 1);
        assert!(verify_frame(&pk, 1005, 0, &f1).unwrap().contains("\"seq\":1"));
        assert_eq!(verify_frame(&pk, 1005, 1, &f1), Err("frame_out_of_order"), "a replayed frame is refused");
        assert_eq!(verify_frame(&pk, 1005, 5, &frame(&sk, NONCE, 1000, "summary", 7)), Err("frame_out_of_order"), "a gap is refused");
        assert_eq!(verify_frame(&pk, 1005 + SKEW_SECS, 0, &f1), Err("stale_frame"));
        assert_eq!(verify_frame(&pk, 1005, 0, &f1.replace("p1", "p2")), Err("bad_signature"));
        assert_eq!(verify_frame(&pk, 1005, 0, &frame(&sk, NONCE, 1000, "secrets", 1)), Err("bad_track"));
        assert_eq!(verify_frame(&hex(SigningKey::from_bytes(&[2u8; 32]).verifying_key().as_bytes()), 1005, 0, &f1), Err("bad_signature"));
        assert_eq!(verify_frame(&pk, 1005, 0, "{\"seq\":1}"), Err("unsigned_frame"));
        // a frame signed for ANOTHER track cannot be moved onto this one
        let moved = f1.replace("summary", "alerts"); assert_eq!(verify_frame(&pk, 1005, 0, &moved), Err("bad_signature"));
    }
    #[test] fn stream_hello_is_mac_bound_and_strict() {
        let t = "ab".repeat(32);
        let h = stream_hello(&t, NONCE, 1000).unwrap();
        assert!(h.starts_with("ANX1 ") && h.ends_with('\n') && h.split(' ').count() == 5);
        assert_eq!(stream_hello("short", NONCE, 1000), Err("no_session"));
        assert_eq!(stream_hello(&t, "zz", 1000), Err("bad_nonce"));
        assert!(is_stale(1000, 1013) && !is_stale(1000, 1012));
    }
}
