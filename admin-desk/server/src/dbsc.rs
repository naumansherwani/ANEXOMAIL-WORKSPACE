// ANEXOMAIL ADMIN DESK dbsc.rs (R3a2-dbsc, 23 Nov 2026): DEVICE-BOUND SESSIONS for the Desk. Top list: docs/claude/admin-desk/DBSC-PHASE-LIST-23NOV.md (D1..D23).
// The DBSC protocol (W3C Editor's Draft 9 Nov 2026, Chrome origin trial): at login the browser creates an ES256 key in secure hardware, proves it on every refresh of a short-lived cookie.
// A stolen cookie or token is useless on another machine. Chromium only today (honest limit, said by the status door). DESK ISOLATION: own cookie, own challenge key, own tables (AD8); copied PATTERN of the
// founder design, nothing imported. Modes (env DESK_DBSC): off (default: routes 404, nothing emitted) / observe (register, refresh, ledger, would-block logged, never blocks) / enforce (only with his word).
use crate::{auth, door::{connect, lit, rows, token_of}};
use axum::{http::{header, HeaderMap, HeaderName, HeaderValue, StatusCode}, response::{IntoResponse, Response}};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD as B64, Engine};
use hmac::{Hmac, Mac};
use serde_json::{json, Value};
use sha2::Sha256;
use std::sync::OnceLock;
use subtle::ConstantTimeEq;

pub const BOUND_COOKIE: &str = "__Host-anx_ddbsc";
const HOST: &str = "admindesk.anexomail.com";
const START: &str = "/desk/v1/dbsc/start";
const REFRESH: &str = "/desk/v1/dbsc/refresh";
const CH_TTL: i64 = 60;
const COOKIE_TTL: i64 = 600;

#[derive(Clone, Copy, PartialEq, Debug)] pub enum Mode { Off, Observe, Enforce }
pub fn mode_of(s: Option<&str>) -> Mode { match s { Some("observe") => Mode::Observe, Some("enforce") => Mode::Enforce, _ => Mode::Off } }
pub fn mode() -> Mode { mode_of(std::env::var("DESK_DBSC").ok().as_deref()) }

fn hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
fn now() -> i64 { crate::signed::now_secs() }
// per-process random key for challenges, session ids and bound cookies; a restart only makes the browser refresh once more
fn key() -> &'static [u8; 32] {
    static K: OnceLock<[u8; 32]> = OnceLock::new();
    K.get_or_init(|| { use argon2::password_hash::rand_core::{OsRng, RngCore}; let mut k = [0u8; 32]; OsRng.fill_bytes(&mut k); k })
}
fn mac_hex(msg: &str) -> String { let mut m = <Hmac<Sha256> as Mac>::new_from_slice(key()).expect("hmac key"); m.update(msg.as_bytes()); hex(&m.finalize().into_bytes()) }
fn eq(a: &str, b: &str) -> bool { a.len() == b.len() && a.as_bytes().ct_eq(b.as_bytes()).into() }

// ---- D2: signed one-use challenge, 60 s, bound to the session token hash and to the step (registration "r" / refresh "f") ----
pub fn make_challenge(step: &str, th: &[u8; 32], now: i64) -> String {
    use argon2::password_hash::rand_core::{OsRng, RngCore};
    let mut n = [0u8; 8]; OsRng.fill_bytes(&mut n);
    let body = format!("{step}.{}.{}.{}", now + CH_TTL, hex(&th[..8]), hex(&n));
    format!("{body}.{}", &mac_hex(&format!("anexo-desk-dbsc-v1|{body}"))[..32])
}
pub fn check_challenge(c: &str, step: &str, th: &[u8; 32], now: i64) -> bool {
    if c.len() > 120 || !c.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'.') { return false; }
    let p: Vec<&str> = c.split('.').collect();
    if p.len() != 5 || p[0] != step { return false; }
    let Ok(exp) = p[1].parse::<i64>() else { return false };
    if exp < now || exp - now > CH_TTL || p[2] != hex(&th[..8]) { return false; }
    eq(p[4], &mac_hex(&format!("anexo-desk-dbsc-v1|{}.{}.{}.{}", p[0], p[1], p[2], p[3]))[..32])
}
pub fn session_id(th: &[u8; 32]) -> String { mac_hex(&format!("sid|{}", hex(th)))[..32].to_string() }

