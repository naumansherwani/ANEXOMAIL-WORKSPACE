// ============================================================================
// inbound_attach.rs — G38b: AANE WALI mail ke attachments ke bytes Storage Box par (20 Oct 2026).
//
// Pehle aane wali mail ke attachments ka sirf naam/size (metadata) jata tha. Ab (do hissay, Postfix ko kabhi nahi rokte):
//   1. `anexomail-deliver` mail DB mein daalta hai (pehle jaisa). Agar mail mein attachments hain aur DB ne (message_id, org_id) diye,
//      to usi mail ki copy local spool mein rakhta hai (`<message_uuid>_<org_uuid>.eml`). Spool likhna fail ho to mail PHIR BHI
//      theek rahti hai (sirf log likhta hai) — mail kabhi nahi khoti.
//   2. `anexomail-deliver --spool-run` (systemd timer, har minute, root): spool se attachments nikalta hai -> SHA-256 -> clamd scan ->
//      Storage Box par file (`<org>/<sha[0..2]>/<sha>-<nonce8>`) -> DB `mail_attach_inbound_register` (E50: quota + dedup SIRF org ke
//      andar + mojooda row se jodna). Kuch bhi atke (Storage Box down, DB down) to spool file wahin rehti hai, agle minute dobara.
// Virus mile to bytes rakhe nahi jate (row par scan likha jata hai). Quota bhar jaye to mail aati hai, bytes nahi rakhe jate.
// Same `ATTACH_DIR` / mount-check / path-shape jo outgoing (attach_glue) istemal karta hai — ek hi jagah, ek hi qaida.
// Sirf std + tokio + reqwest + serde_json + sha2 (deliver binary ke pehle se maujood crates). Pure helpers neeche tests ke saath.
// ============================================================================

use crate::attach_core as ac;
use crate::mig_mime;
use serde_json::{json, Map, Value};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

/// Is se bari attachment ke bytes nahi rakhte (Postfix 50 MB mail par bhi yeh kabhi nahi tootta; sirf ehtiyat).
pub const MAX_ATTACH_BYTES: usize = 60 * 1024 * 1024;
/// Ek `--spool-run` mein itni mails (baqi agle minute).
pub const MAX_PER_RUN: usize = 25;

pub fn spool_dir() -> String {
    let v = std::env::var("ANEXOMAIL_INBOUND_SPOOL").unwrap_or_default();
    if v.starts_with('/') && v.len() > 1 { v.trim_end_matches('/').to_string() } else { "/var/spool/anexomail-inbound".to_string() }
}

pub fn attach_root(env: &Map<String, Value>) -> String {
    let v = env.get("ATTACH_DIR").and_then(|x| x.as_str()).unwrap_or("");
    if v.starts_with('/') && v.len() > 1 { v.trim_end_matches('/').to_string() } else { "/mnt/anexomail-box/attachments".to_string() }
}

fn mount_point(env: &Map<String, Value>) -> Option<String> {
    let m = env.get("ATTACH_MOUNT").and_then(|x| x.as_str()).unwrap_or("");
    if !m.is_empty() {
        return if m == "none" { None } else { Some(m.to_string()) };
    }
    if env.get("ATTACH_DIR").and_then(|x| x.as_str()).unwrap_or("").is_empty() { Some("/mnt/anexomail-box".to_string()) } else { None }
}

/// Mountpoint ki pehchan: device id parent se alag (sshfs/FUSE). Mount gira ho to khali LOCAL folder par kabhi nahi likhte.
fn is_mountpoint(p: &str) -> bool {
    use std::os::unix::fs::MetadataExt;
    let path = Path::new(p);
    let (Ok(a), Some(parent)) = (std::fs::metadata(path), path.parent()) else { return false };
    let Ok(b) = std::fs::metadata(parent) else { return false };
    a.dev() != b.dev()
}

pub fn root_ready(env: &Map<String, Value>) -> Result<String, String> {
    let root = attach_root(env);
    if let Some(mp) = mount_point(env) {
        if !is_mountpoint(&mp) {
            return Err(format!("storage_unavailable: {mp} mount nahi hai"));
        }
    }
    match std::fs::metadata(&root) {
        Ok(m) if m.is_dir() => Ok(root),
        _ => Err(format!("storage_unavailable: {root} nahi hai")),
    }
}

/* ------------------------------------------------------------------ pure helpers */

pub fn spool_name(msg: &str, org: &str) -> Option<String> {
    if ac::valid_uuid(msg) && ac::valid_uuid(org) { Some(format!("{msg}_{org}.eml")) } else { None }
}

