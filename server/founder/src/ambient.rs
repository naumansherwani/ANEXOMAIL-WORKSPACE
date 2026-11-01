//! Founder Ambient Studio (master order S1b; SQL = E114): a look is a recipe {palette, pattern, speed, intensity, blend, seed}.
//! Technology: Rust (axum, tokio). Pure and tested here: the same mixed-radix maths as the SQL (`founder_ambient_index/at/step`), query parsing,
//! and the first line of defence for the two ambient settings. SQL (E114) is authoritative and reads its own catalog tables; these sizes only
//! stop a bad request before it reaches the database. If a table in SQL ever changes size, the SQL answer wins and this file's tests say so.
use serde_json::{Value, json};

pub const PALETTES: i64 = 120;
pub const PATTERNS: i64 = 24;
pub const SPEEDS: i64 = 20;
pub const INTENSITIES: i64 = 10;
pub const BLENDS: i64 = 8;
pub const SEEDS: i64 = 65_536;
pub const MAX_FAVOURITES: usize = 24;
/// Never typed anywhere in the UI: this is the product of the table sizes (the UI shows the number the database computed).
pub const TOTAL: i64 = PALETTES * PATTERNS * SPEEDS * INTENSITIES * BLENDS * SEEDS;

pub fn missing() -> Value { json!({"available": false, "note": "ambient catalog not answering - run the E114 SQL (sql-run.sh)"}) }

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Recipe { pub palette: i64, pub pattern: i64, pub speed: i64, pub intensity: i64, pub blend: i64, pub seed: i64 }

impl Recipe {
    pub fn in_range(&self) -> bool {
        (0..PALETTES).contains(&self.palette) && (0..PATTERNS).contains(&self.pattern) && (0..SPEEDS).contains(&self.speed)
            && (0..INTENSITIES).contains(&self.intensity) && (0..BLENDS).contains(&self.blend) && (0..SEEDS).contains(&self.seed)
    }
    /// palette changes fastest, like cycling a car's ambient colours (same order as the SQL).
    pub fn index(&self) -> i64 {
        self.palette + PALETTES * (self.pattern + PATTERNS * (self.speed + SPEEDS * (self.intensity + INTENSITIES * (self.blend + BLENDS * self.seed))))
    }
    pub fn at(n: i64) -> Recipe {
        let mut q = n.rem_euclid(TOTAL);
        let palette = q % PALETTES; q /= PALETTES;
        let pattern = q % PATTERNS; q /= PATTERNS;
        let speed = q % SPEEDS; q /= SPEEDS;
        let intensity = q % INTENSITIES; q /= INTENSITIES;
        let blend = q % BLENDS; q /= BLENDS;
        Recipe { palette, pattern, speed, intensity, blend, seed: q }
    }
    pub fn step(&self, delta: i64) -> Recipe { Recipe::at((self.index() + delta).rem_euclid(TOTAL)) }
    pub fn to_json(&self) -> Value { json!({"palette": self.palette, "pattern": self.pattern, "speed": self.speed, "intensity": self.intensity, "blend": self.blend, "seed": self.seed}) }
}

/// A recipe in JSON: exactly the six keys, each a whole non-negative number (no decimals, signs, strings or extra keys), all inside the catalog ranges.
pub fn recipe_from_json(v: &Value) -> Option<Recipe> {
    let o = v.as_object()?;
    if o.len() != 6 { return None; }
    let g = |k: &str| -> Option<i64> { let n = o.get(k)?; if n.is_f64() { return None; } n.as_i64().filter(|x| *x >= 0 && *x <= 999_999) };
    let r = Recipe { palette: g("palette")?, pattern: g("pattern")?, speed: g("speed")?, intensity: g("intensity")?, blend: g("blend")?, seed: g("seed")? };
    r.in_range().then_some(r)
}

/// `appearance.ambient` (one recipe) and `appearance.ambient_favs` (up to 24 different recipes).
pub fn valid_setting(key: &str, v: &Value) -> bool {
    match key {
        "appearance.ambient" => recipe_from_json(v).is_some(),
        "appearance.ambient_favs" => {
            let Some(a) = v.as_array() else { return false };
            if a.len() > MAX_FAVOURITES { return false; }
            let mut seen: Vec<Recipe> = Vec::with_capacity(a.len());
            for e in a { match recipe_from_json(e) { Some(r) if !seen.contains(&r) => seen.push(r), _ => return false } }
            true
        }
        _ => false,
    }
}

