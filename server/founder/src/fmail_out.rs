//! Q1d (founder mailbox): SEND. The sender worker (Tokio) and the HTTP doors of Compose / Undo / Drafts / DKIM.
//! Technology: Rust (Tokio + axum), SQL doors E170 (+E167 outbox state machine), fmail_mime (pure), fmail_dkim (pure), fmail_smtp (STARTTLS TLS 1.3, MX, bounded replies).
//! Flow: the browser posts the mail -> the server validates, builds the RFC 5322 message, seals it (AES-256-GCM, vault wrap: the server must read it to send it) and calls fmail_compose_send170
//! (message + outbox row in ONE transaction, undo window, limits, ledger) -> the worker claims due rows (FOR UPDATE SKIP LOCKED), opens the message, strips Bcc, signs it (DKIM Ed25519 + RSA),
//! delivers per recipient domain, reports the result (sent / failed with backoff / dead). A SEND needs a passkey touch bound to the exact mail (fmail_mime::send_target). UNDO needs none.
//! The worker is OFF unless FMAIL_SEND=on (and the database + vault master are there), so installing this code never sends a mail by itself.
use crate::{fmail_core as core, fmail_dkim as dkim, fmail_in::bytea, fmail_mime as mime, fmail_seal as seal, fmail_smtp as smtp, lease, passkey as pk, S};
use axum::{extract::State, http::{HeaderMap, StatusCode, Uri}, response::{IntoResponse, Response}};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use serde_json::{json, Value};
use std::{net::SocketAddr, sync::Arc, time::Duration};

// ---------------------------------------------------------------- config

#[derive(Clone)]
pub struct Cfg { pub relay: Option<SocketAddr>, pub helo: String }
/// FMAIL_SEND=on enables the worker. FMAIL_SMTP_RELAY=127.0.0.1:25 sends through a loopback Postfix (needed while the host blocks outbound port 25); only a loopback address is accepted.
/// FMAIL_SMTP_HELO = the host name this server says in EHLO (must match its reverse DNS for good reputation).
pub fn parse_cfg(send: Option<&str>, relay: Option<&str>, helo: Option<&str>) -> Option<Result<Cfg, String>> {
    if send.map(|s| s.eq_ignore_ascii_case("on")) != Some(true) { return None; }
    let relay = match relay { None | Some("") => None, Some(r) => match r.parse::<SocketAddr>() { Ok(a) if a.ip().is_loopback() => Some(a), Ok(_) => return Some(Err("FMAIL_SMTP_RELAY must be a loopback address".into())), Err(_) => return Some(Err("FMAIL_SMTP_RELAY must look like 127.0.0.1:25".into())) } };
    let helo = helo.unwrap_or("mail.anexomail.com").to_string();
    if helo.is_empty() || !helo.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'-') { return Some(Err("FMAIL_SMTP_HELO is not a host name".into())); }
    Some(Ok(Cfg { relay, helo }))
}
pub fn from_env() -> Option<Result<Cfg, String>> { parse_cfg(std::env::var("FMAIL_SEND").ok().as_deref(), std::env::var("FMAIL_SMTP_RELAY").ok().as_deref(), std::env::var("FMAIL_SMTP_HELO").ok().as_deref()) }

// ---------------------------------------------------------------- pure: what the worker decides

