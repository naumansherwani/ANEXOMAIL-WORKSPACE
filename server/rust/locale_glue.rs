// ============================================================================
// locale_glue.rs — the I/O half of /rpc/locale.* (Rust PRIMARY; Bun /api/locale/* = fallback only, kept as-is).
//
// Procedures:
//   locale.bundle      PUBLIC  {tag}  -> {tag, bundle}   overlay strings for one of the 28 locales (no login needed, same as Bun)
//   locale.registry    PUBLIC  {}     -> {locales:[...]} the 28 locales (tag, english, native, dir, sort_n)
//   locale.pref        AUTH    {}     -> {tag|null}      the caller's saved language (cross-device)
//   locale.pref.set    AUTH    {tag}  -> {ok, tag}       save it (upsert on user_id)
//   locale.uipref      AUTH    {}     -> {clock|null, layout|null, extra{}}  calendar pasand (E57) + calendars / working hours / out-of-office (E58), cross-device
//   locale.uipref.set  AUTH    {clock?, layout?, extra?} -> {ok, clock, layout, extra}  save (wrong value = 400, never stored; extra = validated patch)
//
// Answers are byte-for-byte the shapes the Bun twin (server/routes/locale.ts) returns, inside the usual `{result:{data}}`:
// any read failure degrades to "English / no preference" exactly like Bun does; only the write reports a real error.
// Child module of the crate root: uses the root's private helpers (`sb_rpc`, `sb_select`, `sb_upsert`, `auth_user`, `ok`, `err`).
// Adds NO dependency.
// ============================================================================

use crate::locale_core::{self as lc, DEFAULT_TAG};
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Map, Value};

type Resp = axum::response::Response;

pub fn public_owns(proc: &str) -> bool {
    matches!(proc, "locale.bundle" | "locale.registry")
}

pub fn owns(proc: &str) -> bool {
    matches!(proc, "locale.pref" | "locale.pref.set" | "locale.uipref" | "locale.uipref.set")
}

fn data(v: Value) -> Resp {
    crate::ok(v).into_response()
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn tag_of(input: &Value) -> String {
    input.get("tag").and_then(|x| x.as_str()).unwrap_or("").to_string()
}

pub async fn public(proc: &str, input: &Value) -> Resp {
    match proc {
        "locale.bundle" => bundle(input).await,
        "locale.registry" => registry().await,
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown locale procedure"),
    }
}

struct UiPref {
    clock: Option<String>,
    layout: Option<String>,
    extra: Map<String, Value>,
}

/// The caller's saved calendar preference (clock, layout, extra); empty when there is no row yet or the read fails
/// (the browser then keeps its own device value — same "degrade quietly" rule as `locale.pref`).
async fn ui_pref_of(user_id: &str) -> UiPref {
    let q = format!("awam_ui_pref?select=clock,cal_layout,extra&user_id=eq.{}&limit=1", lc::pct(user_id));
    let row = match crate::sb_select(&q).await {
        Ok(v) => v.as_array().and_then(|a| a.first()).cloned(),
        Err(_) => None,
    };
    let pick = |k: &str, ok: fn(&str) -> bool| {
        row.as_ref()
            .and_then(|r| r.get(k))
            .and_then(|x| x.as_str())
            .filter(|v| ok(v))
            .map(str::to_string)
    };
    let extra = row
        .as_ref()
        .and_then(|r| r.get("extra"))
        .and_then(|x| x.as_object())
        .cloned()
        .unwrap_or_default();
    UiPref { clock: pick("clock", lc::clock_ok), layout: pick("cal_layout", lc::layout_ok), extra }
}

/* ---- extra (E58): calendars, working hours, out-of-office.
 * A patch replaces whole keys (`null` removes one). Only these three keys exist; every value is rebuilt from validated
 * parts, so nothing the client sends is stored as-is. */

const EXTRA_MAX_BYTES: usize = 15_000;

fn hhmm_ok(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 5
        && b[2] == b':'
        && b[0].is_ascii_digit()
        && b[1].is_ascii_digit()
        && b[3].is_ascii_digit()
        && b[4].is_ascii_digit()
        && s[0..2].parse::<u32>().is_ok_and(|h| h < 24)
        && s[3..5].parse::<u32>().is_ok_and(|m| m < 60)
}

fn date_ok(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 10
        && b[4] == b'-'
        && b[7] == b'-'
        && s.chars().enumerate().all(|(i, c)| i == 4 || i == 7 || c.is_ascii_digit())
        && s[5..7].parse::<u32>().is_ok_and(|m| (1..=12).contains(&m))
        && s[8..10].parse::<u32>().is_ok_and(|d| (1..=31).contains(&d))
}

fn clean_text(s: &str, max: usize) -> String {
    s.chars().filter(|c| !c.is_control()).collect::<String>().trim().chars().take(max).collect()
}

fn key_ok(s: &str, max: usize) -> bool {
    !s.is_empty() && s.len() <= max && s.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_' || b == b'-')
}

fn zone_ok(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 64
        && s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'/' || b == b'+' || b == b'-')
}

