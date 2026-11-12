//! Q1b-3 (founder mailbox): the HTTP doors of the Mail page. Every query is whitelisted HERE before it reaches SQL (like inbox.rs); every answer is Ed25519-signed (`signed`).
//! Reads use `authed`; writes use `pk::ctx(..., true)` (fresh session check + request signature + a founder device token). A mail in Quarantine or in a Vault thread is opened,
//! moved out or taken out of the vault ONLY with a spent passkey grant: the browser asks /passkey/options (purpose "action", action mail.unseal / mail.vault_out, target = the id),
//! the user touches the key, /passkey/verify gives a grant, and the grant + nonce arrive here. fmail_touch_consume169 spends it once; the resulting touch hash is written into the mail ledger.
//! Seal modes: `vault` mail is opened here (AES-256-GCM, master key stays in this process) and the browser gets plain summary/text only AFTER the gate; `recipient_pq` mail is sent to the browser
//! still sealed (the server CANNOT open it) for the kernel to open (Q4).
use crate::{fmail_core as core, lease, live, passkey as pk, S};
use axum::{extract::State, http::{HeaderMap, StatusCode, Uri}, response::{IntoResponse, Response}};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use serde_json::{json, Value};

pub const VIEWS: [&str; 10] = ["inbox", "sent", "drafts", "outbox", "archive", "snoozed", "spam", "quarantine", "trash", "vault"];
pub const MOVE_TO: [&str; 4] = ["inbox", "archive", "spam", "trash"];

// ---------------------------------------------------------------- pure: query + body parsing

#[derive(Debug, PartialEq)]
pub struct ListQ { pub mailbox: String, pub view: String, pub after: Option<(String, String)>, pub limit: i64 }

fn pairs(q: Option<&str>) -> impl Iterator<Item = (&str, &str)> { q.unwrap_or("").split('&').filter(|p| !p.is_empty()).map(|p| p.split_once('=').unwrap_or((p, ""))) }
pub fn is_ts(v: &str) -> bool { v.len() >= 20 && v.len() <= 32 && v.bytes().all(|b| b.is_ascii_digit() || matches!(b, b'-' | b':' | b'T' | b'Z' | b'.')) }

/// `box=<uuid>` and nothing else.
pub fn parse_box(q: Option<&str>) -> Result<String, &'static str> {
    let mut m = None;
    for (k, v) in pairs(q) { match k { "box" => { if !pk::is_uuid(v) { return Err("invalid box"); } m = Some(v.to_string()); } _ => return Err("unknown parameter") } }
    m.ok_or("missing box")
}
pub fn parse_list(q: Option<&str>) -> Result<ListQ, &'static str> {
    let (mut mailbox, mut view, mut ts, mut id, mut limit) = (None, "inbox".to_string(), None, None, 50i64);
    for (k, v) in pairs(q) {
        match k {
            "box" => { if !pk::is_uuid(v) { return Err("invalid box"); } mailbox = Some(v.to_string()); }
            "view" => { if !VIEWS.contains(&v) { return Err("invalid view"); } view = v.to_string(); }
            "ts" => { if !is_ts(v) { return Err("invalid ts"); } ts = Some(v.to_string()); }
            "id" => { if !pk::is_uuid(v) { return Err("invalid id"); } id = Some(v.to_string()); }
            "limit" => { limit = v.parse::<i64>().map_err(|_| "invalid limit")?.clamp(1, 100); }
            _ => return Err("unknown parameter"),
        }
    }
    let after = match (ts, id) { (Some(t), Some(i)) => Some((t, i)), (None, None) => None, _ => return Err("the cursor needs both ts and id") };
    Ok(ListQ { mailbox: mailbox.ok_or("missing box")?, view, after, limit })
}
/// `box=<uuid>&id=<uuid>` (id optional: without it the whole ledger chain is verified).
pub fn parse_proof(q: Option<&str>) -> Result<(String, Option<String>), &'static str> {
    let (mut b, mut i) = (None, None);
    for (k, v) in pairs(q) { match k { "box" => { if !pk::is_uuid(v) { return Err("invalid box"); } b = Some(v.to_string()); } "id" => { if !pk::is_uuid(v) { return Err("invalid id"); } i = Some(v.to_string()); } _ => return Err("unknown parameter") } }
    Ok((b.ok_or("missing box")?, i))
}
/// 1..=100 uuids from a JSON array.
pub fn ids_of(v: &Value, key: &str) -> Result<Vec<String>, &'static str> {
    let a = v.get(key).and_then(|x| x.as_array()).ok_or("missing ids")?;
    if a.is_empty() || a.len() > 100 { return Err("1..100 ids"); }
    a.iter().map(|x| x.as_str().filter(|s| pk::is_uuid(s)).map(str::to_string).ok_or("invalid id")).collect()
}
/// The grant + nonce a gated call carries; both or neither.
pub fn touch_of(v: &Value) -> Result<Option<(String, String)>, &'static str> {
    match (v.get("grant").and_then(|x| x.as_str()), v.get("nonce").and_then(|x| x.as_str())) {
        (None, None) => Ok(None),
        (Some(g), Some(n)) if pk::is_uuid(g) && n.len() >= 8 && n.len() <= 128 && n.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_') => Ok(Some((g.to_string(), n.to_string()))),
        _ => Err("a touch needs a valid grant and nonce together"),
    }
}

