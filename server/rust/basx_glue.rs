// ============================================================================
// basx_glue — Basic baaqi chhote endpoints, Rust PRIMARY (Tokio async; /rpc + /wt/rpc; Rule 52/56/57). Sab plans (Basic + Pro).
//   storage.state | storage.preflight | storage.reserve | storage.commit | storage.release   (Bun storage.ts; DB truth: storage_* functions)
//   support.sla (PUBLIC, landing) | support.drafts{org_id} | support.draftDiscard{id}         (Bun support.ts)
//   dashboard.ai-usage                                                                         (Bun dashboard.ts /ai-usage)
//   workspace.setActive{organisation_id}                                                      (Bun workspace.ts PATCH /active-organisation)
// LOOPHOLE FIX: Bun ke support/drafts aur draftDiscard BINA login ke chalte the (koi bhi org_id likh kar drafts padh/discard kar
// sakta tha). Rust mein login + org membership zaroori hai. Storage preflight/reserve "allowed:false" par 200 + body deta hai
// (Bun 413 deta tha; Rule 59: client 4xx par dobara Bun nahi jata, isliye jawab ka body hi sach hai).
// ============================================================================

use crate::basx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::owns_name(proc)
}

pub fn public_owns(proc: &str) -> bool {
    c::public_name(proc)
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

pub async fn public(proc: &str, _input: &Value) -> Resp {
    if proc != "support.sla" {
        return fail(StatusCode::NOT_FOUND, "unknown_proc", "unknown proc");
    }
    let data = match crate::sb_rpc("sla_public", json!({ "_days": 30 })).await {
        Ok(v) => v,
        Err(e) => return fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e),
    };
    let row = match &data {
        Value::Array(a) => a.first().cloned().unwrap_or(Value::Null),
        o => o.clone(),
    };
    let n = |k: &str| row.get(k).and_then(|x| x.as_f64().or_else(|| x.as_str().and_then(|s| s.parse().ok())));
    crate::ok(json!({
        "avg_first_reply_seconds": n("avg_first_reply_seconds").filter(|x| *x != 0.0),
        "resolved_count": n("resolved_count").unwrap_or(0.0),
        "window_days": n("window_days").unwrap_or(30.0),
        "resolution_rate": n("resolution_rate"),
    }))
    .into_response()
}

/// Storage ke liye workspace. Chat-entitled user: chat_ensure_workspace. Basic (chat nahi): pehle se maujood chat_members workspace,
/// warna None => plan-based jawab (neeche). Pehle yeh Basic ko 500 deta tha (DB 'chat_not_entitled' raise karta hai).
async fn workspace_of(token: &str) -> Result<(String, String, Option<String>), Resp> {
    let (id, email) = match crate::auth_user(token).await {
        Some(v) => v,
        None => return Err(fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid")),
    };
    let name = email.split('@').nth(1).filter(|d| !d.is_empty()).unwrap_or("Workspace").to_string();
    match crate::sb_rpc("chat_ensure_workspace", json!({ "_user": id, "_name": name })).await {
        Ok(v) => Ok((id, email, Some(v.as_str().unwrap_or_default().to_string()))),
        Err(e) if c::is_not_entitled(&e) => {
            let m = first(crate::sb_select(&format!("chat_members?select=workspace_id&user_id=eq.{}&limit=1", enc(&id))).await);
            let ws = m.and_then(|r| r.get("workspace_id").and_then(|x| x.as_str()).map(|s| s.to_string())).filter(|s| !s.is_empty());
            Ok((id, email, ws))
        }
        Err(e) => Err(fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e)),
    }
}

