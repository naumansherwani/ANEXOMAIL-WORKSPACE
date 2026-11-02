//! G5b — signed checkpoints (C2SP signed-note / tlog-checkpoint) for the founder audit ledger. Technology: Rust (ring Ed25519). The note rule lives ONCE in
//! `server/rust/checkpoint_core.rs` (shared with the browser kernel, Rule 52). This file only: holds the audit-log key, signs each seal, SELF-VERIFIES the note with
//! the strict verifier, and only then hands it to the SQL door (E123), which re-derives the body from the seal. Key = its own file (0400), NOT the response-signing key.
use crate::checkpoint_core as cp;
use crate::ledger::merkle;
use ring::signature::{ED25519, Ed25519KeyPair, KeyPair, UnparsedPublicKey};
use serde_json::{Value, json};
use std::sync::OnceLock;

pub const DEFAULT_NAME: &str = "founderworkspace.anexomail.com/audit-log";

pub struct LogKey { pair: Ed25519KeyPair, pub name: String, pub pubkey: [u8; 32] }

impl LogKey {
    pub fn from_pkcs8(der: &[u8], name: &str) -> Option<LogKey> {
        if !cp::valid_name(name) { return None; }
        let pair = Ed25519KeyPair::from_pkcs8(der).ok()?;
        let pubkey: [u8; 32] = pair.public_key().as_ref().try_into().ok()?;
        Some(LogKey { pair, name: name.to_string(), pubkey })
    }
    pub fn pub_hex(&self) -> String { merkle::to_hex(&self.pubkey) }
    pub fn key_id_hex(&self) -> String { cp::key_id(&self.name, &self.pubkey).iter().map(|b| format!("{b:02x}")).collect() }
    /// Sign the checkpoint for (size, root) and refuse to return anything our own strict verifier would not accept.
    pub fn note(&self, size: u64, root: &[u8; 32]) -> Option<String> {
        let body = cp::body(&self.name, size, root);
        let sig: [u8; 64] = self.pair.sign(body.as_bytes()).as_ref().try_into().ok()?;
        let note = cp::assemble(&body, &[cp::sig_line(&self.name, &self.pubkey, &sig)]);
        let pk = self.pubkey;
        let ok = cp::verify(&note, &self.name, &pk, size, root, &|m, s| UnparsedPublicKey::new(&ED25519, pk).verify(m, s).is_ok());
        if ok == cp::Verdict::Ok { Some(note) } else { None }
    }
}

static KEY: OnceLock<Option<LogKey>> = OnceLock::new();
/// Loaded once per process from FOUNDER_AUDITLOG_KEY_FILE (default /etc/anexomail/founder-auditlog.p8); no file = the feature is simply OFF (the gauge says so).
pub fn key() -> Option<&'static LogKey> {
    KEY.get_or_init(|| {
        let path = std::env::var("FOUNDER_AUDITLOG_KEY_FILE").unwrap_or_else(|_| "/etc/anexomail/founder-auditlog.p8".into());
        let name = std::env::var("FOUNDER_AUDITLOG_NAME").unwrap_or_else(|_| DEFAULT_NAME.into());
        let k = std::fs::read(&path).ok().and_then(|d| LogKey::from_pkcs8(&d, &name));
        eprintln!("founder: audit-log signing {}", if k.is_some() { "ON" } else { "OFF (no key file)" });
        k
    }).as_ref()
}

/// Called from the live tick right after `auto_seal`: sign every seal that has no signed note yet. Returns how many were stored.
/// A failure never stops the tick; the next tick retries, and the gauge shows `unsigned`.
pub async fn sign_pending(sb: &crate::data::Sb) -> Option<usize> {
    let k = key()?;
    let pend = sb.rpc("founder_audit_signed_cp_pending", json!({"p_limit": 20})).await?;
    let pend = pend.as_array()?;
    if pend.is_empty() { return Some(0); }
    let who = sb.rows("founder_accounts?select=user_id&limit=1").await?;
    let uid = who.first()?.get("user_id")?.as_str()?.to_string();
    if uid.is_empty() || !uid.chars().all(|c| c.is_ascii_hexdigit() || c == '-') { return None; }
    let reg = sb.rpc("founder_audit_log_key_register", json!({"p_actor": uid, "p_name": k.name, "p_pub_hex": k.pub_hex(), "p_key_id_hex": k.key_id_hex()})).await?;
    let key_id = reg.get("id")?.as_i64()?;
    let mut n = 0;
    for p in pend {
        let (id, size, root) = (p.get("cp_id")?.as_i64()?, p.get("size")?.as_u64()?, merkle::from_hex(p.get("root")?.as_str()?)?);
        let Some(note) = k.note(size, &root) else { continue };
        if let Some(r) = sb.rpc("founder_audit_signed_cp_add", json!({"p_cp_id": id, "p_key_id": key_id, "p_note": note})).await {
            if r.get("added").and_then(|a| a.as_bool()) == Some(true) { n += 1; }
        }
    }
    Some(n)
}

