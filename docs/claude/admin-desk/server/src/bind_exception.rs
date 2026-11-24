// ANEXOMAIL ADMIN DESK bind_exception.rs (BL-46 B13 step T4b, 25 Nov 2026): the STAFF doors of the MANUAL COMPANY EXCEPTION with a second reviewer. Rust + Axum + Tokio, Rule 52 (sealed router + live Desk session + DBSC).
// Plan: D6-B13-T4-MANUAL-EXCEPTION-PLAN-25NOV.md. SQL: AD34 (desk.fadm_bind_* SECURITY DEFINER doors; desk_app has NO table right). The DATABASE decides: case.assign on both people, proposer <> decider (table CHECK, NIST AC-5),
// one open proposal per case, 24 hours, approval only through the ONE writer desk.fadm_case_bind (AD30). FOUR doors: propose, decide, withdraw, pending. The actor is ALWAYS the signed-in staff person from the session, never a body field.
// RULE 52 COMBO: S = every answer is one closed JSON shape on the sealed router; M = no mail path; L = the database writes one ledger line per step (closed words, the note never reaches the ledger), this file writes none of its own.
// T4e (25 Nov 2026): the tenant UUID is asked of the Control Plane (signed, tenant_cp.rs) BEFORE the database is called: an unknown company = outcome "no_tenant", the Control Plane not answering = 503 (nothing is proposed on a guess). The pending list carries the company NAME from the Control Plane (tenant_name + name_state ok|missing|unavailable); the name is never stored or logged.
use crate::bridge::owner;
use crate::door::{lit, rows};
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde::Deserialize;

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

/// The closed reason list, the same words as the SQL CHECK in AD34.
pub const REASONS: [&str; 5] = ["customer_emailed_from_other_domain", "new_domain_not_yet_verified", "forwarded_mail", "staff_checked_contract", "other_with_note"];
/// Every answer word the SQL doors can return; anything else is turned into "refused" (fail closed).
pub const PROPOSE_WORDS: [&str; 12] = ["proposed", "not_active_staff", "no_right", "no_case", "bad_tenant", "bad_reason", "bad_note", "already_bound", "already_open", "too_many_open", "no_tenant", "refused"];
pub const DECIDE_WORDS: [&str; 10] = ["approved", "denied", "expired", "no_proposal", "already_decided", "same_person", "no_right", "not_active_staff", "bind_refused", "refused"];
pub const WITHDRAW_WORDS: [&str; 6] = ["withdrawn", "no_proposal", "not_proposer", "already_decided", "not_active_staff", "refused"];

