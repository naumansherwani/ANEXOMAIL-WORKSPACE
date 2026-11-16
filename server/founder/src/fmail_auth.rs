//! Q1b4 (founder mailbox, 17 Nov 2026): THE VERDICT OF EVERY INBOUND MAIL. SPF + DKIM + DMARC (RFC 9989 tree walk) + ARC + iprev + TLS, checked in Rust the moment a mail arrives, handed to SQL E183
//! (`fmail_auth_record183`) which stores the evidence in a hash chain and computes the trust score.
//! Rules this file keeps:
//!   * OBSERVE MODE: nothing here blocks or deletes a mail. A failing mail still lands in the inbox with a red ring. Any trouble (DNS down, no client address) is recorded honestly as "none"/"temperror",
//!     never as a guessed pass.
//!   * Only the TOP `Received:` header is believed: it is written by our own Postfix, the only thing that faces the internet. Every older one is ignored (a sender can forge those).
//!   * The DMARC policy record is found by the RFC 9989 DNS Tree Walk (at most 8 queries), not by a Public Suffix List that goes stale. The result is handed to mail-auth as its organisational-domain function.
//!   * The pure parts (Received parser, tree walk, spoof checks, label maths, Authentication-Results line) are tested here without a network; the async part talks to the DNS through mail-auth.
use mail_auth::{
    dmarc::{verify::DmarcParameters, Policy},
    spf::verify::SpfParameters,
    AuthenticatedMessage, DkimResult, DmarcResult, IprevResult, MessageAuthenticator, SpfResult,
};
use serde_json::{json, Value};
use std::net::IpAddr;

pub const MAX_WALK: usize = 8;             // RFC 9989: at most 8 DNS queries per tree walk
pub const VERIFY_TIMEOUT_S: u64 = 12;      // a slow DNS never holds a mail longer than this (it is recorded as temperror)

// ---------------------------------------------------------------- pure: what our own Postfix wrote on top

