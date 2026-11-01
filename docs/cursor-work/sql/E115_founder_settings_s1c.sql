-- E115 — Founder Settings S1c: the rest of the awam Settings Center rows, as real registry keys (Personal, Workspace, Notifications, Privacy).
-- Founder order 1 Nov 2026 12:00 / 12:01: "awam walay features founder ko milen" — rows read LIVE from the awam Settings Center (docs/claude/AWAM-SETTINGS-CENTER-LIVE-LIST-01NOV.md).
-- Technology: SQL (Supabase Postgres, RLS on). Rust (settings.rs / settings_s2.rs) and the React-TS UI follow only after this is green on the server (one phase at a time).
--
-- What is in here (8 new keys; registry 14 -> 22):
--   personal.undo_send          enum  0 | 5 | 10 | 20 | 30 | 60 seconds           default 30   (awam "Undo send window")
--   personal.send_check         bool                                               default true (awam "Send confidence check")
--   workspace.retention_days    enum  0 (keep forever) | 30 | 90 | 180 | 365 | 730 | 1825   default 0   (awam "Retention window")
--   workspace.require_passkey   bool                                               default true (founder form of awam "Require two-factor for everyone")
--   workspace.flag_external     bool                                               default true (awam "Flag external recipients")
--   notifications.quiet_hours   bool                                               default true (awam "Quiet hours")
--   notifications.only_vips     bool                                               default false(awam "Only VIPs interrupt")
--   privacy.block_trackers      bool                                               default true (awam "Block tracking pixels")
--   (Read receipts has NO key: awam shows "Never sent" — there is nothing to switch on. The UI shows it as a read-only row.)
--
-- Honest scope: each key stores a real value with the full Time machine (history, undo, ledger entry, hash), Explain, Blast radius and scheduling where allowed.
-- The EFFECT of a key belongs to the step that owns the feature (undo send / send check / external flag / trackers = Mail, step 11; passkey = step 7;
-- quiet hours / VIPs = Decide + Live Pulse, step 8; retention = Mail retention job, step 11). Each Explain text says so — nothing claims to be enforced before it is.
-- Not here: a Drift baseline for these keys. Drift today knows two rules ('set', 'max'); a "safe value" rule needs a change to the drift function and is a later, separate step.
--
-- Also here: E114's two selftests asserted "exactly 14 keys". The registry is the one list and has grown, so they are replaced by this file's selftest, which
-- re-tests every one of the 14 older keys and the 8 new ones. (E114 itself is left untouched: the server keeps a sha ledger of files already run.)
--
-- Safe to run again: create-if-not-exists / create-or-replace / upserts. Everything the selftest does is rolled back.

-- ==============================================================================================================================
-- 0) prerequisites
-- ==============================================================================================================================
do $$
begin
  if to_regclass('public.founder_setting_registry') is null or to_regclass('public.founder_settings_info') is null
     or to_regclass('public.founder_settings_schedule') is null or to_regclass('public.founder_settings_history') is null then
    raise exception 'E115 needs E113 and E114 first (run them in order with sql-run.sh)';
  end if;
  if to_regprocedure('public.founder_setting_set(uuid,text,jsonb)') is null or to_regprocedure('public._founder_setting_valid(text,jsonb)') is null
     or to_regprocedure('public._fa_recipe_valid(jsonb)') is null or to_regprocedure('public._fs_fails(text)') is null then
    raise exception 'E115 needs the E114 validator and the E113 helpers';
  end if;
  if (select count(*) from public.founder_setting_registry) < 14 then raise exception 'E115 expects the 14 keys of E114 to be present'; end if;
end $$;

