//! ANEXOMAIL — WebTransport (UDP 3443) ka asli handshake check: QUIC + HTTP/3 + WebTransport session + bidi stream + hello.
//! Har case ke liye ek line: `<case>|<stage>` (stage = kahan tak pahuncha) + `|<pehli line>|ms=<n>` (sirf jaankari).
//! Stage hi pehle/baad milaya jata hai: server error ke baad turant connection band karta hai, is liye pehli line kabhi aati hai kabhi nahi (NOTE N7).
//! Cert check band hai kyunki ye 127.0.0.1 par apne hi server ko dekhta hai (domain ka cert 127.0.0.1 par match nahi hota) — sirf test client.
use std::net::SocketAddr;
use std::time::{Duration, Instant};
use wtransport::{ClientConfig, Endpoint};

#[tokio::main]
async fn main() {
    let url = std::env::args().nth(1).unwrap_or_else(|| "https://127.0.0.1:3443/".into());
    let cases: [(&str, &str); 4] = [
        ("bad_hello", "xx"),
        ("no_token", "{}"),
        ("mail_fake", r#"{"token":"x","mode":"mail","org_id":"o"}"#),
        ("chat_fake", r#"{"token":"x","conversation_id":"c"}"#),
    ];
    let mut all_ok = true;
    for (name, hello) in cases {
        let cfg = ClientConfig::builder()
            .with_bind_address(SocketAddr::from(([0, 0, 0, 0], 0)))
            .with_no_cert_validation()
            .max_idle_timeout(Some(Duration::from_secs(5)))
            .expect("idle timeout")
            .build();
        let ep = match Endpoint::client(cfg) {
            Ok(ep) => ep,
            Err(e) => { println!("{name}|FAIL bind {e}||"); all_ok = false; continue; }
        };
        let t0 = Instant::now();
        let mut stage = "connect";
        let mut first = String::new();
        let res = tokio::time::timeout(Duration::from_secs(8), async {
            let conn = ep.connect(url.as_str()).await.map_err(|e| e.to_string())?;
            stage = "session";
            let (mut tx, mut rx) = conn.open_bi().await.map_err(|e| e.to_string())?.await.map_err(|e| e.to_string())?;
            stage = "stream";
            tx.write_all(hello.as_bytes()).await.map_err(|e| e.to_string())?;
            stage = "hello_sent";
            let mut buf = vec![0u8; 4096];
            while !first.contains('\n') {
                match tokio::time::timeout(Duration::from_secs(3), rx.read(&mut buf)).await {
                    Ok(Ok(Some(n))) => first.push_str(&String::from_utf8_lossy(&buf[..n])),
                    _ => break,
                }
            }
            Ok::<(), String>(())
        })
        .await;
        let ms = t0.elapsed().as_millis();
        let line = first.lines().next().unwrap_or("").to_string();
        match res {
            Ok(Ok(())) => println!("{name}|{stage}|{line}|ms={ms}"),
            Ok(Err(e)) if stage == "hello_sent" => println!("{name}|{stage}|{line}|ms={ms} (band: {e})"),
            Ok(Err(e)) => { all_ok = false; println!("{name}|FAIL {stage}: {e}||ms={ms}"); }
            Err(_) => { all_ok = false; println!("{name}|FAIL {stage}: timeout||ms={ms}"); }
        }
    }
    std::process::exit(if all_ok { 0 } else { 1 });
}
