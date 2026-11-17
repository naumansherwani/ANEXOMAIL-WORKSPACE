//! QC1b (founder mailbox): the SEALED ADDRESS BOOK. Rust (Tokio + axum) over the E186 SQL doors.
//! Technology: AES-256-GCM sealing (fmail_seal, vault wrap) so the database never holds a plain address or display name; ONE exact blind index (HMAC-SHA-256, per-mailbox key derived from
//! the vault master) so the database can answer "is this person already here?" and nothing else; frecency ranking lives in SQL (E186 fmail_contact_score186), the browser filters the opened
//! top 500 (founder-web/src/book.ts), so typing makes ZERO server calls. Research (18 Nov 2026): a blind index cannot do prefix search (an index row per prefix leaks prefix equality and
//! costs ~15 writes per address), big mail clients filter a cached list in the client and rank by how often the address was a recipient (Nylas cookbook), Thunderbird ranks by a counter with no
//! recency (bug 1671679). So: sealed rows + client-side filter + frecency.
//! WHEN a contact is touched: (1) after the sender worker really delivered a mail (process() in fmail_out.rs): every recipient is "sent"; (2) after a real inbound mail was stored in the inbox,
//! scanned clean, passed DMARC, is not a display-name spoof, and is not bulk / list mail: the sender is "received". Never his own domain (the database refuses it too), never a forgotten person
//! when the mail only arrives (the database keeps a blind tombstone). A failure here NEVER costs a mail: it is logged and dropped (the book is a convenience, not a ledger of delivery).
use crate::{fmail_in::bytea, fmail_seal as seal, lease, passkey as pk, S};
use axum::{extract::State, http::{HeaderMap, StatusCode, Uri}, response::{IntoResponse, Response}};
use serde_json::{json, Value};
use std::{collections::HashSet, sync::Mutex};

const AAD_TAG: &str = "fmail-contact-v1";

/// A contact ready for the E186 door: everything sealed or blind, nothing plain.
#[derive(Debug, Clone)]
pub struct SealedContact { pub sealed: Vec<u8>, pub nonce: [u8; 12], pub key_id: String, pub key_wrap: Vec<u8>, pub aad_hash: [u8; 32], pub addr_blind: [u8; 32], pub domain_blind: [u8; 32] }

/// Lower-case ASCII address, or None. Same grammar as fmail_mime::norm_addr / the browser's normAddr (one @, dotted domain, no spaces).
pub fn clean_addr(a: &str) -> Option<String> {
    let s = a.trim().trim_start_matches('<').trim_end_matches('>').trim().to_ascii_lowercase();
    let (l, d) = s.split_once('@')?;
    if l.is_empty() || l.len() > 64 || d.is_empty() || d.len() > 253 || d.contains('@') || !d.contains('.') { return None; }
    if !l.bytes().all(|b| b.is_ascii_alphanumeric() || b"._%+-".contains(&b)) { return None; }
    if !d.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'-') || d.starts_with(['.', '-']) || d.ends_with(['.', '-']) || d.contains("..") { return None; }
    Some(s)
}
pub fn domain_of(addr: &str) -> &str { addr.rsplit_once('@').map(|x| x.1).unwrap_or("") }

/// A display name made safe (same rule as the browser: no control, bidi or zero-width characters, no quotes / angle brackets / backslash, one space, 120 characters).
pub fn clean_name(n: &str) -> String {
    let s: String = n.chars().filter(|c| !matches!(*c, '\u{200b}'..='\u{200f}' | '\u{202a}'..='\u{202e}' | '\u{2066}'..='\u{2069}')).map(|c| if c.is_control() { ' ' } else { c })
        .filter(|c| !matches!(*c, '"' | '<' | '>' | '\\')).collect();
    s.split_whitespace().collect::<Vec<_>>().join(" ").chars().take(120).collect()
}

/// The AAD the sealing is bound to: mailbox + blind index of the address, so a sealed contact cannot be moved to another mailbox or another person's row.
pub fn book_aad(mailbox_id: &str, addr_blind_hex: &str) -> Vec<u8> { seal::aad(&[AAD_TAG, mailbox_id, addr_blind_hex]) }

