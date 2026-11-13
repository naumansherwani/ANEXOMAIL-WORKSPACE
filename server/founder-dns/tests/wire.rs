//! KP1b wire tests: real DNS packets in, real packets out (the same bytes dig would send).
use founder_dns::{auth, net::*, rrl::*, zone::*};
use hickory_proto::op::{Edns, Message, MessageType, OpCode, Query, ResponseCode};
use hickory_proto::rr::rdata::opt::EdnsOption;
use hickory_proto::rr::{Name, RData, RecordType};
use std::{net::{IpAddr, Ipv4Addr}, str::FromStr, sync::{Arc, Mutex}, time::Instant};

const SEC: [u8; 32] = [7u8; 32];
fn zone() -> Zone {
    Zone::build(ZoneConfig { origin: "founderworkspace.anexomail.com.".into(), ns: vec!["ns1.anexomail.com.".into(), "ns2.anexomail.com.".into()], hostmaster: "hostmaster.anexomail.com.".into(), serial: 2026111301,
        v4: vec!["62.238.98.98".parse().unwrap()], v6: vec!["2a01:4f9:c014:5df6::1".parse().unwrap()], alpn: vec!["h3".into()], caa_issuers: vec!["letsencrypt.org".into()], ttl: 300 }).unwrap()
}
fn query(name: &str, t: RecordType, edns: Option<Edns>) -> Vec<u8> {
    let mut m = Message::new(); m.set_id(0x1234); m.set_message_type(MessageType::Query); m.set_op_code(OpCode::Query); m.set_recursion_desired(true);
    m.add_query(Query::query(Name::from_str(name).unwrap(), t)); if let Some(e) = edns { m.set_edns(e); } m.to_vec().unwrap()
}
fn ask(name: &str, t: RecordType) -> Message { let o = auth::respond(&zone(), &query(name, t, None), IpAddr::V4(Ipv4Addr::new(192, 0, 2, 1)), true, &SEC).unwrap(); Message::from_vec(&o.bytes).unwrap() }
const Z: &str = "founderworkspace.anexomail.com.";

