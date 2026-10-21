// ============================================================================
// mail_glue.rs — I/O half of B3 (R1): mail.send + org.mailboxes.* on Rust (founder 21 Oct 2026). Bun /api/mail/send and
// /api/org/mailboxes stay as the fallback (client rpcOrRest falls back on 404/501/502/503/0 only).
//
//   mail.send              {to,cc,bcc,subject,body,html,reply_to,from_name,thread_id,send_at,attachment_ids}
//                          -> same contract as POST /api/mail/send: {ok, thread_id, message_id, message_id_smtp} (or scheduled_at)
//   org.mailboxes.list     -> {ok, mailboxes, plan, limit, used, remaining}
//   org.mailboxes.create   {address} -> {ok, mailbox, plan, remaining}   (owner / admin / manager / founder; plan limit; org_writes switch)
//
// Loopholes closed vs Bun: every recipient/reply-to is shape-checked (no CR/LF/space/<> ever reaches a header or an SMTP command),
// recipients capped (100), `thread_id` must belong to the caller's org (Bun let a foreign thread id through and rewrote its
// message_count), a failed SMTP hands back a clean state (the Sent row we wrote is removed — Bun left a "sent" message that never
// went), message_count is the real count. MIME/SMTP bytes are identical to sendmail.ts (mail-proof.py compares them).
// Child module of the crate root: uses `mail_identity`, `is_founder`, `sb_*`, `env_var`, `ok`, `err`. Adds NO new crate (sha2 present).
// ============================================================================

use crate::mail_core as mc;
use axum::{http::HeaderMap, http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::time::{SystemTime, UNIX_EPOCH};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(proc, "mail.send" | "mail.schedule" | "mail.schedule.cancel" | "org.mailboxes.list" | "org.mailboxes.create")
}

fn fail(status: StatusCode, code: &str) -> Resp {
    crate::err(status, code, code).into_response()
}
fn fail_with(status: StatusCode, code: &str, extra: Value) -> Resp {
    let mut e = json!({ "code": code, "message": code });
    if let (Some(o), Some(x)) = (e.as_object_mut(), extra.as_object()) {
        for (k, v) in x {
            o.insert(k.clone(), v.clone());
        }
    }
    (status, axum::Json(json!({ "error": e }))).into_response()
}
fn now_secs() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}
fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}
/// Bun `list()`: array (falsy dropped) or comma string. Non-string array items are an error (never coerced into a header).
fn addr_list(v: &Value, k: &str) -> Result<Vec<String>, ()> {
    match v.get(k) {
        None | Some(Value::Null) => Ok(vec![]),
        Some(Value::String(s)) => Ok(mc::split_commas(s)),
        Some(Value::Array(a)) => a
            .iter()
            .filter(|x| !x.is_null() && x.as_str() != Some(""))
            .map(|x| x.as_str().map(|s| s.to_string()).ok_or(()))
            .collect(),
        _ => Err(()),
    }
}
fn org_hdr(h: &HeaderMap) -> String {
    let v = h.get("x-org-id").and_then(|v| v.to_str().ok()).unwrap_or("").trim().to_string();
    if mc::is_uuid(&v) { v.to_lowercase() } else { String::new() }
}
fn attach_root() -> String {
    let v = crate::env_var("ATTACH_DIR");
    if v.starts_with('/') && v.len() > 1 { v.trim_end_matches('/').to_string() } else { "/mnt/anexomail-box/attachments".to_string() }
}
fn ip_of(h: &HeaderMap) -> Option<String> {
    let v = h.get("x-forwarded-for").and_then(|v| v.to_str().ok()).unwrap_or("");
    let first = v.split(',').next().unwrap_or("").trim();
    if first.is_empty() || first.len() > 64 { None } else { Some(first.to_string()) }
}
fn first(v: &Value) -> Option<&Value> {
    v.as_array().and_then(|a| a.first())
}

pub async fn dispatch(proc: &str, token: &str, input: &Value, headers: &HeaderMap) -> Resp {
    let me = match crate::mail_identity(token, &org_hdr(headers)).await {
        Ok(m) => m,
        // no workspace: Bun still serves a founder with no membership — 404 makes the client fall back to Bun for exactly that case.
        Err((StatusCode::CONFLICT, _, _)) if proc.starts_with("org.mailboxes") => return fail(StatusCode::NOT_FOUND, "no_org"),
        Err((s, c, m)) => return crate::err(s, c, &m).into_response(),
    };
    match proc {
        "org.mailboxes.list" => mailboxes_list(&me).await,
        "org.mailboxes.create" => mailboxes_create(&me, input, headers).await,
        "mail.send" => send(&me, input).await,
        "mail.schedule" => schedule(&me, input).await,
        "mail.schedule.cancel" => schedule_cancel(&me, input).await,
        _ => fail(StatusCode::NOT_IMPLEMENTED, "use_bun_fallback"),
    }
}

// ── plan / cap (org.ts workspacePlanOf + mailboxCap) ────────────────────────
async fn rows(q: &str) -> Vec<Value> {
    crate::sb_select(q).await.ok().and_then(|v| v.as_array().cloned()).unwrap_or_default()
}

async fn plan_of(org: &str, user: &str) -> String {
    for q in [
        format!("workspace_subscriptions?select=plan&org_id=eq.{org}&limit=1"),
        format!("workspace_subscriptions?select=plan&user_id=eq.{user}&limit=1"),
        format!("entitlement_state?select=plan&user_id=eq.{user}&limit=1"),
    ] {
        if let Some(p) = rows(&q).await.first().and_then(|r| r.get("plan")).and_then(|p| p.as_str()).filter(|p| !p.is_empty()) {
            return p.to_string();
        }
    }
    "basic".to_string()
}

