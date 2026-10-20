// ============================================================================
// dnsauth_core.rs — D2 "Authoritative-NS live check" ka pure hissa (founder HAAN 20 Oct 2026, Domains list #1).
//
// Google/Zoho domain verify public resolver (8.8.8.8 / 1.1.1.1) ke cache se karte hain — user record lagata hai, phir ghanton
// "Verify" dabata rehta hai. Hum seedha domain ke APNE nameservers (Cloudflare / Namecheap / GoDaddy ke authoritative servers)
// se poochte hain, cache ke baghair (RD=0): jaise hi registrar record publish kare, ANEXOMAIL ko pata chal jata hai.
//
// Yahan sirf DNS ka wire format (RFC 1035 + EDNS0 RFC 6891): query banana, jawab padhna (name compression, TXT ke kai
// tukde, MX, CNAME, NS, A), aur "record theek hai?" ke faisle. Koi network nahi — std-only, `rustc --edition 2024 --test`.
// Network (UDP/TCP, timeouts, kis server se poochhna) `dnsauth_glue.rs` mein.
// ============================================================================

pub const T_A: u16 = 1;
pub const T_NS: u16 = 2;
pub const T_CNAME: u16 = 5;
pub const T_MX: u16 = 15;
pub const T_TXT: u16 = 16;
const T_OPT: u16 = 41;

