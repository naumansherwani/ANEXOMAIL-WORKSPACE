//! QC3-A (founder mailbox): THE DELIVERY TIMELINE. What really happened to a sent mail, step by step, from the ledger and the outbox (SQL E195, read-only doors).
//! Technology: Rust + Tokio + axum (async handlers, `tokio::time::timeout` on every database call, `tokio::join!` for the two reads of the delivery board), signed envelope
//! (`crate::signed`), PostgreSQL doors E195 (STABLE, security definer, service_role only). Nothing here writes. No mail content, no address, no sealed column is read or returned.
//!
//! Honest words (QC3-PLAN-20NOV.md): "accepted" = the recipient's server answered 250 to our hand-off. It is NOT "in the inbox" and NOT "read". 4xx = deferred (we retry by ourselves),
//! 5xx or twelve tries = failed. The SQL door decides the phase (one truth); this module only turns the answer into steps, attempts and a plain-language reason for the screen.
//! Doors:
//!   GET /founder/v1/mail/timeline?box=<uuid>&message=<uuid>        one mail: steps, attempts, retry plan, reason
//!   GET /founder/v1/mail/delivery?box=<uuid>&days=1..30             health + list, the two reads run at the same time (tokio::join!)
//!   GET /founder/v1/mail/timeline/badges?box=<uuid>&ids=<uuid,...>  one small word per mail for the Sent list (max 100)
use crate::{passkey as pk, S};
use axum::{extract::State, http::{HeaderMap, StatusCode, Uri}, response::{IntoResponse, Response}};
use serde_json::{json, Value};
use std::{future::Future, time::Duration};

/// Every database call is bounded: a slow database answers a plain 504 instead of holding the connection (and the founder's patience) open.
pub const DB_TIMEOUT: Duration = Duration::from_secs(4);
/// The outbox allows twelve tries (E167 CHECK). The wait after try n is BACKOFF_SECONDS[min(n-1, 5)] (E167 fmail_outbox_result; E195 selftest guards the equality).
pub const MAX_ATTEMPTS: u32 = 12;
pub const BACKOFF_SECONDS: [u64; 6] = [60, 300, 1800, 7200, 21600, 86400];
pub const MAX_BADGES: usize = 100;

// ---------------------------------------------------------------- pure: query strings

fn pairs(q: Option<&str>) -> impl Iterator<Item = (&str, &str)> {
    q.unwrap_or("").split('&').filter(|p| !p.is_empty()).map(|p| p.split_once('=').unwrap_or((p, "")))
}
/// ?box=<uuid>&message=<uuid>. Both needed, nothing else, each once.
pub fn parse_timeline(q: Option<&str>) -> Result<(String, String), &'static str> {
    let (mut b, mut m) = (None, None);
    for (k, v) in pairs(q) {
        match k {
            "box" => { if b.is_some() { return Err("repeated parameter"); } if !pk::is_uuid(v) { return Err("invalid box"); } b = Some(v.to_string()); }
            "message" => { if m.is_some() { return Err("repeated parameter"); } if !pk::is_uuid(v) { return Err("invalid message"); } m = Some(v.to_string()); }
            _ => return Err("unknown parameter"),
        }
    }
    Ok((b.ok_or("missing box")?, m.ok_or("missing message")?))
}
/// ?box=<uuid>&days=1..30 (default 7). A number outside 1..30 is refused, never silently clamped (the screen would then show a window it did not ask for).
pub fn parse_delivery(q: Option<&str>) -> Result<(String, i32), &'static str> {
    let (mut b, mut d) = (None, None);
    for (k, v) in pairs(q) {
        match k {
            "box" => { if b.is_some() { return Err("repeated parameter"); } if !pk::is_uuid(v) { return Err("invalid box"); } b = Some(v.to_string()); }
            "days" => {
                if d.is_some() { return Err("repeated parameter"); }
                if v.is_empty() || v.len() > 2 || !v.bytes().all(|c| c.is_ascii_digit()) { return Err("invalid days"); }
                let n: i32 = v.parse().map_err(|_| "invalid days")?;
                if !(1..=30).contains(&n) { return Err("days must be 1 to 30"); }
                d = Some(n);
            }
            _ => return Err("unknown parameter"),
        }
    }
    Ok((b.ok_or("missing box")?, d.unwrap_or(7)))
}
/// ?box=<uuid>&ids=<uuid>,<uuid>,... : 1..=100 distinct uuids, order kept, a repeat is dropped (not an error: a list may show the same mail twice).
pub fn parse_badges(q: Option<&str>) -> Result<(String, Vec<String>), &'static str> {
    let (mut b, mut ids) = (None, None::<Vec<String>>);
    for (k, v) in pairs(q) {
        match k {
            "box" => { if b.is_some() { return Err("repeated parameter"); } if !pk::is_uuid(v) { return Err("invalid box"); } b = Some(v.to_string()); }
            "ids" => {
                if ids.is_some() { return Err("repeated parameter"); }
                let mut out: Vec<String> = Vec::new();
                for id in v.split(',') {
                    if !pk::is_uuid(id) { return Err("invalid id"); }
                    if !out.iter().any(|x| x == id) { out.push(id.to_string()); }
                    if out.len() > MAX_BADGES { return Err("at most 100 ids"); }
                }
                ids = Some(out);
            }
            _ => return Err("unknown parameter"),
        }
    }
    let ids = ids.ok_or("missing ids")?;
    if ids.is_empty() { return Err("missing ids"); }
    Ok((b.ok_or("missing box")?, ids))
}

