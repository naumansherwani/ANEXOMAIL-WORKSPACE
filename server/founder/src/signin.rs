//! G-MIX 2b / S2 (founder, 10 Nov 2026): the FOUNDER SIGN-IN DOOR. Technology: Rust (axum 0.8 + tokio + ring + reqwest/rustls) inside the founder binary; no Bun, no Node, no WebSocket, no new crate.
//! SQL (E151 + E152) is the rulebook and the memory; THIS file only does what SQL cannot: the password call result, the passkey signature, the identity-service session, the bytes.
//! HIS WORD (10 Nov 18:26): the founder sign-in is ONE FACTOR. A correct password signs in alone; a passkey signs in alone; a magic link never does. The database keeps that word
//! (`founder_signin_policy.second_step`, off by default); if he ever sets it to `required`, the same doors ask for the passkey as a second step (parked session, below).
//!
//! Wiring (see docs/claude/G-MIX-S2-PLAN-10NOV.md):
//!   password  : auth::login_ep -> identity service says the password is right and the account is a founder -> `after_password` -> E151/E152 `locked` -> `open('password')`
//!               -> (word off) complete -> `release_v2` (hand-off row, risk reading, known-network memory) -> tokens;
//!               (word required) the identity session is PARKED here (120 s, single use, bound to the network) and the answer is `{step:"passkey", ticket}`.
//!   passkey   : POST /founder/v1/auth/passkey/begin  {ticket?}  -> an in-memory ceremony (random challenge, 120 s, single use, bound to origin + network, capped)
//!               POST /founder/v1/auth/passkey/finish {ceremony, credential} -> credential id -> active founder passkey -> WebAuthn assertion verified (user verification REQUIRED)
//!               -> E139 `founder_webauthn_assert` must say allow -> E151/E152 `open('passkey')` + `factor(ok)` + `release_v2` -> a session minted by the identity service ADMIN API
//!               (generate_link + verify, nothing is mailed; this is NOT the magic-link feature) -> tokens.
//! Rules (pure parts tested, doors tested end to end against loopback stand-ins):
//!  (1) the database is never trusted to be up: any error from a door = 503 and the identity session is ended (fail closed), never a session;
//!  (2) every refusal of the passkey door is the SAME generic 401 (no account oracle, no "wrong key" vs "unknown key");
//!  (3) the network is stored only as HMAC-SHA256(server key, address): no raw address in the ledger (Rule 69);
//!  (4) a ticket and a ceremony are single use and short lived; a different network hash than the one that began is refused;
//!  (5) failures of a known founder go into the E151 ledger (`factor_fail`), so the database lock (founder AND network) sees them as well as the cheap memory limiter in front;
//!  (6) tokens, passwords and assertions are never logged and never put in a URL.
use axum::extract::State;
use axum::http::{HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::Json;
use hmac::{Hmac, Mac};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use crate::auth::{busy_503, end_session, generic_401, gotrue, locked_429, no_store, parse_grant, Grant};
use crate::data::Sb;
use crate::passkey_core as pc;
use crate::{St, S};

const PARK_TTL: Duration = Duration::from_secs(120);
const PARK_CAP: usize = 64;
const CER_CAP: usize = 256;
const CER_PER_NET: usize = 8;

// ------------------------------------------------------------------------------------------------------------------------------
// pure helpers
// ------------------------------------------------------------------------------------------------------------------------------

/// The client address the TLS terminator wrote (it overwrites x-real-ip, a client cannot forge it). "-" when absent.
pub fn client_ip(h: &HeaderMap) -> String {
    h.get("x-real-ip").and_then(|v| v.to_str().ok()).map(|s| s.trim().chars().take(64).collect::<String>()).filter(|s| !s.is_empty()).unwrap_or_else(|| "-".into())
}

/// Network hash = HMAC-SHA256(server key, "founder-net:v1:" + address), lower-case hex (64). Not reversible without the server key.
pub fn net_hash(key: &[u8], ip: &str) -> String {
    let mut m = <Hmac<Sha256> as Mac>::new_from_slice(key).expect("hmac takes any key length");
    m.update(b"founder-net:v1:");
    m.update(ip.as_bytes());
    hex::encode(m.finalize().into_bytes())
}

pub fn hash_hex(s: &str) -> String { hex::encode(Sha256::digest(s.as_bytes())) }

/// (opaque ticket, its SHA-256 hex). Only the hash ever reaches the database.
pub fn new_ticket() -> Result<(String, String), ()> {
    let t = crate::passkey::random_challenge().map_err(|_| ())?;
    let h = hash_hex(&t);
    Ok((t, h))
}

/// What `founder_signin_open` said, reduced to what Rust decides on. Anything unexpected is Refused (closed).
#[derive(Debug, PartialEq)]
pub enum Opened { Complete, NeedPasskey, Locked, Refused }
pub fn reduce_open(v: &Value) -> Opened {
    if v["ok"].as_bool() != Some(true) {
        return if v["error"].as_str() == Some("locked") { Opened::Locked } else { Opened::Refused };
    }
    let need: Vec<&str> = v["need"].as_array().map(|a| a.iter().filter_map(|x| x.as_str()).collect()).unwrap_or_default();
    match (v["state"].as_str(), need.as_slice()) {
        (Some("complete"), []) => Opened::Complete,
        (Some("open"), ["passkey"]) => Opened::NeedPasskey,
        _ => Opened::Refused, // e.g. a factor this binary cannot honour (totp): never a session
    }
}

/// What the answer tells the page about the hand-off (no secret): the method, whether the network was new, the risk level.
pub fn release_extras(v: &Value) -> Value {
    json!({"method": v["method"], "new_network": v["new_net"].as_bool().unwrap_or(false), "risk": v["risk"]["level"]})
}

/// Single-use, expiring, capped map. `take` always removes (a wrong network or an expired entry is burnt, never retried).
pub struct TtlMap<T> { m: HashMap<String, (Instant, T)>, cap: usize }
impl<T> TtlMap<T> {
    pub fn new(cap: usize) -> Self { Self { m: HashMap::new(), cap } }
    pub fn put(&mut self, k: String, v: T, now: Instant, ttl: Duration) -> bool {
        self.m.retain(|_, (e, _)| *e > now);
        if self.m.len() >= self.cap || self.m.contains_key(&k) { return false; }
        self.m.insert(k, (now + ttl, v));
        true
    }
    /// Like `put`, but when the map is full the heaviest owner pays: the OLDEST entry of the owner that holds the most is dropped, so one address
    /// (or a few) can never fill the map and lock everyone else out; a stranger only ever evicts his own entries.
    pub fn put_fair(&mut self, k: String, v: T, now: Instant, ttl: Duration, owner: &dyn Fn(&T) -> String) -> bool {
        self.m.retain(|_, (e, _)| *e > now);
        if self.m.contains_key(&k) { return false; }
        if self.m.len() >= self.cap {
            let mut counts: HashMap<String, usize> = HashMap::new();
            for (_, (_, t)) in self.m.iter() { *counts.entry(owner(t)).or_default() += 1; }
            let Some((heavy, _)) = counts.into_iter().max_by_key(|(_, c)| *c) else { return false };
            let victim = self.m.iter().filter(|(_, (_, t))| owner(t) == heavy).min_by_key(|(_, (e, _))| *e).map(|(k, _)| k.clone());
            match victim { Some(vk) => { self.m.remove(&vk); } None => return false }
        }
        self.m.insert(k, (now + ttl, v));
        true
    }
    pub fn take(&mut self, k: &str, now: Instant) -> Option<T> {
        match self.m.remove(k) { Some((e, v)) if e > now => Some(v), _ => None }
    }
    pub fn peek(&self, k: &str, now: Instant) -> Option<&T> { self.m.get(k).filter(|(e, _)| *e > now).map(|(_, v)| v) }
    pub fn count_where(&self, now: Instant, f: impl Fn(&T) -> bool) -> usize { self.m.values().filter(|(e, v)| *e > now && f(v)).count() }
    pub fn len(&self) -> usize { self.m.len() }
}

/// An identity-service session that has passed the password and waits for its second step (only when the word is `required`).
pub struct Parked { pub token: String, pub refresh: String, pub expires_at: Option<i64>, pub uid: String, pub net: String }
/// One passkey ceremony in flight.
pub struct Cer { pub challenge: String, pub origin: String, pub rp: String, pub net: String, pub ticket: Option<String> }

fn parked_store() -> &'static Mutex<TtlMap<Parked>> { static P: OnceLock<Mutex<TtlMap<Parked>>> = OnceLock::new(); P.get_or_init(|| Mutex::new(TtlMap::new(PARK_CAP))) }
fn cer_store() -> &'static Mutex<TtlMap<Cer>> { static C: OnceLock<Mutex<TtlMap<Cer>>> = OnceLock::new(); C.get_or_init(|| Mutex::new(TtlMap::new(CER_CAP))) }

// ------------------------------------------------------------------------------------------------------------------------------
// doors (SQL) and answers
// ------------------------------------------------------------------------------------------------------------------------------

async fn deny(sb: &Sb, th: &str, net: &str, why: &str) { let _ = sb.rpc_msg("founder_signin_deny", json!({"p_ticket_hash": th, "p_net_hash": net, "p_reason": why})).await; }

async fn factor(sb: &Sb, th: &str, net: &str, ok: bool, cid: &str) -> Option<Value> {
    sb.rpc_msg("founder_signin_factor", json!({"p_ticket_hash": th, "p_net_hash": net, "p_factor": "passkey", "p_ok": ok, "p_credential_id": cid})).await.ok()
}

/// The database lock (founder AND network). Ok(false) = free, Ok(true) = locked, Err = the door is down.
async fn locked(sb: &Sb, uid: Option<&str>, net: &str) -> Result<bool, ()> {
    match sb.rpc_msg("founder_signin_locked", json!({"p_uid": uid, "p_net": net})).await {
        Ok(v) => Ok(v["locked"].as_bool() != Some(false)), // anything but a clear "false" counts as locked (closed)
        Err(_) => Err(()),
    }
}

fn session_answer(p: &Parked, rel: &Value) -> Response {
    no_store(Json(json!({"token": p.token, "refresh_token": p.refresh, "expires_at": p.expires_at, "signin": release_extras(rel)})).into_response())
}

/// The one door out: release (once), then and only then the tokens. A released ticket of another founder than the session's is never answered.
async fn release(sb: &Sb, th: &str, p: &Parked) -> Response {
    match sb.rpc_msg("founder_signin_release_v2", json!({"p_ticket_hash": th, "p_net_hash": p.net})).await {
        Ok(v) if v["ok"].as_bool() == Some(true) && v["uid"].as_str().map(|u| u.eq_ignore_ascii_case(&p.uid)).unwrap_or(false) => session_answer(p, &v),
        Ok(_) => { end_session(sb, &p.token).await; generic_401() }
        Err(_) => { end_session(sb, &p.token).await; busy_503() }
    }
}

/// Is this NETWORK locked in the ledger (E151/E153)? Asked BEFORE any password is tried. Err = the door is down (closed).
pub async fn net_locked(sb: &Sb, net: &str) -> Result<bool, ()> { locked(sb, None, net).await }
/// A wrong password goes into the append-only ledger (E153), so five from one network lock that network even after a restart. Best effort: a down door never blocks the 401.
pub async fn note_bad_password(sb: &Sb, net: &str) { let _ = sb.rpc_msg("founder_signin_password_fail", json!({"p_net_hash": net})).await; }

// ------------------------------------------------------------------------------------------------------------------------------
// password path (called by auth::login_ep after the identity service said yes and the account is a founder)
// ------------------------------------------------------------------------------------------------------------------------------

pub async fn after_password(st: &St, h: &HeaderMap, uid: String, token: String, refresh: String, expires_at: Option<i64>) -> Response {
    let Some(sb) = st.sb.as_ref() else { return busy_503() };
    let net = net_hash(&st.hmac_key, &client_ip(h));
    let p = Parked { token, refresh, expires_at, uid: uid.clone(), net: net.clone() };
    match locked(sb, Some(&uid), &net).await {
        Ok(false) => {}
        Ok(true) => { end_session(sb, &p.token).await; return locked_429(); }
        Err(()) => { end_session(sb, &p.token).await; return busy_503(); }
    }
    let Ok((ticket, th)) = new_ticket() else { end_session(sb, &p.token).await; return busy_503() };
    let opened = sb.rpc_msg("founder_signin_open", json!({"p_uid": uid, "p_ticket_hash": th, "p_net_hash": net, "p_device_hash": Value::Null, "p_method": "password", "p_totp": false})).await;
    match opened.map(|v| reduce_open(&v)) {
        Ok(Opened::Complete) => release(sb, &th, &p).await,
        Ok(Opened::NeedPasskey) => {
            let ok = parked_store().lock().unwrap().put(th.clone(), p, Instant::now(), PARK_TTL);
            if !ok {
                deny(sb, &th, &net, "park_full").await;
                // the session was moved into `put`; if it could not be parked it is dropped here and ends with its own expiry at the identity service
                return busy_503();
            }
            no_store(Json(json!({"step": "passkey", "ticket": ticket, "expires_ms": PARK_TTL.as_millis() as u64})).into_response())
        }
        Ok(Opened::Locked) => { end_session(sb, &p.token).await; locked_429() }
        Ok(Opened::Refused) => { end_session(sb, &p.token).await; generic_401() }
        Err(_) => { end_session(sb, &p.token).await; busy_503() }
    }
}

// ------------------------------------------------------------------------------------------------------------------------------
// passkey path
// ------------------------------------------------------------------------------------------------------------------------------

/// POST /founder/v1/auth/passkey/begin  {ticket?}  -> {ceremony, options}. No ticket = first step (discoverable credential, the server names no account).
pub async fn passkey_begin_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let Some(sb) = st.sb.as_ref() else { return busy_503() };
    let b: Value = serde_json::from_slice(&body).unwrap_or_else(|_| json!({}));
    let ip = client_ip(&h);
    let (ipkey, net, now) = (format!("flogin:ip:{ip}"), net_hash(&st.hmac_key, &ip), Instant::now());
    if st.lim.lock().unwrap().locked(&ipkey, now) { return locked_429(); }
    let origin = match crate::passkey::origin_of(sb, &h).await { Ok(o) => o, Err(r) => return r };
    let pol = match crate::passkey::policy(sb).await { Ok(p) => p, Err(r) => return r };
    let (mut allow, mut ticket) = (Vec::<String>::new(), None);
    if let Some(t) = b["ticket"].as_str().filter(|t| t.len() <= 128) {
        let th = hash_hex(t);
        let uid = parked_store().lock().unwrap().peek(&th, now).filter(|p| p.net == net).map(|p| p.uid.clone());
        let Some(uid) = uid else { return generic_401() };
        allow = crate::passkey::active(sb, &uid).await.iter().filter_map(|a| a["credential_id"].as_str().map(String::from)).collect();
        if allow.is_empty() { return generic_401(); }
        ticket = Some(th);
    }
    let secs = pol["challenge_secs"].as_u64().unwrap_or(120).clamp(30, 120);
    let (Ok(challenge), Ok(id)) = (crate::passkey::random_challenge(), crate::passkey::random_challenge()) else { return busy_503() };
    let cer = Cer { challenge: challenge.clone(), origin, rp: pol["rp_id"].as_str().unwrap_or("").to_string(), net: net.clone(), ticket };
    {
        let mut m = cer_store().lock().unwrap();
        if m.count_where(now, |c| c.net == net) >= CER_PER_NET || !m.put_fair(id.clone(), cer, now, Duration::from_secs(secs), &|c: &Cer| c.net.clone()) { return locked_429(); }
    }
    no_store(Json(json!({"ceremony": id, "options": crate::passkey::get_options(&pol, &challenge, &allow, secs * 1000)})).into_response())
}

