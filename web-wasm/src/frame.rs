//! Live protocol ke saaf, pure tukde (I/O nahi): newline frames, frame ki pehchaan, hello, backoff.
//! Yeh src/lib/live-core.ts ka Rust jora hai — dono ka rule ek jaisa (parity test src/lib/kernel/ mein).

pub const TOPICS: [&str; 6] = ["mail", "calendar", "crm", "work", "people", "org"];

#[derive(Debug, PartialEq, Eq, Clone)]
pub enum Frame {
    Ready,
    Event(usize), // TOPICS ka index
    Ping,
    Error(String),
    Ignore,
}

/// Ek flat JSON object ke top-level string fields: sirf {"type":"..","topic":"..","code":".."} jaisi server frames ke liye.
/// Nested object/array chhodh deta hai, kharab JSON par None.
pub fn flat_strings(line: &str) -> Option<Vec<(String, String)>> {
    let b = line.trim().as_bytes();
    let mut i = 0;
    let ws = |i: &mut usize| {
        while *i < b.len() && matches!(b[*i], b' ' | b'\t' | b'\r' | b'\n') {
            *i += 1;
        }
    };
    fn string(b: &[u8], i: &mut usize) -> Option<String> {
        if b.get(*i) != Some(&b'"') {
            return None;
        }
        *i += 1;
        let mut out: Vec<u8> = Vec::new();
        while *i < b.len() {
            match b[*i] {
                b'"' => {
                    *i += 1;
                    return String::from_utf8(out).ok();
                }
                b'\\' => {
                    *i += 1;
                    let c = *b.get(*i)?;
                    match c {
                        b'"' | b'\\' | b'/' => out.push(c),
                        b'n' => out.push(b'\n'),
                        b't' => out.push(b'\t'),
                        b'r' => out.push(b'\r'),
                        b'b' | b'f' => {}
                        b'u' => {
                            let hex = std::str::from_utf8(b.get(*i + 1..*i + 5)?).ok()?;
                            let cp = u32::from_str_radix(hex, 16).ok()?;
                            let ch = char::from_u32(cp).unwrap_or('\u{FFFD}');
                            let mut buf = [0u8; 4];
                            out.extend_from_slice(ch.encode_utf8(&mut buf).as_bytes());
                            *i += 4;
                        }
                        _ => return None,
                    }
                    *i += 1;
                }
                c => {
                    out.push(c);
                    *i += 1;
                }
            }
        }
        None
    }
    // value chhodo: string / number / true / false / null / balanced {} []
    fn skip_value(b: &[u8], i: &mut usize) -> Option<Option<String>> {
        match b.get(*i)? {
            b'"' => Some(Some(string(b, i)?)),
            b'{' | b'[' => {
                let mut depth = 0i32;
                let mut in_str = false;
                while *i < b.len() {
                    let c = b[*i];
                    if in_str {
                        if c == b'\\' {
                            *i += 1;
                        } else if c == b'"' {
                            in_str = false;
                        }
                    } else if c == b'"' {
                        in_str = true;
                    } else if c == b'{' || c == b'[' {
                        depth += 1;
                    } else if c == b'}' || c == b']' {
                        depth -= 1;
                        if depth == 0 {
                            *i += 1;
                            return Some(None);
                        }
                    }
                    *i += 1;
                }
                None
            }
            _ => {
                let s = *i;
                while *i < b.len() && !matches!(b[*i], b',' | b'}' | b' ' | b'\t' | b'\r' | b'\n') {
                    *i += 1;
                }
                if *i == s { None } else { Some(None) }
            }
        }
    }
    ws(&mut i);
    if b.get(i) != Some(&b'{') {
        return None;
    }
    i += 1;
    let mut out = Vec::new();
    loop {
        ws(&mut i);
        match b.get(i)? {
            b'}' => return Some(out),
            b',' => {
                i += 1;
                continue;
            }
            _ => {}
        }
        let k = string(b, &mut i)?;
        ws(&mut i);
        if b.get(i) != Some(&b':') {
            return None;
        }
        i += 1;
        ws(&mut i);
        if let Some(v) = skip_value(b, &mut i)? {
            out.push((k, v));
        }
    }
}

pub fn parse_frame(line: &str) -> Frame {
    let Some(f) = flat_strings(line) else { return Frame::Ignore };
    let get = |k: &str| f.iter().find(|(a, _)| a == k).map(|(_, v)| v.as_str());
    match get("type") {
        Some("ready") => Frame::Ready,
        Some("ping") => Frame::Ping,
        Some("error") => Frame::Error(get("code").unwrap_or("error").to_string()),
        Some("mail") => Frame::Event(0), // purana mode:"mail" frame
        Some("event") => match get("topic").and_then(|t| TOPICS.iter().position(|x| *x == t)) {
            Some(i) => Frame::Event(i),
            None => Frame::Ignore,
        },
        _ => Frame::Ignore,
    }
}

/// Errors jinka matlab "login gaya", network nahi — hammer mat karo.
pub fn is_auth_error(code: &str) -> bool {
    matches!(code, "unauthorized" | "session_ended" | "token_required" | "no_workspace" | "too_many_listeners")
}

/// attempt n (0-based) ke baad kitne ms ruko. `rand` in [0,1) 25% tak jitter.
pub fn backoff_ms(attempt: u32, rand: f64) -> u64 {
    let base = (1000u64 << attempt.min(5)).min(30_000);
    (base as f64 * (1.0 + 0.25 * rand.clamp(0.0, 1.0))).round() as u64
}

pub fn json_escape(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 2);
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            '\r' => o.push_str("\\r"),
            '\t' => o.push_str("\\t"),
            c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)),
            c => o.push(c),
        }
    }
    o
}

