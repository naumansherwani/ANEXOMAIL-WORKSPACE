//! D2b (11 Nov 2026): Devices & Sessions, the Rust half of E155 + E156. Plan: docs/claude/G-MIX-D2B-PLAN-11NOV.md.
//!
//! A founder SESSION = one identity-service session (its `session_id`, else uid + device). The registry never sees the id, only `sid_hash`
//! = SHA-256("founder-sid:v1:" + uid + ":" + id). The founder token carries `sid` (the hash), so every verified request can be checked.
//!
//! What this module does, and what it never does:
//!   * facts the SERVER measured (network hash, protocol, country from a LOCAL file) are trusted; facts the browser CLAIMS (kernel, user-agent,
//!     client hints) are only ever compared with what the session showed at sign-in (drift), never treated as proof (R3).
//!   * `check()` runs the SQL door `founder_session_check` at most once per session per 3 s (R5). Anything but `live` is a refusal; a down
//!     door is a refusal too (closed). A revoke from this server drops the cache at once (R2).
//!   * a missing or unreadable country file means country = None: the SQL then admits no NEW device under `enforce` and never kills an
//!     admitted one (proved in the E156 selftest). No per-request network call, ever.
//!   * no Bun, no Node, no WebSocket; no new crate (the country file is a plain CIDR list read once).
use axum::http::HeaderMap;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{collections::HashMap, net::IpAddr, sync::{Mutex, OnceLock}, time::{Duration, Instant}};

use crate::data::Sb;

pub const CACHE_TTL: Duration = Duration::from_secs(3);
const CACHE_CAP: usize = 4096;
const METHOD_TTL: Duration = Duration::from_secs(600);

// ------------------------------------------------------------------------------------------------------------------------------
// pure helpers
// ------------------------------------------------------------------------------------------------------------------------------

/// `sid_hash` for the registry and the token claim (64 hex). `session_id` is the identity-service session; without one the device stands in.
pub fn sid_hash(uid: &str, session_id: Option<&str>, device_hash: &str) -> String {
    let id = match session_id.filter(|s| !s.is_empty()) { Some(s) => format!("s:{s}"), None => format!("d:{device_hash}") };
    hex::encode(Sha256::digest(format!("founder-sid:v1:{uid}:{id}").as_bytes()))
}

/// What the browser CLAIMS (user-agent). Families only; the raw string is never stored.
pub fn ua_family(ua: &str) -> &'static str {
    let u = ua.to_ascii_lowercase();
    if u.trim().is_empty() { "unknown" }
    else if u.contains("edg/") || u.contains("edga/") || u.contains("edgios/") { "edge" }
    else if u.contains("opr/") || u.contains("opera") { "opera" }
    else if u.contains("samsungbrowser") { "samsung" }
    else if u.contains("firefox/") || u.contains("fxios/") { "firefox" }
    else if u.contains("chrome/") || u.contains("crios/") { "chrome" }
    else if u.contains("safari/") { "safari" }
    else { "other" }
}

/// What the engine itself reports through client hints (`Sec-CH-UA`). Absent (Firefox, Safari) = unknown, which the SQL never counts as a mismatch.
pub fn hint_family(h: &str) -> &'static str {
    let u = h.to_ascii_lowercase();
    if u.trim().is_empty() { "unknown" }
    else if u.contains("microsoft edge") { "edge" }
    else if u.contains("opera") { "opera" }
    else if u.contains("samsung") { "samsung" }
    else if u.contains("firefox") { "firefox" }
    else if u.contains("google chrome") || u.contains("chromium") { "chrome" }
    else { "other" }
}

/// The protocol the SERVER saw. `x-fo-proto` is stamped by `stamp_proto` from the real connection (a client-sent copy is overwritten).
pub fn protocol_of(h: &HeaderMap) -> &'static str {
    match h.get("x-fo-proto").and_then(|v| v.to_str().ok()) { Some("h3") => "quic", Some("h2") => "h2", Some("h1") => "h1", _ => "unknown" }
}

/// The kernel build the SPA says it runs (a CLAIM, compared over time). Anything that is not 1-40 safe characters is "unknown".
pub fn kernel_of(h: &HeaderMap) -> String {
    let k = h.get("x-founder-kernel").and_then(|v| v.to_str().ok()).unwrap_or("").trim();
    if !k.is_empty() && k.len() <= 40 && k.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'+' | b'-')) { k.to_string() } else { "unknown".to_string() }
}