// ---------------------------------------------------------------- pure: opening rows

fn b64(v: &Value, k: &str) -> Option<Vec<u8>> { B64.decode(v.get(k)?.as_str()?).ok() }
fn s<'a>(v: &'a Value, k: &str) -> Option<&'a str> { v.get(k).and_then(|x| x.as_str()) }

/// Open the sealed summary of one LIST row (vault mode). Returns the summary JSON, or None when the row does not verify.
pub fn open_list_row(master: &[u8; 32], mailbox: &str, row: &Value) -> Option<Value> {
    let (mh, ah, kid) = (s(row, "msgid_blind")?, s(row, "aad_hash")?, s(row, "key_id")?);
    let (wrap, nonce, meta) = (b64(row, "key_wrap")?, b64(row, "nonce_meta")?, b64(row, "meta")?);
    let r = core::Row { mailbox_id: mailbox, direction: s(row, "direction")?, key_id: kid, msgid_hex: mh, aad_hash_hex: ah, key_wrap: &wrap, nonce_meta: &nonce, meta: &meta, body: None };
    core::open_vault(master, &r).ok().map(|x| x.0)
}
const SEALED_FIELDS: [&str; 5] = ["meta", "nonce_meta", "key_wrap", "aad_hash", "msgid_blind"];
/// What the browser gets for one row: facts + (vault mode) the opened summary under `sum`; sealed bytes are removed unless the kernel must open them (recipient_pq).
pub fn shape_row(master: Option<&[u8; 32]>, mailbox: &str, row: &Value) -> Value {
    let mut out = row.clone();
    let gated = row["gated"] == true;
    let pq = s(row, "seal_mode") == Some("recipient_pq");
    if !gated && !pq {
        match master.and_then(|m| open_list_row(m, mailbox, row)) { Some(sum) => out["sum"] = sum, None => { out["sum"] = Value::Null; out["broken"] = json!(true); } }
    }
    if !(pq && !gated) { if let Some(o) = out.as_object_mut() { for k in SEALED_FIELDS { o.remove(k); } o.remove("nonce_meta"); o.remove("body"); o.remove("nonce_body"); } }
    out
}

/// Full open of one message (vault mode) after the gate: summary + safe view. None = does not verify.
pub fn open_message(master: &[u8; 32], mailbox: &str, m: &Value) -> Result<Value, &'static str> {
    let (mh, ah, kid) = (s(m, "msgid_blind").ok_or("no id")?, s(m, "aad_hash").ok_or("no aad")?, s(m, "key_id").ok_or("no key")?);
    let (wrap, nm, meta, nb, body) = (b64(m, "key_wrap").ok_or("bad wrap")?, b64(m, "nonce_meta").ok_or("bad nonce")?, b64(m, "meta").ok_or("bad meta")?, b64(m, "nonce_body").ok_or("bad nonce")?, b64(m, "body").ok_or("bad body")?);
    let r = core::Row { mailbox_id: mailbox, direction: s(m, "direction").ok_or("no direction")?, key_id: kid, msgid_hex: mh, aad_hash_hex: ah, key_wrap: &wrap, nonce_meta: &nm, meta: &meta, body: Some((&nb, &body)) };
    let (sum, raw) = core::open_vault(master, &r)?;
    Ok(json!({"sum": sum, "view": core::render(&raw.unwrap_or_default())}))
}

