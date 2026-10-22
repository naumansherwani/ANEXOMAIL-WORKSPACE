//! overlap_core — Overlap Matrix (calendar #4b / World Clock W1): pure, std-only logic. No I/O, no clock (caller passes `now`).
//!
//! One question: "if we meet at time T, how is it for each person?" Answer per person, per slot (15/30/60 min grid, UTC-aligned):
//!   w  working hours, free            -> GREEN
//!   u  schedule unknown, local 08-21  -> GREEN (assumed; UI marks it, we never pretend it is their real schedule)
//!   b  inside working hours but busy  -> AMBER (free/busy only — never the meeting's content)
//!   o  out-of-office day              -> AMBER
//!   f  outside working hours, daytime -> AMBER
//!   n  night (local 22:00-07:00)      -> RED   (unless their own working hours cover it)
//!   x  zone unknown                   -> neutral (not counted)
//! Honest numbers only: `assess` reports MINUTES of a proposed meeting outside someone's own working hours and how long their
//! day becomes — a count, never an invented "quality" percentage.
//!
//! Privacy: input is a self-declared schedule (work hours + OOO dates) and busy intervals. No activity, location or mail data exists here.
//! The database (E62) is the wall that decides WHO may be asked about; this file only classifies what it is handed.
//! Tests run on the server by the installer (std-only, `rustc --test overlap_core.rs`); cal_core.rs sits next to it.
#![allow(dead_code)]

#[cfg(test)]
#[path = "cal_core.rs"]
mod cal_core;
#[cfg(not(test))]
use crate::cal_core;

use cal_core::recur::Tz;
use cal_core::{self as cal, Interval};

pub const MAX_PEOPLE: usize = 12;
pub const MAX_DAYS: i64 = 7;
pub const NIGHT_FROM_MIN: i64 = 22 * 60;
pub const NIGHT_TO_MIN: i64 = 7 * 60;
pub const GUEST_DAY_FROM_MIN: i64 = 8 * 60;
pub const GUEST_DAY_TO_MIN: i64 = 21 * 60;

/* ------------------------------------------------------------ working hours */

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Day {
    pub on: bool,
    /// minutes after local midnight
    pub start: i64,
    pub end: i64,
}

/// Index 0 = Monday ... 6 = Sunday (same as the calendar settings and book_core).
pub type Week = [Day; 7];

/// "09:30" -> 570. Same rule as book_core::parse_hhmm.
pub fn parse_hhmm(s: &str) -> Option<i64> {
    let (h, m) = s.split_once(':')?;
    let (h, m): (i64, i64) = (h.trim().parse().ok()?, m.trim().get(..2).unwrap_or(m.trim()).parse().ok()?);
    if (0..=24).contains(&h) && (0..60).contains(&m) && !(h == 24 && m > 0) {
        Some(h * 60 + m)
    } else {
        None
    }
}

/* ------------------------------------------------------------------ person */

pub struct Person<'a> {
    /// None = zone unknown (cells are 'x').
    pub tz: Option<&'a Tz>,
    /// None = the person never wrote a schedule (guest, or member who did not): classified by day/night only.
    pub week: Option<Week>,
    /// inclusive "YYYY-MM-DD" ranges (only meaningful with a known schedule)
    pub ooo: &'a [(String, String)],
    /// sorted + merged busy intervals (UTC epoch seconds)
    pub busy: &'a [Interval],
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Zone {
    Green,
    Amber,
    Red,
    Unknown,
}

pub fn zone(c: char) -> Zone {
    match c {
        'w' | 'u' => Zone::Green,
        'b' | 'o' | 'f' => Zone::Amber,
        'n' => Zone::Red,
        _ => Zone::Unknown,
    }
}

fn date_string(day: i64) -> String {
    let (y, m, d) = cal::civil_from_days(day);
    format!("{:04}-{:02}-{:02}", y, m, d)
}

fn is_night(minute: i64) -> bool {
    minute >= NIGHT_FROM_MIN || minute < NIGHT_TO_MIN
}

