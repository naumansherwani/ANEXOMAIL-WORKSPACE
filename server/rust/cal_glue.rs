// ============================================================================
// ANEXOMAIL — Calendar v2 procs (Rust PRIMARY): real invitations, RSVP, find-a-time.
//
// `mod cal_core; mod cal_glue;` main.rs mein judta hai (installer: docs/cursor-work/server/rust-calendar-install.sh).
// Is file mein sirf I/O ki tarteeb hai (Supabase REST + local Postfix :25). Saari soch cal_core.rs mein hai
// (std-only, 21 unit tests). Parent module (main.rs) ke helpers: sb_select / sb_insert / sb_patch / sb_rpc / sb_count,
// mail_identity, ok / err, s — yahan `crate::` se use hote hain.
//
// Procs (authenticated):  calendar.create  calendar.history  calendar.update  calendar.invites.resend  calendar.busy  calendar.findtime
// Procs (public, token):  calendar.rsvp.lookup  calendar.rsvp.respond
//
// Graceful: E31 SQL (docs/cursor-work/sql/E31_calendar_v2.sql) na lagi ho to `calendar.create` 501 deta hai aur
// frontend purane Bun route par girta hai (event ban jata hai, invitations nahi jati) — kuch toot'ta nahi.
// ============================================================================

use crate::cal_core::{self as cal, recur, EventSpec, Guest, Interval, InviteLinks, Method, Person};
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::Duration;

const MAX_GUESTS: usize = 50;
const DAILY_INVITE_CAP: i64 = 200;

static V2_READY: AtomicBool = AtomicBool::new(false);
static REC_READY: AtomicBool = AtomicBool::new(false);
static REC_CHECKED: std::sync::atomic::AtomicI64 = std::sync::atomic::AtomicI64::new(0);
static MSG_SEQ: AtomicU64 = AtomicU64::new(0);

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "calendar.create"
            | "calendar.update"
            | "calendar.invites.resend"
            | "calendar.busy"
            | "calendar.findtime"
            | "calendar.guests"
            | "calendar.events"
            | "calendar.event"
            | "calendar.load"
            | "calendar.meta.set"
            | "calendar.history"
    )
}

fn app_url() -> String {
    let v = crate::env_var("ANEXOMAIL_APP_URL");
    if v.starts_with("https://") {
        v.trim_end_matches('/').to_string()
    } else {
        "https://anexomail.com".to_string()
    }
}

fn now_epoch() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn num(v: &Value, k: &str) -> Option<i64> {
    v.get(k).and_then(|x| x.as_i64())
}

fn opt(v: &Value, k: &str) -> Option<String> {
    let t = st(v, k);
    if t.trim().is_empty() {
        None
    } else {
        Some(t)
    }
}

/// Percent-encodes a value for a PostgREST filter (e.g. `ali+tag@x.com` must not turn '+' into a space).
fn pe(v: &str) -> String {
    let mut o = String::with_capacity(v.len() + 8);
    for b in v.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'.' | b'_' | b'~' | b'@') {
            o.push(b as char);
        } else {
            o.push_str(&format!("%{:02X}", b));
        }
    }
    o
}

fn fail(status: StatusCode, code: &str, msg: &str) -> axum::response::Response {
    crate::err(status, code, msg).into_response()
}

/// E83: DB room guard refused the new time (a booked room is busy then).
fn room_busy() -> axum::response::Response {
    fail(StatusCode::CONFLICT, "room_busy", "A booked room is already taken at that time. Release the room or pick another time.")
}

async fn v2_ready() -> bool {
    if V2_READY.load(Ordering::Relaxed) {
        return true;
    }
    let ready = crate::sb_select("calendar_attendees?select=rsvp_token&limit=1")
        .await
        .is_ok()
        && crate::sb_select("calendar_invite_log?select=id&limit=1")
            .await
            .is_ok();
    if ready {
        V2_READY.store(true, Ordering::Relaxed);
    }
    ready
}

/// Recurrence SQL (E56) installed? Positive answer is cached for good; a "no" is re-checked at most once a minute,
/// so a calendar without E56 behaves exactly as before (one-off meetings only).
async fn recur_ready() -> bool {
    if REC_READY.load(Ordering::Relaxed) {
        return true;
    }
    let now = now_epoch();
    if now - REC_CHECKED.load(Ordering::Relaxed) < 60 {
        return false;
    }
    REC_CHECKED.store(now, Ordering::Relaxed);
    let ok = crate::sb_select("calendar_events?select=rrule,exdates,series_id,recurrence_id,tz_offset_min&limit=1")
        .await
        .is_ok();
    if ok {
        REC_READY.store(true, Ordering::Relaxed);
    }
    ok
}

static E58_READY: AtomicBool = AtomicBool::new(false);
static E58_CHECKED: std::sync::atomic::AtomicI64 = std::sync::atomic::AtomicI64::new(0);

/// Calendar key / reminders SQL (E58) installed? Same cache rule as `recur_ready`: a "yes" is final, a "no" is re-checked
/// once a minute, so a calendar without E58 keeps working exactly as before (those two fields are just not stored).
async fn e58_ready() -> bool {
    if E58_READY.load(Ordering::Relaxed) {
        return true;
    }
    let now = now_epoch();
    if now - E58_CHECKED.load(Ordering::Relaxed) < 60 {
        return false;
    }
    E58_CHECKED.store(now, Ordering::Relaxed);
    let ok = crate::sb_select("calendar_events?select=calendar_key,remind_min&limit=1").await.is_ok();
    if ok {
        E58_READY.store(true, Ordering::Relaxed);
    }
    ok
}

static E63_READY: AtomicBool = AtomicBool::new(false);
static E63_CHECKED: std::sync::atomic::AtomicI64 = std::sync::atomic::AtomicI64::new(0);

/// E63 (outcome colours) columns exist? Same pattern as e58_ready: cached once true, re-asked at most once a minute while false.
async fn e63_ready() -> bool {
    if E63_READY.load(Ordering::Relaxed) {
        return true;
    }
    let now = now_epoch();
    if now - E63_CHECKED.load(Ordering::Relaxed) < 60 {
        return false;
    }
    E63_CHECKED.store(now, Ordering::Relaxed);
    let ok = crate::sb_select("calendar_events?select=goal,goal_state,goal_state_at&limit=1").await.is_ok();
    if ok {
        E63_READY.store(true, Ordering::Relaxed);
    }
    ok
}

/// `calendar_key` from a request: short lowercase key or nothing.
fn calendar_key_of(input: &Value) -> Option<String> {
    opt(input, "calendar_key").filter(|k| {
        !k.is_empty() && k.len() <= 40 && k.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_' || b == b'-')
    })
}

/// `remind_min` from a request: up to 5 whole minutes-before values, 0..=40320 (four weeks), no duplicates, sorted.
fn remind_of(input: &Value) -> Option<Vec<i64>> {
    let a = input.get("remind_min")?.as_array()?;
    let mut v: Vec<i64> = a.iter().filter_map(|x| x.as_i64()).filter(|n| (0..=40320).contains(n)).collect();
    v.sort_unstable();
    v.dedup();
    v.truncate(5);
    Some(v)
}

fn zone_of(ev: &Value) -> std::sync::Arc<recur::Tz> {
    let off = (num(ev, "tz_offset_min").unwrap_or(0).clamp(-840, 840) * 60) as i32;
    recur::load_tz(&st(ev, "tz"), off)
}

fn exdates_of(ev: &Value) -> Vec<i64> {
    ev.get("exdates")
        .and_then(|v| v.as_array())
        .map(|a| a.iter().filter_map(|x| x.as_str().and_then(cal::parse_ts)).collect())
        .unwrap_or_default()
}

fn is_master(ev: &Value) -> bool {
    !st(ev, "rrule").is_empty()
}

/// Every occurrence of a series master that overlaps [from, to), as event rows with composite ids.
fn occurrences(ev: &Value, from: i64, to: i64) -> Vec<Value> {
    let rule = match recur::parse(&st(ev, "rrule")) {
        Ok(r) => r,
        Err(_) => return vec![],
    };
    let (s, e) = match (cal::parse_ts(&st(ev, "starts_at")), cal::parse_ts(&st(ev, "ends_at"))) {
        (Some(s), Some(e)) => (s, e),
        _ => return vec![],
    };
    let dur = (e - s).max(60);
    let tz = zone_of(ev);
    recur::expand(&rule, s, dur, &tz, &exdates_of(ev), from, to)
        .into_iter()
        .map(|u| {
            let mut j = ev.clone();
            if let Some(o) = j.as_object_mut() {
                o.insert("id".into(), json!(recur::occ_id(&st(ev, "id"), u)));
                o.insert("starts_at".into(), json!(cal::fmt_rfc3339(u)));
                o.insert("ends_at".into(), json!(cal::fmt_rfc3339(u + dur)));
                o.insert("series_id".into(), json!(st(ev, "id")));
                o.insert("recurrence_id".into(), json!(cal::fmt_rfc3339(u)));
                o.insert("_occ".into(), json!(true));
            }
            j
        })
        .collect()
}

/// "when" text for a mail, with the repeat rule appended for series.
fn repeat_label(label: &str, spec: &EventSpec) -> String {
    match spec.rrule.as_deref().and_then(|r| recur::parse(r).ok()) {
        Some(r) if spec.recurrence_id.is_none() => format!("{} (repeats {})", label, recur::human(&r)),
        _ => label.to_string(),
    }
}

