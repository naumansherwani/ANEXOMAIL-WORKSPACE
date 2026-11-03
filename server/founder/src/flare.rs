//! J6 — FLARE v2: the phone push sender (founder lane, Rust, `ring` only, no new crate).
//! Standards: RFC 8030 (Web Push protocol), RFC 8291 (message encryption, `aes128gcm`), RFC 8292 (VAPID, ES256 JWT), and the Declarative Web Push payload
//! (`{"web_push":8030,"notification":{title,navigate,...}}`, WebKit "Meet Declarative Web Push": Safari shows it without a service worker, other browsers get the same JSON in `push`).
//! SQL brain: docs/cursor-work/sql/E140_founder_flare_push.sql (outbox, claim/report doors, hash-chained ledger). Research + honest limits: docs/claude/FOUNDER-FLARE-J6-RESEARCH-03NOV.md.
//! The payload never contains the action: only a code word, the request id and (for the one-time confirm) a token that the database keeps as a hash.

use base64::Engine as _;
use base64::engine::general_purpose::URL_SAFE_NO_PAD as B64;
use ring::{aead, agreement, digest, hkdf, signature as ecdsa, rand::{SecureRandom, SystemRandom}};
use serde_json::{Value, json};

const RS: u32 = 4096;                       // record size we announce; one record only (RFC 8291 §4)
const MAX_PLAIN: usize = 3993;              // 4096 - 16 tag - 1 delimiter - 86 header (21 + 65) - 0 padding  (RFC 8291 §4: a push message is at most 4096 bytes)

struct Len(usize);
impl hkdf::KeyType for Len { fn len(&self) -> usize { self.0 } }

fn expand(prk: &hkdf::Prk, info: &[u8], n: usize) -> Result<Vec<u8>, &'static str> {
    let mut out = vec![0u8; n];
    prk.expand(&[info], Len(n)).map_err(|_| "hkdf expand")?.fill(&mut out).map_err(|_| "hkdf fill")?;
    Ok(out)
}

/// RFC 8291 §3.3-3.4: from the ECDH secret to the content-encryption key and nonce. Pure: the RFC's own test vector pins it.
pub fn derive(ecdh: &[u8], auth: &[u8], ua_pub: &[u8], as_pub: &[u8], salt: &[u8]) -> Result<([u8; 16], [u8; 12]), &'static str> {
    if auth.len() != 16 || ua_pub.len() != 65 || as_pub.len() != 65 || salt.len() != 16 { return Err("bad key or salt length"); }
    let prk_key = hkdf::Salt::new(hkdf::HKDF_SHA256, auth).extract(ecdh);
    let mut key_info = b"WebPush: info\0".to_vec(); key_info.extend_from_slice(ua_pub); key_info.extend_from_slice(as_pub);
    let ikm = expand(&prk_key, &key_info, 32)?;
    let prk = hkdf::Salt::new(hkdf::HKDF_SHA256, salt).extract(&ikm);
    let cek = expand(&prk, b"Content-Encoding: aes128gcm\0", 16)?;
    let nonce = expand(&prk, b"Content-Encoding: nonce\0", 12)?;
    let mut k = [0u8; 16]; k.copy_from_slice(&cek);
    let mut n = [0u8; 12]; n.copy_from_slice(&nonce);
    Ok((k, n))
}

/// Seal one record: `plain || 0x02` under AES-128-GCM, no AAD. Output = the aes128gcm body of RFC 8188 with our public key as key id.
pub fn seal(cek: &[u8; 16], nonce: &[u8; 12], salt: &[u8; 16], as_pub: &[u8], plain: &[u8]) -> Result<Vec<u8>, &'static str> {
    if plain.len() > MAX_PLAIN { return Err("payload too large for one push record"); }
    let key = aead::LessSafeKey::new(aead::UnboundKey::new(&aead::AES_128_GCM, cek).map_err(|_| "aes key")?);
    let mut buf = plain.to_vec(); buf.push(0x02);                        // 0x02 = last record, no padding
    key.seal_in_place_append_tag(aead::Nonce::assume_unique_for_key(*nonce), aead::Aad::empty(), &mut buf).map_err(|_| "seal")?;
    let mut body = Vec::with_capacity(86 + buf.len());
    body.extend_from_slice(salt); body.extend_from_slice(&RS.to_be_bytes()); body.push(as_pub.len() as u8); body.extend_from_slice(as_pub); body.extend_from_slice(&buf);
    Ok(body)
}