fn overlaps(busy: &[Interval], s: i64, e: i64) -> bool {
    // busy is sorted by start: stop once an interval starts at/after the slot end
    for i in busy {
        if i.start >= e {
            break;
        }
        if i.end > s {
            return true;
        }
    }
    false
}

/// Cell for the slot [t, t + slot_min). `t` is a UTC epoch second.
pub fn cell(p: &Person, t: i64, slot_min: i64) -> char {
    let tz = match p.tz {
        Some(z) => z,
        None => return 'x',
    };
    let local = tz.to_local(t);
    let day = local.div_euclid(86_400);
    let minute = local.rem_euclid(86_400) / 60;
    let night = is_night(minute);
    let week = match &p.week {
        Some(w) => w,
        None => {
            // unknown schedule: only the clock on their wall tells us anything
            return if night {
                'n'
            } else if minute >= GUEST_DAY_FROM_MIN && minute + slot_min <= GUEST_DAY_TO_MIN {
                'u'
            } else {
                'f'
            };
        }
    };
    let date = date_string(day);
    if p.ooo.iter().any(|(a, b)| a.as_str() <= date.as_str() && date.as_str() <= b.as_str()) {
        return 'o';
    }
    let w = week[(day + 3).rem_euclid(7) as usize];
    if w.on && w.end > w.start && minute >= w.start && minute + slot_min <= w.end {
        return if overlaps(p.busy, t, t + slot_min * 60) { 'b' } else { 'w' };
    }
    if night {
        'n'
    } else {
        'f'
    }
}

/* ------------------------------------------------------------------ matrix */

#[derive(Clone, Copy, Debug)]
pub struct Grid {
    /// first slot start, UTC epoch seconds (must sit on the grid)
    pub from: i64,
    pub slots: usize,
    pub slot_min: i64,
}

/// Grid for `days` days starting at the first `slot_min` boundary at/after `from`. None for out-of-range input.
pub fn grid(from: i64, days: i64, slot_min: i64) -> Option<Grid> {
    if !matches!(slot_min, 15 | 30 | 60) || !(1..=MAX_DAYS).contains(&days) {
        return None;
    }
    let step = slot_min * 60;
    let start = (from + step - 1).div_euclid(step) * step;
    Some(Grid { from: start, slots: (days * 24 * 60 / slot_min) as usize, slot_min })
}

/// One string per person, one char per slot.
pub fn matrix(people: &[Person], g: &Grid) -> Vec<String> {
    people
        .iter()
        .take(MAX_PEOPLE)
        .map(|p| (0..g.slots).map(|i| cell(p, g.from + i as i64 * g.slot_min * 60, g.slot_min)).collect())
        .collect()
}

/* --------------------------------------------------------------- best times */

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Window {
    pub start: i64,
    pub end: i64,
    pub red: u32,
    pub amber: u32,
}

impl Window {
    pub fn all_green(&self) -> bool {
        self.red == 0 && self.amber == 0
    }
}

/// Suggestions must be at least this far apart, so three chips are three real choices — not 9:30, 10:00, 10:30.
pub const MIN_GAP_MIN: i64 = 180;

