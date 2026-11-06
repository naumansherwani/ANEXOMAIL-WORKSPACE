//! lease@1 — J8c. The browser judges a vault lease; the page only shows the verdict. Technology: Rust -> WASM kernel (Rule 52), SHA-256 / HMAC from this same kernel, no new crates.
//! Two jobs, both pure (the host passes every clock reading in, the kernel never reads a clock):
//!  1. `check`     is this lease good for THIS device, right now? Shape and arithmetic mirror the server's `lease_data` (server/founder/src/lease.rs), plus what only the device can see:
//!                 the serial never goes backwards (a replayed older lease is refused), the device wall clock at receipt agrees with the server within a skew, and the time left is counted on the
//!                 MONOTONIC clock from the moment of receipt. If the wall clock was turned back while the monotonic clock ran on, the lease is treated as ended (this closes the "wind the clock back" gap).
//!  2. `vault_key` vault key = HKDF-SHA256(salt "anexo-vault-key@1", ikm = local half || server half, info "device|<id>"), RFC 5869. The server half exists only inside a live lease; the page keeps it in memory.
//! The Ed25519 signature of the lease envelope is checked by envelope@1 before this module is asked; `check` judges the data inside it.
use crate::hash::hmac_sha256;
use serde_json::{Value, json};

pub const TYPE: &str = "vault-lease@1";
pub const DEFAULT_SKEW_MS: i64 = 300_000;

/* ---- RFC 5869 HKDF-SHA256 (extract + expand), built on the kernel's HMAC ---- */
pub fn hkdf(ikm: &[u8], salt: &[u8], info: &[u8], len: usize) -> Option<Vec<u8>> {
    if len == 0 || len > 255 * 32 { return None; }
    let salt: &[u8] = if salt.is_empty() { &[0u8; 32] } else { salt };
    let prk = hmac_sha256(salt, ikm);
    let (mut t, mut okm): (Vec<u8>, Vec<u8>) = (Vec::new(), Vec::new());
    let mut i = 1u8;
    while okm.len() < len {
        let mut m = t.clone(); m.extend_from_slice(info); m.push(i);
        t = hmac_sha256(&prk, &m).to_vec();
        okm.extend_from_slice(&t);
        i = i.checked_add(1)?;
    }
    okm.truncate(len);
    Some(okm)
}

fn b64u_decode(s: &str) -> Option<Vec<u8>> {
    let mut out = Vec::new(); let (mut acc, mut bits) = (0u32, 0u32);
    for c in s.bytes() {
        let v = match c { b'A'..=b'Z' => c - b'A', b'a'..=b'z' => c - b'a' + 26, b'0'..=b'9' => c - b'0' + 52, b'-' => 62, b'_' => 63, _ => return None } as u32;
        acc = acc << 6 | v; bits += 6;
        if bits >= 8 { bits -= 8; out.push((acc >> bits & 0xff) as u8); acc &= (1 << bits) - 1; }
    }
    if bits >= 6 || (acc != 0) { return None; }   // canonical only: no stray bits
    Some(out)
}
fn b64u_encode(d: &[u8]) -> String {
    const A: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    let mut o = String::new();
    for c in d.chunks(3) { let n = (c[0] as u32) << 16 | (*c.get(1).unwrap_or(&0) as u32) << 8 | *c.get(2).unwrap_or(&0) as u32; for i in 0..=c.len() { o.push(A[(n >> (18 - 6 * i) & 63) as usize] as char); } }
    o
}

/// Input {local, half, device_id}: both halves are base64url of 32 bytes. Out: the 32-byte vault key as base64url, or None.
pub fn vault_key(local_b64: &str, half_b64: &str, device_id: &str) -> Option<String> {
    let (l, h) = (b64u_decode(local_b64)?, b64u_decode(half_b64)?);
    if l.len() != 32 || h.len() != 32 || !uuid_ok(device_id) { return None; }
    let mut ikm = l; ikm.extend_from_slice(&h);
    Some(b64u_encode(&hkdf(&ikm, b"anexo-vault-key@1", format!("device|{}", device_id.to_ascii_lowercase()).as_bytes(), 32)?))
}

fn uuid_ok(s: &str) -> bool { s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_hexdigit() }) }
fn hex_lower(s: &str, n: usize) -> bool { s.len() == n && s.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)) }
fn b64_43(s: &str) -> bool { s.len() == 43 && b64u_decode(s).map(|d| d.len() == 32).unwrap_or(false) }
fn int(v: &Value, k: &str) -> Option<i64> { v.get(k).and_then(Value::as_i64) }

