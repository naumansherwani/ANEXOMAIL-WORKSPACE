// ANEXOMAIL ADMIN DESK probes.rs (R4-1b step 2, 22 Nov 2026): the Desk Bridge heartbeat. HIS RULE (22 Nov 03:52 + 03:57): 100% HONEST TELEMETRY.
// Four real probes every 4 seconds (database, signer, HTTP/3 edge, TLS handshake) and two every 60 seconds (ledger chain, ClamAV). The database (AD3 fadm_service_state)
// shows a service UNKNOWN once its last probe is older than 3 intervals (12 s for the 4 s probes): never a cached green.
// A service with no probe in this file (mail_in, mail_out, dns, storage_box) stays UNKNOWN on purpose until its own probe exists. ClamAV is probed only when DESK_CLAMD_SOCK
// names the clamd socket (0.1% doubt about his server = no guess): no variable, no probe, UNKNOWN.
// Talks to PostgreSQL ONLY as desk_app, only through desk.fadm_probe_record (AD3). Tech: Rust, Tokio, QUIC self-handshake (h3::selfcheck), Ed25519 sign+verify round trip.
use crate::{door, h3, signed};
use std::time::{Duration, Instant};

pub const FAST: Duration = Duration::from_secs(4);
pub const SLOW: Duration = Duration::from_secs(60);

/// One call of the database door. Service names are constants below, never user input; detail goes through `lit`.
pub fn probe_sql(service: &str, ok: bool, ms: Option<u128>, detail: &str) -> String {
    let ms = ms.map(|m| m.min(600_000).to_string()).unwrap_or_else(|| "NULL".into());
    let d = serde_json::json!({ "note": detail.chars().take(200).collect::<String>() }).to_string();
    format!("select desk.fadm_probe_record({}, {}, {}, {}::jsonb)::text", door::lit(service), ok, ms, door::lit(&d))
}

async fn record(service: &str, ok: bool, ms: Option<u128>, detail: &str) {
    let Ok(c) = door::connect().await else { return };   // no database = nothing can be recorded; the state turns UNKNOWN by itself
    if let Err(e) = door::rows(&c, &probe_sql(service, ok, ms, detail)).await { eprintln!("desk probe {service}: record failed: {e}"); }
}

async fn probe_db() {
    let t = Instant::now();
    let ok = match door::connect().await { Ok(c) => door::rows(&c, "select 1").await.is_ok(), Err(_) => false };
    record("db", ok, Some(t.elapsed().as_millis()), if ok { "select 1" } else { "database not answering" }).await;
}
async fn probe_signer() {
    let t = Instant::now();
    let ok = signed::selftest();
    record("signer", ok, Some(t.elapsed().as_millis()), if ok { "sign + verify round trip" } else { "signing key missing or broken" }).await;
}
// The edge and the handshake are measured by one real QUIC connection to our own UDP listener (TLS 1.3, AES-256-GCM, X25519MLKEM768 only: the client offers nothing else).
async fn probe_edge() {
    let (Ok(addr), Ok(certf)) = (std::env::var("DESK_H3_ADDR"), std::env::var("DESK_H3_CERT")) else { return };   // HTTP/3 off = no probe = UNKNOWN
    let Ok(sa) = addr.parse::<std::net::SocketAddr>() else { return };
    let target = std::net::SocketAddr::new(std::net::IpAddr::from([127, 0, 0, 1]), sa.port());
    let Ok(cert) = std::fs::read(&certf) else { return };
    let t = Instant::now();
    let r = tokio::time::timeout(Duration::from_secs(3), h3::selfcheck(target, crate::HOST, &cert)).await;
    let ms = t.elapsed().as_millis();
    let (ok, note) = match r { Ok(Ok(_)) => (true, "h3 handshake ok".to_string()), Ok(Err(e)) => (false, e), Err(_) => (false, "timeout 3 s".to_string()) };
    record("h3_edge", ok, Some(ms), &note).await;
    record("tls", ok, Some(ms), if ok { "TLS 1.3 AES-256-GCM X25519MLKEM768" } else { "handshake failed" }).await;
}
async fn probe_ledger() {
    let t = Instant::now();
    let (ok, note) = match door::connect().await {
        Ok(c) => match door::rows(&c, "select desk.fadm_ledger_verify()::text").await { Ok(v) => (v.first().and_then(|r| r.get(0)) == Some("true"), "chain verify".to_string()), Err(e) => (false, e.to_string()) },
        Err(e) => (false, e),
    };
    record("ledger", ok, Some(t.elapsed().as_millis()), if ok { "SHA-256 chain verifies" } else { &note }).await;
}
// clamd answers PONG to PING on its unix socket. Only when the socket path is given.
async fn probe_clamav() {
    let Ok(sock) = std::env::var("DESK_CLAMD_SOCK") else { return };
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    let t = Instant::now();
    let r = tokio::time::timeout(Duration::from_secs(3), async {
        let mut s = tokio::net::UnixStream::connect(&sock).await.map_err(|e| e.to_string())?;
        s.write_all(b"zPING\0").await.map_err(|e| e.to_string())?;
        let mut b = [0u8; 16]; let n = s.read(&mut b).await.map_err(|e| e.to_string())?;
        Ok::<bool, String>(b[..n].starts_with(b"PONG"))
    }).await;
    let (ok, note) = match r { Ok(Ok(true)) => (true, "PONG".to_string()), Ok(Ok(false)) => (false, "unexpected answer".to_string()), Ok(Err(e)) => (false, e), Err(_) => (false, "timeout 3 s".to_string()) };
    record("clamav", ok, Some(t.elapsed().as_millis()), &note).await;
}

/// Started once from main. Each probe runs in its own task so one slow probe never delays another.
pub fn spawn_all() {
    macro_rules! every { ($d:expr, $f:ident) => { tokio::spawn(async move { let mut i = tokio::time::interval($d); i.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip); loop { i.tick().await; $f().await; } }); }; }
    every!(FAST, probe_db); every!(FAST, probe_signer); every!(FAST, probe_edge); every!(SLOW, probe_ledger); every!(SLOW, probe_clamav);
    eprintln!("desk: Bridge probes running (db, signer, h3_edge, tls every 4 s; ledger, clamav every 60 s)");
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn probe_sql_shape_and_quoting() {
        let q = probe_sql("db", true, Some(3), "it's fine");
        assert_eq!(q, "select desk.fadm_probe_record('db', true, 3, '{\"note\":\"it''s fine\"}'::jsonb)::text");
        assert!(probe_sql("db", false, None, "x").contains(", false, NULL, "));
    }
    #[test] fn latency_is_capped_to_the_column_limit() { assert!(probe_sql("db", true, Some(9_999_999), "").contains(", true, 600000, ")); }
    #[test] fn detail_is_cut_to_200_chars() { let q = probe_sql("db", true, Some(1), &"a".repeat(500)); assert!(q.len() < 330); }
    #[test] fn probe_intervals_match_his_12_second_rule() { assert_eq!(FAST.as_secs() * 3, 12); }
}