/// Up to `limit` windows of `need_min` minutes (at least MIN_GAP_MIN apart), best first: fewest red cells, then fewest amber, then earliest.
/// Windows starting before `not_before` are skipped (never suggest the past). People with an unknown zone do not count.
pub fn best_windows(rows: &[String], g: &Grid, need_min: i64, not_before: i64, limit: usize) -> Vec<Window> {
    if rows.is_empty() || need_min < g.slot_min || need_min > 8 * 60 || limit == 0 {
        return vec![];
    }
    let n = ((need_min + g.slot_min - 1) / g.slot_min) as usize;
    if n > g.slots {
        return vec![];
    }
    let bytes: Vec<&[u8]> = rows.iter().map(|r| r.as_bytes()).collect();
    // per-slot penalties
    let mut red = vec![0u32; g.slots];
    let mut amber = vec![0u32; g.slots];
    for r in &bytes {
        for (i, ch) in r.iter().take(g.slots).enumerate() {
            match zone(*ch as char) {
                Zone::Red => red[i] += 1,
                Zone::Amber => amber[i] += 1,
                _ => {}
            }
        }
    }
    let mut all: Vec<Window> = Vec::new();
    for i in 0..=(g.slots - n) {
        let start = g.from + i as i64 * g.slot_min * 60;
        if start < not_before {
            continue;
        }
        let (r, a) = (red[i..i + n].iter().sum::<u32>(), amber[i..i + n].iter().sum::<u32>());
        all.push(Window { start, end: start + n as i64 * g.slot_min * 60, red: r, amber: a });
    }
    all.sort_by_key(|w| (w.red, w.amber, w.start));
    let mut out: Vec<Window> = Vec::new();
    for w in all {
        if out.len() >= limit {
            break;
        }
        let gap = MIN_GAP_MIN * 60;
        if out.iter().all(|o| w.end + gap <= o.start || w.start >= o.end + gap) {
            out.push(w);
        }
    }
    out
}

/* ----------------------------------------------------------------- assess */

/// What a proposed meeting [start, end) means for ONE person, as plain counts.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Assess {
    pub zone: Zone,
    /// meeting minutes outside their own working hours (all of it on a day off / OOO day). None when they wrote no schedule.
    pub outside_min: Option<i64>,
    /// length of that person's working day once the meeting is in it (first of window-start/meeting-start to last of window-end/meeting-end).
    pub day_len_min: Option<i64>,
    /// how much longer that day is than their normal window. 0 when the meeting sits inside it.
    pub extra_min: Option<i64>,
    /// Focus Ring: minutes already booked (free/busy only) inside their working window on the meeting's local day. None without a schedule or on a day off.
    pub booked_min: Option<i64>,
    /// length of that working window in minutes (the ring's whole circle). None when booked_min is None.
    pub work_min: Option<i64>,
}

