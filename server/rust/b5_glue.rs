// ============================================================================
// b5_glue.rs — B5 (G40): founder-page procedures that used to exist ONLY on Brain (Bun) — Rust PRIMARY now.
// The Bun routes stay as the fallback (frontend `rpcOrRest` falls back only on 404/501/502/503/0).
//
// Public procs (no login):   movein.capacity   movein.request   revenue.lead   status.public
// Login procs (any user):    movein.deal       outbox.send
// Founder procs (gated):     founder.movein.cockpit   founder.movein.deal
//                            founder.release.{overview,checks,run,checklist,checklist.item,deployments,
//                                             lock.list,lock.create,roadmap.list,roadmap.create}
//                            founder.revenue.pipeline
//
// Everything reads / writes the same Supabase #4 tables and RPCs as the TypeScript twins
// (server/routes/movein.ts, release.ts, revenue.ts). All decisions live in b5_core.rs (std-only, unit-tested).
// Child module of main.rs: uses its private helpers via `crate::`.
// ============================================================================

use crate::b5_core as c;
use axum::{http::HeaderMap, http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::Duration;

static RUN_IN_FLIGHT: AtomicBool = AtomicBool::new(false);
static THROTTLE: std::sync::OnceLock<Mutex<c::Throttle>> = std::sync::OnceLock::new();

pub fn public_owns(proc: &str) -> bool {
    matches!(
        proc,
        "movein.capacity" | "movein.request" | "revenue.lead" | "status.public"
    )
}

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "movein.deal"
            | "outbox.send"
            | "founder.movein.cockpit"
            | "founder.movein.deal"
            | "founder.release.overview"
            | "founder.release.checks"
            | "founder.release.run"
            | "founder.release.checklist"
            | "founder.release.checklist.item"
            | "founder.release.deployments"
            | "founder.release.lock.list"
            | "founder.release.lock.create"
            | "founder.release.roadmap.list"
            | "founder.release.roadmap.create"
            | "founder.revenue.pipeline"
    )
}

// ------------------------------------------------------------------ small helpers

fn fail(status: StatusCode, code: &str, msg: &str) -> axum::response::Response {
    crate::err(status, code, msg).into_response()
}

/// Database trouble: the detail goes to the server log, never to the browser.
fn db_fail(what: &str, e: String) -> axum::response::Response {
    eprintln!("b5: {what}: {}", c::clip(&e, 400));
    fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", "Database request failed.")
}

fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