pub fn parse_spool_name(name: &str) -> Option<(String, String)> {
    let stem = name.strip_suffix(".eml")?;
    let (m, o) = stem.split_once('_')?;
    if ac::valid_uuid(m) && ac::valid_uuid(o) { Some((m.to_string(), o.to_string())) } else { None }
}

/// `mail_ingest` ka jawab -> (message_id, org_id). Quarantine / adhoora jawab => None (kuch spool nahi hota).
pub fn ingest_ids(resp: &str) -> Option<(String, String)> {
    let v: Value = serde_json::from_str(resp).ok()?;
    if v.get("quarantined").and_then(|x| x.as_bool()).unwrap_or(false) {
        return None;
    }
    let m = v.get("message_id").and_then(|x| x.as_str())?.to_ascii_lowercase();
    let o = v.get("org_id").and_then(|x| x.as_str())?.to_ascii_lowercase();
    if ac::valid_uuid(&m) && ac::valid_uuid(&o) { Some((m, o)) } else { None }
}

/// Mail mein kitne attachments (jin ke bytes rakhne hain): naam, mime, ordinal (usi naam wali pichli kitni), jagah.
pub struct Found {
    pub filename: String,
    pub mime: String,
    pub ordinal: i32,
    pub src: mig_mime::AttachSrc,
}

pub fn attachments_of(raw: &[u8]) -> Vec<Found> {
    let p = mig_mime::parse(raw);
    let mut out: Vec<Found> = Vec::new();
    for (i, a) in p.attachments.iter().enumerate() {
        let Some(src) = p.attachment_src.get(i) else { break };
        let ordinal = out.iter().filter(|f| f.filename == a.filename).count() as i32;
        out.push(Found { filename: a.filename.clone(), mime: a.mime.clone(), ordinal, src: src.clone() });
    }
    out
}

/// Spool mein mail rakhna: tmp file likh kar rename (aadhi file kabhi nazar nahi aati). Mode 0640.
pub fn write_spool(dir: &str, msg: &str, org: &str, raw: &[u8]) -> std::io::Result<()> {
    use std::io::Write;
    use std::os::unix::fs::OpenOptionsExt;
    let name = spool_name(msg, org).ok_or_else(|| std::io::Error::new(std::io::ErrorKind::InvalidInput, "bad ids"))?;
    std::fs::create_dir_all(dir)?;
    let tmp = Path::new(dir).join(format!(".{name}.{}.part", std::process::id()));
    let fin = Path::new(dir).join(&name);
    {
        let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(0o640).open(&tmp)?;
        f.write_all(raw)?;
        f.sync_all()?;
    }
    std::fs::rename(&tmp, &fin)
}

/// Deliver ke baad: mail mein attachments hon aur DB ne ids di hon to spool. Kabhi fail nahi karta (mail pehle hi DB mein hai).
pub fn maybe_spool(raw: &[u8], ingest_resp: &str) -> Option<String> {
    let (msg, org) = ingest_ids(ingest_resp)?;
    let n = attachments_of(raw).len();
    if n == 0 {
        return None;
    }
    match write_spool(&spool_dir(), &msg, &org, raw) {
        Ok(()) => Some(format!("spooled {n} attachment(s)")),
        Err(e) => Some(format!("SPOOL FAILED ({e}) — attachments sirf metadata rahengi")),
    }
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
    h.finalize().iter().take(4).map(|b| format!("{b:02x}")).collect()
}

fn hex(d: &[u8]) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}

/* ------------------------------------------------------------------ io */

async fn scan_bytes(addr: &str, data: &[u8]) -> Option<ac::ClamVerdict> {
    let mut stream = match tokio::time::timeout(Duration::from_millis(800), tokio::net::TcpStream::connect(addr)).await {
        Ok(Ok(s)) => s,
        _ => return None,
    };
    if stream.write_all(b"zINSTREAM\0").await.is_err() {
        return None;
    }
    for chunk in data.chunks(64 * 1024) {
        if stream.write_all(&(chunk.len() as u32).to_be_bytes()).await.is_err() || stream.write_all(chunk).await.is_err() {
            return Some(ac::ClamVerdict::Error("write failed (clamd limit?)".into()));
        }
    }
    if stream.write_all(&0u32.to_be_bytes()).await.is_err() {
        return Some(ac::ClamVerdict::Error("write failed".into()));
    }
    let mut reply = Vec::new();
    let _ = tokio::time::timeout(Duration::from_secs(90), stream.read_to_end(&mut reply)).await;
    let text = String::from_utf8_lossy(&reply).to_string();
    if text.trim_matches(|c: char| c == '\0' || c.is_whitespace()).is_empty() {
        return None;
    }
    Some(ac::parse_clamd(&text))
}