pub fn addr_blind(master: &seal::Key, mailbox_id: &str, addr: &str) -> Result<[u8; 32], &'static str> { Ok(seal::blind(&seal::blind_key(master, mailbox_id)?, "contact", addr)) }
pub fn domain_blind(master: &seal::Key, mailbox_id: &str, domain: &str) -> Result<[u8; 32], &'static str> { Ok(seal::blind(&seal::blind_key(master, mailbox_id)?, "cdomain", domain)) }
/// One mail counts once per contact: the event key is the blind of (direction, message id, address).
pub fn event_key(master: &seal::Key, mailbox_id: &str, kind: &str, id: &str, addr: &str) -> Result<[u8; 32], &'static str> {
    Ok(seal::blind(&seal::blind_key(master, mailbox_id)?, "cevent", &format!("{kind}|{id}|{addr}")))
}

/// Seal one contact (address + display name) under a fresh key, wrapped with the vault master.
pub fn seal_contact(master: &seal::Key, mailbox_id: &str, key_id: &str, addr: &str, name: &str) -> Result<SealedContact, &'static str> {
    let a = clean_addr(addr).ok_or("not an address")?;
    let ab = addr_blind(master, mailbox_id, &a)?; let db = domain_blind(master, mailbox_id, domain_of(&a))?;
    let aad = book_aad(mailbox_id, &hex::encode(ab));
    let key = seal::new_key()?;
    let plain = serde_json::to_vec(&json!({"a": a, "n": clean_name(name)})).map_err(|_| "json")?;
    let (nonce, sealed) = seal::seal(&key, &aad, &plain)?;
    Ok(SealedContact { sealed, nonce, key_id: key_id.to_string(), key_wrap: seal::wrap_vault(master, key_id, &key)?, aad_hash: seal::aad_hash(&aad), addr_blind: ab, domain_blind: db })
}

/// Open one row of fmail_contacts_top186 (all binary columns are hex text). Checks the stored AAD hash first, then the key wrap, then the seal; None on ANY mismatch, never partial text.
pub fn open_contact(master: &seal::Key, mailbox_id: &str, row: &Value) -> Option<Value> {
    let hx = |k: &str| row.get(k).and_then(|v| v.as_str()).and_then(|s| hex::decode(s).ok());
    let (sealed, nonce, wrap, aadh, blind) = (hx("sealed")?, hx("nonce")?, hx("key_wrap")?, hx("aad_hash")?, row.get("blind")?.as_str()?);
    let aad = book_aad(mailbox_id, blind);
    if seal::aad_hash(&aad).as_slice() != aadh.as_slice() { return None; }
    let key = seal::unwrap_vault(master, row.get("key_id")?.as_str()?, &wrap)?;
    let plain = seal::open(&key, &nonce, &aad, &sealed)?;
    let p: Value = serde_json::from_slice(&plain).ok()?;
    let addr = clean_addr(p.get("a")?.as_str()?)?;
    Some(json!({"id": row.get("id")?, "addr": addr, "name": clean_name(p.get("n").and_then(|x| x.as_str()).unwrap_or("")), "sent": row.get("sent_count")?, "recv": row.get("recv_count")?,
               "last_sent": row.get("last_sent_at").cloned().unwrap_or(Value::Null), "last_recv": row.get("last_recv_at").cloned().unwrap_or(Value::Null), "pinned": row.get("pinned")?, "score": row.get("score").cloned().unwrap_or(Value::Null)}))
}

/// Bulk / list mail never feeds the address book (newsletters, mailing lists, auto replies): List-Id, List-Unsubscribe, Precedence bulk / list / junk, Auto-Submitted other than "no".
pub fn is_bulk(raw: &[u8]) -> bool {
    let head = String::from_utf8_lossy(&raw[..raw.len().min(16 * 1024)]).to_ascii_lowercase();
    let head = head.split("\r\n\r\n").next().unwrap_or("").split("\n\n").next().unwrap_or("");
    head.lines().any(|l| {
        let l = l.trim_end();
        l.starts_with("list-id:") || l.starts_with("list-unsubscribe:") || l.starts_with("x-auto-response-suppress:")
            || (l.starts_with("precedence:") && ["bulk", "list", "junk"].iter().any(|w| l.contains(w)))
            || (l.starts_with("auto-submitted:") && !l.contains(": no"))
    })
}
/// Does this inbound mail deserve a "received" count? Clean scan, DMARC pass, no display-name spoof, no mixed-script sender, not bulk.
pub fn received_ok(scan: &str, ev: &Value, raw: &[u8]) -> bool {
    matches!(scan, "clean" | "skipped") && ev["dmarc_result"] == "pass" && ev["display_spoof"] != json!(true) && ev["mixed_script"] != json!(true) && !is_bulk(raw)
}

