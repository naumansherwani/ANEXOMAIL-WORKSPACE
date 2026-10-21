// ============================================================================
// events_glue.rs — B4 (R5): event-driven live push over WebTransport/QUIC for the WHOLE website (every plan, every account kind,
// family included: the hub is keyed by org membership, never by plan).
//
// Before: each open mail screen made its own server-side DB poll every 700 ms (N tabs = N queries per 0.7 s) and only "mail" existed.
// Now:
//   * ONE hub per org (tokio broadcast). Browsers subscribe with  hello {token, mode:"events", topics:[mail,calendar,crm,work,people,org]}
//     (old `mode:"mail"` still works, same frames) and receive  {"type":"event","topic":..,"seq":..}  lines; mail events also carry the
//     unread / last_message_at stamp so the UI needs no extra call.
//   * PUBLISHERS (instant): every successful mutating /rpc/* (axum layer) · POST /internal/event (loopback + secret; used by the
//     inbound mail pipe and Bun fallbacks) · the Rust mail worker path goes through /rpc as well.
//   * SAFETY NET (not a poll per user): one reconcile task per ACTIVE org compares the mail stamp every 2 s and publishes on change, so
//     writers that cannot notify (Bun, SQL) still reach the screen in <= 2 s. It stops when the last listener leaves.
//   * Sessions re-check the login every 5 min (revoked / expired => closed), 25 s pings find dead links, slow clients are cut after 10 s.
// Child module of the crate root: uses `mail_identity`, `mail_inbox_stamp`, `auth_user`, `wt_send_final`, `env_var`.
// ============================================================================

use crate::events_core as ec;
use axum::{
    extract::Request,
    http::{HeaderMap, StatusCode},
    middleware::Next,
    response::{IntoResponse, Response},
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};
use tokio::sync::broadcast;

const MAX_LISTENERS_PER_ORG: usize = 64;
const RECONCILE: Duration = Duration::from_secs(2);
const PING: Duration = Duration::from_secs(25);
const RECHECK_EVERY_PINGS: u32 = 12; // 12 x 25 s = 5 min

#[derive(Clone, Debug)]
struct Ev {
    topic: &'static str,
    seq: u64,
}

struct OrgHub {
    tx: broadcast::Sender<Ev>,
    seq: AtomicU64,
    stamp: Mutex<Option<(Instant, (i64, String))>>,
    last: Mutex<String>,
    watching: AtomicBool,
}

