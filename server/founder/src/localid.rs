//! QCONNECT step 7 (20 Nov 2026): the Rust IDENTITY ENGINE of the founder binary. Active only with FOUNDER_DB=local; otherwise `gotrue()` in auth.rs calls the managed identity service exactly as before.
//! Technology: Rust + Tokio; bcrypt (pure Rust, run on a blocking thread, constant work for unknown accounts); ES256 (ECDSA P-256 + SHA-256, the audited `ring` crate) access token signed with its OWN key file
//! (separate trust from the founder token); the SQL doors of LOCAL_E198 do the session / refresh-token rows and the hash-chained ledger; WebAuthn passkey stays the other way in (signin.rs).
//! The answers have the SHAPE of the identity service (`access_token`, `refresh_token`, `expires_at`, `user.id`), so auth.rs / signin.rs / main.rs do not change their logic and a rollback is just "unset FOUNDER_DB".
//! The password is never a database parameter (a slow statement is logged with its parameters): only the hash comes out, the compare is here.
use base64::{engine::general_purpose::URL_SAFE_NO_PAD as B64, Engine};
use ring::rand::{SecureRandom, SystemRandom};
use ring::signature::{EcdsaKeyPair, KeyPair, ECDSA_P256_SHA256_FIXED_SIGNING};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

pub const KID: &str = "lid1";
pub const TTL_SECS: i64 = 3600;
/// bcrypt hash of a fixed string, made once at the production cost: compared when the account does not exist, so "no such account" costs the same time as "wrong password".
fn decoy_hash() -> &'static str { static D: OnceLock<String> = OnceLock::new(); D.get_or_init(|| bcrypt::hash("no-such-account-decoy", 10).unwrap_or_default()) }

pub struct LocalId { pair: EcdsaKeyPair, pub jwk: crate::jwt_core::Jwk, iss: String }

impl LocalId {
    pub fn from_pkcs8(der: &[u8], base_url: &str) -> Option<LocalId> {
        let pair = EcdsaKeyPair::from_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, der, &SystemRandom::new()).ok()?;
        let point = pair.public_key().as_ref().to_vec();
        Some(LocalId { pair, jwk: crate::jwt_core::Jwk { kid: KID.into(), point }, iss: format!("{}/auth/v1", base_url.trim_end_matches('/')) })
    }
    /// The key file: read it, or make it (mode 0600) on first start. Err = the identity engine stays off and the site stays on gotrue.
    pub fn load_or_create(path: &str, base_url: &str) -> Result<LocalId, String> {
        if let Ok(d) = std::fs::read(path) { return LocalId::from_pkcs8(&d, base_url).ok_or_else(|| format!("{path} is not a valid PKCS#8 P-256 key")); }
        let der = EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, &SystemRandom::new()).map_err(|_| "key generation failed".to_string())?;
        use std::io::Write; use std::os::unix::fs::OpenOptionsExt;
        let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(path).map_err(|e| format!("{path}: {e}"))?;
        f.write_all(der.as_ref()).map_err(|e| e.to_string())?;
        LocalId::from_pkcs8(der.as_ref(), base_url).ok_or_else(|| "new key unreadable".to_string())
    }
    pub fn access_token(&self, uid: &str, email: &str, sid: &str, now: i64) -> Option<(String, i64)> {
        let exp = now + TTL_SECS;
        let h = B64.encode(json!({"alg": "ES256", "typ": "JWT", "kid": KID}).to_string());
        let p = B64.encode(json!({"iss": self.iss, "aud": "authenticated", "sub": uid, "email": email, "role": "authenticated", "session_id": sid, "aal": "aal1", "amr": [{"method": "password", "timestamp": now}], "iat": now, "exp": exp, "is_anonymous": false}).to_string());
        let msg = format!("{h}.{p}");
        let sig = self.pair.sign(&SystemRandom::new(), msg.as_bytes()).ok()?;
        Some((format!("{msg}.{}", B64.encode(sig.as_ref())), exp))
    }
    pub fn session_id_of(&self, token: &str, now: i64) -> Option<String> {
        crate::jwt_core::verify(token, std::slice::from_ref(&self.jwk), &self.iss, now).ok().and_then(|c| c.session_id)
    }
}

