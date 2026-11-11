//! K7 — Device Bound Session Credentials (DBSC), Rust half. SQL (E149) is the memory and the rulebook; this file speaks the Chrome protocol and decides.
//!
//! WHAT IT BUYS: the founder token is minted by `/founder/v1/exchange` every 15 minutes. With DBSC the browser binds the founder DEVICE to a private key it keeps
//! in the TPM / secure hardware (never exportable). A short-lived cookie (`__Host-anx_fdbsc`, 10 min) can only be refreshed by signing a server challenge with
//! that key, so a stolen device id + login token replayed from another machine has no cookie and cannot mint a founder token (mode `enforce`).
//!
//! PROTOCOL (Chrome DBSC, checked 9 Nov 2026 against developer.chrome.com + a protocol write-up; JWT claim names that the sources disagree on are accepted
//! in both places, the signature is what proves the key):
//!   1. exchange answers 200 + `Secure-Session-Registration: (ES256); path="/founder/v1/dbsc/start"; challenge="<stateless signed challenge>"` for an unbound device.
//!   2. Chrome (TPM key) POSTs `/founder/v1/dbsc/start` with header `Secure-Session-Response: <JWT typ dbsc+jwt, alg ES256, jwk, jti = challenge>`.
//!      The registration carries NO bearer (the browser makes it), so the identity (account + device) is INSIDE the HMAC-signed challenge, minted only on an
//!      authenticated, approved exchange. 60 s life, single use (SQL jti ledger). We verify the ES256 proof-of-possession, store the public key, answer the session JSON.
//!   3. Refresh: Chrome POSTs `/founder/v1/dbsc/refresh` with `Sec-Secure-Session-Id`; we answer 403 + `Secure-Session-Challenge: "<ch>";id="<sid>"`;
//!      Chrome signs it with the same key and re-POSTs `Secure-Session-Response`; we verify against the STORED key (a key in the JWT is ignored), consume the jti, Set-Cookie.
//!   4. exchange checks the cookie against the device's bound session (`gate_exchange`).
//! MODES (env FOUNDER_DBSC): `off` (default: every route 404, nothing changes), `observe` (register + refresh + ledger, never block; would-block is logged),
//! `enforce` (a bound device without a valid cookie gets 401 dbsc_required). Unbound devices (phones, Firefox, Safari) are never blocked: honest limit, DBSC is Chromium.
//! Crypto: only audited `ring` (ES256 verify) + `hmac`/`sha2`; no own crypto (FC15). No secret is ever logged or stored: SQL holds the PUBLIC key only.
use axum::{Json, extract::State, http::{HeaderMap, HeaderValue, StatusCode, header}, response::{IntoResponse, Response}};
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD as B64};
use hmac::{Hmac, Mac};
use ring::rand::{SecureRandom, SystemRandom};
use ring::signature::{ECDSA_P256_SHA256_FIXED, UnparsedPublicKey};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

pub const COOKIE: &str = "__Host-anx_fdbsc";
pub const COOKIE_TTL: i64 = 600;
pub const CH_TTL: i64 = 60;
/// 11 Nov 18:40: the refresh challenge lives 15 min (was 60 s). Chrome sometimes answers with a challenge it cached earlier (reject_challenge bad_or_expired every ~22 min in his ledger). Safe: the answer is signed by the
/// chip key, bound to the session id, and its jti is single use (SQL ledger), so a longer window gives a thief nothing.
pub const CH_TTL_REFRESH: i64 = 900;
fn ttl_of(purpose: char) -> i64 { if purpose == 'f' { CH_TTL_REFRESH } else { CH_TTL } }
pub const REG_PATH: &str = "/founder/v1/dbsc/start";
pub const REFRESH_PATH: &str = "/founder/v1/dbsc/refresh";
pub const EXCHANGE_PATH: &str = "/founder/v1/exchange";
pub const DK_REG_PATH: &str = "/founder/v1/devicekey/register";
const SKEW: i64 = 120;
const COOKIE_ATTRS: &str = "Path=/; Secure; HttpOnly; SameSite=Strict";

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Mode { Off, Observe, Enforce }
impl Mode {
    pub fn parse(s: &str) -> Mode { match s.trim().to_ascii_lowercase().as_str() { "observe" => Mode::Observe, "enforce" => Mode::Enforce, _ => Mode::Off } }
    pub fn as_str(self) -> &'static str { match self { Mode::Off => "off", Mode::Observe => "observe", Mode::Enforce => "enforce" } }
}

#[derive(Debug, PartialEq)]
pub enum DErr { Malformed, Alg, Typ, Key, Signature, Jti, Iat, Aud, Challenge, Expired, Purpose, Device }

type HmacSha = Hmac<Sha256>;
/// Sub-keys from the server secret, one label each (a leaked cookie key is not a challenge key).
pub fn subkey(master: &[u8], label: &str) -> Vec<u8> {
    let mut m = HmacSha::new_from_slice(master).expect("hmac takes any key length");
    m.update(b"anexo-founder-dbsc-v1|"); m.update(label.as_bytes());
    m.finalize().into_bytes().to_vec()
}
fn mac(key: &[u8], msg: &[u8]) -> Vec<u8> { let mut m = HmacSha::new_from_slice(key).expect("hmac"); m.update(msg); m.finalize().into_bytes().to_vec() }
fn mac_ok(key: &[u8], msg: &[u8], tag: &[u8]) -> bool { let mut m = HmacSha::new_from_slice(key).expect("hmac"); m.update(msg); m.verify_slice(tag).is_ok() }
pub fn sha256_hex(s: &str) -> String { hex::encode(Sha256::digest(s.as_bytes())) }
fn rand_bytes<const N: usize>() -> Option<[u8; N]> { let mut b = [0u8; N]; SystemRandom::new().fill(&mut b).ok()?; Some(b) }
pub fn new_sid() -> Option<String> { rand_bytes::<18>().map(|b| B64.encode(b)) }

// ------------------------------------------------------------------ challenges (stateless, signed, 60 s, single use via the SQL jti ledger)
#[derive(Debug, PartialEq)]
pub struct Ch { pub purpose: char, pub a: String, pub b: String }

