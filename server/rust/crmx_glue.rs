// ============================================================================
// crmx_glue — CRM P1 + P2 (Rust PRIMARY, Tokio async; Rule 52: wahi dispatch HTTP /rpc/<proc> AUR WebTransport /wt/rpc par).
//   crm.pipelines.list|save|delete   — alag pipelines + stages (Pro 1, Business 5, Biz Pro+ unlimited)
//   crm.fields.list|save|delete      — custom fields lead/deal (Pro 5, Business 25, Biz Pro+ unlimited)
//   crm.custom.set                   — ek lead/deal par custom values (server validate)
//   crm.dups.list / crm.merge        — duplicate dhoondna + atomic merge (SQL crm_merge)
//   crm.forms.list|save|delete       — web form builder (Pro 1, Business 10, Biz Pro+ unlimited)
//   crm.form.get / crm.form.submit   — PUBLIC (bina login): form dikhana + lead banana (honeypot, speed check, SQL rate limit)
// Gate Pro+ (Basic 403 feature_not_available); package cap SQL function mein p_cap se, advisory lock ke andar (race-free). SQL E92 PEHLE.
// ============================================================================

use crate::crmx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Map, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::pro_only(proc)
}

pub fn public_owns(proc: &str) -> bool {
    matches!(proc, "crm.form.get" | "crm.form.submit")
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

fn uuid_ok(s: &str) -> bool {
    s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_hexdigit() })
}

fn opt_uuid(s: &str) -> Value {
    if uuid_ok(s) { json!(s.to_lowercase()) } else { Value::Null }
}

/// SQL function ke {ok:false, reason} ko HTTP jawab mein badalta hai.
fn reason_resp(v: &Value) -> Resp {
    let r = v.get("reason").and_then(|x| x.as_str()).unwrap_or("failed");
    let (status, msg) = match r {
        "limit_reached" => (StatusCode::FORBIDDEN, "Your plan's limit for this is full. Upgrade for more."),
        "not_found" | "keep_not_found" => (StatusCode::NOT_FOUND, "Not found."),
        "name_taken" | "key_taken" | "duplicate_stage" => (StatusCode::CONFLICT, "That name is already used."),
        "stage_in_use" => (StatusCode::CONFLICT, "Some deals sit in a stage you removed. Move them first."),
        "has_deals" => (StatusCode::CONFLICT, "This pipeline still has deals. Move them first."),
        "default_pipeline" => (StatusCode::CONFLICT, "The default pipeline cannot be deleted."),
        "not_same_workspace" => (StatusCode::BAD_REQUEST, "These records are not in the same workspace."),
        "rate_limited" => (StatusCode::TOO_MANY_REQUESTS, "Too many submissions. Please try again in a few minutes."),
        "bad_email" => (StatusCode::BAD_REQUEST, "Please enter a valid email address."),
        "missing_field" => (StatusCode::BAD_REQUEST, "A required field is missing."),
        _ => (StatusCode::BAD_REQUEST, "The request could not be completed."),
    };
    crate::err(status, r, msg).into_response()
}

async fn rpc(func: &str, body: Value) -> Result<Value, Resp> {
    match crate::sb_rpc(func, body).await {
        Ok(v) if v.get("ok").and_then(|x| x.as_bool()).unwrap_or(false) => Ok(v),
        Ok(v) => Err(reason_resp(&v)),
        Err(e) if e.contains("PGRST202") || e.contains("Could not find the function") => Err(fail(StatusCode::NOT_IMPLEMENTED, "crm_sql_missing", "CRM SQL (E92) is not installed yet.")),
        Err(e) => {
            eprintln!("crmx rpc {func} failed: {}", e.chars().take(300).collect::<String>()); // asli DB wajah server log mein (client ko nahi)
            Err(fail(StatusCode::BAD_GATEWAY, "db_unavailable", "The CRM database is not reachable right now."))
        }
    }
}

/* ------------------------------------------------------------------ public (bina login) */

