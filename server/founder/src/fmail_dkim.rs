//! Q1d (founder mailbox): DKIM signing (RFC 6376, relaxed/relaxed) with Ed25519-SHA256 (RFC 8463) and RSA-SHA256, plus key generation and the sealed key wrap.
//! INHERITABLE BY AWAM (docs/claude/AWAM-INHERITS-FOUNDER-TECH-LAW-13NOV.md): no network, no database, no founder names.
//! Technology: Rust, ring (Ed25519 + RSA PKCS#1 v1.5 signing, SHA-256), the `rsa` crate ONLY to generate an RSA-2048 key (ring cannot generate RSA); signing is always ring.
//! Why both algorithms: Ed25519 is the modern signature (RFC 8463) but several big receivers still verify only RSA, so every mail carries both signatures (RFC 6376 section 3.5 allows several).
//! Private keys never leave this process in plain: they are stored AES-256-GCM sealed under a key derived from the vault master (aad = tag | mailbox | selector | alg).
use crate::fmail_seal as seal;
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use ring::{rand::SystemRandom, signature::{Ed25519KeyPair, KeyPair, RsaKeyPair, RSA_PKCS1_SHA256}};
use sha2::{Digest, Sha256};

pub const ALG_ED: &str = "ed25519-sha256";
pub const ALG_RSA: &str = "rsa-sha256";
/// The headers that are signed when present (From is mandatory). Nothing is over-signed.
pub const SIGNED: [&str; 11] = ["from", "to", "cc", "subject", "date", "message-id", "in-reply-to", "references", "mime-version", "content-type", "content-transfer-encoding"];

// ---------------------------------------------------------------- canonicalization (relaxed)

/// Relaxed body: trailing white space of each line cut, runs of white space folded to one space, trailing empty lines removed, CRLF line ends, ends with exactly one CRLF (or is empty).
pub fn body_relaxed(body: &[u8]) -> Vec<u8> {
    let text = String::from_utf8_lossy(body);
    let mut lines: Vec<String> = Vec::new();
    for l in text.split('\n') {
        let l = l.strip_suffix('\r').unwrap_or(l);
        let mut out = String::with_capacity(l.len());
        let mut sp = false;
        for c in l.chars() { if c == ' ' || c == '\t' { sp = true; } else { if sp { out.push(' '); sp = false; } out.push(c); } }
        lines.push(out);   // a pending trailing space run is dropped (trailing WSP cut)
    }
    while lines.last().map_or(false, |l| l.is_empty()) { lines.pop(); }
    if lines.is_empty() { return Vec::new(); }
    let mut v = lines.join("\r\n").into_bytes(); v.extend_from_slice(b"\r\n"); v
}
pub fn body_hash_b64(body: &[u8]) -> String { B64.encode(Sha256::digest(body_relaxed(body))) }

/// Relaxed header: lower-case name, unfolded, white space runs folded, trimmed; `name:value` + CRLF (the CRLF is left to the caller for the signature header itself).
pub fn header_relaxed(name: &str, value: &str) -> String {
    let unfolded = value.replace("\r\n", "").replace('\n', "").replace('\r', "");
    let mut v = String::new(); let mut sp = false;
    for c in unfolded.chars() { if c == ' ' || c == '\t' { sp = true; } else { if sp && !v.is_empty() { v.push(' '); } sp = false; v.push(c); } }
    format!("{}:{}", name.to_ascii_lowercase(), v.trim())
}

