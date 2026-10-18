// ============================================================================
// mig_glue.rs — the I/O half of "copy my old mailbox into ANEXOMAIL" (migration worker, Rust-first, PRIMARY :3200).
//
// Procedures (all signed-in; the browser is never trusted for the organisation or the mailbox):
//   migration.providers   the list of providers + one honest sentence each (no secrets)
//   migration.start       mailbox + provider + login + App Password  -> opens the walled garden, starts the worker
//   migration.resume      session + App Password again              -> new token, same session, continues where it stopped
//   migration.status      one copy's progress          migration.list   the organisation's copies (newest first)
//   migration.cancel      stop a copy                  migration.verify  re-check the evidence chain (Rust AND database)
//
// How it is kept safe (core: mig_core.rs + mig_imap/mig_mime/mig_run.rs, unit-tested; database: sql/E35):
//   * the old mailbox is only ever READ (IMAP EXAMINE + BODY.PEEK — nothing is marked read, moved or deleted there);
//   * the App Password lives in this process only while the copy runs and is never written anywhere (no database, no
//     log, no file). A restart of this service ends running copies; "Resume" asks for the password again;
//   * the ONLY way these e-mails get into ANEXOMAIL is the database function migration_ingest, which needs a one-use
//     random token that the database issues for this one mailbox. The token never leaves this process (the browser gets
//     the session id only). When the copy ends the database seals the session and locks it for good;
//   * TLS only, port 993 only, certificates checked against the public roots; the host name is resolved here and only
//     PUBLIC addresses are used (no internal network, no cloud metadata address, no DNS-rebinding trick);
//   * at most MIG_MAX_WORKERS copies run at once (default 3) so one tenant cannot starve the engine.
//
// Child module of the crate root (main.rs): it uses `crate::sb_rpc`, `crate::sb_select`, `crate::auth_user`,
// `crate::ok`, `crate::err`, `crate::env_var`. New crates (approved by the founder, G30): rustls 0.23 (ring) + webpki-roots 0.26.
// ============================================================================

use crate::mig_core as mc;
use axum::{http::StatusCode, response::IntoResponse};
use mc::imap::{Conn, ImapError};
use mc::run as mrun;
use mc::ErrKind;
use serde_json::{json, Value};
use std::net::{SocketAddr, TcpStream, ToSocketAddrs};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, OnceLock};
use std::time::{Duration, Instant};

type Resp = axum::response::Response;
type Tls = rustls::StreamOwned<rustls::ClientConnection, TcpStream>;

