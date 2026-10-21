// ============================================================================
// events_core.rs — std-only half of B4 (R5): event-driven live push over WebTransport (QUIC). Whole website, every plan and every
// account kind (Basic / Pro / Business / Business Pro / family): events are keyed by the org membership, NEVER by plan.
// Pure decisions only (topic allow-list, which RPC counts as a change, frame text, secret compare, per-token org cache rules), so
// the installer proves them with plain `rustc --test` before anything is built.
// ============================================================================

/// Topics a browser may subscribe to. Anything else in a hello is ignored (allow-list).
pub const TOPICS: [&str; 6] = ["mail", "calendar", "crm", "work", "people", "org"];

pub fn topic_ok(t: &str) -> Option<&'static str> {
    TOPICS.iter().copied().find(|x| *x == t)
}

/// Hello `topics` -> allow-listed, de-duplicated, order kept. Empty / missing => ["mail"] (the old `mode:"mail"` behaviour).
pub fn parse_topics(raw: &[String]) -> Vec<&'static str> {
    let mut out: Vec<&'static str> = Vec::new();
    for r in raw.iter().take(32) {
        if let Some(t) = topic_ok(r.trim()) {
            if !out.contains(&t) {
                out.push(t);
            }
        }
    }
    if out.is_empty() {
        out.push("mail");
    }
    out
}

/// `/rpc/<proc>` -> the topic a change in it touches.
pub fn topic_for_proc(proc: &str) -> Option<&'static str> {
    let head = proc.split('.').next().unwrap_or("");
    match head {
        "mail" => Some("mail"),
        "calendar" | "cal" => Some("calendar"),
        "crm" => Some("crm"),
        "work" => Some("work"),
        "people" => Some("people"),
        "org" | "team" => Some("org"),
        _ => None,
    }
}

fn words(seg: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    let mut cur = String::new();
    for c in seg.chars() {
        if c.is_uppercase() || c == '_' || c == '-' {
            if !cur.is_empty() {
                out.push(cur.to_lowercase());
                cur.clear();
            }
            if c != '_' && c != '-' {
                cur.push(c);
            }
        } else {
            cur.push(c);
        }
    }
    if !cur.is_empty() {
        out.push(cur.to_lowercase());
    }
    out
}

const VERBS: [&str; 44] = [
    "send", "schedule", "cancel", "create", "update", "delete", "remove", "add", "set", "mark", "move", "archive", "star", "snooze", "label",
    "assign", "accept", "decline", "respond", "import", "dismiss", "complete", "close", "reopen", "resend", "invite", "revoke", "save", "restore",
    "merge", "reply", "forward", "rsvp", "approve", "reject", "toggle", "pin", "unpin", "unarchive", "trash", "rename", "link", "unlink", "reorder",
];

/// Does this RPC change data (so listeners should refresh)? Over-publishing only costs a refetch; under-publishing is caught by the
/// 2 s reconcile for mail. Reads (list / get / status / findtime / busy / threads …) never publish.
pub fn is_mutation(proc: &str) -> bool {
    let last = proc.rsplit('.').next().unwrap_or("");
    words(last).iter().any(|w| VERBS.contains(&w.as_str()))
}

/// Constant-time equality for the internal-event secret. Empty / short secrets never match (endpoint stays closed).
pub fn secret_ok(given: &str, expected: &str) -> bool {
    if expected.len() < 24 || given.len() != expected.len() {
        return false;
    }
    given.bytes().zip(expected.bytes()).fold(0u8, |a, (x, y)| a | (x ^ y)) == 0
}

/// A request that came through the public proxy (Caddy adds these) must never reach the internal endpoint.
pub fn came_via_proxy(forwarded_for: bool, forwarded: bool, real_ip: bool) -> bool {
    forwarded_for || forwarded || real_ip
}

pub fn is_uuid(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 36 && b.iter().enumerate().all(|(i, c)| if matches!(i, 8 | 13 | 18 | 23) { *c == b'-' } else { c.is_ascii_hexdigit() })
}

pub fn frame_ready(mode: &str, topics: &[&str]) -> String {
    let t: Vec<String> = topics.iter().map(|x| format!("\"{x}\"")).collect();
    format!("{{\"type\":\"ready\",\"transport\":\"webtransport\",\"mode\":\"{mode}\",\"topics\":[{}]}}\n", t.join(","))
}

