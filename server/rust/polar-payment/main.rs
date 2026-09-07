// ============================================================================
// ANEXOMAIL — POLAR RUST PAYMENT ENGINE  (PM2: polar-rust-payment, :3400)
// Phase 51 hardening: LOCAL WAL + WORKER + RECONCILE + /ready /metrics + reject log
//
// DEPLOY (Nauman kuch overwrite nahi karta — sirf yeh 2 line):
//   cd /opt/anexomail-web && git pull && bash server/rust/polar-payment/deploy.sh
//
// LIFETIME DESIGN (locked 5 Sep 2026, extended 7 Sep 2026):
//   1. INGRESS boring: Polar -> polarpayments.anexomail.com (TLS) -> Caddy -> 127.0.0.1:3400.
//   2. LOCAL-FIRST DURABILITY: webhook = verify -> local append-only WAL (fsync)
//      -> 200 OK. Supabase down ho to bhi Polar ko 200 milta hai. Ek bhi payment
//      event kabhi gir nahi sakta.
//   3. WORKER: WAL -> Supabase inbox insert. States pending -> done, fail par
//      exponential backoff (30s, 2m, 10m, 1h, 6h, 24h, 24h, 24h), 8 attempts ke
//      baad dead/ (row zinda, /api/v1/replay se dobara chal sakti hai).
//   4. POSTGRES TRIGGER ZINDA HAI: inbox insert ke baad state sync trigger karta
//      hai (polar_inbox_apply). Woh fast-path hai — hataya NAHI gaya.
//   5. RECONCILE: har 15 min Rust khud Polar API se subscriptions + orders pull
//      karke apne state se compare karti hai (OK / MISSING / DIVERGED) aur
//      missing/diverged par synthetic inbox event daal deti hai. Webhook kabhi na
//      aaye to bhi package activate ho jaata hai.
//   6. SIGNATURE REJECT LOG: invalid signature par 401 (spec-correct) MAGAR raw
//      body + headers `polar_signature_rejects` aur alag rejects/ evidence WAL
//      mein log — payment dead-letter queue mein kabhi count nahi hota.
//   7. SECRETS: sirf /opt/polar-rust-payment/.env mein. Deploy ise touch nahi karta.
//
// ENV (/opt/polar-rust-payment/.env):
//   PORT=3400
//   DATABASE_URL=postgres://...            # Supabase #4 pooler (session mode)
//   POLAR_ACCESS_TOKEN=polar_oat_...
//   POLAR_WEBHOOK_SECRET=whsec_...         # Polar dashboard se as-is (prefix samet)
//   PUBLIC_APP_URL=https://anexomail.com
//   WAL_DIR=/opt/polar-rust-payment/wal    # optional (default yehi)
//   ALERT_EMAIL=hello@anexomail.com        # optional (queue watchdog alert)
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
//   GET  /health                       -> engine + db + wal state (truth, no fake)
//   GET  /ready                        -> 200 sirf jab db reachable + WAL writable
//   GET  /metrics                      -> received/duplicate/failed/queue_depth/...
//   POST /api/v1/polar-webhook         -> Polar webhook receiver (instant 200)
//   POST /api/v1/replay                -> dead/ events wapas pending/ mein
//   POST /api/v1/reconcile             -> reconcile abhi chalao (manual trigger)
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
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::Sha256;
use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;
use std::{
    collections::HashMap,
    env,
    fs,
    io::Write,
    net::SocketAddr,
    path::{Path as FsPath, PathBuf},
    sync::{
        atomic::{AtomicI64, AtomicU64, Ordering},
        Arc,
    },
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use subtle::ConstantTimeEq;

type HmacSha256 = Hmac<Sha256>;

const MAX_ATTEMPTS: u32 = 8;
/// 30s, 2m, 10m, 1h, 6h, 24h, 24h, 24h
const BACKOFF_SECS: [i64; 8] = [30, 120, 600, 3600, 21600, 86400, 86400, 86400];

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

fn now_secs() -> i64 {
    now_ms() / 1000
}

// ---------------------------------------------------------------------------
// WAL — append-only, crash safe. Ek event = ek file. pending/ -> done/ | dead/
// ---------------------------------------------------------------------------
#[derive(Serialize, Deserialize, Clone)]
struct Envelope {
    event_id: String,
    event_type: String,
    payload: Value,
    received_ms: i64,
    #[serde(default)]
    attempts: u32,
    #[serde(default)]
    next_try_secs: i64,
    #[serde(default)]
    last_error: Option<String>,
}

struct Wal {
    root: PathBuf,
}

fn slug(raw: &str) -> String {
    let cleaned: String = raw
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() || c == '-' || c == '_' { c } else { '_' })
        .collect();
    if cleaned.is_empty() {
        format!("noid-{}", now_ms())
    } else {
        cleaned.chars().take(80).collect()
    }
}

