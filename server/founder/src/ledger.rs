//! Audit ledger Merkle (master order step 5, F2c; SQL = E107). Rust side: whitelisted query parsing, an independent Rust check of every exported
//! proof (second witness next to SQL), and the automatic checkpoint. Technology: Rust (axum, tokio). The tree rule lives ONCE in `server/rust/merkle_core.rs`
//! (included here by path, so the server and the browser kernel can never disagree). Nothing is invented: a missing E107 answers `connected:false`.
use serde_json::{Value, json};

#[path = "../../rust/merkle_core.rs"]
pub mod merkle;

pub const EXPORT_MAX: i64 = 200;

#[derive(Debug, PartialEq)]
pub struct ProofQ { pub seq: i64, pub upto: Option<i64> }
#[derive(Debug, PartialEq)]
pub struct RangeQ { pub from: i64, pub to: i64 }

fn num(v: &str, what: &'static str) -> Result<i64, &'static str> {
    if v.is_empty() || v.len() > 18 || !v.bytes().all(|b| b.is_ascii_digit()) { return Err(what); }
    let n: i64 = v.parse().map_err(|_| what)?;
    if n < 1 { return Err(what); }
    Ok(n)
}

/// `seq=<n>[&upto=<n>]` only.
pub fn parse_proof(q: Option<&str>) -> Result<ProofQ, &'static str> {
    let (mut seq, mut upto) = (None, None);
    for pair in q.unwrap_or("").split('&').filter(|p| !p.is_empty()) {
        let (k, v) = pair.split_once('=').unwrap_or((pair, ""));
        match k { "seq" => seq = Some(num(v, "invalid seq")?), "upto" => upto = Some(num(v, "invalid upto")?), _ => return Err("unknown parameter") }
    }
    let seq = seq.ok_or("missing seq")?;
    if let Some(u) = upto { if u < seq { return Err("upto before seq"); } }
    Ok(ProofQ { seq, upto })
}

/// `id=<n>` only: one seal (checkpoint) by number. The browser asks for the seal it pinned earlier to prove history was not rewritten.
pub fn parse_seal(q: Option<&str>) -> Result<i64, &'static str> {
    let mut id = None;
    for pair in q.unwrap_or("").split('&').filter(|p| !p.is_empty()) {
        let (k, v) = pair.split_once('=').unwrap_or((pair, ""));
        match k { "id" => id = Some(num(v, "invalid id")?), _ => return Err("unknown parameter") }
    }
    id.ok_or("missing id")
}

/// `first=<n>&second=<n>` only, first <= second: the two ledger sizes a consistency proof is asked for (G5a).
pub fn parse_consistency(q: Option<&str>) -> Result<(i64, i64), &'static str> {
    let (mut first, mut second) = (None, None);
    for pair in q.unwrap_or("").split('&').filter(|p| !p.is_empty()) {
        let (k, v) = pair.split_once('=').unwrap_or((pair, ""));
        match k { "first" => first = Some(num(v, "invalid first")?), "second" => second = Some(num(v, "invalid second")?), _ => return Err("unknown parameter") }
    }
    let (first, second) = (first.ok_or("missing first")?, second.ok_or("missing second")?);
    if second < first { return Err("second before first"); }
    Ok((first, second))
}

/// `from=<n>&to=<n>`, at most EXPORT_MAX rows.
pub fn parse_range(q: Option<&str>) -> Result<RangeQ, &'static str> {
    let (mut from, mut to) = (None, None);
    for pair in q.unwrap_or("").split('&').filter(|p| !p.is_empty()) {
        let (k, v) = pair.split_once('=').unwrap_or((pair, ""));
        match k { "from" => from = Some(num(v, "invalid from")?), "to" => to = Some(num(v, "invalid to")?), _ => return Err("unknown parameter") }
    }
    let (from, to) = (from.ok_or("missing from")?, to.ok_or("missing to")?);
    if to < from { return Err("to before from"); }
    if to - from >= EXPORT_MAX { return Err("range too long (200 rows max)"); }
    Ok(RangeQ { from, to })
}

pub fn missing() -> Value { json!({"connected": false, "note": "founder_audit_merkle_pulse not answering - run the E107 SQL (sql-run.sh)"}) }

