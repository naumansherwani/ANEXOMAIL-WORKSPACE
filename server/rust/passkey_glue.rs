// ============================================================================
// passkey_glue.rs — I/O half of passkey + recovery-code LOGIN on Rust (B2, founder 21 Oct 2026). Bun /api/auth/passkey/* = fallback.
//
// PUBLIC (no bearer — these ARE the login):
//   auth.passkey.options     {email}                       -> WebAuthn request options (challenge stored, 5 min)
//   auth.passkey.verify      {id, response{…}}             -> verifies the assertion, mints a real Supabase session
//   auth.recovery.redeem     {email, code}                 -> recovery_code_redeem (SQL E43) -> real session
// AUTHENTICATED:
//   auth.passkey.register.options / register.verify        -> enrol a passkey (first one also returns 10 recovery codes)
//   auth.passkey.status                                    -> gate/banner status (test accounts exempt)
//   auth.recovery.generate                                 -> new recovery codes
//   auth.passkey.list / auth.passkey.delete {id}           -> your devices (Account page); delete re-opens the passkey gate at 0
//
// Sessions: Supabase GoTrue admin generate_link + verify (same as the Bun code), so the browser gets a normal access token +
// refresh token (B1) and the revocation path (auth.sessions / account_sessions) is the SAME as every other login.
// Answers carry {token, refresh_token, expires_at}; the browser then reads /api/auth/session (Brain) for the profile payload.
//
// Loopholes closed vs Bun: challenge is CONSUMED (atomic DELETE … RETURNING) before the signature is checked, so a captured
// assertion can never be replayed; challenge/credential ids are shape-checked before reaching a filter; challenge user must match
// the credential owner; per-IP rate limit on the public procs; cose curve/length checks; CBOR depth limit.
// Child module of the crate root: uses `auth_user`, `sb`, `sb_rpc`, `sb_select`, `http`, `env_var`, `ok`, `err`. Dependencies:
// sha2 / base64 / ring are already in Cargo.toml (jwt installer added ring). Adds NO new crate.
// ============================================================================

use crate::passkey_core as pc;
use axum::{
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
};
use ring::signature::{self, UnparsedPublicKey};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

type Resp = axum::response::Response;

pub fn public_owns(proc: &str) -> bool {
    matches!(proc, "auth.passkey.options" | "auth.passkey.verify" | "auth.recovery.redeem")
}

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "auth.passkey.register.options"
            | "auth.passkey.register.verify"
            | "auth.passkey.status"
            | "auth.recovery.generate"
            | "auth.passkey.list"
            | "auth.passkey.delete"
    )
}

fn fail(status: StatusCode, code: &str) -> Resp {
    crate::err(status, code, code).into_response()
}
fn bad(code: &str) -> Resp {
    fail(StatusCode::BAD_REQUEST, code)
}
fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}
fn now_secs() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}
fn hdr(h: &HeaderMap, k: &str) -> String {
    h.get(k).and_then(|v| v.to_str().ok()).unwrap_or("").to_string()
}
fn app_url() -> String {
    let v = crate::env_var("APP_URL");
    if v.is_empty() { "https://anexomail.com".into() } else { v }
}
fn rp_of(h: &HeaderMap) -> Result<pc::Rp, &'static str> {
    let o = hdr(h, "origin");
    pc::rp_from_origin(if o.is_empty() { None } else { Some(&o) }, &app_url())
}
fn is_uuid(s: &str) -> bool {
    s.len() == 36 && s.bytes().all(|c| c.is_ascii_hexdigit() || c == b'-')
}
fn sha256(b: &[u8]) -> [u8; 32] {
    let mut o = [0u8; 32];
    o.copy_from_slice(&Sha256::digest(b));
    o
}
fn random_challenge() -> Result<String, String> {
    use ring::rand::{SecureRandom, SystemRandom};
    let mut b = [0u8; 32];
    SystemRandom::new().fill(&mut b).map_err(|_| "rng_failed".to_string())?;
    Ok(pc::b64url_encode(&b))
}

// ── tiny per-IP limiter (public procs are the front door; slow guessing + challenge spam) ──────────────────────────────
fn allow(ip: &str, bucket: &str, max: u32, window_secs: u64) -> bool {
    static L: OnceLock<Mutex<HashMap<String, (Instant, u32)>>> = OnceLock::new();
    let m = L.get_or_init(|| Mutex::new(HashMap::new()));
    let Ok(mut g) = m.lock() else { return true };
    if g.len() > 5000 {
        g.retain(|_, (t, _)| t.elapsed().as_secs() < window_secs);
    }
    let e = g.entry(format!("{bucket}|{ip}")).or_insert((Instant::now(), 0));
    if e.0.elapsed().as_secs() >= window_secs {
        *e = (Instant::now(), 0);
    }
    e.1 += 1;
    e.1 <= max
}

