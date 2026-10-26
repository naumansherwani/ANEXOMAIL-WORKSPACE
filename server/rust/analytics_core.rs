// ============================================================================
// ANEXOMAIL — Analytics Center (Phase 24) ki saaf soch: package gate + input safai. std-only, unit tests ke saath.
// I/O analytics_glue.rs mein. Hisaab SQL E89 mein (formula wahin likha hai aur har jawab ke `method` field mein bhi).
//
// Package gate (PACKAGE-FEATURE-FORMULA.md, Pro v6): Response debt = har package · Thread economics + Deep work = Pro+ ·
// Attention leaks, Promise SLA, Forecast, Team = Business+. UI (plan-surface.ts) sirf aaina; asli rok yahan hai.
// ============================================================================

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Need {
    Everyone,
    Pro,
    Business,
}

/// Proc -> kam se kam kaun sa package chahiye. None = yeh module is proc ka malik nahi.
pub fn need_of(proc: &str) -> Option<Need> {
    match proc {
        "analytics.responseDebt" => Some(Need::Everyone),
        "analytics.threadEconomics" | "analytics.deepWork" => Some(Need::Pro),
        "analytics.attentionLeaks" | "analytics.promiseSla" | "analytics.forecast" | "analytics.team" => Some(Need::Business),
        _ => None,
    }
}

/// 0 basic · 1 pro · 2 business ya upar. `ai_*` grants (AI Pro/Business/Executive) business_pro ke barabar hain (dashboard_summary jaisa). Anjaan = basic.
pub fn plan_rank(plan: &str) -> u8 {
    let p = plan.trim().to_lowercase().replace([' ', '-'], "_");
    if p.starts_with("ai_") || p == "ai" {
        return 2;
    }
    match p.as_str() {
        "business" | "business_pro" | "businesspro" | "enterprise" => 2,
        "pro" => 1,
        _ => 0,
    }
}

/// Ok(()) = chalao; Err(paigham) = 403 feature_not_available.
pub fn allowed(need: Need, plan: &str) -> Result<(), &'static str> {
    let r = plan_rank(plan);
    match need {
        Need::Everyone => Ok(()),
        Need::Pro if r >= 1 => Ok(()),
        Need::Pro => Err("Thread economics and deep work are on Pro and above. Response debt stays on every package."),
        Need::Business if r >= 2 => Ok(()),
        Need::Business => Err("Attention leaks, promise SLA, forecast and team reports are on Business and above."),
    }
}

/// Timezone naam sirf harf/ankh/`_`/`/`/`+`/`-` — warna "UTC". (SQL bhi pg_timezone_names se dobara jaanchta hai.)
pub fn clean_tz(tz: &str) -> String {
    let t = tz.trim();
    if t.is_empty() || t.len() > 64 || !t.chars().all(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '/' | '+' | '-')) || t.contains("..") {
        "UTC".to_string()
    } else {
        t.to_string()
    }
}

/// Mailbox addresses: lowercase, '@' wale, duplicate nahi, <= 200 (SQL array chhota rahe).
pub fn clean_addresses(raw: &[String], me: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for a in std::iter::once(me).chain(raw.iter().map(|s| s.as_str())) {
        let a = a.trim().to_lowercase();
        if a.len() <= 254 && a.contains('@') && !a.contains(char::is_whitespace) && !out.contains(&a) {
            out.push(a);
            if out.len() >= 200 {
                break;
            }
        }
    }
    out
}

/// Team report sirf org ke owner/admin ko (har member ke numbers dikhte hain).
pub fn can_see_team(role: &str) -> bool {
    matches!(role.trim().to_lowercase().as_str(), "owner" | "admin")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gate_matches_the_pro_card() {
        assert_eq!(need_of("analytics.responseDebt"), Some(Need::Everyone));
        assert_eq!(need_of("analytics.threadEconomics"), Some(Need::Pro));
        assert_eq!(need_of("analytics.deepWork"), Some(Need::Pro));
        for p in ["analytics.attentionLeaks", "analytics.promiseSla", "analytics.forecast", "analytics.team"] {
            assert_eq!(need_of(p), Some(Need::Business), "{p}");
        }
        assert_eq!(need_of("mail.threads"), None);
    }

    #[test]
    fn basic_gets_only_response_debt() {
        assert!(allowed(Need::Everyone, "basic").is_ok());
        assert!(allowed(Need::Pro, "basic").is_err());
        assert!(allowed(Need::Business, "basic").is_err());
        assert!(allowed(Need::Everyone, "").is_ok(), "unknown plan is still Basic, never an error for debt");
    }

    #[test]
    fn pro_gets_pro_reports_but_not_business() {
        assert!(allowed(Need::Pro, "pro").is_ok());
        assert!(allowed(Need::Business, "pro").is_err());
    }

    #[test]
    fn business_and_up_get_everything() {
        for plan in ["business", "business_pro", "Business Pro", "enterprise", "ai_executive", "ai_pro", "ai"] {
            assert!(allowed(Need::Business, plan).is_ok(), "{plan}");
            assert!(allowed(Need::Pro, plan).is_ok(), "{plan}");
        }
    }

    #[test]
    fn unknown_plan_never_unlocks_paid_reports() {
        for plan in ["", "free", "trial", "pro2", "probusiness"] {
            assert!(allowed(Need::Business, plan).is_err(), "{plan}");
        }
    }

    #[test]
    fn tz_is_clean_or_utc() {
        assert_eq!(clean_tz("Asia/Karachi"), "Asia/Karachi");
        assert_eq!(clean_tz("Etc/GMT+5"), "Etc/GMT+5");
        assert_eq!(clean_tz(""), "UTC");
        assert_eq!(clean_tz("Asia/Karachi'; drop table x;--"), "UTC");
        assert_eq!(clean_tz("../../etc"), "UTC");
        assert_eq!(clean_tz(&"a".repeat(65)), "UTC");
    }

    #[test]
    fn addresses_are_lowercase_unique_and_capped() {
        let a = clean_addresses(&["B@X.com".into(), "me@x.com".into(), "bad".into(), "has space@x.com".into()], "ME@x.com");
        assert_eq!(a, vec!["me@x.com".to_string(), "b@x.com".to_string()]);
        let many: Vec<String> = (0..500).map(|i| format!("u{i}@x.com")).collect();
        assert_eq!(clean_addresses(&many, "me@x.com").len(), 200);
        assert!(clean_addresses(&[], "").is_empty());
    }

    #[test]
    fn only_owner_or_admin_sees_team() {
        assert!(can_see_team("owner") && can_see_team("Admin"));
        assert!(!can_see_team("member") && !can_see_team(""));
    }
}
