// CONTROL PLANE answer.rs (D5a-3b): the answer is signed with the Control Plane's OWN Ed25519 key (domain anexo-control-answer-v1); the Desk kernel refuses anything else.
use crate::verify::{allowed, hex, unhex, Req, ANS_DOMAIN};
use ed25519_dalek::{Signer as _, SigningKey};
use serde_json::{json, Map, Value};
use sha2::{Digest, Sha256};

pub struct Signer(SigningKey);
impl Signer {
    pub fn from_seed_hex(s: &str) -> Option<Signer> { unhex(s.trim()).and_then(|b| <[u8; 32]>::try_from(b).ok()).map(|b| Signer(SigningKey::from_bytes(&b))) }
    pub fn public_hex(&self) -> String { hex(self.0.verifying_key().as_bytes()) }
    fn kid(&self) -> String { hex(&Sha256::digest(self.0.verifying_key().as_bytes()))[..16].to_string() }
    fn envelope(&self, body: Value) -> String {
        let body = body.to_string();
        json!({"kid": self.kid(), "body": body, "sig": hex(&self.0.sign(format!("{ANS_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    /// Unknown company (database returned nothing): refused. Otherwise ONLY the requested whitelist fields; a field the database does not hold is null (honest, never guessed).
    pub fn answer(&self, r: &Req, found: Option<&Value>, now: i64) -> String {
        let (fields, refused) = match found {
            None => (Map::new(), true),
            Some(row) => { let ok = allowed(); let mut m = Map::new(); for f in &r.fields { if ok.contains(f) { m.insert(f.clone(), row.get(f).cloned().unwrap_or(Value::Null)); } } (m, false) }
        };
        self.envelope(json!({"request_id": r.request_id, "company_ref": r.company, "answered_at": now, "fields": fields, "refused": refused}))
    }
}

impl Signer {
    /// Phase 1m-4 B9: the signed CENSUS answer (counts only). kind "census" keeps it from ever being read as a company answer; a database that returned nothing = refused (never a made-up number).
    /// Phase 1m-5 B6: the signed deliverability answer (kind "deliverability"); None = refused.
    pub fn deliv_answer(&self, request_id: &str, d: Option<&Value>, now: i64) -> String {
        self.envelope(json!({"kind": "deliverability", "request_id": request_id, "answered_at": now, "deliverability": d.cloned().unwrap_or(Value::Null), "refused": d.is_none()}))
    }
    /// Phase 1m Z4b B13: the signed consent answer. kind "consent" + the method, so it can never be read as another answer; None = refused (the database refused the shape or the facts).
    pub fn consent_answer(&self, request_id: &str, method: &str, result: Option<&Value>, now: i64) -> String {
        self.envelope(json!({"kind": "consent", "method": method, "request_id": request_id, "answered_at": now, "result": result.cloned().unwrap_or(Value::Null), "refused": result.is_none()}))
    }
    /// Phase 1m B13 T3b: the signed sender-resolve answer. kind "resolve" keeps it from ever being read as another answer; the result is exactly {verdict, tenant} from cp.resolve_sender; None = refused (the database refused the shape).
    pub fn resolve_answer(&self, request_id: &str, result: Option<&Value>, now: i64) -> String {
        self.envelope(json!({"kind": "resolve", "request_id": request_id, "answered_at": now, "result": result.cloned().unwrap_or(Value::Null), "refused": result.is_none()}))
    }
    /// Phase 1m B13 T4e: the signed tenant-exists answer. kind "tenant" keeps it from ever being read as another answer; the result is exactly {exists, name} from cp.tenant_info; None = refused (the database refused the shape).
    pub fn tenant_answer(&self, request_id: &str, result: Option<&Value>, now: i64) -> String {
        self.envelope(json!({"kind": "tenant", "request_id": request_id, "answered_at": now, "result": result.cloned().unwrap_or(Value::Null), "refused": result.is_none()}))
    }
    pub fn census_answer(&self, request_id: &str, census: Option<&Value>, now: i64) -> String {
        self.envelope(json!({"kind": "census", "request_id": request_id, "answered_at": now, "census": census.cloned().unwrap_or(Value::Null), "refused": census.is_none()}))
    }
}

#[cfg(test)]
mod t {
    use super::*;
    fn req(f: &[&str]) -> Req { Req { request_id: "11111111-2222-4333-8444-555555555555".into(), company: "acme-1234".into(), fields: f.iter().map(|x| x.to_string()).collect() } }
    #[test] fn answer_has_only_requested_fields_and_nulls_for_unknown() {
        let s = Signer::from_seed_hex(&"07".repeat(32)).unwrap();
        let row = json!({"service_state": "active", "usage_seats": 4, "package_id": "pro", "surprise": 1});
        let e: Value = serde_json::from_str(&s.answer(&req(&["service_state", "limit_seats"]), Some(&row), 1000)).unwrap();
        let b: Value = serde_json::from_str(e["body"].as_str().unwrap()).unwrap();
        assert_eq!(b["fields"], json!({"service_state": "active", "limit_seats": null})); assert_eq!(b["refused"], false);
        assert!(b["fields"].get("usage_seats").is_none() && b["fields"].get("surprise").is_none());
    }
    #[test] fn unknown_company_is_refused_with_no_fields() {
        let s = Signer::from_seed_hex(&"07".repeat(32)).unwrap();
        let e: Value = serde_json::from_str(&s.answer(&req(&["service_state"]), None, 1000)).unwrap();
        let b: Value = serde_json::from_str(e["body"].as_str().unwrap()).unwrap(); assert_eq!(b["refused"], true); assert_eq!(b["fields"], json!({}));
    }
    #[test] fn bad_seed_is_none() { assert!(Signer::from_seed_hex("zz").is_none()); assert!(Signer::from_seed_hex("00").is_none()); }
}