/// POST /founder/v1/auth/passkey/finish  {ceremony, credential}
pub async fn passkey_finish_ep(State(st): State<S>, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let Some(sb) = st.sb.as_ref() else { return busy_503() };
    let Ok(b) = serde_json::from_slice::<Value>(&body) else { return generic_401() };
    let ip = client_ip(&h);
    let (ipkey, net, now) = (format!("flogin:ip:{ip}"), net_hash(&st.hmac_key, &ip), Instant::now());
    if st.lim.lock().unwrap().locked(&ipkey, now) { return locked_429(); }
    let resp = finish_inner(&st, sb, &b, &net).await;
    trace("finish", &format!("http={}", resp.status().as_u16()));
    let mut l = st.lim.lock().unwrap();
    match resp.status() { StatusCode::OK => l.clear(&ipkey), StatusCode::UNAUTHORIZED => l.fail(&ipkey, now), _ => {} }
    resp
}

/// The whole proof of one assertion. Err("busy") = a door was down; any other Err = the key did not prove it (reason is for the ledger only).
async fn prove(sb: &Sb, uid: &str, cid: &str, cred: &Value, key: &Value, cer: &Cer) -> Result<(), &'static str> {
    let asr = match crate::passkey::verify_assertion(cred, key, &cer.challenge, &cer.origin, &cer.rp) {
        Ok(a) => a,
        Err(e) => { let _ = sb.rpc("founder_webauthn_fail", json!({"p_uid": uid, "p_credential_id": cid, "p_reason": e})).await; return Err("assertion"); }
    };
    if !asr.credential_id.eq(cid) { return Err("credential_mismatch"); }
    match sb.rpc_msg("founder_webauthn_assert", json!({"p_uid": uid, "p_credential_id": asr.credential_id, "p_in": asr.facts})).await {
        Ok(v) if v["decision"] == "allow" => Ok(()),
        Ok(_) => Err("policy_refused"), // stepup / deny: a passkey that needs extra proof cannot be the whole sign-in
        Err(_) => Err("busy"),
    }
}

