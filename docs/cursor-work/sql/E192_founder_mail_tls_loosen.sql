
-- E192 (QC1cF8-5, 19 Nov 2026 PKT, his order 12:34 + 12:38 "Gmail ka baap, jo duniya mein kisi ke paas nahi"): ONE NAMED PARTNER DOMAIN, TIMED, SIGNED BY A PASSKEY, SELF-HEALING.
-- Every other mail system loosens TLS with a PERMANENT admin rule for a whole tenant or a domain list. Here the rule "send only if TLS" (E191, strict by default) can be relaxed only:
--   for ONE named domain (the partner whose server has no STARTTLS), never for the whole mailbox;  for 1-24 hours, a written reason of 8-200 characters, at most 3 per 24 hours per mailbox;
--   by a passkey touch that SIGNS the exact change (mailbox, domain, hours, reason, nonce; E118 T2 grant, consumed once);  and it RETIRES ITSELF the first time that domain delivers over TLS ("healed"), or at the end of the time.
-- MTA-STS enforce and DANE stay TLS-only whatever this table says (Rust hop_requires_tls, E191 rule).
-- Doors: digest (dry run + the hash the key signs), apply (consume grant + write, one transaction), tighten (no touch needed, safe), heal (Rust, tightening only), loose (Rust asks per domain; any doubt = strict), state (screen).
-- The domain name is stored in plain text ON PURPOSE in this one small table: the founder typed it and signed it himself, and it is shown back to him; the traffic counters of E191 stay sealed.
-- Ledger: every change is a hash-chained E191 line (fmail_tlsx_log191, closed words only, no names). Run through sql-run.sh after E191. Safe to run again. Awam is not touched.

do $$
begin
  if to_regprocedure('public.fmail_tlsx_note191(uuid,text,date,bytea,text)') is null or to_regprocedure('public.fmail_tlsx_verify191(uuid)') is null then raise exception 'E192 needs E191 first'; end if;
  if to_regprocedure('public._fp_consume_action(uuid,uuid,uuid,text,text,jsonb,text)') is null or to_regclass('public.founder_action_tiers') is null then raise exception 'E192 needs E118 first'; end if;
end $$;

insert into public.founder_action_tiers (action, tier, label, built) values ('mail.tls.loosen', 2, 'Allow plain mail delivery to one domain for a short time', true)
on conflict (action) do update set tier = excluded.tier, label = excluded.label, built = excluded.built;

