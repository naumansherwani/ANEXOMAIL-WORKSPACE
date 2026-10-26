// ============================================================================
// ANEXOMAIL — Booking page (B7c) procs (Rust PRIMARY): anexomail.com/book/<handle>.
//
// `mod book_core; mod book_glue;` main.rs mein judta hai (installer: rust-engine-install.sh, module `book`).
// Saari soch book_core.rs mein hai (std-only, unit tests). Yahan sirf I/O: Supabase REST + local Postfix :25.
// SQL: docs/cursor-work/sql/E59_booking_page.sql — wahi aakhri deewar hai (EXCLUDE constraint). Hum sirf woh slot
// dikhate hain jo free hain aur repeating meetings (jo SQL nahi dekhta) booking se pehle dobara check karte hain.
//
// Procs (login chahiye):  booking.page.get  booking.page.set  booking.page.delete  booking.list  booking.host.cancel
//   E88: ek user ke kai booking links (Basic 1 / Pro 3 / Business 20 / Business Pro unlimited). Cap DB trigger rokta hai
//   (booking_pages_cap, error booking_link_limit_reached); yahan sirf wahi error saaf zabaan mein wapas aata hai.
// Procs (public):         booking.public.page  booking.public.slots  booking.public.book
//                         booking.manage.lookup  booking.manage.cancel  booking.manage.reschedule
// Public procs IP rate-limit + honeypot; mail ka daily invite quota (host) in se kabhi kharch nahi hota.
// Graceful: E59 na lagi ho to 501 `booking_sql_missing`; kuch toot'ta nahi.
// ============================================================================

use crate::book_core::{self as c, Kind, MailIn, Params};
use crate::cal_core::{self as cal, recur, EventSpec, Guest, Interval, Method, Person};
use axum::{http::HeaderMap, http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Mutex;

static READY: AtomicBool = AtomicBool::new(false);
static MSG_SEQ: AtomicU64 = AtomicU64::new(0);
static THROTTLE: std::sync::OnceLock<Mutex<c::Throttle>> = std::sync::OnceLock::new();

const WINDOW_MS: u64 = 10 * 60 * 1000;

pub fn owns(proc: &str) -> bool {
    matches!(proc, "booking.page.get" | "booking.page.set" | "booking.page.delete" | "booking.list" | "booking.host.cancel")
}

pub fn public_owns(proc: &str) -> bool {
    matches!(
        proc,
        "booking.public.page"
            | "booking.public.slots"
            | "booking.public.book"
            | "booking.manage.lookup"
            | "booking.manage.cancel"
            | "booking.manage.reschedule"
    )
}

/* ---------------------------------------------------------------- helpers */

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
fn fail(status: StatusCode, code: &str, msg: &str) -> axum::response::Response {
    crate::err(status, code, msg).into_response()
}
fn now_epoch() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}
fn now_ms() -> u64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(0)
}
fn app_url() -> String {
    let v = crate::env_var("ANEXOMAIL_APP_URL");
    if v.starts_with("https://") {
        v.trim_end_matches('/').to_string()
    } else {
        "https://anexomail.com".to_string()
    }
}
fn client_ip(headers: &HeaderMap) -> String {
    headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.split(',').next())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "unknown".to_string())
}
fn allowed(ip: &str, purpose: &str, limit: usize) -> bool {
    let m = THROTTLE.get_or_init(|| Mutex::new(c::Throttle::default()));
    match m.lock() {
        Ok(mut t) => t.allow(&format!("{}|{}", purpose, ip), now_ms(), limit, WINDOW_MS),
        Err(_) => true,
    }
}
fn too_many() -> axum::response::Response {
    fail(StatusCode::TOO_MANY_REQUESTS, "too_many_requests", "Too many requests — please try again in a few minutes.")
}
fn uuid_shape(t: &str) -> bool {
    cal::token_shape_ok(t)
}
fn server_error() -> axum::response::Response {
    fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Booking failed — please try again.")
}

async fn ready() -> bool {
    if READY.load(Ordering::Relaxed) {
        return true;
    }
    let ok = crate::sb_select("booking_pages?select=id&limit=1").await.is_ok()
        && crate::sb_select("bookings?select=id&limit=1").await.is_ok();
    if ok {
        READY.store(true, Ordering::Relaxed);
    }
    ok
}

fn not_ready() -> axum::response::Response {
    fail(StatusCode::NOT_IMPLEMENTED, "booking_sql_missing", "Booking pages are not installed yet (SQL E59).")
}

