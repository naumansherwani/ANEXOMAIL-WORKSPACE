// ============================================================================
// team_glue.rs — the I/O half of "invite people, manage who is in the organisation, and Teams" (Rust-first).
//
// Procedures (all scoped to the CALLER'S organisation; the browser is never trusted for role or organisation):
//   public    team.invite.lookup       token -> "which organisation, which role" (the join page, before sign-in)
//   signed in team.invite.accept       token -> joins (atomic, SQL function team_invite_accept; role comes from the invitation row)
//             team.invites.mine        pending invitations for the caller's VERIFIED e-mail
//             team.members.list / update / remove
//             team.invites.list / create / revoke / resend
//             team.teams.list / create / delete / members / setMembers
//
// Rules (core: team_core.rs, unit-tested):
//   * owner/admin manage people; an admin cannot create admins or touch other admins; nobody edits an owner or themselves;
//   * an invitation e-mail is a real e-mail through the local Postfix (DKIM signed), never a promise — every address
//     reports sent / failed, the ledger (org_invitations) keeps the link and the SMTP error so "Resend" works;
//   * removing a member deletes the org_members row (every code path that joins org_members stops at once) and logs it;
//   * every people change is written to org_people_log (append-only).
//
// Child module of the crate root (main.rs): it uses `crate::sb`, `crate::sb_rpc`, `crate::auth_user`, `crate::ok`,
// `crate::err`, `crate::env_var`. No new dependency: axum, serde_json, reqwest and tokio are already in main.rs.
// ============================================================================

use crate::team_core as tc;
use axum::{http::StatusCode, response::IntoResponse};
use serde_json::{json, Value};
use std::collections::HashSet;
use std::time::Duration;

type Resp = axum::response::Response;

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "team.invite.accept"
            | "team.invites.mine"
            | "team.members.list"
            | "team.members.update"
            | "team.members.remove"
            | "team.invites.list"
            | "team.invites.create"
            | "team.invites.revoke"
            | "team.invites.resend"
            | "team.teams.list"
            | "team.teams.create"
            | "team.teams.delete"
            | "team.teams.members"
            | "team.teams.setMembers"
    )
}

