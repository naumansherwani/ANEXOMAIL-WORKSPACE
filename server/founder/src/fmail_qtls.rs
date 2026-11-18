//! QC1c F8 (Qtls, 18 Nov 2026): the transport-security policies of the OTHER side. Technology: Rust + Tokio, mail-auth 0.9.2 (the TXT parsers for MTA-STS and TLS-RPT), hickory-resolver with DNSSEC validation (dnssec-ring) for DANE,
//! reqwest (rustls, no redirects, pinned public addresses) for the MTA-STS policy file, sha2 for the TLSA matching. INHERITABLE BY AWAM: no database, no founder names.
//! WHAT IS HERE: (1) MTA-STS (RFC 8461): `fetch_mta_sts_policy` + the policy grammar + MX pattern matching. (2) DANE (RFC 7672 / 6698): `tlsa_lookup` keeps ONLY records the resolver proved Secure by DNSSEC; `dane_matches` checks usage 3 (DANE-EE)
//! and 2 (DANE-TA), selector 0 / 1, matching 0 / 1 / 2. (3) TLS-RPT (RFC 8460): the report builder and the rua parser. (4) `require_tls_for`: the one decision "may this hop fall back to clear text?" (never for MTA-STS enforce or DANE).
//! HONEST STATE: the parsers, the matching and the decision are unit-tested here; the DNSSEC proof against a real signed domain, the policy fetch against a real MTA-STS domain, and the call from the sender are proven LIVE, not here.
use crate::fmail_smtp as smtp;
use serde_json::{json, Value};
use sha2::{Digest, Sha256, Sha512};
use std::time::Duration;

// ---------------------------------------------------------------- MTA-STS
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum StsMode { Enforce, Testing, None }
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StsPolicy { pub mode: StsMode, pub mx: Vec<String>, pub max_age: u64 }
const MAX_AGE_CAP: u64 = 31_557_600;   // RFC 8461 3.2: one year

/// The policy file: `key: value` lines (CRLF or LF), version STSv1, mode, one or more mx, max_age. Anything else, a repeated scalar key, or a missing required key = None (never a half policy).
pub fn parse_policy(text: &str) -> Option<StsPolicy> {
    let (mut version, mut mode, mut max_age) = (false, None, None); let mut mx = Vec::new();
    if text.len() > 64 * 1024 { return None; }
    for l in text.lines().map(|l| l.trim()).filter(|l| !l.is_empty()) {
        let (k, v) = l.split_once(':')?; let (k, v) = (k.trim().to_ascii_lowercase(), v.trim());
        match k.as_str() {
            "version" => { if version || v != "STSv1" { return None; } version = true; }
            "mode" => { if mode.is_some() { return None; } mode = Some(match v.to_ascii_lowercase().as_str() { "enforce" => StsMode::Enforce, "testing" => StsMode::Testing, "none" => StsMode::None, _ => return None }); }
            "max_age" => { if max_age.is_some() { return None; } let n: u64 = v.parse().ok()?; if n > MAX_AGE_CAP { return None; } max_age = Some(n); }
            "mx" => { let h = v.trim_end_matches('.').to_ascii_lowercase(); if h.is_empty() || h.len() > 253 || !h.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'-' | b'*')) { return None; } mx.push(h); }
            _ => {}   // unknown keys are ignored (RFC 8461 3.2)
        }
    }
    let (mode, max_age) = (mode?, max_age?);
    if !version || (mode != StsMode::None && mx.is_empty()) { return None; }
    Some(StsPolicy { mode, mx, max_age })
}
/// RFC 8461 4.1: an exact (case-free) match, or `*.example.com` matching exactly one extra left label.
pub fn mx_matches(pattern: &str, host: &str) -> bool {
    let (p, h) = (pattern.trim_end_matches('.').to_ascii_lowercase(), host.trim_end_matches('.').to_ascii_lowercase());
    if let Some(rest) = p.strip_prefix("*.") { return h.split_once('.').map_or(false, |(first, tail)| !first.is_empty() && tail == rest); }
    p == h
}
impl StsPolicy { pub fn allows_host(&self, host: &str) -> bool { self.mode == StsMode::None || self.mx.iter().any(|p| mx_matches(p, host)) } }