// ── PostgREST helpers (service role) ────────────────────────────────────────
async fn pg_delete(path_and_query: &str) -> Result<Value, String> {
    let (url, key) = crate::sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let res = crate::http()
        .delete(format!("{url}/rest/v1/{path_and_query}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .header("prefer", "return=representation")
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = res.status();
    let payload: Value = res.json().await.unwrap_or(Value::Null);
    if !status.is_success() {
        return Err(payload.to_string());
    }
    Ok(payload)
}

fn first_row(v: &Value) -> Option<&Value> {
    v.as_array().and_then(|a| a.first())
}

// ── GoTrue: mint a real session for an email (same two calls the Bun code makes) ────────────────────────────────────────
struct Minted {
    access: String,
    refresh: String,
    expires_at: i64,
    user_id: String,
}

async fn gotrue_post(path: &str, body: Value) -> Result<(StatusCode, Value), String> {
    let (url, key) = crate::sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let res = crate::http()
        .post(format!("{url}/auth/v1/{path}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .header("content-type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = res.status();
    let payload: Value = res.json().await.unwrap_or(Value::Null);
    Ok((status, payload))
}

async fn mint_session(email: &str) -> Result<Minted, String> {
    let (s, link) = gotrue_post("admin/generate_link", json!({ "type": "magiclink", "email": email })).await?;
    if !s.is_success() {
        return Err("passkey_session_failed".into());
    }
    let hashed = link
        .get("hashed_token")
        .or_else(|| link.get("properties").and_then(|p| p.get("hashed_token")))
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if hashed.is_empty() {
        return Err("passkey_session_failed".into());
    }
    for typ in ["magiclink", "email"] {
        let (vs, sess) = gotrue_post("verify", json!({ "type": typ, "token_hash": hashed })).await?;
        let access = st(&sess, "access_token");
        if vs.is_success() && !access.is_empty() {
            return Ok(Minted {
                access,
                refresh: st(&sess, "refresh_token"),
                expires_at: sess.get("expires_at").and_then(|x| x.as_i64()).unwrap_or_else(|| now_secs() as i64 + 3600),
                user_id: sess.get("user").and_then(|u| u.get("id")).and_then(|x| x.as_str()).unwrap_or("").to_string(),
            });
        }
        // a magic-link hash is single-use: if the first type consumed it and failed, generate a fresh one for the retry
        if typ == "magiclink" {
            let (s2, l2) = gotrue_post("admin/generate_link", json!({ "type": "magiclink", "email": email })).await?;
            if !s2.is_success() {
                return Err("passkey_session_failed".into());
            }
            let h2 = l2
                .get("hashed_token")
                .or_else(|| l2.get("properties").and_then(|p| p.get("hashed_token")))
                .and_then(|x| x.as_str())
                .unwrap_or("")
                .to_string();
            if h2.is_empty() {
                return Err("passkey_session_failed".into());
            }
            let (vs2, sess2) = gotrue_post("verify", json!({ "type": "email", "token_hash": h2 })).await?;
            let access2 = st(&sess2, "access_token");
            if vs2.is_success() && !access2.is_empty() {
                return Ok(Minted {
                    access: access2,
                    refresh: st(&sess2, "refresh_token"),
                    expires_at: sess2.get("expires_at").and_then(|x| x.as_i64()).unwrap_or_else(|| now_secs() as i64 + 3600),
                    user_id: sess2.get("user").and_then(|u| u.get("id")).and_then(|x| x.as_str()).unwrap_or("").to_string(),
                });
            }
            break;
        }
    }
    Err("passkey_session_failed".into())
}

/// Same row the Bun `saveSession` writes (Security page lists these; logout / device revoke flip revoked_at).
async fn save_session(m: &Minted, headers: &HeaderMap) {
    let ua = hdr(headers, "user-agent");
    let ua: String = ua.chars().take(300).collect();
    if m.user_id.is_empty() || pc::is_server_ua(&ua) {
        return;
    }
    let (browser, device) = pc::describe_ua(&ua);
    let ip = pc::client_ip(&hdr(headers, "x-forwarded-for"), &hdr(headers, "x-real-ip"));
    let token_hash: String = Sha256::digest(m.access.as_bytes()).iter().map(|b| format!("{b:02x}")).collect();
    let _ = crate::sb_upsert(
        "account_sessions",
        "token_hash",
        json!({
            "user_id": m.user_id, "token_hash": token_hash, "device": device, "browser": browser,
            "ip": ip, "last_seen_at": pc::iso_utc(now_secs()), "revoked_at": Value::Null
        }),
    )
    .await;
}

fn session_json(m: &Minted) -> Value {
    json!({ "token": m.access, "refresh_token": m.refresh, "expires_at": m.expires_at, "needs_session": true })
}

// ── credential payload (flat WebAuthn JSON, or nested under `response`) ─────────────────────────────────────────────
struct Cred {
    id: String,
    client_data: String,
    attestation: String,
    auth_data: String,
    signature: String,
}
fn cred_of(input: &Value) -> Cred {
    let r = input.get("response").unwrap_or(input);
    let id = input.get("id").or_else(|| input.get("rawId")).and_then(|x| x.as_str()).unwrap_or("").to_string();
    Cred {
        id,
        client_data: st(r, "clientDataJSON"),
        attestation: st(r, "attestationObject"),
        auth_data: st(r, "authenticatorData"),
        signature: st(r, "signature"),
    }
}

struct ClientData {
    typ: String,
    challenge: String,
    origin: String,
}
fn parse_client_data(b64: &str) -> Result<(Vec<u8>, ClientData), &'static str> {
    let raw = pc::b64url_decode(b64).map_err(|_| "clientData_invalid")?;
    let v: Value = serde_json::from_slice(&raw).map_err(|_| "clientData_invalid")?;
    Ok((raw, ClientData { typ: st(&v, "type"), challenge: st(&v, "challenge"), origin: st(&v, "origin") }))
}

fn pubkey_json(k: &pc::PubKey) -> Value {
    match k {
        pc::PubKey::Ec { x, y } => json!({ "kty": "EC", "crv": "P-256", "x": pc::b64url_encode(x), "y": pc::b64url_encode(y) }),
        pc::PubKey::Rsa { n, e } => json!({ "kty": "RSA", "n": pc::b64url_encode(n), "e": pc::b64url_encode(e), "alg": "RS256" }),
    }
}

fn verify_signature(jwk: &Value, signed: &[u8], sig: &[u8]) -> Result<(), &'static str> {
    let kty = jwk.get("kty").and_then(|x| x.as_str()).unwrap_or("");
    if kty == "EC" {
        let x = pc::b64url_decode(&st(jwk, "x")).map_err(|_| "assertion_key")?;
        let y = pc::b64url_decode(&st(jwk, "y")).map_err(|_| "assertion_key")?;
        if x.len() != 32 || y.len() != 32 {
            return Err("assertion_key");
        }
        let pt = pc::ec_point(&x, &y);
        UnparsedPublicKey::new(&signature::ECDSA_P256_SHA256_ASN1, &pt).verify(signed, sig).map_err(|_| "assertion_signature")
    } else if kty == "RSA" {
        let n = pc::b64url_decode(&st(jwk, "n")).map_err(|_| "assertion_key")?;
        let e = pc::b64url_decode(&st(jwk, "e")).map_err(|_| "assertion_key")?;
        let der = pc::rsa_public_der(&n, &e);
        UnparsedPublicKey::new(&signature::RSA_PKCS1_2048_8192_SHA256, &der).verify(signed, sig).map_err(|_| "assertion_signature")
    } else {
        Err("assertion_key")
    }
}

// ═══════════════════════════════ PUBLIC ═════════════════════════════════════
pub async fn public(proc: &str, input: &Value, headers: &HeaderMap) -> Resp {
    let ip = pc::client_ip(&hdr(headers, "x-forwarded-for"), &hdr(headers, "x-real-ip")).unwrap_or_else(|| "local".into());
    match proc {
        "auth.passkey.options" => {
            if !allow(&ip, "opt", 30, 60) {
                return fail(StatusCode::TOO_MANY_REQUESTS, "too_many_attempts");
            }
            login_options(input, headers).await
        }
        "auth.passkey.verify" => {
            if !allow(&ip, "ver", 20, 60) {
                return fail(StatusCode::TOO_MANY_REQUESTS, "too_many_attempts");
            }
            login_verify(input, headers).await
        }
        "auth.recovery.redeem" => {
            if !allow(&ip, "rec", 10, 60) {
                return fail(StatusCode::TOO_MANY_REQUESTS, "too_many_attempts");
            }
            recovery_redeem(input, headers).await
        }
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust"),
    }
}

async fn login_options(input: &Value, headers: &HeaderMap) -> Resp {
    let rp = match rp_of(headers) {
        Ok(r) => r,
        Err(c) => return bad(c),
    };
    let email = pc::anexomail_identity(&st(input, "email"));
    if email.is_empty() {
        return crate::err(StatusCode::BAD_REQUEST, "email_required", "Email is required.").into_response();
    }
    // Same answer whether the account exists or not (no user enumeration).
    let no_passkey = || crate::err(StatusCode::BAD_REQUEST, "no_passkey", "No passkey on this account. Use your password.").into_response();
    let uid = match crate::sb_rpc("auth_user_id_by_email", json!({ "_email": email })).await {
        Ok(v) => v.as_str().unwrap_or("").to_string(),
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "passkey_options_failed"),
    };
    if !is_uuid(&uid) {
        return no_passkey();
    }
    let creds = match crate::sb_select(&format!("webauthn_credentials?select=credential_id,transports&user_id=eq.{uid}")).await {
        Ok(v) => v,
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "passkey_options_failed"),
    };
    let allow_list: Vec<Value> = creds
        .as_array()
        .map(|a| {
            a.iter()
                .filter_map(|c| {
                    let id = st(c, "credential_id");
                    if !pc::is_b64url_token(&id, 1400) {
                        return None;
                    }
                    let tr = c.get("transports").filter(|t| t.as_array().map(|x| !x.is_empty()).unwrap_or(false)).cloned().unwrap_or(json!(["internal"]));
                    Some(json!({ "type": "public-key", "id": id, "transports": tr }))
                })
                .collect()
        })
        .unwrap_or_default();
    if allow_list.is_empty() {
        return no_passkey();
    }
    let challenge = match random_challenge() {
        Ok(c) => c,
        Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, &e),
    };
    let now = now_secs();
    let _ = pg_delete(&format!("webauthn_challenges?expires_at=lt.{}", pc::pct(&pc::iso_utc(now)))).await;
    let ins = crate::sb_insert(
        "webauthn_challenges",
        json!({
            "user_id": uid, "email": email, "kind": "authenticate", "challenge": challenge,
            "rp_id": rp.rp_id, "origin": rp.origin, "expires_at": pc::iso_utc(now + 300)
        }),
    )
    .await;
    if ins.is_err() {
        return fail(StatusCode::INTERNAL_SERVER_ERROR, "passkey_challenge_failed");
    }
    crate::ok(json!({ "publicKey": {
        "challenge": challenge, "rpId": rp.rp_id, "timeout": 60000, "userVerification": "required", "allowCredentials": allow_list
    }}))
    .into_response()
}

