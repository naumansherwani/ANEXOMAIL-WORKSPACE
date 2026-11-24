// ANEXOMAIL ADMIN DESK resolve_cp.rs (BL-46 B13 step T3a/T3b, 24 Nov 2026): the Desk's PURE reading of a Control Plane "resolve sender" answer (SQL AD31, cp.resolve_sender). Rust + Tokio side, Rule 52: this module only ever sees an answer that the signed-envelope check (consent_cp::accept style) already verified; it then reads it STRICTLY.
// Shape is closed: exactly {verdict, tenant}; verdict is one of six words; a tenant UUID exists exactly when the verdict is "resolved". Anything else = Reject::Unavailable (fail closed). The Desk then calls desk.fadm_case_bind (AD30) with source verified_domain, and only for "resolved".
// T3b adds the wire side (24 Nov 2026): build_resolve (signed request, audience desk-resolve, 60 s), accept_resolve (the answer must be signed by the Control Plane's own key, kind "resolve", same request id, fresh 15 s, not older than the request, closed shape), resolve_sender (HTTP/3 over the shared client, TLS 1.3 AES-256-GCM + X25519MLKEM768) and the end-to-end `resolve-selftest`. A refusal or any fault is never a company. The sender address is never logged or stored: the Desk keeps the verdict word and the tenant UUID only.
use crate::lookup::{ANS_DOMAIN, EXPIRY, FRESH, REQ_DOMAIN};
use crate::sign::{unhex, Signer};
use serde_json::{json, Value};
pub use crate::consent_cp::Reject;

pub const AUD_RESOLVE: &str = "desk-resolve";
pub const RESOLVE_PATH: &str = "/control/v1/resolve";

pub const VERDICTS: [&str; 6] = ["resolved", "shared", "unknown", "ambiguous", "multi_member", "unaligned"];

#[derive(Debug, PartialEq, Clone)]
pub enum Verdict { Resolved(String), Pending(&'static str) }

fn uuid_ok(s: &str) -> bool { s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_digit() || (b'a'..=b'f').contains(&b) }) }

/// Read one verified resolve answer. Err = the Desk treats the case as unresolved and shows "Not available".
pub fn read(r: &Value) -> Result<Verdict, ()> {
    let m = r.as_object().ok_or(())?;
    if m.len() != 2 || !m.contains_key("verdict") || !m.contains_key("tenant") { return Err(()); }
    let w = r["verdict"].as_str().and_then(|v| VERDICTS.iter().find(|x| **x == v)).ok_or(())?;
    match (*w, &r["tenant"]) {
        ("resolved", Value::String(t)) if uuid_ok(t) => Ok(Verdict::Resolved(t.clone())),
        ("resolved", _) => Err(()),
        (_, Value::Null) => Ok(Verdict::Pending(w)),
        _ => Err(()),
    }
}


/// Same shapes as the Control Plane door (control-plane/src/resolve.rs): refuse here what it would refuse there, before anything is sent.
pub fn domain_ok(s: &str) -> bool {
    s.len() >= 3 && s.len() <= 253 && s.contains('.') && s.split('.').all(|l| (1..=63).contains(&l.len()) && !l.starts_with('-') && !l.ends_with('-') && l.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-'))
}
pub fn local_ok(s: &str) -> bool { (1..=64).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || matches!(b, b'.' | b'_' | b'+' | b'-')) }

pub fn build_resolve(s: &Signer, rid: &str, employee: &str, domain: &str, local: &str, aligned: bool, now: i64) -> String {
    let body = json!({"aud": AUD_RESOLVE, "method": "resolve", "request_id": rid, "employee_id": employee, "path": RESOLVE_PATH, "domain": domain, "local": local, "aligned": aligned, "issued_at": now, "expires_at": now + EXPIRY}).to_string();
    let sig = s.sign_raw(format!("{REQ_DOMAIN}\n{body}").as_bytes());
    json!({"kid": s.kid(), "body": body, "sig": sig}).to_string()
}

