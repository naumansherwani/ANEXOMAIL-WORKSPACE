// ============================================================================
// people_core.rs — "bring your address book with you" (Google Contacts / Outlook / Zoho / Apple / LinkedIn).
//
// FUNCTIONAL CORE of the Rust port of server/lib/import-rows.ts (+ the pure decisions of
// server/routes/people-import.ts). std-only on purpose:
//   * no crate can be fetched in the build sandbox, so `rustc --edition 2021 --test server/rust/people_core.rs`
//     runs every test right here, and again on the server before the installer touches anything;
//   * no I/O, no clock, no randomness => the same input always gives the same answer.
// The thin I/O half (PostgREST, auth, plan lookup) is people_glue.rs.
//
// Rule that does not move: the browser reads the file but is NEVER trusted. Every row is re-validated, trimmed,
// size-capped and de-duplicated here before anything touches a table. Limits stay in step with
// src/lib/contacts-import.ts (500 rows per request, same field caps).
// ============================================================================
#![allow(dead_code)]

use std::collections::HashSet;

pub const MAX_IMPORT_ROWS: usize = 500;

/// One element of the `rows` array as the browser sent it. `None` for a row that is not an object at all.
/// A field that is not a string arrives as `None` (same as the TypeScript `typeof v !== "string"`).
#[derive(Debug, Clone, Default, PartialEq)]
pub struct RawRow {
    pub email: Option<String>,
    pub display_name: Option<String>,
    pub company: Option<String>,
    pub title: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CleanRow {
    pub email: String,
    pub display_name: Option<String>,
    pub company: Option<String>,
    pub title: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct CleanResult {
    pub rows: Vec<CleanRow>,
    pub invalid: usize,
    pub duplicate: usize,
    /// More than MAX_IMPORT_ROWS were sent: the extra rows were ignored, not stored.
    pub too_many: bool,
}

/// JavaScript's `\s` (what the TypeScript twin collapses and trims) — Rust's `is_whitespace` differs on exactly two code points.
fn js_space(c: char) -> bool {
    (c.is_whitespace() && c != '\u{85}') || c == '\u{feff}'
}

fn js_trim(s: &str) -> &str {
    s.trim_matches(js_space)
}

/// Control characters become a space, runs of whitespace collapse to one space, trimmed, capped at `max` characters.
/// Empty after cleaning => None. (The cap is applied last, as in the TypeScript, so a cut can leave one trailing space.)
pub fn clean_text(v: &str, max: usize) -> Option<String> {
    let mut out = String::with_capacity(v.len().min(max * 4 + 4));
    let mut last_space = false;
    for c in v.chars() {
        let ctl = (c as u32) <= 0x1f || (c as u32) == 0x7f;
        if ctl || js_space(c) {
            if !last_space {
                out.push(' ');
                last_space = true;
            }
        } else {
            out.push(c);
            last_space = false;
        }
    }
    let s = js_trim(&out);
    if s.is_empty() {
        None
    } else {
        Some(s.chars().take(max).collect())
    }
}

/// Characters that may appear in an address part: anything except whitespace and  @ < > ( ) [ ] , ; : " \
fn email_char_ok(c: char) -> bool {
    !(js_space(c)
        || matches!(
            c,
            '@' | '<' | '>' | '(' | ')' | '[' | ']' | ',' | ';' | ':' | '"' | '\\'
        ))
}

/// Same rule as the TypeScript `EMAIL_RE`, written by hand:
///   `^[^\s@<>()[\],;:"\\]{1,64}@[^\s@<>()[\],;:"\\]+\.[A-Za-z]{2,}$`, trimmed + lower-cased first, max 254 characters.
pub fn clean_email(v: &str) -> Option<String> {
    let e = js_trim(v).to_lowercase();
    if e.chars().count() > 254 {
        return None;
    }
    let at = e.find('@')?;
    let (local, rest) = (&e[..at], &e[at + 1..]);
    let n = local.chars().count();
    if n == 0 || n > 64 || !local.chars().all(email_char_ok) {
        return None;
    }
    if rest.contains('@') {
        return None;
    }
    let dot = rest.rfind('.')?;
    let (host, tld) = (&rest[..dot], &rest[dot + 1..]);
    if host.is_empty() || !host.chars().all(email_char_ok) {
        return None;
    }
    if tld.chars().count() < 2 || !tld.chars().all(|c| c.is_ascii_alphabetic()) {
        return None;
    }
    Some(e)
}

/// `input[i] == None` means "this element was not an object". Validates, counts and de-duplicates.
pub fn clean_import(input: &[Option<RawRow>]) -> CleanResult {
    let mut out = CleanResult::default();
    let mut seen: HashSet<String> = HashSet::new();
    for (i, r) in input.iter().enumerate() {
        if i >= MAX_IMPORT_ROWS {
            out.too_many = true;
            break;
        }
        let raw = match r {
            Some(r) => r,
            None => {
                out.invalid += 1;
                continue;
            }
        };
        let email = match raw.email.as_deref().and_then(clean_email) {
            Some(e) => e,
            None => {
                out.invalid += 1;
                continue;
            }
        };
        if !seen.insert(email.clone()) {
            out.duplicate += 1;
            continue;
        }
        out.rows.push(CleanRow {
            email,
            display_name: raw.display_name.as_deref().and_then(|t| clean_text(t, 200)),
            company: raw.company.as_deref().and_then(|t| clean_text(t, 200)),
            title: raw.title.as_deref().and_then(|t| clean_text(t, 200)),
            phone: raw.phone.as_deref().and_then(|t| clean_text(t, 40)),
        });
    }
    out
}

/// Webmail domains are not "a company": a contact on gmail.com must not get gmail.com as its company.
const FREE_MAIL: &[&str] = &[
    "gmail.com",
    "googlemail.com",
    "outlook.com",
    "hotmail.com",
    "hotmail.co.uk",
    "live.com",
    "msn.com",
    "yahoo.com",
    "yahoo.co.uk",
    "ymail.com",
    "icloud.com",
    "me.com",
    "mac.com",
    "aol.com",
    "proton.me",
    "protonmail.com",
    "pm.me",
    "gmx.com",
    "gmx.net",
    "mail.com",
    "zoho.com",
    "yandex.com",
    "fastmail.com",
    "anexomail.com",
];

pub fn company_domain_of(email: &str) -> Option<String> {
    let d = email.split('@').nth(1).unwrap_or("").to_lowercase();
    if d.is_empty() || FREE_MAIL.contains(&d.as_str()) {
        None
    } else {
        Some(d)
    }
}

/// What goes in `contacts.notes` for an imported person: the facts the contacts table has no column for.
pub fn import_notes(company: Option<&str>, phone: Option<&str>) -> Option<String> {
    let mut parts: Vec<String> = Vec::new();
    if let Some(c) = company.filter(|c| !c.is_empty()) {
        parts.push(format!("Company: {c}"));
    }
    if let Some(p) = phone.filter(|p| !p.is_empty()) {
        parts.push(format!("Phone: {p}"));
    }
    if parts.is_empty() {
        None
    } else {
        Some(parts.join(" · "))
    }
}

/// Result of "who in this batch is already in the organisation's People?".
#[derive(Debug, Clone, PartialEq)]
pub struct ContactSplit<T> {
    pub fresh: Vec<T>,
    pub existing: usize,
}

/// Anyone already known (by address, case-insensitive) is left alone — an imported name must never overwrite what mail taught us.
pub fn split_known<T: Clone>(
    rows: &[T],
    email_of: impl Fn(&T) -> &str,
    known: &HashSet<String>,
) -> ContactSplit<T> {
    let mut fresh = Vec::new();
    for r in rows {
        if !known.contains(&email_of(r).to_lowercase()) {
            fresh.push(r.clone());
        }
    }
    let existing = rows.len() - fresh.len();
    ContactSplit { fresh, existing }
}

#[derive(Debug, Clone, PartialEq)]
pub struct LeadSplit {
    pub fresh: Vec<CleanRow>,
    pub already_leads: usize,
    pub already_in_people: usize,
}

/// Anyone who is already a lead (in the caller's scope) or already a person in the organisation is left alone.
pub fn split_new_leads(
    rows: &[CleanRow],
    leads: &HashSet<String>,
    people: &HashSet<String>,
) -> LeadSplit {
    let mut s = LeadSplit {
        fresh: Vec::new(),
        already_leads: 0,
        already_in_people: 0,
    };
    for r in rows {
        if leads.contains(&r.email) {
            s.already_leads += 1;
        } else if people.contains(&r.email) {
            s.already_in_people += 1;
        } else {
            s.fresh.push(r.clone());
        }
    }
    s
}

/// Lead ids come from the browser. Keep only id-shaped strings (letters, digits, `-`, `_`), at most 64 chars,
/// at most MAX_IMPORT_ROWS of them, no repeats. Anything else could not match a row anyway.
pub fn safe_ids(values: &[String]) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for v in values.iter().take(MAX_IMPORT_ROWS) {
        let ok = !v.is_empty()
            && v.len() <= 64
            && v.chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_');
        if ok && !out.contains(v) {
            out.push(v.clone());
        }
    }
    out
}

/// Leads are part of CRM, which starts on Pro. Anything that is not exactly "basic" (or unknown) is allowed to use Leads.
/// An unknown / empty plan counts as basic (fail closed).
pub fn crm_allowed(tier: &str) -> bool {
    !matches!(tier.trim().to_lowercase().as_str(), "" | "basic")
}

/// Pro sees its own leads only; Business plans see everyone in the organisation (same scoping as the CRM page).
pub fn lead_owners(tier: &str, me: &str, org_members: &[String]) -> Vec<String> {
    let me = me.trim().to_lowercase();
    if tier.trim().to_lowercase() == "pro" {
        return vec![me];
    }
    let mut out = vec![me];
    for m in org_members {
        let m = m.trim().to_lowercase();
        if !m.is_empty() && !out.contains(&m) {
            out.push(m);
        }
    }
    out
}

/// Percent-encode a query value (PostgREST decodes it before parsing, so list punctuation may be encoded too).
pub fn pct(v: &str) -> String {
    let mut o = String::with_capacity(v.len() + 8);
    for b in v.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'.' | b'_' | b'~' | b'@') {
            o.push(b as char);
        } else {
            o.push_str(&format!("%{:02X}", b));
        }
    }
    o
}