fn random_bytes<const N: usize>() -> [u8; N] {
    use std::io::Read;
    let mut b = [0u8; N];
    if let Ok(mut f) = std::fs::File::open("/dev/urandom") {
        if f.read_exact(&mut b).is_ok() {
            return b;
        }
    }
    // /dev/urandom unavailable: clock + address entropy, hashed (never predictable enough for secrets — only for ids/refs)
    let seed = format!("{}-{:p}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0), &b);
    let h = Sha256::digest(seed.as_bytes());
    for (i, x) in b.iter_mut().enumerate() {
        *x = h[i % 32];
    }
    b
}

/// JS `String(v)` for the JSON shapes a form can send.
fn js_str(v: Option<&Value>) -> String {
    match v {
        Some(Value::String(s)) => s.clone(),
        Some(Value::Number(n)) => n.to_string(),
        Some(Value::Bool(b)) => b.to_string(),
        _ => String::new(),
    }
}

/// JS `Number(v)`: Some(NaN-as-None) for things that are not numbers.
fn js_num(v: Option<&Value>) -> Option<f64> {
    match v {
        Some(Value::Number(n)) => n.as_f64(),
        Some(Value::Null) => Some(0.0),
        Some(Value::Bool(b)) => Some(if *b { 1.0 } else { 0.0 }),
        Some(Value::String(s)) => {
            let t = s.trim();
            if t.is_empty() {
                Some(0.0)
            } else {
                t.parse::<f64>().ok().filter(|x| x.is_finite())
            }
        }
        _ => None,
    }
}

/// A database numeric column as f64 (numbers or numeric strings), 0 otherwise.
fn jnum(v: &Value) -> f64 {
    match v {
        Value::Number(n) => n.as_f64().unwrap_or(0.0),
        Value::String(s) => s.trim().parse::<f64>().unwrap_or(0.0),
        _ => 0.0,
    }
}

fn jint(v: &Value, k: &str) -> i64 {
    v.get(k).map(|x| jnum(x) as i64).unwrap_or(0)
}

fn jstr(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn num_or_null(v: &Value, k: &str) -> Value {
    match v.get(k) {
        None | Some(Value::Null) => Value::Null,
        Some(x) => json!(jnum(x)),
    }
}

fn val_or_null(v: &Value, k: &str) -> Value {
    v.get(k).cloned().unwrap_or(Value::Null)
}

async fn rows(path: &str) -> Result<Vec<Value>, String> {
    crate::sb_select(path).await.map(|v| v.as_array().cloned().unwrap_or_default())
}

// ------------------------------------------------------------------ shapers (same JSON as the Bun twins)

fn shape_check(x: &Value) -> Value {
    json!({
        "id": val_or_null(x, "id"), "suite": val_or_null(x, "suite"), "name": val_or_null(x, "name"),
        "status": val_or_null(x, "status"), "ms": num_or_null(x, "ms"), "code": num_or_null(x, "code"),
        "detail": val_or_null(x, "detail"), "at": val_or_null(x, "at"),
    })
}

fn shape_run(x: &Value) -> Value {
    json!({
        "id": val_or_null(x, "id"), "started_at": val_or_null(x, "started_at"), "finished_at": val_or_null(x, "finished_at"),
        "passed": jint(x, "passed"), "warned": jint(x, "warned"), "failed": jint(x, "failed"),
        "skipped": jint(x, "skipped"), "total": jint(x, "total"), "ms": num_or_null(x, "ms"),
        "verdict": val_or_null(x, "verdict"),
    })
}

fn shape_deployment(x: &Value) -> Value {
    json!({
        "id": val_or_null(x, "id"), "target": val_or_null(x, "target"), "commit_sha": val_or_null(x, "commit_sha"),
        "commit_subject": val_or_null(x, "commit_subject"), "actor": val_or_null(x, "actor"),
        "started_at": val_or_null(x, "started_at"), "finished_at": val_or_null(x, "finished_at"),
        "ms": num_or_null(x, "ms"), "state": val_or_null(x, "state"), "rollback_of": val_or_null(x, "rollback_of"),
        "changed_since_green": match x.get("changed_since_green") { Some(a) if a.is_array() => a.clone(), _ => json!([]) },
    })
}

fn shape_checklist(x: &Value) -> Value {
    json!({
        "id": val_or_null(x, "id"), "area": val_or_null(x, "area"), "label": val_or_null(x, "label"),
        "detail": val_or_null(x, "detail"), "state": val_or_null(x, "state"), "owner": val_or_null(x, "owner"),
        "updated_at": val_or_null(x, "updated_at"),
    })
}

fn shape_lock(x: &Value) -> Value {
    json!({
        "id": val_or_null(x, "id"), "version": val_or_null(x, "version"), "signed_by": val_or_null(x, "signed_by"),
        "signature_hash": val_or_null(x, "signature_hash"), "verdict": val_or_null(x, "verdict"),
        "frozen_at": val_or_null(x, "frozen_at"), "notes": val_or_null(x, "notes"),
    })
}

fn shape_roadmap(x: &Value) -> Value {
    json!({
        "id": val_or_null(x, "id"), "title": val_or_null(x, "title"), "area": val_or_null(x, "area"),
        "impact": x.get("impact").map(|v| if v.is_null() { 3.0 } else { jnum(v) }).unwrap_or(3.0),
        "effort": x.get("effort").map(|v| if v.is_null() { 3.0 } else { jnum(v) }).unwrap_or(3.0),
        "revenue_link": val_or_null(x, "revenue_link"), "state": val_or_null(x, "state"),
    })
}

// ------------------------------------------------------------------ public

pub async fn public(proc: &str, input: &Value, headers: &HeaderMap) -> axum::response::Response {
    match proc {
        "movein.capacity" => match rows("movein_capacity_state?select=*&order=month.asc&limit=4").await {
            Ok(r) => crate::ok(json!({ "months": r })).into_response(),
            Err(e) => db_fail("movein.capacity", e),
        },
        "movein.request" => movein_request(input).await,
        "revenue.lead" => revenue_lead(input, headers).await,
        _ => status_public().await,
    }
}

async fn movein_request(input: &Value) -> axum::response::Response {
    let g = |k: &str| js_str(input.get(k));
    let req = match c::movein_request(
        &g("company"),
        &g("email"),
        js_num(input.get("mailboxes")),
        &g("domain"),
        &g("provider"),
        &g("contact_name"),
        &g("month"),
    ) {
        Ok(r) => r,
        Err(code) => return fail(StatusCode::BAD_REQUEST, code, "Company and email are required."),
    };
    match crate::sb_rpc(
        "movein_open_deal",
        json!({
            "p_company": req.company, "p_email": req.email, "p_mailboxes": req.mailboxes,
            "p_domain": req.domain, "p_provider": req.provider, "p_contact": req.contact,
            "p_user": Value::Null, "p_month": req.month,
        }),
    )
    .await
    {
        Ok(d) => crate::ok(d).into_response(),
        Err(e) => db_fail("movein.request", e),
    }
}

fn client_ip(headers: &HeaderMap) -> String {
    headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.split(',').next())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_default()
}

async fn revenue_lead(input: &Value, headers: &HeaderMap) -> axum::response::Response {
    let ip = client_ip(headers);
    let blocked = {
        let m = THROTTLE.get_or_init(|| Mutex::new(c::Throttle::default()));
        match m.lock() {
            Ok(mut t) => t.throttled(if ip.is_empty() { "unknown" } else { &ip }, now_ms()),
            Err(_) => false,
        }
    };
    if blocked {
        return fail(StatusCode::TOO_MANY_REQUESTS, "too_many_requests", "Too many requests — try again in a few minutes.");
    }
    let kind = js_str(input.get("kind"));
    if !c::lead_kind_ok(&kind) {
        return fail(StatusCode::BAD_REQUEST, "bad_kind", "Unknown lead kind.");
    }
    let company = c::clip(js_str(input.get("company")).trim(), 200);
    let email = c::clip(js_str(input.get("email")).trim(), 200);
    if company.is_empty() || !c::valid_email(&email) {
        return fail(StatusCode::BAD_REQUEST, "company_and_valid_email_required", "Company and a valid email are required.");
    }
    let opt = |k: &str, n: usize| {
        let s = js_str(input.get(k));
        if s.is_empty() { Value::Null } else { json!(c::clip(&s, n)) }
    };
    let seats = js_num(input.get("seats")).map(|x| json!(c::js_round(x))).unwrap_or(Value::Null);
    let quote = js_num(input.get("quote_gbp"));
    let ua = c::clip(headers.get("user-agent").and_then(|v| v.to_str().ok()).unwrap_or(""), 300);
    let detail = match input.get("detail") {
        Some(d) if d.is_object() => d.clone(),
        _ => json!({}),
    };
    let reference = c::reference(&kind, now_ms(), u64::from_le_bytes(random_bytes::<8>()));
    let row = json!({
        "reference": reference, "kind": kind, "company": company, "email": email,
        "contact_name": opt("name", 200), "domain": opt("domain", 200), "seats": seats,
        "quote_gbp": quote.map(|q| json!(q)).unwrap_or(Value::Null),
        "message": opt("message", 2000), "detail": detail,
        "source_ip": if ip.is_empty() { Value::Null } else { json!(ip) },
        "user_agent": if ua.is_empty() { Value::Null } else { json!(ua) },
    });
    let inserted = match crate::sb_insert("revenue_leads", row).await {
        Ok(v) => v,
        Err(e) => return db_fail("revenue.lead", e),
    };
    let first = inserted.as_array().and_then(|a| a.first()).cloned().unwrap_or_else(|| inserted.clone());
    let lead_id = first.get("id").cloned().unwrap_or(Value::Null);

    // Side rows are best-effort (the lead itself is already saved) — same as the Bun twin.
    if kind == "migration" {
        if let Some(q) = quote.filter(|q| *q != 0.0) {
            let _ = crate::sb_insert(
                "revenue_jobs",
                json!({ "lead_id": lead_id, "kind": "migration", "company": company, "amount_gbp": q,
                        "deposit_gbp": c::deposit(q), "stage": "quoted" }),
            )
            .await;
        }
    }
    if kind == "partner" {
        let d = input.get("detail");
        let tier = c::partner_tier(&js_str(d.and_then(|x| x.get("tier"))));
        let rate = c::partner_rate(js_num(d.and_then(|x| x.get("rate"))));
        let _ = crate::sb_insert(
            "revenue_partners",
            json!({ "company": company, "email": email, "tier": tier, "commission_rate": rate, "stage": "applied" }),
        )
        .await;
    }
    crate::ok(json!({
        "id": lead_id, "reference": first.get("reference").cloned().unwrap_or(json!(reference)),
        "kind": first.get("kind").cloned().unwrap_or(json!(kind)), "created_at": val_or_null(&first, "created_at"),
    }))
    .into_response()
}

/// Public status page — it never answers with an error (it must not vanish during an outage).
async fn status_public() -> axum::response::Response {
    let degraded = || {
        crate::ok(json!({
            "state": "degraded", "updated_at": c::iso_utc(now_ms()),
            "components": [{ "name": "Status feed", "state": "degraded", "note": "Health data temporarily unavailable" }],
            "last_incident": Value::Null,
        }))
        .into_response()
    };
    let runs = match rows("release_runs?select=id,finished_at,verdict&order=started_at.desc&limit=1").await {
        Ok(r) => r,
        Err(_) => return degraded(),
    };
    let latest = runs.first().cloned();
    let suites: [(&str, &str, &str); 5] = [
        ("routes", "Workspace", "Sign-in, mail, calendar and admin surfaces"),
        ("database", "Storage", "Mail, contacts and settings storage"),
        ("mail", "Mail delivery", "Inbound and outbound mail"),
        ("ownership", "Domain authentication", "MX, SPF, DKIM and DMARC"),
        ("speed", "Performance", "Response times against our published budgets"),
    ];
    let checks: Vec<Value> = match &latest {
        Some(l) => match rows(&format!("release_checks?select=suite,status&run_id=eq.{}", c::pct(&jstr(l, "id")))).await {
            Ok(r) => r,
            Err(_) => return degraded(),
        },
        None => vec![],
    };
    let mut states: Vec<&str> = vec![];
    let components: Vec<Value> = suites
        .iter()
        .map(|(key, name, note)| {
            let mine: Vec<&Value> = checks.iter().filter(|x| jstr(x, "suite") == *key).collect();
            let f = mine.iter().filter(|x| jstr(x, "status") == "fail").count();
            let w = mine.iter().filter(|x| jstr(x, "status") == "warn").count();
            let st = c::component_state(f, w);
            states.push(st);
            json!({ "name": name, "state": st, "note": note })
        })
        .collect();
    let last_incident = match rows("incidents?select=title,started_at,resolved_at&order=started_at.desc&limit=1").await {
        Ok(r) => r.first().map(|i| json!({ "title": val_or_null(i, "title"), "started_at": val_or_null(i, "started_at"), "resolved_at": val_or_null(i, "resolved_at") })).unwrap_or(Value::Null),
        Err(_) => Value::Null,
    };
    let updated = latest
        .as_ref()
        .and_then(|l| l.get("finished_at"))
        .filter(|v| !v.is_null())
        .cloned()
        .unwrap_or_else(|| json!(c::iso_utc(now_ms())));
    crate::ok(json!({
        "state": c::worst_state(&states), "updated_at": updated, "components": components, "last_incident": last_incident,
    }))
    .into_response()
}

// ------------------------------------------------------------------ login procs

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    let (id, email) = match crate::auth_user(token).await {
        Some(u) => u,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid"),
    };
    if proc.starts_with("founder.") && !crate::is_founder(&id, &email).await {
        return fail(StatusCode::FORBIDDEN, "founder_only", "Founder access required.");
    }
    let email_or_founder = if email.trim().is_empty() { "founder".to_string() } else { email.clone() };
    match proc {
        "movein.deal" => customer_deal(&id, input).await,
        "outbox.send" => outbox_send(&id, input).await,
        "founder.movein.cockpit" => match crate::sb_rpc("movein_cockpit", json!({})).await {
            Ok(d) => crate::ok(d).into_response(),
            Err(e) => db_fail("movein_cockpit", e),
        },
        "founder.movein.deal" => {
            let deal = js_str(input.get("id"));
            if !c::uuid_shape_ok(&deal) {
                return fail(StatusCode::BAD_REQUEST, "bad_request", "A deal id is required.");
            }
            match crate::sb_rpc("movein_evidence_bundle", json!({ "p_deal": deal })).await {
                Ok(d) => crate::ok(json!({ "deal": d })).into_response(),
                Err(e) => db_fail("movein_evidence_bundle", e),
            }
        }
        "founder.release.overview" => release_overview().await,
        "founder.release.checks" => release_checks().await,
        "founder.release.run" => release_run(&id, input).await,
        "founder.release.checklist" => match rows("release_checklist?select=*&order=area.asc,label.asc").await {
            Ok(r) => crate::ok(json!({ "items": r.iter().map(shape_checklist).collect::<Vec<_>>() })).into_response(),
            Err(e) => db_fail("checklist", e),
        },
        "founder.release.checklist.item" => checklist_item(&email_or_founder, input).await,
        "founder.release.deployments" => match rows("deployments?select=*&order=started_at.desc&limit=50").await {
            Ok(r) => crate::ok(json!({ "deployments": r.iter().map(shape_deployment).collect::<Vec<_>>() })).into_response(),
            Err(e) => db_fail("deployments", e),
        },
        "founder.release.lock.list" => match rows("release_locks?select=*&order=frozen_at.desc&limit=20").await {
            Ok(r) => crate::ok(json!({ "locks": r.iter().map(shape_lock).collect::<Vec<_>>() })).into_response(),
            Err(e) => db_fail("locks", e),
        },
        "founder.release.lock.create" => lock_create(&id, &email_or_founder, input).await,
        "founder.release.roadmap.list" => match rows("roadmap_items?select=*&order=created_at.desc&limit=200").await {
            Ok(r) => crate::ok(json!({ "items": r.iter().map(shape_roadmap).collect::<Vec<_>>() })).into_response(),
            Err(e) => db_fail("roadmap", e),
        },
        "founder.release.roadmap.create" => roadmap_create(&id, input).await,
        "founder.revenue.pipeline" => revenue_pipeline().await,
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown procedure."),
    }
}