/// None = unlimited.
async fn cap_of(plan: &str) -> Option<i64> {
    if !plan.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-') {
        return Some(0);
    }
    let s = rows(&format!("storage_plans?select=mailbox_limit&plan_id=eq.{plan}&limit=1")).await;
    if let Some(r) = s.first() {
        return r.get("mailbox_limit").and_then(|x| x.as_i64());
    }
    let w = rows(&format!("workspace_plans?select=mailboxes_included&id=eq.{plan}&limit=1")).await;
    w.first().and_then(|r| r.get("mailboxes_included")).and_then(|x| x.as_i64())
}

/// org.ts: `String(row.box_type || "mailbox") === "mailbox"` (null / "" count as a mailbox).
fn is_mailbox(r: &Value) -> bool {
    matches!(r.get("box_type").and_then(|x| x.as_str()).unwrap_or(""), "" | "mailbox")
}

async fn pg_delete(path_and_query: &str) -> Result<(), String> {
    let (url, key) = crate::sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let res = crate::http()
        .delete(format!("{url}/rest/v1/{path_and_query}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if res.status().is_success() { Ok(()) } else { Err(format!("delete {}", res.status())) }
}

async fn mailboxes_list(me: &crate::MailMe) -> Resp {
    let plan = plan_of(&me.org_id, &me.id).await;
    let limit = cap_of(&plan).await;
    let boxes = rows(&format!(
        "mailboxes?select=id,address,display_name,active,purpose,box_type&org_id=eq.{}&order=address",
        me.org_id
    ))
    .await;
    let used = boxes.iter().filter(|r| is_mailbox(r)).count() as i64;
    let remaining = limit.is_none_or(|l| used < l);
    crate::ok(json!({ "ok": true, "mailboxes": boxes, "plan": plan, "limit": limit, "used": used, "remaining": remaining })).into_response()
}

async fn writes_enabled() -> bool {
    match rows("org_switches?select=value&key=eq.org_writes_enabled&limit=1").await.first().and_then(|r| r.get("value")) {
        None => true,
        Some(Value::Bool(b)) => *b,
        Some(Value::String(s)) => s == "true",
        Some(v) => v.get("enabled").and_then(|x| x.as_bool()) == Some(true),
    }
}

async fn mailboxes_create(me: &crate::MailMe, input: &Value, headers: &HeaderMap) -> Resp {
    let role = rows(&format!("org_members?select=role&org_id=eq.{}&user_id=eq.{}&limit=1", me.org_id, me.id))
        .await
        .first()
        .and_then(|r| r.get("role"))
        .and_then(|r| r.as_str())
        .unwrap_or("")
        .to_string();
    if !(mc::role_may_create_mailbox(&role) || crate::is_founder(&me.id, &me.email).await) {
        return fail_with(StatusCode::FORBIDDEN, "forbidden", json!({ "needs": ["owner", "admin", "manager"] }));
    }
    if !writes_enabled().await {
        return fail(StatusCode::LOCKED, "org_writes_disabled");
    }
    let Some(address) = mc::mailbox_address(&st(input, "address")) else { return fail(StatusCode::BAD_REQUEST, "address_required") };
    let plan = plan_of(&me.org_id, &me.id).await;
    let limit = cap_of(&plan).await;
    let used = rows(&format!("mailboxes?select=id,box_type&org_id=eq.{}", me.org_id)).await.iter().filter(|r| is_mailbox(r)).count() as i64;
    if limit.is_some_and(|l| used >= l) {
        return fail_with(StatusCode::FORBIDDEN, "mailbox_limit", json!({ "plan": plan, "limit": limit, "used": used, "remaining": false }));
    }
    let local = address.split('@').next().unwrap_or(&address).to_string();
    let ins = crate::sb_insert(
        "mailboxes?select=id,address,display_name,active,purpose",
        json!({ "org_id": me.org_id, "address": address, "display_name": local, "box_type": "mailbox",
                "purpose": "User-created mailbox", "is_public": false, "active": true }),
    )
    .await;
    let row = match ins {
        Ok(v) => first(&v).cloned().unwrap_or(Value::Null),
        Err(e) => {
            let l = e.to_lowercase();
            if e.contains("23505") || l.contains("duplicate") || l.contains("unique") {
                return fail(StatusCode::CONFLICT, "address_taken");
            }
            eprintln!("[mail] mailbox insert: {}", e.chars().take(200).collect::<String>());
            return fail(StatusCode::INTERNAL_SERVER_ERROR, "mailbox_create_failed");
        }
    };
    let actor = if me.email.is_empty() { me.id.clone() } else { me.email.clone() };
    let _ = crate::sb_rpc(
        "org_chain_append",
        json!({ "p_actor": actor, "p_action": "mailbox.create", "p_target": address, "p_ip": ip_of(headers), "p_org": me.org_id }),
    )
    .await;
    crate::ok(json!({ "ok": true, "mailbox": row, "plan": plan, "remaining": limit.is_none_or(|l| used + 1 < l) })).into_response()
}

// NOTE: smtp_failed answers 424, never 502: the client falls back to Bun on 502 and would send the mail a second time.

// ── mail.send ───────────────────────────────────────────────────────────────
struct Staged {
    id: String,
    filename: String,
    mime: String,
    size: u64,
    sha: String,
    rel: String,
}

async fn stage(me: &crate::MailMe, ids: &[String]) -> Result<Vec<Staged>, Resp> {
    if ids.is_empty() {
        return Ok(vec![]);
    }
    let data = match crate::sb_rpc("mail_attach_stage_check", json!({ "_user": me.id, "_org": me.org_id, "_ids": ids })).await {
        Ok(d) => d,
        Err(e) => {
            eprintln!("[mail] stage_check: {}", e.chars().take(200).collect::<String>());
            return Err(fail(StatusCode::SERVICE_UNAVAILABLE, "attachments_unavailable"));
        }
    };
    if data.get("ok").and_then(|x| x.as_bool()) != Some(true) {
        let code = data.get("error").and_then(|x| x.as_str()).unwrap_or("attachments_unavailable").to_string();
        let status = match code.as_str() {
            "attachments_too_large" => StatusCode::PAYLOAD_TOO_LARGE,
            "account_blocked" => StatusCode::FORBIDDEN,
            "no_workspace" => StatusCode::CONFLICT,
            "unauthorized" => StatusCode::UNAUTHORIZED,
            _ => StatusCode::BAD_REQUEST,
        };
        let mut extra = serde_json::Map::new();
        for k in ["limit_bytes", "total_bytes", "limit"] {
            if let Some(v) = data.get(k) {
                extra.insert(k.to_string(), v.clone());
            }
        }
        return Err(fail_with(status, &code, Value::Object(extra)));
    }
    let mut out = vec![];
    for f in data.get("files").and_then(|f| f.as_array()).cloned().unwrap_or_default() {
        let s = Staged {
            id: st(&f, "id"),
            filename: st(&f, "filename"),
            mime: st(&f, "mime_type"),
            size: f.get("size_bytes").and_then(|x| x.as_u64()).unwrap_or(0),
            sha: st(&f, "sha256"),
            rel: st(&f, "rel_path"),
        };
        if !mc::rel_path_valid(&s.rel) {
            return Err(fail(StatusCode::INTERNAL_SERVER_ERROR, "attachment_path_invalid"));
        }
        out.push(s);
    }
    Ok(out)
}

async fn read_files(staged: &[Staged]) -> Result<Vec<mc::AttData>, String> {
    let root = attach_root();
    let mut out = vec![];
    for f in staged {
        let full = format!("{root}/{}", f.rel);
        let md = tokio::fs::metadata(&full).await.map_err(|_| format!("attachment_missing: {}", mc::clean_name(&f.filename)))?;
        if !md.is_file() || md.len() != f.size {
            return Err(format!("attachment_changed: {}", mc::clean_name(&f.filename)));
        }
        let data = tokio::fs::read(&full).await.map_err(|_| format!("attachment_missing: {}", mc::clean_name(&f.filename)))?;
        if data.len() as u64 != f.size {
            return Err(format!("attachment_changed: {}", mc::clean_name(&f.filename)));
        }
        let sum: String = Sha256::digest(&data).iter().map(|b| format!("{b:02x}")).collect();
        if !sum.eq_ignore_ascii_case(&f.sha) {
            return Err(format!("attachment_corrupt: {}", mc::clean_name(&f.filename)));
        }
        out.push(mc::AttData { filename: f.filename.clone(), mime: f.mime.clone(), data });
    }
    Ok(out)
}

fn uuid_v4() -> String {
    let mut b = [0u8; 16];
    // Message-ID/boundary need uniqueness, not secrecy: time + counter + address entropy through SHA-256.
    static CTR: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let n = CTR.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    let t = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    let x = Box::new(0u8);
    let seed = format!("{t}-{n}-{:p}-{}", &*x, std::process::id());
    b.copy_from_slice(&Sha256::digest(seed.as_bytes())[..16]);
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    let h: String = b.iter().map(|x| format!("{x:02x}")).collect();
    format!("{}-{}-{}-{}-{}", &h[0..8], &h[8..12], &h[12..16], &h[16..20], &h[20..32])
}

async fn send(me: &crate::MailMe, input: &Value) -> Resp {
    // ── recipients ──
    let (Ok(to_raw), Ok(cc_raw), Ok(bcc_raw)) = (addr_list(input, "to"), addr_list(input, "cc"), addr_list(input, "bcc")) else {
        return fail(StatusCode::BAD_REQUEST, "invalid_recipient");
    };
    let (to, cc, bcc) = match (mc::clean_addrs(&to_raw), mc::clean_addrs(&cc_raw), mc::clean_addrs(&bcc_raw)) {
        (Ok(a), Ok(b), Ok(c)) => (a, b, c),
        (Err(bad), _, _) | (_, Err(bad), _) | (_, _, Err(bad)) => {
            return fail_with(StatusCode::BAD_REQUEST, "invalid_recipient", json!({ "address": bad }));
        }
    };
    if to.is_empty() {
        return fail(StatusCode::BAD_REQUEST, "to_required");
    }
    if to.len() + cc.len() + bcc.len() > mc::MAX_RCPT {
        return fail(StatusCode::BAD_REQUEST, "too_many_recipients");
    }
    let reply_to = st(input, "reply_to");
    if !reply_to.is_empty() && !mc::valid_addr(reply_to.trim()) {
        return fail(StatusCode::BAD_REQUEST, "invalid_reply_to");
    }
    let subject = { let s = st(input, "subject"); if s.is_empty() { "(no subject)".to_string() } else { s } };
    if subject.len() > 998 {
        return fail(StatusCode::BAD_REQUEST, "subject_too_long");
    }
    let body = st(input, "body");
    let html = st(input, "html");
    let from_name = st(input, "from_name");
    if from_name.len() > 200 {
        return fail(StatusCode::BAD_REQUEST, "from_name_too_long");
    }

    // ── attachments (G38) ──
    let raw_ids: Vec<String> = match input.get("attachment_ids") {
        None | Some(Value::Null) => vec![],
        Some(Value::String(s)) if s.is_empty() => vec![],
        Some(Value::Array(a)) => {
            let mut v = vec![];
            for x in a {
                match x.as_str() {
                    Some(s) => v.push(s.to_string()),
                    None => return fail(StatusCode::BAD_REQUEST, "attachment_ids_invalid"),
                }
            }
            v
        }
        _ => return fail(StatusCode::BAD_REQUEST, "attachment_ids_invalid"),
    };
    let ids = match mc::normalise_ids(&raw_ids) {
        Ok(i) => i,
        Err(c) => return fail(StatusCode::BAD_REQUEST, c),
    };
    let staged = match stage(me, &ids).await {
        Ok(s) => s,
        Err(r) => return r,
    };
    let send_at = st(input, "send_at");
    let scheduled_unix = if send_at.is_empty() { None } else { mc::parse_iso(&send_at) };
    if !send_at.is_empty() && scheduled_unix.is_none() {
        return fail(StatusCode::BAD_REQUEST, "send_at_invalid");
    }
    let now = now_secs();
    let is_scheduled = scheduled_unix.is_some_and(|t| t > now);
    if !staged.is_empty() && is_scheduled {
        return fail(StatusCode::BAD_REQUEST, "use_schedule_for_attachments");
    }
    let files = match read_files(&staged).await {
        Ok(f) => f,
        Err(e) => return fail_with(StatusCode::CONFLICT, "attachment_unavailable", json!({ "detail": e.chars().take(200).collect::<String>() })),
    };

    // ── which mailbox sends: mailboxes -> mail_accounts -> own @anexomail.com (same order as Bun) ──
    let org = &me.org_id;
    let mut acc: Option<(String, String)> = None;
    for q in [
        format!("mailboxes?select=id,address&org_id=eq.{org}&order=address&limit=1"),
        format!("mail_accounts?select=id,address&org_id=eq.{org}&order=address&limit=1"),
    ] {
        if let Some(r) = rows(&q).await.first() {
            let (i, a) = (st(r, "id"), st(r, "address"));
            if !i.is_empty() && mc::valid_addr(&a) {
                acc = Some((i, a));
                break;
            }
        }
    }
    if acc.is_none() && me.email.to_lowercase().ends_with("@anexomail.com") && mc::valid_addr(&me.email) {
        acc = Some((me.id.clone(), me.email.to_lowercase()));
    }
    let Some((acc_id, acc_addr)) = acc else { return fail(StatusCode::CONFLICT, "no_mail_account") };

    // ── thread: an existing id must be THIS org's ──
    let when = scheduled_unix.filter(|_| is_scheduled).unwrap_or(now);
    let when_iso = crate::passkey_core::iso_utc(when.max(0) as u64);
    let given_thread = st(input, "thread_id");
    let (thread_id, created_thread) = if !given_thread.is_empty() {
        if !mc::is_uuid(&given_thread) {
            return fail(StatusCode::BAD_REQUEST, "thread_id_invalid");
        }
        let t = given_thread.to_lowercase();
        if rows(&format!("mail_threads?select=id&id=eq.{t}&org_id=eq.{org}&limit=1")).await.is_empty() {
            return fail(StatusCode::NOT_FOUND, "thread_not_found");
        }
        (t, false)
    } else {
        let snippet: String = body.chars().take(180).collect();
        match crate::sb_insert(
            "mail_threads?select=id",
            json!({ "org_id": org, "account_id": acc_id, "subject": subject, "snippet": snippet, "from_name": Value::Null,
                    "from_address": acc_addr, "folder": "sent", "status": "open", "unread": false, "message_count": 0, "last_message_at": when_iso }),
        )
        .await
        {
            Ok(v) => match first(&v).map(|r| st(r, "id")).filter(|i| !i.is_empty()) {
                Some(i) => (i, true),
                None => return fail(StatusCode::INTERNAL_SERVER_ERROR, "thread_create_failed"),
            },
            Err(e) => {
                eprintln!("[mail] thread insert: {}", e.chars().take(200).collect::<String>());
                return fail(StatusCode::INTERNAL_SERVER_ERROR, "thread_create_failed");
            }
        }
    };
    let undo = |msg: Option<String>| {
        let (t, c) = (thread_id.clone(), created_thread);
        let org = org.clone();
        async move {
            if let Some(m) = msg {
                let _ = pg_delete(&format!("mail_messages?id=eq.{m}&org_id=eq.{org}")).await;
            }
            if c {
                let _ = pg_delete(&format!("mail_threads?id=eq.{t}&org_id=eq.{org}")).await;
            }
        }
    };

    let msg_row = crate::sb_insert(
        "mail_messages?select=id",
        json!({ "org_id": org, "thread_id": thread_id, "direction": "out", "from_address": acc_addr, "to_addrs": to, "cc_addrs": cc,
                "bcc_addrs": bcc, "subject": if input.get("subject").and_then(|s| s.as_str()).unwrap_or("").is_empty() { Value::Null } else { json!(subject) },
                "body_text": if body.is_empty() { Value::Null } else { json!(body) }, "sent_at": when_iso,
                "scheduled_at": if is_scheduled { json!(when_iso) } else { Value::Null } }),
    )
    .await;
    let msg_id = match msg_row.ok().as_ref().and_then(first).map(|r| st(r, "id")).filter(|i| !i.is_empty()) {
        Some(i) => i,
        None => {
            undo(None).await;
            return fail(StatusCode::INTERNAL_SERVER_ERROR, "message_create_failed");
        }
    };
    let count = crate::sb_count(&format!("mail_messages?select=id&thread_id=eq.{thread_id}&org_id=eq.{org}")).await.unwrap_or(1).max(1);
    let _ = crate::sb_patch(
        &format!("mail_threads?id=eq.{thread_id}&org_id=eq.{org}"),
        json!({ "message_count": count, "last_message_at": when_iso }),
    )
    .await;

    if is_scheduled {
        return crate::ok(json!({ "ok": true, "scheduled_at": when_iso, "thread_id": thread_id, "message_id": msg_id })).into_response();
    }

    // ── build + submit ──
    let message_id = format!("{}@{}", uuid_v4(), mc::DOMAIN);
    let date = mc::rfc_date(now);
    let boundary = format!("ax_{}", uuid_v4().replace('-', ""));
    let m = mc::Msg {
        from: &acc_addr,
        from_name: Some(from_name.as_str()).filter(|n| !n.is_empty()),
        to: &to,
        cc: &cc,
        reply_to: Some(reply_to.trim()).filter(|r| !r.is_empty()),
        subject: &subject,
        text: &body,
        html: Some(html.as_str()).filter(|h| !h.is_empty()),
        message_id: &message_id,
        date: &date,
        boundary: &boundary,
    };
    let built = mc::wrap_with_attachments(
        &mc::build_message(&m),
        &files,
        &format!("mx_{}", uuid_v4().replace('-', "")),
    );
    let all: Vec<String> = to.iter().chain(cc.iter()).chain(bcc.iter()).cloned().collect();
    let rcpts: Vec<String> = all.iter().map(|r| r.to_lowercase()).collect();
    let (ok_send, smtp_resp, error) = match built {
        Err(e) => (false, String::new(), e.to_string()),
        Ok(data) => {
            let host = { let h = crate::env_var("MAIL_SMTP_HOST"); if h.is_empty() { "127.0.0.1".to_string() } else { h } };
            let port = crate::env_var("MAIL_SMTP_PORT").parse::<u16>().unwrap_or(25);
            let env_from = acc_addr.to_lowercase();
            match tokio::task::spawn_blocking(move || mc::smtp_send(&host, port, &env_from, &rcpts, &data)).await {
                Ok(Ok(r)) => (true, r, String::new()),
                Ok(Err(e)) => (false, String::new(), e),
                Err(e) => (false, String::new(), format!("smtp task: {e}")),
            }
        }
    };
    // delivery proof (mail_outbox_log) — optional, never blocks the answer
    let _ = crate::sb_rpc(
        "mail_outbox_record",
        json!({ "payload": { "from_address": acc_addr, "to": all, "subject": subject, "message_id": message_id,
                              "smtp_response": smtp_resp, "ok": ok_send, "error": if error.is_empty() { Value::Null } else { json!(error) } } }),
    )
    .await;
    if !ok_send {
        undo(Some(msg_id)).await;
        if !created_thread {
            let c = crate::sb_count(&format!("mail_messages?select=id&thread_id=eq.{thread_id}&org_id=eq.{org}")).await.unwrap_or(0);
            let _ = crate::sb_patch(&format!("mail_threads?id=eq.{thread_id}&org_id=eq.{org}"), json!({ "message_count": c })).await;
        }
        return fail_with(StatusCode::FAILED_DEPENDENCY, "smtp_failed", json!({ "detail": error.chars().take(300).collect::<String>() }));
    }
    if !staged.is_empty() {
        let ids: Vec<&str> = staged.iter().map(|s| s.id.as_str()).collect();
        match crate::sb_rpc("mail_attach_commit", json!({ "_user": me.id, "_org": org, "_ids": ids, "_message": msg_id })).await {
            Ok(d) if d.get("ok").and_then(|x| x.as_bool()) == Some(true) => {}
            other => eprintln!("[mail] attach commit failed: {:?}", other.map(|d| d.to_string().chars().take(120).collect::<String>())),
        }
    }
    crate::ok(json!({ "ok": true, "thread_id": thread_id, "message_id": msg_id, "message_id_smtp": message_id })).into_response()
}

// ── hold / undo-send queue (mail-compose.ts /schedule + /schedule/:id/cancel) ───────────────────────────────────────────
async fn user_email(id: &str) -> String {
    if !mc::is_uuid(id) {
        return String::new();
    }
    let Some((url, key)) = crate::sb() else { return String::new() };
    let r = crate::http()
        .get(format!("{url}/auth/v1/admin/users/{id}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await;
    match r {
        Ok(x) if x.status().is_success() => x.json::<Value>().await.ok().map(|v| st(&v, "email").trim().to_lowercase()).unwrap_or_default(),
        _ => String::new(),
    }
}

/// identity.ts allowedSenderAddresses(): org mailboxes + mail_accounts + org_addresses (never alias / inactive) + the user's own @anexomail.com.
async fn allowed_senders(org: &str, user: &str) -> Vec<String> {
    let mut v: Vec<(String, Option<String>, Option<bool>)> = Vec::new();
    for (q, kind_col) in [
        (format!("mailboxes?select=address,box_type,active&org_id=eq.{org}"), "box_type"),
        (format!("mail_accounts?select=address&org_id=eq.{org}"), ""),
        (format!("org_addresses?select=address,kind,active&org_id=eq.{org}"), "kind"),
    ] {
        for r in rows(&q).await {
            v.push((st(&r, "address"), if kind_col.is_empty() { None } else { r.get(kind_col).and_then(|x| x.as_str()).map(|s| s.to_string()) }, r.get("active").and_then(|x| x.as_bool())));
        }
    }
    let mut out = mc::sendable_from(&v);
    let own = user_email(user).await;
    if own.ends_with("@anexomail.com") && !out.contains(&own) {
        out.push(own);
    }
    out
}

async fn schedule(me: &crate::MailMe, input: &Value) -> Resp {
    let hold = input.get("hold_seconds").and_then(|x| x.as_f64()).unwrap_or(10.0);
    let hold = if hold.is_finite() { hold.clamp(0.0, 120.0) as i64 } else { 10 };
    let now = now_secs();
    let send_unix = match input.get("send_at").and_then(|x| x.as_str()).filter(|s| !s.is_empty()) {
        Some(s) => match mc::parse_iso(s) {
            Some(t) => t,
            None => return fail(StatusCode::BAD_REQUEST, "send_at_invalid"),
        },
        None => now + hold,
    };
    let send_iso = crate::passkey_core::iso_utc(send_unix.max(0) as u64);

    let wanted = st(input, "identity").trim().to_lowercase();
    if !wanted.is_empty() && !(mc::valid_addr(&wanted) && allowed_senders(&me.org_id, &me.id).await.contains(&wanted)) {
        return fail_with(StatusCode::FORBIDDEN, "identity_not_allowed", json!({ "identity": wanted.chars().take(120).collect::<String>() }));
    }
    let (Ok(to_raw), Ok(cc_raw), Ok(bcc_raw)) = (addr_list(input, "to"), addr_list(input, "cc"), addr_list(input, "bcc")) else {
        return fail(StatusCode::BAD_REQUEST, "invalid_recipient");
    };
    let (to, cc, bcc) = match (mc::clean_addrs(&to_raw), mc::clean_addrs(&cc_raw), mc::clean_addrs(&bcc_raw)) {
        (Ok(a), Ok(b), Ok(c)) => (a, b, c),
        (Err(bad), _, _) | (_, Err(bad), _) | (_, _, Err(bad)) => return fail_with(StatusCode::BAD_REQUEST, "invalid_recipient", json!({ "address": bad })),
    };
    if to.is_empty() {
        return fail(StatusCode::BAD_REQUEST, "to_required");
    }
    if to.len() + cc.len() + bcc.len() > mc::MAX_RCPT {
        return fail(StatusCode::BAD_REQUEST, "too_many_recipients");
    }
    let subject = st(input, "subject");
    if subject.len() > 998 {
        return fail(StatusCode::BAD_REQUEST, "subject_too_long");
    }
    let raw_ids: Vec<String> = match input.get("attachment_ids") {
        None | Some(Value::Null) => vec![],
        Some(Value::Array(a)) => {
            let mut v = vec![];
            for x in a {
                match x.as_str() {
                    Some(s) => v.push(s.to_string()),
                    None => return fail(StatusCode::BAD_REQUEST, "attachment_ids_invalid"),
                }
            }
            v
        }
        _ => return fail(StatusCode::BAD_REQUEST, "attachment_ids_invalid"),
    };
    let ids = match mc::normalise_ids(&raw_ids) {
        Ok(i) => i,
        Err(c) => return fail(StatusCode::BAD_REQUEST, c),
    };
    let staged = match stage(me, &ids).await {
        Ok(s) => s,
        Err(r) => return r,
    };
    let thread = st(input, "thread_id");
    let thread_v = if thread.is_empty() {
        Value::Null
    } else {
        if !mc::is_uuid(&thread) {
            return fail(StatusCode::BAD_REQUEST, "thread_id_invalid");
        }
        let t = thread.to_lowercase();
        if rows(&format!("mail_threads?select=id&id=eq.{t}&org_id=eq.{}&limit=1", me.org_id)).await.is_empty() {
            return fail(StatusCode::NOT_FOUND, "thread_not_found");
        }
        json!(t)
    };
    let body = st(input, "body");
    let ins = crate::sb_insert(
        "mail_scheduled?select=id,status",
        json!({ "org_id": me.org_id, "user_id": me.id, "thread_id": thread_v,
                "identity": if wanted.is_empty() { Value::Null } else { json!(wanted) },
                "to": to.join(", "), "cc": if cc.is_empty() { Value::Null } else { json!(cc.join(", ")) },
                "bcc": if bcc.is_empty() { Value::Null } else { json!(bcc.join(", ")) },
                "subject": if subject.is_empty() { Value::Null } else { json!(subject) },
                "body": if body.is_empty() { Value::Null } else { json!(body) },
                "status": "holding",
                "attachment_ids": if staged.is_empty() { Value::Null } else { json!(staged.iter().map(|s| s.id.clone()).collect::<Vec<_>>()) },
                "send_at": send_iso }),
    )
    .await;
    match ins.ok().as_ref().and_then(first) {
        Some(r) => crate::ok(json!({ "id": st(r, "id"), "status": st(r, "status") })).into_response(),
        None => fail(StatusCode::INTERNAL_SERVER_ERROR, "schedule_failed"),
    }
}

async fn schedule_cancel(me: &crate::MailMe, input: &Value) -> Resp {
    let id = st(input, "id");
    if !mc::is_uuid(&id) {
        return fail(StatusCode::BAD_REQUEST, "id_invalid");
    }
    match crate::sb_rpc("mail_queue_cancel", json!({ "_id": id.to_lowercase(), "_user": me.id, "_org": me.org_id })).await {
        Ok(Value::Bool(true)) => crate::ok(json!({ "ok": true })).into_response(),
        Ok(_) => fail(StatusCode::CONFLICT, "already_sent"),
        Err(e) => {
            eprintln!("[mail] cancel: {}", e.chars().take(200).collect::<String>());
            fail(StatusCode::SERVICE_UNAVAILABLE, "queue_unavailable")
        }
    }
}

// ── queue worker (mail-worker.ts, ported) ───────────────────────────────────────────────────────────────────────────────
static BUSY: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// Spawned once from main(). MAIL_WORKER=off turns it off. Bun's worker keeps running as a standby: both claim rows through
/// `mail_queue_claim` (E54), so a row is never sent twice, and if this engine is down the Bun worker still delivers.
pub async fn start_worker() {
    if crate::env_var("MAIL_WORKER").eq_ignore_ascii_case("off") {
        eprintln!("[mail-worker] Rust worker OFF (MAIL_WORKER=off)");
        return;
    }
    eprintln!("[mail-worker] Rust worker started, polling every 5 s (claim via mail_queue_claim)");
    loop {
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        if crate::sb().is_none() || BUSY.swap(true, std::sync::atomic::Ordering::SeqCst) {
            continue;
        }
        // own task: a panic inside one mail never kills the loop
        let _ = tokio::spawn(async {
            tick().await;
            BUSY.store(false, std::sync::atomic::Ordering::SeqCst);
        })
        .await;
        BUSY.store(false, std::sync::atomic::Ordering::SeqCst);
    }
}

async fn tick() {
    let _ = crate::sb_rpc("mail_queue_release", json!({})).await;
    let claimed = match crate::sb_rpc("mail_queue_claim", json!({ "_limit": 20, "_stale_minutes": 10 })).await {
        Ok(v) => v.as_array().cloned().unwrap_or_default(),
        Err(e) => {
            if !e.contains("mail_queue_claim") {
                eprintln!("[mail-worker] claim failed: {}", e.chars().take(160).collect::<String>());
            }
            return;
        }
    };
    for row in claimed {
        process_row(&row).await;
    }
}

async fn mark(id: &str, status: &str, error: Option<&str>) {
    let mut b = json!({ "status": status });
    if status == "sent" {
        b["sent_at"] = json!(crate::passkey_core::iso_utc(now_secs().max(0) as u64));
    }
    if let Some(e) = error {
        b["error"] = json!(e.chars().take(300).collect::<String>());
    }
    if let Err(e) = crate::sb_patch(&format!("mail_scheduled?id=eq.{id}"), b).await {
        eprintln!("[mail-worker] status update failed id={id}: {}", e.chars().take(120).collect::<String>());
    }
}

async fn storage_release(ws: &Option<String>, mailbox: &str, bytes: i64) {
    if let Some(w) = ws {
        let _ = crate::sb_rpc("storage_release", json!({ "_workspace": w, "_mailbox": mailbox, "_bytes": bytes, "_kind": "email" })).await;
    }
}

fn list_of(v: &Value, k: &str) -> Vec<String> {
    mc::split_commas(v.get(k).and_then(|x| x.as_str()).unwrap_or(""))
}

async fn process_row(row: &Value) {
    let id = st(row, "id");
    if !mc::is_uuid(&id) {
        return;
    }
    let org = st(row, "org_id");
    let user = st(row, "user_id");
    let to = match mc::clean_addrs(&list_of(row, "to")) {
        Ok(v) if !v.is_empty() => v,
        Ok(_) => return mark(&id, "failed", Some("no recipients")).await,
        Err(_) => return mark(&id, "failed", Some("invalid recipient")).await,
    };
    let (Ok(cc), Ok(bcc)) = (mc::clean_addrs(&list_of(row, "cc")), mc::clean_addrs(&list_of(row, "bcc"))) else {
        return mark(&id, "failed", Some("invalid recipient")).await;
    };
    let me = crate::MailMe { id: user.clone(), email: String::new(), org_id: org.clone() };

    // ── From: identity (re-checked) -> own mailbox -> user's auth email -> default ──
    let mut from = st(row, "identity").trim().to_lowercase();
    if !from.is_empty() {
        if user.is_empty() || !allowed_senders(&org, &user).await.contains(&from) {
            eprintln!("[mail-worker] IDENTITY REJECTED id={id}");
            return mark(&id, "failed", Some("identity_not_allowed")).await;
        }
    } else if !user.is_empty() && mc::is_uuid(&user) && mc::is_uuid(&org) {
        if let Some(a) = rows(&format!("mailboxes?select=address&org_id=eq.{org}&account_id=eq.{user}&limit=1")).await.first().map(|r| st(r, "address")) {
            from = a.trim().to_lowercase();
        }
        if from.is_empty() {
            from = user_email(&user).await;
        }
    }
    if !mc::valid_addr(&from) {
        from = "hello@anexomail.com".to_string();
    }
    let subject = { let s = st(row, "subject"); if s.is_empty() { "(no subject)".to_string() } else { s } };
    let body = st(row, "body");
    let bytes = mc::estimate_bytes(&subject, &body);

    // ── storage preflight + reserve (same RPCs as /api/storage/preflight) ──
    let mut ws: Option<String> = None;
    if mc::is_uuid(&user) {
        let name = from.split('@').nth(1).filter(|d| !d.is_empty()).unwrap_or("Workspace").to_string();
        ws = crate::sb_rpc("chat_ensure_workspace", json!({ "_user": user, "_name": name })).await.ok().and_then(|v| v.as_str().map(|s| s.to_string()));
    }
    if let Some(w) = &ws {
        let r = crate::sb_rpc("storage_reserve", json!({ "_workspace": w, "_mailbox": from, "_bytes": bytes, "_kind": "email" })).await;
        let allowed = r.as_ref().ok().and_then(|v| v.get("allowed")).and_then(|x| x.as_bool()).unwrap_or(false);
        if !allowed {
            let why = r.as_ref().ok().and_then(|v| v.get("reason")).and_then(|x| x.as_str()).map(|s| s.to_string()).unwrap_or_else(|| "storage_limit_exceeded".to_string());
            eprintln!("[mail-worker] STORAGE REJECTED id={id}");
            return mark(&id, "failed", Some(&why)).await;
        }
    }

    // ── attachments: re-check (a file may have changed after scheduling) ──
    let att_ids: Vec<String> = row.get("attachment_ids").and_then(|a| a.as_array()).map(|a| a.iter().filter_map(|x| x.as_str().map(|s| s.to_string())).collect()).unwrap_or_default();
    let mut files: Vec<mc::AttData> = vec![];
    let mut staged: Vec<Staged> = vec![];
    if !att_ids.is_empty() {
        let res = async {
            staged = stage(&me, &att_ids).await.map_err(|_| "attachment check failed".to_string())?;
            files = read_files(&staged).await?;
            Ok::<(), String>(())
        }
        .await;
        if let Err(e) = res {
            storage_release(&ws, &from, bytes).await;
            eprintln!("[mail-worker] ATTACHMENTS REJECTED id={id}: {e}");
            return mark(&id, "failed", Some(&format!("attachments: {e}"))).await;
        }
    }

    // ── build + send ──
    let message_id = format!("{}@{}", uuid_v4(), mc::DOMAIN);
    let date = mc::rfc_date(now_secs());
    let boundary = format!("ax_{}", uuid_v4().replace('-', ""));
    let m = mc::Msg { from: &from, from_name: None, to: &to, cc: &cc, reply_to: None, subject: &subject, text: &body, html: None,
                      message_id: &message_id, date: &date, boundary: &boundary };
    let built = mc::wrap_with_attachments(&mc::build_message(&m), &files, &format!("mx_{}", uuid_v4().replace('-', "")));
    let all: Vec<String> = to.iter().chain(cc.iter()).chain(bcc.iter()).cloned().collect();
    let rcpts: Vec<String> = all.iter().map(|r| r.to_lowercase()).collect();
    let (sent, smtp_resp, error) = match built {
        Err(e) => (false, String::new(), e.to_string()),
        Ok(data) => {
            let host = { let h = crate::env_var("MAIL_SMTP_HOST"); if h.is_empty() { "127.0.0.1".to_string() } else { h } };
            let port = crate::env_var("MAIL_SMTP_PORT").parse::<u16>().unwrap_or(25);
            let env_from = from.clone();
            match tokio::task::spawn_blocking(move || mc::smtp_send(&host, port, &env_from, &rcpts, &data)).await {
                Ok(Ok(r)) => (true, r, String::new()),
                Ok(Err(e)) => (false, String::new(), e),
                Err(e) => (false, String::new(), format!("smtp task: {e}")),
            }
        }
    };
    let _ = crate::sb_rpc(
        "mail_outbox_record",
        json!({ "payload": { "from_address": from, "to": all, "subject": subject, "message_id": message_id, "smtp_response": smtp_resp,
                              "ok": sent, "error": if error.is_empty() { Value::Null } else { json!(error) } } }),
    )
    .await;
    if !sent {
        mark(&id, "failed", Some(if error.is_empty() { "unknown send error" } else { &error })).await;
        storage_release(&ws, &from, bytes).await;
        eprintln!("[mail-worker] FAILED id={id}: {}", error.chars().take(160).collect::<String>());
        return;
    }
    mark(&id, "sent", None).await;
    record_sent(row, &from, &to, &cc, &bcc, &subject, &body, &staged).await;
    if let Some(w) = &ws {
        let _ = crate::sb_rpc("storage_commit", json!({ "_workspace": w, "_mailbox": from, "_bytes": bytes, "_kind": "email", "_was_reserved": true })).await;
    }
    eprintln!("[mail-worker] sent id={id}");
}

/// Sent-folder copy (thread + message, both address column spellings like the Bun worker) + attachment rows.
async fn record_sent(row: &Value, from: &str, to: &[String], cc: &[String], bcc: &[String], subject: &str, body: &str, staged: &[Staged]) {
    let org = st(row, "org_id");
    let user = st(row, "user_id");
    let now_iso = crate::passkey_core::iso_utc(now_secs().max(0) as u64);
    let mut acct: Option<String> = None;
    for t in ["mail_accounts", "mailboxes"] {
        if let Some(r) = rows(&format!("{t}?select=id&org_id=eq.{org}&address=ilike.{}&limit=1", mc::ilike_exact(from))).await.first() {
            acct = Some(st(r, "id"));
            break;
        }
    }
    if acct.is_none() {
        for t in ["mail_accounts", "mailboxes"] {
            if let Some(r) = rows(&format!("{t}?select=id&org_id=eq.{org}&order=address&limit=1")).await.first() {
                acct = Some(st(r, "id"));
                break;
            }
        }
    }
    let snippet: String = body.chars().take(180).collect();
    let th = crate::sb_insert(
        "mail_threads?select=id",
        json!({ "org_id": org, "account_id": acct, "subject": subject, "snippet": snippet, "from_name": Value::Null, "from_address": from,
                "mailbox_address": from, "folder": "sent", "status": "open", "unread": false, "message_count": 1, "last_message_at": now_iso }),
    )
    .await;
    let Some(tid) = th.ok().as_ref().and_then(first).map(|r| st(r, "id")).filter(|i| !i.is_empty()) else {
        eprintln!("[mail-worker] sent-thread failed");
        return;
    };
    let msg = crate::sb_insert(
        "mail_messages?select=id",
        json!({ "org_id": org, "thread_id": tid, "direction": "out", "from_address": from,
                "to_addresses": to, "cc_addresses": cc, "bcc_addresses": bcc, "to_addrs": to, "cc_addrs": cc, "bcc_addrs": bcc,
                "subject": subject, "body_text": body, "sent_at": now_iso }),
    )
    .await;
    match msg.ok().as_ref().and_then(first).map(|r| st(r, "id")).filter(|i| !i.is_empty()) {
        None => eprintln!("[mail-worker] sent-message failed"),
        Some(mid) => {
            if !staged.is_empty() {
                let ids: Vec<&str> = staged.iter().map(|s| s.id.as_str()).collect();
                let _ = crate::sb_rpc("mail_attach_commit", json!({ "_user": user, "_org": org, "_ids": ids, "_message": mid })).await;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn owns_only_b3_procs() {
        assert!(owns("mail.send") && owns("mail.schedule") && owns("mail.schedule.cancel") && owns("org.mailboxes.list") && owns("org.mailboxes.create"));
        assert!(!owns("mail.addresses.remove") && !owns("auth.passkey.list"));
    }

    #[test]
    fn address_lists_are_strict() {
        let v = json!({ "to": "a@b.com, c@d.org", "cc": ["x@y.com", "", null], "bcc": [5] , "z": 1 });
        assert_eq!(addr_list(&v, "to").unwrap(), vec!["a@b.com", "c@d.org"]);
        assert_eq!(addr_list(&v, "cc").unwrap(), vec!["x@y.com"]);
        assert!(addr_list(&v, "bcc").is_err());
        assert!(addr_list(&v, "z").is_err());
        assert!(addr_list(&v, "none").unwrap().is_empty());
    }

    #[test]
    fn uuids_are_unique_and_v4() {
        let a = uuid_v4();
        let b = uuid_v4();
        assert_ne!(a, b);
        assert!(mc::is_uuid(&a));
        assert_eq!(&a[14..15], "4");
    }

    #[test]
    fn org_header_must_be_uuid() {
        let mut h = HeaderMap::new();
        h.insert("x-org-id", "0b9a1c52-1111-4222-8333-444455556666".parse().unwrap());
        assert_eq!(org_hdr(&h), "0b9a1c52-1111-4222-8333-444455556666");
        h.insert("x-org-id", "x&org_id=neq.0".parse().unwrap());
        assert_eq!(org_hdr(&h), "");
    }

    #[test]
    fn mailbox_flag() {
        assert!(is_mailbox(&json!({ "box_type": "mailbox" })) && is_mailbox(&json!({})));
        assert!(!is_mailbox(&json!({ "box_type": "alias" })) && !is_mailbox(&json!({ "box_type": "shared" })));
    }
}
