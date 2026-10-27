// ============================================================================
// workx_core — Work (tasks/promises) + CRM overview ka HISAAB. Sirf std: installer pre-flight `rustc --edition 2021 --test` se pehle test karta hai.
// Bun /api/work/tasks, /api/work/promises, /api/crm/overview ka Rust (Tokio) version; formula Bun jaisa hi (migration, naya formula nahi).
// Gate: teeno Pro+ (Basic ko 403). I/O workx_glue.rs mein.
// ============================================================================

/// Pro+ procs. Some(paigham) = Basic ko 403 `feature_not_available`.
pub fn pro_only(proc: &str) -> Option<&'static str> {
    match proc {
        "work.tasks" => Some("Tasks and boards are a Pro+ feature."),
        "work.promises" => Some("Promise inbox is a Pro+ feature."),
        "crm.overview" => Some("CRM is on Pro and above."),
        "work.task.create" | "work.task.update" => Some("Tasks and boards are a Pro+ feature."),
        "work.followThrough" => Some("Follow-through score is a Pro+ feature."),
        "work.note" | "work.note.save" => Some("Notes on threads and meetings are a Pro+ feature."),
        "calendar.outcome.post" => Some("Meeting outcomes are a Pro+ feature."),
        _ => None,
    }
}

pub fn plan_allows_pro(plan: &str) -> bool {
    let p = plan.trim().to_lowercase().replace([' ', '-'], "_");
    p.starts_with("ai_") || matches!(p.as_str(), "pro" | "business" | "business_pro" | "businesspro" | "enterprise")
}

/// Bun STAGE_PROB.
pub fn stage_prob(stage: &str) -> f64 {
    match stage {
        "new" => 10.0,
        "qualified" => 30.0,
        "proposal" => 55.0,
        "negotiation" => 75.0,
        "won" => 100.0,
        _ => 0.0, // lost + unknown
    }
}

/// Task late = completed hai AUR due ke baad complete hua.
pub fn task_late(completed: Option<i64>, due: Option<i64>) -> bool {
    matches!((completed, due), (Some(c), Some(d)) if c > d)
}

/// Epoch ka UTC mahina shuru (1st 00:00:00). Howard Hinnant civil algorithms (std-only).
pub fn month_start(now: i64) -> i64 {
    let z = now.div_euclid(86_400) + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153; // 0 = March
    let d = doy - (153 * mp + 2) / 5; // 0-based din
    (z - d - 719_468) * 86_400
}

