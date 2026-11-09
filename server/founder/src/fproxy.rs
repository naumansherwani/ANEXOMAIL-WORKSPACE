//! K4.2 (founder, 7 Nov 2026): the legacy-path proxy of the own TLS terminator. Technology: Rust (axum middleware + reqwest/rustls), inside the founder binary.
//! Why: Caddy still owns the OLD founder-host routes (`/founderlogin`, `/app*`, `/api/*` = the old awam-app login). When the AES-256 terminator takes the real :443 for this host (K4.5) it must hand every path that is not ours to the
//! upstream. Everything the terminator itself serves (`/`, `/_cc/*`, `/founder/v1/*`) never leaves this process.
//! Safety rules, all pure and tested: (1) a closed table of what WE serve (everything else is the old app's, as in Caddy); (2) the upstream is explicit (FOUNDER_LEGACY_UPSTREAM=host:port), OFF when unset, and it can never be our own listener (no loop);
//! (3) hop-by-hop and client-supplied forwarding headers are stripped both ways, so a client cannot spoof its address to the old app; (4) redirects are not followed (the browser follows them); (5) bodies are capped;
//! (6) the proxied answer keeps the OLD app's own headers (its CSP, cookies) and only gets `Alt-Svc: clear`, so a browser that learned h3 from Caddy forgets it and stops bypassing the AES-256 terminator.
use axum::body::Body;
use axum::extract::Request;
use axum::http::{header, HeaderMap, HeaderName, HeaderValue, StatusCode};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use std::sync::OnceLock;
use std::time::Duration;

/// The host name the old app answers to (SNI + Host header towards the upstream).
pub const HOST: &str = "founderworkspace.anexomail.com";
const MAX_BODY: usize = 25 * 1024 * 1024;

struct Up { client: reqwest::Client, base: String }
static UP: OnceLock<Up> = OnceLock::new();

/// What THIS process answers itself on the real host (exactly Caddy's routes today: `/` alone, `/_cc/*`, `/founder/v1/*`, the old `/f` bookmarks). Everything else on that host belongs to the old app
/// (`/founderlogin`, `/app*`, `/api/*`, its `/assets/*`, icons, manifest ...), so it is handed upstream. The table is closed on OUR side: a new path is never served by accident.
pub fn is_ours(path: &str) -> bool {
    path == "/" || path == "/f" || path == "/f/" || path == "/_cc" || path.starts_with("/_cc/") || path.starts_with("/founder/v1/")
}
pub fn is_legacy(path: &str) -> bool { !is_ours(path) }

/// G-MIX (founder 9 Nov 2026, SEPARATION LAW): the awam workspace must never open on the founder host. The old app is a single-page app, so `/app*` (dashboard, inbox, calendar) and the awam sign-in `/auth`, `/signup`
/// would render the AWAM product here. They are NOT handed upstream: `/app*` goes to our own Command Center `/`, `/auth` and `/signup` go to the founder sign-in. Only the old founder sign-in page and its `/api/auth*` calls still cross, until the native login (G-MIX stage 2) replaces them.
pub fn awam_redirect(path: &str) -> Option<&'static str> {
    if path == "/app" || path.starts_with("/app/") { return Some("/"); }
    if path == "/auth" || path.starts_with("/auth/") || path == "/signup" || path.starts_with("/signup/") { return Some("/founderlogin"); }
    None
}

/// `host:port` -> validated address. Rejects empty, no port, a port of 0, and anything that is not a plain host:port (no scheme, no path).
pub fn parse_upstream(v: &str) -> Result<(String, u16), String> {
    let v = v.trim();
    let (h, p) = v.rsplit_once(':').ok_or("FOUNDER_LEGACY_UPSTREAM must be host:port")?;
    let port: u16 = p.parse().map_err(|_| "upstream port is not a number")?;
    if port == 0 || h.is_empty() || !h.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'-') { return Err("upstream host is not a plain host name or IPv4".into()); }
    Ok((h.to_string(), port))
}

/// No loop: the upstream must not be the port this process listens on for TLS.
pub fn not_own_listener(up_port: u16, own_tls_addr: Option<&str>) -> bool { own_tls_addr.and_then(|a| a.rsplit_once(':')).and_then(|(_, p)| p.parse::<u16>().ok()) != Some(up_port) }

const HOP: [&str; 9] = ["connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailer", "transfer-encoding", "upgrade", "proxy-connection"];
const FORWARDING: [&str; 6] = ["x-forwarded-for", "x-forwarded-host", "x-forwarded-proto", "x-real-ip", "forwarded", "via"];

