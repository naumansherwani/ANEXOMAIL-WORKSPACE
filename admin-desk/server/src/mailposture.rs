// ANEXOMAIL ADMIN DESK mailposture.rs (phase 1m-7, card B6b Own-domain mail posture, list BL-26, 23 Nov 2026). Rust + Tokio + Axum + hickory-resolver (DNSSEC validating). List: D6-CARDS-LIST-23NOV.md (section B6b, W1..W8).
// ONE read-only door over the sealed router (Rule 52) and a live Desk session. The Desk asks real DNS ITSELF about Anexomail's OWN mail domain (no outside service, no customer data): MX, SPF, DKIM, DMARC, MTA-STS (RFC 8461),
// TLS-RPT (RFC 8460), DANE TLSA on every MX host (RFC 7672) and the DNSSEC chain (DS lookup through a validating resolver). Each check is ok / missing / bogus. A DNS failure (timeout, SERVFAIL) is NOT a check result:
// the whole answer becomes "Data unavailable" (never a guess). AD17 re-checks the right, writes the hourly hash-chained sample and says which checks WORSENED since the previous hour.
use crate::bridge::owner;
use crate::door::{lit, rows};
use axum::{body::Bytes, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};
use serde_json::{json, Value};
use std::time::Duration;

pub const KEYS: [&str; 8] = ["mx", "spf", "dkim", "dmarc", "mta_sts", "tls_rpt", "dane", "dnssec"];
fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json"), (header::CACHE_CONTROL, "no-store")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, json!({"error": e}).to_string()) }
fn unavailable() -> Response { err(StatusCode::SERVICE_UNAVAILABLE, "data_unavailable") }

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum St { Ok, Missing, Bogus }
impl St { pub fn word(self) -> &'static str { match self { St::Ok => "ok", St::Missing => "missing", St::Bogus => "bogus" } } }

// ---------- PURE classification of the TXT text (all tested) ----------
fn tags(txt: &str) -> Vec<(String, String)> { txt.split(';').filter_map(|p| { let p = p.trim(); let (k, v) = p.split_once('=')?; Some((k.trim().to_ascii_lowercase(), v.trim().to_string())) }).collect() }
fn tag<'a>(t: &'a [(String, String)], k: &str) -> Option<&'a str> { t.iter().find(|(a, _)| a == k).map(|(_, v)| v.as_str()) }
/// SPF: exactly one v=spf1 record that ends in -all or ~all. Two records, or +all / ?all / no all = bogus.
pub fn spf(txts: &[String]) -> St {
    let r: Vec<&String> = txts.iter().filter(|t| t.trim().to_ascii_lowercase().starts_with("v=spf1")).collect();
    match r.len() { 0 => St::Missing, 1 => { let l = r[0].trim().to_ascii_lowercase(); if l.ends_with("-all") || l.ends_with("~all") { St::Ok } else { St::Bogus } } _ => St::Bogus }
}
/// DMARC: one v=DMARC1 record with p=quarantine or p=reject. p=none, no p, or two records = bogus (it protects nothing).
pub fn dmarc(txts: &[String]) -> St {
    let r: Vec<&String> = txts.iter().filter(|t| t.trim().to_ascii_lowercase().starts_with("v=dmarc1")).collect();
    match r.len() { 0 => St::Missing, 1 => { let t = tags(r[0]); match tag(&t, "p").map(|p| p.to_ascii_lowercase()).as_deref() { Some("quarantine") | Some("reject") => St::Ok, _ => St::Bogus } } _ => St::Bogus }
}
/// MTA-STS TXT: v=STSv1 with a non-empty id (the policy itself lives on the https policy host, checked by the sender side).
pub fn mta_sts(txts: &[String]) -> St {
    let r: Vec<&String> = txts.iter().filter(|t| t.trim().to_ascii_lowercase().starts_with("v=stsv1")).collect();
    match r.len() { 0 => St::Missing, 1 => { let t = tags(r[0]); if tag(&t, "id").map(|i| !i.is_empty() && i.len() <= 32 && i.chars().all(|c| c.is_ascii_alphanumeric())).unwrap_or(false) { St::Ok } else { St::Bogus } } _ => St::Bogus }
}
/// TLS-RPT TXT: v=TLSRPTv1 with an rua of mailto: or https: (every comma part).
pub fn tls_rpt(txts: &[String]) -> St {
    let r: Vec<&String> = txts.iter().filter(|t| t.trim().to_ascii_lowercase().starts_with("v=tlsrptv1")).collect();
    match r.len() { 0 => St::Missing, 1 => { let t = tags(r[0]); match tag(&t, "rua") { Some(u) if !u.is_empty() && u.split(',').all(|x| { let x = x.trim().to_ascii_lowercase(); x.starts_with("mailto:") || x.starts_with("https://") }) => St::Ok, _ => St::Bogus } } _ => St::Bogus }
}
/// DKIM selector TXT: v=DKIM1 (or a p= key). An empty p= means the key was revoked = bogus.
pub fn dkim(txts: &[String]) -> St {
    let r: Vec<&String> = txts.iter().filter(|t| { let l = t.to_ascii_lowercase(); l.contains("v=dkim1") || l.contains("p=") }).collect();
    match r.len() { 0 => St::Missing, _ => { let t = tags(r[0]); match tag(&t, "p") { Some(p) if !p.is_empty() => St::Ok, _ => St::Bogus } } }
}
/// The answer the door gives: exactly the eight keys, each ok / missing / bogus.
pub fn answer(c: &[(&str, St); 8]) -> Value { let mut m = serde_json::Map::new(); for (k, s) in c { m.insert((*k).into(), json!(s.word())); } Value::Object(m) }
/// Shape check of what AD17 returns (and of the probe answer before it is written).
pub fn series_ok(v: &Value) -> bool {
    let Some(o) = v.as_object() else { return false };
    if o.len() != 3 { return false; }
    let sp = v["spark"].as_array();
    sp.map(|a| a.len() == 24 && a.iter().all(|x| x.is_null() || x.as_i64().map(|n| (0..=8).contains(&n)).unwrap_or(false))).unwrap_or(false)
        && ["up", "steady", "down", "unknown"].contains(&v["trend"].as_str().unwrap_or(""))
        && v["worsened"].as_array().map(|a| a.iter().all(|x| x.as_str().map(|s| KEYS.contains(&s)).unwrap_or(false))).unwrap_or(false)
}
pub fn domain_ok(d: &str) -> bool { !d.is_empty() && d.len() <= 120 && d.split('.').count() >= 2 && d.split('.').all(|l| !l.is_empty() && l.len() <= 63 && l.chars().all(|c| c.is_ascii_alphanumeric() || c == '-') && !l.starts_with('-') && !l.ends_with('-')) }