/// Split a raw message into its header fields (name, raw unfolded-able value without the leading colon) and the body. Header end = first empty line.
pub fn split_message(raw: &[u8]) -> (Vec<(String, String)>, &[u8]) {
    let (head, body) = match find2(raw, b"\r\n\r\n") { Some(i) => (&raw[..i], &raw[i + 4..]), None => match find2(raw, b"\n\n") { Some(i) => (&raw[..i], &raw[i + 2..]), None => (raw, &raw[raw.len()..]) } };
    let head = String::from_utf8_lossy(head).into_owned();
    let mut fields: Vec<(String, String)> = Vec::new();
    for line in head.split('\n') {
        let line = line.strip_suffix('\r').unwrap_or(line);
        if (line.starts_with(' ') || line.starts_with('\t')) && !fields.is_empty() { let l = fields.last_mut().unwrap(); l.1.push_str("\r\n"); l.1.push_str(line); }
        else if let Some((n, v)) = line.split_once(':') { fields.push((n.trim().to_string(), v.to_string())); }
    }
    (fields, body)
}
fn find2(h: &[u8], n: &[u8]) -> Option<usize> { h.windows(n.len()).position(|w| w == n) }

// ---------------------------------------------------------------- keys

pub struct NewKey { pub alg: &'static str, pub pkcs8: Vec<u8>, pub public: Vec<u8> }
/// Ed25519: `public` = the 32 raw bytes (what the DNS record carries).
pub fn gen_ed25519() -> Result<NewKey, &'static str> {
    let rng = SystemRandom::new();
    let doc = Ed25519KeyPair::generate_pkcs8(&rng).map_err(|_| "key generation failed")?;
    let kp = Ed25519KeyPair::from_pkcs8(doc.as_ref()).map_err(|_| "key generation failed")?;
    Ok(NewKey { alg: ALG_ED, pkcs8: doc.as_ref().to_vec(), public: kp.public_key().as_ref().to_vec() })
}
/// RSA-2048: `public` = DER SubjectPublicKeyInfo (what the DNS record carries). The key is generated with the OS random source.
pub fn gen_rsa(bits: usize) -> Result<NewKey, &'static str> {
    use rsa::pkcs8::{EncodePrivateKey, EncodePublicKey};
    if !(2048..=4096).contains(&bits) { return Err("RSA key size must be 2048..4096"); }
    let sk = rsa::RsaPrivateKey::new(&mut rand_core::OsRng, bits).map_err(|_| "key generation failed")?;
    let pkcs8 = sk.to_pkcs8_der().map_err(|_| "key encoding failed")?.as_bytes().to_vec();
    let public = rsa::RsaPublicKey::from(&sk).to_public_key_der().map_err(|_| "key encoding failed")?.as_bytes().to_vec();
    Ok(NewKey { alg: ALG_RSA, pkcs8, public })
}
/// The DNS TXT value for `<selector>._domainkey.<domain>`.
pub fn dns_txt(alg: &str, public: &[u8]) -> String { format!("v=DKIM1; k={}; p={}", if alg == ALG_ED { "ed25519" } else { "rsa" }, B64.encode(public)) }

fn wrap_key(master: &seal::Key, mailbox_id: &str) -> Result<seal::Key, &'static str> { seal::derive(master, "fmail-dkim-v1", mailbox_id) }
fn wrap_aad(mailbox_id: &str, selector: &str, alg: &str) -> Vec<u8> { seal::aad(&["fmail-dkim-v1", mailbox_id, selector, alg]) }
/// Seal a private key (PKCS#8) for storage. Returns (nonce, sealed).
pub fn wrap_private(master: &seal::Key, mailbox_id: &str, selector: &str, alg: &str, pkcs8: &[u8]) -> Result<([u8; 12], Vec<u8>), &'static str> {
    seal::seal(&wrap_key(master, mailbox_id)?, &wrap_aad(mailbox_id, selector, alg), pkcs8)
}
pub fn unwrap_private(master: &seal::Key, mailbox_id: &str, selector: &str, alg: &str, nonce: &[u8], sealed: &[u8]) -> Option<Vec<u8>> {
    seal::open(&wrap_key(master, mailbox_id).ok()?, nonce, &wrap_aad(mailbox_id, selector, alg), sealed)
}

// ---------------------------------------------------------------- signing

pub struct Signer<'a> { pub domain: &'a str, pub selector: &'a str, pub alg: &'a str, pub pkcs8: &'a [u8] }

