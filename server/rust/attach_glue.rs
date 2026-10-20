// ============================================================================
// attach_glue.rs — G38: bheji jane wali mail ke attachments (Rust PRIMARY). SQL: docs/cursor-work/sql/E48_outgoing_attachments.sql
//
//   POST /file/attach        headers: authorization Bearer, x-file-name (percent-encoded), x-file-type, x-org-id (optional); body = raw file bytes
//                            -> {id, filename, size_bytes, deduped, scanned, message_cap_bytes}
//   GET  /file/attach/get?id=<uuid>   (Bearer) -> file download (hamesha `attachment`, nosniff)
//   mail.attach.limits {}    -> {message_cap_bytes, max_files, org_limit_bytes, org_used_bytes, plan, storage_ready, scanning}
//   mail.attach.remove {id}  -> staged file hatao (bheji nahi gayi)
//
// Raasta: body disk par stream hoti hai (RAM mein poori file kabhi nahi), SHA-256 saath-saath, cap paar hote hi rad.
//   type policy (attach_core) -> clamd INSTREAM (ho to) -> DB register (quota + org-ke-andar dedup, atomic) -> rename to
//   `<ATTACH_DIR>/<org>/<sha[0..2]>/<sha>-<nonce>`. DB mein sirf metadata. ATTACH_DIR default `/mnt/anexomail-box/attachments`
//   (Storage Box mount). Mount na ho (ya mountpoint khali local folder ho) to 503 storage_unavailable — kabhi chupke se local disk par nahi likhta.
// Child module: crate root ke `auth_user`, `sb_rpc`, `bearer`, `ok`, `err`, `env_var` istemal karta hai. Koi nayi dependency nahi.
// ============================================================================

use crate::attach_core as ac;
use axum::{
    body::Body,
    http::{header, HeaderMap, StatusCode},
    response::IntoResponse,
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio_stream::StreamExt;

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(proc, "mail.attach.limits" | "mail.attach.remove")
}

fn root() -> String {
    let v = crate::env_var("ATTACH_DIR");
    if v.starts_with('/') && v.len() > 1 {
        v.trim_end_matches('/').to_string()
    } else {
        "/mnt/anexomail-box/attachments".to_string()
    }
}

fn clamd_addr() -> String {
    let v = crate::env_var("CLAMD_ADDR");
    if v.is_empty() { "127.0.0.1:3310".to_string() } else { v }
}

/// Jahan Storage Box mount hona chahiye. ATTACH_DIR na ho (default Box path) => `/mnt/anexomail-box`. Custom ATTACH_DIR (test/doosra disk)
/// => koi mount-check nahi, jab tak ATTACH_MOUNT=<path> na diya ho (ATTACH_MOUNT=none = band).
fn mount_point() -> Option<String> {
    let m = crate::env_var("ATTACH_MOUNT");
    if !m.is_empty() {
        return if m == "none" { None } else { Some(m) };
    }
    if crate::env_var("ATTACH_DIR").is_empty() {
        Some("/mnt/anexomail-box".to_string())
    } else {
        None
    }
}

/// Mountpoint ki pehchan: us ka device id uske parent se alag ho (sshfs/FUSE mount hone par alag hota hai).
/// Mount gir jaye to `/mnt/anexomail-box/attachments` ek khali LOCAL folder reh sakta hai — us par kabhi nahi likhte.
fn is_mountpoint(p: &str) -> bool {
    use std::os::unix::fs::MetadataExt;
    let path = std::path::Path::new(p);
    let (Ok(a), Some(parent)) = (std::fs::metadata(path), path.parent()) else { return false };
    let Ok(b) = std::fs::metadata(parent) else { return false };
    a.dev() != b.dev()
}

async fn root_ready(r: &str) -> bool {
    if let Some(mp) = mount_point() {
        if !is_mountpoint(&mp) {
            return false;
        }
    }
    matches!(tokio::fs::metadata(r).await, Ok(m) if m.is_dir())
}

async fn clamd_up() -> bool {
    matches!(
        tokio::time::timeout(Duration::from_millis(400), tokio::net::TcpStream::connect(clamd_addr())).await,
        Ok(Ok(_))
    )
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn db_err(e: &str) -> Resp {
    fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e.chars().take(300).collect::<String>())
}

