//! DK-a (20 Nov 2026, Rule 52, ONE kernel): module `mailparse@1`. The browser kernel reads a mail the SAME way the server does: summary (subject, from, to, cc, date, Message-ID, References max 40, Reply-To, snippet, attachment count)
//! and the safe view (plain text only, HTML stripped, remote content never loaded, attachment list). The functions below are the SAME code as `server/founder/src/fmail_core.rs` (summarize / render / strip_html / clean);
//! the golden vectors in tests/mail_golden.json are made by the SERVER's real functions and must equal this module's output byte for byte (tests/mail_golden.rs). No network, no DOM, no randomness.
use crate::htmltext::html_to_text;
use mail_parser::{Address, Message, MessageParser, MimeHeaders, PartType};
use serde_json::{json, Value};

pub const MAX_TEXT: usize = 200_000;

#[derive(Debug, Clone, Default, PartialEq)]
pub struct Summary {
    pub subject: String, pub from_addr: String, pub from_name: String, pub to: Vec<String>, pub cc: Vec<String>,
    pub date: String, pub message_id: String, pub in_reply_to: String, pub snippet: String, pub attach: usize,
    /// QC4: the References header of THIS mail (ids without angle brackets, at most 40, in header order). A reply builds its own References from this plus this mail's Message-ID (RFC 5322 3.6.4).
    pub references: Vec<String>,
    /// QC4: the Reply-To header (addresses only): Reply and Reply all go here when it is set (mailing lists, support desks).
    pub reply_to: Vec<String>,
}

/// Control characters out, runs of white space folded to one space, cut to `max` characters (never in the middle of a character).
pub fn clean(s: &str, max: usize) -> String {
    let mut out = String::with_capacity(s.len().min(max * 4));
    let mut last_space = true;
    for c in s.chars() {
        let c = if c.is_control() || c == '\u{2028}' || c == '\u{2029}' || c == '\u{202e}' || c == '\u{200f}' { ' ' } else { c };   // bidi override / RLM tricks are dropped too
        if c.is_whitespace() { if !last_space { out.push(' '); last_space = true; } } else { out.push(c); last_space = false; }
        if out.chars().count() >= max { break; }
    }
    out.trim().to_string()
}

fn addrs(a: Option<&Address>) -> Vec<String> { a.map(|x| x.iter().filter_map(|a| a.address()).map(|s| clean(s, 254)).filter(|s| !s.is_empty()).take(50).collect()).unwrap_or_default() }

/// Remove tags, scripts and styles, decode the few entities that matter. Output is PLAIN TEXT: the UI never receives HTML from a sender.
pub fn strip_html(h: &str) -> String {
    let mut out = String::with_capacity(h.len() / 2);
    let lower = h.to_ascii_lowercase();
    let bytes = h.as_bytes();
    let (mut i, n) = (0usize, h.len());
    while i < n {
        if bytes[i] == b'<' && bytes.get(i + 1).map_or(false, |c| c.is_ascii_alphabetic() || *c == b'/' || *c == b'!') {
            let rest = &lower[i..];
            let skip_to = |tag: &str| -> Option<usize> { rest.find(&format!("</{tag}")).map(|p| i + p) };
            if rest.starts_with("<script") { i = skip_to("script").and_then(|p| lower[p..].find('>').map(|q| p + q + 1)).unwrap_or(n); continue; }
            if rest.starts_with("<style") { i = skip_to("style").and_then(|p| lower[p..].find('>').map(|q| p + q + 1)).unwrap_or(n); continue; }
            if rest.starts_with("<!--") { i = rest.find("-->").map(|p| i + p + 3).unwrap_or(n); continue; }
            let is_break = rest.starts_with("<br") || rest.starts_with("<p") || rest.starts_with("</p") || rest.starts_with("<div") || rest.starts_with("</div") || rest.starts_with("<li") || rest.starts_with("<tr") || rest.starts_with("<h");
            i = rest.find('>').map(|p| i + p + 1).unwrap_or(n);
            if is_break { out.push('\n'); }
            continue;
        }
        let ch_len = h[i..].chars().next().map(|c| c.len_utf8()).unwrap_or(1);
        out.push_str(&h[i..i + ch_len]); i += ch_len;
    }
    let out = out.replace("&nbsp;", " ").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&amp;", "&");
    // collapse 3+ newlines, trim lines
    let mut res = String::new(); let mut nl = 0;
    for line in out.lines() { let t = line.trim_end(); if t.trim().is_empty() { nl += 1; if nl <= 1 { res.push('\n'); } } else { nl = 0; res.push_str(t.trim_start()); res.push('\n'); } }
    res.trim().to_string()
}

