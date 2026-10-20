// ANEXOMAIL — Rust :3200: Supabase access-token (ES256) LOCAL verify. 21 Oct 2026 (B1, founder 04:21 "sab ka sab, lamba time intact").
//
// Kyun: pehle har request par GoTrue `/auth/v1/user` (network) — 429/5xx par user sign-out (login loop). Ab token ki signature
// aur expiry yahin, memory mein, microseconds mein. Revocation (logout / device revoke) ka sach alag: `auth.sessions` row
// (`auth_session_alive`, E53) — yeh file sirf crypto + claims jaanchti hai, network nahi.
//
// Technology: ES256 = ECDSA P-256 + SHA-256 (JWS, RFC 7518). Verify `ring` se (rustls ke saath pehle se tree mein, audited,
// constant-time). JWKS = Supabase `/auth/v1/.well-known/jwks.json` (RFC 7517). Koi doosri crypto library nahi.
//
// Faisle:
//   * UnknownKid / UnsupportedAlg  => caller GoTrue par gir jaye (key rotation / naya format — hum "nahi" nahi kehte).
//   * Expired / BadSignature / Malformed / WrongAudience / WrongIssuer => definitive "nahi" (401), network nahi.
//   * `alg: none` / HS256 kabhi qubool nahi (algorithm-confusion hamla band): sirf ES256.
use base64::Engine;
use ring::signature::{UnparsedPublicKey, ECDSA_P256_SHA256_FIXED};
use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct Jwk {
    pub kid: String,
    /// Uncompressed SEC1 point: 0x04 || X(32) || Y(32)
    pub point: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Claims {
    pub sub: String,
    pub email: String,
    pub session_id: Option<String>,
    pub exp: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub enum JwtErr {
    Malformed,
    UnsupportedAlg,
    UnknownKid,
    BadSignature,
    Expired,
    NotYetValid,
    WrongAudience,
    WrongIssuer,
}

impl JwtErr {
    /// true => caller GoTrue se poochhe (hum faysla nahi kar sakte); false => seedha reject.
    pub fn should_fallback(&self) -> bool {
        matches!(self, JwtErr::UnknownKid | JwtErr::UnsupportedAlg)
    }
}

fn b64(s: &str) -> Option<Vec<u8>> {
    base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(s.trim_end_matches('=')).ok()
}

/// Supabase JWKS JSON -> sirf EC P-256 (ES256) keys.
pub fn parse_jwks(doc: &Value) -> Vec<Jwk> {
    let mut out = Vec::new();
    for k in doc.get("keys").and_then(|v| v.as_array()).into_iter().flatten() {
        if k.get("kty").and_then(|v| v.as_str()) != Some("EC") || k.get("crv").and_then(|v| v.as_str()) != Some("P-256") {
            continue;
        }
        let (Some(kid), Some(x), Some(y)) = (
            k.get("kid").and_then(|v| v.as_str()),
            k.get("x").and_then(|v| v.as_str()).and_then(b64),
            k.get("y").and_then(|v| v.as_str()).and_then(b64),
        ) else {
            continue;
        };
        if x.len() != 32 || y.len() != 32 {
            continue;
        }
        let mut point = Vec::with_capacity(65);
        point.push(0x04);
        point.extend_from_slice(&x);
        point.extend_from_slice(&y);
        out.push(Jwk { kid: kid.to_string(), point });
    }
    out
}

/// Token ke header se `kid` (jaldi — JWKS refresh ka faisla karne ke liye).
pub fn token_kid(token: &str) -> Option<String> {
    let h = b64(token.split('.').next()?)?;
    let v: Value = serde_json::from_slice(&h).ok()?;
    v.get("kid").and_then(|k| k.as_str()).map(|s| s.to_string())
}

/// `issuer_prefix` = `<SUPABASE_URL>/auth/v1` (khali ho to iss ki jaanch nahi). `now` = unix seconds.
pub fn verify(token: &str, jwks: &[Jwk], issuer_prefix: &str, now: i64) -> Result<Claims, JwtErr> {
    let mut parts = token.split('.');
    let (Some(h), Some(p), Some(s), None) = (parts.next(), parts.next(), parts.next(), parts.next()) else {
        return Err(JwtErr::Malformed);
    };
    let header: Value = serde_json::from_slice(&b64(h).ok_or(JwtErr::Malformed)?).map_err(|_| JwtErr::Malformed)?;
    if header.get("alg").and_then(|v| v.as_str()) != Some("ES256") {
        return Err(JwtErr::UnsupportedAlg);
    }
    let kid = header.get("kid").and_then(|v| v.as_str()).ok_or(JwtErr::UnknownKid)?;
    let key = jwks.iter().find(|k| k.kid == kid).ok_or(JwtErr::UnknownKid)?;
    let sig = b64(s).ok_or(JwtErr::Malformed)?;
    let signing_input = &token[..h.len() + 1 + p.len()];
    UnparsedPublicKey::new(&ECDSA_P256_SHA256_FIXED, &key.point)
        .verify(signing_input.as_bytes(), &sig)
        .map_err(|_| JwtErr::BadSignature)?;

    let c: Value = serde_json::from_slice(&b64(p).ok_or(JwtErr::Malformed)?).map_err(|_| JwtErr::Malformed)?;
    let exp = c.get("exp").and_then(|v| v.as_i64()).ok_or(JwtErr::Malformed)?;
    if now > exp + 5 {
        return Err(JwtErr::Expired);
    }
    if let Some(nbf) = c.get("nbf").and_then(|v| v.as_i64()) {
        if now + 5 < nbf {
            return Err(JwtErr::NotYetValid);
        }
    }
    let aud_ok = match c.get("aud") {
        Some(Value::String(a)) => a == "authenticated",
        Some(Value::Array(a)) => a.iter().any(|x| x.as_str() == Some("authenticated")),
        _ => false,
    };
    if !aud_ok {
        return Err(JwtErr::WrongAudience);
    }
    if !issuer_prefix.is_empty() {
        let iss = c.get("iss").and_then(|v| v.as_str()).unwrap_or("");
        if !iss.starts_with(issuer_prefix) {
            return Err(JwtErr::WrongIssuer);
        }
    }
    let sub = c.get("sub").and_then(|v| v.as_str()).filter(|s| !s.is_empty()).ok_or(JwtErr::Malformed)?.to_string();
    Ok(Claims {
        sub,
        email: c.get("email").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        session_id: c.get("session_id").and_then(|v| v.as_str()).map(|s| s.to_string()),
        exp,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use ring::rand::SystemRandom;
    use ring::signature::{EcdsaKeyPair, KeyPair, ECDSA_P256_SHA256_FIXED_SIGNING};
    use serde_json::json;

    fn enc(v: &[u8]) -> String {
        base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(v)
    }
    fn keypair() -> (EcdsaKeyPair, Jwk) {
        let rng = SystemRandom::new();
        let pkcs8 = EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, &rng).unwrap();
        let kp = EcdsaKeyPair::from_pkcs8(&ECDSA_P256_SHA256_FIXED_SIGNING, pkcs8.as_ref(), &rng).unwrap();
        let point = kp.public_key().as_ref().to_vec();
        (kp, Jwk { kid: "k1".into(), point })
    }
    fn sign(kp: &EcdsaKeyPair, header: Value, claims: Value) -> String {
        let h = enc(header.to_string().as_bytes());
        let p = enc(claims.to_string().as_bytes());
        let input = format!("{h}.{p}");
        let sig = kp.sign(&SystemRandom::new(), input.as_bytes()).unwrap();
        format!("{input}.{}", enc(sig.as_ref()))
    }
    fn good_claims(exp: i64) -> Value {
        json!({"sub":"u-1","email":"a@anexomail.com","aud":"authenticated","exp":exp,"iss":"https://x.supabase.co/auth/v1","session_id":"s-1"})
    }
    const ISS: &str = "https://x.supabase.co/auth/v1";

    #[test]
    fn valid_token_passes() {
        let (kp, jwk) = keypair();
        let t = sign(&kp, json!({"alg":"ES256","kid":"k1","typ":"JWT"}), good_claims(2_000_000_000));
        let c = verify(&t, &[jwk], ISS, 1_900_000_000).unwrap();
        assert_eq!((c.sub.as_str(), c.email.as_str(), c.session_id.as_deref()), ("u-1", "a@anexomail.com", Some("s-1")));
    }
    #[test]
    fn expired_rejected_not_fallback() {
        let (kp, jwk) = keypair();
        let t = sign(&kp, json!({"alg":"ES256","kid":"k1"}), good_claims(1_000));
        let e = verify(&t, &[jwk], ISS, 2_000).unwrap_err();
        assert_eq!(e, JwtErr::Expired);
        assert!(!e.should_fallback());
    }
    #[test]
    fn tampered_payload_bad_signature() {
        let (kp, jwk) = keypair();
        let t = sign(&kp, json!({"alg":"ES256","kid":"k1"}), good_claims(2_000_000_000));
        let mut parts: Vec<&str> = t.split('.').collect();
        let evil = enc(good_claims(2_000_000_000).to_string().replace("u-1", "u-2").as_bytes());
        parts[1] = &evil;
        assert_eq!(verify(&parts.join("."), &[jwk], ISS, 1).unwrap_err(), JwtErr::BadSignature);
    }
    #[test]
    fn wrong_key_rejected() {
        let (kp, _) = keypair();
        let (_, other) = keypair();
        let t = sign(&kp, json!({"alg":"ES256","kid":"k1"}), good_claims(2_000_000_000));
        assert_eq!(verify(&t, &[other], ISS, 1).unwrap_err(), JwtErr::BadSignature);
    }
    #[test]
    fn unknown_kid_falls_back() {
        let (kp, jwk) = keypair();
        let t = sign(&kp, json!({"alg":"ES256","kid":"rotated"}), good_claims(2_000_000_000));
        let e = verify(&t, &[jwk], ISS, 1).unwrap_err();
        assert_eq!(e, JwtErr::UnknownKid);
        assert!(e.should_fallback());
    }
    #[test]
    fn alg_none_and_hs256_never_accepted() {
        let (_, jwk) = keypair();
        let none = format!("{}.{}.", enc(br#"{"alg":"none","kid":"k1"}"#), enc(good_claims(2_000_000_000).to_string().as_bytes()));
        assert_eq!(verify(&none, &[jwk.clone()], ISS, 1).unwrap_err(), JwtErr::UnsupportedAlg);
        let hs = format!("{}.{}.{}", enc(br#"{"alg":"HS256","kid":"k1"}"#), enc(good_claims(2_000_000_000).to_string().as_bytes()), enc(b"x"));
        assert_eq!(verify(&hs, &[jwk], ISS, 1).unwrap_err(), JwtErr::UnsupportedAlg);
    }
    #[test]
    fn audience_and_issuer_checked() {
        let (kp, jwk) = keypair();
        let mut c = good_claims(2_000_000_000);
        c["aud"] = json!("anon");
        let t = sign(&kp, json!({"alg":"ES256","kid":"k1"}), c);
        assert_eq!(verify(&t, &[jwk.clone()], ISS, 1).unwrap_err(), JwtErr::WrongAudience);
        let mut c2 = good_claims(2_000_000_000);
        c2["iss"] = json!("https://evil.example/auth/v1");
        let t2 = sign(&kp, json!({"alg":"ES256","kid":"k1"}), c2);
        assert_eq!(verify(&t2, &[jwk], ISS, 1).unwrap_err(), JwtErr::WrongIssuer);
    }
    #[test]
    fn malformed_shapes() {
        for t in ["", "a", "a.b", "a.b.c.d", "!!.!!.!!"] {
            assert!(matches!(verify(t, &[], ISS, 1), Err(JwtErr::Malformed)), "{t}");
        }
    }
    #[test]
    fn jwks_parse_roundtrip() {
        let (_, jwk) = keypair();
        let doc = json!({"keys":[{"kty":"EC","crv":"P-256","kid":"k1","x":enc(&jwk.point[1..33]),"y":enc(&jwk.point[33..65])},{"kty":"RSA","kid":"r"}]});
        let ks = parse_jwks(&doc);
        assert_eq!(ks.len(), 1);
        assert_eq!(ks[0], jwk);
    }
}
