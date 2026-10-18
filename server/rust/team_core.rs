// ============================================================================
// team_core.rs — the pure, testable half of "invite people to your organisation" + Teams.
//
// std-only (no crates) so the same file is unit-tested on the server by the installer BEFORE anything is changed:
//     rustc --edition 2021 --test team_core.rs -o team_core_test && ./team_core_test
// All I/O (Supabase, SMTP, HTTP) lives in team_glue.rs. Everything that DECIDES something lives here:
//   * who may invite / change / remove whom (roles) — one place, so the Members page and the API can never disagree;
//   * which e-mail addresses become invitations (valid, new, not already members, not repeated);
//   * the invitation e-mail itself (header-injection safe, text + HTML, UTF-8);
//   * team names and slugs.
// ============================================================================

use std::collections::HashSet;

pub const MAX_INVITES_PER_REQUEST: usize = 50;
pub const DAILY_INVITE_CAP: i64 = 100;
pub const MAX_TEAM_NAME: usize = 80;
pub const MAX_TEAMS_PER_ORG: usize = 100;
pub const MAX_TEAM_MEMBERS: usize = 500;

/* ------------------------------------------------------------------- roles */

pub fn rank(role: &str) -> u8 {
    match role {
        "owner" => 4,
        "admin" => 3,
        "member" => 2,
        "viewer" => 1,
        _ => 0,
    }
}

/// Owners and admins run the organisation's people.
pub fn can_manage(role: &str) -> bool {
    matches!(role, "owner" | "admin")
}

/// A role the API accepts when INVITING or CHANGING someone (never "owner": ownership is not handed out by an invitation).
pub fn parse_assignable(raw: &str) -> Option<&'static str> {
    match raw.trim().to_lowercase().as_str() {
        "admin" => Some("admin"),
        "member" | "" => Some("member"),
        "viewer" => Some("viewer"),
        _ => None,
    }
}

/// Owner can hand out every assignable role; an admin only roles below admin (no creating more admins).
pub fn can_assign(actor: &str, new_role: &str) -> bool {
    match actor {
        "owner" => matches!(new_role, "admin" | "member" | "viewer"),
        "admin" => matches!(new_role, "member" | "viewer"),
        _ => false,
    }
}

/// Why a change to a member is refused, or Ok. `new_role == None` means "remove from the organisation".
pub fn check_member_change(
    actor_role: &str,
    actor_user: &str,
    target_role: &str,
    target_user: &str,
    new_role: Option<&str>,
) -> Result<(), &'static str> {
    if !can_manage(actor_role) {
        return Err("not_allowed");
    }
    if actor_user == target_user {
        return Err("cannot_edit_self");
    }
    if target_role == "owner" {
        return Err("owner_is_fixed");
    }
    // an admin can look after members and viewers; only the owner touches other admins
    if target_role == "admin" && actor_role != "owner" {
        return Err("not_allowed");
    }
    if let Some(r) = new_role {
        if !can_assign(actor_role, r) {
            return Err("role_not_allowed");
        }
    }
    Ok(())
}

/* ------------------------------------------------------------------ e-mail */

pub fn norm_email(s: &str) -> String {
    s.trim().to_lowercase()
}

/// Strict, boring check. Header-injection characters can never pass.
pub fn valid_email(s: &str) -> bool {
    let s = s.trim();
    if s.len() < 6 || s.len() > 254 {
        return false;
    }
    let mut parts = s.split('@');
    let (Some(local), Some(domain), None) = (parts.next(), parts.next(), parts.next()) else {
        return false;
    };
    if local.is_empty() || local.len() > 64 || domain.len() < 4 {
        return false;
    }
    let ok_local = local
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || "!#$%&'*+-/=?^_`{|}~.".contains(c))
        && !local.starts_with('.')
        && !local.ends_with('.')
        && !local.contains("..");
    if !ok_local || !domain.contains('.') {
        return false;
    }
    let labels: Vec<&str> = domain.split('.').collect();
    labels.iter().all(|l| {
        !l.is_empty()
            && l.len() <= 63
            && !l.starts_with('-')
            && !l.ends_with('-')
            && l.chars().all(|c| c.is_ascii_alphanumeric() || c == '-')
    }) && labels
        .last()
        .map(|t| t.len() >= 2 && t.chars().all(|c| c.is_ascii_alphabetic()))
        .unwrap_or(false)
}