static OWN_DONE: Mutex<Option<HashSet<String>>> = Mutex::new(None);
/// Tell the database once per mailbox and process which domain is the founder's own (blind only), so it never stores his own addresses.
async fn ensure_own_domain(sb: &crate::data::Sb, master: &seal::Key, actor: &str, mailbox: &str, address: &str) {
    let key = format!("{mailbox}|{address}");
    if OWN_DONE.lock().ok().and_then(|g| g.as_ref().map(|s| s.contains(&key))).unwrap_or(false) { return; }
    let Ok(db) = domain_blind(master, mailbox, &domain_of(address).to_ascii_lowercase()) else { return };
    if sb.rpc_msg("fmail_contact_own_domain186", json!({"p_actor": actor, "p_mailbox": mailbox, "p_domain_blind": bytea(&db)})).await.is_ok() {
        if let Ok(mut g) = OWN_DONE.lock() { g.get_or_insert_with(HashSet::new).insert(key); }
    }
}

/// The founder (owner) of a mailbox: intake knows only the mailbox, the E186 door wants the actor.
pub async fn owner_of(sb: &crate::data::Sb, mailbox: &str) -> Option<String> {
    if !pk::is_uuid(mailbox) { return None; }
    sb.rows(&format!("fmail_mailboxes?select=owner&id=eq.{mailbox}&limit=1")).await.and_then(|r| r.into_iter().next()).and_then(|r| r["owner"].as_str().map(|x| x.to_string()))
}
/// Count one person. `kind` = "sent" | "received", `id` = the message / outbox id (so a retry counts once). Errors are logged, never returned (the book must not cost a mail).
pub async fn touch(sb: &crate::data::Sb, master: &seal::Key, actor: &str, mailbox: &str, own_address: &str, key_id: &str, kind: &str, id: &str, addr: &str, name: &str) {
    let Some(a) = clean_addr(addr) else { return };
    if a == own_address.to_ascii_lowercase() { return; }
    ensure_own_domain(sb, master, actor, mailbox, own_address).await;
    let (Ok(sc), Ok(ev)) = (seal_contact(master, mailbox, key_id, &a, name), event_key(master, mailbox, kind, id, &a)) else { return };
    let body = json!({"p_actor": actor, "p_mailbox": mailbox, "p_addr_blind": bytea(&sc.addr_blind), "p_domain_blind": bytea(&sc.domain_blind), "p_direction": kind,
        "p_sealed": bytea(&sc.sealed), "p_nonce": bytea(&sc.nonce), "p_key_id": sc.key_id, "p_key_wrap": bytea(&sc.key_wrap), "p_aad_hash": bytea(&sc.aad_hash), "p_event": bytea(&ev)});
    match tokio::time::timeout(std::time::Duration::from_secs(8), sb.rpc_msg("fmail_contact_touch186", body)).await {
        Ok(Ok(_)) => {}
        Ok(Err((c, m))) => eprintln!("founder: address book touch refused ({c}): {}", m.chars().take(120).collect::<String>()),
        Err(_) => eprintln!("founder: address book touch timed out"),
    }
}
/// Display names of a raw message's To / Cc / From headers: address -> name (the sender worker uses it for recipients, intake for the sender).
pub fn names_of(raw: &[u8]) -> std::collections::HashMap<String, String> {
    let mut out = std::collections::HashMap::new();
    let Some(m) = mail_parser::MessageParser::default().parse(raw) else { return out };
    for list in [m.from(), m.to(), m.cc()].into_iter().flatten() {
        for a in list.iter() { if let (Some(ad), Some(n)) = (a.address(), a.name()) { if let Some(c) = clean_addr(ad) { out.entry(c).or_insert_with(|| clean_name(n)); } } }
    }
    out
}

// ---------------------------------------------------------------- HTTP doors
fn bad(e: &str) -> Response { pk::refuse(StatusCode::BAD_REQUEST, e) }
async fn own(sb: &crate::data::Sb, uid: &str, mailbox: &str) -> Result<(), Response> {
    let v = sb.rpc("fmail_mailboxes169", json!({"p_uid": uid})).await.ok_or_else(|| pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "mail database not answering - run the E186 SQL step (sql-run.sh)"))?;
    if v.as_array().map(|a| a.iter().any(|m| m["id"] == mailbox && m["status"] == "active")).unwrap_or(false) { Ok(()) } else { Err(pk::refuse(StatusCode::NOT_FOUND, "no such mailbox")) }
}