/// a copy that runs longer than this stops by itself (it can be resumed): a stuck or trickling server cannot hold a slot forever
const MAX_RUN_SECS: u64 = 8 * 3600;
/// how long "start" waits for the old provider to accept the login before it says "still connecting"
const LOGIN_WAIT_SECS: u64 = 45;

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "migration.providers"
            | "migration.start"
            | "migration.resume"
            | "migration.status"
            | "migration.list"
            | "migration.cancel"
            | "migration.verify"
    )
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn fail_code(status: StatusCode, code: &str) -> Resp {
    fail(status, code, mc::user_message(code))
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn flag(v: &Value, k: &str) -> bool {
    v.get(k).and_then(|x| x.as_bool()).unwrap_or(false)
}

fn num(v: &Value, k: &str) -> i64 {
    v.get(k).and_then(|x| x.as_i64()).unwrap_or(0)
}

fn is_uuid(s: &str) -> bool {
    s.len() == 36
        && s.char_indices().all(|(i, c)| match i {
            8 | 13 | 18 | 23 => c == '-',
            _ => c.is_ascii_hexdigit(),
        })
}

/// best-effort clearing of a secret we own (the optimiser is told the buffer is still used)
fn wipe(s: &mut String) {
    let mut b = std::mem::take(s).into_bytes();
    for x in b.iter_mut() {
        *x = 0;
    }
    std::hint::black_box(&b);
}

/* ------------------------------------------------------------- who is asking */

struct Ctx {
    id: String,
    org_id: String,
}

/// Who is asking and for which organisation. Revoked memberships do not count (the database re-checks the mailbox too).
async fn ctx(token: &str, input: &Value) -> Result<Ctx, Resp> {
    let id = match crate::auth_user(token).await {
        Some((id, _email)) if is_uuid(&id) => id,
        _ => return Err(fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid")),
    };
    let mine = crate::sb_select(&format!("org_members?select=org_id,status&user_id=eq.{id}"))
        .await
        .map_err(|_| fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Could not read your workspace"))?;
    let live: Vec<String> = mine
        .as_array()
        .map(|a| {
            a.iter()
                .filter(|m| st(m, "status") != "revoked")
                .map(|m| st(m, "org_id"))
                .filter(|o| is_uuid(o))
                .collect()
        })
        .unwrap_or_default();
    if live.is_empty() {
        return Err(fail(StatusCode::CONFLICT, "no_workspace", "no_workspace"));
    }
    let want = st(input, "org_id");
    let org_id = live.iter().find(|o| !want.is_empty() && **o == want).unwrap_or(&live[0]).clone();
    Ok(Ctx { id, org_id })
}

async fn rpc(func: &str, body: Value) -> Result<Value, Resp> {
    crate::sb_rpc(func, body).await.map_err(|e| {
        // PostgREST says the function does not exist => the E35 SQL has not been applied on this database yet
        if e.contains("PGRST202") || e.contains("Could not find the function") {
            fail(StatusCode::NOT_IMPLEMENTED, "migration_sql_missing", "Mail copy is not switched on for this workspace yet.")
        } else {
            fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Could not reach the database")
        }
    })
}

/// A database function answered {ok:false,error:..}: turn it into an HTTP answer (never 401/502/503 — the app would
/// read those as "sign in again" or "use the fallback").
fn sql_fail(v: &Value) -> Resp {
    let e = st(v, "error");
    let (status, code) = match e.as_str() {
        "not_found" | "mailbox_not_found" => (StatusCode::NOT_FOUND, e.as_str()),
        "not_allowed" => (StatusCode::FORBIDDEN, "not_allowed"),
        "too_many_sessions" => (StatusCode::TOO_MANY_REQUESTS, "too_many_sessions"),
        "session_active" | "still_running" | "session_locked" => (StatusCode::CONFLICT, e.as_str()),
        "bad_input" => (StatusCode::BAD_REQUEST, "bad_input"),
        _ => (StatusCode::INTERNAL_SERVER_ERROR, "worker_error"),
    };
    fail_code(status, code)
}

/* ------------------------------------------------------------- dispatch */

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let c = match ctx(token, input).await {
        Ok(c) => c,
        Err(r) => return r,
    };
    match proc {
        "migration.providers" => providers(),
        "migration.start" => start(&c, input).await,
        "migration.resume" => resume(&c, input).await,
        "migration.status" => status(&c, input).await,
        "migration.list" => list(&c).await,
        "migration.cancel" => cancel(&c, input).await,
        "migration.verify" => verify(&c, input).await,
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust", proc),
    }
}

fn providers() -> Resp {
    let list: Vec<Value> = mc::PRESETS
        .iter()
        .map(|p| json!({ "id": p.id, "label": p.label, "host": p.host, "port": p.port, "note": p.note, "custom": p.host.is_empty() }))
        .collect();
    crate::ok(json!({ "providers": list })).into_response()
}

async fn status(c: &Ctx, input: &Value) -> Resp {
    let sid = st(input, "session_id");
    if !is_uuid(&sid) {
        return fail_code(StatusCode::BAD_REQUEST, "not_found");
    }
    match rpc("migration_get", json!({ "_user": c.id, "_session": sid })).await {
        Ok(v) if flag(&v, "ok") => crate::ok(json!({ "session": v.get("session").cloned().unwrap_or(Value::Null) })).into_response(),
        Ok(v) => sql_fail(&v),
        Err(r) => r,
    }
}

async fn list(c: &Ctx) -> Resp {
    match rpc("migration_list", json!({ "_user": c.id, "_org": c.org_id })).await {
        Ok(v) if flag(&v, "ok") => crate::ok(json!({ "sessions": v.get("sessions").cloned().unwrap_or(Value::Null), "max_workers": max_workers() })).into_response(),
        Ok(v) => sql_fail(&v),
        Err(r) => r,
    }
}

async fn cancel(c: &Ctx, input: &Value) -> Resp {
    let sid = st(input, "session_id");
    if !is_uuid(&sid) {
        return fail_code(StatusCode::BAD_REQUEST, "not_found");
    }
    match rpc("migration_cancel", json!({ "_user": c.id, "_session": sid })).await {
        Ok(v) if flag(&v, "ok") => crate::ok(json!({
            "requested": flag(&v, "requested"),
            "already": flag(&v, "already"),
            "status": st(&v, "status"),
            "seal_hash": st(&v, "seal_hash"),
        }))
        .into_response(),
        Ok(v) => sql_fail(&v),
        Err(r) => r,
    }
}

/* ------------------------------------------------------------- worker slots */

static ACTIVE: AtomicUsize = AtomicUsize::new(0);

fn max_workers() -> usize {
    crate::env_var("MIG_MAX_WORKERS").trim().parse::<usize>().unwrap_or(3).clamp(1, 16)
}

/// One running copy. Released when dropped, also if the worker panics.
struct Slot;

impl Slot {
    fn acquire() -> Option<Slot> {
        let before = ACTIVE.fetch_add(1, Ordering::SeqCst);
        if before >= max_workers() {
            ACTIVE.fetch_sub(1, Ordering::SeqCst);
            None
        } else {
            Some(Slot)
        }
    }
}

impl Drop for Slot {
    fn drop(&mut self) {
        ACTIVE.fetch_sub(1, Ordering::SeqCst);
    }
}

/* ------------------------------------------------------------- start / resume */

struct Job {
    rt: tokio::runtime::Handle,
    _slot: Slot,
    session_id: String,
    token: String,
    host: String,
    port: u16,
    login: String,
    password: String,
    include_trash_spam: bool,
}

impl Drop for Job {
    fn drop(&mut self) {
        wipe(&mut self.password);
    }
}

fn status_of(code: &str) -> StatusCode {
    match code {
        "busy" | "provider_throttled" | "too_many_sessions" => StatusCode::TOO_MANY_REQUESTS,
        "worker_error" => StatusCode::INTERNAL_SERVER_ERROR,
        _ => StatusCode::BAD_REQUEST, // never 401: the app would sign the person out
    }
}

/// The error text of an IMAP/TLS/DNS problem as one of our stable codes.
fn code_of(e: &ImapError) -> &'static str {
    match e.text.as_str() {
        "host_not_found" => "host_not_found",
        "host_blocked" => "host_blocked",
        _ => mc::error_code(e.kind),
    }
}

async fn start(c: &Ctx, input: &Value) -> Resp {
    let mailbox = st(input, "mailbox").trim().to_lowercase();
    if mailbox.is_empty() || mailbox.len() > 320 || !mailbox.contains('@') {
        return fail_code(StatusCode::BAD_REQUEST, "mailbox_not_found");
    }
    let mut raw_pw = st(input, "password");
    let checked = mc::check_login_input(&st(input, "provider"), &st(input, "host"), &st(input, "login"), &raw_pw);
    wipe(&mut raw_pw);
    let t = match checked {
        Ok(t) => t,
        Err(code) => return fail_code(StatusCode::BAD_REQUEST, code),
    };
    // refuse a blocked / unknown host BEFORE a session row is made (a refused host must not use up the daily session limit)
    if let Err(code) = resolve_check(t.host.clone()).await {
        return fail_code(StatusCode::BAD_REQUEST, code);
    }
    let slot = match Slot::acquire() {
        Some(s) => s,
        None => return fail_code(StatusCode::TOO_MANY_REQUESTS, "busy"),
    };
    let include = flag(input, "include_trash_spam");
    let made = match rpc(
        "migration_session_create",
        json!({
            "_user": c.id, "_org": c.org_id, "_mailbox": mailbox, "_provider": t.provider,
            "_host": t.host, "_login": t.login, "_include_trash_spam": include
        }),
    )
    .await
    {
        Ok(v) => v,
        Err(r) => return r,
    };
    if !flag(&made, "ok") {
        return sql_fail(&made);
    }
    let job = Job {
        rt: tokio::runtime::Handle::current(),
        _slot: slot,
        session_id: st(&made, "session_id"),
        token: st(&made, "token"),
        host: t.host,
        port: t.port,
        login: t.login,
        password: t.password,
        include_trash_spam: include,
    };
    launch(job).await
}

async fn resume(c: &Ctx, input: &Value) -> Resp {
    let sid = st(input, "session_id");
    if !is_uuid(&sid) {
        return fail_code(StatusCode::BAD_REQUEST, "not_found");
    }
    // 1) read the session first (this also checks the person may use it): reopening replaces the token, so nothing
    //    may be wrong with the input by the time that happens
    let got = match rpc("migration_get", json!({ "_user": c.id, "_session": sid })).await {
        Ok(v) if flag(&v, "ok") => v,
        Ok(v) => return sql_fail(&v),
        Err(r) => return r,
    };
    let session = got.get("session").cloned().unwrap_or(Value::Null);
    if flag(&session, "locked") {
        return fail_code(StatusCode::CONFLICT, "session_locked");
    }
    // the provider rules (Google's spaces) and the host come from the session row, never from the browser
    let mut raw_pw = st(input, "password");
    let checked = mc::check_login_input(&st(&session, "provider"), &st(&got, "source_host"), &st(&session, "source_login"), &raw_pw);
    wipe(&mut raw_pw);
    let t = match checked {
        Ok(t) => t,
        Err(code) => return fail_code(StatusCode::BAD_REQUEST, code),
    };
    if let Err(code) = resolve_check(t.host.clone()).await {
        return fail_code(StatusCode::BAD_REQUEST, code);
    }
    // 2) room to run? (before the token is replaced)
    let slot = match Slot::acquire() {
        Some(s) => s,
        None => return fail_code(StatusCode::TOO_MANY_REQUESTS, "busy"),
    };
    // 3) new token for the same session (the old one dies); refuses while a worker is still alive
    let re = match rpc("migration_reopen", json!({ "_user": c.id, "_session": sid })).await {
        Ok(v) => v,
        Err(r) => return r,
    };
    if !flag(&re, "ok") {
        return sql_fail(&re);
    }
    let job = Job {
        rt: tokio::runtime::Handle::current(),
        _slot: slot,
        session_id: sid,
        token: st(&re, "token"),
        host: t.host,
        port: t.port,
        login: t.login,
        password: t.password,
        include_trash_spam: flag(&re, "include_trash_spam"),
    };
    launch(job).await
}

/// Hand the job to a blocking thread and wait (a short while) for "the old provider accepted the login".
async fn launch(job: Job) -> Resp {
    let sid = job.session_id.clone();
    let (tx, rx) = tokio::sync::oneshot::channel::<Result<(), &'static str>>();
    let _ = tokio::task::spawn_blocking(move || run_job(job, tx));
    match tokio::time::timeout(Duration::from_secs(LOGIN_WAIT_SECS), rx).await {
        Ok(Ok(Ok(()))) => crate::ok(json!({ "session_id": sid, "status": "verified" })).into_response(),
        Ok(Ok(Err(code))) => fail_code(status_of(code), code),
        Ok(Err(_)) => fail_code(StatusCode::INTERNAL_SERVER_ERROR, "worker_error"),
        // slow provider: the copy carries on in the background; the page polls migration.status
        Err(_) => crate::ok(json!({ "session_id": sid, "status": "created", "connecting": true })).into_response(),
    }
}

/* ------------------------------------------------------------- network: DNS guard + TLS */

/// Resolves the host and keeps ONLY public addresses (IPv4 first). Called again for every (re)connect.
fn resolve_public(host: &str, port: u16) -> Result<Vec<SocketAddr>, ImapError> {
    let all: Vec<SocketAddr> = (host, port)
        .to_socket_addrs()
        .map_err(|_| ImapError::new(ErrKind::Fatal, "host_not_found"))?
        .collect();
    if all.is_empty() {
        return Err(ImapError::new(ErrKind::Fatal, "host_not_found"));
    }
    let mut ok: Vec<SocketAddr> = all.into_iter().filter(|a| mc::is_public_ip(&a.ip())).collect();
    if ok.is_empty() {
        return Err(ImapError::new(ErrKind::Fatal, "host_blocked"));
    }
    ok.sort_by_key(|a| a.is_ipv6());
    Ok(ok)
}

/// DNS can hang: never on the async threads, never for more than 10 seconds.
async fn resolve_check(host: String) -> Result<(), &'static str> {
    let job = tokio::task::spawn_blocking(move || resolve_public(&host, mc::ALLOWED_PORT).map(|_| ()));
    match tokio::time::timeout(Duration::from_secs(10), job).await {
        Ok(Ok(Ok(()))) => Ok(()),
        Ok(Ok(Err(e))) => Err(code_of(&e)),
        _ => Err("host_not_found"),
    }
}

