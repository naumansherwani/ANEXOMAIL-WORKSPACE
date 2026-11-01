//! Founder Settings S2 (master order step 6; SQL = E113): Time machine, Drift, Scheduled changes, Explain / Blast radius.
//! Technology: Rust (axum, tokio). Pure and tested here (whitelisted query parsing, body validation, timestamp maths); the network lives in data.rs,
//! the routes in main.rs. SQL is authoritative: everything here is a first line of defence so a bad request never reaches the database.
//! Nothing is invented: when E113 is not applied the answer says so (`available:false`).
use serde_json::{Value, json};

use crate::settings;

/// Keys that may be scheduled (mirrors `founder_settings_info.schedulable` in E113; the photo is never schedulable).
pub const SCHEDULABLE: [&str; 12] = ["personal.display_name", "personal.home", "appearance.graphics", "appearance.sidebar_slim", "appearance.text_scale", "appearance.animations",
    "appearance.transitions", "appearance.celebration", "appearance.focus_ring", "appearance.density", "appearance.reduce_motion", "appearance.ambient"];

pub const MIN_MS: i64 = 1_577_836_800_000; // 2020-01-01: before this no founder history can exist
pub const MAX_MS: i64 = 4_102_444_800_000; // 2100-01-01

pub fn missing() -> Value { json!({"available": false, "note": "settings time machine not answering - run the E113 SQL (sql-run.sh)"}) }

/// uuid text (8-4-4-4-12 hex). Used for schedule ids before they go into an RPC.
pub fn is_uuid(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 36 && b.iter().enumerate().all(|(i, c)| if matches!(i, 8 | 13 | 18 | 23) { *c == b'-' } else { c.is_ascii_hexdigit() })
}

fn num(v: &str, what: &'static str, lo: i64, hi: i64) -> Result<i64, &'static str> {
    if v.is_empty() || v.len() > 18 || !v.bytes().all(|b| b.is_ascii_digit()) { return Err(what); }
    let n: i64 = v.parse().map_err(|_| what)?;
    if n < lo || n > hi { return Err(what); }
    Ok(n)
}

fn pairs(q: Option<&str>) -> impl Iterator<Item = (&str, &str)> { q.unwrap_or("").split('&').filter(|p| !p.is_empty()).map(|p| p.split_once('=').unwrap_or((p, ""))) }

fn key_ok(v: &str) -> bool { v.len() <= 40 && settings::known(v) }

#[derive(Debug, PartialEq)]
pub struct HistQ { pub key: Option<String>, pub before: Option<i64>, pub limit: i64 }

/// `[key=<registry key>][&before=<history id>][&limit=1..200]`
pub fn parse_history(q: Option<&str>) -> Result<HistQ, &'static str> {
    let mut o = HistQ { key: None, before: None, limit: 50 };
    for (k, v) in pairs(q) {
        match k {
            "key" => { if !key_ok(v) { return Err("unknown setting"); } o.key = Some(v.to_string()); }
            "before" => o.before = Some(num(v, "invalid before", 1, i64::MAX / 2)?),
            "limit" => o.limit = num(v, "invalid limit", 1, 200)?,
            _ => return Err("unknown parameter"),
        }
    }
    Ok(o)
}

/// `limit=1..200` only (timeline, scheduled list).
pub fn parse_limit(q: Option<&str>, default: i64) -> Result<i64, &'static str> {
    let mut l = default;
    for (k, v) in pairs(q) { match k { "limit" => l = num(v, "invalid limit", 1, 200)?, _ => return Err("unknown parameter") } }
    Ok(l)
}

/// `key=<registry key>` only (explain, blast radius).
pub fn parse_key(q: Option<&str>) -> Result<String, &'static str> {
    let mut key = None;
    for (k, v) in pairs(q) { match k { "key" => { if !key_ok(v) { return Err("unknown setting"); } key = Some(v.to_string()); } _ => return Err("unknown parameter") } }
    key.ok_or("missing key")
}

/// `t=<epoch ms>` (point in time view).
pub fn parse_at(q: Option<&str>) -> Result<i64, &'static str> {
    let mut t = None;
    for (k, v) in pairs(q) { match k { "t" => t = Some(num(v, "invalid time", MIN_MS, MAX_MS)?), _ => return Err("unknown parameter") } }
    t.ok_or("missing t")
}

/// `from=<ms>&to=<ms>`, from <= to.
pub fn parse_diff(q: Option<&str>) -> Result<(i64, i64), &'static str> {
    let (mut a, mut b) = (None, None);
    for (k, v) in pairs(q) {
        match k { "from" => a = Some(num(v, "invalid from", MIN_MS, MAX_MS)?), "to" => b = Some(num(v, "invalid to", MIN_MS, MAX_MS)?), _ => return Err("unknown parameter") }
    }
    let (a, b) = (a.ok_or("missing from")?, b.ok_or("missing to")?);
    if a > b { return Err("from after to"); }
    Ok((a, b))
}