async fn login_verify(input: &Value, headers: &HeaderMap) -> Resp {
    let rp = match rp_of(headers) {
        Ok(r) => r,
        Err(c) => return bad(c),
    };
    let cred = cred_of(input);
    if !pc::is_b64url_token(&cred.id, 1400) {
        return bad("passkey_unknown");
    }
    let (client_raw, cd) = match parse_client_data(&cred.client_data) {
        Ok(x) => x,
        Err(c) => return bad(c),
    };
    if !pc::is_b64url_token(&cd.challenge, 128) {
        return bad("passkey_challenge_expired");
    }
    // 1) CONSUME the challenge first (single use, DB-side expiry). A replayed assertion finds nothing here.
    let now_iso = pc::iso_utc(now_secs());
    let consumed = pg_delete(&format!(
        "webauthn_challenges?kind=eq.authenticate&challenge=eq.{}&expires_at=gt.{}",
        pc::pct(&cd.challenge),
        pc::pct(&now_iso)
    ))
    .await;
    let ch = match consumed {
        Ok(v) => match first_row(&v) {
            Some(r) => r.clone(),
            None => return bad("passkey_challenge_expired"),
        },
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "passkey_verify_failed"),
    };
    if st(&ch, "origin") != rp.origin || st(&ch, "rp_id") != rp.rp_id {
        return bad("passkey_origin_mismatch");
    }
    // 2) credential
    let stored = match crate::sb_select(&format!(
        "webauthn_credentials?select=id,user_id,credential_id,public_key,sign_count&credential_id=eq.{}&limit=1",
        pc::pct(&cred.id)
    ))
    .await
    {
        Ok(v) => match first_row(&v) {
            Some(r) => r.clone(),
            None => return bad("passkey_unknown"),
        },
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "passkey_verify_failed"),
    };
    let owner = st(&stored, "user_id");
    let ch_user = st(&ch, "user_id");
    if !ch_user.is_empty() && ch_user != owner {
        return bad("passkey_unknown");
    }
    // 3) the assertion itself
    if let Err(c) = pc::check_client_data(&cd.typ, &cd.challenge, &cd.origin, "webauthn.get", &st(&ch, "challenge"), &rp.origin) {
        return bad(c);
    }
    let auth = match pc::b64url_decode(&cred.auth_data) {
        Ok(a) => a,
        Err(_) => return bad("authData_short"),
    };
    let ad = match pc::parse_auth_data(&auth, &sha256(rp.rp_id.as_bytes()), false) {
        Ok(a) => a,
        Err(c) => return bad(c),
    };
    let stored_count = stored.get("sign_count").and_then(|x| x.as_u64()).unwrap_or(0).min(u32::MAX as u64) as u32;
    if let Err(c) = pc::check_sign_count(ad.sign_count, stored_count) {
        return bad(c);
    }
    let sig = match pc::b64url_decode(&cred.signature) {
        Ok(s) => s,
        Err(_) => return bad("assertion_signature"),
    };
    let signed = pc::signed_data(&auth, &sha256(&client_raw));
    if let Err(c) = verify_signature(stored.get("public_key").unwrap_or(&Value::Null), &signed, &sig) {
        return bad(c);
    }
    let rowid = st(&stored, "id");
    if is_uuid(&rowid) {
        let _ = crate::sb_patch(
            &format!("webauthn_credentials?id=eq.{rowid}"),
            json!({ "sign_count": ad.sign_count, "last_used_at": pc::iso_utc(now_secs()) }),
        )
        .await;
    }
    // 4) real session
    let email = match user_email(&owner).await {
        Some(e) => e,
        None => return bad("passkey_user_missing"),
    };
    match mint_session(&email).await {
        Ok(m) => {
            save_session(&m, headers).await;
            crate::ok(session_json(&m)).into_response()
        }
        Err(c) => bad(&c),
    }
}

