// ============================================================================
// crmx_core — CRM P1 + P2 ka HISAAB (pipelines, custom fields, duplicate merge, web forms). Sirf std: installer pre-flight `rustc --edition 2021 --test`.
// Package cap yahan (limits); asli atomic cap SQL function (E92) p_cap se lagta hai. I/O crmx_glue.rs mein.
// Pro 1 pipeline / 5 fields / 1 form · Business 5 / 25 / 10 · Business Pro+ unlimited · Basic: CRM-config Pro+ hai (403).
// ============================================================================

/// Pro+ procs (Basic ko 403). Public form procs (get/submit) yahan NAHI — woh bina login ke hain.
pub fn pro_only(proc: &str) -> bool {
    matches!(
        proc,
        "crm.pipelines.list" | "crm.pipelines.save" | "crm.pipelines.delete" | "crm.fields.list" | "crm.fields.save" | "crm.fields.delete"
            | "crm.custom.set" | "crm.dups.list" | "crm.merge" | "crm.forms.list" | "crm.forms.save" | "crm.forms.delete"
            | "crm.board" | "crm.deals.move" | "crm.deals.setPipeline"
    )
}

pub fn plan_allows_pro(plan: &str) -> bool {
    let p = plan.trim().to_lowercase().replace([' ', '-'], "_");
    p.starts_with("ai_") || matches!(p.as_str(), "pro" | "business" | "business_pro" | "businesspro" | "enterprise" | "business_premium" | "businesspremium")
}

/// -1 = unlimited (SQL p_cap).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Limits {
    pub pipelines: i32,
    pub fields: i32,
    pub forms: i32,
}

pub fn limits(plan: &str) -> Option<Limits> {
    let p = plan.trim().to_lowercase().replace([' ', '-'], "_");
    match p.as_str() {
        "pro" => Some(Limits { pipelines: 1, fields: 5, forms: 1 }),
        "business" => Some(Limits { pipelines: 5, fields: 25, forms: 10 }),
        "business_pro" | "businesspro" | "enterprise" | "business_premium" | "businesspremium" => Some(Limits { pipelines: -1, fields: -1, forms: -1 }),
        s if s.starts_with("ai_") => Some(Limits { pipelines: -1, fields: -1, forms: -1 }),
        _ => None,
    }
}

/// `^[a-z][a-z0-9_]{0,29}$`
pub fn key_ok(k: &str) -> bool {
    let b = k.as_bytes();
    !b.is_empty() && b.len() <= 30 && b[0].is_ascii_lowercase() && b.iter().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || *c == b'_')
}

/// "Deal Size (GBP)" -> "deal_size_gbp"; khali/ghalat shuruaat => None.
pub fn slugify(label: &str) -> Option<String> {
    let mut out = String::new();
    let mut last_us = true;
    for ch in label.trim().to_lowercase().chars() {
        if ch.is_ascii_alphanumeric() {
            out.push(ch);
            last_us = false;
        } else if !last_us {
            out.push('_');
            last_us = true;
        }
    }
    let out = out.trim_matches('_').to_string();
    let out: String = out.chars().take(30).collect();
    let out = out.trim_end_matches('_').to_string();
    if key_ok(&out) { Some(out) } else { None }
}

pub fn field_kind_ok(k: &str) -> bool {
    matches!(k, "text" | "number" | "date" | "select" | "checkbox")
}

/// select ke options: trim, khali nikalo, 40 char, duplicate nikalo, max 30. Select ko kam se kam 1 option chahiye.
pub fn clean_options(kind: &str, raw: &[String]) -> Result<Vec<String>, &'static str> {
    if kind != "select" {
        return Ok(vec![]);
    }
    let mut out: Vec<String> = vec![];
    for o in raw {
        let t: String = o.trim().chars().take(40).collect();
        if !t.is_empty() && !out.iter().any(|x| x.eq_ignore_ascii_case(&t)) {
            out.push(t);
        }
    }
    if out.is_empty() {
        return Err("select_needs_options");
    }
    if out.len() > 30 {
        return Err("too_many_options");
    }
    Ok(out)
}

fn valid_date(s: &str) -> bool {
    let p: Vec<&str> = s.split('-').collect();
    if p.len() != 3 || p[0].len() != 4 || p[1].len() != 2 || p[2].len() != 2 {
        return false;
    }
    let (Ok(y), Ok(m), Ok(d)) = (p[0].parse::<i32>(), p[1].parse::<u32>(), p[2].parse::<u32>()) else { return false };
    let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
    let dim = match m {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 => if leap { 29 } else { 28 },
        _ => return false,
    };
    (1900..=2200).contains(&y) && (1..=dim).contains(&d)
}