/// Mint a session for a founder whose passkey just proved it: identity-service admin API, nothing mailed. Err = no session.
/// One journald line per refusal stage (no ticket, token, key or address in it): the only way to tell which door said no when a phone shows 'not answering'.
fn trace(stage: &str, detail: &str) { eprintln!("founder-signin stage={stage} detail={detail}"); }

async fn mint(sb: &Sb, uid: &str) -> Result<Parked, ()> {
    if uid.is_empty() || !uid.chars().all(|c| c.is_ascii_hexdigit() || c == '-') { return Err(()); }
    let r = sb.http.get(format!("{}/auth/v1/admin/users/{uid}", sb.url)).header("apikey", &sb.key).header("authorization", format!("Bearer {}", sb.key))
        .send().await.map_err(|_| trace("mint_user", "send_failed"))?;
    let c0 = r.status().as_u16();
    let u: Value = r.json().await.map_err(|_| trace("mint_user", &format!("not_json http={c0}")))?;
    let email = u["email"].as_str().filter(|e| crate::login::valid_email(e)).ok_or_else(|| trace("mint_user", &format!("no_email http={c0}")))?.to_string();
    let (c1, link) = gotrue(sb, "admin/generate_link", Some(json!({"type": "magiclink", "email": email})), Some(&sb.key)).await.map_err(|_| trace("mint_link", "send_failed"))?;
    if !(200..300).contains(&c1) { trace("mint_link", &format!("http={c1}")); return Err(()); }
    let th = link["hashed_token"].as_str().or_else(|| link["properties"]["hashed_token"].as_str()).filter(|t| !t.is_empty() && t.len() <= 256).ok_or_else(|| trace("mint_link", "no_hashed_token"))?.to_string();
    let (c2, sess) = gotrue(sb, "verify", Some(json!({"type": "magiclink", "token_hash": th})), None).await.map_err(|_| trace("mint_verify", "send_failed"))?;
    if !(200..300).contains(&c2) { trace("mint_verify", &format!("http={c2}")); }
    match parse_grant(c2, &sess) {
        Grant::Session { token, refresh, expires_at, uid: got, second_factor } => {
            if second_factor || !got.eq_ignore_ascii_case(uid) { end_session(sb, &token).await; return Err(()); }
            Ok(Parked { token, refresh, expires_at, uid: got, net: String::new() })
        }
        _ => Err(()),
    }
}