// ---- D4: the short-lived bound cookie, stateless (exp + MAC over the token hash) ----
pub fn bound_cookie_value(th: &[u8; 32], now: i64) -> String { let exp = now + COOKIE_TTL; format!("1.{exp}.{}", &mac_hex(&format!("cookie|{}|{exp}", hex(th)))[..32]) }
fn set_bound_cookie(th: &[u8; 32], now: i64, max_age: i64) -> HeaderValue {
    let v = if max_age == 0 { String::new() } else { bound_cookie_value(th, now) };
    HeaderValue::from_str(&format!("{BOUND_COOKIE}={v}; Secure; HttpOnly; SameSite=Strict; Path=/; Max-Age={max_age}")).unwrap()
}
pub fn bound_cookie_ok(h: &HeaderMap, th: &[u8; 32], now: i64) -> bool {
    let Some(raw) = h.get(header::COOKIE).and_then(|v| v.to_str().ok()) else { return false };
    let Some(v) = raw.split(';').filter_map(|p| p.trim().split_once('=')).find(|(k, _)| *k == BOUND_COOKIE).map(|(_, v)| v) else { return false };
    let p: Vec<&str> = v.split('.').collect();
    if p.len() != 3 || p[0] != "1" { return false; }
    let Ok(exp) = p[1].parse::<i64>() else { return false };
    exp >= now && eq(p[2], &mac_hex(&format!("cookie|{}|{exp}", hex(th)))[..32])
}

// ---- D3 / D5 / D19: the proof JWT. ES256 ONLY (RS256 and none are refused on purpose) ----
pub struct Jwt { header: Value, payload: Value, signing: Vec<u8>, sig: Vec<u8> }
pub fn parse_jwt(s: &str) -> Option<Jwt> {
    if s.len() > 4096 { return None; }
    let p: Vec<&str> = s.split('.').collect(); if p.len() != 3 { return None; }
    let j = |x: &str| B64.decode(x).ok().and_then(|b| serde_json::from_slice::<Value>(&b).ok());
    Some(Jwt { header: j(p[0])?, payload: j(p[1])?, signing: format!("{}.{}", p[0], p[1]).into_bytes(), sig: B64.decode(p[2]).ok()? })
}
fn sf_string(h: &HeaderMap, name: &str) -> Option<String> { h.get(name).and_then(|v| v.to_str().ok()).map(|v| v.trim().trim_matches('"').to_string()).filter(|v| !v.is_empty()) }
/// An EC P-256 public JWK as the 65-byte uncompressed point ring wants; only kty/crv/x/y survive.
pub fn jwk_point(jwk: &Value) -> Option<Vec<u8>> {
    if jwk["kty"] != "EC" || jwk["crv"] != "P-256" { return None; }
    let (x, y) = (B64.decode(jwk["x"].as_str()?).ok()?, B64.decode(jwk["y"].as_str()?).ok()?);
    if x.len() != 32 || y.len() != 32 { return None; }
    let mut p = vec![4u8]; p.extend(x); p.extend(y); Some(p)
}
fn jwk_clean(jwk: &Value) -> Value { json!({"kty": "EC", "crv": "P-256", "x": jwk["x"], "y": jwk["y"]}) }
fn verify_es256(point: &[u8], j: &Jwt) -> bool {
    ring::signature::UnparsedPublicKey::new(&ring::signature::ECDSA_P256_SHA256_FIXED, point).verify(&j.signing, &j.sig).is_ok()
}
fn header_ok(j: &Jwt) -> bool { j.header["typ"] == "dbsc+jwt" && j.header["alg"] == "ES256" }

