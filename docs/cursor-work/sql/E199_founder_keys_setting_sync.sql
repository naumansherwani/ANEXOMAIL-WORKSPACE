
-- E199 — QC8a: the "Single-letter keyboard shortcuts" switch becomes a REAL founder setting that follows him to every device.
-- His word 21 Nov 2026 04:55 PKT: "DONO KERO" (settings sync AND shortcut audit log; the log is E200).
-- SCHEMA-FIRST (law 20 Nov 2026): read E114 (founder_setting_registry, founder_setting_set, validator) and E115 (the newest validator copy, info rows, selftest style) BEFORE this file.
-- Technology: SQL (Supabase Postgres, RLS on). Sits ON TOP of E114 / E115 / E113; it does not copy or edit them.
--
-- What is in here:
--   1) ONE new registry key  mail.single_keys  (area mail, kind bool, default true = shortcuts ON, WCAG 2.1.4 switch)
--   2) the validator is WRAPPED, not copied: the current _founder_setting_valid becomes _founder_setting_valid_base199 and a thin
--      _founder_setting_valid answers for the new key and hands every other key to the base. E115's 22 keys keep their exact behaviour.
--   3) a plain-words info row (Explain / Blast radius) for the key
--   4) a read door founder_keys_switch199(uid) = the stored value or the default, so the UI/Rust can ask in ONE call
--   5) posture + rolling-back selftest
-- Honest scope: this is the SERVER side only. Today the React switch still stores in the browser (keys_store.ts). The sync is WIRED only when the Rust
-- settings registry mirror (settings.rs REGISTRY) and keys_store.ts read/write this key; that is a separate step and until then nothing claims it is synced.
-- Safe to run again. If E115 is ever re-run it puts its own validator back; run this file again and the wrapper returns (marker below).

do $$
begin
  if to_regclass('public.founder_setting_registry') is null or to_regclass('public.founder_settings_info') is null or to_regclass('public.founder_settings') is null then
    raise exception 'E199 needs E113, E114 and E115 first (run them in order with sql-run.sh)';
  end if;
  if to_regprocedure('public.founder_setting_set(uuid,text,jsonb)') is null or to_regprocedure('public._founder_setting_valid(text,jsonb)') is null then
    raise exception 'E199 needs the E114 write door and the validator';
  end if;
  if (select count(*) from public.founder_setting_registry where key <> 'mail.single_keys') < 22 then raise exception 'E199 expects the 22 keys of E115'; end if;
end $$;

-- 1) the key joins the ONE registry (founder_settings.key and the schedule key are foreign keys to it since E114)
insert into public.founder_setting_registry (key, area, kind, default_value, label, sort) values
  ('mail.single_keys', 'mail', 'bool', 'true'::jsonb, 'Single-letter keyboard shortcuts', 600)
on conflict (key) do update set area = excluded.area, kind = excluded.kind, default_value = excluded.default_value, label = excluded.label, sort = excluded.sort;

-- 2) validator wrapper (marker: E199 wrapper)
do $$
declare v_def text;
begin
  select pg_get_functiondef('public._founder_setting_valid(text,jsonb)'::regprocedure) into v_def;
  if v_def not like '%E199 wrapper%' then
    if to_regprocedure('public._founder_setting_valid_base199(text,jsonb)') is not null then drop function public._founder_setting_valid_base199(text, jsonb); end if;
    alter function public._founder_setting_valid(text, jsonb) rename to _founder_setting_valid_base199;
    revoke all on function public._founder_setting_valid_base199(text, jsonb) from public, anon, authenticated;
  end if;
end $$;

create or replace function public._founder_setting_valid(p_key text, p_value jsonb) returns boolean
language plpgsql stable set search_path = pg_catalog, public as $$
begin
  -- E199 wrapper: the new key is answered here, every other key by the function that was there before (E115)
  if p_key = 'mail.single_keys' then return jsonb_typeof(p_value) = 'boolean'; end if;
  return public._founder_setting_valid_base199(p_key, p_value);
end $$;
revoke all on function public._founder_setting_valid(text, jsonb) from public, anon, authenticated;

-- 3) plain-words info row
insert into public.founder_settings_info (key, label, plain, example, tradeoff, surfaces, severity, reversible, schedulable) values
 ('mail.single_keys', 'Single-letter keyboard shortcuts',
  'Turns the one-letter mail keys (j k e # s u r a f c g /) on or off. Off keeps Esc, Enter, the arrow keys and every Ctrl or Cmd shortcut. It exists so a person using speech input or a single-key device cannot trigger an action by accident (WCAG 2.1.4). The switch is stored per founder, so every device you sign in on follows it once the apps read this key.',
  'Off while dictating a long reply by voice: nothing in the mail list can act on the letters you say.',
  'Off removes the fast keys, so every mail action needs the mouse, the arrow keys with Enter, or the command palette; on keeps them one keystroke away.',
  array['Mail list', 'Settings > Appearance', 'Shortcuts sheet'], 'low', true, true)
on conflict (key) do update set label = excluded.label, plain = excluded.plain, example = excluded.example, tradeoff = excluded.tradeoff, surfaces = excluded.surfaces,
  severity = excluded.severity, reversible = excluded.reversible, schedulable = excluded.schedulable;

