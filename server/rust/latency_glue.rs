// latency_glue — AX9b: p50 / p95 / p99 of every /rpc/* and /file/* request, measured by ONE axum middleware layer (Rust only, std-only core `latency_core.rs`).
// No proc, no database, no SQL. The numbers appear on the localhost-only observability port (:3600 /metrics) as `anexomail_latency_us{probe,quantile}`.
// Honest limits: `/wt/rpc` (WebTransport) is NOT measured by this layer (it is not an axum request); the web probe has no caller yet.
use crate::latency_core as lc;
use axum::{extract::Request, middleware::Next, response::IntoResponse, response::Response};
use std::time::Instant;

pub fn owns(_proc: &str) -> bool {
    false
}
pub async fn dispatch(proc: &str, _token: &str, _input: &serde_json::Value) -> Response {
    crate::err(axum::http::StatusCode::NOT_FOUND, "unknown_proc", proc).into_response()
}

/// Times the request from first byte read to last byte handed on, then records it in the matching probe (lock-free, no allocation).
pub async fn mw(req: Request, next: Next) -> Response {
    let probe = lc::probe_for_path(req.uri().path());
    let t0 = Instant::now();
    let res = next.run(req).await;
    lc::probe(probe).record(t0.elapsed());
    res
}

pub fn prometheus() -> String {
    lc::render_prometheus()
}