pub async fn public(proc: &str, input: &Value) -> Resp {
    let slug = st(input, "slug").trim().to_lowercase();
    if !c::slug_ok(&slug) {
        return fail(StatusCode::NOT_FOUND, "not_found", "This form is not available.");
    }
    if proc == "crm.form.get" {
        return match rpc("crm_form_public", json!({ "p_slug": slug })).await {
            Ok(v) => crate::ok(json!({ "name": v["name"], "fields": v["fields"], "success_message": v["success_message"] })).into_response(),
            Err(r) => r,
        };
    }
    // crm.form.submit
    let Some(obj) = input.get("data").and_then(|d| d.as_object()) else {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "Missing form data.");
    };
    if obj.len() > 12 {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "Too many fields.");
    }
    let mut clean = Map::new();
    let mut blob = String::new();
    for (k, v) in obj {
        if !c::key_ok(k) {
            continue;
        }
        let s = match v {
            Value::String(s) => s.trim().to_string(),
            Value::Number(n) => n.to_string(),
            Value::Bool(b) => b.to_string(),
            _ => continue,
        };
        if s.chars().count() > 500 {
            return fail(StatusCode::BAD_REQUEST, "bad_request", "A value is too long.");
        }
        blob.push_str(&s);
        blob.push(' ');
        clean.insert(k.clone(), json!(s));
    }
    let ms = input.get("ms").and_then(|x| x.as_i64()).unwrap_or(-1);
    let spam = c::spam_score(&st(input, "hp"), ms, &blob);
    match rpc("crm_form_submit", json!({ "p_slug": slug, "p_data": Value::Object(clean), "p_spam": spam })).await {
        Ok(_) => crate::ok(json!({ "received": true })).into_response(), // duplicate / spam bot ko batate nahi
        Err(r) => r,
    }
}

/* ------------------------------------------------------------------ authenticated */

async fn owners(me: &crate::MailMe, plan: &str) -> Vec<String> {
    if plan.trim().eq_ignore_ascii_case("pro") || me.org_id.is_empty() {
        return vec![me.email.to_lowercase()];
    }
    let mut o: Vec<String> = match crate::sb_select(&format!("org_members?select=email&org_id=eq.{}&limit=2000", enc(&me.org_id))).await {
        Ok(v) => v.as_array().cloned().unwrap_or_default().iter().map(|m| st(m, "email").trim().to_lowercase()).filter(|e| !e.is_empty()).collect(),
        Err(_) => vec![],
    };
    o.push(me.email.to_lowercase());
    o.sort();
    o.dedup();
    o
}

fn owner_list(o: &[String]) -> String {
    o.iter().map(|e| format!("%22{}%22", enc(&e.replace('"', "")))).collect::<Vec<_>>().join(",")
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
    // Pro+ gate — SERVER par. Plan na mile => basic (kabhi zyada nahi kholta).
    let Some(lim) = c::limits(&plan) else {
        return fail(StatusCode::FORBIDDEN, "feature_not_available", "CRM setup (pipelines, custom fields, forms, merge) is on Pro and above.");
    };
    let scope = if me.org_id.is_empty() { format!("u:{}", me.email.to_lowercase()) } else { me.org_id.to_lowercase() };
    match proc {
        "crm.pipelines.list" => pipelines_list(&me, &scope, &lim).await,
        "crm.pipelines.save" => pipelines_save(&me, &scope, &lim, input).await,
        "crm.pipelines.delete" => simple_delete("crm_pipeline_delete", &scope, input).await,
        "crm.fields.list" => fields_list(&scope, &lim).await,
        "crm.fields.save" => fields_save(&scope, &lim, input).await,
        "crm.fields.delete" => simple_delete("crm_field_delete", &scope, input).await,
        "crm.custom.set" => custom_set(&me, &plan, &scope, input).await,
        "crm.dups.list" => dups_list(&me, &plan, input).await,
        "crm.merge" => merge(&me, &plan, &scope, input).await,
        "crm.forms.list" => forms_list(&scope, &lim).await,
        "crm.forms.save" => forms_save(&me, &scope, &lim, input).await,
        "crm.forms.delete" => simple_delete("crm_form_delete", &scope, input).await,
        "crm.board" => board(&me, &plan, &scope, input).await,
        "crm.deals.move" => deal_move(&me, &plan, &scope, input).await,
        "crm.deals.setPipeline" => deal_set_pipeline(&me, &plan, &scope, input).await,
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    }
}