/// bcrypt compare on a blocking thread. `hash = None` (no such account) compares against the decoy and is always false.
pub async fn check_password(password: String, hash: Option<String>) -> bool {
    tokio::task::spawn_blocking(move || { let real = hash.is_some(); let h = hash.unwrap_or_else(|| decoy_hash().to_string()); bcrypt::verify(password, &h).unwrap_or(false) && real }).await.unwrap_or(false)
}

fn now_s() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }

fn session_json(lid: &LocalId, uid: &str, email: &str, sid: &str, refresh: &str, factors: i64) -> (u16, Value) {
    let now = now_s();
    let Some((tok, exp)) = lid.access_token(uid, email, sid, now) else { return (500, Value::Null) };
    let f: Vec<Value> = (0..factors.max(0)).map(|_| json!({"status": "verified"})).collect();
    (200, json!({"access_token": tok, "token_type": "bearer", "expires_in": TTL_SECS, "expires_at": exp, "refresh_token": refresh, "user": {"id": uid, "email": email, "factors": f}}))
}

/// One-time hand-off for the passkey mint (generate_link + verify of the identity service, rebuilt in memory): 60 s, single use.
fn links() -> &'static Mutex<HashMap<String, (String, Instant)>> { static L: OnceLock<Mutex<HashMap<String, (String, Instant)>>> = OnceLock::new(); L.get_or_init(Default::default) }

async fn user_row(pg: &crate::pg::Pg, email: Option<&str>, uid: Option<&str>) -> Result<Option<Value>, ()> {
    let body = json!({"p_email": email, "p_uid": uid});
    match pg.rpc("localid_user", &body).await { Ok(Value::Null) => Ok(None), Ok(v) => Ok(Some(v)), Err(_) => Err(()) }
}

fn usable(u: &Value) -> bool { !u["banned"].as_bool().unwrap_or(true) && !u["deleted"].as_bool().unwrap_or(true) && u["confirmed"].as_bool().unwrap_or(false) && !u["anonymous"].as_bool().unwrap_or(true) }

async fn open_grant(pg: &crate::pg::Pg, lid: &LocalId, u: &Value) -> (u16, Value) {
    let uid = u["id"].as_str().unwrap_or("");
    match pg.rpc("localid_open", &json!({"p_uid": uid, "p_ua": Value::Null, "p_ip": Value::Null})).await {
        Ok(o) => session_json(lid, uid, u["email"].as_str().unwrap_or(""), o["session_id"].as_str().unwrap_or(""), o["refresh"].as_str().unwrap_or(""), u["factors"].as_i64().unwrap_or(0)),
        Err((403, _)) => (400, json!({"error": "invalid_grant"})), // E71 backstop: a pending or rejected account never gets a session
        Err(_) => (503, Value::Null),
    }
}

