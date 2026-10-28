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
        Some(0) => json!({"name":"mail_outbox","state":"ok","detail":"queue khali"}),
        Some(n) if n < 25 => json!({"name":"mail_outbox","state":"warn","detail":format!("{n} queued/failed")}),
        Some(n) => json!({"name":"mail_outbox","state":"fail","detail":format!("{n} queued/failed")}),
    });
    items.push(match expiry {
        None => json!({"name":"expiry_watch","state":"unknown","detail":"no report"}),
        Some(r) if r.get("available").and_then(|v| v.as_bool()) != Some(true) => json!({"name":"expiry_watch","state":"unknown","detail":"report not generated yet"}),
        Some(r) if r.get("stale").and_then(|v| v.as_bool()) == Some(true) => json!({"name":"expiry_watch","state":"warn","detail":"report purani (36h+)"}),
        Some(_) => json!({"name":"expiry_watch","state":"ok","detail":"report taza"}),
    });
    let rank = |s: &str| match s { "fail" => 3, "warn" => 2, "unknown" => 1, _ => 0 };
    let worst = items.iter().map(|i| i["state"].as_str().unwrap_or("unknown")).max_by_key(|s| rank(s)).unwrap_or("unknown").to_string();
    json!({"level": worst, "items": items})
}

/// AWAM KI AWAAZ: naye leads (revenue_leads stage=new); glitch/support channel baad ke phase mein.
pub fn voice(new_leads: Option<i64>) -> Value {
    match new_leads {
        None => json!({"connected": false, "note": "cannot reach revenue_leads"}),
        Some(n) => json!({"connected": true, "new_leads": n, "pending_channels": ["glitch", "support", "company_mail"]}),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
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
}
