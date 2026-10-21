// Sandbox-only WebTransport client for B4 proofs (not shipped to the server crate).
// usage: wt_probe <https://host:port> <token> <mode> <topics,comma> <seconds> [org_id]
// Prints every line the server sends, prefixed with milliseconds since connect, flushed. Certificate is NOT validated (self-signed test cert).
use std::io::Write;
use std::time::{Duration, Instant};
use wtransport::{ClientConfig, Endpoint};

#[tokio::main]
async fn main() {
    let a: Vec<String> = std::env::args().collect();
    let (url, token, mode, topics, secs) = (a[1].clone(), a[2].clone(), a[3].clone(), a[4].clone(), a[5].parse::<u64>().unwrap_or(10));
    let org = a.get(6).cloned().unwrap_or_default();
    let cfg = ClientConfig::builder().with_bind_address(std::net::SocketAddr::from(([0, 0, 0, 0], 0))).with_no_cert_validation().build();
    let ep = Endpoint::client(cfg).expect("client");
    let conn = ep.connect(&url).await.expect("connect");
    let (mut send, mut recv) = conn.open_bi().await.expect("open").await.expect("open2");
    let t0 = Instant::now();
    let tl: Vec<String> = topics.split(',').filter(|x| !x.is_empty()).map(|x| format!("\"{x}\"")).collect();
    let hello = format!("{{\"token\":\"{token}\",\"mode\":\"{mode}\",\"topics\":[{}],\"org_id\":\"{org}\"}}", tl.join(","));
    send.write_all(hello.as_bytes()).await.expect("hello");
    let mut buf = vec![0u8; 8192];
    let mut pend = String::new();
    let end = t0 + Duration::from_secs(secs);
    while Instant::now() < end {
        match tokio::time::timeout(Duration::from_millis(300), recv.read(&mut buf)).await {
            Ok(Ok(Some(n))) => {
                pend.push_str(&String::from_utf8_lossy(&buf[..n]));
                while let Some(i) = pend.find('\n') {
                    let line: String = pend.drain(..=i).collect();
                    println!("{} {}", t0.elapsed().as_millis(), line.trim_end());
                    std::io::stdout().flush().ok();
                }
            }
            Ok(Ok(None)) | Ok(Err(_)) => break,
            Err(_) => {}
        }
    }
    println!("{} END", t0.elapsed().as_millis());
}