fn lim_json(l: &c::Limits) -> Value {
    json!({ "pipelines": l.pipelines, "fields": l.fields, "forms": l.forms }) // -1 = unlimited
}

async fn simple_delete(func: &str, scope: &str, input: &Value) -> Resp {
    let id = st(input, "id");
    if !uuid_ok(&id) {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "Missing id.");
    }
    match rpc(func, json!({ "p_scope": scope, "p_id": id })).await {
        Ok(_) => crate::ok(json!({ "deleted": true })).into_response(),
        Err(r) => r,
    }
}

/* ---- pipelines */

async fn load_pipelines(me: &crate::MailMe, scope: &str) -> Result<Vec<Value>, Resp> {
    rpc_id("crm_ensure_default_pipeline", json!({ "p_scope": scope, "p_actor": me.email })).await?;
    match crate::sb_select(&format!("crm_pipelines?select=id,name,is_default,position,crm_pipeline_stages(key,label,position,probability,kind)&scope=eq.{}&order=position.asc", enc(scope))).await {
        Ok(v) => Ok(v
            .as_array()
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .map(|mut p| {
                let mut stages = p.get("crm_pipeline_stages").and_then(|x| x.as_array()).cloned().unwrap_or_default();
                stages.sort_by_key(|s| s.get("position").and_then(|x| x.as_i64()).unwrap_or(0));
                if let Some(o) = p.as_object_mut() {
                    o.remove("crm_pipeline_stages");
                    o.insert("stages".into(), Value::Array(stages));
                }
                p
            })
            .collect()),
        Err(_) => Err(fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Pipelines could not be read.")),
    }
}

async fn pipelines_list(me: &crate::MailMe, scope: &str, lim: &c::Limits) -> Resp {
    match load_pipelines(me, scope).await {
        Ok(list) => crate::ok(json!({ "pipelines": list, "limits": lim_json(lim) })).into_response(),
        Err(r) => r,
    }
}

/// crm_ensure_default_pipeline uuid lautata hai (jsonb nahi) — alag chhota wrapper.
async fn rpc_id(func: &str, body: Value) -> Result<Value, Resp> {
    match crate::sb_rpc(func, body).await {
        Ok(v) => Ok(v),
        Err(e) if e.contains("PGRST202") || e.contains("Could not find the function") => Err(fail(StatusCode::NOT_IMPLEMENTED, "crm_sql_missing", "CRM SQL (E92) is not installed yet.")),
        Err(_) => Err(fail(StatusCode::BAD_GATEWAY, "db_unavailable", "The CRM database is not reachable right now.")),
    }
}

async fn pipelines_save(me: &crate::MailMe, scope: &str, lim: &c::Limits, input: &Value) -> Resp {
    let name = st(input, "name").trim().to_string();
    if name.is_empty() || name.chars().count() > 60 {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "Pipeline name must be 1 to 60 characters.");
    }
    let mut stages: Vec<c::StageIn> = vec![];
    for s in input.get("stages").and_then(|x| x.as_array()).cloned().unwrap_or_default() {
        let label = st(&s, "label").trim().to_string();
        let key = { let k = st(&s, "key"); if k.is_empty() { c::slugify(&label).unwrap_or_default() } else { k } };
        stages.push(c::StageIn {
            key,
            label,
            probability: s.get("probability").and_then(|x| x.as_i64()).unwrap_or(0),
            kind: { let k = st(&s, "kind"); if k.is_empty() { "open".into() } else { k } },
        });
    }
    if let Err(code) = c::check_stages(&stages) {
        return fail(StatusCode::BAD_REQUEST, code, "Check the stages: 2 to 12, unique, won = 100%, lost = 0%, at least one open and one closed.");
    }
    let id = st(input, "id");
    let body = json!({
        "p_scope": scope, "p_id": opt_uuid(&id), "p_name": name, "p_actor": me.email,
        "p_cap": lim.pipelines,
        "p_stages": stages.iter().map(|s| json!({ "key": s.key, "label": s.label.trim(), "probability": s.probability, "kind": s.kind })).collect::<Vec<_>>(),
    });
    match rpc("crm_pipeline_save", body).await {
        Ok(v) => crate::ok(json!({ "id": v["id"] })).into_response(),
        Err(r) => r,
    }
}

