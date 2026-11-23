// ANEXOMAIL ADMIN DESK deliverability.rs (phase 1m-5, card B6 Deliverability, 23 Nov 2026). Rust + Axum + Tokio + HTTP/3 client. List: D6-CARDS-LIST-23NOV.md (section B6, U1..U8).
// ONE door over the sealed router (Rule 52) and a live Desk session, built exactly like the customers door. Order is fixed: 1) PostgreSQL AD15 fadm_deliv_begin checks the right (customer.lookup on the Desk department) and writes ONE ledger line per ten minutes,
// 2) a signed read-only request goes to the Control Plane (own audience desk-deliv, no input, 60 s expiry, HTTP/3), 3) the signed answer is verified (its own key, same request id, fresh, not older than the request, kind deliverability) and its SHAPE and
// INTERNAL SUMS are checked here too, 4) AD15 fadm_deliv_record writes this hour once and returns the 24-hour line. Counts only: never a domain name, company id, token or e-mail.
// FAIL CLOSED: no address, no key, bad signature, stale, wrong id, wrong shape, wrong sums, database down = "data_unavailable" (503); a number is never made up and zero is data. Desk-only: no founder or awam code.
use crate::bridge::owner;
use crate::customers::{series_shape_ok, Reject};
use crate::door::{lit, rows};
use crate::lookup::{cp_pub, plane, uuid4, Breaker, Plane, ANS_DOMAIN, DEADLINE_SECS, EXPIRY, FRESH, REQ_DOMAIN};
use crate::sign::{unhex, Signer};
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::{json, Value};

pub const AUD_DELIV: &str = "desk-deliv";
pub const DELIV_PATH: &str = "/control/v1/deliverability";
const SIGNALS: [&str; 6] = ["spf_missing", "dkim_missing", "dmarc_missing", "mx_missing", "stale_check", "pending_7d"];

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

/// The signed read-only request: {"kid","body","sig"}. It carries NO input field at all.
pub fn build_request(s: &Signer, request_id: &str, employee: &str, now: i64) -> String {
    let body = json!({"aud": AUD_DELIV, "method": "read", "request_id": request_id, "employee_id": employee, "reason": "deliverability board opened", "issued_at": now, "expires_at": now + EXPIRY}).to_string();
    let sig = s.sign_raw(format!("{REQ_DOMAIN}\n{body}").as_bytes());
    json!({"kid": s.kid(), "body": body, "sig": sig}).to_string()
}

/// Verify the Control Plane answer; anything wrong = Unavailable (fail closed). `issued` = the request's own issued_at (2 s clock skew allowed).
pub fn accept(env: &str, cp_pub_hex: &str, request_id: &str, issued: i64, now: i64) -> Result<Value, Reject> {
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};
    let e: Value = serde_json::from_str(env).map_err(|_| Reject::Unavailable)?;
    let body = e["body"].as_str().ok_or(Reject::Unavailable)?;
    let sig = unhex(e["sig"].as_str().ok_or(Reject::Unavailable)?).ok_or(Reject::Unavailable)?;
    let vk = unhex(cp_pub_hex).and_then(|b| <[u8; 32]>::try_from(b).ok()).and_then(|b| VerifyingKey::from_bytes(&b).ok()).ok_or(Reject::Unavailable)?;
    let sig = Signature::from_slice(&sig).map_err(|_| Reject::Unavailable)?;
    vk.verify(format!("{ANS_DOMAIN}\n{body}").as_bytes(), &sig).map_err(|_| Reject::Unavailable)?;
    let b: Value = serde_json::from_str(body).map_err(|_| Reject::Unavailable)?;
    if b["kind"].as_str() != Some("deliverability") || b["request_id"].as_str() != Some(request_id) { return Err(Reject::Unavailable); }
    let at = b["answered_at"].as_i64().ok_or(Reject::Unavailable)?;
    if at > now + 5 || now - at > FRESH || at < issued - 2 { return Err(Reject::Unavailable); }
    if b["refused"].as_bool() == Some(true) { return Err(Reject::Refused); }
    let d = b.get("deliverability").cloned().ok_or(Reject::Unavailable)?;
    if shape_ok(&d) { Ok(d) } else { Err(Reject::Unavailable) }
}