pub fn group_by_domain(rcpts: &[String]) -> Vec<(String, Vec<String>)> {
    let mut g: Vec<(String, Vec<String>)> = Vec::new();
    for r in rcpts { let d = mime::domain_of(r).to_string(); match g.iter_mut().find(|x| x.0 == d) { Some(x) => x.1.push(r.clone()), None => g.push((d, vec![r.clone()])) } }
    g
}
#[derive(Debug, PartialEq)]
pub enum Verdict { Sent { reply: String, tls: &'static str }, Retry { reply: String, error: String }, Dead { reply: String, error: String } }
fn tls_rank(t: &str) -> u8 { match t { "none" => 0, "tls12" => 1, "tls13" => 2, _ => 3 } }
/// One domain's result -> what the whole send is. Rules: anything delivered = sent (the reply lists the recipients that did NOT get it - a per-recipient retry would send duplicates to the
/// others); nothing delivered and every failure permanent = dead; otherwise retry with backoff.
pub fn decide(parts: &[Result<smtp::Outcome, smtp::Fail>]) -> Verdict {
    let mut delivered = 0usize; let mut notes: Vec<String> = Vec::new(); let mut tls: &'static str = "tls13_pq"; let mut any_temp = false; let mut errs: Vec<String> = Vec::new();
    for p in parts {
        match p {
            Ok(o) if o.delivered() => { delivered += o.accepted(); notes.push(o.summary()); if tls_rank(o.tls) < tls_rank(tls) { tls = o.tls; } }
            Ok(o) => { let e = o.data.as_ref().err().cloned().unwrap_or(smtp::Fail::Temp("not delivered".into())); if !e.is_perm() { any_temp = true; } errs.push(o.summary()); }
            Err(e) => { if !e.is_perm() { any_temp = true; } errs.push(e.text().to_string()); }
        }
    }
    let join = |v: &Vec<String>| v.join(" || ").chars().take(290).collect::<String>();
    if delivered > 0 { let mut r = join(&notes); if !errs.is_empty() { r = format!("{} || NOT DELIVERED: {}", notes.first().map(|n| n.chars().take(80).collect::<String>()).unwrap_or_default(), join(&errs)).chars().take(290).collect(); } return Verdict::Sent { reply: r, tls }; }
    if any_temp { Verdict::Retry { reply: join(&errs), error: "temporary failure, will retry".into() } } else { Verdict::Dead { reply: join(&errs), error: "refused by the remote server".into() } }
}

// ---------------------------------------------------------------- the worker

fn jb(v: &Value, k: &str) -> Option<Vec<u8>> { B64.decode(v.get(k)?.as_str()?).ok() }
fn js<'a>(v: &'a Value, k: &str) -> Option<&'a str> { v.get(k).and_then(|x| x.as_str()) }

/// Open the sealed raw message of a claimed job (vault mode only: a send always is).
pub fn open_job(master: &[u8; 32], job: &Value) -> Result<Vec<u8>, &'static str> {
    let mailbox = js(job, "mailbox_id").ok_or("no mailbox")?;
    if js(job, "seal_mode") != Some("vault") { return Err("an outgoing mail must be vault sealed"); }
    let (wrap, nm, meta, nb, body) = (jb(job, "key_wrap").ok_or("bad wrap")?, jb(job, "nonce_meta").ok_or("bad nonce")?, jb(job, "meta").ok_or("bad meta")?, jb(job, "nonce_body").ok_or("bad nonce")?, jb(job, "body").ok_or("bad body")?);
    let r = core::Row { mailbox_id: mailbox, direction: js(job, "direction").ok_or("no direction")?, key_id: js(job, "key_id").ok_or("no key")?, msgid_hex: js(job, "msgid_blind").ok_or("no id")?,
                        aad_hash_hex: js(job, "aad_hash").ok_or("no aad")?, key_wrap: &wrap, nonce_meta: &nm, meta: &meta, body: Some((&nb, &body)) };
    core::open_vault(master, &r)?.1.ok_or("the body did not open")
}
/// DKIM-sign `wire` with every active key of the mailbox; returns the signed message and how many signatures were added.
pub fn sign_all(master: &[u8; 32], mailbox: &str, domain: &str, keys: &Value, wire: &[u8], now: u64) -> (Vec<u8>, usize) {
    let mut sigs = String::new(); let mut n = 0;
    for k in keys.as_array().map(|a| a.as_slice()).unwrap_or(&[]) {
        let (Some(sel), Some(alg), Some(nonce), Some(wrapped)) = (js(k, "selector"), js(k, "alg"), jb(k, "nonce"), jb(k, "wrapped")) else { continue };
        let Some(pk8) = dkim::unwrap_private(master, mailbox, sel, alg, &nonce, &wrapped) else { continue };
        if let Ok(h) = dkim::sign(wire, &dkim::Signer { domain, selector: sel, alg: if alg == dkim::ALG_ED { dkim::ALG_ED } else { dkim::ALG_RSA }, pkcs8: &pk8 }, now) { sigs.push_str(&h); n += 1; }
    }
    let mut out = sigs.into_bytes(); out.extend_from_slice(wire); (out, n)
}

async fn run_domain(cfg: &Cfg, res: Option<&hickory_resolver::TokioResolver>, up: &smtp::RustlsUpgrade, domain: &str, from: &str, rcpts: &[String], payload: &[u8]) -> Result<smtp::Outcome, smtp::Fail> {
    if let Some(addr) = cfg.relay {
        let (io, _) = smtp::connect(&[smtp::Target { host: "localhost".into(), addr }]).await?;
        // loopback relay: TLS is optional here (the hop never leaves the machine); the relay's own policy covers the way out
        return smtp::deliver(io, &smtp::Session { helo: &cfg.helo, require_tls: false, upgrader: up, host: "localhost" }, from, rcpts, payload).await;
    }
    let res = res.ok_or(smtp::Fail::Temp("no DNS resolver".into()))?;
    let ts = smtp::targets(res, domain).await?;
    let mut last = smtp::Fail::Temp("no server tried".into());
    for t in ts.iter().take(3) {
        let (io, t) = match smtp::connect(std::slice::from_ref(t)).await { Ok(x) => x, Err(e) => { last = e; continue } };
        match smtp::deliver(io, &smtp::Session { helo: &cfg.helo, require_tls: true, upgrader: up, host: &t.host }, from, rcpts, payload).await {
            Ok(o) if o.delivered() || o.rcpts.iter().all(|r| r.result.as_ref().err().map_or(false, |e| e.is_perm())) => return Ok(o),
            Ok(o) => { last = o.data.clone().err().unwrap_or(smtp::Fail::Temp("not delivered".into())); }
            Err(e) if e.is_perm() => return Err(e),
            Err(e) => last = e,
        }
    }
    Err(last)
}