fn fold_b(b: &str) -> String { b.as_bytes().chunks(70).map(|c| std::str::from_utf8(c).unwrap_or("")).collect::<Vec<_>>().join("\r\n\t") }

/// Build the `DKIM-Signature:` header line (with CRLF) for `raw` (a full message: headers, empty line, body). `now` is the signing time in unix seconds.
pub fn sign(raw: &[u8], s: &Signer, now: u64) -> Result<String, &'static str> {
    if s.alg != ALG_ED && s.alg != ALG_RSA { return Err("unknown DKIM algorithm"); }
    let (fields, body) = split_message(raw);
    if !fields.iter().any(|(n, _)| n.eq_ignore_ascii_case("from")) { return Err("a signed message needs a From header"); }
    let mut h_names: Vec<&str> = Vec::new();
    let mut canon = String::new();
    for want in SIGNED {
        // every instance of the header, bottom-up (RFC 6376 section 5.4.2): the last one is signed first
        let inst: Vec<&(String, String)> = fields.iter().filter(|(n, _)| n.eq_ignore_ascii_case(want)).collect();
        for f in inst.iter().rev() { canon.push_str(&header_relaxed(&f.0, &f.1)); canon.push_str("\r\n"); h_names.push(want); }
    }
    let bh = body_hash_b64(body);
    let head = format!("v=1; a={}; c=relaxed/relaxed; d={}; s={}; t={}; x={}; h={}; bh={}; b=", s.alg, s.domain, s.selector, now, now + 7 * 86400, h_names.join(":"), bh);
    let mut data = canon.into_bytes();
    data.extend_from_slice(header_relaxed("DKIM-Signature", &head).as_bytes());   // no trailing CRLF for the signature header itself
    let b = if s.alg == ALG_ED {
        let kp = Ed25519KeyPair::from_pkcs8(s.pkcs8).map_err(|_| "bad Ed25519 key")?;
        B64.encode(kp.sign(&Sha256::digest(&data)).as_ref())   // RFC 8463: the signature is over the SHA-256 digest of the canonical data
    } else {
        let kp = RsaKeyPair::from_pkcs8(s.pkcs8).map_err(|_| "bad RSA key")?;
        let mut sig = vec![0u8; kp.public().modulus_len()];
        kp.sign(&RSA_PKCS1_SHA256, &SystemRandom::new(), &data, &mut sig).map_err(|_| "RSA signing failed")?;
        B64.encode(sig)
    };
    Ok(format!("DKIM-Signature: {}{}\r\n", head.replace("; ", ";\r\n\t"), fold_b(&b)))
}

