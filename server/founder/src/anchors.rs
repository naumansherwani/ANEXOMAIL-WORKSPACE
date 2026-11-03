//! G5c — account-free OUTSIDE TIME ANCHORS for the signed checkpoints. Technology: Rust (reqwest + ring; RustCrypto p384 only for P-384/SHA-512). Parsing / format rules live ONCE in `server/rust/anchor_core.rs`
//! (shared with the browser kernel, Rule 52). This file: the tick (E124 queue -> public TSA / OpenTimestamps calendar -> verify -> SQL door), and the view the browser asks.
//! Honest limits: no account anywhere; a TSA signer is pinned (TOFU) not chained to a public root; every failure is stored as plain text in the job, never swallowed.
use crate::anchor_core as ac;
use crate::data::Sb;
use ring::signature as rs;
use serde_json::{Value, json};
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

const MAX_BODY: usize = 262_144;
const UA: &str = "anexomail-founder/0.1 (time-anchor; contact: founderworkspace.anexomail.com)";

fn http() -> &'static reqwest::Client {
    static C: OnceLock<reqwest::Client> = OnceLock::new();
    C.get_or_init(|| reqwest::Client::builder().redirect(reqwest::redirect::Policy::limited(3)).user_agent(UA).build().expect("http client"))
}
fn gaps() -> &'static Mutex<HashMap<String, Instant>> { static G: OnceLock<Mutex<HashMap<String, Instant>>> = OnceLock::new(); G.get_or_init(|| Mutex::new(HashMap::new())) }
/// Politeness towards free public services: at most one call per provider per `min_gap_secs`.
fn gap_ok(name: &str, secs: u64) -> bool {
    let mut g = gaps().lock().unwrap();
    let now = Instant::now();
    if let Some(t) = g.get(name) { if now.duration_since(*t) < Duration::from_secs(secs) { return false; } }
    g.insert(name.to_string(), now);
    true
}
fn url_ok(u: &str) -> bool { (u.starts_with("https://") || u.starts_with("http://")) && u.len() < 300 && u.bytes().all(|c| c.is_ascii_alphanumeric() || b".-_/:".contains(&c)) }

async fn body_of(r: reqwest::Response) -> Result<Vec<u8>, String> {
    if r.content_length().map(|n| n as usize > MAX_BODY).unwrap_or(false) { return Err("answer is larger than 256 KB".into()); }
    let b = r.bytes().await.map_err(|e| format!("reading the answer failed: {e}"))?;
    if b.len() > MAX_BODY { return Err("answer is larger than 256 KB".into()); }
    Ok(b.to_vec())
}

/// Who checks a CMS signature. ring for everything it implements; RustCrypto p384 (pure Rust, verify-only, no C) for the one pair ring does not have: P-384 + SHA-512 (freetsa.org).
/// The parser (`anchor_core::parse_tsr`) accepts EXACTLY the pairs listed here, so a token it lets through always has a verifier, and the (curve, hash) pair is matched exactly (never "any hash on this curve").
pub fn sig_verify(t: &ac::Tsr) -> Option<&'static str> {
    let alg: &dyn rs::VerificationAlgorithm = match &t.kind {
        ac::SigKind::RsaPkcs1(256) => &rs::RSA_PKCS1_2048_8192_SHA256, ac::SigKind::RsaPkcs1(384) => &rs::RSA_PKCS1_2048_8192_SHA384, ac::SigKind::RsaPkcs1(512) => &rs::RSA_PKCS1_2048_8192_SHA512,
        ac::SigKind::Ecdsa { curve: 256, hash: 256 } => &rs::ECDSA_P256_SHA256_ASN1, ac::SigKind::Ecdsa { curve: 256, hash: 384 } => &rs::ECDSA_P256_SHA384_ASN1,
        ac::SigKind::Ecdsa { curve: 384, hash: 256 } => &rs::ECDSA_P384_SHA256_ASN1, ac::SigKind::Ecdsa { curve: 384, hash: 384 } => &rs::ECDSA_P384_SHA384_ASN1,
        ac::SigKind::Ecdsa { curve: 384, hash: 512 } => return if p384_sha512(t) { Some("rustcrypto-p384") } else { None },
        _ => return None };
    if rs::UnparsedPublicKey::new(alg, &t.key).verify(&t.signed_bytes, &t.signature).is_ok() { Some("ring") } else { None }
}

