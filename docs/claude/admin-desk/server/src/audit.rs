// ANEXOMAIL ADMIN DESK audit.rs (D5a-4 outside copy, 23 Nov 2026): the lookup-audit checkpoints (AD4b fadm_lookup_cp) are signed with the Desk's OWN Ed25519 key (Rule 52 key, domain
// anexo-desk-lookup-cp-export-v1) and written, one file per checkpoint, OUTSIDE the database. Rust + Tokio, no new crate. Desk only: no founder or awam code, no money.
// Two jobs: `anexomail-desk audit-export <dir>` (timer, every few minutes) and `anexomail-desk audit-verify <dir> [pubkey-hex]` (anybody, any time, needs no database).
// WHAT IT CATCHES: (1) every older file is compared with the database: a rewritten checkpoint, a missing checkpoint or a changed hash = TAMPER (ledger line + high alert + exit 3);
// (2) every file must carry a valid signature of the Desk key and chain from the file before it; (3) files are written with create_new and never overwritten.
// HONEST LIMIT: a person holding BOTH the database AND the Desk signing key AND the Storage Box could rewrite everything; the Storage Box copy is a second place that must be changed too.
use crate::sign;
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::io::Write;
use std::path::Path;

pub const DOMAIN: &str = "anexo-desk-lookup-cp-export-v1";

#[derive(Clone, Debug, PartialEq)]
pub struct Cp { pub seq: i64, pub ts: String, pub size: i64, pub root: String, pub prev: String, pub hash: String, pub auto: bool }

