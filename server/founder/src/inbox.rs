//! Founder Inbox (step 4d, E112): read side. The browser asks `/founder/v1/inbox` (one snapshot), `/inbox/list` (issues) and `/inbox/group` (one issue).
//! Every query parameter is checked HERE against a fixed list before it reaches SQL (the SQL checks again). Nothing is invented: a missing E112 answers
//! `{"connected": false, ...}` so the UI says "run the E112 step", never a fake empty inbox.
use serde_json::{Value, json};

pub const STATUSES: [&str; 7] = ["active", "new", "open", "waiting", "solved", "closed", "all"];
pub const KINDS: [&str; 2] = ["glitch", "support"];

#[derive(Debug, PartialEq)]
pub struct ListQ { pub status: String, pub kind: Option<String>, pub limit: i64, pub offset: i64 }

/// Parse `status=&kind=&limit=&offset=` from a raw query string. Unknown status/kind = Err (400), numbers are clamped (limit 1..200, offset 0..10000).
pub fn parse_list(q: Option<&str>) -> Result<ListQ, &'static str> {
    let (mut status, mut kind, mut limit, mut offset) = ("active".to_string(), None, 50i64, 0i64);
    for pair in q.unwrap_or("").split('&').filter(|p| !p.is_empty()) {
        let (k, v) = pair.split_once('=').unwrap_or((pair, ""));
        match k {
            "status" => { if !STATUSES.contains(&v) { return Err("invalid status"); } status = v.to_string(); }
            "kind" => { if v.is_empty() { continue; } if !KINDS.contains(&v) { return Err("invalid kind"); } kind = Some(v.to_string()); }
            "limit" => { limit = v.parse::<i64>().map_err(|_| "invalid limit")?.clamp(1, 200); }
            "offset" => { offset = v.parse::<i64>().map_err(|_| "invalid offset")?.clamp(0, 10_000); }
            _ => return Err("unknown parameter"),
        }
    }
    Ok(ListQ { status, kind, limit, offset })
}

/// `id=<digits>` only (a group id). Anything else = Err.
pub fn parse_group(q: Option<&str>) -> Result<i64, &'static str> {
    let q = q.ok_or("missing id")?;
    let v = q.strip_prefix("id=").ok_or("missing id")?;
    if v.is_empty() || v.len() > 18 || !v.bytes().all(|b| b.is_ascii_digit()) { return Err("invalid id"); }
    let n: i64 = v.parse().map_err(|_| "invalid id")?;
    if n < 1 { return Err("invalid id"); }
    Ok(n)
}

pub fn list_args(q: &ListQ) -> Value { json!({"p_status": q.status, "p_kind": q.kind, "p_limit": q.limit, "p_offset": q.offset}) }

/// What the browser gets when E112 is not installed (RPC missing or database not answering).
pub fn missing() -> Value { json!({"connected": false, "note": "founder_inbox_snapshot not answering - run the E112 SQL (sql-run.sh)"}) }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn list_defaults_and_clamps() {
        assert_eq!(parse_list(None).unwrap(), ListQ { status: "active".into(), kind: None, limit: 50, offset: 0 });
        assert_eq!(parse_list(Some("offset=-4")).unwrap().offset, 0); // negative is clamped to 0, never passed to SQL
        let q = parse_list(Some("status=solved&kind=glitch&limit=9999&offset=99999")).unwrap();
        assert_eq!((q.status.as_str(), q.kind.as_deref(), q.limit, q.offset), ("solved", Some("glitch"), 200, 10_000));
        assert_eq!(parse_list(Some("limit=0")).unwrap().limit, 1);
    }
    #[test]
    fn list_refuses_anything_not_on_the_list() {
        assert!(parse_list(Some("status=drop")).is_err());
        assert!(parse_list(Some("kind=x")).is_err());
        assert!(parse_list(Some("limit=abc")).is_err());
        assert!(parse_list(Some("evil=1")).is_err());
        assert!(parse_list(Some("status=active%27")).is_err());
        assert_eq!(parse_list(Some("kind=")).unwrap().kind, None);
    }
    #[test]
    fn group_id_is_digits_only() {
        assert_eq!(parse_group(Some("id=12")), Ok(12));
        for bad in [None, Some(""), Some("id="), Some("id=0"), Some("id=-1"), Some("id=1a"), Some("id=1 or 1"), Some("x=1"), Some("id=1234567890123456789")] { assert!(parse_group(bad).is_err(), "{bad:?}"); }
    }
    #[test]
    fn args_shape_matches_sql_names() {
        let a = list_args(&parse_list(Some("kind=support")).unwrap());
        assert_eq!(a["p_status"], "active"); assert_eq!(a["p_kind"], "support"); assert_eq!(a["p_limit"], 50); assert_eq!(a["p_offset"], 0);
        assert_eq!(missing()["connected"], false);
    }
}
