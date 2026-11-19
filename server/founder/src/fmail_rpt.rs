//! QC1cF8-3 (TLS-RPT, RFC 8460) + F8-4 (strict "send only if TLS" policy). Rust Tokio, SQL E191.
//! (1) `Attempt`: what run_domain saw on each MX host (TLS ok, or one of the RFC failure types) -> `record` counts it per UTC day (domain + host sealed, AES-256-GCM, vault-wrapped key).
//! (2) `daily_worker`: every 10 minutes, for every mailbox, the (day, domain) pairs whose day has ended are claimed ONE AT A TIME (SQL: exactly once), the report JSON is built (build_tls_rpt_report),
//!     gzip-ed, put into a multipart/report mail (RFC 8460 s5.3) and queued through the NORMAL outbox of the mailbox: DKIM signing, the strict TLS sender, MTA-STS, DANE and the relay all apply. https rua = POST.
//! (3) `strict_for`: the sender asks E191 whether the founder's rule "no clear text" is loosened right now; ANY doubt (database silent, bad answer) = strict.
//! Never in a report: an address, a subject, any mail content. Only the policy domain, MX host names, IPs and counts. A report mail is never counted itself (no loop).
use crate::{data, fmail_core as core, fmail_mime as mime, fmail_qtls as qtls, fmail_seal as seal, fmail_smtp as smtp, fmail_tls as tls, lease};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use serde_json::{json, Value};
use std::io::Write;
use std::time::Duration;

const AAD_TAG: &str = "fmail-rpt-v1";
/// The 11 result types of RFC 8460 section 4.3 (the same closed list as the SQL check).
pub const RESULT_TYPES: [&str; 11] = ["starttls-not-supported", "certificate-host-mismatch", "certificate-expired", "certificate-not-trusted", "validation-failure", "tlsa-invalid", "dnssec-invalid", "dane-required",
    "sts-policy-fetch-error", "sts-policy-invalid", "sts-webpki-invalid"];
const MAX_REPORT_BYTES: usize = 1_000_000;   // a report is never bigger than 1 MB (RFC 8460 leaves it to the receiver; Google accepts far less than 10 MB)
const MAX_RUA: usize = 2;                    // at most 2 targets per report (loophole: a TXT record listing 50 addresses must not make us a spam relay)

/// One TLS session attempt to one MX host, as seen by the sender.
#[derive(Debug, Clone, PartialEq)]
pub struct Attempt { pub host: String, pub ip: String, pub policy: &'static str, pub result: &'static str, pub reason: String }

/// Policy type of an attempt: DANE-proven TLSA records -> "tlsa", an MTA-STS policy (enforce or testing) -> "sts", else "no-policy-found". DANE wins (RFC 8461 section 2).
pub fn policy_type(dane: bool, sts: Option<&qtls::StsPolicy>) -> &'static str {
    if dane { "tlsa" } else if sts.map_or(false, |p| p.mode != qtls::StsMode::None) { "sts" } else { "no-policy-found" }
}
/// A session failure as an RFC 8460 result type. None = it is not a TLS or policy matter (the TCP connection failed, the server said 4xx/5xx to a recipient): RFC 8460 does not count those.
pub fn result_type(f: &smtp::Fail, policy: &str) -> Option<&'static str> {
    let t = f.text().to_ascii_lowercase();
    if t.contains("does not offer starttls") { return Some("starttls-not-supported"); }
    if !(t.contains("tls handshake") || t.contains("certificate") || t.contains("tlsa") || t.contains("dane")) { return None; }
    Some(if t.contains("notvalidforname") || t.contains("not valid for name") || t.contains("name mismatch") || t.contains("hostname mismatch") { "certificate-host-mismatch" }
         else if t.contains("expired") { "certificate-expired" }
         else if t.contains("unknownissuer") || t.contains("unknown issuer") || t.contains("not trusted") || t.contains("untrusted") || t.contains("selfsigned") || t.contains("self-signed") { "certificate-not-trusted" }
         else if policy == "tlsa" { if t.contains("dnssec") { "dnssec-invalid" } else { "tlsa-invalid" } }
         else { "validation-failure" })
}
/// A reason code that is safe to put into a report: short, printable, no address-like text.
pub fn reason_code(s: &str) -> String { s.chars().filter(|c| c.is_ascii_graphic() || *c == ' ').filter(|c| *c != '@' && *c != '<' && *c != '>').take(80).collect::<String>().trim().to_string() }