/// The same call shape as `auth::gotrue`: (HTTP status, JSON). Err(()) = the database is unreachable.
pub async fn call(sb: &crate::data::Sb, path_q: &str, body: Option<Value>, bearer: Option<&str>) -> Result<(u16, Value), ()> {
    let (Some(pg), Some(lid)) = (sb.pg.as_ref(), sb.pg.as_ref().and_then(|p| p.id.as_ref())) else { return Err(()) };
    let b = body.unwrap_or(Value::Null);
    match path_q {
        "token?grant_type=password" => {
            let (Some(email), Some(pw)) = (b["email"].as_str(), b["password"].as_str()) else { return Ok((400, json!({"error": "invalid_grant"}))) };
            let u = user_row(pg, Some(email), None).await?;
            let hash = u.as_ref().and_then(|u| u["hash"].as_str()).filter(|h| !h.is_empty()).map(str::to_string);
            let right = check_password(pw.to_string(), hash).await;
            match u { Some(u) if right && usable(&u) => Ok(open_grant(pg, lid, &u).await), _ => Ok((400, json!({"error": "invalid_grant"}))) }
        }
        "token?grant_type=refresh_token" => {
            let Some(rt) = b["refresh_token"].as_str() else { return Ok((400, json!({"error": "invalid_grant"}))) };
            let r = match pg.rpc("localid_refresh", &json!({"p_token": rt, "p_ua": Value::Null, "p_ip": Value::Null})).await { Ok(v) => v, Err(_) => return Err(()) };
            if r.get("error").is_some() { return Ok((400, json!({"error": "invalid_grant"}))); }
            let uid = r["uid"].as_str().unwrap_or("");
            match user_row(pg, None, Some(uid)).await? { Some(u) if usable(&u) => Ok(session_json(lid, uid, u["email"].as_str().unwrap_or(""), r["session_id"].as_str().unwrap_or(""), r["refresh"].as_str().unwrap_or(""), u["factors"].as_i64().unwrap_or(0))), _ => Ok((400, json!({"error": "invalid_grant"}))) }
        }
        "logout" => {
            if let Some(sid) = bearer.and_then(|t| lid.session_id_of(t, now_s())) { let _ = pg.rpc("localid_close", &json!({"p_session": sid})).await; }
            Ok((204, Value::Null))
        }
        "admin/generate_link" => {
            let Some(email) = b["email"].as_str() else { return Ok((400, Value::Null)) };
            let Some(u) = user_row(pg, Some(email), None).await?.filter(usable) else { return Ok((404, Value::Null)) };
            let mut raw = [0u8; 32]; SystemRandom::new().fill(&mut raw).map_err(|_| ())?;
            let th = B64.encode(raw);
            { let mut l = links().lock().unwrap(); let now = Instant::now(); l.retain(|_, (_, t)| now.duration_since(*t) < Duration::from_secs(60)); l.insert(th.clone(), (u["id"].as_str().unwrap_or("").to_string(), now)); }
            Ok((200, json!({"hashed_token": th})))
        }
        "verify" => {
            let Some(th) = b["token_hash"].as_str() else { return Ok((400, Value::Null)) };
            let taken = { let mut l = links().lock().unwrap(); l.remove(th) };
            let Some((uid, t)) = taken.filter(|(_, t)| t.elapsed() < Duration::from_secs(60)) else { return Ok((400, json!({"error": "invalid_grant"}))) };
            match user_row(pg, None, Some(&uid)).await? { Some(u) if usable(&u) => Ok(open_grant(pg, lid, &u).await), _ => Ok((400, json!({"error": "invalid_grant"}))) }
        }
        _ => Ok((404, Value::Null)),
    }
}

/// The identity service's admin user lookup (signin.rs mint): the account's email, or None.
pub async fn admin_email(sb: &crate::data::Sb, uid: &str) -> Option<String> {
    let pg = sb.pg.as_ref()?;
    user_row(pg, None, Some(uid)).await.ok().flatten().and_then(|u| u["email"].as_str().map(str::to_string))
}

#[cfg(test)]
mod tests {
    /// 21 Nov 2026: the key file made by the prep script (openssl) must load in ring exactly like a ring-made key. Set KEYTEST=<der file> to try another file.
    #[test]
    fn openssl_made_key_loads() {
        let Ok(path) = std::env::var("KEYTEST") else { return };
        let der = std::fs::read(&path).unwrap();
        assert!(LocalId::from_pkcs8(&der, "https://x.test").is_some(), "ring refused the key file {path} ({} bytes)", der.len());
    }

    use super::*;
    fn lid() -> LocalId { let der = EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, &SystemRandom::new()).unwrap(); LocalId::from_pkcs8(der.as_ref(), "https://db.example/").unwrap() }
    #[test] fn token_verifies_with_the_shared_jwt_core_and_nothing_else() {
        let l = lid(); let (t, exp) = l.access_token("u-1", "a@b.co", "s-1", 1_000).unwrap(); assert_eq!(exp, 1_000 + TTL_SECS);
        let c = crate::jwt_core::verify(&t, std::slice::from_ref(&l.jwk), "https://db.example/auth/v1", 1_100).unwrap(); assert_eq!((c.sub.as_str(), c.email.as_str(), c.session_id.as_deref()), ("u-1", "a@b.co", Some("s-1")));
        assert!(crate::jwt_core::verify(&t, std::slice::from_ref(&l.jwk), "https://db.example/auth/v1", 1_000 + TTL_SECS + 60).is_err(), "expired");
        assert!(crate::jwt_core::verify(&t, std::slice::from_ref(&l.jwk), "https://other.example/auth/v1", 1_100).is_err(), "wrong issuer");
        let other = lid(); assert!(crate::jwt_core::verify(&t, std::slice::from_ref(&other.jwk), "https://db.example/auth/v1", 1_100).is_err(), "another key never verifies it");
        assert_eq!(l.session_id_of(&t, 1_100).as_deref(), Some("s-1"));
    }
    #[tokio::test] async fn bcrypt_right_wrong_and_absent() {
        let h = bcrypt::hash("correct horse", 4).unwrap();
        assert!(check_password("correct horse".into(), Some(h.clone())).await); assert!(!check_password("wrong".into(), Some(h)).await);
        assert!(!check_password("anything".into(), None).await, "an absent account is never right, and still pays the bcrypt time");
        assert!(bcrypt::verify("x", decoy_hash()).is_ok(), "the decoy is a parseable hash");
    }
    #[test] fn key_file_is_made_once_with_mode_0600() {
        let p = std::env::temp_dir().join(format!("lid-{}.p8", std::process::id())); let _ = std::fs::remove_file(&p);
        let a = LocalId::load_or_create(p.to_str().unwrap(), "https://x").unwrap(); let b = LocalId::load_or_create(p.to_str().unwrap(), "https://x").unwrap();
        assert_eq!(a.jwk.point, b.jwk.point); use std::os::unix::fs::PermissionsExt; assert_eq!(std::fs::metadata(&p).unwrap().permissions().mode() & 0o777, 0o600); let _ = std::fs::remove_file(&p);
    }
}

