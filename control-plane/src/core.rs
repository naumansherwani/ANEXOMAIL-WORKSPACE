// CONTROL PLANE core.rs (D5a-3b): request in -> verified -> database (read-only function) -> signed answer out. Fail closed at every step.
use crate::{answer::Signer, db::Pg, verify::{verify, Seen}};
#[cfg(test)] use serde_json::Value;
use std::sync::Mutex;

pub enum Source { Pg(Pg), #[cfg(test)] Fixed(Option<Value>), #[cfg(test)] Down }
pub struct Core { pub desk_pub: String, pub signer: Signer, pub seen: Seen, pub src: Source, rate: Mutex<(i64, u32)> }
const PER_SECOND: u32 = 50;

impl Core {
    pub fn new(desk_pub: String, signer: Signer, src: Source, boot: i64) -> Core { Core { desk_pub, signer, seen: Seen::new(boot), src, rate: Mutex::new((0, 0)) } }
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