pub fn public_owns(proc: &str) -> bool {
    proc == "team.invite.lookup"
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Resp {
    crate::err(status, code, msg).into_response()
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn app_url() -> String {
    let v = crate::env_var("ANEXOMAIL_APP_URL");
    if v.starts_with("https://") {
        v.trim_end_matches('/').to_string()
    } else {
        "https://anexomail.com".to_string()
    }
}

/// System sender for invitation mail (replies go to the inviter).
fn invite_from() -> String {
    let v = crate::env_var("TEAM_INVITE_FROM");
    if tc::valid_email(&v) {
        v.trim().to_lowercase()
    } else {
        "no-reply@anexomail.com".to_string()
    }
}

/* ----------------------------------------------------------------- REST */

/// One PostgREST call with the service key. `prefer` is the Prefer header ("" = none).
async fn rest(
    method: &str,
    path: &str,
    body: Option<Value>,
    prefer: &str,
) -> Result<Value, String> {
    let (url, key) = crate::sb().ok_or_else(|| "supabase_not_configured".to_string())?;
    let client = reqwest::Client::new();
    let target = format!("{url}/rest/v1/{path}");
    let mut req = match method {
        "POST" => client.post(target),
        "PATCH" => client.patch(target),
        "DELETE" => client.delete(target),
        _ => client.get(target),
    }
    .header("apikey", &key)
    .header("authorization", format!("Bearer {key}"));
    if !prefer.is_empty() {
        req = req.header("prefer", prefer);
    }
    if let Some(b) = body {
        req = req.header("content-type", "application/json").json(&b);
    }
    let res = req.send().await.map_err(|e| e.to_string())?;
    let status = res.status();
    let payload: Value = res.json().await.unwrap_or(Value::Null);
    if !status.is_success() {
        return Err(payload.to_string());
    }
    Ok(payload)
}

fn rows(v: &Value) -> Vec<Value> {
    v.as_array().cloned().unwrap_or_default()
}

/// Supabase Auth: id, e-mail and whether that e-mail is CONFIRMED (a stranger who signs up with somebody else's
/// address without confirming it must never see that person's invitations).
async fn auth_verified(token: &str) -> Option<(String, String, bool)> {
    let (url, key) = crate::sb()?;
    let res = reqwest::Client::new()
        .get(format!("{url}/auth/v1/user"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {token}"))
        .send()
        .await
        .ok()?;
    if !res.status().is_success() {
        return None;
    }
    let body: Value = res.json().await.ok()?;
    let id = st(&body, "id");
    if id.is_empty() {
        return None;
    }
    let email = st(&body, "email").trim().to_lowercase();
    let confirmed =
        !st(&body, "email_confirmed_at").is_empty() || !st(&body, "confirmed_at").is_empty();
    Some((id, email, confirmed))
}

/// Supabase Auth admin: a member's e-mail when org_members.email is empty (old rows). Best effort.
async fn auth_email_of(user_id: &str) -> Option<String> {
    let (url, key) = crate::sb()?;
    let res = reqwest::Client::new()
        .get(format!("{url}/auth/v1/admin/users/{user_id}"))
        .header("apikey", &key)
        .header("authorization", format!("Bearer {key}"))
        .send()
        .await
        .ok()?;
    if !res.status().is_success() {
        return None;
    }
    let body: Value = res.json().await.ok()?;
    let e = st(&body, "email").trim().to_lowercase();
    if e.is_empty() {
        None
    } else {
        Some(e)
    }
}

/* ------------------------------------------------------------------ ctx */

struct Ctx {
    id: String,
    email: String,
    org_id: String,
    org_name: String,
    role: String,
}

/// Who is asking, in which organisation, with which role. Revoked memberships do not count.
async fn ctx(token: &str, input: &Value) -> Result<Ctx, Resp> {
    let (id, email) = match crate::auth_user(token).await {
        Some(x) => x,
        None => {
            return Err(fail(
                StatusCode::UNAUTHORIZED,
                "unauthorized",
                "Session invalid",
            ))
        }
    };
    if !tc::is_uuid(&id) {
        return Err(fail(
            StatusCode::UNAUTHORIZED,
            "unauthorized",
            "Session invalid",
        ));
    }
    let mine = rest(
        "GET",
        &format!("org_members?select=*&user_id=eq.{}", tc::pct(&id)),
        None,
        "",
    )
    .await
    .map_err(|_| {
        fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "server_error",
            "Could not read your workspace",
        )
    })?;
    let live: Vec<Value> = rows(&mine)
        .into_iter()
        .filter(|m| !st(m, "org_id").is_empty() && st(m, "status") != "revoked")
        .collect();
    if live.is_empty() {
        return Err(fail(StatusCode::CONFLICT, "no_workspace", "no_workspace"));
    }
    let requested = st(input, "org_id");
    let pick = live
        .iter()
        .find(|m| !requested.is_empty() && st(m, "org_id") == requested)
        .unwrap_or(&live[0]);
    let org_id = st(pick, "org_id");
    let role = {
        let r = st(pick, "role");
        if r.is_empty() {
            "member".to_string()
        } else {
            r
        }
    };
    let org_name = rest(
        "GET",
        &format!("organisations?select=name&id=eq.{}", tc::pct(&org_id)),
        None,
        "",
    )
    .await
    .ok()
    .and_then(|v| rows(&v).first().map(|o| st(o, "name")))
    .unwrap_or_default();
    Ok(Ctx {
        id,
        email: email.trim().to_lowercase(),
        org_id,
        org_name,
        role,
    })
}

fn need_manage(c: &Ctx) -> Option<Resp> {
    if tc::can_manage(&c.role) {
        None
    } else {
        Some(fail(
            StatusCode::FORBIDDEN,
            "organisation_admin_required",
            "Only an owner or admin can do this.",
        ))
    }
}

/// Append-only people log. Never fails the action it describes.
async fn log(c: &Ctx, action: &str, target: &str, detail: Value) {
    let _ = rest(
        "POST",
        "org_people_log",
        Some(json!({ "org_id": c.org_id, "actor": c.email, "action": action, "target": target, "detail": detail })),
        "return=minimal",
    )
    .await;
}

/* ----------------------------------------------------------------- SMTP */

async fn smtp_reply(s: &mut tokio::net::TcpStream) -> Result<(u16, String), String> {
    use tokio::io::AsyncReadExt;
    let mut acc = String::new();
    loop {
        let mut buf = [0u8; 2048];
        let n = tokio::time::timeout(Duration::from_secs(15), s.read(&mut buf))
            .await
            .map_err(|_| "smtp read timeout".to_string())?
            .map_err(|e| e.to_string())?;
        if n == 0 {
            return Err("smtp connection closed".to_string());
        }
        acc.push_str(&String::from_utf8_lossy(&buf[..n]));
        if let Some(code) = tc::smtp_reply_code(&acc) {
            return Ok((code, acc.trim().to_string()));
        }
        if acc.len() > 16_384 {
            return Err("smtp reply too long".to_string());
        }
    }
}

async fn smtp_cmd(
    s: &mut tokio::net::TcpStream,
    line: &str,
    want: &[u16],
) -> Result<String, String> {
    use tokio::io::AsyncWriteExt;
    s.write_all(format!("{}\r\n", line).as_bytes())
        .await
        .map_err(|e| e.to_string())?;
    let (code, text) = smtp_reply(s).await?;
    if want.contains(&code) {
        Ok(text)
    } else {
        Err(format!(
            "{} -> {}",
            line.split(' ').next().unwrap_or(""),
            text
        ))
    }
}

/// Local Postfix (127.0.0.1:25, mynetworks) — the same path Brain's mail/sendmail.ts uses: DKIM signing + delivery by Postfix.
async fn smtp_send(from: &str, rcpt: &str, raw: &str) -> Result<String, String> {
    use tokio::io::AsyncWriteExt;
    let host = {
        let h = crate::env_var("MAIL_SMTP_HOST");
        if h.is_empty() {
            "127.0.0.1".to_string()
        } else {
            h
        }
    };
    let port: u16 = crate::env_var("MAIL_SMTP_PORT").parse().unwrap_or(25);
    let mut sock = tokio::time::timeout(
        Duration::from_secs(8),
        tokio::net::TcpStream::connect((host.as_str(), port)),
    )
    .await
    .map_err(|_| "smtp connect timeout".to_string())?
    .map_err(|e| format!("smtp connect: {}", e))?;
    let (code, greeting) = smtp_reply(&mut sock).await?;
    if code != 220 {
        return Err(format!("greeting -> {}", greeting));
    }
    smtp_cmd(&mut sock, "EHLO anexomail.com", &[250]).await?;
    smtp_cmd(&mut sock, &format!("MAIL FROM:<{}>", from), &[250]).await?;
    smtp_cmd(&mut sock, &format!("RCPT TO:<{}>", rcpt), &[250, 251]).await?;
    smtp_cmd(&mut sock, "DATA", &[354]).await?;
    let body = format!("{}.\r\n", tc::dot_stuff(raw));
    sock.write_all(body.as_bytes())
        .await
        .map_err(|e| e.to_string())?;
    let (code, text) = smtp_reply(&mut sock).await?;
    if code >= 400 {
        return Err(format!("message refused -> {}", text));
    }
    let _ = smtp_cmd(&mut sock, "QUIT", &[221, 250]).await;
    Ok(text)
}

/// E-mails one invitation (a row of org_invitations) and records the outcome on the row.
async fn deliver(c: &Ctx, inv: &Value) -> Result<(), String> {
    let id = st(inv, "id");
    let to = st(inv, "email");
    let tok = st(inv, "token");
    if !tc::valid_email(&to) || !tc::is_uuid(&tok) {
        return Err("invitation row is not valid".to_string());
    }
    let stamp = now();
    let expires = tc::parse_ts(&st(inv, "expires_at")).unwrap_or(stamp + 14 * 86400);
    let link = format!("{}/join?t={}", app_url(), tok);
    let role = st(inv, "role");
    let invite = tc::Invite {
        org_name: if c.org_name.is_empty() {
            "an organisation"
        } else {
            &c.org_name
        },
        inviter: &c.email,
        role: &role,
        to: &to,
        link: &link,
        expires_epoch: expires,
    };
    let from = invite_from();
    let message_id = format!("team.{}.{}@anexomail.com", id.replace('-', ""), stamp);
    let raw = tc::build_invite_mail(&invite, &c.email, &from, &c.email, &message_id, stamp);
    let sent = smtp_send(&from, &to, &raw).await;
    let count = inv
        .get("invite_count")
        .and_then(|v| v.as_i64())
        .unwrap_or(0)
        + 1;
    let patch = match &sent {
        Ok(_) => {
            json!({ "last_sent_at": tc::fmt_iso(stamp), "invite_count": count, "send_error": Value::Null })
        }
        Err(e) => json!({ "send_error": tc::clean_line(e, 300) }),
    };
    let _ = rest(
        "PATCH",
        &format!("org_invitations?id=eq.{}", tc::pct(&id)),
        Some(patch),
        "return=minimal",
    )
    .await;
    sent.map(|_| ())
}

/* ------------------------------------------------------------ dispatch */

pub async fn public(proc: &str, input: &Value) -> Resp {
    match proc {
        "team.invite.lookup" => invite_lookup(input).await,
        _ => fail(StatusCode::NOT_FOUND, "unknown_proc", proc),
    }
}

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Resp {
    match proc {
        "team.invite.accept" => return invite_accept(token, input).await,
        "team.invites.mine" => return invites_mine(token).await,
        _ => {}
    }
    let c = match ctx(token, input).await {
        Ok(c) => c,
        Err(r) => return r,
    };
    match proc {
        "team.members.list" => members_list(&c).await,
        "team.members.update" => members_update(&c, input).await,
        "team.members.remove" => members_remove(&c, input).await,
        "team.invites.list" => invites_list(&c).await,
        "team.invites.create" => invites_create(&c, input).await,
        "team.invites.revoke" => invites_revoke(&c, input).await,
        "team.invites.resend" => invites_resend(&c, input).await,
        "team.teams.list" => teams_list(&c).await,
        "team.teams.create" => teams_create(&c, input).await,
        "team.teams.delete" => teams_delete(&c, input).await,
        "team.teams.members" => teams_members(&c, input).await,
        "team.teams.setMembers" => teams_set_members(&c, input).await,
        _ => fail(StatusCode::NOT_FOUND, "procedure_not_in_rust", proc),
    }
}

/* ----------------------------------------------------- join (token) */

fn token_of(input: &Value) -> Option<String> {
    let t = st(input, "token").trim().to_lowercase();
    if tc::is_uuid(&t) {
        Some(t)
    } else {
        None
    }
}

fn join_error(code: &str) -> Resp {
    match code {
        "revoked" => fail(
            StatusCode::GONE,
            "revoked",
            "This invitation was withdrawn by the organisation.",
        ),
        "expired" => fail(
            StatusCode::GONE,
            "expired",
            "This invitation has expired. Ask the organiser to send it again.",
        ),
        "used" => fail(
            StatusCode::CONFLICT,
            "used",
            "This invitation was already used by someone else.",
        ),
        _ => fail(
            StatusCode::NOT_FOUND,
            "invite_not_found",
            "This invitation link is not valid.",
        ),
    }
}

async fn invite_lookup(input: &Value) -> Resp {
    let Some(t) = token_of(input) else {
        return join_error("not_found");
    };
    match crate::sb_rpc("team_invite_lookup", json!({ "p_token": t })).await {
        Ok(v) if v.get("error").is_some() => join_error(&st(&v, "error")),
        Ok(v) => crate::ok(v).into_response(),
        Err(_) => fail(
            StatusCode::NOT_IMPLEMENTED,
            "team_v1_sql_missing",
            "Team invitations are not set up on the server yet.",
        ),
    }
}

async fn invite_accept(token: &str, input: &Value) -> Resp {
    let (id, email) = match crate::auth_user(token).await {
        Some(x) => x,
        None => return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid"),
    };
    let Some(t) = token_of(input) else {
        return join_error("not_found");
    };
    match crate::sb_rpc(
        "team_invite_accept",
        json!({ "p_token": t, "p_user_id": id, "p_email": email.trim().to_lowercase() }),
    )
    .await
    {
        Ok(v) if v.get("error").is_some() => join_error(&st(&v, "error")),
        Ok(v) => crate::ok(v).into_response(),
        Err(_) => fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "join_failed",
            "Could not add you to the organisation. Nothing was changed — please try again.",
        ),
    }
}

async fn invites_mine(token: &str) -> Resp {
    let Some((_id, email, verified)) = auth_verified(token).await else {
        return fail(StatusCode::UNAUTHORIZED, "unauthorized", "Session invalid");
    };
    if email.is_empty() || !verified {
        return crate::ok(json!({ "invitations": [], "verified": false })).into_response();
    }
    let q = format!(
        "org_invitations?select=token,role,expires_at,invited_by_email,org_id&email=eq.{}&status=eq.pending&expires_at=gt.{}&order=created_at.desc&limit=20",
        tc::pct(&email),
        tc::pct(&tc::fmt_iso(now()))
    );
    let found = match rest("GET", &q, None, "").await {
        Ok(v) => rows(&v),
        // tables not created yet (E33 not run): an empty list is the truth for the caller
        Err(_) => return crate::ok(json!({ "invitations": [], "verified": true })).into_response(),
    };
    let org_ids: Vec<String> = found
        .iter()
        .map(|r| st(r, "org_id"))
        .filter(|s| tc::is_uuid(s))
        .collect();
    let mut names: Vec<(String, String)> = Vec::new();
    if !org_ids.is_empty() {
        if let Ok(v) = rest(
            "GET",
            &format!(
                "organisations?select=id,name&{}",
                tc::in_filter("id", &org_ids)
            ),
            None,
            "",
        )
        .await
        {
            names = rows(&v)
                .iter()
                .map(|o| (st(o, "id"), st(o, "name")))
                .collect();
        }
    }
    let list: Vec<Value> = found
        .iter()
        .map(|r| {
            let oid = st(r, "org_id");
            let name = names
                .iter()
                .find(|(i, _)| *i == oid)
                .map(|(_, n)| n.clone())
                .unwrap_or_default();
            json!({
                "token": st(r, "token"), "org_name": name, "role": st(r, "role"),
                "invited_by": st(r, "invited_by_email"), "expires_at": st(r, "expires_at"),
            })
        })
        .collect();
    crate::ok(json!({ "invitations": list, "verified": true })).into_response()
}

/* ---------------------------------------------------------- members */

async fn members_list(c: &Ctx) -> Resp {
    let found = match rest(
        "GET",
        &format!("org_members?select=*&org_id=eq.{}", tc::pct(&c.org_id)),
        None,
        "",
    )
    .await
    {
        Ok(v) => rows(&v),
        Err(_) => {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "server_error",
                "Could not read members",
            )
        }
    };
    let mut out: Vec<(u8, String, Value)> = Vec::new();
    let mut healed = 0usize;
    for m in found.iter().filter(|m| st(m, "status") != "revoked") {
        let uid = st(m, "user_id");
        if uid.is_empty() {
            continue;
        }
        let mut email = st(m, "email").trim().to_lowercase();
        if email.is_empty() && healed < 25 {
            healed += 1;
            if let Some(e) = auth_email_of(&uid).await {
                // heal the row so the next call does not need Auth
                let _ = rest(
                    "PATCH",
                    &format!(
                        "org_members?org_id=eq.{}&user_id=eq.{}",
                        tc::pct(&c.org_id),
                        tc::pct(&uid)
                    ),
                    Some(json!({ "email": e })),
                    "return=minimal",
                )
                .await;
                email = e;
            }
        }
        let role = {
            let r = st(m, "role");
            if r.is_empty() {
                "member".to_string()
            } else {
                r
            }
        };
        let joined = ["created_at", "joined_at"]
            .iter()
            .map(|k| st(m, k))
            .find(|s| !s.is_empty());
        out.push((
            tc::rank(&role),
            email.clone(),
            json!({
                "id": uid, "user_id": uid, "email": email, "name": Value::Null, "role": role,
                "status": if st(m, "status").is_empty() { "active".to_string() } else { st(m, "status") },
                "joined_at": joined, "is_you": uid == c.id,
            }),
        ));
    }
    out.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)));
    let members: Vec<Value> = out.into_iter().map(|(_, _, v)| v).collect();
    crate::ok(json!({ "members": members })).into_response()
}

