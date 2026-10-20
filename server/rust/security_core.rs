// ============================================================================
// security_core.rs — PURE half of the Security page (std-only, unit-tested; the installer runs these tests on the server).
//
// 20 Oct 2026 (Basic live audit): the Security page read only empty tables nobody writes to ("Live sessions 0" while the
// user is signed in; "Kill" killed nothing; "Rotate keys" only wrote a row). security_glue.rs now reads the real records
// (auth.sessions, device_vault, auth.audit_log_entries, live TLS handshakes) through E39 SQL. This file holds the
// decisions so they can be tested without a network or a database:
//   * ua_label        — "Chrome on Windows" from a User-Agent (no fingerprinting, only the two coarse words)
//   * session_risk    — an idle session is a forgotten session
//   * score / Proof   — the posture score: points are lost only for things that are really wrong
//   * login_risk      — first sign-in from a network never seen before for this user
//   * SMTP helpers    — reply codes and STARTTLS in EHLO, for the live encryption probe
//   * tls_modern      — TLS 1.2 / 1.3 count as "on"
// ============================================================================

/// Coarse device words from a User-Agent. Order matters: Edge/Opera say "Chrome", iPad/iPhone say "Mac OS X".
pub fn ua_label(ua: &str) -> String {
    let u = ua.to_ascii_lowercase();
    if u.trim().is_empty() {
        return "Unknown device".to_string();
    }
    let browser = if u.contains("edg/") || u.contains("edge/") {
        "Edge"
    } else if u.contains("opr/") || u.contains("opera") {
        "Opera"
    } else if u.contains("firefox/") || u.contains("fxios/") {
        "Firefox"
    } else if u.contains("crios/") || u.contains("chrome/") || u.contains("chromium/") {
        "Chrome"
    } else if u.contains("safari/") || u.contains("version/") {
        "Safari"
    } else if u.starts_with("node") || u.contains("bun/") || u.contains("undici") || u.contains("curl/") || u.contains("python") {
        "App / script"
    } else {
        "Browser"
    };
    let os = if u.contains("iphone") {
        "iPhone"
    } else if u.contains("ipad") {
        "iPad"
    } else if u.contains("android") {
        "Android"
    } else if u.contains("windows") {
        "Windows"
    } else if u.contains("mac os x") || u.contains("macintosh") {
        "Mac"
    } else if u.contains("cros") {
        "ChromeOS"
    } else if u.contains("linux") {
        "Linux"
    } else {
        ""
    };
    if os.is_empty() { browser.to_string() } else { format!("{browser} on {os}") }
}

/// "low" | "medium": a session nobody used for 14+ days is the one a thief would keep.
pub fn session_risk(current: bool, idle_days: i64) -> &'static str {
    if !current && idle_days >= 14 { "medium" } else { "low" }
}

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Proof {
    /// never ran — unknown, not "failed"
    None,
    Passed,
    Failed,
}

/// Posture score 0..=100 from real findings only.
pub fn score(pending_devices: u32, anomalies_high: u32, anomalies_med: u32, anomalies_low: u32, encryption_ok: bool, proof: Proof, failed_24h: u32, stale_sessions: u32) -> u32 {
    let mut penalty: u32 = pending_devices * 3 + anomalies_high * 18 + anomalies_med * 8 + anomalies_low * 3 + failed_24h.min(15) + stale_sessions.min(5) * 2;
    if !encryption_ok {
        penalty += 20;
    }
    penalty += match proof {
        Proof::Failed => 15,
        Proof::None => 5,
        Proof::Passed => 0,
    };
    100u32.saturating_sub(penalty)
}

/// Login risk 0..=100: a network (ip) this user has never signed in from before is worth a look.
pub fn login_risk(ip: Option<&str>, seen_before: bool) -> u32 {
    match ip {
        None => 10,
        Some(_) if seen_before => 5,
        Some(_) => 35,
    }
}