type Hubs = Mutex<HashMap<String, Arc<OrgHub>>>;
fn hubs() -> &'static Hubs {
    static H: OnceLock<Hubs> = OnceLock::new();
    H.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn enabled() -> bool {
    !crate::env_var("EVENTS").eq_ignore_ascii_case("off")
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

// ── hub ─────────────────────────────────────────────────────────────────────
fn join(org: &str) -> Option<(Arc<OrgHub>, broadcast::Receiver<Ev>)> {
    let mut map = hubs().lock().ok()?;
    let hub = map
        .entry(org.to_string())
        .or_insert_with(|| {
            Arc::new(OrgHub { tx: broadcast::channel(256).0, seq: AtomicU64::new(0), stamp: Mutex::new(None), last: Mutex::new(String::new()), watching: AtomicBool::new(false) })
        })
        .clone();
    if hub.tx.receiver_count() >= MAX_LISTENERS_PER_ORG {
        return None;
    }
    let rx = hub.tx.subscribe(); // under the map lock: the reconcile task can never remove a hub that just gained a listener
    if !hub.watching.swap(true, Ordering::SeqCst) {
        tokio::spawn(watch(org.to_string(), hub.clone()));
    }
    Some((hub, rx))
}

fn emit(hub: &OrgHub, topic: &'static str) {
    if hub.tx.receiver_count() == 0 {
        return;
    }
    let seq = hub.seq.fetch_add(1, Ordering::SeqCst) + 1;
    let _ = hub.tx.send(Ev { topic, seq });
}

/// Called after any change to `topic` in `org`. Free when nobody listens.
pub fn publish(org: &str, topic: &'static str) {
    let hub = match hubs().lock() {
        Ok(m) => m.get(org).cloned(),
        Err(_) => None,
    };
    if let Some(h) = hub {
        if topic == "mail" {
            if let Ok(mut s) = h.stamp.lock() {
                *s = None;
            }
        }
        emit(&h, topic);
    }
}

async fn stamp(org: &str, hub: &OrgHub) -> Option<(i64, String)> {
    if let Ok(s) = hub.stamp.lock() {
        if let Some((at, v)) = s.as_ref() {
            if at.elapsed() < Duration::from_millis(400) {
                return Some(v.clone());
            }
        }
    }
    let v = crate::mail_inbox_stamp(org).await.ok()?;
    if let Ok(mut s) = hub.stamp.lock() {
        *s = Some((Instant::now(), v.clone()));
    }
    Some(v)
}

/// One reconcile task per active org (NOT per session). Ends when the last listener has left.
async fn watch(org: String, hub: Arc<OrgHub>) {
    // Seed the baseline NOW (not after the first 2 s sleep): a mail that lands in the first seconds must still count as a change.
    if let Ok((u, at)) = crate::mail_inbox_stamp(&org).await {
        if let Ok(mut l) = hub.last.lock() {
            *l = format!("{u}|{at}");
        }
    }
    loop {
        tokio::time::sleep(RECONCILE).await;
        if hub.tx.receiver_count() == 0 {
            if let Ok(mut map) = hubs().lock() {
                if hub.tx.receiver_count() == 0 {
                    if map.get(&org).is_some_and(|h| Arc::ptr_eq(h, &hub)) {
                        map.remove(&org);
                    }
                    hub.watching.store(false, Ordering::SeqCst);
                    return;
                }
            }
            continue;
        }
        if let Ok((u, at)) = crate::mail_inbox_stamp(&org).await {
            let key = format!("{u}|{at}");
            let changed = match hub.last.lock() {
                Ok(mut l) => {
                    let first = l.is_empty();
                    let ch = *l != key;
                    if ch {
                        *l = key;
                    }
                    ch && !first
                }
                Err(_) => false,
            };
            if let Ok(mut s) = hub.stamp.lock() {
                *s = Some((Instant::now(), (u, at)));
            }
            if changed {
                emit(&hub, "mail");
            }
        }
    }
}

// ── one browser session ─────────────────────────────────────────────────────
async fn put(send: &mut wtransport::SendStream, frame: &str) -> bool {
    matches!(tokio::time::timeout(Duration::from_secs(10), send.write_all(frame.as_bytes())).await, Ok(Ok(())))
}

async fn frame_for(topic: &'static str, seq: u64, legacy_mail: bool, org: &str, hub: &OrgHub) -> String {
    if topic != "mail" {
        return ec::frame_event(topic, seq, "");
    }
    match stamp(org, hub).await {
        Some((unread, at)) if legacy_mail => format!("{}\n", json!({ "type": "mail", "unread": unread, "last_message_at": at })),
        Some((unread, at)) => ec::frame_event("mail", seq, &format!("\"unread\":{unread},\"last_message_at\":{}", Value::String(at))),
        None => ec::frame_event("mail", seq, ""),
    }
}

/// WebTransport hello {token, mode:"events"|"mail", topics?, org_id?}. Never decided by plan: any signed-in org member gets it.
pub async fn serve(mut send: wtransport::SendStream, token: &str, hello: &Value) {
    let legacy_mail = st(hello, "mode") == "mail";
    let topics: Vec<&'static str> = if legacy_mail {
        vec!["mail"]
    } else {
        let raw: Vec<String> = hello.get("topics").and_then(|t| t.as_array()).map(|a| a.iter().filter_map(|x| x.as_str().map(|s| s.to_string())).collect()).unwrap_or_default();
        ec::parse_topics(&raw)
    };
    let me = match crate::mail_identity(token, &{
        let o = st(hello, "org_id");
        if ec::is_uuid(&o) { o.to_lowercase() } else { String::new() }
    })
    .await
    {
        Ok(m) => m,
        Err((_, code, _)) => {
            crate::wt_send_final(&mut send, format!("{{\"type\":\"error\",\"code\":\"{code}\"}}\n").as_bytes()).await;
            return;
        }
    };
    let Some((hub, mut rx)) = join(&me.org_id) else {
        crate::wt_send_final(&mut send, b"{\"type\":\"error\",\"code\":\"too_many_listeners\"}\n").await;
        return;
    };
    let ready = if legacy_mail { "{\"type\":\"ready\",\"transport\":\"webtransport\",\"mode\":\"mail\"}\n".to_string() } else { ec::frame_ready("events", &topics) };
    if !put(&mut send, &ready).await {
        return;
    }
    if topics.contains(&"mail") {
        let f = frame_for("mail", 0, legacy_mail, &me.org_id, &hub).await;
        if !put(&mut send, &f).await {
            return;
        }
    }
    let mut ping = tokio::time::interval(PING);
    ping.tick().await;
    let mut pings = 0u32;
    loop {
        tokio::select! {
            ev = rx.recv() => {
                let mut dirty: Vec<(&'static str, u64)> = Vec::new();
                match ev {
                    Ok(e) => dirty.push((e.topic, e.seq)),
                    Err(broadcast::error::RecvError::Lagged(_)) => dirty.extend(topics.iter().map(|t| (*t, 0))),
                    Err(broadcast::error::RecvError::Closed) => return,
                }
                tokio::time::sleep(Duration::from_millis(120)).await; // coalesce a burst into one frame per topic
                while let Ok(e) = rx.try_recv() { dirty.push((e.topic, e.seq)); }
                for t in &topics {
                    if let Some((topic, seq)) = dirty.iter().rev().find(|(x, _)| x == t).copied() {
                        let f = frame_for(topic, seq, legacy_mail, &me.org_id, &hub).await;
                        if !put(&mut send, &f).await { return; }
                    }
                }
            }
            _ = ping.tick() => {
                pings += 1;
                if pings % RECHECK_EVERY_PINGS == 0 && crate::auth_user(token).await.is_none() {
                    crate::wt_send_final(&mut send, b"{\"type\":\"error\",\"code\":\"session_ended\"}\n").await;
                    return;
                }
                if !put(&mut send, ec::frame_ping()).await { return; }
            }
        }
    }
}

// ── publishers ──────────────────────────────────────────────────────────────
fn org_cache() -> &'static Mutex<HashMap<String, (Instant, String)>> {
    static C: OnceLock<Mutex<HashMap<String, (Instant, String)>>> = OnceLock::new();
    C.get_or_init(|| Mutex::new(HashMap::new()))
}