fn bx(b: &[u8]) -> String { format!("\\x{}", hex::encode(b)) }
fn aad_of(mailbox: &str, dom_hex: &str, host_hex: &str, policy: &str, result: &str) -> Vec<u8> { seal::aad(&[AAD_TAG, mailbox, dom_hex, host_hex, policy, result]) }

/// Count one attempt (best effort: a failing database never costs the mail). `domain` is the recipient domain.
pub async fn record(sb: &data::Sb, master: &seal::Key, actor: &str, mailbox: &str, key_id: &str, domain: &str, a: &Attempt) {
    let Some(d) = tls::domain_only(domain) else { return };
    let Ok(bk) = seal::blind_key(master, mailbox) else { return };
    let dom_blind = seal::blind(&bk, "tlsdomain", &d); let host = a.host.trim_end_matches('.').to_ascii_lowercase();
    let host_blind = seal::blind(&bk, "rptmx", &host);
    if !RESULT_TYPES.contains(&a.result) && a.result != "success" { return; }
    let aad = aad_of(mailbox, &hex::encode(dom_blind), &hex::encode(host_blind), a.policy, a.result);
    let plain = json!({"d": d, "h": host, "ip": a.ip, "r": reason_code(&a.reason)}).to_string();
    let Ok(key) = seal::new_key() else { return };
    let Ok((nonce, sealed)) = seal::seal(&key, &aad, plain.as_bytes()) else { return };
    let Ok(wrap) = seal::wrap_vault(master, key_id, &key) else { return };
    let r = sb.rpc_msg("fmail_rpt_count_door191", json!({"p_actor": actor, "p_mailbox": mailbox, "p_blind": bx(&dom_blind), "p_policy": a.policy, "p_result": a.result, "p_host_blind": bx(&host_blind),
        "p_sealed": bx(&sealed), "p_nonce": bx(&nonce), "p_key_id": key_id, "p_key_wrap": bx(&wrap), "p_aad": bx(&seal::aad_hash(&aad)), "p_n": 1})).await;
    if let Err((_, m)) = r { eprintln!("founder: tls-rpt count not written: {}", m.chars().take(120).collect::<String>()); }
}

/// F8-4: is "send only if TLS" strict right now? Strict unless E191 positively says it was loosened by a passkey grant and the time has not run out. Any doubt = strict.
pub async fn strict_for(sb: &data::Sb, actor: &str, mailbox: &str) -> bool {
    match sb.rpc("fmail_tls_policy_get191", json!({"p_actor": actor, "p_mailbox": mailbox})).await {
        Some(v) if v["ok"] == json!(true) && v["strict"] == json!(false) => false,
        _ => true,
    }
}
/// The require_tls flag for one hop. An enforcing MTA-STS policy or DANE-proven TLSA always means TLS, whatever the founder's own rule says.
pub fn hop_requires_tls(strict: bool, sts: Option<&qtls::StsPolicy>, dane: bool) -> bool { strict || dane || sts.map_or(false, |p| p.mode == qtls::StsMode::Enforce) }

// ---------------------------------------------------------------- the report
/// One counter row opened from the claim answer.
#[derive(Debug, Clone, PartialEq)]
pub struct Counter { pub policy: String, pub result: String, pub host: String, pub ip: String, pub reason: String, pub cnt: u64 }