/// "250-STARTTLS" / "250 OK" -> Some(250). Only complete 3-digit codes.
pub fn smtp_code(line: &str) -> Option<u16> {
    let b = line.as_bytes();
    if b.len() < 3 || !b[..3].iter().all(|c| c.is_ascii_digit()) {
        return None;
    }
    if b.len() > 3 && b[3] != b' ' && b[3] != b'-' {
        return None;
    }
    line[..3].parse().ok()
}

/// true when this is the LAST line of a (multi-line) SMTP reply ("250 ..." not "250-...").
pub fn smtp_last(line: &str) -> bool {
    smtp_code(line).is_some() && (line.len() == 3 || line.as_bytes()[3] == b' ')
}

pub fn ehlo_has_starttls(reply: &str) -> bool {
    reply.lines().any(|l| l.len() > 4 && l[4..].trim().eq_ignore_ascii_case("STARTTLS"))
}

/// "TLSv1_3" / "TLSv1.2" -> true; anything older -> false.
pub fn tls_modern(version: &str) -> bool {
    let v = version.to_ascii_lowercase().replace(['_', ' '], ".");
    v.contains("1.3") || v.contains("1.2")
}

/// "TLSv1_3" -> "TLS 1.3" (what a person reads).
pub fn tls_human(version: &str) -> String {
    let v = version.to_ascii_lowercase().replace('_', ".");
    if let Some(i) = v.find("1.") {
        return format!("TLS {}", &v[i..i + 3]);
    }
    version.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ua_labels() {
        assert_eq!(ua_label("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36"), "Chrome on Windows");
        assert_eq!(ua_label("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1"), "Safari on iPhone");
        assert_eq!(ua_label("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/141.0 Safari/537.36 Edg/141.0"), "Edge on Windows");
        assert_eq!(ua_label("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5; rv:131.0) Gecko/20100101 Firefox/131.0"), "Firefox on Mac");
        assert_eq!(ua_label("Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/141.0 Mobile Safari/537.36"), "Chrome on Android");
        assert_eq!(ua_label("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 CriOS/141.0 Mobile/15E148 Safari/604.1"), "Chrome on iPad");
        assert_eq!(ua_label("node"), "App / script");
        assert_eq!(ua_label(""), "Unknown device");
    }

    #[test]
    fn risk_and_score() {
        assert_eq!(session_risk(true, 40), "low");
        assert_eq!(session_risk(false, 13), "low");
        assert_eq!(session_risk(false, 14), "medium");
        assert_eq!(score(0, 0, 0, 0, true, Proof::Passed, 0, 0), 100);
        assert_eq!(score(0, 0, 0, 0, true, Proof::None, 0, 0), 95);
        assert_eq!(score(0, 0, 0, 0, false, Proof::Failed, 0, 0), 65);
        assert_eq!(score(10, 10, 0, 0, false, Proof::Failed, 99, 9), 0);
        assert_eq!(login_risk(Some("1.2.3.4"), true), 5);
        assert_eq!(login_risk(Some("1.2.3.4"), false), 35);
        assert_eq!(login_risk(None, false), 10);
    }

    #[test]
    fn smtp_parsing() {
        assert_eq!(smtp_code("220 mail.anexomail.com ESMTP"), Some(220));
        assert_eq!(smtp_code("250-STARTTLS"), Some(250));
        assert_eq!(smtp_code("25"), None);
        assert_eq!(smtp_code("2500 x"), None);
        assert!(smtp_last("250 SMTPUTF8"));
        assert!(!smtp_last("250-PIPELINING"));
        assert!(ehlo_has_starttls("250-mail.anexomail.com\r\n250-PIPELINING\r\n250-STARTTLS\r\n250 SMTPUTF8\r\n"));
        assert!(!ehlo_has_starttls("250-mail\r\n250 8BITMIME\r\n"));
    }

    #[test]
    fn tls_versions() {
        assert!(tls_modern("TLSv1_3"));
        assert!(tls_modern("TLSv1_2"));
        assert!(!tls_modern("TLSv1_1"));
        assert_eq!(tls_human("TLSv1_3"), "TLS 1.3");
    }
}