/* ---- fields */

async fn fields_list(scope: &str, lim: &c::Limits) -> Resp {
    match crate::sb_select(&format!("crm_field_defs?select=id,entity,key,label,kind,options,position&scope=eq.{}&order=position.asc", enc(scope))).await {
        Ok(v) => crate::ok(json!({ "fields": v, "limits": lim_json(lim) })).into_response(),
        Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Fields could not be read."),
    }
}

async fn fields_save(scope: &str, lim: &c::Limits, input: &Value) -> Resp {
    let (entity, label, kind) = (st(input, "entity"), st(input, "label").trim().to_string(), st(input, "kind"));
    if !matches!(entity.as_str(), "lead" | "deal") || label.is_empty() || label.chars().count() > 40 || !c::field_kind_ok(&kind) {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "Field needs an entity (lead or deal), a label up to 40 characters and a valid type.");
    }
    let raw: Vec<String> = input.get("options").and_then(|x| x.as_array()).map(|a| a.iter().filter_map(|o| o.as_str().map(|s| s.to_string())).collect()).unwrap_or_default();
    let options = match c::clean_options(&kind, &raw) {
        Ok(o) => o,
        Err(code) => return fail(StatusCode::BAD_REQUEST, code, "A select field needs 1 to 30 options."),
    };
    let id = st(input, "id");
    let key = if uuid_ok(&id) { String::new() } else {
        match c::slugify(&label) {
            Some(k) => k,
            None => return fail(StatusCode::BAD_REQUEST, "bad_request", "The label must start with a letter."),
        }
    };
    let body = json!({
        "p_scope": scope, "p_id": opt_uuid(&id), "p_entity": entity, "p_label": label, "p_kind": kind,
        "p_key": key, "p_options": options, "p_cap": lim.fields,
    });
    match rpc("crm_field_save", body).await {
        Ok(v) => crate::ok(json!({ "id": v["id"] })).into_response(),
        Err(r) => r,
    }
}

