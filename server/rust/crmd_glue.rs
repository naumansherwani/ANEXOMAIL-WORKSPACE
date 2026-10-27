// ============================================================================
// crmd_glue — CRM desk (Pro+) Rust PRIMARY, Tokio async (Rule 52: wahi dispatch HTTP /rpc/<proc> AUR WebTransport /wt/rpc; Rule 56: Bun ka kaam khatam).
//   crm.leads {state?}            -> {leads}            (Bun GET  /api/crm/leads)
//   crm.deals {}                  -> {deals}            (Bun GET  /api/crm/deals)
//   crm.createLead {email,...}    -> {ok,id}            (Bun POST /api/crm/leads)
//   crm.createDeal {title,...}    -> {ok,id,thread_id}  (Bun POST /api/crm/deals)
//   crm.moveDeal {id,stage}       -> {ok}               (Bun POST /api/crm/deals/stage)
//   crm.convertLead {id}          -> {ok,deal_id,thread_id} (Bun POST /api/crm/leads/convert)
//   crm.dealWork {id}             -> {ok,task_id}       (Bun POST /api/crm/deals/work)
//   crm.dealThread {id}           -> {ok,thread_id}     (Bun POST /api/crm/deals/thread)
//   work.promise.commit {id}      -> {ok,task}          (Bun POST /api/work/promises/:id/commit; promise -> task)
//   work.promise.dismiss {id}     -> {ok}               (Bun POST /api/work/promises/:id/dismiss)
//   crm.memory {email}            -> {email,person,deals,tasks,timeline,next_actions} (Bun GET /api/crm/memory; relationship memory)
//   crm.insights {}               -> {insights:[]}      (Bun GET  /api/crm/insights; workspace mein LEO nahi, khali jaan-boojh kar)
// Gate Pro+ (Basic 403 feature_not_available). Pro = sirf apni rows (owner = email); Business+ = poori team (org_members). Hisaab crmd_core.rs (std-only, tested). Koi SQL nahi.
// ============================================================================

use crate::crmd_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::pro_only(proc)
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn nul(v: &Value, k: &str) -> Value {
    v.get(k).cloned().filter(|x| !x.is_null()).unwrap_or(Value::Null)
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

fn uuid_ok(s: &str) -> bool {
    s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_hexdigit() })
}

fn now_secs() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

fn now_iso() -> String {
    crate::cal_core::fmt_rfc3339(now_secs())
}

/// mail_messages mein `snippet` column nahi (mail_threads mein hai): body_text ke shuru se 160 akshar.
fn mail_detail(m: &Value) -> Value {
    let short: String = st(m, "body_text").split_whitespace().collect::<Vec<_>>().join(" ").chars().take(160).collect();
    if short.is_empty() { Value::Null } else { json!(short) }
}

async fn rows(q: &str) -> Vec<Value> {
    match crate::sb_select(q).await {
        Ok(v) => v.as_array().cloned().unwrap_or_default(),
        Err(_) => vec![],
    }
}

/// Bun insertBest: pehle org_id ke saath, na chale to org_id ke baghair (purane schema).
async fn insert_best(table: &str, row: Value) -> Result<Value, String> {
    match crate::sb_insert(&format!("{table}?select=id"), row.clone()).await {
        Ok(v) => Ok(v),
        Err(_) => {
            let mut slim = row;
            if let Some(o) = slim.as_object_mut() {
                o.remove("org_id");
            }
            crate::sb_insert(&format!("{table}?select=id"), slim).await
        }
    }
}

fn first_id(v: &Value) -> Option<String> {
    v.get(0).and_then(|r| r.get("id")).map(|x| x.as_str().map(|s| s.to_string()).unwrap_or_else(|| x.to_string()))
}

struct Ctx {
    me: crate::MailMe,
    plan: String,
    owners: Vec<String>,
}

fn owner_list(o: &[String]) -> String {
    o.iter().map(|e| format!("%22{}%22", enc(&e.replace('"', "")))).collect::<Vec<_>>().join(",")
}

async fn owners_of(me: &crate::MailMe, plan: &str) -> Vec<String> {
    if plan.trim().eq_ignore_ascii_case("pro") || me.org_id.is_empty() {
        return vec![me.email.to_lowercase()];
    }
    let mut o: Vec<String> = rows(&format!("org_members?select=email&org_id=eq.{}&limit=2000", enc(&me.org_id)))
        .await
        .iter()
        .map(|m| c::email_of(&st(m, "email")))
        .filter(|e| !e.is_empty())
        .collect();
    o.push(me.email.to_lowercase());
    o.sort();
    o.dedup();
    o
}