#[derive(Debug, Default, PartialEq)]
pub struct InvitePlan {
    /// never invited before (no pending invitation): a new invitation row + e-mail
    pub fresh: Vec<String>,
    /// a pending invitation exists: same link, new expiry, e-mail again
    pub resend: Vec<String>,
    pub already_member: Vec<String>,
    pub invalid: usize,
    pub duplicate: usize,
    /// valid addresses beyond MAX_INVITES_PER_REQUEST — told to the caller, never silently dropped
    pub over_cap: usize,
}

/// Turns what the browser typed into exactly what will be done. `members` and `pending` hold lower-case addresses.
pub fn plan_invites(
    raw: &[String],
    members: &HashSet<String>,
    pending: &HashSet<String>,
) -> InvitePlan {
    let mut plan = InvitePlan::default();
    let mut seen: HashSet<String> = HashSet::new();
    for r in raw {
        let e = norm_email(r);
        if !valid_email(&e) {
            plan.invalid += 1;
            continue;
        }
        if !seen.insert(e.clone()) {
            plan.duplicate += 1;
            continue;
        }
        if members.contains(&e) {
            plan.already_member.push(e);
            continue;
        }
        if plan.fresh.len() + plan.resend.len() >= MAX_INVITES_PER_REQUEST {
            plan.over_cap += 1;
            continue;
        }
        if pending.contains(&e) {
            plan.resend.push(e);
        } else {
            plan.fresh.push(e);
        }
    }
    plan
}

/* ------------------------------------------------------------------- teams */

/// "  Customer   Support " -> Some("Customer Support"); control characters become spaces; 1..=80 chars.
pub fn clean_team_name(raw: &str) -> Option<String> {
    let t: String = raw
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect();
    let t = t.split_whitespace().collect::<Vec<_>>().join(" ");
    let t: String = t.chars().take(MAX_TEAM_NAME).collect();
    if t.is_empty() {
        None
    } else {
        Some(t)
    }
}

pub fn slugify(name: &str) -> String {
    let mut out = String::new();
    let mut dash = false;
    for c in name.chars() {
        if c.is_ascii_alphanumeric() {
            out.push(c.to_ascii_lowercase());
            dash = false;
        } else if !dash && !out.is_empty() {
            out.push('-');
            dash = true;
        }
    }
    let out = out.trim_end_matches('-').to_string();
    let out: String = out.chars().take(40).collect();
    let out = out.trim_end_matches('-').to_string();
    if out.is_empty() {
        "team".to_string()
    } else {
        out
    }
}

/// `support`, then `support-2`, `support-3` ... never a clash inside one organisation.
pub fn unique_slug(base: &str, taken: &HashSet<String>) -> String {
    if !taken.contains(base) {
        return base.to_string();
    }
    let mut n = 2;
    loop {
        let c = format!("{}-{}", base, n);
        if !taken.contains(&c) {
            return c;
        }
        n += 1;
    }
}

/// Uuid shape only (8-4-4-4-12 hex). Anything else never reaches a PostgREST filter.
pub fn is_uuid(s: &str) -> bool {
    let b = s.as_bytes();
    if b.len() != 36 {
        return false;
    }
    b.iter().enumerate().all(|(i, c)| match i {
        8 | 13 | 18 | 23 => *c == b'-',
        _ => c.is_ascii_hexdigit(),
    })
}

