// ANEXOMAIL ADMIN DESK customers.rs (phase 1m-4, card B9 Customers and Plans, 23 Nov 2026). Rust + Axum + Tokio + HTTP/3 client. List: D6-CARDS-LIST-23NOV.md (U7..U11).
// ONE door over the sealed router (Rule 52) and a live Desk session. Order is fixed: 1) PostgreSQL AD14 fadm_customers_begin checks the right (customer.lookup on the Desk department), writes ONE ledger line per ten minutes
// and hands over the seat promise of each package, 2) a signed read-only census request goes to the Control Plane (own audience desk-census, 60 s expiry, HTTP/3), 3) the signed answer is verified (its own key, same request id,
// fresh, not older than the request, kind census) and its SHAPE is checked here too, 4) AD14 fadm_census_record writes this hour once and returns the 24-hour line. Counts only: never a company name, e-mail, domain or person.
// FAIL CLOSED: no address, no key, bad signature, stale, wrong id, wrong shape, database down = "data_unavailable" (503); a number is never made up and zero is data. Desk-only: no founder or awam code.
use crate::bridge::owner;
use crate::door::{lit, rows};
use crate::lookup::{plane, cp_pub, uuid4, Breaker, Plane, ANS_DOMAIN, REQ_DOMAIN, DEADLINE_SECS, EXPIRY, FRESH};
use crate::sign::{unhex, Signer};
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::{json, Value};

pub const AUD_CENSUS: &str = "desk-census";
pub const CENSUS_PATH: &str = "/control/v1/census";
const PKGS: [&str; 6] = ["basic", "pro", "business", "business_pro", "business_premium", "business_max"];
const PKG_ALL: [&str; 8] = ["basic", "pro", "business", "business_pro", "business_premium", "business_max", "none", "unknown"];
const SIGNALS: [&str; 8] = ["grace_period", "not_active_yet", "ended", "payment_received_not_active", "seats_90", "seats_95", "storage_90", "storage_95"];

fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

/// The signed read-only census request: {"kid","body","sig"}; the body travels as a string so the exact signed bytes arrive.
pub fn build_census_request(s: &Signer, request_id: &str, employee: &str, limits: &Value, now: i64) -> String {
    let body = json!({"aud": AUD_CENSUS, "method": "read", "request_id": request_id, "employee_id": employee, "reason": "customers and plans board opened", "limits": limits, "issued_at": now, "expires_at": now + EXPIRY}).to_string();
    let sig = s.sign_raw(format!("{REQ_DOMAIN}\n{body}").as_bytes());
    json!({"kid": s.kid(), "body": body, "sig": sig}).to_string()
}

#[derive(Debug, PartialEq)]
pub enum Reject { Unavailable, Refused }
/// Verify the Control Plane census answer; anything wrong = Unavailable (fail closed). `issued` = the request's own issued_at (2 s clock skew allowed).
pub fn accept_census(env: &str, cp_pub_hex: &str, request_id: &str, issued: i64, now: i64) -> Result<Value, Reject> {
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};
    let e: Value = serde_json::from_str(env).map_err(|_| Reject::Unavailable)?;
    let body = e["body"].as_str().ok_or(Reject::Unavailable)?;
    let sig = unhex(e["sig"].as_str().ok_or(Reject::Unavailable)?).ok_or(Reject::Unavailable)?;
    let vk = unhex(cp_pub_hex).and_then(|b| <[u8; 32]>::try_from(b).ok()).and_then(|b| VerifyingKey::from_bytes(&b).ok()).ok_or(Reject::Unavailable)?;
    let sig = Signature::from_slice(&sig).map_err(|_| Reject::Unavailable)?;
    vk.verify(format!("{ANS_DOMAIN}\n{body}").as_bytes(), &sig).map_err(|_| Reject::Unavailable)?;
    let b: Value = serde_json::from_str(body).map_err(|_| Reject::Unavailable)?;
    if b["kind"].as_str() != Some("census") || b["request_id"].as_str() != Some(request_id) { return Err(Reject::Unavailable); }
    let at = b["answered_at"].as_i64().ok_or(Reject::Unavailable)?;
    if at > now + 5 || now - at > FRESH || at < issued - 2 { return Err(Reject::Unavailable); }
    if b["refused"].as_bool() == Some(true) { return Err(Reject::Refused); }
    let c = b.get("census").cloned().ok_or(Reject::Unavailable)?;
    if census_shape_ok(&c) { Ok(c) } else { Err(Reject::Unavailable) }
}

