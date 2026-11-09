//! Module `flive@1` (K6.3, founder live over WebTransport) — Rust async state machine on the Tokio LocalSet, browser WebTransport through the host ABI.
//! Talks the founder protocol of server/founder/src/wt.rs: ALPN h3, path /wt/live, first bidi stream, hello line `ANX1 <token> [<last-id>]\n`,
//! then the SAME SSE frames as /founder/v1/live/stream (snapshot | tick | events), each `data:` a signed envelope.
//! EVERY frame is verified HERE (Ed25519 envelope, pinned key, clock skew) BEFORE it is handed to the page; a frame that fails is dropped and counted, never shown.
//! Refusal = the server writes `ERR <status>\n` and closes (401/403 = wait a minute, anything else = normal backoff).
//! Transport/Host/Sink-style traits keep this code testable natively with a mock; the same code runs in wasm.

use crate::frame;
use crate::live::{Cfg, Host, Transport};
use std::cell::{Cell, RefCell};
use std::rc::Rc;

pub const KIND_SNAPSHOT: u32 = 1;
pub const KIND_TICK: u32 = 2;
pub const KIND_EVENTS: u32 = 3;
pub const SKEW_S: i64 = 120;
/// One unfinished SSE block may never grow past this (a hostile or broken server cannot make the kernel eat memory).
pub const MAX_BLOCK: usize = 1 << 20;
pub const LIVE_DETAIL: &str = "Live over WebTransport / QUIC (Rust kernel, frames verified)";
pub const FALLBACK_DETAIL: &str = "WebTransport closed";

pub trait Clock {
    /// Unix seconds (the browser clock, through the host).
    async fn now_s(&self) -> i64;
}

pub trait FSink {
    fn state(&self, webtransport: bool, detail: &str);
    /// A VERIFIED frame: `data` is exactly the signed `data` slice of the envelope.
    fn frame(&self, kind: u32, data: &[u8]);
    /// A frame that failed verification (code from ed.rs) or was malformed: counted, never drawn.
    fn dropped(&self, code: u32);
}

/// `ANX1 <token> [<last-id>]\n`. None if the token could not pass the server's own charset/length check (so a bad token never goes on the wire).
pub fn hello(token: &str, last_id: u64) -> Option<String> {
    if token.is_empty() || token.len() > 3000 || !token.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-' | b'~' | b'+' | b'/' | b'=')) {
        return None;
    }
    Some(if last_id > 0 { format!("ANX1 {token} {last_id}\n") } else { format!("ANX1 {token}\n") })
}

#[derive(Debug, PartialEq, Eq, Clone)]
pub struct Block {
    pub id: Option<String>,
    pub event: String,
    pub data: String,
}

/// SSE block splitter on BYTES (a chunk may cut a UTF-8 character in half). `\r` is dropped (the server only writes `\n`). Comment-only blocks (heartbeat) are skipped.
#[derive(Default)]
pub struct SseBuf {
    buf: Vec<u8>,
}
impl SseBuf {
    pub fn pending(&self) -> usize {
        self.buf.len()
    }
    pub fn clear(&mut self) {
        self.buf.clear();
    }
    /// Err(()) = the unfinished block is over MAX_BLOCK: the caller must drop the session.
    pub fn push(&mut self, chunk: &[u8]) -> Result<Vec<Block>, ()> {
        self.buf.extend(chunk.iter().copied().filter(|b| *b != b'\r'));
        let mut out = Vec::new();
        while let Some(i) = self.buf.windows(2).position(|w| w == b"\n\n") {
            let raw: Vec<u8> = self.buf.drain(..i + 2).collect();
            if let Some(b) = parse_block(&raw[..i]) {
                out.push(b);
            }
        }
        if self.buf.len() > MAX_BLOCK {
            return Err(());
        }
        Ok(out)
    }
}

fn parse_block(raw: &[u8]) -> Option<Block> {
    let text = std::str::from_utf8(raw).ok()?;
    let (mut id, mut event, mut any) = (None, "message".to_string(), false);
    let mut data: Vec<&str> = Vec::new();
    for line in text.split('\n') {
        if line.starts_with(':') || line.is_empty() {
            continue;
        }
        let (f, v) = match line.find(':') {
            Some(i) => (&line[..i], line[i + 1..].strip_prefix(' ').unwrap_or(&line[i + 1..])),
            None => (line, ""),
        };
        match f {
            "id" => {
                id = Some(v.to_string());
                any = true;
            }
            "event" => {
                event = v.to_string();
                any = true;
            }
            "data" => {
                data.push(v);
                any = true;
            }
            _ => {}
        }
    }
    any.then(|| Block { id, event, data: data.join("\n") })
}