// ---------------------------------------------------------------- handlers

fn bad(e: &str) -> Response { pk::refuse(StatusCode::BAD_REQUEST, e) }

/// The mailbox must belong to the signed-in founder (fmail_mailboxes169 lists only his).
async fn own(sb: &crate::data::Sb, uid: &str, mailbox: &str) -> Result<(), Response> {
    let v = sb.rpc("fmail_mailboxes169", json!({"p_uid": uid})).await.ok_or_else(|| pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "mail database not answering - run the E169 SQL step (sql-run.sh)"))?;
    if v.as_array().map_or(false, |a| a.iter().any(|m| m["id"] == mailbox)) { Ok(()) } else { Err(pk::refuse(StatusCode::NOT_FOUND, "no such mailbox")) }
}
fn missing() -> Value { json!({"connected": false, "note": "mail doors not answering - run the E167, E168 and E169 SQL steps (sql-run.sh)"}) }

pub async fn boxes_ep(State(st): State<S>, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("fmail_mailboxes169", json!({"p_uid": c.sub})).await { Some(v) if v.is_array() => crate::signed(&st, json!({"connected": true, "boxes": v, "vault_ready": lease::MASTER.get().is_some()})), _ => crate::signed(&st, missing()) }
}
pub async fn counts_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let b = match parse_box(uri.query()) { Ok(b) => b, Err(e) => return bad(e) };
    let sb = st.sb.as_ref().unwrap();
    if let Err(r) = own(sb, &c.sub, &b).await { return r; }
    match sb.rpc("fmail_counts169", json!({"p_mailbox": b})).await { Some(v) if v.is_object() => crate::signed(&st, json!({"connected": true, "counts": v})), _ => crate::signed(&st, missing()) }
}
pub async fn list_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let q = match parse_list(uri.query()) { Ok(q) => q, Err(e) => return bad(e) };
    let sb = st.sb.as_ref().unwrap();
    if let Err(r) = own(sb, &c.sub, &q.mailbox).await { return r; }
    let (ts, id) = q.after.clone().map(|(t, i)| (Value::String(t), Value::String(i))).unwrap_or((Value::Null, Value::Null));
    let Some(mut v) = sb.rpc("fmail_list169", json!({"p_mailbox": q.mailbox, "p_view": q.view, "p_after_ts": ts, "p_after_id": id, "p_limit": q.limit})).await.filter(|v| v.is_object()) else { return crate::signed(&st, missing()) };
    let master = lease::MASTER.get();
    let rows: Vec<Value> = v["rows"].as_array().map(|a| a.iter().map(|r| shape_row(master, &q.mailbox, r)).collect()).unwrap_or_default();
    v["rows"] = Value::Array(rows);
    crate::signed(&st, json!({"connected": true, "list": v, "view": q.view}))
}
pub async fn lanes_ep(State(st): State<S>, h: HeaderMap) -> Response {
    if let Err(e) = crate::authed(&st, &h).await { return e.into_response(); }
    let sb = st.sb.as_ref().unwrap();
    match sb.rpc("fmail_bridge_feed", json!({"p_hours": 24})).await { Some(v) if v.is_object() => crate::signed(&st, json!({"connected": true, "feed": v})), _ => crate::signed(&st, missing()) }
}
pub async fn proof_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let (b, id) = match parse_proof(uri.query()) { Ok(x) => x, Err(e) => return bad(e) };
    let sb = st.sb.as_ref().unwrap();
    if let Err(r) = own(sb, &c.sub, &b).await { return r; }
    match sb.rpc("fmail_proof169", json!({"p_mailbox": b, "p_message": id})).await { Some(v) if v.is_object() => crate::signed(&st, json!({"connected": true, "proof": v})), _ => crate::signed(&st, missing()) }
}

