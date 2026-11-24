// ANEXOMAIL ADMIN DESK ledger.rs (phase 1m-L, card Ledger, 24 Nov 2026, his 08:34 order "Ledger card wire kero"). Rust + Axum + Tokio. SQL: AD27 (desk.fadm_ledger_board). List/contract: CURRENT.md block LEDGER CARD.
// ONE read-only door over the sealed router (Rule 52) and a live Desk session, built exactly like the security door. Order is fixed: 1) PostgreSQL AD27 checks the right (staff.read on the Desk department) and answers with kind + role + time only (never the detail, an e-mail or a name);
// a person without the right gets 403. 2) The answer is checked here too: closed key lists, the tail is newest first with consecutive-or-descending sequence numbers that never pass the newest one, at most 20 lines, a role from a closed word list,
// kinds are short dotted words, the window is never larger than the line count. A wrong shape = "Data unavailable", never half a ledger.
use crate::bridge::owner;
use crate::door::rows;
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::Value;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

const ROLES: [&str; 4] = ["owner", "agent", "system", "unknown"];
fn nat(v: &Value) -> Option<i64> { v.as_i64().filter(|x| *x >= 0) }
fn stamp(v: &Value) -> bool { v.as_str().map(|s| s.len() == 20 && s.ends_with('Z') && s.as_bytes()[10] == b'T').unwrap_or(false) }
fn kind_ok(v: &Value) -> bool { v.as_str().map(|s| !s.is_empty() && s.len() <= 60 && s.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'.' || b == b'_' || b == b'-')).unwrap_or(false) }
fn keys_are(v: &Value, keys: &[&str]) -> bool { v.as_object().map(|o| o.len() == keys.len() && keys.iter().all(|k| o.contains_key(*k))).unwrap_or(false) }

pub fn shape_ok(v: &Value) -> bool {
    if !keys_are(v, &["generated_at", "lines", "newest_seq", "newest_at", "window_lines", "chain_ok", "probe", "tail", "kinds_24h"]) { return false; }
    if !stamp(&v["generated_at"]) || !v["chain_ok"].is_boolean() { return false; }
    let (Some(lines), Some(window)) = (nat(&v["lines"]), nat(&v["window_lines"])) else { return false };
    if window > lines || window > 2000 { return false; }
    // a ledger always has its first line; an empty one is not a real answer
    if lines == 0 { return v["newest_seq"].is_null() && v["newest_at"].is_null() && v["tail"].as_array().map(|a| a.is_empty()).unwrap_or(false); }
    let Some(newest) = nat(&v["newest_seq"]) else { return false };
    if newest < lines || !stamp(&v["newest_at"]) { return false; }
    let p = &v["probe"];
    if !keys_are(p, &["ok", "at"]) { return false; }
    if p["ok"].is_null() != p["at"].is_null() || (!p["ok"].is_null() && (!p["ok"].is_boolean() || !stamp(&p["at"]))) { return false; }
    let Some(tail) = v["tail"].as_array() else { return false };
    if tail.is_empty() || tail.len() > 20 || (tail.len() as i64) > lines { return false; }
    let mut last = i64::MAX;
    for (i, l) in tail.iter().enumerate() {
        if !keys_are(l, &["seq", "at", "kind", "role"]) { return false; }
        let Some(seq) = nat(&l["seq"]) else { return false };
        if seq >= last || seq > newest || (i == 0 && seq != newest) { return false; }
        last = seq;
        if !stamp(&l["at"]) || !kind_ok(&l["kind"]) || !l["role"].as_str().map(|r| ROLES.contains(&r)).unwrap_or(false) { return false; }
    }
    let Some(kinds) = v["kinds_24h"].as_array() else { return false };
    if kinds.len() > 8 { return false; }
    let mut prev = i64::MAX;
    for k in kinds {
        if !keys_are(k, &["kind", "n"]) || !kind_ok(&k["kind"]) { return false; }
        let Some(n) = nat(&k["n"]) else { return false };
        if n < 1 || n > prev { return false; } prev = n;
    }
    true
}