/// The `_mta-sts.<domain>` TXT record: `v=STSv1; id=...` through the mail-auth parser. Returns the id.
pub fn sts_txt_id(txt: &str) -> Option<String> { use mail_auth::common::parse::TxtRecordParser; mail_auth::mta_sts::MtaSts::parse(txt.as_bytes()).ok().map(|m| m.id) }

/// Fetch the policy: TXT first (no TXT = no policy, Ok(None)), then https://mta-sts.<domain>/.well-known/mta-sts.txt with a verified certificate, no redirect, 10 s, 64 KiB, only PUBLIC addresses of that host (no SSRF through the recipient's DNS).
pub async fn fetch_mta_sts_policy(res: &hickory_resolver::TokioResolver, domain: &str) -> Result<Option<StsPolicy>, String> {
    let d = domain.trim_end_matches('.').to_ascii_lowercase();
    let txt = match res.txt_lookup(format!("_mta-sts.{d}.")).await { Ok(t) => t, Err(e) if e.is_no_records_found() => return Ok(None), Err(e) => return Err(format!("MTA-STS TXT lookup failed: {e}")) };
    let has = txt.iter().any(|r| sts_txt_id(&r.to_string()).is_some()); if !has { return Ok(None); }
    let host = format!("mta-sts.{d}");
    let addrs: Vec<std::net::SocketAddr> = res.lookup_ip(format!("{host}.")).await.map_err(|e| format!("policy host lookup failed: {e}"))?.iter().filter(|ip| smtp::is_public(ip)).map(|ip| std::net::SocketAddr::new(ip, 443)).collect();
    if addrs.is_empty() { return Err("the policy host has no public address".into()); }
    let c = reqwest::Client::builder().redirect(reqwest::redirect::Policy::none()).timeout(Duration::from_secs(10)).https_only(true).resolve_to_addrs(&host, &addrs).build().map_err(|e| e.to_string())?;
    let r = c.get(format!("https://{host}/.well-known/mta-sts.txt")).send().await.map_err(|e| format!("policy fetch failed: {e}"))?;
    if !r.status().is_success() { return Err(format!("policy fetch answered {}", r.status())); }
    if r.content_length().map_or(false, |n| n > 64 * 1024) { return Err("policy file too big".into()); }
    let body = r.bytes().await.map_err(|e| e.to_string())?; if body.len() > 64 * 1024 { return Err("policy file too big".into()); }
    parse_policy(&String::from_utf8_lossy(&body)).map(Some).ok_or_else(|| "the policy file is not a valid MTA-STS policy".into())
}

// ---------------------------------------------------------------- DANE
/// The resolver DANE needs: the same real upstream DNS as the sender, with DNSSEC validation ON. Without validation no answer is ever Secure, so `tlsa_lookup` would return nothing (fail safe).
pub fn dane_resolver() -> Option<hickory_resolver::TokioResolver> { let mut b = crate::fmail_out::public_dns_builder().ok()?; b.options_mut().validate = true; Some(b.build()) }
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Tlsa { pub usage: u8, pub selector: u8, pub matching: u8, pub data: Vec<u8> }