/// SQL code -> (HTTP status, message). Messages are for visitors: short, no internals.
fn problem(code: &str) -> (StatusCode, &'static str) {
    match code {
        "taken" => (StatusCode::CONFLICT, "That time was just taken. Please pick another slot."),
        "too_soon" => (StatusCode::CONFLICT, "That time is too soon to book. Please pick a later slot."),
        "too_far" => (StatusCode::CONFLICT, "That time is too far ahead to book."),
        "outside_hours" | "out_of_office" | "bad_start" => (StatusCode::CONFLICT, "That time is not available. Please pick another slot."),
        "bad_duration" => (StatusCode::BAD_REQUEST, "That meeting length is not offered."),
        "not_enabled" | "not_found" => (StatusCode::NOT_FOUND, "This booking page is not available."),
        "too_many" => (StatusCode::TOO_MANY_REQUESTS, "You already have the maximum number of upcoming bookings with this host."),
        "busy_day" => (StatusCode::TOO_MANY_REQUESTS, "This page is fully booked for now. Please try again later."),
        "limit" => (StatusCode::CONFLICT, "This booking was already rescheduled the maximum number of times. Cancel it and book again."),
        "past" => (StatusCode::CONFLICT, "This meeting has already started."),
        "cancelled" => (StatusCode::CONFLICT, "This booking was cancelled."),
        _ => (StatusCode::BAD_REQUEST, "Please check the details and try again."),
    }
}

fn parse_week(ctx: &Value) -> c::Week {
    let mut week = c::default_week();
    if let Some(days) = ctx.get("work_hours").and_then(|w| w.get("days")).and_then(|d| d.as_array()) {
        for (i, d) in days.iter().take(7).enumerate() {
            let on = d.get("on").and_then(|x| x.as_bool()).unwrap_or(false);
            let s = d.get("start").and_then(|x| x.as_str()).and_then(c::parse_hhmm).unwrap_or(9 * 60);
            let e = d.get("end").and_then(|x| x.as_str()).and_then(c::parse_hhmm).unwrap_or(17 * 60);
            week[i] = c::Day { on, start: s, end: e };
        }
    }
    week
}

fn parse_ooo(ctx: &Value) -> Vec<(String, String)> {
    ctx.get("ooo")
        .and_then(|o| o.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|r| {
                    let (f, t) = (st(r, "from"), st(r, "to"));
                    if f.len() == 10 && t.len() == 10 {
                        Some((f, t))
                    } else {
                        None
                    }
                })
                .collect()
        })
        .unwrap_or_default()
}

fn zone(name: &str) -> std::sync::Arc<recur::Tz> {
    recur::load_tz(name, 0)
}

/// The host's busy time in [from, to): single meetings (+ repeating ones expanded). `masters_only` is for the
/// pre-booking recheck of repeating meetings, which the database does not look at.
async fn busy_for(org_id: &str, host: &str, from: i64, to: i64, masters_only: bool) -> Result<Vec<Interval>, String> {
    let mut out: Vec<Interval> = Vec::new();
    let (f, t) = (from - 86_400, to + 86_400);
    if !masters_only {
        let rows = crate::sb_rpc(
            "calendar_busy",
            json!({ "p_org": org_id, "p_addresses": [host], "p_from": cal::fmt_rfc3339(f), "p_to": cal::fmt_rfc3339(t) }),
        )
        .await?;
        for r in rows.as_array().cloned().unwrap_or_default() {
            if let (Some(s), Some(e)) = (cal::parse_ts(&st(&r, "starts_at")), cal::parse_ts(&st(&r, "ends_at"))) {
                out.push(Interval { start: s, end: e });
            }
        }
    }
    let masters = crate::sb_rpc(
        "calendar_busy_masters",
        json!({ "p_org": org_id, "p_addresses": [host], "p_to": cal::fmt_rfc3339(t) }),
    )
    .await?;
    for m in masters.as_array().cloned().unwrap_or_default() {
        let rule = match recur::parse(&st(&m, "rrule")) {
            Ok(r) => r,
            Err(_) => continue,
        };
        let (s, e) = match (cal::parse_ts(&st(&m, "starts_at")), cal::parse_ts(&st(&m, "ends_at"))) {
            (Some(s), Some(e)) => (s, e),
            _ => continue,
        };
        let dur = (e - s).max(60);
        let off = (num(&m, "tz_offset_min").unwrap_or(0).clamp(-840, 840) * 60) as i32;
        let tz = recur::load_tz(&st(&m, "tz"), off);
        let ex: Vec<i64> = m
            .get("exdates")
            .and_then(|v| v.as_array())
            .map(|a| a.iter().filter_map(|x| x.as_str().and_then(cal::parse_ts)).collect())
            .unwrap_or_default();
        for u in recur::expand(&rule, s, dur, &tz, &ex, f, t) {
            out.push(Interval { start: u, end: u + dur });
        }
    }
    Ok(cal::merge_intervals(out))
}

async fn context(handle: &str) -> Result<Option<Value>, String> {
    let v = crate::sb_rpc("booking_context", json!({ "p_handle": handle })).await?;
    if v.get("found").and_then(|f| f.as_bool()) == Some(true) {
        Ok(Some(v))
    } else {
        Ok(None)
    }
}

/// The page row regardless of `enabled` (a booking must stay manageable after the host switches the page off).
async fn page_row(handle: &str) -> Result<Option<Value>, String> {
    let h: String = handle.chars().filter(|ch| ch.is_ascii_alphanumeric() || *ch == '-').collect();
    if h.is_empty() {
        return Ok(None);
    }
    let rows = crate::sb_select(&format!("booking_pages?select=*&handle=eq.{}&limit=1", h.to_lowercase())).await?;
    Ok(rows.as_array().and_then(|a| a.first().cloned()))
}