async fn evidence(cx: &Ctx, decision: &str, why: &str, table: &str, source_id: &str, action: &str, result: &str) {
    let row = json!({
        "org_id": cx.me.org_id, "actor": cx.me.email, "decision": decision, "why": why,
        "source_table": table, "source_id": source_id, "action": action, "result": result,
    });
    let _ = insert_best("crm_evidence", row).await;
}

async fn edge(cx: &Ctx, from_kind: &str, from_id: &str, to_kind: &str, to_id: &str, kind: &str) {
    let row = json!({ "org_id": cx.me.org_id, "from_kind": from_kind, "from_id": from_id, "to_kind": to_kind, "to_id": to_id, "kind": kind });
    let _ = insert_best("crm_graph_edges", row).await;
}

async fn audit(cx: &Ctx, action: &str, target: &str) {
    let _ = crate::sb_insert("crm_audit", json!({ "actor": cx.me.email, "action": action, "target": target })).await;
}

/// Bun threadForAddress: us address ki sab se nayi mail ka thread, warna us address ka sab se naya thread.
async fn thread_for(org: &str, email: &str) -> Option<String> {
    if !email.contains('@') {
        return None;
    }
    let (o, e) = (enc(org), enc(email));
    let m = rows(&format!(
        "mail_messages?select=thread_id,sent_at&org_id=eq.{o}&from_address=eq.{e}&thread_id=not.is.null&order=sent_at.desc&limit=1"
    ))
    .await;
    if let Some(t) = m.first().and_then(|r| r.get("thread_id")).and_then(|x| x.as_str()) {
        return Some(t.to_string());
    }
    let t = rows(&format!("mail_threads?select=id,from_address,last_message_at&org_id=eq.{o}&from_address=eq.{e}&order=last_message_at.desc&limit=1")).await;
    t.first().and_then(|r| r.get("id")).and_then(|x| x.as_str()).map(|s| s.to_string())
}

