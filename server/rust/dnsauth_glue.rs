// ============================================================================
// dnsauth_glue.rs — D2 "Authoritative-NS live check" ka I/O hissa (Rust PRIMARY; founder HAAN 20 Oct 2026, Domains list #1).
//
//   mail.domains.verify  {domain_id}  -> pehle jaisa jawab {ok, ready, checks, domain} + {source, zone, nameservers, public}
//
// Pehle: Cloudflare DoH (public resolver CACHE) — record lagne ke baad bhi TTL khatam hone tak "nahi mila".
// Ab: (1) zone + uske NS dhoondo (recursive resolver se, sirf "kaun jawab deta hai"), (2) har record SEEDHA un nameservers se
// poochho (RD=0, cache nahi) — Cloudflare/Namecheap/GoDaddy ne jaise hi publish kiya, yahan hara. (3) Saath mein public DoH
// sirf "duniya mein phail raha hai?" batane ke liye (faisla authoritative ka). Authoritative tak pahunch hi na ho (firewall,
// NS down) => pehle wala public raasta — kabhi pehle se bura nahi.
// UDP + EDNS0 (4096); jawab kata (TC) => wohi sawal TCP par. Har sawal 2.5s, sab nameservers ek saath (Tokio join).
// Child module of the crate root: uses `mail_identity`, `mail_can_manage`, `forbidden`, `dns_records`, `doh`, `sb_rpc`,
// `MAIL_HOST`, `ok`, `err`. Adds NO crate (tokio net + std).
// ============================================================================

use crate::dnsauth_core::{self as dc, Reply};
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use std::net::{Ipv4Addr, SocketAddr};
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpStream, UdpSocket};

type Resp = axum::response::Response;

const STEP: Duration = Duration::from_millis(2500);
const MAX_NS: usize = 4;

pub fn owns(proc: &str) -> bool {
    proc == "mail.domains.verify"
}

/// Recursive resolvers (sirf zone/NS/A dhoondne ke liye). `DNSAUTH_RESOLVERS="1.1.1.1:53,8.8.8.8:53"` se badal sakte hain (test).
fn resolvers() -> Vec<SocketAddr> {
    let env = std::env::var("DNSAUTH_RESOLVERS").unwrap_or_default();
    let list: Vec<SocketAddr> = env.split(',').filter_map(|s| s.trim().parse().ok()).collect();
    if !list.is_empty() {
        return list;
    }
    ["1.1.1.1:53", "8.8.8.8:53", "9.9.9.9:53"].iter().filter_map(|s| s.parse().ok()).collect()
}

/// Test mein authoritative server ka port badalna (asli duniya mein hamesha 53).
fn ns_port() -> u16 {
    std::env::var("DNSAUTH_NS_PORT").ok().and_then(|p| p.parse().ok()).unwrap_or(53)
}

fn qid() -> u16 {
    let n = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.subsec_nanos()).unwrap_or(7);
    (n ^ (n >> 16)) as u16
}

async fn tcp_query(server: SocketAddr, pkt: &[u8], id: u16) -> Option<Reply> {
    let fut = async {
        let mut s = TcpStream::connect(server).await.ok()?;
        let mut framed = Vec::with_capacity(pkt.len() + 2);
        framed.extend_from_slice(&(pkt.len() as u16).to_be_bytes());
        framed.extend_from_slice(pkt);
        s.write_all(&framed).await.ok()?;
        let mut len = [0u8; 2];
        s.read_exact(&mut len).await.ok()?;
        let n = u16::from_be_bytes(len) as usize;
        let mut buf = vec![0u8; n];
        s.read_exact(&mut buf).await.ok()?;
        dc::parse_reply(&buf).filter(|r| r.id == id)
    };
    tokio::time::timeout(STEP, fut).await.ok().flatten()
}

/// Ek sawal ek server se. UDP, kata ho to TCP.
async fn query(server: SocketAddr, name: &str, qtype: u16, recurse: bool) -> Option<Reply> {
    let id = qid();
    let pkt = dc::build_query(id, name, qtype, recurse);
    let udp = async {
        let sock = UdpSocket::bind(("0.0.0.0", 0)).await.ok()?;
        sock.send_to(&pkt, server).await.ok()?;
        let mut buf = vec![0u8; 4096];
        loop {
            let (n, from) = sock.recv_from(&mut buf).await.ok()?;
            if from.ip() != server.ip() {
                continue; // kisi aur ka packet — nazar-andaaz (spoofing se bachav)
            }
            if let Some(r) = dc::parse_reply(&buf[..n]) {
                if r.id == id {
                    return Some(r);
                }
            }
        }
    };
    let r = tokio::time::timeout(STEP, udp).await.ok().flatten()?;
    if r.truncated { tcp_query(server, &pkt, id).await.or(Some(r)) } else { Some(r) }
}