async fn process(sb: &crate::data::Sb, master: &[u8; 32], cfg: &Cfg, res: Option<&hickory_resolver::TokioResolver>, up: &smtp::RustlsUpgrade, id: &str) {
    let Some(job) = sb.rpc("fmail_outbox_job170", json!({"p_outbox": id})).await.filter(|j| j.is_object()) else { eprintln!("founder: mail send: job {id} not readable"); return };
    let (Some(actor), Some(mailbox), Some(addr)) = (js(&job, "actor"), js(&job, "mailbox_id"), js(&job, "address")) else { return };
    let report = |v: Verdict, signed: bool| async move {
        match v {
            Verdict::Sent { reply, tls } => { let _ = sb.rpc_msg("fmail_outbox_result", json!({"p_actor": actor, "p_outbox": id, "p_ok": true, "p_reply": reply, "p_tls": tls, "p_dkim": signed, "p_error": Value::Null})).await; }
            Verdict::Retry { reply, error } => { let _ = sb.rpc_msg("fmail_outbox_result", json!({"p_actor": actor, "p_outbox": id, "p_ok": false, "p_reply": reply, "p_tls": Value::Null, "p_dkim": signed, "p_error": error})).await; }
            Verdict::Dead { reply, error } => { let _ = sb.rpc_msg("fmail_outbox_dead170", json!({"p_actor": actor, "p_outbox": id, "p_reply": reply, "p_error": error})).await; }
        }
    };
    let dead = |why: &str| Verdict::Dead { reply: why.chars().take(250).collect(), error: "the stored mail cannot be sent".into() };
    let raw = match open_job(master, &job) { Ok(r) => r, Err(e) => { report(dead(e), false).await; return } };
    let (from, rcpts) = match mime::envelope(&raw) { Ok(x) => x, Err(e) => { report(dead(e), false).await; return } };
    if from != addr { report(dead("the From address is not this mailbox"), false).await; return }
    let wire = mime::strip_bcc(&raw);
    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    let (signed, nsig) = sign_all(master, mailbox, mime::domain_of(&from), &job["dkim"], &wire, now);
    if nsig == 0 { report(Verdict::Retry { reply: "no usable DKIM key".into(), error: "no active DKIM key; install one, then the mail goes".into() }, false).await; return }
    let payload = mime::data_payload(&signed);
    let mut parts = Vec::new();
    if cfg.relay.is_some() { parts.push(run_domain(cfg, res, up, "", &from, &rcpts, &payload).await); }
    else { for (d, rs) in group_by_domain(&rcpts) { parts.push(run_domain(cfg, res, up, &d, &from, &rs, &payload).await); } }
    report(decide(&parts), true).await;
}

/// Start the sender. Every 5 s: put failed rows whose backoff passed back in the queue, claim up to 5 due rows, send them one after the other (a slow server never blocks the clock).
pub async fn spawn(sb: crate::data::Sb, master: [u8; 32], cfg: Cfg) {
    let up = match smtp::RustlsUpgrade::new() { Ok(u) => Arc::new(u), Err(e) => { eprintln!("founder: mail sender NOT started: TLS config: {e}"); return } };
    let res = if cfg.relay.is_none() { match hickory_resolver::TokioResolver::builder_tokio() { Ok(b) => Some(Arc::new(b.build())), Err(e) => { eprintln!("founder: mail sender NOT started: DNS resolver: {e}"); return } } } else { None };
    eprintln!("founder: mail sender ON ({})", match cfg.relay { Some(a) => format!("relay {a}"), None => "direct MX, STARTTLS TLS 1.3 required".into() });
    tokio::spawn(async move {
        let mut tick = tokio::time::interval(Duration::from_secs(5));
        tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        loop {
            tick.tick().await;
            let _ = sb.rpc("fmail_outbox_requeue_failed", json!({})).await;
            let Some(Value::Array(ids)) = sb.rpc("fmail_outbox_claim", json!({"p_max": 5})).await else { continue };
            for id in ids.iter().filter_map(|x| x.as_str()) { process(&sb, &master, &cfg, res.as_deref(), &up, id).await; }
        }
    });
}

// ---------------------------------------------------------------- HTTP doors

