//! QC1c F8-5 - loosening "send only if TLS" for ONE named domain needs a FRESH passkey touch that SIGNS the exact change (mailbox, domain, hours, reason, nonce).
//! Plan: docs/claude/QC1C-F8-5-RESEARCH-PLAN-19NOV.md. SQL: E192 (digest / apply / tighten / heal / loose / state) on E191 (the ratchet) and E118 (T2 grants). Same shape as policy_step.rs (D2b-5):
//!   begin  {box, domain, hours, reason} -> Rust checks the shape, SQL does a dry run and returns the canonical params + hash; the payload is kept server side, the WebAuthn challenge IS the hash.
//!   finish {ceremony, credential}       -> ONLY the assertion comes back. The grant is issued and consumed in this one request and never leaves the server (SQL consume + write = one transaction).
//!   tighten {box, domain}               -> no touch (tightening is always safe), ledgered.   GET policy?box= -> the screen's facts (active domains, left today, ledger lines, chain check).
//! Pure functions (`fields_of`, `valid_domain`, `state_ok`, `refusal_text`) are tested without a network.
use crate::passkey::{self as pk, refuse, sql_err, sbx, body_json, st_s, is_uuid};
use crate::S;
use axum::{extract::State, http::{HeaderMap, StatusCode, Uri}, response::{IntoResponse, Response}};
use serde_json::{json, Value};

/// Same rule as the SQL check: lower-case host name, 2+ labels, labels 1-63 of [a-z0-9-] not starting or ending with '-', alphabetic last label of 2-63, 3-253 characters in all.
pub fn valid_domain(d: &str) -> bool {
    if d.len() < 3 || d.len() > 253 { return false; }
    let labels: Vec<&str> = d.split('.').collect();
    if labels.len() < 2 { return false; }
    for (i, l) in labels.iter().enumerate() {
        if l.is_empty() || l.len() > 63 || !l.bytes().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'-') || l.starts_with('-') || l.ends_with('-') { return false; }
        if i == labels.len() - 1 && (l.len() < 2 || !l.bytes().all(|c| c.is_ascii_lowercase())) { return false; }
    }
    true
}

/// What the browser may propose. Unknown keys are ignored, never forwarded; the body can never smuggle a uid.
pub fn fields_of(b: &Value) -> Result<Value, &'static str> {
    let bx = b.get("box").and_then(|x| x.as_str()).filter(|s| is_uuid(s)).ok_or("a field is missing or has the wrong shape")?;
    let domain = b.get("domain").and_then(|x| x.as_str()).map(|s| s.trim().to_ascii_lowercase()).filter(|d| valid_domain(d)).ok_or("write a real domain name, for example partner.com")?;
    let hours = b.get("hours").and_then(|x| x.as_i64()).filter(|h| (1..=24).contains(h)).ok_or("choose 1 to 24 hours")?;
    let reason = b.get("reason").and_then(|x| x.as_str()).map(str::trim).filter(|r| (8..=200).contains(&r.chars().count()) && !r.chars().any(|c| c.is_control() || c == '<' || c == '>')).ok_or("say why (8 to 200 characters, no < >)")?;
    Ok(json!({"box": bx, "domain": domain, "hours": hours, "reason": reason}))
}

/// A ceremony state must be this purpose, this device, and the same mailbox/domain it was begun for.
pub fn state_ok(state: &Value, did: &str) -> Result<(), &'static str> {
    if state["purpose"] != "tls_loosen" { return Err("this ceremony is not a TLS change"); }
    if state["device"].as_str() != Some(did) { return Err("this ceremony belongs to another device"); }
    if state["fields"]["domain"].as_str().map_or(true, |d| !valid_domain(d)) { return Err("this ceremony is damaged: start again"); }
    Ok(())
}

