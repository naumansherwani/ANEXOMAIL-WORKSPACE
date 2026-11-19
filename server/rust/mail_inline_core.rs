// ============================================================================
// mail_inline_core.rs — PURE half of QC1e D4B (AWAM ONLY, 20 Nov 2026): company emoji as REAL inline images in outgoing mail.
// std only. No I/O, no crate. Tested with `rustc --test` by the installer, like every *_core.rs.
//
// What it does (one job): take the HTML that mail.send already has, swap ":code:" text tokens (text nodes only, never inside a tag
// or an attribute) for <img src="cid:..."> for the emoji the sender's company really owns, and splice the matching
// multipart/related part into the message mail_core::build_message already built.
//
// Standards followed (researched, see docs/claude/QC1E-D4-PLAN-20NOV.md):
//   RFC 2392  cid: URL + Content-ID <local@domain>         RFC 2387  multipart/related; type="text/html"
//   RFC 2046  nesting: mixed > alternative > [ text/plain , related > [ text/html , image/png ... ] ]
//   RFC 2183  Content-Disposition: inline                  RFC 2045  base64, 76 char lines
// No base64 data: URI (Gmail/Outlook strip it), no remote image URL, no tracking pixel. Image bytes are a derived 48x48 PNG
// (Outlook desktop and every client draw PNG; WebP is never put in outgoing mail). The text/plain part keeps ":code:".
//
// Gates (my defaults, founder decides): distinct emoji per mail 5/5/12/25, inline bytes per mail 120/120/300/600 KB.
// An emoji over a gate is simply left as text: the mail still goes, nothing is lost, nothing fails.
// ============================================================================

pub const INLINE_PX: u32 = 48; // the PNG is 48x48, shown at 24x24 (2x, sharp on retina)
pub const SHOW_PX: u32 = 24;
pub const MAX_PNG_BYTES: usize = 16 * 1024; // one derived 48x48 PNG is a few KB; this is a hard ceiling
pub const CID_DOMAIN: &str = "emoji.anexomail";

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Gates {
    pub max_distinct: usize,
    pub max_bytes: usize,
}

/// Tier gates from the plan name (same family test as emoji_core::tier_limit). Unknown / free plan = no inline images.
pub fn gates(plan: &str) -> Gates {
    let p = plan.to_ascii_lowercase();
    if p.contains("max") {
        Gates { max_distinct: 25, max_bytes: 600 * 1024 }
    } else if p.contains("premium") {
        Gates { max_distinct: 12, max_bytes: 300 * 1024 }
    } else if p.contains("business") {
        Gates { max_distinct: 5, max_bytes: 120 * 1024 }
    } else {
        Gates { max_distinct: 0, max_bytes: 0 }
    }
}

#[derive(Debug, Clone)]
pub struct Img {
    pub code: String, // shortcode without colons
    pub sha: String,  // sha256 hex of the MASTER (identity of the emoji)
    pub png: Vec<u8>, // derived 48x48 PNG
}

/// "<first 16 hex of the master sha>@emoji.anexomail" (no angle brackets).
pub fn cid_of(sha: &str) -> String {
    format!("{}@{}", &sha[..16.min(sha.len())], CID_DOMAIN)
}

/// Cheap structural check of a derived PNG before it may enter a mail: signature, first chunk IHDR, size 48x48 (or any 16..=96 square),
/// size ceiling, ends with IEND, no animation chunks.
pub fn check_png(b: &[u8]) -> Result<(), &'static str> {
    if b.len() < 45 || b.len() > MAX_PNG_BYTES {
        return Err("png size");
    }
    if &b[..8] != b"\x89PNG\r\n\x1a\n" || &b[12..16] != b"IHDR" {
        return Err("png header");
    }
    let w = u32::from_be_bytes([b[16], b[17], b[18], b[19]]);
    let h = u32::from_be_bytes([b[20], b[21], b[22], b[23]]);
    if w != h || !(16..=96).contains(&w) {
        return Err("png dims");
    }
    if &b[b.len() - 8..b.len() - 4] != b"IEND" {
        return Err("png end");
    }
    // walk the chunks: no acTL / fcTL / fdAT (animation), lengths stay inside the buffer
    let mut i = 8usize;
    while i + 8 <= b.len() {
        let len = u32::from_be_bytes([b[i], b[i + 1], b[i + 2], b[i + 3]]) as usize;
        let ty = &b[i + 4..i + 8];
        if ty == b"acTL" || ty == b"fcTL" || ty == b"fdAT" {
            return Err("png animated");
        }
        let next = i.checked_add(12).and_then(|x| x.checked_add(len)).ok_or("png chunk")?;
        if next > b.len() {
            return Err("png chunk");
        }
        i = next;
    }
    Ok(())
}

