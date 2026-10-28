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
    /// All of the founder's own settings as one JSON object (key -> value). None = database unavailable / E108 not applied (never invented).
    pub async fn settings(&self, uid: &str) -> Option<Value> {
        if uid.is_empty() || !uid.chars().all(|c| c.is_ascii_hexdigit() || c == '-') { return None; }
        self.rpc("founder_settings_get", serde_json::json!({"p_uid": uid})).await
    }
    /// One atomic write through the SQL door (validation + history + audit inside). Err = (HTTP status from PostgREST, message).
    pub async fn setting_set(&self, uid: &str, key: &str, value: &Value) -> Result<Value, (u16, String)> {
        let r = self.http.post(format!("{}/rest/v1/rpc/founder_setting_set", self.url)).header("apikey", &self.key)
            .header("authorization", format!("Bearer {}", self.key)).json(&serde_json::json!({"p_uid": uid, "p_key": key, "p_value": value})).send().await.map_err(|_| (0u16, "database unreachable".to_string()))?;
        let st = r.status().as_u16();
        let body: Value = r.json().await.unwrap_or(Value::Null);
        if (200..300).contains(&st) { Ok(body) } else { Err((st, body["message"].as_str().unwrap_or("").to_string())) }
    }
    pub async fn is_founder(&self, uid: &str) -> bool {
        if uid.is_empty() || !uid.chars().all(|c| c.is_ascii_hexdigit() || c == '-') { return false; } // injection se bachao
        self.rows(&format!("founder_accounts?select=user_id&user_id=eq.{uid}&limit=1")).await.map(|r| !r.is_empty()).unwrap_or(false)
    }
    /// Founder token ka device ab bhi approved aur revoke nahi? (har request par; revoke foran asar)
    pub async fn device_ok(&self, uid: &str, did: &str) -> bool {
        let id_ok = |s: &str| !s.is_empty() && s.chars().all(|c| c.is_ascii_hexdigit() || c == '-');
        if !id_ok(uid) || !id_ok(did) { return false; }
        matches!(self.rpc("founder_device_ok", serde_json::json!({"p_uid": uid, "p_device": did})).await, Some(Value::Bool(true)))
    }
    pub async fn jwks(&self) -> Vec<crate::jwt_core::Jwk> {
        let Ok(r) = self.http.get(format!("{}/auth/v1/.well-known/jwks.json", self.url)).send().await else { return vec![] };
        match r.json::<Value>().await { Ok(d) => crate::jwt_core::parse_jwks(&d), Err(_) => vec![] }
    }
}

