// basx_core — Basic-baaqi chhote endpoints ka dimaag (storage, support, dashboard.ai-usage, workspace.setActive). std-only.
// Bun twins: storage.ts, support.ts, dashboard.ts, workspace.ts. Sab plans (Basic + Pro) — koi plan gate nahi.

pub const PROCS: [&str; 10] = [
    "storage.state", "storage.preflight", "storage.reserve", "storage.commit", "storage.release",
    "support.sla", "support.drafts", "support.draftDiscard", "dashboard.ai-usage", "workspace.setActive",
];

pub fn owns_name(p: &str) -> bool {
    PROCS.contains(&p)
}

pub fn public_name(p: &str) -> bool {
    p == "support.sla"
}

pub const KINDS: [&str; 3] = ["email", "attachment", "file"];

/// {mailbox, bytes, kind} jaanch — Bun parseBody jaisa. Err = (code, detail).
pub fn parse_storage(mailbox: &str, bytes: Option<f64>, kind: &str) -> Result<(String, i64, String), &'static str> {
    let m = mailbox.trim().to_lowercase();
    let k = if kind.is_empty() { "attachment" } else { kind };
    if m.is_empty() || !KINDS.contains(&k) {
        return Err("mailbox + kind (email|attachment|file)");
    }
    let b = bytes.filter(|x| x.is_finite()).map(|x| x.floor()).unwrap_or(0.0).max(0.0) as i64;
    Ok((m, b, k.to_string()))
}

/// Draft discard / list ke liye uuid jaisi id (sirf hex aur '-').
pub fn safe_id(id: &str) -> Option<String> {
    let t = id.trim();
    if t.len() >= 8 && t.len() <= 64 && t.chars().all(|c| c.is_ascii_hexdigit() || c == '-') {
        Some(t.to_lowercase())
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn storage_parse() {
        assert_eq!(parse_storage(" A@B.com ", Some(10.9), "file"), Ok(("a@b.com".into(), 10, "file".into())));
        assert_eq!(parse_storage("a@b.com", None, ""), Ok(("a@b.com".into(), 0, "attachment".into())));
        assert_eq!(parse_storage("a@b.com", Some(-5.0), "email").unwrap().1, 0);
        assert_eq!(parse_storage("a@b.com", Some(f64::NAN), "email").unwrap().1, 0);
        assert!(parse_storage("", Some(1.0), "email").is_err());
        assert!(parse_storage("a@b.com", Some(1.0), "video").is_err());
    }
    #[test]
    fn ids_and_names() {
        assert_eq!(safe_id("ABCDEF12-3456"), Some("abcdef12-3456".into()));
        assert_eq!(safe_id("x;drop"), None);
        assert_eq!(safe_id("ab"), None);
        assert!(owns_name("storage.reserve") && !owns_name("storage.sweep"));
        assert!(public_name("support.sla") && !public_name("support.drafts"));
    }
}