async fn user_email(user_id: &str) -> Option<String> {
    if !is_uuid(user_id) {
        return None;
    }
    let (url, key) = crate::sb()?;
    let res = crate::http()
        .get(format!("{url}/auth/v1/admin/users/{user_id}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await
        .ok()?;
    if !res.status().is_success() {
        return None;
    }
    let v: Value = res.json().await.ok()?;
    let e = st(&v, "email");
    if e.is_empty() { None } else { Some(e) }
}

async fn recovery_redeem(input: &Value, headers: &HeaderMap) -> Resp {
    let email = pc::anexomail_identity(&st(input, "email"));
    let code: String = st(input, "code").chars().take(40).collect();
    if email.is_empty() || code.is_empty() {
        return bad("invalid");
    }
    let r = match crate::sb_rpc("recovery_code_redeem", json!({ "_email": email, "_code": code })).await {
        Ok(v) => v,
        Err(_) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "recovery_codes_unavailable"),
    };
    if r.get("ok").and_then(|x| x.as_bool()) != Some(true) {
        let e = r.get("error").and_then(|x| x.as_str()).unwrap_or("invalid");
        return fail(if e == "too_many_attempts" { StatusCode::TOO_MANY_REQUESTS } else { StatusCode::BAD_REQUEST }, e);
    }
    match mint_session(&email).await {
        Ok(m) => {
            save_session(&m, headers).await;
            let mut out = session_json(&m);
            out["codes_left"] = r.get("codes_left").cloned().unwrap_or(json!(0));
            out["must_add_passkey"] = json!(true);
            crate::ok(out).into_response()
        }
        Err(c) => bad(&c),
    }
}

// ═══════════════════════════ AUTHENTICATED ══════════════════════════════════
pub async fn dispatch(proc: &str, token: &str, input: &Value, headers: &HeaderMap) -> Resp {
    let (uid, email) = match crate::auth_user(token).await {
        Some(u) => u,
        None => return crate::err(StatusCode::UNAUTHORIZED, "unauthorized", "").into_response(),
    };
    match proc {
        "auth.passkey.status" => status(&uid, &email).await,
        "auth.passkey.register.options" => register_options(&uid, &email, headers).await,
        "auth.passkey.register.verify" => register_verify(&uid, token, input, headers).await,
        "auth.recovery.generate" => recovery_generate(&uid).await,
        "auth.passkey.list" => list(&uid).await,
        "auth.passkey.delete" => delete(&uid, input).await,
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust"),
    }
}

async fn list(uid: &str) -> Resp {
    match crate::sb_select(&format!(
        "webauthn_credentials?select=id,device_name,created_at,last_used_at&user_id=eq.{uid}&order=created_at.desc"
    ))
    .await
    {
        Ok(v) => crate::ok(if v.is_array() { v } else { json!([]) }).into_response(),
        Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "passkey_list_failed"),
    }
}

