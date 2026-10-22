// ============================================================================
// evidence_core.rs — E72: appeal ke saboot (screenshots, PDF, documents) ka "dimaag". Sirf std; tests `rustc --test` se.
// (IO + HTTP + DB `evidence_glue.rs` mein; attach_core.rs saath rehti hai — naam saaf karna, clamd jawab, uuid, header decode.)
//
// Kya yeh file karti hai:
//   - type ALLOWLIST (sirf images / PDF / text / Office / eml) — attachments ki block-list se sakht, kyunki yeh SIRF saboot hai, bhejne ki cheez nahi
//   - extension ke mutabiq asli bytes (magic) ki jaanch: .png naam wali exe ya zip nahi chalegi; text files mein NUL byte nahi
//   - storage path: `appeals/<user>/<sha[0..2]>/<sha>-<nonce8>` — org wale attachments se alag; DB se aaya path dobara parakhna
//   - appeal ke statement ki gintee (characters, bytes nahi) aur evidence ids ki safai
//   - SQL ke error code -> HTTP status + insaani jumla
// ============================================================================
#![allow(dead_code)]

#[cfg(test)]
#[path = "attach_core.rs"]
mod attach_core;
#[cfg(not(test))]
use crate::attach_core;

use attach_core as ac;

pub const STATEMENT_MIN: usize = 20;
pub const STATEMENT_MAX: usize = 20_000;
pub const MAX_IDS: usize = 5;

/// Sirf yeh extensions. (zip/rar/7z jaan-boojh kar nahi: andar kya hai yeh reviewer ke saamne nahi dikhta.)
const ALLOWED: &[&str] = &[
    "png", "jpg", "jpeg", "gif", "webp", "pdf", "txt", "csv", "md", "log", "eml", "doc", "docx", "odt", "rtf", "xls", "xlsx", "ods",
];

#[derive(Debug, PartialEq, Clone, Copy)]
enum Magic {
    Png,
    Jpeg,
    Gif,
    Webp,
    Pdf,
    Zip, // docx / xlsx / odt / ods
    Ole, // doc / xls (purana Office)
    Rtf,
    Text,
}

fn magic_for(ext: &str) -> Option<Magic> {
    Some(match ext {
        "png" => Magic::Png,
        "jpg" | "jpeg" => Magic::Jpeg,
        "gif" => Magic::Gif,
        "webp" => Magic::Webp,
        "pdf" => Magic::Pdf,
        "docx" | "xlsx" | "odt" | "ods" => Magic::Zip,
        "doc" | "xls" => Magic::Ole,
        "rtf" => Magic::Rtf,
        "txt" | "csv" | "md" | "log" | "eml" => Magic::Text,
        _ => return None,
    })
}

fn matches_magic(m: Magic, head: &[u8]) -> bool {
    match m {
        Magic::Png => head.starts_with(&[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]),
        Magic::Jpeg => head.starts_with(&[0xFF, 0xD8, 0xFF]),
        Magic::Gif => head.starts_with(b"GIF87a") || head.starts_with(b"GIF89a"),
        Magic::Webp => head.len() >= 12 && &head[..4] == b"RIFF" && &head[8..12] == b"WEBP",
        // PDF: "%PDF-" pehle 1024 bytes mein kahin (kuch generators pehle junk likhte hain)
        Magic::Pdf => head.windows(5).take(1024).any(|w| w == b"%PDF-"),
        Magic::Zip => head.starts_with(b"PK\x03\x04"),
        Magic::Ole => head.starts_with(&[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]),
        Magic::Rtf => head.starts_with(b"{\\rtf"),
        // text: NUL byte nahi (binary chhupa hua nahi) aur valid UTF-8 ya kam az kam printable ke qareeb
        Magic::Text => !head.contains(&0u8),
    }
}

/// Sirf naam dekh kar (body utaarne se pehle): kya yeh extension saboot ke taur par manzoor hai?
pub fn ext_allowed(name: &str) -> Result<(), String> {
    let ext = ac::ext_of(name);
    if ALLOWED.contains(&ext.as_str()) {
        return Ok(());
    }
    let shown = if ext.is_empty() { "(none)".to_string() } else { format!(".{ext}") };
    Err(format!("Files of type {shown} are not accepted as evidence. Use a screenshot (PNG/JPG), PDF, text, email (.eml) or an Office document."))
}

/// Ok(()) ya Err(wajah — insaan ko dikhane layak)
pub fn verdict(name: &str, head: &[u8]) -> Result<(), String> {
    ext_allowed(name)?;
    let ext = ac::ext_of(name);
    // attachments wali jaanch pehle (asli exe/ELF/script jis ka naam kuch bhi ho)
    ac::type_verdict(name, head)?;
    let m = magic_for(&ext).ok_or_else(|| "This file type is not accepted.".to_string())?;
    if !matches_magic(m, head) {
        return Err(format!("This file is named .{ext} but its contents are not a real .{ext} file."));
    }
    Ok(())
}

