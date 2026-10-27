//! Module `intent@1` — email likhte waqt KAAM aur PAISA samajhna (Rule 52: kernel ke andar module, bikhri wasm nahi).
//!   1) scan_json: text mein WADA (commitment) + uski DEADLINE dhoondna ("will send by Friday", "kal tak bhej doon ga") — sirf
//!      deterministic qaide (koi model/network/guess nahi): wahi text + wahi `now` => hamesha wahi jawab. English + Roman Urdu.
//!   2) cost_json: "yeh email padhne mein kitna waqt/paisa lagega" — words x recipients x hourly rate. Formula SQL `attention_cost()`
//!      (E97) se bit-ba-bit milta hai (parity test dono taraf), taake browser aur server alag number na dikhayein.
//! Sirf std. Browser (wasm32) aur native `cargo test` dono par chalta hai.

/// Padhne ki raftaar (words/minute) aur har recipient par "context switch" ka fixed waqt (seconds). E97 attention_cost() mein wahi.
pub const DEFAULT_WPM: u32 = 220;
pub const SWITCH_SECONDS: u32 = 8;
/// Lambi email ki jagah 2 minute ki call ka mashwara (har participant ka waqt).
pub const CALL_MINUTES: u32 = 2;

/* ------------------------------------------------------------------ tareekh (civil <-> days since 1970-01-01) */
fn days_from_civil(y: i64, m: i64, d: i64) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let mp = (m + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

fn civil_from_days(z: i64) -> (i64, i64, i64) {
    let z = z + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    (if m <= 2 { y + 1 } else { y }, m, d)
}

/// 0 = Sunday .. 6 = Saturday
fn weekday(days: i64) -> i64 {
    (days + 4).rem_euclid(7)
}

fn iso(days: i64) -> String {
    let (y, m, d) = civil_from_days(days);
    format!("{y:04}-{m:02}-{d:02}")
}

const WEEKDAYS: [(&str, i64); 14] = [
    ("sunday", 0), ("monday", 1), ("tuesday", 2), ("wednesday", 3), ("thursday", 4), ("friday", 5), ("saturday", 6),
    ("sun", 0), ("mon", 1), ("tue", 2), ("wed", 3), ("thu", 4), ("fri", 5), ("sat", 6),
];
const WEEKDAY_NAMES: [&str; 7] = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const MONTHS: [(&str, i64); 23] = [
    ("january", 1), ("february", 2), ("march", 3), ("april", 4), ("may", 5), ("june", 6), ("july", 7), ("august", 8),
    ("september", 9), ("october", 10), ("november", 11), ("december", 12),
    ("jan", 1), ("feb", 2), ("mar", 3), ("apr", 4), ("jun", 6), ("jul", 7), ("aug", 8), ("sep", 9), ("oct", 10), ("nov", 11), ("dec", 12),
];

/* ------------------------------------------------------------------ chhote text helpers */
fn words(s: &str) -> Vec<String> {
    s.split(|c: char| !(c.is_alphanumeric() || c == '\'' || c == '-' || c == '/'))
        .filter(|w| !w.is_empty())
        .map(|w| w.trim_matches(|c| c == '\'' || c == '-' || c == '/').to_string())
        .filter(|w| !w.is_empty())
        .collect()
}

fn has_phrase(ws: &[String], phrase: &str) -> bool {
    let p: Vec<&str> = phrase.split(' ').collect();
    if p.is_empty() || ws.len() < p.len() {
        return false;
    }
    ws.windows(p.len()).any(|w| w.iter().zip(p.iter()).all(|(a, b)| a == b))
}

fn any_phrase(ws: &[String], list: &[&str]) -> bool {
    list.iter().any(|p| has_phrase(ws, p))
}

fn num(s: &str) -> Option<i64> {
    let t = s.trim_end_matches(|c: char| c.is_alphabetic()); // 3rd, 12th
    if t.is_empty() || t.len() > 4 || !t.chars().all(|c| c.is_ascii_digit()) {
        return None;
    }
    t.parse().ok()
}

fn number_word(s: &str) -> Option<i64> {
    match s {
        "a" | "an" | "one" | "ek" => Some(1),
        "two" | "do" => Some(2),
        "three" | "teen" => Some(3),
        "four" | "char" => Some(4),
        "five" | "paanch" | "panch" => Some(5),
        "six" => Some(6),
        "seven" => Some(7),
        _ => num(s),
    }
}

/* ------------------------------------------------------------------ DEADLINE nikalna */
#[derive(Debug, PartialEq, Clone)]
pub struct Due {
    pub days: i64,
    pub label: String,
    /// true = saaf tareekh/din ("Friday", "12 Nov"), false = andaza ("EOD", "next week")
    pub exact: bool,
}

fn next_weekday(today: i64, target: i64, strictly_after: bool) -> i64 {
    let mut d = (target - weekday(today)).rem_euclid(7);
    if d == 0 && strictly_after {
        d = 7;
    }
    today + d
}

pub fn parse_due(ws: &[String], today: i64) -> Option<Due> {
    // 1) ISO tareekh 2026-11-03
    for w in ws {
        let p: Vec<&str> = w.split('-').collect();
        if p.len() == 3 && p[0].len() == 4 {
            if let (Ok(y), Ok(m), Ok(d)) = (p[0].parse::<i64>(), p[1].parse::<i64>(), p[2].parse::<i64>()) {
                if (1..=12).contains(&m) && (1..=31).contains(&d) {
                    let days = days_from_civil(y, m, d);
                    return Some(Due { days, label: iso(days), exact: true });
                }
            }
        }
    }
    // 2) "12 nov [2026]" / "nov 12" / "12th november"
    for (i, w) in ws.iter().enumerate() {
        let month = MONTHS.iter().find(|(n, _)| n == w).map(|(_, m)| *m);
        if let Some(m) = month {
            let day = if i > 0 { num(&ws[i - 1]) } else { None }.or_else(|| ws.get(i + 1).and_then(|x| num(x)));
            if let Some(d) = day.filter(|d| (1..=31).contains(d)) {
                let (cy, _, _) = civil_from_days(today);
                let explicit_year = ws.get(i + 1).and_then(|x| num(x)).filter(|y| *y >= 2000 && *y <= 2100);
                let mut y = explicit_year.unwrap_or(cy);
                let mut days = days_from_civil(y, m, d);
                if explicit_year.is_none() && days < today {
                    y += 1;
                    days = days_from_civil(y, m, d);
                }
                return Some(Due { days, label: iso(days), exact: true });
            }
        }
    }
    // 3) "in 3 days / in two weeks / 3 din mein / 2 hafte mein"
    for i in 0..ws.len() {
        let unit = ws[i].as_str();
        let (mult, ok) = match unit {
            "day" | "days" | "din" => (1, true),
            "week" | "weeks" | "hafta" | "hafte" | "haftay" => (7, true),
            "hour" | "hours" | "ghanta" | "ghante" | "ghantay" | "hrs" | "hr" => (0, true),
            _ => (0, false),
        };
        if !ok || i == 0 {
            continue;
        }
        if let Some(n) = number_word(&ws[i - 1]) {
            let near_in = (i >= 2 && ws[i - 2] == "in") || ws.get(i + 1).map(|x| x == "mein" || x == "me" || x == "baad").unwrap_or(false) || ws.get(i + 1).map(|x| x == "later").unwrap_or(false);
            if near_in || (i >= 2 && ws[i - 2] == "within") {
                let days = today + n * mult;
                let label = if mult == 0 { "today".to_string() } else if n == 1 && mult == 1 { "tomorrow".to_string() } else { iso(days) };
                return Some(Due { days, label, exact: mult == 1 && true });
            }
        }
    }
    // 4) alfaaz
    let by_eod = any_phrase(ws, &["eod", "end of day", "end of the day", "close of business", "cob", "aaj raat tak", "aaj tak"]);
    if any_phrase(ws, &["today", "tonight", "aaj", "this evening", "this afternoon", "this morning", "right away", "asap"]) || by_eod {
        return Some(Due { days: today, label: "today".into(), exact: !by_eod && !any_phrase(ws, &["asap", "right away"]) });
    }
    if any_phrase(ws, &["day after tomorrow", "parson", "parsoon"]) {
        return Some(Due { days: today + 2, label: iso(today + 2), exact: true });
    }
    if any_phrase(ws, &["tomorrow", "tmrw", "kal"]) {
        return Some(Due { days: today + 1, label: "tomorrow".into(), exact: true });
    }
    // weekday (by/before/until/on/next/this/tak)
    for (i, w) in ws.iter().enumerate() {
        if let Some((_, t)) = WEEKDAYS.iter().find(|(n, _)| n == w) {
            // "may" mahina bhi hai, "sat"/"sun" aam alfaaz — chhote naam sirf tab jab saath mein by/on/next/tak ho
            let short = w.len() == 3;
            let ctx = (i > 0 && matches!(ws[i - 1].as_str(), "by" | "before" | "until" | "till" | "on" | "next" | "this" | "every"))
                || ws.get(i + 1).map(|x| x == "tak" || x == "ko" || x == "morning" || x == "afternoon").unwrap_or(false);
            if short && !ctx {
                continue;
            }
            let next_kw = i > 0 && ws[i - 1] == "next";
            let day = next_weekday(today, *t, true);
            let day = if next_kw && day - today <= 1 { day + 7 } else { day };
            let name = WEEKDAY_NAMES[*t as usize];
            return Some(Due { days: day, label: name.to_string(), exact: true });
        }
    }
    if any_phrase(ws, &["end of week", "end of the week", "eow", "by the weekend", "hafte tak", "is hafte"]) {
        let fri = next_weekday(today, 5, false);
        return Some(Due { days: fri, label: "Friday".into(), exact: false });
    }
    if any_phrase(ws, &["next week", "agle hafte", "agle haftay", "agle hafta"]) {
        // agle hafte ka Friday (kaam ka hafta khatam)
        let fri_this = next_weekday(today, 5, false);
        let fri = if fri_this - today < 3 { fri_this + 7 } else { fri_this + 7 };
        return Some(Due { days: fri, label: "next week".into(), exact: false });
    }
    if any_phrase(ws, &["end of month", "end of the month", "month end", "mahine ke aakhir tak", "mahine tak"]) {
        let (y, m, _) = civil_from_days(today);
        let (ny, nm) = if m == 12 { (y + 1, 1) } else { (y, m + 1) };
        let last = days_from_civil(ny, nm, 1) - 1;
        return Some(Due { days: last, label: iso(last), exact: false });
    }
    None
}

/* ------------------------------------------------------------------ WADA (commitment) pehchanna */
#[derive(Debug, PartialEq)]
pub struct Promise {
    pub phrase: String,
    pub action: String,
    pub due: Option<Due>,
    pub confidence: u32,
    pub lang: &'static str,
}

const EN_FIRST: [&str; 14] = [
    "i will", "i'll", "i shall", "we will", "we'll", "we shall", "i can have", "let me get", "i promise", "we promise",
    "i am going to", "i'm going to", "we are going to", "we're going to",
];
const EN_YOU: [&str; 6] = ["you will receive", "you will get", "you will have", "you'll receive", "you'll get", "you'll have"];
const EN_VERBS: [&str; 18] = [
    "send", "deliver", "share", "get back", "reply", "respond", "finish", "complete", "submit", "review", "call", "update", "confirm",
    "prepare", "ship", "forward", "follow up", "have it",
];
const UR_STRONG: [&str; 14] = [
    "doon ga", "dunga", "dungi", "doon gi", "denge", "dein ge", "karunga", "karungi", "kar dunga", "kar dungi", "kar denge", "bhej dunga", "bhej denge", "bhej doon ga",
];
const UR_VERBS: [&str; 10] = ["bhej", "kar", "de", "share", "send", "complete", "finish", "jama", "tayyar", "wapis"];
const NEGATE: [&str; 9] = ["won't", "will not", "cannot", "can't", "wont", "unless", "nahi", "nahin", "if you"];

fn sentences(text: &str) -> Vec<&str> {
    let mut out = vec![];
    let mut start = 0;
    let b = text.as_bytes();
    let mut i = 0;
    while i < b.len() {
        let c = b[i];
        let end_here = c == b'\n' || c == b'!' || c == b'?' || (c == b'.' && (i + 1 >= b.len() || b[i + 1] == b' ' || b[i + 1] == b'\n'));
        if end_here {
            let s = &text[start..=i];
            if !s.trim().is_empty() {
                out.push(s);
            }
            start = i + 1;
        }
        i += 1;
    }
    if start < text.len() && !text[start..].trim().is_empty() {
        out.push(&text[start..]);
    }
    out
}

pub fn promise_of(sentence: &str, today: i64) -> Option<Promise> {
    let trimmed = sentence.trim();
    if trimmed.ends_with('?') || trimmed.starts_with('>') || trimmed.len() < 8 {
        return None; // sawal ya quoted purani mail
    }
    let low = trimmed.to_lowercase().replace('\u{2019}', "'");
    let ws = words(&low);
    if any_phrase(&ws, &NEGATE) {
        return None;
    }
    let first = any_phrase(&ws, &EN_FIRST);
    let you = any_phrase(&ws, &EN_YOU);
    let en_verb = EN_VERBS.iter().any(|v| has_phrase(&ws, v)) || ws.iter().any(|w| matches!(w.as_str(), "send" | "deliver" | "share" | "finish" | "submit" | "review" | "call" | "update" | "confirm"));
    let ur_strong = any_phrase(&ws, &UR_STRONG);
    let ur_verb = UR_VERBS.iter().any(|v| ws.iter().any(|w| w == v));
    let en_promise = (first && en_verb) || (first && any_phrase(&ws, &["i promise", "we promise"])) || (you && en_verb);
    let ur_promise = ur_strong && ur_verb || ur_strong;
    if !(en_promise || ur_promise) {
        return None;
    }
    let due = parse_due(&ws, today);
    let mut confidence = 55u32;
    if let Some(d) = &due {
        confidence = if d.exact { 92 } else { 80 };
    }
    if you && !first {
        confidence = confidence.saturating_sub(10);
    }
    // lambi, kai-clause sentence = kam bharosa
    if ws.len() > 40 {
        confidence = confidence.saturating_sub(15);
    }
    if due.is_none() && !any_phrase(&ws, &["i promise", "we promise"]) {
        // tareekh ke baghair sirf mazboot alfaaz par — warna chup
        if !(ur_strong || first) {
            return None;
        }
    }
    Some(Promise {
        phrase: trimmed.to_string(),
        action: action_of(&ws, ur_promise && !en_promise),
        due,
        confidence,
        lang: if ur_promise && !en_promise { "ur" } else { "en" },
    })
}

/// Kaam ka chhota naam (task title): trigger ke baad ka hissa, deadline ke alfaaz hata kar. Na mile to poori sentence.
fn action_of(ws: &[String], ur: bool) -> String {
    let stop = ["by", "before", "until", "till", "on", "tak", "in", "within", "today", "tomorrow", "tonight", "next", "this", "kal", "aaj", "eod"];
    let start = ws
        .iter()
        .position(|w| matches!(w.as_str(), "will" | "i'll" | "we'll" | "shall" | "promise" | "going" | "get" | "have" | "receive"))
        .map(|p| p + 1)
        .unwrap_or(0);
    let mut out: Vec<&str> = vec![];
    if ur && start == 0 {
        // Roman Urdu: "Main Monday tak details bhej doon ga" -> "Details bhej doon" (zameer, din, tak, ga/gi/ge hata kar)
        let drop = ["main", "mein", "me", "hum", "ham", "kal", "aaj", "parson", "tak", "ko", "ga", "gi", "ge", "din", "hafte", "haftay", "hafta", "agle", "is"];
        for w in ws.iter() {
            if drop.contains(&w.as_str()) || num(w).is_some() || WEEKDAYS.iter().any(|(n, _)| n == w) {
                continue;
            }
            out.push(w);
            if out.len() >= 6 {
                break;
            }
        }
        let t = out.join(" ");
        if t.is_empty() {
            return "Follow up".to_string();
        }
        let mut c = t.chars();
        return c.next().map(|f| f.to_uppercase().collect::<String>() + c.as_str()).unwrap_or(t);
    }
    for w in ws.iter().skip(start) {
        if stop.contains(&w.as_str()) || WEEKDAYS.iter().any(|(n, _)| n == w && w.len() > 3) {
            break;
        }
        if w == "to" && out.is_empty() {
            continue;
        }
        out.push(w);
        if out.len() >= 10 {
            break;
        }
    }
    let t = out.join(" ");
    if t.is_empty() {
        "Follow up".to_string()
    } else {
        let mut c = t.chars();
        c.next().map(|f| f.to_uppercase().collect::<String>() + c.as_str()).unwrap_or(t)
    }
}

/* ------------------------------------------------------------------ JSON (haath se, koi dependency nahi) */
fn esc(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 2);
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            '\r' => o.push_str("\\r"),
            '\t' => o.push_str("\\t"),
            c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)),
            c => o.push(c),
        }
    }
    o
}

