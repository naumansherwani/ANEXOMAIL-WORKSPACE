// ============================================================================
// ANEXOMAIL / ANEXOChat — RUST PRIMARY ENGINE
//
// NANO COMMAND (server par):
//   cp /opt/anexomail-rust/src/main.rs /opt/anexomail-rust/src/main.rs.bak.$(date +%s)
//   nano /opt/anexomail-rust/src/main.rs     # select all -> paste -> Ctrl+O, Ctrl+X
//   cd /opt/anexomail-rust && cargo build --release && pm2 restart anexomail-rust
//
// BLUEPRINT LOCK (anexochat/docs/anexochat-blueprint.md PART 0 + PHASE 2):
//   PRIMARY  : Rust engine — tRPC-style /rpc/* (TCP 3200 behind Caddy HTTP/3)
//              + WebTransport / HTTP3 / QUIC realtime on UDP 3443
//   FALLBACK : Bun service /api/chat/* (port 3300) — sirf jab WT/RPC na chale
//   TRUTH    : Supabase #4 / PostgreSQL (RLS) — Rust apna data invent nahi karta
//   API-FREE : koi external chat/AI/weather/file API nahi
//
// ENV (/opt/anexomail-rust/.env):
//   SUPABASE4_URL=https://<ref>.supabase.co
//   SUPABASE4_SERVICE_ROLE_KEY=<service role>
//   ANEXOCHAT_WT_PORT=3443
//   ANEXOCHAT_WT_CERT=/etc/anexochat/wt/fullchain.pem
//   ANEXOCHAT_WT_KEY=/etc/anexochat/wt/privkey.pem
// WT cert/key na hon to WebTransport OFF rehta hai aur /rpc/health sach bolta
// hai (`webtransport: "unavailable"`) — jhooti capability kabhi nahi.
// ============================================================================