/// Request headers for the upstream: no hop-by-hop, no client-supplied forwarding headers, no Host (set from HOST), no content-length (reqwest sets it).
pub fn request_headers(h: &HeaderMap) -> HeaderMap {
    let mut o = HeaderMap::new();
    for (k, v) in h {
        let n = k.as_str();
        if HOP.contains(&n) || FORWARDING.contains(&n) || n == "host" || n == "content-length" { continue; }
        o.append(k.clone(), v.clone());
    }
    o
}
/// Response headers to the browser: no hop-by-hop, no upstream Alt-Svc (we say `clear`), no content-length (the body is streamed).
pub fn response_headers(h: &HeaderMap) -> HeaderMap {
    let mut o = HeaderMap::new();
    for (k, v) in h {
        let n = k.as_str();
        if HOP.contains(&n) || n == "alt-svc" || n == "content-length" { continue; }
        o.append(k.clone(), v.clone());
    }
    o.insert(HeaderName::from_static("alt-svc"), HeaderValue::from_static("clear"));
    o
}

/// Startup: FOUNDER_LEGACY_UPSTREAM=127.0.0.1:443 today (Caddy answers for the host), 127.0.0.1:8444 after the switch. Unset = the paths answer 404 exactly as before.
pub fn init_from_env(own_tls_addr: Option<&str>) {
    let Some(v) = std::env::var("FOUNDER_LEGACY_UPSTREAM").ok().filter(|v| !v.trim().is_empty()) else { eprintln!("founder: legacy path proxy OFF (no FOUNDER_LEGACY_UPSTREAM)"); return };
    let (h, port) = match parse_upstream(&v) { Ok(x) => x, Err(e) => { eprintln!("founder: legacy path proxy OFF: {e}"); return } };
    if !not_own_listener(port, own_tls_addr) { eprintln!("founder: legacy path proxy OFF: the upstream is this process's own TLS port (would loop)"); return; }
    let ip: std::net::IpAddr = match h.parse() { Ok(i) => i, Err(_) => { eprintln!("founder: legacy path proxy OFF: the upstream must be an IP address (it is connected to directly)"); return } };
    // connect to the given address but speak TLS for the real host name: the certificate check stays ON
    let client = match reqwest::Client::builder().resolve(HOST, std::net::SocketAddr::new(ip, port)).redirect(reqwest::redirect::Policy::none()).timeout(Duration::from_secs(60)).connect_timeout(Duration::from_secs(5)).build() {
        Ok(c) => c, Err(e) => { eprintln!("founder: legacy path proxy OFF: {e}"); return }
    };
    let _ = UP.set(Up { client, base: format!("https://{HOST}:{port}") });
    eprintln!("founder: legacy path proxy ON ({h}:{port}, TLS name {HOST}): /founderlogin /app /api");
}

fn bad_gateway() -> Response { (StatusCode::BAD_GATEWAY, [(header::CACHE_CONTROL, "no-store")], "The old sign-in service did not answer.").into_response() }