/// `now_unix` = abhi ka UTC unix second; `tz_min` = user ke time zone ka UTC se farq (minutes, +300 = Karachi).
pub fn scan_json(text: &str, now_unix: i64, tz_min: i32) -> String {
    let local = now_unix + (tz_min as i64) * 60;
    let today = local.div_euclid(86_400);
    let mut items: Vec<String> = vec![];
    for s in sentences(text).into_iter().take(60) {
        if let Some(p) = promise_of(s, today) {
            let due = match &p.due {
                Some(d) => format!("\"due_date\":\"{}\",\"due_label\":\"{}\",\"due_exact\":{}", iso(d.days), esc(&d.label), d.exact),
                None => "\"due_date\":null,\"due_label\":null,\"due_exact\":false".to_string(),
            };
            items.push(format!(
                "{{\"phrase\":\"{}\",\"action\":\"{}\",{},\"confidence\":{},\"lang\":\"{}\"}}",
                esc(&p.phrase), esc(&p.action), due, p.confidence, p.lang
            ));
        }
    }
    format!("{{\"promises\":[{}]}}", items.join(","))
}

/* ------------------------------------------------------------------ PAISA / WAQT */
/// words x recipients x hourly rate (minor unit = pence/cents per ghanta). Sab integer — SQL attention_cost() se bit-ba-bit.
/// seconds_each = ceil(words*60/wpm) + SWITCH_SECONDS ; total = seconds_each * recipients ; cost_minor = round(total*rate/3600).
pub fn cost_values(words: u32, recipients: u32, rate_minor_per_hour: u32, wpm: u32) -> (u64, u64, u64) {
    let wpm = if wpm == 0 { DEFAULT_WPM } else { wpm } as u64;
    let w = words as u64;
    let each = (w * 60).div_ceil(wpm) + SWITCH_SECONDS as u64;
    let total = each * recipients as u64;
    let cost = (total * rate_minor_per_hour as u64 + 1800) / 3600;
    (each, total, cost)
}