/// Customer portal: the caller's newest deal, or one explicit deal they own.
async fn customer_deal(uid: &str, input: &Value) -> axum::response::Response {
    if !c::uuid_shape_ok(uid) {
        return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid");
    }
    let wanted = js_str(input.get("id"));
    let deal_id: Option<String> = if wanted.is_empty() {
        match rows(&format!("movein_deals?select=id&user_id=eq.{uid}&order=created_at.desc&limit=1")).await {
            Ok(r) => r.first().map(|x| jstr(x, "id")).filter(|s| !s.is_empty()),
            Err(e) => return db_fail("movein.deal", e),
        }
    } else {
        if !c::uuid_shape_ok(&wanted) {
            return fail(StatusCode::NOT_FOUND, "not_found", "Deal not found.");
        }
        match rows(&format!("movein_deals?select=id&id=eq.{wanted}&or=(user_id.eq.{uid},owner_id.eq.{uid})&limit=1")).await {
            Ok(r) if !r.is_empty() => Some(wanted),
            Ok(_) => return fail(StatusCode::NOT_FOUND, "not_found", "Deal not found."),
            Err(e) => return db_fail("movein.deal", e),
        }
    };
    let Some(id) = deal_id else {
        return crate::ok(json!({ "deal": Value::Null })).into_response();
    };
    match crate::sb_rpc("movein_customer_view", json!({ "p_deal": id })).await {
        Ok(d) => crate::ok(json!({ "deal": d })).into_response(),
        Err(e) => db_fail("movein_customer_view", e),
    }
}