/// GET /founder/v1/mail/contacts?box=<uuid> : the top 500 contacts by frecency, opened here (vault master) and handed to the browser over the signed channel; the browser filters while typing.
pub async fn top_ep(State(st): State<S>, uri: Uri, h: HeaderMap) -> Response {
    let c = match crate::authed(&st, &h).await { Ok(c) => c, Err(e) => return e.into_response() };
    let b = match crate::fmail_ep::parse_box(uri.query()) { Ok(b) => b, Err(e) => return bad(e) };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    if let Err(r) = own(sb, &c.sub, &b).await { return r; }
    let Some(master) = lease::MASTER.get() else { return pk::refuse(StatusCode::SERVICE_UNAVAILABLE, "the vault master key is not loaded") };
    let call = sb.rpc_msg("fmail_contacts_top186", json!({"p_actor": c.sub, "p_mailbox": b, "p_limit": 500}));
    match tokio::time::timeout(std::time::Duration::from_secs(8), call).await {
        Err(_) => pk::refuse(StatusCode::GATEWAY_TIMEOUT, "the database did not answer in time"),
        Ok(Err(e)) => pk::sql_err(e),
        Ok(Ok(v)) => {
            let items: Vec<Value> = v["items"].as_array().map(|a| a.iter().filter_map(|r| open_contact(master, &b, r)).collect()).unwrap_or_default();
            let skipped = v["returned"].as_u64().unwrap_or(0).saturating_sub(items.len() as u64);
            crate::signed(&st, json!({"ok": true, "total": v["total"], "truncated": v["truncated"], "skipped": skipped, "items": items}))
        }
    }
}