use axum::{
    extract::Path,
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde_json::{json, Value};
use std::net::SocketAddr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use tower_http::cors::{Any, CorsLayer};

const PORT: u16 = 3200;
const OBSERVABILITY_PORT: u16 = 3600;
/// PHASE 31A — SFU: TCP control (loopback) + UDP media forwarding (public).
const SFU_CONTROL_PORT: u16 = 3500;
const SFU_MEDIA_PORT: u16 = 3501;
static WT_LIVE: AtomicBool = AtomicBool::new(false);
static SFU_LIVE: AtomicBool = AtomicBool::new(false);

fn ok(data: Value) -> impl IntoResponse {
    (StatusCode::OK, Json(json!({ "result": { "data": data } })))
}

fn err(status: StatusCode, code: &str, message: &str) -> impl IntoResponse + use<> {
    (
        status,
        Json(json!({ "error": { "code": code, "message": message } })),
    )
}

fn env_var(key: &str) -> String {
    std::env::var(key).unwrap_or_default()
}

/// PHASE 19/21 sealing key. `.env` kabhi deploy script se touch nahi hoti, is
/// liye DEVICE_VAULT_KEY optional hai: na ho to service-role key se derive
/// hoti hai (server ke andar hi rehti hai, kabhi response mein nahi jati).
fn vault_key() -> String {
    let k = env_var("DEVICE_VAULT_KEY");
    if !k.is_empty() {
        return k;
    }
    let base = env_var("SUPABASE4_SERVICE_ROLE_KEY");
    if base.is_empty() {
        return "anexomail-vault-unconfigured".to_string();
    }
    format!("anexomail-vault:{}", &base[base.len().saturating_sub(32)..])
}


fn bearer(headers: &HeaderMap) -> Option<String> {
    headers
        .get("authorization")?
        .to_str()
        .ok()?
        .strip_prefix("Bearer ")
        .map(|s| s.to_string())
}

// ── Supabase #4 (single source of truth) ────────────────────────────────────
fn sb() -> Option<(String, String)> {
    let url = env_var("SUPABASE4_URL");
    let key = env_var("SUPABASE4_SERVICE_ROLE_KEY");
    if url.is_empty() || key.is_empty() {
        return None;
    }
    Some((url.trim_end_matches('/').to_string(), key))
}

async fn sb_rpc(func: &str, body: Value) -> Result<Value, String> {
    let (url, key) = sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let client = reqwest::Client::new();
    let res = client
        .post(format!("{url}/rest/v1/rpc/{func}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .header("content-type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = res.status();
    let payload: Value = res.json().await.unwrap_or(Value::Null);
    if !status.is_success() {
        return Err(payload.to_string());
    }
    Ok(payload)
}

async fn sb_select(path_and_query: &str) -> Result<Value, String> {
    let (url, key) = sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let client = reqwest::Client::new();
    let res = client
        .get(format!("{url}/rest/v1/{path_and_query}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = res.status();
    let payload: Value = res.json().await.unwrap_or(Value::Null);
    if !status.is_success() {
        return Err(payload.to_string());
    }
    Ok(payload)
}

struct Me {
    id: String,
    email: String,
    workspace_id: String,
}

/// Identity Supabase Auth se — Rust apna session store nahi rakhta.
async fn auth_user(token: &str) -> Option<(String, String)> {
    let (url, key) = sb()?;
    let client = reqwest::Client::new();
    let res = client
        .get(format!("{url}/auth/v1/user"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {token}"))
        .send()
        .await
        .ok()?;
    if !res.status().is_success() {
        return None;
    }
    let body: Value = res.json().await.ok()?;
    let id = body.get("id")?.as_str()?.to_string();
    let email = body
        .get("email")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    Some((id, email))
}

/// Gate DB ka `chat_access()` — Basic false. Pro / Business / Business Pro / AI true.
async fn chat_identity(token: &str) -> Result<Me, (StatusCode, &'static str, String)> {
    let (id, email) = auth_user(token)
        .await
        .ok_or((StatusCode::UNAUTHORIZED, "unauthorized", String::new()))?;

    let gate = sb_rpc("chat_access", json!({ "_user_id": id }))
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, "db_error", e))?;
    if gate.as_bool() != Some(true) {
        return Err((
            StatusCode::FORBIDDEN,
            "chat_not_entitled",
            "Chat is on Personal Pro, Business and Business Pro.".to_string(),
        ));
    }

    let domain = email.split('@').nth(1).unwrap_or("Workspace").to_string();
    let ws = sb_rpc(
        "chat_ensure_workspace",
        json!({ "_user": id, "_name": domain }),
    )
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, "db_error", e))?;
    let workspace_id = ws.as_str().unwrap_or_default().to_string();

    Ok(Me {
        id,
        email,
        workspace_id,
    })
}

/// Mail inbox identity — org_members, NOT chat_access.
/// Basic/Pro ko mail chahiye; ANEXOChat gate yahan nahi.
struct MailMe {
    id: String,
    email: String,
    org_id: String,
}

async fn mail_identity(
    token: &str,
    requested_org: &str,
) -> Result<MailMe, (StatusCode, &'static str, String)> {
    let (id, email) = auth_user(token)
        .await
        .ok_or((StatusCode::UNAUTHORIZED, "unauthorized", String::new()))?;

    let rows = sb_select(&format!(
        "org_members?select=org_id&user_id=eq.{id}"
    ))
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, "db_error", e))?;

    let ids: Vec<String> = rows
        .as_array()
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter_map(|r| r.get("org_id")?.as_str().map(|s| s.to_string()))
        .collect();
    if ids.is_empty() {
        return Err((
            StatusCode::CONFLICT,
            "no_workspace",
            "no_workspace".to_string(),
        ));
    }
    let org_id = if !requested_org.is_empty() && ids.iter().any(|o| o == requested_org) {
        requested_org.to_string()
    } else {
        ids[0].clone()
    };
    Ok(MailMe {
        id,
        email: email,
        org_id,
    })
}

async fn sb_patch(path_and_query: &str, body: Value) -> Result<Value, String> {
    let (url, key) = sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let client = reqwest::Client::new();
    let res = client
        .patch(format!("{url}/rest/v1/{path_and_query}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .header("content-type", "application/json")
        .header("prefer", "return=minimal")
        .json(&body)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = res.status();
    if !status.is_success() {
        let payload: Value = res.json().await.unwrap_or(Value::Null);
        return Err(payload.to_string());
    }
    Ok(json!({ "ok": true }))
}

async fn sb_insert(path: &str, body: Value) -> Result<Value, String> {
    let (url, key) = sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let client = reqwest::Client::new();
    let res = client
        .post(format!("{url}/rest/v1/{path}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .header("content-type", "application/json")
        .header("prefer", "return=representation")
        .json(&body)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = res.status();
    let payload: Value = res.json().await.unwrap_or(Value::Null);
    if !status.is_success() {
        return Err(payload.to_string());
    }
    Ok(payload)
}

/// Insert-or-update on a unique constraint (e.g. work_notes: one row per org_id+thread_id).
/// on_conflict_cols must match an existing unique/exclusion constraint's columns.
async fn sb_upsert(path: &str, on_conflict_cols: &str, body: Value) -> Result<Value, String> {
    let (url, key) = sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let client = reqwest::Client::new();
    let res = client
        .post(format!("{url}/rest/v1/{path}?on_conflict={on_conflict_cols}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .header("content-type", "application/json")
        .header("prefer", "resolution=merge-duplicates,return=representation")
        .json(&body)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = res.status();
    let payload: Value = res.json().await.unwrap_or(Value::Null);
    if !status.is_success() {
        return Err(payload.to_string());
    }
    Ok(payload)
}

async fn sb_count(path_and_query: &str) -> Result<i64, String> {
    let (url, key) = sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let client = reqwest::Client::new();
    let res = client
        .get(format!("{url}/rest/v1/{path_and_query}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .header("prefer", "count=exact")
        .header("range", "0-0")
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !res.status().is_success() && res.status().as_u16() != 416 {
        let payload: Value = res.json().await.unwrap_or(Value::Null);
        return Err(payload.to_string());
    }
    let cr = res
        .headers()
        .get("content-range")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    let total = cr.split('/').nth(1).unwrap_or("0");
    Ok(total.parse().unwrap_or(0))
}

fn mail_q_safe(raw: &str) -> String {
    raw.chars()
        .filter(|c| c.is_ascii_alphanumeric() || matches!(c, ' ' | '@' | '.' | '-' | '_'))
        .take(80)
        .collect()
}

fn mail_thread_item(t: &Value, labels: Vec<Value>) -> Value {
    let unread = t
        .get("unread")
        .and_then(|v| v.as_bool())
        .or_else(|| t.get("is_unread").and_then(|v| v.as_bool()))
        .unwrap_or(false);
    json!({
        "id": t.get("id"),
        "subject": t.get("subject").and_then(|v| v.as_str()).unwrap_or(""),
        "snippet": t.get("snippet"),
        "from_name": t.get("from_name"),
        "from_address": t.get("from_address").and_then(|v| v.as_str()).unwrap_or(""),
        "account_id": t.get("account_id"),
        "account_address": t.get("mailbox_address"),
        "message_count": t.get("message_count").and_then(|v| v.as_i64()).unwrap_or(0),
        "unread": unread,
        "starred": t.get("starred").and_then(|v| v.as_bool()).unwrap_or(false),
        "has_attachments": t.get("has_attachments").and_then(|v| v.as_bool()).unwrap_or(false),
        "status": t.get("status").and_then(|v| v.as_str()).or_else(|| t.get("state").and_then(|v| v.as_str())).unwrap_or("open"),
        "assignee": t.get("assignee"),
        "labels": labels,
        "category": t.get("category"),
        "snoozed_until": t.get("snoozed_until"),
        "last_message_at": t.get("last_message_at").cloned().or_else(|| t.get("created_at").cloned()),
    })
}

async fn mail_labels_for(thread_ids: &[String]) -> std::collections::HashMap<String, Vec<Value>> {
    let mut map = std::collections::HashMap::new();
    if thread_ids.is_empty() {
        return map;
    }
    let list = thread_ids.join(",");
    let Ok(data) = sb_select(&format!(
        "mail_thread_labels?select=thread_id,mail_labels(name)&thread_id=in.({list})"
    ))
    .await else {
        return map;
    };
    for row in data.as_array().cloned().unwrap_or_default() {
        let tid = row
            .get("thread_id")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        if tid.is_empty() {
            continue;
        }
        if let Some(name) = row
            .get("mail_labels")
            .and_then(|v| v.get("name"))
            .and_then(|v| v.as_str())
        {
            map.entry(tid)
                .or_insert_with(Vec::new)
                .push(Value::String(name.to_string()));
        }
    }
    map
}

async fn mail_query_threads(org_id: &str, input: &Value) -> Result<Value, String> {
    let folder = {
        let f = s(input, "folder");
        if f.is_empty() {
            "inbox".to_string()
        } else {
            f
        }
    };
    let account = s(input, "account");
    let category = s(input, "category");
    let label = s(input, "label");
    let q = mail_q_safe(&s(input, "q"));

    let mut thread_filter = String::new();
    if !label.is_empty() {
        let lab = sb_select(&format!(
            "mail_labels?select=id&org_id=eq.{org_id}&or=(id.eq.{label},name.eq.{label})&limit=1"
        ))
        .await;
        let lab_id = lab
            .ok()
            .and_then(|v| v.as_array().cloned())
            .and_then(|arr| arr.into_iter().next())
            .and_then(|r| r.get("id")?.as_str().map(|s| s.to_string()))
            .unwrap_or(label.clone());
        let links = match sb_select(&format!(
            "mail_thread_labels?select=thread_id&label_id=eq.{lab_id}"
        ))
        .await
        {
            Ok(v) => v,
            Err(_) => return Ok(json!({ "threads": [] })),
        };
        let ids: Vec<String> = links
            .as_array()
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .filter_map(|r| r.get("thread_id")?.as_str().map(|s| s.to_string()))
            .collect();
        if ids.is_empty() {
            return Ok(json!({ "threads": [] }));
        }
        thread_filter = format!("&id=in.({})", ids.join(","));
    }

    let mut path = format!(
        "mail_threads?select=*&org_id=eq.{org_id}&folder=eq.{folder}&order=last_message_at.desc&limit=100{thread_filter}"
    );
    if !account.is_empty() {
        path.push_str(&format!("&account_id=eq.{account}"));
    }
    if !category.is_empty() {
        path.push_str(&format!("&category=eq.{category}"));
    }
    if !q.is_empty() {
        let enc = q.replace(' ', "%20");
        path.push_str(&format!(
            "&or=(subject.ilike.*{enc}*,snippet.ilike.*{enc}*,from_address.ilike.*{enc}*)"
        ));
    }

    let data = sb_select(&path).await?;
    let rows: Vec<Value> = data.as_array().cloned().unwrap_or_default();
    let ids: Vec<String> = rows
        .iter()
        .filter_map(|t| t.get("id")?.as_str().map(|s| s.to_string()))
        .collect();
    let lmap = mail_labels_for(&ids).await;
    let threads: Vec<Value> = rows
        .iter()
        .map(|t| {
            let id = t.get("id").and_then(|v| v.as_str()).unwrap_or("");
            mail_thread_item(t, lmap.get(id).cloned().unwrap_or_default())
        })
        .collect();
    Ok(json!({ "threads": threads }))
}

async fn mail_inbox_stamp(org_id: &str) -> Result<(i64, String), String> {
    let rows = sb_select(&format!(
        "mail_threads?select=unread,last_message_at&org_id=eq.{org_id}&folder=eq.inbox&order=last_message_at.desc&limit=40"
    ))
    .await?;
    let arr = rows.as_array().cloned().unwrap_or_default();
    let unread = arr
        .iter()
        .filter(|t| t.get("unread").and_then(|v| v.as_bool()) == Some(true))
        .count() as i64;
    let max_at = arr
        .first()
        .and_then(|t| t.get("last_message_at").and_then(|v| v.as_str()))
        .unwrap_or("")
        .to_string();
    Ok((unread, max_at))
}

// ── BILLING PROCEDURES — PRIMARY on Rust :3200 ──────────────────────────────
//
// billing.subscription  → get_billing_subscription(p_user_id)  [E5 SQL]
// billing.invoices       → get_billing_invoices(p_user_id)       [E5 SQL]
//
// Fallback: Bun /api/billing/subscription aur /api/billing/invoices
// (rpcOrRest frontend mein: Rust pehle, Bun jab 404/502/503)
//
// Polar Rust payment :3400 NO-TOUCH. Yeh sirf subscription read karta hai.
// plans.ts prices NO-TOUCH. SQL RPCs (E5) se real Polar data aata hai.
async fn dispatch_billing(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    let (user_id, _email) = match auth_user(token).await {
        Some(u) => u,
        None => {
            return err(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid")
                .into_response()
        }
    };

    let result: Result<Value, String> = match proc {
        // GET /rpc/billing.subscription
        // Returns: Subscription { plan, state, price_per_seat, interval, seats, ... }
        "billing.subscription" => {
            sb_rpc(
                "get_billing_subscription",
                json!({ "p_user_id": user_id }),
            )
            .await
            .map(|data| {
                // If RPC returns null (no subscription yet) return empty state
                if data.is_null() {
                    json!({
                        "plan": null,
                        "state": "none",
                        "price_per_seat": 0,
                        "currency": "GBP",
                        "interval": "month",
                        "seats": 0,
                        "seats_used": 0,
                        "storage_per_mailbox_gb": null,
                        "renews_at": null,
                        "cancel_at": null
                    })
                } else {
                    data
                }
            })
        }

        // GET /rpc/billing.invoices
        // Returns: { invoices: Invoice[] }
        "billing.invoices" => {
            sb_rpc(
                "get_billing_invoices",
                json!({ "p_user_id": user_id }),
            )
            .await
            .map(|data| {
                if data.is_null() {
                    json!({ "invoices": [] })
                } else {
                    data
                }
            })
        }

        // POST /rpc/billing.settle  { checkout_id }   (E23, 14 Oct 2026)
        // /checkout/done Polar se "paid" dekh kar yeh bulata hai. Rust yahan sirf
        // Supabase ke verified RPCs chalata hai: billing_intent_confirm amount +
        // currency + product khud check karta hai, aur account 'active' hona
        // entitlement_state trigger (E23 SQL) karta hai. Intent abhi "open" ho
        // (Polar se paisa pull karna baqi) to woh hissa Rust mein nahi hai ->
        // 503 -> frontend (rpcOrRest) Bun fallback /api/billing/settle bulata hai.
        "billing.settle" => {
            let checkout_id = s(input, "checkout_id").trim().to_string();
            if checkout_id.is_empty()
                || !checkout_id
                    .chars()
                    .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
            {
                return err(
                    StatusCode::BAD_REQUEST,
                    "checkout_id_required",
                    "checkout_id is required",
                )
                .into_response();
            }
            let rows = sb_select(&format!(
                "billing_intents?select=id,state,currency,product_id&polar_checkout_id=eq.{checkout_id}&user_id=eq.{user_id}&limit=1"
            ))
            .await;
            let intent = match rows {
                Ok(v) => v.as_array().and_then(|a| a.first()).cloned(),
                Err(e) => {
                    return err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response()
                }
            };
            let intent = match intent {
                Some(i) => i,
                None => {
                    return err(
                        StatusCode::NOT_FOUND,
                        "intent_not_found",
                        "No such checkout for this account",
                    )
                    .into_response()
                }
            };
            let state = intent
                .get("state")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            match state.as_str() {
                "entitled" => Ok(json!({ "settled": true, "state": "entitled" })),
                "paid" | "stuck" => {
                    let intent_id = intent
                        .get("id")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string();
                    let currency = intent
                        .get("currency")
                        .and_then(|v| v.as_str())
                        .filter(|c| !c.is_empty())
                        .unwrap_or("GBP")
                        .to_string();
                    let product_id = intent.get("product_id").cloned().unwrap_or(Value::Null);
                    // Bun jaisa: confirm ka error yahan settle ko fail nahi karta
                    // (jaise payment_amount_mismatch) -- state dobara padhi jati hai.
                    let _ = sb_rpc(
                        "billing_intent_confirm",
                        json!({
                            "p_intent": intent_id,
                            "p_checkout_id": checkout_id,
                            "p_order_id": Value::Null,
                            "p_amount": Value::Null,
                            "p_source": "settle",
                            "p_currency": currency,
                            "p_product_id": product_id,
                        }),
                    )
                    .await;
                    let fresh = sb_select(&format!(
                        "billing_intents?select=state&id=eq.{intent_id}&limit=1"
                    ))
                    .await
                    .ok()
                    .and_then(|v| {
                        v.as_array()
                            .and_then(|a| a.first())
                            .and_then(|r| r.get("state"))
                            .and_then(|x| x.as_str())
                            .map(|x| x.to_string())
                    })
                    .unwrap_or_else(|| state.clone());
                    Ok(json!({ "settled": fresh == "entitled", "state": fresh }))
                }
                "open" => {
                    return err(
                        StatusCode::SERVICE_UNAVAILABLE,
                        "settle_pull_in_bun",
                        "Open checkouts are pulled from Polar by the Bun fallback.",
                    )
                    .into_response()
                }
                _ => Ok(json!({ "settled": false, "state": state })),
            }
        }

        _ => Err(format!("{proc} billing procedure nahi hai")),
    };

    match result {
        Ok(data) => ok(data).into_response(),
        Err(e) => err(StatusCode::INTERNAL_SERVER_ERROR, "billing_error", &e).into_response(),
    }
}

/// CRM procedures — genuinely new (no Bun equivalent existed as a named RPC).
/// work_promises is already fetched by Bun's /crm/live for radar/next_actions
/// but the raw list was never returned — this closes that gap.
async fn dispatch_crm(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    let requested = s(input, "org_id");
    let me = match mail_identity(token, &requested).await {
        Ok(me) => me,
        Err((status, code, detail)) => {
            return (
                status,
                Json(json!({ "error": { "code": code, "message": detail } })),
            )
                .into_response()
        }
    };

    let plan = sb_rpc(
        "resolve_plan",
        json!({ "_user_id": me.id, "_email": me.email }),
    )
    .await
    .unwrap_or(json!("basic"));
    let plan_str = plan.as_str().unwrap_or("basic").to_string();
    if plan_str == "basic" {
        return err(
            StatusCode::FORBIDDEN,
            "feature_not_available",
            "CRM is a Pro+ feature.",
        )
        .into_response();
    }

    let result: Result<Value, String> = match proc {
        "crm.promises.list" => {
            // Real columns confirmed against work_promises (no thread_subject
            // column exists there — the pre-existing Bun /crm/live query
            // asked for it too and silently swallowed the resulting error).
            sb_rpc("crm_promises_open", json!({ "_org_id": me.org_id }))
                .await
                .map(|data| json!({ "promises": data }))
        }
        "crm.followups.list" => {
            // Configurable per-user threshold (default 3 days).
            let pref_rows = sb_select(&format!(
                "account_profiles?select=preferences&user_id=eq.{}",
                me.id
            ))
            .await
            .unwrap_or(json!([]));
            let days: i64 = pref_rows
                .as_array()
                .and_then(|a| a.first())
                .and_then(|r| r.get("preferences"))
                .and_then(|p| p.get("followup_days"))
                .and_then(|v| v.as_i64())
                .unwrap_or(3);

            sb_rpc(
                "crm_followups",
                json!({ "_org_id": me.org_id, "_days": days }),
            )
            .await
            .map(|data| json!({ "followups": data, "days": days }))
        }
        "crm.followups.setDays" => {
            let days = n(input, "days").unwrap_or(3).clamp(1, 30);
            sb_rpc(
                "set_user_pref",
                json!({ "_user_id": me.id, "_key": "followup_days", "_value": days }),
            )
            .await
            .map(|_| json!({ "ok": true, "days": days }))
        }
        "crm.leads.suggest" => {
            // Point 7 (first-response timer): last_mail_at is returned so the
            // frontend can show "Xh since first contact" — no extra storage
            // needed, the clock is just derived from the mail timestamp.
            let own_rows = sb_select(&format!(
                "mailboxes?select=address&org_id=eq.{}",
                me.org_id
            ))
            .await
            .unwrap_or(json!([]));
            let own_addrs: Vec<String> = own_rows
                .as_array()
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter_map(|r| r.get("address").and_then(|v| v.as_str()).map(|a| a.to_lowercase()))
                .collect();

            sb_rpc(
                "crm_capture_suggestions",
                json!({ "_org_id": me.org_id, "_own_addrs": own_addrs }),
            )
            .await
            .map(|data| json!({ "suggestions": data }))
        }
        "crm.leads.dismiss" => {
            // Point 6: "Not a lead" — remembered per org so it never resurfaces.
            let email = s(input, "email").to_lowercase();
            if email.is_empty() {
                Err("email_required".to_string())
            } else {
                sb_upsert(
                    "crm_lead_dismissals",
                    "org_id,email",
                    json!({ "org_id": me.org_id, "email": email }),
                )
                .await
                .map(|_| json!({ "ok": true }))
            }
        }
        "crm.contacts.recompute" => {
            // Points 2+3 (Memory): populates the already-wired-but-empty
            // contact_stats table. resolve_plan gate already applied above.
            sb_rpc("recompute_contact_stats", json!({ "_org_id": me.org_id }))
                .await
                .map(|updated| json!({ "ok": true, "updated": updated }))
        }
        "crm.contacts.setNotes" => {
            // Point 6: contacts.notes already exists as a column, no new table.
            let contact_id = s(input, "contact_id");
            let notes = s(input, "notes");
            if contact_id.is_empty() {
                Err("contact_id_required".to_string())
            } else {
                sb_patch(
                    &format!("contacts?id=eq.{contact_id}&org_id=eq.{}", me.org_id),
                    json!({ "notes": notes }),
                )
                .await
                .map(|_| json!({ "ok": true }))
            }
        }
        "crm.contacts.addAlias" => {
            // Point 7 (basic): merge a second email into an existing
            // contact's addresses[] array via the add_contact_alias() RPC.
            let contact_id = s(input, "contact_id");
            let email = s(input, "email").to_lowercase();
            if contact_id.is_empty() || email.is_empty() {
                Err("contact_id_and_email_required".to_string())
            } else {
                sb_rpc(
                    "add_contact_alias",
                    json!({ "_contact_id": contact_id, "_email": email }),
                )
                .await
                .map(|addresses| json!({ "ok": true, "addresses": addresses }))
            }
        }
        "crm.promises.board" => {
            // Loop step 4: promises with mine/theirs and kept/late/broken phases.
            // Detection (scan) only runs when the page asks for it with scan:true.
            let side = s(input, "side");
            let limit = n(input, "limit").unwrap_or(100);
            let do_scan = input.get("scan").and_then(|v| v.as_bool()).unwrap_or(false);
            if do_scan {
                let _ = sb_rpc(
                    "crm_promises_scan",
                    json!({ "_org_id": me.org_id, "_days": 30 }),
                )
                .await;
            }
            sb_rpc(
                "crm_promises_board",
                json!({
                    "_org_id": me.org_id,
                    "_side": if side.is_empty() { Value::Null } else { json!(side) },
                    "_limit": limit,
                }),
            )
            .await
            .map(|data| json!({ "promises": data }))
        }
        "crm.next" => {
            // Loop step 9: one ranked list built only from risk, promises and health.
            let limit = n(input, "limit").unwrap_or(20);
            sb_rpc(
                "crm_next",
                json!({ "_org_id": me.org_id, "_limit": limit }),
            )
            .await
            .map(|data| json!({ "next": data }))
        }
        "crm.team" => {
            // Loop step 8, team part: which teammate talks to which outside person. Nothing is written.
            let limit = n(input, "limit").unwrap_or(100);
            sb_rpc(
                "crm_team_graph",
                json!({ "_org_id": me.org_id, "_limit": limit }),
            )
            .await
            .map(|data| json!({ "team": data }))
        }
        "crm.graph" => {
            // Loop step 8: people grouped by company, with their deals. Nothing is written.
            let limit = n(input, "limit").unwrap_or(60);
            sb_rpc(
                "crm_graph",
                json!({ "_org_id": me.org_id, "_limit": limit }),
            )
            .await
            .map(|data| json!({ "graph": data }))
        }
        "crm.risk" => {
            // Loop step 6: only dangers, each with its reason. Nothing is written.
            let limit = n(input, "limit").unwrap_or(50);
            sb_rpc(
                "crm_risk",
                json!({ "_org_id": me.org_id, "_limit": limit }),
            )
            .await
            .map(|data| json!({ "risks": data }))
        }
        "crm.health" => {
            // Loop step 5: who needs attention. Fresh calculation, nothing is written.
            let limit = n(input, "limit").unwrap_or(100);
            sb_rpc(
                "crm_health",
                json!({ "_org_id": me.org_id, "_limit": limit }),
            )
            .await
            .map(|data| json!({ "people": data }))
        }
        "crm.timeline" => {
            // Loop step 3: everyone's activity, newest first, optional filters.
            let contact_id = s(input, "contact_id");
            let before = s(input, "before");
            let kinds: Vec<String> = input
                .get("kinds")
                .and_then(|v| v.as_array())
                .map(|a| {
                    a.iter()
                        .filter_map(|x| x.as_str().map(|t| t.to_string()))
                        .collect()
                })
                .unwrap_or_default();
            let limit = n(input, "limit").unwrap_or(50);
            sb_rpc(
                "crm_timeline",
                json!({
                    "_org_id": me.org_id,
                    "_contact_id": if contact_id.is_empty() { Value::Null } else { json!(contact_id) },
                    "_kinds": if kinds.is_empty() { Value::Null } else { json!(kinds) },
                    "_before": if before.is_empty() { Value::Null } else { json!(before) },
                    "_limit": limit,
                }),
            )
            .await
            .map(|data| json!({ "timeline": data }))
        }
        "crm.person.timeline" => {
            // Point 1: unified per-person feed (mail, meetings, tasks, deals).
            let contact_id = s(input, "contact_id");
            if contact_id.is_empty() {
                Err("contact_id_required".to_string())
            } else {
                sb_rpc(
                    "crm_person_timeline",
                    json!({ "_org_id": me.org_id, "_contact_id": contact_id }),
                )
                .await
                .map(|data| json!({ "timeline": data }))
            }
        }
        "crm.contacts.extractSignature" => {
            // Point 4: phone + job-title pulled from the latest inbound mail.
            let contact_id = s(input, "contact_id");
            if contact_id.is_empty() {
                Err("contact_id_required".to_string())
            } else {
                sb_rpc(
                    "crm_extract_signature",
                    json!({ "_org_id": me.org_id, "_contact_id": contact_id }),
                )
                .await
            }
        }
        "crm.people.list" => {
            // Migrated from Bun's loadPeople()/CONTACT_SELECT — using the
            // SAME fix (health_score/last_contact_at only exist on
            // contact_stats, never as raw columns on contacts).
            sb_select(&format!(
                "contacts?select=id,display_name,primary_address,company_domain,stats:contact_stats(messages_in,messages_out,avg_reply_minutes,open_threads,last_contact_at,relationship,health_score)&org_id=eq.{}&limit=400",
                me.org_id
            ))
            .await
            .map(|rows| {
                let people: Vec<Value> = rows
                    .as_array()
                    .cloned()
                    .unwrap_or_default()
                    .into_iter()
                    .map(|row| {
                        let stats = row.get("stats").cloned().unwrap_or(json!({}));
                        json!({
                            "id": row.get("id").cloned().unwrap_or(Value::Null),
                            "display_name": row.get("display_name").cloned().unwrap_or(Value::Null),
                            "primary_address": row.get("primary_address").cloned().unwrap_or(Value::Null),
                            "company_name": row.get("company_domain").cloned().unwrap_or(Value::Null),
                            "relationship": stats.get("relationship").cloned().unwrap_or(Value::Null),
                            "health_score": stats.get("health_score").cloned().unwrap_or(Value::Null),
                            "last_contact_at": stats.get("last_contact_at").cloned().unwrap_or(Value::Null),
                            "open_threads": stats.get("open_threads").cloned().unwrap_or(json!(0)),
                        })
                    })
                    .collect();
                json!({ "people": people })
            })
        }
        _ => Err(format!("{proc} not implemented")),
    };

    match result {
        Ok(v) => ok(v).into_response(),
        Err(e) => err(StatusCode::BAD_REQUEST, "crm_error", &e).into_response(),
    }
}

/// F3 mail RPC — PRIMARY. Bun `/api/mail/*` sirf jab yeh 404/502.
async fn dispatch_mail(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    let requested = s(input, "org_id");
    let me = match mail_identity(token, &requested).await {
        Ok(me) => me,
        Err((status, code, detail)) => {
            return (
                status,
                Json(json!({ "error": { "code": code, "message": detail } })),
            )
                .into_response()
        }
    };
    let _ = &me.email;

    let result: Result<Value, String> = match proc {
        "mail.threads" | "mail.search" => mail_query_threads(&me.org_id, input).await,
        "mail.counts" => {
            let folders = [
                "inbox", "assigned", "waiting", "sent", "drafts", "archive", "spam", "trash",
            ];
            let mut out = serde_json::Map::new();
            for folder in folders {
                let total = sb_count(&format!(
                    "mail_threads?select=id&org_id=eq.{}&folder=eq.{folder}",
                    me.org_id
                ))
                .await
                .unwrap_or(0);
                let unread = sb_count(&format!(
                    "mail_threads?select=id&org_id=eq.{}&folder=eq.{folder}&unread=eq.true",
                    me.org_id
                ))
                .await
                .unwrap_or(0);
                out.insert(folder.to_string(), json!({ "total": total, "unread": unread }));
            }
            Ok(json!({ "folders": out }))
        }
        "mail.accounts" => {
            let mut rows = sb_select(&format!(
                "mailboxes?select=id,address,box_type&org_id=eq.{}&order=address",
                me.org_id
            ))
            .await
            .unwrap_or(json!([]));
            if !rows.as_array().map(|a| !a.is_empty()).unwrap_or(false) {
                rows = sb_select(&format!(
                    "mail_accounts?select=id,address&org_id=eq.{}&order=address",
                    me.org_id
                ))
                .await
                .unwrap_or(json!([]));
            }
            let unread_rows = sb_select(&format!(
                "mail_threads?select=account_id,mailbox_address&org_id=eq.{}&unread=eq.true&limit=5000",
                me.org_id
            ))
            .await
            .unwrap_or(json!([]));
            let mut by_id: std::collections::HashMap<String, i64> = std::collections::HashMap::new();
            let mut by_addr: std::collections::HashMap<String, i64> = std::collections::HashMap::new();
            for r in unread_rows.as_array().cloned().unwrap_or_default() {
                if let Some(id) = r.get("account_id").and_then(|v| v.as_str()) {
                    *by_id.entry(id.to_string()).or_insert(0) += 1;
                }
                if let Some(addr) = r.get("mailbox_address").and_then(|v| v.as_str()) {
                    *by_addr.entry(addr.to_lowercase()).or_insert(0) += 1;
                }
            }
            let accounts: Vec<Value> = rows
                .as_array()
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .map(|a| {
                    let id = a.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
                    let address = a.get("address").and_then(|v| v.as_str()).unwrap_or("").to_string();
                    let kind = if a.get("box_type").and_then(|v| v.as_str()) == Some("alias") {
                        "shared"
                    } else {
                        "personal"
                    };
                    let unread = *by_id.get(&id).unwrap_or(&0)
                        + *by_addr.get(&address.to_lowercase()).unwrap_or(&0);
                    json!({
                        "id": id,
                        "address": address,
                        "kind": kind,
                        "unread": unread,
                    })
                })
                .collect();
            Ok(json!({ "accounts": accounts }))
        }
        "mail.identities" => mail_identities(&me.org_id, &me.email).await,
        "mail.thread" => {
            let thread_id = s(input, "id");
            if thread_id.is_empty() {
                Err("thread_id_required".to_string())
            } else {
                let t_rows = sb_select(&format!(
                    "mail_threads?select=*&org_id=eq.{}&id=eq.{thread_id}",
                    me.org_id
                ))
                .await;
                match t_rows {
                    Err(e) => Err(e),
                    Ok(rows) => {
                        let t = rows.as_array().cloned().unwrap_or_default().into_iter().next();
                        match t {
                            None => Err("not_found".to_string()),
                            Some(t) => {
                                let msgs = sb_select(&format!(
                                    "mail_messages?select=*,mail_attachments(*)&thread_id=eq.{thread_id}&order=sent_at.asc"
                                ))
                                .await
                                .unwrap_or(json!([]));

                                let label_rows = sb_select(&format!(
                                    "mail_thread_labels?select=mail_labels(name)&thread_id=eq.{thread_id}"
                                ))
                                .await
                                .unwrap_or(json!([]));
                                let labels: Vec<String> = label_rows
                                    .as_array()
                                    .cloned()
                                    .unwrap_or_default()
                                    .into_iter()
                                    .filter_map(|r| {
                                        r.get("mail_labels")
                                            .and_then(|l| l.get("name"))
                                            .and_then(|v| v.as_str())
                                            .map(|v| v.to_string())
                                    })
                                    .collect();

                                if t.get("unread").and_then(|v| v.as_bool()) == Some(true) {
                                    let _ = sb_patch(
                                        &format!("mail_threads?id=eq.{thread_id}&org_id=eq.{}", me.org_id),
                                        json!({ "unread": false }),
                                    )
                                    .await;
                                }

                                let messages: Vec<Value> = msgs
                                    .as_array()
                                    .cloned()
                                    .unwrap_or_default()
                                    .into_iter()
                                    .map(|m| {
                                        let atts: Vec<Value> = m
                                            .get("mail_attachments")
                                            .and_then(|v| v.as_array())
                                            .cloned()
                                            .unwrap_or_default()
                                            .into_iter()
                                            .map(|a| {
                                                let url = a
                                                    .get("url")
                                                    .or_else(|| a.get("storage_path"))
                                                    .or_else(|| a.get("disk_path"))
                                                    .cloned()
                                                    .unwrap_or(Value::Null);
                                                json!({
                                                    "id": a.get("id").cloned().unwrap_or(Value::Null),
                                                    "filename": a.get("filename").cloned().unwrap_or(Value::Null),
                                                    "mime_type": a.get("mime_type").cloned().unwrap_or(Value::Null),
                                                    "size_bytes": a.get("size_bytes").and_then(|v| v.as_i64()).unwrap_or(0),
                                                    "url": url,
                                                })
                                            })
                                            .collect();
                                        json!({
                                            "id": m.get("id").cloned().unwrap_or(Value::Null),
                                            "direction": m.get("direction").cloned().unwrap_or(Value::Null),
                                            "from_name": m.get("from_name").cloned().unwrap_or(Value::Null),
                                            "from_address": m.get("from_address").cloned().unwrap_or(Value::Null),
                                            "to": m.get("to_addrs").cloned().unwrap_or(json!([])),
                                            "cc": m.get("cc_addrs").cloned().unwrap_or(json!([])),
                                            "subject": m.get("subject").cloned().unwrap_or(Value::Null),
                                            "body_text": m.get("body_text").cloned().unwrap_or(Value::Null),
                                            "body_html": m.get("body_html").cloned().unwrap_or(Value::Null),
                                            "sent_at": m.get("sent_at").cloned().unwrap_or(Value::Null),
                                            "scheduled_at": m.get("scheduled_at").cloned().unwrap_or(Value::Null),
                                            "attachments": atts,
                                        })
                                    })
                                    .collect();

                                Ok(json!({
                                    "id": t.get("id").cloned().unwrap_or(Value::Null),
                                    "subject": t.get("subject").and_then(|v| v.as_str()).unwrap_or(""),
                                    "status": t.get("status").and_then(|v| v.as_str()).unwrap_or("open"),
                                    "assignee": t.get("assignee").cloned().unwrap_or(Value::Null),
                                    "labels": labels,
                                    "snoozed_until": t.get("snoozed_until").cloned().unwrap_or(Value::Null),
                                    "account_address": t.get("mailbox_address").cloned().unwrap_or(Value::Null),
                                    "messages": messages,
                                }))
                            }
                        }
                    }
                }
            }
        }
        "mail.thread.insights" => {
            let thread_id = s(input, "id");
            if thread_id.is_empty() {
                Err("thread_id_required".to_string())
            } else {
                // Pro+ gate — canonical resolve_plan() RPC, same source of
                // truth as plan.ts / Step 6's dispatch_work.
                let plan = sb_rpc(
                    "resolve_plan",
                    json!({ "_user_id": me.id, "_email": me.email }),
                )
                .await
                .unwrap_or(json!("basic"));
                let plan_str = plan.as_str().unwrap_or("basic").to_string();
                if plan_str == "basic" {
                    return err(
                        StatusCode::FORBIDDEN,
                        "feature_not_available",
                        "Thread analytics are a Pro+ feature.",
                    )
                    .into_response();
                }

                // Concurrent fetch — genuine Tokio benefit, not cosmetic.
                // format!() results must be let-bound: passing the temporary
                // directly into tokio::join! drops it before the futures
                // are polled (E0716).
                let q_msgs = format!(
                    "mail_messages?select=direction,sent_at&org_id=eq.{}&thread_id=eq.{thread_id}&order=sent_at.asc",
                    me.org_id
                );
                let q_track = format!(
                    "mail_thread_insights?select=opened,open_count,last_opened_at,recipient_timezone&org_id=eq.{}&thread_id=eq.{thread_id}",
                    me.org_id
                );
                let (msgs_res, track_res) = tokio::join!(sb_select(&q_msgs), sb_select(&q_track));

                let rows = msgs_res.unwrap_or(json!([])).as_array().cloned().unwrap_or_default();
                let inbound = rows
                    .iter()
                    .filter(|m| m.get("direction").and_then(|v| v.as_str()) == Some("in"))
                    .count() as i64;
                let outbound = rows
                    .iter()
                    .filter(|m| m.get("direction").and_then(|v| v.as_str()) == Some("out"))
                    .count() as i64;

                let mut gaps: Vec<f64> = Vec::new();
                for w in rows.windows(2) {
                    let prev = &w[0];
                    let cur = &w[1];
                    if prev.get("direction").and_then(|v| v.as_str()) == Some("in")
                        && cur.get("direction").and_then(|v| v.as_str()) == Some("out")
                    {
                        if let (Some(p), Some(c)) = (
                            prev.get("sent_at").and_then(|v| v.as_str()),
                            cur.get("sent_at").and_then(|v| v.as_str()),
                        ) {
                            if let (Some(pe), Some(ce)) =
                                (parse_iso_epoch_seconds(p), parse_iso_epoch_seconds(c))
                            {
                                gaps.push((ce - pe) as f64 / 60.0);
                            }
                        }
                    }
                }
                let avg: Value = if gaps.is_empty() {
                    Value::Null
                } else {
                    json!((gaps.iter().sum::<f64>() / gaps.len() as f64).round() as i64)
                };

                // Honesty fix (parity with Bun): 1 reply is not a "pattern".
                let in_hours: Vec<i64> = rows
                    .iter()
                    .filter(|m| m.get("direction").and_then(|v| v.as_str()) == Some("in"))
                    .filter_map(|m| m.get("sent_at").and_then(|v| v.as_str()))
                    .filter_map(hour_of_iso)
                    .collect();
                let mut tally: std::collections::HashMap<i64, i64> = std::collections::HashMap::new();
                for h in &in_hours {
                    *tally.entry(*h).or_insert(0) += 1;
                }
                let best: Option<i64> = if in_hours.len() >= 3 {
                    tally.into_iter().max_by_key(|(_, c)| *c).map(|(h, _)| h)
                } else {
                    None
                };

                let track = track_res
                    .unwrap_or(json!([]))
                    .as_array()
                    .cloned()
                    .unwrap_or_default()
                    .into_iter()
                    .next();

                let response_rate: Value = if outbound > 0 {
                    json!((inbound as f64 / outbound as f64).min(1.0))
                } else {
                    Value::Null
                };

                let recipient_tz: Value = track
                    .as_ref()
                    .and_then(|t| t.get("recipient_timezone"))
                    .cloned()
                    .filter(|v| !v.is_null())
                    .unwrap_or_else(|| if best.is_some() { json!("UTC") } else { Value::Null });

                Ok(json!({
                    "opened": track.as_ref().and_then(|t| t.get("opened")).cloned().unwrap_or(Value::Null),
                    "open_count": track.as_ref().and_then(|t| t.get("open_count")).and_then(|v| v.as_i64()).unwrap_or(0),
                    "last_opened_at": track.as_ref().and_then(|t| t.get("last_opened_at")).cloned().unwrap_or(Value::Null),
                    "response_rate": response_rate,
                    "avg_response_minutes": avg,
                    "best_send_hour": best,
                    "recipient_timezone": recipient_tz,
                }))
            }
        }
        "mail.labels" => {
            let data = match sb_select(&format!(
                "mail_labels?select=id,name,colour&org_id=eq.{}&order=name",
                me.org_id
            ))
            .await
            {
                Ok(v) => v,
                Err(_) => return ok(json!({ "labels": [] })).into_response(),
            };
            Ok(json!({ "labels": data }))
        }
        "mail.star" => {
            let thread_id = s(input, "thread_id");
            if thread_id.is_empty() {
                Err("thread_id_required".to_string())
            } else {
                let starred = input.get("starred").and_then(|v| v.as_bool()).unwrap_or(false);
                sb_patch(
                    &format!("mail_threads?id=eq.{thread_id}&org_id=eq.{}", me.org_id),
                    json!({ "starred": starred }),
                )
                .await
                .map(|_| json!({ "ok": true, "starred": starred }))
            }
        }
        "mail.predict" => {
            let prefix = s(input, "prefix");
            if prefix.trim().is_empty() {
                Ok(json!({ "candidates": [] }))
            } else {
                let formality = if s(input, "formality").is_empty() {
                    "any".to_string()
                } else {
                    s(input, "formality")
                };
                sb_rpc(
                    "mail_predict",
                    json!({
                        "_user": me.id,
                        "_prefix": prefix,
                        "_formality": formality,
                        "_limit": input.get("limit").and_then(|v| v.as_i64()).unwrap_or(3),
                    }),
                )
                .await
                .map(|data| json!({ "candidates": data }))
            }
        }
        "mail.predict.learn" => {
            let text = s(input, "text");
            if text.trim().len() < 12 {
                Ok(json!({ "learned": 0 }))
            } else {
                sb_rpc("mail_predict_learn", json!({ "_user": me.id, "_text": text }))
                    .await
                    .map(|data| json!({ "learned": data.as_i64().unwrap_or(0) }))
            }
        }
        "mail.predict.event" => {
            let action = s(input, "action");
            if action.is_empty() {
                Err("action_required".to_string())
            } else {
                sb_rpc(
                    "mail_predict_event",
                    json!({
                        "_user": me.id,
                        "_action": action,
                        "_prefix": input.get("prefix").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
                .map(|_| json!({ "ok": true }))
            }
        }
        // E15 — company domains + addresses (owner/admin hi badal sakta hai)
        "mail.domains.list" => mail_domains_list(&me.org_id).await,
        "mail.domains.add" => {
            if !mail_can_manage(&me.org_id, &me.id).await {
                return forbidden();
            }
            match sb_rpc(
                "org_domain_add",
                json!({ "_org": me.org_id, "_domain": s(input, "domain") }),
            )
            .await
            {
                Ok(mut r) => {
                    if r.get("ok").and_then(|v| v.as_bool()) == Some(true) {
                        let rec = r.get("domain").map(dns_records).unwrap_or(Value::Null);
                        r["domain"]["records"] = rec;
                    }
                    Ok(r)
                }
                Err(e) => Err(e),
            }
        }
        "mail.domains.verify" => {
            if !mail_can_manage(&me.org_id, &me.id).await {
                return forbidden();
            }
            mail_domain_verify(&me.org_id, &s(input, "domain_id")).await
        }
        "mail.domains.remove" => {
            if !mail_can_manage(&me.org_id, &me.id).await {
                return forbidden();
            }
            sb_rpc(
                "org_domain_remove",
                json!({ "_org": me.org_id, "_id": s(input, "domain_id") }),
            )
            .await
        }
        "mail.addresses.list" => mail_addresses_list(&me.org_id, &me.email).await,
        "mail.addresses.create" => {
            if !mail_can_manage(&me.org_id, &me.id).await {
                return forbidden();
            }
            let kind = if s(input, "kind").is_empty() {
                "mailbox".to_string()
            } else {
                s(input, "kind")
            };
            let mut body = json!({
                "_org": me.org_id,
                "_domain_id": s(input, "domain_id"),
                "_local": s(input, "local_part"),
                "_kind": kind,
            });
            if !s(input, "owner_user_id").is_empty() {
                body["_owner"] = json!(s(input, "owner_user_id"));
            }
            if !s(input, "alias_target").is_empty() {
                body["_alias_target"] = json!(s(input, "alias_target"));
            }
            sb_rpc("org_address_create", body).await
        }
        "mail.addresses.remove" => {
            if !mail_can_manage(&me.org_id, &me.id).await {
                return forbidden();
            }
            sb_rpc(
                "org_address_remove",
                json!({ "_org": me.org_id, "_id": s(input, "address_id") }),
            )
            .await
        }
        // mail.send — Bun pe delegate. Frontend seedha /api/mail/send call karta hai.
        // Agar koi /rpc/mail.send call kare to Bun fallback signal milta hai.
        "mail.send" => {
            return err(
                StatusCode::NOT_IMPLEMENTED,
                "use_bun_fallback",
                "mail.send: POST /api/mail/send (Bun -> local Postfix)",
            )
            .into_response()
        }
        "org.mailboxes.list" => {
            return err(
                StatusCode::NOT_IMPLEMENTED,
                "use_bun_fallback",
                "org.mailboxes.list: GET /api/org/mailboxes",
            )
            .into_response()
        }
        "org.mailboxes.create" => {
            return err(
                StatusCode::NOT_IMPLEMENTED,
                "use_bun_fallback",
                "org.mailboxes.create: POST /api/org/mailboxes",
            )
            .into_response()
        }
        other => {
            return err(
                StatusCode::NOT_FOUND,
                "procedure_not_in_rust",
                &format!("{other} Rust pe define nahi hai."),
            )
            .into_response()
        }
    };

    match result {
        Ok(data) => ok(data).into_response(),
        Err(detail) => err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &detail).into_response(),
    }
}

// ── Phase 5 — naya real buyer signup (Rust primary) ─────────────────────────
// Truth: Supabase RPCs (phase32_trial.sql + E17_trial_provision_workspace.sql).
// Rust yahan sirf dispatch karta hai, apna business logic invent nahi karta.
// account.signup.address — PUBLIC (auth se pehle dispatch() mein handle hota hai).
async fn account_signup_address(input: &Value) -> axum::response::Response {
    let handle = s(input, "handle").trim().to_lowercase();
    if !regex_handle_ok(&handle) {
        return ok(json!({ "handle": handle, "available": false, "reason": "invalid_handle" }))
            .into_response();
    }
    let reserved = sb_select(&format!("reserved_handles?select=handle&handle=eq.{handle}")).await;
    if reserved.map(|v| v.as_array().map(|a| !a.is_empty()).unwrap_or(false)).unwrap_or(false) {
        return ok(json!({ "handle": handle, "available": false, "reason": "reserved_handle" }))
            .into_response();
    }
    let taken = sb_select(&format!(
        "trial_accounts?select=user_id&anexomail_handle=eq.{handle}&status=neq.released"
    ))
    .await;
    if taken.map(|v| v.as_array().map(|a| !a.is_empty()).unwrap_or(false)).unwrap_or(false) {
        return ok(json!({ "handle": handle, "available": false, "reason": "taken" }))
            .into_response();
    }
    ok(json!({ "handle": handle, "available": true, "address": format!("{handle}@anexomail.com") }))
        .into_response()
}

fn regex_handle_ok(h: &str) -> bool {
    let b = h.as_bytes();
    if b.len() < 3 || b.len() > 30 {
        return false;
    }
    let ok_char = |c: u8| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'.' || c == b'-';
    if !b[0].is_ascii_alphanumeric() || !b[b.len() - 1].is_ascii_alphanumeric() {
        return false;
    }
    b.iter().all(|&c| ok_char(c))
}

/// account.signup.* + account.delete.* (E24) — authenticated (real Supabase Auth session), lekin
/// mail_identity ki tarah org_members pehle se hone ki zaroorat NAHI
/// (brand-new buyer ke paas abhi workspace hi nahi hota).
async fn dispatch_account(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    let (user_id, email) = match auth_user(token).await {
        Some(v) => v,
        None => return err(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid").into_response(),
    };

    let result: Result<Value, String> = match proc {
        "account.signup.state" => sb_rpc("account_state", json!({ "_user_id": user_id })).await,
        "account.signup.start" => {
            let provider = if s(input, "provider").is_empty() {
                "email".to_string()
            } else {
                s(input, "provider")
            };
            sb_rpc(
                "trial_start",
                json!({ "_user_id": user_id, "_social_email": email, "_provider": provider }),
            )
            .await
        }
        "account.signup.claim" => {
            let handle = s(input, "handle").trim().to_lowercase();
            if handle.is_empty() {
                Err("handle_required".to_string())
            } else {
                match sb_rpc(
                    "trial_claim_address",
                    json!({ "_user_id": user_id, "_handle": handle }),
                )
                .await
                {
                    Ok(claim) => {
                        if claim.get("ok").and_then(|v| v.as_bool()) != Some(true) {
                            Ok(claim)
                        } else {
                            // Yahi woh gap hai jo pro.test/biz.test ke liye manual SQL se
                            // bhara gaya tha — ab khud-ba-khud: organisations + mail_accounts
                            // + org_members. Postfix sync already-fixed cron khud utha lega.
                            match sb_rpc(
                                "trial_provision_workspace",
                                json!({ "_user_id": user_id }),
                            )
                            .await
                            {
                                Ok(prov) => Ok(json!({
                                    "ok": true,
                                    "claim": claim,
                                    "workspace": prov,
                                })),
                                Err(e) => Err(e),
                            }
                        }
                    }
                    Err(e) => Err(e),
                }
            }
        }
        // E23 -- payment ke baad account activate. Client ka plan/payment_ref
        // ignore: sirf entitlement_state (billing_intent_confirm ne verify ki).
        "account.signup.activate" => {
            match sb_rpc("trial_activate_if_paid", json!({ "_user": user_id })).await {
                Ok(v) if v.get("ok").and_then(|x| x.as_bool()) == Some(false) => {
                    return err(
                        StatusCode::PAYMENT_REQUIRED,
                        "no_verified_payment",
                        "No verified payment found for this account yet.",
                    )
                    .into_response();
                }
                other => other,
            }
        }
        // E24 -- account delete: sirf request / cancel / state. Asli delete
        // (account_purge) yahan se KABHI nahi: us par kisi role ka execute nahi,
        // sirf founder SQL Editor se chalta hai.
        "account.delete.state" => {
            sb_rpc("account_deletion_state", json!({ "_user": user_id })).await
        }
        "account.delete.cancel" => {
            sb_rpc("account_deletion_cancel", json!({ "_user": user_id })).await
        }
        "account.delete.request" => {
            match sb_rpc(
                "account_deletion_request",
                json!({ "_user": user_id, "_confirm_email": s(input, "confirm_email") }),
            )
            .await
            {
                Ok(v) if v.get("ok").and_then(|x| x.as_bool()) == Some(false) => {
                    let code = v
                        .get("error")
                        .and_then(|x| x.as_str())
                        .unwrap_or("request_failed")
                        .to_string();
                    let (status, msg) = match code.as_str() {
                        "blocked" => (
                            StatusCode::CONFLICT,
                            "Resolve the items listed on the page first.",
                        ),
                        "email_mismatch" => (
                            StatusCode::BAD_REQUEST,
                            "That email doesn't match this account.",
                        ),
                        _ => (StatusCode::BAD_REQUEST, "Deletion could not be scheduled."),
                    };
                    return err(status, &code, msg).into_response();
                }
                other => other,
            }
        }
        other => {
            return err(
                StatusCode::NOT_FOUND,
                "procedure_not_in_rust",
                &format!("{other} Rust pe define nahi hai."),
            )
            .into_response()
        }
    };

    match result {
        Ok(data) => ok(data).into_response(),
        Err(detail) => err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &detail).into_response(),
    }
}

// ── E15 business domains (company mail, Zoho-style) ─────────────────────────
const MAIL_HOST: &str = "mail.anexomail.com";

fn forbidden() -> axum::response::Response {
    err(StatusCode::FORBIDDEN, "forbidden", "owner_or_admin_only").into_response()
}

async fn mail_can_manage(org: &str, user: &str) -> bool {
    sb_select(&format!(
        "org_members?select=role&org_id=eq.{org}&user_id=eq.{user}"
    ))
    .await
    .ok()
    .and_then(|v| {
        let r = v.get(0)?.get("role")?.as_str()?.to_lowercase();
        Some(r == "owner" || r == "admin")
    })
    .unwrap_or(false)
}

fn dns_records(d: &Value) -> Value {
    let g = |k: &str| d.get(k).and_then(|v| v.as_str()).unwrap_or("").to_string();
    let b = |k: &str| d.get(k).and_then(|v| v.as_bool()).unwrap_or(false);
    let dom = g("domain");
    let sel = {
        let x = g("dkim_selector");
        if x.is_empty() { "anexo1".to_string() } else { x }
    };
    let dkim = g("dkim_public");
    let dkim_val = if dkim.is_empty() {
        Value::Null
    } else {
        json!(format!("v=DKIM1; k=rsa; p={dkim}"))
    };
    json!([
        { "key": "txt", "type": "TXT", "name": "_anexomail-verify", "host": format!("_anexomail-verify.{dom}"),
          "value": g("verify_token"), "ok": b("txt_ok") },
        { "key": "mx", "type": "MX", "name": "@", "host": dom, "value": MAIL_HOST, "priority": 10, "ok": b("mx_ok") },
        { "key": "spf", "type": "TXT", "name": "@", "host": dom,
          "value": format!("v=spf1 a:{MAIL_HOST} ~all"), "ok": b("spf_ok") },
        { "key": "dkim", "type": "TXT", "name": format!("{sel}._domainkey"), "host": format!("{sel}._domainkey.{dom}"),
          "value": dkim_val, "pending": dkim.is_empty(), "ok": b("dkim_ok") },
        { "key": "dmarc", "type": "TXT", "name": "_dmarc", "host": format!("_dmarc.{dom}"),
          "value": "v=DMARC1; p=none; rua=mailto:dmarc@anexomail.com", "ok": b("dmarc_ok") }
    ])
}

/// DNS-over-HTTPS (Cloudflare) — shell/dig ki zaroorat nahi, koi injection nahi.
async fn doh(name: &str, rtype: &str) -> Vec<String> {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(6))
        .build()
        .unwrap_or_default();
    let res = client
        .get("https://cloudflare-dns.com/dns-query")
        .query(&[("name", name), ("type", rtype)])
        .header("accept", "application/dns-json")
        .send()
        .await;
    let Ok(res) = res else { return vec![] };
    let Ok(v) = res.json::<Value>().await else { return vec![] };
    v.get("Answer")
        .and_then(|a| a.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|r| r.get("data").and_then(|d| d.as_str()))
                .map(|x| x.replace("\" \"", "").trim_matches('"').to_string())
                .collect()
        })
        .unwrap_or_default()
}

/// #7 — Compose "Send from": is user ke liye jaiz From addresses. Qaida Bun `lib/identity.ts` jaisa:
/// org ke mailboxes / mail_accounts / org_addresses (alias nahi, inactive nahi) + apna @anexomail.com login.
/// Default = apna login (warna pehla). Naya code Rust-first; Bun fallback nahi.
async fn mail_identities(org: &str, own_email: &str) -> Result<Value, String> {
    let mut found: std::collections::BTreeMap<String, &'static str> = std::collections::BTreeMap::new();
    let sources: [(String, &str); 3] = [
        (format!("mailboxes?select=address,box_type,active&org_id=eq.{org}"), "box_type"),
        (format!("mail_accounts?select=address&org_id=eq.{org}"), ""),
        (format!("org_addresses?select=address,kind,active&org_id=eq.{org}"), "kind"),
    ];
    for (path, kind_col) in sources.iter() {
        let rows = sb_select(path).await.unwrap_or(json!([]));
        for r in rows.as_array().cloned().unwrap_or_default() {
            let addr = r
                .get("address")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .trim()
                .to_lowercase();
            if addr.is_empty() || !addr.contains('@') {
                continue;
            }
            if r.get("active").and_then(|v| v.as_bool()) == Some(false) {
                continue;
            }
            let kind = if kind_col.is_empty() {
                "mailbox"
            } else {
                r.get(*kind_col).and_then(|v| v.as_str()).unwrap_or("mailbox")
            };
            if kind == "alias" {
                continue;
            }
            found.insert(addr, if kind == "shared" { "shared" } else { "mailbox" });
        }
    }
    let own = own_email.trim().to_lowercase();
    if own.ends_with("@anexomail.com") {
        found.entry(own.clone()).or_insert("mailbox");
    }
    let mut list: Vec<Value> = Vec::new();
    if found.contains_key(&own) {
        list.push(json!({ "address": own, "kind": "login" }));
    }
    for (addr, kind) in found.iter() {
        if *addr == own {
            continue;
        }
        list.push(json!({ "address": addr, "kind": kind }));
    }
    let default = list
        .first()
        .and_then(|v| v.get("address"))
        .cloned()
        .unwrap_or(Value::Null);
    Ok(json!({ "identities": list, "default": default }))
}

async fn mail_domains_list(org: &str) -> Result<Value, String> {
    let list = sb_rpc("org_domain_list", json!({ "_org": org })).await?;
    let plan = sb_rpc("org_plan_of", json!({ "_org": org }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|x| x.to_string()))
        .unwrap_or_else(|| "basic".to_string());
    let cap = sb_rpc("org_domain_cap", json!({ "_plan": plan }))
        .await
        .unwrap_or(Value::Null);
    let domains: Vec<Value> = list
        .as_array()
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .map(|mut d| {
            let rec = dns_records(&d);
            d["records"] = rec;
            d
        })
        .collect();
    Ok(json!({ "domains": domains, "plan": plan, "domain_cap": cap, "mail_host": MAIL_HOST }))
}

async fn mail_domain_verify(org: &str, id: &str) -> Result<Value, String> {
    let list = sb_rpc("org_domain_list", json!({ "_org": org })).await?;
    let d = match list
        .as_array()
        .and_then(|a| a.iter().find(|x| x.get("id").and_then(|v| v.as_str()) == Some(id)))
        .cloned()
    {
        Some(d) => d,
        None => return Ok(json!({ "ok": false, "error": "domain_not_found" })),
    };
    let g = |k: &str| d.get(k).and_then(|v| v.as_str()).unwrap_or("").to_string();
    let dom = g("domain");
    let token = g("verify_token");
    let sel = {
        let x = g("dkim_selector");
        if x.is_empty() { "anexo1".to_string() } else { x }
    };
    let dkim_pub: String = g("dkim_public").split_whitespace().collect();

    let txt = doh(&format!("_anexomail-verify.{dom}"), "TXT").await;
    let mx = doh(&dom, "MX").await;
    let spf = doh(&dom, "TXT").await;
    let dkim = doh(&format!("{sel}._domainkey.{dom}"), "TXT").await;
    let dmarc = doh(&format!("_dmarc.{dom}"), "TXT").await;

    let txt_ok = !token.is_empty() && txt.iter().any(|t| t.trim() == token);
    let mx_ok = mx
        .iter()
        .any(|m| m.trim().trim_end_matches('.').to_lowercase().ends_with(MAIL_HOST));
    let spf_ok = spf
        .iter()
        .any(|t| t.to_lowercase().starts_with("v=spf1") && t.to_lowercase().contains(MAIL_HOST));
    let dkim_ok = dkim_pub.len() >= 40 && dkim_pub.is_ascii()
        && dkim.iter().any(|t| {
            let c: String = t.split_whitespace().collect();
            c.contains("p=") && c.contains(&dkim_pub[..40])
        });
    let dmarc_ok = dmarc.iter().any(|t| t.to_uppercase().starts_with("V=DMARC1"));

    let saved = sb_rpc(
        "org_domain_set_checks",
        json!({ "_id": id, "_txt": txt_ok, "_mx": mx_ok, "_spf": spf_ok, "_dkim": dkim_ok, "_dmarc": dmarc_ok }),
    )
    .await?;
    let mut domain = saved.get("domain").cloned().unwrap_or(Value::Null);
    if domain.is_object() {
        let rec = dns_records(&domain);
        domain["records"] = rec;
    }
    Ok(json!({
        "ok": saved.get("ok").and_then(|v| v.as_bool()).unwrap_or(false),
        "ready": domain.get("status").and_then(|v| v.as_str()) == Some("verified"),
        "checks": { "txt": txt_ok, "mx": mx_ok, "spf": spf_ok, "dkim": dkim_ok, "dmarc": dmarc_ok },
        "domain": domain
    }))
}

async fn mail_addresses_list(org: &str, login: &str) -> Result<Value, String> {
    let list = sb_rpc("org_address_list", json!({ "_org": org })).await?;
    let plan = sb_rpc("org_plan_of", json!({ "_org": org }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|x| x.to_string()))
        .unwrap_or_else(|| "basic".to_string());
    let cap = sb_rpc("org_mailbox_cap", json!({ "_plan": plan }))
        .await
        .unwrap_or(Value::Null);
    let used = list
        .as_array()
        .map(|a| {
            a.iter()
                .filter(|x| {
                    matches!(x.get("kind").and_then(|v| v.as_str()), Some("mailbox") | Some("shared"))
                })
                .count()
        })
        .unwrap_or(0);
    Ok(json!({
        "addresses": list, "plan": plan, "mailbox_cap": cap, "mailbox_used": used,
        "login_address": login
    }))
}

async fn file_ping() -> impl IntoResponse {
    ok(json!({
        "service": "anexomail-file-engine",
        "status": "up",
        "phase": "13-18",
        "safety": {
            "external_api": false,
            "engines": ["type-policy", "clamd-local", "entropy", "archive-ratio", "local-classifier"]
        },
        "max_file_bytes": 5_368_709_120u64,
        "max_chunk_bytes": 16_777_216u64,
        "resumable": true,
        "integrity": "sha256-per-chunk"
    }))
}

async fn health() -> impl IntoResponse {
    ok(json!({
        "service": "anexomail-rust",
        "status": "up",
        "port": PORT,
        "role": "primary",
        "transport": ["rpc", "http3"],
        "webtransport": if WT_LIVE.load(Ordering::Relaxed) { "live" } else { "unavailable" },
        // Asli listener bhi yahi default leta hai (neeche `unwrap_or(3443)`): health ab sach batata hai, khali string nahi.
        "wt_port": env_var("ANEXOCHAT_WT_PORT").parse::<u16>().unwrap_or(3443),
        "fallback": { "service": "anexochat-bun", "port": 3300 },
    }))
}

fn s(input: &Value, key: &str) -> String {
    input
        .get(key)
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string()
}

fn n(input: &Value, key: &str) -> Option<i64> {
    input.get(key).and_then(|v| v.as_i64())
}

/// Minimal ISO-8601 -> epoch-seconds parser (no external crate needed).
/// PostgREST always returns fixed-width "YYYY-MM-DDTHH:MM:SS[.ffffff]+00:00"
/// timestamps for timestamptz, so plain slicing is reliable here.
fn parse_iso_epoch_seconds(ts: &str) -> Option<i64> {
    let y: i64 = ts.get(0..4)?.parse().ok()?;
    let mo: i64 = ts.get(5..7)?.parse().ok()?;
    let d: i64 = ts.get(8..10)?.parse().ok()?;
    let h: i64 = ts.get(11..13)?.parse().ok()?;
    let mi: i64 = ts.get(14..16)?.parse().ok()?;
    let sec: i64 = ts.get(17..19)?.parse().ok()?;

    let y2 = if mo <= 2 { y - 1 } else { y };
    let era = if y2 >= 0 { y2 } else { y2 - 399 } / 400;
    let yoe = y2 - era * 400;
    let mp = (mo + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146097 + doe - 719468;

    Some(days * 86400 + h * 3600 + mi * 60 + sec)
}

fn hour_of_iso(ts: &str) -> Option<i64> {
    ts.get(11..13)?.parse().ok()
}

/// Dashboard (Phase 6 + E30) — Rust PRIMARY. Hisaab Postgres functions mein
/// (dashboard_summary / dashboard_analytics, E30) taake Bun fallback aur Rust
/// ek hi sach dikhayein. Koi bhi DB error 502 hota hai: frontend rpcOrRest()
/// 502 par Bun /api/dashboard/* par girta hai — dashboard kabhi khali nahi.
async fn dispatch_dashboard(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    let requested = s(input, "org_id");
    let me = match mail_identity(token, &requested).await {
        Ok(me) => me,
        Err((status, code, detail)) => {
            return (
                status,
                Json(json!({ "error": { "code": code, "message": detail } })),
            )
                .into_response()
        }
    };

    let result: Result<Value, String> = match proc {
        "dashboard.summary" => {
            sb_rpc(
                "dashboard_summary",
                json!({ "_org": me.org_id, "_user": me.id, "_email": me.email }),
            )
            .await
        }
        "dashboard.analytics" => {
            let days = n(input, "days").unwrap_or(14).clamp(1, 90);
            sb_rpc(
                "dashboard_analytics",
                json!({ "_org": me.org_id, "_days": days }),
            )
            .await
        }
        "dashboard.activity" => {
            let limit = n(input, "limit").unwrap_or(20).clamp(1, 50);
            sb_select(&format!(
                "activity_log?select=id,kind,actor_label,subject,detail,created_at&org_id=eq.{}&order=created_at.desc&limit={}",
                me.org_id, limit
            ))
            .await
            .map(|rows| {
                let items: Vec<Value> = rows
                    .as_array()
                    .cloned()
                    .unwrap_or_default()
                    .into_iter()
                    .map(|r| {
                        json!({
                            "id": r.get("id").cloned().unwrap_or(Value::Null),
                            "kind": r.get("kind").cloned().unwrap_or(Value::Null),
                            "actor": r.get("actor_label").cloned().unwrap_or(Value::Null),
                            "subject": r.get("subject").cloned().unwrap_or(Value::Null),
                            "detail": r.get("detail").cloned().unwrap_or(Value::Null),
                            "created_at": r.get("created_at").cloned().unwrap_or(Value::Null),
                        })
                    })
                    .collect();
                json!({ "items": items })
            })
        }
        "dashboard.ai-usage" => sb_select(&format!(
            "ai_credits?select=enabled,plan,credits_total,credits_used,period_end&org_id=eq.{}&limit=1",
            me.org_id
        ))
        .await
        .map(|rows| {
            let row = rows
                .as_array()
                .and_then(|a| a.first())
                .cloned()
                .unwrap_or(Value::Null);
            json!({
                "enabled": row.get("enabled").and_then(|v| v.as_bool()).unwrap_or(false),
                "plan": row.get("plan").cloned().unwrap_or(Value::Null),
                "credits_total": row.get("credits_total").and_then(|v| v.as_i64()).unwrap_or(0),
                "credits_used": row.get("credits_used").and_then(|v| v.as_i64()).unwrap_or(0),
                "period_end": row.get("period_end").cloned().unwrap_or(Value::Null),
            })
        }),
        "dashboard.calendar" => {
            let from = {
                let now = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .map(|d| d.as_secs() as i64)
                    .unwrap_or(0);
                now - 3600
            };
            // epoch -> ISO8601 UTC (PostgREST gte filter), bina extra crate ke.
            let days = from.div_euclid(86400);
            let rem = from.rem_euclid(86400);
            let z = days + 719468;
            let era = z.div_euclid(146097);
            let doe = z - era * 146097;
            let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
            let y = yoe + era * 400;
            let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
            let mp = (5 * doy + 2) / 153;
            let d = doy - (153 * mp + 2) / 5 + 1;
            let m = if mp < 10 { mp + 3 } else { mp - 9 };
            let y = if m <= 2 { y + 1 } else { y };
            let iso = format!(
                "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z",
                y,
                m,
                d,
                rem / 3600,
                (rem % 3600) / 60,
                rem % 60
            );
            sb_select(&format!(
                "calendar_events?select=id,title,starts_at,ends_at,location,all_day&org_id=eq.{}&starts_at=gte.{}&order=starts_at.asc&limit=10",
                me.org_id, iso
            ))
            .await
            .map(|rows| json!({ "events": rows }))
        }
        _ => Err(format!("{proc} not implemented")),
    };

    match result {
        Ok(v) => ok(v).into_response(),
        Err(e) => err(StatusCode::BAD_GATEWAY, "dashboard_unavailable", &e).into_response(),
    }
}

/// Step 6 (plan-feature-wire audit) — Tasks + Notes, THREAD-level, Pro+ gate.
/// NEW feature (koi Bun equivalent nahi tha) — is liye genuinely Rust/async/
/// Tokio pe, jaisa rule hai: "jo naya hai woh new technology pe hoga".
async fn dispatch_work(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    let requested = s(input, "org_id");
    let me = match mail_identity(token, &requested).await {
        Ok(me) => me,
        Err((status, code, detail)) => {
            return (
                status,
                Json(json!({ "error": { "code": code, "message": detail } })),
            )
                .into_response()
        }
    };

    // Pro+ gate (resolve_plan RPC — canonical, EXACT plan.ts logic mirror).
    let plan = sb_rpc(
        "resolve_plan",
        json!({ "_user_id": me.id, "_email": me.email }),
    )
    .await
    .unwrap_or(json!("basic"));
    let plan_str = plan.as_str().unwrap_or("basic").to_string();
    if plan_str == "basic" {
        return err(
            StatusCode::FORBIDDEN,
            "feature_not_available",
            "Tasks & notes on a thread are a Pro+ feature.",
        )
        .into_response();
    }

    let result: Result<Value, String> = match proc {
        "work.tasks.list" => {
            let thread_id = s(input, "thread_id");
            let query = if !thread_id.is_empty() {
                format!(
                    "work_tasks?select=*&org_id=eq.{}&thread_id=eq.{}&order=created_at.desc",
                    me.org_id, thread_id
                )
            } else {
                format!(
                    "work_tasks?select=*&org_id=eq.{}&order=created_at.desc&limit=200",
                    me.org_id
                )
            };
            sb_select(&query).await
        }
        "work.tasks.create" => {
            let title = s(input, "title");
            if title.is_empty() {
                Err("title_required".to_string())
            } else {
                let thread_id = s(input, "thread_id");
                let body = json!({
                    "org_id": me.org_id,
                    "title": title,
                    "status": "todo",
                    "owner": me.email,
                    "thread_id": if thread_id.is_empty() { Value::Null } else { json!(thread_id) },
                    "created_by": me.id,
                });
                sb_insert("work_tasks", body).await
            }
        }
        "work.tasks.update" => {
            // completed_at is filled/cleared inside the SQL function so that
            // kept / late / broken (promises, follow-through) stay correct.
            let id = s(input, "id");
            let status_val = s(input, "status");
            let due_val = s(input, "due_at");
            if id.is_empty() {
                Err("id_required".to_string())
            } else if status_val.is_empty() && due_val.is_empty() {
                Err("status_or_due_required".to_string())
            } else {
                sb_rpc(
                    "work_task_update",
                    json!({
                        "_org_id": me.org_id,
                        "_id": id,
                        "_status": if status_val.is_empty() { Value::Null } else { json!(status_val) },
                        "_due": if due_val.is_empty() { Value::Null } else { json!(due_val) },
                    }),
                )
                .await
            }
        }
        "work.notes.list" => {
            let thread_id = s(input, "thread_id");
            if thread_id.is_empty() {
                Err("thread_id_required".to_string())
            } else {
                sb_select(&format!(
                    "work_notes?select=*&org_id=eq.{}&thread_id=eq.{}&order=updated_at.desc",
                    me.org_id, thread_id
                ))
                .await
            }
        }
        "work.notes.upsert" => {
            let thread_id = s(input, "thread_id");
            if thread_id.is_empty() {
                Err("thread_id_required".to_string())
            } else {
                let body_text = s(input, "body");
                // Partial unique index (org_id, thread_id) WHERE thread_id IS NOT NULL
                // can't be targeted by PostgREST on_conflict, so upsert manually.
                let existing = sb_select(&format!(
                    "work_notes?select=id&org_id=eq.{}&thread_id=eq.{}",
                    me.org_id, thread_id
                ))
                .await
                .unwrap_or(json!([]));
                let existing_id = existing
                    .as_array()
                    .and_then(|a| a.first())
                    .and_then(|r| r.get("id"))
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());

                if let Some(id) = existing_id {
                    let patch = json!({ "body": body_text, "updated_by": me.id });
                    sb_patch(&format!("work_notes?id=eq.{id}"), patch)
                        .await
                        .map(|_| json!({ "ok": true, "id": id }))
                } else {
                    let body = json!({
                        "org_id": me.org_id,
                        "thread_id": thread_id,
                        "body": body_text,
                        "updated_by": me.id,
                    });
                    sb_insert("work_notes", body).await
                }
            }
        }
        _ => Err(format!("{proc} not implemented")),
    };

    match result {
        Ok(v) => ok(v).into_response(),
        Err(e) => err(StatusCode::BAD_REQUEST, "work_error", &e).into_response(),
    }
}

/// tRPC-style dispatch. ANEXOChat ke procedures PRIMARY yahan hain.
/// Jo procedure Rust pe nahi hai woh 404 deta hai taake frontend fallback kar sake.
/// 8o — founder-only: expiry watch. `anexomail-expiry-watch` (systemd timer, din mein 2 baar) yeh file likhta hai;
/// Rust sirf parhta hai (na secret, na network). Gate Bun ke founder gate jaisa hi: `FOUNDER_EMAILS` (ya default list)
/// ya `founder_accounts` row. File 36 ghante se purani ho to `stale: true` — monitor khud ruk jaye to bhi chup nahi.
const EXPIRY_WATCH_FILE: &str = "/var/lib/anexomail/expiry-watch.json";
const EXPIRY_STALE_SECS: u64 = 36 * 3600;

fn founder_emails() -> Vec<String> {
    let raw = env_var("FOUNDER_EMAILS");
    let raw = if raw.trim().is_empty() {
        "naumansherwani.founder@anexomail.com,naumansherwani.founder@nexatect.com".to_string()
    } else {
        raw
    };
    raw.split(',')
        .map(|e| e.trim().to_lowercase())
        .filter(|e| !e.is_empty())
        .collect()
}

async fn is_founder(id: &str, email: &str) -> bool {
    let email = email.trim().to_lowercase();
    if !email.is_empty() && founder_emails().iter().any(|f| *f == email) {
        return true;
    }
    // Supabase Auth ka id UUID hota hai — URL mein daalne se pehle sirf hex/dash allow.
    if id.is_empty() || !id.chars().all(|c| c.is_ascii_hexdigit() || c == '-') {
        return false;
    }
    match sb_select(&format!(
        "founder_accounts?select=user_id&user_id=eq.{id}&limit=1"
    ))
    .await
    {
        Ok(rows) => rows.as_array().map(|a| !a.is_empty()).unwrap_or(false),
        Err(_) => false,
    }
}

async fn dispatch_founder(proc: &str, token: &str) -> axum::response::Response {
    let (id, email) = match auth_user(token).await {
        Some(u) => u,
        None => {
            return err(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid").into_response()
        }
    };
    if !is_founder(&id, &email).await {
        return err(StatusCode::FORBIDDEN, "founder_only", "Founder only").into_response();
    }
    match proc {
        "founder.expiry.watch" => {
            let path = std::env::var("EXPIRY_WATCH_FILE")
                .unwrap_or_else(|_| EXPIRY_WATCH_FILE.to_string());
            let text = match tokio::fs::read_to_string(&path).await {
                Ok(t) => t,
                Err(_) => {
                    return ok(json!({ "available": false, "reason": "no_report_yet" }))
                        .into_response()
                }
            };
            let mut report: Value = match serde_json::from_str(&text) {
                Ok(v) => v,
                Err(_) => {
                    return ok(json!({ "available": false, "reason": "unreadable" }))
                        .into_response()
                }
            };
            let age: Option<u64> = tokio::fs::metadata(&path)
                .await
                .ok()
                .and_then(|m| m.modified().ok())
                .and_then(|t| t.elapsed().ok())
                .map(|d| d.as_secs());
            if let Some(obj) = report.as_object_mut() {
                obj.insert("available".to_string(), json!(true));
                obj.insert("age_secs".to_string(), json!(age));
                obj.insert(
                    "stale".to_string(),
                    json!(age.map(|a| a > EXPIRY_STALE_SECS).unwrap_or(true)),
                );
            }
            ok(report).into_response()
        }
        _ => err(
            StatusCode::NOT_FOUND,
            "procedure_not_in_rust",
            "Unknown founder procedure",
        )
        .into_response(),
    }
}

/// axum 0.7 ke `Option<Json<Value>>` ka bartao jaisa ka taisa (axum 0.8 mein `Option<Json>` galat Content-Type / kharab body par
/// request ko reject karne laga, pehle sab kuch chupke se `None` ban jata tha): body tab hi parse hoti hai jab Content-Type JSON ho
/// (`application/json` ya `application/*+json`); koi bhi gadbad (type, syntax, size) => None => input `{}`.
fn rpc_json_body(headers: &HeaderMap, body: Option<axum::body::Bytes>) -> Option<Value> {
    let bytes = body?;
    let ct = headers.get(axum::http::header::CONTENT_TYPE)?.to_str().ok()?;
    let mime = ct.split(';').next()?.trim().to_ascii_lowercase();
    let is_json = mime == "application/json" || (mime.starts_with("application/") && mime.ends_with("+json"));
    if !is_json {
        return None;
    }
    serde_json::from_slice::<Value>(&bytes).ok()
}

async fn dispatch(
    Path(proc): Path<String>,
    headers: HeaderMap,
    body: Result<axum::body::Bytes, axum::extract::rejection::BytesRejection>,
) -> axum::response::Response {
    let raw = rpc_json_body(&headers, body.ok()).unwrap_or(json!({}));
    let input = raw
        .get("input")
        .cloned()
        .unwrap_or_else(|| raw.clone());

    if proc == "health" {
        return health().await.into_response();
    }

    // TURN readiness (public, secret-free): sirf yeh batata hai ke server-side
    // HMAC creds ban sakti hain ya nahi. Asli username/credential yahan KABHI nahi —
    // woh sirf authenticated `chat.turn.credentials` se milti hai.
    if proc == "chat.turn.health" {
        return ok(turn_health()).into_response();
    }

    // Phase 5 — signup ke waqt handle-availability check, login se pehle.
    if proc == "account.signup.address" {
        return account_signup_address(&input).await;
    }

    let token = match bearer(&headers) {
        Some(t) => t,
        None => {
            return err(
                StatusCode::UNAUTHORIZED,
                "unauthorized",
                "Missing bearer token",
            )
            .into_response()
        }
    };

    if proc == "whoami" {
        return match auth_user(&token).await {
            Some((id, email)) => {
                ok(json!({ "user_id": id, "email": email, "served_by": "rust" })).into_response()
            }
            None => err(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid").into_response(),
        };
    }

    // 8o — founder-only expiry watch (mail TLS, web certs, domain renewal, DKIM). Exact-match only.
    if proc == "founder.expiry.watch" {
        return dispatch_founder(&proc, &token).await;
    }

    // CRM — Personal Pro+ / Business feature. Exact-match only (learned from
    // the work. prefix bug): never intercept a name we don't explicitly own.
    if matches!(
        proc.as_str(),
        "crm.promises.list"
            | "crm.followups.list"
            | "crm.followups.setDays"
            | "crm.leads.suggest"
            | "crm.leads.dismiss"
            | "crm.contacts.recompute"
            | "crm.contacts.setNotes"
            | "crm.contacts.addAlias"
            | "crm.person.timeline"
            | "crm.timeline"
            | "crm.health"
            | "crm.risk"
            | "crm.graph"
            | "crm.team"
            | "crm.next"
            | "crm.promises.board"
            | "crm.contacts.extractSignature"
            | "crm.people.list"
    ) {
        return dispatch_crm(&proc, &token, &input).await;
    }

    // F3 mail — org mailbox users (Basic/Pro included). Chat entitlement nahi.
    if proc.starts_with("mail.") {
        return dispatch_mail(&proc, &token, &input).await;
    }

    // Phase 5 — naya buyer signup (workspace abhi nahi bana, is liye mail_identity
    // use nahi karte — sirf real Supabase Auth session chahiye).
    if proc.starts_with("account.signup.") || proc.starts_with("account.delete.") {
        return dispatch_account(&proc, &token, &input).await;
    }

    // Billing subscription + invoices — reads from polar_billing_state() [Phase 50]
    // Polar Rust payment :3400 NO-TOUCH. Sirf Supabase RPCs (E5 SQL) se read.
    // Fallback: Bun /api/billing/subscription + /api/billing/invoices.
    if proc.starts_with("billing.") {
        return dispatch_billing(&proc, &token, &input).await;
    }

    // Dashboard — Rust PRIMARY (E30 SQL functions). Fallback: Bun /api/dashboard/*.
    if matches!(
        proc.as_str(),
        "dashboard.summary"
            | "dashboard.analytics"
            | "dashboard.activity"
            | "dashboard.ai-usage"
            | "dashboard.calendar"
    ) {
        return dispatch_dashboard(&proc, &token, &input).await;
    }

    // Step 6 (plan-feature-wire audit) — Tasks + Notes, THREAD-level, Pro+.
    // Narrow match only: a broad "work." prefix match here was intercepting
    // the pre-existing, working Bun /api/work/tasks and /api/work/promises
    // (general, non-thread-scoped) procedures and returning a non-fallbackable
    // "not implemented" error, breaking a feature that already worked.
    if matches!(
        proc.as_str(),
        "work.tasks.list" | "work.tasks.create" | "work.tasks.update" | "work.notes.list" | "work.notes.upsert"
    ) {
        return dispatch_work(&proc, &token, &input).await;
    }

    if !proc.starts_with("chat.") && !proc.starts_with("file.") {
        return err(
            StatusCode::NOT_FOUND,
            "procedure_not_in_rust",
            &format!("{proc} Rust pe nahi hai — legacy REST use karo."),
        )
        .into_response();
    }

    let me = match chat_identity(&token).await {
        Ok(me) => me,
        Err((status, code, detail)) => {
            return (
                status,
                Json(json!({ "error": { "code": code, "message": detail } })),
            )
                .into_response()
        }
    };

    let result: Result<Value, String> = match proc.as_str() {
        "chat.bootstrap" => {
            let members = sb_select(&format!(
                "chat_members?select=user_id,display_name,role&workspace_id=eq.{}",
                me.workspace_id
            ))
            .await;
            members.map(|list| {
                json!({
                    "user_id": me.id,
                    "email": me.email,
                    "workspace_id": me.workspace_id,
                    "members": list,
                    "transport": "rust",
                })
            })
        }

        "chat.conversations" => sb_rpc(
            "chat_conversation_list",
            json!({ "_ws": me.workspace_id, "_me": me.id }),
        )
        .await
        .map(|data| json!({ "conversations": data })),

        "chat.conversations.direct" => {
            let other = s(&input, "other_user_id");
            if other.is_empty() {
                Err("other_user_id_required".to_string())
            } else {
                sb_rpc(
                    "chat_direct_conversation",
                    json!({ "_ws": me.workspace_id, "_me": me.id, "_other": other }),
                )
                .await
                .map(|id| json!({ "conversation_id": id }))
            }
        }

        "chat.messages" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_required".to_string())
            } else {
                sb_rpc(
                    "chat_messages_page",
                    json!({
                        "_conv": conv,
                        "_me": me.id,
                        "_before_seq": n(&input, "before_seq"),
                        "_limit": n(&input, "limit").unwrap_or(80),
                    }),
                )
                .await
                .map(|data| json!({ "messages": data }))
            }
        }

        "chat.send" => {
            let conv = s(&input, "conversation_id");
            let client_msg_id = s(&input, "client_msg_id");
            let body_text = s(&input, "body");
            if conv.is_empty() || client_msg_id.is_empty() || body_text.trim().is_empty() {
                Err("conversation_id_client_msg_id_body_required".to_string())
            } else {
                // Durable write PEHLE — "Sent" tab jab DB row bane.
                sb_rpc(
                    "chat_send",
                    json!({
                        "_conv": conv,
                        "_sender": me.id,
                        "_client_msg_id": client_msg_id,
                        "_body": body_text,
                        "_device": input.get("device").cloned().unwrap_or(Value::Null),
                        "_reply_to": input.get("reply_to_id").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
                .map(|data| {
                    let row = data.get(0).cloned().unwrap_or(data.clone());
                    let mut out = row;
                    if let Some(obj) = out.as_object_mut() {
                        obj.insert("state".into(), json!("sent"));
                        obj.insert("served_by".into(), json!("rust"));
                    }
                    out
                })
            }
        }

        "chat.receipts" => {
            let conv = s(&input, "conversation_id");
            let upto = n(&input, "upto_seq");
            match (conv.is_empty(), upto) {
                (false, Some(upto)) => {
                    let state = if s(&input, "state") == "delivered" {
                        "delivered"
                    } else {
                        "read"
                    };
                    sb_rpc(
                        "chat_mark",
                        json!({ "_conv": conv, "_user": me.id, "_state": state, "_upto": upto }),
                    )
                    .await
                    .map(|marked| json!({ "marked": marked }))
                }
                _ => Err("conversation_id_upto_seq_required".to_string()),
            }
        }

        "chat.typing" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_required".to_string())
            } else {
                sb_rpc(
                    "chat_typing_ping",
                    json!({
                        "_conv": conv,
                        "_user": me.id,
                        "_typing": input.get("typing").and_then(|v| v.as_bool()).unwrap_or(false),
                    }),
                )
                .await
                .map(|_| json!({ "ok": true }))
            }
        }

        "chat.presence.ping" => sb_rpc(
            "chat_presence_ping",
            json!({
                "_ws": me.workspace_id,
                "_user": me.id,
                "_device": input.get("device").cloned().unwrap_or(Value::Null),
            }),
        )
        .await
        .map(|_| json!({ "ok": true })),

        "chat.presence" => {
            let conv = s(&input, "conversation_id");
            let presence = sb_select(&format!(
                "chat_presence?select=user_id,device_label,last_seen_at&workspace_id=eq.{}",
                me.workspace_id
            ))
            .await;
            match presence {
                Err(e) => Err(e),
                Ok(presence) => {
                    let typing = if conv.is_empty() {
                        Ok(json!([]))
                    } else {
                        sb_select(&format!(
                            "chat_typing?select=user_id,until&conversation_id=eq.{conv}&until=gt.now()&user_id=neq.{}",
                            me.id
                        ))
                        .await
                    };
                    typing.map(|typing| json!({ "presence": presence, "typing": typing }))
                }
            }
        }

        // ── PHASE 3: message engine (reactions / edit / delete) ─────────────
        "chat.react" => {
            let msg = s(&input, "message_id");
            let emoji = s(&input, "emoji");
            if msg.is_empty() || emoji.is_empty() {
                Err("message_id_emoji_required".to_string())
            } else {
                sb_rpc(
                    "chat_react",
                    json!({ "_msg": msg, "_user": me.id, "_emoji": emoji }),
                )
                .await
                .map(|data| json!({ "reactions": data }))
            }
        }

        "chat.message.edit" => {
            let msg = s(&input, "message_id");
            let body_text = s(&input, "body");
            if msg.is_empty() || body_text.trim().is_empty() {
                Err("message_id_body_required".to_string())
            } else {
                sb_rpc(
                    "chat_edit_message",
                    json!({ "_msg": msg, "_user": me.id, "_body": body_text }),
                )
                .await
                .map(|data| data.get(0).cloned().unwrap_or(data))
            }
        }

        "chat.message.delete" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc("chat_delete_message", json!({ "_msg": msg, "_user": me.id }))
                    .await
                    .map(|data| data.get(0).cloned().unwrap_or(data))
            }
        }

        // E6 — Business Pro: company-wide delete, NO time limit.
        // Plan gate SQL ke andar (entitlement_state.plan = business_pro).
        "chat.message.delete_anytime" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc(
                    "chat_delete_message_anytime",
                    json!({ "_msg": msg, "_user": me.id }),
                )
                .await
                .map(|data| data.get(0).cloned().unwrap_or(data))
            }
        }

        // E7 — Business: delete for everyone within 48 HOURS.
        // Gate SQL ke andar: business = 48h, business_pro = no limit.
        "chat.message.delete_48h" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc(
                    "chat_delete_message_48h",
                    json!({ "_msg": msg, "_user": me.id }),
                )
                .await
                .map(|data| data.get(0).cloned().unwrap_or(data))
            }
        }

        // ── PHASE 3: work objects (task / promise / decision) ───────────────
        "chat.work.create" => {
            let conv = s(&input, "conversation_id");
            let kind = s(&input, "kind");
            let title = s(&input, "title");
            if conv.is_empty() || kind.is_empty() || title.trim().is_empty() {
                Err("conversation_id_kind_title_required".to_string())
            } else {
                sb_rpc(
                    "chat_work_create",
                    json!({
                        "_conv": conv,
                        "_user": me.id,
                        "_msg": input.get("message_id").cloned().unwrap_or(Value::Null),
                        "_kind": kind,
                        "_title": title,
                        "_due": input.get("due_at").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
                .map(|id| json!({ "id": id }))
            }
        }

        "chat.work.list" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_required".to_string())
            } else {
                sb_rpc("chat_work_list", json!({ "_conv": conv, "_user": me.id }))
                    .await
                    .map(|items| json!({ "items": items }))
            }
        }

        "chat.work.state" => {
            let item = s(&input, "item_id");
            let state = s(&input, "state");
            if item.is_empty() || state.is_empty() {
                Err("item_id_state_required".to_string())
            } else {
                sb_rpc(
                    "chat_work_set_state",
                    json!({ "_item": item, "_user": me.id, "_state": state }),
                )
                .await
                .map(|_| json!({ "ok": true }))
            }
        }

        "chat.conversation.state" => {
            let conv = s(&input, "conversation_id");
            let state = s(&input, "state");
            if conv.is_empty() || state.is_empty() {
                Err("conversation_id_state_required".to_string())
            } else {
                sb_rpc(
                    "chat_conversation_set_state",
                    json!({
                        "_conv": conv,
                        "_user": me.id,
                        "_state": state,
                        "_note": input.get("note").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
                .map(|data| data.get(0).cloned().unwrap_or(data))
            }
        }

        // ── PHASE 6: ANEXOMAIL sidebar unread truth ─────────────────────────
        "chat.unread" => sb_rpc("chat_unread_total", json!({ "_user": me.id }))
            .await
            .map(|data| data.get(0).cloned().unwrap_or(json!({ "unread": 0, "conversations": 0 }))),

        // ── PHASE 11 — NEW ADDED: attachments (Rust PRIMARY) ────────────────
        // Storage ka signed upload ticket Bun deta hai (S3 signing wahin hai);
        // commit / attach / list ke commands ab PRIMARY engine par chalte hain.
        "chat.attachment.commit" => {
            let att = s(&input, "attachment_id");
            if att.is_empty() {
                Err("attachment_required".to_string())
            } else {
                let w = input.get("width").and_then(|v| v.as_i64()).unwrap_or(0);
                let h = input.get("height").and_then(|v| v.as_i64()).unwrap_or(0);
                sb_rpc(
                    "chat_attachment_commit",
                    json!({ "_user": me.id, "_attachment": att, "_width": w, "_height": h }),
                )
                .await
                .map(|_| json!({ "committed": true, "attachment_id": att }))
            }
        }

        "chat.attachment.attach" => {
            let msg = s(&input, "message_id");
            let ids: Vec<String> = input
                .get("attachment_ids")
                .and_then(|v| v.as_array())
                .map(|a| {
                    a.iter()
                        .filter_map(|x| x.as_str().map(|s| s.to_string()))
                        .collect()
                })
                .unwrap_or_default();
            if msg.is_empty() || ids.is_empty() {
                Err("message_and_attachments_required".to_string())
            } else {
                sb_rpc(
                    "chat_attachment_attach",
                    json!({ "_user": me.id, "_message": msg, "_ids": ids }),
                )
                .await
                .map(|data| json!({ "attached": data }))
            }
        }

        // ── PHASE 8-10: parity (hide / pin / prefs / search) ────────────────
        "chat.message.hide" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc("chat_message_hide", json!({ "_msg": msg, "_user": me.id }))
                    .await
                    .map(|_| json!({ "hidden": true }))
            }
        }

        "chat.message.pin" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                let pin = input.get("pin").and_then(|v| v.as_bool()).unwrap_or(true);
                sb_rpc(
                    "chat_pin_message",
                    json!({ "_msg": msg, "_user": me.id, "_pin": pin }),
                )
                .await
                .map(|data| data.get(0).cloned().unwrap_or(data))
            }
        }

        "chat.conversation.prefs" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_required".to_string())
            } else {
                sb_rpc(
                    "chat_conversation_prefs",
                    json!({
                        "_conv": conv,
                        "_user": me.id,
                        "_mute_minutes": input.get("mute_minutes").cloned().unwrap_or(Value::Null),
                        "_archived": input.get("archived").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
                .map(|data| data.get(0).cloned().unwrap_or(data))
            }
        }

        "chat.search" => {
            let q = s(&input, "q");
            if q.trim().is_empty() {
                Ok(json!({ "results": [] }))
            } else {
                sb_rpc("chat_search_deep", json!({ "_user": me.id, "_q": q, "_limit": 40 }))
                    .await
                    .map(|results| json!({ "results": results }))
            }
        }

        // ── PHASE 12: CROSS-DEVICE CONTINUITY (Rust PRIMARY) ────────────────
        // Canonical state Supabase mein; Rust sirf typed procedure hai.
        // Bun `/api/chat/*` wahi contract fallback ke taur par deta hai.
        "chat.device.seen" => {
            let device = s(&input, "device_id");
            if device.is_empty() {
                Err("device_id_required".to_string())
            } else {
                sb_rpc(
                    "chat_device_seen",
                    json!({
                        "_user": me.id,
                        "_device_id": device,
                        "_label": input.get("label").cloned().unwrap_or(Value::Null),
                        "_kind": if s(&input, "kind").is_empty() { "unknown".to_string() } else { s(&input, "kind") },
                        "_platform": input.get("platform").cloned().unwrap_or(Value::Null),
                        "_installed": input.get("installed").and_then(|v| v.as_bool()).unwrap_or(false),
                    }),
                )
                .await
                .map(|_| json!({ "ok": true }))
            }
        }

        "chat.continuity" => sb_rpc(
            "chat_continuity",
            json!({
                "_user": me.id,
                "_device_id": input.get("device_id").cloned().unwrap_or(Value::Null),
            }),
        )
        .await
        .map(|data| data),

        "chat.draft.save" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_required".to_string())
            } else {
                let ids: Vec<String> = input
                    .get("attachment_ids")
                    .and_then(|v| v.as_array())
                    .map(|a| {
                        a.iter()
                            .filter_map(|x| x.as_str().map(|s| s.to_string()))
                            .take(20)
                            .collect()
                    })
                    .unwrap_or_default();
                sb_rpc(
                    "chat_draft_save",
                    json!({
                        "_user": me.id,
                        "_conv": conv,
                        "_body": s(&input, "body"),
                        "_reply_to": input.get("reply_to_id").cloned().unwrap_or(Value::Null),
                        "_caret": input.get("caret").and_then(|v| v.as_i64()).unwrap_or(0),
                        "_attachment_ids": ids,
                        "_rev": input.get("rev").and_then(|v| v.as_i64()).unwrap_or(0),
                        "_device_id": input.get("device_id").cloned().unwrap_or(Value::Null),
                        "_device_label": input.get("device_label").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
                .map(|data| data.get(0).cloned().unwrap_or(data))
            }
        }

        "chat.position.save" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_required".to_string())
            } else {
                sb_rpc(
                    "chat_position_save",
                    json!({
                        "_user": me.id,
                        "_conv": conv,
                        "_anchor_seq": input.get("anchor_seq").and_then(|v| v.as_i64()).unwrap_or(0),
                        "_at_bottom": input.get("at_bottom").and_then(|v| v.as_bool()).unwrap_or(true),
                        "_rev": input.get("rev").and_then(|v| v.as_i64()).unwrap_or(0),
                        "_device_id": input.get("device_id").cloned().unwrap_or(Value::Null),
                        "_device_label": input.get("device_label").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
                .map(|data| data.get(0).cloned().unwrap_or(data))
            }
        }

        "chat.search.deep" => {
            let q = s(&input, "q");
            if q.trim().is_empty() {
                Ok(json!({ "results": [] }))
            } else {
                sb_rpc(
                    "chat_search_deep",
                    json!({
                        "_user": me.id,
                        "_q": q,
                        "_conv": input.get("conversation_id").cloned().unwrap_or(Value::Null),
                        "_sender": input.get("sender").cloned().unwrap_or(Value::Null),
                        "_before": input.get("before").cloned().unwrap_or(Value::Null),
                        "_limit": input.get("limit").and_then(|v| v.as_i64()).unwrap_or(40),
                    }),
                )
                .await
                .map(|results| json!({ "results": results }))
            }
        }

        // ── PHASE 12A: ADVANCED EMAIL WORD PREDICTION (Rust PRIMARY) ────────
        // Assistive only: engine chhota phrase deta hai, poora email kabhi nahi.
        // Bun `/api/mail/predict` wahi contract fallback ke taur par deta hai.
        "mail.predict" => {
            let prefix = s(&input, "prefix");
            if prefix.trim().is_empty() {
                Ok(json!({ "candidates": [] }))
            } else {
                let formality = if s(&input, "formality").is_empty() {
                    "any".to_string()
                } else {
                    s(&input, "formality")
                };
                sb_rpc(
                    "mail_predict",
                    json!({
                        "_user": me.id,
                        "_prefix": prefix,
                        "_formality": formality,
                        "_limit": input.get("limit").and_then(|v| v.as_i64()).unwrap_or(3),
                    }),
                )
                .await
                .map(|data| json!({ "candidates": data }))
            }
        }

        "mail.predict.learn" => {
            let text = s(&input, "text");
            if text.trim().len() < 12 {
                Ok(json!({ "learned": 0 }))
            } else {
                sb_rpc("mail_predict_learn", json!({ "_user": me.id, "_text": text }))
                    .await
                    .map(|data| json!({ "learned": data.as_i64().unwrap_or(0) }))
            }
        }

        "mail.predict.event" => {
            let action = s(&input, "action");
            if action.is_empty() {
                Err("action_required".to_string())
            } else {
                sb_rpc(
                    "mail_predict_event",
                    json!({
                        "_user": me.id,
                        "_action": action,
                        "_prefix": input.get("prefix").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
                .map(|_| json!({ "ok": true }))
            }
        }

        // ── PHASE 7: ANEXOVideoChat signalling (Business Pro only) ──────────

        "chat.video.gate" => sb_rpc("chat_video_allowed", json!({ "_user_id": me.id }))
            .await
            .map(|data| json!({ "allowed": data.as_bool().unwrap_or(false), "plan_required": "business_pro" })),

        "chat.signal.send" => {
            let conv = s(&input, "conversation_id");
            let to = s(&input, "to_user");
            let kind = s(&input, "kind");
            if conv.is_empty() || to.is_empty() || kind.is_empty() {
                Err("conversation_id_to_user_kind_required".to_string())
            } else {
                sb_rpc(
                    "chat_signal_send",
                    json!({
                        "_conv": conv,
                        "_from": me.id,
                        "_to": to,
                        "_kind": kind,
                        "_payload": input.get("payload").cloned().unwrap_or(json!({})),
                    }),
                )
                .await
                .map(|id| json!({ "id": id }))
            }
        }

        "chat.signal.poll" => sb_rpc(
            "chat_signal_poll",
            json!({
                "_conv": input.get("conversation_id").cloned().unwrap_or(Value::Null),
                "_user": me.id,
            }),
        )
        .await
        .map(|signals| json!({ "signals": signals })),

        // ── PHASE 10A: ANEXOVIDEOCHAT CALL ENGINE ───────────────────────────
        // TURN creds coturn REST scheme se banti hain. Secret sirf server par.
        "chat.turn.credentials" => {
            match sb_rpc("chat_video_allowed", json!({ "_user_id": me.id })).await {
                Err(e) => Err(e),
                Ok(v) if v.as_bool() != Some(true) => {
                    return err(
                        StatusCode::FORBIDDEN,
                        "video_not_entitled",
                        "ANEXOVideoChat Business Pro par hai.",
                    )
                    .into_response()
                }
                Ok(_) => Ok(turn_credentials(&me.id)),
            }
        }

        "chat.call.start" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_required".to_string())
            } else {
                sb_rpc(
                    "chat_call_start",
                    json!({
                        "_conv": conv,
                        "_user": me.id,
                        "_peer": input.get("peer_user_id").cloned().unwrap_or(Value::Null),
                        "_role": if s(&input, "role").is_empty() { "caller".to_string() } else { s(&input, "role") },
                        "_signaling": s(&input, "signaling"),
                    }),
                )
                .await
                .map(|id| json!({ "session_id": id }))
            }
        }

        "chat.call.stat" => {
            let session = s(&input, "session_id");
            if session.is_empty() {
                Err("session_required".to_string())
            } else {
                sb_rpc(
                    "chat_call_stat",
                    json!({
                        "_session": session,
                        "_user": me.id,
                        "_sample": input.get("sample").cloned().unwrap_or(json!({})),
                    }),
                )
                .await
                .map(|_| json!({ "ok": true }))
            }
        }

        "chat.call.end" => {
            let session = s(&input, "session_id");
            if session.is_empty() {
                Err("session_required".to_string())
            } else {
                sb_rpc(
                    "chat_call_end",
                    json!({ "_session": session, "_user": me.id, "_reason": s(&input, "reason") }),
                )
                .await
                .map(|_| json!({ "ok": true }))
            }
        }

        // Founder view: measured aggregates (DB hi founder check karta hai)
        "chat.calls.health" => {
            let days = input.get("days").and_then(|v| v.as_i64()).unwrap_or(7);
            match sb_rpc("chat_call_health", json!({ "_user": me.id, "_days": days })).await {
                Err(e) => Err(e),
                Ok(health) => sb_rpc("chat_call_recent", json!({ "_user": me.id, "_limit": 40 }))
                    .await
                    .map(|calls| json!({ "health": health, "calls": calls })),
            }
        }

        // ── PHASE 13/14/15: FILE ENGINE (PRIMARY yahan, Bun sirf fallback) ──
        // Truth DB mein: pool/limits/chunk state/resume identity sab RPC se.
        "file.state" => {
            sb_rpc(
                "file_engine_state",
                json!({ "_user": me.id, "_workspace": me.workspace_id }),
            )
            .await
        }

        "file.begin" => {
            sb_rpc(
                "file_transfer_begin",
                json!({
                    "_user": me.id,
                    "_workspace": me.workspace_id,
                    "_conv": input.get("conversation_id").cloned().unwrap_or(Value::Null),
                    "_name": s(&input, "name"),
                    "_content_type": s(&input, "content_type"),
                    "_bytes": n(&input, "bytes").unwrap_or(0),
                    "_file_sha256": input.get("file_sha256").cloned().unwrap_or(Value::Null),
                    "_chunk_size": n(&input, "chunk_size").unwrap_or(8388608),
                    "_device": s(&input, "device"),
                }),
            )
            .await
        }

        // Resume ka asli source: missing + corrupt chunk list DB se.
        "file.transfer.state" => {
            sb_rpc(
                "file_transfer_state",
                json!({ "_user": me.id, "_transfer": s(&input, "transfer_id") }),
            )
            .await
        }

        "file.transfer.mark" => {
            sb_rpc(
                "file_transfer_mark",
                json!({
                    "_user": me.id,
                    "_transfer": s(&input, "transfer_id"),
                    "_state": s(&input, "state"),
                    "_transport": s(&input, "transport"),
                    "_error": input.get("error").cloned().unwrap_or(Value::Null),
                }),
            )
            .await
        }

        "file.commit" => {
            sb_rpc(
                "file_commit",
                json!({
                    "_user": me.id,
                    "_transfer": s(&input, "transfer_id"),
                    "_file_sha256": input.get("file_sha256").cloned().unwrap_or(Value::Null),
                }),
            )
            .await
        }

        "file.versions" => {
            sb_rpc(
                "file_versions",
                json!({ "_user": me.id, "_file": s(&input, "file_id") }),
            )
            .await
        }

        // ── PHASE 16: FILE TRUTH — evidence chain (jhoot ki gunjaish nahi) ──
        // UI sirf yeh chain dikhata hai: jo row DB mein nahi, woh step "abhi
        // nahi hua". "Delivered" jaisa lafz browser upload par kabhi nahi.
        "file.truth" => {
            sb_rpc(
                "file_truth",
                json!({ "_user": me.id, "_version": s(&input, "version_id") }),
            )
            .await
        }

        // Client selection ka evidence (chain ka pehla step, insaan ka action).
        "file.evidence" => {
            sb_rpc(
                "file_evidence_for_transfer",
                json!({
                    "_user": me.id,
                    "_transfer": s(&input, "transfer_id"),
                    "_state": s(&input, "state"),
                    "_actor": "rust",
                    "_detail": input.get("detail").cloned().unwrap_or(json!({})),
                }),
            )
            .await
        }

        // ── PHASE 17/18: safety truth — engines ki list, queue, enforcement ─
        "file.safety.state" => {
            sb_rpc("file_safety_state", json!({ "_user": me.id })).await
        }

        // Downloaded step sirf asli download par (blocked file par 'not_available').
        "file.download.ack" => {
            sb_rpc(
                "file_download_ack",
                json!({
                    "_user": me.id,
                    "_version": s(&input, "version_id"),
                    "_bytes": n(&input, "bytes").unwrap_or(0),
                    "_device": s(&input, "device"),
                }),
            )
            .await
        }

        // ── PHASE 19: DEVICE SAFETY VAULT ───────────────────────────────────
        // Signals → normalize → hash → sealed vault. Biometric fingerprinting
        // NAHI: sirf 5 coarse signals, aur raw kabhi plain column mein nahi.
        "chat.device.vault" => {
            let mut signals = input.get("signals").cloned().unwrap_or(json!({}));
            if let Some(obj) = signals.as_object_mut() {
                obj.remove("canvas");
                obj.remove("audio");
                obj.remove("fonts");
                obj.remove("webgl");
                obj.remove("ip");
            }
            sb_rpc(
                "device_vault_register",
                json!({ "_user": me.id, "_signals": signals, "_key": vault_key() }),
            )
            .await
        }

        // ── PHASE 20: DEVICE TRUST — dekho aur ek click mein maar do ────────
        "chat.device.trust.list" => {
            sb_rpc("device_trust_list", json!({ "_user": me.id })).await
        }

        "chat.device.trust.set" => {
            let hash = s(&input, "device_hash");
            let state = s(&input, "state");
            if hash.is_empty() || state.is_empty() {
                Err("device_hash_state_required".to_string())
            } else {
                sb_rpc(
                    "device_trust_set",
                    json!({ "_user": me.id, "_device_hash": hash, "_state": state, "_actor": "user" }),
                )
                .await
            }
        }

        // ── PHASE 21: SAFETY REPORTING ──────────────────────────────────────
        "chat.safety.report" => {
            let kind = s(&input, "subject_kind");
            let subject = s(&input, "subject_id");
            let reason = s(&input, "reason");
            if kind.is_empty() || subject.is_empty() || reason.is_empty() {
                Err("subject_kind_subject_id_reason_required".to_string())
            } else {
                sb_rpc(
                    "safety_report_create",
                    json!({
                        "_user": me.id, "_kind": kind, "_subject": subject,
                        "_reason": reason, "_note": s(&input, "note"), "_key": vault_key(),
                    }),
                )
                .await
            }
        }

        "chat.safety.queue" => {
            let state = s(&input, "state");
            sb_rpc(
                "safety_queue",
                json!({ "_actor": me.id, "_state": if state.is_empty() { Value::Null } else { json!(state) } }),
            )
            .await
        }

        "chat.safety.advance" => {
            let report = s(&input, "report_id");
            let to = s(&input, "to_state");
            if report.is_empty() || to.is_empty() {
                Err("report_id_to_state_required".to_string())
            } else {
                sb_rpc(
                    "safety_report_advance",
                    json!({
                        "_actor": me.id, "_report": report, "_to": to,
                        "_note": s(&input, "note"),
                        "_action": input.get("action").cloned().unwrap_or(Value::Null),
                        "_until": input.get("until").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        // Private content sirf justification + audit row ke saath khulta hai.
        "chat.safety.reveal" => {
            let report = s(&input, "report_id");
            let why = s(&input, "justification");
            if report.is_empty() || why.trim().chars().count() < 12 {
                Err("justification_required".to_string())
            } else {
                sb_rpc(
                    "safety_report_reveal",
                    json!({ "_actor": me.id, "_report": report, "_justification": why, "_key": vault_key() }),
                )
                .await
            }
        }

        "chat.safety.standing" => {
            sb_rpc("safety_my_standing", json!({ "_user": me.id })).await
        }

        // ── PHASE 22: WORK EXECUTION CHAIN ──────────────────────────────────
        // Message → task/promise/decision → owner → dependency → deadline →
        // completion → evidence. Parsing deterministic hai: koi AI API nahi,
        // insaani guftagu kahin bahar nahi jati.
        "chat.work.suggest" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc("chat_work_suggest", json!({ "_msg": msg, "_user": me.id })).await
            }
        }

        "chat.work.from_message" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc(
                    "chat_work_from_message",
                    json!({
                        "_msg": msg, "_user": me.id,
                        "_kind": input.get("kind").cloned().unwrap_or(Value::Null),
                        "_title": input.get("title").cloned().unwrap_or(Value::Null),
                        "_owner": input.get("owner_user_id").cloned().unwrap_or(Value::Null),
                        "_due": input.get("due_at").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.work.depend" => {
            let item = s(&input, "item_id");
            let dep = s(&input, "depends_on");
            if item.is_empty() || dep.is_empty() {
                Err("item_id_depends_on_required".to_string())
            } else {
                sb_rpc(
                    "chat_work_depend",
                    json!({ "_item": item, "_depends_on": dep, "_user": me.id }),
                )
                .await
            }
        }

        "chat.work.complete" => {
            let item = s(&input, "item_id");
            if item.is_empty() {
                Err("item_id_required".to_string())
            } else {
                sb_rpc(
                    "chat_work_complete",
                    json!({
                        "_item": item, "_user": me.id,
                        "_evidence": input.get("evidence").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.work.chain" => {
            let item = s(&input, "item_id");
            if item.is_empty() {
                Err("item_id_required".to_string())
            } else {
                sb_rpc("chat_work_chain", json!({ "_item": item, "_user": me.id })).await
            }
        }

        "chat.work.board" => sb_rpc("chat_work_board", json!({ "_user": me.id })).await,

        // ── PHASE 23: PROMISE RECOVERY ENGINE ───────────────────────────────
        // Engine khud kabhi deadline nahi badalti. Har action insaan karta hai,
        // reason ke saath, aur ledger append-only hai.
        "chat.promise.board" => sb_rpc("promise_board", json!({ "_user": me.id })).await,

        "chat.promise.recover" => {
            let item = s(&input, "item_id");
            let action = s(&input, "action");
            if item.is_empty() || action.is_empty() {
                Err("item_id_action_required".to_string())
            } else {
                sb_rpc(
                    "promise_recover",
                    json!({
                        "_item": item, "_user": me.id, "_action": action,
                        "_reason": input.get("reason").cloned().unwrap_or(Value::Null),
                        "_new_due": input.get("new_due_at").cloned().unwrap_or(Value::Null),
                        "_new_owner": input.get("new_owner_id").cloned().unwrap_or(Value::Null),
                        "_impact": input.get("downstream_impact").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.promise.keep" => {
            let item = s(&input, "item_id");
            if item.is_empty() {
                Err("item_id_required".to_string())
            } else {
                sb_rpc(
                    "promise_keep",
                    json!({
                        "_item": item, "_user": me.id,
                        "_evidence": input.get("evidence").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.promise.history" => {
            let item = s(&input, "item_id");
            if item.is_empty() {
                Err("item_id_required".to_string())
            } else {
                sb_rpc("promise_history", json!({ "_item": item, "_user": me.id })).await
            }
        }

        // ── PHASE 24: DECISION LEDGER + DECISION IMPACT MAP ─────────────────
        // Decision hamesha ek ASLI message se banti hai (maker · UTC · source ·
        // body_hash). History kabhi overwrite nahi hoti — tabdeeli naya version
        // row banati hai. Impact map sirf insaani link se, engine kabhi
        // dependency invent nahi karti.
        "chat.decision.mark" => {
            let message = s(&input, "message_id");
            if message.is_empty() {
                Err("message_required".to_string())
            } else {
                sb_rpc(
                    "decision_mark",
                    json!({
                        "_user": me.id, "_message": message,
                        "_title": input.get("title").cloned().unwrap_or(Value::Null),
                        "_detail": input.get("detail").cloned().unwrap_or(Value::Null),
                        "_decided_at": input.get("decided_at").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.decision.board" => {
            sb_rpc(
                "decision_board",
                json!({
                    "_user": me.id,
                    "_conversation": input.get("conversation_id").cloned().unwrap_or(Value::Null),
                }),
            )
            .await
        }

        "chat.decision.state" => {
            let id = s(&input, "decision_id");
            if id.is_empty() {
                Err("decision_id_required".to_string())
            } else {
                sb_rpc("decision_state", json!({ "_decision": id, "_user": me.id })).await
            }
        }

        "chat.decision.impact" => {
            let id = s(&input, "decision_id");
            if id.is_empty() {
                Err("decision_id_required".to_string())
            } else {
                sb_rpc("decision_impact", json!({ "_decision": id, "_user": me.id })).await
            }
        }

        "chat.decision.amend" => {
            let id = s(&input, "decision_id");
            if id.is_empty() {
                Err("decision_id_required".to_string())
            } else {
                sb_rpc(
                    "decision_amend",
                    json!({
                        "_decision": id, "_user": me.id,
                        "_reason": input.get("reason").cloned().unwrap_or(Value::Null),
                        "_change": input.get("change").cloned().unwrap_or(json!("amended")),
                        "_title": input.get("title").cloned().unwrap_or(Value::Null),
                        "_detail": input.get("detail").cloned().unwrap_or(Value::Null),
                        "_decided_at": input.get("decided_at").cloned().unwrap_or(Value::Null),
                        "_superseded_by": input.get("superseded_by").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.decision.link" => {
            let id = s(&input, "decision_id");
            let object = s(&input, "object_id");
            let kind = s(&input, "object_type");
            if id.is_empty() || object.is_empty() || kind.is_empty() {
                Err("decision_object_required".to_string())
            } else {
                sb_rpc(
                    "decision_link",
                    json!({
                        "_decision": id, "_user": me.id,
                        "_object_type": kind, "_object_id": object,
                        "_reason": input.get("reason").cloned().unwrap_or(Value::Null),
                        "_relation": input.get("relation").cloned().unwrap_or(json!("affects")),
                        "_note": input.get("note").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.decision.unlink" => {
            let link = s(&input, "link_id");
            if link.is_empty() {
                Err("link_id_required".to_string())
            } else {
                sb_rpc(
                    "decision_unlink",
                    json!({
                        "_link": link, "_user": me.id,
                        "_reason": input.get("reason").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        // ── PHASE 25/26/27: TIMELINE · HEALTH · PROVENANCE · COLLISION ──────
        // Timeline kuch invent nahi karti — communication aur outcome do lane,
        // har event ka asli record. Health sirf sabit cheez se. Collision sirf
        // insaani dependency par, har amal 8+ char wajah ke saath.

        "chat.timeline.get" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_id_required".to_string())
            } else {
                sb_rpc(
                    "conversation_timeline",
                    json!({
                        "_conversation": conv, "_user": me.id,
                        "_lens": input.get("lens").cloned().unwrap_or(json!("all")),
                        "_limit": input.get("limit").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.timeline.important" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc(
                    "message_mark_important",
                    json!({
                        "_message": msg, "_user": me.id,
                        "_reason": input.get("reason").cloned().unwrap_or(Value::Null),
                        "_important": input.get("important").cloned().unwrap_or(json!(true)),
                    }),
                )
                .await
            }
        }

        "chat.health.conversation" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_id_required".to_string())
            } else {
                sb_rpc("conversation_health", json!({ "_conversation": conv, "_user": me.id })).await
            }
        }

        "chat.health.board" => {
            sb_rpc("conversation_health_board", json!({ "_user": me.id })).await
        }

        "chat.provenance.message" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc("message_provenance", json!({ "_message": msg, "_user": me.id })).await
            }
        }

        "chat.provenance.chain" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_id_required".to_string())
            } else {
                sb_rpc(
                    "conversation_chain_verify",
                    json!({ "_conversation": conv, "_user": me.id }),
                )
                .await
            }
        }

        "chat.collision.scan" => {
            sb_rpc(
                "commitment_collision_scan",
                json!({
                    "_user": me.id,
                    "_conversation": input.get("conversation_id").cloned().unwrap_or(Value::Null),
                }),
            )
            .await
        }

        "chat.collision.act" => {
            let id = s(&input, "collision_id");
            let action = s(&input, "action");
            if id.is_empty() || action.is_empty() {
                Err("collision_id_and_action_required".to_string())
            } else {
                sb_rpc(
                    "commitment_collision_act",
                    json!({
                        "_collision": id, "_user": me.id, "_action": action,
                        "_reason": input.get("reason").cloned().unwrap_or(Value::Null),
                        "_new_due": input.get("new_due").cloned().unwrap_or(Value::Null),
                        "_new_owner": input.get("new_owner").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        // ── PHASE 28: BUSINESS CONVERSATION RECEIPTS + HANDOVER PACK ────────
        // RUST-FIRST: yeh arms PRIMARY hain (/rpc/* on :3200 + WT/QUIC 3443);
        // Bun :3300 sirf fallback. Steps sirf asli rows se — jo record nahi
        // hua woh "Not recorded" hai. Negative receipts bhi likhe jate hain.

        "chat.receipt.pack" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc("message_receipt_pack", json!({ "_message": msg, "_user": me.id })).await
            }
        }

        "chat.receipt.record" => {
            let msg = s(&input, "message_id");
            let state = s(&input, "state");
            if msg.is_empty() || state.is_empty() {
                Err("message_id_and_state_required".to_string())
            } else {
                sb_rpc(
                    "receipt_device_record",
                    json!({
                        "_user": me.id, "_message": msg, "_state": state,
                        "_platform_class": input.get("platform_class").cloned().unwrap_or(Value::Null),
                        "_tz_bucket": input.get("tz_bucket").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.receipt.silent" => {
            sb_rpc(
                "read_without_response",
                json!({
                    "_user": me.id,
                    "_hours": input.get("hours").cloned().unwrap_or(json!(24)),
                }),
            )
            .await
        }

        "chat.receipt.replay" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_id_required".to_string())
            } else {
                sb_rpc(
                    "receipt_replay",
                    json!({
                        "_conversation": conv, "_user": me.id,
                        "_limit": input.get("limit").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.receipt.certificate" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_id_required".to_string())
            } else {
                sb_rpc(
                    "receipt_certificate_issue",
                    json!({ "_conversation": conv, "_user": me.id }),
                )
                .await
            }
        }

        // bahar se verify — token kaafi hai, body kabhi shamil nahi
        "chat.receipt.verify" => {
            let token = s(&input, "token");
            if token.is_empty() {
                Err("token_required".to_string())
            } else {
                sb_rpc("receipt_certificate_verify", json!({ "_token": token })).await
            }
        }

        "chat.message.attach" => {
            let msg = s(&input, "message_id");
            let ver = s(&input, "version_id");
            if msg.is_empty() || ver.is_empty() {
                Err("message_id_and_version_id_required".to_string())
            } else {
                sb_rpc(
                    "message_attach_file",
                    json!({ "_user": me.id, "_message": msg, "_version": ver }),
                )
                .await
            }
        }

        "chat.handover.board" => sb_rpc("handover_pack_board", json!({ "_user": me.id })).await,

        "chat.handover.build" => {
            let outgoing = s(&input, "outgoing_user");
            if outgoing.is_empty() {
                Err("outgoing_user_required".to_string())
            } else {
                sb_rpc(
                    "handover_pack_build",
                    json!({
                        "_actor": me.id, "_outgoing": outgoing,
                        "_scope": input.get("scope").cloned().unwrap_or(json!("workspace")),
                        "_scope_ref": input.get("scope_ref").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.handover.get" => {
            let pack = s(&input, "pack_id");
            if pack.is_empty() {
                Err("pack_id_required".to_string())
            } else {
                sb_rpc("handover_pack_get", json!({ "_pack": pack, "_user": me.id })).await
            }
        }

        "chat.handover.assign" => {
            let pack = s(&input, "pack_id");
            let incoming = s(&input, "incoming_user");
            let reason = s(&input, "reason");
            if pack.is_empty() || incoming.is_empty() || reason.trim().len() < 8 {
                Err("pack_id_incoming_user_and_8_char_reason_required".to_string())
            } else {
                sb_rpc(
                    "handover_assign",
                    json!({
                        "_actor": me.id, "_pack": pack, "_incoming": incoming,
                        "_reason": reason,
                        "_item": input.get("item_id").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.handover.complete" => {
            let pack = s(&input, "pack_id");
            let reason = s(&input, "reason");
            if pack.is_empty() || reason.trim().len() < 8 {
                Err("pack_id_and_8_char_reason_required".to_string())
            } else {
                sb_rpc(
                    "handover_complete",
                    json!({ "_actor": me.id, "_pack": pack, "_reason": reason }),
                )
                .await
            }
        }

        // ── PHASE 29: EMAIL → CHAT BRIDGE ───────────────────────────────────
        // Email formal record hai, chat instant layer. Link do-tarfa aur ek hi.

        "chat.bridge.discuss" => {
            let thread = s(&input, "mail_thread_id");
            if thread.is_empty() {
                Err("mail_thread_id_required".to_string())
            } else {
                sb_rpc(
                    "email_discuss_in_chat",
                    json!({
                        "_user": me.id, "_mail_thread": thread,
                        "_mail_message": input.get("mail_message_id").cloned().unwrap_or(Value::Null),
                        "_conversation": input.get("conversation_id").cloned().unwrap_or(Value::Null),
                        "_subject": input.get("subject").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.bridge.context" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_id_required".to_string())
            } else {
                sb_rpc("email_chat_context", json!({ "_conversation": conv, "_user": me.id })).await
            }
        }

        "chat.bridge.thread" => {
            let thread = s(&input, "mail_thread_id");
            if thread.is_empty() {
                Err("mail_thread_id_required".to_string())
            } else {
                sb_rpc(
                    "email_thread_conversation",
                    json!({ "_user": me.id, "_mail_thread": thread }),
                )
                .await
            }
        }

        "chat.bridge.quote" => {
            let msg = s(&input, "message_id");
            let thread = s(&input, "mail_thread_id");
            let text = s(&input, "quoted_text");
            if msg.is_empty() || thread.is_empty() || text.trim().is_empty() {
                Err("message_id_mail_thread_id_and_quoted_text_required".to_string())
            } else {
                sb_rpc(
                    "email_quote_to_chat",
                    json!({
                        "_user": me.id, "_message": msg, "_mail_thread": thread,
                        "_quoted_text": text,
                        "_mail_message": input.get("mail_message_id").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.bridge.quote.verify" => {
            let quote = s(&input, "quote_id");
            if quote.is_empty() {
                Err("quote_id_required".to_string())
            } else {
                sb_rpc(
                    "email_quote_verify",
                    json!({
                        "_quote": quote,
                        "_current_text": input.get("current_text").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.bridge.presence" => {
            sb_rpc(
                "email_discuss_presence",
                json!({
                    "_user": me.id,
                    "_emails": input.get("emails").cloned().unwrap_or(json!([])),
                }),
            )
            .await
        }

        "chat.bridge.rescue" => {
            let thread = s(&input, "mail_thread_id");
            let title = s(&input, "title");
            let owner = s(&input, "owner_user_id");
            let due = s(&input, "due_at");
            if thread.is_empty() || title.trim().len() < 3 || owner.is_empty() || due.is_empty() {
                Err("mail_thread_id_title_owner_and_due_required".to_string())
            } else {
                sb_rpc(
                    "silent_thread_rescue",
                    json!({
                        "_user": me.id, "_mail_thread": thread, "_title": title,
                        "_owner": owner, "_due": due,
                        "_mail_message": input.get("mail_message_id").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        // ── PHASE 30: CHAT → EMAIL (provenance preserved) ───────────────────
        // Har line ke saath citation (sender · UTC ms · body_hash). Consent
        // gate. Email ki jagah chat kabhi nahi leta.

        "chat.email.draft" => {
            let conv = s(&input, "conversation_id");
            let subject = s(&input, "subject");
            if conv.is_empty() || subject.trim().len() < 3 {
                Err("conversation_id_and_subject_required".to_string())
            } else {
                sb_rpc(
                    "chat_email_draft_create",
                    json!({
                        "_user": me.id, "_conversation": conv, "_subject": subject,
                        "_recipients": input.get("recipients").cloned().unwrap_or(json!([])),
                        "_message_ids": input.get("message_ids").cloned().unwrap_or(json!([])),
                        "_intro": input.get("intro").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.email.board" => {
            sb_rpc(
                "chat_email_draft_board",
                json!({
                    "_user": me.id,
                    "_conversation": input.get("conversation_id").cloned().unwrap_or(Value::Null),
                }),
            )
            .await
        }

        "chat.email.get" => {
            let draft = s(&input, "draft_id");
            if draft.is_empty() {
                Err("draft_id_required".to_string())
            } else {
                sb_rpc("chat_email_draft_get", json!({ "_draft": draft, "_user": me.id })).await
            }
        }

        "chat.email.consent" => {
            let draft = s(&input, "draft_id");
            let state = s(&input, "state");
            if draft.is_empty() || state.is_empty() {
                Err("draft_id_and_state_required".to_string())
            } else {
                sb_rpc(
                    "chat_email_draft_consent",
                    json!({
                        "_user": me.id, "_draft": draft, "_state": state,
                        "_reason": input.get("reason").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }

        "chat.email.send" => {
            let draft = s(&input, "draft_id");
            let mail = s(&input, "mail_message_id");
            if draft.is_empty() || mail.is_empty() {
                Err("draft_id_and_mail_message_id_required".to_string())
            } else {
                sb_rpc(
                    "chat_email_draft_send",
                    json!({ "_user": me.id, "_draft": draft, "_mail_message": mail }),
                )
                .await
            }
        }

        "chat.email.decision" => {
            let decision = s(&input, "decision_id");
            if decision.is_empty() {
                Err("decision_id_required".to_string())
            } else {
                sb_rpc("decision_to_email", json!({ "_user": me.id, "_decision": decision })).await
            }
        }

        "chat.email.escalations" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc("message_escalations", json!({ "_message": msg, "_user": me.id })).await
            }
        }

        // ── PHASE 31 · FILE CONTEXT (RUST PRIMARY) ──────────────────────────
        // Context card · deterministic diff (koi AI API nahi) · duplicate-by-hash
        // · stale-file warning · human-recorded relationship graph.

        "file.context.card" => {
            let file = s(&input, "file_id");
            if file.is_empty() {
                Err("file_id_required".to_string())
            } else {
                sb_rpc("file_context_card", json!({ "_file": file, "_user": me.id })).await
            }
        }

        "file.context.diff" => {
            let file = s(&input, "file_id");
            let from = input.get("from").and_then(|v| v.as_i64()).unwrap_or(0);
            let to = input.get("to").and_then(|v| v.as_i64()).unwrap_or(0);
            if file.is_empty() || from <= 0 || to <= 0 {
                Err("file_id_from_to_required".to_string())
            } else {
                sb_rpc(
                    "file_version_diff",
                    json!({ "_file": file, "_from": from, "_to": to, "_user": me.id }),
                )
                .await
            }
        }

        "file.context.duplicates" => {
            let file = s(&input, "file_id");
            if file.is_empty() {
                Err("file_id_required".to_string())
            } else {
                sb_rpc("file_duplicates", json!({ "_file": file, "_user": me.id })).await
            }
        }

        "file.context.stale" => {
            let file = s(&input, "file_id");
            if file.is_empty() {
                Err("file_id_required".to_string())
            } else {
                sb_rpc("file_stale_check", json!({ "_file": file, "_user": me.id })).await
            }
        }

        "file.context.link" => {
            let file = s(&input, "file_id");
            let object_type = s(&input, "object_type");
            let object_id = s(&input, "object_id");
            let reason = s(&input, "reason");
            if file.is_empty() || object_type.is_empty() || object_id.is_empty() {
                Err("file_object_required".to_string())
            } else if reason.trim().chars().count() < 8 {
                Err("reason_min_8_chars".to_string())
            } else {
                sb_rpc(
                    "file_link",
                    json!({
                        "_file": file, "_object_type": object_type, "_object_id": object_id,
                        "_label": s(&input, "label"), "_reason": reason, "_user": me.id
                    }),
                )
                .await
            }
        }

        "file.context.unlink" => {
            let link = s(&input, "link_id");
            let reason = s(&input, "reason");
            if link.is_empty() {
                Err("link_id_required".to_string())
            } else if reason.trim().chars().count() < 8 {
                Err("reason_min_8_chars".to_string())
            } else {
                sb_rpc(
                    "file_unlink",
                    json!({ "_link": link, "_reason": reason, "_user": me.id }),
                )
                .await
            }
        }

        "file.context.graph" => {
            let file = s(&input, "file_id");
            if file.is_empty() {
                Err("file_id_required".to_string())
            } else {
                sb_rpc("file_relationship_graph", json!({ "_file": file, "_user": me.id })).await
            }
        }

        // ── ANEXOVIDEOCALL PHASE 31 · CALL BUSINESS RECORD (RUST PRIMARY) ───
        // Join truth append-only · duration asli events se · in-call file wahi
        // evidence chain · call → work provenance · relay honesty.

        "call.record" => {
            let session = s(&input, "session_id");
            if session.is_empty() {
                Err("session_id_required".to_string())
            } else {
                sb_rpc("call_record", json!({ "_session": session, "_user": me.id })).await
            }
        }

        "call.record.board" => {
            let conv = s(&input, "conversation_id");
            sb_rpc(
                "call_record_board",
                json!({
                    "_user": me.id,
                    "_conversation": if conv.is_empty() { Value::Null } else { Value::String(conv) },
                    "_limit": input.get("limit").and_then(|v| v.as_i64()).unwrap_or(50)
                }),
            )
            .await
        }

        "call.event" => {
            let session = s(&input, "session_id");
            let event = s(&input, "event");
            let at_ms = input.get("at_ms").and_then(|v| v.as_i64()).unwrap_or(0);
            if session.is_empty() || event.is_empty() || at_ms <= 0 {
                Err("session_event_at_ms_required".to_string())
            } else {
                sb_rpc(
                    "call_event_record",
                    json!({
                        "_session": session, "_user": me.id, "_event": event, "_at_ms": at_ms,
                        "_transport": s(&input, "transport"), "_path": s(&input, "path"),
                        "_detail": input.get("detail").cloned().unwrap_or(json!({}))
                    }),
                )
                .await
            }
        }

        "call.transport" => {
            let session = s(&input, "session_id");
            let path = s(&input, "path");
            let at_ms = input.get("at_ms").and_then(|v| v.as_i64()).unwrap_or(0);
            if session.is_empty() || path.is_empty() || at_ms <= 0 {
                Err("session_path_at_ms_required".to_string())
            } else {
                sb_rpc(
                    "call_transport_record",
                    json!({
                        "_session": session, "_user": me.id, "_path": path,
                        "_relay_host": s(&input, "relay_host"), "_reason": s(&input, "reason"),
                        "_at_ms": at_ms
                    }),
                )
                .await
            }
        }

        "call.file.share" => {
            let session = s(&input, "session_id");
            let version = s(&input, "version_id");
            let at_ms = input.get("at_ms").and_then(|v| v.as_i64()).unwrap_or(0);
            if session.is_empty() || version.is_empty() || at_ms <= 0 {
                Err("session_version_at_ms_required".to_string())
            } else {
                sb_rpc(
                    "call_file_share",
                    json!({ "_session": session, "_version": version, "_user": me.id, "_at_ms": at_ms }),
                )
                .await
            }
        }

        "call.work.link" => {
            let session = s(&input, "session_id");
            let object_type = s(&input, "object_type");
            let object_id = s(&input, "object_id");
            let at_ms = input.get("at_ms").and_then(|v| v.as_i64()).unwrap_or(0);
            if session.is_empty() || object_type.is_empty() || object_id.is_empty() || at_ms <= 0 {
                Err("session_object_at_ms_required".to_string())
            } else {
                sb_rpc(
                    "call_work_link",
                    json!({
                        "_session": session, "_object_type": object_type, "_object_id": object_id,
                        "_note": s(&input, "note"), "_user": me.id, "_at_ms": at_ms
                    }),
                )
                .await
            }
        }

        // ── ANEXOVIDEOCALL PHASE 31A · LIGHT-SPEED PATH (RUST PRIMARY) ──────
        // QUIC signaling · pre-warm marks · own SFU rooms · audio-first
        // survival · self-made ring truth. Koi number marketing ka nahi.

        "call.ring.start" => {
            let session = s(&input, "session_id");
            let to = s(&input, "to_user");
            let at_ms = input.get("at_ms").and_then(|v| v.as_i64()).unwrap_or(0);
            if session.is_empty() || to.is_empty() || at_ms <= 0 {
                Err("session_to_user_at_ms_required".to_string())
            } else {
                sb_rpc(
                    "call_ring_start",
                    json!({
                        "_session": session, "_from": me.id, "_to": to,
                        "_tone": s(&input, "tone"),
                        "_calm": input.get("calm_mode").and_then(|v| v.as_bool()).unwrap_or(false),
                        "_trigger": s(&input, "trigger_path"), "_at_ms": at_ms
                    }),
                )
                .await
            }
        }

        "call.ring.settle" => {
            let ring = s(&input, "ring_id");
            let action = s(&input, "action");
            let at_ms = input.get("at_ms").and_then(|v| v.as_i64()).unwrap_or(0);
            if ring.is_empty() || action.is_empty() || at_ms <= 0 {
                Err("ring_action_at_ms_required".to_string())
            } else {
                sb_rpc(
                    "call_ring_settle",
                    json!({ "_ring": ring, "_user": me.id, "_action": action, "_at_ms": at_ms }),
                )
                .await
            }
        }

        "call.ring.state" => {
            let session = s(&input, "session_id");
            if session.is_empty() {
                Err("session_id_required".to_string())
            } else {
                sb_rpc("call_ring_state", json!({ "_session": session, "_user": me.id })).await
            }
        }

        "call.connect.mark" => {
            let session = s(&input, "session_id");
            let mark = s(&input, "mark");
            let at_ms = input.get("at_ms").and_then(|v| v.as_i64()).unwrap_or(0);
            if session.is_empty() || mark.is_empty() || at_ms <= 0 {
                Err("session_mark_at_ms_required".to_string())
            } else {
                sb_rpc(
                    "call_connect_mark",
                    json!({
                        "_session": session, "_user": me.id, "_mark": mark,
                        "_value_ms": input.get("value_ms").and_then(|v| v.as_i64()),
                        "_transport": s(&input, "transport"), "_at_ms": at_ms
                    }),
                )
                .await
            }
        }

        "call.connect.report" => {
            let session = s(&input, "session_id");
            if session.is_empty() {
                Err("session_id_required".to_string())
            } else {
                sb_rpc("call_connect_report", json!({ "_session": session, "_user": me.id })).await
            }
        }

        "call.connect.health" => {
            sb_rpc(
                "call_connect_health",
                json!({
                    "_user": me.id,
                    "_days": input.get("days").and_then(|v| v.as_i64()).unwrap_or(7)
                }),
            )
            .await
        }

        "call.sfu.ensure" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_id_required".to_string())
            } else {
                // engine_host SIRF tab jata hai jab apna SFU asal mein configured ho
                sb_rpc(
                    "call_sfu_room_ensure",
                    json!({
                        "_conversation": conv, "_user": me.id,
                        "_participants": input.get("participants").and_then(|v| v.as_i64()).unwrap_or(2),
                        "_engine_host": env_var("ANEXOCALL_SFU_HOST")
                    }),
                )
                .await
            }
        }

        "call.sfu.join" => {
            let room = s(&input, "room_id");
            if room.is_empty() {
                Err("room_id_required".to_string())
            } else {
                sb_rpc(
                    "call_sfu_join",
                    json!({
                        "_room": room, "_user": me.id,
                        "_layers": input.get("layers").and_then(|v| v.as_i64()).unwrap_or(3),
                        "_codec": s(&input, "codec")
                    }),
                )
                .await
            }
        }

        "call.sfu.leave" => {
            let room = s(&input, "room_id");
            if room.is_empty() {
                Err("room_id_required".to_string())
            } else {
                sb_rpc("call_sfu_leave", json!({ "_room": room, "_user": me.id })).await
            }
        }

        "call.sfu.state" => {
            let conv = s(&input, "conversation_id");
            if conv.is_empty() {
                Err("conversation_id_required".to_string())
            } else {
                sb_rpc("call_sfu_state", json!({ "_conversation": conv, "_user": me.id })).await
            }
        }

        "call.survival" => {
            let session = s(&input, "session_id");
            let state = s(&input, "state");
            let reason = s(&input, "reason");
            let at_ms = input.get("at_ms").and_then(|v| v.as_i64()).unwrap_or(0);
            if session.is_empty() || state.is_empty() || reason.len() < 3 || at_ms <= 0 {
                Err("session_state_reason_at_ms_required".to_string())
            } else {
                sb_rpc(
                    "call_survival_record",
                    json!({
                        "_session": session, "_user": me.id, "_state": state, "_reason": reason,
                        "_rtt": input.get("rtt_ms").and_then(|v| v.as_i64()),
                        "_loss": input.get("loss_pct").and_then(|v| v.as_f64()),
                        "_at_ms": at_ms
                    }),
                )
                .await
            }
        }


        // ── ACCOUNT INTEGRITY (one person, one account) ─────────────────────
        // Detection sirf device shape par. Engine khud kabhi block nahi karti:
        // warn/block/release har qadam insaan ka, 12+ char reason ke saath.

        "account.integrity.state" => {
            sb_rpc("account_integrity_state", json!({ "_user": me.id })).await
        }

        "account.integrity.evaluate" => {
            sb_rpc(
                "account_integrity_evaluate",
                json!({
                    "_user": me.id,
                    "_device_hash": input.get("device_hash").cloned().unwrap_or(Value::Null),
                }),
            )
            .await
        }

        "account.integrity.queue" => {
            sb_rpc(
                "account_integrity_queue",
                json!({
                    "_actor": me.id,
                    "_state": input.get("state").cloned().unwrap_or(Value::Null),
                }),
            )
            .await
        }

        "account.integrity.warn" | "account.integrity.block" | "account.integrity.release" => {
            let target = s(&input, "user_id");
            let reason = s(&input, "reason");
            if target.is_empty() || reason.trim().len() < 12 {
                Err("user_id_and_12_char_reason_required".to_string())
            } else {
                let fname = match proc.as_str() {
                    "account.integrity.warn" => "account_integrity_warn",
                    "account.integrity.block" => "account_integrity_block",
                    _ => "account_integrity_release",
                };
                sb_rpc(
                    fname,
                    json!({ "_actor": me.id, "_user": target, "_reason": reason }),
                )
                .await
            }
        }

        "account.integrity.export" => {
            sb_rpc("account_integrity_export_ready", json!({ "_user": me.id })).await
        }

        // Device ban appeal: ban sirf device par hota hai, network par kabhi
        // nahi — is liye har ban ke khilaf insaani appeal ka raasta khula hai.
        "chat.device.appeal" => {
            let hash = s(&input, "device_hash");
            let statement = s(&input, "statement");
            if hash.is_empty() || statement.trim().is_empty() {
                Err("device_hash_statement_required".to_string())
            } else {
                sb_rpc(
                    "device_appeal_open",
                    json!({ "_user": me.id, "_device_hash": hash, "_statement": statement }),
                )
                .await
            }
        }

        "chat.device.appeal.queue" => {
            sb_rpc(
                "device_appeal_queue",
                json!({
                    "_actor": me.id,
                    "_state": input.get("state").cloned().unwrap_or(Value::Null),
                }),
            )
            .await
        }

        "chat.device.appeal.decide" => {
            let appeal = s(&input, "appeal_id");
            let decision = s(&input, "decision");
            if appeal.is_empty() || decision.is_empty() {
                Err("appeal_id_decision_required".to_string())
            } else {
                sb_rpc(
                    "device_appeal_decide",
                    json!({
                        "_actor": me.id, "_appeal": appeal, "_decision": decision,
                        "_reason": input.get("reason").cloned().unwrap_or(Value::Null),
                    }),
                )
                .await
            }
        }


        // ── messenger basics (loophole fix): star + forward ──────────────────
        "chat.message.star" => {
            let msg = s(&input, "message_id");
            if msg.is_empty() {
                Err("message_id_required".to_string())
            } else {
                sb_rpc("chat_message_star", json!({ "_msg": msg, "_user": me.id })).await
            }
        }

        "chat.message.forward" => {
            let msg = s(&input, "message_id");
            let conv = s(&input, "to_conversation_id");
            if msg.is_empty() || conv.is_empty() {
                Err("message_id_to_conversation_id_required".to_string())
            } else {
                sb_rpc(
                    "chat_message_forward",
                    json!({ "_msg": msg, "_to_conv": conv, "_user": me.id }),
                )
                .await
            }
        }

        other => {


            return err(
                StatusCode::NOT_FOUND,
                "procedure_not_in_rust",
                &format!("{other} Rust pe define nahi hai."),
            )
            .into_response()
        }
    };

    match result {
        Ok(data) => ok(data).into_response(),
        Err(detail) => err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &detail).into_response(),
    }
}

// ── TURN (coturn) ephemeral credentials — REST scheme ───────────────────────
// username = <unix-expiry>:<user-id>, password = base64(HMAC-SHA1(secret, username))
// ENV: TURN_HOST, TURN_SECRET, TURN_TTL_SECONDS. Secret frontend pe kabhi nahi.
// Public readiness: koi secret, username ya credential value leak nahi hoti —
// sirf yeh sach ke HMAC creds banane ke liye host + secret maujood hain.
fn turn_health() -> Value {
    use hmac::{Hmac, Mac};
    use sha1::Sha1;

    let host = env_var("TURN_HOST");
    let secret = env_var("TURN_SECRET");
    let ready = !host.is_empty() && !secret.is_empty();
    let hmac_ok = ready
        && Hmac::<Sha1>::new_from_slice(secret.as_bytes())
            .map(|mut m| {
                m.update(b"probe");
                m.finalize().into_bytes().len() == 20
            })
            .unwrap_or(false);

    json!({
        "turn_host": host,
        "scheme": "hmac-sha1-rest",
        "credential_ready": hmac_ok,
        "credential_source": "server-side only (chat.turn.credentials, authenticated)"
    })
}

fn turn_credentials(user_id: &str) -> Value {

    use base64::Engine as _;
    use hmac::{Hmac, Mac};
    use sha1::Sha1;

    let mut servers = vec![json!({
        "urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]
    })];
    let host = env_var("TURN_HOST");
    let secret = env_var("TURN_SECRET");
    let ttl: u64 = env_var("TURN_TTL_SECONDS").parse().unwrap_or(3600);

    if !host.is_empty() && !secret.is_empty() {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        let username = format!("{}:{}", now + ttl, user_id);
        let mut mac = Hmac::<Sha1>::new_from_slice(secret.as_bytes()).expect("hmac key");
        mac.update(username.as_bytes());
        let credential = base64::engine::general_purpose::STANDARD.encode(mac.finalize().into_bytes());
        servers.push(json!({
            "urls": [
                format!("turn:{host}:3478?transport=udp"),
                format!("turn:{host}:3478?transport=tcp"),
                format!("turns:{host}:5349?transport=tcp")
            ],
            "username": username,
            "credential": credential
        }));
    }

    json!({
        "ice_servers": servers,
        "ttl_seconds": ttl,
        "turn": !host.is_empty() && !secret.is_empty()
    })
}

// ── WebTransport / HTTP3 / QUIC realtime (PRIMARY push path) ────────────────
//
// Client bidi stream par ek JSON frame bhejta hai:
//   {"token":"<supabase access token>","conversation_id":"<uuid>","after_seq":0}
// Server usi stream par newline-delimited JSON frames wapis karta hai:
//   {"type":"messages","messages":[...]}   — sirf asli DB rows
//   {"type":"error","code":"..."}          — koi fake state nahi
//
// Yeh path durability ka faisla nahi karta: send hamesha DB write se guzarta hai.
// ── PHASE 31A: QUIC SIGNALING HUB (per-conversation fan-out, in-memory) ─────
// Sirf raftaar ke liye. Har frame ka durable ghar `chat_signals` rows hai, is
// liye process restart par koi sach nahi khota — sirf QUIC path naya banta hai.
type SignalTx = tokio::sync::mpsc::UnboundedSender<String>;
static SIGNAL_HUB: std::sync::OnceLock<
    std::sync::Mutex<std::collections::HashMap<String, Vec<(String, SignalTx)>>>,
> = std::sync::OnceLock::new();

fn signal_hub() -> &'static std::sync::Mutex<std::collections::HashMap<String, Vec<(String, SignalTx)>>>
{
    SIGNAL_HUB.get_or_init(|| std::sync::Mutex::new(std::collections::HashMap::new()))
}

fn signal_hub_join(conv: &str, user: &str, tx: SignalTx) {
    if let Ok(mut map) = signal_hub().lock() {
        let peers = map.entry(conv.to_string()).or_default();
        peers.retain(|(u, t)| u != user && !t.is_closed());
        peers.push((user.to_string(), tx));
    }
}

fn signal_hub_leave(conv: &str, user: &str) {
    if let Ok(mut map) = signal_hub().lock() {
        if let Some(peers) = map.get_mut(conv) {
            peers.retain(|(u, t)| u != user && !t.is_closed());
            if peers.is_empty() {
                map.remove(conv);
            }
        }
    }
}

/// `to` khali ho to conversation ke sab peers ko (apne aap ko kabhi nahi).
fn signal_hub_send(conv: &str, from: &str, to: &str, line: String) {
    if let Ok(map) = signal_hub().lock() {
        if let Some(peers) = map.get(conv) {
            for (user, tx) in peers.iter() {
                if user == from {
                    continue;
                }
                if !to.is_empty() && user != to {
                    continue;
                }
                let _ = tx.send(line.clone());
            }
        }
    }
}

/// NOTE N7 (20 Oct 2026): aakhri (error) frame bhej kar stream ko gracefully band karo aur peer ke ack ka intezar karo
/// (`finish()` ack tak rukta hai; zyada se zyada 2s taake atka hua client server ko na roke). Pehle frame likh kar turant
/// `return` hota tha -> Connection drop -> frame aksar raaste mein kho jata, browser ko sirf "Connection lost" milta tha.
async fn wt_send_final(send: &mut wtransport::SendStream, frame: &[u8]) {
    if send.write_all(frame).await.is_ok() {
        let _ = tokio::time::timeout(Duration::from_secs(2), send.finish()).await;
    }
}

async fn wt_session(incoming: wtransport::endpoint::IncomingSession) {
    let Ok(request) = incoming.await else { return };
    let Ok(connection) = request.accept().await else {
        return;
    };

    let Ok((mut send, mut recv)) = connection.accept_bi().await else {
        return;
    };

    let mut buf = vec![0u8; 8 * 1024];
    let read = match recv.read(&mut buf).await {
        Ok(Some(len)) => len,
        _ => return,
    };
    let hello: Value = match serde_json::from_slice(&buf[..read]) {
        Ok(v) => v,
        Err(_) => {
            wt_send_final(&mut send, b"{\"type\":\"error\",\"code\":\"bad_hello\"}\n").await;
            return;
        }
    };

    let token = s(&hello, "token");
    let conv = s(&hello, "conversation_id");
    let mode = s(&hello, "mode");
    if token.is_empty() {
        wt_send_final(&mut send, b"{\"type\":\"error\",\"code\":\"token_required\"}\n").await;
        return;
    }

    // F3 — mail inbox live stamp (org-scoped). Chat hello still needs conversation_id.
    if mode == "mail" {
        let requested = s(&hello, "org_id");
        let me = match mail_identity(&token, &requested).await {
            Ok(me) => me,
            Err((_, code, _)) => {
                let frame = format!("{{\"type\":\"error\",\"code\":\"{code}\"}}\n");
                wt_send_final(&mut send, frame.as_bytes()).await;
                return;
            }
        };
        let _ = send
            .write_all(b"{\"type\":\"ready\",\"transport\":\"webtransport\",\"mode\":\"mail\"}\n")
            .await;
        let mut last = String::new();
        loop {
            match mail_inbox_stamp(&me.org_id).await {
                Ok((unread, max_at)) => {
                    let stamp = format!("{unread}|{max_at}");
                    if stamp != last {
                        last = stamp;
                        let frame = json!({
                            "type": "mail",
                            "unread": unread,
                            "last_message_at": max_at
                        })
                        .to_string();
                        if send.write_all(frame.as_bytes()).await.is_err() {
                            return;
                        }
                        if send.write_all(b"\n").await.is_err() {
                            return;
                        }
                    }
                }
                Err(_) => {
                    let _ = send
                        .write_all(b"{\"type\":\"error\",\"code\":\"db_error\"}\n")
                        .await;
                }
            }
            tokio::time::sleep(Duration::from_millis(700)).await;
        }
    }

    if conv.is_empty() {
        wt_send_final(&mut send, b"{\"type\":\"error\",\"code\":\"token_and_conversation_required\"}\n").await;
        return;
    }

    let me = match chat_identity(&token).await {
        Ok(me) => me,
        Err((_, code, _)) => {
            let frame = format!("{{\"type\":\"error\",\"code\":\"{code}\"}}\n");
            wt_send_final(&mut send, frame.as_bytes()).await;
            return;
        }
    };

    // ── PHASE 31A: QUIC SIGNALING MODE (light-speed connect) ───────────────
    // hello: {"token":..,"conversation_id":..,"mode":"signal"}
    // SDP/ICE frames isi QUIC stream par 1 RTT mein peer tak jate hain.
    // Durability DB rows se aati hai (frontend dono likhta hai); ye path sirf
    // raftaar deta hai — sach ka faisla kabhi nahi karta.
    if s(&hello, "mode") == "signal" {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel::<String>();
        signal_hub_join(&conv, &me.id, tx);
        let _ = send
            .write_all(b"{\"type\":\"ready\",\"transport\":\"webtransport\",\"mode\":\"signal\"}\n")
            .await;

        let mut sbuf = vec![0u8; 64 * 1024];
        let mut pending = String::new();
        loop {
            tokio::select! {
                out = rx.recv() => {
                    match out {
                        Some(line) => {
                            if send.write_all(line.as_bytes()).await.is_err() { break; }
                            if send.write_all(b"\n").await.is_err() { break; }
                        }
                        None => break,
                    }
                }
                got = recv.read(&mut sbuf) => {
                    match got {
                        Ok(Some(len)) if len > 0 => {
                            pending.push_str(&String::from_utf8_lossy(&sbuf[..len]));
                            while let Some(idx) = pending.find('\n') {
                                let raw: String = pending.drain(..=idx).collect();
                                let line = raw.trim().to_string();
                                if line.is_empty() { continue; }
                                if let Ok(mut frame) = serde_json::from_str::<Value>(&line) {
                                    // from_user server likhta hai — client jhoot nahi bol sakta
                                    frame["from_user"] = Value::String(me.id.clone());
                                    let to = s(&frame, "to_user");
                                    signal_hub_send(&conv, &me.id, &to, frame.to_string());
                                }
                            }
                        }
                        Ok(Some(_)) => {}
                        _ => break,
                    }
                }
            }
        }
        signal_hub_leave(&conv, &me.id);
        return;
    }



    let mut last_seq = hello.get("after_seq").and_then(|v| v.as_i64()).unwrap_or(0);
    let _ = send
        .write_all(b"{\"type\":\"ready\",\"transport\":\"webtransport\"}\n")
        .await;

    loop {
        match sb_rpc(
            "chat_messages_page",
            json!({ "_conv": conv, "_me": me.id, "_before_seq": Value::Null, "_limit": 60 }),
        )
        .await
        {
            Ok(page) => {
                let fresh: Vec<Value> = page
                    .as_array()
                    .cloned()
                    .unwrap_or_default()
                    .into_iter()
                    .filter(|m| m.get("seq").and_then(|v| v.as_i64()).unwrap_or(0) > last_seq)
                    .collect();
                if !fresh.is_empty() {
                    for m in &fresh {
                        let seq = m.get("seq").and_then(|v| v.as_i64()).unwrap_or(0);
                        if seq > last_seq {
                            last_seq = seq;
                        }
                    }
                    let frame = json!({ "type": "messages", "messages": fresh }).to_string();
                    if send.write_all(frame.as_bytes()).await.is_err() {
                        return;
                    }
                    if send.write_all(b"\n").await.is_err() {
                        return;
                    }
                }
            }
            Err(_) => {
                let _ = send
                    .write_all(b"{\"type\":\"error\",\"code\":\"db_error\"}\n")
                    .await;
            }
        }
        tokio::time::sleep(Duration::from_millis(700)).await;
    }
}

async fn start_webtransport() {
    let cert = env_var("ANEXOCHAT_WT_CERT");
    let key = env_var("ANEXOCHAT_WT_KEY");
    let port: u16 = env_var("ANEXOCHAT_WT_PORT").parse().unwrap_or(3443);

    if cert.is_empty() || key.is_empty() {
        println!("WebTransport OFF — ANEXOCHAT_WT_CERT / ANEXOCHAT_WT_KEY missing (fallback: Bun 3300)");
        return;
    }

    let identity = match wtransport::Identity::load_pemfiles(&cert, &key).await {
        Ok(id) => id,
        Err(e) => {
            println!("WebTransport OFF — cert load failed: {e}");
            return;
        }
    };

    let config = wtransport::ServerConfig::builder()
        .with_bind_default(port)
        .with_identity(identity)
        .build();

    let endpoint = match wtransport::Endpoint::server(config) {
        Ok(ep) => ep,
        Err(e) => {
            println!("WebTransport OFF — bind udp/{port} failed: {e}");
            return;
        }
    };

    WT_LIVE.store(true, Ordering::Relaxed);
    println!("ANEXOChat WebTransport/QUIC LIVE on udp/{port} (primary realtime)");

    loop {
        let incoming = endpoint.accept().await;
        tokio::spawn(wt_session(incoming));
    }
}

// ── PHASE 14: RAW CHUNK PATH (browser → HTTP/3/QUIC → Rust → storage) ──────
//
// POST /file/chunk   headers: authorization, x-transfer-id, x-chunk-index,
//                             x-chunk-sha256 (client ka hash), content-type
// Body = raw chunk bytes (stream). Rust khud sha256 nikaalta hai aur DB ko
// dono hash deta hai: match = verified, mismatch = corrupt (sirf woh chunk
// dobara aayega, poori file kabhi nahi). Backpressure: concurrency DB se.
async fn sb_storage_put(path: &str, bytes: axum::body::Bytes) -> Result<(), String> {
    let (url, key) = sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let client = reqwest::Client::new();
    let res = client
        .post(format!("{url}/storage/v1/object/chat-files/{path}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .header("content-type", "application/octet-stream")
        .header("x-upsert", "true")
        .body(bytes)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !res.status().is_success() {
        return Err(res.text().await.unwrap_or_else(|_| "storage_error".into()));
    }
    Ok(())
}

fn sha256_hex(bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    hasher
        .finalize()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

async fn file_chunk(headers: HeaderMap, body: axum::body::Bytes) -> axum::response::Response {
    let head = |k: &str| {
        headers
            .get(k)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("")
            .to_string()
    };

    let token = match bearer(&headers) {
        Some(t) => t,
        None => return err(StatusCode::UNAUTHORIZED, "unauthorized", "Missing bearer").into_response(),
    };
    let me = match chat_identity(&token).await {
        Ok(me) => me,
        Err((status, code, detail)) => {
            return (status, Json(json!({ "error": { "code": code, "message": detail } })))
                .into_response()
        }
    };

    let transfer = head("x-transfer-id");
    let idx: i64 = head("x-chunk-index").parse().unwrap_or(-1);
    let client_sha = head("x-chunk-sha256").to_lowercase();
    if transfer.is_empty() || idx < 0 {
        return err(
            StatusCode::BAD_REQUEST,
            "bad_request",
            "x-transfer-id + x-chunk-index required",
        )
        .into_response();
    }

    // Transfer identity DB se — prefix client se kabhi nahi liya jata.
    let state = match sb_rpc(
        "file_transfer_state",
        json!({ "_user": me.id, "_transfer": transfer }),
    )
    .await
    {
        Ok(v) => v,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
    };
    if state.get("found").and_then(|v| v.as_bool()) != Some(true) {
        return err(StatusCode::NOT_FOUND, "transfer_not_found", "Transfer nahi mila").into_response();
    }
    let prefix = state
        .get("storage_prefix")
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string();

    let len = body.len() as i64;
    let server_sha = sha256_hex(&body);

    if !client_sha.is_empty() && client_sha != server_sha {
        // Corrupt chunk storage tak nahi jaata — sirf DB mein record hota hai.
        let ack = sb_rpc(
            "file_chunk_ack",
            json!({
                "_user": me.id, "_transfer": transfer, "_idx": idx,
                "_bytes": len, "_sha256": client_sha, "_server_sha256": server_sha
            }),
        )
        .await;
        return match ack {
            Ok(v) => (StatusCode::CONFLICT, Json(json!({ "result": { "data": v } }))).into_response(),
            Err(e) => err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
        };
    }

    if let Err(e) = sb_storage_put(&format!("{prefix}/chunks/{idx}"), body).await {
        return err(StatusCode::BAD_GATEWAY, "storage_error", &e).into_response();
    }

    match sb_rpc(
        "file_chunk_ack",
        json!({
            "_user": me.id, "_transfer": transfer, "_idx": idx,
            "_bytes": len, "_sha256": server_sha, "_server_sha256": server_sha
        }),
    )
    .await
    {
        Ok(v) => ok(v).into_response(),
        Err(e) => err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
    }
}


// ============================================================================
// PHASE 16 + 17 + 18 — SELF-HOSTED SAFETY WORKER (koi external API nahi)
//
// Chain: selected → uploading → uploaded → scanning → verified → available →
//        downloaded. Yeh worker sirf `scanning → verified/blocked` karta hai,
//        baqi steps asli events se bante hain.
//
// ENGINES (sab ANEXOMAIL infra ke andar):
//   type-policy      : DB `file_type_verdict` (extension + magic bytes + mime
//                      mismatch + double extension) — deterministic, model nahi
//   clamd-local      : self-hosted ClamAV daemon INSTREAM (CLAMD_ADDR,
//                      default 127.0.0.1:3310). Available na ho to engine list
//                      mein naam nahi aata — jhooti safety claim kabhi nahi.
//   entropy          : declared text/document par packed payload ka pata
//   archive-ratio    : zip local header se compression bomb ratio
//   local-classifier : local deterministic prohibited-content wordlist, sirf
//                      text-like bytes par. Insaani guftagu kabhi nahi.
// ============================================================================

// ============================================================================
// PHASE 31C — FILE DOWNLOAD (Phase 16 "downloaded" step ka asli raasta)
// GET /file/download?version=<uuid>   header: authorization Bearer <token>
// DB manifest (sirf ready + clean + available, caller participant) → chunks
// tarteeb se storage se, har chunk ka sha256 DB wale se match → tab hi bytes
// aage jate hain. Mismatch = stream wahin band (client ko adhoori file milti
// hai, jo browser fail karta hai) — "Downloaded" step client tab likhta hai
// jab poore bytes aa jayen (`file.download.ack`). Prefix client ko kabhi nahi.
// ============================================================================
async fn file_download(
    headers: HeaderMap,
    axum::extract::Query(q): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> axum::response::Response {
    let token = match bearer(&headers) {
        Some(t) => t,
        None => return err(StatusCode::UNAUTHORIZED, "unauthorized", "Missing bearer").into_response(),
    };
    let me = match chat_identity(&token).await {
        Ok(me) => me,
        Err((status, code, detail)) => {
            return (status, Json(json!({ "error": { "code": code, "message": detail } })))
                .into_response()
        }
    };
    let version = q.get("version").cloned().unwrap_or_default();
    if version.is_empty() {
        return err(StatusCode::BAD_REQUEST, "bad_request", "version required").into_response();
    }
    let man = match sb_rpc(
        "file_download_manifest",
        json!({ "_user": me.id, "_version": version }),
    )
    .await
    {
        Ok(v) => v,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
    };
    if man.get("ok").and_then(|v| v.as_bool()) != Some(true) {
        let reason = man.get("reason").and_then(|v| v.as_str()).unwrap_or("not_available");
        let status = match reason {
            "not_found" => StatusCode::NOT_FOUND,
            _ => StatusCode::CONFLICT,
        };
        return (status, Json(json!({ "error": { "code": reason, "message": reason }, "truth": man })))
            .into_response();
    }

    let prefix = man.get("storage_prefix").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let name = man.get("name").and_then(|v| v.as_str()).unwrap_or("file").to_string();
    let ctype = man
        .get("content_type")
        .and_then(|v| v.as_str())
        .unwrap_or("application/octet-stream")
        .to_string();
    let total = man.get("bytes").and_then(|v| v.as_i64()).unwrap_or(0);
    let file_sha = man.get("file_sha256").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let chunks: Vec<(i64, String)> = man
        .get("chunks")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .map(|c| {
                    (
                        c.get("idx").and_then(|v| v.as_i64()).unwrap_or(0),
                        c.get("sha256").and_then(|v| v.as_str()).unwrap_or("").to_lowercase(),
                    )
                })
                .collect()
        })
        .unwrap_or_default();

    // Bounded channel = backpressure: ek waqt mein sirf 2 chunk memory mein.
    let (tx, rx) = tokio::sync::mpsc::channel::<Result<axum::body::Bytes, std::io::Error>>(2);
    tokio::spawn(async move {
        for (idx, want) in chunks {
            let got = match sb_storage_get(&format!("{prefix}/chunks/{idx}")).await {
                Ok(b) => b,
                Err(e) => {
                    let _ = tx.send(Err(std::io::Error::other(e))).await;
                    return;
                }
            };
            if sha256_hex(&got) != want {
                // Storage ka chunk DB ke sabit hash se nahi milta — bytes aage nahi jate.
                let _ = tx
                    .send(Err(std::io::Error::other(format!("chunk_{idx}_hash_mismatch"))))
                    .await;
                return;
            }
            if tx.send(Ok(axum::body::Bytes::from(got))).await.is_err() {
                return; // client gaya
            }
        }
    });
    let stream = tokio_stream::wrappers::ReceiverStream::new(rx);
    let safe_name: String = name
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() || ".-_ ".contains(c) { c } else { '_' })
        .collect();
    let mut resp = axum::response::Response::builder()
        .status(StatusCode::OK)
        .header("content-type", ctype)
        .header("content-disposition", format!("attachment; filename=\"{safe_name}\""))
        .header("x-file-sha256", file_sha)
        .header("x-file-version", version)
        .header("cache-control", "private, no-store");
    if total > 0 {
        resp = resp.header("content-length", total.to_string());
    }
    resp.body(axum::body::Body::from_stream(stream))
        .unwrap_or_else(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "stream_error", "body").into_response())
}

async fn sb_storage_get(path: &str) -> Result<Vec<u8>, String> {
    let (url, key) = sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let res = reqwest::Client::new()
        .get(format!("{url}/storage/v1/object/chat-files/{path}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !res.status().is_success() {
        return Err(format!("storage_get_{}", res.status().as_u16()));
    }
    Ok(res.bytes().await.map_err(|e| e.to_string())?.to_vec())
}

fn hex_head(bytes: &[u8], take: usize) -> String {
    bytes
        .iter()
        .take(take)
        .map(|b| format!("{b:02x}"))
        .collect()
}

fn shannon_entropy(bytes: &[u8]) -> f64 {
    if bytes.is_empty() {
        return 0.0;
    }
    let mut counts = [0usize; 256];
    for b in bytes {
        counts[*b as usize] += 1;
    }
    let len = bytes.len() as f64;
    -counts
        .iter()
        .filter(|c| **c > 0)
        .map(|c| {
            let p = *c as f64 / len;
            p * p.log2()
        })
        .sum::<f64>()
}

/// ZIP local file header: compressed vs uncompressed size — bomb ratio.
fn archive_ratio(bytes: &[u8]) -> Option<f64> {
    if bytes.len() < 30 || &bytes[0..4] != b"PK\x03\x04" {
        return None;
    }
    let rd = |o: usize| -> u64 {
        u32::from_le_bytes([bytes[o], bytes[o + 1], bytes[o + 2], bytes[o + 3]]) as u64
    };
    let comp = rd(18).max(1);
    let uncomp = rd(22);
    if uncomp == 0 {
        return None;
    }
    Some(uncomp as f64 / comp as f64)
}

/// Self-hosted ClamAV daemon. Reachable na ho to `Ok(None)` — engine chup.
async fn clamd_scan(bytes: &[u8]) -> Result<Option<String>, String> {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    let addr = {
        let v = env_var("CLAMD_ADDR");
        if v.is_empty() {
            "127.0.0.1:3310".to_string()
        } else {
            v
        }
    };
    let connect = tokio::time::timeout(
        Duration::from_millis(600),
        tokio::net::TcpStream::connect(&addr),
    )
    .await;
    let mut stream = match connect {
        Ok(Ok(s)) => s,
        _ => return Ok(None), // clamd nahi hai — jhooti clean claim nahi
    };
    stream
        .write_all(b"zINSTREAM\0")
        .await
        .map_err(|e| e.to_string())?;
    for part in bytes.chunks(65536) {
        stream
            .write_all(&(part.len() as u32).to_be_bytes())
            .await
            .map_err(|e| e.to_string())?;
        stream.write_all(part).await.map_err(|e| e.to_string())?;
    }
    stream
        .write_all(&0u32.to_be_bytes())
        .await
        .map_err(|e| e.to_string())?;
    let mut reply = Vec::new();
    let _ = tokio::time::timeout(Duration::from_secs(20), stream.read_to_end(&mut reply)).await;
    let text = String::from_utf8_lossy(&reply).trim().to_string();
    if text.is_empty() {
        return Ok(None);
    }
    if text.ends_with("OK") {
        return Ok(Some("clean".into()));
    }
    Ok(Some(text))
}

/// Local deterministic classifier — sirf text-like bytes, sirf saaf mamnu maal.
fn local_classify(name: &str, content_type: &str, bytes: &[u8]) -> Option<(String, String)> {
    let texty = content_type.starts_with("text/")
        || content_type.contains("json")
        || content_type.contains("xml")
        || name.ends_with(".txt")
        || name.ends_with(".csv")
        || name.ends_with(".md");
    if !texty {
        return None;
    }
    let text = String::from_utf8_lossy(&bytes[..bytes.len().min(2 * 1024 * 1024)]).to_lowercase();
    let markers = [
        ("credential-dump", vec!["-----begin rsa private key-----", "-----begin openssh private key-----"]),
        ("card-data-dump", vec!["cvv", "card_number,expiry"]),
        ("malware-builder", vec!["ransom note", "shellcode payload"]),
    ];
    for (label, needles) in markers {
        if needles.iter().any(|n| text.contains(n)) {
            return Some((label.to_string(), format!("Local classifier matched {label}")));
        }
    }
    None
}

async fn scan_one(job: &Value) {
    let version = job.get("version_id").and_then(|v| v.as_str()).unwrap_or("");
    let name = job.get("name").and_then(|v| v.as_str()).unwrap_or("");
    let ctype = job
        .get("content_type")
        .and_then(|v| v.as_str())
        .unwrap_or("application/octet-stream");
    let prefix = job
        .get("storage_prefix")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    let chunks = job.get("chunk_count").and_then(|v| v.as_i64()).unwrap_or(0);
    if version.is_empty() || prefix.is_empty() {
        return;
    }

    // Sirf pehle 4 chunks (max 32 MB) — 5 GB file par bhi scan window bounded.
    let mut sample: Vec<u8> = Vec::new();
    for idx in 0..chunks.min(4) {
        match sb_storage_get(&format!("{prefix}/chunks/{idx}")).await {
            Ok(mut part) => sample.append(&mut part),
            Err(e) => {
                let _ = sb_rpc(
                    "file_scan_report",
                    json!({
                        "_version": version,
                        "_engines": ["type-policy"],
                        "_classification": "unreadable",
                        "_decision": "quarantine",
                        "_findings": [{ "code": "sample_unreadable", "detail": e }]
                    }),
                )
                .await;
                return;
            }
        }
    }

    let mut engines: Vec<&str> = vec!["type-policy", "entropy", "archive-ratio"];
    let mut findings: Vec<Value> = Vec::new();
    let mut decision = "allow";
    let mut classification = "clean".to_string();

    // 1) deterministic type policy (DB) — magic bytes ke saath
    if let Ok(v) = sb_rpc(
        "file_type_verdict",
        json!({ "_name": name, "_content_type": ctype, "_magic_hex": hex_head(&sample, 8) }),
    )
    .await
    {
        if let Some(reasons) = v.get("reasons").and_then(|r| r.as_array()) {
            findings.extend(reasons.clone());
        }
        match v.get("decision").and_then(|d| d.as_str()) {
            Some("block") => {
                decision = "block";
                classification = "dangerous".into();
            }
            Some("quarantine") => {
                decision = "quarantine";
                classification = "suspicious".into();
            }
            _ => {}
        }
    }

    // 2) EICAR / test signature (deterministic, offline)
    if sample
        .windows(20)
        .any(|w| w == b"EICAR-STANDARD-ANTIV")
    {
        decision = "block";
        classification = "dangerous".into();
        findings.push(json!({ "code": "signature_match", "detail": "Known test malware signature" }));
    }

    // 3) self-hosted clamd
    match clamd_scan(&sample).await {
        Ok(Some(reply)) => {
            engines.push("clamd-local");
            if reply != "clean" {
                decision = "block";
                classification = "malware".into();
                findings.push(json!({ "code": "clamd_found", "detail": reply }));
            }
        }
        _ => {}
    }

    // 4) archive bomb ratio
    if let Some(ratio) = archive_ratio(&sample) {
        if ratio > 200.0 && decision != "block" {
            decision = "block";
            classification = "dangerous".into();
            findings.push(json!({
                "code": "archive_bomb",
                "detail": format!("Compression ratio {ratio:.0}x exceeds policy")
            }));
        }
    }

    // 5) entropy: declared document/text magar packed payload
    let entropy = shannon_entropy(&sample[..sample.len().min(1024 * 1024)]);
    if decision == "allow"
        && entropy > 7.95
        && (ctype.starts_with("text/") || ctype.contains("pdf") || ctype.contains("word"))
    {
        decision = "quarantine";
        classification = "suspicious".into();
        findings.push(json!({
            "code": "entropy_mismatch",
            "detail": format!("Declared document with packed payload (entropy {entropy:.2})")
        }));
    }

    // 6) local classifier (Phase 18) — sirf text-like file bytes par
    if let Some((label, detail)) = local_classify(name, ctype, &sample) {
        engines.push("local-classifier");
        decision = "block";
        classification = label;
        findings.push(json!({ "code": "content_policy", "detail": detail }));
    }

    let _ = sb_rpc(
        "file_scan_report",
        json!({
            "_version": version,
            "_engines": engines,
            "_classification": classification,
            "_decision": decision,
            "_findings": findings
        }),
    )
    .await;
}

async fn start_safety_worker() {
    if sb().is_none() {
        println!("safety worker OFF — SUPABASE4_* missing");
        return;
    }
    loop {
        match sb_rpc("file_scan_claim", json!({ "_limit": 2 })).await {
            Ok(v) => {
                let jobs = v
                    .get("jobs")
                    .and_then(|j| j.as_array())
                    .cloned()
                    .unwrap_or_default();
                if jobs.is_empty() {
                    tokio::time::sleep(Duration::from_secs(4)).await;
                    continue;
                }
                for job in jobs {
                    scan_one(&job).await;
                }
            }
            Err(_) => tokio::time::sleep(Duration::from_secs(10)).await,
        }
    }
}

async fn observability_ready() -> impl IntoResponse {
    let database_configured = sb().is_some();
    let webtransport_live = WT_LIVE.load(Ordering::Relaxed);
    // ready = engine apna kaam kar sakta hai (DB truth maujood). WebTransport ki
    // asli halat alag field mein sach-sach report hoti hai — chhupai nahi jati,
    // aur uska apna gate (udp 3443 listener) alag hai.
    let ready = database_configured;
    let status = if ready {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };
    (
        status,
        Json(json!({
            "ready": ready,
            "database_configured": database_configured,
            "webtransport_live": webtransport_live,
            "rpc_port": PORT,
            "webtransport_port": 3443
        })),
    )
}

async fn observability_metrics() -> impl IntoResponse {
    let database_configured = if sb().is_some() { 1 } else { 0 };
    let webtransport_live = if WT_LIVE.load(Ordering::Relaxed) { 1 } else { 0 };
    (
        StatusCode::OK,
        format!(
            "anexomail_database_configured {database_configured}\n\
             anexomail_webtransport_live {webtransport_live}\n"
        ),
    )
}

async fn start_observability() {
    let app = Router::new()
        .route("/ready", get(observability_ready))
        .route("/metrics", get(observability_metrics));
    let addr = SocketAddr::from(([127, 0, 0, 1], OBSERVABILITY_PORT));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind observability 3600");
    println!("ANEXOMAIL Rust observability LIVE on {addr} (/ready + /metrics)");
    axum::serve(listener, app).await.expect("serve observability");
}

// ── PHASE 31A — REAL SFU MEDIA FORWARDING (:3500 tcp control · :3501 udp media) ──
//
// Yeh khali port nahi: UDP :3501 par asli packet forwarding hoti hai.
//   register datagram : "ANEXOSFU1 <room_id> <participant_id>"  -> "ANEXOSFU1 OK"
//   media datagram    : koi bhi doosra packet -> usi room ke baqi participants
//                       ko byte-for-byte forward (SFU = forward, mixing nahi).
// Media payload (SRTP) Rust kholta nahi — sirf raftaar deta hai; sach DB rows se
// aata hai. 60 second khamosh participant khud nikal jata hai.
struct SfuPeer {
    room: String,
    participant: String,
    addr: SocketAddr,
    last_seen: std::time::Instant,
}

#[derive(Default)]
struct SfuState {
    peers: Vec<SfuPeer>,
    packets_in: u64,
    packets_forwarded: u64,
    bytes_forwarded: u64,
}

static SFU_STATE: std::sync::OnceLock<std::sync::Mutex<SfuState>> = std::sync::OnceLock::new();

fn sfu_state() -> &'static std::sync::Mutex<SfuState> {
    SFU_STATE.get_or_init(|| std::sync::Mutex::new(SfuState::default()))
}

fn sfu_prune(state: &mut SfuState) {
    state
        .peers
        .retain(|p| p.last_seen.elapsed() < Duration::from_secs(60));
}

fn sfu_register(room: &str, participant: &str, addr: SocketAddr) {
    let mut state = sfu_state().lock().expect("sfu lock");
    sfu_prune(&mut state);
    state
        .peers
        .retain(|p| !(p.room == room && p.participant == participant));
    state.peers.push(SfuPeer {
        room: room.to_string(),
        participant: participant.to_string(),
        addr,
        last_seen: std::time::Instant::now(),
    });
}

/// Sender ke room ke baqi peers ke addresses (sender khud shamil nahi).
fn sfu_targets(from: SocketAddr, len: usize) -> Vec<SocketAddr> {
    let mut state = sfu_state().lock().expect("sfu lock");
    sfu_prune(&mut state);
    state.packets_in += 1;

    let mut room = None;
    for p in state.peers.iter_mut() {
        if p.addr == from {
            p.last_seen = std::time::Instant::now();
            room = Some(p.room.clone());
            break;
        }
    }
    let room = match room {
        Some(r) => r,
        None => return Vec::new(),
    };

    let targets: Vec<SocketAddr> = state
        .peers
        .iter()
        .filter(|p| p.room == room && p.addr != from)
        .map(|p| p.addr)
        .collect();
    state.packets_forwarded += targets.len() as u64;
    state.bytes_forwarded += (targets.len() * len) as u64;
    targets
}

fn sfu_snapshot() -> Value {
    let mut state = sfu_state().lock().expect("sfu lock");
    sfu_prune(&mut state);
    let mut rooms: std::collections::HashMap<String, usize> = std::collections::HashMap::new();
    for p in state.peers.iter() {
        *rooms.entry(p.room.clone()).or_insert(0) += 1;
    }
    json!({
        "live": SFU_LIVE.load(Ordering::Relaxed),
        "media_port": SFU_MEDIA_PORT,
        "control_port": SFU_CONTROL_PORT,
        "mode": "selective forwarding (no mixing, no transcoding)",
        "participants": state.peers.len(),
        "rooms": rooms.len(),
        "room_participants": rooms,
        "packets_in": state.packets_in,
        "packets_forwarded": state.packets_forwarded,
        "bytes_forwarded": state.bytes_forwarded
    })
}

async fn start_sfu_media() {
    let socket =
        match tokio::net::UdpSocket::bind(SocketAddr::from(([0, 0, 0, 0], SFU_MEDIA_PORT))).await {
            Ok(s) => s,
            Err(e) => {
                println!("SFU media OFF — bind udp/{SFU_MEDIA_PORT} failed: {e}");
                return;
            }
        };
    SFU_LIVE.store(true, Ordering::Relaxed);
    println!("ANEXOVideoCall SFU media LIVE on udp/{SFU_MEDIA_PORT} (forwarding)");

    let mut buf = vec![0u8; 2048];
    loop {
        let (len, from) = match socket.recv_from(&mut buf).await {
            Ok(v) => v,
            Err(_) => continue,
        };
        let packet = &buf[..len];

        if packet.starts_with(b"ANEXOSFU1 ") {
            let text = String::from_utf8_lossy(packet);
            let mut parts = text.trim().split_whitespace().skip(1);
            let room = parts.next().unwrap_or("").to_string();
            let participant = parts.next().unwrap_or("").to_string();
            if room.is_empty() || participant.is_empty() {
                let _ = socket
                    .send_to(b"ANEXOSFU1 ERR room_and_participant_required", from)
                    .await;
                continue;
            }
            sfu_register(&room, &participant, from);
            let _ = socket.send_to(b"ANEXOSFU1 OK", from).await;
            continue;
        }

        for target in sfu_targets(from, len) {
            let _ = socket.send_to(packet, target).await;
        }
    }
}

async fn sfu_ready() -> impl IntoResponse {
    let snapshot = sfu_snapshot();
    let status = if SFU_LIVE.load(Ordering::Relaxed) {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };
    (status, Json(snapshot))
}

async fn sfu_metrics() -> impl IntoResponse {
    let snapshot = sfu_snapshot();
    let n = |k: &str| snapshot.get(k).and_then(|v| v.as_u64()).unwrap_or(0);
    (
        StatusCode::OK,
        format!(
            "anexomail_sfu_live {}\n\
             anexomail_sfu_participants {}\n\
             anexomail_sfu_packets_in {}\n\
             anexomail_sfu_packets_forwarded {}\n\
             anexomail_sfu_bytes_forwarded {}\n",
            if SFU_LIVE.load(Ordering::Relaxed) { 1 } else { 0 },
            n("participants"),
            n("packets_in"),
            n("packets_forwarded"),
            n("bytes_forwarded")
        ),
    )
}

async fn start_sfu_control() {
    let app = Router::new()
        .route("/ready", get(sfu_ready))
        .route("/stats", get(sfu_ready))
        .route("/metrics", get(sfu_metrics));
    let addr = SocketAddr::from(([127, 0, 0, 1], SFU_CONTROL_PORT));
    let listener = match tokio::net::TcpListener::bind(addr).await {
        Ok(l) => l,
        Err(e) => {
            println!("SFU control OFF — bind tcp/{SFU_CONTROL_PORT} failed: {e}");
            return;
        }
    };
    println!("ANEXOVideoCall SFU control LIVE on {addr} (/ready + /stats + /metrics)");
    let _ = axum::serve(listener, app).await;
}

#[tokio::main]

async fn main() {
    let _ = dotenvy::from_path("/opt/anexomail-rust/.env");
    tracing_subscriber::fmt().with_target(false).init();

    tokio::spawn(start_webtransport());
    tokio::spawn(start_observability());
    // PHASE 31A — asli SFU: media forwarding + control readings
    tokio::spawn(start_sfu_media());
    tokio::spawn(start_sfu_control());
    // PHASE 17/18 — self-hosted safety worker (koi external API nahi)
    tokio::spawn(start_safety_worker());

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_headers(Any)
        .allow_methods(Any);

    let app = Router::new()
        .route("/rpc/health", get(health).post(health))
        // Public liveness face of the file engine (auth ke bagair 200) — is se
        // gateway readings 401/404 ki jagah asli 200 dikhati hain.
        .route("/file/ping", get(file_ping).post(file_ping))
        .route("/rpc/{proc}", post(dispatch).get(dispatch))
        // 16 MB chunk ceiling — 5 GB file 8 MB chunks mein aati hai.
        .route(
            "/file/chunk",
            post(file_chunk).layer(axum::extract::DefaultBodyLimit::max(16 * 1024 * 1024)),
        )
        // PHASE 31C — verified chunk stream (Phase 16 "downloaded" step ka raasta).
        .route("/file/download", get(file_download))
        .layer(cors);

    let addr = SocketAddr::from(([0, 0, 0, 0], PORT));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind 3200");
    println!("ANEXOMAIL Rust PRIMARY engine LIVE on {addr} (/rpc/* + ANEXOChat)");
    axum::serve(listener, app).await.expect("serve");
}