async fn rpc(client: &reqwest::Client, url: &str, key: &str, name: &str, args: Value) -> Result<Value, String> {
    let res = client
        .post(format!("{}/rest/v1/rpc/{name}", url.trim_end_matches('/')))
        .header("apikey", key)
        .header("authorization", format!("Bearer {key}"))
        .header("content-type", "application/json")
        .json(&args)
        .send()
        .await
        .map_err(|e| format!("network {e}"))?;
    let status = res.status();
    let body = res.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(format!("db {} {}", status.as_u16(), body.chars().take(200).collect::<String>()));
    }
    serde_json::from_str(&body).map_err(|e| format!("db json {e}"))
}

fn env_s(env: &Map<String, Value>, k: &str) -> String {
    env.get(k).and_then(|v| v.as_str()).unwrap_or("").to_string()
}

pub struct Totals {
    pub processed: usize,
    pub failed: usize,
    pub left: usize,
    pub oldest_age_s: u64,
}

/// Ek spool mail: har attachment ke liye scan -> file -> DB. Ok(()) = poori ho gayi (spool file hatai ja sakti hai).
async fn process_one(env: &Map<String, Value>, client: &reqwest::Client, root: &str, path: &Path, msg: &str, org: &str) -> Result<(), String> {
    let raw = tokio::fs::read(path).await.map_err(|e| format!("spool read: {e}"))?;
    let url = env_s(env, "SUPABASE_URL");
    let key = env_s(env, "SUPABASE_SERVICE_ROLE_KEY");
    let clamd = {
        let v = env_s(env, "CLAMD_ADDR");
        if v.is_empty() { "127.0.0.1:3310".to_string() } else { v }
    };
    for f in attachments_of(&raw) {
        let data = mig_mime::attachment_bytes(&raw, &f.src);
        let size = data.len() as i64;
        let mut args = json!({ "_org": org, "_message": msg, "_ordinal": f.ordinal, "_filename": f.filename, "_mime": ac::clean_mime(&f.mime), "_size": size });
        let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
        if data.is_empty() {
            continue; // khali part: rakhne ko kuch nahi
        }
        if data.len() > MAX_ATTACH_BYTES {
            args["_sha256"] = Value::Null;
            args["_rel_path"] = Value::Null;
            args["_scan"] = json!({ "reason": "too_large", "checked_at_unix": now });
            rpc(client, &url, &key, "mail_attach_inbound_register", args).await?;
            continue;
        }
        let sha = hex(&Sha256::digest(&data));
        let (clam, scanned, found_sig) = match scan_bytes(&clamd, &data).await {
            Some(ac::ClamVerdict::Found(sig)) => ("found".to_string(), true, Some(sig)),
            Some(ac::ClamVerdict::Clean) => ("clean".to_string(), true, None),
            Some(ac::ClamVerdict::Error(e)) => (format!("error:{e}"), false, None),
            None => ("unavailable".to_string(), false, None),
        };
        let mut scan = json!({
            "type_policy": "inbound",
            "clamd": clam,
            "scanned": scanned,
            "engines": if scanned { json!(["clamd-local"]) } else { json!([]) },
            "checked_at_unix": now,
        });
        if let Some(sig) = found_sig {
            scan["signature"] = json!(sig);
            args["_sha256"] = Value::Null;
            args["_rel_path"] = Value::Null;
            args["_scan"] = scan;
            rpc(client, &url, &key, "mail_attach_inbound_register", args).await?;
            continue;
        }
        let rel = ac::rel_path(org, &sha, &rand8()).ok_or("bad path")?;
        let fin = Path::new(root).join(&rel);
        // file PEHLE (nonce wala naya path, takrao mumkin nahi), DB BAAD mein: DB kabhi aisi file ko nahi dikhata jo disk par na ho
        let tmp_dir = Path::new(root).join(".tmp");
        tokio::fs::create_dir_all(&tmp_dir).await.map_err(|e| format!("storage_unavailable: {e}"))?;
        let tmp = tmp_dir.join(format!("in-{}-{}", std::process::id(), rand8()));
        {
            let mut fh = tokio::fs::File::create(&tmp).await.map_err(|e| format!("storage_unavailable: {e}"))?;
            fh.write_all(&data).await.map_err(|e| format!("storage_unavailable: {e}"))?;
            fh.flush().await.map_err(|e| format!("storage_unavailable: {e}"))?;
            fh.sync_all().await.map_err(|e| format!("storage_unavailable: {e}"))?;
        }
        let parent = fin.parent().map(|p| p.to_path_buf()).ok_or("bad path")?;
        if let Err(e) = tokio::fs::create_dir_all(&parent).await {
            let _ = tokio::fs::remove_file(&tmp).await;
            return Err(format!("storage_unavailable: {e}"));
        }
        if let Err(e) = tokio::fs::rename(&tmp, &fin).await {
            let _ = tokio::fs::remove_file(&tmp).await;
            return Err(format!("storage_unavailable: {e}"));
        }
        args["_sha256"] = json!(sha);
        args["_rel_path"] = json!(rel);
        args["_scan"] = scan;
        let reg = match rpc(client, &url, &key, "mail_attach_inbound_register", args).await {
            Ok(v) => v,
            Err(e) => {
                let _ = tokio::fs::remove_file(&fin).await;
                return Err(e);
            }
        };
        let ok = reg.get("ok").and_then(|v| v.as_bool()).unwrap_or(false);
        let stored = reg.get("stored").and_then(|v| v.as_bool()).unwrap_or(false);
        let deduped = reg.get("deduped").and_then(|v| v.as_bool()).unwrap_or(false);
        if !ok || !stored || deduped {
            // bekar copy (dedup / quota / galti): hamari nayi file hatao; asli blob ki file nahi chhoote
            let _ = tokio::fs::remove_file(&fin).await;
        }
        if !ok {
            return Err(format!("register: {}", reg.get("error").and_then(|v| v.as_str()).unwrap_or("unknown")));
        }
    }
    Ok(())
}

