// ============================================================================
// ANEXOMAIL — Analytics Center procs (Phase 24) (Rust PRIMARY).
//
// `mod analytics_core; mod analytics_glue;` main.rs mein judta hai (installer: rust-engine-install.sh, module `analytics`).
// Soch analytics_core.rs mein (gate + safai, unit tests). Hisaab SQL E89 mein (service_role-only SECURITY DEFINER functions) — yahan sirf I/O.
// SQL E89 PEHLE (Rule 46). Na lagi ho to 501 `analytics_sql_missing` — kuch toot'ta nahi.
//
// Procs (login chahiye):
//   analytics.responseDebt      har package            -> analytics_response_debt
//   analytics.threadEconomics   Pro+                   -> analytics_thread_economics
//   analytics.deepWork          Pro+   input { tz? }   -> analytics_deep_work
//   analytics.attentionLeaks    Business+              -> analytics_attention_leaks
//   analytics.promiseSla        Business+              -> analytics_promise_sla
//   analytics.forecast          Business+              -> analytics_forecast
//   analytics.team              Business+, sirf owner/admin -> analytics_team
//   founderAnalytics.overview   sirf founder           -> founder_analytics_overview
// Scope: org ke saare mailboxes (shared inbox) — app ka mail.threads bhi org-scoped hai. Gate server par; UI sirf aaina.
// ============================================================================

use crate::analytics_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use std::collections::{HashMap, VecDeque};
use std::sync::Mutex;

const RATE_LIMIT: usize = 30; // calls per user per minute (hisaab bhari hai)
const RATE_WINDOW_MS: u64 = 60_000;
static RATE: std::sync::OnceLock<Mutex<HashMap<String, VecDeque<u64>>>> = std::sync::OnceLock::new();

pub fn owns(proc: &str) -> bool {
    c::need_of(proc).is_some() || proc == "founderAnalytics.overview"
}

fn fail(status: StatusCode, code: &str, msg: &str) -> axum::response::Response {
    crate::err(status, code, msg).into_response()
}
fn now_ms() -> u64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(0)
}

fn allowed_now(user: &str) -> bool {
    let m = RATE.get_or_init(|| Mutex::new(HashMap::new()));
    let now = now_ms();
    match m.lock() {
        Ok(mut map) => {
            if map.len() > 5_000 {
                map.retain(|_, q| q.back().map(|t| now.saturating_sub(*t) < RATE_WINDOW_MS).unwrap_or(false));
            }
            let q = map.entry(user.to_string()).or_default();
            while q.front().map(|t| now.saturating_sub(*t) >= RATE_WINDOW_MS).unwrap_or(false) {
                q.pop_front();
            }
            if q.len() >= RATE_LIMIT {
                false
            } else {
                q.push_back(now);
                true
            }
        }
        Err(_) => true,
    }
}

fn is_missing_function(e: &str) -> bool {
    e.contains("PGRST202") || e.contains("Could not find the function") || e.contains("42883")
}

fn sql_fail(e: &str) -> axum::response::Response {
    if is_missing_function(e) {
        fail(StatusCode::NOT_IMPLEMENTED, "analytics_sql_missing", "Analytics is being set up on the server.")
    } else {
        fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", "Could not read analytics right now.")
    }
}

