//! Bridge ka asli hisaab (Rule 63: koi dummy nahi). Yahan sirf PURE functions — rows aate hain, summary jaata hai; network main.rs/data.rs mein.
//! Jo data maujood nahi woh `null` + `note` — kabhi jhoota 0 nahi.
use serde_json::{Value, json};

fn num(v: &Value, k: &str) -> f64 {
    match v.get(k) {
        Some(Value::Number(n)) => n.as_f64().unwrap_or(0.0),
        Some(Value::String(s)) => s.parse().unwrap_or(0.0), // PostgREST numeric string bhejta hai
        _ => 0.0,
    }
}

/// PAISA: revenue_accounts (status=active) ka MRR. `None` rows => source tak pahunch nahi hui.
pub fn money(accounts: Option<&[Value]>, target_gbp: Option<f64>) -> Value {
    match accounts {
        None => json!({"connected": false, "note": "cannot reach revenue_accounts"}),
        Some(rows) => {
            let active: Vec<&Value> = rows.iter().filter(|r| r.get("status").and_then(|s| s.as_str()) == Some("active")).collect();
            let mrr: f64 = active.iter().map(|r| num(r, "mrr_gbp")).sum();
            json!({
                "connected": true, "source": "revenue_accounts", "mrr_gbp": (mrr * 100.0).round() / 100.0,
                "active_accounts": active.len(), "target_gbp": target_gbp,
                "note": if rows.is_empty() { Some("no accounts recorded — Polar/Billing connects in F3") } else { None }
            })
        }
    }
}

/// KYA BIGAD RAHA HAI: har item {name, state: ok|warn|fail|unknown, detail}; level = sab se bura.
pub fn trouble(mail_queue: Option<i64>, expiry: Option<&Value>) -> Value {
    let mut items = vec![];
    items.push(match mail_queue {
        None => json!({"name":"mail_outbox","state":"unknown","detail":"unreachable"}),
        Some(0) => json!({"name":"mail_outbox","state":"ok","detail":"queue empty"}),
        Some(n) if n < 25 => json!({"name":"mail_outbox","state":"warn","detail":format!("{n} queued/failed")}),
        Some(n) => json!({"name":"mail_outbox","state":"fail","detail":format!("{n} queued/failed")}),
    });
    items.push(match expiry {
        None => json!({"name":"expiry_watch","state":"unknown","detail":"no report"}),
        Some(r) if r.get("available").and_then(|v| v.as_bool()) != Some(true) => json!({"name":"expiry_watch","state":"unknown","detail":"report not generated yet"}),
        Some(r) if r.get("stale").and_then(|v| v.as_bool()) == Some(true) => json!({"name":"expiry_watch","state":"warn","detail":"report purani (36h+)"}),
        Some(_) => json!({"name":"expiry_watch","state":"ok","detail":"report fresh"}),
    });
    let rank = |s: &str| match s { "fail" => 3, "warn" => 2, "unknown" => 1, _ => 0 };
    let worst = items.iter().map(|i| i["state"].as_str().unwrap_or("unknown")).max_by_key(|s| rank(s)).unwrap_or("unknown").to_string();
    json!({"level": worst, "items": items})
}

/// AWAM KI AWAAZ: naye leads (revenue_leads stage=new); glitch/support channel baad ke phase mein.
/// `pending` = answer of `founder_channels_pending()` (E111, the channel registry). None = E111 not installed / not answering: the OLD fixed list is shown
/// and the answer says `registry: "missing"` so nothing pretends the database confirmed it.
pub fn voice(new_leads: Option<i64>, pending: Option<Vec<String>>) -> Value {
    let (list, reg) = match pending {
        Some(p) => (p, "db"),
        None => (vec!["glitch".to_string(), "support".to_string(), "company_mail".to_string()], "missing"),
    };
    match new_leads {
        None => json!({"connected": false, "note": "cannot reach revenue_leads", "pending_channels": list, "registry": reg}),
        Some(n) => json!({"connected": true, "new_leads": n, "pending_channels": list, "registry": reg}),
    }
}

/// Read the registry answer: a JSON array of channel keys. Anything else (object with "error", numbers, bad keys) = None, never guessed.
pub fn pending_from(v: &Value) -> Option<Vec<String>> {
    let a = v.as_array()?;
    let mut out = Vec::with_capacity(a.len());
    for x in a {
        let k = x.as_str()?;
        if k.len() < 2 || k.len() > 41 || !k.starts_with(|c: char| c.is_ascii_lowercase()) || !k.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_') { return None; }
        out.push(k.to_string());
    }
    Some(out)
}

