// ============================================================================
// calexp_glue — calendar.export: apna poora calendar (.ics ya json) nikalna. Sab plans (Basic bhi): ownership pillar, lock-in nahi.
//   calendar.export {format?: "ics"|"json"} -> ics: {filename, content_type, body}   json: {events:[...]}
// Rule 52: browser -> WASM kernel -> /wt/rpc ya /rpc; Bun GET /api/calendar/export sirf fallback. Hisaab calexp_core.rs (std-only, tested).
// ============================================================================

use crate::calexp_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::owns_name(proc)
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn opt(v: &Value, k: &str) -> Option<String> {
    v.get(k).and_then(|x| x.as_str()).map(|s| s.to_string()).filter(|s| !s.is_empty())
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    if !owns(proc) {
        return crate::err(StatusCode::NOT_FOUND, "unknown_proc", proc).into_response();
    }
    let me = match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(m) => m,
        Err((s, code, m)) => return crate::err(s, code, &m).into_response(),
    };
    let Some(format) = c::format_of(&st(input, "format")) else {
        return crate::err(StatusCode::BAD_REQUEST, "bad_format", "format must be ics or json").into_response();
    };
    let scope = if me.org_id.is_empty() { format!("created_by=eq.{}", enc(&me.id)) } else { format!("org_id=eq.{}", enc(&me.org_id)) };
    let q = format!("calendar_events?select=*&{scope}&order=starts_at.asc&limit=20000");
    let rows = match crate::sb_select(&q).await {
        Ok(v) => v.as_array().cloned().unwrap_or_default(),
        Err(_) => return crate::err(StatusCode::BAD_GATEWAY, "db_unavailable", "Calendar could not be read").into_response(),
    };
    if format == "json" {
        return crate::ok(json!({ "events": rows })).into_response();
    }
    let events: Vec<c::Ev> = rows
        .iter()
        .filter_map(|e| {
            let s = crate::cal_core::parse_ts(&st(e, "starts_at"))?;
            let en = crate::cal_core::parse_ts(&st(e, "ends_at")).unwrap_or(s);
            Some(c::Ev { id: st(e, "id"), title: st(e, "title"), agenda: opt(e, "agenda"), location: opt(e, "location"), starts: s, ends: en })
        })
        .collect();
    crate::ok(json!({
        "filename": "anexomail.ics",
        "content_type": "text/calendar; charset=utf-8",
        "count": events.len(),
        "body": c::build_ics(&events),
    }))
    .into_response()
}
