// setx_core — Batch D: Settings (Time Machine) + Integrations + founder overviews, sirf HISAAB (std-only, serde_json nahi).
// Bun twins: server/routes/settings.ts, integrations.ts, security.ts (founder overview). I/O setx_glue.rs mein.
// Business-only settings (blastRadius, simulate, drift, scheduled, schedule, cancel) aur Leo actions (ai_soon) JAAN-BOOJH kar yahan NAHI —
// woh qadam 11 / AI plan ke saath aayenge; Rust unhein 404 procedure_not_in_rust deta hai to client Bun par girta hai (Rule 59).

pub const PROCS: [&str; 18] = [
    "settings.list",
    "settings.explain",
    "settings.save",
    "settings.history",
    "settings.revert",
    "founderSettings.overview",
    "integrations.providers",
    "integrations.connections",
    "integrations.connect",
    "integrations.disconnect",
    "integrations.migrations",
    "integrations.startMigration",
    "integrations.controlMigration",
    "integrations.delivery",
    "integrations.exports",
    "integrations.export",
    "founderIntegrations.overview",
    "founderSecurity.overview",
];

pub const SCOPES: [&str; 6] = ["personal", "workspace", "appearance", "notifications", "privacy", "ai"];

pub fn owns_name(p: &str) -> bool {
    PROCS.contains(&p)
}

pub fn founder_only(p: &str) -> bool {
    p.starts_with("founder")
}

pub fn scope_ok(s: &str) -> bool {
    SCOPES.contains(&s)
}

/// Setting key: 1..=120, sirf a-z A-Z 0-9 _ . : -
pub fn key_ok(k: &str) -> bool {
    !k.is_empty() && k.len() <= 120 && k.chars().all(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '.' | ':' | '-'))
}

/// uuid shakal (8-4-4-4-12 hex) — PostgREST ko galat id jane se pehle hi rok do.
pub fn uuid_ok(s: &str) -> bool {
    let p: Vec<&str> = s.split('-').collect();
    p.len() == 5
        && [8usize, 4, 4, 4, 12].iter().zip(p.iter()).all(|(n, x)| x.len() == *n && x.chars().all(|c| c.is_ascii_hexdigit()))
}

/// Provider id (gmail, outlook, imap ...): 1..=40, a-z 0-9 _ -
pub fn provider_ok(s: &str) -> bool {
    !s.is_empty() && s.len() <= 40 && s.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || matches!(c, '_' | '-'))
}

/// Account/target (email jaisa): trimmed, 3..=254, ek '@', koi space/control/quote/comma nahi.
pub fn email_ok(s: &str) -> bool {
    let t = s.trim();
    t.len() >= 3
        && t.len() <= 254
        && t.matches('@').count() == 1
        && !t.starts_with('@')
        && !t.ends_with('@')
        && t.chars().all(|c| c.is_ascii_graphic() && !matches!(c, '"' | ',' | '(' | ')' | '<' | '>' | '\\' | '*' | '&' | '#' | '%'))
}

/// Connection account (IMAP user/email): 1..=254, control character nahi (body JSON mein jata hai, URL mein nahi).
pub fn account_ok(s: &str) -> bool {
    let t = s.trim();
    !t.is_empty() && t.len() <= 254 && t.chars().all(|c| !c.is_control())
}

/// Hostname: 1..=253, a-z 0-9 . - (label 1..=63, '-' se shuru/khatam nahi).
pub fn host_ok(s: &str) -> bool {
    let t = s.trim();
    t.len() <= 253
        && !t.is_empty()
        && t.split('.').all(|l| {
            !l.is_empty() && l.len() <= 63 && !l.starts_with('-') && !l.ends_with('-') && l.chars().all(|c| c.is_ascii_alphanumeric() || c == '-')
        })
}

pub fn port_ok(p: i64) -> bool {
    (1..=65535).contains(&p)
}

pub fn export_scope_ok(s: &str) -> bool {
    matches!(s, "mail" | "calendar" | "contacts" | "everything")
}

pub fn export_format_ok(s: &str) -> bool {
    matches!(s, "mbox" | "eml" | "ics" | "csv" | "json")
}

/// Migration control: (nayi state, last_error saaf karna?, finished_at lagana?, last_error text)
pub fn control_action(a: &str) -> Option<(&'static str, bool, bool, Option<&'static str>)> {
    match a {
        "pause" => Some(("paused", false, false, None)),
        "resume" => Some(("queued", false, false, None)),
        "retry" => Some(("queued", true, false, None)),
        "cancel" => Some(("failed", false, true, Some("cancelled by user"))),
        _ => None,
    }
}

/// Drift: recommended None => None (score nahi). current = value ya default ya "null" (JS String(null) jaisa).
/// Barabar => aligned; warna recommended "true" thi aur user ne hataya => risky; baaqi loose.
pub fn drift_of(recommended: Option<&str>, default: Option<&str>, value: Option<&str>) -> Option<&'static str> {
    let rec = recommended?;
    let cur = value.or(default).unwrap_or("null");
    if cur == rec {
        Some("aligned")
    } else if rec == "true" {
        Some("risky")
    } else {
        Some("loose")
    }
}

