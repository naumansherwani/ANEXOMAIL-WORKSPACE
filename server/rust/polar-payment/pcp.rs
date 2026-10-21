// ============================================================================
// pcp.rs — POLAR CONTROL PLANE core (B6a, 21 Oct 2026). Pure logic, no I/O
// beyond two tiny file reads. Webhook / WAL / worker path se iska koi taalluq
// NAHI — yeh sirf engine ke andar ke (internal) raaston ki muhar check karta hai.
//
// MUHAR (signed request):
//   x-pcp-ts    = unix seconds
//   x-pcp-nonce = 16..64 chars [A-Za-z0-9_-]  (har request naya)
//   x-pcp-sig   = hex( HMAC-SHA256(key, "v1\nMETHOD\nPATH\nTS\nNONCE\nsha256hex(body)") )
// Qaide: 60 s ki khidki, nonce dobara nahi chalta (replay band), constant-time
// compare, key na ho / chhoti ho to FAIL-CLOSED (kuch bhi nahi chalta).
// ============================================================================
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::Mutex;
use subtle::ConstantTimeEq;

type HmacSha256 = Hmac<Sha256>;

pub const WINDOW_SECS: i64 = 60;
pub const MIN_KEY_BYTES: usize = 32;
const MAX_NONCES: usize = 20_000;

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Reject {
    NoKey,
    Missing,
    BadTs,
    Stale,
    BadNonce,
    BadSig,
    Replay,
}

impl Reject {
    pub fn code(&self) -> &'static str {
        match self {
            Reject::NoKey => "control_plane_key_missing",
            Reject::Missing => "signature_required",
            Reject::BadTs => "bad_timestamp",
            Reject::Stale => "stale_request",
            Reject::BadNonce => "bad_nonce",
            Reject::BadSig => "bad_signature",
            Reject::Replay => "replayed_request",
        }
    }
    /// 503 = hamari taraf ka masla (key nahi); baaqi 401.
    pub fn http(&self) -> u16 {
        match self {
            Reject::NoKey => 503,
            _ => 401,
        }
    }
}

pub fn body_sha256_hex(body: &[u8]) -> String {
    hex::encode(Sha256::digest(body))
}

pub fn canonical(method: &str, path: &str, ts: i64, nonce: &str, body: &[u8]) -> String {
    format!(
        "v1\n{}\n{}\n{}\n{}\n{}",
        method.to_ascii_uppercase(),
        path,
        ts,
        nonce,
        body_sha256_hex(body)
    )
}

pub fn sign(key: &[u8], method: &str, path: &str, ts: i64, nonce: &str, body: &[u8]) -> String {
    let mut mac = HmacSha256::new_from_slice(key).expect("hmac accepts any key length");
    mac.update(canonical(method, path, ts, nonce, body).as_bytes());
    hex::encode(mac.finalize().into_bytes())
}

/// Nonce yaad-dasht: har nonce window ke dauraan sirf ek dafa.
pub struct Nonces {
    seen: Mutex<HashMap<String, i64>>, // nonce -> expiry (unix secs)
}

impl Nonces {
    pub fn new() -> Self {
        Self { seen: Mutex::new(HashMap::new()) }
    }

    /// true = naya (record ho gaya); false = pehle dekha ja chuka (replay).
    pub fn claim(&self, nonce: &str, now: i64) -> bool {
        let mut m = match self.seen.lock() {
            Ok(g) => g,
            Err(p) => p.into_inner(),
        };
        if m.len() >= MAX_NONCES {
            m.retain(|_, exp| *exp > now);
            if m.len() >= MAX_NONCES {
                // memory-bomb se bachao: sab se purani aadhi nikalo (khidki 60 s hi hai)
                let mut v: Vec<(String, i64)> = m.drain().collect();
                v.sort_by_key(|(_, e)| *e);
                let keep = v.split_off(v.len() / 2);
                m.extend(keep);
            }
        }
        match m.get(nonce) {
            Some(exp) if *exp > now => false,
            _ => {
                m.insert(nonce.to_string(), now + WINDOW_SECS * 2);
                true
            }
        }
    }
}

fn nonce_ok(n: &str) -> bool {
    (16..=64).contains(&n.len())
        && n.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
}

pub struct SigParts<'a> {
    pub ts: Option<&'a str>,
    pub nonce: Option<&'a str>,
    pub sig: Option<&'a str>,
}

/// Poori jaanch. Nonce AAKHRI mein claim hota hai (galat muhar nonce nahi jalati).
pub fn verify(
    key: &[u8],
    method: &str,
    path: &str,
    parts: &SigParts,
    body: &[u8],
    now: i64,
    nonces: &Nonces,
) -> Result<(), Reject> {
    if key.len() < MIN_KEY_BYTES {
        return Err(Reject::NoKey);
    }
    let (Some(ts_s), Some(nonce), Some(sig)) = (parts.ts, parts.nonce, parts.sig) else {
        return Err(Reject::Missing);
    };
    let ts: i64 = ts_s.trim().parse().map_err(|_| Reject::BadTs)?;
    if (now - ts).abs() > WINDOW_SECS {
        return Err(Reject::Stale);
    }
    if !nonce_ok(nonce) {
        return Err(Reject::BadNonce);
    }
    let want = sign(key, method, path, ts, nonce, body);
    let got = sig.trim().to_ascii_lowercase();
    if want.len() != got.len() || !bool::from(want.as_bytes().ct_eq(got.as_bytes())) {
        return Err(Reject::BadSig);
    }
    if !nonces.claim(nonce, now) {
        return Err(Reject::Replay);
    }
    Ok(())
}

