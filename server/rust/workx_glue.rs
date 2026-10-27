// ============================================================================
// workx_glue — Work tasks, promise inbox aur CRM overview: Bun se Rust (Tokio async). Rule 52: wahi dispatch HTTP /rpc/<proc> AUR WebTransport /wt/rpc par.
//   work.tasks     {view?: "mine", thread_id?, event_id?, org_id?}  -> {tasks:[...]}        (Bun GET /api/work/tasks jaisa shape)
//   work.promises  {org_id?}                                         -> {promises:[...]}    (status=suggested)
//   crm.overview   {org_id?}                                         -> {currency, pipeline_value, weighted_value, ...}
// Gate: teeno Pro+ (workx_core::pro_only), resolve_plan se. Hisaab workx_core.rs mein (std-only, tested).
// ============================================================================

use crate::workx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::pro_only(proc).is_some()
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

fn ts(v: &Value, k: &str) -> Option<i64> {
    v.get(k).and_then(|x| x.as_str()).and_then(crate::cal_core::parse_ts)
}

fn num(v: &Value, k: &str) -> f64 {
    match v.get(k) {
        Some(Value::Number(n)) => n.as_f64().unwrap_or(0.0),
        Some(Value::String(s)) => s.parse().unwrap_or(0.0),
        _ => 0.0,
    }
}