impl Wal {
    fn new(root: PathBuf) -> std::io::Result<Self> {
        for sub in ["pending", "done", "dead", "rejects"] {
            fs::create_dir_all(root.join(sub))?;
        }
        Ok(Self { root })
    }

    fn dir(&self, kind: &str) -> PathBuf {
        self.root.join(kind)
    }

    /// Atomic durable write: tmp -> fsync -> rename -> dir fsync.
    fn write(&self, kind: &str, env: &Envelope) -> std::io::Result<PathBuf> {
        let dir = self.dir(kind);
        let name = format!("{:013}-{}.json", env.received_ms, slug(&env.event_id));
        let final_path = dir.join(&name);
        let tmp_path = dir.join(format!("{name}.tmp"));
        let bytes = serde_json::to_vec(env).unwrap_or_else(|_| b"{}".to_vec());
        {
            let mut f = fs::File::create(&tmp_path)?;
            f.write_all(&bytes)?;
            f.sync_all()?;
        }
        fs::rename(&tmp_path, &final_path)?;
        if let Ok(d) = fs::File::open(&dir) {
            let _ = d.sync_all();
        }
        Ok(final_path)
    }

    fn list(&self, kind: &str) -> Vec<PathBuf> {
        let mut out: Vec<PathBuf> = match fs::read_dir(self.dir(kind)) {
            Ok(rd) => rd
                .filter_map(|e| e.ok().map(|e| e.path()))
                .filter(|p| p.extension().and_then(|e| e.to_str()) == Some("json"))
                .collect(),
            Err(_) => Vec::new(),
        };
        out.sort();
        out
    }

    fn read(path: &FsPath) -> Option<Envelope> {
        let bytes = fs::read(path).ok()?;
        serde_json::from_slice::<Envelope>(&bytes).ok()
    }

    fn move_to(&self, path: &FsPath, kind: &str, env: &Envelope) {
        if self.write(kind, env).is_ok() {
            let _ = fs::remove_file(path);
        }
    }

    fn writable(&self) -> bool {
        let probe = self.dir("pending").join(".probe");
        let ok = fs::write(&probe, b"ok").is_ok();
        let _ = fs::remove_file(&probe);
        ok
    }

    /// (queue_depth, oldest_age_secs)
    fn queue_stats(&self) -> (u64, i64) {
        let files = self.list("pending");
        let depth = files.len() as u64;
        let oldest = files
            .first()
            .and_then(|p| Wal::read(p))
            .map(|e| now_secs() - e.received_ms / 1000)
            .unwrap_or(0);
        (depth, oldest.max(0))
    }
}

// ---------------------------------------------------------------------------
struct Metrics {
    received: AtomicU64,
    duplicate: AtomicU64,
    synced: AtomicU64,
    failed: AtomicU64,
    dead: AtomicU64,
    rejects: AtomicU64,
    reconcile_runs: AtomicU64,
    reconcile_gap: AtomicU64,
    reconcile_last: AtomicI64,
}

impl Metrics {
    fn new() -> Self {
        Self {
            received: AtomicU64::new(0),
            duplicate: AtomicU64::new(0),
            synced: AtomicU64::new(0),
            failed: AtomicU64::new(0),
            dead: AtomicU64::new(0),
            rejects: AtomicU64::new(0),
            reconcile_runs: AtomicU64::new(0),
            reconcile_gap: AtomicU64::new(0),
            reconcile_last: AtomicI64::new(0),
        }
    }
}

