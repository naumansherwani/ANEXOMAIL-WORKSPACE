
-- E176 - FIX of fmail_dkim_health175 (Q1d-1a, found live 16 Nov 03:50): "text[] || 'literal'" is read by PostgreSQL as an ARRAY literal, so the health read raised
-- "malformed array literal" for a mailbox with no key (the Systems panel said "signing status unavailable"). The two literals are now cast ::text. The E175 selftest never read
-- the health of a mailbox WITHOUT a key; the selftest below does, and rolls itself back. Needs E175. Re-run safe (create or replace).

create or replace function public.fmail_dkim_health175(p_mailbox uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  pol public.fmail_dkim_policy%rowtype; v_keys jsonb; v_rot jsonb; v_block text[] := '{}'; v_warn text[] := '{}'; r record; v_ed int := 0; v_rsa int := 0; v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_over24 int; v_n24 int; v_proof text;
begin
  pol := public.fmail_dkim_pol175(p_mailbox);
  v_rot := public.fmail_dkim_rotation175(p_mailbox);
  select coalesce(jsonb_agg(jsonb_build_object(
      'key_id', k.id, 'selector', k.selector, 'alg', k.alg, 'status', k.status,
      'dns', (select jsonb_build_object('result', d.result, 'dnssec', d.dnssec, 'age_s', ((v_ms - d.observed_ms) / 1000)) from public.fmail_dkim_dns_obs d where d.key_id = k.id order by d.seq desc limit 1),
      'signed_24h', (select count(*) from public.fmail_dkim_sign_log s where s.key_id = k.id and s.ts_ms > v_ms - 86400000),
      'last_proof', (select p.verdict from public.fmail_dkim_proof p where p.key_id = k.id order by p.seq desc limit 1)) order by k.created_at), '[]'::jsonb)
    into v_keys from public.fmail_dkim_keys k where k.mailbox_id = p_mailbox and k.status = 'active';
  for r in select k.id, k.selector, k.alg, (select d.result from public.fmail_dkim_dns_obs d where d.key_id = k.id order by d.seq desc limit 1) as dns,
                  (select d.dnssec from public.fmail_dkim_dns_obs d where d.key_id = k.id order by d.seq desc limit 1) as dnssec,
                  (select p.verdict from public.fmail_dkim_proof p where p.key_id = k.id order by p.seq desc limit 1) as proof
             from public.fmail_dkim_keys k where k.mailbox_id = p_mailbox and k.status = 'active' loop
    if r.alg = 'ed25519-sha256' then v_ed := v_ed + 1; else v_rsa := v_rsa + 1; end if;
    if r.dns is distinct from 'match' then
      if pol.require_dns_match then v_block := v_block || ('the DNS record for ' || r.selector || ' is not confirmed'); else v_warn := v_warn || ('the DNS record for ' || r.selector || ' is not confirmed yet'); end if;
    end if;
    if r.dnssec = 'bogus' then v_block := v_block || ('the DNSSEC answer for ' || r.selector || ' is bogus'); end if;
    if r.proof is distinct from 'pass' then v_warn := v_warn || ('no outside receiver has passed ' || r.selector || ' yet'); end if;
  end loop;
  if v_ed + v_rsa = 0 then v_block := v_block || 'there is no active DKIM key'::text; end if;
  if pol.require_dual and (v_ed = 0 or v_rsa = 0) then v_block := v_block || 'policy needs both an Ed25519 and an RSA key'::text; end if;
  for r in select e ->> 'selector' as sel, e ->> 'state' as st from jsonb_array_elements(v_rot) e where e ->> 'status' = 'active' and e ->> 'state' in ('due', 'overdue') loop
    v_warn := v_warn || ('key ' || r.sel || ' should rotate (' || r.st || ')');
  end loop;
  select count(*) filter (where oversigned), count(*) into v_over24, v_n24 from public.fmail_dkim_sign_log where mailbox_id = p_mailbox and ts_ms > v_ms - 86400000;
  if v_n24 > 0 and v_over24 < v_n24 and not pol.require_oversign then v_warn := v_warn || ((v_n24 - v_over24)::text || ' signature(s) in 24 h were not over-signed'); end if;
  return jsonb_build_object('policy', to_jsonb(pol) - 'mailbox_id', 'keys', v_keys, 'rotation', v_rot, 'blockers', to_jsonb(v_block), 'warnings', to_jsonb(v_warn),
                            'send_ready', cardinality(v_block) = 0, 'signed_24h', v_n24, 'oversigned_24h', v_over24);
end $$;

create or replace function public.fmail_dkim_selftest176() returns text language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_uid uuid; v_box uuid; v_h jsonb; v_pass int := 0; v_fail int := 0; v_res jsonb := '[]'::jsonb; ev jsonb; v_pub bytea := decode(repeat('06', 32), 'hex'); v_sel text;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E176 selftest: no founder account to test with'; end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest176@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    v_h := public.fmail_dkim_health175(v_box);
    v_res := v_res || jsonb_build_object('name', 'health of a mailbox with NO key answers (was: malformed array literal)', 'ok', jsonb_typeof(v_h) = 'object');
    v_res := v_res || jsonb_build_object('name', 'no key = blocker "there is no active DKIM key" and send_ready false', 'ok', (v_h -> 'blockers') ? 'there is no active DKIM key' and (v_h ->> 'send_ready') = 'false');
    v_res := v_res || jsonb_build_object('name', 'the send gate is closed for it, with the reason', 'ok', (public.fmail_dkim_send_gate175(v_box) ->> 'ok') = 'false' and jsonb_array_length(public.fmail_dkim_send_gate175(v_box) -> 'reasons') >= 1);
    perform public.fmail_dkim_policy_set175(v_uid, v_box, null, null, null, null, true, null, repeat('a', 64));
    v_h := public.fmail_dkim_health175(v_box);
    v_res := v_res || jsonb_build_object('name', 'dual policy on, no key: both blockers listed, no error', 'ok', jsonb_array_length(v_h -> 'blockers') = 2 and (v_h -> 'blockers') ? 'policy needs both an Ed25519 and an RSA key');
    raise exception 'E176_SELFTEST_ROLLBACK %', v_res::text;
  exception when others then
    if sqlerrm like 'E176_SELFTEST_ROLLBACK %' then v_res := substr(sqlerrm, length('E176_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return 'E176 selftest: ERROR ' || sqlerrm || ' (' || sqlstate || ')'; end if;
  end;
  for ev in select * from jsonb_array_elements(v_res) loop if (ev ->> 'ok')::boolean then v_pass := v_pass + 1; else v_fail := v_fail + 1; end if; end loop;
  if v_fail > 0 then return 'E176 selftest: ' || v_pass || ' ok, ' || v_fail || ' failed: ' || (select string_agg(x ->> 'name', ' | ') from jsonb_array_elements(v_res) x where not (x ->> 'ok')::boolean); end if;
  return 'E176 selftest: ' || v_pass || ' ok, 0 failed';
end $$;
revoke all on function public.fmail_dkim_selftest176() from public, anon, authenticated;
grant execute on function public.fmail_dkim_selftest176() to service_role;

select public.fmail_dkim_selftest176() as e176_selftest;