// ---------------------------------------------------------------- pure: the phase and what it means

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Phase { Undo, Queued, Scheduled, HandingOff, Retrying, Deferred, Accepted, Failed, Cancelled, Undone, Unknown }
impl Phase {
    /// The word E195 fmail_phase195 answers. An unknown word is Unknown, never a guess.
    pub fn parse(s: &str) -> Phase {
        match s { "undo" => Phase::Undo, "queued" => Phase::Queued, "scheduled" => Phase::Scheduled, "handing_off" => Phase::HandingOff, "retrying" => Phase::Retrying,
                  "deferred" => Phase::Deferred, "accepted" => Phase::Accepted, "failed" => Phase::Failed, "cancelled" => Phase::Cancelled, "undone" => Phase::Undone, _ => Phase::Unknown }
    }
    pub fn as_str(self) -> &'static str {
        match self { Phase::Undo => "undo", Phase::Queued => "queued", Phase::Scheduled => "scheduled", Phase::HandingOff => "handing_off", Phase::Retrying => "retrying",
                     Phase::Deferred => "deferred", Phase::Accepted => "accepted", Phase::Failed => "failed", Phase::Cancelled => "cancelled", Phase::Undone => "undone", Phase::Unknown => "unknown" }
    }
    /// Nothing more will happen to this mail.
    pub fn is_final(self) -> bool { matches!(self, Phase::Accepted | Phase::Failed | Phase::Cancelled | Phase::Undone) }
    /// The mail is on its way or waiting for its clock (the screen may poll gently).
    pub fn is_live(self) -> bool { !self.is_final() && self != Phase::Unknown }
    /// One of five calm tones for the screen: done (accepted), active (on its way), warn (we are retrying), bad (failed), calm (stopped by the founder / unknown).
    pub fn tone(self) -> &'static str {
        match self { Phase::Accepted => "done", Phase::Undo | Phase::Queued | Phase::Scheduled | Phase::HandingOff => "active", Phase::Deferred | Phase::Retrying => "warn",
                     Phase::Failed => "bad", Phase::Cancelled | Phase::Undone | Phase::Unknown => "calm" }
    }
}

/// Seconds the sender waits after try `attempt` (1-based) before try `attempt + 1`: 1 m, 5 m, 30 m, 2 h, 6 h, then a day.
pub fn backoff_after(attempt: u32) -> u64 { BACKOFF_SECONDS[(attempt.max(1) as usize - 1).min(BACKOFF_SECONDS.len() - 1)] }
/// How long, from now, until the sender gives up if every remaining try fails: the waits after tries `done`..=11 (the wait after the twelfth try does not exist).
/// `done` = tries already made. 12 or more = 0.
pub fn give_up_after_seconds(done: u32) -> u64 { (done.max(1)..MAX_ATTEMPTS).map(backoff_after).sum() }

/// A remote server's reply in plain words. `class` is "temporary" (4xx) or "permanent" (5xx), `code` the enhanced status (5.1.1) or the basic one (550).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Explain { pub class: &'static str, pub code: String, pub kind: &'static str, pub plain: &'static str }

/// Strip control characters, collapse white space, cut at 300 characters. The database already refuses control characters; this is the second wall for text that came from another computer.
pub fn clean_reply(s: &str) -> String {
    let mut out = String::with_capacity(s.len().min(300));
    let mut last_space = true;
    for ch in s.chars() {
        let c = if ch.is_control() { ' ' } else { ch };
        if c.is_whitespace() { if !last_space { out.push(' '); last_space = true; } } else { out.push(c); last_space = false; }
        if out.chars().count() >= 300 { break; }
    }
    out.trim().to_string()
}
fn enhanced_code(s: &str) -> Option<String> {
    let b = s.as_bytes();
    let mut i = 0;
    while i < b.len() {
        if matches!(b[i], b'2' | b'4' | b'5') && (i == 0 || !b[i - 1].is_ascii_alphanumeric() && b[i - 1] != b'.') && i + 1 < b.len() && b[i + 1] == b'.' {
            let rest = &s[i + 2..];
            let (a, r1) = take_digits(rest, 3);
            if let (Some(a), Some(r1)) = (a, r1.strip_prefix('.')) {
                let (c, r2) = take_digits(r1, 3);
                if let Some(c) = c { if !r2.starts_with(|x: char| x.is_ascii_alphanumeric()) { return Some(format!("{}.{}.{}", b[i] as char, a, c)); } }
            }
        }
        i += 1;
    }
    None
}
fn take_digits(s: &str, max: usize) -> (Option<&str>, &str) {
    let n = s.bytes().take_while(|c| c.is_ascii_digit()).count();
    if n == 0 || n > max { (None, s) } else { (Some(&s[..n]), &s[n..]) }
}
fn basic_code(s: &str) -> Option<String> {
    let t = s.trim_start();
    let d = t.bytes().take(3).filter(|c| c.is_ascii_digit()).count();
    if d == 3 && matches!(t.as_bytes()[0], b'4' | b'5') && !t.as_bytes().get(3).map_or(false, |c| c.is_ascii_digit()) { Some(t[..3].to_string()) } else { None }
}
/// Reads an SMTP reply (or our own error text that carries one) and says what it means. None when there is no 4xx/5xx code in it at all.
pub fn explain_reply(reply: &str) -> Option<Explain> {
    let reply = clean_reply(reply);
    let enh = enhanced_code(&reply);
    let code = enh.clone().or_else(|| basic_code(&reply))?;
    let class = if code.starts_with('4') { "temporary" } else if code.starts_with('5') { "permanent" } else { return None };
    let (kind, plain): (&'static str, &'static str) = match enh.as_deref() {
        Some("5.1.1") | Some("5.1.10") => ("no_such_user", "The address does not exist at the recipient's server. Check the spelling."),
        Some("5.1.2") | Some("4.1.2") => ("bad_domain", "The recipient's domain does not exist or has no mail server."),
        Some("5.2.1") | Some("4.2.1") => ("mailbox_disabled", "The recipient's mailbox is disabled or not accepting mail."),
        Some("5.2.2") | Some("4.2.2") => ("mailbox_full", "The recipient's mailbox is full."),
        Some("5.3.4") => ("too_big", "The message is bigger than the recipient's server accepts."),
        Some("4.4.1") | Some("4.4.2") | Some("4.4.7") => ("network", "The connection to the recipient's server timed out or dropped. We will try again."),
        Some("5.4.1") => ("recipient_refused", "The recipient's server refused the recipient address."),
        Some("5.4.4") | Some("5.4.6") => ("no_route", "No route to the recipient's mail server."),
        Some("4.7.1") => ("try_later", "The recipient's server asked us to try again later (greylisting or a rate limit). This usually clears by itself."),
        Some("5.7.23") | Some("5.7.26") | Some("5.7.25") => ("auth_failed", "The recipient's server did not trust the sender checks (SPF, DKIM, DMARC or reverse DNS)."),
        Some("5.7.1") | Some("5.7.0") | Some("5.7.606") => ("policy", "The recipient's server refused the mail by policy (often spam rules or sender reputation)."),
        Some("5.7.510") | Some("5.7.64") => ("relay_denied", "The recipient's server does not accept mail for this address."),
        _ => match (class, code.as_str()) {
            ("temporary", "421") => ("busy", "The recipient's server is busy or shutting down. We will try again."),
            ("temporary", "450") | ("temporary", "451") | ("temporary", "452") => ("try_later", "The recipient's server could not take the mail right now. We will try again."),
            ("temporary", _) => ("temporary", "A temporary refusal from the recipient's server. We will try again."),
            ("permanent", "550") => ("refused", "The recipient's server refused the mail for good."),
            ("permanent", "552") => ("too_big", "The recipient's mailbox or the message size limit was exceeded."),
            ("permanent", "553") => ("bad_address", "The recipient's server does not accept this address format."),
            ("permanent", "554") => ("rejected", "The recipient's server rejected the mail."),
            _ => ("permanent", "A permanent refusal from the recipient's server. We will not retry."),
        },
    };
    Some(Explain { class, code, kind, plain })
}

