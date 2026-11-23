// ANEXOMAIL ADMIN DESK staff.rs (phase 1m-3, card B8 Staff online and shifts, 23 Nov 2026). Rust + Axum + Tokio. List: D6-CARDS-LIST-23NOV.md (T1..T7).
// ONE READ-ONLY door over the sealed router (Rule 52) and a live Desk session. desk_app has NO right on the series table; the SECURITY DEFINER door of SQL AD13 (fadm_staff_board) answers ONLY a person who may list staff
// (staff.read on the Desk department), everyone else gets 403. Names and counts only: never an e-mail, IP, device, token or key. The answer shape is checked here too: a wrong shape is "Data unavailable", never half a board. No money. Desk-only.
use crate::bridge::owner;
use crate::door::rows;
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::Value;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

pub const COUNTS: [&str; 9] = ["staff", "online", "scheduled", "on_shift", "covered", "gap", "extra", "elevations", "breakglass"];
/// The shape the card relies on: nine counts (all >= 0, online/scheduled <= staff, on_shift <= scheduled, covered + gap = on_shift, covered <= online), at most 50 people and 20 elevations of closed shape, a 24-point series and a trend word.
pub fn board_shape_ok(v: &Value) -> bool {
    let n = |k: &str| v.get("counts").and_then(|c| c.get(k)).and_then(|x| x.as_i64()).unwrap_or(-1);
    if COUNTS.iter().any(|k| n(k) < 0) { return false; }
    let counts_ok = n("online") <= n("staff") && n("scheduled") <= n("staff") && n("on_shift") <= n("scheduled") && n("covered") + n("gap") == n("on_shift") && n("covered") <= n("online");
    let ppl_ok = v.get("people").and_then(|x| x.as_array()).map(|a| a.len() <= 50 && a.iter().all(|p| {
        p.get("name").and_then(|x| x.as_str()).map(|s| !s.is_empty() && s.len() <= 80).unwrap_or(false)
            && ["owner", "agent"].contains(&p.get("role").and_then(|x| x.as_str()).unwrap_or(""))
            && ["online", "scheduled", "on_shift"].iter().all(|k| p.get(*k).map(|x| x.is_boolean()).unwrap_or(false))
            && (p.get("signed_in_minutes").map(|x| x.is_null() || x.as_i64().map(|m| m >= 0).unwrap_or(false)).unwrap_or(false))
            && p.as_object().map(|o| o.len() == 6).unwrap_or(false)
    })).unwrap_or(false);
    let el_ok = v.get("elevations").and_then(|x| x.as_array()).map(|a| a.len() <= 20 && a.iter().all(|e| {
        ["who", "relation", "unit"].iter().all(|k| e.get(*k).and_then(|x| x.as_str()).map(|s| !s.is_empty() && s.len() <= 80).unwrap_or(false))
            && ["elevation", "breakglass"].contains(&e.get("source").and_then(|x| x.as_str()).unwrap_or(""))
            && e.get("minutes_left").and_then(|x| x.as_i64()).map(|m| m >= 0).unwrap_or(false)
    })).unwrap_or(false);
    let spark_ok = v.get("spark").and_then(|x| x.as_array()).map(|a| a.len() == 24 && a.iter().all(|x| x.is_null() || x.as_i64().map(|m| m >= 0).unwrap_or(false))).unwrap_or(false);
    counts_ok && ppl_ok && el_ok && spark_ok && ["up", "steady", "down", "unknown"].contains(&v.get("trend").and_then(|x| x.as_str()).unwrap_or(""))
}

pub async fn board(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    match rows(&c, &format!("select desk.fadm_staff_board('{o}'::uuid)::text")).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) {
            Some(j) => match serde_json::from_str::<Value>(j) { Ok(p) if board_shape_ok(&p) => out(StatusCode::OK, j.to_string()), _ => { eprintln!("desk staff: wrong answer shape"); unavailable() } },
            None => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk staff: db: {e}"); unavailable() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    fn good() -> Value { json!({"counts":{"staff":4,"online":3,"scheduled":3,"on_shift":2,"covered":1,"gap":1,"extra":1,"elevations":1,"breakglass":0},
        "people":[{"name":"Aisha","role":"agent","online":true,"scheduled":true,"on_shift":true,"signed_in_minutes":42},{"name":"Bilal","role":"owner","online":false,"scheduled":false,"on_shift":false,"signed_in_minutes":null}],
        "elevations":[{"who":"Aisha","relation":"lead","unit":"Support","source":"elevation","minutes_left":25}],
        "spark":[null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,1,2,3],"trend":"up"}) }
    #[test] fn good_shape_passes() { assert!(board_shape_ok(&good())); }
    #[test] fn refuses_wrong_counts() {
        let mut v = good(); v["counts"]["online"] = json!(9); assert!(!board_shape_ok(&v), "online above staff");
        let mut v = good(); v["counts"]["covered"] = json!(2); assert!(!board_shape_ok(&v), "covered + gap must equal on_shift");
        let mut v = good(); v["counts"]["gap"] = json!(-1); assert!(!board_shape_ok(&v), "negative");
        let mut v = good(); v["counts"].as_object_mut().unwrap().remove("extra"); assert!(!board_shape_ok(&v), "missing count");
        let mut v = good(); v["counts"]["on_shift"] = json!(5); assert!(!board_shape_ok(&v), "on_shift above scheduled");
    }
    #[test] fn refuses_wrong_people_and_elevations() {
        let mut v = good(); v["people"][0]["role"] = json!("boss"); assert!(!board_shape_ok(&v), "unknown role");
        let mut v = good(); v["people"][0]["email"] = json!("a@b.c"); assert!(!board_shape_ok(&v), "an extra personal field is refused");
        let mut v = good(); v["people"][0]["online"] = json!("yes"); assert!(!board_shape_ok(&v), "not a boolean");
        let mut v = good(); v["people"][0]["name"] = json!(""); assert!(!board_shape_ok(&v), "empty name");
        let mut v = good(); v["elevations"][0]["source"] = json!("standing"); assert!(!board_shape_ok(&v), "unknown source");
        let mut v = good(); v["elevations"][0]["minutes_left"] = json!(-1); assert!(!board_shape_ok(&v), "negative minutes");
        let mut v = good(); let p = v["people"][0].clone(); v["people"] = json!(vec![p; 51]); assert!(!board_shape_ok(&v), "more than 50 people");
        let mut v = good(); let e = v["elevations"][0].clone(); v["elevations"] = json!(vec![e; 21]); assert!(!board_shape_ok(&v), "more than 20 elevations");
    }
    #[test] fn refuses_wrong_series_and_trend() {
        let mut v = good(); v["spark"] = json!([1, 2]); assert!(!board_shape_ok(&v), "short series");
        let mut v = good(); v["trend"] = json!("sideways"); assert!(!board_shape_ok(&v), "unknown trend");
        assert!(!board_shape_ok(&json!({})) && !board_shape_ok(&json!(null)));
    }
    #[test] fn no_contact_or_credential_field_in_a_good_answer() { let t = good().to_string(); assert!(!t.contains("email") && !t.contains("\"ip\"") && !t.contains("token") && !t.contains("cred")); }
}
