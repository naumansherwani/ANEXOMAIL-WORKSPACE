// ============================================================================
// wsx_glue — Onboarding: naya user ka workspace, Rust PRIMARY (Tokio async; /rpc + /wt/rpc; Rule 52/56/57). Sab plans (login).
//   workspace.personal {}                       -> {id, kind:"personal", existing?}    (Bun POST /api/workspace/personal)
//   workspace.organisations {name, domain}      -> {id, name, slug, domain, kind}      (Bun POST /api/workspace/organisations)
// Hu-ba-hu Bun workspace.ts: organisations(+owner_id retry) -> org_members(+status retry, fail => rollback) -> account_organisations
// + account_org_members -> orgs (best effort) -> mail_accounts attach -> account_profiles.preferences.workspace_kind + onboarded.
// POST /workspace/invitations alag proc nahi: Rust `team.invites.create` (team_glue) pehle se hai. Hisaab wsx_core.rs (3 tests).
// Domain errors 400/409 (Rule 59); koi bhi fail => Bun fallback client par sirf 502/503/404 par.
// ============================================================================

use crate::wsx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::owns_name(proc)
}

fn fail(s: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(s, code, msg).into_response()
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

fn first(v: Result<Value, String>) -> Option<Value> {
    v.ok().and_then(|r| r.as_array().and_then(|a| a.first().cloned()))
}

async fn delete(path_and_query: &str) -> Result<(), String> {
    let (url, key) = crate::sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let r = crate::http()
        .delete(format!("{url}/rest/v1/{path_and_query}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if r.status().is_success() { Ok(()) } else { Err(r.text().await.unwrap_or_default()) }
}

async fn patch_only(path_and_query: &str, body: Value) -> Result<(), String> {
    crate::sb_patch(path_and_query, body).await.map(|_| ())
}

/// Profile mein pehle se likha workspace_kind (None = kabhi stamp nahi hua).
async fn current_kind(uid: &str) -> Option<String> {
    let p = first(crate::sb_select(&format!("account_profiles?select=preferences&user_id=eq.{}&limit=1", enc(uid))).await)?;
    p.get("preferences")?.get("workspace_kind")?.as_str().filter(|k| !k.is_empty()).map(|k| k.to_string())
}

/// account_profiles.preferences.workspace_kind = kind, onboarded = true.
/// Profile row na ho (NOT NULL email/legal_name/display_name) to Bun ka upsert chup-chaap fail hota tha — yahan row bana dete hain.
async fn stamp_kind(uid: &str, email: &str, kind: &str) {
    // BUG FIX (live test 03:40): upsert mojooda row par bhi INSERT-tuple banata hai, aur account_profiles ke NOT NULL
    // (email/legal_name/display_name) us mein khali hote hain => poora upsert chup-chaap fail. Isliye: row hai => PATCH, nahi => poori INSERT.
    let prof = first(crate::sb_select(&format!("account_profiles?select=preferences&user_id=eq.{}&limit=1", enc(uid))).await);
    match prof {
        Some(p) => {
            let mut prefs = p.get("preferences").cloned().filter(|x| x.is_object()).unwrap_or(json!({}));
            prefs["workspace_kind"] = json!(kind);
            let _ = crate::sb_patch(&format!("account_profiles?user_id=eq.{}", enc(uid)), json!({ "preferences": prefs, "onboarded": true })).await;
        }
        None => {
            let local = email.split('@').next().unwrap_or("").to_string();
            let _ = crate::sb_insert(
                "account_profiles",
                json!({ "user_id": uid, "email": email, "legal_name": local, "display_name": local, "preferences": { "workspace_kind": kind }, "onboarded": true }),
            )
            .await;
        }
    }
}

struct Made {
    id: String,
    name: String,
    slug: String,
    domain: Option<String>,
    kind: &'static str,
}

async fn create_org(uid: &str, name: &str, email: &str, kind: &'static str, domain: Option<String>) -> Result<Made, String> {
    let slug = if kind == "personal" { c::personal_slug(uid) } else { c::slugify(name, uid) };
    let domain = if kind == "business" { domain } else { None };

    // organisations — id DB banata hai (gen_random_uuid); pehle owner_id ke saath, fail to bina
    let mut row = json!({ "name": name, "slug": slug });
    if let Some(d) = &domain {
        row["domain"] = json!(d);
    }
    let mut with_owner = row.clone();
    with_owner["owner_id"] = json!(uid);
    let made = match crate::sb_insert("organisations", with_owner).await {
        Ok(v) => Ok(v),
        Err(_) => crate::sb_insert("organisations", row).await,
    }
    .map_err(|e| if e.is_empty() { "operational_workspace_failed".to_string() } else { e })?;
    let id = first(Ok(made))
        .and_then(|r| r.get("id").and_then(|x| x.as_str()).map(|s| s.to_string()))
        .ok_or_else(|| "operational_workspace_failed".to_string())?;

    // org_members — status ke saath, fail to bina; dono fail => organisations rollback
    let mut member = json!({ "org_id": id, "user_id": uid, "role": "owner", "status": "active" });
    if !email.is_empty() {
        member["email"] = json!(email);
    }
    let mut ok = crate::sb_upsert("org_members", "org_id,user_id", member.clone()).await.is_ok();
    if !ok {
        if let Some(o) = member.as_object_mut() {
            o.remove("status");
        }
        ok = crate::sb_upsert("org_members", "org_id,user_id", member).await.is_ok();
    }
    if !ok {
        let _ = delete(&format!("organisations?id=eq.{}", enc(&id))).await;
        return Err("operational_membership_failed".into());
    }

    // account layer (UI session)
    let acc = crate::sb_upsert(
        "account_organisations",
        "id",
        json!({ "id": id, "name": name, "slug": slug, "domain": domain, "created_by": uid }),
    )
    .await;
    if acc.is_ok() {
        let _ = crate::sb_upsert("account_org_members", "org_id,user_id", json!({ "org_id": id, "user_id": uid, "role": "owner" })).await;
    }
    // legacy orgs — best effort
    let _ = crate::sb_upsert("orgs", "id", json!({ "id": id, "name": name })).await;

    // mailbox attach
    if !email.is_empty() {
        let q = format!("address=ilike.{}", enc(email));
        let existing = first(crate::sb_select(&format!("mail_accounts?select=address&{q}&limit=1")).await);
        if existing.is_some() {
            let _ = patch_only(&format!("mail_accounts?{q}"), json!({ "org_id": id })).await;
        } else {
            let _ = crate::sb_insert("mail_accounts", json!({ "org_id": id, "address": email })).await;
        }
    }
    Ok(Made { id, name: name.to_string(), slug, domain, kind })
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    let (uid, email) = match crate::auth_user(token).await {
        Some(v) => v,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid"),
    };
    let mail = if email.is_empty() { String::new() } else { email.clone() };
    match proc {
        "workspace.personal" => {
            if let Some(m) = first(crate::sb_select(&format!("org_members?select=org_id&user_id=eq.{}&limit=1", enc(&uid))).await) {
                if let Some(oid) = m.get("org_id").and_then(|x| x.as_str()) {
                    // LOOPHOLE FIX (27 Oct 04:3x): pehle yahan HAMESHA "personal" stamp hota tha — company wale account (pro.buyer) par probe/login
                    // chalne se workspace_kind business -> personal ho gaya aur sidebar "Personal Pro+" dikhane laga. Ab mojooda kind ko CHHUA nahi jata;
                    // sirf tab "personal" likhte hain jab profile mein kind hai hi nahi.
                    let kind = match current_kind(&uid).await {
                        Some(k) => k,
                        None => {
                            stamp_kind(&uid, &mail, "personal").await;
                            "personal".to_string()
                        }
                    };
                    return crate::ok(json!({ "id": oid, "kind": kind, "existing": true })).into_response();
                }
            }
            match create_org(&uid, "Personal mail", &mail, "personal", None).await {
                Ok(m) => {
                    stamp_kind(&uid, &mail, "personal").await;
                    crate::ok(json!({ "id": m.id, "name": m.name, "slug": m.slug, "domain": m.domain, "kind": m.kind })).into_response()
                }
                Err(e) => fail(StatusCode::INTERNAL_SERVER_ERROR, "personal_workspace_failed", &e),
            }
        }
        "workspace.organisations" => {
            let name = st(input, "name").trim().to_string();
            if !c::org_name_ok(&name) {
                return fail(StatusCode::BAD_REQUEST, "bad_name", "Organisation name is required.");
            }
            let domain = match c::normalize_org_domain(&st(input, "domain")) {
                Ok(d) => d,
                Err(m) => return fail(StatusCode::BAD_REQUEST, "bad_domain", m),
            };
            match create_org(&uid, &name, &mail, "business", Some(domain)).await {
                Ok(m) => {
                    stamp_kind(&uid, &mail, "business").await;
                    crate::ok(json!({ "id": m.id, "name": m.name, "slug": m.slug, "domain": m.domain, "kind": m.kind })).into_response()
                }
                Err(e) => fail(StatusCode::INTERNAL_SERVER_ERROR, "operational_workspace_failed", &e),
            }
        }
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", "unknown proc"),
    }
}