// ---- the two protocol steps, written against a database client so tests run on a real PostgreSQL ----
#[derive(Debug, PartialEq)] pub enum Fail { Refused(&'static str), Db }
pub struct Done { pub config: Value, pub cookie: HeaderValue, pub next_challenge: String, pub sid: String }
fn thex(th: &[u8; 32]) -> String { format!("'\\x{}'::bytea", hex(th)) }
async fn q(c: &tokio_postgres::Client, sql: &str) -> Result<Option<String>, Fail> { rows(c, sql).await.map_err(|_| Fail::Db).map(|v| v.first().and_then(|r| r.get(0)).map(str::to_string)) }
async fn refuse(c: &tokio_postgres::Client, th: &[u8; 32], why: &str, step: &str) { let _ = q(c, &format!("select desk.fadm_dbsc_refuse({}, {}, {})::text", thex(th), lit(why), lit(step))).await; }
pub fn config(sid: &str) -> Value {
    let ex = |p: &str| json!({"type": "exclude", "domain": HOST, "path": p});
    json!({"session_identifier": sid, "refresh_url": REFRESH,
           "scope": {"origin": format!("https://{HOST}"), "include_site": false, "scope_specification": [ex("/desk/v1/dbsc/"), ex("/desk/v1/health"), ex("/desk/v1/key")]},
           "credentials": [{"type": "cookie", "name": BOUND_COOKIE, "attributes": "Secure; HttpOnly; SameSite=Strict; Path=/"}],
           "allowed_refresh_initiators": []})
}
pub async fn start_core(c: &tokio_postgres::Client, th: &[u8; 32], proof: &str, now: i64) -> Result<Done, Fail> {
    let Some(j) = parse_jwt(proof) else { return Err(Fail::Refused("bad_proof")) };
    if !header_ok(&j) { refuse(c, th, "bad_header", "register").await; return Err(Fail::Refused("bad_header")); }
    let Some(point) = jwk_point(&j.header["jwk"]) else { refuse(c, th, "bad_key", "register").await; return Err(Fail::Refused("bad_key")) };
    let jti = j.payload["jti"].as_str().unwrap_or("");
    if !check_challenge(jti, "r", th, now) { refuse(c, th, "bad_challenge", "register").await; return Err(Fail::Refused("bad_challenge")); }
    if !verify_es256(&point, &j) { refuse(c, th, "bad_signature", "register").await; return Err(Fail::Refused("bad_signature")); }
    let key = jwk_clean(&j.header["jwk"]);
    match q(c, &format!("select desk.fadm_dbsc_register({}, {}::jsonb, {})::text", thex(th), lit(&key.to_string()), lit(jti))).await? {
        Some(t) if t == "true" => { let sid = session_id(th); Ok(Done { config: config(&sid), cookie: set_bound_cookie(th, now, COOKIE_TTL), next_challenge: make_challenge("f", th, now), sid }) }
        _ => Err(Fail::Refused("refused")),
    }
}
/// Ok(Some) = proof accepted. Ok(None) = no proof sent yet: the caller answers 403 + a fresh challenge. Err = refused / database.
pub async fn refresh_core(c: &tokio_postgres::Client, th: &[u8; 32], proof: Option<&str>, now: i64) -> Result<Option<Done>, Fail> {
    let Some(stored) = q(c, &format!("select desk.fadm_dbsc_key({})::text", thex(th))).await? else { return Err(Fail::Refused("not_bound")) };
    let Some(stored) = serde_json::from_str::<Value>(&stored).ok().and_then(|v| jwk_point(&v)) else { return Err(Fail::Refused("not_bound")) };
    let Some(proof) = proof else { return Ok(None) };
    let Some(j) = parse_jwt(proof) else { return Err(Fail::Refused("bad_proof")) };
    if !header_ok(&j) || !j.header["jwk"].is_null() { refuse(c, th, "bad_header", "refresh").await; return Err(Fail::Refused("bad_header")); }   // a key inside a refresh proof is never used
    let jti = j.payload["jti"].as_str().unwrap_or("");
    if !check_challenge(jti, "f", th, now) { refuse(c, th, "bad_challenge", "refresh").await; return Ok(None); }                                   // stale or foreign challenge: ask again
    if !verify_es256(&stored, &j) { refuse(c, th, "bad_signature", "refresh").await; return Err(Fail::Refused("bad_signature")); }              // verified against the STORED key only
    match q(c, &format!("select desk.fadm_dbsc_refresh({}, {})::text", thex(th), lit(jti))).await? {
        Some(t) if t == "true" => { let sid = session_id(th); Ok(Some(Done { config: config(&sid), cookie: set_bound_cookie(th, now, COOKIE_TTL), next_challenge: make_challenge("f", th, now), sid })) }
        _ => Ok(None),   // replayed proof id: a fresh challenge, never a cookie
    }
}