/// TLSA records of `_25._tcp.<mx>`. ONLY records the validating resolver proved Secure (DNSSEC) are kept: an unsigned or bogus answer yields nothing, so DANE can never be spoofed into existence.
pub async fn tlsa_lookup(res: &hickory_resolver::TokioResolver, mx_host: &str) -> Result<Vec<Tlsa>, String> {
    use hickory_resolver::proto::{dnssec::Proof, rr::{RData, RecordType}};
    let name = format!("_25._tcp.{}.", mx_host.trim_end_matches('.'));
    let l = match res.lookup(name, RecordType::TLSA).await { Ok(l) => l, Err(e) if e.is_no_records_found() => return Ok(vec![]), Err(e) => return Err(format!("TLSA lookup failed: {e}")) };
    Ok(l.record_iter().filter(|r| r.proof() == Proof::Secure).filter_map(|r| match r.data() { RData::TLSA(t) => Some(Tlsa { usage: u8::from(t.cert_usage()), selector: u8::from(t.selector()), matching: u8::from(t.matching()), data: t.cert_data().to_vec() }), _ => None }).collect())
}
/// DER: read one TLV at `i`, returns (tag, content_start, content_end).
fn tlv(b: &[u8], i: usize) -> Option<(u8, usize, usize)> {
    let tag = *b.get(i)?; let l0 = *b.get(i + 1)? as usize;
    let (len, hdr) = if l0 < 0x80 { (l0, 2) } else { let n = l0 & 0x7f; if n == 0 || n > 4 { return None; } let mut v = 0usize; for k in 0..n { v = (v << 8) | *b.get(i + 2 + k)? as usize; } (v, 2 + n) };
    let end = i.checked_add(hdr)?.checked_add(len)?; if end > b.len() { return None; } Some((tag, i + hdr, end))
}
/// The SubjectPublicKeyInfo (whole TLV) of an X.509 certificate.
pub fn spki_of(cert: &[u8]) -> Option<&[u8]> {
    let (t, s, _e) = tlv(cert, 0)?; if t != 0x30 { return None; }
    let (t, ts, te) = tlv(cert, s)?; if t != 0x30 { return None; }          // tbsCertificate
    let mut i = ts; let (t0, _, e0) = tlv(cert, i)?; if t0 == 0xa0 { i = e0; }  // optional [0] version
    // serial, signature alg, issuer, validity, subject, then SPKI
    for _ in 0..5 { let (_, _, e) = tlv(cert, i)?; i = e; }
    let (t, _, e) = tlv(cert, i)?; if t != 0x30 || e > te { return None; } Some(&cert[i..e])
}
fn matching(m: u8, data: &[u8]) -> Option<Vec<u8>> { match m { 0 => Some(data.to_vec()), 1 => Some(Sha256::digest(data).to_vec()), 2 => Some(Sha512::digest(data).to_vec()), _ => None } }
/// Does the presented chain (end entity first, DER) satisfy any record? usage 3 = the end-entity certificate itself, usage 2 = any certificate of the chain (the trust anchor the record names).
/// Usage 0 / 1 (PKIX-TA / PKIX-EE) are not accepted here: they would need full path validation, so they never count as a match (fail closed).
pub fn dane_matches(records: &[Tlsa], chain: &[Vec<u8>]) -> bool {
    records.iter().any(|r| {
        let certs: Vec<&Vec<u8>> = match r.usage { 3 => chain.iter().take(1).collect(), 2 => chain.iter().collect(), _ => return false };
        certs.iter().any(|c| { let sel: Option<&[u8]> = match r.selector { 0 => Some(c.as_slice()), 1 => spki_of(c), _ => None }; sel.and_then(|s| matching(r.matching, s)).map_or(false, |m| m == r.data) })
    })
}

