// wsx_core — workspace banane ka dimaag (std-only; `rustc --edition 2021 --test`). Bun twin: server/routes/workspace.ts.
// Onboarding ka raasta: naya user ka Personal/Business workspace. Yahan sirf naam/domain/slug ke qaide — DB glue mein.

pub const PROCS: [&str; 2] = ["workspace.personal", "workspace.organisations"];

pub fn owns_name(p: &str) -> bool {
    PROCS.contains(&p)
}

/// slugify(name, uid) — Bun: lower, non [a-z0-9] runs -> '-', trim '-', 40 chars, "workspace" default, + "-" + uid[0..8].
pub fn slugify(name: &str, uid: &str) -> String {
    let mut out = String::new();
    let mut dash = false;
    for ch in name.to_lowercase().chars() {
        if ch.is_ascii_lowercase() || ch.is_ascii_digit() {
            out.push(ch);
            dash = false;
        } else if !dash {
            out.push('-');
            dash = true;
        }
    }
    let trimmed = out.trim_matches('-');
    let base: String = trimmed.chars().take(40).collect();
    let base = if base.is_empty() { "workspace".to_string() } else { base };
    let short: String = uid.chars().take(8).collect();
    format!("{base}-{short}")
}

/// Personal slug: "personal-" + uid (dashes hata kar) ke pehle 12 chars.
pub fn personal_slug(uid: &str) -> String {
    let flat: String = uid.chars().filter(|c| *c != '-').take(12).collect();
    format!("personal-{flat}")
}

/// Organisation domain saaf + jaanch. Err = (code, message) — Bun jaisi English messages.
pub fn normalize_org_domain(raw: &str) -> Result<String, &'static str> {
    let mut s = raw.trim().to_lowercase();
    for p in ["https://", "http://"] {
        if let Some(r) = s.strip_prefix(p) {
            s = r.to_string();
            break;
        }
    }
    if let Some(i) = s.find('/') {
        s.truncate(i);
    }
    if let Some(r) = s.strip_prefix("www.") {
        s = r.to_string();
    }
    if s.is_empty() {
        return Err("Organisation domain is required.");
    }
    if s == "anexomail.com" || s.ends_with(".anexomail.com") {
        return Err("Use your company domain, not anexomail.com.");
    }
    if !domain_shape_ok(&s) {
        return Err("Enter a domain like company.com.");
    }
    Ok(s)
}

/// /^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?\.[a-z]{2,24}$/
fn domain_shape_ok(s: &str) -> bool {
    let b = s.as_bytes();
    let dot = match s.rfind('.') {
        Some(i) => i,
        None => return false,
    };
    let tld = &s[dot + 1..];
    if tld.len() < 2 || tld.len() > 24 || !tld.bytes().all(|c| c.is_ascii_lowercase()) {
        return false;
    }
    let head = &s[..dot];
    if head.is_empty() || head.len() > 253 {
        return false;
    }
    let hb = head.as_bytes();
    let alnum = |c: u8| c.is_ascii_lowercase() || c.is_ascii_digit();
    if !alnum(hb[0]) || !alnum(hb[hb.len() - 1]) {
        return false;
    }
    let _ = b;
    hb.iter().all(|c| alnum(*c) || *c == b'.' || *c == b'-')
}

pub fn org_name_ok(name: &str) -> bool {
    name.trim().chars().count() >= 2
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn slugs() {
        assert_eq!(slugify("Acme Corp!!", "12345678-aaaa"), "acme-corp-12345678");
        assert_eq!(slugify("  ---  ", "abcdefghij"), "workspace-abcdefgh");
        assert_eq!(slugify("Ünï Cödé", "u1u2u3u4"), "n-c-d-u1u2u3u4");
        assert_eq!(slugify(&"a".repeat(80), "12345678").len(), 40 + 1 + 8);
        assert_eq!(personal_slug("123e4567-e89b-12d3-a456-426614174000"), "personal-123e4567e89b");
    }
    #[test]
    fn domains() {
        assert_eq!(normalize_org_domain(" HTTPS://WWW.Acme.com/path?x "), Ok("acme.com".into()));
        assert_eq!(normalize_org_domain("sub.acme.co.uk"), Ok("sub.acme.co.uk".into()));
        assert_eq!(normalize_org_domain(""), Err("Organisation domain is required."));
        assert_eq!(normalize_org_domain("https://"), Err("Organisation domain is required."));
        assert_eq!(normalize_org_domain("anexomail.com"), Err("Use your company domain, not anexomail.com."));
        assert_eq!(normalize_org_domain("mail.anexomail.com"), Err("Use your company domain, not anexomail.com."));
        assert_eq!(normalize_org_domain("nodot"), Err("Enter a domain like company.com."));
        assert_eq!(normalize_org_domain("-bad.com"), Err("Enter a domain like company.com."));
        assert_eq!(normalize_org_domain("bad-.com"), Err("Enter a domain like company.com."));
        assert_eq!(normalize_org_domain("a.c"), Err("Enter a domain like company.com."));
        assert_eq!(normalize_org_domain("a b.com"), Err("Enter a domain like company.com."));
        assert_eq!(normalize_org_domain("acme.com1"), Err("Enter a domain like company.com."));
        assert_eq!(normalize_org_domain("a.com"), Ok("a.com".into()));
    }
    #[test]
    fn names() {
        assert!(org_name_ok("Ab"));
        assert!(!org_name_ok(" a "));
        assert!(owns_name("workspace.personal") && !owns_name("workspace.setActive"));
    }
}