struct Who {
    id: String,
    email: String,
    org_id: String,
}

async fn who(token: &str, input: &Value) -> Result<Who, axum::response::Response> {
    match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(me) => Ok(Who {
            id: me.id,
            email: me.email.trim().to_lowercase(),
            org_id: me.org_id,
        }),
        // account without a workspace row: let the legacy route (which supports personal mode) answer
        Err((StatusCode::CONFLICT, _, _)) => Err(fail(
            StatusCode::NOT_IMPLEMENTED,
            "not_implemented_for_account",
            "Use the legacy calendar route for this account.",
        )),
        Err((status, code, detail)) => Err(fail(status, code, &detail)),
    }
}

/* -------------------------------------------------------------- SMTP */

async fn smtp_reply(s: &mut tokio::net::TcpStream) -> Result<(u16, String), String> {
    use tokio::io::AsyncReadExt;
    let mut acc = String::new();
    loop {
        let mut buf = [0u8; 2048];
        let n = tokio::time::timeout(Duration::from_secs(15), s.read(&mut buf))
            .await
            .map_err(|_| "smtp read timeout".to_string())?
            .map_err(|e| e.to_string())?;
        if n == 0 {
            return Err("smtp connection closed".to_string());
        }
        acc.push_str(&String::from_utf8_lossy(&buf[..n]));
        if let Some(code) = cal::smtp_reply_code(&acc) {
            return Ok((code, acc.trim().to_string()));
        }
        if acc.len() > 16_384 {
            return Err("smtp reply too long".to_string());
        }
    }
}

async fn smtp_cmd(
    s: &mut tokio::net::TcpStream,
    line: &str,
    want: &[u16],
) -> Result<String, String> {
    use tokio::io::AsyncWriteExt;
    s.write_all(format!("{}\r\n", line).as_bytes())
        .await
        .map_err(|e| e.to_string())?;
    let (code, text) = smtp_reply(s).await?;
    if want.contains(&code) {
        Ok(text)
    } else {
        Err(format!(
            "{} -> {}",
            line.split(' ').next().unwrap_or(""),
            text
        ))
    }
}

/// Local Postfix (127.0.0.1:25, mynetworks) — same path as Brain's mail/sendmail.ts: DKIM signing + delivery by Postfix.
pub(crate) async fn smtp_send(from: &str, rcpt: &str, raw: &str) -> Result<String, String> {
    use tokio::io::AsyncWriteExt;
    let host = {
        let h = crate::env_var("MAIL_SMTP_HOST");
        if h.is_empty() {
            "127.0.0.1".to_string()
        } else {
            h
        }
    };
    let port: u16 = crate::env_var("MAIL_SMTP_PORT").parse().unwrap_or(25);
    let mut sock = tokio::time::timeout(
        Duration::from_secs(8),
        tokio::net::TcpStream::connect((host.as_str(), port)),
    )
    .await
    .map_err(|_| "smtp connect timeout".to_string())?
    .map_err(|e| format!("smtp connect: {}", e))?;
    let (code, greeting) = smtp_reply(&mut sock).await?;
    if code != 220 {
        return Err(format!("greeting -> {}", greeting));
    }
    smtp_cmd(&mut sock, "EHLO anexomail.com", &[250]).await?;
    smtp_cmd(&mut sock, &format!("MAIL FROM:<{}>", from), &[250]).await?;
    smtp_cmd(&mut sock, &format!("RCPT TO:<{}>", rcpt), &[250, 251]).await?;
    smtp_cmd(&mut sock, "DATA", &[354]).await?;
    let body = format!("{}.\r\n", cal::dot_stuff(raw));
    sock.write_all(body.as_bytes())
        .await
        .map_err(|e| e.to_string())?;
    let (code, text) = smtp_reply(&mut sock).await?;
    if code >= 400 {
        return Err(format!("message refused -> {}", text));
    }
    let _ = smtp_cmd(&mut sock, "QUIT", &[221, 250]).await;
    Ok(text)
}

/* --------------------------------------------------------- invitations */

struct Sent {
    sent: i64,
    failed: i64,
    skipped: i64,
    results: Vec<Value>,
}

fn guests_of(rows: &[Value]) -> Vec<Guest> {
    rows.iter()
        .map(|r| Guest {
            address: st(r, "address").to_lowercase(),
            name: opt(r, "display_name"),
            optional: st(r, "role") == "optional",
            response: {
                let x = st(r, "response");
                if x.is_empty() {
                    "needs_action".to_string()
                } else {
                    x
                }
            },
        })
        .collect()
}

fn event_spec(ev: &Value, organiser_name: Option<String>, rows: &[Value]) -> Option<EventSpec> {
    let sid = st(ev, "series_id");
    let exc = !sid.is_empty();
    let tzname = st(ev, "tz");
    let zone = zone_of(ev);
    Some(EventSpec {
        id: if exc { sid } else { st(ev, "id") },
        sequence: num(ev, "sequence").unwrap_or(0).max(0) as u32,
        title: st(ev, "title"),
        agenda: opt(ev, "agenda"),
        starts: cal::parse_ts(&st(ev, "starts_at"))?,
        ends: cal::parse_ts(&st(ev, "ends_at"))?,
        location: opt(ev, "location"),
        organiser: Person {
            address: st(ev, "organiser").to_lowercase(),
            name: organiser_name,
        },
        guests: guests_of(rows),
        now: now_epoch(),
        rrule: opt(ev, "rrule"),
        exdates: exdates_of(ev),
        recurrence_id: if exc { cal::parse_ts(&st(ev, "recurrence_id")) } else { None },
        tz: if tzname.is_empty() { None } else { Some((tzname, (*zone).clone())) },
    })
}

fn message_id(event_id: &str) -> String {
    let n = MSG_SEQ.fetch_add(1, Ordering::Relaxed);
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let short: String = event_id
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .take(8)
        .collect();
    format!("axc.{}.{}.{}@{}", short, nanos, n, cal::DOMAIN)
}

/// Sends `method` to the chosen attendee rows (never to the organiser), writes the ledger + per-attendee status.
async fn send_to(
    me: &Who,
    spec: &EventSpec,
    rows: &[Value],
    only: &[String],
    method: Method,
    when_label: &str,
) -> Sent {
    let mut out = Sent {
        sent: 0,
        failed: 0,
        skipped: 0,
        results: vec![],
    };
    let since = cal::fmt_rfc3339(now_epoch() - 86_400);
    let used = crate::sb_count(&format!(
        "calendar_invite_log?select=id&sent_by=eq.{}&ok=eq.true&created_at=gte.{}",
        me.id, since
    ))
    .await
    .unwrap_or(0);
    let mut left = cal::invite_quota_left(used, DAILY_INVITE_CAP);
    let base = app_url();

    for row in rows {
        let addr = st(row, "address").to_lowercase();
        // E82: room/resource (rooms.anexomail.com) kisi ka inbox nahi — un par invite mail KABHI nahi jati
        if addr == me.email || addr.is_empty() || addr.ends_with("@rooms.anexomail.com") {
            continue;
        }
        if !only.is_empty() && !only.contains(&addr) {
            continue;
        }
        let token = st(row, "rsvp_token");
        let guest = match spec.guests.iter().find(|g| g.address == addr) {
            Some(g) => g.clone(),
            None => continue,
        };
        let row_id = st(row, "id");
        if left <= 0 {
            out.skipped += 1;
            out.results.push(
                json!({ "address": addr, "status": "skipped", "error": "daily_invite_limit" }),
            );
            if !row_id.is_empty() {
                let _ = crate::sb_patch(
                    &format!("calendar_attendees?id=eq.{}", row_id),
                    json!({ "invite_status": "failed", "invite_error": "daily_invite_limit" }),
                )
                .await;
            }
            continue;
        }
        let view = if cal::token_shape_ok(&token) {
            format!("{}/rsvp?t={}", base, token)
        } else {
            format!("{}/app/calendar", base)
        };
        let links = InviteLinks {
            yes: format!("{}&r=yes", view),
            maybe: format!("{}&r=maybe", view),
            no: format!("{}&r=no", view),
            view: view.clone(),
        };
        let mid = message_id(&spec.id);
        let mail = cal::build_invite_mail(method, spec, &guest, &links, &view, when_label, &mid);
        let res = smtp_send(&me.email, &addr, &mail.raw).await;
        let (ok_flag, smtp_text, error) = match &res {
            Ok(t) => (true, t.clone(), String::new()),
            Err(e) => (false, String::new(), e.clone()),
        };
        // ledger (best effort) + the same proof table the Brain mailer writes to
        let _ = crate::sb_insert(
            "calendar_invite_log",
            json!({
                "org_id": me.org_id, "event_id": spec.id, "address": addr, "method": method.word(),
                "sequence": spec.sequence, "sent_by": me.id, "message_id": mid, "ok": ok_flag,
                "smtp_response": if ok_flag { json!(smtp_text) } else { Value::Null },
                "error": if ok_flag { Value::Null } else { json!(error) },
            }),
        )
        .await;
        let _ = crate::sb_rpc(
            "mail_outbox_record",
            json!({ "payload": {
                "from_address": me.email, "to": [addr], "subject": mail.subject, "message_id": mid,
                "smtp_response": smtp_text, "ok": ok_flag, "error": if ok_flag { Value::Null } else { json!(error) },
            }}),
        )
        .await;
        if !row_id.is_empty() && method == Method::Request {
            let patch = if ok_flag {
                json!({ "invite_status": "sent", "invite_sent_at": cal::fmt_rfc3339(now_epoch()), "invite_error": Value::Null })
            } else {
                json!({ "invite_status": "failed", "invite_error": error })
            };
            let _ = crate::sb_patch(&format!("calendar_attendees?id=eq.{}", row_id), patch).await;
        }
        if ok_flag {
            out.sent += 1;
            left -= 1;
            out.results
                .push(json!({ "address": addr, "status": "sent" }));
        } else {
            out.failed += 1;
            out.results
                .push(json!({ "address": addr, "status": "failed", "error": error }));
        }
    }
    out
}