/// Ek custom value check. Ok(normalised) ya Err(code). Khali string = "hatao" (caller null karta hai).
pub fn check_value(kind: &str, options: &[String], v: &str) -> Result<String, &'static str> {
    let t = v.trim();
    match kind {
        "text" => if t.chars().count() <= 500 { Ok(t.to_string()) } else { Err("too_long") },
        "number" => match t.parse::<f64>() {
            Ok(n) if n.is_finite() && n.abs() < 1e15 => Ok(t.to_string()),
            _ => Err("not_a_number"),
        },
        "date" => if valid_date(t) { Ok(t.to_string()) } else { Err("not_a_date") },
        "checkbox" => match t {
            "true" | "false" => Ok(t.to_string()),
            _ => Err("not_a_checkbox"),
        },
        "select" => options.iter().find(|o| o.eq_ignore_ascii_case(t)).cloned().ok_or("not_an_option"),
        _ => Err("bad_kind"),
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct StageIn {
    pub key: String,
    pub label: String,
    pub probability: i64,
    pub kind: String,
}

/// 2..12 stage, key slug + unique, label 1..40, probability 0..100, kind open/won/lost, kam se kam ek open aur ek closed (won ya lost).
pub fn check_stages(st: &[StageIn]) -> Result<(), &'static str> {
    if st.len() < 2 || st.len() > 12 {
        return Err("bad_stages");
    }
    for (i, s) in st.iter().enumerate() {
        if !key_ok(&s.key) || s.label.trim().is_empty() || s.label.trim().chars().count() > 40 || !(0..=100).contains(&s.probability) || !matches!(s.kind.as_str(), "open" | "won" | "lost") {
            return Err("bad_stage");
        }
        if st[..i].iter().any(|x| x.key == s.key) {
            return Err("duplicate_stage");
        }
        if s.kind == "won" && s.probability != 100 {
            return Err("won_must_be_100");
        }
        if s.kind == "lost" && s.probability != 0 {
            return Err("lost_must_be_0");
        }
    }
    if !st.iter().any(|s| s.kind == "open") || !st.iter().any(|s| s.kind != "open") {
        return Err("needs_open_and_closed");
    }
    Ok(())
}

pub fn form_field_kind_ok(k: &str) -> bool {
    matches!(k, "text" | "email" | "number" | "date" | "select" | "textarea")
}

pub fn email_shape_ok(e: &str) -> bool {
    let e = e.trim();
    if e.len() > 254 || e.chars().any(|c| c.is_whitespace()) {
        return false;
    }
    let mut it = e.splitn(2, '@');
    let (l, d) = (it.next().unwrap_or(""), it.next().unwrap_or(""));
    !l.is_empty() && d.contains('.') && !d.starts_with('.') && !d.ends_with('.') && !d.contains('@')
}

/// Form ka fields: <=12, key slug unique, "email" required hona lazmi.
pub fn check_form_fields(keys_kinds_required: &[(String, String, bool)]) -> Result<(), &'static str> {
    if keys_kinds_required.is_empty() || keys_kinds_required.len() > 12 {
        return Err("bad_fields");
    }
    for (i, (k, kind, _)) in keys_kinds_required.iter().enumerate() {
        if !key_ok(k) || !form_field_kind_ok(kind) {
            return Err("bad_field");
        }
        if keys_kinds_required[..i].iter().any(|x| &x.0 == k) {
            return Err("duplicate_field");
        }
    }
    match keys_kinds_required.iter().find(|x| x.0 == "email") {
        Some((_, _, true)) => Ok(()),
        _ => Err("email_required"),
    }
}

pub fn slug_ok(s: &str) -> bool {
    s.len() == 16 && s.bytes().all(|c| c.is_ascii_digit() || (b'a'..=b'f').contains(&c))
}

/// Spam score: honeypot bhara = 5 (seedha band); 1.5 sec se tez bhara = +3; 3+ link = +2; sirf link jaisa text = +1. >=5 ko SQL chup-chap quietly drop karta hai.
pub fn spam_score(honeypot: &str, elapsed_ms: i64, text_blob: &str) -> i32 {
    let mut s = 0;
    if !honeypot.trim().is_empty() {
        s += 5;
    }
    if (0..1500).contains(&elapsed_ms) {
        s += 3;
    }
    let links = text_blob.matches("http://").count() + text_blob.matches("https://").count();
    if links >= 3 {
        s += 2;
    } else if links >= 1 {
        s += 1;
    }
    s
}

/// Duplicate ka kunji: lead = email (chhota), deal = title + company (sirf alphanumeric, chhota). Khali kunji kabhi group nahi banata.
pub fn lead_key(email: &str) -> String {
    email.trim().to_lowercase()
}