async fn target_member(c: &Ctx, input: &Value) -> Result<(String, String), Resp> {
    let id = st(input, "id").trim().to_lowercase();
    if !tc::is_uuid(&id) {
        return Err(fail(
            StatusCode::BAD_REQUEST,
            "bad_member",
            "Say which member.",
        ));
    }
    let found = rest(
        "GET",
        &format!(
            "org_members?select=user_id,role,status&org_id=eq.{}&user_id=eq.{}",
            tc::pct(&c.org_id),
            tc::pct(&id)
        ),
        None,
        "",
    )
    .await
    .map_err(|_| {
        fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "server_error",
            "Could not read the member",
        )
    })?;
    match rows(&found)
        .into_iter()
        .find(|m| st(m, "status") != "revoked")
    {
        Some(m) => {
            let r = st(&m, "role");
            Ok((
                id,
                if r.is_empty() {
                    "member".to_string()
                } else {
                    r
                },
            ))
        }
        None => Err(fail(
            StatusCode::NOT_FOUND,
            "member_not_found",
            "That person is not in this organisation.",
        )),
    }
}

fn change_refused(code: &str) -> Resp {
    match code {
        "cannot_edit_self" => fail(
            StatusCode::FORBIDDEN,
            code,
            "You cannot change or remove yourself here.",
        ),
        "owner_is_fixed" => fail(
            StatusCode::FORBIDDEN,
            code,
            "The owner cannot be changed or removed.",
        ),
        "role_not_allowed" => fail(StatusCode::FORBIDDEN, code, "You cannot give that role."),
        _ => fail(
            StatusCode::FORBIDDEN,
            "not_allowed",
            "You are not allowed to change this member.",
        ),
    }
}

