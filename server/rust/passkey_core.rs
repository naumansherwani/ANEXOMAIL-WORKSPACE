// ============================================================================
// passkey_core.rs — PURE half of passkey / recovery-code login (B2, founder 21 Oct 2026). std-only, no I/O, no crates.
//
// Ported 1:1 from server/lib/webauthn.ts + server/routes/auth-passkey.ts (Bun stays as the fallback), with the loopholes closed:
//   * CBOR reader is bounds-checked and depth-limited (Bun's subarray() silently truncated; deep nesting could blow the stack)
//   * COSE EC key must be P-256 (crv = 1); unsupported kty/alg is refused
//   * challenge / credential-id shapes are validated before they ever touch a PostgREST filter (no filter injection)
//   * RP / origin allow-list is the same as Bun (anexomail.com / www over https, localhost for dev)
// The I/O half (sha256, ECDSA/RSA verify through `ring`, PostgREST, GoTrue) is passkey_glue.rs. This file is compiled by the
// installer with plain `rustc --test`, so it must stay std-only.
// ============================================================================
#![allow(dead_code)]

// ── base64url ───────────────────────────────────────────────────────────────
const B64: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

pub fn b64url_encode(data: &[u8]) -> String {
    let mut out = String::with_capacity((data.len() * 4 + 2) / 3);
    for chunk in data.chunks(3) {
        let b = [chunk[0], *chunk.get(1).unwrap_or(&0), *chunk.get(2).unwrap_or(&0)];
        let n = ((b[0] as u32) << 16) | ((b[1] as u32) << 8) | b[2] as u32;
        out.push(B64[(n >> 18) as usize & 63] as char);
        out.push(B64[(n >> 12) as usize & 63] as char);
        if chunk.len() > 1 {
            out.push(B64[(n >> 6) as usize & 63] as char);
        }
        if chunk.len() > 2 {
            out.push(B64[n as usize & 63] as char);
        }
    }
    out
}

/// Accepts base64url (padded or not) AND the standard alphabet, like Node's Buffer.from(…,"base64") did for the Bun code.
pub fn b64url_decode(s: &str) -> Result<Vec<u8>, &'static str> {
    let mut vals: Vec<u8> = Vec::with_capacity(s.len());
    for c in s.trim_end_matches('=').bytes() {
        let v = match c {
            b'A'..=b'Z' => c - b'A',
            b'a'..=b'z' => c - b'a' + 26,
            b'0'..=b'9' => c - b'0' + 52,
            b'-' | b'+' => 62,
            b'_' | b'/' => 63,
            _ => return Err("b64_alphabet"),
        };
        vals.push(v);
    }
    if vals.len() % 4 == 1 {
        return Err("b64_length");
    }
    let mut out = Vec::with_capacity(vals.len() * 3 / 4);
    for chunk in vals.chunks(4) {
        let mut n: u32 = 0;
        for (i, v) in chunk.iter().enumerate() {
            n |= (*v as u32) << (18 - 6 * i as u32);
        }
        out.push((n >> 16) as u8);
        if chunk.len() > 2 {
            out.push((n >> 8) as u8);
        }
        if chunk.len() > 3 {
            out.push(n as u8);
        }
    }
    Ok(out)
}

// ── shapes that are allowed to reach a database filter ──────────────────────
/// Challenge / credential ids are base64url. Anything else never reaches PostgREST.
pub fn is_b64url_token(s: &str, max: usize) -> bool {
    !s.is_empty() && s.len() <= max && s.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-' || c == b'_')
}

/// Percent-encode for a PostgREST query value (belt and braces next to is_b64url_token).
pub fn pct(s: &str) -> String {
    let mut o = String::with_capacity(s.len());
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || b == b'-' || b == b'_' || b == b'.' || b == b'~' {
            o.push(b as char);
        } else {
            o.push_str(&format!("%{:02X}", b));
        }
    }
    o
}

// ── identity / relying party ────────────────────────────────────────────────
/// Same rule as auth-passkey.ts `anexomailIdentity`: local part only, [a-z0-9._-], always @anexomail.com.
pub fn anexomail_identity(raw: &str) -> String {
    let t = raw.trim().to_lowercase();
    let before = match t.find('@') {
        Some(i) => &t[..i],
        None => &t[..],
    };
    let local: String = before.chars().filter(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || matches!(c, '.' | '_' | '-')).collect();
    if local.is_empty() { String::new() } else { format!("{local}@anexomail.com") }
}

