// ANEXOMAIL ADMIN DESK pressure.rs (phase 1m, cards B1 Queue pressure + B2 SLA at risk, 23 Nov 2026). Rust + Axum + Tokio. List: D6-CARDS-LIST-23NOV.md (C1..C10).
// Two READ-ONLY doors over the sealed router (Rule 52) and a live Desk session. desk_app has NO table right; the SECURITY DEFINER doors of SQL AD11 (fadm_queue_pressure, fadm_sla_risk) decide what the asking person may read
// (fadm_case_can per case) and return counts and references only (no subject, no address, no company). The answer shape is checked here too: a wrong shape is "Data unavailable", never a half answer. No money. Desk-only.
use crate::bridge::owner;
use crate::door::rows;
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::Value;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

pub const QUEUES: [&str; 4] = ["general", "support", "movein", "billing"];
/// The shape the card relies on: four queues in the fixed order; a queue the person may not read is readable=false, level "none", all zeros; a readable queue has non-negative counts, five aging buckets, a 12-point sparkline (null = gap),
/// a trend word, a level word, and a clear-time estimate that is null or a positive number. The risk window is 15.
pub fn pressure_shape_ok(v: &Value) -> bool {
    let nat = |x: Option<&Value>| x.and_then(|y| y.as_i64()).map(|n| n >= 0).unwrap_or(false);
    let Some(q) = v.get("queues").and_then(|x| x.as_array()) else { return false };
    v.get("risk_window_minutes").and_then(|x| x.as_i64()) == Some(15) && q.len() == 4
        && q.iter().zip(QUEUES).all(|(r, name)| {
            let readable = r.get("readable").and_then(|x| x.as_bool());
            let level = r.get("level").and_then(|x| x.as_str()).unwrap_or("");
            let trend = r.get("trend").and_then(|x| x.as_str()).unwrap_or("");
            let ages_ok = r.get("ages").and_then(|x| x.as_array()).map(|a| a.len() == 5 && a.iter().all(|n| nat(Some(n)))).unwrap_or(false);
            let spark_ok = r.get("spark").and_then(|x| x.as_array()).map(|a| a.len() == 12 && a.iter().all(|n| n.is_null() || nat(Some(n)))).unwrap_or(false);
            let clear_ok = r.get("clear_minutes").map(|x| x.is_null() || x.as_i64().map(|n| n > 0).unwrap_or(false)).unwrap_or(false);
            let old_ok = r.get("oldest_minutes").map(|x| x.is_null() || nat(Some(x))).unwrap_or(false);
            r.get("queue").and_then(|x| x.as_str()) == Some(name) && readable.is_some()
                && ["new", "open", "waiting", "at_risk", "arrived_60m", "answered_60m"].iter().all(|k| nat(r.get(*k)))
                && ages_ok && spark_ok && clear_ok && old_ok
                && ["growing", "steady", "shrinking", "unknown"].contains(&trend)
                && if readable == Some(true) { ["calm", "busy", "strained", "overloaded"].contains(&level) } else { level == "none" && trend == "unknown" }
        })
}
pub fn risk_shape_ok(v: &Value) -> bool {
    v.get("risk_window_minutes").and_then(|x| x.as_i64()) == Some(15)
        && v.get("cases").and_then(|x| x.as_array()).map(|c| c.len() <= 20 && c.iter().all(|r| r.get("ref").and_then(|x| x.as_str()).map(|s| s.starts_with("C-")).unwrap_or(false)
            && r.get("queue").and_then(|x| x.as_str()).map(|s| QUEUES.contains(&s)).unwrap_or(false) && r.get("minutes_left").and_then(|x| x.as_i64()).is_some() && r.get("overdue").and_then(|x| x.as_bool()).is_some())).unwrap_or(false)
}