fn tls_config() -> Result<Arc<rustls::ClientConfig>, String> {
    static CFG: OnceLock<Result<Arc<rustls::ClientConfig>, String>> = OnceLock::new();
    CFG.get_or_init(|| {
        let mut roots = rustls::RootCertStore::empty();
        roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
        let provider = Arc::new(rustls::crypto::ring::default_provider());
        let cfg = rustls::ClientConfig::builder_with_provider(provider)
            .with_safe_default_protocol_versions()
            .map_err(|e| e.to_string())?
            .with_root_certificates(roots)
            .with_no_client_auth();
        Ok(Arc::new(cfg))
    })
    .clone()
}

/// A fresh, not-yet-greeted IMAP connection over TLS to a PUBLIC address of `host`. The certificate must be valid for `host`.
fn dial(host: &str, port: u16) -> Result<Conn<Tls>, ImapError> {
    let addrs = resolve_public(host, port)?;
    let cfg = tls_config().map_err(|e| ImapError::new(ErrKind::Fatal, format!("tls config: {e}")))?;
    let name = rustls::pki_types::ServerName::try_from(host.to_string()).map_err(|_| ImapError::new(ErrKind::Fatal, "host_invalid"))?;
    let mut last: Option<std::io::Error> = None;
    for a in addrs.iter().take(4) {
        match TcpStream::connect_timeout(a, Duration::from_secs(15)) {
            Ok(tcp) => {
                let _ = tcp.set_read_timeout(Some(Duration::from_secs(90)));
                let _ = tcp.set_write_timeout(Some(Duration::from_secs(30)));
                let _ = tcp.set_nodelay(true);
                let conn = rustls::ClientConnection::new(cfg.clone(), name.clone())
                    .map_err(|e| ImapError::new(ErrKind::Tls, format!("tls: {e}")))?;
                return Ok(Conn::new(rustls::StreamOwned::new(conn, tcp)));
            }
            Err(e) => last = Some(e),
        }
    }
    Err(match last {
        Some(e) => ImapError::new(ErrKind::Transient, format!("connect: {e}")),
        None => ImapError::new(ErrKind::Fatal, "host_not_found"),
    })
}

