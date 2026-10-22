// ============================================================================
// calfile_glue.rs — #5: meeting par FILES. Rust PRIMARY. SQL: docs/cursor-work/sql/E74_calendar_event_files.sql
//
//   calendar.files.list   {event_id, org_id?}                    -> {files:[{id,filename,mime_type,size_bytes,created_at,can_remove,scanned}], can_add, max_files}
//   calendar.files.attach {event_id, attachment_id, org_id?}     -> {id, filename, size_bytes}      (attachment_id = POST /file/attach ka jawab; wohi upload pipeline)
//   calendar.files.remove {event_id, id, org_id?}                -> {removed}
//   Download: GET /file/attach/get?id=<file id>  (mojooda route; E74 ka mail_attach_resolve meeting ki file bhi pehchanta hai)
//
// Naya storage/scan/quota nahi — sab mail attachments wala (attach_glue). Yahan sirf "kaun si file kis meeting par" aur ijazat (SQL _cal_file_gate).
// Org: mail_attach_ctx se (user ka asli, revoked nahi wala member org) — client ka org_id sirf hint hai, SQL dobara member-check karta hai.
// ============================================================================

use crate::calfile_core as cf;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(proc, "calendar.files.list" | "calendar.files.attach" | "calendar.files.remove")
}

fn fail_code(code: &str) -> Resp {
    let (s, m) = cf::error_text(code);
    let body = json!({ "error": { "code": code, "message": m } });
    (StatusCode::from_u16(s).unwrap_or(StatusCode::BAD_REQUEST), axum::Json(body)).into_response()
}

fn db_err(e: &str) -> Resp {
    // E74 chali nahi: function nahi milta
    if e.contains("cal_file_") && (e.contains("does not exist") || e.contains("Could not find") || e.contains("PGRST202") || e.contains("42883")) {
        return fail_code("sql_missing");
    }
    crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e.chars().take(300).collect::<String>()).into_response()
}

fn okv(v: &Value) -> bool {
    v.get("ok").and_then(|x| x.as_bool()) == Some(true)
}

fn sv<'a>(v: &'a Value, k: &str) -> &'a str {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("")
}

fn sql_fail(v: &Value) -> Resp {
    let code = sv(v, "error");
    fail_code(if code.is_empty() { "bad_input" } else { code })
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let (uid, _email) = match crate::auth_user(token).await {
        Some(x) => x,
        None => return crate::err(StatusCode::UNAUTHORIZED, "unauthorized", "").into_response(),
    };
    let event = match cf::event_uuid(sv(input, "event_id")) {
        Some(e) => e,
        None => return fail_code("bad_id"),
    };
    let hint = input.get("org_id").and_then(|v| v.as_str()).filter(|s| cf::valid_uuid(s));
    let ctx = match crate::sb_rpc("mail_attach_ctx", json!({ "_user": uid, "_org": hint })).await {
        Ok(v) => v,
        Err(e) => return db_err(&e),
    };
    if !okv(&ctx) {
        return sql_fail(&ctx);
    }
    let org = sv(&ctx, "org_id").to_string();
    if !cf::valid_uuid(&org) {
        return fail_code("no_workspace");
    }
    match proc {
        "calendar.files.list" => match crate::sb_rpc("cal_file_list", json!({ "_user": uid, "_org": org, "_event": event })).await {
            Ok(v) if okv(&v) => crate::ok(json!({ "files": v["files"], "can_add": v["can_add"], "max_files": v["max_files"] })).into_response(),
            Ok(v) => sql_fail(&v),
            Err(e) => db_err(&e),
        },
        "calendar.files.attach" => {
            let staged = sv(input, "attachment_id");
            if !cf::valid_uuid(staged) {
                return fail_code("bad_id");
            }
            match crate::sb_rpc("cal_file_attach", json!({ "_user": uid, "_org": org, "_event": event, "_staged": staged })).await {
                Ok(v) if okv(&v) => crate::ok(json!({ "id": v["id"], "filename": v["filename"], "size_bytes": v["size_bytes"] })).into_response(),
                Ok(v) => sql_fail(&v),
                Err(e) => db_err(&e),
            }
        }
        "calendar.files.remove" => {
            let id = sv(input, "id");
            if !cf::valid_uuid(id) {
                return fail_code("bad_id");
            }
            match crate::sb_rpc("cal_file_remove", json!({ "_user": uid, "_org": org, "_event": event, "_id": id })).await {
                Ok(v) if okv(&v) => crate::ok(json!({ "removed": v["removed"] })).into_response(),
                Ok(v) => sql_fail(&v),
                Err(e) => db_err(&e),
            }
        }
        _ => crate::err(StatusCode::NOT_FOUND, "unknown_proc", "").into_response(),
    }
}
