// ============================================================================
// imip_core.rs — iMIP REPLY reader (#3, 22 Oct 2026). std-only, no I/O, unit-tested.
//
// A guest answers an ANEXOMAIL invitation from Gmail/Outlook/Apple: their app mails back a `text/calendar; method=REPLY`
// part. This file only READS that part and decides whether it may be trusted; the database (E60 `calendar_imip_apply`)
// is the last wall (matching event + attendee, sequence, duplicates).
//
//   parse_reply(ics)        -> Some(Reply) for METHOD:REPLY with an ANEXOMAIL UID and a usable PARTSTAT, else None
//   trusted(spf, dkim, from, attendee, envelope_from) -> true only when the sender is provably the attendee
// ============================================================================

#[derive(Debug, Clone, PartialEq)]
pub struct Reply {
    pub uid: String,
    pub attendee: String,
    pub partstat: String, // ACCEPTED | DECLINED | TENTATIVE
    pub sequence: i32,
    pub recurrence_id: Option<String>, // RFC 3339 UTC ("2026-11-05T09:00:00Z")
    pub comment: Option<String>,
}

const MAX_ICS: usize = 64 * 1024;

fn unfold(s: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for line in s.split('\n') {
        let line = line.strip_suffix('\r').unwrap_or(line);
        if (line.starts_with(' ') || line.starts_with('\t')) && !out.is_empty() {
            out.last_mut().unwrap().push_str(&line[1..]);
        } else {
            out.push(line.to_string());
        }
    }
    out
}

/// "NAME;P=V;P2=V2:value" -> (NAME upper, params, value)
fn split_prop(line: &str) -> Option<(String, Vec<(String, String)>, String)> {
    let mut in_q = false;
    let mut colon = None;
    for (i, c) in line.char_indices() {
        match c {
            '"' => in_q = !in_q,
            ':' if !in_q => {
                colon = Some(i);
                break;
            }
            _ => {}
        }
    }
    let colon = colon?;
    let (head, value) = (&line[..colon], &line[colon + 1..]);
    let mut parts = head.split(';');
    let name = parts.next()?.trim().to_ascii_uppercase();
    if name.is_empty() {
        return None;
    }
    let params = parts
        .filter_map(|p| {
            let (k, v) = p.split_once('=')?;
            Some((k.trim().to_ascii_uppercase(), v.trim().trim_matches('"').to_string()))
        })
        .collect();
    Some((name, params, value.to_string()))
}

fn unescape(s: &str) -> String {
    let mut out = String::new();
    let mut it = s.chars();
    while let Some(c) = it.next() {
        if c == '\\' {
            match it.next() {
                Some('n') | Some('N') => out.push('\n'),
                Some(o) => out.push(o),
                None => {}
            }
        } else {
            out.push(c);
        }
    }
    out
}

/// `20261105T090000Z` -> `2026-11-05T09:00:00Z`; anything not strictly UTC -> None (we never guess a time zone).
fn utc_stamp(v: &str) -> Option<String> {
    let b = v.trim().as_bytes();
    if b.len() != 16 || b[8] != b'T' || b[15] != b'Z' {
        return None;
    }
    if !b[..8].iter().chain(b[9..15].iter()).all(|c| c.is_ascii_digit()) {
        return None;
    }
    let n = |a: usize, z: usize| std::str::from_utf8(&b[a..z]).unwrap().parse::<u32>().unwrap();
    let (mo, d, h, mi, s) = (n(4, 6), n(6, 8), n(9, 11), n(11, 13), n(13, 15));
    if !(1..=12).contains(&mo) || !(1..=31).contains(&d) || h > 23 || mi > 59 || s > 60 {
        return None;
    }
    Some(format!("{}-{:02}-{:02}T{:02}:{:02}:{:02}Z", std::str::from_utf8(&b[..4]).unwrap(), mo, d, h, mi, s.min(59)))
}

