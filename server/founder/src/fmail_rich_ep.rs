//! QC2 (founder mailbox): SEALED SIGNATURES + SNIPPETS. Rust (Tokio + axum) over the E194 SQL doors, with the pure rules of fmail_rich.
//! Technology: AES-256-GCM sealing (fmail_seal, vault wrap) so the database never holds a plain From address, signature text, snippet name or snippet text; ONE exact blind index per row
//! (HMAC-SHA-256, per-mailbox key from the vault master) so the database can answer "is this one already here?" and nothing else. The AAD binds every sealed value to its mailbox AND its blind index,
//! so a sealed signature can not be moved to another mailbox or another From address. All lists are opened HERE (vault master) and handed to the browser over the signed channel (HTTP/3 + kernel RPC);
//! the browser fills variables and builds the HTML. A signature is TEXT ONLY (lines and plain links), no HTML is stored. Writes are signed (passkey session, ctx(write = true)), no touch needed:
//! nothing leaves the mailbox until a mail is sent, and that send has its own touch.
use crate::{fmail_in::bytea, fmail_rich as rich, fmail_seal as seal, lease, passkey as pk, S};
use axum::{extract::State, http::{HeaderMap, StatusCode, Uri}, response::{IntoResponse, Response}};
use serde_json::{json, Value};

const SIG_TAG: &str = "fmail-signature-v1";
const SNIP_TAG: &str = "fmail-snippet-v1";

/// A sealed row ready for an E194 door: everything sealed or blind, nothing plain.
#[derive(Debug, Clone)]
pub struct Sealed { pub sealed: Vec<u8>, pub nonce: [u8; 12], pub key_id: String, pub key_wrap: Vec<u8>, pub aad_hash: [u8; 32], pub blind: [u8; 32] }

pub fn sig_aad(mailbox_id: &str, blind_hex: &str) -> Vec<u8> { seal::aad(&[SIG_TAG, mailbox_id, blind_hex]) }
pub fn snip_aad(mailbox_id: &str, blind_hex: &str) -> Vec<u8> { seal::aad(&[SNIP_TAG, mailbox_id, blind_hex]) }

fn seal_json(master: &seal::Key, key_id: &str, aad: &[u8], plain: &Value, blind: [u8; 32]) -> Result<Sealed, &'static str> {
    let key = seal::new_key()?;
    let (nonce, sealed) = seal::seal(&key, aad, &serde_json::to_vec(plain).map_err(|_| "json")?)?;
    Ok(Sealed { sealed, nonce, key_id: key_id.to_string(), key_wrap: seal::wrap_vault(master, key_id, &key)?, aad_hash: seal::aad_hash(aad), blind })
}

/// Seal one signature: the From address it belongs to + its text. Address must be a valid mailbox-style address (same grammar as fmail_mime).
pub fn seal_signature(master: &seal::Key, mailbox_id: &str, key_id: &str, from: &str, text: &str) -> Result<Sealed, &'static str> {
    let a = crate::fmail_mime::norm_addr(from).ok_or("the From address is not valid")?;
    let t = rich::clean_text(text, rich::MAX_SIGNATURE)?;
    if t.is_empty() { return Err("a signature needs some text"); }
    let blind = seal::blind(&seal::blind_key(master, mailbox_id)?, "sigfrom", &a);
    seal_json(master, key_id, &sig_aad(mailbox_id, &hex::encode(blind)), &json!({"a": a, "t": t}), blind)
}

/// Seal one snippet: its name + text.
pub fn seal_snippet(master: &seal::Key, mailbox_id: &str, key_id: &str, name: &str, text: &str) -> Result<Sealed, &'static str> {
    let n = rich::clean_name(name).ok_or("a snippet name is 1 to 40 letters, digits, - or _")?;
    let t = rich::clean_text(text, rich::MAX_SNIPPET)?;
    if t.is_empty() { return Err("a snippet needs some text"); }
    let blind = seal::blind(&seal::blind_key(master, mailbox_id)?, "snipname", &n);
    seal_json(master, key_id, &snip_aad(mailbox_id, &hex::encode(blind)), &json!({"n": n, "t": t}), blind)
}