/// Everything the doors want about one request.
#[derive(Debug, Clone, PartialEq)]
pub struct Facts { pub net: String, pub protocol: &'static str, pub kernel: String, pub ua: &'static str, pub hint: &'static str, pub country: Option<String> }

pub fn facts(h: &HeaderMap, net_key: &[u8]) -> Facts {
    let ip = crate::signin::client_ip(h);
    let hv = |n: &str| h.get(n).and_then(|v| v.to_str().ok()).unwrap_or("").chars().take(512).collect::<String>();
    Facts {
        net: crate::signin::net_hash(net_key, &ip), protocol: protocol_of(h), kernel: kernel_of(h),
        ua: ua_family(&hv("user-agent")), hint: hint_family(&hv("sec-ch-ua")),
        country: ip.parse::<IpAddr>().ok().and_then(|a| geo().lookup(a)),
    }
}

// ------------------------------------------------------------------------------------------------------------------------------
// the local country file: lines "a.b.c.d/len,CC" (or "::1/len,CC"); read once; no file = every lookup is None
// ------------------------------------------------------------------------------------------------------------------------------

#[derive(Default)]
pub struct Geo { r: Vec<(u128, u128, [u8; 2])> }

fn ip_key(a: IpAddr) -> u128 { match a { IpAddr::V4(v) => u128::from(v.to_ipv6_mapped()), IpAddr::V6(v) => u128::from(v) } }

impl Geo {
    pub fn parse(txt: &str) -> Geo {
        let mut r: Vec<(u128, u128, [u8; 2])> = Vec::new();
        for l in txt.lines().take(2_000_000) {
            let l = l.trim();
            if l.is_empty() || l.starts_with('#') { continue; }
            let mut it = l.split([',', ' ', '\t']).filter(|x| !x.is_empty());
            let (Some(cidr), Some(cc)) = (it.next(), it.next()) else { continue };
            let cc = cc.trim_matches('"').to_ascii_uppercase();
            let b = cc.as_bytes();
            if b.len() != 2 || !b.iter().all(|c| c.is_ascii_uppercase()) { continue; }
            let Some((a, len)) = cidr.split_once('/') else { continue };
            let (Ok(addr), Ok(len)) = (a.parse::<IpAddr>(), len.parse::<u32>()) else { continue };
            let bits = match addr { IpAddr::V4(_) => { if len > 32 { continue; } 96 + len } IpAddr::V6(_) => { if len > 128 { continue; } len } };
            let base = ip_key(addr);
            let host = if bits >= 128 { 0u128 } else { (1u128 << (128 - bits)) - 1 };
            r.push((base & !host, base | host, [b[0], b[1]]));
        }
        r.sort_by_key(|x| (x.0, x.1));
        Geo { r }
    }
    pub fn load(path: &str) -> Geo { std::fs::read_to_string(path).map(|t| Geo::parse(&t)).unwrap_or_default() }
    pub fn len(&self) -> usize { self.r.len() }
    pub fn lookup(&self, a: IpAddr) -> Option<String> {
        if self.r.is_empty() { return None; }
        let k = ip_key(a);
        let i = self.r.partition_point(|x| x.0 <= k);
        // ranges are sorted by start; the last range that starts at or before k is the tightest candidate (overlaps are rare in country files)
        self.r[..i].iter().rev().take(4).find(|x| x.1 >= k).map(|x| String::from_utf8_lossy(&x.2).to_string())
    }
}

fn geo() -> &'static Geo {
    static G: OnceLock<Geo> = OnceLock::new();
    G.get_or_init(|| match std::env::var("FOUNDER_GEOIP") {
        Ok(p) if !p.is_empty() => { let g = Geo::load(&p); eprintln!("founder-sessions stage=geo detail=loaded ranges={}", g.len()); g }
        _ => { eprintln!("founder-sessions stage=geo detail=no country file (country stays unknown)"); Geo::default() }
    })
}

// ------------------------------------------------------------------------------------------------------------------------------
// state: the 3 s verdict cache and the sign-in method note (both in memory, bounded)
// ------------------------------------------------------------------------------------------------------------------------------