/// Spool ki saari mails (purani pehle), MAX_PER_RUN tak. Storage Box mount na ho to kuch nahi chhoota (Err).
pub async fn run_spool(env: &Map<String, Value>) -> Result<Totals, String> {
    let dir = spool_dir();
    let mut entries: Vec<(std::time::SystemTime, PathBuf, String, String)> = Vec::new();
    match std::fs::read_dir(&dir) {
        Ok(rd) => {
            for e in rd.flatten() {
                let name = e.file_name().to_string_lossy().to_string();
                if let Some((m, o)) = parse_spool_name(&name) {
                    let mt = e.metadata().and_then(|m| m.modified()).unwrap_or_else(|_| std::time::SystemTime::now());
                    entries.push((mt, e.path(), m, o));
                }
            }
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Totals { processed: 0, failed: 0, left: 0, oldest_age_s: 0 }),
        Err(e) => return Err(format!("spool read: {e}")),
    }
    entries.sort_by_key(|e| e.0);
    let oldest_age_s = entries.first().map(|e| e.0.elapsed().map(|d| d.as_secs()).unwrap_or(0)).unwrap_or(0);
    if entries.is_empty() {
        return Ok(Totals { processed: 0, failed: 0, left: 0, oldest_age_s: 0 });
    }
    let root = root_ready(env)?;
    if env_s(env, "SUPABASE_URL").is_empty() || env_s(env, "SUPABASE_SERVICE_ROLE_KEY").is_empty() {
        return Err("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing".into());
    }
    let client = reqwest::Client::builder().timeout(Duration::from_secs(60)).connect_timeout(Duration::from_secs(10)).build().map_err(|e| e.to_string())?;
    let (mut processed, mut failed) = (0usize, 0usize);
    for (_, path, msg, org) in entries.iter().take(MAX_PER_RUN) {
        match process_one(env, &client, &root, path, msg, org).await {
            Ok(()) => {
                let _ = std::fs::remove_file(path);
                processed += 1;
                eprintln!("inbound-attach: OK {msg}");
            }
            Err(e) => {
                failed += 1;
                eprintln!("inbound-attach: RETRY {msg}: {e}");
            }
        }
    }
    Ok(Totals { processed, failed, left: entries.len() - processed, oldest_age_s })
}

#[cfg(test)]
mod tests {
    use super::*;

    const M: &str = "aaaaaaaa-0000-4000-8000-000000000001";
    const O: &str = "11111111-1111-4111-8111-111111111111";

    fn crlf(s: &str) -> Vec<u8> {
        s.replace('\n', "\r\n").into_bytes()
    }

