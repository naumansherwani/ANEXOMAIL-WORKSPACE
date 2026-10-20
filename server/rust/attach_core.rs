// ============================================================================
// attach_core.rs — G38: bheji jane wali mail ke attachments ka "dimaag". Sirf std, koi crate nahi, tests `rustc --test` se.
// (IO + HTTP + DB `attach_glue.rs` mein.)
//
// Kya yeh file karti hai:
//   - file ka naam saaf karna (path tricks, bidi-override dhoka (naam ke beech ulta-likhne wala hidden character), control chars, trailing dot/space)
//   - type policy: khatarnak extension (Gmail jaisi list) ya asli exe/ELF/Mach-O bytes kisi aur naam ke peeche => rad
//   - storage path: `<org>/<sha[0..2]>/<sha>-<nonce8>` — dedup SIRF org ke andar (cross-org kabhi nahi), har generation ka apna path
//   - header decode/encode (percent), Content-Disposition, mime saaf karna
//   - clamd (ClamAV INSTREAM) ka jawab parse karna
// ============================================================================

pub const MAX_NAME_BYTES: usize = 200;
pub const HEAD_BYTES: usize = 4096;

/// Gmail jaisi block list: chalne wali / installer / script files. (zip ke andar ki cheez clamd dekhta hai.)
const BLOCKED_EXT: &[&str] = &[
    "ade", "adp", "apk", "appx", "appxbundle", "bat", "cab", "chm", "cmd", "com", "cpl", "dll", "dmg", "ex", "ex_", "exe", "hta", "ins",
    "isp", "iso", "jar", "js", "jse", "lib", "lnk", "mde", "msc", "msi", "msix", "msixbundle", "mst", "nsh", "pif", "ps1", "scr",
    "sct", "shb", "sys", "vb", "vbe", "vbs", "vxd", "wsc", "wsf", "wsh",
];

fn is_bidi_or_control(c: char) -> bool {
    c.is_control()
        || matches!(c as u32, 0x200B..=0x200F | 0x202A..=0x202E | 0x2060..=0x2064 | 0x2066..=0x2069 | 0xFEFF | 0xFFF9..=0xFFFB)
}

/// Kachcha naam -> mehfooz naam. Hamesha kuch na kuch deta hai ("file" agar kuch na bache).
pub fn sanitize_filename(raw: &str) -> String {
    // path ka sirf aakhri hissa (/, \ dono)
    let last = raw.rsplit(['/', '\\']).next().unwrap_or("");
    let mut s: String = last
        .chars()
        .filter(|c| !is_bidi_or_control(*c))
        .map(|c| if matches!(c, '"' | '<' | '>' | ':' | '|' | '?' | '*') { '_' } else { c })
        .collect();
    // Windows trailing dot/space hata deta hai ("a.exe " == "a.exe") — hum pehle hi hata dete hain taake check sahi ho
    s = s.trim_matches(|c: char| c == ' ' || c == '.').to_string();
    if s.is_empty() || s == ".." {
        return "file".to_string();
    }
    if s.len() > MAX_NAME_BYTES {
        // extension bachate hue, char boundary par kaato
        let ext = ext_of(&s);
        let keep_ext = if ext.is_empty() || ext.len() > 16 { String::new() } else { format!(".{ext}") };
        let budget = MAX_NAME_BYTES - keep_ext.len();
        let mut cut = String::new();
        for ch in s.chars() {
            if cut.len() + ch.len_utf8() > budget {
                break;
            }
            cut.push(ch);
        }
        s = format!("{cut}{keep_ext}");
    }
    s
}

/// aakhri extension, chhoti, bina dot ("a.tar.GZ" -> "gz"; "noext" -> "")
pub fn ext_of(name: &str) -> String {
    match name.rsplit_once('.') {
        Some((stem, ext)) if !stem.is_empty() => ext.to_ascii_lowercase(),
        _ => String::new(),
    }
}

