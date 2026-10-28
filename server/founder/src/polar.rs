//! Polar billing — READ-ONLY reader (F3 foundation). Separate read-only token (scope `metrics:read`), never the payment/webhook token,
//! never :3400 (webhook engine stays NO-TOUCH). A tokio task polls Polar's Metrics API; the last good snapshot is served signed and
//! pushed to listeners through a `watch` channel. No token / no answer = honest "not connected" (FC26: nothing invented).
use serde_json::{Value, json};
use std::sync::{Arc, RwLock};
use tokio::sync::watch;

const METRICS: [&str; 5] = ["monthly_recurring_revenue", "active_subscriptions", "new_subscriptions", "canceled_subscriptions", "revenue"];
pub const POLL_SECS: u64 = 60;
pub const WINDOW_DAYS: i64 = 30;

#[derive(Clone)]
pub struct Cfg { pub token: String, pub base: String, pub org: Option<String> }
impl Cfg {
    pub fn from_env() -> Option<Cfg> {
        let token = std::env::var("FOUNDER_POLAR_READ_TOKEN").ok().map(|t| t.trim().to_string()).filter(|t| t.len() >= 20)?;
        let base = std::env::var("FOUNDER_POLAR_API").unwrap_or_else(|_| "https://api.polar.sh".into()).trim_end_matches('/').to_string();
        let org = std::env::var("FOUNDER_POLAR_ORG_ID").ok().filter(|o| !o.is_empty() && o.chars().all(|c| c.is_ascii_hexdigit() || c == '-'));
        Some(Cfg { token, base, org })
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Snap { pub mrr_minor: Option<i64>, pub active: Option<i64>, pub new_30d: i64, pub canceled_30d: i64, pub revenue_30d_minor: i64, pub through: String, pub as_of: i64 }

#[derive(Default)]
struct Inner { last_ok: Option<Snap>, last_err: Option<(u16, i64)> }

pub struct Live { configured: bool, inner: RwLock<Inner>, pub tx: watch::Sender<u64> }
impl Live {
    pub fn new(configured: bool) -> Arc<Live> { Arc::new(Live { configured, inner: RwLock::default(), tx: watch::channel(0u64).0 }) }
    pub fn off() -> Arc<Live> { Live::new(false) }
    fn record(&self, r: Result<Snap, u16>, now: i64) {
        let mut g = self.inner.write().unwrap();
        let changed = match r { Ok(s) => { let c = g.last_ok.as_ref().map(|o| (o.mrr_minor, o.active, o.new_30d, o.canceled_30d, o.revenue_30d_minor)) != Some((s.mrr_minor, s.active, s.new_30d, s.canceled_30d, s.revenue_30d_minor)); g.last_ok = Some(s); g.last_err = None; c }
                                  Err(code) => { let c = g.last_err.map(|e| e.0) != Some(code); g.last_err = Some((code, now)); c } };
        drop(g);
        if changed { self.tx.send_modify(|n| *n += 1); }
    }
    /// What the SPA/bridge sees. Amounts are Polar's own "minor units" (cents) in the account currency — we never guess a currency.
    pub fn view(&self, now: i64) -> Value {
        if !self.configured { return json!({"connected": false, "source": "polar", "note": "Polar read-only token not configured (FOUNDER_POLAR_READ_TOKEN)"}); }
        let g = self.inner.read().unwrap();
        match (&g.last_ok, g.last_err) {
            (None, Some((code, _))) => json!({"connected": false, "source": "polar", "note": err_note(code)}),
            (None, None) => json!({"connected": false, "source": "polar", "note": "Polar: first reading in progress"}),
            (Some(s), err) => { let age = (now - s.as_of).max(0);
                json!({"connected": true, "source": "polar metrics api (read-only)", "mrr_minor": s.mrr_minor, "active_subscriptions": s.active, "new_30d": s.new_30d, "canceled_30d": s.canceled_30d,
                       "revenue_30d_minor": s.revenue_30d_minor, "through": s.through, "as_of": s.as_of, "age_secs": age, "stale": age > 5 * POLL_SECS as i64 || err.is_some(),
                       "last_error": err.map(|e| err_note(e.0)), "unit": "minor units (cents) of the Polar account currency"}) }
        }
    }
}
fn err_note(code: u16) -> String {
    match code { 401 | 403 => "Polar refused the token (needs a read-only token with scope metrics:read)".into(), 0 => "Polar did not answer".into(), 429 => "Polar rate limit — backing off".into(), c => format!("Polar answered HTTP {c}") }
}

/// civil date (UTC) from unix seconds — no chrono dependency.
pub fn ymd(secs: i64) -> String {
    let z = secs.div_euclid(86_400) + 719_468; let era = z.div_euclid(146_097); let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365; let y = yoe + era * 400; let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153; let d = doy - (153 * mp + 2) / 5 + 1; let m = if mp < 10 { mp + 3 } else { mp - 9 };
    format!("{:04}-{:02}-{:02}", if m <= 2 { y + 1 } else { y }, m, d)
}

fn num(v: &Value) -> Option<i64> { v.as_i64().or_else(|| v.as_f64().map(|f| f.round() as i64)) }

/// Polar MetricsResponse -> Snap. periods[] each carry the metric slugs; MRR/active = last period, new/canceled/revenue = sum over the window.
pub fn parse(v: &Value, now: i64) -> Option<Snap> {
    let periods = v.get("periods")?.as_array()?;
    if periods.is_empty() { return None; }
    let last = periods.last()?;
    let sum = |k: &str| periods.iter().filter_map(|p| p.get(k).and_then(num)).sum::<i64>();
    Some(Snap { mrr_minor: last.get("monthly_recurring_revenue").and_then(num), active: last.get("active_subscriptions").and_then(num),
        new_30d: sum("new_subscriptions"), canceled_30d: sum("canceled_subscriptions"), revenue_30d_minor: sum("revenue"),
        through: last.get("timestamp").and_then(|t| t.as_str()).unwrap_or("").chars().take(10).collect(), as_of: now })
}

pub fn query(cfg: &Cfg, now: i64) -> Vec<(&'static str, String)> {
    let mut q = vec![("start_date", ymd(now - (WINDOW_DAYS - 1) * 86_400)), ("end_date", ymd(now)), ("interval", "day".to_string())];
    for m in METRICS { q.push(("metrics", m.to_string())); }
    if let Some(o) = &cfg.org { q.push(("organization_id", o.clone())); }
    q
}

async fn fetch(http: &reqwest::Client, cfg: &Cfg, now: i64) -> Result<Snap, u16> {
    let r = http.get(format!("{}/v1/metrics/", cfg.base)).bearer_auth(&cfg.token).query(&query(cfg, now)).send().await.map_err(|_| 0u16)?;
    if !r.status().is_success() { return Err(r.status().as_u16()); }
    let v = r.json::<Value>().await.map_err(|_| 0u16)?;
    parse(&v, now).ok_or(0)
}

/// tokio background task: poll every POLL_SECS (backoff x2 on error). GET only — this module has no write path to Polar at all.
pub fn spawn(live: Arc<Live>, cfg: Cfg, now_fn: fn() -> i64) {
    tokio::spawn(async move {
        let Ok(http) = reqwest::Client::builder().timeout(std::time::Duration::from_secs(10)).build() else { return };
        loop {
            let now = now_fn(); let r = fetch(&http, &cfg, now).await; let bad = r.is_err(); live.record(r, now);
            tokio::time::sleep(std::time::Duration::from_secs(if bad { POLL_SECS * 2 } else { POLL_SECS })).await;
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    // Shape follows Polar's documented MetricsResponse (periods[] with timestamp + metric slugs; currency values in cents).
    fn resp() -> Value { json!({"periods": [
        {"timestamp": "2026-10-27T00:00:00Z", "monthly_recurring_revenue": 4000, "active_subscriptions": 1, "new_subscriptions": 1, "canceled_subscriptions": 0, "revenue": 4000},
        {"timestamp": "2026-10-28T00:00:00Z", "monthly_recurring_revenue": 14500, "active_subscriptions": 2, "new_subscriptions": 1, "canceled_subscriptions": 0, "revenue": 10500}]}) }
    #[test] fn parses_last_period_and_sums() {
        let s = parse(&resp(), 100).unwrap();
        assert_eq!((s.mrr_minor, s.active, s.new_30d, s.canceled_30d, s.revenue_30d_minor), (Some(14500), Some(2), 2, 0, 14500));
        assert_eq!(s.through, "2026-10-28");
    }
    #[test] fn empty_or_garbage_is_none_never_zero() {
        assert!(parse(&json!({"periods": []}), 1).is_none()); assert!(parse(&json!({"x": 1}), 1).is_none()); assert!(parse(&json!("no"), 1).is_none());
    }
    #[test] fn null_metric_stays_none_not_zero() {
        let s = parse(&json!({"periods": [{"timestamp": "2026-10-28T00:00:00Z", "monthly_recurring_revenue": null}]}), 1).unwrap();
        assert_eq!(s.mrr_minor, None); assert_eq!(s.active, None);
    }
    #[test] fn dates_are_right() {
        assert_eq!(ymd(0), "1970-01-01"); assert_eq!(ymd(1_761_609_600), "2025-10-28"); assert_eq!(ymd(1_793_145_600), "2026-10-28");
        let cfg = Cfg { token: "x".repeat(24), base: "https://api.polar.sh".into(), org: None };
        let q = query(&cfg, 1_793_145_600); assert_eq!(q[0], ("start_date", "2026-09-29".into())); assert_eq!(q[1], ("end_date", "2026-10-28".into()));
        assert_eq!(q.iter().filter(|(k, _)| *k == "metrics").count(), 5);
    }
    #[test] fn view_states_are_honest() {
        assert_eq!(Live::off().view(1)["connected"], false);
        let l = Live::new(true); assert_eq!(l.view(1)["connected"], false);                         // configured, nothing yet
        l.record(Err(403), 5); assert!(l.view(6)["note"].as_str().unwrap().contains("metrics:read")); // refused token says why
        l.record(Ok(parse(&resp(), 10).unwrap()), 10); let v = l.view(12); assert_eq!(v["connected"], true); assert_eq!(v["mrr_minor"], 14500); assert_eq!(v["stale"], false);
        l.record(Err(500), 20); assert_eq!(l.view(21)["stale"], true);                               // last good kept, flagged stale — never replaced by 0
        assert_eq!(l.view(21)["mrr_minor"], 14500);
    }
    #[test] fn watch_fires_only_on_change() {
        let l = Live::new(true); let rx = l.tx.subscribe(); let s = parse(&resp(), 1).unwrap();
        l.record(Ok(s.clone()), 1); assert_eq!(*rx.borrow(), 1); l.record(Ok(s), 2); assert_eq!(*rx.borrow(), 1); // same numbers: no push
    }
    // Real HTTP round-trip against a local stand-in for Polar: proves path, bearer header, query (repeated `metrics`) and parsing end to end.
    #[tokio::test] async fn fetch_sends_bearer_and_query() {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        let l = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap(); let port = l.local_addr().unwrap().port();
        let srv = tokio::spawn(async move { let (mut c, _) = l.accept().await.unwrap(); let mut b = vec![0u8; 4096]; let n = c.read(&mut b).await.unwrap();
            let body = resp().to_string(); c.write_all(format!("HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{}", body.len(), body).as_bytes()).await.unwrap();
            String::from_utf8_lossy(&b[..n]).to_string() });
        let cfg = Cfg { token: "t".repeat(24), base: format!("http://127.0.0.1:{port}"), org: None };
        let s = fetch(&reqwest::Client::new(), &cfg, 1_793_145_600).await.unwrap(); assert_eq!(s.mrr_minor, Some(14500));
        let req = srv.await.unwrap().to_lowercase();
        assert!(req.starts_with("get /v1/metrics/?start_date=2026-09-29&end_date=2026-10-28&interval=day&metrics=monthly_recurring_revenue&metrics=active_subscriptions"), "{req}");
        assert!(req.contains(&format!("authorization: bearer {}", "t".repeat(24))));
    }
    #[test] fn token_must_look_real() { unsafe { std::env::set_var("FOUNDER_POLAR_READ_TOKEN", "short"); } assert!(Cfg::from_env().is_none()); }
}
