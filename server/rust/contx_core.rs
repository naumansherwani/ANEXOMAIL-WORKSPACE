// contx_core — People / Companies / universal search ka dimaag (std-only; `rustc --edition 2021 --test`).
// Bun twin: server/routes/contacts.ts. Sab plans (Basic aur Pro dono) ko same code — koi plan gate nahi (PP1 #10,#17,#31,#34).

pub const PROCS: [&str; 10] = [
    "contacts.list", "contacts.tags", "contacts.get", "contacts.update", "contacts.tag", "contacts.timeline",
    "companies.list", "companies.get", "companies.timeline", "search.universal",
];

pub fn owns_name(p: &str) -> bool {
    PROCS.contains(&p)
}

/// PostgREST `or=(...)` / ilike mein jaane wali qeemat se woh characters hatao jo filter todte hain (`, ( ) * % \ "` aur control).
pub fn safe_term(q: &str) -> String {
    q.chars()
        .filter(|c| !matches!(c, ',' | '(' | ')' | '*' | '%' | '\\' | '"' | '\'' | ';' | '&' | '#') && !c.is_control())
        .collect::<String>()
        .trim()
        .chars()
        .take(100)
        .collect()
}

/// Address/domain fragment: sirf mail-safe characters.
pub fn safe_addr(a: &str) -> String {
    a.chars().filter(|c| c.is_ascii_alphanumeric() || matches!(c, '@' | '.' | '_' | '-' | '+')).collect::<String>().to_lowercase()
}

pub fn clamp(s: &str, max: usize) -> String {
    s.chars().take(max).collect()
}

pub fn clean_tag(raw: &str) -> Option<String> {
    let t = clamp(raw.trim(), 60);
    let t = t.trim().to_string();
    if t.is_empty() { None } else { Some(t) }
}

pub fn is_tag_filter(filter: &str) -> bool {
    matches!(filter, "customer" | "vendor" | "investor")
}

/// Kaun sa tag-driven filter lagana hai: explicit tag, warna customer/vendor/investor filter, warna kuch nahi.
pub fn want_tag(tag: &str, filter: &str) -> String {
    if !tag.trim().is_empty() {
        tag.trim().to_string()
    } else if is_tag_filter(filter) {
        filter.to_string()
    } else {
        String::new()
    }
}

pub fn passes_stat_filter(filter: &str, relationship: &str, open_threads: i64) -> bool {
    match filter {
        "at_risk" => relationship == "at_risk",
        "dormant" => relationship == "dormant",
        "unanswered" => open_threads > 0,
        _ => true,
    }
}

pub fn is_schema_cache_error(m: &str) -> bool {
    let l = m.to_lowercase();
    l.contains("schema cache") || l.contains("pgrst200") || l.contains("relationship between")
}

#[derive(Clone, Debug, PartialEq)]
pub struct PersonStat {
    pub messages_in: i64,
    pub messages_out: i64,
    pub open_threads: i64,
    pub last_contact_at: Option<String>,
    pub relationship: String,
    pub health: Option<f64>,
}

#[derive(Debug, PartialEq)]
pub struct CompanyAgg {
    pub people_count: usize,
    pub messages_total: i64,
    pub open_threads: i64,
    pub relationship: String,
    pub health_score: Option<i64>,
    pub last_contact_at: Option<String>,
}

pub fn aggregate_company(people: &[PersonStat]) -> CompanyAgg {
    let msgs: i64 = people.iter().map(|p| p.messages_in + p.messages_out).sum();
    let open: i64 = people.iter().map(|p| p.open_threads).sum();
    let last = people.iter().filter_map(|p| p.last_contact_at.clone()).filter(|s| !s.is_empty()).max();
    let risky = people.iter().any(|p| p.relationship == "at_risk");
    let rel = if risky {
        "at_risk".to_string()
    } else {
        people.first().map(|p| p.relationship.clone()).filter(|r| !r.is_empty()).unwrap_or_else(|| "new".into())
    };
    let scores: Vec<f64> = people.iter().filter_map(|p| p.health).collect();
    let health = if scores.is_empty() { None } else { Some((scores.iter().sum::<f64>() / scores.len() as f64).round() as i64) };
    CompanyAgg { people_count: people.len(), messages_total: msgs, open_threads: open, relationship: rel, health_score: health, last_contact_at: last }
}

/// "last_contact_at" ke hisab se naye pehle (string compare, None = "").
pub fn newest_first(a: &Option<String>, b: &Option<String>) -> std::cmp::Ordering {
    b.as_deref().unwrap_or("").cmp(a.as_deref().unwrap_or(""))
}