fn bad(e: &str) -> Response { pk::refuse(StatusCode::BAD_REQUEST, e) }
struct BoxInfo { id: String, address: String, name: String, key_id: String, seal_mode: String }
async fn own_box(sb: &crate::data::Sb, uid: &str, mailbox: &str) -> Result<BoxInfo, Response> {
    let v = sb.rpc("fmail_mailboxes169", json!({"p_uid": uid})).await.ok_or_else(|| pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "mail database not answering - run the E169 and E170 SQL steps (sql-run.sh)"))?;
    let m = v.as_array().and_then(|a| a.iter().find(|m| m["id"] == mailbox)).ok_or_else(|| pk::refuse(StatusCode::NOT_FOUND, "no such mailbox"))?;
    if m["status"] != "active" { return Err(pk::refuse(StatusCode::FORBIDDEN, "this mailbox is not active")); }
    Ok(BoxInfo { id: mailbox.to_string(), address: js(m, "address").unwrap_or("").to_string(), name: js(m, "name").unwrap_or("").to_string(), key_id: js(m, "key_id").unwrap_or("").to_string(), seal_mode: js(m, "seal_mode").unwrap_or("").to_string() })
}
fn need_master() -> Result<&'static [u8; 32], Response> { lease::MASTER.get().ok_or_else(|| pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "the vault master key is not loaded")) }
fn now_s() -> u64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0) }
fn touch_of(j: &Value) -> Result<Option<(String, String)>, &'static str> { crate::fmail_ep::touch_of(j) }
async fn spend(st: &crate::St, sb: &crate::data::Sb, uid: &str, did: &str, t: &(String, String), action: &str, target: &str) -> Result<String, Response> {
    match sb.rpc_msg("fmail_touch_consume169", json!({"p_uid": uid, "p_device": did, "p_grant": t.0, "p_action": action, "p_target": target, "p_params": {}, "p_nonce": t.1})).await {
        Ok(Value::String(h)) if h.len() == 64 && h.bytes().all(|b| b.is_ascii_hexdigit()) => Ok(h.to_ascii_lowercase()),
        Ok(_) => Err(pk::refuse(StatusCode::BAD_GATEWAY, "the touch could not be confirmed")),
        Err(e) => { let _ = st; Err(pk::sql_err(e)) }
    }
}
fn schedule_of(j: &Value) -> Result<Option<String>, &'static str> {
    match j.get("schedule_at").and_then(|x| x.as_str()) { None | Some("") => Ok(None), Some(s) if crate::fmail_ep::is_ts(s) => Ok(Some(s.to_string())), _ => Err("schedule_at must be an ISO time (UTC)") }
}

