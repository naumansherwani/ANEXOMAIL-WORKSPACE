//! QLIVE (founder mailbox, 18 Nov 2026): LIVE MAIL WITHOUT A REFRESH. Rust (Tokio + axum) over the E187 change log.
//! Technology: Tokio (`broadcast`, `Notify`, `select!`), the existing WebTransport / QUIC / HTTP/3 live stream (a new signed event `mail`), the Rust WASM kernel (verifies every frame and every door answer),
//! PostgreSQL E187 (gapless hash-chained per-mailbox change log). Research (JMAP RFC 8620, IMAP NOTIFY RFC 5465, Postgres LISTEN/NOTIFY limits): a push is only a PROMPT ("this mailbox is now at head N");
//! the truth is always the cursor door `GET /founder/v1/mail/changes`, so a lost or merged frame costs nothing. Plan: docs/claude/QLIVE-PLAN-18NOV.md.
//! HOW THE WAKE-UP WORKS: (1) in-process poke: every write that goes through this binary (intake, sender, mail actions) calls `poke()` right after it succeeded, zero delay; (2) a SAFETY check every 2 s
//! while at least one stream is open (one tiny `fmail_change_heads187` call), so a write made by anything else still shows within 2 s. No stream open = the watcher sleeps and makes no database call at all.
//! The frame carries NO mail content, only {box, head} (inside a normal signed `tick`, see frame_json). Privacy: the log holds ids and a closed kind.
use crate::data::Sb;
use axum::{extract::State, http::{HeaderMap, StatusCode, Uri}, response::{IntoResponse, Response}};
use serde_json::{json, Value};
use std::{collections::HashMap, sync::{Arc, OnceLock}, time::Duration};
use tokio::sync::{broadcast, Notify};

/// How often the watcher re-reads the heads while at least one stream is open.
pub const SAFETY_EVERY: Duration = Duration::from_secs(2);
/// Most changes one door answer returns (the browser pages with `more`).
pub const MAX_PAGE: u32 = 200;

#[derive(Clone, Debug, PartialEq)]
pub struct Ping { pub mailbox: String, pub head: i64 }

pub struct Hub { pub tx: broadcast::Sender<Arc<Ping>>, pub wake: Notify }
static HUB: OnceLock<Arc<Hub>> = OnceLock::new();
pub fn hub() -> Arc<Hub> { HUB.get_or_init(|| Arc::new(Hub { tx: broadcast::channel(64).0, wake: Notify::new() })).clone() }

/// Wake the watcher now (a mail was stored, sent, moved, flagged ...). Cheap, never blocks, safe to call from anywhere.
pub fn poke() { hub().wake.notify_one(); }

/// The signed frame body for one ping. Tiny on purpose. It is shaped as a normal live `tick` ({version, changed, at, ok}) plus a `mail` object, because the shared Rule 52 kernel only
/// passes the events snapshot / tick / events (flive.rs) and the founder lane must not fork that shared kernel: `version` is the stream's own last version (never a regress), `changed` names the source "mail".
pub fn frame_json(p: &Ping, version: i64, at_s: i64) -> Value { json!({"version": version, "changed": ["mail"], "at": at_s, "ok": true, "mail": {"box": p.mailbox, "head": p.head}}) }

/// Read the answer of `fmail_change_heads187`: [{mailbox, head}]. Entries that are not the promised shape are skipped (never invented).
pub fn parse_heads(v: &Value) -> Vec<Ping> {
    v.as_array().map(|a| a.iter().filter_map(|e| {
        let m = e.get("mailbox")?.as_str()?; let h = e.get("head")?.as_i64()?;
        if h < 0 || !crate::passkey::is_uuid(m) { return None; }
        Some(Ping { mailbox: m.to_string(), head: h })
    }).collect()).unwrap_or_default()
}

/// Which heads must be announced: every mailbox whose head is higher than the last head announced for it (a mailbox never announced yet counts: the browser compares with its own cursor and ignores a no-op).
pub fn moved(seen: &HashMap<String, i64>, now: &[Ping]) -> Vec<Ping> {
    now.iter().filter(|p| seen.get(&p.mailbox).is_none_or(|h| p.head > *h)).cloned().collect()
}