/// PostgREST `in.(...)` list with every value double-quoted (values may legitimately contain `+`, `&`, `#`, `%` …).
pub fn in_list(values: &[String]) -> String {
    let inner: Vec<String> = values
        .iter()
        .map(|v| format!("\"{}\"", v.replace('\\', "\\\\").replace('"', "\\\"")))
        .collect();
    format!("({})", inner.join(","))
}

/// A complete, URL-safe `column=in.(...)` filter.
pub fn in_filter(column: &str, values: &[String]) -> String {
    format!("{}=in.{}", column, pct(&in_list(values)))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn raw(email: &str) -> Option<RawRow> {
        Some(RawRow {
            email: Some(email.to_string()),
            ..Default::default()
        })
    }

    #[test]
    fn email_accepts_normal_and_lowercases() {
        assert_eq!(
            clean_email("  Ayesha.Khan@Acme.CO.UK ").as_deref(),
            Some("ayesha.khan@acme.co.uk")
        );
        assert_eq!(clean_email("a+tag@x.io").as_deref(), Some("a+tag@x.io"));
        assert_eq!(clean_email("a&b@x.io").as_deref(), Some("a&b@x.io"));
        assert_eq!(clean_email("o'neil@x.ie").as_deref(), Some("o'neil@x.ie"));
    }

    #[test]
    fn email_rejects_what_is_not_an_address() {
        for bad in [
            "",
            "nobody",
            "a@b",
            "a@@b.com",
            "a b@c.com",
            "a@b.c",
            "<script>@x.io",
            "x@y.io,z@y.io",
            "a@b.c1",
            "@x.io",
            "a@.io",
            "a@x.",
            "a@x.i0",
            "a\"b@x.io",
            "a(b)@x.io",
            "a@x y.io",
            "a@x.io;b@y.io",
            "Bob <bob@x.io>",
            "mailto:bob@x.io",
        ] {
            assert_eq!(clean_email(bad), None, "{bad:?} must be rejected");
        }
        let long_local = format!("{}@x.io", "a".repeat(65));
        assert_eq!(clean_email(&long_local), None);
        let ok_local = format!("{}@x.io", "a".repeat(64));
        assert!(clean_email(&ok_local).is_some());
        let long_all = format!("a@{}.io", "b".repeat(260));
        assert_eq!(clean_email(&long_all), None);
    }

    #[test]
    fn email_double_dot_host_matches_the_typescript_regex() {
        // the TypeScript regex allows dots inside the host part, so "b..com" passes there; stay identical
        assert_eq!(clean_email("a@b..com").as_deref(), Some("a@b..com"));
        assert_eq!(clean_email("a@b.com.").as_deref(), None);
    }

    #[test]
    fn email_unicode_whitespace_is_trimmed_like_javascript() {
        assert_eq!(
            clean_email("\u{feff}a@x.io\u{a0}").as_deref(),
            Some("a@x.io")
        );
        assert_eq!(clean_email("a@x.io\u{2003}").as_deref(), Some("a@x.io"));
    }

    #[test]
    fn text_collapses_strips_and_caps() {
        assert_eq!(
            clean_text("  Ayesha \n\t Rahman  ", 200).as_deref(),
            Some("Ayesha Rahman")
        );
        assert_eq!(clean_text("a\u{0}b\u{7f}c", 200).as_deref(), Some("a b c"));
        assert_eq!(clean_text("   \n ", 200), None);
        assert_eq!(clean_text("", 200), None);
        assert_eq!(clean_text("abcdef", 3).as_deref(), Some("abc"));
        // cap is applied last: a cut can leave a trailing space (same as the TypeScript)
        assert_eq!(clean_text("ab cd", 3).as_deref(), Some("ab "));
        // multi-byte characters are cut on character boundaries, never in the middle
        assert_eq!(clean_text("ایاز احمد", 4).as_deref(), Some("ایاز"));
    }

    #[test]
    fn import_counts_invalid_and_duplicates_and_caps_fields() {
        let rows = vec![
            Some(RawRow {
                email: Some("Ayesha@Zephyr.io".into()),
                display_name: Some("  Ayesha   Rahman ".into()),
                company: Some("Zephyr Labs".into()),
                title: Some("Head of Ops".into()),
                phone: Some("+44 7700 900123".into()),
            }),
            raw("ayesha@zephyr.io"), // duplicate (case-insensitive)
            raw("not-an-email"),
            None,                    // not an object
            Some(RawRow::default()), // object with no email
            raw("tom@northwind.co.uk"),
        ];
        let r = clean_import(&rows);
        assert_eq!(r.rows.len(), 2);
        assert_eq!(r.invalid, 3);
        assert_eq!(r.duplicate, 1);
        assert!(!r.too_many);
        assert_eq!(r.rows[0].email, "ayesha@zephyr.io");
        assert_eq!(r.rows[0].display_name.as_deref(), Some("Ayesha Rahman"));
        assert_eq!(r.rows[1].display_name, None);
    }

    #[test]
    fn import_stops_at_the_cap_and_says_so() {
        let rows: Vec<Option<RawRow>> = (0..MAX_IMPORT_ROWS + 25)
            .map(|i| raw(&format!("p{i}@x.io")))
            .collect();
        let r = clean_import(&rows);
        assert_eq!(r.rows.len(), MAX_IMPORT_ROWS);
        assert!(r.too_many);
        let exact: Vec<Option<RawRow>> = (0..MAX_IMPORT_ROWS)
            .map(|i| raw(&format!("p{i}@x.io")))
            .collect();
        assert!(!clean_import(&exact).too_many);
    }

    #[test]
    fn empty_input_is_empty_not_an_error() {
        let r = clean_import(&[]);
        assert_eq!(
            (r.rows.len(), r.invalid, r.duplicate, r.too_many),
            (0, 0, 0, false)
        );
    }

    #[test]
    fn webmail_is_not_a_company() {
        assert_eq!(company_domain_of("x@gmail.com"), None);
        assert_eq!(company_domain_of("x@GMAIL.com"), None);
        assert_eq!(company_domain_of("x@anexomail.com"), None);
        assert_eq!(
            company_domain_of("x@zephyrlabs.io").as_deref(),
            Some("zephyrlabs.io")
        );
        assert_eq!(company_domain_of("no-at-sign"), None);
    }

    #[test]
    fn notes_keep_only_the_facts_the_table_has_no_column_for() {
        assert_eq!(
            import_notes(Some("Zephyr"), Some("+44 1")).as_deref(),
            Some("Company: Zephyr · Phone: +44 1")
        );
        assert_eq!(
            import_notes(Some("Zephyr"), None).as_deref(),
            Some("Company: Zephyr")
        );
        assert_eq!(
            import_notes(None, Some("+44 1")).as_deref(),
            Some("Phone: +44 1")
        );
        assert_eq!(import_notes(None, None), None);
        assert_eq!(import_notes(Some(""), Some("")), None);
    }

    #[test]
    fn existing_people_are_never_touched() {
        let rows: Vec<String> = vec!["a@x.io".into(), "b@x.io".into(), "c@x.io".into()];
        let known: HashSet<String> = ["b@x.io".to_string()].into_iter().collect();
        let s = split_known(&rows, |r| r.as_str(), &known);
        assert_eq!(s.fresh, vec!["a@x.io".to_string(), "c@x.io".to_string()]);
        assert_eq!(s.existing, 1);
        let none: HashSet<String> = HashSet::new();
        assert_eq!(split_known(&rows, |r| r.as_str(), &none).existing, 0);
    }

    #[test]
    fn leads_split_counts_each_row_once() {
        let rows: Vec<CleanRow> = ["a@x.io", "b@x.io", "c@x.io", "d@x.io"]
            .iter()
            .map(|e| CleanRow {
                email: e.to_string(),
                display_name: None,
                company: None,
                title: None,
                phone: None,
            })
            .collect();
        let leads: HashSet<String> = ["a@x.io".to_string(), "b@x.io".to_string()]
            .into_iter()
            .collect();
        // b is both a lead and a person: counted as a lead only (the TypeScript counts people only when not a lead)
        let people: HashSet<String> = ["b@x.io".to_string(), "c@x.io".to_string()]
            .into_iter()
            .collect();
        let s = split_new_leads(&rows, &leads, &people);
        assert_eq!(s.already_leads, 2);
        assert_eq!(s.already_in_people, 1);
        assert_eq!(
            s.fresh.iter().map(|r| r.email.as_str()).collect::<Vec<_>>(),
            vec!["d@x.io"]
        );
    }

    #[test]
    fn lead_ids_are_shape_checked_deduped_and_capped() {
        let v: Vec<String> = vec![
            "3f2c9d1e-0000-4000-8000-000000000001".into(),
            "3f2c9d1e-0000-4000-8000-000000000001".into(),
            "".into(),
            "x\" or 1=1".into(),
            "a,b".into(),
            "lead_7".into(),
            "a".repeat(65),
        ];
        assert_eq!(
            safe_ids(&v),
            vec![
                "3f2c9d1e-0000-4000-8000-000000000001".to_string(),
                "lead_7".to_string()
            ]
        );
        let many: Vec<String> = (0..MAX_IMPORT_ROWS + 10)
            .map(|i| format!("id{i}"))
            .collect();
        assert_eq!(safe_ids(&many).len(), MAX_IMPORT_ROWS);
    }

    #[test]
    fn leads_need_a_crm_plan() {
        assert!(!crm_allowed("basic"));
        assert!(!crm_allowed(" Basic "));
        assert!(!crm_allowed(""));
        for t in ["pro", "business", "business_pro", "enterprise"] {
            assert!(crm_allowed(t), "{t}");
        }
    }

    #[test]
    fn pro_sees_own_leads_business_sees_the_organisation() {
        let members = vec![
            "Sara@Acme.io".to_string(),
            "me@acme.io".to_string(),
            "".to_string(),
        ];
        assert_eq!(
            lead_owners("pro", "Me@Acme.io", &members),
            vec!["me@acme.io".to_string()]
        );
        assert_eq!(
            lead_owners("business", "me@acme.io", &members),
            vec!["me@acme.io".to_string(), "sara@acme.io".to_string()]
        );
    }

    #[test]
    fn query_values_survive_special_characters() {
        let list = in_list(&[
            "a&b@x.io".to_string(),
            "p+q@x.io".to_string(),
            "h#sh@x.io".to_string(),
        ]);
        assert_eq!(list, "(\"a&b@x.io\",\"p+q@x.io\",\"h#sh@x.io\")");
        let f = in_filter(
            "primary_address",
            &["a&b@x.io".to_string(), "p+q@x.io".to_string()],
        );
        assert_eq!(
            f,
            "primary_address=in.%28%22a%26b@x.io%22%2C%22p%2Bq@x.io%22%29"
        );
        assert!(!f.contains('&') && !f.contains('#') && !f.contains(' '));
        assert_eq!(in_list(&["a\"b".to_string()]), "(\"a\\\"b\")");
    }
}