create table if not exists public.fmail_tls_dom192 (
  id             uuid primary key default gen_random_uuid(),
  mailbox_id     uuid not null references public.fmail_mailboxes (id) on delete cascade,
  domain         text not null check (length(domain) between 3 and 253 and domain = lower(domain) and domain ~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$'),
  loosened_until timestamptz not null,
  reason         text not null check (length(reason) between 8 and 200 and reason !~ '[[:cntrl:]<>]'),
  grant_id       uuid not null unique,
  created_at     timestamptz not null default now(),
  retired_at     timestamptz,
  retired_why    text check (retired_why in ('expired', 'manual', 'healed')),
  constraint fmail_tls_dom192_pair check ((retired_at is null) = (retired_why is null))
);
create unique index if not exists fmail_tls_dom192_active_ix on public.fmail_tls_dom192 (mailbox_id, domain) where retired_at is null;
alter table public.fmail_tls_dom192 enable row level security;
alter table public.fmail_tls_dom192 force row level security;
revoke all on public.fmail_tls_dom192 from public, anon, authenticated, service_role;
grant select on public.fmail_tls_dom192 to service_role;

create or replace function public._tls_loosen_params192(p_mailbox uuid, p_domain text, p_hours integer, p_reason text) returns jsonb
language sql immutable set search_path = pg_catalog, public as $$
  select jsonb_build_object('mailbox', p_mailbox::text, 'domain', lower(btrim(p_domain)), 'hours', p_hours::text, 'reason', btrim(p_reason))
$$;

-- the rules, said BEFORE any touch (a refusal costs no touch and burns no grant)
create or replace function public._tls_loosen_dry192(p_uid uuid, p_mailbox uuid, p_domain text, p_hours integer, p_reason text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_n integer; v_d text := lower(btrim(coalesce(p_domain, '')));
begin
  if p_mailbox is null or not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_uid) then return jsonb_build_object('ok', false, 'error', 'no_mailbox'); end if;
  if length(v_d) not between 3 and 253 or v_d !~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' then return jsonb_build_object('ok', false, 'error', 'domain'); end if;
  if p_hours is null or p_hours < 1 or p_hours > 24 then return jsonb_build_object('ok', false, 'error', 'hours'); end if;
  if p_reason is null or length(btrim(p_reason)) not between 8 and 200 or p_reason ~ '[[:cntrl:]<>]' then return jsonb_build_object('ok', false, 'error', 'reason'); end if;
  if exists (select 1 from public.fmail_tls_dom192 where mailbox_id = p_mailbox and domain = v_d and retired_at is null and loosened_until > now()) then return jsonb_build_object('ok', false, 'error', 'already'); end if;
  select count(*) into v_n from public.fmail_tlsx_log191 where mailbox_id = p_mailbox and event = 'policy_loosen' and at > now() - interval '24 hours';
  if v_n >= 3 then return jsonb_build_object('ok', false, 'error', 'limit'); end if;
  return jsonb_build_object('ok', true, 'left_today', 3 - v_n);
end $$;

create or replace function public.fmail_tls_loosen_digest192(p_uid uuid, p_mailbox uuid, p_domain text, p_hours integer, p_reason text, p_nonce text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare v_dry jsonb; v_params jsonb;
begin
  v_dry := public._tls_loosen_dry192(p_uid, p_mailbox, p_domain, p_hours, p_reason);
  if (v_dry ->> 'ok') <> 'true' then return v_dry; end if;
  v_params := public._tls_loosen_params192(p_mailbox, p_domain, p_hours, p_reason);
  return jsonb_build_object('ok', true, 'params', v_params, 'hash', public.founder_action_hash('mail.tls.loosen', p_mailbox::text, v_params, p_nonce), 'left_today', v_dry -> 'left_today');
end $$;

create or replace function public.fmail_tls_loosen_apply192(p_uid uuid, p_device uuid, p_mailbox uuid, p_domain text, p_hours integer, p_reason text, p_grant uuid, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_dry jsonb; v_until timestamptz; v_d text := lower(btrim(p_domain));
begin
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text, 191));
  v_dry := public._tls_loosen_dry192(p_uid, p_mailbox, p_domain, p_hours, p_reason);
  if (v_dry ->> 'ok') <> 'true' then raise exception 'loosen refused: %', v_dry ->> 'error' using errcode = '22023'; end if;     -- nothing consumed
  perform public._fp_consume_action(p_uid, p_device, p_grant, 'mail.tls.loosen', p_mailbox::text, public._tls_loosen_params192(p_mailbox, v_d, p_hours, p_reason), p_nonce);
  v_until := now() + make_interval(hours => p_hours);
  insert into public.fmail_tls_dom192 (mailbox_id, domain, loosened_until, reason, grant_id) values (p_mailbox, v_d, v_until, btrim(p_reason), p_grant);   -- unique grant_id: one touch, one loosening
  perform public.fmail_tlsx_note191(p_mailbox, 'policy_loosen', null, null, p_hours || ' h one domain');
  return jsonb_build_object('ok', true, 'domain', v_d, 'loosened_until', v_until);
end $$;

-- tightening is safe and needs no touch. Hands back what it retired.
create or replace function public.fmail_tls_dom_tighten192(p_uid uuid, p_mailbox uuid, p_domain text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_n integer; v_d text := lower(btrim(coalesce(p_domain, '')));
begin
  if p_mailbox is null or not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_uid) then return jsonb_build_object('ok', false, 'error', 'no_mailbox'); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text, 191));
  update public.fmail_tls_dom192 set retired_at = now(), retired_why = case when loosened_until <= now() then 'expired' else 'manual' end where mailbox_id = p_mailbox and domain = v_d and retired_at is null;
  get diagnostics v_n = row_count;
  if v_n > 0 then perform public.fmail_tlsx_note191(p_mailbox, 'policy_tighten', null, null, 'one domain'); end if;
  return jsonb_build_object('ok', true, 'changed', v_n > 0);
end $$;

