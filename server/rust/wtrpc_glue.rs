// ============================================================================
// ANEXOMAIL — WebTransport RPC (`/wt/rpc`) (Rust PRIMARY). `mod wtrpc_core; mod wtrpc_glue;` main.rs mein judta hai (installer module `wtrpc`).
// Saari soch wtrpc_core.rs mein (std-only, tests). Yahan sirf I/O: wtransport session, har bidi stream = ek call.
//
// Kyun: poori website ke liye EK transport — WASM kernel (web-wasm, rpc@1) ek QUIC session rakhta hai; har proc (jo `/rpc/<proc>` par hai) bina
// naya endpoint likhe isi se guzarta hai. Dispatcher WOHI `dispatch()` hai jo HTTP `/rpc/<proc>` chalata hai => auth, package gates, rate limits,
// graceful errors sab ek jaise; koi alag raasta nahi jis se gate bach sake.
//
// Hifazat: har stream mein token (session anjaan rehta hai); request <= 1 MiB aur 10 s mein; jawab <= 8 MiB; ek session mein 64 calls ek saath;
// ek IP se 20 session; poore server par 512 calls ek saath; session idle 15 min / umar 1 ghanta.
// ============================================================================

use crate::wtrpc_core as c;
use axum::body::{to_bytes, Bytes};
use axum::extract::Path;
use axum::http::{HeaderMap, HeaderValue};
use axum::response::IntoResponse;
use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};
use tokio::sync::Semaphore;

const MAX_SESSIONS_PER_IP: usize = 20;
const MAX_STREAMS_GLOBAL: usize = 512;
const READ_TIMEOUT: Duration = Duration::from_secs(10);
const WRITE_TIMEOUT: Duration = Duration::from_secs(15);

static GLOBAL: OnceLock<Arc<Semaphore>> = OnceLock::new();
static PER_IP: OnceLock<Mutex<HashMap<String, usize>>> = OnceLock::new();

pub fn wants(path: &str) -> bool {
    c::is_rpc_path(path)
}

// Installer ka saancha har module se owns/dispatch maangta hai; yeh module koi proc nahi rakhta (transport hai) — isliye kabhi nahi pakadta.
pub fn owns(_proc: &str) -> bool {
    false
}
pub async fn dispatch(proc: &str, _token: &str, _input: &serde_json::Value) -> axum::response::Response {
    crate::err(axum::http::StatusCode::NOT_FOUND, "unknown_proc", proc).into_response()
}

/// IP ke session ginti ka guard: drop par ginti ghat'ti hai.
struct IpGuard(String);
impl IpGuard {
    fn take(ip: &str) -> Option<IpGuard> {
        let m = PER_IP.get_or_init(|| Mutex::new(HashMap::new()));
        let mut map = m.lock().ok()?;
        let n = map.entry(ip.to_string()).or_insert(0);
        if *n >= MAX_SESSIONS_PER_IP {
            return None;
        }
        *n += 1;
        Some(IpGuard(ip.to_string()))
    }
}
impl Drop for IpGuard {
    fn drop(&mut self) {
        if let Some(m) = PER_IP.get() {
            if let Ok(mut map) = m.lock() {
                if let Some(n) = map.get_mut(&self.0) {
                    *n = n.saturating_sub(1);
                    if *n == 0 {
                        map.remove(&self.0);
                    }
                }
            }
        }
    }
}

pub async fn serve(request: wtransport::endpoint::SessionRequest) {
    let ip = request.remote_address().ip().to_string();
    let Some(_ip_guard) = IpGuard::take(&ip) else {
        request.too_many_requests().await;
        return;
    };
    let Ok(conn) = request.accept().await else { return };
    let started = Instant::now();
    let per_session = Arc::new(Semaphore::new(c::MAX_STREAMS_PER_SESSION));
    let global = GLOBAL.get_or_init(|| Arc::new(Semaphore::new(MAX_STREAMS_GLOBAL))).clone();
    loop {
        let left = Duration::from_secs(c::SESSION_MAX_SECS).saturating_sub(started.elapsed());
        if left.is_zero() {
            break;
        }
        let wait = left.min(Duration::from_secs(c::SESSION_IDLE_SECS));
        let (send, recv) = match tokio::time::timeout(wait, conn.accept_bi()).await {
            Ok(Ok(s)) => s,
            _ => break, // client gaya / idle / umar poori
        };
        let (Ok(p1), Ok(p2)) = (per_session.clone().acquire_owned().await, global.clone().acquire_owned().await) else { break };
        let ip = ip.clone();
        tokio::spawn(async move {
            handle_stream(send, recv, &ip).await;
            drop((p1, p2));
        });
    }
    conn.close(wtransport::VarInt::from_u32(0), b"done");
}