/// POST /founder/v1/mail/send {box, to[], cc[], bcc[], subject, text, in_reply_to?, references?, schedule_at?, draft?, grant?, nonce?}
pub async fn send_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, did) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some(b) = pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)) else { return bad("box is needed") };
    let c = match mime::parse_compose(&j) { Ok(c) => c, Err(e) => return bad(e) };
    let sched = match schedule_of(&j) { Ok(s) => s, Err(e) => return bad(e) };
    let draft = match j.get("draft").and_then(|x| x.as_str()) { Some(d) if pk::is_uuid(d) => Some(d.to_string()), Some(_) => return bad("invalid draft"), None => None };
    let touch = match touch_of(&j) { Ok(t) => t, Err(e) => return bad(e) };
    let bx = match own_box(sb, &uid, &b).await { Ok(x) => x, Err(r) => return r };
    let master = match need_master() { Ok(m) => m, Err(r) => return r };
    if bx.seal_mode != "vault" && bx.seal_mode != "recipient_pq" { return bad("this mailbox cannot send"); }
    let target = mime::send_target(&b, &c, sched.as_deref().unwrap_or(""));
    let Some(t) = touch else { return crate::signed(&st, json!({"needs_touch": true, "action": "mail.send", "target": target})) };
    // build + seal BEFORE spending the touch: a mail that cannot be built must not burn a grant
    let domain = mime::domain_of(&bx.address).to_string();
    let mid = match mime::new_message_id(&domain) { Ok(m) => m, Err(e) => return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    let raw = match mime::build(&c, &bx.address, &bx.name, &mid, now_s()) { Ok(r) => r, Err(e) => return bad(e) };
    let sum = core::summarize(&raw);
    let vault_kid = if bx.key_id.is_empty() { "vault-1".to_string() } else { bx.key_id.clone() };
    let sealed = match core::seal_message(master, &b, "out", core::Wrap::Vault { master, key_id: &vault_kid }, &raw, &sum) { Ok(s) => s, Err(e) => return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    let bk = match seal::blind_key(master, &b) { Ok(k) => k, Err(e) => return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    let mut all: Vec<&String> = c.to.iter().chain(c.cc.iter()).chain(c.bcc.iter()).collect(); all.sort(); all.dedup();
    let rcpt_hex: Vec<String> = all.iter().map(|a| hex::encode(seal::blind(&bk, "rcpt", a))).collect();
    let hash = match spend(&st, sb, &uid, &did, &t, "mail.send", &target).await { Ok(h) => h, Err(r) => return r };
    let opt = |b: &Option<[u8; 32]>| b.as_ref().map(|x| Value::String(bytea(x))).unwrap_or(Value::Null);
    match sb.rpc_msg("fmail_compose_send170", json!({
        "p_actor": uid, "p_mailbox": b, "p_sealed_body": bytea(&sealed.sealed_body), "p_sealed_meta": bytea(&sealed.sealed_meta), "p_nonce_body": bytea(&sealed.nonce_body), "p_nonce_meta": bytea(&sealed.nonce_meta),
        "p_key_id": sealed.key_id, "p_key_wrap": bytea(&sealed.key_wrap), "p_aad_hash": bytea(&sealed.aad_hash), "p_msgid_blind": bytea(&sealed.msgid_blind), "p_parent_blind": opt(&sealed.parent_blind),
        "p_subject_blind": bytea(&sealed.subject_blind), "p_size": raw.len() as i64, "p_attach": 0, "p_rcpt_hex": rcpt_hex, "p_schedule_at": sched, "p_touch_hash": hash, "p_draft": draft,
    })).await {
        Ok(v) => crate::signed(&st, json!({"ok": true, "queued": v})),
        Err((_, m)) if m.contains("DKIM") => crate::signed(&st, json!({"ok": false, "needs_dkim": true, "error": "Install a DKIM signing key for this mailbox first (Mail > Domain keys). Unsigned mail is never sent."})),
        Err(e) => pk::sql_err(e),
    }
}

fn ids_ok(j: &Value) -> Option<(String, String)> { Some((pk::txt(j, "box", 40).filter(|x| pk::is_uuid(x))?, pk::txt(j, "outbox", 40).filter(|x| pk::is_uuid(x))?)) }
async fn in_outbox(sb: &crate::data::Sb, b: &str, ob: &str) -> bool { sb.rpc("fmail_outbox_list170", json!({"p_mailbox": b})).await.and_then(|v| v.as_array().map(|a| a.iter().any(|r| r["outbox_id"] == ob))).unwrap_or(false) }

/// POST /founder/v1/mail/undo {box, outbox}: no touch (it only takes a mail BACK). The database refuses it after the undo window.
pub async fn undo_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some((b, ob)) = ids_ok(&j) else { return bad("box and outbox are needed") };
    if let Err(r) = own_box(sb, &uid, &b).await { return r; }
    if !in_outbox(sb, &b, &ob).await { return pk::refuse(StatusCode::NOT_FOUND, "no such queued mail"); }
    match sb.rpc_msg("fmail_outbox_undo", json!({"p_actor": uid, "p_outbox": ob})).await { Ok(v) => crate::signed(&st, json!({"ok": true, "result": v})), Err(e) => pk::sql_err(e) }
}
/// POST /founder/v1/mail/cancel {box, outbox}: cancel a scheduled or failed mail (it goes back to Drafts).
pub async fn cancel_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some((b, ob)) = ids_ok(&j) else { return bad("box and outbox are needed") };
    if let Err(r) = own_box(sb, &uid, &b).await { return r; }
    match sb.rpc_msg("fmail_outbox_cancel170", json!({"p_actor": uid, "p_mailbox": b, "p_outbox": ob})).await { Ok(v) => crate::signed(&st, json!({"ok": true, "result": v})), Err(e) => pk::sql_err(e) }
}
/// GET /founder/v1/mail/outbox?box=<uuid>: states and clocks only.
pub async fn outbox_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let b = match crate::fmail_ep::parse_box(uri.query()) { Ok(b) => b, Err(e) => return bad(e) };
    let sb = st.sb.as_ref().unwrap();
    if let Err(r) = own_box(sb, &c.sub, &b).await { return r; }
    match sb.rpc("fmail_outbox_list170", json!({"p_mailbox": b})).await { Some(v) if v.is_array() => crate::signed(&st, json!({"connected": true, "outbox": v})), _ => crate::signed(&st, json!({"connected": false, "note": "run the E170 SQL step (sql-run.sh)"})) }
}

