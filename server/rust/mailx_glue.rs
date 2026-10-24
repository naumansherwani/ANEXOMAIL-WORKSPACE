// ============================================================================
// mailx_glue.rs — M1/M2: Pro mail actions, Rust PRIMARY. Bun `/api/mail/...` is the emergency fallback only
// (client rpcOrRest falls back on 404/501/502/503/0).
//
//   mail.snooze            {thread_id, until|null}        Pro+  (until=null brings the thread back; folder is NEVER changed)
//   mail.status            {thread_id, status}            open|waiting|done
//   mail.move              {thread_id, folder}
//   mail.labels.update     {thread_id, add[], remove[]}
//   mail.assign            {thread_id, assignee}          Pro+  (uuid, e-mail or full name; GoTrue lookup like Bun)
//   mail.templates.save    {name, subject, body}          Pro+  (personal scope, 50 per person)
//   mail.templates.delete  {id}                           own template only
//   M2: mail.drafts.save / mail.drafts.versions (own drafts only, race-safe versions), mail.templates.list, mail.snippets.list|save,
//       mail.signatures.list, mail.confidence (send-confidence, ported 1:1 + differential-tested vs the Bun/JS original),
//       mail.followup.create|list (bad dates are a 400, never a crash)
//   mail.threads           {folder,...}                   wraps main.rs `mail_query_threads`: inbox hides future-snoozed
//                                                          threads, folder "snoozed" lists them (virtual folder, = inbox + snoozed_until > now)
//
// Same plan gate for EVERY account kind (basic/pro/business/business pro/personal/family): `resolve_plan` RPC, no per-kind code.
// Child module of the crate root: uses `mail_identity`, `mail_query_threads`, `sb_*`, `sb()`, `http()`, `ok`, `err`.
// ============================================================================
use crate::mailx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use std::time::{SystemTime, UNIX_EPOCH};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "mail.snooze"
            | "mail.status"
            | "mail.move"
            | "mail.labels.update"
            | "mail.assign"
            | "mail.templates.save"
            | "mail.templates.delete"
            | "mail.threads"
            | "mail.drafts.save"
            | "mail.drafts.versions"
            | "mail.templates.list"
            | "mail.snippets.list"
            | "mail.snippets.save"
            | "mail.signatures.list"
            | "mail.confidence"
            | "mail.followup.create"
            | "mail.followup.list"
    )
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}
fn data(v: Value) -> Resp {
    crate::ok(v).into_response()
}
fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}
fn bad(code: &str) -> Resp {
    fail(StatusCode::BAD_REQUEST, code, code)
}
fn db_fail(e: &str) -> Resp {
    eprintln!("[mailx] {}", e.chars().take(200).collect::<String>());
    fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", "database error")
}
fn now_secs() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}
fn list(input: &Value, k: &str) -> Vec<String> {
    input
        .get(k)
        .and_then(|v| v.as_array())
        .map(|a| a.iter().filter_map(|x| x.as_str()).map(|x| x.trim().to_string()).filter(|x| !x.is_empty()).collect())
        .unwrap_or_default()
}

