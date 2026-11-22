// ANEXOMAIL ADMIN DESK bridge.rs (R4-1b S1, 22 Nov 2026): the Bridge DATA LAYER. Rust + Axum + Tokio; every number is read from the database as the
// signed-in person (desk.fadm_bridge_summary / fadm_bridge_services / fadm_alert_list / fadm_alert_act: each runs fadm_need() inside PostgreSQL, so the
// database, not this file, decides who may see or do what). These doors sit behind signed::guard (Rule 52: Desk-signed answer, request MAC, replay nonce).
// HIS LAW 22 Nov 04:44: HTTP fallback is BANNED. These doors are the data source the S2 WebTransport stream reads; the browser UI never polls them.
// NULL stays NULL (not measured), nothing is invented. Desk-only: no founder or awam code.
use crate::door::{connect, lit, rows, token_of};
use crate::auth;
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use tokio_postgres::error::SqlState;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
fn db_err(e: &tokio_postgres::Error) -> Response {
    match e.code() {
        Some(c) if *c == SqlState::INSUFFICIENT_PRIVILEGE => err(StatusCode::FORBIDDEN, "not_allowed"),
        Some(c) if *c == SqlState::NO_DATA_FOUND => err(StatusCode::NOT_FOUND, "not_found"),
        Some(c) if *c == SqlState::CHECK_VIOLATION => err(StatusCode::UNPROCESSABLE_ENTITY, "refused"),
        _ => { eprintln!("desk bridge: db: {e}"); err(StatusCode::SERVICE_UNAVAILABLE, "db_unavailable") }
    }
}
fn uuid_ok(s: &str) -> bool { s.len() == 36 && s.bytes().all(|b| b.is_ascii_hexdigit() || b == b'-') }

/// The owner behind the session token (None = no live session). The kernel MAC was already checked by signed::guard.
pub(crate) async fn owner(h: &HeaderMap) -> Result<(std::sync::Arc<tokio_postgres::Client>, String), Response> {
    let Some(t) = token_of(h) else { return Err(err(StatusCode::UNAUTHORIZED, "no_session")) };
    let Ok(c) = connect().await else { return Err(err(StatusCode::SERVICE_UNAVAILABLE, "db_unavailable")) };
    let q = format!("select owner_id::text from desk.fadm_session_lookup('\\x{}'::bytea)", auth::token_hash(&t).iter().map(|x| format!("{x:02x}")).collect::<String>());
    match rows(&c, &q).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)).map(str::to_string).filter(|o| uuid_ok(o)) { Some(o) => Ok((c, o)), None => Err(err(StatusCode::UNAUTHORIZED, "no_session")) },
        Err(_) => Err(err(StatusCode::SERVICE_UNAVAILABLE, "db_unavailable")),
    }
}
async fn json_of(h: &HeaderMap, sql_for: impl FnOnce(&str) -> String) -> Response {
    let (c, o) = match owner(h).await { Ok(x) => x, Err(r) => return r };
    match rows(&c, &sql_for(&o)).await {
        Ok(v) => out(StatusCode::OK, v.first().and_then(|r| r.get(0)).unwrap_or("null").to_string()),
        Err(e) => db_err(&e),
    }
}
/// GET /desk/v1/bridge/summary: the Command Bar numbers (P1 count, services by state, ledger seal).
pub async fn summary(h: HeaderMap) -> Response { json_of(&h, |o| format!("select desk.fadm_bridge_summary('{o}'::uuid)::text")).await }
/// GET /desk/v1/bridge/services: the 10 services with state, last probe age, latency, 24 h uptime.
pub async fn services(h: HeaderMap) -> Response { json_of(&h, |o| format!("select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)::text from desk.fadm_bridge_services('{o}'::uuid) t")).await }
/// GET /desk/v1/bridge/alerts: open alerts, worst first (max 100).
pub async fn alerts(h: HeaderMap) -> Response { json_of(&h, |o| format!("select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)::text from desk.fadm_alert_list('{o}'::uuid, true, 100) t")).await }

#[derive(serde::Deserialize)]
pub struct Act { alert: i64, event: String, status: Option<String>, assignee: Option<String>, note: Option<String> }
/// POST /desk/v1/bridge/alerts/act: ack / assign / status / note on one alert. The database enforces who may do it and the alert rules.
pub async fn alert_act(h: HeaderMap, bytes: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if bytes.len() > 8 * 1024 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(a) = serde_json::from_slice::<Act>(&bytes) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    let word = |s: &str| s.len() <= 40 && s.bytes().all(|b| b.is_ascii_lowercase() || b == b'_');
    if a.alert < 1 || !word(&a.event) || a.status.as_deref().is_some_and(|s| !word(s)) || a.assignee.as_deref().is_some_and(|s| !uuid_ok(s)) || a.note.as_deref().is_some_and(|n| n.len() > 2000) {
        return err(StatusCode::BAD_REQUEST, "bad_body");
    }
    let q = format!("select desk.fadm_alert_act('{o}'::uuid, {}, {}, {}, {}, {})::text", a.alert, lit(&a.event),
        a.status.as_deref().map(lit).unwrap_or("NULL".into()), a.assignee.as_deref().map(|s| format!("'{s}'::uuid")).unwrap_or("NULL".into()), a.note.as_deref().map(lit).unwrap_or("NULL".into()));
    match rows(&c, &q).await { Ok(_) => out(StatusCode::OK, r#"{"ok":true}"#.into()), Err(e) => db_err(&e) }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn uuid_check_blocks_sql() { assert!(uuid_ok("123e4567-e89b-12d3-a456-426614174000")); assert!(!uuid_ok("123e4567-e89b-12d3-a456-42661417400'")); assert!(!uuid_ok("x")); }
    #[test] fn act_body_parses_and_unknown_field_is_ignored_safely() {
        let a: Act = serde_json::from_str(r#"{"alert":7,"event":"ack"}"#).unwrap(); assert_eq!(a.alert, 7); assert!(a.status.is_none());
        assert!(serde_json::from_str::<Act>(r#"{"event":"ack"}"#).is_err());
    }
    #[test] fn errors_are_json_with_the_right_status() { assert_eq!(err(StatusCode::FORBIDDEN, "not_allowed").status(), StatusCode::FORBIDDEN); }
}


/// Phase C: one track of the Bridge for the WebTransport stream. The session token is looked up EVERY call (a sign-out or a revoked session ends the stream on the next tick);
/// the database (fadm_need inside PostgreSQL) still decides what this person may see. Ok = the JSON text, Err = the HTTP-style status of the refusal.
pub async fn track(token: &str, track: &str) -> Result<String, u16> {
    let mut h = HeaderMap::new();
    h.insert(header::AUTHORIZATION, format!("Bearer {token}").parse().map_err(|_| 401u16)?);
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return Err(r.status().as_u16()) };
    let q = match track {
        "summary" => format!("select desk.fadm_bridge_summary('{o}'::uuid)::text"),
        "services" => format!("select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)::text from desk.fadm_bridge_services('{o}'::uuid) t"),
        "alerts" => format!("select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)::text from desk.fadm_alert_list('{o}'::uuid, true, 100) t"),
        _ => return Err(404),
    };
    match rows(&c, &q).await {
        Ok(v) => Ok(v.first().and_then(|r| r.get(0)).unwrap_or("null").to_string()),
        Err(e) => Err(db_err(&e).status().as_u16()),
    }
}