fn invites_json(s: &Sent, engine_note: &str) -> Value {
    json!({
        "engine": "rust", "sent": s.sent, "failed": s.failed, "skipped": s.skipped,
        "results": s.results, "note": engine_note,
    })
}

async fn attendee_rows(event_id: &str) -> Vec<Value> {
    crate::sb_select(&format!(
        "calendar_attendees?select=*&event_id=eq.{}&order=address.asc",
        event_id
    ))
    .await
    .map_err(|e| eprintln!("calendar: attendee read failed: {}", e.chars().take(300).collect::<String>()))
    .ok()
    .and_then(|v| v.as_array().cloned())
    .unwrap_or_default()
}

fn event_json(ev: &Value, rows: &[Value]) -> Value {
    json!({
        "id": st(ev, "id"), "title": st(ev, "title"), "starts_at": st(ev, "starts_at"), "ends_at": st(ev, "ends_at"),
        "all_day": false, "location": ev.get("location").cloned().unwrap_or(Value::Null),
        "agenda": ev.get("agenda").cloned().unwrap_or(Value::Null),
        "organiser": ev.get("organiser").cloned().unwrap_or(Value::Null),
        "attendees": rows.iter().map(|r| json!({
            "address": st(r, "address"), "display_name": r.get("display_name").cloned().unwrap_or(Value::Null),
            "timezone": r.get("timezone").cloned().unwrap_or(Value::Null), "local_start": Value::Null, "unsociable": false,
            "response": st(r, "response"), "invite_status": st(r, "invite_status"), "invite_error": r.get("invite_error").cloned().unwrap_or(Value::Null),
            "rsvp_at": r.get("rsvp_at").cloned().unwrap_or(Value::Null),
        })).collect::<Vec<_>>(),
        "thread_id": ev.get("thread_id").cloned().unwrap_or(Value::Null),
        "thread_subject": ev.get("thread_subject").cloned().unwrap_or(Value::Null),
        "kind": "meeting", "status": st(ev, "status"), "sequence": num(ev, "sequence").unwrap_or(0),
        "cost": Value::Null, "conflict": false, "shield_conflict": false,
        "rrule": ev.get("rrule").cloned().filter(|v| v.as_str().map_or(false, |x| !x.is_empty())).unwrap_or(Value::Null),
        "recurring": !st(ev, "rrule").is_empty() || !st(ev, "series_id").is_empty(),
        "series_id": opt(ev, "series_id").map(Value::from).unwrap_or(Value::Null),
        "recurrence_id": opt(ev, "recurrence_id").map(Value::from).unwrap_or(Value::Null),
        "is_exception": !st(ev, "series_id").is_empty() && st(ev, "rrule").is_empty() && ev.get("_occ").is_none(),
        "timezone": opt(ev, "tz").map(Value::from).unwrap_or(Value::Null),
        "calendar_key": opt(ev, "calendar_key").map(Value::from).unwrap_or(Value::Null),
        "remind_min": ev.get("remind_min").cloned().filter(|v| v.is_array()).unwrap_or(Value::Null),
        "goal": opt(ev, "goal").map(Value::from).unwrap_or(Value::Null),
        "goal_state": opt(ev, "goal_state").filter(|g| cal::goal_state_ok(g)).unwrap_or_else(|| "open".into()),
        "goal_state_at": opt(ev, "goal_state_at").map(Value::from).unwrap_or(Value::Null),
    })
}

fn when_label_of(input: &Value, starts: i64) -> String {
    let w = cal::clean_line(&st(input, "when_label"), 80);
    if w.is_empty() {
        cal::fmt_human_utc(starts)
    } else {
        w
    }
}

/* ------------------------------------------------------------- procs */

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    let me = match who(token, input).await {
        Ok(m) => m,
        Err(r) => return r,
    };
    if !v2_ready().await {
        return fail(
            StatusCode::NOT_IMPLEMENTED,
            "calendar_v2_sql_missing",
            "Calendar v2 SQL (E31) is not installed yet.",
        );
    }
    match proc {
        "calendar.create" => create(&me, input).await,
        "calendar.update" => update(&me, input).await,
        "calendar.invites.resend" => resend(&me, input).await,
        "calendar.busy" => busy(&me, input).await,
        "calendar.findtime" => findtime(&me, input).await,
        "calendar.guests" => guests(&me, input).await,
        "calendar.events" => events(&me, input).await,
        "calendar.event" => event_one(&me, input).await,
        "calendar.load" => team_load(&me, input).await,
        "calendar.meta.set" => meta_set(&me, input).await,
        "calendar.history" => history(&me, input).await,
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    }
}

async fn create(me: &Who, input: &Value) -> axum::response::Response {
    let title = cal::clean_line(&st(input, "title"), 200);
    let agenda = st(input, "agenda").trim().to_string();
    if title.chars().count() < 2 {
        return fail(StatusCode::BAD_REQUEST, "bad_title", "Title is required");
    }
    if agenda.chars().count() < 5 {
        return fail(
            StatusCode::BAD_REQUEST,
            "agenda_required",
            "A meeting needs a purpose",
        );
    }
    let starts = match cal::parse_ts(&st(input, "starts_at")) {
        Some(t) => t,
        None => return fail(StatusCode::BAD_REQUEST, "bad_time", "Start time is invalid"),
    };
    let minutes = num(input, "duration_minutes").unwrap_or(30);
    if !(5..=1440).contains(&minutes) {
        return fail(
            StatusCode::BAD_REQUEST,
            "bad_duration",
            "Duration must be between 5 minutes and 24 hours",
        );
    }
    let ends = starts + minutes * 60;
    let raw: Vec<String> = input
        .get("attendees")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|x| x.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();
    let list = cal::normalise_attendees(&raw, &me.email, MAX_GUESTS);
    if list.over_cap > 0 {
        return fail(
            StatusCode::BAD_REQUEST,
            "too_many_guests",
            &format!("A meeting can invite up to {} people.", MAX_GUESTS),
        );
    }
    // E71: a brand-new (probation) account cannot invite guests — the meeting itself is fine, the invitations are not.
    if list.kept.len() > 1 {
        if let Some(r) = crate::export_glue::probation_deny(&me.id, "invite", 0).await {
            return r;
        }
    }
    let tz = opt(input, "timezone").map(|t| cal::clean_line(&t, 64));
    let thread_id = opt(input, "thread_id").filter(|t| cal::token_shape_ok(t));
    // repeating meeting (every package): rule is validated and stored in canonical form
    let mut rrule_store: Option<String> = None;
    if let Some(r) = opt(input, "rrule").map(|r| r.trim().trim_start_matches("RRULE:").to_string()).filter(|r| !r.is_empty()) {
        if !recur_ready().await {
            return fail(StatusCode::NOT_IMPLEMENTED, "calendar_recurrence_sql_missing", "Repeating meetings need the E56 SQL.");
        }
        match recur::parse(&r) {
            Ok(rule) => rrule_store = Some(recur::to_string(&rule)),
            Err(m) => return fail(StatusCode::BAD_REQUEST, "bad_rrule", &m),
        }
    }
    let tz_off = num(input, "tz_offset_min").map(|n| n.clamp(-840, 840));

    let mut ev_body = json!({
            "org_id": me.org_id, "title": title, "agenda": agenda,
            "starts_at": cal::fmt_rfc3339(starts), "ends_at": cal::fmt_rfc3339(ends), "all_day": false,
            "location": opt(input, "location").map(|l| cal::clean_line(&l, 300)),
            "organiser": me.email, "thread_id": thread_id, "thread_subject": opt(input, "thread_subject").map(|t| cal::clean_line(&t, 200)),
            "kind": "meeting", "status": "confirmed", "created_by": me.id, "tz": tz, "sequence": 0,
        });
    if recur_ready().await {
        if let Some(o) = ev_body.as_object_mut() {
            if let Some(r) = &rrule_store {
                o.insert("rrule".into(), json!(r));
            }
            if let Some(n) = tz_off {
                o.insert("tz_offset_min".into(), json!(n));
            }
        }
    }
    if e58_ready().await {
        if let Some(o) = ev_body.as_object_mut() {
            if let Some(k) = calendar_key_of(input) {
                o.insert("calendar_key".into(), json!(k));
            }
            if let Some(r) = remind_of(input).filter(|r| !r.is_empty()) {
                o.insert("remind_min".into(), json!(r));
            }
        }
    }
    let ev_row = crate::sb_insert("calendar_events", ev_body).await;
    if let Err(e) = &ev_row {
        eprintln!("calendar.create: event insert failed: {}", e.chars().take(400).collect::<String>());
    }
    let ev = match ev_row
        .ok()
        .and_then(|v| v.as_array().and_then(|a| a.first().cloned()))
    {
        Some(e) => e,
        None => {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "server_error",
                "Calendar failed",
            )
        }
    };
    let event_id = st(&ev, "id");

    let attendee_body: Vec<Value> = list
        .kept
        .iter()
        .map(|a| {
            let mine = *a == me.email;
            json!({
                "event_id": event_id, "org_id": me.org_id, "address": a,
                "timezone": if mine { json!(tz) } else { Value::Null },
                "response": if mine { "accepted" } else { "needs_action" },
                "invite_status": "not_sent",
            })
        })
        .collect();
    let rows = match crate::sb_insert("calendar_attendees", Value::Array(attendee_body)).await {
        Ok(v) => v.as_array().cloned().unwrap_or_default(),
        Err(e) => {
            eprintln!("calendar.create: attendee insert failed: {}", e.chars().take(400).collect::<String>());
            // Yatim event na rahe: attendee na bane to event wapas hata do.
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs() as i64)
                .unwrap_or(0);
            let _ = crate::sb_patch(
                &format!("calendar_events?id=eq.{}", event_id),
                json!({ "cancelled_at": cal::fmt_rfc3339(now), "status": "cancelled" }),
            )
            .await;
            if e.contains("room_busy") {
                return room_busy();
            }
            if e.contains("no_room") {
                return fail(StatusCode::BAD_REQUEST, "no_room", "That room is not available. Book rooms from the meeting's Room section.");
            }
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "server_error",
                "Calendar failed",
            )
        }
    };

    if let Some(tid) = thread_id {
        let _ = crate::sb_insert(
            "mail_thread_events",
            json!({ "org_id": me.org_id, "thread_id": tid, "kind": "meeting_created", "actor": me.email,
                    "payload": { "event_id": event_id, "title": title } }),
        )
        .await;
    }

    let want_invites = input
        .get("invite")
        .and_then(|v| v.as_bool())
        .unwrap_or(true);
    let has_guests = rows
        .iter()
        .any(|r| st(r, "address").to_lowercase() != me.email);
    let invites = if want_invites && has_guests {
        let spec = match event_spec(&ev, opt(input, "organiser_name"), &rows) {
            Some(s) => s,
            None => {
                return fail(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "server_error",
                    "Calendar failed",
                )
            }
        };
        let sent = send_to(
            me,
            &spec,
            &rows,
            &[],
            Method::Request,
            &repeat_label(&when_label_of(input, starts), &spec),
        )
        .await;
        invites_json(&sent, "")
    } else {
        json!({ "engine": "rust", "sent": 0, "failed": 0, "skipped": 0, "results": [],
                "note": if has_guests { "invitations were switched off for this meeting" } else { "no guests to invite" } })
    };

    let fresh = attendee_rows(&event_id).await;
    crate::ok(json!({
        "event": event_json(&ev, if fresh.is_empty() { &rows } else { &fresh }),
        "invites": invites,
        "ignored": { "invalid": list.invalid, "duplicate": list.duplicate },
    }))
    .into_response()
}

