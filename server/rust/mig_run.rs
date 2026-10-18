// mig_run.rs — the copy loop (part of mig_core). std-only and I/O-free: it talks to a `Source` (the old mailbox)
// and a `Sink` (the ANEXOMAIL database gate). The glue supplies the real ones; the tests supply fakes.
//
// Guarantees:
//   * resume: before a folder is copied the Sink says which UIDs are already done (same UIDVALIDITY) — those are
//     never fetched again;
//   * one message at a time in memory per fetch group (groups are capped by count AND bytes);
//   * throttling is respected (wait, then retry); dropped connections reconnect and continue where they stopped;
//   * every e-mail looked at becomes exactly one Item (copied / too large / failed) — nothing disappears silently;
//   * a cancel from the person (Sink says stop) ends the loop at the next batch.

use super::imap::{self, Body, Conn, FetchData, ImapError, ListItem};
use super::{backoff_ms, mime, plan_folders, remaining, sha256_hex, AppFolder, ErrKind, Skipped};
use std::collections::HashMap;
use std::io::{Read, Write};

#[derive(Debug, Clone)]
pub struct Config {
    pub max_msg_bytes: usize,
    pub group_msgs: usize,
    pub group_bytes: u64,
    pub batch_bytes: usize,
    pub meta_chunk: usize,
    pub include_trash_spam: bool,
    pub max_retries: u32,
    pub max_retries_throttle: u32,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            max_msg_bytes: 35 * 1024 * 1024,
            group_msgs: 10,
            group_bytes: 6 * 1024 * 1024,
            batch_bytes: 2 * 1024 * 1024,
            meta_chunk: 500,
            include_trash_spam: false,
            max_retries: 6,
            max_retries_throttle: 10,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Outcome {
    Copy,
    TooLarge,
    Failed,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct Flags {
    pub seen: bool,
    pub flagged: bool,
    pub answered: bool,
    pub draft: bool,
}

/// One e-mail, ready for the database gate.
#[derive(Debug, Clone)]
pub struct Item {
    pub folder: String,
    pub app_folder: AppFolder,
    pub uidvalidity: u32,
    pub uid: u32,
    pub outcome: Outcome,
    /// machine code when outcome != Copy (too_large / gone_on_server / ...)
    pub reason: Option<&'static str>,
    pub raw_sha256: String,
    pub raw_size: u64,
    /// Date header, else the server's INTERNALDATE (unix seconds)
    pub sent_at: Option<i64>,
    pub flags: Flags,
    pub parsed: Option<mime::Parsed>,
}

impl Item {
    /// rough size of what goes over the wire for this item (to keep each database call small)
    pub fn weight(&self) -> usize {
        512 + self.parsed.as_ref().map(|p| p.text.len() + p.html.as_ref().map(|h| h.len()).unwrap_or(0)).unwrap_or(0)
    }
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct Progress {
    pub folder: String,
    pub folders_total: usize,
    pub folders_done: usize,
    pub found: u64,
    pub sent: u64,
    pub bytes: u64,
    pub skipped_folders: Vec<(String, String)>,
}

pub trait Source {
    fn folders(&mut self) -> Result<Vec<ListItem>, ImapError>;
    fn open(&mut self, raw: &str) -> Result<(u32, u32), ImapError>;
    fn uids(&mut self) -> Result<Vec<u32>, ImapError>;
    fn meta(&mut self, uids: &[u32]) -> Result<Vec<FetchData>, ImapError>;
    fn bodies(&mut self, uids: &[u32], max_msg: usize, on: &mut dyn FnMut(FetchData)) -> Result<(), ImapError>;
    fn reconnect(&mut self) -> Result<(), ImapError>;
}

pub trait Sink {
    /// UIDs already done for this folder + UIDVALIDITY (resume)
    fn done(&mut self, folder: &str, uidvalidity: u32) -> Result<Vec<u32>, String>;
    /// write a batch through the gate; Ok(true) = the person asked to stop
    fn ingest(&mut self, items: &[Item]) -> Result<bool, String>;
    /// heartbeat + counters; Ok(true) = stop
    fn progress(&mut self, p: &Progress) -> Result<bool, String>;
}

pub trait Clock {
    fn sleep_ms(&mut self, ms: u64);
}

pub struct RealClock;
impl Clock for RealClock {
    fn sleep_ms(&mut self, ms: u64) {
        std::thread::sleep(std::time::Duration::from_millis(ms));
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum End {
    Completed,
    Cancelled,
    Failed(ErrKind, String),
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct Totals {
    pub found: u64,
    pub sent: u64,
    pub too_large: u64,
    pub failed: u64,
    pub bytes: u64,
    pub folders: usize,
    pub skipped_folders: Vec<Skipped>,
}

/// greedy groups by count and bytes; messages over `max_msg` are returned separately (never fetched)
pub fn plan_groups(sizes: &[(u32, u64)], max_msgs: usize, max_bytes: u64, max_msg: u64) -> (Vec<Vec<u32>>, Vec<(u32, u64)>) {
    let mut groups: Vec<Vec<u32>> = vec![];
    let mut big = vec![];
    let mut cur: Vec<u32> = vec![];
    let mut cur_b = 0u64;
    for &(u, s) in sizes {
        if s > max_msg {
            big.push((u, s));
            continue;
        }
        if !cur.is_empty() && (cur.len() >= max_msgs || cur_b + s > max_bytes) {
            groups.push(std::mem::take(&mut cur));
            cur_b = 0;
        }
        cur.push(u);
        cur_b += s;
    }
    if !cur.is_empty() {
        groups.push(cur);
    }
    (groups, big)
}

pub fn flags_of(f: &[String]) -> Flags {
    let has = |x: &str| f.iter().any(|y| y.eq_ignore_ascii_case(x));
    Flags { seen: has("\\Seen"), flagged: has("\\Flagged"), answered: has("\\Answered"), draft: has("\\Draft") }
}

enum Stop {
    Cancel,
    Fail(ErrKind, String),
}

fn retry<T>(
    src: &mut dyn Source,
    clock: &mut dyn Clock,
    cfg: &Config,
    mut f: impl FnMut(&mut dyn Source) -> Result<T, ImapError>,
) -> Result<T, ImapError> {
    let mut attempt = 0u32;
    loop {
        let e = match f(src) {
            Ok(v) => return Ok(v),
            Err(e) => e,
        };
        let limit = match e.kind {
            ErrKind::Throttle => cfg.max_retries_throttle,
            ErrKind::Transient => cfg.max_retries,
            _ => return Err(e),
        };
        if attempt >= limit {
            return Err(e);
        }
        clock.sleep_ms(backoff_ms(attempt, e.kind));
        attempt += 1;
        if e.kind == ErrKind::Transient {
            // a dead connection: log in again (the source re-opens the folder and checks UIDVALIDITY)
            let mut again = 0u32;
            loop {
                match src.reconnect() {
                    Ok(()) => break,
                    Err(r) if matches!(r.kind, ErrKind::Transient | ErrKind::Throttle) && again < cfg.max_retries => {
                        clock.sleep_ms(backoff_ms(again + attempt, r.kind));
                        again += 1;
                    }
                    Err(r) => return Err(r),
                }
            }
        }
    }
}

fn sink_retry<T>(clock: &mut dyn Clock, cfg: &Config, mut f: impl FnMut() -> Result<T, String>) -> Result<T, Stop> {
    let mut attempt = 0u32;
    loop {
        match f() {
            Ok(v) => return Ok(v),
            Err(e) => {
                // the gate being closed (cancelled / sealed / token replaced) or the time limit will not change by waiting
                if e.starts_with("gate_closed") || e.starts_with("rejected") || e.starts_with("max_runtime") {
                    return Err(Stop::Fail(ErrKind::Fatal, e));
                }
                if attempt >= cfg.max_retries {
                    return Err(Stop::Fail(ErrKind::Transient, format!("database: {e}")));
                }
                clock.sleep_ms(backoff_ms(attempt, ErrKind::Transient));
                attempt += 1;
            }
        }
    }
}

fn flush(sink: &mut dyn Sink, clock: &mut dyn Clock, cfg: &Config, items: &mut Vec<Item>, t: &mut Totals) -> Result<(), Stop> {
    // split by weight so one database call stays small
    while !items.is_empty() {
        let mut n = 0;
        let mut w = 0;
        while n < items.len() && (n == 0 || w + items[n].weight() <= cfg.batch_bytes) {
            w += items[n].weight();
            n += 1;
        }
        let part: Vec<Item> = items.drain(..n).collect();
        let stop = sink_retry(clock, cfg, || sink.ingest(&part))?;
        t.sent += part.len() as u64;
        if stop {
            return Err(Stop::Cancel);
        }
    }
    Ok(())
}

fn item_from(folder: &str, app: AppFolder, validity: u32, f: FetchData, cfg: &Config) -> Option<Item> {
    let uid = f.uid?;
    let flags = flags_of(&f.flags);
    let idate = f.internaldate.as_deref().and_then(mime::parse_date);
    let base = |outcome, reason, sha: String, size: u64, parsed: Option<mime::Parsed>, sent| Item {
        folder: folder.to_string(),
        app_folder: app,
        uidvalidity: validity,
        uid,
        outcome,
        reason,
        raw_sha256: sha,
        raw_size: size,
        sent_at: sent,
        flags: flags.clone(),
        parsed,
    };
    match f.body? {
        Body::Bytes(b) => {
            if b.len() > cfg.max_msg_bytes {
                return Some(base(Outcome::TooLarge, Some("too_large"), String::new(), b.len() as u64, None, idate));
            }
            let sha = sha256_hex(&b);
            let p = mime::parse(&b);
            let sent = p.date.or(idate);
            Some(base(Outcome::Copy, None, sha, b.len() as u64, Some(p), sent))
        }
        Body::Skipped(n) => Some(base(Outcome::TooLarge, Some("too_large"), String::new(), n, None, idate)),
    }
}

/// Copy everything. Returns how it ended and what it saw.
pub fn run(src: &mut dyn Source, sink: &mut dyn Sink, clock: &mut dyn Clock, cfg: &Config) -> (End, Totals) {
    let mut t = Totals::default();
    match run_inner(src, sink, clock, cfg, &mut t) {
        Ok(()) => (End::Completed, t),
        Err(Stop::Cancel) => (End::Cancelled, t),
        Err(Stop::Fail(k, why)) => (End::Failed(k, why), t),
    }
}

fn run_inner(src: &mut dyn Source, sink: &mut dyn Sink, clock: &mut dyn Clock, cfg: &Config, t: &mut Totals) -> Result<(), Stop> {
    let fail = |e: ImapError| Stop::Fail(e.kind, e.text);
    let listed = retry(src, clock, cfg, |s| s.folders()).map_err(fail)?;
    let raw_of: HashMap<String, String> = listed.iter().map(|l| (l.name.clone(), l.raw.clone())).collect();
    let pairs: Vec<(String, Vec<String>)> = listed.iter().map(|l| (l.name.clone(), l.attrs.clone())).collect();
    let (plan, skipped) = plan_folders(&pairs, cfg.include_trash_spam);
    t.skipped_folders = skipped.clone();
    let mut prog = Progress {
        folders_total: plan.len(),
        skipped_folders: skipped.iter().map(|s| (s.name.clone(), s.why.to_string())).collect(),
        ..Default::default()
    };

    for (fi, fp) in plan.iter().enumerate() {
        prog.folder = fp.name.clone();
        prog.folders_done = fi;
        if sink_retry(clock, cfg, || sink.progress(&prog))? {
            return Err(Stop::Cancel);
        }
        let raw = raw_of.get(&fp.name).cloned().unwrap_or_else(|| fp.name.clone());
        let (validity, _exists) = match retry(src, clock, cfg, |s| s.open(&raw)) {
            Ok(v) => v,
            Err(e) if e.kind == ErrKind::Fatal => {
                // this one folder cannot be opened: say so, carry on with the others
                prog.skipped_folders.push((fp.name.clone(), "could_not_open".into()));
                t.skipped_folders.push(Skipped { name: fp.name.clone(), why: "could_not_open" });
                continue;
            }
            Err(e) => return Err(fail(e)),
        };
        let all = retry(src, clock, cfg, |s| s.uids()).map_err(fail)?;
        let done = sink_retry(clock, cfg, || sink.done(&fp.name, validity))?;
        let todo = remaining(&all, &done);
        t.found += all.len() as u64;
        prog.found = t.found;

        for chunk in todo.chunks(cfg.meta_chunk.max(1)) {
            let metas = retry(src, clock, cfg, |s| s.meta(chunk)).map_err(fail)?;
            let mut sizes: Vec<(u32, u64)> = metas.iter().filter_map(|m| Some((m.uid?, m.size.unwrap_or(0)))).collect();
            sizes.sort_unstable();
            let meta_by: HashMap<u32, FetchData> = metas.into_iter().filter_map(|m| Some((m.uid?, m))).collect();
            let (groups, big) = plan_groups(&sizes, cfg.group_msgs, cfg.group_bytes, cfg.max_msg_bytes as u64);
            let mut items: Vec<Item> = vec![];
            for (u, s) in big {
                let m = meta_by.get(&u).cloned().unwrap_or_default();
                let mut it = item_from(&fp.name, fp.app, validity, FetchData { uid: Some(u), body: Some(Body::Skipped(s)), ..m }, cfg).unwrap();
                it.reason = Some("too_large");
                t.too_large += 1;
                items.push(it);
            }
            // UIDs the server listed but did not describe = gone between the two commands
            let described: Vec<u32> = sizes.iter().map(|x| x.0).collect();
            for &u in chunk {
                if described.binary_search(&u).is_err() {
                    items.push(gone(&fp.name, fp.app, validity, u));
                    t.failed += 1;
                }
            }
            for g in groups {
                let mut pending: Vec<u32> = g.clone();
                let mut got: Vec<Item> = vec![];
                let r = retry(src, clock, cfg, |s| {
                    let want = pending.clone();
                    let mut cb = |f: FetchData| {
                        if f.body.is_none() {
                            return;
                        }
                        if let Some(u) = f.uid {
                            if let Some(pos) = pending.iter().position(|x| *x == u) {
                                pending.remove(pos);
                                if let Some(it) = item_from(&fp.name, fp.app, validity, f, cfg) {
                                    got.push(it);
                                }
                            }
                        }
                    };
                    if want.is_empty() {
                        return Ok(());
                    }
                    s.bodies(&want, cfg.max_msg_bytes, &mut cb)
                });
                for it in &got {
                    match it.outcome {
                        Outcome::Copy => t.bytes += it.raw_size,
                        Outcome::TooLarge => t.too_large += 1,
                        Outcome::Failed => t.failed += 1,
                    }
                }
                items.extend(got);
                if let Err(e) = r {
                    flush(sink, clock, cfg, &mut items, t)?; // keep what arrived before the failure
                    return Err(fail(e));
                }
                for u in pending {
                    items.push(gone(&fp.name, fp.app, validity, u));
                    t.failed += 1;
                }
                if items.iter().map(|i| i.weight()).sum::<usize>() >= cfg.batch_bytes || items.len() >= cfg.group_msgs * 3 {
                    flush(sink, clock, cfg, &mut items, t)?;
                    prog.sent = t.sent;
                    prog.bytes = t.bytes;
                    if sink_retry(clock, cfg, || sink.progress(&prog))? {
                        return Err(Stop::Cancel);
                    }
                }
            }
            flush(sink, clock, cfg, &mut items, t)?;
        }
        t.folders += 1;
        prog.sent = t.sent;
        prog.bytes = t.bytes;
    }
    prog.folders_done = plan.len();
    prog.folder.clear();
    if sink_retry(clock, cfg, || sink.progress(&prog))? {
        return Err(Stop::Cancel);
    }
    Ok(())
}

fn gone(folder: &str, app: AppFolder, validity: u32, uid: u32) -> Item {
    Item {
        folder: folder.to_string(),
        app_folder: app,
        uidvalidity: validity,
        uid,
        outcome: Outcome::Failed,
        reason: Some("gone_on_server"),
        raw_sha256: String::new(),
        raw_size: 0,
        sent_at: None,
        flags: Flags::default(),
        parsed: None,
    }
}

/* ------------------------------------------------------------------ the IMAP source */

/// greeting + CAPABILITY + login on a fresh connection
pub fn establish<S: Read + Write>(mut c: Conn<S>, user: &str, pass: &str) -> Result<Conn<S>, ImapError> {
    c.greeting()?;
    let caps = c.capability()?;
    c.login(user, pass, &caps)?;
    Ok(c)
}

pub struct ImapSource<S: Read + Write> {
    conn: Option<Conn<S>>,
    connect: Box<dyn FnMut() -> Result<Conn<S>, ImapError> + Send>,
    user: String,
    pass: Vec<u8>,
    open: Option<(String, u32)>,
}

impl<S: Read + Write> Drop for ImapSource<S> {
    fn drop(&mut self) {
        for b in self.pass.iter_mut() {
            *b = 0;
        }
    }
}

impl<S: Read + Write> ImapSource<S> {
    /// `conn` is already logged in; `connect` gives a fresh, not-yet-greeted connection (TCP + TLS) for reconnects
    pub fn new(conn: Conn<S>, connect: Box<dyn FnMut() -> Result<Conn<S>, ImapError> + Send>, user: &str, pass: &str) -> Self {
        ImapSource { conn: Some(conn), connect, user: user.to_string(), pass: pass.as_bytes().to_vec(), open: None }
    }
    fn c(&mut self) -> Result<&mut Conn<S>, ImapError> {
        self.conn.as_mut().ok_or_else(|| ImapError::new(ErrKind::Transient, "not connected"))
    }
    pub fn logout(&mut self) {
        if let Some(c) = self.conn.as_mut() {
            c.logout();
        }
        self.conn = None;
    }
}

impl<S: Read + Write> Source for ImapSource<S> {
    fn folders(&mut self) -> Result<Vec<ListItem>, ImapError> {
        self.c()?.list_folders()
    }
    fn open(&mut self, raw: &str) -> Result<(u32, u32), ImapError> {
        let r = self.c()?.examine(raw)?;
        self.open = Some((raw.to_string(), r.0));
        Ok(r)
    }
    fn uids(&mut self) -> Result<Vec<u32>, ImapError> {
        self.c()?.uid_search_all()
    }
    fn meta(&mut self, uids: &[u32]) -> Result<Vec<FetchData>, ImapError> {
        self.c()?.uid_fetch_meta(&super::uid_ranges(uids))
    }
    fn bodies(&mut self, uids: &[u32], max_msg: usize, on: &mut dyn FnMut(FetchData)) -> Result<(), ImapError> {
        let r = super::uid_ranges(uids);
        self.c()?.uid_fetch_bodies(&r, max_msg, |f| on(f))
    }
    fn reconnect(&mut self) -> Result<(), ImapError> {
        self.conn = None;
        let fresh = (self.connect)()?;
        let pass = String::from_utf8_lossy(&self.pass).into_owned();
        let c = establish(fresh, &self.user, &pass);
        let mut pass = pass.into_bytes();
        for b in pass.iter_mut() {
            *b = 0;
        }
        self.conn = Some(c?);
        if let Some((raw, v)) = self.open.clone() {
            let (now, _) = self.c()?.examine(&raw)?;
            if now != v {
                // the server renumbered the folder: old UIDs mean nothing any more — stop rather than copy wrong mail
                return Err(ImapError::new(ErrKind::Fatal, "uidvalidity_changed"));
            }
        }
        Ok(())
    }
}

#[allow(dead_code)]
fn _uses(_: imap::Untagged) {}

#[cfg(test)]
mod tests {
    use super::super::imap::fake;
    use super::*;
    use std::net::TcpStream;
    use std::sync::Arc;

    struct VecSink {
        items: Vec<Item>,
        done: HashMap<String, Vec<u32>>,
        stop_after_batches: Option<usize>,
        batches: usize,
        progress: Vec<Progress>,
        fail_first_ingest: bool,
    }
    impl VecSink {
        fn new() -> Self {
            VecSink { items: vec![], done: HashMap::new(), stop_after_batches: None, batches: 0, progress: vec![], fail_first_ingest: false }
        }
    }
    impl Sink for VecSink {
        fn done(&mut self, folder: &str, _v: u32) -> Result<Vec<u32>, String> {
            Ok(self.done.get(folder).cloned().unwrap_or_default())
        }
        fn ingest(&mut self, items: &[Item]) -> Result<bool, String> {
            if self.fail_first_ingest {
                self.fail_first_ingest = false;
                return Err("503".into());
            }
            self.items.extend(items.iter().cloned());
            self.batches += 1;
            Ok(self.stop_after_batches.map(|n| self.batches >= n).unwrap_or(false))
        }
        fn progress(&mut self, p: &Progress) -> Result<bool, String> {
            self.progress.push(p.clone());
            Ok(false)
        }
    }
    #[derive(Default)]
    struct FakeClock {
        slept: Vec<u64>,
    }
    impl Clock for FakeClock {
        fn sleep_ms(&mut self, ms: u64) {
            self.slept.push(ms);
        }
    }

    fn msg(folder: &str, u: u32) -> Vec<u8> {
        if u == 99 {
            return vec![b'x'; 4000]; // the oversize one in tests that set a small max
        }
        format!("From: Sara <sara@acme.co.uk>\r\nTo: me@x.com\r\nSubject: {folder} #{u}\r\nMessage-ID: <m{u}.{}@acme>\r\nDate: Mon, 19 Oct 2026 04:10:00 +0500\r\n\r\nHello {u}\r\n", folder.len()).into_bytes()
    }

    fn spec(drop_after: Option<(usize, usize)>, throttle: bool) -> fake::Spec {
        let mut uids = HashMap::new();
        uids.insert("INBOX".to_string(), (1..=25).collect::<Vec<u32>>());
        uids.insert("[Gmail]/Sent Mail".to_string(), vec![3, 4]);
        uids.insert("[Gmail]/All Mail".to_string(), (1..=27).collect());
        uids.insert("[Gmail]/Trash".to_string(), vec![1]);
        fake::Spec {
            user: "me@gmail.com".into(),
            pass: "abcdefghijklmnop".into(),
            folders: vec![
                ("INBOX".into(), vec!["\\HasNoChildren".into()]),
                ("[Gmail]/Sent Mail".into(), vec!["\\Sent".into()]),
                ("[Gmail]/All Mail".into(), vec!["\\All".into()]),
                ("[Gmail]/Trash".into(), vec!["\\Trash".into()]),
                ("Gone".into(), vec![]),
            ],
            uids,
            validity: 7,
            msg: Arc::new(|f, u| msg(f, u)),
            drop_after,
            throttle_first_fetch: throttle,
        }
    }

    fn source(port: u16, pass: &str) -> Result<ImapSource<TcpStream>, ImapError> {
        let mk = move || -> Result<Conn<TcpStream>, ImapError> {
            let s = TcpStream::connect(("127.0.0.1", port)).map_err(|e| ImapError::new(ErrKind::Transient, e.to_string()))?;
            s.set_read_timeout(Some(std::time::Duration::from_secs(5))).ok();
            Ok(Conn::new(s))
        };
        let first = establish(mk()?, "me@gmail.com", pass)?;
        Ok(ImapSource::new(first, Box::new(mk), "me@gmail.com", pass))
    }

    struct ClosedGate;
    impl Sink for ClosedGate {
        fn done(&mut self, _f: &str, _v: u32) -> Result<Vec<u32>, String> {
            Ok(vec![])
        }
        fn ingest(&mut self, _i: &[Item]) -> Result<bool, String> {
            Err("gate_closed:session_locked".into())
        }
        fn progress(&mut self, _p: &Progress) -> Result<bool, String> {
            Ok(false)
        }
    }

    #[test]
    fn closed_gate_stops_at_once_without_waiting() {
        let srv = fake::start(spec(None, false));
        let mut src = source(srv.port, "abcdefghijklmnop").unwrap();
        let mut clock = FakeClock::default();
        let (end, _t) = run(&mut src, &mut ClosedGate, &mut clock, &Config::default());
        match end {
            End::Failed(ErrKind::Fatal, why) => assert!(why.starts_with("gate_closed")),
            x => panic!("{x:?}"),
        }
        assert!(clock.slept.is_empty(), "a closed gate is permanent: no retry sleeps, got {:?}", clock.slept);
    }

    #[test]
    fn groups_respect_count_bytes_and_oversize() {
        let sizes = vec![(1, 10), (2, 10), (3, 50), (4, 1000), (5, 10), (6, 10)];
        let (g, big) = plan_groups(&sizes, 2, 60, 500);
        assert_eq!(g, vec![vec![1, 2], vec![3, 5], vec![6]]);
        assert_eq!(big, vec![(4, 1000)]);
        let (g, _) = plan_groups(&[(1, 100)], 5, 10, 500);
        assert_eq!(g, vec![vec![1]], "one message bigger than a group still gets its own group");
    }

    #[test]
    fn full_copy_skips_duplicate_views_and_keeps_inbox_first() {
        let srv = fake::start(spec(None, false));
        let mut src = source(srv.port, "abcdefghijklmnop").unwrap();
        let mut sink = VecSink::new();
        let mut clock = FakeClock::default();
        let (end, t) = run(&mut src, &mut sink, &mut clock, &Config::default());
        assert_eq!(end, End::Completed);
        assert_eq!(t.found, 27);
        assert_eq!(sink.items.len(), 27, "25 inbox + 2 sent");
        assert!(sink.items.iter().take(25).all(|i| i.folder == "INBOX" && i.app_folder == AppFolder::Inbox));
        let sent: Vec<&Item> = sink.items.iter().filter(|i| i.app_folder == AppFolder::Sent).collect();
        assert_eq!(sent.len(), 2);
        let first = &sink.items[0];
        assert_eq!(first.raw_sha256, sha256_hex(&msg("INBOX", 1)));
        assert_eq!(first.parsed.as_ref().unwrap().subject.as_deref(), Some("INBOX #1"));
        assert!(first.flags.seen);
        assert!(clock.slept.is_empty());
        let cmds = srv.commands.lock().unwrap().clone();
        assert!(!cmds.iter().any(|c| c.contains("All Mail") || c.contains("Trash")), "duplicate views and trash never opened");
        assert!(cmds.iter().all(|c| !c.contains(" SELECT ") && !c.contains("STORE") && !c.contains("EXPUNGE")));
        assert!(cmds.iter().any(|c| c.contains("BODY.PEEK[]")));
    }

    #[test]
    fn resume_fetches_only_what_is_missing() {
        let srv = fake::start(spec(None, false));
        let mut src = source(srv.port, "abcdefghijklmnop").unwrap();
        let mut sink = VecSink::new();
        sink.done.insert("INBOX".into(), (1..=20).collect());
        sink.done.insert("[Gmail]/Sent Mail".into(), vec![3, 4]);
        let (end, _) = run(&mut src, &mut sink, &mut FakeClock::default(), &Config::default());
        assert_eq!(end, End::Completed);
        let uids: Vec<u32> = sink.items.iter().map(|i| i.uid).collect();
        assert_eq!(uids, vec![21, 22, 23, 24, 25]);
        let cmds = srv.commands.lock().unwrap().clone();
        assert!(cmds.iter().filter(|c| c.contains("BODY.PEEK")).all(|c| c.contains("21:25")));
    }

    #[test]
    fn wrong_password_ends_with_auth_and_copies_nothing() {
        let srv = fake::start(spec(None, false));
        let e = source(srv.port, "nope").err().unwrap();
        assert_eq!(e.kind, ErrKind::Auth);
    }

    #[test]
    fn throttle_waits_then_continues() {
        let srv = fake::start(spec(None, true));
        let mut src = source(srv.port, "abcdefghijklmnop").unwrap();
        let mut sink = VecSink::new();
        let mut clock = FakeClock::default();
        let (end, _) = run(&mut src, &mut sink, &mut clock, &Config::default());
        assert_eq!(end, End::Completed);
        assert_eq!(clock.slept, vec![15_000]);
        assert_eq!(sink.items.len(), 27);
    }

    #[test]
    fn dropped_connection_reconnects_without_duplicates() {
        // first connection vanishes after 9 commands (mid copy)
        let srv = fake::start(spec(Some((0, 9)), false));
        let mut src = source(srv.port, "abcdefghijklmnop").unwrap();
        let mut sink = VecSink::new();
        let mut clock = FakeClock::default();
        let (end, _) = run(&mut src, &mut sink, &mut clock, &Config::default());
        assert_eq!(end, End::Completed);
        let mut keys: Vec<(String, u32)> = sink.items.iter().map(|i| (i.folder.clone(), i.uid)).collect();
        let n = keys.len();
        keys.sort();
        keys.dedup();
        assert_eq!(keys.len(), n, "no e-mail delivered twice");
        assert_eq!(n, 27);
        assert!(srv.connections.load(std::sync::atomic::Ordering::SeqCst) >= 2);
        assert!(!clock.slept.is_empty());
    }

    #[test]
    fn cancel_stops_at_the_next_batch() {
        let srv = fake::start(spec(None, false));
        let mut src = source(srv.port, "abcdefghijklmnop").unwrap();
        let mut sink = VecSink::new();
        sink.stop_after_batches = Some(1);
        let cfg = Config { group_msgs: 5, ..Config::default() };
        let (end, _) = run(&mut src, &mut sink, &mut FakeClock::default(), &cfg);
        assert_eq!(end, End::Cancelled);
        assert!(sink.items.len() < 27);
    }

    #[test]
    fn database_hiccup_is_retried_not_lost() {
        let srv = fake::start(spec(None, false));
        let mut src = source(srv.port, "abcdefghijklmnop").unwrap();
        let mut sink = VecSink::new();
        sink.fail_first_ingest = true;
        let mut clock = FakeClock::default();
        let (end, _) = run(&mut src, &mut sink, &mut clock, &Config::default());
        assert_eq!(end, End::Completed);
        assert_eq!(sink.items.len(), 27);
        assert_eq!(clock.slept, vec![2_000]);
    }

    #[test]
    fn oversize_message_is_recorded_not_fetched() {
        let mut sp = spec(None, false);
        sp.uids.insert("INBOX".into(), vec![1, 99, 2]);
        let srv = fake::start(sp);
        let mut src = source(srv.port, "abcdefghijklmnop").unwrap();
        let mut sink = VecSink::new();
        let cfg = Config { max_msg_bytes: 1000, ..Config::default() };
        let (end, t) = run(&mut src, &mut sink, &mut FakeClock::default(), &cfg);
        assert_eq!(end, End::Completed);
        let big: Vec<&Item> = sink.items.iter().filter(|i| i.outcome == Outcome::TooLarge).collect();
        assert_eq!(big.len(), 1);
        assert_eq!(big[0].uid, 99);
        assert_eq!(big[0].raw_size, 4000);
        assert_eq!(t.too_large, 1);
        let cmds = srv.commands.lock().unwrap().clone();
        assert!(cmds.iter().filter(|c| c.contains("BODY.PEEK")).all(|c| !c.contains("99")));
    }

    #[test]
    fn folder_that_cannot_be_opened_is_reported_and_others_continue() {
        let mut sp = spec(None, false);
        sp.folders.push(("Projects".into(), vec![]));
        let srv = fake::start(sp); // "Projects" and "Gone" are listed but have no uids entry -> NO [NONEXISTENT]
        let mut src = source(srv.port, "abcdefghijklmnop").unwrap();
        let mut sink = VecSink::new();
        let (end, t) = run(&mut src, &mut sink, &mut FakeClock::default(), &Config::default());
        assert_eq!(end, End::Completed);
        assert!(t.skipped_folders.iter().any(|s| s.name == "Projects" && s.why == "could_not_open"));
        assert_eq!(sink.items.len(), 27);
    }

    /// Measured, not promised: run with  `<binary> --ignored --nocapture measure`
    #[test]
    #[ignore]
    fn measure_memory_and_speed() {
        let n: u32 = std::env::var("MIG_N").ok().and_then(|x| x.parse().ok()).unwrap_or(20_000);
        let kb: usize = std::env::var("MIG_KB").ok().and_then(|x| x.parse().ok()).unwrap_or(50);
        let mut uids = HashMap::new();
        uids.insert("INBOX".to_string(), (1..=n).collect::<Vec<u32>>());
        let pad = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ".repeat(kb * 1024 / 57);
        let sp = fake::Spec {
            user: "u@x.com".into(),
            pass: "p".into(),
            folders: vec![("INBOX".into(), vec![])],
            uids,
            validity: 1,
            msg: Arc::new(move |_f, u| format!("Subject: m{u}\r\nMessage-ID: <{u}@x>\r\n\r\n{pad}\r\n").into_bytes()),
            drop_after: None,
            throttle_first_fetch: false,
        };
        struct Count(u64, u64);
        impl Sink for Count {
            fn done(&mut self, _: &str, _: u32) -> Result<Vec<u32>, String> {
                Ok(vec![])
            }
            fn ingest(&mut self, i: &[Item]) -> Result<bool, String> {
                self.0 += i.len() as u64;
                self.1 += i.iter().map(|x| x.raw_size).sum::<u64>();
                Ok(false)
            }
            fn progress(&mut self, _: &Progress) -> Result<bool, String> {
                Ok(false)
            }
        }
        let rss = || {
            let s = std::fs::read_to_string("/proc/self/status").unwrap_or_default();
            let get = |k: &str| s.lines().find(|l| l.starts_with(k)).map(|l| l.split_whitespace().nth(1).unwrap_or("0").parse::<u64>().unwrap_or(0)).unwrap_or(0);
            (get("VmRSS:"), get("VmHWM:"))
        };
        let srv = fake::start(sp);
        let before = rss();
        let t0 = std::time::Instant::now();
        let mut src = source_for(srv.port);
        let mut sink = Count(0, 0);
        let (end, _) = run(&mut src, &mut sink, &mut FakeClock::default(), &Config::default());
        let el = t0.elapsed();
        let after = rss();
        println!(
            "MEASURE messages={} raw_bytes={} end={:?} secs={:.1} rss_before_kb={} rss_after_kb={} peak_kb={} (peak includes the fake server thread in the same process)",
            sink.0, sink.1, end, el.as_secs_f64(), before.0, after.0, after.1
        );
    }

    fn source_for(port: u16) -> ImapSource<TcpStream> {
        let mk = move || -> Result<Conn<TcpStream>, ImapError> {
            let s = TcpStream::connect(("127.0.0.1", port)).map_err(|e| ImapError::new(ErrKind::Transient, e.to_string()))?;
            Ok(Conn::new(s))
        };
        let first = establish(mk().unwrap(), "u@x.com", "p").unwrap();
        ImapSource::new(first, Box::new(mk), "u@x.com", "p")
    }
}