/// Offline outbox: same key = same result, never two mails. State becomes "sent" only when the mail pipeline says so.
async fn outbox_send(uid: &str, input: &Value) -> axum::response::Response {
    let key = js_str(input.get("idempotency_key"));
    let to = js_str(input.get("to")).trim().to_string();
    if key.is_empty() || to.is_empty() || key.len() > 200 {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "idempotency_key + to required");
    }
    let lookup = || async {
        rows(&format!("mail_outbox?select=id,state,sent_at,user_id&idempotency_key=eq.{}&limit=1", c::pct(&key))).await
    };
    let existing = match lookup().await {
        Ok(r) => r.first().cloned(),
        Err(e) => return db_fail("outbox.lookup", e),
    };
    let dup = |f: &Value| crate::ok(json!({ "id": val_or_null(f, "id"), "state": val_or_null(f, "state"), "sent_at": val_or_null(f, "sent_at"), "duplicate": true })).into_response();
    if let Some(f) = &existing {
        // A key that belongs to someone else is not theirs to read.
        if jstr(f, "user_id") != uid {
            return fail(StatusCode::CONFLICT, "idempotency_conflict", "This idempotency key is already in use.");
        }
        return dup(f);
    }
    let thread = js_str(input.get("thread_id"));
    let row = json!({
        "user_id": uid, "idempotency_key": key, "to_address": to,
        "subject": c::clip(&js_str(input.get("subject")), 998), "body": js_str(input.get("body")),
        "thread_id": if thread.is_empty() { Value::Null } else { json!(thread) },
        "state": "queued", "attempts": 0,
    });
    match crate::sb_insert("mail_outbox", row).await {
        Ok(v) => {
            let d = v.as_array().and_then(|a| a.first()).cloned().unwrap_or(v);
            crate::ok(json!({ "id": val_or_null(&d, "id"), "state": val_or_null(&d, "state"), "sent_at": val_or_null(&d, "sent_at"), "duplicate": false })).into_response()
        }
        Err(e) => {
            // two taps at the same moment: the unique key made the second insert fail — answer with the first row
            if e.contains("23505") || e.contains("duplicate key") {
                if let Ok(r) = lookup().await {
                    if let Some(f) = r.first() {
                        if jstr(f, "user_id") == uid {
                            return dup(f);
                        }
                    }
                }
            }
            db_fail("outbox.insert", e)
        }
    }
}

// ------------------------------------------------------------------ release gate

async fn release_checks() -> axum::response::Response {
    let runs = match rows("release_runs?select=*&order=started_at.desc&limit=10").await {
        Ok(r) => r,
        Err(e) => return db_fail("release_runs", e),
    };
    let checks = match runs.first() {
        Some(l) => match rows(&format!("release_checks?select=*&run_id=eq.{}&order=suite.asc,name.asc", c::pct(&jstr(l, "id")))).await {
            Ok(r) => r,
            Err(e) => return db_fail("release_checks", e),
        },
        None => vec![],
    };
    crate::ok(json!({ "runs": runs.iter().map(shape_run).collect::<Vec<_>>(), "checks": checks.iter().map(shape_check).collect::<Vec<_>>() })).into_response()
}