// ---------- the live probe ----------
use hickory_resolver::{config::ResolveHosts, proto::rr::RecordType, TokioResolver};
fn resolver(validate: bool) -> Result<TokioResolver, ()> {
    let mut b = TokioResolver::builder_tokio().map_err(|e| eprintln!("desk mailposture: resolver: {e}"))?;
    b.options_mut().use_hosts_file = ResolveHosts::Never; b.options_mut().validate = validate; b.options_mut().attempts = 2; b.options_mut().timeout = Duration::from_secs(2);
    Ok(b.build())
}
/// TXT strings at a name. Empty list = the name has no TXT (NXDOMAIN or NODATA). Any other failure = Err (the whole answer is then unavailable).
async fn txt(r: &TokioResolver, name: &str) -> Result<Vec<String>, ()> {
    match r.txt_lookup(name).await {
        Ok(l) => Ok(l.iter().map(|t| t.txt_data().iter().map(|b| String::from_utf8_lossy(b).into_owned()).collect::<String>()).collect()),
        Err(e) if e.is_no_records_found() => Ok(vec![]),
        Err(e) => { eprintln!("desk mailposture: txt {name}: {e}"); Err(()) }
    }
}
async fn has(r: &TokioResolver, name: &str, t: RecordType) -> Result<bool, ()> {
    match r.lookup(name, t).await { Ok(l) => Ok(l.iter().next().is_some()), Err(e) if e.is_no_records_found() => Ok(false), Err(e) => { eprintln!("desk mailposture: {t} {name}: {e}"); Err(()) } }
}
pub async fn probe(domain: &str, selector: &str) -> Result<Value, ()> {
    let (plain, valid) = (resolver(false)?, resolver(true)?);
    let mx: Vec<String> = match plain.mx_lookup(domain).await { Ok(l) => l.iter().map(|m| m.exchange().to_utf8().trim_end_matches('.').to_ascii_lowercase()).collect(), Err(e) if e.is_no_records_found() => vec![], Err(e) => { eprintln!("desk mailposture: mx: {e}"); return Err(()) } };
    let mxs = if mx.is_empty() { St::Missing } else { St::Ok };
    let sp = spf(&txt(&plain, domain).await?);
    let dk = dkim(&txt(&plain, &format!("{selector}._domainkey.{domain}")).await?);
    let dm = dmarc(&txt(&plain, &format!("_dmarc.{domain}")).await?);
    let ms = mta_sts(&txt(&plain, &format!("_mta-sts.{domain}")).await?);
    let tr = tls_rpt(&txt(&plain, &format!("_smtp._tls.{domain}")).await?);
    // DNSSEC: the DS record of the domain asked through a VALIDATING resolver. A validation failure surfaces as an error = bogus; no DS = missing.
    let dnssec = match valid.lookup(domain, RecordType::DS).await { Ok(l) if l.iter().next().is_some() => St::Ok, Ok(_) => St::Missing, Err(e) if e.is_no_records_found() => St::Missing,
        Err(e) => { let m = e.to_string().to_ascii_lowercase(); if m.contains("dnssec") || m.contains("bogus") || m.contains("rrsig") || m.contains("validation") { St::Bogus } else { eprintln!("desk mailposture: ds: {e}"); return Err(()) } } };
    // DANE: every MX host publishes a TLSA at _25._tcp.<host> AND the domain is signed. A TLSA without DNSSEC protects nothing = bogus.
    let mut all = !mx.is_empty(); let mut any = false;
    for h in &mx { if has(&plain, &format!("_25._tcp.{h}"), RecordType::TLSA).await? { any = true; } else { all = false; } }
    let dane = if !any { St::Missing } else if all && dnssec == St::Ok { St::Ok } else { St::Bogus };
    Ok(answer(&[("mx", mxs), ("spf", sp), ("dkim", dk), ("dmarc", dm), ("mta_sts", ms), ("tls_rpt", tr), ("dane", dane), ("dnssec", dnssec)]))
}