async fn members_update(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let Some(new_role) =
        tc::parse_assignable(&st(input, "role")).filter(|_| !st(input, "role").trim().is_empty())
    else {
        return fail(
            StatusCode::BAD_REQUEST,
            "bad_role",
            "Choose admin, member or viewer.",
        );
    };
    let (uid, target_role) = match target_member(c, input).await {
        Ok(x) => x,
        Err(r) => return r,
    };
    if let Err(code) = tc::check_member_change(&c.role, &c.id, &target_role, &uid, Some(new_role)) {
        return change_refused(code);
    }
    if target_role == new_role {
        return crate::ok(json!({ "ok": true, "role": new_role, "changed": false }))
            .into_response();
    }
    let q = format!(
        "org_members?org_id=eq.{}&user_id=eq.{}",
        tc::pct(&c.org_id),
        tc::pct(&uid)
    );
    if rest(
        "PATCH",
        &q,
        Some(json!({ "role": new_role })),
        "return=minimal",
    )
    .await
    .is_err()
    {
        return fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "role_not_changed",
            "The role was not changed.",
        );
    }
    // account layer: best effort (its role check has no 'viewer')
    let _ = rest(
        "PATCH",
        &format!(
            "account_org_members?org_id=eq.{}&user_id=eq.{}",
            tc::pct(&c.org_id),
            tc::pct(&uid)
        ),
        Some(json!({ "role": if new_role == "viewer" { "member" } else { new_role } })),
        "return=minimal",
    )
    .await;
    log(
        c,
        "member.role",
        &uid,
        json!({ "from": target_role, "to": new_role }),
    )
    .await;
    crate::ok(json!({ "ok": true, "role": new_role, "changed": true })).into_response()
}