/// `appeals/<user>/<sha[0..2]>/<sha>-<nonce8>`
pub fn rel_path(user: &str, sha256: &str, nonce8: &str) -> Option<String> {
    if !ac::valid_uuid(user) || sha256.len() != 64 || !ac::is_hex(sha256) || nonce8.len() != 8 || !ac::is_hex(nonce8) {
        return None;
    }
    Some(format!("appeals/{user}/{}/{sha256}-{nonce8}", &sha256[..2]))
}

/// DB se aaya rel_path dobara parakhna: kabhi `..`, kabhi absolute, kabhi org wale path ki shakl nahi.
pub fn rel_path_valid(rel: &str) -> bool {
    let parts: Vec<&str> = rel.split('/').collect();
    if parts.len() != 4 || parts[0] != "appeals" || !ac::valid_uuid(parts[1]) || parts[2].len() != 2 || !ac::is_hex(parts[2]) {
        return false;
    }
    match parts[3].rsplit_once('-') {
        Some((sha, nonce)) => sha.len() == 64 && ac::is_hex(sha) && nonce.len() == 8 && ac::is_hex(nonce) && sha.starts_with(parts[2]),
        None => false,
    }
}

/// Statement ki gintee CHARACTERS mein (Urdu/emoji ke bytes nahi). Ok(trimmed) ya Err(code).
pub fn statement_check(raw: &str) -> Result<String, &'static str> {
    let t = raw.trim();
    let n = t.chars().count();
    if n < STATEMENT_MIN {
        return Err("statement_required");
    }
    if n > STATEMENT_MAX {
        return Err("statement_too_long");
    }
    Ok(t.to_string())
}

/// Evidence ids: sirf asli uuid, dohrao nahi, zyada se zyada MAX_IDS. Khali list ok.
pub fn clean_ids(ids: &[String]) -> Result<Vec<String>, &'static str> {
    let mut out: Vec<String> = Vec::new();
    for i in ids {
        let t = i.trim().to_ascii_lowercase();
        if !ac::valid_uuid(&t) {
            return Err("evidence_invalid");
        }
        if !out.contains(&t) {
            out.push(t);
        }
    }
    if out.len() > MAX_IDS {
        return Err("too_many_files");
    }
    Ok(out)
}