async fn read_request(recv: &mut wtransport::RecvStream) -> Result<Vec<u8>, &'static str> {
    let mut out: Vec<u8> = Vec::new();
    let mut buf = vec![0u8; 16 * 1024];
    let fut = async {
        loop {
            match recv.read(&mut buf).await {
                Ok(Some(n)) => {
                    if out.len() + n > c::MAX_REQUEST {
                        return Err("request_too_large");
                    }
                    out.extend_from_slice(&buf[..n]);
                }
                Ok(None) => return Ok(()),
                Err(_) => return Err("read_failed"),
            }
        }
    };
    match tokio::time::timeout(READ_TIMEOUT, fut).await {
        Ok(Ok(())) => Ok(out),
        Ok(Err(e)) => Err(e),
        Err(_) => Err("request_timeout"),
    }
}

fn status_of(code: &str) -> u16 {
    match code {
        "request_too_large" => 413,
        "request_timeout" => 408,
        "token_required" => 401,
        "read_failed" => 400,
        _ => 400,
    }
}

async fn handle_stream(mut send: wtransport::SendStream, mut recv: wtransport::RecvStream, ip: &str) {
    let frame: String = match read_request(&mut recv).await {
        Err(code) => c::error_frame(status_of(code), code),
        Ok(bytes) => match c::parse_request(&bytes) {
            Err(code) => c::error_frame(status_of(code), code),
            Ok(req) => {
                let mut headers = HeaderMap::new();
                match HeaderValue::from_str(&format!("Bearer {}", req.token)) {
                    Ok(v) => {
                        headers.insert("authorization", v);
                        headers.insert("content-type", HeaderValue::from_static("application/json"));
                        if let Ok(v) = HeaderValue::from_str(ip) {
                            headers.insert("x-forwarded-for", v.clone());
                            headers.insert("x-real-ip", v);
                        }
                        headers.insert("x-anexo-transport", HeaderValue::from_static("webtransport"));
                        let body = Bytes::from(c::dispatcher_body(req.input_raw));
                        let resp = crate::dispatch(Path(req.proc_name), headers, Ok(body)).await;
                        let status = resp.status().as_u16();
                        match to_bytes(resp.into_body(), c::MAX_RESPONSE).await {
                            Ok(b) => {
                                let text = String::from_utf8_lossy(&b).into_owned();
                                let is_json = serde_json::from_str::<serde::de::IgnoredAny>(&text).is_ok();
                                c::compose(status, &text, is_json)
                            }
                            Err(_) => c::error_frame(413, "response_too_large"),
                        }
                    }
                    Err(_) => c::error_frame(401, "token_required"),
                }
            }
        },
    };
    let write = async {
        if send.write_all(frame.as_bytes()).await.is_ok() {
            let _ = send.finish().await;
        }
    };
    let _ = tokio::time::timeout(WRITE_TIMEOUT, write).await;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_rpc_path_is_ours() {
        assert!(wants("/wt/rpc") && !wants("/wt/events") && !wants("/wt"));
    }

    #[test]
    fn ip_guard_caps_sessions_and_releases_on_drop() {
        let ip = "203.0.113.77";
        let guards: Vec<_> = (0..MAX_SESSIONS_PER_IP).map(|_| IpGuard::take(ip).expect("under cap")).collect();
        assert!(IpGuard::take(ip).is_none(), "21st session from one IP is refused");
        assert!(IpGuard::take("203.0.113.78").is_some(), "another IP is unaffected");
        drop(guards);
        assert!(IpGuard::take(ip).is_some(), "slots come back");
    }

    #[test]
    fn error_codes_map_to_http_like_statuses() {
        assert_eq!(status_of("request_too_large"), 413);
        assert_eq!(status_of("request_timeout"), 408);
        assert_eq!(status_of("token_required"), 401);
        assert_eq!(status_of("bad_proc"), 400);
    }
}