/// ECDSA P-384 over the SHA-512 of the signed attributes (RFC 5758 ecdsa-with-SHA512). The key must be an UNCOMPRESSED point (ring demands the same); the signature strict DER; the digest is
/// handed over as a pre-hash, which ECDSA truncates to the leftmost 384 bits (FIPS 186-5) - that is the whole reason ring cannot do it and this can.
fn p384_sha512(t: &ac::Tsr) -> bool {
    use ecdsa::signature::hazmat::PrehashVerifier;
    use sha2::{Digest, Sha512};
    if t.key.len() != 97 || t.key[0] != 0x04 { return false; }
    let Ok(vk) = ecdsa::VerifyingKey::<p384::NistP384>::from_sec1_bytes(&t.key) else { return false };
    let Ok(sig) = ecdsa::Signature::<p384::NistP384>::from_der(&t.signature) else { return false };
    vk.verify_prehash(&Sha512::digest(&t.signed_bytes), &sig).is_ok()
}

/// Everything about one TSA answer, decided without the network (so it is testable): parse, bind to our digest + nonce, check the CMS signature.
pub fn check_tsa_reply(reply: &[u8], digest: &[u8; 32], nonce: &[u8; 8]) -> Result<(ac::Tsr, Value), String> {
    let t = ac::parse_tsr(reply, digest, Some(nonce))?;
    let Some(by) = sig_verify(&t) else { return Err("the TSA signature does not verify".into()) };
    let parsed = json!({"gen_time_ms": t.gen_time_ms, "serial": if t.serial_hex.len() < 2 { format!("0{}", t.serial_hex) } else { t.serial_hex.clone() }, "nonce": t.nonce_hex, "policy": t.policy,
        "signer_pin": t.signer_pin, "cert_not_before_ms": t.not_before_ms, "cert_not_after_ms": t.not_after_ms, "tstinfo_sha256": t.tstinfo_sha256, "sig": format!("{:?}", t.kind), "verified_by": by});
    Ok((t, parsed))
}

fn fresh_nonce() -> Option<[u8; 8]> {
    use ring::rand::{SecureRandom, SystemRandom};
    let mut n = [0u8; 8]; SystemRandom::new().fill(&mut n).ok()?; n[0] = 1 + (n[0] % 0x7e); Some(n)
}

async fn run_tsa(sb: &Sb, job: &Value, id: i64) -> Result<(), String> {
    let url = job["url"].as_str().unwrap_or(""); if !url_ok(url) { return Err("bad provider address".into()); }
    let digest: [u8; 32] = ac::from_hex(job["digest_hex"].as_str().unwrap_or("")).and_then(|v| v.try_into().ok()).ok_or("digest missing")?;
    let nonce = fresh_nonce().ok_or("no randomness")?;
    let q = ac::build_tsq(&digest, &nonce);
    let to = Duration::from_millis(job["timeout_ms"].as_u64().unwrap_or(15000).clamp(2000, 60000));
    let r = http().post(url).timeout(to).header("Content-Type", "application/timestamp-query").header("Accept", "application/timestamp-reply").body(q).send().await.map_err(|e| format!("TSA unreachable: {e}"))?;
    if !r.status().is_success() { return Err(format!("TSA answered HTTP {}", r.status().as_u16())); }
    let reply = body_of(r).await?;
    let (_t, parsed) = check_tsa_reply(&reply, &digest, &nonce)?;
    let res = sb.rpc("founder_anchor_record_tsa", json!({"p_job": id, "p_evidence_hex": ac::to_hex(&reply), "p_parsed": parsed})).await.ok_or("SQL refused the token (see E124 guard)")?;
    if res.get("recorded").and_then(|x| x.as_bool()) == Some(false) { return Err(format!("not stored: {}", res["reason"].as_str().unwrap_or("?"))); }
    Ok(())
}

