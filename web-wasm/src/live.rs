//! Module `live@1` — poori website ka live push (mail/calendar/crm/work/people/org) — Rust async state machine, Tokio LocalSet par,
//! WebTransport browser ka (host ABI), parity: src/lib/live-core.ts. Reconnect 1,2,4,8,16,30 s (+jitter); har reconnect/ready par resync.
//! Transport/Host/Sink traits ki wajah se yahi code native tests (mock) mein bhi chalta hai aur wasm mein bhi.

use crate::frame::{self, Frame, LineBuf};
use std::cell::{Cell, RefCell};
use std::rc::Rc;

pub trait Transport {
    /// Naya session + ek bidi stream khol do (`url` poora, `/wt/events` samet).
    async fn open(&mut self, url: &str) -> Result<(), String>;
    async fn write(&mut self, data: &[u8]) -> Result<(), String>;
    /// Ok(None) = stream band.
    async fn read(&mut self) -> Result<Option<Vec<u8>>, String>;
    fn close(&mut self);
}

pub trait Host {
    async fn sleep(&self, ms: u64);
    /// [0,1)
    fn rand(&self) -> f64;
}

pub trait Sink {
    fn state(&self, webtransport: bool, detail: &str);
    fn event(&self, topic: usize);
    /// Sab subscribed data dobara kheencho (reconnect ke baad kuch chhoot sakta tha).
    fn resync(&self);
}

#[derive(Default)]
pub struct Cfg {
    pub url: String,
    pub token: String,
}

pub const POLL_DETAIL: &str = "HTTP poll (WebTransport unavailable)";