async fn owned_deal(cx: &Ctx, id: &str) -> Option<Value> {
    if !uuid_ok(id) {
        return None;
    }
    rows(&format!("crm_deals?select=*&id=eq.{}&owner=in.({})&limit=1", enc(id), owner_list(&cx.owners))).await.into_iter().next()
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let me = match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(m) => m,
        Err((s, code, m)) => return crate::err(s, code, &m).into_response(),
    };
    let plan = crate::sb_rpc("resolve_plan", json!({ "_user_id": me.id, "_email": me.email }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .unwrap_or_else(|| "basic".to_string());
    if !crate::workx_core::plan_allows_pro(&plan) {
        return fail(StatusCode::FORBIDDEN, "feature_not_available", c::NO_ACCESS);
    }
    if proc.starts_with("work.promise.") {
        return promise(proc, &me, input).await;
    }
    if me.org_id.is_empty() {
        return fail(StatusCode::CONFLICT, "no_workspace", "No workspace");
    }
    let owners = owners_of(&me, &plan).await;
    let cx = Ctx { me, plan, owners };
    match proc {
        "crm.leads" => leads(&cx, input).await,
        "crm.deals" => deals(&cx).await,
        "crm.createLead" => create_lead(&cx, input).await,
        "crm.createDeal" => create_deal(&cx, input).await,
        "crm.moveDeal" => move_deal(&cx, input).await,
        "crm.convertLead" => convert_lead(&cx, input).await,
        "crm.dealWork" => deal_work(&cx, input).await,
        "crm.dealThread" => deal_thread(&cx, input).await,
        "crm.memory" => memory(&cx, input).await,
        "crm.insights" => crate::ok(json!({ "insights": [] })).into_response(),
        // 404 sirf "yeh proc Rust ke paas nahi" ke liye — baaqi sab domain errors 409 (client 404 par Bun fallback karta hai; live loophole 27 Oct: deals/thread 404 -> Bun).
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    }
}

async fn leads(cx: &Ctx, input: &Value) -> Resp {
    let want = st(input, "state");
    let list = rows(&format!("crm_leads?select=*&owner=in.({})&order=created_at.desc&limit=300", owner_list(&cx.owners))).await;
    let out: Vec<Value> = list
        .iter()
        .filter(|l| c::state_matches(&want, l.get("state").and_then(|x| x.as_str()).unwrap_or("new")))
        .map(|l| {
            json!({
                "id": l.get("id"), "display_name": nul(l, "display_name"), "email": l.get("email"), "company": nul(l, "company"),
                "source": nul(l, "source"), "score": nul(l, "score"), "score_reason": nul(l, "score_reason"), "owner": nul(l, "owner"),
                "state": l.get("state").filter(|x| !x.is_null()).cloned().unwrap_or(json!("new")),
                "last_touch_at": nul(l, "last_touch_at"), "created_at": l.get("created_at"),
            })
        })
        .collect();
    crate::ok(json!({ "leads": out })).into_response()
}

async fn deals(cx: &Ctx) -> Resp {
    let now = now_secs();
    let list = rows(&format!("crm_deals?select=*&owner=in.({})&order=updated_at.desc&limit=300", owner_list(&cx.owners))).await;
    let out: Vec<Value> = list
        .iter()
        .map(|d| {
            let stage = d.get("stage").and_then(|x| x.as_str()).unwrap_or("new").to_string();
            let upd = d.get("updated_at").and_then(|x| x.as_str()).and_then(crate::cal_core::parse_ts);
            let stale = if c::is_closed(&stage) { Value::Null } else { c::days_since(now, upd).map(|n| json!(n)).unwrap_or(Value::Null) };
            let prob = d.get("probability").filter(|x| !x.is_null()).cloned().or_else(|| c::stage_prob(&stage).map(|p| json!(p))).unwrap_or(Value::Null);
            let value = d.get("value").and_then(|x| x.as_f64().or_else(|| x.as_str().and_then(|s| s.parse().ok()))).unwrap_or(0.0);
            json!({
                "id": d.get("id"), "title": d.get("title"), "company": nul(d, "company"), "contact_email": nul(d, "contact_email"),
                "stage": stage, "value": value, "currency": d.get("currency").filter(|x| !x.is_null()).cloned().unwrap_or(json!("GBP")),
                "probability": prob, "owner": nul(d, "owner"), "next_step": nul(d, "next_step"), "next_step_due": nul(d, "next_step_due"),
                "thread_id": nul(d, "thread_id"), "stale_days": stale, "updated_at": d.get("updated_at"),
            })
        })
        .collect();
    crate::ok(json!({ "deals": out })).into_response()
}

async fn create_lead(cx: &Ctx, input: &Value) -> Resp {
    let Some(email) = c::clean_lead_email(&st(input, "email")) else {
        return fail(StatusCode::BAD_REQUEST, "email_required", "A valid email is required");
    };
    let row = json!({
        "email": email, "display_name": c::opt_text(&st(input, "display_name")), "company": c::opt_text(&st(input, "company")),
        "source": c::clean_source(&st(input, "source")), "owner": cx.me.email, "state": "new", "org_id": cx.me.org_id,
    });
    let ins = match insert_best("crm_leads", row).await {
        Ok(v) => v,
        Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "lead_create_failed", &e),
    };
    let id = first_id(&ins);
    evidence(cx, "Lead captured", &email, "crm_leads", id.as_deref().unwrap_or(&email), "lead.create", "new").await;
    audit(cx, "lead.create", &email).await;
    crate::ok(json!({ "ok": true, "id": id })).into_response()
}

async fn create_deal(cx: &Ctx, input: &Value) -> Resp {
    let Some(title) = c::clean_title(&st(input, "title")) else {
        return fail(StatusCode::BAD_REQUEST, "title_required", "A title of at least 2 characters is required");
    };
    let contact = c::opt_text(&c::email_of(&st(input, "contact_email")));
    let value = c::clean_value(input.get("value").and_then(|x| x.as_f64().or_else(|| x.as_str().and_then(|s| s.parse().ok()))));
    let row = json!({
        "title": title, "company": c::opt_text(&st(input, "company")), "contact_email": contact, "stage": "new", "value": value,
        "currency": "GBP", "probability": c::stage_prob("new"), "owner": cx.me.email, "next_step": c::opt_text(&st(input, "next_step")),
        "org_id": cx.me.org_id, "updated_at": now_iso(),
    });
    let ins = match insert_best("crm_deals", row).await {
        Ok(v) => v,
        Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "deal_create_failed", &e),
    };
    let id = first_id(&ins);
    let tid = match &contact {
        Some(e) => thread_for(&cx.me.org_id, e).await,
        None => None,
    };
    if let (Some(i), Some(t)) = (&id, &tid) {
        let _ = crate::sb_patch(&format!("crm_deals?id=eq.{}", enc(i)), json!({ "thread_id": t })).await;
        edge(cx, "deal", i, "mail", t, "thread").await;
    }
    let _ = crate::sb_insert(
        "crm_activities",
        json!({ "kind": "note", "actor": cx.me.email, "subject": title, "body": "Deal opened.", "deal_id": id, "contact_email": contact }),
    )
    .await;
    let result = tid.as_ref().map(|t| format!("thread:{t}")).unwrap_or_else(|| "no_thread_yet".to_string());
    evidence(cx, "Deal opened", &title, "crm_deals", id.as_deref().unwrap_or(""), "deal.create", &result).await;
    audit(cx, "deal.create", id.as_deref().unwrap_or(&title)).await;
    crate::ok(json!({ "ok": true, "id": id, "thread_id": tid })).into_response()
}