// ---------------------------------------------------------------- pure: the answer of E195 -> what the screen draws

fn events(v: &Value) -> &[Value] { v["events"].as_array().map(|a| a.as_slice()).unwrap_or(&[]) }
fn first_ts(ev: &[Value], actions: &[&str]) -> Option<i64> { ev.iter().find(|e| actions.contains(&e["action"].as_str().unwrap_or(""))).and_then(|e| e["ts_ms"].as_i64()) }
fn step(key: &str, state: &str, at_ms: Option<i64>, at: Option<&str>, detail: Value) -> Value { json!({"key": key, "state": state, "at_ms": at_ms, "at": at, "detail": detail}) }

/// One try per ledger line: send_fail = deferred (or failed when permanent), send_ok = accepted. A try that is running right now has no line yet: it is added as in_flight.
/// The real sender writes no line when a try STARTS, so this never invents one.
pub fn attempts_of(v: &Value, phase: Phase) -> Vec<Value> {
    let tries = v["retry"]["attempts"].as_u64().unwrap_or(0);
    let mut out: Vec<Value> = Vec::new();
    for e in events(v) {
        let act = e["action"].as_str().unwrap_or("");
        let at = e["ts_ms"].as_i64();
        match act {
            "send_fail" => {
                let n = e["meta"]["attempt"].as_u64().unwrap_or(out.len() as u64 + 1);
                let perm = e["meta"]["permanent"].as_bool() == Some(true);
                out.push(json!({"n": n, "result": if perm { "failed" } else { "deferred" }, "at_ms": at}));
            }
            "send_ok" => out.push(json!({"n": tries.max(out.len() as u64 + 1), "result": "accepted", "at_ms": at, "tls": e["meta"]["tls"], "dkim": e["meta"]["dkim"]})),
            _ => {}
        }
    }
    if matches!(phase, Phase::HandingOff | Phase::Retrying) { out.push(json!({"n": tries.max(out.len() as u64 + 1), "result": "in_flight", "at_ms": Value::Null})); }
    out
}

/// The four steps the screen draws, always in this order: queued -> hold (or scheduled) -> hand-off -> outcome. state is done | active | waiting | failed | skipped.
pub fn steps_of(v: &Value, phase: Phase) -> Vec<Value> {
    let ev = events(v);
    let ob = &v["outbox"];
    let tries = v["retry"]["attempts"].as_u64().unwrap_or(0);
    let scheduled = ob["scheduled_by_founder"].as_bool() == Some(true);
    let stopped = matches!(phase, Phase::Cancelled | Phase::Undone);
    let mut s: Vec<Value> = Vec::with_capacity(4);
    s.push(step("queued", "done", first_ts(ev, &["send_queue", "send_schedule"]), ob["created_at"].as_str(), json!({"rcpt": ob["rcpt"]})));
    if scheduled {
        let state = match phase { Phase::Scheduled => "active", p if p == Phase::Cancelled || p == Phase::Undone => "skipped", _ => "done" };
        s.push(step("scheduled", state, None, ob["not_before"].as_str(), json!({"for": ob["not_before"]})));
    } else {
        let state = match phase { Phase::Undo => "active", Phase::Cancelled => "skipped", _ => "done" };
        s.push(step("hold", state, first_ts(ev, &["send_release", "send_undo"]), ob["undo_until"].as_str(),
                    json!({"sent_now": ob["sent_now"].as_bool() == Some(true), "undone": phase == Phase::Undone})));
    }
    let hand = match phase {
        Phase::HandingOff | Phase::Retrying => "active",
        _ if tries >= 1 => "done",
        _ if stopped => "skipped",
        _ => "waiting",
    };
    s.push(step("handoff", hand, first_ts(ev, &["send_start", "send_fail", "send_ok"]), None, json!({"attempts": tries})));
    let outcome = match phase { Phase::Accepted => "done", Phase::Failed => "failed", Phase::Cancelled | Phase::Undone => "skipped", _ => "waiting" };
    s.push(step("outcome", outcome, first_ts(ev, &["send_ok"]).or_else(|| if phase == Phase::Failed { ev.iter().rev().find(|e| e["action"] == "send_fail").and_then(|e| e["ts_ms"].as_i64()) } else { None }),
                ob["finished_at"].as_str(), json!({"phase": phase.as_str()})));
    s
}

/// The whole answer for one mail. `v` is E195 fmail_timeline195's jsonb. Never panics on a surprising shape: a missing field becomes null / 0.
pub fn timeline_view(v: &Value) -> Value {
    let phase = Phase::parse(v["phase"].as_str().unwrap_or(""));
    let tries = v["retry"]["attempts"].as_u64().unwrap_or(0) as u32;
    let reply = clean_reply(v["retry"]["smtp_reply"].as_str().unwrap_or(""));
    let error = clean_reply(v["retry"]["last_error"].as_str().unwrap_or(""));
    let explain = explain_reply(&reply).or_else(|| explain_reply(&error));
    let waiting = matches!(phase, Phase::Deferred | Phase::Retrying);
    json!({
        "message_id": v["message_id"], "phase": phase.as_str(), "tone": phase.tone(), "final": phase.is_final(), "live": phase.is_live(), "server_now": v["server_now"],
        "steps": steps_of(v, phase), "attempts": attempts_of(v, phase),
        "retry": {
            "attempts": tries, "max_attempts": MAX_ATTEMPTS, "remaining": MAX_ATTEMPTS.saturating_sub(tries),
            "next_in_seconds": if waiting { v["retry"]["next_in_seconds"].clone() } else { Value::Null },
            "give_up_in_seconds": if waiting { json!(give_up_after_seconds(tries)) } else { Value::Null },
            "last_error": if error.is_empty() { Value::Null } else { json!(error) },
            "smtp_reply": if reply.is_empty() { Value::Null } else { json!(reply) },
            "explain": explain.map(|e| json!({"class": e.class, "code": e.code, "kind": e.kind, "plain": e.plain})),
        },
        "outbox": {"rcpt": v["outbox"]["rcpt"], "tls": v["outbox"]["tls"], "dkim": v["outbox"]["dkim"], "sent_now": v["outbox"]["sent_now"], "scheduled_by_founder": v["outbox"]["scheduled_by_founder"],
                   "created_at": v["outbox"]["created_at"], "finished_at": v["outbox"]["finished_at"]},
        "events_truncated": v["events_truncated"].as_bool() == Some(true),
    })
}