/// Recursive resolver se (pehla jo jawab de).
async fn ask_resolver(name: &str, qtype: u16) -> Option<Reply> {
    for r in resolvers() {
        if let Some(rep) = query(r, name, qtype, true).await {
            if rep.rcode == 0 || rep.rcode == 3 {
                return Some(rep);
            }
        }
    }
    None
}

/// Zone (jahan NS records hain) + uske nameservers ke IPv4. Subdomain (mail.acme.co.uk) par bhi sahi zone (acme.co.uk).
pub async fn zone_nameservers(domain: &str) -> Option<(String, Vec<(String, Vec<Ipv4Addr>)>)> {
    for cand in dc::zone_candidates(domain) {
        let Some(rep) = ask_resolver(&cand, dc::T_NS).await else { continue };
        let names: Vec<String> = rep
            .answers
            .iter()
            .filter(|rr| rr.name == cand)
            .filter_map(|rr| match &rr.data {
                dc::Data::Ns(h) => Some(h.clone()),
                _ => None,
            })
            .collect();
        if names.is_empty() {
            continue;
        }
        let mut out = Vec::new();
        for ns in names.into_iter().take(MAX_NS) {
            let mut ips: Vec<Ipv4Addr> = dc::a_records(&rep, &ns).into_iter().map(Ipv4Addr::from).collect();
            if ips.is_empty() {
                if let Some(a) = ask_resolver(&ns, dc::T_A).await {
                    ips = dc::a_records(&a, &ns).into_iter().map(Ipv4Addr::from).collect();
                }
            }
            if !ips.is_empty() {
                out.push((ns, ips));
            }
        }
        if !out.is_empty() {
            return Some((cand, out));
        }
    }
    None
}

/// Har nameserver se ek saath; jo authoritative (AA) jawab de wahi ginti mein. Wapas: (har NS ka jawab, kitne NS ne jawab diya)
async fn ask_authoritative(ns: &[(String, Vec<Ipv4Addr>)], name: &str, qtype: u16) -> (Vec<Reply>, usize) {
    let port = ns_port();
    let futs = ns.iter().map(|(_, ips)| {
        let ip = ips[0];
        let name = name.to_string();
        async move { query(SocketAddr::from((ip, port)), &name, qtype, false).await }
    });
    let all = futures_join(futs.collect()).await;
    let answered: Vec<Reply> = all.into_iter().flatten().filter(|r| r.authoritative && (r.rcode == 0 || r.rcode == 3)).collect();
    let n = answered.len();
    (answered, n)
}

/// `futures::join_all` ke baghair (koi naya crate nahi): har future alag task, phir intezar.
async fn futures_join<F>(futs: Vec<F>) -> Vec<Option<Reply>>
where
    F: std::future::Future<Output = Option<Reply>> + Send + 'static,
{
    let handles: Vec<_> = futs.into_iter().map(tokio::spawn).collect();
    let mut out = Vec::with_capacity(handles.len());
    for h in handles {
        out.push(h.await.ok().flatten());
    }
    out
}

fn uniq_txt(rs: &[Reply], name: &str) -> Vec<String> {
    let mut v: Vec<String> = rs.iter().flat_map(|r| dc::txts(r, name)).collect();
    v.sort();
    v.dedup();
    v
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    if proc != "mail.domains.verify" {
        return crate::err(StatusCode::NOT_FOUND, "procedure_not_in_rust", "Unknown procedure").into_response();
    }
    let requested = input.get("org_id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let me = match crate::mail_identity(token, &requested).await {
        Ok(me) => me,
        Err((status, code, detail)) => return crate::err(status, code, &detail).into_response(),
    };
    if !crate::mail_can_manage(&me.org_id, &me.id).await {
        return crate::forbidden();
    }
    let id = input.get("domain_id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    match verify(&me.org_id, &id).await {
        Ok(v) => crate::ok(v).into_response(),
        Err(e) => crate::err(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e).into_response(),
    }
}