/// The server's refusal line, if `head` starts with one: Some(Some(status)) = complete, Some(None) = need more bytes, None = not a refusal.
pub fn refusal(head: &[u8]) -> Option<Option<u16>> {
    const P: &[u8] = b"ERR ";
    if head.len() < P.len() {
        return if P.starts_with(head) && !head.is_empty() { Some(None) } else { None };
    }
    if !head.starts_with(P) {
        return None;
    }
    match head.iter().position(|b| *b == b'\n') {
        None => Some(None),
        Some(i) => Some(Some(std::str::from_utf8(&head[4..i]).ok().and_then(|s| s.trim().parse().ok()).unwrap_or(0))),
    }
}

pub fn kind_of(event: &str) -> Option<u32> {
    match event {
        "snapshot" => Some(KIND_SNAPSHOT),
        "tick" => Some(KIND_TICK),
        "events" => Some(KIND_EVENTS),
        _ => None,
    }
}

type Verify = dyn Fn(&[u8], i64, i64) -> Result<(usize, usize), u32>;

/// Runs until `stop`. Never panics, never returns an error. `verify` is `ed::envelope_verify` in the browser; tests inject their own key.
pub async fn run<T: Transport, H: Host + Clock, S: FSink>(cfg: Rc<RefCell<Cfg>>, mut mk: impl FnMut() -> T, host: H, sink: S, stop: Rc<Cell<bool>>, verify: Rc<Verify>) {
    let mut attempt: u32 = 0;
    let mut last_id: u64 = 0;
    while !stop.get() {
        let (url, token) = {
            let c = cfg.borrow();
            (c.url.trim_end_matches('/').to_string(), c.token.clone())
        };
        let Some(hello_line) = (if url.is_empty() { None } else { hello(&token, last_id) }) else {
            sink.state(false, "waiting for login");
            host.sleep(15_000).await;
            continue;
        };
        let mut fatal = false;
        let mut t = mk();
        'session: {
            if t.open(&url).await.is_err() || t.write(hello_line.as_bytes()).await.is_err() {
                break 'session;
            }
            let (mut head, mut head_done, mut buf, mut live_up) = (Vec::<u8>::new(), false, SseBuf::default(), false);
            while !stop.get() {
                let chunk = match t.read().await {
                    Ok(Some(c)) => c,
                    _ => break 'session,
                };
                let mut feed = chunk;
                if !head_done {
                    head.extend_from_slice(&feed);
                    match refusal(&head) {
                        Some(Some(code)) => {
                            sink.state(false, &format!("WebTransport refused: {code}"));
                            fatal = code == 401 || code == 403;
                            break 'session;
                        }
                        Some(None) => continue,
                        None => {
                            head_done = true;
                            feed = std::mem::take(&mut head);
                        }
                    }
                }
                let Ok(blocks) = buf.push(&feed) else { break 'session };
                for b in blocks {
                    let Some(kind) = kind_of(&b.event) else { continue };
                    let now = host.now_s().await;
                    match verify(b.data.as_bytes(), now, SKEW_S) {
                        Ok((s, e)) => {
                            if let Some(n) = b.id.as_deref().and_then(|x| x.parse::<u64>().ok()) {
                                last_id = last_id.max(n);
                            }
                            if !live_up {
                                live_up = true;
                                attempt = 0;
                                sink.state(true, LIVE_DETAIL);
                            }
                            sink.frame(kind, &b.data.as_bytes()[s..e]);
                        }
                        Err(code) => sink.dropped(code),
                    }
                }
            }
        }
        t.close();
        if stop.get() {
            return;
        }
        if !fatal {
            sink.state(false, FALLBACK_DETAIL);
        }
        let wait = if fatal {
            60_000
        } else {
            let w = frame::backoff_ms(attempt, host.rand());
            attempt = attempt.saturating_add(1);
            w
        };
        host.sleep(wait).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ed::tests::{envelope_with, pair};
    use crate::ed::{self, STALE};
    use ring::signature::KeyPair;
    use std::collections::VecDeque;

    #[test]
    fn hello_matches_the_server_grammar() {
        assert_eq!(hello("abc.DEF_1-2~+/=", 0).unwrap(), "ANX1 abc.DEF_1-2~+/=\n");
        assert_eq!(hello("tok", 42).unwrap(), "ANX1 tok 42\n");
        for bad in ["", "a b", "a\nb", "a\"b", "a;b", &"x".repeat(3001)] {
            assert!(hello(bad, 0).is_none(), "{bad:?} must never reach the wire");
        }
    }

    #[test]
    fn sse_blocks_split_across_chunks_crlf_and_utf8() {
        let mut b = SseBuf::default();
        assert!(b.push(b": hb\n\n").unwrap().is_empty(), "heartbeat is not a frame");
        let msg = "id: 7\nevent: tick\ndata: {\"a\":\"\u{e9}\"}\n\n".as_bytes();
        let cut = msg.iter().position(|c| *c == 0xc3).unwrap() + 1; // inside the 2-byte character
        assert!(b.push(&msg[..cut]).unwrap().is_empty());
        let got = b.push(&msg[cut..]).unwrap();
        assert_eq!(got, vec![Block { id: Some("7".into()), event: "tick".into(), data: "{\"a\":\"\u{e9}\"}".into() }]);
        let got = b.push(b"event: x\r\ndata: 1\r\ndata: 2\r\n\r\n").unwrap();
        assert_eq!(got[0].data, "1\n2", "multi-line data is joined with a newline");
        assert!(b.push(&vec![b'a'; MAX_BLOCK + 1]).is_err(), "an endless block is refused");
    }

    #[test]
    fn refusal_line_parser() {
        assert_eq!(refusal(b"ERR 401\n"), Some(Some(401)));
        assert_eq!(refusal(b"ER"), Some(None));
        assert_eq!(refusal(b"ERR 40"), Some(None));
        assert_eq!(refusal(b"event: snapshot"), None);
        assert_eq!(refusal(b"ERR x\n"), Some(Some(0)));
        assert_eq!(refusal(b""), None);
    }

    #[derive(Default)]
    struct Log {
        states: Vec<(bool, String)>,
        frames: Vec<(u32, String)>,
        dropped: Vec<u32>,
        sleeps: Vec<u64>,
        opened: Vec<String>,
        hellos: Vec<String>,
    }
    type L = Rc<RefCell<Log>>;
    struct Sk(L);
    impl FSink for Sk {
        fn state(&self, wt: bool, d: &str) {
            self.0.borrow_mut().states.push((wt, d.into()));
        }
        fn frame(&self, k: u32, d: &[u8]) {
            self.0.borrow_mut().frames.push((k, String::from_utf8_lossy(d).into()));
        }
        fn dropped(&self, c: u32) {
            self.0.borrow_mut().dropped.push(c);
        }
    }
    struct Ho(L, Rc<Cell<bool>>, usize, i64);
    impl Host for Ho {
        async fn sleep(&self, ms: u64) {
            let n = {
                let mut l = self.0.borrow_mut();
                l.sleeps.push(ms);
                l.sleeps.len()
            };
            if n >= self.2 {
                self.1.set(true);
            }
            tokio::task::yield_now().await;
        }
        fn rand(&self) -> f64 {
            0.0
        }
    }
    impl Clock for Ho {
        async fn now_s(&self) -> i64 {
            self.3
        }
    }
    struct Script {
        log: L,
        open_ok: bool,
        reads: VecDeque<Result<Option<Vec<u8>>, String>>,
    }
    impl Transport for Script {
        async fn open(&mut self, url: &str) -> Result<(), String> {
            self.log.borrow_mut().opened.push(url.into());
            if self.open_ok { Ok(()) } else { Err("refused".into()) }
        }
        async fn write(&mut self, d: &[u8]) -> Result<(), String> {
            self.log.borrow_mut().hellos.push(String::from_utf8_lossy(d).into());
            Ok(())
        }
        async fn read(&mut self) -> Result<Option<Vec<u8>>, String> {
            tokio::task::yield_now().await;
            self.reads.pop_front().unwrap_or(Ok(None))
        }
        fn close(&mut self) {}
    }
    type Sess = (bool, Vec<Result<Option<Vec<u8>>, String>>);
    fn ok(s: &str) -> Result<Option<Vec<u8>>, String> {
        Ok(Some(s.as_bytes().to_vec()))
    }
    fn drive(token: &str, sessions: Vec<Sess>, max_sleeps: usize, now: i64) -> Log {
        let kp = pair(7);
        let pk: [u8; 32] = kp.public_key().as_ref().try_into().unwrap();
        let verify: Rc<Verify> = Rc::new(move |b, n, s| ed::envelope_verify_with(b, n, s, &[("s1", pk)]));
        let log: L = Rc::default();
        let stop = Rc::new(Cell::new(false));
        let cfg = Rc::new(RefCell::new(Cfg { url: "https://f.example:4443/wt/live".into(), token: token.into() }));
        let mut q: VecDeque<_> = sessions.into();
        let lg = log.clone();
        let mk = move || {
            let (o, r) = q.pop_front().unwrap_or((false, vec![]));
            Script { log: lg.clone(), open_ok: o, reads: r.into() }
        };
        let rt = tokio::runtime::Builder::new_current_thread().build().unwrap();
        rt.block_on(async {
            tokio::task::LocalSet::new().run_until(run(cfg, mk, Ho(log.clone(), stop.clone(), max_sleeps, now), Sk(log.clone()), stop.clone(), verify)).await
        });
        Rc::try_unwrap(log).ok().unwrap().into_inner()
    }
    fn sse(kp_seed: u8, kid: &str, ts: i64, id: u64, event: &str, data: &str) -> String {
        format!("id: {id}\nevent: {event}\ndata: {}\n\n", envelope_with(&pair(kp_seed), kid, ts, data))
    }

    #[test]
    fn verified_frames_reach_the_page_with_the_exact_signed_slice() {
        let (a, b) = (sse(7, "s1", 1000, 5, "snapshot", r#"{"version":5}"#), sse(7, "s1", 1001, 6, "tick", r#"{"version":6,"changed":["mail"]}"#));
        let split = a.len() / 2;
        let l = drive("tok", vec![(true, vec![ok(&a[..split]), ok(&a[split..]), ok(&b), ok(": hb\n\n"), Ok(None)])], 1, 1002);
        assert_eq!(l.opened, vec!["https://f.example:4443/wt/live"]);
        assert_eq!(l.hellos, vec!["ANX1 tok\n"]);
        assert_eq!(l.frames, vec![(KIND_SNAPSHOT, r#"{"version":5}"#.to_string()), (KIND_TICK, r#"{"version":6,"changed":["mail"]}"#.to_string())]);
        assert_eq!(l.states[0], (true, LIVE_DETAIL.to_string()));
        assert_eq!(l.states.last().unwrap(), &(false, FALLBACK_DETAIL.to_string()));
        assert!(l.dropped.is_empty());
        assert_eq!(l.sleeps, vec![1000]);
    }

    #[test]
    fn forged_wrong_key_and_stale_frames_are_dropped_never_shown() {
        let good = sse(7, "s1", 1000, 1, "snapshot", r#"{"version":1}"#);
        let forged = sse(9, "s1", 1000, 2, "tick", r#"{"version":2}"#); // signed by another key
        let stale = sse(7, "s1", 100, 3, "tick", r#"{"version":3}"#);
        let tampered = sse(7, "s1", 1000, 4, "tick", r#"{"version":4}"#).replace(r#"{"version":4}"#, r#"{"version":9}"#);
        let l = drive("tok", vec![(true, vec![ok(&forged), ok(&stale), ok(&tampered), ok(&good), Ok(None)])], 1, 1000);
        assert_eq!(l.frames.len(), 1, "only the good frame is shown");
        assert_eq!(l.frames[0].1, r#"{"version":1}"#);
        assert_eq!(l.dropped.len(), 3);
        assert!(l.dropped.contains(&STALE));
    }

    #[test]
    fn refusal_401_waits_a_minute_and_a_500_uses_normal_backoff() {
        let l = drive("tok", vec![(true, vec![ok("ERR 401\n")])], 1, 0);
        assert_eq!(l.sleeps, vec![60_000]);
        assert!(l.states.iter().any(|(wt, d)| !*wt && d.contains("401")));
        assert!(l.frames.is_empty());
        let l = drive("tok", vec![(true, vec![ok("ER"), ok("R 503\n")])], 1, 0);
        assert_eq!(l.sleeps, vec![1000], "a split refusal line is reassembled, 503 is retried normally");
    }

    #[test]
    fn reconnect_sends_the_last_id_and_the_ladder_resets_after_a_live_frame() {
        let a = sse(7, "s1", 1000, 11, "snapshot", r#"{"version":11}"#);
        let l = drive("tok", vec![(false, vec![]), (true, vec![ok(&a), Ok(None)]), (true, vec![Ok(None)])], 3, 1000);
        assert_eq!(l.sleeps, vec![1000, 1000, 2000], "fail=1s; live frame resets, ends=1s; next fail=2s");
        assert_eq!(l.hellos, vec!["ANX1 tok\n", "ANX1 tok 11\n"], "second real session resumes from id 11");
    }

    #[test]
    fn bad_token_never_opens_a_session_and_an_endless_block_is_dropped() {
        let l = drive("bad token", vec![], 2, 0);
        assert!(l.opened.is_empty());
        assert_eq!(l.sleeps, vec![15_000, 15_000]);
        let l = drive("tok", vec![(true, vec![Ok(Some(vec![b'a'; MAX_BLOCK + 10]))])], 1, 0);
        assert!(l.frames.is_empty());
        assert_eq!(l.sleeps, vec![1000]);
    }

    #[test]
    fn unknown_events_are_ignored() {
        let a = sse(7, "s1", 1000, 1, "mystery", r#"{"x":1}"#);
        let l = drive("tok", vec![(true, vec![ok(&a), Ok(None)])], 1, 1000);
        assert!(l.frames.is_empty() && l.dropped.is_empty());
    }
}
