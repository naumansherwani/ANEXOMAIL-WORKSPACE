//! D2b-5 - changing the Devices & Sessions policy (location lock, spoof action, caps, idle/absolute limits) needs a FRESH passkey touch that signs the EXACT change.
//! Plan: docs/claude/G-MIX-D2B5-PLAN-11NOV.md (loopholes P1-P14). SQL: E157 (`founder_session_policy_digest` / `founder_session_policy_apply`) on E118 grants.
//!
//!   begin  {fields, reason}      -> Rust validates the shape, adds the SERVER-measured facts (live session id, country), SQL does a dry run and returns the canonical params + hash;
//!                                   the payload is stored in the ceremony state (server side), the WebAuthn challenge IS the hash; the answer carries a plain-words summary.
//!   finish {ceremony, credential} -> ONLY the assertion comes back. The payload cannot be changed between touch and apply. The grant is issued and consumed in this one request and never leaves the server.
//! Pure functions (`fields_of`, `state_ok`, `summary`) are tested without a network; the SQL half has its own rolled-back selftest (E157).
use crate::passkey::{self as pk, refuse, sql_err, sbx, body_json, txt, st_s, is_uuid};
use crate::S;
use axum::{extract::State, http::{HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::{json, Value};

/// The policy fields the browser may propose. Types and ranges are checked here AND again in SQL (set_v2); unknown keys are ignored, never forwarded.
pub fn fields_of(b: &Value, current_country: Option<&str>) -> Result<Value, &'static str> {
    let s = |k: &str, allowed: &[&str]| -> Result<String, &'static str> { b.get(k).and_then(|x| x.as_str()).filter(|v| allowed.contains(v)).map(String::from).ok_or("a field is missing or has the wrong shape") };
    let n = |k: &str, lo: i64, hi: i64| -> Result<i64, &'static str> { b.get(k).and_then(|x| x.as_i64()).filter(|v| (lo..=hi).contains(v)).ok_or("a field is missing or has the wrong shape") };
    let geo = s("geo_mode", &["off", "observe", "enforce"])?;
    let mut countries: Vec<String> = Vec::new();
    match b.get("countries") {
        Some(Value::Array(a)) if a.len() <= 40 => for c in a {
            let c = c.as_str().ok_or("a field is missing or has the wrong shape")?;
            if c.len() != 2 || !c.bytes().all(|x| x.is_ascii_uppercase()) { return Err("a country must be two capital letters"); }
            if !countries.iter().any(|x| x == c) { countries.push(c.to_string()); }
        },
        _ => return Err("a field is missing or has the wrong shape"),
    }
    countries.sort();
    let reason = b.get("reason").and_then(|x| x.as_str()).map(str::trim).filter(|r| (8..=200).contains(&r.chars().count()) && !r.chars().any(|c| c.is_control() || c == '<' || c == '>')).ok_or("say why (8 to 200 characters, no < >)")?;
    let (idle, abs) = (n("idle_s", 300, 2_592_000)?, n("absolute_s", 3600, 7_776_000)?);
    if abs < idle { return Err("the absolute limit cannot be shorter than the idle limit"); }
    Ok(json!({"geo_mode": geo, "countries": countries, "spoof_action": s("spoof_action", &["alert", "block"])?, "stale_after_s": n("stale_after_s", 30, 86400)?, "max_live": n("max_live", 2, 200)?,
              "fail_limit": n("fail_limit", 3, 100)?, "flap_limit": n("flap_limit", 2, 50)?, "flap_action": s("flap_action", &["alert", "revoke"])?, "idle_s": idle, "absolute_s": abs,
              "current_country": current_country, "reason": reason}))
}

fn args_digest(f: &Value, uid: &str, sid: &str, nonce: &str) -> Value {
    json!({"p_uid": uid, "p_sid_hash": sid, "p_geo_mode": f["geo_mode"], "p_countries": f["countries"], "p_spoof_action": f["spoof_action"], "p_stale_after_s": f["stale_after_s"], "p_max_live": f["max_live"],
           "p_fail_limit": f["fail_limit"], "p_flap_limit": f["flap_limit"], "p_flap_action": f["flap_action"], "p_idle_s": f["idle_s"], "p_absolute_s": f["absolute_s"],
           "p_current_country": f["current_country"], "p_reason": f["reason"], "p_nonce": nonce})
}
fn args_apply(f: &Value, uid: &str, did: &str, sid: &str, grant: &str, nonce: &str) -> Value {
    json!({"p_uid": uid, "p_device": did, "p_sid_hash": sid, "p_grant": grant, "p_nonce": nonce, "p_geo_mode": f["geo_mode"], "p_countries": f["countries"], "p_spoof_action": f["spoof_action"],
           "p_stale_after_s": f["stale_after_s"], "p_max_live": f["max_live"], "p_fail_limit": f["fail_limit"], "p_flap_limit": f["flap_limit"], "p_flap_action": f["flap_action"],
           "p_idle_s": f["idle_s"], "p_absolute_s": f["absolute_s"], "p_current_country": f["current_country"], "p_reason": f["reason"]})
}

/// What a ceremony state must satisfy before its assertion is even looked at (P3, P4, P11): right purpose, same device, same live session, same country as at begin.
pub fn state_ok(state: &Value, did: &str, sid: &str, country_now: Option<&str>) -> Result<(), &'static str> {
    if state["purpose"] != "session_policy" { return Err("this ceremony is not a policy change"); }
    if state["device"].as_str() != Some(did) { return Err("this ceremony belongs to another device"); }
    if state["sid"].as_str() != Some(sid) { return Err("this ceremony belongs to another session"); }
    if state["fields"]["current_country"].as_str() != country_now { return Err("your network changed while you were confirming: start again"); }
    Ok(())
}