/// Only YOUR row can go (user_id filter in the same DELETE). Last passkey gone => trial_accounts.passkey_set=false (gate returns).
async fn delete(uid: &str, input: &Value) -> Resp {
    let id = st(input, "id");
    if !is_uuid(&id) {
        return bad("passkey_id_invalid");
    }
    if pg_delete(&format!("webauthn_credentials?id=eq.{id}&user_id=eq.{uid}")).await.is_err() {
        return fail(StatusCode::INTERNAL_SERVER_ERROR, "passkey_delete_failed");
    }
    if credential_count(uid).await == 0 {
        let _ = crate::sb_patch(&format!("trial_accounts?user_id=eq.{uid}"), json!({ "passkey_set": false, "updated_at": pc::iso_utc(now_secs()) })).await;
    }
    crate::ok(json!({ "ok": true })).into_response()
}

async fn status(uid: &str, email: &str) -> Resp {
    // E76: pattern AKELA kaafi nahi — registry (test_accounts) mein bhi ho. rpc na mile/false => chhoot nahi (fail-closed).
    if pc::is_test_account(email)
        && crate::sb_rpc("is_registered_test_account", json!({ "_email": email })).await.ok().and_then(|v| v.as_bool()).unwrap_or(false)
    {
        return crate::ok(json!({ "exempt": true, "required": false, "hard": false, "count": 0, "target": 0, "codes_remaining": 1 })).into_response();
    }
    match crate::sb_rpc("passkey_status", json!({ "_user": uid })).await {
        Ok(v) => crate::ok(v).into_response(),
        // E43 SQL not run: honest "unknown", nothing locks
        Err(_) => crate::ok(json!({ "unknown": true, "required": false, "hard": false, "count": 0, "target": 2, "codes_remaining": 0 })).into_response(),
    }
}