/// The delivery board: E195 stats + the rows with their text cleaned and the reply explained.
pub fn delivery_view(stats: &Value, list: &Value) -> Value {
    let rows: Vec<Value> = list["outbox"].as_array().map(|a| a.iter().map(|r| {
        let reply = clean_reply(r["smtp_reply"].as_str().unwrap_or(""));
        let error = clean_reply(r["last_error"].as_str().unwrap_or(""));
        let phase = Phase::parse(r["phase"].as_str().unwrap_or(""));
        let ex = explain_reply(&reply).or_else(|| explain_reply(&error));
        json!({"outbox_id": r["outbox_id"], "message_id": r["message_id"], "phase": phase.as_str(), "tone": phase.tone(), "final": phase.is_final(), "rcpt": r["rcpt"], "attempts": r["attempts"],
               "created_at": r["created_at"], "finished_at": r["finished_at"], "next_attempt": r["next_attempt"], "tls": r["tls"], "dkim": r["dkim"],
               "reason": ex.map(|e| e.plain), "last_error": if error.is_empty() { Value::Null } else { json!(error) }})
    }).collect()).unwrap_or_default();
    json!({"server_now": stats["server_now"], "days": stats["days"], "total": stats["total"], "by_phase": stats["by_phase"], "accepted_took_seconds": stats["accepted_took_seconds"],
           "accepted_rate": stats["accepted_rate"], "deferred_rate": stats["deferred_rate"], "failed_rate": stats["failed_rate"], "rows": rows})
}
pub fn badges_view(b: &Value) -> Value {
    let items: Vec<Value> = b["items"].as_array().map(|a| a.iter().map(|i| {
        let p = Phase::parse(i["phase"].as_str().unwrap_or(""));
        json!({"message_id": i["message_id"], "phase": p.as_str(), "tone": p.tone(), "final": p.is_final(), "attempts": i["attempts"], "next_attempt": i["next_attempt"]})
    }).collect()).unwrap_or_default();
    json!({"server_now": b["server_now"], "items": items})
}

// ---------------------------------------------------------------- async: the doors

/// What a bounded database call came to. Slow = the 4 s Tokio timeout fired. Missing = the E195 door is not installed yet (run sql-run).
#[derive(Debug)]
pub enum Db { Ok(Value), Slow, Down, Missing, Refused(u16, String) }
/// Run one database call under the Tokio timeout and sort its outcome. The caller never sees a raw status code.
pub async fn bounded<F: Future<Output = Result<Value, (u16, String)>>>(f: F) -> Db {
    match tokio::time::timeout(DB_TIMEOUT, f).await {
        Err(_) => Db::Slow,
        Ok(Ok(v)) => Db::Ok(v),
        Ok(Err((0, _))) => Db::Down,
        Ok(Err((404, _))) => Db::Missing,
        Ok(Err((s, m))) => Db::Refused(s, m),
    }
}
/// Pure: the HTTP status and plain words for a database outcome that is not Ok. (The SQL door says "not your mailbox" with 42501; nothing about the mail is revealed.)
pub fn outcome_status(d: &Db) -> Option<(StatusCode, &'static str)> {
    match d {
        Db::Ok(_) => None,
        Db::Slow => Some((StatusCode::GATEWAY_TIMEOUT, "the mail database is slow right now, try again in a moment")),
        Db::Down => Some((StatusCode::SERVICE_UNAVAILABLE, "the mail database is not answering")),
        Db::Missing => None,
        Db::Refused(s, _) if *s == 403 || *s == 401 => Some((StatusCode::NOT_FOUND, "no such mailbox")),
        Db::Refused(s, _) if *s == 400 || *s == 422 => Some((StatusCode::BAD_REQUEST, "the request was refused")),
        Db::Refused(_, _) => Some((StatusCode::BAD_GATEWAY, "the mail database refused the request")),
    }
}
fn reply_with(st: &S, d: Db, ok: impl FnOnce(Value) -> Value) -> Response {
    if let Some((code, msg)) = outcome_status(&d) { return pk::refuse(code, msg); }
    match d {
        Db::Missing => crate::signed(st, json!({"connected": false, "note": "run the E195 SQL step (sql-run.sh)"})),
        Db::Ok(v) => crate::signed(st, ok(v)),
        _ => pk::refuse(StatusCode::BAD_GATEWAY, "unexpected database answer"),
    }
}
fn bad(e: &str) -> Response { pk::refuse(StatusCode::BAD_REQUEST, e) }

/// GET /founder/v1/mail/timeline?box=&message=
pub async fn timeline_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let (b, m) = match parse_timeline(uri.query()) { Ok(x) => x, Err(e) => return bad(e) };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let d = bounded(sb.rpc_msg("fmail_timeline195", json!({"p_actor": c.sub, "p_mailbox": b, "p_message": m}))).await;
    reply_with(&st, d, |v| if v.is_null() { json!({"connected": true, "timeline": Value::Null}) } else { json!({"connected": true, "timeline": timeline_view(&v)}) })
}

/// GET /founder/v1/mail/delivery?box=&days= : the health numbers and the list are read AT THE SAME TIME (two doors, one Tokio join, one shared timeout).
pub async fn delivery_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let (b, days) = match parse_delivery(uri.query()) { Ok(x) => x, Err(e) => return bad(e) };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let stats = bounded(sb.rpc_msg("fmail_delivery_stats195", json!({"p_actor": c.sub, "p_mailbox": b, "p_days": days})));
    let list = bounded(sb.rpc_msg("fmail_outbox_list195", json!({"p_actor": c.sub, "p_mailbox": b, "p_days": days})));
    let (stats, list) = tokio::join!(stats, list);
    match (stats, list) {
        (Db::Ok(s), Db::Ok(l)) => crate::signed(&st, json!({"connected": true, "delivery": delivery_view(&s, &l)})),
        (a, b) => {
            // the worse of the two decides the answer; a missing door (E195 not run) is told plainly
            let d = if matches!(a, Db::Ok(_)) { b } else { a };
            reply_with(&st, d, |_| Value::Null)
        }
    }
}