/// Mashwara: lambi email + kai log => 2 minute ki call sasti. Call ka kharcha = (recipients+1 yaani likhne wala bhi) x 2 min x rate.
pub fn cost_json(words: u32, recipients: u32, rate_minor_per_hour: u32, wpm: u32) -> String {
    let (each, total, cost) = cost_values(words, recipients, rate_minor_per_hour, wpm);
    let call_total_s = (recipients as u64 + 1) * CALL_MINUTES as u64 * 60;
    let call_cost = (call_total_s * rate_minor_per_hour as u64 + 1800) / 3600;
    let suggest = recipients >= 3 && words >= 180 && call_cost < cost;
    let saving = if suggest { cost - call_cost } else { 0 };
    format!(
        "{{\"seconds_each\":{each},\"seconds_total\":{total},\"cost_minor\":{cost},\"call_minutes\":{CALL_MINUTES},\"call_cost_minor\":{call_cost},\"suggest_call\":{suggest},\"saving_minor\":{saving}}}"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    // 2026-10-27 (Mangal / Tuesday) dopahar UTC
    const NOW: i64 = 1_793_102_400;
    fn today() -> i64 {
        (NOW + 300 * 60).div_euclid(86_400)
    }

    #[test]
    fn calendar_math_roundtrips() {
        assert_eq!(iso(today()), "2026-10-27");
        assert_eq!(weekday(today()), 2);
        for d in [0, 59, 60, 365, 11_017, 20_000, 24_000] {
            let (y, m, dd) = civil_from_days(d);
            assert_eq!(days_from_civil(y, m, dd), d);
        }
    }

    #[test]
    fn english_deadlines() {
        let p = promise_of("I will send you the details by Friday.", today()).unwrap();
        assert_eq!(p.due.as_ref().unwrap().label, "Friday");
        assert_eq!(iso(p.due.unwrap().days), "2026-10-30");
        assert!(p.confidence >= 90);
        let p = promise_of("We'll deliver the proposal tomorrow", today()).unwrap();
        assert_eq!(iso(p.due.unwrap().days), "2026-10-28");
        let p = promise_of("I will review it in 3 days", today()).unwrap();
        assert_eq!(iso(p.due.unwrap().days), "2026-10-30");
        let p = promise_of("I'll get back to you by 12 Nov", today()).unwrap();
        assert_eq!(iso(p.due.unwrap().days), "2026-11-12");
        let p = promise_of("I will finish the report by 2026-11-03.", today()).unwrap();
        assert_eq!(iso(p.due.unwrap().days), "2026-11-03");
        let p = promise_of("I will send it by next Monday", today()).unwrap();
        assert_eq!(iso(p.due.unwrap().days), "2026-11-02");
        let p = promise_of("I'll submit the form by EOD", today()).unwrap();
        assert!(!p.due.as_ref().unwrap().exact);
        assert_eq!(iso(p.due.unwrap().days), "2026-10-27");
    }

    #[test]
    fn same_weekday_means_next_week_not_today() {
        // aaj Mangal hai; "by Tuesday" => agla Mangal (7 din), aaj nahi
        let p = promise_of("I will send the file by Tuesday.", today()).unwrap();
        assert_eq!(iso(p.due.unwrap().days), "2026-11-03");
    }

    #[test]
    fn roman_urdu() {
        let p = promise_of("Main Monday tak details bhej doon ga", today()).unwrap();
        assert_eq!(p.lang, "ur");
        assert_eq!(p.action, "Details bhej doon");
        assert_eq!(iso(p.due.unwrap().days), "2026-11-02");
        let p = promise_of("Hum kal tak kar denge", today()).unwrap();
        assert_eq!(p.action, "Kar denge");
        assert_eq!(iso(p.due.unwrap().days), "2026-10-28");
        let p = promise_of("Main 2 din mein bhej dunga", today()).unwrap();
        assert_eq!(iso(p.due.unwrap().days), "2026-10-29");
    }

    #[test]
    fn not_a_promise() {
        assert!(promise_of("Can you send me the file by Friday?", today()).is_none()); // sawal
        assert!(promise_of("I won't be able to send it by Friday.", today()).is_none()); // inkaar
        assert!(promise_of("The meeting is on Friday.", today()).is_none()); // wada nahi
        assert!(promise_of("> I will send you the details by Friday.", today()).is_none()); // quoted
        assert!(promise_of("I will send it if you approve by Friday.", today()).is_none()); // shart
        assert!(promise_of("See you on sat", today()).is_none());
    }

    #[test]
    fn promise_without_date_is_low_confidence() {
        let p = promise_of("I promise to get this sorted for you.", today()).unwrap();
        assert!(p.due.is_none());
        assert!(p.confidence < 70);
    }

    #[test]
    fn scan_json_shape_and_escaping() {
        let j = scan_json("Hi,\nI will send you the \"final\" details by Friday.\nThanks", NOW, 300);
        assert!(j.starts_with("{\"promises\":[{"));
        assert!(j.contains("\"due_date\":\"2026-10-30\""));
        assert!(j.contains("\\\"final\\\""));
        assert_eq!(scan_json("hello there", NOW, 300), "{\"promises\":[]}");
        // deterministic
        assert_eq!(scan_json("I will send it by Friday.", NOW, 300), scan_json("I will send it by Friday.", NOW, 300));
    }

    #[test]
    fn action_title_is_clean() {
        let p = promise_of("I'll deliver it tomorrow", today()).unwrap();
        assert_eq!(p.action, "Deliver it");
        let p = promise_of("I will send you the revised contract by Friday", today()).unwrap();
        assert_eq!(p.action, "Send you the revised contract");
    }

    #[test]
    fn cost_matches_sql_formula_and_suggests_call() {
        // 400 words, 10 recipients, £100/ghanta (10_000 pence): each = ceil(24000/220)=110 +8 = 118s; total 1180s; cost = round(1180*10000/3600)=3278
        assert_eq!(cost_values(400, 10, 10_000, 220), (118, 1180, 3278));
        let j = cost_json(400, 10, 10_000, 220);
        assert!(j.contains("\"cost_minor\":3278"));
        // call: 11 log x 2 min = 1320s => 3667 pence > 3278 => call mehengi, jhoota mashwara nahi
        assert!(j.contains("\"suggest_call\":false") && j.contains("\"saving_minor\":0"));
        // 1500 words: each=418s, total=4180s => 11611 pence; call 3667 => bachat 7944
        let j = cost_json(1500, 10, 10_000, 220);
        assert!(j.contains("\"cost_minor\":11611") && j.contains("\"suggest_call\":true") && j.contains("\"saving_minor\":7944"));
        // chhoti email, 1 recipient: koi mashwara nahi
        assert!(cost_json(40, 1, 10_000, 220).contains("\"suggest_call\":false"));
        // wpm 0 => default
        assert_eq!(cost_values(220, 1, 3600, 0), (68, 68, 68));
    }
}