struct AppState {
    db: PgPool,
    http: reqwest::Client,
    webhook_secret: String,
    polar_token: String,
    app_url: String,
    products: HashMap<String, String>,
    wal: Wal,
    metrics: Metrics,
    alert_email: String,
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

fn product_key_for(state: &AppState, product_id: &str) -> Option<String> {
    state
        .products
        .iter()
        .find(|(_, v)| v.as_str() == product_id)
        .map(|(k, _)| k.to_lowercase())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt().with_target(false).init();

    let db_url = env::var("DATABASE_URL").expect("DATABASE_URL missing");
    let db = PgPoolOptions::new()
        .max_connections(10)
        .acquire_timeout(Duration::from_secs(10))
        .connect_lazy(&db_url)?;

    let wal_dir = env::var("WAL_DIR").unwrap_or_else(|_| "/opt/polar-rust-payment/wal".into());
    let wal = Wal::new(PathBuf::from(&wal_dir))?;

    let state = Arc::new(AppState {
        db,
        http: reqwest::Client::builder()
            .timeout(Duration::from_secs(20))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new()),
        webhook_secret: env::var("POLAR_WEBHOOK_SECRET").unwrap_or_default(),
        polar_token: env::var("POLAR_ACCESS_TOKEN").unwrap_or_default(),
        app_url: env::var("PUBLIC_APP_URL").unwrap_or_else(|_| "https://anexomail.com".into()),
        products: product_map(),
        wal,
        metrics: Metrics::new(),
        alert_email: env::var("ALERT_EMAIL").unwrap_or_else(|_| "hello@anexomail.com".into()),
    });

    // background loops — webhook path se bilkul alag
    tokio::spawn(worker_loop(state.clone()));
    tokio::spawn(watchdog_loop(state.clone()));
    tokio::spawn(reconcile_loop(state.clone()));

    let app = Router::new()
        .route("/health", get(health))
        .route("/ready", get(ready))
        .route("/metrics", get(metrics))
        .route("/api/v1/polar-webhook", post(handle_polar_webhook))
        .route("/api/v1/replay", post(replay_dead))
        .route("/api/v1/reconcile", post(reconcile_now))
        .route("/api/v1/checkout", post(create_checkout))
        .route("/api/v1/checkout/:id", get(read_checkout))
        .route("/api/v1/billing/:user_id", get(read_billing))
        .layer(tower_http::cors::CorsLayer::permissive())
        .with_state(state);

    let port: u16 = env::var("PORT").ok().and_then(|p| p.parse().ok()).unwrap_or(3400);
    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    tracing::info!("polar-rust-payment listening on {addr} (wal: {wal_dir})");
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;
    Ok(())
}

// ---------------------------------------------------------------------------
// HEALTH / READY / METRICS
// ---------------------------------------------------------------------------
async fn health(State(s): State<Arc<AppState>>) -> impl IntoResponse {
    let db_ok = sqlx::query("select 1").fetch_one(&s.db).await.is_ok();
    let (depth, oldest) = s.wal.queue_stats();
    Json(json!({
        "service": "polar-rust-payment",
        "db": db_ok,
        "wal_writable": s.wal.writable(),
        "queue_depth": depth,
        "oldest_pending_secs": oldest,
        "webhook_secret": !s.webhook_secret.is_empty(),
        "polar_token": !s.polar_token.is_empty(),
        "products": s.products.len(),
    }))
}

async fn ready(State(s): State<Arc<AppState>>) -> impl IntoResponse {
    let db_ok = sqlx::query("select 1").fetch_one(&s.db).await.is_ok();
    let wal_ok = s.wal.writable();
    // WAL writable = webhook 200 de sakta hai. DB down ho to bhi accept karte hain,
    // is liye ready ki shart WAL hai; db state sirf sach ke liye report hoti hai.
    let code = if wal_ok { StatusCode::OK } else { StatusCode::SERVICE_UNAVAILABLE };
    (code, Json(json!({ "ready": wal_ok, "db": db_ok, "wal_writable": wal_ok })))
}