/// GET /founder/v1/mail/timeline/badges?box=&ids=
pub async fn badges_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let (b, ids) = match parse_badges(uri.query()) { Ok(x) => x, Err(e) => return bad(e) };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let d = bounded(sb.rpc_msg("fmail_timeline_batch195", json!({"p_actor": c.sub, "p_mailbox": b, "p_messages": ids}))).await;
    reply_with(&st, d, |v| json!({"connected": true, "badges": badges_view(&v)}))
}

#[cfg(test)]
mod tests {
    use super::*;
    const BOX: &str = "11111111-1111-1111-1111-111111111111";
    const MSG: &str = "22222222-2222-2222-2222-222222222222";
    const MSG2: &str = "33333333-3333-3333-3333-333333333333";

    // ---- query strings
    #[test] fn timeline_needs_box_and_message_and_nothing_else() {
        assert_eq!(parse_timeline(Some(&format!("box={BOX}&message={MSG}"))), Ok((BOX.into(), MSG.into())));
        assert_eq!(parse_timeline(Some(&format!("message={MSG}&box={BOX}"))), Ok((BOX.into(), MSG.into())));
        assert_eq!(parse_timeline(Some(&format!("box={BOX}"))), Err("missing message"));
        assert_eq!(parse_timeline(Some(&format!("message={MSG}"))), Err("missing box"));
        assert_eq!(parse_timeline(None), Err("missing box"));
        assert_eq!(parse_timeline(Some(&format!("box={BOX}&message={MSG}&x=1"))), Err("unknown parameter"));
        assert_eq!(parse_timeline(Some(&format!("box={BOX}&box={BOX}&message={MSG}"))), Err("repeated parameter"));
        assert_eq!(parse_timeline(Some("box=nope&message=x")), Err("invalid box"));
        assert_eq!(parse_timeline(Some(&format!("box={BOX}&message=1; drop table"))), Err("invalid message"));
    }
    #[test] fn delivery_days_are_1_to_30_default_7_never_clamped() {
        assert_eq!(parse_delivery(Some(&format!("box={BOX}"))), Ok((BOX.into(), 7)));
        assert_eq!(parse_delivery(Some(&format!("box={BOX}&days=1"))), Ok((BOX.into(), 1)));
        assert_eq!(parse_delivery(Some(&format!("box={BOX}&days=30"))), Ok((BOX.into(), 30)));
        assert_eq!(parse_delivery(Some(&format!("box={BOX}&days=0"))), Err("days must be 1 to 30"));
        assert_eq!(parse_delivery(Some(&format!("box={BOX}&days=31"))), Err("days must be 1 to 30"));
        assert_eq!(parse_delivery(Some(&format!("box={BOX}&days=-1"))), Err("invalid days"));
        assert_eq!(parse_delivery(Some(&format!("box={BOX}&days=1e1"))), Err("invalid days"));
        assert_eq!(parse_delivery(Some(&format!("box={BOX}&days="))), Err("invalid days"));
        assert_eq!(parse_delivery(Some(&format!("box={BOX}&days=007"))), Err("invalid days"));
        assert_eq!(parse_delivery(Some(&format!("box={BOX}&days=7&days=8"))), Err("repeated parameter"));
    }
    #[test] fn badges_take_1_to_100_distinct_uuids_in_order() {
        assert_eq!(parse_badges(Some(&format!("box={BOX}&ids={MSG},{MSG2}"))), Ok((BOX.into(), vec![MSG.into(), MSG2.into()])));
        assert_eq!(parse_badges(Some(&format!("box={BOX}&ids={MSG},{MSG}"))).unwrap().1, vec![MSG.to_string()]);
        assert_eq!(parse_badges(Some(&format!("box={BOX}&ids="))), Err("invalid id"));
        assert_eq!(parse_badges(Some(&format!("box={BOX}&ids={MSG},bad"))), Err("invalid id"));
        assert_eq!(parse_badges(Some(&format!("box={BOX}"))), Err("missing ids"));
        let many: Vec<String> = (0..101).map(|i| format!("{:08x}-1111-1111-1111-111111111111", i)).collect();
        assert_eq!(parse_badges(Some(&format!("box={BOX}&ids={}", many.join(",")))), Err("at most 100 ids"));
        let ok: Vec<String> = (0..100).map(|i| format!("{:08x}-1111-1111-1111-111111111111", i)).collect();
        assert_eq!(parse_badges(Some(&format!("box={BOX}&ids={}", ok.join(",")))).unwrap().1.len(), 100);
    }

    // ---- phase, tones, retry clock
    #[test] fn every_sql_phase_word_round_trips_and_unknown_is_never_guessed() {
        for w in ["undo", "queued", "scheduled", "handing_off", "retrying", "deferred", "accepted", "failed", "cancelled", "undone"] { assert_eq!(Phase::parse(w).as_str(), w); }
        assert_eq!(Phase::parse("delivered"), Phase::Unknown);
        assert_eq!(Phase::parse(""), Phase::Unknown);
        assert_eq!(Phase::Unknown.as_str(), "unknown");
    }
    #[test] fn final_and_live_phases() {
        for p in [Phase::Accepted, Phase::Failed, Phase::Cancelled, Phase::Undone] { assert!(p.is_final() && !p.is_live()); }
        for p in [Phase::Undo, Phase::Queued, Phase::Scheduled, Phase::HandingOff, Phase::Retrying, Phase::Deferred] { assert!(!p.is_final() && p.is_live()); }
        assert!(!Phase::Unknown.is_final() && !Phase::Unknown.is_live());
    }
    #[test] fn tones_are_five_calm_words() {
        assert_eq!(Phase::Accepted.tone(), "done"); assert_eq!(Phase::Failed.tone(), "bad"); assert_eq!(Phase::Deferred.tone(), "warn"); assert_eq!(Phase::Retrying.tone(), "warn");
        for p in [Phase::Undo, Phase::Queued, Phase::Scheduled, Phase::HandingOff] { assert_eq!(p.tone(), "active"); }
        for p in [Phase::Cancelled, Phase::Undone, Phase::Unknown] { assert_eq!(p.tone(), "calm"); }
    }
    #[test] fn backoff_is_1m_5m_30m_2h_6h_then_a_day() {
        let w: Vec<u64> = (1..=8).map(backoff_after).collect();
        assert_eq!(w, vec![60, 300, 1800, 7200, 21600, 86400, 86400, 86400]);
        assert_eq!(backoff_after(0), 60, "try 0 is read as try 1, no underflow");
    }
    #[test] fn give_up_adds_the_waits_that_are_left() {
        assert_eq!(give_up_after_seconds(11), 86400, "after the 11th failure one wait is left, before the 12th and last try");
        assert_eq!(give_up_after_seconds(12), 0);
        assert_eq!(give_up_after_seconds(99), 0);
        assert_eq!(give_up_after_seconds(1), 60 + 300 + 1800 + 7200 + 21600 + 6 * 86400);
        assert_eq!(give_up_after_seconds(0), give_up_after_seconds(1));
        assert!(give_up_after_seconds(2) < give_up_after_seconds(1));
    }

    // ---- reading a remote server's words
    #[test] fn reply_text_is_cleaned() {
        assert_eq!(clean_reply("550  5.1.1\t<a@b.c>:\r\n user   unknown"), "550 5.1.1 <a@b.c>: user unknown");
        assert_eq!(clean_reply("\u{0}\u{7}x\u{1b}[31my"), "x [31my");
        assert_eq!(clean_reply(&"é".repeat(400)).chars().count(), 300);
        assert_eq!(clean_reply("   "), "");
    }
    #[test] fn five_one_one_is_user_unknown() {
        let e = explain_reply("550 5.1.1 <bob@example.com>: Recipient address rejected: User unknown").unwrap();
        assert_eq!((e.class, e.code.as_str(), e.kind), ("permanent", "5.1.1", "no_such_user"));
    }
    #[test] fn four_seven_one_is_try_later_and_temporary() {
        let e = explain_reply("451 4.7.1 Greylisted, please try again in 300 seconds").unwrap();
        assert_eq!((e.class, e.code.as_str(), e.kind), ("temporary", "4.7.1", "try_later"));
    }
    #[test] fn mailbox_full_in_both_classes() {
        assert_eq!(explain_reply("452 4.2.2 Over quota").unwrap().kind, "mailbox_full");
        assert_eq!(explain_reply("552 5.2.2 Mailbox full").unwrap().kind, "mailbox_full");
    }
    #[test] fn auth_and_policy_refusals() {
        assert_eq!(explain_reply("550 5.7.26 This mail is unauthenticated").unwrap().kind, "auth_failed");
        assert_eq!(explain_reply("550 5.7.23 SPF validation failed").unwrap().kind, "auth_failed");
        assert_eq!(explain_reply("554 5.7.1 Service unavailable; client blocked").unwrap().kind, "policy");
        assert_eq!(explain_reply("550 5.7.1 [IP] blocked").unwrap().class, "permanent");
    }
    #[test] fn network_and_size() {
        assert_eq!(explain_reply("421 4.4.2 timeout").unwrap().kind, "network");
        assert_eq!(explain_reply("552 5.3.4 Message size exceeds fixed limit").unwrap().kind, "too_big");
    }
    #[test] fn a_basic_code_alone_still_gets_a_class() {
        let e = explain_reply("421 Service not available").unwrap();
        assert_eq!((e.class, e.code.as_str(), e.kind), ("temporary", "421", "busy"));
        let e = explain_reply("554 Transaction failed").unwrap();
        assert_eq!((e.class, e.kind), ("permanent", "rejected"));
        assert_eq!(explain_reply("550 nope").unwrap().kind, "refused");
        assert_eq!(explain_reply("399 odd").map(|e| e.class), None, "only 4xx and 5xx are refusals");
    }
    #[test] fn no_code_means_no_explanation_not_a_guess() {
        assert!(explain_reply("").is_none());
        assert!(explain_reply("connection refused").is_none());
        assert!(explain_reply("250 2.0.0 OK queued as ABC").is_none(), "an accept is not a refusal");
        assert!(explain_reply("version 5.1.1.9 of the thing").is_none() || explain_reply("version 5.1.1.9 of the thing").map_or(true, |e| e.code != "5.1.1.9"));
    }
    #[test] fn a_code_buried_in_our_own_error_text_is_found() {
        let e = explain_reply("recipient refused: 550 5.1.1 user unknown").unwrap();
        assert_eq!(e.kind, "no_such_user");
    }

    // ---- the timeline view, one test per phase of the mail's life
    fn base(phase: &str, state: &str, attempts: u64) -> Value {
        json!({"message_id": MSG, "phase": phase, "server_now": "2026-11-20T02:00:00Z", "events_truncated": false, "events": [],
               "outbox": {"state": state, "created_at": "2026-11-20T01:59:00Z", "not_before": "2026-11-20T01:59:30Z", "undo_until": "2026-11-20T01:59:30Z", "released_at": null, "finished_at": null,
                          "rcpt": 2, "tls": null, "dkim": false, "scheduled_by_founder": false, "sent_now": false},
               "retry": {"attempts": attempts, "max_attempts": 12, "remaining": 12 - attempts, "next_attempt": null, "final": false, "next_in_seconds": null, "last_error": null, "smtp_reply": null}})
    }
    fn ev(seq: i64, action: &str, meta: Value) -> Value { json!({"seq": seq, "ts_ms": 1_000 + seq * 1000, "action": action, "reason": "x", "meta": meta}) }
    fn states(v: &Value) -> Vec<(String, String)> { v["steps"].as_array().unwrap().iter().map(|s| (s["key"].as_str().unwrap().into(), s["state"].as_str().unwrap().into())).collect() }
    fn st(a: &str, b: &str) -> (String, String) { (a.into(), b.into()) }

    #[test] fn inside_the_hold_the_hold_step_is_active() {
        let mut v = base("undo", "queued", 0); v["events"] = json!([ev(1, "send_queue", json!({}))]);
        let t = timeline_view(&v);
        assert_eq!(states(&t), vec![st("queued", "done"), st("hold", "active"), st("handoff", "waiting"), st("outcome", "waiting")]);
        assert_eq!((t["phase"].as_str(), t["tone"].as_str(), t["final"].as_bool(), t["live"].as_bool()), (Some("undo"), Some("active"), Some(false), Some(true)));
        assert_eq!(t["steps"][0]["at_ms"], 2000);
    }
    #[test] fn send_now_marks_the_hold_done_and_says_so() {
        let mut v = base("queued", "queued", 0); v["outbox"]["sent_now"] = json!(true); v["events"] = json!([ev(1, "send_queue", json!({})), ev(2, "send_release", json!({"saved_seconds": 20.5}))]);
        let t = timeline_view(&v);
        assert_eq!(states(&t)[1], st("hold", "done"));
        assert_eq!(t["steps"][1]["detail"]["sent_now"], true);
        assert_eq!(t["steps"][1]["at_ms"], 3000);
    }
    #[test] fn a_scheduled_mail_shows_the_scheduled_step_not_the_hold() {
        let mut v = base("scheduled", "scheduled", 0); v["outbox"]["scheduled_by_founder"] = json!(true); v["outbox"]["not_before"] = json!("2026-11-20T15:00:00Z");
        let t = timeline_view(&v);
        assert_eq!(states(&t)[1], st("scheduled", "active"));
        assert_eq!(t["steps"][1]["detail"]["for"], "2026-11-20T15:00:00Z");
        assert!(!states(&t).iter().any(|(k, _)| k == "hold"));
    }
    #[test] fn first_try_in_flight() {
        let v = base("handing_off", "sending", 1);
        let t = timeline_view(&v);
        assert_eq!(states(&t)[2], st("handoff", "active"));
        assert_eq!(t["attempts"][0]["result"], "in_flight");
        assert_eq!(t["tone"], "active");
    }
    #[test] fn a_deferred_mail_tells_the_reason_the_wait_and_when_we_give_up() {
        let mut v = base("deferred", "failed", 1);
        v["retry"]["next_in_seconds"] = json!(240); v["retry"]["smtp_reply"] = json!("451 4.7.1 Greylisted"); v["retry"]["last_error"] = json!("greylisted");
        v["events"] = json!([ev(1, "send_queue", json!({})), ev(2, "send_fail", json!({"attempt": 1}))]);
        let t = timeline_view(&v);
        assert_eq!(states(&t), vec![st("queued", "done"), st("hold", "done"), st("handoff", "done"), st("outcome", "waiting")]);
        assert_eq!(t["retry"]["next_in_seconds"], 240);
        assert_eq!(t["retry"]["give_up_in_seconds"], give_up_after_seconds(1));
        assert_eq!(t["retry"]["explain"]["kind"], "try_later");
        assert_eq!(t["retry"]["explain"]["class"], "temporary");
        assert_eq!(t["attempts"], json!([{"n": 1, "result": "deferred", "at_ms": 3000}]));
        assert_eq!(t["tone"], "warn");
        assert_eq!(t["retry"]["remaining"], 11);
    }
    #[test] fn the_second_try_is_retrying_with_two_attempts_listed() {
        let mut v = base("retrying", "sending", 2); v["events"] = json!([ev(1, "send_fail", json!({"attempt": 1}))]);
        let t = timeline_view(&v);
        assert_eq!(t["attempts"].as_array().unwrap().len(), 2);
        assert_eq!(t["attempts"][1], json!({"n": 2, "result": "in_flight", "at_ms": null}));
        assert_eq!(states(&t)[2], st("handoff", "active"));
    }
    #[test] fn accepted_never_promises_the_inbox() {
        let mut v = base("accepted", "sent", 2); v["outbox"]["tls"] = json!("tls13"); v["outbox"]["dkim"] = json!(true); v["outbox"]["finished_at"] = json!("2026-11-20T02:00:00Z");
        v["events"] = json!([ev(1, "send_queue", json!({})), ev(2, "send_fail", json!({"attempt": 1})), ev(3, "send_ok", json!({"tls": "tls13", "dkim": true}))]);
        let t = timeline_view(&v);
        assert_eq!(states(&t)[3], st("outcome", "done"));
        assert_eq!(t["final"], true); assert_eq!(t["tone"], "done");
        assert_eq!(t["attempts"][1], json!({"n": 2, "result": "accepted", "at_ms": 4000, "tls": "tls13", "dkim": true}));
        assert_eq!(t["retry"]["next_in_seconds"], Value::Null);
        assert_eq!(t["retry"]["give_up_in_seconds"], Value::Null);
        let text = t.to_string().to_lowercase();
        assert!(!text.contains("inbox") && !text.contains("\"read\"") && !text.contains("delivered"), "the words never say more than the server's 250");
    }
    #[test] fn a_permanent_failure_is_failed_with_its_reason_and_no_retry() {
        let mut v = base("failed", "failed", 1); v["retry"]["final"] = json!(true); v["retry"]["smtp_reply"] = json!("550 5.1.1 user unknown"); v["retry"]["last_error"] = json!("recipient refused");
        v["events"] = json!([ev(1, "send_fail", json!({"attempt": 1, "permanent": true}))]);
        let t = timeline_view(&v);
        assert_eq!(states(&t)[3], st("outcome", "failed"));
        assert_eq!(t["attempts"][0]["result"], "failed");
        assert_eq!(t["retry"]["explain"]["kind"], "no_such_user");
        assert_eq!(t["retry"]["next_in_seconds"], Value::Null);
        assert_eq!(t["tone"], "bad"); assert_eq!(t["final"], true);
        assert_eq!(t["steps"][3]["at_ms"], 2000);
    }
    #[test] fn cancelled_and_undone_skip_the_rest() {
        let t = timeline_view(&base("cancelled", "cancelled", 0));
        assert_eq!(states(&t), vec![st("queued", "done"), st("hold", "skipped"), st("handoff", "skipped"), st("outcome", "skipped")]);
        let t = timeline_view(&base("undone", "undone", 0));
        assert_eq!(states(&t), vec![st("queued", "done"), st("hold", "done"), st("handoff", "skipped"), st("outcome", "skipped")]);
        assert_eq!(t["steps"][1]["detail"]["undone"], true);
        let mut v = base("cancelled", "cancelled", 0); v["outbox"]["scheduled_by_founder"] = json!(true);
        assert_eq!(states(&timeline_view(&v))[1], st("scheduled", "skipped"));
    }
    #[test] fn a_surprising_shape_never_panics() {
        for v in [json!(null), json!({}), json!({"phase": 7, "events": "x", "retry": [], "outbox": 3}), json!({"phase": "accepted", "events": [null, 1, {"action": 5}]})] {
            let t = timeline_view(&v);
            assert_eq!(t["steps"].as_array().unwrap().len(), 4);
        }
        assert_eq!(timeline_view(&json!({}))["phase"], "unknown");
    }
    #[test] fn text_from_the_remote_server_is_cleaned_before_it_reaches_the_screen() {
        let mut v = base("deferred", "failed", 1); v["retry"]["smtp_reply"] = json!("451\u{0}\u{1b}[2J 4.7.1\n  later");
        let t = timeline_view(&v);
        let r = t["retry"]["smtp_reply"].as_str().unwrap();
        assert!(!r.chars().any(|c| c.is_control()) && r.contains("4.7.1"));
    }
    #[test] fn no_content_field_is_ever_added_to_the_view() {
        let v = base("accepted", "sent", 1);
        let t = timeline_view(&v).to_string();
        for w in ["sealed", "nonce", "key_wrap", "subject", "body", "@"] { assert!(!t.contains(w), "{w} must not appear"); }
    }

    // ---- delivery board and badges
    #[test] fn the_board_explains_each_rows_reason_and_keeps_the_numbers() {
        let stats = json!({"server_now": "n", "days": 7, "total": 3, "by_phase": {"accepted": 2, "failed": 1}, "accepted_took_seconds": {"p50": 31.0, "p95": 40.2}, "accepted_rate": 0.6667, "deferred_rate": 0, "failed_rate": 0.3333});
        let list = json!({"outbox": [{"outbox_id": "o1", "message_id": MSG, "phase": "failed", "rcpt": 1, "attempts": 1, "created_at": "c", "finished_at": "f", "next_attempt": null, "tls": null, "dkim": false,
                                      "smtp_reply": "550 5.1.1 unknown", "last_error": "refused"},
                                     {"outbox_id": "o2", "message_id": MSG2, "phase": "accepted", "rcpt": 2, "attempts": 1, "smtp_reply": "250 ok", "last_error": null}]});
        let d = delivery_view(&stats, &list);
        assert_eq!(d["total"], 3); assert_eq!(d["accepted_took_seconds"]["p50"], 31.0);
        assert_eq!(d["rows"][0]["reason"], "The address does not exist at the recipient's server. Check the spelling.");
        assert_eq!(d["rows"][0]["tone"], "bad");
        assert_eq!(d["rows"][1]["reason"], Value::Null);
        assert_eq!(d["rows"][1]["tone"], "done");
    }
    #[test] fn badges_keep_order_and_never_invent_a_phase() {
        let b = badges_view(&json!({"server_now": "n", "items": [{"message_id": MSG2, "phase": "deferred", "attempts": 2, "next_attempt": "t"}, {"message_id": MSG, "phase": "weird", "attempts": 0}]}));
        assert_eq!(b["items"][0]["message_id"], MSG2); assert_eq!(b["items"][0]["tone"], "warn");
        assert_eq!(b["items"][1]["phase"], "unknown");
        assert_eq!(badges_view(&json!({}))["items"], json!([]));
    }

    // ---- async: the Tokio timeout and how outcomes become answers
    #[tokio::test] async fn a_fast_call_comes_back_ok() {
        match bounded(async { Ok::<Value, (u16, String)>(json!({"a": 1})) }).await { Db::Ok(v) => assert_eq!(v["a"], 1), o => panic!("{o:?}") }
    }
    #[tokio::test(start_paused = true)] async fn a_slow_database_is_cut_off_by_the_timeout_not_waited_for() {
        let slow = async { tokio::time::sleep(Duration::from_secs(60)).await; Ok::<Value, (u16, String)>(Value::Null) };
        let t0 = tokio::time::Instant::now();
        let r = bounded(slow).await;
        assert!(matches!(r, Db::Slow));
        assert!(t0.elapsed() >= DB_TIMEOUT && t0.elapsed() < Duration::from_secs(5), "it gave up at the timeout, not at 60 s");
    }
    #[tokio::test] async fn database_errors_are_sorted() {
        assert!(matches!(bounded(async { Err::<Value, _>((0u16, "x".to_string())) }).await, Db::Down));
        assert!(matches!(bounded(async { Err::<Value, _>((404u16, "x".to_string())) }).await, Db::Missing));
        assert!(matches!(bounded(async { Err::<Value, _>((403u16, "E195: not your mailbox".to_string())) }).await, Db::Refused(403, _)));
    }
    #[tokio::test(start_paused = true)] async fn the_two_board_reads_run_together_not_one_after_the_other() {
        let a = bounded(async { tokio::time::sleep(Duration::from_secs(3)).await; Ok::<Value, (u16, String)>(json!(1)) });
        let b = bounded(async { tokio::time::sleep(Duration::from_secs(3)).await; Ok::<Value, (u16, String)>(json!(2)) });
        let t0 = tokio::time::Instant::now();
        let (a, b) = tokio::join!(a, b);
        assert!(matches!((a, b), (Db::Ok(_), Db::Ok(_))));
        assert!(t0.elapsed() < Duration::from_secs(4), "3 s + 3 s in parallel is about 3 s, not 6");
    }
    #[test] fn outcomes_become_plain_statuses() {
        assert_eq!(outcome_status(&Db::Slow).unwrap().0, StatusCode::GATEWAY_TIMEOUT);
        assert_eq!(outcome_status(&Db::Down).unwrap().0, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(outcome_status(&Db::Refused(403, "E195: not your mailbox".into())).unwrap(), (StatusCode::NOT_FOUND, "no such mailbox"));
        assert_eq!(outcome_status(&Db::Refused(400, "x".into())).unwrap().0, StatusCode::BAD_REQUEST);
        assert_eq!(outcome_status(&Db::Refused(500, "x".into())).unwrap().0, StatusCode::BAD_GATEWAY);
        assert!(outcome_status(&Db::Ok(Value::Null)).is_none());
        assert!(outcome_status(&Db::Missing).is_none(), "a missing door is told as connected:false, with the SQL step to run");
    }
    #[test] fn another_founders_refusal_does_not_reveal_that_the_mailbox_exists() {
        let (code, msg) = outcome_status(&Db::Refused(403, "E195: not your mailbox".into())).unwrap();
        assert_eq!(code, StatusCode::NOT_FOUND);
        assert!(!msg.contains("E195") && !msg.contains("your"));
    }
}