-- ==============================================================================================================================
-- 1) the 8 new keys join the ONE registry (founder_settings.key and the schedule key are foreign keys to it since E114)
-- ==============================================================================================================================
insert into public.founder_setting_registry (key, area, kind, default_value, label, sort) values
  ('personal.undo_send',        'personal',      'enum', '30'::jsonb,   'Undo send window',          40),
  ('personal.send_check',       'personal',      'bool', 'true'::jsonb, 'Send confidence check',     50),
  ('workspace.retention_days',  'workspace',     'enum', '0'::jsonb,    'Retention window',         300),
  ('workspace.require_passkey', 'workspace',     'bool', 'true'::jsonb, 'Require passkey for every sign-in', 310),
  ('workspace.flag_external',   'workspace',     'bool', 'true'::jsonb, 'Flag external recipients',  320),
  ('notifications.quiet_hours', 'notifications', 'bool', 'true'::jsonb, 'Quiet hours',               400),
  ('notifications.only_vips',   'notifications', 'bool', 'false'::jsonb,'Only VIPs interrupt',       410),
  ('privacy.block_trackers',    'privacy',       'bool', 'true'::jsonb, 'Block tracking pixels',     500)
on conflict (key) do update set area = excluded.area, kind = excluded.kind, default_value = excluded.default_value, label = excluded.label, sort = excluded.sort;