fn id_of(input: &Value) -> String {
    let a = st(input, "deal_id");
    if a.is_empty() { st(input, "id") } else { a }
}

async fn move_deal(cx: &Ctx, input: &Value) -> Resp {
    let id = id_of(input);
    let stage = st(input, "stage");
    let Some(prob) = c::stage_prob(&stage) else {
        return fail(StatusCode::BAD_REQUEST, "deal_id_and_stage_required", "deal id and a valid stage are required");
    };
    if id.is_empty() {
        return fail(StatusCode::BAD_REQUEST, "deal_id_and_stage_required", "deal id and a valid stage are required");
    }
    let Some(deal) = owned_deal(cx, &id).await else {
        return fail(StatusCode::CONFLICT, "deal_not_found", "Deal not found");
    };
    if let Err(e) = crate::sb_patch(&format!("crm_deals?id=eq.{}", enc(&id)), json!({ "stage": stage, "probability": prob, "updated_at": now_iso() })).await {
        return fail(StatusCode::INTERNAL_SERVER_ERROR, "stage_failed", &e);
    }
    let _ = crate::sb_insert("crm_activities", json!({ "kind": "stage_change", "actor": cx.me.email, "subject": format!("Stage → {stage}"), "deal_id": id })).await;
    audit(cx, "deal.stage", &format!("{id}:{stage}")).await;
    let why = {
        let t = st(&deal, "title");
        if t.is_empty() { id.clone() } else { t }
    };
    evidence(cx, &format!("Stage → {stage}"), &why, "crm_deals", &id, "deal.stage", &stage).await;
    crate::ok(json!({ "ok": true })).into_response()
}

async fn convert_lead(cx: &Ctx, input: &Value) -> Resp {
    let lead_id = {
        let a = st(input, "lead_id");
        if a.is_empty() { st(input, "id") } else { a }
    };
    if lead_id.is_empty() {
        return fail(StatusCode::BAD_REQUEST, "lead_id_required", "lead id is required");
    }
    let lead = if uuid_ok(&lead_id) {
        rows(&format!("crm_leads?select=*&id=eq.{}&owner=in.({})&limit=1", enc(&lead_id), owner_list(&cx.owners))).await.into_iter().next()
    } else {
        None
    };
    let Some(lead) = lead else {
        return fail(StatusCode::CONFLICT, "lead_not_found", "Lead not found");
    };
    let email = st(&lead, "email");
    let company = lead.get("company").and_then(|x| x.as_str()).map(|s| s.to_string());
    let value = c::clean_value(input.get("value").and_then(|x| x.as_f64().or_else(|| x.as_str().and_then(|s| s.parse().ok()))));
    let owner = lead.get("owner").and_then(|x| x.as_str()).filter(|s| !s.is_empty()).unwrap_or(&cx.me.email).to_string();
    let row = json!({
        "title": c::convert_title(company.as_deref(), &email), "company": company, "contact_email": email, "stage": "qualified", "value": value,
        "currency": "GBP", "probability": c::stage_prob("qualified"), "owner": owner, "org_id": cx.me.org_id, "updated_at": now_iso(),
    });
    let ins = match insert_best("crm_deals", row).await {
        Ok(v) => v,
        Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "convert_failed", &e),
    };
    let deal_id = first_id(&ins);
    let tid = thread_for(&cx.me.org_id, &c::email_of(&email)).await;
    if let (Some(d), Some(t)) = (&deal_id, &tid) {
        let _ = crate::sb_patch(&format!("crm_deals?id=eq.{}", enc(d)), json!({ "thread_id": t })).await;
        edge(cx, "deal", d, "mail", t, "thread").await;
    }
    let _ = crate::sb_patch(&format!("crm_leads?id=eq.{}", enc(&lead_id)), json!({ "state": "converted" })).await;
    let result = deal_id.as_ref().map(|d| format!("crm_deals:{d}")).unwrap_or_else(|| "created".to_string());
    evidence(cx, "Lead converted", &email, "crm_leads", &lead_id, "lead.convert", &result).await;
    audit(cx, "lead.convert", &lead_id).await;
    crate::ok(json!({ "ok": true, "deal_id": deal_id, "thread_id": tid })).into_response()
}

