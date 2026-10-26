// authx_core — `auth.session` ka dimaag (std-only, serde_json NAHI; `rustc --edition 2021 --test` se test hota hai).
// Bun `sessionResult()` (server/routes/auth.ts) ka hu-ba-hu hisab: account kind, plan, organisations ka milan, active org, onboarded, naam.
// Glue (authx_glue.rs) sirf DB se rows laata hai aur yeh functions chalata hai.

#[derive(Clone, Debug, PartialEq)]
pub struct Org {
    pub id: String,
    pub name: String,
    pub slug: String,
    pub domain: Option<String>,
    pub role: String,
}

pub fn owns_name(proc: &str) -> bool {
    proc == "auth.session"
}

fn norm(s: &str) -> String {
    s.trim().to_lowercase()
}

/// Pehli khaali-na-hone wali qeemat (JS `a || b || c`).
pub fn first_text(items: &[Option<&str>]) -> Option<String> {
    for i in items {
        if let Some(s) = i {
            if !s.is_empty() {
                return Some(s.to_string());
            }
        }
    }
    None
}

pub fn resolve_account_kind(pref: &str, plan: &str, org_slug: &str) -> &'static str {
    let k = norm(pref);
    if k == "personal" {
        return "personal";
    }
    if k == "business" {
        return "business";
    }
    if org_slug.to_lowercase().starts_with("personal-") {
        return "personal";
    }
    let mut p = norm(if plan.trim().is_empty() { "basic" } else { plan });
    p = p.split(|c: char| c.is_whitespace() || c == '-').filter(|x| !x.is_empty()).collect::<Vec<_>>().join("_");
    if p == "basic" || p == "pro" {
        "personal"
    } else {
        "business"
    }
}

/// workspace_plan: asli plan (family > trial) ya "basic" (sirf gating fallback).
pub fn workspace_plan(real: Option<&str>) -> String {
    let p = norm(real.unwrap_or(""));
    if p.is_empty() {
        "basic".into()
    } else {
        p
    }
}

pub fn ai_plan(raw: &str) -> Option<String> {
    let t = raw.trim();
    if t.is_empty() {
        None
    } else {
        Some(t.to_lowercase())
    }
}

pub fn anexo_address(trial: Option<&str>, founder: bool, email: &str) -> Option<String> {
    let e = norm(email);
    if let Some(t) = trial {
        if !t.is_empty() {
            return Some(t.to_string());
        }
    }
    if founder && !e.is_empty() {
        return Some(e);
    }
    if e.ends_with("@anexomail.com") {
        return Some(e);
    }
    None
}

pub fn op_org_name(live: Option<&str>, legacy: Option<&str>, founder: bool) -> String {
    first_text(&[live, legacy]).unwrap_or_else(|| if founder { "Founder workspace".into() } else { "ANEXOMAIL Workspace".into() })
}

pub fn op_org_slug(live: Option<&str>, founder: bool, id: &str) -> String {
    match live {
        Some(s) if !s.is_empty() => s.to_string(),
        _ => {
            if founder {
                "founder-workspace".into()
            } else {
                let short: String = id.chars().take(8).collect();
                format!("workspace-{short}")
            }
        }
    }
}

/// Account organisations + operational org ka milan (Bun jaisa).
pub fn merge_orgs(accounts: Vec<Org>, op: Option<Org>, founder: bool, has_address: bool) -> Vec<Org> {
    match op {
        Some(o) if !founder && has_address => vec![o],
        Some(o) => {
            let mut all = accounts;
            if !all.iter().any(|x| x.id == o.id) {
                all.insert(0, o);
            }
            let mut seen: Vec<String> = Vec::new();
            all.into_iter()
                .filter(|x| {
                    if seen.contains(&x.id) {
                        false
                    } else {
                        seen.push(x.id.clone());
                        true
                    }
                })
                .collect()
        }
        None => accounts,
    }
}

pub fn active_org_id(preferred: Option<&str>, orgs: &[Org]) -> Option<String> {
    if let Some(p) = preferred {
        if !p.is_empty() && orgs.iter().any(|o| o.id == p) {
            return Some(p.to_string());
        }
    }
    orgs.first().map(|o| o.id.clone())
}