/// Start the one process-wide watcher. FOUNDER_MAIL_LIVE=off disables it (rollback switch): the browser then simply keeps its 5 s read.
pub fn start(sb: Sb) {
    if std::env::var("FOUNDER_MAIL_LIVE").map(|v| v == "off").unwrap_or(false) { eprintln!("founder: live mail push is OFF (FOUNDER_MAIL_LIVE=off)"); return; }
    let h = hub();
    eprintln!("founder: live mail push ON (poke + {} s safety check while a stream is open)", SAFETY_EVERY.as_secs());
    tokio::spawn(async move {
        let mut seen: HashMap<String, i64> = HashMap::new();
        loop {
            tokio::select! { _ = h.wake.notified() => {}, _ = tokio::time::sleep(SAFETY_EVERY) => {} }
            if h.tx.receiver_count() == 0 { seen.clear(); continue; }   // nobody is listening: no database call at all
            let Ok(Some(v)) = tokio::time::timeout(Duration::from_secs(4), sb.rpc("fmail_change_heads187", json!({}))).await else { continue };
            let now = parse_heads(&v);
            for p in moved(&seen, &now) { seen.insert(p.mailbox.clone(), p.head); let _ = h.tx.send(Arc::new(p)); }
        }
    });
}

/// Middleware: after ANY write (not GET) to a mail door, wake the watcher. The answer is untouched.
pub async fn poke_mw(req: axum::extract::Request, next: axum::middleware::Next) -> Response {
    let write = req.method() != axum::http::Method::GET && req.uri().path().starts_with("/founder/v1/mail/");
    let res = next.run(req).await;
    if write { poke(); }
    res
}

/// `after` and `limit` from a query string. after = 0 when absent, limit is capped at MAX_PAGE. A value that is not a plain number is an error (never guessed).
pub fn parse_cursor(q: Option<&str>) -> Result<(i64, u32), &'static str> {
    let (mut after, mut limit) = (0i64, 100u32);
    for kv in q.unwrap_or("").split('&') {
        match kv.split_once('=') {
            Some(("after", v)) => after = v.parse::<i64>().ok().filter(|n| (0..=i64::MAX / 2).contains(n)).ok_or("after must be a whole number")?,
            Some(("limit", v)) => limit = v.parse::<u32>().ok().filter(|n| *n >= 1).ok_or("limit must be a whole number")?.min(MAX_PAGE),
            _ => {}
        }
    }
    Ok((after, limit))
}

