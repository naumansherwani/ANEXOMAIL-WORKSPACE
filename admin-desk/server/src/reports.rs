// ANEXOMAIL ADMIN DESK reports.rs (phase 1m-6, card B10 Reports, list BL-04 + BL-45, 23 Nov 2026). Rust + Axum + Tokio. List: D6-CARDS-LIST-23NOV.md (section B10, V1..V8), BILLIONAIRE-SETUP-LIST-23NOV.md.
// ONE read-only door over the sealed router (Rule 52) and a live Desk session. desk_app has NO right on the case tables; the SECURITY DEFINER door of SQL AD16 (fadm_reports) answers ONLY with the queues the person may read
// (fadm_queue_can); a person who may read none gets 403. Counts and minutes only: never a case reference, subject, company, address or person. The answer is checked here too: closed key lists, every part within its whole,
// and the numbers must agree with each other (per-queue backlog adds up to the backlog, today's end-of-day backlog equals the backlog now). A wrong shape or a sum that does not add up = "Data unavailable", never half a report.
use crate::bridge::owner;
use crate::door::rows;
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::Value;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

const QUEUES: [&str; 4] = ["general", "support", "movein", "billing"];
fn nat(v: &Value) -> Option<i64> { v.as_i64().filter(|x| *x >= 0) }
fn obj_ints(v: &Value, keys: &[&str]) -> Option<Vec<i64>> {
    let o = v.as_object()?; if o.len() != keys.len() { return None; }
    keys.iter().map(|k| o.get(*k).and_then(nat)).collect()
}
fn line(v: &Value) -> Option<Vec<i64>> { let a = v.as_array()?; if a.len() != 14 { return None; } a.iter().map(nat).collect() }
/// median / p90 minutes: both null when there is nothing to measure, both whole numbers (p90 never below the median) when there is.
fn pair_ok(v: &Value, n: i64) -> bool {
    let (m, p) = (&v["median_min"], &v["p90_min"]);
    if n == 0 { m.is_null() && p.is_null() } else { matches!((nat(m), nat(p)), (Some(a), Some(b)) if b >= a) }
}
pub fn shape_ok(v: &Value) -> bool {
    let Some(o) = v.as_object() else { return false };
    let keys = ["generated_at", "queues_counted", "queues_hidden", "backlog", "daily", "first_reply", "resolution", "reopened_30d", "priority", "queues"];
    if o.len() != keys.len() || keys.iter().any(|k| !o.contains_key(*k)) { return false; }
    if !v["generated_at"].as_str().map(|s| !s.is_empty() && s.len() <= 40).unwrap_or(false) { return false; }
    let (Some(counted), Some(hidden), Some(reopened)) = (nat(&v["queues_counted"]), nat(&v["queues_hidden"]), nat(&v["reopened_30d"])) else { return false };
    if counted < 1 || counted + hidden != 4 { return false; }
    let Some(bk) = obj_ints(&v["backlog"], &["new", "open", "waiting"]) else { return false };
    let backlog: i64 = bk.iter().sum();
    let d = &v["daily"]; let Some(dobj) = d.as_object() else { return false }; if dobj.len() != 3 { return false; }
    let (Some(_c), Some(_s), Some(db)) = (line(&d["created"]), line(&d["solved"]), line(&d["backlog"])) else { return false };
    if db[13] != backlog { return false; }
    let Some(fr) = obj_ints(&Value::Object(v["first_reply"].as_object().map(|m| m.iter().filter(|(k, _)| !k.ends_with("_min")).map(|(k, x)| (k.clone(), x.clone())).collect()).unwrap_or_default()), &["cases", "replied", "unanswered"]) else { return false };
    if v["first_reply"].as_object().map(|m| m.len() != 5).unwrap_or(true) || fr[1] + fr[2] != fr[0] || !pair_ok(&v["first_reply"], fr[1]) { return false; }
    let Some(rs) = nat(&v["resolution"]["solved"]) else { return false };
    if v["resolution"].as_object().map(|m| m.len() != 3).unwrap_or(true) || !pair_ok(&v["resolution"], rs) { return false; }
    let Some(pr) = obj_ints(&v["priority"], &["total", "in_time", "late", "waiting"]) else { return false };
    if pr[0] != pr[1] + pr[2] + pr[3] { return false; }
    let Some(qs) = v["queues"].as_array() else { return false };
    if qs.len() as i64 != counted { return false; }
    let mut last = -1i64; let mut qb = 0;
    for q in qs {
        let Some(m) = q.as_object() else { return false }; if m.len() != 4 { return false; }
        let Some(pos) = q["queue"].as_str().and_then(|n| QUEUES.iter().position(|x| *x == n)) else { return false };
        if pos as i64 <= last { return false; } last = pos as i64;
        let (Some(_), Some(_), Some(b)) = (nat(&q["created"]), nat(&q["solved"]), nat(&q["backlog"])) else { return false };
        qb += b;
    }
    qb == backlog
}

