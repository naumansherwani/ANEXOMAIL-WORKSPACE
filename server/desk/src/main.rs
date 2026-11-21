// ANEXOMAIL ADMIN DESK, R3a0 (21 Nov 2026): its own process on loopback 127.0.0.1:4400 (Caddy proxies admindesk.anexomail.com to it).
// Tech: Rust, Tokio, axum. Stage 2 (SNI front + HTTP/3, AES-256-GCM, X25519MLKEM768) comes later; until then NO TLS promise is made by this process.
// Honest by design: the login door answers 503 "not connected" until R3a2 (SQL E201 + ARGON2ID) exists. Nothing here is a mock.
use axum::{
    Router,
    extract::Request,
    http::{HeaderValue, StatusCode, header},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use tower_http::services::{ServeDir, ServeFile};

const HOST: &str = "admindesk.anexomail.com";
const BIND: &str = "127.0.0.1:4400";
const DIST: &str = "/opt/anexomail-desk/dist-desk";

// A wrong Host never reaches a page: 404, and one line in the journal (the ledger line arrives with R3a2).
async fn host_gate(req: Request, next: Next) -> Response {
    let ok = req
        .headers()
        .get(header::HOST)
        .and_then(|h| h.to_str().ok())
        .map(|h| h.split(':').next().unwrap_or("").eq_ignore_ascii_case(HOST))
        .unwrap_or(false);
    if !ok {
        eprintln!("desk: wrong host refused: {:?}", req.headers().get(header::HOST));
        return StatusCode::NOT_FOUND.into_response();
    }
    next.run(req).await
}

// Desk headers: CSP self-only + Trusted Types, COOP/CORP, HSTS, no sniffing, no referrer, no framing.
async fn desk_headers(req: Request, next: Next) -> Response {
    let mut res = next.run(req).await;
    let h = res.headers_mut();
    let set = |h: &mut axum::http::HeaderMap, k: &'static str, v: &'static str| {
        h.insert(header::HeaderName::from_static(k), HeaderValue::from_static(v));
    };
    set(h, "content-security-policy", "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'; require-trusted-types-for 'script'");
    set(h, "cross-origin-opener-policy", "same-origin");
    set(h, "cross-origin-resource-policy", "same-origin");
    set(h, "strict-transport-security", "max-age=63072000; includeSubDomains");
    set(h, "x-content-type-options", "nosniff");
    set(h, "referrer-policy", "no-referrer");
    set(h, "x-frame-options", "DENY");
    set(h, "cache-control", "no-store");
    res
}

async fn health() -> impl IntoResponse {
    (StatusCode::OK, [(header::CONTENT_TYPE, "application/json")], r#"{"desk":"up","login":"not-connected"}"#)
}

// R3a2 replaces this with the real ARGON2ID door. Until then it says the truth.
async fn login_not_connected() -> impl IntoResponse {
    (StatusCode::NOT_FOUND, [(header::CONTENT_TYPE, "application/json")], r#"{"error":"desk login not connected"}"#)
}

#[tokio::main]
async fn main() {
    let index = format!("{DIST}/desk.html");
    let files = ServeDir::new(DIST).not_found_service(ServeFile::new(index));
    let app = Router::new()
        .route("/desk/v1/health", get(health))
        .route("/desk/v1/auth/login", post(login_not_connected))
        .fallback_service(files)
        .layer(middleware::from_fn(desk_headers))
        .layer(middleware::from_fn(host_gate));
    let listener = tokio::net::TcpListener::bind(BIND).await.expect("bind 127.0.0.1:4400");
    eprintln!("desk: listening on {BIND} (loopback only)");
    axum::serve(listener, app).await.expect("serve");
}
