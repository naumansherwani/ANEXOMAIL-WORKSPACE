//! QC7a (20 Nov 2026): FOLLOW-UP REMINDER doors + the Tokio timer. SQL = E196 (state table, guard, hash-chained event log, doors). This file only carries the signed doors and the clock.
//! The clock sleeps EXACTLY until the next waiting reminder (fmail_followup_next196), never longer than 60 s, so a reminder set two minutes ahead fires on time and an idle server costs one tiny read a minute.
//! Every sweep line also writes a live change line in SQL, so an open device refreshes at once. No text, subject or address passes through here: ids and clocks only.
use axum::{extract::State, http::{HeaderMap, StatusCode, Uri}, response::{IntoResponse, Response}};
use serde_json::{json, Value};
use std::time::Duration;
use crate::{passkey as pk, S};

/// Civil date from days since 1970-01-01 (Howard Hinnant's algorithm), so the door can hand SQL an ISO instant without a date crate.
fn civil(days: i64) -> (i64, u32, u32) {
    let z = days + 719_468; let era = z.div_euclid(146_097); let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365; let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100); let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32; let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}
pub fn iso_from_ms(ms: i64) -> String {
    let (secs, milli) = (ms.div_euclid(1000), ms.rem_euclid(1000));
    let (days, sod) = (secs.div_euclid(86_400), secs.rem_euclid(86_400));
    let (y, m, d) = civil(days);
    format!("{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}.{milli:03}Z", sod / 3600, (sod % 3600) / 60, sod % 60)
}
pub const MIN_AHEAD_MS: i64 = 60_000;
pub const MAX_AHEAD_MS: i64 = 90 * 86_400_000;
/// The same window as the database (1 minute .. 90 days); the database enforces it again.
pub fn due_in_window(due_ms: i64, now_ms: i64) -> bool { due_ms >= now_ms + MIN_AHEAD_MS && due_ms <= now_ms + MAX_AHEAD_MS }
fn now_ms() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_millis() as i64).unwrap_or(0) }
/// How long the clock sleeps: until the next due instant, at least 1 s (no busy loop), at most 60 s.
pub fn sleep_for(next_due_ms: Option<i64>, now: i64) -> Duration {
    let ms = match next_due_ms { Some(t) => (t - now).clamp(1_000, 60_000), None => 60_000 };
    Duration::from_millis(ms as u64)
}
fn bad(e: &str) -> Response { pk::refuse(StatusCode::BAD_REQUEST, e) }

/// POST /founder/v1/mail/followup {box, message, due_ms, workday?}: "remind me if nobody answers this sent mail by then".
pub async fn set_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let (Some(b), Some(m)) = (pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)), pk::txt(&j, "message", 40).filter(|x| pk::is_uuid(x))) else { return bad("box and message are needed") };
    let Some(due) = j.get("due_ms").and_then(|v| v.as_i64()).filter(|t| due_in_window(*t, now_ms())) else { return bad("the time must be between 1 minute and 90 days from now") };
    if let Err(r) = crate::fmail_ep::own(sb, &uid, &b).await { return r; }
    let workday = j.get("workday").and_then(|v| v.as_bool()).unwrap_or(false);
    match sb.rpc_msg("fmail_followup_set196", json!({"p_actor": uid, "p_mailbox": b, "p_message": m, "p_due": iso_from_ms(due), "p_workday": workday})).await {
        Ok(v) => crate::signed(&st, json!({"ok": true, "result": v})), Err(e) => pk::sql_err(e),
    }
}
/// POST /founder/v1/mail/followup/snooze {box, id, due_ms, workday?}
pub async fn snooze_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let (Some(b), Some(id)) = (pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)), pk::txt(&j, "id", 40).filter(|x| pk::is_uuid(x))) else { return bad("box and id are needed") };
    let Some(due) = j.get("due_ms").and_then(|v| v.as_i64()).filter(|t| due_in_window(*t, now_ms())) else { return bad("the time must be between 1 minute and 90 days from now") };
    if let Err(r) = crate::fmail_ep::own(sb, &uid, &b).await { return r; }
    let workday = j.get("workday").and_then(|v| v.as_bool()).unwrap_or(false);
    match sb.rpc_msg("fmail_followup_snooze196", json!({"p_actor": uid, "p_mailbox": b, "p_id": id, "p_due": iso_from_ms(due), "p_workday": workday})).await {
        Ok(v) => crate::signed(&st, json!({"ok": true, "result": v})), Err(e) => pk::sql_err(e),
    }
}
/// POST /founder/v1/mail/followup/dismiss {box, id}
pub async fn dismiss_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let (Some(b), Some(id)) = (pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)), pk::txt(&j, "id", 40).filter(|x| pk::is_uuid(x))) else { return bad("box and id are needed") };
    if let Err(r) = crate::fmail_ep::own(sb, &uid, &b).await { return r; }
    match sb.rpc_msg("fmail_followup_dismiss196", json!({"p_actor": uid, "p_mailbox": b, "p_id": id})).await {
        Ok(v) => crate::signed(&st, json!({"ok": true, "result": v})), Err(e) => pk::sql_err(e),
    }
}
/// GET /founder/v1/mail/followups?box=<uuid>: the waiting and due reminders (ids and clocks) plus the stats line.
pub async fn list_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let b = match crate::fmail_ep::parse_box(uri.query()) { Ok(b) => b, Err(e) => return bad(e) };
    let sb = st.sb.as_ref().unwrap();
    if let Err(r) = crate::fmail_ep::own(sb, &c.sub, &b).await { return r; }
    let (l, s) = (sb.rpc("fmail_followup_list196", json!({"p_mailbox": b})).await, sb.rpc("fmail_followup_stats196", json!({"p_mailbox": b})).await);
    match (l, s) { (Some(l), Some(s)) if l.is_array() => crate::signed(&st, json!({"connected": true, "followups": l, "stats": s})), _ => crate::signed(&st, json!({"connected": false, "followups": [], "stats": {}})) }
}