/// purpose 'r' (registration): a = account uid, b = device hash. purpose 'f' (refresh): a = session id, b = "".
pub fn mint_challenge(key: &[u8], purpose: char, a: &str, b: &str, now: i64) -> Option<String> {
    if a.contains('|') || b.contains('|') || a.is_empty() { return None; }
    let nonce = hex::encode(rand_bytes::<16>()?);
    let payload = format!("{purpose}|{}|{nonce}|{a}|{b}", now + ttl_of(purpose));
    Some(format!("{}.{}", B64.encode(payload.as_bytes()), B64.encode(mac(key, payload.as_bytes()))))
}
pub fn check_challenge(key: &[u8], token: &str, want: char, now: i64) -> Result<Ch, DErr> {
    if token.len() > 600 { return Err(DErr::Malformed); }
    let (p, t) = token.split_once('.').ok_or(DErr::Malformed)?;
    let payload = B64.decode(p).map_err(|_| DErr::Malformed)?;
    let tag = B64.decode(t).map_err(|_| DErr::Malformed)?;
    if !mac_ok(key, &payload, &tag) { return Err(DErr::Challenge); }
    let s = String::from_utf8(payload).map_err(|_| DErr::Malformed)?;
    let f: Vec<&str> = s.splitn(5, '|').collect();
    if f.len() != 5 { return Err(DErr::Malformed); }
    let purpose = f[0].chars().next().ok_or(DErr::Malformed)?;
    if purpose != want { return Err(DErr::Purpose); }
    let exp: i64 = f[1].parse().map_err(|_| DErr::Malformed)?;
    if now > exp { return Err(DErr::Expired); }
    if exp - now > ttl_of(purpose) + SKEW { return Err(DErr::Malformed); } // a challenge from the far future is not ours
    Ok(Ch { purpose, a: f[3].to_string(), b: f[4].to_string() })
}

// ------------------------------------------------------------------ the short-lived cookie
pub fn mint_cookie(key: &[u8], sid: &str, now: i64) -> String {
    let exp = now + COOKIE_TTL;
    let msg = format!("c|{sid}|{exp}");
    format!("v1.{sid}.{exp}.{}", B64.encode(mac(key, msg.as_bytes())))
}
/// The session id inside a valid, unexpired cookie value (None for anything else).
pub fn check_cookie(key: &[u8], value: &str, now: i64) -> Option<String> {
    let f: Vec<&str> = value.split('.').collect();
    if f.len() != 4 || f[0] != "v1" || value.len() > 200 { return None; }
    let exp: i64 = f[2].parse().ok()?;
    if now >= exp || exp - now > COOKIE_TTL + SKEW { return None; }
    let tag = B64.decode(f[3]).ok()?;
    if !mac_ok(key, format!("c|{}|{exp}", f[1]).as_bytes(), &tag) { return None; }
    Some(f[1].to_string())
}
pub fn set_cookie_value(value: &str) -> String { format!("{COOKIE}={value}; Max-Age={COOKIE_TTL}; {COOKIE_ATTRS}") }
/// Find our cookie in a `Cookie:` header.
pub fn cookie_from(h: &HeaderMap) -> Option<String> {
    for v in h.get_all(header::COOKIE) {
        for part in v.to_str().ok()?.split(';') {
            if let Some(val) = part.trim().strip_prefix(COOKIE).and_then(|r| r.strip_prefix('=')) { return Some(val.to_string()); }
        }
    }
    None
}

// ------------------------------------------------------------------ JWT (ES256, typ dbsc+jwt)
pub struct Jwt { pub header: Value, pub payload: Value, input: String, sig: Vec<u8> }
pub fn parse_jwt(t: &str) -> Result<Jwt, DErr> {
    if t.len() > 4096 { return Err(DErr::Malformed); }
    let p: Vec<&str> = t.split('.').collect();
    if p.len() != 3 { return Err(DErr::Malformed); }
    let dec = |s: &str| B64.decode(s).map_err(|_| DErr::Malformed);
    Ok(Jwt { header: serde_json::from_slice(&dec(p[0])?).map_err(|_| DErr::Malformed)?, payload: serde_json::from_slice(&dec(p[1])?).map_err(|_| DErr::Malformed)?,
             input: format!("{}.{}", p[0], p[1]), sig: dec(p[2])? })
}
/// The `jti` of a JWT BEFORE it is verified: only used to find the challenge (which is itself MAC-checked) and never trusted on its own.
pub fn peek_jti(t: &str) -> Option<String> { parse_jwt(t).ok()?.payload["jti"].as_str().map(String::from) }

fn jwk_to_sec1(jwk: &Value) -> Result<[u8; 65], DErr> {
    if jwk["kty"].as_str() != Some("EC") || jwk["crv"].as_str() != Some("P-256") { return Err(DErr::Key); }
    let (x, y) = (B64.decode(jwk["x"].as_str().ok_or(DErr::Key)?).map_err(|_| DErr::Key)?, B64.decode(jwk["y"].as_str().ok_or(DErr::Key)?).map_err(|_| DErr::Key)?);
    if x.len() != 32 || y.len() != 32 { return Err(DErr::Key); }
    let mut out = [0u8; 65]; out[0] = 4; out[1..33].copy_from_slice(&x); out[33..].copy_from_slice(&y);
    Ok(out)
}
fn verify_sig(pubkey: &[u8], j: &Jwt) -> Result<(), DErr> { UnparsedPublicKey::new(&ECDSA_P256_SHA256_FIXED, pubkey).verify(j.input.as_bytes(), &j.sig).map_err(|_| DErr::Signature) }
fn common(j: &Jwt, challenge: &str, now: i64, path: &str) -> Result<(), DErr> {
    if j.header["alg"].as_str() != Some("ES256") { return Err(DErr::Alg); }   // none / HS256 / RS256: never
    if j.header["typ"].as_str() != Some("dbsc+jwt") { return Err(DErr::Typ); }
    if j.payload["jti"].as_str() != Some(challenge) { return Err(DErr::Jti); }
    if let Some(iat) = j.payload.get("iat") { if iat.as_i64().is_none_or(|i| (now - i).abs() > SKEW) { return Err(DErr::Iat); } }
    if let Some(aud) = j.payload.get("aud") { if !aud.as_str().is_some_and(|a| a.starts_with("https://") && a.ends_with(path)) { return Err(DErr::Aud); } }
    Ok(())
}
/// Registration proof: the JWT is signed by the key it carries (proof of possession). Returns the 65-byte SEC1 public key.
pub fn verify_registration(jwt: &str, challenge: &str, now: i64) -> Result<[u8; 65], DErr> {
    let j = parse_jwt(jwt)?;
    common(&j, challenge, now, REG_PATH)?;
    let jwk = if j.header.get("jwk").is_some() { &j.header["jwk"] } else { &j.payload["key"] };
    let key = jwk_to_sec1(jwk)?;
    verify_sig(&key, &j)?;
    Ok(key)
}
/// Refresh proof: checked ONLY against the key stored at registration; a key inside the JWT is ignored.
pub fn verify_refresh(jwt: &str, challenge: &str, stored: &[u8], now: i64) -> Result<(), DErr> {
    let j = parse_jwt(jwt)?;
    common(&j, challenge, now, REFRESH_PATH)?;
    verify_sig(stored, &j)
}