async fn load_own_event(me: &Who, raw_id: &str) -> Result<Value, axum::response::Response> {
    let id = recur::split_occ(raw_id).0; // "<uuid>~<epoch>" = one occurrence of a series
    if !cal::token_shape_ok(id) {
        return Err(fail(
            StatusCode::BAD_REQUEST,
            "bad_id",
            "Event id is invalid",
        ));
    }
    let rows = crate::sb_select(&format!(
        "calendar_events?select=*&id=eq.{}&org_id=eq.{}",
        id, me.org_id
    ))
    .await
    .map_err(|_| {
        fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "server_error",
            "Calendar failed",
        )
    })?;
    let ev = rows.as_array().and_then(|a| a.first().cloned());
    match ev {
        Some(e) => Ok(e),
        None => Err(fail(StatusCode::NOT_FOUND, "not_found", "Event not found")),
    }
}

fn organiser_only(me: &Who, ev: &Value) -> Option<axum::response::Response> {
    if st(ev, "organiser").to_lowercase() != me.email {
        Some(fail(
            StatusCode::FORBIDDEN,
            "organiser_only",
            "Only the organiser can change or cancel this meeting.",
        ))
    } else {
        None
    }
}

/// Personal labels of a meeting — which of the organiser's calendars it sits in, and when to remind. These are NOT a change to the
/// meeting: no new SEQUENCE, no mail to guests. (For a repeating series the label sits on the master, so every occurrence shares it.)
async fn meta_set(me: &Who, input: &Value) -> axum::response::Response {
    if !e58_ready().await {
        return fail(StatusCode::NOT_IMPLEMENTED, "calendar_e58_sql_missing", "Calendar labels and reminders need the E58 SQL.");
    }
    let ev = match load_own_event(me, &st(input, "id")).await {
        Ok(e) => e,
        Err(r) => return r,
    };
    if let Some(r) = organiser_only(me, &ev) {
        return r;
    }
    let mut patch = serde_json::Map::new();
    if input.get("calendar_key").is_some() {
        match input.get("calendar_key") {
            Some(Value::Null) => {
                patch.insert("calendar_key".into(), Value::Null);
            }
            _ => match calendar_key_of(input) {
                Some(k) => {
                    patch.insert("calendar_key".into(), json!(k));
                }
                None => return fail(StatusCode::BAD_REQUEST, "bad_calendar", "Calendar key is not valid"),
            },
        }
    }
    if input.get("remind_min").is_some() {
        match input.get("remind_min") {
            Some(Value::Null) => {
                patch.insert("remind_min".into(), Value::Null);
            }
            _ => match remind_of(input) {
                Some(r) => {
                    patch.insert("remind_min".into(), if r.is_empty() { Value::Null } else { json!(r) });
                }
                None => return fail(StatusCode::BAD_REQUEST, "bad_reminders", "Reminders must be a list of minutes"),
            },
        }
    }
    if input.get("goal").is_some() || input.get("goal_state").is_some() {
        // Outcome colours (#9): one tap = one meeting. A repeating series shares one row, so "achieved" would colour every occurrence — refused, not faked.
        if !st(&ev, "rrule").is_empty() {
            return fail(StatusCode::BAD_REQUEST, "goal_single_only", "Outcome tracking is for single meetings. Open one occurrence as its own meeting first.");
        }
        if !e63_ready().await {
            return fail(StatusCode::NOT_IMPLEMENTED, "calendar_e63_sql_missing", "Meeting outcomes need the E63 SQL.");
        }
        match input.get("goal") {
            None => {}
            Some(Value::Null) => {
                patch.insert("goal".into(), Value::Null);
            }
            Some(v) => match cal::clean_goal(v.as_str().unwrap_or("")) {
                Ok(g) => {
                    patch.insert("goal".into(), json!(g));
                }
                Err(m) => return fail(StatusCode::BAD_REQUEST, "bad_goal", m),
            },
        }
        if let Some(v) = input.get("goal_state") {
            let state = v.as_str().unwrap_or("");
            if !cal::goal_state_ok(state) {
                return fail(StatusCode::BAD_REQUEST, "bad_goal_state", "State must be open, achieved or missed");
            }
            let starts = cal::parse_ts(&st(&ev, "starts_at")).unwrap_or(i64::MAX);
            if state != "open" && now_epoch() < starts {
                return fail(StatusCode::BAD_REQUEST, "not_started", "The meeting has not started yet");
            }
            patch.insert("goal_state".into(), json!(state));
            patch.insert(
                "goal_state_at".into(),
                if state == "open" { Value::Null } else { json!(cal::fmt_rfc3339(now_epoch())) },
            );
        }
    }
    if patch.is_empty() {
        return fail(StatusCode::BAD_REQUEST, "nothing_to_change", "Nothing to change");
    }
    let id = st(&ev, "id");
    match crate::sb_patch(&format!("calendar_events?id=eq.{}&org_id=eq.{}", id, me.org_id), Value::Object(patch)).await {
        Ok(_) => crate::ok(json!({ "ok": true, "id": id })).into_response(),
        Err(e) if e.contains("room_busy") => room_busy(),
        Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Calendar failed"),
    }
}

/* ------------------------------------------------ history search (#10, E64) */

static HIST_RATE: std::sync::OnceLock<std::sync::Mutex<std::collections::HashMap<String, std::collections::VecDeque<u64>>>> = std::sync::OnceLock::new();
const HIST_LIMIT: usize = 40;
const HIST_WINDOW_MS: u64 = 60_000;

/// Sliding window per user (searches are heavier than reads). A poisoned lock never blocks a real user.
fn hist_allowed(user: &str) -> bool {
    let now = (now_epoch() as u64) * 1000;
    let m = HIST_RATE.get_or_init(|| std::sync::Mutex::new(std::collections::HashMap::new()));
    match m.lock() {
        Ok(mut map) => {
            if map.len() > 5_000 {
                map.retain(|_, q| q.back().map(|t| now.saturating_sub(*t) < HIST_WINDOW_MS).unwrap_or(false));
            }
            let q = map.entry(user.to_string()).or_default();
            while q.front().map(|t| now.saturating_sub(*t) >= HIST_WINDOW_MS).unwrap_or(false) {
                q.pop_front();
            }
            if q.len() >= HIST_LIMIT {
                false
            } else {
                q.push_back(now);
                true
            }
        }
        Err(_) => true,
    }
}