/// Verify one `DKIM-Signature` against a public key (used by the tests and by the self-check before a key is installed). Returns true only when body hash AND signature match.
pub fn verify(signed_raw: &[u8], alg: &str, public: &[u8]) -> bool {
    use ring::signature::{UnparsedPublicKey, ED25519, RSA_PKCS1_2048_8192_SHA256};
    let (fields, body) = split_message(signed_raw);
    let Some((sn, sv)) = fields.iter().find(|(n, v)| n.eq_ignore_ascii_case("dkim-signature") && v.contains(&format!("a={alg}"))) else { return false };
    let tags: std::collections::HashMap<String, String> = sv.replace("\r\n", "").split(';').filter_map(|t| t.split_once('=')).map(|(k, v)| (k.trim().to_string(), v.split_whitespace().collect::<String>())).collect();
    let (Some(bh), Some(b), Some(h)) = (tags.get("bh"), tags.get("b"), tags.get("h")) else { return false };
    if *bh != body_hash_b64(body) { return false; }
    let mut canon = String::new();
    let mut used: std::collections::HashMap<String, usize> = Default::default();
    for name in h.split(':') {
        let lname = name.to_ascii_lowercase();
        let inst: Vec<&(String, String)> = fields.iter().filter(|(n, _)| n.eq_ignore_ascii_case(&lname)).collect();
        let k = used.entry(lname).or_insert(0);
        if let Some(f) = inst.iter().rev().nth(*k) { canon.push_str(&header_relaxed(&f.0, &f.1)); canon.push_str("\r\n"); }
        *k += 1;
    }
    let stripped = {
        let full = sv.replace("\r\n", "");
        let i = full.rfind("b=").map(|i| i + 2).unwrap_or(full.len());
        full[..i].to_string()
    };
    let mut data = canon.into_bytes();
    data.extend_from_slice(header_relaxed(sn, &stripped).as_bytes());
    let Ok(sig) = B64.decode(b) else { return false };
    if alg == ALG_ED { UnparsedPublicKey::new(&ED25519, public).verify(&Sha256::digest(&data), &sig).is_ok() }
    else {
        // ring wants the RSAPublicKey (PKCS#1) inside the SPKI
        let Some(pk1) = spki_rsa_inner(public) else { return false };
        UnparsedPublicKey::new(&RSA_PKCS1_2048_8192_SHA256, pk1).verify(&data, &sig).is_ok()
    }
}
/// Strip the SubjectPublicKeyInfo wrapper: SEQUENCE { SEQUENCE alg, BIT STRING { 0x00, RSAPublicKey } }.
fn spki_rsa_inner(der: &[u8]) -> Option<&[u8]> {
    fn tlv(d: &[u8]) -> Option<(u8, &[u8], &[u8])> {
        let t = *d.first()?; let l0 = *d.get(1)? as usize;
        let (len, off) = if l0 < 0x80 { (l0, 2) } else { let n = l0 & 0x7f; if n == 0 || n > 3 { return None; } let mut l = 0usize; for i in 0..n { l = (l << 8) | *d.get(2 + i)? as usize; } (l, 2 + n) };
        let body = d.get(off..off + len)?; Some((t, body, &d[off + len..]))
    }
    let (_, seq, _) = tlv(der)?; let (_, _alg, rest) = tlv(seq)?; let (t, bits, _) = tlv(rest)?;
    if t != 0x03 || bits.first() != Some(&0) { return None; } Some(&bits[1..])
}

#[cfg(test)]
mod tests {
    use super::*;
    const MSG: &[u8] = b"From: Nauman <naumansherwani.founder@anexomail.com>\r\nTo: a@example.org\r\nSubject: Hello  world\r\nDate: Fri, 13 Nov 2026 03:00:00 +0000\r\nMessage-ID: <1@anexomail.com>\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nHi there  \r\n\r\nline two\t\r\n\r\n\r\n";

