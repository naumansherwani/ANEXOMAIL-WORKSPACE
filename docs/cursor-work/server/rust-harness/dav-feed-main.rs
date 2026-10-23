#![allow(dead_code)]
use axum::{body::Body, http::{Request, StatusCode}, response::IntoResponse, Json};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
#[path = "@R@/cal_core.rs"] mod cal_core;
#[path = "@R@/dav_core.rs"] mod dav_core;
#[path = "@R@/dav_glue.rs"] mod dav_glue;
const PEP: &str = "test-pepper-test-pepper-1234";
const TID: &str = "abcdefghij";
const SECRET: &str = "klmnopqrst234567uvwx";
const EV: &str = "0f8fad5b-d9cb-469f-a165-70867728950e";
fn ok(data: Value) -> impl IntoResponse { (StatusCode::OK, Json(json!({ "result": { "data": data } }))) }
fn err(status: StatusCode, code: &str, message: &str) -> impl IntoResponse + use<> { (status, Json(json!({ "error": { "code": code, "message": message } }))) }
fn env_var(key: &str) -> String { if key == "CALDAV_PEPPER" { PEP.into() } else { std::env::var(key).unwrap_or_default() } }
fn hash() -> String { let mut h = Sha256::new(); h.update(PEP.as_bytes()); h.update(SECRET.as_bytes()); h.finalize().iter().map(|b| format!("{b:02x}")).collect() }
async fn sb_rpc(f: &str, b: Value) -> Result<Value, String> {
    Ok(match f {
        "caldav_feed_lookup" if b["p_token_id"] == TID => json!({"id":"11111111-1111-1111-1111-111111111111","user_id":"u","org_id":"22222222-2222-2222-2222-222222222222","email":"Me@X.test","secret_hash":hash()}),
        "caldav_ctag" => json!(7),
        _ => Value::Null,
    })
}
static BIG: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
const BIG_MINE: usize = 2600; // organiser main hoon
const BIG_INVITED: usize = 150; // sirf guest
fn big_id(i: usize) -> String { format!("00000000-0000-4000-8000-{i:012}") }
/// Nakli backend jo asli PostgREST jaisa chalta hai: server-side max-rows 1000, limit/offset, in.(..), aur URL ki lambai ka khayal.
fn big(p: &str) -> Result<Value, String> {
    assert!(p.len() < 4000, "URL bohot lamba ({} bytes) — in.(...) chunk nahi hua", p.len());
    let (table, q) = p.split_once('?').unwrap_or((p, ""));
    let prm = |k: &str| q.split('&').find_map(|kv| kv.strip_prefix(&format!("{k}=")));
    let limit = prm("limit").and_then(|v| v.parse::<usize>().ok()).unwrap_or(1000).min(1000);
    let offset = prm("offset").and_then(|v| v.parse::<usize>().ok()).unwrap_or(0);
    let ids_in = |k: &str| -> Option<Vec<String>> { prm(k).and_then(|v| v.strip_prefix("in.(")).map(|v| v.trim_end_matches(')').split(',').map(|x| x.to_string()).collect()) };
    let ev = |i: usize| json!({"id":big_id(i),"title":format!("Meeting {i}"),"starts_at":"2026-10-24T09:00:00Z","ends_at":"2026-10-24T10:00:00Z","organiser": if i < BIG_MINE {"me@x.test"} else {"boss@x.test"},"tz":"","tz_offset_min":0,"dav_rev":1,"dav_updated_at":"2026-10-23T05:00:00Z","status":"confirmed","sequence":0});
    let rows: Vec<Value> = match table {
        "calendar_attendees" => {
            if prm("address").is_some() { (BIG_MINE..BIG_MINE + BIG_INVITED).map(|i| json!({"event_id":big_id(i),"address":"me@x.test"})).collect() }
            else if let Some(ids) = ids_in("event_id") { ids.iter().map(|id| json!({"event_id":id,"address":"g@x.test","display_name":"G","role":"required","response":"accepted"})).collect() }
            else { vec![] }
        }
        "calendar_events" => {
            if prm("organiser").is_some() { (0..BIG_MINE).map(ev).collect() }
            else if let Some(ids) = ids_in("id") { ids.iter().filter_map(|id| id.rsplit('-').next().and_then(|n| n.parse::<usize>().ok())).map(ev).collect() }
            else { vec![] }
        }
        _ => vec![],
    };
    Ok(Value::Array(rows.into_iter().skip(offset).take(limit).collect()))
}
async fn sb_select(p: &str) -> Result<Value, String> {
    if BIG.load(std::sync::atomic::Ordering::Relaxed) { return big(p); }
    Ok(if p.starts_with("calendar_events?select=*&org_id=") {
        json!([{"id":EV,"title":"Board, review; Q4","starts_at":"2026-10-24T09:00:00Z","ends_at":"2026-10-24T10:00:00Z","organiser":"me@x.test","tz":"","tz_offset_min":0,"dav_rev":3,"dav_updated_at":"2026-10-23T05:00:00Z","status":"confirmed","sequence":1}])
    } else { json!([]) })
}
struct MailMe { id: String, email: String, org_id: String }
async fn mail_identity(_t: &str, _o: &str) -> Result<MailMe, (StatusCode, &'static str, String)> { Err((StatusCode::UNAUTHORIZED, "x", "y".into())) }

async fn call(method: &str, path: &str, inm: Option<&str>) -> (StatusCode, axum::http::HeaderMap, String) {
    let mut r = Request::builder().method(method).uri(path);
    if let Some(v) = inm { r = r.header("if-none-match", v); }
    let resp = dav_glue::handle(r.body(Body::empty()).unwrap()).await;
    let (p, b) = resp.into_parts();
    (p.status, p.headers, String::from_utf8_lossy(&axum::body::to_bytes(b, 1 << 22).await.unwrap()).to_string())
}
#[tokio::main]
async fn main() {
    let good = format!("/dav/feed/{TID}{SECRET}.ics");
    let (s, h, b) = call("GET", &good, None).await;
    println!("GET good -> {s}  ct={:?} etag={:?} cc={:?} ref={:?} robots={:?}", h["content-type"], h["etag"], h["cache-control"], h["referrer-policy"], h["x-robots-tag"]);
    assert_eq!(s, StatusCode::OK);
    assert!(b.starts_with("BEGIN:VCALENDAR\r\n") && b.ends_with("END:VCALENDAR\r\n"), "{b}");
    assert!(b.contains("METHOD:PUBLISH") && !b.contains("METHOD:REQUEST"));
    assert_eq!(b.matches("BEGIN:VEVENT").count(), 1);
    assert!(b.contains("UID:") && b.contains(r"SUMMARY:Board\, review\; Q4"), "{b}");
    println!("---- feed body ----\n{b}");
    let et = h["etag"].to_str().unwrap().to_string();
    let (s, _, b) = call("GET", &good, Some(&et)).await;
    println!("GET If-None-Match -> {s}"); assert_eq!(s, StatusCode::NOT_MODIFIED); assert!(b.is_empty());
    let (s, _, b) = call("HEAD", &good, None).await; println!("HEAD -> {s}"); assert_eq!(s, StatusCode::OK); assert!(b.is_empty());
    let (s, _, _) = call("GET", &format!("/dav/feed/{TID}aaaaaaaaaaaaaaaaaaaa.ics"), None).await; println!("wrong secret -> {s}"); assert_eq!(s, StatusCode::NOT_FOUND);
    let (s, _, _) = call("GET", "/dav/feed/zzzzzzzzzzaaaaaaaaaaaaaaaaaaaa.ics", None).await; println!("unknown token -> {s}"); assert_eq!(s, StatusCode::NOT_FOUND);
    let (s, _, _) = call("GET", "/dav/feed/short.ics", None).await; println!("bad shape -> {s}"); assert_eq!(s, StatusCode::NOT_FOUND); let (s2, _, _) = call("GET", "/dav/feed/", None).await; assert_eq!(s2, StatusCode::NOT_FOUND);
    for m in ["POST", "PUT", "DELETE", "PROPFIND", "REPORT"] { let (s, _, _) = call(m, &good, None).await; println!("{m} -> {s}"); assert!(s == StatusCode::METHOD_NOT_ALLOWED || (m=="PROPFIND"||m=="REPORT") && s == StatusCode::METHOD_NOT_ALLOWED, "{m} {s}"); }
    let (s, h, _) = call("OPTIONS", &good, None).await; println!("OPTIONS -> {s} allow={:?}", h.get("allow")); assert_eq!(s, StatusCode::OK);
    let (s, _, _) = call("GET", "/dav/c/personal/", None).await; println!("basic path w/o auth -> {s}"); assert_eq!(s, StatusCode::UNAUTHORIZED);
    // ── bara user: 2600 apne + 150 bulaye hue meeting; backend max 1000 row/page deta hai; URL kabhi lamba nahi
    BIG.store(true, std::sync::atomic::Ordering::Relaxed);
    let (s, _, b) = call("GET", &good, None).await;
    let n = b.matches("BEGIN:VEVENT").count();
    println!("BIG feed -> {s}  events={n} (chahiye {})", BIG_MINE + BIG_INVITED);
    assert_eq!(s, StatusCode::OK);
    assert_eq!(n, BIG_MINE + BIG_INVITED, "koi meeting gum hui");
    assert!(b.contains("Meeting 0\r\n") && b.contains("Meeting 2749\r\n"), "pehli aur aakhri meeting dono honi chahiye");
    assert_eq!(b.matches("ATTENDEE").count(), BIG_MINE + BIG_INVITED, "har meeting ka guest judna chahiye");
    println!("ALL FEED HANDLER CHECKS PASSED");
}