/* ------------------------------------------------------------- the gate (database) */

/// Everything the worker writes goes through here: one database function per call, each needing the session token.
struct DbSink {
    rt: tokio::runtime::Handle,
    token: String,
    started: Instant,
}

/// {ok:true,..} passes; anything else becomes a short error word the copy loop understands.
fn gate(v: Value) -> Result<Value, String> {
    if flag(&v, "ok") {
        return Ok(v);
    }
    let e = st(&v, "error");
    Err(if e == "gate_closed" { format!("gate_closed:{}", st(&v, "why")) } else { format!("rejected:{e}") })
}

impl DbSink {
    fn call(&self, func: &str, body: Value) -> Result<Value, String> {
        if self.started.elapsed() > Duration::from_secs(MAX_RUN_SECS) {
            return Err("max_runtime".to_string());
        }
        self.rt.block_on(crate::sb_rpc(func, body))
    }
}

impl mrun::Sink for DbSink {
    fn done(&mut self, folder: &str, uidvalidity: u32) -> Result<Vec<u32>, String> {
        let v = gate(self.call("migration_done", json!({ "_token": self.token, "_folder": folder, "_uidv": uidvalidity }))?)?;
        mc::parse_ranges(&st(&v, "ranges"))
    }

    fn ingest(&mut self, items: &[mrun::Item]) -> Result<bool, String> {
        let arr: Vec<Value> = items.iter().map(item_json).collect();
        let v = gate(self.call("migration_ingest", json!({ "_token": self.token, "_items": arr }))?)?;
        Ok(flag(&v, "stop"))
    }