/// Keeps valid, distinct uuids in order; `over` counts what was beyond the cap.
pub fn clean_uuid_list(raw: &[String], cap: usize) -> (Vec<String>, usize) {
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    let mut over = 0usize;
    for r in raw {
        let t = r.trim().to_lowercase();
        if !is_uuid(&t) || !seen.insert(t.clone()) {
            continue;
        }
        if out.len() >= cap {
            over += 1;
            continue;
        }
        out.push(t);
    }
    (out, over)
}

/* ------------------------------------------------------- PostgREST filters */

/// Percent-encode a query value (PostgREST decodes it before parsing, so list punctuation may be encoded too).
pub fn pct(v: &str) -> String {
    let mut o = String::with_capacity(v.len() + 8);
    for b in v.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'.' | b'_' | b'~' | b'@') {
            o.push(b as char);
        } else {
            o.push_str(&format!("%{:02X}", b));
        }
    }
    o
}

/// A complete, URL-safe `column=in.(...)` filter; every value is double-quoted.
pub fn in_filter(column: &str, values: &[String]) -> String {
    let inner: Vec<String> = values
        .iter()
        .map(|v| format!("\"{}\"", v.replace('\\', "\\\\").replace('"', "\\\"")))
        .collect();
    format!("{}=in.{}", column, pct(&format!("({})", inner.join(","))))
}

/// "2026-10-18T01:04:05Z" — what PostgREST wants in a timestamptz filter or body.
pub fn fmt_iso(epoch: i64) -> String {
    let days = epoch.div_euclid(86400);
    let rem = epoch.rem_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z",
        y,
        m,
        d,
        rem / 3600,
        rem % 3600 / 60,
        rem % 60
    )
}

/// Epoch seconds from a Postgres/PostgREST timestamp ("2026-10-18T01:04:05+00:00", "...Z", "2026-10-18 01:04:05.123+00").
pub fn parse_ts(s: &str) -> Option<i64> {
    let s = s.trim();
    let b = s.as_bytes();
    if b.len() < 19 || b[4] != b'-' || b[7] != b'-' || !(b[10] == b'T' || b[10] == b' ') {
        return None;
    }
    let num = |a: usize, z: usize| -> Option<i64> { s.get(a..z)?.parse::<i64>().ok() };
    let (y, mo, d, h, mi, se) = (
        num(0, 4)?,
        num(5, 7)?,
        num(8, 10)?,
        num(11, 13)?,
        num(14, 16)?,
        num(17, 19)?,
    );
    if !(1..=12).contains(&mo) || !(1..=31).contains(&d) || h > 23 || mi > 59 || se > 60 {
        return None;
    }
    // offset after optional fractional seconds
    let mut rest = &s[19..];
    if rest.starts_with('.') {
        let n = rest[1..].chars().take_while(|c| c.is_ascii_digit()).count();
        rest = &rest[1 + n..];
    }
    let off = if rest.is_empty() || rest == "Z" || rest == "z" {
        0
    } else {
        let sign = if rest.starts_with('-') {
            -1
        } else if rest.starts_with('+') {
            1
        } else {
            return None;
        };
        let digits: String = rest[1..].chars().filter(|c| c.is_ascii_digit()).collect();
        let (oh, om) = match digits.len() {
            2 => (digits.parse::<i64>().ok()?, 0),
            4 => (
                digits[..2].parse::<i64>().ok()?,
                digits[2..].parse::<i64>().ok()?,
            ),
            _ => return None,
        };
        sign * (oh * 3600 + om * 60)
    };
    Some(days_from_civil(y, mo as u32, d as u32) * 86400 + h * 3600 + mi * 60 + se - off)
}

fn days_from_civil(y: i64, m: u32, d: u32) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let mp = (m as i64 + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d as i64 - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe - 719468
}

/* -------------------------------------------------------------- the mail */

const B64: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