/// POST /desk/v1/ledger/board  (empty body)
pub async fn board(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    match rows(&c, &format!("select desk.fadm_ledger_board('{o}'::uuid)::text")).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) {
            Some(j) => match serde_json::from_str::<Value>(j) { Ok(p) if shape_ok(&p) => out(StatusCode::OK, j.to_string()), _ => { eprintln!("desk ledger: wrong answer shape"); unavailable() } },
            None => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk ledger: db: {e}"); unavailable() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    fn good() -> Value {
        json!({"generated_at": "2026-11-24T04:00:00Z", "lines": 40, "newest_seq": 40, "newest_at": "2026-11-24T03:59:00Z", "window_lines": 40, "chain_ok": true,
          "probe": {"ok": true, "at": "2026-11-24T03:58:00Z"},
          "tail": [{"seq": 40, "at": "2026-11-24T03:59:00Z", "kind": "package.publish", "role": "owner"}, {"seq": 39, "at": "2026-11-24T03:58:00Z", "kind": "alert.act", "role": "agent"}],
          "kinds_24h": [{"kind": "package.publish", "n": 5}, {"kind": "alert.act", "n": 2}]})
    }
    #[test] fn good_shape_passes() { assert!(shape_ok(&good())); }
    #[test] fn a_probe_that_never_ran_is_a_real_answer() { let mut g = good(); g["probe"] = json!({"ok": null, "at": null}); assert!(shape_ok(&g)); g["probe"] = json!({"ok": true, "at": null}); assert!(!shape_ok(&g)); }
    #[test] fn a_broken_chain_is_still_shown_not_hidden() { let mut g = good(); g["chain_ok"] = json!(false); assert!(shape_ok(&g), "the card must be able to say the chain is broken"); }
    #[test] fn refuses_wrong_shapes() {
        let bad = |f: &dyn Fn(&mut Value)| { let mut v = good(); f(&mut v); assert!(!shape_ok(&v)); };
        bad(&|v| v["tail"][0]["seq"] = json!(39));
        bad(&|v| v["tail"][1]["seq"] = json!(41));
        bad(&|v| v["tail"][1]["seq"] = json!(40));
        bad(&|v| v["tail"][0]["role"] = json!("a@b.c"));
        bad(&|v| v["tail"][0]["kind"] = json!("Has Space"));
        bad(&|v| v["tail"][0]["detail"] = json!({"x": 1}));
        bad(&|v| v["window_lines"] = json!(41));
        bad(&|v| v["window_lines"] = json!(2001));
        bad(&|v| v["lines"] = json!(10));
        bad(&|v| v["kinds_24h"] = json!([{"kind": "a", "n": 1}, {"kind": "b", "n": 2}]));
        bad(&|v| v["kinds_24h"][0]["n"] = json!(0));
        bad(&|v| v["chain_ok"] = json!("yes"));
        bad(&|v| v["generated_at"] = json!("yesterday"));
        bad(&|v| { v.as_object_mut().unwrap().remove("probe"); });
        bad(&|v| v["email"] = json!("a@b.c"));
        assert!(!shape_ok(&json!(null)) && !shape_ok(&json!({})));
    }
    #[test] fn too_many_tail_lines_or_kinds_are_refused() {
        let mut v = good(); v["lines"] = json!(100); v["newest_seq"] = json!(100); v["window_lines"] = json!(100);
        v["tail"] = json!((0..21).map(|i| json!({"seq": 100 - i, "at": "2026-11-24T03:59:00Z", "kind": "alert.act", "role": "system"})).collect::<Vec<_>>());
        assert!(!shape_ok(&v), "21 tail lines");
        let mut w = good(); w["kinds_24h"] = json!((0..9).map(|i| json!({"kind": format!("k{i}"), "n": 9 - i})).collect::<Vec<_>>());
        assert!(!shape_ok(&w), "9 kinds");
    }
    #[test] fn no_personal_field_in_a_good_answer() { let t = good().to_string(); assert!(!t.contains('@') && !t.contains("detail") && !t.contains("email")); }
}