/// POST /desk/v1/mailposture/board  (empty body)
pub async fn board(h: HeaderMap, body: Bytes) -> Response {
    if body.len() > 64 { return err(StatusCode::PAYLOAD_TOO_LARGE, "too_large"); }
    let domain = std::env::var("DESK_MAIL_DOMAIN").unwrap_or_else(|_| "anexomail.com".into());
    let selector = std::env::var("DESK_DKIM_SELECTOR").unwrap_or_else(|_| "e2611a".into());
    if !domain_ok(&domain) || !domain_ok(&format!("{selector}.x")) { eprintln!("desk mailposture: bad DESK_MAIL_DOMAIN / DESK_DKIM_SELECTOR"); return unavailable(); }
    let (c, who) = match tokio::time::timeout(Duration::from_secs(6), owner(&h)).await { Err(_) => return unavailable(), Ok(Err(r)) => return r, Ok(Ok(x)) => x };
    let Ok(Ok(p)) = tokio::time::timeout(Duration::from_secs(12), probe(&domain, &selector)).await else { return unavailable() };
    match rows(&c, &format!("select desk.fadm_mailposture_record('{who}'::uuid, {}::jsonb)::text", lit(&p.to_string()))).await {
        Ok(v) => match v.first().and_then(|r| r.get(0)).and_then(|j| serde_json::from_str::<Value>(j).ok()) {
            Some(sr) if series_ok(&sr) => out(StatusCode::OK, json!({"domain": domain, "checks": p, "series": sr}).to_string()),
            Some(_) => { eprintln!("desk mailposture: wrong series shape"); unavailable() }
            None => err(StatusCode::FORBIDDEN, "not_allowed") },
        Err(e) => { eprintln!("desk mailposture: record: {e}"); unavailable() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn v(s: &[&str]) -> Vec<String> { s.iter().map(|x| x.to_string()).collect() }
    #[test] fn spf_cases() { assert_eq!(spf(&v(&["v=spf1 mx -all"])), St::Ok); assert_eq!(spf(&v(&["v=spf1 include:x ~all"])), St::Ok); assert_eq!(spf(&v(&["v=spf1 +all"])), St::Bogus); assert_eq!(spf(&v(&["v=spf1 mx"])), St::Bogus);
        assert_eq!(spf(&v(&["v=spf1 -all", "v=spf1 mx -all"])), St::Bogus); assert_eq!(spf(&v(&["google-site-verification=x"])), St::Missing); assert_eq!(spf(&[]), St::Missing); }
    #[test] fn dmarc_cases() { assert_eq!(dmarc(&v(&["v=DMARC1; p=reject; rua=mailto:a@b.c"])), St::Ok); assert_eq!(dmarc(&v(&["v=DMARC1; p=quarantine"])), St::Ok); assert_eq!(dmarc(&v(&["v=DMARC1; p=none"])), St::Bogus);
        assert_eq!(dmarc(&v(&["v=DMARC1; rua=mailto:a@b.c"])), St::Bogus); assert_eq!(dmarc(&v(&["v=DMARC1; p=reject", "v=DMARC1; p=none"])), St::Bogus); assert_eq!(dmarc(&[]), St::Missing); }
    #[test] fn sts_rpt_cases() { assert_eq!(mta_sts(&v(&["v=STSv1; id=20261123T0000"])), St::Ok); assert_eq!(mta_sts(&v(&["v=STSv1; id="])), St::Bogus); assert_eq!(mta_sts(&v(&["v=STSv1; id=a b"])), St::Bogus); assert_eq!(mta_sts(&[]), St::Missing);
        assert_eq!(tls_rpt(&v(&["v=TLSRPTv1; rua=mailto:tls@x.y"])), St::Ok); assert_eq!(tls_rpt(&v(&["v=TLSRPTv1; rua=https://x.y/r,mailto:t@x.y"])), St::Ok); assert_eq!(tls_rpt(&v(&["v=TLSRPTv1; rua=ftp://x"])), St::Bogus); assert_eq!(tls_rpt(&v(&["v=TLSRPTv1"])), St::Bogus); assert_eq!(tls_rpt(&[]), St::Missing); }
    #[test] fn dkim_cases() { assert_eq!(dkim(&v(&["v=DKIM1; k=rsa; p=MIIBIj"])), St::Ok); assert_eq!(dkim(&v(&["v=DKIM1; p="])), St::Bogus); assert_eq!(dkim(&[]), St::Missing); }
    #[test] fn answer_has_the_eight_keys() { let a = answer(&[("mx", St::Ok), ("spf", St::Ok), ("dkim", St::Missing), ("dmarc", St::Bogus), ("mta_sts", St::Ok), ("tls_rpt", St::Ok), ("dane", St::Missing), ("dnssec", St::Ok)]);
        assert_eq!(a.as_object().unwrap().len(), 8); for k in KEYS { assert!(a[k].is_string()); } assert_eq!(a["dmarc"], "bogus"); }
    #[test] fn series_shape() { let g = json!({"spark": vec![json!(null); 23].into_iter().chain([json!(5)]).collect::<Vec<_>>(), "trend": "steady", "worsened": ["spf"]}); assert!(series_ok(&g));
        let mut b = g.clone(); b["trend"] = json!("sideways"); assert!(!series_ok(&b)); let mut b = g.clone(); b["worsened"] = json!(["secret"]); assert!(!series_ok(&b)); let mut b = g.clone(); b["spark"][0] = json!(9); assert!(!series_ok(&b)); let mut b = g.clone(); b["extra"] = json!(1); assert!(!series_ok(&b)); }
    #[test] fn domains() { assert!(domain_ok("anexomail.com")); assert!(!domain_ok("a")); assert!(!domain_ok("a..b")); assert!(!domain_ok("-a.com")); assert!(!domain_ok("a b.com")); assert!(!domain_ok("x'.com")); }
}