-- Rust: "may this one domain be sent to without TLS right now?" Anything but a clear yes is a no.
create or replace function public.fmail_tls_dom_loose192(p_mailbox uuid, p_domain text) returns boolean
language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (select 1 from public.fmail_tls_dom192 where mailbox_id = p_mailbox and domain = lower(btrim(coalesce(p_domain, ''))) and retired_at is null and loosened_until > now())
$$;

-- Rust, after a delivery to that domain WENT OVER TLS: the exception is no longer needed, retire it. Tightening only, so it takes no touch.
create or replace function public.fmail_tls_dom_heal192(p_mailbox uuid, p_domain text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_n integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text, 191));
  update public.fmail_tls_dom192 set retired_at = now(), retired_why = 'healed' where mailbox_id = p_mailbox and domain = lower(btrim(coalesce(p_domain, ''))) and retired_at is null;
  get diagnostics v_n = row_count;
  if v_n > 0 then perform public.fmail_tlsx_note191(p_mailbox, 'policy_tighten', null, null, 'healed'); end if;
  return jsonb_build_object('ok', true, 'healed', v_n > 0);
end $$;

create or replace function public.fmail_tls_state192(p_uid uuid, p_mailbox uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_n integer; v_act jsonb; v_hist jsonb; v_chain jsonb;
begin
  if p_mailbox is null or not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_uid) then return jsonb_build_object('ok', false, 'error', 'no_mailbox'); end if;
  select count(*) into v_n from public.fmail_tlsx_log191 where mailbox_id = p_mailbox and event = 'policy_loosen' and at > now() - interval '24 hours';
  select coalesce(jsonb_agg(jsonb_build_object('domain', domain, 'loosened_until', loosened_until, 'reason', reason) order by loosened_until), '[]'::jsonb) into v_act
    from public.fmail_tls_dom192 where mailbox_id = p_mailbox and retired_at is null and loosened_until > now();
  select coalesce(jsonb_agg(jsonb_build_object('at', at, 'event', event, 'note', note) order by seq desc), '[]'::jsonb) into v_hist
    from (select at, event, note, seq from public.fmail_tlsx_log191 where mailbox_id = p_mailbox and event in ('policy_loosen', 'policy_tighten', 'policy_expired') order by seq desc limit 8) h;
  v_chain := public.fmail_tlsx_verify191(p_mailbox);
  return jsonb_build_object('ok', true, 'strict', jsonb_array_length(v_act) = 0, 'active', v_act, 'left_today', greatest(0, 3 - v_n), 'history', v_hist,
                            'chain_ok', coalesce((v_chain ->> 'ok')::boolean, false), 'server_now', now());
end $$;