-- ==============================================================================================================================
-- 2) validator: E114's function with the 8 new cases added (every older case is copied unchanged)
-- ==============================================================================================================================
create or replace function public._founder_setting_valid(p_key text, p_value jsonb) returns boolean
language plpgsql stable set search_path = pg_catalog, public as $$
declare t text; e jsonb;
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
    when 'personal.home' then
      if jsonb_typeof(p_value) <> 'object' then return false; end if;
      if (select array_agg(k order by k) from jsonb_object_keys(p_value) k) is distinct from array['city','country','iana','lat','lon'] then return false; end if;
      if jsonb_typeof(p_value -> 'city') <> 'string' or jsonb_typeof(p_value -> 'country') <> 'string' or jsonb_typeof(p_value -> 'iana') <> 'string'
         or jsonb_typeof(p_value -> 'lat') <> 'number' or jsonb_typeof(p_value -> 'lon') <> 'number' then return false; end if;
      if (p_value ->> 'city') !~ '^[^\x00-\x1f\x7f<>]{1,60}$' or (p_value ->> 'country') !~ '^[^\x00-\x1f\x7f<>]{0,60}$' then return false; end if;
      if (p_value ->> 'lat')::numeric not between -90 and 90 or (p_value ->> 'lon')::numeric not between -180 and 180 then return false; end if;
      return exists (select 1 from pg_timezone_names where name = p_value ->> 'iana');
    -- S1c: awam's toggles, one boolean each
    when 'appearance.graphics', 'appearance.sidebar_slim', 'appearance.celebration', 'appearance.focus_ring', 'appearance.reduce_motion',
         'personal.send_check', 'workspace.require_passkey', 'workspace.flag_external', 'notifications.quiet_hours', 'notifications.only_vips', 'privacy.block_trackers' then
      return jsonb_typeof(p_value) = 'boolean';
    -- S1c: exact JSON integers from a closed list (never a string, never 30.5)
    when 'personal.undo_send' then
      return jsonb_typeof(p_value) = 'number' and (p_value #>> '{}') in ('0','5','10','20','30','60');
    when 'workspace.retention_days' then
      return jsonb_typeof(p_value) = 'number' and (p_value #>> '{}') in ('0','30','90','180','365','730','1825');
    when 'appearance.text_scale' then
      return jsonb_typeof(p_value) = 'number' and (p_value #>> '{}') in ('90','100','115','130','150');
    when 'appearance.animations' then
      return jsonb_typeof(p_value) = 'string' and (p_value #>> '{}') in ('full','reduced','none');
    when 'appearance.transitions' then
      return jsonb_typeof(p_value) = 'string' and (p_value #>> '{}') in ('fast','normal','slow');
    when 'appearance.density' then
      return jsonb_typeof(p_value) = 'string' and (p_value #>> '{}') in ('compact','comfortable');
    when 'appearance.ambient' then
      return public._fa_recipe_valid(p_value);
    when 'appearance.ambient_favs' then
      if jsonb_typeof(p_value) <> 'array' or jsonb_array_length(p_value) > 24 then return false; end if;
      for e in select x from jsonb_array_elements(p_value) x loop
        if not public._fa_recipe_valid(e) then return false; end if;
      end loop;
      return (select count(distinct x) from jsonb_array_elements(p_value) x) = jsonb_array_length(p_value);   -- no duplicates
    else return false;
  end case;
end $$;
revoke all on function public._founder_setting_valid(text, jsonb) from public, anon, authenticated;

-- ==============================================================================================================================
-- 3) plain-words info rows (Explain / Blast radius). High severity + not schedulable for the two keys that can lock the founder out or delete mail.
-- ==============================================================================================================================
insert into public.founder_settings_info (key, label, plain, example, tradeoff, surfaces, severity, reversible, schedulable) values
 ('personal.undo_send', 'Undo send window',
  'How many seconds a sent mail is held before it really leaves, so you can take it back. 0 sends at once. The hold itself starts working when Mail Desk is built (step 11); until then this stores your choice.',
  '30 seconds is long enough to catch a wrong recipient.',
  'A longer window delays every outgoing mail by that long; 0 removes the safety net.', array['Mail Desk (step 11)'], 'low', true, true),
 ('personal.send_check', 'Send confidence check',
  'Warns you before sending when the tone, the recipients or an attachment look wrong. The check itself works when Mail Desk is built (step 11); until then this stores your choice.',
  'It would stop a mail with the word "attached" and no attachment.',
  'Off sends without any last look; on adds one confirmation on a flagged mail.', array['Mail Desk (step 11)'], 'low', true, true),
 ('workspace.retention_days', 'Retention window',
  'How long mail is kept before permanent deletion. 0 keeps mail forever; nothing is deleted automatically. The deletion job does not exist yet (Mail, step 11), so today no mail is removed whatever you choose — the value is stored and shown honestly.',
  '365 keeps one year of mail and removes older mail permanently once the job exists.',
  'A short window frees space but deletes for good; a long or forever window keeps everything and keeps the storage bill growing.', array['Mail storage (step 11)'], 'high', true, false),
 ('workspace.require_passkey', 'Require passkey for every sign-in',
  'The founder form of "require two-factor for everyone": every sign-in must use a passkey, not just a token. Passkey sign-in is built in step 7; until then this stores your choice and the existing approved-device gate stays the only door.',
  'On is the recommended setting. Once passkeys exist, a device without one cannot sign in.',
  'On can lock you out if the only passkey is lost, so it comes with the recovery plan of step 7; off keeps sign-in weaker.', array['Sign-in (step 7)'], 'high', true, false),
 ('workspace.flag_external', 'Flag external recipients',
  'Shows a clear warning when a thread leaves the company. The warning appears when Mail Desk is built (step 11); until then this stores your choice.',
  'Replying to a customer from a company thread shows "External recipient".',
  'Off removes the warning, so a wrong address leaves the company without a pause.', array['Mail Desk (step 11)'], 'low', true, true),
 ('notifications.quiet_hours', 'Quiet hours',
  'Silences everything outside working hours, except escalations. Alerts that can interrupt you arrive with Decide and Live Pulse (step 8); until then this stores your choice.',
  'On keeps night-time alerts away unless something is escalated.',
  'Off means every alert can interrupt at any hour.', array['Decide, Live Pulse (step 8)'], 'low', true, true),
 ('notifications.only_vips', 'Only VIPs interrupt',
  'Everything except people on your VIP list waits for the next check. The VIP list and the interruptions arrive with Decide and Live Pulse (step 8); until then this stores your choice.',
  'On during a deep-work block: only your VIPs reach you.',
  'On can delay a real problem from someone who is not on the list.', array['Decide, Live Pulse (step 8)'], 'low', true, true),
 ('privacy.block_trackers', 'Block tracking pixels',
  'Strips tracking pixels from incoming mail before it is shown, so a sender cannot learn that you opened it. The stripping works when Mail Desk is built (step 11); until then this stores your choice.',
  'On is the default: a marketing mail cannot report when you read it.',
  'Off lets remote images load, which can reveal your address and the time you opened the mail.', array['Mail Desk (step 11)'], 'low', true, true)
on conflict (key) do update set label = excluded.label, plain = excluded.plain, example = excluded.example, tradeoff = excluded.tradeoff, surfaces = excluded.surfaces,
  severity = excluded.severity, reversible = excluded.reversible, schedulable = excluded.schedulable;

-- ==============================================================================================================================
-- 4) E114's selftests assumed exactly 14 keys. The registry has grown (and will again), so they are replaced by tests that read the registry.
-- ==============================================================================================================================
drop function if exists public.founder_appearance_selftest();
drop function if exists public.founder_appearance_selftest2();

-- ==============================================================================================================================
-- 5) selftest — behaviour of all 22 keys through the real write door (everything rolled back)
-- ==============================================================================================================================
create or replace function public.founder_settings_s1c_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '90s' as $$
declare
  u uuid; r text := ''; j jsonb; k text; sid uuid; v jsonb; n integer; hid bigint; bad text;
  b_set bigint; b_hist bigint; b_audit bigint; b_rev bigint; b_sch bigint;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E115 selftest SKIP — no founder account'; end if;
  select count(*) into b_set from public.founder_settings; select count(*) into b_hist from public.founder_settings_history; select count(*) into b_audit from public.founder_audit;
  select count(*) into b_rev from public.founder_settings_revert_log; select count(*) into b_sch from public.founder_settings_schedule;
  begin
    delete from public.founder_settings where user_id = u;

    -- registry: 22 keys, every one has an info row and the other way round, every default is a valid value, every key has a sensible area
    if (select count(*) from public.founder_setting_registry) <> 22 then raise exception 'registry must list 22 keys, has %', (select count(*) from public.founder_setting_registry); end if;
    if exists (select 1 from public.founder_settings_info i where not exists (select 1 from public.founder_setting_registry r where r.key = i.key)) then raise exception 'info row without a registry key'; end if;
    if exists (select 1 from public.founder_setting_registry r where not exists (select 1 from public.founder_settings_info i where i.key = r.key)) then raise exception 'registry key without an info row'; end if;
    for k, v in select key, default_value from public.founder_setting_registry where default_value is not null and default_value <> 'null'::jsonb loop
      if not public._founder_setting_valid(k, v) then raise exception 'the default of % is not a valid value', k; end if;
    end loop;
    if (select count(*) from public.founder_setting_registry where area = 'personal') <> 5 or (select count(*) from public.founder_setting_registry where area = 'workspace') <> 3
       or (select count(*) from public.founder_setting_registry where area = 'notifications') <> 2 or (select count(*) from public.founder_setting_registry where area = 'privacy') <> 1
       or (select count(*) from public.founder_setting_registry where area = 'appearance') <> 11 then raise exception 'keys per area are wrong'; end if;
    j := public.founder_setting_registry_list();
    if jsonb_array_length(j) <> 22 then raise exception 'registry list shape: %', j; end if;
    if (select count(*) from jsonb_array_elements(j) e where (e ->> 'schedulable')::boolean) <> 18 then raise exception 'schedulable keys must be 18 (22 minus avatar, favourites, retention, passkey)'; end if;
    r := r || 'registry (22 keys, defaults valid) OK; ';

    -- the two high-severity keys are not schedulable, and the info table says so
    if (select count(*) from public.founder_settings_info where key in ('workspace.retention_days','workspace.require_passkey') and severity = 'high' and not schedulable) <> 2 then raise exception 'retention and passkey must be high severity and not schedulable'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'workspace.retention_days', '90'::jsonb, now() + interval '5 minutes', null, 'selftest retention cannot be scheduled')$q$, u)) then raise exception 'retention was schedulable'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'workspace.require_passkey', 'false'::jsonb, now() + interval '5 minutes', null, 'selftest passkey cannot be scheduled')$q$, u)) then raise exception 'passkey was schedulable'; end if;
    r := r || 'high-severity keys not schedulable OK; ';

    -- every older key still works through the door (E114 behaviour is not lost)
    perform public.founder_setting_set(u, 'personal.display_name', to_jsonb('S1c Tester'::text));
    perform public.founder_setting_set(u, 'personal.home', jsonb_build_object('city','Lahore','country','Pakistan','iana','Asia/Karachi','lat',31.52,'lon',74.36));
    perform public.founder_setting_set(u, 'personal.avatar', to_jsonb('data:image/png;base64,iVBORw0KGgo='::text));
    perform public.founder_setting_set(u, 'appearance.graphics', to_jsonb(false));
    perform public.founder_setting_set(u, 'appearance.sidebar_slim', to_jsonb(true));
    perform public.founder_setting_set(u, 'appearance.text_scale', to_jsonb(115));
    perform public.founder_setting_set(u, 'appearance.animations', to_jsonb('reduced'::text));
    perform public.founder_setting_set(u, 'appearance.transitions', to_jsonb('slow'::text));
    perform public.founder_setting_set(u, 'appearance.celebration', to_jsonb(false));
    perform public.founder_setting_set(u, 'appearance.focus_ring', to_jsonb(true));
    perform public.founder_setting_set(u, 'appearance.density', to_jsonb('compact'::text));
    perform public.founder_setting_set(u, 'appearance.reduce_motion', to_jsonb(true));
    perform public.founder_setting_set(u, 'appearance.ambient', public.founder_ambient_at(1000));
    perform public.founder_setting_set(u, 'appearance.ambient_favs', jsonb_build_array(public.founder_ambient_at(7), public.founder_ambient_at(9)));
    r := r || '14 older keys OK; ';

    -- Undo send window: the closed list passes, everything else is refused
    foreach v in array array['0'::jsonb,'5'::jsonb,'10'::jsonb,'20'::jsonb,'30'::jsonb,'60'::jsonb] loop
      perform public.founder_setting_set(u, 'personal.undo_send', v);
    end loop;
    foreach bad in array array['15','-5','61','30.5','"30"','true','null','[30]','{"s":30}','300'] loop
      if bad = 'null' then continue; end if;   -- null is "back to the default", tested below
      if not public._fs_fails(format($q$select public.founder_setting_set(%L, 'personal.undo_send', %L::jsonb)$q$, u, bad)) then raise exception 'undo_send accepted %', bad; end if;
    end loop;
    r := r || 'undo_send (6 good, 9 bad) OK; ';

    -- Retention window: closed list
    foreach v in array array['0'::jsonb,'30'::jsonb,'90'::jsonb,'180'::jsonb,'365'::jsonb,'730'::jsonb,'1825'::jsonb] loop
      perform public.founder_setting_set(u, 'workspace.retention_days', v);
    end loop;
    foreach bad in array array['1','7','45','364','366','1826','-30','90.5','"90"','false','[90]','1e2'] loop
      if not public._fs_fails(format($q$select public.founder_setting_set(%L, 'workspace.retention_days', %L::jsonb)$q$, u, bad)) then raise exception 'retention accepted %', bad; end if;
    end loop;
    r := r || 'retention (7 good, 12 bad) OK; ';

    -- the six toggles: booleans only
    foreach k in array array['personal.send_check','workspace.require_passkey','workspace.flag_external','notifications.quiet_hours','notifications.only_vips','privacy.block_trackers'] loop
      perform public.founder_setting_set(u, k, to_jsonb(true));
      perform public.founder_setting_set(u, k, to_jsonb(false));
      foreach bad in array array['"true"','1','0','[]','{}','"yes"'] loop
        if not public._fs_fails(format($q$select public.founder_setting_set(%L, %L, %L::jsonb)$q$, u, k, bad)) then raise exception '% accepted non-boolean %', k, bad; end if;
      end loop;
    end loop;
    r := r || '6 toggles (boolean only) OK; ';

    -- the stored value is exactly what was set, and null puts every new key back to its default (no row stored)
    perform public.founder_setting_set(u, 'personal.undo_send', to_jsonb(10));
    if public._fs_current(u, 'personal.undo_send') <> to_jsonb(10) then raise exception 'undo_send was not stored'; end if;
    for k in select key from public.founder_setting_registry where key in ('personal.undo_send','personal.send_check','workspace.retention_days','workspace.require_passkey','workspace.flag_external','notifications.quiet_hours','notifications.only_vips','privacy.block_trackers') loop
      perform public.founder_setting_set(u, k, null);
      if exists (select 1 from public.founder_settings where user_id = u and key = k) then raise exception 'null did not return % to its default', k; end if;
    end loop;
    r := r || 'store + null-to-default OK; ';

    -- an unchanged value is not a change (no history row, no ledger entry)
    perform public.founder_setting_set(u, 'privacy.block_trackers', to_jsonb(false));
    select count(*) into n from public.founder_settings_history where user_id = u and key = 'privacy.block_trackers';
    j := public.founder_setting_set(u, 'privacy.block_trackers', to_jsonb(false));
    if (j ->> 'changed')::boolean is not false then raise exception 'setting the same value twice must report changed=false'; end if;
    if (select count(*) from public.founder_settings_history where user_id = u and key = 'privacy.block_trackers') <> n then raise exception 'an unchanged value wrote history'; end if;
    r := r || 'no-op not recorded OK; ';

    -- Time machine: every change of a new key has a version, a ledger entry and can be undone exactly once
    select count(*) into n from public.founder_settings_history where user_id = u and key = 'notifications.only_vips';
    perform public.founder_setting_set(u, 'notifications.only_vips', to_jsonb(true));
    perform public.founder_setting_set(u, 'notifications.only_vips', to_jsonb(false));
    j := public.founder_settings_history_list(u, 'notifications.only_vips', null, 50);
    if jsonb_array_length(j -> 'items') <> n + 2 then raise exception 'history must list 2 new versions of only_vips (had %): %', n, jsonb_array_length(j -> 'items'); end if;
    if (j -> 'items' -> 0 ->> 'audit_seq') is null then raise exception 'history entry without a ledger entry'; end if;
    hid := public._fs_last_history_id(u, 'notifications.only_vips');
    j := public.founder_setting_revert(u, hid, 'selftest undo only vips');
    if public._fs_current(u, 'notifications.only_vips') is distinct from to_jsonb(true) then raise exception 'undo of only_vips did not restore the old value'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'selftest undo twice')$q$, u, hid)) then raise exception 'a version was undone twice'; end if;
    perform public.founder_setting_set(u, 'workspace.retention_days', to_jsonb(365));
    perform public.founder_setting_set(u, 'workspace.retention_days', to_jsonb(90));
    j := public.founder_setting_revert(u, public._fs_last_history_id(u, 'workspace.retention_days'), 'selftest undo retention');
    if public._fs_current(u, 'workspace.retention_days') <> to_jsonb(365) then raise exception 'undo of retention failed'; end if;
    r := r || 'history + undo OK; ';

    -- Explain and Blast radius answer for every new key
    for k in select key from public.founder_setting_registry where key in ('personal.undo_send','personal.send_check','workspace.retention_days','workspace.require_passkey','workspace.flag_external','notifications.quiet_hours','notifications.only_vips','privacy.block_trackers') loop
      j := public.founder_setting_explain(k);
      if j ->> 'plain' is null or length(j ->> 'plain') < 60 then raise exception 'explain too thin for %', k; end if;
      j := public.founder_setting_blast(u, k);
      if j ->> 'severity' is null then raise exception 'blast without severity for %', k; end if;
    end loop;
    if (public.founder_setting_blast(u, 'workspace.retention_days') ->> 'severity') <> 'high' or (public.founder_setting_blast(u, 'workspace.require_passkey') ->> 'severity') <> 'high' then raise exception 'retention and passkey must be high severity'; end if;
    r := r || 'explain + blast radius OK; ';

    -- a schedulable new key can be scheduled, applied by the tick, and rolled back by the timer
    perform public.founder_setting_set(u, 'notifications.quiet_hours', to_jsonb(true));
    j := public.founder_settings_schedule_create(u, 'notifications.quiet_hours', to_jsonb(false), now() + interval '2 minutes', 15, 'selftest quiet hours off for a deploy');
    sid := (j ->> 'id')::uuid;
    perform public.founder_settings_schedule_tick(now() + interval '3 minutes');
    if public._fs_current(u, 'notifications.quiet_hours') is distinct from to_jsonb(false) then raise exception 'scheduled quiet_hours not applied'; end if;
    perform public.founder_settings_schedule_tick(now() + interval '30 minutes');
    if public._fs_current(u, 'notifications.quiet_hours') is distinct from to_jsonb(true) or (select state from public.founder_settings_schedule where id = sid) <> 'rolled_back' then raise exception 'scheduled quiet_hours not rolled back'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'personal.undo_send', '15'::jsonb, now() + interval '5 minutes', null, 'selftest bad scheduled value')$q$, u)) then raise exception 'a bad value was scheduled'; end if;
    r := r || 'schedule + rollback OK; ';

    -- unknown keys and non-founders are still refused
    if not public._fs_fails(format($q$select public.founder_setting_set(%L, 'privacy.read_receipts', 'true'::jsonb)$q$, u)) then raise exception 'read receipts must have NO key (it is a fixed "Never sent")'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_set(%L, 'workspace.nope', 'true'::jsonb)$q$, u)) then raise exception 'unknown workspace key accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_set(%L, 'privacy.block_trackers', 'true'::jsonb)$q$, gen_random_uuid())) then raise exception 'non-founder wrote a setting'; end if;
    if public._fs_fails(format($q$insert into public.founder_settings (user_id, key, value) values (%L, 'bad.key', 'true'::jsonb)$q$, u)) is not true then raise exception 'unregistered key stored'; end if;
    r := r || 'unknown key / non-founder refused OK; ';

    -- the history replay and the Time machine still agree with the live table, drift still answers, chain clean
    if public.founder_settings_replay_check(u) is not null then raise exception 'replay check dirty: %', public.founder_settings_replay_check(u); end if;
    if public.founder_settings_crosscheck(u) not like 'E113 crosscheck OK%' then raise exception 'crosscheck: %', public.founder_settings_crosscheck(u); end if;
    if (public.founder_settings_drift(u) ->> 'score')::integer not between 0 and 100 then raise exception 'drift broken'; end if;
    if public.founder_audit_verify(1) is not null then raise exception 'audit chain broken'; end if;
    r := r || 'replay + drift + chain OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E115 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_settings) <> b_set or (select count(*) from public.founder_settings_history) <> b_hist or (select count(*) from public.founder_audit) <> b_audit
     or (select count(*) from public.founder_settings_revert_log) <> b_rev or (select count(*) from public.founder_settings_schedule) <> b_sch then
    raise exception 'E115 selftest left rows behind';
  end if;
  return 'E115 selftest OK — ' || r || 'rollback clean';
