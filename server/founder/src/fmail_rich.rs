//! QC2 (founder mailbox, 20 Nov 2026): the PURE side of RICH TEXT mail: the second wall that cleans the HTML the editor produced, the plain-text twin of it, the multipart/alternative body,
//! the variables of snippets and signatures. INHERITABLE BY AWAM (docs/claude/AWAM-INHERITS-FOUNDER-TECH-LAW-13NOV.md): no network, no database, no founder names.
//! Technology: Rust. HTML is cleaned by the audited `ammonia` crate (pure Rust on html5ever, NO C code, strict allow-list); a hand-written sanitiser is a known security anti-pattern, so none exists here.
//! Why a second wall: the browser editor (Tiptap / ProseMirror, restricted schema) is wall 1, but pasted HTML is untrusted input (ProseMirror GHSA-c8x8-7fp4-3x9w, prosemirror-view < 1.42.3), and the
//! server never trusts what a browser says it produced. Research (20 Nov 2026): Superhuman snippets (named, variables, unfilled placeholders are warned about), Exclaimer signature handbook (no logo images in
//! the first version), Gmail (plain text mode is per message, one way).
use ammonia::Builder;
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use std::collections::HashSet;

pub const MAX_HTML: usize = 2 * 1024 * 1024;
pub const MAX_SIGNATURE: usize = 2000;
pub const MAX_SNIPPET: usize = 8000;
pub const MAX_NAME: usize = 40;

/// The closed set of tags a mail written here can carry. Everything else is removed (script and style together with their content).
const TAGS: &[&str] = &["p", "br", "strong", "b", "em", "i", "u", "a", "ul", "ol", "li", "blockquote", "code", "pre", "div", "span"];

/// Clean the HTML of the editor: allow-listed tags only, `href` only on `a` with https or mailto, links get rel="noopener noreferrer nofollow", no style / class / id / data / event attributes,
/// comments removed, script and style removed WITH their content. Idempotent: cleaning clean HTML changes nothing.
pub fn sanitize_html(html: &str) -> Result<String, &'static str> {
    if html.len() > MAX_HTML { return Err("the message is too long"); }
    if html.contains('\0') { return Err("the message has a NUL character"); }
    let tags: HashSet<&str> = TAGS.iter().copied().collect();
    let schemes: HashSet<&str> = ["https", "mailto"].into_iter().collect();
    let mut b = Builder::default();
    b.tags(tags).clean_content_tags(["script", "style"].into_iter().collect()).url_schemes(schemes).strip_comments(true)
        .link_rel(Some("noopener noreferrer nofollow")).generic_attributes(HashSet::new()).tag_attributes(std::collections::HashMap::new()).url_relative(ammonia::UrlRelative::Deny);
    b.add_tag_attributes("a", ["href"]);
    Ok(b.clean(html).to_string())
}