revoke all on function public._tls_loosen_params192(uuid, text, integer, text), public._tls_loosen_dry192(uuid, uuid, text, integer, text),
  public.fmail_tls_loosen_digest192(uuid, uuid, text, integer, text, text), public.fmail_tls_loosen_apply192(uuid, uuid, uuid, text, integer, text, uuid, text),
  public.fmail_tls_dom_tighten192(uuid, uuid, text), public.fmail_tls_dom_loose192(uuid, text), public.fmail_tls_dom_heal192(uuid, text), public.fmail_tls_state192(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.fmail_tls_loosen_digest192(uuid, uuid, text, integer, text, text), public.fmail_tls_loosen_apply192(uuid, uuid, uuid, text, integer, text, uuid, text),
  public.fmail_tls_dom_tighten192(uuid, uuid, text), public.fmail_tls_dom_loose192(uuid, text), public.fmail_tls_dom_heal192(uuid, text), public.fmail_tls_state192(uuid, uuid) to service_role;

create or replace function public.fmail_selftest192() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare res jsonb := '[]'::jsonb; v_uid uuid; v_dev uuid; v_box uuid; v_r jsonb; v_g uuid := gen_random_uuid(); v_g2 uuid := gen_random_uuid(); v_nonce text := 'selftest192nonce0001'; v_h text; v_err text; v_cred text;
        v_why text := 'partner server has no STARTTLS';
begin
  -- the founder whose device is approved and unrevoked (E117 _fp_assert_device); the first account in the table may be another one
  select d.user_id, d.id into v_uid, v_dev from public.founder_devices d join public.founder_accounts a on a.user_id = d.user_id where d.approved_at is not null and d.revoked_at is null order by d.approved_at desc limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'passed', 0, 'total', 1, 'checks', jsonb_build_array(jsonb_build_object('name', 'no founder account with an approved device to test with', 'ok', false))); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest192@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    res := res || jsonb_build_array(jsonb_build_object('name', 'tier row is T2 and built', 'ok', exists (select 1 from public.founder_action_tiers where action = 'mail.tls.loosen' and tier = 2 and built)));
    res := res || jsonb_build_array(jsonb_build_object('name', 'params ignore case and spaces', 'ok', public._tls_loosen_params192(v_box, ' Partner.COM ', 4, ' ' || v_why) = public._tls_loosen_params192(v_box, 'partner.com', 4, v_why)));
    v_r := public.fmail_tls_loosen_digest192(v_uid, v_box, 'partner.com', 4, v_why, v_nonce);
    res := res || jsonb_build_array(jsonb_build_object('name', 'digest answers a 64-hex hash and 3 left', 'ok', (v_r ->> 'ok') = 'true' and (v_r ->> 'hash') ~ '^[0-9a-f]{64}$' and (v_r ->> 'left_today')::int = 3));
    res := res || jsonb_build_array(jsonb_build_object('name', 'digest refuses bad hours, domain, reason and another owner',
      'ok', public.fmail_tls_loosen_digest192(v_uid, v_box, 'partner.com', 0, v_why, v_nonce) ->> 'error' = 'hours' and public.fmail_tls_loosen_digest192(v_uid, v_box, 'partner.com', 25, v_why, v_nonce) ->> 'error' = 'hours'
        and public.fmail_tls_loosen_digest192(v_uid, v_box, 'not a domain', 4, v_why, v_nonce) ->> 'error' = 'domain' and public.fmail_tls_loosen_digest192(v_uid, v_box, 'localhost', 4, v_why, v_nonce) ->> 'error' = 'domain'
        and public.fmail_tls_loosen_digest192(v_uid, v_box, 'partner.com', 4, 'short', v_nonce) ->> 'error' = 'reason' and public.fmail_tls_loosen_digest192(v_uid, v_box, 'partner.com', 4, 'has <b> tag in it', v_nonce) ->> 'error' = 'reason'
        and public.fmail_tls_loosen_digest192(gen_random_uuid(), v_box, 'partner.com', 4, v_why, v_nonce) ->> 'error' = 'no_mailbox'));
    begin
      perform public.fmail_tls_loosen_apply192(v_uid, gen_random_uuid(), v_box, 'partner.com', 4, v_why, gen_random_uuid(), v_nonce);
      res := res || jsonb_build_array(jsonb_build_object('name', 'apply refuses a made-up grant and device', 'ok', false));
    exception when others then
      res := res || jsonb_build_array(jsonb_build_object('name', 'apply refuses a made-up grant and device', 'ok', not public.fmail_tls_dom_loose192(v_box, 'partner.com')));
    end;
    begin
      select credential_id into v_cred from public.founder_passkeys where user_id = v_uid limit 1;
      v_h := public.founder_action_hash('mail.tls.loosen', v_box::text, public._tls_loosen_params192(v_box, 'partner.com', 4, v_why), v_nonce);
      insert into public.founder_stepups (id, user_id, device_id, credential_id, scope, action, action_hash, expires_at) values (v_g, v_uid, v_dev, coalesce(v_cred, 'SELFTEST192CRED00000001'), 'g3', 'mail.tls.loosen', v_h, now() + interval '5 minutes');
      insert into public.founder_stepups (id, user_id, device_id, credential_id, scope, action, action_hash, expires_at) values (v_g2, v_uid, v_dev, coalesce(v_cred, 'SELFTEST192CRED00000001'), 'g3', 'mail.tls.loosen', v_h, now() + interval '5 minutes');
      begin
        perform public.fmail_tls_loosen_apply192(v_uid, v_dev, v_box, 'other.com', 4, v_why, v_g2, v_nonce);
        res := res || jsonb_build_array(jsonb_build_object('name', 'a grant signed for partner.com cannot loosen other.com', 'ok', false));
      exception when others then
        res := res || jsonb_build_array(jsonb_build_object('name', 'a grant signed for partner.com cannot loosen other.com', 'ok', (select used_at is null from public.founder_stepups where id = v_g2) and not public.fmail_tls_dom_loose192(v_box, 'other.com')));
      end;
      begin
        perform public.fmail_tls_loosen_apply192(v_uid, v_dev, v_box, 'partner.com', 12, v_why, v_g2, v_nonce);
        res := res || jsonb_build_array(jsonb_build_object('name', 'a grant signed for 4 hours cannot loosen for 12', 'ok', false));
      exception when others then
        res := res || jsonb_build_array(jsonb_build_object('name', 'a grant signed for 4 hours cannot loosen for 12', 'ok', (select used_at is null from public.founder_stepups where id = v_g2)));
      end;
      v_r := public.fmail_tls_loosen_apply192(v_uid, v_dev, v_box, 'Partner.com', 4, v_why, v_g, v_nonce);
      res := res || jsonb_build_array(jsonb_build_object('name', 'apply with the right grant loosens that one domain only',
        'ok', (v_r ->> 'ok') = 'true' and public.fmail_tls_dom_loose192(v_box, 'partner.com') and not public.fmail_tls_dom_loose192(v_box, 'other.com') and not public.fmail_tls_dom_loose192(v_box, 'sub.partner.com')));
      begin
        perform public.fmail_tls_loosen_apply192(v_uid, v_dev, v_box, 'partner.com', 4, v_why, v_g, v_nonce);
        res := res || jsonb_build_array(jsonb_build_object('name', 'the same grant cannot be used twice', 'ok', false));
      exception when others then
        res := res || jsonb_build_array(jsonb_build_object('name', 'the same grant cannot be used twice', 'ok', true));
      end;
      v_r := public.fmail_tls_state192(v_uid, v_box);
      res := res || jsonb_build_array(jsonb_build_object('name', 'state: one active domain, 2 left, history, good chain', 'ok', (v_r ->> 'ok') = 'true' and (v_r -> 'strict') = 'false'::jsonb and jsonb_array_length(v_r -> 'active') = 1 and (v_r ->> 'left_today')::int = 2 and jsonb_array_length(v_r -> 'history') >= 1 and (v_r ->> 'chain_ok')::boolean));
      v_r := public.fmail_tls_dom_heal192(v_box, 'partner.com');
      res := res || jsonb_build_array(jsonb_build_object('name', 'a TLS delivery heals it (retired, strict again)', 'ok', (v_r ->> 'healed') = 'true' and not public.fmail_tls_dom_loose192(v_box, 'partner.com') and (public.fmail_tls_state192(v_uid, v_box) -> 'strict') = 'true'::jsonb));
      v_r := public.fmail_tls_dom_heal192(v_box, 'partner.com');
      res := res || jsonb_build_array(jsonb_build_object('name', 'healing twice changes nothing', 'ok', (v_r ->> 'healed') = 'false'));
      res := res || jsonb_build_array(jsonb_build_object('name', 'a missing mailbox is refused by tighten', 'ok', public.fmail_tls_dom_tighten192(v_uid, gen_random_uuid(), 'partner.com') ->> 'error' = 'no_mailbox'));
      res := res || jsonb_build_array(jsonb_build_object('name', 'a retired domain in the table is never strict-breaking', 'ok', (select count(*) from public.fmail_tls_dom192 where mailbox_id = v_box and retired_why = 'healed') = 1));
    exception when others then
      get stacked diagnostics v_err = message_text;
      res := res || jsonb_build_array(jsonb_build_object('name', 'happy path stopped: ' || left(v_err, 120), 'ok', false));
    end;
    raise exception 'ROLLBACK_SELFTEST192';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST192' then res := res || jsonb_build_array(jsonb_build_object('name', 'selftest stopped: ' || left(sqlerrm, 120), 'ok', false)); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok') <> 'true'), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok') = 'true'), 'total', jsonb_array_length(res), 'checks', res);
end $$;
revoke all on function public.fmail_selftest192() from public, anon, authenticated, service_role;
grant execute on function public.fmail_selftest192() to service_role;