/// Years of meetings, one box. Text / person / date range — at least one. The privacy wall (active member of this org) is in SQL.
async fn history(me: &Who, input: &Value) -> axum::response::Response {
    if !hist_allowed(&me.id) {
        return fail(StatusCode::TOO_MANY_REQUESTS, "too_many_requests", "Too many searches — please try again in a minute.");
    }
    let q = cal::clean_search_text(&st(input, "q"), 200);
    let person = cal::clean_search_text(&st(input, "person"), 120);
    let parse = |k: &str| -> Result<Option<i64>, ()> {
        let raw = st(input, k);
        if raw.trim().is_empty() {
            return Ok(None);
        }
        cal::parse_ts(&raw).map(Some).ok_or(())
    };
    let (from, to) = match (parse("from"), parse("to")) {
        (Ok(f), Ok(t)) => (f, t),
        _ => return fail(StatusCode::BAD_REQUEST, "bad_range", "from and to must be RFC 3339 times"),
    };
    if let (Some(f), Some(t)) = (from, to) {
        if t <= f {
            return fail(StatusCode::BAD_REQUEST, "bad_range", "The end of the range is before its start");
        }
    }
    if q.is_none() && person.is_none() && from.is_none() && to.is_none() {
        return fail(StatusCode::BAD_REQUEST, "empty_query", "Type at least two letters, pick a person or choose dates");
    }
    let (limit, offset) = cal::history_page(num(input, "limit"), num(input, "offset"));
    let order = cal::history_order(&st(input, "order"));
    // Keyset cursor (recent / oldest): both halves or neither; a half-given or malformed cursor is refused, never guessed.
    let (after_ts, after_id) = match (st(input, "after_ts"), st(input, "after_id")) {
        (a, b) if a.trim().is_empty() && b.trim().is_empty() => (None, None),
        (a, b) => match cal::history_cursor(&a, &b) {
            Some((t, i)) => (Some(t), Some(i)),
            None => return fail(StatusCode::BAD_REQUEST, "bad_cursor", "That page marker is not valid — search again"),
        },
    };
    let facets = input.get("facets").and_then(|v| v.as_bool()).unwrap_or(false);
    let body = json!({
        "p_org": me.org_id, "p_viewer": me.id, "p_q": q, "p_person": person, "p_order": order, "p_limit": limit, "p_offset": offset,
        "p_from": from.map(cal::fmt_rfc3339), "p_to": to.map(cal::fmt_rfc3339),
        "p_after_ts": after_ts, "p_after_id": after_id, "p_facets": facets,
    });
    match crate::sb_rpc("calendar_history", body).await {
        Ok(v) => match v.get("error").and_then(|e| e.as_str()) {
            Some("forbidden") => fail(StatusCode::FORBIDDEN, "forbidden", "You are not allowed to search this workspace's calendar."),
            Some("bad_range") => fail(StatusCode::BAD_REQUEST, "bad_range", "The end of the range is before its start"),
            Some("empty_query") => fail(StatusCode::BAD_REQUEST, "empty_query", "Type at least two letters, pick a person or choose dates"),
            Some(other) => {
                eprintln!("history: unexpected error code {}", other.chars().take(40).collect::<String>());
                fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Search failed — please try again.")
            }
            None => crate::ok(v).into_response(),
        },
        Err(e) if e.contains("PGRST202") || e.contains("Could not find the function") || e.contains("42883") => {
            fail(StatusCode::NOT_IMPLEMENTED, "history_sql_missing", "History search is not installed yet (SQL E64).")
        }
        Err(e) if e.contains("57014") || e.to_lowercase().contains("statement timeout") => {
            fail(StatusCode::GATEWAY_TIMEOUT, "search_timeout", "That search is too wide — narrow the dates or add a person.")
        }
        Err(e) => {
            eprintln!("history: calendar_history failed: {}", e.chars().take(300).collect::<String>());
            fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Search failed — please try again.")
        }
    }
}

/// "This meeting only" for a repeating series: cancel one occurrence (exdate + CANCEL for that date) or edit it
/// (exception row with its own time/title, the master skips that date).
async fn update_this(me: &Who, input: &Value, ev: &Value, occ: i64) -> axum::response::Response {
    let cancel = input.get("cancel").and_then(|v| v.as_bool()).unwrap_or(false);
    let notify = input.get("notify").and_then(|v| v.as_bool()).unwrap_or(true);
    let master_id = st(ev, "id");
    let found = occurrences(ev, occ, occ + 1)
        .into_iter()
        .find(|o| cal::parse_ts(&st(o, "starts_at")) == Some(occ));
    let o = match found {
        Some(o) => o,
        None => return fail(StatusCode::GONE, "occurrence_gone", "That occurrence no longer exists"),
    };
    let o_end = cal::parse_ts(&st(&o, "ends_at")).unwrap_or(occ + 3600);
    let mut ex = exdates_of(ev);
    if !ex.contains(&occ) {
        ex.push(occ);
    }
    ex.sort();
    let ex_json: Vec<String> = ex.iter().map(|x| cal::fmt_rfc3339(*x)).collect();
    let seq = num(ev, "sequence").unwrap_or(0) + 1;
    let rows = attendee_rows(&master_id).await;
    let guests = rows.iter().any(|r| st(r, "address").to_lowercase() != me.email);
    let rec_iso = cal::fmt_rfc3339(occ);

    if cancel {
        if crate::sb_patch(
            &format!("calendar_events?id=eq.{}&org_id=eq.{}", master_id, me.org_id),
            json!({ "exdates": ex_json, "sequence": seq, "updated_at": cal::fmt_rfc3339(now_epoch()) }),
        )
        .await
        .is_err()
        {
            return fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Calendar failed");
        }
        let mut synth = o.clone();
        if let Some(m) = synth.as_object_mut() {
            m.remove("_occ");
            m.insert("id".into(), json!(master_id));
            m.insert("rrule".into(), Value::Null);
            m.insert("series_id".into(), json!(master_id));
            m.insert("recurrence_id".into(), json!(rec_iso));
            m.insert("sequence".into(), json!(seq));
            m.insert("status".into(), json!("cancelled"));
        }
        let invites = if notify && guests {
            match event_spec(&synth, opt(input, "organiser_name"), &rows) {
                Some(spec) => {
                    let sent = send_to(me, &spec, &rows, &[], Method::Cancel, &when_label_of(input, spec.starts)).await;
                    invites_json(&sent, "")
                }
                None => json!({ "engine": "rust", "sent": 0, "failed": 0, "skipped": 0, "results": [], "note": "time could not be read" }),
            }
        } else {
            json!({ "engine": "rust", "sent": 0, "failed": 0, "skipped": 0, "results": [], "note": "guests were not notified" })
        };
        return crate::ok(json!({ "event": event_json(&synth, &rows), "invites": invites, "cancelled": true, "scope": "this" })).into_response();
    }

    let mut new_start = occ;
    let mut moved = false;
    if let Some(t) = input.get("starts_at").and_then(|v| v.as_str()) {
        match cal::parse_ts(t) {
            Some(x) => new_start = x,
            None => return fail(StatusCode::BAD_REQUEST, "bad_time", "Start time is invalid"),
        }
    }
    let minutes = num(input, "duration_minutes").unwrap_or((o_end - occ) / 60);
    if !(5..=1440).contains(&minutes) {
        return fail(StatusCode::BAD_REQUEST, "bad_duration", "Duration must be between 5 minutes and 24 hours");
    }
    let new_end = new_start + minutes * 60;
    if new_start != occ || new_end != o_end {
        moved = true;
    }
    let mut changed = moved;
    let mut title = st(ev, "title");
    if let Some(t) = input.get("title").and_then(|v| v.as_str()) {
        let t = cal::clean_line(t, 200);
        if t.chars().count() < 2 {
            return fail(StatusCode::BAD_REQUEST, "bad_title", "Title is required");
        }
        if t != title {
            title = t;
            changed = true;
        }
    }
    let mut agenda = opt(ev, "agenda");
    if let Some(a) = input.get("agenda").and_then(|v| v.as_str()) {
        if a.trim().chars().count() < 5 {
            return fail(StatusCode::BAD_REQUEST, "agenda_required", "A meeting needs a purpose");
        }
        if Some(a.trim().to_string()) != agenda {
            agenda = Some(a.trim().to_string());
            changed = true;
        }
    }
    let mut location = opt(ev, "location");
    if let Some(l) = input.get("location").and_then(|v| v.as_str()) {
        let l = cal::clean_line(l, 300);
        let l = if l.is_empty() { None } else { Some(l) };
        if l != location {
            location = l;
            changed = true;
        }
    }
    if !changed {
        return fail(StatusCode::BAD_REQUEST, "nothing_to_change", "Nothing to change");
    }
    let row = crate::sb_insert(
        "calendar_events",
        json!({
            "org_id": me.org_id, "title": title, "agenda": agenda, "location": location,
            "starts_at": cal::fmt_rfc3339(new_start), "ends_at": cal::fmt_rfc3339(new_end), "all_day": false,
            "organiser": me.email, "kind": "meeting", "status": "confirmed", "created_by": me.id,
            "tz": ev.get("tz").cloned().unwrap_or(Value::Null), "tz_offset_min": ev.get("tz_offset_min").cloned().unwrap_or(Value::Null),
            "sequence": seq, "series_id": master_id, "recurrence_id": rec_iso,
        }),
    )
    .await;
    let exc = match row.ok().and_then(|v| v.as_array().and_then(|a| a.first().cloned())) {
        Some(r) => r,
        None => return fail(StatusCode::CONFLICT, "exception_exists", "This occurrence was already changed — reload the calendar."),
    };
    let exc_id = st(&exc, "id");
    let body: Vec<Value> = rows
        .iter()
        .map(|r| {
            let mine = st(r, "address").to_lowercase() == me.email;
            json!({
                "event_id": exc_id, "org_id": me.org_id, "address": st(r, "address"),
                "display_name": r.get("display_name").cloned().unwrap_or(Value::Null),
                "role": if st(r, "role").is_empty() { "required".to_string() } else { st(r, "role") },
                "timezone": r.get("timezone").cloned().unwrap_or(Value::Null),
                "response": if mine { "accepted".to_string() } else if moved { "needs_action".to_string() } else { st(r, "response") },
                "invite_status": "not_sent",
            })
        })
        .collect();
    let new_rows = crate::sb_insert("calendar_attendees", Value::Array(body))
        .await
        .ok()
        .and_then(|v| v.as_array().cloned())
        .unwrap_or_default();
    // the master now skips that date (the exception row stands in for it)
    if crate::sb_patch(
        &format!("calendar_events?id=eq.{}&org_id=eq.{}", master_id, me.org_id),
        json!({ "exdates": ex_json, "updated_at": cal::fmt_rfc3339(now_epoch()) }),
    )
    .await
    .is_err()
    {
        return fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Calendar failed");
    }
    let invites = if notify && guests {
        match event_spec(&exc, opt(input, "organiser_name"), &new_rows) {
            Some(spec) => {
                let sent = send_to(me, &spec, &new_rows, &[], Method::Request, &when_label_of(input, spec.starts)).await;
                invites_json(&sent, "")
            }
            None => json!({ "engine": "rust", "sent": 0, "failed": 0, "skipped": 0, "results": [], "note": "time could not be read" }),
        }
    } else {
        json!({ "engine": "rust", "sent": 0, "failed": 0, "skipped": 0, "results": [], "note": "guests were not notified" })
    };
    let fresh = attendee_rows(&exc_id).await;
    crate::ok(json!({ "event": event_json(&exc, &fresh), "invites": invites, "cancelled": false, "scope": "this" })).into_response()
}

