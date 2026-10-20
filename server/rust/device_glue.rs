// ============================================================================
// device_glue.rs — I/O half of the device record for EVERY signed-in user (Rust PRIMARY; Bun /api/chat/device/* = fallback).
//
//   chat.device.vault        {signals}              -> device_vault_register  (seal 5 coarse signals; flags 3+ accounts / bursts)
//   chat.device.trust.list   {}                     -> device_trust_list      (your devices + policy)
//   chat.device.trust.set    {device_hash, state}   -> device_trust_set       (revoke ends that device's sessions)
//
// Procedure names are unchanged (the browser already calls them); they are answered here BEFORE the chat gate, so Basic
// gets the same protection as every other plan. Same SQL functions, same arguments, same {result:{data}} / 500 db_error
// shapes as the chat arm in main.rs (which stays as dead fallback). Child module of the crate root: uses `auth_user`,
// `sb_rpc`, `vault_key`, `ok`, `err`. Adds NO dependency.
// ============================================================================

use crate::device_core as dc;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(proc, "chat.device.vault" | "chat.device.trust.list" | "chat.device.trust.set")
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let user = match crate::auth_user(token).await {
        Some((id, _)) => id,
        None => return crate::err(StatusCode::UNAUTHORIZED, "unauthorized", "").into_response(),
    };
    let result: Result<Value, String> = match proc {
        "chat.device.vault" => {
            let mut signals = input.get("signals").cloned().unwrap_or(json!({}));
            if let Some(obj) = signals.as_object_mut() {
                obj.retain(|k, _| !dc::is_forbidden_signal(k));
            } else {
                signals = json!({});
            }
            crate::sb_rpc("device_vault_register", json!({ "_user": user, "_signals": signals, "_key": crate::vault_key() })).await
        }
        "chat.device.trust.list" => crate::sb_rpc("device_trust_list", json!({ "_user": user })).await,
        "chat.device.trust.set" => {
            let hash = st(input, "device_hash");
            let state = st(input, "state");
            if !dc::valid_device_hash(&hash) || !dc::valid_user_state(&state) {
                return crate::err(StatusCode::BAD_REQUEST, "device_hash_state_required", "device_hash and a valid state are required")
                    .into_response();
            }
            crate::sb_rpc("device_trust_set", json!({ "_user": user, "_device_hash": hash, "_state": state, "_actor": "user" })).await
        }
        _ => return crate::err(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown device procedure").into_response(),
    };
    match result {
        Ok(data) => crate::ok(data).into_response(),
        Err(detail) => crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &detail).into_response(),
    }
}