/// {entity:"lead"|"deal", id, values:{key: "value" | "" | null}} — khali / null = hatao.
async fn custom_set(me: &crate::MailMe, plan: &str, scope: &str, input: &Value) -> Resp {
    let (entity, id) = (st(input, "entity"), st(input, "id"));
    let Some(values) = input.get("values").and_then(|v| v.as_object()) else {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "Missing values.");
    };
    if !matches!(entity.as_str(), "lead" | "deal") || !uuid_ok(&id) || values.len() > 30 {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "Missing or invalid entity / id.");
    }
    let defs = match crate::sb_select(&format!("crm_field_defs?select=key,kind,options&scope=eq.{}&entity=eq.{}", enc(scope), enc(&entity))).await {
        Ok(v) => v.as_array().cloned().unwrap_or_default(),
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Fields could not be read."),
    };
    let table = if entity == "lead" { "crm_leads" } else { "crm_deals" };
    let o = owners(me, plan).await;
    let row = match crate::sb_select(&format!("{table}?select=id,custom&id=eq.{}&owner=in.({})&limit=1", enc(&id), owner_list(&o))).await {
        Ok(v) => v.as_array().and_then(|a| a.first().cloned()),
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "db_unavailable", "The record could not be read."),
    };
    let Some(row) = row else { return fail(StatusCode::NOT_FOUND, "not_found", "Record not found.") };
    let mut custom = row.get("custom").and_then(|x| x.as_object()).cloned().unwrap_or_default();
    for (k, v) in values {
        let Some(def) = defs.iter().find(|d| st(d, "key") == *k) else {
            return fail(StatusCode::BAD_REQUEST, "unknown_field", "That custom field does not exist.");
        };
        let raw = match v {
            Value::Null => String::new(),
            Value::String(s) => s.clone(),
            Value::Bool(b) => b.to_string(),
            Value::Number(n) => n.to_string(),
            _ => return fail(StatusCode::BAD_REQUEST, "bad_value", "Invalid value."),
        };
        if raw.trim().is_empty() {
            custom.remove(k);
            continue;
        }
        let opts: Vec<String> = def.get("options").and_then(|x| x.as_array()).map(|a| a.iter().filter_map(|o| o.as_str().map(|s| s.to_string())).collect()).unwrap_or_default();
        match c::check_value(&st(def, "kind"), &opts, &raw) {
            Ok(n) => {
                custom.insert(k.clone(), json!(n));
            }
            Err(code) => return fail(StatusCode::BAD_REQUEST, code, &format!("Invalid value for {k}.")),
        }
    }
    match crate::sb_patch(&format!("{table}?id=eq.{}&owner=in.({})", enc(&id), owner_list(&o)), json!({ "custom": Value::Object(custom.clone()) })).await {
        Ok(_) => crate::ok(json!({ "custom": Value::Object(custom) })).into_response(),
        Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "The record could not be saved."),
    }
}

/* ---- duplicates + merge */

async fn dups_list(me: &crate::MailMe, plan: &str, input: &Value) -> Resp {
    let kind = st(input, "kind");
    let o = owners(me, plan).await;
    let (q, is_lead) = match kind.as_str() {
        "lead" => (format!("crm_leads?select=id,email,display_name,company,source,created_at&owner=in.({})&order=created_at.asc&limit=5000", owner_list(&o)), true),
        "deal" => (format!("crm_deals?select=id,title,company,stage,value,currency,created_at&owner=in.({})&order=created_at.asc&limit=5000", owner_list(&o)), false),
        _ => return fail(StatusCode::BAD_REQUEST, "bad_request", "kind must be lead or deal."),
    };
    let rows = match crate::sb_select(&q).await {
        Ok(v) => v.as_array().cloned().unwrap_or_default(),
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Records could not be read."),
    };
    let keyed: Vec<(String, String)> = rows
        .iter()
        .map(|r| (st(r, "id"), if is_lead { c::lead_key(&st(r, "email")) } else { c::deal_key(&st(r, "title"), &st(r, "company")) }))
        .collect();
    let groups = c::group_dups(&keyed);
    let out: Vec<Value> = groups
        .iter()
        .take(200)
        .map(|g| json!({ "records": g.iter().filter_map(|id| rows.iter().find(|r| st(r, "id") == *id).cloned()).collect::<Vec<_>>() }))
        .collect();
    crate::ok(json!({ "kind": kind, "groups": out, "total_groups": groups.len() })).into_response()
}

