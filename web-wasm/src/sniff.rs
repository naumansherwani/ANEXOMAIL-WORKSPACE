//! Module `sniff@1` — attachment ke asli bytes (magic) ki jaanch upload se pehle. Server (attach_core / evidence_core) phir bhi akhri faisla karta hai;
//! yeh sirf user ko foran, bina upload ke, sach batata hai.

pub const OK: i32 = 0;
/// Naam kuch aur kehta hai, bytes kuch aur (.png naam ki exe, .pdf naam ki zip ...).
pub const MISMATCH: i32 = 1;
/// Chalne wali file (exe/dll/ELF/Mach-O/script) — attachment mein kabhi nahi.
pub const EXECUTABLE: i32 = 2;
/// Extension jaanch ki list mein nahi (koi faisla nahi; server dekhega).
pub const UNKNOWN: i32 = 3;

fn ext_of(name: &str) -> String {
    match name.rsplit_once('.') {
        Some((stem, e)) if !stem.is_empty() && !e.is_empty() && e.len() <= 8 => e.to_ascii_lowercase(),
        _ => String::new(),
    }
}

pub fn is_executable(head: &[u8]) -> bool {
    head.starts_with(b"MZ")
        || head.starts_with(&[0x7F, b'E', b'L', b'F'])
        || head.starts_with(b"#!")
        || head.starts_with(&[0xCF, 0xFA, 0xED, 0xFE])
        || head.starts_with(&[0xCE, 0xFA, 0xED, 0xFE])
        || head.starts_with(&[0xFE, 0xED, 0xFA, 0xCE])
        || head.starts_with(&[0xFE, 0xED, 0xFA, 0xCF])
        || head.starts_with(&[0xCA, 0xFE, 0xBA, 0xBE]) // Mach-O fat / Java class
}

fn matches(ext: &str, head: &[u8]) -> Option<bool> {
    Some(match ext {
        "png" => head.starts_with(&[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]),
        "jpg" | "jpeg" => head.starts_with(&[0xFF, 0xD8, 0xFF]),
        "gif" => head.starts_with(b"GIF87a") || head.starts_with(b"GIF89a"),
        "webp" => head.len() >= 12 && &head[..4] == b"RIFF" && &head[8..12] == b"WEBP",
        "pdf" => head.iter().take(1024).copied().collect::<Vec<u8>>().windows(5).any(|w| w == b"%PDF-"),
        "zip" | "docx" | "xlsx" | "pptx" | "odt" | "ods" => head.starts_with(b"PK\x03\x04") || head.starts_with(b"PK\x05\x06"),
        "doc" | "xls" | "ppt" => head.starts_with(&[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]),
        "rtf" => head.starts_with(b"{\\rtf"),
        "txt" | "csv" | "md" | "log" | "eml" => !head.contains(&0u8),
        _ => return None,
    })
}

/// `head` = file ke pehle bytes (kam az kam 1024 behtar). Pehle executable, phir naam-vs-bytes.
pub fn check(name: &str, head: &[u8]) -> i32 {
    if is_executable(head) {
        return EXECUTABLE;
    }
    match matches(&ext_of(name), head) {
        Some(true) => OK,
        Some(false) => MISMATCH,
        None => UNKNOWN,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    const PNG: &[u8] = &[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0];

    #[test]
    fn real_files_pass() {
        assert_eq!(check("a.png", PNG), OK);
        assert_eq!(check("A.PNG", PNG), OK);
        assert_eq!(check("r.pdf", b"%PDF-1.7 ..."), OK);
        assert_eq!(check("late.pdf", &[b"junk".as_slice(), &[b' '; 100], b"%PDF-1.4"].concat()), OK);
        assert_eq!(check("d.docx", b"PK\x03\x04rest"), OK);
        assert_eq!(check("n.txt", "salaam, naye saal ✓".as_bytes()), OK);
    }

    #[test]
    fn disguised_files_are_caught() {
        assert_eq!(check("holiday.png", b"MZ\x90\x00"), EXECUTABLE);
        assert_eq!(check("report.pdf", &[0x7F, b'E', b'L', b'F', 2, 1]), EXECUTABLE);
        assert_eq!(check("run.txt", b"#!/bin/sh\nrm -rf /"), EXECUTABLE);
        assert_eq!(check("x.pdf", PNG), MISMATCH);
        assert_eq!(check("x.jpg", b"GIF89a"), MISMATCH);
        assert_eq!(check("notes.txt", b"ab\0cd"), MISMATCH);
    }

    #[test]
    fn unknown_types_are_left_to_the_server() {
        assert_eq!(check("archive.7z", b"7z\xBC\xAF"), UNKNOWN);
        assert_eq!(check("noext", b"hello"), UNKNOWN);
        assert_eq!(check(".png", PNG), UNKNOWN, "a dotfile is not an extension");
        assert_eq!(check("empty.png", b""), MISMATCH);
    }
}