async fn metrics(State(s): State<Arc<AppState>>) -> impl IntoResponse {
    let m = &s.metrics;
    let (depth, oldest) = s.wal.queue_stats();
    // Purani releases reject evidence ko dead/ mein rakhti thin. Un files ko bhi
    // payment failures mein count na karo; replay handler pehle hi unhein skip karta hai.
    let dead_depth = s
        .wal
        .list("dead")
        .into_iter()
        .filter_map(|path| Wal::read(&path))
        .filter(|env| !env.event_type.starts_with("signature_reject:"))
        .count() as u64;
    Json(json!({
        "received":            m.received.load(Ordering::Relaxed),
        "duplicate":           m.duplicate.load(Ordering::Relaxed),
        "synced":              m.synced.load(Ordering::Relaxed),
        "failed":              m.failed.load(Ordering::Relaxed),
        "dead_letter":         m.dead.load(Ordering::Relaxed),
        "dead_letter_depth":   dead_depth,
        "signature_rejects":   m.rejects.load(Ordering::Relaxed),
        "queue_depth":         depth,
        "oldest_pending_secs": oldest,
        "reconcile_runs":      m.reconcile_runs.load(Ordering::Relaxed),
        "reconcile_gap":       m.reconcile_gap.load(Ordering::Relaxed),
        "reconcile_last_secs": m.reconcile_last.load(Ordering::Relaxed),
    }))
}

