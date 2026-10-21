// ============================================================================
// b6_glue.rs — B6 (G16): `billing.portal` Rust PRIMARY. Bun /api/billing/portal sirf fallback.
//
//   billing.portal   AUTH   {}  -> {url}   Polar customer portal (cancel / card badalna / VAT invoices)
//
// Kaise: login se user_id (body se KABHI nahi) -> Polar engine :3400 ko MUHAR-band POST /api/v1/portal
// (HMAC-SHA256, 60 s khidki, nonce) -> sirf https://*.polar.sh URL wapas. Koi secret/card browser tak nahi jaata.
// Child module of crate root. Adds NO dependency (hmac, sha2, reqwest pehle se hain).
// ============================================================================
use crate::b6_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use hmac::{Hmac, Mac};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

type Resp = axum::response::Response;
static CTR: AtomicU64 = AtomicU64::new(1);

pub fn owns(proc: &str) -> bool {
    proc == "billing.portal"
}

fn data(v: Value) -> Resp {
    crate::ok(v).into_response()
}

fn fail(status: u16, code: &str, msg: &str) -> Resp {
    crate::err(StatusCode::from_u16(status).unwrap_or(StatusCode::BAD_GATEWAY), code, msg).into_response()
}

fn load_key() -> Vec<u8> {
    let path = std::env::var("PCP_KEY_FILE").unwrap_or_else(|_| "/etc/anexomail/pcp.key".into());
    if let Ok(s) = std::fs::read_to_string(&path) {
        let t = s.trim();
        if !t.is_empty() {
            return t.as_bytes().to_vec();
        }
    }
    crate::env_var("PCP_KEY").trim().as_bytes().to_vec()
}

fn engine_url() -> String {
    let u = crate::env_var("POLAR_ENGINE_URL");
    let u = if u.trim().is_empty() { "http://127.0.0.1:3400".to_string() } else { u };
    u.trim_end_matches('/').to_string()
}

pub async fn dispatch(proc: &str, token: &str, _input: &Value) -> Resp {
    let user_id = match crate::auth_user(token).await {
        Some((id, _)) => id,
        None => return fail(401, "unauthorized", "Session invalid"),
    };
    if proc != "billing.portal" || !c::is_uuid(&user_id) {
        return fail(404, "procedure_not_in_rust", "Unknown billing procedure");
    }
    let key = load_key();
    if key.len() < 32 {
        return fail(503, "control_plane_key_missing", "Billing portal is not configured");
    }

    let body = json!({ "user_id": user_id }).to_string();
    let body_hash = c::hex(&Sha256::digest(body.as_bytes()));
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default();
    let ts = now.as_secs() as i64;
    let nonce = c::nonce(now.as_nanos(), CTR.fetch_add(1, Ordering::Relaxed));
    let canon = c::canonical("POST", c::PORTAL_PATH, ts, &nonce, &body_hash);
    let mut mac = match Hmac::<Sha256>::new_from_slice(&key) {
        Ok(m) => m,
        Err(_) => return fail(503, "control_plane_key_missing", "Billing portal is not configured"),
    };
    mac.update(canon.as_bytes());
    let sig = c::hex(&mac.finalize().into_bytes());

    let sent = crate::http()
        .post(format!("{}{}", engine_url(), c::PORTAL_PATH))
        .header("content-type", "application/json")
        .header("x-pcp-ts", ts.to_string())
        .header("x-pcp-nonce", &nonce)
        .header("x-pcp-sig", sig)
        .body(body)
        .timeout(Duration::from_secs(20))
        .send()
        .await;
    let resp = match sent {
        Ok(r) => r,
        Err(_) => return fail(502, "portal_unavailable", "Billing portal is unavailable"),
    };
    let status = resp.status().as_u16();
    let j: Value = resp.json().await.unwrap_or(Value::Null);
    if status == 200 {
        let url = j.get("url").and_then(|v| v.as_str()).unwrap_or("");
        if c::portal_url_ok(url) {
            return data(json!({ "url": url }));
        }
        return fail(502, "portal_unavailable", "Billing portal is unavailable");
    }
    let code = j.get("error").and_then(|v| v.as_str()).unwrap_or("");
    let (st, cd, msg) = c::classify(status, code);
    fail(st, cd, msg)
}
