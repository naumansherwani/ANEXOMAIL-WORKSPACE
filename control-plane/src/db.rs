// CONTROL PLANE db.rs (D5a-3b): the ONLY database call is `select cp.lookup($1)::text` as role cp_lookup (EXECUTE on that one function, no table right).
use serde_json::Value;
use std::{sync::Arc, time::Duration};
use tokio_postgres::{config::SslMode, Client, Config, NoTls};

pub struct Pg { url: String, ca: Option<String>, c: tokio::sync::Mutex<Option<Arc<Client>>> }
impl Pg {
    pub fn new(url: String, ca: Option<String>) -> Pg { Pg { url, ca, c: tokio::sync::Mutex::new(None) } }
    async fn open(&self) -> Result<Client, String> {
        let cfg: Config = self.url.parse().map_err(|_| "CP_DB_URL is not a valid postgres url".to_string())?;
        if cfg.get_ssl_mode() == SslMode::Disable { let (c, conn) = cfg.connect(NoTls).await.map_err(|e| e.to_string())?; tokio::spawn(async move { let _ = conn.await; }); return Ok(c); }
        let mut roots = rustls::RootCertStore::empty();
        for c in rustls_native_certs::load_native_certs().certs { let _ = roots.add(c); }
        if let Some(p) = &self.ca { let pem = std::fs::read(p).map_err(|e| format!("CP_DB_CA {p}: {e}"))?; for c in rustls_pemfile::certs(&mut pem.as_slice()).flatten() { roots.add(c).map_err(|e| e.to_string())?; } }
        let tls = rustls::ClientConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider())).with_safe_default_protocol_versions().map_err(|e| e.to_string())?.with_root_certificates(roots).with_no_client_auth();
        let (c, conn) = cfg.connect(tokio_postgres_rustls::MakeRustlsConnect::new(tls)).await.map_err(|e| e.to_string())?;
        tokio::spawn(async move { let _ = conn.await; }); Ok(c)
    }
    async fn client(&self) -> Result<Arc<Client>, String> {
        let mut g = self.c.lock().await;
        if let Some(c) = g.as_ref() { if !c.is_closed() { return Ok(c.clone()); } }
        let c = Arc::new(self.open().await?); *g = Some(c.clone()); Ok(c)
    }
    /// Ok(None) = no such company; Err = database unavailable (the caller answers 503, never a made-up value).
    pub async fn lookup(&self, company: &str) -> Result<Option<Value>, String> {
        let work = async {
            let c = self.client().await?;
            let r = c.query_one("select cp.lookup($1::text)::text", &[&company]).await.map_err(|e| e.to_string())?;
            let t: Option<String> = r.get(0);
            match t { None => Ok(None), Some(s) => serde_json::from_str(&s).map(Some).map_err(|e| e.to_string()) }
        };
        tokio::time::timeout(Duration::from_secs(5), work).await.map_err(|_| "database timeout".to_string())?
    }
    /// Phase 1m-5 B6: `select cp.deliverability()::text` (counts only). Err = database unavailable (503).
    pub async fn deliverability(&self) -> Result<Option<Value>, String> {
        let work = async {
            let c = self.client().await?;
            let r = c.query_one("select cp.deliverability()::text", &[]).await.map_err(|e| e.to_string())?;
            let t: Option<String> = r.get(0);
            match t { None => Ok(None), Some(s) => serde_json::from_str(&s).map(Some).map_err(|e| e.to_string()) }
        };
        tokio::time::timeout(Duration::from_secs(8), work).await.map_err(|_| "database timeout".to_string())?
    }
    /// Phase 1m-4 B9: `select cp.census($1)::text` (counts only). Ok(None) = the function refused the limits (null); Err = database unavailable (503, never a made-up number).
    pub async fn census(&self, limits: &Value) -> Result<Option<Value>, String> {
        let arg = limits.to_string();
        let work = async {
            let c = self.client().await?;
            let r = c.query_one("select cp.census($1::text::jsonb)::text", &[&arg]).await.map_err(|e| e.to_string())?;
            let t: Option<String> = r.get(0);
            match t { None => Ok(None), Some(s) => serde_json::from_str(&s).map(Some).map_err(|e| e.to_string()) }
        };
        tokio::time::timeout(Duration::from_secs(8), work).await.map_err(|_| "database timeout".to_string())?
    }
    /// Phase 1m Z4b B13: ONE of cp.consent_push / cp.consent_cancel / cp.consent_poll (the only consent doors cp_lookup may run; it has no right to decide). Ok(None) = the database refused (null); Err = database unavailable (503).
    pub async fn consent(&self, call: &crate::consent::Call) -> Result<Option<Value>, String> {
        use crate::consent::Call;
        let work = async {
            let c = self.client().await?;
            let r = match call {
                Call::Push { consent, company, case_ref, scope, reason } => c.query_one("select cp.consent_push($1::text::uuid, $2::text, $3::text, $4::text, $5::text)::text", &[consent, company, case_ref, scope, reason]).await,
                Call::Cancel { consent } => c.query_one("select cp.consent_cancel($1::text::uuid)::text", &[consent]).await,
                Call::Poll { consents } => c.query_one("select cp.consent_poll($1::text[]::uuid[])::text", &[consents]).await,
            }.map_err(|e| e.to_string())?;
            let t: Option<String> = r.get(0);
            match t { None => Ok(None), Some(s) => serde_json::from_str(&s).map(Some).map_err(|e| e.to_string()) }
        };
        tokio::time::timeout(Duration::from_secs(8), work).await.map_err(|_| "database timeout".to_string())?
    }
}