/// E166: the per-lane "when" answer. Only the six known lanes, only counts and ages (numbers) and ISO-looking times survive; a negative or absurd age, an
/// unknown lane or a lane that is not `connected:true` is dropped. None = E166 not installed or the database did not answer: the Bridge then shows counts only.
pub const LANES: [&str; 6] = ["leads", "polar_events", "subscriptions", "mail_waiting", "webhook_errors", "sig_rejects"];
pub fn lane_times_clean(v: &Value) -> Option<Value> {
    let lanes = v.get("lanes")?.as_object()?;
    let ok_time = |x: &Value| x.as_str().map(|t| t.len() >= 20 && t.len() <= 40 && t.bytes().all(|b| b.is_ascii_digit() || b"-:T.+Z ".contains(&b))).unwrap_or(false);
    let ok_age = |x: &Value| x.as_i64().filter(|a| (0..=3_153_600_000).contains(a));
    let mut out = serde_json::Map::new();
    for k in LANES {
        let Some(l) = lanes.get(k).and_then(|l| l.as_object()) else { continue };
        if l.get("connected").and_then(|c| c.as_bool()) != Some(true) { continue; }
        let mut o = serde_json::Map::new();
        if let Some(c) = l.get("count").and_then(|c| c.as_i64()).filter(|c| *c >= 0) { o.insert("count".into(), json!(c)); }
        for (t, a) in [("last_at", "age_secs"), ("oldest_at", "oldest_age_secs")] {
            if let (Some(tv), Some(av)) = (l.get(t), l.get(a)) { if ok_time(tv) { if let Some(age) = ok_age(av) { o.insert(t.into(), tv.clone()); o.insert(a.into(), json!(age)); } } }
        }
        if let Some(w) = l.get("window").and_then(|w| w.as_str()).filter(|w| w.len() <= 60 && w.chars().all(|c| c.is_ascii_alphanumeric() || " ()-,".contains(c))) { o.insert("window".into(), json!(w)); }
        out.insert(k.into(), Value::Object(o));
    }
    Some(Value::Object(out))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn pending_reads_only_clean_key_arrays() {
        assert_eq!(pending_from(&json!(["glitch", "support"])), Some(vec!["glitch".to_string(), "support".to_string()]));
        assert_eq!(pending_from(&json!([])), Some(vec![]));
        assert_eq!(pending_from(&json!({"error": "42883"})), None);
        assert_eq!(pending_from(&json!([1, 2])), None);
        assert_eq!(pending_from(&json!(["Bad Key"])), None);
        assert_eq!(pending_from(&json!(["a"])), None);
    }
    #[test]
    fn voice_says_where_the_list_came_from() {
        let db = voice(Some(3), Some(vec!["support".to_string()]));
        assert_eq!(db["registry"], "db");
        assert_eq!(db["pending_channels"], json!(["support"]));
        let old = voice(Some(3), None);
        assert_eq!(old["registry"], "missing");
        assert_eq!(old["pending_channels"].as_array().map(|a| a.len()), Some(3));
        assert_eq!(voice(None, Some(vec![]))["connected"], false);
    }
    #[test]
    fn money_sums_only_active() {
        let rows = vec![
            json!({"status":"active","mrr_gbp":"105.00"}),
            json!({"status":"active","mrr_gbp":360}),
            json!({"status":"churned","mrr_gbp":"999"}),
        ];
        let m = money(Some(&rows), Some(1000.0));
        assert_eq!(m["mrr_gbp"], 465.0);
        assert_eq!(m["active_accounts"], 2);
    }
    #[test]
    fn money_unreachable_is_not_zero() {
        let m = money(None, None);
        assert_eq!(m["connected"], false);
        assert!(m.get("mrr_gbp").is_none());
    }
    #[test]
    fn trouble_worst_wins() {
        let ok = json!({"available":true,"stale":false});
        assert_eq!(trouble(Some(0), Some(&ok))["level"], "ok");
        assert_eq!(trouble(Some(3), Some(&ok))["level"], "warn");
        assert_eq!(trouble(Some(500), Some(&ok))["level"], "fail");
        assert_eq!(trouble(None, Some(&ok))["level"], "unknown");
    }
    #[test]
    fn lane_times_keep_only_clean_numbers_and_times() {
        let raw = json!({"lanes": {
            "leads": {"connected": true, "count": 2, "window": "waiting now (stage new)", "last_at": "2026-11-12T20:26:31.242737+05:00", "age_secs": 604, "oldest_at": "2026-11-12T17:36:31+05:00", "oldest_age_secs": 10804},
            "mail_waiting": {"connected": false},
            "sig_rejects": {"connected": true, "count": -4, "last_at": "<script>", "age_secs": 5},
            "polar_events": {"connected": true, "count": 1, "last_at": "2026-11-12T20:31:31+05:00", "age_secs": -9},
            "evil": {"connected": true, "count": 1}}});
        let c = lane_times_clean(&raw).unwrap();
        assert_eq!(c["leads"]["age_secs"], 604); assert_eq!(c["leads"]["oldest_age_secs"], 10804); assert_eq!(c["leads"]["window"], "waiting now (stage new)");
        assert!(c.get("mail_waiting").is_none()); assert!(c.get("evil").is_none());
        assert!(c["sig_rejects"].get("count").is_none() && c["sig_rejects"].get("last_at").is_none());
        assert!(c["polar_events"].get("last_at").is_none() && c["polar_events"]["count"] == 1);
        assert!(lane_times_clean(&json!({"error": "42883"})).is_none());
    }
}