async fn members_remove(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let (uid, target_role) = match target_member(c, input).await {
        Ok(x) => x,
        Err(r) => return r,
    };
    if let Err(code) = tc::check_member_change(&c.role, &c.id, &target_role, &uid, None) {
        return change_refused(code);
    }
    let q = format!(
        "org_members?org_id=eq.{}&user_id=eq.{}",
        tc::pct(&c.org_id),
        tc::pct(&uid)
    );
    let mut soft = false;
    if rest("DELETE", &q, None, "return=minimal").await.is_err() {
        // a table that references the row: keep it, but end the access
        if rest(
            "PATCH",
            &q,
            Some(json!({ "status": "revoked" })),
            "return=minimal",
        )
        .await
        .is_err()
        {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "member_not_removed",
                "The member was not removed.",
            );
        }
        soft = true;
    }
    let _ = rest(
        "DELETE",
        &format!(
            "account_org_members?org_id=eq.{}&user_id=eq.{}",
            tc::pct(&c.org_id),
            tc::pct(&uid)
        ),
        None,
        "return=minimal",
    )
    .await;
    // out of this organisation's teams too
    if let Ok(t) = rest(
        "GET",
        &format!("org_teams?select=id&org_id=eq.{}", tc::pct(&c.org_id)),
        None,
        "",
    )
    .await
    {
        let ids: Vec<String> = rows(&t)
            .iter()
            .map(|r| st(r, "id"))
            .filter(|s| tc::is_uuid(s))
            .collect();
        if !ids.is_empty() {
            let _ = rest(
                "DELETE",
                &format!(
                    "org_team_members?user_id=eq.{}&{}",
                    tc::pct(&uid),
                    tc::in_filter("team_id", &ids)
                ),
                None,
                "return=minimal",
            )
            .await;
        }
    }
    log(
        c,
        "member.removed",
        &uid,
        json!({ "role": target_role, "soft": soft }),
    )
    .await;
    crate::ok(json!({ "ok": true, "removed": true })).into_response()
}

/* -------------------------------------------------------- invitations */

fn invite_row(r: &Value, t: i64) -> Value {
    let expires = st(r, "expires_at");
    let expired = tc::parse_ts(&expires).map(|e| e < t).unwrap_or(false);
    json!({
        "id": st(r, "id"), "email": st(r, "email"), "role": st(r, "role"), "expires_at": expires,
        "created_at": st(r, "created_at"), "last_sent_at": r.get("last_sent_at").cloned().unwrap_or(Value::Null),
        "send_error": r.get("send_error").cloned().unwrap_or(Value::Null),
        "invited_by": st(r, "invited_by_email"), "expired": expired,
    })
}

async fn invites_list(c: &Ctx) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let q = format!(
        "org_invitations?select=id,email,role,expires_at,created_at,last_sent_at,send_error,invited_by_email&org_id=eq.{}&status=eq.pending&order=created_at.desc&limit=200",
        tc::pct(&c.org_id)
    );
    match rest("GET", &q, None, "").await {
        Ok(v) => {
            let t = now();
            let list: Vec<Value> = rows(&v).iter().map(|r| invite_row(r, t)).collect();
            crate::ok(json!({ "invitations": list })).into_response()
        }
        Err(_) => fail(
            StatusCode::NOT_IMPLEMENTED,
            "team_v1_sql_missing",
            "Team invitations are not set up on the server yet.",
        ),
    }
}

