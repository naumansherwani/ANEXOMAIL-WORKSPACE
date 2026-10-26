// ============================================================================
// setx_glue — Batch D: Settings (Time Machine) + Integrations + founder overviews, Rust PRIMARY (Tokio async; /rpc + /wt/rpc; Rule 52/56/57/59).
//   settings.list{scope} | explain{key} | save{key,value,reason?} | history{key?} | revert{version_id}        (Bun /api/settings/*)
//   integrations.providers | connections | connect | disconnect | migrations | startMigration | controlMigration | delivery | exports | export   (Bun /api/integrations/*)
//   founderSettings.overview | founderIntegrations.overview | founderSecurity.overview                         FOUNDER ONLY (Bun mein har login wala dekh sakta tha — LOOPHOLE band)
// Sab plans (login). Business settings (blast/simulate/drift/schedule) aur Leo actions Bun par rehte hain (404 procedure_not_in_rust => client fallback).
// LOOPHOLES band: (1) founder overviews sirf founder_accounts; (2) migration target_mailbox agar kisi aur org ka mailbox hai to 403;
//   (3) host/port/account/domain/scope/format/key/uuid sab validate (PostgREST filter mein kuch bhi nahi jata); (4) oauth connect 501 ki jagah 422 oauth_client_pending (Rule 59).
// ============================================================================

use crate::setx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Map, Value};
use std::collections::HashMap;

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::owns_name(proc)
}

fn fail(s: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(s, code, msg).into_response()
}