/// Open the sealed counters of a claim. A row that does not open (wrong AAD, wrong key) is dropped, never guessed. Returns (domain, counters). All rows must name the same domain.
pub fn open_counters(master: &seal::Key, mailbox: &str, dom_hex: &str, rows: &Value) -> Option<(String, Vec<Counter>)> {
    let mut out = Vec::new(); let mut domain: Option<String> = None;
    for r in rows.as_array()? {
        let hx = |k: &str| r.get(k).and_then(|v| v.as_str()).and_then(|s| hex::decode(s).ok());
        let (Some(sealed), Some(nonce), Some(wrap), Some(aadh)) = (hx("sealed"), hx("nonce"), hx("key_wrap"), hx("aad_hash")) else { continue };
        let (policy, result, host_hex) = (r["policy_type"].as_str()?, r["result_type"].as_str()?, r["host_blind"].as_str()?);
        let aad = aad_of(mailbox, dom_hex, host_hex, policy, result);
        if seal::aad_hash(&aad).as_slice() != aadh.as_slice() { continue; }
        let Some(key) = seal::unwrap_vault(master, r["key_id"].as_str()?, &wrap) else { continue };
        let Some(pt) = seal::open(&key, &nonce, &aad, &sealed) else { continue };
        let Ok(v) = serde_json::from_slice::<Value>(&pt) else { continue };
        let d = v["d"].as_str()?.to_string();
        if domain.as_deref().map_or(false, |x| x != d) { return None; }
        domain = Some(d);
        out.push(Counter { policy: policy.to_string(), result: result.to_string(), host: v["h"].as_str().unwrap_or("").to_string(), ip: v["ip"].as_str().unwrap_or("").to_string(), reason: v["r"].as_str().unwrap_or("").to_string(), cnt: r["cnt"].as_u64().unwrap_or(0) });
    }
    Some((domain?, out)).filter(|(_, c)| !c.is_empty())
}
/// RFC 8460 report JSON for one UTC day: one policy block per policy type. Totals count sessions; failure-details list the failure rows. Never an address.
pub fn build_report(org: &str, contact: &str, report_id: &str, day: &str, domain: &str, counters: &[Counter]) -> Value {
    let (start, end) = (format!("{day}T00:00:00Z"), format!("{day}T23:59:59Z"));
    let mut types: Vec<&str> = counters.iter().map(|c| c.policy.as_str()).collect(); types.sort(); types.dedup();
    let mut report = Value::Null;
    for pt in types {
        let rows: Vec<&Counter> = counters.iter().filter(|c| c.policy == pt).collect();
        let ok: u64 = rows.iter().filter(|c| c.result == "success").map(|c| c.cnt).sum();
        let failed: u64 = rows.iter().filter(|c| c.result != "success").map(|c| c.cnt).sum();
        let fails: Vec<qtls::RptFailure> = rows.iter().filter(|c| c.result != "success").filter_map(|c| RESULT_TYPES.iter().find(|t| **t == c.result).map(|t| qtls::RptFailure {
            result_type: t, sending_mx_ip: String::new(), receiving_mx_host: c.host.clone(), count: c.cnt, reason: c.reason.clone() })).collect();
        let one = qtls::build_tls_rpt_report(org, contact, report_id, &start, &end, domain, pt, ok, failed, &fails);
        if report.is_null() { report = one; } else if let (Some(a), Some(b)) = (report["policies"].as_array_mut(), one["policies"].as_array()) { a.extend(b.iter().cloned()); }
    }
    report
}
pub fn gzip(json: &Value) -> Result<Vec<u8>, &'static str> {
    let raw = serde_json::to_vec(json).map_err(|_| "report does not serialise")?;
    let mut e = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::best());
    e.write_all(&raw).map_err(|_| "gzip failed")?; let gz = e.finish().map_err(|_| "gzip failed")?;
    if gz.len() > MAX_REPORT_BYTES { return Err("the report is too big"); }
    Ok(gz)
}
/// The mail of RFC 8460 section 5.3: multipart/report (report-type tlsrpt), a short human part, and the gzip part. Headers TLS-Report-Domain and TLS-Report-Submitter name the report.
pub fn report_mail(from: &str, to: &str, submitter: &str, domain: &str, report_id: &str, day: &str, message_id: &str, unix: u64, gz: &[u8], boundary: &str) -> Result<Vec<u8>, &'static str> {
    let ok_name = |s: &str| !s.is_empty() && s.len() <= 255 && s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'-');
    if !ok_name(submitter) || !ok_name(domain) || !report_id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') || report_id.is_empty() || !boundary.bytes().all(|b| b.is_ascii_alphanumeric()) { return Err("bad report names"); }
    if mime::norm_addr(from).as_deref() != Some(from) || mime::norm_addr(to).as_deref() != Some(to) { return Err("bad report address"); }
    let file = format!("{submitter}!{domain}!{day}!{report_id}.json.gz");
    let mut h = String::new();
    h.push_str(&format!("From: {from}\r\nTo: {to}\r\nSubject: Report Domain: {domain} Submitter: {submitter} Report-ID: <{report_id}>\r\nTLS-Report-Domain: {domain}\r\nTLS-Report-Submitter: {submitter}\r\n"));
    h.push_str(&format!("Date: {}\r\nMessage-ID: <{message_id}>\r\nMIME-Version: 1.0\r\nAuto-Submitted: auto-generated\r\nContent-Type: multipart/report; report-type=\"tlsrpt\"; boundary=\"{boundary}\"\r\n\r\n", mime::rfc2822(unix)));
    h.push_str(&format!("--{boundary}\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\nThis is an SMTP TLS aggregate report (RFC 8460) for {domain}, UTC day {day}. It holds counts and host names only.\r\n\r\n"));
    h.push_str(&format!("--{boundary}\r\nContent-Type: application/tlsrpt+gzip\r\nContent-Transfer-Encoding: base64\r\nContent-Disposition: attachment; filename=\"{file}\"\r\n\r\n"));
    let enc = B64.encode(gz);
    for c in enc.as_bytes().chunks(76) { h.push_str(std::str::from_utf8(c).unwrap_or("")); h.push_str("\r\n"); }
    h.push_str(&format!("--{boundary}--\r\n"));
    Ok(h.into_bytes())
}
/// A mail that carries the RFC 8460 header TLS-Report-Domain is a report itself: its own delivery is never counted (no loop). Only the header block is searched.
pub fn is_report_mail(raw: &[u8]) -> bool {
    let end = raw.windows(4).position(|w| w == b"\r\n\r\n").unwrap_or(raw.len().min(8192)); let head = &raw[..end.min(raw.len())];
    head.split(|b| *b == b'\n').any(|l| l.len() >= 18 && l[..18].eq_ignore_ascii_case(b"TLS-Report-Domain:"))
}
/// Report targets of the rua list: mailto (a valid address) and https (an absolute https URL with a host NAME on port 443, no credentials). At most MAX_RUA. Anything else is dropped.
pub fn rua_targets(rua: &[String]) -> Vec<(bool, String)> {
    let mut out = Vec::new();
    for r in rua {
        if out.len() >= MAX_RUA { break; }
        if let Some(a) = r.strip_prefix("mailto:") { let a = a.split('?').next().unwrap_or(""); if let Some(n) = mime::norm_addr(a) { out.push((false, n)); } }
        else if let Some(u) = r.strip_prefix("https://") {
            let host = u.split(['/', '?', '#']).next().unwrap_or("");
            if host.is_empty() || host.contains('@') || host.contains(':') || host.contains('[') || host.parse::<std::net::IpAddr>().is_ok() || !host.contains('.') { continue; }
            if host.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'-') { out.push((true, r.clone())); }
        }
    }
    out
}