#[derive(Debug, Clone)]
pub struct DealIn {
    pub stage: String,
    pub value: f64,
    pub prob: Option<f64>,
    pub updated: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct LeadIn {
    pub state: String,
    pub touched: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct StageCount {
    pub stage: &'static str,
    pub count: usize,
    pub value: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Overview {
    pub pipeline_value: f64,
    pub weighted_value: f64,
    pub won_this_month: f64,
    pub open_deals: usize,
    pub leads_new: usize,
    pub leads_unworked: usize,
    pub stale_deals: usize,
    pub stage_counts: Vec<StageCount>,
}

pub const STAGES: [&str; 6] = ["new", "qualified", "proposal", "negotiation", "won", "lost"];

pub fn overview(deals: &[DealIn], leads: &[LeadIn], now: i64) -> Overview {
    let open: Vec<&DealIn> = deals.iter().filter(|d| d.stage != "won" && d.stage != "lost").collect();
    let ms = month_start(now);
    let weighted: f64 = open.iter().map(|d| d.value * (d.prob.unwrap_or_else(|| stage_prob(&d.stage)) / 100.0)).sum();
    Overview {
        pipeline_value: open.iter().map(|d| d.value).sum(),
        weighted_value: weighted.round(),
        won_this_month: deals.iter().filter(|d| d.stage == "won" && d.updated.unwrap_or(0) >= ms).map(|d| d.value).sum(),
        open_deals: open.len(),
        leads_new: leads.iter().filter(|l| l.state == "new").count(),
        leads_unworked: leads.iter().filter(|l| l.state == "new" && !l.touched).count(),
        stale_deals: open.iter().filter(|d| d.updated.map(|u| (now - u).div_euclid(86_400) >= 14).unwrap_or(false)).count(),
        stage_counts: STAGES
            .iter()
            .map(|s| StageCount {
                stage: s,
                count: deals.iter().filter(|d| d.stage == *s).count(),
                value: deals.iter().filter(|d| d.stage == *s).map(|d| d.value).sum(),
            })
            .collect(),
    }
}

// ── Pro 7 endpoints (27 Oct): tasks create/update, follow-through, notes, meeting outcome — Bun calendar.ts ka Rust twin ──
pub const TASK_STATUSES: [&str; 4] = ["todo", "doing", "waiting", "done"];
pub const NOTE_MAX: usize = 20_000;

/// Title: trim, kam az kam 2 chars (Bun `bad_title`), 300 se zyada nahi.
pub fn task_title(s: &str) -> Option<String> {
    let t = s.trim();
    let n = t.chars().count();
    if (2..=300).contains(&n) { Some(t.to_string()) } else { None }
}

pub fn status_ok(s: &str) -> bool {
    TASK_STATUSES.contains(&s)
}

/// uuid shakal (8-4-4-4-12 hex): PostgREST ko galat id jane se pehle rok do.
pub fn uuid_ok(s: &str) -> bool {
    let p: Vec<&str> = s.split('-').collect();
    p.len() == 5 && [8usize, 4, 4, 4, 12].iter().zip(p.iter()).all(|(n, x)| x.len() == *n && x.chars().all(|c| c.is_ascii_hexdigit()))
}

/// Note body: 20,000 chars tak (Bun `too_long`).
pub fn note_len_ok(s: &str) -> bool {
    s.chars().count() <= NOTE_MAX
}

/// Follow-through: ek task (due wala) ka nateeja.
#[derive(Debug, Clone, PartialEq)]
pub struct Bucket {
    pub made: u32,
    pub on_time: u32,
    pub late: u32,
    pub broken: u32,
}

/// (completed, due, now) => 0 = on_time, 1 = late, 2 = broken, 3 = abhi open (due nahi guzra).
pub fn ft_class(completed: Option<i64>, due: i64, now: i64) -> u8 {
    match completed {
        Some(c) if c <= due => 0,
        Some(_) => 1,
        None if due < now => 2,
        None => 3,
    }
}

pub fn ft_add(b: &mut Bucket, class: u8) {
    b.made += 1;
    match class {
        0 => b.on_time += 1,
        1 => b.late += 1,
        2 => b.broken += 1,
        _ => {}
    }
}

/// Score = round((on_time + late*0.5) / made * 100); made==0 => None. (Bun jaisa; .5 upar round.)
pub fn ft_score(b: &Bucket) -> Option<i64> {
    if b.made == 0 {
        return None;
    }
    Some(((b.on_time as f64 + b.late as f64 * 0.5) / b.made as f64 * 100.0).round() as i64)
}

/// Epoch seconds => "YYYY-MM-DDTHH:MM:SSZ" (PostgREST gte filter ke liye; chrono crate nahi).
pub fn iso_utc(epoch: i64) -> String {
    let (days, secs) = (epoch.div_euclid(86400), epoch.rem_euclid(86400));
    let z = days + 719468;
    let era = z.div_euclid(146097);
    let doe = z.rem_euclid(146097);
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z", secs / 3600, (secs % 3600) / 60, secs % 60)
}

#[cfg(test)]
mod tests {
    use super::*;

    const DAY: i64 = 86_400;
    // 2026-10-26T12:00:00Z
    const NOW: i64 = 1_793_016_000;

    fn deal(stage: &str, value: f64, prob: Option<f64>, updated_days_ago: Option<i64>) -> DealIn {
        DealIn { stage: stage.into(), value, prob, updated: updated_days_ago.map(|d| NOW - d * DAY) }
    }

    #[test]
    fn gate_is_pro_plus_for_exactly_these_procs() {
        for p in ["work.tasks", "work.promises", "crm.overview"] {
            assert!(pro_only(p).is_some(), "{p}");
        }
        assert!(pro_only("work.tasks.list").is_none() && pro_only("mail.threads").is_none());
        assert!(!plan_allows_pro("basic") && !plan_allows_pro("") && !plan_allows_pro("Basic"));
        for p in ["pro", "business", "business_pro", "Business Pro", "enterprise", "ai_pro"] {
            assert!(plan_allows_pro(p), "{p}");
        }
    }

    #[test]
    fn month_start_is_utc_first_of_month() {
        assert_eq!(month_start(NOW), NOW - (25 * DAY + 12 * 3600)); // 2026-10-01T00:00:00Z
        assert_eq!(month_start(0), 0); // 1970-01-01
        assert_eq!(month_start(31 * DAY - 1), 0); // Jan 31 23:59:59 1970
        assert_eq!(month_start(31 * DAY), 31 * DAY); // Feb 1 1970
        assert_eq!(month_start(1_709_251_199), 1_706_745_600); // 2024-02-29T23:59:59Z -> 2024-02-01 (leap year)
    }

    #[test]
    fn stage_prob_and_late() {
        assert_eq!((stage_prob("new"), stage_prob("proposal"), stage_prob("won"), stage_prob("lost"), stage_prob("x")), (10.0, 55.0, 100.0, 0.0, 0.0));
        assert!(task_late(Some(11), Some(10)));
        assert!(!task_late(Some(10), Some(10)) && !task_late(None, Some(10)) && !task_late(Some(10), None));
    }

    #[test]
    fn overview_matches_the_bun_formula() {
        let deals = vec![
            deal("new", 1000.0, None, Some(1)),            // 10% -> 100
            deal("proposal", 2000.0, None, Some(20)),      // 55% -> 1100, stale
            deal("negotiation", 1000.0, Some(50.0), Some(14)), // explicit 50% -> 500, stale (14 din)
            deal("won", 5000.0, None, Some(2)),            // is mahine (Oct 24)
            deal("won", 700.0, None, Some(60)),            // purana mahina
            deal("lost", 300.0, None, Some(3)),
        ];
        let leads = vec![
            LeadIn { state: "new".into(), touched: false },
            LeadIn { state: "new".into(), touched: true },
            LeadIn { state: "working".into(), touched: false },
        ];
        let o = overview(&deals, &leads, NOW);
        assert_eq!(o.open_deals, 3);
        assert_eq!(o.pipeline_value, 4000.0);
        assert_eq!(o.weighted_value, 1700.0);
        assert_eq!(o.won_this_month, 5000.0);
        assert_eq!((o.leads_new, o.leads_unworked, o.stale_deals), (2, 1, 2));
        assert_eq!(o.stage_counts.len(), 6);
        assert_eq!(o.stage_counts[4], StageCount { stage: "won", count: 2, value: 5700.0 });
    }

    #[test]
    fn empty_is_zero_not_invented() {
        let o = overview(&[], &[], NOW);
        assert_eq!((o.pipeline_value, o.weighted_value, o.won_this_month, o.open_deals, o.leads_new), (0.0, 0.0, 0.0, 0, 0));
        assert!(o.stage_counts.iter().all(|s| s.count == 0 && s.value == 0.0));
    }

    #[test]
    fn pro7_gates_and_validators() {
        for p in ["work.task.create", "work.task.update", "work.followThrough", "work.note", "work.note.save", "calendar.outcome.post"] {
            assert!(pro_only(p).is_some(), "{p}");
        }
        assert!(pro_only("calendar.availability").is_none());
        assert_eq!(task_title("  ab "), Some("ab".to_string()));
        assert_eq!(task_title("a"), None);
        assert_eq!(task_title(&"x".repeat(301)), None);
        assert!(status_ok("waiting") && !status_ok("blocked") && !status_ok(""));
        assert!(uuid_ok("123e4567-e89b-12d3-a456-426614174000") && !uuid_ok("1 or true"));
        assert!(note_len_ok(&"a".repeat(20_000)) && !note_len_ok(&"a".repeat(20_001)));
    }
    #[test]
    fn follow_through() {
        assert_eq!(ft_class(Some(10), 10, 99), 0);
        assert_eq!(ft_class(Some(11), 10, 99), 1);
        assert_eq!(ft_class(None, 10, 99), 2);
        assert_eq!(ft_class(None, 100, 99), 3);
        let mut b = Bucket { made: 0, on_time: 0, late: 0, broken: 0 };
        assert_eq!(ft_score(&b), None);
        for c in [0u8, 0, 1, 2] { ft_add(&mut b, c); }
        assert_eq!(b, Bucket { made: 4, on_time: 2, late: 1, broken: 1 });
        assert_eq!(ft_score(&b), Some(63)); // (2+0.5)/4 = 62.5 -> 63
        ft_add(&mut b, 3);
        assert_eq!(b.made, 5);
    }
}
