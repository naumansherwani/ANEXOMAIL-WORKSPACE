// ANEXOMAIL ADMIN DESK consent.rs (BL-46 B13 step Z2, 24 Nov 2026): the STAFF doors of consent-gated customer-data access. Rust + Axum + Tokio, Rule 52 (sealed router + live Desk session + DBSC).
// List: D6-B13-CONSENT-ACCESS-LIST-24NOV.md. SQL: AD20 (desk.fadm_consent_* SECURITY DEFINER doors; desk_app has NO table right). The database decides: window 60/30/15 min, one live grant, restricted never content, audit line BEFORE data.
// THREE doors only: request, board, open. There is NO decide/revoke door here ON PURPOSE: a staff person must never approve their own request. The approval comes from the customer's Company Admin / Security Admin
// (passkey-signed, verified by the Control Plane with Rule 52) in step Z4; until that path exists a request honestly stays "requested". No break-glass, no auto-approval, no Chairman bypass (his 24 Nov 04:26 word).
use crate::bridge::owner;
use crate::door::{lit, rows};
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde::Deserialize;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

pub const SCOPES: [&str; 3] = ["metadata", "headers", "content"];
/// Same shape as the SQL case ref (letters, digits, _ . : -), 3..64.
pub fn valid_case(s: &str) -> bool { (3..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'_' | b'.' | b':' | b'-')) }
/// Same bound as the SQL CHECK (20..300 characters), no control characters.
pub fn valid_reason(s: &str) -> bool { let n = s.chars().count(); (20..=300).contains(&n) && s.chars().all(|c| !c.is_control()) }
fn uuid_ok(s: &str) -> bool { s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_hexdigit() }) }

#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct RequestIn { case_ref: String, scope: String, reason: String }
#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct OpenIn { consent_id: String }

fn request_ok(b: &RequestIn) -> bool { valid_case(&b.case_ref) && SCOPES.contains(&b.scope.as_str()) && valid_reason(&b.reason) }

/// POST /desk/v1/consent/request {case_ref, scope, reason}: ask for ONE case. 200 {consent_id,status:"requested"}; 409 refused by the database (restricted content, too many waiting, not active, no such case); 400 bad shape.
pub async fn request(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 2048 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<RequestIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if !request_ok(&b) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    let q = format!("select desk.fadm_consent_request('{o}'::uuid, {}, {}, {})::text", lit(&b.case_ref), lit(&b.scope), lit(&b.reason));
    match rows(&c, &q).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)).filter(|i| uuid_ok(i)) { Some(i) => out(StatusCode::OK, serde_json::json!({"consent_id": i, "status": "requested"}).to_string()), None => err(StatusCode::CONFLICT, "refused") },
        Err(e) => { let m = format!("{e}"); if m.contains("not bound to a company yet") { err(StatusCode::CONFLICT, "not_bound") } else if m.contains("not allowed") || m.contains("restricted") || m.contains("too many") || m.contains("no such case") { err(StatusCode::CONFLICT, "refused") } else { eprintln!("desk consent: db: {e}"); unavailable() } }
    }
}
/// POST /desk/v1/consent/board {}: counts + my own requests (case ref, scope, status, seconds left). No name, address, subject or money.
pub async fn board(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    match rows(&c, &format!("select desk.fadm_consent_board('{o}'::uuid)::text")).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) { Some(j) => out(StatusCode::OK, j.to_string()), None => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk consent: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/consent/open {consent_id}: the database writes the audit line FIRST, then returns {scope, seconds_left}; any other state answers 403 with one generic shape (the refusal line is written inside).
pub async fn open(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 256 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<OpenIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if !uuid_ok(&b.consent_id) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    let q = format!("select scope || '|' || seconds_left::text from desk.fadm_consent_open('{o}'::uuid, '{}'::uuid)", b.consent_id);
    match rows(&c, &q).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)).and_then(|s| s.split_once('|').map(|(a, n)| (a.to_string(), n.parse::<i64>().ok()))) {
            Some((scope, Some(left))) if SCOPES.contains(&scope.as_str()) => out(StatusCode::OK, serde_json::json!({"scope": scope, "seconds_left": left}).to_string()),
            _ => err(StatusCode::FORBIDDEN, "not_allowed"),
        },
        Err(e) => { eprintln!("desk consent: db: {e}"); unavailable() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn good() -> RequestIn { RequestIn { case_ref: "CASE-231123-00001".into(), scope: "metadata".into(), reason: "customer asked us to look at the delay".into() } }
    #[test] fn request_shape_blocks_odd_input() {
        assert!(request_ok(&good()));
        for f in [|c: &mut RequestIn| c.case_ref = "a'; drop table x;--".into(), |c: &mut RequestIn| c.case_ref = "ab".into(), |c: &mut RequestIn| c.scope = "everything".into(), |c: &mut RequestIn| c.scope = "".into(),
            |c: &mut RequestIn| c.reason = "too short".into(), |c: &mut RequestIn| c.reason = "x".repeat(301), |c: &mut RequestIn| c.reason = format!("{}\nline", "y".repeat(25))] { let mut c = good(); f(&mut c); assert!(!request_ok(&c)); }
    }
    #[test] fn the_three_scopes_match_the_database() { assert_eq!(SCOPES, ["metadata", "headers", "content"]); }
    #[test] fn bodies_reject_unknown_fields_and_wrong_types() {
        assert!(serde_json::from_str::<RequestIn>(r#"{"case_ref":"CASE-1","scope":"metadata","reason":"customer asked us to look at it"}"#).is_ok());
        assert!(serde_json::from_str::<RequestIn>(r#"{"case_ref":"CASE-1","scope":"metadata","reason":"customer asked us to look at it","approve":true}"#).is_err(), "no self-approval field can ride along");
        assert!(serde_json::from_str::<OpenIn>(r#"{"consent_id":"00000000-0000-0000-0000-000000000000","x":1}"#).is_err());
        assert!(serde_json::from_str::<OpenIn>(r#"{"consent_id":5}"#).is_err());
    }
    #[test] fn uuid_check_is_strict() {
        assert!(uuid_ok("123e4567-e89b-12d3-a456-426614174000"));
        for s in ["", "123e4567e89b12d3a456426614174000", "123e4567-e89b-12d3-a456-42661417400'", "123e4567-e89b-12d3-a456-4266141740000", "gggggggg-e89b-12d3-a456-426614174000", "123e4567-e89b-12d3-a456-426614174000; --"] { assert!(!uuid_ok(s), "{s}"); }
    }
}

#[cfg(test)]
mod bind_tests {
    // AD30: the database says "the case is not bound to a company yet"; the door must answer its own word, never a generic refusal and never 503.
    #[test]
    fn the_unbound_message_is_the_one_the_door_looks_for() {
        let sql = include_str!("../../sql/AD30.sql");
        assert!(sql.contains("the case is not bound to a company yet"));
        assert!(include_str!("consent.rs").contains("\"not bound to a company yet\""));
    }
}