async fn merge(me: &crate::MailMe, plan: &str, scope: &str, input: &Value) -> Resp {
    let kind = st(input, "kind");
    let keep = st(input, "keep");
    let drop: Vec<String> = input.get("drop").and_then(|x| x.as_array()).map(|a| a.iter().filter_map(|v| v.as_str().map(|s| s.to_lowercase())).collect()).unwrap_or_default();
    if !matches!(kind.as_str(), "lead" | "deal") || !uuid_ok(&keep) || drop.is_empty() || drop.len() > 20 || !drop.iter().all(|d| uuid_ok(d)) || drop.iter().any(|d| *d == keep.to_lowercase()) {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "Pick one record to keep and up to 20 to merge into it.");
    }
    // Sirf apne dikhne wale (owner scope) records — doosre ka record merge nahi.
    let table = if kind == "lead" { "crm_leads" } else { "crm_deals" };
    let o = owners(me, plan).await;
    let ids = std::iter::once(keep.to_lowercase()).chain(drop.iter().cloned()).collect::<Vec<_>>();
    let seen = match crate::sb_select(&format!("{table}?select=id&id=in.({})&owner=in.({})", ids.join(","), owner_list(&o))).await {
        Ok(v) => v.as_array().map(|a| a.len()).unwrap_or(0),
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Records could not be read."),
    };
    if seen != ids.len() {
        return fail(StatusCode::NOT_FOUND, "not_found", "One of these records is not yours to merge.");
    }
    match rpc("crm_merge", json!({ "p_kind": kind, "p_keep": keep, "p_drop": drop, "p_actor": me.email, "p_scope": scope })).await {
        Ok(v) => crate::ok(json!({ "merged": v["merged"], "kept_id": v["kept_id"] })).into_response(),
        Err(r) => r,
    }
}

/* ---- forms */

async fn forms_list(scope: &str, lim: &c::Limits) -> Resp {
    match crate::sb_select(&format!("crm_forms?select=id,slug,name,owner,fields,success_message,active,submissions,created_at&scope=eq.{}&order=created_at.asc", enc(scope))).await {
        Ok(v) => {
            let list: Vec<Value> = v
                .as_array()
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .map(|mut f| {
                    let url = format!("/f/{}", st(&f, "slug"));
                    if let Some(o) = f.as_object_mut() {
                        o.insert("path".into(), json!(url));
                    }
                    f
                })
                .collect();
            crate::ok(json!({ "forms": list, "limits": lim_json(lim) })).into_response()
        }
        Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "Forms could not be read."),
    }
}

async fn forms_save(me: &crate::MailMe, scope: &str, lim: &c::Limits, input: &Value) -> Resp {
    let name = st(input, "name").trim().to_string();
    if name.is_empty() || name.chars().count() > 60 {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "Form name must be 1 to 60 characters.");
    }
    let mut triples: Vec<(String, String, bool)> = vec![];
    let mut fields: Vec<Value> = vec![];
    for f in input.get("fields").and_then(|x| x.as_array()).cloned().unwrap_or_default() {
        let label = st(&f, "label").trim().to_string();
        let key = { let k = st(&f, "key"); if k.is_empty() { c::slugify(&label).unwrap_or_default() } else { k } };
        let kind = { let k = st(&f, "kind"); if k.is_empty() { "text".into() } else { k } };
        let required = f.get("required").and_then(|x| x.as_bool()).unwrap_or(false) || key == "email";
        if label.is_empty() || label.chars().count() > 60 {
            return fail(StatusCode::BAD_REQUEST, "bad_field", "Every field needs a label up to 60 characters.");
        }
        let mut obj = json!({ "key": key, "label": label, "kind": kind, "required": required });
        if kind == "select" {
            let raw: Vec<String> = f.get("options").and_then(|x| x.as_array()).map(|a| a.iter().filter_map(|o| o.as_str().map(|s| s.to_string())).collect()).unwrap_or_default();
            match c::clean_options("select", &raw) {
                Ok(o) => obj["options"] = json!(o),
                Err(code) => return fail(StatusCode::BAD_REQUEST, code, "A select field needs 1 to 30 options."),
            }
        }
        triples.push((key, kind, required));
        fields.push(obj);
    }
    if let Err(code) = c::check_form_fields(&triples) {
        return fail(StatusCode::BAD_REQUEST, code, "A form needs up to 12 fields and a required email field.");
    }
    let id = st(input, "id");
    let body = json!({
        "p_scope": scope, "p_org": opt_uuid(&me.org_id), "p_id": opt_uuid(&id), "p_name": name, "p_owner": me.email,
        "p_fields": fields, "p_success": st(input, "success_message").chars().take(300).collect::<String>(),
        "p_active": input.get("active").and_then(|x| x.as_bool()), "p_cap": lim.forms,
    });
    match rpc("crm_form_save", body).await {
        Ok(v) => crate::ok(json!({ "id": v["id"], "slug": v["slug"], "path": format!("/f/{}", st(&v, "slug")) })).into_response(),
        Err(r) => r,
    }
}