/// Rust's own check of a SQL export: every row's path must lead to the exported root. Returns {checked, ok, bad_seqs}. A malformed row counts as bad.
pub fn check_export(ex: &Value) -> Value {
    let root = ex.get("root").and_then(|r| r.as_str()).and_then(merkle::from_hex);
    let rows = ex.get("rows").and_then(|r| r.as_array()).cloned().unwrap_or_default();
    let (mut ok, mut bad) = (0u32, Vec::new());
    for r in &rows {
        let good = (|| {
            let root = root?;
            let hash = merkle::from_hex(r.get("hash")?.as_str()?)?;
            let items: Vec<(String, String)> = r.get("path")?.as_array()?.iter()
                .map(|p| Some((p.get("s")?.as_str()?.to_string(), p.get("h")?.as_str()?.to_string()))).collect::<Option<_>>()?;
            Some(merkle::verify(&hash, &merkle::path_from_json(&items)?, &root))
        })().unwrap_or(false);
        if good { ok += 1; } else { bad.push(r.get("seq").cloned().unwrap_or(Value::Null)); }
    }
    json!({"checked": rows.len(), "ok": ok, "bad_seqs": bad, "all_ok": root.is_some() && ok as usize == rows.len() && !rows.is_empty()})
}

/// G5a: Rust's own check of a SQL consistency answer (second witness): the proof must carry the sizes and roots it claims. false on any malformed field.
pub fn check_consistency(v: &Value) -> bool {
    (|| {
        let (first, second) = (v.get("first")?.as_u64()?, v.get("second")?.as_u64()?);
        let (fr, sr) = (merkle::from_hex(v.get("first_root")?.as_str()?)?, merkle::from_hex(v.get("second_root")?.as_str()?)?);
        let proof: Vec<_> = v.get("proof")?.as_array()?.iter().map(|x| merkle::from_hex(x.as_str()?)).collect::<Option<_>>()?;
        Some(merkle::verify_consistency(first, second, &fr, &sr, &proof))
    })().unwrap_or(false)
}

/// Called from the live tick (every ~60 s): if the pulse says a checkpoint is due, seal the ledger. The actor is the founder account (the audit row
/// says "automatic checkpoint (system)"). Failure never stops the tick: the gauge simply shows the lag and the next try follows.
pub async fn auto_seal(sb: &crate::data::Sb) -> Option<bool> {
    let p = sb.rpc("founder_audit_merkle_pulse", json!({})).await?;
    if p.get("due").and_then(|d| d.as_bool()) != Some(true) { return Some(false); }
    let who = sb.rows("founder_accounts?select=user_id&limit=1").await?;
    let uid = who.first()?.get("user_id")?.as_str()?.to_string();
    if uid.is_empty() || !uid.chars().all(|c| c.is_ascii_hexdigit() || c == '-') { return None; }
    let r = sb.rpc("founder_audit_checkpoint", json!({"p_actor": uid, "p_reason": "automatic checkpoint (system, ledger rows since last seal reached the policy)"})).await?;
    Some(r.get("created").and_then(|c| c.as_bool()).unwrap_or(false))
}

/// G4 (E120): is a FULL ledger check (chain + seals re-hashed) due? Yes when none has ever run, or the last one is older than the policy interval.
/// Pure on purpose (unit tested). A pulse without `policy` (E120 not installed) is never "due": we do not call a door that does not exist.
pub fn verify_due(pulse: &Value) -> bool {
    let Some(every) = pulse.pointer("/policy/verify_every_secs").and_then(|v| v.as_i64()) else { return false };
    match pulse.get("full_check") {
        None | Some(Value::Null) => true,
        Some(fc) => fc.get("age_s").and_then(|a| a.as_i64()).map_or(true, |age| age >= every),
    }
}