fn clean_work_hours(v: &Value) -> Result<Value, String> {
    let o = v.as_object().ok_or("work_hours must be an object")?;
    let days = o.get("days").and_then(|d| d.as_array()).ok_or("work_hours.days must be 7 days")?;
    if days.len() != 7 {
        return Err("work_hours.days must be 7 days (Mon..Sun)".into());
    }
    let mut out = Vec::with_capacity(7);
    for d in days {
        let on = d.get("on").and_then(|x| x.as_bool()).ok_or("each day needs on: true/false")?;
        let start = d.get("start").and_then(|x| x.as_str()).unwrap_or("09:00");
        let end = d.get("end").and_then(|x| x.as_str()).unwrap_or("17:00");
        if !hhmm_ok(start) || !hhmm_ok(end) {
            return Err("times must look like 09:30".into());
        }
        if on && start >= end {
            return Err("a working day must end after it starts".into());
        }
        out.push(json!({ "on": on, "start": start, "end": end }));
    }
    let mut res = Map::new();
    res.insert("days".into(), Value::Array(out));
    if let Some(tz) = o.get("tz").and_then(|x| x.as_str()).filter(|t| !t.is_empty()) {
        if !zone_ok(tz) {
            return Err("time zone name is not valid".into());
        }
        res.insert("tz".into(), json!(tz));
    }
    Ok(Value::Object(res))
}

fn clean_ooo(v: &Value) -> Result<Value, String> {
    let a = v.as_array().ok_or("ooo must be a list")?;
    if a.len() > 20 {
        return Err("at most 20 out-of-office periods".into());
    }
    let mut out = Vec::with_capacity(a.len());
    for x in a {
        let from = x.get("from").and_then(|s| s.as_str()).unwrap_or("");
        let to = x.get("to").and_then(|s| s.as_str()).unwrap_or("");
        if !date_ok(from) || !date_ok(to) {
            return Err("out-of-office dates must look like 2026-10-30".into());
        }
        if from > to {
            return Err("out-of-office must end on or after the day it starts".into());
        }
        let note = clean_text(x.get("note").and_then(|s| s.as_str()).unwrap_or(""), 200);
        out.push(json!({ "from": from, "to": to, "note": note }));
    }
    Ok(Value::Array(out))
}

