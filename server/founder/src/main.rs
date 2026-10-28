//! anexomail-founder — F1b foundation: sirf health + military-level headers. Login/RPC agle phases mein.
mod audit;

use axum::{Router, http::{HeaderName, HeaderValue}, routing::get};
use tower_http::set_header::SetResponseHeaderLayer;

fn hdr(n: &'static str, v: &'static str) -> SetResponseHeaderLayer<HeaderValue> {
    SetResponseHeaderLayer::overriding(HeaderName::from_static(n), HeaderValue::from_static(v))
}

pub fn app() -> Router {
    Router::new()
        .route("/healthz", get(|| async { "ok" }))
        .layer(hdr("content-security-policy", "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'; require-trusted-types-for 'script'"))
        .layer(hdr("strict-transport-security", "max-age=63072000; includeSubDomains; preload"))
        .layer(hdr("x-content-type-options", "nosniff"))
        .layer(hdr("referrer-policy", "no-referrer"))
        .layer(hdr("cross-origin-opener-policy", "same-origin"))
        .layer(hdr("cross-origin-embedder-policy", "require-corp"))
        .layer(hdr("cache-control", "no-store"))
}

#[tokio::main]
async fn main() {
    let addr = std::env::var("FOUNDER_BIND").unwrap_or_else(|_| "127.0.0.1:3210".into());
    let l = tokio::net::TcpListener::bind(&addr).await.expect("bind");
    axum::serve(l, app()).await.expect("serve");
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{body::Body, http::Request};
    use tower::ServiceExt;
    #[tokio::test]
    async fn health_has_hardening_headers() {
        let r = app().oneshot(Request::get("/healthz").body(Body::empty()).unwrap()).await.unwrap();
        assert_eq!(r.status(), 200);
        let h = r.headers();
        assert!(h["content-security-policy"].to_str().unwrap().contains("frame-ancestors 'none'"));
        assert_eq!(h["cache-control"], "no-store");
    }
}