/// The sentence list the founder reads before touching the key (computed from the server's own dry run, never from the browser).
pub fn summary(cur: &Value, next: &Value) -> Vec<Value> {
    let mut out = Vec::new();
    for (k, label) in [("geo_mode", "Location lock"), ("countries", "Allowed countries"), ("spoof_action", "When a browser lies about itself"), ("max_live", "Live sessions allowed"), ("fail_limit", "Failed signatures before closing"),
                       ("flap_limit", "Network changes before action"), ("flap_action", "When the network keeps changing"), ("idle_s", "Idle limit (seconds)"), ("absolute_s", "Absolute limit (seconds)"), ("stale_after_s", "Quiet before a session counts as stale (seconds)")] {
        if cur[k] != next[k] { out.push(json!({"field": k, "label": label, "from": cur[k], "to": next[k]})); }
    }
    out
}

/// POST /founder/v1/sessions/policy/begin
pub async fn begin_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let path = "/founder/v1/sessions/policy/begin";
    let (uid, _e, did) = match pk::ctx(&st, &h, path, &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    let Some(sid) = crate::cur_sid_pub(&st, &h) else { return refuse(StatusCode::BAD_REQUEST, "this token has no session; sign in again") };
    let b = match body_json(&body) { Ok(b) => b, Err(r) => return r };
    let country = crate::sessions::facts(&h, &st.hmac_key).country;
    let f = match fields_of(&b, country.as_deref()) { Ok(f) => f, Err(e) => return refuse(StatusCode::BAD_REQUEST, e) };
    let (pol, origin) = match tokio::join!(pk::policy(sb), pk::origin_of(sb, &h)) { (Ok(p), Ok(o)) => (p, o), (Err(r), _) | (_, Err(r)) => return r };
    let act = pk::active(sb, &uid).await;
    let ids: Vec<String> = act.iter().filter_map(|a| a["credential_id"].as_str().map(String::from)).collect();
    if ids.is_empty() { return refuse(StatusCode::CONFLICT, "no active passkey: register one first"); }
    let nonce = match pk::random_challenge() { Ok(c) => c, Err(e) => return refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    let d = match sb.rpc_msg("founder_session_policy_digest", args_digest(&f, &uid, &sid, &nonce)).await { Ok(d) => d, Err(e) => return sql_err(e) };
    if d["ok"] != true {
        let code = d["error"].as_str().unwrap_or("refused");
        let status = if code == "too_many_changes" { StatusCode::TOO_MANY_REQUESTS } else { StatusCode::UNPROCESSABLE_ENTITY };
        return (status, axum::Json(json!({"error": code, "note": refusal_text(code)}))).into_response();
    }
    let Some(hash) = d["hash"].as_str() else { return refuse(StatusCode::BAD_GATEWAY, "policy digest unavailable - run the E157 SQL step") };
    let challenge = match pk::challenge_of_action_hash(hash) { Ok(c) => c, Err(e) => return refuse(StatusCode::BAD_GATEWAY, e) };
    let secs = pol["challenge_secs"].as_u64().unwrap_or(120).clamp(30, 300);
    let state = json!({"purpose": "session_policy", "origin": origin, "device": did, "sid": sid, "challenge": challenge, "rp_id": pol["rp_id"], "hash": hash, "nonce": nonce, "fields": f, "params": d["params"]});
    let Some(Value::String(cid)) = sb.rpc("founder_passkey_ceremony_begin", json!({"p_uid": uid, "p_kind": "authenticate", "p_state": state})).await else { return refuse(StatusCode::TOO_MANY_REQUESTS, "too many open ceremonies") };
    let opts = pk::get_options(&pol, &challenge, &ids, secs * 1000);
    crate::signed(&st, json!({"ceremony": cid, "options": opts, "hash": hash, "expires_in_s": secs, "changes": summary(&d["current"], &d["next"]), "reason": f["reason"], "action": "session.policy", "target": "policy", "params": d["params"], "nonce": nonce}))
}

pub fn refusal_text(code: &str) -> &'static str {
    match code {
        "would_lock_you_out" => "Refused: the location lock would lock you out (your current country is not in the allowed list).",
        "enforce_needs_a_country" => "Refused: enforcing the location lock needs at least one allowed country.",
        "no_change" => "Nothing to change: these are already the settings.",
        "too_many_changes" => "Too many policy changes in the last hour (5 allowed). Wait and try again.",
        "session_not_live" => "This session is no longer live. Sign in again.",
        "shape" => "One of the values is outside its allowed range.",
        _ => "Refused.",
    }
}