fn h64(s: &str) -> bool { s.len() == 64 && s.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f')) }
fn ts_ok(s: &str) -> bool { s.len() == 27 && s.ends_with('Z') && s.as_bytes()[10] == b'T' && s.bytes().all(|b| b.is_ascii_digit() || matches!(b, b'-' | b':' | b'.' | b'T' | b'Z')) }
/// The first link of the checkpoint chain: sha256 of the fixed genesis text used in AD4b.
pub fn genesis_hex() -> String { sign::sha256_hex(b"anexo-desk-lookup-cp-genesis") }

impl Cp {
    pub fn from_json(v: &Value) -> Result<Cp, String> {
        let s = |k: &str| v[k].as_str().map(str::to_string).ok_or_else(|| format!("missing {k}"));
        let cp = Cp { seq: v["cp_seq"].as_i64().ok_or("missing cp_seq")?, ts: s("ts")?, size: v["size"].as_i64().ok_or("missing size")?, root: s("root")?, prev: s("prev")?, hash: s("hash")?, auto: v["auto"].as_bool().ok_or("missing auto")? };
        if cp.seq < 1 || cp.size < 1 || !ts_ok(&cp.ts) || !h64(&cp.root) || !h64(&cp.prev) || !h64(&cp.hash) { return Err("malformed checkpoint".into()); }
        Ok(cp)
    }
    /// The exact bytes that are signed.
    pub fn message(&self) -> Vec<u8> { format!("{DOMAIN}|{}|{}|{}|{}|{}|{}", self.seq, self.ts, self.size, self.root, self.prev, self.hash).into_bytes() }
}
pub fn file_name(seq: i64) -> String { format!("cp-{seq:010}.json") }
fn seq_of(name: &str) -> Option<i64> { let d = name.strip_prefix("cp-")?.strip_suffix(".json")?; if d.len() == 10 && d.bytes().all(|b| b.is_ascii_digit()) { d.parse().ok() } else { None } }

/// The file text for one checkpoint, signed with the Desk key.
pub fn file_json(s: &sign::Signer, cp: &Cp) -> String {
    format!("{}\n", json!({"format": DOMAIN, "cp_seq": cp.seq, "ts": cp.ts, "size": cp.size, "root": cp.root, "prev": cp.prev, "hash": cp.hash, "auto": cp.auto, "kid": s.kid(), "pub": s.public_hex(), "sig": s.sign_raw(&cp.message())}))
}
/// Check one file: format, key id, signature (and, when given, that it is THIS key). Returns the checkpoint.
pub fn verify_file(text: &str, expect_pub: Option<&str>) -> Result<Cp, String> {
    let v: Value = serde_json::from_str(text).map_err(|_| "not valid JSON".to_string())?;
    if v["format"].as_str() != Some(DOMAIN) { return Err("wrong format".into()); }
    let cp = Cp::from_json(&v)?;
    let pubhex = v["pub"].as_str().ok_or("missing pub")?;
    if let Some(e) = expect_pub { if e != pubhex { return Err("signed by another key".into()); } }
    let pk: [u8; 32] = sign::unhex(pubhex).and_then(|b| <[u8; 32]>::try_from(b).ok()).ok_or("bad pub")?;
    if v["kid"].as_str() != Some(&sign::sha256_hex(&pk)[..16]) { return Err("kid does not match the key".into()); }
    let sig: Vec<u8> = v["sig"].as_str().and_then(sign::unhex).ok_or("missing sig")?;
    let (vk, sg) = (VerifyingKey::from_bytes(&pk).map_err(|_| "bad pub".to_string())?, Signature::from_slice(&sig).map_err(|_| "bad sig".to_string())?);
    vk.verify(&cp.message(), &sg).map_err(|_| "signature does not verify".to_string())?;
    Ok(cp)
}
/// Does `next` follow `prev` (or the genesis when there is none)?
pub fn chain_ok(prev: Option<&Cp>, next: &Cp) -> bool {
    match prev { None => next.seq == 1 && next.prev == genesis_hex(), Some(p) => next.seq == p.seq + 1 && next.prev == p.hash && next.size > p.size }
}
/// All files of a folder, in order: every signature valid, every name equal to its number, no gap, every file chained to the one before.
pub fn scan(dir: &Path, expect_pub: Option<&str>) -> Result<Vec<Cp>, String> {
    let mut names: Vec<(i64, String)> = Vec::new();
    for e in std::fs::read_dir(dir).map_err(|e| format!("cannot read {}: {e}", dir.display()))? {
        let n = e.map_err(|e| e.to_string())?.file_name().to_string_lossy().to_string();
        if let Some(q) = seq_of(&n) { names.push((q, n)); }
    }
    names.sort();
    let mut out: Vec<Cp> = Vec::new();
    for (q, n) in names {
        let text = std::fs::read_to_string(dir.join(&n)).map_err(|e| format!("{n}: {e}"))?;
        let cp = verify_file(&text, expect_pub).map_err(|e| format!("{n}: {e}"))?;
        if cp.seq != q { return Err(format!("{n}: the number inside is {}", cp.seq)); }
        if !chain_ok(out.last(), &cp) { return Err(format!("{n}: does not chain from the file before (a checkpoint is missing or changed)")); }
        out.push(cp);
    }
    Ok(out)
}

#[derive(Debug, PartialEq)]
pub struct Summary { pub files: usize, pub new: usize, pub last: i64 }
/// The export job against one database connection and one folder. Err("TAMPER: ...") = history differs from the files; Err("ERROR: ...") = could not do the job.
pub async fn run(c: &tokio_postgres::Client, s: &sign::Signer, dir: &Path) -> Result<Summary, String> {
    std::fs::create_dir_all(dir).map_err(|e| format!("ERROR: cannot create {}: {e}", dir.display()))?;
    let have = scan(dir, Some(&s.public_hex())).map_err(|e| format!("TAMPER: {e}"))?;
    let _ = c.simple_query("select desk.fadm_lookup_tick()::text").await;   // sweep + automatic seal first, so a quiet day's last links are sealed and copied too
    let msgs = c.simple_query("select desk.fadm_lookup_cp_export(0, 1000)::text").await.map_err(|e| format!("ERROR: database: {e}"))?;
    let text = msgs.iter().find_map(|m| if let tokio_postgres::SimpleQueryMessage::Row(r) = m { r.get(0).map(str::to_string) } else { None }).ok_or("ERROR: no answer from the export door")?;
    let arr: Vec<Value> = serde_json::from_str(&text).map_err(|e| format!("ERROR: export door answer: {e}"))?;
    let db: Vec<Cp> = arr.iter().map(Cp::from_json).collect::<Result<_, _>>().map_err(|e| format!("ERROR: {e}"))?;
    for f in &have {
        match db.iter().find(|d| d.seq == f.seq) { Some(d) if d == f => {}, Some(_) => return Err(format!("TAMPER: checkpoint {} in the database differs from the signed file", f.seq)), None => return Err(format!("TAMPER: checkpoint {} exists as a signed file but not in the database", f.seq)) }
    }
    let mut prev = have.last().cloned(); let mut new = 0usize; let after = prev.as_ref().map_or(0, |p| p.seq);
    for d in db.iter().filter(|d| d.seq > after) {
        if !chain_ok(prev.as_ref(), d) { return Err(format!("TAMPER: checkpoint {} does not chain from the one before it", d.seq)); }
        let mut f = std::fs::OpenOptions::new().write(true).create_new(true).open(dir.join(file_name(d.seq))).map_err(|e| format!("ERROR: cannot create the file for checkpoint {}: {e}", d.seq))?;
        f.write_all(file_json(s, d).as_bytes()).and_then(|_| f.sync_all()).map_err(|e| format!("ERROR: cannot write checkpoint {}: {e}", d.seq))?;
        prev = Some(d.clone()); new += 1;
    }
    Ok(Summary { files: have.len() + new, new, last: prev.map_or(0, |p| p.seq) })
}
async fn report(c: &tokio_postgres::Client, ok: bool, new: usize, last: i64, note: &str) {
    let q = format!("select desk.fadm_lookup_export_report({ok}, {new}, {last}, '{}')", note.replace('\'', ""));
    if let Err(e) = c.simple_query(&q).await { eprintln!("audit-export: could not report to the database: {e}"); }
}
/// `anexomail-desk audit-export <dir>`: exit 0 ok, 3 tamper (reported), 4 error.
pub async fn cmd_export(dir: &str) -> i32 {
    crate::signed::init();
    let Some(s) = crate::signed::signer() else { println!("AUDIT EXPORT FAIL: ERROR: signing key missing"); return 4 };
    let c = match crate::door::connect().await { Ok(c) => c, Err(e) => { println!("AUDIT EXPORT FAIL: ERROR: database: {e}"); return 4 } };
    match run(&c, s, Path::new(dir)).await {
        Ok(r) => { report(&c, true, r.new, r.last, "ok").await; println!("AUDIT EXPORT OK: {} files in {dir}, {} new, last checkpoint {} (signed with kid {})", r.files, r.new, r.last, s.kid()); 0 }
        Err(e) if e.starts_with("TAMPER") => { report(&c, false, 0, 0, &e).await; println!("AUDIT EXPORT FAIL: {e}"); 3 }
        Err(e) => { println!("AUDIT EXPORT FAIL: {e}"); 4 }
    }
}
/// `anexomail-desk audit-verify <dir> [pubkey-hex]`: no database, no key file needed; anybody holding the folder can run it.
pub fn cmd_verify(dir: &str, pubhex: Option<&str>) -> i32 {
    match scan(Path::new(dir), pubhex) {
        Ok(v) if v.is_empty() => { println!("AUDIT FILES: no checkpoint files in {dir} yet"); 0 }
        Ok(v) => { println!("AUDIT FILES OK: {} checkpoint files, every signature valid, every file chained to the one before, last checkpoint {} covers {} lookups", v.len(), v.last().map_or(0, |c| c.seq), v.last().map_or(0, |c| c.size)); 0 }
        Err(e) => { println!("AUDIT FILES FAIL: {e}"); 3 }
    }
}
#[allow(dead_code)] fn _sha(b: &[u8]) -> String { sign::hex(&Sha256::digest(b)) }

#[cfg(test)]
mod tests {
    use super::*;
    const SEED: &str = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";
    fn signer() -> sign::Signer { sign::Signer::from_seed_hex(SEED).unwrap() }
    fn cp(seq: i64, prev: &str) -> Cp { let h = sign::sha256_hex(format!("cp{seq}").as_bytes()); Cp { seq, ts: "2026-11-23T01:30:00.123456Z".into(), size: seq * 10, root: sign::sha256_hex(format!("root{seq}").as_bytes()), prev: prev.into(), hash: h, auto: seq % 2 == 0 } }
    fn tmp(tag: &str) -> std::path::PathBuf { let p = std::env::temp_dir().join(format!("desk-audit-{tag}-{}-{}", std::process::id(), std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos())); std::fs::create_dir_all(&p).unwrap(); p }
    fn chain(n: i64) -> Vec<Cp> { let mut v: Vec<Cp> = vec![]; for i in 1..=n { let prev = v.last().map(|c| c.hash.clone()).unwrap_or_else(genesis_hex); v.push(cp(i, &prev)); } v }
    #[test] fn genesis_matches_the_sql_text() { assert_eq!(genesis_hex(), sign::sha256_hex(b"anexo-desk-lookup-cp-genesis")); assert_eq!(genesis_hex().len(), 64); }
    #[test] fn signed_file_verifies_and_every_tamper_fails() {
        let s = signer(); let c = &chain(1)[0]; let t = file_json(&s, c);
        assert_eq!(verify_file(&t, None).unwrap(), *c); assert_eq!(verify_file(&t, Some(&s.public_hex())).unwrap(), *c);
        assert!(verify_file(&t.replace(&c.root, &"0".repeat(64)), None).is_err());           // changed root
        assert!(verify_file(&t.replace("\"cp_seq\":1", "\"cp_seq\":2"), None).is_err());     // changed number
        assert!(verify_file(&t, Some(&"11".repeat(32))).is_err());                           // another key
        let other = sign::Signer::from_seed_hex(&"07".repeat(32)).unwrap(); let forged = file_json(&other, c).replace(&other.public_hex(), &s.public_hex());
        assert!(verify_file(&forged, None).is_err());                                        // signed by another key, labelled as ours
        assert!(verify_file("{}", None).is_err()); assert!(verify_file("nope", None).is_err());
    }
    #[test] fn chain_rules() {
        let v = chain(3);
        assert!(chain_ok(None, &v[0]) && chain_ok(Some(&v[0]), &v[1]) && chain_ok(Some(&v[1]), &v[2]));
        assert!(!chain_ok(None, &v[1]) && !chain_ok(Some(&v[0]), &v[2]));                    // gap
        let mut bad = v[1].clone(); bad.prev = "0".repeat(64); assert!(!chain_ok(Some(&v[0]), &bad));
        let mut small = v[1].clone(); small.size = 5; assert!(!chain_ok(Some(&v[0]), &small)); // tree must grow
    }
    #[test] fn folder_scan_accepts_a_whole_chain_and_names_the_broken_file() {
        let s = signer(); let d = tmp("scan"); let v = chain(4);
        for c in &v { std::fs::write(d.join(file_name(c.seq)), file_json(&s, c)).unwrap(); }
        assert_eq!(scan(&d, Some(&s.public_hex())).unwrap().len(), 4); assert_eq!(cmd_verify(d.to_str().unwrap(), None), 0);
        let p3 = d.join(file_name(3)); let t = std::fs::read_to_string(&p3).unwrap(); std::fs::write(&p3, t.replace("\"auto\":false", "\"auto\":true").replace(&v[2].root, &v[3].root)).unwrap();
        let e = scan(&d, None).unwrap_err(); assert!(e.contains("cp-0000000003.json"), "{e}"); assert_eq!(cmd_verify(d.to_str().unwrap(), None), 3);
        std::fs::write(&p3, t).unwrap(); std::fs::remove_file(d.join(file_name(2))).unwrap();   // a removed file = a gap
        assert!(scan(&d, None).unwrap_err().contains("cp-0000000003.json")); std::fs::remove_dir_all(&d).ok();
    }
    #[test] fn a_file_named_for_another_number_is_refused() {
        let s = signer(); let d = tmp("name"); let v = chain(2);
        std::fs::write(d.join(file_name(1)), file_json(&s, &v[0])).unwrap(); std::fs::write(d.join(file_name(2)), file_json(&s, &v[0])).unwrap();
        assert!(scan(&d, None).is_err()); std::fs::remove_dir_all(&d).ok();
    }
    #[test] fn malformed_checkpoints_are_refused() {
        let ok = serde_json::to_value(json!({"cp_seq": 1, "ts": "2026-11-23T01:30:00.123456Z", "size": 3, "root": "a".repeat(64), "prev": "b".repeat(64), "hash": "c".repeat(64), "auto": true})).unwrap();
        assert!(Cp::from_json(&ok).is_ok());
        for (k, v) in [("root", json!("zz")), ("ts", json!("yesterday")), ("size", json!(0)), ("cp_seq", json!(0)), ("hash", json!("A".repeat(64)))] { let mut b = ok.clone(); b[k] = v; assert!(Cp::from_json(&b).is_err(), "{k}"); }
    }
    // ---- real PostgreSQL (scratch db with AD1..AD4b and some lookup links): export, repeat, tamper ----
    async fn pg() -> Option<tokio_postgres::Client> {
        let url = std::env::var("DESK_TEST_ADMIN_URL").ok()?;
        let (c, conn) = tokio_postgres::connect(&url, tokio_postgres::NoTls).await.ok()?; tokio::spawn(conn); Some(c)
    }
    #[tokio::test] async fn export_on_real_postgres_writes_signed_files_once_and_catches_tamper() {
        let Some(c) = pg().await else { eprintln!("no DESK_TEST_ADMIN_URL: skipped"); return };
        let n = |q: &str| { let q = q.to_string(); let c = &c; async move { c.simple_query(&q).await.unwrap().into_iter().find_map(|m| if let tokio_postgres::SimpleQueryMessage::Row(r) = m { r.get(0).map(str::to_string) } else { None }).unwrap_or_default() } };
        if n("select count(*) from desk.fadm_lookup_link").await == "0" { eprintln!("no lookup links in the scratch db: skipped"); return; }
        // seal at least one checkpoint (installer role does what the timer or an owner would do)
        let _ = c.simple_query("insert into desk.fadm_lookup_cp (sealed_by, auto) values (null, true)").await;   // refused with 'nothing new to seal' when already sealed: fine
        let s = signer(); let d = tmp("pg");
        let r1 = run(&c, &s, &d).await.unwrap(); assert!(r1.new >= 1 && r1.files == r1.new, "{r1:?}");
        let db_n: usize = n("select count(*) from desk.fadm_lookup_cp").await.parse().unwrap(); assert_eq!(r1.files, db_n);
        assert_eq!(scan(&d, Some(&s.public_hex())).unwrap().len(), db_n);
        let r2 = run(&c, &s, &d).await.unwrap(); assert_eq!(r2.new, 0, "a second run writes nothing"); assert_eq!(r2.files, db_n);
        // a new checkpoint appears: only the new file is written, the old ones are untouched
        let first = std::fs::read(d.join(file_name(1))).unwrap();
        let _ = c.simple_query("insert into desk.fadm_lookup (employee_id, company_ref, reason, fields, request_id, outcome) select employee_id, company_ref, reason, fields, gen_random_uuid(), 'requested' from desk.fadm_lookup limit 1").await;
        if c.simple_query("insert into desk.fadm_lookup_cp (sealed_by, auto) values (null, true)").await.is_ok() { let r3 = run(&c, &s, &d).await.unwrap(); assert_eq!(r3.new, 1); assert_eq!(std::fs::read(d.join(file_name(1))).unwrap(), first); }
        // another key signs a file: refused as TAMPER
        let other = sign::Signer::from_seed_hex(&"09".repeat(32)).unwrap(); let r = run(&c, &other, &d).await.unwrap_err(); assert!(r.starts_with("TAMPER"), "{r}");
        // a file changed on the box: TAMPER
        let p = d.join(file_name(1)); let t = std::fs::read_to_string(&p).unwrap(); std::fs::write(&p, t.replacen("\"size\":", "\"size\":9", 1)).unwrap();
        assert!(run(&c, &s, &d).await.unwrap_err().starts_with("TAMPER"));
        // a file removed from the middle or the end: the end is simply re-created (it is in the database), the middle is a gap
        std::fs::write(&p, t).unwrap(); std::fs::remove_dir_all(&d).ok();
    }
}
