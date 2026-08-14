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

    if !proc.starts_with("chat.") {
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

#[tokio::main]
async fn main() {
    let _ = dotenvy::from_path("/opt/anexomail-rust/.env");
    tracing_subscriber::fmt().with_target(false).init();

    tokio::spawn(start_webtransport());

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_headers(Any)
        .allow_methods(Any);

    let app = Router::new()
        .route("/rpc/health", get(health).post(health))
        .route("/rpc/:proc", post(dispatch).get(dispatch))
        .layer(cors);

    let addr = SocketAddr::from(([0, 0, 0, 0], PORT));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind 3200");
    println!("ANEXOMAIL Rust PRIMARY engine LIVE on {addr} (/rpc/* + ANEXOChat)");
    axum::serve(listener, app).await.expect("serve");
}