/// Result of the swap: new html, the images that were really used (in order of first use), codes left as text because of a gate.
#[derive(Debug, Default)]
pub struct Swap {
    pub html: String,
    pub used: Vec<Img>,
    pub over_gate: Vec<String>,
}

fn is_code_byte(c: u8) -> bool {
    c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'_' || c == b'-'
}

/// Swap ":code:" in TEXT NODES ONLY. `pack` = the sender company's ACTIVE emoji (code, sha, derived png). Tags, attributes,
/// <script>/<style>/comments are copied untouched. Same boundary rule as emoji_core::tokens (12:30:45 is a time, never a token).
pub fn swap_html(html: &str, pack: &[Img], g: Gates) -> Swap {
    let b = html.as_bytes();
    let mut out = String::with_capacity(html.len() + 256);
    let mut used: Vec<Img> = Vec::new();
    let mut over: Vec<String> = Vec::new();
    let mut bytes = 0usize;
    let mut i = 0usize;
    let mut raw_until: Option<&'static str> = None; // inside <script> / <style>
    while i < b.len() {
        if let Some(end) = raw_until {
            let rest = &html[i..];
            let low = rest.to_ascii_lowercase();
            match low.find(end) {
                Some(p) => {
                    out.push_str(&rest[..p]);
                    i += p;
                    raw_until = None;
                }
                None => {
                    out.push_str(rest);
                    i = b.len();
                }
            }
            continue;
        }
        if b[i] == b'<' {
            if html[i..].starts_with("<!--") {
                let e = html[i..].find("-->").map(|p| i + p + 3).unwrap_or(b.len());
                out.push_str(&html[i..e]);
                i = e;
                continue;
            }
            // copy the whole tag, honouring quotes (a '>' inside an attribute value does not end it)
            let mut j = i + 1;
            let mut q: u8 = 0;
            while j < b.len() {
                let c = b[j];
                if q != 0 {
                    if c == q {
                        q = 0;
                    }
                } else if c == b'"' || c == b'\'' {
                    q = c;
                } else if c == b'>' {
                    j += 1;
                    break;
                }
                j += 1;
            }
            let tag = &html[i..j.min(b.len())];
            let tl = tag.to_ascii_lowercase();
            if tl.starts_with("<script") {
                raw_until = Some("</script");
            } else if tl.starts_with("<style") {
                raw_until = Some("</style");
            }
            out.push_str(tag);
            i = j.min(b.len());
            continue;
        }
        // text node: look for a token starting here
        if b[i] == b':' && (i == 0 || !b[i - 1].is_ascii_alphanumeric()) {
            let mut j = i + 1;
            while j < b.len() && j - i - 1 <= 24 && is_code_byte(b[j]) {
                j += 1;
            }
            if j < b.len() && b[j] == b':' {
                let code = &html[i + 1..j];
                if code.bytes().any(|c| c.is_ascii_lowercase()) {
                    if let Some(img) = pack.iter().find(|p| p.code == code) {
                        let already = used.iter().any(|u| u.sha == img.sha);
                        let fits = already
                            || (used.len() < g.max_distinct && bytes + img.png.len() <= g.max_bytes && check_png(&img.png).is_ok());
                        if fits {
                            if !already {
                                bytes += img.png.len();
                                used.push(img.clone());
                            }
                            out.push_str(&format!(
                                "<img src=\"cid:{}\" alt=\":{}:\" width=\"{px}\" height=\"{px}\" style=\"width:{px}px;height:{px}px;vertical-align:middle;border:0\">",
                                cid_of(&img.sha),
                                code,
                                px = SHOW_PX
                            ));
                            i = j + 1;
                            continue;
                        } else if !over.iter().any(|c| c == code) {
                            over.push(code.to_string());
                        }
                    }
                }
                // not swapped: copy the token text, the closing colon may open the next token
                out.push_str(&html[i..j]);
                i = j;
                continue;
            }
        }
        // copy one char (UTF-8 safe)
        let ch = html[i..].chars().next().unwrap();
        out.push(ch);
        i += ch.len_utf8();
    }
    Swap { html: out, used, over_gate: over }
}