fn n(v: &Value, k: &str) -> i64 { v.get(k).and_then(|x| x.as_i64()).unwrap_or(-1) }
fn sum_of(v: &Value, keys: &[&str]) -> Option<i64> {
    let o = v.as_object()?; if o.len() != keys.len() { return None; }
    let mut t = 0; for k in keys { let x = o.get(*k)?.as_i64()?; if x < 0 { return None; } t += x; } Some(t)
}
/// The per-plan breakdown the plan detail page relies on: the eight plan keys, each group's own companies equal the plan count, its states add up to them, intervals and size bands never exceed them,
/// the storage count never exceeds them, and every seat adds up to the whole. A part that does not add up to its whole = the whole answer is refused.
fn by_package_ok(v: &Value, companies: i64) -> bool {
    let Some(bp) = v["by_package"].as_object() else { return false };
    if bp.len() != PKG_ALL.len() { return false; }
    let mut seats = 0i64;
    for k in PKG_ALL {
        let Some(g) = bp.get(k).and_then(|x| x.as_object()) else { return false };
        if g.len() != 6 { return false; }
        let c = g.get("companies").and_then(|x| x.as_i64()).unwrap_or(-1);
        if c < 0 || c > companies || Some(c) != v["packages"][k].as_i64() { return false; }
        let (Some(st), Some(iv), Some(bd), Some(s90), Some(se)) = (g.get("states"), g.get("intervals"), g.get("size_bands"), g.get("storage_90").and_then(|x| x.as_i64()), g.get("seats_in_use").and_then(|x| x.as_i64())) else { return false };
        if sum_of(st, &["active", "trialing", "grace_period", "not_active_yet", "ended"]) != Some(c) { return false; }
        if sum_of(iv, &["month", "year", "none"]).map(|t| t > c).unwrap_or(true) || sum_of(bd, &["1", "2-5", "6-20", "21-100", "101+"]).map(|t| t > c).unwrap_or(true) { return false; }
        if s90 < 0 || s90 > c || se < 0 { return false; }
        seats += se;
    }
    seats == n(v, "seats_in_use")
}
/// The shape the card relies on: closed key lists, no negative number, every grouping adds up to the companies, eight fixed signals in order. No personal field is allowed anywhere.
pub fn census_shape_ok(v: &Value) -> bool {
    let Some(o) = v.as_object() else { return false };
    let keys = ["generated_at", "companies", "seats_in_use", "packages", "states", "intervals", "size_bands", "growth_12m", "ended_30d", "renewals_7d", "over_limit", "by_package", "signals"];
    if o.len() != keys.len() || keys.iter().any(|k| !o.contains_key(*k)) { return false; }
    let companies = n(v, "companies");
    if companies < 0 || n(v, "seats_in_use") < 0 || n(v, "ended_30d") < 0 || n(v, "renewals_7d") < 0 { return false; }
    if !v["generated_at"].as_str().map(|s| !s.is_empty() && s.len() <= 40).unwrap_or(false) { return false; }
    if sum_of(&v["packages"], &PKG_ALL) != Some(companies) { return false; }
    if !by_package_ok(v, companies) { return false; }
    if sum_of(&v["states"], &["active", "trialing", "grace_period", "not_active_yet", "ended"]) != Some(companies) { return false; }
    if sum_of(&v["intervals"], &["month", "year", "none"]).map(|t| t > companies).unwrap_or(true) { return false; }
    if sum_of(&v["size_bands"], &["1", "2-5", "6-20", "21-100", "101+"]).map(|t| t > companies).unwrap_or(true) { return false; }
    if !v["growth_12m"].as_array().map(|a| a.len() == 12 && a.iter().all(|x| x.as_i64().map(|m| m >= 0).unwrap_or(false))).unwrap_or(false) { return false; }
    if !v["over_limit"].as_object().map(|m| m.iter().all(|(k, x)| PKGS.contains(&k.as_str()) && x.as_i64().map(|m| m >= 0 && m <= companies).unwrap_or(false))).unwrap_or(false) { return false; }
    v["signals"].as_array().map(|a| a.len() == SIGNALS.len() && a.iter().zip(SIGNALS.iter()).all(|(s, k)| {
        s.as_object().map(|m| m.len() == 4).unwrap_or(false) && s["key"].as_str() == Some(*k)
            && s["label"].as_str().map(|l| !l.is_empty() && l.len() <= 80).unwrap_or(false)
            && (s["runbook"].is_null() || s["runbook"].as_str().map(|r| !r.is_empty() && r.len() <= 80).unwrap_or(false))
            && s["count"].as_i64().map(|c| c >= 0 && c <= companies).unwrap_or(false)
    })).unwrap_or(false)
}

