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
const TRACKS: [&str; 4] = ["summary", "services", "alerts", "plans"];

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

// ---- D5a-5 (phase 1i, 23 Nov 2026): the lookup answer can NEVER reach a screen unless it is fresh and for THIS call. Any doubt = Unavailable. ----
pub const LOOKUP_PATH: &str = "/desk/v1/customer/lookup";
/// An answer whose own signed answered_at is more than this many seconds older than the Desk's signed envelope time is never shown, however genuine its signature is.
pub const LOOKUP_FRESH_SECS: i64 = 15;
#[derive(Debug, PartialEq)]
pub enum LookupView { Data(String), Refused, Unavailable }
/// The ONLY door from a Desk lookup answer to a screen. `status` is the HTTP status the browser saw, `envelope` the sealed answer. Data only when: signature + method + path + nonce + clock (verify_answer),
/// HTTP 200, the body names the SAME request id and company the page asked for, answered_at is at most 15 s old (and at most 5 s in the future), and `fields` is an object. A signed refusal (403) = Refused.
/// Everything else (any other status, 503, stale, replayed, other request, other company, malformed, empty) = Unavailable: the page shows "Data unavailable" and keeps nothing from before.
pub fn lookup_view(pinned_pub_hex: &str, nonce: &str, now: i64, request_id: &str, company: &str, status: u16, envelope: &str) -> LookupView {
    let Ok(body) = verify_answer(pinned_pub_hex, "POST", LOOKUP_PATH, nonce, now, envelope) else { return LookupView::Unavailable };
    let Ok(b) = serde_json::from_str::<serde_json::Value>(&body) else { return LookupView::Unavailable };
    // freshness is measured against the Desk's OWN signed envelope time (the signature covers ts), so a laptop clock that is a little off cannot hide stale data or break good data;
    // the laptop clock itself must still be within SKEW_SECS of the Desk (verify_answer above), so an old envelope cannot be replayed either.
    let Some(ts) = serde_json::from_str::<serde_json::Value>(envelope).ok().and_then(|e| e["ts"].as_i64()) else { return LookupView::Unavailable };
    if status == 403 && b["error"].as_str() == Some("control_plane_refused") && b["request_id"].as_str() == Some(request_id) { return LookupView::Refused; }
    if status != 200 { return LookupView::Unavailable; }
    if b["request_id"].as_str() != Some(request_id) || b["company_ref"].as_str() != Some(company) { return LookupView::Unavailable; }
    let Some(at) = b["answered_at"].as_i64() else { return LookupView::Unavailable };
    if ts - at > LOOKUP_FRESH_SECS || at - ts > 5 { return LookupView::Unavailable; }
    if !b["fields"].is_object() { return LookupView::Unavailable; }
    LookupView::Data(body)
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
    // ---- D5a-5 (1i): every doubtful lookup answer ends as Unavailable ----
    const RID: &str = "11111111-2222-4333-8444-555555555555";
    fn lk(sk: &SigningKey, ts: i64, body: &str) -> String { envelope(sk, "POST", LOOKUP_PATH, NONCE, ts, body) }
    fn good_body(at: i64) -> String { serde_json::json!({"request_id": RID, "company_ref": "acme-1234", "answered_at": at, "fields": {"service_state": "active"}}).to_string() }
    #[test] fn lookup_view_shows_data_only_when_fresh_and_for_this_call() {
        let sk = SigningKey::from_bytes(&[1u8; 32]); let pk = hex(sk.verifying_key().as_bytes());
        let v = |now: i64, st: u16, rid: &str, co: &str, env: &str| lookup_view(&pk, NONCE, now, rid, co, st, env);
        let env = lk(&sk, 1005, &good_body(1000));
        assert_eq!(v(1005, 200, RID, "acme-1234", &env), LookupView::Data(good_body(1000)));
        assert_eq!(v(1005, 200, RID, "acme-1234", &lk(&sk, 1000 + LOOKUP_FRESH_SECS, &good_body(1000))), LookupView::Data(good_body(1000)), "exactly at the limit");
        assert_eq!(v(1016, 200, RID, "acme-1234", &lk(&sk, 1000 + LOOKUP_FRESH_SECS + 1, &good_body(1000))), LookupView::Unavailable, "genuine but 16 s old: never shown");
        assert_eq!(v(1005, 200, "99999999-2222-4333-8444-555555555555", "acme-1234", &env), LookupView::Unavailable, "another request");
        assert_eq!(v(1005, 200, RID, "other-9999", &env), LookupView::Unavailable, "another company");
        assert_eq!(v(1005, 503, RID, "acme-1234", &env), LookupView::Unavailable, "a 503 is never data, whatever the body says");
        assert_eq!(v(1005, 500, RID, "acme-1234", &env), LookupView::Unavailable);
        assert_eq!(v(1005, 0, RID, "acme-1234", &env), LookupView::Unavailable, "network error");
        assert_eq!(v(1000, 200, RID, "acme-1234", &lk(&sk, 1000, &good_body(1100))), LookupView::Unavailable, "answered in the future");
        assert_eq!(v(1005, 200, RID, "acme-1234", &lk(&sk, 1005, &serde_json::json!({"request_id": RID, "company_ref": "acme-1234", "answered_at": 1000}).to_string())), LookupView::Unavailable, "no fields object");
        assert_eq!(v(1005, 200, RID, "acme-1234", &lk(&sk, 1005, "not json")), LookupView::Unavailable);
        assert_eq!(v(1005, 200, RID, "acme-1234", ""), LookupView::Unavailable, "empty answer");
        assert_eq!(v(1005, 200, RID, "acme-1234", "{}"), LookupView::Unavailable, "unsigned");
        // a laptop clock 100 s off still gets good data (the Desk's own time decides freshness); 130 s off is refused by verify_answer (SKEW 120)
        assert_eq!(v(1105, 200, RID, "acme-1234", &env), LookupView::Data(good_body(1000)), "clock 100 s ahead: fine");
        assert_eq!(v(1005 + SKEW_SECS + 10, 200, RID, "acme-1234", &env), LookupView::Unavailable, "clock far off: refused");
    }
    #[test] fn lookup_view_refuses_wrong_key_replay_for_another_call_and_old_envelope() {
        let sk = SigningKey::from_bytes(&[1u8; 32]); let pk = hex(sk.verifying_key().as_bytes()); let other = hex(SigningKey::from_bytes(&[2u8; 32]).verifying_key().as_bytes());
        let env = lk(&sk, 1000, &good_body(1000));
        assert_eq!(lookup_view(&other, NONCE, 1005, RID, "acme-1234", 200, &env), LookupView::Unavailable, "wrong pinned key");
        assert_eq!(lookup_view(&pk, "ffffffffffffffffffffffffffffffff", 1005, RID, "acme-1234", 200, &env), LookupView::Unavailable, "answer recorded for another call (replay)");
        assert_eq!(lookup_view(&pk, NONCE, 1000 + SKEW_SECS + 1, RID, "acme-1234", 200, &env), LookupView::Unavailable, "old envelope");
        let tampered = env.replace("active", "suspended"); assert_ne!(tampered, env);
        assert_eq!(lookup_view(&pk, NONCE, 1005, RID, "acme-1234", 200, &tampered), LookupView::Unavailable, "tampered");
        let other_path = envelope(&sk, "POST", "/desk/v1/bridge/summary", NONCE, 1000, &good_body(1000));
        assert_eq!(lookup_view(&pk, NONCE, 1005, RID, "acme-1234", 200, &other_path), LookupView::Unavailable, "answer of another door");
    }
    #[test] fn lookup_view_signed_refusal_is_refused_and_forged_refusal_is_not() {
        let sk = SigningKey::from_bytes(&[1u8; 32]); let pk = hex(sk.verifying_key().as_bytes());
        let r = serde_json::json!({"error": "control_plane_refused", "request_id": RID}).to_string();
        assert_eq!(lookup_view(&pk, NONCE, 1005, RID, "acme-1234", 403, &lk(&sk, 1005, &r)), LookupView::Refused);
        assert_eq!(lookup_view(&pk, NONCE, 1005, "99999999-2222-4333-8444-555555555555", "acme-1234", 403, &lk(&sk, 1005, &r)), LookupView::Unavailable, "refusal of another request");
        assert_eq!(lookup_view(&pk, NONCE, 1005, RID, "acme-1234", 403, &lk(&sk, 1000, "{\"error\":\"not_allowed\"}")), LookupView::Unavailable);
    }
}
