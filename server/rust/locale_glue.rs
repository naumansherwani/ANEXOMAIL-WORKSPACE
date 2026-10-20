// ============================================================================
// locale_glue.rs — the I/O half of /rpc/locale.* (Rust PRIMARY; Bun /api/locale/* = fallback only, kept as-is).
//
// Procedures:
//   locale.bundle      PUBLIC  {tag}  -> {tag, bundle}   overlay strings for one of the 28 locales (no login needed, same as Bun)
//   locale.registry    PUBLIC  {}     -> {locales:[...]} the 28 locales (tag, english, native, dir, sort_n)
//   locale.pref        AUTH    {}     -> {tag|null}      the caller's saved language (cross-device)
//   locale.pref.set    AUTH    {tag}  -> {ok, tag}       save it (upsert on user_id)
//
// Answers are byte-for-byte the shapes the Bun twin (server/routes/locale.ts) returns, inside the usual `{result:{data}}`:
// any read failure degrades to "English / no preference" exactly like Bun does; only the write reports a real error.
// Child module of the crate root: uses the root's private helpers (`sb_rpc`, `sb_select`, `sb_upsert`, `auth_user`, `ok`, `err`).
// Adds NO dependency.
// ============================================================================

use crate::locale_core::{self as lc, DEFAULT_TAG};
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Map, Value};

type Resp = axum::response::Response;

pub fn public_owns(proc: &str) -> bool {
    matches!(proc, "locale.bundle" | "locale.registry")
}

pub fn owns(proc: &str) -> bool {
    matches!(proc, "locale.pref" | "locale.pref.set")
}

fn data(v: Value) -> Resp {
    crate::ok(v).into_response()
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn tag_of(input: &Value) -> String {
    input.get("tag").and_then(|x| x.as_str()).unwrap_or("").to_string()
}

pub async fn public(proc: &str, input: &Value) -> Resp {
    match proc {
        "locale.bundle" => bundle(input).await,
        "locale.registry" => registry().await,
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown locale procedure"),
    }
}

async fn bundle(input: &Value) -> Resp {
    let mut tag = tag_of(input);
    if tag.is_empty() {
        tag = DEFAULT_TAG.to_string();
    }
    if !lc::is_tag(&tag) {
        return data(json!({ "tag": DEFAULT_TAG, "bundle": {} }));
    }
    // 1) the SQL function (phase64 `ui_copy_bundle`) — one round-trip, filtering done in Postgres.
    if let Ok(v) = crate::sb_rpc("ui_copy_bundle", json!({ "p_tag": tag })).await {
        if v.is_object() {
            return data(json!({ "tag": tag, "bundle": v }));
        }
    }
    // 2) the raw rows, filtered here exactly like the Bun twin.
    let rows = match crate::sb_select(&format!("ui_copy?select=english_key,text&locale_tag=eq.{}", lc::pct(&tag))).await {
        Ok(v) => v,
        Err(_) => return data(json!({ "tag": tag, "bundle": {} })),
    };
    let mut out = Map::new();
    for r in rows.as_array().cloned().unwrap_or_default() {
        let k = r.get("english_key").and_then(|x| x.as_str()).unwrap_or("");
        let t = r.get("text").and_then(|x| x.as_str()).unwrap_or("");
        if lc::keep_row(&tag, k, t) {
            out.insert(k.to_string(), Value::String(t.to_string()));
        }
    }
    data(json!({ "tag": tag, "bundle": Value::Object(out) }))
}

async fn registry() -> Resp {
    match crate::sb_select("locale_registry?select=tag,english,native,dir,sort_n&order=sort_n.asc").await {
        Ok(v) if v.is_array() => data(json!({ "locales": v })),
        _ => data(json!({ "locales": lc::TAGS.iter().map(|t| json!({ "tag": t })).collect::<Vec<_>>() })),
    }
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let user_id = match crate::auth_user(token).await {
        Some((id, _)) => id,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid"),
    };
    match proc {
        "locale.pref" => {
            let q = format!("awam_locale_pref?select=locale_tag&user_id=eq.{}&limit=1", lc::pct(&user_id));
            let tag = match crate::sb_select(&q).await {
                Ok(v) => v
                    .as_array()
                    .and_then(|a| a.first())
                    .and_then(|r| r.get("locale_tag"))
                    .and_then(|x| x.as_str())
                    .filter(|t| lc::is_tag(t))
                    .map(|t| Value::String(t.to_string()))
                    .unwrap_or(Value::Null),
                Err(_) => Value::Null,
            };
            data(json!({ "tag": tag }))
        }
        "locale.pref.set" => {
            let tag = tag_of(input);
            if !lc::is_tag(&tag) {
                return fail(StatusCode::BAD_REQUEST, "locale_not_allowed", "Language not supported");
            }
            let row = json!({ "user_id": user_id, "locale_tag": tag, "updated_at": lc::now_rfc3339() });
            match crate::sb_upsert("awam_locale_pref", "user_id", row).await {
                Ok(_) => data(json!({ "ok": true, "tag": tag })),
                Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "pref_failed", "Could not save language"),
            }
        }
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown locale procedure"),
    }
}