fn pairs(q: Option<&str>) -> impl Iterator<Item = (&str, &str)> { q.unwrap_or("").split('&').filter(|p| !p.is_empty()).map(|p| p.split_once('=').unwrap_or((p, ""))) }
fn digits(v: &str) -> Option<i64> { if v.is_empty() || v.len() > 7 || !v.bytes().all(|b| b.is_ascii_digit()) { None } else { v.parse().ok() } }

/// `?palette=&pattern=&speed=&intensity=&blend=&seed=` — exactly these six, each once, whole numbers, inside the catalog.
pub fn parse_recipe(q: Option<&str>) -> Result<Recipe, &'static str> {
    let (mut pa, mut pt, mut sp, mut it, mut bl, mut sd) = (None, None, None, None, None, None);
    for (k, v) in pairs(q) {
        let slot = match k { "palette" => &mut pa, "pattern" => &mut pt, "speed" => &mut sp, "intensity" => &mut it, "blend" => &mut bl, "seed" => &mut sd, "delta" | "each" | "n" => continue, _ => return Err("unknown parameter") };
        if slot.is_some() { return Err("parameter given twice"); }
        *slot = Some(digits(v).ok_or("look values must be whole numbers")?);
    }
    let r = Recipe { palette: pa.ok_or("palette needed")?, pattern: pt.ok_or("pattern needed")?, speed: sp.ok_or("speed needed")?, intensity: it.ok_or("intensity needed")?, blend: bl.ok_or("blend needed")?, seed: sd.ok_or("seed needed")? };
    if r.in_range() { Ok(r) } else { Err("look outside the catalog") }
}

/// `delta=<-TOTAL..TOTAL>` (a minus sign is allowed here only).
pub fn parse_delta(q: Option<&str>) -> Result<i64, &'static str> {
    for (k, v) in pairs(q) {
        if k != "delta" { continue; }
        let (neg, d) = match v.strip_prefix('-') { Some(r) => (true, r), None => (false, v) };
        if d.is_empty() || d.len() > 12 || !d.bytes().all(|b| b.is_ascii_digit()) { return Err("delta must be a whole number"); }
        let n: i64 = d.parse().map_err(|_| "delta must be a whole number")?;
        let n = if neg { -n } else { n };
        return if n.abs() <= TOTAL { Ok(n) } else { Err("delta larger than one lap") };
    }
    Ok(1)
}

/// `each=1..12` (how many looks to pre-render on each side).
pub fn parse_each(q: Option<&str>) -> Result<i64, &'static str> {
    for (k, v) in pairs(q) { if k == "each" { let n = digits(v).ok_or("each must be a whole number")?; return if (1..=12).contains(&n) { Ok(n) } else { Err("each must be 1..12") }; } }
    Ok(3)
}

/// `n=<whole number up to 15 digits>` — the browser's own random number for "Surprise me".
pub fn parse_entropy(q: Option<&str>) -> Result<i64, &'static str> {
    for (k, v) in pairs(q) { if k == "n" { if v.is_empty() || v.len() > 15 || !v.bytes().all(|b| b.is_ascii_digit()) { return Err("n must be a whole number"); } return v.parse().map_err(|_| "n must be a whole number"); } }
    Err("n needed")
}

#[cfg(test)]
mod tests {
    use super::*;
    const DEFAULT: Recipe = Recipe { palette: 60, pattern: 1, speed: 9, intensity: 6, blend: 0, seed: 0 };

