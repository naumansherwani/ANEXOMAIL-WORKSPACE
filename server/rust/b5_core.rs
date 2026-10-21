// ============================================================================
// b5_core.rs — B5 (G40): the pure, std-only brain of the founder-page procedures that used to live only on Brain (Bun).
// Tested with plain `rustc --test b5_core.rs` (no crates). The I/O half is b5_glue.rs.
//
// Every rule here is a faithful port of the TypeScript twin it replaces (server/routes/movein.ts, release.ts, revenue.ts),
// which STAYS on Brain as the fallback (Rust 404/501/502/503 -> frontend falls back to the old REST route).
// ============================================================================

use std::collections::HashMap;

// ---------------------------------------------------------------- text helpers

/// JS `String(x).slice(0, n)` — first `n` characters (never splits a UTF-8 char).
pub fn clip(s: &str, n: usize) -> String {
    s.chars().take(n).collect()
}

/// JS `Math.round` for the positive money values used here: floor(x + 0.5).
pub fn js_round(x: f64) -> i64 {
    if !x.is_finite() {
        return 0;
    }
    (x + 0.5).floor() as i64
}

/// Only characters of a UUID. Anything else is refused before it can reach a URL.
pub fn uuid_shape_ok(s: &str) -> bool {
    let l = s.len();
    (8..=40).contains(&l) && s.chars().all(|c| c.is_ascii_hexdigit() || c == '-')
}

/// Percent-encodes a value for a PostgREST filter.
pub fn pct(v: &str) -> String {
    let mut o = String::with_capacity(v.len() + 8);
    for b in v.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'.' | b'_' | b'~') {
            o.push(b as char);
        } else {
            o.push_str(&format!("%{:02X}", b));
        }
    }
    o
}

// ---------------------------------------------------------------- time

/// Epoch milliseconds -> `2026-10-21T07:20:00.123Z` (same shape as JS `toISOString()`), no crates.
pub fn iso_utc(ms: i64) -> String {
    let secs = ms.div_euclid(1000);
    let milli = ms.rem_euclid(1000);
    let days = secs.div_euclid(86_400);
    let rem = secs.rem_euclid(86_400);
    let (y, m, d) = civil_from_days(days);
    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}.{:03}Z",
        y,
        m,
        d,
        rem / 3600,
        (rem % 3600) / 60,
        rem % 60,
        milli
    )
}

/// Howard Hinnant's days -> civil date.
pub fn civil_from_days(z: i64) -> (i64, i64, i64) {
    let z = z + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    (if m <= 2 { y + 1 } else { y }, m, d)
}

/// A v4 UUID from 16 random bytes.
pub fn uuid_v4(mut b: [u8; 16]) -> String {
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    let h: Vec<String> = b.iter().map(|x| format!("{:02x}", x)).collect();
    format!(
        "{}-{}-{}-{}-{}",
        h[0..4].concat(),
        h[4..6].concat(),
        h[6..8].concat(),
        h[8..10].concat(),
        h[10..16].concat()
    )
}

// ---------------------------------------------------------------- move-in

/// `Number(mailboxes) || 1` — zero / NaN / missing become 1.
pub fn mailboxes_or_one(n: Option<f64>) -> i64 {
    match n {
        Some(v) if v.is_finite() && v != 0.0 => v.trunc() as i64,
        _ => 1,
    }
}

pub struct MoveInReq {
    pub company: String,
    pub email: String,
    pub mailboxes: i64,
    pub domain: Option<String>,
    pub provider: String,
    pub contact: Option<String>,
    pub month: Option<String>,
}

/// Same trimming/limits as POST /movein/request. Err = the machine code of the 400.
pub fn movein_request(
    company: &str,
    email: &str,
    mailboxes: Option<f64>,
    domain: &str,
    provider: &str,
    contact: &str,
    month: &str,
) -> Result<MoveInReq, &'static str> {
    if company.is_empty() || email.is_empty() {
        return Err("company_and_email_required");
    }
    let some = |s: &str, n: usize| if s.is_empty() { None } else { Some(clip(s, n)) };
    Ok(MoveInReq {
        company: clip(company, 200),
        email: clip(email, 200),
        mailboxes: mailboxes_or_one(mailboxes),
        domain: some(domain, 200),
        provider: if provider.is_empty() { "other".to_string() } else { clip(provider, 40) },
        contact: some(contact, 200),
        month: if month.is_empty() { None } else { Some(month.to_string()) },
    })
}

// ---------------------------------------------------------------- revenue lead

pub fn lead_kind_ok(k: &str) -> bool {
    matches!(k, "migration" | "partner" | "sla" | "plan")
}