/// Verify the Control Plane answer to ONE resolve request. Refused (the database said no) is its own outcome; every other fault is Unavailable.
pub fn accept_resolve(env: &str, cp_pub_hex: &str, request_id: &str, issued: i64, now: i64) -> Result<Verdict, Reject> {
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};
    let e: Value = serde_json::from_str(env).map_err(|_| Reject::Unavailable)?;
    let body = e["body"].as_str().ok_or(Reject::Unavailable)?;
    let sig = unhex(e["sig"].as_str().ok_or(Reject::Unavailable)?).ok_or(Reject::Unavailable)?;
    let vk = unhex(cp_pub_hex).and_then(|b| <[u8; 32]>::try_from(b).ok()).and_then(|b| VerifyingKey::from_bytes(&b).ok()).ok_or(Reject::Unavailable)?;
    let sig = Signature::from_slice(&sig).map_err(|_| Reject::Unavailable)?;
    vk.verify(format!("{ANS_DOMAIN}\n{body}").as_bytes(), &sig).map_err(|_| Reject::Unavailable)?;
    let b: Value = serde_json::from_str(body).map_err(|_| Reject::Unavailable)?;
    if b["kind"].as_str() != Some("resolve") || b["request_id"].as_str() != Some(request_id) { return Err(Reject::Unavailable); }
    let at = b["answered_at"].as_i64().ok_or(Reject::Unavailable)?;
    if at > now + 5 || now - at > FRESH || at < issued - 2 { return Err(Reject::Unavailable); }
    match b["refused"].as_bool() { Some(true) => return Err(Reject::Refused), Some(false) => {}, None => return Err(Reject::Unavailable) }
    read(&b["result"]).map_err(|_| Reject::Unavailable)
}

/// The call itself with a request id chosen by the caller: sign, send over HTTP/3, verify. Any fault = Unavailable.
async fn call(p: &crate::lookup::Plane, s: &Signer, cp_pub_hex: &str, employee: &str, rid: &str, domain: &str, local: &str, aligned: bool, now: i64) -> Result<Verdict, Reject> {
    let env = build_resolve(s, rid, employee, domain, local, aligned, now);
    let ans = p.ask_path(RESOLVE_PATH, &env).await.ok_or(Reject::Unavailable)?;
    accept_resolve(&ans, cp_pub_hex, rid, now, crate::signed::now_secs())
}
/// The whole call without the ledger (used by the selftest): validate, sign, send, verify. Bad input = Refused before anything leaves the Desk.
pub(crate) async fn resolve_sender(p: &crate::lookup::Plane, s: &Signer, cp_pub_hex: &str, employee: &str, domain: &str, local: &str, aligned: bool, now: i64) -> Result<Verdict, Reject> {
    if !domain_ok(domain) || !local_ok(local) { return Err(Reject::Refused); }
    call(p, s, cp_pub_hex, employee, &crate::lookup::uuid4(), domain, local, aligned, now).await
}

/// The ledger report of ONE attempt (AD32 desk.fadm_resolve_log): case ref, request id, closed outcome, verdict word, tenant UUID. There is no place in it for an address or a domain (OWASP Logging: no personal data in the log).
#[allow(dead_code)] // T3c (Folder 2 mail door) is the caller; the report builder is tested here
pub fn log_sql(case_ref: &str, rid: &str, res: &Result<Verdict, Reject>, invalid: bool) -> String {
    let q = |s: &str| format!("'{}'", s.replace('\'', "''"));
    let (outcome, verdict, tenant) = match (invalid, res) {
        (true, _) => ("invalid", "null".to_string(), "null".to_string()),
        (_, Ok(Verdict::Resolved(t))) => ("answered", q("resolved"), format!("{}::uuid", q(t))),
        (_, Ok(Verdict::Pending(w))) => ("answered", q(w), "null".to_string()),
        (_, Err(Reject::Refused)) => ("refused", "null".to_string(), "null".to_string()),
        (_, Err(Reject::Unavailable)) => ("unavailable", "null".to_string(), "null".to_string()),
    };
    format!("select desk.fadm_resolve_log({}, {}::uuid, {}, {}::text, {})::text", q(case_ref), q(rid), q(outcome), verdict, tenant)
}