async fn update(me: &Who, input: &Value) -> axum::response::Response {
    let raw = st(input, "id");
    let (id_s, occ) = recur::split_occ(&raw);
    let id = id_s.to_string();
    let ev = match load_own_event(me, &id).await {
        Ok(e) => e,
        Err(r) => return r,
    };
    if let Some(r) = organiser_only(me, &ev) {
        return r;
    }
    if st(&ev, "status") == "cancelled" {
        return fail(
            StatusCode::CONFLICT,
            "already_cancelled",
            "This meeting is already cancelled.",
        );
    }
    let master = is_master(&ev);
    if master {
        if let Some(o) = occ {
            if st(input, "scope") != "all" {
                return update_this(me, input, &ev, o).await;
            }
        }
    }
    let cancel = input
        .get("cancel")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    let notify = input
        .get("notify")
        .and_then(|v| v.as_bool())
        .unwrap_or(true);
    let old_start = cal::parse_ts(&st(&ev, "starts_at")).unwrap_or(0);
    let old_end = cal::parse_ts(&st(&ev, "ends_at")).unwrap_or(old_start);

    let mut patch = serde_json::Map::new();
    let mut moved = false;
    let mut changed = false;
    let mut new_start = old_start;
    let mut new_end = old_end;
    if input.get("starts_at").is_some() || input.get("duration_minutes").is_some() {
        if let Some(t) = input.get("starts_at").and_then(|v| v.as_str()) {
            match cal::parse_ts(t) {
                // "all events": the user dragged ONE occurrence; the whole series moves by the same distance
                Some(x) => new_start = if master { old_start + (x - occ.unwrap_or(old_start)) } else { x },
                None => return fail(StatusCode::BAD_REQUEST, "bad_time", "Start time is invalid"),
            }
        }
        let minutes = num(input, "duration_minutes").unwrap_or((old_end - old_start) / 60);
        if !(5..=1440).contains(&minutes) {
            return fail(
                StatusCode::BAD_REQUEST,
                "bad_duration",
                "Duration must be between 5 minutes and 24 hours",
            );
        }
        new_end = new_start + minutes * 60;
        if new_start != old_start || new_end != old_end {
            patch.insert("starts_at".into(), json!(cal::fmt_rfc3339(new_start)));
            patch.insert("ends_at".into(), json!(cal::fmt_rfc3339(new_end)));
            moved = true;
            changed = true;
        }
    }
    if let Some(t) = input.get("title").and_then(|v| v.as_str()) {
        let t = cal::clean_line(t, 200);
        if t.chars().count() < 2 {
            return fail(StatusCode::BAD_REQUEST, "bad_title", "Title is required");
        }
        if t != st(&ev, "title") {
            patch.insert("title".into(), json!(t));
            changed = true;
        }
    }
    if let Some(a) = input.get("agenda").and_then(|v| v.as_str()) {
        if a.trim().chars().count() < 5 {
            return fail(
                StatusCode::BAD_REQUEST,
                "agenda_required",
                "A meeting needs a purpose",
            );
        }
        if a.trim() != st(&ev, "agenda") {
            patch.insert("agenda".into(), json!(a.trim()));
            changed = true;
        }
    }
    if let Some(l) = input.get("location").and_then(|v| v.as_str()) {
        let l = cal::clean_line(l, 300);
        if l != st(&ev, "location") {
            patch.insert(
                "location".into(),
                if l.is_empty() { Value::Null } else { json!(l) },
            );
            changed = true;
        }
    }
    if master {
        if let Some(r) = input.get("rrule").and_then(|v| v.as_str()) {
            match recur::parse(r.trim().trim_start_matches("RRULE:")) {
                Ok(rule) => {
                    let canon = recur::to_string(&rule);
                    if canon != st(&ev, "rrule") {
                        patch.insert("rrule".into(), json!(canon));
                        changed = true;
                        moved = true;
                    }
                }
                Err(m) => return fail(StatusCode::BAD_REQUEST, "bad_rrule", &m),
            }
        }
    }
    if !cancel && !changed {
        return fail(
            StatusCode::BAD_REQUEST,
            "nothing_to_change",
            "Nothing to change",
        );
    }
    let seq = num(&ev, "sequence").unwrap_or(0) + 1;
    patch.insert("sequence".into(), json!(seq));
    if cancel {
        patch.insert("status".into(), json!("cancelled"));
        patch.insert("cancelled_at".into(), json!(cal::fmt_rfc3339(now_epoch())));
    }
    patch.insert("updated_at".into(), json!(cal::fmt_rfc3339(now_epoch())));
    if let Err(e) = crate::sb_patch(
        &format!("calendar_events?id=eq.{}&org_id=eq.{}", id, me.org_id),
        Value::Object(patch),
    )
    .await
    {
        if e.contains("room_busy") {
            return room_busy();
        }
        return fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "server_error",
            "Calendar failed",
        );
    }
    if cancel && master {
        let _ = crate::sb_patch(
            &format!("calendar_events?series_id=eq.{}&org_id=eq.{}&cancelled_at=is.null", id, me.org_id),
            json!({ "status": "cancelled", "cancelled_at": cal::fmt_rfc3339(now_epoch()) }),
        )
        .await;
    }
    if moved {
        // a new time means everyone is asked again (the organiser stays accepted)
        let _ = crate::sb_patch(
            &format!(
                "calendar_attendees?event_id=eq.{}&address=neq.{}",
                id,
                pe(&me.email)
            ),
            json!({ "response": "needs_action", "rsvp_at": Value::Null }),
        )
        .await;
    }
    let ev_after = match load_own_event(me, &id).await {
        Ok(e) => e,
        Err(r) => return r,
    };
    let rows = attendee_rows(&id).await;
    let invites = if notify
        && rows
            .iter()
            .any(|r| st(r, "address").to_lowercase() != me.email)
    {
        match event_spec(&ev_after, opt(input, "organiser_name"), &rows) {
            Some(spec) => {
                let method = if cancel {
                    Method::Cancel
                } else {
                    Method::Request
                };
                let sent = send_to(
                    me,
                    &spec,
                    &rows,
                    &[],
                    method,
                    &repeat_label(&when_label_of(input, spec.starts), &spec),
                )
                .await;
                invites_json(&sent, "")
            }
            None => {
                json!({ "engine": "rust", "sent": 0, "failed": 0, "skipped": 0, "results": [], "note": "time could not be read" })
            }
        }
    } else {
        json!({ "engine": "rust", "sent": 0, "failed": 0, "skipped": 0, "results": [], "note": "guests were not notified" })
    };
    let fresh = attendee_rows(&id).await;
    crate::ok(
        json!({ "event": event_json(&ev_after, &fresh), "invites": invites, "cancelled": cancel }),
    )
    .into_response()
}