/// Key: pehle PCP_KEY_FILE (default /etc/anexomail/pcp.key), phir env PCP_KEY.
pub fn load_key() -> Vec<u8> {
    let path = std::env::var("PCP_KEY_FILE").unwrap_or_else(|_| "/etc/anexomail/pcp.key".into());
    if let Ok(s) = std::fs::read_to_string(&path) {
        let t = s.trim();
        if !t.is_empty() {
            return t.as_bytes().to_vec();
        }
    }
    std::env::var("PCP_KEY").map(|s| s.trim().as_bytes().to_vec()).unwrap_or_default()
}

/// Kill switch: ek khali file banao -> woh feature ruk jaata hai (restart nahi chahiye).
///   touch /opt/polar-rust-payment/PAUSE_PORTAL ; rm ... se wapas chalu.
pub fn paused(dir: &str, name: &str) -> bool {
    std::path::Path::new(dir).join(format!("PAUSE_{}", name.to_ascii_uppercase())).exists()
}

/// Polar customer-session response se sirf https://*.polar.sh portal URL maano.
pub fn portal_url_ok(url: &str) -> bool {
    let Some(rest) = url.strip_prefix("https://") else { return false };
    let host = rest.split(['/', '?', '#']).next().unwrap_or("");
    let host = host.split('@').last().unwrap_or("");
    let host = host.split(':').next().unwrap_or("");
    host == "polar.sh" || host.ends_with(".polar.sh")
}