/// What the browser asks for: the newest signed note + the key list + the pulse. The kernel verifies; this is only delivery.
pub async fn view(sb: &crate::data::Sb) -> Value {
    let (g, p) = tokio::join!(sb.rpc("founder_audit_signed_cp_get", json!({})), sb.rpc("founder_audit_signed_pulse", json!({})));
    match (g, p) {
        (Some(g), Some(p)) if g.is_object() => json!({"connected": true, "signing": key().is_some(), "signed": g, "pulse": p}),
        _ => json!({"connected": false, "signing": key().is_some(), "reason": "Run the E123 SQL step (sql-run.sh) once."}),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn seed_key(seed: [u8; 32], name: &str) -> LogKey {
        let pair = Ed25519KeyPair::from_seed_unchecked(&seed).unwrap();
        let pubkey: [u8; 32] = pair.public_key().as_ref().try_into().unwrap();
        LogKey { pair, name: name.into(), pubkey }
    }
    #[test]
    fn go_vector_signed_the_same_bytes() {
        let v: Value = serde_json::from_str(include_str!("../../rust/g5b_vectors.json")).unwrap();
        let k0 = &v["keys"][0];
        let h = |s: &str| -> Vec<u8> { (0..s.len() / 2).map(|i| u8::from_str_radix(&s[2 * i..2 * i + 2], 16).unwrap()).collect() };
        let key = seed_key(h(k0["seed_hex"].as_str().unwrap()).try_into().unwrap(), k0["name"].as_str().unwrap());
        assert_eq!(key.pub_hex(), k0["pub_hex"].as_str().unwrap());
        assert_eq!(key.key_id_hex(), k0["key_id_hex"].as_str().unwrap());
        let mut n = 0;
        for x in v["vectors"].as_array().unwrap().iter().filter(|x| x["key"] == 0) {
            let root: [u8; 32] = h(x["root_hex"].as_str().unwrap()).try_into().unwrap();
            assert_eq!(key.note(x["size"].as_u64().unwrap(), &root).unwrap(), x["note"].as_str().unwrap());
            n += 1;
        }
        assert!(n >= 10);
    }
    #[test]
    fn bad_names_and_keys_are_refused() {
        assert!(LogKey::from_pkcs8(b"not a key", DEFAULT_NAME).is_none());
        let der = crate::sign::EdKeys::generate_pkcs8().unwrap();
        assert!(LogKey::from_pkcs8(&der, "has space/x").is_none());
        assert!(LogKey::from_pkcs8(&der, "a+b").is_none());
        assert!(LogKey::from_pkcs8(&der, "").is_none());
        assert!(LogKey::from_pkcs8(&der, DEFAULT_NAME).is_some());
    }
    #[test]
    fn a_fresh_key_signs_and_the_strict_verifier_agrees() {
        let der = crate::sign::EdKeys::generate_pkcs8().unwrap();
        let k = LogKey::from_pkcs8(&der, DEFAULT_NAME).unwrap();
        let root = [9u8; 32];
        let n = k.note(31, &root).unwrap();
        let pk = k.pubkey;
        let ver = |size, r: &[u8; 32]| cp::verify(&n, DEFAULT_NAME, &pk, size, r, &|m, s| UnparsedPublicKey::new(&ED25519, pk).verify(m, s).is_ok());
        assert_eq!(ver(31, &root), cp::Verdict::Ok);
        assert!(matches!(ver(32, &root), cp::Verdict::Bad(_)));
        assert!(n.starts_with("founderworkspace.anexomail.com/audit-log\n31\n"));
        assert!(n.contains("\n\n\u{2014} founderworkspace.anexomail.com/audit-log "));
    }
}