/// Spend a grant for a mail action. Err = the HTTP answer. Ok(hash) = the touch hash the SQL door writes into the ledger.
async fn spend(st: &crate::St, sb: &crate::data::Sb, uid: &str, did: &str, t: &(String, String), action: &str, target: &str) -> Result<String, Response> {
    match sb.rpc_msg("fmail_touch_consume169", json!({"p_uid": uid, "p_device": did, "p_grant": t.0, "p_action": action, "p_target": target, "p_params": {}, "p_nonce": t.1})).await {
        Ok(Value::String(h)) if h.len() == 64 && h.bytes().all(|b| b.is_ascii_hexdigit()) => Ok(h.to_ascii_lowercase()),
        Ok(_) => Err(pk::refuse(StatusCode::BAD_GATEWAY, "the touch could not be confirmed")),
        Err(e) => { let _ = st; Err(pk::sql_err(e)) }
    }
}

/// POST /founder/v1/mail/open {box, id, grant?, nonce?}
pub async fn open_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _email, did) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let (Some(b), Some(id)) = (pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)), pk::txt(&j, "id", 40).filter(|x| pk::is_uuid(x))) else { return bad("box and id are needed") };
    let touch = match touch_of(&j) { Ok(t) => t, Err(e) => return bad(e) };
    if let Err(r) = own(sb, &uid, &b).await { return r; }
    let Some(first) = sb.rpc("fmail_get169", json!({"p_mailbox": b, "p_message": id, "p_touch_hash": Value::Null})).await else { return pk::refuse(StatusCode::BAD_GATEWAY, "mail database not answering") };
    if first["found"] != true { return pk::refuse(StatusCode::NOT_FOUND, "no such message"); }
    let mut m = first;
    let mut touched = false;
    if m["needs_touch"] == true {
        let Some(t) = touch else { return crate::signed(&st, json!({"needs_touch": true, "action": "mail.unseal", "target": id, "folder": m["folder"], "vault": m["vault"]})) };
        let hash = match spend(&st, sb, &uid, &did, &t, "mail.unseal", &id).await { Ok(h) => h, Err(r) => return r };
        m = match sb.rpc_msg("fmail_get169", json!({"p_mailbox": b, "p_message": id, "p_touch_hash": hash})).await { Ok(v) => v, Err(e) => return pk::sql_err(e) };
        touched = true;
    }
    if m["seal_mode"] == "recipient_pq" {
        // the server cannot open this one: the sealed parts go to the browser kernel
        return crate::signed(&st, json!({"sealed_for_kernel": true, "touched": touched, "mail": m}));
    }
    let Some(master) = lease::MASTER.get() else { return pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "the vault key is not set up on the server") };
    let opened = match open_message(master, &b, &m) { Ok(o) => o, Err(e) => return crate::signed(&st, json!({"broken": true, "reason": e, "id": id})) };
    if m["direction"] == "in" && m["read"] == false { let _ = sb.rpc("fmail_flag", json!({"p_mailbox": b, "p_ids": [id], "p_read": true, "p_star": Value::Null})).await; }
    let mut facts = m.clone();
    if let Some(o) = facts.as_object_mut() { for k in ["meta", "nonce_meta", "key_wrap", "aad_hash", "msgid_blind", "body", "nonce_body"] { o.remove(k); } }
    crate::signed(&st, json!({"opened": true, "touched": touched, "facts": facts, "sum": opened["sum"], "view": opened["view"]}))
}

/// POST /founder/v1/mail/flag {box, ids[], read?, starred?}
pub async fn flag_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some(b) = pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)) else { return bad("box is needed") };
    let ids = match ids_of(&j, "ids") { Ok(i) => i, Err(e) => return bad(e) };
    let (read, star) = (j.get("read").and_then(|x| x.as_bool()), j.get("starred").and_then(|x| x.as_bool()));
    if read.is_none() && star.is_none() { return bad("nothing to change"); }
    if let Err(r) = own(sb, &uid, &b).await { return r; }
    match sb.rpc_msg("fmail_flag", json!({"p_mailbox": b, "p_ids": ids, "p_read": read, "p_star": star})).await { Ok(n) => crate::signed(&st, json!({"ok": true, "changed": n})), Err(e) => pk::sql_err(e) }
}

