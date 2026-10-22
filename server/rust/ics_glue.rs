// ============================================================================
// ics_glue.rs — #4c: bahar ka calendar (ICS subscribe, SIRF PADHNE ke liye). Rust PRIMARY, tokio async. SQL: docs/cursor-work/sql/E73_calendar_subscriptions.sql
//
//   calendar.sub.add     {url, name?, color?, refresh_minutes?}  -> {id, name, event_count}   (pehli fetch foran; fail ho to subscription wapas hata di jati hai)
//   calendar.sub.list    {}                                       -> {subs:[{id,name,host,color,enabled,refresh_minutes,last_ok_at,last_error,event_count,...}]}   (URL kabhi nahi)
//   calendar.sub.update  {id, name?, color?, enabled?, refresh_minutes?}
//   calendar.sub.remove  {id}
//   calendar.sub.refresh {id}                                     -> abhi fetch (1 minute mein ek baar)
//   calendar.sub.events  {from, to}  (RFC3339, <= 100 din)        -> {subs:[..], events:[{sub_id,sub_name,color,uid,title,location,description,start,end,all_day,date?,end_date?}]}
//                                                                    purane ho chuke feeds ko pehle (<= 6 s) taza karta hai; daemon nahi — padhne wala hi taza karta hai.
//
// Fetch ki hifazat (SSRF): sirf https:443, URL mein user:pass nahi, local/internal naam nahi; DNS jawab ka HAR IP public hona chahiye (ics_core::ip_allowed),
//   connection usi jaanche hue IP par pin (reqwest .resolve — DNS rebinding nahi), redirect khud (<= 3, har hop dobara jaanch), 10 s, 5 MB stream cap.
// Server par ek saath 4 se zyada fetch nahi (Semaphore). Koi nayi crate nahi: reqwest, sha2, tokio — pehle se hain.
// ============================================================================

use crate::cal_core as cal;
use crate::ics_core as ics;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::sync::OnceLock;
use std::time::Duration;

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(proc, "calendar.sub.add" | "calendar.sub.list" | "calendar.sub.update" | "calendar.sub.remove" | "calendar.sub.refresh" | "calendar.sub.events")
}

fn fail_code(code: &str) -> Resp {
    let (s, m) = ics::error_text(code);
    let body = json!({ "error": { "code": code, "message": m } });
    (StatusCode::from_u16(s).unwrap_or(StatusCode::BAD_REQUEST), axum::Json(body)).into_response()
}

fn db_err(e: &str) -> Resp {
    // E73 chali nahi: function nahi milta
    if e.contains("cal_sub_") && (e.contains("does not exist") || e.contains("Could not find") || e.contains("PGRST202") || e.contains("42883")) {
        return fail_code("sql_missing");
    }
    crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e.chars().take(300).collect::<String>()).into_response()
}

fn okv(v: &Value) -> bool {
    v.get("ok").and_then(|x| x.as_bool()) == Some(true)
}

fn sql_fail(v: &Value) -> Resp {
    fail_code(v.get("error").and_then(|x| x.as_str()).unwrap_or("bad_input"))
}

fn sv<'a>(v: &'a Value, k: &str) -> &'a str {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("")
}

fn now_epoch() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

fn valid_uuid(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 36 && b.iter().enumerate().all(|(i, c)| if matches!(i, 8 | 13 | 18 | 23) { *c == b'-' } else { c.is_ascii_hexdigit() })
}

fn gate() -> &'static tokio::sync::Semaphore {
    static G: OnceLock<tokio::sync::Semaphore> = OnceLock::new();
    G.get_or_init(|| tokio::sync::Semaphore::new(4))
}

fn sha_hex(s: &str) -> String {
    Sha256::digest(s.as_bytes()).iter().map(|b| format!("{b:02x}")).collect()
}

// ── fetch ──
enum Fetched {
    NotModified,
    Body { text: String, etag: String, last_modified: String },
}

fn host_of(url: &str) -> &str {
    let r = url.strip_prefix("https://").unwrap_or(url);
    let a = r.split(['/', '?', '#']).next().unwrap_or("");
    a.split(':').next().unwrap_or("")
}