/// Called from the live tick (every ~60 s) next to `auto_seal`: when a full check is due, run it (SQL does the real re-hash and records the result).
/// SQL rate-limits itself (one run per 60 s), so a restart loop cannot hammer the database. Returns Some(ran).
pub async fn auto_verify(sb: &crate::data::Sb) -> Option<bool> {
    let p = sb.rpc("founder_audit_merkle_pulse", json!({})).await?;
    if !verify_due(&p) { return Some(false); }
    let r = sb.rpc("founder_audit_verify_record", json!({"p_source": "rust"})).await?;
    Some(r.get("ran").and_then(|c| c.as_bool()).unwrap_or(false))
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::merkle::*;
    use sha2::{Digest, Sha256};

    #[test]
    fn seal_query_is_whitelisted() {
        assert_eq!(parse_seal(Some("id=7")), Ok(7));
        assert!(parse_seal(None).is_err());
        assert!(parse_seal(Some("id=0")).is_err());
        assert!(parse_seal(Some("id=-1")).is_err());
        assert!(parse_seal(Some("id=1;drop")).is_err());
        assert!(parse_seal(Some("id=1&x=2")).is_err());
        assert!(parse_seal(Some("id=1234567890123456789")).is_err());
    }
    /// G5a three-way check: the Python reference (docs/cursor-work/server/g5a-reference.py, written from the RFC) produced these vectors; Rust must produce the
    /// SAME proof bytes for every (m, n) with n <= 40 and its verifier must accept them. SQL E121 carries literal vectors from the same reference.
    #[test]
    fn rust_matches_the_independent_python_reference_byte_for_byte() {
        use super::merkle::{consistency_proof, from_hex, leaf, to_hex, verify_consistency};
        use sha2::{Digest, Sha256};
        let v: Value = serde_json::from_str(include_str!("../../rust/consistency_vectors.json")).unwrap();
        let max_n = v["max_n"].as_u64().unwrap() as usize;
        let leaves: Vec<_> = (1..=max_n).map(|g| leaf(&Sha256::digest(format!("founder-merkle-vector-{g}").as_bytes()).into())).collect();
        let cases = v["cases"].as_array().unwrap();
        assert_eq!(cases.len(), max_n * (max_n + 1) / 2, "the vector file must hold every pair");
        for c in cases {
            let (m, n) = (c["m"].as_u64().unwrap() as usize, c["n"].as_u64().unwrap() as usize);
            let want: Vec<String> = c["proof"].as_array().unwrap().iter().map(|x| x.as_str().unwrap().to_string()).collect();
            let got: Vec<String> = consistency_proof(&leaves, m, n).unwrap().iter().map(to_hex).collect();
            assert_eq!(got, want, "proof differs from Python for m={m} n={n}");
            let (fr, sr) = (from_hex(c["first_root"].as_str().unwrap()).unwrap(), from_hex(c["second_root"].as_str().unwrap()).unwrap());
            let proof: Vec<_> = want.iter().map(|h| from_hex(h).unwrap()).collect();
            assert!(verify_consistency(m as u64, n as u64, &fr, &sr, &proof), "Rust refused a Python proof m={m} n={n}");
        }
    }
    #[test]
    fn consistency_query_is_whitelisted() {
        assert_eq!(parse_consistency(Some("first=3&second=9")), Ok((3, 9)));
        assert_eq!(parse_consistency(Some("second=9&first=9")), Ok((9, 9)));
        for bad in [None, Some("first=3"), Some("second=3"), Some("first=9&second=3"), Some("first=0&second=3"), Some("first=1&second=2&x=1"), Some("first=a&second=2"), Some("first=1;&second=2")] { assert!(parse_consistency(bad).is_err(), "{bad:?}"); }
    }
    #[test]
    fn rust_checks_a_consistency_answer_and_refuses_a_changed_one() {
        use super::merkle::*;
        let l: Vec<H32> = (1..=9usize).map(|g| leaf(&sha2::Sha256::digest(format!("founder-merkle-vector-{g}").as_bytes()).into())).collect();
        let pr: Vec<String> = consistency_proof(&l, 5, 9).unwrap().iter().map(to_hex).collect();
        let good = json!({"first": 5, "second": 9, "first_root": to_hex(&mth(&l[..5])), "second_root": to_hex(&mth(&l)), "proof": pr});
        assert!(check_consistency(&good));
        let mut bad = good.clone(); bad["second"] = json!(0); assert!(!check_consistency(&bad));
        let mut bad = good.clone(); bad["proof"][0] = json!("zz"); assert!(!check_consistency(&bad));
        let mut bad = good.clone(); bad["second_root"] = json!(to_hex(&mth(&l[..8]))); assert!(!check_consistency(&bad));
        assert!(!check_consistency(&json!({"connected": false})));
    }
    #[test]
    fn proof_query_is_whitelisted() {
        assert_eq!(parse_proof(Some("seq=5")).unwrap(), ProofQ { seq: 5, upto: None });
        assert_eq!(parse_proof(Some("seq=5&upto=9")).unwrap(), ProofQ { seq: 5, upto: Some(9) });
        for bad in ["", "seq=0", "seq=-1", "seq=abc", "seq=5&upto=4", "seq=5&evil=1", "upto=3", "seq=1234567890123456789", "seq=5%27"] { assert!(parse_proof(Some(bad)).is_err(), "{bad}"); }
        assert!(parse_proof(None).is_err());
    }
    #[test]
    fn range_query_is_whitelisted_and_capped() {
        assert_eq!(parse_range(Some("from=3&to=10")).unwrap(), RangeQ { from: 3, to: 10 });
        assert!(parse_range(Some("from=1&to=200")).is_ok());
        for bad in ["from=1&to=201", "from=5&to=4", "from=1", "to=3", "from=0&to=3", "from=a&to=3", "from=1&to=3&x=1"] { assert!(parse_range(Some(bad)).is_err(), "{bad}"); }
        assert!(parse_range(None).is_err());
    }

    fn export_of(n: usize) -> Value {
        let rows: Vec<H32> = (1..=n).map(|g| Sha256::digest(format!("founder-merkle-vector-{g}").as_bytes()).into()).collect();
        let lv = levels(&rows.iter().map(leaf).collect::<Vec<_>>());
        let root = to_hex(&lv.last().unwrap()[0]);
        let items: Vec<Value> = (0..n).map(|i| json!({"seq": i + 1, "hash": to_hex(&rows[i]),
            "path": path(&lv, i).unwrap().iter().map(|(s, h)| json!({"s": if *s == Side::L { "L" } else { "R" }, "h": to_hex(h)})).collect::<Vec<_>>()})).collect();
        json!({"root": root, "rows": items})
    }
    #[test]
    fn rust_second_witness_accepts_a_good_export() {
        for n in [1, 2, 3, 7, 8, 9, 33] { let c = check_export(&export_of(n)); assert_eq!(c["all_ok"], true, "n={n}"); assert_eq!(c["ok"], n as u64); }
    }
    #[test]
    fn full_check_is_due_when_never_run_or_older_than_the_policy() {
        let p = |fc: Value| json!({"policy": {"verify_every_secs": 1800}, "full_check": fc});
        assert!(verify_due(&p(Value::Null)), "never run -> due");
        assert!(verify_due(&p(json!({"age_s": 1800}))), "exactly the interval -> due");
        assert!(verify_due(&p(json!({"age_s": 99999}))), "old -> due");
        assert!(!verify_due(&p(json!({"age_s": 1799}))), "fresh -> not due");
        assert!(verify_due(&p(json!({"chain_ok": true}))), "a result with no age is not trusted as fresh");
        assert!(!verify_due(&json!({"full_check": null})), "E120 not installed (no policy) -> never call the missing door");
        assert!(!verify_due(&json!({"connected": false})), "E107 missing -> not due");
    }

    #[test]
    fn rust_second_witness_catches_every_kind_of_tamper() {
        let mut ex = export_of(9);
        ex["rows"][4]["hash"] = json!("0".repeat(64));
        let c = check_export(&ex); assert_eq!(c["all_ok"], false); assert_eq!(c["bad_seqs"], json!([5]));
        let mut ex = export_of(9); ex["root"] = json!("f".repeat(64));
        assert_eq!(check_export(&ex)["all_ok"], false);
        let mut ex = export_of(9); ex["rows"][2]["path"][0]["s"] = json!("X");
        assert_eq!(check_export(&ex)["bad_seqs"], json!([3]));
        let mut ex = export_of(9); ex["rows"][2]["path"] = json!("not-an-array");
        assert_eq!(check_export(&ex)["bad_seqs"], json!([3]));
        assert_eq!(check_export(&json!({"root": "ab".repeat(32), "rows": []}))["all_ok"], false, "no rows is not a pass");
        assert_eq!(check_export(&json!({"rows": []}))["all_ok"], false);
    }
}
