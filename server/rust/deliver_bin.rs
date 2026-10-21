// ============================================================================
// anexomail-deliver (Rust) — Postfix `anexopipe` -> PostgreSQL `mail_ingest` (R1a, 20 Oct 2026; founder "haan" for the mail path).
//
// Replaces the Bun pipe `server/mail/deliver-to-supabase.ts` (kept on disk as the rollback). Same contract, same exit codes:
//   argv: anexomail-deliver <envelope sender> <envelope recipient>        (master.cf: flags=DRhu user=vmail)
//   stdin: the raw RFC 5322 message
//   exit 0  = stored (or quarantined by the E37 gate — never in a stranger's organisation)
//   exit 75 = temporary failure (EX_TEMPFAIL): Postfix keeps it in the queue and retries — mail is never lost
//
// Why Rust: the Bun parser only split the first MIME level and stored RFC 2047 subjects raw ("=?UTF-8?B?...?="),
// lost text inside nested multiparts and knew nothing about attachments. This binary uses `mig_mime.rs` — the same
// tested reader the Import-mail worker runs: exact charsets, nested multipart, encoded words, html->text, and the
// names/sizes of every attachment (sent as `attachments` metadata for E38; bytes are not stored here).
// The payload keys are exactly the ones the Bun twin sent, so `mail_ingest` sees no difference except better text.
//
// Built as a second binary of the anexomail-rust crate (src/bin/anexomail-deliver.rs); uses only crates the engine
// already has (tokio, reqwest+rustls, serde_json, sha2). Installer: docs/cursor-work/server/rust-deliver-install.sh.
// ============================================================================

#[path = "../mig_mime.rs"]
#[allow(dead_code)]
mod mig_mime;

// G38b: aane wali mail ke attachments ke bytes (spool -> Storage Box). Dono files crate ke src/ mein hain (attach module + yeh installer).
#[path = "../attach_core.rs"]
#[allow(dead_code)]
mod attach_core;
#[path = "../inbound_attach.rs"]
#[allow(dead_code)]
mod inbound_attach;

use serde_json::{json, Map, Value};
use sha2::{Digest, Sha256};
use std::io::Read;
use std::process::ExitCode;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const ENV_FILE_DEFAULT: &str = "/etc/anexomail/mail.env";
const EX_TEMPFAIL: u8 = 75;

/// KEY=value lines (quotes stripped) — same tolerant reader as the Bun twin; process env wins over nothing, file wins over env
/// only where the env is empty.
fn load_env(path: &str) -> Map<String, Value> {
    let mut out = Map::new();
    for (k, v) in std::env::vars() {
        out.insert(k, Value::String(v));
    }
    if let Ok(text) = std::fs::read_to_string(path) {
        for line in text.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            if let Some((k, v)) = line.split_once('=') {
                let k = k.trim();
                if k.is_empty() || !k.bytes().all(|b| b.is_ascii_uppercase() || b.is_ascii_digit() || b == b'_') {
                    continue;
                }
                let v = v.trim().trim_matches(|c| c == '"' || c == '\'').to_string();
                out.insert(k.to_string(), Value::String(v));
            }
        }
    }
    out
}

fn env_str(env: &Map<String, Value>, k: &str) -> String {
    env.get(k).and_then(|v| v.as_str()).unwrap_or("").to_string()
}

/// Lower-cased header name -> value; duplicates joined with ", " (exactly like the Bun `parseHeaders`).
fn header_map(raw: &[u8]) -> Map<String, Value> {
    let head_end = raw
        .windows(4)
        .position(|w| w == b"\r\n\r\n")
        .or_else(|| raw.windows(2).position(|w| w == b"\n\n"))
        .unwrap_or(raw.len());
    let mut m = Map::new();
    for (k, v) in mig_mime::parse_headers(&raw[..head_end]) {
        let k = k.to_ascii_lowercase();
        let merged = match m.get(&k).and_then(|x| x.as_str()) {
            Some(prev) => format!("{prev}, {v}"),
            None => v,
        };
        m.insert(k, Value::String(merged));
    }
    m
}

