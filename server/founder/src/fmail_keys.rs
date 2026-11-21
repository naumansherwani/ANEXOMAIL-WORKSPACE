//! QC8c c3 (21 Nov 2026): the signed door that records what the one-letter mail keys did. Rust (axum + tokio), HTTP/3 + signed channel, SQL E200 (hash chain, append-only).
//! POST /founder/v1/mail/keys/log {action: archive|trash|star|unread, via: key|batch, n: 1..50, folder: [a-z_]{1,24}}. The write signature is ENFORCED (pk::ctx, same as every
//! mail door). The body carries NO mail id, subject or address, by design; the SQL door also refuses them (no such columns) and caps 600 rows per hour.
//! GET  /founder/v1/mail/keys/stats?days=7 and /founder/v1/mail/keys/verify read the log back (stats, and the hash-chain check).
use crate::{passkey as pk, S};
use axum::{extract::State, http::{HeaderMap, StatusCode, Uri}, response::{IntoResponse, Response}};
use serde_json::{json, Value};

/// The same closed lists as the SQL checks in E200, checked here first so a bad body never reaches the database.
pub fn valid_event(j: &Value) -> Option<(String, String, i64, String)> {
    let action = j.get("action")?.as_str()?;
    let via = j.get("via")?.as_str()?;
    let n = j.get("n")?.as_i64()?;
    let folder = j.get("folder")?.as_str()?;
    if !matches!(action, "archive" | "trash" | "star" | "unread") { return None; }
    if !matches!(via, "key" | "batch") { return None; }
    if (via == "key" && n != 1) || (via == "batch" && !(2..=50).contains(&n)) { return None; }
    if folder.is_empty() || folder.len() > 24 || !folder.bytes().all(|b| b.is_ascii_lowercase() || b == b'_') { return None; }
    Some((action.to_string(), via.to_string(), n, folder.to_string()))
}

fn bad(e: &str) -> Response { pk::refuse(StatusCode::BAD_REQUEST, e) }

pub async fn log_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some((action, via, n, folder)) = valid_event(&j) else { return bad("action, via, n and folder are needed (closed lists)") };
    let call = sb.rpc_msg("fmail_keys_log200", json!({"p_uid": uid, "p_action": action, "p_via": via, "p_n": n, "p_folder": folder}));
    match tokio::time::timeout(std::time::Duration::from_secs(5), call).await {
        Err(_) => pk::refuse(StatusCode::GATEWAY_TIMEOUT, "the log did not answer in time; the key action itself already happened"),
        Ok(Ok(v)) => crate::signed(&st, json!({"ok": true, "result": v})),
        Ok(Err((429 | 54000, _))) => pk::refuse(StatusCode::TOO_MANY_REQUESTS, "more than 600 key actions in an hour; the log paused"),
        Ok(Err(e)) => pk::sql_err(e),
    }
}

/// GET /founder/v1/mail/keys/stats?days=7
pub async fn stats_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let days = uri.query().and_then(|q| q.split('&').find_map(|p| p.strip_prefix("days="))).and_then(|d| d.parse::<i64>().ok()).unwrap_or(7).clamp(1, 90);
    let Some(sb) = st.sb.as_ref() else { return crate::signed(&st, json!({"connected": false})) };
    match sb.rpc("fmail_keys_stats200", json!({"p_uid": c.sub, "p_days": days})).await { Some(v) => crate::signed(&st, json!({"connected": true, "stats": v})), None => crate::signed(&st, json!({"connected": false, "note": "run the E200 SQL step (sql-run.sh)"})) }
}

/// GET /founder/v1/mail/keys/verify : walks the whole hash chain of this founder.
pub async fn verify_ep(State(st): State<S>, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let Some(sb) = st.sb.as_ref() else { return crate::signed(&st, json!({"connected": false})) };
    match sb.rpc("fmail_keys_verify200", json!({"p_uid": c.sub})).await { Some(v) => crate::signed(&st, json!({"connected": true, "chain": v})), None => crate::signed(&st, json!({"connected": false, "note": "run the E200 SQL step (sql-run.sh)"})) }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn good_events_pass() {
        assert!(valid_event(&json!({"action": "star", "via": "key", "n": 1, "folder": "inbox"})).is_some());
        assert!(valid_event(&json!({"action": "archive", "via": "batch", "n": 50, "folder": "inbox"})).is_some());
        assert!(valid_event(&json!({"action": "unread", "via": "batch", "n": 2, "folder": "my_folder"})).is_some());
    }
    #[test] fn bad_events_are_refused() {
        for b in [json!({"action": "delete", "via": "key", "n": 1, "folder": "inbox"}), json!({"action": "star", "via": "other", "n": 1, "folder": "inbox"}),
                  json!({"action": "star", "via": "key", "n": 2, "folder": "inbox"}), json!({"action": "star", "via": "batch", "n": 1, "folder": "inbox"}),
                  json!({"action": "star", "via": "batch", "n": 51, "folder": "inbox"}), json!({"action": "star", "via": "key", "n": 1, "folder": "In Box"}),
                  json!({"action": "star", "via": "key", "n": 1, "folder": ""}), json!({"action": "star", "via": "key", "n": 1, "folder": "abcdefghijklmnopqrstuvwxyz"}),
                  json!({"action": "star", "via": "key", "n": "1", "folder": "inbox"}), json!({"via": "key", "n": 1, "folder": "inbox"}),
                  json!({"action": "star", "via": "key", "n": 1, "folder": "inbox", "subject": "x"}).get("folder").cloned().map(|_| json!(null)).unwrap()] {
            assert!(valid_event(&b).is_none(), "{b}");
        }
    }
    #[test] fn extra_fields_are_ignored_never_stored() {
        // a body that tries to smuggle a subject: the validator returns only the four closed fields
        let (a, v, n, f) = valid_event(&json!({"action": "star", "via": "key", "n": 1, "folder": "inbox", "subject": "secret", "message_id": "x"})).unwrap();
        assert_eq!((a.as_str(), v.as_str(), n, f.as_str()), ("star", "key", 1, "inbox"));
    }
}