pub fn base64(data: &[u8]) -> String {
    let mut o = String::with_capacity(data.len() * 4 / 3 + 4);
    for ch in data.chunks(3) {
        let b = [ch[0], *ch.get(1).unwrap_or(&0), *ch.get(2).unwrap_or(&0)];
        let n = ((b[0] as u32) << 16) | ((b[1] as u32) << 8) | b[2] as u32;
        o.push(B64[(n >> 18) as usize & 63] as char);
        o.push(B64[(n >> 12) as usize & 63] as char);
        o.push(if ch.len() > 1 {
            B64[(n >> 6) as usize & 63] as char
        } else {
            '='
        });
        o.push(if ch.len() > 2 {
            B64[n as usize & 63] as char
        } else {
            '='
        });
    }
    o
}

/// base64 for a MIME body: 76-char lines, CRLF.
pub fn base64_mime(data: &[u8]) -> String {
    let flat = base64(data);
    let mut o = String::with_capacity(flat.len() + flat.len() / 76 * 2 + 2);
    for chunk in flat.as_bytes().chunks(76) {
        o.push_str(std::str::from_utf8(chunk).unwrap_or(""));
        o.push_str("\r\n");
    }
    o
}

/// No CR/LF/NUL/control character can ever reach a header or a display name.
pub fn clean_line(s: &str, max: usize) -> String {
    let t: String = s
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect();
    let t = t.split_whitespace().collect::<Vec<_>>().join(" ");
    t.chars().take(max).collect()
}

/// RFC 2047 encoded-word for a header value that is not pure ASCII.
pub fn encode_header(s: &str) -> String {
    let t = clean_line(s, 300);
    if t.is_ascii() {
        return t;
    }
    let mut words: Vec<String> = Vec::new();
    let mut cur = String::new();
    for c in t.chars() {
        if cur.len() + c.len_utf8() > 36 {
            words.push(format!("=?UTF-8?B?{}?=", base64(cur.as_bytes())));
            cur.clear();
        }
        cur.push(c);
    }
    if !cur.is_empty() {
        words.push(format!("=?UTF-8?B?{}?=", base64(cur.as_bytes())));
    }
    words.join("\r\n ")
}

pub fn html_escape(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 8);
    for c in s.chars() {
        match c {
            '&' => o.push_str("&amp;"),
            '<' => o.push_str("&lt;"),
            '>' => o.push_str("&gt;"),
            '"' => o.push_str("&quot;"),
            '\'' => o.push_str("&#39;"),
            _ => o.push(c),
        }
    }
    o
}

/// RFC 5321 §4.5.2 — a line that starts with '.' gets one more '.', and every line ends with CRLF.
pub fn dot_stuff(data: &str) -> String {
    let mut out = String::with_capacity(data.len() + 16);
    for line in data.replace("\r\n", "\n").split('\n') {
        if line.starts_with('.') {
            out.push('.');
        }
        out.push_str(line);
        out.push_str("\r\n");
    }
    if data.ends_with('\n') && out.ends_with("\r\n\r\n") {
        out.truncate(out.len() - 2);
    }
    out
}

/// Final reply code of a (possibly multi-line) SMTP reply block; None while the reply is incomplete.
pub fn smtp_reply_code(block: &str) -> Option<u16> {
    let last = block
        .trim_end_matches(['\r', '\n'])
        .rsplit('\n')
        .next()?
        .trim_end_matches('\r');
    if last.len() < 3 || !last.as_bytes()[..3].iter().all(|b| b.is_ascii_digit()) {
        return None;
    }
    if last.len() > 3 && last.as_bytes()[3] == b'-' {
        return None;
    }
    last[..3].parse().ok()
}

const MON: [&str; 12] = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];
const DOW: [&str; 7] = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"];

fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}

/// "Tue, 20 Oct 2026 14:00:00 +0000"
pub fn fmt_rfc2822(epoch: i64) -> String {
    let days = epoch.div_euclid(86400);
    let rem = epoch.rem_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    format!(
        "{}, {} {} {} {:02}:{:02}:{:02} +0000",
        DOW[days.rem_euclid(7) as usize],
        d,
        MON[(m - 1) as usize],
        y,
        rem / 3600,
        rem % 3600 / 60,
        rem % 60
    )
}