/// `/^[^@\s]+@[^@\s]+\.[^@\s]+$/`
pub fn valid_email(e: &str) -> bool {
    if e.is_empty() || e.chars().any(|c| c.is_whitespace()) {
        return false;
    }
    let mut parts = e.splitn(2, '@');
    let local = parts.next().unwrap_or("");
    let rest = parts.next().unwrap_or("");
    if local.is_empty() || rest.is_empty() || rest.contains('@') {
        return false;
    }
    // need `x.y` with non-empty x and y somewhere in `rest`
    let b: Vec<char> = rest.chars().collect();
    (1..b.len().saturating_sub(1)).any(|i| b[i] == '.')
}

pub fn lead_prefix(kind: &str) -> &'static str {
    match kind {
        "migration" => "MIG",
        "partner" => "PTR",
        "sla" => "SLA",
        _ => "LED",
    }
}

/// Four base-36 characters (A-Z0-9) from a number.
pub fn rand4(mut n: u64) -> String {
    const A: &[u8] = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    let mut o = [b'0'; 4];
    for i in (0..4).rev() {
        o[i] = A[(n % 36) as usize];
        n /= 36;
    }
    String::from_utf8_lossy(&o).to_string()
}

/// `MIG-202610-AB12`
pub fn reference(kind: &str, ms: i64, r: u64) -> String {
    let (y, m, _d) = civil_from_days(ms.div_euclid(1000).div_euclid(86_400));
    format!("{}-{:04}{:02}-{}", lead_prefix(kind), y, m, rand4(r))
}

/// 5 leads / 10 minutes / IP, in memory (same as Brain).
#[derive(Default)]
pub struct Throttle {
    hits: HashMap<String, Vec<i64>>,
}

impl Throttle {
    pub const WINDOW_MS: i64 = 10 * 60_000;
    pub const MAX: usize = 5;
    /// true = this request is TOO MANY (blocked).
    pub fn throttled(&mut self, ip: &str, now_ms: i64) -> bool {
        let mut win: Vec<i64> = self
            .hits
            .get(ip)
            .map(|v| v.iter().copied().filter(|t| now_ms - *t < Self::WINDOW_MS).collect())
            .unwrap_or_default();
        if win.len() >= Self::MAX {
            self.hits.insert(ip.to_string(), win);
            return true;
        }
        win.push(now_ms);
        self.hits.insert(ip.to_string(), win);
        if self.hits.len() > 5000 {
            self.hits.clear();
        }
        false
    }
}

/// Migration lead: deposit is half of the quote, rounded.
pub fn deposit(quote: f64) -> i64 {
    js_round(quote * 0.5)
}

pub fn partner_tier(t: &str) -> &'static str {
    match t {
        "gold" => "gold",
        "platinum" => "platinum",
        _ => "reseller",
    }
}

/// Commission rate: (0, 0.30] is honoured, anything else is 20 %.
pub fn partner_rate(r: Option<f64>) -> f64 {
    match r {
        Some(v) if v > 0.0 && v <= 0.3 => v,
        _ => 0.2,
    }
}

// ---------------------------------------------------------------- release gate

pub fn verdict(failed: i64, warned: i64) -> &'static str {
    if failed > 0 {
        "red"
    } else if warned > 0 {
        "watch"
    } else {
        "green"
    }
}

/// HTTP probe: ok code -> pass (warn if slower than 1.5 s), otherwise fail.
pub fn http_probe_status(code_ok: bool, ms: i64) -> &'static str {
    if code_ok {
        if ms > 1500 {
            "warn"
        } else {
            "pass"
        }
    } else {
        "fail"
    }
}

/// 95th percentile of an ascending list (nearest-rank). Empty -> 0.
pub fn p95(sorted: &[f64]) -> f64 {
    if sorted.is_empty() {
        return 0.0;
    }
    let n = sorted.len() as f64;
    let i = ((0.95 * n).ceil() as i64 - 1).clamp(0, sorted.len() as i64 - 1) as usize;
    sorted[i]
}

pub fn speed_status(p: f64, budget_ms: f64) -> &'static str {
    if p <= budget_ms {
        "pass"
    } else if p <= budget_ms * 1.5 {
        "warn"
    } else {
        "fail"
    }
}

/// Held outbox mail: 0 pass, <25 warn, else fail.
pub fn backlog_status(held: i64) -> &'static str {
    if held == 0 {
        "pass"
    } else if held < 25 {
        "warn"
    } else {
        "fail"
    }
}