async fn finish_inner(st: &St, sb: &Sb, b: &Value, net: &str) -> Response {
    let now = Instant::now();
    // 1 the ceremony: single use, expiring, bound to the network that began it
    let cer = match b["ceremony"].as_str().filter(|c| c.len() <= 64).and_then(|id| cer_store().lock().unwrap().take(id, now)) { Some(c) => c, None => return generic_401() };
    if cer.net != net { return generic_401(); }
    // 2 whose key is it (only an ACTIVE passkey of a founder counts; unknown, revoked and foreign look the same from outside)
    let cred = &b["credential"];
    let cid = cred.get("id").and_then(|x| x.as_str()).unwrap_or("");
    if !pc::is_b64url_token(cid, 1400) { return generic_401(); }
    // E154: the key body is readable only through this SQL door (E117 gives service_role no select on the column)
    let found = match sb.rpc_msg("founder_passkey_by_credential", json!({"p_credential_id": cid})).await { Ok(v) => v, Err(_) => { trace("passkey_rows", "founder_passkey_by_credential door failed"); return busy_503() } };
    let (Some(uid), key) = (found["user_id"].as_str().map(str::to_string), found["passkey"].clone()) else { return generic_401() };
    if !sb.is_founder(&uid).await { return generic_401(); }
    match locked(sb, Some(&uid), net).await { Ok(false) => {} Ok(true) => return locked_429(), Err(()) => return busy_503() }
    // 3 which ticket: the parked one (second step) or a fresh passkey ticket (first step)
    let (th, parked) = match &cer.ticket {
        Some(t) => {
            let taken = parked_store().lock().unwrap().take(t, now); // the guard is gone before any await
            match taken {
                Some(p) if p.net == net && p.uid.eq_ignore_ascii_case(&uid) => (t.clone(), Some(p)),
                _ => { deny(sb, t, net, "parked_lost").await; return generic_401(); }
            }
        }
        None => {
            let Ok((_tok, th)) = new_ticket() else { return busy_503() };
            let opened = sb.rpc_msg("founder_signin_open", json!({"p_uid": uid, "p_ticket_hash": th, "p_net_hash": net, "p_device_hash": Value::Null, "p_method": "passkey", "p_totp": false})).await;
            match opened.map(|v| reduce_open(&v)) {
                Ok(Opened::NeedPasskey) => {}
                Ok(Opened::Locked) => return locked_429(),
                Ok(_) => return generic_401(),
                Err(_) => return busy_503(),
            }
            (th, None)
        }
    };
    // 4 the proof, then the ledger
    if let Err(why) = prove(sb, &uid, cid, cred, &key, &cer).await {
        let _ = factor(sb, &th, net, false, cid).await;
        if let Some(p) = &parked { end_session(sb, &p.token).await; }
        if why == "busy" { deny(sb, &th, net, "door_down").await; return busy_503(); }
        return generic_401();
    }
    let done = factor(sb, &th, net, true, cid).await;
    if done.as_ref().map(|v| v["ok"].as_bool() == Some(true) && v["state"] == "complete") != Some(true) {
        if let Some(p) = &parked { end_session(sb, &p.token).await; }
        return generic_401();
    }
    // 5 the session
    let mut session = match parked {
        Some(p) => p,
        None => match mint(sb, &uid).await {
            Ok(p) => p,
            Err(()) => { trace("session_not_minted", "see mint_* line above"); deny(sb, &th, net, "session_not_minted").await; return busy_503(); }
        },
    };
    session.net = net.to_string();
    let _ = st; // the limiter is cleared by the caller on a 200
    release(sb, &th, &session).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::extract::{Path, Query, State as St2};
    use axum::http::Request;
    use axum::routing::{get, post};
    use axum::Router;
    use ring::signature::{Ed25519KeyPair, KeyPair};
    use std::sync::Arc;
    use tower::ServiceExt;

    // ---------------- pure ----------------
    #[test]
    fn network_hash_is_keyed_stable_and_hides_the_address() {
        let a = net_hash(b"k1", "203.0.113.9");
        assert_eq!(a.len(), 64); assert!(a.bytes().all(|c| c.is_ascii_hexdigit()));
        assert_eq!(a, net_hash(b"k1", "203.0.113.9"));
        assert_ne!(a, net_hash(b"k2", "203.0.113.9"));
        assert_ne!(a, net_hash(b"k1", "203.0.113.10"));
        assert!(!a.contains("203"));
    }
    #[test]
    fn client_ip_is_bounded() {
        let mut h = HeaderMap::new();
        assert_eq!(client_ip(&h), "-");
        h.insert("x-real-ip", " 198.51.100.7 ".parse().unwrap());
        assert_eq!(client_ip(&h), "198.51.100.7");
        h.insert("x-real-ip", "x".repeat(400).parse().unwrap());
        assert_eq!(client_ip(&h).len(), 64);
    }
    #[test]
    fn tickets_are_random_and_only_the_hash_matches() {
        let (t1, h1) = new_ticket().unwrap(); let (t2, h2) = new_ticket().unwrap();
        assert_ne!(t1, t2); assert_eq!(h1, hash_hex(&t1)); assert_eq!(h2.len(), 64); assert!(t1.len() >= 40);
    }
    #[test]
    fn open_answers_reduce_closed() {
        assert_eq!(reduce_open(&json!({"ok": true, "state": "complete", "need": []})), Opened::Complete);
        assert_eq!(reduce_open(&json!({"ok": true, "state": "open", "need": ["passkey"]})), Opened::NeedPasskey);
        assert_eq!(reduce_open(&json!({"ok": false, "error": "locked"})), Opened::Locked);
        assert_eq!(reduce_open(&json!({"ok": false, "error": "denied"})), Opened::Refused);
        assert_eq!(reduce_open(&json!({"ok": true, "state": "open", "need": ["totp"]})), Opened::Refused); // a factor this binary cannot honour
        assert_eq!(reduce_open(&json!({"ok": true, "state": "open", "need": ["passkey", "totp"]})), Opened::Refused);
        assert_eq!(reduce_open(&json!({"ok": true, "state": "complete", "need": ["passkey"]})), Opened::Refused);
        assert_eq!(reduce_open(&json!({"state": "complete", "need": []})), Opened::Refused); // no ok = no session
        assert_eq!(reduce_open(&Value::Null), Opened::Refused);
    }
    #[test]
    fn ttl_map_is_single_use_expiring_and_capped() {
        let mut m = TtlMap::new(2); let t0 = Instant::now();
        assert!(m.put("a".into(), 1, t0, Duration::from_secs(10)));
        assert!(!m.put("a".into(), 9, t0, Duration::from_secs(10))); // no overwrite
        assert!(m.put("b".into(), 2, t0, Duration::from_secs(10)));
        assert!(!m.put("c".into(), 3, t0, Duration::from_secs(10))); // cap
        assert_eq!(m.peek("a", t0), Some(&1));
        assert_eq!(m.count_where(t0, |v| *v > 0), 2);
        assert_eq!(m.take("a", t0), Some(1));
        assert_eq!(m.take("a", t0), None); // single use
        assert_eq!(m.take("b", t0 + Duration::from_secs(11)), None); // expired is burnt
        assert_eq!(m.len(), 0);
        assert!(m.put("c".into(), 3, t0 + Duration::from_secs(20), Duration::from_secs(1))); // expired entries do not hold the cap
    }
    #[test]
    fn a_full_map_evicts_the_heaviest_owner_never_a_stranger() {
        let mut m: TtlMap<&'static str> = TtlMap::new(4); let t0 = Instant::now(); let own = |v: &&'static str| v.to_string();
        for (i, o) in ["a", "a", "a", "b"].iter().enumerate() { assert!(m.put_fair(format!("k{i}"), *o, t0 + Duration::from_millis(i as u64), Duration::from_secs(10), &own)); }
        assert!(m.put_fair("c0".into(), "c", t0, Duration::from_secs(10), &own)); // full: the heavy owner "a" pays, with its OLDEST entry
        assert_eq!(m.peek("k0", t0), None); assert_eq!(m.peek("k1", t0), Some(&"a")); assert_eq!(m.peek("k3", t0), Some(&"b")); assert_eq!(m.len(), 4);
        // the attacker keeps pushing: only "a" entries ever disappear, "b" and "c" stay
        for i in 0..6 { assert!(m.put_fair(format!("x{i}"), "a", t0, Duration::from_secs(10), &own)); }
        assert_eq!(m.peek("k3", t0), Some(&"b")); assert_eq!(m.peek("c0", t0), Some(&"c"));
        assert!(!m.put_fair("c0".into(), "c", t0, Duration::from_secs(10), &own)); // same key is never overwritten
    }
    #[test]
    fn release_extras_carry_no_secret() {
        let e = release_extras(&json!({"ok": true, "uid": "u", "method": "password", "new_net": true, "risk": {"level": "medium", "score": 35}, "device_hash": "x"}));
        assert_eq!(e, json!({"method": "password", "new_network": true, "risk": "medium"}));
    }

    // ---------------- end to end: real axum routes, loopback stand-ins of the identity service and PostgREST ----------------
    const UID: &str = "11111111-1111-1111-1111-111111111111";
    const RP: &str = "founderworkspace.anexomail.com";
    const ORIGIN: &str = "https://founderworkspace.anexomail.com";
    const CID: &str = "AbCdEf_-0123456789";

    #[derive(Clone)]
    struct World { rpc: Arc<Mutex<Vec<(String, Value)>>>, word_required: Arc<Mutex<bool>>, sql_down: Arc<Mutex<bool>>, logouts: Arc<Mutex<Vec<String>>>, key: Value, active: Arc<Mutex<bool>>, open_down: Arc<Mutex<bool>>, net_locked: Arc<Mutex<bool>>, bad_pw: Arc<Mutex<bool>>, idp_calls: Arc<Mutex<u32>> }

    fn software_key() -> (Ed25519KeyPair, Value) {
        let kp = Ed25519KeyPair::from_seed_unchecked(&[5u8; 32]).unwrap();
        let jwk = json!({"kty": "OKP", "crv": "Ed25519", "x": pc::b64url_encode(kp.public_key().as_ref())});
        (kp, jwk)
    }
    /// A software authenticator: authenticatorData (rpIdHash, flags, counter) + clientDataJSON, signed over authData || SHA-256(clientData).
    fn assertion(kp: &Ed25519KeyPair, flags: u8, count: u32, challenge: &str, origin: &str, id: &str) -> Value {
        let mut auth = crate::passkey::sha256(RP.as_bytes()).to_vec(); auth.push(flags); auth.extend(count.to_be_bytes());
        let cdj = format!(r#"{{"type":"webauthn.get","challenge":"{challenge}","origin":"{origin}"}}"#);
        let sig = kp.sign(&pc::signed_data(&auth, &crate::passkey::sha256(cdj.as_bytes())));
        json!({"id": id, "response": {"clientDataJSON": pc::b64url_encode(cdj.as_bytes()), "authenticatorData": pc::b64url_encode(&auth), "signature": pc::b64url_encode(sig.as_ref())}})
    }

    async fn spawn_world() -> (String, World) {
        let (_kp, jwk) = software_key();
        let w = World { rpc: Default::default(), word_required: Default::default(), sql_down: Default::default(), logouts: Default::default(), key: jwk, active: Arc::new(Mutex::new(true)), open_down: Default::default(), net_locked: Default::default(), bad_pw: Default::default(), idp_calls: Default::default() };
        let app = Router::new()
            // identity service
            .route("/auth/v1/token", post(|St2(w): St2<World>| async move {
                *w.idp_calls.lock().unwrap() += 1;
                if *w.bad_pw.lock().unwrap() { return (StatusCode::BAD_REQUEST, Json(json!({"error": "invalid_grant"}))); }
                (StatusCode::OK, Json(json!({"access_token": "pw-session-token-0123456789", "refresh_token": "pw-refresh", "expires_at": 4102444800i64, "user": {"id": UID, "factors": []}})))
            }))
            .route("/auth/v1/logout", post(|St2(w): St2<World>, h: HeaderMap| async move { w.logouts.lock().unwrap().push(h.get("authorization").and_then(|v| v.to_str().ok()).unwrap_or("").to_string()); StatusCode::NO_CONTENT }))
            .route("/auth/v1/admin/users/{id}", get(|Path(id): Path<String>| async move { Json(json!({"id": id, "email": "founder@x.com"})) }))
            .route("/auth/v1/admin/generate_link", post(|| async { Json(json!({"hashed_token": "hashed-otp-1"})) }))
            .route("/auth/v1/verify", post(|Json(b): Json<Value>| async move {
                if b["token_hash"] == "hashed-otp-1" { (StatusCode::OK, Json(json!({"access_token": "minted-session-token-0123456789", "refresh_token": "minted-refresh", "expires_at": 4102444800i64, "user": {"id": UID, "factors": []}}))) }
                else { (StatusCode::BAD_REQUEST, Json(json!({}))) }
            }))
            // PostgREST tables
            .route("/rest/v1/founder_accounts", get(|| async { Json(json!([{"user_id": UID}])) }))
            .route("/rest/v1/founder_webauthn_policy", get(|| async { Json(json!([{"rp_id": RP, "origins": [ORIGIN], "challenge_secs": 120, "allowed_algs": [-8, -7], "attestation_pref": "none"}])) }))
            .route("/rest/v1/founder_passkeys", get(|St2(w): St2<World>, Query(q): Query<HashMap<String, String>>| async move {
                let hit = q.get("credential_id").map(|c| c == &format!("eq.{CID}")).unwrap_or(false) && *w.active.lock().unwrap();
                Json(if hit { json!([{"user_id": UID, "passkey": w.key}]) } else { json!([]) })
            }))
            // SQL doors
            .route("/rest/v1/rpc/{name}", post(|St2(w): St2<World>, Path(name): Path<String>, Json(b): Json<Value>| async move {
                w.rpc.lock().unwrap().push((name.clone(), b.clone()));
                if (*w.sql_down.lock().unwrap() && name.starts_with("founder_signin")) || (*w.open_down.lock().unwrap() && name == "founder_signin_open") { return (StatusCode::BAD_GATEWAY, Json(json!({"message": "down"}))); }
                let req = *w.word_required.lock().unwrap();
                let v = match name.as_str() {
                    "founder_webauthn_origin_ok" => json!(true),
                    "founder_passkey_active" => json!([{"credential_id": CID, "passkey": w.key}]),
                    "founder_passkey_by_credential" => if b["p_credential_id"] == CID && *w.active.lock().unwrap() { json!({"user_id": UID, "passkey": w.key}) } else { Value::Null },
                    "founder_signin_locked" => json!({"locked": *w.net_locked.lock().unwrap(), "fails": 0, "retry_s": 0}),
                    "founder_signin_open" => {
                        let m = b["p_method"].as_str().unwrap_or("");
                        if m == "passkey" || (m == "password" && req) { json!({"ok": true, "state": "open", "second_required": true, "need": ["passkey"], "expires_ms": 1}) }
                        else { json!({"ok": true, "state": "complete", "second_required": false, "need": [], "expires_ms": 1}) }
                    }
                    "founder_signin_factor" => if b["p_ok"] == true { json!({"ok": true, "state": "complete", "done": ["passkey"]}) } else { json!({"ok": false, "error": "denied"}) },
                    "founder_signin_release_v2" => json!({"ok": true, "uid": UID, "method": "password", "factors": [], "new_net": true, "risk": {"level": "low", "score": 5, "reasons": []}}),
                    "founder_webauthn_assert" => json!({"decision": "allow", "risk": 1}),
                    _ => json!({"ok": true}),
                };
                (StatusCode::OK, Json(v))
            }))
            .with_state(w.clone());
        let l = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}", l.local_addr().unwrap());
        tokio::spawn(async move { axum::serve(l, app).await.unwrap(); });
        (url, w)
    }
    fn st_for(url: &str) -> S {
        let sb = Sb { url: url.into(), key: "svc".into(), http: reqwest::Client::new() };
        Arc::new(St { sb: Some(sb), hmac_key: b"net-key".to_vec(), jwks: tokio::sync::RwLock::new(vec![]), lim: Default::default(), ft: None, legacy: true, polar: crate::polar::Live::off(), hook: Default::default(), ed: None, reqsig: true, gate: crate::authcache::AuthCache::new(Duration::from_secs(5)), dbsc: crate::dbsc::Mode::Off })
    }
    async fn call(st: &S, path: &str, body: Value, ip: &str) -> (StatusCode, Value) {
        let r = crate::app(st.clone()).oneshot(Request::post(path).header("content-type", "application/json").header("origin", ORIGIN).header("x-real-ip", ip).body(Body::from(body.to_string())).unwrap()).await.unwrap();
        let s = r.status();
        let b = axum::body::to_bytes(r.into_body(), 1 << 20).await.unwrap();
        (s, serde_json::from_slice(&b).unwrap_or(Value::Null))
    }
    fn names(w: &World) -> Vec<String> { w.rpc.lock().unwrap().iter().map(|(n, _)| n.clone()).filter(|n| n.starts_with("founder_signin") || n == "founder_webauthn_assert").collect() }
    fn args(w: &World, name: &str) -> Vec<Value> { w.rpc.lock().unwrap().iter().filter(|(n, _)| n == name).map(|(_, a)| a.clone()).collect() }

    #[tokio::test]
    async fn password_alone_signs_in_when_the_word_is_off_and_the_ledger_sees_it() {
        let (url, w) = spawn_world().await; let st = st_for(&url);
        let (s, j) = call(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "right"}), "198.51.100.1").await;
        assert_eq!(s, StatusCode::OK); assert_eq!(j["token"], "pw-session-token-0123456789"); assert_eq!(j["signin"]["new_network"], true); assert_eq!(j["signin"]["risk"], "low");
        assert_eq!(names(&w), ["founder_signin_locked", "founder_signin_locked", "founder_signin_open", "founder_signin_release_v2"]); // network lock first, then the founder + network lock, then the ceremony
        let o = &args(&w, "founder_signin_open")[0];
        assert_eq!(o["p_method"], "password"); assert_eq!(o["p_uid"], UID);
        let net = o["p_net_hash"].as_str().unwrap(); assert_eq!(net.len(), 64); assert!(!net.contains("198")); // no raw address in the ledger
        assert_eq!(o["p_ticket_hash"].as_str().unwrap().len(), 64);
        assert_eq!(args(&w, "founder_signin_release_v2")[0]["p_net_hash"], net);
        assert!(w.logouts.lock().unwrap().is_empty());
    }

    #[tokio::test]
    async fn a_locked_network_is_refused_before_any_password_is_tried_and_wrong_passwords_reach_the_ledger() {
        let (url, w) = spawn_world().await; let st = st_for(&url);
        // wrong password: 401 AND the append-only ledger is told (E153)
        *w.bad_pw.lock().unwrap() = true;
        assert_eq!(call(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "nope"}), "198.51.100.60").await.0, StatusCode::UNAUTHORIZED);
        let fails = args(&w, "founder_signin_password_fail");
        assert_eq!(fails.len(), 1); assert_eq!(fails[0]["p_net_hash"].as_str().unwrap().len(), 64);
        // the network is locked in the ledger: refused with 429 and the identity service was NEVER asked
        *w.bad_pw.lock().unwrap() = false; *w.net_locked.lock().unwrap() = true;
        let before = *w.idp_calls.lock().unwrap();
        assert_eq!(call(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "right"}), "198.51.100.61").await.0, StatusCode::TOO_MANY_REQUESTS);
        assert_eq!(*w.idp_calls.lock().unwrap(), before);
        // the lock door down: 503, still no password tried
        *w.net_locked.lock().unwrap() = false; *w.sql_down.lock().unwrap() = true;
        assert_eq!(call(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "right"}), "198.51.100.62").await.0, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(*w.idp_calls.lock().unwrap(), before);
    }

    #[tokio::test]
    async fn sql_down_is_503_never_a_session_and_a_late_failure_ends_the_identity_session() {
        let (url, w) = spawn_world().await; let st = st_for(&url);
        // the rulebook is down BEFORE the password: 503 and the identity service is not even asked (see the lock test), nothing to end
        *w.sql_down.lock().unwrap() = true;
        let (s, j) = call(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "right"}), "198.51.100.2").await;
        assert_eq!(s, StatusCode::SERVICE_UNAVAILABLE); assert!(j.get("token").is_none()); assert_eq!(*w.idp_calls.lock().unwrap(), 0);
        // the door fails AFTER the password was accepted (ticket cannot be opened): 503, no token, the identity session is ended
        *w.sql_down.lock().unwrap() = false; *w.open_down.lock().unwrap() = true;
        let (s, j) = call(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "right"}), "198.51.100.3").await;
        assert_eq!(s, StatusCode::SERVICE_UNAVAILABLE); assert!(j.get("token").is_none());
        assert_eq!(w.logouts.lock().unwrap().as_slice(), ["Bearer pw-session-token-0123456789"]);
    }

    #[tokio::test]
    async fn word_required_parks_the_session_and_only_his_passkey_releases_it() {
        let (url, w) = spawn_world().await; let st = st_for(&url); let (kp, _) = software_key();
        *w.word_required.lock().unwrap() = true;
        let (s, j) = call(&st, "/founder/v1/auth/login", json!({"email": "founder@x.com", "password": "right"}), "198.51.100.3").await;
        assert_eq!(s, StatusCode::OK); assert!(j.get("token").is_none()); assert_eq!(j["step"], "passkey");
        let ticket = j["ticket"].as_str().unwrap().to_string();
        // a stranger network cannot even begin with this ticket
        assert_eq!(call(&st, "/founder/v1/auth/passkey/begin", json!({"ticket": ticket}), "198.51.100.99").await.0, StatusCode::UNAUTHORIZED);
        let (s, o) = call(&st, "/founder/v1/auth/passkey/begin", json!({"ticket": ticket}), "198.51.100.3").await;
        assert_eq!(s, StatusCode::OK); assert_eq!(o["options"]["allowCredentials"][0]["id"], CID); assert_eq!(o["options"]["userVerification"], "required");
        let (ch, cer) = (o["options"]["challenge"].as_str().unwrap().to_string(), o["ceremony"].as_str().unwrap().to_string());
        let (s, j) = call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer, "credential": assertion(&kp, 0x05, 1, &ch, ORIGIN, CID)}), "198.51.100.3").await;
        assert_eq!(s, StatusCode::OK); assert_eq!(j["token"], "pw-session-token-0123456789"); // the PARKED password session, no new one minted
        assert_eq!(args(&w, "founder_signin_factor")[0]["p_ok"], true);
        // the ticket was single use: begin again with it is refused
        assert_eq!(call(&st, "/founder/v1/auth/passkey/begin", json!({"ticket": ticket}), "198.51.100.3").await.0, StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn passkey_alone_signs_in_and_every_bad_proof_is_the_same_401() {
        let (url, w) = spawn_world().await; let st = st_for(&url); let (kp, _) = software_key();
        let begin = |ip: &'static str| { let st = st.clone(); async move { let (s, o) = call(&st, "/founder/v1/auth/passkey/begin", json!({}), ip).await; assert_eq!(s, StatusCode::OK); assert_eq!(o["options"]["allowCredentials"], json!([])); (o["options"]["challenge"].as_str().unwrap().to_string(), o["ceremony"].as_str().unwrap().to_string()) } };
        // happy path: a session is minted by the identity service admin API, the ledger gets passkey open + factor ok + release
        let (ch, cer) = begin("198.51.100.10").await;
        let (s, j) = call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer, "credential": assertion(&kp, 0x05, 7, &ch, ORIGIN, CID)}), "198.51.100.10").await;
        assert_eq!(s, StatusCode::OK); assert_eq!(j["token"], "minted-session-token-0123456789");
        assert_eq!(names(&w).iter().filter(|n| *n == "founder_signin_open").count(), 1);
        assert_eq!(args(&w, "founder_signin_open")[0]["p_method"], "passkey");
        assert_eq!(args(&w, "founder_signin_factor")[0]["p_credential_id"], CID);
        // replay of the SAME ceremony: refused
        let (s, _) = call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer, "credential": assertion(&kp, 0x05, 8, &ch, ORIGIN, CID)}), "198.51.100.10").await;
        assert_eq!(s, StatusCode::UNAUTHORIZED);
        // wrong challenge (a signature made for another ceremony): 401 and a factor_fail in the ledger
        let (_ch2, cer2) = begin("198.51.100.11").await;
        let (s, j1) = call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer2, "credential": assertion(&kp, 0x05, 9, "not-the-challenge", ORIGIN, CID)}), "198.51.100.11").await;
        assert_eq!(s, StatusCode::UNAUTHORIZED);
        assert!(args(&w, "founder_signin_factor").iter().any(|a| a["p_ok"] == false));
        // user verification missing (flags UP only): refused
        let (ch3, cer3) = begin("198.51.100.12").await;
        assert_eq!(call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer3, "credential": assertion(&kp, 0x01, 10, &ch3, ORIGIN, CID)}), "198.51.100.12").await.0, StatusCode::UNAUTHORIZED);
        // a different origin in the signed client data: refused
        let (ch4, cer4) = begin("198.51.100.13").await;
        assert_eq!(call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer4, "credential": assertion(&kp, 0x05, 11, &ch4, "https://evil.example", CID)}), "198.51.100.13").await.0, StatusCode::UNAUTHORIZED);
        // a signature by a key that is not his: refused
        let other = Ed25519KeyPair::from_seed_unchecked(&[6u8; 32]).unwrap();
        let (ch5, cer5) = begin("198.51.100.14").await;
        assert_eq!(call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer5, "credential": assertion(&other, 0x05, 12, &ch5, ORIGIN, CID)}), "198.51.100.14").await.0, StatusCode::UNAUTHORIZED);
        // a credential id he does not have, and a revoked one: the same answer as every other refusal
        let (ch6, cer6) = begin("198.51.100.15").await;
        let (s, j2) = call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer6, "credential": assertion(&kp, 0x05, 13, &ch6, ORIGIN, "UnknownCredential-1")}), "198.51.100.15").await;
        assert_eq!(s, StatusCode::UNAUTHORIZED); assert_eq!(j1, j2); // no oracle: wrong challenge and unknown key read the same
        *w.active.lock().unwrap() = false;
        let (ch7, cer7) = begin("198.51.100.16").await;
        assert_eq!(call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer7, "credential": assertion(&kp, 0x05, 14, &ch7, ORIGIN, CID)}), "198.51.100.16").await.0, StatusCode::UNAUTHORIZED);
        *w.active.lock().unwrap() = true;
        // a ceremony cannot be finished from another network
        let (ch8, cer8) = begin("198.51.100.17").await;
        assert_eq!(call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer8, "credential": assertion(&kp, 0x05, 15, &ch8, ORIGIN, CID)}), "198.51.100.18").await.0, StatusCode::UNAUTHORIZED);
        // junk bodies never panic
        assert_eq!(call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": 5}), "198.51.100.19").await.0, StatusCode::UNAUTHORIZED);
        assert_eq!(call(&st, "/founder/v1/auth/passkey/finish", json!({}), "198.51.100.19").await.0, StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn a_down_database_never_mints_a_passkey_session() {
        let (url, w) = spawn_world().await; let st = st_for(&url); let (kp, _) = software_key();
        let (_, o) = call(&st, "/founder/v1/auth/passkey/begin", json!({}), "198.51.100.30").await;
        let (ch, cer) = (o["options"]["challenge"].as_str().unwrap().to_string(), o["ceremony"].as_str().unwrap().to_string());
        *w.sql_down.lock().unwrap() = true;
        let (s, j) = call(&st, "/founder/v1/auth/passkey/finish", json!({"ceremony": cer, "credential": assertion(&kp, 0x05, 1, &ch, ORIGIN, CID)}), "198.51.100.30").await;
        assert_eq!(s, StatusCode::SERVICE_UNAVAILABLE); assert!(j.get("token").is_none());
    }

    #[tokio::test]
    async fn ceremonies_are_capped_per_network() {
        let (url, _w) = spawn_world().await; let st = st_for(&url);
        for _ in 0..CER_PER_NET { assert_eq!(call(&st, "/founder/v1/auth/passkey/begin", json!({}), "198.51.100.40").await.0, StatusCode::OK); }
        assert_eq!(call(&st, "/founder/v1/auth/passkey/begin", json!({}), "198.51.100.40").await.0, StatusCode::TOO_MANY_REQUESTS);
        assert_eq!(call(&st, "/founder/v1/auth/passkey/begin", json!({}), "198.51.100.41").await.0, StatusCode::OK); // another network is not affected
    }
}
