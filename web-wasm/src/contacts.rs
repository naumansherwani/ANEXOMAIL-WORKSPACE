//! Module `contacts@1` (Q-contacts-kernel, 18 Nov 2026): the founder address-book filter + frecency rank, in the Rust WASM kernel instead of TypeScript.
//! It is the exact twin of founder-web/src/book.ts (`suggest`): same fold, same prefix rules, same frecency (ln(1 + 3*sent + recv) * 2^(-days/45), pinned +1e9),
//! same order (score desc, then the address in plain byte order). A shared JSON vector file (contacts_vectors.json, GENERATED from book.ts) is tested on BOTH sides, so the two can never drift.
//! Input JSON: {"q": typed text, "taken": [addresses already in a row], "now": ms, "max": n, "c": [{"a": addr, "n": name, "s": sent, "r": recv, "l": last activity ms or null, "p": pinned}]}.
//! Output JSON: {"hits": [{"i": index into c, "why": "name"|"address"|"domain", "score": f64}]}. The caller turns last_sent / last_recv into ONE number `l` (the later of the two), so the kernel never parses a date.
//! Fold = lower-case + Latin accents (Latin-1, Latin Extended-A) removed + combining marks U+0300..U+036F dropped + fullwidth ASCII to ASCII: the same result as the browser's NFKD for every Latin name
//! (Urdu / Arabic / CJK names are only lower-cased by both, so they still match each other letter for letter). No ICU, no extra crate, so the kernel stays small.
use serde_json::{json, Value};
use std::collections::HashSet;

pub const MIN_CHARS: usize = 2;
pub const MAX_ROWS: usize = 8;
const HALF_LIFE_DAYS: f64 = 45.0;

const FOLD: &[(&str, char)] = &[
    ("àáâãäåāăą", 'a'), ("çćĉċč", 'c'), ("ď", 'd'), ("èéêëēĕėęě", 'e'), ("ĝğġģ", 'g'), ("ĥ", 'h'), ("ìíîïĩīĭį", 'i'), ("ĵ", 'j'), ("ķ", 'k'), ("ĺļľ", 'l'),
    ("ñńņň", 'n'), ("òóôõöōŏő", 'o'), ("ŕŗř", 'r'), ("śŝşšſ", 's'), ("ţť", 't'), ("ùúûüũūŭůűų", 'u'), ("ŵ", 'w'), ("ýÿŷ", 'y'), ("źżž", 'z'),
];

pub fn fold(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for ch in s.chars() {
        let ch = if ('\u{FF01}'..='\u{FF5E}').contains(&ch) { char::from_u32(ch as u32 - 0xFEE0).unwrap_or(ch) } else { ch }; // fullwidth ASCII
        for l in ch.to_lowercase() {
            if ('\u{0300}'..='\u{036F}').contains(&l) { continue; } // combining marks
            if l == 'ĳ' { out.push_str("ij"); continue; }
            match FOLD.iter().find(|(set, _)| set.contains(l)) { Some((_, base)) => out.push(*base), None => out.push(l) }
        }
    }
    out
}

/// What was typed, reduced to the searched part: leading space / quote / `<` and trailing `>` / quote removed, folded, trimmed.
pub fn needle(typed: &str) -> String {
    let a = typed.trim_start_matches(|c: char| c.is_whitespace() || c == '"' || c == '<');
    let b = a.trim_end_matches(|c: char| c == '>' || c == '"');
    fold(b).trim().to_string()
}

fn is_name_sep(c: char) -> bool { c.is_whitespace() || matches!(c, '.' | ',' | '_' | '-') }
fn is_local_sep(c: char) -> bool { matches!(c, '.' | '_' | '+' | '%' | '-') }

pub fn matches(addr: &str, name: &str, q: &str) -> Option<&'static str> {
    if q.is_empty() { return None; }
    let (name, addr) = (fold(name), fold(addr));
    let at = addr.find('@');
    let dom = at.map(|i| &addr[i + 1..]).unwrap_or("");
    if name.split(is_name_sep).any(|w| !w.is_empty() && w.starts_with(q)) || name.starts_with(q) { return Some("name"); }
    if addr.starts_with(q) || at.is_some_and(|i| i > 0 && addr[..i].split(is_local_sep).any(|w| w.starts_with(q))) { return Some("address"); }
    if (q.contains('@') && addr.starts_with(q)) || (!q.contains('@') && dom.starts_with(q)) { return Some("domain"); }
    None
}

pub fn score(sent: f64, recv: f64, last_ms: Option<f64>, pinned: bool, now_ms: f64) -> f64 {
    let last = last_ms.filter(|n| n.is_finite()).unwrap_or(now_ms);
    let days = (now_ms - last).max(0.0) / 86_400_000.0;
    (if pinned { 1e9 } else { 0.0 }) + (1.0 + 3.0 * sent.max(0.0) + recv.max(0.0)).ln() * (-days / HALF_LIFE_DAYS).exp2()
}