end $$;

-- ==============================================================================================================================
-- 6) selftest2 — structure, privileges, hygiene (read-only)
-- ==============================================================================================================================
create or replace function public.founder_settings_s1c_selftest2() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r text := ''; t text; f text;
begin
  foreach t in array array['public.founder_setting_registry','public.founder_settings_info','public.founder_settings_baseline','public.founder_settings_schedule','public.founder_settings_revert_log'] loop
    if to_regclass(t) is null then raise exception 'table missing: %', t; end if;
    if not (select relrowsecurity from pg_class where oid = to_regclass(t)) then raise exception 'RLS off on %', t; end if;
    if has_table_privilege('anon', t, 'select') or has_table_privilege('authenticated', t, 'select') or has_table_privilege('anon', t, 'insert') or has_table_privilege('authenticated', t, 'insert') then raise exception 'anon/authenticated can reach %', t; end if;
  end loop;
  if has_table_privilege('service_role', 'public.founder_setting_registry', 'insert') or has_table_privilege('service_role', 'public.founder_setting_registry', 'update')
     or has_table_privilege('service_role', 'public.founder_setting_registry', 'delete') then raise exception 'the registry must be read-only for service_role'; end if;
  if has_table_privilege('service_role', 'public.founder_settings_info', 'insert') or has_table_privilege('service_role', 'public.founder_settings_info', 'update') then raise exception 'info must be read-only for service_role'; end if;
  r := r || 'tables OK; ';
  foreach f in array array['public.founder_setting_set(uuid,text,jsonb)','public.founder_setting_registry_list()','public.founder_settings_s1c_selftest()','public.founder_settings_s1c_selftest2()'] loop
    if to_regprocedure(f) is null then raise exception 'function missing: %', f; end if;
    if has_function_privilege('anon', f, 'execute') or has_function_privilege('authenticated', f, 'execute') or not has_function_privilege('service_role', f, 'execute') then raise exception 'wrong execute privileges on %', f; end if;
  end loop;
  if has_function_privilege('anon', 'public._founder_setting_valid(text,jsonb)', 'execute') or has_function_privilege('authenticated', 'public._founder_setting_valid(text,jsonb)', 'execute') then raise exception 'validator is reachable by anon/authenticated'; end if;
  r := r || 'functions OK; ';
  if to_regprocedure('public.founder_appearance_selftest()') is not null or to_regprocedure('public.founder_appearance_selftest2()') is not null then raise exception 'the E114 fixed-count selftests must be gone'; end if;
  if not exists (select 1 from pg_constraint where conname = 'founder_settings_key_fk') or not exists (select 1 from pg_constraint where conname = 'founder_settings_schedule_key_fk') then raise exception 'registry foreign keys missing'; end if;
  if exists (select 1 from public.founder_setting_registry where key !~ '^[a-z]+(\.[a-z_]+)+$') then raise exception 'a registry key has a bad shape'; end if;
  if exists (select 1 from public.founder_setting_registry r where not exists (select 1 from public.founder_settings_info i where i.key = r.key)) then raise exception 'every registry key needs an info row'; end if;
  if exists (select 1 from public.founder_settings_info i where not exists (select 1 from public.founder_setting_registry r where r.key = i.key)) then raise exception 'info has a key outside the registry'; end if;
  if exists (select 1 from public.founder_settings_info where length(plain) < 40 or example is null or surfaces = '{}'::text[]) then raise exception 'an info row is too thin'; end if;
  r := r || 'registry hygiene OK; ';
  return 'E115 selftest2 OK — ' || r || 'done';