// ---- drafts: the compose form autosaves a sealed version; stale saves are refused (409)
fn draft_aad(b: &str) -> Vec<u8> { seal::aad(&["fmail-draft-v1", b]) }
/// POST /founder/v1/mail/draft {box, draft?, expected, in_reply_to?, <compose fields, may be empty>}
pub async fn draft_save_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some(b) = pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)) else { return bad("box is needed") };
    let bx = match own_box(sb, &uid, &b).await { Ok(x) => x, Err(r) => return r };
    let master = match need_master() { Ok(m) => m, Err(r) => return r };
    let draft = match j.get("draft").and_then(|x| x.as_str()) { Some(d) if pk::is_uuid(d) => Some(d.to_string()), Some(_) => return bad("invalid draft"), None => None };
    let expected = j.get("expected").and_then(|x| x.as_i64()).unwrap_or(0).clamp(0, 100_000);
    // a draft may be half written: only the sizes and the control characters are checked here (the full check runs at send)
    let pick = |k: &str| j.get(k).cloned().unwrap_or(Value::Null);
    let doc = json!({"to": pick("to"), "cc": pick("cc"), "bcc": pick("bcc"), "subject": pick("subject"), "text": pick("text"), "in_reply_to": pick("in_reply_to")});
    let bytes = doc.to_string();
    if bytes.len() > mime::MAX_TEXT + 64 * 1024 { return bad("the draft is too long"); }
    if doc["subject"].as_str().map_or(false, |s| s.chars().count() > mime::MAX_SUBJECT) { return bad("the subject is too long"); }
    let reply_to = match j.get("reply_to").and_then(|x| x.as_str()) { Some(d) if pk::is_uuid(d) => Some(d.to_string()), Some(_) => return bad("invalid reply_to"), None => None };
    let key = match seal::new_key() { Ok(k) => k, Err(e) => return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    let (nonce, ct) = match seal::seal(&key, &draft_aad(&b), bytes.as_bytes()) { Ok(x) => x, Err(e) => return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    let kid = if bx.key_id.is_empty() { "vault-1".to_string() } else { bx.key_id.clone() };
    let wrap = match seal::wrap_vault(master, &kid, &key) { Ok(w) => w, Err(e) => return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    match sb.rpc_msg("fmail_draft_save170", json!({"p_mailbox": b, "p_draft": draft, "p_expected": expected, "p_reply_to": reply_to, "p_sealed": bytea(&ct), "p_nonce": bytea(&nonce), "p_key_id": kid, "p_key_wrap": bytea(&wrap)})).await {
        Ok(v) => crate::signed(&st, json!({"ok": true, "draft": v})),
        Err((_, m)) if m.contains("stale") => (StatusCode::CONFLICT, axum::Json(json!({"error": "this draft was changed somewhere else; reload it", "stale": true}))).into_response(),
        Err(e) => pk::sql_err(e),
    }
}
/// GET /founder/v1/mail/drafts?box=<uuid> -> list; GET /founder/v1/mail/draft?box=<uuid>&id=<uuid> -> the opened draft
pub async fn drafts_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let (b, id) = match crate::fmail_ep::parse_proof(uri.query()) { Ok(x) => x, Err(e) => return bad(e) };
    let sb = st.sb.as_ref().unwrap();
    let bx = match own_box(sb, &c.sub, &b).await { Ok(x) => x, Err(r) => return r };
    let Some(id) = id else {
        return match sb.rpc("fmail_draft_list170", json!({"p_mailbox": b})).await { Some(v) if v.is_array() => crate::signed(&st, json!({"connected": true, "drafts": v})), _ => crate::signed(&st, json!({"connected": false, "note": "run the E170 SQL step (sql-run.sh)"})) };
    };
    let master = match need_master() { Ok(m) => m, Err(r) => return r };
    let Some(d) = sb.rpc("fmail_draft_get170", json!({"p_mailbox": b, "p_draft": id})).await.filter(|d| d.is_object()) else { return pk::refuse(StatusCode::NOT_FOUND, "no such draft") };
    let (Some(wrap), Some(nonce), Some(ct), Some(kid)) = (jb(&d, "key_wrap"), jb(&d, "nonce"), jb(&d, "sealed"), js(&d, "key_id")) else { return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, "the draft is damaged") };
    let Some(key) = seal::unwrap_vault(master, kid, &wrap) else { return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, "the draft key does not open") };
    let Some(plain) = seal::open(&key, &nonce, &draft_aad(&b), &ct) else { return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, "the draft does not verify") };
    let doc: Value = serde_json::from_slice(&plain).unwrap_or(Value::Null);
    let _ = bx;
    crate::signed(&st, json!({"connected": true, "draft": {"id": id, "version": d["version"], "reply_to": d["reply_to"], "content": doc}}))
}
/// POST /founder/v1/mail/draft/discard {box, draft}
pub async fn draft_discard_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let (Some(b), Some(d)) = (pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)), pk::txt(&j, "draft", 40).filter(|x| pk::is_uuid(x))) else { return bad("box and draft are needed") };
    if let Err(r) = own_box(sb, &uid, &b).await { return r; }
    match sb.rpc_msg("fmail_draft_discard170", json!({"p_mailbox": b, "p_draft": d})).await { Ok(v) => crate::signed(&st, json!({"ok": true, "result": v})), Err(e) => pk::sql_err(e) }
}

