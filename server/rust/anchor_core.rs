//! `anchor_core` (module `anchor@1` of the kernel) — G5c: account-free OUTSIDE TIME ANCHORS for the signed checkpoints.
//! Two independent routes, both free and without any account:  RFC 3161 (a public Time-Stamp Authority signs digest + time)  and  OpenTimestamps (public calendars -> a Bitcoin block).
//! One source for two users (Rule 52): the founder server (builds requests, parses replies, verifies signatures with ring) and the browser kernel (re-derives digest binding / commitment chain). Pure: no I/O, no clock, no ring.
//! The public-key signature check is NOT in this file: `parse_tsr` returns the exact bytes + algorithm + key, and the server checks them with ring (the kernel has no RSA/ECDSA crate).
//! Oracles: real RFC 3161 replies made by OpenSSL (`docs/cursor-work/server/g5c-oracle/`); OpenTimestamps vectors are built from the published format (no reference implementation available offline: stated in the docs).
use sha2::{Digest, Sha256};

pub fn to_hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }
pub fn from_hex(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 { return None; }
    let n = |c: u8| match c { b'0'..=b'9' => Some(c - b'0'), b'a'..=b'f' => Some(c - b'a' + 10), _ => None };
    s.as_bytes().chunks(2).map(|c| Some(n(c[0])? << 4 | n(c[1])?)).collect()
}
pub fn sha256(b: &[u8]) -> [u8; 32] { Sha256::digest(b).into() }

// =============================================================== OpenTimestamps
pub const OTS_MAGIC: &[u8] = b"\x00OpenTimestamps\x00\x00Proof\x00\xbf\x89\xe2\xe8\x84\xe8\x92\x94";
const TAG_PENDING: [u8; 8] = [0x83, 0xdf, 0xe3, 0x0d, 0x2e, 0xf9, 0x0c, 0x8e];
const TAG_BITCOIN: [u8; 8] = [0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01];
pub const MAX_MSG: usize = 4096;       // OpenTimestamps Op.MAX_MSG_LENGTH (also the longest commitment a calendar may use)
const MAX_DEPTH: usize = 64;
const MAX_ITEMS: usize = 4000;
const MAX_VARBYTES: usize = 1 << 20;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Att { Pending(String), Bitcoin(u64), Other([u8; 8]) }
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Op { Sha256, Append(Vec<u8>), Prepend(Vec<u8>), Reverse, Hexlify }
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Item { Att(Att), Op(Op, Node) }
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Node { pub items: Vec<Item> }
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Leaf { pub commit: Vec<u8>, pub att: Att }

struct R<'a> { b: &'a [u8], i: usize, items: usize }
impl<'a> R<'a> {
    fn byte(&mut self) -> Result<u8, &'static str> { let x = *self.b.get(self.i).ok_or("proof ends early")?; self.i += 1; Ok(x) }
    fn take(&mut self, n: usize) -> Result<&'a [u8], &'static str> { let e = self.i.checked_add(n).ok_or("length overflow")?; let s = self.b.get(self.i..e).ok_or("proof ends early")?; self.i = e; Ok(s) }
    fn varuint(&mut self) -> Result<u64, &'static str> {
        let (mut v, mut shift) = (0u64, 0u32);
        loop { let c = self.byte()?; if shift > 56 && (c & 0x7f) as u64 > (u64::MAX >> shift) { return Err("varuint too large"); } v |= ((c & 0x7f) as u64) << shift; if c & 0x80 == 0 { return Ok(v); } shift += 7; if shift > 63 { return Err("varuint too long"); } }
    }
    fn varbytes(&mut self, max: usize) -> Result<&'a [u8], &'static str> { let n = self.varuint()?; if n > max as u64 { return Err("field too long"); } self.take(n as usize) }
}

fn uri_ok(u: &str) -> bool { !u.is_empty() && u.len() <= 1000 && u.bytes().all(|c| c.is_ascii_alphanumeric() || b".-_/:".contains(&c)) }

fn read_attestation(r: &mut R) -> Result<Att, &'static str> {
    let tag: [u8; 8] = r.take(8)?.try_into().unwrap();
    let payload = r.varbytes(MAX_VARBYTES)?;
    let mut p = R { b: payload, i: 0, items: 0 };
    let a = if tag == TAG_PENDING {
        let u = p.varbytes(1000)?;
        let u = std::str::from_utf8(u).map_err(|_| "calendar address is not text")?;
        if !uri_ok(u) { return Err("calendar address has forbidden characters"); }
        Att::Pending(u.to_string())
    } else if tag == TAG_BITCOIN { Att::Bitcoin(p.varuint()?) } else { return Ok(Att::Other(tag)); };
    if p.i != payload.len() { return Err("trailing bytes inside an attestation"); }
    Ok(a)
}

fn read_item(r: &mut R, tag: u8, depth: usize) -> Result<Item, &'static str> {
    r.items += 1;
    if r.items > MAX_ITEMS { return Err("proof has too many steps"); }
    if tag == 0x00 { return Ok(Item::Att(read_attestation(r)?)); }
    let op = match tag {
        0x08 => Op::Sha256,
        0xf0 => Op::Append(r.varbytes(MAX_MSG)?.to_vec()),
        0xf1 => Op::Prepend(r.varbytes(MAX_MSG)?.to_vec()),
        0xf2 => Op::Reverse,
        0xf3 => Op::Hexlify,
        0x02 | 0x03 | 0x67 => return Err("proof uses a hash this checker does not support (sha1 / ripemd160 / keccak)"),
        _ => return Err("unknown operation in the proof"),
    };
    Ok(Item::Op(op, read_node(r, depth + 1)?))
}