/// A DNS verdict is fine when empty, "pass", "green" or `true`.
pub fn dns_value_ok(v: Option<&str>, is_true: bool) -> bool {
    if is_true {
        return true;
    }
    match v {
        None => true,
        Some(s) => s.is_empty() || s == "pass" || s == "green",
    }
}

pub fn ownership_status(result: &str) -> &'static str {
    match result {
        "pass" => "pass",
        "fail" => "fail",
        _ => "warn",
    }
}

/// gate = locked | unknown | blocked | ready
pub fn gate(locked: bool, has_run: bool, blockers: usize) -> &'static str {
    if locked {
        "locked"
    } else if !has_run {
        "unknown"
    } else if blockers > 0 {
        "blocked"
    } else {
        "ready"
    }
}

/// The exact string that is SHA-256 hashed into a version-lock signature (field order is part of the contract).
pub fn lock_signature_payload(
    version: &str,
    email: &str,
    frozen_at: &str,
    run_id: &str,
    verdict: &str,
    passed: i64,
    failed: i64,
    override_reason: &str,
) -> String {
    [
        version,
        email,
        frozen_at,
        run_id,
        verdict,
        &passed.to_string(),
        &failed.to_string(),
        override_reason,
    ]
    .join("|")
}

pub fn checklist_state_ok(s: &str) -> bool {
    matches!(s, "open" | "done" | "blocker")
}

pub fn roadmap_state(s: &str) -> &'static str {
    match s {
        "next" => "next",
        "building" => "building",
        "shipped" => "shipped",
        _ => "idea",
    }
}

/// `Math.min(5, Math.max(1, Number(v ?? 3)))` — missing / NaN -> 3.
pub fn clamp_1_5(v: Option<f64>) -> i64 {
    match v {
        Some(x) if x.is_finite() => (x.max(1.0).min(5.0)) as i64,
        _ => 3,
    }
}

// ---------------------------------------------------------------- public status page

/// down if anything failed, degraded if anything warned, else operational.
pub fn component_state(failed: usize, warned: usize) -> &'static str {
    if failed > 0 {
        "down"
    } else if warned > 0 {
        "degraded"
    } else {
        "operational"
    }
}

pub fn worst_state(states: &[&str]) -> &'static str {
    if states.iter().any(|s| *s == "down") {
        "down"
    } else if states.iter().any(|s| *s == "degraded") {
        "degraded"
    } else {
        "operational"
    }
}

// ---------------------------------------------------------------- revenue pipeline truth

pub fn stage_weight(stage: &str) -> f64 {
    match stage {
        "new" => 0.1,
        "contacted" => 0.2,
        "qualified" => 0.4,
        "quoted" => 0.5,
        "proposal" => 0.6,
        "won" => 1.0,
        "lost" => 0.0,
        _ => 0.1,
    }
}

pub fn offer_label(kind: &str) -> &'static str {
    match kind {
        "migration" => "Managed Move-In",
        "sla" => "Priority Support",
        "partner" => "Partner commission",
        "subscription" => "Workspace subscription",
        _ => "Workspace subscription",
    }
}

/// Weighted expected MRR of one open lead: linked pipeline row wins, else seats * Pro list price (£46).
pub fn expected_mrr(linked_expected: Option<f64>, seats: f64, weight: f64) -> i64 {
    let base = linked_expected.unwrap_or(seats * SEAT_PRICE_DEFAULT);
    js_round(base * weight)
}

/// Priority-support retainer: £790/mo per live SLA account (locked list price; the old 500 was stale).
pub const SLA_MRR_PER_ACCOUNT: i64 = 790;

/// Per-seat price used when a lead has no linked pipeline row: Pro list price £46 (the old 40 was stale).
pub const SEAT_PRICE_DEFAULT: f64 = 46.0;

pub fn gap(target: f64, committed: f64) -> i64 {
    js_round(target - committed).max(0)
}