/* ---- board: deals + unki pipeline ke stages (purane Bun stage-move sirf 6 fixed stages leta tha) */

fn now_secs() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

fn pick_pipeline<'a>(list: &'a [Value], wanted: &str) -> Option<&'a Value> {
    list.iter().find(|p| !wanted.is_empty() && st(p, "id") == wanted.to_lowercase()).or_else(|| list.iter().find(|p| p.get("is_default").and_then(|x| x.as_bool()).unwrap_or(false)))
}

fn stage_of<'a>(pipe: &'a Value, key: &str) -> Option<&'a Value> {
    pipe.get("stages").and_then(|x| x.as_array()).and_then(|a| a.iter().find(|s| st(s, "key") == key))
}

async fn board(me: &crate::MailMe, plan: &str, scope: &str, input: &Value) -> Resp {
    let pipes = match load_pipelines(me, scope).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let Some(sel) = pick_pipeline(&pipes, &st(input, "pipeline_id")).cloned() else {
        return fail(StatusCode::NOT_FOUND, "not_found", "No pipeline.");
    };
    let sel_id = st(&sel, "id");
    let sel_default = sel.get("is_default").and_then(|x| x.as_bool()).unwrap_or(false);
    let o = owners(me, plan).await;
    let (dq, fq) = (
        format!("crm_deals?select=*&owner=in.({})&order=updated_at.desc&limit=300", owner_list(&o)),
        format!("crm_field_defs?select=id,entity,key,label,kind,options&scope=eq.{}&entity=eq.deal&order=position.asc", enc(scope)),
    );
    let (deals_r, defs_r) = tokio::join!(crate::sb_select(&dq), crate::sb_select(&fq));
    let rows = deals_r.ok().and_then(|v| v.as_array().cloned()).unwrap_or_default();
    let now = now_secs();
    let deals: Vec<Value> = rows
        .iter()
        .filter(|d| c::deal_in_pipeline(d.get("pipeline_id").and_then(|x| x.as_str()), &sel_id, sel_default))
        .map(|d| {
            let stage = st(d, "stage");
            let sdef = stage_of(&sel, &stage);
            let open = sdef.map(|s| st(s, "kind") == "open").unwrap_or(!matches!(stage.as_str(), "won" | "lost"));
            let prob = d.get("probability").filter(|x| !x.is_null()).cloned().or_else(|| sdef.and_then(|s| s.get("probability").cloned())).unwrap_or(Value::Null);
            json!({
                "id": d.get("id"), "title": d.get("title"), "company": d.get("company"), "contact_email": d.get("contact_email"),
                "stage": stage, "value": d.get("value").and_then(|x| x.as_f64()).unwrap_or(0.0), "currency": d.get("currency").and_then(|x| x.as_str()).unwrap_or("GBP"),
                "probability": prob, "owner": d.get("owner"), "next_step": d.get("next_step"), "next_step_due": d.get("next_step_due"), "thread_id": d.get("thread_id"),
                "stale_days": c::stale_days(open, d.get("updated_at").and_then(|x| x.as_str()).and_then(crate::cal_core::parse_ts), now),
                "updated_at": d.get("updated_at"), "custom": d.get("custom").cloned().unwrap_or_else(|| json!({})), "pipeline_id": sel_id,
            })
        })
        .collect();
    crate::ok(json!({
        "pipeline": sel,
        "pipelines": pipes.iter().map(|p| json!({ "id": p["id"], "name": p["name"], "is_default": p["is_default"] })).collect::<Vec<_>>(),
        "deals": deals,
        "fields": defs_r.ok().unwrap_or_else(|| json!([])),
    }))
    .into_response()
}

