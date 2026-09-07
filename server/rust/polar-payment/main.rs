// ============================================================================
// ANEXOMAIL — POLAR RUST PAYMENT ENGINE  (PM2: polar-rust-payment, :3400)
//
// NANO COMMAND (server par):
//   mkdir -p /opt/polar-rust-payment/src
//   nano /opt/polar-rust-payment/src/main.rs   # select all -> paste -> Ctrl+O, Ctrl+X
//   cd /opt/polar-rust-payment && cargo build --release && pm2 restart polar-rust-payment
//
// LIFETIME DESIGN (locked 5 Sep 2026):
//   1. DECOUPLED: webhook = verify -> INSERT into polar_webhook_inbox -> 200 OK (<300ms).
//      State sync Postgres trigger karta hai. Polar ko hamesha instant 200 milta hai,
//      is liye webhook kabhi auto-disable nahi hota.
//   2. SECRETS: sirf /opt/polar-rust-payment/.env mein. Koi deployment ise touch
//      nahi karta (repo mein .env nahi jaata).
//   3. FAIL-SAFE: top-level catch — internal error par bhi Polar ko 200 jaata hai
//      (sirf invalid signature = 401, kyunki woh asli reject hai).
//   4. NO TOUCH: yeh file ek dafa deploy hone ke baad regenerate nahi hoti.
//
// ENV (/opt/polar-rust-payment/.env):
//   PORT=3400
//   DATABASE_URL=postgres://...            # Supabase #4 pooler (session mode)
//   POLAR_ACCESS_TOKEN=polar_oat_...
//   POLAR_WEBHOOK_SECRET=whsec_...         # Polar dashboard se as-is (prefix samet)
//   PUBLIC_APP_URL=https://anexomail.com
//   POLAR_PRODUCT_PLAN_BASIC_MONTHLY=5e1c7b50-fee5-4214-873c-ad9f350476d9
//   POLAR_PRODUCT_PLAN_BASIC_YEARLY=d3642ce7-a750-484c-940f-eb39039ed9c2
//   POLAR_PRODUCT_PLAN_PRO_MONTHLY=df1aa320-346f-451b-a16a-e737c0703e12
//   POLAR_PRODUCT_PLAN_PRO_YEARLY=7d87a72e-6be6-4aa2-86d6-5eca3d448956
//   POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY=b12be1b1-a02d-4701-9475-08e796d99b69
//   POLAR_PRODUCT_PLAN_BUSINESS_YEARLY=7a1d5445-92c5-4472-81a3-4820b8579854
//   POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY=3a1e1699-59c0-4334-8be0-d4b08a1202d1
//   POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY=80bca014-b832-474e-bd3e-084a04453de0
//   POLAR_PRODUCT_PRIORITY_SUPPORT=8f6d7c8e-1722-421f-b28c-2a031f63731d
//
// ROUTES
//   GET  /health                       -> engine + db state (truth, no fake)
//   POST /api/v1/polar-webhook         -> Polar webhook receiver (instant 200)
//   POST /api/v1/checkout              -> checkout session banao (guest + signed-in)
//   GET  /api/v1/checkout/:id          -> checkout state verify (success page)
//   GET  /api/v1/billing/:user_id      -> plan + due + grace (in-app billing panel)
// ============================================================================

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use base64::{engine::general_purpose::STANDARD as B64, Engine as _};
use hmac::{Hmac, Mac};
use serde::Deserialize;
use serde_json::{json, Value};
use sha2::Sha256;
use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;
use std::{collections::HashMap, env, net::SocketAddr, sync::Arc};
use subtle::ConstantTimeEq;

type HmacSha256 = Hmac<Sha256>;

struct AppState {
    db: PgPool,
    http: reqwest::Client,
    webhook_secret: String,
    polar_token: String,
    app_url: String,
    products: HashMap<String, String>,
}

