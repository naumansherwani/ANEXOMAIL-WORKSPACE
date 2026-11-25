// ANEXOMAIL ADMIN DESK registry.rs (BL-46 B13 step T4i, 25 Nov 2026): the READ doors of the company registration numbers (SQL AD34 desk.fadm_registry_kind from the GLEIF RA list + AD35 desk.fadm_company_identifier). Rust + Axum + Tokio, Rule 52 (sealed router + live Desk session + DBSC).
// Plan: D6-B13-T4I-REGISTRATION-NUMBERS-PLAN-25NOV.md. FIVE read-only doors: countries, pick, check, lookup, history. The actor is ALWAYS the signed-in staff person from the session, never a body field. The DATABASE decides (staff.read inside the SECURITY DEFINER door); desk_app has no table right.
// WHY NO WRITE DOOR HERE (honest, in the gate as T4I-5): the AD35 write door company_identifier_set(actor, SECOND, ...) takes the second person as an argument, and the second person cannot prove consent in the same HTTP call. A body-supplied second uuid would let one staff member name a colleague who never agreed.
// So the record/end doors stay CLOSED to the browser until a proposal + confirm flow exists (like T4a, a later SQL file); this phase gives staff the picker, the shape check and the "who holds this number" lookup, which is what finds the company for a case.
// RULE 52 COMBO: S = every answer is one closed JSON shape on the sealed router and is kernel-verified in the browser; the company NAME is asked of the Control Plane (signed, tenant_cp.rs), never guessed. M = no mail path. L = the database writes its own ledger lines; a read door writes none, and the NUMBER is never logged by this file.
use crate::bridge::owner;
use crate::door::{lit, rows};
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde::Deserialize;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

/// The closed words of desk.registry_check (AD34); anything else becomes "refused" (fail closed).
pub const CHECK_WORDS: [&str; 5] = ["ok", "wrong_shape", "shape_unknown", "bad_number", "no_register"];
/// The closed states of desk.company_identifier_lookup (AD35).
pub const LOOKUP_STATES: [&str; 5] = ["found", "none", "no_right", "no_register", "bad_number"];
pub const SHAPE_STATES: [&str; 2] = ["shape_ok", "shape_unproven"];

pub fn word(raw: Option<&str>, list: &[&'static str]) -> &'static str { raw.and_then(|w| list.iter().find(|x| **x == w).copied()).unwrap_or("refused") }
pub fn uuid_ok(s: &str) -> bool { s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_hexdigit() }) }
pub fn nil_uuid(s: &str) -> bool { s.bytes().all(|b| b == b'0' || b == b'-') }
/// ISO 3166-1 alpha-2 shape: exactly two capital letters (the SQL door checks it again).
pub fn country_ok(s: &str) -> bool { s.len() == 2 && s.bytes().all(|b| b.is_ascii_uppercase()) }
/// A register row id of desk.fadm_registry_kind: a positive number that fits a bigint.
pub fn registry_ok(id: i64) -> bool { id > 0 }
/// What a person may type as a registration number: 1..80 printable characters (spaces and dashes are removed by the database), never a control character.
pub fn number_ok(s: &str) -> bool { let n = s.trim().chars().count(); (1..=80).contains(&n) && !s.chars().any(|c| c.is_control()) }

#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct PickIn { country: String }
#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct NumberIn { registry_id: i64, number: String }
#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct HistoryIn { tenant_id: String }