async fn visible_deal(o: &[String], id: &str) -> Result<Value, Resp> {
    if !uuid_ok(id) {
        return Err(fail(StatusCode::BAD_REQUEST, "bad_request", "Missing deal id."));
    }
    match crate::sb_select(&format!("crm_deals?select=id,stage,pipeline_id,title&id=eq.{}&owner=in.({})&limit=1", enc(id), owner_list(o))).await {
        Ok(v) => v.as_array().and_then(|a| a.first().cloned()).ok_or_else(|| fail(StatusCode::NOT_FOUND, "not_found", "Deal not found.")),
        Err(_) => Err(fail(StatusCode::BAD_GATEWAY, "db_unavailable", "The deal could not be read.")),
    }
}

async fn audit(me: &crate::MailMe, action: &str, target: &str) {
    let _ = crate::sb_insert("crm_audit", json!({ "actor": me.email, "action": action, "target": target })).await;
}

async fn deal_move(me: &crate::MailMe, plan: &str, scope: &str, input: &Value) -> Resp {
    let (id, stage) = (st(input, "id"), st(input, "stage"));
    let o = owners(me, plan).await;
    let deal = match visible_deal(&o, &id).await {
        Ok(d) => d,
        Err(r) => return r,
    };
    let pipes = match load_pipelines(me, scope).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let Some(pipe) = pick_pipeline(&pipes, &st(&deal, "pipeline_id")) else {
        return fail(StatusCode::NOT_FOUND, "not_found", "Pipeline not found.");
    };
    let Some(sdef) = stage_of(pipe, &stage) else {
        return fail(StatusCode::BAD_REQUEST, "bad_stage", "That stage is not in this deal's pipeline.");
    };
    let prob = sdef.get("probability").and_then(|x| x.as_i64()).unwrap_or(0);
    let body = json!({ "stage": stage, "probability": prob, "updated_at": crate::cal_core::fmt_rfc3339(now_secs()) });
    match crate::sb_patch(&format!("crm_deals?id=eq.{}&owner=in.({})", enc(&id), owner_list(&o)), body).await {
        Ok(_) => {
            audit(me, "deal.stage", &format!("{id}:{}->{stage}", st(&deal, "stage"))).await;
            crate::ok(json!({ "deal": { "id": id, "stage": stage, "probability": prob } })).into_response()
        }
        Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "The deal could not be moved."),
    }
}

async fn deal_set_pipeline(me: &crate::MailMe, plan: &str, scope: &str, input: &Value) -> Resp {
    let (id, target) = (st(input, "id"), st(input, "pipeline_id"));
    let o = owners(me, plan).await;
    let deal = match visible_deal(&o, &id).await {
        Ok(d) => d,
        Err(r) => return r,
    };
    let pipes = match load_pipelines(me, scope).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let Some(pipe) = pipes.iter().find(|p| !target.is_empty() && st(p, "id") == target.to_lowercase()) else {
        return fail(StatusCode::NOT_FOUND, "not_found", "Pipeline not found.");
    };
    let first = pipe.get("stages").and_then(|x| x.as_array()).and_then(|a| a.iter().find(|s| st(s, "kind") == "open")).cloned();
    let Some(first) = first else {
        return fail(StatusCode::BAD_REQUEST, "bad_stage", "That pipeline has no open stage.");
    };
    let body = json!({ "pipeline_id": pipe["id"], "stage": first["key"], "probability": first["probability"], "updated_at": crate::cal_core::fmt_rfc3339(now_secs()) });
    match crate::sb_patch(&format!("crm_deals?id=eq.{}&owner=in.({})", enc(&id), owner_list(&o)), body).await {
        Ok(_) => {
            audit(me, "deal.pipeline", &format!("{id}->{}", st(pipe, "id"))).await;
            crate::ok(json!({ "deal": { "id": id, "pipeline_id": pipe["id"], "stage": first["key"] } })).into_response()
        }
        Err(_) => fail(StatusCode::BAD_GATEWAY, "db_unavailable", "The deal could not be moved."),
    }
}