fn b64(data: &[u8]) -> String {
    const T: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut s = String::with_capacity(data.len() * 4 / 3 + 4);
    for c in data.chunks(3) {
        let n = (c[0] as u32) << 16 | (*c.get(1).unwrap_or(&0) as u32) << 8 | *c.get(2).unwrap_or(&0) as u32;
        s.push(T[(n >> 18) as usize & 63] as char);
        s.push(T[(n >> 12) as usize & 63] as char);
        s.push(if c.len() > 1 { T[(n >> 6) as usize & 63] as char } else { '=' });
        s.push(if c.len() > 2 { T[n as usize & 63] as char } else { '=' });
    }
    s
}

fn b64_lines(data: &[u8]) -> String {
    let e = b64(data);
    e.as_bytes().chunks(76).map(|l| std::str::from_utf8(l).unwrap()).collect::<Vec<_>>().join("\r\n")
}

/// The multipart/related part that REPLACES the plain text/html part: header block + body (no leading boundary).
pub fn related_part(html: &str, used: &[Img], rb: &str) -> String {
    let mut s = format!("Content-Type: multipart/related; type=\"text/html\"; boundary=\"{rb}\"\r\n\r\n");
    s.push_str(&format!(
        "--{rb}\r\nContent-Type: text/html; charset=\"UTF-8\"\r\nContent-Transfer-Encoding: 8bit\r\n\r\n{html}\r\n"
    ));
    for im in used {
        let c = cid_of(&im.sha);
        let nm = format!("{}.png", &im.sha[..16.min(im.sha.len())]);
        s.push_str(&format!(
            "--{rb}\r\nContent-Type: image/png; name=\"{nm}\"\r\nContent-Transfer-Encoding: base64\r\nContent-ID: <{c}>\r\nContent-Disposition: inline; filename=\"{nm}\"\r\n\r\n{}\r\n",
            b64_lines(&im.png)
        ));
    }
    s.push_str(&format!("--{rb}--"));
    s
}

const HTML_HEAD: &str = "Content-Type: text/html; charset=\"UTF-8\"\r\nContent-Transfer-Encoding: 8bit\r\n\r\n";

/// Replace the text/html part of a message built by mail_core::build_message (multipart/alternative) with the related part.
/// Fails (and the caller sends the ORIGINAL message) if the shape is not exactly what we expect.
pub fn splice(base: &str, original_html: &str, related: &str) -> Result<String, &'static str> {
    let needle = format!("{HTML_HEAD}{original_html}\r\n--");
    let at = base.find(&needle).ok_or("html part not found")?;
    if base[at + 1..].contains(&needle) {
        return Err("html part not unique");
    }
    let before = &base[..at];
    let after = &base[at + needle.len() - 2..]; // keep "\r\n--" -> we re-add CRLF + "--"
    // after now starts with "--boundary--..." ; related ends without CRLF
    Ok(format!("{before}{related}\r\n{after}"))
}

// ---------------------------------------------------------------- ClamAV (clamd INSTREAM, std only)

