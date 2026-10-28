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
    /// Founder's own profile row (display name + photo). None = table/row unavailable (never invented).
    pub async fn profile(&self, uid: &str) -> Option<Value> {
        if uid.is_empty() || !uid.chars().all(|c| c.is_ascii_hexdigit() || c == '-') { return None; }
        self.rows(&format!("account_profiles?select=display_name,legal_name,avatar_url&user_id=eq.{uid}&limit=1")).await?.into_iter().next()
    }
    /// Set or clear (None) the founder's own photo. Only that one column, only that user's row.
    pub async fn set_avatar(&self, uid: &str, url: Option<&str>) -> bool {
        if uid.is_empty() || !uid.chars().all(|c| c.is_ascii_hexdigit() || c == '-') { return false; }
        let body = serde_json::json!({"avatar_url": url, "updated_at": chrono_now()});
        let r = self.http.patch(format!("{}/rest/v1/account_profiles?user_id=eq.{}", self.url, uid)).header("apikey", &self.key)
            .header("authorization", format!("Bearer {}", self.key)).header("prefer", "return=representation").json(&body).send().await;
        match r { Ok(r) if r.status().is_success() => r.json::<Vec<Value>>().await.map(|v| !v.is_empty()).unwrap_or(false), _ => false }
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

fn chrono_now() -> String {
    let d = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    // RFC3339 UTC without extra deps
    let (days, rem) = (d / 86400, d % 86400);
    let (mut y, mut dd) = (1970i64, days as i64);
    loop { let yl = if (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 { 366 } else { 365 }; if dd >= yl { dd -= yl; y += 1; } else { break; } }
    let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
    let ml = [31, if leap { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut m = 0; while dd >= ml[m] { dd -= ml[m]; m += 1; }
    format!("{y:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z", m + 1, dd + 1, rem / 3600, rem % 3600 / 60, rem % 60)
}