fn n(v: &Value, k: &str) -> i64 { v.get(k).and_then(|x| x.as_i64()).unwrap_or(-1) }
fn group(v: &Value, keys: &[&str]) -> Option<Vec<i64>> {
    let o = v.as_object()?; if o.len() != keys.len() { return None; }
    keys.iter().map(|k| o.get(*k).and_then(|x| x.as_i64()).filter(|x| *x >= 0)).collect()
}
/// The shape the card relies on: closed key lists, no negative number, every part within its whole, and the six signals must equal the numbers they are made from. No personal field is allowed anywhere.
pub fn shape_ok(v: &Value) -> bool {
    let Some(o) = v.as_object() else { return false };
    let keys = ["generated_at", "domains", "companies", "status", "posture", "never_checked", "stale_24h", "pending_7d", "companies_failing", "signals"];
    if o.len() != keys.len() || keys.iter().any(|k| !o.contains_key(*k)) { return false; }
    if !v["generated_at"].as_str().map(|s| !s.is_empty() && s.len() <= 40).unwrap_or(false) { return false; }
    let (domains, companies) = (n(v, "domains"), n(v, "companies"));
    let (never, stale, p7, failing) = (n(v, "never_checked"), n(v, "stale_24h"), n(v, "pending_7d"), n(v, "companies_failing"));
    if [domains, companies, never, stale, p7, failing].iter().any(|x| *x < 0) { return false; }
    let Some(st) = group(&v["status"], &["pending", "verified"]) else { return false };
    let Some(po) = group(&v["posture"], &["spf", "dkim", "dmarc", "mx", "all_ok"]) else { return false };
    let (pending, verified) = (st[0], st[1]);
    if pending + verified != domains || companies > domains || never > domains || stale > verified || p7 > pending || failing > companies { return false; }
    if po.iter().any(|x| *x > verified) || po[4] > po[0].min(po[1]).min(po[2]).min(po[3]) { return false; }
    let want = [verified - po[0], verified - po[1], verified - po[2], verified - po[3], stale, p7];
    v["signals"].as_array().map(|a| a.len() == SIGNALS.len() && a.iter().zip(SIGNALS.iter()).zip(want.iter()).all(|((s, k), w)| {
        s.as_object().map(|m| m.len() == 4).unwrap_or(false) && s["key"].as_str() == Some(*k)
            && s["label"].as_str().map(|l| !l.is_empty() && l.len() <= 80).unwrap_or(false)
            && (s["runbook"].is_null() || s["runbook"].as_str().map(|r| !r.is_empty() && r.len() <= 80).unwrap_or(false))
            && s["count"].as_i64() == Some(*w)
    })).unwrap_or(false)
}

static BREAKER: std::sync::OnceLock<Breaker> = std::sync::OnceLock::new();
fn breaker() -> &'static Breaker { BREAKER.get_or_init(Breaker::default) }
async fn ask_bounded(p: &Plane, env: &str, secs: u64) -> Option<String> { tokio::time::timeout(std::time::Duration::from_secs(secs), p.ask_path(DELIV_PATH, env)).await.ok().flatten() }

/// POST /desk/v1/deliverability/board  (empty body)
pub async fn board(h: HeaderMap, body: Bytes) -> Response {
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    run(&h, &plane(), &cp_pub(), crate::signed::now_secs(), breaker()).await
}

