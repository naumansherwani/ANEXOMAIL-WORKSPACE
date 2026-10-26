// ============================================================================
// ANEXOMAIL — Overlap Matrix procs (calendar #4b / World Clock W1) (Rust PRIMARY).
//
// `mod overlap_core; mod overlap_glue;` main.rs mein judta hai (installer: rust-engine-install.sh, module `overlap`).
// Saari soch overlap_core.rs mein hai (std-only, unit tests). Yahan sirf I/O: Supabase REST.
// SQL: docs/cursor-work/sql/E62_team_overlap.sql — privacy ki aakhri deewar (viewer same-org ka zinda member ho, sirf apna likha
// schedule, OOO ka `note` kabhi nahi). Busy time sirf free/busy (calendar_busy) — meeting ka naam/content kabhi nahi.
//
// Proc (login chahiye):  calendar.overlap
//   input  { addresses: [..<=12], from?: RFC3339 (default ab), days?: 1..7 (2), step_min?: 15|30|60 (30),
//            minutes?: meeting length 15..480 (30), proposal?: { start, end } RFC3339 }
//   output { now, grid:{from,slots,step_min}, truncated, members:[{address,name,kind,tz,known,you,row,assess?}], best:[{start,end,red,amber,all_green}] }
// Graceful: E62 na lagi ho to 501 `overlap_sql_missing`; kuch toot'ta nahi (Bun fallback ka is proc se koi wasta nahi).
// Package gating NAHI: har plan + family ko ek jaisa (Rule 37/40). Basic ka akela member bhi guests ke zones dekh sakta hai.
// ============================================================================

use crate::cal_core::{self as cal, recur, Interval};
use crate::overlap_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use std::collections::{HashMap, VecDeque};
use std::sync::Mutex;

const RATE_LIMIT: usize = 60; // calls per user per minute
const RATE_WINDOW_MS: u64 = 60_000;
static RATE: std::sync::OnceLock<Mutex<HashMap<String, VecDeque<u64>>>> = std::sync::OnceLock::new();

pub fn owns(proc: &str) -> bool {
    proc == "calendar.overlap"
}

/* ---------------------------------------------------------------- helpers */

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}
fn num(v: &Value, k: &str) -> Option<i64> {
    v.get(k).and_then(|x| x.as_i64())
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

/// Sliding window per user. A poisoned lock never blocks a real user.
fn allowed(user: &str) -> bool {
    let m = RATE.get_or_init(|| Mutex::new(HashMap::new()));
    let now = now_ms();
    match m.lock() {
        Ok(mut map) => {
            if map.len() > 5_000 {
                map.retain(|_, q| q.back().map(|t| now.saturating_sub(*t) < RATE_WINDOW_MS).unwrap_or(false));
            }
            let q = map.entry(user.to_string()).or_default();
            while q.front().map(|t| now.saturating_sub(*t) >= RATE_WINDOW_MS).unwrap_or(false) {
                q.pop_front();
            }
            if q.len() >= RATE_LIMIT {
                false
            } else {
                q.push_back(now);
                true
            }
        }
        Err(_) => true,
    }
}

fn zone_name(z: c::Zone) -> &'static str {
    match z {
        c::Zone::Green => "green",
        c::Zone::Amber => "amber",
        c::Zone::Red => "red",
        c::Zone::Unknown => "unknown",
    }
}

fn parse_week(v: &Value) -> Option<c::Week> {
    let days = v.get("days")?.as_array()?;
    if days.len() != 7 {
        return None;
    }
    let mut week = [c::Day { on: false, start: 9 * 60, end: 17 * 60 }; 7];
    for (i, d) in days.iter().enumerate() {
        let on = d.get("on").and_then(|x| x.as_bool()).unwrap_or(false);
        let s = d.get("start").and_then(|x| x.as_str()).and_then(c::parse_hhmm).unwrap_or(9 * 60);
        let e = d.get("end").and_then(|x| x.as_str()).and_then(c::parse_hhmm).unwrap_or(17 * 60);
        week[i] = c::Day { on, start: s, end: e };
    }
    Some(week)
}