// ---------------------------------------------------------------- the worker
async fn txt_rua(domain: &str) -> Vec<String> {
    let Some(res) = crate::fmail_out::probe_resolver() else { return Vec::new() };
    let Ok(Ok(t)) = tokio::time::timeout(Duration::from_secs(10), res.txt_lookup(format!("_smtp._tls.{domain}."))).await else { return Vec::new() };
    for r in t.iter() {
        let s: String = r.txt_data().iter().map(|b| String::from_utf8_lossy(b).to_string()).collect();
        let v = qtls::rpt_rua(&s); if !v.is_empty() { return v; }
    }
    Vec::new()
}
/// https rua: POST of the gzip with the RFC type. The host must resolve ONLY to public addresses (SSRF guard), the connection is pinned to the vetted address, TLS only, 10 s.
async fn post_https(url: &str, gz: &[u8]) -> Result<(), String> {
    let host = url.trim_start_matches("https://").split(['/', '?', '#']).next().unwrap_or("").to_string();
    let res = crate::fmail_out::probe_resolver().ok_or("no resolver")?;
    let ips: Vec<std::net::IpAddr> = tokio::time::timeout(Duration::from_secs(10), res.lookup_ip(format!("{host}."))).await.map_err(|_| "dns timed out")?.map_err(|e| format!("dns: {e}"))?.iter().collect();
    if ips.is_empty() || !ips.iter().all(smtp::is_public) { return Err("the report address is not a public host".into()); }
    let c = reqwest::Client::builder().https_only(true).timeout(Duration::from_secs(10)).redirect(reqwest::redirect::Policy::none()).resolve(&host, std::net::SocketAddr::new(ips[0], 443)).build().map_err(|e| e.to_string())?;
    let r = c.post(url).header("content-type", "application/tlsrpt+gzip").body(gz.to_vec()).send().await.map_err(|e| format!("post: {e}"))?;
    if r.status().is_success() { Ok(()) } else { Err(format!("the receiver answered {}", r.status().as_u16())) }
}
fn now_s() -> u64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0) }