/// POST /founder/v1/mail/contact {box, contact, op: "forget" | "pin" | "unpin"}. No touch needed (it only changes suggestions, nothing leaves).
pub async fn act_ep(State(st): State<S>, uri: Uri, h: HeaderMap, body: axum::body::Bytes) -> Response {
    let (uid, _e, _d) = match pk::ctx(&st, &h, uri.path(), &body, true).await { Ok(x) => x, Err(r) => return r };
    let sb = match pk::sbx(&st) { Ok(s) => s, Err(r) => return r };
    let j = match pk::body_json(&body) { Ok(j) => j, Err(r) => return r };
    let (Some(b), Some(cid)) = (pk::txt(&j, "box", 40).filter(|x| pk::is_uuid(x)), pk::txt(&j, "contact", 40).filter(|x| pk::is_uuid(x))) else { return bad("box and contact are needed") };
    let op = pk::txt(&j, "op", 10).unwrap_or_default();
    if let Err(r) = own(sb, &uid, &b).await { return r; }
    let call = match op.as_str() {
        "forget" => sb.rpc_msg("fmail_contact_forget186", json!({"p_actor": uid, "p_mailbox": b, "p_contact": cid})),
        "pin" | "unpin" => sb.rpc_msg("fmail_contact_pin186", json!({"p_actor": uid, "p_mailbox": b, "p_contact": cid, "p_pinned": op == "pin"})),
        _ => return bad("op is forget, pin or unpin"),
    };
    match tokio::time::timeout(std::time::Duration::from_secs(8), call).await {
        Err(_) => pk::refuse(StatusCode::GATEWAY_TIMEOUT, "the database did not answer in time"),
        Ok(Ok(v)) => crate::signed(&st, json!({"ok": true, "result": v})),
        Ok(Err(e)) => pk::sql_err(e),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn master() -> seal::Key { [9u8; 32] }
    fn row_of(sc: &SealedContact, id: &str, blind: &str) -> Value {
        json!({"id": id, "sealed": hex::encode(&sc.sealed), "nonce": hex::encode(sc.nonce), "key_id": sc.key_id, "key_wrap": hex::encode(&sc.key_wrap), "aad_hash": hex::encode(sc.aad_hash), "blind": blind,
               "sent_count": 3, "recv_count": 1, "last_sent_at": null, "last_recv_at": null, "pinned": false, "score": 2.3})
    }
    #[test] fn addresses_are_normalised_like_the_browser() {
        assert_eq!(clean_addr(" <Ali@Example.COM> ").as_deref(), Some("ali@example.com"));
        for bad in ["", "a@b", "a@@b.com", "@b.com", "a b@c.com", "a@-b.com", "a@b..com", "ali@exa mple.com", "ünï@b.com"] { assert!(clean_addr(bad).is_none(), "{bad}"); }
    }
    #[test] fn names_are_cleaned() {
        assert_eq!(clean_name("  \"Zoya\"  <Khan>\u{202e}\n\tX  "), "Zoya Khan X");
        assert_eq!(clean_name(&"x".repeat(500)).chars().count(), 120);
    }
    #[test] fn seal_then_open_roundtrip_and_nothing_plain_is_in_the_blob() {
        let m = master(); let mb = "11111111-1111-1111-1111-111111111111";
        let sc = seal_contact(&m, mb, "vault-1", "Zoya@Idn.pk", "Zoya Khan").unwrap();
        assert!(!String::from_utf8_lossy(&sc.sealed).contains("zoya") && !String::from_utf8_lossy(&sc.sealed).contains("Zoya"));
        let o = open_contact(&m, mb, &row_of(&sc, "22222222-2222-2222-2222-222222222222", &hex::encode(sc.addr_blind))).unwrap();
        assert_eq!(o["addr"], "zoya@idn.pk"); assert_eq!(o["name"], "Zoya Khan"); assert_eq!(o["sent"], 3);
    }
    #[test] fn a_sealed_contact_cannot_be_moved_to_another_mailbox_or_person() {
        let m = master(); let sc = seal_contact(&m, "mb-a", "vault-1", "a@b.com", "A").unwrap(); let blind = hex::encode(sc.addr_blind);
        assert!(open_contact(&m, "mb-b", &row_of(&sc, "i", &blind)).is_none(), "another mailbox");
        assert!(open_contact(&m, "mb-a", &row_of(&sc, "i", &hex::encode(addr_blind(&m, "mb-a", "x@y.com").unwrap()))).is_none(), "another person's blind");
        assert!(open_contact(&[1u8; 32], "mb-a", &row_of(&sc, "i", &blind)).is_none(), "another master key");
        let mut r = row_of(&sc, "i", &blind); let mut s = hex::decode(r["sealed"].as_str().unwrap()).unwrap(); s[0] ^= 1; r["sealed"] = json!(hex::encode(s));
        assert!(open_contact(&m, "mb-a", &r).is_none(), "a flipped bit");
    }
    #[test] fn blind_indexes_are_stable_case_free_and_separated() {
        let m = master();
        assert_eq!(addr_blind(&m, "mb", "a@b.com").unwrap(), addr_blind(&m, "mb", "a@b.com").unwrap());
        assert_ne!(addr_blind(&m, "mb", "a@b.com").unwrap(), addr_blind(&m, "mb2", "a@b.com").unwrap());
        assert_ne!(addr_blind(&m, "mb", "b.com").unwrap(), domain_blind(&m, "mb", "b.com").unwrap(), "address and domain spaces never meet");
        assert_ne!(event_key(&m, "mb", "sent", "1", "a@b.com").unwrap(), event_key(&m, "mb", "received", "1", "a@b.com").unwrap());
    }
    #[test] fn bulk_and_list_mail_is_recognised() {
        assert!(is_bulk(b"From: a@b.com\r\nList-Unsubscribe: <mailto:x@y.z>\r\n\r\nbody"));
        assert!(is_bulk(b"From: a@b.com\r\nPrecedence: bulk\r\n\r\nbody"));
        assert!(is_bulk(b"From: a@b.com\r\nAuto-Submitted: auto-replied\r\n\r\nbody"));
        assert!(!is_bulk(b"From: a@b.com\r\nAuto-Submitted: no\r\nSubject: hi\r\n\r\nList-Id: in the body does not count"));
        assert!(!is_bulk(b"From: a@b.com\r\nSubject: hello\r\n\r\nbody"));
    }
    #[test] fn only_clean_authenticated_personal_mail_counts_as_received() {
        let ok = json!({"dmarc_result": "pass", "display_spoof": false, "mixed_script": false}); let raw = b"From: a@b.com\r\n\r\nhi";
        assert!(received_ok("clean", &ok, raw)); assert!(received_ok("skipped", &ok, raw));
        assert!(!received_ok("infected", &ok, raw) && !received_ok("opaque", &ok, raw));
        assert!(!received_ok("clean", &json!({"dmarc_result": "fail"}), raw));
        assert!(!received_ok("clean", &json!({"dmarc_result": "pass", "display_spoof": true}), raw));
        assert!(!received_ok("clean", &json!({"dmarc_result": "pass", "mixed_script": true}), raw));
    }
    #[test] fn names_come_out_of_the_headers() {
        let n = names_of(b"From: \"Zoya Khan\" <Zoya@idn.pk>\r\nTo: Ali <ali@x.com>, bare@y.org\r\n\r\nhi");
        assert_eq!(n.get("zoya@idn.pk").map(|s| s.as_str()), Some("Zoya Khan")); assert_eq!(n.get("ali@x.com").map(|s| s.as_str()), Some("Ali")); assert!(!n.contains_key("bare@y.org"));
    }
}
