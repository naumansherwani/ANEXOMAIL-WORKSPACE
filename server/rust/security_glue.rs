// ============================================================================
// security_glue.rs — I/O half of the Security page (Rust PRIMARY; Bun /api/security/* stays as fallback).
//
// Before (20 Oct 2026 live audit): every number came from tables nothing writes to — "Live sessions 0" for a signed-in
// user, "Kill" ended nothing, "Encryption: needs attention" because a table was empty, "Rotate keys" only wrote a row.
// Now each answer comes from the real record (E39 SQL, service_role only):
//   security.dashboard   -> sec_dashboard (auth.sessions, device_vault, ledger) + live TLS probes        (score: security_core)
//   security.sessions    -> sec_sessions  (auth.sessions; "this device" = the session inside YOUR token)
//   security.killSession -> sec_session_kill (deletes the auth session => its refresh token dies, and /auth/v1/user
//                           refuses the old access token at once — Rust and Bun both check every request there)
//   security.killSwitch  -> sec_kill_switch  (every OTHER session; hash-chained ledger entry)
//   security.history     -> sec_logins (auth.audit_log_entries: real sign-ins with network; first-time network flagged)
//   security.disown      -> "this wasn't me": ends every other session (same as kill switch) + ledger
//   security.encryption  -> live handshakes from this server: HTTPS 443, IMAP 993, SMTP 587 + 25 (STARTTLS),
//                           certificate checked against public roots; at rest = Supabase (AES-256, provider-managed)
//   security.rotate      -> 409 honest: keys are provider-managed, nothing to rotate from here (no fake ledger row)
//   security.devices / security.deviceState -> device_vault (device_trust_list / device_trust_set)
// Child module of the crate root: uses `auth_user`, `sb_rpc`, `ok`, `err`. Crates: serde_json, base64, tokio, rustls,
// webpki-roots (rustls + webpki-roots are the ones the Import-mail module already added; installer ensures them).
// ============================================================================

use crate::security_core as sc;
use axum::{http::StatusCode, response::IntoResponse};
use base64::Engine;
use serde_json::{json, Value};
use std::io::{BufRead, BufReader, Write};
use std::net::{SocketAddr, TcpStream};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "security.dashboard"
            | "security.sessions"
            | "security.killSession"
            | "security.killSwitch"
            | "security.history"
            | "security.disown"
            | "security.encryption"
            | "security.rotate"
            | "security.devices"
            | "security.deviceState"
    )
}