async fn verify(org: &str, id: &str) -> Result<Value, String> {
    let list = crate::sb_rpc("org_domain_list", json!({ "_org": org })).await?;
    let d = match list.as_array().and_then(|a| a.iter().find(|x| x.get("id").and_then(|v| v.as_str()) == Some(id))).cloned() {
        Some(d) => d,
        None => return Ok(json!({ "ok": false, "error": "domain_not_found" })),
    };
    let g = |k: &str| d.get(k).and_then(|v| v.as_str()).unwrap_or("").to_string();
    let Some(dom) = dc::clean_domain(&g("domain")) else {
        return Ok(json!({ "ok": false, "error": "domain_invalid" }));
    };
    let token = g("verify_token");
    let sel = {
        let x = g("dkim_selector");
        if x.is_empty() { "anexo1".to_string() } else { x }
    };
    let dkim_pub: String = g("dkim_public").split_whitespace().collect();
    let n_txt = format!("_anexomail-verify.{dom}");
    let n_dkim = format!("{sel}._domainkey.{dom}");
    let n_dmarc = format!("_dmarc.{dom}");
    let host = crate::MAIL_HOST;

    // public (duniya) — sirf jaankari; authoritative ke saath hi chalta hai
    let public = async {
        let (txt, mx, spf, dkim, dmarc) = tokio::join!(
            crate::doh(&n_txt, "TXT"),
            crate::doh(&dom, "MX"),
            crate::doh(&dom, "TXT"),
            crate::doh(&n_dkim, "TXT"),
            crate::doh(&n_dmarc, "TXT"),
        );
        let mx_pairs: Vec<(u16, String)> = mx.iter().map(|m| {
            let mut it = m.split_whitespace();
            let p = it.next().and_then(|x| x.parse().ok()).unwrap_or(0);
            (p, it.next().unwrap_or(m).to_string())
        }).collect();
        json!({
            "txt": dc::txt_ok(&txt, &token), "mx": dc::mx_ok(&mx_pairs, host), "spf": dc::spf_ok(&spf, host),
            "dkim": dc::dkim_ok(&dkim, &dkim_pub), "dmarc": dc::dmarc_ok(&dmarc)
        })
    };

    let auth = async {
        let (zone, ns) = zone_nameservers(&dom).await?;
        let (t, m, s, k, r) = tokio::join!(
            ask_authoritative(&ns, &n_txt, dc::T_TXT),
            ask_authoritative(&ns, &dom, dc::T_MX),
            ask_authoritative(&ns, &dom, dc::T_TXT),
            ask_authoritative(&ns, &n_dkim, dc::T_TXT),
            ask_authoritative(&ns, &n_dmarc, dc::T_TXT),
        );
        if t.1 + m.1 + s.1 + k.1 + r.1 == 0 {
            return None; // koi nameserver ne authoritative jawab nahi diya — public raasta
        }
        let mx: Vec<(u16, String)> = {
            let mut v: Vec<(u16, String)> = m.0.iter().flat_map(dc::mxs).collect();
            v.sort();
            v.dedup();
            v
        };
        let checks = json!({
            "txt": dc::txt_ok(&uniq_txt(&t.0, &n_txt), &token),
            "mx": dc::mx_ok(&mx, host),
            "spf": dc::spf_ok(&uniq_txt(&s.0, &dom), host),
            "dkim": dc::dkim_ok(&uniq_txt(&k.0, &n_dkim), &dkim_pub),
            "dmarc": dc::dmarc_ok(&uniq_txt(&r.0, &n_dmarc)),
        });
        let names: Vec<String> = ns.iter().map(|(n, _)| n.clone()).collect();
        Some((zone, names, checks))
    };

    let (public, auth) = tokio::join!(public, auth);
    let (source, zone, nameservers, checks) = match auth {
        Some((zone, names, checks)) => ("authoritative", Value::String(zone), json!(names), checks),
        None => ("public", Value::Null, json!([]), public.clone()),
    };
    let b = |k: &str| checks.get(k).and_then(|v| v.as_bool()).unwrap_or(false);
    let saved = crate::sb_rpc(
        "org_domain_set_checks",
        json!({ "_id": id, "_txt": b("txt"), "_mx": b("mx"), "_spf": b("spf"), "_dkim": b("dkim"), "_dmarc": b("dmarc") }),
    )
    .await?;
    let mut domain = saved.get("domain").cloned().unwrap_or(Value::Null);
    if domain.is_object() {
        let rec = crate::dns_records(&domain);
        domain["records"] = rec;
    }
    Ok(json!({
        "ok": saved.get("ok").and_then(|v| v.as_bool()).unwrap_or(false),
        "ready": domain.get("status").and_then(|v| v.as_str()) == Some("verified"),
        "checks": checks,
        "domain": domain,
        "source": source,
        "zone": zone,
        "nameservers": nameservers,
        "public": public,
        "checked_at": crate::locale_core::now_rfc3339(),
    }))
}