async fn deal_work(cx: &Ctx, input: &Value) -> Resp {
    let id = id_of(input);
    if id.is_empty() {
        return fail(StatusCode::BAD_REQUEST, "deal_id_required", "deal id is required");
    }
    let Some(deal) = owned_deal(cx, &id).await else {
        return fail(StatusCode::CONFLICT, "deal_not_found", "Deal not found");
    };
    let owner = deal.get("owner").and_then(|x| x.as_str()).filter(|s| !s.is_empty()).unwrap_or(&cx.me.email).to_string();
    let row = json!({
        "org_id": cx.me.org_id, "title": deal.get("title"), "status": "todo", "owner": owner, "due_at": nul(&deal, "next_step_due"),
        "thread_id": nul(&deal, "thread_id"), "source": "manual", "source_deal_id": id, "created_by": cx.me.id,
    });
    // work_tasks.source CHECK sirf manual|promise|meeting_outcome maanta hai (live bug 27 Oct: "crm_deal" se insert toot'ta tha) — deal ka rishta source_deal_id mein.
    let ins = match crate::sb_insert("work_tasks?select=id", row).await {
        Ok(v) => v,
        Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "work_create_failed", &e),
    };
    let task_id = first_id(&ins);
    edge(cx, "deal", &id, "work", task_id.as_deref().unwrap_or(&id), "workstream").await;
    let why = st(&deal, "title");
    let result = task_id.as_ref().map(|t| format!("work_tasks:{t}")).unwrap_or_else(|| "created".to_string());
    evidence(cx, "CRM → Work", &why, "crm_deals", &id, "deal.work", &result).await;
    audit(cx, "deal.work", &id).await;
    crate::ok(json!({ "ok": true, "task_id": task_id })).into_response()
}

async fn deal_thread(cx: &Ctx, input: &Value) -> Resp {
    let id = id_of(input);
    if id.is_empty() {
        return fail(StatusCode::BAD_REQUEST, "deal_id_required", "deal id is required");
    }
    let Some(deal) = owned_deal(cx, &id).await else {
        return fail(StatusCode::CONFLICT, "deal_not_found", "Deal not found");
    };
    let address = c::email_of(&st(&deal, "contact_email"));
    let Some(tid) = thread_for(&cx.me.org_id, &address).await else {
        return fail(StatusCode::CONFLICT, "no_thread_for_address", "No mail thread found for this contact yet");
    };
    if let Err(e) = crate::sb_patch(&format!("crm_deals?id=eq.{}", enc(&id)), json!({ "thread_id": tid, "updated_at": now_iso() })).await {
        return fail(StatusCode::INTERNAL_SERVER_ERROR, "thread_attach_failed", &e);
    }
    edge(cx, "deal", &id, "mail", &tid, "thread").await;
    evidence(cx, "Conversation → CRM", &format!("Recorded thread for {address}"), "crm_deals", &id, "deal.thread", &format!("mail_threads:{tid}")).await;
    audit(cx, "deal.thread", &format!("{id}:{tid}")).await;
    crate::ok(json!({ "ok": true, "thread_id": tid })).into_response()
}

/// work_promises par org ho to org_id, warna apni (created_by) rows — Bun orgFilter jaisa.
fn promise_scope(me: &crate::MailMe) -> String {
    if me.org_id.is_empty() { format!("created_by=eq.{}", enc(&me.id)) } else { format!("org_id=eq.{}", enc(&me.org_id)) }
}