async fn release_overview() -> axum::response::Response {
    let (run_q, lock_q, list_q, dep_q) = tokio::join!(
        rows("release_runs?select=*&order=started_at.desc&limit=1"),
        rows("release_locks?select=*&order=frozen_at.desc&limit=1"),
        rows("release_checklist?select=*"),
        rows("deployments?select=*&order=started_at.desc&limit=1"),
    );
    let latest = run_q.unwrap_or_default().first().cloned();
    let lock = lock_q.unwrap_or_default().first().cloned();
    let items = list_q.unwrap_or_default();
    let dep = dep_q.unwrap_or_default().first().cloned();

    let mut blockers: Vec<Value> = items
        .iter()
        .filter(|i| jstr(i, "state") == "blocker")
        .map(|i| json!({ "id": val_or_null(i, "id"), "label": val_or_null(i, "label"), "suite": format!("checklist · {}", jstr(i, "area")), "detail": val_or_null(i, "detail") }))
        .collect();
    if let Some(l) = &latest {
        if jint(l, "failed") > 0 {
            if let Ok(fc) = rows(&format!("release_checks?select=id,suite,name,detail&run_id=eq.{}&status=eq.fail&limit=25", c::pct(&jstr(l, "id")))).await {
                for x in fc {
                    blockers.push(json!({ "id": val_or_null(&x, "id"), "label": val_or_null(&x, "name"), "suite": val_or_null(&x, "suite"), "detail": val_or_null(&x, "detail") }));
                }
            }
        }
    }
    crate::ok(json!({
        "gate": c::gate(lock.is_some(), latest.is_some(), blockers.len()),
        "version": lock.as_ref().map(|l| val_or_null(l, "version")).unwrap_or(Value::Null),
        "locked_at": lock.as_ref().map(|l| val_or_null(l, "frozen_at")).unwrap_or(Value::Null),
        "latest_run": latest.as_ref().map(shape_run).unwrap_or(Value::Null),
        "blockers": blockers,
        "checklist_open": items.iter().filter(|i| jstr(i, "state") != "done").count(),
        "checklist_total": items.len(),
        "last_deployment": dep.as_ref().map(shape_deployment).unwrap_or(Value::Null),
    }))
    .into_response()
}

async fn checklist_item(owner: &str, input: &Value) -> axum::response::Response {
    let id = js_str(input.get("id"));
    let state = js_str(input.get("state"));
    if !c::uuid_shape_ok(&id) || !c::checklist_state_ok(&state) {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "id + state (open|done|blocker) required");
    }
    if let Err(e) = crate::sb_patch(
        &format!("release_checklist?id=eq.{id}"),
        json!({ "state": state, "owner": owner, "updated_at": c::iso_utc(now_ms()) }),
    )
    .await
    {
        return db_fail("checklist.update", e);
    }
    match rows(&format!("release_checklist?select=*&id=eq.{id}&limit=1")).await {
        Ok(r) => match r.first() {
            Some(x) => crate::ok(shape_checklist(x)).into_response(),
            None => fail(StatusCode::NOT_FOUND, "not_found", "Checklist item not found."),
        },
        Err(e) => db_fail("checklist.read", e),
    }
}

async fn lock_create(uid: &str, email: &str, input: &Value) -> axum::response::Response {
    let version = js_str(input.get("version")).trim().to_string();
    if version.is_empty() {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "version required");
    }
    let override_reason = js_str(input.get("override_reason"));
    match rows(&format!("release_locks?select=id&version=eq.{}&limit=1", c::pct(&version))).await {
        Ok(r) if !r.is_empty() => return fail(StatusCode::CONFLICT, "already_locked", &format!("v{version} is already frozen")),
        Ok(_) => {}
        Err(e) => return db_fail("lock.exists", e),
    }
    let latest = match rows("release_runs?select=*&order=started_at.desc&limit=1").await {
        Ok(r) => r.first().cloned(),
        Err(e) => return db_fail("lock.run", e),
    };
    let Some(latest) = latest else {
        return fail(StatusCode::PRECONDITION_FAILED, "no_run", "Run the QA suite first");
    };
    let blockers = crate::sb_count("release_checklist?select=*&state=eq.blocker").await.unwrap_or(0);
    let failed = jint(&latest, "failed");
    let red = failed > 0 || blockers > 0;
    if red && override_reason.is_empty() {
        return fail(
            StatusCode::PRECONDITION_FAILED,
            "gate_red",
            &format!("{failed} failing checks and {blockers} blockers — fix them or send override_reason"),
        );
    }
    let frozen_at = c::iso_utc(now_ms());
    let run_verdict = jstr(&latest, "verdict");
    let payload = c::lock_signature_payload(&version, email, &frozen_at, &jstr(&latest, "id"), &run_verdict, jint(&latest, "passed"), failed, &override_reason);
    let signature: String = Sha256::digest(payload.as_bytes()).iter().map(|b| format!("{:02x}", b)).collect();
    let notes = js_str(input.get("notes"));
    let row = json!({
        "version": version, "signed_by": email, "user_id": uid, "run_id": latest.get("id").cloned().unwrap_or(Value::Null),
        "verdict": if red { format!("override({run_verdict})") } else { run_verdict },
        "signature_hash": signature, "frozen_at": frozen_at,
        "notes": if notes.is_empty() { Value::Null } else { json!(notes) },
        "override_reason": if override_reason.is_empty() { Value::Null } else { json!(override_reason) },
    });
    match crate::sb_insert("release_locks", row).await {
        Ok(v) => {
            let d = v.as_array().and_then(|a| a.first()).cloned().unwrap_or(v);
            crate::ok(shape_lock(&d)).into_response()
        }
        Err(e) if e.contains("23505") => fail(StatusCode::CONFLICT, "already_locked", &format!("v{version} is already frozen")),
        Err(e) => db_fail("lock.insert", e),
    }
}

async fn roadmap_create(uid: &str, input: &Value) -> axum::response::Response {
    let title = js_str(input.get("title")).trim().to_string();
    if title.is_empty() {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "title required");
    }
    let area = js_str(input.get("area"));
    let link = js_str(input.get("revenue_link"));
    let row = json!({
        "user_id": uid, "title": c::clip(&title, 300),
        "area": if area.is_empty() { "general".to_string() } else { c::clip(&area, 80) },
        "impact": c::clamp_1_5(js_num(input.get("impact")).or(if input.get("impact").is_none() { None } else { Some(f64::NAN) })),
        "effort": c::clamp_1_5(js_num(input.get("effort")).or(if input.get("effort").is_none() { None } else { Some(f64::NAN) })),
        "revenue_link": if link.is_empty() { Value::Null } else { json!(c::clip(&link, 300)) },
        "state": c::roadmap_state(&js_str(input.get("state"))),
    });
    match crate::sb_insert("roadmap_items", row).await {
        Ok(v) => {
            let d = v.as_array().and_then(|a| a.first()).cloned().unwrap_or(v);
            crate::ok(shape_roadmap(&d)).into_response()
        }
        Err(e) => db_fail("roadmap.insert", e),
    }
}