async fn resolve_public(host: &str) -> Result<std::net::SocketAddr, &'static str> {
    if let Ok(ip) = host.parse::<std::net::IpAddr>() {
        return if ics::ip_allowed(ip) { Ok(std::net::SocketAddr::new(ip, 443)) } else { Err("feed_blocked_address") };
    }
    let found = tokio::time::timeout(Duration::from_secs(5), tokio::net::lookup_host((host, 443u16))).await;
    let addrs: Vec<std::net::SocketAddr> = match found {
        Ok(Ok(it)) => it.collect(),
        Ok(Err(_)) => return Err("feed_dns"),
        Err(_) => return Err("feed_unreachable"),
    };
    if addrs.is_empty() {
        return Err("feed_dns");
    }
    // EK bhi private jawab ho to poora rad: attacker public + private dono de sakta hai
    if addrs.iter().any(|a| !ics::ip_allowed(a.ip())) {
        return Err("feed_blocked_address");
    }
    Ok(addrs[0])
}

async fn fetch(url0: &str, etag: &str, last_modified: &str) -> Result<Fetched, &'static str> {
    let _permit = gate().acquire().await.map_err(|_| "feed_unreachable")?;
    let mut url = ics::normalize_url(url0)?;
    for hop in 0..=3 {
        let host = host_of(&url).to_string();
        let addr = resolve_public(&host).await?;
        let client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .timeout(Duration::from_secs(10))
            .user_agent("ANEXOMAIL-Calendar/1 (+https://anexomail.com)")
            .resolve(&host, addr)
            .build()
            .map_err(|_| "feed_unreachable")?;
        let mut rq = client.get(&url).header("accept", "text/calendar, text/plain;q=0.5, */*;q=0.1");
        if hop == 0 {
            if !etag.is_empty() {
                rq = rq.header("if-none-match", etag);
            }
            if !last_modified.is_empty() {
                rq = rq.header("if-modified-since", last_modified);
            }
        }
        let mut resp = rq.send().await.map_err(|_| "feed_unreachable")?;
        match ics::plan_for_status(resp.status().as_u16()) {
            ics::FetchPlan::NotModified => return Ok(Fetched::NotModified),
            ics::FetchPlan::Fail(c) => return Err(c),
            ics::FetchPlan::Redirect => {
                let loc = resp.headers().get("location").and_then(|v| v.to_str().ok()).unwrap_or("").trim().to_string();
                if loc.is_empty() {
                    return Err("feed_bad_status");
                }
                let next = if loc.starts_with('/') { format!("https://{}{}", url.strip_prefix("https://").unwrap_or("").split('/').next().unwrap_or(""), loc) } else { loc };
                url = ics::normalize_url(&next)?; // naya hop bhi poori jaanch se
                continue;
            }
            ics::FetchPlan::Apply => {
                if resp.content_length().is_some_and(|n| n as usize > ics::MAX_FEED_BYTES) {
                    return Err("feed_too_big");
                }
                let et = resp.headers().get("etag").and_then(|v| v.to_str().ok()).unwrap_or("").chars().take(512).collect::<String>();
                let lm = resp.headers().get("last-modified").and_then(|v| v.to_str().ok()).unwrap_or("").chars().take(128).collect::<String>();
                let mut buf: Vec<u8> = Vec::new();
                loop {
                    match resp.chunk().await {
                        Ok(Some(c)) => {
                            if buf.len() + c.len() > ics::MAX_FEED_BYTES {
                                return Err("feed_too_big");
                            }
                            buf.extend_from_slice(&c);
                        }
                        Ok(None) => break,
                        Err(_) => return Err("feed_unreachable"),
                    }
                }
                let text = String::from_utf8_lossy(&buf).into_owned();
                if !ics::looks_like_ics(&text) {
                    return Err("feed_not_calendar");
                }
                return Ok(Fetched::Body { text, etag: et, last_modified: lm });
            }
        }
    }
    Err("feed_too_many_redirects")
}

