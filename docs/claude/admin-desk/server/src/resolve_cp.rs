// ANEXOMAIL ADMIN DESK resolve_cp.rs (BL-46 B13 step T3a/T3b, 24 Nov 2026): the Desk's PURE reading of a Control Plane "resolve sender" answer (SQL AD31, cp.resolve_sender). Rust + Tokio side, Rule 52: this module only ever sees an answer that the signed-envelope check (consent_cp::accept style) already verified; it then reads it STRICTLY.
// Shape is closed: exactly {verdict, tenant}; verdict is one of six words; a tenant UUID exists exactly when the verdict is "resolved". Anything else = Reject::Unavailable (fail closed). The Desk then calls desk.fadm_case_bind (AD30) with source verified_domain, and only for "resolved".
// The wire call itself (signed request, HTTP/3, replay cache) is step T3b and is not here. No sender address or company name ever reaches this module: the Desk gets a word and a UUID.
use serde_json::Value;

pub const VERDICTS: [&str; 6] = ["resolved", "shared", "unknown", "ambiguous", "multi_member", "unaligned"];

#[derive(Debug, PartialEq, Clone)]
pub enum Verdict { Resolved(String), Pending(&'static str) }

fn uuid_ok(s: &str) -> bool { s.len() == 36 && s.bytes().enumerate().all(|(i, b)| if matches!(i, 8 | 13 | 18 | 23) { b == b'-' } else { b.is_ascii_digit() || (b'a'..=b'f').contains(&b) }) }

/// Read one verified resolve answer. Err = the Desk treats the case as unresolved and shows "Not available".
pub fn read(r: &Value) -> Result<Verdict, ()> {
    let m = r.as_object().ok_or(())?;
    if m.len() != 2 || !m.contains_key("verdict") || !m.contains_key("tenant") { return Err(()); }
    let w = r["verdict"].as_str().and_then(|v| VERDICTS.iter().find(|x| **x == v)).ok_or(())?;
    match (*w, &r["tenant"]) {
        ("resolved", Value::String(t)) if uuid_ok(t) => Ok(Verdict::Resolved(t.clone())),
        ("resolved", _) => Err(()),
        (_, Value::Null) => Ok(Verdict::Pending(w)),
        _ => Err(()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    const T: &str = "3f2b8c1e-5a4d-4e7a-9c1b-0a1b2c3d4e5f";
    #[test] fn resolved_needs_a_uuid() {
        assert_eq!(read(&json!({"verdict": "resolved", "tenant": T})), Ok(Verdict::Resolved(T.to_string())));
        assert!(read(&json!({"verdict": "resolved", "tenant": null})).is_err());
        assert!(read(&json!({"verdict": "resolved", "tenant": "acme"})).is_err());
    }
    #[test] fn every_other_word_has_no_tenant() {
        for w in ["shared", "unknown", "ambiguous", "multi_member", "unaligned"] {
            assert!(matches!(read(&json!({"verdict": w, "tenant": null})), Ok(Verdict::Pending(x)) if x == w));
            assert!(read(&json!({"verdict": w, "tenant": T})).is_err(), "{w} must never carry a tenant");
        }
    }
    #[test] fn unknown_words_and_shapes_fail_closed() {
        assert!(read(&json!({"verdict": "maybe", "tenant": null})).is_err());
        assert!(read(&json!({"verdict": "resolved", "tenant": T, "name": "Acme"})).is_err());
        assert!(read(&json!({"verdict": "resolved"})).is_err());
        assert!(read(&json!("resolved")).is_err());
        assert!(read(&json!(null)).is_err());
    }
    #[test] fn the_word_list_is_the_sql_word_list() {
        let sql = include_str!("../../sql/AD31.sql");
        for w in VERDICTS { assert!(sql.contains(&format!("'{w}'")), "{w} missing in AD31"); }
    }
}
