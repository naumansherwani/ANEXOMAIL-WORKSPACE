// ============================================================================
// emoji_pack_core.rs — the pure, testable half of the COMPANY EMOJI PACK (QC1e D4A, AWAM ONLY, 20 Nov 2026).
//
// std-only (no crates) so the same file is unit-tested on the server by the installer BEFORE anything is changed:
//     rustc --edition 2021 --test emoji_pack_core.rs -o emoji_pack_core_test && ./emoji_pack_core_test
// All I/O (Supabase, image decode/encode with the `image-webp` + `png` crates) lives in emoji_pack_glue.rs.
// Everything that DECIDES something lives here, and mirrors the SQL (E193) so the Rust door and the database can never disagree:
//   * shortcode shape + reserved names           (SQL: company_emoji_code_chk, company_emoji_reserved)
//   * the tier table                              (SQL: company_emoji_tier_limit)  Business 10 / Pro 10 / Premium 50 / MAX 200
//   * input limits BEFORE any decoder runs       (OWASP: size limit first, header dimensions before decode, no animation, no SVG)
//   * container sniffing from MAGIC BYTES        (the client's Content-Type / file name is never trusted)
//   * the output check: a clean WebP made by us  (RIFF....WEBP, only VP8 / VP8L / ALPH / VP8X-without-metadata chunks, <= 64 KB)
//   * the size ladder 256 -> 192 -> 128 -> 96 px  (lossless only: if even 96 px does not fit, the answer is "too detailed")
//   * ":code:" token extraction for the picker / mail path (used again by D4B)
// ============================================================================

pub const MAX_UPLOAD_BYTES: usize = 512 * 1024; // what the browser may send (png or webp)
pub const MAX_SRC_SIDE: u32 = 4096; // header-declared width/height before decode
pub const MAX_SRC_PIXELS: u64 = 16_000_000; // 16 MP hard ceiling (decompression-bomb brake)
pub const MAX_OUT_BYTES: usize = 65_536; // same as SQL company_emoji_bytes_chk
pub const MIN_OUT_BYTES: usize = 64;
pub const LADDER: [u32; 4] = [256, 192, 128, 96];
pub const MIN_SIDE: u32 = 16; // SQL company_emoji_dim_chk
pub const MAX_SIDE: u32 = 256;
pub const MAX_ALT: usize = 80;
pub const MAX_UPLOADS_PER_DAY_BUSINESS: i64 = 20;

/* ------------------------------------------------------------------- tiers */

/// SQL company_emoji_tier_limit(plan): the pack size per plan. 0 = the feature is not in this plan.
pub fn tier_limit(plan: &str) -> usize {
    let p = plan.to_lowercase();
    if p.contains("max") {
        200
    } else if p.contains("premium") {
        50
    } else if p == "business" || p == "business_pro" {
        10
    } else {
        0
    }
}

/// Uploads a company may make per UTC day (abuse brake; D4A uses it in the glue, SQL counter arrives with D4B).
pub fn daily_upload_cap(plan: &str) -> i64 {
    match tier_limit(plan) {
        200 => 200,
        50 => 60,
        10 => MAX_UPLOADS_PER_DAY_BUSINESS,
        _ => 0,
    }
}

/* -------------------------------------------------------------- shortcodes */

const RESERVED: [&str; 22] = [
    "official", "admin", "administrator", "support", "system", "security", "billing", "staff", "moderator", "mod", "anexo",
    "anexomail", "anexochat", "anexosuite", "founder", "owner", "root", "null", "undefined", "everyone", "here", "channel",
];

/// Same list as SQL company_emoji_reserved.
pub fn is_reserved(code: &str) -> bool {
    let c = code.to_lowercase();
    RESERVED.contains(&c.as_str())
}

/// Same rule as SQL company_emoji_code_chk: ^[a-z0-9][a-z0-9_-]{0,22}[a-z0-9]$  (2..24 characters).
pub fn valid_code_shape(code: &str) -> bool {
    let b = code.as_bytes();
    if b.len() < 2 || b.len() > 24 {
        return false;
    }
    let alnum = |c: u8| c.is_ascii_lowercase() || c.is_ascii_digit();
    if !alnum(b[0]) || !alnum(b[b.len() - 1]) {
        return false;
    }
    b.iter().all(|&c| alnum(c) || c == b'_' || c == b'-')
}

