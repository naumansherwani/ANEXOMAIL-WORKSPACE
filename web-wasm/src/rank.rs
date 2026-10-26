//! Module `rank@1` — bade list par tez filter + ranking (mail search / command palette / contacts). Rust mein: 100k items par bhi frame nahi girta.
//! Items = '\n' se juda utf-8 text; jawab = best-pehle indices. Score: exact > prefix > word-prefix > substring > subsequence.

fn score(q: &str, item: &str) -> Option<u32> {
    if q.is_empty() {
        return Some(1);
    }
    let it = item.to_lowercase();
    if it == q {
        return Some(10_000);
    }
    if it.starts_with(q) {
        return Some(8_000 - it.len().min(1_000) as u32);
    }
    if it.split(|c: char| !c.is_alphanumeric()).any(|w| !w.is_empty() && w.starts_with(q)) {
        return Some(6_000 - it.len().min(1_000) as u32);
    }
    if let Some(pos) = it.find(q) {
        return Some(4_000 - (pos.min(1_000) as u32) - it.len().min(1_000) as u32 / 4);
    }
    // subsequence: har akshar apni tarteeb mein; kam gap = behtar
    let mut chars = it.chars();
    let mut gap = 0u32;
    let mut last_hit = true;
    for qc in q.chars() {
        loop {
            match chars.next() {
                Some(c) if c == qc => {
                    last_hit = true;
                    break;
                }
                Some(_) => {
                    if !last_hit {
                        gap += 1;
                    }
                    last_hit = false;
                }
                None => return None,
            }
        }
    }
    Some(2_000u32.saturating_sub(gap.min(1_900)))
}

/// Best-pehle indices (<= limit). Khali query = pehle `limit` items jaisi tarteeb mein.
pub fn rank(query: &str, items: &str, limit: usize) -> Vec<u32> {
    let q = query.trim().to_lowercase();
    let mut hits: Vec<(u32, usize, usize)> = Vec::new(); // (score, len, index)
    for (i, line) in items.split('\n').enumerate() {
        if let Some(s) = score(&q, line) {
            hits.push((s, line.len(), i));
        }
    }
    hits.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));
    hits.into_iter().take(limit.min(10_000)).map(|(_, _, i)| i as u32).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exact_beats_prefix_beats_word_beats_substring_beats_fuzzy() {
        let items = "xxfooxx\nfoo bar\nbar foo\nfoo\nf-o-o";
        // exact(3) prefix(1) word-prefix(2) substring(0) fuzzy(4)
        assert_eq!(rank("foo", items, 10), vec![3, 1, 2, 0, 4]);
    }

    #[test]
    fn non_matches_are_dropped_and_case_is_ignored() {
        assert_eq!(rank("INV", "Invoice\nreceipt\ninvite", 10), vec![2, 0], "shorter prefix match ranks first");
        assert!(rank("zzz", "a\nb", 10).is_empty());
    }

    #[test]
    fn empty_query_keeps_order_and_limit_applies() {
        assert_eq!(rank("", "a\nb\nc", 2), vec![0, 1]);
        assert_eq!(rank("a", "a1\na2\na3", 1).len(), 1);
    }

    #[test]
    fn handles_unicode_and_scale() {
        assert_eq!(rank("اردو", "hello\nاردو زبان", 5), vec![1]);
        let big: String = (0..100_000).map(|i| format!("thread {i} subject")).collect::<Vec<_>>().join("\n");
        let r = rank("thread 99999", &big, 3);
        assert_eq!(r[0], 99_999);
    }
}