fn looks_executable(head: &[u8]) -> Option<&'static str> {
    if head.len() >= 4 && &head[..4] == b"\x7fELF" {
        return Some("ELF executable");
    }
    if head.len() >= 4 {
        let m = [head[0], head[1], head[2], head[3]];
        if matches!(m, [0xFE, 0xED, 0xFA, 0xCE] | [0xFE, 0xED, 0xFA, 0xCF] | [0xCE, 0xFA, 0xED, 0xFE] | [0xCF, 0xFA, 0xED, 0xFE] | [0xCA, 0xFE, 0xBA, 0xBE] | [0xBE, 0xBA, 0xFE, 0xCA]) {
            // 0xCAFEBABE java class bhi hai — dono (Mach-O fat / Java class) chalne wali cheez
            return Some("Mach-O/Java executable");
        }
    }
    // PE: "MZ" + e_lfanew (0x3c) jo "PE\0\0" par ishara kare
    if head.len() >= 0x40 && &head[..2] == b"MZ" {
        let off = u32::from_le_bytes([head[0x3c], head[0x3d], head[0x3e], head[0x3f]]) as usize;
        if off >= 0x40 && off + 4 <= head.len() && &head[off..off + 4] == b"PE\0\0" {
            return Some("Windows executable");
        }
        // e_lfanew head se bahar ho to bhi: MZ + DOS stub text
        if off >= head.len() && off < 0x10_0000 {
            return Some("Windows executable");
        }
    }
    // shebang script (#!) — Linux/Mac par seedha chalne wali
    if head.len() >= 2 && &head[..2] == b"#!" {
        return Some("script with interpreter line");
    }
    None
}

/// Ok(()) ya Err(wajah — insaan ko dikhane layak)
pub fn type_verdict(name: &str, head: &[u8]) -> Result<(), String> {
    let ext = ext_of(name);
    if BLOCKED_EXT.contains(&ext.as_str()) {
        return Err(format!("Files of type .{ext} can't be sent because they can run on the receiver's computer. Put it in a .zip if you really need to send it."));
    }
    if let Some(kind) = looks_executable(head) {
        // asli exe jis ka naam .exe nahi => dhoka. (Naam .sh/.py wale scripts ko `#!` par nahi rokte.)
        let script_name = matches!(ext.as_str(), "sh" | "py" | "rb" | "pl" | "bash" | "zsh" | "command" | "txt" | "md" | "json");
        if !(kind.starts_with("script") && script_name) {
            return Err(format!("This file is a {kind} but is named .{}. It was not attached.", if ext.is_empty() { "(none)".into() } else { ext }));
        }
    }
    Ok(())
}

pub fn is_hex(s: &str) -> bool {
    !s.is_empty() && s.bytes().all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase())
}

pub fn valid_uuid(s: &str) -> bool {
    let b = s.as_bytes();
    if b.len() != 36 {
        return false;
    }
    for (i, c) in b.iter().enumerate() {
        let dash = matches!(i, 8 | 13 | 18 | 23);
        if dash {
            if *c != b'-' {
                return false;
            }
        } else if !(c.is_ascii_digit() || (b'a'..=b'f').contains(c)) {
            return false;
        }
    }
    true
}

/// `<org>/<sha[0..2]>/<sha>-<nonce8>`
pub fn rel_path(org: &str, sha256: &str, nonce8: &str) -> Option<String> {
    if !valid_uuid(org) || sha256.len() != 64 || !is_hex(sha256) || nonce8.len() != 8 || !is_hex(nonce8) {
        return None;
    }
    Some(format!("{org}/{}/{sha256}-{nonce8}", &sha256[..2]))
}

/// DB se aaya rel_path dobara parakhna (kabhi `..`, kabhi absolute, kabhi kisi aur shakl ka path nahi).
pub fn rel_path_valid(rel: &str) -> bool {
    let parts: Vec<&str> = rel.split('/').collect();
    if parts.len() != 3 || !valid_uuid(parts[0]) || parts[1].len() != 2 || !is_hex(parts[1]) {
        return false;
    }
    match parts[2].rsplit_once('-') {
        Some((sha, nonce)) => sha.len() == 64 && is_hex(sha) && nonce.len() == 8 && is_hex(nonce) && sha.starts_with(parts[1]),
        None => false,
    }
}