/// Trim + lower-case, then check shape and reserved list. Err = a short reason a person can read.
pub fn clean_code(raw: &str) -> Result<String, &'static str> {
    let c = raw.trim().to_lowercase();
    let c = c.trim_matches(':').to_string(); // people type ":acme:"
    if !valid_code_shape(&c) {
        return Err("shortcode: 2-24 letters, digits, _ or -, starting and ending with a letter or digit");
    }
    if is_reserved(&c) {
        return Err("shortcode: this name is reserved (official, admin, support ...)");
    }
    Ok(c)
}

/// Alt text: trimmed, no control characters, at most 80 characters.
pub fn clean_alt(raw: &str) -> Result<String, &'static str> {
    let a: String = raw.trim().to_string();
    if a.chars().any(|c| c.is_control()) {
        return Err("alt text: no control characters");
    }
    if a.chars().count() > MAX_ALT {
        return Err("alt text: at most 80 characters");
    }
    Ok(a)
}

/* ------------------------------------------------------- container sniffing */

#[derive(Debug, PartialEq, Clone, Copy)]
pub enum Kind {
    Png,
    Webp,
}

/// Decide the format from the first bytes only. Everything else (jpeg, gif, svg, html ...) is refused.
pub fn sniff(b: &[u8]) -> Result<Kind, &'static str> {
    if b.len() >= 8 && b[..8] == [0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A] {
        return Ok(Kind::Png);
    }
    if b.len() >= 12 && &b[0..4] == b"RIFF" && &b[8..12] == b"WEBP" {
        return Ok(Kind::Webp);
    }
    let head = String::from_utf8_lossy(&b[..b.len().min(256)]).to_lowercase();
    if head.contains("<svg") || head.contains("<?xml") {
        return Err("SVG is not accepted (it can carry scripts): upload a PNG or WebP");
    }
    Err("only PNG or WebP pictures are accepted")
}

fn be32(b: &[u8], i: usize) -> u32 {
    u32::from_be_bytes([b[i], b[i + 1], b[i + 2], b[i + 3]])
}
fn le24(b: &[u8], i: usize) -> u32 {
    b[i] as u32 | (b[i + 1] as u32) << 8 | (b[i + 2] as u32) << 16
}

/// PNG: width/height from IHDR, and refuse APNG (an `acTL` chunk before IDAT). Walks chunks without decoding anything.
pub fn png_info(b: &[u8]) -> Result<(u32, u32), &'static str> {
    if b.len() < 33 || &b[12..16] != b"IHDR" || be32(b, 8) != 13 {
        return Err("PNG: broken header");
    }
    let (w, h) = (be32(b, 16), be32(b, 20));
    let mut i = 8usize;
    while i + 12 <= b.len() {
        let len = be32(b, i) as usize;
        let ty = &b[i + 4..i + 8];
        if ty == b"acTL" || ty == b"fcTL" || ty == b"fdAT" {
            return Err("animated PNG is not accepted");
        }
        if ty == b"IDAT" || ty == b"IEND" {
            break;
        }
        i = match i.checked_add(12).and_then(|x| x.checked_add(len)) {
            Some(n) => n,
            None => return Err("PNG: broken chunk"),
        };
    }
    Ok((w, h))
}

/// WebP: width/height from the first chunk (VP8 / VP8L / VP8X) and refuse animation. No decoding.
pub fn webp_info(b: &[u8]) -> Result<(u32, u32), &'static str> {
    if b.len() < 30 || &b[0..4] != b"RIFF" || &b[8..12] != b"WEBP" {
        return Err("WebP: broken header");
    }
    let riff = u32::from_le_bytes([b[4], b[5], b[6], b[7]]) as usize;
    if riff + 8 > b.len() + 0 && riff + 8 != b.len() {
        // declared size larger than the bytes we have = truncated / lying header
        if riff + 8 > b.len() {
            return Err("WebP: truncated file");
        }
    }
    let tag = &b[12..16];
    match tag {
        b"VP8X" => {
            let flags = b[20];
            if flags & 0x02 != 0 {
                return Err("animated WebP is not accepted");
            }
            let (w, h) = (le24(b, 24) + 1, le24(b, 27) + 1);
            Ok((w, h))
        }
        b"VP8L" => {
            if b[20] != 0x2F {
                return Err("WebP: broken lossless header");
            }
            let bits = u32::from_le_bytes([b[21], b[22], b[23], b[24]]);
            Ok(((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1))
        }
        b"VP8 " => {
            if b[23..26] != [0x9D, 0x01, 0x2A] {
                return Err("WebP: broken lossy header");
            }
            let w = u16::from_le_bytes([b[26], b[27]]) as u32 & 0x3FFF;
            let h = u16::from_le_bytes([b[28], b[29]]) as u32 & 0x3FFF;
            Ok((w, h))
        }
        _ => Err("WebP: unknown first chunk"),
    }
}

