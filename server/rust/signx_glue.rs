// ============================================================================
// signx_glue.rs — the I/O half of the sign-up / create-account doors (PX2b). Rust ONLY: "bun banned hai" (founder 2 Nov 2026), so there is NO Bun twin.
// Security design: docs/claude/SIGNUP-SECURITY-MILITARY-GRADE-02NOV.md. Pure rules + HMAC token: signx_core.rs.
//
// Procedures (all under /rpc/*):
//   signx.policy       PUBLIC  {}                         -> {blocked_countries, blocked_dials}      (the UI hides these from the Country list)
//   signx.token        PUBLIC  {}                         -> {token, nonce, ts, ttl}                  (HMAC-SHA256 door token, 10 min)
//   signx.check        PUBLIC  {kind: "handle"|"email", value, token, nonce, ts, tz?}
//                                                         -> {available, reason?, suggestions?[]}     red = available:false (+ up to 5 free ideas for a handle), green = true
//   signx.country.set  AUTH    {country_iso2}             -> {ok, country_iso2}
//   signx.phones.list  AUTH    {}                         -> {phones:[{id,e164,country_iso2,label,is_primary,verified}]}
//   signx.phones.add   AUTH    {e164, country_iso2, label?} -> {ok, id}     (max 5; same number on other accounts is allowed; blind-index HMAC stored)
//   signx.phones.remove AUTH   {id}                       -> {ok}
//   signx.phones.primary AUTH  {id}                       -> {ok}
// SQL first: E127 (tables), E128 (e164_hmac). Adds NO dependency. Child module of main.rs: uses its private helpers via `crate::`.
// ============================================================================

use crate::signx_core as sc;
use axum::{
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
};
use serde_json::{json, Value};
use std::sync::{Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

type Resp = axum::response::Response;

static WINDOW: OnceLock<Mutex<sc::Window>> = OnceLock::new();

pub fn public_owns(proc: &str) -> bool {
    matches!(proc, "signx.policy" | "signx.token" | "signx.check")
}

pub fn owns(proc: &str) -> bool {
    matches!(proc, "signx.country.set" | "signx.phones.list" | "signx.phones.add" | "signx.phones.remove" | "signx.phones.primary")
}

fn data(v: Value) -> Resp {
    crate::ok(v).into_response()
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn st(input: &Value, k: &str) -> String {
    input.get(k).and_then(|x| x.as_str()).unwrap_or("").trim().to_string()
}

fn now_ms() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(0)
}

fn rand_hex(bytes: usize) -> Result<String, String> {
    use std::io::Read;
    let mut b = vec![0u8; bytes];
    std::fs::File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut b)).map_err(|e| e.to_string())?;
    Ok(b.iter().map(|x| format!("{x:02x}")).collect())
}

fn too_many(key: &str, window_ms: u64, max: usize) -> bool {
    let m = WINDOW.get_or_init(|| Mutex::new(sc::Window::default()));
    match m.lock() {
        Ok(mut w) => w.too_many(key, now_ms(), window_ms, max),
        Err(_) => false,
    }
}

fn not_available() -> Resp {
    fail(StatusCode::FORBIDDEN, "country_not_available", "ANEXOMAIL is not available in your country.")
}

pub async fn public(proc: &str, input: &Value, headers: &HeaderMap) -> Resp {
    let ip = sc::client_ip_from_xff(headers.get("x-forwarded-for").and_then(|v| v.to_str().ok()).unwrap_or(""));
    let ip_key = if ip.is_empty() { "unknown".to_string() } else { ip };
    match proc {
        "signx.policy" => data(json!({ "blocked_countries": sc::BLOCKED_COUNTRIES, "blocked_dials": sc::BLOCKED_DIALS })),
        "signx.token" => {
            // 30 fresh tokens per 10 minutes per address: enough for a human, expensive for a scanner.
            if too_many(&format!("tok:{ip_key}"), 600_000, 30) {
                return fail(StatusCode::TOO_MANY_REQUESTS, "too_many_requests", "Too many requests. Try again in a few minutes.");
            }
            let nonce = match rand_hex(16) {
                Ok(n) => n,
                Err(_) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "token_failed", "Could not prepare the check."),
            };
            let ts = now_ms() / 1000;
            let token = sc::make_token(&crate::vault_key(), "check", ts, &nonce);
            data(json!({ "token": token, "nonce": nonce, "ts": ts, "ttl": sc::TOKEN_TTL_SECS }))
        }
        "signx.check" => check(input, &ip_key).await,
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown sign-up procedure"),
    }
}