#[derive(Debug, PartialEq, Clone)]
pub struct Rp {
    pub rp_id: String,
    pub origin: String,
}

/// `rpFromRequest`: Origin header (or APP_URL) -> relying party. Err(code) strings match the Bun error codes.
pub fn rp_from_origin(origin_header: Option<&str>, app_url: &str) -> Result<Rp, &'static str> {
    let raw = origin_header.filter(|s| !s.trim().is_empty()).unwrap_or(app_url);
    let origin = raw.trim().trim_end_matches('/').to_string();
    let (scheme, rest) = match origin.split_once("://") {
        Some((s, r)) => (s.to_lowercase(), r),
        None => return Err("passkey_origin_invalid"),
    };
    if scheme != "https" && scheme != "http" {
        return Err("passkey_origin_invalid");
    }
    let authority = rest.split(['/', '?', '#']).next().unwrap_or("");
    if authority.is_empty() || authority.contains('@') || authority.contains(' ') {
        return Err("passkey_origin_invalid");
    }
    let host = authority.split(':').next().unwrap_or("").to_lowercase();
    if host == "anexomail.com" || host == "www.anexomail.com" {
        if scheme != "https" {
            return Err("passkey_https_required");
        }
        return Ok(Rp { rp_id: "anexomail.com".into(), origin });
    }
    if host == "localhost" || host == "127.0.0.1" {
        return Ok(Rp { rp_id: host, origin });
    }
    Err("passkey_host_not_allowed")
}

// ── CBOR (subset WebAuthn uses) ─────────────────────────────────────────────
#[derive(Debug, PartialEq, Clone)]
pub enum Cbor {
    Uint(u64),
    Nint(i64), // value is -1 - n
    Bytes(Vec<u8>),
    Text(String),
    Array(Vec<Cbor>),
    Map(Vec<(Cbor, Cbor)>),
    Other,
}

const MAX_DEPTH: usize = 8;
const MAX_ITEMS: u64 = 256;

fn take<'a>(buf: &'a [u8], at: usize, n: usize) -> Result<&'a [u8], &'static str> {
    let end = at.checked_add(n).ok_or("cbor_truncated")?;
    buf.get(at..end).ok_or("cbor_truncated")
}

fn read(buf: &[u8], mut at: usize, depth: usize) -> Result<(Cbor, usize), &'static str> {
    if depth > MAX_DEPTH {
        return Err("cbor_depth");
    }
    let first = *buf.get(at).ok_or("cbor_truncated")?;
    at += 1;
    let major = first >> 5;
    let addl = first & 31;
    let len: u64 = match addl {
        0..=23 => addl as u64,
        24 => {
            let b = take(buf, at, 1)?;
            at += 1;
            b[0] as u64
        }
        25 => {
            let b = take(buf, at, 2)?;
            at += 2;
            u16::from_be_bytes([b[0], b[1]]) as u64
        }
        26 => {
            let b = take(buf, at, 4)?;
            at += 4;
            u32::from_be_bytes([b[0], b[1], b[2], b[3]]) as u64
        }
        _ => return Err("cbor_indefinite"),
    };
    match major {
        0 => Ok((Cbor::Uint(len), at)),
        1 => {
            if len > i64::MAX as u64 {
                return Err("cbor_int");
            }
            Ok((Cbor::Nint(-1 - len as i64), at))
        }
        2 | 3 => {
            let n = usize::try_from(len).map_err(|_| "cbor_len")?;
            let s = take(buf, at, n)?;
            let v = if major == 2 {
                Cbor::Bytes(s.to_vec())
            } else {
                Cbor::Text(String::from_utf8(s.to_vec()).map_err(|_| "cbor_utf8")?)
            };
            Ok((v, at + n))
        }
        4 => {
            if len > MAX_ITEMS {
                return Err("cbor_items");
            }
            let mut v = Vec::new();
            for _ in 0..len {
                let (item, next) = read(buf, at, depth + 1)?;
                v.push(item);
                at = next;
            }
            Ok((Cbor::Array(v), at))
        }
        5 => {
            if len > MAX_ITEMS {
                return Err("cbor_items");
            }
            let mut v = Vec::new();
            for _ in 0..len {
                let (k, n1) = read(buf, at, depth + 1)?;
                let (val, n2) = read(buf, n1, depth + 1)?;
                v.push((k, val));
                at = n2;
            }
            Ok((Cbor::Map(v), at))
        }
        6 => read(buf, at, depth + 1), // tag: value follows
        _ => Ok((Cbor::Other, at)),    // simple/float: WebAuthn maps never need them
    }
}