/// {"token":"..","mode":"events","topics":[..]} — server ka wt_session hello.
pub fn hello(token: &str) -> String {
    let topics = TOPICS.iter().map(|t| format!("\"{t}\"")).collect::<Vec<_>>().join(",");
    format!("{{\"token\":\"{}\",\"mode\":\"events\",\"topics\":[{topics}]}}", json_escape(token))
}

/// Chunks se lines: aadhi line agle chunk tak rukti hai. UTF-8 ka tukda chunk ke beech mein ho to bhi sahi.
#[derive(Default)]
pub struct LineBuf {
    raw: Vec<u8>,
}

impl LineBuf {
    pub fn push(&mut self, chunk: &[u8]) -> Vec<String> {
        self.raw.extend_from_slice(chunk);
        let mut lines = Vec::new();
        while let Some(p) = self.raw.iter().position(|b| *b == b'\n') {
            let rest = self.raw.split_off(p + 1);
            let mut line = std::mem::replace(&mut self.raw, rest);
            line.pop();
            lines.push(String::from_utf8_lossy(&line).into_owned());
        }
        lines
    }
    pub fn pending(&self) -> usize {
        self.raw.len()
    }
    pub fn clear(&mut self) {
        self.raw.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frames_match_the_typescript_rules() {
        assert_eq!(parse_frame(r#"{"type":"ready","transport":"webtransport"}"#), Frame::Ready);
        assert_eq!(parse_frame(r#"{"type":"ping"}"#), Frame::Ping);
        assert_eq!(parse_frame(r#"{"type":"error","code":"unauthorized"}"#), Frame::Error("unauthorized".into()));
        assert_eq!(parse_frame(r#"{"type":"error"}"#), Frame::Error("error".into()));
        assert_eq!(parse_frame(r#"{"type":"mail","unread":3}"#), Frame::Event(0));
        for (i, t) in TOPICS.iter().enumerate() {
            assert_eq!(parse_frame(&format!(r#"{{"type":"event","topic":"{t}"}}"#)), Frame::Event(i));
        }
        assert_eq!(parse_frame(r#"{"type":"event","topic":"nope"}"#), Frame::Ignore);
        assert_eq!(parse_frame("not json"), Frame::Ignore);
        assert_eq!(parse_frame(""), Frame::Ignore);
        assert_eq!(parse_frame(r#"{"type":"zzz"}"#), Frame::Ignore);
    }

    #[test]
    fn parser_survives_nesting_escapes_and_garbage() {
        let f = flat_strings(r#"{"a":{"type":"ready","x":[1,{"y":"}"}]},"type":"ping","n":12,"t":true,"z":null}"#).unwrap();
        assert_eq!(f, vec![("type".to_string(), "ping".to_string())], "nested type must not leak");
        assert_eq!(flat_strings(r#"{"s":"a\"b\\c\u00e9"}"#).unwrap()[0].1, "a\"b\\cé");
        for bad in ["{", "{\"a\"", "{\"a\":", "{\"a\":\"x", "[1]", "{\"a\":{", "{\"a\" 1}", "{\"\\q\":1}"] {
            assert!(flat_strings(bad).is_none(), "{bad}");
        }
        // 100k kharab bytes se panic nahi
        let junk = "{".repeat(100_000);
        assert!(flat_strings(&junk).is_none());
    }

    #[test]
    fn backoff_is_1_2_4_8_16_30_with_jitter() {
        let b: Vec<u64> = (0..8).map(|n| backoff_ms(n, 0.0)).collect();
        assert_eq!(b, vec![1000, 2000, 4000, 8000, 16000, 30000, 30000, 30000]);
        assert_eq!(backoff_ms(0, 1.0), 1250);
        assert_eq!(backoff_ms(5, 1.0), 37_500);
        assert_eq!(backoff_ms(0, 7.0), 1250, "rand is clamped");
        assert_eq!(backoff_ms(u32::MAX, 0.0), 30_000);
    }

    #[test]
    fn auth_errors() {
        for c in ["unauthorized", "session_ended", "token_required", "no_workspace", "too_many_listeners"] {
            assert!(is_auth_error(c));
        }
        assert!(!is_auth_error("db_error"));
    }

    #[test]
    fn hello_is_valid_and_escapes_the_token() {
        let h = hello("a\"b\\c\nd");
        let f = flat_strings(&h).unwrap();
        assert_eq!(f.iter().find(|(k, _)| k == "token").unwrap().1, "a\"b\\c\nd");
        assert_eq!(f.iter().find(|(k, _)| k == "mode").unwrap().1, "events");
        assert!(h.contains(r#""topics":["mail","calendar","crm","work","people","org"]"#));
        assert!(!hello("x").contains('\n'), "hello is a single line");
    }

    #[test]
    fn line_buffer_handles_split_chunks_and_multibyte() {
        let mut lb = LineBuf::default();
        assert!(lb.push(b"{\"type\":\"re").is_empty());
        assert_eq!(lb.push(b"ady\"}\n{\"type\":\"ping\"}\nrest"), vec![r#"{"type":"ready"}"#, r#"{"type":"ping"}"#]);
        assert_eq!(lb.pending(), 4);
        let s = "é\n".as_bytes(); // 0xC3 0xA9 0x0A
        let mut lb = LineBuf::default();
        assert!(lb.push(&s[..1]).is_empty());
        assert_eq!(lb.push(&s[1..]), vec!["é"]);
        let mut lb = LineBuf::default();
        assert_eq!(lb.push(b"\n\n"), vec!["", ""]);
    }
}
