// ============================================================================
// evidence_glue.rs — E72: appeal ke saboot (screenshots / PDF / documents). Rust PRIMARY, tokio async. SQL: docs/cursor-work/sql/E72_appeal_evidence.sql
//
//   POST /file/appeal-evidence       headers: authorization Bearer, x-file-name (percent-encoded), x-file-type; body = raw file bytes
//                                    -> {id, filename, size_bytes, deduped, scanned, limits}
//   GET  /file/appeal-evidence/get?id=<uuid>   (Bearer) -> file download (hamesha `attachment`, nosniff, sandbox). Malik ya reviewer; reviewer ka har download likha jata hai.
//   appeal.evidence.limits {}        -> {eligible, statement_max, max_files, max_file_bytes, max_total_bytes, staged_files, staged_bytes, storage_ready, scanning}
//   appeal.evidence.remove {id}      -> appeal se pehle ki file wapas
//   appeal.evidence.list {appeal_id} -> {files:[{id, filename, mime, size_bytes, scanned}]}  (malik ya reviewer)
//   appeal.device.open {device_hash, statement, evidence_ids?} -> device appeal (20..20,000 characters) + files EK transaction mein (SQL device_appeal_open_v2)
//
// Raasta: body disk par stream hoti hai (RAM mein poori file kabhi nahi), SHA-256 saath-saath, cap paar hote hi rad.
//   eligible check (body padhne se PEHLE) -> type allowlist + magic (evidence_core) -> clamd INSTREAM (ho to) -> DB register (hadein + dedup, atomic)
//   -> rename to `<ATTACH_DIR>/appeals/<user>/<sha[0..2]>/<sha>-<nonce>`. DB mein sirf metadata.
// tokio: ek Semaphore (zyada se zyada 8 upload ek saath — server ka disk/clamd dabao mein na aaye) + har user ke liye ek-waqt-mein-ek upload.
// Storage: attach_glue wala hi `ATTACH_DIR` + Storage Box mount-check (mount na ho to 503, kabhi chupke se local disk par nahi likhta).
// Koi nayi crate nahi: sha2, tokio, tokio_stream, axum — attach_glue pehle se use karta hai.
// ============================================================================

use crate::attach_core as ac;
use crate::evidence_core as ev;
use axum::{
    body::Body,
    http::{header, HeaderMap, StatusCode},
    response::IntoResponse,
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::sync::{Mutex, OnceLock};
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio_stream::StreamExt;

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(proc, "appeal.evidence.limits" | "appeal.evidence.remove" | "appeal.evidence.list" | "appeal.device.open")
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

fn ctx_ok(v: &Value) -> bool {
    v.get("ok").and_then(|x| x.as_bool()) == Some(true)
}

/// SQL ke {ok:false,error} ko HTTP mein badalna
fn sql_fail(v: &Value) -> Resp {
    let code = s_of(v, "error");
    let (status, msg) = ev::error_text(code);
    let mut body = json!({ "error": { "code": code, "message": msg } });
    for k in ["limit_bytes", "used_bytes", "limit"] {
        if let Some(x) = v.get(k) {
            body["error"][k] = x.clone();
        }
    }
    (StatusCode::from_u16(status).unwrap_or(StatusCode::BAD_REQUEST), axum::Json(body)).into_response()
}

fn rand8() -> String {
    use std::sync::atomic::{AtomicU64, Ordering};
    static N: AtomicU64 = AtomicU64::new(0);
    let nanos = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    let mut h = Sha256::new();
    h.update(nanos.to_le_bytes());
    h.update(std::process::id().to_le_bytes());
    h.update(N.fetch_add(1, Ordering::Relaxed).to_le_bytes());
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

// ── tokio: server-wide aur per-user rok ──
const MAX_CONCURRENT: usize = 8;

fn gate() -> &'static tokio::sync::Semaphore {
    static G: OnceLock<tokio::sync::Semaphore> = OnceLock::new();
    G.get_or_init(|| tokio::sync::Semaphore::new(MAX_CONCURRENT))
}

fn in_flight() -> &'static Mutex<HashSet<String>> {
    static S: OnceLock<Mutex<HashSet<String>>> = OnceLock::new();
    S.get_or_init(|| Mutex::new(HashSet::new()))
}