#[test] fn https_record_alpn_h3_is_served() {
    let r = ask(Z, RecordType::HTTPS);
    assert_eq!(r.response_code(), ResponseCode::NoError); assert!(r.authoritative()); assert!(!r.recursion_available());
    assert_eq!(r.answers().len(), 1);
    let RData::HTTPS(h) = r.answers()[0].data() else { panic!("not an HTTPS rdata") };
    assert_eq!(h.0.svc_priority(), 1); assert!(h.0.target_name().is_root());
    let s = format!("{}", h.0); assert!(s.contains("h3"), "alpn missing: {s}"); assert!(!s.contains("h2"), "h2 must never be advertised: {s}");
}
#[test] fn a_aaaa_ns_soa_caa_answer() {
    assert_eq!(ask(Z, RecordType::A).answers().len(), 1); assert_eq!(ask(Z, RecordType::AAAA).answers().len(), 1);
    assert_eq!(ask(Z, RecordType::NS).answers().len(), 2); assert_eq!(ask(Z, RecordType::SOA).answers().len(), 1); assert_eq!(ask(Z, RecordType::CAA).answers().len(), 1);
}
#[test] fn nodata_and_nxdomain_carry_soa() {
    let r = ask(Z, RecordType::MX); assert_eq!(r.response_code(), ResponseCode::NoError); assert!(r.answers().is_empty()); assert_eq!(r.name_servers().len(), 1);
    let r = ask("nope.founderworkspace.anexomail.com.", RecordType::A); assert_eq!(r.response_code(), ResponseCode::NXDomain); assert!(r.authoritative()); assert_eq!(r.name_servers().len(), 1);
}
#[test] fn other_zones_are_refused_never_recursed() {
    for n in ["example.com.", "anexomail.com.", "www.anexomail.com.", "."] { let r = ask(n, RecordType::A); assert_eq!(r.response_code(), ResponseCode::Refused, "{n}"); assert!(!r.authoritative()); assert!(r.answers().is_empty()); }
}
#[test] fn case_insensitive_name() { assert_eq!(ask("FounderWorkspace.AnexoMail.COM.", RecordType::A).answers().len(), 1); }
#[test] fn responses_and_garbage_are_not_answered() {
    let mut m = Message::new(); m.set_message_type(MessageType::Response); m.add_query(Query::query(Name::from_str(Z).unwrap(), RecordType::A));
    assert!(auth::respond(&zone(), &m.to_vec().unwrap(), IpAddr::V4(Ipv4Addr::LOCALHOST), true, &SEC).is_none());
    assert!(auth::respond(&zone(), &[1, 2, 3], IpAddr::V4(Ipv4Addr::LOCALHOST), true, &SEC).is_none());
    let o = auth::respond(&zone(), &[0xab, 0xcd, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], IpAddr::V4(Ipv4Addr::LOCALHOST), true, &SEC);
    assert!(o.map(|o| o.rcode == ResponseCode::FormErr).unwrap_or(true));
}
#[test] fn non_query_opcode_is_notimp() {
    let mut m = Message::new(); m.set_message_type(MessageType::Query); m.set_op_code(OpCode::Update); m.add_query(Query::query(Name::from_str(Z).unwrap(), RecordType::SOA));
    assert_eq!(auth::respond(&zone(), &m.to_vec().unwrap(), IpAddr::V4(Ipv4Addr::LOCALHOST), true, &SEC).unwrap().rcode, ResponseCode::NotImp);
}
#[test] fn edns_version_1_is_badvers() { let mut e = Edns::new(); e.set_version(1); let o = auth::respond(&zone(), &query(Z, RecordType::A, Some(e)), IpAddr::V4(Ipv4Addr::LOCALHOST), true, &SEC).unwrap(); assert_eq!(o.rcode, ResponseCode::BADVERS); }
#[test] fn udp_answer_is_truncated_when_client_has_no_edns_room() {
    // classic 512-byte client + a large ANY-style answer is not possible here (tiny zone), so force a tiny limit via many NS names
    let mut c = ZoneConfig { origin: Z.into(), ns: (0..40).map(|i| format!("nameserver-number-{i}.anexomail.com.")).collect(), hostmaster: "hostmaster.anexomail.com.".into(), serial: 1, v4: vec![Ipv4Addr::LOCALHOST], v6: vec![], alpn: vec!["h3".into()], caa_issuers: vec![], ttl: 300 };
    c.ttl = 300; let z = Zone::build(c).unwrap();
    let u = auth::respond(&z, &query(Z, RecordType::NS, None), IpAddr::V4(Ipv4Addr::LOCALHOST), true, &SEC).unwrap(); assert!(u.truncated); let m = Message::from_vec(&u.bytes).unwrap(); assert!(m.truncated() && m.answers().is_empty());
    let t = auth::respond(&z, &query(Z, RecordType::NS, None), IpAddr::V4(Ipv4Addr::LOCALHOST), false, &SEC).unwrap(); assert!(!t.truncated); assert_eq!(Message::from_vec(&t.bytes).unwrap().answers().len(), 40, "TCP has no size limit");
}
#[test] fn cookie_roundtrip_and_validation() {
    let ip = IpAddr::V4(Ipv4Addr::new(203, 0, 113, 9)); let client = vec![1u8, 2, 3, 4, 5, 6, 7, 8];
    let mut e = Edns::new(); e.options_mut().insert(EdnsOption::Unknown(10, client.clone()));
    let o1 = auth::respond(&zone(), &query(Z, RecordType::A, Some(e)), ip, true, &SEC).unwrap(); assert!(!o1.cookie_valid, "first contact: no server cookie yet");
    let m = Message::from_vec(&o1.bytes).unwrap(); let EdnsOption::Unknown(_, full) = m.extensions().as_ref().unwrap().option(hickory_proto::rr::rdata::opt::EdnsCode::Cookie).unwrap().clone() else { panic!() };
    assert_eq!(full.len(), 16); assert_eq!(&full[..8], &client[..]);
    let mut e2 = Edns::new(); e2.options_mut().insert(EdnsOption::Unknown(10, full.clone()));
    assert!(auth::respond(&zone(), &query(Z, RecordType::A, Some(e2)), ip, true, &SEC).unwrap().cookie_valid, "echoed server cookie is valid for the same IP");
    let mut e3 = Edns::new(); e3.options_mut().insert(EdnsOption::Unknown(10, full));
    assert!(!auth::respond(&zone(), &query(Z, RecordType::A, Some(e3)), IpAddr::V4(Ipv4Addr::new(198, 51, 100, 7)), true, &SEC).unwrap().cookie_valid, "same cookie from another IP (spoofing) is NOT valid");
}
#[test] fn rrl_limits_slips_and_recovers() {
    let mut r = Rrl::new(10.0, 5.0, 2); let ip = IpAddr::V4(Ipv4Addr::new(192, 0, 2, 1)); let other = IpAddr::V4(Ipv4Addr::new(192, 0, 2, 200)); // same /24
    for _ in 0..5 { assert_eq!(r.check(ip, 0.0), Verdict::Answer); }
    let a = r.check(other, 0.0); let b = r.check(ip, 0.0); assert!(a != Verdict::Answer && b != Verdict::Answer); assert!(a == Verdict::Drop && b == Verdict::Slip, "every 2nd limited response slips: {a:?} {b:?}");
    assert_eq!(r.check(IpAddr::V4(Ipv4Addr::new(198, 51, 100, 1)), 0.0), Verdict::Answer, "another network is unaffected");
    assert_eq!(r.check(ip, 1.0), Verdict::Answer, "tokens refill");
}
#[test] fn bind_must_be_explicit() { assert!(parse_binds("0.0.0.0:53").is_err()); assert!(parse_binds("[::]:53").is_err()); assert!(parse_binds("").is_err()); assert_eq!(parse_binds("62.238.98.98:53,[2a01:4f9:c014:5df6::1]:53").unwrap().len(), 2); }

