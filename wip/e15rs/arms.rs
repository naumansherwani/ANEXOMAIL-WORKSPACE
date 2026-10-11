        // E15 — company domains + addresses (owner/admin hi badal sakta hai)
        "mail.domains.list" => mail_domains_list(&me.org_id).await,
        "mail.domains.add" => {
            if !mail_can_manage(&me.org_id, &me.id).await {
                return forbidden();
            }
            match sb_rpc(
                "org_domain_add",
                json!({ "_org": me.org_id, "_domain": s(input, "domain") }),
            )
            .await
            {
                Ok(mut r) => {
                    if r.get("ok").and_then(|v| v.as_bool()) == Some(true) {
                        let rec = r.get("domain").map(dns_records).unwrap_or(Value::Null);
                        r["domain"]["records"] = rec;
                    }
                    Ok(r)
                }
                Err(e) => Err(e),
            }
        }
        "mail.domains.verify" => {
            if !mail_can_manage(&me.org_id, &me.id).await {
                return forbidden();
            }
            mail_domain_verify(&me.org_id, &s(input, "domain_id")).await
        }
        "mail.domains.remove" => {
            if !mail_can_manage(&me.org_id, &me.id).await {
                return forbidden();
            }
            sb_rpc(
                "org_domain_remove",
                json!({ "_org": me.org_id, "_id": s(input, "domain_id") }),
            )
            .await
        }
        "mail.addresses.list" => mail_addresses_list(&me.org_id, &me.email).await,
        "mail.addresses.create" => {
            if !mail_can_manage(&me.org_id, &me.id).await {
                return forbidden();
            }
            let kind = if s(input, "kind").is_empty() {
                "mailbox".to_string()
            } else {
                s(input, "kind")
            };
            let mut body = json!({
                "_org": me.org_id,
                "_domain_id": s(input, "domain_id"),
                "_local": s(input, "local_part"),
                "_kind": kind,
            });
            if !s(input, "owner_user_id").is_empty() {
                body["_owner"] = json!(s(input, "owner_user_id"));
            }
            if !s(input, "alias_target").is_empty() {
                body["_alias_target"] = json!(s(input, "alias_target"));
            }
            sb_rpc("org_address_create", body).await
        }
        "mail.addresses.remove" => {
            if !mail_can_manage(&me.org_id, &me.id).await {
                return forbidden();
            }
            sb_rpc(
                "org_address_remove",
                json!({ "_org": me.org_id, "_id": s(input, "address_id") }),
            )
            .await
        }
