// ANEXOMAIL ADMIN DESK runbooks.rs (D5b, phase 1k, 23 Nov 2026): the runbook library, the guided checklist and the Chairman's approval (SQL AD9 + AD9b). Rust + Axum + Tokio.
// Sealed router (Rule 52: Desk-signed answer, request MAC, replay nonce) and a live Desk session. desk_app has NO table right: every call goes through a SECURITY DEFINER door
// (fadm_runbooks_list, fadm_runbook_tick, fadm_runbook_ticks, fadm_runbook_mark). The database decides who may approve (role owner only); this file only checks the SHAPE of the request.
// Staff instructions only: no customer data beyond the company reference already typed on the lookup screen, no money. Desk-only: no founder or awam code.
use crate::bridge::owner;
use crate::door::{lit, rows};
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde::Deserialize;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
/// Same shape as the SQL CHECK (a company reference the employee typed on the lookup screen, plain characters only).
pub fn valid_company(s: &str) -> bool { (6..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-') }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct TickIn { version_id: i64, company_ref: String, step: i32, done: bool }
#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct TicksIn { version_id: i64, company_ref: String }
#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct MarkIn { version_id: i64, kind: String }

/// GET /desk/v1/runbooks: the current version of every runbook with approval, validation and the 90-day stale flag.
pub async fn list(h: HeaderMap) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    match rows(&c, &format!("select desk.fadm_runbooks_list('{o}'::uuid)::text")).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) { Some(j) => out(StatusCode::OK, j.to_string()), None => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk runbooks: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/runbooks/tick {version_id, company_ref, step, done}: tick or untick one step. The database refuses a stranger, a wrong step, an old version and a flood (409 refused).
pub async fn tick(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 2048 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(t) = serde_json::from_slice::<TickIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if t.version_id < 1 || !valid_company(&t.company_ref) || !(0..=11).contains(&t.step) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    let q = format!("select desk.fadm_runbook_tick('{o}'::uuid, {}, {}, {}, {})::text", t.version_id, lit(&t.company_ref), t.step, t.done);
    verdict(rows(&c, &q).await)
}
/// POST /desk/v1/runbooks/ticks {version_id, company_ref}: the latest state of every step for that company.
pub async fn ticks(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 2048 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(t) = serde_json::from_slice::<TicksIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if t.version_id < 1 || !valid_company(&t.company_ref) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    match rows(&c, &format!("select desk.fadm_runbook_ticks('{o}'::uuid, {}, {})::text", t.version_id, lit(&t.company_ref))).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) { Some(j) => out(StatusCode::OK, j.to_string()), None => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk runbooks: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/runbooks/mark {version_id, kind: approved|validated}: ONLY an owner (the Chairman) can; the database says no to everyone else (403).
pub async fn mark(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 1024 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(m) = serde_json::from_slice::<MarkIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if m.version_id < 1 || !matches!(m.kind.as_str(), "approved" | "validated") { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    match rows(&c, &format!("select desk.fadm_runbook_mark('{o}'::uuid, {}, {})::text", m.version_id, lit(&m.kind))).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) { Some("true") => out(StatusCode::OK, r#"{"ok":true}"#.into()), _ => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk runbooks: db: {e}"); unavailable() }
    }
}
fn verdict(r: Result<Vec<tokio_postgres::SimpleQueryRow>, tokio_postgres::Error>) -> Response {
    match r {
        Ok(v) => match v.first().and_then(|r| r.get(0)) { Some("true") => out(StatusCode::OK, r#"{"ok":true}"#.into()), _ => err(StatusCode::CONFLICT, "refused") },
        Err(e) => { eprintln!("desk runbooks: db: {e}"); unavailable() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn company_shape_blocks_sql_and_odd_text() {
        for ok in ["TESTCO001", "acme-corp_1"] { assert!(valid_company(ok), "{ok}"); }
        for bad in ["", "abc", "a'; drop table x;--", "TEST CO", "x".repeat(65).as_str(), "co.mpany", "../x"] { assert!(!valid_company(bad), "{bad}"); }
    }
    #[test] fn bodies_reject_unknown_fields_and_wrong_types() {
        assert!(serde_json::from_str::<TickIn>(r#"{"version_id":1,"company_ref":"TESTCO001","step":0,"done":true}"#).is_ok());
        assert!(serde_json::from_str::<TickIn>(r#"{"version_id":1,"company_ref":"TESTCO001","step":0,"done":true,"x":1}"#).is_err());
        assert!(serde_json::from_str::<TickIn>(r#"{"version_id":"1","company_ref":"TESTCO001","step":0,"done":true}"#).is_err());
        assert!(serde_json::from_str::<MarkIn>(r#"{"version_id":1}"#).is_err());
    }
    /// Rust -> PostgreSQL on the scratch database (needs DESK_TEST_ADMIN_URL with AD1..AD9b; skipped otherwise): no session = 401; an agent reads, ticks, cannot approve; an owner can approve; a bad body is 400.
    #[tokio::test] async fn database_doors_read_tick_and_only_an_owner_approves() {
        let Ok(admin) = std::env::var("DESK_TEST_ADMIN_URL") else { eprintln!("no DESK_TEST_ADMIN_URL: skipped"); return; };
        let (a, conn) = tokio_postgres::connect(&admin, tokio_postgres::NoTls).await.unwrap(); tokio::spawn(conn);
        let hx = |b: &[u8]| b.iter().map(|x| format!("{x:02x}")).collect::<String>();
        let sfx = hx(&crate::auth::token_hash(&format!("rb{:?}", std::time::SystemTime::now()))[..4]);
        let h = "$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo";
        let own = rows(&a, &format!("insert into desk.fadm_owner (email, display_name, role, pw_hash) values ('rb-o-{sfx}@selftest.invalid','RB Owner','owner','{h}') returning id::text")).await.unwrap()[0].get(0).unwrap().to_string();
        let ag = rows(&a, &format!("insert into desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) values ('rb-a-{sfx}@selftest.invalid','RB Agent','agent',NULL,true,'active',true) returning id::text")).await.unwrap()[0].get(0).unwrap().to_string();
        let to = format!("{sfx}{}", "ab".repeat(28)); let ta = format!("{sfx}{}", "cd".repeat(28));
        for (o, t) in [(&own, &to), (&ag, &ta)] { rows(&a, &format!("select desk.fadm_session_create('{o}'::uuid, '\\x{}'::bytea, 600)::text", hx(&crate::auth::token_hash(t)))).await.unwrap(); }
        rows(&a, "alter role desk_app login password 'scratch'").await.unwrap();
        let url = format!("postgres://desk_app:scratch@{}/{}?sslmode=disable", admin.split('@').next_back().unwrap().split('/').next().unwrap(), admin.rsplit('/').next().unwrap());
        unsafe { std::env::set_var("DESK_APP_URL", &url); }
        let body = |r: Response| async move { let st = r.status(); let b = axum::body::to_bytes(r.into_body(), 1 << 22).await.unwrap(); (st, serde_json::from_slice::<serde_json::Value>(&b).unwrap_or_default()) };
        let hd = |t: &str| { let mut m = HeaderMap::new(); m.insert(header::AUTHORIZATION, format!("Bearer {t}").parse().unwrap()); m };
        // a FRESH current version of R1 for this run (the scratch database keeps earlier runs, so the test must not depend on an untouched R1)
        rows(&a, "insert into desk.fadm_runbook_version (runbook_key, major, minor, patch, parts, steps, say_text, changelog) select runbook_key, major + 1, 0, 0, parts, steps, say_text, 'test run' from desk.fadm_runbook_version where runbook_key = 'R1' order by major desc, minor desc, patch desc limit 1").await.unwrap();
        let (st, _) = body(list(HeaderMap::new()).await).await; assert_eq!(st, StatusCode::UNAUTHORIZED);
        let (st, v) = body(list(hd(&ta)).await).await; assert_eq!(st, StatusCode::OK, "{v}");
        let arr = v.as_array().unwrap(); assert!(arr.len() >= 9); let r1 = arr.iter().find(|x| x["key"] == "R1").unwrap();
        let vid = r1["version_id"].as_i64().unwrap(); assert_eq!(r1["parts"].as_object().unwrap().len(), 6); assert!(r1["approved_at"].is_null(), "a draft is not approved");
        let tk = |step: i32, done: bool| Bytes::from(format!(r#"{{"version_id":{vid},"company_ref":"RBTESTCO1","step":{step},"done":{done}}}"#));
        let (st, _) = body(tick(hd(&ta), tk(0, true)).await).await; assert_eq!(st, StatusCode::OK);
        let (st, v) = body(tick(hd(&ta), tk(99, true)).await).await; assert_eq!(st, StatusCode::BAD_REQUEST, "{v}");
        let (st, v) = body(tick(hd(&ta), Bytes::from(format!(r#"{{"version_id":{vid},"company_ref":"RBTESTCO1","step":11,"done":true}}"#))).await).await; assert_eq!(st, StatusCode::CONFLICT, "step 11 does not exist in a six-step runbook: {v}");
        let (st, v) = body(ticks(hd(&to), Bytes::from(format!(r#"{{"version_id":{vid},"company_ref":"RBTESTCO1"}}"#))).await).await; assert_eq!(st, StatusCode::OK);
        assert_eq!(v.as_array().unwrap().len(), 1); assert_eq!(v[0]["by"], "RB Agent");
        let mk = Bytes::from(format!(r#"{{"version_id":{vid},"kind":"approved"}}"#));
        let (st, _) = body(mark(hd(&ta), mk.clone()).await).await; assert_eq!(st, StatusCode::FORBIDDEN, "an agent must never approve");
        let (st, _) = body(mark(hd(&to), mk).await).await; assert_eq!(st, StatusCode::OK);
        let (st, _) = body(mark(hd(&to), Bytes::from(r#"{"version_id":1,"kind":"deleted"}"#)).await).await; assert_eq!(st, StatusCode::BAD_REQUEST);
        let (_, v) = body(list(hd(&ta)).await).await; assert!(!v.as_array().unwrap().iter().find(|x| x["key"] == "R1").unwrap()["approved_at"].is_null(), "approval shows");
    }
}
