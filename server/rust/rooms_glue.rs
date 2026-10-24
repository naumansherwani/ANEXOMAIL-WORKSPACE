// ============================================================================
// rooms_glue.rs — #8 Rooms. Rust PRIMARY. SQL: docs/cursor-work/sql/E82_calendar_rooms.sql
//
//   calendar.rooms.list     {org_id?}                                   -> {rooms:[{id,name,kind,capacity,location,address}], can_manage}
//   calendar.rooms.create   {name, kind?, capacity?, location?}         -> {id, address, name}          (owner/admin)
//   calendar.rooms.archive  {id}                                        -> {archived}                   (owner/admin)
//   calendar.rooms.state    {from, to, exclude_event?}                  -> {rooms:[... , busy]}
//   calendar.rooms.book     {event_id, room_id}                         -> {booked, room, over_capacity}
//   calendar.rooms.release  {event_id, room_id}                         -> {released}
//   calendar.rooms.schedule {room_id, from, to}                         -> {slots:[{starts_at,ends_at,organiser}]}   (sirf waqt, title kabhi nahi)
// Org: mail_attach_ctx se (user ka asli member org). Client ka org_id sirf hint; SQL dobara member-check karta hai.
// ============================================================================

use crate::rooms_core as rc;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "calendar.rooms.list" | "calendar.rooms.create" | "calendar.rooms.archive" | "calendar.rooms.state" | "calendar.rooms.book" | "calendar.rooms.release" | "calendar.rooms.schedule"
    )
}

fn fail_code(code: &str) -> Resp {
    let (s, m) = rc::error_text(code);
    (StatusCode::from_u16(s).unwrap_or(StatusCode::BAD_REQUEST), axum::Json(json!({ "error": { "code": code, "message": m } }))).into_response()
}

fn db_err(e: &str) -> Resp {
    if e.contains("calendar_room_") && (e.contains("does not exist") || e.contains("Could not find") || e.contains("PGRST202") || e.contains("42883")) {
        return fail_code("sql_missing");
    }
    crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e.chars().take(300).collect::<String>()).into_response()
}

fn sv<'a>(v: &'a Value, k: &str) -> &'a str {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("")
}

/// SQL jawab: {"error":"..."} ho to saaf error, warna Ok(v).
fn checked(v: Value) -> Result<Value, Resp> {
    match v.get("error").and_then(|x| x.as_str()) {
        Some(c) => Err(fail_code(c)),
        None => Ok(v),
    }
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let (uid, _email) = match crate::auth_user(token).await {
        Some(x) => x,
        None => return crate::err(StatusCode::UNAUTHORIZED, "unauthorized", "").into_response(),
    };
    let hint = input.get("org_id").and_then(|v| v.as_str()).filter(|s| rc::valid_uuid(s));
    let ctx = match crate::sb_rpc("mail_attach_ctx", json!({ "_user": uid, "_org": hint })).await {
        Ok(v) => v,
        Err(e) => return db_err(&e),
    };
    let org = sv(&ctx, "org_id").to_string();
    if ctx.get("ok").and_then(|x| x.as_bool()) != Some(true) || !rc::valid_uuid(&org) {
        return fail_code("no_workspace");
    }
    let res: Result<Value, String> = match proc {
        "calendar.rooms.list" => {
            let l = crate::sb_rpc("calendar_room_list", json!({ "p_org": org })).await;
            let admin = crate::sb_rpc("calendar_room_admin_ok", json!({ "p_org": org, "p_user": uid })).await;
            match (l, admin) {
                (Ok(rooms), Ok(a)) => Ok(json!({ "rooms": rooms, "can_manage": a.as_bool().unwrap_or(false) })),
                (Err(e), _) | (_, Err(e)) => Err(e),
            }
        }
        "calendar.rooms.create" => {
            let cap = input.get("capacity").and_then(|v| v.as_i64());
            crate::sb_rpc(
                "calendar_room_create",
                json!({ "p_org": org, "p_user": uid, "p_name": sv(input, "name"), "p_kind": sv(input, "kind"), "p_capacity": cap, "p_location": input.get("location").and_then(|v| v.as_str()) }),
            )
            .await
        }
        "calendar.rooms.archive" => {
            let id = sv(input, "id");
            if !rc::valid_uuid(id) {
                return fail_code("bad_id");
            }
            crate::sb_rpc("calendar_room_archive", json!({ "p_org": org, "p_user": uid, "p_id": id })).await
        }
        "calendar.rooms.state" | "calendar.rooms.schedule" => {
            let (f, t) = (sv(input, "from"), sv(input, "to"));
            if !rc::ts_ok(f) || !rc::ts_ok(t) {
                return fail_code("bad_time");
            }
            if proc == "calendar.rooms.state" {
                let ex = rc::event_uuid(sv(input, "exclude_event"));
                crate::sb_rpc("calendar_room_state", json!({ "p_org": org, "p_from": f, "p_to": t, "p_exclude_event": ex }))
                    .await
                    .map(|v| json!({ "rooms": v }))
            } else {
                let rid = sv(input, "room_id");
                if !rc::valid_uuid(rid) {
                    return fail_code("bad_id");
                }
                crate::sb_rpc("calendar_room_schedule", json!({ "p_org": org, "p_room": rid, "p_from": f, "p_to": t }))
                    .await
                    .map(|v| json!({ "slots": v }))
            }
        }
        "calendar.rooms.book" | "calendar.rooms.release" => {
            let (ev, rid) = (rc::event_uuid(sv(input, "event_id")), sv(input, "room_id"));
            let ev = match ev {
                Some(e) if rc::valid_uuid(rid) => e,
                _ => return fail_code("bad_id"),
            };
            if proc == "calendar.rooms.book" {
                // E84: repeat meetings — sirf pehla slot nahi, agle 400 din ke SAARE occurrences us room par kisi aur se takra to nahi rahe
                let addr = crate::sb_select(&format!("calendar_rooms?select=address&id=eq.{}&org_id=eq.{}&archived_at=is.null&limit=1", rid, org))
                    .await
                    .ok()
                    .and_then(|v| v.as_array().and_then(|a| a.first().cloned()))
                    .map(|r| sv(&r, "address").to_string())
                    .unwrap_or_default();
                let evrow = crate::sb_select(&format!("calendar_events?select=*&id=eq.{}&org_id=eq.{}&limit=1", ev, org))
                    .await
                    .ok()
                    .and_then(|v| v.as_array().and_then(|a| a.first().cloned()));
                if let (true, Some(row)) = (!addr.is_empty(), evrow) {
                    if crate::cal_glue::room_series_clash(&org, &row, Some(&addr)).await.is_some() {
                        return fail_code("room_busy");
                    }
                }
            }
            let f = if proc == "calendar.rooms.book" { "calendar_room_book" } else { "calendar_room_release" };
            crate::sb_rpc(f, json!({ "p_org": org, "p_user": uid, "p_event": ev, "p_room": rid })).await
        }
        _ => return crate::err(StatusCode::NOT_FOUND, "unknown_proc", "").into_response(),
    };
    match res {
        Ok(v) => match checked(v) {
            Ok(v) => crate::ok(v).into_response(),
            Err(r) => r,
        },
        Err(e) => db_err(&e),
    }
}
