-- E146 — Banned countries for the founder alert number (Phone alerts, E118 mobile flare). Layer: SQL (decision). Founder order 7 Nov 2026 16:22 / 16:30.
-- ANEXOMAIL is not available in Afghanistan (+93), Israel (+972), North Korea (+850) and Syria (+963); every other country is allowed. The list is banned-countries/banned.json
-- (the tests read it and fail on drift against Rust, awam, founder UI, Caddy and this file).
--   1) founder_banned_countries: the decision table. Append-only for ever (a trigger refuses UPDATE / DELETE / TRUNCATE); closed to anon and authenticated; read by service_role.
--   2) founder_e164_banned(e164): true when the number starts with a banned calling code (codes are prefix-free, so a prefix test is exact). Palestine +970 is NOT touched.
--   3) founder_mobile_flare_set (E118) is replaced: same signature, same grant check, plus the banned test BEFORE the step-up grant is spent (a refused number never burns the key touch).
--   4) selftest (rolls back) + CHECK_E146.sql.
-- Needs E118. Safe to run again.

do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_banned:ddl', 0));
  create table if not exists public.founder_banned_countries (
    iso2   text primary key check (iso2 ~ '^[A-Z]{2}$'),
    name   text not null check (length(btrim(name)) between 2 and 60),
    dial   text not null unique check (dial ~ '^[1-9][0-9]{0,3}$'),
    since  timestamptz not null default now()
  );
  alter table public.founder_banned_countries enable row level security;
  alter table public.founder_banned_countries force row level security;
  revoke all on public.founder_banned_countries from public, anon, authenticated, service_role;
  grant select on public.founder_banned_countries to service_role;
end $$;

create or replace function public._fb_append_only() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin raise exception 'the banned-country list is append-only: add a row through a new E-file, never edit or delete' using errcode = '42501'; end $$;
drop trigger if exists founder_banned_no_change on public.founder_banned_countries;
create trigger founder_banned_no_change before update or delete on public.founder_banned_countries for each row execute function public._fb_append_only();
drop trigger if exists founder_banned_no_truncate on public.founder_banned_countries;
create trigger founder_banned_no_truncate before truncate on public.founder_banned_countries for each statement execute function public._fb_append_only();
revoke all on function public._fb_append_only() from public, anon, authenticated;

insert into public.founder_banned_countries (iso2, name, dial) values
  ('AF', 'Afghanistan', '93'), ('IL', 'Israel', '972'), ('KP', 'North Korea', '850'), ('SY', 'Syria', '963')
on conflict (iso2) do nothing;

create or replace function public.founder_e164_banned(p_e164 text) returns boolean
language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (select 1 from public.founder_banned_countries b where p_e164 ~ '^\+[1-9][0-9]{7,14}$' and substr(p_e164, 2) like b.dial || '%');
$$;
revoke all on function public.founder_e164_banned(text) from public, anon, authenticated;
grant execute on function public.founder_e164_banned(text) to service_role;

-- E118 door, same signature and behaviour, plus the banned-country wall (before the grant is consumed)
create or replace function public.founder_mobile_flare_set(p_uid uuid, p_device uuid, p_e164 text, p_grant uuid, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  perform public._fp_assert_device(p_uid, p_device);
  if p_e164 is null or p_e164 !~ '^\+[1-9][0-9]{7,14}$' then raise exception 'number must be in international format, e.g. +923001234567' using errcode = '22023'; end if;
  if public.founder_e164_banned(p_e164) then raise exception 'Anexomail is not available for numbers of this country' using errcode = '42501'; end if;
  perform public._fp_consume_action(p_uid, p_device, p_grant, 'mobile.flare', 'alert number', jsonb_build_object('last4', right(p_e164, 4)), p_nonce);
  insert into public.founder_mobile_flare (user_id, e164) values (p_uid, p_e164)
    on conflict (user_id) do update set e164 = excluded.e164, added_at = now(), confirmed_at = null, removed_at = null;
  perform public.founder_audit_append(p_uid, 'mobile.flare', 'set', 'alert number registered; not confirmed until the owner replies from it', jsonb_build_object('device', p_device, 'last4', right(p_e164, 4)));
  return jsonb_build_object('registered', true, 'confirmed', false, 'last4', right(p_e164, 4));
end $$;
revoke all on function public.founder_mobile_flare_set(uuid,uuid,text,uuid,text) from public, anon, authenticated;
grant execute on function public.founder_mobile_flare_set(uuid,uuid,text,uuid,text) to service_role;

create or replace function public.founder_banned_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r text := ''; u uuid; d uuid; v_msg text; n text;
begin
  if (select count(*) from public.founder_banned_countries where (iso2, dial) in (('AF','93'),('IL','972'),('KP','850'),('SY','963'))) <> 4 then return 'E146 selftest FAIL: the four banned rows are not all there'; end if;
  if (select count(*) from public.founder_banned_countries) <> 4 then return 'E146 selftest FAIL: unexpected extra banned rows'; end if;
  begin
    if not (public.founder_e164_banned('+93701234567') and public.founder_e164_banned('+972501234567') and public.founder_e164_banned('+850191234567') and public.founder_e164_banned('+963944123456')) then raise exception 'a banned prefix passed'; end if;
    if public.founder_e164_banned('+923001234567') or public.founder_e164_banned('+970599123456') or public.founder_e164_banned('+96171123456') or public.founder_e164_banned('+447700900123') or public.founder_e164_banned('+12025550100') or public.founder_e164_banned('03001234567') then raise exception 'an allowed number was refused'; end if;
    r := r || 'prefix test exact (PK, PS, LB, GB, US pass); ';
    begin update public.founder_banned_countries set dial = '1' where iso2 = 'SY'; raise exception 'the list was edited'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_banned_countries where iso2 = 'KP'; raise exception 'a row was deleted'; exception when sqlstate '42501' then null; end;
    if (select count(*) from pg_trigger where tgrelid = 'public.founder_banned_countries'::regclass and not tgisinternal and tgname in ('founder_banned_no_change', 'founder_banned_no_truncate')) <> 2 then raise exception 'an append-only trigger is missing'; end if;
    r := r || 'append-only; ';
    select user_id into u from public.founder_accounts order by user_id limit 1;
    select id into d from public.founder_devices where user_id = u and approved_at is not null and revoked_at is null limit 1;
    if u is not null and d is not null then
      n := md5(random()::text);
      begin perform public.founder_mobile_flare_set(u, d, '+963944123456', gen_random_uuid(), n); raise exception 'a Syrian number was accepted';
      exception when others then get stacked diagnostics v_msg = message_text; if v_msg not like '%not available for numbers of this country%' then raise exception 'wrong refusal for a banned number: %', v_msg; end if; end;
      begin perform public.founder_mobile_flare_set(u, d, '+923001234567', gen_random_uuid(), n); raise exception 'an allowed number passed without a grant';
      exception when others then get stacked diagnostics v_msg = message_text; if v_msg like '%not available for numbers of this country%' or v_msg like 'an allowed number passed%' then raise exception 'allowed number hit the wall: %', v_msg; end if; end;
      r := r || 'door: banned refused before the grant, allowed number reaches the grant check; ';
    else r := r || 'door check SKIPPED (no approved device); ';
    end if;
    return 'E146 selftest PASS: ' || r;
  exception when others then return 'E146 selftest FAIL: ' || sqlerrm || ' (after: ' || r || ')';
  end;
end $$;
revoke all on function public.founder_banned_selftest() from public, anon, authenticated;
grant execute on function public.founder_banned_selftest() to service_role;