fn s(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn n(v: &Value, k: &str) -> i64 {
    v.get(k).and_then(|x| x.as_i64()).unwrap_or(0)
}

/// `session_id` claim of an access token that /auth/v1/user ALREADY accepted (signature checked there, not here).
fn session_of(token: &str) -> Option<String> {
    let mid = token.split('.').nth(1)?;
    let raw = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(mid.trim_end_matches('=')).ok()?;
    let v: Value = serde_json::from_slice(&raw).ok()?;
    let id = v.get("session_id")?.as_str()?.to_string();
    if id.len() == 36 { Some(id) } else { None }
}

fn bad(code: &str, msg: &str) -> Resp {
    crate::err(StatusCode::BAD_REQUEST, code, msg).into_response()
}

fn db_fail(detail: String) -> Resp {
    // E39 SQL abhi nahi chali => 404, taake browser purane Bun route par gire (page kabhi na toote).
    if detail.contains("PGRST202") || detail.contains("Could not find the function") {
        return crate::err(StatusCode::NOT_FOUND, "procedure_not_in_rust", "E39 not installed yet").into_response();
    }
    // E39 functions raise readable reasons — pass those as 4xx so the browser does NOT fall back to the old Bun route.
    for (needle, code, msg) in [
        ("this_session_use_sign_out", "this_session", "This is the device you are using — use Sign out instead."),
        ("session_not_found", "session_not_found", "That session has already ended."),
        ("session_id_required", "session_id_required", "session_id is required"),
        ("current_session_unknown", "current_session_unknown", "Sign in again, then retry."),
        ("device_not_found", "device_not_found", "That device is not on your list."),
    ] {
        if detail.contains(needle) {
            return crate::err(StatusCode::CONFLICT, code, msg).into_response();
        }
    }
    crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &detail).into_response()
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let user = match crate::auth_user(token).await {
        Some((id, _)) => id,
        None => return crate::err(StatusCode::UNAUTHORIZED, "unauthorized", "").into_response(),
    };
    let current = session_of(token);
    let cur = current.clone().map(Value::String).unwrap_or(Value::Null);

    let out: Result<Value, String> = match proc {
        "security.dashboard" => dashboard(&user, &cur).await,
        "security.sessions" => crate::sb_rpc("sec_sessions", json!({ "_user": user, "_current": cur }))
            .await
            .map(|rows| json!({ "sessions": sessions_view(&rows) })),
        "security.killSession" => {
            let id = s(input, "session_id");
            if id.len() != 36 {
                return bad("session_id_required", "session_id is required");
            }
            crate::sb_rpc("sec_session_kill", json!({ "_user": user, "_session": id, "_current": cur })).await
        }
        "security.killSwitch" | "security.disown" => {
            let reason = if proc == "security.disown" {
                format!("login disowned: {}", s(input, "event_id"))
            } else {
                let r = s(input, "reason");
                if r.is_empty() { "kill switch".to_string() } else { r }
            };
            crate::sb_rpc("sec_kill_switch", json!({ "_user": user, "_current": cur, "_reason": reason })).await
        }
        "security.history" => history(&user, &s(input, "outcome")).await,
        "security.encryption" => Ok(encryption().await),
        "security.rotate" => {
            return crate::err(
                StatusCode::CONFLICT,
                "provider_managed_keys",
                "Storage keys are managed and rotated by the database provider (AES-256). There is nothing to rotate from here — we no longer pretend to.",
            )
            .into_response();
        }
        "security.devices" => crate::sb_rpc("device_trust_list", json!({ "_user": user }))
            .await
            .map(|v| json!({ "devices": devices_view(v.get("devices").unwrap_or(&Value::Null)) })),
        "security.deviceState" => {
            let hash = s(input, "device_id");
            let state = match s(input, "state").as_str() {
                "trusted" => "trusted",
                "blocked" => "revoked",
                "pending" => "suspicious",
                _ => return bad("device_id_and_state_required", "device_id and a valid state are required"),
            };
            if hash.is_empty() || hash.len() > 128 {
                return bad("device_id_and_state_required", "device_id and a valid state are required");
            }
            match crate::sb_rpc("device_trust_set", json!({ "_user": user, "_device_hash": hash, "_state": state, "_actor": "user" })).await {
                Ok(_) => {
                    let _ = crate::sb_rpc(
                        "sec_ledger_add",
                        json!({ "_user": user, "_action": format!("device_{state}"), "_payload": { "device": hash.chars().take(12).collect::<String>() } }),
                    )
                    .await;
                    crate::sb_rpc("device_trust_list", json!({ "_user": user })).await.map(|v| {
                        let all = devices_view(v.get("devices").unwrap_or(&Value::Null));
                        let one = all.as_array().and_then(|a| a.iter().find(|d| s(d, "id") == hash).cloned()).unwrap_or(Value::Null);
                        json!({ "device": one })
                    })
                }
                Err(e) => Err(e),
            }
        }
        _ => return crate::err(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown security procedure").into_response(),
    };
    match out {
        Ok(v) => crate::ok(v).into_response(),
        Err(detail) => db_fail(detail),
    }
}

fn sessions_view(rows: &Value) -> Value {
    let list: Vec<Value> = rows
        .as_array()
        .map(|a| {
            a.iter()
                .map(|r| {
                    let current = r.get("current").and_then(|x| x.as_bool()).unwrap_or(false);
                    json!({
                        "id": s(r, "id"),
                        "device_label": sc::ua_label(&s(r, "user_agent")),
                        "ip": r.get("ip").cloned().unwrap_or(Value::Null),
                        "city": Value::Null,
                        "country": Value::Null,
                        "started_at": r.get("started_at").cloned().unwrap_or(Value::Null),
                        "last_seen_at": r.get("last_seen_at").cloned().unwrap_or(Value::Null),
                        "expires_at": r.get("expires_at").cloned().unwrap_or(Value::Null),
                        "current": current,
                        "risk": sc::session_risk(current, n(r, "idle_days")),
                    })
                })
                .collect()
        })
        .unwrap_or_default();
    Value::Array(list)
}

fn devices_view(rows: &Value) -> Value {
    let list: Vec<Value> = rows
        .as_array()
        .map(|a| {
            a.iter()
                .map(|d| {
                    let st = match s(d, "state").as_str() {
                        "trusted" => "trusted",
                        "revoked" | "banned" => "blocked",
                        _ => "pending",
                    };
                    let platform = s(d, "platform_class");
                    let browser = s(d, "browser_class");
                    let label = {
                        let l = s(d, "label");
                        if !l.is_empty() { l } else { format!("{browser} on {platform}") }
                    };
                    json!({
                        "id": s(d, "device_hash"),
                        "label": label,
                        "fingerprint": s(d, "device_hash").chars().take(12).collect::<String>(),
                        "platform": if platform.is_empty() { Value::Null } else { Value::String(platform) },
                        "browser": if browser.is_empty() { Value::Null } else { Value::String(browser) },
                        "state": st,
                        "trust_score": match st { "trusted" => 92, "blocked" => 0, _ => 50 },
                        "reasons": d.get("reasons").cloned().filter(|r| r.is_array()).unwrap_or(json!([])),
                        "first_seen_at": d.get("first_seen_at").cloned().unwrap_or(Value::Null),
                        "last_seen_at": d.get("last_seen_at").cloned().unwrap_or(Value::Null),
                        "city": Value::Null, "country": Value::Null, "ip": Value::Null,
                        "current": false,
                    })
                })
                .collect()
        })
        .unwrap_or_default();
    Value::Array(list)
}

async fn dashboard(user: &str, cur: &Value) -> Result<Value, String> {
    let (d, enc) = tokio::join!(crate::sb_rpc("sec_dashboard", json!({ "_user": user, "_current": cur })), encryption());
    let d = d?;
    let sessions = d.get("sessions").cloned().unwrap_or(json!([]));
    let live = sessions.as_array().map(|a| a.len()).unwrap_or(0) as u32;
    let stale = sessions
        .as_array()
        .map(|a| a.iter().filter(|r| !r.get("current").and_then(|x| x.as_bool()).unwrap_or(false) && n(r, "idle_days") >= 14).count())
        .unwrap_or(0) as u32;
    let pending = n(&d, "devices_pending") as u32;
    let failed = n(&d, "failed_logins_24h") as u32;
    let anomalies = d.get("anomalies").and_then(|a| a.as_array()).cloned().unwrap_or_default();
    let count_sev = |sev: &str| anomalies.iter().filter(|a| s(a, "severity") == sev).count() as u32;
    let encryption_ok = enc
        .get("in_transit")
        .and_then(|a| a.as_array())
        .map(|a| !a.is_empty() && a.iter().all(|h| s(h, "state") == "on"))
        .unwrap_or(false);
    let proof = match d.get("last_proof") {
        Some(p) if p.is_object() => {
            if n(p, "failed") == 0 { sc::Proof::Passed } else { sc::Proof::Failed }
        }
        _ => sc::Proof::None,
    };

    let mut advice: Vec<Value> = Vec::new();
    if pending > 0 {
        advice.push(json!({ "title": format!("{pending} device{} waiting for a decision", if pending > 1 { "s" } else { "" }),
            "detail": "Open Device trust and mark each one trusted or revoke it.", "severity": "medium" }));
    }
    if stale > 0 {
        advice.push(json!({ "title": format!("{stale} session{} unused for 14+ days", if stale > 1 { "s" } else { "" }),
            "detail": "Old sign-ins you forgot about are the easiest way in. End them under Sessions.", "severity": "medium" }));
    }
    for a in &anomalies {
        advice.push(json!({ "title": s(a, "kind").replace('_', " "), "detail": s(a, "detail"), "severity": s(a, "severity") }));
    }
    if !encryption_ok {
        let off: Vec<String> = enc
            .get("in_transit")
            .and_then(|a| a.as_array())
            .map(|a| a.iter().filter(|h| s(h, "state") != "on").map(|h| s(h, "hop")).collect())
            .unwrap_or_default();
        advice.push(json!({ "title": "An encrypted connection failed its live check",
            "detail": if off.is_empty() { "The live check could not run.".to_string() } else { off.join(" · ") }, "severity": "high" }));
    }
    match proof {
        sc::Proof::Failed => advice.push(json!({ "title": "Your last ownership proof had failing checks",
            "detail": "Open Ownership proof to see which DNS record to fix.", "severity": "high" })),
        sc::Proof::None => advice.push(json!({ "title": "Sign an ownership proof for your domain",
            "detail": "Ownership proof checks DKIM, SPF, DMARC and TLS and gives you a signed, exportable record.", "severity": "low" })),
        sc::Proof::Passed => {}
    }
    if failed > 10 {
        advice.push(json!({ "title": format!("{failed} failed sign-ins in 24 hours"),
            "detail": "Change your password and pull the kill switch under Sessions.", "severity": "high" }));
    }

    Ok(json!({
        "score": sc::score(pending, count_sev("high"), count_sev("medium"), count_sev("low"), encryption_ok, proof, failed, stale),
        "devices_trusted": n(&d, "devices_trusted"),
        "devices_pending": pending,
        "sessions_live": live,
        "failed_logins_24h": failed,
        "open_anomalies": anomalies.len(),
        "encryption_ok": encryption_ok,
        "ownership_ok": proof == sc::Proof::Passed,
        "ledger": d.get("ledger").cloned().unwrap_or(json!([])),
        "advice": advice,
    }))
}

async fn history(user: &str, outcome: &str) -> Result<Value, String> {
    let rows = crate::sb_rpc("sec_logins", json!({ "_user": user, "_limit": 100 })).await?;
    let mut events: Vec<Value> = Vec::new();
    for r in rows.as_array().cloned().unwrap_or_default() {
        let action = s(&r, "action");
        let method = match (action.as_str(), s(&r, "provider").as_str()) {
            ("user_recovery_requested", _) => "recovery",
            (_, "google") => "google",
            (_, "apple") => "apple",
            _ => "password",
        };
        if action != "login" && action != "user_recovery_requested" {
            continue;
        }
        let ip = r.get("ip").and_then(|x| x.as_str()).map(|x| x.to_string());
        let seen = r.get("seen_before").and_then(|x| x.as_bool()).unwrap_or(false);
        let risk = sc::login_risk(ip.as_deref(), seen);
        let story = match (action.as_str(), ip.as_deref(), seen) {
            ("user_recovery_requested", _, _) => "Password recovery was requested.".to_string(),
            (_, Some(i), true) => format!("Signed in from {i} — a network you have used before."),
            (_, Some(i), false) => format!("Signed in from {i} — first time from this network."),
            _ => "Signed in.".to_string(),
        };
        let ev = json!({
            "id": s(&r, "id"), "at": r.get("at").cloned().unwrap_or(Value::Null), "email": s(&r, "email"),
            "method": method, "outcome": "success", "ip": ip, "city": Value::Null, "country": Value::Null,
            "device_label": Value::Null, "risk_score": risk, "story": story, "disowned": false,
        });
        if outcome.is_empty() || outcome == "all" || outcome == "success" {
            events.push(ev);
        }
    }
    Ok(json!({ "events": events, "anomalies": [] }))
}

// ── live encryption probes (cached 10 min; each probe ≤ 4 s, all in parallel) ────────────────────────────────

fn tls_config() -> Result<Arc<rustls::ClientConfig>, String> {
    static CFG: OnceLock<Result<Arc<rustls::ClientConfig>, String>> = OnceLock::new();
    CFG.get_or_init(|| {
        let mut roots = rustls::RootCertStore::empty();
        roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
        let provider = Arc::new(rustls::crypto::ring::default_provider());
        let cfg = rustls::ClientConfig::builder_with_provider(provider)
            .with_safe_default_protocol_versions()
            .map_err(|e| e.to_string())?
            .with_root_certificates(roots)
            .with_no_client_auth();
        Ok(Arc::new(cfg))
    })
    .clone()
}

const T: Duration = Duration::from_secs(4);

/// Plain TCP to this machine (127.0.0.1) — the certificate is still checked against the PUBLIC name.
fn connect(port: u16) -> Result<TcpStream, String> {
    let addr: SocketAddr = ([127, 0, 0, 1], port).into();
    let tcp = TcpStream::connect_timeout(&addr, T).map_err(|e| format!("connect: {e}"))?;
    let _ = tcp.set_read_timeout(Some(T));
    let _ = tcp.set_write_timeout(Some(T));
    Ok(tcp)
}

fn handshake(tcp: TcpStream, name: &str) -> Result<(String, String), String> {
    let cfg = tls_config()?;
    let sn = rustls::pki_types::ServerName::try_from(name.to_string()).map_err(|_| "bad name".to_string())?;
    let conn = rustls::ClientConnection::new(cfg, sn).map_err(|e| e.to_string())?;
    let mut tls = rustls::StreamOwned::new(conn, tcp);
    while tls.conn.is_handshaking() {
        tls.conn.complete_io(&mut tls.sock).map_err(|e| {
            let t = e.to_string();
            if t.to_ascii_lowercase().contains("certificate") { format!("certificate not valid for {name}: {t}") } else { format!("handshake: {t}") }
        })?;
    }
    let ver = tls.conn.protocol_version().map(|v| format!("{v:?}")).unwrap_or_default();
    let suite = tls.conn.negotiated_cipher_suite().map(|c| format!("{:?}", c.suite())).unwrap_or_default();
    let _ = tls.conn.send_close_notify();
    let _ = tls.flush();
    Ok((ver, suite))
}

fn smtp_starttls(port: u16, name: &str) -> Result<(String, String), String> {
    let tcp = connect(port)?;
    let mut rd = BufReader::new(tcp.try_clone().map_err(|e| e.to_string())?);
    let mut w = tcp.try_clone().map_err(|e| e.to_string())?;
    let read_reply = |rd: &mut BufReader<TcpStream>| -> Result<(u16, String), String> {
        let mut all = String::new();
        for _ in 0..40 {
            let mut line = String::new();
            if rd.read_line(&mut line).map_err(|e| format!("read: {e}"))? == 0 {
                return Err("server closed".into());
            }
            all.push_str(&line);
            let l = line.trim_end();
            if sc::smtp_last(l) {
                return Ok((sc::smtp_code(l).unwrap_or(0), all));
            }
        }
        Err("reply too long".into())
    };
    let (c, _) = read_reply(&mut rd)?;
    if c != 220 {
        return Err(format!("greeting {c}"));
    }
    w.write_all(b"EHLO security-check.anexomail.com\r\n").map_err(|e| e.to_string())?;
    let (c, ehlo) = read_reply(&mut rd)?;
    if c != 250 || !sc::ehlo_has_starttls(&ehlo) {
        return Err("STARTTLS not offered".into());
    }
    w.write_all(b"STARTTLS\r\n").map_err(|e| e.to_string())?;
    let (c, _) = read_reply(&mut rd)?;
    if c != 220 {
        return Err(format!("STARTTLS refused ({c})"));
    }
    if rd.buffer().len() > 0 {
        return Err("unexpected bytes before TLS".into());
    }
    drop(rd);
    handshake(tcp, name)
}

fn probe(kind: &'static str) -> (String, String, Result<(String, String), String>) {
    match kind {
        "web" => ("Browser ↔ ANEXOMAIL (HTTPS, 443)".into(), "anexomail.com".into(), connect(443).and_then(|t| handshake(t, "anexomail.com"))),
        "imap" => ("Mail apps ↔ IMAP (993)".into(), "mail.anexomail.com".into(), connect(993).and_then(|t| handshake(t, "mail.anexomail.com"))),
        "submit" => ("Mail apps ↔ sending (587, STARTTLS)".into(), "mail.anexomail.com".into(), smtp_starttls(587, "mail.anexomail.com")),
        _ => ("Other mail servers ↔ ANEXOMAIL (25, STARTTLS)".into(), "mail.anexomail.com".into(), smtp_starttls(25, "mail.anexomail.com")),
    }
}

async fn encryption() -> Value {
    static CACHE: OnceLock<Mutex<Option<(Instant, Value)>>> = OnceLock::new();
    let cache = CACHE.get_or_init(|| Mutex::new(None));
    if let Ok(g) = cache.lock() {
        if let Some((at, v)) = g.as_ref() {
            // sab theek ho to 10 min yaad; koi hop band ho to 1 min (theek hote hi jaldi dikhe)
            let all_on = v.get("in_transit").and_then(|a| a.as_array()).map(|a| a.iter().all(|h| h.get("state").and_then(|x| x.as_str()) == Some("on"))).unwrap_or(false);
            if at.elapsed() < Duration::from_secs(if all_on { 600 } else { 60 }) {
                return v.clone();
            }
        }
    }
    const KINDS: [&'static str; 4] = ["web", "imap", "submit", "mx"];
    let jobs: Vec<_> = KINDS.into_iter().map(|k| tokio::task::spawn_blocking(move || probe(k))).collect();
    let mut hops: Vec<Value> = Vec::new();
    let checked_at = format!("{:?}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0));
    for j in jobs {
        let (hop, name, r) = match tokio::time::timeout(Duration::from_secs(12), j).await {
            Ok(Ok(x)) => x,
            _ => ("(probe)".to_string(), String::new(), Err("timed out".to_string())),
        };
        hops.push(match r {
            Ok((ver, suite)) => json!({
                "hop": hop, "protocol": sc::tls_human(&ver), "cipher": suite,
                "state": if sc::tls_modern(&ver) { "on" } else { "partial" },
                "detail": format!("certificate valid for {name}"),
            }),
            Err(e) => json!({ "hop": hop, "protocol": "—", "cipher": Value::Null, "state": "off", "detail": e }),
        });
    }
    let v = json!({
        "at_rest": [
            { "surface": "Mail, contacts, calendar (database)", "algorithm": "AES-256", "state": "on",
              "detail": "Supabase managed Postgres — disk and backups encrypted by the provider; keys held and rotated by the provider." }
        ],
        "in_transit": hops,
        "key_rotated_at": Value::Null,
        "next_rotation_at": Value::Null,
        "ledger": [],
        "checked_at_unix": checked_at,
        "source": "live handshake from the mail server, cached 10 minutes",
    });
    if let Ok(mut g) = cache.lock() {
        *g = Some((Instant::now(), v.clone()));
    }
    v
}
