// ============================================================================
// livex_glue — `crm.live` (CRM radar/timeline/graph) aur `org.members`: Bun se Rust (Tokio async). Rule 52: wahi dispatch HTTP /rpc/<proc> AUR WebTransport /wt/rpc par.
//   crm.live     {org_id?}   -> {radar, next_actions, timeline, people, graph:{nodes,edges}, counts}   (Bun GET /api/crm/live jaisa shape; Pro+)
//   org.members  {status?}   -> {members:[...]}                                                        (Bun GET /api/org/members jaisa; login + org)
// Hisaab livex_core.rs (std-only, tested). Org na ho => crm.live 409 no_workspace (Bun jaisa), org.members 404 org_not_found (UI Bun par girta hai: founder-fallback sirf Bun mein).
// ============================================================================

use crate::livex_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(proc, "crm.live" | "org.members")
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn opt(v: &Value, k: &str) -> Option<String> {
    v.get(k).and_then(|x| x.as_str()).filter(|s| !s.is_empty()).map(|s| s.to_string())
}

fn nul(v: &Value, k: &str) -> Value {
    v.get(k).cloned().filter(|x| !x.is_null()).unwrap_or(Value::Null)
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

fn ts(v: &Value, k: &str) -> Option<i64> {
    v.get(k).and_then(|x| x.as_str()).and_then(crate::cal_core::parse_ts)
}

fn now_secs() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

/// Bun `safe()`: error / table nahi => khali list (jhoota data nahi).
async fn rows(q: &str) -> Vec<Value> {
    match crate::sb_select(q).await {
        Ok(v) => v.as_array().cloned().unwrap_or_default(),
        Err(_) => vec![],
    }
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let me = match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(m) => m,
        Err((s, code, m)) => return crate::err(s, code, &m).into_response(),
    };
    match proc {
        "org.members" => org_members(&me, input).await,
        "crm.live" => {
            let plan = crate::sb_rpc("resolve_plan", json!({ "_user_id": me.id, "_email": me.email }))
                .await
                .ok()
                .and_then(|v| v.as_str().map(|s| s.to_string()))
                .unwrap_or_else(|| "basic".to_string());
            if let Some(msg) = c::pro_only(proc) {
                if !crate::workx_core::plan_allows_pro(&plan) {
                    return fail(StatusCode::FORBIDDEN, "feature_not_available", msg);
                }
            }
            if me.org_id.is_empty() {
                return fail(StatusCode::CONFLICT, "no_workspace", "No workspace");
            }
            crm_live(&me, &plan).await
        }
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    }
}

/* ------------------------------------------------------------------ org.members */

async fn org_members(me: &crate::MailMe, input: &Value) -> Resp {
    if me.org_id.is_empty() {
        return fail(StatusCode::NOT_FOUND, "org_not_found", "No organisation for this account");
    }
    let org = enc(&me.org_id);
    let (mem_q, use_q, ses_q) = (
        format!("org_members?select=*&org_id=eq.{org}&limit=2000"),
        format!("org_privilege_usage?select=*&org_id=eq.{org}&limit=2000"),
        format!("org_sessions?select=user_id&org_id=eq.{org}&limit=5000"),
    );
    let (members, usage, sessions) = tokio::join!(rows(&mem_q), rows(&use_q), rows(&ses_q));
    let want = st(input, "status");
    let want = c::status_filter(&want).to_string();
    let mut sess: HashMap<String, usize> = HashMap::new();
    for s in &sessions {
        *sess.entry(st(s, "user_id")).or_insert(0) += 1;
    }
    let out: Vec<Value> = members
        .iter()
        .filter(|r| want == "all" || c::status_or_active(r.get("status").and_then(|x| x.as_str())) == want)
        .map(|r| {
            let uid = st(r, "user_id");
            let used = usage.iter().find(|u| st(u, "user_id") == uid).map(|u| nul(u, "last_used_at")).unwrap_or(Value::Null);
            json!({
                "user_id": r.get("user_id").cloned().unwrap_or(Value::Null),
                "email": st(r, "email"),
                "display_name": nul(r, "display_name"),
                "role": opt(r, "role").unwrap_or_else(|| "member".to_string()),
                "department": nul(r, "department"),
                "status": c::status_or_active(r.get("status").and_then(|x| x.as_str())),
                "mfa": r.get("mfa").and_then(|x| x.as_bool()).unwrap_or(false),
                "sessions": sess.get(&uid).copied().unwrap_or(0),
                "last_active_at": nul(r, "last_active_at"),
                "admin_power_last_used_at": used,
            })
        })
        .collect();
    crate::ok(json!({ "members": out })).into_response()
}