/// `x-file-name` header: percent-encoded UTF-8.
pub fn pct_decode(s: &str) -> String {
    let b = s.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() {
            let h = std::str::from_utf8(&b[i + 1..i + 3]).ok().and_then(|x| u8::from_str_radix(x, 16).ok());
            if let Some(v) = h {
                out.push(v);
                i += 3;
                continue;
            }
        }
        out.push(b[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

pub fn pct_encode(s: &str) -> String {
    let mut o = String::new();
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') {
            o.push(b as char);
        } else {
            o.push_str(&format!("%{b:02X}"));
        }
    }
    o
}

/// RFC 6266: ASCII fallback + `filename*=UTF-8''…`. Header injection (quote, CR/LF) kabhi nahi.
pub fn content_disposition(name: &str) -> String {
    let clean = sanitize_filename(name);
    let ascii: String = clean
        .chars()
        .map(|c| if c.is_ascii() && !c.is_ascii_control() && c != '"' && c != '\\' && c != '%' { c } else { '_' })
        .collect();
    format!("attachment; filename=\"{ascii}\"; filename*=UTF-8''{}", pct_encode(&clean))
}

/// declared mime: sirf `type/subtype` token chars; warna octet-stream
pub fn clean_mime(raw: &str) -> String {
    let base = raw.split(';').next().unwrap_or("").trim().to_ascii_lowercase();
    let ok = base.len() <= 100
        && base.matches('/').count() == 1
        && base
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'/' | b'.' | b'+' | b'-' | b'_'))
        && !base.starts_with('/')
        && !base.ends_with('/');
    if ok { base } else { "application/octet-stream".to_string() }
}

#[derive(Debug, PartialEq, Clone)]
pub enum ClamVerdict {
    Clean,
    Found(String),
    Error(String),
}

/// clamd "zINSTREAM" jawab: `stream: OK` / `stream: Eicar-Test-Signature FOUND` / `... ERROR`
pub fn parse_clamd(reply: &str) -> ClamVerdict {
    let r = reply.trim_matches(|c: char| c == '\0' || c.is_whitespace());
    if r.ends_with("OK") {
        return ClamVerdict::Clean;
    }
    if let Some(body) = r.strip_suffix("FOUND") {
        let sig = body.trim().trim_start_matches("stream:").trim();
        return ClamVerdict::Found(if sig.is_empty() { "unknown".into() } else { sig.chars().take(120).collect() });
    }
    ClamVerdict::Error(r.chars().take(200).collect())
}