/// Chalta rehta hai jab tak `stop` na ho. Kabhi panic/return-error nahi.
pub async fn run<T: Transport, H: Host, S: Sink>(cfg: Rc<RefCell<Cfg>>, mut mk: impl FnMut() -> T, host: H, sink: S, stop: Rc<Cell<bool>>) {
    let mut attempt: u32 = 0;
    while !stop.get() {
        let (url, token) = {
            let c = cfg.borrow();
            (c.url.trim_end_matches('/').to_string(), c.token.clone())
        };
        if url.is_empty() || token.is_empty() {
            sink.state(false, POLL_DETAIL);
            host.sleep(15_000).await; // login ya env baad mein aa sakta hai
            continue;
        }
        let mut fatal = false;
        let mut t = mk();
        'session: {
            if t.open(&format!("{url}/wt/events")).await.is_err() {
                break 'session;
            }
            if t.write(frame::hello(&token).as_bytes()).await.is_err() {
                break 'session;
            }
            let mut buf = LineBuf::default();
            let mut opened = false;
            while !stop.get() {
                let chunk = match t.read().await {
                    Ok(Some(c)) => c,
                    _ => break 'session,
                };
                for line in buf.push(&chunk) {
                    if line.trim().is_empty() {
                        continue;
                    }
                    match frame::parse_frame(&line) {
                        Frame::Ready => {
                            opened = true;
                            attempt = 0;
                            sink.state(true, "Live over WebTransport / QUIC (Rust engine)");
                            sink.resync();
                        }
                        Frame::Event(i) => sink.event(i),
                        Frame::Error(code) => {
                            sink.state(false, &format!("HTTP poll (live push closed: {code})"));
                            fatal = frame::is_auth_error(&code);
                            buf.clear();
                            break 'session;
                        }
                        Frame::Ping | Frame::Ignore => {}
                    }
                }
                if !opened && buf.pending() > 65_536 {
                    break 'session;
                }
            }
        }
        t.close();
        if stop.get() {
            return;
        }
        sink.state(false, POLL_DETAIL);
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
    use std::collections::VecDeque;

    #[derive(Default)]
    struct Log {
        states: Vec<(bool, String)>,
        events: Vec<usize>,
        resyncs: u32,
        sleeps: Vec<u64>,
        opened: Vec<String>,
        hellos: Vec<String>,
    }
    type L = Rc<RefCell<Log>>;

    struct Sk(L);
    impl Sink for Sk {
        fn state(&self, wt: bool, d: &str) {
            self.0.borrow_mut().states.push((wt, d.to_string()));
        }
        fn event(&self, t: usize) {
            self.0.borrow_mut().events.push(t);
        }
        fn resync(&self) {
            self.0.borrow_mut().resyncs += 1;
        }
    }
    struct Ho(L, Rc<Cell<bool>>, usize);
    impl Host for Ho {
        async fn sleep(&self, ms: u64) {
            let n = {
                let mut l = self.0.borrow_mut();
                l.sleeps.push(ms);
                l.sleeps.len()
            };
            if n >= self.2 {
                self.1.set(true); // test ko rokne ke liye
            }
            tokio::task::yield_now().await;
        }
        fn rand(&self) -> f64 {
            0.0
        }
    }
    /// Har session ek script: open result, phir reads (Ok(Some)/Ok(None)/Err).
    struct Script {
        log: L,
        open_ok: bool,
        reads: VecDeque<Result<Option<Vec<u8>>, String>>,
    }
    impl Transport for Script {
        async fn open(&mut self, url: &str) -> Result<(), String> {
            self.log.borrow_mut().opened.push(url.to_string());
            if self.open_ok { Ok(()) } else { Err("refused".into()) }
        }
        async fn write(&mut self, d: &[u8]) -> Result<(), String> {
            self.log.borrow_mut().hellos.push(String::from_utf8_lossy(d).into_owned());
            Ok(())
        }
        async fn read(&mut self) -> Result<Option<Vec<u8>>, String> {
            tokio::task::yield_now().await;
            self.reads.pop_front().unwrap_or(Ok(None))
        }
        fn close(&mut self) {}
    }

    fn drive(url: &str, token: &str, sessions: Vec<(bool, Vec<Result<Option<Vec<u8>>, String>>)>, stop_after_sleeps: usize) -> Log {
        let log: L = Rc::default();
        let stop = Rc::new(Cell::new(false));
        let cfg = Rc::new(RefCell::new(Cfg { url: url.into(), token: token.into() }));
        let mut q: VecDeque<_> = sessions.into();
        let lg = log.clone();
        let mk = move || {
            let (ok, reads) = q.pop_front().unwrap_or((false, vec![]));
            Script { log: lg.clone(), open_ok: ok, reads: reads.into() }
        };
        let rt = tokio::runtime::Builder::new_current_thread().build().unwrap();
        rt.block_on(async {
            tokio::task::LocalSet::new()
                .run_until(run(cfg, mk, Ho(log.clone(), stop.clone(), stop_after_sleeps), Sk(log.clone()), stop.clone()))
                .await
        });
        Rc::try_unwrap(log).ok().unwrap().into_inner()
    }
    fn ok(s: &str) -> Result<Option<Vec<u8>>, String> {
        Ok(Some(s.as_bytes().to_vec()))
    }

    #[test]
    fn ready_events_and_resync() {
        let l = drive(
            "https://x.example/",
            "tok",
            vec![(true, vec![ok("{\"type\":\"ready\"}\n{\"type\":\"event\",\"topic\":\"crm\"}\n"), ok("{\"type\":\"event\",\"to"), ok("pic\":\"org\"}\n"), Ok(None)])],
            1,
        );
        assert_eq!(l.opened, vec!["https://x.example/wt/events"]);
        assert!(l.hellos[0].contains("\"token\":\"tok\"") && l.hellos[0].contains("\"mode\":\"events\""));
        assert_eq!(l.events, vec![2, 5], "crm then org; the split frame is reassembled");
        assert_eq!(l.resyncs, 1);
        assert_eq!(l.states[0], (true, "Live over WebTransport / QUIC (Rust engine)".to_string()));
        assert_eq!(l.states.last().unwrap(), &(false, POLL_DETAIL.to_string()), "after the stream ends we are honest: poll");
        assert_eq!(l.sleeps, vec![1000], "first reconnect after 1 s");
    }

    #[test]
    fn backoff_grows_and_resets_after_ready() {
        let l = drive(
            "https://x",
            "t",
            vec![
                (false, vec![]),
                (false, vec![]),
                (false, vec![]),
                (true, vec![ok("{\"type\":\"ready\"}\n"), Ok(None)]),
                (false, vec![]),
            ],
            5,
        );
        assert_eq!(l.sleeps, vec![1000, 2000, 4000, 1000, 2000], "ready resets the ladder");
        assert_eq!(l.resyncs, 1);
    }

    #[test]
    fn auth_error_waits_a_minute_and_says_so() {
        let l = drive("https://x", "t", vec![(true, vec![ok("{\"type\":\"error\",\"code\":\"unauthorized\"}\n")])], 1);
        assert_eq!(l.sleeps, vec![60_000]);
        assert!(l.states.iter().any(|(wt, d)| !*wt && d.contains("unauthorized")));
        assert!(l.events.is_empty());
    }

    #[test]
    fn non_auth_error_uses_normal_backoff() {
        let l = drive("https://x", "t", vec![(true, vec![ok("{\"type\":\"error\",\"code\":\"db_error\"}\n")])], 1);
        assert_eq!(l.sleeps, vec![1000]);
    }

    #[test]
    fn no_url_or_token_polls_and_retries_in_15s() {
        let l = drive("", "t", vec![], 2);
        assert_eq!(l.sleeps, vec![15_000, 15_000]);
        assert!(l.opened.is_empty());
        let l = drive("https://x", "", vec![], 1);
        assert!(l.opened.is_empty());
        assert_eq!(l.states[0], (false, POLL_DETAIL.to_string()));
    }

    #[test]
    fn a_server_that_never_says_ready_is_dropped_after_64k() {
        let big = Ok(Some(vec![b'a'; 70_000]));
        let l = drive("https://x", "t", vec![(true, vec![big])], 1);
        assert!(l.events.is_empty() && l.resyncs == 0);
        assert_eq!(l.sleeps, vec![1000]);
    }

    #[test]
    fn read_error_reconnects_and_ping_garbage_are_ignored() {
        let l = drive(
            "https://x",
            "t",
            vec![(true, vec![ok("{\"type\":\"ready\"}\n{\"type\":\"ping\"}\ngarbage\n\n{\"type\":\"event\",\"topic\":\"mail\"}\n"), Err("reset".into())])],
            1,
        );
        assert_eq!(l.events, vec![0]);
        assert_eq!(l.sleeps, vec![1000]);
    }
}
