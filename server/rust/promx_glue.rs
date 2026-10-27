// ============================================================================
// promx_glue — compose "Business Outcomes" (Pro+) Rust PRIMARY, Tokio async (Rule 52: wahi dispatch HTTP /rpc/<proc> AUR WebTransport /wt/rpc).
//   commit.record {phrase,action,due,thread_id,subject,exact,confidence,lang,to[],with_event,client_tag} -> {ok,duplicate,promise_id,task_id,event_id,ledger_id,seq,seal}
//   commit.status {promise_id,status,new_due?}   -> {ok,status,seq,seal}        (fulfilled | broken | snoozed | cancelled)
//   commit.list {}                                -> {commitments:[...]}         (apne khule wade, due ke hisaab se)
//   commit.verify {}                              -> {ok,rows,head}              (HMAC-SHA256 chain dobara hisaab; kharab to bad_seq)
//   commit.economics {thread_id?,words,recipients,call_accepted?} -> attention_estimate + log id   (send par)
//   commit.rate {} / commit.rateSet {rate_minor_per_hour,wpm,currency}  -> org ka hourly rate (default £60/ghanta)
// SQL E97 PEHLE (commitment_record, commitment_set_status, commitment_verify, attention_estimate, thread_economics_record, org_attention_rates).
// Gate Pro+ (Basic 403 feature_not_available). Hisaab promx_core.rs (std-only, tested).
// ============================================================================

use crate::promx_core as c;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    c::owns_name(proc)
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn num(v: &Value, k: &str) -> i64 {
    v.get(k).and_then(|x| x.as_i64().or_else(|| x.as_f64().map(|f| f as i64))).unwrap_or(0)
}

fn flag(v: &Value, k: &str) -> bool {
    v.get(k).and_then(|x| x.as_bool()).unwrap_or(false)
}