/// Drop par user ka slot khud wapas (early return / panic / client disconnect sab raaste)
struct UserSlot(String);
impl Drop for UserSlot {
    fn drop(&mut self) {
        if let Ok(mut s) = in_flight().lock() {
            s.remove(&self.0);
        }
    }
}

fn take_user_slot(uid: &str) -> Option<UserSlot> {
    let mut s = in_flight().lock().ok()?;
    if s.insert(uid.to_string()) { Some(UserSlot(uid.to_string())) } else { None }
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let (uid, _email) = match crate::auth_user(token).await {
        Some(x) => x,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", ""),
    };
    match proc {
        "appeal.evidence.limits" => {
            let c = match crate::sb_rpc("appeal_evidence_ctx", json!({ "_user": uid })).await {
                Ok(v) => v,
                Err(e) => return db_err(&e),
            };
            if !ctx_ok(&c) {
                return sql_fail(&c);
            }
            let mut out = c.clone();
            out["storage_ready"] = json!(root_ready(&root()).await);
            out["scanning"] = json!(clamd_up().await);
            crate::ok(out).into_response()
        }
        "appeal.evidence.remove" => {
            let id = input.get("id").and_then(|v| v.as_str()).unwrap_or("");
            if !ac::valid_uuid(id) {
                return fail(StatusCode::BAD_REQUEST, "bad_id", "");
            }
            match crate::sb_rpc("appeal_evidence_remove", json!({ "_user": uid, "_id": id })).await {
                Ok(v) if ctx_ok(&v) => crate::ok(v).into_response(),
                Ok(v) => sql_fail(&v),
                Err(e) => db_err(&e),
            }
        }
        "appeal.device.open" => {
            let hash = input.get("device_hash").and_then(|v| v.as_str()).unwrap_or("").trim().to_string();
            if hash.is_empty() || hash.len() > 200 {
                return fail(StatusCode::BAD_REQUEST, "device_required", "Enter the device id from your device list.");
            }
            let statement = match ev::statement_check(input.get("statement").and_then(|v| v.as_str()).unwrap_or("")) {
                Ok(t) => t,
                Err(code) => return sql_fail(&json!({ "error": code })),
            };
            let raw: Vec<String> = input
                .get("evidence_ids")
                .and_then(|v| v.as_array())
                .map(|a| a.iter().filter_map(|x| x.as_str().map(|t| t.to_string())).collect())
                .unwrap_or_default();
            let ids = match ev::clean_ids(&raw) {
                Ok(v) => v,
                Err(code) => return sql_fail(&json!({ "error": code })),
            };
            match crate::sb_rpc("device_appeal_open_v2", json!({ "_user": uid, "_device_hash": hash, "_statement": statement, "_evidence": ids })).await {
                Ok(v) => crate::ok(v).into_response(),
                Err(e) => db_err(&e),
            }
        }
        "appeal.evidence.list" => {
            let id = input.get("appeal_id").and_then(|v| v.as_str()).unwrap_or("");
            if !ac::valid_uuid(id) {
                return fail(StatusCode::BAD_REQUEST, "bad_id", "");
            }
            match crate::sb_rpc("appeal_evidence_list", json!({ "_actor": uid, "_appeal": id })).await {
                Ok(v) if ctx_ok(&v) => crate::ok(v).into_response(),
                Ok(v) => sql_fail(&v),
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
    let uid = uid.to_string();
    if !ac::valid_uuid(&uid) {
        return fail(StatusCode::INTERNAL_SERVER_ERROR, "bad_user", "");
    }

    // ── body padhne SE PEHLE: kya yeh user appeal kar sakta hai, kitni jagah hai ──
    let c = match crate::sb_rpc("appeal_evidence_ctx", json!({ "_user": uid })).await {
        Ok(v) => v,
        Err(e) => return db_err(&e),
    };
    if !ctx_ok(&c) {
        return sql_fail(&c);
    }
    if c.get("eligible").and_then(|v| v.as_bool()) != Some(true) {
        return sql_fail(&json!({ "error": "nothing_to_appeal" }));
    }
    let max_files = c.get("max_files").and_then(|v| v.as_u64()).unwrap_or(5);
    if c.get("staged_files").and_then(|v| v.as_u64()).unwrap_or(0) >= max_files {
        return sql_fail(&json!({ "error": "too_many_files", "limit": max_files }));
    }
    let cap = c.get("max_file_bytes").and_then(|v| v.as_u64()).unwrap_or(0);
    if cap == 0 {
        return fail(StatusCode::INTERNAL_SERVER_ERROR, "no_cap", "");
    }
    let declared = headers.get(header::CONTENT_LENGTH).and_then(|v| v.to_str().ok()).and_then(|s| s.parse::<u64>().ok());
    if ac::exceeds_cap(declared, cap) {
        return sql_fail(&json!({ "error": "file_too_large", "limit_bytes": cap }));
    }

    // ── tokio: ek user ek waqt mein ek upload; poore server par 8 se zyada nahi ──
    let Some(_slot) = take_user_slot(&uid) else {
        return fail(StatusCode::TOO_MANY_REQUESTS, "upload_in_progress", "Another file is still uploading. Wait for it to finish.");
    };
    let Ok(_permit) = gate().try_acquire() else {
        return fail(StatusCode::SERVICE_UNAVAILABLE, "busy", "The server is busy with other uploads. Try again in a minute.");
    };

    let raw_name = headers.get("x-file-name").and_then(|v| v.to_str().ok()).map(ac::pct_decode).unwrap_or_default();
    let name = ac::sanitize_filename(&raw_name);
    let mime = ac::clean_mime(headers.get("x-file-type").and_then(|v| v.to_str().ok()).unwrap_or(""));

    // naam se hi rad: allowlist (body utaarne se pehle)
    if let Err(why) = ev::ext_allowed(&name) {
        return fail(StatusCode::UNPROCESSABLE_ENTITY, "file_type_blocked", &why);
    }

    let root = root();
    if !root_ready(&root).await {
        return fail(StatusCode::SERVICE_UNAVAILABLE, "storage_unavailable", "File storage is not available right now. Try again shortly.");
    }
    let tmp_dir = format!("{root}/appeals/{uid}/.tmp");
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

    // ── type allowlist + asli bytes ──
    if let Err(why) = ev::verdict(&name, &head) {
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
    let rel = match ev::rel_path(&uid, &sha, &rand8()) {
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
        "checked_at_unix": std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0),
    });
    let reg = match crate::sb_rpc(
        "appeal_evidence_register",
        json!({ "_user": uid, "_sha256": sha, "_size": total, "_filename": name, "_mime": mime, "_rel_path": rel, "_scan": scan }),
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
        // isi user ne yeh file pehle bhi di hai — nayi byte nahi rakhi
        let _ = tokio::fs::remove_file(&tmp_path).await;
    } else {
        let final_path = format!("{root}/{rel}");
        let parent = std::path::Path::new(&final_path).parent().map(|p| p.to_path_buf());
        let placed = match parent {
            Some(p) => tokio::fs::create_dir_all(&p).await.is_ok() && tokio::fs::rename(&tmp_path, &final_path).await.is_ok(),
            None => false,
        };
        if !placed {
            // storage ne jawab de diya — row wapas (safai ka kaam purge karega) aur file nahi rakhi
            let _ = crate::sb_rpc("appeal_evidence_remove", json!({ "_user": uid, "_id": id })).await;
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
        "max_files": max_files,
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
    let r = match crate::sb_rpc("appeal_evidence_resolve", json!({ "_actor": uid, "_id": id })).await {
        Ok(v) => v,
        Err(e) => return db_err(&e),
    };
    if !ctx_ok(&r) {
        return sql_fail(&r);
    }
    let rel = s_of(&r, "rel_path");
    if !ev::rel_path_valid(rel) {
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
    (
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, "application/octet-stream".to_string()),
            (header::CONTENT_DISPOSITION, ac::content_disposition(s_of(&r, "filename"))),
            (header::CONTENT_LENGTH, want.to_string()),
            (header::CACHE_CONTROL, "private, no-store".to_string()),
            (header::X_CONTENT_TYPE_OPTIONS, "nosniff".to_string()),
            (header::CONTENT_SECURITY_POLICY, "sandbox; default-src 'none'".to_string()),
        ],
        Body::from_stream(file_stream(file)),
    )
        .into_response()
}

/// File ko 64 KB tukdon mein stream (mpsc + spawn; client beech mein chala jaye to task khud ruk jata hai).
fn file_stream(mut file: tokio::fs::File) -> tokio_stream::wrappers::ReceiverStream<Result<axum::body::Bytes, std::io::Error>> {
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