async fn invites_create(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let Some(role) = tc::parse_assignable(&st(input, "role")) else {
        return fail(
            StatusCode::BAD_REQUEST,
            "bad_role",
            "Choose admin, member or viewer.",
        );
    };
    if !tc::can_assign(&c.role, role) {
        return fail(
            StatusCode::FORBIDDEN,
            "role_not_allowed",
            "Only the owner can invite admins.",
        );
    }
    let raw: Vec<String> = input
        .get("emails")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|x| x.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();
    if raw.is_empty() {
        return fail(
            StatusCode::BAD_REQUEST,
            "emails_required",
            "At least one e-mail address is required.",
        );
    }
    let org = tc::pct(&c.org_id);

    // who is already in / already invited
    let members: HashSet<String> = match rest(
        "GET",
        &format!("org_members?select=email,status&org_id=eq.{org}"),
        None,
        "",
    )
    .await
    {
        Ok(v) => rows(&v)
            .iter()
            .filter(|m| st(m, "status") != "revoked")
            .map(|m| st(m, "email").trim().to_lowercase())
            .filter(|e| !e.is_empty())
            .chain(std::iter::once(c.email.clone()))
            .collect(),
        Err(_) => {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "server_error",
                "Could not read members",
            )
        }
    };
    let pending: HashSet<String> = match rest(
        "GET",
        &format!("org_invitations?select=email&org_id=eq.{org}&status=eq.pending&limit=1000"),
        None,
        "",
    )
    .await
    {
        Ok(v) => rows(&v).iter().map(|r| st(r, "email")).collect(),
        Err(_) => {
            return fail(
                StatusCode::NOT_IMPLEMENTED,
                "team_v1_sql_missing",
                "Team invitations are not set up on the server yet.",
            )
        }
    };
    let plan = tc::plan_invites(&raw, &members, &pending);
    let todo = plan.fresh.len() + plan.resend.len();

    // daily cap on invitation e-mails (abuse guard), counted from the ledger
    if todo > 0 {
        let since = tc::fmt_iso(now() - 86400);
        let sent_today = rest(
            "GET",
            &format!(
                "org_invitations?select=id&org_id=eq.{org}&last_sent_at=gte.{}&limit=1000",
                tc::pct(&since)
            ),
            None,
            "",
        )
        .await
        .map(|v| rows(&v).len() as i64)
        .unwrap_or(0);
        if sent_today + todo as i64 > tc::DAILY_INVITE_CAP {
            return fail(
                StatusCode::TOO_MANY_REQUESTS,
                "daily_limit",
                &format!(
                    "At most {} invitation e-mails a day per organisation. Try again tomorrow.",
                    tc::DAILY_INVITE_CAP
                ),
            );
        }
    }

    let t = now();
    let expires = tc::fmt_iso(t + 14 * 86400);
    for e in &plan.fresh {
        let row = json!({
            "org_id": c.org_id, "email": e, "role": role, "invited_by": c.id,
            "invited_by_email": c.email, "expires_at": expires,
        });
        // a parallel request may have created it a moment ago: the pending-unique index refuses, the refresh below covers it
        let _ = rest("POST", "org_invitations", Some(row), "return=minimal").await;
    }
    if !plan.resend.is_empty() {
        let _ = rest(
            "PATCH",
            &format!(
                "org_invitations?org_id=eq.{org}&status=eq.pending&{}",
                tc::in_filter("email", &plan.resend)
            ),
            Some(json!({ "role": role, "expires_at": expires, "invited_by": c.id, "invited_by_email": c.email })),
            "return=minimal",
        )
        .await;
    }
    let all: Vec<String> = plan
        .fresh
        .iter()
        .chain(plan.resend.iter())
        .cloned()
        .collect();
    let mut sent: Vec<String> = Vec::new();
    let mut resent: Vec<String> = Vec::new();
    let mut failed: Vec<Value> = Vec::new();
    if !all.is_empty() {
        let q = format!(
            "org_invitations?select=id,email,token,role,expires_at,invite_count&org_id=eq.{org}&status=eq.pending&{}",
            tc::in_filter("email", &all)
        );
        let invs = match rest("GET", &q, None, "").await {
            Ok(v) => rows(&v),
            Err(_) => {
                return fail(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "server_error",
                    "Could not read the invitations",
                )
            }
        };
        for inv in &invs {
            let addr = st(inv, "email");
            match deliver(c, inv).await {
                Ok(()) => {
                    if plan.resend.contains(&addr) {
                        resent.push(addr);
                    } else {
                        sent.push(addr);
                    }
                }
                Err(e) => failed.push(json!({ "email": addr, "error": tc::clean_line(&e, 200) })),
            }
        }
        log(
            c,
            "invite.sent",
            &format!("{} address{}", all.len(), if all.len() == 1 { "" } else { "es" }),
            json!({ "role": role, "sent": sent.len(), "resent": resent.len(), "failed": failed.len() }),
        )
        .await;
    }
    crate::ok(json!({
        "ok": true,
        "role": role,
        "invited": sent,
        "resent": resent,
        "failed": failed,
        "already_member": plan.already_member,
        "invalid": plan.invalid,
        "duplicate": plan.duplicate,
        "over_cap": plan.over_cap,
    }))
    .into_response()
}