/// Input: {data, device_id, pinned_serial, received_wall_ms, received_mono_ms, now_wall_ms, now_mono_ms, max_skew_ms?}.
/// Report: {ok, state: "live"|"expired"|"refused", remaining_ms, serial, reason?}. ok only when live. Anything unexpected is "refused" (never silently live).
pub fn check(input: &str) -> (bool, String) {
    let refuse = |why: &str| (false, json!({"ok": false, "state": "refused", "remaining_ms": 0, "reason": why}).to_string());
    let Ok(v) = serde_json::from_str::<Value>(input) else { return refuse("input is not JSON") };
    let Some(d) = v.get("data").filter(|d| d.is_object()) else { return refuse("no lease data") };
    if d.get("type").and_then(Value::as_str) != Some(TYPE) { return refuse("not a vault lease"); }
    if d.as_object().map(|o| o.len()).unwrap_or(0) != 9 { return refuse("the lease has unexpected fields"); }
    let s = |k: &str| d.get(k).and_then(Value::as_str);
    let (Some(dev), Some(nonce), Some(thumb), Some(half)) = (s("device_id"), s("nonce"), s("key_thumb"), s("half")) else { return refuse("the lease is missing a field") };
    let (Some(serial), Some(issued), Some(expires), Some(ttl)) = (int(d, "serial"), int(d, "issued_ms"), int(d, "expires_ms"), int(d, "ttl_s")) else { return refuse("the lease is missing a number") };
    let me = v.get("device_id").and_then(Value::as_str).unwrap_or("");
    if !uuid_ok(dev) || !uuid_ok(me) || !dev.eq_ignore_ascii_case(me) { return refuse("this lease belongs to another device"); }
    if !hex_lower(nonce, 32) || !b64_43(thumb) || !b64_43(half) { return refuse("the lease has a malformed secret field"); }
    if serial < 1 || issued <= 0 || !(60..=3600).contains(&ttl) || issued.checked_add(ttl * 1000) != Some(expires) { return refuse("the lease times do not add up"); }
    let pinned = int(&v, "pinned_serial").unwrap_or(0);
    if serial < pinned { return refuse("an older lease than the one this device already holds (replay)"); }
    let (Some(rw), Some(rm), Some(nw), Some(nm)) = (int(&v, "received_wall_ms"), int(&v, "received_mono_ms"), int(&v, "now_wall_ms"), int(&v, "now_mono_ms")) else { return refuse("the host gave no clock readings") };
    let skew = int(&v, "max_skew_ms").unwrap_or(DEFAULT_SKEW_MS).clamp(1000, 3_600_000);
    if (rw - issued).abs() > skew { return refuse("this device clock disagrees with the server clock"); }
    let elapsed = nm - rm;
    if elapsed < 0 { return refuse("the monotonic clock went backwards"); }
    let wall_elapsed = nw - rw;
    let report = |state: &str, remaining: i64, reason: Option<&str>| {
        let mut r = json!({"ok": state == "live", "state": state, "remaining_ms": remaining.max(0), "serial": serial});
        if let Some(x) = reason { r["reason"] = json!(x); }
        (state == "live", r.to_string())
    };
    if elapsed - wall_elapsed > skew { return report("expired", 0, Some("the device clock was turned back; the lease is treated as ended")); }
    let remaining = ttl * 1000 - elapsed;
    if remaining <= 0 { return report("expired", 0, Some("the lease ran out")); }
    report("live", remaining, None)
}

#[cfg(test)]
mod tests {
    use super::*;
    const DEV: &str = "0f8fad5b-d9cb-469f-a165-70867728950e";
    const K: &str = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    fn h(s: &str) -> Vec<u8> { (0..s.len() / 2).map(|i| u8::from_str_radix(&s[2 * i..2 * i + 2], 16).unwrap()).collect() }
    fn hx(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }

    #[test] fn hkdf_rfc5869_vectors() {
        // A.1
        let okm = hkdf(&[0x0b; 22], &h("000102030405060708090a0b0c"), &h("f0f1f2f3f4f5f6f7f8f9"), 42).unwrap();
        assert_eq!(hx(&okm), "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865");
        // A.3: zero-length salt and info
        let okm = hkdf(&[0x0b; 22], b"", b"", 42).unwrap();
        assert_eq!(hx(&okm), "8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8");
        assert!(hkdf(b"k", b"s", b"i", 0).is_none() && hkdf(b"k", b"s", b"i", 255 * 32 + 1).is_none());
    }
    #[test] fn vault_key_is_stable_and_depends_on_every_input() {
        let a = vault_key(K, "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBE", DEV).unwrap();
        assert_eq!(a.len(), 43); assert_eq!(a, vault_key(K, "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBE", DEV).unwrap());
        assert_ne!(a, vault_key(K, "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCE", DEV).unwrap(), "server half bound");
        assert_ne!(a, vault_key("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCE", "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBE", DEV).unwrap(), "local half bound");
        assert_ne!(a, vault_key(K, "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBE", "ffffffff-d9cb-469f-a165-70867728950e").unwrap(), "device bound");
        assert!(vault_key("short", K, DEV).is_none() && vault_key(K, K, "nope").is_none() && vault_key(&format!("{}+", &K[1..]), K, DEV).is_none());
    }
    fn lease(serial: i64) -> Value { json!({"type": TYPE, "device_id": DEV, "serial": serial, "issued_ms": 1_700_000_000_000i64, "expires_ms": 1_700_000_900_000i64, "ttl_s": 900, "nonce": "0123456789abcdef0123456789abcdef", "key_thumb": K, "half": K}) }
    fn input(data: Value, extra: Value) -> String {
        let mut v = json!({"data": data, "device_id": DEV, "pinned_serial": 0, "received_wall_ms": 1_700_000_000_500i64, "received_mono_ms": 10_000, "now_wall_ms": 1_700_000_000_500i64, "now_mono_ms": 10_000});
        for (k, x) in extra.as_object().unwrap() { v[k] = x.clone(); }
        v.to_string()
    }
    fn state(i: &str) -> (bool, String, String) { let (ok, r) = check(i); let j: Value = serde_json::from_str(&r).unwrap(); (ok, j["state"].as_str().unwrap().to_string(), j["reason"].as_str().unwrap_or("").to_string()) }

    #[test] fn a_fresh_lease_is_live_with_the_full_time_left() {
        let (ok, r) = check(&input(lease(3), json!({})));
        let j: Value = serde_json::from_str(&r).unwrap();
        assert!(ok && j["state"] == "live" && j["remaining_ms"] == 900_000 && j["serial"] == 3);
    }
    #[test] fn time_is_counted_on_the_monotonic_clock() {
        let live = |el: i64| state(&input(lease(3), json!({"now_mono_ms": 10_000 + el, "now_wall_ms": 1_700_000_000_500i64 + el})));
        assert_eq!(live(899_999).1, "live");
        assert_eq!(live(900_000).1, "expired");
        assert_eq!(live(5_000_000).1, "expired");
    }
    #[test] fn a_wound_back_wall_clock_ends_the_lease() {
        // monotonic ran 400 s, but the wall clock says only 10 s passed: the clock was turned back
        let (ok, st, why) = state(&input(lease(3), json!({"now_mono_ms": 410_000, "now_wall_ms": 1_700_000_010_500i64})));
        assert!(!ok && st == "expired" && why.contains("turned back"), "{why}");
        // small drift is fine
        assert_eq!(state(&input(lease(3), json!({"now_mono_ms": 70_000, "now_wall_ms": 1_700_000_058_500i64}))).1, "live");
    }
    #[test] fn a_device_clock_far_from_the_server_refuses_the_lease() {
        assert_eq!(state(&input(lease(3), json!({"received_wall_ms": 1_700_000_900_000i64}))).1, "refused");
        assert_eq!(state(&input(lease(3), json!({"received_wall_ms": 1_699_999_000_000i64}))).1, "refused");
    }
    #[test] fn an_older_serial_is_a_replay() {
        let (_, st, why) = state(&input(lease(2), json!({"pinned_serial": 3})));
        assert!(st == "refused" && why.contains("replay"));
        assert_eq!(state(&input(lease(3), json!({"pinned_serial": 3}))).1, "live", "the same serial is fine (re-reading it)");
    }
    #[test] fn another_device_or_a_changed_lease_is_refused() {
        let mut i: Value = serde_json::from_str(&input(lease(3), json!({}))).unwrap(); i["device_id"] = json!("ffffffff-d9cb-469f-a165-70867728950e");
        assert_eq!(state(&i.to_string()).1, "refused");
        let mut d = lease(3); d["expires_ms"] = json!(1_700_000_900_001i64); assert_eq!(state(&input(d, json!({}))).1, "refused");
        let mut d = lease(3); d["ttl_s"] = json!(7200); d["expires_ms"] = json!(1_700_007_200_000i64); assert_eq!(state(&input(d, json!({}))).1, "refused", "ttl cap");
        let mut d = lease(3); d["type"] = json!("something-else"); assert_eq!(state(&input(d, json!({}))).1, "refused");
        let mut d = lease(3); d["extra"] = json!(1); assert_eq!(state(&input(d, json!({}))).1, "refused", "no extra fields");
        let mut d = lease(3); d["half"] = json!("short"); assert_eq!(state(&input(d, json!({}))).1, "refused");
        for bad in ["", "{}", "[]", "not json", r#"{"data":1}"#] { assert_eq!(state(bad).1, "refused", "{bad}"); }
    }
    #[test] fn missing_clock_readings_are_never_live() {
        let mut i: Value = serde_json::from_str(&input(lease(3), json!({}))).unwrap(); i.as_object_mut().unwrap().remove("now_mono_ms");
        assert_eq!(state(&i.to_string()).1, "refused");
        assert_eq!(state(&input(lease(3), json!({"now_mono_ms": 5_000}))).1, "refused", "monotonic clock going backwards");
    }
}
