// ============================================================================
// export_glue.rs — ASLI data export (G36, Rust PRIMARY). SQL: docs/cursor-work/sql/E44_account_export.sql
//
//   account.export.ticket  {}        -> ek-bar ka download ticket (10 min)  -> {url:"/file/account-export?t=…"}
//   account.integrity.me   {}        -> apni account-integrity halat (clean / warned / blocked + export ke ghante)
//   account.integrity.appeal {statement} -> apna appeal (E46): user ke banned devices par, reviewer ko jata hai
//   GET /file/account-export?t=…     -> streaming ZIP: mail (.mbox + .jsonl) · attachments · contacts (.csv/.vcf) · calendar (.ics) · manifest.json
//
// Procedures sab plans ke liye (chat gate se pehle). Blocked account ko ticket sirf 72 ghante ki export window mein milta hai
// (SQL ticket_issue yeh khud dekhta hai). Zip 4 GB se bada na ho (ZipStream::would_exceed); bada ho to rukta hai aur manifest mein likhta hai.
// Child module of the crate root: uses `auth_user`, `sb_rpc`, `ok`, `err`. Adds NO dependency (sha2 pehle se Cargo.toml mein).
// ============================================================================

use crate::export_core as ec;
use axum::{
    body::{Body, Bytes},
    http::{header, StatusCode},
    response::IntoResponse,
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use tokio::sync::mpsc::Sender;

type Resp = axum::response::Response;
type Tx = Sender<Result<Bytes, std::io::Error>>;

pub fn owns(proc: &str) -> bool {
    matches!(proc, "account.export.ticket" | "account.integrity.me" | "account.integrity.appeal")
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let user = match crate::auth_user(token).await {
        Some((id, _)) => id,
        None => return crate::err(StatusCode::UNAUTHORIZED, "unauthorized", "").into_response(),
    };
    match proc {
        "account.export.ticket" => match crate::sb_rpc("account_export_ticket_issue", json!({ "_user": user })).await {
            Ok(v) if v.get("ok").and_then(|x| x.as_bool()) == Some(true) => {
                let t = v.get("ticket").and_then(|x| x.as_str()).unwrap_or("");
                crate::ok(json!({ "url": format!("/file/account-export?t={t}"), "expires_in": 600 })).into_response()
            }
            Ok(v) => {
                let code = v.get("error").and_then(|x| x.as_str()).unwrap_or("not_available").to_string();
                (StatusCode::CONFLICT, axum::Json(json!({ "error": { "code": code, "message": code }, "truth": v }))).into_response()
            }
            Err(e) => crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
        },
        "account.integrity.me" => match crate::sb_rpc("account_integrity_state", json!({ "_user": user })).await {
            Ok(v) => crate::ok(v).into_response(),
            // phase24a SQL na chala ho: kuch rokna nahi, sach batana
            Err(_) => crate::ok(json!({ "state": "clean", "unknown": true })).into_response(),
        },
        // blocked/warned user ka apna appeal (device hash user ko nahi chahiye: SQL us ke banned devices dhoondta hai)
        "account.integrity.appeal" => {
            let statement = input.get("statement").and_then(|x| x.as_str()).unwrap_or("").trim().to_string();
            if statement.chars().count() < 20 || statement.chars().count() > 2000 {
                return crate::err(StatusCode::BAD_REQUEST, "statement_required", "Write 20 to 2000 characters explaining why this block is wrong.").into_response();
            }
            match crate::sb_rpc("account_integrity_appeal", json!({ "_user": user, "_statement": statement })).await {
                Ok(v) => crate::ok(v).into_response(),
                Err(e) => crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
            }
        }
        _ => crate::err(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown export procedure").into_response(),
    }
}


// ───────────────────────── blocked-account guard (G37) ─────────────────────────
// main.rs ke dispatch mein token ke FORAN baad lagta hai (installer): blocked/purged account ki har call 403 `account_blocked`,
// siwaye export / apni halat / apna delete. Token ka sub bina verify padha jata hai (jhoota sub sirf us user ka haal dikhata hai).
// DB ya cache mein koi masla ho to guard KHULA rehta hai (fail-open): outage mein sab ko lock nahi karte.
static BLOCK_CACHE: std::sync::OnceLock<std::sync::Mutex<HashMap<String, (bool, std::time::Instant)>>> = std::sync::OnceLock::new();

async fn is_blocked(sub: &str) -> bool {
    let cache = BLOCK_CACHE.get_or_init(|| std::sync::Mutex::new(HashMap::new()));
    if let Ok(m) = cache.lock() {
        if let Some((v, at)) = m.get(sub) {
            if at.elapsed() < std::time::Duration::from_secs(30) {
                return *v;
            }
        }
    }
    let blocked = match crate::sb_select(&format!("account_integrity?user_id=eq.{sub}&select=state&limit=1")).await {
        Ok(Value::Array(a)) => a
            .first()
            .and_then(|r| r.get("state"))
            .and_then(|s| s.as_str())
            .map(|s| s == "blocked" || s == "purged")
            .unwrap_or(false),
        _ => false,
    };
    if let Ok(mut m) = cache.lock() {
        if m.len() > 5000 {
            m.clear();
        }
        m.insert(sub.to_string(), (blocked, std::time::Instant::now()));
    }
    blocked
}

pub async fn blocked(proc: &str, token: &str) -> Option<Resp> {
    if ec::allowed_when_blocked(proc) {
        return None;
    }
    let sub = ec::jwt_sub(token)?;
    if !is_blocked(&sub).await {
        return None;
    }
    Some(
        crate::err(
            StatusCode::FORBIDDEN,
            "account_blocked",
            "This account is blocked. You can still download your data until the export window ends.",
        )
        .into_response(),
    )
}

// ───────────────────────── download ─────────────────────────

fn now_unix() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

fn s_of(row: &Value, keys: &[&str]) -> String {
    for k in keys {
        if let Some(v) = row.get(*k) {
            if let Some(s) = v.as_str() {
                if !s.is_empty() {
                    return s.to_string();
                }
            }
        }
    }
    String::new()
}
/// text[] / jsonb array / "a@x.com" — teeno chalte hain
fn list_of(row: &Value, keys: &[&str]) -> Vec<String> {
    for k in keys {
        match row.get(*k) {
            Some(Value::Array(a)) => {
                let v: Vec<String> = a.iter().filter_map(|x| x.as_str().map(|s| s.to_string())).collect();
                if !v.is_empty() {
                    return v;
                }
            }
            Some(Value::String(s)) if !s.is_empty() => return vec![s.clone()],
            _ => {}
        }
    }
    vec![]
}
fn t_of(row: &Value, keys: &[&str]) -> i64 {
    for k in keys {
        if let Some(s) = row.get(*k).and_then(|x| x.as_str()) {
            if let Some(u) = ec::parse_iso(s) {
                return u;
            }
        }
    }
    0
}

/// Ek khuli ZIP file ka writer: bytes bhejta hai, crc/size zip mein, sha256 manifest ke liye.
struct Out {
    tx: Tx,
    z: ec::ZipStream,
    cur_sha: Option<Sha256>,
    cur_name: String,
    cur_bytes: u64,
    files: Vec<Value>,
    now: i64,
}
impl Out {
    async fn send(&self, b: Vec<u8>) -> Result<(), String> {
        self.tx.send(Ok(Bytes::from(b))).await.map_err(|_| "client_gone".to_string())
    }
    async fn begin(&mut self, name: &str) -> Result<(), String> {
        let h = self.z.begin_file(name, self.now);
        self.cur_sha = Some(Sha256::new());
        self.cur_name = name.to_string();
        self.cur_bytes = 0;
        self.send(h).await
    }
    async fn write(&mut self, data: &[u8]) -> Result<(), String> {
        if data.is_empty() {
            return Ok(());
        }
        self.z.account(data);
        if let Some(h) = self.cur_sha.as_mut() {
            h.update(data);
        }
        self.cur_bytes += data.len() as u64;
        self.send(data.to_vec()).await
    }
    async fn end(&mut self) -> Result<(), String> {
        let d = self.z.end_file();
        let sha = self.cur_sha.take().map(|h| h.finalize().iter().map(|b| format!("{b:02x}")).collect::<String>()).unwrap_or_default();
        self.files.push(json!({ "name": self.cur_name, "bytes": self.cur_bytes, "sha256": sha }));
        self.send(d).await
    }
    async fn small(&mut self, name: &str, data: &[u8]) -> Result<(), String> {
        self.begin(name).await?;
        self.write(data).await?;
        self.end().await
    }
}

/// Ek page (E44 `account_export_page`): (rows, next cursor)
async fn fetch_page(user: &str, kind: &str, after: &Option<String>) -> Result<(Vec<Value>, Option<String>), String> {
    let page = crate::sb_rpc("account_export_page", json!({ "_user": user, "_kind": kind, "_after": after, "_limit": 500 })).await?;
    let rows = page.get("rows").and_then(|r| r.as_array()).cloned().unwrap_or_default();
    let next = page.get("next").and_then(|x| x.as_str()).filter(|s| !s.is_empty()).map(|s| s.to_string());
    Ok((rows, next))
}
/// Chhote kinds ke saare rows (threads, attachments, contacts, events, attendees) — memory mein theek.
async fn all_rows(user: &str, kind: &str) -> Result<Vec<Value>, String> {
    let mut out = vec![];
    let mut after = None;
    loop {
        let (rows, next) = fetch_page(user, kind, &after).await?;
        out.extend(rows);
        match next {
            Some(n) => after = Some(n),
            None => break,
        }
    }
    Ok(out)
}

fn attach_roots() -> Vec<String> {
    let mut v = vec!["/mnt/anexomail-box/attachments".to_string()];
    if let Ok(extra) = std::env::var("EXPORT_ATTACH_ROOTS") {
        v.extend(extra.split(':').filter(|s| s.starts_with('/')).map(|s| s.to_string()));
    }
    v
}

async fn build(user: String, email: String, tx: Tx) -> Result<(), String> {
    let now = now_unix();
    let mut o = Out { tx, z: ec::ZipStream::new(), cur_sha: None, cur_name: String::new(), cur_bytes: 0, files: vec![], now };
    let mut counts = serde_json::Map::new();
    let mut notes: Vec<String> = vec![];

    o.small(
        "README.txt",
        format!(
            "ANEXOMAIL data export for {email}\nCreated: {}\n\nmail/all-mail.mbox      all your messages (open with Thunderbird, Apple Mail, or any mbox importer)\nmail/messages.jsonl     the same messages as raw database rows\nmail/threads.jsonl      your conversations (folder, state)\nmail/attachments/       attachment files, one folder per message\ncontacts/contacts.csv   contacts (spreadsheet)\ncontacts/contacts.vcf   contacts (import into any address book)\ncalendar/events.ics     calendar events (import into any calendar)\nmanifest.json           every file with its size and SHA-256, and anything that could not be included\n\nThis file is yours. Nothing here is sent anywhere.\n",
            ec::rfc2822(now)
        )
        .as_bytes(),
    )
    .await?;

    // ── threads (folder map) + threads.jsonl
    let threads = all_rows(&user, "threads").await?;
    let mut folder_of: HashMap<String, String> = HashMap::new();
    let mut lines = String::new();
    for r in &threads {
        folder_of.insert(s_of(r, &["id"]), s_of(r, &["folder"]));
        lines.push_str(&format!("{r}\n"));
    }
    o.small("mail/threads.jsonl", lines.as_bytes()).await?;
    counts.insert("threads".into(), json!(threads.len()));
    drop(lines);

    // ── messages.jsonl (page by page)
    o.begin("mail/messages.jsonl").await?;
    let mut n_msgs = 0u64;
    let mut after = None;
    loop {
        let (rows, next) = fetch_page(&user, "messages", &after).await?;
        for r in &rows {
            n_msgs += 1;
            o.write(format!("{r}\n").as_bytes()).await?;
        }
        match next {
            Some(n) => after = Some(n),
            None => break,
        }
    }
    o.end().await?;
    counts.insert("messages".into(), json!(n_msgs));

    // ── all-mail.mbox (page by page)
    o.begin("mail/all-mail.mbox").await?;
    let mut after = None;
    loop {
        let (rows, next) = fetch_page(&user, "messages", &after).await?;
        for r in &rows {
            let folder = folder_of.get(&s_of(r, &["thread_id"])).cloned().unwrap_or_default();
            let m = ec::MailMsg {
                from_name: s_of(r, &["from_name"]),
                from_addr: s_of(r, &["from_address", "from_addr"]),
                to: list_of(r, &["to_addresses", "to_addrs"]),
                cc: list_of(r, &["cc_addresses", "cc_addrs"]),
                subject: s_of(r, &["subject"]),
                unix: t_of(r, &["sent_at", "created_at"]),
                message_id: s_of(r, &["message_id", "message_id_header"]),
                in_reply_to: s_of(r, &["in_reply_to"]),
                body_text: s_of(r, &["body_text"]),
                body_html: s_of(r, &["body_html"]),
                folder,
            };
            o.write(&ec::mbox_entry(&m)).await?;
        }
        match next {
            Some(n) => after = Some(n),
            None => break,
        }
    }
    o.end().await?;

    // ── attachments rows + files
    let roots = attach_roots();
    let att_rows = all_rows(&user, "attachments").await?;
    let n_att = att_rows.len();
    counts.insert("attachments".into(), json!(n_att));
    let mut att_lines = String::new();
    for r in &att_rows {
        att_lines.push_str(&format!("{r}\n"));
    }
    o.small("mail/attachments.jsonl", att_lines.as_bytes()).await?;
    let mut att_ok = 0u64;
    let mut att_skipped = 0u64;
    let mut used: std::collections::HashSet<String> = std::collections::HashSet::new();
    for r in &att_rows {
        let path = s_of(r, &["disk_path", "storage_path"]);
        let canon = match tokio::fs::canonicalize(&path).await {
            Ok(p) => p,
            Err(_) => {
                att_skipped += 1;
                continue;
            }
        };
        let cs = canon.to_string_lossy().to_string();
        if !roots.iter().any(|root| cs.starts_with(&format!("{}/", root.trim_end_matches('/')))) {
            att_skipped += 1;
            continue;
        }
        let meta = match tokio::fs::metadata(&canon).await {
            Ok(m) if m.is_file() => m,
            _ => {
                att_skipped += 1;
                continue;
            }
        };
        if o.z.would_exceed(meta.len()) {
            notes.push("size_limit: remaining attachments were not included (a single export stays under 4 GB)".into());
            att_skipped += 1;
            break;
        }
        let mut name = format!("mail/attachments/{}/{}", ec::safe_name(&s_of(r, &["message_id"])), ec::safe_name(&s_of(r, &["filename"])));
        let mut n = 1;
        while !used.insert(name.clone()) {
            n += 1;
            name = format!("mail/attachments/{}/{}-{}", ec::safe_name(&s_of(r, &["message_id"])), n, ec::safe_name(&s_of(r, &["filename"])));
        }
        let mut f = match tokio::fs::File::open(&canon).await {
            Ok(f) => f,
            Err(_) => {
                att_skipped += 1;
                continue;
            }
        };
        o.begin(&name).await?;
        let mut buf = vec![0u8; 256 * 1024];
        loop {
            use tokio::io::AsyncReadExt;
            let k = f.read(&mut buf).await.map_err(|e| e.to_string())?;
            if k == 0 {
                break;
            }
            o.write(&buf[..k]).await?;
        }
        o.end().await?;
        att_ok += 1;
    }
    counts.insert("attachment_files_included".into(), json!(att_ok));
    if att_skipped > 0 {
        notes.push(format!("{att_skipped} attachment file(s) could not be included (file missing or outside the attachment store); their details are in mail/attachments.jsonl"));
    }

    // ── contacts
    let contacts = all_rows(&user, "contacts").await?;
    counts.insert("contacts".into(), json!(contacts.len()));
    let mut csv = ec::csv_row(&["name", "email", "other emails", "title", "company", "notes", "vip", "last contact"]);
    let mut vcf = String::new();
    for c in &contacts {
        let name = s_of(c, &["display_name"]);
        let primary = s_of(c, &["primary_address"]);
        let mut emails = vec![primary.clone()];
        for a in list_of(c, &["addresses"]) {
            if !emails.contains(&a) {
                emails.push(a);
            }
        }
        let others = emails.iter().skip(1).cloned().collect::<Vec<_>>().join("; ");
        let vip = if c.get("vip").and_then(|v| v.as_bool()) == Some(true) { "yes" } else { "" };
        csv.push_str(&ec::csv_row(&[&name, &primary, &others, &s_of(c, &["title"]), &s_of(c, &["company_domain"]), &s_of(c, &["notes"]), vip, &s_of(c, &["last_contact_at"])]));
        vcf.push_str(&ec::vcard(&name, &emails, &s_of(c, &["title"]), &s_of(c, &["company_domain"]), &s_of(c, &["notes"])));
    }
    o.small("contacts/contacts.csv", csv.as_bytes()).await?;
    o.small("contacts/contacts.vcf", vcf.as_bytes()).await?;

    // ── calendar
    let mut attendees: HashMap<String, Vec<String>> = HashMap::new();
    for r in all_rows(&user, "attendees").await? {
        attendees.entry(s_of(&r, &["event_id"])).or_default().push(s_of(&r, &["address"]));
    }
    let events = all_rows(&user, "events").await?;
    let mut ics = ec::ics_calendar_begin();
    for r in &events {
        let id = s_of(r, &["id"]);
        let e = ec::IcsEvent {
            uid: id.clone(),
            title: s_of(r, &["title"]),
            start: t_of(r, &["starts_at"]),
            end: t_of(r, &["ends_at"]),
            all_day: r.get("all_day").and_then(|v| v.as_bool()) == Some(true),
            location: s_of(r, &["location"]),
            description: s_of(r, &["agenda", "description"]),
            status: s_of(r, &["status"]),
            organiser: s_of(r, &["organiser"]),
            attendees: attendees.get(&id).cloned().unwrap_or_default(),
        };
        ics.push_str(&ec::ics_event(&e));
    }
    ics.push_str(&ec::ics_calendar_end());
    counts.insert("events".into(), json!(events.len()));
    o.small("calendar/events.ics", ics.as_bytes()).await?;

    // ── manifest (aakhri; apni sha nahi)
    let manifest = json!({
        "exported_for": email,
        "created_at": ec::rfc2822(now),
        "counts": Value::Object(counts),
        "files": o.files,
        "notes": notes,
        "scope": "your own mailbox; contacts and calendar of organisations you own; events you created elsewhere",
    });
    o.small("manifest.json", serde_json::to_string_pretty(&manifest).unwrap_or_default().as_bytes()).await?;
    let tail = o.z.finish();
    o.send(tail).await?;
    Ok(())
}

pub async fn download(axum::extract::Query(q): axum::extract::Query<HashMap<String, String>>) -> Resp {
    let t = q.get("t").cloned().unwrap_or_default();
    if t.len() != 48 || !t.chars().all(|c| c.is_ascii_hexdigit()) {
        return crate::err(StatusCode::UNAUTHORIZED, "invalid_ticket", "Ticket missing or malformed").into_response();
    }
    let used = match crate::sb_rpc("account_export_ticket_use", json!({ "_token": t })).await {
        Ok(v) => v,
        Err(e) => return crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
    };
    if used.get("ok").and_then(|v| v.as_bool()) != Some(true) {
        return crate::err(StatusCode::UNAUTHORIZED, "invalid_ticket", "Ticket expired or already used — create a new export").into_response();
    }
    let user = used.get("user_id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let scope = match crate::sb_rpc("account_export_scope", json!({ "_user": user })).await {
        Ok(v) => v,
        Err(e) => return crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
    };
    let email = scope.get("email").and_then(|v| v.as_str()).unwrap_or("").to_string();
    if email.is_empty() {
        return crate::err(StatusCode::NOT_FOUND, "user_not_found", "").into_response();
    }
    let (tx, rx) = tokio::sync::mpsc::channel::<Result<Bytes, std::io::Error>>(4);
    tokio::spawn(async move {
        let tx2 = tx.clone();
        if let Err(e) = build(user, email, tx).await {
            if e != "client_gone" {
                let _ = tx2.send(Err(std::io::Error::other(e))).await;
            }
        }
    });
    let day = ec::ics_date(now_unix());
    let body = Body::from_stream(tokio_stream::wrappers::ReceiverStream::new(rx));
    (
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, "application/zip".to_string()),
            (header::CONTENT_DISPOSITION, format!("attachment; filename=\"anexomail-export-{day}.zip\"")),
            (header::CACHE_CONTROL, "no-store".to_string()),
        ],
        body,
    )
        .into_response()
}