/// `extra` is already-valid JSON object body text (without braces) or empty.
pub fn frame_event(topic: &str, seq: u64, extra: &str) -> String {
    if extra.is_empty() {
        format!("{{\"type\":\"event\",\"topic\":\"{topic}\",\"seq\":{seq}}}\n")
    } else {
        format!("{{\"type\":\"event\",\"topic\":\"{topic}\",\"seq\":{seq},{extra}}}\n")
    }
}

pub fn frame_ping() -> &'static str {
    "{\"type\":\"ping\"}\n"
}

/// Cache key for token -> org lookups: never keep the token itself in memory longer than the request.
pub fn cache_ok(age_secs: u64, ttl_secs: u64) -> bool {
    age_secs < ttl_secs
}

#[cfg(test)]
mod tests {
    use super::*;

    fn s(v: &[&str]) -> Vec<String> {
        v.iter().map(|x| x.to_string()).collect()
    }

    #[test]
    fn topics_are_allow_listed() {
        assert_eq!(parse_topics(&s(&["calendar", "mail", "calendar", "x&y", "", "ORG"])), vec!["calendar", "mail"]);
        assert_eq!(parse_topics(&s(&[])), vec!["mail"]);
        assert_eq!(parse_topics(&s(&["nope", "chat"])), vec!["mail"]);
        assert_eq!(parse_topics(&vec!["mail".to_string(); 500]), vec!["mail"]);
    }

    #[test]
    fn proc_to_topic() {
        assert_eq!(topic_for_proc("mail.send"), Some("mail"));
        assert_eq!(topic_for_proc("calendar.create"), Some("calendar"));
        assert_eq!(topic_for_proc("crm.leadsMoveToPeople"), Some("crm"));
        assert_eq!(topic_for_proc("team.members.remove"), Some("org"));
        assert_eq!(topic_for_proc("auth.passkey.verify"), None);
        assert_eq!(topic_for_proc("chat.messages.send"), None);
        assert_eq!(topic_for_proc(""), None);
    }

    #[test]
    fn mutations_vs_reads() {
        for m in ["mail.send", "mail.schedule", "mail.schedule.cancel", "mail.star", "calendar.create", "calendar.update", "crm.leadsImport",
                  "crm.leadsMoveToPeople", "crm.leads.dismiss", "team.members.remove", "mail.addresses.remove", "org.mailboxes.create", "work.tasks.complete"] {
            assert!(is_mutation(m), "{m}");
        }
        for r in ["mail.threads", "mail.thread", "calendar.busy", "calendar.findtime", "calendar.guests", "org.mailboxes.list", "team.members.list",
                  "crm.promises.open", "mail.attach.limits", "billing.subscription", "dashboard.overview"] {
            assert!(!is_mutation(r), "{r}");
        }
    }

    #[test]
    fn secret_is_constant_time_and_never_short() {
        let sec = "a".repeat(40);
        assert!(secret_ok(&sec, &sec));
        assert!(!secret_ok(&"a".repeat(39), &sec));
        assert!(!secret_ok(&format!("{}b", "a".repeat(39)), &sec));
        assert!(!secret_ok("", ""));
        assert!(!secret_ok("short", "short"));
    }

    #[test]
    fn proxy_headers_close_internal_endpoint() {
        assert!(came_via_proxy(true, false, false) && came_via_proxy(false, true, false) && came_via_proxy(false, false, true));
        assert!(!came_via_proxy(false, false, false));
    }

    #[test]
    fn frames_are_valid_lines() {
        assert_eq!(frame_ready("events", &["mail", "crm"]), "{\"type\":\"ready\",\"transport\":\"webtransport\",\"mode\":\"events\",\"topics\":[\"mail\",\"crm\"]}\n");
        assert_eq!(frame_event("crm", 7, ""), "{\"type\":\"event\",\"topic\":\"crm\",\"seq\":7}\n");
        assert_eq!(frame_event("mail", 8, "\"unread\":3"), "{\"type\":\"event\",\"topic\":\"mail\",\"seq\":8,\"unread\":3}\n");
        assert!(frame_ping().ends_with('\n'));
    }

    #[test]
    fn uuid_and_cache() {
        assert!(is_uuid("0b9a1c52-1111-4222-8333-444455556666"));
        assert!(!is_uuid("x&org=1") && !is_uuid(""));
        assert!(cache_ok(59, 60) && !cache_ok(60, 60));
    }
}