fn enc(v: &str) -> String {
    v.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') { (b as char).to_string() } else { format!("%{:02X}", b) })
        .collect()
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    if !owns(proc) {
        return fail(StatusCode::NOT_FOUND, "unknown_proc", proc);
    }
    let me = match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(m) => m,
        Err((s, code, m)) => return crate::err(s, code, &m).into_response(),
    };
    let plan = crate::sb_rpc("resolve_plan", json!({ "_user_id": me.id, "_email": me.email }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .unwrap_or_else(|| "basic".to_string());
    if !crate::workx_core::plan_allows_pro(&plan) {
        return fail(StatusCode::FORBIDDEN, "feature_not_available", c::NO_ACCESS);
    }
    if me.org_id.is_empty() {
        return fail(StatusCode::CONFLICT, "no_workspace", "No workspace");
    }
    match proc {
        "commit.record" => record(&me, input).await,
        "commit.status" => status(&me, input).await,
        "commit.list" => list(&me).await,
        "commit.verify" => verify(&me).await,
        "commit.economics" => economics(&me, input).await,
        "commit.rate" => rate(&me).await,
        "commit.rateSet" => rate_set(&me, input).await,
        // 404 sirf "yeh proc Rust ke paas nahi" (Rule 59); baaqi domain errors 400/409.
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    }
}

async fn record(me: &crate::MailMe, input: &Value) -> Resp {
    let Some(phrase) = c::clean_phrase(&st(input, "phrase")) else {
        return fail(StatusCode::BAD_REQUEST, "phrase_required", "Promise text must be 4-1000 characters");
    };
    let due = match st(input, "due") {
        d if d.trim().is_empty() => Value::Null,
        d => match c::clean_date(&d) {
            Some(ok) => json!(ok),
            None => return fail(StatusCode::BAD_REQUEST, "bad_due", "due must be a real date, YYYY-MM-DD"),
        },
    };
    let thread = st(input, "thread_id");
    let thread_v = if thread.is_empty() {
        Value::Null
    } else if c::uuid_ok(&thread) {
        json!(thread)
    } else {
        return fail(StatusCode::BAD_REQUEST, "bad_thread", "thread_id must be a uuid");
    };
    let to: Vec<String> = input.get("to").and_then(|x| x.as_array()).map(|a| a.iter().filter_map(|y| y.as_str().map(|s| s.to_string())).collect()).unwrap_or_default();
    let conf = c::clamp_conf(input.get("confidence").and_then(|x| x.as_f64()).unwrap_or(0.0));
    let body = json!({
        "p_org": me.org_id, "p_user": me.id, "p_phrase": phrase,
        "p_action": c::clean_action(&st(input, "action"), &phrase),
        "p_due": due, "p_thread": thread_v,
        "p_subject": st(input, "subject").chars().take(300).collect::<String>(),
        "p_exact": flag(input, "exact"), "p_confidence": conf, "p_lang": c::lang_of(&st(input, "lang")),
        "p_to": c::clean_to(&to), "p_with_event": flag(input, "with_event"),
        "p_client_tag": st(input, "client_tag").chars().take(128).collect::<String>(),
    });
    match crate::sb_rpc("commitment_record", body).await {
        Ok(v) => crate::ok(v).into_response(),
        Err(e) => fail(StatusCode::CONFLICT, "record_failed", &format!("{}", e.chars().take(200).collect::<String>())),
    }
}

async fn status(me: &crate::MailMe, input: &Value) -> Resp {
    let id = st(input, "promise_id");
    let s = st(input, "status");
    if !c::uuid_ok(&id) || !c::valid_status(&s) {
        return fail(StatusCode::BAD_REQUEST, "bad_request", "promise_id (uuid) and status (fulfilled|broken|snoozed|cancelled) required");
    }
    // Pro = sirf apna wada (owner = user id); doosre ka nahi.
    let own = crate::sb_select(&format!("work_promises?select=id&id=eq.{}&org_id=eq.{}&owner=eq.{}&limit=1", enc(&id), enc(&me.org_id), enc(&me.id))).await;
    if own.ok().and_then(|v| v.as_array().map(|a| a.is_empty())).unwrap_or(true) {
        return fail(StatusCode::CONFLICT, "not_found", "Promise not found");
    }
    let new_due = match st(input, "new_due") {
        d if d.trim().is_empty() => Value::Null,
        d => match c::clean_date(&d) {
            Some(ok) => json!(ok),
            None => return fail(StatusCode::BAD_REQUEST, "bad_due", "new_due must be YYYY-MM-DD"),
        },
    };
    match crate::sb_rpc("commitment_set_status", json!({ "p_org": me.org_id, "p_user": me.id, "p_promise": id, "p_status": s, "p_new_due": new_due })).await {
        Ok(v) => {
            if v.get("ok").and_then(|x| x.as_bool()) == Some(false) {
                fail(StatusCode::CONFLICT, v.get("error").and_then(|x| x.as_str()).unwrap_or("status_failed"), "Could not change the promise")
            } else {
                crate::ok(v).into_response()
            }
        }
        Err(e) => fail(StatusCode::CONFLICT, "status_failed", &e.chars().take(200).collect::<String>()),
    }
}

async fn list(me: &crate::MailMe) -> Resp {
    let q = format!("v_commitments_open?select=*&org_id=eq.{}&owner=eq.{}&order=due_at.asc.nullslast&limit=200", enc(&me.org_id), enc(&me.id));
    match crate::sb_select(&q).await {
        Ok(v) => crate::ok(json!({ "commitments": v })).into_response(),
        Err(e) => fail(StatusCode::CONFLICT, "list_failed", &e.chars().take(200).collect::<String>()),
    }
}

async fn verify(me: &crate::MailMe) -> Resp {
    match crate::sb_rpc("commitment_verify", json!({ "p_org": me.org_id })).await {
        Ok(v) => crate::ok(v).into_response(),
        Err(e) => fail(StatusCode::CONFLICT, "verify_failed", &e.chars().take(200).collect::<String>()),
    }
}

async fn economics(me: &crate::MailMe, input: &Value) -> Resp {
    let (words, rcpt) = c::clamp_counts(num(input, "words"), num(input, "recipients"));
    let thread = st(input, "thread_id");
    let thread_v = if c::uuid_ok(&thread) { json!(thread) } else { Value::Null };
    let body = json!({ "p_org": me.org_id, "p_user": me.id, "p_thread": thread_v, "p_words": words, "p_recipients": rcpt, "p_call_accepted": flag(input, "call_accepted") });
    match crate::sb_rpc("thread_economics_record", body).await {
        Ok(v) => crate::ok(v).into_response(),
        Err(e) => fail(StatusCode::CONFLICT, "economics_failed", &e.chars().take(200).collect::<String>()),
    }
}

async fn rate(me: &crate::MailMe) -> Resp {
    let row = crate::sb_select(&format!("org_attention_rates?select=currency,rate_minor_per_hour,wpm&org_id=eq.{}&limit=1", enc(&me.org_id))).await.ok().and_then(|v| v.as_array().and_then(|a| a.first().cloned()));
    crate::ok(row.unwrap_or(json!({ "currency": "GBP", "rate_minor_per_hour": 6000, "wpm": 220 }))).into_response()
}

async fn rate_set(me: &crate::MailMe, input: &Value) -> Resp {
    let (r, w, cur) = (num(input, "rate_minor_per_hour"), num(input, "wpm"), st(input, "currency"));
    if !c::rate_ok(r) || !c::wpm_ok(if w == 0 { 220 } else { w }) || !c::currency_ok(&cur) {
        return fail(StatusCode::BAD_REQUEST, "bad_rate", "rate_minor_per_hour 100-1000000, wpm 60-600, currency 3 capital letters");
    }
    let row = json!({ "org_id": me.org_id, "currency": cur, "rate_minor_per_hour": r, "wpm": if w == 0 { 220 } else { w }, "updated_by": me.id, "updated_at": crate::cal_core::fmt_rfc3339(std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)) });
    match crate::sb_upsert("org_attention_rates", "org_id", row).await {
        Ok(_) => crate::ok(json!({ "ok": true })).into_response(),
        Err(e) => fail(StatusCode::CONFLICT, "rate_failed", &e.chars().take(200).collect::<String>()),
    }
}
