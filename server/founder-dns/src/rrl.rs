//! Response Rate Limiting against DNS reflection/amplification (UDP only). Per client network (IPv4 /24, IPv6 /56) a token bucket;
//! when empty, every SLIP-th response is sent as a tiny truncated (TC) answer so a real client retries over TCP, the rest are dropped.
use std::collections::HashMap;
use std::net::IpAddr;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Verdict { Answer, Slip, Drop }

pub struct Rrl { rate: f64, burst: f64, slip: u32, map: HashMap<[u8; 8], (f64, f64, u32)>, last_gc: f64 }

fn key(ip: IpAddr) -> [u8; 8] {
    let mut k = [0u8; 8];
    match ip {
        IpAddr::V4(a) => { k[0] = 4; k[1..4].copy_from_slice(&a.octets()[..3]); }
        IpAddr::V6(a) => { k[0] = 6; k[1..8].copy_from_slice(&a.octets()[..7]); }
    }
    k
}

impl Rrl {
    pub fn new(rate_per_sec: f64, burst: f64, slip: u32) -> Self { Rrl { rate: rate_per_sec, burst, slip: slip.max(1), map: HashMap::new(), last_gc: 0.0 } }
    /// `now` in seconds (monotonic), injected so tests are exact.
    pub fn check(&mut self, ip: IpAddr, now: f64) -> Verdict {
        if now - self.last_gc > 60.0 { self.map.retain(|_, v| now - v.1 < 120.0); self.last_gc = now; }
        let (rate, burst, slip) = (self.rate, self.burst, self.slip);
        let e = self.map.entry(key(ip)).or_insert((burst, now, 0));
        e.0 = (e.0 + (now - e.1) * rate).min(burst); e.1 = now;
        if e.0 >= 1.0 { e.0 -= 1.0; e.2 = 0; return Verdict::Answer; }
        e.2 += 1;
        if e.2 % slip == 0 { Verdict::Slip } else { Verdict::Drop }
    }
}