/// Scan bytes with clamd over TCP ("host:port") using the INSTREAM protocol. Ok(()) only on "stream: OK".
/// Anything else (found, error, timeout, bad answer) is an Err: FAIL CLOSED.
pub fn clamd_instream(addr: &str, data: &[u8]) -> Result<(), String> {
    use std::io::{Read, Write};
    use std::net::{TcpStream, ToSocketAddrs};
    use std::time::Duration;
    let sa = addr.to_socket_addrs().map_err(|e| format!("clamd addr: {e}"))?.next().ok_or("clamd addr empty")?;
    let mut s = TcpStream::connect_timeout(&sa, Duration::from_secs(3)).map_err(|e| format!("clamd connect: {e}"))?;
    s.set_read_timeout(Some(Duration::from_secs(10))).ok();
    s.set_write_timeout(Some(Duration::from_secs(10))).ok();
    s.write_all(b"zINSTREAM\0").map_err(|e| format!("clamd write: {e}"))?;
    for ch in data.chunks(8192) {
        s.write_all(&(ch.len() as u32).to_be_bytes()).map_err(|e| format!("clamd write: {e}"))?;
        s.write_all(ch).map_err(|e| format!("clamd write: {e}"))?;
    }
    s.write_all(&0u32.to_be_bytes()).map_err(|e| format!("clamd write: {e}"))?;
    let mut resp = Vec::new();
    s.take(512).read_to_end(&mut resp).map_err(|e| format!("clamd read: {e}"))?;
    let t = String::from_utf8_lossy(&resp);
    let t = t.trim_matches(|c: char| c == '\0' || c.is_whitespace());
    if t == "stream: OK" {
        Ok(())
    } else {
        Err(format!("clamd: {}", t.chars().take(120).collect::<String>()))
    }
}

/* ------------------------------------------------------------------- tests */

#[cfg(test)]
mod tests {
    use super::*;

    fn fake_png(side: u32) -> Vec<u8> {
        // structurally valid PNG (signature, IHDR, IDAT with junk, IEND) — check_png is structural only
        let mut v = b"\x89PNG\r\n\x1a\n".to_vec();
        v.extend_from_slice(&13u32.to_be_bytes());
        v.extend_from_slice(b"IHDR");
        v.extend_from_slice(&side.to_be_bytes());
        v.extend_from_slice(&side.to_be_bytes());
        v.extend_from_slice(&[8, 6, 0, 0, 0]);
        v.extend_from_slice(&[0, 0, 0, 0]); // crc (not checked)
        v.extend_from_slice(&4u32.to_be_bytes());
        v.extend_from_slice(b"IDAT");
        v.extend_from_slice(&[1, 2, 3, 4]);
        v.extend_from_slice(&[0, 0, 0, 0]);
        v.extend_from_slice(&0u32.to_be_bytes());
        v.extend_from_slice(b"IEND");
        v.extend_from_slice(&[0xAE, 0x42, 0x60, 0x82]);
        v
    }
    fn img(code: &str, n: u8) -> Img {
        let sha: String = std::iter::repeat(format!("{:02x}", n)).take(32).collect();
        Img { code: code.into(), sha, png: fake_png(48) }
    }
    fn g5() -> Gates {
        gates("Business")
    }

    #[test]
    fn gates_by_plan() {
        assert_eq!(gates("Business Max").max_distinct, 25);
        assert_eq!(gates("premium").max_distinct, 12);
        assert_eq!(gates("business_pro").max_distinct, 5);
        assert_eq!(gates("free").max_distinct, 0);
    }

    #[test]
    fn png_check() {
        assert!(check_png(&fake_png(48)).is_ok());
        assert!(check_png(&fake_png(300)).is_err());
        let mut p = fake_png(48);
        p[0] = 0;
        assert!(check_png(&p).is_err());
        let mut a = fake_png(48);
        let at = a.len() - 12;
        a.splice(at..at, b"\0\0\0\0acTL\0\0\0\0".iter().copied());
        assert!(check_png(&a).is_err());
        assert!(check_png(&[]).is_err());
    }