fn db_fail(e: &str) -> Resp {
    eprintln!("[setx] db_error: {e}");
    fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", e)
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

fn rows(v: Result<Value, String>) -> Vec<Value> {
    match v {
        Ok(Value::Array(a)) => a,
        _ => vec![],
    }
}

fn first(v: Result<Value, String>) -> Option<Value> {
    rows(v).into_iter().next()
}

fn st(input: &Value, k: &str) -> String {
    input.get(k).and_then(|x| x.as_str()).unwrap_or("").trim().to_string()
}

/// JS String(x) jaisa: null/missing => None.
fn jstr(v: Option<&Value>) -> Option<String> {
    match v {
        None | Some(Value::Null) => None,
        Some(Value::String(s)) => Some(s.clone()),
        Some(Value::Bool(b)) => Some(b.to_string()),
        Some(Value::Number(n)) => Some(n.to_string()),
        Some(o) => Some(o.to_string()),
    }
}

fn pick(row: &Value, cols: &[&str]) -> Value {
    let mut m = Map::new();
    for c in cols {
        m.insert((*c).to_string(), row.get(*c).cloned().unwrap_or(Value::Null));
    }
    Value::Object(m)
}

fn now_secs() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
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

const DEF_COLS: &str = "key,scope,label,help,kind,default_value,recommended,options,affects,reversible";
const JOB_COLS: [&str; 12] = [
    "id", "provider", "source_account", "target_mailbox", "state", "mode", "total", "done", "failed", "eta_minutes", "started_at", "finished_at",
];
const JOB_SEL: &str = "id,provider,source_account,target_mailbox,state,mode,total,done,failed,eta_minutes,started_at,finished_at,last_error";

fn setting_json(d: &Value, v: Option<&Value>) -> Value {
    let vv = v.and_then(|x| x.get("value")).filter(|x| !x.is_null());
    let value = vv.cloned().or_else(|| d.get("default_value").filter(|x| !x.is_null()).cloned()).unwrap_or(Value::Null);
    let rec = jstr(d.get("recommended"));
    let def = jstr(d.get("default_value"));
    let cur = jstr(vv);
    let drift = match c::drift_of(rec.as_deref(), def.as_deref(), cur.as_deref()) {
        Some(x) => json!(x),
        None => Value::Null,
    };
    json!({
        "key": d.get("key"), "scope": d.get("scope"), "label": d.get("label"), "help": d.get("help"), "kind": d.get("kind"),
        "value": value,
        "default_value": d.get("default_value").cloned().unwrap_or(Value::Null),
        "options": d.get("options").cloned().unwrap_or(Value::Null),
        "locked_by_policy": null,
        "drift": drift,
        "updated_at": v.and_then(|x| x.get("updated_at")).cloned().unwrap_or(Value::Null),
        "updated_by": v.and_then(|x| x.get("updated_by")).cloned().unwrap_or(Value::Null),
    })
}

async fn write_setting(uid: &str, key: &str, value: &str, reason: Option<&str>, by: &str) -> Result<Value, Resp> {
    let (u, k) = (enc(uid), enc(key));
    let q_d = format!("setting_defs?select={DEF_COLS}&key=eq.{k}&limit=1");
    let q_p = format!("setting_values?select=value&user_id=eq.{u}&key=eq.{k}&limit=1");
    let (d, p) = tokio::join!(crate::sb_select(&q_d), crate::sb_select(&q_p));
    let def = match first(d) {
        Some(x) => x,
        None => return Err(fail(StatusCode::UNPROCESSABLE_ENTITY, "unknown_setting", "unknown setting")),
    };
    let prev = first(p).and_then(|r| r.get("value").cloned()).unwrap_or(Value::Null);
    let saved = match crate::sb_upsert(
        "setting_values",
        "user_id,key",
        json!({ "user_id": uid, "key": key, "value": value, "updated_at": c_iso(), "updated_by": by }),
    )
    .await
    {
        Ok(v) => first(Ok(v)).unwrap_or(Value::Null),
        Err(e) => return Err(db_fail(&e)),
    };
    if let Err(e) = crate::sb_insert(
        "setting_versions",
        json!({
            "user_id": uid, "key": key, "from_value": prev, "to_value": value, "changed_by": by, "reason": reason,
            "blast": { "affects": def.get("affects").cloned().unwrap_or(json!([])), "reversible": def.get("reversible") }
        }),
    )
    .await
    {
        eprintln!("[setx.version] {e}");
    }
    Ok(setting_json(&def, Some(&saved)))
}

fn c_iso() -> String {
    c::iso_utc(now_secs())
}

async fn is_founder(uid: &str) -> bool {
    first(crate::sb_select(&format!("founder_accounts?select=user_id&user_id=eq.{}&limit=1", enc(uid))).await).is_some()
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let (uid, _email) = match crate::auth_user(token).await {
        Some(v) => v,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", "unauthorized"),
    };
    if c::founder_only(proc) && !is_founder(&uid).await {
        return fail(StatusCode::FORBIDDEN, "founder_only", "founder only");
    }
    let u = enc(&uid);
    match proc {
        // ------------------------------------------------------------ settings
        "settings.list" => {
            let scope = st(input, "scope");
            if !c::scope_ok(&scope) {
                return fail(StatusCode::UNPROCESSABLE_ENTITY, "unknown_scope", "unknown scope");
            }
            let q_d = format!("setting_defs?select={DEF_COLS}&scope=eq.{}", enc(&scope));
            let q_v = format!("setting_values?select=key,value,updated_at,updated_by&user_id=eq.{u}");
            let (d, v) = tokio::join!(crate::sb_select(&q_d), crate::sb_select(&q_v));
            if let Err(e) = &d {
                return db_fail(e);
            }
            let vals: HashMap<String, Value> =
                rows(v).into_iter().filter_map(|r| r.get("key").and_then(|k| k.as_str()).map(|k| (k.to_string(), r.clone()))).collect();
            let settings: Vec<Value> = rows(d)
                .iter()
                .map(|def| setting_json(def, def.get("key").and_then(|k| k.as_str()).and_then(|k| vals.get(k))))
                .collect();
            crate::ok(json!({ "settings": settings })).into_response()
        }
        "settings.explain" => {
            let key = st(input, "key");
            if !c::key_ok(&key) {
                return fail(StatusCode::UNPROCESSABLE_ENTITY, "unknown_setting", "unknown setting");
            }
            let k = enc(&key);
            let q_c = format!("setting_explanations?select=key,plain,example,tradeoff,source&key=eq.{k}&limit=1");
            if let Some(cached) = first(crate::sb_select(&q_c).await) {
                return crate::ok(cached).into_response();
            }
            let q_d = format!("setting_defs?select=key,label,help,recommended,risk_if_off,affects&key=eq.{k}&limit=1");
            let def = match first(crate::sb_select(&q_d).await) {
                Some(d) => d,
                None => return fail(StatusCode::UNPROCESSABLE_ENTITY, "unknown_setting", "unknown setting"),
            };
            let affects: Vec<String> = def
                .get("affects")
                .and_then(|a| a.as_array())
                .map(|a| a.iter().filter_map(|x| x.as_str().map(|s| s.to_string())).collect())
                .unwrap_or_default();
            let example = if affects.is_empty() { "Sirf tumhare account par asar hoga.".to_string() } else { format!("Asar yahan hoga: {}.", affects.join(", ")) };
            crate::ok(json!({
                "key": key, "plain": def.get("help").cloned().unwrap_or(Value::Null), "example": example,
                "tradeoff": def.get("risk_if_off").cloned().unwrap_or(Value::Null), "source": "server"
            }))
            .into_response()
        }
        "settings.save" => {
            let key = st(input, "key");
            if key.is_empty() {
                return fail(StatusCode::BAD_REQUEST, "key_required", "key required");
            }
            if !c::key_ok(&key) {
                return fail(StatusCode::UNPROCESSABLE_ENTITY, "unknown_setting", "unknown setting");
            }
            let value = match jstr(input.get("value")) {
                Some(v) => v,
                None => return fail(StatusCode::BAD_REQUEST, "value_required", "value required"),
            };
            let reason = jstr(input.get("reason")).filter(|r| !r.trim().is_empty());
            match write_setting(&uid, &key, &value, reason.as_deref(), "self").await {
                Ok(s) => crate::ok(s).into_response(),
                Err(r) => r,
            }
        }
        "settings.history" => {
            let key = st(input, "key");
            let mut q = format!(
                "setting_versions?select=id,key,from_value,to_value,changed_by,changed_at,reason,reverted&user_id=eq.{u}&order=changed_at.desc&limit=200"
            );
            if !key.is_empty() {
                if !c::key_ok(&key) {
                    return fail(StatusCode::BAD_REQUEST, "key_invalid", "key invalid");
                }
                q.push_str(&format!("&key=eq.{}", enc(&key)));
            }
            match crate::sb_select(&q).await {
                Ok(v) => crate::ok(json!({ "versions": if v.is_array() { v } else { json!([]) } })).into_response(),
                Err(e) => db_fail(&e),
            }
        }
        "settings.revert" => {
            let vid = st(input, "version_id");
            if vid.is_empty() {
                return fail(StatusCode::BAD_REQUEST, "version_id_required", "version_id required");
            }
            if !c::uuid_ok(&vid) {
                return fail(StatusCode::UNPROCESSABLE_ENTITY, "unknown_version", "unknown version");
            }
            let q = format!("setting_versions?select=id,key,from_value&user_id=eq.{u}&id=eq.{vid}&limit=1");
            let ver = match crate::sb_select(&q).await {
                Ok(v) => match first(Ok(v)) {
                    Some(r) => r,
                    None => return fail(StatusCode::UNPROCESSABLE_ENTITY, "unknown_version", "unknown version"),
                },
                Err(e) => return db_fail(&e),
            };
            let key = ver.get("key").and_then(|k| k.as_str()).unwrap_or("").to_string();
            // BUG FIX (Chrome live 04:47): pehli baar badli hui setting ki from_value NULL hoti hai (tab tak default chal raha tha);
            // pehle revert "" likh deta tha => toggle "Off/Risky" reh jata tha. Ab NULL ho to setting ka default_value wapas.
            let from = match jstr(ver.get("from_value")) {
                Some(f) => f,
                None => {
                    let q_def = format!("setting_defs?select=default_value&key=eq.{}&limit=1", enc(&key));
                    first(crate::sb_select(&q_def).await).and_then(|d| jstr(d.get("default_value"))).unwrap_or_default()
                }
            };
            let out = match write_setting(&uid, &key, &from, Some(&format!("revert of {vid}")), "revert").await {
                Ok(s) => s,
                Err(r) => return r,
            };
            if let Err(e) = crate::sb_patch(&format!("setting_versions?id=eq.{vid}&user_id=eq.{u}"), json!({ "reverted": true })).await {
                eprintln!("[setx.revert] {e}");
            }
            crate::ok(out).into_response()
        }
        "founderSettings.overview" => {
            let now = now_secs();
            let (s24, s7) = (c::iso_utc(now - 24 * 3600), c::iso_utc(now - 7 * 24 * 3600));
            let q1 = format!("setting_versions?select=id&changed_at=gte.{}", enc(&s24));
            let q2 = format!("setting_versions?select=id&reverted=eq.true&changed_at=gte.{}", enc(&s7));
            let q3 = "setting_schedules?select=id&state=eq.scheduled".to_string();
            let q4 = format!("setting_versions?select=key,user_id&changed_at=gte.{}&limit=2000", enc(&s7));
            let (a, b, p, r) = tokio::join!(crate::sb_count(&q1), crate::sb_count(&q2), crate::sb_count(&q3), crate::sb_select(&q4));
            let recent = rows(r);
            let keys: Vec<String> = recent.iter().filter_map(|x| x.get("key").and_then(|k| k.as_str()).map(|s| s.to_string())).collect();
            let mut tenants: Vec<&str> = recent.iter().filter_map(|x| x.get("user_id").and_then(|k| k.as_str())).collect();
            tenants.sort_unstable();
            tenants.dedup();
            let most: Vec<Value> = c::top_keys(&keys, 8).into_iter().map(|(key, changes)| json!({ "key": key, "changes": changes })).collect();
            crate::ok(json!({
                "tenants": tenants.len(), "changes_24h": a.unwrap_or(0), "reverts_7d": b.unwrap_or(0),
                "risky_tenants": [], "most_changed": most, "pending_scheduled": p.unwrap_or(0),
            }))
            .into_response()
        }

        // -------------------------------------------------------- integrations
        "integrations.providers" => {
            match crate::sb_select("integration_providers?select=id,label,kind,can_migrate,can_sync,can_send,notes,available&order=sort_order.asc").await {
                Ok(v) => crate::ok(json!({ "providers": if v.is_array() { v } else { json!([]) } })).into_response(),
                Err(e) => db_fail(&e),
            }
        }
        "integrations.connections" => {
            let q = format!("integration_connections?select=id,provider,account,state,scopes,last_sync_at,synced_threads,error,created_at&user_id=eq.{u}&order=created_at.desc");
            match crate::sb_select(&q).await {
                Ok(v) => crate::ok(json!({ "connections": if v.is_array() { v } else { json!([]) } })).into_response(),
                Err(e) => db_fail(&e),
            }
        }
        "integrations.connect" => {
            let provider = st(input, "provider");
            if provider.is_empty() {
                return fail(StatusCode::BAD_REQUEST, "provider_required", "provider required");
            }
            if !c::provider_ok(&provider) {
                return fail(StatusCode::BAD_REQUEST, "provider_unavailable", "provider unavailable");
            }
            let q = format!("integration_providers?select=id,kind,available&id=eq.{}&limit=1", enc(&provider));
            let p = match crate::sb_select(&q).await {
                Ok(v) => first(Ok(v)),
                Err(e) => return db_fail(&e),
            };
            let p = match p {
                Some(p) if p.get("available").and_then(|a| a.as_bool()).unwrap_or(false) => p,
                _ => return fail(StatusCode::BAD_REQUEST, "provider_unavailable", "provider unavailable"),
            };
            // OAuth (Google/Microsoft/Zoho): client credentials ke bagair start nahi hota — sachchi 422 (501 nahi: client Bun par na gire).
            if p.get("kind").and_then(|k| k.as_str()) == Some("oauth") {
                return fail(StatusCode::UNPROCESSABLE_ENTITY, "oauth_client_pending", &format!("{provider} oauth client pending"));
            }
            let account = st(input, "account");
            if account.is_empty() {
                return fail(StatusCode::BAD_REQUEST, "account_required", "account required");
            }
            if !c::account_ok(&account) {
                return fail(StatusCode::BAD_REQUEST, "account_invalid", "account invalid");
            }
            let host = match input.get("host") {
                None | Some(Value::Null) => Value::Null,
                Some(Value::String(h)) if h.trim().is_empty() => Value::Null,
                Some(Value::String(h)) if c::host_ok(h) => json!(h.trim().to_lowercase()),
                _ => return fail(StatusCode::BAD_REQUEST, "host_invalid", "host invalid"),
            };
            let port = match input.get("port") {
                None | Some(Value::Null) => Value::Null,
                Some(v) => match v.as_i64().or_else(|| v.as_str().and_then(|s| s.trim().parse::<i64>().ok())) {
                    Some(n) if c::port_ok(n) => json!(n),
                    _ => return fail(StatusCode::BAD_REQUEST, "port_invalid", "port invalid"),
                },
            };
            // credentials request body se nahi, server vault se aate hain => state needs_reauth
            let body = json!({ "user_id": uid, "provider": provider, "account": account, "host": host, "port": port, "state": "needs_reauth", "updated_at": c_iso() });
            match crate::sb_upsert("integration_connections", "user_id,provider,account", body).await {
                Ok(v) => match first(Ok(v)) {
                    Some(r) => crate::ok(json!({ "id": r.get("id"), "state": r.get("state"), "redirect_url": null })).into_response(),
                    None => db_fail("connect: empty"),
                },
                Err(e) => db_fail(&e),
            }
        }
        "integrations.disconnect" => {
            let id = st(input, "id");
            if id.is_empty() {
                return fail(StatusCode::BAD_REQUEST, "id_required", "id required");
            }
            if !c::uuid_ok(&id) {
                return fail(StatusCode::UNPROCESSABLE_ENTITY, "connection_not_found", "connection not found");
            }
            match delete(&format!("integration_connections?user_id=eq.{u}&id=eq.{id}")).await {
                Ok(()) => crate::ok(json!({ "ok": true })).into_response(),
                Err(e) => db_fail(&e),
            }
        }
        "integrations.migrations" => {
            let q = format!("integration_migrations?select={JOB_SEL}&user_id=eq.{u}&order=created_at.desc&limit=50");
            match crate::sb_select(&q).await {
                Ok(v) => crate::ok(json!({ "jobs": if v.is_array() { v } else { json!([]) } })).into_response(),
                Err(e) => db_fail(&e),
            }
        }
        "integrations.startMigration" => {
            let (cid, target) = (st(input, "connection_id"), st(input, "target_mailbox"));
            if cid.is_empty() || target.is_empty() {
                return fail(StatusCode::BAD_REQUEST, "connection_and_target_required", "connection and target required");
            }
            if !c::uuid_ok(&cid) {
                return fail(StatusCode::UNPROCESSABLE_ENTITY, "connection_not_found", "connection not found");
            }
            if !c::email_ok(&target) {
                return fail(StatusCode::BAD_REQUEST, "target_invalid", "target mailbox invalid");
            }
            let target = target.to_lowercase();
            let q_c = format!("integration_connections?select=id,provider,account&user_id=eq.{u}&id=eq.{cid}&limit=1");
            let conn = match crate::sb_select(&q_c).await {
                Ok(v) => match first(Ok(v)) {
                    Some(r) => r,
                    None => return fail(StatusCode::UNPROCESSABLE_ENTITY, "connection_not_found", "connection not found"),
                },
                Err(e) => return db_fail(&e),
            };
            // LOOPHOLE: dusre ki mailbox mein import nahi. Mailbox maujood hai to uski org ka member hona lazmi; maujood nahi (team banayegi) to ijazat.
            if let Some(mb) = first(crate::sb_select(&format!("mail_accounts?select=org_id&address=eq.{}&limit=1", enc(&target))).await) {
                if let Some(org) = mb.get("org_id").and_then(|o| o.as_str()) {
                    let q_m = format!("org_members?select=org_id&user_id=eq.{u}&org_id=eq.{}&limit=1", enc(org));
                    if first(crate::sb_select(&q_m).await).is_none() {
                        return fail(StatusCode::FORBIDDEN, "mailbox_not_yours", "target mailbox is not in your workspace");
                    }
                }
            }
            let mode = if input.get("mode").and_then(|m| m.as_str()) == Some("mirror") { "mirror" } else { "copy" };
            let body = json!({
                "user_id": uid, "connection_id": conn.get("id"), "provider": conn.get("provider"), "source_account": conn.get("account"),
                "target_mailbox": target, "mode": mode, "state": "queued"
            });
            match crate::sb_insert("integration_migrations", body).await {
                Ok(v) => match first(Ok(v)) {
                    Some(r) => crate::ok(pick(&r, &[&JOB_COLS[..], &["last_error"][..]].concat())).into_response(),
                    None => db_fail("startMigration: empty"),
                },
                Err(e) => db_fail(&e),
            }
        }
        "integrations.controlMigration" => {
            let (id, action) = (st(input, "id"), st(input, "action"));
            let (state, clear_err, finish, err_txt) = match c::control_action(&action) {
                Some(a) if !id.is_empty() => a,
                _ => return fail(StatusCode::BAD_REQUEST, "bad_request", "bad request"),
            };
            if !c::uuid_ok(&id) {
                return fail(StatusCode::UNPROCESSABLE_ENTITY, "job_not_found", "job not found");
            }
            let q_x = format!("integration_migrations?select=id&user_id=eq.{u}&id=eq.{id}&limit=1");
            match crate::sb_select(&q_x).await {
                Ok(v) => {
                    if v.as_array().map(|a| a.is_empty()).unwrap_or(true) {
                        return fail(StatusCode::UNPROCESSABLE_ENTITY, "job_not_found", "job not found");
                    }
                }
                Err(e) => return db_fail(&e),
            }
            let mut patch = json!({ "state": state });
            if clear_err {
                patch["last_error"] = Value::Null;
            }
            if let Some(t) = err_txt {
                patch["last_error"] = json!(t);
            }
            if finish {
                patch["finished_at"] = json!(c_iso());
            }
            if let Err(e) = crate::sb_patch(&format!("integration_migrations?user_id=eq.{u}&id=eq.{id}"), patch).await {
                return db_fail(&e);
            }
            let q = format!("integration_migrations?select={JOB_SEL}&user_id=eq.{u}&id=eq.{id}&limit=1");
            match first(crate::sb_select(&q).await) {
                Some(r) => crate::ok(r).into_response(),
                None => fail(StatusCode::UNPROCESSABLE_ENTITY, "job_not_found", "job not found"),
            }
        }
        "integrations.delivery" => {
            let d = st(input, "domain").to_lowercase();
            let domain = if d.is_empty() { "anexomail.com".to_string() } else { d };
            if !c::host_ok(&domain) {
                return fail(StatusCode::BAD_REQUEST, "domain_invalid", "domain invalid");
            }
            let q_c = format!("delivery_checks?select=key,state,detail,fix,checked_at&domain=eq.{}", enc(&domain));
            let q_l = format!("delivery_blocklists?select=name,listed&domain=eq.{}", enc(&domain));
            let (checks, lists) = tokio::join!(crate::sb_select(&q_c), crate::sb_select(&q_l));
            if let Err(e) = &checks {
                return db_fail(e);
            }
            let checks = rows(checks);
            let ok_n = checks.iter().filter(|r| r.get("state").and_then(|s| s.as_str()) == Some("ok")).count();
            let score = if checks.is_empty() { 0 } else { ((ok_n as f64 / checks.len() as f64) * 100.0).round() as i64 };
            let reputation = if checks.is_empty() { "unknown" } else if score >= 90 { "good" } else if score >= 70 { "watch" } else { "poor" };
            crate::ok(json!({ "domain": domain, "score": score, "checks": checks, "blocklists": rows(lists), "reputation": reputation })).into_response()
        }
        "integrations.exports" => {
            let q = format!("integration_exports?select=id,scope,format,state,size_bytes,url,expires_at,created_at&user_id=eq.{u}&order=created_at.desc&limit=30");
            match crate::sb_select(&q).await {
                Ok(v) => crate::ok(json!({ "jobs": if v.is_array() { v } else { json!([]) } })).into_response(),
                Err(e) => db_fail(&e),
            }
        }
        "integrations.export" => {
            let scope = { let s = st(input, "scope"); if s.is_empty() { "everything".to_string() } else { s } };
            let format = { let s = st(input, "format"); if s.is_empty() { "mbox".to_string() } else { s } };
            if !c::export_scope_ok(&scope) {
                return fail(StatusCode::BAD_REQUEST, "bad_scope", "bad scope");
            }
            if !c::export_format_ok(&format) {
                return fail(StatusCode::BAD_REQUEST, "bad_format", "bad format");
            }
            match crate::sb_insert("integration_exports", json!({ "user_id": uid, "scope": scope, "format": format, "state": "queued" })).await {
                Ok(v) => match first(Ok(v)) {
                    Some(r) => crate::ok(pick(&r, &["id", "scope", "format", "state", "size_bytes", "url", "expires_at", "created_at"])).into_response(),
                    None => db_fail("export: empty"),
                },
                Err(e) => db_fail(&e),
            }
        }

        // ------------------------------------------------------ founder views
        "founderIntegrations.overview" => match crate::sb_rpc("founder_integrations_overview", json!({})).await {
            Ok(v) => crate::ok(v).into_response(),
            Err(e) => db_fail(&e),
        },
        "founderSecurity.overview" => match crate::sb_rpc("founder_security_overview", json!({})).await {
            Ok(d) => {
                let n = |k: &str| d.get(k).and_then(|x| x.as_i64()).unwrap_or(0);
                crate::ok(json!({
                    "tenants": n("tenants"), "devices_blocked": n("devices_blocked"), "open_anomalies": n("open_anomalies"),
                    "frozen_accounts": n("frozen_accounts"), "failed_logins_24h": n("failed_logins_24h"), "kill_switches_30d": n("kill_switches_30d"),
                    "worst_tenants": d.get("worst_tenants").filter(|w| w.is_array()).cloned().unwrap_or(json!([])),
                }))
                .into_response()
            }
            Err(e) => db_fail(&e),
        },
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", "unknown proc"),
    }
}
