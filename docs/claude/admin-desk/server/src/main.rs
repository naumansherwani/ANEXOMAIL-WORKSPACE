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

mod auth;
mod door;
mod h3;
mod probes;
mod bridge;
mod lookup;
mod sign;
mod wt;
mod signed;

pub const HOST: &str = "admindesk.anexomail.com";
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
    set(h, "content-security-policy", "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://admindesk.anexomail.com:4400; frame-ancestors 'none'; base-uri 'none'; form-action 'self'; require-trusted-types-for 'script'");
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

#[tokio::main]
async fn main() {
    // `anexomail-desk h3check <ip:port> <host> <cert.pem>`: the proof client (PQ + AES-256 only) for his server
    let a: Vec<String> = std::env::args().collect();
    // `anexomail-desk hashpw`: reads ONE password line from stdin (typed on his server by desk-owner.sh), prints only the ARGON2ID hash. Never prints or logs the password.
    if a.get(1).map(String::as_str) == Some("hashpw") {
        let mut l = String::new();
        std::io::stdin().read_line(&mut l).ok();
        match auth::hash_password(l.trim_end_matches(['\n', '\r'])) { Ok(h) => { println!("{h}"); return; } Err(e) => { eprintln!("hashpw: {e}"); std::process::exit(3); } }
    }
    if a.get(1).map(String::as_str) == Some("h3check") && a.len() == 5 {
        let cert = std::fs::read(&a[4]).expect("cert file");
        match h3::selfcheck(a[2].parse().expect("ip:port"), &a[3], &cert).await { Ok(o) => { println!("H3CHECK OK: {o} (handshake = TLS 1.3, AES-256-GCM, X25519MLKEM768: the client offered nothing else)"); return; } Err(e) => { println!("H3CHECK FAIL: {e}"); std::process::exit(1); } }
    }
    tokio::spawn(door::warm());
    let index = format!("{DIST}/desk.html");
    let files = ServeDir::new(DIST).fallback(ServeFile::new(index));
    signed::init();
    probes::spawn_all();   // after the key is loaded, so the first signer probe is a real one
    // R3d (Rule 52): every door below `sealed` answers ONLY as a Desk-signed envelope; calls after sign-in must carry the request MAC (signed.rs).
    let sealed = Router::new()
        .route("/desk/v1/auth/login", post(door::login))
        .route("/desk/v1/auth/me", get(door::me))
        .route("/desk/v1/auth/logout", post(door::logout))
        .route("/desk/v1/sig/ping", get(signed::ping))
        .route("/desk/v1/bridge/summary", get(bridge::summary))
        .route("/desk/v1/bridge/services", get(bridge::services))
        .route("/desk/v1/bridge/alerts", get(bridge::alerts))
        .route("/desk/v1/bridge/alerts/act", post(bridge::alert_act))
        .route("/desk/v1/customer/lookup", post(lookup::lookup))
        .layer(middleware::from_fn(signed::guard));
    let app = Router::new()
        .route("/desk/v1/health", get(health))
        .route("/desk/v1/key", get(signed::key))
        .merge(sealed)
        .fallback_service(files)
        .layer(middleware::from_fn(desk_headers))
        .layer(middleware::from_fn(host_gate));
    // R3a0-s2: the Desk's OWN HTTP/3 (QUIC, TLS 1.3 AES-256-GCM, X25519MLKEM768 first). Off unless DESK_H3_ADDR is set (its UDP port comes only from his fresh ss).
    let mut app = app;
    match h3::from_env() {
        None => eprintln!("desk: HTTP/3 is OFF (DESK_H3_ADDR not set)"),
        Some(Err(e)) => { eprintln!("desk: HTTP/3 REFUSED to start: {e}"); std::process::exit(2); }
        Some(Ok((addr, tls))) => {
            let port = addr.port();
            let qc = h3::quic_config(tls).expect("desk h3 quic config");
            let ep = quinn::Endpoint::server(qc, addr).expect("bind desk udp");
            eprintln!("desk: HTTP/3 listening on udp {addr} (TLS 1.3, AES-256-GCM only, X25519MLKEM768 first)");
            let alt = HeaderValue::from_str(&h3::alt_svc_value(port)).expect("alt-svc");
            app = app.layer(middleware::from_fn(move |req: Request, next: Next| { let alt = alt.clone(); async move { let mut r = next.run(req).await; r.headers_mut().insert(header::HeaderName::from_static("alt-svc"), alt); r } }));
            let fetch: wt::Fetch = std::sync::Arc::new(|t: String, track: &'static str| Box::pin(async move { bridge::track(&t, track).await }));
            tokio::spawn(h3::serve(ep, app.clone(), HOST.to_string(), Some(std::sync::Arc::new(wt::Cfg { host: HOST.to_string(), fetch }))));
        }
    }
    let listener = tokio::net::TcpListener::bind(BIND).await.expect("bind 127.0.0.1:4400");
    eprintln!("desk: listening on {BIND} (loopback only)");
    axum::serve(listener, app).await.expect("serve");
}