/// The whole operation. A wrong shape gives `{"ok":false}` (the browser then uses its TypeScript twin, never an empty list by surprise).
pub fn suggest_json(input: &str) -> String {
    let Ok(v) = serde_json::from_str::<Value>(input) else { return r#"{"ok":false,"problem":"bad json"}"#.into() };
    let (Some(typed), Some(cs), Some(now)) = (v["q"].as_str(), v["c"].as_array(), v["now"].as_f64()) else { return r#"{"ok":false,"problem":"bad shape"}"#.into() };
    let max = v["max"].as_u64().unwrap_or(MAX_ROWS as u64).clamp(1, 50) as usize;
    let q = needle(typed);
    if q.chars().count() < MIN_CHARS { return json!({"ok": true, "hits": []}).to_string(); }
    let taken: HashSet<&str> = v["taken"].as_array().map(|a| a.iter().filter_map(|x| x.as_str()).collect()).unwrap_or_default();
    let mut hits: Vec<(usize, &'static str, f64, &str)> = Vec::new();
    for (i, c) in cs.iter().enumerate() {
        let (Some(addr), name) = (c["a"].as_str(), c["n"].as_str().unwrap_or("")) else { continue };
        if taken.contains(addr) { continue; }
        if let Some(why) = matches(addr, name, &q) {
            let rank = match why { "name" => 0.02, "address" => 0.01, _ => 0.0 };
            hits.push((i, why, score(c["s"].as_f64().unwrap_or(0.0), c["r"].as_f64().unwrap_or(0.0), c["l"].as_f64(), c["p"].as_bool().unwrap_or(false), now) + rank, addr));
        }
    }
    hits.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap_or(std::cmp::Ordering::Equal).then_with(|| a.3.cmp(b.3)));
    hits.truncate(max);
    json!({"ok": true, "hits": hits.iter().map(|h| json!({"i": h.0, "why": h.1, "score": h.2})).collect::<Vec<_>>()}).to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn fold_removes_accents_and_case() {
        assert_eq!(fold("Zoyá"), "zoya"); assert_eq!(fold("ÉLODIE Müller"), "elodie muller"); assert_eq!(fold("ŁÓDŹ"), "łodz"); assert_eq!(fold("İstanbul"), "istanbul");
        assert_eq!(fold("ＡＢＣ@ｅｘ.com"), "abc@ex.com"); assert_eq!(fold("e\u{0301}"), "e"); assert_eq!(fold("نعمان"), "نعمان");
    }
    #[test]
    fn needle_strips_the_typing_decoration() { assert_eq!(needle("  \"<Ali>\""), "ali"); assert_eq!(needle("  \"<Ali>\" "), "ali>\""); assert_eq!(needle("Zoyá"), "zoya"); } // a trailing space stops the strip: same as the TypeScript twin
    #[test]
    fn prefix_rules_match_the_typescript_twin() {
        assert_eq!(matches("ali@x.com", "Ali Khan", "kha"), Some("name"));
        assert_eq!(matches("ali.khan@x.com", "", "kha"), Some("address"));
        assert_eq!(matches("a@gmail.com", "", "gma"), Some("domain"));
        assert_eq!(matches("a@gmail.com", "", "zzz"), None); assert_eq!(matches("a@b.com", "", ""), None);
    }
    #[test]
    fn frecency_is_the_sql_number() {
        let now = 1_700_000_000_000.0;
        assert!((score(2.0, 1.0, Some(now), false, now) - 8f64.ln()).abs() < 1e-12);
        assert!((score(2.0, 1.0, Some(now - 45.0 * 86_400_000.0), false, now) - 8f64.ln() / 2.0).abs() < 1e-12);
        assert!(score(0.0, 1.0, None, true, now) > 1e9);
    }
    #[test]
    fn short_or_broken_input_is_safe() {
        assert!(suggest_json(r#"{"q":"a","c":[],"now":1}"#).contains("\"hits\":[]"));
        assert!(suggest_json("nope").contains("\"ok\":false")); assert!(suggest_json(r#"{"q":1}"#).contains("\"ok\":false"));
    }
    #[test]
    fn it_equals_the_typescript_vectors() {
        // contacts_vectors.json is GENERATED from founder-web/src/book.ts (founder-web/sim/gen_contacts_vectors.ts): same input -> same hits, same order, scores within 1e-9
        let v: Value = serde_json::from_str(include_str!("contacts_vectors.json")).unwrap();
        let cases = v["cases"].as_array().unwrap();
        assert!(cases.len() >= 12, "vector file too small");
        for (n, case) in cases.iter().enumerate() {
            let got: Value = serde_json::from_str(&suggest_json(&case["input"].to_string())).unwrap();
            let (g, w) = (got["hits"].as_array().unwrap(), case["hits"].as_array().unwrap());
            assert_eq!(g.len(), w.len(), "case {n} {}: hit count", case["name"]);
            for (a, b) in g.iter().zip(w) {
                assert_eq!((a["i"].as_u64(), a["why"].as_str()), (b["i"].as_u64(), b["why"].as_str()), "case {n} {}: order or reason", case["name"]);
                assert!((a["score"].as_f64().unwrap() - b["score"].as_f64().unwrap()).abs() < 1e-9, "case {n} {}: score", case["name"]);
            }
        }
    }
}