async fn resend(me: &Who, input: &Value) -> axum::response::Response {
    let id = recur::split_occ(&st(input, "id")).0.to_string();
    let ev = match load_own_event(me, &id).await {
        Ok(e) => e,
        Err(r) => return r,
    };
    if let Some(r) = organiser_only(me, &ev) {
        return r;
    }
    if st(&ev, "status") == "cancelled" {
        return fail(
            StatusCode::CONFLICT,
            "already_cancelled",
            "This meeting is cancelled.",
        );
    }
    let rows = attendee_rows(&id).await;
    let only: Vec<String> = match opt(input, "address") {
        Some(a) => vec![a.trim().to_lowercase()],
        // everyone who has not answered yet, plus anyone whose mail failed
        None => rows
            .iter()
            .filter(|r| {
                let resp = st(r, "response");
                (resp == "needs_action" || st(r, "invite_status") != "sent") && resp != "declined"
            })
            .map(|r| st(r, "address").to_lowercase())
            .collect(),
    };
    if only.is_empty() {
        return crate::ok(json!({ "event": event_json(&ev, &rows), "invites": { "engine": "rust", "sent": 0, "failed": 0, "skipped": 0, "results": [], "note": "everyone has already answered" } })).into_response();
    }
    let spec = match event_spec(&ev, opt(input, "organiser_name"), &rows) {
        Some(s) => s,
        None => {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "server_error",
                "Calendar failed",
            )
        }
    };
    let sent = send_to(
        me,
        &spec,
        &rows,
        &only,
        Method::Request,
        &repeat_label(&when_label_of(input, spec.starts), &spec),
    )
    .await;
    let fresh = attendee_rows(&id).await;
    crate::ok(json!({ "event": event_json(&ev, &fresh), "invites": invites_json(&sent, "") }))
        .into_response()
}

/// Who was invited, who answered, and what happened to each invitation. Never exposes the RSVP tokens.
async fn guests(me: &Who, input: &Value) -> axum::response::Response {
    let id = recur::split_occ(&st(input, "id")).0.to_string();
    let ev = match load_own_event(me, &id).await {
        Ok(e) => e,
        Err(r) => return r,
    };
    let rows = attendee_rows(&id).await;
    crate::ok(json!({
        "event_id": id,
        "status": st(&ev, "status"),
        "sequence": num(&ev, "sequence").unwrap_or(0),
        "organiser": ev.get("organiser").cloned().unwrap_or(Value::Null),
        "is_organiser": st(&ev, "organiser").to_lowercase() == me.email,
        "attendees": rows.iter().map(|r| json!({
            "address": st(r, "address"),
            "role": st(r, "role"),
            "response": st(r, "response"),
            "rsvp_at": r.get("rsvp_at").cloned().unwrap_or(Value::Null),
            "rsvp_comment": r.get("rsvp_comment").cloned().unwrap_or(Value::Null),
            "rsvp_via": r.get("rsvp_via").cloned().unwrap_or(Value::Null),
            "invite_status": st(r, "invite_status"),
            "invite_sent_at": r.get("invite_sent_at").cloned().unwrap_or(Value::Null),
            "invite_error": r.get("invite_error").cloned().unwrap_or(Value::Null),
        })).collect::<Vec<_>>(),
    }))
    .into_response()
}

fn addresses_of(input: &Value) -> Vec<String> {
    input
        .get("addresses")
        .and_then(|v| v.as_array())
        .map(|a| {
            let mut out: Vec<String> = Vec::new();
            for x in a.iter().filter_map(|x| x.as_str()) {
                let l = x.trim().to_lowercase();
                if cal::valid_email(&l) && !out.contains(&l) && out.len() < 30 {
                    out.push(l);
                }
            }
            out
        })
        .unwrap_or_default()
}

/* ------------------------------------------------ reads: events / event / load (20 Oct 2026) */

fn range_of(input: &Value) -> Option<(i64, i64)> {
    match (cal::parse_ts(&st(input, "from")), cal::parse_ts(&st(input, "to"))) {
        (Some(f), Some(t)) if t > f && t - f <= 62 * 86_400 => Some((f, t)),
        _ => None,
    }
}

async fn events_between(me: &Who, from: i64, to: i64) -> Result<Vec<Value>, ()> {
    let rec = recur_ready().await;
    let q = format!(
        "calendar_events?select=*&org_id=eq.{}&cancelled_at=is.null{}&starts_at=lt.{}&ends_at=gt.{}&order=starts_at.asc&limit=500",
        me.org_id,
        if rec { "&rrule=is.null" } else { "" },
        cal::fmt_rfc3339(to),
        cal::fmt_rfc3339(from)
    );
    let v = crate::sb_select(&q).await.map_err(|_| ())?;
    let mut out = v.as_array().cloned().unwrap_or_default();
    if rec {
        // series masters start before the window and repeat into it: expand them here (time zone + DST aware)
        let mq = format!(
            "calendar_events?select=*&org_id=eq.{}&cancelled_at=is.null&rrule=not.is.null&starts_at=lt.{}&limit=300",
            me.org_id,
            cal::fmt_rfc3339(to)
        );
        let masters = crate::sb_select(&mq).await.map_err(|_| ())?;
        for m in masters.as_array().cloned().unwrap_or_default() {
            if st(&m, "status") == "cancelled" {
                continue;
            }
            out.extend(occurrences(&m, from, to));
        }
        out.sort_by_key(|e| cal::parse_ts(&st(e, "starts_at")).unwrap_or(0));
        out.truncate(1500);
    }
    Ok(out)
}

/// The real event row an expanded occurrence belongs to (attendees live on the master).
fn base_id(e: &Value) -> String {
    if e.get("_occ").is_some() {
        st(e, "series_id")
    } else {
        st(e, "id")
    }
}

async fn attendees_of_many(ids: &[String]) -> Vec<Value> {
    if ids.is_empty() {
        return vec![];
    }
    crate::sb_select(&format!(
        "calendar_attendees?select=*&event_id=in.({})&order=address.asc&limit=5000",
        ids.join(",")
    ))
    .await
    .ok()
    .and_then(|v| v.as_array().cloned())
    .unwrap_or_default()
}

async fn events(me: &Who, input: &Value) -> axum::response::Response {
    let (from, to) = match range_of(input) {
        Some(r) => r,
        None => return fail(StatusCode::BAD_REQUEST, "bad_range", "from/to must be a range of at most 62 days"),
    };
    let evs = match events_between(me, from, to).await {
        Ok(e) => e,
        Err(_) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Calendar failed"),
    };
    let mut ids: Vec<String> = evs.iter().map(base_id).filter(|i| cal::token_shape_ok(i)).collect();
    ids.sort();
    ids.dedup();
    let all = attendees_of_many(&ids).await;
    let spans: Vec<Interval> = evs
        .iter()
        .map(|e| Interval {
            start: cal::parse_ts(&st(e, "starts_at")).unwrap_or(0),
            end: cal::parse_ts(&st(e, "ends_at")).unwrap_or(0),
        })
        .collect();
    let clash = cal::mark_conflicts(&spans);
    let out: Vec<Value> = evs
        .iter()
        .enumerate()
        .map(|(i, e)| {
            let id = base_id(e);
            let mine: Vec<Value> = all.iter().filter(|a| st(a, "event_id") == id).cloned().collect();
            let mut j = event_json(e, &mine);
            let k = st(e, "kind");
            if let Some(o) = j.as_object_mut() {
                o.insert("conflict".to_string(), json!(clash[i]));
                if ["meeting", "focus", "hold", "personal"].contains(&k.as_str()) {
                    o.insert("kind".to_string(), json!(k));
                }
            }
            j
        })
        .collect();
    crate::ok(json!({ "events": out })).into_response()
}

async fn event_one(me: &Who, input: &Value) -> axum::response::Response {
    let id = st(input, "id");
    let ev = match load_own_event(me, &id).await {
        Ok(e) => e,
        Err(r) => return r,
    };
    let (base, occ) = recur::split_occ(&id);
    let rows = attendee_rows(base).await;
    let mut shown = ev.clone();
    if is_master(&ev) {
        if let Some(u) = occ {
            match occurrences(&ev, u, u + 1).into_iter().find(|o| cal::parse_ts(&st(o, "starts_at")) == Some(u)) {
                Some(o) => shown = o,
                None => return fail(StatusCode::GONE, "occurrence_gone", "That occurrence no longer exists"),
            }
        }
    }
    crate::ok(json!({ "event": event_json(&shown, &rows), "outcome": Value::Null, "tasks": [] })).into_response()
}