/// Encrypt `plain` for a subscription (`p256dh` and `auth` are base64url as the browser gives them).
pub fn encrypt(p256dh_b64: &str, auth_b64: &str, plain: &[u8]) -> Result<Vec<u8>, &'static str> {
    let ua_pub = B64.decode(p256dh_b64).map_err(|_| "p256dh is not base64url")?;
    let auth = B64.decode(auth_b64).map_err(|_| "auth is not base64url")?;
    if ua_pub.len() != 65 || ua_pub[0] != 4 { return Err("p256dh is not an uncompressed P-256 point"); }
    let rng = SystemRandom::new();
    let eph = agreement::EphemeralPrivateKey::generate(&agreement::ECDH_P256, &rng).map_err(|_| "ephemeral key")?;
    let as_pub = eph.compute_public_key().map_err(|_| "public key")?.as_ref().to_vec();
    let mut salt = [0u8; 16]; rng.fill(&mut salt).map_err(|_| "salt")?;
    let ua = agreement::UnparsedPublicKey::new(&agreement::ECDH_P256, ua_pub.clone());
    let (cek, nonce) = agreement::agree_ephemeral(eph, &ua, |secret| derive(secret, &auth, &ua_pub, &as_pub, &salt)).map_err(|_| "the subscription key is not a valid P-256 point")??;
    seal(&cek, &nonce, &salt, &as_pub, plain)
}

// ------------------------------------------------------------------ VAPID (RFC 8292) ------------------------------------------------------------------

pub struct Vapid { kp: ecdsa::EcdsaKeyPair, public: Vec<u8>, subject: String }
impl Vapid {
    pub fn from_pkcs8(d: &[u8], subject: &str) -> Option<Vapid> {
        let rng = SystemRandom::new();
        let kp = ecdsa::EcdsaKeyPair::from_pkcs8(&ecdsa::ECDSA_P256_SHA256_FIXED_SIGNING, d, &rng).ok()?;
        let public = ecdsa::KeyPair::public_key(&kp).as_ref().to_vec();
        Some(Vapid { kp, public, subject: subject.to_string() })
    }
    /// Load the key file; if it does not exist yet make a fresh P-256 key (0400) so the installer needs no extra step. The private key never leaves the server.
    pub fn load_or_create(path: &str, subject: &str) -> Option<Vapid> {
        if let Ok(d) = std::fs::read(path) { return Vapid::from_pkcs8(&d, subject); }
        let rng = SystemRandom::new();
        let doc = ecdsa::EcdsaKeyPair::generate_pkcs8(&ecdsa::ECDSA_P256_SHA256_FIXED_SIGNING, &rng).ok()?;
        if let Some(dir) = std::path::Path::new(path).parent() { let _ = std::fs::create_dir_all(dir); }
        #[cfg(unix)] {
            use std::io::Write; use std::os::unix::fs::OpenOptionsExt;
            let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(0o400).open(path).ok()?;
            f.write_all(doc.as_ref()).ok()?;
        }
        #[cfg(not(unix))] { std::fs::write(path, doc.as_ref()).ok()?; }
        Vapid::from_pkcs8(doc.as_ref(), subject)
    }
    /// The applicationServerKey the browser subscribes with (65 bytes, base64url).
    pub fn public_b64(&self) -> String { B64.encode(&self.public) }
    /// `Authorization: vapid t=<jwt>, k=<key>` for one push service origin; the JWT lives 12 hours (the RFC allows at most 24).
    pub fn authorization(&self, endpoint: &str, now_s: i64) -> Result<String, &'static str> {
        let aud = origin_of(endpoint).ok_or("endpoint has no origin")?;
        let head = B64.encode(br#"{"typ":"JWT","alg":"ES256"}"#);
        let claims = B64.encode(serde_json::to_vec(&json!({"aud": aud, "exp": now_s + 12 * 3600, "sub": self.subject})).map_err(|_| "claims")?);
        let signing = format!("{head}.{claims}");
        let sig = self.kp.sign(&SystemRandom::new(), signing.as_bytes()).map_err(|_| "sign")?;
        Ok(format!("vapid t={signing}.{}, k={}", B64.encode(sig.as_ref()), self.public_b64()))
    }
}