pub fn deal_key(title: &str, company: &str) -> String {
    let norm = |s: &str| s.chars().filter(|c| c.is_alphanumeric()).collect::<String>().to_lowercase();
    let (t, c) = (norm(title), norm(company));
    if t.is_empty() { String::new() } else { format!("{t}|{c}") }
}

/// (id, key) -> woh groups jinmein 2+ hon; har group mein pehli entry sabse purani/pehli (input ki tarteeb). Group bhi pehle-aaye tarteeb se.
pub fn group_dups(items: &[(String, String)]) -> Vec<Vec<String>> {
    let mut order: Vec<String> = vec![];
    let mut groups: Vec<Vec<String>> = vec![];
    for (id, key) in items {
        if key.is_empty() {
            continue;
        }
        match order.iter().position(|k| k == key) {
            Some(i) => groups[i].push(id.clone()),
            None => {
                order.push(key.clone());
                groups.push(vec![id.clone()]);
            }
        }
    }
    groups.into_iter().filter(|g| g.len() > 1).collect()
}

/// Deal is pipeline par dikhna chahiye? pipeline_id barabar, ya deal ka pipeline_id khali aur yeh default pipeline hai.
pub fn deal_in_pipeline(deal_pipeline: Option<&str>, selected_id: &str, selected_is_default: bool) -> bool {
    match deal_pipeline {
        Some(p) => p.eq_ignore_ascii_case(selected_id),
        None => selected_is_default,
    }
}