fn dur_list(v: &Value) -> Vec<i64> {
    v.get("durations").and_then(|d| d.as_array()).map(|a| a.iter().filter_map(|x| x.as_i64()).collect()).unwrap_or_default()
}

/* ------------------------------------------------------------------- mail */

struct Booked {
    event_id: String,
    token: String,
    starts: i64,
    ends: i64,
    visitor_name: String,
    visitor_email: String,
    visitor_tz: Option<String>,
    note: Option<String>,
    sequence: u32,
}

fn message_id(seed: &str) -> String {
    let n = MSG_SEQ.fetch_add(1, Ordering::Relaxed);
    let nanos = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    let short: String = seed.chars().filter(|ch| ch.is_ascii_alphanumeric()).take(8).collect();
    format!("axb.{}.{}.{}@{}", short, nanos, n, cal::DOMAIN)
}

/// Confirmation / move / cancel mail to the visitor (with .ics) and a plain notice to the host. Never fails the booking:
/// returns whether the VISITOR mail was accepted by the local mail server.
async fn notify(kind: Kind, page: &Value, b: &Booked) -> bool {
    let host = st(page, "host_email").to_lowercase();
    let host_name = opt(page, "host_name");
    let title = cal::clean_line(&st(page, "title"), 120);
    let page_tz = st(page, "timezone");
    let ptz = zone(&page_tz);
    let (vz_name, vtz) = match b.visitor_tz.as_deref().filter(|z| c::tz_known(z)) {
        Some(z) => (z.to_string(), zone(z)),
        None => (page_tz.clone(), ptz.clone()),
    };
    let base = app_url();
    let manage = format!("{}/book/manage?t={}", base, b.token);
    let rebook = format!("{}/book/{}", base, st(page, "handle"));
    let location = opt(page, "location");
    let method = if kind == Kind::Cancelled { Method::Cancel } else { Method::Request };
    let spec = EventSpec {
        id: b.event_id.clone(),
        sequence: b.sequence,
        title: title.clone(),
        agenda: b.note.clone(),
        starts: b.starts,
        ends: b.ends,
        location: location.clone(),
        organiser: Person { address: host.clone(), name: host_name.clone() },
        guests: vec![Guest {
            address: b.visitor_email.clone(),
            name: Some(b.visitor_name.clone()),
            optional: false,
            response: "accepted".to_string(),
        }],
        now: now_epoch(),
        rrule: None,
        exdates: vec![],
        recurrence_id: None,
        tz: None,
    };
    let ics = cal::build_ics(method, &spec, &manage);
    let hn = host_name.clone().unwrap_or_else(|| host.clone());

    let vlabel = c::when_label(b.starts, b.ends, &vz_name, &vtz);
    let vmid = message_id(&b.event_id);
    let (vsubject, vraw) = c::build_mail(&MailIn {
        kind,
        from_address: &host,
        from_name: host_name.as_deref(),
        to_address: &b.visitor_email,
        to_name: Some(&b.visitor_name),
        title: &title,
        host_name: &hn,
        visitor_name: &b.visitor_name,
        when_label: &vlabel,
        location: location.as_deref(),
        note: b.note.as_deref(),
        manage_url: Some(&manage),
        rebook_url: Some(&rebook),
        ics: Some(&ics),
        message_id: &vmid,
        now: now_epoch(),
    });
    let vres = crate::cal_glue::smtp_send(&host, &b.visitor_email, &vraw).await;
    record(&host, &b.visitor_email, &vsubject, &vmid, &vres).await;

    let hlabel = c::when_label(b.starts, b.ends, &page_tz, &ptz);
    let hmid = message_id(&b.token);
    let (hsubject, hraw) = c::build_mail(&MailIn {
        kind,
        from_address: &host,
        from_name: Some("ANEXOMAIL Booking"),
        to_address: &host,
        to_name: host_name.as_deref(),
        title: &title,
        host_name: &hn,
        visitor_name: &format!("{} ({})", cal::clean_line(&b.visitor_name, 80), b.visitor_email),
        when_label: &hlabel,
        location: location.as_deref(),
        note: b.note.as_deref(),
        manage_url: None,
        rebook_url: None,
        ics: None,
        message_id: &hmid,
        now: now_epoch(),
    });
    let hres = crate::cal_glue::smtp_send(&host, &host, &hraw).await;
    record(&host, &host, &hsubject, &hmid, &hres).await;
    vres.is_ok()
}

async fn record(from: &str, to: &str, subject: &str, mid: &str, res: &Result<String, String>) {
    let (ok_flag, text, error) = match res {
        Ok(t) => (true, t.clone(), String::new()),
        Err(e) => (false, String::new(), e.clone()),
    };
    let _ = crate::sb_rpc(
        "mail_outbox_record",
        json!({ "payload": {
            "from_address": from, "to": [to], "subject": subject, "message_id": mid,
            "smtp_response": text, "ok": ok_flag, "error": if ok_flag { Value::Null } else { json!(error) },
        }}),
    )
    .await;
}

/* ------------------------------------------------- authenticated (host) */

struct Who {
    id: String,
    email: String,
    org_id: String,
}