/// "Wed 28 Oct 2026" for the expiry line of the mail.
pub fn fmt_day(epoch: i64) -> String {
    let days = epoch.div_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    format!(
        "{} {} {} {}",
        DOW[days.rem_euclid(7) as usize],
        d,
        MON[(m - 1) as usize],
        y
    )
}

pub fn role_phrase(role: &str) -> &'static str {
    match role {
        "admin" => "an admin (manages people, domains and addresses)",
        "viewer" => "a viewer (read-only)",
        _ => "a member",
    }
}

pub struct Invite<'a> {
    pub org_name: &'a str,
    pub inviter: &'a str,
    pub role: &'a str,
    pub to: &'a str,
    pub link: &'a str,
    pub expires_epoch: i64,
}

pub fn invite_subject(i: &Invite) -> String {
    format!(
        "{} invited you to {} on ANEXOMAIL",
        clean_line(i.inviter, 80),
        clean_line(i.org_name, 80)
    )
}

pub fn invite_text(i: &Invite) -> String {
    format!(
        "{inviter} invited you to join {org} on ANEXOMAIL as {role}.\r\n\r\n\
         Open this link, sign in (or create your account) with {to}, then press \"Join\":\r\n{link}\r\n\r\n\
         The invitation works until {day}. If you were not expecting it, ignore this e-mail — nothing happens until you press Join.\r\n\r\n\
         ANEXOMAIL\r\n",
        inviter = clean_line(i.inviter, 80),
        org = clean_line(i.org_name, 80),
        role = role_phrase(i.role),
        to = clean_line(i.to, 254),
        link = i.link,
        day = fmt_day(i.expires_epoch)
    )
}

pub fn invite_html(i: &Invite) -> String {
    format!(
        "<!doctype html><html><body style=\"margin:0;padding:24px;background:#f4f6f8;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#0b1220\">\
         <div style=\"max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;padding:28px\">\
         <p style=\"margin:0 0 6px;font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:#5b6b7f\">ANEXOMAIL</p>\
         <h1 style=\"margin:0 0 14px;font-size:20px;line-height:1.3\">{inviter} invited you to {org}</h1>\
         <p style=\"margin:0 0 18px;font-size:15px;line-height:1.5\">You will join as {role}. Sign in (or create your account) with <b>{to}</b>, then press <b>Join</b>.</p>\
         <p style=\"margin:0 0 18px\"><a href=\"{link}\" style=\"display:inline-block;background:#0b1220;color:#ffffff;text-decoration:none;font-weight:700;font-size:15px;padding:12px 22px;border-radius:10px\">Open invitation</a></p>\
         <p style=\"margin:0;font-size:12px;line-height:1.5;color:#5b6b7f\">Works until {day}. Nothing happens until you press Join — if you were not expecting this, ignore it.<br>If the button does not open, paste this link: {link}</p>\
         </div></body></html>",
        inviter = html_escape(&clean_line(i.inviter, 80)),
        org = html_escape(&clean_line(i.org_name, 80)),
        role = html_escape(role_phrase(i.role)),
        to = html_escape(&clean_line(i.to, 254)),
        link = html_escape(i.link),
        day = fmt_day(i.expires_epoch)
    )
}