async fn team_load(me: &Who, input: &Value) -> axum::response::Response {
    let (from, to) = match range_of(input) {
        Some(r) => r,
        None => return fail(StatusCode::BAD_REQUEST, "bad_range", "from/to must be a range of at most 62 days"),
    };
    let evs = match events_between(me, from, to).await {
        Ok(e) => e,
        Err(_) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Calendar failed"),
    };
    let mut ids: Vec<String> = evs.iter().map(base_id).filter(|i| cal::token_shape_ok(i)).collect();
    ids.sort();
    ids.dedup();
    let all = attendees_of_many(&ids).await;
    // person -> their meetings (organiser + every guest who did not decline)
    let mut per: Vec<(String, Vec<Interval>)> = Vec::new();
    let mut add = |who: String, iv: Interval| {
        let who = who.trim().to_lowercase();
        if who.is_empty() {
            return;
        }
        match per.iter_mut().find(|p| p.0 == who) {
            Some(p) => p.1.push(iv),
            None => per.push((who, vec![iv])),
        }
    };
    for e in &evs {
        let iv = Interval {
            start: cal::parse_ts(&st(e, "starts_at")).unwrap_or(0),
            end: cal::parse_ts(&st(e, "ends_at")).unwrap_or(0),
        };
        add(st(e, "organiser"), iv);
        let id = base_id(e);
        for a in all.iter().filter(|a| st(a, "event_id") == id && st(a, "response") != "declined") {
            add(st(a, "address"), iv);
        }
    }
    let mut load: Vec<Value> = per
        .iter()
        .map(|(m, v)| {
            let mins = cal::minutes_in(v, from, to);
            json!({ "member": m, "display_name": Value::Null, "meeting_minutes": mins, "open_tasks": 0, "overloaded": cal::overloaded(mins, from, to) })
        })
        .collect();
    load.sort_by(|a, b| {
        let m = |v: &Value| v.get("meeting_minutes").and_then(|x| x.as_i64());
        m(b).cmp(&m(a))
    });
    crate::ok(json!({ "load": load })).into_response()
}

async fn busy_for(
    me: &Who,
    addrs: &[String],
    from: i64,
    to: i64,
) -> Result<Vec<(String, Vec<Interval>)>, String> {
    let rows = crate::sb_rpc(
        "calendar_busy",
        json!({ "p_org": me.org_id, "p_addresses": addrs, "p_from": cal::fmt_rfc3339(from), "p_to": cal::fmt_rfc3339(to) }),
    )
    .await?;
    let mut per: Vec<(String, Vec<Interval>)> = addrs.iter().map(|a| (a.clone(), vec![])).collect();
    for r in rows.as_array().cloned().unwrap_or_default() {
        let a = st(&r, "address").to_lowercase();
        if let (Some(s), Some(e)) = (
            cal::parse_ts(&st(&r, "starts_at")),
            cal::parse_ts(&st(&r, "ends_at")),
        ) {
            if let Some(slot) = per.iter_mut().find(|p| p.0 == a) {
                slot.1.push(Interval { start: s, end: e });
            }
        }
    }
    // repeating meetings: expand every master that any of these people attend (E56 not installed => nothing to add)
    if recur_ready().await {
        if let Ok(ms) = crate::sb_rpc(
            "calendar_busy_masters",
            json!({ "p_org": me.org_id, "p_addresses": addrs, "p_to": cal::fmt_rfc3339(to) }),
        )
        .await
        {
            for m in ms.as_array().cloned().unwrap_or_default() {
                let a = st(&m, "address").to_lowercase();
                if let Some(slot) = per.iter_mut().find(|p| p.0 == a) {
                    for o in occurrences(&m, from, to) {
                        if let (Some(s), Some(e)) = (cal::parse_ts(&st(&o, "starts_at")), cal::parse_ts(&st(&o, "ends_at"))) {
                            slot.1.push(Interval { start: s, end: e });
                        }
                    }
                }
            }
        }
    }
    Ok(per
        .into_iter()
        .map(|(a, v)| (a, cal::merge_intervals(v)))
        .collect())
}

async fn busy(me: &Who, input: &Value) -> axum::response::Response {
    let addrs = addresses_of(input);
    let (from, to) = match (
        cal::parse_ts(&st(input, "from")),
        cal::parse_ts(&st(input, "to")),
    ) {
        (Some(f), Some(t)) if t > f && t - f <= 31 * 86_400 => (f, t),
        _ => {
            return fail(
                StatusCode::BAD_REQUEST,
                "bad_range",
                "from/to must be a range of at most 31 days",
            )
        }
    };
    if addrs.is_empty() {
        return fail(
            StatusCode::BAD_REQUEST,
            "no_addresses",
            "Add at least one valid address",
        );
    }
    match busy_for(me, &addrs, from, to).await {
        Ok(per) => crate::ok(json!({
            "busy": per.iter().map(|(a, v)| json!({
                "address": a,
                "intervals": v.iter().map(|i| json!({ "start": cal::fmt_rfc3339(i.start), "end": cal::fmt_rfc3339(i.end) })).collect::<Vec<_>>(),
            })).collect::<Vec<_>>(),
        }))
        .into_response(),
        Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Calendar failed"),
    }
}

async fn findtime(me: &Who, input: &Value) -> axum::response::Response {
    let mut addrs = addresses_of(input);
    if addrs.is_empty() {
        return fail(
            StatusCode::BAD_REQUEST,
            "no_addresses",
            "Add at least one valid address",
        );
    }
    // the organiser is always part of the search — a time that clashes with their own day is no time at all
    if !addrs.contains(&me.email) {
        addrs.insert(0, me.email.clone());
    }
    let mut windows: Vec<Interval> = Vec::new();
    for w in input
        .get("windows")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .take(400)
    {
        if let (Some(s), Some(e)) = (
            cal::parse_ts(&st(&w, "start")),
            cal::parse_ts(&st(&w, "end")),
        ) {
            if e > s {
                windows.push(Interval { start: s, end: e });
            }
        }
    }
    if windows.is_empty() {
        return fail(
            StatusCode::BAD_REQUEST,
            "no_windows",
            "Send the hours to search (windows)",
        );
    }
    let lo = windows.iter().map(|w| w.start).min().unwrap_or(0);
    let hi = windows.iter().map(|w| w.end).max().unwrap_or(0);
    if hi - lo > 31 * 86_400 {
        return fail(
            StatusCode::BAD_REQUEST,
            "bad_range",
            "Search at most 31 days at a time",
        );
    }
    let minutes = num(input, "duration_minutes").unwrap_or(30);
    if !(5..=480).contains(&minutes) {
        return fail(
            StatusCode::BAD_REQUEST,
            "bad_duration",
            "Duration must be between 5 minutes and 8 hours",
        );
    }
    let step = num(input, "step_minutes").unwrap_or(15).clamp(5, 60) * 60;
    let buffer = num(input, "buffer_minutes").unwrap_or(0).clamp(0, 60) * 60;
    let limit = num(input, "limit").unwrap_or(40).clamp(1, 200) as usize;
    let per = match busy_for(me, &addrs, lo, hi).await {
        Ok(p) => p,
        Err(_) => {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "server_error",
                "Calendar failed",
            )
        }
    };
    let lists: Vec<Vec<Interval>> = per.iter().map(|p| p.1.clone()).collect();
    let slots = cal::common_free_slots(&lists, &windows, minutes * 60, step, buffer, limit);
    crate::ok(json!({
        "slots": slots.iter().map(|i| json!({ "start": cal::fmt_rfc3339(i.start), "end": cal::fmt_rfc3339(i.end) })).collect::<Vec<_>>(),
        "checked": addrs,
        "engine": "rust",
    }))
    .into_response()
}

/* ------------------------------------------------------- public RSVP */

pub fn public_owns(proc: &str) -> bool {
    matches!(proc, "calendar.rsvp.lookup" | "calendar.rsvp.respond")
}

pub async fn public(proc: &str, input: &Value) -> axum::response::Response {
    let token = st(input, "token").trim().to_lowercase();
    if !cal::token_shape_ok(&token) {
        return fail(
            StatusCode::NOT_FOUND,
            "not_found",
            "This invitation link is not valid.",
        );
    }
    if !v2_ready().await {
        return fail(
            StatusCode::NOT_IMPLEMENTED,
            "calendar_v2_sql_missing",
            "Calendar v2 SQL (E31) is not installed yet.",
        );
    }
    let res = if proc == "calendar.rsvp.lookup" {
        crate::sb_rpc("calendar_rsvp_lookup", json!({ "p_token": token })).await
    } else {
        let resp = match cal::rsvp_value(&st(input, "response")) {
            Some(r) => r,
            None => {
                return fail(
                    StatusCode::BAD_REQUEST,
                    "bad_response",
                    "Choose yes, maybe or no.",
                )
            }
        };
        let comment = cal::clean_line(&st(input, "comment"), 500);
        crate::sb_rpc(
            "calendar_rsvp_apply",
            json!({ "p_token": token, "p_response": resp, "p_comment": if comment.is_empty() { Value::Null } else { json!(comment) } }),
        )
        .await
    };
    match res {
        Ok(v) if v.is_null() || v.get("found").and_then(|f| f.as_bool()) == Some(false) => fail(
            StatusCode::NOT_FOUND,
            "not_found",
            "This invitation link is not valid.",
        ),
        Ok(mut v) => {
            // E77: collision warning — guest ko jawab se PEHLE dikhe "is waqt aur meeting hai" (sirf ginti + waqt, title nahi).
            // Best-effort: E77 SQL na chali ho ya fail ho to lookup jawab waisa hi, kuch tootta nahi.
            if proc == "calendar.rsvp.lookup" {
                if let Ok(c) = crate::sb_rpc("calendar_rsvp_conflicts", json!({ "p_token": token })).await {
                    if c.get("count").is_some() {
                        v["conflicts"] = c;
                    }
                }
            }
            crate::ok(v).into_response()
        }
        Err(_) => fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "server_error",
            "Calendar failed",
        ),
    }
}
