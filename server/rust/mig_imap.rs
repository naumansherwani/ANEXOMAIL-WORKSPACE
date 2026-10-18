// mig_imap.rs — a small, strict IMAP4rev1 client (part of mig_core). std-only; it speaks over ANY `Read + Write`
// (the glue hands it a TLS stream, the tests hand it a loopback fake server).
//
// Safety properties the worker relies on:
//   * READ-ONLY on the customer's side: only EXAMINE (never SELECT), BODY.PEEK (never marks mail as read), no STORE/EXPUNGE/DELETE.
//   * bounded memory: a line is at most MAX_LINE bytes; a literal bigger than the caller's limit is READ AND DROPPED
//     (so the connection stays in sync) and reported as `Skipped(n)`; one message at a time is handed to the caller.
//   * the password only ever exists inside `login`'s command buffer, which is wiped after use. It is never logged:
//     error texts come from the SERVER'S reply, and `Debug` of the client prints no secrets.

use super::{classify_imap_text, ErrKind};
use std::io::{Read, Write};

pub const MAX_LINE: usize = 64 * 1024;
const MAX_DEPTH: usize = 12;
const MAX_TOKENS: usize = 4096;

#[derive(Debug, Clone, PartialEq)]
pub struct ImapError {
    pub kind: ErrKind,
    pub text: String,
}

impl ImapError {
    pub fn new(kind: ErrKind, text: impl Into<String>) -> Self {
        ImapError { kind, text: text.into() }
    }
    /// every socket problem (timeout, reset, broken pipe, EOF) is a dropped connection: reconnect and carry on
    fn io(e: std::io::Error) -> Self {
        let text = format!("io: {e}");
        // A bad certificate / failed handshake will not get better by retrying. rustls reports those as InvalidData;
        // a dropped connection ("peer closed connection without sending TLS close_notify") is UnexpectedEof/Reset and
        // must stay retryable even though its text contains the word TLS.
        let kind = if e.kind() == std::io::ErrorKind::InvalidData && classify_imap_text(&text) == ErrKind::Tls {
            ErrKind::Tls
        } else {
            ErrKind::Transient
        };
        ImapError { kind, text }
    }
}

type R<T> = Result<T, ImapError>;

#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    Atom(String),
    Quoted(String),
    Lit(Vec<u8>),
    /// a literal that was bigger than the limit: its bytes were read and dropped
    Skipped(u64),
    List(Vec<Token>),
    Nil,
}