fn now_secs() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let me = match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(m) => m,
        Err((s, code, m)) => return crate::err(s, code, &m).into_response(),
    };
    // Pro+ gate — SERVER par. resolve_plan na mile to basic maana jata hai (kabhi zyada nahi kholta).
    let plan = crate::sb_rpc("resolve_plan", json!({ "_user_id": me.id, "_email": me.email }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .unwrap_or_else(|| "basic".to_string());
    if let Some(msg) = c::pro_only(proc) {
        if !c::plan_allows_pro(&plan) {
            return fail(StatusCode::FORBIDDEN, "feature_not_available", msg);
        }
    }
    let scope = if me.org_id.is_empty() { format!("created_by=eq.{}", enc(&me.id)) } else { format!("org_id=eq.{}", enc(&me.org_id)) };
    match proc {
        "work.tasks" => tasks(&me, &scope, input).await,
        "work.promises" => promises(&scope).await,
        "crm.overview" => crm_overview(&me, &plan, input).await,
        "work.task.create" => task_create(&me, input).await,
        "work.task.update" => task_update(&scope, input).await,
        "work.followThrough" => follow_through(&scope, input).await,
        "work.note" => note_get(&scope, input).await,
        "work.note.save" => note_save(&me, &scope, input).await,
        "calendar.outcome.post" => outcome_post(&me, &scope, input).await,
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    }
}

fn shape_task(t: &Value) -> Value {
    let (done, due) = (ts(t, "completed_at"), ts(t, "due_at"));
    let nul = |k: &str| t.get(k).cloned().filter(|x| !x.is_null()).unwrap_or(Value::Null);
    json!({
        "id": t.get("id"), "title": t.get("title"),
        "status": t.get("status").and_then(|x| x.as_str()).filter(|s| !s.is_empty()).unwrap_or("todo"),
        "owner": nul("owner"), "due_at": nul("due_at"), "thread_id": nul("thread_id"), "thread_subject": nul("thread_subject"),
        "event_id": nul("event_id"),
        "source": t.get("source").and_then(|x| x.as_str()).filter(|s| !s.is_empty()).unwrap_or("manual"),
        "created_at": t.get("created_at"), "completed_at": nul("completed_at"),
        "late": c::task_late(done, due),
    })
}

async fn tasks(me: &crate::MailMe, scope: &str, input: &Value) -> Resp {
    let mut q = format!("work_tasks?select=*&{scope}&order=created_at.desc&limit=400");
    for k in ["thread_id", "event_id"] {
        let v = st(input, k);
        if !v.is_empty() {
            q.push_str(&format!("&{k}=eq.{}", enc(&v)));
        }
    }
    if st(input, "view") == "mine" {
        q.push_str(&format!("&owner=eq.{}", enc(&me.email)));
    }
    match crate::sb_select(&q).await {
        Ok(v) => crate::ok(json!({ "tasks": v.as_array().cloned().unwrap_or_default().iter().map(shape_task).collect::<Vec<_>>() })).into_response(),
        Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Tasks could not be read"),
    }
}

async fn promises(scope: &str) -> Resp {
    let q = format!("work_promises?select=*&{scope}&status=eq.suggested&order=detected_at.desc&limit=100");
    match crate::sb_select(&q).await {
        Ok(v) => {
            let list: Vec<Value> = v
                .as_array()
                .cloned()
                .unwrap_or_default()
                .iter()
                .map(|p| {
                    json!({
                        "id": p.get("id"), "quote": p.get("quote"), "suggested_title": p.get("suggested_title"),
                        "suggested_due_at": p.get("suggested_due_at").cloned().filter(|x| !x.is_null()).unwrap_or(Value::Null),
                        "thread_id": p.get("thread_id"),
                        "thread_subject": p.get("thread_subject").cloned().filter(|x| !x.is_null()).unwrap_or(Value::Null),
                        "detected_at": p.get("detected_at").filter(|x| !x.is_null()).or_else(|| p.get("created_at")),
                        "confidence": num(p, "confidence"),
                    })
                })
                .collect();
            crate::ok(json!({ "promises": list })).into_response()
        }
        Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Promises could not be read"),
    }
}

/// Bun scopedDeals/scopedLeads: Pro = sirf apni email; Business+ = poori workspace ke owners.
async fn crm_overview(me: &crate::MailMe, plan: &str, input: &Value) -> Resp {
    let _ = input;
    let owners: Vec<String> = if plan.trim().eq_ignore_ascii_case("pro") || me.org_id.is_empty() {
        vec![me.email.to_lowercase()]
    } else {
        let mut o: Vec<String> = match crate::sb_select(&format!("org_members?select=email&org_id=eq.{}&limit=2000", enc(&me.org_id))).await {
            Ok(v) => v.as_array().cloned().unwrap_or_default().iter().map(|m| st(m, "email").trim().to_lowercase()).filter(|e| !e.is_empty()).collect(),
            Err(_) => vec![],
        };
        o.push(me.email.to_lowercase());
        o.sort();
        o.dedup();
        o
    };
    let list = owners.iter().map(|e| format!("%22{}%22", enc(e))).collect::<Vec<_>>().join(",");
    let (dq, lq) = (format!("crm_deals?select=*&owner=in.({list})&limit=5000"), format!("crm_leads?select=*&owner=in.({list})&limit=5000"));
    let (deals_r, leads_r) = tokio::join!(crate::sb_select(&dq), crate::sb_select(&lq));
    // Bun safe(): tableen na hon / error => khali (jhoota number nahi, sirf 0)
    let deals_v = deals_r.ok().and_then(|v| v.as_array().cloned()).unwrap_or_default();
    let leads_v = leads_r.ok().and_then(|v| v.as_array().cloned()).unwrap_or_default();
    let deals: Vec<c::DealIn> = deals_v
        .iter()
        .map(|d| c::DealIn {
            stage: st(d, "stage"),
            value: num(d, "value"),
            prob: d.get("probability").filter(|x| !x.is_null()).map(|_| num(d, "probability")),
            updated: ts(d, "updated_at"),
        })
        .collect();
    let leads: Vec<c::LeadIn> = leads_v
        .iter()
        .map(|l| c::LeadIn { state: st(l, "state"), touched: l.get("last_touch_at").map(|x| !x.is_null()).unwrap_or(false) })
        .collect();
    let o = c::overview(&deals, &leads, now_secs());
    crate::ok(json!({
        "currency": deals_v.first().and_then(|d| d.get("currency")).and_then(|x| x.as_str()).unwrap_or("GBP"),
        "pipeline_value": o.pipeline_value, "weighted_value": o.weighted_value, "won_this_month": o.won_this_month,
        "open_deals": o.open_deals, "leads_new": o.leads_new, "leads_unworked": o.leads_unworked, "stale_deals": o.stale_deals,
        "avg_first_reply_minutes": Value::Null,
        "stage_counts": o.stage_counts.iter().map(|s| json!({ "stage": s.stage, "count": s.count, "value": s.value })).collect::<Vec<_>>(),
    }))
    .into_response()
}

// ── Pro 7 endpoints (27 Oct): Bun calendar.ts /work/tasks POST+PATCH, /work/follow-through, /work/notes GET+POST, /calendar/events/:id/outcome ──
fn nz(v: &Value, k: &str) -> Value {
    v.get(k).cloned().filter(|x| !x.is_null()).unwrap_or(Value::Null)
}

fn iso_now() -> String {
    c::iso_utc(now_secs())
}

async fn task_create(me: &crate::MailMe, input: &Value) -> Resp {
    let Some(title) = c::task_title(&st(input, "title")) else {
        return fail(StatusCode::BAD_REQUEST, "bad_title", "Title is required");
    };
    for k in ["thread_id", "event_id"] {
        let v = st(input, k);
        if !v.is_empty() && !c::uuid_ok(&v) && k == "event_id" {
            return fail(StatusCode::BAD_REQUEST, "bad_event", "Event id is not valid");
        }
    }
    let owner = match input.get("owner") {
        Some(Value::String(s)) if !s.trim().is_empty() => json!(s.trim()),
        Some(Value::Null) => Value::Null,
        _ => json!(me.email),
    };
    let body = json!({
        "org_id": if me.org_id.is_empty() { Value::Null } else { json!(me.org_id) },
        "title": title, "status": "todo", "owner": owner,
        "due_at": nz(input, "due_at"), "thread_id": nz(input, "thread_id"), "event_id": nz(input, "event_id"),
        "source": "manual", "created_by": me.id,
    });
    match crate::sb_insert("work_tasks", body).await {
        Ok(v) => {
            let row = v.as_array().and_then(|a| a.first().cloned()).unwrap_or(Value::Null);
            crate::ok(json!({ "task": shape_task(&row) })).into_response()
        }
        Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Task could not be saved"),
    }
}

async fn task_update(scope: &str, input: &Value) -> Resp {
    let id = st(input, "id");
    if !c::uuid_ok(&id) {
        return fail(StatusCode::BAD_REQUEST, "bad_id", "Task id is not valid");
    }
    let mut patch = serde_json::Map::new();
    let status = st(input, "status");
    if !status.is_empty() {
        if !c::status_ok(&status) {
            return fail(StatusCode::BAD_REQUEST, "bad_status", "Status must be todo, doing, waiting or done");
        }
        patch.insert("completed_at".into(), if status == "done" { json!(iso_now()) } else { Value::Null });
        patch.insert("status".into(), json!(status));
    }
    for k in ["owner", "due_at"] {
        if input.get(k).is_some() {
            patch.insert(k.into(), nz(input, k));
        }
    }
    let q = format!("work_tasks?select=*&id=eq.{}&{scope}&limit=1", enc(&id));
    let exists = crate::sb_select(&q).await.ok().and_then(|v| v.as_array().and_then(|a| a.first().cloned()));
    if exists.is_none() {
        return fail(StatusCode::NOT_FOUND, "not_found", "Task not found");
    }
    if !patch.is_empty() {
        if crate::sb_patch(&format!("work_tasks?id=eq.{}&{scope}", enc(&id)), Value::Object(patch)).await.is_err() {
            return fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Task could not be updated");
        }
    }
    match crate::sb_select(&q).await.ok().and_then(|v| v.as_array().and_then(|a| a.first().cloned())) {
        Some(row) => crate::ok(json!({ "task": shape_task(&row) })).into_response(),
        None => fail(StatusCode::NOT_FOUND, "not_found", "Task not found"),
    }
}

async fn follow_through(scope: &str, input: &Value) -> Resp {
    let team = st(input, "scope") == "team";
    let q = format!("work_tasks?select=owner,status,due_at,completed_at&{scope}&due_at=not.is.null&limit=5000");
    let rows = match crate::sb_select(&q).await {
        Ok(v) => v.as_array().cloned().unwrap_or_default(),
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Follow-through could not be read"),
    };
    let now = now_secs();
    let mut by: Vec<(String, c::Bucket)> = Vec::new();
    for t in &rows {
        let Some(due) = ts(t, "due_at") else { continue };
        let key = if team { "team".to_string() } else { Some(st(t, "owner")).filter(|o| !o.is_empty()).unwrap_or_else(|| "unassigned".into()) };
        let class = c::ft_class(ts(t, "completed_at"), due, now);
        match by.iter_mut().find(|(k, _)| *k == key) {
            Some((_, b)) => c::ft_add(b, class),
            None => {
                let mut b = c::Bucket { made: 0, on_time: 0, late: 0, broken: 0 };
                c::ft_add(&mut b, class);
                by.push((key, b));
            }
        }
    }
    let mut out: Vec<(Option<i64>, Value)> = by
        .iter()
        .map(|(k, b)| {
            let score = c::ft_score(b);
            (score, json!({
                "scope": if team { "team" } else { "person" }, "subject": k, "display_name": Value::Null,
                "promises_made": b.made, "kept_on_time": b.on_time, "kept_late": b.late, "broken": b.broken,
                "score": score.map(|x| json!(x)).unwrap_or(Value::Null),
            }))
        })
        .collect();
    out.sort_by(|a, b| b.0.unwrap_or(0).cmp(&a.0.unwrap_or(0)));
    crate::ok(json!({ "rows": out.into_iter().map(|x| x.1).collect::<Vec<_>>() })).into_response()
}

async fn note_get(scope: &str, input: &Value) -> Resp {
    let (tid, eid) = (st(input, "thread_id"), st(input, "event_id"));
    let filt = if !tid.is_empty() {
        format!("thread_id=eq.{}", enc(&tid))
    } else if !eid.is_empty() && c::uuid_ok(&eid) {
        format!("event_id=eq.{}", enc(&eid))
    } else {
        return crate::ok(json!({ "note": Value::Null })).into_response();
    };
    let q = format!("work_notes?select=*&{scope}&{filt}&order=updated_at.desc&limit=1");
    match crate::sb_select(&q).await {
        Ok(v) => {
            let note = v.as_array().and_then(|a| a.first().cloned()).map(|d| {
                json!({
                    "id": d.get("id"), "body": d.get("body").and_then(|x| x.as_str()).unwrap_or(""),
                    "thread_id": nz(&d, "thread_id"), "event_id": nz(&d, "event_id"),
                    "updated_at": d.get("updated_at").filter(|x| !x.is_null()).or_else(|| d.get("created_at")),
                    "updated_by": nz(&d, "updated_by"),
                })
            });
            crate::ok(json!({ "note": note.unwrap_or(Value::Null) })).into_response()
        }
        Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Note could not be read"),
    }
}

async fn note_save(me: &crate::MailMe, scope: &str, input: &Value) -> Resp {
    let body = input.get("body").and_then(|x| x.as_str()).unwrap_or("").to_string();
    if !c::note_len_ok(&body) {
        return fail(StatusCode::BAD_REQUEST, "too_long", "A note can be up to 20,000 characters");
    }
    let (tid, eid) = (st(input, "thread_id"), st(input, "event_id"));
    if tid.is_empty() && eid.is_empty() {
        return fail(StatusCode::BAD_REQUEST, "no_target", "A note belongs to a thread or a meeting");
    }
    if tid.is_empty() && !c::uuid_ok(&eid) {
        return fail(StatusCode::BAD_REQUEST, "bad_event", "Event id is not valid");
    }
    let filt = if !tid.is_empty() { format!("thread_id=eq.{}", enc(&tid)) } else { format!("event_id=eq.{}", enc(&eid)) };
    let q = format!("work_notes?select=id&{scope}&{filt}&limit=1");
    let existing = crate::sb_select(&q).await.ok().and_then(|v| v.as_array().and_then(|a| a.first().cloned()));
    if let Some(row) = existing {
        let id = st(&row, "id");
        return match crate::sb_patch(&format!("work_notes?id=eq.{}", enc(&id)), json!({ "body": body, "updated_at": iso_now(), "updated_by": me.email })).await {
            Ok(_) => crate::ok(json!({ "ok": true, "id": id })).into_response(),
            Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Note could not be saved"),
        };
    }
    let ins = json!({
        "org_id": if me.org_id.is_empty() { Value::Null } else { json!(me.org_id) },
        "body": body, "thread_id": if tid.is_empty() { Value::Null } else { json!(tid) },
        "event_id": if tid.is_empty() { json!(eid) } else { Value::Null },
        "updated_by": me.email, "created_by": me.id,
    });
    match crate::sb_insert("work_notes", ins).await {
        Ok(v) => {
            let id = v.as_array().and_then(|a| a.first()).map(|r| st(r, "id")).unwrap_or_default();
            crate::ok(json!({ "ok": true, "id": id })).into_response()
        }
        Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Note could not be saved"),
    }
}

async fn outcome_post(me: &crate::MailMe, scope: &str, input: &Value) -> Resp {
    let id = st(input, "event_id");
    if !c::uuid_ok(&id) {
        return fail(StatusCode::BAD_REQUEST, "bad_id", "Event id is not valid");
    }
    let q = format!("calendar_events?select=*&id=eq.{}&{scope}&limit=1", enc(&id));
    let Some(e) = crate::sb_select(&q).await.ok().and_then(|v| v.as_array().and_then(|a| a.first().cloned())) else {
        return fail(StatusCode::NOT_FOUND, "not_found", "Event not found");
    };
    let outcome = e.get("outcome").cloned().filter(|x| !x.is_null());
    let Some(outcome) = outcome else {
        return fail(StatusCode::CONFLICT, "no_outcome", "No outcome recorded for this meeting yet");
    };
    let items: Vec<Value> = outcome.get("action_items").and_then(|x| x.as_array()).cloned().unwrap_or_default();
    let thread = nz(&e, "thread_id");
    let org = if me.org_id.is_empty() { Value::Null } else { json!(me.org_id) };
    if !items.is_empty() {
        let rows: Vec<Value> = items
            .iter()
            .map(|i| json!({
                "org_id": org, "title": i.get("title"), "owner": nz(i, "owner"), "due_at": nz(i, "due_at"),
                "status": "todo", "event_id": id, "thread_id": thread, "source": "meeting_outcome", "created_by": me.id,
            }))
            .collect();
        if crate::sb_insert("work_tasks", Value::Array(rows)).await.is_err() {
            return fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Action items could not be saved");
        }
    }
    if !thread.is_null() {
        let _ = crate::sb_insert("mail_thread_events", json!({
            "org_id": org, "thread_id": thread, "kind": "meeting_outcome_posted", "actor": me.email,
            "payload": { "event_id": id, "decisions": outcome.get("decisions").cloned().unwrap_or(json!([])) },
        })).await;
    }
    let _ = crate::sb_patch(&format!("calendar_events?id=eq.{}", enc(&id)), json!({ "outcome_posted_at": iso_now() })).await;
    crate::ok(json!({ "ok": true, "tasks_created": items.len() })).into_response()
}