// ---- D1: the registration header the login answers with ----
pub fn registration_value(mode: Mode, th: &[u8; 32], now: i64) -> Option<String> {
    if mode == Mode::Off { return None; }
    Some(format!("(ES256); path=\"{START}\"; challenge=\"{}\"", make_challenge("r", th, now)))
}
pub fn registration_header(th: &[u8; 32]) -> Option<(HeaderName, HeaderValue)> {
    registration_value(mode(), th, now()).and_then(|v| HeaderValue::from_str(&v).ok()).map(|v| (HeaderName::from_static("secure-session-registration"), v))
}

// ---- HTTP wrappers (D14 D15 D16 D17 D20) ----
fn reply(status: StatusCode, body: Value) -> Response {
    let mut r = (status, [(header::CONTENT_TYPE, "application/json")], body.to_string()).into_response();
    r.headers_mut().insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store")); r
}
fn challenge_header(r: &mut Response, c: &str, sid: &str) { if let Ok(v) = HeaderValue::from_str(&format!("\"{c}\";id=\"{sid}\"")) { r.headers_mut().insert(HeaderName::from_static("secure-session-challenge"), v); } }
fn th_of(h: &HeaderMap) -> Option<[u8; 32]> { token_of(h).map(|t| auth::token_hash(&t)) }
fn done_reply(d: Done) -> Response { let mut r = reply(StatusCode::OK, d.config); r.headers_mut().insert(header::SET_COOKIE, d.cookie); challenge_header(&mut r, &d.next_challenge, &d.sid); r }
fn fail_reply(f: Fail) -> Response { match f { Fail::Db => reply(StatusCode::SERVICE_UNAVAILABLE, json!({"error": "db_unavailable"})), Fail::Refused(w) => reply(StatusCode::FORBIDDEN, json!({"error": w})) } }

pub async fn start(h: HeaderMap) -> Response {
    if mode() == Mode::Off { return StatusCode::NOT_FOUND.into_response(); }
    let Some(th) = th_of(&h) else { return reply(StatusCode::UNAUTHORIZED, json!({"error": "no_session"})) };
    let Some(proof) = sf_string(&h, "secure-session-response") else { return reply(StatusCode::BAD_REQUEST, json!({"error": "no_proof"})) };
    let Ok(c) = connect().await else { return fail_reply(Fail::Db) };
    match start_core(&c, &th, &proof, now()).await { Ok(d) => done_reply(d), Err(f) => fail_reply(f) }
}
pub async fn refresh(h: HeaderMap) -> Response {
    if mode() == Mode::Off { return StatusCode::NOT_FOUND.into_response(); }
    let Some(th) = th_of(&h) else { return reply(StatusCode::UNAUTHORIZED, json!({"error": "no_session"})) };
    let sid = session_id(&th);
    if sf_string(&h, "sec-secure-session-id").as_deref() != Some(sid.as_str()) { return reply(StatusCode::FORBIDDEN, json!({"error": "session_id"})); }   // D14
    let Ok(c) = connect().await else { return fail_reply(Fail::Db) };
    if let Some(sk) = sf_string(&h, "secure-session-skipped") {   // D16: why the browser skipped a refresh
        for r in ["unreachable", "server_error", "quota_exceeded"] { if sk.contains(r) { refuse(&c, &th, &format!("skipped_{r}"), "refresh").await; } }
    }
    let proof = sf_string(&h, "secure-session-response");
    match refresh_core(&c, &th, proof.as_deref(), now()).await {
        Ok(Some(d)) => done_reply(d),
        Ok(None) => { let mut r = reply(StatusCode::FORBIDDEN, json!({"error": "challenge"})); challenge_header(&mut r, &make_challenge("f", &th, now()), &sid); r }
        Err(Fail::Refused("not_bound")) => reply(StatusCode::OK, json!({"continue": false})),   // D17: nothing bound (or revoked): the browser ends its side cleanly
        Err(f) => fail_reply(f),
    }
}
/// GET /desk/v1/dbsc/status (sealed door): honest facts, never a claim DBSC works where it does not.
pub async fn status(h: HeaderMap) -> Response {
    let Some(th) = th_of(&h) else { return reply(StatusCode::UNAUTHORIZED, json!({"error": "no_session"})) };
    let Ok(c) = connect().await else { return fail_reply(Fail::Db) };
    let r = rows(&c, &format!("select bound::text, registered_at::text, last_refresh_at::text from desk.fadm_dbsc_status({})", thex(&th))).await;
    let Ok(v) = r else { return fail_reply(Fail::Db) };
    let row = v.first();
    reply(StatusCode::OK, json!({"mode": format!("{:?}", mode()).to_lowercase(), "bound": row.and_then(|r| r.get(0)) == Some("true"), "registered_at": row.and_then(|r| r.get(1)), "last_refresh_at": row.and_then(|r| r.get(2)),
        "fallback": "long_lived_token", "browser_support": "chromium_with_secure_key_storage_only"}))
}
/// D6 / D21: called by every door that knows the session. off = true; observe = true (would-block logged); enforce = a BOUND session needs a valid bound cookie; unbound sessions are never blocked.
pub async fn enforce_ok(h: &HeaderMap, th: &[u8; 32]) -> bool {
    let m = mode(); if m == Mode::Off { return true; }
    let Ok(c) = connect().await else { return m != Mode::Enforce };
    let bound = rows(&c, &format!("select bound::text from desk.fadm_dbsc_status({})", thex(th))).await.ok().and_then(|v| v.first().and_then(|r| r.get(0)).map(|x| x == "true")).unwrap_or(false);
    if !bound { return true; }
    let ok = bound_cookie_ok(h, th, now());
    if !ok { eprintln!("desk dbsc: bound session without a valid bound cookie ({})", if m == Mode::Enforce { "BLOCKED" } else { "would block" }); refuse(&c, th, "no_cookie", "enforce").await; }
    ok || m != Mode::Enforce
}