/// Open one row of a list door (all binary columns are hex text). Checks the stored AAD hash first, then the key wrap, then the seal; None on ANY mismatch, never partial text.
fn open_row(master: &seal::Key, mailbox_id: &str, row: &Value, tag: &str) -> Option<Value> {
    let hx = |k: &str| row.get(k).and_then(|v| v.as_str()).and_then(|s| hex::decode(s).ok());
    let (sealed, nonce, wrap, aadh, blind) = (hx("sealed")?, hx("nonce")?, hx("key_wrap")?, hx("aad_hash")?, row.get("blind")?.as_str()?);
    let aad = seal::aad(&[tag, mailbox_id, blind]);
    if seal::aad_hash(&aad).as_slice() != aadh.as_slice() { return None; }
    let key = seal::unwrap_vault(master, row.get("key_id")?.as_str()?, &wrap)?;
    let plain = seal::open(&key, &nonce, &aad, &sealed)?;
    serde_json::from_slice(&plain).ok()
}

/// A signature row opened: {id, from, text, fallback, version}. The From address is checked against the same grammar again.
pub fn open_signature(master: &seal::Key, mailbox_id: &str, row: &Value) -> Option<Value> {
    let p = open_row(master, mailbox_id, row, SIG_TAG)?;
    let from = crate::fmail_mime::norm_addr(p.get("a")?.as_str()?)?;
    Some(json!({"id": row.get("id")?, "from": from, "text": p.get("t")?.as_str()?, "fallback": row.get("is_fallback")?, "version": row.get("version")?}))
}
/// A snippet row opened: {id, name, text, used, last_used, version, vars} where vars = the placeholders found in the text (so the screen knows what to ask before it sends).
pub fn open_snippet(master: &seal::Key, mailbox_id: &str, row: &Value) -> Option<Value> {
    let p = open_row(master, mailbox_id, row, SNIP_TAG)?;
    let name = rich::clean_name(p.get("n")?.as_str()?)?; let text = p.get("t")?.as_str()?;
    Some(json!({"id": row.get("id")?, "name": name, "text": text, "used": row.get("use_count")?, "last_used": row.get("last_used_at").cloned().unwrap_or(Value::Null),
               "version": row.get("version")?, "vars": rich::placeholders(text)}))
}

fn bad(e: &str) -> Response { pk::refuse(StatusCode::BAD_REQUEST, e) }
/// The mailbox must be the caller's and active; returns its vault key id (the column the engine seals under), "vault-1" when the row does not say.
async fn own(sb: &crate::data::Sb, uid: &str, mailbox: &str) -> Result<String, Response> {
    let v = sb.rpc("fmail_mailboxes169", json!({"p_uid": uid})).await.ok_or_else(|| pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "mail database not answering - run the E194 SQL step (sql-run.sh)"))?;
    let m = v.as_array().and_then(|a| a.iter().find(|m| m["id"] == mailbox && m["status"] == "active")).ok_or_else(|| pk::refuse(StatusCode::NOT_FOUND, "no such mailbox"))?;
    Ok(m["vault_key_id"].as_str().filter(|s| !s.is_empty()).unwrap_or("vault-1").to_string())
}
async fn call(call: impl std::future::Future<Output = Result<Value, (u16, String)>>) -> Result<Value, Response> {
    match tokio::time::timeout(std::time::Duration::from_secs(8), call).await {
        Err(_) => Err(pk::refuse(StatusCode::GATEWAY_TIMEOUT, "the database did not answer in time")),
        Ok(Err(e)) => Err(pk::sql_err(e)),
        Ok(Ok(v)) => Ok(v),
    }
}

/// GET /founder/v1/mail/signatures?box=<uuid> : every signature of the mailbox, opened here and handed over the signed channel.
pub async fn sigs_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let b = match crate::fmail_ep::parse_box(uri.query()) { Ok(b) => b, Err(e) => return bad(e) };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    if let Err(r) = own(sb, &c.sub, &b).await { return r; }
    let Some(master) = lease::MASTER.get() else { return pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "the vault master key is not loaded") };
    match call(sb.rpc_msg("fmail_signatures_list194", json!({"p_actor": c.sub, "p_mailbox": b}))).await {
        Err(r) => r,
        Ok(v) => {
            let items: Vec<Value> = v["items"].as_array().map(|a| a.iter().filter_map(|r| open_signature(master, &b, r)).collect()).unwrap_or_default();
            let skipped = v["returned"].as_u64().unwrap_or(0).saturating_sub(items.len() as u64);
            crate::signed(&st, json!({"ok": true, "skipped": skipped, "items": items}))
        }
    }
}