/// The whole pre-decode gate. Ok((kind, w, h)) means: safe to hand to a decoder with a pixel limit.
pub fn gate_upload(b: &[u8]) -> Result<(Kind, u32, u32), String> {
    if b.is_empty() {
        return Err("empty file".into());
    }
    if b.len() > MAX_UPLOAD_BYTES {
        return Err(format!("file too big: at most {} KB", MAX_UPLOAD_BYTES / 1024));
    }
    let kind = sniff(b).map_err(|e| e.to_string())?;
    let (w, h) = match kind {
        Kind::Png => png_info(b),
        Kind::Webp => webp_info(b),
    }
    .map_err(|e| e.to_string())?;
    if w == 0 || h == 0 {
        return Err("picture has no size".into());
    }
    if w > MAX_SRC_SIDE || h > MAX_SRC_SIDE || (w as u64) * (h as u64) > MAX_SRC_PIXELS {
        return Err("picture is too large in pixels (max 4096 x 4096)".into());
    }
    if w < MIN_SIDE || h < MIN_SIDE {
        return Err("picture is too small (min 16 x 16)".into());
    }
    Ok((kind, w, h))
}

/* ----------------------------------------------------------- size ladder */

/// Target (w,h) fitting inside `side` x `side`, keeping the aspect ratio, never upscaling, never below MIN_SIDE.
pub fn fit(w: u32, h: u32, side: u32) -> (u32, u32) {
    let side = side.min(MAX_SIDE);
    if w <= side && h <= side {
        return (w.max(MIN_SIDE), h.max(MIN_SIDE));
    }
    let (nw, nh) = if w >= h {
        (side, ((h as u64 * side as u64) / w as u64) as u32)
    } else {
        (((w as u64 * side as u64) / h as u64) as u32, side)
    };
    (nw.max(MIN_SIDE), nh.max(MIN_SIDE))
}

/// The ladder steps to try, starting with the largest that does not upscale the source.
pub fn ladder_for(w: u32, h: u32) -> Vec<u32> {
    let m = w.max(h);
    let mut v: Vec<u32> = LADDER.iter().copied().filter(|&s| s <= m.max(LADDER[3])).collect();
    if v.is_empty() {
        v.push(LADDER[3]);
    }
    v
}

/* ------------------------------------------------------------ output check */

/// The last wall before the SQL door: a WebP made by OUR encoder must be exactly RIFF....WEBP with an allowed chunk set,
/// no EXIF / XMP / ICCP / ANIM / ANMF chunks, a plausible size and dimensions in range.
pub fn check_output(b: &[u8]) -> Result<(u32, u32), String> {
    if b.len() < MIN_OUT_BYTES {
        return Err("output too small".into());
    }
    if b.len() > MAX_OUT_BYTES {
        return Err("output over 64 KB".into());
    }
    let (w, h) = webp_info(b).map_err(|e| e.to_string())?;
    if w < MIN_SIDE || h < MIN_SIDE || w > MAX_SIDE || h > MAX_SIDE {
        return Err("output dimensions out of 16..256".into());
    }
    let mut i = 12usize;
    while i + 8 <= b.len() {
        let ty = &b[i..i + 4];
        let len = u32::from_le_bytes([b[i + 4], b[i + 5], b[i + 6], b[i + 7]]) as usize;
        match ty {
            b"VP8 " | b"VP8L" | b"ALPH" | b"VP8X" => {}
            _ => return Err(format!("output has a forbidden chunk {}", String::from_utf8_lossy(ty))),
        }
        let next = i + 8 + len + (len & 1);
        if next > b.len() + 1 {
            return Err("output chunk overruns the file".into());
        }
        i = next;
    }
    Ok((w, h))
}

/* ------------------------------------------------------------------ tokens */

