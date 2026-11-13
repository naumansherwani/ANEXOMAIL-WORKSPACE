//! The authoritative answer logic: bytes in, bytes out, no I/O (so every behaviour is a plain unit test).
use crate::zone::Zone;
use hickory_proto::op::{Edns, Message, MessageType, OpCode, ResponseCode};
use hickory_proto::rr::rdata::opt::{EdnsCode, EdnsOption};
use hickory_proto::rr::{DNSClass, LowerName, RecordType};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::net::IpAddr;

/// DNS flag day 2020: 1232 bytes is the largest UDP answer that does not fragment on a 1280-byte-MTU path.
pub const UDP_MAX: u16 = 1232;
pub const COOKIE: u16 = 10;

pub struct Out { pub bytes: Vec<u8>, pub cookie_valid: bool, pub rcode: ResponseCode, pub truncated: bool }

fn server_cookie(secret: &[u8; 32], client: &[u8], ip: IpAddr) -> [u8; 8] {
    let mut m = <Hmac<Sha256> as Mac>::new_from_slice(secret).expect("hmac key");
    m.update(client);
    match ip { IpAddr::V4(a) => m.update(&a.octets()), IpAddr::V6(a) => m.update(&a.octets()) }
    let d = m.finalize().into_bytes();
    let mut o = [0u8; 8]; o.copy_from_slice(&d[..8]); o
}

fn bare(id: u16, rc: ResponseCode) -> Out {
    let mut m = Message::new(); m.set_id(id); m.set_message_type(MessageType::Response); m.set_response_code(rc);
    Out { bytes: m.to_vec().unwrap_or_default(), cookie_valid: false, rcode: rc, truncated: false }
}

/// `udp` decides the size limit (TCP has none). Returns None when nothing must be sent (not a query, or unparseable and too short to answer).
pub fn respond(zone: &Zone, req: &[u8], ip: IpAddr, udp: bool, secret: &[u8; 32]) -> Option<Out> {
    let q = match Message::from_vec(req) {
        Ok(m) => m,
        Err(_) => { return if req.len() >= 12 { Some(bare(u16::from_be_bytes([req[0], req[1]]), ResponseCode::FormErr)) } else { None }; }
    };
    if q.message_type() != MessageType::Query { return None; } // never answer a response: no reflection loops
    if q.op_code() != OpCode::Query { return Some(bare(q.id(), ResponseCode::NotImp)); }
    if q.queries().len() != 1 { return Some(bare(q.id(), ResponseCode::FormErr)); }
    let (mut limit, mut cookie_in): (u16, Option<Vec<u8>>) = (512, None);
    if let Some(e) = q.extensions() {
        if e.version() > 0 { let mut o = bare(q.id(), ResponseCode::BADVERS); o.rcode = ResponseCode::BADVERS; return Some(o); }
        limit = e.max_payload().clamp(512, UDP_MAX);
        if let Some(EdnsOption::Unknown(c, d)) = e.option(EdnsCode::Cookie) { if *c == COOKIE { cookie_in = Some(d.clone()); } }
    }
    let qy = &q.queries()[0];
    let qname = LowerName::new(qy.name());
    let mut r = Message::new();
    r.set_id(q.id()); r.set_message_type(MessageType::Response); r.set_op_code(OpCode::Query); r.set_recursion_desired(q.recursion_desired()); r.set_recursion_available(false);
    r.add_query(qy.clone());
    if qy.query_class() != DNSClass::IN || !zone.origin.zone_of(&qname) {
        r.set_response_code(ResponseCode::Refused); // not our zone, never recurse
    } else {
        r.set_authoritative(true);
        if qname == zone.origin {
            let t = qy.query_type();
            if t == RecordType::SOA || t == RecordType::ANY { r.add_answer(zone.soa().clone()); }
            else if let Some(v) = zone.apex(t) { for rec in v { r.add_answer(rec.clone()); } }
            else { r.add_name_server(zone.soa().clone()); } // NODATA
            if t == RecordType::NS { for a in zone.apex(RecordType::A).into_iter().flatten().chain(zone.apex(RecordType::AAAA).into_iter().flatten()) { let _ = a; } }
        } else {
            r.set_response_code(ResponseCode::NXDomain); r.add_name_server(zone.soa().clone());
        }
    }
    let mut cookie_valid = false;
    let mut edns = Edns::new(); edns.set_version(0); edns.set_max_payload(UDP_MAX);
    if let Some(c) = cookie_in {
        if c.len() >= 8 {
            let client = &c[..8]; let sc = server_cookie(secret, client, ip);
            cookie_valid = c.len() == 16 && c[8..] == sc;
            let mut v = client.to_vec(); v.extend_from_slice(&sc);
            edns.options_mut().insert(EdnsOption::Unknown(COOKIE, v));
        }
    }
    r.set_edns(edns);
    let rcode = r.response_code();
    let mut bytes = r.to_vec().ok()?;
    let mut truncated = false;
    if udp && bytes.len() > limit as usize {
        let mut t = Message::new(); t.set_id(r.id()); t.set_message_type(MessageType::Response); t.set_authoritative(true); t.set_truncated(true);
        t.set_recursion_desired(q.recursion_desired()); t.add_query(qy.clone()); t.set_response_code(rcode);
        if let Some(e) = r.extensions().clone() { t.set_edns(e); }
        bytes = t.to_vec().ok()?; truncated = true;
    }
    Some(Out { bytes, cookie_valid, rcode, truncated })
}

/// The tiny TC answer used by RRL "slip": the client's resolver retries over TCP (a spoofed victim gets only ~40 useless bytes).
pub fn slip(req: &[u8]) -> Option<Vec<u8>> {
    let q = Message::from_vec(req).ok()?; if q.message_type() != MessageType::Query || q.queries().len() != 1 { return None; }
    let mut t = Message::new(); t.set_id(q.id()); t.set_message_type(MessageType::Response); t.set_authoritative(true); t.set_truncated(true); t.add_query(q.queries()[0].clone());
    t.to_vec().ok()
}