pub fn parse_reply(ics: &[u8]) -> Option<Reply> {
    if ics.is_empty() || ics.len() > MAX_ICS {
        return None;
    }
    let text = String::from_utf8_lossy(ics);
    let lines = unfold(&text);
    let mut method = String::new();
    let mut in_event = false;
    let mut done = false;
    let (mut uid, mut attendee, mut partstat, mut comment, mut rec) = (String::new(), String::new(), String::new(), None, None);
    let mut seq = 0i32;
    let mut attendees = 0;
    let mut bad_rec = false;
    for l in &lines {
        let Some((name, params, value)) = split_prop(l) else { continue };
        match name.as_str() {
            "METHOD" if !in_event => method = value.trim().to_ascii_uppercase(),
            "BEGIN" if value.trim().eq_ignore_ascii_case("VEVENT") => {
                if done {
                    return None; // more than one VEVENT: not something a calendar app sends for a single reply
                }
                in_event = true;
            }
            "END" if value.trim().eq_ignore_ascii_case("VEVENT") => {
                in_event = false;
                done = true;
            }
            "UID" if in_event => uid = value.trim().to_string(),
            "SEQUENCE" if in_event => seq = value.trim().parse::<i32>().unwrap_or(0).clamp(0, 1_000_000),
            "COMMENT" if in_event => {
                let c = unescape(&value);
                let c: String = c.chars().take(500).collect();
                if !c.trim().is_empty() {
                    comment = Some(c);
                }
            }
            "RECURRENCE-ID" if in_event => match utc_stamp(&value) {
                Some(s) => rec = Some(s),
                None => bad_rec = true,
            },
            "ATTENDEE" if in_event => {
                attendees += 1;
                let v = value.trim();
                let addr = v.strip_prefix("mailto:").or_else(|| v.strip_prefix("MAILTO:")).unwrap_or(v).trim().to_ascii_lowercase();
                attendee = addr;
                partstat = params.iter().find(|(k, _)| k == "PARTSTAT").map(|(_, v)| v.to_ascii_uppercase()).unwrap_or_default();
            }
            _ => {}
        }
    }
    // A REPLY carries exactly one ATTENDEE (the replier). Several = not a plain reply: ignore, never guess which one.
    if method != "REPLY" || attendees != 1 || bad_rec {
        return None;
    }
    if !matches!(partstat.as_str(), "ACCEPTED" | "DECLINED" | "TENTATIVE") {
        return None;
    }
    // Only our own UIDs: <uuid>@anexomail.com
    let (id, dom) = uid.split_once('@')?;
    let u = id.as_bytes();
    let uuid_ok = u.len() == 36 && u.iter().enumerate().all(|(i, c)| if matches!(i, 8 | 13 | 18 | 23) { *c == b'-' } else { c.is_ascii_hexdigit() });
    if !uuid_ok || !dom.eq_ignore_ascii_case("anexomail.com") {
        return None;
    }
    if attendee.is_empty() || attendee.len() > 254 || attendee.contains(char::is_whitespace) || !attendee.contains('@') {
        return None;
    }
    Some(Reply { uid: uid.to_ascii_lowercase(), attendee, partstat, sequence: seq, recurrence_id: rec, comment })
}

fn bare(addr: &str) -> String {
    let a = addr.trim().to_ascii_lowercase();
    match (a.rfind('<'), a.rfind('>')) {
        (Some(i), Some(j)) if j > i => a[i + 1..j].trim().to_string(),
        _ => a,
    }
}

/// The reply may be applied only when the mail itself proves the attendee wrote it:
/// SPF or DKIM passed (from our own Authentication-Results) AND the visible From is the ATTENDEE.
/// Envelope sender may differ (mailing lists, Gmail uses the same), so it is not required.
pub fn trusted(spf: Option<&str>, dkim: Option<&str>, from: &str, attendee: &str) -> bool {
    let pass = |v: Option<&str>| v.map(|s| s.eq_ignore_ascii_case("pass")).unwrap_or(false);
    (pass(spf) || pass(dkim)) && !from.trim().is_empty() && bare(from) == attendee.trim().to_ascii_lowercase()
}

#[cfg(test)]
mod tests {
    use super::*;
    const UID: &str = "0f8fad5b-d9cb-469f-a165-70867728950e@anexomail.com";

