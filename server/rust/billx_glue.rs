// ============================================================================
// billx_glue — Batch C1: billing padhne/jodne wale 3 raaste, Rust PRIMARY (Tokio async; /rpc + /wt/rpc; Rule 52/56/57/59).
//   billing.state          AUTH {}                 -> {source_of_truth, entitlement, intents[20], log[20]}   (Bun GET /api/billing/state)
//   billing.stateHealth    AUTH FOUNDER {}         -> {health, gaps[50], alerts[50]}                          (Bun GET /api/billing/state-health)
//   billing.claimGuest     AUTH {guest_token}      -> {intent_id, claimed}                                    (Bun POST /api/billing/claim-guest)
// LOOPHOLE FIX: Bun ka state-health har login wale ko poori company ke truth-gaps aur payment alerts dikhata tha;
// Rust mein sirf founder_accounts. Polar ko yahan koi call nahi. Paisa banane wale raaste (intent/change-plan/guest-intent/sync) C2.
// ============================================================================

use crate::billx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::owns_name(proc)
}

fn fail(s: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(s, code, msg).into_response()
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

fn first(v: &Result<Value, String>) -> Option<Value> {
    v.as_ref().ok().and_then(|r| r.as_array().and_then(|a| a.first().cloned()))
}

fn rows(v: Result<Value, String>) -> Value {
    match v {
        Ok(x) if x.is_array() => x,
        _ => json!([]),
    }
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let (uid, _email) = match crate::auth_user(token).await {
        Some(v) => v,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", "unauthorized"),
    };
    let u = enc(&uid);
    match proc {
        "billing.state" => {
            let q_ent = format!("entitlement_state?select=*&user_id=eq.{u}&limit=1");
            let q_int = format!("billing_intents?select=id,kind,plan,band,seats,state,amount_expected,amount_paid,currency,paid_at,created_at,last_error&user_id=eq.{u}&order=created_at.desc&limit=20");
            let q_log = format!("billing_state_log?select=to_state,reason,source,created_at&user_id=eq.{u}&order=created_at.desc&limit=20");
            let (ent, intents, log) = tokio::join!(crate::sb_select(&q_ent), crate::sb_select(&q_int), crate::sb_select(&q_log));
            let entitlement = first(&ent).unwrap_or(json!({
                "plan": null, "seats": 0, "movein_band": null, "support_active": false, "active_until": null, "revision": 0
            }));
            crate::ok(json!({
                "source_of_truth": "supabase",
                "entitlement": entitlement,
                "intents": rows(intents),
                "log": rows(log),
            }))
            .into_response()
        }
        "billing.stateHealth" => {
            let q_f = format!("founder_accounts?select=user_id&user_id=eq.{u}&limit=1");
            let is_founder = first(&crate::sb_select(&q_f).await).is_some();
            if !c::health_allowed(is_founder) {
                return fail(StatusCode::FORBIDDEN, "founder_only", "founder only");
            }
            let q_h = "billing_state_health?select=*&limit=1".to_string();
            let q_g = "billing_truth_gaps?select=*&limit=50".to_string();
            let q_a = "payment_alerts?select=id,severity,kind,message,created_at&resolved_at=is.null&order=created_at.desc&limit=50".to_string();
            let (h, g, a) = tokio::join!(crate::sb_select(&q_h), crate::sb_select(&q_g), crate::sb_select(&q_a));
            crate::ok(json!({
                "health": first(&h).unwrap_or(Value::Null),
                "gaps": rows(g),
                "alerts": rows(a),
            }))
            .into_response()
        }
        "billing.claimGuest" => {
            let raw = input.get("guest_token").and_then(|x| x.as_str()).unwrap_or("");
            if raw.trim().is_empty() {
                return fail(StatusCode::BAD_REQUEST, "guest_token_required", "guest_token required");
            }
            let tok = match c::guest_token_ok(raw) {
                Some(t) => t,
                None => return fail(StatusCode::BAD_REQUEST, "guest_token_invalid", "guest_token invalid"),
            };
            match crate::sb_rpc("billing_guest_intent_claim", json!({ "p_token": tok, "p_user": uid })).await {
                Ok(v) => {
                    let id = match &v {
                        Value::String(s) if !s.is_empty() => Some(s.clone()),
                        Value::Array(a) => a.first().and_then(|x| x.as_str()).map(|s| s.to_string()),
                        _ => None,
                    };
                    crate::ok(json!({ "intent_id": id, "claimed": id.is_some() })).into_response()
                }
                Err(e) => fail(StatusCode::INTERNAL_SERVER_ERROR, "claim_failed", &e),
            }
        }
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", "unknown proc"),
    }
}
