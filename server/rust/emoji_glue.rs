// ============================================================================
// emoji_glue.rs — the I/O half of the COMPANY EMOJI PACK (QC1e D4A, AWAM ONLY, 20 Nov 2026).
//
// Procedures (all scoped to the CALLER'S organisation; the browser is never trusted for role or organisation):
//   member      emoji.pack.quota   {plan, limit, used, left, enabled} + my role + can_manage
//   member      emoji.pack.list    the active emoji (no bytes) + quota   (the picker's "Company" tab and the ":" list)
//   member      emoji.pack.get     {code} -> {mime, etag(=sha256), data_b64}  (immutable: the browser caches it by etag, forever)
//   owner/admin emoji.pack.add     {code, alt, image_b64} PNG or WebP -> clean lossless WebP (emoji_img) -> SQL door
//   owner/admin emoji.pack.remove  {code}
//   owner/admin emoji.pack.alt     {code, alt}
//
// Rules (core: emoji_core.rs + image half emoji_img.rs, unit-tested; database wall: SQL E193):
//   * the role is read from org_members by the server; SQL re-checks it (company_emoji_role) so a bug here cannot widen access;
//   * limits BEFORE work: base64 size, then magic bytes + header dimensions, then decode; the decode/encode runs in
//     spawn_blocking behind a ONE-permit semaphore (one picture at a time: a flood of uploads can never load the server);
//   * a daily upload cap per plan (abuse brake), the pack size cap lives in SQL (quota trigger, advisory lock);
//   * every add / remove / alt change is a line in the SQL hash-chain ledger (company_emoji_ledger).
//
// Child module of the crate root (main.rs): it uses crate::sb, crate::sb_rpc, crate::auth_user, crate::err, crate::ok.
// New dependencies for this module only: image-webp + png (pure Rust), installed by rust-engine-install.sh (module "emoji", opt-in).
// ============================================================================

use crate::emoji_core as core;
#[path = "emoji_img.rs"]
mod img;
// ClamAV (clamd INSTREAM, std only, tested in mail_inline_core.rs); the same file also carries the D4B mail MIME builder
#[path = "mail_inline_core.rs"]
mod inl;
use axum::{http::StatusCode, response::IntoResponse};
use base64::Engine as _;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::sync::OnceLock;

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "emoji.pack.quota" | "emoji.pack.list" | "emoji.pack.get" | "emoji.pack.add" | "emoji.pack.remove" | "emoji.pack.alt"
    )
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn is_uuid(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 36
        && b.iter().enumerate().all(|(i, &c)| match i {
            8 | 13 | 18 | 23 => c == b'-',
            _ => c.is_ascii_hexdigit(),
        })
}

fn now_secs() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

/// RFC 3339 UTC text for PostgREST filters (civil-from-days, no crate).
fn iso_utc(epoch: i64) -> String {
    let days = epoch.div_euclid(86400);
    let rem = epoch.rem_euclid(86400);
    let z = days + 719468;
    let era = z.div_euclid(146097);
    let doe = z.rem_euclid(146097);
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z", y, m, d, rem / 3600, (rem % 3600) / 60, rem % 60)
}

/* ----------------------------------------------------------------- REST */