    #[test] fn relaxed_body_vectors() {
        assert_eq!(body_relaxed(b""), b"");
        assert_eq!(body_relaxed(b"\r\n"), b"");
        assert_eq!(body_relaxed(b"\r\n\r\n"), b"");
        assert_eq!(body_relaxed(b"Hi  there \t\r\n\r\n\r\n"), b"Hi there\r\n");
        assert_eq!(body_relaxed(b"a\nb"), b"a\r\nb\r\n");
        assert_eq!(body_relaxed(b"a\r\n\r\nb\r\n"), b"a\r\n\r\nb\r\n");
        // sha256 of the empty string, the value every DKIM tool prints for an empty relaxed body
        assert_eq!(body_hash_b64(b"\r\n"), "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=");
    }
    #[test] fn relaxed_header_vectors() {
        assert_eq!(header_relaxed("Subject", " A  B\r\n\t C  "), "subject:A B C");
        assert_eq!(header_relaxed("X-Y", "v"), "x-y:v");
    }
    #[test] fn split_keeps_folded_values() {
        let (f, b) = split_message(b"A: 1\r\n 2\r\nB: x\r\n\r\nbody\r\n");
        assert_eq!(f.len(), 2); assert!(f[0].1.contains("\r\n 2")); assert_eq!(b, b"body\r\n");
    }
    #[test] fn ed25519_sign_verify_and_tamper() {
        let k = gen_ed25519().unwrap();
        let sig = sign(MSG, &Signer { domain: "anexomail.com", selector: "s1", alg: ALG_ED, pkcs8: &k.pkcs8 }, 1_800_000_000).unwrap();
        assert!(sig.starts_with("DKIM-Signature: v=1;")); assert!(sig.contains("a=ed25519-sha256")); assert!(sig.contains("h=from:to:subject:date:message-id:mime-version:content-type"));
        let mut signed = sig.clone().into_bytes(); signed.extend_from_slice(MSG);
        assert!(verify(&signed, ALG_ED, &k.public));
        let t = String::from_utf8(signed.clone()).unwrap().replace("Hello  world", "Hello world!");
        assert!(!verify(t.as_bytes(), ALG_ED, &k.public), "a changed header must break the signature");
        let t = String::from_utf8(signed.clone()).unwrap().replace("line two", "line 2");
        assert!(!verify(t.as_bytes(), ALG_ED, &k.public), "a changed body must break the signature");
        let other = gen_ed25519().unwrap();
        assert!(!verify(&signed, ALG_ED, &other.public), "another key must not verify");
    }
    #[test] fn rsa_sign_verify() {
        let k = gen_rsa(2048).unwrap();
        let sig = sign(MSG, &Signer { domain: "anexomail.com", selector: "r1", alg: ALG_RSA, pkcs8: &k.pkcs8 }, 1_800_000_000).unwrap();
        let mut signed = sig.into_bytes(); signed.extend_from_slice(MSG);
        assert!(verify(&signed, ALG_RSA, &k.public));
        assert!(!verify(String::from_utf8(signed).unwrap().replace("Hi there", "Hi you").as_bytes(), ALG_RSA, &k.public));
    }
    #[test] fn two_signatures_both_verify() {
        let (e, r) = (gen_ed25519().unwrap(), gen_rsa(2048).unwrap());
        let mut m = Vec::new();
        for (k, s) in [(&e, "e1"), (&r, "r1")] { m.extend_from_slice(sign(MSG, &Signer { domain: "anexomail.com", selector: s, alg: k.alg, pkcs8: &k.pkcs8 }, 1_800_000_000).unwrap().as_bytes()); }
        m.extend_from_slice(MSG);
        assert!(verify(&m, ALG_ED, &e.public) && verify(&m, ALG_RSA, &r.public));
    }
    #[test] fn refuses_without_from_and_unknown_alg() {
        let k = gen_ed25519().unwrap();
        assert!(sign(b"To: a@b.c\r\n\r\nx\r\n", &Signer { domain: "d.com", selector: "s", alg: ALG_ED, pkcs8: &k.pkcs8 }, 1).is_err());
        assert!(sign(MSG, &Signer { domain: "d.com", selector: "s", alg: "md5", pkcs8: &k.pkcs8 }, 1).is_err());
        assert!(gen_rsa(1024).is_err());
    }
    #[test] fn dns_value_and_key_wrap_round_trip() {
        let k = gen_ed25519().unwrap();
        let t = dns_txt(ALG_ED, &k.public); assert!(t.starts_with("v=DKIM1; k=ed25519; p=")); assert_eq!(B64.decode(t.rsplit("p=").next().unwrap()).unwrap(), k.public);
        let master = [7u8; 32];
        let (n, ct) = wrap_private(&master, "mb", "s1", ALG_ED, &k.pkcs8).unwrap();
        assert!(!ct.windows(16).any(|w| k.pkcs8.windows(16).any(|x| x == w)), "the wrapped key must not contain the plain key");
        assert_eq!(unwrap_private(&master, "mb", "s1", ALG_ED, &n, &ct).unwrap(), k.pkcs8);
        assert!(unwrap_private(&master, "mb", "s2", ALG_ED, &n, &ct).is_none(), "another selector must not open it");
        assert!(unwrap_private(&master, "other", "s1", ALG_ED, &n, &ct).is_none(), "another mailbox must not open it");
        assert!(unwrap_private(&[8u8; 32], "mb", "s1", ALG_ED, &n, &ct).is_none(), "another master must not open it");
    }
}