pub fn cbor_parse(buf: &[u8]) -> Result<(Cbor, usize), &'static str> {
    read(buf, 0, 0)
}

impl Cbor {
    fn int(&self) -> Option<i64> {
        match self {
            Cbor::Uint(u) => i64::try_from(*u).ok(),
            Cbor::Nint(n) => Some(*n),
            _ => None,
        }
    }
    pub fn get_int(&self, key: i64) -> Option<&Cbor> {
        if let Cbor::Map(m) = self {
            m.iter().find(|(k, _)| k.int() == Some(key)).map(|(_, v)| v)
        } else {
            None
        }
    }
    pub fn get_text(&self, key: &str) -> Option<&Cbor> {
        if let Cbor::Map(m) = self {
            m.iter().find(|(k, _)| matches!(k, Cbor::Text(t) if t == key)).map(|(_, v)| v)
        } else {
            None
        }
    }
    pub fn bytes(&self) -> Option<&[u8]> {
        if let Cbor::Bytes(b) = self { Some(b) } else { None }
    }
}

// ── COSE key -> public key ──────────────────────────────────────────────────
#[derive(Debug, PartialEq, Clone)]
pub enum PubKey {
    /// ES256: P-256 affine coordinates (32 bytes each)
    Ec { x: Vec<u8>, y: Vec<u8> },
    /// RS256: modulus / exponent, big-endian
    Rsa { n: Vec<u8>, e: Vec<u8> },
}

pub fn cose_to_pubkey(cose: &Cbor) -> Result<PubKey, &'static str> {
    let kty = cose.get_int(1).and_then(|v| v.int()).ok_or("cose_kty")?;
    match kty {
        2 => {
            // crv -1 must be 1 (P-256) — Bun did not check, a P-384 key would just fail at verify; refuse early instead
            if cose.get_int(-1).and_then(|v| v.int()) != Some(1) {
                return Err("cose_curve_unsupported");
            }
            let x = cose.get_int(-2).and_then(|v| v.bytes()).ok_or("cose_bytes")?;
            let y = cose.get_int(-3).and_then(|v| v.bytes()).ok_or("cose_bytes")?;
            if x.len() != 32 || y.len() != 32 {
                return Err("cose_ec_len");
            }
            Ok(PubKey::Ec { x: x.to_vec(), y: y.to_vec() })
        }
        3 => {
            let n = cose.get_int(-1).and_then(|v| v.bytes()).ok_or("cose_bytes")?;
            let e = cose.get_int(-2).and_then(|v| v.bytes()).ok_or("cose_bytes")?;
            if n.len() < 256 || n.len() > 1024 || e.is_empty() || e.len() > 8 {
                return Err("cose_rsa_len");
            }
            Ok(PubKey::Rsa { n: n.to_vec(), e: e.to_vec() })
        }
        _ => Err("cose_kty_unsupported"),
    }
}

/// SEC1 uncompressed point for `ring` (ECDSA_P256_SHA256_ASN1).
pub fn ec_point(x: &[u8], y: &[u8]) -> Vec<u8> {
    let mut v = Vec::with_capacity(65);
    v.push(0x04);
    v.extend_from_slice(x);
    v.extend_from_slice(y);
    v
}

fn der_len(out: &mut Vec<u8>, n: usize) {
    if n < 128 {
        out.push(n as u8);
    } else if n < 256 {
        out.extend_from_slice(&[0x81, n as u8]);
    } else {
        out.extend_from_slice(&[0x82, (n >> 8) as u8, n as u8]);
    }
}

fn der_uint(out: &mut Vec<u8>, be: &[u8]) {
    let mut s = be;
    while s.len() > 1 && s[0] == 0 {
        s = &s[1..];
    }
    let pad = !s.is_empty() && s[0] & 0x80 != 0;
    out.push(0x02);
    der_len(out, s.len() + pad as usize);
    if pad {
        out.push(0);
    }
    out.extend_from_slice(s);
}