// ---- DKIM keys
pub fn dkim_target(b: &str, selector: &str, alg: &str) -> String { format!("dkim:{b}:{selector}:{alg}") }
fn dns_rows(bx_addr: &str, keys: &Value) -> Value {
    let dom = mime::domain_of(bx_addr);
    Value::Array(keys.as_array().map(|a| a.iter().filter_map(|k| {
        let (sel, alg, pubk) = (js(k, "selector")?, js(k, "alg")?, B64.decode(js(k, "public")?).ok()?);
        Some(json!({"id": k["id"], "selector": sel, "alg": alg, "dns_name": format!("{sel}._domainkey.{dom}"), "dns_type": "TXT", "dns_value": dkim::dns_txt(alg, &pubk), "created_at": k["created_at"]}))
    }).collect()).unwrap_or_default())
}
/// GET /founder/v1/mail/dkim?box=<uuid>: the active keys and the exact DNS record to publish for each. Private halves never leave the server.
pub async fn dkim_get_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let b = match crate::fmail_ep::parse_box(uri.query()) { Ok(b) => b, Err(e) => return bad(e) };
    let sb = st.sb.as_ref().unwrap();
    let bx = match own_box(sb, &c.sub, &b).await { Ok(x) => x, Err(r) => return r };
    match sb.rpc("fmail_dkim_active170", json!({"p_mailbox": b})).await { Some(v) if v.is_array() => crate::signed(&st, json!({"connected": true, "keys": dns_rows(&bx.address, &v)})), _ => crate::signed(&st, json!({"connected": false, "note": "run the E170 SQL step (sql-run.sh)"})) }
}
/// POST /founder/v1/mail/dkim {box, selector, alg, grant?, nonce?}: generate a key pair HERE, store the private half sealed, answer with the DNS record. Needs a touch (action mail.key).
pub async fn dkim_set_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, did) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some(b) = pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)) else { return bad("box is needed") };
    let Some(sel) = pk::txt(&j, "selector", 63).filter(|s| !s.is_empty() && s.len() <= 63 && s.bytes().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'-') && !s.starts_with('-')) else { return bad("selector: lower-case letters, digits and - (max 63)") };
    let Some(alg) = pk::txt(&j, "alg", 20).filter(|a| a == dkim::ALG_ED || a == dkim::ALG_RSA) else { return bad("alg must be ed25519-sha256 or rsa-sha256") };
    let touch = match touch_of(&j) { Ok(t) => t, Err(e) => return bad(e) };
    let bx = match own_box(sb, &uid, &b).await { Ok(x) => x, Err(r) => return r };
    let master = match need_master() { Ok(m) => m, Err(r) => return r };
    let target = dkim_target(&b, &sel, &alg);
    let Some(t) = touch else { return crate::signed(&st, json!({"needs_touch": true, "action": "mail.key", "target": target})) };
    let nk = match if alg == dkim::ALG_ED { dkim::gen_ed25519() } else { tokio::task::spawn_blocking(|| dkim::gen_rsa(2048)).await.unwrap_or(Err("key generation failed")) } { Ok(k) => k, Err(e) => return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    let (nonce, wrapped) = match dkim::wrap_private(master, &b, &sel, nk.alg, &nk.pkcs8) { Ok(x) => x, Err(e) => return pk::refuse(StatusCode::INTERNAL_SERVER_ERROR, e) };
    let hash = match spend(&st, sb, &uid, &did, &t, "mail.key", &target).await { Ok(h) => h, Err(r) => return r };
    match sb.rpc_msg("fmail_dkim_install170", json!({"p_actor": uid, "p_mailbox": b, "p_selector": sel, "p_alg": nk.alg, "p_public": bytea(&nk.public), "p_wrapped": bytea(&wrapped), "p_nonce": bytea(&nonce), "p_touch_hash": hash})).await {
        Ok(v) => crate::signed(&st, json!({"ok": true, "installed": v, "dns_name": format!("{sel}._domainkey.{}", mime::domain_of(&bx.address)), "dns_type": "TXT", "dns_value": dkim::dns_txt(nk.alg, &nk.public)})),
        Err(e) => pk::sql_err(e),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fmail_smtp::{Fail, Outcome, Rcpt};
    fn ok_out(domain_rcpts: &[&str], tls: &'static str) -> Outcome { Outcome { rcpts: domain_rcpts.iter().map(|a| Rcpt { addr: a.to_string(), result: Ok("250 ok".into()) }).collect(), data: Ok("250 queued".into()), tls } }
    #[test] fn cfg_is_off_unless_asked_and_relay_must_be_loopback() {
        assert!(parse_cfg(None, None, None).is_none()); assert!(parse_cfg(Some("off"), None, None).is_none());
        let c = parse_cfg(Some("on"), Some("127.0.0.1:25"), Some("mail.anexomail.com")).unwrap().unwrap(); assert_eq!(c.relay.unwrap().port(), 25);
        assert!(parse_cfg(Some("on"), Some("8.8.8.8:25"), None).unwrap().is_err()); assert!(parse_cfg(Some("on"), Some("nope"), None).unwrap().is_err()); assert!(parse_cfg(Some("on"), None, Some("bad host!")).unwrap().is_err());
        assert!(parse_cfg(Some("ON"), None, None).unwrap().unwrap().relay.is_none());
    }
    #[test] fn recipients_are_grouped_by_domain() {
        let g = group_by_domain(&["a@x.com".into(), "b@y.org".into(), "c@x.com".into()]); assert_eq!(g, vec![("x.com".to_string(), vec!["a@x.com".to_string(), "c@x.com".to_string()]), ("y.org".to_string(), vec!["b@y.org".to_string()])]);
    }
    #[test] fn decide_sent_retry_dead() {
        assert!(matches!(decide(&[Ok(ok_out(&["a@x.com"], "tls13_pq")), Ok(ok_out(&["b@y.org"], "tls13"))]), Verdict::Sent { tls: "tls13", .. }));
        assert!(matches!(decide(&[Ok(ok_out(&["a@x.com"], "none"))]), Verdict::Sent { tls: "none", .. }));
        let v = decide(&[Ok(ok_out(&["a@x.com"], "tls13")), Err(Fail::Perm("550 no".into()))]); match v { Verdict::Sent { reply, .. } => assert!(reply.contains("NOT DELIVERED") && reply.contains("550 no")), o => panic!("{o:?}") }
        assert!(matches!(decide(&[Err(Fail::Temp("451 later".into()))]), Verdict::Retry { .. }));
        assert!(matches!(decide(&[Err(Fail::Perm("550 no".into())), Err(Fail::Temp("timeout".into()))]), Verdict::Retry { .. }), "one temporary failure keeps the retry alive");
        assert!(matches!(decide(&[Err(Fail::Perm("550 no".into()))]), Verdict::Dead { .. }));
        assert!(matches!(decide(&[]), Verdict::Dead { .. }));
    }
    #[test] fn dkim_target_binds_box_selector_alg() { assert_ne!(dkim_target("b", "s1", "ed25519-sha256"), dkim_target("b", "s2", "ed25519-sha256")); assert!(dkim_target("b", "s", "rsa-sha256").len() <= 200); }
    #[test] fn dns_rows_carry_the_exact_record() {
        let k = dkim::gen_ed25519().unwrap();
        let rows = dns_rows("naumansherwani.founder@anexomail.com", &json!([{"id": "1", "selector": "s1", "alg": "ed25519-sha256", "public": B64.encode(&k.public), "created_at": "t"}]));
        assert_eq!(rows[0]["dns_name"], "s1._domainkey.anexomail.com"); assert!(rows[0]["dns_value"].as_str().unwrap().starts_with("v=DKIM1; k=ed25519; p="));
    }
    #[test] fn job_opens_signs_and_envelope_survives_end_to_end() {
        let master = [9u8; 32]; let mailbox = "11111111-1111-1111-1111-111111111111";
        let c = mime::parse_compose(&json!({"to": ["a@x.com"], "bcc": ["hidden@y.org"], "subject": "Hi", "text": "body"})).unwrap();
        let raw = mime::build(&c, "me@anexomail.com", "Me", "m1@anexomail.com", 1_794_538_800).unwrap();
        let sum = core::summarize(&raw);
        let sealed = core::seal_message(&master, mailbox, "out", core::Wrap::Vault { master: &master, key_id: "vault-1" }, &raw, &sum).unwrap();
        let k = dkim::gen_ed25519().unwrap(); let (n, w) = dkim::wrap_private(&master, mailbox, "s1", dkim::ALG_ED, &k.pkcs8).unwrap();
        let job = json!({"mailbox_id": mailbox, "seal_mode": "vault", "direction": "out", "key_id": "vault-1", "msgid_blind": hex::encode(sealed.msgid_blind), "aad_hash": hex::encode(sealed.aad_hash),
            "key_wrap": B64.encode(&sealed.key_wrap), "meta": B64.encode(&sealed.sealed_meta), "nonce_meta": B64.encode(sealed.nonce_meta), "body": B64.encode(&sealed.sealed_body), "nonce_body": B64.encode(sealed.nonce_body),
            "dkim": [{"selector": "s1", "alg": "ed25519-sha256", "nonce": B64.encode(n), "wrapped": B64.encode(&w), "public": B64.encode(&k.public)}]});
        let opened = open_job(&master, &job).unwrap(); assert_eq!(opened, raw);
        let (from, rc) = mime::envelope(&opened).unwrap(); assert_eq!(from, "me@anexomail.com"); assert_eq!(rc, vec!["a@x.com", "hidden@y.org"]);
        let wire = mime::strip_bcc(&opened); assert!(!String::from_utf8_lossy(&wire).contains("hidden@y.org"));
        let (signed, nsig) = sign_all(&master, mailbox, "anexomail.com", &job["dkim"], &wire, 1_794_538_800); assert_eq!(nsig, 1);
        assert!(dkim::verify(&signed, dkim::ALG_ED, &k.public), "the mail that goes on the wire carries a valid signature");
        assert!(!String::from_utf8_lossy(&signed).contains("hidden@y.org"), "Bcc never reaches the wire, not even inside the signature");
        let mut other = job.clone(); other["mailbox_id"] = json!("22222222-2222-2222-2222-222222222222"); assert!(open_job(&master, &other).is_err(), "a sealed mail cannot be opened as another mailbox");
        let mut pq = job.clone(); pq["seal_mode"] = json!("recipient_pq"); assert!(open_job(&master, &pq).is_err());
        assert_eq!(sign_all(&[1u8; 32], mailbox, "anexomail.com", &job["dkim"], &wire, 1).1, 0, "a wrong master unwraps no key");
    }
}
