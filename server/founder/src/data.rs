//! Supabase REST (service role) — sirf founder binary ke paas. Network yahin; hisaab bridge.rs mein.
use serde_json::Value;

#[derive(Clone)]
pub struct Sb { pub url: String, pub key: String, pub http: reqwest::Client }

impl Sb {
    pub fn from_env() -> Option<Sb> {
        let url = std::env::var("SUPABASE4_URL").ok()?.trim_end_matches('/').to_string();
        let key = std::env::var("SUPABASE4_SERVICE_ROLE_KEY").ok()?;
        Some(Sb { url, key, http: reqwest::Client::builder().timeout(std::time::Duration::from_secs(8)).build().ok()? })
    }
    fn req(&self, path: &str) -> reqwest::RequestBuilder {
        self.http.get(format!("{}/rest/v1/{}", self.url, path)).header("apikey", &self.key).header("authorization", format!("Bearer {}", self.key))
    }
    pub async fn rows(&self, path: &str) -> Option<Vec<Value>> {
        let r = self.req(path).send().await.ok()?;
        if !r.status().is_success() { return None; }
        r.json::<Vec<Value>>().await.ok()
    }
    pub async fn count(&self, path: &str) -> Option<i64> {
        let r = self.req(path).header("prefer", "count=exact").header("range", "0-0").send().await.ok()?;
        if !r.status().is_success() && r.status().as_u16() != 416 { return None; }
        r.headers().get("content-range")?.to_str().ok()?.split('/').nth(1)?.parse().ok()
    }
    /// PostgREST RPC (service_role). Jawab JSON value (null bhi valid) ya None (error).
    pub async fn rpc(&self, name: &str, body: Value) -> Option<Value> {
        let r = self.http.post(format!("{}/rest/v1/rpc/{}", self.url, name)).header("apikey", &self.key)
            .header("authorization", format!("Bearer {}", self.key)).json(&body).send().await.ok()?;
        if !r.status().is_success() { return None; }
        r.json::<Value>().await.ok()
    }
    pub async fn is_founder(&self, uid: &str) -> bool {
        if uid.is_empty() || !uid.chars().all(|c| c.is_ascii_hexdigit() || c == '-') { return false; } // injection se bachao
        self.rows(&format!("founder_accounts?select=user_id&user_id=eq.{uid}&limit=1")).await.map(|r| !r.is_empty()).unwrap_or(false)
    }
    pub async fn jwks(&self) -> Vec<crate::jwt_core::Jwk> {
        let Ok(r) = self.http.get(format!("{}/auth/v1/.well-known/jwks.json", self.url)).send().await else { return vec![] };
        match r.json::<Value>().await { Ok(d) => crate::jwt_core::parse_jwks(&d), Err(_) => vec![] }
    }
}