/// `spf=pass` / `dkim=fail` out of Authentication-Results (first match, lower-cased) — same as the Bun regex.
fn auth_result(ar: Option<&str>, kind: &str) -> Value {
    let Some(ar) = ar else { return Value::Null };
    let lower = ar.to_ascii_lowercase();
    let needle = format!("{kind}=");
    let mut from = 0;
    while let Some(i) = lower[from..].find(&needle) {
        let at = from + i;
        let boundary = at == 0 || !lower.as_bytes()[at - 1].is_ascii_alphanumeric();
        let word: String = lower[at + needle.len()..].chars().take_while(|c| c.is_ascii_lowercase()).collect();
        if boundary && !word.is_empty() {
            return Value::String(word);
        }
        from = at + needle.len();
    }
    Value::Null
}

fn iso_now() -> String {
    let secs = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0);
    mig_mime::iso_utc(secs)
}

/// The exact JSON `mail_ingest(payload)` receives. Pure (no I/O) so it is unit-tested below.
pub fn build_payload(raw: &[u8], envelope_from: &str, envelope_to: &str) -> Value {
    let p = mig_mime::parse(raw);
    let h = header_map(raw);
    let hs = |k: &str| h.get(k).and_then(|v| v.as_str()).map(|s| s.to_string());
    let from = p.from.clone().unwrap_or_default();
    let from_address = if from.address.is_empty() { "unknown".to_string() } else { from.address.clone() };
    let to: Vec<String> = if p.to.is_empty() { vec![envelope_to.to_string()] } else { p.to.clone() };
    let attachments: Vec<Value> = p
        .attachments
        .iter()
        .map(|a| json!({ "filename": a.filename, "mime": a.mime, "size": a.size }))
        .collect();
    let ar = hs("authentication-results");
    json!({
        "envelope_from": if envelope_from.is_empty() { from_address.clone() } else { envelope_from.to_string() },
        "envelope_to": envelope_to,
        "message_id": p.message_id,
        "in_reply_to": p.in_reply_to,
        "from_name": from.name,
        "from_address": from_address,
        "to": to,
        "cc": p.cc,
        "subject": p.subject,
        "body_text": p.text,
        "body_html": p.html,
        "spf": auth_result(ar.as_deref(), "spf"),
        "dkim": auth_result(ar.as_deref(), "dkim"),
        "sent_at": p.date.map(mig_mime::iso_utc).unwrap_or_else(iso_now),
        "raw_size": raw.len(),
        "raw_sha256": format!("{:x}", Sha256::digest(raw)),
        "attachments": attachments,
        "mime_lossy": p.lossy,
        "body_truncated": p.truncated,
        "parser": "rust-mig_mime",
        "headers": {
            "subject": hs("subject"),
            "from": hs("from"),
            "to": hs("to"),
            "message-id": hs("message-id"),
            "authentication-results": ar,
        },
    })
}

/// `anexomail-deliver --spool-run` (systemd timer, root): spool ki mails ke attachments Storage Box par (G38b). Exit 0 = theek ya kuch nahi;
/// 1 = kuch dobara koshish par chhoda (spool file wahin hai); 2 = Storage Box / env tayyar nahi (kuch nahi chhoota).
fn spool_run(env: &Map<String, Value>) -> ExitCode {
    let rt = match tokio::runtime::Builder::new_current_thread().enable_all().build() {
        Ok(rt) => rt,
        Err(e) => {
            eprintln!("inbound-attach: runtime: {e}");
            return ExitCode::from(2);
        }
    };
    match rt.block_on(inbound_attach::run_spool(env)) {
        Ok(t) => {
            println!("inbound-attach: processed={} failed={} left={} oldest_age_s={}", t.processed, t.failed, t.left, t.oldest_age_s);
            if t.failed > 0 { ExitCode::from(1) } else { ExitCode::SUCCESS }
        }
        Err(e) => {
            eprintln!("inbound-attach: {e}");
            ExitCode::from(2)
        }
    }
}