pub(crate) async fn run(h: &HeaderMap, p: &Plane, cp_key: &str, now: i64, brk: &Breaker) -> Response {
    let (c, who) = match tokio::time::timeout(std::time::Duration::from_secs(DEADLINE_SECS), owner(h)).await {
        Err(_) => { eprintln!("desk deliverability: session check timed out"); return unavailable() }
        Ok(Err(r)) => return r,
        Ok(Ok(x)) => x,
    };
    match rows(&c, &format!("select desk.fadm_deliv_begin('{who}'::uuid)::text")).await {
        Ok(v) => if v.first().and_then(|r| r.get(0)).is_none() { return err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk deliverability: db: {e}"); return unavailable() }
    }
    let Some(s) = crate::signed::signer() else { return unavailable() };
    let rid = uuid4(); let env = build_request(s, &rid, &who, now);
    let started = std::time::Instant::now(); let go = brk.allow(now);
    let asked = if go { ask_bounded(p, &env, DEADLINE_SECS).await } else { eprintln!("desk deliverability: breaker open"); None };
    let Some(ans) = asked else { if go { brk.fail(now); } return unavailable() };
    let now2 = now + started.elapsed().as_secs() as i64;
    match accept(&ans, cp_key, &rid, now, now2) {
        Ok(d) => {
            brk.ok();
            let q = format!("select desk.fadm_deliv_record('{who}'::uuid, {}::jsonb)::text", lit(&d.to_string()));
            match rows(&c, &q).await {
                Ok(v) => match v.first().and_then(|r| r.get(0)).and_then(|j| serde_json::from_str::<Value>(j).ok()) {
                    Some(sr) if series_shape_ok(&sr) => out(StatusCode::OK, json!({"deliverability": d, "series": sr}).to_string()),
                    Some(_) => { eprintln!("desk deliverability: wrong series shape"); unavailable() }
                    None => err(StatusCode::FORBIDDEN, "not_allowed") },
                Err(e) => { eprintln!("desk deliverability: record: {e}"); unavailable() }
            }
        }
        Err(Reject::Refused) => { brk.ok(); unavailable() }
        Err(Reject::Unavailable) => { brk.fail(now); unavailable() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signer as _, SigningKey};
    const SEED: &str = "0101010101010101010101010101010101010101010101010101010101010101";
    const RID: &str = "11111111-2222-4333-8444-555555555555";
    fn hexs(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
    fn cp() -> (SigningKey, String) { let k = SigningKey::from_bytes(&[7u8; 32]); let p = hexs(k.verifying_key().as_bytes()); (k, p) }
    fn good() -> Value {
        // verified 3, pending 1: spf 2, dkim 1, dmarc 3, mx 3, all_ok 1; stale 2; pending over 7 days 1
        let c = [1, 2, 0, 0, 2, 1]; let l = ["a", "b", "c", "d", "e", "f"];
        let sig: Vec<Value> = SIGNALS.iter().enumerate().map(|(i, k)| json!({"key": k, "label": l[i], "runbook": if i < 4 { json!("Email not delivered") } else { Value::Null }, "count": c[i]})).collect();
        json!({"generated_at": "2026-11-23T08:00:00Z", "domains": 4, "companies": 2, "status": {"pending": 1, "verified": 3}, "posture": {"spf": 2, "dkim": 1, "dmarc": 3, "mx": 3, "all_ok": 1},
               "never_checked": 1, "stale_24h": 2, "pending_7d": 1, "companies_failing": 2, "signals": sig})
    }
    fn answer(k: &SigningKey, kind: &str, rid: &str, at: i64, d: Value, refused: bool) -> String {
        let body = json!({"kind": kind, "request_id": rid, "answered_at": at, "deliverability": d, "refused": refused}).to_string();
        json!({"body": body, "sig": hexs(&k.sign(format!("{ANS_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    #[test] fn good_shape_passes_and_zero_is_data() {
        assert!(shape_ok(&good()));
        let mut z = good(); z["domains"] = json!(0); z["companies"] = json!(0);
        z["status"] = json!({"pending": 0, "verified": 0}); z["posture"] = json!({"spf": 0, "dkim": 0, "dmarc": 0, "mx": 0, "all_ok": 0});
        z["never_checked"] = json!(0); z["stale_24h"] = json!(0); z["pending_7d"] = json!(0); z["companies_failing"] = json!(0);
        for s in z["signals"].as_array_mut().unwrap() { s["count"] = json!(0); }
        assert!(shape_ok(&z), "no domain yet is a real answer");
    }
    #[test] fn wrong_shapes_and_sums_are_refused() {
        let bad = |f: &dyn Fn(&mut Value)| { let mut v = good(); f(&mut v); assert!(!shape_ok(&v)); };
        bad(&|v| v["status"]["pending"] = json!(2));
        bad(&|v| v["domains"] = json!(-1));
        bad(&|v| v["companies"] = json!(9));
        bad(&|v| v["posture"]["spf"] = json!(4));
        bad(&|v| v["posture"]["all_ok"] = json!(2));
        bad(&|v| v["stale_24h"] = json!(4));
        bad(&|v| v["pending_7d"] = json!(2));
        bad(&|v| v["companies_failing"] = json!(3));
        bad(&|v| v["signals"][0]["count"] = json!(0));
        bad(&|v| { v["signals"].as_array_mut().unwrap().swap(0, 1); });
        bad(&|v| v["signals"][0]["domain"] = json!("acme.example"));
        bad(&|v| { v["signals"].as_array_mut().unwrap().pop(); });
        bad(&|v| v["domain_names"] = json!(["acme.example"]));
        bad(&|v| { v.as_object_mut().unwrap().remove("never_checked"); });
        assert!(!shape_ok(&json!(null)) && !shape_ok(&json!({})));
    }
    #[test] fn request_is_signed_audience_bound_has_no_input_and_expires_in_60s() {
        use ed25519_dalek::{Signature, Verifier, VerifyingKey};
        let s = Signer::from_seed_hex(SEED).unwrap();
        let env: Value = serde_json::from_str(&build_request(&s, RID, "emp-1", 1000)).unwrap();
        let body = env["body"].as_str().unwrap(); let b: Value = serde_json::from_str(body).unwrap();
        assert_eq!(b["aud"], "desk-deliv"); assert_eq!(b["method"], "read"); assert!(b.get("limits").is_none());
        assert_eq!(b["expires_at"].as_i64().unwrap() - b["issued_at"].as_i64().unwrap(), 60);
        let vk = VerifyingKey::from_bytes(&unhex(&s.public_hex()).unwrap().try_into().unwrap()).unwrap();
        let sig = Signature::from_slice(&unhex(env["sig"].as_str().unwrap()).unwrap()).unwrap();
        assert!(vk.verify(format!("{REQ_DOMAIN}\n{body}").as_bytes(), &sig).is_ok());
        assert!(vk.verify(format!("anexo-desk-v1\n{body}").as_bytes(), &sig).is_err());
    }
    #[test] fn accept_good_and_refuse_every_bad_answer() {
        let (k, p) = cp(); let other = SigningKey::from_bytes(&[9u8; 32]);
        assert_eq!(accept(&answer(&k, "deliverability", RID, 1000, good(), false), &p, RID, 1000, 1005).unwrap()["domains"], 4);
        let un = |a: String, now: i64| assert_eq!(accept(&a, &p, RID, 1000, now), Err(Reject::Unavailable));
        un(answer(&other, "deliverability", RID, 1000, good(), false), 1005);
        un(answer(&k, "census", RID, 1000, good(), false), 1005);
        un(answer(&k, "deliverability", "99999999-2222-4333-8444-555555555555", 1000, good(), false), 1005);
        un(answer(&k, "deliverability", RID, 1000, good(), false), 1100);
        un(answer(&k, "deliverability", RID, 990, good(), false), 1005);
        un(answer(&k, "deliverability", RID, 1000, json!({"domains": 1}), false), 1005);
        un("garbage".into(), 1005);
        assert_eq!(accept(&answer(&k, "deliverability", RID, 1000, Value::Null, true), &p, RID, 1000, 1005), Err(Reject::Refused));
        assert_eq!(accept(&answer(&k, "deliverability", RID, 1000, good(), false), &hexs(&[1u8; 32]), RID, 1000, 1005), Err(Reject::Unavailable));
    }
    #[tokio::test] async fn double_plane_round_trip_uses_the_deliverability_path() {
        let (k, p) = cp(); let s = Signer::from_seed_hex(SEED).unwrap();
        let env = build_request(&s, RID, "emp-1", 1000); let ans = answer(&k, "deliverability", RID, 1000, good(), false);
        let pl = Plane::Double(Box::new(move |_| Some(ans.clone())));
        let got = ask_bounded(&pl, &env, 2).await.unwrap();
        assert!(accept(&got, &p, RID, 1000, 1002).is_ok());
        assert!(ask_bounded(&Plane::Off, &env, 2).await.is_none());
    }
}
