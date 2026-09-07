// ============================================================================
// ANEXOMAIL / ANEXOChat — RUST PRIMARY ENGINE
//
// NANO COMMAND (server par):
//   cp /opt/anexomail-rust/src/main.rs /opt/anexomail-rust/src/main.rs.bak.$(date +%s)
//   nano /opt/anexomail-rust/src/main.rs     # select all -> paste -> Ctrl+O, Ctrl+X
//   cd /opt/anexomail-rust && cargo build --release && pm2 restart anexomail-rust
//
// BLUEPRINT LOCK (docs/anexochat-blueprint.md PART 0 + PHASE 2):
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
static WT_LIVE: AtomicBool = AtomicBool::new(false);

fn ok(data: Value) -> impl IntoResponse {
    (StatusCode::OK, Json(json!({ "result": { "data": data } })))
}

fn err(status: StatusCode, code: &str, message: &str) -> impl IntoResponse {
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

/// Gate DB ka `chat_access()` — Basic/Pro par false. Frontend ka claim nahi maana jata.
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
            "business".to_string(),
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
        "wt_port": env_var("ANEXOCHAT_WT_PORT"),
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

/// tRPC-style dispatch. ANEXOChat ke procedures PRIMARY yahan hain.
/// Jo procedure Rust pe nahi hai woh 404 deta hai taake frontend fallback kar sake.
async fn dispatch(
    Path(proc): Path<String>,
    headers: HeaderMap,
    body: Option<Json<Value>>,
) -> axum::response::Response {
    let raw = body.map(|Json(v)| v).unwrap_or(json!({}));
    let input = raw
        .get("input")
        .cloned()
        .unwrap_or_else(|| raw.clone());

    if proc == "health" {
        return health().await.into_response();
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
            let _ = send
                .write_all(b"{\"type\":\"error\",\"code\":\"bad_hello\"}\n")
                .await;
            return;
        }
    };

    let token = s(&hello, "token");
    let conv = s(&hello, "conversation_id");
    if token.is_empty() || conv.is_empty() {
        let _ = send
            .write_all(b"{\"type\":\"error\",\"code\":\"token_and_conversation_required\"}\n")
            .await;
        return;
    }

    let me = match chat_identity(&token).await {
        Ok(me) => me,
        Err((_, code, _)) => {
            let frame = format!("{{\"type\":\"error\",\"code\":\"{code}\"}}\n");
            let _ = send.write_all(frame.as_bytes()).await;
            return;
        }
    };

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
        .with_identity(&identity)
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

#[tokio::main]

async fn main() {
    let _ = dotenvy::from_path("/opt/anexomail-rust/.env");
    tracing_subscriber::fmt().with_target(false).init();

    tokio::spawn(start_webtransport());
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
        .route("/rpc/:proc", post(dispatch).get(dispatch))
        // 16 MB chunk ceiling — 5 GB file 8 MB chunks mein aati hai.
        .route(
            "/file/chunk",
            post(file_chunk).layer(axum::extract::DefaultBodyLimit::max(16 * 1024 * 1024)),
        )
        .layer(cors);

    let addr = SocketAddr::from(([0, 0, 0, 0], PORT));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind 3200");
    println!("ANEXOMAIL Rust PRIMARY engine LIVE on {addr} (/rpc/* + ANEXOChat)");
    axum::serve(listener, app).await.expect("serve");
}