end $$;

-- ==============================================================================================================================
-- 7) grants (service_role only)
-- ==============================================================================================================================
do $$
declare f text;
begin
  foreach f in array array['public.founder_settings_s1c_selftest()','public.founder_settings_s1c_selftest2()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

comment on function public.founder_settings_s1c_selftest() is 'E115: behaviour of all 22 registry keys through the real write door; every row it writes is rolled back.';

-- ==============================================================================================================================
-- 8) run the selftests now (output shows in sql-run.sh)
-- ==============================================================================================================================
do $$ begin
  raise notice '%', public.founder_settings_s1c_selftest();
  raise notice '%', public.founder_settings_s1c_selftest2();
  raise notice 'E115 registry keys: %', (select count(*) from public.founder_setting_registry);
end $$;

-- ==============================================================================================================================
-- RUNBOOK (comments only)
-- ==============================================================================================================================
-- Run:        bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E115_founder_settings_s1c CHECK_E115   (after the usual fetch)
-- Order:      E102 -> E107 -> E108 -> E109 -> E113 -> E114 -> E115. Safe to run again.
-- Rust:       settings.rs REGISTRY 14 -> 22 keys + validation; settings_s2.rs SCHEDULABLE 12 -> 18 (adds the 6 toggles-with-low-risk: undo_send, send_check, flag_external, quiet_hours, only_vips, block_trackers).
-- UI:         Personal gains Undo send + Send confidence check rows; Workspace, Notifications and Privacy tabs go live (Read receipts = read-only "Never sent").
-- Undo plan:  delete from founder_settings / founder_settings_schedule where key is one of the 8; delete the 8 registry + info rows; restore the E114 validator (re-run E114).
