// CONTROL PLANE core.rs (D5a-3b): request in -> verified -> database (read-only function) -> signed answer out. Fail closed at every step.
use crate::{answer::Signer, db::Pg, verify::{verify, Seen}};
#[cfg(test)] use serde_json::Value;
use std::{collections::HashMap, sync::Mutex};

pub enum Source { Pg(Pg), #[cfg(test)] Fixed(Option<Value>), #[cfg(test)] Down }
pub struct Core { pub desk_pub: String, pub signer: Signer, pub seen: Seen, pub src: Source, rate: Mutex<(i64, u32)>, census_cache: Mutex<HashMap<String, (i64, serde_json::Value)>> }
pub const CENSUS_CACHE_SECS: i64 = 60;
const CENSUS_CACHE_CAP: usize = 16;
const PER_SECOND: u32 = 50;

impl Core {
    pub fn new(desk_pub: String, signer: Signer, src: Source, boot: i64) -> Core { Core { desk_pub, signer, seen: Seen::new(boot), src, rate: Mutex::new((0, 0)), census_cache: Mutex::new(HashMap::new()) } }
    fn allow(&self, now: i64) -> bool { let mut r = self.rate.lock().unwrap_or_else(|e| e.into_inner()); if r.0 != now { *r = (now, 0); } r.1 += 1; r.1 <= PER_SECOND }
    /// (HTTP status, body). 200 signed answer (refused:true inside for an unknown company) / 403 bad request (no reason given back) / 429 too many / 503 database down.
    pub async fn handle(&self, body: &str, now: i64) -> (u16, String) {
        if !self.allow(now) { return (429, String::new()); }
        let req = match verify(body, &self.desk_pub, &self.seen, now) { Ok(r) => r, Err(why) => { eprintln!("control plane: request refused ({why})"); return (403, String::new()); } };
        let found = match &self.src {
            Source::Pg(p) => p.lookup(&req.company).await,
            #[cfg(test)] Source::Fixed(v) => Ok(v.clone()),
            #[cfg(test)] Source::Down => Err("down".to_string()),
        };
        match found { Ok(row) => (200, self.signer.answer(&req, row.as_ref(), now)), Err(e) => { eprintln!("control plane: database unavailable ({e})"); (503, String::new()) } }
    }
    /// Phase 1m-5 B6: deliverability. Same order: rate, verify (own audience desk-deliv, no input), ONE read-only function, cached 60 s, signed answer. 200 signed / 403 / 429 / 503.
    pub async fn handle_deliv(&self, body: &str, now: i64) -> (u16, String) {
        if !self.allow(now) { return (429, String::new()); }
        let req = match crate::census::verify_deliv(body, &self.desk_pub, &self.seen, now) { Ok(r) => r, Err(why) => { eprintln!("control plane: deliverability request refused ({why})"); return (403, String::new()); } };
        let key = "deliverability".to_string();
        if let Some((at, v)) = self.census_cache.lock().unwrap_or_else(|e| e.into_inner()).get(&key) { if now - *at < CENSUS_CACHE_SECS && now >= *at { return (200, self.signer.deliv_answer(&req.request_id, Some(v), now)); } }
        let found = match &self.src {
            Source::Pg(p) => p.deliverability().await,
            #[cfg(test)] Source::Fixed(v) => Ok(v.clone()),
            #[cfg(test)] Source::Down => Err("down".to_string()),
        };
        match found {
            Ok(Some(v)) => {
                { let mut c = self.census_cache.lock().unwrap_or_else(|e| e.into_inner()); if c.len() >= CENSUS_CACHE_CAP { c.retain(|_, (at, _)| now - *at < CENSUS_CACHE_SECS); } if c.len() < CENSUS_CACHE_CAP { c.insert(key, (now, v.clone())); } }
                (200, self.signer.deliv_answer(&req.request_id, Some(&v), now))
            }
            Ok(None) => (200, self.signer.deliv_answer(&req.request_id, None, now)),
            Err(e) => { eprintln!("control plane: database unavailable ({e})"); (503, String::new()) }
        }
    }
    /// Phase 1m Z4b B13: consent. Order: rate, verify (own audience desk-consent, closed methods push|cancel|poll), ONE database door (never cached: a decision must show at once), signed answer. No decide method exists. 200 signed / 403 / 429 / 503 (database down = request stays waiting, never approved).
    pub async fn handle_consent(&self, body: &str, now: i64) -> (u16, String) {
        if !self.allow(now) { return (429, String::new()); }
        let req = match crate::consent::verify_consent(body, &self.desk_pub, &self.seen, now) { Ok(r) => r, Err(why) => { eprintln!("control plane: consent request refused ({why})"); return (403, String::new()); } };
        let method = match &req.call { crate::consent::Call::Push { .. } => "push", crate::consent::Call::Cancel { .. } => "cancel", crate::consent::Call::Poll { .. } => "poll" };
        let found = match &self.src {
            Source::Pg(p) => p.consent(&req.call).await,
            #[cfg(test)] Source::Fixed(v) => Ok(v.clone()),
            #[cfg(test)] Source::Down => Err("down".to_string()),
        };
        match found { Ok(v) => (200, self.signer.consent_answer(&req.request_id, method, v.as_ref(), now)), Err(e) => { eprintln!("control plane: database unavailable ({e})"); (503, String::new()) } }
    }
    /// Phase 1m B13 T3b: sender resolve. Order: rate, verify (own audience desk-resolve, one closed method), ONE read-only database function (never cached: a membership change must show at once), signed answer. 200 signed / 403 / 429 / 503.
    pub async fn handle_resolve(&self, body: &str, now: i64) -> (u16, String) {
        if !self.allow(now) { return (429, String::new()); }
        let req = match crate::resolve::verify_resolve(body, &self.desk_pub, &self.seen, now) { Ok(r) => r, Err(why) => { eprintln!("control plane: resolve request refused ({why})"); return (403, String::new()); } };
        let found = match &self.src {
            Source::Pg(p) => p.resolve(&req.domain, &req.local, req.aligned).await,
            #[cfg(test)] Source::Fixed(v) => Ok(v.clone()),
            #[cfg(test)] Source::Down => Err("down".to_string()),
        };
        match found { Ok(v) => (200, self.signer.resolve_answer(&req.request_id, v.as_ref(), now)), Err(e) => { eprintln!("control plane: database unavailable ({e})"); (503, String::new()) } }
    }
    /// Phase 1m B13 T4e: tenant exists + display name. Order: rate, verify (own audience desk-tenant, one closed method), ONE read-only database function (never cached), signed answer. 200 signed / 403 / 429 / 503.
    pub async fn handle_tenant(&self, body: &str, now: i64) -> (u16, String) {
        if !self.allow(now) { return (429, String::new()); }
        let req = match crate::tenant::verify_tenant(body, &self.desk_pub, &self.seen, now) { Ok(r) => r, Err(why) => { eprintln!("control plane: tenant request refused ({why})"); return (403, String::new()); } };
        let found = match &self.src {
            Source::Pg(p) => p.tenant(&req.tenant).await,
            #[cfg(test)] Source::Fixed(v) => Ok(v.clone()),
            #[cfg(test)] Source::Down => Err("down".to_string()),
        };
        match found { Ok(v) => (200, self.signer.tenant_answer(&req.request_id, v.as_ref(), now)), Err(e) => { eprintln!("control plane: database unavailable ({e})"); (503, String::new()) } }
    }
    /// Phase 1m-4 B9: the census. Same order as a lookup: rate, verify (own audience desk-census), then ONE read-only function; the result is cached 60 s per seat-promise set; signed answer out. 200 signed / 403 / 429 / 503.
    pub async fn handle_census(&self, body: &str, now: i64) -> (u16, String) {
        if !self.allow(now) { return (429, String::new()); }
        let req = match crate::census::verify_census(body, &self.desk_pub, &self.seen, now) { Ok(r) => r, Err(why) => { eprintln!("control plane: census request refused ({why})"); return (403, String::new()); } };
        let key = req.limits.to_string();
        if let Some((at, v)) = self.census_cache.lock().unwrap_or_else(|e| e.into_inner()).get(&key) { if now - *at < CENSUS_CACHE_SECS && now >= *at { return (200, self.signer.census_answer(&req.request_id, Some(v), now)); } }
        let found = match &self.src {
            Source::Pg(p) => p.census(&req.limits).await,
            #[cfg(test)] Source::Fixed(v) => Ok(v.clone()),
            #[cfg(test)] Source::Down => Err("down".to_string()),
        };
        match found {
            Ok(Some(v)) => {
                { let mut c = self.census_cache.lock().unwrap_or_else(|e| e.into_inner()); if c.len() >= CENSUS_CACHE_CAP { c.retain(|_, (at, _)| now - *at < CENSUS_CACHE_SECS); } if c.len() < CENSUS_CACHE_CAP { c.insert(key, (now, v.clone())); } }
                (200, self.signer.census_answer(&req.request_id, Some(&v), now))
            }
            Ok(None) => (200, self.signer.census_answer(&req.request_id, None, now)),
            Err(e) => { eprintln!("control plane: database unavailable ({e})"); (503, String::new()) }
        }
    }
}

#[cfg(test)]
mod t {
    use super::*; use crate::verify::{hex, REQ_DOMAIN}; use ed25519_dalek::{Signer as _, SigningKey}; use serde_json::json;
    fn core(src: Source) -> (Core, SigningKey) { let d = SigningKey::from_bytes(&[3u8; 32]); (Core::new(hex(d.verifying_key().as_bytes()), Signer::from_seed_hex(&"07".repeat(32)).unwrap(), src, 0), d) }
    fn env(k: &SigningKey, rid: &str) -> String {
        let body = json!({"aud":"desk-lookup","method":"read","request_id":rid,"employee_id":"e1","company_ref":"acme-1234","reason":"customer says mail is missing","requested_fields":["service_state","usage_seats"],"issued_at":1000,"expires_at":1060}).to_string();
        json!({"kid":"x","body":body,"sig":hex(&k.sign(format!("{REQ_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    #[tokio::test] async fn full_flow_good_replay_unknown_down_and_rate() {
        let (c, d) = core(Source::Fixed(Some(json!({"service_state":"active","usage_seats":4}))));
        let (s, a) = c.handle(&env(&d, "aaaaaaaa-0000-4000-8000-000000000001"), 1010).await; assert_eq!(s, 200);
        let b: Value = serde_json::from_str(serde_json::from_str::<Value>(&a).unwrap()["body"].as_str().unwrap()).unwrap(); assert_eq!(b["fields"]["usage_seats"], 4);
        assert_eq!(c.handle(&env(&d, "aaaaaaaa-0000-4000-8000-000000000001"), 1010).await.0, 403, "replay");
        assert_eq!(c.handle("garbage", 1010).await.0, 403);
        let (c2, d2) = core(Source::Fixed(None)); let (s, a) = c2.handle(&env(&d2, "aaaaaaaa-0000-4000-8000-000000000002"), 1010).await; assert_eq!(s, 200);
        let b: Value = serde_json::from_str(serde_json::from_str::<Value>(&a).unwrap()["body"].as_str().unwrap()).unwrap(); assert_eq!(b["refused"], true);
        let (c3, d3) = core(Source::Down); assert_eq!(c3.handle(&env(&d3, "aaaaaaaa-0000-4000-8000-000000000003"), 1010).await.0, 503);
        let (c4, _) = core(Source::Down); let mut last = 0; for _ in 0..60 { last = c4.handle("x", 1010).await.0; } assert_eq!(last, 429);
    }
}

#[cfg(test)]
mod census_t {
    use super::*; use crate::verify::{hex, REQ_DOMAIN}; use ed25519_dalek::{Signer as _, SigningKey}; use serde_json::json;
    fn core(src: Source) -> (Core, SigningKey) { let d = SigningKey::from_bytes(&[3u8; 32]); (Core::new(hex(d.verifying_key().as_bytes()), Signer::from_seed_hex(&"07".repeat(32)).unwrap(), src, 0), d) }
    fn env(k: &SigningKey, rid: &str, limits: Value) -> String {
        let body = json!({"aud":"desk-census","method":"read","request_id":rid,"employee_id":"e1","reason":"customers and plans board opened","limits":limits,"issued_at":1000,"expires_at":1060}).to_string();
        json!({"kid":"x","body":body,"sig":hex(&k.sign(format!("{REQ_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    fn body(a: &str) -> Value { serde_json::from_str(serde_json::from_str::<Value>(a).unwrap()["body"].as_str().unwrap()).unwrap() }
    #[tokio::test] async fn census_flow_good_replay_refused_down_cache_and_rate() {
        let (c, d) = core(Source::Fixed(Some(json!({"companies": 7}))));
        let (s, a) = c.handle_census(&env(&d, "aaaaaaaa-0000-4000-8000-000000000001", json!({"basic": 5})), 1010).await; assert_eq!(s, 200);
        let b = body(&a); assert_eq!((b["kind"].as_str(), b["refused"].as_bool(), b["census"]["companies"].as_i64()), (Some("census"), Some(false), Some(7)));
        assert_eq!(c.handle_census(&env(&d, "aaaaaaaa-0000-4000-8000-000000000001", json!({"basic": 5})), 1010).await.0, 403, "replay");
        assert_eq!(c.handle_census("garbage", 1010).await.0, 403);
        // same limits, new request id, inside 60 s: served from the cache, answered_at is fresh
        let (s, a) = c.handle_census(&env(&d, "aaaaaaaa-0000-4000-8000-000000000002", json!({"basic": 5})), 1030).await; assert_eq!(s, 200); assert_eq!(body(&a)["answered_at"], 1030);
        let (c2, d2) = core(Source::Fixed(None)); let (s, a) = c2.handle_census(&env(&d2, "aaaaaaaa-0000-4000-8000-000000000003", json!({})), 1010).await; assert_eq!(s, 200); assert_eq!(body(&a)["refused"], true); assert_eq!(body(&a)["census"], Value::Null);
        let (c3, d3) = core(Source::Down); assert_eq!(c3.handle_census(&env(&d3, "aaaaaaaa-0000-4000-8000-000000000004", json!({})), 1010).await.0, 503);
        let (c4, _) = core(Source::Down); let mut last = 0; for _ in 0..60 { last = c4.handle_census("x", 1010).await.0; } assert_eq!(last, 429);
    }
    #[tokio::test] async fn a_lookup_request_is_refused_by_the_census_door_and_a_census_request_by_the_lookup_door() {
        let (c, d) = core(Source::Fixed(Some(json!({"companies": 1}))));
        let body_l = json!({"aud":"desk-lookup","method":"read","request_id":"aaaaaaaa-0000-4000-8000-000000000009","employee_id":"e1","company_ref":"acme-1234","reason":"customer says mail is missing","requested_fields":["service_state"],"issued_at":1000,"expires_at":1060}).to_string();
        let l = json!({"kid":"x","body":body_l,"sig":hex(&d.sign(format!("{REQ_DOMAIN}\n{body_l}").as_bytes()).to_bytes())}).to_string();
        assert_eq!(c.handle_census(&l, 1010).await.0, 403);
        assert_eq!(c.handle(&env(&d, "aaaaaaaa-0000-4000-8000-000000000008", json!({})), 1010).await.0, 403);
    }
}

#[cfg(test)]
mod deliv_t {
    use super::*; use crate::verify::{hex, REQ_DOMAIN}; use ed25519_dalek::{Signer as _, SigningKey}; use serde_json::json;
    fn core(src: Source) -> (Core, SigningKey) { let d = SigningKey::from_bytes(&[3u8; 32]); (Core::new(hex(d.verifying_key().as_bytes()), Signer::from_seed_hex(&"07".repeat(32)).unwrap(), src, 0), d) }
    fn env(k: &SigningKey, rid: &str, aud: &str) -> String {
        let body = json!({"aud":aud,"method":"read","request_id":rid,"employee_id":"e1","reason":"deliverability board opened","issued_at":1000,"expires_at":1060}).to_string();
        json!({"kid":"x","body":body,"sig":hex(&k.sign(format!("{REQ_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    fn body(a: &str) -> Value { serde_json::from_str(serde_json::from_str::<Value>(a).unwrap()["body"].as_str().unwrap()).unwrap() }
    #[tokio::test] async fn deliverability_flow_good_replay_wrong_audience_down_and_refused() {
        let (c, d) = core(Source::Fixed(Some(json!({"domains": 3}))));
        let (s, a) = c.handle_deliv(&env(&d, "aaaaaaaa-0000-4000-8000-000000000001", "desk-deliv"), 1010).await; assert_eq!(s, 200);
        let b = body(&a); assert_eq!((b["kind"].as_str(), b["refused"].as_bool(), b["deliverability"]["domains"].as_i64()), (Some("deliverability"), Some(false), Some(3)));
        assert_eq!(c.handle_deliv(&env(&d, "aaaaaaaa-0000-4000-8000-000000000001", "desk-deliv"), 1010).await.0, 403, "replay");
        assert_eq!(c.handle_deliv(&env(&d, "aaaaaaaa-0000-4000-8000-000000000002", "desk-census"), 1010).await.0, 403, "a census request is not accepted here");
        assert_eq!(c.handle_deliv("garbage", 1010).await.0, 403);
        let (c2, d2) = core(Source::Fixed(None)); let (s, a) = c2.handle_deliv(&env(&d2, "aaaaaaaa-0000-4000-8000-000000000003", "desk-deliv"), 1010).await; assert_eq!(s, 200); assert_eq!(body(&a)["refused"], true);
        let (c3, d3) = core(Source::Down); assert_eq!(c3.handle_deliv(&env(&d3, "aaaaaaaa-0000-4000-8000-000000000004", "desk-deliv"), 1010).await.0, 503);
    }
}


#[cfg(test)]
mod consent_t {
    use super::*; use crate::verify::{hex, REQ_DOMAIN}; use ed25519_dalek::{Signer as _, SigningKey}; use serde_json::json;
    fn core(src: Source) -> (Core, SigningKey) { let d = SigningKey::from_bytes(&[3u8; 32]); (Core::new(hex(d.verifying_key().as_bytes()), Signer::from_seed_hex(&"07".repeat(32)).unwrap(), src, 0), d) }
    fn env(k: &SigningKey, rid: &str, aud: &str, method: &str) -> String {
        let body = json!({"aud":aud,"method":method,"request_id":rid,"employee_id":"e1","consent":"aaaaaaaa-0000-4000-8000-000000000001","issued_at":1000,"expires_at":1060}).to_string();
        json!({"kid":"x","body":body,"sig":hex(&k.sign(format!("{REQ_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    fn body(a: &str) -> Value { serde_json::from_str(serde_json::from_str::<Value>(a).unwrap()["body"].as_str().unwrap()).unwrap() }
    #[tokio::test] async fn consent_flow_good_replay_wrong_audience_refused_down_and_rate() {
        let (c, d) = core(Source::Fixed(Some(json!({"consent": "x", "status": "cancelled"}))));
        let (s, a) = c.handle_consent(&env(&d, "aaaaaaaa-0000-4000-8000-000000000011", "desk-consent", "cancel"), 1010).await; assert_eq!(s, 200);
        let b = body(&a); assert_eq!((b["kind"].as_str(), b["method"].as_str(), b["refused"].as_bool(), b["result"]["status"].as_str()), (Some("consent"), Some("cancel"), Some(false), Some("cancelled")));
        assert_eq!(c.handle_consent(&env(&d, "aaaaaaaa-0000-4000-8000-000000000011", "desk-consent", "cancel"), 1010).await.0, 403, "replay");
        assert_eq!(c.handle_consent(&env(&d, "aaaaaaaa-0000-4000-8000-000000000012", "desk-census", "cancel"), 1010).await.0, 403, "a census request is not accepted here");
        assert_eq!(c.handle_consent(&env(&d, "aaaaaaaa-0000-4000-8000-000000000013", "desk-consent", "decide"), 1010).await.0, 403, "there is no decide method");
        assert_eq!(c.handle_consent("garbage", 1010).await.0, 403);
        let (c2, d2) = core(Source::Fixed(None)); let (s, a) = c2.handle_consent(&env(&d2, "aaaaaaaa-0000-4000-8000-000000000014", "desk-consent", "cancel"), 1010).await; assert_eq!(s, 200); assert_eq!(body(&a)["refused"], true); assert_eq!(body(&a)["result"], Value::Null);
        let (c3, d3) = core(Source::Down); assert_eq!(c3.handle_consent(&env(&d3, "aaaaaaaa-0000-4000-8000-000000000015", "desk-consent", "cancel"), 1010).await.0, 503, "database down: nothing is approved");
        let (c4, _) = core(Source::Down); let mut last = 0; for _ in 0..60 { last = c4.handle_consent("x", 1010).await.0; } assert_eq!(last, 429);
    }
}


#[cfg(test)]
mod resolve_t {
    use super::*; use crate::verify::{hex, REQ_DOMAIN}; use ed25519_dalek::{Signer as _, SigningKey}; use serde_json::json;
    fn core(src: Source) -> (Core, SigningKey) { let d = SigningKey::from_bytes(&[3u8; 32]); (Core::new(hex(d.verifying_key().as_bytes()), Signer::from_seed_hex(&"07".repeat(32)).unwrap(), src, 0), d) }
    fn env(k: &SigningKey, rid: &str, aud: &str, method: &str) -> String {
        let body = json!({"aud":aud,"method":method,"request_id":rid,"employee_id":"e1","path":"/control/v1/resolve","domain":"acme.example","local":"ann","aligned":true,"issued_at":1000,"expires_at":1060}).to_string();
        json!({"kid":"x","body":body,"sig":hex(&k.sign(format!("{REQ_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    fn body(a: &str) -> Value { serde_json::from_str(serde_json::from_str::<Value>(a).unwrap()["body"].as_str().unwrap()).unwrap() }
    #[tokio::test] async fn resolve_flow_good_replay_wrong_audience_refused_down_and_rate() {
        let (c, d) = core(Source::Fixed(Some(json!({"verdict": "unknown", "tenant": null}))));
        let (s, a) = c.handle_resolve(&env(&d, "aaaaaaaa-0000-4000-8000-000000000021", "desk-resolve", "resolve"), 1010).await; assert_eq!(s, 200);
        let b = body(&a); assert_eq!((b["kind"].as_str(), b["refused"].as_bool(), b["result"]["verdict"].as_str()), (Some("resolve"), Some(false), Some("unknown")));
        assert_eq!(c.handle_resolve(&env(&d, "aaaaaaaa-0000-4000-8000-000000000021", "desk-resolve", "resolve"), 1010).await.0, 403, "replay");
        assert_eq!(c.handle_resolve(&env(&d, "aaaaaaaa-0000-4000-8000-000000000022", "desk-consent", "resolve"), 1010).await.0, 403, "a consent request is not accepted here");
        assert_eq!(c.handle_resolve(&env(&d, "aaaaaaaa-0000-4000-8000-000000000023", "desk-resolve", "bind"), 1010).await.0, 403, "there is no bind method");
        assert_eq!(c.handle_resolve("garbage", 1010).await.0, 403);
        let (c2, d2) = core(Source::Fixed(None)); let (s, a) = c2.handle_resolve(&env(&d2, "aaaaaaaa-0000-4000-8000-000000000024", "desk-resolve", "resolve"), 1010).await; assert_eq!(s, 200); assert_eq!(body(&a)["refused"], true); assert_eq!(body(&a)["result"], Value::Null);
        let (c3, d3) = core(Source::Down); assert_eq!(c3.handle_resolve(&env(&d3, "aaaaaaaa-0000-4000-8000-000000000025", "desk-resolve", "resolve"), 1010).await.0, 503, "database down: no verdict, nothing is bound");
        let (c4, _) = core(Source::Down); let mut last = 0; for _ in 0..60 { last = c4.handle_resolve("x", 1010).await.0; } assert_eq!(last, 429);
    }
}
#[cfg(test)]
mod tenant_t {
    use super::*; use crate::verify::{hex, REQ_DOMAIN}; use ed25519_dalek::{Signer as _, SigningKey}; use serde_json::json;
    fn core(src: Source) -> (Core, SigningKey) { let d = SigningKey::from_bytes(&[3u8; 32]); (Core::new(hex(d.verifying_key().as_bytes()), Signer::from_seed_hex(&"07".repeat(32)).unwrap(), src, 0), d) }
    fn env(k: &SigningKey, rid: &str, aud: &str, method: &str) -> String {
        let body = json!({"aud":aud,"method":method,"request_id":rid,"employee_id":"e1","path":"/control/v1/tenant","tenant":"11111111-1111-4111-8111-111111111111","issued_at":1000,"expires_at":1060}).to_string();
        json!({"kid":"x","body":body,"sig":hex(&k.sign(format!("{REQ_DOMAIN}\n{body}").as_bytes()).to_bytes())}).to_string()
    }
    fn body(a: &str) -> Value { serde_json::from_str(serde_json::from_str::<Value>(a).unwrap()["body"].as_str().unwrap()).unwrap() }
    #[tokio::test] async fn tenant_flow_good_replay_wrong_audience_refused_down_and_rate() {
        let (c, d) = core(Source::Fixed(Some(json!({"exists": true, "name": "Acme Ltd"}))));
        let (s, a) = c.handle_tenant(&env(&d, "aaaaaaaa-0000-4000-8000-000000000031", "desk-tenant", "tenant"), 1010).await; assert_eq!(s, 200);
        let b = body(&a); assert_eq!((b["kind"].as_str(), b["refused"].as_bool(), b["result"]["exists"].as_bool(), b["result"]["name"].as_str()), (Some("tenant"), Some(false), Some(true), Some("Acme Ltd")));
        assert_eq!(c.handle_tenant(&env(&d, "aaaaaaaa-0000-4000-8000-000000000031", "desk-tenant", "tenant"), 1010).await.0, 403, "replay");
        assert_eq!(c.handle_tenant(&env(&d, "aaaaaaaa-0000-4000-8000-000000000032", "desk-resolve", "tenant"), 1010).await.0, 403, "a resolve request is not accepted here");
        assert_eq!(c.handle_tenant(&env(&d, "aaaaaaaa-0000-4000-8000-000000000033", "desk-tenant", "bind"), 1010).await.0, 403, "there is no bind method");
        assert_eq!(c.handle_tenant("garbage", 1010).await.0, 403);
        let (c2, d2) = core(Source::Fixed(None)); let (s, a) = c2.handle_tenant(&env(&d2, "aaaaaaaa-0000-4000-8000-000000000034", "desk-tenant", "tenant"), 1010).await; assert_eq!(s, 200); assert_eq!(body(&a)["refused"], true);
        let (c3, d3) = core(Source::Down); assert_eq!(c3.handle_tenant(&env(&d3, "aaaaaaaa-0000-4000-8000-000000000035", "desk-tenant", "tenant"), 1010).await.0, 503, "database down: no name is guessed");
        let (c4, _) = core(Source::Down); let mut last = 0; for _ in 0..60 { last = c4.handle_tenant("x", 1010).await.0; } assert_eq!(last, 429);
    }
}