async fn run_ots_submit(sb: &Sb, job: &Value, id: i64) -> Result<(), String> {
    let url = job["url"].as_str().unwrap_or("").trim_end_matches('/'); if !url_ok(url) { return Err("bad calendar address".into()); }
    let digest: [u8; 32] = ac::from_hex(job["digest_hex"].as_str().unwrap_or("")).and_then(|v| v.try_into().ok()).ok_or("digest missing")?;
    let to = Duration::from_millis(job["timeout_ms"].as_u64().unwrap_or(15000).clamp(2000, 60000));
    let r = http().post(format!("{url}/digest")).timeout(to).header("Accept", "application/vnd.opentimestamps.v1").header("Content-Type", "application/x-www-form-urlencoded").body(digest.to_vec()).send().await.map_err(|e| format!("calendar unreachable: {e}"))?;
    if !r.status().is_success() { return Err(format!("calendar answered HTTP {}", r.status().as_u16())); }
    let b = body_of(r).await?;
    let node = ac::parse_timestamp(&b).map_err(|e| format!("calendar answer is not a valid proof: {e}"))?;
    let ls = ac::leaves(&node, &digest).map_err(|e| e.to_string())?;
    let pend = ls.iter().find_map(|l| if let ac::Att::Pending(u) = &l.att { Some((l.commit.clone(), u.clone())) } else { None }).ok_or("calendar answer carries no pending attestation")?;
    // The OpenTimestamps format allows a commitment of any length up to MAX_MSG (E133 / G5c R1); the old "exactly 32 bytes" rule killed every job whose calendar appends before its last hash.
    if pend.0.is_empty() || pend.0.len() > ac::MAX_MSG { return Err(format!("calendar commitment has an impossible length ({} bytes)", pend.0.len())); }
    let file = ac::detached_file(&digest, &node);
    let parsed = json!({"commit_hex": ac::to_hex(&pend.0), "calendar": pend.1, "commit_len": pend.0.len(), "leaves": ls.len(), "format": "opentimestamps-v1"});
    let res = sb.rpc("founder_anchor_record_ots", json!({"p_job": id, "p_stage": "ots_pending", "p_evidence_hex": ac::to_hex(&file), "p_parsed": parsed})).await.ok_or("SQL refused the proof")?;
    if res.get("recorded").and_then(|x| x.as_bool()) == Some(false) { return Err(format!("not stored: {}", res["reason"].as_str().unwrap_or("?"))); }
    Ok(())
}