// ================================================================== tests
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clip_is_char_safe() {
        assert_eq!(clip("abcdef", 3), "abc");
        assert_eq!(clip("شہزاد", 2), "شہ");
    }

    #[test]
    fn js_round_matches_math_round() {
        assert_eq!(js_round(2.5), 3);
        assert_eq!(js_round(2.4), 2);
        assert_eq!(js_round(0.0), 0);
        assert_eq!(deposit(1001.0), 501);
    }

    #[test]
    fn uuid_shape() {
        assert!(uuid_shape_ok("3f2a9c10-0000-4000-8000-0123456789ab"));
        assert!(!uuid_shape_ok("x'; drop"));
        assert!(!uuid_shape_ok(""));
        assert!(!uuid_shape_ok("12-34"));
    }

    #[test]
    fn iso_matches_js() {
        assert_eq!(iso_utc(0), "1970-01-01T00:00:00.000Z");
        assert_eq!(iso_utc(1_700_000_000_123), "2023-11-14T22:13:20.123Z");
        assert_eq!(iso_utc(1_782_000_000_000), "2026-06-21T00:00:00.000Z");
        assert_eq!(iso_utc(951_782_400_000), "2000-02-29T00:00:00.000Z"); // leap day
    }

    #[test]
    fn uuid_v4_shape() {
        let u = uuid_v4([255; 16]);
        assert_eq!(u.len(), 36);
        assert_eq!(&u[14..15], "4");
        assert!(matches!(&u[19..20], "8" | "9" | "a" | "b"));
        assert!(uuid_shape_ok(&u));
    }

    #[test]
    fn movein_request_rules() {
        assert_eq!(movein_request("", "a@b.co", None, "", "", "", "").err(), Some("company_and_email_required"));
        assert_eq!(movein_request("Acme", "", None, "", "", "", "").err(), Some("company_and_email_required"));
        let r = movein_request("Acme", "a@b.co", Some(0.0), "", "", "", "").unwrap();
        assert_eq!(r.mailboxes, 1);
        assert_eq!(r.provider, "other");
        assert!(r.domain.is_none() && r.contact.is_none() && r.month.is_none());
        let r = movein_request("Acme", "a@b.co", Some(12.0), "acme.com", "google", "Ali", "2026-11").unwrap();
        assert_eq!((r.mailboxes, r.domain.as_deref(), r.provider.as_str(), r.month.as_deref()), (12, Some("acme.com"), "google", Some("2026-11")));
        let long = "x".repeat(500);
        assert_eq!(movein_request(&long, "a@b.co", None, "", &long, "", "").unwrap().company.len(), 200);
        assert_eq!(movein_request("A", "a@b.co", None, "", &long, "", "").unwrap().provider.len(), 40);
        assert_eq!(mailboxes_or_one(Some(f64::NAN)), 1);
        assert_eq!(mailboxes_or_one(Some(-2.0)), -2);
    }

    #[test]
    fn email_shape_like_the_regex() {
        for ok in ["a@b.co", "ali.khan@sub.example.com", "a+b@c.d.e"] {
            assert!(valid_email(ok), "{ok}");
        }
        for bad in ["", "a", "a@b", "@b.co", "a@.co", "a@b.", "a b@c.co", "a@b@c.co", "a@b .co"] {
            assert!(!valid_email(bad), "{bad}");
        }
    }

    #[test]
    fn lead_reference_and_kinds() {
        assert!(lead_kind_ok("migration") && lead_kind_ok("plan") && !lead_kind_ok("x") && !lead_kind_ok(""));
        let r = reference("migration", 1_782_000_000_000, 123_456);
        assert!(r.starts_with("MIG-202606-"), "{r}");
        assert_eq!(r.len(), "MIG-202606-".len() + 4);
        assert!(reference("partner", 0, 0).starts_with("PTR-197001-"));
        assert!(reference("sla", 0, 0).starts_with("SLA-"));
        assert!(reference("plan", 0, 0).starts_with("LED-"));
        assert_eq!(rand4(0), "0000");
        assert_eq!(rand4(35), "000Z");
    }

    #[test]
    fn throttle_five_per_ten_minutes() {
        let mut t = Throttle::default();
        for i in 0..5 {
            assert!(!t.throttled("1.2.3.4", 1000 + i), "request {i}");
        }
        assert!(t.throttled("1.2.3.4", 2000)); // 6th
        assert!(!t.throttled("9.9.9.9", 2000)); // another IP is free
        assert!(!t.throttled("1.2.3.4", 1000 + Throttle::WINDOW_MS + 10)); // window passed
    }

    #[test]
    fn partner_rules() {
        assert_eq!(partner_tier("gold"), "gold");
        assert_eq!(partner_tier("platinum"), "platinum");
        assert_eq!(partner_tier("bogus"), "reseller");
        assert_eq!(partner_rate(Some(0.25)), 0.25);
        assert_eq!(partner_rate(Some(0.31)), 0.2);
        assert_eq!(partner_rate(Some(0.0)), 0.2);
        assert_eq!(partner_rate(None), 0.2);
    }

    #[test]
    fn verdicts_and_probe_status() {
        assert_eq!(verdict(1, 5), "red");
        assert_eq!(verdict(0, 1), "watch");
        assert_eq!(verdict(0, 0), "green");
        assert_eq!(http_probe_status(true, 100), "pass");
        assert_eq!(http_probe_status(true, 1501), "warn");
        assert_eq!(http_probe_status(true, 1500), "pass");
        assert_eq!(http_probe_status(false, 1), "fail");
    }

    #[test]
    fn p95_nearest_rank_and_budgets() {
        let v: Vec<f64> = (1..=100).map(|x| x as f64).collect();
        assert_eq!(p95(&v), 95.0);
        assert_eq!(p95(&[7.0]), 7.0);
        assert_eq!(p95(&[]), 0.0);
        let v: Vec<f64> = (1..=20).map(|x| x as f64).collect();
        assert_eq!(p95(&v), 19.0);
        assert_eq!(speed_status(100.0, 100.0), "pass");
        assert_eq!(speed_status(150.0, 100.0), "warn");
        assert_eq!(speed_status(151.0, 100.0), "fail");
    }

    #[test]
    fn backlog_dns_ownership() {
        assert_eq!(backlog_status(0), "pass");
        assert_eq!(backlog_status(24), "warn");
        assert_eq!(backlog_status(25), "fail");
        assert!(dns_value_ok(None, false) && dns_value_ok(Some("pass"), false) && dns_value_ok(Some("green"), false));
        assert!(dns_value_ok(None, true));
        assert!(!dns_value_ok(Some("fail"), false) && !dns_value_ok(Some("pending"), false));
        assert_eq!(ownership_status("pass"), "pass");
        assert_eq!(ownership_status("fail"), "fail");
        assert_eq!(ownership_status("anything"), "warn");
    }

    #[test]
    fn gate_order() {
        assert_eq!(gate(true, true, 9), "locked");
        assert_eq!(gate(false, false, 9), "unknown");
        assert_eq!(gate(false, true, 1), "blocked");
        assert_eq!(gate(false, true, 0), "ready");
    }

    #[test]
    fn signature_payload_order_is_the_contract() {
        let p = lock_signature_payload("1.0.0", "f@x.com", "2026-10-21T00:00:00.000Z", "run1", "green", 40, 0, "");
        assert_eq!(p, "1.0.0|f@x.com|2026-10-21T00:00:00.000Z|run1|green|40|0|");
        let p = lock_signature_payload("1.0.0", "f@x.com", "t", "r", "red", 1, 2, "why");
        assert_eq!(p, "1.0.0|f@x.com|t|r|red|1|2|why");
    }

    #[test]
    fn checklist_roadmap_clamps() {
        assert!(checklist_state_ok("open") && checklist_state_ok("done") && checklist_state_ok("blocker"));
        assert!(!checklist_state_ok("x") && !checklist_state_ok(""));
        assert_eq!(roadmap_state("next"), "next");
        assert_eq!(roadmap_state("zzz"), "idea");
        assert_eq!(clamp_1_5(None), 3);
        assert_eq!(clamp_1_5(Some(99.0)), 5);
        assert_eq!(clamp_1_5(Some(-4.0)), 1);
        assert_eq!(clamp_1_5(Some(f64::NAN)), 3);
        assert_eq!(clamp_1_5(Some(2.0)), 2);
    }

    #[test]
    fn status_page_states() {
        assert_eq!(component_state(1, 1), "down");
        assert_eq!(component_state(0, 2), "degraded");
        assert_eq!(component_state(0, 0), "operational");
        assert_eq!(worst_state(&["operational", "degraded"]), "degraded");
        assert_eq!(worst_state(&["operational", "down", "degraded"]), "down");
        assert_eq!(worst_state(&[]), "operational");
    }

    #[test]
    fn pipeline_maths() {
        assert_eq!(stage_weight("won"), 1.0);
        assert_eq!(stage_weight("lost"), 0.0);
        assert_eq!(stage_weight("???"), 0.1);
        assert_eq!(offer_label("migration"), "Managed Move-In");
        assert_eq!(offer_label("nope"), "Workspace subscription");
        // 3 seats, no link, stage "qualified" (0.4): 3*46*0.4 = 55.2 -> 55
        assert_eq!(expected_mrr(None, 3.0, 0.4), 55);
        // linked 1000, "quoted" (0.5)
        assert_eq!(expected_mrr(Some(1000.0), 9.0, 0.5), 500);
        assert_eq!(gap(500.0, 120.4), 380);
        assert_eq!(gap(100.0, 900.0), 0);
        assert_eq!(SLA_MRR_PER_ACCOUNT * 2, 1580);
    }

    #[test]
    fn pct_encoding() {
        assert_eq!(pct("a b+c@d"), "a%20b%2Bc%40d");
        assert_eq!(pct("2026-10"), "2026-10");
    }
}
