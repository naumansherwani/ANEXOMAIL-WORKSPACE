-- E108 — FOUNDER SETTINGS (Settings Center S1 + profile photo), 10/10: ek registry, ek atomic darwaza `founder_setting_set`, har badlav history + founder_audit mein.
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase), security definer RPC (service_role only, search_path pinned), E102 founder_accounts + founder_audit_append par.
--   1) Table      — founder_settings(user_id, key, value jsonb): registry-bound keys, CHECK key list. AWAM `account_profiles` ko haath NAHI lagta (FC18/Rule 35).
--   2) Registry   — personal.display_name (text 2..60), personal.avatar (jpeg/png/webp data URL <=180000 ya https <=500), personal.timezone (asli IANA zone,
--                   pg_timezone_names se check), appearance.graphics (bool), appearance.sidebar_slim (bool). Value null/JSON null = default par wapas.
--   3) History    — founder_settings_history append-only (trigger: update/delete/truncate band); avatar ki puri value nahi, sirf SHA-256 (size + privacy).
--   4) RPC        — founder_setting_set(uid, key, value): founder-only, per-user advisory lock, validate, no-op detect, upsert/delete, history + audit ek transaction.
--                   founder_settings_get(uid): saari values ek jsonb object mein (stable).
--   5) selftest   — har key valid/invalid, null=default, no-op, history, audit chain, non-founder; aakhir mein poora rollback.
-- Gate: G1w (founder token + approved device + signed write + audit) — low-risk apni profile/cosmetic values. Polar :3400 NO-TOUCH. Dobara chalana safe.

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = pg_catalog, public, extensions;

do $$
begin
  if to_regclass('public.founder_accounts') is null or to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then
    raise notice 'E108 SKIP: E102 (founder_accounts / founder_audit_append) pehle chalayein';
    return;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_settings:ddl', 0));

  create table if not exists public.founder_settings (
    user_id uuid not null references public.founder_accounts(user_id) on delete cascade,
    key text not null,
    value jsonb not null,
    updated_at timestamptz not null default now(),
    primary key (user_id, key),
    constraint founder_settings_key_registry check (key in ('personal.display_name','personal.avatar','personal.timezone','appearance.graphics','appearance.sidebar_slim')),
    constraint founder_settings_value_size check (octet_length(value::text) <= 190000)
  );
  alter table public.founder_settings enable row level security;   -- koi policy nahi: anon/authenticated ko kuch nahi; sirf service_role (RLS bypass) + security definer RPC
  revoke all on public.founder_settings from public, anon, authenticated;

  create table if not exists public.founder_settings_history (
    id bigint generated always as identity primary key,
    user_id uuid not null,
    key text not null,
    old_hash text, new_hash text,                    -- SHA-256 of the JSON text (null = default / unset)
    old_value jsonb, new_value jsonb,                -- null for personal.avatar (hash only)
    changed_at timestamptz not null default now()
  );
  create index if not exists founder_settings_history_idx on public.founder_settings_history (user_id, changed_at desc);
  alter table public.founder_settings_history enable row level security;
  revoke all on public.founder_settings_history from public, anon, authenticated;
end $$;

comment on table public.founder_settings is 'E108: founder own settings (registry-bound). Separate from the user app account_profiles on purpose.';
comment on table public.founder_settings_history is 'E108: append-only change history of founder_settings (Time machine reads this in S2). Avatar stored as hash only.';

-- 3) append-only history
do $$
begin
  if to_regclass('public.founder_settings_history') is null then return; end if;
  if to_regprocedure('public._fa_immutable()') is null then return; end if;
  drop trigger if exists founder_settings_history_no_upd on public.founder_settings_history;
  create trigger founder_settings_history_no_upd before update or delete on public.founder_settings_history for each row execute function public._fa_immutable();
  drop trigger if exists founder_settings_history_no_trunc on public.founder_settings_history;
  create trigger founder_settings_history_no_trunc before truncate on public.founder_settings_history for each statement execute function public._fa_immutable();
end $$;