async fn promise(proc: &str, me: &crate::MailMe, input: &Value) -> Resp {
    let id = st(input, "id");
    if !uuid_ok(&id) {
        return fail(StatusCode::CONFLICT, "not_found", "Promise not found");
    }
    let scope = promise_scope(me);
    if proc == "work.promise.dismiss" {
        if let Err(e) = crate::sb_patch(&format!("work_promises?id=eq.{}&{scope}", enc(&id)), json!({ "status": "dismissed" })).await {
            return fail(StatusCode::INTERNAL_SERVER_ERROR, "promise_failed", &e);
        }
        return crate::ok(json!({ "ok": true })).into_response();
    }
    let Some(p) = rows(&format!("work_promises?select=*&id=eq.{}&{scope}&limit=1", enc(&id))).await.into_iter().next() else {
        return fail(StatusCode::CONFLICT, "not_found", "Promise not found");
    };
    let row = json!({
        "org_id": if me.org_id.is_empty() { Value::Null } else { json!(me.org_id) }, "title": p.get("suggested_title"), "status": "todo",
        "owner": c::task_owner(p.get("owner").and_then(|x| x.as_str()), &me.email), "due_at": nul(&p, "suggested_due_at"),
        "thread_id": nul(&p, "thread_id"), "thread_subject": nul(&p, "thread_subject"), "source": "promise", "created_by": me.id,
    });
    let task = match crate::sb_insert("work_tasks?select=*", row).await {
        Ok(v) => v.get(0).cloned(),
        Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "task_create_failed", &e),
    };
    let tid = task.as_ref().and_then(|t| t.get("id")).cloned().unwrap_or(Value::Null);
    let _ = crate::sb_patch(&format!("work_promises?id=eq.{}", enc(&id)), json!({ "status": "committed", "task_id": tid })).await;
    let shaped = task.map(|t| {
        let late = match (t.get("completed_at").and_then(|x| x.as_str()).and_then(crate::cal_core::parse_ts), t.get("due_at").and_then(|x| x.as_str()).and_then(crate::cal_core::parse_ts)) {
            (Some(done), Some(due)) => done > due,
            _ => false,
        };
        json!({
            "id": t.get("id"), "title": t.get("title"), "status": t.get("status").filter(|x| !x.is_null()).cloned().unwrap_or(json!("todo")),
            "owner": nul(&t, "owner"), "due_at": nul(&t, "due_at"), "thread_id": nul(&t, "thread_id"), "thread_subject": nul(&t, "thread_subject"),
            "event_id": nul(&t, "event_id"), "source": t.get("source").filter(|x| !x.is_null()).cloned().unwrap_or(json!("manual")),
            "created_at": t.get("created_at"), "completed_at": nul(&t, "completed_at"), "late": late,
        })
    });
    crate::ok(json!({ "ok": true, "task": shaped })).into_response()
}

/* ------------------------------------------------------------------ crm.memory */

fn ts_of(v: &Value, k: &str) -> Option<i64> {
    v.get(k).and_then(|x| x.as_str()).and_then(crate::cal_core::parse_ts)
}

fn f64_of(v: Option<&Value>) -> Option<f64> {
    match v {
        Some(Value::Number(n)) => n.as_f64(),
        Some(Value::String(s)) => s.parse().ok(),
        _ => None,
    }
}

/// contacts row (stats embed ek object) -> person, Bun shapePerson jaisa.
fn shape_person(row: &Value) -> Value {
    let empty = Value::Null;
    let s = match row.get("stats") {
        Some(o @ Value::Object(_)) => o,
        _ => &empty,
    };
    let pick = |k: &str| -> Option<Value> { s.get(k).filter(|x| !x.is_null()).cloned().or_else(|| row.get(k).filter(|x| !x.is_null()).cloned()) };
    let company = row
        .get("company")
        .and_then(|c| c.get("name"))
        .and_then(|x| x.as_str())
        .filter(|x| !x.is_empty())
        .map(|x| x.to_string())
        .or_else(|| row.get("company_name").and_then(|x| x.as_str()).filter(|x| !x.is_empty()).map(|x| x.to_string()))
        .or_else(|| row.get("company_domain").and_then(|x| x.as_str()).filter(|x| !x.is_empty()).map(|x| x.to_string()));
    json!({
        "id": row.get("id").map(|x| x.as_str().map(|v| v.to_string()).unwrap_or_else(|| x.to_string())).unwrap_or_default(),
        "display_name": nul(row, "display_name"),
        "primary_address": c::email_of(&st(row, "primary_address")),
        "company_name": company,
        "relationship": pick("relationship").unwrap_or(Value::Null),
        "health_score": pick("health_score").unwrap_or(Value::Null),
        "last_contact_at": pick("last_contact_at").unwrap_or(Value::Null),
        "open_threads": f64_of(pick("open_threads").as_ref()).map(|n| n as i64).unwrap_or(0),
    })
}

fn synth_person(id: &Value, name: Value, addr: &str, company: Value, last: Value) -> Value {
    json!({
        "id": id.as_str().map(|s| s.to_string()).unwrap_or_default(), "display_name": name, "primary_address": addr, "company_name": company,
        "relationship": Value::Null, "health_score": Value::Null, "last_contact_at": last, "open_threads": 0,
    })
}