/// DER `RSAPublicKey ::= SEQUENCE { n INTEGER, e INTEGER }` for `ring` (RSA_PKCS1_2048_8192_SHA256).
pub fn rsa_public_der(n: &[u8], e: &[u8]) -> Vec<u8> {
    let mut body = Vec::new();
    der_uint(&mut body, n);
    der_uint(&mut body, e);
    let mut out = vec![0x30];
    der_len(&mut out, body.len());
    out.extend_from_slice(&body);
    out
}

// ── authenticator data ──────────────────────────────────────────────────────
#[derive(Debug)]
pub struct AuthData {
    pub rp_hash: [u8; 32],
    pub flags: u8,
    pub sign_count: u32,
    pub credential_id: Option<Vec<u8>>,
    pub cose: Option<Cbor>,
}

/// Parses authData. `rp_hash_expected` is sha256(rpId) computed by the caller (core stays crate-free).
pub fn parse_auth_data(auth: &[u8], rp_hash_expected: &[u8; 32], need_attested: bool) -> Result<AuthData, &'static str> {
    if auth.len() < 37 {
        return Err("authData_short");
    }
    let mut rp_hash = [0u8; 32];
    rp_hash.copy_from_slice(&auth[..32]);
    if &rp_hash != rp_hash_expected {
        return Err("rpId_mismatch");
    }
    let flags = auth[32];
    let sign_count = u32::from_be_bytes([auth[33], auth[34], auth[35], auth[36]]);
    if flags & 0x01 == 0 {
        return Err("user_not_present");
    }
    if flags & 0x04 == 0 {
        return Err("user_not_verified");
    }
    if !need_attested {
        return Ok(AuthData { rp_hash, flags, sign_count, credential_id: None, cose: None });
    }
    if flags & 0x40 == 0 {
        return Err("attested_credential_missing");
    }
    // aaguid(16) at 37..53, credIdLen(2) at 53..55
    let l = take(auth, 53, 2)?;
    let cred_len = u16::from_be_bytes([l[0], l[1]]) as usize;
    if cred_len == 0 || cred_len > 1023 {
        return Err("credential_id_len");
    }
    let cred = take(auth, 55, cred_len)?.to_vec();
    let cose_raw = auth.get(55 + cred_len..).ok_or("cbor_truncated")?;
    let (cose, _) = cbor_parse(cose_raw)?;
    Ok(AuthData { rp_hash, flags, sign_count, credential_id: Some(cred), cose: Some(cose) })
}

/// attestationObject -> authData bytes (fmt/attStmt are ignored: attestation = "none").
pub fn auth_data_from_attestation(att: &[u8]) -> Result<Vec<u8>, &'static str> {
    let (map, _) = cbor_parse(att)?;
    map.get_text("authData").and_then(|v| v.bytes()).map(|b| b.to_vec()).ok_or("authData_missing")
}

// ── clientDataJSON checks (JSON parsed by the glue with serde_json) ─────────
pub fn check_client_data(
    typ: &str,
    challenge: &str,
    origin: &str,
    want_type: &str,
    want_challenge: &str,
    want_origin: &str,
) -> Result<(), &'static str> {
    if typ != want_type {
        return Err("clientData_type");
    }
    if challenge != want_challenge {
        return Err("clientData_challenge");
    }
    if origin != want_origin {
        return Err("clientData_origin");
    }
    Ok(())
}

/// Same clone-detection rule as Bun: only when both counters are non-zero.
pub fn check_sign_count(new: u32, stored: u32) -> Result<(), &'static str> {
    if new > 0 && stored > 0 && new <= stored { Err("sign_count_cloned") } else { Ok(()) }
}

/// Bytes the authenticator signed: authData || sha256(clientDataJSON).
pub fn signed_data(auth: &[u8], client_hash: &[u8; 32]) -> Vec<u8> {
    let mut v = Vec::with_capacity(auth.len() + 32);
    v.extend_from_slice(auth);
    v.extend_from_slice(client_hash);
    v
}