async fn credential_count(uid: &str) -> i64 {
    crate::sb_count(&format!("webauthn_credentials?user_id=eq.{uid}")).await.unwrap_or(0)
}

async fn register_options(uid: &str, email: &str, headers: &HeaderMap) -> Resp {
    let rp = match rp_of(headers) {
        Ok(r) => r,
        Err(c) => return bad(c),
    };
    let challenge = match random_challenge() {
        Ok(c) => c,
        Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, &e),
    };
    let now = now_secs();
    let _ = pg_delete(&format!("webauthn_challenges?expires_at=lt.{}", pc::pct(&pc::iso_utc(now)))).await;
    let ins = crate::sb_insert(
        "webauthn_challenges",
        json!({
            "user_id": uid, "email": email, "kind": "register", "challenge": challenge,
            "rp_id": rp.rp_id, "origin": rp.origin, "expires_at": pc::iso_utc(now + 300)
        }),
    )
    .await;
    if ins.is_err() {
        return bad("passkey_challenge_failed");
    }
    // already-registered authenticators are excluded; NO authenticatorAttachment so phone (hybrid), laptop and security keys all work
    let existing = crate::sb_select(&format!("webauthn_credentials?select=credential_id&user_id=eq.{uid}")).await.unwrap_or(json!([]));
    let exclude: Vec<Value> = existing
        .as_array()
        .map(|a| a.iter().map(|c| json!({ "type": "public-key", "id": st(c, "credential_id") })).collect())
        .unwrap_or_default();
    crate::ok(json!({ "publicKey": {
        "challenge": challenge,
        "rp": { "name": "ANEXOMAIL", "id": rp.rp_id },
        "user": { "id": pc::b64url_encode(uid.as_bytes()), "name": email, "displayName": email },
        "pubKeyCredParams": [ { "type": "public-key", "alg": -7 }, { "type": "public-key", "alg": -257 } ],
        "excludeCredentials": exclude,
        "authenticatorSelection": { "residentKey": "preferred", "userVerification": "required" },
        "timeout": 120000,
        "attestation": "none"
    }}))
    .into_response()
}

