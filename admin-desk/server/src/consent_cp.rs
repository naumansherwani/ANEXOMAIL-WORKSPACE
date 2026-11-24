// ANEXOMAIL ADMIN DESK consent_cp.rs (BL-46 B13 step Z4b-2, 24 Nov 2026): the Desk's CLIENT of the Control Plane consent door (audience desk-consent, HTTP/3, Rule 52). PURE building blocks, no door wired yet (Z4b-3 wires them).
// Three signed requests go out: push (a staff request goes DOWN to the customer's company), cancel (staff withdraw), poll (what did the customer answer). The answer must be signed by the Control Plane's own key, kind "consent", the same method,
// the same request id, fresh (15 s) and not older than the request; the shape is closed; a decision is read ONLY from a verified poll answer. Anything wrong = Reject::Unavailable (fail closed): a request then stays "requested", never approved.
// There is NO decide request here: the Desk cannot approve. It can only APPLY a verified customer decision (the Control Plane's decision_ref = the hash of its ledger line).
use crate::lookup::{ANS_DOMAIN, EXPIRY, FRESH, REQ_DOMAIN};
use crate::sign::{unhex, Signer};
use serde_json::{json, Value};

pub const AUD_CONSENT: &str = "desk-consent";
pub const CONSENT_PATH: &str = "/control/v1/consent";
pub const SCOPES: [&str; 3] = ["metadata", "headers", "content"];
pub const STATUSES: [&str; 6] = ["requested", "approved", "denied", "cancelled", "revoked", "expired"];

#[derive(Debug, PartialEq)]
pub enum Reject { Unavailable, Refused }

fn envelope(s: &Signer, body: Value) -> String {
    let body = body.to_string(); let sig = s.sign_raw(format!("{REQ_DOMAIN}\n{body}").as_bytes());
    json!({"kid": s.kid(), "body": body, "sig": sig}).to_string()
}
pub fn build_push(s: &Signer, rid: &str, employee: &str, consent: &str, company: &str, case_ref: &str, scope: &str, reason: &str, now: i64) -> String {
    envelope(s, json!({"aud": AUD_CONSENT, "method": "push", "request_id": rid, "employee_id": employee, "consent": consent, "company_ref": company, "case_ref": case_ref, "scope": scope, "reason": reason.trim(), "issued_at": now, "expires_at": now + EXPIRY}))
}
pub fn build_cancel(s: &Signer, rid: &str, employee: &str, consent: &str, now: i64) -> String {
    envelope(s, json!({"aud": AUD_CONSENT, "method": "cancel", "request_id": rid, "employee_id": employee, "consent": consent, "issued_at": now, "expires_at": now + EXPIRY}))
}
pub fn build_poll(s: &Signer, rid: &str, employee: &str, consents: &[String], now: i64) -> String {
    envelope(s, json!({"aud": AUD_CONSENT, "method": "poll", "request_id": rid, "employee_id": employee, "consents": consents, "issued_at": now, "expires_at": now + EXPIRY}))
}

/// Verify the Control Plane answer to ONE request; returns its `result`. Refused (the database said no) is its own outcome; every other fault is Unavailable.
pub fn accept(env: &str, cp_pub_hex: &str, request_id: &str, method: &str, issued: i64, now: i64) -> Result<Value, Reject> {
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};
    let e: Value = serde_json::from_str(env).map_err(|_| Reject::Unavailable)?;
    let body = e["body"].as_str().ok_or(Reject::Unavailable)?;
    let sig = unhex(e["sig"].as_str().ok_or(Reject::Unavailable)?).ok_or(Reject::Unavailable)?;
    let vk = unhex(cp_pub_hex).and_then(|b| <[u8; 32]>::try_from(b).ok()).and_then(|b| VerifyingKey::from_bytes(&b).ok()).ok_or(Reject::Unavailable)?;
    let sig = Signature::from_slice(&sig).map_err(|_| Reject::Unavailable)?;
    vk.verify(format!("{ANS_DOMAIN}\n{body}").as_bytes(), &sig).map_err(|_| Reject::Unavailable)?;
    let b: Value = serde_json::from_str(body).map_err(|_| Reject::Unavailable)?;
    if b["kind"].as_str() != Some("consent") || b["method"].as_str() != Some(method) || b["request_id"].as_str() != Some(request_id) { return Err(Reject::Unavailable); }
    let at = b["answered_at"].as_i64().ok_or(Reject::Unavailable)?;
    if at > now + 5 || now - at > FRESH || at < issued - 2 { return Err(Reject::Unavailable); }
    match b["refused"].as_bool() { Some(true) => return Err(Reject::Refused), Some(false) => {}, None => return Err(Reject::Unavailable) }
    let r = b["result"].clone(); if r.is_null() { return Err(Reject::Unavailable); }
    Ok(r)
}

