// ============================================================================
// authx_glue — `auth.session` Rust PRIMARY (Tokio async; wahi dispatch HTTP /rpc aur WebTransport /wt/rpc; Rule 52/56).
//   auth.session {} -> { user{...}, organisations[], active_organisation_id }   (Bun GET /api/auth/session = sessionResult)
// Har page-load par chalta hai (auth.tsx). Login/refresh/logout/mfa Bun par rehte hain (alag migration). Jawab ka shape Bun se barabar.
// Hisab authx_core.rs mein (6 tests); yahan sirf rows laana. Sirf login (har plan).
// ============================================================================

use crate::authx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::owns_name(proc)
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

fn s<'a>(v: &'a Value, k: &str) -> Option<&'a str> {
    v.get(k).and_then(|x| x.as_str())
}

fn first_row(v: Result<Value, String>) -> Option<Value> {
    v.ok().and_then(|r| r.as_array().and_then(|a| a.first().cloned()))
}

/// user_metadata.name (GoTrue admin) — sirf tab jab baaqi naam khaali hon.
async fn meta_name(uid: &str) -> Option<String> {
    let (url, key) = crate::sb()?;
    let r = crate::http()
        .get(format!("{url}/auth/v1/admin/users/{}", enc(uid)))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await
        .ok()?;
    if !r.status().is_success() {
        return None;
    }
    let j: Value = r.json().await.ok()?;
    j.get("user_metadata").and_then(|m| m.get("name")).and_then(|n| n.as_str()).filter(|n| !n.is_empty()).map(|n| n.to_string())
}

/// operationalOrganisation: org_members, warna mail_accounts se owner banao (upsert).
async fn operational(uid: &str, email: &str) -> Option<(String, String)> {
    if let Some(m) = first_row(crate::sb_select(&format!("org_members?select=org_id,role&user_id=eq.{}&limit=1", enc(uid))).await) {
        if let Some(oid) = s(&m, "org_id") {
            let role = s(&m, "role").filter(|r| !r.is_empty()).unwrap_or("member");
            return Some((oid.to_string(), role.to_string()));
        }
    }
    let addr = email.trim().to_lowercase();
    if addr.is_empty() {
        return None;
    }
    let mb = first_row(crate::sb_select(&format!("mail_accounts?select=org_id&address=eq.{}&limit=1", enc(&addr))).await)?;
    let oid = s(&mb, "org_id")?.to_string();
    let up = crate::sb_upsert(
        "org_members",
        "org_id,user_id",
        json!({ "org_id": oid, "user_id": uid, "email": addr, "role": "owner", "status": "active" }),
    )
    .await;
    if up.is_err() {
        return None;
    }
    Some((oid, "owner".into()))
}