/// Real-database proof: `PG_TEST_URL=postgresql://postgres@/anexo_q?host=/tmp&port=5546 cargo test lid_live -- --ignored` (needs E198 + the compat layer on that database).
#[cfg(test)]
mod live {
    use super::*;
    use tokio_postgres::NoTls;
    #[tokio::test] #[ignore]
    async fn lid_live_password_refresh_logout_mint_and_the_e71_guard() {
        let url = std::env::var("PG_TEST_URL").expect("PG_TEST_URL");
        let (adm, conn) = tokio_postgres::connect(&url, NoTls).await.unwrap(); tokio::spawn(conn);
        let hash = bcrypt::hash("right-password", 4).unwrap();
        adm.batch_execute("delete from auth.refresh_tokens where user_id in (select id::text from auth.users where email like 'lid-%@invalid.test'); delete from auth.sessions where user_id in (select id from auth.users where email like 'lid-%@invalid.test'); delete from auth.users where email like 'lid-%@invalid.test'").await.unwrap();
        let mk = |e: &str, extra: &str| format!("insert into auth.users(email, encrypted_password, email_confirmed_at{}) values ('{e}', '{hash}', now(){}) returning id::text", if extra.is_empty() { "" } else { ", banned_until" }, if extra.is_empty() { String::new() } else { format!(", {extra}") });
        let uid: String = adm.query_one(&mk("lid-ok@invalid.test", ""), &[]).await.unwrap().get(0);
        adm.query_one(&mk("lid-banned@invalid.test", "now() + interval '1 day'"), &[]).await.unwrap();
        let pend: String = adm.query_one(&mk("lid-pending@invalid.test", ""), &[]).await.unwrap().get(0);
        adm.batch_execute(&format!("create table if not exists public.identity_account_state(account_id uuid primary key, state text); insert into public.identity_account_state values ('{pend}', 'pending') on conflict (account_id) do update set state='pending';
            create or replace function public.identity_session_guard() returns trigger language plpgsql as $$ declare st text; begin select s.state into st from public.identity_account_state s where s.account_id = new.user_id; if st in ('pending','rejected') then raise exception 'account_pending' using errcode='42501'; end if; return new; end $$;
            drop trigger if exists identity_session_guard_trg on auth.sessions; create trigger identity_session_guard_trg before insert on auth.sessions for each row execute function public.identity_session_guard();")).await.unwrap();
        let mut pg = crate::pg::Pg::connect(&url, 4).await.unwrap();
        pg.id = Some(LocalId::from_pkcs8(EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, &SystemRandom::new()).unwrap().as_ref(), "https://db.example").unwrap());
        let sb = crate::data::Sb { url: "https://db.example".into(), key: "k".into(), http: reqwest::Client::new(), pg: Some(std::sync::Arc::new(pg)) };
        let lid = sb.pg.as_ref().unwrap().id.as_ref().unwrap();
        macro_rules! g { ($p:expr, $b:expr, $t:expr) => { call(&sb, $p, Some($b), $t).await.unwrap() } }

        let (st, s) = g!("token?grant_type=password", json!({"email": "LID-OK@invalid.test", "password": "right-password"}), None); assert_eq!(st, 200, "{s}");
        assert_eq!(s["user"]["id"].as_str().unwrap(), uid); assert_eq!(s["user"]["factors"], json!([]));
        let sid = lid.session_id_of(s["access_token"].as_str().unwrap(), now_s()).expect("the token verifies with our key"); assert!(!sid.is_empty());
        assert_eq!(g!("token?grant_type=password", json!({"email": "lid-ok@invalid.test", "password": "WRONG"}), None).0, 400);
        assert_eq!(g!("token?grant_type=password", json!({"email": "nobody@invalid.test", "password": "right-password"}), None).0, 400);
        assert_eq!(g!("token?grant_type=password", json!({"email": "lid-banned@invalid.test", "password": "right-password"}), None).0, 400, "banned = refused even with the right password");
        assert_eq!(g!("token?grant_type=password", json!({"email": "lid-pending@invalid.test", "password": "right-password"}), None).0, 400, "E71 guard 42501 = invalid, not a 503 retry");
        // refresh rotation
        let r1 = s["refresh_token"].as_str().unwrap().to_string();
        let (st, s2) = g!("token?grant_type=refresh_token", json!({"refresh_token": r1}), None); assert_eq!(st, 200); let r2 = s2["refresh_token"].as_str().unwrap().to_string(); assert_ne!(r1, r2);
        adm.batch_execute(&format!("update auth.refresh_tokens set updated_at = now() - interval '1 minute' where token = '{r1}'")).await.unwrap();
        assert_eq!(g!("token?grant_type=refresh_token", json!({"refresh_token": r1}), None).0, 400, "a used token again = refused");
        assert_eq!(g!("token?grant_type=refresh_token", json!({"refresh_token": r2}), None).0, 400, "...and the whole session is dead after a reuse");
        assert_eq!(adm.query_one(&format!("select count(*) from auth.sessions where id = '{sid}'"), &[]).await.unwrap().get::<_, i64>(0), 0);
        // logout
        let (_, s3) = g!("token?grant_type=password", json!({"email": "lid-ok@invalid.test", "password": "right-password"}), None); let t3 = s3["access_token"].as_str().unwrap().to_string();
        assert_eq!(g!("logout", Value::Null, Some(&t3)).0, 204); let sid3 = lid.session_id_of(&t3, now_s()).unwrap();
        assert_eq!(adm.query_one(&format!("select count(*) from auth.sessions where id = '{sid3}'"), &[]).await.unwrap().get::<_, i64>(0), 0);
        // passkey mint: generate_link + verify, single use
        let (c, l) = g!("admin/generate_link", json!({"type": "magiclink", "email": "lid-ok@invalid.test"}), Some("k")); assert_eq!(c, 200); let th = l["hashed_token"].as_str().unwrap().to_string();
        let (c, v) = g!("verify", json!({"type": "magiclink", "token_hash": th}), None); assert_eq!(c, 200); assert_eq!(v["user"]["id"].as_str().unwrap(), uid);
        assert_eq!(g!("verify", json!({"type": "magiclink", "token_hash": th}), None).0, 400, "a hand-off is single use");
        assert_eq!(g!("admin/generate_link", json!({"type": "magiclink", "email": "lid-banned@invalid.test"}), Some("k")).0, 404);
        assert_eq!(admin_email(&sb, &uid).await.as_deref(), Some("lid-ok@invalid.test"));
        let ev = sb.pg.as_ref().unwrap().rpc("localid_verify", &json!({})).await.unwrap(); assert_eq!(ev["broken"], json!(0), "the ledger chain holds: {ev}"); assert!(ev["checked"].as_i64().unwrap() >= 6);
        assert!(sb.pg.as_ref().unwrap().rpc("localid_selftest", &json!({})).await.unwrap().as_str().unwrap().ends_with("10/10"));
        adm.batch_execute("delete from auth.refresh_tokens where user_id in (select id::text from auth.users where email like 'lid-%@invalid.test'); delete from auth.sessions where user_id in (select id from auth.users where email like 'lid-%@invalid.test'); delete from auth.users where email like 'lid-%@invalid.test'; drop trigger if exists identity_session_guard_trg on auth.sessions").await.unwrap();
    }
}