// ── session bookkeeping (same text rules as routes/auth.ts) ─────────────────
pub fn is_server_ua(ua: &str) -> bool {
    let u = ua.trim().to_lowercase();
    if u.is_empty() {
        return true;
    }
    u.starts_with("bun/")
        || u.starts_with("node/")
        || u.starts_with("undici")
        || u.starts_with("curl/")
        || u.starts_with("wget/")
        || u.starts_with("python")
        || u.starts_with("go-http")
        || u.starts_with("got/")
        || u.contains("healthcheck")
}

/// -> (browser, device)
pub fn describe_ua(ua: &str) -> (String, String) {
    let raw = ua.trim();
    let u = raw.to_lowercase();
    let browser = if u.contains("edg/") || u.contains("edgios") {
        "Edge".to_string()
    } else if u.contains("opr/") || u.contains("opera") {
        "Opera".to_string()
    } else if u.contains("firefox/") || u.contains("fxios") {
        "Firefox".to_string()
    } else if u.contains("crios") || (u.contains("chrome/") && !u.contains("edg/")) {
        "Chrome".to_string()
    } else if u.contains("safari/") && !u.contains("chrome") && !u.contains("crios") {
        "Safari".to_string()
    } else if !raw.is_empty() && !u.contains("mozilla") {
        raw.chars().take(40).collect()
    } else {
        "Browser".to_string()
    };
    let device = if u.contains("iphone") {
        "iPhone"
    } else if u.contains("ipad") {
        "iPad"
    } else if u.contains("android") {
        "Android"
    } else if u.contains("mac os") || u.contains("macintosh") {
        "Mac"
    } else if u.contains("windows") {
        "Windows"
    } else if u.contains("cros") {
        "Chromebook"
    } else if u.contains("linux") {
        "Linux"
    } else {
        "Computer"
    };
    (browser, device.to_string())
}

pub fn client_ip(xff: &str, real: &str) -> Option<String> {
    let first = xff.split(',').next().unwrap_or("").trim();
    let raw = if !first.is_empty() { first } else { real.trim() };
    let raw = raw.trim_start_matches("::ffff:");
    if raw.is_empty() || raw == "127.0.0.1" || raw == "::1" || raw == "localhost" {
        return None;
    }
    Some(raw.chars().take(80).collect())
}

/// `(^|[._-])test@` — test accounts never get the passkey banner / gate (founder 21 Oct 2026).
pub fn is_test_account(email: &str) -> bool {
    let e = email.to_lowercase();
    let Some(i) = e.find('@') else { return false };
    let local = &e[..i];
    // regex matches "test@" anywhere, so the local part must END with "test" and be preceded by start or [._-]
    if !local.ends_with("test") {
        return false;
    }
    let pre = &local[..local.len() - 4];
    pre.is_empty() || pre.ends_with('.') || pre.ends_with('_') || pre.ends_with('-')
}

pub fn clean_label(raw: &str) -> String {
    let kept: String = raw
        .chars()
        .filter(|c| c.is_alphanumeric() || *c == '_' || matches!(c, ' ' | '.' | ',' | '\'' | '(' | ')' | '-'))
        .collect();
    kept.trim().chars().take(60).collect()
}


/// Unix seconds -> "YYYY-MM-DDTHH:MM:SSZ" (PostgREST timestamptz filter / insert value). Howard Hinnant civil-from-days.
pub fn iso_utc(secs: u64) -> String {
    let days = (secs / 86_400) as i64;
    let rem = secs % 86_400;
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z", y, m, d, rem / 3600, (rem % 3600) / 60, rem % 60)
}