fn clean_calendars(v: &Value) -> Result<Value, String> {
    let a = v.as_array().ok_or("calendars must be a list")?;
    if a.is_empty() || a.len() > 20 {
        return Err("between 1 and 20 calendars".into());
    }
    let mut seen: Vec<String> = Vec::new();
    let mut out = Vec::with_capacity(a.len());
    for x in a {
        let id = x.get("id").and_then(|s| s.as_str()).unwrap_or("");
        if !key_ok(id, 24) || seen.iter().any(|s| s == id) {
            return Err("each calendar needs a unique short id".into());
        }
        seen.push(id.to_string());
        let name = clean_text(x.get("name").and_then(|s| s.as_str()).unwrap_or(""), 40);
        if name.is_empty() {
            return Err("each calendar needs a name".into());
        }
        let color = x.get("color").and_then(|s| s.as_str()).unwrap_or("").to_ascii_lowercase();
        let cb = color.as_bytes();
        if cb.len() != 7 || cb[0] != b'#' || !cb[1..].iter().all(|c| c.is_ascii_hexdigit()) {
            return Err("calendar colour must look like #3b82f6".into());
        }
        out.push(json!({ "id": id, "name": name, "color": color }));
    }
    Ok(Value::Array(out))
}

/// Merge a client patch into the stored `extra`. Unknown keys are refused, `null` removes a key, the result stays small.
fn clean_extra(old: &Map<String, Value>, patch: &Map<String, Value>) -> Result<Map<String, Value>, String> {
    let mut out = old.clone();
    for (k, v) in patch {
        if v.is_null() {
            out.remove(k);
            continue;
        }
        let cleaned = match k.as_str() {
            "work_hours" => clean_work_hours(v)?,
            "ooo" => clean_ooo(v)?,
            "calendars" => clean_calendars(v)?,
            _ => return Err(format!("unknown setting '{}'", clean_text(k, 24))),
        };
        out.insert(k.clone(), cleaned);
    }
    if Value::Object(out.clone()).to_string().len() > EXTRA_MAX_BYTES {
        return Err("settings are too large".into());
    }
    Ok(out)
}

#[cfg(test)]
mod extra_tests {
    use super::*;

    fn obj(v: Value) -> Map<String, Value> {
        v.as_object().cloned().unwrap()
    }

    fn week(on: bool) -> Value {
        json!({ "days": (0..7).map(|_| json!({ "on": on, "start": "09:00", "end": "17:30" })).collect::<Vec<_>>(), "tz": "Asia/Karachi" })
    }

    #[test]
    fn working_hours_roundtrip_and_rejects() {
        let ok = clean_extra(&Map::new(), &obj(json!({ "work_hours": week(true) }))).unwrap();
        assert_eq!(ok["work_hours"]["days"][0]["end"], "17:30");
        assert!(clean_extra(&Map::new(), &obj(json!({ "work_hours": { "days": [] } }))).is_err());
        let mut bad = week(true);
        bad["days"][2]["start"] = json!("18:00");
        assert!(clean_extra(&Map::new(), &obj(json!({ "work_hours": bad }))).is_err());
        let mut bad2 = week(true);
        bad2["days"][1]["end"] = json!("25:00");
        assert!(clean_extra(&Map::new(), &obj(json!({ "work_hours": bad2 }))).is_err());
        let mut off = week(true);
        off["days"][5] = json!({ "on": false, "start": "18:00", "end": "09:00" });
        assert!(clean_extra(&Map::new(), &obj(json!({ "work_hours": off }))).is_ok(), "a day that is off may hold any time");
        let mut tz = week(true);
        tz["tz"] = json!("Asia/Karachi; drop table");
        assert!(clean_extra(&Map::new(), &obj(json!({ "work_hours": tz }))).is_err());
    }

    #[test]
    fn ooo_validates_dates_order_and_count() {
        let good = json!([{ "from": "2026-10-30", "to": "2026-11-02", "note": "  Eid \u{7} break " }]);
        let m = clean_extra(&Map::new(), &obj(json!({ "ooo": good }))).unwrap();
        assert_eq!(m["ooo"][0]["note"], "Eid  break");
        assert!(clean_extra(&Map::new(), &obj(json!({ "ooo": [{ "from": "2026-11-02", "to": "2026-10-30" }] }))).is_err());
        assert!(clean_extra(&Map::new(), &obj(json!({ "ooo": [{ "from": "2026-13-01", "to": "2026-13-02" }] }))).is_err());
        assert!(clean_extra(&Map::new(), &obj(json!({ "ooo": [{ "from": "30/10/2026", "to": "31/10/2026" }] }))).is_err());
        let many: Vec<Value> = (0..21).map(|_| json!({ "from": "2026-10-30", "to": "2026-10-30" })).collect();
        assert!(clean_extra(&Map::new(), &obj(json!({ "ooo": many }))).is_err());
    }