async fn register_verify(uid: &str, token: &str, input: &Value, headers: &HeaderMap) -> Resp {
    let rp = match rp_of(headers) {
        Ok(r) => r,
        Err(c) => return bad(c),
    };
    let cred = cred_of(input);
    let (_raw, cd) = match parse_client_data(&cred.client_data) {
        Ok(x) => x,
        Err(c) => return bad(c),
    };
    if !pc::is_b64url_token(&cd.challenge, 128) {
        return bad("passkey_challenge_expired");
    }
    let now_iso = pc::iso_utc(now_secs());
    let consumed = pg_delete(&format!(
        "webauthn_challenges?user_id=eq.{uid}&kind=eq.register&challenge=eq.{}&expires_at=gt.{}",
        pc::pct(&cd.challenge),
        pc::pct(&now_iso)
    ))
    .await;
    let row = match consumed {
        Ok(v) => match first_row(&v) {
            Some(r) => r.clone(),
            None => return bad("passkey_challenge_expired"),
        },
        Err(_) => return fail(StatusCode::BAD_GATEWAY, "passkey_verify_failed"),
    };
    if st(&row, "origin") != rp.origin || st(&row, "rp_id") != rp.rp_id {
        return bad("passkey_origin_mismatch");
    }
    if let Err(c) = pc::check_client_data(&cd.typ, &cd.challenge, &cd.origin, "webauthn.create", &st(&row, "challenge"), &rp.origin) {
        return bad(c);
    }
    let att = match pc::b64url_decode(&cred.attestation) {
        Ok(a) => a,
        Err(_) => return bad("authData_missing"),
    };
    let auth = match pc::auth_data_from_attestation(&att) {
        Ok(a) => a,
        Err(c) => return bad(c),
    };
    let ad = match pc::parse_auth_data(&auth, &sha256(rp.rp_id.as_bytes()), true) {
        Ok(a) => a,
        Err(c) => return bad(c),
    };
    let (Some(cid), Some(cose)) = (ad.credential_id.as_ref(), ad.cose.as_ref()) else { return bad("attested_credential_missing") };
    let pk = match pc::cose_to_pubkey(cose) {
        Ok(k) => k,
        Err(c) => return bad(c),
    };
    let label = pc::clean_label(&st(input, "label"));
    let device_name = if label.is_empty() {
        let ua: String = hdr(headers, "user-agent").chars().take(80).collect();
        if ua.is_empty() { "This device".to_string() } else { ua }
    } else {
        label
    };
    let ins = crate::sb_insert(
        "webauthn_credentials",
        json!({
            "user_id": uid, "credential_id": pc::b64url_encode(cid), "public_key": pubkey_json(&pk),
            "sign_count": ad.sign_count, "device_name": device_name, "transports": ["internal"],
            "last_used_at": pc::iso_utc(now_secs())
        }),
    )
    .await;
    if let Err(e) = ins {
        return bad(if e.contains("duplicate") { "passkey_already_registered" } else { "passkey_save_failed" });
    }
    // markPasskeySet (same two writes as Bun)
    let _ = crate::sb_patch(&format!("trial_accounts?user_id=eq.{uid}"), json!({ "passkey_set": true, "updated_at": pc::iso_utc(now_secs()) })).await;
    let _ = crate::sb_rpc("trial_set_security", json!({ "_user_id": uid, "_passkey": true, "_recovery_kind": Value::Null, "_recovery_hint": Value::Null })).await;
    let count = credential_count(uid).await;
    // first passkey => 10 recovery codes (plain only here, once; DB keeps hashes)
    let mut codes = Value::Null;
    if count == 1 {
        if let Ok(c) = crate::sb_rpc("recovery_codes_regenerate", json!({ "_user": uid })).await {
            if c.is_array() {
                codes = c;
            }
        }
    }
    crate::ok(json!({ "token": token, "ok": true, "passkey_count": count, "recovery_codes": codes })).into_response()
}