impl Token {
    fn text(&self) -> Option<String> {
        match self {
            Token::Atom(s) | Token::Quoted(s) => Some(s.clone()),
            Token::Lit(b) => Some(String::from_utf8_lossy(b).into_owned()),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum Body {
    Bytes(Vec<u8>),
    Skipped(u64),
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct FetchData {
    pub seq: u32,
    pub uid: Option<u32>,
    pub flags: Vec<String>,
    pub internaldate: Option<String>,
    pub size: Option<u64>,
    pub body: Option<Body>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ListItem {
    pub attrs: Vec<String>,
    pub delim: Option<String>,
    /// exactly as the server sent it (modified UTF-7) — this is what goes back into EXAMINE
    pub raw: String,
    /// decoded for people and for the folder rules
    pub name: String,
}

#[derive(Debug, Clone, PartialEq)]
pub enum Untagged {
    Status { kind: String, text: String },
    Capability(Vec<String>),
    List(ListItem),
    Exists(u32),
    Recent(u32),
    Expunge(u32),
    Search(Vec<u32>),
    Fetch(FetchData),
    Other(String),
}

#[derive(Debug, Clone, PartialEq)]
pub enum Resp {
    Tagged { tag: String, ok: bool, bad: bool, text: String },
    Untagged(Untagged),
    Continue(String),
}

/* ------------------------------------------------------------------ text helpers */

pub fn base64_encode(b: &[u8]) -> String {
    const T: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity((b.len() + 2) / 3 * 4);
    for c in b.chunks(3) {
        let n = (c[0] as u32) << 16 | (*c.get(1).unwrap_or(&0) as u32) << 8 | *c.get(2).unwrap_or(&0) as u32;
        out.push(T[(n >> 18) as usize & 63] as char);
        out.push(T[(n >> 12) as usize & 63] as char);
        out.push(if c.len() > 1 { T[(n >> 6) as usize & 63] as char } else { '=' });
        out.push(if c.len() > 2 { T[n as usize & 63] as char } else { '=' });
    }
    out
}

/// IMAP quoted string. Refuses anything that cannot be sent safely inside quotes.
pub fn quote(s: &str) -> Option<String> {
    if s.is_empty() {
        return Some("\"\"".into());
    }
    if s.chars().any(|c| c == '\r' || c == '\n' || c == '\0' || (c as u32) > 0x7e || (c as u32) < 0x20) {
        return None;
    }
    let mut o = String::with_capacity(s.len() + 2);
    o.push('"');
    for c in s.chars() {
        if c == '"' || c == '\\' {
            o.push('\\');
        }
        o.push(c);
    }
    o.push('"');
    Some(o)
}

/// RFC 3501 §5.1.3 modified UTF-7 -> UTF-8. A malformed sequence is left as typed (never panics).
pub fn decode_mutf7(s: &str) -> String {
    let b: Vec<char> = s.chars().collect();
    let mut out = String::new();
    let mut i = 0;
    while i < b.len() {
        if b[i] != '&' {
            out.push(b[i]);
            i += 1;
            continue;
        }
        match b[i + 1..].iter().position(|&c| c == '-') {
            Some(end) => {
                let seg: String = b[i + 1..i + 1 + end].iter().collect();
                if seg.is_empty() {
                    out.push('&');
                } else {
                    let std: String = seg.replace(',', "/");
                    let bytes = super::mime::base64_decode(std.as_bytes());
                    let units: Vec<u16> = bytes.chunks(2).filter(|c| c.len() == 2).map(|c| u16::from_be_bytes([c[0], c[1]])).collect();
                    match String::from_utf16(&units) {
                        Ok(t) if !units.is_empty() => out.push_str(&t),
                        _ => {
                            out.push('&');
                            out.push_str(&seg);
                            out.push('-');
                        }
                    }
                }
                i += end + 2;
            }
            None => {
                out.push('&');
                i += 1;
            }
        }
    }
    out
}

fn num(s: &str) -> Option<u64> {
    s.parse().ok()
}

/* ------------------------------------------------------------------ the connection */

pub struct Conn<S: Read + Write> {
    s: S,
    buf: Vec<u8>,
    pos: usize,
    end: usize,
    tag: u32,
    /// bytes of mail received on this connection (for progress / throttling decisions)
    pub bytes_in: u64,
    pub max_line: usize,
}

impl<S: Read + Write> std::fmt::Debug for Conn<S> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Conn(tag={}, in={})", self.tag, self.bytes_in)
    }
}

impl<S: Read + Write> Conn<S> {
    pub fn new(s: S) -> Self {
        Conn { s, buf: vec![0; 16 * 1024], pos: 0, end: 0, tag: 0, bytes_in: 0, max_line: MAX_LINE }
    }

    pub fn into_inner(self) -> S {
        self.s
    }

    fn fill(&mut self) -> R<()> {
        if self.pos < self.end {
            return Ok(());
        }
        self.pos = 0;
        self.end = 0;
        loop {
            match self.s.read(&mut self.buf) {
                Ok(0) => return Err(ImapError::new(ErrKind::Transient, "connection closed by server")),
                Ok(n) => {
                    self.end = n;
                    self.bytes_in += n as u64;
                    return Ok(());
                }
                Err(e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
                Err(e) => return Err(ImapError::io(e)),
            }
        }
    }

    /// one line without its CRLF (a bare LF is accepted too)
    pub fn read_line(&mut self) -> R<Vec<u8>> {
        let mut line: Vec<u8> = Vec::new();
        loop {
            self.fill()?;
            let chunk = &self.buf[self.pos..self.end];
            match chunk.iter().position(|&c| c == b'\n') {
                Some(i) => {
                    line.extend_from_slice(&chunk[..i]);
                    self.pos += i + 1;
                    if line.last() == Some(&b'\r') {
                        line.pop();
                    }
                    if line.len() > self.max_line {
                        return Err(ImapError::new(ErrKind::Fatal, "response line too long"));
                    }
                    return Ok(line);
                }
                None => {
                    line.extend_from_slice(chunk);
                    self.pos = self.end;
                    if line.len() > self.max_line {
                        return Err(ImapError::new(ErrKind::Fatal, "response line too long"));
                    }
                }
            }
        }
    }

    /// exactly `n` bytes. Over `max`: they are consumed and dropped, `Ok(None)` says so.
    fn read_literal(&mut self, n: u64, max: usize) -> R<Option<Vec<u8>>> {
        let keep = n <= max as u64;
        let mut out: Vec<u8> = if keep { Vec::with_capacity(n as usize) } else { Vec::new() };
        let mut left = n;
        while left > 0 {
            self.fill()?;
            let avail = (self.end - self.pos) as u64;
            let take = avail.min(left) as usize;
            if keep {
                out.extend_from_slice(&self.buf[self.pos..self.pos + take]);
            }
            self.pos += take;
            left -= take as u64;
        }
        Ok(if keep { Some(out) } else { None })
    }

    fn write_all(&mut self, b: &[u8]) -> R<()> {
        self.s.write_all(b).map_err(ImapError::io)?;
        self.s.flush().map_err(ImapError::io)
    }

    /* ---- tokenizer: handles (nested lists), "quoted", atoms, NIL and {n} literals that continue on the next line */

    fn tokenize(&mut self, first: &[u8], max_lit: usize) -> R<Vec<Token>> {
        let mut stack: Vec<Vec<Token>> = vec![Vec::new()];
        let mut line: Vec<u8> = first.to_vec();
        let mut count = 0usize;
        loop {
            let mut i = 0;
            let mut pending: Option<u64> = None;
            while i < line.len() {
                let c = line[i];
                count += 1;
                if count > MAX_TOKENS * 64 {
                    return Err(ImapError::new(ErrKind::Fatal, "response too complex"));
                }
                match c {
                    b' ' | b'\t' => i += 1,
                    b'(' => {
                        if stack.len() > MAX_DEPTH {
                            return Err(ImapError::new(ErrKind::Fatal, "response nested too deep"));
                        }
                        stack.push(Vec::new());
                        i += 1;
                    }
                    b')' => {
                        if stack.len() < 2 {
                            return Err(ImapError::new(ErrKind::Fatal, "unbalanced ) in response"));
                        }
                        let l = stack.pop().unwrap();
                        stack.last_mut().unwrap().push(Token::List(l));
                        i += 1;
                    }
                    b'"' => {
                        let mut s: Vec<u8> = Vec::new();
                        i += 1;
                        let mut closed = false;
                        while i < line.len() {
                            match line[i] {
                                b'\\' if i + 1 < line.len() => {
                                    s.push(line[i + 1]);
                                    i += 2;
                                }
                                b'"' => {
                                    closed = true;
                                    i += 1;
                                    break;
                                }
                                x => {
                                    s.push(x);
                                    i += 1;
                                }
                            }
                        }
                        if !closed {
                            return Err(ImapError::new(ErrKind::Fatal, "unterminated quoted string"));
                        }
                        stack.last_mut().unwrap().push(Token::Quoted(String::from_utf8_lossy(&s).into_owned()));
                    }
                    b'{' => {
                        // {123} or {123+} must end the line
                        let close = line[i..].iter().position(|&x| x == b'}').map(|p| i + p);
                        let close = match close {
                            Some(c) if c + 1 == line.len() => c,
                            _ => return Err(ImapError::new(ErrKind::Fatal, "bad literal marker")),
                        };
                        let inner = std::str::from_utf8(&line[i + 1..close]).unwrap_or("").trim_end_matches('+');
                        pending = Some(num(inner).ok_or_else(|| ImapError::new(ErrKind::Fatal, "bad literal size"))?);
                        i = line.len();
                    }
                    _ => {
                        let st = i;
                        let mut br = 0i32;
                        while i < line.len() {
                            let x = line[i];
                            if x == b'[' {
                                br += 1;
                            } else if x == b']' {
                                br -= 1;
                            }
                            if br <= 0 && (x == b' ' || x == b'(' || x == b')' || x == b'"' || x == b'\t') {
                                break;
                            }
                            i += 1;
                        }
                        let a = String::from_utf8_lossy(&line[st..i]).into_owned();
                        let t = if a.eq_ignore_ascii_case("nil") { Token::Nil } else { Token::Atom(a) };
                        stack.last_mut().unwrap().push(t);
                    }
                }
            }
            match pending {
                Some(n) => {
                    let t = match self.read_literal(n, max_lit)? {
                        Some(b) => Token::Lit(b),
                        None => Token::Skipped(n),
                    };
                    stack.last_mut().unwrap().push(t);
                    line = self.read_line()?; // the rest of the response continues on the next line
                }
                None => {
                    if stack.len() != 1 {
                        return Err(ImapError::new(ErrKind::Fatal, "unbalanced ( in response"));
                    }
                    return Ok(stack.pop().unwrap());
                }
            }
        }
    }

    /// next response from the server (one logical response, literals included)
    pub fn next_response(&mut self, max_lit: usize) -> R<Resp> {
        let line = self.read_line()?;
        if line.first() == Some(&b'+') {
            return Ok(Resp::Continue(String::from_utf8_lossy(&line[1..]).trim().to_string()));
        }
        if line.starts_with(b"* ") {
            return self.untagged(&line[2..], max_lit).map(Resp::Untagged);
        }
        let text = String::from_utf8_lossy(&line).into_owned();
        let mut it = text.splitn(3, ' ');
        let tag = it.next().unwrap_or("").to_string();
        let st = it.next().unwrap_or("").to_uppercase();
        let rest = it.next().unwrap_or("").to_string();
        if tag.is_empty() || st.is_empty() {
            return Err(ImapError::new(ErrKind::Fatal, "unreadable response"));
        }
        Ok(Resp::Tagged { tag, ok: st == "OK", bad: st == "BAD", text: rest })
    }

    fn untagged(&mut self, rest: &[u8], max_lit: usize) -> R<Untagged> {
        let s = String::from_utf8_lossy(rest).into_owned();
        let mut words = s.splitn(3, ' ');
        let w1 = words.next().unwrap_or("");
        let w2 = words.next().unwrap_or("");
        let up1 = w1.to_uppercase();
        if matches!(up1.as_str(), "OK" | "NO" | "BAD" | "BYE" | "PREAUTH") {
            let text = s[w1.len()..].trim().to_string();
            return Ok(Untagged::Status { kind: up1, text });
        }
        if up1 == "CAPABILITY" {
            return Ok(Untagged::Capability(s.split_whitespace().skip(1).map(|x| x.to_uppercase()).collect()));
        }
        if up1 == "SEARCH" {
            return Ok(Untagged::Search(s.split_whitespace().skip(1).filter_map(|x| x.parse().ok()).collect()));
        }
        if up1 == "LIST" || up1 == "LSUB" {
            let after = &rest[w1.len()..];
            let t = self.tokenize(after, 64 * 1024)?;
            // (attrs) delim name
            if t.len() >= 3 {
                if let Token::List(a) = &t[0] {
                    let attrs = a.iter().filter_map(|x| x.text()).collect();
                    let delim = t[1].text();
                    let raw = t[2].text().unwrap_or_default();
                    return Ok(Untagged::List(ListItem { attrs, delim, name: decode_mutf7(&raw), raw }));
                }
            }
            return Ok(Untagged::Other(s));
        }
        if let Some(n) = num(w1) {
            let up2 = w2.to_uppercase();
            match up2.as_str() {
                "EXISTS" => return Ok(Untagged::Exists(n as u32)),
                "RECENT" => return Ok(Untagged::Recent(n as u32)),
                "EXPUNGE" => return Ok(Untagged::Expunge(n as u32)),
                "FETCH" => {
                    let from = rest.iter().position(|&c| c == b'(').unwrap_or(rest.len());
                    let t = self.tokenize(&rest[from..], max_lit)?;
                    let items = match t.first() {
                        Some(Token::List(l)) => l.clone(),
                        _ => return Ok(Untagged::Other(s)),
                    };
                    let mut f = FetchData { seq: n as u32, ..Default::default() };
                    let mut i = 0;
                    while i + 1 < items.len() {
                        let key = items[i].text().unwrap_or_default().to_uppercase();
                        let v = &items[i + 1];
                        match key.as_str() {
                            "UID" => f.uid = v.text().and_then(|x| x.parse().ok()),
                            "FLAGS" => {
                                if let Token::List(l) = v {
                                    f.flags = l.iter().filter_map(|x| x.text()).collect();
                                }
                            }
                            "INTERNALDATE" => f.internaldate = v.text(),
                            "RFC822.SIZE" => f.size = v.text().and_then(|x| x.parse().ok()),
                            k if k.starts_with("BODY[") || k == "RFC822" => {
                                f.body = match v {
                                    Token::Lit(b) => Some(Body::Bytes(b.clone())),
                                    Token::Skipped(n) => Some(Body::Skipped(*n)),
                                    Token::Quoted(q) => Some(Body::Bytes(q.clone().into_bytes())),
                                    _ => None,
                                }
                            }
                            _ => {}
                        }
                        i += 2;
                    }
                    return Ok(Untagged::Fetch(f));
                }
                _ => {}
            }
        }
        Ok(Untagged::Other(s))
    }

    /* ---- commands */

    fn next_tag(&mut self) -> String {
        self.tag += 1;
        format!("A{:04}", self.tag)
    }

    /// Run one command and feed every untagged response to `on` as it arrives (so a big FETCH never piles up).
    /// Returns the tagged reply text on OK; NO / BAD become an error whose kind comes from the server's words.
    pub fn run(&mut self, cmd: &str, max_lit: usize, mut on: impl FnMut(Untagged)) -> R<String> {
        let tag = self.next_tag();
        let mut line = format!("{tag} {cmd}\r\n").into_bytes();
        let sent = self.write_all(&line);
        wipe(&mut line);
        sent?;
        loop {
            match self.next_response(max_lit)? {
                Resp::Untagged(Untagged::Status { kind, text }) if kind == "BYE" => {
                    return Err(ImapError::new(classify_imap_text(&text), format!("server closed: {text}")));
                }
                Resp::Untagged(u) => on(u),
                Resp::Continue(_) => return Err(ImapError::new(ErrKind::Fatal, "unexpected continuation request")),
                Resp::Tagged { tag: t, ok, bad, text } => {
                    if t != tag {
                        continue; // not ours
                    }
                    if ok {
                        return Ok(text);
                    }
                    let kind = classify_imap_text(&text);
                    return Err(ImapError::new(if bad && kind == ErrKind::Transient { ErrKind::Fatal } else { kind }, text));
                }
            }
        }
    }

    /// server greeting (first line after the TLS handshake)
    pub fn greeting(&mut self) -> R<String> {
        match self.next_response(0)? {
            Resp::Untagged(Untagged::Status { kind, text }) if kind == "OK" || kind == "PREAUTH" => Ok(text),
            Resp::Untagged(Untagged::Status { text, .. }) => Err(ImapError::new(classify_imap_text(&text), text)),
            _ => Err(ImapError::new(ErrKind::Fatal, "no IMAP greeting")),
        }
    }

    pub fn capability(&mut self) -> R<Vec<String>> {
        let mut caps = Vec::new();
        self.run("CAPABILITY", 0, |u| {
            if let Untagged::Capability(c) = u {
                caps = c;
            }
        })?;
        Ok(caps)
    }

    /// LOGIN with quoting when that is safe, AUTHENTICATE PLAIN (UTF-8 safe) otherwise. Never logs the secret.
    pub fn login(&mut self, user: &str, pass: &str, caps: &[String]) -> R<()> {
        if caps.iter().any(|c| c == "LOGINDISABLED") && !caps.iter().any(|c| c == "AUTH=PLAIN") {
            return Err(ImapError::new(ErrKind::Auth, "login is disabled on this server"));
        }
        match (quote(user), quote(pass)) {
            (Some(u), Some(p)) if !caps.iter().any(|c| c == "LOGINDISABLED") => {
                let mut cmd = format!("LOGIN {u} {p}");
                let r = self.run(&cmd, 0, |_| {});
                wipe_string(&mut cmd);
                r.map(|_| ()).map_err(auth_error)
            }
            _ => self.authenticate_plain(user, pass),
        }
    }

    fn authenticate_plain(&mut self, user: &str, pass: &str) -> R<()> {
        let tag = self.next_tag();
        let mut first = format!("{tag} AUTHENTICATE PLAIN\r\n").into_bytes();
        self.write_all(&first)?;
        wipe(&mut first);
        loop {
            match self.next_response(0)? {
                Resp::Continue(_) => break,
                Resp::Untagged(_) => continue,
                Resp::Tagged { text, .. } => return Err(auth_error(ImapError::new(classify_imap_text(&text), text))),
            }
        }
        let mut raw: Vec<u8> = Vec::new();
        raw.push(0);
        raw.extend_from_slice(user.as_bytes());
        raw.push(0);
        raw.extend_from_slice(pass.as_bytes());
        let mut enc = base64_encode(&raw).into_bytes();
        wipe(&mut raw);
        enc.extend_from_slice(b"\r\n");
        let w = self.write_all(&enc);
        wipe(&mut enc);
        w?;
        loop {
            match self.next_response(0)? {
                Resp::Tagged { tag: t, ok, text, .. } if t == tag => {
                    return if ok { Ok(()) } else { Err(auth_error(ImapError::new(classify_imap_text(&text), text))) };
                }
                _ => continue,
            }
        }
    }

    pub fn list_folders(&mut self) -> R<Vec<ListItem>> {
        let mut out = Vec::new();
        self.run("LIST \"\" \"*\"", 64 * 1024, |u| {
            if let Untagged::List(l) = u {
                out.push(l);
            }
        })?;
        Ok(out)
    }

    /// EXAMINE = open read-only. Returns (UIDVALIDITY, exists).
    pub fn examine(&mut self, raw_name: &str) -> R<(u32, u32)> {
        let q = quote(raw_name).ok_or_else(|| ImapError::new(ErrKind::Fatal, "folder name cannot be sent"))?;
        let mut validity = 0u32;
        let mut exists = 0u32;
        self.run(&format!("EXAMINE {q}"), 0, |u| match u {
            Untagged::Exists(n) => exists = n,
            Untagged::Status { text, .. } => {
                if let Some(v) = resp_code_num(&text, "UIDVALIDITY") {
                    validity = v as u32;
                }
            }
            _ => {}
        })?;
        if validity == 0 {
            return Err(ImapError::new(ErrKind::Fatal, "server did not report UIDVALIDITY"));
        }
        Ok((validity, exists))
    }

    /// all UIDs in the open folder, ascending
    pub fn uid_search_all(&mut self) -> R<Vec<u32>> {
        let keep = self.max_line;
        self.max_line = 64 * 1024 * 1024; // one number per message on ONE line: a million messages is ~8 MB
        let mut v: Vec<u32> = Vec::new();
        let r = self.run("UID SEARCH ALL", 0, |u| {
            if let Untagged::Search(s) = u {
                v.extend(s);
            }
        });
        self.max_line = keep;
        r?;
        v.sort_unstable();
        v.dedup();
        Ok(v)
    }

    /// size / flags / date for a set of UIDs (no bodies)
    pub fn uid_fetch_meta(&mut self, ranges: &str) -> R<Vec<FetchData>> {
        let mut out = Vec::new();
        self.run(&format!("UID FETCH {ranges} (UID RFC822.SIZE FLAGS INTERNALDATE)"), 0, |u| {
            if let Untagged::Fetch(f) = u {
                if f.uid.is_some() {
                    out.push(f);
                }
            }
        })?;
        Ok(out)
    }

    /// bodies, one callback per message; a body over `max_msg` arrives as Body::Skipped
    pub fn uid_fetch_bodies(&mut self, ranges: &str, max_msg: usize, on: impl FnMut(FetchData)) -> R<()> {
        let mut on = on;
        self.run(&format!("UID FETCH {ranges} (UID FLAGS INTERNALDATE BODY.PEEK[])"), max_msg, |u| {
            if let Untagged::Fetch(f) = u {
                if f.uid.is_some() {
                    on(f);
                }
            }
        })?;
        Ok(())
    }

    pub fn logout(&mut self) {
        let _ = self.run("LOGOUT", 0, |_| {});
    }
}

fn auth_error(e: ImapError) -> ImapError {
    // a refused LOGIN is an authentication problem unless the server clearly said "slow down"
    if e.kind == ErrKind::Transient || e.kind == ErrKind::Fatal {
        ImapError { kind: ErrKind::Auth, text: e.text }
    } else {
        e
    }
}

fn wipe(b: &mut Vec<u8>) {
    for x in b.iter_mut() {
        *x = 0;
    }
    b.clear();
}

fn wipe_string(s: &mut String) {
    let mut v = std::mem::take(s).into_bytes();
    wipe(&mut v);
}

/// `[UIDVALIDITY 3857529045]` inside a status text
pub fn resp_code_num(text: &str, code: &str) -> Option<u64> {
    let up = text.to_uppercase();
    let key = format!("[{code} ");
    let p = up.find(&key)?;
    let rest = &text[p + key.len()..];
    let end = rest.find(']')?;
    rest[..end].trim().parse().ok()
}

#[cfg(test)]
pub mod fake {
    //! A tiny IMAP server for the tests (loopback TCP, one connection at a time). Not compiled into the product.
    use std::collections::HashMap;
    use std::io::{BufRead, BufReader, Write};
    use std::net::{TcpListener, TcpStream};
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::{Arc, Mutex};
    use std::thread;

    pub type MsgFn = Arc<dyn Fn(&str, u32) -> Vec<u8> + Send + Sync>;

    #[derive(Clone)]
    pub struct Spec {
        pub user: String,
        pub pass: String,
        /// (raw name, attrs)
        pub folders: Vec<(String, Vec<String>)>,
        /// folder -> uids
        pub uids: HashMap<String, Vec<u32>>,
        pub validity: u32,
        pub msg: MsgFn,
        /// drop the TCP connection after this many commands on the Nth connection (conn index, command count)
        pub drop_after: Option<(usize, usize)>,
        /// answer the first UID FETCH body command with a throttle NO
        pub throttle_first_fetch: bool,
    }

    pub struct Server {
        pub port: u16,
        pub commands: Arc<Mutex<Vec<String>>>,
        pub connections: Arc<AtomicUsize>,
    }

    pub fn start(spec: Spec) -> Server {
        let l = TcpListener::bind("127.0.0.1:0").unwrap();
        let port = l.local_addr().unwrap().port();
        let commands = Arc::new(Mutex::new(Vec::new()));
        let connections = Arc::new(AtomicUsize::new(0));
        let (c2, n2) = (commands.clone(), connections.clone());
        let throttled = Arc::new(AtomicUsize::new(0));
        thread::spawn(move || {
            for st in l.incoming() {
                let st = match st {
                    Ok(s) => s,
                    Err(_) => break,
                };
                let idx = n2.fetch_add(1, Ordering::SeqCst);
                let (spec, c3, th) = (spec.clone(), c2.clone(), throttled.clone());
                thread::spawn(move || serve(st, spec, idx, c3, th));
            }
        });
        Server { port, commands, connections }
    }

    fn q(s: &str) -> String {
        s.replace('\\', "\\\\").replace('"', "\\\"")
    }

    fn ranges(s: &str) -> Vec<u32> {
        let mut v = vec![];
        for p in s.split(',') {
            if let Some((a, b)) = p.split_once(':') {
                let (a, b): (u32, u32) = (a.parse().unwrap(), if b == "*" { u32::MAX } else { b.parse().unwrap() });
                for x in a..=b.min(a + 100_000) {
                    v.push(x);
                }
            } else if let Ok(x) = p.parse() {
                v.push(x);
            }
        }
        v
    }

    fn serve(st: TcpStream, spec: Spec, idx: usize, cmds: Arc<Mutex<Vec<String>>>, throttled: Arc<AtomicUsize>) {
        let mut w = st.try_clone().unwrap();
        let mut r = BufReader::new(st);
        let _ = w.write_all(b"* OK [CAPABILITY IMAP4rev1 AUTH=PLAIN] fake ready\r\n");
        let mut open: Option<String> = None;
        let mut n = 0usize;
        let mut line = String::new();
        loop {
            line.clear();
            if r.read_line(&mut line).unwrap_or(0) == 0 {
                return;
            }
            n += 1;
            let l = line.trim_end().to_string();
            cmds.lock().unwrap().push(if l.contains(" LOGIN ") || l.contains("AUTHENTICATE") { "<login>".into() } else { l.clone() });
            if let Some((ci, cn)) = spec.drop_after {
                if ci == idx && n > cn {
                    return; // vanish mid-session
                }
            }
            let mut it = l.splitn(3, ' ');
            let tag = it.next().unwrap_or("").to_string();
            let cmd = it.next().unwrap_or("").to_uppercase();
            let rest = it.next().unwrap_or("").to_string();
            match cmd.as_str() {
                "CAPABILITY" => {
                    let _ = write!(w, "* CAPABILITY IMAP4rev1 AUTH=PLAIN\r\n{tag} OK done\r\n");
                }
                "LOGIN" => {
                    let want = format!("\"{}\" \"{}\"", q(&spec.user), q(&spec.pass));
                    if rest == want {
                        let _ = write!(w, "{tag} OK logged in\r\n");
                    } else {
                        let _ = write!(w, "{tag} NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)\r\n");
                    }
                }
                "AUTHENTICATE" => {
                    let _ = write!(w, "+ \r\n");
                    line.clear();
                    let _ = r.read_line(&mut line);
                    let ok = line.trim() == super::base64_encode(format!("\0{}\0{}", spec.user, spec.pass).as_bytes());
                    let _ = if ok { write!(w, "{tag} OK ok\r\n") } else { write!(w, "{tag} NO [AUTHENTICATIONFAILED] bad\r\n") };
                }
                "LIST" => {
                    for (name, attrs) in &spec.folders {
                        if name.contains('\u{1}') {
                            continue;
                        }
                        let _ = write!(w, "* LIST ({}) \"/\" \"{}\"\r\n", attrs.join(" "), q(name));
                    }
                    let _ = write!(w, "{tag} OK LIST done\r\n");
                }
                "EXAMINE" => {
                    let inner = rest.strip_prefix('"').and_then(|x| x.strip_suffix('"')).unwrap_or(&rest);
                    let name = inner.replace("\\\"", "\"").replace("\\\\", "\\");
                    match spec.uids.get(&name) {
                        Some(u) => {
                            open = Some(name);
                            let _ = write!(w, "* {} EXISTS\r\n* OK [UIDVALIDITY {}] ok\r\n{tag} OK [READ-ONLY] done\r\n", u.len(), spec.validity);
                        }
                        None => {
                            let _ = write!(w, "{tag} NO [NONEXISTENT] no such folder\r\n");
                        }
                    }
                }
                "UID" => {
                    let mut p = rest.splitn(2, ' ');
                    let sub = p.next().unwrap_or("").to_uppercase();
                    let args = p.next().unwrap_or("").to_string();
                    let folder = open.clone().unwrap_or_default();
                    let all = spec.uids.get(&folder).cloned().unwrap_or_default();
                    if sub == "SEARCH" {
                        let s: Vec<String> = all.iter().map(|u| u.to_string()).collect();
                        let _ = write!(w, "* SEARCH {}\r\n{tag} OK search done\r\n", s.join(" "));
                    } else if sub == "FETCH" {
                        let (set, items) = args.split_once(' ').unwrap_or((&args, ""));
                        let want_body = items.contains("BODY.PEEK[]");
                        if want_body && spec.throttle_first_fetch && throttled.fetch_add(1, Ordering::SeqCst) == 0 {
                            let _ = write!(w, "{tag} NO [LIMIT] Account exceeded command or bandwidth limits\r\n");
                            continue;
                        }
                        for u in ranges(set) {
                            if !all.contains(&u) {
                                continue;
                            }
                            let m = (spec.msg)(&folder, u);
                            if want_body {
                                let _ = write!(w, "* {u} FETCH (UID {u} FLAGS (\\Seen) INTERNALDATE \"19-Oct-2026 04:10:00 +0500\" BODY[] {{{}}}\r\n", m.len());
                                let _ = w.write_all(&m);
                                let _ = w.write_all(b")\r\n");
                            } else {
                                let _ = write!(w, "* {u} FETCH (UID {u} RFC822.SIZE {} FLAGS (\\Seen) INTERNALDATE \"19-Oct-2026 04:10:00 +0500\")\r\n", m.len());
                            }
                        }
                        let _ = write!(w, "{tag} OK fetch done\r\n");
                    } else {
                        let _ = write!(w, "{tag} BAD unknown\r\n");
                    }
                }
                "LOGOUT" => {
                    let _ = write!(w, "* BYE bye\r\n{tag} OK logout\r\n");
                    return;
                }
                _ => {
                    let _ = write!(w, "{tag} BAD unknown command\r\n");
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn io_errors_dropped_connection_is_retryable_bad_certificate_is_not() {
        use std::io::{Error, ErrorKind};
        // what rustls gives when the other side just hangs up: the text says TLS, but it is a network hiccup
        let drop = Error::new(ErrorKind::UnexpectedEof, "peer closed connection without sending TLS close_notify");
        assert_eq!(ImapError::io(drop).kind, ErrKind::Transient);
        let reset = Error::new(ErrorKind::ConnectionReset, "Connection reset by peer");
        assert_eq!(ImapError::io(reset).kind, ErrKind::Transient);
        let timeout = Error::new(ErrorKind::TimedOut, "timed out");
        assert_eq!(ImapError::io(timeout).kind, ErrKind::Transient);
        // certificate / handshake problems are reported by rustls as InvalidData and will not fix themselves
        let cert = Error::new(ErrorKind::InvalidData, "invalid peer certificate: UnknownIssuer");
        assert_eq!(ImapError::io(cert).kind, ErrKind::Tls);
        let alert = Error::new(ErrorKind::InvalidData, "received fatal alert: HandshakeFailure");
        assert_eq!(ImapError::io(alert).kind, ErrKind::Tls);
    }

    /// scripted stream: reads come from `inp`, writes are collected
    struct Mock {
        inp: Cursor<Vec<u8>>,
        out: Vec<u8>,
    }
    impl Read for Mock {
        fn read(&mut self, b: &mut [u8]) -> std::io::Result<usize> {
            self.inp.read(b)
        }
    }
    impl Write for Mock {
        fn write(&mut self, b: &[u8]) -> std::io::Result<usize> {
            self.out.extend_from_slice(b);
            Ok(b.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    fn conn(script: &str) -> Conn<Mock> {
        Conn::new(Mock { inp: Cursor::new(script.replace('\n', "\r\n").into_bytes()), out: vec![] })
    }
    fn conn_bytes(script: Vec<u8>) -> Conn<Mock> {
        Conn::new(Mock { inp: Cursor::new(script), out: vec![] })
    }

    #[test]
    fn mutf7_names() {
        assert_eq!(decode_mutf7("INBOX"), "INBOX");
        assert_eq!(decode_mutf7("Entw&APw-rfe"), "Entwürfe");
        assert_eq!(decode_mutf7("&AOk-t&AOk-"), "été");
        assert_eq!(decode_mutf7("A&-B"), "A&B");
        assert_eq!(decode_mutf7("&ZeVnLIqe-"), "日本語");
        assert_eq!(decode_mutf7("bad&!!!-x"), "bad&!!!-x");
        assert_eq!(decode_mutf7("dangling&"), "dangling&");
    }

    #[test]
    fn quoting_and_base64() {
        assert_eq!(quote("a b").unwrap(), "\"a b\"");
        assert_eq!(quote("p\"w\\").unwrap(), "\"p\\\"w\\\\\"");
        assert!(quote("caf\u{e9}").is_none());
        assert!(quote("a\r\nb").is_none());
        assert_eq!(base64_encode(b"\0user\0pass"), "AHVzZXIAcGFzcw==");
        assert_eq!(base64_encode(b"ab"), "YWI=");
        assert_eq!(base64_encode(b""), "");
    }

    #[test]
    fn greeting_capability_login_and_what_is_sent() {
        let mut c = conn("* OK [CAPABILITY IMAP4rev1] Gimap ready\n* CAPABILITY IMAP4rev1 AUTH=PLAIN X-GM-EXT-1\nA0001 OK done\nA0002 OK logged in\n");
        assert!(c.greeting().unwrap().contains("Gimap"));
        let caps = c.capability().unwrap();
        assert!(caps.contains(&"AUTH=PLAIN".to_string()));
        c.login("me@gmail.com", "ab\"cd", &caps).unwrap();
        let sent = String::from_utf8(c.into_inner().out).unwrap();
        assert!(sent.starts_with("A0001 CAPABILITY\r\n"));
        assert!(sent.contains("A0002 LOGIN \"me@gmail.com\" \"ab\\\"cd\"\r\n"));
    }

    #[test]
    fn non_ascii_password_uses_authenticate_plain() {
        let mut c = conn("+ \nA0001 OK ok\n");
        c.login("me@x.com", "pässword", &["IMAP4REV1".to_string(), "AUTH=PLAIN".to_string()]).unwrap();
        let sent = String::from_utf8(c.into_inner().out).unwrap();
        assert!(sent.starts_with("A0001 AUTHENTICATE PLAIN\r\n"));
        let line2 = sent.lines().nth(1).unwrap();
        assert_eq!(line2, base64_encode("\0me@x.com\0pässword".as_bytes()));
    }

    #[test]
    fn refused_login_is_an_auth_error_and_throttle_is_not() {
        let mut c = conn("A0001 NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)\n");
        let e = c.login("a@b.com", "x", &[]).unwrap_err();
        assert_eq!(e.kind, ErrKind::Auth);
        let mut c = conn("A0001 NO login failed\n");
        assert_eq!(c.login("a@b.com", "x", &[]).unwrap_err().kind, ErrKind::Auth);
        let mut c = conn("A0001 NO [LIMIT] Account exceeded command or bandwidth limits\n");
        assert_eq!(c.login("a@b.com", "x", &[]).unwrap_err().kind, ErrKind::Throttle);
        let mut c = conn("");
        assert!(c.login("a@b.com", "x", &["LOGINDISABLED".to_string()]).unwrap_err().kind == ErrKind::Auth);
    }

    #[test]
    fn list_with_attrs_quoted_atom_and_literal_names() {
        let mut c = conn("* LIST (\\HasNoChildren) \"/\" INBOX\n* LIST (\\HasNoChildren \\Sent) \"/\" \"[Gmail]/Sent Mail\"\n* LIST () \".\" \"Entw&APw-rfe\"\n* LIST (\\Noselect) NIL {5}\nAB CD\nA0001 OK done\n");
        let l = c.list_folders().unwrap();
        assert_eq!(l.len(), 4);
        assert_eq!(l[0].name, "INBOX");
        assert_eq!(l[1].attrs, vec!["\\HasNoChildren", "\\Sent"]);
        assert_eq!(l[1].name, "[Gmail]/Sent Mail");
        assert_eq!(l[2].name, "Entwürfe");
        assert_eq!(l[2].raw, "Entw&APw-rfe");
        assert_eq!(l[3].name, "AB CD");
        assert_eq!(l[3].delim, None);
    }

    #[test]
    fn examine_reads_uidvalidity_and_exists_and_asks_read_only() {
        let mut c = conn("* FLAGS (\\Seen)\n* 172 EXISTS\n* 1 RECENT\n* OK [UIDVALIDITY 3857529045] UIDs valid\n* OK [UIDNEXT 4392] Predicted\nA0001 OK [READ-ONLY] Select completed\n");
        assert_eq!(c.examine("INBOX").unwrap(), (3857529045, 172));
        let sent = String::from_utf8(c.into_inner().out).unwrap();
        assert_eq!(sent, "A0001 EXAMINE \"INBOX\"\r\n");
        assert!(!sent.contains("SELECT"));
        let mut c = conn("* 5 EXISTS\nA0001 OK done\n");
        assert_eq!(c.examine("X").unwrap_err().kind, ErrKind::Fatal);
    }

    #[test]
    fn search_and_meta() {
        let mut c = conn("* SEARCH 5 1 3 3\nA0001 OK done\n* 1 FETCH (UID 1 RFC822.SIZE 120 FLAGS (\\Seen \\Flagged) INTERNALDATE \" 9-Oct-2026 10:00:00 +0000\")\n* 2 FETCH (UID 3 RFC822.SIZE 99 FLAGS ())\nA0002 OK done\n");
        assert_eq!(c.uid_search_all().unwrap(), vec![1, 3, 5]);
        let m = c.uid_fetch_meta("1,3").unwrap();
        assert_eq!(m.len(), 2);
        assert_eq!(m[0].uid, Some(1));
        assert_eq!(m[0].size, Some(120));
        assert_eq!(m[0].flags, vec!["\\Seen", "\\Flagged"]);
        assert_eq!(m[0].internaldate.as_deref(), Some(" 9-Oct-2026 10:00:00 +0000"));
        assert_eq!(m[1].flags.len(), 0);
    }

    #[test]
    fn fetch_body_literal_then_closing_paren_and_oversize_is_dropped_in_sync() {
        let body = "Subject: Hi\r\n\r\nHello\r\n";
        let big = "x".repeat(5000);
        let script = format!(
            "* 1 FETCH (UID 10 FLAGS (\\Seen) BODY[] {{{}}}\r\n{})\r\n* 2 FETCH (UID 11 BODY[] {{{}}}\r\n{})\r\n* 3 FETCH (UID 12 BODY[] {{{}}}\r\n{})\r\nA0001 OK done\r\n",
            body.len(),
            body,
            big.len(),
            big,
            body.len(),
            body
        );
        let mut c = conn_bytes(script.into_bytes());
        let mut got: Vec<FetchData> = vec![];
        c.uid_fetch_bodies("10:12", 1000, |f| got.push(f)).unwrap();
        assert_eq!(got.len(), 3);
        assert_eq!(got[0].body, Some(Body::Bytes(body.as_bytes().to_vec())));
        assert_eq!(got[1].body, Some(Body::Skipped(5000)));
        assert_eq!(got[2].uid, Some(12), "the stream stayed in sync after the dropped literal");
        assert_eq!(got[2].body, Some(Body::Bytes(body.as_bytes().to_vec())));
        let sent = String::from_utf8(c.into_inner().out).unwrap();
        assert!(sent.contains("BODY.PEEK[]") && !sent.contains("STORE") && !sent.contains("EXPUNGE"));
    }

    #[test]
    fn bye_and_closed_connection_are_errors_not_hangs() {
        let mut c = conn("* BYE Too many connections\n");
        let e = c.run("NOOP", 0, |_| {}).unwrap_err();
        assert!(e.text.contains("Too many"));
        let mut c = conn("* 1 EXISTS\n");
        let e = c.run("NOOP", 0, |_| {}).unwrap_err();
        assert_eq!(e.kind, ErrKind::Transient);
    }

    #[test]
    fn protocol_garbage_is_rejected_cleanly() {
        for bad in ["* 1 FETCH (UID 1 BODY[] {abc}\n", "* 1 FETCH (UID 1 (((((((((((((((((((((((1\n", "* 1 FETCH (UID 1))\n", "* LIST (\\X \"/\" \"unterminated\n"] {
            let mut c = conn(bad);
            let r = c.run("X", 100, |_| {});
            assert!(r.is_err(), "{bad}");
        }
        // a line longer than the limit
        let mut c = conn(&format!("* OK {}\nA0001 OK\n", "z".repeat(MAX_LINE + 10)));
        assert!(c.run("NOOP", 0, |_| {}).is_err());
    }

    #[test]
    fn debug_output_has_no_secrets() {
        let c = conn("");
        assert!(!format!("{c:?}").contains("pass"));
    }

    #[test]
    fn works_against_the_loopback_fake_server() {
        use std::collections::HashMap;
        use std::net::TcpStream;
        use std::sync::Arc;
        let mut uids = HashMap::new();
        uids.insert("INBOX".to_string(), vec![1, 2, 3]);
        uids.insert("Sent \"Items\"".to_string(), vec![7]);
        let spec = fake::Spec {
            user: "me@x.com".into(),
            pass: "s3cret \"x\"".into(),
            folders: vec![("INBOX".into(), vec![]), ("Sent \"Items\"".into(), vec!["\\Sent".into()])],
            uids,
            validity: 42,
            msg: Arc::new(|f, u| format!("Subject: {f}-{u}\r\n\r\nbody {u}\r\n").into_bytes()),
            drop_after: None,
            throttle_first_fetch: false,
        };
        let srv = fake::start(spec);
        let s = TcpStream::connect(("127.0.0.1", srv.port)).unwrap();
        s.set_read_timeout(Some(std::time::Duration::from_secs(5))).unwrap();
        let mut c = Conn::new(s);
        c.greeting().unwrap();
        let caps = c.capability().unwrap();
        assert_eq!(c.login("me@x.com", "wrong", &caps).unwrap_err().kind, ErrKind::Auth);
        c.login("me@x.com", "s3cret \"x\"", &caps).unwrap();
        let l = c.list_folders().unwrap();
        assert_eq!(l.len(), 2);
        assert_eq!(c.examine("Sent \"Items\"").unwrap(), (42, 1));
        assert_eq!(c.uid_search_all().unwrap(), vec![7]);
        assert_eq!(c.examine("INBOX").unwrap(), (42, 3));
        let mut subjects = vec![];
        c.uid_fetch_bodies("1:3", 1 << 20, |f| {
            if let Some(Body::Bytes(b)) = f.body {
                subjects.push(String::from_utf8(b).unwrap().lines().next().unwrap().to_string());
            }
        })
        .unwrap();
        assert_eq!(subjects, vec!["Subject: INBOX-1", "Subject: INBOX-2", "Subject: INBOX-3"]);
        assert_eq!(c.examine("Nope").unwrap_err().kind, ErrKind::Fatal);
        c.logout();
        let cmds = srv.commands.lock().unwrap().clone();
        assert!(cmds.iter().any(|x| x.contains("EXAMINE")) && !cmds.iter().any(|x| x.to_uppercase().contains("SELECT ")));
        assert!(!cmds.iter().any(|x| x.contains("s3cret")), "password never appears in what the server logged");
    }
}