fn s_of<'a>(v: &'a Value, k: &str) -> &'a str {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("")
}

/// SQL ke {ok:false,error} ko HTTP mein badalna
fn sql_fail(v: &Value) -> Resp {
    let code = s_of(v, "error");
    let (status, msg) = match code {
        "unauthorized" => (StatusCode::UNAUTHORIZED, "Please sign in again."),
        "account_blocked" => (StatusCode::FORBIDDEN, "This account is blocked from sending files."),
        "no_workspace" => (StatusCode::CONFLICT, "No workspace for this account."),
        "wrong_org" => (StatusCode::FORBIDDEN, "That workspace is not yours."),
        "file_too_large" => (StatusCode::PAYLOAD_TOO_LARGE, "This file is larger than one message can carry."),
        "org_quota_full" => (StatusCode::INSUFFICIENT_STORAGE, "Your workspace attachment storage is full."),
        "too_many_staged" => (StatusCode::TOO_MANY_REQUESTS, "Too many files waiting to be sent. Send or remove some first."),
        "not_found" => (StatusCode::NOT_FOUND, "File not found."),
        _ => (StatusCode::BAD_REQUEST, "The file could not be attached."),
    };
    let mut body = json!({ "error": { "code": code, "message": msg } });
    for k in ["limit_bytes", "used_bytes"] {
        if let Some(x) = v.get(k) {
            body["error"][k] = x.clone();
        }
    }
    (status, axum::Json(body)).into_response()
}

fn ctx_ok(v: &Value) -> bool {
    v.get("ok").and_then(|x| x.as_bool()) == Some(true)
}

fn rand8() -> String {
    use std::sync::atomic::{AtomicU64, Ordering};
    static N: AtomicU64 = AtomicU64::new(0);
    let nanos = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    let mut h = Sha256::new();
    h.update(nanos.to_le_bytes());
    h.update(std::process::id().to_le_bytes());
    h.update(N.fetch_add(1, Ordering::Relaxed).to_le_bytes());
    // /dev/urandom ho to uska bhi namak (na ho to bhi theek: path guess karna fayda nahi deta, auth DB se hoti hai)
    if let Ok(mut f) = std::fs::File::open("/dev/urandom") {
        use std::io::Read;
        let mut b = [0u8; 16];
        if f.read_exact(&mut b).is_ok() {
            h.update(b);
        }
    }
    let d = h.finalize();
    d.iter().take(4).map(|b| format!("{b:02x}")).collect()
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let (uid, _email) = match crate::auth_user(token).await {
        Some(x) => x,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", ""),
    };
    match proc {
        "mail.attach.limits" => {
            let org = input.get("org_id").and_then(|v| v.as_str()).filter(|s| ac::valid_uuid(s));
            let c = match crate::sb_rpc("mail_attach_ctx", json!({ "_user": uid, "_org": org })).await {
                Ok(v) => v,
                Err(e) => return db_err(&e),
            };
            if !ctx_ok(&c) {
                return sql_fail(&c);
            }
            let ready = root_ready(&root()).await;
            let scanning = clamd_up().await;
            let mut out = c.clone();
            out["storage_ready"] = json!(ready);
            out["scanning"] = json!(scanning);
            crate::ok(out).into_response()
        }
        "mail.attach.remove" => {
            let id = input.get("id").and_then(|v| v.as_str()).unwrap_or("");
            if !ac::valid_uuid(id) {
                return fail(StatusCode::BAD_REQUEST, "bad_id", "");
            }
            match crate::sb_rpc("mail_attach_remove", json!({ "_user": uid, "_id": id })).await {
                Ok(v) => crate::ok(v).into_response(),
                Err(e) => db_err(&e),
            }
        }
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", ""),
    }
}