/// Stale din: sirf open stage ka deal; ghalat/future waqt = 0.
pub fn stale_days(open: bool, updated: Option<i64>, now: i64) -> Option<i64> {
    if !open {
        return None;
    }
    updated.map(|u| ((now - u).max(0)) / 86_400)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn caps_follow_the_founder_table_and_pro_is_below_business() {
        assert_eq!(limits("pro"), Some(Limits { pipelines: 1, fields: 5, forms: 1 }));
        assert_eq!(limits("Business"), Some(Limits { pipelines: 5, fields: 25, forms: 10 }));
        for p in ["business_pro", "Business Pro", "enterprise", "ai_pro"] {
            assert_eq!(limits(p), Some(Limits { pipelines: -1, fields: -1, forms: -1 }), "{p}");
        }
        assert_eq!(limits("basic"), None);
        assert_eq!(limits(""), None);
        let (p, b) = (limits("pro").unwrap(), limits("business").unwrap());
        assert!(p.pipelines < b.pipelines && p.fields < b.fields && p.forms < b.forms);
    }

    #[test]
    fn gate_covers_config_procs_but_not_public_form() {
        for p in ["crm.pipelines.save", "crm.fields.save", "crm.merge", "crm.forms.save", "crm.dups.list", "crm.custom.set", "crm.board", "crm.deals.move", "crm.deals.setPipeline"] {
            assert!(pro_only(p), "{p}");
        }
        assert!(!pro_only("crm.form.submit") && !pro_only("crm.form.get") && !pro_only("crm.overview"));
        assert!(plan_allows_pro("pro") && !plan_allows_pro("basic"));
    }

    #[test]
    fn keys_and_slugs() {
        assert!(key_ok("budget") && key_ok("a_1") && !key_ok("1a") && !key_ok("Budget") && !key_ok("") && !key_ok(&"a".repeat(31)));
        assert_eq!(slugify("Deal Size (GBP)"), Some("deal_size_gbp".into()));
        assert_eq!(slugify("  --  "), None);
        assert_eq!(slugify("9 lives"), None);
        assert_eq!(slugify("Budget"), Some("budget".into()));
        assert!(slug_ok("0123456789abcdef") && !slug_ok("0123456789abcdeg") && !slug_ok("abc"));
    }

    #[test]
    fn field_values_are_validated_per_kind() {
        let opts = vec!["Hot".to_string(), "Cold".to_string()];
        assert_eq!(check_value("number", &[], " 12.5 "), Ok("12.5".into()));
        assert!(check_value("number", &[], "NaN").is_err() && check_value("number", &[], "inf").is_err() && check_value("number", &[], "abc").is_err());
        assert!(check_value("date", &[], "2026-02-29").is_err() && check_value("date", &[], "2028-02-29").is_ok() && check_value("date", &[], "26-1-1").is_err());
        assert_eq!(check_value("select", &opts, "hot"), Ok("Hot".into()));
        assert_eq!(check_value("select", &opts, "warm"), Err("not_an_option"));
        assert!(check_value("checkbox", &[], "true").is_ok() && check_value("checkbox", &[], "yes").is_err());
        assert!(check_value("text", &[], &"x".repeat(501)).is_err());
    }

    #[test]
    fn select_options_clean() {
        let raw = vec![" Hot ".to_string(), "hot".to_string(), "".to_string(), "Cold".to_string()];
        assert_eq!(clean_options("select", &raw), Ok(vec!["Hot".to_string(), "Cold".to_string()]));
        assert_eq!(clean_options("select", &[]), Err("select_needs_options"));
        assert_eq!(clean_options("text", &raw), Ok(vec![]));
    }

    fn st(k: &str, p: i64, kind: &str) -> StageIn {
        StageIn { key: k.into(), label: k.to_uppercase(), probability: p, kind: kind.into() }
    }

    #[test]
    fn stage_rules() {
        assert!(check_stages(&[st("new", 10, "open"), st("won", 100, "won")]).is_ok());
        assert_eq!(check_stages(&[st("new", 10, "open")]), Err("bad_stages"));
        assert_eq!(check_stages(&[st("new", 10, "open"), st("new", 20, "open"), st("won", 100, "won")]), Err("duplicate_stage"));
        assert_eq!(check_stages(&[st("new", 10, "open"), st("won", 90, "won")]), Err("won_must_be_100"));
        assert_eq!(check_stages(&[st("new", 10, "open"), st("lost", 5, "lost")]), Err("lost_must_be_0"));
        assert_eq!(check_stages(&[st("a", 10, "open"), st("b", 20, "open")]), Err("needs_open_and_closed"));
        assert_eq!(check_stages(&[st("New", 10, "open"), st("won", 100, "won")]), Err("bad_stage"));
        assert_eq!(check_stages(&[st("a", 101, "open"), st("won", 100, "won")]), Err("bad_stage"));
    }

    #[test]
    fn form_needs_a_required_email_field() {
        let f = |k: &str, kind: &str, r: bool| (k.to_string(), kind.to_string(), r);
        assert!(check_form_fields(&[f("email", "email", true), f("name", "text", false)]).is_ok());
        assert_eq!(check_form_fields(&[f("name", "text", true)]), Err("email_required"));
        assert_eq!(check_form_fields(&[f("email", "email", false)]), Err("email_required"));
        assert_eq!(check_form_fields(&[f("email", "email", true), f("email", "email", true)]), Err("duplicate_field"));
        assert_eq!(check_form_fields(&[f("email", "weird", true)]), Err("bad_field"));
        assert_eq!(check_form_fields(&[]), Err("bad_fields"));
        assert!(email_shape_ok("a@b.co") && !email_shape_ok("a@b") && !email_shape_ok("a b@c.com") && !email_shape_ok("@b.com") && !email_shape_ok("a@@b.com"));
    }

    #[test]
    fn board_helpers() {
        assert!(deal_in_pipeline(None, "p1", true) && !deal_in_pipeline(None, "p1", false));
        assert!(deal_in_pipeline(Some("P1"), "p1", false) && !deal_in_pipeline(Some("p2"), "p1", true));
        assert_eq!(stale_days(true, Some(0), 3 * 86_400 + 5), Some(3));
        assert_eq!(stale_days(false, Some(0), 99 * 86_400), None);
        assert_eq!(stale_days(true, Some(100), 50), Some(0));
        assert_eq!(stale_days(true, None, 50), None);
    }

    #[test]
    fn spam_score_rules() {
        assert!(spam_score("http://spam", 9000, "") >= 5);
        assert_eq!(spam_score("", 9000, "hello"), 0);
        assert_eq!(spam_score("", 400, "hello"), 3);
        assert_eq!(spam_score("", 9000, "https://a https://b http://c"), 2);
        assert_eq!(spam_score("", 9000, "see https://a"), 1);
        assert_eq!(spam_score("", -1, ""), 0); // elapsed na bhejne wala browser spam nahi
        assert!(spam_score("", 400, "https://a https://b https://c") >= 5);
    }

    #[test]
    fn duplicate_keys_and_groups() {
        assert_eq!(lead_key("  Ann@X.com "), "ann@x.com");
        assert_eq!(deal_key("Acme - Q4 Renewal!", "ACME Ltd."), "acmeq4renewal|acmeltd");
        assert_eq!(deal_key("   ", "Acme"), "");
        let items = vec![
            ("1".to_string(), "a".to_string()),
            ("2".to_string(), "b".to_string()),
            ("3".to_string(), "a".to_string()),
            ("4".to_string(), "".to_string()),
            ("5".to_string(), "".to_string()),
            ("6".to_string(), "a".to_string()),
        ];
        assert_eq!(group_dups(&items), vec![vec!["1".to_string(), "3".to_string(), "6".to_string()]]);
        assert!(group_dups(&[]).is_empty());
    }
}