pub fn is_onboarded(founder: bool, profile_onboarded: bool, has_op: bool, has_address: bool) -> bool {
    founder || profile_onboarded || (has_op && has_address)
}

#[cfg(test)]
mod tests {
    use super::*;
    fn o(id: &str) -> Org {
        Org { id: id.into(), name: format!("n{id}"), slug: format!("s{id}"), domain: None, role: "owner".into() }
    }
    #[test]
    fn kind() {
        assert_eq!(resolve_account_kind("Personal", "enterprise", ""), "personal");
        assert_eq!(resolve_account_kind("business", "basic", "personal-x"), "business");
        assert_eq!(resolve_account_kind("", "basic", "Personal-abc"), "personal");
        assert_eq!(resolve_account_kind("", "pro", "x"), "personal");
        assert_eq!(resolve_account_kind("", "Business Pro", "x"), "business");
        assert_eq!(resolve_account_kind("", "business-pro", "x"), "business");
        assert_eq!(resolve_account_kind("", "", "x"), "personal");
        assert_eq!(resolve_account_kind("weird", "pro", "x"), "personal");
    }
    #[test]
    fn plan_and_ai() {
        assert_eq!(workspace_plan(None), "basic");
        assert_eq!(workspace_plan(Some(" Pro ")), "pro");
        assert_eq!(workspace_plan(Some("")), "basic");
        assert_eq!(ai_plan("  "), None);
        assert_eq!(ai_plan(" Pro "), Some("pro".into()));
    }
    #[test]
    fn address() {
        assert_eq!(anexo_address(Some("a@anexomail.com"), false, "x@y.com"), Some("a@anexomail.com".into()));
        assert_eq!(anexo_address(None, true, " F@Y.com "), Some("f@y.com".into()));
        assert_eq!(anexo_address(None, false, "Z@anexomail.com"), Some("z@anexomail.com".into()));
        assert_eq!(anexo_address(None, false, "z@gmail.com"), None);
        assert_eq!(anexo_address(Some(""), false, ""), None);
    }
    #[test]
    fn op_names() {
        assert_eq!(op_org_name(Some("A"), Some("B"), false), "A");
        assert_eq!(op_org_name(None, Some("B"), false), "B");
        assert_eq!(op_org_name(Some(""), None, true), "Founder workspace");
        assert_eq!(op_org_name(None, None, false), "ANEXOMAIL Workspace");
        assert_eq!(op_org_slug(None, false, "123456789abc"), "workspace-12345678");
        assert_eq!(op_org_slug(None, true, "1"), "founder-workspace");
        assert_eq!(op_org_slug(Some("zz"), true, "1"), "zz");
    }
    #[test]
    fn merge() {
        // awam @anexomail: sirf operational
        assert_eq!(merge_orgs(vec![o("1")], Some(o("2")), false, true), vec![o("2")]);
        // founder: prepend + dedupe
        let m = merge_orgs(vec![o("1"), o("1"), o("3")], Some(o("2")), true, true);
        assert_eq!(m.iter().map(|x| x.id.as_str()).collect::<Vec<_>>(), vec!["2", "1", "3"]);
        // op already present: no prepend
        let m = merge_orgs(vec![o("1"), o("2")], Some(o("2")), false, false);
        assert_eq!(m.iter().map(|x| x.id.as_str()).collect::<Vec<_>>(), vec!["1", "2"]);
        // no op: accounts as is
        assert_eq!(merge_orgs(vec![o("1")], None, false, true), vec![o("1")]);
    }
    #[test]
    fn active_and_misc() {
        let l = vec![o("1"), o("2")];
        assert_eq!(active_org_id(Some("2"), &l), Some("2".into()));
        assert_eq!(active_org_id(Some("9"), &l), Some("1".into()));
        assert_eq!(active_org_id(None, &[]), None);
        assert!(is_onboarded(true, false, false, false));
        assert!(is_onboarded(false, false, true, true));
        assert!(!is_onboarded(false, false, true, false));
        assert_eq!(first_text(&[None, Some(""), Some("x")]), Some("x".into()));
    }
}