/// POST /founder/v1/mail/signature {box, op: "put" | "clear", from, text, fallback} | {box, op: "clear", id}.
pub async fn sig_act_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some(b) = pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)) else { return bad("box is needed") };
    let kid = match own(sb, &uid, &b).await { Ok(k) => k, Err(r) => return r };
    let Some(master) = lease::MASTER.get() else { return pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "the vault master key is not loaded") };
    let r = match pk::txt(&j, "op", 10).unwrap_or_default().as_str() {
        "put" => {
            let (Some(from), Some(text)) = (pk::txt(&j, "from", 320), pk::txt(&j, "text", rich::MAX_SIGNATURE * 4)) else { return bad("from and text are needed") };
            let s = match seal_signature(master, &b, &kid, &from, &text) { Ok(s) => s, Err(e) => return bad(e) };
            call(sb.rpc_msg("fmail_signature_put194", json!({"p_actor": uid, "p_mailbox": b, "p_from_blind": bytea(&s.blind), "p_sealed": bytea(&s.sealed), "p_nonce": bytea(&s.nonce),
                "p_key_id": s.key_id, "p_key_wrap": bytea(&s.key_wrap), "p_aad_hash": bytea(&s.aad_hash), "p_fallback": j.get("fallback").and_then(|x| x.as_bool()).unwrap_or(false)}))).await
        }
        "clear" => {
            let Some(id) = pk::txt(&j, "id", 40).filter(|x| pk::is_uuid(x)) else { return bad("id is needed") };
            call(sb.rpc_msg("fmail_signature_clear194", json!({"p_actor": uid, "p_mailbox": b, "p_signature": id}))).await
        }
        _ => return bad("op is put or clear"),
    };
    match r { Ok(v) => crate::signed(&st, json!({"ok": true, "result": v})), Err(r) => r }
}

/// GET /founder/v1/mail/snippets?box=<uuid> : every snippet of the mailbox, opened here (most used first).
pub async fn snips_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let b = match crate::fmail_ep::parse_box(uri.query()) { Ok(b) => b, Err(e) => return bad(e) };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    if let Err(r) = own(sb, &c.sub, &b).await { return r; }
    let Some(master) = lease::MASTER.get() else { return pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "the vault master key is not loaded") };
    match call(sb.rpc_msg("fmail_snippets_list194", json!({"p_actor": c.sub, "p_mailbox": b}))).await {
        Err(r) => r,
        Ok(v) => {
            let items: Vec<Value> = v["items"].as_array().map(|a| a.iter().filter_map(|r| open_snippet(master, &b, r)).collect()).unwrap_or_default();
            let skipped = v["returned"].as_u64().unwrap_or(0).saturating_sub(items.len() as u64);
            crate::signed(&st, json!({"ok": true, "total": v["total"], "skipped": skipped, "items": items}))
        }
    }
}