/// Timeline ke liye `or=(...)` ka andar ka hissa. Khali addresses => None.
pub fn timeline_or(addresses: &[String]) -> Option<String> {
    let parts: Vec<String> = addresses
        .iter()
        .map(|a| safe_addr(a))
        .filter(|a| !a.is_empty())
        .flat_map(|a| vec![format!("from_address.ilike.*{a}*"), format!("to_addresses.ilike.*{a}*")])
        .collect();
    if parts.is_empty() { None } else { Some(parts.join(",")) }
}

#[derive(Debug, PartialEq)]
pub struct Patch {
    pub display_name: Option<String>,
    pub title: Option<String>,
    pub notes: Option<String>,
    pub vip: Option<bool>,
}

impl Patch {
    pub fn is_empty(&self) -> bool {
        self.display_name.is_none() && self.title.is_none() && self.notes.is_none() && self.vip.is_none()
    }
}

pub fn build_patch(display_name: Option<&str>, title: Option<&str>, notes: Option<&str>, vip: Option<bool>) -> Patch {
    Patch {
        display_name: display_name.map(|s| clamp(s, 200)),
        title: title.map(|s| clamp(s, 200)),
        notes: notes.map(|s| clamp(s, 5000)),
        vip,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn p(i: i64, o: i64, open: i64, last: Option<&str>, rel: &str, h: Option<f64>) -> PersonStat {
        PersonStat { messages_in: i, messages_out: o, open_threads: open, last_contact_at: last.map(|s| s.into()), relationship: rel.into(), health: h }
    }
    #[test]
    fn terms() {
        assert_eq!(safe_term("  a,b(c)*%\"x  "), "abcx");
        assert_eq!(safe_term(&"z".repeat(300)).len(), 100);
        assert_eq!(safe_addr("Bob@Ex.com,(x)"), "bob@ex.comx");
        assert_eq!(clean_tag("  vip  "), Some("vip".into()));
        assert_eq!(clean_tag("   "), None);
        assert_eq!(clean_tag(&"t".repeat(90)).unwrap().len(), 60);
    }
    #[test]
    fn filters() {
        assert_eq!(want_tag("", "customer"), "customer");
        assert_eq!(want_tag("Hot", "customer"), "Hot");
        assert_eq!(want_tag("", "vip"), "");
        assert!(passes_stat_filter("at_risk", "at_risk", 0));
        assert!(!passes_stat_filter("dormant", "new", 0));
        assert!(passes_stat_filter("unanswered", "new", 2));
        assert!(!passes_stat_filter("unanswered", "new", 0));
        assert!(passes_stat_filter("all", "x", 0));
        assert!(is_schema_cache_error("Could not find a relationship between 'a' and 'b' in the schema cache"));
        assert!(is_schema_cache_error("PGRST200"));
        assert!(!is_schema_cache_error("timeout"));
    }
    #[test]
    fn company() {
        let a = aggregate_company(&[p(3, 2, 1, Some("2026-10-01"), "new", Some(60.0)), p(1, 0, 2, Some("2026-10-05"), "at_risk", Some(41.0))]);
        assert_eq!(a.people_count, 2);
        assert_eq!(a.messages_total, 6);
        assert_eq!(a.open_threads, 3);
        assert_eq!(a.relationship, "at_risk");
        assert_eq!(a.health_score, Some(51)); // 50.5 -> 51
        assert_eq!(a.last_contact_at, Some("2026-10-05".into()));
        let e = aggregate_company(&[]);
        assert_eq!(e.relationship, "new");
        assert_eq!(e.health_score, None);
        assert_eq!(e.last_contact_at, None);
        let f = aggregate_company(&[p(0, 0, 0, None, "dormant", None)]);
        assert_eq!(f.relationship, "dormant");
    }
    #[test]
    fn order_timeline_patch() {
        let mut v = vec![None, Some("2026-01".to_string()), Some("2026-03".to_string())];
        v.sort_by(newest_first);
        assert_eq!(v, vec![Some("2026-03".to_string()), Some("2026-01".to_string()), None]);
        assert_eq!(timeline_or(&[]), None);
        assert_eq!(timeline_or(&["@Acme.com".into()]).unwrap(), "from_address.ilike.*@acme.com*,to_addresses.ilike.*@acme.com*");
        let pt = build_patch(Some(&"n".repeat(300)), None, None, None);
        assert_eq!(pt.display_name.unwrap().len(), 200);
        assert!(build_patch(None, None, None, None).is_empty());
        assert!(!build_patch(None, None, None, Some(false)).is_empty());
        assert!(owns_name("search.universal") && !owns_name("contacts.import"));
    }
}