async fn pending_by_id(c: &Ctx, input: &Value) -> Result<Value, Resp> {
    let id = st(input, "id").trim().to_lowercase();
    if !tc::is_uuid(&id) {
        return Err(fail(
            StatusCode::BAD_REQUEST,
            "bad_invitation",
            "Say which invitation.",
        ));
    }
    let found = rest(
        "GET",
        &format!(
            "org_invitations?select=id,email,token,role,expires_at,invite_count&id=eq.{}&org_id=eq.{}&status=eq.pending",
            tc::pct(&id),
            tc::pct(&c.org_id)
        ),
        None,
        "",
    )
    .await
    .map_err(|_| fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Could not read the invitation"))?;
    rows(&found).into_iter().next().ok_or_else(|| {
        fail(
            StatusCode::NOT_FOUND,
            "invite_not_found",
            "That invitation is no longer pending.",
        )
    })
}

async fn invites_revoke(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let inv = match pending_by_id(c, input).await {
        Ok(v) => v,
        Err(r) => return r,
    };
    let q = format!(
        "org_invitations?id=eq.{}&org_id=eq.{}&status=eq.pending",
        tc::pct(&st(&inv, "id")),
        tc::pct(&c.org_id)
    );
    if rest(
        "PATCH",
        &q,
        Some(json!({ "status": "revoked" })),
        "return=minimal",
    )
    .await
    .is_err()
    {
        return fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "revoke_failed",
            "The invitation was not revoked.",
        );
    }
    log(c, "invite.revoked", &st(&inv, "email"), json!({})).await;
    crate::ok(json!({ "ok": true })).into_response()
}

async fn invites_resend(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let inv = match pending_by_id(c, input).await {
        Ok(v) => v,
        Err(r) => return r,
    };
    let expires = tc::fmt_iso(now() + 14 * 86400);
    let _ = rest(
        "PATCH",
        &format!("org_invitations?id=eq.{}", tc::pct(&st(&inv, "id"))),
        Some(json!({ "expires_at": expires })),
        "return=minimal",
    )
    .await;
    let mut fresh = inv.clone();
    if let Some(o) = fresh.as_object_mut() {
        o.insert("expires_at".to_string(), json!(expires));
    }
    match deliver(c, &fresh).await {
        Ok(()) => {
            log(c, "invite.resent", &st(&inv, "email"), json!({})).await;
            crate::ok(json!({ "ok": true, "sent": true })).into_response()
        }
        Err(e) => fail(
            StatusCode::BAD_GATEWAY,
            "send_failed",
            &format!(
                "The e-mail could not be sent ({}). The invitation is still valid — try again.",
                tc::clean_line(&e, 160)
            ),
        ),
    }
}

/* ------------------------------------------------------------- teams */

async fn team_ids_of(c: &Ctx) -> Result<Vec<Value>, Resp> {
    rest(
        "GET",
        &format!(
            "org_teams?select=id,name,slug,created_at&org_id=eq.{}&order=name.asc&limit=500",
            tc::pct(&c.org_id)
        ),
        None,
        "",
    )
    .await
    .map(|v| rows(&v))
    .map_err(|_| {
        fail(
            StatusCode::NOT_IMPLEMENTED,
            "team_v1_sql_missing",
            "Teams are not set up on the server yet.",
        )
    })
}

async fn teams_list(c: &Ctx) -> Resp {
    let teams = match team_ids_of(c).await {
        Ok(t) => t,
        Err(r) => return r,
    };
    let ids: Vec<String> = teams
        .iter()
        .map(|t| st(t, "id"))
        .filter(|s| tc::is_uuid(s))
        .collect();
    let mut counts: std::collections::HashMap<String, usize> = std::collections::HashMap::new();
    if !ids.is_empty() {
        if let Ok(v) = rest(
            "GET",
            &format!(
                "org_team_members?select=team_id&{}&limit=20000",
                tc::in_filter("team_id", &ids)
            ),
            None,
            "",
        )
        .await
        {
            for r in rows(&v) {
                *counts.entry(st(&r, "team_id")).or_insert(0) += 1;
            }
        }
    }
    let list: Vec<Value> = teams
        .iter()
        .map(|t| {
            let id = st(t, "id");
            json!({ "id": id, "name": st(t, "name"), "slug": st(t, "slug"), "member_count": counts.get(&id).copied().unwrap_or(0) })
        })
        .collect();
    crate::ok(json!({ "teams": list })).into_response()
}

async fn teams_create(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let Some(name) = tc::clean_team_name(&st(input, "name")) else {
        return fail(
            StatusCode::BAD_REQUEST,
            "name_required",
            "Give the team a name.",
        );
    };
    let existing = match team_ids_of(c).await {
        Ok(t) => t,
        Err(r) => return r,
    };
    if existing.len() >= tc::MAX_TEAMS_PER_ORG {
        return fail(
            StatusCode::CONFLICT,
            "too_many_teams",
            "This organisation has reached its limit of teams.",
        );
    }
    if existing
        .iter()
        .any(|t| st(t, "name").to_lowercase() == name.to_lowercase())
    {
        return fail(
            StatusCode::CONFLICT,
            "team_exists",
            "A team with that name already exists.",
        );
    }
    let taken: HashSet<String> = existing.iter().map(|t| st(t, "slug")).collect();
    let slug = tc::unique_slug(&tc::slugify(&name), &taken);
    let made = rest(
        "POST",
        "org_teams?select=id,name,slug",
        Some(json!({ "org_id": c.org_id, "name": name, "slug": slug, "created_by": c.id })),
        "return=representation",
    )
    .await;
    match made {
        Ok(v) => {
            let team = rows(&v).into_iter().next().unwrap_or(Value::Null);
            log(c, "team.created", &name, json!({})).await;
            crate::ok(json!({ "ok": true, "team": team })).into_response()
        }
        Err(_) => fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "team_not_created",
            "The team was not created.",
        ),
    }
}