fn read_node(r: &mut R, depth: usize) -> Result<Node, &'static str> {
    if depth > MAX_DEPTH { return Err("proof is nested too deeply"); }
    let mut items = Vec::new();
    let mut tag = r.byte()?;
    while tag == 0xff { let t = r.byte()?; items.push(read_item(r, t, depth)?); tag = r.byte()?; }
    items.push(read_item(r, tag, depth)?);
    Ok(Node { items })
}

/// Parse a serialized OpenTimestamps Timestamp (what a calendar returns for a digest, and what an upgrade returns). Must consume every byte.
pub fn parse_timestamp(b: &[u8]) -> Result<Node, &'static str> {
    if b.is_empty() || b.len() > MAX_VARBYTES { return Err("empty or oversized proof"); }
    let mut r = R { b, i: 0, items: 0 };
    let n = read_node(&mut r, 0)?;
    if r.i != b.len() { return Err("trailing bytes after the proof"); }
    Ok(n)
}

pub fn serialize_timestamp(n: &Node) -> Vec<u8> { let mut o = Vec::new(); ser_node(n, &mut o); o }
fn put_varuint(o: &mut Vec<u8>, mut v: u64) { loop { let c = (v & 0x7f) as u8; v >>= 7; if v == 0 { o.push(c); return; } o.push(c | 0x80); } }
fn put_varbytes(o: &mut Vec<u8>, b: &[u8]) { put_varuint(o, b.len() as u64); o.extend_from_slice(b); }
fn ser_node(n: &Node, o: &mut Vec<u8>) {
    for (k, it) in n.items.iter().enumerate() {
        if k + 1 < n.items.len() { o.push(0xff); }
        match it {
            Item::Att(a) => {
                o.push(0x00);
                let mut p = Vec::new();
                let tag = match a { Att::Pending(u) => { put_varbytes(&mut p, u.as_bytes()); TAG_PENDING } Att::Bitcoin(h) => { put_varuint(&mut p, *h); TAG_BITCOIN } Att::Other(t) => *t };
                o.extend_from_slice(&tag); put_varbytes(o, &p);
            }
            Item::Op(op, sub) => {
                match op { Op::Sha256 => o.push(0x08), Op::Append(a) => { o.push(0xf0); put_varbytes(o, a); } Op::Prepend(a) => { o.push(0xf1); put_varbytes(o, a); } Op::Reverse => o.push(0xf2), Op::Hexlify => o.push(0xf3) }
                ser_node(sub, o);
            }
        }
    }
}

fn apply(op: &Op, msg: &[u8]) -> Result<Vec<u8>, &'static str> {
    let out = match op {
        Op::Sha256 => sha256(msg).to_vec(),
        Op::Append(a) => [msg, a].concat(),
        Op::Prepend(a) => [a.as_slice(), msg].concat(),
        Op::Reverse => msg.iter().rev().copied().collect(),
        Op::Hexlify => to_hex(msg).into_bytes(),
    };
    if out.is_empty() || out.len() > MAX_MSG { return Err("a step in the proof produced an invalid message length"); }
    Ok(out)
}

/// Walk the proof from `msg` (the digest we submitted) and list every attestation with the commitment it attests.
pub fn leaves(n: &Node, msg: &[u8]) -> Result<Vec<Leaf>, &'static str> { let mut v = Vec::new(); walk(n, msg, &mut v)?; Ok(v) }
fn walk(n: &Node, msg: &[u8], out: &mut Vec<Leaf>) -> Result<(), &'static str> {
    for it in &n.items { match it { Item::Att(a) => out.push(Leaf { commit: msg.to_vec(), att: a.clone() }), Item::Op(op, sub) => walk(sub, &apply(op, msg)?, out)? } }
    Ok(())
}

/// Replace the pending attestation whose commitment is `commit` by the items of `upgrade` (a calendar's answer for that commitment). Returns true when something was replaced.
pub fn upgrade_pending(n: &mut Node, msg: &[u8], commit: &[u8], upgrade: &Node) -> Result<bool, &'static str> {
    let mut done = false;
    let mut k = 0;
    while k < n.items.len() {
        match &mut n.items[k] {
            Item::Att(Att::Pending(_)) if msg == commit => { n.items.remove(k); for u in &upgrade.items { n.items.insert(k, u.clone()); k += 1; } done = true; continue; }
            Item::Att(_) => {}
            Item::Op(op, sub) => { let m2 = apply(op, msg)?; if upgrade_pending(sub, &m2, commit, upgrade)? { done = true; } }
        }
        k += 1;
    }
    Ok(done)
}

/// A full `.ots` file for the standard tools (`ots verify`): header, version 1, sha256 of the file, then the timestamp.
pub fn detached_file(digest: &[u8; 32], ts: &Node) -> Vec<u8> { let mut o = OTS_MAGIC.to_vec(); put_varuint(&mut o, 1); o.push(0x08); o.extend_from_slice(digest); o.extend(serialize_timestamp(ts)); o }

