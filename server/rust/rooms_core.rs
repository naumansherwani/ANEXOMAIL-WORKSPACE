// ============================================================================
// rooms_core.rs — #8 Rooms. Sirf saaf (pure) tukde. SQL: docs/cursor-work/sql/E82_calendar_rooms.sql
// ============================================================================

pub const ROOM_DOMAIN: &str = "@rooms.anexomail.com";

pub fn valid_uuid(s: &str) -> bool {
    s.len() == 36
        && s.char_indices().all(|(i, c)| if [8, 13, 18, 23].contains(&i) { c == '-' } else { c.is_ascii_hexdigit() })
}

/// "<uuid>" ya "<uuid>~<epoch>" -> master meeting uuid (room poori series ke liye).
pub fn event_uuid(raw: &str) -> Option<String> {
    let base = raw.split_once('~').map(|(m, _)| m).unwrap_or(raw);
    if valid_uuid(base) { Some(base.to_ascii_lowercase()) } else { None }
}

/// Room ka pseudo address? (room-<12 hex>@rooms.anexomail.com) — invite mail aur guest-list filter isi se.
pub fn is_room_address(a: &str) -> bool {
    let a = a.to_ascii_lowercase();
    match a.strip_suffix(ROOM_DOMAIN) {
        Some(l) => l.len() == 17 && l.starts_with("room-") && l[5..].chars().all(|c| matches!(c, '0'..='9' | 'a'..='f')),
        None => false,
    }
}

/// RFC3339 jaisi simple jaanch (parse Postgres karta hai); length + shape sirf kachra rokne ke liye.
pub fn ts_ok(s: &str) -> bool {
    (20..=40).contains(&s.len()) && s.as_bytes()[4] == b'-' && s.contains('T')
}

pub fn error_text(code: &str) -> (u16, &'static str) {
    match code {
        "bad_input" | "bad_id" | "bad_name" | "bad_kind" | "bad_capacity" | "bad_location" | "bad_time" => (400, "That request was not valid."),
        "unauthorized" => (401, "Please sign in again."),
        "forbidden" => (403, "Only workspace owners and admins can manage rooms."),
        "not_organiser" => (403, "Only the organiser can change rooms on this meeting."),
        "no_workspace" => (409, "No workspace for this account."),
        "no_event" | "no_room" => (404, "That meeting or room was not found."),
        "room_busy" => (409, "That room is already booked at this time."),
        "name_taken" => (409, "A room with that name already exists."),
        "too_many" => (409, "This workspace has reached its room limit (200)."),
        "retry" => (503, "Please try again."),
        "sql_missing" => (503, "Rooms are not set up on the server yet."),
        _ => (400, "That request could not be completed."),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn room_addr() {
        assert!(is_room_address("room-0123456789ab@rooms.anexomail.com"));
        assert!(is_room_address("ROOM-0123456789AB@Rooms.Anexomail.com"));
        assert!(!is_room_address("room-0123456789a@rooms.anexomail.com"));
        assert!(!is_room_address("room-0123456789ag@rooms.anexomail.com"));
        assert!(!is_room_address("room-0123456789ab@anexomail.com"));
        assert!(!is_room_address("x@rooms.anexomail.com"));
    }
    #[test]
    fn ids() {
        let u = "0f8fad5b-d9cb-469f-a165-70867728950e";
        assert_eq!(event_uuid(&format!("{u}~1700000000")).as_deref(), Some(u));
        assert!(event_uuid("nope").is_none());
    }
    #[test]
    fn ts() {
        assert!(ts_ok("2030-01-01T10:00:00Z"));
        assert!(!ts_ok("x"));
    }
    #[test]
    fn errors() {
        assert_eq!(error_text("room_busy").0, 409);
        assert_eq!(error_text("zzz").0, 400);
    }
}
