// calexp_core — Calendar export (.ics / json) ka HISAAB. Sirf std: installer pre-flight `rustc --test` se pehle test karta hai.
// Bun twin: server/routes/calendar.ts GET /api/calendar/export. Ownership pillar: user apna poora calendar kabhi bhi nikaal sakta hai (sab plans, Basic bhi).
// Farq (jaan-boojh kar, RFC 5545): TEXT escaping (\ ; , newline) + 75-octet line folding — Bun ye nahi karta tha, "a,b" jaisa title kharab import hota tha.

pub const PROCS: [&str; 1] = ["calendar.export"];

pub fn owns_name(p: &str) -> bool {
    PROCS.contains(&p)
}

pub fn format_of(s: &str) -> Option<&'static str> {
    match s.trim().to_ascii_lowercase().as_str() {
        "" | "ics" => Some("ics"),
        "json" => Some("json"),
        _ => None,
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct Ev {
    pub id: String,
    pub title: String,
    pub agenda: Option<String>,
    pub location: Option<String>,
    pub starts: i64,
    pub ends: i64,
}

/// RFC 5545 TEXT escape: backslash, ; , aur newline (\r\n / \n / \r => \n literal).
pub fn escape_text(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 4);
    let mut it = s.chars().peekable();
    while let Some(c) = it.next() {
        match c {
            '\\' => o.push_str("\\\\"),
            ';' => o.push_str("\\;"),
            ',' => o.push_str("\\,"),
            '\r' => {
                if it.peek() == Some(&'\n') {
                    it.next();
                }
                o.push_str("\\n");
            }
            '\n' => o.push_str("\\n"),
            c if c.is_control() => {}
            c => o.push(c),
        }
    }
    o
}

/// Epoch seconds => "YYYYMMDDTHHMMSSZ".
pub fn stamp(epoch: i64) -> String {
    let (days, secs) = (epoch.div_euclid(86400), epoch.rem_euclid(86400));
    let z = days + 719468;
    let era = z.div_euclid(146097);
    let doe = z.rem_euclid(146097);
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{y:04}{m:02}{d:02}T{:02}{:02}{:02}Z", secs / 3600, (secs % 3600) / 60, secs % 60)
}

/// Lambi line 75 octets par todna (RFC 5545 3.1): agli lines ek space se shuru. UTF-8 character beech mein nahi katta.
pub fn fold(line: &str) -> String {
    let mut out = String::new();
    let mut cur = 0usize;
    for c in line.chars() {
        let n = c.len_utf8();
        if cur + n > 75 {
            out.push_str("\r\n ");
            cur = 1;
        }
        out.push(c);
        cur += n;
    }
    out
}

/// Poora VCALENDAR (CRLF se jura, aakhir mein bhi CRLF).
pub fn build_ics(events: &[Ev]) -> String {
    let mut lines: Vec<String> = vec!["BEGIN:VCALENDAR".into(), "VERSION:2.0".into(), "PRODID:-//ANEXOMAIL//Workspace//EN".into()];
    for e in events {
        lines.push("BEGIN:VEVENT".into());
        lines.push(format!("UID:{}@anexomail.com", e.id));
        lines.push(format!("DTSTART:{}", stamp(e.starts)));
        lines.push(format!("DTEND:{}", stamp(e.ends)));
        lines.push(format!("SUMMARY:{}", escape_text(&e.title)));
        if let Some(a) = e.agenda.as_ref().filter(|x| !x.is_empty()) {
            lines.push(format!("DESCRIPTION:{}", escape_text(a)));
        }
        if let Some(l) = e.location.as_ref().filter(|x| !x.is_empty()) {
            lines.push(format!("LOCATION:{}", escape_text(l)));
        }
        lines.push("END:VEVENT".into());
    }
    lines.push("END:VCALENDAR".into());
    let mut o = lines.iter().map(|l| fold(l)).collect::<Vec<_>>().join("\r\n");
    o.push_str("\r\n");
    o
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ev(title: &str) -> Ev {
        Ev { id: "abc".into(), title: title.into(), agenda: None, location: None, starts: 1_700_000_000, ends: 1_700_003_600 }
    }

    #[test]
    fn names_and_formats() {
        assert!(owns_name("calendar.export") && !owns_name("calendar.create"));
        assert_eq!(format_of(""), Some("ics"));
        assert_eq!(format_of("ICS"), Some("ics"));
        assert_eq!(format_of("json"), Some("json"));
        assert_eq!(format_of("pdf"), None);
    }
    #[test]
    fn stamps() {
        assert_eq!(stamp(0), "19700101T000000Z");
        assert_eq!(stamp(1_700_000_000), "20231114T221320Z");
        assert_eq!(stamp(951_782_400), "20000229T000000Z");
    }
    #[test]
    fn escaping() {
        assert_eq!(escape_text("a,b;c\\d"), "a\\,b\\;c\\\\d");
        assert_eq!(escape_text("l1\r\nl2\nl3\rl4"), "l1\\nl2\\nl3\\nl4");
        assert_eq!(escape_text("ok\u{7}x"), "okx");
        assert_eq!(escape_text("نمستے"), "نمستے");
    }
    #[test]
    fn folding() {
        let short = "SUMMARY:hi";
        assert_eq!(fold(short), short);
        let long = format!("SUMMARY:{}", "x".repeat(200));
        let f = fold(&long);
        for (i, l) in f.split("\r\n").enumerate() {
            let n = if i == 0 { l.len() } else { l.len() - 1 };
            assert!(n <= 75, "line {i} = {n}");
            if i > 0 {
                assert!(l.starts_with(' '));
            }
        }
        assert_eq!(f.replace("\r\n ", ""), long);
        // UTF-8 beech se nahi katta
        let u = format!("SUMMARY:{}", "é".repeat(60));
        assert_eq!(fold(&u).replace("\r\n ", ""), u);
    }
    #[test]
    fn ics_shape() {
        let mut e = ev("Standup, daily");
        e.agenda = Some("a\nb".into());
        e.location = Some("Room 1".into());
        let s = build_ics(&[e, ev("Two")]);
        assert!(s.starts_with("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"));
        assert!(s.ends_with("END:VCALENDAR\r\n"));
        assert!(s.contains("UID:abc@anexomail.com\r\n"));
        assert!(s.contains("DTSTART:20231114T221320Z\r\n"));
        assert!(s.contains("DTEND:20231114T231320Z\r\n"));
        assert!(s.contains("SUMMARY:Standup\\, daily\r\n"));
        assert!(s.contains("DESCRIPTION:a\\nb\r\n"));
        assert!(s.contains("LOCATION:Room 1\r\n"));
        assert_eq!(s.matches("BEGIN:VEVENT").count(), 2);
        // khali agenda/location likhe hi nahi jate
        assert_eq!(s.matches("DESCRIPTION").count(), 1);
        assert_eq!(build_ics(&[]), "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//ANEXOMAIL//Workspace//EN\r\nEND:VCALENDAR\r\n");
    }
}