/// First text body of the message. A real text/plain part is taken as it is; an HTML-only message is converted by OUR html_to_text (htmltext.rs), because mail-parser's own entity table is wrong on wasm32.
fn text_of(m: &Message) -> Option<String> {
    let id = *m.text_body.first()?;
    match &m.parts.get(id as usize)?.body {
        PartType::Html(h) => Some(html_to_text(h)),
        _ => m.body_text(0).map(|t| t.into_owned()),
    }
}

/// Everything the list and the sealed meta need. Never panics and never fails: an unreadable message still gets a summary ("(unreadable message)").
pub fn summarize(raw: &[u8]) -> Summary {
    let Some(m) = MessageParser::default().parse(raw) else { return Summary { subject: "(unreadable message)".into(), ..Default::default() } };
    let from = m.from().and_then(|a| a.first());
    let text = text_of(&m).or_else(|| m.body_html(0).map(|h| strip_html(&h))).unwrap_or_default();
    let in_reply = m.in_reply_to().as_text().map(str::to_string).or_else(|| m.in_reply_to().as_text_list().and_then(|l| l.first().map(|s| s.to_string()))).unwrap_or_default();
    let refs: Vec<String> = { let h = m.references(); h.as_text_list().map(|l| l.iter().map(|x| clean(x, 300)).filter(|x| !x.is_empty()).take(40).collect()).or_else(|| h.as_text().map(|x| vec![clean(x, 300)]).filter(|v| !v[0].is_empty())).unwrap_or_default() };
    Summary {
        subject: clean(m.subject().unwrap_or(""), 300),
        from_addr: from.and_then(|a| a.address()).map(|s| clean(s, 254)).unwrap_or_default(),
        from_name: from.and_then(|a| a.name()).map(|s| clean(s, 120)).unwrap_or_default(),
        to: addrs(m.to()), cc: addrs(m.cc()),
        date: m.date().map(|d| d.to_rfc3339()).unwrap_or_default(),
        message_id: clean(m.message_id().unwrap_or(""), 300), in_reply_to: clean(&in_reply, 300),
        snippet: clean(&text, 160), attach: m.attachment_count().min(100), references: refs, reply_to: addrs(m.reply_to()),
    }
}

pub fn summary_json(s: &Summary) -> Value {
    json!({"subject": s.subject, "from": s.from_addr, "from_name": s.from_name, "to": s.to, "cc": s.cc, "date": s.date, "message_id": s.message_id, "references": s.references, "reply_to": s.reply_to, "snippet": s.snippet, "attach": s.attach})
}

/// Safe view of a whole message for the reader: plain text only (HTML becomes stripped text), the attachment list (name, type, size), a flag that remote content was removed.
pub fn render(raw: &[u8]) -> Value {
    let Some(m) = MessageParser::default().parse(raw) else { return json!({"text": "(this message could not be read)", "had_html": false, "attachments": []}) };
    let had_html = m.body_html(0).is_some();
    let text = match text_of(&m) { Some(t) => t, None => m.body_html(0).map(|h| strip_html(&h)).unwrap_or_default() };
    let mut text = text.replace('\r', "").trim().to_string();
    if text.chars().count() > MAX_TEXT { text = text.chars().take(MAX_TEXT).collect::<String>() + "\n[message cut here]"; }
    let atts: Vec<Value> = m.attachments().take(100).map(|p| json!({
        "name": clean(p.attachment_name().unwrap_or("attachment"), 200),
        "type": p.content_type().map(|c| format!("{}/{}", c.ctype(), c.subtype().unwrap_or("octet-stream"))).unwrap_or_else(|| "application/octet-stream".into()),
        "size": p.contents().len()})).collect();
    json!({"text": text, "had_html": had_html, "remote_content_blocked": had_html, "attachments": atts})
}


/// JSON out for the browser: {"summary": {...}, "view": {...}} for one raw RFC 822 message (the plain bytes a `kemopen@1` open gives back).
pub fn parse_json(raw: &[u8]) -> String {
    json!({"summary": summary_json(&summarize(raw)), "view": render(raw)}).to_string()
}