async fn team_of(c: &Ctx, input: &Value) -> Result<String, Resp> {
    let id = st(input, "id").trim().to_lowercase();
    if !tc::is_uuid(&id) {
        return Err(fail(StatusCode::BAD_REQUEST, "bad_team", "Say which team."));
    }
    let found = rest(
        "GET",
        &format!(
            "org_teams?select=id&id=eq.{}&org_id=eq.{}",
            tc::pct(&id),
            tc::pct(&c.org_id)
        ),
        None,
        "",
    )
    .await
    .map_err(|_| {
        fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "server_error",
            "Could not read the team",
        )
    })?;
    if rows(&found).is_empty() {
        return Err(fail(
            StatusCode::NOT_FOUND,
            "team_not_found",
            "That team does not exist.",
        ));
    }
    Ok(id)
}

async fn teams_delete(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let id = match team_of(c, input).await {
        Ok(i) => i,
        Err(r) => return r,
    };
    let q = format!(
        "org_teams?id=eq.{}&org_id=eq.{}",
        tc::pct(&id),
        tc::pct(&c.org_id)
    );
    if rest("DELETE", &q, None, "return=minimal").await.is_err() {
        return fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "team_not_deleted",
            "The team was not deleted.",
        );
    }
    log(c, "team.deleted", &id, json!({})).await;
    crate::ok(json!({ "ok": true })).into_response()
}

async fn teams_members(c: &Ctx, input: &Value) -> Resp {
    let id = match team_of(c, input).await {
        Ok(i) => i,
        Err(r) => return r,
    };
    match rest(
        "GET",
        &format!(
            "org_team_members?select=user_id&team_id=eq.{}&limit=1000",
            tc::pct(&id)
        ),
        None,
        "",
    )
    .await
    {
        Ok(v) => {
            let ids: Vec<String> = rows(&v).iter().map(|r| st(r, "user_id")).collect();
            crate::ok(json!({ "team_id": id, "user_ids": ids })).into_response()
        }
        Err(_) => fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "server_error",
            "Could not read the team's people",
        ),
    }
}

/// Replaces the team's people with exactly the given user ids — only people who really are in this organisation.
async fn teams_set_members(c: &Ctx, input: &Value) -> Resp {
    if let Some(r) = need_manage(c) {
        return r;
    }
    let id = match team_of(c, input).await {
        Ok(i) => i,
        Err(r) => return r,
    };
    let asked: Vec<String> = input
        .get("user_ids")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|x| x.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();
    let (wanted, over) = tc::clean_uuid_list(&asked, tc::MAX_TEAM_MEMBERS);

    // only active members of THIS organisation can be in its teams
    let org_people: HashSet<String> = match rest(
        "GET",
        &format!(
            "org_members?select=user_id,status&org_id=eq.{}&limit=5000",
            tc::pct(&c.org_id)
        ),
        None,
        "",
    )
    .await
    {
        Ok(v) => rows(&v)
            .iter()
            .filter(|m| st(m, "status") != "revoked")
            .map(|m| st(m, "user_id").to_lowercase())
            .collect(),
        Err(_) => {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "server_error",
                "Could not read members",
            )
        }
    };
    let keep: Vec<String> = wanted
        .iter()
        .filter(|u| org_people.contains(*u))
        .cloned()
        .collect();
    let ignored = wanted.len() - keep.len();

    let current: HashSet<String> = match rest(
        "GET",
        &format!(
            "org_team_members?select=user_id&team_id=eq.{}&limit=5000",
            tc::pct(&id)
        ),
        None,
        "",
    )
    .await
    {
        Ok(v) => rows(&v)
            .iter()
            .map(|r| st(r, "user_id").to_lowercase())
            .collect(),
        Err(_) => {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "server_error",
                "Could not read the team's people",
            )
        }
    };
    let want: HashSet<String> = keep.iter().cloned().collect();
    let to_add: Vec<String> = keep
        .iter()
        .filter(|u| !current.contains(*u))
        .cloned()
        .collect();
    let to_remove: Vec<String> = current
        .iter()
        .filter(|u| !want.contains(*u))
        .cloned()
        .collect();

    if !to_remove.is_empty()
        && rest(
            "DELETE",
            &format!(
                "org_team_members?team_id=eq.{}&{}",
                tc::pct(&id),
                tc::in_filter("user_id", &to_remove)
            ),
            None,
            "return=minimal",
        )
        .await
        .is_err()
    {
        return fail(
            StatusCode::INTERNAL_SERVER_ERROR,
            "team_not_saved",
            "The team was not saved.",
        );
    }
    if !to_add.is_empty() {
        let body = Value::Array(
            to_add
                .iter()
                .map(|u| json!({ "team_id": id, "user_id": u, "added_by": c.id }))
                .collect(),
        );
        if rest(
            "POST",
            "org_team_members?on_conflict=team_id,user_id",
            Some(body),
            "resolution=ignore-duplicates,return=minimal",
        )
        .await
        .is_err()
        {
            return fail(
                StatusCode::INTERNAL_SERVER_ERROR,
                "team_not_saved",
                "The team was not saved.",
            );
        }
    }
    if !to_add.is_empty() || !to_remove.is_empty() {
        log(
            c,
            "team.members",
            &id,
            json!({ "added": to_add.len(), "removed": to_remove.len() }),
        )
        .await;
    }
    crate::ok(json!({
        "ok": true, "added": to_add.len(), "removed": to_remove.len(),
        "ignored": ignored, "over_cap": over, "count": keep.len(),
    }))
    .into_response()
}