fn product_map() -> HashMap<String, String> {
    let mut map = HashMap::new();
    for (k, v) in env::vars() {
        if let Some(key) = k.strip_prefix("POLAR_PRODUCT_") {
            if !v.trim().is_empty() {
                map.insert(key.to_string(), v.trim().to_string());
            }
        }
    }
    map
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt().with_target(false).init();

    let db_url = env::var("DATABASE_URL").expect("DATABASE_URL missing");
    let db = PgPoolOptions::new()
        .max_connections(10)
        .connect(&db_url)
        .await?;

    let state = Arc::new(AppState {
        db,
        http: reqwest::Client::new(),
        webhook_secret: env::var("POLAR_WEBHOOK_SECRET").unwrap_or_default(),
        polar_token: env::var("POLAR_ACCESS_TOKEN").unwrap_or_default(),
        app_url: env::var("PUBLIC_APP_URL").unwrap_or_else(|_| "https://anexomail.com".into()),
        products: product_map(),
    });

    let app = Router::new()
        .route("/health", get(health))
        .route("/api/v1/polar-webhook", post(handle_polar_webhook))
        .route("/api/v1/checkout", post(create_checkout))
        .route("/api/v1/checkout/:id", get(read_checkout))
        .route("/api/v1/billing/:user_id", get(read_billing))
        .layer(tower_http::cors::CorsLayer::permissive())
        .with_state(state);

    let port: u16 = env::var("PORT").ok().and_then(|p| p.parse().ok()).unwrap_or(3400);
    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    tracing::info!("polar-rust-payment listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;
    Ok(())
}

async fn health(State(s): State<Arc<AppState>>) -> impl IntoResponse {
    let db_ok = sqlx::query("select 1").fetch_one(&s.db).await.is_ok();
    Json(json!({
        "service": "polar-rust-payment",
        "db": db_ok,
        "webhook_secret": !s.webhook_secret.is_empty(),
        "polar_token": !s.polar_token.is_empty(),
        "products": s.products.len(),
    }))
}

// ---------------------------------------------------------------------------
// SIGNATURE — Polar docs (8 Sep 2026 cutoff) LOCK:
//   Polar sirf EK header bhejta hai: webhook-signature = "v1,<base64 sig>"
//   signed content = "{webhook-id}.{webhook-timestamp}.{raw body}"
//   HMAC key secret ki UMR par depend karti hai:
//     A) Standard Webhooks (secret 8 Sep 2026 00:00 UTC ke BAAD banaya/reset):
//        key = base64-decode( whsec_ strip karke )  — Standard Webhooks spec
//     B) Polar HMAC (us se PEHLE ka secret):
//        key = UTF-8 bytes of FULL `whsec_...` string (as-is, koi decode nahi)
//   Polar SDKs 1.0.0-alpha.19+ bhi dono keys try karte hain — hum bhi dono.
//   Fallback: legacy `x-polar-signature` = hex HMAC of raw body (dono keys).
// ---------------------------------------------------------------------------
fn secret_keys(secret: &str) -> Vec<Vec<u8>> {
    let full = secret.trim();
    let raw = full.strip_prefix("whsec_").unwrap_or(full);
    let mut keys: Vec<Vec<u8>> = Vec::with_capacity(2);
    // A) Standard Webhooks key: prefix strip -> base64 decode
    if let Ok(decoded) = B64.decode(raw) {
        keys.push(decoded);
    }
    // B) Polar HMAC key: poora whsec_ string ke UTF-8 bytes, as-is
    keys.push(full.as_bytes().to_vec());
    keys
}

fn hmac_ok(key: &[u8], msg: &[u8], expected: &[u8]) -> bool {
    let Ok(mut mac) = HmacSha256::new_from_slice(key) else {
        return false;
    };
    mac.update(msg);
    let got = mac.finalize().into_bytes();
    got.as_slice().ct_eq(expected).into()
}

fn verify_signature(s: &AppState, headers: &HeaderMap, body: &[u8]) -> bool {
    if s.webhook_secret.is_empty() {
        return false;
    }
    let key = secret_bytes(&s.webhook_secret);
    let h = |name: &str| headers.get(name).and_then(|v| v.to_str().ok()).unwrap_or("");

    // 1. Standard Webhooks (Polar default)
    let sig_header = h("webhook-signature");
    if !sig_header.is_empty() {
        let id = h("webhook-id");
        let ts = h("webhook-timestamp");
        let signed = format!("{id}.{ts}.{}", String::from_utf8_lossy(body));
        for part in sig_header.split_whitespace() {
            let sig = part.strip_prefix("v1,").unwrap_or(part);
            if let Ok(raw) = B64.decode(sig) {
                if hmac_ok(&key, signed.as_bytes(), &raw) {
                    return true;
                }
            }
        }
    }

    // 2. Legacy hex signature over raw body
    let legacy = h("x-polar-signature");
    if !legacy.is_empty() {
        if let Ok(raw) = hex::decode(legacy.trim()) {
            if hmac_ok(&key, body, &raw) {
                return true;
            }
        }
    }
    false
}

// ---------------------------------------------------------------------------
// WEBHOOK — verify -> insert -> instant 200. Koi business logic yahan nahi.
// ---------------------------------------------------------------------------
async fn handle_polar_webhook(
    State(s): State<Arc<AppState>>,
    headers: HeaderMap,
    body: axum::body::Bytes,
) -> impl IntoResponse {
    if !verify_signature(&s, &headers, &body) {
        // Asli reject: secret ghalat hai. Polar dashboard se secret dobara set karo.
        tracing::warn!("polar webhook: invalid signature");
        return (StatusCode::UNAUTHORIZED, "Invalid Signature");
    }

    let payload: Value = match serde_json::from_slice(&body) {
        Ok(v) => v,
        Err(_) => {
            tracing::error!("polar webhook: invalid json");
            return (StatusCode::OK, "Logged internally");
        }
    };

    let header_id = headers
        .get("webhook-id")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .to_string();
    let event_id = payload
        .get("data")
        .and_then(|d| d.get("id"))
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .filter(|_| !header_id.is_empty() || true)
        .unwrap_or_default();
    let event_id = if !header_id.is_empty() { header_id } else { event_id };
    let event_type = payload
        .get("type")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown")
        .to_string();

    let result = sqlx::query(
        r#"insert into public.polar_webhook_inbox (event_id, event_type, payload)
           values ($1, $2, $3)
           on conflict (event_id) do nothing"#,
    )
    .bind(&event_id)
    .bind(&event_type)
    .bind(&payload)
    .execute(&s.db)
    .await;

    match result {
        Ok(_) => (StatusCode::OK, "Event Accepted"),
        Err(e) => {
            // FAIL-SAFE: internal error Polar ka masla nahi — 200 hi bhejo,
            // warna 5 retries ke baad Polar webhook block kar deta hai.
            tracing::error!("polar webhook insert failed: {e:?}");
            (StatusCode::OK, "Logged internally")
        }
    }
}

// ---------------------------------------------------------------------------
// CHECKOUT — card click se seedha Polar checkout. Guest bhi allowed.
// ---------------------------------------------------------------------------
#[derive(Deserialize)]
struct CheckoutBody {
    product_key: String,
    #[serde(default)]
    user_id: Option<String>,
    #[serde(default)]
    email: Option<String>,
    #[serde(default)]
    seats: Option<i32>,
    /// Jahan user kaam kar raha tha — payment ke baad wahin wapas bhejte hain.
    #[serde(default)]
    return_to: Option<String>,
}

fn safe_return_to(raw: &Option<String>) -> String {
    match raw {
        Some(p) if p.starts_with('/') && !p.starts_with("//") => p.clone(),
        _ => "/app/billing".to_string(),
    }
}

async fn create_checkout(
    State(s): State<Arc<AppState>>,
    Json(body): Json<CheckoutBody>,
) -> impl IntoResponse {
    if s.polar_token.is_empty() {
        return (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(json!({"error": "polar_token_missing"})),
        );
    }
    let Some(product_id) = s.products.get(&body.product_key).cloned() else {
        return (
            StatusCode::BAD_REQUEST,
            Json(json!({"error": "unknown_product_key", "product_key": body.product_key})),
        );
    };

    let return_to = safe_return_to(&body.return_to);
    let success_url = format!(
        "{}/checkout/done?checkout_id={{CHECKOUT_ID}}&return_to={}",
        s.app_url, return_to
    );

    let mut payload = json!({
        "products": [product_id],
        "success_url": success_url,
        "metadata": {
            "brand": "anexomail",
            "product_key": body.product_key,
            "seats": body.seats.unwrap_or(1).to_string(),
            "return_to": return_to,
        }
    });
    if let Some(uid) = body.user_id.as_ref().filter(|u| !u.is_empty()) {
        payload["external_customer_id"] = json!(uid);
    }
    if let Some(email) = body.email.as_ref().filter(|e| e.contains('@')) {
        payload["customer_email"] = json!(email);
    }

    let sent = s
        .http
        .post("https://api.polar.sh/v1/checkouts/")
        .bearer_auth(&s.polar_token)
        .json(&payload)
        .send()
        .await;

    let response = match sent {
        Ok(r) => r,
        Err(e) => {
            tracing::error!("polar checkout request failed: {e:?}");
            return (
                StatusCode::BAD_GATEWAY,
                Json(json!({"error": "polar_unreachable"})),
            );
        }
    };
    let status = response.status();
    let data: Value = response.json().await.unwrap_or(json!({}));
    if !status.is_success() {
        tracing::error!("polar checkout rejected: {status} {data}");
        return (
            StatusCode::BAD_GATEWAY,
            Json(json!({"error": "polar_rejected", "detail": data})),
        );
    }

    let url = data.get("url").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let checkout_id = data.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();

    let _ = sqlx::query(
        r#"insert into public.polar_checkout_log
             (checkout_id, product_key, product_id, user_id, email, return_to, payload)
           values ($1,$2,$3,$4::uuid,$5,$6,$7)
           on conflict (checkout_id) do nothing"#,
    )
    .bind(&checkout_id)
    .bind(&body.product_key)
    .bind(&product_id)
    .bind(body.user_id.clone())
    .bind(body.email.clone())
    .bind(&return_to)
    .bind(&data)
    .execute(&s.db)
    .await;

    (
        StatusCode::OK,
        Json(json!({"url": url, "checkout_id": checkout_id, "return_to": return_to})),
    )
}

async fn read_checkout(
    State(s): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    if s.polar_token.is_empty() {
        return (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(json!({"error": "polar_token_missing"})),
        );
    }
    let sent = s
        .http
        .get(format!("https://api.polar.sh/v1/checkouts/{id}"))
        .bearer_auth(&s.polar_token)
        .send()
        .await;
    match sent {
        Ok(r) => {
            let data: Value = r.json().await.unwrap_or(json!({}));
            let status = data.get("status").and_then(|v| v.as_str()).unwrap_or("unknown");
            let return_to = data
                .get("metadata")
                .and_then(|m| m.get("return_to"))
                .and_then(|v| v.as_str())
                .unwrap_or("/app/billing");
            (
                StatusCode::OK,
                Json(json!({"status": status, "return_to": return_to})),
            )
        }
        Err(_) => (
            StatusCode::BAD_GATEWAY,
            Json(json!({"error": "polar_unreachable"})),
        ),
    }
}

// ---------------------------------------------------------------------------
// BILLING STATE — plan, next due, grace (3 din), block kabhi nahi.
// ---------------------------------------------------------------------------
async fn read_billing(
    State(s): State<Arc<AppState>>,
    Path(user_id): Path<String>,
) -> impl IntoResponse {
    let row: Result<(Value,), sqlx::Error> =
        sqlx::query_as("select public.polar_billing_state($1::uuid) as state")
            .bind(&user_id)
            .fetch_one(&s.db)
            .await;
    match row {
        Ok((state,)) => (StatusCode::OK, Json(state)),
        Err(e) => {
            tracing::error!("billing state failed: {e:?}");
            (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(json!({"error": "billing_state_unavailable"})),
            )
        }
    }
}
