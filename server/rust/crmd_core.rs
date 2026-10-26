// ============================================================================
// crmd_core — CRM desk (Pro): lead/deal banana, stage badalna, lead -> deal, deal -> task/thread ka HISAAB. Sirf std (installer `rustc --edition 2021 --test`).
// Bun server/routes/crm.ts ke Pro endpoints ka Rust (Tokio) port — Rule 52 (kernel) + Rule 56 (Bun ka kaam khatam). Formula Bun jaisa hi.
// Gate: Pro+ (Basic 403 feature_not_available). I/O crmd_glue.rs mein.
// ============================================================================

/// Pro+ procs.
pub fn pro_only(proc: &str) -> bool {
    matches!(
        proc,
        "crm.leads" | "crm.deals" | "crm.createLead" | "crm.createDeal" | "crm.moveDeal" | "crm.convertLead" | "crm.dealWork" | "crm.dealThread" | "crm.insights" | "work.promise.commit" | "work.promise.dismiss"
    )
}

pub const NO_ACCESS: &str = "CRM is on Pro and above.";

pub fn email_of(v: &str) -> String {
    v.trim().to_lowercase()
}

/// Bun STAGE_PROB.
pub fn stage_prob(stage: &str) -> Option<i64> {
    match stage {
        "new" => Some(10),
        "qualified" => Some(30),
        "proposal" => Some(55),
        "negotiation" => Some(75),
        "won" => Some(100),
        "lost" => Some(0),
        _ => None,
    }
}

pub fn is_closed(stage: &str) -> bool {
    stage == "won" || stage == "lost"
}

/// Lead email: trim + chhota; '@' lazmi. None => 400 email_required.
pub fn clean_lead_email(raw: &str) -> Option<String> {
    let e = email_of(raw);
    if e.is_empty() || !e.contains('@') {
        None
    } else {
        Some(e)
    }
}

/// Khali string => None (Bun `|| null`).
pub fn opt_text(raw: &str) -> Option<String> {
    let t = raw.trim();
    if t.is_empty() {
        None
    } else {
        Some(t.to_string())
    }
}

/// Lead source: khali => "manual".
pub fn clean_source(raw: &str) -> String {
    opt_text(raw).unwrap_or_else(|| "manual".to_string())
}

/// Deal title: kam az kam 2 harf (Bun `title.length < 2` => 400).
pub fn clean_title(raw: &str) -> Option<String> {
    let t = raw.trim();
    if t.chars().count() < 2 {
        None
    } else {
        Some(t.to_string())
    }
}

/// Deal value: finite nahi => 0. Negative bhi Bun jaisa chalta hai? Nahi — negative rakam 0 (naya, tez-gharaz bachav; Bun ne rok nahi rakha tha).
pub fn clean_value(v: Option<f64>) -> f64 {
    match v {
        Some(x) if x.is_finite() && x >= 0.0 => (x * 100.0).round() / 100.0,
        _ => 0.0,
    }
}

/// Lead -> deal ka title (company ho to "<company> — opportunity", warna email).
pub fn convert_title(company: Option<&str>, email: &str) -> String {
    match company.map(|c| c.trim()).filter(|c| !c.is_empty()) {
        Some(c) => format!("{c} — opportunity"),
        None => format!("{email} — opportunity"),
    }
}

/// Bun `days()` (floor): None => None.
pub fn days_since(now: i64, then: Option<i64>) -> Option<i64> {
    then.map(|t| (now - t).div_euclid(86_400))
}

/// Promise ko task banate waqt owner: promise ka apna owner, warna commit karne wala.
pub fn task_owner(promise_owner: Option<&str>, me: &str) -> String {
    promise_owner.map(|o| o.trim()).filter(|o| !o.is_empty()).unwrap_or(me).to_string()
}

/// Lead list filter: "all" ya state barabar.
pub fn state_matches(want: &str, have: &str) -> bool {
    let w = if want.is_empty() { "all" } else { want };
    w == "all" || w == have
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gate_list() {
        assert!(pro_only("crm.createLead"));
        assert!(pro_only("crm.insights"));
        assert!(pro_only("work.promise.commit") && pro_only("work.promise.dismiss"));
        assert!(!pro_only("crm.live"));
        assert!(!pro_only("crm.deals.move"));
    }

    #[test]
    fn stages() {
        assert_eq!(stage_prob("new"), Some(10));
        assert_eq!(stage_prob("won"), Some(100));
        assert_eq!(stage_prob("lost"), Some(0));
        assert_eq!(stage_prob("bogus"), None);
        assert!(is_closed("won") && is_closed("lost") && !is_closed("proposal"));
    }

    #[test]
    fn lead_email() {
        assert_eq!(clean_lead_email("  A@B.com "), Some("a@b.com".to_string()));
        assert_eq!(clean_lead_email("nope"), None);
        assert_eq!(clean_lead_email(""), None);
    }

    #[test]
    fn text_and_source() {
        assert_eq!(opt_text("  "), None);
        assert_eq!(opt_text(" x "), Some("x".to_string()));
        assert_eq!(clean_source(""), "manual");
        assert_eq!(clean_source("form"), "form");
    }

    #[test]
    fn titles_values() {
        assert_eq!(clean_title("a"), None);
        assert_eq!(clean_title(" Big deal "), Some("Big deal".to_string()));
        assert_eq!(clean_value(Some(10.456)), 10.46);
        assert_eq!(clean_value(Some(-5.0)), 0.0);
        assert_eq!(clean_value(Some(f64::NAN)), 0.0);
        assert_eq!(clean_value(None), 0.0);
        assert_eq!(convert_title(Some("Acme"), "a@b.com"), "Acme — opportunity");
        assert_eq!(convert_title(None, "a@b.com"), "a@b.com — opportunity");
        assert_eq!(convert_title(Some("  "), "a@b.com"), "a@b.com — opportunity");
    }

    #[test]
    fn promise_owner() {
        assert_eq!(task_owner(Some("a@b.com"), "me@x.com"), "a@b.com");
        assert_eq!(task_owner(Some(" "), "me@x.com"), "me@x.com");
        assert_eq!(task_owner(None, "me@x.com"), "me@x.com");
    }

    #[test]
    fn days_and_state() {
        assert_eq!(days_since(86_400 * 3, Some(0)), Some(3));
        assert_eq!(days_since(10, None), None);
        assert!(state_matches("all", "new") && state_matches("", "new") && state_matches("new", "new"));
        assert!(!state_matches("converted", "new"));
    }
}