/// POST /founder/v1/mail/move {box, ids[], to, grant?, nonce?}. Moving a Quarantine / Vault mail back to inbox or archive needs a touch (the database enforces it too).
pub async fn move_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, did) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some(b) = pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)) else { return bad("box is needed") };
    let ids = match ids_of(&j, "ids") { Ok(i) => i, Err(e) => return bad(e) };
    let Some(to) = pk::txt(&j, "to", 16).filter(|t| MOVE_TO.contains(&t.as_str())) else { return bad("invalid target folder") };
    let touch = match touch_of(&j) { Ok(t) => t, Err(e) => return bad(e) };
    if let Err(r) = own(sb, &uid, &b).await { return r; }
    let hash = match &touch { Some(t) => match spend(&st, sb, &uid, &did, t, "mail.unseal", &ids.join(",").chars().take(200).collect::<String>()).await { Ok(h) => Some(h), Err(r) => return r }, None => None };
    match sb.rpc_msg("fmail_move169", json!({"p_actor": uid, "p_mailbox": b, "p_ids": ids, "p_to_kind": to, "p_touch_hash": hash})).await {
        Ok(v) => crate::signed(&st, json!({"ok": true, "result": v})),
        Err((403, m)) | Err((401, m)) | Err((400, m)) if m.contains("touch") => crate::signed(&st, json!({"needs_touch": true, "action": "mail.unseal", "target": ids.join(",").chars().take(200).collect::<String>()})),
        Err(e) => pk::sql_err(e),
    }
}

/// POST /founder/v1/mail/vault {box, thread, vault, grant?, nonce?}. Into the vault: no touch. Out of the vault: touch (action mail.vault_out, target = thread id).
pub async fn vault_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, did) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let (Some(b), Some(t)) = (pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)), pk::txt(&j, "thread", 40).filter(|x| pk::is_uuid(x))) else { return bad("box and thread are needed") };
    let Some(vault) = j.get("vault").and_then(|x| x.as_bool()) else { return bad("vault must be true or false") };
    let touch = match touch_of(&j) { Ok(t) => t, Err(e) => return bad(e) };
    if let Err(r) = own(sb, &uid, &b).await { return r; }
    let hash = match (&touch, vault) {
        (Some(tc), false) => match spend(&st, sb, &uid, &did, tc, "mail.vault_out", &t).await { Ok(h) => Some(h), Err(r) => return r },
        (None, false) => return crate::signed(&st, json!({"needs_touch": true, "action": "mail.vault_out", "target": t})),
        _ => None,
    };
    match sb.rpc_msg("fmail_vault_set169", json!({"p_actor": uid, "p_mailbox": b, "p_thread": t, "p_vault": vault, "p_touch_hash": hash})).await { Ok(v) => crate::signed(&st, json!({"ok": true, "result": v})), Err(e) => pk::sql_err(e) }
}