/// Org ke mailbox addresses (mailboxes + mail_accounts), org_id DB ki apni UUID hai (mail_identity se).
async fn org_addresses(org: &str, me: &str) -> Vec<String> {
    let mut raw: Vec<String> = Vec::new();
    for q in [format!("mailboxes?select=address&org_id=eq.{org}&limit=500"), format!("mail_accounts?select=address&org_id=eq.{org}&limit=500")] {
        if let Ok(rows) = crate::sb_select(&q).await {
            for r in rows.as_array().cloned().unwrap_or_default() {
                if let Some(a) = r.get("address").and_then(|x| x.as_str()) {
                    raw.push(a.to_string());
                }
            }
        }
    }
    c::clean_addresses(&raw, me)
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    if proc == "founderAnalytics.overview" {
        let (id, email) = match crate::auth_user(token).await {
            Some(u) => u,
            None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid"),
        };
        if !crate::is_founder(&id, &email).await {
            return fail(StatusCode::FORBIDDEN, "founder_only", "Founder only");
        }
        return match crate::sb_rpc("founder_analytics_overview", json!({})).await {
            Ok(v) => crate::ok(v).into_response(),
            Err(e) => sql_fail(&e),
        };
    }
    let need = match c::need_of(proc) {
        Some(n) => n,
        None => return fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    };
    let org_in = input.get("org_id").and_then(|x| x.as_str()).unwrap_or("");
    let me = match crate::mail_identity(token, org_in).await {
        Ok(m) => m,
        Err((StatusCode::CONFLICT, _, _)) => {
            return fail(StatusCode::NOT_IMPLEMENTED, "not_implemented_for_account", "Analytics needs a workspace mailbox.")
        }
        Err((status, code, detail)) => return fail(status, code, &detail),
    };
    // Package gate — SERVER par. (resolve_plan na mile to basic: kabhi zyada nahi kholta.)
    let plan = crate::sb_rpc("resolve_plan", json!({ "_user_id": me.id, "_email": me.email }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .unwrap_or_else(|| "basic".to_string());
    if let Err(msg) = c::allowed(need, &plan) {
        return fail(StatusCode::FORBIDDEN, "feature_not_available", msg);
    }
    if !allowed_now(&me.id) {
        return fail(StatusCode::TOO_MANY_REQUESTS, "too_many_requests", "Too many requests — please try again in a minute.");
    }
    let my_email = me.email.trim().to_lowercase();

    let result = match proc {
        "analytics.team" => {
            let role = crate::sb_select(&format!("org_members?select=role&org_id=eq.{}&user_id=eq.{}&limit=1", me.org_id, me.id))
                .await
                .ok()
                .and_then(|v| v.as_array().and_then(|a| a.first().cloned()))
                .and_then(|r| r.get("role").and_then(|x| x.as_str()).map(|s| s.to_string()))
                .unwrap_or_default();
            if !c::can_see_team(&role) {
                return fail(StatusCode::FORBIDDEN, "owner_or_admin_only", "The team report is for workspace owners and admins.");
            }
            crate::sb_rpc("analytics_team", json!({ "p_user": me.id, "p_org": me.org_id })).await
        }
        "analytics.promiseSla" => {
            crate::sb_rpc("analytics_promise_sla", json!({ "p_user": me.id, "p_org": me.org_id, "p_email": my_email })).await
        }
        _ => {
            let addrs = org_addresses(&me.org_id, &my_email).await;
            match proc {
                "analytics.responseDebt" => crate::sb_rpc("analytics_response_debt", json!({ "p_user": me.id, "p_addresses": addrs })).await,
                "analytics.threadEconomics" => crate::sb_rpc("analytics_thread_economics", json!({ "p_user": me.id, "p_addresses": addrs })).await,
                "analytics.deepWork" => {
                    let tz = c::clean_tz(input.get("tz").and_then(|x| x.as_str()).unwrap_or(""));
                    crate::sb_rpc("analytics_deep_work", json!({ "p_user": me.id, "p_addresses": addrs, "p_tz": tz })).await
                }
                "analytics.attentionLeaks" => crate::sb_rpc("analytics_attention_leaks", json!({ "p_user": me.id, "p_addresses": addrs })).await,
                "analytics.forecast" => crate::sb_rpc("analytics_forecast", json!({ "p_user": me.id, "p_addresses": addrs })).await,
                _ => return fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
            }
        }
    };
    match result {
        Ok(v) => crate::ok(v).into_response(),
        Err(e) => sql_fail(&e),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn owns_exactly_the_analytics_procs() {
        for p in [
            "analytics.responseDebt", "analytics.threadEconomics", "analytics.deepWork", "analytics.attentionLeaks",
            "analytics.promiseSla", "analytics.forecast", "analytics.team", "founderAnalytics.overview",
        ] {
            assert!(owns(p), "{p}");
        }
        assert!(!owns("mail.threads") && !owns("analytics.nope"));
    }

    #[test]
    fn missing_function_is_recognised() {
        assert!(is_missing_function(r#"{"code":"PGRST202","message":"Could not find the function public.analytics_team"}"#));
        assert!(!is_missing_function(r#"{"code":"23505"}"#));
    }

    #[test]
    fn rate_limit_is_per_user_and_bounded() {
        let u = format!("an-rl-{}", now_ms());
        for _ in 0..RATE_LIMIT {
            assert!(allowed_now(&u));
        }
        assert!(!allowed_now(&u));
        assert!(allowed_now(&format!("{u}-other")));
    }
}
