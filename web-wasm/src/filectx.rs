//! Module `filectx@1` — email likhte waqt FILE ka zikr pakadna ("the latest CRM sheet", "Q3_budget.xlsx").
//! Browser mein, deterministic, bina network: sirf text se (phrase, search-query, explicit-naam-hai-ya-nahi, "latest" ka ishara) nikalta hai.
//! Asli file ka live structure (version, uploader, thread, diff) server (SQL E99 file_context_find) se aata hai — yahan sirf pehchaan.
//! Sirf std. Browser (wasm32) aur native `cargo test` dono par.

const NOUNS: [&str; 26] = [
    "sheet", "spreadsheet", "file", "report", "deck", "doc", "document", "proposal", "contract", "invoice", "presentation", "pdf",
    "quote", "quotation", "agreement", "brief", "sow", "budget", "forecast", "roadmap", "schedule", "plan", "export", "list", "template", "slides",
];
const LATEST: [&str; 9] = ["latest", "updated", "new", "newest", "final", "current", "revised", "recent", "last"];
const ATTACHED: [&str; 4] = ["attached", "attaching", "enclosed", "attach"];
const STOP: [&str; 24] = [
    "the", "a", "an", "my", "our", "your", "this", "that", "these", "those", "of", "for", "to", "in", "on", "with", "and", "or", "is", "are", "see", "find", "please", "here",
];
const EXTS: [&str; 16] = ["pdf", "xlsx", "xls", "csv", "docx", "doc", "pptx", "ppt", "txt", "png", "jpg", "jpeg", "zip", "key", "numbers", "pages"];

#[derive(Debug, PartialEq, Clone)]
pub struct Mention {
    pub phrase: String,
    pub query: String,
    pub explicit: bool,
    pub latest: bool,
}

fn clean_word(w: &str) -> String {
    w.trim_matches(|c: char| !(c.is_alphanumeric() || c == '_' || c == '-' || c == '.')).trim_end_matches('.').to_string()
}

fn is_filename(w: &str) -> bool {
    match w.rsplit_once('.') {
        Some((stem, ext)) => !stem.is_empty() && stem.len() <= 80 && EXTS.contains(&ext.to_lowercase().as_str()) && stem.chars().all(|c| c.is_alphanumeric() || c == '_' || c == '-' || c == '.' || c == ' '),
        None => false,
    }
}

pub fn scan(text: &str) -> Vec<Mention> {
    let mut out: Vec<Mention> = vec![];
    for line in text.lines() {
        if line.trim_start().starts_with('>') {
            continue; // quoted purani mail
        }
        let raw: Vec<String> = line.split_whitespace().map(clean_word).filter(|w| !w.is_empty()).collect();
        let low: Vec<String> = raw.iter().map(|w| w.to_lowercase()).collect();
        let mut i = 0;
        while i < raw.len() {
            if is_filename(&raw[i]) {
                let stem = raw[i].rsplit_once('.').map(|x| x.0).unwrap_or(&raw[i]);
                let q: Vec<String> = stem.split(|c: char| !c.is_alphanumeric()).filter(|p| !p.is_empty()).map(|p| p.to_lowercase()).collect();
                push(&mut out, Mention { phrase: raw[i].clone(), query: q.join(" "), explicit: true, latest: false });
                i += 1;
                continue;
            }
            if NOUNS.contains(&low[i].as_str()) {
                // peeche 4 shabd tak: [article/attached] [latest] content-words noun
                let lo = i.saturating_sub(4);
                let mut start = i;
                let (mut latest, mut marker) = (false, false);
                let mut content: Vec<String> = vec![];
                let mut j = i;
                while j > lo {
                    j -= 1;
                    let w = low[j].as_str();
                    if LATEST.contains(&w) {
                        latest = true;
                        marker = true;
                        start = j;
                        continue;
                    }
                    if ATTACHED.contains(&w) || matches!(w, "the" | "my" | "our" | "your" | "this") {
                        marker = true;
                        break;
                    }
                    if STOP.contains(&w) || !raw[j].chars().all(|c| c.is_alphanumeric() || c == '_' || c == '-') || latest {
                        break;
                    }
                    content.insert(0, w.to_string());
                    start = j;
                }
                // "the report" akela itna aam hai: ya to content word + ishara (the/attached/latest), ya "latest <noun>"
                if (!content.is_empty() && marker) || latest {
                    let mut q = content.clone();
                    q.push(low[i].clone());
                    push(&mut out, Mention { phrase: raw[start..=i].join(" "), query: q.join(" "), explicit: false, latest });
                }
            }
            i += 1;
        }
        if out.len() >= 3 {
            break;
        }
    }
    out.truncate(3);
    out
}

fn push(out: &mut Vec<Mention>, m: Mention) {
    if m.query.trim().is_empty() || out.iter().any(|x| x.query == m.query) {
        return;
    }
    out.push(m);
}

fn esc(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 2);
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            c if (c as u32) < 0x20 => o.push(' '),
            c => o.push(c),
        }
    }
    o
}

pub fn scan_json(text: &str) -> String {
    let items: Vec<String> = scan(text)
        .iter()
        .map(|m| format!("{{\"phrase\":\"{}\",\"query\":\"{}\",\"explicit\":{},\"latest\":{}}}", esc(&m.phrase), esc(&m.query), m.explicit, m.latest))
        .collect();
    format!("{{\"mentions\":[{}]}}", items.join(","))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn q(t: &str) -> Vec<(String, String, bool, bool)> {
        scan(t).into_iter().map(|m| (m.phrase, m.query, m.explicit, m.latest)).collect()
    }

    #[test]
    fn finds_latest_named_file() {
        let r = q("Please see the latest CRM sheet before the call.");
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].0, "latest CRM sheet");
        assert_eq!(r[0].1, "crm sheet");
        assert!(r[0].3 && !r[0].2);
    }

    #[test]
    fn explicit_filenames() {
        let r = q("I attached Q3_budget-v2.xlsx and notes.pdf for you.");
        assert_eq!(r.len(), 2);
        assert_eq!(r[0].1, "q3 budget v2");
        assert!(r[0].2 && r[1].2);
        assert_eq!(r[1].1, "notes");
    }

    #[test]
    fn generic_nouns_alone_stay_quiet() {
        assert!(q("I will review the report tomorrow.").is_empty());
        assert!(q("What is the plan?").is_empty());
        assert!(q("see you soon").is_empty());
    }

    #[test]
    fn marker_plus_content_word_is_enough() {
        let r = q("Here is the sales forecast.");
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].1, "sales forecast");
        let r = q("our Acme contract is ready");
        assert_eq!(r[0].1, "acme contract");
    }

    #[test]
    fn quoted_lines_and_limits() {
        assert!(q("> the latest CRM sheet").is_empty());
        let many = "the latest A sheet\nthe latest B sheet\nthe latest C sheet\nthe latest D sheet";
        assert_eq!(scan(many).len(), 3);
        assert_eq!(scan("the latest Alpha sheet\nthe latest Alpha sheet").len(), 1);
    }

    #[test]
    fn json_is_escaped_and_stable() {
        let j = scan_json("the latest \"CRM\" sheet");
        assert!(j.starts_with("{\"mentions\":["));
        assert_eq!(scan_json("hello"), "{\"mentions\":[]}");
        assert_eq!(scan_json("the latest CRM sheet"), scan_json("the latest CRM sheet"));
    }
}
