// ============================================================================
// people_glue.rs — the I/O half of "bring your address book with you" (Rust-first; Bun route = fallback only).
//
// Procedures (all authenticated, all scoped to the CALLER'S organisation):
//   people.import           rows -> People (every plan)
//   crm.leadsImport         rows -> Leads  (plans that have CRM — Pro and up; nobody is "a person you know" until you say so)
//   crm.leadsMoveToPeople   confirmed leads -> People (plans that have CRM)
//
// Same rules as the TypeScript twin (server/routes/people-import.ts), which stays on Brain as the fallback:
//   * nothing here sends mail, invites or contacts anyone — it only writes rows;
//   * the browser is never trusted: people_core::clean_import re-validates every row (differential-tested against the TS);
//   * an organisation's People are never overwritten (PostgREST `resolution=ignore-duplicates`, plus a look-up first);
//   * "move to people" can only touch leads the caller can already see (owner scope), never another organisation's.
//
// Child module of the crate root (main.rs): it uses the root's private helpers (`sb`, `sb_select`, `sb_insert`, `sb_patch`,
// `sb_rpc`, `auth_user`, `ok`, `err`). It adds NO dependency — only axum, serde_json and reqwest, which main.rs already uses.
// ============================================================================

use crate::people_core::{self as pc, CleanRow, RawRow, MAX_IMPORT_ROWS};
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use std::collections::HashSet;

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "people.import" | "crm.leadsImport" | "crm.leadsMoveToPeople"
    )
}

fn fail(status: StatusCode, code: &str, msg: &str) -> axum::response::Response {
    crate::err(status, code, msg).into_response()
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn opt_str(v: &Value, k: &str) -> Option<String> {
    v.get(k).and_then(|x| x.as_str()).map(|s| s.to_string())
}

struct Ctx {
    id: String,
    email: String,
    org_id: String,
    tier: String,
    /// Everyone in the organisation (lower-case e-mails) — the Business-plan lead scope.
    members: Vec<String>,
}

/// Who is asking, for which organisation, on which plan. Mirrors ctx() in people-import.ts, and (unlike the generic
/// mail identity) ignores revoked memberships and refuses read-only roles.
async fn ctx(token: &str, input: &Value) -> Result<Ctx, axum::response::Response> {
    let (id, email) = match crate::auth_user(token).await {
        Some(x) => x,
        None => {
            return Err(fail(
                StatusCode::UNAUTHORIZED,
                "unauthorized",
                "Session invalid",
            ))
        }
    };
    let email = email.trim().to_lowercase();
    let rows = crate::sb_select(&format!(
        "org_members?select=org_id,role,status&user_id=eq.{}",
        pc::pct(&id)
    ))
    .await
    .map_err(|_| {
        fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "server_error",
            "Import failed",
        )
    })?;
    let live: Vec<Value> = rows
        .as_array()
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter(|m| !st(m, "org_id").is_empty() && st(m, "status") != "revoked")
        .collect();
    if live.is_empty() {
        return Err(fail(StatusCode::CONFLICT, "no_workspace", "no_workspace"));
    }
    let requested = st(input, "org_id");
    let pick = live
        .iter()
        .find(|m| !requested.is_empty() && st(m, "org_id") == requested)
        .unwrap_or(&live[0]);
    if st(pick, "role") == "viewer" {
        return Err(fail(
            StatusCode::FORBIDDEN,
            "read_only",
            "Your role in this workspace is read-only.",
        ));
    }
    let org_id = st(pick, "org_id");
    let members: Vec<String> = crate::sb_select(&format!(
        "org_members?select=email&org_id=eq.{}",
        pc::pct(&org_id)
    ))
    .await
    .ok()
    .and_then(|v| v.as_array().cloned())
    .unwrap_or_default()
    .iter()
    .map(|m| st(m, "email").trim().to_lowercase())
    .filter(|e| !e.is_empty())
    .collect();
    // fail closed: if the plan cannot be read, the account counts as basic (no Leads)
    let tier = crate::sb_rpc("resolve_plan", json!({ "_user_id": id, "_email": email }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .unwrap_or_else(|| "basic".to_string());
    Ok(Ctx {
        id,
        email,
        org_id,
        tier,
        members,
    })
}

fn crm_required() -> axum::response::Response {
    fail(
        StatusCode::FORBIDDEN,
        "package_required",
        "Leads are part of CRM, which starts on Pro. On your package, import straight into People.",
    )
}

/// The `rows` array as the browser sent it. Not an array => no rows. A 501st element is kept only so the core can say "too many".
fn parse_rows(input: &Value) -> Vec<Option<RawRow>> {
    input
        .get("rows")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .take(MAX_IMPORT_ROWS + 1)
                .map(|r| {
                    if r.is_object() {
                        Some(RawRow {
                            email: opt_str(r, "email"),
                            display_name: opt_str(r, "display_name"),
                            company: opt_str(r, "company"),
                            title: opt_str(r, "title"),
                            phone: opt_str(r, "phone"),
                        })
                    } else {
                        None
                    }
                })
                .collect()
        })
        .unwrap_or_default()
}