#[cfg(test)]
mod tests {
    use super::*;
    use ring::{rand::SystemRandom, signature::{EcdsaKeyPair, KeyPair, ECDSA_P256_SHA256_FIXED_SIGNING}};
    const TH: [u8; 32] = [7u8; 32];
    fn pair() -> EcdsaKeyPair { let rng = SystemRandom::new(); let pk = EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, &rng).unwrap(); EcdsaKeyPair::from_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, pk.as_ref(), &rng).unwrap() }
    fn jwk(k: &EcdsaKeyPair) -> Value { let p = k.public_key().as_ref(); json!({"kty": "EC", "crv": "P-256", "x": B64.encode(&p[1..33]), "y": B64.encode(&p[33..65])}) }
    fn jwt(k: &EcdsaKeyPair, header: Value, payload: Value) -> String {
        let s = format!("{}.{}", B64.encode(header.to_string()), B64.encode(payload.to_string()));
        format!("{s}.{}", B64.encode(k.sign(&SystemRandom::new(), s.as_bytes()).unwrap().as_ref()))
    }
    fn reg(k: &EcdsaKeyPair, jti: &str) -> String { jwt(k, json!({"typ": "dbsc+jwt", "alg": "ES256", "jwk": jwk(k)}), json!({"jti": jti})) }
    fn refp(k: &EcdsaKeyPair, jti: &str) -> String { jwt(k, json!({"typ": "dbsc+jwt", "alg": "ES256"}), json!({"jti": jti})) }
    #[test] fn challenge_is_bound_signed_short_lived_and_step_specific() {
        let c = make_challenge("r", &TH, 1000);
        assert!(check_challenge(&c, "r", &TH, 1000) && check_challenge(&c, "r", &TH, 1060));
        assert!(!check_challenge(&c, "r", &TH, 1061), "expired");
        assert!(!check_challenge(&c, "f", &TH, 1000), "wrong step");
        assert!(!check_challenge(&c, "r", &[8u8; 32], 1000), "another session");
        let mut t = c.clone(); t.replace_range(t.len() - 1.., if c.ends_with('a') { "b" } else { "a" }); assert!(!check_challenge(&t, "r", &TH, 1000), "tampered mac");
        assert!(!check_challenge(&c.replace("r.", "r.9"), "r", &TH, 1000), "tampered expiry");
        assert!(!check_challenge("", "r", &TH, 1000) && !check_challenge("A.b.c.d.e", "r", &TH, 1000));
    }
    #[test] fn bound_cookie_is_signed_and_expires() {
        let v = bound_cookie_value(&TH, 1000); let mut h = HeaderMap::new(); h.insert(header::COOKIE, HeaderValue::from_str(&format!("x=1; {BOUND_COOKIE}={v}")).unwrap());
        assert!(bound_cookie_ok(&h, &TH, 1000) && bound_cookie_ok(&h, &TH, 1600)); assert!(!bound_cookie_ok(&h, &TH, 1601), "expired"); assert!(!bound_cookie_ok(&h, &[9u8; 32], 1000), "another session");
        let mut bad = HeaderMap::new(); bad.insert(header::COOKIE, HeaderValue::from_str(&format!("{BOUND_COOKIE}=1.9999999999.{}", "a".repeat(32))).unwrap()); assert!(!bound_cookie_ok(&bad, &TH, 1000), "forged");
        assert!(!bound_cookie_ok(&HeaderMap::new(), &TH, 1000));
        let c = set_bound_cookie(&TH, 1000, 600); let s = c.to_str().unwrap(); assert!(s.starts_with("__Host-") && s.contains("Secure") && s.contains("HttpOnly") && s.contains("SameSite=Strict") && s.contains("Path=/") && !s.contains("Domain"));
    }
    #[test] fn es256_only_and_the_stored_key_decides() {
        let (a, b) = (pair(), pair()); let j = parse_jwt(&reg(&a, "x")).unwrap(); assert!(header_ok(&j)); assert!(verify_es256(&jwk_point(&j.header["jwk"]).unwrap(), &j));
        assert!(!verify_es256(&jwk_point(&jwk(&b)).unwrap(), &j), "another key");
        for (alg, typ) in [("none", "dbsc+jwt"), ("HS256", "dbsc+jwt"), ("RS256", "dbsc+jwt"), ("ES256", "JWT")] { let bad = parse_jwt(&jwt(&a, json!({"typ": typ, "alg": alg}), json!({"jti": "x"}))).unwrap(); assert!(!header_ok(&bad), "{alg} {typ}"); }
        let s = reg(&a, "x"); let mut p: Vec<&str> = s.split('.').collect(); let np = B64.encode(json!({"jti": "evil"}).to_string()); p[1] = &np; let t = parse_jwt(&p.join(".")).unwrap(); assert!(!verify_es256(&jwk_point(&jwk(&a)).unwrap(), &t), "tampered payload");
        assert!(jwk_point(&json!({"kty": "RSA"})).is_none() && jwk_point(&json!({"kty": "EC", "crv": "P-384", "x": "a", "y": "b"})).is_none() && jwk_point(&json!({"kty": "EC", "crv": "P-256", "x": "AA", "y": "AA"})).is_none());
        assert!(parse_jwt("a.b").is_none() && parse_jwt(&"a".repeat(5000)).is_none() && parse_jwt("!!.!!.!!").is_none());
    }
    #[test] fn registration_header_only_when_the_mode_is_on_and_es256_only() {
        assert!(registration_value(Mode::Off, &TH, 1000).is_none());
        for m in [Mode::Observe, Mode::Enforce] { let v = registration_value(m, &TH, 1000).unwrap(); assert!(v.starts_with("(ES256);") && !v.contains("RS256") && v.contains(START) && v.contains("challenge=\"r.")); }
        assert_eq!((mode_of(None), mode_of(Some("observe")), mode_of(Some("enforce")), mode_of(Some("on"))), (Mode::Off, Mode::Observe, Mode::Enforce, Mode::Off));
    }
    #[test] fn config_is_site_closed_no_key_sharing_and_hides_public_paths() {
        let c = config("sid"); assert_eq!(c["scope"]["include_site"], false); assert_eq!(c["allowed_refresh_initiators"], json!([])); assert_eq!(c["credentials"][0]["name"], BOUND_COOKIE);
        let t = c.to_string(); for no in ["provider_key", "provider_session_id", "provider_url"] { assert!(!t.contains(no), "{no}"); }
        for p in ["/desk/v1/dbsc/", "/desk/v1/health", "/desk/v1/key"] { assert!(t.contains(p), "{p} excluded"); }
        assert_eq!(session_id(&TH).len(), 32); assert_ne!(session_id(&TH), session_id(&[8u8; 32]));
    }
    // ---- real PostgreSQL (scratch db with AD1..AD8): the whole protocol through the database doors ----
    async fn pg() -> Option<tokio_postgres::Client> {
        let url = std::env::var("DESK_TEST_ADMIN_URL").ok()?;
        let (c, conn) = tokio_postgres::connect(&url, tokio_postgres::NoTls).await.ok()?; tokio::spawn(conn);
        let _ = c.simple_query("create temporary table if not exists _x(i int)").await; Some(c)
    }
    #[tokio::test] async fn full_protocol_on_real_postgres() {
        let Some(c) = pg().await else { eprintln!("no DESK_TEST_ADMIN_URL: skipped"); return };
        let th = { let mut t = [0u8; 32]; use argon2::password_hash::rand_core::{OsRng, RngCore}; OsRng.fill_bytes(&mut t); t };
        rows(&c, &format!("insert into desk.fadm_session (owner_id, token_hash, expires_at) select id, '\\x{}', now() + interval '1 hour' from desk.fadm_owner where active limit 1", hex(&th))).await.unwrap();
        let (k, other) = (pair(), pair()); let now = crate::signed::now_secs();
        // registration: a bad challenge, a foreign key signature, a wrong header all refuse
        let rc = make_challenge("r", &th, now);
        assert_eq!(start_core(&c, &th, &reg(&k, "nope"), now).await.err(), Some(Fail::Refused("bad_challenge")));
        let forged = jwt(&other, json!({"typ": "dbsc+jwt", "alg": "ES256", "jwk": jwk(&k)}), json!({"jti": rc})); assert_eq!(start_core(&c, &th, &forged, now).await.err(), Some(Fail::Refused("bad_signature")));
        assert_eq!(start_core(&c, &th, &jwt(&k, json!({"typ": "dbsc+jwt", "alg": "none"}), json!({"jti": rc})), now).await.err(), Some(Fail::Refused("bad_header")));
        // refresh before binding: not bound
        assert_eq!(refresh_core(&c, &th, None, now).await.err(), Some(Fail::Refused("not_bound")));
        let d = start_core(&c, &th, &reg(&k, &rc), now).await.unwrap(); assert_eq!(d.config["session_identifier"], session_id(&th)); assert!(d.cookie.to_str().unwrap().contains(BOUND_COOKIE));
        // the same registration proof again: replay refused, and a second key cannot re-bind
        assert!(start_core(&c, &th, &reg(&k, &rc), now).await.is_err());
        let rc2 = make_challenge("r", &th, now); assert!(start_core(&c, &th, &reg(&other, &rc2), now).await.is_err(), "already bound: first key wins");
        // refresh: no proof = ask for one; wrong key refused; right key accepted once; replay gets a new challenge
        assert!(refresh_core(&c, &th, None, now).await.unwrap().is_none());
        let fc = d.next_challenge.clone();
        assert_eq!(refresh_core(&c, &th, Some(&refp(&other, &fc)), now).await.err(), Some(Fail::Refused("bad_signature")));
        assert_eq!(refresh_core(&c, &th, Some(&jwt(&k, json!({"typ": "dbsc+jwt", "alg": "ES256", "jwk": jwk(&other)}), json!({"jti": fc}))), now).await.err(), Some(Fail::Refused("bad_header")), "a key inside a refresh proof is never used");
        let d2 = refresh_core(&c, &th, Some(&refp(&k, &fc)), now).await.unwrap().expect("accepted"); assert!(d2.cookie.to_str().unwrap().contains(BOUND_COOKIE));
        assert!(refresh_core(&c, &th, Some(&refp(&k, &fc)), now).await.unwrap().is_none(), "replayed proof id gets no cookie");
        assert!(refresh_core(&c, &th, Some(&refp(&k, &make_challenge("r", &th, now))), now).await.unwrap().is_none(), "a registration challenge is no refresh challenge");
        let st = rows(&c, &format!("select bound::text from desk.fadm_dbsc_status({})", thex(&th))).await.unwrap(); assert_eq!(st[0].get(0), Some("true"));
        assert_eq!(q(&c, "select desk.fadm_ledger_verify()::text").await.unwrap().as_deref(), Some("true"), "hash chain intact");
        rows(&c, &format!("update desk.fadm_session set revoked_at = now() where token_hash = '\\x{}'", hex(&th))).await.unwrap();
        assert_eq!(refresh_core(&c, &th, None, now).await.err(), Some(Fail::Refused("not_bound")), "a revoked session ends the binding");
    }
}