    #[test] fn total_is_the_product_and_over_a_million() { assert_eq!(TOTAL, 301_989_888_000); assert!(TOTAL > 1_000_000); }
    #[test] fn default_look_number_matches_sql() { assert_eq!(DEFAULT.index(), 60 + 120 * 1 + 120 * 24 * 9 + 120 * 24 * 20 * 6); }
    #[test] fn edges_match_sql() {
        assert_eq!(Recipe::at(0), Recipe { palette: 0, pattern: 0, speed: 0, intensity: 0, blend: 0, seed: 0 });
        assert_eq!(Recipe::at(TOTAL - 1), Recipe { palette: 119, pattern: 23, speed: 19, intensity: 9, blend: 7, seed: 65_535 });
    }
    #[test] fn round_trip_spread_numbers() { for i in 0..3000i64 { let n = (i * 1_000_003 + 17) % TOTAL; assert_eq!(Recipe::at(n).index(), n); } }
    #[test] fn step_moves_palette_first_and_wraps() {
        assert_eq!(DEFAULT.step(1), Recipe { palette: 61, ..DEFAULT });
        let edge = Recipe { palette: 119, ..DEFAULT };
        assert_eq!((edge.step(1).palette, edge.step(1).pattern), (0, 2));
        assert_eq!(DEFAULT.step(37).step(-37), DEFAULT);
        assert_eq!(DEFAULT.step(TOTAL), DEFAULT);
        assert_eq!(Recipe::at(TOTAL - 1).step(1), Recipe::at(0));
        assert_eq!(Recipe::at(0).step(-1), Recipe::at(TOTAL - 1));
    }
    #[test] fn json_recipe_is_strict() {
        assert_eq!(recipe_from_json(&DEFAULT.to_json()), Some(DEFAULT));
        for bad in [json!({"palette":120,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0}), json!({"palette":-1,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0}),
                    json!({"palette":60.5,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0}), json!({"palette":"60","pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0}),
                    json!({"palette":60,"pattern":1,"speed":9,"intensity":6,"blend":0}), json!({"palette":60,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0,"x":1}),
                    json!({"palette":60,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":65536}), json!([]), json!("x"), Value::Null] { assert!(recipe_from_json(&bad).is_none(), "{bad}"); }
    }
    #[test] fn favourites_limits() {
        let mk = |n: i64| Value::Array((0..n).map(|i| Recipe::at(i * 120).to_json()).collect());
        assert!(valid_setting("appearance.ambient_favs", &mk(24)));
        assert!(valid_setting("appearance.ambient_favs", &mk(0)));
        assert!(!valid_setting("appearance.ambient_favs", &mk(25)));
        assert!(!valid_setting("appearance.ambient_favs", &json!([DEFAULT.to_json(), DEFAULT.to_json()])));
        assert!(!valid_setting("appearance.ambient_favs", &json!({"a": 1})));
        assert!(valid_setting("appearance.ambient", &DEFAULT.to_json()));
        assert!(!valid_setting("appearance.graphics", &json!(true)));
    }
    #[test] fn query_parsing_is_a_whitelist() {
        assert_eq!(parse_recipe(Some("palette=60&pattern=1&speed=9&intensity=6&blend=0&seed=0")), Ok(DEFAULT));
        assert_eq!(parse_recipe(Some("palette=60&pattern=1&speed=9&intensity=6&blend=0&seed=0&delta=-5")), Ok(DEFAULT));
        assert!(parse_recipe(Some("palette=60&pattern=1&speed=9&intensity=6&blend=0")).is_err());
        assert!(parse_recipe(Some("palette=60&palette=61&pattern=1&speed=9&intensity=6&blend=0&seed=0")).is_err());
        assert!(parse_recipe(Some("palette=120&pattern=1&speed=9&intensity=6&blend=0&seed=0")).is_err());
        assert!(parse_recipe(Some("palette=-1&pattern=1&speed=9&intensity=6&blend=0&seed=0")).is_err());
        assert!(parse_recipe(Some("palette=60&pattern=1&speed=9&intensity=6&blend=0&seed=0&evil=1")).is_err());
        assert_eq!(parse_delta(Some("delta=-37")), Ok(-37));
        assert_eq!(parse_delta(None), Ok(1));
        assert!(parse_delta(Some("delta=1.5")).is_err());
        assert!(parse_delta(Some(&format!("delta={}", TOTAL + 1))).is_err());
        assert_eq!(parse_each(Some("each=12")), Ok(12));
        assert!(parse_each(Some("each=13")).is_err() && parse_each(Some("each=0")).is_err());
        assert_eq!(parse_entropy(Some("n=42")), Ok(42));
        assert!(parse_entropy(None).is_err() && parse_entropy(Some("n=-1")).is_err() && parse_entropy(Some("n=1234567890123456")).is_err());
    }
}