pub fn origin_of(endpoint: &str) -> Option<String> {
    let rest = endpoint.strip_prefix("https://")?;
    let host = rest.split('/').next().filter(|h| !h.is_empty() && !h.contains('@'))?;
    Some(format!("https://{host}"))
}

// ------------------------------------------------------------------ the message ------------------------------------------------------------------

/// Declarative-Web-Push-shaped payload. `origin` is the founder host (navigate must stay on the site). No secret of any action is ever written here.
pub fn payload(kind: &str, reference: Option<&str>, token: Option<&str>, origin: &str) -> Option<Vec<u8>> {
    let (title, body, urgent) = match kind {
        "confirm" => ("Confirm this phone", "Open to finish setting up alerts.", false),
        "test" => ("Test alert", "Phone alerts work.", false),
        "t3_begun" => ("Protected action started", "A two-key action was started. If it was not you, cancel it now.", true),
        "t3_approved" => ("Protected action approved", "The second key approved it. Check it now.", true),
        "t3_cancelled" => ("Protected action cancelled", "A protected action was cancelled.", false),
        _ => return None,
    };
    let mut v = json!({
        "web_push": 8030,
        "notification": {"title": title, "body": body, "navigate": format!("{origin}/#/settings"), "silent": false, "lang": "en", "dir": "ltr", "tag": format!("anexo-{kind}"), "requireInteraction": urgent},
        "k": kind,
    });
    if let Some(r) = reference { v["r"] = json!(r); }
    if let Some(t) = token { v["t"] = json!(t); }
    serde_json::to_vec(&v).ok()
}

/// Topic header (RFC 8030 §5.4): up to 32 URL-safe characters; a newer message with the same topic replaces an undelivered one.
pub fn topic_of(tag: &str) -> String {
    let d = digest::digest(&digest::SHA256, tag.as_bytes());
    B64.encode(&d.as_ref()[..18])              // 24 characters
}

// ------------------------------------------------------------------ the sender loop ------------------------------------------------------------------

pub static PUBLIC: std::sync::OnceLock<String> = std::sync::OnceLock::new();   // the applicationServerKey, for GET /founder/v1/flare/key

pub struct Cfg { pub vapid: Vapid, pub origin: String }
impl Cfg {
    pub fn from_env() -> Option<Cfg> {
        if std::env::var("FOUNDER_FLARE").map(|v| v == "off").unwrap_or(false) { return None; }
        let origin = std::env::var("FOUNDER_ORIGIN").unwrap_or_else(|_| "https://founderworkspace.anexomail.com".into());
        let subject = std::env::var("FOUNDER_VAPID_SUB").unwrap_or_else(|_| origin.clone());
        let path = std::env::var("FOUNDER_VAPID_KEY_FILE").unwrap_or_else(|_| "/etc/anexomail/founder-vapid.p8".into());
        Some(Cfg { vapid: Vapid::load_or_create(&path, &subject)?, origin })
    }
}

fn now_s() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }

/// Send one claimed row; returns the HTTP status the push service answered (0 = no answer / could not even build the request) and its Retry-After.
async fn send_one(http: &reqwest::Client, cfg: &Cfg, row: &Value) -> (i32, Option<i32>) {
    let s = |k: &str| row.get(k).and_then(|v| v.as_str()).unwrap_or("");
    let kind = s("kind");
    let token = row.get("payload").and_then(|p| p.get("t")).and_then(|t| t.as_str());
    let reference = row.get("payload").and_then(|p| p.get("r")).and_then(|t| t.as_str());
    let Some(plain) = payload(kind, reference, token, &cfg.origin) else { return (400, None) };
    let Ok(body) = encrypt(s("p256dh"), s("auth"), &plain) else { return (400, None) };
    let Ok(auth) = cfg.vapid.authorization(s("endpoint"), now_s()) else { return (400, None) };
    let ttl = row.get("ttl").and_then(|v| v.as_i64()).unwrap_or(300).clamp(60, 86400);
    let urgency = match s("urgency") { "very-low" | "low" | "normal" | "high" => s("urgency"), _ => "normal" };
    let r = http.post(s("endpoint")).header("Authorization", auth).header("Content-Encoding", "aes128gcm").header("Content-Type", "application/octet-stream")
        .header("TTL", ttl.to_string()).header("Urgency", urgency).header("Topic", topic_of(s("tag"))).body(body).send().await;
    match r {
        Ok(resp) => {
            let ra = resp.headers().get("retry-after").and_then(|v| v.to_str().ok()).and_then(|v| v.trim().parse::<i32>().ok());
            (resp.status().as_u16() as i32, ra)
        }
        Err(_) => (0, None),
    }
}

/// One pass: claim, send, report. Returns how many rows were handled (None = the E140 doors are not installed or the database did not answer).
pub async fn tick(sb: &crate::data::Sb, http: &reqwest::Client, cfg: &Cfg) -> Option<usize> {
    let got = sb.rpc("founder_push_claim", json!({"p_limit": 10})).await?;
    let rows = got.get("rows").and_then(|r| r.as_array()).cloned().unwrap_or_default();
    for row in &rows {
        let Some(id) = row.get("id").and_then(|v| v.as_str()) else { continue };
        let (status, ra) = send_one(http, cfg, row).await;
        let _ = sb.rpc("founder_push_report", json!({"p_id": id, "p_status": status, "p_retry_after": ra})).await;
    }
    Some(rows.len())
}