/* ------------------------------------------------------------------ crm.live */

struct Person {
    id: String,
    display_name: Value,
    addr: String,
    company: Value,
    relationship: Value,
    health: Option<f64>,
    last_contact_at: Value,
    open_threads: i64,
}

fn person_json(p: &Person) -> Value {
    json!({
        "id": p.id, "display_name": p.display_name, "primary_address": p.addr, "company_name": p.company,
        "relationship": p.relationship, "health_score": p.health.map(|h| json!(h)).unwrap_or(Value::Null),
        "last_contact_at": p.last_contact_at, "open_threads": p.open_threads,
    })
}

fn f64_of(v: Option<&Value>) -> Option<f64> {
    match v {
        Some(Value::Number(n)) => n.as_f64(),
        Some(Value::String(s)) => s.parse().ok(),
        _ => None,
    }
}

/// Bun shapePerson (contacts row, stats embed ek object; array/None => khali).
fn shape_person(row: &Value) -> Person {
    let empty = Value::Null;
    let s = match row.get("stats") {
        Some(o @ Value::Object(_)) => o,
        _ => &empty,
    };
    let pick = |k: &str| -> Option<Value> {
        s.get(k).filter(|x| !x.is_null()).cloned().or_else(|| row.get(k).filter(|x| !x.is_null()).cloned())
    };
    let company = row
        .get("company")
        .and_then(|c| c.get("name"))
        .and_then(|x| x.as_str())
        .filter(|x| !x.is_empty())
        .map(|x| x.to_string())
        .or_else(|| opt(row, "company_name"))
        .or_else(|| opt(row, "company_domain"));
    Person {
        id: row.get("id").map(|x| x.as_str().map(|s| s.to_string()).unwrap_or_else(|| x.to_string())).unwrap_or_default(),
        display_name: nul(row, "display_name"),
        addr: c::email_of(&st(row, "primary_address")),
        company: company.map(Value::String).unwrap_or(Value::Null),
        relationship: s
            .get("relationship")
            .filter(|x| x.as_str().map(|v| !v.is_empty()).unwrap_or(false))
            .cloned()
            .or_else(|| row.get("relationship").filter(|x| x.as_str().map(|v| !v.is_empty()).unwrap_or(false)).cloned())
            .unwrap_or(Value::Null),
        health: f64_of(pick("health_score").as_ref()),
        last_contact_at: s
            .get("last_contact_at")
            .filter(|x| x.as_str().map(|v| !v.is_empty()).unwrap_or(false))
            .cloned()
            .or_else(|| row.get("last_contact_at").filter(|x| !x.is_null()).cloned())
            .unwrap_or(Value::Null),
        open_threads: f64_of(pick("open_threads").as_ref()).map(|n| n as i64).unwrap_or(0),
    }
}

fn owner_list(o: &[String]) -> String {
    o.iter().map(|e| format!("%22{}%22", enc(&e.replace('"', "")))).collect::<Vec<_>>().join(",")
}