async fn org_of(token: &str) -> Option<String> {
    let key: String = Sha256::digest(token.as_bytes()).iter().map(|b| format!("{b:02x}")).collect();
    if let Ok(c) = org_cache().lock() {
        if let Some((at, org)) = c.get(&key) {
            if ec::cache_ok(at.elapsed().as_secs(), 60) {
                return Some(org.clone());
            }
        }
    }
    let org = crate::mail_identity(token, "").await.ok()?.org_id;
    if let Ok(mut c) = org_cache().lock() {
        if c.len() > 4096 {
            c.clear();
        }
        c.insert(key, (Instant::now(), org.clone()));
    }
    Some(org)
}

/// axum layer: a successful mutating /rpc/<proc> tells that org's listeners. Costs nothing when no browser is subscribed anywhere.
pub async fn publish_layer(req: Request, next: Next) -> Response {
    let topic = req
        .uri()
        .path()
        .strip_prefix("/rpc/")
        .filter(|_| req.method() == axum::http::Method::POST)
        .filter(|p| ec::is_mutation(p))
        .and_then(ec::topic_for_proc);
    let token = topic.and_then(|_| req.headers().get("authorization")).and_then(|v| v.to_str().ok()).and_then(|v| v.strip_prefix("Bearer ")).map(|t| t.to_string());
    let resp = next.run(req).await;
    if let (Some(topic), Some(token)) = (topic, token) {
        if resp.status().is_success() && hubs().lock().map(|m| !m.is_empty()).unwrap_or(false) {
            tokio::spawn(async move {
                if let Some(org) = org_of(&token).await {
                    publish(&org, topic);
                }
            });
        }
    }
    resp
}

/// POST /internal/event {org_id, topic} — for processes that write data outside /rpc (inbound mail pipe, Bun fallback).
/// Closed unless EVENT_SECRET (>= 24 chars) is set; refuses anything that came through the public proxy.
pub async fn internal_event(headers: HeaderMap, body: axum::body::Bytes) -> Response {
    let secret = crate::env_var("EVENT_SECRET");
    if secret.len() < 24 {
        return StatusCode::NOT_FOUND.into_response();
    }
    if ec::came_via_proxy(headers.contains_key("x-forwarded-for"), headers.contains_key("forwarded"), headers.contains_key("x-real-ip")) {
        return StatusCode::FORBIDDEN.into_response();
    }
    let given = headers.get("x-event-secret").and_then(|v| v.to_str().ok()).unwrap_or("");
    if !ec::secret_ok(given, &secret) {
        return StatusCode::UNAUTHORIZED.into_response();
    }
    let Ok(v) = serde_json::from_slice::<Value>(&body) else { return StatusCode::BAD_REQUEST.into_response() };
    let org = st(&v, "org_id").to_lowercase();
    let Some(topic) = ec::topic_ok(&st(&v, "topic")) else { return StatusCode::BAD_REQUEST.into_response() };
    if !ec::is_uuid(&org) {
        return StatusCode::BAD_REQUEST.into_response();
    }
    publish(&org, topic);
    StatusCode::NO_CONTENT.into_response()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn publish_reaches_only_listeners_of_that_org() {
        let (_h1, mut a) = join("org-a").unwrap();
        let (_h2, mut b) = join("org-b").unwrap();
        publish("org-a", "calendar");
        let e = tokio::time::timeout(Duration::from_millis(500), a.recv()).await.unwrap().unwrap();
        assert_eq!((e.topic, e.seq), ("calendar", 1));
        assert!(tokio::time::timeout(Duration::from_millis(150), b.recv()).await.is_err());
        publish("org-a", "crm");
        let e = a.recv().await.unwrap();
        assert_eq!((e.topic, e.seq), ("crm", 2));
    }

    #[tokio::test]
    async fn publish_without_listeners_is_free_and_listener_cap_holds() {
        publish("nobody", "mail");
        assert!(hubs().lock().unwrap().get("nobody").is_none());
        let mut keep = Vec::new();
        for _ in 0..MAX_LISTENERS_PER_ORG {
            keep.push(join("org-cap").unwrap());
        }
        assert!(join("org-cap").is_none());
    }

    #[tokio::test]
    async fn internal_event_is_closed_by_default() {
        let h = HeaderMap::new();
        let r = internal_event(h, axum::body::Bytes::from_static(b"{}")).await;
        assert_eq!(r.status(), StatusCode::NOT_FOUND);
    }
}