async fn who(token: &str, input: &Value) -> Result<Who, axum::response::Response> {
    match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(me) => Ok(Who { id: me.id, email: me.email.trim().to_lowercase(), org_id: me.org_id }),
        Err((StatusCode::CONFLICT, _, _)) => Err(fail(
            StatusCode::NOT_IMPLEMENTED,
            "not_implemented_for_account",
            "Booking pages need a workspace mailbox.",
        )),
        Err((status, code, detail)) => Err(fail(status, code, &detail)),
    }
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    let me = match who(token, input).await {
        Ok(m) => m,
        Err(r) => return r,
    };
    if !ready().await {
        return not_ready();
    }
    match proc {
        "booking.page.get" => page_get(&me).await,
        "booking.page.set" => page_set(&me, input).await,
        "booking.page.delete" => page_delete(&me, input).await,
        "booking.list" => list(&me).await,
        "booking.host.cancel" => host_cancel(&me, input).await,
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    }
}

/// Saare pages is user ke, sab se purana pehle (primary = pehla).
async fn my_pages(me: &Who) -> Result<Vec<Value>, String> {
    let rows = crate::sb_select(&format!("booking_pages?select=*&user_id=eq.{}&order=created_at.asc,id.asc&limit=50", me.id)).await?;
    Ok(rows.as_array().cloned().unwrap_or_default())
}

/// Primary page (purana ek-page contract; page_id na dene wale purane clients isi par chalte hain).
async fn my_page(me: &Who) -> Result<Option<Value>, String> {
    Ok(my_pages(me).await?.into_iter().next())
}

/// (limit, plan) — `limit` None = unlimited. DB ki chat_phase_entitlements 'booking_links' se (E88). Fail ho to None, None (cap DB phir bhi rokta hai).
async fn links_cap(me: &Who) -> (Option<i64>, Option<String>) {
    match crate::sb_rpc("chat_feature_allowed", json!({ "_user": me.id, "_feature": "booking_links" })).await {
        Ok(v) => (
            v.get("limit").and_then(|x| x.as_i64()),
            v.get("plan").and_then(|x| x.as_str()).map(|x| x.to_string()),
        ),
        Err(_) => (None, None),
    }
}

async fn page_get(me: &Who) -> axum::response::Response {
    match my_pages(me).await {
        Ok(pages) => {
            let (limit, plan) = links_cap(me).await;
            crate::ok(json!({
                "page": pages.first().cloned(),
                "pages": pages,
                "links_used": pages.len(),
                "links_limit": limit,
                "plan": plan,
                "suggested_handle": c::suggest_handle(&me.email), "host_email": me.email, "app_url": app_url(),
            }))
            .into_response()
        }
        Err(_) => server_error(),
    }
}