-- 4) one read door: stored value, else the registry default (never null)
create or replace function public.founder_keys_switch199(p_uid uuid) returns boolean
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v jsonb;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  select value into v from public.founder_settings where user_id = p_uid and key = 'mail.single_keys';
  if v is null then select default_value into v from public.founder_setting_registry where key = 'mail.single_keys'; end if;
  return coalesce((v #>> '{}')::boolean, true);
end $$;
revoke all on function public.founder_keys_switch199(uuid) from public, anon, authenticated;
grant execute on function public.founder_keys_switch199(uuid) to service_role;

-- 5) posture (read-only facts)
create or replace function public.founder_keys_posture199() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare r jsonb := '{}'::jsonb;
begin
  r := r || jsonb_build_object('key_registered', exists (select 1 from public.founder_setting_registry where key = 'mail.single_keys' and area = 'mail' and kind = 'bool'));
  r := r || jsonb_build_object('default_true', (select default_value = 'true'::jsonb from public.founder_setting_registry where key = 'mail.single_keys'));
  r := r || jsonb_build_object('info_row', exists (select 1 from public.founder_settings_info where key = 'mail.single_keys' and severity = 'low' and reversible and schedulable));
  r := r || jsonb_build_object('wrapper_in_place', pg_get_functiondef('public._founder_setting_valid(text,jsonb)'::regprocedure) like '%E199 wrapper%' and to_regprocedure('public._founder_setting_valid_base199(text,jsonb)') is not null);
  r := r || jsonb_build_object('validator_not_public', not has_function_privilege('public', 'public._founder_setting_valid(text,jsonb)', 'execute') and not has_function_privilege('anon', 'public._founder_setting_valid(text,jsonb)', 'execute'));
  r := r || jsonb_build_object('read_door_service_only', has_function_privilege('service_role', 'public.founder_keys_switch199(uuid)', 'execute') and not has_function_privilege('anon', 'public.founder_keys_switch199(uuid)', 'execute') and not has_function_privilege('authenticated', 'public.founder_keys_switch199(uuid)', 'execute'));
  r := r || jsonb_build_object('fk_to_registry', exists (select 1 from pg_constraint where conname = 'founder_settings_key_fk' and conrelid = 'public.founder_settings'::regclass));
  return r;
end $$;
revoke all on function public.founder_keys_posture199() from public, anon, authenticated;
grant execute on function public.founder_keys_posture199() to service_role;

-- 6) selftest: everything is rolled back
create or replace function public.founder_keys_selftest199() returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare u uuid; n int := 0; p int := 0; b_hist bigint; b_audit bigint; v_msg text; j jsonb;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return jsonb_build_object('ok', true, 'skipped', 'no founder account', 'passed', 0, 'total', 0); end if;
  select count(*) into b_hist from public.founder_settings_history; select count(*) into b_audit from public.founder_audit;
  begin
    n := n + 1; if public.founder_keys_switch199(u) is not true then raise exception 'default must be ON'; end if; p := p + 1;
    n := n + 1; if not public._founder_setting_valid('mail.single_keys', 'true'::jsonb) or not public._founder_setting_valid('mail.single_keys', 'false'::jsonb) then raise exception 'booleans must be valid'; end if; p := p + 1;
    n := n + 1; if public._founder_setting_valid('mail.single_keys', '"off"'::jsonb) or public._founder_setting_valid('mail.single_keys', '1'::jsonb) or public._founder_setting_valid('mail.single_keys', '{}'::jsonb) or public._founder_setting_valid('mail.single_keys', '[]'::jsonb) then raise exception 'non-booleans must be refused'; end if; p := p + 1;
    n := n + 1; if not public._founder_setting_valid('appearance.graphics', 'true'::jsonb) or public._founder_setting_valid('appearance.text_scale', '77'::jsonb) or public._founder_setting_valid('nope.key', 'true'::jsonb) then raise exception 'older keys must behave as before'; end if; p := p + 1;
    n := n + 1; j := public.founder_setting_set(u, 'mail.single_keys', 'false'::jsonb); if (j ->> 'changed')::boolean is not true then raise exception 'write must change'; end if; p := p + 1;
    n := n + 1; if public.founder_keys_switch199(u) is not false then raise exception 'stored OFF must read back'; end if; p := p + 1;
    n := n + 1; j := public.founder_setting_set(u, 'mail.single_keys', 'false'::jsonb); if (j ->> 'changed')::boolean is not false then raise exception 'same value must be a no-op'; end if; p := p + 1;
    n := n + 1; begin perform public.founder_setting_set(u, 'mail.single_keys', '"x"'::jsonb); raise exception 'bad value was accepted'; exception when sqlstate '22023' then p := p + 1; end;
    n := n + 1; if (select count(*) from public.founder_settings_history where user_id = u and key = 'mail.single_keys') < 1 or (select count(*) from public.founder_audit) <= b_audit then raise exception 'history and audit ledger must grow'; end if; p := p + 1;
    n := n + 1; j := public.founder_setting_set(u, 'mail.single_keys', null); if public.founder_keys_switch199(u) is not true then raise exception 'reset must return to the default ON'; end if; p := p + 1;
    n := n + 1; begin perform public.founder_keys_switch199(gen_random_uuid()); raise exception 'a stranger was answered'; exception when sqlstate '42501' then p := p + 1; end;
    raise exception 'E199_ROLLBACK';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'E199_ROLLBACK' then return jsonb_build_object('ok', false, 'passed', p, 'total', n, 'failed_at', n, 'error', v_msg); end if;
  end;
  if (select count(*) from public.founder_settings_history) <> b_hist then return jsonb_build_object('ok', false, 'error', 'selftest left history rows behind'); end if;
  return jsonb_build_object('ok', p = n, 'passed', p, 'total', n);
end $$;
revoke all on function public.founder_keys_selftest199() from public, anon, authenticated;
grant execute on function public.founder_keys_selftest199() to service_role;