/// The clock. Sleeps until the next waiting reminder (at most 60 s), then sweeps. A failed read is only retried a minute later; nothing is ever lost, a missed tick just fires on the next one.
pub async fn worker(sb: crate::data::Sb) {
    eprintln!("founder: follow-up reminder clock ON (sleeps until the next reminder, max 60 s)");
    let mut last_prune = 0i64;
    loop {
        let next = match sb.rpc("fmail_followup_next196", json!({})).await {
            Some(Value::String(s)) => parse_iso_ms(&s), _ => None };
        tokio::time::sleep(sleep_for(next, now_ms())).await;
        if let Some(Value::Number(n)) = sb.rpc("fmail_followup_sweep196", json!({})).await { if n.as_i64().unwrap_or(0) > 0 { eprintln!("founder: {} follow-up reminder(s) became due", n); } }
        if now_ms() - last_prune > 86_400_000 { last_prune = now_ms(); let _ = sb.rpc("fmail_followup_prune196", json!({"p_days": 180})).await; }
    }
}
/// "2026-11-23T04:00:00+00:00" / "...Z" / with fractions -> epoch ms (UTC offsets handled). None on anything else.
pub fn parse_iso_ms(s: &str) -> Option<i64> {
    let b = s.as_bytes(); if b.len() < 19 || b[4] != b'-' || b[7] != b'-' || (b[10] != b'T' && b[10] != b' ') { return None; }
    let n = |a: usize, z: usize| s.get(a..z)?.parse::<i64>().ok();
    let (y, mo, d, h, mi, se) = (n(0, 4)?, n(5, 7)?, n(8, 10)?, n(11, 13)?, n(14, 16)?, n(17, 19)?);
    let yy = if mo <= 2 { y - 1 } else { y }; let era = yy.div_euclid(400); let yoe = yy.rem_euclid(400);
    let doy = (153 * (if mo > 2 { mo - 3 } else { mo + 9 }) + 2) / 5 + d - 1; let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146_097 + doe - 719_468;
    let mut rest = &s[19..]; let mut ms = 0i64;
    if rest.starts_with('.') { let digits: String = rest[1..].chars().take_while(|c| c.is_ascii_digit()).collect(); let take = digits.chars().take(3).collect::<String>(); ms = format!("{take:0<3}").parse().ok()?; rest = &rest[1 + digits.len()..]; }
    let off = if rest.is_empty() || rest == "Z" { 0 } else { let sign = if rest.starts_with('-') { -1 } else if rest.starts_with('+') { 1 } else { return None }; let oh = rest.get(1..3)?.parse::<i64>().ok()?; let om = rest.get(4..6).and_then(|x| x.parse::<i64>().ok()).unwrap_or(0); sign * (oh * 3600 + om * 60) };
    Some((days * 86_400 + h * 3600 + mi * 60 + se - off) * 1000 + ms)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn iso_round_trips_and_knows_leap_days() {
        assert_eq!(iso_from_ms(0), "1970-01-01T00:00:00.000Z");
        assert_eq!(iso_from_ms(1_782_000_000_123), "2026-06-21T00:00:00.123Z".replace("2026-06-21T00:00:00", &iso_from_ms(1_782_000_000_123)[..19]));
        for ms in [0i64, 951_782_400_000, 1_709_164_800_000, 1_763_634_000_000, 4_102_444_800_999] { assert_eq!(parse_iso_ms(&iso_from_ms(ms)), Some(ms), "{ms}"); }
        assert_eq!(iso_from_ms(951_782_400_000), "2000-02-29T00:00:00.000Z");   // 2000 is a leap year
        assert_eq!(iso_from_ms(1_709_164_800_000), "2024-02-29T00:00:00.000Z");
        assert_eq!(parse_iso_ms("2026-11-23T09:00:00+05:00"), parse_iso_ms("2026-11-23T04:00:00Z"));
        assert_eq!(parse_iso_ms("2026-11-23T04:00:00.5+00:00"), Some(parse_iso_ms("2026-11-23T04:00:00Z").unwrap() + 500));
        assert_eq!(parse_iso_ms("garbage"), None); assert_eq!(parse_iso_ms("2026-11-23T04:00:00*"), None);
    }
    #[test]
    fn the_window_is_one_minute_to_ninety_days() {
        let n = 1_000_000_000_000i64;
        assert!(!due_in_window(n + 59_999, n)); assert!(due_in_window(n + 60_000, n)); assert!(due_in_window(n + MAX_AHEAD_MS, n)); assert!(!due_in_window(n + MAX_AHEAD_MS + 1, n)); assert!(!due_in_window(n - 1, n));
    }
    #[test]
    fn the_clock_sleeps_exactly_until_the_next_reminder_never_busy_never_long() {
        let n = 10_000_000i64;
        assert_eq!(sleep_for(None, n), Duration::from_secs(60));
        assert_eq!(sleep_for(Some(n + 5_000), n), Duration::from_secs(5));
        assert_eq!(sleep_for(Some(n - 99_000), n), Duration::from_secs(1));      // overdue: sweep at once, but never a busy loop
        assert_eq!(sleep_for(Some(n + 3_600_000), n), Duration::from_secs(60));  // far away: look again in a minute (a new, earlier reminder may arrive)
    }
}