/// clamd INSTREAM file se (RAM mein poori file nahi). Ok(None) = clamd chal hi nahi raha (jhooti clean claim nahi).
async fn scan_file(path: &std::path::Path) -> Result<Option<ac::ClamVerdict>, String> {
    let connect = tokio::time::timeout(Duration::from_millis(600), tokio::net::TcpStream::connect(clamd_addr())).await;
    let mut stream = match connect {
        Ok(Ok(s)) => s,
        _ => return Ok(None),
    };
    stream.write_all(b"zINSTREAM\0").await.map_err(|e| e.to_string())?;
    let mut f = tokio::fs::File::open(path).await.map_err(|e| e.to_string())?;
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        let n = f.read(&mut buf).await.map_err(|e| e.to_string())?;
        if n == 0 {
            break;
        }
        stream.write_all(&(n as u32).to_be_bytes()).await.map_err(|e| e.to_string())?;
        stream.write_all(&buf[..n]).await.map_err(|e| e.to_string())?;
    }
    stream.write_all(&0u32.to_be_bytes()).await.map_err(|e| e.to_string())?;
    let mut reply = Vec::new();
    let _ = tokio::time::timeout(Duration::from_secs(60), stream.read_to_end(&mut reply)).await;
    let text = String::from_utf8_lossy(&reply).to_string();
    if text.trim_matches(|c: char| c == '\0' || c.is_whitespace()).is_empty() {
        return Ok(None);
    }
    Ok(Some(ac::parse_clamd(&text)))
}

