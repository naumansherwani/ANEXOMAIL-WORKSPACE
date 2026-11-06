//! J8b: the dead-man VAULT LEASE signer (founder go 6 Nov 2026). SQL E143 decides (device approved, not revoked, rate limits, clock guard); this module only
//! (1) turns the SQL answer into one STRICTLY validated, domain-separated record that the normal Ed25519 envelope signs, (2) maps a refusal to an honest HTTP status,
//! (3) runs the sweep that logs leases which ran out on their own. Fail-closed: any answer that is not exactly right is NEVER signed (502), so a bad row cannot become a valid lease.
//! The browser kernel (J8c) checks: signature, `type`, `expires_ms`, and that the serial never goes backwards.
use serde_json::{json, Value};

pub const TYPE: &str = "vault-lease@1";
pub const TTL_MIN: i64 = 60;
pub const TTL_MAX: i64 = 3600;

fn int(v: &Value, k: &str) -> Option<i64> { v.get(k).and_then(Value::as_i64) }
fn hex_n(s: &str, n: usize) -> bool { s.len() == n && s.bytes().all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase()) }
fn uuid_ok(s: &str) -> bool { s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_hexdigit() && !b.is_ascii_uppercase() }) }

/// The record that gets signed. None when the SQL answer is anything but a perfectly formed, internally consistent lease.
pub fn lease_data(r: &Value, expect_device: &str) -> Option<Value> {
    if r.get("ok").and_then(Value::as_bool) != Some(true) { return None; }
    let device = r.get("device_id")?.as_str()?;
    let nonce = r.get("nonce")?.as_str()?;
    let (serial, issued, expires, ttl) = (int(r, "serial")?, int(r, "issued_ms")?, int(r, "expires_ms")?, int(r, "ttl_s")?);
    if !uuid_ok(device) || device != expect_device.to_ascii_lowercase() || !hex_n(nonce, 32) { return None; }
    if serial < 1 || issued <= 0 || !(TTL_MIN..=TTL_MAX).contains(&ttl) || expires != issued.checked_add(ttl.checked_mul(1000)?)? { return None; }
    Some(json!({"type": TYPE, "device_id": device, "serial": serial, "issued_ms": issued, "expires_ms": expires, "ttl_s": ttl, "nonce": nonce}))
}

/// Refusal reason (from E143) to HTTP status. Unknown reasons are a server fault, never a silent 200.
pub fn refusal_status(why: &str) -> u16 {
    match why { "revoked" | "not_approved" | "not_your_device" | "unknown_device" => 403, "too_fast" | "too_many" => 429, "clock_back" => 409, _ => 502 }
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
    fn good() -> Value { json!({"ok": true, "device_id": D, "serial": 3, "issued_ms": 1_700_000_000_000i64, "expires_ms": 1_700_000_900_000i64, "ttl_s": 900, "nonce": "0123456789abcdef0123456789abcdef"}) }

    #[test] fn a_good_answer_becomes_one_typed_record() {
        let d = lease_data(&good(), D).unwrap();
        assert_eq!(d["type"], TYPE); assert_eq!(d["serial"], 3); assert_eq!(d["ttl_s"], 900);
        assert_eq!(d.as_object().unwrap().len(), 7, "exactly these fields, nothing the SQL added by accident");
    }
    #[test] fn the_device_in_the_answer_must_be_the_caller() {
        assert!(lease_data(&good(), "ffffffff-d9cb-469f-a165-70867728950e").is_none());
        assert!(lease_data(&good(), &D.to_ascii_uppercase()).is_some(), "case does not matter for the caller id");
    }
    #[test] fn not_ok_or_missing_fields_are_never_signed() {
        let mut r = good(); r["ok"] = json!(false); assert!(lease_data(&r, D).is_none());
        for k in ["device_id", "serial", "issued_ms", "expires_ms", "ttl_s", "nonce", "ok"] { let mut r = good(); r.as_object_mut().unwrap().remove(k); assert!(lease_data(&r, D).is_none(), "{k}"); }
        assert!(lease_data(&json!(null), D).is_none() && lease_data(&json!({}), D).is_none());
    }
    #[test] fn the_times_must_agree_exactly() {
        let mut r = good(); r["expires_ms"] = json!(1_700_000_900_001i64); assert!(lease_data(&r, D).is_none(), "expires must be issued + ttl");
        let mut r = good(); r["ttl_s"] = json!(59); r["expires_ms"] = json!(1_700_000_059_000i64); assert!(lease_data(&r, D).is_none(), "ttl floor");
        let mut r = good(); r["ttl_s"] = json!(3601); r["expires_ms"] = json!(1_700_003_601_000i64); assert!(lease_data(&r, D).is_none(), "ttl cap");
        let mut r = good(); r["serial"] = json!(0); assert!(lease_data(&r, D).is_none());
        let mut r = good(); r["issued_ms"] = json!(i64::MAX); r["expires_ms"] = json!(i64::MAX); assert!(lease_data(&r, D).is_none(), "no overflow");
    }
    #[test] fn nonce_and_ids_have_a_strict_shape() {
        for n in ["short", "0123456789ABCDEF0123456789ABCDEF", "0123456789abcdef0123456789abcdeg", "0123456789abcdef0123456789abcdef00"] { let mut r = good(); r["nonce"] = json!(n); assert!(lease_data(&r, D).is_none(), "{n}"); }
        let mut r = good(); r["device_id"] = json!("not-a-uuid"); assert!(lease_data(&r, "not-a-uuid").is_none());
    }
    #[test] fn refusals_map_to_honest_statuses() {
        for (w, s) in [("revoked", 403), ("not_approved", 403), ("not_your_device", 403), ("unknown_device", 403), ("too_fast", 429), ("too_many", 429), ("clock_back", 409), ("surprise", 502)] { assert_eq!(refusal_status(w), s, "{w}"); }
        assert!(refusal_text("revoked").contains("revoked") && !refusal_text("zzz").is_empty());
    }
}
