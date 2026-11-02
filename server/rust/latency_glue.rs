// latency_glue — AX9b: p50 / p95 / p99 of every /rpc/* and /file/* request, measured by ONE axum middleware layer (Rust only, std-only core `latency_core.rs`).
// No proc, no database, no SQL, ONE hook in main.rs (the layer). The numbers are served by this module itself on a localhost-only port, 127.0.0.1:3601 `/latency`,
// as `anexomail_latency_us{probe,quantile}` (started on the first request; Caddy never proxies it).
// Honest limits: `/wt/rpc` (WebTransport) is NOT measured by this layer (it is not an axum request); the web probe has no caller yet.
use crate::latency_core as lc;
use axum::{extract::Request, middleware::Next, response::IntoResponse, response::Response};
use std::sync::OnceLock;
use std::time::Instant;

static LISTENER: OnceLock<()> = OnceLock::new();

async fn numbers() -> String {
    lc::render_prometheus()
}

/// Starts the localhost-only numbers page once. A bind failure (port busy) is ignored: measuring goes on, only the page is missing.
fn start_listener() {
    LISTENER.get_or_init(|| {
        tokio::spawn(async {
            let app = axum::Router::new().route("/latency", axum::routing::get(numbers));
            if let Ok(l) = tokio::net::TcpListener::bind(std::net::SocketAddr::from(([127, 0, 0, 1], 3601))).await {
                let _ = axum::serve(l, app).await;
            }
        });
    });
}

pub fn owns(_proc: &str) -> bool {
    false
}
pub async fn dispatch(proc: &str, _token: &str, _input: &serde_json::Value) -> Response {
    crate::err(axum::http::StatusCode::NOT_FOUND, "unknown_proc", proc).into_response()
}

/// Times the request from first byte read to last byte handed on, then records it in the matching probe (lock-free, no allocation).
pub async fn mw(req: Request, next: Next) -> Response {
    start_listener();
    let probe = lc::probe_for_path(req.uri().path());
    let t0 = Instant::now();
    let res = next.run(req).await;
    lc::probe(probe).record(t0.elapsed());
    res
}