// ═════════════════════════════════════════════════════════════════════════════
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn b64_roundtrip_and_node_compat() {
        for n in 0..40usize {
            let data: Vec<u8> = (0..n as u8).map(|i| i.wrapping_mul(37).wrapping_add(11)).collect();
            assert_eq!(b64url_decode(&b64url_encode(&data)).unwrap(), data);
        }
        assert_eq!(b64url_encode(&[0xfb, 0xff]), "-_8");
        assert_eq!(b64url_decode("-_8").unwrap(), vec![0xfb, 0xff]);
        assert_eq!(b64url_decode("+/8=").unwrap(), vec![0xfb, 0xff]); // standard alphabet + padding also fine (Node did)
        assert!(b64url_decode("a").is_err());
        assert!(b64url_decode("ab$d").is_err());
    }

    #[test]
    fn token_shape_blocks_filter_injection() {
        assert!(is_b64url_token("abcDEF_-123", 128));
        assert!(!is_b64url_token("", 128));
        assert!(!is_b64url_token("a,b", 128));
        assert!(!is_b64url_token("x)&or=(id.gt.0", 128));
        assert!(!is_b64url_token(&"a".repeat(129), 128));
        assert_eq!(pct("a b&c=d"), "a%20b%26c%3Dd");
    }

    #[test]
    fn identity_matches_bun() {
        assert_eq!(anexomail_identity("  Nauman.Sherwani@Gmail.com "), "nauman.sherwani@anexomail.com");
        assert_eq!(anexomail_identity("A B+c"), "abc@anexomail.com");
        assert_eq!(anexomail_identity("@x.com"), "");
        assert_eq!(anexomail_identity("  "), "");
        assert_eq!(anexomail_identity("basic.test"), "basic.test@anexomail.com");
    }

    #[test]
    fn rp_rules() {
        let a = "https://anexomail.com";
        assert_eq!(rp_from_origin(Some("https://anexomail.com/"), a).unwrap(), Rp { rp_id: "anexomail.com".into(), origin: "https://anexomail.com".into() });
        assert_eq!(rp_from_origin(Some("https://www.anexomail.com"), a).unwrap().rp_id, "anexomail.com");
        assert_eq!(rp_from_origin(None, a).unwrap().origin, a);
        assert_eq!(rp_from_origin(Some(""), a).unwrap().origin, a);
        assert_eq!(rp_from_origin(Some("http://anexomail.com"), a), Err("passkey_https_required"));
        assert_eq!(rp_from_origin(Some("https://evil.com"), a), Err("passkey_host_not_allowed"));
        assert_eq!(rp_from_origin(Some("https://anexomail.com.evil.com"), a), Err("passkey_host_not_allowed"));
        assert_eq!(rp_from_origin(Some("https://anexomail.com@evil.com"), a), Err("passkey_origin_invalid"));
        assert_eq!(rp_from_origin(Some("nonsense"), a), Err("passkey_origin_invalid"));
        assert_eq!(rp_from_origin(Some("ftp://anexomail.com"), a), Err("passkey_origin_invalid"));
        let l = rp_from_origin(Some("http://localhost:3000"), a).unwrap();
        assert_eq!((l.rp_id.as_str(), l.origin.as_str()), ("localhost", "http://localhost:3000"));
    }

    // attestationObject captured from a real "none" registration shape: {fmt:"none", attStmt:{}, authData: …}
    fn sample_cose() -> Vec<u8> {
        // {1:2, 3:-7, -1:1, -2:x(32), -3:y(32)}
        let mut v = vec![0xa5, 0x01, 0x02, 0x03, 0x26, 0x20, 0x01, 0x21, 0x58, 0x20];
        v.extend((0..32u8).map(|i| i + 1));
        v.extend_from_slice(&[0x22, 0x58, 0x20]);
        v.extend((0..32u8).map(|i| 100 + i));
        v
    }

    fn sample_auth(flags: u8, count: u32, cred: &[u8], with_key: bool) -> Vec<u8> {
        let mut a = vec![7u8; 32];
        a.push(flags);
        a.extend_from_slice(&count.to_be_bytes());
        if with_key {
            a.extend_from_slice(&[0u8; 16]);
            a.extend_from_slice(&(cred.len() as u16).to_be_bytes());
            a.extend_from_slice(cred);
            a.extend_from_slice(&sample_cose());
        }
        a
    }

    #[test]
    fn cose_ec_key() {
        let (c, used) = cbor_parse(&sample_cose()).unwrap();
        assert_eq!(used, sample_cose().len());
        match cose_to_pubkey(&c).unwrap() {
            PubKey::Ec { x, y } => {
                assert_eq!(x[0], 1);
                assert_eq!(y[0], 100);
                assert_eq!(ec_point(&x, &y).len(), 65);
            }
            _ => panic!("expected EC"),
        }
    }

    #[test]
    fn cose_rejects_other_curves_and_short_keys() {
        let mut other = sample_cose();
        other[6] = 0x02; // crv = 2 (P-384)
        let (c2, _) = cbor_parse(&other).unwrap();
        assert_eq!(cose_to_pubkey(&c2), Err("cose_curve_unsupported"));
        let (okmap, _) = cbor_parse(&[0xa1, 0x01, 0x04]).unwrap(); // kty 4 = symmetric
        assert_eq!(cose_to_pubkey(&okmap), Err("cose_kty_unsupported"));
    }

    #[test]
    fn cbor_is_bounds_checked() {
        assert_eq!(cbor_parse(&[]), Err("cbor_truncated"));
        assert_eq!(cbor_parse(&[0x58]), Err("cbor_truncated"));
        assert_eq!(cbor_parse(&[0x58, 0x05, 1, 2]), Err("cbor_truncated")); // bytes shorter than declared
        assert_eq!(cbor_parse(&[0x5f]), Err("cbor_indefinite"));
        assert_eq!(cbor_parse(&[0x1b, 0, 0, 0, 0, 0, 0, 0, 1]), Err("cbor_indefinite")); // 8-byte length refused
        // 300-deep nested arrays must not blow the stack
        let deep = vec![0x81u8; 300];
        assert_eq!(cbor_parse(&deep), Err("cbor_depth"));
        // huge declared array
        assert_eq!(cbor_parse(&[0x99, 0xff, 0xff]), Err("cbor_items"));
    }

    #[test]
    fn auth_data_checks() {
        let h = [7u8; 32];
        let cred = [9u8; 20];
        // registration: UP|UV|AT = 0x45
        let reg = sample_auth(0x45, 0, &cred, true);
        let ad = parse_auth_data(&reg, &h, true).unwrap();
        assert_eq!(ad.credential_id.unwrap(), cred.to_vec());
        assert!(matches!(cose_to_pubkey(&ad.cose.unwrap()), Ok(PubKey::Ec { .. })));
        // wrong rp
        assert_eq!(parse_auth_data(&reg, &[8u8; 32], true).unwrap_err(), "rpId_mismatch");
        // UP missing / UV missing / AT missing
        assert_eq!(parse_auth_data(&sample_auth(0x44, 0, &cred, true), &h, true).unwrap_err(), "user_not_present");
        assert_eq!(parse_auth_data(&sample_auth(0x41, 0, &cred, true), &h, true).unwrap_err(), "user_not_verified");
        assert_eq!(parse_auth_data(&sample_auth(0x05, 0, &cred, false), &h, true).unwrap_err(), "attested_credential_missing");
        // short
        assert_eq!(parse_auth_data(&[0u8; 36], &h, false).unwrap_err(), "authData_short");
        // cred id longer than the buffer
        let mut bad = sample_auth(0x45, 0, &cred, true);
        bad[53] = 0x03;
        bad[54] = 0xe0; // 992 bytes declared
        assert_eq!(parse_auth_data(&bad, &h, true).unwrap_err(), "cbor_truncated");
        // assertion: no attested data needed
        assert_eq!(parse_auth_data(&sample_auth(0x05, 41, &cred, false), &h, false).unwrap().sign_count, 41);
    }

    #[test]
    fn attestation_object() {
        // {"fmt":"none","attStmt":{},"authData": <bytes>}
        let auth = sample_auth(0x45, 0, &[1u8; 16], true);
        let mut att = vec![0xa3, 0x63, b'f', b'm', b't', 0x64, b'n', b'o', b'n', b'e', 0x67];
        att.extend_from_slice(b"attStmt");
        att.push(0xa0);
        att.push(0x68);
        att.extend_from_slice(b"authData");
        att.push(0x59);
        att.extend_from_slice(&(auth.len() as u16).to_be_bytes());
        att.extend_from_slice(&auth);
        assert_eq!(auth_data_from_attestation(&att).unwrap(), auth);
        assert_eq!(auth_data_from_attestation(&[0xa0]), Err("authData_missing"));
    }

    #[test]
    fn client_data_and_counts() {
        assert!(check_client_data("webauthn.get", "c", "https://anexomail.com", "webauthn.get", "c", "https://anexomail.com").is_ok());
        assert_eq!(check_client_data("webauthn.create", "c", "o", "webauthn.get", "c", "o"), Err("clientData_type"));
        assert_eq!(check_client_data("webauthn.get", "x", "o", "webauthn.get", "c", "o"), Err("clientData_challenge"));
        assert_eq!(check_client_data("webauthn.get", "c", "evil", "webauthn.get", "c", "o"), Err("clientData_origin"));
        assert!(check_sign_count(0, 0).is_ok());
        assert!(check_sign_count(5, 0).is_ok());
        assert!(check_sign_count(0, 9).is_ok());
        assert!(check_sign_count(6, 5).is_ok());
        assert_eq!(check_sign_count(5, 5), Err("sign_count_cloned"));
        assert_eq!(check_sign_count(4, 5), Err("sign_count_cloned"));
    }

    #[test]
    fn rsa_der_shape() {
        let n = vec![0xc3u8; 256]; // high bit set => needs 0x00 pad
        let e = vec![0x01, 0x00, 0x01];
        let d = rsa_public_der(&n, &e);
        assert_eq!(d[0], 0x30);
        assert_eq!(&d[1..4], &[0x82, 0x01, 0x0a]); // 266 bytes body
        assert_eq!(&d[4..9], &[0x02, 0x82, 0x01, 0x01, 0x00]);
        assert_eq!(&d[d.len() - 5..], &[0x02, 0x03, 0x01, 0x00, 0x01]);
        // leading zeros stripped, no pad when high bit clear
        let d2 = rsa_public_der(&[0, 0, 0x7f, 0x01], &[0x03]);
        assert_eq!(d2, vec![0x30, 0x07, 0x02, 0x02, 0x7f, 0x01, 0x02, 0x01, 0x03]);
    }

    #[test]
    fn ua_rules_match_auth_ts() {
        // expected values generated from server/routes/auth.ts describeUserAgent / isServerUserAgent
        let chrome_win = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
        let safari_iphone = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1";
        let edge_mac = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0";
        let firefox_linux = "Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0";
        let chrome_android = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36";
        assert_eq!(describe_ua(chrome_win), ("Chrome".into(), "Windows".into()));
        assert_eq!(describe_ua(safari_iphone), ("Safari".into(), "iPhone".into()));
        assert_eq!(describe_ua(edge_mac), ("Edge".into(), "Mac".into()));
        assert_eq!(describe_ua(firefox_linux), ("Firefox".into(), "Linux".into()));
        assert_eq!(describe_ua(chrome_android), ("Chrome".into(), "Android".into()));
        assert_eq!(describe_ua("SomeApp/1.0"), ("SomeApp/1.0".into(), "Computer".into()));
        assert_eq!(describe_ua(""), ("Browser".into(), "Computer".into()));
        assert!(is_server_ua(""));
        assert!(is_server_ua("curl/8.5.0"));
        assert!(is_server_ua("Bun/1.4.0"));
        assert!(is_server_ua("kube-healthcheck"));
        assert!(!is_server_ua(chrome_win));
        assert_eq!(client_ip("1.2.3.4, 10.0.0.1", ""), Some("1.2.3.4".into()));
        assert_eq!(client_ip("", "::ffff:5.6.7.8"), Some("5.6.7.8".into()));
        assert_eq!(client_ip("127.0.0.1", ""), None);
        assert_eq!(client_ip("", ""), None);
    }

    #[test]
    fn test_account_regex() {
        assert!(is_test_account("basic.test@anexomail.com"));
        assert!(is_test_account("test@anexomail.com"));
        assert!(is_test_account("g38b-test@anexomail.com"));
        assert!(is_test_account("a_test@x.com"));
        assert!(is_test_account("BUSINESS_PRO.TEST@anexomail.com"));
        assert!(!is_test_account("contest@anexomail.com"));
        assert!(!is_test_account("pro.buyer@anexomail.com"));
        assert!(!is_test_account("testing@anexomail.com"));
        assert!(!is_test_account("nobody"));
    }

    #[test]
    fn iso_dates() {
        assert_eq!(iso_utc(0), "1970-01-01T00:00:00Z");
        assert_eq!(iso_utc(951_782_400), "2000-02-29T00:00:00Z"); // leap day
        assert_eq!(iso_utc(1_792_543_160), "2026-10-21T00:39:20Z");
        assert_eq!(iso_utc(4_102_444_800), "2100-01-01T00:00:00Z");
    }

    #[test]
    fn label_clean() {
        assert_eq!(clean_label("  Chrome on <Windows>!  "), "Chrome on Windows");
        assert_eq!(clean_label(&"a".repeat(90)).len(), 60);
    }
}