/// Read a detached `.ots` file back: (sha256 digest it stamps, the timestamp tree).
pub fn parse_detached(b: &[u8]) -> Result<([u8; 32], Node), &'static str> {
    if b.len() < OTS_MAGIC.len() + 3 + 32 || &b[..OTS_MAGIC.len()] != OTS_MAGIC { return Err("not an OpenTimestamps file"); }
    let mut r = R { b, i: OTS_MAGIC.len(), items: 0 };
    if r.varuint()? != 1 { return Err("unknown OpenTimestamps file version"); }
    if r.byte()? != 0x08 { return Err("the file stamps a non-SHA-256 digest"); }
    let d: [u8; 32] = r.take(32)?.try_into().unwrap();
    let n = parse_timestamp(&b[r.i..])?;
    Ok((d, n))
}

/// Does this Bitcoin block header's merkle root equal the commitment? `merkle_root_display_hex` is what block explorers show (byte-reversed); the commitment is in header byte order.
pub fn bitcoin_commit_matches(commit: &[u8], merkle_root_display_hex: &str) -> bool {
    let Some(mut d) = from_hex(merkle_root_display_hex) else { return false };
    if d.len() != 32 || commit.len() != 32 { return false; }
    d.reverse();
    d == commit
}

// =============================================================== RFC 3161
const OID_SHA256: &[u8] = &[0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01];
const OID_SIGNED_DATA: &[u8] = &[0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x07, 0x02];
const OID_TSTINFO: &[u8] = &[0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x10, 0x01, 0x04];
const OID_MSG_DIGEST: &[u8] = &[0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x04];
const OID_RSA: &[u8] = &[0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01];
const OID_RSA_SHA256: &[u8] = &[0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0b];
const OID_RSA_SHA384: &[u8] = &[0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0c];
const OID_RSA_SHA512: &[u8] = &[0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0d];
const OID_EC_KEY: &[u8] = &[0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01];
const OID_P256: &[u8] = &[0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07];
const OID_P384: &[u8] = &[0x2b, 0x81, 0x04, 0x00, 0x22];
const OID_ECDSA_SHA256: &[u8] = &[0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02];
const OID_ECDSA_SHA384: &[u8] = &[0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x03];
const OID_SHA384: &[u8] = &[0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x02];
const OID_SHA512: &[u8] = &[0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03];

fn tlv(b: &[u8]) -> Result<(u8, &[u8], &[u8]), String> { // (tag, content, rest)
    if b.len() < 2 { return Err("DER ends early".into()); }
    let tag = b[0];
    let (len, hdr) = if b[1] < 0x80 { (b[1] as usize, 2) } else {
        let n = (b[1] & 0x7f) as usize;
        if n == 0 { return Err("indefinite-length (BER) encoding is not supported".into()); }
        if n > 4 || b.len() < 2 + n { return Err("bad DER length".into()); }
        if b[2] == 0 { return Err("non-minimal DER length".into()); }
        let l = b[2..2 + n].iter().fold(0usize, |a, x| a << 8 | *x as usize);
        if l < 0x80 { return Err("non-minimal DER length".into()); }
        (l, 2 + n)
    };
    let end = hdr.checked_add(len).ok_or("DER length overflow")?;
    if b.len() < end { return Err("DER content ends early".into()); }
    Ok((tag, &b[hdr..end], &b[end..]))
}
fn expect(b: &[u8], tag: u8, what: &str) -> Result<(Vec<u8>, usize), String> { // (content, total bytes consumed)
    let (t, c, rest) = tlv(b)?;
    if t != tag { return Err(format!("expected {what} (tag {tag:#04x}), found tag {t:#04x}")); }
    Ok((c.to_vec(), b.len() - rest.len()))
}
fn der_len(n: usize) -> Vec<u8> { if n < 0x80 { vec![n as u8] } else if n < 0x100 { vec![0x81, n as u8] } else if n < 0x10000 { vec![0x82, (n >> 8) as u8, n as u8] } else { vec![0x83, (n >> 16) as u8, (n >> 8) as u8, n as u8] } }
fn der(tag: u8, c: &[u8]) -> Vec<u8> { let mut o = vec![tag]; o.extend(der_len(c.len())); o.extend_from_slice(c); o }