async fn check(input: &Value, ip_key: &str) -> Resp {
    let ts = input.get("ts").and_then(|x| x.as_u64()).unwrap_or(0);
    let now = now_ms() / 1000;
    if !sc::verify_token(&crate::vault_key(), "check", ts, &st(input, "nonce"), &st(input, "token"), now) {
        return fail(StatusCode::UNAUTHORIZED, "bad_token", "Please try again.");
    }
    // 60 questions per minute per address, and 120 per token window: a person typing is far below this.
    if too_many(&format!("chk:{ip_key}"), 60_000, 60) {
        return fail(StatusCode::TOO_MANY_REQUESTS, "too_many_requests", "Too many requests. Try again in a minute.");
    }
    // Best-effort VPN signal: a browser that says it is in one of the three time zones.
    if sc::timezone_blocked(&st(input, "tz")) {
        return not_available();
    }
    let kind = st(input, "kind");
    let value = st(input, "value").to_lowercase();
    match kind.as_str() {
        "handle" => check_handle(&value).await,
        "email" => check_email(&value).await,
        _ => fail(StatusCode::BAD_REQUEST, "bad_kind", "Unknown check."),
    }
}

async fn handle_free(h: &str) -> bool {
    let reserved = crate::sb_select(&format!("reserved_handles?select=handle&handle=eq.{}", sc::pct_simple(h))).await;
    if reserved.map(|v| v.as_array().map(|a| !a.is_empty()).unwrap_or(false)).unwrap_or(false) {
        return false;
    }
    let taken = crate::sb_select(&format!("trial_accounts?select=user_id&anexomail_handle=eq.{}&status=neq.released", sc::pct_simple(h))).await;
    !taken.map(|v| v.as_array().map(|a| !a.is_empty()).unwrap_or(false)).unwrap_or(false)
}

async fn check_handle(raw: &str) -> Resp {
    let base = sc::clean_base(raw);
    if !sc::handle_ok(&base) || base != raw {
        return data(json!({ "kind": "handle", "value": raw, "available": false, "reason": "invalid_handle" }));
    }
    if handle_free(&base).await {
        return data(json!({ "kind": "handle", "value": base, "available": true, "address": format!("{base}@anexomail.com") }));
    }
    // Red: find up to 5 ideas that are free right now (checked one by one, at most 12 candidates).
    let mut ideas: Vec<String> = Vec::new();
    for c in sc::handle_candidates(&base, now_ms()) {
        if ideas.len() >= 5 {
            break;
        }
        if handle_free(&c).await {
            ideas.push(c);
        }
    }
    data(json!({ "kind": "handle", "value": base, "available": false, "reason": "taken", "suggestions": ideas }))
}

async fn check_email(email: &str) -> Resp {
    if !sc::email_shape_ok(email) {
        return data(json!({ "kind": "email", "value": email, "available": false, "reason": "invalid_email" }));
    }
    // Same single lookup for every address; the answer never says whose account it is.
    let uid = match crate::sb_rpc("auth_user_id_by_email", json!({ "_email": email })).await {
        Ok(v) => v.as_str().unwrap_or("").to_string(),
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "check_failed", "Could not check right now. Try again."),
    };
    if uid.is_empty() {
        data(json!({ "kind": "email", "value": email, "available": true }))
    } else {
        data(json!({ "kind": "email", "value": email, "available": false, "reason": "taken" }))
    }
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