#[derive(Debug, PartialEq, Clone, Default)]
pub struct Recv { pub ip: Option<IpAddr>, pub helo: Option<String>, pub rdns: Option<String>, pub tls_version: Option<String>, pub tls_cipher: Option<String>, pub tls_group: Option<String>, pub tls_class: &'static str }

/// The first `Received:` header of the header block (the one our own Postfix wrote), unfolded to one line. None = no such header, so nothing is believed
pub fn top_received(raw: &[u8]) -> Option<String> {
    let head = &raw[..raw.len().min(16_384)];
    let text = String::from_utf8_lossy(head);
    let mut lines = text.split('\n').map(|l| l.trim_end_matches('\r')).peekable();
    // Our Postfix always writes its own `Received:` ABOVE every header the sender supplied. Anything above it was added by our own side (LMTP Return-Path / Delivered-To, a milter's
    // Authentication-Results ...). So the FIRST `Received:` of the header block is the one we trust; every later one is sender-written and never read.
    while let Some(l) = lines.peek() {
        if l.is_empty() { return None; }
        if l.to_ascii_lowercase().starts_with("received:") { break; }
        lines.next();
    }
    let first = lines.next()?;
    let mut out = first["received:".len()..].trim().to_string();
    for l in lines {
        if l.starts_with(' ') || l.starts_with('\t') { out.push(' '); out.push_str(l.trim()); } else { break; }
    }
    Some(out)
}

/// `from HELO (rdns [ip]) (using TLSv1.3 with cipher X (256/256 bits) key-exchange G server-signature S) ... by host (Postfix) with ESMTPS`
pub fn parse_received(h: &str) -> Recv {
    let mut r = Recv { tls_class: "none", ..Default::default() };
    let low = h.to_ascii_lowercase();
    if let Some(rest) = low.strip_prefix("from ") {
        let helo_end = rest.find([' ', '(']).unwrap_or(rest.len());
        let helo = h[5..5 + helo_end].trim();
        if !helo.is_empty() && helo.len() <= 255 && !helo.chars().any(|c| c.is_control()) { r.helo = Some(helo.to_string()); }
        if let (Some(a), Some(b)) = (rest.find('('), rest.find(')')) {
            if a < b {
                let inner = &h[5 + a + 1..5 + b];
                if let (Some(ob), Some(cb)) = (inner.rfind('['), inner.rfind(']')) {
                    if ob < cb {
                        let ip_s = inner[ob + 1..cb].trim().trim_start_matches("IPv6:").trim_start_matches("ipv6:");
                        r.ip = ip_s.parse::<IpAddr>().ok();
                        let name = inner[..ob].trim();
                        if !name.is_empty() && !name.eq_ignore_ascii_case("unknown") && name.len() <= 255 { r.rdns = Some(name.to_ascii_lowercase()); }
                    }
                }
            }
        }
    }
    if let Some(i) = h.find("(using ") {
        let tail = &h[i + 7..];
        let tail = &tail[..tail.find(')').map(|e| e + 1).unwrap_or(tail.len())];
        // the cipher text holds its own brackets "(256/256 bits)", so cut at the sentinel words instead of the first ')'
        let tail_full = &h[i + 7..];
        let ver = tail_full.split_whitespace().next().unwrap_or("");
        if !ver.is_empty() && ver.len() <= 24 { r.tls_version = Some(ver.to_string()); }
        if let Some(c) = tail_full.find("with cipher ") { let v = tail_full[c + 12..].split_whitespace().next().unwrap_or(""); if !v.is_empty() && v.len() <= 64 { r.tls_cipher = Some(v.to_string()); } }
        if let Some(k) = tail_full.find("key-exchange ") { let v = tail_full[k + 13..].split_whitespace().next().unwrap_or("").trim_end_matches(')'); if !v.is_empty() && v.len() <= 48 { r.tls_group = Some(v.to_string()); } }
        let _ = tail;
        let v = ver.to_ascii_uppercase();
        let pq = r.tls_group.as_deref().map_or(false, |g| g.to_ascii_uppercase().contains("MLKEM") || g.to_ascii_uppercase().contains("KYBER"));
        r.tls_class = if v.starts_with("TLSV1.3") { if pq { "tls13_pq" } else { "tls13" } } else if v.starts_with("TLSV1.2") { "tls12" } else { "none" };
    }
    // "with ESMTPS" / "ESMTPSA" says TLS was used, but without the "(using ...)" detail we cannot tell the version: that is UNKNOWN (null), never a false "none" that would lower the score
    if r.tls_class == "none" && r.tls_version.is_none() {
        let w = low.split(" with ").nth(1).and_then(|x| x.split_whitespace().next()).unwrap_or("");
        if w.starts_with("esmtps") || w.starts_with("lmtps") { r.tls_class = "unknown"; }
    }
    r
}

// ---------------------------------------------------------------- pure: domains

pub fn labels(d: &str) -> Vec<&str> { d.split('.').filter(|l| !l.is_empty()).collect() }
/// The rightmost `n` labels of a domain ("a.b.c.d", 2 -> "c.d").
pub fn rightmost(d: &str, n: usize) -> String { let l = labels(d); let k = l.len().saturating_sub(n); l[k..].join(".") }

/// "Name <a@b.c>" / "a@b.c" -> (display name, domain of the address), both lower-case; None when no address is found.
pub fn from_parts(raw_from: &str) -> Option<(String, String)> {
    let s = raw_from.trim();
    let (disp, addr) = match (s.rfind('<'), s.rfind('>')) { (Some(a), Some(b)) if a < b => (s[..a].trim().trim_matches('"').trim(), &s[a + 1..b]), _ => ("", s) };
    let dom = addr.rsplit_once('@')?.1.trim().trim_end_matches('.').to_ascii_lowercase();
    if dom.is_empty() || dom.len() > 253 { return None; }
    Some((disp.to_ascii_lowercase(), dom))
}

/// The display name pretends to be another address ("ceo@bank.com" <evil@x.tld>): it holds an e-mail-like token whose domain differs from the real one (compared on the last two labels).
pub fn display_spoof(display: &str, real_domain: &str) -> bool {
    for tok in display.split(|c: char| c.is_whitespace() || c == '<' || c == '>' || c == '"' || c == ',' || c == ';') {
        if let Some((l, d)) = tok.rsplit_once('@') {
            let d = d.trim_end_matches('.').to_ascii_lowercase();
            if !l.is_empty() && d.contains('.') && rightmost(&d, 2) != rightmost(real_domain, 2) { return true; }
        }
    }
    false
}

#[derive(Clone, Copy, PartialEq, Debug)]
enum Script { Latin, Cyrillic, Greek, Other }
fn script_of(c: char) -> Option<Script> {
    match c { 'a'..='z' | 'A'..='Z' | '\u{00C0}'..='\u{024F}' => Some(Script::Latin), '\u{0400}'..='\u{052F}' => Some(Script::Cyrillic), '\u{0370}'..='\u{03FF}' => Some(Script::Greek),
        '0'..='9' | '-' | '.' | '_' => None, c if c.is_alphabetic() => Some(Script::Other), _ => None }
}
/// (unicode form when the domain uses xn-- labels, one label mixes Latin with Cyrillic or Greek). Never fails: an undecodable label is simply left as written.
pub fn idn_facts(domain: &str) -> (Option<String>, bool) {
    if !domain.contains("xn--") { return (None, false); }
    let (uni, res) = idna::domain_to_unicode(domain);
    let uni = if res.is_ok() { uni } else { domain.to_string() };
    let mut mixed = false;
    for lab in uni.split('.') {
        let mut seen: Vec<Script> = vec![];
        for c in lab.chars() { if let Some(s) = script_of(c) { if !seen.contains(&s) { seen.push(s); } } }
        if seen.len() > 1 { mixed = true; }
    }
    (if uni != domain && uni.len() <= 253 { Some(uni) } else { None }, mixed)
}

// ---------------------------------------------------------------- pure: the RFC 9989 tree walk

/// The names whose `_dmarc.` record the walk asks for, in order: the full domain first, then the rightmost 7, 6, ... 1 labels (never more than 8 queries; a longer domain skips the middle labels).
pub fn walk_names(domain: &str) -> Vec<String> {
    let n = labels(domain).len();
    if n == 0 { return vec![]; }
    let mut v = vec![labels(domain).join(".")];
    let mut k = (n - 1).min(MAX_WALK - 1);
    while k >= 1 && v.len() < MAX_WALK { v.push(rightmost(domain, k)); k -= 1; }
    v
}
#[derive(Debug, Clone, PartialEq)]
pub struct Found { pub name: String, pub psd: Option<char> }   // psd = 'y' | 'n' | None (tag absent)
/// psd= tag of a `v=DMARC1` record text (None when absent or not y/n).
pub fn psd_tag(rec: &str) -> Option<char> {
    for part in rec.split(';') { let p = part.trim(); if let Some(v) = p.strip_prefix("psd=").or_else(|| p.strip_prefix("psd =")) { return match v.trim() { "y" => Some('y'), "n" => Some('n'), _ => None }; } }
    None
}
/// The organisational domain from what the walk found (RFC 9989 section 4.10, in short): the record of the longest name is the policy record; if a record says psd=n, that name is the organisational domain;
/// else the shortest record that is not psd=y; a psd=y record names a public suffix, so the domain one label below it is the organisational domain. No record anywhere: the last two labels.
pub fn org_from_found(domain: &str, found: &[Found]) -> String {
    let n = labels(domain).len();
    if found.is_empty() { return rightmost(domain, 2.min(n.max(1))); }
    if let Some(f) = found.iter().filter(|f| f.psd == Some('n')).min_by_key(|f| labels(&f.name).len()) { return f.name.clone(); }
    let shortest = found.iter().min_by_key(|f| labels(&f.name).len()).unwrap();
    if shortest.psd == Some('y') { let k = labels(&shortest.name).len() + 1; return rightmost(domain, k.min(n)); }
    shortest.name.clone()
}
pub fn same_org(a: &str, b: &str, org_labels: usize) -> bool { rightmost(a, org_labels).eq_ignore_ascii_case(&rightmost(b, org_labels)) }

// ---------------------------------------------------------------- pure: result words and the RFC 8601 line

pub fn spf_word(r: SpfResult) -> &'static str { match r { SpfResult::Pass => "pass", SpfResult::Fail => "fail", SpfResult::SoftFail => "softfail", SpfResult::Neutral => "neutral", SpfResult::TempError => "temperror", SpfResult::PermError => "permerror", SpfResult::None => "none" } }
pub fn dkim_word(r: &DkimResult) -> &'static str { match r { DkimResult::Pass => "pass", DkimResult::Fail(_) => "fail", DkimResult::Neutral(_) => "neutral", DkimResult::TempError(_) => "temperror", DkimResult::PermError(_) => "permerror", DkimResult::None => "none" } }
/// All signatures together: any pass = pass; otherwise the "worst" word (fail > permerror > temperror > neutral > none).
pub fn dkim_overall(words: &[&'static str]) -> &'static str {
    if words.contains(&"pass") { return "pass"; }
    for w in ["fail", "permerror", "temperror", "neutral"] { if words.contains(&w) { return w; } }
    "none"
}
pub fn policy_word(p: &Policy) -> Option<&'static str> { match p { Policy::None => Some("none"), Policy::Quarantine => Some("quarantine"), Policy::Reject => Some("reject"), _ => None } }
/// One line, no control characters: `host; spf=pass smtp.mailfrom=x; dkim=pass header.d=x; dmarc=pass header.from=x`
pub fn authres_line(host: &str, ev: &Value) -> String {
    let g = |k: &str| ev[k].as_str().unwrap_or("none").to_string();
    let clean = |s: String| s.chars().filter(|c| !c.is_control()).take(120).collect::<String>();
    let mut s = format!("{host}; spf={} smtp.mailfrom={}; dkim={} header.d={}; dmarc={} header.from={}; arc={}; iprev={}", g("spf_result"), clean(ev["mail_from_domain"].as_str().unwrap_or("").to_string()),
        g("dkim_result"), clean(ev["first_dkim_domain"].as_str().unwrap_or("none").to_string()), g("dmarc_result"), clean(g("header_from_domain")), g("arc_result"), g("iprev_result"));
    s.truncate(1900); s
}

fn now_s() -> i64 { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0) }

// ---------------------------------------------------------------- async: the checks

pub struct Verifier { auth: MessageAuthenticator, host: String }
impl Verifier {
    /// None when the system resolver cannot be set up (then mail is stored without a verdict, honestly).
    pub fn new(host: &str) -> Option<Self> { MessageAuthenticator::new_system_conf().ok().map(|auth| Verifier { auth, host: host.to_string() }) }

    async fn dmarc_walk(&self, domain: &str) -> (Vec<Found>, usize) {
        let mut found = vec![]; let names = walk_names(domain); let mut q = 0;
        for n in &names {
            q += 1;
            if let Ok(raw) = self.auth.txt_raw_lookup(format!("_dmarc.{n}.")).await {
                let t = String::from_utf8_lossy(&raw).to_string();
                if t.to_ascii_lowercase().contains("v=dmarc1") { found.push(Found { name: n.clone(), psd: psd_tag(&t.to_ascii_lowercase()) }); }
            }
        }
        (found, q)
    }

    /// The evidence object for fmail_auth_record183 and the signature rows. `mail_from` is the SMTP envelope sender ("" = null sender). Never panics, never blocks longer than VERIFY_TIMEOUT_S.
    pub async fn verify(&self, raw: &[u8], mail_from: &str) -> Option<(Value, Value)> {
        match tokio::time::timeout(std::time::Duration::from_secs(VERIFY_TIMEOUT_S), self.verify_inner(raw, mail_from)).await { Ok(v) => v, Err(_) => None }
    }

    async fn verify_inner(&self, raw: &[u8], mail_from: &str) -> Option<(Value, Value)> {
        let msg = AuthenticatedMessage::parse(raw)?;
        let from_raw = msg.from.first()?.clone();
        let (display, from_dom) = from_parts(&from_raw).or_else(|| from_parts(&format!("<{from_raw}>")))?;
        let top = top_received(raw);
        if top.is_none() { // observability only: header NAMES (never values) so a layout surprise is visible in the journal
            let names: Vec<String> = String::from_utf8_lossy(&raw[..raw.len().min(4096)]).lines().take_while(|l| !l.is_empty()).filter(|l| !l.starts_with(' ') && !l.starts_with('\t')).filter_map(|l| l.split(':').next()).take(12).map(|n| n.chars().take(40).collect()).collect();
            eprintln!("founder: mail auth: no Received header found; top header names: {}", names.join(","));
        }
        let recv = top.map(|h| parse_received(&h)).unwrap_or(Recv { tls_class: "none", ..Default::default() });
        // display name comes from the raw From header (mail-auth keeps addresses only)
        let disp = raw_from_header(raw).and_then(|h| from_parts(&h)).map(|p| p.0).unwrap_or(display);
        let spoof = display_spoof(&disp, &from_dom);
        let (uni, mixed) = idn_facts(&from_dom);
        let (found, queries) = self.dmarc_walk(&from_dom).await;
        let org = org_from_found(&from_dom, &found);
        let org_n = labels(&org).len().max(1);
        let helo = recv.helo.clone().unwrap_or_default();
        let mf_dom = mail_from.rsplit_once('@').map(|x| x.1.to_ascii_lowercase()).unwrap_or_default();

        // iprev + SPF need the client address; without it they are "none" (never a guessed pass)
        let mut iprev = "none"; let mut spf_o = mail_auth::SpfOutput::new(String::new());
        if let Some(ip) = recv.ip {
            iprev = match self.auth.verify_iprev(ip).await.result() { IprevResult::Pass => "pass", IprevResult::Fail(_) => "fail", IprevResult::TempError(_) => "temperror", IprevResult::PermError(_) => "permerror", IprevResult::None => "none" };
            let host = self.host.as_str();
            let out = if mail_from.is_empty() || !mail_from.contains('@') { self.auth.verify_spf(SpfParameters::verify_ehlo(ip, &helo, host)).await }
                      else { self.auth.verify_spf(SpfParameters::verify_mail_from(ip, &helo, host, mail_from)).await };
            spf_o = out;
        }
        let (spf_out, spf_dom) = (spf_o.result(), spf_o.domain().to_ascii_lowercase());
        let dkim = self.auth.verify_dkim(&msg).await;
        let arc = self.auth.verify_arc(&msg).await;
        let dm_from = if !mf_dom.is_empty() { mf_dom.clone() } else { helo.to_ascii_lowercase() };
        let dmarc = self.auth.verify_dmarc(DmarcParameters::new(&msg, &dkim, &dm_from, &spf_o).with_domain_suffix_fn(|d| { let l = labels(d); let k = l.len().saturating_sub(org_n); let start: usize = l[..k].iter().map(|x| x.len() + 1).sum(); &d[start.min(d.len())..] })).await;

        let (dsp, ddk) = (matches!(dmarc.spf_result(), DmarcResult::Pass), matches!(dmarc.dkim_result(), DmarcResult::Pass));
        let has_rec = dmarc.dmarc_record().is_some();
        let dm_word = if dsp || ddk { "pass" } else if !has_rec { "none" }
            else if matches!(dmarc.spf_result(), DmarcResult::TempError(_)) || matches!(dmarc.dkim_result(), DmarcResult::TempError(_)) { "temperror" }
            else if matches!(dmarc.spf_result(), DmarcResult::PermError(_)) && matches!(dmarc.dkim_result(), DmarcResult::PermError(_)) { "permerror" } else { "fail" };
        let policy = if has_rec { policy_word(&dmarc.policy()) } else { None };
        let disp_w = if dm_word == "fail" { policy } else if dm_word == "none" { None } else { Some("none") };
        let now = now_s();
        let mut sigs = vec![]; let mut words = vec![]; let mut first_dom = String::new();
        for o in dkim.iter().take(16) {
            let Some(s) = o.signature() else { continue };
            let w = dkim_word(o.result()); words.push(w);
            let d = s.d.to_ascii_lowercase();
            if first_dom.is_empty() { first_dom = d.clone(); }
            let algo = match s.a { mail_auth::common::crypto::Algorithm::RsaSha1 => "rsa-sha1", mail_auth::common::crypto::Algorithm::RsaSha256 => "rsa-sha256", mail_auth::common::crypto::Algorithm::Ed25519Sha256 => "ed25519-sha256" };
            let strict = d == from_dom; let relaxed = strict || same_org(&d, &from_dom, org_n);
            sigs.push(json!({"domain": d, "selector": s.s.to_ascii_lowercase(), "algo": algo, "result": w, "aligned_relaxed": relaxed, "aligned_strict": strict,
                "sig_age_s": if s.t > 0 { Value::from((now - s.t as i64).clamp(-31_536_000, 315_360_000)) } else { Value::Null },
                "expired": s.x > 0 && (s.x as i64) < now, "body_limited": s.l > 0}));
        }
        let arc_w = match arc.result() { DkimResult::Pass => "pass", DkimResult::None => "none", _ => "fail" };
        let ev = json!({"header_from_domain": from_dom, "org_domain": org, "from_unicode": uni, "display_spoof": spoof, "mixed_script": mixed,
            "client_ip": recv.ip.map(|i| i.to_string()), "helo": recv.helo, "rdns": recv.rdns, "mail_from_domain": if mf_dom.is_empty() { Value::Null } else { Value::from(mf_dom.clone()) },
            "spf_result": spf_word(spf_out), "spf_domain": if spf_out == SpfResult::None || spf_dom.is_empty() { Value::Null } else { Value::from(spf_dom) },
            "dkim_result": dkim_overall(&words), "dmarc_result": dm_word, "dmarc_policy": policy, "dmarc_disposition": disp_w, "dmarc_spf_aligned": dsp, "dmarc_dkim_aligned": ddk,
            "dmarc_walk": queries as i64, "dmarc_record_domain": found.iter().min_by_key(|f| labels(&f.name).len()).map(|f| f.name.clone()),
            "arc_result": arc_w, "arc_instances": arc.sets().len() as i64, "iprev_result": iprev,
            "tls_class": if recv.tls_class == "unknown" { Value::Null } else { Value::from(recv.tls_class) }, "tls_version": recv.tls_version, "tls_cipher": recv.tls_cipher, "tls_group": recv.tls_group, "first_dkim_domain": first_dom});
        let mut ev = ev;
        ev["authres"] = Value::from(authres_line(&self.host, &ev));
        if let Some(o) = ev.as_object_mut() { o.remove("first_dkim_domain"); }
        Some((ev, Value::Array(sigs)))
    }
}

/// The raw text of the first `From:` header (unfolded), for the display name.
pub fn raw_from_header(raw: &[u8]) -> Option<String> {
    let head = String::from_utf8_lossy(&raw[..raw.len().min(65_536)]).to_string();
    let end = head.find("\r\n\r\n").or_else(|| head.find("\n\n")).unwrap_or(head.len());
    let mut cur: Option<String> = None;
    for l in head[..end].split('\n') {
        let l = l.trim_end_matches('\r');
        if let Some(c) = cur.as_mut() { if l.starts_with(' ') || l.starts_with('\t') { c.push(' '); c.push_str(l.trim()); continue; } else { break; } }
        if l.len() > 5 && l[..5].eq_ignore_ascii_case("from:") { cur = Some(l[5..].trim().to_string()); }
    }
    cur
}

#[cfg(test)]
mod tests {
    use super::*;
    const PF: &str = "Received: from mail-wr1-f41.google.com (mail-wr1-f41.google.com [209.85.221.41])\r\n\t(using TLSv1.3 with cipher TLS_AES_256_GCM_SHA384 (256/256 bits) key-exchange X25519MLKEM768 server-signature RSA-PSS (2048 bits))\r\n\tby mx.anexomail.com (Postfix) with ESMTPS id 4abc\r\n\tfor <founder@anexomail.com>; Tue, 17 Nov 2026 02:00:00 +0500 (PKT)\r\nReceived: from forged.example (forged.example [6.6.6.6]) by x\r\nFrom: A <a@b.c>\r\n\r\nbody";

    #[test]
    fn lmtp_headers_above_postfix_received_are_skipped_but_other_headers_refuse() {
        let ok = format!("Return-Path: <a@b.c>\r\nDelivered-To: f@x\r\nX-Original-To: f@x\r\n{}", PF);
        assert!(top_received(ok.as_bytes()).unwrap().contains("mail-wr1-f41.google.com"));
        let milter = format!("Authentication-Results: mx; dkim=pass\r\nX-Spam: no\r\n{}", PF);
        assert!(top_received(milter.as_bytes()).unwrap().contains("209.85.221.41"));
        assert!(top_received(b"X-Spam: yes\r\n\r\nReceived: from x (x [1.1.1.1]) by y\r\n").is_none());   // a Received in the body is never read
    }

    #[test]
    fn postfix_top_header_is_read_with_ip_helo_rdns_and_post_quantum_tls() {
        let h = top_received(PF.as_bytes()).unwrap();
        let r = parse_received(&h);
        assert_eq!(r.ip, Some("209.85.221.41".parse().unwrap())); assert_eq!(r.helo.as_deref(), Some("mail-wr1-f41.google.com")); assert_eq!(r.rdns.as_deref(), Some("mail-wr1-f41.google.com"));
        assert_eq!(r.tls_version.as_deref(), Some("TLSv1.3")); assert_eq!(r.tls_cipher.as_deref(), Some("TLS_AES_256_GCM_SHA384")); assert_eq!(r.tls_group.as_deref(), Some("X25519MLKEM768")); assert_eq!(r.tls_class, "tls13_pq");
    }
    #[test]
    fn only_the_top_received_is_believed_an_older_forged_one_is_ignored() {
        let h = top_received(PF.as_bytes()).unwrap(); assert!(!h.contains("6.6.6.6"));
        assert!(top_received(b"From: a@b.c\r\n\r\nReceived: from x (x [1.1.1.1]) by y\r\n").is_none());   // in the body = never read
    }
    #[test]
    fn plain_tls12_no_tls_unknown_rdns_and_ipv6() {
        let r = parse_received("from h.example (unknown [IPv6:2001:db8::7]) (using TLSv1.2 with cipher ECDHE-RSA-AES256-GCM-SHA384 (256/256 bits)) by mx (Postfix) with ESMTPS");
        assert_eq!(r.ip, Some("2001:db8::7".parse().unwrap())); assert_eq!(r.rdns, None); assert_eq!(r.tls_class, "tls12");
        let r = parse_received("from h.example (h.example [192.0.2.1]) by mx (Postfix) with ESMTP id 1"); assert_eq!(r.tls_class, "none"); assert_eq!(r.tls_version, None);
        let r = parse_received("by mx (Postfix, from userid 0) id 5"); assert_eq!(r.ip, None); assert_eq!(r.helo, None);
        let r = parse_received("from a (b [not-an-ip]) by mx"); assert_eq!(r.ip, None);
        let r = parse_received("from h.example (h.example [192.0.2.1]) by mx (Postfix) with ESMTPS id 9"); assert_eq!(r.tls_class, "unknown", "TLS was used but Postfix did not log how: unknown, not none");
        let r = parse_received("from h.example (h.example [192.0.2.1]) by mx (Postfix) with ESMTPSA id 9"); assert_eq!(r.tls_class, "unknown");
        let r = parse_received("from x (x [1.2.3.4]) (using TLSv1.3 with cipher TLS_AES_256_GCM_SHA384 (256/256 bits) key-exchange X25519 server-signature ECDSA) by mx"); assert_eq!(r.tls_class, "tls13");
    }
    #[test]
    fn unfolding_stops_at_the_next_header() {
        let h = top_received(b"Received: from a (a [1.1.1.1])\r\n  by b\r\nTo: x\r\n\r\n").unwrap(); assert_eq!(h, "from a (a [1.1.1.1]) by b");
    }
    #[test]
    fn walk_asks_at_most_eight_names_and_skips_the_middle_of_long_domains() {
        assert_eq!(walk_names("a.b.example.com"), vec!["a.b.example.com", "b.example.com", "example.com", "com"]);
        assert_eq!(walk_names("example.com"), vec!["example.com", "com"]);
        assert_eq!(walk_names("com"), vec!["com"]);
        let long = "l1.l2.l3.l4.l5.l6.l7.l8.l9.example.com"; let w = walk_names(long);
        assert_eq!(w.len(), MAX_WALK); assert_eq!(w[0], long); assert_eq!(w[1], "l5.l6.l7.l8.l9.example.com"); assert_eq!(w[7], "com");
    }
    #[test]
    fn organisational_domain_from_what_the_walk_found() {
        let f = |n: &str, p: Option<char>| Found { name: n.into(), psd: p };
        assert_eq!(org_from_found("mail.example.com", &[f("example.com", None)]), "example.com");
        assert_eq!(org_from_found("mail.example.com", &[f("mail.example.com", None), f("example.com", None)]), "example.com");   // the shortest record wins
        assert_eq!(org_from_found("a.b.example.com", &[f("b.example.com", Some('n')), f("example.com", None)]), "b.example.com");  // psd=n names the organisation
        assert_eq!(org_from_found("shop.example.co.uk", &[f("co.uk", Some('y'))]), "example.co.uk");                               // psd=y is a public suffix: one label below
        assert_eq!(org_from_found("x.example.org", &[]), "example.org"); assert_eq!(org_from_found("localhost", &[]), "localhost");
    }
    #[test]
    fn psd_tag_reads_only_y_and_n() {
        assert_eq!(psd_tag("v=dmarc1; p=reject; psd=y"), Some('y')); assert_eq!(psd_tag("v=dmarc1; psd=n; p=none"), Some('n')); assert_eq!(psd_tag("v=dmarc1; psd=maybe"), None); assert_eq!(psd_tag("v=dmarc1; p=none"), None);
    }
    #[test]
    fn alignment_maths() {
        assert!(same_org("mail.example.com", "example.com", 2)); assert!(!same_org("example.net", "example.com", 2)); assert!(same_org("a.example.co.uk", "b.example.co.uk", 3)); assert!(!same_org("a.evil.co.uk", "b.example.co.uk", 3));
        assert_eq!(rightmost("a.b.c.d", 2), "c.d"); assert_eq!(rightmost("a", 5), "a");
    }
    #[test]
    fn from_header_parts_and_display_name_spoof() {
        assert_eq!(from_parts("\"PayPal\" <Service@PayPal.Example>"), Some(("paypal".into(), "paypal.example".into()))); assert_eq!(from_parts("a@b.co"), Some(("".into(), "b.co".into()))); assert_eq!(from_parts("no address"), None);
        assert!(display_spoof("ceo@bank.com", "evil.example")); assert!(display_spoof("support <help@paypal.com>", "evil.example")); assert!(!display_spoof("ceo@bank.com", "mail.bank.com")); assert!(!display_spoof("Alice Smith", "x.example")); assert!(!display_spoof("a@localhost", "x.example"));
    }
    #[test]
    fn mixed_script_domains_are_found() {
        let (u, m) = idn_facts("xn--pypal-4ve.com"); assert!(m, "{u:?}"); assert!(u.unwrap().contains('\u{0430}'));    // paypal with a Cyrillic a
        let (u, m) = idn_facts("example.com"); assert_eq!((u, m), (None, false));
        let (_, m) = idn_facts("xn--mnchen-3ya.de"); assert!(!m);                                                         // münchen: all Latin
        let (_, m) = idn_facts("xn--80ak6aa92e.com"); assert!(!m);                                                         // apple in pure Cyrillic: one script
    }
    #[test]
    fn result_words_and_overall_dkim() {
        assert_eq!(spf_word(SpfResult::SoftFail), "softfail"); assert_eq!(dkim_overall(&["fail", "pass"]), "pass"); assert_eq!(dkim_overall(&["neutral", "fail"]), "fail"); assert_eq!(dkim_overall(&[]), "none");
        assert_eq!(policy_word(&Policy::Reject), Some("reject")); assert_eq!(policy_word(&Policy::Unspecified), None);
    }
    #[test]
    fn authres_line_is_one_clean_line() {
        let ev = json!({"spf_result": "pass", "mail_from_domain": "a.example", "dkim_result": "pass", "first_dkim_domain": "a.example", "dmarc_result": "pass", "header_from_domain": "a.example\r\nX: y", "arc_result": "none", "iprev_result": "pass"});
        let s = authres_line("anexomail.com", &ev); assert!(s.starts_with("anexomail.com; spf=pass smtp.mailfrom=a.example;")); assert!(!s.contains('\r') && !s.contains('\n')); assert!(s.contains("dmarc=pass"));
    }
    #[test]
    fn raw_from_header_is_unfolded_and_only_from_the_head() {
        assert_eq!(raw_from_header(b"To: x\r\nFrom: \"A B\"\r\n <a@b.c>\r\nSubject: s\r\n\r\nFrom: fake@x.y").unwrap(), "\"A B\" <a@b.c>");
        assert!(raw_from_header(b"Subject: s\r\n\r\nFrom: only-in-body@x.y").is_none());
    }
    #[tokio::test]
    async fn a_mail_without_a_from_has_no_verdict_and_never_panics() {
        if let Some(v) = Verifier::new("anexomail.com") { assert!(v.verify(b"Subject: x\r\n\r\nhi", "a@b.c").await.is_none()); }
    }
}
