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
async fn sb_select(p: &str) -> Result<Value, String> {
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
    println!("ALL FEED HANDLER CHECKS PASSED");
}