    #[test]
    fn calendars_need_unique_ids_names_and_hex_colours() {
        let good = json!([{ "id": "work", "name": "Work", "color": "#3B82F6" }, { "id": "home", "name": "Home", "color": "#22c55e" }]);
        let m = clean_extra(&Map::new(), &obj(json!({ "calendars": good }))).unwrap();
        assert_eq!(m["calendars"][0]["color"], "#3b82f6");
        assert!(clean_extra(&Map::new(), &obj(json!({ "calendars": [] }))).is_err());
        assert!(clean_extra(&Map::new(), &obj(json!({ "calendars": [{ "id": "a", "name": "A", "color": "#fff" }] }))).is_err());
        assert!(clean_extra(&Map::new(), &obj(json!({ "calendars": [{ "id": "A B", "name": "A", "color": "#ffffff" }] }))).is_err());
        let dup = json!([{ "id": "a", "name": "A", "color": "#ffffff" }, { "id": "a", "name": "B", "color": "#000000" }]);
        assert!(clean_extra(&Map::new(), &obj(json!({ "calendars": dup }))).is_err());
        assert!(clean_extra(&Map::new(), &obj(json!({ "calendars": [{ "id": "a", "name": " ", "color": "#ffffff" }] }))).is_err());
    }

    #[test]
    fn patch_merges_removes_and_refuses_unknown_keys() {
        let start = clean_extra(&Map::new(), &obj(json!({ "work_hours": week(true), "ooo": [] }))).unwrap();
        let after = clean_extra(&start, &obj(json!({ "ooo": null }))).unwrap();
        assert!(after.contains_key("work_hours") && !after.contains_key("ooo"));
        assert!(clean_extra(&start, &obj(json!({ "api_key": "x" }))).is_err());
        let huge: Vec<Value> = (0..20).map(|_| json!({ "from": "2026-10-30", "to": "2026-10-30", "note": "x".repeat(200) })).collect();
        let mut st = start.clone();
        for i in 0..3 {
            st.insert(format!("pad{i}"), json!("y".repeat(5000)));
        }
        assert!(clean_extra(&st, &obj(json!({ "ooo": huge }))).is_err(), "size cap");
    }
}

async fn bundle(input: &Value) -> Resp {
    let mut tag = tag_of(input);
    if tag.is_empty() {
        tag = DEFAULT_TAG.to_string();
    }
    if !lc::is_tag(&tag) {
        return data(json!({ "tag": DEFAULT_TAG, "bundle": {} }));
    }
    // 1) the SQL function (phase64 `ui_copy_bundle`) — one round-trip, filtering done in Postgres.
    if let Ok(v) = crate::sb_rpc("ui_copy_bundle", json!({ "p_tag": tag })).await {
        if v.is_object() {
            return data(json!({ "tag": tag, "bundle": v }));
        }
    }
    // 2) the raw rows, filtered here exactly like the Bun twin.
    let rows = match crate::sb_select(&format!("ui_copy?select=english_key,text&locale_tag=eq.{}", lc::pct(&tag))).await {
        Ok(v) => v,
        Err(_) => return data(json!({ "tag": tag, "bundle": {} })),
    };
    let mut out = Map::new();
    for r in rows.as_array().cloned().unwrap_or_default() {
        let k = r.get("english_key").and_then(|x| x.as_str()).unwrap_or("");
        let t = r.get("text").and_then(|x| x.as_str()).unwrap_or("");
        if lc::keep_row(&tag, k, t) {
            out.insert(k.to_string(), Value::String(t.to_string()));
        }
    }
    data(json!({ "tag": tag, "bundle": Value::Object(out) }))
}