fn events_json(events: &[ics::SubEvent]) -> Value {
    Value::Array(
        events
            .iter()
            .map(|e| {
                json!({ "uid": e.uid, "rid": e.rid, "title": e.title, "location": e.location, "description": e.description, "start_ts": e.start,
                        "duration_s": e.duration, "all_day": e.all_day, "tzid": e.tzid, "rrule": e.rrule, "exdates": e.exdates, "cancelled": e.cancelled })
            })
            .collect(),
    )
}

/// Ek feed ko taza karna. Ok((event_count, feed_name)) ya Err(code) — Err par SQL mein fail likha ja chuka hota hai.
async fn refresh_one(uid: &str, id: &str, url: &str, etag: &str, lm: &str, fails: i64, refresh_minutes: i64) -> Result<(i64, String), &'static str> {
    let backoff = |f: i64| ics::backoff_minutes(refresh_minutes, f);
    let record_fail = |code: &'static str| {
        let (uid, id) = (uid.to_string(), id.to_string());
        let b = backoff(fails + 1);
        async move {
            let _ = crate::sb_rpc("cal_sub_fail", json!({ "_user": uid, "_id": id, "_error": code, "_backoff_min": b })).await;
            code
        }
    };
    match fetch(url, etag, lm).await {
        Err(c) => Err(record_fail(c).await),
        Ok(Fetched::NotModified) => {
            let _ = crate::sb_rpc("cal_sub_notmodified", json!({ "_user": uid, "_id": id })).await;
            Ok((-1, String::new()))
        }
        Ok(Fetched::Body { text, etag, last_modified }) => {
            let now = now_epoch();
            let feed = match tokio::task::spawn_blocking(move || ics::parse_feed(&text, now)).await {
                Ok(f) => f,
                Err(_) => return Err(record_fail("feed_bad_status").await),
            };
            let st = &feed.stats;
            let stats = json!({ "found": st.found, "kept": st.kept, "recurring": st.recurring, "all_day": st.all_day, "cancelled": st.cancelled,
                "skipped_bad": st.skipped_bad, "skipped_old": st.skipped_old, "unknown_zone": st.unknown_zone, "floating_as_utc": st.floating_as_utc,
                "rrule_unreadable": st.rrule_unreadable, "truncated": st.truncated });
            let body = json!({ "_user": uid, "_id": id, "_etag": etag, "_lm": last_modified, "_name": feed.name, "_events": events_json(&feed.events), "_stats": stats });
            match crate::sb_rpc("cal_sub_apply", body).await {
                Ok(v) if okv(&v) => Ok((v.get("event_count").and_then(|x| x.as_i64()).unwrap_or(0), feed.name)),
                Ok(_) => Err(record_fail("too_many_events").await),
                Err(_) => Err("feed_unreachable"),
            }
        }
    }
}

/// Due feeds ko (ya ek `only` id ko) taza karna; sab spawn hoti hain, hum <= `wait` tak intezaar karte hain, baaqi peeche chalti rehti hain.
async fn refresh_due(uid: &str, only: Option<&str>, wait: Duration) -> Result<Vec<(String, Result<(i64, String), &'static str>)>, String> {
    let due = crate::sb_rpc("cal_sub_due", json!({ "_user": uid, "_id": only, "_limit": 3 })).await?;
    let rows = due.as_array().cloned().unwrap_or_default();
    let mut handles = Vec::new();
    for r in rows {
        let (uid, id, url) = (uid.to_string(), sv(&r, "id").to_string(), sv(&r, "url").to_string());
        let (etag, lm) = (sv(&r, "etag").to_string(), sv(&r, "last_modified").to_string());
        let fails = r.get("fail_count").and_then(|x| x.as_i64()).unwrap_or(0);
        let rm = r.get("refresh_minutes").and_then(|x| x.as_i64()).unwrap_or(60);
        let id2 = id.clone();
        handles.push((id2, tokio::spawn(async move { refresh_one(&uid, &id, &url, &etag, &lm, fails, rm).await })));
    }
    let mut out = Vec::new();
    let _ = tokio::time::timeout(wait, async {
        for (id, h) in handles {
            if let Ok(r) = h.await {
                out.push((id, r));
            }
        }
    })
    .await;
    Ok(out)
}