async fn recovery_generate(uid: &str) -> Resp {
    if credential_count(uid).await == 0 {
        return bad("passkey_required_first");
    }
    match crate::sb_rpc("recovery_codes_regenerate", json!({ "_user": uid })).await {
        Ok(c) if c.is_array() => crate::ok(json!({ "codes": c })).into_response(),
        _ => fail(StatusCode::INTERNAL_SERVER_ERROR, "recovery_codes_failed"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ring::rand::SystemRandom;
    use ring::signature::{EcdsaKeyPair, KeyPair, ECDSA_P256_SHA256_ASN1_SIGNING};

const RSA_N: &str = "c18970549d9110233cbff3f8ad7d8fd4ffffe5056d035cd98a2487677b7cf91a501a9cee04d038497576585e99af0c01f5066b11578942267f0b60c82a99c6812ab3ea6aeee4b8652dc920ce1e9bec67ba7a7b7f79a5ca716d3a0025340a3fc817eff5d0485ab79f8f77b9e643988f62c6d9f9afe63d0f4755dd9b1d0119936f5629d548f5cdff96d1435449d61095d29739ed7b87350dedab7b5e1c631a7eef4ea2fdf0d34bd7143a1a3b7210b804ce8660180d7ff483d56e7022c8021de28b6e64ef2ad6140006f3b960a028a43e224ab221080750b138e51c8d4f33c5d5008f1302cbf5c412526c4be72d6e77078b0c00ad6a7e670e8b79801d9258322bb1";
const RSA_E: &str = "010001";
const RSA_SIG: &str = "07e9d394d48894710248400c8f7f17918ca90daa2702f3ca14f23d5e335b272cbb62233c7a6f6e80a20a8de4183cb3243e574c282df697ab43e7f89425c71d046ab30c99b949fd15bf235897cf00f245f27f8fe0b1c7d247a29b441a7cb4724b5f85650c84b190b073c53b037930197bba6efe0f9ef51e8c012ed4769982f09c4cd37d61875f8de0b8cca7321af19218f17b4d7bd5044c9b9109778cf59decee89abb2137bdb2cfc033587ae5334f17dca5c57e32269a2f6c1ace4606ebbdb3d9b01abbe3f4341fa21d9a467654de66ed89e87f1f1903155c986083b2c6f13aae30ce8c18432f45d6fbe1e125c40af757f94291c4797ea553091ae37023c7068";

    fn unhex(s: &str) -> Vec<u8> {
        (0..s.len() / 2).map(|i| u8::from_str_radix(&s[2 * i..2 * i + 2], 16).unwrap()).collect()
    }

    #[test]
    fn es256_assertion_verifies_and_tamper_fails() {
        let rng = SystemRandom::new();
        let pkcs8 = EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_ASN1_SIGNING, &rng).unwrap();
        let kp = EcdsaKeyPair::from_pkcs8(&ECDSA_P256_SHA256_ASN1_SIGNING, pkcs8.as_ref(), &rng).unwrap();
        let pubb = kp.public_key().as_ref().to_vec(); // 0x04 || x || y
        assert_eq!(pubb.len(), 65);
        let cose_like = pc::PubKey::Ec { x: pubb[1..33].to_vec(), y: pubb[33..65].to_vec() };
        let jwk = pubkey_json(&cose_like);
        let auth = vec![5u8; 37];
        let signed = pc::signed_data(&auth, &sha256(b"clientDataJSON"));
        let sig = kp.sign(&rng, &signed).unwrap();
        assert!(verify_signature(&jwk, &signed, sig.as_ref()).is_ok());
        let mut other = signed.clone();
        other[0] ^= 1;
        assert_eq!(verify_signature(&jwk, &other, sig.as_ref()), Err("assertion_signature"));
        let mut bad_sig = sig.as_ref().to_vec();
        let last = bad_sig.len() - 1;
        bad_sig[last] ^= 1;
        assert_eq!(verify_signature(&jwk, &signed, &bad_sig), Err("assertion_signature"));
        // a different key must not verify
        let pkcs8b = EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_ASN1_SIGNING, &rng).unwrap();
        let kpb = EcdsaKeyPair::from_pkcs8(&ECDSA_P256_SHA256_ASN1_SIGNING, pkcs8b.as_ref(), &rng).unwrap();
        let pb = kpb.public_key().as_ref().to_vec();
        let jwk_b = pubkey_json(&pc::PubKey::Ec { x: pb[1..33].to_vec(), y: pb[33..65].to_vec() });
        assert_eq!(verify_signature(&jwk_b, &signed, sig.as_ref()), Err("assertion_signature"));
        assert_eq!(verify_signature(&json!({"kty":"OKP"}), &signed, sig.as_ref()), Err("assertion_key"));
        assert_eq!(verify_signature(&Value::Null, &signed, sig.as_ref()), Err("assertion_key"));
    }

    #[test]
    fn rs256_openssl_vector_verifies() {
        let jwk = pubkey_json(&pc::PubKey::Rsa { n: unhex(RSA_N), e: unhex(RSA_E) });
        assert!(verify_signature(&jwk, b"webauthn-test-message", &unhex(RSA_SIG)).is_ok());
        assert_eq!(verify_signature(&jwk, b"webauthn-test-messagE", &unhex(RSA_SIG)), Err("assertion_signature"));
    }

    #[test]
    fn challenge_and_hash_helpers() {
        let a = random_challenge().unwrap();
        let b = random_challenge().unwrap();
        assert_ne!(a, b);
        assert_eq!(a.len(), 43);
        assert!(pc::is_b64url_token(&a, 128));
        // sha256("anexomail.com") is what authenticators put in authData
        assert_eq!(sha256(b"")[0], 0xe3);
        assert!(is_uuid("123e4567-e89b-12d3-a456-426614174000"));
        assert!(!is_uuid("123e4567-e89b-12d3-a456-4266141740zz;"));
    }

    #[test]
    fn limiter_blocks_after_max() {
        for _ in 0..3 {
            assert!(allow("9.9.9.9", "t", 3, 60));
        }
        assert!(!allow("9.9.9.9", "t", 3, 60));
        assert!(allow("9.9.9.10", "t", 3, 60));
    }
}