    #[test]
    fn swaps_text_nodes_only() {
        let pack = vec![img("acme", 1)];
        let h = "<p title=\":acme:\">hi :acme: and <a href=\"x:acme:y\">:acme:</a></p><script>var a=':acme:';</script><style>.a{content:':acme:'}</style><!-- :acme: -->";
        let s = swap_html(h, &pack, g5());
        assert_eq!(s.used.len(), 1);
        assert_eq!(s.html.matches("cid:").count(), 2, "{}", s.html); // text + inside <a>, nothing else
        assert!(s.html.contains("title=\":acme:\""));
        assert!(s.html.contains("var a=':acme:';"));
        assert!(s.html.contains("<!-- :acme: -->"));
        assert!(s.html.contains("width=\"24\" height=\"24\""));
    }

    #[test]
    fn time_is_not_a_token_and_unknown_stays() {
        let pack = vec![img("acme", 1)];
        let s = swap_html("<p>12:30:45 :nope: :acme:</p>", &pack, g5());
        assert!(s.html.contains("12:30:45 :nope: <img"));
        assert_eq!(s.used.len(), 1);
    }

    #[test]
    fn distinct_gate_leaves_extras_as_text() {
        let pack: Vec<Img> = (0..7).map(|n| img(&format!("e{}", n), n as u8 + 1)).collect();
        let h: String = (0..7).map(|n| format!(":e{}: ", n)).collect();
        let s = swap_html(&h, &pack, g5());
        assert_eq!(s.used.len(), 5);
        assert_eq!(s.over_gate, vec!["e5".to_string(), "e6".to_string()]);
        assert!(s.html.contains(":e5:") && s.html.contains(":e6:"));
        // the same emoji repeated is one part, many <img>
        let r = swap_html(":e0: :e0: :e0:", &pack, g5());
        assert_eq!(r.used.len(), 1);
        assert_eq!(r.html.matches("<img").count(), 3);
    }

    #[test]
    fn byte_gate() {
        let mut big = img("big", 9);
        big.png = {
            let mut p = fake_png(48);
            let at = p.len() - 12;
            p.splice(at..at, std::iter::repeat(7u8).take(0)); // keep structurally valid; size via separate gate below
            p
        };
        let tiny = Gates { max_distinct: 5, max_bytes: 10 };
        let s = swap_html(":big:", &[big], tiny);
        assert!(s.used.is_empty());
        assert_eq!(s.over_gate, vec!["big".to_string()]);
    }

    #[test]
    fn free_plan_swaps_nothing() {
        let s = swap_html(":acme:", &[img("acme", 1)], gates("free"));
        assert!(s.used.is_empty());
        assert_eq!(s.html, ":acme:");
    }

    #[test]
    fn utf8_safe() {
        let s = swap_html("<p>گھر :acme: ✓</p>", &[img("acme", 1)], g5());
        assert!(s.html.starts_with("<p>گھر <img") && s.html.ends_with(" ✓</p>"));
    }

    /// Independent MIME walk (written separately from the builder): boundaries, nesting, Content-ID matches every cid:, base64 decodes to the PNG.
    fn unb64(s: &str) -> Vec<u8> {
        let mut out = Vec::new();
        let mut acc = 0u32;
        let mut n = 0;
        for c in s.bytes() {
            let v = match c {
                b'A'..=b'Z' => c - b'A',
                b'a'..=b'z' => c - b'a' + 26,
                b'0'..=b'9' => c - b'0' + 52,
                b'+' => 62,
                b'/' => 63,
                _ => continue,
            } as u32;
            acc = acc << 6 | v;
            n += 1;
            if n == 4 {
                out.extend_from_slice(&[(acc >> 16) as u8, (acc >> 8) as u8, acc as u8]);
                acc = 0;
                n = 0;
            }
        }
        if n == 3 {
            out.extend_from_slice(&[(acc >> 10) as u8, (acc >> 2) as u8]);
        } else if n == 2 {
            out.push((acc >> 4) as u8);
        }
        out
    }

    fn base_alt(html: &str) -> String {
        format!(
            "From: a@b.c\r\nSubject: s\r\nMIME-Version: 1.0\r\nContent-Type: multipart/alternative; boundary=\"alt\"\r\n\r\n--alt\r\nContent-Type: text/plain; charset=\"UTF-8\"\r\nContent-Transfer-Encoding: 8bit\r\n\r\nhi :acme:\r\n--alt\r\n{HTML_HEAD}{html}\r\n--alt--\r\n"
        )
    }