pub async fn upload(headers: HeaderMap, body: Body) -> Resp {
    let token = match crate::bearer(&headers) {
        Some(t) => t,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", ""),
    };
    let (uid, _email) = match crate::auth_user(&token).await {
        Some(x) => x,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", ""),
    };
    let want_org = headers.get("x-org-id").and_then(|v| v.to_str().ok()).filter(|s| ac::valid_uuid(s)).map(|s| s.to_string());
    let c = match crate::sb_rpc("mail_attach_ctx", json!({ "_user": uid, "_org": want_org })).await {
        Ok(v) => v,
        Err(e) => return db_err(&e),
    };
    if !ctx_ok(&c) {
        return sql_fail(&c);
    }
    let org = s_of(&c, "org_id").to_string();
    if !ac::valid_uuid(&org) {
        return fail(StatusCode::INTERNAL_SERVER_ERROR, "bad_org", "");
    }
    let cap = c.get("message_cap_bytes").and_then(|v| v.as_u64()).unwrap_or(0);
    if cap == 0 {
        return fail(StatusCode::INTERNAL_SERVER_ERROR, "no_cap", "");
    }
    let declared = headers.get(header::CONTENT_LENGTH).and_then(|v| v.to_str().ok()).and_then(|s| s.parse::<u64>().ok());
    if ac::exceeds_cap(declared, cap) {
        return sql_fail(&json!({ "error": "file_too_large", "limit_bytes": cap }));
    }

    let raw_name = headers.get("x-file-name").and_then(|v| v.to_str().ok()).map(ac::pct_decode).unwrap_or_default();
    let name = ac::sanitize_filename(&raw_name);
    let mime = ac::clean_mime(headers.get("x-file-type").and_then(|v| v.to_str().ok()).unwrap_or(""));

    let root = root();
    if !root_ready(&root).await {
        return fail(StatusCode::SERVICE_UNAVAILABLE, "storage_unavailable", "File storage is not available right now. Try again shortly.");
    }
    let tmp_dir = format!("{root}/{org}/.tmp");
    if let Err(e) = tokio::fs::create_dir_all(&tmp_dir).await {
        return fail(StatusCode::SERVICE_UNAVAILABLE, "storage_unavailable", &e.to_string());
    }
    let tmp_path = std::path::PathBuf::from(format!("{tmp_dir}/{}", rand8() + &rand8()));
    let mut f = match tokio::fs::File::create(&tmp_path).await {
        Ok(f) => f,
        Err(e) => return fail(StatusCode::SERVICE_UNAVAILABLE, "storage_unavailable", &e.to_string()),
    };

    // ── stream: disk par, sha256 saath, cap par rad ──
    let mut hasher = Sha256::new();
    let mut head: Vec<u8> = Vec::with_capacity(ac::HEAD_BYTES);
    let mut total: u64 = 0;
    let mut stream = body.into_data_stream();
    let mut problem: Option<Resp> = None;
    loop {
        let next = match tokio::time::timeout(Duration::from_secs(30), stream.next()).await {
            Ok(n) => n,
            Err(_) => {
                problem = Some(fail(StatusCode::REQUEST_TIMEOUT, "upload_stalled", "The upload stalled. Try again."));
                break;
            }
        };
        let chunk = match next {
            None => break,
            Some(Ok(b)) => b,
            Some(Err(_)) => {
                problem = Some(fail(StatusCode::BAD_REQUEST, "upload_aborted", "The upload was interrupted."));
                break;
            }
        };
        total += chunk.len() as u64;
        if total > cap {
            problem = Some(sql_fail(&json!({ "error": "file_too_large", "limit_bytes": cap })));
            break;
        }
        if head.len() < ac::HEAD_BYTES {
            let take = (ac::HEAD_BYTES - head.len()).min(chunk.len());
            head.extend_from_slice(&chunk[..take]);
        }
        hasher.update(&chunk);
        if let Err(e) = f.write_all(&chunk).await {
            problem = Some(fail(StatusCode::SERVICE_UNAVAILABLE, "storage_unavailable", &e.to_string()));
            break;
        }
    }
    let flushed = f.flush().await.is_ok() && f.sync_all().await.is_ok();
    drop(f);
    if problem.is_none() && !flushed {
        problem = Some(fail(StatusCode::SERVICE_UNAVAILABLE, "storage_unavailable", "Could not write the file."));
    }
    if problem.is_none() && total == 0 {
        problem = Some(fail(StatusCode::UNPROCESSABLE_ENTITY, "empty_file", "This file is empty."));
    }
    if let Some(p) = problem {
        let _ = tokio::fs::remove_file(&tmp_path).await;
        return p;
    }

    // ── type policy ──
    if let Err(why) = ac::type_verdict(&name, &head) {
        let _ = tokio::fs::remove_file(&tmp_path).await;
        return fail(StatusCode::UNPROCESSABLE_ENTITY, "file_type_blocked", &why);
    }

    // ── virus scan (apne infra par clamd; na ho to saaf "scanned:false") ──
    let (clam, scanned) = match scan_file(&tmp_path).await {
        Ok(Some(ac::ClamVerdict::Found(sig))) => {
            let _ = tokio::fs::remove_file(&tmp_path).await;
            return fail(StatusCode::UNPROCESSABLE_ENTITY, "malware_detected", &format!("This file was blocked because it looks malicious ({sig})."));
        }
        Ok(Some(ac::ClamVerdict::Clean)) => ("clean".to_string(), true),
        Ok(Some(ac::ClamVerdict::Error(e))) => (format!("error:{e}"), false),
        Ok(None) => ("unavailable".to_string(), false),
        Err(e) => (format!("error:{e}"), false),
    };

    let sha: String = hasher.finalize().iter().map(|b| format!("{b:02x}")).collect();
    let rel = match ac::rel_path(&org, &sha, &rand8()) {
        Some(r) => r,
        None => {
            let _ = tokio::fs::remove_file(&tmp_path).await;
            return fail(StatusCode::INTERNAL_SERVER_ERROR, "bad_path", "");
        }
    };
    let scan = json!({
        "type_policy": "pass",
        "clamd": clam,
        "scanned": scanned,
        "engines": if scanned { json!(["type-policy", "clamd-local"]) } else { json!(["type-policy"]) },
        "checked_at_unix": std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0),
    });
    let reg = match crate::sb_rpc(
        "mail_attach_register",
        json!({ "_user": uid, "_org": org, "_sha256": sha, "_size": total, "_filename": name, "_mime": mime, "_rel_path": rel, "_scan": scan }),
    )
    .await
    {
        Ok(v) => v,
        Err(e) => {
            let _ = tokio::fs::remove_file(&tmp_path).await;
            return db_err(&e);
        }
    };
    if !ctx_ok(&reg) {
        let _ = tokio::fs::remove_file(&tmp_path).await;
        return sql_fail(&reg);
    }
    let deduped = reg.get("deduped").and_then(|v| v.as_bool()).unwrap_or(false);
    let id = s_of(&reg, "id").to_string();
    if deduped {
        // isi org mein yeh file pehle se hai — nayi byte nahi rakhi
        let _ = tokio::fs::remove_file(&tmp_path).await;
    } else {
        let final_path = format!("{root}/{rel}");
        let parent = std::path::Path::new(&final_path).parent().map(|p| p.to_path_buf());
        let placed = match parent {
            Some(p) => tokio::fs::create_dir_all(&p).await.is_ok() && tokio::fs::rename(&tmp_path, &final_path).await.is_ok(),
            None => false,
        };
        if !placed {
            // storage ne jawab de diya — staged row wapas (blob row GC saaf karega) aur file nahi rakhi
            let _ = crate::sb_rpc("mail_attach_remove", json!({ "_user": uid, "_id": id })).await;
            let _ = tokio::fs::remove_file(&tmp_path).await;
            return fail(StatusCode::SERVICE_UNAVAILABLE, "storage_unavailable", "Could not store the file. Try again.");
        }
    }
    crate::ok(json!({
        "id": id,
        "filename": s_of(&reg, "filename"),
        "mime_type": mime,
        "size_bytes": total,
        "deduped": deduped,
        "scanned": scanned,
        "message_cap_bytes": cap,
    }))
    .into_response()
}

