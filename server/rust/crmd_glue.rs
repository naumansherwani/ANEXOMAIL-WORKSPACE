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
        "crm.insights" => crate::ok(json!({ "insights": [] })).into_response(),
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
        return fail(StatusCode::NOT_FOUND, "deal_not_found", "Deal not found");
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
        return fail(StatusCode::NOT_FOUND, "lead_not_found", "Lead not found");
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
        return fail(StatusCode::NOT_FOUND, "deal_not_found", "Deal not found");
    };
    let owner = deal.get("owner").and_then(|x| x.as_str()).filter(|s| !s.is_empty()).unwrap_or(&cx.me.email).to_string();
    let row = json!({
        "org_id": cx.me.org_id, "title": deal.get("title"), "status": "todo", "owner": owner, "due_at": nul(&deal, "next_step_due"),
        "thread_id": nul(&deal, "thread_id"), "source": "crm_deal", "created_by": cx.me.id,
    });
    let ins = match insert_best("work_tasks", row).await {
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
        return fail(StatusCode::NOT_FOUND, "deal_not_found", "Deal not found");
    };
    let address = c::email_of(&st(&deal, "contact_email"));
    let Some(tid) = thread_for(&cx.me.org_id, &address).await else {
        return fail(StatusCode::NOT_FOUND, "no_thread_for_address", "No mail thread found for this contact yet");
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
        return fail(StatusCode::NOT_FOUND, "not_found", "Promise not found");
    }
    let scope = promise_scope(me);
    if proc == "work.promise.dismiss" {
        if let Err(e) = crate::sb_patch(&format!("work_promises?id=eq.{}&{scope}", enc(&id)), json!({ "status": "dismissed" })).await {
            return fail(StatusCode::INTERNAL_SERVER_ERROR, "promise_failed", &e);
        }
        return crate::ok(json!({ "ok": true })).into_response();
    }
    let Some(p) = rows(&format!("work_promises?select=*&id=eq.{}&{scope}&limit=1", enc(&id))).await.into_iter().next() else {
        return fail(StatusCode::NOT_FOUND, "not_found", "Promise not found");
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