/// The record answer: 24 points (null or >= 0) and a trend word.
pub fn series_shape_ok(v: &Value) -> bool {
    v.get("spark").and_then(|x| x.as_array()).map(|a| a.len() == 24 && a.iter().all(|x| x.is_null() || x.as_i64().map(|m| m >= 0).unwrap_or(false))).unwrap_or(false)
        && ["up", "steady", "down", "unknown"].contains(&v.get("trend").and_then(|x| x.as_str()).unwrap_or(""))
}

static BREAKER: std::sync::OnceLock<Breaker> = std::sync::OnceLock::new();
fn breaker() -> &'static Breaker { BREAKER.get_or_init(Breaker::default) }

async fn ask_bounded(p: &Plane, env: &str, secs: u64) -> Option<String> { tokio::time::timeout(std::time::Duration::from_secs(secs), p.ask_path(CENSUS_PATH, env)).await.ok().flatten() }

/// POST /desk/v1/customers/census  (empty body)
pub async fn census(h: HeaderMap, body: Bytes) -> Response {
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    run(&h, &plane(), &cp_pub(), crate::signed::now_secs(), breaker()).await
}

pub(crate) async fn run(h: &HeaderMap, p: &Plane, cp_key: &str, now: i64, brk: &Breaker) -> Response {
    let (c, who) = match tokio::time::timeout(std::time::Duration::from_secs(DEADLINE_SECS), owner(h)).await {
        Err(_) => { eprintln!("desk customers: session check timed out"); return unavailable() }
        Ok(Err(r)) => return r,
        Ok(Ok(x)) => x,
    };
    let limits = match rows(&c, &format!("select desk.fadm_customers_begin('{who}'::uuid)::text")).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)).and_then(|j| serde_json::from_str::<Value>(j).ok()) { Some(l) if l.is_object() => l, _ => return err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk customers: db: {e}"); return unavailable() }
    };
    let Some(s) = crate::signed::signer() else { return unavailable() };
    let rid = uuid4(); let env = build_census_request(s, &rid, &who, &limits, now);
    let started = std::time::Instant::now(); let go = brk.allow(now);
    let asked = if go { ask_bounded(p, &env, DEADLINE_SECS).await } else { eprintln!("desk customers: breaker open"); None };
    let Some(ans) = asked else { if go { brk.fail(now); } return unavailable() };
    let now2 = now + started.elapsed().as_secs() as i64;
    match accept_census(&ans, cp_key, &rid, now, now2) {
        Ok(cen) => {
            brk.ok();
            let q = format!("select desk.fadm_census_record('{who}'::uuid, {}::jsonb)::text", lit(&cen.to_string()));
            match rows(&c, &q).await {
                Ok(v) => match v.first().and_then(|r| r.get(0)).and_then(|j| serde_json::from_str::<Value>(j).ok()) {
                    Some(sr) if series_shape_ok(&sr) => out(StatusCode::OK, json!({"census": cen, "series": sr}).to_string()),
                    Some(_) => { eprintln!("desk customers: wrong series shape"); unavailable() }
                    None => err(StatusCode::FORBIDDEN, "not_allowed") },
                Err(e) => { eprintln!("desk customers: record: {e}"); unavailable() }
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
    fn bp_fixture() -> Value {
        let mut m = serde_json::Map::new();
        for (k, c, se) in [("basic", 2, 8), ("pro", 1, 5), ("business", 1, 6), ("business_pro", 1, 4), ("business_premium", 1, 5), ("business_max", 0, 0), ("none", 1, 3), ("unknown", 0, 0)] {
            m.insert(k.into(), json!({"companies": c, "seats_in_use": se, "states": {"active": c, "trialing": 0, "grace_period": 0, "not_active_yet": 0, "ended": 0}, "intervals": {"month": c, "year": 0, "none": 0}, "size_bands": {"1": c, "2-5": 0, "6-20": 0, "21-100": 0, "101+": 0}, "storage_90": 0}));
        }
        Value::Object(m)
    }
    fn good() -> Value {
        let sig: Vec<Value> = SIGNALS.iter().map(|k| json!({"key": k, "label": "x", "runbook": null, "count": 1})).collect();
        json!({"generated_at": "2026-11-23T08:00:00Z", "companies": 7, "seats_in_use": 31,
            "packages": {"basic": 2, "pro": 1, "business": 1, "business_pro": 1, "business_premium": 1, "business_max": 0, "none": 1, "unknown": 0}, "by_package": bp_fixture(),
            "states": {"active": 3, "trialing": 1, "grace_period": 1, "not_active_yet": 1, "ended": 1},
            "intervals": {"month": 4, "year": 2, "none": 1}, "size_bands": {"1": 1, "2-5": 3, "6-20": 2, "21-100": 1, "101+": 0},
            "growth_12m": [0,0,0,0,0,0,0,1,2,3,5,7], "ended_30d": 1, "renewals_7d": 2, "over_limit": {"basic": 0, "pro": 1}, "signals": sig})
    }
    fn answer(k: &SigningKey, kind: &str, rid: &str, at: i64, c: Value, refused: bool) -> String {
        let body = json!({"kind": kind, "request_id": rid, "answered_at": at, "census": c, "refused": refused}).to_string();
        json!({"body": body, "sig": hexs(&k.sign(format!("{ANS_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    #[test] fn good_shape_passes_and_zero_is_data() {
        assert!(census_shape_ok(&good()));
        let mut z = good(); z["companies"] = json!(0); z["seats_in_use"] = json!(0);
        for k in ["packages", "states"] { for (_, v) in z[k].as_object_mut().unwrap().iter_mut() { *v = json!(0); } }
        for (_, g) in z["by_package"].as_object_mut().unwrap().iter_mut() { g["companies"] = json!(0); g["seats_in_use"] = json!(0); for k in ["states", "intervals", "size_bands"] { for (_, v) in g[k].as_object_mut().unwrap().iter_mut() { *v = json!(0); } } }
        for k in ["intervals", "size_bands"] { for (_, v) in z[k].as_object_mut().unwrap().iter_mut() { *v = json!(0); } }
        z["growth_12m"] = json!(vec![0; 12]); z["ended_30d"] = json!(0); z["renewals_7d"] = json!(0); z["over_limit"] = json!({});
        for s in z["signals"].as_array_mut().unwrap() { s["count"] = json!(0); }
        assert!(census_shape_ok(&z), "an empty business is a real answer");
    }
    #[test] fn wrong_shapes_are_refused() {
        let bad = |f: &dyn Fn(&mut Value)| { let mut v = good(); f(&mut v); assert!(!census_shape_ok(&v)); };
        bad(&|v| v["states"]["active"] = json!(4));
        bad(&|v| v["packages"]["business"] = json!(0));
        bad(&|v| v["by_package"]["pro"]["companies"] = json!(2));
        bad(&|v| v["by_package"]["basic"]["states"]["active"] = json!(1));
        bad(&|v| v["by_package"]["business_max"]["seats_in_use"] = json!(5));
        bad(&|v| v["by_package"]["none"]["storage_90"] = json!(2));
        bad(&|v| v["by_package"]["evil"] = json!({}));
        bad(&|v| { v["by_package"].as_object_mut().unwrap().remove("none"); });
        bad(&|v| v["companies"] = json!(-1));
        bad(&|v| v["intervals"]["month"] = json!(9));
        bad(&|v| v["size_bands"]["1"] = json!(9));
        bad(&|v| v["growth_12m"] = json!([1, 2]));
        bad(&|v| v["growth_12m"][3] = json!(-1));
        bad(&|v| v["over_limit"] = json!({"evil": 1}));
        bad(&|v| v["over_limit"]["pro"] = json!(8));
        bad(&|v| { v["signals"].as_array_mut().unwrap().swap(0, 1); });
        bad(&|v| v["signals"][0]["email"] = json!("a@b.c"));
        bad(&|v| v["signals"][2]["count"] = json!(8));
        bad(&|v| { v["signals"].as_array_mut().unwrap().pop(); });
        bad(&|v| v["company_names"] = json!(["Acme"]));
        bad(&|v| { v.as_object_mut().unwrap().remove("renewals_7d"); });
        assert!(!census_shape_ok(&json!(null)) && !census_shape_ok(&json!({})));
    }
    #[test] fn series_shape() {
        assert!(series_shape_ok(&json!({"spark": vec![Value::Null; 24], "trend": "unknown"})));
        assert!(!series_shape_ok(&json!({"spark": [1], "trend": "up"})) && !series_shape_ok(&json!({"spark": vec![json!(1); 24], "trend": "sideways"})));
    }
    #[test] fn request_is_signed_audience_bound_and_expires_in_60s() {
        use ed25519_dalek::{Signature, Verifier, VerifyingKey};
        let s = Signer::from_seed_hex(SEED).unwrap();
        let env: Value = serde_json::from_str(&build_census_request(&s, RID, "emp-1", &json!({"basic": 5}), 1000)).unwrap();
        let body = env["body"].as_str().unwrap(); let b: Value = serde_json::from_str(body).unwrap();
        assert_eq!(b["aud"], "desk-census"); assert_eq!(b["method"], "read"); assert_eq!(b["limits"]["basic"], 5);
        assert_eq!(b["expires_at"].as_i64().unwrap() - b["issued_at"].as_i64().unwrap(), 60);
        let vk = VerifyingKey::from_bytes(&unhex(&s.public_hex()).unwrap().try_into().unwrap()).unwrap();
        let sig = Signature::from_slice(&unhex(env["sig"].as_str().unwrap()).unwrap()).unwrap();
        assert!(vk.verify(format!("{REQ_DOMAIN}\n{body}").as_bytes(), &sig).is_ok());
        assert!(vk.verify(format!("anexo-desk-v1\n{body}").as_bytes(), &sig).is_err());
    }
    #[test] fn accept_good_and_refuse_every_bad_answer() {
        let (k, p) = cp(); let other = SigningKey::from_bytes(&[9u8; 32]);
        assert_eq!(accept_census(&answer(&k, "census", RID, 1000, good(), false), &p, RID, 1000, 1005).unwrap()["companies"], 7);
        let un = |a: String, now: i64| assert_eq!(accept_census(&a, &p, RID, 1000, now), Err(Reject::Unavailable));
        un(answer(&other, "census", RID, 1000, good(), false), 1005);
        un(answer(&k, "lookup", RID, 1000, good(), false), 1005);
        un(answer(&k, "census", "99999999-2222-4333-8444-555555555555", 1000, good(), false), 1005);
        un(answer(&k, "census", RID, 1000, good(), false), 1100);
        un(answer(&k, "census", RID, 990, good(), false), 1005);
        un(answer(&k, "census", RID, 1000, json!({"companies": 1}), false), 1005);
        un("garbage".into(), 1005);
        assert_eq!(accept_census(&answer(&k, "census", RID, 1000, Value::Null, true), &p, RID, 1000, 1005), Err(Reject::Refused));
        assert_eq!(accept_census(&answer(&k, "census", RID, 1000, good(), false), &hexs(&[1u8; 32]), RID, 1000, 1005), Err(Reject::Unavailable));
    }
    #[tokio::test] async fn double_plane_round_trip_uses_the_census_path() {
        let (k, p) = cp(); let s = Signer::from_seed_hex(SEED).unwrap();
        let env = build_census_request(&s, RID, "emp-1", &json!({}), 1000);
        let ans = answer(&k, "census", RID, 1000, good(), false);
        let pl = Plane::Double(Box::new(move |_| Some(ans.clone())));
        let got = ask_bounded(&pl, &env, 2).await.unwrap();
        assert!(accept_census(&got, &p, RID, 1000, 1002).is_ok());
        assert!(ask_bounded(&Plane::Off, &env, 2).await.is_none());
    }
}
