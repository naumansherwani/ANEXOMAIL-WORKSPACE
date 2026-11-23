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