    fn progress(&mut self, p: &mrun::Progress) -> Result<bool, String> {
        let skipped: Vec<Value> = p.skipped_folders.iter().map(|(n, w)| json!({ "name": n, "why": w })).collect();
        let body = json!({
            "_token": self.token,
            "_p": {
                "folders_total": p.folders_total, "folders_done": p.folders_done, "folder": p.folder,
                "found": p.found, "skipped_folders": skipped
            }
        });
        let v = gate(self.call("migration_progress", body)?)?;
        Ok(flag(&v, "stop"))
    }
}

/// One e-mail as the database function migration_ingest expects it (field names are pinned by the E35 self-test).
pub(crate) fn item_json(it: &mrun::Item) -> Value {
    match (it.outcome, it.parsed.as_ref()) {
        (mrun::Outcome::Copy, Some(p)) => {
            let from_name = p.from.as_ref().and_then(|a| a.name.clone());
            let from_address = p.from.as_ref().map(|a| a.address.clone()).unwrap_or_default();
            let atts: Vec<Value> = p
                .attachments
                .iter()
                .map(|a| json!({ "filename": a.filename, "mime": a.mime, "size": a.size }))
                .collect();
            json!({
                "outcome": "copy",
                "folder": it.folder, "uidvalidity": it.uidvalidity, "uid": it.uid,
                "raw_sha256": it.raw_sha256, "raw_size": it.raw_size,
                "message_id": p.message_id, "in_reply_to": p.in_reply_to, "references": p.references,
                "subject": p.subject, "from_name": from_name, "from_address": from_address,
                "to": p.to, "cc": p.cc, "body_text": p.text, "body_html": p.html,
                "sent_at": it.sent_at.map(mc::mime::iso_utc),
                "app_folder": it.app_folder.as_str(), "direction": it.app_folder.direction(),
                "seen": it.flags.seen, "flagged": it.flags.flagged,
                "attachments": atts
            })
        }
        (mrun::Outcome::TooLarge, _) => json!({
            "outcome": "too_large", "folder": it.folder, "uidvalidity": it.uidvalidity, "uid": it.uid,
            "raw_size": it.raw_size, "reason": it.reason.unwrap_or("too_large")
        }),
        // a Copy without a parsed message cannot happen; if it ever does it is recorded as failed, never dropped
        _ => json!({
            "outcome": "failed", "folder": it.folder, "uidvalidity": it.uidvalidity, "uid": it.uid,
            "reason": it.reason.unwrap_or("failed")
        }),
    }
}

