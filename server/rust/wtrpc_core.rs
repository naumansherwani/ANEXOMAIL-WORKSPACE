// ============================================================================
// ANEXOMAIL — WebTransport RPC (`/wt/rpc`) ki saaf soch. std-only, unit tests ke saath; I/O wtrpc_glue.rs mein.
// WASM kernel (web-wasm, module rpc@1) ek QUIC session kholta hai; har call ek bidi stream: request {"token","proc","input"} -> wohi dispatcher jo
// `/rpc/<proc>` chalata hai -> jawab {"status":N,"body":<json>}. Alag endpoint/page ka code nahi: ek transport, har proc.
// ============================================================================

pub const MAX_REQUEST: usize = 1 << 20; // 1 MiB
pub const MAX_RESPONSE: usize = 8 << 20; // 8 MiB — kernel bhi yahi rokta hai
pub const MAX_STREAMS_PER_SESSION: usize = 64; // ek saath chalti calls
pub const SESSION_IDLE_SECS: u64 = 15 * 60; // koi stream nahi to session band
pub const SESSION_MAX_SECS: u64 = 60 * 60; // har session ki umar (token badalta rehta hai; reconnect sasta)

pub fn is_rpc_path(path: &str) -> bool {
    path == "/wt/rpc" || path.starts_with("/wt/rpc?")
}

/// Proc ka naam: a-z A-Z 0-9 . _ - ; 1..=96; ".." ya shuru/aakhir mein '.' nahi.
pub fn valid_proc(p: &str) -> bool {
    !p.is_empty()
        && p.len() <= 96
        && p.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-'))
        && !p.contains("..")
        && !p.starts_with('.')
        && !p.ends_with('.')
}

#[derive(Debug, PartialEq, Eq)]
pub struct Request<'a> {
    pub token: String,
    pub proc_name: String,
    /// `input` ka kaccha JSON text (jaisa aaya waisa; dispatcher khud parse karta hai). Na ho to "null".
    pub input_raw: &'a str,
    /// E90 request tag (optional): ticket + ts (epoch secs) + tag (hex HMAC-SHA256). Na ho to None.
    pub ticket: Option<String>,
    pub ts: Option<String>,
    pub tag: Option<String>,
}