async fn page_set(me: &Who, input: &Value) -> axum::response::Response {
    let bad = |m: &str| fail(StatusCode::BAD_REQUEST, "bad_input", m);
    let handle = st(input, "handle").trim().to_lowercase();
    if !c::handle_ok(&handle) {
        return fail(
            StatusCode::BAD_REQUEST,
            "bad_handle",
            "Use 3-30 letters, numbers or single hyphens (not at the start or end). Some words are reserved.",
        );
    }
    let title = cal::clean_line(&st(input, "title"), 100);
    if title.chars().count() < 2 {
        return bad("Give the page a title.");
    }
    let description = cal::clean_line(&st(input, "description"), 500);
    let durations: Vec<i64> = input
        .get("durations")
        .and_then(|d| d.as_array())
        .map(|a| a.iter().filter_map(|x| x.as_i64()).collect())
        .unwrap_or_default();
    if !c::durations_ok(&durations) {
        return bad("Choose 1-5 different meeting lengths between 5 minutes and 8 hours.");
    }
    let buffer = num(input, "buffer_min").unwrap_or(0);
    let notice = num(input, "min_notice_min").unwrap_or(240);
    let max_days = num(input, "max_days").unwrap_or(30);
    if !(0..=120).contains(&buffer) || !(0..=20_160).contains(&notice) || !(1..=365).contains(&max_days) {
        return bad("Buffer, notice or booking window is out of range.");
    }
    let tz = st(input, "timezone");
    if !c::tz_known(&tz) {
        return bad("Unknown time zone.");
    }
    let location = cal::clean_line(&st(input, "location"), 200);
    let key = opt(input, "calendar_key").filter(|k| {
        k.len() <= 40 && k.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_' || b == b'-')
    });
    let host_name = cal::clean_line(&st(input, "host_name"), 80);
    let enabled = input.get("enabled").and_then(|e| e.as_bool()).unwrap_or(false);

    // E88: kaun sa page? page_id diya => wahi (mera hona zaruri); new:true => naya link; kuch nahi => purana behaviour (primary).
    let mine = match my_pages(me).await {
        Ok(p) => p,
        Err(_) => return server_error(),
    };
    let want_id = st(input, "page_id");
    let make_new = input.get("new").and_then(|n| n.as_bool()).unwrap_or(false);
    let existing: Option<Value> = if !want_id.is_empty() {
        match mine.iter().find(|p| st(p, "id") == want_id) {
            Some(p) => Some(p.clone()),
            None => return fail(StatusCode::NOT_FOUND, "not_found", "Unknown booking link."),
        }
    } else if make_new {
        None
    } else {
        mine.first().cloned()
    };
    if existing.is_none() {
        let (limit, plan) = links_cap(me).await;
        if let Some(l) = limit {
            if (mine.len() as i64) >= l {
                return link_limit(plan.as_deref(), l);
            }
        }
    }
    // handle must be free (case-insensitive) unless it is THIS page
    match crate::sb_select(&format!("booking_pages?select=id&handle=eq.{}&limit=1", handle)).await {
        Ok(r) => {
            if let Some(o) = r.as_array().and_then(|a| a.first()) {
                let same = existing.as_ref().map(|e| st(e, "id") == st(o, "id")).unwrap_or(false);
                if !same {
                    return fail(StatusCode::CONFLICT, "handle_taken", "That page name is already taken. Try another.");
                }
            }
        }
        Err(_) => return server_error(),
    }
    let row = json!({
        "handle": handle, "title": title,
        "description": if description.is_empty() { Value::Null } else { json!(description) },
        "durations": durations, "buffer_min": buffer, "min_notice_min": notice, "max_days": max_days,
        "timezone": tz,
        "location": if location.is_empty() { Value::Null } else { json!(location) },
        "calendar_key": key, "enabled": enabled,
        "host_name": if host_name.is_empty() { Value::Null } else { json!(host_name) },
        "host_email": me.email,
    });
    let res = if let Some(e) = &existing {
        crate::sb_patch(&format!("booking_pages?id=eq.{}&user_id=eq.{}", st(e, "id"), me.id), row.clone()).await.map(|_| ())
    } else {
        let mut r = row.clone();
        if let Some(o) = r.as_object_mut() {
            o.insert("user_id".into(), json!(me.id));
            o.insert("org_id".into(), json!(me.org_id));
        }
        crate::sb_insert("booking_pages", r).await.map(|_| ())
    };
    match res {
        Ok(()) => page_get(me).await,
        Err(e) => {
            if e.contains("booking_link_limit_reached") {
                let (limit, plan) = links_cap(me).await;
                link_limit(plan.as_deref(), limit.unwrap_or(1))
            } else if e.contains("23505") || e.contains("duplicate") {
                fail(StatusCode::CONFLICT, "handle_taken", "That page name is already taken. Try another.")
            } else if e.contains("23514") || e.contains("check") {
                bad("Some settings are not allowed. Please check them.")
            } else {
                server_error()
            }
        }
    }
}

async fn list(me: &Who) -> axum::response::Response {
    let ids: Vec<String> = match my_pages(me).await {
        Ok(p) => p.iter().map(|x| st(x, "id")).filter(|i| uuid_shape(i)).collect(),
        Err(_) => return server_error(),
    };
    if ids.is_empty() {
        return crate::ok(json!({ "bookings": [] })).into_response();
    }
    match crate::sb_select(&format!(
        "bookings?select=id,page_id,starts_at,ends_at,visitor_name,visitor_email,visitor_tz,note,status,reschedules,created_at&page_id=in.({})&order=starts_at.desc&limit=200",
        ids.join(",")
    ))
    .await
    {
        Ok(r) => crate::ok(json!({ "bookings": r })).into_response(),
        Err(_) => server_error(),
    }
}

/// Plan ka cap poora ho chuka — saaf paigham (UI isi code par Upgrade dikhata hai).
fn link_limit(plan: Option<&str>, limit: i64) -> axum::response::Response {
    let who = plan.unwrap_or("your");
    fail(
        StatusCode::FORBIDDEN,
        "link_limit_reached",
        &format!("Your {who} plan includes {limit} public booking link{}. Upgrade for more.", if limit == 1 { "" } else { "s" }),
    )
}

/// Ek link hatao. Aane wali confirmed booking ho to NAHI (pehle cancel karo) — visitor ka link toot'ta nahi.
async fn page_delete(me: &Who, input: &Value) -> axum::response::Response {
    let id = st(input, "page_id");
    if !uuid_shape(&id) {
        return fail(StatusCode::BAD_REQUEST, "bad_input", "Unknown booking link.");
    }
    let mine = match my_pages(me).await {
        Ok(p) => p,
        Err(_) => return server_error(),
    };
    if !mine.iter().any(|p| st(p, "id") == id) {
        return fail(StatusCode::NOT_FOUND, "not_found", "Unknown booking link.");
    }
    let now = c::rfc3339_utc(std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0) as i64);
    let upcoming = crate::sb_count(&format!("bookings?select=id&page_id=eq.{id}&status=eq.confirmed&ends_at=gt.{now}")).await;
    match upcoming {
        Ok(n) if n > 0 => {
            return fail(StatusCode::CONFLICT, "has_bookings", "This link has upcoming bookings. Cancel them first.");
        }
        Ok(_) => {}
        Err(_) => return server_error(),
    }
    let (url, key) = match crate::sb() {
        Some(x) => x,
        None => return server_error(),
    };
    let res = crate::http()
        .delete(format!("{url}/rest/v1/booking_pages?id=eq.{id}&user_id=eq.{}", me.id))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await;
    match res {
        Ok(r) if r.status().is_success() => page_get(me).await,
        _ => server_error(),
    }
}