fn parse_ooo(v: &Value) -> Vec<(String, String)> {
    v.as_array()
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
                .take(20)
                .collect()
        })
        .unwrap_or_default()
}

/// Unknown zone name -> None (never guess). `load_tz(.., 1)` returns the Fixed(1) sentinel when the name is not in the database.
fn zone_of(name: &str) -> Option<std::sync::Arc<recur::Tz>> {
    if name.is_empty() || name.len() > 64 {
        return None;
    }
    let z = recur::load_tz(name, 1);
    if matches!(&*z, recur::Tz::Fixed(1)) && !(name.eq_ignore_ascii_case("UTC") || name == "Etc/UTC") {
        None
    } else {
        Some(z)
    }
}

fn is_missing_function(e: &str) -> bool {
    e.contains("PGRST202") || e.contains("Could not find the function") || e.contains("42883")
}

/// Busy time for several people in [from, to): single meetings + repeating ones expanded. Keyed by lower-case address.
async fn busy_many(org: &str, addrs: &[String], from: i64, to: i64) -> Result<HashMap<String, Vec<Interval>>, String> {
    let mut out: HashMap<String, Vec<Interval>> = HashMap::new();
    if addrs.is_empty() {
        return Ok(out);
    }
    let (f, t) = (from - 86_400, to + 86_400);
    let rows = crate::sb_rpc(
        "calendar_busy",
        json!({ "p_org": org, "p_addresses": addrs, "p_from": cal::fmt_rfc3339(f), "p_to": cal::fmt_rfc3339(t) }),
    )
    .await?;
    for r in rows.as_array().cloned().unwrap_or_default() {
        if let (Some(s), Some(e)) = (cal::parse_ts(&st(&r, "starts_at")), cal::parse_ts(&st(&r, "ends_at"))) {
            out.entry(st(&r, "address").to_lowercase()).or_default().push(Interval { start: s, end: e });
        }
    }
    let masters = crate::sb_rpc(
        "calendar_busy_masters",
        json!({ "p_org": org, "p_addresses": addrs, "p_to": cal::fmt_rfc3339(t) }),
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
        let key = st(&m, "address").to_lowercase();
        for u in recur::expand(&rule, s, dur, &tz, &ex, f, t) {
            out.entry(key.clone()).or_default().push(Interval { start: u, end: u + dur });
        }
    }
    for v in out.values_mut() {
        *v = cal::merge_intervals(std::mem::take(v));
    }
    Ok(out)
}