/// UTC ISO-8601 with milliseconds from epoch milliseconds (days-to-civil, no date crate). 1970..2100 only.
pub fn iso_from_ms(ms: i64) -> String {
    let days = ms.div_euclid(86_400_000);
    let rem = ms.rem_euclid(86_400_000);
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    let (h, mi, s, milli) = (rem / 3_600_000, rem / 60_000 % 60, rem / 1000 % 60, rem % 1000);
    format!("{y:04}-{m:02}-{d:02}T{h:02}:{mi:02}:{s:02}.{milli:03}Z")
}

/// 8-300 printable characters, no control characters (same rule as the SQL RPCs).
pub fn valid_reason(s: &str) -> bool { let n = s.trim().chars().count(); (8..=300).contains(&n) && !s.chars().any(|c| c.is_control()) }

#[derive(serde::Deserialize)]
pub struct RevertIn { pub history_id: i64, pub reason: String }
#[derive(serde::Deserialize)]
pub struct ScheduleIn { pub key: String, #[serde(default)] pub value: Value, pub apply_at_ms: i64, #[serde(default)] pub rollback_minutes: Option<i64>, pub reason: String }
#[derive(serde::Deserialize)]
pub struct IdReasonIn { pub id: String, pub reason: String }

pub fn check_revert(b: &RevertIn) -> Result<(), &'static str> {
    if b.history_id < 1 { return Err("invalid version"); }
    if !valid_reason(&b.reason) { return Err("reason must be 8-300 characters"); }
    Ok(())
}

/// Window is checked against `now_ms`: at least 1 minute ahead, at most 90 days (same as SQL).
pub fn check_schedule(b: &ScheduleIn, now_ms: i64) -> Result<(), &'static str> {
    if !SCHEDULABLE.contains(&b.key.as_str()) { return Err("this setting cannot be scheduled"); }
    if !settings::valid(&b.key, &b.value) { return Err("invalid value for this setting"); }
    if b.apply_at_ms < now_ms + 60_000 { return Err("apply time must be at least 1 minute from now"); }
    if b.apply_at_ms > now_ms + 90 * 86_400_000 { return Err("apply time must be within 90 days"); }
    if let Some(m) = b.rollback_minutes { if !(5..=10_080).contains(&m) { return Err("auto-rollback must be 5 minutes to 7 days"); } }
    if !valid_reason(&b.reason) { return Err("reason must be 8-300 characters"); }
    Ok(())
}

pub fn check_id_reason(b: &IdReasonIn) -> Result<(), &'static str> {
    if !is_uuid(&b.id) { return Err("invalid id"); }
    if !valid_reason(&b.reason) { return Err("reason must be 8-300 characters"); }
    Ok(())
}