/// Outermost middleware: legacy paths go upstream, everything else continues untouched. When the proxy is off, nothing changes.
pub async fn layer(req: Request, next: Next) -> Response {
    if let Some(to) = awam_redirect(req.uri().path()) {
        let mut r = Response::new(Body::empty()); *r.status_mut() = StatusCode::FOUND;
        r.headers_mut().insert(header::LOCATION, HeaderValue::from_static(to)); r.headers_mut().insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
        r.headers_mut().insert(HeaderName::from_static("alt-svc"), HeaderValue::from_static("clear"));
        return r;
    }
    let (Some(up), true) = (UP.get(), is_legacy(req.uri().path())) else { return next.run(req).await };
    let (parts, body) = req.into_parts();
    let url = format!("{}{}", up.base, parts.uri.path_and_query().map(|p| p.as_str()).unwrap_or("/"));
    let Ok(bytes) = axum::body::to_bytes(body, MAX_BODY).await else { return StatusCode::PAYLOAD_TOO_LARGE.into_response() };
    let Ok(method) = reqwest::Method::from_bytes(parts.method.as_str().as_bytes()) else { return StatusCode::METHOD_NOT_ALLOWED.into_response() };
    let r = up.client.request(method, url).headers(request_headers(&parts.headers)).header(header::HOST, HOST).body(bytes).send().await;
    let Ok(r) = r else { return bad_gateway() };
    let status = StatusCode::from_u16(r.status().as_u16()).unwrap_or(StatusCode::BAD_GATEWAY);
    let mut hd = HeaderMap::new();
    for (k, v) in r.headers() { if let (Ok(n), Ok(val)) = (HeaderName::from_bytes(k.as_str().as_bytes()), HeaderValue::from_bytes(v.as_bytes())) { hd.append(n, val); } }
    let hd = response_headers(&hd);
    // stream the answer chunk by chunk (no reqwest `stream` feature needed): an old-app event stream is not buffered
    let body = futures_util::stream::unfold(r, |mut r| async move { match r.chunk().await { Ok(Some(c)) => Some((Ok::<_, std::io::Error>(c), r)), _ => None } });
    let mut out = Response::new(Body::from_stream(body));
    *out.status_mut() = status; *out.headers_mut() = hd;
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn we_serve_only_our_own_routes_and_everything_else_is_the_old_apps() {
        for p in ["/", "/f", "/f/", "/_cc", "/_cc/", "/_cc/assets/index-x.js", "/_cc/kernel/anexo-kernel-0.13.0.wasm", "/founder/v1/me", "/founder/v1/vault/lease"] { assert!(is_ours(p) && !is_legacy(p), "{p}"); }
        for p in ["/founderlogin", "/app", "/app/founder", "/api/auth/refresh", "/assets/index-CyAOzGvs.js", "/favicon.svg", "/manifest.webmanifest", "/apple-touch-icon.png", "/_ccx/a", "/founder/v1", "/founder", "/f2", "/healthz"] { assert!(is_legacy(p), "{p}"); }
    }
    #[test]
    fn the_awam_app_never_opens_on_the_founder_host() {
        for (p, to) in [("/app", "/"), ("/app/", "/"), ("/app/inbox", "/"), ("/app/founder/ai", "/"), ("/auth", "/founderlogin"), ("/auth/x", "/founderlogin"), ("/signup", "/founderlogin")] { assert_eq!(awam_redirect(p), Some(to), "{p}"); }
        for p in ["/", "/founderlogin", "/api/auth/refresh", "/assets/a.js", "/application", "/authx", "/f", "/_cc/a", "/founder/v1/me"] { assert_eq!(awam_redirect(p), None, "{p}"); }
    }
    #[test]
    fn the_upstream_is_a_plain_host_port_and_never_our_own_port() {
        assert_eq!(parse_upstream(" 127.0.0.1:8444 ").unwrap(), ("127.0.0.1".into(), 8444));
        for v in ["", "127.0.0.1", "127.0.0.1:0", "127.0.0.1:99999", "http://127.0.0.1:80", "a/b:80", ":80", "127.0.0.1:x", "evil.com/x:80"] { assert!(parse_upstream(v).is_err(), "{v}"); }
        assert!(!not_own_listener(8443, Some("0.0.0.0:8443"))); assert!(not_own_listener(8444, Some("0.0.0.0:8443"))); assert!(not_own_listener(443, None));
    }
    #[test]
    fn forwarding_headers_cannot_be_spoofed_and_hop_by_hop_never_crosses() {
        let mut h = HeaderMap::new();
        for (k, v) in [("x-forwarded-for", "1.2.3.4"), ("x-real-ip", "1.2.3.4"), ("forwarded", "for=1.2.3.4"), ("host", "evil"), ("connection", "close"), ("transfer-encoding", "chunked"), ("upgrade", "websocket"), ("content-length", "5"), ("cookie", "a=b"), ("authorization", "Bearer x"), ("content-type", "application/json")] { h.append(HeaderName::from_bytes(k.as_bytes()).unwrap(), HeaderValue::from_static(v)); }
        let o = request_headers(&h);
        for gone in ["x-forwarded-for", "x-real-ip", "forwarded", "host", "connection", "transfer-encoding", "upgrade", "content-length"] { assert!(o.get(gone).is_none(), "{gone}"); }
        for kept in ["cookie", "authorization", "content-type"] { assert!(o.get(kept).is_some(), "{kept}"); }
    }
    #[test]
    fn the_answer_forgets_h3_and_keeps_the_old_apps_own_headers() {
        let mut h = HeaderMap::new();
        for (k, v) in [("alt-svc", "h3=\":443\"; ma=2592000"), ("set-cookie", "s=1; HttpOnly"), ("content-security-policy", "default-src 'self'"), ("connection", "keep-alive"), ("content-length", "9")] { h.append(HeaderName::from_bytes(k.as_bytes()).unwrap(), HeaderValue::from_static(v)); }
        let o = response_headers(&h);
        assert_eq!(o.get("alt-svc").unwrap(), "clear"); assert_eq!(o.get_all("alt-svc").iter().count(), 1);
        assert!(o.get("set-cookie").is_some() && o.get("content-security-policy").is_some());
        assert!(o.get("connection").is_none() && o.get("content-length").is_none());
    }
}