async fn door(h: HeaderMap, body: Bytes, sql_fn: &str, ok: fn(&Value) -> bool) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    match rows(&c, &format!("select desk.{sql_fn}('{o}'::uuid)::text")).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) {
            Some(j) => match serde_json::from_str::<Value>(j) { Ok(p) if ok(&p) => out(StatusCode::OK, j.to_string()), _ => { eprintln!("desk pressure: wrong answer shape from {sql_fn}"); unavailable() } },
            None => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk pressure: db: {e}"); unavailable() }
    }
}
pub async fn queues(h: HeaderMap, body: Bytes) -> Response { door(h, body, "fadm_queue_pressure", pressure_shape_ok).await }
pub async fn risk(h: HeaderMap, body: Bytes) -> Response { door(h, body, "fadm_sla_risk", risk_shape_ok).await }

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    fn q(name: &str, readable: bool, n: i64, risk: i64) -> Value { json!({"queue":name,"readable":readable,"new":n,"open":0,"waiting":0,"at_risk":risk,"oldest_minutes":if n>0 {json!(42)} else {Value::Null},"arrived_60m":n,"answered_60m":0,
        "ages":[n,0,0,0,0],"spark":[null,null,null,null,null,null,null,null,null,null,null,n],"trend":if readable {"steady"} else {"unknown"},"clear_minutes":null,"level":if !readable {"none"} else if risk>=3 {"overloaded"} else {"calm"}}) }
    fn good() -> Value { json!({"risk_window_minutes":15,"queues":[q("general",true,0,0),q("support",true,4,3),q("movein",false,0,0),q("billing",false,0,0)]}) }
    #[test] fn pressure_good_shape_passes() { assert!(pressure_shape_ok(&good())); }
    #[test] fn pressure_refuses_wrong_shapes() {
        let mut v = good(); v["queues"].as_array_mut().unwrap().pop(); assert!(!pressure_shape_ok(&v), "three queues");
        let mut v = good(); v["queues"][1]["new"] = json!(-1); assert!(!pressure_shape_ok(&v), "negative count");
        let mut v = good(); v["queues"][0]["queue"] = json!("support"); assert!(!pressure_shape_ok(&v), "wrong order");
        let mut v = good(); v["risk_window_minutes"] = json!(30); assert!(!pressure_shape_ok(&v), "other window");
        let mut v = good(); v["queues"][1]["new"] = json!("2"); assert!(!pressure_shape_ok(&v), "count as text");
        let mut v = good(); v["queues"][1]["level"] = json!("panic"); assert!(!pressure_shape_ok(&v), "unknown level");
        let mut v = good(); v["queues"][1]["trend"] = json!("up"); assert!(!pressure_shape_ok(&v), "unknown trend");
        let mut v = good(); v["queues"][1]["ages"] = json!([1, 2, 3]); assert!(!pressure_shape_ok(&v), "three age buckets");
        let mut v = good(); v["queues"][1]["spark"] = json!([1, 2]); assert!(!pressure_shape_ok(&v), "short sparkline");
        let mut v = good(); v["queues"][1]["clear_minutes"] = json!(0); assert!(!pressure_shape_ok(&v), "zero clear time");
        let mut v = good(); v["queues"][2]["level"] = json!("calm"); assert!(!pressure_shape_ok(&v), "an unreadable queue must say level none");
        let mut v = good(); v["queues"][2]["readable"] = json!(null); assert!(!pressure_shape_ok(&v), "readable missing");
        assert!(!pressure_shape_ok(&json!({})) && !pressure_shape_ok(&json!(null)));
    }
    #[test] fn risk_shape_rules() {
        assert!(risk_shape_ok(&json!({"risk_window_minutes":15,"cases":[]})));
        assert!(risk_shape_ok(&json!({"risk_window_minutes":15,"cases":[{"ref":"C-000012","queue":"support","minutes_left":-5,"overdue":true}]})));
        assert!(!risk_shape_ok(&json!({"risk_window_minutes":15,"cases":[{"ref":"X1","queue":"support","minutes_left":3,"overdue":false}]})), "bad ref");
        assert!(!risk_shape_ok(&json!({"risk_window_minutes":15,"cases":[{"ref":"C-000012","queue":"other","minutes_left":3,"overdue":false}]})), "bad queue");
        assert!(!risk_shape_ok(&json!({"risk_window_minutes":15,"cases":[{"ref":"C-000012","queue":"support","subject":"x","minutes_left":3}]})), "missing overdue");
        let many: Vec<Value> = (0..21).map(|i| json!({"ref":format!("C-{i:06}"),"queue":"support","minutes_left":1,"overdue":false})).collect();
        assert!(!risk_shape_ok(&json!({"risk_window_minutes":15,"cases":many})), "more than 20");
    }
}