-- 2) registry validator (authoritative; Rust mirrors it as a first line)
create or replace function public._founder_setting_valid(p_key text, p_value jsonb) returns boolean
language plpgsql stable set search_path = pg_catalog, public as $$
declare t text;
begin
  case p_key
    when 'personal.display_name' then
      if jsonb_typeof(p_value) <> 'string' then return false; end if;
      t := p_value #>> '{}';
      return t ~ '^[^\x00-\x1f\x7f<>]{2,60}$' and btrim(t) = t;
    when 'personal.avatar' then
      if jsonb_typeof(p_value) <> 'string' then return false; end if;
      t := p_value #>> '{}';
      if t like 'data:image/%' then
        return length(t) <= 180000 and t ~ '^data:image/(jpeg|jpg|png|webp);base64,[A-Za-z0-9+/=]+$';
      end if;
      return length(t) <= 500 and t ~ '^https://[^\s"<>'']+$';
    when 'personal.timezone' then
      if jsonb_typeof(p_value) <> 'string' then return false; end if;
      t := p_value #>> '{}';
      return length(t) <= 60 and exists (select 1 from pg_timezone_names where name = t);
    when 'appearance.graphics', 'appearance.sidebar_slim' then
      return jsonb_typeof(p_value) = 'boolean';
    else return false;
  end case;
end $$;
revoke all on function public._founder_setting_valid(text, jsonb) from public, anon, authenticated;

-- 4) the one door
create or replace function public.founder_setting_set(p_uid uuid, p_key text, p_value jsonb)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare old jsonb; v_new jsonb := case when p_value is null or jsonb_typeof(p_value) = 'null' then null else p_value end; ho text; hn text; v_avatar boolean := (p_key = 'personal.avatar'); a jsonb;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if p_key is null or p_key not in ('personal.display_name','personal.avatar','personal.timezone','appearance.graphics','appearance.sidebar_slim') then raise exception 'unknown setting' using errcode = '22023'; end if;
  if v_new is not null and not public._founder_setting_valid(p_key, v_new) then raise exception 'invalid value for %', p_key using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_settings:' || p_uid::text, 0));
  select value into old from public.founder_settings where user_id = p_uid and key = p_key;
  if old is not distinct from v_new then return jsonb_build_object('changed', false, 'key', p_key); end if;
  ho := case when old is null then null else encode(digest(old::text, 'sha256'), 'hex') end;
  hn := case when v_new is null then null else encode(digest(v_new::text, 'sha256'), 'hex') end;
  if v_new is null then delete from public.founder_settings where user_id = p_uid and key = p_key;
  else insert into public.founder_settings (user_id, key, value) values (p_uid, p_key, v_new)
       on conflict (user_id, key) do update set value = excluded.value, updated_at = now(); end if;
  insert into public.founder_settings_history (user_id, key, old_hash, new_hash, old_value, new_value)
    values (p_uid, p_key, ho, hn, case when v_avatar then null else old end, case when v_avatar then null else v_new end);
  a := public.founder_audit_append(p_uid, 'settings.' || p_key, p_key, 'founder changed own setting', jsonb_build_object('from', left(coalesce(ho, 'default'), 12), 'to', left(coalesce(hn, 'default'), 12)));
  return jsonb_build_object('changed', true, 'key', p_key, 'audit_seq', a -> 'seq');