/// Bitcoin header of `height` from account-free public explorers. Returns (merkle root as explorers display it, block time in ms, explorer name). Two explorers must not disagree.
async fn btc_header(height: u64) -> Result<(String, i64, &'static str), String> {
    let mut got: Vec<(String, i64, &'static str)> = Vec::new(); let mut errs = Vec::new();
    for (name, base) in [("blockstream.info", "https://blockstream.info/api"), ("mempool.space", "https://mempool.space/api")] {
        let one = async {
            let h = http().get(format!("{base}/block-height/{height}")).timeout(Duration::from_secs(15)).send().await.map_err(|e| e.to_string())?;
            if !h.status().is_success() { return Err(format!("HTTP {}", h.status().as_u16())); }
            let hash = String::from_utf8(body_of(h).await?).map_err(|_| "block hash is not text".to_string())?; let hash = hash.trim().to_string();
            if hash.len() != 64 || !hash.bytes().all(|c| c.is_ascii_hexdigit()) { return Err("block hash malformed".into()); }
            let b = http().get(format!("{base}/block/{hash}")).timeout(Duration::from_secs(15)).send().await.map_err(|e| e.to_string())?;
            if !b.status().is_success() { return Err(format!("HTTP {}", b.status().as_u16())); }
            let v: Value = serde_json::from_slice(&body_of(b).await?).map_err(|_| "block json malformed".to_string())?;
            if v["id"].as_str().map(|x| x.eq_ignore_ascii_case(&hash)) != Some(true) || v["height"].as_u64() != Some(height) { return Err("explorer answer is for another block".into()); }
            let mr = v["merkle_root"].as_str().ok_or("no merkle_root")?.to_lowercase(); let ts = v["timestamp"].as_i64().ok_or("no timestamp")?;
            Ok::<_, String>((mr, ts * 1000))
        }.await;
        match one { Ok((m, t)) => got.push((m, t, name)), Err(e) => errs.push(format!("{name}: {e}")) }
        if got.len() == 2 { break; }
    }
    match got.len() { 0 => Err(format!("no explorer answered ({})", errs.join("; "))), 1 => Ok(got.remove(0)), _ => if got[0].0 == got[1].0 && got[0].1 == got[1].1 { Ok(got.remove(0)) } else { Err("two explorers disagree about this block".into()) } }
}

async fn run_ots_upgrade(sb: &Sb, job: &Value, id: i64) -> Result<(), String> {
    let digest: [u8; 32] = ac::from_hex(job["digest_hex"].as_str().unwrap_or("")).and_then(|v| v.try_into().ok()).ok_or("digest missing")?;
    let file = ac::from_hex(job["pending_hex"].as_str().unwrap_or("")).ok_or("pending proof missing")?;
    let (d, mut node) = ac::parse_detached(&file).map_err(|e| e.to_string())?;
    if d != digest { return Err("stored proof stamps another digest".into()); }
    let ls = ac::leaves(&node, &digest).map_err(|e| e.to_string())?;
    let (commit, cal) = ls.iter().find_map(|l| if let ac::Att::Pending(u) = &l.att { Some((l.commit.clone(), u.clone())) } else { None }).ok_or("no pending leaf left in the stored proof")?;
    if !url_ok(&cal) { return Err("calendar address in the proof is not allowed".into()); }
    let r = http().get(format!("{}/timestamp/{}", cal.trim_end_matches('/'), ac::to_hex(&commit))).timeout(Duration::from_secs(20)).header("Accept", "application/vnd.opentimestamps.v1").send().await.map_err(|e| format!("calendar unreachable: {e}"))?;
    if r.status().as_u16() == 404 { return Err("waiting for Bitcoin: the calendar has not confirmed this commitment yet".into()); }
    if !r.status().is_success() { return Err(format!("calendar answered HTTP {}", r.status().as_u16())); }
    let up = ac::parse_timestamp(&body_of(r).await?).map_err(|e| format!("upgrade answer is not a valid proof: {e}"))?;
    if !ac::upgrade_pending(&mut node, &digest, &commit, &up).map_err(|e| e.to_string())? { return Err("upgrade did not attach to the pending leaf".into()); }
    let ls = ac::leaves(&node, &digest).map_err(|e| e.to_string())?;
    let (bc, height) = ls.iter().find_map(|l| if let ac::Att::Bitcoin(h) = &l.att { Some((l.commit.clone(), *h)) } else { None }).ok_or("waiting for Bitcoin: the calendar answered but no Bitcoin block yet")?;
    let (mr, t_ms, via) = btc_header(height).await?;
    if !ac::bitcoin_commit_matches(&bc, &mr) { return Err(format!("Bitcoin block {height}: the proof's commitment is NOT the block's merkle root")); }
    let out = ac::detached_file(&digest, &node);
    let parsed = json!({"commit_hex": ac::to_hex(&bc), "btc_height": height, "btc_time_ms": t_ms, "merkle_root": mr, "explorer": via, "format": "opentimestamps-v1"});
    let res = sb.rpc("founder_anchor_record_ots", json!({"p_job": id, "p_stage": "ots_bitcoin", "p_evidence_hex": ac::to_hex(&out), "p_parsed": parsed})).await.ok_or("SQL refused the Bitcoin proof")?;
    if res.get("recorded").and_then(|x| x.as_bool()) == Some(false) { return Err(format!("not stored: {}", res["reason"].as_str().unwrap_or("?"))); }
    Ok(())
}

/// One tick (~60 s from the live loop): enqueue the newest signed checkpoints, lease due jobs, run them one by one. A failure is written to the job (backoff / dead letter in SQL) and never stops the tick.
pub async fn tick(sb: &Sb) -> Option<usize> {
    let _ = sb.rpc("founder_anchor_enqueue", json!({})).await?;
    let jobs = sb.rpc("founder_anchor_next", json!({"p_limit": 6})).await?;
    let mut n = 0;
    for j in jobs.as_array()? {
        let (Some(id), Some(kind), Some(name)) = (j["job_id"].as_i64(), j["kind"].as_str(), j["provider"].as_str()) else { continue };
        if !gap_ok(name, j["min_gap_secs"].as_u64().unwrap_or(5).clamp(1, 3600)) { continue; }
        let res = match (kind, j["state"].as_str()) { ("rfc3161", _) => run_tsa(sb, j, id).await, ("ots", Some("pending")) => run_ots_upgrade(sb, j, id).await, ("ots", _) => run_ots_submit(sb, j, id).await, _ => Err("unknown provider kind".into()) };
        match res { Ok(()) => n += 1, Err(e) => { let _ = sb.rpc("founder_anchor_fail", json!({"p_job": id, "p_error": e, "p_retryable": true})).await; } }
    }
    Some(n)
}

/// What the browser asks for: the newest time-anchored checkpoint with its evidence, the pulse and the DB's own re-check. The kernel re-verifies; this is only delivery.
pub async fn view(sb: &Sb) -> Value {
    let (g, p, v) = tokio::join!(sb.rpc("founder_anchor_get", json!({})), sb.rpc("founder_anchor_pulse", json!({})), sb.rpc("founder_anchor_verify", json!({"p_last": 50})));
    match (g, p) {
        (Some(g), Some(p)) if g.is_object() => json!({"connected": true, "anchor": g, "pulse": p, "db_recheck": v}),
        _ => json!({"connected": false, "reason": "Run the E124 SQL step (sql-run.sh) once."}),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn vecs() -> Value { serde_json::from_str(include_str!("../../rust/g5c_tsa_vectors.json")).unwrap() }
    #[test] fn url_rules() { assert!(url_ok("https://freetsa.org/tsr")); assert!(!url_ok("ftp://x")); assert!(!url_ok("https://a b")); assert!(!url_ok("https://a/?x=<")); }
    #[test] fn gap_blocks_a_second_call() { assert!(gap_ok("t-gap", 60)); assert!(!gap_ok("t-gap", 60)); }
    #[test] fn nonce_is_positive_der_integer() { for _ in 0..200 { let n = fresh_nonce().unwrap(); assert!((1..0x7f).contains(&n[0])); } }
    #[test] fn nonce_mismatch_is_refused_for_every_real_reply() {
        // OpenSSL replies carry their own nonce-less/ different nonce: a reply that is not for OUR nonce must never be accepted.
        for e in vecs()["vectors"].as_array().unwrap() {
            let d: [u8; 32] = ac::from_hex(e["digest_hex"].as_str().unwrap()).unwrap().try_into().unwrap();
            let r = ac::from_hex(e["reply_hex"].as_str().unwrap()).unwrap();
            let other = [0x11u8; 8];
            let got = check_tsa_reply(&r, &d, &other);
            if let Some(n) = e["nonce_hex"].as_str().filter(|n| !n.is_empty()) { assert!(n != "1111111111111111"); assert!(got.is_err(), "{}", e["name"]); }
        }
    }
    #[test] fn good_reply_with_its_own_nonce_is_accepted_and_tamper_is_not() {
        let mut ok = 0;
        for e in vecs()["vectors"].as_array().unwrap() {
            let Some(nh) = e["nonce_hex"].as_str().filter(|n| n.len() == 16) else { continue };
            let d: [u8; 32] = ac::from_hex(e["digest_hex"].as_str().unwrap()).unwrap().try_into().unwrap();
            let n: [u8; 8] = ac::from_hex(nh).unwrap().try_into().unwrap();
            let r = ac::from_hex(e["reply_hex"].as_str().unwrap()).unwrap();
            let (t, p) = check_tsa_reply(&r, &d, &n).unwrap();
            assert_eq!(p["signer_pin"], e["spki_sha256"]); assert!(t.gen_time_ms > 0); ok += 1;
            let mut bad = r.clone(); let k = bad.len() / 2; bad[k] ^= 0x40;
            if let Ok((t2, _)) = check_tsa_reply(&bad, &d, &n) { assert_eq!(t2.signer_pin, t.signer_pin); assert_eq!(t2.gen_time_ms, t.gen_time_ms); }
        }
        assert!(ok > 0, "no vector carried a usable nonce");
    }
    // R2 (3 Nov): freetsa signs with a P-384 key + ecdsa-with-SHA512, a pair ring does not have. These vectors come from OpenSSL acting as a TSA with the SAME key/hash pair.
    fn by_name(name: &str) -> Vec<Value> { vecs()["vectors"].as_array().unwrap().iter().filter(|e| e["name"] == name).cloned().collect() }
    fn open_vec(e: &Value) -> (Vec<u8>, [u8; 32], [u8; 8]) {
        (ac::from_hex(e["reply_hex"].as_str().unwrap()).unwrap(), ac::from_hex(e["digest_hex"].as_str().unwrap()).unwrap().try_into().unwrap(), ac::from_hex(e["nonce_hex"].as_str().unwrap()).unwrap().try_into().unwrap())
    }
    #[test] fn p384_sha512_reply_is_verified_by_rustcrypto_and_the_pair_is_exact() {
        let v = by_name("ec384x512"); assert_eq!(v.len(), 2);
        for e in &v {
            let (r, d, n) = open_vec(e); let (t, p) = check_tsa_reply(&r, &d, &n).unwrap();
            assert_eq!(t.kind, ac::SigKind::Ecdsa { curve: 384, hash: 512 }); assert_eq!(p["verified_by"], "rustcrypto-p384"); assert_eq!(p["signer_pin"], e["spki_sha256"]);
        }
        for e in &by_name("ec384x384") { let (r, d, n) = open_vec(e); let (t, p) = check_tsa_reply(&r, &d, &n).unwrap(); assert_eq!(t.kind, ac::SigKind::Ecdsa { curve: 384, hash: 384 }); assert_eq!(p["verified_by"], "ring"); }
    }
    #[test] fn p384_sha512_forgeries_are_refused() {
        let e = &by_name("ec384x512")[0]; let (r, d, n) = open_vec(e); let (t, _) = check_tsa_reply(&r, &d, &n).unwrap();
        // 1) one flipped bit anywhere in the signature, 2) one flipped bit in the signed attributes, 3) the other vector's signature under this key, 4) a compressed key, 5) a truncated key
        for bit in [0usize, 7, 100, t.signature.len() * 8 - 1] { let mut t2 = t.clone(); t2.signature[bit / 8] ^= 1 << (bit % 8); assert!(sig_verify(&t2).is_none(), "signature bit {bit}"); }
        for at in [0usize, t.signed_bytes.len() / 2, t.signed_bytes.len() - 1] { let mut t2 = t.clone(); t2.signed_bytes[at] ^= 0x01; assert!(sig_verify(&t2).is_none(), "signed byte {at}"); }
        let other = &by_name("ec384x512")[1]; let (r2, d2, n2) = open_vec(other); let (t3, _) = check_tsa_reply(&r2, &d2, &n2).unwrap();
        let mut t4 = t.clone(); t4.signature = t3.signature.clone(); assert!(sig_verify(&t4).is_none());
        let mut t5 = t.clone(); t5.key[0] = 0x02; t5.key.truncate(49); assert!(sig_verify(&t5).is_none());
        let mut t6 = t.clone(); t6.key.truncate(96); assert!(sig_verify(&t6).is_none());
        let mut t7 = t.clone(); t7.key[1] ^= 0x01; assert!(sig_verify(&t7).is_none(), "a point off the curve or another key");
        let mut t8 = t.clone(); t8.signature.push(0); assert!(sig_verify(&t8).is_none(), "trailing byte after the DER signature");
    }
    #[test] fn p256_sha512_is_refused_by_the_parser_because_nobody_verifies_it() {
        let e = &vecs()["refused_by_design"][0]; assert_eq!(e["name"], "ec256x512"); let (r, d, n) = open_vec(e);
        assert!(ac::parse_tsr(&r, &d, Some(&n)).is_err());
    }
    #[test] fn every_pair_the_parser_accepts_has_a_verifier() {
        // the contract in one place: whatever parse_tsr lets through, sig_verify must be able to say yes to for a genuine token.
        let mut seen = std::collections::BTreeSet::new();
        for e in vecs()["vectors"].as_array().unwrap() { let (r, d, n) = open_vec(e); if let Ok(t) = ac::parse_tsr(&r, &d, Some(&n)) { assert!(sig_verify(&t).is_some(), "{}", e["name"]); seen.insert(format!("{:?}", t.kind)); } }
        assert!(seen.contains("Ecdsa { curve: 384, hash: 512 }") && seen.contains("Ecdsa { curve: 384, hash: 384 }") && seen.contains("Ecdsa { curve: 256, hash: 256 }"), "{seen:?}");
    }
    #[test] fn flipping_any_byte_of_a_p384_sha512_reply_never_changes_an_accepted_claim() {
        // the same property anchor_core proves against ring, here against the RustCrypto verifier: a tampered reply is refused, or it still says exactly what the genuine one said.
        let e = &by_name("ec384x512")[0]; let (r, d, n) = open_vec(e); let (good, _) = check_tsa_reply(&r, &d, &n).unwrap();
        for i in 0..r.len() { let mut m = r.clone(); m[i] ^= 0x01; if let Ok((t, _)) = check_tsa_reply(&m, &d, &n) { assert_eq!((t.gen_time_ms, &t.signer_pin, &t.serial_hex), (good.gen_time_ms, &good.signer_pin, &good.serial_hex), "byte {i}"); } }
    }
}