fn unescape(s: &str) -> String { s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&nbsp;", " ").replace("&amp;", "&") }

/// The plain-text twin of CLEAN html (call sanitize_html first): paragraphs and blocks become blank-line separated text, <br> a new line, list items "- " / "1. ", a link "text (https://...)",
/// quotes "> ", entities decoded. Never leaves a tag in the text.
pub fn html_to_text(clean: &str) -> String {
    let mut out = String::with_capacity(clean.len());
    let (mut href_stack, mut ol_n, mut in_ol, mut quote): (Vec<String>, Vec<usize>, Vec<bool>, usize) = (vec![], vec![], vec![], 0);
    let b = clean.as_bytes(); let mut i = 0;
    while i < b.len() {
        if b[i] == b'<' {
            let Some(end) = clean[i..].find('>') else { break };
            let tag = &clean[i + 1..i + end]; i += end + 1;
            let closing = tag.starts_with('/'); let tag = tag.trim_start_matches('/');
            let name = tag.split(|c: char| c.is_whitespace() || c == '/').next().unwrap_or("").to_ascii_lowercase();
            let nl = |o: &mut String, n: usize| { while o.ends_with(' ') { o.pop(); } let have = o.chars().rev().take_while(|c| *c == '\n').count(); for _ in have..n { o.push('\n'); } };
            match (name.as_str(), closing) {
                ("br", _) => out.push('\n'),
                ("p" | "div" | "pre", false) | ("blockquote", false) => { if !out.is_empty() { nl(&mut out, 2); } if name == "blockquote" { quote += 1; } if quote > 0 { out.push_str(&"> ".repeat(quote)); } }
                ("p" | "div" | "pre", true) => nl(&mut out, 2),
                ("blockquote", true) => { quote = quote.saturating_sub(1); nl(&mut out, 2); }
                ("ul", false) => { in_ol.push(false); ol_n.push(0); if !out.is_empty() { nl(&mut out, 1); } }
                ("ol", false) => { in_ol.push(true); ol_n.push(0); if !out.is_empty() { nl(&mut out, 1); } }
                ("ul" | "ol", true) => { in_ol.pop(); ol_n.pop(); nl(&mut out, 2); }
                ("li", false) => { nl(&mut out, 1); if quote > 0 { out.push_str(&"> ".repeat(quote)); } if in_ol.last().copied().unwrap_or(false) { if let Some(n) = ol_n.last_mut() { *n += 1; out.push_str(&format!("{}. ", n)); } } else { out.push_str("- "); } }
                ("li", true) => nl(&mut out, 1),
                ("a", false) => { let h = tag.split("href=\"").nth(1).and_then(|r| r.split('"').next()).map(unescape).unwrap_or_default(); href_stack.push(h); }
                ("a", true) => { if let Some(h) = href_stack.pop() { if !h.is_empty() && !out.trim_end().ends_with(&h) { out.push_str(&format!(" ({h})")); } } }
                _ => {}
            }
        } else {
            let next = clean[i..].find('<').map(|n| i + n).unwrap_or(b.len());
            let t = unescape(&clean[i..next]); out.push_str(&t); i = next;
        }
    }
    let mut lines: Vec<String> = out.replace("\r\n", "\n").split('\n').map(|l| l.trim_end().to_string()).collect();
    while lines.first().map_or(false, |l| l.is_empty()) { lines.remove(0); }
    while lines.last().map_or(false, |l| l.is_empty()) { lines.pop(); }
    let mut res = String::new(); let mut blank = 0;
    for l in lines { if l.is_empty() { blank += 1; if blank <= 1 { res.push('\n'); } } else { blank = 0; res.push_str(&l); res.push('\n'); } }
    res.trim_end().to_string()
}

fn b64_lines(data: &[u8]) -> String {
    let enc = B64.encode(data); let mut s = String::with_capacity(enc.len() + enc.len() / 76 * 2 + 2);
    for c in enc.as_bytes().chunks(76) { s.push_str(std::str::from_utf8(c).unwrap_or("")); s.push_str("\r\n"); }
    s
}

/// A boundary that cannot appear in the parts (base64 text has no "="-free random run of this shape): derived from a counter-free random seed supplied by the caller (a Message-ID is unique per mail).
pub fn boundary_for(message_id: &str) -> String {
    let h: String = message_id.bytes().filter(|b| b.is_ascii_alphanumeric()).map(|b| b as char).take(24).collect();
    format!("=_anx_{h}_alt")
}

/// The MIME body + its Content-Type value for a rich mail (RFC 2046 section 5.1.4): multipart/alternative, text/plain FIRST, text/html LAST (the last part is the preferred one). Both parts are
/// UTF-8 + base64, so no line can be a lone "." or hold a bare CR (same rule as fmail_mime). DKIM signs the whole body, both parts, with no change.
pub fn alternative(text: &str, clean_html: &str, boundary: &str) -> (String, Vec<u8>) {
    let norm = |s: &str| s.replace("\r\n", "\n").replace('\r', "\n").replace('\n', "\r\n");
    let mut b = String::new();
    b.push_str(&format!("--{boundary}\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"));
    b.push_str(&b64_lines(norm(text).as_bytes()));
    b.push_str(&format!("--{boundary}\r\nContent-Type: text/html; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"));
    let doc = format!("<!doctype html><html><head><meta charset=\"utf-8\"></head><body>{clean_html}</body></html>");
    b.push_str(&b64_lines(norm(&doc).as_bytes()));
    b.push_str(&format!("--{boundary}--\r\n"));
    (format!("multipart/alternative; boundary=\"{boundary}\""), b.into_bytes())
}

// ---------------------------------------------------------------- variables of snippets and signatures

/// A snippet / signature name: lower-case ASCII letters, digits, "-" and "_", 1 to 40 characters. None when it is not one.
pub fn clean_name(n: &str) -> Option<String> {
    let s = n.trim().trim_start_matches('/').to_ascii_lowercase();
    if s.is_empty() || s.len() > MAX_NAME || !s.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-' || b == b'_') { return None; }
    Some(s)
}

/// Text of a signature or snippet: no NUL / control characters except newline and tab, no bidi override characters, CRLF folded to LF, trailing spaces cut, at most `max` characters.
pub fn clean_text(t: &str, max: usize) -> Result<String, &'static str> {
    if t.chars().any(|c| (c.is_control() && !matches!(c, '\n' | '\t' | '\r')) || matches!(c, '\u{202a}'..='\u{202e}' | '\u{2066}'..='\u{2069}' | '\u{200b}'..='\u{200f}')) { return Err("the text has a control or direction character"); }
    let s: String = t.replace("\r\n", "\n").replace('\r', "\n").lines().map(|l| l.trim_end()).collect::<Vec<_>>().join("\n");
    let s = s.trim_matches('\n').to_string();
    if s.chars().count() > max { return Err("the text is too long"); }
    Ok(s)
}