/// ANEXO_TAG_MODE: observe (default) = sirf ginti, kabhi block nahi; enforce = WebTransport par bina sahi tag ke 401.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TagMode {
    Observe,
    Enforce,
}
impl TagMode {
    pub fn parse(s: &str) -> TagMode {
        if s.trim().eq_ignore_ascii_case("enforce") { TagMode::Enforce } else { TagMode::Observe }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TagState {
    Valid,
    Missing,
    Invalid,
}

pub const TAG_SKEW_SECS: i64 = 120;

/// Tag ke bagair chalne wale procs: ticket khud, report, aur public/login se pehle ke procs (token hi nahi hota unmein).
pub fn tag_exempt(proc_name: &str) -> bool {
    matches!(proc_name, "kernel.ticket" | "kernel.report")
}

pub fn ts_fresh(ts: &str, now: i64) -> bool {
    ts.parse::<i64>().map(|t| (now - t).abs() <= TAG_SKEW_SECS).unwrap_or(false)
}

pub fn tag_shape_ok(tag: &str) -> bool {
    tag.len() == 64 && tag.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

/// Message jo kernel sign karta hai: "<proc>.<ts>.<sha256hex(input_raw)>". Input hash glue karta hai (sha2 crate); yahan sirf jod.
pub fn tag_message(proc_name: &str, ts: &str, input_sha_hex: &str) -> String {
    format!("{proc_name}.{ts}.{input_sha_hex}")
}

/// Faisla: block karna hai ya nahi. Observe mein kabhi block nahi.
pub fn should_block(mode: TagMode, state: TagState, proc_name: &str) -> bool {
    mode == TagMode::Enforce && state != TagState::Valid && !tag_exempt(proc_name)
}

fn skip_ws(b: &[u8], i: &mut usize) {
    while *i < b.len() && matches!(b[*i], b' ' | b'\t' | b'\r' | b'\n') {
        *i += 1;
    }
}

/// i par '"' hai; band hone ke baad ka index. None = adhoori/kharab string.
fn skip_string(b: &[u8], mut i: usize) -> Option<usize> {
    if b.get(i) != Some(&b'"') {
        return None;
    }
    i += 1;
    while i < b.len() {
        match b[i] {
            b'"' => return Some(i + 1),
            b'\\' => i += 2,
            _ => i += 1,
        }
    }
    None
}

/// Ek JSON value ka aakhri index (exclusive). Depth <= 64.
fn skip_value(b: &[u8], i: usize) -> Option<usize> {
    match *b.get(i)? {
        b'"' => skip_string(b, i),
        b'{' | b'[' => {
            let mut depth = 0i32;
            let mut j = i;
            while j < b.len() {
                match b[j] {
                    b'"' => j = skip_string(b, j)? - 1,
                    b'{' | b'[' => {
                        depth += 1;
                        if depth > 64 {
                            return None;
                        }
                    }
                    b'}' | b']' => {
                        depth -= 1;
                        if depth == 0 {
                            return Some(j + 1);
                        }
                    }
                    _ => {}
                }
                j += 1;
            }
            None
        }
        _ => {
            let mut j = i;
            while j < b.len() && !matches!(b[j], b',' | b'}' | b']' | b' ' | b'\t' | b'\r' | b'\n') {
                j += 1;
            }
            (j > i).then_some(j)
        }
    }
}

pub fn unescape(raw: &str) -> Option<String> {
    let inner = raw.strip_prefix('"')?.strip_suffix('"')?;
    let mut out = String::with_capacity(inner.len());
    let mut it = inner.chars();
    while let Some(c) = it.next() {
        if c != '\\' {
            out.push(c);
            continue;
        }
        match it.next()? {
            '"' => out.push('"'),
            '\\' => out.push('\\'),
            '/' => out.push('/'),
            'n' => out.push('\n'),
            't' => out.push('\t'),
            'r' => out.push('\r'),
            'b' | 'f' => {}
            'u' => {
                let hex: String = it.by_ref().take(4).collect();
                if hex.len() != 4 {
                    return None;
                }
                out.push(char::from_u32(u32::from_str_radix(&hex, 16).ok()?).unwrap_or('\u{FFFD}'));
            }
            _ => return None,
        }
    }
    Some(out)
}

/// Request bytes -> {token, proc, input}. Pehla maqsad: bina serde ke, bina kharab input par panic ke.
pub fn parse_request(bytes: &[u8]) -> Result<Request<'_>, &'static str> {
    if bytes.is_empty() {
        return Err("empty_request");
    }
    if bytes.len() > MAX_REQUEST {
        return Err("request_too_large");
    }
    let text = std::str::from_utf8(bytes).map_err(|_| "bad_request")?;
    let b = text.as_bytes();
    let mut i = 0;
    skip_ws(b, &mut i);
    if b.get(i) != Some(&b'{') {
        return Err("bad_request");
    }
    i += 1;
    let (mut token, mut proc_name, mut input_raw): (Option<String>, Option<String>, Option<&str>) = (None, None, None);
    let (mut ticket, mut ts, mut tag): (Option<String>, Option<String>, Option<String>) = (None, None, None);
    loop {
        skip_ws(b, &mut i);
        match b.get(i) {
            Some(b'}') => break,
            Some(b',') => {
                i += 1;
                continue;
            }
            Some(b'"') => {}
            _ => return Err("bad_request"),
        }
        let kend = skip_string(b, i).ok_or("bad_request")?;
        let key = unescape(&text[i..kend]).ok_or("bad_request")?;
        i = kend;
        skip_ws(b, &mut i);
        if b.get(i) != Some(&b':') {
            return Err("bad_request");
        }
        i += 1;
        skip_ws(b, &mut i);
        let vend = skip_value(b, i).ok_or("bad_request")?;
        let raw = &text[i..vend];
        match key.as_str() {
            "token" => token = Some(unescape(raw).ok_or("bad_request")?),
            "proc" => proc_name = Some(unescape(raw).ok_or("bad_request")?),
            "input" => input_raw = Some(raw),
            "ticket" => ticket = unescape(raw).filter(|t| t.len() <= 1024),
            "ts" => ts = unescape(raw).filter(|t| t.len() <= 20),
            "tag" => tag = unescape(raw).filter(|t| t.len() <= 128),
            _ => {}
        }
        i = vend;
    }
    let token = token.filter(|t| !t.is_empty() && t.len() <= 8192).ok_or("token_required")?;
    let proc_name = proc_name.filter(|p| valid_proc(p)).ok_or("bad_proc")?;
    Ok(Request { token, proc_name, input_raw: input_raw.unwrap_or("null"), ticket, ts, tag })
}

/// Dispatcher ko dene wali body: {"input": <raw>}.
pub fn dispatcher_body(input_raw: &str) -> String {
    format!("{{\"input\":{input_raw}}}")
}

/// Jawab frame. `body_is_json` glue ne serde se jaancha; nahi to body ek JSON string ban jata hai.
pub fn compose(status: u16, body: &str, body_is_json: bool) -> String {
    let status = if (100..=599).contains(&status) { status } else { 502 };
    let b = body.trim();
    if b.is_empty() {
        return format!("{{\"status\":{status},\"body\":null}}");
    }
    if body_is_json {
        return format!("{{\"status\":{status},\"body\":{b}}}");
    }
    let mut esc = String::with_capacity(b.len() + 2);
    for c in b.chars() {
        match c {
            '"' => esc.push_str("\\\""),
            '\\' => esc.push_str("\\\\"),
            '\n' => esc.push_str("\\n"),
            '\r' => esc.push_str("\\r"),
            '\t' => esc.push_str("\\t"),
            c if (c as u32) < 0x20 => esc.push_str(&format!("\\u{:04x}", c as u32)),
            c => esc.push(c),
        }
    }
    format!("{{\"status\":{status},\"body\":\"{esc}\"}}")
}

pub fn error_frame(status: u16, code: &str) -> String {
    format!("{{\"status\":{status},\"body\":{{\"error\":{{\"code\":\"{code}\",\"message\":\"{code}\"}}}}}}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn paths() {
        assert!(is_rpc_path("/wt/rpc") && is_rpc_path("/wt/rpc?x=1"));
        assert!(!is_rpc_path("/wt/events") && !is_rpc_path("/wt/rpcx") && !is_rpc_path("/wt/rpc/") && !is_rpc_path(""));
    }

    #[test]
    fn proc_names() {
        for ok in ["mail.threads", "analytics.responseDebt", "a", "calendar.rooms.book", "x-y_z.1"] {
            assert!(valid_proc(ok), "{ok}");
        }
        for bad in ["", ".a", "a.", "a..b", "a/b", "a b", "../x", "a\"b", &"a".repeat(97)] {
            assert!(!valid_proc(bad), "{bad}");
        }
    }

    #[test]
    fn parses_a_normal_request_and_keeps_input_raw() {
        let r = parse_request(br#"{"token":"abc","proc":"mail.threads","input":{"folder":"inbox","n":[1,2,{"x":"}"}]}}"#).unwrap();
        assert_eq!(r.token, "abc");
        assert_eq!(r.proc_name, "mail.threads");
        assert_eq!(r.input_raw, r#"{"folder":"inbox","n":[1,2,{"x":"}"}]}"#);
        assert_eq!(dispatcher_body(r.input_raw), r#"{"input":{"folder":"inbox","n":[1,2,{"x":"}"}]}}"#);
    }

    #[test]
    fn field_order_whitespace_unknown_keys_and_missing_input() {
        let r = parse_request(b" { \"proc\" : \"whoami\" , \"extra\": [1,2] , \"token\" : \"t\\\"k\" } ").unwrap();
        assert_eq!((r.token.as_str(), r.proc_name.as_str(), r.input_raw), ("t\"k", "whoami", "null"));
        let r = parse_request(br#"{"token":"t","proc":"p","input":null}"#).unwrap();
        assert_eq!(r.input_raw, "null");
        let r = parse_request(br#"{"token":"t","proc":"p","input":"s\"x"}"#).unwrap();
        assert_eq!(r.input_raw, r#""s\"x""#);
        let r = parse_request(br#"{"token":"t","proc":"p","input":12.5e3}"#).unwrap();
        assert_eq!(r.input_raw, "12.5e3");
    }

    #[test]
    fn rejects_garbage_without_panicking() {
        for (bad, why) in [
            (&b""[..], "empty_request"),
            (b"[]", "bad_request"),
            (b"{", "bad_request"),
            (b"{\"token\"", "bad_request"),
            (b"{\"token\":", "bad_request"),
            (b"{\"token\":\"x", "bad_request"),
            (br#"{"proc":"p"}"#, "token_required"),
            (br#"{"token":"","proc":"p"}"#, "token_required"),
            (br#"{"token":"t"}"#, "bad_proc"),
            (br#"{"token":"t","proc":"../etc/passwd"}"#, "bad_proc"),
            (br#"{"token":"t","proc":"a b"}"#, "bad_proc"),
            (&[0xff, 0xfe][..], "bad_request"),
        ] {
            assert_eq!(parse_request(bad).unwrap_err(), why, "{:?}", String::from_utf8_lossy(bad));
        }
        let deep = format!("{{\"token\":\"t\",\"proc\":\"p\",\"input\":{}}}", "[".repeat(100_000));
        assert!(parse_request(deep.as_bytes()).is_err(), "depth bomb is refused");
        let big = vec![b' '; MAX_REQUEST + 1];
        assert_eq!(parse_request(&big).unwrap_err(), "request_too_large");
        let long_token = format!("{{\"token\":\"{}\",\"proc\":\"p\"}}", "a".repeat(9000));
        assert_eq!(parse_request(long_token.as_bytes()).unwrap_err(), "token_required");
    }

    #[test]
    fn unicode_escapes() {
        let esc = format!("{{\"token\":\"{b}u0061b{b}u00e9\",\"proc\":\"p\"}}", b = '\\');
        let r = parse_request(esc.as_bytes()).unwrap();
        assert_eq!(r.token, "abé");
        assert!(parse_request(br#"{"token":"\u00","proc":"p"}"#).is_err());
        assert!(parse_request(br#"{"token":"\q","proc":"p"}"#).is_err());
    }

    #[test]
    fn response_frames() {
        assert_eq!(compose(200, r#"{"ok":true}"#, true), r#"{"status":200,"body":{"ok":true}}"#);
        assert_eq!(compose(200, "", true), r#"{"status":200,"body":null}"#);
        assert_eq!(compose(502, "bad \"gateway\"\n", false), r#"{"status":502,"body":"bad \"gateway\""}"#);
        assert_eq!(compose(0, "{}", true), r#"{"status":502,"body":{}}"#, "nonsense status never leaks");
        assert_eq!(error_frame(413, "request_too_large"), r#"{"status":413,"body":{"error":{"code":"request_too_large","message":"request_too_large"}}}"#);
    }

    #[test]
    fn tag_fields_parse_and_default_to_none() {
        let r = parse_request(br#"{"token":"t","proc":"mail.threads","input":{"a":1},"ticket":"v1.u.1.n.k.t","ts":"1700000000","tag":"ab"}"#).unwrap();
        assert_eq!((r.ticket.as_deref(), r.ts.as_deref(), r.tag.as_deref()), (Some("v1.u.1.n.k.t"), Some("1700000000"), Some("ab")));
        assert_eq!(r.input_raw, r#"{"a":1}"#);
        let r2 = parse_request(br#"{"token":"t","proc":"whoami"}"#).unwrap();
        assert!(r2.ticket.is_none() && r2.ts.is_none() && r2.tag.is_none());
    }

    #[test]
    fn tag_mode_and_block_decision() {
        assert_eq!(TagMode::parse("enforce"), TagMode::Enforce);
        assert_eq!(TagMode::parse(" ENFORCE "), TagMode::Enforce);
        assert_eq!(TagMode::parse(""), TagMode::Observe);
        assert_eq!(TagMode::parse("anything"), TagMode::Observe);
        for st in [TagState::Valid, TagState::Missing, TagState::Invalid] {
            assert!(!should_block(TagMode::Observe, st, "mail.threads"), "observe kabhi block nahi");
        }
        assert!(!should_block(TagMode::Enforce, TagState::Valid, "mail.threads"));
        assert!(should_block(TagMode::Enforce, TagState::Missing, "mail.threads"));
        assert!(should_block(TagMode::Enforce, TagState::Invalid, "mail.threads"));
        assert!(!should_block(TagMode::Enforce, TagState::Missing, "kernel.ticket"), "ticket khud tag ke bina");
    }

    #[test]
    fn ts_window_and_tag_shape_and_message() {
        assert!(ts_fresh("1000", 1000) && ts_fresh("1120", 1000) && ts_fresh("880", 1000));
        assert!(!ts_fresh("1121", 1000) && !ts_fresh("879", 1000) && !ts_fresh("x", 1000) && !ts_fresh("", 1000));
        assert!(tag_shape_ok(&"a".repeat(64)) && !tag_shape_ok(&"A".repeat(64)) && !tag_shape_ok("abc"));
        assert_eq!(tag_message("mail.threads", "17", "ff"), "mail.threads.17.ff");
    }
}