/// The whole message, ready for SMTP DATA. Envelope sender is `from` (a system address); replies go to the inviter.
pub fn build_invite_mail(
    i: &Invite,
    from_name: &str,
    from: &str,
    reply_to: &str,
    message_id: &str,
    now: i64,
) -> String {
    let seed: String = message_id
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .take(40)
        .collect();
    let alt = format!("axt_{}", seed);
    let mut m = String::new();
    m.push_str(&format!(
        "From: {} <{}>\r\n",
        encode_header(&format!("{} via ANEXOMAIL", clean_line(from_name, 80))),
        from
    ));
    m.push_str(&format!("To: <{}>\r\n", i.to));
    m.push_str(&format!("Reply-To: <{}>\r\n", reply_to));
    m.push_str(&format!(
        "Subject: {}\r\n",
        encode_header(&invite_subject(i))
    ));
    m.push_str(&format!(
        "Message-ID: <{}>\r\n",
        clean_line(message_id, 120).replace(' ', "")
    ));
    m.push_str(&format!("Date: {}\r\n", fmt_rfc2822(now)));
    m.push_str("MIME-Version: 1.0\r\n");
    m.push_str("X-ANEXOMAIL-Mail: team-invite\r\n");
    m.push_str("Auto-Submitted: auto-generated\r\n");
    m.push_str(&format!(
        "Content-Type: multipart/alternative; boundary=\"{}\"\r\n\r\n",
        alt
    ));
    m.push_str(&format!(
        "--{}\r\nContent-Type: text/plain; charset=\"UTF-8\"\r\nContent-Transfer-Encoding: base64\r\n\r\n{}",
        alt,
        base64_mime(invite_text(i).as_bytes())
    ));
    m.push_str(&format!(
        "--{}\r\nContent-Type: text/html; charset=\"UTF-8\"\r\nContent-Transfer-Encoding: base64\r\n\r\n{}",
        alt,
        base64_mime(invite_html(i).as_bytes())
    ));
    m.push_str(&format!("--{}--\r\n", alt));
    m
}

/* ---------------------------------------------------------------- tests */

#[cfg(test)]
mod tests {
    use super::*;