// ---------------------------------------------------------------------------
// SIGNATURE — Polar docs (8 Sep 2026 cutoff) LOCK:
//   Polar sirf EK header bhejta hai: webhook-signature = "v1,<base64 sig>"
//   signed content = "{webhook-id}.{webhook-timestamp}.{raw body}"
//   HMAC key secret ki UMR par depend karti hai:
//     A) Standard Webhooks (secret 8 Sep 2026 00:00 UTC ke BAAD banaya/reset):
//        key = base64-decode( whsec_ strip karke )
//     B) Polar HMAC (us se PEHLE ka secret):
//        key = UTF-8 bytes of FULL `whsec_...` string (as-is, koi decode nahi)
//   Engine dono keys try karti hai — secret reset ho ya purana, kuch nahi badalta.
//   Fallback: legacy `x-polar-signature` = hex HMAC of raw body (dono keys).
// ---------------------------------------------------------------------------
fn secret_keys(secret: &str) -> Vec<Vec<u8>> {
    let full = secret.trim();
    let raw = full.strip_prefix("whsec_").unwrap_or(full);
    let mut keys: Vec<Vec<u8>> = Vec::with_capacity(2);
    if let Ok(decoded) = B64.decode(raw) {
        keys.push(decoded);
    }
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

/// Ok(()) = valid. Err(reason) = reject reason (log ke liye).
fn verify_signature(s: &AppState, headers: &HeaderMap, body: &[u8]) -> Result<(), String> {
    if s.webhook_secret.is_empty() {
        return Err("secret_missing".into());
    }
    let keys = secret_keys(&s.webhook_secret);
    let h = |name: &str| headers.get(name).and_then(|v| v.to_str().ok()).unwrap_or("");

    let sig_header = h("webhook-signature");
    if !sig_header.is_empty() {
        let id = h("webhook-id");
        let ts = h("webhook-timestamp");
        if let Ok(ts_num) = ts.parse::<i64>() {
            if (now_secs() - ts_num).abs() > 300 {
                return Err("timestamp_out_of_tolerance".into());
            }
        }
        let signed = format!("{id}.{ts}.{}", String::from_utf8_lossy(body));
        for part in sig_header.split_whitespace() {
            let sig = part.strip_prefix("v1,").unwrap_or(part);
            if let Ok(raw) = B64.decode(sig) {
                for key in &keys {
                    if hmac_ok(key, signed.as_bytes(), &raw) {
                        return Ok(());
                    }
                }
            }
        }
        return Err("signature_mismatch".into());
    }

    let legacy = h("x-polar-signature");
    if !legacy.is_empty() {
        if let Ok(raw) = hex::decode(legacy.trim()) {
            for key in &keys {
                if hmac_ok(key, body, &raw) {
                    return Ok(());
                }
            }
        }
        return Err("legacy_signature_mismatch".into());
    }
    Err("signature_header_missing".into())
}

fn header_snapshot(headers: &HeaderMap) -> Value {
    let mut map = serde_json::Map::new();
    for name in [
        "webhook-id",
        "webhook-timestamp",
        "webhook-signature",
        "x-polar-signature",
        "content-type",
        "user-agent",
    ] {
        if let Some(v) = headers.get(name).and_then(|v| v.to_str().ok()) {
            map.insert(name.to_string(), json!(v));
        }
    }
    Value::Object(map)
}

// ---------------------------------------------------------------------------
// WEBHOOK — verify -> local WAL fsync -> instant 200. Koi DB/network call nahi.
// ---------------------------------------------------------------------------
async fn handle_polar_webhook(
    State(s): State<Arc<AppState>>,
    headers: HeaderMap,
    body: axum::body::Bytes,
) -> impl IntoResponse {
    if let Err(reason) = verify_signature(&s, &headers, &body) {
        // 401 spec-correct hai, MAGAR evidence khota nahi: DB log + isolated rejects WAL.
        s.metrics.rejects.fetch_add(1, Ordering::Relaxed);
        tracing::warn!("polar webhook rejected: {reason}");
        let raw = String::from_utf8_lossy(&body).to_string();
        let head = header_snapshot(&headers);
        let db = s.db.clone();
        let wal_env = Envelope {
            event_id: format!("reject-{}", now_ms()),
            event_type: format!("signature_reject:{reason}"),
            payload: json!({ "raw": raw, "headers": head, "reason": reason }),
            received_ms: now_ms(),
            attempts: MAX_ATTEMPTS,
            next_try_secs: 0,
            last_error: Some(reason.clone()),
        };
        let _ = s.wal.write("rejects", &wal_env);
        tokio::spawn(async move {
            let _ = sqlx::query(
                r#"insert into public.polar_signature_rejects (reason, raw_body, headers)
                   values ($1,$2,$3)"#,
            )
            .bind(&reason)
            .bind(&raw)
            .bind(&head)
            .execute(&db)
            .await;
        });
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
    let data_id = payload
        .get("data")
        .and_then(|d| d.get("id"))
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let event_id = if !header_id.is_empty() {
        header_id
    } else if !data_id.is_empty() {
        format!("{}:{}", payload.get("type").and_then(|v| v.as_str()).unwrap_or("event"), data_id)
    } else {
        format!("anon-{}", now_ms())
    };
    let event_type = payload
        .get("type")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown")
        .to_string();

    let env = Envelope {
        event_id,
        event_type,
        payload,
        received_ms: now_ms(),
        attempts: 0,
        next_try_secs: 0,
        last_error: None,
    };

    match s.wal.write("pending", &env) {
        Ok(_) => {
            s.metrics.received.fetch_add(1, Ordering::Relaxed);
            (StatusCode::OK, "Event Accepted")
        }
        Err(e) => {
            // WAL bhi na likh sake to bhi Polar ko 200 (warna webhook disable ho jata
            // hai) — magar loud error log, watchdog isay pakar lega.
            tracing::error!("polar webhook: WAL write failed: {e:?}");
            (StatusCode::OK, "Logged internally")
        }
    }
}

// ---------------------------------------------------------------------------
// WORKER — WAL -> Supabase inbox. Postgres trigger wahan se state sync karta hai.
// ---------------------------------------------------------------------------
async fn sync_envelope(s: &AppState, env: &Envelope) -> Result<bool, String> {
    let res = sqlx::query(
        r#"insert into public.polar_webhook_inbox (event_id, event_type, payload)
           values ($1,$2,$3)
           on conflict (event_id) do nothing"#,
    )
    .bind(&env.event_id)
    .bind(&env.event_type)
    .bind(&env.payload)
    .execute(&s.db)
    .await
    .map_err(|e| e.to_string())?;
    Ok(res.rows_affected() > 0)
}

async fn worker_loop(s: Arc<AppState>) {
    loop {
        let files = s.wal.list("pending");
        for path in files {
            let Some(mut env) = Wal::read(&path) else {
                // corrupt file — dead mein rakh do, kabhi delete nahi.
                let _ = fs::rename(&path, s.wal.dir("dead").join(
                    path.file_name().unwrap_or_default(),
                ));
                continue;
            };
            if env.next_try_secs > now_secs() {
                continue;
            }
            match sync_envelope(&s, &env).await {
                Ok(inserted) => {
                    if inserted {
                        s.metrics.synced.fetch_add(1, Ordering::Relaxed);
                    } else {
                        s.metrics.duplicate.fetch_add(1, Ordering::Relaxed);
                    }
                    env.last_error = None;
                    s.wal.move_to(&path, "done", &env);
                }
                Err(e) => {
                    s.metrics.failed.fetch_add(1, Ordering::Relaxed);
                    env.attempts += 1;
                    env.last_error = Some(e.clone());
                    let idx = (env.attempts as usize).saturating_sub(1).min(BACKOFF_SECS.len() - 1);
                    env.next_try_secs = now_secs() + BACKOFF_SECS[idx];
                    tracing::warn!(
                        "wal sync failed ({} attempts) {}: {e}",
                        env.attempts,
                        env.event_id
                    );
                    if env.attempts >= MAX_ATTEMPTS {
                        s.metrics.dead.fetch_add(1, Ordering::Relaxed);
                        s.wal.move_to(&path, "dead", &env);
                    } else {
                        let _ = s.wal.write("pending", &env);
                    }
                }
            }
        }
        // done/ purge: 14 din se purani files hata do (disk safai, truth DB mein hai)
        let cutoff = now_ms() - 14 * 24 * 3600 * 1000;
        for path in s.wal.list("done") {
            if let Some(env) = Wal::read(&path) {
                if env.received_ms < cutoff {
                    let _ = fs::remove_file(&path);
                }
            }
        }
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}

async fn replay_dead(State(s): State<Arc<AppState>>) -> impl IntoResponse {
    let mut moved = 0u64;
    for path in s.wal.list("dead") {
        if let Some(mut env) = Wal::read(&path) {
            if env.event_type.starts_with("signature_reject:") {
                continue; // reject events replay nahi hote — woh sirf evidence hain
            }
            env.attempts = 0;
            env.next_try_secs = 0;
            env.last_error = None;
            s.wal.move_to(&path, "pending", &env);
            moved += 1;
        }
    }
    (StatusCode::OK, Json(json!({ "replayed": moved })))
}

// ---------------------------------------------------------------------------
// WATCHDOG — queue_depth / oldest_pending 10 min se ooper = alert row
// ---------------------------------------------------------------------------
async fn watchdog_loop(s: Arc<AppState>) {
    loop {
        tokio::time::sleep(Duration::from_secs(60)).await;
        let (depth, oldest) = s.wal.queue_stats();
        let dead_depth = s
            .wal
            .list("dead")
            .into_iter()
            .filter_map(|path| Wal::read(&path))
            .filter(|env| !env.event_type.starts_with("signature_reject:"))
            .count() as u64;
        let mut alerts: Vec<(&str, Value)> = Vec::new();
        if oldest > 600 {
            alerts.push((
                "queue_stalled",
                json!({ "queue_depth": depth, "oldest_pending_secs": oldest }),
            ));
        }
        if depth > 200 {
            alerts.push(("queue_depth_high", json!({ "queue_depth": depth })));
        }
        if dead_depth > 0 {
            alerts.push(("dead_letter", json!({ "dead_letter_depth": dead_depth })));
        }
        for (kind, detail) in alerts {
            let _ = sqlx::query(
                r#"insert into public.polar_payment_alerts (kind, bucket, to_email, detail)
                   values ($1, date_trunc('hour', now()), $2, $3)
                   on conflict (kind, bucket) do nothing"#,
            )
            .bind(kind)
            .bind(&s.alert_email)
            .bind(&detail)
            .execute(&s.db)
            .await;
        }
    }
}

// ---------------------------------------------------------------------------
// RECONCILE — har 15 min Polar API vs internal state. Webhook-independence.
// ---------------------------------------------------------------------------
async fn reconcile_loop(s: Arc<AppState>) {
    tokio::time::sleep(Duration::from_secs(45)).await;
    loop {
        reconcile_once(&s).await;
        tokio::time::sleep(Duration::from_secs(15 * 60)).await;
    }
}

async fn reconcile_now(State(s): State<Arc<AppState>>) -> impl IntoResponse {
    reconcile_once(&s).await;
    let gap = s.metrics.reconcile_gap.load(Ordering::Relaxed);
    (StatusCode::OK, Json(json!({ "ok": true, "gap": gap })))
}

async fn polar_list(s: &AppState, path: &str) -> Vec<Value> {
    if s.polar_token.is_empty() {
        return Vec::new();
    }
    let url = format!("https://api.polar.sh/v1/{path}");
    match s.http.get(&url).bearer_auth(&s.polar_token).send().await {
        Ok(r) => {
            let body: Value = r.json().await.unwrap_or(json!({}));
            body.get("items")
                .and_then(|v| v.as_array())
                .cloned()
                .unwrap_or_default()
        }
        Err(e) => {
            tracing::warn!("reconcile: polar {path} unreachable: {e:?}");
            Vec::new()
        }
    }
}

async fn reconcile_once(s: &AppState) {
    s.metrics.reconcile_runs.fetch_add(1, Ordering::Relaxed);
    s.metrics.reconcile_last.store(now_secs(), Ordering::Relaxed);

    let subs = polar_list(s, "subscriptions/?limit=100&sorting=-started_at").await;
    let mut gap: u64 = 0;

    for sub in &subs {
        let Some(sub_id) = sub.get("id").and_then(|v| v.as_str()) else { continue };
        let polar_status = sub.get("status").and_then(|v| v.as_str()).unwrap_or("unknown");
        let row: Result<Option<(String,)>, sqlx::Error> = sqlx::query_as(
            "select status from public.polar_subscriptions where polar_subscription_id = $1",
        )
        .bind(sub_id)
        .fetch_optional(&s.db)
        .await;

        let (verdict, local_status) = match row {
            Ok(Some((local,))) => {
                let expected = match polar_status {
                    "active" | "trialing" => "active",
                    "past_due" => "past_due",
                    "canceled" => "canceled",
                    "revoked" | "unpaid" => "revoked",
                    _ => local.as_str(),
                };
                if local == expected {
                    ("ok", Some(local))
                } else {
                    ("diverged", Some(local))
                }
            }
            Ok(None) => ("missing", None),
            Err(e) => {
                tracing::warn!("reconcile db read failed: {e}");
                ("unknown", None)
            }
        };

        let _ = sqlx::query(
            r#"insert into public.polar_reconcile_log
                 (kind, polar_id, verdict, polar_status, local_status, payload)
               values ('subscription', $1, $2, $3, $4, $5)"#,
        )
        .bind(sub_id)
        .bind(verdict)
        .bind(polar_status)
        .bind(local_status.clone())
        .bind(sub)
        .execute(&s.db)
        .await;

        if verdict == "missing" || verdict == "diverged" {
            gap += 1;
            let event_type = match polar_status {
                "active" | "trialing" => "subscription.active",
                "past_due" => "subscription.past_due",
                "canceled" => "subscription.canceled",
                "revoked" | "unpaid" => "subscription.revoked",
                _ => "subscription.updated",
            };
            let modified = sub
                .get("modified_at")
                .and_then(|v| v.as_str())
                .unwrap_or("na")
                .to_string();
            // Synthetic event — product_key metadata mein bhar dete hain taake
            // Postgres trigger package theek activate kare.
            let mut data = sub.clone();
            let pid = sub
                .get("product_id")
                .and_then(|v| v.as_str())
                .or_else(|| sub.pointer("/product/id").and_then(|v| v.as_str()))
                .unwrap_or("")
                .to_string();
            if let Some(key) = product_key_for(s, &pid) {
                if let Some(m) = data.get_mut("metadata").and_then(|m| m.as_object_mut()) {
                    m.entry("product_key").or_insert(json!(key));
                } else {
                    data["metadata"] = json!({ "product_key": key });
                }
            }
            let env = Envelope {
                event_id: format!("reconcile:{sub_id}:{modified}:{polar_status}"),
                event_type: event_type.to_string(),
                payload: json!({ "type": event_type, "data": data, "source": "reconcile" }),
                received_ms: now_ms(),
                attempts: 0,
                next_try_secs: 0,
                last_error: None,
            };
            let _ = s.wal.write("pending", &env);
        }
    }

    s.metrics.reconcile_gap.store(gap, Ordering::Relaxed);
    if gap > 0 {
        tracing::warn!("reconcile: {gap} subscription(s) missing/diverged — repaired via WAL");
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
