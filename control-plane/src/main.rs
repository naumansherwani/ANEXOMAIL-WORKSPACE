// ANEXOMAIL CONTROL PLANE responder (D5a-3b, 22 Nov 2026). Own binary. Answers the Admin Desk's signed, read-only company lookups over HTTP/3 only.
// Env: CP_LISTEN (UDP ip:port), CP_CERT, CP_KEY, CP_SEED_FILE (own Ed25519 seed, hex), CP_DESK_PUBKEY (the Desk's public key, hex), CP_DB_URL (role cp_lookup), CP_DB_CA (optional).
// `--print-pubkey` prints this Control Plane's public key (the Desk pins it as DESK_CONTROL_PLANE_PUBKEY). No secret is ever printed.
mod answer; mod core; mod db; mod h3srv; mod verify;
use std::sync::Arc;

fn need(k: &str) -> String { std::env::var(k).unwrap_or_else(|_| { eprintln!("control plane: {k} is not set"); std::process::exit(2) }) }
fn read(p: &str) -> Vec<u8> { std::fs::read(p).unwrap_or_else(|e| { eprintln!("control plane: {p}: {e}"); std::process::exit(2) }) }

#[tokio::main]
async fn main() {
    let signer = answer::Signer::from_seed_hex(&String::from_utf8_lossy(&read(&need("CP_SEED_FILE")))).unwrap_or_else(|| { eprintln!("control plane: CP_SEED_FILE is not a 32-byte hex seed"); std::process::exit(2) });
    if std::env::args().any(|a| a == "--print-pubkey") { println!("{}", signer.public_hex()); return; }
    let desk_pub = need("CP_DESK_PUBKEY");
    if verify::unhex(&desk_pub).map(|b| b.len()) != Some(32) { eprintln!("control plane: CP_DESK_PUBKEY is not a 32-byte hex key"); std::process::exit(2); }
    let tls = h3srv::server_config(&read(&need("CP_CERT")), &read(&need("CP_KEY"))).unwrap_or_else(|e| { eprintln!("control plane: {e}"); std::process::exit(2) });
    let addr: std::net::SocketAddr = need("CP_LISTEN").parse().unwrap_or_else(|_| { eprintln!("control plane: CP_LISTEN is not ip:port"); std::process::exit(2) });
    let ep = quinn::Endpoint::server(h3srv::quic_config(tls).unwrap_or_else(|e| { eprintln!("control plane: {e}"); std::process::exit(2) }), addr).unwrap_or_else(|e| { eprintln!("control plane: cannot listen on UDP {addr}: {e}"); std::process::exit(2) });
    let core = Arc::new(core::Core::new(desk_pub, signer, core::Source::Pg(db::Pg::new(need("CP_DB_URL"), std::env::var("CP_DB_CA").ok())), h3srv::now_secs()));
    eprintln!("control plane ready: HTTP/3 UDP {addr}, TLS 1.3 AES-256-GCM + X25519MLKEM768, answers signed with its own key");
    h3srv::serve(ep, core).await;
}