/// Find ":code:" tokens in a text (D4B uses it at send time). Only shapes that pass `valid_code_shape`, deduped, in order.
pub fn tokens(text: &str) -> Vec<String> {
    let b = text.as_bytes();
    let mut out: Vec<String> = Vec::new();
    let mut i = 0usize;
    while i < b.len() {
        // the opening colon must not touch a letter/digit before it (12:30:45 is a time, not a token)
        let boundary = i == 0 || !(b[i - 1].is_ascii_alphanumeric());
        if b[i] == b':' && boundary {
            let mut j = i + 1;
            while j < b.len() && j - i - 1 <= 24 && (b[j].is_ascii_lowercase() || b[j].is_ascii_digit() || b[j] == b'_' || b[j] == b'-') {
                j += 1;
            }
            if j < b.len() && b[j] == b':' {
                let code = &text[i + 1..j];
                if valid_code_shape(code) && code.bytes().any(|c| c.is_ascii_lowercase()) && !out.iter().any(|c| c == code) {
                    out.push(code.to_string());
                }
                i = j; // the closing colon may open the next token
                continue;
            }
        }
        i += 1;
    }
    out
}

/// ETag value for the immutable same-origin serving (the sha256 itself, quoted).
pub fn etag(sha: &str) -> String {
    format!("\"{}\"", sha)
}

pub fn valid_sha(s: &str) -> bool {
    s.len() == 64 && s.bytes().all(|c| c.is_ascii_digit() || (b'a'..=b'f').contains(&c))
}

/* ------------------------------------------------------------------- tests */

#[cfg(test)]
mod tests {
    use super::*;

    fn png(w: u32, h: u32, extra: &[u8]) -> Vec<u8> {
        let mut v = vec![0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13];
        v.extend_from_slice(b"IHDR");
        v.extend_from_slice(&w.to_be_bytes());
        v.extend_from_slice(&h.to_be_bytes());
        v.extend_from_slice(&[8, 6, 0, 0, 0, 0, 0, 0, 0]); // depth, colour, 3 methods, crc(4)
        v.extend_from_slice(extra);
        v.extend_from_slice(&[0, 0, 0, 0]);
        v.extend_from_slice(b"IDAT");
        v.extend_from_slice(&[0; 8]);
        v
    }

    fn webp_l(w: u32, h: u32) -> Vec<u8> {
        let bits: u32 = (w - 1) | ((h - 1) << 14);
        let mut chunk = vec![0x2F];
        chunk.extend_from_slice(&bits.to_le_bytes());
        chunk.extend_from_slice(&[0; 60]);
        let mut v = b"RIFF".to_vec();
        v.extend_from_slice(&((4 + 8 + chunk.len()) as u32).to_le_bytes());
        v.extend_from_slice(b"WEBPVP8L");
        v.extend_from_slice(&(chunk.len() as u32).to_le_bytes());
        v.extend_from_slice(&chunk);
        v
    }

    #[test]
    fn tiers_match_sql() {
        assert_eq!(tier_limit("business"), 10);
        assert_eq!(tier_limit("business_pro"), 10);
        assert_eq!(tier_limit("business_premium"), 50);
        assert_eq!(tier_limit("business_max"), 200);
        assert_eq!(tier_limit("basic"), 0);
        assert_eq!(tier_limit("pro"), 0);
        assert_eq!(tier_limit(""), 0);
        assert_eq!(daily_upload_cap("business_max"), 200);
        assert_eq!(daily_upload_cap("basic"), 0);
    }

    #[test]
    fn codes() {
        assert_eq!(clean_code(" :Acme: ").unwrap(), "acme");
        assert!(clean_code("a").is_err());
        assert!(clean_code("-ab").is_err());
        assert!(clean_code("ab-").is_err());
        assert!(clean_code("a b").is_err());
        assert!(clean_code("Official").is_err());
        assert!(clean_code(":admin:").is_err());
        assert!(clean_code(&"a".repeat(25)).is_err());
        assert!(clean_code(&"a".repeat(24)).is_ok());
        assert!(clean_code("team_logo-2").is_ok());
        assert!(clean_code("چائے").is_err());
    }

    #[test]
    fn alt() {
        assert!(clean_alt("Acme logo").is_ok());
        assert!(clean_alt("bad\u{7}").is_err());
        assert!(clean_alt(&"x".repeat(81)).is_err());
    }