// ------------------------------------------------------------------ QA run (real probes, nothing mocked)

struct Probe {
    suite: &'static str,
    name: String,
    status: &'static str,
    ms: Option<i64>,
    code: Option<i64>,
    detail: Option<String>,
}

const GUARDED: &[(&str, &str)] = &[
    ("auth session", "/api/auth/session"),
    ("workspace", "/api/workspace/overview"),
    ("dashboard", "/api/dashboard/overview"),
    ("mail threads", "/api/mail/threads"),
    ("compose drafts", "/api/mail/drafts"),
    ("contacts", "/api/contacts"),
    ("calendar events", "/api/calendar/events"),
    ("crm pipeline", "/api/crm/pipeline"),
    ("org members", "/api/org/members"),
    ("settings list", "/api/settings/list"),
    ("settings history", "/api/settings/history"),
    ("admin health", "/api/admin/health"),
    ("admin monitoring", "/api/admin/monitoring"),
    ("admin diagnostics", "/api/admin/diagnostics"),
    ("security devices", "/api/security/devices"),
    ("security sessions", "/api/security/sessions"),
    ("security proof", "/api/security/proof"),
    ("perf budgets", "/api/perf/budgets"),
    ("perf prefetch", "/api/perf/prefetch"),
    ("integrations providers", "/api/integrations/providers"),
    ("integrations exports", "/api/integrations/exports"),
    ("mail handoff", "/api/mail/handoff"),
    ("founder overview", "/api/founder/overview"),
    ("founder mailboxes", "/api/founder/mailboxes"),
    ("founder revenue", "/api/founder/revenue/overview"),
    ("founder release", "/api/founder/release/overview"),
];

const TABLES: &[&str] = &[
    "mail_threads", "mail_messages", "mail_domains", "mailboxes", "mail_outbox", "contacts", "calendar_events",
    "crm_deals", "org_members", "setting_values", "admin_health_checks", "diagnostic_runs", "security_devices",
    "security_ledger", "perf_budgets", "perf_samples", "integration_connections", "export_jobs", "revenue_leads",
    "revenue_accounts", "revenue_targets", "release_checks", "release_runs", "deployments", "release_locks",
    "roadmap_items", "subscription_pipeline",
];

fn brain_origin() -> String {
    let v = crate::env_var("SELF_ORIGIN");
    if v.starts_with("http") {
        return v.trim_end_matches('/').to_string();
    }
    let p = crate::env_var("BRAIN_PORT");
    format!("http://127.0.0.1:{}", if p.is_empty() { "3100".to_string() } else { p })
}

async fn http_probe(suite: &'static str, name: &str, base: &str, path: &str, ok_codes: &[u16]) -> Probe {
    let started = std::time::Instant::now();
    let res = crate::http().get(format!("{base}{path}")).timeout(Duration::from_millis(3000)).send().await;
    let ms = started.elapsed().as_millis() as i64;
    match res {
        Ok(r) => {
            let code = r.status().as_u16();
            let good = ok_codes.contains(&code);
            Probe {
                suite, name: name.to_string(), status: c::http_probe_status(good, ms), ms: Some(ms), code: Some(code as i64),
                detail: Some(if good { path.to_string() } else { format!("{path} returned {code}, expected {}", ok_codes.iter().map(|x| x.to_string()).collect::<Vec<_>>().join("/")) }),
            }
        }
        Err(e) => Probe { suite, name: name.to_string(), status: "fail", ms: Some(ms), code: None, detail: Some(format!("{path} unreachable: {}", c::clip(&e.to_string(), 160))) },
    }
}

async fn table_probe(table: &'static str) -> Probe {
    let started = std::time::Instant::now();
    let r = crate::sb_count(&format!("{table}?select=*")).await;
    let ms = started.elapsed().as_millis() as i64;
    match r {
        Ok(n) => Probe { suite: "database", name: format!("table {table}"), status: "pass", ms: Some(ms), code: Some(200), detail: Some(format!("{n} rows")) },
        Err(e) => Probe { suite: "database", name: format!("table {table}"), status: "fail", ms: Some(ms), code: None, detail: Some(c::clip(&e, 200)) },
    }
}

async fn mail_probes() -> Vec<Probe> {
    let mut out = vec![];
    match rows("mail_domains?select=domain,dkim,spf,dmarc,mx").await {
        Err(e) => out.push(Probe { suite: "mail", name: "mail_domains".into(), status: "fail", ms: None, code: None, detail: Some(c::clip(&e, 200)) }),
        Ok(list) => {
            for d in list {
                let bad: Vec<&str> = ["dkim", "spf", "dmarc", "mx"]
                    .into_iter()
                    .filter(|k| {
                        let v = d.get(*k);
                        let is_true = matches!(v, Some(Value::Bool(true)));
                        let present = matches!(v, Some(x) if !x.is_null() && *x != json!(false) && *x != json!("") && *x != json!(0));
                        present && !c::dns_value_ok(v.and_then(|x| x.as_str()), is_true)
                    })
                    .collect();
                out.push(Probe {
                    suite: "mail", name: format!("domain {}", jstr(&d, "domain")), status: if bad.is_empty() { "pass" } else { "fail" }, ms: None, code: None,
                    detail: Some(if bad.is_empty() { "MX / SPF / DKIM / DMARC green".to_string() } else { format!("needs attention: {}", bad.join(", ")) }),
                });
            }
        }
    }
    let held = crate::sb_count("mail_outbox?select=*&state=in.(queued,failed)").await.unwrap_or(0);
    out.push(Probe { suite: "mail", name: "outbox backlog".into(), status: c::backlog_status(held), ms: None, code: None, detail: Some(format!("{held} messages waiting")) });
    out
}