fn uuid_ok(s: &str) -> bool { s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_digit() || (b'a'..=b'f').contains(&b) }) }
fn keys_are(v: &Value, want: &[&str]) -> bool { v.as_object().map(|m| m.len() == want.len() && want.iter().all(|k| m.contains_key(*k))).unwrap_or(false) }

/// A push / cancel result: exactly {consent, status}; the consent id must be the one asked about.
pub fn check_status(r: &Value, consent: &str) -> Result<String, Reject> {
    if !keys_are(r, &["consent", "status"]) || r["consent"].as_str() != Some(consent) { return Err(Reject::Unavailable); }
    r["status"].as_str().filter(|s| STATUSES.contains(s)).map(str::to_string).ok_or(Reject::Unavailable)
}

/// What the Desk may DO with one verified poll row. Decide carries the Control Plane's decision_ref (64 hex) which the Desk stores as the consent reference.
#[derive(Debug, PartialEq, Clone)]
pub enum Act { Wait, Approve { window_end: i64, decision_ref: String }, Deny { decision_ref: String }, Revoke { window_end: i64 }, Expire, Cancelled }

/// The poll result: an array of rows, each with exactly {consent, status, window_start, window_end, decision_ref}, only for the ids asked, no repeats, closed statuses, and a window only where a window can exist.
pub fn check_poll(r: &Value, asked: &[String]) -> Result<Vec<(String, Act)>, Reject> {
    let a = r.as_array().ok_or(Reject::Unavailable)?; let mut out: Vec<(String, Act)> = Vec::new();
    for row in a {
        if !keys_are(row, &["consent", "status", "window_start", "window_end", "decision_ref"]) { return Err(Reject::Unavailable); }
        let id = row["consent"].as_str().filter(|s| uuid_ok(s) && asked.iter().any(|x| x == s)).ok_or(Reject::Unavailable)?.to_string();
        if out.iter().any(|(i, _)| *i == id) { return Err(Reject::Unavailable); }
        let st = row["status"].as_str().filter(|s| STATUSES.contains(s)).ok_or(Reject::Unavailable)?;
        let (ws, we) = (row["window_start"].as_i64(), row["window_end"].as_i64());
        let dref = row["decision_ref"].as_str().filter(|d| d.len() == 64 && d.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))).map(str::to_string);
        let has_window = matches!(st, "approved" | "revoked" | "expired");
        if has_window != (ws.is_some() && we.is_some()) || (!has_window && (row["window_start"].as_i64().is_some() || row["window_end"].as_i64().is_some())) { return Err(Reject::Unavailable); }
        if let (Some(s), Some(e)) = (ws, we) { if e < s || e - s > 3600 { return Err(Reject::Unavailable); } }
        let act = match st {
            "requested" => Act::Wait,
            "approved" => Act::Approve { window_end: we.ok_or(Reject::Unavailable)?, decision_ref: dref.ok_or(Reject::Unavailable)? },
            "denied" => Act::Deny { decision_ref: dref.ok_or(Reject::Unavailable)? },
            "revoked" => Act::Revoke { window_end: we.ok_or(Reject::Unavailable)? },
            "expired" => Act::Expire,
            _ => Act::Cancelled,
        };
        out.push((id, act));
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*; use crate::sign::hex; use ed25519_dalek::{Signer as _, SigningKey};
    const U1: &str = "aaaaaaaa-0000-4000-8000-000000000001"; const U2: &str = "bbbbbbbb-0000-4000-8000-000000000002"; const RID: &str = "11111111-2222-4333-8444-555555555555";
    fn cp() -> (SigningKey, String) { let k = SigningKey::from_bytes(&[7u8; 32]); let p = hex(k.verifying_key().as_bytes()); (k, p) }
    fn ans(k: &SigningKey, rid: &str, method: &str, at: i64, result: Value, refused: bool) -> String {
        let body = json!({"kind": "consent", "method": method, "request_id": rid, "answered_at": at, "result": result, "refused": refused}).to_string();
        json!({"body": body, "sig": hex(&k.sign(format!("{ANS_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    fn dref() -> String { "ab".repeat(32) }
    #[test] fn the_three_requests_are_signed_bound_to_desk_consent_and_expire_in_60s() {
        let s = Signer::from_seed_hex(&"03".repeat(32)).unwrap();
        for (env, m) in [(build_push(&s, RID, "e1", U1, U2, "CASE-0001", "metadata", " customer says mail is missing since noon ", 1000), "push"), (build_cancel(&s, RID, "e1", U1, 1000), "cancel"), (build_poll(&s, RID, "e1", &[U1.to_string()], 1000), "poll")] {
            let e: Value = serde_json::from_str(&env).unwrap(); let b: Value = serde_json::from_str(e["body"].as_str().unwrap()).unwrap();
            assert_eq!((b["aud"].as_str(), b["method"].as_str(), b["expires_at"].as_i64().unwrap() - b["issued_at"].as_i64().unwrap()), (Some(AUD_CONSENT), Some(m), 60));
            assert!(b.get("decision").is_none() && b.get("approve").is_none(), "the Desk cannot send a decision");
        }
        let e: Value = serde_json::from_str(&build_push(&s, RID, "e1", U1, U2, "CASE-0001", "metadata", " padded reason that is long enough ", 1000)).unwrap(); assert_eq!(serde_json::from_str::<Value>(e["body"].as_str().unwrap()).unwrap()["reason"], "padded reason that is long enough");
    }
    #[test] fn a_good_answer_is_accepted_and_every_fault_fails_closed() {
        let (k, p) = cp(); let r = json!({"consent": U1, "status": "requested"});
        assert_eq!(accept(&ans(&k, RID, "push", 1010, r.clone(), false), &p, RID, "push", 1000, 1012).unwrap(), r);
        let bad = |e: String, m: &str, rid: &str, iss: i64, now: i64| accept(&e, &p, rid, m, iss, now);
        assert_eq!(bad(ans(&SigningKey::from_bytes(&[9u8; 32]), RID, "push", 1010, r.clone(), false), "push", RID, 1000, 1012), Err(Reject::Unavailable), "wrong key");
        assert_eq!(bad(ans(&k, RID, "cancel", 1010, r.clone(), false), "push", RID, 1000, 1012), Err(Reject::Unavailable), "wrong method");
        assert_eq!(bad(ans(&k, "other-id-0000", "push", 1010, r.clone(), false), "push", RID, 1000, 1012), Err(Reject::Unavailable), "wrong request id");
        assert_eq!(bad(ans(&k, RID, "push", 1010, r.clone(), false), "push", RID, 1000, 1030), Err(Reject::Unavailable), "stale (older than 15 s)");
        assert_eq!(bad(ans(&k, RID, "push", 990, r.clone(), false), "push", RID, 1000, 1005), Err(Reject::Unavailable), "older than the request it answers");
        assert_eq!(bad(ans(&k, RID, "push", 1100, r.clone(), false), "push", RID, 1000, 1012), Err(Reject::Unavailable), "from the future");
        assert_eq!(bad(ans(&k, RID, "push", 1010, Value::Null, false), "push", RID, 1000, 1012), Err(Reject::Unavailable), "no result");
        assert_eq!(bad(ans(&k, RID, "push", 1010, Value::Null, true), "push", RID, 1000, 1012), Err(Reject::Refused), "the database refused");
        assert_eq!(bad("not json".into(), "push", RID, 1000, 1012), Err(Reject::Unavailable));
        let census = json!({"body": json!({"kind": "census", "request_id": RID, "answered_at": 1010, "census": {}, "refused": false}).to_string(), "sig": "00"}).to_string(); assert_eq!(bad(census, "push", RID, 1000, 1012), Err(Reject::Unavailable));
    }
    #[test] fn push_and_cancel_results_have_one_closed_shape() {
        assert_eq!(check_status(&json!({"consent": U1, "status": "requested"}), U1).unwrap(), "requested");
        assert_eq!(check_status(&json!({"consent": U1, "status": "approved"}), U1).unwrap(), "approved");
        for v in [json!({"consent": U2, "status": "requested"}), json!({"consent": U1, "status": "maybe"}), json!({"consent": U1, "status": "requested", "x": 1}), json!({"consent": U1}), json!([1])] { assert_eq!(check_status(&v, U1), Err(Reject::Unavailable)); }
    }
    fn row(id: &str, st: &str, ws: Value, we: Value, dr: Value) -> Value { json!({"consent": id, "status": st, "window_start": ws, "window_end": we, "decision_ref": dr}) }
    #[test] fn a_poll_turns_into_exactly_the_acts_the_customer_decided() {
        let ids = vec![U1.to_string(), U2.to_string()];
        let r = json!([row(U1, "approved", json!(1000), json!(2800), json!(dref())), row(U2, "requested", Value::Null, Value::Null, Value::Null)]);
        assert_eq!(check_poll(&r, &ids).unwrap(), vec![(U1.to_string(), Act::Approve { window_end: 2800, decision_ref: dref() }), (U2.to_string(), Act::Wait)]);
        assert_eq!(check_poll(&json!([row(U1, "denied", Value::Null, Value::Null, json!(dref()))]), &ids).unwrap()[0].1, Act::Deny { decision_ref: dref() });
        assert_eq!(check_poll(&json!([row(U1, "revoked", json!(1000), json!(1500), json!(dref()))]), &ids).unwrap()[0].1, Act::Revoke { window_end: 1500 });
        assert_eq!(check_poll(&json!([row(U1, "expired", json!(1000), json!(2800), json!(dref()))]), &ids).unwrap()[0].1, Act::Expire);
        assert_eq!(check_poll(&json!([row(U1, "cancelled", Value::Null, Value::Null, Value::Null)]), &ids).unwrap()[0].1, Act::Cancelled);
        assert_eq!(check_poll(&json!([]), &ids).unwrap(), vec![]);
    }
    #[test] fn a_forged_or_odd_poll_never_approves() {
        let ids = vec![U1.to_string()];
        let no = |v: Value| assert_eq!(check_poll(&v, &ids), Err(Reject::Unavailable), "{v}");
        no(json!([row(U2, "approved", json!(1000), json!(2800), json!(dref()))]));                       // an id nobody asked about
        no(json!([row(U1, "approved", json!(1000), json!(2800), Value::Null)]));                         // approved without a decision reference
        no(json!([row(U1, "approved", json!(1000), json!(2800), json!("short"))]));                      // bad reference
        no(json!([row(U1, "approved", Value::Null, Value::Null, json!(dref()))]));                       // approved without a window
        no(json!([row(U1, "approved", json!(1000), json!(9000), json!(dref()))]));                       // window longer than 60 minutes
        no(json!([row(U1, "approved", json!(2800), json!(1000), json!(dref()))]));                       // window ends before it starts
        no(json!([row(U1, "requested", json!(1000), json!(2800), Value::Null)]));                        // a waiting request cannot carry a window
        no(json!([row(U1, "granted", Value::Null, Value::Null, Value::Null)]));                          // unknown status
        no(json!([row(U1, "requested", Value::Null, Value::Null, Value::Null), row(U1, "requested", Value::Null, Value::Null, Value::Null)])); // repeated id
        no(json!([{"consent": U1, "status": "requested", "window_start": null, "window_end": null, "decision_ref": null, "approve": true}])); // extra field
        no(json!({"consent": U1}));                                                                       // not an array
    }
}