/// An RFC 3161 TimeStampReq for a SHA-256 digest, asking for the TSA certificate (certReq TRUE). `nonce[0]` must be 0x01..0x7f (a positive DER INTEGER).
pub fn build_tsq(digest: &[u8; 32], nonce: &[u8; 8]) -> Vec<u8> {
    let alg = der(0x30, &[der(0x06, OID_SHA256), vec![0x05, 0x00]].concat());
    let imprint = der(0x30, &[alg, der(0x04, digest)].concat());
    der(0x30, &[vec![0x02, 0x01, 0x01], imprint, der(0x02, nonce), vec![0x01, 0x01, 0xff]].concat())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SigKind { RsaPkcs1(u16), Ecdsa { curve: u16, hash: u16 } }   // hash/curve in bits: 256 / 384 / 512
#[derive(Debug, Clone)]
pub struct Tsr {
    pub gen_time_ms: i64, pub serial_hex: String, pub nonce_hex: Option<String>, pub policy: String,
    pub signer_pin: String,                 // sha256 of the signer certificate's SubjectPublicKeyInfo DER (hex)
    pub not_before_ms: i64, pub not_after_ms: i64,
    pub signed_bytes: Vec<u8>, pub signature: Vec<u8>, pub key: Vec<u8>, pub kind: SigKind,   // for the server's ring check: verify(kind, key, signed_bytes, signature)
    pub tstinfo_sha256: String,
}

/// The SubjectPublicKeyInfo rebuilt in canonical DER from (algorithm, parameters, key): the pin depends on the KEY only, never on how the certificate happened to wrap it.
fn canon_spki(alg_oid: &[u8], par: &[u8], key: &[u8]) -> Vec<u8> {
    let p = if alg_oid == OID_RSA { vec![0x05, 0x00] } else { par.to_vec() };
    let alg = der(0x30, &[der(0x06, alg_oid), p].concat());
    der(0x30, &[alg, der(0x03, &[&[0u8][..], key].concat())].concat())
}
fn oid_text(o: &[u8]) -> String {
    if o.is_empty() { return String::new(); }
    let mut v = vec![(o[0] / 40) as u64, (o[0] % 40) as u64]; let mut cur = 0u64;
    for b in &o[1..] { cur = cur << 7 | (b & 0x7f) as u64; if b & 0x80 == 0 { v.push(cur); cur = 0; } }
    v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(".")
}
fn int_hex(c: &[u8]) -> String { let s = if c.len() > 1 && c[0] == 0 { &c[1..] } else { c }; to_hex(s) }
fn days_from_civil(y: i64, m: i64, d: i64) -> i64 { let y = if m <= 2 { y - 1 } else { y }; let era = if y >= 0 { y } else { y - 399 } / 400; let yoe = y - era * 400; let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1; let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy; era * 146097 + doe - 719468 }
/// "YYYYMMDDHHMMSS[.f+]Z" (GeneralizedTime) or "YYMMDDHHMMSSZ" (UTCTime) -> unix milliseconds.
pub fn parse_time(t: &[u8], generalized: bool) -> Result<i64, String> {
    let s = std::str::from_utf8(t).map_err(|_| "time is not text")?;
    let s = s.strip_suffix('Z').ok_or("time must end in Z (UTC)")?;
    let (main, frac) = match s.split_once('.') { Some((a, b)) => (a, b), None => (s, "") };
    let (yl, y) = if generalized { (4, 0) } else { (2, 0) }; let _ = y;
    if main.len() != yl + 10 || !main.bytes().all(|c| c.is_ascii_digit()) || !frac.bytes().all(|c| c.is_ascii_digit()) { return Err("malformed time".into()); }
    let n = |a: usize, b: usize| main[a..b].parse::<i64>().unwrap();
    let year = if generalized { n(0, 4) } else { let y2 = n(0, 2); if y2 >= 50 { 1900 + y2 } else { 2000 + y2 } };
    let o = yl;
    let (mo, d, h, mi, se) = (n(o, o + 2), n(o + 2, o + 4), n(o + 4, o + 6), n(o + 6, o + 8), n(o + 8, o + 10));
    if !(1..=12).contains(&mo) || !(1..=31).contains(&d) || h > 23 || mi > 59 || se > 60 { return Err("time out of range".into()); }
    let ms = if frac.is_empty() { 0 } else { format!("{:0<3}", &frac[..frac.len().min(3)]).parse::<i64>().unwrap() };
    Ok(((days_from_civil(year, mo, d) * 24 + h) * 60 + mi) * 60_000 + se * 1000 + ms)
}

fn hash_bits(oid: &[u8]) -> Option<u16> { if oid == OID_SHA256 { Some(256) } else if oid == OID_SHA384 { Some(384) } else if oid == OID_SHA512 { Some(512) } else { None } }
fn digest_bits(bits: u16, data: &[u8]) -> Vec<u8> { use sha2::{Sha384, Sha512}; match bits { 256 => Sha256::digest(data).to_vec(), 384 => Sha384::digest(data).to_vec(), _ => Sha512::digest(data).to_vec() } }

/// Parse a TimeStampResp for our request: status granted, TSTInfo binds EXACTLY `digest` (SHA-256) and (if given) `nonce`, signed attributes match the TSTInfo, a signer
/// certificate in the reply is valid at genTime, and returns everything the server needs to check the signature itself. Every refusal is a plain sentence (it is stored as the job's error).
pub fn parse_tsr(resp: &[u8], digest: &[u8; 32], nonce: Option<&[u8; 8]>) -> Result<Tsr, String> {
    let (_, top, _) = tlv(resp).and_then(|(t, c, r)| if t == 0x30 { Ok((t, c, r)) } else { Err("reply is not a DER SEQUENCE".to_string()) })?;
    let (st, status, rest) = tlv(top)?;
    if st != 0x30 { return Err("no PKIStatusInfo".into()); }
    let (it, ival, _) = tlv(status)?;
    if it != 0x02 || ival.len() != 1 { return Err("bad PKIStatus".into()); }
    if ival[0] > 1 { return Err(format!("the TSA refused the request (PKIStatus {})", ival[0])); }
    let (ct, token, _) = tlv(rest)?;
    if ct != 0x30 { return Err("granted but no TimeStampToken".into()); }
    let (ot, oid, rest) = tlv(token)?;
    if ot != 0x06 || oid != OID_SIGNED_DATA { return Err("token is not CMS SignedData".into()); }
    let (_, expl, _) = tlv(rest)?;                                    // [0] EXPLICIT
    let (_, sd, _) = tlv(expl)?;                                      // SignedData SEQUENCE
    let (_, _ver, r) = tlv(sd)?;
    let (_, _algs, r) = tlv(r)?;
    let (_, eci, mut r) = tlv(r)?;                                    // EncapsulatedContentInfo
    let (et, eoid, erest) = tlv(eci)?;
    if et != 0x06 || eoid != OID_TSTINFO { return Err("content is not TSTInfo".into()); }
    let (_, ex2, _) = tlv(erest)?;                                    // [0] EXPLICIT
    let (ot2, tst, _) = tlv(ex2)?;
    if ot2 != 0x04 { return Err("TSTInfo is not an OCTET STRING".into()); }
    let mut certs: Vec<Vec<u8>> = Vec::new();
    let signer_infos;
    loop {
        let (t, c, rest) = tlv(r)?;
        match t {
            0xa0 => { let mut cc = c; while !cc.is_empty() { let (ct, _, rr) = tlv(cc)?; if ct != 0x30 { return Err("certificate is not a SEQUENCE".into()); } certs.push(cc[..cc.len() - rr.len()].to_vec()); cc = rr; } r = rest; }
            0xa1 => { r = rest; }
            0x31 => { signer_infos = c; break; }
            _ => return Err("unexpected element in SignedData".into()),
        }
    }
    // ---- TSTInfo
    let (_, info, _) = tlv(tst).and_then(|(t, c, r)| if t == 0x30 { Ok((t, c, r)) } else { Err("TSTInfo is not a SEQUENCE".to_string()) })?;
    let (_, _v, r) = tlv(info)?;
    let (pt, policy, r) = tlv(r)?; if pt != 0x06 { return Err("TSTInfo policy missing".into()); }
    let (_, imprint, r) = tlv(r)?;
    let (_, ialg, ir) = tlv(imprint)?;
    let (_, ialg_oid, _) = tlv(ialg)?;
    let (_, hashed, _) = tlv(ir)?;
    if ialg_oid != OID_SHA256 { return Err("the TSA stamped a different hash algorithm than SHA-256".into()); }
    if hashed != digest { return Err("the TSA token stamps a DIFFERENT digest than the one requested".into()); }
    let (st2, serial, r) = tlv(r)?; if st2 != 0x02 { return Err("serial number missing".into()); }
    let (gt, gtv, mut r) = tlv(r)?; if gt != 0x18 { return Err("genTime is not a GeneralizedTime".into()); }
    let gen_time_ms = parse_time(gtv, true)?;
    let mut nonce_hex = None;
    while !r.is_empty() {
        let (t, c, rest) = tlv(r)?;
        if t == 0x02 { nonce_hex = Some(int_hex(c)); }
        r = rest;
    }
    if let Some(n) = nonce {
        let want = int_hex(n);
        if nonce_hex.as_deref() != Some(want.as_str()) { return Err("the TSA reply carries a different nonce than the request (replayed or wrong reply)".into()); }
    }
    let tstinfo_sha256 = to_hex(&sha256(tst));
    // ---- SignerInfo (exactly one)
    let (st3, si, more) = tlv(signer_infos)?; if st3 != 0x30 || !more.is_empty() { return Err("expected exactly one signer".into()); }
    let (_, _v, r) = tlv(si)?;
    let (sidt, sid, r) = tlv(r)?;
    let (_, dalg, r) = tlv(r)?;
    let (_, d_oid, _) = tlv(dalg)?;
    let dbits = hash_bits(d_oid).ok_or("signer digest algorithm is not SHA-256/384/512")?;
    let (t, c, r) = tlv(r)?;
    let (signed_bytes, r) = if t == 0xa0 {
        let mut a = c; let mut found = false;
        while !a.is_empty() {
            let (_, attr, rest) = tlv(a)?; let (_, ao, av) = tlv(attr)?;
            if ao == OID_MSG_DIGEST { let (_, set, _) = tlv(av)?; let (_, val, _) = tlv(set)?; if val != digest_bits(dbits, tst).as_slice() { return Err("the signed attributes do not match the TSTInfo (messageDigest differs)".into()); } found = true; }
            a = rest;
        }
        if !found { return Err("signed attributes carry no messageDigest".into()); }
        (der(0x31, c), r)                                              // the signature covers the attributes re-tagged as a SET (0x31)
    } else { return Err("TSA reply has no signed attributes (not supported)".into()); };
    let (_, sigalg, r) = tlv(r)?;
    let (sat, sig_oid, _) = tlv(sigalg)?; if sat != 0x06 { return Err("signature algorithm missing".into()); }
    let (sgt, sig, _) = tlv(r)?; if sgt != 0x04 { return Err("signature missing".into()); }
    // ---- signer certificate: match issuerAndSerial (or the only certificate)
    let sid_serial: Option<Vec<u8>> = if sidt == 0x30 { let (_, _iss, rr) = tlv(sid)?; let (_, sn, _) = tlv(rr)?; Some(sn.to_vec()) } else { None };
    let mut chosen: Option<(Vec<u8>, i64, i64, Vec<u8>)> = None; // (spki tlv, nb, na, serial)
    for cert in &certs {
        let (_, cc, _) = tlv(cert)?; let (_, tbs, _) = tlv(cc)?;
        let (t0, _, rest0) = tlv(tbs)?; let r2 = if t0 == 0xa0 { rest0 } else { tbs };
        let (_, serial, r2) = tlv(r2)?; let (_, _sa, r2) = tlv(r2)?; let (_, _iss, r2) = tlv(r2)?;
        let (_, val, r2) = tlv(r2)?; let (_, _subj, r2) = tlv(r2)?;
        let spki_total = { let (_, _, rest) = tlv(r2)?; r2.len() - rest.len() };
        let spki = r2[..spki_total].to_vec();
        let (nt, nb, rv) = tlv(val)?; let (at, na, _) = tlv(rv)?;
        let nbm = parse_time(nb, nt == 0x18)?; let nam = parse_time(na, at == 0x18)?;
        let ok = match &sid_serial { Some(sn) => sn.as_slice() == serial, None => certs.len() == 1 };
        if ok { chosen = Some((spki, nbm, nam, serial.to_vec())); break; }
    }
    let (spki, nb, na, _serial) = chosen.ok_or("the signer certificate is not inside the reply")?;
    if gen_time_ms < nb || gen_time_ms > na { return Err("the TSA certificate was not valid at the stamped time".into()); }
    let (_, spki_c, _) = tlv(&spki)?;
    let (_, alg, kr) = tlv(spki_c)?;
    let (_, alg_oid, alg_par) = tlv(alg)?;
    if alg_oid == OID_RSA && alg_par != [0x05, 0x00] { return Err("RSA key parameters are not exactly NULL".into()); }
    let (bt, bits, tail) = tlv(kr)?; if !tail.is_empty() { return Err("trailing bytes after the public key".into()); }
    if bt != 0x03 || bits.is_empty() || bits[0] != 0 { return Err("bad public key bit string".into()); }
    let key = bits[1..].to_vec();
    let sig_hash = |o: &[u8]| -> Option<u16> { if o == OID_RSA_SHA256 || o == OID_ECDSA_SHA256 { Some(256) } else if o == OID_RSA_SHA384 || o == OID_ECDSA_SHA384 { Some(384) } else if o == OID_RSA_SHA512 { Some(512) } else { None } };
    let hb = sig_hash(sig_oid).unwrap_or(dbits);
    let kind = if alg_oid == OID_RSA {
        if !(sig_oid == OID_RSA || sig_hash(sig_oid).is_some()) { return Err(format!("unsupported RSA signature algorithm {}", oid_text(sig_oid))); }
        SigKind::RsaPkcs1(hb)
    } else if alg_oid == OID_EC_KEY {
        let (ct, curve, ctail) = tlv(alg_par)?; if ct != 0x06 || !ctail.is_empty() { return Err("EC parameters are not a single named curve".into()); }
        let c = if curve == OID_P256 { 256 } else if curve == OID_P384 { 384 } else { return Err(format!("unsupported curve {}", oid_text(curve))); };
        if (c, hb) != (256, 256) && (c, hb) != (384, 384) { return Err("unsupported ECDSA curve/hash pair".into()); }
        SigKind::Ecdsa { curve: c, hash: hb }
    } else { return Err(format!("unsupported signer key type {}", oid_text(alg_oid))); };
    Ok(Tsr {
        gen_time_ms, serial_hex: int_hex(serial), nonce_hex, policy: oid_text(policy),
        signer_pin: to_hex(&sha256(&canon_spki(alg_oid, alg_par, &key))), not_before_ms: nb, not_after_ms: na,
        signed_bytes, signature: sig.to_vec(), key, kind, tstinfo_sha256,
    })
}

/// The browser kernel's one entry (`anchor@1`): re-derive, from the stored evidence alone, what the evidence CLAIMS about `digest_hex`. kind 1 = RFC 3161 token, 2 = OpenTimestamps file.
/// Output (pipe-separated, nothing else): tsa = `gen_time_ms|serial|signer_pin|tstinfo_sha256|cert_not_after_ms`; ots = `bitcoin|height|commit_hex` (or `pending|0|commit_hex`).
/// NOT done here (no RSA/ECDSA in the kernel): the CMS signature itself — the founder server checks it with ring and stores `verified_by`; the page says so.
pub fn inspect(kind: u32, evidence_hex: &str, digest_hex: &str) -> Option<String> {
    let ev = from_hex(evidence_hex)?; let d: [u8; 32] = from_hex(digest_hex)?.try_into().ok()?;
    match kind {
        1 => { let t = parse_tsr(&ev, &d, None).ok()?; Some(format!("{}|{}|{}|{}|{}", t.gen_time_ms, t.serial_hex, t.signer_pin, t.tstinfo_sha256, t.not_after_ms)) }
        2 => {
            let (fd, node) = parse_detached(&ev).ok()?; if fd != d { return None; }
            let ls = leaves(&node, &d).ok()?;
            if let Some(l) = ls.iter().find(|l| matches!(l.att, Att::Bitcoin(_))) { if let Att::Bitcoin(h) = l.att { return Some(format!("bitcoin|{h}|{}", to_hex(&l.commit))); } }
            ls.iter().find(|l| matches!(l.att, Att::Pending(_))).map(|l| format!("pending|0|{}", to_hex(&l.commit)))
        }
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ring::signature as rs;
    use serde_json::Value;
    fn vecs() -> Value { serde_json::from_str(include_str!("g5c_tsa_vectors.json")).unwrap() }
    fn ring_ok(t: &Tsr) -> bool {
        let alg: &dyn rs::VerificationAlgorithm = match &t.kind {
            SigKind::RsaPkcs1(256) => &rs::RSA_PKCS1_2048_8192_SHA256, SigKind::RsaPkcs1(384) => &rs::RSA_PKCS1_2048_8192_SHA384, SigKind::RsaPkcs1(512) => &rs::RSA_PKCS1_2048_8192_SHA512,
            SigKind::Ecdsa { curve: 256, .. } => &rs::ECDSA_P256_SHA256_ASN1, SigKind::Ecdsa { curve: 384, .. } => &rs::ECDSA_P384_SHA384_ASN1, _ => return false };
        rs::UnparsedPublicKey::new(alg, &t.key).verify(&t.signed_bytes, &t.signature).is_ok()
    }
    fn arr<const N: usize>(h: &str) -> [u8; N] { from_hex(h).unwrap().try_into().unwrap() }
    // E133 / G5c R1: the OpenTimestamps format allows ANY message length up to MAX_MSG at a pending leaf, not only 32 bytes. A calendar that appends to the digest before its last hash
    // (or ends on an append/prepend) hands out a longer commitment; the old server check "exactly 32" killed every such job. These tests pin the rules the fix relies on.
    #[test] fn pending_leaf_commitment_may_be_longer_than_32_bytes() {
        let d = [7u8; 32];
        let leaf = Node { items: vec![Item::Att(Att::Pending("https://cal.example".into()))] };
        let tree = Node { items: vec![Item::Op(Op::Append(vec![9u8; 20]), leaf)] };
        let ls = leaves(&tree, &d).unwrap();
        assert_eq!(ls.len(), 1); assert_eq!(ls[0].commit.len(), 52);
        assert_eq!(&ls[0].commit[..32], &d[..]); assert_eq!(&ls[0].commit[32..], &[9u8; 20][..]);
        // a detached file with it round-trips and the kernel-side inspect reports the full commitment
        let file = detached_file(&d, &tree);
        let (fd, back) = parse_detached(&file).unwrap(); assert_eq!(fd, d); assert_eq!(back, tree);
        let out = inspect(2, &to_hex(&file), &to_hex(&d)).unwrap();
        assert_eq!(out, format!("pending|0|{}", to_hex(&ls[0].commit)));
        // the upgrade replaces exactly that leaf, whatever its length
        let up = Node { items: vec![Item::Att(Att::Bitcoin(800_000))] };
        let mut t2 = back.clone(); assert!(upgrade_pending(&mut t2, &d, &ls[0].commit, &up).unwrap());
        assert!(leaves(&t2, &d).unwrap().iter().any(|l| matches!(l.att, Att::Bitcoin(800_000))));
        // a commitment longer than MAX_MSG can never be produced
        let huge = Node { items: vec![Item::Op(Op::Append(vec![1u8; MAX_MSG]), Node { items: vec![Item::Att(Att::Pending("x".into()))] })] };
        assert!(leaves(&huge, &d).is_err());
    }
    #[test] fn real_openssl_replies_parse_and_verify() {
        let v = vecs();
        for e in v["vectors"].as_array().unwrap() {
            let d: [u8; 32] = arr(e["digest_hex"].as_str().unwrap());
            let t = parse_tsr(&from_hex(e["reply_hex"].as_str().unwrap()).unwrap(), &d, None).unwrap_or_else(|x| panic!("{}: {x}", e["name"]));
            assert_eq!(t.signer_pin, e["spki_sha256"].as_str().unwrap(), "{}", e["name"]);
            assert_eq!(t.serial_hex.trim_start_matches('0'), e["serial_hex"].as_str().unwrap().trim_start_matches('0').to_lowercase());
            assert!(ring_ok(&t), "ring rejects {}", e["name"]);
            assert!(t.gen_time_ms > 1_700_000_000_000);
        }
    }
    #[test] fn wrong_digest_is_refused() {
        let v = vecs(); let e = &v["vectors"][0];
        let mut d: [u8; 32] = arr(e["digest_hex"].as_str().unwrap()); d[0] ^= 1;
        assert!(parse_tsr(&from_hex(e["reply_hex"].as_str().unwrap()).unwrap(), &d, None).unwrap_err().contains("DIFFERENT digest"));
    }
    #[test] fn flipping_any_byte_never_yields_another_accepted_claim() {
        let v = vecs();
        for e in v["vectors"].as_array().unwrap().iter().step_by(2) {
            let d: [u8; 32] = arr(e["digest_hex"].as_str().unwrap());
            let r = from_hex(e["reply_hex"].as_str().unwrap()).unwrap();
            let good = parse_tsr(&r, &d, None).unwrap();
            for i in 0..r.len() {
                let mut m = r.clone(); m[i] ^= 0x01;
                if let Ok(t) = parse_tsr(&m, &d, None) {
                    if ring_ok(&t) { assert_eq!((t.gen_time_ms, &t.signer_pin, &t.serial_hex), (good.gen_time_ms, &good.signer_pin, &good.serial_hex), "byte {i} changed the claim"); }
                }
            }
        }
    }
    #[test] fn truncations_never_panic() {
        let v = vecs(); let e = &v["vectors"][2];
        let d: [u8; 32] = arr(e["digest_hex"].as_str().unwrap());
        let r = from_hex(e["reply_hex"].as_str().unwrap()).unwrap();
        for n in 0..r.len() { assert!(parse_tsr(&r[..n], &d, None).is_err()); }
    }
    #[test] fn tsq_matches_openssl_shape() {
        let v = vecs(); let e = &v["vectors"][0];
        let q = from_hex(e["query_hex"].as_str().unwrap()).unwrap();
        let d: [u8; 32] = arr(e["digest_hex"].as_str().unwrap());
        let mine = build_tsq(&d, &[1, 2, 3, 4, 5, 6, 7, 8]);
        assert_eq!(&mine[..2], &[0x30, mine.len() as u8 - 2]);
        assert!(mine.windows(32).any(|w| w == d) && q.windows(32).any(|w| w == d));
    }
    #[test] fn time_parse() {
        assert_eq!(parse_time(b"20261102021339Z", true).unwrap(), 1_793_585_619_000);
        assert_eq!(parse_time(b"20261102021339.25Z", true).unwrap() % 1000, 250);
        assert!(parse_time(b"20261302021339Z", true).is_err());
    }
    fn sample() -> (Vec<u8>, Node) {
        let d = sha256(b"note");
        let c1 = [d.as_slice(), &[7u8; 16]].concat();
        let c2 = sha256(&c1).to_vec();
        let n = Node { items: vec![Item::Op(Op::Append(vec![7; 16]), Node { items: vec![Item::Op(Op::Sha256, Node { items: vec![Item::Att(Att::Pending("https://alice.btc.calendar.opentimestamps.org".into()))] })] })] };
        let _ = c1; (c2, n)
    }
    #[test] fn ots_roundtrip_leaves_and_upgrade() {
        let d = sha256(b"note"); let (commit, n) = sample();
        let bytes = serialize_timestamp(&n);
        let mut p = parse_timestamp(&bytes).unwrap(); assert_eq!(p, n);
        let l = leaves(&p, &d).unwrap(); assert_eq!(l.len(), 1); assert_eq!(l[0].commit, commit);
        assert_eq!(l[0].att, Att::Pending("https://alice.btc.calendar.opentimestamps.org".into()));
        let up = Node { items: vec![Item::Op(Op::Prepend(vec![9; 3]), Node { items: vec![Item::Att(Att::Bitcoin(800_000))] })] };
        assert!(upgrade_pending(&mut p, &d, &commit, &up).unwrap());
        let l = leaves(&p, &d).unwrap(); assert_eq!(l[0].att, Att::Bitcoin(800_000)); assert_eq!(l[0].commit, [vec![9u8; 3], commit.clone()].concat());
        assert_eq!(parse_timestamp(&serialize_timestamp(&p)).unwrap(), p);
        let f = detached_file(&d, &p); assert!(f.starts_with(OTS_MAGIC));
        assert_eq!(parse_detached(&f).unwrap(), (d, p.clone()));
        let mut bad = f.clone(); bad[OTS_MAGIC.len() + 1] = 0x02; assert!(parse_detached(&bad).is_err());
    }
    #[test] fn ots_fork_two_attestations() {
        let n = Node { items: vec![Item::Op(Op::Sha256, Node { items: vec![Item::Att(Att::Bitcoin(1))] }), Item::Att(Att::Pending("https://a.example/x".into()))] };
        let b = serialize_timestamp(&n); assert_eq!(b[0], 0xff);
        assert_eq!(parse_timestamp(&b).unwrap(), n);
    }
    #[test] fn ots_hostile_inputs() {
        assert!(parse_timestamp(&[]).is_err());
        assert!(parse_timestamp(&[0x02]).is_err());
        assert!(parse_timestamp(&[0xf0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01]).is_err());
        assert!(parse_timestamp(&[0x08; 200]).is_err());                       // nesting bomb
        let (_, n) = sample(); let mut b = serialize_timestamp(&n); b.push(0); assert!(parse_timestamp(&b).is_err());
        for i in 0..b.len() { let _ = parse_timestamp(&b[..i]); }
        let bad = Node { items: vec![Item::Att(Att::Pending("javascript:alert(1)<".into()))] };
        assert!(parse_timestamp(&serialize_timestamp(&bad)).is_err());
    }
    #[test] fn inspect_matches_parse() {
        let v = vecs(); let e = &v["vectors"][0];
        let o = inspect(1, e["reply_hex"].as_str().unwrap(), e["digest_hex"].as_str().unwrap()).unwrap();
        assert!(o.split('|').nth(2) == e["spki_sha256"].as_str());
        let mut wrong = e["digest_hex"].as_str().unwrap().to_string(); wrong.replace_range(0..2, "00");
        assert!(inspect(1, e["reply_hex"].as_str().unwrap(), &wrong).is_none() || e["digest_hex"].as_str().unwrap().starts_with("00"));
        let d = sha256(b"note"); let (commit, n) = sample();
        let f = to_hex(&detached_file(&d, &n));
        assert_eq!(inspect(2, &f, &to_hex(&d)).unwrap(), format!("pending|0|{}", to_hex(&commit)));
        let up = Node { items: vec![Item::Att(Att::Bitcoin(800_001))] }; let mut p = n.clone(); upgrade_pending(&mut p, &d, &commit, &up).unwrap();
        assert_eq!(inspect(2, &to_hex(&detached_file(&d, &p)), &to_hex(&d)).unwrap(), format!("bitcoin|800001|{}", to_hex(&commit)));
        assert!(inspect(2, &f, &to_hex(&sha256(b"other"))).is_none()); assert!(inspect(9, &f, &to_hex(&d)).is_none()); assert!(inspect(2, "zz", "zz").is_none());
    }
    #[test] fn bitcoin_byte_order() {
        let c: Vec<u8> = (0u8..32).collect();
        let mut disp = c.clone(); disp.reverse();
        assert!(bitcoin_commit_matches(&c, &to_hex(&disp)));
        assert!(!bitcoin_commit_matches(&c, &to_hex(&c)));
    }
}