/// (key, count) — count ghatte, phir key barhte; sirf pehle `n`.
pub fn top_keys(keys: &[String], n: usize) -> Vec<(String, usize)> {
    let mut m: Vec<(String, usize)> = Vec::new();
    for k in keys {
        match m.iter_mut().find(|(x, _)| x == k) {
            Some(e) => e.1 += 1,
            None => m.push((k.clone(), 1)),
        }
    }
    m.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
    m.truncate(n);
    m
}

/// Epoch seconds => "YYYY-MM-DDTHH:MM:SSZ" (PostgREST gte filter ke liye; chrono crate nahi).
pub fn iso_utc(epoch: i64) -> String {
    let (days, secs) = (epoch.div_euclid(86400), epoch.rem_euclid(86400));
    let z = days + 719468;
    let era = z.div_euclid(146097);
    let doe = z.rem_euclid(146097);
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z", secs / 3600, (secs % 3600) / 60, secs % 60)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names() {
        assert_eq!(PROCS.len(), 18);
        assert!(owns_name("settings.save"));
        assert!(owns_name("integrations.delivery"));
        assert!(!owns_name("settings.drift"));
        assert!(!owns_name("settings.simulate"));
        assert!(!owns_name("integrations.leoActions"));
        assert!(founder_only("founderSettings.overview"));
        assert!(founder_only("founderSecurity.overview"));
        assert!(!founder_only("settings.list"));
    }
    #[test]
    fn scopes_and_keys() {
        assert!(scope_ok("privacy"));
        assert!(!scope_ok("admin"));
        assert!(!scope_ok(""));
        assert!(key_ok("notifications.digest:daily-1"));
        assert!(!key_ok(""));
        assert!(!key_ok("a b"));
        assert!(!key_ok("a&b=1"));
        assert!(!key_ok(&"k".repeat(121)));
    }
    #[test]
    fn ids() {
        assert!(uuid_ok("123e4567-e89b-12d3-a456-426614174000"));
        assert!(!uuid_ok("123e4567e89b12d3a456426614174000"));
        assert!(!uuid_ok("123e4567-e89b-12d3-a456-42661417400g"));
        assert!(!uuid_ok("1 or true"));
        assert!(provider_ok("imap"));
        assert!(provider_ok("google-oauth"));
        assert!(!provider_ok("Gmail"));
        assert!(!provider_ok(""));
    }
    #[test]
    fn emails_hosts_ports() {
        assert!(email_ok("ali@gmail.com"));
        assert!(email_ok(" ali@gmail.com "));
        assert!(!email_ok("ali"));
        assert!(!email_ok("a@b@c.com"));
        assert!(!email_ok("a b@c.com"));
        assert!(!email_ok("a,b@c.com"));
        assert!(!email_ok("x*@c.com"));
        assert!(account_ok("user name") && !account_ok("") && !account_ok("a\nb"));
        assert!(host_ok("imap.gmail.com"));
        assert!(!host_ok("-bad.com"));
        assert!(!host_ok("a..com"));
        assert!(!host_ok("a b.com"));
        assert!(!host_ok(""));
        assert!(port_ok(993));
        assert!(!port_ok(0));
        assert!(!port_ok(70000));
    }
    #[test]
    fn exports_and_control() {
        assert!(export_scope_ok("everything") && !export_scope_ok("all"));
        assert!(export_format_ok("mbox") && !export_format_ok("pdf"));
        assert_eq!(control_action("pause"), Some(("paused", false, false, None)));
        assert_eq!(control_action("resume"), Some(("queued", false, false, None)));
        assert_eq!(control_action("retry"), Some(("queued", true, false, None)));
        assert_eq!(control_action("cancel"), Some(("failed", false, true, Some("cancelled by user"))));
        assert_eq!(control_action("delete"), None);
    }
    #[test]
    fn drift() {
        assert_eq!(drift_of(None, Some("a"), Some("b")), None);
        assert_eq!(drift_of(Some("true"), Some("true"), None), Some("aligned"));
        assert_eq!(drift_of(Some("true"), None, Some("false")), Some("risky"));
        assert_eq!(drift_of(Some("daily"), None, Some("weekly")), Some("loose"));
        assert_eq!(drift_of(Some("null"), None, None), Some("aligned"));
        assert_eq!(drift_of(Some("x"), Some("x"), Some("y")), Some("loose"));
    }
    #[test]
    fn top() {
        let k: Vec<String> = ["b", "a", "b", "c", "a", "b"].iter().map(|s| s.to_string()).collect();
        assert_eq!(top_keys(&k, 2), vec![("b".to_string(), 3), ("a".to_string(), 2)]);
        let tie: Vec<String> = ["z", "y"].iter().map(|s| s.to_string()).collect();
        assert_eq!(top_keys(&tie, 8), vec![("y".to_string(), 1), ("z".to_string(), 1)]);
        assert!(top_keys(&[], 8).is_empty());
    }
    #[test]
    fn iso() {
        assert_eq!(iso_utc(0), "1970-01-01T00:00:00Z");
        assert_eq!(iso_utc(1_700_000_000), "2023-11-14T22:13:20Z");
        assert_eq!(iso_utc(951_782_400), "2000-02-29T00:00:00Z");
    }
}
