// ============================================================================
// calfile_core.rs — #5: meeting par files. Sirf saaf (pure) tukde — database/network yahan nahi. SQL: docs/cursor-work/sql/E74_calendar_event_files.sql
// ============================================================================

/// 36 harf ka uuid (8-4-4-4-12, hex).
pub fn valid_uuid(s: &str) -> bool {
    s.len() == 36
        && s.char_indices().all(|(i, c)| if [8, 13, 18, 23].contains(&i) { c == '-' } else { c.is_ascii_hexdigit() })
}

/// "<uuid>" ya "<uuid>~<epoch>" (repeat hone wali meeting ka ek din) -> master meeting ka uuid (chhota). Files poori series ki hoti hain.
pub fn event_uuid(raw: &str) -> Option<String> {
    let base = raw.split_once('~').map(|(m, _)| m).unwrap_or(raw);
    if valid_uuid(base) {
        Some(base.to_ascii_lowercase())
    } else {
        None
    }
}

/// SQL ka error code -> (HTTP status, insaani jumla).
pub fn error_text(code: &str) -> (u16, &'static str) {
    match code {
        "bad_input" | "bad_id" => (400, "That request was not valid."),
        "unauthorized" => (401, "Please sign in again."),
        "account_blocked" => (403, "This account is blocked from adding files."),
        "organiser_only" => (403, "Only the organiser can add files to this meeting."),
        "no_workspace" => (409, "No workspace for this account."),
        "not_found" => (404, "That meeting or file was not found."),
        "attachment_not_found" => (404, "That upload was not found. Upload the file again."),
        "already_attached" => (409, "That file is already on this meeting."),
        "too_many_files" => (409, "A meeting can carry up to 10 files. Remove one first."),
        "event_cancelled" => (409, "This meeting is cancelled, so files cannot be added."),
        "sql_missing" => (501, "Meeting files are not set up on this server yet."),
        _ => (500, "Something went wrong with meeting files."),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn uuid_shape() {
        assert!(valid_uuid("0b1d2f3a-4c5d-4e6f-8a9b-0c1d2e3f4a5b"));
        assert!(!valid_uuid("0b1d2f3a4c5d4e6f8a9b0c1d2e3f4a5b"));
        assert!(!valid_uuid("0b1d2f3a-4c5d-4e6f-8a9b-0c1d2e3f4a5g"));
        assert!(!valid_uuid(""));
        assert!(!valid_uuid("0b1d2f3a-4c5d-4e6f-8a9b-0c1d2e3f4a5b; drop"));
    }

    #[test]
    fn occurrence_ids_map_to_master() {
        let u = "0B1D2F3A-4C5D-4E6F-8A9B-0C1D2E3F4A5B";
        assert_eq!(event_uuid(u).as_deref(), Some("0b1d2f3a-4c5d-4e6f-8a9b-0c1d2e3f4a5b"));
        assert_eq!(event_uuid(&format!("{u}~1790000000")).as_deref(), Some("0b1d2f3a-4c5d-4e6f-8a9b-0c1d2e3f4a5b"));
        assert_eq!(event_uuid("ext~sub~uid~1"), None);
        assert_eq!(event_uuid("nope"), None);
        assert_eq!(event_uuid(""), None);
    }

    #[test]
    fn errors_are_human_and_safe() {
        for c in ["bad_input", "organiser_only", "no_workspace", "not_found", "attachment_not_found", "already_attached", "too_many_files", "event_cancelled", "sql_missing", "zzz"] {
            let (s, m) = error_text(c);
            assert!((400..=501).contains(&s));
            assert!(!m.is_empty() && !m.contains("sql") && !m.contains("uuid"));
        }
        assert_eq!(error_text("organiser_only").0, 403);
        assert_eq!(error_text("zzz").0, 500);
    }
}