async fn rest_get(path: &str) -> Result<Value, String> {
    let (url, key) = crate::sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let res = reqwest::Client::new()
        .get(format!("{url}/rest/v1/{path}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let ok = res.status().is_success();
    let body: Value = res.json().await.unwrap_or(Value::Null);
    if ok {
        Ok(body)
    } else {
        Err(body.to_string())
    }
}

fn pct(s: &str) -> String {
    s.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || b"-_.~".contains(&b) { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

/* ------------------------------------------------------------------ ctx */

struct Ctx {
    user_id: String,
    org_id: String,
    role: String,
}

async fn ctx(token: &str, input: &Value) -> Result<Ctx, Resp> {
    let (id, _email) = match crate::auth_user(token).await {
        Some(x) => x,
        None => return Err(fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid")),
    };
    if !is_uuid(&id) {
        return Err(fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid"));
    }
    let mine = rest_get(&format!("org_members?select=org_id,role,status&user_id=eq.{}", pct(&id)))
        .await
        .map_err(|_| fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Could not read your workspace"))?;
    let live: Vec<Value> = mine
        .as_array()
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter(|m| !st(m, "org_id").is_empty() && st(m, "status") != "revoked")
        .collect();
    if live.is_empty() {
        return Err(fail(StatusCode::CONFLICT, "no_workspace", "no_workspace"));
    }
    let requested = st(input, "org_id");
    let pick = live.iter().find(|m| !requested.is_empty() && st(m, "org_id") == requested).unwrap_or(&live[0]);
    let role = {
        let r = st(pick, "role");
        if r.is_empty() { "member".to_string() } else { r }
    };
    Ok(Ctx { user_id: id, org_id: st(pick, "org_id"), role })
}

fn can_manage(c: &Ctx) -> bool {
    matches!(c.role.as_str(), "owner" | "admin")
}

fn need_manage(c: &Ctx) -> Option<Resp> {
    if can_manage(c) {
        None
    } else {
        Some(fail(StatusCode::FORBIDDEN, "organisation_admin_required", "Only an owner or admin can change the company emoji."))
    }
}

/// SQL errors carry their E193 reason; turn them into an honest status + message (never a raw database dump).
fn sql_fail(e: &str) -> Resp {
    let m = |needle: &str| e.contains(needle);
    if m("E193 ROLE") {
        fail(StatusCode::FORBIDDEN, "organisation_admin_required", "Only an owner or admin can change the company emoji.")
    } else if m("E193 TIER") {
        fail(StatusCode::FORBIDDEN, "plan_required", "The company emoji pack is part of the Business plans.")
    } else if m("E193 QUOTA") {
        fail(StatusCode::CONFLICT, "pack_full", "Your plan's emoji limit is reached. Remove one first.")
    } else if m("E193 DUP") {
        fail(StatusCode::CONFLICT, "duplicate", "That shortcode or that picture is already in the pack.")
    } else if m("E193: ") && m("reserved") {
        fail(StatusCode::UNPROCESSABLE_ENTITY, "reserved_name", "That name is reserved. Pick another.")
    } else if m("function") && m("company_emoji") && m("not exist") {
        fail(StatusCode::SERVICE_UNAVAILABLE, "emoji_sql_missing", "emoji_sql_missing")
    } else {
        fail(StatusCode::BAD_REQUEST, "bad_request", "The emoji could not be saved.")
    }
}

// ---- advance technology (footer list: ClamAV + Hetzner Storage Box), his law 20 Nov 2026 04:28 -----------------------------------
// ClamAV: the clamd that already runs on his server (127.0.0.1:3310, shared with the founder mail intake). EMOJI_CLAMD or FMAIL_CLAMD overrides.
// FAIL CLOSED: if clamd cannot answer, the upload is refused and nothing is saved.
fn clamd_addr() -> String {
    for k in ["EMOJI_CLAMD", "FMAIL_CLAMD"] {
        let v = crate::env_var(k);
        if !v.trim().is_empty() {
            return v.trim().to_string();
        }
    }
    "127.0.0.1:3310".to_string()
}
// Hetzner Storage Box = the mount he already uses for attachments (/mnt/anexomail-box). Key = emoji/<org>/<sha256>.webp (content addressed).
fn box_root() -> String {
    let v = crate::env_var("EMOJI_BOX_DIR");
    if v.starts_with('/') && v.len() > 1 { v.trim_end_matches('/').to_string() } else { "/mnt/anexomail-box".to_string() }
}
fn box_key(org: &str, sha: &str) -> Option<String> {
    if !is_uuid(org) || !core::valid_sha(sha) {
        return None;
    }
    Some(format!("emoji/{}/{}.webp", org.to_ascii_lowercase(), sha))
}
/// write atomically (tmp + rename) and read back + compare the sha: the Box is trusted only after it returns the same bytes
fn box_put(root: &str, key: &str, bytes: &[u8], sha: &str) -> Result<(), String> {
    let full = format!("{}/{}", root, key);
    let dir = std::path::Path::new(&full).parent().ok_or("box path")?.to_path_buf();
    std::fs::create_dir_all(&dir).map_err(|e| format!("box mkdir: {e}"))?;
    let tmp = format!("{full}.tmp");
    std::fs::write(&tmp, bytes).map_err(|e| format!("box write: {e}"))?;
    std::fs::rename(&tmp, &full).map_err(|e| format!("box rename: {e}"))?;
    let back = std::fs::read(&full).map_err(|e| format!("box read back: {e}"))?;
    if hex(&Sha256::digest(&back)) != sha {
        let _ = std::fs::remove_file(&full);
        return Err("box read-back sha mismatch".into());
    }
    Ok(())
}
fn box_get(root: &str, key: &str, sha: &str) -> Result<Vec<u8>, String> {
    let b = std::fs::read(format!("{}/{}", root, key)).map_err(|e| format!("box read: {e}"))?;
    if hex(&Sha256::digest(&b)) != sha {
        return Err("box file sha mismatch".into());
    }
    Ok(b)
}

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{:02x}", x)).collect()
}

static GATE: OnceLock<tokio::sync::Semaphore> = OnceLock::new();
fn gate() -> &'static tokio::sync::Semaphore {
    GATE.get_or_init(|| tokio::sync::Semaphore::new(1))
}

/* ------------------------------------------------------------- dispatch */

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let c = match ctx(token, input).await {
        Ok(c) => c,
        Err(r) => return r,
    };
    match proc {
        "emoji.pack.quota" => quota(&c).await,
        "emoji.pack.list" => list(&c).await,
        "emoji.pack.get" => get(&c, input).await,
        "emoji.pack.add" => add(&c, input).await,
        "emoji.pack.remove" => remove(&c, input).await,
        "emoji.pack.alt" => alt(&c, input).await,
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    }
}

async fn quota(c: &Ctx) -> Resp {
    match crate::sb_rpc("company_emoji_quota", json!({ "p_org": c.org_id })).await {
        Ok(q) => crate::ok(json!({ "quota": q, "role": c.role, "can_manage": can_manage(c) })).into_response(),
        Err(e) => sql_fail(&e),
    }
}

async fn list(c: &Ctx) -> Resp {
    let items = match crate::sb_rpc("company_emoji_list", json!({ "p_org": c.org_id })).await {
        Ok(v) => v,
        Err(e) => return sql_fail(&e),
    };
    let q = crate::sb_rpc("company_emoji_quota", json!({ "p_org": c.org_id })).await.unwrap_or(Value::Null);
    crate::ok(json!({ "items": items, "quota": q, "role": c.role, "can_manage": can_manage(c) })).into_response()
}

async fn get(c: &Ctx, input: &Value) -> Resp {
    let code = match core::clean_code(&st(input, "code")) {
        Ok(x) => x,
        Err(m) => return fail(StatusCode::UNPROCESSABLE_ENTITY, "bad_code", m),
    };
    match crate::sb_rpc("company_emoji_get", json!({ "p_org": c.org_id, "p_code": code })).await {
        Ok(mut v) if v.get("ok").and_then(|x| x.as_bool()) == Some(true) => {
            // bytes that live in the Hetzner Storage Box are read back and verified against the sha before they leave the server
            if st(&v, "storage") == "hetzner" {
                let sha = st(&v, "etag");
                let key = st(&v, "storage_key");
                let got = match tokio::task::spawn_blocking(move || box_get(&box_root(), &key, &sha)).await {
                    Ok(Ok(b)) => b,
                    _ => return fail(StatusCode::BAD_GATEWAY, "store_unavailable", "The picture store did not answer. Try again."),
                };
                if let Some(o) = v.as_object_mut() {
                    o.insert("data_b64".into(), json!(base64::engine::general_purpose::STANDARD.encode(&got)));
                }
            }
            crate::ok(v).into_response()
        }
        Ok(_) => fail(StatusCode::NOT_FOUND, "not_found", "not_found"),
        Err(e) => sql_fail(&e),
    }
}

async fn add(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let code = match core::clean_code(&st(input, "code")) {
        Ok(x) => x,
        Err(m) => return fail(StatusCode::UNPROCESSABLE_ENTITY, "bad_code", m),
    };
    let alt = match core::clean_alt(&st(input, "alt")) {
        Ok(x) => x,
        Err(m) => return fail(StatusCode::UNPROCESSABLE_ENTITY, "bad_alt", m),
    };
    let b64 = st(input, "image_b64");
    // 1) size before anything is decoded (base64 is 4/3 of the bytes)
    if b64.is_empty() || b64.len() > core::MAX_UPLOAD_BYTES * 4 / 3 + 8 {
        return fail(StatusCode::PAYLOAD_TOO_LARGE, "too_big", "The picture is too big (max 512 KB).");
    }
    let raw = match base64::engine::general_purpose::STANDARD.decode(b64.trim()) {
        Ok(x) => x,
        Err(_) => return fail(StatusCode::UNPROCESSABLE_ENTITY, "bad_image", "The picture could not be read."),
    };
    // 2) plan + daily cap (abuse brake); the pack-size cap is enforced by SQL
    let plan = match crate::sb_rpc("company_emoji_quota", json!({ "p_org": c.org_id })).await {
        Ok(q) => st(&q, "plan"),
        Err(e) => return sql_fail(&e),
    };
    let cap = core::daily_upload_cap(&plan);
    if cap <= 0 {
        return fail(StatusCode::FORBIDDEN, "plan_required", "The company emoji pack is part of the Business plans.");
    }
    let since = iso_utc(now_secs() - 86400);
    if let Ok(rows) = rest_get(&format!(
        "company_emoji_ledger?select=seq&org_id=eq.{}&action=eq.add&created_at=gte.{}&limit={}",
        pct(&c.org_id),
        pct(&since),
        cap + 1
    ))
    .await
    {
        if rows.as_array().map(|a| a.len() as i64).unwrap_or(0) >= cap {
            return fail(StatusCode::TOO_MANY_REQUESTS, "daily_limit", "Too many uploads today. Try again tomorrow.");
        }
    }
    // 3) one picture at a time, off the async threads
    let _permit = match gate().acquire().await {
        Ok(p) => p,
        Err(_) => return fail(StatusCode::SERVICE_UNAVAILABLE, "busy", "Busy, try again."),
    };
    let cleaned = match tokio::task::spawn_blocking(move || img::clean(&raw)).await {
        Ok(Ok(x)) => x,
        Ok(Err(m)) => return fail(StatusCode::UNPROCESSABLE_ENTITY, "bad_image", &m),
        Err(_) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Image worker failed."),
    };
    drop(_permit);
    let sha = hex(&Sha256::digest(&cleaned.webp));
    // ClamAV FIRST (fail closed): an infected or un-scannable picture is never saved
    {
        let (addr, bytes) = (clamd_addr(), cleaned.webp.clone());
        match tokio::task::spawn_blocking(move || inl::clamd_instream(&addr, &bytes)).await {
            Ok(Ok(())) => {}
            Ok(Err(m)) if m.contains("FOUND") => {
                return fail(StatusCode::UNPROCESSABLE_ENTITY, "virus", "This picture was refused by the virus scanner.");
            }
            _ => {
                return fail(StatusCode::SERVICE_UNAVAILABLE, "scanner_unavailable", "Virus scanning is not available right now. Nothing was saved. Try again in a moment.");
            }
        }
    }
    let res = crate::sb_rpc(
        "company_emoji_add",
        json!({
            "p_org": c.org_id, "p_actor": c.user_id, "p_code": code, "p_alt": alt, "p_sha": sha,
            "p_w": cleaned.w, "p_h": cleaned.h, "p_data": format!("\\x{}", hex(&cleaned.webp)),
        }),
    )
    .await;
    match res {
        Ok(v) => {
            // record the scan, then move the bytes to the Storage Box (SQL refuses the move unless the scan says clean)
            let mut storage = "pg";
            let scan_ok = crate::sb_rpc("company_emoji_scan_set", json!({ "p_org": c.org_id, "p_code": code, "p_state": "clean", "p_engine": "clamav" })).await.is_ok();
            if scan_ok {
                if let Some(key) = box_key(&c.org_id, &sha) {
                    let (k2, b2, s2) = (key, cleaned.webp.clone(), sha.clone());
                    let put = tokio::task::spawn_blocking(move || box_put(&box_root(), &k2, &b2, &s2)).await;
                    if matches!(put, Ok(Ok(()))) && crate::sb_rpc("company_emoji_store_move", json!({ "p_org": c.org_id, "p_code": code })).await.is_ok() {
                        storage = "hetzner";
                    }
                }
            }
            crate::ok(json!({ "added": v, "w": cleaned.w, "h": cleaned.h, "bytes": cleaned.webp.len(), "step": cleaned.step, "scan": if scan_ok { "clean" } else { "unscanned" }, "storage": storage })).into_response()
        }
        Err(e) => sql_fail(&e),
    }
}

async fn remove(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let code = match core::clean_code(&st(input, "code")) {
        Ok(x) => x,
        Err(m) => return fail(StatusCode::UNPROCESSABLE_ENTITY, "bad_code", m),
    };
    // remember where the bytes live before the row is removed (best-effort cleanup of the Storage Box file afterwards)
    let before = crate::sb_rpc("company_emoji_get", json!({ "p_org": c.org_id, "p_code": code })).await.ok();
    match crate::sb_rpc("company_emoji_remove", json!({ "p_org": c.org_id, "p_actor": c.user_id, "p_code": code })).await {
        Ok(v) if v.get("ok").and_then(|x| x.as_bool()) == Some(true) => {
            if let Some(b) = before {
                if st(&b, "storage") == "hetzner" {
                    if let Some(key) = box_key(&c.org_id, &st(&b, "etag")) {
                        let _ = tokio::task::spawn_blocking(move || std::fs::remove_file(format!("{}/{}", box_root(), key))).await;
                    }
                }
            }
            crate::ok(v).into_response()
        }
        Ok(_) => fail(StatusCode::NOT_FOUND, "not_found", "not_found"),
        Err(e) => sql_fail(&e),
    }
}

async fn alt(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let code = match core::clean_code(&st(input, "code")) {
        Ok(x) => x,
        Err(m) => return fail(StatusCode::UNPROCESSABLE_ENTITY, "bad_code", m),
    };
    let alt = match core::clean_alt(&st(input, "alt")) {
        Ok(x) => x,
        Err(m) => return fail(StatusCode::UNPROCESSABLE_ENTITY, "bad_alt", m),
    };
    match crate::sb_rpc("company_emoji_rename_alt", json!({ "p_org": c.org_id, "p_actor": c.user_id, "p_code": code, "p_alt": alt })).await {
        Ok(v) if v.get("ok").and_then(|x| x.as_bool()) == Some(true) => crate::ok(v).into_response(),
        Ok(_) => fail(StatusCode::NOT_FOUND, "not_found", "not_found"),
        Err(e) => sql_fail(&e),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn iso_matches_known_dates() {
        assert_eq!(iso_utc(0), "1970-01-01T00:00:00Z");
        assert_eq!(iso_utc(1_700_000_000), "2023-11-14T22:13:20Z");
        assert_eq!(iso_utc(1_795_145_405), "2026-11-20T03:30:05Z");
    }
    #[test]
    fn uuid_check() {
        assert!(is_uuid("123e4567-e89b-12d3-a456-426614174000"));
        assert!(!is_uuid("nope"));
    }
    #[test]
    fn owns_only_emoji() {
        assert!(owns("emoji.pack.add") && !owns("team.members.list"));
    }
    #[test]
    fn box_key_is_content_addressed() {
        let org = "11111111-1111-1111-1111-111111111111";
        let sha = "a".repeat(64);
        assert_eq!(box_key(org, &sha), Some(format!("emoji/{org}/{sha}.webp")));
        assert_eq!(box_key("../etc", &sha), None);
        assert_eq!(box_key(org, "short"), None);
    }

    #[test]
    fn box_put_get_roundtrip_and_tamper() {
        let dir = std::env::temp_dir().join(format!("emoji-box-{}", std::process::id()));
        let root = dir.to_str().unwrap().to_string();
        let bytes = b"RIFF\x04\0\0\0WEBPxx".to_vec();
        let sha = hex(&Sha256::digest(&bytes));
        let key = box_key("11111111-1111-1111-1111-111111111111", &sha).unwrap();
        box_put(&root, &key, &bytes, &sha).unwrap();
        assert_eq!(box_get(&root, &key, &sha).unwrap(), bytes);
        std::fs::write(format!("{}/{}", root, key), b"tampered").unwrap();
        assert!(box_get(&root, &key, &sha).is_err());
        assert!(box_put(&root, &key, &bytes, &"0".repeat(64)).is_err()); // wrong sha is refused and the file removed
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn sql_errors_map() {
        assert_eq!(sql_fail("E193 QUOTA: x").status(), StatusCode::CONFLICT);
        assert_eq!(sql_fail("E193 ROLE: x").status(), StatusCode::FORBIDDEN);
        assert_eq!(sql_fail("boom").status(), StatusCode::BAD_REQUEST);
    }
}