    #[test]
    fn full_message_shape() {
        let pack = vec![img("acme", 1), img("smile", 2)];
        let orig = "<p>hello :acme: :smile: :acme:</p>";
        let sw = swap_html(orig, &pack, g5());
        let rel = related_part(&sw.html, &sw.used, "rb1");
        let msg = splice(&base_alt(orig), orig, &rel).unwrap();
        // structure
        assert!(msg.contains("multipart/related; type=\"text/html\"; boundary=\"rb1\""));
        assert_eq!(msg.matches("--rb1\r\n").count(), 3); // html + 2 images
        assert_eq!(msg.matches("--rb1--").count(), 1);
        assert_eq!(msg.matches("--alt\r\n").count(), 2);
        assert_eq!(msg.matches("--alt--").count(), 1);
        // text part untouched
        assert!(msg.contains("hi :acme:\r\n--alt"));
        // every cid: in the html has exactly one Content-ID part, and its bytes round trip
        for im in &sw.used {
            let c = cid_of(&im.sha);
            assert!(sw.html.contains(&format!("cid:{c}")));
            let tag = format!("Content-ID: <{c}>");
            assert_eq!(msg.matches(&tag).count(), 1);
            let from = msg.find(&tag).unwrap();
            let body_start = from + msg[from..].find("\r\n\r\n").unwrap() + 4;
            let body_end = body_start + msg[body_start..].find("\r\n--rb1").unwrap();
            assert_eq!(unb64(&msg[body_start..body_end]), im.png);
        }
        // nothing but CRLF line ends, base64 lines <= 76
        assert!(!msg.replace("\r\n", "").contains('\n'));
        for l in msg.split("\r\n") {
            assert!(l.len() <= 998, "line too long");
        }
        // alt closes after related closes
        assert!(msg.find("--rb1--").unwrap() < msg.find("--alt--").unwrap());
    }

    #[test]
    fn splice_refuses_odd_shapes() {
        assert!(splice("nothing here", "<p>x</p>", "R").is_err());
        let two = format!("{HTML_HEAD}<p>x</p>\r\n--a{HTML_HEAD}<p>x</p>\r\n--b");
        assert!(splice(&two, "<p>x</p>", "R").is_err());
    }

    #[test]
    fn b64_matches_known() {
        assert_eq!(b64(b""), "");
        assert_eq!(b64(b"f"), "Zg==");
        assert_eq!(b64(b"fo"), "Zm8=");
        assert_eq!(b64(b"foo"), "Zm9v");
        assert_eq!(b64(b"foobar"), "Zm9vYmFy");
    }

    #[test]
    fn clamd_instream_against_fake_server() {
        use std::io::{Read, Write};
        use std::net::TcpListener;
        for (reply, expect_ok) in [(&b"stream: OK\0"[..], true), (&b"stream: Eicar-Test-Signature FOUND\0"[..], false)] {
            let l = TcpListener::bind("127.0.0.1:0").unwrap();
            let addr = l.local_addr().unwrap().to_string();
            let rep = reply.to_vec();
            let h = std::thread::spawn(move || {
                let (mut s, _) = l.accept().unwrap();
                let mut cmd = [0u8; 10];
                s.read_exact(&mut cmd).unwrap();
                assert_eq!(&cmd, b"zINSTREAM\0");
                let mut total = 0usize;
                loop {
                    let mut n = [0u8; 4];
                    s.read_exact(&mut n).unwrap();
                    let n = u32::from_be_bytes(n) as usize;
                    if n == 0 {
                        break;
                    }
                    let mut buf = vec![0u8; n];
                    s.read_exact(&mut buf).unwrap();
                    total += n;
                }
                assert_eq!(total, 20000);
                s.write_all(&rep).unwrap();
            });
            let r = clamd_instream(&addr, &vec![7u8; 20000]);
            h.join().unwrap();
            assert_eq!(r.is_ok(), expect_ok, "{:?}", r);
        }
        // nothing listening = fail closed
        assert!(clamd_instream("127.0.0.1:1", b"x").is_err());
    }
}