/// POST /desk/v1/registry/countries {}: the jurisdictions with how many registers each: {countries:[{code,country,registers}]}.
pub async fn countries(h: HeaderMap, body: Bytes) -> Response {
    let (c, _o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    match rows(&c, "select desk.registry_countries()::text").await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) { Some(j) if j.starts_with('[') => out(StatusCode::OK, format!("{{\"countries\":{j}}}")), _ => unavailable() },
        Err(e) => { eprintln!("desk registry: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/registry/pick {country}: the registers of one country (at most 100) with whether a number shape is proven.
pub async fn pick(h: HeaderMap, body: Bytes) -> Response {
    let (c, _o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 128 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<PickIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if !country_ok(&b.country) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    match rows(&c, &format!("select desk.registry_pick({})::text", lit(&b.country))).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) { Some(j) if j.starts_with('[') => out(StatusCode::OK, format!("{{\"registers\":{j}}}")), _ => unavailable() },
        Err(e) => { eprintln!("desk registry: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/registry/check {registry_id, number}: does the number have the proven shape of that register? One closed word. shape_unknown is honest: no shape is proven for that register, nothing is guessed.
pub async fn check(h: HeaderMap, body: Bytes) -> Response {
    let (c, _o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 512 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<NumberIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if !registry_ok(b.registry_id) || !number_ok(&b.number) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    match rows(&c, &format!("select desk.registry_check({}::bigint, {})", b.registry_id, lit(b.number.trim()))).await {
        Ok(v) => { let w = word(v.first().and_then(|r| r.get(0)), &CHECK_WORDS); out(StatusCode::OK, serde_json::json!({"check": w}).to_string()) }
        Err(e) => { eprintln!("desk registry: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/registry/lookup {registry_id, number}: which company holds this number now. 200 {state, tenant_id?, since?, shape_state?, tenant_name?, name_state?}. The company NAME is asked of the Control Plane (signed), name_state = ok | missing | unavailable.
pub async fn lookup(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 512 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<NumberIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if !registry_ok(b.registry_id) || !number_ok(&b.number) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    let q = format!("select desk.company_identifier_lookup('{o}'::uuid, {}::bigint, {})::text", b.registry_id, lit(b.number.trim()));
    match rows(&c, &q).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) {
            Some(j) => out(StatusCode::OK, shape_lookup(&o, j).await),
            None => unavailable(),
        },
        Err(e) => { eprintln!("desk registry: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/registry/history {tenant_id}: every registry number a company ever held (at most 100, newest first). Only public register names and numbers, no person ids.
pub async fn history(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 256 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<HistoryIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if !uuid_ok(&b.tenant_id) || nil_uuid(&b.tenant_id) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    match rows(&c, &format!("select desk.company_identifier_history('{o}'::uuid, '{}'::uuid)::text", b.tenant_id)).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) {
            Some(j) if j.starts_with('[') => out(StatusCode::OK, format!("{{\"items\":{j}}}")),
            _ => err(StatusCode::FORBIDDEN, "not_allowed"),   // the database answered NULL: the person has no staff.read
        },
        Err(e) => { eprintln!("desk registry: db: {e}"); unavailable() }
    }
}

/// Turns the database answer of the lookup into the closed answer shape. Only known states pass; a found company gets its NAME from the Control Plane.
async fn shape_lookup(owner: &str, raw: &str) -> String {
    let Ok(v) = serde_json::from_str::<serde_json::Value>(raw) else { return serde_json::json!({"state": "refused"}).to_string() };
    let st = word(v["state"].as_str(), &LOOKUP_STATES);
    if st != "found" { return serde_json::json!({"state": st}).to_string(); }
    let (Some(t), Some(since), Some(shape)) = (v["tenant_id"].as_str(), v["since"].as_str(), v["shape_state"].as_str()) else { return serde_json::json!({"state": "refused"}).to_string() };
    if !uuid_ok(t) || nil_uuid(t) || !SHAPE_STATES.contains(&shape) || since.len() > 40 { return serde_json::json!({"state": "refused"}).to_string(); }
    let (ns, name) = match crate::tenant_cp::ask(owner, &t.to_ascii_lowercase()).await {
        Ok(crate::tenant_cp::Tenant::Exists(n)) => ("ok", Some(n)),
        Ok(crate::tenant_cp::Tenant::Missing) => ("missing", None),
        Err(_) => ("unavailable", None),
    };
    serde_json::json!({"state": "found", "tenant_id": t, "since": since, "shape_state": shape, "name_state": ns, "tenant_name": name}).to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn country_must_be_two_capital_letters() {
        assert!(country_ok("PK")); assert!(country_ok("GB"));
        for bad in ["pk", "P", "PAK", "P1", "P K", "", "P'", "Pk"] { assert!(!country_ok(bad), "{bad}"); }
    }
    #[test] fn registry_id_must_be_positive() { assert!(registry_ok(1)); assert!(!registry_ok(0)); assert!(!registry_ok(-5)); }
    #[test] fn a_number_is_printable_and_bounded() {
        assert!(number_ok("0086650")); assert!(number_ok("  0086650 ")); assert!(number_ok("DE-HRB 12345"));
        assert!(!number_ok("")); assert!(!number_ok("   ")); assert!(!number_ok("12\n34")); assert!(!number_ok(&"9".repeat(81))); assert!(!number_ok("12\u{0007}"));
    }
    #[test] fn bodies_reject_unknown_fields_and_a_forged_actor() {
        assert!(serde_json::from_str::<PickIn>(r#"{"country":"PK"}"#).is_ok());
        assert!(serde_json::from_str::<PickIn>(r#"{"country":"PK","actor":"x"}"#).is_err());
        assert!(serde_json::from_str::<NumberIn>(r#"{"registry_id":5,"number":"1"}"#).is_ok());
        assert!(serde_json::from_str::<NumberIn>(r#"{"registry_id":"5","number":"1"}"#).is_err(), "the id is a number, never a text");
        assert!(serde_json::from_str::<NumberIn>(r#"{"registry_id":5,"number":"1","second":"x"}"#).is_err(), "no second person can be named from the browser");
        assert!(serde_json::from_str::<HistoryIn>(r#"{"tenant_id":"a","actor":"b"}"#).is_err());
    }
    #[test] fn an_unknown_database_word_fails_closed() {
        assert_eq!(word(Some("ok"), &CHECK_WORDS), "ok");
        assert_eq!(word(Some("shape_unknown"), &CHECK_WORDS), "shape_unknown");
        assert_eq!(word(Some("hacked"), &CHECK_WORDS), "refused");
        assert_eq!(word(None, &CHECK_WORDS), "refused");
        assert_eq!(word(Some("found"), &CHECK_WORDS), "refused", "a word of another door is not accepted");
        assert_eq!(word(Some("none"), &LOOKUP_STATES), "none");
    }
    #[test] fn uuid_and_nil_checks_are_strict() {
        assert!(uuid_ok("123e4567-e89b-12d3-a456-426614174000")); assert!(!uuid_ok("123e4567e89b12d3a456426614174000"));
        assert!(nil_uuid("00000000-0000-0000-0000-000000000000")); assert!(!nil_uuid("00000000-0000-0000-0000-000000000001"));
    }
    #[tokio::test] async fn a_lookup_answer_of_the_database_is_shaped_or_refused() {
        // states without a company never reach the Control Plane
        for (raw, want) in [(r#"{"state":"none"}"#, "none"), (r#"{"state":"no_right"}"#, "no_right"), (r#"{"state":"no_register"}"#, "no_register"), (r#"{"state":"bad_number"}"#, "bad_number"), (r#"{"state":"surprise"}"#, "refused"), ("not json", "refused")] {
            let a: serde_json::Value = serde_json::from_str(&shape_lookup("123e4567-e89b-12d3-a456-426614174000", raw).await).unwrap();
            assert_eq!(a["state"], want, "{raw}");
            assert!(a.get("tenant_id").is_none());
        }
        // a "found" with a missing or odd field is refused before anything leaves the Desk
        for raw in [r#"{"state":"found"}"#, r#"{"state":"found","tenant_id":"nope","since":"2026-11-25T00:00:00Z","shape_state":"shape_ok"}"#,
                    r#"{"state":"found","tenant_id":"00000000-0000-0000-0000-000000000000","since":"2026-11-25T00:00:00Z","shape_state":"shape_ok"}"#,
                    r#"{"state":"found","tenant_id":"123e4567-e89b-12d3-a456-426614174000","since":"2026-11-25T00:00:00Z","shape_state":"made_up"}"#] {
            let a: serde_json::Value = serde_json::from_str(&shape_lookup("123e4567-e89b-12d3-a456-426614174000", raw).await).unwrap();
            assert_eq!(a["state"], "refused", "{raw}");
        }
    }
}