fn cache() -> &'static Mutex<HashMap<String, Instant>> { static C: OnceLock<Mutex<HashMap<String, Instant>>> = OnceLock::new(); C.get_or_init(|| Mutex::new(HashMap::new())) }
fn methods() -> &'static Mutex<HashMap<String, (Instant, &'static str)>> { static M: OnceLock<Mutex<HashMap<String, (Instant, &'static str)>>> = OnceLock::new(); M.get_or_init(|| Mutex::new(HashMap::new())) }

pub fn cache_put(sid: &str, now: Instant) {
    let mut c = cache().lock().unwrap();
    if c.len() >= CACHE_CAP { c.retain(|_, e| *e > now); if c.len() >= CACHE_CAP { c.clear(); } }
    c.insert(sid.to_string(), now + CACHE_TTL);
}
pub fn cache_fresh(sid: &str, now: Instant) -> bool { cache().lock().unwrap().get(sid).is_some_and(|e| *e > now) }
/// R2: a revoke (or a closed verdict) must never be answered from the cache again.
pub fn cache_drop(sid: &str) { cache().lock().unwrap().remove(sid); }
pub fn cache_clear() { cache().lock().unwrap().clear(); }

/// The release door says how this founder just signed in; the next exchange of that founder registers the session with it.
pub fn note_method(uid: &str, method: &str) {
    let m: &'static str = match method { "passkey" => "passkey", "magic_link" => "magic_link", _ => "password" };
    let mut t = methods().lock().unwrap();
    if t.len() > 64 { let now = Instant::now(); t.retain(|_, v| v.0 > now); }
    t.insert(uid.to_string(), (Instant::now() + METHOD_TTL, m));
}
/// Honest default: after a server restart between sign-in and the first exchange the note is gone and "password" is recorded.
pub fn method_for(uid: &str) -> &'static str { methods().lock().unwrap().get(uid).filter(|v| v.0 > Instant::now()).map(|v| v.1).unwrap_or("password") }

// ------------------------------------------------------------------------------------------------------------------------------
// the doors
// ------------------------------------------------------------------------------------------------------------------------------

#[derive(Debug, PartialEq)]
pub enum Verdict { Live, Closed(String) }

fn trace(stage: &str, detail: &str) { eprintln!("founder-sessions stage={stage} detail={detail}"); }

/// Sign-in side (called by the exchange): record the session. Err = refuse the exchange (R1: no half-signed-in session).
pub async fn register(sb: &Sb, uid: &str, sid: &str, device_hash: &str, f: &Facts, key: Option<(&str, &str)>) -> Result<(), &'static str> {
    let (src, fp) = match key { Some((s, fp)) => (s, Some(fp.to_string())), None => ("none", None) };
    let a = json!({"p_uid": uid, "p_sid_hash": sid, "p_device_hash": device_hash, "p_net_hash": f.net, "p_method": method_for(uid), "p_protocol": f.protocol, "p_kernel": f.kernel,
        "p_key_source": src, "p_key_fp": fp, "p_ua_family": f.ua, "p_hint_family": f.hint, "p_country": f.country});
    match sb.rpc_msg("founder_session_register", a).await {
        Ok(v) if v["ok"].as_bool() == Some(true) && v["decision"].as_str() == Some("allow") => { cache_put(sid, Instant::now()); Ok(()) }
        Ok(v) if v["ok"].as_bool() == Some(true) => { trace("register", &format!("denied reason={}", v["reason"].as_str().unwrap_or("?"))); Err("denied") }
        Ok(v) => { trace("register", &format!("refused error={}", v["error"].as_str().unwrap_or("?"))); Err("refused") }
        Err((c, _)) => { trace("register", &format!("door_down http={c}")); Err("door_down") }
    }
}

/// Request side (called by the gate for every verified founder token that carries a `sid`).
pub async fn check(sb: &Sb, sid: &str, f: &Facts, verified: bool, key_fp: Option<&str>) -> Verdict {
    let now = Instant::now();
    if verified && key_fp.is_none() && cache_fresh(sid, now) { return Verdict::Live; }
    let a = json!({"p_sid_hash": sid, "p_net_hash": f.net, "p_protocol": f.protocol, "p_kernel": f.kernel, "p_verified": verified,
        "p_ua_family": f.ua, "p_hint_family": f.hint, "p_key_fp": key_fp, "p_country": f.country});
    match sb.rpc_msg("founder_session_check", a).await {
        Ok(v) if v["state"].as_str() == Some("live") => { if verified { cache_put(sid, now); } Verdict::Live }
        Ok(v) => { cache_drop(sid); let s = v["state"].as_str().unwrap_or("closed").to_string(); trace("check", &format!("closed state={s}")); Verdict::Closed(s) }
        Err((c, _)) => { cache_drop(sid); trace("check", &format!("door_down http={c}")); Verdict::Closed("door_down".into()) }
    }
}

pub async fn board(sb: &Sb, uid: &str, current: Option<&str>) -> Option<Value> { sb.rpc("founder_sessions_board", json!({"p_uid": uid, "p_current_sid_hash": current})).await }
pub async fn ledger_page(sb: &Sb, uid: &str, limit: i64, before: Option<i64>) -> Option<Value> { sb.rpc("founder_session_ledger_page", json!({"p_uid": uid, "p_limit": limit.clamp(1, 200), "p_before_id": before})).await }

pub async fn revoke(sb: &Sb, uid: &str, sid: &str) -> Option<Value> {
    let r = sb.rpc("founder_session_revoke", json!({"p_uid": uid, "p_sid_hash": sid, "p_reason": "founder_nuke"})).await;
    cache_drop(sid);
    r
}
pub async fn revoke_others(sb: &Sb, uid: &str, keep: &str) -> Option<Value> {
    let r = sb.rpc("founder_session_revoke_others", json!({"p_uid": uid, "p_keep_sid_hash": keep})).await;
    cache_clear();
    r
}

/// R8: hourly upkeep. A failure is a journald line, never a crash.
pub fn spawn_upkeep(sb: Sb) {
    tokio::spawn(async move {
        let mut first = true;
        loop {
            tokio::time::sleep(Duration::from_secs(if first { 90 } else { 3600 })).await;
            first = false;
            match sb.rpc_msg("founder_session_tick", json!({})).await { Ok(v) => { cache_clear(); trace("tick", &format!("ok expired={}", v["expired"])); } Err((c, _)) => trace("tick", &format!("failed http={c}")) }
            let uid = sb.rows("founder_accounts?select=user_id&limit=5").await.unwrap_or_default();
            for u in uid.iter().filter_map(|r| r["user_id"].as_str()) {
                match sb.rpc_msg("founder_session_anchor", json!({"p_uid": u})).await { Ok(v) => trace("anchor", &format!("ok anchored={}", v["anchored"])), Err((c, _)) => trace("anchor", &format!("failed http={c}")) }
            }
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{extract::{Path, State as St2}, routing::post, Json, Router};
    use axum::http::StatusCode;

    #[test]
    fn families_are_read_from_what_the_browser_claims_and_proves() {
        assert_eq!(ua_family("Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 Chrome/130.0 Safari/537.36"), "chrome");
        assert_eq!(ua_family("Mozilla/5.0 Chrome/130.0 Safari/537.36 Edg/130.0"), "edge");
        assert_eq!(ua_family("Mozilla/5.0 (iPhone) AppleWebKit Version/17 Mobile Safari/604.1"), "safari");
        assert_eq!(ua_family("Mozilla/5.0 (Android) Chrome/130 Mobile Safari/537 SamsungBrowser/25"), "samsung");
        assert_eq!(ua_family("Mozilla/5.0 (X11; Linux) Gecko/20100101 Firefox/131.0"), "firefox");
        assert_eq!(ua_family(""), "unknown");
        assert_eq!(ua_family("curl/8.0"), "other");
        assert_eq!(hint_family(r#""Chromium";v="130", "Google Chrome";v="130", "Not?A_Brand";v="99""#), "chrome");
        assert_eq!(hint_family(r#""Chromium";v="130", "Microsoft Edge";v="130""#), "edge");
        assert_eq!(hint_family(""), "unknown");
    }

    #[test]
    fn protocol_kernel_and_sid_are_bounded_and_never_trust_a_raw_header() {
        let mut h = HeaderMap::new();
        assert_eq!(protocol_of(&h), "unknown");
        h.insert("x-fo-proto", "h2".parse().unwrap());
        assert_eq!(protocol_of(&h), "h2");
        h.insert("x-fo-proto", "quic-evil".parse().unwrap());
        assert_eq!(protocol_of(&h), "unknown");
        assert_eq!(kernel_of(&h), "unknown");
        h.insert("x-founder-kernel", "k-0.7.3+abc".parse().unwrap());
        assert_eq!(kernel_of(&h), "k-0.7.3+abc");
        h.insert("x-founder-kernel", "bad kernel;drop".parse().unwrap());
        assert_eq!(kernel_of(&h), "unknown");
        h.insert("x-founder-kernel", "k".repeat(41).parse().unwrap());
        assert_eq!(kernel_of(&h), "unknown");
        let a = sid_hash("u1", Some("s-1"), &"d".repeat(64));
        assert_eq!(a.len(), 64);
        assert_ne!(a, sid_hash("u1", Some("s-2"), &"d".repeat(64)));
        assert_ne!(a, sid_hash("u2", Some("s-1"), &"d".repeat(64)));
        assert_eq!(sid_hash("u1", None, &"d".repeat(64)), sid_hash("u1", Some(""), &"d".repeat(64)));
        assert_ne!(sid_hash("u1", None, &"d".repeat(64)), sid_hash("u1", None, &"e".repeat(64)));
    }

    #[test]
    fn the_country_file_finds_ranges_and_an_empty_file_finds_nothing() {
        let g = Geo::parse("# comment\n1.0.0.0/24,AU\n39.32.0.0/11,PK\n\"::1/128\",ZZ\n2001:db8::/32 DE\nbad line\n8.8.8.0/40,XX\n10.0.0.0/8,usa\n");
        assert_eq!(g.lookup("39.40.1.1".parse().unwrap()).as_deref(), Some("PK"));
        assert_eq!(g.lookup("1.0.0.77".parse().unwrap()).as_deref(), Some("AU"));
        assert_eq!(g.lookup("1.0.1.1".parse().unwrap()), None);
        assert_eq!(g.lookup("2001:db8:1::5".parse().unwrap()).as_deref(), Some("DE"));
        assert_eq!(g.lookup("8.8.8.8".parse().unwrap()), None, "a bad prefix is skipped, not guessed");
        assert_eq!(g.lookup("10.1.1.1".parse().unwrap()), None, "a three-letter country is skipped");
        assert_eq!(Geo::default().lookup("39.40.1.1".parse().unwrap()), None);
        assert_eq!(Geo::load("/no/such/file").len(), 0);
    }

    #[test]
    fn the_cache_lives_three_seconds_and_a_drop_is_immediate() {
        let t = Instant::now();
        cache_put("c-1", t);
        assert!(cache_fresh("c-1", t + Duration::from_secs(2)));
        assert!(!cache_fresh("c-1", t + Duration::from_secs(4)));
        cache_put("c-2", t);
        cache_drop("c-2");
        assert!(!cache_fresh("c-2", t));
        note_method("u-m", "passkey");
        assert_eq!(method_for("u-m"), "passkey");
        assert_eq!(method_for("u-unknown"), "password");
    }

    // ---- a loopback database that models the REAL grants: only the SQL doors answer; there is no table to read around them ----
    #[derive(Clone, Default)]
    struct World { rpc: std::sync::Arc<Mutex<Vec<(String, Value)>>>, state: std::sync::Arc<Mutex<String>>, down: std::sync::Arc<Mutex<bool>>, deny: std::sync::Arc<Mutex<bool>> }
    async fn world() -> (Sb, World) {
        let w = World::default();
        *w.state.lock().unwrap() = "live".into();
        let app = Router::new().route("/rest/v1/rpc/{name}", post(|St2(w): St2<World>, Path(n): Path<String>, Json(b): Json<Value>| async move {
            w.rpc.lock().unwrap().push((n.clone(), b));
            if *w.down.lock().unwrap() { return (StatusCode::BAD_GATEWAY, Json(json!({"message": "down"}))); }
            let v = match n.as_str() {
                "founder_session_register" => if *w.deny.lock().unwrap() { json!({"ok": true, "decision": "deny", "reason": "location"}) } else { json!({"ok": true, "decision": "allow"}) },
                "founder_session_check" => { let s = w.state.lock().unwrap().clone(); json!({"ok": s == "live", "state": s, "drift": []}) }
                _ => json!({"ok": true}),
            };
            (StatusCode::OK, Json(v))
        })).with_state(w.clone());
        let l = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}", l.local_addr().unwrap());
        tokio::spawn(async move { axum::serve(l, app).await.unwrap(); });
        (Sb { url, key: "svc".into(), http: reqwest::Client::new() }, w)
    }
    fn f() -> Facts { Facts { net: "n".repeat(64), protocol: "h2", kernel: "k-1".into(), ua: "chrome", hint: "chrome", country: Some("PK".into()) } }
    fn n(w: &World, name: &str) -> usize { w.rpc.lock().unwrap().iter().filter(|(x, _)| x == name).count() }

    #[tokio::test]
    async fn register_allows_refuses_and_a_down_door_is_a_refusal() {
        let (sb, w) = world().await;
        let sid = sid_hash("u-r", Some("s"), &"d".repeat(64));
        assert_eq!(register(&sb, "u-r", &sid, &"d".repeat(64), &f(), None).await, Ok(()));
        let a = w.rpc.lock().unwrap()[0].1.clone();
        assert_eq!((a["p_key_source"].as_str(), a["p_key_fp"].is_null(), a["p_country"].as_str(), a["p_protocol"].as_str()), (Some("none"), true, Some("PK"), Some("h2")));
        assert!(!a.to_string().contains("Mozilla"), "no raw user-agent travels");
        *w.deny.lock().unwrap() = true;
        assert_eq!(register(&sb, "u-r", &sid, &"d".repeat(64), &f(), Some(("webcrypto", &"a".repeat(64)))).await, Err("denied"));
        *w.down.lock().unwrap() = true;
        assert_eq!(register(&sb, "u-r", &sid, &"d".repeat(64), &f(), None).await, Err("door_down"));
    }

    #[tokio::test]
    async fn check_asks_once_per_three_seconds_and_every_closed_state_is_a_refusal_that_clears_the_cache() {
        let (sb, w) = world().await;
        let sid = "s".repeat(64);
        cache_drop(&sid);
        assert_eq!(check(&sb, &sid, &f(), true, None).await, Verdict::Live);
        assert_eq!(check(&sb, &sid, &f(), true, None).await, Verdict::Live);
        assert_eq!(n(&w, "founder_session_check"), 1, "R5: the second request in 3 s is answered from the cache");
        // a request that carries a key proof is never answered from the cache (the proof must reach the SQL)
        assert_eq!(check(&sb, &sid, &f(), true, Some(&"b".repeat(64))).await, Verdict::Live);
        assert_eq!(n(&w, "founder_session_check"), 2);
        for s in ["revoked", "expired", "drift_revoked", "geo_outside", "flapping_revoked", "integrity_revoked", "unknown", "shape"] {
            cache_put(&sid, Instant::now());
            *w.state.lock().unwrap() = s.to_string();
            // a failed signature (verified=false) always reaches the SQL, so the failure streak counts it
            assert_eq!(check(&sb, &sid, &f(), false, None).await, Verdict::Closed(s.to_string()));
            assert!(!cache_fresh(&sid, Instant::now()), "R2: a closed verdict leaves nothing in the cache ({s})");
        }
        *w.state.lock().unwrap() = "live".into();
        *w.down.lock().unwrap() = true;
        cache_drop(&sid);
        assert_eq!(check(&sb, &sid, &f(), true, None).await, Verdict::Closed("door_down".into()), "a down door is closed, never open");
    }

    #[tokio::test]
    async fn revoke_drops_the_cache_at_once_and_revoke_others_drops_all() {
        let (sb, w) = world().await;
        let sid = "r".repeat(64);
        cache_put(&sid, Instant::now());
        let _ = revoke(&sb, "u", &sid).await;
        assert!(!cache_fresh(&sid, Instant::now()));
        assert_eq!(w.rpc.lock().unwrap().last().unwrap().1["p_reason"], "founder_nuke");
        cache_put("x1", Instant::now()); cache_put("x2", Instant::now());
        let _ = revoke_others(&sb, "u", "x1").await;
        assert!(!cache_fresh("x2", Instant::now()) && !cache_fresh("x1", Instant::now()), "the kept session simply asks again once");
        assert!(ledger_page(&sb, "u", 9999, None).await.is_some());
        assert_eq!(w.rpc.lock().unwrap().last().unwrap().1["p_limit"], 200);
    }
}