/// resolve_plan (SQL RPC, reads family_accounts / trial_accounts / subscriptions): one gate for every account kind.
async fn plan_of(user_id: &str, email: &str) -> String {
    crate::sb_rpc("resolve_plan", json!({ "_user_id": user_id, "_email": email }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .unwrap_or_else(|| "basic".to_string())
}
async fn pro_gate(me: &crate::MailMe, msg: &str) -> Option<Resp> {
    if c::plan_allows_pro(&plan_of(&me.id, &me.email).await) {
        None
    } else {
        Some(fail(StatusCode::FORBIDDEN, "feature_not_available", msg))
    }
}

async fn thread_owned(org: &str, thread: &str) -> bool {
    crate::sb_count(&format!("mail_threads?select=id&org_id=eq.{org}&id=eq.{thread}")).await.unwrap_or(0) > 0
}

async fn pg_delete_rows(path_and_query: &str) -> Result<usize, String> {
    let (url, key) = crate::sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let res = crate::http()
        .delete(format!("{url}/rest/v1/{path_and_query}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .header("prefer", "return=representation")
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !res.status().is_success() {
        return Err(format!("delete {}", res.status()));
    }
    let body: Value = res.json().await.unwrap_or(Value::Null);
    Ok(body.as_array().map(|a| a.len()).unwrap_or(0))
}

async fn label_id(org: &str, name: &str) -> Option<String> {
    let q = if c::is_uuid(name) {
        format!("mail_labels?select=id&org_id=eq.{org}&id=eq.{name}&limit=1")
    } else {
        format!("mail_labels?select=id&org_id=eq.{org}&name=eq.{}&limit=1", c::pct(name))
    };
    crate::sb_select(&q).await.ok()?.as_array()?.first()?.get("id")?.as_str().map(|x| x.to_string())
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let me = match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(m) => m,
        Err((s, code, m)) => return crate::err(s, code, &m).into_response(),
    };
    if proc == "mail.threads" {
        return threads(&me, input).await;
    }
    if proc == "mail.templates.save" {
        return template_save(&me, input).await;
    }
    if proc == "mail.templates.delete" {
        let id = st(input, "id");
        if !c::is_uuid(&id) {
            return bad("id_required");
        }
        return match pg_delete_rows(&format!("mail_templates?id=eq.{id}&org_id=eq.{}&user_id=eq.{}&select=id", me.org_id, me.id)).await {
            Ok(n) => data(json!({ "removed": n })),
            Err(e) => db_fail(&e),
        };
    }

    if let Some(r) = compose(proc, &me, input).await {
        return r;
    }

    // everything below acts on one thread of the caller's workspace
    let thread = st(input, "thread_id");
    if !c::is_uuid(&thread) {
        return bad("thread_id_required");
    }
    if !thread_owned(&me.org_id, &thread).await {
        return fail(StatusCode::NOT_FOUND, "not_found", "not_found");
    }
    let patch_path = format!("mail_threads?id=eq.{thread}&org_id=eq.{}", me.org_id);
    match proc {
        "mail.snooze" => {
            let until = match c::check_until(input.get("until").and_then(|v| v.as_str()).unwrap_or("")) {
                Ok(u) => u,
                Err(code) => return bad(code),
            };
            if until.is_some() {
                if let Some(r) = pro_gate(&me, "Snooze is a Pro+ feature.").await {
                    return r;
                }
            }
            // never touches `folder` (there is no 'snoozed' mail_folder); the inbox hides the thread until `until`.
            match crate::sb_patch(&patch_path, json!({ "snoozed_until": until })).await {
                Ok(_) => data(json!({ "ok": true })),
                Err(e) => db_fail(&e),
            }
        }
        "mail.status" => {
            let status = st(input, "status");
            if !c::valid_status(&status) {
                return bad("bad_status");
            }
            match crate::sb_patch(&patch_path, json!({ "status": status })).await {
                Ok(_) => data(json!({ "ok": true })),
                Err(e) => db_fail(&e),
            }
        }
        "mail.move" => {
            let folder = st(input, "folder");
            if !c::valid_folder(&folder) {
                return bad("bad_folder");
            }
            match crate::sb_patch(&patch_path, json!({ "folder": folder })).await {
                Ok(_) => data(json!({ "ok": true })),
                Err(e) => db_fail(&e),
            }
        }
        "mail.labels.update" => labels(&me, &thread, input).await,
        "mail.assign" => assign(&me, &thread, input).await,
        _ => fail(StatusCode::NOT_IMPLEMENTED, "use_bun_fallback", "use_bun_fallback"),
    }
}

async fn labels(me: &crate::MailMe, thread: &str, input: &Value) -> Resp {
    let (add, remove) = (list(input, "add"), list(input, "remove"));
    if let Err(code) = c::check_labels(&add, &remove) {
        return bad(code);
    }
    for name in &add {
        let id = match label_id(&me.org_id, name).await {
            Some(id) => id,
            None => match crate::sb_insert("mail_labels", json!({ "org_id": me.org_id, "name": name })).await {
                Ok(rows) => rows.as_array().and_then(|a| a.first()).and_then(|r| r.get("id")?.as_str().map(|x| x.to_string())).unwrap_or_default(),
                Err(e) => return db_fail(&e),
            },
        };
        if id.is_empty() {
            continue;
        }
        if let Err(e) = crate::sb_upsert("mail_thread_labels", "thread_id,label_id", json!({ "thread_id": thread, "label_id": id })).await {
            return db_fail(&e);
        }
    }
    for name in &remove {
        if let Some(id) = label_id(&me.org_id, name).await {
            if let Err(e) = pg_delete_rows(&format!("mail_thread_labels?thread_id=eq.{thread}&label_id=eq.{id}&select=thread_id")).await {
                return db_fail(&e);
            }
        }
    }
    data(json!({ "ok": true }))
}

/// uuid as is; otherwise e-mail or full name through the GoTrue admin list (same match as Bun; the `?email=` filter is ignored by GoTrue).
async fn find_user(needle: &str) -> Option<String> {
    let (url, key) = crate::sb()?;
    let res = crate::http()
        .get(format!("{url}/auth/v1/admin/users?per_page=1000"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await
        .ok()?;
    let j: Value = res.json().await.ok()?;
    let n = needle.to_lowercase();
    let users = j.get("users")?.as_array()?;
    let by = |f: &dyn Fn(&Value) -> String| users.iter().find(|u| f(u) == n).and_then(|u| u.get("id")?.as_str().map(|x| x.to_string()));
    by(&|u| u.get("email").and_then(|x| x.as_str()).unwrap_or("").to_lowercase())
        .or_else(|| by(&|u| u.get("user_metadata").and_then(|m| m.get("full_name")).and_then(|x| x.as_str()).unwrap_or("").to_lowercase()))
}

async fn assign(me: &crate::MailMe, thread: &str, input: &Value) -> Resp {
    if let Some(r) = pro_gate(me, "Shared inbox with collision guard is a Pro+ feature. Upgrade to assign threads.").await {
        return r;
    }
    let who = st(input, "assignee").trim().to_string();
    let assignee = if who.is_empty() || c::is_uuid(&who) {
        who
    } else {
        match find_user(&who).await {
            Some(id) => id,
            None => return bad("assignee_not_found"),
        }
    };
    // E85: ONE function (uuid, uuid|null, uuid). null = remove the assignee; the DB refuses anyone who is not an active member.
    let who = if assignee.is_empty() { Value::Null } else { json!(assignee) };
    match crate::sb_rpc("mail_thread_assign", json!({ "_thread_id": thread, "_assignee": who, "_org_id": me.org_id })).await {
        Ok(t) => data(json!({ "ok": true, "thread": t })),
        Err(e) if e.contains("assignee_not_member") => bad("assignee_not_member"),
        Err(e) => fail(StatusCode::BAD_REQUEST, "assign_failed", &e.chars().take(200).collect::<String>()),
    }
}

async fn template_save(me: &crate::MailMe, input: &Value) -> Resp {
    let (name, body) = (st(input, "name").trim().to_string(), st(input, "body"));
    if let Err(code) = c::check_template(&name, &body) {
        return bad(code);
    }
    if let Some(r) = pro_gate(me, "Email templates are a Pro+ feature.").await {
        return r;
    }
    let have = crate::sb_count(&format!("mail_templates?select=id&org_id=eq.{}&user_id=eq.{}", me.org_id, me.id)).await.unwrap_or(0);
    if have >= c::MAX_TEMPLATES_PER_USER {
        return fail(StatusCode::CONFLICT, "too_many", "too_many");
    }
    let subject: Value = match input.get("subject").and_then(|v| v.as_str()) {
        Some(x) => Value::String(x.chars().take(200).collect()),
        None => Value::Null,
    };
    let row = json!({ "org_id": me.org_id, "user_id": me.id, "name": name, "scope": "personal", "subject": subject, "body": body, "variables": c::template_vars(&body) });
    match crate::sb_insert("mail_templates", row).await {
        Ok(rows) => data(json!({ "id": rows.as_array().and_then(|a| a.first()).and_then(|r| r.get("id").cloned()).unwrap_or(Value::Null) })),
        Err(e) => db_fail(&e),
    }
}

/// inbox: hide threads snoozed into the future · snoozed: only those · any other folder: untouched.
async fn threads(me: &crate::MailMe, input: &Value) -> Resp {
    let folder = st(input, "folder");
    let mode = match folder.as_str() {
        "snoozed" => 1,
        "" | "inbox" => 0,
        _ => 2,
    };
    let mut inp = input.clone();
    if mode == 1 {
        inp["folder"] = json!("inbox");
    }
    let mut out = match crate::mail_query_threads(&me.org_id, &inp).await {
        Ok(v) => v,
        Err(e) => return db_fail(&e),
    };
    if mode != 2 {
        let now = c::iso_prefix(now_secs());
        if let Some(arr) = out.get_mut("threads").and_then(|t| t.as_array_mut()) {
            arr.retain(|t| {
                let future = t.get("snoozed_until").and_then(|v| v.as_str()).map(|u| c::is_future(u, &now)).unwrap_or(false);
                if mode == 1 { future } else { !future }
            });
        }
    }
    data(out)
}

// ── M2: compose-side procs (drafts, templates list, snippets, signatures, send-confidence, follow-ups) ────────────────
fn new_uuid() -> String {
    use std::io::Read;
    let mut b = [0u8; 16];
    let ok = std::fs::File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut b)).is_ok();
    if !ok {
        let n = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(1);
        b.copy_from_slice(&n.to_be_bytes());
    }
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    let h: Vec<String> = b.iter().map(|x| format!("{x:02x}")).collect();
    format!("{}-{}-{}-{}-{}", h[0..4].concat(), h[4..6].concat(), h[6..8].concat(), h[8..10].concat(), h[10..16].concat())
}

fn opt_str(input: &Value, k: &str) -> Value {
    match input.get(k).and_then(|v| v.as_str()) {
        Some(x) if !x.is_empty() => Value::String(x.to_string()),
        _ => Value::Null,
    }
}

async fn compose(proc: &str, me: &crate::MailMe, input: &Value) -> Option<Resp> {
    Some(match proc {
        "mail.drafts.save" => drafts_save(me, input).await,
        "mail.drafts.versions" => {
            let id = st(input, "id");
            if !c::is_uuid(&id) {
                return Some(bad("id_required"));
            }
            let q = format!(
                "mail_drafts_versions?select=id,version,saved_at,subject,body&org_id=eq.{}&user_id=eq.{}&draft_id=eq.{id}&order=version.desc&limit=40",
                me.org_id, me.id
            );
            match crate::sb_select(&q).await {
                Ok(rows) => {
                    let v: Vec<Value> = rows
                        .as_array()
                        .cloned()
                        .unwrap_or_default()
                        .iter()
                        .map(|r| json!({ "id": r["id"], "version": r["version"], "saved_at": r["saved_at"], "subject": r["subject"], "body": r["body"] }))
                        .collect();
                    data(json!({ "versions": v }))
                }
                Err(e) => db_fail(&e),
            }
        }
        "mail.templates.list" => {
            let q = format!(
                "mail_templates?select=id,name,scope,subject,body,variables&org_id=eq.{}&or=(scope.eq.org,user_id.eq.{})&order=name",
                me.org_id, me.id
            );
            match crate::sb_select(&q).await {
                Ok(rows) => {
                    let t: Vec<Value> = rows
                        .as_array()
                        .cloned()
                        .unwrap_or_default()
                        .into_iter()
                        .map(|mut r| {
                            if r.get("variables").map(|v| v.is_null()).unwrap_or(true) {
                                r["variables"] = json!([]);
                            }
                            r
                        })
                        .collect();
                    data(json!({ "templates": t }))
                }
                Err(e) => db_fail(&e),
            }
        }
        "mail.snippets.list" => match crate::sb_select(&format!("mail_snippets?select=id,shortcut,body&org_id=eq.{}&user_id=eq.{}&order=shortcut", me.org_id, me.id)).await {
            Ok(rows) => data(json!({ "snippets": rows })),
            Err(e) => db_fail(&e),
        },
        "mail.snippets.save" => {
            let (shortcut, body) = (st(input, "shortcut").trim().to_string(), st(input, "body"));
            if let Err(code) = c::check_snippet(&shortcut, &body) {
                return Some(bad(code));
            }
            let have = crate::sb_count(&format!("mail_snippets?select=id&org_id=eq.{}&user_id=eq.{}", me.org_id, me.id)).await.unwrap_or(0);
            if have >= c::MAX_SNIPPETS_PER_USER {
                return Some(fail(StatusCode::CONFLICT, "too_many", "too_many"));
            }
            match crate::sb_insert("mail_snippets", json!({ "org_id": me.org_id, "user_id": me.id, "shortcut": shortcut, "body": body })).await {
                Ok(rows) => data(json!({ "id": rows.as_array().and_then(|a| a.first()).and_then(|r| r.get("id").cloned()).unwrap_or(Value::Null) })),
                Err(e) => db_fail(&e),
            }
        }
        "mail.signatures.list" => match crate::sb_select(&format!("mail_signatures?select=id,identity,name,body,is_default&org_id=eq.{}&user_id=eq.{}&order=is_default.desc", me.org_id, me.id)).await {
            Ok(rows) => data(json!({ "signatures": rows })),
            Err(e) => db_fail(&e),
        },
        "mail.confidence" => {
            let to = match input.get("to") {
                Some(Value::Array(a)) => a.iter().filter_map(|x| x.as_str()).collect::<Vec<_>>().join(","),
                _ => st(input, "to"),
            };
            let att = input.get("attachments").and_then(|v| v.as_i64().or_else(|| v.as_f64().map(|f| f as i64))).unwrap_or(0);
            let (score, issues) = c::send_confidence(&to, &st(input, "subject"), &st(input, "body"), att);
            let list: Vec<Value> = issues.iter().map(|i| json!({ "kind": i.kind, "severity": i.severity, "message": i.message })).collect();
            data(json!({ "score": score, "issues": list }))
        }
        "mail.followup.create" => {
            let remind = match c::check_remind(&st(input, "remind_at")) {
                Ok(r) => r,
                Err(code) => return Some(bad(code)),
            };
            let thread = st(input, "thread_id");
            if !thread.is_empty() && (!c::is_uuid(&thread) || !thread_owned(&me.org_id, &thread).await) {
                return Some(fail(StatusCode::NOT_FOUND, "not_found", "not_found"));
            }
            let subject: Value = match input.get("subject").and_then(|v| v.as_str()) {
                Some(x) if !x.is_empty() => Value::String(x.chars().take(998).collect()),
                _ => Value::Null,
            };
            let row = json!({ "org_id": me.org_id, "user_id": me.id, "thread_id": if thread.is_empty() { Value::Null } else { json!(thread) }, "subject": subject, "remind_at": remind, "status": "pending" });
            match crate::sb_insert("mail_followups", row).await {
                Ok(rows) => {
                    let r = rows.as_array().and_then(|a| a.first()).cloned().unwrap_or(Value::Null);
                    data(json!({ "id": r["id"], "thread_id": r["thread_id"], "subject": r["subject"], "remind_at": r["remind_at"], "status": r["status"] }))
                }
                Err(e) if e.contains("22007") || e.contains("22008") || e.contains("date/time") || e.contains("timestamp") => bad("bad_remind_at"),
                Err(e) => db_fail(&e),
            }
        }
        "mail.followup.list" => match crate::sb_select(&format!("mail_followups?select=id,thread_id,subject,remind_at,status&org_id=eq.{}&user_id=eq.{}&order=remind_at", me.org_id, me.id)).await {
            Ok(rows) => data(json!({ "follow_ups": rows })),
            Err(e) => db_fail(&e),
        },
        _ => return None,
    })
}

async fn drafts_save(me: &crate::MailMe, input: &Value) -> Resp {
    let (subject, body, to, cc, bcc, identity) = (st(input, "subject"), st(input, "body"), st(input, "to"), st(input, "cc"), st(input, "bcc"), st(input, "identity"));
    if let Err(code) = c::check_draft(&subject, &body, &to, &cc, &bcc, &identity) {
        return bad(code);
    }
    let given = st(input, "id");
    if !given.is_empty() && !c::is_uuid(&given) {
        return bad("id_invalid");
    }
    let thread = st(input, "thread_id");
    if !thread.is_empty() && (!c::is_uuid(&thread) || !thread_owned(&me.org_id, &thread).await) {
        return fail(StatusCode::NOT_FOUND, "not_found", "not_found");
    }
    let draft_id = if given.is_empty() { new_uuid() } else { given.to_lowercase() };
    // a draft id that already has versions must belong to this user (Bun let anyone append to someone else's draft id)
    if !given.is_empty() {
        let owner = crate::sb_select(&format!("mail_drafts_versions?select=user_id,org_id&draft_id=eq.{draft_id}&limit=1")).await.ok();
        if let Some(r) = owner.as_ref().and_then(|v| v.as_array()).and_then(|a| a.first()) {
            if r.get("user_id").and_then(|x| x.as_str()) != Some(me.id.as_str()) || r.get("org_id").and_then(|x| x.as_str()) != Some(me.org_id.as_str()) {
                return fail(StatusCode::NOT_FOUND, "not_found", "not_found");
            }
        }
    }
    let send_at = match input.get("send_at").and_then(|v| v.as_str()).filter(|x| !x.is_empty()) {
        Some(x) => match c::check_remind(x) {
            Ok(t) => Value::String(t),
            Err(_) => return bad("send_at_invalid"),
        },
        None => Value::Null,
    };
    // version = last + 1; two saves racing for the same number collide on the unique key -> read again and retry (max 4 times)
    for _ in 0..4 {
        let last = crate::sb_select(&format!("mail_drafts_versions?select=version&draft_id=eq.{draft_id}&order=version.desc&limit=1")).await.ok();
        let version = last.as_ref().and_then(|v| v.as_array()).and_then(|a| a.first()).and_then(|r| r.get("version")).and_then(|x| x.as_i64()).unwrap_or(0) + 1;
        let row = json!({
            "org_id": me.org_id, "draft_id": draft_id, "user_id": me.id,
            "thread_id": if thread.is_empty() { Value::Null } else { json!(thread) },
            "version": version, "identity": opt_str(input, "identity"),
            "to": to, "cc": opt_str(input, "cc"), "bcc": opt_str(input, "bcc"), // live columns are to/cc/bcc (Bun used to_addresses: autosave 500)
            "subject": opt_str(input, "subject"), "body": opt_str(input, "body"),
            "send_at": send_at, "language": opt_str(input, "language"),
        });
        match crate::sb_insert("mail_drafts_versions", row).await {
            Ok(_) => return data(json!({ "id": draft_id, "version": version, "saved_at": format!("{}.000Z", c::iso_prefix(now_secs())) })),
            Err(e) if e.contains("23505") => continue,
            Err(e) => return db_fail(&e),
        }
    }
    fail(StatusCode::CONFLICT, "draft_busy", "draft_busy")
}