/// POST /desk/v1/reports/summary  (empty body)
pub async fn summary(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    match rows(&c, &format!("select desk.fadm_reports('{o}'::uuid)::text")).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) {
            Some(j) => match serde_json::from_str::<Value>(j) { Ok(p) if shape_ok(&p) => out(StatusCode::OK, j.to_string()), _ => { eprintln!("desk reports: wrong answer shape or sums"); unavailable() } },
            None => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk reports: db: {e}"); unavailable() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    fn good() -> Value {
        let l = |x: i64| vec![x; 14];
        let mut bl = l(3); bl[13] = 5;
        json!({"generated_at": "2026-11-23T09:00:00Z", "queues_counted": 2, "queues_hidden": 2, "backlog": {"new": 1, "open": 1, "waiting": 3},
          "daily": {"created": l(2), "solved": l(1), "backlog": bl},
          "first_reply": {"cases": 10, "replied": 8, "unanswered": 2, "median_min": 12, "p90_min": 95},
          "resolution": {"solved": 4, "median_min": 300, "p90_min": 1400}, "reopened_30d": 1,
          "priority": {"total": 3, "in_time": 2, "late": 0, "waiting": 1},
          "queues": [{"queue": "general", "created": 3, "solved": 1, "backlog": 2}, {"queue": "support", "created": 7, "solved": 3, "backlog": 3}]})
    }
    #[test] fn good_shape_passes() { assert!(shape_ok(&good())); }
    #[test] fn zero_is_data_and_medians_are_null_only_when_nothing_was_measured() {
        let mut z = good(); z["backlog"] = json!({"new": 0, "open": 0, "waiting": 0}); z["daily"] = json!({"created": vec![0; 14], "solved": vec![0; 14], "backlog": vec![0; 14]});
        z["first_reply"] = json!({"cases": 0, "replied": 0, "unanswered": 0, "median_min": null, "p90_min": null}); z["resolution"] = json!({"solved": 0, "median_min": null, "p90_min": null});
        z["reopened_30d"] = json!(0); z["priority"] = json!({"total": 0, "in_time": 0, "late": 0, "waiting": 0});
        z["queues"] = json!([{"queue": "support", "created": 0, "solved": 0, "backlog": 0}]); z["queues_counted"] = json!(1); z["queues_hidden"] = json!(3);
        assert!(shape_ok(&z), "an empty desk is a real answer");
        let mut a = z.clone(); a["first_reply"]["median_min"] = json!(5); assert!(!shape_ok(&a), "a median with nothing measured");
        let mut b = good(); b["first_reply"]["median_min"] = Value::Null; assert!(!shape_ok(&b), "no median although cases were answered");
    }
    #[test] fn sums_that_do_not_agree_are_refused() {
        let bad = |f: &dyn Fn(&mut Value)| { let mut v = good(); f(&mut v); assert!(!shape_ok(&v)); };
        bad(&|v| v["first_reply"]["unanswered"] = json!(3));
        bad(&|v| v["priority"]["waiting"] = json!(0));
        bad(&|v| v["queues"][1]["backlog"] = json!(4));
        bad(&|v| v["daily"]["backlog"][13] = json!(9));
        bad(&|v| v["queues_hidden"] = json!(1));
        bad(&|v| v["queues_counted"] = json!(3));
        bad(&|v| v["first_reply"]["p90_min"] = json!(1));
        bad(&|v| v["resolution"]["p90_min"] = json!(10));
    }
    #[test] fn wrong_shapes_are_refused() {
        let bad = |f: &dyn Fn(&mut Value)| { let mut v = good(); f(&mut v); assert!(!shape_ok(&v)); };
        bad(&|v| v["daily"]["created"] = json!([1, 2]));
        bad(&|v| v["daily"]["solved"][3] = json!(-1));
        bad(&|v| v["backlog"]["new"] = json!(-1));
        bad(&|v| v["queues"][0]["queue"] = json!("secret"));
        bad(&|v| { let q = v["queues"][0].clone(); v["queues"][1] = q; });
        bad(&|v| v["queues"][0]["subject"] = json!("Sign in problem"));
        bad(&|v| v["case_refs"] = json!(["C-000001"]));
        bad(&|v| { v.as_object_mut().unwrap().remove("reopened_30d"); });
        bad(&|v| v["first_reply"]["who"] = json!("a@b.c"));
        assert!(!shape_ok(&json!(null)) && !shape_ok(&json!({})));
    }
    #[test] fn no_personal_field_in_a_good_answer() { let t = good().to_string(); assert!(!t.contains("@") && !t.contains("C-0") && !t.contains("subject") && !t.contains("company") && !t.contains("address")); }
}