/// POST /founder/v1/sessions/policy/finish  {ceremony, credential}
pub async fn finish_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let path = "/founder/v1/sessions/policy/finish";
    let (uid, _e, did) = match pk::ctx(&st, &h, path, &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match sbx(&st) { Ok(s) => s, Err(r) => return r };
    let Some(sid) = crate::cur_sid_pub(&st, &h) else { return refuse(StatusCode::BAD_REQUEST, "this token has no session; sign in again") };
    let b = match body_json(&body) { Ok(b) => b, Err(r) => return r };
    let cred = &b["credential"];
    let cer = b["ceremony"].as_str().unwrap_or("");
    if !is_uuid(cer) || !cred.is_object() { return refuse(StatusCode::BAD_REQUEST, "bad ceremony or credential"); }
    // single use: the ceremony is consumed the moment it is looked at, whatever happens next (P1)
    let state = match pk::ceremony_take(sb, &uid, cer, "authenticate").await { Ok(s) => s, Err(r) => return r };
    let country = crate::sessions::facts(&h, &st.hmac_key).country;
    if let Err(e) = state_ok(&state, &did, &sid, country.as_deref()) { return refuse(StatusCode::FORBIDDEN, e); }
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
    let granted = match sb.rpc_msg("founder_stepup_issue", json!({"p_uid": uid, "p_device": did, "p_credential_id": cid, "p_action": "session.policy", "p_target": "policy", "p_params": params, "p_nonce": nonce})).await { Ok(g) => g, Err(e) => return sql_err(e) };
    let Some(grant) = granted["grant"].as_str().filter(|g| is_uuid(g)) else { return refuse(StatusCode::BAD_GATEWAY, "no grant") };
    let r = match sb.rpc_msg("founder_session_policy_apply", args_apply(&f, &uid, &did, &sid, grant, &nonce)).await { Ok(r) => r, Err(e) => return sql_err(e) };
    crate::sessions::cache_clear();      // P13: every session is re-checked against the new policy on its next request
    crate::signed(&st, json!({"ok": true, "policy": r["policy"], "was": r["was"], "hardware": verdict["device_bound"]}))
}