/// One (day, domain) report: claim, build, send, finish. Returns the state written. Errors become a `failed` finish (retried later), never a lost claim.
async fn one_report(sb: &data::Sb, master: &seal::Key, actor: &str, mb: &Value, day: &str, dom_hex: &str) -> Option<String> {
    let mailbox = mb["id"].as_str()?; let address = mb["address"].as_str()?; let key_id = mb["vault_key_id"].as_str().filter(|s| !s.is_empty()).unwrap_or("vault-1");
    let claim = sb.rpc("fmail_rpt_claim191", json!({"p_actor": actor, "p_mailbox": mailbox, "p_day": day, "p_blind": format!("\\x{dom_hex}")})).await?;
    if claim["go"] != json!(true) { return None; }
    let finish = |state: &'static str, via: Option<&'static str>, bytes: Option<usize>, ok: Option<u64>, fail: Option<u64>, why: String| {
        let (sb, actor, mailbox, day, dom_hex) = (sb.clone(), actor.to_string(), mailbox.to_string(), day.to_string(), dom_hex.to_string());
        async move {
            let r = sb.rpc_msg("fmail_rpt_finish191", json!({"p_actor": actor, "p_mailbox": mailbox, "p_day": day, "p_blind": format!("\\x{dom_hex}"), "p_state": state, "p_via": via, "p_bytes": bytes, "p_ok": ok, "p_fail": fail, "p_reason": why})).await;
            if let Err((_, m)) = r { eprintln!("founder: tls-rpt finish not written: {}", m.chars().take(120).collect::<String>()); }
            state.to_string()
        }
    };
    let Some((domain, counters)) = open_counters(master, mailbox, dom_hex, &claim["counters"]) else { return Some(finish("failed", None, None, None, None, "the counters did not open".into()).await) };
    let rid = claim["report_id"].as_str().unwrap_or("").to_string();
    let submitter = mime::domain_of(address).to_string();
    let report = build_report(&submitter, address, &rid, day, &domain, &counters);
    let (ok, fail): (u64, u64) = (counters.iter().filter(|c| c.result == "success").map(|c| c.cnt).sum(), counters.iter().filter(|c| c.result != "success").map(|c| c.cnt).sum());
    let gz = match gzip(&report) { Ok(g) => g, Err(e) => return Some(finish("failed", None, None, None, None, e.into()).await) };
    let targets = rua_targets(&txt_rua(&domain).await);
    let Some((is_https, target)) = targets.into_iter().next() else { return Some(finish("no_rua", None, None, None, None, "the domain publishes no usable _smtp._tls rua".into()).await) };
    if is_https {
        return Some(match post_https(&target, &gz).await { Ok(()) => finish("sent", Some("https"), Some(gz.len()), Some(ok), Some(fail), String::new()).await, Err(e) => finish("failed", None, None, None, None, e).await });
    }
    // mailto: queue it through the mailbox's own outbox (DKIM + strict TLS + MTA-STS + DANE + relay all apply). The sender never counts a mail that carries the TLS-Report-Domain header (no loop).
    let (Ok(mid), Ok(bnd)) = (mime::new_message_id(&submitter), mime::new_message_id("b")) else { return Some(finish("failed", None, None, None, None, "no random".into()).await) };
    let boundary: String = bnd.chars().filter(|c| c.is_ascii_alphanumeric()).collect();
    let raw = match report_mail(address, &target, &submitter, &domain, &rid, day, &mid, now_s(), &gz, &boundary) { Ok(r) => r, Err(e) => return Some(finish("failed", None, None, None, None, e.into()).await) };
    let sum = core::summarize(&raw);
    let sealed = match core::seal_message(master, mailbox, "out", core::Wrap::Vault { master, key_id }, &raw, &sum) { Ok(s) => s, Err(e) => return Some(finish("failed", None, None, None, None, e.into()).await) };
    let Ok(bk) = seal::blind_key(master, mailbox) else { return Some(finish("failed", None, None, None, None, "no blind key".into()).await) };
    let rcpt_hex = vec![hex::encode(seal::blind(&bk, "rcpt", &target))];
    let q = sb.rpc_msg("fmail_compose_send170", json!({
        "p_actor": actor, "p_mailbox": mailbox, "p_sealed_body": bx(&sealed.sealed_body), "p_sealed_meta": bx(&sealed.sealed_meta), "p_nonce_body": bx(&sealed.nonce_body), "p_nonce_meta": bx(&sealed.nonce_meta),
        "p_key_id": sealed.key_id, "p_key_wrap": bx(&sealed.key_wrap), "p_aad_hash": bx(&sealed.aad_hash), "p_msgid_blind": bx(&sealed.msgid_blind), "p_parent_blind": Value::Null,
        "p_subject_blind": bx(&sealed.subject_blind), "p_size": raw.len() as i64, "p_attach": 0, "p_rcpt_hex": rcpt_hex, "p_schedule_at": Value::Null, "p_touch_hash": Value::Null, "p_draft": Value::Null })).await;
    match q {
        Ok(_) => { crate::fmail_out::wake(); Some(finish("sent", Some("mailto"), Some(gz.len()), Some(ok), Some(fail), String::new()).await) }
        Err((_, m)) => Some(finish("failed", None, None, None, None, format!("queue: {m}")).await),
    }
}
/// Every 10 minutes: every active vault mailbox, its due (day, domain) pairs, one report at a time (a slow receiver never blocks the others for long: 4 per mailbox per round).
pub async fn daily_worker(sb: data::Sb) {
    eprintln!("founder: TLS-RPT daily report worker ON (after the UTC day ends, 4 per mailbox per round)");
    loop {
        tokio::time::sleep(Duration::from_secs(600)).await;
        let Some(master) = lease::MASTER.get() else { continue };
        let Some(boxes) = sb.rows("fmail_mailboxes?select=id,owner,address,vault_key_id&status=eq.active&seal_mode=eq.vault").await else { continue };
        for mb in boxes {
            let (Some(id), Some(actor)) = (mb["id"].as_str(), mb["owner"].as_str()) else { continue };
            let Some(due) = sb.rpc("fmail_rpt_due191", json!({"p_actor": actor, "p_mailbox": id, "p_limit": 4})).await else { continue };
            for d in due["due"].as_array().map(|a| a.as_slice()).unwrap_or(&[]) {
                let (Some(day), Some(dom)) = (d["day"].as_str(), d["domain_blind"].as_str()) else { continue };
                if let Some(state) = one_report(&sb, master, actor, &mb, day, dom).await { eprintln!("founder: tls-rpt {day}: {state}"); }
            }
            let _ = sb.rpc("fmail_rpt_clean_door191", json!({"p_actor": actor, "p_mailbox": id})).await;
            let _ = sb.rpc("fmail_tls_policy_tighten191", json!({"p_actor": actor, "p_mailbox": id})).await;   // an expired loosening is cleaned and noted in the chain
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn sts(mode: qtls::StsMode) -> qtls::StsPolicy { qtls::StsPolicy { mode, mx: vec!["mx.example.com".into()], max_age: 86400 } }
    #[test]
    fn policy_and_result_types() {
        assert_eq!(policy_type(true, Some(&sts(qtls::StsMode::Enforce))), "tlsa");
        assert_eq!(policy_type(false, Some(&sts(qtls::StsMode::Testing))), "sts");
        assert_eq!(policy_type(false, Some(&sts(qtls::StsMode::None))), "no-policy-found");
        assert_eq!(policy_type(false, None), "no-policy-found");
        let t = |s: &str, p: &str| result_type(&smtp::Fail::Temp(s.into()), p);
        assert_eq!(t("mx.a.com does not offer STARTTLS; the mail is not sent in the clear and will be retried", "sts"), Some("starttls-not-supported"));
        assert_eq!(t("TLS handshake with mx.a.com failed: invalid peer certificate: UnknownIssuer", "no-policy-found"), Some("certificate-not-trusted"));
        assert_eq!(t("TLS handshake with mx.a.com failed: invalid peer certificate: NotValidForName", "sts"), Some("certificate-host-mismatch"));
        assert_eq!(t("TLS handshake with mx.a.com failed: invalid peer certificate: Expired", "sts"), Some("certificate-expired"));
        assert_eq!(t("TLS handshake with mx.a.com failed: peer is incompatible", "tlsa"), Some("tlsa-invalid"));
        assert_eq!(t("TLS handshake with mx.a.com failed: handshake eof", "no-policy-found"), Some("validation-failure"));
        assert_eq!(t("connect to 1.2.3.4:25 timed out", "sts"), None, "a TCP failure is not a TLS report matter");
        assert_eq!(result_type(&smtp::Fail::Perm("550 no such user".into()), "sts"), None);
    }
    #[test]
    fn hop_rule_never_downgrades_a_policy() {
        assert!(hop_requires_tls(true, None, false), "strict by default");
        assert!(!hop_requires_tls(false, None, false), "loosened and no policy: opportunistic");
        assert!(hop_requires_tls(false, Some(&sts(qtls::StsMode::Enforce)), false), "MTA-STS enforce stays TLS-only while loosened");
        assert!(hop_requires_tls(false, None, true), "DANE stays TLS-only while loosened");
        assert!(!hop_requires_tls(false, Some(&sts(qtls::StsMode::Testing)), false), "testing mode never forces");
    }
    #[test]
    fn reason_is_clean() {
        assert_eq!(reason_code("TLS failed for bob@example.com <x>\n"), "TLS failed for bobexample.com x");
        assert!(reason_code(&"a".repeat(500)).len() <= 80);
    }
    #[test]
    fn report_has_both_policies_and_no_address() {
        let c = |p: &str, r: &str, n: u64| Counter { policy: p.into(), result: r.into(), host: "mx.example.com".into(), ip: "192.0.2.1".into(), reason: "x".into(), cnt: n };
        let v = build_report("anexomail.com", "tls@anexomail.com", "rid-1", "2026-11-18", "example.com", &[c("sts", "success", 7), c("sts", "certificate-expired", 2), c("tlsa", "success", 1)]);
        assert_eq!(v["policies"].as_array().unwrap().len(), 2);
        let sts_p = v["policies"].as_array().unwrap().iter().find(|p| p["policy"]["policy-type"] == "sts").unwrap();
        assert_eq!(sts_p["summary"]["total-successful-session-count"], 7); assert_eq!(sts_p["summary"]["total-failure-session-count"], 2);
        assert_eq!(v["date-range"]["start-datetime"], "2026-11-18T00:00:00Z"); assert_eq!(v["date-range"]["end-datetime"], "2026-11-18T23:59:59Z");
        assert!(!v.to_string().contains('@') || v.to_string().matches('@').count() == 0 || v["contact-info"] == "tls@anexomail.com");
    }
    #[test]
    fn gzip_roundtrip_and_mail_shape() {
        use std::io::Read;
        let v = json!({"report-id": "r"}); let gz = gzip(&v).unwrap();
        let mut s = String::new(); flate2::read::GzDecoder::new(&gz[..]).read_to_string(&mut s).unwrap(); assert_eq!(serde_json::from_str::<Value>(&s).unwrap(), v);
        let m = report_mail("mail@anexomail.com", "tls@example.com", "anexomail.com", "example.com", "rid-1", "2026-11-18", "abc@anexomail.com", 1_794_000_000, &gz, "BND123").unwrap();
        let t = String::from_utf8(m).unwrap();
        assert!(t.contains("Subject: Report Domain: example.com Submitter: anexomail.com Report-ID: <rid-1>"));
        assert!(t.contains("TLS-Report-Domain: example.com") && t.contains("report-type=\"tlsrpt\"") && t.contains("application/tlsrpt+gzip"));
        assert!(t.contains("filename=\"anexomail.com!example.com!2026-11-18!rid-1.json.gz\"") && t.ends_with("--BND123--\r\n"));
        assert!(report_mail("mail@anexomail.com", "tls@example.com", "bad host", "example.com", "r", "d", "m", 1, &gz, "B").is_err());
        assert!(report_mail("mail@anexomail.com", "not an address", "a.com", "example.com", "r", "d", "m", 1, &gz, "B").is_err());
        assert_eq!(mime::envelope(&report_mail("mail@anexomail.com", "tls@example.com", "anexomail.com", "example.com", "rid-1", "2026-11-18", "abc@anexomail.com", 1, &gz, "BND").unwrap()).unwrap().1, vec!["tls@example.com".to_string()]);
    }
    #[test]
    fn a_report_is_recognised_and_a_body_line_is_not() {
        let gz = gzip(&json!({"a": 1})).unwrap();
        let m = report_mail("mail@anexomail.com", "tls@example.com", "anexomail.com", "example.com", "rid-1", "2026-11-18", "abc@anexomail.com", 1, &gz, "BND").unwrap();
        assert!(is_report_mail(&m));
        assert!(!is_report_mail(b"From: a@b.com\r\nSubject: hi\r\n\r\nTLS-Report-Domain: x.com\r\n"), "a body line does not make a report");
        assert!(!is_report_mail(b"From: a@b.com\r\nSubject: hi\r\n\r\nhello"));
    }
    #[test]
    fn rua_targets_are_filtered() {
        let l = |v: &[&str]| rua_targets(&v.iter().map(|s| s.to_string()).collect::<Vec<_>>());
        assert_eq!(l(&["mailto:tls@example.com"]), vec![(false, "tls@example.com".to_string())]);
        assert_eq!(l(&["https://r.example.com/x"]).len(), 1);
        assert!(l(&["https://127.0.0.1/x", "https://user@evil.com/x", "https://evil.com:8080/x", "https://[::1]/x", "https://localhost/x", "ftp://x.com", "mailto:not an address"]).is_empty());
        assert_eq!(l(&["mailto:a@x.com", "mailto:b@x.com", "mailto:c@x.com"]).len(), 2, "at most 2 targets");
    }
    #[test]
    fn counters_open_only_with_the_right_aad() {
        let master = [7u8; 32]; let (mb, dom, host) = ("11111111-1111-1111-1111-111111111111", "ab".repeat(32), "cd".repeat(32));
        let aad = aad_of(mb, &dom, &host, "sts", "success"); let key = seal::new_key().unwrap();
        let (nonce, sealed) = seal::seal(&key, &aad, json!({"d": "example.com", "h": "mx.example.com", "ip": "192.0.2.1", "r": ""}).to_string().as_bytes()).unwrap();
        let wrap = seal::wrap_vault(&master, "vault-1", &key).unwrap();
        let row = json!({"policy_type": "sts", "result_type": "success", "host_blind": host, "cnt": 3, "sealed": hex::encode(&sealed), "nonce": hex::encode(nonce), "key_id": "vault-1", "key_wrap": hex::encode(&wrap), "aad_hash": hex::encode(seal::aad_hash(&aad))});
        let (d, c) = open_counters(&master, mb, &dom, &json!([row.clone()])).unwrap();
        assert_eq!(d, "example.com"); assert_eq!(c[0].cnt, 3); assert_eq!(c[0].host, "mx.example.com");
        assert!(open_counters(&master, "22222222-2222-2222-2222-222222222222", &dom, &json!([row.clone()])).is_none(), "another mailbox can not open it");
        assert!(open_counters(&[8u8; 32], mb, &dom, &json!([row])).is_none(), "another vault key can not open it");
    }
}