/// Content-Length header se pehle hi rad karna (poori file utarne se pehle)
pub fn exceeds_cap(declared: Option<u64>, cap: u64) -> bool {
    matches!(declared, Some(n) if n > cap)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sanitize_strips_paths_and_tricks() {
        assert_eq!(sanitize_filename("../../etc/passwd"), "passwd");
        assert_eq!(sanitize_filename("C:\\Users\\a\\report.pdf"), "report.pdf");
        assert_eq!(sanitize_filename("  .. "), "file");
        assert_eq!(sanitize_filename(""), "file");
        assert_eq!(sanitize_filename("invoice\u{202E}fdp.exe"), "invoicefdp.exe");
        assert_eq!(sanitize_filename("a\u{0}b\r\nc.txt"), "abc.txt");
        assert_eq!(sanitize_filename("run.exe . "), "run.exe");
        assert_eq!(sanitize_filename("q\"<>:|?*.txt"), "q_______.txt");
    }

    #[test]
    fn sanitize_long_names_keep_extension_and_char_boundary() {
        let long = format!("{}.pdf", "é".repeat(300));
        let s = sanitize_filename(&long);
        assert!(s.len() <= MAX_NAME_BYTES);
        assert!(s.ends_with(".pdf"));
        assert!(std::str::from_utf8(s.as_bytes()).is_ok());
    }

    #[test]
    fn extension_rules() {
        assert_eq!(ext_of("a.tar.GZ"), "gz");
        assert_eq!(ext_of("noext"), "");
        assert_eq!(ext_of(".bashrc"), "");
    }

    #[test]
    fn blocked_extensions_even_after_trailing_tricks() {
        assert!(type_verdict(&sanitize_filename("setup.EXE"), b"").is_err());
        assert!(type_verdict(&sanitize_filename("setup.exe "), b"").is_err());
        assert!(type_verdict(&sanitize_filename("invoice\u{202E}fdp.exe"), b"").is_err());
        assert!(type_verdict("x.js", b"").is_err());
        assert!(type_verdict("x.pdf", b"%PDF-1.7").is_ok());
        assert!(type_verdict("notes.txt", b"hello").is_ok());
        assert!(type_verdict("archive.zip", b"PK\x03\x04").is_ok());
    }

    #[test]
    fn disguised_executables_are_refused() {
        let mut pe = vec![0u8; 256];
        pe[0] = b'M';
        pe[1] = b'Z';
        pe[0x3c] = 0x80;
        pe[0x80..0x84].copy_from_slice(b"PE\0\0");
        assert!(type_verdict("holiday.jpg", &pe).is_err());
        assert!(type_verdict("holiday.jpg", b"\x7fELF\x02\x01\x01").is_err());
        assert!(type_verdict("holiday.jpg", &[0xCF, 0xFA, 0xED, 0xFE, 0, 0]).is_err());
        // "MZ" se shuru hone wala saada text exe nahi
        assert!(type_verdict("initials.txt", b"MZ are the initials of the sender, nothing more than text here at all....").is_ok());
        // shebang: asli .sh/.py allowed, .jpg ke peeche nahi
        assert!(type_verdict("backup.sh", b"#!/bin/sh\necho hi").is_ok());
        assert!(type_verdict("photo.jpg", b"#!/bin/sh\necho hi").is_err());
    }

    #[test]
    fn rel_path_is_per_org_and_validated() {
        let org = "11111111-1111-1111-1111-111111111111";
        let sha = "ab".repeat(32);
        let r = rel_path(org, &sha, "0123abcd").unwrap();
        assert_eq!(r, format!("{org}/ab/{sha}-0123abcd"));
        assert!(rel_path_valid(&r));
        // doosre org ka path alag => cross-org dedup structurally impossible
        let r2 = rel_path("22222222-2222-2222-2222-222222222222", &sha, "0123abcd").unwrap();
        assert_ne!(r, r2);
        assert!(rel_path("not-a-uuid", &sha, "0123abcd").is_none());
        assert!(rel_path(org, "zz", "0123abcd").is_none());
        assert!(rel_path(org, &sha, "xyz").is_none());
        assert!(rel_path(org, &sha.to_uppercase(), "0123abcd").is_none());
    }

    #[test]
    fn rel_path_valid_rejects_traversal_and_shapes() {
        let org = "11111111-1111-1111-1111-111111111111";
        let sha = "cd".repeat(32);
        assert!(!rel_path_valid(&format!("../{org}/cd/{sha}-0123abcd")));
        assert!(!rel_path_valid(&format!("/{org}/cd/{sha}-0123abcd")));
        assert!(!rel_path_valid(&format!("{org}/cd/{sha}")));
        assert!(!rel_path_valid(&format!("{org}/ab/{sha}-0123abcd"))); // prefix sha se mel nahi khata
        assert!(!rel_path_valid(&format!("{org}/cd/../{sha}-0123abcd")));
        assert!(!rel_path_valid(""));
    }

    #[test]
    fn header_encoding_round_trips_and_cannot_inject() {
        let n = "résumé 2026.pdf";
        assert_eq!(pct_decode(&pct_encode(n)), n);
        assert_eq!(pct_decode("a%2"), "a%2");
        assert_eq!(pct_decode("%zz"), "%zz");
        let cd = content_disposition("evil\"\r\nSet-Cookie: x=1.txt");
        assert!(!cd.contains('\r') && !cd.contains('\n'));
        assert_eq!(cd.matches('"').count(), 2);
        let cd2 = content_disposition("résumé.pdf");
        assert!(cd2.contains("filename=\"r_sum_.pdf\""));
        assert!(cd2.contains("filename*=UTF-8''r%C3%A9sum%C3%A9.pdf"));
    }

    #[test]
    fn mime_is_cleaned() {
        assert_eq!(clean_mime("application/pdf"), "application/pdf");
        assert_eq!(clean_mime("Text/Plain; charset=utf-8"), "text/plain");
        assert_eq!(clean_mime("x\r\nBcc: a@b"), "application/octet-stream");
        assert_eq!(clean_mime(""), "application/octet-stream");
        assert_eq!(clean_mime("a/b/c"), "application/octet-stream");
    }

    #[test]
    fn clamd_replies() {
        assert_eq!(parse_clamd("stream: OK\0"), ClamVerdict::Clean);
        assert_eq!(parse_clamd("stream: Eicar-Test-Signature FOUND\0"), ClamVerdict::Found("Eicar-Test-Signature".into()));
        assert!(matches!(parse_clamd("INSTREAM size limit exceeded. ERROR"), ClamVerdict::Error(_)));
        assert!(matches!(parse_clamd(""), ClamVerdict::Error(_)));
    }

    #[test]
    fn cap_check() {
        assert!(exceeds_cap(Some(10), 9));
        assert!(!exceeds_cap(Some(9), 9));
        assert!(!exceeds_cap(None, 9));
    }

    #[test]
    fn uuid_shape() {
        assert!(valid_uuid("11111111-1111-1111-1111-111111111111"));
        assert!(!valid_uuid("11111111-1111-1111-1111-11111111111Z"));
        assert!(!valid_uuid("11111111111111111111111111111111"));
        assert!(!valid_uuid("11111111-1111-1111-1111-111111111111/../x"));
    }
}
