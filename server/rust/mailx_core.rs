// ============================================================================
// mailx_core.rs — M1/M2 (Pro mail actions on Rust PRIMARY): PURE logic, std only (server par pre-flight `rustc --test`).
// Same rules as the Bun fallback (server/routes/mail.ts, mail-compose.ts) so a call gives the same answer on either side.
// I/O (PostgREST, resolve_plan, GoTrue) lives in mailx_glue.rs.
// ============================================================================

pub const FOLDERS: [&str; 8] = ["inbox", "assigned", "waiting", "sent", "drafts", "archive", "spam", "trash"];
pub const STATUSES: [&str; 3] = ["open", "waiting", "done"];
pub const MAX_TEMPLATES_PER_USER: i64 = 50;

pub fn is_uuid(v: &str) -> bool {
    v.len() == 36
        && v.chars().enumerate().all(|(i, c)| match i {
            8 | 13 | 18 | 23 => c == '-',
            _ => c.is_ascii_hexdigit(),
        })
}

pub fn valid_folder(f: &str) -> bool {
    FOLDERS.contains(&f)
}

pub fn valid_status(s: &str) -> bool {
    STATUSES.contains(&s)
}

/// Basic is the only tier without Pro-card features (family / personal accounts resolve to a tier via resolve_plan).
pub fn plan_allows_pro(plan: &str) -> bool {
    plan != "basic"
}

/// Percent-encode everything except unreserved characters (PostgREST filter values: no filter injection).
pub fn pct(v: &str) -> String {
    let mut out = String::new();
    for b in v.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{:02X}", b));
        }
    }
    out
}

/// `until` for snooze: "" = bring the thread back. Otherwise an ISO-like timestamp (digits - : T Z . +), 10..=40 chars.
pub fn check_until(raw: &str) -> Result<Option<String>, &'static str> {
    let t = raw.trim();
    if t.is_empty() {
        return Ok(None);
    }
    let shape = t.chars().all(|c| c.is_ascii_digit() || matches!(c, '-' | ':' | 'T' | 'Z' | '.' | '+'));
    if !shape || t.len() < 10 || t.len() > 40 {
        return Err("bad_until");
    }
    Ok(Some(t.to_string()))
}

/// Label names go into a PostgREST filter: same limits as Bun (<=20 each, <=60 chars, no `,` `(` `)`).
pub fn check_labels(add: &[String], remove: &[String]) -> Result<(), &'static str> {
    if add.len() > 20 || remove.len() > 20 {
        return Err("bad_label");
    }
    if add.iter().chain(remove.iter()).any(|n| n.chars().count() > 60 || n.contains(|c| matches!(c, ',' | '(' | ')'))) {
        return Err("bad_label");
    }
    Ok(())
}

pub fn check_template(name: &str, body: &str) -> Result<(), &'static str> {
    let n = name.trim();
    if n.is_empty() || n.chars().count() > 80 {
        return Err("bad_name");
    }
    if body.trim().is_empty() || body.chars().count() > 20000 {
        return Err("bad_body");
    }
    Ok(())
}

/// `{{variable}}` names in a template body (unique, first 30), like Bun's /{{\s*([\w.]+)\s*}}/g.
pub fn template_vars(body: &str) -> Vec<String> {
    let mut vars: Vec<String> = Vec::new();
    let mut rest = body;
    while let Some(i) = rest.find("{{") {
        let after = &rest[i + 2..];
        match after.find("}}") {
            Some(j) => {
                let v = after[..j].trim();
                if !v.is_empty()
                    && v.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '.')
                    && !vars.iter().any(|x| x == v)
                    && vars.len() < 30
                {
                    vars.push(v.to_string());
                }
                rest = &after[j + 2..];
            }
            None => break,
        }
    }
    vars
}

/// Epoch seconds -> `YYYY-MM-DDTHH:MM:SS` (UTC). Lexically comparable with the first 19 chars of a Postgres timestamptz in UTC.
pub fn iso_prefix(secs: i64) -> String {
    let days = secs.div_euclid(86_400);
    let rem = secs.rem_euclid(86_400);
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + if m <= 2 { 1 } else { 0 };
    format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}", y, m, d, rem / 3600, (rem % 3600) / 60, rem % 60)
}

/// Is `until` (Postgres timestamptz text) still in the future compared with `now` (an `iso_prefix`)?
pub fn is_future(until: &str, now: &str) -> bool {
    until.len() >= 19 && until.get(..19).map(|u| u > now).unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn uuid_and_enums() {
        assert!(is_uuid("0af789df-86e8-47b0-8e65-797ec7ed9e46"));
        assert!(!is_uuid("0af789df-86e8-47b0-8e65-797ec7ed9e4"));
        assert!(!is_uuid("x&y=1"));
        assert!(valid_folder("archive") && !valid_folder("snoozed") && !valid_folder("x"));
        assert!(valid_status("done") && !valid_status("snoozed"));
    }

    #[test]
    fn plan_gate() {
        assert!(!plan_allows_pro("basic"));
        for p in ["pro", "business", "business_pro"] {
            assert!(plan_allows_pro(p));
        }
    }

    #[test]
    fn until_rules() {
        assert_eq!(check_until("  "), Ok(None));
        assert_eq!(check_until("2026-10-24T12:00:00.000Z"), Ok(Some("2026-10-24T12:00:00.000Z".into())));
        assert_eq!(check_until("bad;drop"), Err("bad_until"));
        assert_eq!(check_until("2026"), Err("bad_until"));
    }

    #[test]
    fn labels_rules() {
        assert!(check_labels(&["Sales".into()], &[]).is_ok());
        assert!(check_labels(&["a,b".into()], &[]).is_err());
        assert!(check_labels(&["a(b)".into()], &[]).is_err());
        assert!(check_labels(&["x".repeat(61)], &[]).is_err());
        assert!(check_labels(&(0..21).map(|i| i.to_string()).collect::<Vec<_>>(), &[]).is_err());
    }

    #[test]
    fn template_rules_and_vars() {
        assert!(check_template("Hi", "x").is_ok());
        assert_eq!(check_template("", "x"), Err("bad_name"));
        assert_eq!(check_template(&"n".repeat(81), "x"), Err("bad_name"));
        assert_eq!(check_template("a", "  "), Err("bad_body"));
        assert_eq!(check_template("a", &"b".repeat(20001)), Err("bad_body"));
        assert_eq!(template_vars("Hello {{first_name}} and {{ first_name }} {{a.b}} {{bad name}} {{"), vec!["first_name", "a.b"]);
    }

    #[test]
    fn pct_encodes() {
        assert_eq!(pct("a b,c"), "a%20b%2Cc");
        assert_eq!(pct("ok-1_2.3~"), "ok-1_2.3~");
    }

    #[test]
    fn time_prefix() {
        assert_eq!(iso_prefix(0), "1970-01-01T00:00:00");
        assert_eq!(iso_prefix(1_784_894_400), "2026-07-24T12:00:00");
        assert_eq!(iso_prefix(1_792_843_200), "2026-10-24T12:00:00");
        let now = iso_prefix(1_792_843_200);
        assert!(is_future("2026-10-24T12:00:01+00:00", &now));
        assert!(!is_future("2026-10-24T12:00:00+00:00", &now));
        assert!(!is_future("2026-10-24", &now));
    }
}