pub fn assess(p: &Person, start: i64, end: i64) -> Assess {
    let none = |z| Assess { zone: z, outside_min: None, day_len_min: None, extra_min: None, booked_min: None, work_min: None };
    let tz = match p.tz {
        Some(z) if end > start => z,
        _ => return none(Zone::Unknown),
    };
    let len_min = (end - start + 59) / 60;
    // worst cell the meeting touches, on a 15-minute walk
    let mut worst = Zone::Green;
    let mut t = start;
    while t < end {
        let z = zone(cell(p, t, 15.min(len_min.max(1))));
        worst = match (worst, z) {
            (Zone::Red, _) | (_, Zone::Red) => Zone::Red,
            (Zone::Amber, _) | (_, Zone::Amber) => Zone::Amber,
            (_, Zone::Unknown) => worst,
            _ => worst,
        };
        t += 900;
    }
    let week = match &p.week {
        Some(w) => w,
        None => return none(worst),
    };
    let ls = tz.to_local(start);
    let le = ls + (end - start);
    let day = ls.div_euclid(86_400);
    let date = date_string(day);
    let off_day = p.ooo.iter().any(|(a, b)| a.as_str() <= date.as_str() && date.as_str() <= b.as_str());
    let w = week[(day + 3).rem_euclid(7) as usize];
    if off_day || !w.on || w.end <= w.start {
        return Assess { zone: worst, outside_min: Some(len_min), day_len_min: Some(len_min), extra_min: Some(len_min), booked_min: None, work_min: None };
    }
    let (ws, we) = (day * 86_400 + w.start * 60, day * 86_400 + w.end * 60);
    let inside = (le.min(we) - ls.max(ws)).max(0);
    let outside = ((le - ls) - inside + 59) / 60;
    let span = le.max(we) - ls.min(ws);
    // booked minutes inside the working window (busy is sorted + merged, so a plain clipped sum is exact)
    let off = ls - start; // local - utc
    let (wu_s, wu_e) = (ws - off, we - off);
    let booked: i64 = p.busy.iter().map(|i| (i.end.min(wu_e) - i.start.max(wu_s)).max(0)).sum::<i64>() / 60;
    Assess {
        booked_min: Some(booked),
        work_min: Some((we - ws) / 60),
        zone: worst,
        outside_min: Some(outside),
        day_len_min: Some(span / 60),
        extra_min: Some((span - (we - ws)) / 60),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const H: i64 = 3600;

    fn fixed(hours: i32) -> Tz {
        Tz::Fixed(hours * 3600)
    }
    fn day0(y: i64, m: u32, d: u32) -> i64 {
        cal::days_from_civil(y, m, d) * 86_400
    }
    fn office() -> Week {
        let wd = Day { on: true, start: 9 * 60, end: 17 * 60 };
        let we = Day { on: false, start: 9 * 60, end: 17 * 60 };
        [wd, wd, wd, wd, wd, we, we]
    }
    fn p<'a>(tz: Option<&'a Tz>, week: Option<Week>, ooo: &'a [(String, String)], busy: &'a [Interval]) -> Person<'a> {
        Person { tz, week, ooo, busy }
    }

    #[test]
    fn hhmm_matches_book_core() {
        assert_eq!(parse_hhmm("09:30"), Some(570));
        assert_eq!(parse_hhmm("24:00"), Some(1440));
        assert_eq!(parse_hhmm("24:01"), None);
        assert_eq!(parse_hhmm("9"), None);
        assert_eq!(parse_hhmm("12:60"), None);
    }

    // Tue 27 Oct 2026 (a Tuesday). UTC 04:00 = Karachi 09:00 = Tokyo 13:00 = Zurich 05:00(+1h) ...
    #[test]
    fn green_amber_red_by_zone() {
        let t = day0(2026, 10, 27) + 4 * H; // 04:00 UTC
        let khi = fixed(5);
        let tokyo = fixed(9);
        let ny = fixed(-4);
        let a = p(Some(&khi), Some(office()), &[], &[]);
        let b = p(Some(&tokyo), Some(office()), &[], &[]);
        let c = p(Some(&ny), Some(office()), &[], &[]);
        assert_eq!(cell(&a, t, 30), 'w', "Karachi 09:00 working");
        assert_eq!(cell(&b, t, 30), 'w', "Tokyo 13:00 working");
        assert_eq!(cell(&c, t, 30), 'n', "New York 00:00 night");
        let t2 = t + 6 * H; // 10:00 UTC: Karachi 15:00 w, Tokyo 19:00 f, NY 06:00 n
        assert_eq!((cell(&a, t2, 30), cell(&b, t2, 30), cell(&c, t2, 30)), ('w', 'f', 'n'));
        let t3 = t + 10 * H; // 14:00 UTC: Karachi 19:00 f, NY 10:00 w
        assert_eq!((cell(&a, t3, 30), cell(&c, t3, 30)), ('f', 'w'));
    }

    #[test]
    fn slot_must_fit_inside_working_hours() {
        let khi = fixed(5);
        let a = p(Some(&khi), Some(office()), &[], &[]);
        let t = day0(2026, 10, 27) + 11 * H + 45 * 60; // Karachi 16:45
        assert_eq!(cell(&a, t, 15), 'w');
        assert_eq!(cell(&a, t, 30), 'f', "a 30-min slot at 16:45 runs past 17:00");
    }

    #[test]
    fn weekend_is_amber_by_day_red_by_night() {
        let khi = fixed(5);
        let a = p(Some(&khi), Some(office()), &[], &[]);
        let sat = day0(2026, 10, 24); // Saturday
        assert_eq!(cell(&a, sat + 7 * H, 30), 'f', "Sat 12:00 Karachi");
        assert_eq!(cell(&a, sat + 21 * H, 30), 'n', "Sat 02:00+1 Karachi");
    }

    #[test]
    fn busy_and_ooo_are_amber() {
        let khi = fixed(5);
        let day = day0(2026, 10, 27);
        let busy = [Interval { start: day + 5 * H, end: day + 6 * H }]; // Karachi 10:00-11:00
        let ooo = vec![("2026-10-28".to_string(), "2026-10-29".to_string())];
        let a = p(Some(&khi), Some(office()), &ooo, &busy);
        assert_eq!(cell(&a, day + 5 * H, 30), 'b');
        assert_eq!(cell(&a, day + 6 * H, 30), 'w', "busy ends exactly at the slot start");
        assert_eq!(cell(&a, day + 4 * H + 30 * 60, 30), 'w', "slot ends exactly when busy starts");
        assert_eq!(cell(&a, day + 24 * H + 5 * H, 30), 'o', "Wed is out of office");
        assert_eq!(cell(&a, day + 48 * H + 5 * H, 30), 'o', "Thu too (inclusive range)");
        assert_eq!(cell(&a, day + 72 * H + 5 * H, 30), 'w', "Fri is back");
    }

    #[test]
    fn unknown_schedule_uses_the_wall_clock_only() {
        let zrh = fixed(1);
        let g = p(Some(&zrh), None, &[], &[]);
        let day = day0(2026, 10, 27);
        assert_eq!(cell(&g, day + 8 * H, 30), 'u', "09:00 Zurich");
        assert_eq!(cell(&g, day + 20 * H + 30 * 60, 30), 'f', "21:30 Zurich is past the assumed day");
        assert_eq!(cell(&g, day + 22 * H, 30), 'n', "23:00 Zurich");
        assert_eq!(cell(&g, day + 4 * H, 30), 'n', "05:00 Zurich");
        let nowhere = p(None, Some(office()), &[], &[]);
        assert_eq!(cell(&nowhere, day, 30), 'x');
        assert_eq!(zone('x'), Zone::Unknown);
    }

    #[test]
    fn night_shift_working_hours_are_respected() {
        // a person whose OWN hours are 22:00-06:00 is not "night" while they work
        let khi = fixed(5);
        let d = Day { on: true, start: 22 * 60, end: 24 * 60 };
        let w: Week = [d; 7];
        let a = p(Some(&khi), Some(w), &[], &[]);
        let day = day0(2026, 10, 27);
        assert_eq!(cell(&a, day + 17 * H, 30), 'w', "22:00 Karachi inside own window");
        assert_eq!(cell(&a, day + 20 * H, 30), 'n', "01:00 Karachi next day: outside own window and night");
    }

    #[test]
    fn dst_zone_is_followed() {
        // Europe/Zurich is UTC+2 until 25 Oct 2026, UTC+1 after. 05:30 UTC is 07:30 local on 20 Oct ('f': day) but 06:30 local on 27 Oct ('n': night).
        let z = cal_core::recur::load_tz("Europe/Zurich", 0);
        if matches!(&*z, Tz::Fixed(_)) {
            return; // no tz database on this machine: nothing to prove here
        }
        let g = p(Some(&z), None, &[], &[]);
        assert_eq!(cell(&g, day0(2026, 10, 20) + 5 * H + 30 * 60, 30), 'f');
        assert_eq!(cell(&g, day0(2026, 10, 27) + 5 * H + 30 * 60, 30), 'n');
        assert_eq!(cell(&g, day0(2026, 10, 27) + 7 * H, 30), 'u', "08:00 local in winter");
    }

    #[test]
    fn grid_rules() {
        assert!(grid(0, 0, 30).is_none());
        assert!(grid(0, 8, 30).is_none());
        assert!(grid(0, 1, 20).is_none());
        let g = grid(1_000, 2, 30).unwrap();
        assert_eq!(g.from % 1800, 0);
        assert!(g.from >= 1_000 && g.from < 1_000 + 1800);
        assert_eq!(g.slots, 96);
        assert_eq!(grid(0, 7, 15).unwrap().slots, 672);
    }

    #[test]
    fn matrix_shape_and_cap() {
        let khi = fixed(5);
        let a = p(Some(&khi), Some(office()), &[], &[]);
        let g = grid(day0(2026, 10, 27), 1, 60).unwrap();
        let m = matrix(&[a], &g);
        assert_eq!(m.len(), 1);
        assert_eq!(m[0].len(), 24);
        let many: Vec<Person> = (0..20).map(|_| p(Some(&khi), None, &[], &[])).collect();
        assert_eq!(matrix(&many, &g).len(), MAX_PEOPLE);
    }

    // The founder's own scenario: Karachi + Zurich + Tokyo + New York.
    #[test]
    fn best_windows_prefers_all_green_then_least_bad() {
        let khi = fixed(5);
        let zrh = fixed(1);
        let tok = fixed(9);
        let day = day0(2026, 10, 27);
        let people = vec![
            p(Some(&khi), Some(office()), &[], &[]),
            p(Some(&zrh), Some(office()), &[], &[]),
            p(Some(&tok), Some(office()), &[], &[]),
        ];
        let g = grid(day, 1, 30).unwrap();
        let rows = matrix(&people, &g);
        let w = best_windows(&rows, &g, 30, day, 3);
        assert!(!w.is_empty());
        // Karachi 09-17 (04-12 UTC), Zurich 09-17 (08-16 UTC), Tokyo 09-17 (00-08 UTC): no instant works for all three
        assert!(!w[0].all_green(), "no all-green window exists across Zurich+Tokyo+Karachi");
        assert_eq!(w[0].red, 0, "but a window with nobody at night exists");
        assert!(w.windows(2).all(|p| (p[0].red, p[0].amber) <= (p[1].red, p[1].amber)), "sorted best first");
        assert!(w.iter().enumerate().all(|(i, a)| w.iter().skip(i + 1).all(|b| a.end <= b.start || b.end <= a.start)), "no overlap");
        // two people with a real overlap
        let two = vec![people.into_iter().next().unwrap(), p(Some(&zrh), Some(office()), &[], &[])];
        let rows2 = matrix(&two, &g);
        let w2 = best_windows(&rows2, &g, 60, day, 1);
        assert!(w2[0].all_green());
        assert_eq!(w2[0].start, day + 8 * H, "08:00 UTC = Karachi 13:00 = Zurich 09:00, the earliest hour both are in");
    }

    #[test]
    fn best_windows_are_spread_out() {
        let khi = fixed(5);
        let a = p(Some(&khi), Some(office()), &[], &[]);
        let day = day0(2026, 10, 27);
        let g = grid(day, 1, 30).unwrap();
        let rows = matrix(&[a], &g);
        let w = best_windows(&rows, &g, 30, day, 3);
        assert_eq!(w.len(), 3);
        for i in 0..w.len() {
            for j in (i + 1)..w.len() {
                assert!(w[i].end + MIN_GAP_MIN * 60 <= w[j].start || w[j].end + MIN_GAP_MIN * 60 <= w[i].start, "{:?} vs {:?}", w[i], w[j]);
            }
        }
    }

    #[test]
    fn best_windows_skips_the_past_and_bad_input() {
        let khi = fixed(5);
        let a = p(Some(&khi), None, &[], &[]);
        let day = day0(2026, 10, 27);
        let g = grid(day, 1, 30).unwrap();
        let rows = matrix(&[a], &g);
        let w = best_windows(&rows, &g, 30, day + 10 * H, 1);
        assert!(w[0].start >= day + 10 * H);
        assert!(best_windows(&rows, &g, 10, day, 1).is_empty(), "shorter than a slot");
        assert!(best_windows(&rows, &g, 30, day, 0).is_empty());
        assert!(best_windows(&[], &g, 30, day, 1).is_empty());
        assert!(best_windows(&rows, &g, 600, day, 1).is_empty(), "over 8 hours");
    }

    // The sentence we promise the user: "Japan's day becomes 14 hours" — a count of real minutes, not a percentage.
    #[test]
    fn assess_counts_real_minutes() {
        let tok = fixed(9);
        let a = p(Some(&tok), Some(office()), &[], &[]);
        let day = day0(2026, 10, 27);
        // 13:00-14:00 UTC = Tokyo 22:00-23:00. Window 09:00-17:00 -> day runs 09:00-23:00 = 14h, 6h longer than 8h
        let r = assess(&a, day + 13 * H, day + 14 * H);
        assert_eq!(r.outside_min, Some(60));
        assert_eq!(r.day_len_min, Some(14 * 60));
        assert_eq!(r.extra_min, Some(6 * 60));
        assert_eq!(r.zone, Zone::Red);
        // inside: 02:00-03:00 UTC = Tokyo 11:00-12:00
        let r = assess(&a, day + 2 * H, day + 3 * H);
        assert_eq!((r.outside_min, r.day_len_min, r.extra_min), (Some(0), Some(8 * 60), Some(0)));
        assert_eq!(r.zone, Zone::Green);
        // straddling the end: Tokyo 16:30-17:30
        let r = assess(&a, day + 7 * H + 30 * 60, day + 8 * H + 30 * 60);
        assert_eq!(r.outside_min, Some(30));
        assert_eq!(r.extra_min, Some(30));
        // day off: all of it is outside
        let sat = day0(2026, 10, 24);
        let r = assess(&a, sat + 2 * H, sat + 3 * H);
        assert_eq!((r.outside_min, r.extra_min), (Some(60), Some(60)));
        assert_eq!(r.zone, Zone::Amber);
    }

    #[test]
    fn assess_without_schedule_or_zone_makes_no_numbers_up() {
        let zrh = fixed(1);
        let day = day0(2026, 10, 27);
        let g = p(Some(&zrh), None, &[], &[]);
        let r = assess(&g, day + 8 * H, day + 9 * H);
        assert_eq!((r.outside_min, r.day_len_min, r.extra_min), (None, None, None));
        assert_eq!(r.zone, Zone::Green);
        let r = assess(&g, day + 2 * H, day + 3 * H);
        assert_eq!(r.zone, Zone::Red, "03:00 Zurich is night even without a schedule");
        let nowhere = p(None, Some(office()), &[], &[]);
        assert_eq!(assess(&nowhere, day, day + H).zone, Zone::Unknown);
        assert_eq!(assess(&g, day + H, day).zone, Zone::Unknown, "end before start");
    }

    #[test]
    fn assess_focus_ring_counts_booked_minutes_in_window() {
        let z = fixed(0);
        let day = day0(2026, 6, 1); // a Monday, office 09-17
        let busy = [Interval { start: day + 8 * H, end: day + 10 * H }, Interval { start: day + 12 * H, end: day + 13 * H + 1800 }];
        let a = p(Some(&z), Some(office()), &[], &busy);
        let r = assess(&a, day + 14 * H, day + 15 * H);
        assert_eq!(r.work_min, Some(480));
        assert_eq!(r.booked_min, Some(60 + 90), "08-10 is clipped to 09-10; 12-13:30 counts whole");
        let sat = day + 5 * 86_400;
        assert_eq!(assess(&a, sat + 10 * H, sat + 11 * H).booked_min, None, "day off: no ring");
        let g = p(Some(&z), None, &[], &[]);
        assert_eq!(assess(&g, day + 10 * H, day + 11 * H).work_min, None, "no schedule: no ring");
    }

    #[test]
    fn assess_marks_busy_as_amber() {
        let khi = fixed(5);
        let day = day0(2026, 10, 27);
        let busy = [Interval { start: day + 5 * H, end: day + 6 * H }];
        let a = p(Some(&khi), Some(office()), &[], &busy);
        assert_eq!(assess(&a, day + 5 * H, day + 6 * H).zone, Zone::Amber);
        assert_eq!(assess(&a, day + 6 * H, day + 7 * H).zone, Zone::Green);
    }
}
