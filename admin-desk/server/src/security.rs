// ANEXOMAIL ADMIN DESK security.rs (phase 1m-2, card B3 Security health of the Desk itself, 23 Nov 2026). Rust + Axum + Tokio. List: D6-CARDS-LIST-23NOV.md (S1..S7).
// ONE READ-ONLY door over the sealed router (Rule 52) and a live Desk session. desk_app has NO right on the series table; the SECURITY DEFINER door of SQL AD12 (fadm_security_health) answers ONLY a person who may list staff
// (staff.read on the Desk department), everyone else gets 403. AGGREGATE ONLY: a score, eight named checks (have / of), a 24-point series and a trend; never a name, e-mail, credential or key material.
// The answer shape is checked here too: a wrong shape is "Data unavailable", never half a score. No money. Desk-only.
use crate::bridge::owner;
use crate::door::rows;
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::Value;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

pub const CHECKS: [(&str, i64); 8] = [("every_staff_has_key", 20), ("two_keys_each", 20), ("keys_device_bound", 15), ("keys_allowed_model", 10), ("no_open_recovery", 10), ("no_stale_grants", 10), ("no_breakglass_active", 10), ("no_open_high_alert", 5)];
/// The shape the card relies on: the 8 checks in the fixed order with their fixed weights; a status of ok / fail / na; have <= of; a score that is null or 0..100; a 24-point series of null or 0..100; a trend word.
pub fn health_shape_ok(v: &Value) -> bool {
    let score_ok = |x: &Value| x.is_null() || x.as_i64().map(|n| (0..=100).contains(&n)).unwrap_or(false);
    let Some(c) = v.get("checks").and_then(|x| x.as_array()) else { return false };
    let checks_ok = c.len() == 8 && c.iter().zip(CHECKS).all(|(r, (key, w))| {
        let st = r.get("status").and_then(|x| x.as_str()).unwrap_or("");
        let have = r.get("have").and_then(|x| x.as_i64()).unwrap_or(-1); let of = r.get("of").and_then(|x| x.as_i64()).unwrap_or(-1);
        r.get("key").and_then(|x| x.as_str()) == Some(key) && r.get("weight").and_then(|x| x.as_i64()) == Some(w) && r.get("label").and_then(|x| x.as_str()).map(|s| !s.is_empty() && s.len() <= 120).unwrap_or(false)
            && ["ok", "fail", "na"].contains(&st) && have >= 0 && of >= 0 && have <= of && (st != "na" || of == 0) && (st != "ok" || have >= of && of > 0 || st == "ok" && of > 0 && have == of)
    });
    let n = |k: &str| v.get(k).and_then(|x| x.as_i64()).unwrap_or(-1);
    checks_ok && v.get("score").map(score_ok).unwrap_or(false) && n("ok") >= 0 && n("fail") >= 0 && n("na") >= 0 && n("ok") + n("fail") + n("na") == 8 && n("staff") >= 0
        && v.get("spark").and_then(|x| x.as_array()).map(|a| a.len() == 24 && a.iter().all(score_ok)).unwrap_or(false)
        && ["up", "steady", "down", "unknown"].contains(&v.get("trend").and_then(|x| x.as_str()).unwrap_or(""))
        && (v.get("score").map(|s| s.is_null()).unwrap_or(false) == (n("ok") + n("fail") == 0))
}

pub async fn health(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    match rows(&c, &format!("select desk.fadm_security_health('{o}'::uuid)::text")).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) {
            Some(j) => match serde_json::from_str::<Value>(j) { Ok(p) if health_shape_ok(&p) => out(StatusCode::OK, j.to_string()), _ => { eprintln!("desk security: wrong answer shape"); unavailable() } },
            None => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk security: db: {e}"); unavailable() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    fn check(i: usize, status: &str, have: i64, of: i64) -> Value { json!({"key":CHECKS[i].0,"label":"A check","weight":CHECKS[i].1,"status":status,"have":have,"of":of}) }
    fn good() -> Value { json!({"score":80,"ok":7,"fail":1,"na":0,"staff":4,"trend":"steady","spark":[null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,80,80],
        "checks":[check(0,"ok",4,4),check(1,"fail",2,4),check(2,"ok",6,6),check(3,"ok",6,6),check(4,"ok",1,1),check(5,"ok",1,1),check(6,"ok",1,1),check(7,"ok",1,1)]}) }
    #[test] fn good_shape_passes() { assert!(health_shape_ok(&good())); }
    #[test] fn weights_sum_to_100() { assert_eq!(CHECKS.iter().map(|c| c.1).sum::<i64>(), 100); }
    #[test] fn refuses_wrong_shapes() {
        let mut v = good(); v["checks"].as_array_mut().unwrap().pop(); assert!(!health_shape_ok(&v), "seven checks");
        let mut v = good(); v["checks"][0]["key"] = json!("other"); assert!(!health_shape_ok(&v), "wrong key");
        let mut v = good(); v["checks"][1]["weight"] = json!(25); assert!(!health_shape_ok(&v), "wrong weight");
        let mut v = good(); v["checks"][1]["status"] = json!("maybe"); assert!(!health_shape_ok(&v), "unknown status");
        let mut v = good(); v["checks"][1]["have"] = json!(9); assert!(!health_shape_ok(&v), "have above of");
        let mut v = good(); v["checks"][1]["status"] = json!("na"); assert!(!health_shape_ok(&v), "na with a need");
        let mut v = good(); v["score"] = json!(101); assert!(!health_shape_ok(&v), "score above 100");
        let mut v = good(); v["ok"] = json!(6); assert!(!health_shape_ok(&v), "counts must add to 8");
        let mut v = good(); v["spark"] = json!([1, 2]); assert!(!health_shape_ok(&v), "short series");
        let mut v = good(); v["trend"] = json!("sideways"); assert!(!health_shape_ok(&v), "unknown trend");
        let mut v = good(); v["score"] = Value::Null; assert!(!health_shape_ok(&v), "no score while checks apply");
        assert!(!health_shape_ok(&json!({})) && !health_shape_ok(&json!(null)));
    }
    #[test] fn nobody_to_check_has_no_score_only_when_every_check_is_na() {
        let mut v = good(); v["score"] = Value::Null; v["ok"] = json!(0); v["fail"] = json!(0); v["na"] = json!(8);
        for i in 0..8 { v["checks"][i] = json!({"key":CHECKS[i].0,"label":"A check","weight":CHECKS[i].1,"status":"na","have":0,"of":0}); }
        assert!(health_shape_ok(&v));
    }
    #[test] fn no_personal_field_in_a_good_answer() { let t = good().to_string(); assert!(!t.contains("email") && !t.contains("cred") && !t.contains("aaguid") && !t.contains("name")); }
}