fn civil(epoch: i64) -> String {
    cal::fmt_rfc3339(epoch).chars().take(10).collect()
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let (uid, _email) = match crate::auth_user(token).await {
        Some(x) => x,
        None => return crate::err(StatusCode::UNAUTHORIZED, "unauthorized", "").into_response(),
    };
    match proc {
        "calendar.sub.add" => {
            let url = match ics::normalize_url(sv(input, "url")) {
                Ok(u) => u,
                Err(c) => return fail_code(c),
            };
            // pehle hi bata do ki address public hai (fetch se pehle, saaf wajah)
            if let Err(c) = resolve_public(host_of(&url)).await {
                return fail_code(c);
            }
            let refresh = input.get("refresh_minutes").and_then(|x| x.as_i64()).unwrap_or(60).clamp(15, 1440);
            let added = match crate::sb_rpc(
                "cal_sub_add",
                json!({ "_user": uid, "_url": url, "_hash": sha_hex(&url), "_name": sv(input, "name"), "_color": sv(input, "color"), "_refresh": refresh }),
            )
            .await
            {
                Ok(v) => v,
                Err(e) => return db_err(&e),
            };
            if !okv(&added) {
                return sql_fail(&added);
            }
            let id = sv(&added, "id").to_string();
            let res = match refresh_due(&uid, Some(&id), Duration::from_secs(12)).await {
                Ok(r) => r,
                Err(e) => {
                    let _ = crate::sb_rpc("cal_sub_remove", json!({ "_user": uid, "_id": id })).await;
                    return db_err(&e);
                }
            };
            match res.into_iter().next() {
                Some((_, Ok((n, name)))) => crate::ok(json!({ "id": id, "name": name, "event_count": n.max(0) })).into_response(),
                Some((_, Err(code))) => {
                    // pehli fetch fail: aisa feed rakhne ka koi fayda nahi — hata do, saaf wajah batao
                    let _ = crate::sb_rpc("cal_sub_remove", json!({ "_user": uid, "_id": id })).await;
                    fail_code(code)
                }
                None => {
                    let _ = crate::sb_rpc("cal_sub_remove", json!({ "_user": uid, "_id": id })).await;
                    fail_code("feed_unreachable")
                }
            }
        }
        "calendar.sub.list" => match crate::sb_rpc("cal_sub_list", json!({ "_user": uid })).await {
            Ok(v) => crate::ok(json!({ "subs": v })).into_response(),
            Err(e) => db_err(&e),
        },
        "calendar.sub.update" => {
            let id = sv(input, "id");
            if !valid_uuid(id) {
                return fail_code("bad_input");
            }
            let body = json!({ "_user": uid, "_id": id, "_name": input.get("name").and_then(|x| x.as_str()), "_color": input.get("color").and_then(|x| x.as_str()),
                "_enabled": input.get("enabled").and_then(|x| x.as_bool()), "_refresh": input.get("refresh_minutes").and_then(|x| x.as_i64()) });
            match crate::sb_rpc("cal_sub_update", body).await {
                Ok(v) if okv(&v) => crate::ok(json!({ "ok": true })).into_response(),
                Ok(v) => sql_fail(&v),
                Err(e) => db_err(&e),
            }
        }
        "calendar.sub.remove" => {
            let id = sv(input, "id");
            if !valid_uuid(id) {
                return fail_code("bad_input");
            }
            match crate::sb_rpc("cal_sub_remove", json!({ "_user": uid, "_id": id })).await {
                Ok(v) if okv(&v) => crate::ok(json!({ "ok": true })).into_response(),
                Ok(v) => sql_fail(&v),
                Err(e) => db_err(&e),
            }
        }
        "calendar.sub.refresh" => {
            let id = sv(input, "id");
            if !valid_uuid(id) {
                return fail_code("bad_input");
            }
            match refresh_due(&uid, Some(id), Duration::from_secs(12)).await {
                Ok(r) => match r.into_iter().next() {
                    Some((_, Ok((n, _)))) => crate::ok(json!({ "ok": true, "event_count": n.max(0) })).into_response(),
                    Some((_, Err(code))) => fail_code(code),
                    None => fail_code("refresh_too_soon"),
                },
                Err(e) => db_err(&e),
            }
        }
        "calendar.sub.events" => {
            let (Some(from), Some(to)) = (cal::parse_ts(sv(input, "from")), cal::parse_ts(sv(input, "to"))) else {
                return fail_code("range_invalid");
            };
            if to <= from || to - from > 100 * 86_400 {
                return fail_code("range_invalid");
            }
            if let Err(e) = refresh_due(&uid, None, Duration::from_secs(6)).await {
                return db_err(&e);
            }
            let data = match crate::sb_rpc("cal_sub_events", json!({ "_user": uid, "_from": from, "_to": to })).await {
                Ok(v) => v,
                Err(e) => return db_err(&e),
            };
            let subs = data.get("subs").cloned().unwrap_or(json!([]));
            let rows = data.get("events").and_then(|x| x.as_array()).cloned().unwrap_or_default();
            let mut events: Vec<ics::SubEvent> = Vec::with_capacity(rows.len());
            let mut owner: Vec<String> = Vec::with_capacity(rows.len());
            for r in &rows {
                events.push(ics::SubEvent {
                    uid: sv(r, "uid").to_string(),
                    rid: r.get("rid").and_then(|x| x.as_i64()).unwrap_or(0),
                    title: sv(r, "title").to_string(),
                    location: sv(r, "location").to_string(),
                    description: sv(r, "description").to_string(),
                    start: r.get("start_ts").and_then(|x| x.as_i64()).unwrap_or(0),
                    duration: r.get("duration_s").and_then(|x| x.as_i64()).unwrap_or(0),
                    all_day: r.get("all_day").and_then(|x| x.as_bool()).unwrap_or(false),
                    tzid: sv(r, "tzid").to_string(),
                    rrule: sv(r, "rrule").to_string(),
                    exdates: r.get("exdates").and_then(|x| x.as_array()).map(|a| a.iter().filter_map(|x| x.as_i64()).collect()).unwrap_or_default(),
                    cancelled: r.get("cancelled").and_then(|x| x.as_bool()).unwrap_or(false),
                });
                owner.push(sv(r, "sub_id").to_string());
            }
            // uid sirf ek feed ke andar milta hai: overrides ko doosre feed ke master se na milao
            let mut out: Vec<Value> = Vec::new();
            let subs_arr = subs.as_array().cloned().unwrap_or_default();
            let mut sub_ids: Vec<String> = owner.clone();
            sub_ids.sort();
            sub_ids.dedup();
            for sid in sub_ids {
                let idx: Vec<usize> = (0..events.len()).filter(|i| owner[*i] == sid).collect();
                let subset: Vec<ics::SubEvent> = idx.iter().map(|i| events[*i].clone()).collect();
                let meta = subs_arr.iter().find(|s| sv(s, "id") == sid);
                let (name, color) = meta.map(|m| (sv(m, "name").to_string(), sv(m, "color").to_string())).unwrap_or_default();
                for o in ics::occurrences(&subset, from, to) {
                    let e = &subset[o.index];
                    let mut item = json!({ "sub_id": sid, "sub_name": name, "color": color, "uid": e.uid, "title": e.title, "location": e.location,
                        "description": e.description, "start": cal::fmt_rfc3339(o.start), "end": cal::fmt_rfc3339(o.end), "all_day": e.all_day });
                    if e.all_day {
                        item["date"] = json!(civil(o.start));
                        item["end_date"] = json!(civil(o.end.max(o.start + 86_400)));
                    }
                    out.push(item);
                }
            }
            out.sort_by(|a, b| sv(a, "start").cmp(sv(b, "start")));
            out.truncate(ics::MAX_OCC);
            crate::ok(json!({ "subs": subs, "events": out })).into_response()
        }
        _ => crate::err(StatusCode::NOT_FOUND, "unknown_proc", proc).into_response(),
    }
}
