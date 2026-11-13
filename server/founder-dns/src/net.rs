//! UDP + TCP servers on explicit addresses (never wildcard: systemd-resolved owns 127.0.0.53/54:53 on his server).
use crate::{auth, rrl::{Rrl, Verdict}, zone::Zone};
use std::{net::SocketAddr, sync::{Arc, Mutex}, time::{Duration, Instant}};
use tokio::{io::{AsyncReadExt, AsyncWriteExt}, net::{TcpListener, UdpSocket}, sync::Semaphore};

pub struct Shared { pub zone: Zone, pub secret: [u8; 32], pub rrl: Mutex<Rrl>, pub t0: Instant }

pub async fn serve_udp(sock: Arc<UdpSocket>, sh: Arc<Shared>) {
    let mut buf = vec![0u8; 4096];
    loop {
        let (n, from) = match sock.recv_from(&mut buf).await { Ok(x) => x, Err(_) => continue };
        let req = &buf[..n];
        let Some(out) = auth::respond(&sh.zone, req, from.ip(), true, &sh.secret) else { continue };
        let v = if out.cookie_valid { Verdict::Answer } else { sh.rrl.lock().unwrap().check(from.ip(), sh.t0.elapsed().as_secs_f64()) };
        match v {
            Verdict::Answer => { let _ = sock.send_to(&out.bytes, from).await; }
            Verdict::Slip => { if let Some(s) = auth::slip(req) { let _ = sock.send_to(&s, from).await; } }
            Verdict::Drop => {}
        }
    }
}

pub async fn serve_tcp(l: TcpListener, sh: Arc<Shared>) {
    let cap = Arc::new(Semaphore::new(256)); // at most 256 live TCP connections
    loop {
        let Ok((mut s, from)) = l.accept().await else { continue };
        let Ok(p) = cap.clone().try_acquire_owned() else { continue };
        let sh = sh.clone();
        tokio::spawn(async move {
            let _p = p;
            for _ in 0..16 { // at most 16 queries per connection, 5 s idle
                let mut lb = [0u8; 2];
                if tokio::time::timeout(Duration::from_secs(5), s.read_exact(&mut lb)).await.map(|r| r.is_err()).unwrap_or(true) { return; }
                let n = u16::from_be_bytes(lb) as usize; if n < 12 { return; }
                let mut m = vec![0u8; n];
                if tokio::time::timeout(Duration::from_secs(5), s.read_exact(&mut m)).await.map(|r| r.is_err()).unwrap_or(true) { return; }
                let Some(o) = auth::respond(&sh.zone, &m, from.ip(), false, &sh.secret) else { return };
                let mut w = (o.bytes.len() as u16).to_be_bytes().to_vec(); w.extend_from_slice(&o.bytes);
                if s.write_all(&w).await.is_err() { return; }
            }
        });
    }
}

pub fn parse_binds(s: &str) -> Result<Vec<SocketAddr>, String> {
    let v: Vec<SocketAddr> = s.split(',').map(|x| x.trim()).filter(|x| !x.is_empty()).map(|x| x.parse().map_err(|e| format!("DNS_BIND {x}: {e}"))).collect::<Result<_, _>>()?;
    if v.is_empty() { return Err("DNS_BIND is empty".into()); }
    if v.iter().any(|a| a.ip().is_unspecified()) { return Err("DNS_BIND must name explicit addresses, never 0.0.0.0 or [::] (systemd-resolved owns the loopback stub on :53)".into()); }
    Ok(v)
}