// ------------------------------------------------------------------ K7b: device-key proof for EVERY browser (WebCrypto non-extractable P-256, same ES256 JWT shape)
/// DPoP-style proof, no challenge round trip: `jti` = a random client nonce (single use, kept >= 1 day in the E149 jti ledger), `iat` within 120 s, `aud` = the exact route,
/// `dh` = sha-256 of the device id (the proof is only good for THIS device). `stored` = the key registered earlier (exchange); None = registration, the key comes from the header jwk
/// and the signature proves possession. Returns (jti, 65-byte key).
pub fn verify_proof(jwt: &str, path: &str, stored: Option<&[u8]>, dev_hash: &str, now: i64) -> Result<(String, [u8; 65]), DErr> {
    let j = parse_jwt(jwt)?;
    if j.header["alg"].as_str() != Some("ES256") { return Err(DErr::Alg); }
    if j.header["typ"].as_str() != Some("dbsc+jwt") { return Err(DErr::Typ); }
    let jti = j.payload["jti"].as_str().filter(|x| (16..=64).contains(&x.len()) && x.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')).ok_or(DErr::Jti)?.to_string();
    let iat = j.payload["iat"].as_i64().ok_or(DErr::Iat)?;
    if (now - iat).abs() > SKEW { return Err(DErr::Iat); }
    if !j.payload["aud"].as_str().is_some_and(|a| a.starts_with("https://") && a.ends_with(path)) { return Err(DErr::Aud); }
    if j.payload["dh"].as_str() != Some(dev_hash) { return Err(DErr::Device); }
    let key: [u8; 65] = match stored { Some(k) => k.try_into().map_err(|_| DErr::Key)?, None => jwk_to_sec1(&j.header["jwk"])? };
    verify_sig(&key, &j)?;
    Ok((jti, key))
}

// ------------------------------------------------------------------ the exchange decision (pure)
#[derive(Debug, PartialEq)]
pub enum Decision { Allow, AllowWould(&'static str), Block(&'static str) }
/// K7 wire fix: the registration header goes to a device with no binding, and in OBSERVE mode also to a bound device whose browser showed no live key this time (its old session is
/// replaced, so the Trust seal's Device key becomes real). Never in enforce: there a stolen token could otherwise re-bind a device to the thief's key.
/// 11 Nov 19:45: a device bound by a LIVE secure-chip key (`chip_alive`) is NEVER re-offered a new key (every re-offer replaced the binding = churn). A chip binding that has been silent for
/// `CHIP_DEAD_S` (Chrome ended its DBSC session after a 4xx, cookie gone for good) is NOT alive: in observe mode it is offered a fresh registration, so the device heals by itself. Enforce never re-offers.
pub const CHIP_DEAD_S: i64 = 1200;
pub fn offer_binding(mode: Mode, bound: bool, has_key: bool, chip_alive: bool) -> bool { mode != Mode::Off && (!bound || (mode == Mode::Observe && !has_key && !chip_alive)) }
/// Pure: is this chip binding alive? (`idle_s` = seconds since it last refreshed or was made; unknown = alive, never a surprise re-bind.)
pub fn chip_alive(is_chip: bool, idle_s: Option<i64>) -> bool { is_chip && idle_s.map_or(true, |s| s < CHIP_DEAD_S) }

pub fn gate_exchange(mode: Mode, bound_sid: Option<&str>, cookie_sid: Option<&str>) -> Decision {
    let Some(bound) = bound_sid else { return Decision::Allow };   // unbound device (phone, Firefox, Safari): never blocked
    if mode == Mode::Off || cookie_sid == Some(bound) { return Decision::Allow; }
    let why = if cookie_sid.is_none() { "no_cookie" } else { "wrong_session" };
    if mode == Mode::Enforce { Decision::Block(why) } else { Decision::AllowWould(why) }
}

pub fn registration_header(key: &[u8], uid: &str, dev_hash: &str, now: i64) -> Option<HeaderValue> {
    let ch = mint_challenge(key, 'r', uid, dev_hash, now)?;
    HeaderValue::from_str(&format!("(ES256); path=\"{REG_PATH}\"; challenge=\"{ch}\"")).ok()
}

// ------------------------------------------------------------------ routes
fn now_s() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }
fn no_store(mut r: Response) -> Response { r.headers_mut().insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store")); r }
fn err(code: StatusCode, why: &str) -> Response { no_store((code, Json(json!({"error": why}))).into_response()) }
fn hv<'a>(h: &'a HeaderMap, k: &str) -> Option<&'a str> { h.get(k).and_then(|v| v.to_str().ok()) }
fn sid_ok(s: &str) -> bool { (16..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_') }
fn host_ok(h: &str) -> bool { !h.is_empty() && h.len() <= 253 && h.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'.' || b == b'-' || b == b':') }

/// POST /founder/v1/dbsc/start — the browser registers its TPM key. No bearer: the signed challenge carries the account + device.
pub async fn start_ep(State(st): State<crate::S>, h: HeaderMap) -> Response {
    if st.dbsc == Mode::Off { return StatusCode::NOT_FOUND.into_response(); }
    let Some(sb) = st.sb.as_ref() else { return err(StatusCode::SERVICE_UNAVAILABLE, "database not configured") };
    let Some(jwt) = hv(&h, "secure-session-response") else { return err(StatusCode::BAD_REQUEST, "missing proof") };
    let Some(jti) = peek_jti(jwt) else { return err(StatusCode::BAD_REQUEST, "malformed proof") };
    let (ck, cookie_key, now) = (subkey(&st.hmac_key, "challenge"), subkey(&st.hmac_key, "cookie"), now_s());
    let ch = match check_challenge(&ck, &jti, 'r', now) { Ok(c) => c, Err(_) => return err(StatusCode::FORBIDDEN, "challenge refused") };
    let pubkey = match verify_registration(jwt, &jti, now) { Ok(k) => k, Err(e) => return err(StatusCode::BAD_REQUEST, &format!("proof refused: {e:?}").to_ascii_lowercase()) };
    let (Some(sid), Ok(uid)) = (new_sid(), uuid_like(&ch.a)) else { return err(StatusCode::INTERNAL_SERVER_ERROR, "no session id") };
    let r = sb.rpc("founder_dbsc_register", json!({"p_uid": uid, "p_device_hash": ch.b, "p_sid": sid, "p_pub": hex::encode(pubkey), "p_jti_hash": sha256_hex(&jti)})).await;
    match r {
        Some(v) if v["ok"].as_bool() == Some(true) => {
            let host = crate::hostproof::host_of(&h);
            let origin = if host_ok(&host) { format!("https://{host}") } else { return err(StatusCode::BAD_REQUEST, "bad host") };
            let body = json!({"session_identifier": sid, "refresh_url": REFRESH_PATH,
                "scope": {"origin": origin, "include_site": false},
                "credentials": [{"type": "cookie", "name": COOKIE, "attributes": COOKIE_ATTRS}]});
            let mut resp = no_store(Json(body).into_response());
            if let Ok(c) = HeaderValue::from_str(&set_cookie_value(&mint_cookie(&cookie_key, &sid, now))) { resp.headers_mut().append(header::SET_COOKIE, c); }
            resp
        }
        Some(v) => err(StatusCode::CONFLICT, v["error"].as_str().unwrap_or("refused")),
        None => err(StatusCode::SERVICE_UNAVAILABLE, "ledger unavailable: run the E149 SQL (sql-run.sh)"),
    }
}

fn uuid_like(s: &str) -> Result<String, ()> { if s.len() == 36 && s.bytes().all(|b| b.is_ascii_hexdigit() || b == b'-') { Ok(s.to_string()) } else { Err(()) } }

/// 403 + a FRESH refresh challenge. 11 Nov 19:25: Chrome ends a DBSC session for good on any other 4xx (a 400 on refresh = no cookie ever again until a new registration), so every
/// refusal that a new challenge can cure (expired, cached, other session) answers THIS, never 400. Chrome retries once with the new challenge.
fn challenge_403(ck: &[u8], sid: &str, now: i64) -> Response {
    let Some(ch) = mint_challenge(ck, 'f', sid, "", now) else { return err(StatusCode::INTERNAL_SERVER_ERROR, "no challenge") };
    let mut r = err(StatusCode::FORBIDDEN, "challenge");
    if let Ok(v) = HeaderValue::from_str(&format!("\"{ch}\";id=\"{sid}\"")) { r.headers_mut().insert("secure-session-challenge", v); }
    r
}

/// POST /founder/v1/dbsc/refresh — 403 + challenge, then verify the signed answer against the STORED key and hand out a fresh cookie.
pub async fn refresh_ep(State(st): State<crate::S>, h: HeaderMap) -> Response {
    if st.dbsc == Mode::Off { return StatusCode::NOT_FOUND.into_response(); }
    let Some(sb) = st.sb.as_ref() else { return err(StatusCode::SERVICE_UNAVAILABLE, "database not configured") };
    let Some(sid) = hv(&h, "sec-secure-session-id").map(|s| s.trim().trim_matches('"').to_string()).filter(|s| sid_ok(s)) else { return err(StatusCode::BAD_REQUEST, "bad session id") };
    let Some(s) = sb.rpc("founder_dbsc_get", json!({"p_sid": sid})).await else { return err(StatusCode::SERVICE_UNAVAILABLE, "ledger unavailable") };
    if s["found"].as_bool() != Some(true) || s["revoked"].as_bool() == Some(true) { return err(StatusCode::BAD_REQUEST, "unknown or ended session"); }
    let (ck, cookie_key, now) = (subkey(&st.hmac_key, "challenge"), subkey(&st.hmac_key, "cookie"), now_s());
    let uid = s["uid"].as_str().unwrap_or("").to_string();
    let Some(jwt) = hv(&h, "secure-session-response") else { return challenge_403(&ck, &sid, now) };
    let log = |kind: &'static str, why: &'static str| { let (sb, uid, sid) = (sb.clone(), uid.clone(), sid.clone()); tokio::spawn(async move { let _ = sb.rpc("founder_dbsc_event", json!({"p_uid": uid, "p_sid": sid, "p_kind": kind, "p_facts": {"why": why}})).await; }); };
    let Some(jti) = peek_jti(jwt) else { log("reject_challenge", "malformed"); return err(StatusCode::BAD_REQUEST, "malformed proof") };
    match check_challenge(&ck, &jti, 'f', now) {
        Ok(c) if c.a == sid => {}
        Ok(_) => { log("reject_challenge", "other_session"); return challenge_403(&ck, &sid, now) }
        Err(DErr::Expired) => { log("reject_challenge", "expired"); return challenge_403(&ck, &sid, now) }
        Err(DErr::Challenge) => { log("reject_challenge", "bad_mac"); return challenge_403(&ck, &sid, now) }
        Err(_) => { log("reject_challenge", "bad_or_expired"); return challenge_403(&ck, &sid, now) }
    }
    let stored = hex::decode(s["pub"].as_str().unwrap_or("")).unwrap_or_default();
    if verify_refresh(jwt, &jti, &stored, now).is_err() { log("reject_signature", "bad_proof"); return err(StatusCode::BAD_REQUEST, "proof refused"); }
    match sb.rpc("founder_dbsc_refreshed", json!({"p_sid": sid, "p_jti_hash": sha256_hex(&jti)})).await {
        Some(v) if v["ok"].as_bool() == Some(true) => {
            let mut r = no_store(StatusCode::OK.into_response());
            if let Ok(c) = HeaderValue::from_str(&set_cookie_value(&mint_cookie(&cookie_key, &sid, now))) { r.headers_mut().append(header::SET_COOKIE, c); }
            r
        }
        Some(v) => err(StatusCode::BAD_REQUEST, v["error"].as_str().unwrap_or("refused")),
        None => err(StatusCode::SERVICE_UNAVAILABLE, "ledger unavailable"),
    }
}


#[derive(serde::Deserialize)]
pub struct DeviceIn { pub device_id: String }

/// POST /founder/v1/devicekey/register — K7b: any browser registers the PUBLIC half of its non-extractable WebCrypto key. Same trust as the exchange (the signed-in session
/// token), plus a proof signed by the key itself. A secure-chip (dbsc) session on the same device is never replaced (E150).
pub async fn devicekey_register_ep(State(st): State<crate::S>, h: HeaderMap, Json(b): Json<DeviceIn>) -> Response {
    if st.dbsc == Mode::Off { return StatusCode::NOT_FOUND.into_response(); }
    let c = match crate::authed_session(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    let Some(sb) = st.sb.as_ref() else { return err(StatusCode::SERVICE_UNAVAILABLE, "database not configured") };
    if !crate::ftoken::valid_device_id(&b.device_id) { return err(StatusCode::BAD_REQUEST, "invalid device id"); }
    let Some(proof) = hv(&h, "x-device-proof") else { return err(StatusCode::BAD_REQUEST, "missing proof") };
    let dev_hash = crate::ftoken::device_hash(&b.device_id);
    let (jti, key) = match verify_proof(proof, DK_REG_PATH, None, &dev_hash, now_s()) { Ok(x) => x, Err(e) => return err(StatusCode::BAD_REQUEST, &format!("proof refused: {e:?}").to_ascii_lowercase()) };
    let Some(sid) = new_sid() else { return err(StatusCode::INTERNAL_SERVER_ERROR, "no session id") };
    match sb.rpc("founder_dbsc_register_src", json!({"p_uid": c.sub, "p_device_hash": dev_hash, "p_sid": sid, "p_pub": hex::encode(key), "p_jti_hash": sha256_hex(&jti), "p_source": "webcrypto"})).await {
        Some(v) if v["ok"].as_bool() == Some(true) => no_store(Json(json!({"ok": true, "source": v["source"], "kept": v["kept"]})).into_response()),
        Some(v) => err(StatusCode::CONFLICT, v["error"].as_str().unwrap_or("refused")),
        None => err(StatusCode::SERVICE_UNAVAILABLE, "ledger unavailable: run the E150 SQL (sql-run.sh)"),
    }
}

/// GET /founder/v1/dbsc/status — for the founder screen: mode, this founder's devices with their binding, and the ledger report (signed like every answer).
pub async fn status_ep(State(st): State<crate::S>, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(code) => return code.into_response() };
    let did = crate::passkey::did_of(&st, &h);
    let Some(sb) = st.sb.as_ref() else { return crate::signed(&st, json!({"mode": st.dbsc.as_str(), "available": false, "note": "database not configured"})) };
    let (devs, rep) = tokio::join!(sb.rpc("founder_dbsc_devices", json!({"p_uid": c.sub})), sb.rpc("founder_dbsc_report", json!({"p_uid": c.sub})));
    match (devs, rep) {
        (Some(d), Some(r)) => crate::signed(&st, json!({"mode": st.dbsc.as_str(), "available": true, "this_device": did, "devices": d, "report": r,
            "limit": "DBSC (secure chip) exists only in Chromium. Every other browser and phone is bound by a non-extractable browser key; both show here."})),
        _ => crate::signed(&st, json!({"mode": st.dbsc.as_str(), "available": false, "note": "ledger not found: run the E149 SQL (sql-run.sh)"})),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ring::signature::{ECDSA_P256_SHA256_FIXED_SIGNING, EcdsaKeyPair, KeyPair};
    const NOW: i64 = 1_800_000_000;
    fn pair() -> EcdsaKeyPair { let r = SystemRandom::new(); EcdsaKeyPair::from_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, &r).unwrap().as_ref(), &r).unwrap() }
    fn jwk(p: &EcdsaKeyPair) -> Value { let k = p.public_key().as_ref(); json!({"kty": "EC", "crv": "P-256", "x": B64.encode(&k[1..33]), "y": B64.encode(&k[33..])}) }
    fn jwt(p: &EcdsaKeyPair, header: Value, payload: Value) -> String {
        let input = format!("{}.{}", B64.encode(header.to_string()), B64.encode(payload.to_string()));
        format!("{input}.{}", B64.encode(p.sign(&SystemRandom::new(), input.as_bytes()).unwrap().as_ref()))
    }
    fn reg_jwt(p: &EcdsaKeyPair, ch: &str) -> String { jwt(p, json!({"alg": "ES256", "typ": "dbsc+jwt", "jwk": jwk(p)}), json!({"jti": ch, "iat": NOW, "aud": "https://founder.example.com/founder/v1/dbsc/start"})) }
    fn ref_jwt(p: &EcdsaKeyPair, ch: &str) -> String { jwt(p, json!({"alg": "ES256", "typ": "dbsc+jwt"}), json!({"jti": ch, "iat": NOW})) }
    const UID: &str = "11111111-2222-3333-4444-555555555555";
    fn dev() -> String { sha256_hex("device-a") }

    #[test]
    fn modes_parse_and_default_off() {
        assert_eq!(Mode::parse(""), Mode::Off); assert_eq!(Mode::parse("garbage"), Mode::Off);
        assert_eq!(Mode::parse(" Observe "), Mode::Observe); assert_eq!(Mode::parse("ENFORCE"), Mode::Enforce);
    }
    #[test]
    fn subkeys_differ_per_label_and_master() {
        assert_ne!(subkey(b"m", "challenge"), subkey(b"m", "cookie"));
        assert_ne!(subkey(b"m", "cookie"), subkey(b"n", "cookie"));
        assert_eq!(subkey(b"m", "cookie"), subkey(b"m", "cookie"));
    }
    #[test]
    fn challenge_round_trip_and_binding() {
        let k = subkey(b"m", "challenge");
        let t = mint_challenge(&k, 'r', UID, &dev(), NOW).unwrap();
        assert_eq!(check_challenge(&k, &t, 'r', NOW + 10), Ok(Ch { purpose: 'r', a: UID.into(), b: dev() }));
        assert_eq!(check_challenge(&k, &t, 'f', NOW), Err(DErr::Purpose));            // a registration challenge is not a refresh challenge
        assert_eq!(check_challenge(&k, &t, 'r', NOW + CH_TTL + 1), Err(DErr::Expired));
        let f = mint_challenge(&k, 'f', "sid-aaaaaaaaaaaaaaaa", "", NOW).unwrap();   // refresh challenge: 15 min, not 60 s
        assert!(check_challenge(&k, &f, 'f', NOW + 800).is_ok());
        assert_eq!(check_challenge(&k, &f, 'f', NOW + CH_TTL_REFRESH + 1), Err(DErr::Expired));
        assert_eq!(check_challenge(&subkey(b"other", "challenge"), &t, 'r', NOW), Err(DErr::Challenge));
        let (p, tag) = t.split_once('.').unwrap();
        let forged = format!("{}.{tag}", B64.encode(String::from_utf8(B64.decode(p).unwrap()).unwrap().replace(UID, "99999999-2222-3333-4444-555555555555")));
        assert_eq!(check_challenge(&k, &forged, 'r', NOW), Err(DErr::Challenge));     // swapping the account inside breaks the MAC
        for bad in ["", "x", "a.b", &"A".repeat(700)] { assert!(check_challenge(&k, bad, 'r', NOW).is_err()); }
        assert!(mint_challenge(&k, 'r', "a|b", "", NOW).is_none() && mint_challenge(&k, 'r', "", "", NOW).is_none());
        assert_ne!(t, mint_challenge(&k, 'r', UID, &dev(), NOW).unwrap());           // nonce: two challenges never equal
    }
    #[test]
    fn cookie_round_trip_expiry_forgery() {
        let k = subkey(b"m", "cookie");
        let c = mint_cookie(&k, "SID1234567890123456", NOW);
        assert_eq!(check_cookie(&k, &c, NOW + 5).as_deref(), Some("SID1234567890123456"));
        assert_eq!(check_cookie(&k, &c, NOW + COOKIE_TTL), None);                      // expired exactly at the edge
        assert_eq!(check_cookie(&subkey(b"x", "cookie"), &c, NOW), None);
        assert_eq!(check_cookie(&k, &c.replace("SID1234567890123456", "SID9999999999999999"), NOW), None);
        assert_eq!(check_cookie(&k, &c.replace(&format!(".{}.", NOW + COOKIE_TTL), &format!(".{}.", NOW + 999_999)), NOW), None);
        for bad in ["", "v1.a.b", "v2.a.1.c", "v1.a.notnum.c"] { assert_eq!(check_cookie(&k, bad, NOW), None); }
        assert!(set_cookie_value(&c).starts_with("__Host-anx_fdbsc=") && set_cookie_value(&c).contains("Secure; HttpOnly; SameSite=Strict") && !set_cookie_value(&c).contains("Domain"));
    }
    #[test]
    fn cookie_header_parsing() {
        let mut h = HeaderMap::new();
        h.append(header::COOKIE, HeaderValue::from_static("a=1; __Host-anx_fdbsc=v1.x.2.y; b=2"));
        assert_eq!(cookie_from(&h).as_deref(), Some("v1.x.2.y"));
        let mut h2 = HeaderMap::new(); h2.append(header::COOKIE, HeaderValue::from_static("__Host-anx_fdbsc_other=zzz; a=1"));
        assert_eq!(cookie_from(&h2), None);
        assert_eq!(cookie_from(&HeaderMap::new()), None);
    }
    #[test]
    fn registration_accepts_real_proof_and_returns_the_key() {
        let p = pair(); let k = subkey(b"m", "challenge");
        let ch = mint_challenge(&k, 'r', UID, &dev(), NOW).unwrap();
        let key = verify_registration(&reg_jwt(&p, &ch), &ch, NOW).unwrap();
        assert_eq!(&key[..], p.public_key().as_ref());
        // the claim names sources disagree on: key in the payload instead of the header jwk, and no iat/aud at all
        let alt = jwt(&p, json!({"alg": "ES256", "typ": "dbsc+jwt"}), json!({"jti": ch, "key": jwk(&p)}));
        assert_eq!(verify_registration(&alt, &ch, NOW).unwrap()[..], key[..]);
    }
    #[test]
    fn registration_refuses_every_bad_proof() {
        let (p, other) = (pair(), pair()); let k = subkey(b"m", "challenge");
        let ch = mint_challenge(&k, 'r', UID, &dev(), NOW).unwrap();
        let good_h = json!({"alg": "ES256", "typ": "dbsc+jwt", "jwk": jwk(&p)});
        assert_eq!(verify_registration(&jwt(&p, json!({"alg": "none", "typ": "dbsc+jwt", "jwk": jwk(&p)}), json!({"jti": ch})), &ch, NOW), Err(DErr::Alg));
        assert_eq!(verify_registration(&jwt(&p, json!({"alg": "HS256", "typ": "dbsc+jwt", "jwk": jwk(&p)}), json!({"jti": ch})), &ch, NOW), Err(DErr::Alg));
        assert_eq!(verify_registration(&jwt(&p, json!({"alg": "ES256", "typ": "JWT", "jwk": jwk(&p)}), json!({"jti": ch})), &ch, NOW), Err(DErr::Typ));
        assert_eq!(verify_registration(&jwt(&p, good_h.clone(), json!({"jti": "someone-elses"})), &ch, NOW), Err(DErr::Jti));
        assert_eq!(verify_registration(&jwt(&p, good_h.clone(), json!({"jti": ch, "iat": NOW - 500})), &ch, NOW), Err(DErr::Iat));
        assert_eq!(verify_registration(&jwt(&p, good_h.clone(), json!({"jti": ch, "iat": "now"})), &ch, NOW), Err(DErr::Iat));
        assert_eq!(verify_registration(&jwt(&p, good_h.clone(), json!({"jti": ch, "aud": "https://evil.example/other"})), &ch, NOW), Err(DErr::Aud));
        assert_eq!(verify_registration(&jwt(&p, good_h.clone(), json!({"jti": ch, "aud": "http://x/founder/v1/dbsc/start"})), &ch, NOW), Err(DErr::Aud));
        // signed by a DIFFERENT key than the jwk it presents: no proof of possession
        assert_eq!(verify_registration(&jwt(&other, good_h.clone(), json!({"jti": ch})), &ch, NOW), Err(DErr::Signature));
        // wrong curve / short coordinates / no key
        assert_eq!(verify_registration(&jwt(&p, json!({"alg": "ES256", "typ": "dbsc+jwt", "jwk": {"kty": "EC", "crv": "P-384", "x": "AA", "y": "AA"}}), json!({"jti": ch})), &ch, NOW), Err(DErr::Key));
        assert_eq!(verify_registration(&jwt(&p, json!({"alg": "ES256", "typ": "dbsc+jwt", "jwk": {"kty": "EC", "crv": "P-256", "x": "AA", "y": "AA"}}), json!({"jti": ch})), &ch, NOW), Err(DErr::Key));
        assert_eq!(verify_registration(&jwt(&p, json!({"alg": "ES256", "typ": "dbsc+jwt"}), json!({"jti": ch})), &ch, NOW), Err(DErr::Key));
        // tampered payload after signing
        let t = reg_jwt(&p, &ch); let parts: Vec<&str> = t.split('.').collect();
        let tam = format!("{}.{}.{}", parts[0], B64.encode(json!({"jti": ch, "iat": NOW + 1, "aud": "https://x/founder/v1/dbsc/start"}).to_string()), parts[2]);
        assert_eq!(verify_registration(&tam, &ch, NOW), Err(DErr::Signature));
        for bad in ["", "a.b", "a.b.c.d", &"x".repeat(5000)] { assert!(verify_registration(bad, &ch, NOW).is_err()); }
    }
    #[test]
    fn binding_is_reoffered_only_in_observe_to_a_keyless_bound_device() {
        assert!(offer_binding(Mode::Observe, false, false, false) && offer_binding(Mode::Observe, true, false, false) && !offer_binding(Mode::Observe, true, true, false));
        assert!(offer_binding(Mode::Enforce, false, false, false) && !offer_binding(Mode::Enforce, true, false, false) && !offer_binding(Mode::Off, false, false, false));
        assert!(!offer_binding(Mode::Observe, true, false, true), "a LIVE chip-bound device keeps its key: no re-offer, no fingerprint churn");
        assert!(offer_binding(Mode::Observe, true, false, chip_alive(true, Some(CHIP_DEAD_S + 1))), "a chip binding silent for 20 min is dead: it is offered a new registration");
        assert!(!offer_binding(Mode::Observe, true, false, chip_alive(true, Some(30))) && !offer_binding(Mode::Observe, true, false, chip_alive(true, None)));
        assert!(!offer_binding(Mode::Enforce, true, false, false), "enforce never re-offers");
        assert!(offer_binding(Mode::Observe, false, false, true), "an unbound device is still offered the binding");
    }

    #[test]
    fn refresh_uses_the_stored_key_only() {
        let (p, attacker) = (pair(), pair()); let k = subkey(b"m", "challenge");
        let ch = mint_challenge(&k, 'f', "SID1234567890123456", "", NOW).unwrap();
        assert_eq!(verify_refresh(&ref_jwt(&p, &ch), &ch, p.public_key().as_ref(), NOW), Ok(()));
        // the attacker signs with HIS key and even puts his jwk in the header: refused, the stored key decides
        let evil = jwt(&attacker, json!({"alg": "ES256", "typ": "dbsc+jwt", "jwk": jwk(&attacker)}), json!({"jti": ch, "iat": NOW}));
        assert_eq!(verify_refresh(&evil, &ch, p.public_key().as_ref(), NOW), Err(DErr::Signature));
        assert_eq!(verify_refresh(&ref_jwt(&p, "other"), &ch, p.public_key().as_ref(), NOW), Err(DErr::Jti));
        assert_eq!(verify_refresh(&ref_jwt(&p, &ch), &ch, &[4u8; 65], NOW), Err(DErr::Signature));
        assert_eq!(verify_refresh(&ref_jwt(&p, &ch), &ch, &[], NOW), Err(DErr::Signature));
    }
    #[test]
    fn exchange_decision_matrix() {
        use Decision::*;
        for m in [Mode::Off, Mode::Observe, Mode::Enforce] { assert_eq!(gate_exchange(m, None, None), Allow); assert_eq!(gate_exchange(m, None, Some("s")), Allow); } // unbound: never blocked
        assert_eq!(gate_exchange(Mode::Off, Some("s"), None), Allow);
        assert_eq!(gate_exchange(Mode::Observe, Some("s"), None), AllowWould("no_cookie"));
        assert_eq!(gate_exchange(Mode::Observe, Some("s"), Some("t")), AllowWould("wrong_session"));
        assert_eq!(gate_exchange(Mode::Enforce, Some("s"), None), Block("no_cookie"));
        assert_eq!(gate_exchange(Mode::Enforce, Some("s"), Some("t")), Block("wrong_session"));
        assert_eq!(gate_exchange(Mode::Enforce, Some("s"), Some("s")), Allow);
    }
    #[test]
    fn registration_header_shape() {
        let k = subkey(b"m", "challenge");
        let v = registration_header(&k, UID, &dev(), NOW).unwrap(); let s = v.to_str().unwrap().to_string();
        assert!(s.starts_with("(ES256); path=\"/founder/v1/dbsc/start\"; challenge=\"") && s.ends_with('"') && !s.contains("RS256"));
        let ch = s.split("challenge=\"").nth(1).unwrap().trim_end_matches('"');
        assert_eq!(check_challenge(&k, ch, 'r', NOW).unwrap().a, UID);
    }
    fn proof_jwt(p: &EcdsaKeyPair, with_jwk: bool, payload: Value) -> String {
        let mut h = json!({"alg": "ES256", "typ": "dbsc+jwt"}); if with_jwk { h["jwk"] = jwk(p); }
        jwt(p, h, payload)
    }
    #[test]
    fn k7b_proof_registers_and_then_proves_with_the_stored_key() {
        let p = pair(); let dh = dev();
        let reg = proof_jwt(&p, true, json!({"jti": "nonce-0123456789abcdef", "iat": NOW, "aud": "https://f.example.com/founder/v1/devicekey/register", "dh": dh}));
        let (jti, key) = verify_proof(&reg, DK_REG_PATH, None, &dh, NOW).unwrap();
        assert_eq!(jti, "nonce-0123456789abcdef"); assert_eq!(&key[..], p.public_key().as_ref());
        let ex = proof_jwt(&p, false, json!({"jti": "another-nonce-0123456789", "iat": NOW + 30, "aud": "https://f.example.com/founder/v1/exchange", "dh": dh}));
        assert!(verify_proof(&ex, EXCHANGE_PATH, Some(&key), &dh, NOW).is_ok());
    }
    #[test]
    fn k7b_proof_refuses_every_bad_shape() {
        let (p, evil) = (pair(), pair()); let dh = dev();
        let ok = json!({"jti": "nonce-0123456789abcdef", "iat": NOW, "aud": "https://f.example.com/founder/v1/exchange", "dh": dh});
        let key: [u8; 65] = p.public_key().as_ref().try_into().unwrap();
        assert_eq!(verify_proof(&proof_jwt(&evil, false, ok.clone()), EXCHANGE_PATH, Some(&key), &dh, NOW), Err(DErr::Signature)); // stolen login on another machine: no key
        assert_eq!(verify_proof(&proof_jwt(&evil, true, ok.clone()), EXCHANGE_PATH, Some(&key), &dh, NOW), Err(DErr::Signature)); // his own jwk is ignored when a key is stored
        assert_eq!(verify_proof(&proof_jwt(&p, false, json!({"jti": "nonce-0123456789abcdef", "iat": NOW - 300, "aud": "https://f/founder/v1/exchange", "dh": dh})), EXCHANGE_PATH, Some(&key), &dh, NOW), Err(DErr::Iat));
        assert_eq!(verify_proof(&proof_jwt(&p, false, json!({"jti": "nonce-0123456789abcdef", "aud": "https://f/founder/v1/exchange", "dh": dh})), EXCHANGE_PATH, Some(&key), &dh, NOW), Err(DErr::Iat));
        assert_eq!(verify_proof(&proof_jwt(&p, false, json!({"jti": "nonce-0123456789abcdef", "iat": NOW, "aud": "https://f/founder/v1/settings", "dh": dh})), EXCHANGE_PATH, Some(&key), &dh, NOW), Err(DErr::Aud)); // a proof for one route is not good for another
        assert_eq!(verify_proof(&proof_jwt(&p, false, json!({"jti": "nonce-0123456789abcdef", "iat": NOW, "aud": "http://f/founder/v1/exchange", "dh": dh})), EXCHANGE_PATH, Some(&key), &dh, NOW), Err(DErr::Aud));
        assert_eq!(verify_proof(&proof_jwt(&p, false, ok.clone()), EXCHANGE_PATH, Some(&key), &sha256_hex("another-device"), NOW), Err(DErr::Device)); // good for THIS device only
        assert_eq!(verify_proof(&proof_jwt(&p, false, json!({"jti": "short", "iat": NOW, "aud": "https://f/founder/v1/exchange", "dh": dh})), EXCHANGE_PATH, Some(&key), &dh, NOW), Err(DErr::Jti));
        assert_eq!(verify_proof(&proof_jwt(&p, false, ok.clone()), EXCHANGE_PATH, Some(&[4u8; 10]), &dh, NOW), Err(DErr::Key));
        assert_eq!(verify_proof(&proof_jwt(&p, false, ok.clone()), DK_REG_PATH, None, &dh, NOW), Err(DErr::Aud));      // registration needs the registration route
        assert_eq!(verify_proof(&jwt(&p, json!({"alg": "RS256", "typ": "dbsc+jwt"}), ok.clone()), EXCHANGE_PATH, Some(&key), &dh, NOW), Err(DErr::Alg));
        assert_eq!(verify_proof("junk", EXCHANGE_PATH, Some(&key), &dh, NOW), Err(DErr::Malformed));
    }
    #[test]
    fn small_validators() {
        assert!(sid_ok("abcdefghijklmnop") && !sid_ok("short") && !sid_ok("bad sid bad sid bad sid") && !sid_ok(&"a".repeat(65)));
        assert!(host_ok("founder.anexomail.com") && host_ok("localhost:8443") && !host_ok("") && !host_ok("a b") && !host_ok("EVIL.com/x"));
        assert!(uuid_like(UID).is_ok() && uuid_like("x").is_err() && uuid_like(&format!("{UID}; drop")).is_err());
        assert!(new_sid().is_some_and(|s| sid_ok(&s)));
    }
}