pub async fn download(headers: HeaderMap, axum::extract::Query(q): axum::extract::Query<std::collections::HashMap<String, String>>) -> Resp {
    let token = match crate::bearer(&headers) {
        Some(t) => t,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", ""),
    };
    let (uid, _e) = match crate::auth_user(&token).await {
        Some(x) => x,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", ""),
    };
    let id = q.get("id").cloned().unwrap_or_default();
    if !ac::valid_uuid(&id) {
        return fail(StatusCode::BAD_REQUEST, "bad_id", "");
    }
    let r = match crate::sb_rpc("mail_attach_resolve", json!({ "_user": uid, "_id": id })).await {
        Ok(v) => v,
        Err(e) => return db_err(&e),
    };
    if !ctx_ok(&r) {
        return sql_fail(&r);
    }
    let rel = s_of(&r, "rel_path");
    if !ac::rel_path_valid(rel) {
        return fail(StatusCode::INTERNAL_SERVER_ERROR, "bad_path", "");
    }
    let path = format!("{}/{rel}", root());
    let file = match tokio::fs::File::open(&path).await {
        Ok(f) => f,
        Err(_) => return fail(StatusCode::NOT_FOUND, "file_missing", "The file is no longer available."),
    };
    let want = r.get("size_bytes").and_then(|v| v.as_u64()).unwrap_or(0);
    match file.metadata().await {
        Ok(m) if m.is_file() && m.len() == want => {}
        _ => return fail(StatusCode::INTERNAL_SERVER_ERROR, "file_changed", "The stored file does not match its record."),
    }
    let stream = tokio_util_stream(file);
    (
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, "application/octet-stream".to_string()),
            (header::CONTENT_DISPOSITION, ac::content_disposition(s_of(&r, "filename"))),
            (header::CONTENT_LENGTH, want.to_string()),
            (header::CACHE_CONTROL, "private, no-store".to_string()),
            (header::X_CONTENT_TYPE_OPTIONS, "nosniff".to_string()),
        ],
        Body::from_stream(stream),
    )
        .into_response()
}

/// File ko 64 KB tukdon mein stream (tokio-util ki zaroorat nahi — mpsc + spawn).
fn tokio_util_stream(mut file: tokio::fs::File) -> tokio_stream::wrappers::ReceiverStream<Result<axum::body::Bytes, std::io::Error>> {
    let (tx, rx) = tokio::sync::mpsc::channel::<Result<axum::body::Bytes, std::io::Error>>(4);
    tokio::spawn(async move {
        let mut buf = vec![0u8; 64 * 1024];
        loop {
            match file.read(&mut buf).await {
                Ok(0) => break,
                Ok(n) => {
                    if tx.send(Ok(axum::body::Bytes::copy_from_slice(&buf[..n]))).await.is_err() {
                        break;
                    }
                }
                Err(e) => {
                    let _ = tx.send(Err(e)).await;
                    break;
                }
            }
        }
    });
    tokio_stream::wrappers::ReceiverStream::new(rx)
}