fn clean_or_reject(input: &Value) -> Result<pc::CleanResult, axum::response::Response> {
    let clean = pc::clean_import(&parse_rows(input));
    if clean.too_many {
        return Err(fail(
            StatusCode::PAYLOAD_TOO_LARGE,
            "too_many_rows",
            &format!("Send at most {} rows per request.", MAX_IMPORT_ROWS),
        ));
    }
    if clean.rows.is_empty() {
        return Err(fail(
            StatusCode::BAD_REQUEST,
            "no_valid_rows",
            &format!(
                "No valid e-mail addresses in this file ({} not valid, {} repeated).",
                clean.invalid, clean.duplicate
            ),
        ));
    }
    Ok(clean)
}

/// POST that keeps what is already there: `Prefer: resolution=ignore-duplicates` returns only the rows really inserted.
async fn post_ignore_duplicates(path: &str, body: Value) -> Result<Value, String> {
    let (url, key) = crate::sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let client = reqwest::Client::new();
    let res = client
        .post(format!("{url}/rest/v1/{path}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .header("content-type", "application/json")
        .header(
            "prefer",
            "resolution=ignore-duplicates,return=representation",
        )
        .json(&body)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = res.status();
    let payload: Value = res.json().await.unwrap_or(Value::Null);
    if !status.is_success() {
        return Err(payload.to_string());
    }
    Ok(payload)
}

/// Adds people to `contacts` for ONE organisation, never touching anyone who is already there.
/// Returns (really new, already there).
async fn insert_new_contacts(org_id: &str, rows: &[CleanRow]) -> Result<(usize, usize), String> {
    let mut created = 0usize;
    for part in rows.chunks(200) {
        let emails: Vec<String> = part.iter().map(|r| r.email.clone()).collect();
        let have = crate::sb_select(&format!(
            "contacts?select=primary_address&org_id=eq.{}&{}",
            pc::pct(org_id),
            pc::in_filter("primary_address", &emails)
        ))
        .await?;
        let known: HashSet<String> = have
            .as_array()
            .cloned()
            .unwrap_or_default()
            .iter()
            .map(|r| st(r, "primary_address").to_lowercase())
            .collect();
        let split = pc::split_known(part, |r| r.email.as_str(), &known);
        if split.fresh.is_empty() {
            continue;
        }
        let body = Value::Array(
            split
                .fresh
                .iter()
                .map(|r| {
                    json!({
                        "org_id": org_id,
                        "display_name": r.display_name,
                        "primary_address": r.email,
                        "addresses": [r.email],
                        "title": r.title,
                        "company_domain": pc::company_domain_of(&r.email),
                        "notes": pc::import_notes(r.company.as_deref(), r.phone.as_deref()),
                    })
                })
                .collect(),
        );
        let ins = post_ignore_duplicates(
            "contacts?on_conflict=org_id,primary_address&select=id",
            body,
        )
        .await?;
        created += ins.as_array().map(|a| a.len()).unwrap_or(0);
    }
    Ok((created, rows.len().saturating_sub(created)))
}

/// Evidence + audit are best-effort (the tables are optional on older databases) and must never fail an import.
async fn record(c: &Ctx, decision: &str, why: &str, action: &str, result: &str) {
    let row = json!({
        "org_id": c.org_id, "actor": c.email, "decision": decision, "why": why,
        "source_table": "crm_leads", "source_id": why, "action": action, "result": result,
    });
    if crate::sb_insert("crm_evidence", row).await.is_err() {
        let slim = json!({
            "actor": c.email, "decision": decision, "why": why,
            "source_table": "crm_leads", "source_id": why, "action": action, "result": result,
        });
        let _ = crate::sb_insert("crm_evidence", slim).await;
    }
    let _ = crate::sb_insert(
        "crm_audit",
        json!({ "actor": c.email, "action": action, "target": why }),
    )
    .await;
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    let c = match ctx(token, input).await {
        Ok(c) => c,
        Err(r) => return r,
    };
    match proc {
        "people.import" => people_import(&c, input).await,
        "crm.leadsImport" => leads_import(&c, input).await,
        "crm.leadsMoveToPeople" => move_to_people(&c, input).await,
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    }
}

async fn people_import(c: &Ctx, input: &Value) -> axum::response::Response {
    let clean = match clean_or_reject(input) {
        Ok(x) => x,
        Err(r) => return r,
    };
    match insert_new_contacts(&c.org_id, &clean.rows).await {
        Ok((created, existing)) => crate::ok(json!({
            "ok": true,
            "created": created,
            "already_in_people": existing,
            "invalid": clean.invalid,
            "duplicate": clean.duplicate,
        }))
        .into_response(),
        Err(_) => fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "import_failed",
            "Import failed",
        ),
    }
}

async fn leads_import(c: &Ctx, input: &Value) -> axum::response::Response {
    if !pc::crm_allowed(&c.tier) {
        return crm_required();
    }
    let clean = match clean_or_reject(input) {
        Ok(x) => x,
        Err(r) => return r,
    };
    let owners = pc::lead_owners(&c.tier, &c.email, &c.members);
    let emails: Vec<String> = clean.rows.iter().map(|r| r.email.clone()).collect();
    let mut is_lead: HashSet<String> = HashSet::new();
    let mut is_person: HashSet<String> = HashSet::new();
    for part in emails.chunks(200) {
        let part: Vec<String> = part.to_vec();
        let leads = crate::sb_select(&format!(
            "crm_leads?select=email&{}&{}",
            pc::in_filter("owner", &owners),
            pc::in_filter("email", &part)
        ))
        .await;
        let people = crate::sb_select(&format!(
            "contacts?select=primary_address&org_id=eq.{}&{}",
            pc::pct(&c.org_id),
            pc::in_filter("primary_address", &part)
        ))
        .await;
        if leads.is_err() || people.is_err() {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "import_failed",
                "Import failed",
            );
        }
        for l in leads
            .ok()
            .and_then(|v| v.as_array().cloned())
            .unwrap_or_default()
        {
            is_lead.insert(st(&l, "email").to_lowercase());
        }
        for p in people
            .ok()
            .and_then(|v| v.as_array().cloned())
            .unwrap_or_default()
        {
            is_person.insert(st(&p, "primary_address").to_lowercase());
        }
    }
    let split = pc::split_new_leads(&clean.rows, &is_lead, &is_person);

    let mut created = 0usize;
    for part in split.fresh.chunks(200) {
        let with_org: Vec<Value> = part
            .iter()
            .map(|r| {
                json!({
                    "email": r.email, "display_name": r.display_name, "company": r.company,
                    "source": "import", "owner": c.email, "state": "new", "org_id": c.org_id,
                })
            })
            .collect();
        let mut ins = crate::sb_insert("crm_leads?select=id", Value::Array(with_org)).await;
        if ins.is_err() {
            // older databases without crm_leads.org_id: same fallback routes/crm.ts uses (scoping is by owner there)
            let without_org: Vec<Value> = part
                .iter()
                .map(|r| {
                    json!({
                        "email": r.email, "display_name": r.display_name, "company": r.company,
                        "source": "import", "owner": c.email, "state": "new",
                    })
                })
                .collect();
            ins = crate::sb_insert("crm_leads?select=id", Value::Array(without_org)).await;
        }
        match ins {
            Ok(v) => created += v.as_array().map(|a| a.len()).unwrap_or(0),
            Err(_) => {
                return fail(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "import_failed",
                    &format!("Import stopped after {} leads were added.", created),
                )
            }
        }
    }

    if created > 0 {
        let why = format!("{} lead{}", created, if created == 1 { "" } else { "s" });
        record(c, "Leads imported from a file", &why, "lead.import", "new").await;
    }
    crate::ok(json!({
        "ok": true,
        "created": created,
        "already_leads": split.already_leads,
        "already_in_people": split.already_in_people,
        "invalid": clean.invalid,
        "duplicate": clean.duplicate,
    }))
    .into_response()
}

