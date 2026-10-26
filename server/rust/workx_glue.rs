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
