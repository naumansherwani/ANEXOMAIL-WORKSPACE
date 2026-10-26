// ============================================================================
// contx_glue — People / Companies / universal search, Rust PRIMARY (Tokio async; HTTP /rpc aur WebTransport /wt/rpc; Rule 52/56/57).
//   contacts.list{q,filter,tag} contacts.tags contacts.get{id} contacts.update{id,...} contacts.tag{id,add,remove} contacts.timeline{id}
//   companies.list{q} companies.get{domain} companies.timeline{domain} search.universal{q}
// Bun twin: server/routes/contacts.ts (fallback). SAB plans (Basic + Pro) — koi plan gate nahi (PP1 #10,#17,#31,#34); sirf login + workspace.
// Domain errors 409/400 (Rule 59: 404 sirf "proc nahi"). Hisab contx_core.rs mein.
// ============================================================================

use crate::contx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::owns_name(proc)
}

fn fail(s: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(s, code, msg).into_response()
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

fn arr(v: &Value) -> Vec<Value> {
    v.as_array().cloned().unwrap_or_default()
}

fn rows(r: Result<Value, String>) -> Vec<Value> {
    r.map(|v| arr(&v)).unwrap_or_default()
}

const SELECT_CONTACT: &str = "id,display_name,primary_address,addresses,title,company_domain,vip,notes,stats:contact_stats(messages_in,messages_out,avg_reply_minutes,open_threads,last_contact_at,relationship,health_score)";
const SELECT_PLAIN: &str = "id,display_name,primary_address,addresses,title,company_domain,vip,notes";

/// contacts select: pehle stats embed ke saath, schema-cache error par plain (Bun jaisa).
async fn contacts_query(tail: &str) -> Result<Vec<Value>, String> {
    match crate::sb_select(&format!("contacts?select={SELECT_CONTACT}&{tail}")).await {
        Ok(v) => Ok(arr(&v)),
        Err(e) if c::is_schema_cache_error(&e) => crate::sb_select(&format!("contacts?select={SELECT_PLAIN}&{tail}")).await.map(|v| arr(&v)),
        Err(e) => Err(e),
    }
}

fn stats_of(row: &Value) -> Value {
    match row.get("stats") {
        Some(Value::Array(a)) => a.first().cloned().unwrap_or(json!({})),
        Some(o) if o.is_object() => o.clone(),
        _ => json!({}),
    }
}

fn num(v: &Value, k: &str) -> i64 {
    v.get(k).and_then(|x| x.as_i64().or_else(|| x.as_f64().map(|f| f as i64))).unwrap_or(0)
}

fn person_stat(row: &Value) -> c::PersonStat {
    let s = stats_of(row);
    c::PersonStat {
        messages_in: num(&s, "messages_in"),
        messages_out: num(&s, "messages_out"),
        open_threads: num(&s, "open_threads"),
        last_contact_at: s.get("last_contact_at").and_then(|x| x.as_str()).map(|x| x.to_string()),
        relationship: relationship(row),
        health: s.get("health_score").and_then(|x| x.as_f64()),
    }
}

fn relationship(row: &Value) -> String {
    let s = stats_of(row);
    row.get("relationship").and_then(|x| x.as_str()).filter(|x| !x.is_empty()).map(|x| x.to_string())
        .or_else(|| s.get("relationship").and_then(|x| x.as_str()).filter(|x| !x.is_empty()).map(|x| x.to_string()))
        .unwrap_or_else(|| "new".into())
}

fn shape_contact(row: &Value, tags: &[String], company_name: Option<&str>) -> Value {
    let s = stats_of(row);
    let primary = row.get("primary_address").cloned().unwrap_or(Value::Null);
    let addresses = match row.get("addresses") {
        Some(Value::Array(a)) if !a.is_empty() => Value::Array(a.clone()),
        _ => json!([primary]),
    };
    json!({
        "id": row.get("id"),
        "display_name": row.get("display_name").cloned().unwrap_or(Value::Null),
        "primary_address": primary,
        "addresses": addresses,
        "title": row.get("title").cloned().unwrap_or(Value::Null),
        "company_domain": row.get("company_domain").cloned().unwrap_or(Value::Null),
        "company_name": company_name,
        "tags": tags,
        "vip": row.get("vip").and_then(|x| x.as_bool()).unwrap_or(false),
        "relationship": relationship(row),
        "health_score": s.get("health_score").cloned().unwrap_or(Value::Null),
        "last_contact_at": s.get("last_contact_at").cloned().unwrap_or(Value::Null),
        "messages_in": num(&s, "messages_in"),
        "messages_out": num(&s, "messages_out"),
        "avg_reply_minutes": s.get("avg_reply_minutes").cloned().unwrap_or(Value::Null),
        "open_threads": num(&s, "open_threads"),
        "notes": row.get("notes").cloned().unwrap_or(Value::Null),
    })
}

/// domain (lowercase) -> company name, ek query mein.
async fn company_names(org: &str, domains: &[String]) -> HashMap<String, String> {
    let mut m = HashMap::new();
    if domains.is_empty() {
        return m;
    }
    let list = domains.iter().map(|d| enc(d)).collect::<Vec<_>>().join(",");
    for r in rows(crate::sb_select(&format!("companies?select=domain,name&org_id=eq.{}&domain=in.({list})", enc(org))).await) {
        let d = st(&r, "domain").trim().to_lowercase();
        let n = st(&r, "name").trim().to_string();
        if !d.is_empty() && !n.is_empty() {
            m.insert(d, n);
        }
    }
    m
}

fn domains_of(rs: &[Value]) -> Vec<String> {
    let mut d: Vec<String> = rs.iter().map(|r| st(r, "company_domain").trim().to_lowercase()).filter(|x| !x.is_empty()).map(|x| c::safe_addr(&x)).filter(|x| !x.is_empty()).collect();
    d.sort();
    d.dedup();
    d
}

/// contact_id -> tag names.
async fn tags_for(org: &str, ids: &[String]) -> HashMap<String, Vec<String>> {
    let mut m: HashMap<String, Vec<String>> = HashMap::new();
    if ids.is_empty() {
        return m;
    }
    let list = ids.iter().map(|i| enc(i)).collect::<Vec<_>>().join(",");
    for r in rows(crate::sb_select(&format!("contact_tag_map?select=contact_id,tag:contact_tags(name)&org_id=eq.{}&contact_id=in.({list})", enc(org))).await) {
        let name = r.get("tag").and_then(|t| t.get("name")).and_then(|n| n.as_str()).unwrap_or("");
        if name.is_empty() {
            continue;
        }
        m.entry(st(&r, "contact_id")).or_default().push(name.to_string());
    }
    m
}

static LAST_BUILD: OnceLock<Mutex<HashMap<String, Instant>>> = OnceLock::new();

/// Mail se contacts ka sasta rebuild — har org ke liye 60 s mein ek baar (Bun jaisa).
async fn ensure_fresh(org: &str) {
    let m = LAST_BUILD.get_or_init(|| Mutex::new(HashMap::new()));
    {
        let mut g = match m.lock() {
            Ok(g) => g,
            Err(_) => return,
        };
        if let Some(t) = g.get(org) {
            if t.elapsed() < Duration::from_secs(60) {
                return;
            }
        }
        g.insert(org.to_string(), Instant::now());
    }
    if let Err(e) = crate::sb_rpc("anexo_rebuild_contacts", json!({ "p_org": org })).await {
        eprintln!("[contx.rebuild] {e}");
    }
}

async fn delete(path_and_query: &str) -> Result<(), String> {
    let (url, key) = crate::sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let r = crate::http()
        .delete(format!("{url}/rest/v1/{path_and_query}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if r.status().is_success() { Ok(()) } else { Err(r.text().await.unwrap_or_default()) }
}

async fn timeline(org: &str, addresses: &[String]) -> Vec<Value> {
    let or = match c::timeline_or(addresses) {
        Some(o) => o,
        None => return vec![],
    };
    let q = format!(
        "mail_messages?select=id,thread_id,subject,snippet,from_address,to_addresses,direction,sent_at&org_id=eq.{}&or=({})&order=sent_at.desc&limit=200",
        enc(org),
        or.replace('*', "%2A").replace('@', "%40")
    );
    rows(crate::sb_select(&q).await)
        .into_iter()
        .map(|m| {
            let subj = st(&m, "subject");
            json!({
                "id": m.get("id"),
                "kind": if st(&m, "direction") == "out" { "message_out" } else { "message_in" },
                "at": m.get("sent_at"),
                "title": if subj.is_empty() { "(no subject)".to_string() } else { subj },
                "detail": m.get("snippet").filter(|x| x.as_str().map(|s| !s.is_empty()).unwrap_or(false)).cloned().unwrap_or(Value::Null),
                "thread_id": m.get("thread_id").cloned().unwrap_or(Value::Null),
                "actor": m.get("from_address").filter(|x| x.as_str().map(|s| !s.is_empty()).unwrap_or(false)).cloned().unwrap_or(Value::Null),
            })
        })
        .collect()
}

fn company_json(domain: &str, name: Option<&str>, people: &[c::PersonStat]) -> Value {
    let a = c::aggregate_company(people);
    json!({
        "domain": domain, "name": name, "people_count": a.people_count, "messages_total": a.messages_total,
        "open_threads": a.open_threads, "relationship": a.relationship, "health_score": a.health_score, "last_contact_at": a.last_contact_at,
    })
}

/// Kai companies ke log ek hi query mein (Bun har company ke liye alag query chalata tha).
async fn people_by_domain(org: &str, domains: &[String]) -> HashMap<String, Vec<Value>> {
    let mut m: HashMap<String, Vec<Value>> = HashMap::new();
    if domains.is_empty() {
        return m;
    }
    let list = domains.iter().map(|d| enc(d)).collect::<Vec<_>>().join(",");
    if let Ok(rs) = contacts_query(&format!("org_id=eq.{}&company_domain=in.({list})&limit=5000", enc(org))).await {
        for r in rs {
            m.entry(st(&r, "company_domain").trim().to_lowercase()).or_default().push(r);
        }
    }
    m
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let me = match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(m) => m,
        Err((status, code, msg)) => return fail(status, code, &msg),
    };
    let org = me.org_id.clone();
    let oq = enc(&org);
    match proc {
        "contacts.tags" => {
            let tags = rows(crate::sb_select(&format!("contact_tags?select=id,name,colour&org_id=eq.{oq}&order=name.asc")).await);
            let mut counts: HashMap<String, i64> = HashMap::new();
            for l in rows(crate::sb_select(&format!("contact_tag_map?select=tag_id&org_id=eq.{oq}")).await) {
                *counts.entry(st(&l, "tag_id")).or_insert(0) += 1;
            }
            let out: Vec<Value> = tags
                .into_iter()
                .map(|mut t| {
                    let n = counts.get(&st(&t, "id")).copied().unwrap_or(0);
                    t["count"] = json!(n);
                    t
                })
                .collect();
            crate::ok(json!({ "tags": out })).into_response()
        }
        "contacts.list" => {
            ensure_fresh(&org).await;
            let q = c::safe_term(&st(input, "q"));
            let mut filter = st(input, "filter");
            if filter.is_empty() {
                filter = "all".into();
            }
            let tag = st(input, "tag").trim().to_string();
            let mut tail = format!("org_id=eq.{oq}");
            if !q.is_empty() {
                let e = enc(&q);
                tail.push_str(&format!("&or=(display_name.ilike.%2A{e}%2A,primary_address.ilike.%2A{e}%2A,company_domain.ilike.%2A{e}%2A)"));
            }
            if filter == "vip" {
                tail.push_str("&vip=eq.true");
            }
            tail.push_str("&limit=500");
            let mut rs = match contacts_query(&tail).await {
                Ok(r) => r,
                Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e),
            };
            let names = company_names(&org, &domains_of(&rs)).await;
            rs.retain(|r| {
                let ps = person_stat(r);
                c::passes_stat_filter(&filter, &ps.relationship, ps.open_threads)
            });
            let ids: Vec<String> = rs.iter().map(|r| st(r, "id")).collect();
            let tmap = tags_for(&org, &ids).await;
            let want = c::want_tag(&tag, &filter).to_lowercase();
            if !want.is_empty() {
                rs.retain(|r| tmap.get(&st(r, "id")).map(|t| t.iter().any(|n| n.to_lowercase() == want)).unwrap_or(false));
            }
            let mut out: Vec<(Option<String>, Value)> = rs
                .iter()
                .map(|r| {
                    let nm = names.get(&st(r, "company_domain").trim().to_lowercase()).map(|s| s.as_str());
                    let v = shape_contact(r, tmap.get(&st(r, "id")).map(|v| v.as_slice()).unwrap_or(&[]), nm);
                    (v.get("last_contact_at").and_then(|x| x.as_str()).map(|s| s.to_string()), v)
                })
                .collect();
            out.sort_by(|a, b| c::newest_first(&a.0, &b.0));
            crate::ok(json!({ "contacts": out.into_iter().map(|x| x.1).collect::<Vec<_>>() })).into_response()
        }
        "contacts.get" => {
            let id = st(input, "id");
            if id.is_empty() {
                return fail(StatusCode::BAD_REQUEST, "id_required", "id required");
            }
            let rs = match contacts_query(&format!("org_id=eq.{oq}&id=eq.{}&limit=1", enc(&id))).await {
                Ok(r) => r,
                Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e),
            };
            let row = match rs.first() {
                Some(r) => r.clone(),
                None => return fail(StatusCode::CONFLICT, "not_found", "Contact not found"),
            };
            let names = company_names(&org, &domains_of(&[row.clone()])).await;
            let tmap = tags_for(&org, &[id.clone()]).await;
            let nm = names.get(&st(&row, "company_domain").trim().to_lowercase()).map(|s| s.as_str());
            crate::ok(json!({ "contact": shape_contact(&row, tmap.get(&id).map(|v| v.as_slice()).unwrap_or(&[]), nm) })).into_response()
        }
        "contacts.update" => {
            let id = st(input, "id");
            if id.is_empty() {
                return fail(StatusCode::BAD_REQUEST, "id_required", "id required");
            }
            let g = |k: &str| input.get(k).and_then(|x| x.as_str()).map(|s| s.to_string());
            let p = c::build_patch(g("display_name").as_deref(), g("title").as_deref(), g("notes").as_deref(), input.get("vip").and_then(|x| x.as_bool()));
            if p.is_empty() {
                return fail(StatusCode::BAD_REQUEST, "nothing_to_update", "nothing_to_update");
            }
            let mut body = serde_json::Map::new();
            if let Some(v) = p.display_name { body.insert("display_name".into(), json!(v)); }
            if let Some(v) = p.title { body.insert("title".into(), json!(v)); }
            if let Some(v) = p.notes { body.insert("notes".into(), json!(v)); }
            if let Some(v) = p.vip { body.insert("vip".into(), json!(v)); }
            match crate::sb_patch(&format!("contacts?org_id=eq.{oq}&id=eq.{}", enc(&id)), Value::Object(body)).await {
                Ok(_) => crate::ok(json!({ "ok": true })).into_response(),
                Err(e) => fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e),
            }
        }
        "contacts.tag" => {
            let id = st(input, "id");
            if id.is_empty() {
                return fail(StatusCode::BAD_REQUEST, "id_required", "id required");
            }
            let list = |k: &str| -> Vec<String> { input.get(k).and_then(|x| x.as_array()).map(|a| a.iter().filter_map(|x| x.as_str().map(|s| s.to_string())).collect()).unwrap_or_default() };
            for raw in list("add") {
                let name = match c::clean_tag(&raw) { Some(n) => n, None => continue };
                let found = rows(crate::sb_select(&format!("contact_tags?select=id&org_id=eq.{oq}&name=ilike.{}&limit=1", enc(&c::safe_term(&name)))).await);
                let tag_id = match found.first().map(|f| st(f, "id")).filter(|x| !x.is_empty()) {
                    Some(t) => t,
                    None => match crate::sb_insert("contact_tags", json!({ "org_id": org, "name": name, "created_by": me.id })).await {
                        Ok(v) => match arr(&v).first().map(|f| st(f, "id")).filter(|x| !x.is_empty()) { Some(t) => t, None => continue },
                        Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e),
                    },
                };
                let _ = crate::sb_upsert("contact_tag_map", "contact_id,tag_id", json!({ "org_id": org, "contact_id": id, "tag_id": tag_id })).await;
            }
            for raw in list("remove") {
                let name = raw.trim().to_string();
                if name.is_empty() { continue; }
                let found = rows(crate::sb_select(&format!("contact_tags?select=id&org_id=eq.{oq}&name=ilike.{}&limit=1", enc(&c::safe_term(&name)))).await);
                if let Some(t) = found.first().map(|f| st(f, "id")).filter(|x| !x.is_empty()) {
                    let _ = delete(&format!("contact_tag_map?org_id=eq.{oq}&contact_id=eq.{}&tag_id=eq.{}", enc(&id), enc(&t))).await;
                }
            }
            crate::ok(json!({ "ok": true })).into_response()
        }
        "contacts.timeline" => {
            let id = st(input, "id");
            let rs = rows(crate::sb_select(&format!("contacts?select=primary_address,addresses&org_id=eq.{oq}&id=eq.{}&limit=1", enc(&id))).await);
            let row = match rs.first() { Some(r) => r.clone(), None => return fail(StatusCode::CONFLICT, "not_found", "Contact not found") };
            let mut addrs: Vec<String> = row.get("addresses").and_then(|a| a.as_array()).map(|a| a.iter().filter_map(|x| x.as_str().map(|s| s.to_string())).collect()).unwrap_or_default();
            if addrs.is_empty() {
                addrs.push(st(&row, "primary_address"));
            }
            crate::ok(json!({ "events": timeline(&org, &addrs).await })).into_response()
        }
        "companies.list" => {
            ensure_fresh(&org).await;
            let q = c::safe_term(&st(input, "q"));
            let mut tail = format!("companies?select=domain,name&org_id=eq.{oq}");
            if !q.is_empty() {
                let e = enc(&q);
                tail.push_str(&format!("&or=(domain.ilike.%2A{e}%2A,name.ilike.%2A{e}%2A)"));
            }
            tail.push_str("&limit=300");
            let cos = rows(crate::sb_select(&tail).await);
            let doms: Vec<String> = cos.iter().map(|r| c::safe_addr(&st(r, "domain"))).filter(|d| !d.is_empty()).collect();
            let by = people_by_domain(&org, &doms).await;
            let mut out: Vec<(Option<String>, Value)> = cos
                .iter()
                .map(|r| {
                    let d = st(r, "domain");
                    let ps: Vec<c::PersonStat> = by.get(&d.to_lowercase()).map(|v| v.iter().map(person_stat).collect()).unwrap_or_default();
                    let nm = r.get("name").and_then(|x| x.as_str());
                    let v = company_json(&d, nm, &ps);
                    (v.get("last_contact_at").and_then(|x| x.as_str()).map(|s| s.to_string()), v)
                })
                .collect();
            out.sort_by(|a, b| c::newest_first(&a.0, &b.0));
            crate::ok(json!({ "companies": out.into_iter().map(|x| x.1).collect::<Vec<_>>() })).into_response()
        }
        "companies.get" => {
            let domain = c::safe_addr(&st(input, "domain"));
            let cos = rows(crate::sb_select(&format!("companies?select=domain,name&org_id=eq.{oq}&domain=eq.{}&limit=1", enc(&domain))).await);
            let co = match cos.first() { Some(r) => r.clone(), None => return fail(StatusCode::CONFLICT, "not_found", "Company not found") };
            let by = people_by_domain(&org, &[domain.clone()]).await;
            let prs = by.get(&domain).cloned().unwrap_or_default();
            let ids: Vec<String> = prs.iter().map(|r| st(r, "id")).collect();
            let tmap = tags_for(&org, &ids).await;
            let nm = co.get("name").and_then(|x| x.as_str());
            let stats: Vec<c::PersonStat> = prs.iter().map(person_stat).collect();
            let people: Vec<Value> = prs.iter().map(|r| shape_contact(r, tmap.get(&st(r, "id")).map(|v| v.as_slice()).unwrap_or(&[]), nm)).collect();
            crate::ok(json!({ "company": company_json(&st(&co, "domain"), nm, &stats), "people": people })).into_response()
        }
        "companies.timeline" => {
            let domain = c::safe_addr(&st(input, "domain"));
            crate::ok(json!({ "events": timeline(&org, &[format!("@{domain}")]).await })).into_response()
        }
        "search.universal" => {
            let q = c::safe_term(&st(input, "q"));
            if q.chars().count() < 2 {
                return crate::ok(json!({ "people": [], "companies": [], "threads": [], "attachments": [] })).into_response();
            }
            let e = enc(&q);
            let people_tail = format!("org_id=eq.{oq}&or=(display_name.ilike.%2A{e}%2A,primary_address.ilike.%2A{e}%2A)&limit=8");
            let q_comp = format!("companies?select=domain,name&org_id=eq.{oq}&or=(domain.ilike.%2A{e}%2A,name.ilike.%2A{e}%2A)&limit=6");
            let q_thr = format!("mail_threads?select=id,subject,snippet,from_address,folder,last_message_at&org_id=eq.{oq}&or=(subject.ilike.%2A{e}%2A,snippet.ilike.%2A{e}%2A,from_address.ilike.%2A{e}%2A)&order=last_message_at.desc&limit=10");
            let q_att = format!("mail_attachments?select=id,filename,size_bytes,thread_id,sent_at&org_id=eq.{oq}&filename=ilike.%2A{e}%2A&order=sent_at.desc&limit=8");
            let (people_r, comp_r, thread_r, attach_r) = tokio::join!(
                contacts_query(&people_tail),
                crate::sb_select(&q_comp),
                crate::sb_select(&q_thr),
                crate::sb_select(&q_att),
            );
            let prs = people_r.unwrap_or_default();
            let names = company_names(&org, &domains_of(&prs)).await;
            let ids: Vec<String> = prs.iter().map(|r| st(r, "id")).collect();
            let tmap = tags_for(&org, &ids).await;
            let people: Vec<Value> = prs.iter().map(|r| {
                let nm = names.get(&st(r, "company_domain").trim().to_lowercase()).map(|s| s.as_str());
                shape_contact(r, tmap.get(&st(r, "id")).map(|v| v.as_slice()).unwrap_or(&[]), nm)
            }).collect();
            let cos = comp_r.map(|v| arr(&v)).unwrap_or_default();
            let doms: Vec<String> = cos.iter().map(|r| c::safe_addr(&st(r, "domain"))).filter(|d| !d.is_empty()).collect();
            let by = people_by_domain(&org, &doms).await;
            let companies: Vec<Value> = cos.iter().map(|r| {
                let d = st(r, "domain");
                let ps: Vec<c::PersonStat> = by.get(&d.to_lowercase()).map(|v| v.iter().map(person_stat).collect()).unwrap_or_default();
                company_json(&d, r.get("name").and_then(|x| x.as_str()), &ps)
            }).collect();
            let threads: Vec<Value> = thread_r.map(|v| arr(&v)).unwrap_or_default().into_iter().map(|t| {
                let subj = st(&t, "subject");
                let folder = st(&t, "folder");
                json!({ "id": t.get("id"), "subject": if subj.is_empty() { "(no subject)".to_string() } else { subj },
                        "snippet": t.get("snippet").cloned().unwrap_or(Value::Null), "from_address": st(&t, "from_address"),
                        "folder": if folder.is_empty() { "inbox".to_string() } else { folder }, "last_message_at": t.get("last_message_at") })
            }).collect();
            let attachments: Vec<Value> = attach_r.map(|v| arr(&v)).unwrap_or_default().into_iter().map(|a| {
                json!({ "id": a.get("id"), "filename": a.get("filename"), "size_bytes": num(&a, "size_bytes"),
                        "thread_id": a.get("thread_id").cloned().unwrap_or(Value::Null), "folder": "inbox", "sent_at": a.get("sent_at") })
            }).collect();
            crate::ok(json!({ "people": people, "companies": companies, "threads": threads, "attachments": attachments })).into_response()
        }
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", "unknown proc"),
    }
}