/// (HTTP status, insaani jumla) SQL ke error code ke liye.
pub fn error_text(code: &str) -> (u16, &'static str) {
    match code {
        "unauthorized" => (401, "Please sign in again."),
        "nothing_to_appeal" => (403, "There is nothing to appeal on this account."),
        "file_too_large" => (413, "This file is larger than the allowed size for evidence."),
        "total_too_large" => (413, "The evidence files together are larger than allowed."),
        "too_many_files" => (429, "Too many evidence files. Remove one first."),
        "rate_limited" => (429, "Too many uploads today. Try again tomorrow."),
        "not_found" => (404, "File not found."),
        "file_in_appeal" => (409, "This file is already part of an appeal and cannot be removed."),
        "not_allowed" => (403, "You cannot view this."),
        "statement_required" => (400, "Write at least 20 characters explaining why this block is wrong."),
        "statement_too_long" => (400, "An appeal can be up to 20,000 characters."),
        "evidence_invalid" => (400, "One of the attached files could not be used. Remove it and try again."),
        "bad_file" => (400, "The file could not be read."),
        _ => (400, "The request could not be completed."),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const U: &str = "0a1b2c3d-1111-4222-8333-444455556666";
    fn sha() -> String {
        "ab".repeat(32)
    }

    #[test]
    fn allowlist_only() {
        assert!(verdict("shot.png", &[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]).is_ok());
        for bad in ["a.zip", "a.exe", "a.js", "a.html", "a.svg", "a.rar", "a", "a.7z", "a.sh", "a.php"] {
            assert!(verdict(bad, b"hello").is_err(), "{bad}");
        }
    }

    #[test]
    fn content_must_match_extension() {
        let png = [0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A];
        assert!(verdict("a.png", &png).is_ok());
        assert!(verdict("a.jpg", &png).is_err(), "png bytes ke saath .jpg naam");
        assert!(verdict("a.jpg", &[0xFF, 0xD8, 0xFF, 0xE0]).is_ok());
        assert!(verdict("a.gif", b"GIF89a....").is_ok());
        assert!(verdict("a.webp", b"RIFF\x10\0\0\0WEBPVP8 ").is_ok());
        assert!(verdict("a.webp", b"RIFF\x10\0\0\0WAVEfmt ").is_err());
        assert!(verdict("a.pdf", b"%PDF-1.7\n...").is_ok());
        assert!(verdict("a.pdf", b"junk\n%PDF-1.4").is_ok(), "PDF ke pehle thoda junk");
        assert!(verdict("a.pdf", b"not a pdf at all").is_err());
        assert!(verdict("a.docx", b"PK\x03\x04rest").is_ok());
        assert!(verdict("a.docx", b"plain text").is_err());
        assert!(verdict("a.doc", &[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0]).is_ok());
        assert!(verdict("a.rtf", b"{\\rtf1\\ansi").is_ok());
    }

    #[test]
    fn disguised_executables_are_refused() {
        let mut pe = vec![0u8; 0x80];
        pe[0] = b'M';
        pe[1] = b'Z';
        pe[0x3c] = 0x40;
        pe[0x40..0x44].copy_from_slice(b"PE\0\0");
        assert!(verdict("invoice.pdf", &pe).is_err());
        assert!(verdict("notes.txt", &pe).is_err(), "NUL bytes + exe");
        assert!(verdict("a.png", b"\x7fELF\x02\x01\x01").is_err());
    }

    #[test]
    fn text_files_must_not_hide_binary() {
        assert!(verdict("a.txt", "Mera block ghalat hai — میرا بلاک غلط ہے".as_bytes()).is_ok());
        assert!(verdict("a.csv", b"a,b\n1,2\n").is_ok());
        assert!(verdict("a.eml", b"From: a@b.c\r\nSubject: x\r\n\r\nhi").is_ok());
        assert!(verdict("a.txt", b"abc\0def").is_err());
    }

    #[test]
    fn extension_check_is_case_insensitive_and_last_ext_only() {
        assert!(verdict("SHOT.PNG", &[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]).is_ok());
        assert!(verdict("shot.png.exe", &[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]).is_err());
        assert!(verdict("shot.exe.png", &[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]).is_ok());
    }

    #[test]
    fn rel_path_shape() {
        let r = rel_path(U, &sha(), "0123abcd").unwrap();
        assert_eq!(r, format!("appeals/{U}/ab/{}-0123abcd", sha()));
        assert!(rel_path_valid(&r));
        assert!(rel_path("not-a-uuid", &sha(), "0123abcd").is_none());
        assert!(rel_path(U, "short", "0123abcd").is_none());
        assert!(rel_path(U, &sha(), "ZZZZZZZZ").is_none());
        assert!(rel_path(U, &"AB".repeat(32), "0123abcd").is_none(), "capital hex nahi");
    }

    #[test]
    fn rel_path_valid_rejects_tricks() {
        let ok = rel_path(U, &sha(), "0123abcd").unwrap();
        assert!(rel_path_valid(&ok));
        for bad in [
            format!("../appeals/{U}/ab/{}-0123abcd", sha()),
            format!("/appeals/{U}/ab/{}-0123abcd", sha()),
            format!("appeals/{U}/cd/{}-0123abcd", sha()),
            format!("appeals/{U}/ab/../{}-0123abcd", sha()),
            format!("{U}/ab/{}-0123abcd", sha()),
            format!("appeals/{U}/ab/{}-0123abc", sha()),
            "appeals/x/ab/y".to_string(),
            String::new(),
        ] {
            assert!(!rel_path_valid(&bad), "{bad}");
        }
    }

    #[test]
    fn statement_counts_characters_not_bytes() {
        assert_eq!(statement_check("a".repeat(19).as_str()), Err("statement_required"));
        assert!(statement_check(&"a".repeat(20)).is_ok());
        assert!(statement_check(&"a".repeat(20_000)).is_ok());
        assert_eq!(statement_check(&"a".repeat(20_001)), Err("statement_too_long"));
        // Urdu: har harf 2 byte — 20,000 harf = 40,000 bytes, phir bhi ok
        assert!(statement_check(&"ب".repeat(20_000)).is_ok());
        assert_eq!(statement_check(&"ب".repeat(20_001)), Err("statement_too_long"));
        // trim ke baad ginti
        assert_eq!(statement_check(&format!("   {}   ", "a".repeat(19))), Err("statement_required"));
        assert_eq!(statement_check("   "), Err("statement_required"));
    }

    #[test]
    fn ids_are_cleaned() {
        let a = "11111111-1111-4111-8111-111111111111".to_string();
        let b = "22222222-2222-4222-8222-222222222222".to_string();
        assert_eq!(clean_ids(&[]).unwrap(), Vec::<String>::new());
        assert_eq!(clean_ids(&[a.clone(), a.clone(), b.clone()]).unwrap(), vec![a.clone(), b.clone()]);
        assert_eq!(clean_ids(&[a.to_ascii_uppercase()]).unwrap(), vec![a.clone()]);
        assert_eq!(clean_ids(&["nope".to_string()]), Err("evidence_invalid"));
        assert_eq!(clean_ids(&["'; drop table x; --".to_string()]), Err("evidence_invalid"));
        let six: Vec<String> = (1..=6).map(|i| format!("{i}{i}111111-1111-4111-8111-111111111111")).collect();
        assert_eq!(clean_ids(&six), Err("too_many_files"));
    }

    #[test]
    fn error_text_has_sensible_status() {
        assert_eq!(error_text("unauthorized").0, 401);
        assert_eq!(error_text("file_too_large").0, 413);
        assert_eq!(error_text("rate_limited").0, 429);
        assert_eq!(error_text("whatever").0, 400);
        assert!(!error_text("not_found").1.contains("exists"), "wajood ka ishara nahi");
    }
}
