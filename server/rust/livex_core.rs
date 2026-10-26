// ============================================================================
// livex_core — CRM live radar (`crm.live`) aur org members (`org.members`) ka HISAAB. Sirf std: installer pre-flight `rustc --edition 2021 --test`.
// Bun GET /api/crm/live aur GET /api/org/members ka Rust (Tokio) port (Rule 52 G3, Rule 56: Bun ka kaam khatam). Formula Bun jaisa hi.
// Gate: crm.live Pro+ (Basic 403); org.members sirf login + org (Bun jaisa). I/O livex_glue.rs mein.
// ============================================================================

/// Pro+ procs. Some(paigham) = Basic ko 403 `feature_not_available`.
pub fn pro_only(proc: &str) -> Option<&'static str> {
    match proc {
        "crm.live" => Some("CRM is on Pro and above."),
        _ => None,
    }
}

pub fn email_of(v: &str) -> String {
    v.trim().to_lowercase()
}

/// Bun `days()`: floor((now - then) / 86400); aagay ka waqt negative nahi, JS Math.floor jaisa hi (negative floor).
pub fn days_since(now: i64, then: Option<i64>) -> Option<i64> {
    then.map(|t| (now - t).div_euclid(86_400))
}

/// Deal itne din khamosh => radar "silent".
pub const SILENT_DAYS: i64 = 14;
/// Decision-maker meeting gap.
pub const MEETING_GAP_DAYS: i64 = 12;

/// Bun: score 72; quiet null ya >=14 => -18; open_threads>0 => -10; 0..100.
pub fn default_health(quiet: Option<i64>, open_threads: i64) -> i64 {
    let mut s = 72;
    if quiet.map(|q| q >= SILENT_DAYS).unwrap_or(true) {
        s -= 18;
    }
    if open_threads > 0 {
        s -= 10;
    }
    s.clamp(0, 100)
}

/// JS number -> text: 72 => "72", 72.5 => "72.5".
pub fn num_text(n: f64) -> String {
    if n.fract() == 0.0 && n.abs() < 1e15 {
        format!("{}", n as i64)
    } else {
        format!("{n}")
    }
}

/// Bun: relationship (at_risk/dormant) YA (quiet >= 14 aur is contact ki koi open deal) => radar "health".
pub fn health_radar(relationship: &str, quiet: Option<i64>, has_open_deal: bool) -> bool {
    relationship == "at_risk" || relationship == "dormant" || (quiet.map(|q| q >= SILENT_DAYS).unwrap_or(false) && has_open_deal)
}

pub fn health_why(relationship: &str, health: Option<f64>, quiet: Option<i64>) -> String {
    if !relationship.is_empty() {
        match health {
            Some(h) => format!("Relationship {relationship} · health {}", num_text(h)),
            None => format!("Relationship {relationship}"),
        }
    } else {
        let q = quiet.map(|q| q.to_string()).unwrap_or_else(|| "unknown".to_string());
        format!("Last touch {q} days ago · health {}", health.map(num_text).unwrap_or_else(|| "null".to_string()))
    }
}

/// Promise ka title: suggested_title || quote || "Promise".
pub fn promise_title(suggested: &str, quote: &str) -> String {
    if !suggested.is_empty() {
        suggested.to_string()
    } else if !quote.is_empty() {
        quote.to_string()
    } else {
        "Promise".to_string()
    }
}

/// Bun `status ?? "active"` (null/missing => active).
pub fn status_or_active(s: Option<&str>) -> &str {
    match s {
        Some(x) => x,
        None => "active",
    }
}

/// `status` input: sirf kuch bhi (Bun filter), khali => "all".
pub fn status_filter(s: &str) -> &str {
    if s.is_empty() {
        "all"
    } else {
        s
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gate_is_pro_plus_for_crm_live_only() {
        assert!(pro_only("crm.live").is_some());
        assert!(pro_only("org.members").is_none());
        assert!(pro_only("crm.board").is_none());
    }

    #[test]
    fn days_floor_like_js() {
        assert_eq!(days_since(100_000, Some(100_000 - 86_400 * 14)), Some(14));
        assert_eq!(days_since(100_000, Some(100_000 - 86_399)), Some(0));
        assert_eq!(days_since(100_000, None), None);
        assert_eq!(days_since(0, Some(10)), Some(-1)); // aagay ka waqt: Math.floor(-tiny) = -1
    }

    #[test]
    fn health_score_defaults_match_bun() {
        assert_eq!(default_health(Some(0), 0), 72);
        assert_eq!(default_health(None, 0), 54);
        assert_eq!(default_health(Some(14), 0), 54);
        assert_eq!(default_health(Some(13), 0), 72);
        assert_eq!(default_health(Some(30), 2), 44);
        assert_eq!(default_health(Some(1), 1), 62);
    }

    #[test]
    fn health_radar_rules() {
        assert!(health_radar("at_risk", Some(0), false));
        assert!(health_radar("dormant", None, false));
        assert!(health_radar("", Some(14), true));
        assert!(!health_radar("", Some(14), false));
        assert!(!health_radar("", None, true));
        assert!(!health_radar("healthy", Some(3), true));
    }

    #[test]
    fn why_text_matches_bun_template() {
        assert_eq!(health_why("at_risk", Some(40.0), Some(3)), "Relationship at_risk · health 40");
        assert_eq!(health_why("", Some(54.0), None), "Last touch unknown days ago · health 54");
        assert_eq!(health_why("", Some(54.5), Some(20)), "Last touch 20 days ago · health 54.5");
        assert_eq!(health_why("dormant", None, None), "Relationship dormant");
    }

    #[test]
    fn promise_title_fallbacks() {
        assert_eq!(promise_title("Send quote", "I will send"), "Send quote");
        assert_eq!(promise_title("", "I will send"), "I will send");
        assert_eq!(promise_title("", ""), "Promise");
    }

    #[test]
    fn org_status_helpers() {
        assert_eq!(status_or_active(None), "active");
        assert_eq!(status_or_active(Some("invited")), "invited");
        assert_eq!(status_filter(""), "all");
        assert_eq!(status_filter("revoked"), "revoked");
        assert_eq!(email_of("  A@B.com "), "a@b.com");
    }
}