async fn host_cancel(me: &Who, input: &Value) -> axum::response::Response {
    let id = st(input, "booking_id");
    if !uuid_shape(&id) {
        return fail(StatusCode::BAD_REQUEST, "bad_input", "Unknown booking.");
    }
    let pages = match my_pages(me).await {
        Ok(p) if !p.is_empty() => p,
        Ok(_) => return fail(StatusCode::NOT_FOUND, "not_found", "No booking page."),
        Err(_) => return server_error(),
    };
    let ids: Vec<String> = pages.iter().map(|x| st(x, "id")).filter(|i| uuid_shape(i)).collect();
    let rows = match crate::sb_select(&format!(
        "bookings?select=token,page_id&id=eq.{}&page_id=in.({})&limit=1",
        id,
        ids.join(",")
    ))
    .await
    {
        Ok(r) => r,
        Err(_) => return server_error(),
    };
    let row = match rows.as_array().and_then(|a| a.first()) {
        Some(r) => r.clone(),
        None => return fail(StatusCode::NOT_FOUND, "not_found", "Unknown booking."),
    };
    let token = st(&row, "token");
    if !uuid_shape(&token) {
        return fail(StatusCode::NOT_FOUND, "not_found", "Unknown booking.");
    }
    let page = pages.iter().find(|p| st(p, "id") == st(&row, "page_id")).cloned().unwrap_or_else(|| pages[0].clone());
    cancel_by_token(&token, &page).await
}

/* ----------------------------------------------------------------- public */

pub async fn public(proc: &str, input: &Value, headers: &HeaderMap) -> axum::response::Response {
    let ip = client_ip(headers);
    let (purpose, limit) = match proc {
        "booking.public.book" => ("book", 6),
        "booking.manage.cancel" | "booking.manage.reschedule" => ("change", 12),
        "booking.manage.lookup" => ("look", 40),
        _ => ("read", 120),
    };
    if !allowed(&ip, purpose, limit) {
        return too_many();
    }
    if !ready().await {
        return not_ready();
    }
    match proc {
        "booking.public.page" => public_page(input).await,
        "booking.public.slots" => public_slots(input).await,
        "booking.public.book" => public_book(input).await,
        "booking.manage.lookup" => manage_lookup(input).await,
        "booking.manage.cancel" => manage_cancel(input).await,
        _ => manage_reschedule(input).await,
    }
}

fn not_found() -> axum::response::Response {
    fail(StatusCode::NOT_FOUND, "not_found", "This booking page is not available.")
}

async fn public_page(input: &Value) -> axum::response::Response {
    let handle = st(input, "handle").trim().to_lowercase();
    if !c::handle_ok(&handle) {
        return not_found();
    }
    match context(&handle).await {
        Ok(Some(p)) => crate::ok(json!({
            "handle": st(&p, "handle"), "host_name": p.get("host_name"), "title": st(&p, "title"),
            "description": p.get("description"), "durations": p.get("durations"), "timezone": st(&p, "timezone"),
            "location": p.get("location"), "min_notice_min": p.get("min_notice_min"), "max_days": p.get("max_days"),
        }))
        .into_response(),
        Ok(None) => not_found(),
        Err(_) => server_error(),
    }
}

async fn public_slots(input: &Value) -> axum::response::Response {
    let handle = st(input, "handle").trim().to_lowercase();
    if !c::handle_ok(&handle) {
        return not_found();
    }
    let ctx = match context(&handle).await {
        Ok(Some(p)) => p,
        Ok(None) => return not_found(),
        Err(_) => return server_error(),
    };
    let durations = dur_list(&ctx);
    let minutes = num(input, "minutes").unwrap_or_else(|| durations.first().copied().unwrap_or(30));
    if !durations.contains(&minutes) {
        return fail(StatusCode::BAD_REQUEST, "bad_duration", "That meeting length is not offered.");
    }
    let now = now_epoch();
    let from = cal::parse_ts(&st(input, "from")).unwrap_or(now).max(now);
    let days = num(input, "days").unwrap_or(14).clamp(1, c::MAX_WINDOW_DAYS);
    let to = from + days * 86_400;
    let tzname = st(&ctx, "timezone");
    let tz = zone(&tzname);
    let buffer = num(&ctx, "buffer_min").unwrap_or(0);
    let busy = match busy_for(&st(&ctx, "org_id"), &st(&ctx, "host_email").to_lowercase(), from - buffer * 60, to + buffer * 60, false).await {
        Ok(b) => b,
        Err(_) => return server_error(),
    };
    let ooo = parse_ooo(&ctx);
    let p = Params {
        tz: &tz,
        week: parse_week(&ctx),
        ooo: &ooo,
        minutes,
        buffer_min: buffer,
        min_notice_min: num(&ctx, "min_notice_min").unwrap_or(240),
        max_days: num(&ctx, "max_days").unwrap_or(30),
        now,
    };
    let s: Vec<String> = c::slots(&p, from, to, &busy).into_iter().take(2_000).map(cal::fmt_rfc3339).collect();
    crate::ok(json!({
        "slots": s, "minutes": minutes, "timezone": tzname, "now": cal::fmt_rfc3339(now),
        "from": cal::fmt_rfc3339(from), "to": cal::fmt_rfc3339(to),
    }))
    .into_response()
}