/// Browser-friendly summary of a tick answer (used for the log line only).
pub fn tick_busy(v: &Value) -> bool {
    ["applied", "rolled_back", "superseded", "failed"].iter().any(|k| v.get(*k).and_then(|x| x.as_i64()).unwrap_or(0) > 0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test] fn uuid_shape() {
        assert!(is_uuid("0e9a1f2c-3b4d-4e5f-8a9b-0c1d2e3f4a5b"));
        assert!(!is_uuid("0e9a1f2c3b4d4e5f8a9b0c1d2e3f4a5b"));
        assert!(!is_uuid("0e9a1f2c-3b4d-4e5f-8a9b-0c1d2e3f4a5z"));
        assert!(!is_uuid("'; drop table x; --"));
    }
    #[test] fn history_query() {
        assert_eq!(parse_history(None).unwrap(), HistQ { key: None, before: None, limit: 50 });
        assert_eq!(parse_history(Some("key=appearance.graphics&before=12&limit=10")).unwrap(), HistQ { key: Some("appearance.graphics".into()), before: Some(12), limit: 10 });
        assert!(parse_history(Some("key=nope")).is_err());
        assert!(parse_history(Some("limit=0")).is_err());
        assert!(parse_history(Some("limit=201")).is_err());
        assert!(parse_history(Some("before=-1")).is_err());
        assert!(parse_history(Some("x=1")).is_err());
        assert!(parse_history(Some("key=appearance.graphics%27")).is_err());
    }
    #[test] fn limit_key_at_diff() {
        assert_eq!(parse_limit(None, 60).unwrap(), 60);
        assert_eq!(parse_limit(Some("limit=5"), 60).unwrap(), 5);
        assert!(parse_limit(Some("limit=abc"), 60).is_err());
        assert_eq!(parse_key(Some("key=personal.home")).unwrap(), "personal.home");
        assert!(parse_key(None).is_err());
        assert!(parse_key(Some("key=x")).is_err());
        assert_eq!(parse_at(Some("t=1793000000000")).unwrap(), 1_793_000_000_000);
        assert!(parse_at(Some("t=1")).is_err());
        assert!(parse_at(Some("t=99999999999999")).is_err());
        assert_eq!(parse_diff(Some("from=1700000000000&to=1790000000000")).unwrap(), (1_700_000_000_000, 1_790_000_000_000));
        assert!(parse_diff(Some("from=1790000000000&to=1700000000000")).is_err());
        assert!(parse_diff(Some("from=1700000000000")).is_err());
    }
    #[test] fn iso_known_dates() {
        assert_eq!(iso_from_ms(0), "1970-01-01T00:00:00.000Z");
        assert_eq!(iso_from_ms(1_577_836_800_000), "2020-01-01T00:00:00.000Z");
        assert_eq!(iso_from_ms(951_782_400_000), "2000-02-29T00:00:00.000Z");           // leap day
        assert_eq!(iso_from_ms(1_793_000_000_123), "2026-10-26T07:33:20.123Z");
        assert_eq!(iso_from_ms(4_102_444_800_000), "2100-01-01T00:00:00.000Z");
        assert_eq!(iso_from_ms(1_709_164_799_999), "2024-02-28T23:59:59.999Z");
        assert_eq!(iso_from_ms(1_709_164_800_000), "2024-02-29T00:00:00.000Z");
    }
    #[test] fn reason_rules() {
        assert!(valid_reason("undo my last change"));
        assert!(!valid_reason("short"));
        assert!(!valid_reason("        "));
        assert!(!valid_reason("bad\u{0007}control chars here"));
        assert!(!valid_reason(&"x".repeat(301)));
        assert!(valid_reason(&"x".repeat(300)));
    }
    #[test] fn revert_body() {
        assert!(check_revert(&RevertIn { history_id: 3, reason: "undo this one".into() }).is_ok());
        assert!(check_revert(&RevertIn { history_id: 0, reason: "undo this one".into() }).is_err());
        assert!(check_revert(&RevertIn { history_id: 3, reason: "no".into() }).is_err());
    }
    fn sched(key: &str, value: Value, at: i64, rb: Option<i64>, reason: &str) -> ScheduleIn { ScheduleIn { key: key.into(), value, apply_at_ms: at, rollback_minutes: rb, reason: reason.into() } }
    #[test] fn schedule_rules() {
        let now = 1_793_000_000_000;
        assert!(check_schedule(&sched("appearance.graphics", json!(false), now + 120_000, Some(30), "evening calm look"), now).is_ok());
        assert!(check_schedule(&sched("appearance.graphics", Value::Null, now + 120_000, None, "back to default please"), now).is_ok());
        assert!(check_schedule(&sched("personal.avatar", json!("https://x.y/a.png"), now + 120_000, None, "photo schedule no"), now).is_err());
        assert!(check_schedule(&sched("appearance.graphics", json!("off"), now + 120_000, None, "wrong value type"), now).is_err());
        assert!(check_schedule(&sched("appearance.graphics", json!(false), now + 30_000, None, "too soon to apply"), now).is_err());
        assert!(check_schedule(&sched("appearance.graphics", json!(false), now + 91 * 86_400_000, None, "too far away"), now).is_err());
        assert!(check_schedule(&sched("appearance.graphics", json!(false), now + 120_000, Some(4), "rollback too short"), now).is_err());
        assert!(check_schedule(&sched("appearance.graphics", json!(false), now + 120_000, Some(10_081), "rollback too long"), now).is_err());
        assert!(check_schedule(&sched("appearance.graphics", json!(false), now + 120_000, None, "short"), now).is_err());
        assert!(check_schedule(&sched("nope.key", json!(true), now + 120_000, None, "unknown key here"), now).is_err());
        assert!(check_schedule(&sched("personal.home", json!({"city":"Lahore","country":"Pakistan","iana":"Asia/Karachi","lat":31.5,"lon":74.3}), now + 120_000, Some(60), "home city for the trip"), now).is_ok());
    }
    #[test] fn id_reason_body() {
        assert!(check_id_reason(&IdReasonIn { id: "0e9a1f2c-3b4d-4e5f-8a9b-0c1d2e3f4a5b".into(), reason: "cancel this schedule".into() }).is_ok());
        assert!(check_id_reason(&IdReasonIn { id: "1".into(), reason: "cancel this schedule".into() }).is_err());
        assert!(check_id_reason(&IdReasonIn { id: "0e9a1f2c-3b4d-4e5f-8a9b-0c1d2e3f4a5b".into(), reason: "x".into() }).is_err());
    }
    #[test] fn schedulable_keys_are_registry_keys() { for k in SCHEDULABLE { assert!(settings::known(k), "{k}"); } assert!(!SCHEDULABLE.contains(&"personal.avatar")); }
    #[test] fn tick_busy_flag() {
        assert!(!tick_busy(&json!({"skipped": false, "applied": 0, "rolled_back": 0, "superseded": 0, "failed": 0})));
        assert!(tick_busy(&json!({"applied": 1})));
        assert!(tick_busy(&json!({"failed": 2})));
        assert!(!tick_busy(&json!({"skipped": true})));
    }
}
