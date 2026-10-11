// ── E15 business domains (company mail, Zoho-style) ─────────────────────────
const MAIL_HOST: &str = "mail.anexomail.com";

fn forbidden() -> axum::response::Response {
    err(StatusCode::FORBIDDEN, "forbidden", "owner_or_admin_only").into_response()
}

async fn mail_can_manage(org: &str, user: &str) -> bool {
    sb_select(&format!(
        "org_members?select=role&org_id=eq.{org}&user_id=eq.{user}"
    ))
    .await
    .ok()
    .and_then(|v| {
        let r = v.get(0)?.get("role")?.as_str()?.to_lowercase();
        Some(r == "owner" || r == "admin")
    })
    .unwrap_or(false)
}

fn dns_records(d: &Value) -> Value {
    let g = |k: &str| d.get(k).and_then(|v| v.as_str()).unwrap_or("").to_string();
    let b = |k: &str| d.get(k).and_then(|v| v.as_bool()).unwrap_or(false);
    let dom = g("domain");
    let sel = {
        let x = g("dkim_selector");
        if x.is_empty() { "anexo1".to_string() } else { x }
    };
    let dkim = g("dkim_public");
    let dkim_val = if dkim.is_empty() {
        Value::Null
    } else {
        json!(format!("v=DKIM1; k=rsa; p={dkim}"))
    };
    json!([
        { "key": "txt", "type": "TXT", "name": "_anexomail-verify", "host": format!("_anexomail-verify.{dom}"),
          "value": g("verify_token"), "ok": b("txt_ok") },
        { "key": "mx", "type": "MX", "name": "@", "host": dom, "value": MAIL_HOST, "priority": 10, "ok": b("mx_ok") },
        { "key": "spf", "type": "TXT", "name": "@", "host": dom,
          "value": format!("v=spf1 a:{MAIL_HOST} ~all"), "ok": b("spf_ok") },
        { "key": "dkim", "type": "TXT", "name": format!("{sel}._domainkey"), "host": format!("{sel}._domainkey.{dom}"),
          "value": dkim_val, "pending": dkim.is_empty(), "ok": b("dkim_ok") },
        { "key": "dmarc", "type": "TXT", "name": "_dmarc", "host": format!("_dmarc.{dom}"),
          "value": "v=DMARC1; p=none; rua=mailto:dmarc@anexomail.com", "ok": b("dmarc_ok") }
    ])
}

/// DNS-over-HTTPS (Cloudflare) — shell/dig ki zaroorat nahi, koi injection nahi.
async fn doh(name: &str, rtype: &str) -> Vec<String> {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(6))
        .build()
        .unwrap_or_default();
    let res = client
        .get("https://cloudflare-dns.com/dns-query")
        .query(&[("name", name), ("type", rtype)])
        .header("accept", "application/dns-json")
        .send()
        .await;
    let Ok(res) = res else { return vec![] };
    let Ok(v) = res.json::<Value>().await else { return vec![] };
    v.get("Answer")
        .and_then(|a| a.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|r| r.get("data").and_then(|d| d.as_str()))
                .map(|x| x.replace("\" \"", "").trim_matches('"').to_string())
                .collect()
        })
        .unwrap_or_default()
}

async fn mail_domains_list(org: &str) -> Result<Value, String> {
    let list = sb_rpc("org_domain_list", json!({ "_org": org })).await?;
    let plan = sb_rpc("org_plan_of", json!({ "_org": org }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|x| x.to_string()))
        .unwrap_or_else(|| "basic".to_string());
    let cap = sb_rpc("org_domain_cap", json!({ "_plan": plan }))
        .await
        .unwrap_or(Value::Null);
    let domains: Vec<Value> = list
        .as_array()
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .map(|mut d| {
            let rec = dns_records(&d);
            d["records"] = rec;
            d
        })
        .collect();
    Ok(json!({ "domains": domains, "plan": plan, "domain_cap": cap, "mail_host": MAIL_HOST }))
}