async fn registry() -> Resp {
    match crate::sb_select("locale_registry?select=tag,english,native,dir,sort_n&order=sort_n.asc").await {
        Ok(v) if v.is_array() => data(json!({ "locales": v })),
        _ => data(json!({ "locales": lc::TAGS.iter().map(|t| json!({ "tag": t })).collect::<Vec<_>>() })),
    }
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let user_id = match crate::auth_user(token).await {
        Some((id, _)) => id,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid"),
    };
    match proc {
        "locale.pref" => {
            let q = format!("awam_locale_pref?select=locale_tag&user_id=eq.{}&limit=1", lc::pct(&user_id));
            let tag = match crate::sb_select(&q).await {
                Ok(v) => v
                    .as_array()
                    .and_then(|a| a.first())
                    .and_then(|r| r.get("locale_tag"))
                    .and_then(|x| x.as_str())
                    .filter(|t| lc::is_tag(t))
                    .map(|t| Value::String(t.to_string()))
                    .unwrap_or(Value::Null),
                Err(_) => Value::Null,
            };
            data(json!({ "tag": tag }))
        }
        "locale.pref.set" => {
            let tag = tag_of(input);
            if !lc::is_tag(&tag) {
                return fail(StatusCode::BAD_REQUEST, "locale_not_allowed", "Language not supported");
            }
            let row = json!({ "user_id": user_id, "locale_tag": tag, "updated_at": lc::now_rfc3339() });
            match crate::sb_upsert("awam_locale_pref", "user_id", row).await {
                Ok(_) => data(json!({ "ok": true, "tag": tag })),
                Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "pref_failed", "Could not save language"),
            }
        }
        "locale.uipref" => {
            let p = ui_pref_of(&user_id).await;
            data(json!({ "clock": p.clock, "layout": p.layout, "extra": Value::Object(p.extra) }))
        }
        "locale.uipref.set" => {
            let want_clock = input.get("clock").and_then(|x| x.as_str());
            let want_layout = input.get("layout").and_then(|x| x.as_str());
            let want_extra = input.get("extra").and_then(|x| x.as_object());
            if want_clock.is_none() && want_layout.is_none() && want_extra.is_none() {
                return fail(StatusCode::BAD_REQUEST, "nothing_to_save", "Send a clock, layout or extra value");
            }
            if want_clock.is_some_and(|c| !lc::clock_ok(c)) || want_layout.is_some_and(|l| !lc::layout_ok(l)) {
                return fail(StatusCode::BAD_REQUEST, "pref_not_allowed", "That preference value is not supported");
            }
            let old = ui_pref_of(&user_id).await;
            let extra = match want_extra {
                Some(patch) => match clean_extra(&old.extra, patch) {
                    Ok(m) => m,
                    Err(m) => return fail(StatusCode::BAD_REQUEST, "extra_not_allowed", &m),
                },
                None => old.extra.clone(),
            };
            let clock = want_clock.map(str::to_string).or(old.clock).unwrap_or_else(|| "auto".to_string());
            let layout = want_layout.map(str::to_string).or(old.layout).unwrap_or_else(|| "classic".to_string());
            let row = json!({ "user_id": user_id, "clock": clock, "cal_layout": layout,
                              "extra": Value::Object(extra.clone()), "updated_at": lc::now_rfc3339() });
            match crate::sb_upsert("awam_ui_pref", "user_id", row).await {
                Ok(_) => data(json!({ "ok": true, "clock": clock, "layout": layout, "extra": Value::Object(extra) })),
                Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "pref_failed", "Could not save preference"),
            }
        }
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown locale procedure"),
    }
}