async fn memory(cx: &Ctx, input: &Value) -> Resp {
    let email = c::email_of(&st(input, "email"));
    if !email.contains('@') {
        return fail(StatusCode::BAD_REQUEST, "email_required", "A valid email is required");
    }
    let now = now_secs();
    let org = enc(&cx.me.org_id);
    let list = owner_list(&cx.owners);
    let (dq, lq) = (format!("crm_deals?select=*&owner=in.({list})&limit=5000"), format!("crm_leads?select=*&owner=in.({list})&limit=5000"));
    let e = enc(&email);
    let pq = format!(
        "contacts?select=id,display_name,primary_address,company_domain,health_score,last_contact_at,stats:contact_stats(messages_in,messages_out,avg_reply_minutes,open_threads,last_contact_at,relationship,health_score)&org_id=eq.{org}&primary_address=ilike.{e}&limit=1"
    );
    let pq2 = format!("contacts?select=id,display_name,primary_address,company_domain,health_score,last_contact_at&org_id=eq.{org}&primary_address=ilike.{e}&limit=1");
    let tq = format!("work_tasks?select=*&org_id=eq.{org}&limit=200");
    let mq = format!(
        "mail_messages?select=id,thread_id,subject,from_address,direction,sent_at,body_text&org_id=eq.{org}&or=(from_address.ilike.%2A{e}%2A,to_addresses.cs.%7B{e}%7D,to_addrs.cs.%7B{e}%7D)&order=sent_at.desc&limit=40"
    );
    let eq = format!("calendar_events?select=id,title,starts_at,organiser,thread_id&org_id=eq.{org}&limit=80");
    let aq = format!("calendar_attendees?select=event_id,address&org_id=eq.{org}&limit=500");
    let (all_deals, all_leads, joined, tasks, mut mail, events, attendees) =
        tokio::join!(rows(&dq), rows(&lq), rows(&pq), rows(&tq), rows(&mq), rows(&eq), rows(&aq));
    let contact = if joined.is_empty() { rows(&pq2).await } else { joined };
    if mail.is_empty() {
        // Bun loadMail: org ki taza mail, na ho to threads — phir sirf is address ki.
        let recent = rows(&format!("mail_messages?select=id,thread_id,subject,from_address,direction,sent_at&org_id=eq.{org}&order=sent_at.desc&limit=40")).await;
        mail = if !recent.is_empty() {
            recent
        } else {
            rows(&format!("mail_threads?select=id,subject,from_address,last_message_at,status,folder&org_id=eq.{org}&order=last_message_at.desc&limit=40"))
                .await
                .iter()
                .map(|t| {
                    let open = st(t, "status") == "open" || st(t, "folder") == "inbox";
                    json!({ "id": t.get("id"), "thread_id": t.get("id"), "subject": t.get("subject"), "from_address": t.get("from_address"),
                            "direction": "in", "sent_at": t.get("last_message_at"), "open": open })
                })
                .collect()
        };
        mail.retain(|m| c::email_of(&st(m, "from_address")) == email);
    }
    let deals: Vec<Value> = all_deals.iter().filter(|d| c::email_of(&st(d, "contact_email")) == email).cloned().collect();
    let person = if let Some(row) = contact.first() {
        shape_person(row)
    } else if let Some(d) = all_deals.iter().find(|d| c::email_of(&st(d, "contact_email")) == email) {
        let name = d.get("company").filter(|x| !x.is_null()).cloned().unwrap_or(json!(email));
        synth_person(d.get("id").unwrap_or(&Value::Null), name, &email, nul(d, "company"), nul(d, "updated_at"))
    } else if let Some(l) = all_leads.iter().find(|l| c::email_of(&st(l, "email")) == email) {
        let name = l.get("display_name").filter(|x| x.as_str().map(|s| !s.is_empty()).unwrap_or(false)).cloned().unwrap_or(json!(email));
        let last = l.get("last_touch_at").filter(|x| !x.is_null()).cloned().unwrap_or_else(|| nul(l, "created_at"));
        synth_person(l.get("id").unwrap_or(&Value::Null), name, &email, nul(l, "company"), last)
    } else {
        Value::Null
    };
    let deal_ids: Vec<String> = deals.iter().map(|d| st(d, "id")).collect();
    let deal_threads: Vec<String> = deals.iter().map(|d| st(d, "thread_id")).filter(|t| !t.is_empty()).collect();
    let related_tasks: Vec<&Value> = tasks
        .iter()
        .filter(|t| {
            c::email_of(&st(t, "owner")) == email
                || (!st(t, "thread_id").is_empty() && deal_threads.contains(&st(t, "thread_id")))
                || st(t, "source").contains("crm_deal")
                || (!st(t, "source_deal_id").is_empty() && deal_ids.contains(&st(t, "source_deal_id")))
        })
        .collect();
    let meet_ids: Vec<String> = attendees.iter().filter(|a| c::email_of(&st(a, "address")) == email).map(|a| st(a, "event_id")).collect();
    let mut related_events: Vec<&Value> = events.iter().filter(|e| meet_ids.contains(&st(e, "id")) || c::email_of(&st(e, "organiser")) == email).collect();
    let open_threads = person.get("open_threads").and_then(|x| x.as_i64()).unwrap_or(0);
    let no_pitch = c::no_pitch(open_threads, mail.iter().any(|m| m.get("open").and_then(|x| x.as_bool()).unwrap_or(false) || st(m, "direction") == "in"));
    related_events.sort_by(|a, b| st(b, "starts_at").cmp(&st(a, "starts_at")));
    let last_meet = related_events.first();
    let gap = c::meeting_gap(last_meet.and_then(|e| c::days_since(now, ts_of(e, "starts_at"))));
    let mut timeline: Vec<(String, Value)> = vec![];
    for m in &mail {
        let at = st(m, "sent_at");
        let subj = st(m, "subject");
        let href = if st(m, "thread_id").is_empty() { "/app/mail/inbox".to_string() } else { format!("/app/mail/inbox/{}", st(m, "thread_id")) };
        timeline.push((at.clone(), json!({
            "at": at, "kind": if st(m, "direction") == "out" { "email_out" } else { "email_in" },
            "title": if subj.is_empty() { "(no subject)".to_string() } else { subj }, "detail": mail_detail(m), "href": href,
        })));
    }
    for e in &related_events {
        let at = st(e, "starts_at");
        timeline.push((at.clone(), json!({ "at": at, "kind": "meeting", "title": e.get("title"), "detail": e.get("organiser").filter(|x| x.as_str().map(|s| !s.is_empty()).unwrap_or(false)).cloned().unwrap_or(Value::Null), "href": "/app/calendar" })));
    }
    for t in &related_tasks {
        let at = { let d = st(t, "due_at"); if d.is_empty() { st(t, "created_at") } else { d } };
        timeline.push((at.clone(), json!({ "at": at, "kind": "work", "title": t.get("title"), "detail": t.get("status").filter(|x| x.as_str().map(|s| !s.is_empty()).unwrap_or(false)).cloned().unwrap_or(Value::Null), "href": "/app/work" })));
    }
    timeline.retain(|(at, _)| !at.is_empty());
    timeline.sort_by(|a, b| b.0.cmp(&a.0));
    let timeline: Vec<Value> = timeline.into_iter().take(40).map(|(_, v)| v).collect();
    let mut next: Vec<Value> = vec![];
    if no_pitch {
        let n = if open_threads > 0 { open_threads } else { mail.len() as i64 };
        next.push(json!({ "action": "Don't send a sales email — an open support thread is still waiting", "why": format!("{n} open threads"), "href": "/app/mail/inbox" }));
    }
    if c::needs_meeting(!deals.is_empty(), gap) {
        let why = match last_meet { Some(e) => format!("Last meeting {}", st(e, "starts_at")), None => "No meeting on record".to_string() };
        next.push(json!({ "action": "No decision-maker meeting in 12 days", "why": why, "href": "/app/calendar" }));
    }
    for d in &deals {
        let n = c::days_since(now, ts_of(d, "updated_at"));
        if c::deal_untouched(n) {
            let href = if st(d, "thread_id").is_empty() { "/app/crm/pipeline".to_string() } else { format!("/app/mail/inbox/{}", st(d, "thread_id")) };
            next.push(json!({ "action": "Write the thread or set a next step", "why": format!("Deal untouched {} days", n.unwrap_or(0)), "href": href }));
        }
    }
    let task_out: Vec<Value> = related_tasks
        .iter()
        .map(|t| json!({ "id": t.get("id"), "title": t.get("title"), "status": t.get("status"), "due_at": nul(t, "due_at"), "thread_id": nul(t, "thread_id") }))
        .collect();
    crate::ok(json!({ "email": email, "person": person, "deals": deals, "tasks": task_out, "timeline": timeline, "next_actions": next })).into_response()
}