    fn ics(extra: &str, partstat: &str) -> Vec<u8> {
        format!(
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nMETHOD:REPLY\r\nBEGIN:VEVENT\r\nUID:{UID}\r\nSEQUENCE:2\r\nATTENDEE;PARTSTAT={partstat};CN=Guest:mailto:Guest@Gmail.com\r\n{extra}END:VEVENT\r\nEND:VCALENDAR\r\n"
        )
        .into_bytes()
    }

    #[test]
    fn accepted_reply_is_read() {
        let r = parse_reply(&ics("", "ACCEPTED")).unwrap();
        assert_eq!((r.partstat.as_str(), r.attendee.as_str(), r.sequence), ("ACCEPTED", "guest@gmail.com", 2));
        assert_eq!(r.uid, UID);
        assert!(r.recurrence_id.is_none() && r.comment.is_none());
    }

    #[test]
    fn declined_tentative_and_comment_and_folding() {
        assert_eq!(parse_reply(&ics("", "DECLINED")).unwrap().partstat, "DECLINED");
        assert_eq!(parse_reply(&ics("", "tentative")).unwrap().partstat, "TENTATIVE");
        let r = parse_reply(&ics("COMMENT:Late by\r\n  10 min\\, sorry\r\n", "ACCEPTED")).unwrap();
        assert_eq!(r.comment.as_deref(), Some("Late by 10 min, sorry"));
    }

    #[test]
    fn exception_instance_utc_only() {
        let r = parse_reply(&ics("RECURRENCE-ID:20261105T090000Z\r\n", "ACCEPTED")).unwrap();
        assert_eq!(r.recurrence_id.as_deref(), Some("2026-11-05T09:00:00Z"));
        // zone-local recurrence id: we do not guess — ignored entirely (never applied to the whole series)
        assert!(parse_reply(&ics("RECURRENCE-ID;TZID=Asia/Karachi:20261105T140000\r\n", "ACCEPTED")).is_none());
    }

    #[test]
    fn only_replies_for_our_uids_with_a_real_answer() {
        let req = String::from_utf8(ics("", "ACCEPTED")).unwrap().replace("METHOD:REPLY", "METHOD:REQUEST");
        assert!(parse_reply(req.as_bytes()).is_none());
        let foreign = String::from_utf8(ics("", "ACCEPTED")).unwrap().replace("@anexomail.com", "@evil.com");
        assert!(parse_reply(foreign.as_bytes()).is_none());
        assert!(parse_reply(&ics("", "NEEDS-ACTION")).is_none());
        assert!(parse_reply(&ics("", "DELEGATED")).is_none());
        assert!(parse_reply(b"").is_none());
        assert!(parse_reply(&vec![b'x'; MAX_ICS + 1]).is_none());
    }

    #[test]
    fn several_attendees_or_events_are_ignored() {
        let two = String::from_utf8(ics("ATTENDEE;PARTSTAT=ACCEPTED:mailto:b@x.com\r\n", "ACCEPTED")).unwrap();
        assert!(parse_reply(two.as_bytes()).is_none());
        let ev = String::from_utf8(ics("", "ACCEPTED")).unwrap();
        let twice = ev.replace("END:VCALENDAR", &format!("BEGIN:VEVENT\r\nUID:{UID}\r\nEND:VEVENT\r\nEND:VCALENDAR"));
        assert!(parse_reply(twice.as_bytes()).is_none());
    }

    #[test]
    fn trust_needs_auth_pass_and_from_equals_attendee() {
        assert!(trusted(Some("pass"), None, "Guest <guest@gmail.com>", "guest@gmail.com"));
        assert!(trusted(None, Some("pass"), "GUEST@gmail.com", "guest@gmail.com"));
        assert!(!trusted(Some("fail"), Some("none"), "guest@gmail.com", "guest@gmail.com"));
        assert!(!trusted(None, None, "guest@gmail.com", "guest@gmail.com"));
        assert!(!trusted(Some("pass"), Some("pass"), "mallory@evil.com", "guest@gmail.com"));
        assert!(!trusted(Some("pass"), None, "", "guest@gmail.com"));
    }

    #[test]
    fn utc_stamp_rejects_junk() {
        assert!(utc_stamp("20261305T090000Z").is_none());
        assert!(utc_stamp("20261105T090000").is_none());
        assert!(utc_stamp("2026110ZT090000Z").is_none());
    }
}
