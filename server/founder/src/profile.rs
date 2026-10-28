//! Founder profile photo: validation only (pure, tested). Network lives in data.rs, routing in main.rs.
//! Same limits as the user app's /api/auth/profile, so a photo set on either side is valid on both (FC18).

/// A photo is either a small data: URL (jpeg/png/webp, base64, <= 180_000 chars) or a short https link.
pub fn valid_avatar(s: &str) -> bool {
    let s = s.trim();
    if s.starts_with("data:image/") {
        let ok_head = ["data:image/jpeg;base64,", "data:image/jpg;base64,", "data:image/png;base64,", "data:image/webp;base64,"].iter().any(|h| s.starts_with(h));
        let body = s.split_once(',').map(|x| x.1).unwrap_or("");
        return ok_head && s.len() <= 180_000 && !body.is_empty() && body.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'+' || b == b'/' || b == b'=');
    }
    s.len() <= 500 && s.starts_with("https://") && !s.contains(char::is_whitespace) && !s.contains(['"', '<', '>', '\''])
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn data_url_png_ok() { assert!(valid_avatar("data:image/png;base64,iVBORw0KGgo=")); }
    #[test] fn data_url_svg_refused() { assert!(!valid_avatar("data:image/svg+xml;base64,PHN2Zz4=")); }
    #[test] fn data_url_junk_body_refused() { assert!(!valid_avatar("data:image/png;base64,abc<script>")); }
    #[test] fn data_url_empty_refused() { assert!(!valid_avatar("data:image/png;base64,")); }
    #[test] fn too_big_refused() { assert!(!valid_avatar(&format!("data:image/jpeg;base64,{}", "A".repeat(180_000)))); }
    #[test] fn https_ok_http_refused() { assert!(valid_avatar("https://cdn.example.com/a.jpg")); assert!(!valid_avatar("http://cdn.example.com/a.jpg")); assert!(!valid_avatar("javascript:alert(1)")); }
    #[test] fn https_with_quote_or_space_refused() { assert!(!valid_avatar("https://x.com/a b.jpg")); assert!(!valid_avatar("https://x.com/a\".jpg")); }
}