fn booked_from(v: &Value, name: &str, email: &str, tz: Option<String>, note: Option<String>) -> Option<Booked> {
    Some(Booked {
        event_id: st(v, "event_id"),
        token: st(v, "token"),
        starts: cal::parse_ts(&st(v, "starts_at"))?,
        ends: cal::parse_ts(&st(v, "ends_at"))?,
        visitor_name: name.to_string(),
        visitor_email: email.to_string(),
        visitor_tz: tz,
        note,
        sequence: num(v, "sequence").unwrap_or(0).max(0) as u32,
    })
}

async fn public_book(input: &Value) -> axum::response::Response {
    // honeypot: real people never see the `website` field
    if !st(input, "website").trim().is_empty() {
        return fail(StatusCode::BAD_REQUEST, "bad_input", "Please check the details and try again.");
    }
    let handle = st(input, "handle").trim().to_lowercase();
    let name = cal::clean_line(&st(input, "name"), 80);
    let email = st(input, "email").trim().to_lowercase();
    let note = opt(input, "note").map(|n| n.trim().chars().take(1000).collect::<String>()).filter(|n| !n.is_empty());
    let vtz = opt(input, "tz").filter(|z| c::tz_shape_ok(z));
    let minutes = num(input, "minutes").unwrap_or(0);
    let start = cal::parse_ts(&st(input, "start"));
    if !c::handle_ok(&handle) || name.is_empty() || !cal::valid_email(&email) || email.len() > 254 || start.is_none() {
        return fail(StatusCode::BAD_REQUEST, "bad_input", "Please enter your name, a valid e-mail and pick a time.");
    }
    let start = start.unwrap_or(0);
    let page = match page_row(&handle).await {
        Ok(Some(p)) if p.get("enabled").and_then(|e| e.as_bool()) == Some(true) => p,
        Ok(_) => return not_found(),
        Err(_) => return server_error(),
    };
    if !dur_list(&page).contains(&minutes) {
        return fail(StatusCode::BAD_REQUEST, "bad_duration", "That meeting length is not offered.");
    }
    // repeating meetings are invisible to the database check: look at them here, with the buffer, before booking
    let buffer = num(&page, "buffer_min").unwrap_or(0);
    let end = start + minutes * 60;
    match busy_for(&st(&page, "org_id"), &st(&page, "host_email").to_lowercase(), start - buffer * 60, end + buffer * 60, true).await {
        Ok(b) => {
            if c::clashes(&b, start, end, buffer) {
                let (s, m) = problem("taken");
                return fail(s, "taken", m);
            }
        }
        Err(_) => return server_error(),
    }
    let res = crate::sb_rpc(
        "booking_book",
        json!({
            "p_handle": handle, "p_start": cal::fmt_rfc3339(start), "p_minutes": minutes, "p_name": name,
            "p_email": email, "p_tz": vtz, "p_note": note,
        }),
    )
    .await;
    let v = match res {
        Ok(v) => v,
        Err(_) => return server_error(),
    };
    if v.get("ok").and_then(|o| o.as_bool()) != Some(true) {
        let code = st(&v, "code");
        let (s, m) = problem(&code);
        return fail(s, if code.is_empty() { "bad_input" } else { &code }, m);
    }
    let b = match booked_from(&v, &name, &email, vtz.clone(), note.clone()) {
        Some(b) => b,
        None => return server_error(),
    };
    let mail_sent = notify(Kind::Confirmed, &page, &b).await;
    crate::ok(json!({
        "booked": true, "token": b.token, "starts_at": cal::fmt_rfc3339(b.starts), "ends_at": cal::fmt_rfc3339(b.ends),
        "title": st(&page, "title"), "host_name": page.get("host_name"), "location": page.get("location"),
        "timezone": st(&page, "timezone"), "manage_url": format!("{}/book/manage?t={}", app_url(), b.token),
        "mail_sent": mail_sent,
    }))
    .into_response()
}

async fn manage_info(token: &str) -> Result<Option<Value>, String> {
    let v = crate::sb_rpc("booking_manage", json!({ "p_token": token })).await?;
    if v.get("found").and_then(|f| f.as_bool()) == Some(true) {
        Ok(Some(v))
    } else {
        Ok(None)
    }
}

fn token_of(input: &Value) -> Option<String> {
    let t = st(input, "token").trim().to_lowercase();
    if uuid_shape(&t) {
        Some(t)
    } else {
        None
    }
}

fn link_gone() -> axum::response::Response {
    fail(StatusCode::NOT_FOUND, "not_found", "This booking link is not valid.")
}

