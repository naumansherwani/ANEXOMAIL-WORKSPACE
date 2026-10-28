//! Founder darwaza: Bearer (Supabase ES256 JWT, local verify) + `founder_accounts` mein uid. Awam token chalega par founder row nahi => 403.
//! Awam API par founder session ka ulta (F1a): is binary ka token awam host nahi leta.
use crate::jwt_core::{Claims, Jwk, JwtErr};

#[derive(Debug, PartialEq)]
pub enum Gate {
    Ok(Claims),
    Unauthorized, // 401: token nahi/ghalat/expired
    Forbidden,    // 403: token theek, founder nahi
}

pub fn bearer(h: Option<&str>) -> Option<&str> {
    let v = h?.strip_prefix("Bearer ")?.trim();
    (!v.is_empty()).then_some(v)
}

/// Pure faisla: verify ka nateeja + "kya yeh uid founder_accounts mein hai".
pub fn decide(v: Result<Claims, JwtErr>, is_founder: impl FnOnce(&str) -> bool) -> Gate {
    match v {
        Err(_) => Gate::Unauthorized,
        Ok(c) => {
            if is_founder(&c.sub) { Gate::Ok(c) } else { Gate::Forbidden }
        }
    }
}

pub fn verify_token(token: &str, jwks: &[Jwk], iss: &str, now: i64) -> Result<Claims, JwtErr> {
    crate::jwt_core::verify(token, jwks, iss, now)
}

#[cfg(test)]
mod tests {
    use super::*;
    fn c() -> Claims { Claims { sub: "u1".into(), email: "e".into(), session_id: None, exp: 9 } }
    #[test]
    fn bearer_parse() {
        assert_eq!(bearer(Some("Bearer abc")), Some("abc"));
        assert_eq!(bearer(Some("Basic abc")), None);
        assert_eq!(bearer(Some("Bearer  ")), None);
        assert_eq!(bearer(None), None);
    }
    #[test]
    fn decisions() {
        assert_eq!(decide(Err(JwtErr::Expired), |_| true), Gate::Unauthorized);
        assert_eq!(decide(Ok(c()), |_| false), Gate::Forbidden);
        assert_eq!(decide(Ok(c()), |u| u == "u1"), Gate::Ok(c()));
    }
}