    fn set(v: &[&str]) -> HashSet<String> {
        v.iter().map(|s| s.to_string()).collect()
    }
    fn strs(v: &[&str]) -> Vec<String> {
        v.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn invited_role_is_parsed_not_assumed() {
        assert_eq!(parse_assignable("Admin"), Some("admin"));
        assert_eq!(parse_assignable(" viewer "), Some("viewer"));
        assert_eq!(parse_assignable(""), Some("member"));
        // the old bug: whatever the browser sent became "member"; and "owner" must never be grantable
        assert_eq!(parse_assignable("owner"), None);
        assert_eq!(parse_assignable("root"), None);
    }

    #[test]
    fn who_may_assign_what() {
        assert!(can_assign("owner", "admin"));
        assert!(can_assign("owner", "viewer"));
        assert!(can_assign("admin", "member"));
        assert!(!can_assign("admin", "admin")); // an admin cannot mint more admins
        assert!(!can_assign("member", "viewer"));
        assert!(!can_assign("viewer", "member"));
        assert!(!can_assign("owner", "owner"));
    }

    #[test]
    fn member_changes_follow_the_rules() {
        // owner edits a member
        assert_eq!(
            check_member_change("owner", "u1", "member", "u2", Some("admin")),
            Ok(())
        );
        assert_eq!(
            check_member_change("owner", "u1", "admin", "u2", None),
            Ok(())
        );
        // nobody edits or removes an owner, nobody edits themselves
        assert_eq!(
            check_member_change("owner", "u1", "owner", "u2", None),
            Err("owner_is_fixed")
        );
        assert_eq!(
            check_member_change("admin", "u1", "owner", "u2", Some("member")),
            Err("owner_is_fixed")
        );
        assert_eq!(
            check_member_change("admin", "u1", "admin", "u1", Some("member")),
            Err("cannot_edit_self")
        );
        // an admin looks after members/viewers but not other admins, and cannot promote
        assert_eq!(
            check_member_change("admin", "u1", "member", "u2", Some("viewer")),
            Ok(())
        );
        assert_eq!(
            check_member_change("admin", "u1", "member", "u2", None),
            Ok(())
        );
        assert_eq!(
            check_member_change("admin", "u1", "admin", "u2", Some("member")),
            Err("not_allowed")
        );
        assert_eq!(
            check_member_change("admin", "u1", "member", "u2", Some("admin")),
            Err("role_not_allowed")
        );
        // members and viewers manage nobody
        assert_eq!(
            check_member_change("member", "u1", "viewer", "u2", None),
            Err("not_allowed")
        );
        assert_eq!(
            check_member_change("viewer", "u1", "member", "u2", Some("viewer")),
            Err("not_allowed")
        );
    }

    #[test]
    fn emails_are_checked_and_never_inject_headers() {
        assert!(valid_email("anna@example.com"));
        assert!(valid_email("a.b+tag@sub.example.co.uk"));
        assert!(!valid_email("anna@example"));
        assert!(!valid_email("anna example@x.com"));
        assert!(!valid_email("anna@x.com\r\nBcc: evil@x.com"));
        assert!(!valid_email("a..b@x.com"));
        assert!(!valid_email("@x.com"));
        assert!(!valid_email(&format!("{}@x.com", "a".repeat(70))));
    }

    #[test]
    fn plan_splits_fresh_resend_member_and_noise() {
        let p = plan_invites(
            &strs(&[
                "New@Example.com",
                "new@example.com",
                "again@example.com",
                "me@example.com",
                "not an email",
                "",
                "second@example.com",
            ]),
            &set(&["me@example.com"]),
            &set(&["again@example.com"]),
        );
        assert_eq!(p.fresh, strs(&["new@example.com", "second@example.com"]));
        assert_eq!(p.resend, strs(&["again@example.com"]));
        assert_eq!(p.already_member, strs(&["me@example.com"]));
        assert_eq!(p.invalid, 2);
        assert_eq!(p.duplicate, 1);
        assert_eq!(p.over_cap, 0);
    }

    #[test]
    fn plan_caps_a_single_request_and_says_so() {
        let many: Vec<String> = (0..70).map(|i| format!("p{}@example.com", i)).collect();
        let p = plan_invites(&many, &set(&[]), &set(&[]));
        assert_eq!(p.fresh.len(), MAX_INVITES_PER_REQUEST);
        assert_eq!(p.over_cap, 20);
    }

    #[test]
    fn team_names_and_slugs() {
        assert_eq!(
            clean_team_name("  Customer \n  Support "),
            Some("Customer Support".to_string())
        );
        assert_eq!(clean_team_name("   \t "), None);
        assert_eq!(
            clean_team_name(&"x".repeat(200)).unwrap().chars().count(),
            MAX_TEAM_NAME
        );
        assert_eq!(slugify("Customer Support!"), "customer-support");
        assert_eq!(slugify("***"), "team");
        assert_eq!(slugify("Ünïcode Team"), "n-code-team");
        assert_eq!(
            unique_slug("support", &set(&["support", "support-2"])),
            "support-3"
        );
        assert_eq!(unique_slug("sales", &set(&["support"])), "sales");
    }

    #[test]
    fn uuids_only_reach_filters() {
        assert!(is_uuid("123e4567-e89b-12d3-a456-426614174000"));
        assert!(!is_uuid("123e4567-e89b-12d3-a456-42661417400"));
        assert!(!is_uuid("123e4567-e89b-12d3-a456-42661417400g"));
        assert!(!is_uuid("x),or=(id.neq.0"));
        let (ids, over) = clean_uuid_list(
            &strs(&[
                "123E4567-E89B-12D3-A456-426614174000",
                "123e4567-e89b-12d3-a456-426614174000",
                "nope",
                "223e4567-e89b-12d3-a456-426614174000",
                "323e4567-e89b-12d3-a456-426614174000",
            ]),
            2,
        );
        assert_eq!(ids.len(), 2);
        assert_eq!(over, 1);
    }

    #[test]
    fn filters_and_timestamps() {
        assert_eq!(pct("a b+c@x.io"), "a%20b%2Bc@x.io");
        assert_eq!(
            in_filter("email", &strs(&["a@x.io", "we\"ird@x.io"])),
            "email=in.%28%22a@x.io%22%2C%22we%5C%22ird@x.io%22%29"
        );
        assert_eq!(fmt_iso(1_792_285_445), "2026-10-18T01:04:05Z");
        assert_eq!(parse_ts("2026-10-18T01:04:05Z"), Some(1_792_285_445));
        assert_eq!(
            parse_ts("2026-10-18 06:04:05.123456+05:00"),
            Some(1_792_285_445)
        );
        assert_eq!(parse_ts("2026-10-18T01:04:05+00"), Some(1_792_285_445));
        assert_eq!(parse_ts("yesterday"), None);
        assert_eq!(parse_ts(&fmt_iso(0)), Some(0));
    }

    #[test]
    fn dates_are_right() {
        // 2026-10-18 00:00:00 UTC was a Sunday
        assert_eq!(fmt_day(1_792_281_600), "Sun 18 Oct 2026");
        assert_eq!(
            fmt_rfc2822(1_792_285_445),
            "Sun, 18 Oct 2026 01:04:05 +0000"
        );
        assert_eq!(fmt_rfc2822(0), "Thu, 1 Jan 1970 00:00:00 +0000");
    }

    fn sample<'a>(inviter: &'a str, org: &'a str) -> Invite<'a> {
        Invite {
            org_name: org,
            inviter,
            role: "admin",
            to: "guest@example.com",
            link: "https://anexomail.com/join?t=123e4567-e89b-12d3-a456-426614174000",
            expires_epoch: 1_793_491_200,
        }
    }

    #[test]
    fn invitation_mail_is_safe_and_complete() {
        let i = sample("Anna <b>Bold</b>\r\nBcc: evil@x.com", "Acme \"Ltd\"");
        let raw = build_invite_mail(
            &i,
            "Anna",
            "invites@anexomail.com",
            "anna@acme.com",
            "t.1@anexomail.com",
            1_792_285_445,
        );
        // headers: exactly the ones we wrote, no injected Bcc
        let head = raw.split("\r\n\r\n").next().unwrap();
        assert!(!head.to_lowercase().contains("\r\nbcc:"));
        assert!(head.contains("To: <guest@example.com>"));
        assert!(head.contains("Reply-To: <anna@acme.com>"));
        assert!(head.contains("Date: Sun, 18 Oct 2026 01:04:05 +0000"));
        assert!(head.contains("Auto-Submitted: auto-generated"));
        // body parts are base64 of the text/html we generate
        let html = invite_html(&i);
        assert!(!html.contains("<b>Bold</b>")); // inviter name is escaped
        assert!(html.contains("&lt;b&gt;Bold&lt;/b&gt;"));
        assert!(html.contains("https://anexomail.com/join?t=123e4567-e89b-12d3-a456-426614174000"));
        assert!(invite_text(&i).contains("Join"));
        assert!(invite_text(&i).contains("an admin"));
        assert!(raw.contains("--axt_t1anexomailcom--\r\n"));
        // every physical line is short enough for SMTP
        assert!(raw.split("\r\n").all(|l| l.len() <= 998));
    }

    #[test]
    fn non_ascii_names_are_encoded() {
        let i = sample("Zoë Åström", "Café Société");
        assert!(invite_subject(&i).contains("Zoë"));
        let raw = build_invite_mail(
            &i,
            "Zoë Åström",
            "invites@anexomail.com",
            "z@acme.com",
            "m.2@anexomail.com",
            0,
        );
        let head = raw.split("\r\n\r\n").next().unwrap();
        assert!(head.is_ascii());
        assert!(head.contains("=?UTF-8?B?"));
    }

    #[test]
    fn smtp_helpers() {
        assert_eq!(smtp_reply_code("250-a\r\n250 ok\r\n"), Some(250));
        assert_eq!(smtp_reply_code("250-a\r\n"), None);
        assert_eq!(dot_stuff(".hidden\r\nline\r\n"), "..hidden\r\nline\r\n");
        assert_eq!(base64(b"Man"), "TWFu");
        assert_eq!(base64(b"Ma"), "TWE=");
    }
}