/* ------------------------------------------------------------- the worker */

fn run_job(job: Job, tx: tokio::sync::oneshot::Sender<Result<(), &'static str>>) {
    let rt = job.rt.clone();
    let token = job.token.clone();
    let sid = job.session_id.clone();
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| work(&job, tx)));
    if result.is_err() {
        // a bug must never leave the session stuck: free it so "Resume" works
        let _ = rt.block_on(crate::sb_rpc("migration_release", json!({ "_token": token, "_error": "worker_error" })));
        println!("[migration] {sid} worker panicked — session released");
    }
}

fn work(job: &Job, tx: tokio::sync::oneshot::Sender<Result<(), &'static str>>) {
    let sink_rt = job.rt.clone();
    let mut sink = DbSink { rt: sink_rt, token: job.token.clone(), started: Instant::now() };

    // 1) connect + log in at the OLD provider
    let first = dial(&job.host, job.port).and_then(|c| mrun::establish(c, &job.login, &job.password));
    let conn = match first {
        Ok(c) => c,
        Err(e) => {
            let code = code_of(&e);
            // nothing was copied yet: close the session cleanly (sealed, locked) and tell the person why
            let _ = sink.call("migration_finish", json!({ "_token": sink.token, "_status": "failed", "_error": code }));
            let _ = tx.send(Err(code));
            println!("[migration] {} login failed ({code})", job.session_id);
            return;
        }
    };

    // 2) the login worked: open the gate (status verified)
    match sink.call("migration_verify", json!({ "_token": sink.token })).and_then(gate) {
        Ok(_) => {}
        Err(_) => {
            let mut c = conn;
            c.logout();
            let _ = tx.send(Err("worker_error"));
            println!("[migration] {} gate did not open", job.session_id);
            return;
        }
    }
    let _ = tx.send(Ok(()));

    // 3) copy (read-only on the old side), until done / cancelled / stopped
    let host = job.host.clone();
    let port = job.port;
    let mut src = mrun::ImapSource::new(conn, Box::new(move || dial(&host, port)), &job.login, &job.password);
    let cfg = mrun::Config { include_trash_spam: job.include_trash_spam, ..Default::default() };
    let mut clock = mrun::RealClock;
    let (end, totals) = mrun::run(&mut src, &mut sink, &mut clock, &cfg);
    src.logout();

    // 4) close: sealed + locked for ever (done / cancelled) or released so Resume can continue (anything else)
    let label = match &end {
        mrun::End::Completed => {
            let _ = sink.call("migration_finish", json!({ "_token": sink.token, "_status": "completed" }));
            "completed"
        }
        mrun::End::Cancelled => {
            let _ = sink.call("migration_finish", json!({ "_token": sink.token, "_status": "cancelled", "_error": "cancelled_by_user" }));
            "cancelled"
        }
        mrun::End::Failed(kind, text) => {
            if text.starts_with("gate_closed") {
                "gate_closed" // the person cancelled, or a newer token took over: nothing left to do
            } else {
                let code = if text == "uidvalidity_changed" {
                    "folder_changed"
                } else if text.starts_with("max_runtime") {
                    "time_limit"
                } else {
                    mc::error_code(*kind)
                };
                let _ = sink.call("migration_release", json!({ "_token": sink.token, "_error": code }));
                code
            }
        }
    };
    println!(
        "[migration] {} ended={} found={} sent={} too_large={} failed={} folders={}",
        job.session_id, label, totals.found, totals.sent, totals.too_large, totals.failed, totals.folders
    );
}