pub async fn dispatch(proc: &str, token: &str, _input: &Value) -> Resp {
    if proc != "auth.session" {
        return crate::err(StatusCode::NOT_FOUND, "unknown_proc", "unknown proc").into_response();
    }
    let (uid, email) = match crate::auth_user(token).await {
        Some(v) => v,
        None => return crate::err(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid").into_response(),
    };
    let u = enc(&uid);
    let q_profile = format!(
        "account_profiles?select=legal_name,display_name,avatar_url,work_role,preferences,onboarded&user_id=eq.{u}&limit=1"
    );
    let q_members = format!("account_org_members?select=role,account_organisations(id,name,slug,domain)&user_id=eq.{u}");
    let q_trial = format!("trial_accounts?select=anexomail_address,plan&user_id=eq.{u}&limit=1");
    let q_founder = format!("founder_accounts?select=user_id&user_id=eq.{u}&limit=1");
    let (profile, members, trial, founder_row, op) = tokio::join!(
        crate::sb_select(&q_profile),
        crate::sb_select(&q_members),
        crate::sb_select(&q_trial),
        crate::sb_select(&q_founder),
        operational(&uid, &email),
    );

    let profile = first_row(profile);
    let trial = first_row(trial);
    let founder = first_row(founder_row).is_some();

    let addr = c::anexo_address(trial.as_ref().and_then(|t| s(t, "anexomail_address")), founder, &email);

    let family = match &addr {
        Some(a) => first_row(crate::sb_select(&format!("family_accounts?select=display_name,plan,ai_plan&email=eq.{}&limit=1", enc(a))).await),
        None => None,
    };
    let real_plan = family
        .as_ref()
        .and_then(|f| s(f, "plan"))
        .filter(|p| !p.is_empty())
        .or_else(|| trial.as_ref().and_then(|t| s(t, "plan")).filter(|p| !p.is_empty()));
    let has_chosen_plan = real_plan.is_some();
    let plan = c::workspace_plan(real_plan);
    let ai_plan = family.as_ref().and_then(|f| s(f, "ai_plan")).and_then(c::ai_plan);

    // account organisations
    let mut accounts: Vec<c::Org> = Vec::new();
    if let Ok(Value::Array(rows)) = members {
        for r in rows {
            if let Some(o) = r.get("account_organisations").filter(|o| o.is_object()) {
                accounts.push(c::Org {
                    id: s(o, "id").unwrap_or("").to_string(),
                    name: s(o, "name").unwrap_or("").to_string(),
                    slug: s(o, "slug").unwrap_or("").to_string(),
                    domain: s(o, "domain").map(|d| d.to_string()),
                    role: s(&r, "role").unwrap_or("").to_string(),
                });
            }
        }
    }

    // operational org
    let op_org = match op {
        Some((oid, role)) => {
            let live = first_row(crate::sb_select(&format!("organisations?select=id,name,slug&id=eq.{}&limit=1", enc(&oid))).await);
            let legacy = if live.is_some() { None } else { first_row(crate::sb_select(&format!("orgs?select=id,name&id=eq.{}&limit=1", enc(&oid))).await) };
            Some(c::Org {
                name: c::op_org_name(live.as_ref().and_then(|l| s(l, "name")), legacy.as_ref().and_then(|l| s(l, "name")), founder),
                slug: c::op_org_slug(live.as_ref().and_then(|l| s(l, "slug")), founder, &oid),
                id: oid,
                domain: None,
                role: if role.is_empty() { "owner".into() } else { role },
            })
        }
        None => None,
    };
    let has_op = op_org.is_some();
    let orgs = c::merge_orgs(accounts, op_org.clone(), founder, addr.is_some());

    let prefs = profile.as_ref().and_then(|p| p.get("preferences")).cloned().unwrap_or(json!({}));
    let preferred = prefs.get("active_organisation_id").and_then(|x| x.as_str());
    let active = c::active_org_id(preferred, &orgs);
    let profile_onboarded = profile.as_ref().and_then(|p| p.get("onboarded")).and_then(|x| x.as_bool()).unwrap_or(false);
    let onboarded = c::is_onboarded(founder, profile_onboarded, has_op, addr.is_some());

    let legal = profile.as_ref().and_then(|p| s(p, "legal_name"));
    let mut display = c::first_text(&[
        profile.as_ref().and_then(|p| s(p, "display_name")),
        family.as_ref().and_then(|f| s(f, "display_name")),
        legal,
    ]);
    if display.is_none() {
        display = meta_name(&uid).await;
    }

    let pref_kind = prefs.get("workspace_kind").and_then(|x| x.as_str()).unwrap_or("");
    let org_slug = op_org.as_ref().map(|o| o.slug.as_str()).or_else(|| orgs.first().map(|o| o.slug.as_str())).unwrap_or("");
    let kind = c::resolve_account_kind(pref_kind, &plan, org_slug);
    let mut personal_plan_name = Value::Null;
    if kind == "personal" {
        if let Ok(Value::String(l)) = crate::sb_rpc("personal_workspace_label", json!({ "_user_id": uid })).await {
            if !l.trim().is_empty() {
                personal_plan_name = json!(l.trim());
            }
        }
    }

    let orgs_json: Vec<Value> = orgs
        .iter()
        .map(|o| json!({ "id": o.id, "name": o.name, "slug": o.slug, "domain": o.domain, "role": o.role }))
        .collect();

    crate::ok(json!({
        "user": {
            "id": uid,
            "email": email,
            "name": display,
            "legal_name": legal,
            "display_name": display,
            "avatar_url": profile.as_ref().and_then(|p| s(p, "avatar_url")),
            "work_role": profile.as_ref().and_then(|p| s(p, "work_role")),
            "preferences": prefs,
            "mfa_enabled": false,
            "is_founder": founder,
            "onboarded": onboarded,
            "anexomail_address": addr,
            "workspace_plan": plan,
            "has_chosen_plan": has_chosen_plan,
            "ai_plan": ai_plan,
            "account_kind": kind,
            "personal_plan_name": personal_plan_name,
        },
        "organisations": orgs_json,
        "active_organisation_id": active,
    }))
    .into_response()
}