async fn owners(me: &crate::MailMe, plan: &str) -> Vec<String> {
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

fn is_open(d: &Value) -> bool {
    let s = st(d, "stage");
    s != "won" && s != "lost"
}

async fn crm_live(me: &crate::MailMe, plan: &str) -> Resp {
    let now = now_secs();
    let org = enc(&me.org_id);
    let owners = owners(me, plan).await;
    let list = owner_list(&owners);
    let since = enc(&crate::cal_core::fmt_rfc3339(now - 40 * 86_400));
    let (dq, lq) = (format!("crm_deals?select=*&owner=in.({list})&limit=5000"), format!("crm_leads?select=*&owner=in.({list})&limit=5000"));
    let cq = format!("contacts?select=id,display_name,primary_address,company_domain,health_score,last_contact_at,stats:contact_stats(messages_in,messages_out,avg_reply_minutes,open_threads,last_contact_at,relationship,health_score)&org_id=eq.{org}&limit=400");
    let cq2 = format!("contacts?select=id,display_name,primary_address,company_domain,health_score,last_contact_at&org_id=eq.{org}&limit=400");
    let tq = format!("work_tasks?select=id,title,status,due_at,owner,thread_id,source,created_at,thread_subject&org_id=eq.{org}&limit=300");
    let pq = format!("work_promises?select=id,quote,suggested_title,suggested_due_at,status,thread_id,thread_subject&org_id=eq.{org}&limit=200");
    let eq = format!("calendar_events?select=id,title,starts_at,organiser,thread_id&org_id=eq.{org}&starts_at=gte.{since}&limit=200");
    let aq = format!("calendar_attendees?select=event_id,address,org_id&org_id=eq.{org}&limit=2000");
    let mq = format!("mail_messages?select=id,thread_id,subject,from_address,direction,sent_at&org_id=eq.{org}&order=sent_at.desc&limit=40");
    let xq = "crm_activities?select=id,kind,subject,actor,deal_id,contact_email,created_at&order=created_at.desc&limit=300".to_string();
    let gq = format!("crm_graph_edges?select=from_kind,from_id,to_kind,to_id,kind&org_id=eq.{org}&limit=80");
    let (deals, leads, mut contact_rows, tasks, promises, events, attendees, mut mail, acts_all, stored) =
        tokio::join!(rows(&dq), rows(&lq), rows(&cq), rows(&tq), rows(&pq), rows(&eq), rows(&aq), rows(&mq), rows(&xq), rows(&gq));
    if contact_rows.is_empty() {
        contact_rows = rows(&cq2).await;
    }
    if mail.is_empty() {
        let mtq = format!("mail_threads?select=id,subject,from_address,last_message_at,status,folder&org_id=eq.{org}&order=last_message_at.desc&limit=40");
        mail = rows(&mtq)
            .await
            .iter()
            .map(|t| {
                let open = t.get("status").and_then(|x| x.as_str()) == Some("open") || t.get("folder").and_then(|x| x.as_str()) == Some("inbox");
                json!({"id": t.get("id"), "thread_id": t.get("id"), "subject": t.get("subject"), "from_address": t.get("from_address"),
                       "direction": "in", "sent_at": t.get("last_message_at"), "open": open})
            })
            .collect();
    }
    // crm_activities mein org_id nahi: sirf is workspace ke logon ki likhi/unke baare mein (Bun jaisa tenant filter)
    let owner_set: HashSet<String> = owners.iter().cloned().collect();
    let acts: Vec<&Value> = acts_all
        .iter()
        .filter(|a| owner_set.contains(&c::email_of(&st(a, "actor"))) || owner_set.contains(&c::email_of(&st(a, "contact_email"))))
        .take(40)
        .collect();

    // ---- people (contacts + deal/lead se bane)
    let mut people: Vec<Person> = vec![];
    let mut idx: HashMap<String, usize> = HashMap::new();
    for row in &contact_rows {
        let p = shape_person(row);
        if p.addr.contains('@') {
            match idx.get(&p.addr) {
                Some(&i) => people[i] = p,
                None => {
                    idx.insert(p.addr.clone(), people.len());
                    people.push(p);
                }
            }
        }
    }
    for d in &deals {
        let a = c::email_of(&st(d, "contact_email"));
        if !a.contains('@') || idx.contains_key(&a) {
            continue;
        }
        idx.insert(a.clone(), people.len());
        people.push(Person {
            id: d.get("id").and_then(|x| x.as_str()).unwrap_or("").to_string(),
            display_name: opt(d, "company").map(Value::String).unwrap_or(Value::String(a.clone())),
            addr: a,
            company: nul(d, "company"),
            relationship: Value::Null,
            health: None,
            last_contact_at: nul(d, "updated_at"),
            open_threads: 0,
        });
    }
    for l in &leads {
        let a = c::email_of(&st(l, "email"));
        if !a.contains('@') || idx.contains_key(&a) {
            continue;
        }
        idx.insert(a.clone(), people.len());
        people.push(Person {
            id: l.get("id").and_then(|x| x.as_str()).unwrap_or("").to_string(),
            display_name: opt(l, "display_name").map(Value::String).unwrap_or(Value::String(a.clone())),
            addr: a,
            company: nul(l, "company"),
            relationship: Value::Null,
            health: None,
            last_contact_at: l.get("last_touch_at").filter(|x| !x.is_null()).or_else(|| l.get("created_at")).cloned().unwrap_or(Value::Null),
            open_threads: 0,
        });
    }

    let open: Vec<&Value> = deals.iter().filter(|d| is_open(d)).collect();
    let mut radar: Vec<Value> = vec![];
    let mut next: Vec<Value> = vec![];

    // mail se open_threads
    let mut open_mail: HashMap<String, i64> = HashMap::new();
    for m in &mail {
        let a = c::email_of(&st(m, "from_address"));
        if !a.contains('@') {
            continue;
        }
        if m.get("open").and_then(|x| x.as_bool()).unwrap_or(false) || st(m, "direction") == "in" {
            *open_mail.entry(a).or_insert(0) += 1;
        }
    }
    for p in people.iter_mut() {
        if p.open_threads == 0 {
            p.open_threads = open_mail.get(&p.addr).copied().unwrap_or(0);
        }
    }

    // ---- deals: silent + meeting gap
    for d in &open {
        let quiet = c::days_since(now, ts(d, "updated_at")).unwrap_or(0);
        let thread = opt(d, "thread_id");
        let title = st(d, "title");
        if quiet >= c::SILENT_DAYS {
            let href = thread.as_ref().map(|t| format!("/app/mail/inbox/{t}")).unwrap_or_else(|| "/app/crm/pipeline".to_string());
            radar.push(json!({"kind": "silent", "title": title, "why": format!("Deal untouched {quiet} days"), "source": format!("crm_deals:{}", st(d, "id")), "href": href}));
            next.push(json!({"kind": "follow_up", "title": title, "action": "Write the thread or set a next step", "why": format!("{quiet} days silent"), "href": href}));
        }
        let contact = c::email_of(&st(d, "contact_email"));
        if !contact.is_empty() {
            let meet_ids: HashSet<String> = attendees.iter().filter(|a| c::email_of(&st(a, "address")) == contact).map(|a| st(a, "event_id")).collect();
            let mut cand: Vec<&Value> = events.iter().filter(|e| meet_ids.contains(&st(e, "id")) || c::email_of(&st(e, "organiser")) == contact).collect();
            cand.sort_by(|a, b| st(b, "starts_at").cmp(&st(a, "starts_at")));
            let last = cand.first();
            let gap: Option<i64> = match last {
                Some(e) => c::days_since(now, ts(e, "starts_at")),
                None => Some(999),
            };
            if gap.map(|g| g >= c::MEETING_GAP_DAYS).unwrap_or(false) {
                let why = match last {
                    Some(e) => format!("Last meeting {}", st(e, "starts_at")),
                    None => "No meeting on record".to_string(),
                };
                next.push(json!({"kind": "meeting", "title": title, "action": "No decision-maker meeting in 12 days", "why": why, "href": "/app/calendar"}));
            }
        }
    }

    // ---- contacts: health score + no_pitch + health radar
    for p in people.iter_mut() {
        let name = p.display_name.as_str().map(|s| s.to_string()).filter(|s| !s.is_empty()).unwrap_or_else(|| p.addr.clone());
        let quiet = c::days_since(now, p.last_contact_at.as_str().and_then(crate::cal_core::parse_ts));
        if p.health.is_none() {
            p.health = Some(c::default_health(quiet, p.open_threads) as f64);
        }
        if p.open_threads > 0 {
            next.push(json!({"kind": "no_pitch", "title": name, "action": "Don't send a sales email — an open support thread is still waiting",
                             "why": format!("{} open mail threads", p.open_threads), "href": "/app/mail/inbox"}));
        }
        let rel = p.relationship.as_str().unwrap_or("").to_string();
        let has_deal = open.iter().any(|d| c::email_of(&st(d, "contact_email")) == p.addr);
        if c::health_radar(&rel, quiet, has_deal) {
            radar.push(json!({"kind": "health", "title": name, "why": c::health_why(&rel, p.health, quiet),
                              "source": format!("contacts:{}", p.id), "href": format!("/app/crm/relationships?email={}", enc(&p.addr))}));
        }
    }

    // ---- overdue tasks + promises
    for t in &tasks {
        if st(t, "status") == "done" {
            continue;
        }
        if ts(t, "due_at").map(|d| d < now).unwrap_or(false) {
            let due = st(t, "due_at");
            radar.push(json!({"kind": "promise_overdue", "title": t.get("title"), "why": format!("Due {due}"), "source": format!("work_tasks:{}", st(t, "id")), "href": "/app/work"}));
            next.push(json!({"kind": "promise", "title": t.get("title"), "action": "Promise overdue — complete with evidence or move the date", "why": format!("work_tasks:{}", st(t, "id")), "href": "/app/work"}));
        }
    }
    for pr in &promises {
        let due = st(pr, "suggested_due_at");
        if due.is_empty() || ts(pr, "suggested_due_at").map(|d| d >= now).unwrap_or(true) {
            continue;
        }
        let s = st(pr, "status");
        if s == "done" || s == "kept" {
            continue;
        }
        let title = c::promise_title(&st(pr, "suggested_title"), &st(pr, "quote"));
        radar.push(json!({"kind": "promise_overdue", "title": title, "why": format!("Due {due}"), "source": format!("work_promises:{}", st(pr, "id")), "href": "/app/work"}));
        next.push(json!({"kind": "promise", "title": title, "action": "Promise overdue — complete with evidence or move the date", "why": format!("work_promises:{}", st(pr, "id")), "href": "/app/work"}));
    }

    // ---- timeline
    let mut tl: Vec<Value> = vec![];
    for m in &mail {
        let tid = opt(m, "thread_id");
        tl.push(json!({"at": m.get("sent_at"), "kind": if st(m, "direction") == "out" { "email_out" } else { "email_in" },
                       "title": opt(m, "subject").unwrap_or_else(|| "(no subject)".to_string()), "source": m.get("from_address"),
                       "href": tid.map(|t| format!("/app/mail/inbox/{t}")).unwrap_or_else(|| "/app/mail/inbox".to_string())}));
    }
    for e in events.iter().take(20) {
        tl.push(json!({"at": e.get("starts_at"), "kind": "meeting", "title": e.get("title"), "source": e.get("organiser"), "href": "/app/calendar"}));
    }
    for t in tasks.iter().filter(|t| opt(t, "created_at").is_some() || opt(t, "due_at").is_some()).take(20) {
        tl.push(json!({"at": opt(t, "created_at").or_else(|| opt(t, "due_at")), "kind": "work", "title": t.get("title"), "source": t.get("owner"), "href": "/app/work"}));
    }
    for a in &acts {
        tl.push(json!({"at": a.get("created_at"), "kind": opt(a, "kind").unwrap_or_else(|| "note".to_string()),
                       "title": opt(a, "subject").or_else(|| opt(a, "kind")), "source": a.get("actor"), "href": "/app/crm/activity"}));
    }
    tl.retain(|r| r.get("at").and_then(|x| x.as_str()).map(|s| !s.is_empty()).unwrap_or(false));
    // Naya pehle: asli waqt se (Bun ka localeCompare "…:19+00:00" ko "…:19.925+00:00" se pehle rakhta tha — ghalat tarteeb). Barabar second par string.
    tl.sort_by(|a, b| ts(b, "at").cmp(&ts(a, "at")).then_with(|| st(b, "at").cmp(&st(a, "at"))));
    tl.truncate(30);

    // ---- graph
    let mut nodes: Vec<Value> = vec![];
    let mut seen: HashSet<String> = HashSet::new();
    for p in people.iter().take(40) {
        let id = format!("person:{}", p.id);
        seen.insert(id.clone());
        nodes.push(json!({"id": id, "kind": "person", "label": p.display_name.as_str().filter(|s| !s.is_empty()).unwrap_or(&p.addr), "email": p.addr}));
    }
    for d in open.iter().take(40) {
        let id = format!("deal:{}", st(d, "id"));
        seen.insert(id.clone());
        nodes.push(json!({"id": id, "kind": "deal", "label": d.get("title"), "email": d.get("contact_email")}));
    }
    let mut add_node = |nodes: &mut Vec<Value>, id: String, kind: &str, label: Value| {
        if seen.insert(id.clone()) {
            nodes.push(json!({"id": id, "kind": kind, "label": label}));
        }
    };
    let mut edges: Vec<Value> = vec![];
    let edge = |from: String, to: String, kind: &str| json!({"from": from, "to": to, "kind": kind});
    let person_by = |addr: &str| people.iter().find(|p| p.addr == addr);
    for d in &open {
        if let Some(p) = person_by(&c::email_of(&st(d, "contact_email"))) {
            edges.push(edge(format!("person:{}", p.id), format!("deal:{}", st(d, "id")), "owns"));
        }
        if let Some(t) = opt(d, "thread_id") {
            add_node(&mut nodes, format!("mail:{t}"), "mail", d.get("title").cloned().unwrap_or(Value::Null));
            edges.push(edge(format!("deal:{}", st(d, "id")), format!("mail:{t}"), "thread"));
        }
    }
    for m in &mail {
        let Some(t) = opt(m, "thread_id") else { continue };
        add_node(&mut nodes, format!("mail:{t}"), "mail", Value::String(opt(m, "subject").unwrap_or_else(|| "(no subject)".to_string())));
        if let Some(p) = person_by(&c::email_of(&st(m, "from_address"))) {
            edges.push(edge(format!("person:{}", p.id), format!("mail:{t}"), "wrote"));
        }
    }
    for t in &tasks {
        let tid = st(t, "id");
        add_node(&mut nodes, format!("work:{tid}"), "work", t.get("title").cloned().unwrap_or(Value::Null));
        if let Some(p) = person_by(&c::email_of(&st(t, "owner"))) {
            edges.push(edge(format!("person:{}", p.id), format!("work:{tid}"), "assigned"));
        }
        let thread = opt(t, "thread_id");
        let source = st(t, "source");
        let deal = open
            .iter()
            .find(|d| thread.is_some() && opt(d, "thread_id") == thread)
            .or_else(|| open.iter().find(|d| !st(d, "id").is_empty() && source.contains(&st(d, "id"))));
        if let Some(d) = deal {
            edges.push(edge(format!("deal:{}", st(d, "id")), format!("work:{tid}"), "workstream"));
        }
        if let Some(th) = thread {
            let label = opt(t, "thread_subject").map(Value::String).or_else(|| t.get("title").cloned()).unwrap_or(Value::Null);
            add_node(&mut nodes, format!("mail:{th}"), "mail", label);
            edges.push(edge(format!("work:{tid}"), format!("mail:{th}"), "thread"));
        }
    }
    for e in &events {
        let eid = st(e, "id");
        add_node(&mut nodes, format!("calendar:{eid}"), "calendar", e.get("title").cloned().unwrap_or(Value::Null));
        let mut who: Vec<String> = attendees.iter().filter(|a| st(a, "event_id") == eid).map(|a| c::email_of(&st(a, "address"))).collect();
        if let Some(o) = opt(e, "organiser") {
            who.push(c::email_of(&o));
        }
        for a in who {
            if let Some(p) = person_by(&a) {
                edges.push(edge(format!("person:{}", p.id), format!("calendar:{eid}"), "attends"));
            }
        }
        if let Some(th) = opt(e, "thread_id") {
            add_node(&mut nodes, format!("mail:{th}"), "mail", e.get("title").cloned().unwrap_or(Value::Null));
            edges.push(edge(format!("calendar:{eid}"), format!("mail:{th}"), "thread"));
        }
    }
    for e in &stored {
        let (fk, tk) = (st(e, "from_kind"), st(e, "to_kind"));
        let (f, t) = (format!("{fk}:{}", st(e, "from_id")), format!("{tk}:{}", st(e, "to_id")));
        add_node(&mut nodes, f.clone(), &fk, Value::String(fk.clone()));
        add_node(&mut nodes, t.clone(), &tk, Value::String(tk.clone()));
        edges.push(edge(f, t, &st(e, "kind")));
    }
    edges.truncate(80);
    radar.truncate(24);
    next.truncate(16);

    let overdue = tasks.iter().filter(|t| st(t, "status") != "done" && ts(t, "due_at").map(|d| d < now).unwrap_or(false)).count();
    crate::ok(json!({
        "radar": radar, "next_actions": next, "timeline": tl,
        "people": people.iter().take(60).map(person_json).collect::<Vec<_>>(),
        "graph": { "nodes": nodes, "edges": edges },
        "counts": { "contacts": people.len(), "open_deals": open.len(), "overdue_tasks": overdue, "promises": promises.len() },
    }))
    .into_response()
}