/* --------------------------------------------------------------- dispatch */

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> axum::response::Response {
    if proc != "calendar.overlap" {
        return fail(StatusCode::NOT_FOUND, "unknown_proc", proc);
    }
    let me = match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(m) => m,
        Err((StatusCode::CONFLICT, _, _)) => {
            return fail(StatusCode::NOT_IMPLEMENTED, "not_implemented_for_account", "Team availability needs a workspace mailbox.")
        }
        Err((status, code, detail)) => return fail(status, code, &detail),
    };
    // Overlap Matrix = Pro and above (Find-a-time `calendar.findtime` har package par rehta hai). Server rokta hai, UI sirf aaina.
    let plan = crate::sb_rpc("resolve_plan", json!({ "_user_id": me.id, "_email": me.email }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .unwrap_or_else(|| "basic".to_string());
    if plan == "basic" {
        return fail(StatusCode::FORBIDDEN, "feature_not_available", "Overlap Matrix is a Pro+ feature. Find a time works on every package.");
    }
    let my_email = me.email.trim().to_lowercase();
    if !allowed(&me.id) {
        return fail(StatusCode::TOO_MANY_REQUESTS, "too_many_requests", "Too many requests — please try again in a minute.");
    }
    let bad = |m: &str| fail(StatusCode::BAD_REQUEST, "bad_input", m);

    // ---- input ----
    let step = num(input, "step_min").unwrap_or(30);
    let days = num(input, "days").unwrap_or(2);
    let now = now_epoch();
    let from = match input.get("from").and_then(|x| x.as_str()) {
        Some(s) if !s.trim().is_empty() => match cal::parse_ts(s) {
            Some(t) => t,
            None => return bad("from must be an RFC 3339 time"),
        },
        _ => now,
    };
    let g = match c::grid(from, days, step) {
        Some(g) => g,
        None => return bad("days must be 1-7 and step_min 15, 30 or 60"),
    };
    let need = num(input, "minutes").unwrap_or(30).clamp(15, 480).max(step);
    let mut addrs: Vec<String> = vec![my_email.clone()];
    if let Some(list) = input.get("addresses").and_then(|a| a.as_array()) {
        for a in list.iter().take(100) {
            if let Some(s) = a.as_str() {
                let s = s.trim().to_lowercase();
                if s.len() <= 254 && s.contains('@') && !addrs.contains(&s) {
                    addrs.push(s);
                }
            }
        }
    }
    let proposal: Option<(i64, i64)> = match input.get("proposal") {
        Some(p) if p.is_object() => match (cal::parse_ts(&st(p, "start")), cal::parse_ts(&st(p, "end"))) {
            (Some(s), Some(e)) if e > s && e - s <= 8 * 3600 => Some((s, e)),
            _ => return bad("proposal needs start < end, at most 8 hours"),
        },
        _ => None,
    };

    // ---- who are they (privacy wall is in SQL) ----
    let ctx = match crate::sb_rpc(
        "calendar_team_context",
        json!({ "p_org": me.org_id, "p_viewer": me.id, "p_addresses": addrs }),
    )
    .await
    {
        Ok(v) => v,
        Err(e) if is_missing_function(&e) => {
            return fail(StatusCode::NOT_IMPLEMENTED, "overlap_sql_missing", "Team availability is not installed yet (SQL E62).")
        }
        Err(e) => {
            eprintln!("overlap: calendar_team_context failed: {}", e.chars().take(300).collect::<String>());
            return fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Could not load team availability — please try again.");
        }
    };
    if ctx.get("error").and_then(|e| e.as_str()) == Some("forbidden") {
        return fail(StatusCode::FORBIDDEN, "forbidden", "You are not allowed to see this team's availability.");
    }
    let members: Vec<Value> = ctx.get("members").and_then(|m| m.as_array()).cloned().unwrap_or_default();

    // ---- busy time (members who wrote a schedule — free/busy only) ----
    let want_busy: Vec<String> = members
        .iter()
        .filter(|m| st(m, "kind") == "member" && m.get("known").and_then(|k| k.as_bool()) == Some(true))
        .map(|m| st(m, "address"))
        .collect();
    let span_end = g.from + g.slots as i64 * step * 60;
    let busy = match busy_many(&me.org_id, &want_busy, g.from, span_end).await {
        Ok(b) => b,
        Err(e) => {
            eprintln!("overlap: busy time failed: {}", e.chars().take(300).collect::<String>());
            return fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Could not load busy time — please try again.");
        }
    };

    // ---- classify ----
    struct Row {
        address: String,
        name: String,
        kind: String,
        tz_name: String,
        known: bool,
        tz: Option<std::sync::Arc<recur::Tz>>,
        week: Option<c::Week>,
        ooo: Vec<(String, String)>,
        busy: Vec<Interval>,
    }
    let rows: Vec<Row> = members
        .iter()
        .map(|m| {
            let address = st(m, "address");
            let tz_name = st(m, "tz");
            let week = m.get("work_hours").and_then(parse_week);
            Row {
                tz: zone_of(&tz_name),
                known: week.is_some(),
                week,
                ooo: m.get("ooo").map(parse_ooo).unwrap_or_default(),
                busy: busy.get(&address).cloned().unwrap_or_default(),
                name: st(m, "name"),
                kind: st(m, "kind"),
                tz_name,
                address,
            }
        })
        .collect();
    let people: Vec<c::Person> = rows
        .iter()
        .map(|r| c::Person { tz: r.tz.as_deref(), week: r.week, ooo: &r.ooo, busy: &r.busy })
        .collect();
    let matrix = c::matrix(&people, &g);
    let not_before = (now / (step * 60) + 1) * step * 60;
    let best = c::best_windows(&matrix, &g, need, not_before, 5);

    let out_members: Vec<Value> = rows
        .iter()
        .zip(matrix.iter())
        .zip(people.iter())
        .map(|((r, row), p)| {
            let mut v = json!({
                "address": r.address, "name": r.name, "kind": r.kind,
                "tz": if r.tz.is_some() { Value::String(r.tz_name.clone()) } else { Value::Null },
                "known": r.known, "you": r.address == my_email, "row": row,
            });
            if let Some((s, e)) = proposal {
                let a = c::assess(p, s, e);
                v["assess"] = json!({
                    "zone": zone_name(a.zone), "outside_min": a.outside_min, "day_len_min": a.day_len_min, "extra_min": a.extra_min,
                    "booked_min": a.booked_min, "work_min": a.work_min,
                });
            }
            v
        })
        .collect();

    crate::ok(json!({
        "now": cal::fmt_rfc3339(now),
        "grid": { "from": cal::fmt_rfc3339(g.from), "slots": g.slots, "step_min": step },
        "truncated": ctx.get("truncated").and_then(|t| t.as_bool()).unwrap_or(false),
        "members": out_members,
        "best": best.iter().map(|w| json!({
            "start": cal::fmt_rfc3339(w.start), "end": cal::fmt_rfc3339(w.end), "red": w.red, "amber": w.amber, "all_green": w.all_green(),
        })).collect::<Vec<_>>(),
    }))
    .into_response()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn week_needs_exactly_seven_days_and_defaults_are_safe() {
        assert!(parse_week(&json!({ "days": [] })).is_none());
        assert!(parse_week(&json!({})).is_none());
        let seven: Vec<Value> = (0..7).map(|i| json!({ "on": i < 5, "start": "08:30", "end": "16:00" })).collect();
        let w = parse_week(&json!({ "days": seven })).unwrap();
        assert!(w[0].on && !w[6].on);
        assert_eq!((w[0].start, w[0].end), (8 * 60 + 30, 16 * 60));
        let junk: Vec<Value> = (0..7).map(|_| json!({ "on": true, "start": "zz", "end": 5 })).collect();
        let w = parse_week(&json!({ "days": junk })).unwrap();
        assert_eq!((w[0].start, w[0].end), (9 * 60, 17 * 60), "bad times fall back to 09:00-17:00, never to nonsense");
    }

    #[test]
    fn ooo_keeps_dates_only_and_caps() {
        let o = parse_ooo(&json!([{ "from": "2026-10-30", "to": "2026-11-02", "note": "private" }, { "from": "bad", "to": "x" }]));
        assert_eq!(o, vec![("2026-10-30".to_string(), "2026-11-02".to_string())]);
        let many: Vec<Value> = (0..50).map(|_| json!({ "from": "2026-10-30", "to": "2026-10-31" })).collect();
        assert_eq!(parse_ooo(&Value::Array(many)).len(), 20);
        assert!(parse_ooo(&json!("nope")).is_empty());
    }

    #[test]
    fn unknown_zone_is_never_guessed() {
        assert!(zone_of("").is_none());
        assert!(zone_of("Mars/Olympus").is_none());
        assert!(zone_of("../../etc/passwd").is_none());
        assert!(zone_of(&"a".repeat(65)).is_none());
        assert!(zone_of("UTC").is_some());
    }

    #[test]
    fn missing_function_is_recognised() {
        assert!(is_missing_function(r#"{"code":"PGRST202","message":"Could not find the function public.calendar_team_context"}"#));
        assert!(!is_missing_function(r#"{"code":"23505","message":"duplicate"}"#));
    }

    #[test]
    fn rate_limit_is_per_user_and_bounded() {
        let u = format!("rl-test-{}", now_ms());
        for _ in 0..RATE_LIMIT {
            assert!(allowed(&u));
        }
        assert!(!allowed(&u), "61st call in a minute is refused");
        assert!(allowed(&format!("{}-other", u)), "another user is unaffected");
    }
}