end $$;
revoke all on function public.founder_setting_set(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.founder_setting_set(uuid, text, jsonb) to service_role;
comment on function public.founder_setting_set(uuid, text, jsonb) is 'E108: the one door. Validates against the registry, history + audit in the same transaction. null/JSON null = back to default.';

create or replace function public.founder_settings_get(p_uid uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from public.founder_settings where user_id = p_uid
$$;
revoke all on function public.founder_settings_get(uuid) from public, anon, authenticated;
grant execute on function public.founder_settings_get(uuid) to service_role;

-- 5) selftest
create or replace function public.founder_settings_selftest() returns text language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_uid uuid; r text := ''; v_before bigint; v_hist_before bigint; v_audit_before bigint; res jsonb; v_ok boolean; png text := 'data:image/png;base64,iVBORw0KGgo=';
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E108 selftest SKIP — founder_accounts khali'; end if;
  select count(*) into v_before from public.founder_settings; select count(*) into v_hist_before from public.founder_settings_history; select count(*) into v_audit_before from public.founder_audit;
  begin
    delete from public.founder_settings where user_id = v_uid;   -- rollback mein wapas
    res := public.founder_setting_set(v_uid, 'personal.display_name', to_jsonb('Test Founder'::text));
    if (res ->> 'changed')::boolean is not true then raise exception 'display_name set nahi: %', res; end if;
    if public.founder_settings_get(v_uid) -> 'personal.display_name' <> to_jsonb('Test Founder'::text) then raise exception 'get ne value nahi di'; end if;
    r := r || 'display_name OK; ';
    if (public.founder_setting_set(v_uid, 'personal.display_name', to_jsonb('Test Founder'::text)) ->> 'changed')::boolean then raise exception 'no-op change maana gaya'; end if;
    r := r || 'no-op OK; ';
    v_ok := false; begin perform public.founder_setting_set(v_uid, 'personal.display_name', to_jsonb('x'::text)); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'chhota naam qubool'; end if;
    v_ok := false; begin perform public.founder_setting_set(v_uid, 'personal.display_name', to_jsonb('<b>x</b>'::text)); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'html naam qubool'; end if;
    res := public.founder_setting_set(v_uid, 'personal.avatar', to_jsonb(png));
    if (res ->> 'changed')::boolean is not true then raise exception 'avatar set nahi'; end if;
    v_ok := false; begin perform public.founder_setting_set(v_uid, 'personal.avatar', to_jsonb('data:image/svg+xml;base64,PHN2Zz4='::text)); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'svg avatar qubool'; end if;
    v_ok := false; begin perform public.founder_setting_set(v_uid, 'personal.avatar', to_jsonb('javascript:alert(1)'::text)); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'script avatar qubool'; end if;
    if exists (select 1 from public.founder_settings_history where user_id = v_uid and key = 'personal.avatar' and (new_value is not null or old_value is not null)) then raise exception 'avatar ki puri value history mein'; end if;
    r := r || 'avatar valid/invalid + history hash-only OK; ';
    res := public.founder_setting_set(v_uid, 'personal.timezone', to_jsonb('Asia/Karachi'::text));
    if (res ->> 'changed')::boolean is not true then raise exception 'timezone set nahi'; end if;
    v_ok := false; begin perform public.founder_setting_set(v_uid, 'personal.timezone', to_jsonb('Mars/Phobos'::text)); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'jhoota timezone qubool'; end if;
    r := r || 'timezone OK; ';
    res := public.founder_setting_set(v_uid, 'appearance.graphics', to_jsonb(false));
    if (res ->> 'changed')::boolean is not true then raise exception 'graphics set nahi'; end if;
    v_ok := false; begin perform public.founder_setting_set(v_uid, 'appearance.graphics', to_jsonb('off'::text)); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'graphics ko text qubool'; end if;
    res := public.founder_setting_set(v_uid, 'appearance.sidebar_slim', to_jsonb(true));
    r := r || 'appearance OK; ';
    res := public.founder_setting_set(v_uid, 'appearance.graphics', 'null'::jsonb);
    if (res ->> 'changed')::boolean is not true or public.founder_settings_get(v_uid) ? 'appearance.graphics' then raise exception 'null se default nahi hua'; end if;
    r := r || 'null=default OK; ';
    v_ok := false; begin perform public.founder_setting_set(v_uid, 'appearance.nope', to_jsonb(true)); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'unknown key qubool'; end if;
    v_ok := false; begin perform public.founder_setting_set(gen_random_uuid(), 'appearance.graphics', to_jsonb(true)); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'gair-founder ne setting likhi'; end if;
    v_ok := false; begin insert into public.founder_settings (user_id, key, value) values (v_uid, 'bad.key', to_jsonb(1)); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'registry CHECK ne bad.key nahi roka'; end if;
    r := r || 'unknown key + non-founder + CHECK OK; ';
    v_ok := false; begin update public.founder_settings_history set key = 'x' where user_id = v_uid; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'history update ho gayi'; end if;
    v_ok := false; begin delete from public.founder_settings_history where user_id = v_uid; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'history delete ho gayi'; end if;
    r := r || 'history append-only OK; ';
    if (select count(*) from public.founder_audit where action like 'settings.%') < 6 then raise exception 'audit rows kam'; end if;
    if public.founder_audit_verify(1) is not null then raise exception 'audit chain toot gayi'; end if;
    r := r || 'audit chain saaf OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E108 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_settings) <> v_before or (select count(*) from public.founder_settings_history) <> v_hist_before or (select count(*) from public.founder_audit) <> v_audit_before then raise exception 'E108 selftest ne saaf nahi kiya'; end if;
  return 'E108 selftest OK — ' || r || 'rollback saaf';
end $$;
revoke all on function public.founder_settings_selftest() from public, anon, authenticated;
grant execute on function public.founder_settings_selftest() to service_role;

do $$ begin
  if to_regprocedure('public.founder_settings_selftest()') is not null then raise notice '%', public.founder_settings_selftest(); end if;
end $$;