    #[test]
    fn sniff_refuses_others() {
        assert_eq!(sniff(&png(64, 64, &[])).unwrap(), Kind::Png);
        assert_eq!(sniff(&webp_l(64, 64)).unwrap(), Kind::Webp);
        assert!(sniff(b"<svg xmlns='http://www.w3.org/2000/svg'></svg>").unwrap_err().contains("SVG"));
        assert!(sniff(b"\xFF\xD8\xFF\xE0 jpeg").is_err());
        assert!(sniff(b"GIF89a....").is_err());
    }

    #[test]
    fn gate_accepts_and_refuses() {
        assert_eq!(gate_upload(&png(128, 64, &[])).unwrap(), (Kind::Png, 128, 64));
        assert_eq!(gate_upload(&webp_l(200, 100)).unwrap(), (Kind::Webp, 200, 100));
        assert!(gate_upload(&png(5000, 10, &[])).is_err()); // side
        assert!(gate_upload(&png(4096, 4096, &[])).is_err()); // pixels (16.7 MP)
        assert!(gate_upload(&png(8, 64, &[])).is_err()); // too small
        assert!(gate_upload(&vec![0u8; MAX_UPLOAD_BYTES + 1]).is_err());
        assert!(gate_upload(&[]).is_err());
        // APNG: acTL chunk before IDAT
        let mut ex = vec![0, 0, 0, 8];
        ex.extend_from_slice(b"acTL");
        ex.extend_from_slice(&[0; 12]);
        assert!(gate_upload(&png(64, 64, &ex)).unwrap_err().contains("animated"));
    }

    #[test]
    fn webp_animation_refused() {
        let mut v = b"RIFF".to_vec();
        v.extend_from_slice(&40u32.to_le_bytes());
        v.extend_from_slice(b"WEBPVP8X");
        v.extend_from_slice(&10u32.to_le_bytes());
        v.extend_from_slice(&[0x02, 0, 0, 0]); // animation flag
        v.extend_from_slice(&[63, 0, 0, 63, 0, 0]);
        v.extend_from_slice(&[0; 20]);
        assert!(webp_info(&v).unwrap_err().contains("animated"));
    }

    #[test]
    fn truncated_webp_refused() {
        let mut v = webp_l(64, 64);
        v.truncate(40);
        assert!(webp_info(&v).is_err());
    }

    #[test]
    fn fit_and_ladder() {
        assert_eq!(fit(1000, 500, 256), (256, 128));
        assert_eq!(fit(500, 1000, 256), (128, 256));
        assert_eq!(fit(100, 100, 256), (100, 100));
        assert_eq!(fit(400, 16, 256), (256, 16));
        assert_eq!(ladder_for(1000, 1000), vec![256, 192, 128, 96]);
        assert_eq!(ladder_for(100, 100), vec![96]);
        assert_eq!(ladder_for(150, 90), vec![128, 96]);
    }

    #[test]
    fn output_check() {
        assert_eq!(check_output(&webp_l(64, 64)).unwrap(), (64, 64));
        assert!(check_output(&webp_l(300, 64)).is_err()); // dims
        assert!(check_output(&webp_l(8, 8)).is_err());
        let mut big = webp_l(64, 64);
        big.extend(vec![0u8; MAX_OUT_BYTES]);
        assert!(check_output(&big).is_err());
        // an EXIF chunk appended = refused
        let mut v = webp_l(64, 64);
        v.extend_from_slice(b"EXIF");
        v.extend_from_slice(&4u32.to_le_bytes());
        v.extend_from_slice(&[1, 2, 3, 4]);
        assert!(check_output(&v).unwrap_err().contains("forbidden chunk"));
    }

    #[test]
    fn token_extraction() {
        assert_eq!(tokens("hi :acme: and :acme: :team-2: 12:30:45 :Bad: :x:"), vec!["acme", "team-2"]);
        assert_eq!(tokens(":a:b:"), Vec::<String>::new());
        assert_eq!(tokens(":ab::cd:"), vec!["ab", "cd"]);
        assert!(tokens("12:30:45 and a:b:c").is_empty());
        assert_eq!(tokens("(:acme:)"), vec!["acme"]);
        assert!(tokens("no tokens here").is_empty());
    }

    #[test]
    fn sha_and_etag() {
        assert!(valid_sha(&"a".repeat(64)));
        assert!(!valid_sha(&"A".repeat(64)));
        assert_eq!(etag("ab"), "\"ab\"");
    }
}