/// GET /founder/v1/mail/changes?box=<uuid>&after=<seq>&limit=<n>: the changes after a cursor (E187 `fmail_change_since187`). Signed answer (the kernel verifies it). `gap: true` = full refresh.
pub async fn changes_ep(State(st): State<crate::S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let b = match crate::fmail_ep::parse_box(uri.query()) { Ok(b) => b, Err(e) => return (StatusCode::BAD_REQUEST, axum::Json(json!({"error": e}))).into_response() };
    let (after, limit) = match parse_cursor(uri.query()) { Ok(x) => x, Err(e) => return (StatusCode::BAD_REQUEST, axum::Json(json!({"error": e}))).into_response() };
    let Some(sb) = st.sb.as_ref() else { return StatusCode::SERVICE_UNAVAILABLE.into_response() };
    let call = sb.rpc_msg("fmail_change_since187", json!({"p_actor": c.sub, "p_mailbox": b, "p_after": after, "p_limit": limit}));
    match tokio::time::timeout(Duration::from_secs(6), call).await {
        Err(_) => (StatusCode::GATEWAY_TIMEOUT, axum::Json(json!({"error": "the database did not answer in time"}))).into_response(),
        Ok(Err(_)) => (StatusCode::SERVICE_UNAVAILABLE, axum::Json(json!({"error": "the change log is not available (E187 not installed?)"}))).into_response(),
        Ok(Ok(v)) if v["ok"] == true => crate::signed(&st, v),
        Ok(Ok(_)) => (StatusCode::NOT_FOUND, axum::Json(json!({"error": "no such mailbox"}))).into_response(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    const A: &str = "11111111-1111-4111-8111-111111111111";
    const B: &str = "22222222-2222-4222-8222-222222222222";

    #[test]
    fn heads_are_read_in_the_promised_shape_and_everything_else_is_skipped() {
        let v = json!([{"mailbox": A, "head": 5}, {"mailbox": "not-a-uuid", "head": 1}, {"mailbox": B}, {"mailbox": B, "head": -2}, {"head": 3}, "x"]);
        assert_eq!(parse_heads(&v), vec![Ping { mailbox: A.into(), head: 5 }]);
        assert!(parse_heads(&json!({"a": 1})).is_empty()); assert!(parse_heads(&Value::Null).is_empty());
    }
    #[test]
    fn only_a_higher_head_is_announced_and_a_new_mailbox_always_is() {
        let mut seen = HashMap::new();
        let now = vec![Ping { mailbox: A.into(), head: 4 }, Ping { mailbox: B.into(), head: 0 }];
        assert_eq!(moved(&seen, &now).len(), 2);                       // first sight of both
        for p in &now { seen.insert(p.mailbox.clone(), p.head); }
        assert!(moved(&seen, &now).is_empty());                        // nothing moved
        let later = vec![Ping { mailbox: A.into(), head: 6 }, Ping { mailbox: B.into(), head: 0 }];
        assert_eq!(moved(&seen, &later), vec![Ping { mailbox: A.into(), head: 6 }]);
        let lower = vec![Ping { mailbox: A.into(), head: 2 }];         // a head that went DOWN (log reset) is not announced here; the browser sees `gap` from the door
        assert!(moved(&seen, &lower).is_empty());
    }
    #[test]
    fn the_frame_is_a_normal_tick_with_a_mail_part_of_box_and_head_only() {
        let f = frame_json(&Ping { mailbox: A.into(), head: 9 }, 41, 1_700_000_000);
        assert_eq!(f, json!({"version": 41, "changed": ["mail"], "at": 1_700_000_000, "ok": true, "mail": {"box": A, "head": 9}}));
        assert_eq!(f["mail"].as_object().unwrap().len(), 2); // the mail part is only {box, head}
    }
    #[test]
    fn the_cursor_query_is_strict() {
        assert_eq!(parse_cursor(Some("box=x")).unwrap(), (0, 100));
        assert_eq!(parse_cursor(Some("box=x&after=41&limit=50")).unwrap(), (41, 50));
        assert_eq!(parse_cursor(Some("after=3&limit=99999")).unwrap(), (3, MAX_PAGE));
        assert!(parse_cursor(Some("after=-1")).is_err()); assert!(parse_cursor(Some("after=abc")).is_err());
        assert!(parse_cursor(Some("limit=0")).is_err()); assert!(parse_cursor(Some("limit=1.5")).is_err());
        assert_eq!(parse_cursor(None).unwrap(), (0, 100));
    }
    #[tokio::test]
    async fn a_poke_wakes_the_watcher_and_a_ping_reaches_every_subscriber() {
        let h = hub();
        let mut r1 = h.tx.subscribe(); let mut r2 = h.tx.subscribe();
        assert!(h.tx.receiver_count() >= 2);
        h.tx.send(Arc::new(Ping { mailbox: A.into(), head: 1 })).unwrap();
        assert_eq!(r1.recv().await.unwrap().head, 1); assert_eq!(r2.recv().await.unwrap().head, 1);
        poke();                                                        // stored permit: the next wait returns at once
        tokio::time::timeout(Duration::from_millis(200), h.wake.notified()).await.expect("the poke must wake the watcher");
    }
    #[tokio::test]
    async fn the_poke_middleware_pokes_on_a_mail_write_only() {
        use axum::{body::Body, http::Request, routing::{get, post}, Router};
        use tower::ServiceExt;
        let app = Router::new().route("/founder/v1/mail/flag", post(|| async { "ok" })).route("/founder/v1/mail/counts", get(|| async { "ok" })).route("/founder/v1/other", post(|| async { "ok" })).layer(axum::middleware::from_fn(poke_mw));
        let h = hub();
        let _ = tokio::time::timeout(Duration::from_millis(5), h.wake.notified()).await;          // drain any stored permit
        let quiet = |m: &'static str, p: &'static str| Request::builder().method(m).uri(p).body(Body::empty()).unwrap();
        let _ = app.clone().oneshot(quiet("GET", "/founder/v1/mail/counts")).await.unwrap();
        assert!(tokio::time::timeout(Duration::from_millis(50), h.wake.notified()).await.is_err(), "a read must not poke");
        let _ = app.clone().oneshot(quiet("POST", "/founder/v1/other")).await.unwrap();
        assert!(tokio::time::timeout(Duration::from_millis(50), h.wake.notified()).await.is_err(), "a write outside the mail doors must not poke");
        let r = app.clone().oneshot(quiet("POST", "/founder/v1/mail/flag")).await.unwrap();
        assert_eq!(r.status(), 200);
        assert!(tokio::time::timeout(Duration::from_millis(200), h.wake.notified()).await.is_ok(), "a mail write must poke");
    }
}