fn uuid_ok(s: &str) -> bool {
    s.len() == 36 && s.bytes().all(|c| c.is_ascii_hexdigit() || c == b'-')
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let user_id = match crate::auth_user(token).await {
        Some((id, _)) => id,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid"),
    };
    if !uuid_ok(&user_id) {
        return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid");
    }
    if too_many(&format!("usr:{user_id}"), 60_000, 30) {
        return fail(StatusCode::TOO_MANY_REQUESTS, "too_many_requests", "Too many requests. Try again in a minute.");
    }
    match proc {
        "signx.country.set" => {
            let c = st(input, "country_iso2").to_ascii_uppercase();
            if !sc::country_shape_ok(&c) {
                return fail(StatusCode::BAD_REQUEST, "bad_country", "Choose your country from the list.");
            }
            if sc::country_blocked(&c) {
                return not_available();
            }
            match crate::sb_patch(&format!("account_profiles?user_id=eq.{user_id}"), json!({ "country_iso2": c })).await {
                Ok(_) => data(json!({ "ok": true, "country_iso2": c })),
                Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "country_failed", "Could not save your country."),
            }
        }
        "signx.phones.list" => match crate::sb_select(&format!("account_phones?select=id,e164,country_iso2,label,is_primary,verified_at&user_id=eq.{user_id}&order=created_at")).await {
            Ok(v) => {
                let phones: Vec<Value> = v
                    .as_array()
                    .map(|a| {
                        a.iter()
                            .map(|r| {
                                json!({ "id": r["id"], "e164": r["e164"], "country_iso2": r["country_iso2"], "label": r["label"],
                                        "is_primary": r["is_primary"], "verified": !r["verified_at"].is_null() })
                            })
                            .collect()
                    })
                    .unwrap_or_default();
                data(json!({ "phones": phones }))
            }
            Err(_) => fail(StatusCode::BAD_GATEWAY, "phones_failed", "Could not load your numbers."),
        },
        "signx.phones.add" => {
            let c = st(input, "country_iso2").to_ascii_uppercase();
            if !sc::country_shape_ok(&c) {
                return fail(StatusCode::BAD_REQUEST, "bad_country", "Choose the country of this number.");
            }
            let e164 = match sc::normalise_e164(&st(input, "e164")) {
                Some(n) => n,
                None => return fail(StatusCode::BAD_REQUEST, "bad_number", "Enter the number with its country code, for example +92 300 1234567."),
            };
            if sc::country_blocked(&c) || sc::dial_blocked(&e164) {
                return not_available();
            }
            let label = st(input, "label");
            if label.chars().count() > 40 {
                return fail(StatusCode::BAD_REQUEST, "bad_label", "Label is too long (40 characters).");
            }
            let existing = match crate::sb_select(&format!("account_phones?select=id,e164&user_id=eq.{user_id}")).await {
                Ok(v) => v.as_array().cloned().unwrap_or_default(),
                Err(_) => return fail(StatusCode::BAD_GATEWAY, "phones_failed", "Could not save the number."),
            };
            if existing.iter().any(|r| r["e164"].as_str() == Some(e164.as_str())) {
                return fail(StatusCode::CONFLICT, "already_on_your_account", "This number is already on your account.");
            }
            if existing.len() >= 5 {
                return fail(StatusCode::CONFLICT, "phones_limit", "You can keep up to 5 numbers.");
            }
            let blind = sc::phone_blind_index(&crate::vault_key(), &e164);
            let row = json!({
                "user_id": user_id, "e164": e164, "country_iso2": c,
                "label": if label.is_empty() { Value::Null } else { json!(label) },
                "is_primary": existing.is_empty(), "e164_hmac": blind
            });
            match crate::sb_insert("account_phones", row).await {
                Ok(v) => {
                    let id = v.as_array().and_then(|a| a.first()).and_then(|r| r.get("id")).cloned().unwrap_or(Value::Null);
                    data(json!({ "ok": true, "id": id }))
                }
                Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "phones_failed", "Could not save the number."),
            }
        }
        "signx.phones.remove" => {
            let id = st(input, "id");
            if !uuid_ok(&id) {
                return fail(StatusCode::BAD_REQUEST, "bad_id", "Unknown number.");
            }
            if pg_delete(&format!("account_phones?id=eq.{id}&user_id=eq.{user_id}")).await.is_err() {
                return fail(StatusCode::INTERNAL_SERVER_ERROR, "phones_failed", "Could not remove the number.");
            }
            // keep one primary if any number is left
            if let Ok(v) = crate::sb_select(&format!("account_phones?select=id,is_primary&user_id=eq.{user_id}&order=created_at")).await {
                let rows = v.as_array().cloned().unwrap_or_default();
                if !rows.is_empty() && !rows.iter().any(|r| r["is_primary"].as_bool() == Some(true)) {
                    if let Some(first) = rows[0]["id"].as_str().filter(|s| uuid_ok(s)) {
                        let _ = crate::sb_patch(&format!("account_phones?id=eq.{first}&user_id=eq.{user_id}"), json!({ "is_primary": true })).await;
                    }
                }
            }
            data(json!({ "ok": true }))
        }
        "signx.phones.primary" => {
            let id = st(input, "id");
            if !uuid_ok(&id) {
                return fail(StatusCode::BAD_REQUEST, "bad_id", "Unknown number.");
            }
            // it must be the caller's own row
            let own = crate::sb_select(&format!("account_phones?select=id&id=eq.{id}&user_id=eq.{user_id}")).await;
            if !own.map(|v| v.as_array().map(|a| !a.is_empty()).unwrap_or(false)).unwrap_or(false) {
                return fail(StatusCode::NOT_FOUND, "not_found", "Unknown number.");
            }
            let a = crate::sb_patch(&format!("account_phones?user_id=eq.{user_id}"), json!({ "is_primary": false })).await;
            let b = crate::sb_patch(&format!("account_phones?id=eq.{id}&user_id=eq.{user_id}"), json!({ "is_primary": true })).await;
            if a.is_ok() && b.is_ok() { data(json!({ "ok": true })) } else { fail(StatusCode::INTERNAL_SERVER_ERROR, "phones_failed", "Could not change the main number.") }
        }
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown sign-up procedure"),
    }
}
