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
/// The shape the card relies on: four queues in the fixed order, every count a non-negative number, the risk window 15.
pub fn pressure_shape_ok(v: &Value) -> bool {
    let Some(q) = v.get("queues").and_then(|x| x.as_array()) else { return false };
    v.get("risk_window_minutes").and_then(|x| x.as_i64()) == Some(15) && q.len() == 4
        && q.iter().zip(QUEUES).all(|(r, name)| r.get("queue").and_then(|x| x.as_str()) == Some(name)
            && ["new", "open", "waiting", "at_risk"].iter().all(|k| r.get(*k).and_then(|x| x.as_i64()).map(|n| n >= 0).unwrap_or(false))
            && r.get("oldest_minutes").map(|x| x.is_null() || x.as_i64().map(|n| n >= 0).unwrap_or(false)).unwrap_or(false))
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
    fn good() -> Value { json!({"risk_window_minutes":15,"queues":[
        {"queue":"general","new":0,"open":0,"waiting":0,"at_risk":0,"oldest_minutes":null},{"queue":"support","new":2,"open":1,"waiting":0,"at_risk":1,"oldest_minutes":42},
        {"queue":"movein","new":0,"open":0,"waiting":0,"at_risk":0,"oldest_minutes":null},{"queue":"billing","new":0,"open":0,"waiting":0,"at_risk":0,"oldest_minutes":null}]}) }
    #[test] fn pressure_good_shape_passes() { assert!(pressure_shape_ok(&good())); }
    #[test] fn pressure_refuses_wrong_shapes() {
        let mut v = good(); v["queues"].as_array_mut().unwrap().pop(); assert!(!pressure_shape_ok(&v), "three queues");
        let mut v = good(); v["queues"][1]["new"] = json!(-1); assert!(!pressure_shape_ok(&v), "negative count");
        let mut v = good(); v["queues"][0]["queue"] = json!("support"); assert!(!pressure_shape_ok(&v), "wrong order");
        let mut v = good(); v["risk_window_minutes"] = json!(30); assert!(!pressure_shape_ok(&v), "other window");
        let mut v = good(); v["queues"][1]["new"] = json!("2"); assert!(!pressure_shape_ok(&v), "count as text");
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