/// user_id sirf asli UUID (8-4-4-4-12 hex). Kuch aur nahi — URL/JSON injection band.
pub fn is_uuid(s: &str) -> bool {
    let b = s.as_bytes();
    if b.len() != 36 {
        return false;
    }
    b.iter().enumerate().all(|(i, c)| match i {
        8 | 13 | 18 | 23 => *c == b'-',
        _ => c.is_ascii_hexdigit(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const KEY: &[u8] = b"0123456789abcdef0123456789abcdef-test-key";
    const NONCE: &str = "abcdefghijklmnop1234";

    fn parts<'a>(ts: &'a str, n: &'a str, sig: &'a str) -> SigParts<'a> {
        SigParts { ts: Some(ts), nonce: Some(n), sig: Some(sig) }
    }

    #[test]
    fn good_signature_passes_once_then_replay_fails() {
        let nn = Nonces::new();
        let body = br#"{"user_id":"x"}"#;
        let sig = sign(KEY, "POST", "/api/v1/portal", 1000, NONCE, body);
        let p = parts("1000", NONCE, &sig);
        assert_eq!(verify(KEY, "POST", "/api/v1/portal", &p, body, 1010, &nn), Ok(()));
        assert_eq!(verify(KEY, "POST", "/api/v1/portal", &p, body, 1011, &nn), Err(Reject::Replay));
    }

    #[test]
    fn tampered_body_path_method_all_fail() {
        let nn = Nonces::new();
        let body = br#"{"user_id":"a"}"#;
        let sig = sign(KEY, "POST", "/api/v1/portal", 1000, NONCE, body);
        let p = parts("1000", NONCE, &sig);
        assert_eq!(verify(KEY, "POST", "/api/v1/portal", &p, br#"{"user_id":"b"}"#, 1000, &nn), Err(Reject::BadSig));
        assert_eq!(verify(KEY, "POST", "/api/v1/checkout", &p, body, 1000, &nn), Err(Reject::BadSig));
        assert_eq!(verify(KEY, "GET", "/api/v1/portal", &p, body, 1000, &nn), Err(Reject::BadSig));
        // galat muhar ne nonce nahi jalaya: sahi muhar ab bhi chalti hai
        assert_eq!(verify(KEY, "POST", "/api/v1/portal", &p, body, 1000, &nn), Ok(()));
    }

    #[test]
    fn stale_future_missing_and_bad_inputs() {
        let nn = Nonces::new();
        let sig = sign(KEY, "POST", "/p", 1000, NONCE, b"");
        assert_eq!(verify(KEY, "POST", "/p", &parts("1000", NONCE, &sig), b"", 1061, &nn), Err(Reject::Stale));
        assert_eq!(verify(KEY, "POST", "/p", &parts("1000", NONCE, &sig), b"", 939, &nn), Err(Reject::Stale));
        assert_eq!(verify(KEY, "POST", "/p", &parts("abc", NONCE, &sig), b"", 1000, &nn), Err(Reject::BadTs));
        assert_eq!(verify(KEY, "POST", "/p", &parts("1000", "short", &sig), b"", 1000, &nn), Err(Reject::BadNonce));
        assert_eq!(verify(KEY, "POST", "/p", &parts("1000", "bad nonce with spaces!!", &sig), b"", 1000, &nn), Err(Reject::BadNonce));
        let none = SigParts { ts: None, nonce: None, sig: None };
        assert_eq!(verify(KEY, "POST", "/p", &none, b"", 1000, &nn), Err(Reject::Missing));
    }

    #[test]
    fn fail_closed_without_key_or_short_key() {
        let nn = Nonces::new();
        let sig = sign(b"short", "POST", "/p", 1000, NONCE, b"");
        assert_eq!(verify(b"", "POST", "/p", &parts("1000", NONCE, &sig), b"", 1000, &nn), Err(Reject::NoKey));
        assert_eq!(verify(b"short", "POST", "/p", &parts("1000", NONCE, &sig), b"", 1000, &nn), Err(Reject::NoKey));
        assert_eq!(Reject::NoKey.http(), 503);
        assert_eq!(Reject::BadSig.http(), 401);
    }

    #[test]
    fn signature_case_and_wrong_key() {
        let nn = Nonces::new();
        let sig = sign(KEY, "POST", "/p", 1000, NONCE, b"x").to_ascii_uppercase();
        assert_eq!(verify(KEY, "POST", "/p", &parts("1000", NONCE, &sig), b"x", 1000, &nn), Ok(()));
        let other = b"ffffffffffffffffffffffffffffffff-other";
        let nn2 = Nonces::new();
        let s2 = sign(other, "POST", "/p", 1000, "zzzzzzzzzzzzzzzz9999", b"x");
        assert_eq!(verify(KEY, "POST", "/p", &parts("1000", "zzzzzzzzzzzzzzzz9999", &s2), b"x", 1000, &nn2), Err(Reject::BadSig));
        // length mismatch bhi BadSig, panic nahi
        assert_eq!(verify(KEY, "POST", "/p", &parts("1000", "zzzzzzzzzzzzzzzz9999", "ab"), b"x", 1000, &nn2), Err(Reject::BadSig));
    }

    #[test]
    fn nonce_table_is_bounded() {
        let nn = Nonces::new();
        for i in 0..(MAX_NONCES + 500) {
            assert!(nn.claim(&format!("n{i}"), 1000));
        }
        let len = nn.seen.lock().unwrap().len();
        assert!(len <= MAX_NONCES + 1, "len={len}");
        // purane nonce expire ho jayen to dobara chal sakte hain
        assert!(nn.claim("n_old", 1000));
        assert!(!nn.claim("n_old", 1001));
        assert!(nn.claim("n_old", 1000 + WINDOW_SECS * 2 + 1));
    }

    #[test]
    fn portal_url_allowlist() {
        assert!(portal_url_ok("https://polar.sh/anexomail/portal?token=x"));
        assert!(portal_url_ok("https://sandbox.polar.sh/portal"));
        assert!(portal_url_ok("https://buy.polar.sh/portal/abc"));
        assert!(!portal_url_ok("http://polar.sh/portal"));
        assert!(!portal_url_ok("https://evilpolar.sh/portal"));
        assert!(!portal_url_ok("https://polar.sh.evil.com/portal"));
        assert!(!portal_url_ok("https://polar.sh@evil.com/portal"));
        assert!(!portal_url_ok("https://evil.com/?https://polar.sh"));
        assert!(!portal_url_ok("javascript:alert(1)"));
        assert!(!portal_url_ok(""));
    }

    #[test]
    fn uuid_strict() {
        assert!(is_uuid("0b3f6b0e-2b1c-4d3e-9a4f-1234567890ab"));
        assert!(!is_uuid("0b3f6b0e-2b1c-4d3e-9a4f-1234567890a"));
        assert!(!is_uuid("0b3f6b0e-2b1c-4d3e-9a4f-1234567890abc"));
        assert!(!is_uuid("../../etc/passwd"));
        assert!(!is_uuid("0b3f6b0e-2b1c-4d3e-9a4f-123456789zzz"));
        assert!(!is_uuid("0b3f6b0e_2b1c_4d3e_9a4f_1234567890ab"));
        assert!(!is_uuid(""));
    }

    #[test]
    fn paused_flag_file() {
        let d = std::env::temp_dir().join(format!("pcp-test-{}", std::process::id()));
        std::fs::create_dir_all(&d).unwrap();
        let ds = d.to_str().unwrap();
        assert!(!paused(ds, "portal"));
        std::fs::write(d.join("PAUSE_PORTAL"), b"").unwrap();
        assert!(paused(ds, "portal"));
        assert!(paused(ds, "PORTAL"));
        assert!(!paused(ds, "checkout"));
        std::fs::remove_dir_all(&d).ok();
    }

    #[test]
    fn known_vector_stable() {
        // canonical format tabdeel hui to Bun/Rust ki muhar toot jati — yeh test usay pakadta hai
        let c = canonical("post", "/api/v1/portal", 1700000000, "abcdefghijklmnop1234", b"{}");
        assert_eq!(
            c,
            "v1\nPOST\n/api/v1/portal\n1700000000\nabcdefghijklmnop1234\n44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
        );
    }
}