/// AD33 closed answer words of the apply door (the SQL list is the Rust list, tested).
pub const APPLY_WORDS: [&str; 5] = ["bound", "already_bound", "not_resolved", "no_attempt", "refused"];
/// The apply call (AD33 desk.fadm_case_apply_resolution): ONE case ref in, ONE closed word out. It carries no address, no domain and no tenant: the tenant comes from the newest verified answer already in the Desk ledger.
pub fn apply_sql(case_ref: &str) -> String { format!("select desk.fadm_case_apply_resolution('{}')::text", case_ref.replace('\'', "''")) }
/// Reads the apply answer: only a word of the closed list counts, anything else is fail closed ("refused").
pub fn apply_word(raw: Option<&str>) -> &'static str { raw.and_then(|w| APPLY_WORDS.iter().find(|x| **x == w).copied()).unwrap_or("refused") }

/// ONE attempt for ONE case, with its ledger line (T3c calls this with the sender the Folder 2 mail door hands over). Order: validate, sign, ask over HTTP/3, verify, THEN write the ledger report. If the report cannot be written the verdict is NOT used (Unavailable): no attempt without a line. Binding is not done here.
#[allow(dead_code)] // T3c wires the door that calls this with the sender
pub(crate) async fn resolve_and_log(c: &tokio_postgres::Client, p: &crate::lookup::Plane, s: &Signer, cp_pub_hex: &str, employee: &str, case_ref: &str, domain: &str, local: &str, aligned: bool, now: i64) -> Result<Verdict, Reject> {
    let rid = crate::lookup::uuid4();
    let invalid = !domain_ok(domain) || !local_ok(local);
    let res = if invalid { Err(Reject::Refused) } else { call(p, s, cp_pub_hex, employee, &rid, domain, local, aligned, now).await };
    let wrote = crate::door::rows(c, &log_sql(case_ref, &rid, &res, invalid)).await.ok().and_then(|v| v.first().and_then(|r| r.get(0).map(|x| x == "true"))).unwrap_or(false);
    if !wrote { eprintln!("desk resolve: the attempt could not be written to the ledger: the verdict is not used"); return Err(Reject::Unavailable); }
    // T3c: a verified, resolved verdict is applied to the case by the ONE SQL door (AD33); it re-reads the NEWEST attempt itself, so nothing the caller says can bind a case
    if matches!(res, Ok(Verdict::Resolved(_))) {
        let w = crate::door::rows(c, &apply_sql(case_ref)).await.ok().and_then(|v| v.first().and_then(|r| r.get(0).map(|x| x.to_string())));
        eprintln!("desk resolve: apply {}", apply_word(w.as_deref()));
    }
    res
}

