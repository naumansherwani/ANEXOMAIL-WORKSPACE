// ============================================================================
// b6_core.rs — B6 (G16) Polar control plane, Rust-app ki taraf: PURE logic (sirf std).
// Polar engine (:3400) ke internal raaste ko muhar-band call karne ke qaide. HMAC/SHA-256 aur network
// glue (b6_glue.rs) mein hai; yahan wohi cheezen jinhein server par pre-flight `rustc --test` se parkha jaata hai.
//
// Muhar ka format polar-payment/pcp.rs, Bun (billing-sync.ts pcpHeaders) aur is file mein EK jaisa hai:
//   "v1\nMETHOD\nPATH\nTS\nNONCE\nsha256hex(body)"  -> HMAC-SHA256(key) -> hex
// ============================================================================

pub const PORTAL_PATH: &str = "/api/v1/portal";

/// Muhar ki canonical string. `body_sha256_hex` glue nikalta hai (SHA-256 crate wahan hai).
pub fn canonical(method: &str, path: &str, ts: i64, nonce: &str, body_sha256_hex: &str) -> String {
    format!("v1\n{}\n{}\n{}\n{}\n{}", method.to_ascii_uppercase(), path, ts, nonce, body_sha256_hex)
}

pub fn hex(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        s.push_str(&format!("{b:02x}"));
    }
    s
}

/// Nonce: 32 hex chars (engine 16..64 [A-Za-z0-9_-] maanta hai). Alag alag call = alag (nanos + counter).
pub fn nonce(nanos: u128, counter: u64) -> String {
    format!("{:016x}{:016x}", (nanos & 0xffff_ffff_ffff_ffff) as u64, counter)
}

pub fn is_uuid(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 36
        && b.iter().enumerate().all(|(i, c)| match i {
            8 | 13 | 18 | 23 => *c == b'-',
            _ => c.is_ascii_hexdigit(),
        })
}

/// Polar portal URL sirf https://polar.sh ya *.polar.sh.
pub fn portal_url_ok(url: &str) -> bool {
    let Some(rest) = url.strip_prefix("https://") else { return false };
    let host = rest.split(['/', '?', '#']).next().unwrap_or("");
    if host.contains('@') {
        return false;
    }
    let host = host.split(':').next().unwrap_or("");
    host == "polar.sh" || host.ends_with(".polar.sh")
}

/// Engine ke jawab ko (status, error code) se app ke (http status, code, message) mein badlo.
/// Statuses jaan-boojh kar 404/501/502/503 se bachaye gaye jahan jawab "final" hai —
/// kyunke rpcOrRest in par Bun fallback chalata hai (wahi jawab doosri dafa mangna bekaar).
pub fn classify(engine_status: u16, code: &str) -> (u16, &'static str, &'static str) {
    match (engine_status, code) {
        (404, "no_billing_account") => (422, "no_billing_account", "No payment on file yet"),
        (503, "portal_paused") => (409, "portal_paused", "Billing portal is paused for a moment"),
        (400, "bad_user_id") => (400, "bad_user_id", "Invalid account"),
        (s, _) if s >= 500 => (502, "portal_unavailable", "Billing portal is unavailable"),
        (401, _) | (403, _) => (502, "portal_unavailable", "Billing portal is unavailable"),
        _ => (502, "portal_unavailable", "Billing portal is unavailable"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_matches_engine_vector() {
        // Rust engine pcp.rs ka test-vector (body "{}" ka sha256) — teeno taraf (Rust, Bun, Python) yahi string banate hain
        let c = canonical(
            "post",
            PORTAL_PATH,
            1700000000,
            "abcdefghijklmnop1234",
            "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
        );
        assert_eq!(
            c,
            "v1\nPOST\n/api/v1/portal\n1700000000\nabcdefghijklmnop1234\n44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
        );
    }

    #[test]
    fn hex_and_nonce() {
        assert_eq!(hex(&[0, 1, 15, 16, 255]), "00010f10ff");
        let a = nonce(123456789012345678901234567890, 1);
        let b = nonce(123456789012345678901234567890, 2);
        assert_ne!(a, b);
        assert_eq!(a.len(), 32);
        assert!(a.bytes().all(|c| c.is_ascii_hexdigit()));
        assert_eq!(nonce(0, 0), "00000000000000000000000000000000");
    }

    #[test]
    fn uuid_strict() {
        assert!(is_uuid("0b3f6b0e-2b1c-4d3e-9a4f-1234567890ab"));
        assert!(!is_uuid("0b3f6b0e-2b1c-4d3e-9a4f-1234567890a"));
        assert!(!is_uuid("../../x"));
        assert!(!is_uuid(""));
        assert!(!is_uuid("0b3f6b0e-2b1c-4d3e-9a4f-123456789zzz"));
    }

    #[test]
    fn portal_allowlist() {
        assert!(portal_url_ok("https://polar.sh/anexomail/portal?x=1"));
        assert!(portal_url_ok("https://sandbox.polar.sh/p"));
        assert!(!portal_url_ok("http://polar.sh/p"));
        assert!(!portal_url_ok("https://evilpolar.sh/p"));
        assert!(!portal_url_ok("https://polar.sh.evil.com/p"));
        assert!(!portal_url_ok("https://polar.sh@evil.com/p"));
        assert!(!portal_url_ok("https://evil.com/#https://polar.sh"));
        assert!(!portal_url_ok(""));
    }

    #[test]
    fn classify_table() {
        assert_eq!(classify(404, "no_billing_account").0, 422);
        assert_eq!(classify(503, "portal_paused").0, 409);
        assert_eq!(classify(400, "bad_user_id").0, 400);
        for s in [500u16, 502, 503, 504] {
            assert_eq!(classify(s, "polar_unreachable").1, "portal_unavailable");
        }
        assert_eq!(classify(401, "bad_signature").1, "portal_unavailable");
        // koi bhi final jawab fallback-trigger (404/501/502/503) na bane jab woh asal mein final ho
        for (s, c) in [(404u16, "no_billing_account"), (503, "portal_paused")] {
            let out = classify(s, c).0;
            assert!(![404, 501, 502, 503].contains(&out), "{out}");
        }
    }
}