#[cfg(test)]
mod tests {
    use super::*;
    fn good() -> Value { json!({"geo_mode": "observe", "countries": ["US", "PK", "PK"], "spoof_action": "alert", "stale_after_s": 900, "max_live": 15, "fail_limit": 10, "flap_limit": 4, "flap_action": "alert", "idle_s": 86400, "absolute_s": 604800, "reason": "  trying observe mode  ", "uid": "attacker", "p_uid": "attacker"}) }
    #[test]
    fn fields_are_checked_deduped_sorted_and_unknown_keys_dropped() {
        let f = fields_of(&good(), Some("PK")).unwrap();
        assert_eq!(f["countries"], json!(["PK", "US"]));
        assert_eq!(f["reason"], "trying observe mode");
        assert!(f.get("uid").is_none() && f.get("p_uid").is_none(), "the body can never smuggle a uid");
        assert_eq!(f["current_country"], "PK");
        assert_eq!(fields_of(&good(), None).unwrap()["current_country"], Value::Null);
        for (k, v) in [("geo_mode", json!("on")), ("spoof_action", json!("ignore")), ("max_live", json!(1)), ("max_live", json!(201)), ("fail_limit", json!(2)), ("flap_limit", json!("4")), ("flap_action", json!("kill")),
                       ("idle_s", json!(10)), ("stale_after_s", json!(29)), ("countries", json!("PK")), ("countries", json!(["pk"])), ("countries", json!(["PAK"])), ("reason", json!("short")), ("reason", json!("has <b> tag here")), ("reason", json!("line\nbreak here ok"))] {
            let mut b = good(); b[k] = v.clone();
            assert!(fields_of(&b, None).is_err(), "{k}={v} must be refused");
        }
        let mut b = good(); b["idle_s"] = json!(604801); b["absolute_s"] = json!(3600); assert!(fields_of(&b, None).is_err(), "absolute below idle");
        let mut b = good(); b.as_object_mut().unwrap().remove("reason"); assert!(fields_of(&b, None).is_err());
        let mut b = good(); b["countries"] = json!((0..41).map(|i| format!("{}{}", (b'A' + (i / 26) as u8) as char, (b'A' + (i % 26) as u8) as char)).collect::<Vec<_>>()); assert!(fields_of(&b, None).is_err(), "more than 40 countries");
    }
    #[test]
    fn a_ceremony_state_binds_purpose_device_session_and_country() {
        let st = json!({"purpose": "session_policy", "device": "de01", "sid": "s1", "fields": {"current_country": "PK"}});
        assert_eq!(state_ok(&st, "de01", "s1", Some("PK")), Ok(()));
        assert!(state_ok(&json!({"purpose": "action", "device": "de01", "sid": "s1", "fields": {"current_country": "PK"}}), "de01", "s1", Some("PK")).is_err(), "another purpose");
        assert!(state_ok(&st, "de02", "s1", Some("PK")).is_err(), "another device");
        assert!(state_ok(&st, "de01", "s2", Some("PK")).is_err(), "another session");
        assert!(state_ok(&st, "de01", "s1", Some("US")).is_err(), "network moved country");
        assert!(state_ok(&st, "de01", "s1", None).is_err(), "country lost");
        let none = json!({"purpose": "session_policy", "device": "de01", "sid": "s1", "fields": {"current_country": null}});
        assert_eq!(state_ok(&none, "de01", "s1", None), Ok(()), "unknown country at begin and at finish is consistent");
    }
    #[test]
    fn the_sql_arguments_carry_only_named_fields_and_the_token_identity() {
        let f = fields_of(&good(), Some("PK")).unwrap();
        let a = args_apply(&f, "uid-1", "dev-1", &"a".repeat(64), "grant-1", "nonce-1");
        assert_eq!((a["p_uid"].as_str(), a["p_device"].as_str(), a["p_sid_hash"].as_str().map(str::len)), (Some("uid-1"), Some("dev-1"), Some(64)));
        assert_eq!(a["p_countries"], json!(["PK", "US"]));
        assert_eq!(a.as_object().unwrap().len(), 17);
        let d = args_digest(&f, "uid-1", &"a".repeat(64), "nonce-1");
        assert_eq!(d.as_object().unwrap().len(), 15);
        assert!(!d.to_string().contains("attacker"));
    }
    #[test]
    fn the_summary_lists_only_what_changes() {
        let cur = json!({"geo_mode": "off", "countries": [], "spoof_action": "alert", "max_live": 20, "fail_limit": 10, "flap_limit": 4, "flap_action": "alert", "idle_s": 86400, "absolute_s": 604800, "stale_after_s": 900});
        let mut next = cur.clone(); next["geo_mode"] = json!("enforce"); next["countries"] = json!(["PK"]);
        let s = summary(&cur, &next);
        assert_eq!(s.len(), 2);
        assert_eq!((s[0]["field"].as_str(), s[0]["to"].as_str()), (Some("geo_mode"), Some("enforce")));
        assert!(summary(&cur, &cur).is_empty());
    }
    #[test]
    fn every_refusal_code_has_plain_words() {
        for c in ["would_lock_you_out", "enforce_needs_a_country", "no_change", "too_many_changes", "session_not_live", "shape"] { assert_ne!(refusal_text(c), "Refused.", "{c}"); }
        let _ = txt(&json!({}), "x", 1);
    }
}