/* ------------------------------------------------------------- evidence check */

fn chain_row(v: &Value) -> mc::ChainRow {
    let row_id = st(v, "row_id");
    mc::ChainRow {
        seq: num(v, "seq"),
        outcome: st(v, "outcome"),
        folder: st(v, "folder"),
        uidvalidity: num(v, "uidvalidity"),
        uid: num(v, "uid"),
        raw_sha256: st(v, "raw_sha256"),
        body_sha256: st(v, "body_sha256"),
        row_id: if row_id.is_empty() { mc::ZERO_ID.to_string() } else { row_id },
        ts: num(v, "ts"),
        copied: num(v, "copied"),
        duplicate: num(v, "duplicate"),
        skipped: num(v, "skipped"),
        failed: num(v, "failed"),
        prev_hash: st(v, "prev_hash"),
        entry_hash: st(v, "entry_hash"),
    }
}

/// Re-checks every link of the session's chain TWICE: here (Rust, page by page) and in the database. The seal hash the
/// person was given must equal the head of the chain. Tamper-EVIDENT: a changed or removed entry shows up here.
async fn verify(c: &Ctx, input: &Value) -> Resp {
    let sid = st(input, "session_id");
    if !is_uuid(&sid) {
        return fail_code(StatusCode::BAD_REQUEST, "not_found");
    }
    let got = match rpc("migration_get", json!({ "_user": c.id, "_session": sid })).await {
        Ok(v) if flag(&v, "ok") => v,
        Ok(v) => return sql_fail(&v),
        Err(r) => return r,
    };
    let session = got.get("session").cloned().unwrap_or(Value::Null);
    let mailbox = st(&session, "mailbox");
    let seal_hash = st(&session, "seal_hash");
    let want_len = num(&session, "chain_len");

    const PAGE: i64 = 2000;
    const MAX_PAGES: i64 = 1500; // 3 million entries; beyond that the answer says "partial"
    let mut walker = mc::ChainWalker::new(&sid, &mailbox);
    let mut broken: Option<(i64, &'static str)> = None;
    let mut partial = false;
    let mut pages = 0i64;
    'paging: loop {
        let after = walker.next_seq() - 1;
        let page = match rpc("migration_chain_export", json!({ "_user": c.id, "_session": sid, "_after": after, "_limit": PAGE })).await {
            Ok(v) if flag(&v, "ok") => v,
            Ok(v) => return sql_fail(&v),
            Err(r) => return r,
        };
        let rows = page.get("rows").and_then(|r| r.as_array()).cloned().unwrap_or_default();
        for r in rows.iter() {
            if let Err(b) = walker.push(&chain_row(r)) {
                broken = Some(b);
                break 'paging;
            }
        }
        pages += 1;
        if (rows.len() as i64) < PAGE {
            break;
        }
        if pages >= MAX_PAGES {
            partial = true;
            break;
        }
    }
    let database_ok = match rpc("migration_chain_verify", json!({ "_session": sid })).await {
        Ok(v) => flag(&v, "ok"),
        Err(r) => return r,
    };
    let sealed = walker.sealed();
    let complete = !partial && broken.is_none() && walker.entries() as i64 == want_len;
    let matches_seal = sealed && !seal_hash.is_empty() && walker.head() == seal_hash;
    let rust_ok = broken.is_none() && complete;
    // a closed session must carry the seal the person was given; a session still running has no seal yet
    let closed = matches!(st(&session, "status").as_str(), "completed" | "cancelled" | "failed");
    let all_ok = rust_ok && database_ok && (!closed || matches_seal);
    crate::ok(json!({
        "ok": all_ok,
        "session_id": sid,
        "entries": walker.entries(),
        "expected_entries": want_len,
        "head": walker.head(),
        "sealed": sealed,
        "seal_hash": seal_hash,
        "matches_seal": matches_seal,
        "rust_check": rust_ok,
        "database_check": database_ok,
        "partial": partial,
        "broken_at": broken.map(|b| b.0),
        "why": broken.map(|b| b.1)
    }))
    .into_response()
}