/// Background sender: every 4 s while there is work, every 20 s when idle, 60 s when the SQL is missing. Never panics, never blocks a request.
pub fn spawn(sb: crate::data::Sb, cfg: Cfg) {
    tokio::spawn(async move {
        let http = reqwest::Client::builder().timeout(std::time::Duration::from_secs(15)).connect_timeout(std::time::Duration::from_secs(8)).user_agent("anexomail-founder-flare/1").build().unwrap_or_default();
        let _ = PUBLIC.set(cfg.vapid.public_b64());
        eprintln!("founder: flare sender ON (Web Push, VAPID key {}…)", &cfg.vapid.public_b64()[..8]);
        loop {
            let wait = match tick(&sb, &http, &cfg).await { Some(n) if n > 0 => 4, Some(_) => 20, None => 60 };
            tokio::time::sleep(std::time::Duration::from_secs(wait)).await;
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    fn b(s: &str) -> Vec<u8> { B64.decode(s).unwrap() }

    // RFC 8291 Appendix A ("When I grow up, I want to be a watermelon"): the key schedule must reproduce the RFC's IKM-derived CEK and NONCE from its published secret.
    #[test]
    fn rfc8291_appendix_a_key_schedule() {
        let ecdh = b("kyrL1jIIOHEzg3sM2ZWRHDRB62YACZhhSlknJ672kSs");
        let auth = b("BTBZMqHH6r4Tts7J_aSIgg");
        let ua = b("BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4");
        let asp = b("BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8");
        let salt = b("DGv6ra1nlYgDCS1FRnbzlw");
        let (cek, nonce) = derive(&ecdh, &auth, &ua, &asp, &salt).unwrap();
        assert_eq!(B64.encode(cek), "oIhVW04MRdy2XN9CiKLxTg");
        assert_eq!(B64.encode(nonce), "4h_95klXJ5E_qnoN");
    }

    #[test]
    fn derive_refuses_bad_lengths() {
        assert!(derive(&[0; 32], &[0; 15], &[4; 65], &[4; 65], &[0; 16]).is_err());
        assert!(derive(&[0; 32], &[0; 16], &[4; 64], &[4; 65], &[0; 16]).is_err());
        assert!(derive(&[0; 32], &[0; 16], &[4; 65], &[4; 65], &[0; 15]).is_err());
    }

    // An independent receiver (the browser's side) written from the RFC: it must open what encrypt() made.
    #[test]
    fn encrypt_round_trips_through_an_independent_receiver() {
        let rng = SystemRandom::new();
        let ua_priv = agreement::EphemeralPrivateKey::generate(&agreement::ECDH_P256, &rng).unwrap();
        let ua_pub = ua_priv.compute_public_key().unwrap().as_ref().to_vec();
        let mut auth = [0u8; 16]; rng.fill(&mut auth).unwrap();
        let msg = br#"{"web_push":8030,"notification":{"title":"x","navigate":"https://a.example/"}}"#;
        let body = encrypt(&B64.encode(&ua_pub), &B64.encode(auth), msg).unwrap();
        // parse the RFC 8188 header
        let salt = &body[..16]; let rs = u32::from_be_bytes(body[16..20].try_into().unwrap()); let idlen = body[20] as usize;
        assert_eq!(rs, 4096); assert_eq!(idlen, 65);
        let as_pub = &body[21..21 + idlen]; let ct = &body[21 + idlen..];
        let sp = agreement::UnparsedPublicKey::new(&agreement::ECDH_P256, as_pub.to_vec());
        let (cek, nonce) = agreement::agree_ephemeral(ua_priv, &sp, |s| derive(s, &auth, &ua_pub, as_pub, salt)).unwrap().unwrap();
        let key = aead::LessSafeKey::new(aead::UnboundKey::new(&aead::AES_128_GCM, &cek).unwrap());
        let mut buf = ct.to_vec();
        let plain = key.open_in_place(aead::Nonce::assume_unique_for_key(nonce), aead::Aad::empty(), &mut buf).unwrap();
        assert_eq!(plain.last(), Some(&0x02)); assert_eq!(&plain[..plain.len() - 1], msg);
        assert_eq!(ct.len(), msg.len() + 1 + 16);
        // a flipped bit must fail the tag
        let mut bad = ct.to_vec(); bad[0] ^= 1;
        let key2 = aead::LessSafeKey::new(aead::UnboundKey::new(&aead::AES_128_GCM, &cek).unwrap());
        assert!(key2.open_in_place(aead::Nonce::assume_unique_for_key(nonce), aead::Aad::empty(), &mut bad).is_err());
    }

    #[test]
    fn encrypt_refuses_bad_subscriptions_and_big_payloads() {
        assert!(encrypt("not base64 !!", "AAAAAAAAAAAAAAAAAAAAAA", b"x").is_err());
        assert!(encrypt(&B64.encode([4u8; 64]), "AAAAAAAAAAAAAAAAAAAAAA", b"x").is_err());
        assert!(encrypt(&B64.encode([3u8; 65]), "AAAAAAAAAAAAAAAAAAAAAA", b"x").is_err());           // compressed/other prefix
        assert!(encrypt(&B64.encode([4u8; 65]), "AAAAAAAAAAAAAAAAAAAAAA", b"x").is_err());           // not on the curve
        let rng = SystemRandom::new();
        let k = agreement::EphemeralPrivateKey::generate(&agreement::ECDH_P256, &rng).unwrap();
        let p = B64.encode(k.compute_public_key().unwrap().as_ref());
        assert!(encrypt(&p, "AAAAAAAAAAAAAAAAAAAAAA", &vec![b'a'; MAX_PLAIN]).is_ok());
        assert!(encrypt(&p, "AAAAAAAAAAAAAAAAAAAAAA", &vec![b'a'; MAX_PLAIN + 1]).is_err());
        assert!(encrypt(&p, "short", b"x").is_err());
    }

    #[test]
    fn vapid_jwt_is_valid_es256_for_the_push_service_origin() {
        let rng = SystemRandom::new();
        let doc = ecdsa::EcdsaKeyPair::generate_pkcs8(&ecdsa::ECDSA_P256_SHA256_FIXED_SIGNING, &rng).unwrap();
        let v = Vapid::from_pkcs8(doc.as_ref(), "https://founderworkspace.anexomail.com").unwrap();
        assert_eq!(b(&v.public_b64()).len(), 65);
        let h = v.authorization("https://fcm.googleapis.com/fcm/send/abc", 1_000_000).unwrap();
        let t = h.strip_prefix("vapid t=").unwrap().split(", k=").next().unwrap();
        let parts: Vec<&str> = t.split('.').collect(); assert_eq!(parts.len(), 3);
        let claims: Value = serde_json::from_slice(&b(parts[1])).unwrap();
        assert_eq!(claims["aud"], "https://fcm.googleapis.com"); assert_eq!(claims["exp"], 1_000_000 + 43200); assert!(claims["exp"].as_i64().unwrap() - 1_000_000 <= 86400);
        assert_eq!(claims["sub"], "https://founderworkspace.anexomail.com");
        assert_eq!(serde_json::from_slice::<Value>(&b(parts[0])).unwrap(), json!({"typ": "JWT", "alg": "ES256"}));
        let sig = b(parts[2]); assert_eq!(sig.len(), 64);
        let pubk = ring::signature::UnparsedPublicKey::new(&ring::signature::ECDSA_P256_SHA256_FIXED, v.public.clone());
        assert!(pubk.verify(format!("{}.{}", parts[0], parts[1]).as_bytes(), &sig).is_ok());
        assert!(pubk.verify(format!("{}.{}x", parts[0], parts[1]).as_bytes(), &sig).is_err());
        assert!(h.ends_with(&format!("k={}", v.public_b64())));
    }

    #[test]
    fn vapid_key_file_is_created_once_and_reloaded() {
        let dir = std::env::temp_dir().join(format!("flare-test-{}", std::process::id())); let _ = std::fs::remove_dir_all(&dir);
        let path = dir.join("v.p8"); let p = path.to_str().unwrap();
        let a = Vapid::load_or_create(p, "https://x.example").unwrap(); let again = Vapid::load_or_create(p, "https://x.example").unwrap();
        assert_eq!(a.public_b64(), again.public_b64());
        #[cfg(unix)] { use std::os::unix::fs::PermissionsExt; assert_eq!(std::fs::metadata(&path).unwrap().permissions().mode() & 0o777, 0o400); }
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn origin_and_topic_and_payload_shapes() {
        assert_eq!(origin_of("https://web.push.apple.com/abc").as_deref(), Some("https://web.push.apple.com"));
        assert_eq!(origin_of("http://x/y"), None); assert_eq!(origin_of("https://u@x/y"), None); assert_eq!(origin_of("https:///y"), None);
        let t = topic_of("t3:abcd1234"); assert_eq!(t.len(), 24); assert!(t.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-' || c == b'_')); assert_eq!(t, topic_of("t3:abcd1234")); assert_ne!(t, topic_of("t3:abcd1235"));
        let p: Value = serde_json::from_slice(&payload("t3_begun", Some("9d8f"), None, "https://f.example").unwrap()).unwrap();
        assert_eq!(p["web_push"], 8030); assert!(!p["notification"]["title"].as_str().unwrap().is_empty()); assert_eq!(p["notification"]["navigate"], "https://f.example/#/settings"); assert_eq!(p["r"], "9d8f");
        let text = p.to_string(); assert!(!text.contains("key.rotate") && !text.contains("hash"));
        let c: Value = serde_json::from_slice(&payload("confirm", None, Some("tok"), "https://f.example").unwrap()).unwrap(); assert_eq!(c["t"], "tok");
        assert!(payload("unknown_kind", None, None, "https://f.example").is_none());
        for k in ["confirm", "test", "t3_begun", "t3_approved", "t3_cancelled"] { assert!(payload(k, None, None, "https://f.example").unwrap().len() < 600); }
    }
}