pub fn refusal_text(code: &str) -> &'static str {
    match code {
        "no_mailbox" => "No such mailbox.",
        "domain" => "That is not a valid domain name.",
        "hours" => "Choose between 1 and 24 hours.",
        "reason" => "Write a reason of 8 to 200 characters (no < >).",
        "already" => "That domain is already allowed for now. Make it strict first if you want to start again.",
        "limit" => "You already allowed plain delivery 3 times in the last 24 hours. Strict stays on until one of them is older than a day.",
        _ => "Refused.",
    }
}

/// POST /founder/v1/mail/tls/loosen/begin
pub async fn begin_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let path = "/founder/v1/mail/tls/loosen/begin";
    let (uid, _e, did) = match pk::ctx(&st, &h, path, &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    let b = match body_json(&body) { Ok(b) => b, Err(r) => return r };
    let f = match fields_of(&b) { Ok(f) => f, Err(e) => return refuse(StatusCode::BAD_REQUEST, e) };
    let (pol, origin) = match tokio::join!(pk::policy(sb), pk::origin_of(sb, &h)) { (Ok(p), Ok(o)) => (p, o), (Err(r), _) | (_, Err(r)) => return r };
    let act = pk::active(sb, &uid).await;
    let ids: Vec<String> = act.iter().filter_map(|a| a["credential_id"].as_str().map(String::from)).collect();
    if ids.is_empty() { return refuse(StatusCode::CONFLICT, "no active passkey: register one first"); }
    let nonce = match pk::random_challenge() { Ok(c) => c, Err(e) => return refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    let d = match sb.rpc_msg("fmail_tls_loosen_digest192", json!({"p_uid": uid, "p_mailbox": f["box"], "p_domain": f["domain"], "p_hours": f["hours"], "p_reason": f["reason"], "p_nonce": nonce})).await { Ok(d) => d, Err(e) => return sql_err(e) };
    if d["ok"] != true {
        let code = d["error"].as_str().unwrap_or("refused");
        let status = if code == "limit" { StatusCode::TOO_MANY_REQUESTS } else { StatusCode::UNPROCESSABLE_ENTITY };
        return (status, axum::Json(json!({"error": code, "note": refusal_text(code)}))).into_response();
    }
    let Some(hash) = d["hash"].as_str() else { return refuse(StatusCode::BAD_GATEWAY, "digest unavailable - run the E192 SQL step") };
    let challenge = match pk::challenge_of_action_hash(hash) { Ok(c) => c, Err(e) => return refuse(StatusCode::BAD_GATEWAY, e) };
    let secs = pol["challenge_secs"].as_u64().unwrap_or(120).clamp(30, 300);
    let state = json!({"purpose": "tls_loosen", "origin": origin, "device": did, "challenge": challenge, "rp_id": pol["rp_id"], "hash": hash, "nonce": nonce, "fields": f, "params": d["params"]});
    let Some(Value::String(cid)) = sb.rpc("founder_passkey_ceremony_begin", json!({"p_uid": uid, "p_kind": "authenticate", "p_state": state})).await else { return refuse(StatusCode::TOO_MANY_REQUESTS, "too many open ceremonies") };
    let opts = pk::get_options(&pol, &challenge, &ids, secs * 1000);
    crate::signed(&st, json!({"ceremony": cid, "options": opts, "hash": hash, "expires_in_s": secs, "domain": f["domain"], "hours": f["hours"], "reason": f["reason"], "left_today": d["left_today"],
                              "action": "mail.tls.loosen", "target": f["box"], "params": d["params"], "nonce": nonce}))
}

/// POST /founder/v1/mail/tls/loosen/finish {ceremony, credential}
pub async fn finish_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let path = "/founder/v1/mail/tls/loosen/finish";
    let (uid, _e, did) = match pk::ctx(&st, &h, path, &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    let b = match body_json(&body) { Ok(b) => b, Err(r) => return r };
    let cred = &b["credential"];
    let cer = b["ceremony"].as_str().unwrap_or("");
    if !is_uuid(cer) || !cred.is_object() { return refuse(StatusCode::BAD_REQUEST, "bad ceremony or credential"); }
    let state = match pk::ceremony_take(sb, &uid, cer, "authenticate").await { Ok(s) => s, Err(r) => return r };      // single use, whatever happens next
    if let Err(e) = state_ok(&state, &did) { return refuse(StatusCode::FORBIDDEN, e); }
    let (ch, origin, rp) = (st_s(&state, "challenge"), st_s(&state, "origin"), st_s(&state, "rp_id"));
    let cid = cred.get("id").and_then(|x| x.as_str()).unwrap_or("");
    let act = pk::active(sb, &uid).await;
    let Some(key) = act.iter().find(|a| a["credential_id"].as_str() == Some(cid)).map(|a| a["passkey"].clone()) else { return refuse(StatusCode::FORBIDDEN, "unknown or revoked passkey") };
    let asr = match pk::verify_assertion(cred, &key, &ch, &origin, &rp) {
        Ok(a) => a,
        Err(e) => { let _ = sb.rpc("founder_webauthn_fail", json!({"p_uid": uid, "p_credential_id": cid, "p_reason": e})).await; return refuse(StatusCode::FORBIDDEN, e); }
    };
    let verdict = match sb.rpc_msg("founder_webauthn_assert", json!({"p_uid": uid, "p_credential_id": asr.credential_id, "p_in": asr.facts})).await { Ok(v) => v, Err(e) => return sql_err(e) };
    if verdict["decision"] != "allow" {
        return (StatusCode::FORBIDDEN, axum::Json(json!({"error": if verdict["decision"] == "stepup" { "extra proof needed: use a hardware key" } else { "refused" }, "decision": verdict["decision"], "reasons": verdict["reasons"]}))).into_response();
    }
    let (nonce, params, f) = (st_s(&state, "nonce"), state["params"].clone(), state["fields"].clone());
    let granted = match sb.rpc_msg("founder_stepup_issue", json!({"p_uid": uid, "p_device": did, "p_credential_id": cid, "p_action": "mail.tls.loosen", "p_target": f["box"], "p_params": params, "p_nonce": nonce})).await { Ok(g) => g, Err(e) => return sql_err(e) };
    let Some(grant) = granted["grant"].as_str().filter(|g| is_uuid(g)) else { return refuse(StatusCode::BAD_GATEWAY, "no grant") };
    let r = match sb.rpc_msg("fmail_tls_loosen_apply192", json!({"p_uid": uid, "p_device": did, "p_mailbox": f["box"], "p_domain": f["domain"], "p_hours": f["hours"], "p_reason": f["reason"], "p_grant": grant, "p_nonce": nonce})).await { Ok(r) => r, Err(e) => return sql_err(e) };
    crate::signed(&st, json!({"ok": true, "domain": r["domain"], "loosened_until": r["loosened_until"], "hardware": verdict["device_bound"]}))
}

/// POST /founder/v1/mail/tls/tighten {box, domain}: make one domain strict again. Needs no touch (tightening is always safe).
pub async fn tighten_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let path = "/founder/v1/mail/tls/tighten";
    let (uid, _e, _d) = match pk::ctx(&st, &h, path, &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    let b = match body_json(&body) { Ok(b) => b, Err(r) => return r };
    let bx = b.get("box").and_then(|x| x.as_str()).filter(|s| is_uuid(s));
    let dm = b.get("domain").and_then(|x| x.as_str()).map(|s| s.trim().to_ascii_lowercase()).filter(|d| valid_domain(d));
    let (Some(bx), Some(dm)) = (bx, dm) else { return refuse(StatusCode::BAD_REQUEST, "box and a real domain are needed") };
    match sb.rpc_msg("fmail_tls_dom_tighten192", json!({"p_uid": uid, "p_mailbox": bx, "p_domain": dm})).await {
        Ok(v) if v["ok"] == true => crate::signed(&st, json!({"ok": true, "changed": v["changed"]})),
        Ok(v) => (StatusCode::UNPROCESSABLE_ENTITY, axum::Json(json!({"error": v["error"], "note": refusal_text(v["error"].as_str().unwrap_or(""))}))).into_response(),
        Err(e) => sql_err(e),
    }
}

/// GET /founder/v1/mail/tls/policy?box=<uuid>: what the Settings card shows. Read-only, signed.
pub async fn policy_get_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let b = match crate::fmail_ep::parse_box(uri.query()) { Ok(b) => b, Err(e) => return refuse(StatusCode::BAD_REQUEST, e) };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    match sb.rpc("fmail_tls_state192", json!({"p_uid": c.sub, "p_mailbox": b})).await {
        Some(v) if v["ok"] == true => crate::signed(&st, json!({"connected": true, "policy": v})),
        Some(v) if v["error"] == "no_mailbox" => refuse(StatusCode::NOT_FOUND, "no such mailbox"),
        _ => crate::signed(&st, json!({"connected": false, "note": "run the E192 SQL step (sql-run.sh)"})),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    const BX: &str = "0b9c1f3e-5a7d-4c2e-8f10-123456789abc";
    fn good() -> Value { json!({"box": BX, "domain": "  Partner.COM ", "hours": 4, "reason": "  partner server has no STARTTLS  ", "uid": "attacker", "p_uid": "attacker"}) }
    #[test]
    fn domains_follow_the_sql_rule() {
        for d in ["partner.com", "a-b.co.uk", "x1.example.org", "sub.partner.io"] { assert!(valid_domain(d), "{d}"); }
        for d in ["", "localhost", "a.b", "-a.com", "a-.com", "a..com", "partner.c0m", "partner.123", "has space.com", "UPPER.com", "partner.com.", "1.2.3.4", &format!("{}.com", "a".repeat(64))] { assert!(!valid_domain(d), "{d}"); }
        assert!(!valid_domain(&format!("{}.com", vec!["a".repeat(60); 5].join("."))), "over 253");
    }
    #[test]
    fn fields_are_checked_normalised_and_unknown_keys_dropped() {
        let f = fields_of(&good()).unwrap();
        assert_eq!((f["domain"].as_str(), f["hours"].as_i64(), f["reason"].as_str()), (Some("partner.com"), Some(4), Some("partner server has no STARTTLS")));
        assert!(f.get("uid").is_none() && f.get("p_uid").is_none(), "the body can never smuggle a uid");
        for (k, v) in [("box", json!("nope")), ("box", json!(7)), ("domain", json!("localhost")), ("domain", json!("a b.com")), ("hours", json!(0)), ("hours", json!(25)), ("hours", json!("4")), ("reason", json!("short")), ("reason", json!("has <b> tag here")), ("reason", json!("line\nbreak here ok"))] {
            let mut b = good(); b[k] = v.clone();
            assert!(fields_of(&b).is_err(), "{k}={v} must be refused");
        }
        for k in ["box", "domain", "hours", "reason"] { let mut b = good(); b.as_object_mut().unwrap().remove(k); assert!(fields_of(&b).is_err(), "missing {k}"); }
    }
    #[test]
    fn a_ceremony_state_binds_purpose_device_and_domain() {
        let st = json!({"purpose": "tls_loosen", "device": "de01", "fields": {"domain": "partner.com"}});
        assert_eq!(state_ok(&st, "de01"), Ok(()));
        assert!(state_ok(&json!({"purpose": "session_policy", "device": "de01", "fields": {"domain": "partner.com"}}), "de01").is_err(), "another purpose");
        assert!(state_ok(&st, "de02").is_err(), "another device");
        assert!(state_ok(&json!({"purpose": "tls_loosen", "device": "de01", "fields": {}}), "de01").is_err(), "no domain");
        assert!(state_ok(&json!({"purpose": "tls_loosen", "device": "de01", "fields": {"domain": "x"}}), "de01").is_err(), "bad domain");
    }
    #[test]
    fn every_refusal_code_has_plain_words() {
        for c in ["no_mailbox", "domain", "hours", "reason", "already", "limit"] { assert_ne!(refusal_text(c), "Refused.", "{c}"); }
    }
}