/// Same shape as the SQL case ref (letters, digits, _ . : -), 3..64.
pub fn valid_case(s: &str) -> bool { (3..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'_' | b'.' | b':' | b'-')) }
pub fn uuid_ok(s: &str) -> bool { s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_hexdigit() }) }
pub fn nil_uuid(s: &str) -> bool { s.bytes().all(|b| b == b'0' || b == b'-') }
/// Same bound as the SQL CHECK: at most 200 characters, no control characters; "other_with_note" needs 10 real characters.
pub fn note_ok(reason: &str, note: &str) -> bool {
    let t = note.trim(); let n = t.chars().count();
    n <= 200 && !note.chars().any(|c| c.is_control()) && (reason != "other_with_note" || n >= 10)
}
/// Turns whatever the database answered into one word of the closed list, or "refused".
pub fn word(raw: Option<&str>, list: &[&'static str]) -> &'static str { raw.and_then(|w| list.iter().find(|x| **x == w).copied()).unwrap_or("refused") }

#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct ProposeIn { case_ref: String, tenant_id: String, reason: String, #[serde(default)] note: String }
#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct DecideIn { proposal_id: String, approve: bool }
#[derive(Deserialize)] #[serde(deny_unknown_fields)] struct WithdrawIn { proposal_id: String }

fn propose_ok(b: &ProposeIn) -> bool { valid_case(&b.case_ref) && uuid_ok(&b.tenant_id) && !nil_uuid(&b.tenant_id) && REASONS.contains(&b.reason.as_str()) && note_ok(&b.reason, &b.note) }
fn status_of(w: &str) -> StatusCode { if matches!(w, "proposed" | "approved" | "denied" | "withdrawn") { StatusCode::OK } else if matches!(w, "refused") { StatusCode::FORBIDDEN } else { StatusCode::CONFLICT } }

/// POST /desk/v1/bind/propose {case_ref, tenant_id, reason, note?}: 200 {outcome:"proposed", proposal_id}; 409 {outcome: closed word}.
pub async fn propose(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 1024 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<ProposeIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if !propose_ok(&b) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    // T4e: is this company real? asked of the Control Plane first (signed, never cached). Unknown = no_tenant; no answer = nothing is proposed.
    match crate::tenant_cp::ask(&o, &b.tenant_id).await {
        Ok(crate::tenant_cp::Tenant::Exists(_)) => {}
        Ok(crate::tenant_cp::Tenant::Missing) => return out(StatusCode::CONFLICT, serde_json::json!({"outcome": "no_tenant"}).to_string()),
        Err(crate::tenant_cp::Reject::Refused) => return err(StatusCode::FORBIDDEN, "refused"),
        Err(crate::tenant_cp::Reject::Unavailable) => { eprintln!("desk bind: the Control Plane could not confirm the company"); return unavailable(); }
    }
    let q = format!("select outcome || '|' || coalesce(proposal_id::text, '') from desk.fadm_bind_propose('{o}'::uuid, {}, '{}'::uuid, {}, {})", lit(&b.case_ref), b.tenant_id, lit(&b.reason), lit(b.note.trim()));
    match rows(&c, &q).await {
        Ok(v) => {
            let raw = v.first().and_then(|r| r.get(0)).unwrap_or("");
            let (w, id) = raw.split_once('|').unwrap_or((raw, ""));
            let w = word(Some(w), &PROPOSE_WORDS);
            if w == "proposed" && uuid_ok(id) { out(StatusCode::OK, serde_json::json!({"outcome": w, "proposal_id": id}).to_string()) } else { out(if w == "proposed" { StatusCode::FORBIDDEN } else { status_of(w) }, serde_json::json!({"outcome": if w == "proposed" { "refused" } else { w }}).to_string()) }
        }
        Err(e) => { eprintln!("desk bind: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/bind/decide {proposal_id, approve}: a DIFFERENT person approves or denies. 200 {outcome:"approved"|"denied"}; 409 {outcome: closed word}.
pub async fn decide(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 256 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<DecideIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if !uuid_ok(&b.proposal_id) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    let q = format!("select desk.fadm_bind_decide('{o}'::uuid, '{}'::uuid, {})", b.proposal_id, if b.approve { "true" } else { "false" });
    match rows(&c, &q).await {
        Ok(v) => { let w = word(v.first().and_then(|r| r.get(0)), &DECIDE_WORDS); out(status_of(w), serde_json::json!({"outcome": w}).to_string()) }
        Err(e) => { eprintln!("desk bind: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/bind/withdraw {proposal_id}: only the proposer. 200 {outcome:"withdrawn"}; 409 {outcome: closed word}.
pub async fn withdraw(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 256 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let Ok(b) = serde_json::from_slice::<WithdrawIn>(&body) else { return err(StatusCode::BAD_REQUEST, "bad_body") };
    if !uuid_ok(&b.proposal_id) { return err(StatusCode::BAD_REQUEST, "bad_body"); }
    match rows(&c, &format!("select desk.fadm_bind_withdraw('{o}'::uuid, '{}'::uuid)", b.proposal_id)).await {
        Ok(v) => { let w = word(v.first().and_then(|r| r.get(0)), &WITHDRAW_WORDS); out(status_of(w), serde_json::json!({"outcome": w}).to_string()) }
        Err(e) => { eprintln!("desk bind: db: {e}"); unavailable() }
    }
}
/// POST /desk/v1/bind/pending {}: the open proposals a person with case.assign may see (case ref, company UUID, reason word, note, proposer role, seconds left, mine). No customer data, no mail text.
pub async fn pending(h: HeaderMap, body: Bytes) -> Response {
    let (c, o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let q = format!("select coalesce(json_agg(t), '[]'::json)::text from (select proposal_id, case_ref, tenant_id, reason, note, proposer_role, seconds_left, mine from desk.fadm_bind_pending('{o}'::uuid)) t");
    match rows(&c, &q).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)) {
            Some(j) if j.starts_with('[') => out(StatusCode::OK, with_names(&o, j).await),
            _ => err(StatusCode::FORBIDDEN, "not_allowed"),
        },
        Err(e) => { eprintln!("desk bind: db: {e}"); unavailable() }
    }
}

/// T4e: adds the company NAME to every pending item, asked of the Control Plane (one signed question per distinct company, at most 20, never cached). name_state = ok | missing | unavailable (the Control Plane did not answer: the screen says so, it never shows a guessed name).
async fn with_names(owner: &str, j: &str) -> String {
    let Ok(mut items) = serde_json::from_str::<Vec<serde_json::Value>>(j) else { return format!("{{\"items\":{j}}}") };
    let mut seen: Vec<(String, (&'static str, Option<String>))> = Vec::new();
    for it in items.iter_mut().take(20) {
        let t = it["tenant_id"].as_str().unwrap_or("").to_string();
        let got = match seen.iter().find(|(k, _)| *k == t) { Some((_, v)) => v.clone(), None => {
            let v = match crate::tenant_cp::ask(owner, &t).await { Ok(crate::tenant_cp::Tenant::Exists(n)) => ("ok", Some(n)), Ok(crate::tenant_cp::Tenant::Missing) => ("missing", None), Err(_) => ("unavailable", None) };
            seen.push((t.clone(), v.clone())); v } };
        it["name_state"] = serde_json::json!(got.0); it["tenant_name"] = match got.1 { Some(n) => serde_json::json!(n), None => serde_json::Value::Null };
    }
    serde_json::json!({"items": items}).to_string()
}

/// BACKGROUND EXPIRY WORKER (T4, acceptance 3): every 60 seconds one call of desk.fadm_bind_sweep() ends the stale open proposals. The DATABASE refuses an approval after 24 hours by itself (decision-time check + table CHECK),
/// so a late or dead worker can never make an old proposal approvable; the sweep only moves pending -> expired (guard trigger: an ended proposal never changes again, so a late run cannot resurrect anything) and writes
/// ONE ledger line per real transition (a second run finds nothing and writes nothing = idempotent).
pub async fn expiry_worker() {
    let mut tick = tokio::time::interval(std::time::Duration::from_secs(60));
    tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        tick.tick().await;
        match crate::door::connect().await {
            Ok(c) => match rows(&c, "select desk.fadm_bind_sweep()::text").await {
                Ok(v) => { let n = v.first().and_then(|r| r.get(0)).and_then(|x| x.parse::<i64>().ok()).unwrap_or(0); if n > 0 { eprintln!("desk bind: {n} proposal(s) ran out"); } }
                Err(e) => eprintln!("desk bind: sweep failed: {e}"),
            },
            Err(e) => eprintln!("desk bind: sweep waits for the database: {e}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn good() -> ProposeIn { ProposeIn { case_ref: "CASE-251125-00001".into(), tenant_id: "123e4567-e89b-12d3-a456-426614174000".into(), reason: "forwarded_mail".into(), note: String::new() } }
    #[test] fn propose_shape_blocks_odd_input() {
        assert!(propose_ok(&good()));
        for f in [|c: &mut ProposeIn| c.case_ref = "a'; drop table x;--".into(), |c: &mut ProposeIn| c.case_ref = "ab".into(), |c: &mut ProposeIn| c.tenant_id = "not-a-uuid".into(),
            |c: &mut ProposeIn| c.tenant_id = "00000000-0000-0000-0000-000000000000".into(), |c: &mut ProposeIn| c.reason = "because".into(),
            |c: &mut ProposeIn| c.note = "x".repeat(201), |c: &mut ProposeIn| c.note = "line\nbreak".into(), |c: &mut ProposeIn| { c.reason = "other_with_note".into(); c.note = "short".into(); }] {
            let mut c = good(); f(&mut c); assert!(!propose_ok(&c));
        }
        let mut c = good(); c.reason = "other_with_note".into(); c.note = "contract seen on paper".into(); assert!(propose_ok(&c));
    }
    #[test] fn reasons_match_the_database() { assert_eq!(REASONS, ["customer_emailed_from_other_domain", "new_domain_not_yet_verified", "forwarded_mail", "staff_checked_contract", "other_with_note"]); }
    #[test] fn bodies_reject_unknown_fields_and_a_forged_actor() {
        assert!(serde_json::from_str::<ProposeIn>(r#"{"case_ref":"CASE-1","tenant_id":"123e4567-e89b-12d3-a456-426614174000","reason":"forwarded_mail"}"#).is_ok());
        assert!(serde_json::from_str::<ProposeIn>(r#"{"case_ref":"CASE-1","tenant_id":"123e4567-e89b-12d3-a456-426614174000","reason":"forwarded_mail","actor":"x"}"#).is_err(), "the actor is the session, never a body field");
        assert!(serde_json::from_str::<DecideIn>(r#"{"proposal_id":"123e4567-e89b-12d3-a456-426614174000","approve":true,"decided_by":"x"}"#).is_err());
        assert!(serde_json::from_str::<DecideIn>(r#"{"proposal_id":"123e4567-e89b-12d3-a456-426614174000","approve":"yes"}"#).is_err());
        assert!(serde_json::from_str::<WithdrawIn>(r#"{"proposal_id":5}"#).is_err());
    }
    #[test] fn an_unknown_database_word_fails_closed() {
        assert_eq!(word(Some("approved"), &DECIDE_WORDS), "approved");
        assert_eq!(word(Some("hacked"), &DECIDE_WORDS), "refused");
        assert_eq!(word(None, &DECIDE_WORDS), "refused");
        assert_eq!(word(Some("proposed"), &DECIDE_WORDS), "refused", "a word of another door is not accepted");
        assert_eq!(word(Some("withdrawn"), &WITHDRAW_WORDS), "withdrawn");
    }
    #[test] fn http_status_follows_the_word() {
        for w in ["proposed", "approved", "denied", "withdrawn"] { assert_eq!(status_of(w), StatusCode::OK); }
        assert_eq!(status_of("refused"), StatusCode::FORBIDDEN);
        for w in ["same_person", "no_right", "already_decided", "expired", "already_open", "too_many_open"] { assert_eq!(status_of(w), StatusCode::CONFLICT); }
    }
    #[test] fn uuid_and_nil_checks_are_strict() {
        assert!(uuid_ok("123e4567-e89b-12d3-a456-426614174000")); assert!(!uuid_ok("123e4567e89b12d3a456426614174000")); assert!(!uuid_ok("123e4567-e89b-12d3-a456-42661417400g"));
        assert!(nil_uuid("00000000-0000-0000-0000-000000000000")); assert!(!nil_uuid("00000000-0000-0000-0000-000000000001"));
    }
}