#[derive(Debug, Clone, PartialEq)]
pub enum Data {
    A([u8; 4]),
    Ns(String),
    Cname(String),
    Mx(u16, String),
    Txt(String),
    Other,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Rr {
    pub name: String,
    pub rtype: u16,
    pub ttl: u32,
    pub data: Data,
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct Reply {
    pub id: u16,
    pub rcode: u8,
    pub authoritative: bool,
    pub truncated: bool,
    pub answers: Vec<Rr>,
    pub authority: Vec<Rr>,
    pub additional: Vec<Rr>,
}

/// Domain jaisa naam? (sirf a-z 0-9 - . _ ; har label 1..=63; kul <= 253; kam se kam 2 label). Lower-case wapas.
pub fn clean_domain(s: &str) -> Option<String> {
    let d = s.trim().trim_end_matches('.').to_ascii_lowercase();
    if d.is_empty() || d.len() > 253 || !d.contains('.') {
        return None;
    }
    for l in d.split('.') {
        if l.is_empty() || l.len() > 63 || l.starts_with('-') || l.ends_with('-') {
            return None;
        }
        if !l.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-' || b == b'_') {
            return None;
        }
    }
    Some(d)
}

/// Query packet. `recurse` = RD bit (resolver ko true, authoritative ko false). EDNS0 OPT (4096 byte UDP) taake lambi DKIM TXT
/// ek hi jawab mein aa jaye.
pub fn build_query(id: u16, name: &str, qtype: u16, recurse: bool) -> Vec<u8> {
    let mut p = Vec::with_capacity(64 + name.len());
    p.extend_from_slice(&id.to_be_bytes());
    p.extend_from_slice(&(if recurse { 0x0100u16 } else { 0 }).to_be_bytes());
    p.extend_from_slice(&1u16.to_be_bytes()); // QDCOUNT
    p.extend_from_slice(&0u16.to_be_bytes()); // ANCOUNT
    p.extend_from_slice(&0u16.to_be_bytes()); // NSCOUNT
    p.extend_from_slice(&1u16.to_be_bytes()); // ARCOUNT (OPT)
    for l in name.trim_end_matches('.').split('.') {
        if l.is_empty() {
            continue;
        }
        p.push(l.len().min(63) as u8);
        p.extend_from_slice(&l.as_bytes()[..l.len().min(63)]);
    }
    p.push(0);
    p.extend_from_slice(&qtype.to_be_bytes());
    p.extend_from_slice(&1u16.to_be_bytes()); // IN
    // OPT: root name, type 41, class = UDP payload size, ttl 0, rdlen 0
    p.push(0);
    p.extend_from_slice(&T_OPT.to_be_bytes());
    p.extend_from_slice(&4096u16.to_be_bytes());
    p.extend_from_slice(&0u32.to_be_bytes());
    p.extend_from_slice(&0u16.to_be_bytes());
    p
}

fn u16_at(b: &[u8], i: usize) -> Option<u16> {
    Some(u16::from_be_bytes([*b.get(i)?, *b.get(i + 1)?]))
}

fn u32_at(b: &[u8], i: usize) -> Option<u32> {
    Some(u32::from_be_bytes([*b.get(i)?, *b.get(i + 1)?, *b.get(i + 2)?, *b.get(i + 3)?]))
}

/// Naam padhna (compression pointers ke saath, loop se mehfooz). Wapas: (naam, agla offset).
fn read_name(b: &[u8], mut i: usize) -> Option<(String, usize)> {
    let mut labels: Vec<String> = Vec::new();
    let mut end: Option<usize> = None;
    let mut jumps = 0;
    loop {
        let len = *b.get(i)? as usize;
        if len & 0xC0 == 0xC0 {
            let ptr = ((len & 0x3F) << 8) | *b.get(i + 1)? as usize;
            if end.is_none() {
                end = Some(i + 2);
            }
            jumps += 1;
            if jumps > 32 || ptr >= b.len() {
                return None;
            }
            i = ptr;
            continue;
        }
        if len & 0xC0 != 0 {
            return None;
        }
        if len == 0 {
            let next = end.unwrap_or(i + 1);
            return Some((labels.join(".").to_ascii_lowercase(), next));
        }
        let lab = b.get(i + 1..i + 1 + len)?;
        labels.push(String::from_utf8_lossy(lab).into_owned());
        if labels.len() > 127 {
            return None;
        }
        i += 1 + len;
    }
}

fn read_rr(b: &[u8], i: usize) -> Option<(Rr, usize)> {
    let (name, j) = read_name(b, i)?;
    let rtype = u16_at(b, j)?;
    let ttl = u32_at(b, j + 4)?;
    let rdlen = u16_at(b, j + 8)? as usize;
    let rd = j + 10;
    let rd_end = rd.checked_add(rdlen)?;
    if rd_end > b.len() {
        return None;
    }
    let data = match rtype {
        T_A if rdlen == 4 => Data::A([b[rd], b[rd + 1], b[rd + 2], b[rd + 3]]),
        T_NS => Data::Ns(read_name(b, rd)?.0),
        T_CNAME => Data::Cname(read_name(b, rd)?.0),
        T_MX => Data::Mx(u16_at(b, rd)?, read_name(b, rd + 2)?.0),
        T_TXT => {
            // TXT = kai <len><bytes> tukde; DKIM ki lambi key 255 se bade hisson mein aati hai — jod kar ek string.
            let mut s = String::new();
            let mut k = rd;
            while k < rd_end {
                let l = b[k] as usize;
                let part = b.get(k + 1..(k + 1 + l).min(rd_end))?;
                s.push_str(&String::from_utf8_lossy(part));
                k += 1 + l;
            }
            Data::Txt(s)
        }
        _ => Data::Other,
    };
    Some((Rr { name, rtype, ttl, data }, rd_end))
}

/// Jawab padhna. Kharab / chhota packet => None (kabhi panic nahi).
pub fn parse_reply(b: &[u8]) -> Option<Reply> {
    if b.len() < 12 {
        return None;
    }
    let id = u16_at(b, 0)?;
    let flags = u16_at(b, 2)?;
    let qd = u16_at(b, 4)? as usize;
    let an = u16_at(b, 6)? as usize;
    let ns = u16_at(b, 8)? as usize;
    let ar = u16_at(b, 10)? as usize;
    if flags & 0x8000 == 0 {
        return None; // QR=0: yeh jawab nahi
    }
    let mut i = 12;
    for _ in 0..qd {
        let (_, j) = read_name(b, i)?;
        i = j + 4;
    }
    let mut out = Reply {
        id,
        rcode: (flags & 0x000F) as u8,
        authoritative: flags & 0x0400 != 0,
        truncated: flags & 0x0200 != 0,
        ..Default::default()
    };
    for (count, which) in [(an, 0), (ns, 1), (ar, 2)] {
        for _ in 0..count.min(512) {
            let Some((rr, j)) = read_rr(b, i) else { return Some(out) };
            i = j;
            match which {
                0 => out.answers.push(rr),
                1 => out.authority.push(rr),
                _ => out.additional.push(rr),
            }
        }
    }
    Some(out)
}

/// `a.b.example.co.uk` -> ["a.b.example.co.uk", "b.example.co.uk", "example.co.uk", "co.uk"] — zone dhoondne ke liye
/// (har ek par NS poochho, pehla jis par NS mile wahi zone; TLD tak nahi jaate).
pub fn zone_candidates(domain: &str) -> Vec<String> {
    let labels: Vec<&str> = domain.split('.').collect();
    (0..labels.len().saturating_sub(1)).map(|i| labels[i..].join(".")).collect()
}

pub fn txts(r: &Reply, name: &str) -> Vec<String> {
    r.answers
        .iter()
        .filter(|x| x.name == name)
        .filter_map(|x| match &x.data {
            Data::Txt(t) => Some(t.clone()),
            _ => None,
        })
        .collect()
}

pub fn mxs(r: &Reply) -> Vec<(u16, String)> {
    r.answers
        .iter()
        .filter_map(|x| match &x.data {
            Data::Mx(p, h) => Some((*p, h.clone())),
            _ => None,
        })
        .collect()
}

#[allow(dead_code)] // tests + aage (NS badla? health guard #6)
pub fn ns_names(r: &Reply) -> Vec<String> {
    r.answers
        .iter()
        .chain(r.authority.iter())
        .filter_map(|x| match &x.data {
            Data::Ns(h) => Some(h.trim_end_matches('.').to_string()),
            _ => None,
        })
        .collect()
}

pub fn a_records(r: &Reply, name: &str) -> Vec<[u8; 4]> {
    r.answers
        .iter()
        .chain(r.additional.iter())
        .filter(|x| x.name == name)
        .filter_map(|x| match &x.data {
            Data::A(a) => Some(*a),
            _ => None,
        })
        .collect()
}

/* ---- faisle: wohi qawaid jo `mail_domain_verify` (main.rs) public DoH ke saath lagata tha ---- */

pub fn txt_ok(values: &[String], token: &str) -> bool {
    !token.is_empty() && values.iter().any(|t| t.trim() == token)
}

pub fn mx_ok(values: &[(u16, String)], mail_host: &str) -> bool {
    values.iter().any(|(_, h)| h.trim().trim_end_matches('.').to_ascii_lowercase().ends_with(mail_host))
}

pub fn spf_ok(values: &[String], mail_host: &str) -> bool {
    values.iter().any(|t| {
        let l = t.to_ascii_lowercase();
        l.starts_with("v=spf1") && l.contains(mail_host)
    })
}

pub fn dkim_ok(values: &[String], dkim_pub: &str) -> bool {
    let key: String = dkim_pub.split_whitespace().collect();
    key.len() >= 40
        && key.is_ascii()
        && values.iter().any(|t| {
            let c: String = t.split_whitespace().collect();
            c.contains("p=") && c.contains(&key[..40])
        })
}

pub fn dmarc_ok(values: &[String]) -> bool {
    values.iter().any(|t| t.trim().to_ascii_uppercase().starts_with("V=DMARC1"))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// test ke liye jawab banana (asli server jaisa: question + answers, compression pointer ke saath)
    fn reply_with(id: u16, qname: &str, qtype: u16, answers: &[(u16, Vec<u8>)], aa: bool) -> Vec<u8> {
        let mut p = Vec::new();
        p.extend_from_slice(&id.to_be_bytes());
        p.extend_from_slice(&(0x8000u16 | if aa { 0x0400 } else { 0 }).to_be_bytes());
        p.extend_from_slice(&1u16.to_be_bytes());
        p.extend_from_slice(&(answers.len() as u16).to_be_bytes());
        p.extend_from_slice(&0u16.to_be_bytes());
        p.extend_from_slice(&0u16.to_be_bytes());
        for l in qname.split('.') {
            p.push(l.len() as u8);
            p.extend_from_slice(l.as_bytes());
        }
        p.push(0);
        p.extend_from_slice(&qtype.to_be_bytes());
        p.extend_from_slice(&1u16.to_be_bytes());
        for (t, rdata) in answers {
            p.extend_from_slice(&[0xC0, 12]); // pointer -> question name
            p.extend_from_slice(&t.to_be_bytes());
            p.extend_from_slice(&1u16.to_be_bytes());
            p.extend_from_slice(&300u32.to_be_bytes());
            p.extend_from_slice(&(rdata.len() as u16).to_be_bytes());
            p.extend_from_slice(rdata);
        }
        p
    }

    fn name_wire(n: &str) -> Vec<u8> {
        let mut v = Vec::new();
        for l in n.split('.') {
            v.push(l.len() as u8);
            v.extend_from_slice(l.as_bytes());
        }
        v.push(0);
        v
    }

    #[test]
    fn query_shape() {
        let q = build_query(0xBEEF, "_dmarc.Acme.co.uk", T_TXT, false);
        assert_eq!(&q[0..2], &[0xBE, 0xEF]);
        assert_eq!(&q[2..4], &[0, 0]); // RD=0 (authoritative)
        assert_eq!(&q[4..6], &[0, 1]);
        assert_eq!(&q[10..12], &[0, 1]); // OPT
        let q2 = build_query(1, "x.com", T_NS, true);
        assert_eq!(&q2[2..4], &[1, 0]); // RD=1
        assert!(q.ends_with(&[0, 0, 41, 0x10, 0, 0, 0, 0, 0, 0, 0]));
    }

    #[test]
    fn txt_split_strings_join() {
        let mut rd = Vec::new();
        let a = "v=DKIM1; k=rsa; p=".to_string() + &"A".repeat(230); // har TXT tukda <= 255 byte
        let b = "B".repeat(150);
        rd.push(a.len() as u8);
        rd.extend_from_slice(a.as_bytes());
        rd.push(b.len() as u8);
        rd.extend_from_slice(b.as_bytes());
        let pkt = reply_with(7, "anexo1._domainkey.acme.co.uk", T_TXT, &[(T_TXT, rd)], true);
        let r = parse_reply(&pkt).unwrap();
        assert!(r.authoritative && !r.truncated && r.rcode == 0 && r.id == 7);
        let t = txts(&r, "anexo1._domainkey.acme.co.uk");
        assert_eq!(t.len(), 1);
        assert_eq!(t[0], format!("{a}{b}"));
        assert!(dkim_ok(&t, &("A".repeat(60))));
        assert!(!dkim_ok(&t, &("C".repeat(60))));
    }

    #[test]
    fn mx_and_ns_with_compression() {
        let mut mx = vec![0, 10];
        mx.extend_from_slice(&name_wire("mail.anexomail.com"));
        let pkt = reply_with(9, "acme.co.uk", T_MX, &[(T_MX, mx)], true);
        let r = parse_reply(&pkt).unwrap();
        let m = mxs(&r);
        assert_eq!(m, vec![(10, "mail.anexomail.com".to_string())]);
        assert!(mx_ok(&m, "mail.anexomail.com"));
        assert!(!mx_ok(&[(10, "aspmx.l.google.com".into())], "mail.anexomail.com"));
        // NS rdata that points back into the packet (compression)
        let ns_rd = vec![3, b'n', b's', b'1', 0xC0, 12];
        let pkt = reply_with(3, "acme.co.uk", T_NS, &[(T_NS, ns_rd)], false);
        let r = parse_reply(&pkt).unwrap();
        assert_eq!(ns_names(&r), vec!["ns1.acme.co.uk".to_string()]);
    }

    #[test]
    fn hostile_packets_never_panic() {
        assert!(parse_reply(&[]).is_none());
        assert!(parse_reply(&[0; 11]).is_none());
        let mut loopy = reply_with(1, "a.com", T_A, &[], false);
        loopy[12] = 0xC0;
        loopy[13] = 12; // name points to itself
        assert!(parse_reply(&loopy).is_none());
        // answer count says 5 but nothing there
        let mut short = reply_with(1, "a.com", T_A, &[], false);
        short[7] = 5;
        let r = parse_reply(&short).unwrap();
        assert!(r.answers.is_empty());
        // random bytes
        for seed in 0..200u32 {
            let v: Vec<u8> = (0..(seed % 97 + 12)).map(|i| ((i * 31 + seed * 17) % 251) as u8 | 0x80).collect();
            let _ = parse_reply(&v);
        }
    }

    #[test]
    fn domain_rules_and_zones() {
        assert_eq!(clean_domain(" Acme.CO.uk. ").as_deref(), Some("acme.co.uk"));
        assert!(clean_domain("localhost").is_none());
        assert!(clean_domain("a..b.com").is_none());
        assert!(clean_domain("-a.com").is_none());
        assert!(clean_domain("a b.com").is_none());
        assert_eq!(zone_candidates("mail.acme.co.uk"), vec!["mail.acme.co.uk", "acme.co.uk", "co.uk"]);
        assert_eq!(zone_candidates("acme.com"), vec!["acme.com"]);
    }

    #[test]
    fn decision_rules_match_public_check() {
        assert!(txt_ok(&["tok123".into()], "tok123"));
        assert!(!txt_ok(&["tok123".into()], ""));
        assert!(spf_ok(&["v=spf1 a:mail.anexomail.com ~all".into()], "mail.anexomail.com"));
        assert!(!spf_ok(&["v=spf1 include:_spf.google.com ~all".into()], "mail.anexomail.com"));
        assert!(dmarc_ok(&[" v=DMARC1; p=none".into()]));
        assert!(!dmarc_ok(&["v=spf1".into()]));
    }
}