/// POST /founder/v1/mail/snippet {box, op: "put", name, text} | {box, op: "delete" | "used", id}.
pub async fn snip_act_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let Some(b) = pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)) else { return bad("box is needed") };
    let kid = match own(sb, &uid, &b).await { Ok(k) => k, Err(r) => return r };
    let Some(master) = lease::MASTER.get() else { return pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "the vault master key is not loaded") };
    let id = pk::txt(&j, "id", 40).filter(|x| pk::is_uuid(x));
    let r = match pk::txt(&j, "op", 10).unwrap_or_default().as_str() {
        "put" => {
            let (Some(name), Some(text)) = (pk::txt(&j, "name", 80), pk::txt(&j, "text", rich::MAX_SNIPPET * 4)) else { return bad("name and text are needed") };
            let s = match seal_snippet(master, &b, &kid, &name, &text) { Ok(s) => s, Err(e) => return bad(e) };
            call(sb.rpc_msg("fmail_snippet_put194", json!({"p_actor": uid, "p_mailbox": b, "p_name_blind": bytea(&s.blind), "p_sealed": bytea(&s.sealed), "p_nonce": bytea(&s.nonce),
                "p_key_id": s.key_id, "p_key_wrap": bytea(&s.key_wrap), "p_aad_hash": bytea(&s.aad_hash)}))).await
        }
        "delete" => { let Some(id) = id else { return bad("id is needed") }; call(sb.rpc_msg("fmail_snippet_delete194", json!({"p_actor": uid, "p_mailbox": b, "p_snippet": id}))).await }
        "used" => { let Some(id) = id else { return bad("id is needed") }; call(sb.rpc_msg("fmail_snippet_used194", json!({"p_actor": uid, "p_mailbox": b, "p_snippet": id}))).await }
        _ => return bad("op is put, delete or used"),
    };
    match r { Ok(v) => crate::signed(&st, json!({"ok": true, "result": v})), Err(r) => r }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn master() -> seal::Key { [7u8; 32] }
    fn row_of(s: &Sealed, id: &str) -> Value {
        json!({"id": id, "sealed": hex::encode(&s.sealed), "nonce": hex::encode(s.nonce), "key_id": s.key_id, "key_wrap": hex::encode(&s.key_wrap), "aad_hash": hex::encode(s.aad_hash),
               "blind": hex::encode(s.blind), "is_fallback": true, "version": 1, "use_count": 2, "last_used_at": null})
    }
    #[test] fn a_signature_seals_and_opens_and_nothing_plain_is_in_the_blob() {
        let m = master(); let s = seal_signature(&m, "mb-1", "vault-1", "Me@Idn.pk", "Nauman\nhttps://idn.pk").unwrap();
        assert!(!s.sealed.windows(5).any(|w| w == b"Nauma") && !s.sealed.windows(6).any(|w| w == b"idn.pk"));
        let o = open_signature(&m, "mb-1", &row_of(&s, "id-1")).unwrap();
        assert_eq!(o["from"], "me@idn.pk"); assert_eq!(o["text"], "Nauman\nhttps://idn.pk"); assert_eq!(o["fallback"], true);
    }
    #[test] fn a_sealed_signature_cannot_be_moved_to_another_mailbox_or_address() {
        let m = master(); let s = seal_signature(&m, "mb-1", "vault-1", "me@idn.pk", "Hi").unwrap();
        assert!(open_signature(&m, "mb-2", &row_of(&s, "x")).is_none());
        let mut r = row_of(&s, "x"); r["blind"] = json!(hex::encode([9u8; 32])); assert!(open_signature(&m, "mb-1", &r).is_none());
        assert!(open_signature(&[8u8; 32], "mb-1", &row_of(&s, "x")).is_none());
    }
    #[test] fn a_tampered_blob_never_opens() {
        let m = master(); let s = seal_snippet(&m, "mb-1", "vault-1", "Thanks", "Thank you {first_name}").unwrap();
        let mut r = row_of(&s, "x"); let mut b = s.sealed.clone(); b[0] ^= 1; r["sealed"] = json!(hex::encode(b)); assert!(open_snippet(&m, "mb-1", &r).is_none());
    }
    #[test] fn a_signature_row_cannot_be_opened_as_a_snippet_and_the_reverse() {
        let m = master(); let s = seal_signature(&m, "mb-1", "vault-1", "me@idn.pk", "Hi").unwrap(); let n = seal_snippet(&m, "mb-1", "vault-1", "hi", "Hi").unwrap();
        assert!(open_snippet(&m, "mb-1", &row_of(&s, "x")).is_none()); assert!(open_signature(&m, "mb-1", &row_of(&n, "x")).is_none());
    }
    #[test] fn a_snippet_opens_with_its_name_text_and_placeholders() {
        let m = master(); let s = seal_snippet(&m, "mb-1", "vault-1", " /Thanks ", "Thanks {first_name}, see you {date} re {deal}").unwrap();
        let o = open_snippet(&m, "mb-1", &row_of(&s, "id-9")).unwrap();
        assert_eq!(o["name"], "thanks"); assert_eq!(o["vars"], json!(["first_name", "date", "deal"])); assert_eq!(o["used"], 2);
    }
    #[test] fn blinds_are_stable_case_free_and_separated_by_kind_and_mailbox() {
        let m = master();
        let a = seal_snippet(&m, "mb-1", "k", "Thanks", "x").unwrap().blind; let b = seal_snippet(&m, "mb-1", "k", "thanks", "y").unwrap().blind; assert_eq!(a, b);
        let c = seal_signature(&m, "mb-1", "k", "thanks@x.com", "x").unwrap().blind; assert_ne!(a, c);
        assert_ne!(a, seal_snippet(&m, "mb-2", "k", "thanks", "x").unwrap().blind);
    }
    #[test] fn refusals() {
        let m = master();
        assert!(seal_signature(&m, "mb", "k", "not an address", "x").is_err()); assert!(seal_signature(&m, "mb", "k", "a@b.com", "  \n ").is_err());
        assert!(seal_signature(&m, "mb", "k", "a@b.com", &"x".repeat(rich::MAX_SIGNATURE + 1)).is_err());
        assert!(seal_snippet(&m, "mb", "k", "bad name", "x").is_err()); assert!(seal_snippet(&m, "mb", "k", "ok", "a\u{202e}b").is_err());
        assert!(seal_snippet(&m, "mb", "k", "ok", &"x".repeat(rich::MAX_SNIPPET + 1)).is_err());
    }
}