async fn manage_lookup(input: &Value) -> axum::response::Response {
    let token = match token_of(input) {
        Some(t) => t,
        None => return link_gone(),
    };
    match manage_info(&token).await {
        Ok(Some(m)) => crate::ok(json!({
            "status": m.get("status"), "starts_at": m.get("starts_at"), "ends_at": m.get("ends_at"),
            "visitor_name": m.get("visitor_name"), "visitor_tz": m.get("visitor_tz"), "reschedules": m.get("reschedules"),
            "can_change": m.get("can_change"), "handle": m.get("handle"), "title": m.get("title"),
            "host_name": m.get("host_name"), "location": m.get("location"), "timezone": m.get("timezone"),
            "minutes": m.get("minutes"), "enabled": m.get("enabled"),
        }))
        .into_response(),
        Ok(None) => link_gone(),
        Err(_) => server_error(),
    }
}

async fn booked_of_manage(m: &Value, token: &str, sequence: u32) -> Option<Booked> {
    Some(Booked {
        event_id: st(m, "event_id"),
        token: token.to_string(),
        starts: cal::parse_ts(&st(m, "starts_at"))?,
        ends: cal::parse_ts(&st(m, "ends_at"))?,
        visitor_name: st(m, "visitor_name"),
        visitor_email: st(m, "visitor_email").to_lowercase(),
        visitor_tz: opt(m, "visitor_tz"),
        note: None,
        sequence,
    })
}

/// Shared by visitor-cancel and host-cancel: SQL cancel (event is cancelled too), then CANCEL mails.
async fn cancel_by_token(token: &str, page_hint: &Value) -> axum::response::Response {
    let info = match manage_info(token).await {
        Ok(Some(m)) => m,
        Ok(None) => return link_gone(),
        Err(_) => return server_error(),
    };
    let res = match crate::sb_rpc("booking_cancel", json!({ "p_token": token })).await {
        Ok(v) => v,
        Err(_) => return server_error(),
    };
    if res.get("ok").and_then(|o| o.as_bool()) != Some(true) {
        let code = st(&res, "code");
        let (s, m) = problem(&code);
        return fail(s, if code.is_empty() { "bad_input" } else { &code }, m);
    }
    let already = res.get("already").and_then(|a| a.as_bool()).unwrap_or(false);
    if !already {
        let page = if page_hint.is_null() || page_hint.get("handle").is_none() {
            page_row(&st(&info, "handle")).await.ok().flatten()
        } else {
            Some(page_hint.clone())
        };
        if let (Some(page), Some(b)) = (page, booked_of_manage(&info, token, num(&res, "sequence").unwrap_or(1).max(1) as u32).await) {
            let _ = notify(Kind::Cancelled, &page, &b).await;
        }
    }
    crate::ok(json!({ "cancelled": true, "already": already })).into_response()
}

async fn manage_cancel(input: &Value) -> axum::response::Response {
    match token_of(input) {
        Some(t) => cancel_by_token(&t, &Value::Null).await,
        None => link_gone(),
    }
}

async fn manage_reschedule(input: &Value) -> axum::response::Response {
    let token = match token_of(input) {
        Some(t) => t,
        None => return link_gone(),
    };
    let start = match cal::parse_ts(&st(input, "start")) {
        Some(s) => s,
        None => return fail(StatusCode::BAD_REQUEST, "bad_input", "Pick a new time."),
    };
    let info = match manage_info(&token).await {
        Ok(Some(m)) => m,
        Ok(None) => return link_gone(),
        Err(_) => return server_error(),
    };
    let page = match page_row(&st(&info, "handle")).await {
        Ok(Some(p)) => p,
        Ok(None) => return not_found(),
        Err(_) => return server_error(),
    };
    let minutes = num(&info, "minutes").unwrap_or(30);
    let buffer = num(&page, "buffer_min").unwrap_or(0);
    let end = start + minutes * 60;
    match busy_for(&st(&page, "org_id"), &st(&page, "host_email").to_lowercase(), start - buffer * 60, end + buffer * 60, true).await {
        Ok(b) => {
            if c::clashes(&b, start, end, buffer) {
                let (s, m) = problem("taken");
                return fail(s, "taken", m);
            }
        }
        Err(_) => return server_error(),
    }
    let v = match crate::sb_rpc("booking_reschedule", json!({ "p_token": token, "p_start": cal::fmt_rfc3339(start) })).await {
        Ok(v) => v,
        Err(_) => return server_error(),
    };
    if v.get("ok").and_then(|o| o.as_bool()) != Some(true) {
        let code = st(&v, "code");
        let (s, m) = problem(&code);
        return fail(s, if code.is_empty() { "bad_input" } else { &code }, m);
    }
    let mut moved = info.clone();
    if let Some(o) = moved.as_object_mut() {
        o.insert("starts_at".into(), v.get("starts_at").cloned().unwrap_or(Value::Null));
        o.insert("ends_at".into(), v.get("ends_at").cloned().unwrap_or(Value::Null));
    }
    let mail_sent = match booked_of_manage(&moved, &token, num(&v, "sequence").unwrap_or(1).max(1) as u32).await {
        Some(b) => notify(Kind::Rescheduled, &page, &b).await,
        None => false,
    };
    crate::ok(json!({
        "rescheduled": true, "starts_at": cal::fmt_rfc3339(start), "ends_at": cal::fmt_rfc3339(end), "mail_sent": mail_sent,
    }))
    .into_response()
}