/// `anexomail-desk resolve-selftest`: the real end-to-end proof on his server (no login): Desk key -> HTTP/3 -> Control Plane -> read-only database function cp.resolve_sender -> signed answer -> Desk verifies.
/// Proves: an unowned domain = unknown; a shared provider = shared; an unaligned sender = unaligned; the SAME request again is refused (replay); the answer checked against a WRONG key is refused; bad input never leaves the Desk.
pub async fn selftest() -> Result<String, String> {
    crate::signed::init();
    let Some(s) = crate::signed::signer() else { return Err("Desk signing key not loaded".into()) };
    let p = crate::lookup::plane(); if matches!(p, crate::lookup::Plane::Off) { return Err("DESK_CONTROL_PLANE_ADDR / _HOST are not set".into()); }
    let key = crate::lookup::cp_pub(); let now = crate::signed::now_secs();
    let mut seen: Vec<String> = Vec::new();
    for (d, l, a, want) in [("selftest-nobody-owns-this.example", "ann", true, "unknown"), ("gmail.com", "ann", true, "shared"), ("selftest-nobody-owns-this.example", "ann", false, "unaligned")] {
        match resolve_sender(&p, s, &key, "selftest", d, l, a, now).await { Ok(Verdict::Pending(w)) if w == want => seen.push(w.to_string()), Ok(v) => return Err(format!("unexpected verdict {v:?} (wanted {want})")), Err(e) => return Err(format!("{want} probe failed: {e:?}")) }
    }
    let rid = crate::lookup::uuid4(); let env = build_resolve(s, &rid, "selftest", "selftest-nobody-owns-this.example", "ann", true, now);
    let ans = p.ask_path(RESOLVE_PATH, &env).await.ok_or("no answer over HTTP/3 (Control Plane down, certificate not trusted, or request refused)")?;
    accept_resolve(&ans, &key, &rid, now, crate::signed::now_secs()).map_err(|e| format!("answer not accepted: {e:?}"))?;
    if p.ask_path(RESOLVE_PATH, &env).await.is_some() { return Err("REPLAY WAS ANSWERED (must be refused)".into()); }
    if accept_resolve(&ans, &crate::sign::hex(&[9u8; 32]), &rid, now, crate::signed::now_secs()).is_ok() { return Err("answer accepted under a wrong key".into()); }
    if resolve_sender(&p, s, &key, "selftest", "Bad Domain", "ann", true, now).await != Err(Reject::Refused) { return Err("bad input was not refused inside the Desk".into()); }
    Ok(format!("RESOLVE SELFTEST OK: signed verdicts verified ({}), replay refused, wrong key refused, bad input never leaves the Desk", seen.join(", ")))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    const T: &str = "3f2b8c1e-5a4d-4e7a-9c1b-0a1b2c3d4e5f";
    #[test] fn resolved_needs_a_uuid() {
        assert_eq!(read(&json!({"verdict": "resolved", "tenant": T})), Ok(Verdict::Resolved(T.to_string())));
        assert!(read(&json!({"verdict": "resolved", "tenant": null})).is_err());
        assert!(read(&json!({"verdict": "resolved", "tenant": "acme"})).is_err());
    }
    #[test] fn every_other_word_has_no_tenant() {
        for w in ["shared", "unknown", "ambiguous", "multi_member", "unaligned"] {
            assert!(matches!(read(&json!({"verdict": w, "tenant": null})), Ok(Verdict::Pending(x)) if x == w));
            assert!(read(&json!({"verdict": w, "tenant": T})).is_err(), "{w} must never carry a tenant");
        }
    }
    #[test] fn unknown_words_and_shapes_fail_closed() {
        assert!(read(&json!({"verdict": "maybe", "tenant": null})).is_err());
        assert!(read(&json!({"verdict": "resolved", "tenant": T, "name": "Acme"})).is_err());
        assert!(read(&json!({"verdict": "resolved"})).is_err());
        assert!(read(&json!("resolved")).is_err());
        assert!(read(&json!(null)).is_err());
    }
    #[test] fn the_word_list_is_the_sql_word_list() {
        let sql = include_str!("../../sql/AD31.sql");
        for w in VERDICTS { assert!(sql.contains(&format!("'{w}'")), "{w} missing in AD31"); }
    }
    #[test] fn the_request_is_signed_for_desk_resolve_and_expires_in_60_s() {
        let s = Signer::from_seed_hex(&"03".repeat(32)).unwrap();
        let e: Value = serde_json::from_str(&build_resolve(&s, "11111111-2222-4333-8444-555555555555", "e1", "acme.example", "ann", true, 1000)).unwrap();
        let b: Value = serde_json::from_str(e["body"].as_str().unwrap()).unwrap();
        assert_eq!((b["aud"].as_str(), b["method"].as_str(), b["domain"].as_str(), b["local"].as_str(), b["aligned"].as_bool(), b["expires_at"].as_i64().unwrap() - b["issued_at"].as_i64().unwrap()), (Some(AUD_RESOLVE), Some("resolve"), Some("acme.example"), Some("ann"), Some(true), 60));
        assert_eq!(b["path"].as_str(), Some(RESOLVE_PATH), "the request is signed for its own path");
        assert_eq!(b.as_object().unwrap().len(), 10, "closed field list: no tenant, no company, nothing the Desk could use to choose");
    }
    fn ans(k: &ed25519_dalek::SigningKey, rid: &str, at: i64, result: Value, refused: bool, kind: &str) -> String {
        use ed25519_dalek::Signer as _; let body = json!({"kind": kind, "request_id": rid, "answered_at": at, "result": result, "refused": refused}).to_string();
        json!({"body": body, "sig": crate::sign::hex(&k.sign(format!("{ANS_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    #[test] fn a_good_answer_is_accepted_and_every_fault_fails_closed() {
        let k = ed25519_dalek::SigningKey::from_bytes(&[7u8; 32]); let p = crate::sign::hex(k.verifying_key().as_bytes()); const RID: &str = "11111111-2222-4333-8444-555555555555";
        assert_eq!(accept_resolve(&ans(&k, RID, 1010, json!({"verdict": "resolved", "tenant": T}), false, "resolve"), &p, RID, 1000, 1012), Ok(Verdict::Resolved(T.to_string())));
        assert_eq!(accept_resolve(&ans(&k, RID, 1010, json!({"verdict": "unknown", "tenant": null}), false, "resolve"), &p, RID, 1000, 1012), Ok(Verdict::Pending("unknown")));
        let bad = |e: String, rid: &str, iss: i64, now: i64| accept_resolve(&e, &p, rid, iss, now);
        assert_eq!(bad(ans(&k, RID, 1010, Value::Null, true, "resolve"), RID, 1000, 1012), Err(Reject::Refused));
        let u = Err(Reject::Unavailable);
        assert_eq!(bad(ans(&k, RID, 1010, json!({"verdict": "unknown", "tenant": null}), false, "consent"), RID, 1000, 1012), u, "a consent answer is not a resolve answer");
        assert_eq!(bad(ans(&k, RID, 1010, json!({"verdict": "unknown", "tenant": null}), false, "resolve"), "22222222-2222-4333-8444-555555555555", 1000, 1012), u, "another request id");
        assert_eq!(bad(ans(&k, RID, 1010, json!({"verdict": "unknown", "tenant": null}), false, "resolve"), RID, 1000, 1100), u, "stale (older than 15 s)");
        assert_eq!(bad(ans(&k, RID, 990, json!({"verdict": "unknown", "tenant": null}), false, "resolve"), RID, 1000, 1002), u, "older than the request");
        assert_eq!(bad(ans(&k, RID, 1030, json!({"verdict": "unknown", "tenant": null}), false, "resolve"), RID, 1000, 1002), u, "from the future");
        assert_eq!(bad(ans(&k, RID, 1010, json!({"verdict": "maybe", "tenant": null}), false, "resolve"), RID, 1000, 1012), u, "a word outside the closed list");
        assert_eq!(bad(ans(&k, RID, 1010, json!({"verdict": "resolved", "tenant": null}), false, "resolve"), RID, 1000, 1012), u, "resolved without a tenant");
        assert_eq!(bad(ans(&k, RID, 1010, json!({"verdict": "unknown", "tenant": T}), false, "resolve"), RID, 1000, 1012), u, "a tenant on a non-resolved word");
        let other = ed25519_dalek::SigningKey::from_bytes(&[8u8; 32]); assert_eq!(bad(ans(&other, RID, 1010, json!({"verdict": "unknown", "tenant": null}), false, "resolve"), RID, 1000, 1012), u, "signed by another key");
        assert_eq!(bad("not json".into(), RID, 1000, 1012), u);
        let mut tampered: Value = serde_json::from_str(&ans(&k, RID, 1010, json!({"verdict": "unknown", "tenant": null}), false, "resolve")).unwrap(); tampered["body"] = json!(tampered["body"].as_str().unwrap().replace("unknown", "resolved")); assert_eq!(bad(tampered.to_string(), RID, 1000, 1012), u, "a changed body breaks the signature");
    }
    #[test] fn bad_input_never_leaves_the_desk_and_the_shapes_match_the_control_plane() {
        assert!(domain_ok("acme.example") && !domain_ok("Acme.example") && !domain_ok("localhost") && !domain_ok("a b.example"));
        assert!(local_ok("ann") && local_ok("a.b+tag") && !local_ok("Ann") && !local_ok("a@b") && !local_ok(""));
        let cp = include_str!("../../../../../control-plane/src/resolve.rs");
        for needle in ["b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-'", "matches!(b, b'.' | b'_' | b'+' | b'-')", "(1..=63).contains(&l.len())", "(1..=64).contains(&s.len())", "AUD_RESOLVE: &str = \"desk-resolve\"", "SIGNED_PATH: &str = \"/control/v1/resolve\""] { assert!(cp.contains(needle), "the Control Plane door must keep the same rule: {needle}"); }
    }
    #[test] fn the_ledger_report_has_no_place_for_an_address_and_maps_every_outcome() {
        const RID: &str = "11111111-2222-4333-8444-555555555555";
        let sql = |r: Result<Verdict, Reject>, inv: bool| log_sql("C-000036", RID, &r, inv);
        assert_eq!(sql(Ok(Verdict::Resolved(T.to_string())), false), format!("select desk.fadm_resolve_log('C-000036', '{RID}'::uuid, 'answered', 'resolved'::text, '{T}'::uuid)::text"));
        assert_eq!(sql(Ok(Verdict::Pending("shared")), false), format!("select desk.fadm_resolve_log('C-000036', '{RID}'::uuid, 'answered', 'shared'::text, null)::text"));
        assert_eq!(sql(Err(Reject::Refused), false), format!("select desk.fadm_resolve_log('C-000036', '{RID}'::uuid, 'refused', null::text, null)::text"));
        assert_eq!(sql(Err(Reject::Unavailable), false), format!("select desk.fadm_resolve_log('C-000036', '{RID}'::uuid, 'unavailable', null::text, null)::text"));
        assert_eq!(sql(Err(Reject::Refused), true), format!("select desk.fadm_resolve_log('C-000036', '{RID}'::uuid, 'invalid', null::text, null)::text"), "bad input is its own outcome");
        assert!(!log_sql("C-0'1", RID, &Err(Reject::Unavailable), false).contains("C-0'1"), "a quote in the case ref is escaped");
        let ad32 = include_str!("../../sql/AD32.sql");
        for w in ["'answered'", "'unavailable'", "'refused'", "'invalid'", "p_case text, p_request uuid, p_outcome text, p_verdict text, p_tenant uuid"] { assert!(ad32.contains(w), "{w} must match AD32"); }
    }
    #[test] fn the_apply_door_has_one_argument_and_a_closed_word_list_that_is_the_sql_list() {
        assert_eq!(apply_sql("C-000036"), "select desk.fadm_case_apply_resolution('C-000036')::text");
        assert!(!apply_sql("C-0'1").contains("C-0'1"), "a quote in the case ref is escaped");
        for w in APPLY_WORDS { assert_eq!(apply_word(Some(w)), w); }
        for bad in ["bind", "BOUND", "", "bound ", "true"] { assert_eq!(apply_word(Some(bad)), "refused", "{bad:?} is not a word of the list: fail closed"); }
        assert_eq!(apply_word(None), "refused");
        let ad33 = include_str!("../../sql/AD33.sql");
        for w in APPLY_WORDS { assert!(ad33.contains(&format!("'{w}'")), "{w} missing in AD33"); }
        assert!(ad33.contains("fadm_case_apply_resolution(p_case text)") && !ad33.contains("p_tenant"), "the door takes a case ref only: no tenant can be handed in");
    }
}