    #[test]
    fn spool_names_roundtrip_and_reject_tricks() {
        let n = spool_name(M, O).unwrap();
        assert_eq!(parse_spool_name(&n), Some((M.to_string(), O.to_string())));
        assert!(spool_name("../x", O).is_none());
        assert!(parse_spool_name("../../etc/passwd").is_none());
        assert!(parse_spool_name(&format!("{M}_{O}.eml.part")).is_none());
        assert!(parse_spool_name(&format!("{M}_{O}")).is_none());
        assert!(parse_spool_name(&format!("{}_{O}.eml", M.to_uppercase())).is_none());
    }

    #[test]
    fn ingest_ids_only_from_a_real_ingest() {
        let ok = format!(r#"{{"ok":true,"org_id":"{O}","thread_id":"{M}","message_id":"{M}"}}"#);
        assert_eq!(ingest_ids(&ok), Some((M.to_string(), O.to_string())));
        assert!(ingest_ids(r#"{"ok":true,"quarantined":true,"reason":"unknown_recipient"}"#).is_none());
        assert!(ingest_ids(r#"{"ok":true,"org_id":"x","message_id":"y"}"#).is_none());
        assert!(ingest_ids("not json").is_none());
        assert!(ingest_ids(&format!(r#"{{"quarantined":true,"org_id":"{O}","message_id":"{M}"}}"#)).is_none());
    }

    #[test]
    fn finds_attachments_in_order_with_ordinals_and_decodes_bytes() {
        let raw = crlf("From: a@x.com\nTo: b@y.com\nSubject: s\nContent-Type: multipart/mixed; boundary=\"M\"\n\n--M\nContent-Type: text/plain\n\nhello\n--M\nContent-Type: application/pdf; name=\"q.pdf\"\nContent-Disposition: attachment; filename=\"q.pdf\"\nContent-Transfer-Encoding: base64\n\nSGVsbG8gd29ybGQ=\n--M\nContent-Type: text/plain; name=\"q.pdf\"\nContent-Disposition: attachment; filename=\"q.pdf\"\nContent-Transfer-Encoding: quoted-printable\n\nPrice =E2=82=AC10\n--M\nContent-Type: application/octet-stream; name=\"raw.bin\"\nContent-Disposition: attachment; filename=\"raw.bin\"\n\n\x01\x02\x03\n--M--\n");
        let f = attachments_of(&raw);
        assert_eq!(f.len(), 3);
        assert_eq!((f[0].filename.as_str(), f[0].ordinal), ("q.pdf", 0));
        assert_eq!((f[1].filename.as_str(), f[1].ordinal), ("q.pdf", 1));
        assert_eq!((f[2].filename.as_str(), f[2].ordinal), ("raw.bin", 0));
        assert_eq!(mig_mime::attachment_bytes(&raw, &f[0].src), b"Hello world");
        assert_eq!(mig_mime::attachment_bytes(&raw, &f[1].src), "Price €10".as_bytes());
        assert_eq!(mig_mime::attachment_bytes(&raw, &f[2].src), b"\x01\x02\x03");
        // metadata aur bytes ka size wahi jo mig_mime ne naapa
        let p = mig_mime::parse(&raw);
        for (i, a) in p.attachments.iter().enumerate() {
            assert_eq!(mig_mime::attachment_bytes(&raw, &f[i].src).len(), a.size, "size of {}", a.filename);
        }
    }

    #[test]
    fn mail_without_attachments_spools_nothing() {
        let raw = crlf("From: a@x.com\nTo: b@y.com\nSubject: s\n\nplain text only\n");
        assert!(attachments_of(&raw).is_empty());
        let resp = format!(r#"{{"ok":true,"org_id":"{O}","message_id":"{M}"}}"#);
        assert!(maybe_spool(&raw, &resp).is_none());
    }

    #[test]
    fn spool_write_is_atomic_and_private() {
        use std::os::unix::fs::PermissionsExt;
        let d = std::env::temp_dir().join(format!("ax-spool-{}", std::process::id()));
        let ds = d.to_str().unwrap().to_string();
        write_spool(&ds, M, O, b"raw mail").unwrap();
        let p = d.join(spool_name(M, O).unwrap());
        assert_eq!(std::fs::read(&p).unwrap(), b"raw mail");
        assert_eq!(std::fs::metadata(&p).unwrap().permissions().mode() & 0o777, 0o640);
        let names: Vec<String> = std::fs::read_dir(&d).unwrap().flatten().map(|e| e.file_name().to_string_lossy().to_string()).collect();
        assert_eq!(names.len(), 1, "no .part leftovers: {names:?}");
        assert!(write_spool(&ds, "../x", O, b"x").is_err());
        let _ = std::fs::remove_dir_all(d);
    }
}