/// GET /founder/v1/mail/stream?box=<uuid>: Server-Sent Events (the HTTP fallback of the live channel; WebTransport carries the same frames in Q3). One snapshot, then a frame only when the
/// counts, lanes or ledger head CHANGED, plus an `arrival` frame when the inbox grew. Heartbeat 15 s, lifetime 10 min, the browser reconnects with Last-Event-ID.
pub async fn stream_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let b = match parse_box(uri.query()) { Ok(b) => b, Err(e) => return bad(e) };
    let Some(sb) = st.sb.clone() else { return StatusCode::SERVICE_UNAVAILABLE.into_response() };
    if let Err(r) = own(&sb, &c.sub, &b).await { return r; }
    let Some(slot) = live::Slot::take(&live::hub()) else { return (StatusCode::SERVICE_UNAVAILABLE, "too many live streams").into_response() };
    let (tx, rx) = tokio::sync::mpsc::channel::<axum::body::Bytes>(8);
    tokio::spawn(async move {
        let _slot = slot;
        let end = tokio::time::Instant::now() + live::MAX_LIFETIME;
        let (mut last, mut last_inbox, mut first) = (String::new(), -1i64, true);
        let mut poll = tokio::time::interval(std::time::Duration::from_secs(3));
        let mut hb = tokio::time::interval(live::HEARTBEAT);
        hb.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        hb.tick().await;
        loop {
            tokio::select! {
                _ = tokio::time::sleep_until(end) => return,
                _ = tx.closed() => return,
                _ = hb.tick() => { if tx.try_send(axum::body::Bytes::from(": hb\n\n")).is_err() { return; } }
                _ = poll.tick() => {
                    let (counts, feed) = tokio::join!(sb.rpc("fmail_counts169", json!({"p_mailbox": b})), sb.rpc("fmail_bridge_feed", json!({"p_hours": 24})));
                    let (Some(counts), Some(feed)) = (counts, feed) else { continue };
                    let data = json!({"counts": counts, "feed": feed}).to_string();
                    if data == last { continue; }
                    let inbox = counts["inbox"]["total"].as_i64().unwrap_or(0);
                    let seq = feed["ledger_head"].as_i64();
                    let arrived = !first && inbox > last_inbox;
                    let sign = |d: &Value| serde_json::to_string(&crate::envelope(&st, d)).unwrap_or_default();
                    let v: Value = serde_json::from_str(&data).unwrap_or(Value::Null);
                    let frame = live::sse_frame(seq, if first { "snapshot" } else { "counts" }, &sign(&v));
                    if tx.try_send(axum::body::Bytes::from(frame)).is_err() { return; }
                    if arrived && tx.try_send(axum::body::Bytes::from(live::sse_frame(seq, "arrival", &sign(&json!({"inbox_total": inbox, "new": inbox - last_inbox}))))).is_err() { return; }
                    last = data; last_inbox = inbox; first = false;
                }
            }
        }
    });
    let mut res = axum::body::Body::from_stream(live::RxStream(rx)).into_response();
    let hd = res.headers_mut();
    hd.insert(axum::http::header::CONTENT_TYPE, axum::http::HeaderValue::from_static("text/event-stream"));
    hd.insert(axum::http::header::CACHE_CONTROL, axum::http::HeaderValue::from_static("no-store"));
    hd.insert(axum::http::HeaderName::from_static("x-accel-buffering"), axum::http::HeaderValue::from_static("no"));
    res
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fmail_seal as seal;
    const BOX: &str = "0b9d1c2e-0000-4000-8000-000000000001";
    const U1: &str = "11111111-2222-4333-8444-555555555555";
    #[test]
    fn queries_are_whitelisted() {
        assert_eq!(parse_box(Some(&format!("box={BOX}"))).unwrap(), BOX);
        for bad in [None, Some("box=x"), Some("box=1&x=2"), Some("")] { assert!(parse_box(bad).is_err()); }
        let q = parse_list(Some(&format!("box={BOX}&view=vault&limit=9999"))).unwrap(); assert_eq!((q.view.as_str(), q.limit, q.after.is_none()), ("vault", 100, true));
        let q = parse_list(Some(&format!("box={BOX}&ts=2026-11-13T09:41:00.123456Z&id={U1}"))).unwrap(); assert!(q.after.is_some());
        for bad in [format!("box={BOX}&view=drop"), format!("box={BOX}&ts=2026-11-13T09:41:00.123456Z"), format!("box={BOX}&id={U1}"), format!("box={BOX}&ts=x'--&id={U1}"), format!("box={BOX}&evil=1"), format!("view=inbox")] { assert!(parse_list(Some(&bad)).is_err(), "{bad}"); }
        assert_eq!(parse_proof(Some(&format!("box={BOX}"))).unwrap().1, None); assert!(parse_proof(Some(&format!("box={BOX}&id=zz"))).is_err());
    }
    #[test]
    fn bodies_are_checked() {
        assert!(ids_of(&json!({"ids": [U1]}), "ids").is_ok()); assert!(ids_of(&json!({"ids": []}), "ids").is_err()); assert!(ids_of(&json!({"ids": ["x"]}), "ids").is_err());
        assert!(ids_of(&json!({"ids": vec![U1; 101]}), "ids").is_err());
        assert_eq!(touch_of(&json!({})).unwrap(), None); assert!(touch_of(&json!({"grant": U1, "nonce": "abcdefgh12"})).unwrap().is_some());
        for bad in [json!({"grant": U1}), json!({"nonce": "abcdefgh"}), json!({"grant": "x", "nonce": "abcdefgh"}), json!({"grant": U1, "nonce": "short"}), json!({"grant": U1, "nonce": "bad nonce!!"})] { assert!(touch_of(&bad).is_err(), "{bad}"); }
    }
    fn stored(raw: &[u8], mode_gated: bool) -> (Value, [u8; 32]) {
        let m = [9u8; 32]; let s = core::summarize(raw);
        let z = core::seal_message(&m, BOX, "in", core::Wrap::Vault { master: &m, key_id: "vk-1" }, raw, &s).unwrap();
        let e = |b: &[u8]| B64.encode(b);
        (json!({"id": U1, "direction": "in", "seal_mode": "vault", "gated": mode_gated, "read": false, "msgid_blind": hex::encode(z.msgid_blind), "aad_hash": hex::encode(z.aad_hash), "key_id": "vk-1",
                "key_wrap": e(&z.key_wrap), "meta": e(&z.sealed_meta), "nonce_meta": e(&z.nonce_meta), "body": e(&z.sealed_body), "nonce_body": e(&z.nonce_body)}), m)
    }
    #[test]
    fn list_rows_are_opened_here_and_sealed_bytes_never_leave() {
        let raw = b"From: a@b.co\r\nSubject: Clause 7\r\nMessage-ID: <z@b.co>\r\n\r\nhello";
        let (row, m) = stored(raw, false);
        let out = shape_row(Some(&m), BOX, &row);
        assert_eq!(out["sum"]["subject"], "Clause 7");
        for k in SEALED_FIELDS { assert!(out.get(k).is_none(), "{k} must not reach the browser in vault mode"); }
        assert!(out.get("body").is_none() || out["body"].is_null());
        let wrong = shape_row(Some(&[1u8; 32]), BOX, &row); assert_eq!(wrong["broken"], true, "a row that does not verify says so");
        let nomaster = shape_row(None, BOX, &row); assert_eq!(nomaster["broken"], true);
        let (gated, _) = stored(raw, true); let g = shape_row(Some(&m), BOX, &json!({"id": U1, "gated": true, "seal_mode": "vault", "meta": null})); assert!(g.get("sum").is_none()); let _ = gated;
    }
    #[test]
    fn a_post_quantum_row_stays_sealed_for_the_kernel() {
        let row = json!({"id": U1, "gated": false, "seal_mode": "recipient_pq", "meta": "AAAA", "nonce_meta": "AAAA", "key_wrap": "AAAA", "aad_hash": "00", "msgid_blind": "00"});
        let out = shape_row(Some(&[9u8; 32]), BOX, &row); assert!(out.get("sum").is_none() && out["key_wrap"] == "AAAA", "the server does not (and cannot) open it");
    }
    #[test]
    fn a_full_message_opens_with_text_and_attachments_and_a_bad_one_does_not() {
        let raw = b"From: a@b.co\r\nSubject: S\r\nMessage-ID: <q@b.co>\r\nMIME-Version: 1.0\r\nContent-Type: text/html\r\n\r\n<p>Hi <script>x()</script>there</p>";
        let (row, m) = stored(raw, false);
        let o = open_message(&m, BOX, &row).unwrap(); assert_eq!(o["view"]["text"], "Hi there"); assert_eq!(o["view"]["remote_content_blocked"], true); assert_eq!(o["sum"]["subject"], "S");
        assert!(open_message(&[1u8; 32], BOX, &row).is_err()); assert!(open_message(&m, "0b9d1c2e-0000-4000-8000-0000000000ff", &row).is_err(), "another mailbox cannot open it");
        let mut tampered = row.clone(); let mut bytes = B64.decode(tampered["body"].as_str().unwrap()).unwrap(); bytes[3] ^= 1; tampered["body"] = json!(B64.encode(bytes)); assert!(open_message(&m, BOX, &tampered).is_err());
        let _ = seal::new_key();
    }
}