/// B4: tell the Rust event hub a mail landed so open browsers refresh in ~100 ms instead of waiting for the 2 s reconcile.
/// Best effort ONLY: no secret / hub down / slow => silently nothing (the reconcile still delivers it). Never delays or fails Postfix.
fn push_mail_event(rt: &tokio::runtime::Runtime, env: &Map<String, Value>, ingest_response: &str) {
    let secret = env_str(env, "EVENT_SECRET");
    if secret.len() < 24 {
        return;
    }
    let Some((_msg, org)) = inbound_attach::ingest_ids(ingest_response) else { return };
    let base = {
        let b = env_str(env, "EVENT_URL");
        if b.is_empty() { "http://127.0.0.1:3200".to_string() } else { b }
    };
    let _ = rt.block_on(async {
        let client = reqwest::Client::builder().timeout(Duration::from_millis(1500)).build().ok()?;
        client
            .post(format!("{}/internal/event", base.trim_end_matches('/')))
            .header("x-event-secret", secret)
            .json(&json!({ "org_id": org, "topic": "mail" }))
            .send()
            .await
            .ok()
    });
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    if args.get(1).map(|a| a.as_str()) == Some("--spool-run") {
        let env_file = std::env::var("ANEXOMAIL_MAIL_ENV").unwrap_or_else(|_| ENV_FILE_DEFAULT.to_string());
        return spool_run(&load_env(&env_file));
    }
    let envelope_from = args.get(1).map(|s| s.to_lowercase()).unwrap_or_default();
    let envelope_to = args.get(2).map(|s| s.to_lowercase()).unwrap_or_default();
    let env_file = std::env::var("ANEXOMAIL_MAIL_ENV").unwrap_or_else(|_| ENV_FILE_DEFAULT.to_string());
    let env = load_env(&env_file);
    let url = env_str(&env, "SUPABASE_URL");
    let key = env_str(&env, "SUPABASE_SERVICE_ROLE_KEY");
    if url.is_empty() || key.is_empty() {
        eprintln!("anexomail-deliver: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing in {env_file}");
        return ExitCode::from(EX_TEMPFAIL);
    }

    let mut raw = Vec::with_capacity(64 * 1024);
    if let Err(e) = std::io::stdin().lock().read_to_end(&mut raw) {
        eprintln!("anexomail-deliver: stdin read failed: {e}");
        return ExitCode::from(EX_TEMPFAIL);
    }
    let payload = build_payload(&raw, &envelope_from, &envelope_to);

    let rt = match tokio::runtime::Builder::new_current_thread().enable_all().build() {
        Ok(rt) => rt,
        Err(e) => {
            eprintln!("anexomail-deliver: runtime: {e}");
            return ExitCode::from(EX_TEMPFAIL);
        }
    };
    let endpoint = format!("{}/rest/v1/rpc/mail_ingest", url.trim_end_matches('/'));
    let result = rt.block_on(async {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(60))
            .connect_timeout(Duration::from_secs(10))
            .build()
            .map_err(|e| e.to_string())?;
        let res = client
            .post(&endpoint)
            .header("apikey", &key)
            .header("authorization", format!("Bearer {key}"))
            .header("content-type", "application/json")
            .json(&json!({ "payload": payload }))
            .send()
            .await
            .map_err(|e| format!("network error {e}"))?;
        let status = res.status();
        let body = res.text().await.unwrap_or_default();
        if status.is_success() { Ok(body) } else { Err(format!("supabase {} {}", status.as_u16(), body)) }
    });
    match result {
        Ok(out) => {
            eprintln!("anexomail-deliver: OK {envelope_to} {}", out.chars().take(300).collect::<String>());
            push_mail_event(&rt, &env, &out);
            // G38b: attachments ke bytes baad mein (mail DB mein hai); yahan kuch bhi ho, Postfix ko SUCCESS hi milta hai
            if let Some(note) = inbound_attach::maybe_spool(&raw, &out) {
                eprintln!("anexomail-deliver: {note}");
            }
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("anexomail-deliver: {}", e.chars().take(500).collect::<String>());
            ExitCode::from(EX_TEMPFAIL)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn crlf(s: &str) -> Vec<u8> {
        s.replace('\n', "\r\n").into_bytes()
    }

    #[test]
    fn payload_keys_match_the_bun_contract() {
        let raw = crlf("Return-Path: <a@x.com>\nDelivered-To: basic.test@anexomail.com\nFrom: \"Sara Khan\" <Sara@Acme.co.uk>\nTo: Basic.Test@anexomail.com\nSubject: =?UTF-8?B?U2FsYW0g8J+Riw==?=\nMessage-ID: <abc@acme.co.uk>\nIn-Reply-To: <prev@acme.co.uk>\nDate: Mon, 19 Oct 2026 04:10:00 +0500\nAuthentication-Results: mx.anexomail.com; spf=pass smtp.mailfrom=acme.co.uk; dkim=FAIL header.d=acme.co.uk\n\nHi there\n");
        let v = build_payload(&raw, "a@x.com", "basic.test@anexomail.com");
        for k in ["envelope_from", "envelope_to", "message_id", "in_reply_to", "from_name", "from_address", "to", "cc", "subject",
                  "body_text", "body_html", "spf", "dkim", "sent_at", "raw_size", "raw_sha256", "headers"] {
            assert!(v.get(k).is_some(), "missing key {k}");
        }
        assert_eq!(v["subject"], "Salam 👋"); // Bun stored "=?UTF-8?B?...?=" raw
        assert_eq!(v["from_address"], "sara@acme.co.uk");
        assert_eq!(v["from_name"], "Sara Khan");
        assert_eq!(v["to"], json!(["basic.test@anexomail.com"]));
        assert_eq!(v["message_id"], "abc@acme.co.uk");
        assert_eq!(v["in_reply_to"], "prev@acme.co.uk");
        assert_eq!(v["spf"], "pass");
        assert_eq!(v["dkim"], "fail");
        assert_eq!(v["sent_at"], "2026-10-18T23:10:00Z");
        assert_eq!(v["raw_size"], raw.len());
        assert_eq!(v["raw_sha256"].as_str().unwrap().len(), 64);
        assert_eq!(v["headers"]["subject"], "=?UTF-8?B?U2FsYW0g8J+Riw==?=");
        assert!(v["body_text"].as_str().unwrap().starts_with("Hi there"));
        assert_eq!(v["body_html"], Value::Null);
    }

    #[test]
    fn no_to_header_falls_back_to_envelope_and_unknown_sender() {
        let raw = crlf("Subject: x\n\nbody");
        let v = build_payload(&raw, "", "info@acme.co.uk");
        assert_eq!(v["to"], json!(["info@acme.co.uk"]));
        assert_eq!(v["from_address"], "unknown");
        assert_eq!(v["envelope_from"], "unknown");
        assert_eq!(v["message_id"], Value::Null);
        assert_eq!(v["spf"], Value::Null);
    }

    #[test]
    fn nested_multipart_text_and_attachment_metadata() {
        let raw = crlf("From: a@x.com\nTo: b@anexomail.com\nSubject: Quote\nContent-Type: multipart/mixed; boundary=\"M\"\n\n--M\nContent-Type: multipart/alternative; boundary=A\n\n--A\nContent-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: quoted-printable\n\nPrice =E2=82=AC10\n--A\nContent-Type: text/html; charset=utf-8\n\n<p>Price <b>&euro;10</b></p>\n--A--\n\n--M\nContent-Type: application/pdf; name=\"q.pdf\"\nContent-Disposition: attachment; filename=\"q.pdf\"\nContent-Transfer-Encoding: base64\n\nJVBERi0xLjQK\n\n--M--\n");
        let v = build_payload(&raw, "a@x.com", "b@anexomail.com");
        assert!(v["body_text"].as_str().unwrap().contains("Price €10"));
        assert!(v["body_html"].as_str().unwrap().contains("<b>"));
        assert_eq!(v["attachments"][0]["filename"], "q.pdf");
        assert_eq!(v["attachments"][0]["mime"], "application/pdf");
    }

    #[test]
    fn duplicate_headers_join_like_bun() {
        let raw = crlf("Authentication-Results: a; spf=none\nAuthentication-Results: b; dkim=pass\nSubject: s\n\nx");
        let v = build_payload(&raw, "a@x", "b@y");
        assert_eq!(v["headers"]["authentication-results"], "a; spf=none, b; dkim=pass");
        assert_eq!(v["spf"], "none");
        assert_eq!(v["dkim"], "pass");
    }

    #[test]
    fn env_file_parsing() {
        let p = std::env::temp_dir().join(format!("ax-env-{}", std::process::id()));
        std::fs::write(&p, "# c\nSUPABASE_URL=\"https://x.supabase.co\"\nSUPABASE_SERVICE_ROLE_KEY='k'\nlower=no\n").unwrap();
        let e = load_env(p.to_str().unwrap());
        assert_eq!(env_str(&e, "SUPABASE_URL"), "https://x.supabase.co");
        assert_eq!(env_str(&e, "SUPABASE_SERVICE_ROLE_KEY"), "k");
        assert!(e.get("lower").is_none());
        let _ = std::fs::remove_file(p);
    }
}