/// The placeholders {name} in a text (name = lower-case letters, digits, "_" up to 40), in order of first use, without repeats.
pub fn placeholders(t: &str) -> Vec<String> {
    let (mut out, b) = (Vec::<String>::new(), t.as_bytes()); let mut i = 0;
    while i < b.len() {
        if b[i] == b'{' {
            if let Some(e) = t[i + 1..].find('}') {
                let n = &t[i + 1..i + 1 + e];
                if !n.is_empty() && n.len() <= MAX_NAME && n.bytes().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'_') && !out.iter().any(|x| x == n) { out.push(n.to_string()); }
                i += e + 2; continue;
            }
        }
        i += 1;
    }
    out
}

/// Fill the known variables. Returns (text, the placeholders that stayed unfilled): the screen warns before sending when the list is not empty. A value can never bring a new placeholder in
/// (values are inserted after scanning, once), and a value with a control character is refused by the caller through clean_text.
pub fn fill(t: &str, vars: &[(&str, &str)]) -> (String, Vec<String>) {
    let mut out = String::with_capacity(t.len()); let mut open: Vec<String> = Vec::new(); let b = t.as_bytes(); let mut i = 0;
    while i < b.len() {
        if b[i] == b'{' {
            if let Some(e) = t[i + 1..].find('}') {
                let n = &t[i + 1..i + 1 + e];
                if !n.is_empty() && n.len() <= MAX_NAME && n.bytes().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'_') {
                    if let Some((_, v)) = vars.iter().find(|(k, v)| *k == n && !v.is_empty()) { out.push_str(v); } else { out.push('{'); out.push_str(n); out.push('}'); if !open.iter().any(|x| x == n) { open.push(n.to_string()); } }
                    i += e + 2; continue;
                }
            }
        }
        let ch = t[i..].chars().next().unwrap_or(' '); out.push(ch); i += ch.len_utf8();
    }
    (out, open)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn script_style_and_events_die_with_their_content() {
        let c = sanitize_html("<p onclick=\"x()\" style=\"color:red\" class=\"a\">Hi <script>alert(1)</script><style>p{}</style><b>there</b></p>").unwrap();
        assert_eq!(c, "<p>Hi <b>there</b></p>");
    }
    #[test] fn only_https_and_mailto_links_survive_and_get_rel() {
        let c = sanitize_html("<a href=\"https://a.com/x\">ok</a> <a href=\"javascript:alert(1)\">bad</a> <a href=\"mailto:a@b.co\">m</a> <a href=\"data:text/html,x\">d</a> <a href=\"http://plain.com\">h</a> <a href=\"/rel\">r</a>").unwrap();
        assert!(c.contains("href=\"https://a.com/x\"") && c.contains("rel=\"noopener noreferrer nofollow\""), "{c}");
        assert!(!c.contains("javascript") && !c.contains("data:") && !c.contains("http://plain") && !c.contains("\"/rel\""), "{c}");
        assert!(c.contains("mailto:a@b.co"), "{c}");
    }
    #[test] fn images_iframes_forms_and_remote_content_are_gone() {
        let c = sanitize_html("<img src=\"http://t.example/x.gif\"><iframe src=\"https://e.com\"></iframe><form action=\"x\"><input name=a></form><svg onload=x()></svg><object data=x></object><p>t</p>").unwrap();
        assert_eq!(c, "<p>t</p>");
    }
    #[test] fn paste_from_word_junk_is_cleaned_to_plain_structure() {
        let c = sanitize_html("<p class=MsoNormal style='margin:0cm'><span style='font-family:Calibri'>Hello <o:p></o:p></span></p><!--[if gte mso 9]><xml>x</xml><![endif]-->").unwrap();
        assert!(!c.contains("Mso") && !c.contains("style") && !c.contains("<!--") && !c.contains("o:p") && c.contains("Hello"), "{c}");
    }
    #[test] fn cleaning_is_idempotent() {
        let once = sanitize_html("<p>a <strong>b</strong> <a href=\"https://x.com\">l</a></p><ul><li>1</li></ul>").unwrap();
        assert_eq!(sanitize_html(&once).unwrap(), once);
    }
    #[test] fn size_and_nul_are_refused() {
        assert!(sanitize_html(&"a".repeat(MAX_HTML + 1)).is_err()); assert!(sanitize_html("a\0b").is_err());
    }
    #[test] fn text_twin_of_blocks_lists_links_and_quotes() {
        let h = sanitize_html("<p>Hello <b>Ali</b>,</p><p>See <a href=\"https://x.com/a\">the page</a>.</p><ul><li>one</li><li>two</li></ul><ol><li>a</li><li>b</li></ol><blockquote>quoted</blockquote><p>Line<br>two &amp; more</p>").unwrap();
        let t = html_to_text(&h);
        assert_eq!(t, "Hello Ali,\n\nSee the page (https://x.com/a).\n\n- one\n- two\n\n1. a\n2. b\n\n> quoted\n\nLine\ntwo & more");
    }
    #[test] fn text_twin_has_no_tag_and_no_double_link() {
        let t = html_to_text(&sanitize_html("<p><a href=\"https://x.com\">https://x.com</a></p>").unwrap());
        assert_eq!(t, "https://x.com"); assert!(!t.contains('<'));
    }
    #[test] fn alternative_is_text_first_html_last_and_base64() {
        let (ct, body) = alternative("hi\nthere", "<p>hi</p>", "=_anx_abc_alt");
        assert_eq!(ct, "multipart/alternative; boundary=\"=_anx_abc_alt\"");
        let s = String::from_utf8(body).unwrap();
        let (p, h) = (s.find("text/plain").unwrap(), s.find("text/html").unwrap());
        assert!(p < h && s.ends_with("--=_anx_abc_alt--\r\n"));
        assert!(!s.contains("<p>hi</p>"), "html must be base64, not plain");
        assert!(s.lines().all(|l| l.len() <= 78));
    }
    #[test] fn boundary_is_stable_and_safe() {
        assert_eq!(boundary_for("abc.123@x.com"), boundary_for("abc.123@x.com")); assert!(boundary_for("a\r\nb").bytes().all(|b| b.is_ascii_graphic()));
    }
    #[test] fn names_are_lowercase_ascii_slugs() {
        assert_eq!(clean_name(" /Thanks-2 ").as_deref(), Some("thanks-2"));
        for bad in ["", "a b", "x\r\ny", "ünï", &"a".repeat(41), "a/b", "a{b}"] { assert!(clean_name(bad).is_none(), "{bad}"); }
    }
    #[test] fn text_is_cleaned_and_bidi_and_control_are_refused() {
        assert_eq!(clean_text("a  \r\nb\t\n\n", 100).unwrap(), "a\nb");
        assert!(clean_text("a\u{202e}b", 100).is_err()); assert!(clean_text("a\u{0}b", 100).is_err()); assert!(clean_text("a\u{7}b", 100).is_err());
        assert!(clean_text(&"x".repeat(101), 100).is_err());
    }
    #[test] fn placeholders_are_found_once_in_order() {
        assert_eq!(placeholders("Hi {first_name}, {date} {first_name} {Bad} {} {a-b}"), vec!["first_name", "date"]);
    }
    #[test] fn fill_known_variables_and_report_the_open_ones() {
        let (t, open) = fill("Dear {first_name}, on {date} {deal} {deal}", &[("first_name", "Ali"), ("date", "20 Nov 2026")]);
        assert_eq!(t, "Dear Ali, on 20 Nov 2026 {deal} {deal}"); assert_eq!(open, vec!["deal"]);
    }
    #[test] fn a_value_cannot_bring_a_new_placeholder_in() {
        let (t, open) = fill("{a} x", &[("a", "{b}")]); assert_eq!(t, "{b} x"); assert!(open.is_empty());
    }
    #[test] fn an_empty_value_counts_as_unfilled_and_unicode_survives() {
        let (t, open) = fill("Grüße {first_name} ✓", &[("first_name", "")]); assert_eq!(t, "Grüße {first_name} ✓"); assert_eq!(open, vec!["first_name"]);
    }
}