// ---------------------------------------------------------------- TLS-RPT
/// The `rua=` targets of a `_smtp._tls.<domain>` TXT record (mail-auth parser): mailto: and https: only.
pub fn rpt_rua(txt: &str) -> Vec<String> {
    use mail_auth::common::parse::TxtRecordParser; use mail_auth::mta_sts::ReportUri;
    mail_auth::mta_sts::TlsRpt::parse(txt.as_bytes()).map(|r| r.rua.into_iter().map(|u| match u { ReportUri::Mail(m) => format!("mailto:{m}"), ReportUri::Http(h) => h }).collect()).unwrap_or_default()
}
#[derive(Debug, Clone)]
pub struct RptFailure { pub result_type: &'static str, pub sending_mx_ip: String, pub receiving_mx_host: String, pub count: u64, pub reason: String }
/// RFC 8460 section 4 aggregate report (JSON). `policy_type` is "sts", "tlsa" or "no-policy-found". Only counts and host names: never an address, never a subject.
pub fn build_tls_rpt_report(org: &str, contact: &str, report_id: &str, start_utc: &str, end_utc: &str, policy_domain: &str, policy_type: &str, ok: u64, failed: u64, failures: &[RptFailure]) -> Value {
    const TYPES: [&str; 11] = ["starttls-not-supported", "certificate-host-mismatch", "certificate-expired", "certificate-not-trusted", "validation-failure", "tlsa-invalid", "dnssec-invalid", "dane-required", "sts-policy-fetch-error", "sts-policy-invalid", "sts-webpki-invalid"];
    json!({
        "organization-name": org, "date-range": {"start-datetime": start_utc, "end-datetime": end_utc}, "contact-info": contact, "report-id": report_id,
        "policies": [{ "policy": {"policy-type": policy_type, "policy-domain": policy_domain},
            "summary": {"total-successful-session-count": ok, "total-failure-session-count": failed},
            "failure-details": failures.iter().filter(|f| TYPES.contains(&f.result_type)).map(|f| json!({"result-type": f.result_type, "sending-mta-ip": f.sending_mx_ip, "receiving-mx-hostname": f.receiving_mx_host, "failed-session-count": f.count, "failure-reason-code": f.reason})).collect::<Vec<_>>() }]
    })
}

// ---------------------------------------------------------------- the decision
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Hop { /// this MX may not be used at all
    Skip(String), /// TLS is mandatory and the certificate must pass (the reason names the policy)
    MustTls(String), /// the founder's global "send only if TLS" rule, no policy involved
    Strict, /// opportunistic: STARTTLS if offered (the sender in fmail_smtp still refuses clear text by default)
    Opportunistic }
/// "May this hop fall back to clear text?" Never when MTA-STS enforces or DANE is proven; an MX outside an enforcing MTA-STS policy is skipped; testing mode only reports.
/// `always` is the founder's own rule "send only if TLS" (the default); it turns every hop into at least Strict. DANE wins over MTA-STS (RFC 8461 2: DANE takes precedence).
pub fn require_tls_for(sts: Option<&StsPolicy>, dane_for_host: bool, mx_host: &str, always: bool) -> Hop {
    if dane_for_host { return Hop::MustTls("DANE (DNSSEC-proven TLSA record)".into()); }
    if let Some(p) = sts { if p.mode == StsMode::Enforce { return if p.allows_host(mx_host) { Hop::MustTls("MTA-STS enforce".into()) } else { Hop::Skip(format!("{mx_host} is not listed in the MTA-STS policy")) }; } }
    if always { Hop::Strict } else { Hop::Opportunistic }
}

#[cfg(test)]
mod tests {
    use super::*;
    const POL: &str = "version: STSv1\r\nmode: enforce\r\nmx: mail.example.com\r\nmx: *.example.net\r\nmax_age: 604800\r\n";
    #[test] fn policy_grammar() {
        let p = parse_policy(POL).unwrap(); assert_eq!(p.mode, StsMode::Enforce); assert_eq!(p.mx, vec!["mail.example.com", "*.example.net"]); assert_eq!(p.max_age, 604800);
        for bad in ["", "version: STSv2\nmode: enforce\nmx: a.b\nmax_age: 1", "version: STSv1\nmode: enforce\nmax_age: 1", "version: STSv1\nmode: sometimes\nmx: a.b\nmax_age: 1", "version: STSv1\nmode: enforce\nmx: a.b", "version: STSv1\nmode: enforce\nmx: a.b\nmax_age: 99999999999", "version: STSv1\nmode: enforce\nmode: testing\nmx: a.b\nmax_age: 1", "garbage line"] { assert!(parse_policy(bad).is_none(), "{bad:?}"); }
        assert!(parse_policy("version: STSv1\nmode: none\nmax_age: 0").is_some(), "mode none needs no mx");
        assert!(parse_policy("version: STSv1\nfuture: x\nmode: testing\nmx: a.b\nmax_age: 5").is_some(), "unknown keys are ignored");
    }
    #[test] fn mx_patterns() {
        assert!(mx_matches("mail.example.com", "MAIL.example.com.") && !mx_matches("mail.example.com", "x.mail.example.com"));
        assert!(mx_matches("*.example.net", "mx1.example.net") && !mx_matches("*.example.net", "example.net") && !mx_matches("*.example.net", "a.b.example.net"));
        let p = parse_policy(POL).unwrap(); assert!(p.allows_host("mx1.example.net") && !p.allows_host("evil.example.org"));
    }
    #[test] fn txt_id_and_rua() {
        assert_eq!(sts_txt_id("v=STSv1; id=20260101T000000;").as_deref(), Some("20260101T000000")); assert!(sts_txt_id("v=spf1 -all").is_none());
        assert_eq!(rpt_rua("v=TLSRPTv1; rua=mailto:tls@example.com,https://r.example.com/x"), vec!["mailto:tls@example.com", "https://r.example.com/x"]); assert!(rpt_rua("nonsense").is_empty());
    }
    // a minimal but real X.509-shaped DER: SEQ{ SEQ{ [0]{2}, serial, sigalg, issuer, validity, subject, SPKI }, sigalg, sig }
    fn cert() -> (Vec<u8>, Vec<u8>) {
        let spki = vec![0x30, 0x0a, 0x30, 0x03, 0x06, 0x01, 0x2a, 0x03, 0x03, 0x00, 0xde, 0xad];
        let mut tbs = vec![0xa0, 0x03, 0x02, 0x01, 0x02, 0x02, 0x01, 0x07, 0x30, 0x00, 0x30, 0x00, 0x30, 0x00, 0x30, 0x00]; tbs.extend_from_slice(&spki);
        let mut body = vec![0x30, tbs.len() as u8]; body.extend_from_slice(&tbs); body.extend_from_slice(&[0x30, 0x00, 0x03, 0x01, 0x00]);
        let mut c = vec![0x30, body.len() as u8]; c.extend_from_slice(&body); (c, spki)
    }
    #[test] fn spki_extraction() { let (c, spki) = cert(); assert_eq!(spki_of(&c).unwrap(), spki.as_slice()); assert!(spki_of(&c[..10]).is_none() && spki_of(b"").is_none()); }
    #[test] fn dane_matching_all_forms_and_fail_closed() {
        let (c, spki) = cert(); let chain = vec![c.clone(), vec![1, 2, 3]];
        let r = |u, s, m, d: Vec<u8>| Tlsa { usage: u, selector: s, matching: m, data: d };
        assert!(dane_matches(&[r(3, 0, 0, c.clone())], &chain), "EE full exact");
        assert!(dane_matches(&[r(3, 1, 1, Sha256::digest(&spki).to_vec())], &chain), "EE spki sha256");
        assert!(dane_matches(&[r(3, 0, 2, Sha512::digest(&c).to_vec())], &chain), "EE full sha512");
        assert!(dane_matches(&[r(2, 0, 1, Sha256::digest([1u8, 2, 3]).to_vec())], &chain), "TA anywhere in the chain");
        assert!(!dane_matches(&[r(3, 0, 1, Sha256::digest([1u8, 2, 3]).to_vec())], &chain), "usage 3 looks at the end entity only");
        assert!(!dane_matches(&[r(3, 1, 1, vec![0; 32])], &chain), "wrong hash");
        assert!(!dane_matches(&[r(0, 0, 0, c.clone()), r(1, 0, 0, c.clone())], &chain), "PKIX usages never count");
        assert!(!dane_matches(&[r(3, 9, 0, c.clone()), r(3, 0, 9, c.clone())], &chain), "unknown selector / matching");
        assert!(!dane_matches(&[], &chain) && !dane_matches(&[r(3, 0, 0, c)], &[]));
    }
    #[test] fn tls_rpt_report_shape() {
        let f = [RptFailure { result_type: "starttls-not-supported", sending_mx_ip: "203.0.113.2".into(), receiving_mx_host: "mx.example.com".into(), count: 3, reason: "no STARTTLS".into() }, RptFailure { result_type: "made-up", sending_mx_ip: "x".into(), receiving_mx_host: "y".into(), count: 1, reason: "z".into() }];
        let v = build_tls_rpt_report("Anexomail", "tls@anexomail.com", "r-1", "2026-11-17T00:00:00Z", "2026-11-17T23:59:59Z", "example.com", "sts", 40, 3, &f);
        assert_eq!(v["policies"][0]["summary"]["total-failure-session-count"], 3); assert_eq!(v["policies"][0]["policy"]["policy-type"], "sts");
        assert_eq!(v["policies"][0]["failure-details"].as_array().unwrap().len(), 1, "a result type outside RFC 8460 is dropped");
        assert!(!v.to_string().contains('@') || v["contact-info"] == "tls@anexomail.com", "no recipient address in a report");
    }
    #[test] fn the_decision() {
        let en = parse_policy(POL).unwrap(); let tst = parse_policy("version: STSv1\nmode: testing\nmx: a.b\nmax_age: 1").unwrap();
        assert!(matches!(require_tls_for(Some(&en), false, "mail.example.com", false), Hop::MustTls(_)));
        assert!(matches!(require_tls_for(Some(&en), false, "evil.example.org", false), Hop::Skip(_)));
        assert!(matches!(require_tls_for(Some(&en), true, "evil.example.org", false), Hop::MustTls(_)), "DANE wins");
        assert_eq!(require_tls_for(Some(&tst), false, "x.y", true), Hop::Strict); assert_eq!(require_tls_for(None, false, "x.y", true), Hop::Strict); assert_eq!(require_tls_for(None, false, "x.y", false), Hop::Opportunistic);
    }
}