/// Plan ki storage_plans row (Basic jaise users ke liye, jinka koi chat workspace nahi).
async fn plan_row(user: &str, email: &str) -> (String, Option<Value>) {
    let plan = crate::sb_rpc("resolve_plan", json!({ "_user_id": user, "_email": email }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .unwrap_or_else(|| "basic".into());
    let wanted = [plan.clone(), "trial".to_string()];
    for p in wanted.iter() {
        if let Some(r) = first(crate::sb_select(&format!("storage_plans?select=*&plan_id=eq.{}&limit=1", enc(p))).await) {
            return (plan, Some(r));
        }
    }
    (plan, None)
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    match proc {
        "storage.state" | "storage.preflight" | "storage.reserve" | "storage.commit" | "storage.release" => {
            // pehle input jaanch (Bun jaisa), phir workspace
            let parsed = if proc == "storage.state" {
                None
            } else {
                match c::parse_storage(&st(input, "mailbox"), input.get("bytes").and_then(|x| x.as_f64()), &st(input, "kind")) {
                    Ok(t) => Some(t),
                    Err(d) => return fail(StatusCode::BAD_REQUEST, "bad_request", d),
                }
            };
            let (uid, email, ws) = match workspace_of(token).await {
                Ok(w) => w,
                Err(r) => return r,
            };
            let ws = match ws {
                Some(w) => w,
                None => {
                    // Basic: chat workspace nahi => plan ki hadd se jawab
                    let (plan, row) = plan_row(&uid, &email).await;
                    let g = |k: &str| row.as_ref().and_then(|r| r.get(k)).and_then(|x| x.as_i64());
                    return match proc {
                        "storage.state" => {
                            let pooled = g("pooled_bytes");
                            crate::ok(json!({
                                "plan": plan,
                                "model": if pooled.is_some() { "pooled" } else { "per_mailbox" },
                                "mailbox_limit": g("mailbox_limit"),
                                "max_send_bytes": g("max_send_bytes"),
                                "pool": pooled.map(|q| json!({ "quota_bytes": q, "used_bytes": 0, "remaining_bytes": q, "percent": 0 })),
                                "mailboxes": [],
                            }))
                            .into_response()
                        }
                        "storage.preflight" | "storage.reserve" => {
                            let (_m, bytes, kind) = parsed.unwrap_or_default();
                            let (allowed, code, reason) = c::plan_preflight(&kind, bytes, g("max_send_bytes"));
                            crate::ok(json!({ "allowed": allowed, "code": code, "reason": reason, "limit_bytes": g("max_send_bytes") })).into_response()
                        }
                        "storage.commit" => crate::ok(json!({ "ok": true, "accounted": false })).into_response(),
                        _ => crate::ok(json!({ "ok": true })).into_response(),
                    };
                }
            };
            if proc == "storage.state" {
                return match crate::sb_rpc("storage_state", json!({ "_workspace": ws })).await {
                    Ok(v) => crate::ok(v).into_response(),
                    Err(e) => fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e),
                };
            }
            let (mailbox, bytes, kind) = parsed.unwrap_or_default();
            let r = match proc {
                "storage.preflight" => crate::sb_rpc("storage_can_accept", json!({ "_workspace": ws, "_mailbox": mailbox, "_bytes": bytes, "_kind": kind })).await,
                "storage.reserve" => crate::sb_rpc("storage_reserve", json!({ "_workspace": ws, "_mailbox": mailbox, "_bytes": bytes, "_kind": kind })).await,
                "storage.commit" => {
                    let was = input.get("was_reserved").and_then(|x| x.as_bool()).unwrap_or(true);
                    crate::sb_rpc("storage_commit", json!({ "_workspace": ws, "_mailbox": mailbox, "_bytes": bytes, "_kind": kind, "_was_reserved": was })).await
                }
                _ => crate::sb_rpc("storage_release", json!({ "_workspace": ws, "_mailbox": mailbox, "_bytes": bytes })).await,
            };
            match r {
                Ok(v) => crate::ok(if proc == "storage.release" { json!({ "ok": true }) } else { v }).into_response(),
                Err(e) => fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e),
            }
        }
        "support.drafts" | "support.draftDiscard" => {
            let me = match crate::mail_identity(token, &st(input, "org_id")).await {
                Ok(m) => m,
                Err((status, code, msg)) => return fail(status, code, &msg),
            };
            let oq = enc(&me.org_id);
            match proc {
                "support.drafts" => match crate::sb_select(&format!("leo_email_drafts?select=*&org_id=eq.{oq}&state=eq.pending&order=created_at.desc&limit=50")).await {
                    Ok(v) => crate::ok(json!({ "drafts": v })).into_response(),
                    Err(e) => fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e),
                },
                "support.draftDiscard" => {
                    let id = match c::safe_id(&st(input, "id")) {
                        Some(i) => i,
                        None => return fail(StatusCode::BAD_REQUEST, "id_required", "id required"),
                    };
                    // sirf apni org ka draft (Bun mein koi org check nahi tha)
                    match crate::sb_patch(&format!("leo_email_drafts?id=eq.{}&org_id=eq.{oq}", enc(&id)), json!({ "state": "discarded" })).await {
                        Ok(_) => crate::ok(json!({ "ok": true })).into_response(),
                        Err(e) => fail(StatusCode::INTERNAL_SERVER_ERROR, "db_error", &e),
                    }
                }
                _ => fail(StatusCode::NOT_FOUND, "unknown_proc", "unknown proc"),
            }
        }
        "workspace.setActive" => {
            let (uid, _email) = match crate::auth_user(token).await {
                Some(v) => v,
                None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid"),
            };
            let org = st(input, "organisation_id").trim().to_string();
            let org = match c::safe_id(&org) {
                Some(o) => o,
                None => return fail(StatusCode::BAD_REQUEST, "organisation_id_required", "organisation_id_required"),
            };
            let q_acc = format!("account_org_members?select=org_id&user_id=eq.{}&org_id=eq.{}&limit=1", enc(&uid), enc(&org));
            let q_ops = format!("org_members?select=org_id&user_id=eq.{}&org_id=eq.{}&limit=1", enc(&uid), enc(&org));
            let (a, b) = tokio::join!(crate::sb_select(&q_acc), crate::sb_select(&q_ops));
            if first(a).is_none() && first(b).is_none() {
                return fail(StatusCode::CONFLICT, "not_found", "Organisation not found");
            }
            let prof = first(crate::sb_select(&format!("account_profiles?select=preferences&user_id=eq.{}&limit=1", enc(&uid))).await);
            let mut prefs = prof.and_then(|p| p.get("preferences").cloned()).filter(|p| p.is_object()).unwrap_or(json!({}));
            prefs["active_organisation_id"] = json!(org);
            match crate::sb_upsert("account_profiles", "user_id", json!({ "user_id": uid, "preferences": prefs, "updated_at": chrono_now() })).await {
                Ok(_) => crate::ok(json!({ "ok": true, "active_organisation_id": org })).into_response(),
                Err(_) => fail(StatusCode::INTERNAL_SERVER_ERROR, "active_organisation_update_failed", "active_organisation_update_failed"),
            }
        }
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", "unknown proc"),
    }
}

fn chrono_now() -> String {
    // RFC3339 UTC bina chrono crate ke: Postgres `now()` default nahi, isliye SystemTime se.
    let d = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0) as i64;
    let (days, secs) = (d.div_euclid(86400), d.rem_euclid(86400));
    // civil-from-days (Howard Hinnant)
    let z = days + 719468;
    let era = z.div_euclid(146097);
    let doe = z.rem_euclid(146097);
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let dd = doy - (153 * mp + 2) / 5 + 1;
    let mm = if mp < 10 { mp + 3 } else { mp - 9 };
    let yy = if mm <= 2 { y + 1 } else { y };
    format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z", yy, mm, dd, secs / 3600, (secs % 3600) / 60, secs % 60)
}
