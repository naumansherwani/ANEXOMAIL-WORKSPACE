//! L5 v2: founder-host proof. The Rust side of E110. Records where a founder session was created (the Host header the proxy forwards) so
//! "founder only on the founder host" is proven from the database, not from pm2 log files. Pure helpers here are unit tested.
use axum::http::HeaderMap;

/// Hosts that count as the founder host (env FOUNDER_HOSTS, comma separated; default is the production founder host).
pub fn founder_hosts() -> Vec<String> {
    std::env::var("FOUNDER_HOSTS").unwrap_or_else(|_| "founderworkspace.anexomail.com".into())
        .split(',').map(|s| s.trim().to_lowercase()).filter(|s| !s.is_empty()).collect()
}

/// Lower-case host without port. The proxy's x-forwarded-host wins over Host (Caddy sets both); "-" when missing or not a plain hostname.
pub fn host_of(h: &HeaderMap) -> String {
    let raw = h.get("x-forwarded-host").or_else(|| h.get("host")).and_then(|v| v.to_str().ok()).unwrap_or("");
    let first = raw.split(',').next().unwrap_or("").trim().to_lowercase();
    let host = match first.rsplit_once(':') { Some((a, p)) if p.chars().all(|c| c.is_ascii_digit()) => a.to_string(), _ => first };
    if !host.is_empty() && host.len() <= 120 && host.chars().all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-') { host } else { "-".into() }
}

pub fn is_founder_host(host: &str, hosts: &[String]) -> bool { hosts.iter().any(|x| x == host) }

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::HeaderValue;
    fn hm(k: &'static str, v: &str) -> HeaderMap { let mut h = HeaderMap::new(); h.insert(k, HeaderValue::from_str(v).unwrap()); h }
    #[test] fn host_strips_port_and_case() { assert_eq!(host_of(&hm("host", "FounderWorkspace.Anexomail.com:443")), "founderworkspace.anexomail.com"); }
    #[test] fn forwarded_host_wins() {
        let mut h = hm("host", "127.0.0.1:8099"); h.insert("x-forwarded-host", HeaderValue::from_static("founderworkspace.anexomail.com"));
        assert_eq!(host_of(&h), "founderworkspace.anexomail.com");
    }
    #[test] fn bad_or_missing_host_is_dash() { assert_eq!(host_of(&HeaderMap::new()), "-"); assert_eq!(host_of(&hm("host", "a b!.com")), "-"); }
    #[test] fn founder_host_match_is_exact() {
        let hs = vec!["founderworkspace.anexomail.com".to_string()];
        assert!(is_founder_host("founderworkspace.anexomail.com", &hs));
        assert!(!is_founder_host("anexomail.com", &hs));
        assert!(!is_founder_host("evil-founderworkspace.anexomail.com", &hs));
    }
}