async fn move_to_people(c: &Ctx, input: &Value) -> axum::response::Response {
    if !pc::crm_allowed(&c.tier) {
        return crm_required();
    }
    // Either an explicit list of lead ids, or "everything I imported that is still new". Never "all leads".
    let asked: Vec<String> = input
        .get("ids")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|x| x.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();
    let ids = pc::safe_ids(&asked);
    let imported_only = st(input, "source") == "import";
    if ids.is_empty() && !imported_only {
        return fail(
            StatusCode::BAD_REQUEST,
            "ids_or_source_required",
            "Say which leads to move, or move everything you imported.",
        );
    }

    let owners = pc::lead_owners(&c.tier, &c.email, &c.members);
    let mut q = format!(
        "crm_leads?select=*&state=eq.new&{}",
        pc::in_filter("owner", &owners)
    );
    if ids.is_empty() {
        q.push_str("&source=eq.import");
    } else {
        q.push('&');
        q.push_str(&pc::in_filter("id", &ids));
    }
    q.push_str(&format!("&limit={}", MAX_IMPORT_ROWS));
    let found = match crate::sb_select(&q).await {
        Ok(v) => v,
        Err(_) => {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "move_failed",
                "Could not move them",
            )
        }
    };
    // only rows that came back from the scoped query are ever written — an id from another organisation is simply absent
    let leads: Vec<Value> = found
        .as_array()
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter(|l| !st(l, "email").trim().is_empty())
        .collect();
    if leads.is_empty() {
        return crate::ok(
            json!({ "ok": true, "moved": 0, "added_to_people": 0, "already_in_people": 0 }),
        )
        .into_response();
    }

    let people: Vec<CleanRow> = leads
        .iter()
        .map(|l| CleanRow {
            email: st(l, "email").trim().to_lowercase(),
            display_name: opt_str(l, "display_name"),
            company: opt_str(l, "company"),
            title: None,
            phone: None,
        })
        .collect();
    let (created, existing) = match insert_new_contacts(&c.org_id, &people).await {
        Ok(x) => x,
        Err(_) => {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "move_failed",
                "Could not move them",
            )
        }
    };
    let lead_ids: Vec<String> = leads
        .iter()
        .map(|l| match l.get("id") {
            Some(Value::String(s)) => s.clone(),
            Some(other) => other.to_string(),
            None => String::new(),
        })
        .filter(|s| !s.is_empty())
        .collect();
    if crate::sb_patch(
        &format!("crm_leads?{}", pc::in_filter("id", &lead_ids)),
        json!({ "state": "moved" }),
    )
    .await
    .is_err()
    {
        return fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "move_failed",
            &format!(
                "{} added to People, but the leads could not be marked as moved.",
                created
            ),
        );
    }
    let why = format!(
        "{} lead{}",
        leads.len(),
        if leads.len() == 1 { "" } else { "s" }
    );
    record(
        c,
        "Leads moved to People",
        &why,
        "lead.move_to_people",
        "moved",
    )
    .await;
    crate::ok(json!({
        "ok": true,
        "moved": leads.len(),
        "added_to_people": created,
        "already_in_people": existing,
    }))
    .into_response()
}