async fn mail_domain_verify(org: &str, id: &str) -> Result<Value, String> {
    let list = sb_rpc("org_domain_list", json!({ "_org": org })).await?;
    let d = match list
        .as_array()
        .and_then(|a| a.iter().find(|x| x.get("id").and_then(|v| v.as_str()) == Some(id)))
        .cloned()
    {
        Some(d) => d,
        None => return Ok(json!({ "ok": false, "error": "domain_not_found" })),
    };
    let g = |k: &str| d.get(k).and_then(|v| v.as_str()).unwrap_or("").to_string();
    let dom = g("domain");
    let token = g("verify_token");
    let sel = {
        let x = g("dkim_selector");
        if x.is_empty() { "anexo1".to_string() } else { x }
    };
    let dkim_pub: String = g("dkim_public").split_whitespace().collect();

    let txt = doh(&format!("_anexomail-verify.{dom}"), "TXT").await;
    let mx = doh(&dom, "MX").await;
    let spf = doh(&dom, "TXT").await;
    let dkim = doh(&format!("{sel}._domainkey.{dom}"), "TXT").await;
    let dmarc = doh(&format!("_dmarc.{dom}"), "TXT").await;

    let txt_ok = !token.is_empty() && txt.iter().any(|t| t.trim() == token);
    let mx_ok = mx
        .iter()
        .any(|m| m.trim().trim_end_matches('.').to_lowercase().ends_with(MAIL_HOST));
    let spf_ok = spf
        .iter()
        .any(|t| t.to_lowercase().starts_with("v=spf1") && t.to_lowercase().contains(MAIL_HOST));
    let dkim_ok = dkim_pub.len() >= 40 && dkim_pub.is_ascii()
        && dkim.iter().any(|t| {
            let c: String = t.split_whitespace().collect();
            c.contains("p=") && c.contains(&dkim_pub[..40])
        });
    let dmarc_ok = dmarc.iter().any(|t| t.to_uppercase().starts_with("V=DMARC1"));

    let saved = sb_rpc(
        "org_domain_set_checks",
        json!({ "_id": id, "_txt": txt_ok, "_mx": mx_ok, "_spf": spf_ok, "_dkim": dkim_ok, "_dmarc": dmarc_ok }),
    )
    .await?;
    let mut domain = saved.get("domain").cloned().unwrap_or(Value::Null);
    if domain.is_object() {
        let rec = dns_records(&domain);
        domain["records"] = rec;
    }
    Ok(json!({
        "ok": saved.get("ok").and_then(|v| v.as_bool()).unwrap_or(false),
        "ready": domain.get("status").and_then(|v| v.as_str()) == Some("verified"),
        "checks": { "txt": txt_ok, "mx": mx_ok, "spf": spf_ok, "dkim": dkim_ok, "dmarc": dmarc_ok },
        "domain": domain
    }))
}

async fn mail_addresses_list(org: &str, login: &str) -> Result<Value, String> {
    let list = sb_rpc("org_address_list", json!({ "_org": org })).await?;
    let plan = sb_rpc("org_plan_of", json!({ "_org": org }))
        .await
        .ok()
        .and_then(|v| v.as_str().map(|x| x.to_string()))
        .unwrap_or_else(|| "basic".to_string());
    let cap = sb_rpc("org_mailbox_cap", json!({ "_plan": plan }))
        .await
        .unwrap_or(Value::Null);
    let used = list
        .as_array()
        .map(|a| {
            a.iter()
                .filter(|x| {
                    matches!(x.get("kind").and_then(|v| v.as_str()), Some("mailbox") | Some("shared"))
                })
                .count()
        })
        .unwrap_or(0);
    Ok(json!({
        "addresses": list, "plan": plan, "mailbox_cap": cap, "mailbox_used": used,
        "login_address": login
    }))
}

