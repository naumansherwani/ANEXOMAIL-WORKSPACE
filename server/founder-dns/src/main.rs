use founder_dns::{net::*, rrl::Rrl, zone::*};
use std::{sync::{Arc, Mutex}, time::Instant};
use tokio::net::{TcpListener, UdpSocket};

#[tokio::main]
async fn main() {
    let run = || async {
        let cfg = ZoneConfig::from_env()?;
        let binds = parse_binds(&std::env::var("DNS_BIND").map_err(|_| "env DNS_BIND is missing".to_string())?)?;
        let zone = Zone::build(cfg)?;
        let mut secret = [0u8; 32]; getrandom::getrandom(&mut secret).map_err(|e| e.to_string())?;
        let sh = Arc::new(Shared { zone, secret, rrl: Mutex::new(Rrl::new(20.0, 40.0, 2)), t0: Instant::now() });
        for a in binds {
            let u = Arc::new(UdpSocket::bind(a).await.map_err(|e| format!("udp {a}: {e}"))?);
            let t = TcpListener::bind(a).await.map_err(|e| format!("tcp {a}: {e}"))?;
            eprintln!("founder-dns: ON {a} udp+tcp, zone {}", sh.zone.cfg.origin);
            tokio::spawn(serve_udp(u, sh.clone())); tokio::spawn(serve_tcp(t, sh.clone()));
        }
        tokio::signal::ctrl_c().await.map_err(|e| e.to_string())?;
        Ok::<(), String>(())
    };
    if let Err(e) = run().await { eprintln!("founder-dns: {e}"); std::process::exit(1); }
}