async fn ownership_probes() -> Vec<Probe> {
    let started = std::time::Instant::now();
    match rows("diagnostic_probes?select=probe,target,result,ms&order=at.desc&limit=40").await {
        Err(e) => vec![Probe { suite: "ownership", name: "diagnostic probes".into(), status: "fail", ms: Some(started.elapsed().as_millis() as i64), code: None, detail: Some(c::clip(&e, 200)) }],
        Ok(list) if list.is_empty() => vec![Probe { suite: "ownership", name: "DNS / DKIM / SPF / DMARC / TLS".into(), status: "warn", ms: None, code: None, detail: Some("No diagnostics run yet — run Admin → Diagnostics".into()) }],
        Ok(list) => {
            let mut seen = std::collections::HashSet::new();
            let mut out = vec![];
            for r in list {
                let target = jstr(&r, "target");
                let key = format!("{}:{}", jstr(&r, "probe"), target);
                if !seen.insert(key) {
                    continue;
                }
                let result = jstr(&r, "result");
                out.push(Probe {
                    suite: "ownership",
                    name: if target.is_empty() { jstr(&r, "probe") } else { format!("{} · {}", jstr(&r, "probe"), target) },
                    status: c::ownership_status(&result), ms: r.get("ms").filter(|v| !v.is_null()).map(|v| jnum(v) as i64), code: None, detail: Some(result),
                });
            }
            out.truncate(10);
            out
        }
    }
}

async fn speed_probes() -> Vec<Probe> {
    let budgets = match rows("perf_budgets?select=action,label,budget_ms").await {
        Err(e) => return vec![Probe { suite: "speed", name: "perf budgets".into(), status: "fail", ms: None, code: None, detail: Some(c::clip(&e, 200)) }],
        Ok(b) => b,
    };
    if budgets.is_empty() {
        return vec![Probe { suite: "speed", name: "perf budgets".into(), status: "warn", ms: None, code: None, detail: Some("No budgets seeded".into()) }];
    }
    let since = c::iso_utc(now_ms() - 7 * 86_400_000);
    let samples = rows(&format!("perf_samples?select=action,duration_ms&at=gt.{}&limit=20000", c::pct(&since))).await.unwrap_or_default();
    budgets
        .iter()
        .map(|b| {
            let action = jstr(b, "action");
            let mut mine: Vec<f64> = samples.iter().filter(|s| jstr(s, "action") == action).map(|s| s.get("duration_ms").map(jnum).unwrap_or(0.0)).collect();
            mine.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
            let label = jstr(b, "label");
            let budget = b.get("budget_ms").map(jnum).unwrap_or(0.0);
            if mine.is_empty() {
                return Probe { suite: "speed", name: label, status: "skip", ms: None, code: None, detail: Some("no samples in 7 days".into()) };
            }
            let p = c::p95(&mine);
            Probe {
                suite: "speed", name: label, status: c::speed_status(p, budget), ms: Some(p as i64), code: None,
                detail: Some(format!("p95 {}ms vs budget {}ms · {} samples", p.round() as i64, budget as i64, mine.len())),
            }
        })
        .collect()
}

async fn run_suite(suite: &str) -> Vec<Probe> {
    let all = suite == "all";
    let mut set: tokio::task::JoinSet<Vec<Probe>> = tokio::task::JoinSet::new();
    if all || suite == "routes" {
        let base = brain_origin();
        let b = base.clone();
        set.spawn(async move { vec![http_probe("routes", "health", &b, "/api/health", &[200]).await] });
        let b = base.clone();
        set.spawn(async move { vec![http_probe("routes", "public status", &b, "/api/public/status", &[200]).await] });
        // B5: the Rust engine itself is now part of the gate
        set.spawn(async move { vec![http_probe("routes", "rust engine health", "http://127.0.0.1:3200", "/rpc/health", &[200]).await] });
        for (name, path) in GUARDED {
            let b = base.clone();
            set.spawn(async move { vec![http_probe("routes", name, &b, path, &[200, 401]).await] });
        }
    }
    if all || suite == "database" {
        for t in TABLES {
            set.spawn(async move { vec![table_probe(t).await] });
        }
    }
    if all || suite == "mail" {
        set.spawn(mail_probes());
    }
    if all || suite == "ownership" {
        set.spawn(ownership_probes());
    }
    if all || suite == "speed" {
        set.spawn(speed_probes());
    }
    let mut out = vec![];
    while let Some(r) = set.join_next().await {
        if let Ok(mut v) = r {
            out.append(&mut v);
        }
    }
    // stable order: suites in the Bun order, then by name
    let rank = |s: &str| ["routes", "database", "mail", "ownership", "speed"].iter().position(|x| *x == s).unwrap_or(9);
    out.sort_by(|a, b| rank(a.suite).cmp(&rank(b.suite)).then(a.name.cmp(&b.name)));
    out
}

struct RunGuard;
impl Drop for RunGuard {
    fn drop(&mut self) {
        RUN_IN_FLIGHT.store(false, Ordering::SeqCst);
    }
}

