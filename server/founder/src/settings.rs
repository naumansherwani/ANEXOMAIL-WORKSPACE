//! Founder settings registry (first line of defence; the SQL registry in E108 is authoritative). Pure + tested; network lives in data.rs, routing in main.rs.
//! Gate G1w: founder token + approved device + signed write + audit row (low-risk own-profile / cosmetic values).
use serde_json::Value;

/// (key, kind, default as JSON text) — what the SPA is told, so the UI never invents a default.
pub const REGISTRY: [(&str, &str, &str); 5] = [
    ("personal.display_name", "text", "null"),
    ("personal.avatar", "image", "null"),
    ("personal.home", "place", "null"),
    ("appearance.graphics", "bool", "true"),
    ("appearance.sidebar_slim", "bool", "false"),
];

/// A photo is a small data: URL (jpeg/png/webp, base64, <= 180_000 chars) or a short https link. Same limits as the user app, so both stay compatible.
pub fn valid_avatar(s: &str) -> bool {
    let s = s.trim();
    if s.starts_with("data:image/") {
        let ok_head = ["data:image/jpeg;base64,", "data:image/jpg;base64,", "data:image/png;base64,", "data:image/webp;base64,"].iter().any(|h| s.starts_with(h));
        let body = s.split_once(',').map(|x| x.1).unwrap_or("");
        return ok_head && s.len() <= 180_000 && !body.is_empty() && body.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'+' || b == b'/' || b == b'=');
    }
    s.len() <= 500 && s.starts_with("https://") && !s.contains(char::is_whitespace) && !s.contains(['"', '<', '>', '\''])
}

fn valid_name(s: &str) -> bool { let n = s.chars().count(); (2..=60).contains(&n) && s.trim() == s && !s.chars().any(|c| c.is_control() || c == '<' || c == '>') }
fn valid_tz_shape(s: &str) -> bool { s.len() <= 60 && s.contains('/') && s.chars().all(|c| c.is_ascii_alphanumeric() || matches!(c, '/' | '_' | '+' | '-')) }
fn clean_txt(v: &Value, min: usize, max: usize) -> bool { v.as_str().map(|s| { let n = s.chars().count(); n >= min && n <= max && !s.chars().any(|c| c.is_control() || c == '<' || c == '>') }).unwrap_or(false) }
/// A place is exactly {city, country, iana, lat, lon}. The real zone-name check (pg_timezone_names) is done by SQL.
fn valid_place(v: &Value) -> bool {
    let Some(o) = v.as_object() else { return false };
    if o.len() != 5 { return false; }
    let num = |k: &str, lo: f64, hi: f64| o.get(k).and_then(|x| x.as_f64()).map(|n| n >= lo && n <= hi).unwrap_or(false);
    o.get("city").map(|x| clean_txt(x, 1, 60)).unwrap_or(false) && o.get("country").map(|x| clean_txt(x, 0, 60)).unwrap_or(false)
        && o.get("iana").and_then(|x| x.as_str()).map(valid_tz_shape).unwrap_or(false) && num("lat", -90.0, 90.0) && num("lon", -180.0, 180.0)
}

pub fn known(key: &str) -> bool { REGISTRY.iter().any(|r| r.0 == key) }

/// null = back to default (always allowed for a known key).
pub fn valid(key: &str, v: &Value) -> bool {
    if !known(key) { return false; }
    if v.is_null() { return true; }
    match key {
        "personal.display_name" => v.as_str().map(valid_name).unwrap_or(false),
        "personal.avatar" => v.as_str().map(valid_avatar).unwrap_or(false),
        "personal.home" => valid_place(v), // the real zone list check is in SQL (pg_timezone_names)
        "appearance.graphics" | "appearance.sidebar_slim" => v.is_boolean(),
        _ => false,
    }
}

pub fn registry_json() -> Value {
    Value::Array(REGISTRY.iter().map(|(k, kind, d)| serde_json::json!({"key": k, "kind": kind, "default": serde_json::from_str::<Value>(d).unwrap_or(Value::Null)})).collect())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test] fn data_url_png_ok() { assert!(valid_avatar("data:image/png;base64,iVBORw0KGgo=")); }
    #[test] fn data_url_svg_refused() { assert!(!valid_avatar("data:image/svg+xml;base64,PHN2Zz4=")); }
    #[test] fn data_url_junk_body_refused() { assert!(!valid_avatar("data:image/png;base64,abc<script>")); }
    #[test] fn data_url_empty_refused() { assert!(!valid_avatar("data:image/png;base64,")); }
    #[test] fn too_big_refused() { assert!(!valid_avatar(&format!("data:image/jpeg;base64,{}", "A".repeat(180_000)))); }
    #[test] fn https_ok_http_refused() { assert!(valid_avatar("https://cdn.example.com/a.jpg")); assert!(!valid_avatar("http://cdn.example.com/a.jpg")); assert!(!valid_avatar("javascript:alert(1)")); }
    #[test] fn https_with_quote_or_space_refused() { assert!(!valid_avatar("https://x.com/a b.jpg")); assert!(!valid_avatar("https://x.com/a\".jpg")); }
    #[test] fn unknown_key_refused() { assert!(!valid("appearance.nope", &json!(true))); assert!(!valid("", &json!(null))); }
    #[test] fn null_resets_any_known_key() { for (k, _, _) in REGISTRY { assert!(valid(k, &Value::Null), "{k}"); } }
    #[test] fn name_rules() { assert!(valid("personal.display_name", &json!("Nauman Sherwani"))); assert!(!valid("personal.display_name", &json!("x"))); assert!(!valid("personal.display_name", &json!(" pad "))); assert!(!valid("personal.display_name", &json!("<b>hi</b>"))); assert!(!valid("personal.display_name", &json!(5))); }
    #[test] fn bool_rules() { assert!(valid("appearance.graphics", &json!(false))); assert!(!valid("appearance.graphics", &json!("off"))); assert!(!valid("appearance.sidebar_slim", &json!(1))); }
    #[test] fn place_rules() {
        let ok = json!({"city":"Lahore","country":"Pakistan","iana":"Asia/Karachi","lat":31.52,"lon":74.36});
        assert!(valid("personal.home", &ok));
        assert!(!valid("personal.home", &json!("Lahore")), "text is not a place");
        assert!(!valid("personal.home", &json!({"city":"Lahore","country":"Pakistan","iana":"Asia/Karachi","lat":131,"lon":74.36})), "lat range");
        assert!(!valid("personal.home", &json!({"city":"Lahore","country":"Pakistan","iana":"Karachi","lat":31.5,"lon":74.3})), "zone shape");
        assert!(!valid("personal.home", &json!({"city":"Lahore","country":"Pakistan","iana":"Asia/Karachi","lat":31.5,"lon":74.3,"x":1})), "extra key");
        assert!(!valid("personal.home", &json!({"city":"<b>","country":"P","iana":"Asia/Karachi","lat":31.5,"lon":74.3})), "markup in city");
        assert!(!valid("personal.home", &json!({"city":"Lahore","country":"Pakistan","iana":"Asia/Karachi","lat":"31.5","lon":74.3})), "lat as text");
    }
    #[test] fn registry_defaults_are_json() { assert_eq!(registry_json().as_array().unwrap().len(), REGISTRY.len()); }
}