#[tokio::test] async fn real_udp_and_tcp_sockets_answer_https() {
    use tokio::{io::{AsyncReadExt, AsyncWriteExt}, net::{TcpListener, TcpStream, UdpSocket}};
    let sh = Arc::new(Shared { zone: zone(), secret: SEC, rrl: Mutex::new(Rrl::new(1000.0, 1000.0, 2)), t0: Instant::now() });
    let u = Arc::new(UdpSocket::bind("127.0.0.1:0").await.unwrap()); let ua = u.local_addr().unwrap(); tokio::spawn(serve_udp(u, sh.clone()));
    let t = TcpListener::bind("127.0.0.1:0").await.unwrap(); let ta = t.local_addr().unwrap(); tokio::spawn(serve_tcp(t, sh));
    let q = query(Z, RecordType::HTTPS, None);
    let c = UdpSocket::bind("127.0.0.1:0").await.unwrap(); c.send_to(&q, ua).await.unwrap(); let mut b = vec![0u8; 2048]; let (n, _) = tokio::time::timeout(std::time::Duration::from_secs(3), c.recv_from(&mut b)).await.unwrap().unwrap();
    assert_eq!(Message::from_vec(&b[..n]).unwrap().answers().len(), 1);
    let mut s = TcpStream::connect(ta).await.unwrap(); let mut w = (q.len() as u16).to_be_bytes().to_vec(); w.extend_from_slice(&q); s.write_all(&w).await.unwrap();
    let mut lb = [0u8; 2]; s.read_exact(&mut lb).await.unwrap(); let mut m = vec![0u8; u16::from_be_bytes(lb) as usize]; s.read_exact(&mut m).await.unwrap();
    assert_eq!(Message::from_vec(&m).unwrap().answers().len(), 1);
}