async fn release_run(uid: &str, input: &Value) -> axum::response::Response {
    if RUN_IN_FLIGHT.swap(true, Ordering::SeqCst) {
        return fail(StatusCode::CONFLICT, "run_in_flight", "A QA run is already in progress.");
    }
    let _guard = RunGuard;
    let suite = {
        let s = js_str(input.get("suite"));
        if matches!(s.as_str(), "routes" | "database" | "mail" | "ownership" | "speed") { s } else { "all".to_string() }
    };
    let started = now_ms();
    let probes = run_suite(&suite).await;
    let finished = now_ms();
    let count = |s: &str| probes.iter().filter(|p| p.status == s).count() as i64;
    let (passed, warned, failed, skipped) = (count("pass"), count("warn"), count("fail"), count("skip"));
    let ms = finished - started;
    let verdict = c::verdict(failed, warned);
    let run_id = c::uuid_v4(random_bytes::<16>());
    if let Err(e) = crate::sb_insert(
        "release_runs",
        json!({ "id": run_id, "user_id": uid, "suite": suite, "started_at": c::iso_utc(started), "finished_at": c::iso_utc(finished),
                "passed": passed, "warned": warned, "failed": failed, "skipped": skipped, "total": probes.len(), "ms": ms, "verdict": verdict }),
    )
    .await
    {
        return db_fail("release_runs.insert", e);
    }
    let rows_json: Vec<Value> = probes
        .iter()
        .map(|p| json!({ "run_id": run_id, "user_id": uid, "suite": p.suite, "name": p.name, "status": p.status, "ms": p.ms, "code": p.code, "detail": p.detail }))
        .collect();
    let inserted = match crate::sb_insert("release_checks", Value::Array(rows_json)).await {
        Ok(v) => v.as_array().cloned().unwrap_or_default(),
        Err(e) => return db_fail("release_checks.insert", e),
    };
    crate::ok(json!({
        "run": { "id": run_id, "started_at": c::iso_utc(started), "finished_at": c::iso_utc(finished), "passed": passed, "warned": warned,
                 "failed": failed, "skipped": skipped, "total": probes.len(), "ms": ms, "verdict": verdict },
        "checks": inserted.iter().map(shape_check).collect::<Vec<_>>(),
    }))
    .into_response()
}

// ------------------------------------------------------------------ revenue pipeline truth

async fn revenue_pipeline() -> axum::response::Response {
    let (acc_q, lead_q, tgt_q, partner_q, pipe_q) = tokio::join!(
        rows("revenue_accounts?select=plan,seats,mrr_gbp,sla_addon,state"),
        rows("revenue_leads?select=id,reference,company,kind,stage,seats,quote_gbp,created_at&order=created_at.desc&limit=100"),
        rows("revenue_targets?select=target_gbp&order=month.desc&limit=1"),
        rows("revenue_partners?select=company,tier,live_seats,commission_gbp,stage"),
        rows("subscription_pipeline?select=lead_id,plan_seats,expected_mrr_gbp,stage"),
    );
    let accounts = acc_q.unwrap_or_default();
    let leads = lead_q.unwrap_or_default();
    let partners = partner_q.unwrap_or_default();
    let pipe_rows = pipe_q.unwrap_or_default();

    let live: Vec<&Value> = accounts.iter().filter(|a| jstr(a, "state") != "cancelled").collect();
    let subs_mrr: f64 = live.iter().map(|a| a.get("mrr_gbp").map(jnum).unwrap_or(0.0)).sum();
    let sla_n = live.iter().filter(|a| matches!(a.get("sla_addon"), Some(Value::Bool(true)))).count() as i64;
    let sla_mrr = sla_n * c::SLA_MRR_PER_ACCOUNT;
    let partner_mrr: f64 = partners
        .iter()
        .filter(|p| matches!(jstr(p, "stage").as_str(), "active" | "live"))
        .map(|p| p.get("commission_gbp").map(jnum).unwrap_or(0.0))
        .sum();
    let target = tgt_q.unwrap_or_default().first().and_then(|t| t.get("target_gbp")).map(jnum).unwrap_or(500.0);
    let committed = subs_mrr + sla_mrr as f64 + partner_mrr;

    let open: Vec<&Value> = leads.iter().filter(|l| jstr(l, "stage") != "lost").collect();
    let pipeline: Vec<Value> = open
        .iter()
        .map(|l| {
            let lid = l.get("id").cloned().unwrap_or(Value::Null);
            let linked = pipe_rows.iter().find(|p| p.get("lead_id") == Some(&lid));
            let stage = { let s = jstr(l, "stage"); if s.is_empty() { "new".to_string() } else { s } };
            let weight = c::stage_weight(&stage);
            let seats = linked
                .and_then(|p| p.get("plan_seats")).filter(|v| !v.is_null()).map(jnum)
                .or_else(|| l.get("seats").filter(|v| !v.is_null()).map(jnum))
                .unwrap_or(1.0);
            let linked_expected = linked.and_then(|p| p.get("expected_mrr_gbp")).filter(|v| !v.is_null()).map(jnum);
            let kind = jstr(l, "kind");
            json!({
                "id": lid, "reference": val_or_null(l, "reference"), "company": val_or_null(l, "company"), "stage": stage, "weight": weight,
                "plan_seats": seats, "expected_mrr_gbp": c::expected_mrr(linked_expected, seats, weight),
                "offer": c::offer_label(&kind),
                "one_off_gbp": if kind == "migration" && l.get("quote_gbp").map(|v| !v.is_null()).unwrap_or(false) { json!(jnum(&l["quote_gbp"])) } else { Value::Null },
            })
        })
        .collect();
    let pipeline_mrr: i64 = pipeline.iter().map(|p| p["expected_mrr_gbp"].as_i64().unwrap_or(0)).sum();
    let one_off: f64 = leads
        .iter()
        .filter(|l| jstr(l, "kind") == "migration" && jstr(l, "stage") == "won")
        .map(|l| l.get("quote_gbp").map(jnum).unwrap_or(0.0))
        .sum();

    let mut committed_streams = vec![];
    let mut push = |stream: &str, mrr: i64, accounts: usize| {
        if accounts > 0 || mrr > 0 {
            committed_streams.push(json!({ "stream": stream, "mrr_gbp": mrr, "accounts": accounts }));
        }
    };
    push("Subscriptions (Basic/Pro/Business)", c::js_round(subs_mrr), live.len());
    push("Priority Support retainer", sla_mrr, sla_n as usize);
    push("Partner commission", c::js_round(partner_mrr), partners.len());

    crate::ok(json!({
        "target_gbp": target, "committed_mrr_gbp": c::js_round(committed), "pipeline_mrr_gbp": pipeline_mrr,
        "one_off_cash_gbp": c::js_round(one_off), "gap_gbp": c::gap(target, committed),
        "committed": committed_streams, "pipeline": pipeline,
    }))
    .into_response()
}
