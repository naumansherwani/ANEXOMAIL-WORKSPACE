// ============================================================================
// trialx_glue — Trial lifecycle ke baaqi 3 procs, Rust PRIMARY (Tokio async; wahi dispatch HTTP /rpc aur WebTransport /wt/rpc; Rule 52/56).
//   account.signup.security {passkey?, recovery_kind?, recovery_hint?} -> account_state   (Bun POST /api/trial/security; SQL trial_set_security)
//   account.signup.events   {}                                          -> {events}        (Bun GET  /api/trial/events)
//   account.signup.holds    {}                                          -> {holds}         (Bun GET  /api/trial/mail-holds)
// Baaqi trial procs (state/start/claim/address/activate) main.rs mein pehle se Rust par hain; yeh module sirf kami poori karta hai. Sirf login chahiye (har plan).
// ============================================================================

use crate::trialx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::owns_name(proc)
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let (user, _email) = match crate::auth_user(token).await {
        Some(v) => v,
        None => return crate::err(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid").into_response(),
    };
    match proc {
        "account.signup.security" => {
            let passkey = input.get("passkey").and_then(|x| x.as_bool()).unwrap_or(false);
            let kind = st(input, "recovery_kind");
            if c::nothing_to_set(passkey, &kind) {
                return crate::err(StatusCode::BAD_REQUEST, "nothing_to_set", "Nothing to set").into_response();
            }
            let hint = c::clamp_hint(&st(input, "recovery_hint"));
            match crate::sb_rpc(
                "trial_set_security",
                json!({ "_user_id": user, "_passkey": passkey, "_recovery_kind": c::opt(&kind), "_recovery_hint": c::opt(&hint) }),
            )
            .await
            {
                Ok(v) => crate::ok(v).into_response(),
                Err(e) => crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
            }
        }
        "account.signup.events" => match crate::sb_select(&format!(
            "trial_events?select=id,event_type,detail,created_at&user_id=eq.{}&order=created_at.desc&limit=100",
            enc(&user)
        ))
        .await
        {
            Ok(v) => crate::ok(json!({ "events": v })).into_response(),
            Err(e) => crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
        },
        "account.signup.holds" => match crate::sb_select(&format!(
            "trial_mail_holds?select=id,from_address,subject,disposition,reason,received_at,released_at&user_id=eq.{}&order=received_at.desc&limit=200",
            enc(&user)
        ))
        .await
        {
            Ok(v) => crate::ok(json!({ "holds": v })).into_response(),
            Err(e) => crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
        },
        _ => crate::err(StatusCode::NOT_FOUND, "unknown_proc", proc).into_response(),
    }
}
