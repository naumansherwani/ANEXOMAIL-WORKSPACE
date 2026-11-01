-- E116 — Founder Settings S1d: Drift & schedule measure the new S1c rows. A third baseline rule, "value": the recommended safe value of a setting (true / false / a number).
-- Founder order 1 Nov 2026 12:14: close the honest gaps of S1c ("yeh sari haadein ko par kero") — the 8 awam rows had no Drift baseline.
-- Technology: SQL (Supabase Postgres, RLS on). The Drift page already shows any item; the Schedule form (UI) is widened in the same phase.
--
-- What changes:
--   1) founder_settings_baseline gets a 'value' rule: safe_value (jsonb) + if_off ('loose' | 'risky' = how bad it is when the value differs). E113's two rules ('set', 'max') are unchanged.
--   2) founder_settings_drift: a 'value' item compares the account's current value (or the registry default when nothing is stored) with the safe value.
--   3) founder_setting_explain: "recommended" shows the safe value for a 'value' item.
--   4) 5 baseline rows: require passkey (risky when off), flag external, send check, quiet hours, block trackers (looser when off).
--      NOT measured on purpose: undo window, retention, only-VIPs — they are choices, not safety defaults; a baseline would call a legitimate choice "drift".
-- E113 itself is left untouched (the server keeps a sha ledger of files already run); this file replaces the two functions. Safe to run again. Everything the selftest does is rolled back.

do $$
begin
  if to_regclass('public.founder_settings_baseline') is null or to_regprocedure('public.founder_settings_drift(uuid)') is null or to_regprocedure('public.founder_setting_explain(text)') is null then
    raise exception 'E116 needs E113';
  end if;
  if (select count(*) from public.founder_setting_registry) < 22 then raise exception 'E116 needs E115 first (22 registry keys)'; end if;
end $$;

-- 1) the table
alter table public.founder_settings_baseline add column if not exists safe_value jsonb;
alter table public.founder_settings_baseline add column if not exists if_off text not null default 'loose';
do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid = 'public.founder_settings_baseline'::regclass and contype = 'c'
            and (pg_get_constraintdef(oid) like '%rule%') and conname <> 'founder_settings_baseline_if_off_ok' loop
    execute format('alter table public.founder_settings_baseline drop constraint %I', c.conname);
  end loop;
  alter table public.founder_settings_baseline add constraint founder_settings_baseline_value_rule_ok check (
    (rule = 'set'   and recommended is null     and safe_value is null) or
    (rule = 'max'   and recommended is not null and recommended > 0 and safe_value is null) or
    (rule = 'value' and recommended is null     and safe_value is not null));
  if not exists (select 1 from pg_constraint where conname = 'founder_settings_baseline_if_off_ok') then
    alter table public.founder_settings_baseline add constraint founder_settings_baseline_if_off_ok check (if_off in ('loose','risky'));
  end if;
end $$;

-- 2) five baseline rows (source 'setting' = a registry key)
insert into public.founder_settings_baseline (key, source, rule, recommended, safe_value, if_off, label, why, sort) values
 ('workspace.require_passkey', 'setting', 'value', null, 'true'::jsonb,  'risky', 'Passkey is required for every sign-in', 'Without a passkey requirement a stolen token is enough to sign in. Recommended: on (it takes effect when passkey sign-in exists, step 7).', 60),
 ('workspace.flag_external',   'setting', 'value', null, 'true'::jsonb,  'loose', 'External recipients are flagged', 'Without the warning a mail can leave the company by a mistyped address and nobody pauses.', 70),
 ('personal.send_check',       'setting', 'value', null, 'true'::jsonb,  'loose', 'Send confidence check is on', 'The check catches a missing attachment or a wrong recipient before the mail leaves.', 80),
 ('notifications.quiet_hours', 'setting', 'value', null, 'true'::jsonb,  'loose', 'Quiet hours are on', 'Without quiet hours every alert can interrupt at any hour, which hides the ones that really matter.', 90),
 ('privacy.block_trackers',    'setting', 'value', null, 'true'::jsonb,  'loose', 'Tracking pixels are blocked', 'Remote tracking pixels tell a sender that you opened a mail, and from where.', 100)
on conflict (key) do update set source = excluded.source, rule = excluded.rule, recommended = excluded.recommended, safe_value = excluded.safe_value, if_off = excluded.if_off, label = excluded.label, why = excluded.why, sort = excluded.sort;

-- 3) drift: E113's function plus the 'value' rule
create or replace function public.founder_settings_drift(p_uid uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare b record; pol public.founder_audit_merkle_policy%rowtype; v_cur jsonb; v_num numeric; v_state text; v_items jsonb := '[]'::jsonb;
        na integer := 0; nl integer := 0; nr integer := 0; v_rows bigint; v_last bigint; v_lag bigint;
begin
  perform public._fs_assert_founder(p_uid);
  select * into pol from public.founder_audit_merkle_policy where id;
  for b in select * from public.founder_settings_baseline order by sort, key loop
    v_state := 'aligned'; v_cur := null;
    if b.rule = 'set' then
      v_cur := public._fs_current(p_uid, b.key);
      if v_cur is null then v_state := 'loose'; end if;
    elsif b.rule = 'value' then
      v_cur := coalesce(public._fs_current(p_uid, b.key), (select default_value from public.founder_setting_registry where key = b.key));
      if v_cur is distinct from b.safe_value then v_state := b.if_off; end if;
    else
      v_num := case b.key when 'audit.merkle.every_rows' then pol.every_rows when 'audit.merkle.warn_lag_rows' then pol.warn_lag_rows
                          when 'audit.merkle.fail_lag_rows' then pol.fail_lag_rows else null end;
      if v_num is null then continue; end if;
      v_cur := to_jsonb(v_num);
      if v_num > b.recommended * 10 then v_state := 'risky'; elsif v_num > b.recommended then v_state := 'loose'; end if;
    end if;
    if v_state = 'aligned' then na := na + 1; elsif v_state = 'loose' then nl := nl + 1; else nr := nr + 1; end if;
    v_items := v_items || jsonb_build_object('key', b.key, 'label', b.label, 'state', v_state, 'current', v_cur,
                                             'recommended', case when b.rule = 'set' then to_jsonb('set'::text) when b.rule = 'value' then b.safe_value else to_jsonb(b.recommended) end, 'why', b.why);
  end loop;
  select coalesce(max(seq), 0) into v_rows from public.founder_audit;
  select coalesce(max(upto_seq), 0) into v_last from public.founder_audit_checkpoints;
  v_lag := greatest(v_rows - v_last, 0);
  v_state := case when v_lag > pol.fail_lag_rows then 'risky' when v_lag > pol.warn_lag_rows then 'loose' else 'aligned' end;
  if v_state = 'aligned' then na := na + 1; elsif v_state = 'loose' then nl := nl + 1; else nr := nr + 1; end if;
  v_items := v_items || jsonb_build_object('key', 'audit.merkle.lag', 'label', 'Unsealed ledger entries right now', 'state', v_state, 'current', to_jsonb(v_lag),
                                           'recommended', to_jsonb(pol.warn_lag_rows), 'why', 'Entries since the last seal. Above the warning lag the tail is no longer provably covered by a seal.');
  return jsonb_build_object('score', public._fs_drift_score(na, nl, nr), 'aligned', na, 'loose', nl, 'risky', nr, 'items', v_items,
                            'at_ms', public._fs_ms(clock_timestamp()));
end $$;
revoke all on function public.founder_settings_drift(uuid) from public, anon, authenticated;
grant execute on function public.founder_settings_drift(uuid) to service_role;

-- 4) explain: the recommended value of a 'value' item
create or replace function public.founder_setting_explain(p_key text)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare i public.founder_settings_info%rowtype; b public.founder_settings_baseline%rowtype;
begin
  select * into i from public.founder_settings_info where key = p_key;
  if not found then raise exception 'unknown setting' using errcode = '22023'; end if;
  select * into b from public.founder_settings_baseline where key = p_key;
  return jsonb_build_object('key', i.key, 'label', i.label, 'plain', i.plain, 'example', i.example, 'tradeoff', i.tradeoff, 'source', 'server',
                            'recommended', case when b.key is null then null when b.rule = 'set' then to_jsonb('set'::text) when b.rule = 'value' then b.safe_value else to_jsonb(b.recommended) end,
                            'why_recommended', b.why);
end $$;
revoke all on function public.founder_setting_explain(text) from public, anon, authenticated;
grant execute on function public.founder_setting_explain(text) to service_role;

-- 5) selftest (rolled back)
create or replace function public.founder_drift_value_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare u uuid; r text := ''; j jsonb; j2 jsonb; st text; k text; n_items integer;
        b_set bigint; b_hist bigint; b_audit bigint; b_rev bigint; b_sch bigint;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E116 selftest SKIP — no founder account'; end if;
  select count(*) into b_set from public.founder_settings; select count(*) into b_hist from public.founder_settings_history; select count(*) into b_audit from public.founder_audit;
  select count(*) into b_rev from public.founder_settings_revert_log; select count(*) into b_sch from public.founder_settings_schedule;
  begin
    -- NOTE: no raw delete of the live table (the history replay must keep agreeing with it, also on an account that already holds real values).
    -- The five keys are put back to their defaults through the real write door instead, which records each step.
    foreach k in array array['workspace.require_passkey','workspace.flag_external','personal.send_check','notifications.quiet_hours','privacy.block_trackers'] loop
      perform public.founder_setting_set(u, k, null);
    end loop;
    -- structure: 5 'value' rows, the old rules intact, every value row names a registry key with a boolean default equal to its safe value
    if (select count(*) from public.founder_settings_baseline where rule = 'value') <> 5 then raise exception 'five value rules expected'; end if;
    if (select count(*) from public.founder_settings_baseline where rule = 'set') <> 2 or (select count(*) from public.founder_settings_baseline where rule = 'max') <> 3 then raise exception 'the E113 rules changed'; end if;
    if exists (select 1 from public.founder_settings_baseline b where b.rule = 'value' and (not exists (select 1 from public.founder_setting_registry r where r.key = b.key)
        or not public._founder_setting_valid(b.key, b.safe_value))) then raise exception 'a value rule points at nothing or at an invalid safe value'; end if;
    if public._fs_fails($q$insert into public.founder_settings_baseline (key, source, rule, recommended, safe_value, label, why, sort) values ('x.bad','setting','value',5,'true'::jsonb,'l','w',1)$q$) is not true then raise exception 'a value rule with a recommended number was accepted'; end if;
    if public._fs_fails($q$insert into public.founder_settings_baseline (key, source, rule, recommended, safe_value, label, why, sort) values ('x.bad2','setting','value',null,null,'l','w',1)$q$) is not true then raise exception 'a value rule without a safe value was accepted'; end if;
    r := r || 'structure OK; ';

    -- defaults: with nothing stored every value item is aligned (the registry defaults ARE the safe values)
    j := public.founder_settings_drift(u);
    for k in select key from public.founder_settings_baseline where rule = 'value' loop
      st := (select e ->> 'state' from jsonb_array_elements(j -> 'items') e where e ->> 'key' = k);
      if st is distinct from 'aligned' then raise exception '% must be aligned at its default, got %', k, st; end if;
    end loop;
    n_items := jsonb_array_length(j -> 'items');
    if (j ->> 'aligned')::integer + (j ->> 'loose')::integer + (j ->> 'risky')::integer <> n_items then raise exception 'drift counts do not add up'; end if;
    r := r || 'defaults aligned OK; ';

    -- turning a safe setting off drifts it: passkey -> risky, the other four -> loose; the score falls; turning it back restores it
    perform public.founder_setting_set(u, 'workspace.require_passkey', to_jsonb(false));
    j2 := public.founder_settings_drift(u);
    if (select e ->> 'state' from jsonb_array_elements(j2 -> 'items') e where e ->> 'key' = 'workspace.require_passkey') <> 'risky' then raise exception 'passkey off must be risky'; end if;
    if (j2 ->> 'score')::integer >= (j ->> 'score')::integer then raise exception 'score must fall when passkey is off'; end if;
    if (select e -> 'current' from jsonb_array_elements(j2 -> 'items') e where e ->> 'key' = 'workspace.require_passkey') <> 'false'::jsonb
       or (select e -> 'recommended' from jsonb_array_elements(j2 -> 'items') e where e ->> 'key' = 'workspace.require_passkey') <> 'true'::jsonb then raise exception 'drift must show current and recommended'; end if;
    foreach k in array array['workspace.flag_external','personal.send_check','notifications.quiet_hours','privacy.block_trackers'] loop
      perform public.founder_setting_set(u, k, to_jsonb(false));
      st := (select e ->> 'state' from jsonb_array_elements(public.founder_settings_drift(u) -> 'items') e where e ->> 'key' = k);
      if st is distinct from 'loose' then raise exception '% off must be loose, got %', k, st; end if;
    end loop;
    if (public.founder_settings_drift(u) ->> 'risky')::integer < 1 or (public.founder_settings_drift(u) ->> 'loose')::integer < 4 then raise exception 'counts after five drifts'; end if;
    perform public.founder_setting_set(u, 'workspace.require_passkey', null);        -- null = back to the default (true)
    if (select e ->> 'state' from jsonb_array_elements(public.founder_settings_drift(u) -> 'items') e where e ->> 'key' = 'workspace.require_passkey') <> 'aligned' then raise exception 'passkey back to default must be aligned'; end if;
    perform public.founder_setting_set(u, 'privacy.block_trackers', to_jsonb(true));  -- an explicit safe value is aligned too
    if (select e ->> 'state' from jsonb_array_elements(public.founder_settings_drift(u) -> 'items') e where e ->> 'key' = 'privacy.block_trackers') <> 'aligned' then raise exception 'explicit true must be aligned'; end if;
    r := r || 'drift and restore OK; ';

    -- unmeasured choices stay unmeasured: undo window, retention and only-VIPs never appear in drift
    if exists (select 1 from jsonb_array_elements(public.founder_settings_drift(u) -> 'items') e where e ->> 'key' in ('personal.undo_send','workspace.retention_days','notifications.only_vips')) then raise exception 'a choice was measured as drift'; end if;
    r := r || 'choices not measured OK; ';

    -- explain shows the recommended value; a key without a baseline shows null
    j := public.founder_setting_explain('workspace.require_passkey');
    if j -> 'recommended' <> 'true'::jsonb or j ->> 'why_recommended' is null then raise exception 'explain must show the recommended value: %', j; end if;
    if public.founder_setting_explain('personal.undo_send') ->> 'recommended' is not null then raise exception 'undo_send has no baseline'; end if;
    if public.founder_setting_explain('personal.home') ->> 'recommended' <> 'set' then raise exception 'the E113 explain for a set rule changed'; end if;
    r := r || 'explain OK; ';

    if public.founder_settings_replay_check(u) is not null then raise exception 'replay check dirty'; end if;
    if public.founder_audit_verify(1) is not null then raise exception 'audit chain broken'; end if;
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E116 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_settings) <> b_set or (select count(*) from public.founder_settings_history) <> b_hist or (select count(*) from public.founder_audit) <> b_audit
     or (select count(*) from public.founder_settings_revert_log) <> b_rev or (select count(*) from public.founder_settings_schedule) <> b_sch then
    raise exception 'E116 selftest left rows behind';
  end if;
  return 'E116 selftest OK — ' || r || 'rollback clean';
end $$;
revoke all on function public.founder_drift_value_selftest() from public, anon, authenticated;
grant execute on function public.founder_drift_value_selftest() to service_role;

-- 6) E113's behaviour selftest starts with a raw "delete from founder_settings". That is only correct while the account holds nothing but the five E108 keys:
--    as soon as the founder has saved any other key from the Settings page, the history replay disagrees with the emptied table and the selftest (and every CHECK that calls it) fails.
--    Same test, same checks, with the one setup line replaced by a registry-wide reset through the write door. (E113 itself is untouched: the server keeps a sha ledger.)
create or replace function public.founder_settings_s2_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare
  k_ text; u uuid; r text := ''; j jsonb; j2 jsonb; hid bigint; hid2 bigint; sid uuid; sid2 uuid; sid3 uuid; sid4 uuid; v_n integer; t0 timestamptz := now();
  b_set bigint; b_hist bigint; b_audit bigint; b_rev bigint; b_sch bigint; b_pol public.founder_audit_merkle_policy%rowtype;
begin
  select user_id into u from public.founder_accounts limit 1;
  if u is null then return 'E113 selftest SKIP — no founder account'; end if;
  select count(*) into b_set from public.founder_settings; select count(*) into b_hist from public.founder_settings_history; select count(*) into b_audit from public.founder_audit;
  select count(*) into b_rev from public.founder_settings_revert_log; select count(*) into b_sch from public.founder_settings_schedule;
  begin
    -- E116: no raw delete of the live table. On an account that already holds real values (any registry key, e.g. one set from the Settings page) the history replay
    -- would then list keys the table no longer has. Every key goes back to its default through the real write door instead, which records each step (all rolled back below).
    for k_ in select key from public.founder_setting_registry order by key loop
      perform public.founder_setting_set(u, k_, null);
    end loop;

    -- registries
    if (select count(*) from public.founder_settings_info) < 5 then raise exception 'info registry incomplete'; end if;
    if (select count(*) from public.founder_settings_baseline) < 5 then raise exception 'baseline registry incomplete'; end if;
    j := public.founder_setting_explain('personal.home');
    if j ->> 'label' <> 'Home city' or j ->> 'recommended' <> 'set' then raise exception 'explain wrong: %', j; end if;
    if not public._fs_fails($q$select public.founder_setting_explain('nope.key')$q$) then raise exception 'explain accepted an unknown key'; end if;
    r := r || 'registries+explain OK; ';

    -- blast radius: real counts
    j := public.founder_setting_blast(u, 'appearance.graphics');
    if (j ->> 'devices_affected')::integer <> (select count(*) from public.founder_devices where user_id = u and approved_at is not null and revoked_at is null) then raise exception 'blast device count wrong'; end if;
    if jsonb_array_length(j -> 'surfaces') < 1 or j ->> 'severity' <> 'low' then raise exception 'blast shape wrong: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_setting_blast(%L, 'appearance.graphics')$q$, gen_random_uuid())) then raise exception 'blast for a non-founder'; end if;
    r := r || 'blast OK; ';

    -- drift: nothing set -> two loose
    j := public.founder_settings_drift(u);
    if (select count(*) from jsonb_array_elements(j -> 'items') e where e ->> 'key' in ('personal.display_name','personal.home') and e ->> 'state' = 'loose') <> 2 then raise exception 'drift: unset name/home must be loose: %', j; end if;
    if (j ->> 'score')::integer not between 0 and 100 then raise exception 'drift score range'; end if;
    perform public.founder_setting_set(u, 'personal.display_name', to_jsonb('Drift Tester'::text));
    perform public.founder_setting_set(u, 'personal.home', jsonb_build_object('city','Lahore','country','Pakistan','iana','Asia/Karachi','lat',31.52,'lon',74.36));
    j2 := public.founder_settings_drift(u);
    if (select count(*) from jsonb_array_elements(j2 -> 'items') e where e ->> 'key' in ('personal.display_name','personal.home') and e ->> 'state' = 'aligned') <> 2 then raise exception 'drift: set name/home must be aligned'; end if;
    if (j2 ->> 'score')::integer <= (j ->> 'score')::integer then raise exception 'drift score must improve after setting name and home'; end if;
    r := r || 'drift settings OK; ';

    -- drift: ledger policy (read from E107)
    select * into b_pol from public.founder_audit_merkle_policy where id;
    perform public.founder_audit_merkle_policy_set(u, 600, 700, 2500, 'drift selftest policy change');
    j := public.founder_settings_drift(u);
    if (select e ->> 'state' from jsonb_array_elements(j -> 'items') e where e ->> 'key' = 'audit.merkle.every_rows') <> 'risky' then raise exception 'every_rows 600 must be risky'; end if;
    if (select e ->> 'state' from jsonb_array_elements(j -> 'items') e where e ->> 'key' = 'audit.merkle.warn_lag_rows') <> 'loose' then raise exception 'warn 700 must be loose'; end if;
    if (select e ->> 'state' from jsonb_array_elements(j -> 'items') e where e ->> 'key' = 'audit.merkle.fail_lag_rows') <> 'loose' then raise exception 'fail 2500 must be loose'; end if;
    perform public.founder_audit_merkle_policy_set(u, b_pol.every_rows, b_pol.warn_lag_rows, b_pol.fail_lag_rows, 'drift selftest policy restore');
    j := public.founder_settings_drift(u);
    if (select e ->> 'state' from jsonb_array_elements(j -> 'items') e where e ->> 'key' = 'audit.merkle.every_rows') <> 'aligned' then raise exception 'policy restore must be aligned again'; end if;
    if public._fs_drift_score(2, 2, 0) <> 75 or public._fs_drift_score(0, 0, 3) <> 0 or public._fs_drift_score(4, 0, 0) <> 100 then raise exception 'drift score maths'; end if;
    r := r || 'drift policy+score OK; ';

    -- time machine: versions + undo
    perform public.founder_setting_set(u, 'appearance.graphics', to_jsonb(true));
    perform public.founder_setting_set(u, 'appearance.graphics', to_jsonb(false));
    hid := public._fs_last_history_id(u, 'appearance.graphics');
    j := public.founder_settings_history_list(u, 'appearance.graphics', null, 10);
    if jsonb_array_length(j -> 'items') <> 2 or (j -> 'items' -> 0 ->> 'id')::bigint <> hid then raise exception 'history list wrong: %', j; end if;
    if (j -> 'items' -> 0 ->> 'can_undo')::boolean is not true or (j -> 'items' -> 0 ->> 'reverted')::boolean then raise exception 'newest version must be undoable'; end if;
    if (j -> 'items' -> 0 ->> 'audit_seq') is null then raise exception 'history item has no audit seq'; end if;
    if public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'short')$q$, u, hid)) is not true then raise exception 'revert accepted a 5-char reason'; end if;
    j := public.founder_setting_revert(u, hid, 'selftest undo graphics');
    if (j ->> 'changed')::boolean is not true or (public._fs_current(u, 'appearance.graphics')) <> to_jsonb(true) then raise exception 'undo did not restore true: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'selftest undo twice')$q$, u, hid)) then raise exception 'a version was undone twice'; end if;
    j := public.founder_settings_history_list(u, 'appearance.graphics', null, 10);
    if (select count(*) from jsonb_array_elements(j -> 'items') e where (e ->> 'reverted')::boolean) <> 1 then raise exception 'reverted flag not shown'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, 999999999, 'selftest unknown version')$q$, u)) then raise exception 'unknown version undone'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'selftest wrong founder')$q$, gen_random_uuid(), hid)) then raise exception 'non-founder undid a version'; end if;
    r := r || 'undo OK; ';

    -- undo back to default (first ever change of a key)
    perform public.founder_setting_set(u, 'appearance.sidebar_slim', to_jsonb(true));
    hid2 := public._fs_last_history_id(u, 'appearance.sidebar_slim');
    j := public.founder_setting_revert(u, hid2, 'selftest back to default');
    if (j ->> 'now_default')::boolean is not true or public.founder_settings_get(u) ? 'appearance.sidebar_slim' then raise exception 'undo to default failed'; end if;
    -- undoing the undo is a legitimate new version: it brings the earlier value back, and is itself undoable once
    j := public.founder_setting_revert(u, public._fs_last_history_id(u, 'appearance.sidebar_slim'), 'selftest undo of the undo');
    if (j ->> 'now_default')::boolean or public._fs_current(u, 'appearance.sidebar_slim') <> to_jsonb(true) then raise exception 'undo of the undo did not bring true back'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'selftest first version twice')$q$, u, hid2)) then raise exception 'the first version was undone twice'; end if;
    r := r || 'undo-to-default OK; ';

    -- avatar can never be reverted from history
    perform public.founder_setting_set(u, 'personal.avatar', to_jsonb('data:image/png;base64,iVBORw0KGgo='::text));
    if not public._fs_fails(format($q$select public.founder_setting_revert(%L, %s, 'selftest avatar revert')$q$, u, public._fs_last_history_id(u, 'personal.avatar'))) then raise exception 'avatar was reverted'; end if;
    j := public.founder_settings_history_list(u, 'personal.avatar', null, 5);
    if (j -> 'items' -> 0 ->> 'hash_only')::boolean is not true or j -> 'items' -> 0 -> 'to' <> 'null'::jsonb or (j -> 'items' -> 0 ->> 'can_undo')::boolean then raise exception 'avatar history must be hash-only and not undoable'; end if;
    r := r || 'avatar guard OK; ';

    -- replay must equal live; tamper must be caught
    if public.founder_settings_replay_check(u) is not null then raise exception 'replay check dirty: %', public.founder_settings_replay_check(u); end if;
    if public.founder_settings_crosscheck(u) not like 'E113 crosscheck OK%' then raise exception 'crosscheck: %', public.founder_settings_crosscheck(u); end if;
    update public.founder_settings set value = to_jsonb(false) where user_id = u and key = 'appearance.graphics';   -- bypasses the door on purpose
    if public.founder_settings_replay_check(u) is null then raise exception 'replay check missed a tampered value'; end if;
    update public.founder_settings set value = to_jsonb(true) where user_id = u and key = 'appearance.graphics';
    if public.founder_settings_replay_check(u) is not null then raise exception 'replay check still dirty after fixing'; end if;
    r := r || 'replay+tamper OK; ';

    -- point in time (backdated rows are inserted directly; history allows insert, never update)
    insert into public.founder_settings_history (user_id, key, old_hash, new_hash, old_value, new_value, changed_at)
      values (u, 'appearance.sidebar_slim', null, public._fs_hash(to_jsonb(true)), null, to_jsonb(true), t0 - interval '3 days');
    insert into public.founder_settings_history (user_id, key, old_hash, new_hash, old_value, new_value, changed_at)
      values (u, 'appearance.sidebar_slim', public._fs_hash(to_jsonb(true)), null, to_jsonb(true), null, t0 - interval '1 day');
    j := public.founder_settings_at(u, t0 - interval '2 days');
    if j -> 'settings' -> 'appearance.sidebar_slim' <> to_jsonb(true) then raise exception 'time travel: 2 days ago sidebar_slim must be true: %', j; end if;
    j := public.founder_settings_at(u, t0 - interval '4 days');
    if j -> 'settings' ? 'appearance.sidebar_slim' then raise exception 'time travel: 4 days ago nothing was set'; end if;
    j := public.founder_settings_at(u, t0 - interval '12 hours');
    if j -> 'settings' ? 'appearance.sidebar_slim' then raise exception 'time travel: after the reset the key is back to default'; end if;
    j := public.founder_settings_diff(u, t0 - interval '4 days', t0 - interval '2 days');
    if jsonb_array_length(j -> 'changes') <> 1 or j -> 'changes' -> 0 ->> 'key' <> 'appearance.sidebar_slim' then raise exception 'diff wrong: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_settings_diff(%L, now(), now() - interval '1 day')$q$, u)) then raise exception 'diff accepted a reversed range'; end if;
    r := r || 'point-in-time+diff OK; ';

    -- timeline carries all kinds
    j := public.founder_settings_timeline(u, 100);
    if jsonb_array_length(j) < 6 or not exists (select 1 from jsonb_array_elements(j) e where e ->> 'kind' = 'revert') then raise exception 'timeline incomplete'; end if;
    r := r || 'timeline OK; ';

    -- scheduling: validation
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', 'false'::jsonb, now() + interval '30 seconds', null, 'selftest too soon')$q$, u)) then raise exception 'schedule accepted <1 min'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', 'false'::jsonb, now() + interval '91 days', null, 'selftest too far')$q$, u)) then raise exception 'schedule accepted >90 days'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', '"x"'::jsonb, now() + interval '5 minutes', null, 'selftest bad value')$q$, u)) then raise exception 'schedule accepted a bad value'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'personal.avatar', '"https://x.y/a.png"'::jsonb, now() + interval '5 minutes', null, 'selftest avatar')$q$, u)) then raise exception 'schedule accepted the avatar'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'nope.key', 'true'::jsonb, now() + interval '5 minutes', null, 'selftest unknown')$q$, u)) then raise exception 'schedule accepted an unknown key'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', 'false'::jsonb, now() + interval '5 minutes', 3, 'selftest short rollback')$q$, u)) then raise exception 'schedule accepted a 3-minute rollback'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', 'false'::jsonb, now() + interval '5 minutes', null, 'short')$q$, u)) then raise exception 'schedule accepted a short reason'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.graphics', 'false'::jsonb, now() + interval '5 minutes', null, 'selftest non founder')$q$, gen_random_uuid())) then raise exception 'non-founder scheduled'; end if;
    r := r || 'schedule validation OK; ';

    -- schedule: cancel path
    j := public.founder_settings_schedule_create(u, 'appearance.graphics', 'false'::jsonb, now() + interval '5 minutes', null, 'selftest cancel path');
    sid := (j ->> 'id')::uuid;
    j := public.founder_settings_schedule_cancel(u, sid, 'selftest cancel it');
    if j ->> 'state' <> 'cancelled' then raise exception 'cancel failed'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_cancel(%L, %L, 'selftest cancel twice')$q$, u, sid)) then raise exception 'cancelled twice'; end if;
    if public._fs_fails(format($q$update public.founder_settings_schedule set state = 'scheduled' where id = %L$q$, sid)) is not true then raise exception 'a cancelled row went back to scheduled'; end if;
    r := r || 'cancel OK; ';

    -- schedule: apply then auto-rollback (value true -> false -> back to true)
    j := public.founder_settings_schedule_create(u, 'appearance.graphics', 'false'::jsonb, now() + interval '2 minutes', 10, 'selftest rollback path');
    sid := (j ->> 'id')::uuid;
    j := public.founder_settings_schedule_preview(now() + interval '3 minutes');
    if (j ->> 'due_to_apply')::integer <> 1 then raise exception 'preview must see 1 due: %', j; end if;
    j := public.founder_settings_schedule_tick(now() + interval '1 minute');
    if (j ->> 'applied')::integer <> 0 then raise exception 'tick applied too early: %', j; end if;
    j := public.founder_settings_schedule_tick(now() + interval '3 minutes');
    if (j ->> 'applied')::integer <> 1 or public._fs_current(u, 'appearance.graphics') <> to_jsonb(false) then raise exception 'tick did not apply: %', j; end if;
    if (select state from public.founder_settings_schedule where id = sid) <> 'applied' then raise exception 'state should be applied'; end if;
    j := public.founder_settings_schedule_tick(now() + interval '5 minutes');
    if (j ->> 'rolled_back')::integer <> 0 then raise exception 'rolled back before the timer'; end if;
    j := public.founder_settings_schedule_tick(now() + interval '20 minutes');
    if (j ->> 'rolled_back')::integer <> 1 or public._fs_current(u, 'appearance.graphics') <> to_jsonb(true) then raise exception 'auto-rollback did not restore true: %', j; end if;
    if (select state from public.founder_settings_schedule where id = sid) <> 'rolled_back' then raise exception 'state should be rolled_back'; end if;
    j := public.founder_settings_schedule_tick(now() + interval '40 minutes');
    if (j ->> 'rolled_back')::integer <> 0 or (j ->> 'applied')::integer <> 0 then raise exception 'tick is not idempotent: %', j; end if;
    r := r || 'apply+auto-rollback OK; ';

    -- schedule: confirm keeps the change
    j := public.founder_settings_schedule_create(u, 'appearance.graphics', 'false'::jsonb, now() + interval '2 minutes', 10, 'selftest confirm path');
    sid2 := (j ->> 'id')::uuid;
    perform public.founder_settings_schedule_tick(now() + interval '3 minutes');
    j := public.founder_settings_schedule_confirm(u, sid2, 'selftest keep this one');
    if j ->> 'state' <> 'confirmed' then raise exception 'confirm failed'; end if;
    j := public.founder_settings_schedule_tick(now() + interval '60 minutes');
    if public._fs_current(u, 'appearance.graphics') <> to_jsonb(false) then raise exception 'confirmed change was rolled back'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_confirm(%L, %L, 'selftest confirm again')$q$, u, sid2)) then raise exception 'confirmed twice'; end if;
    r := r || 'confirm OK; ';

    -- schedule: a newer manual change wins (superseded, never overwritten)
    perform public.founder_setting_set(u, 'appearance.graphics', to_jsonb(true));
    j := public.founder_settings_schedule_create(u, 'appearance.graphics', 'false'::jsonb, now() + interval '2 minutes', 10, 'selftest superseded path');
    sid3 := (j ->> 'id')::uuid;
    perform public.founder_settings_schedule_tick(now() + interval '3 minutes');
    perform public.founder_setting_set(u, 'appearance.graphics', to_jsonb(true));                 -- founder changes it again before the timer
    j := public.founder_settings_schedule_tick(now() + interval '30 minutes');
    if (j ->> 'superseded')::integer <> 1 or public._fs_current(u, 'appearance.graphics') <> to_jsonb(true) then raise exception 'rollback overwrote a newer value: %', j; end if;
    r := r || 'superseded OK; ';

    -- schedule: no-op and permanent
    j := public.founder_settings_schedule_create(u, 'appearance.graphics', 'true'::jsonb, now() + interval '2 minutes', 10, 'selftest already set');
    sid4 := (j ->> 'id')::uuid;
    j := public.founder_settings_schedule_tick(now() + interval '3 minutes');
    if (j ->> 'already_set')::integer <> 1 or (select state from public.founder_settings_schedule where id = sid4) <> 'confirmed' then raise exception 'no-op schedule wrong: %', j; end if;
    j := public.founder_settings_schedule_create(u, 'appearance.sidebar_slim', 'false'::jsonb, now() + interval '2 minutes', null, 'selftest permanent path');
    sid4 := (j ->> 'id')::uuid;
    perform public.founder_settings_schedule_tick(now() + interval '3 minutes');
    perform public.founder_settings_schedule_tick(now() + interval '9 days');
    if public._fs_current(u, 'appearance.sidebar_slim') <> to_jsonb(false) or (select state from public.founder_settings_schedule where id = sid4) <> 'applied' then raise exception 'permanent schedule changed after the tick'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_confirm(%L, %L, 'selftest nothing to confirm')$q$, u, sid4)) then raise exception 'confirmed a permanent change'; end if;
    r := r || 'no-op+permanent OK; ';

    -- schedule: list + guards
    j := public.founder_settings_schedule_list(u, 50);
    if jsonb_array_length(j) < 6 then raise exception 'schedule list short: %', jsonb_array_length(j); end if;
    if public._fs_fails(format($q$delete from public.founder_settings_schedule where id = %L$q$, sid)) is not true then raise exception 'schedule row deleted'; end if;
    if public._fs_fails(format($q$update public.founder_settings_schedule set new_value = 'true'::jsonb where id = %L$q$, sid3)) is not true then raise exception 'request edited after creation'; end if;
    if public._fs_fails('truncate public.founder_settings_schedule') is not true then raise exception 'schedule truncated'; end if;
    if public._fs_fails('truncate public.founder_settings_revert_log') is not true then raise exception 'revert log truncated'; end if;
    if public._fs_fails('update public.founder_settings_revert_log set reason = ''xxxxxxxxxx''') is not true then raise exception 'revert log updated'; end if;
    -- open-schedule limit
    for v_n in 1..20 loop
      perform public.founder_settings_schedule_create(u, 'appearance.sidebar_slim', 'false'::jsonb, now() + interval '5 days', null, 'selftest limit ' || v_n);
    end loop;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.sidebar_slim', 'false'::jsonb, now() + interval '5 days', null, 'selftest limit over')$q$, u)) then raise exception 'open schedule limit not enforced'; end if;
    r := r || 'list+guards+limit OK; ';

    -- pulse
    j := public.founder_settings_pulse(u);
    if (j ->> 'versions_total')::integer < 8 or (j ->> 'pending_scheduled')::integer < 20 or (j ->> 'reverts_7d')::integer < 2 then raise exception 'pulse counts wrong: %', j; end if;
    if (j ->> 'drift_score')::integer not between 0 and 100 then raise exception 'pulse drift'; end if;
    r := r || 'pulse OK; ';

    -- audit chain still clean, new action names present
    if public.founder_audit_verify(1) is not null then raise exception 'audit chain broken'; end if;
    if (select count(distinct action) from public.founder_audit where action in ('settings.revert','settings.schedule.create','settings.schedule.apply','settings.schedule.rollback','settings.schedule.confirm','settings.schedule.cancel')) <> 6 then
      raise exception 'expected 6 new audit actions, got %', (select count(distinct action) from public.founder_audit where action like 'settings.%');
    end if;
    r := r || 'audit chain+actions OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E113 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_settings) <> b_set or (select count(*) from public.founder_settings_history) <> b_hist or (select count(*) from public.founder_audit) <> b_audit
     or (select count(*) from public.founder_settings_revert_log) <> b_rev or (select count(*) from public.founder_settings_schedule) <> b_sch then
    raise exception 'E113 selftest left rows behind';
  end if;
  return 'E113 selftest OK — ' || r || 'rollback clean';
end $$;

do $$ begin
  raise notice '%', public.founder_drift_value_selftest();
  raise notice '%', public.founder_settings_s2_selftest();
  raise notice '%', public.founder_settings_s1c_selftest();
end $$;

-- RUNBOOK (comments only)
-- Run:   bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E116_founder_drift_value_rule CHECK_E116   (after the usual fetch). Order: ... E114 -> E115 -> E116. Safe to run again.
-- UI:    Drift lists the five new items when they differ; the Schedule form offers every schedulable setting (booleans and the closed lists).
-- Undo:  delete the 5 baseline rows with rule 'value'; re-run E113 section 6 (drift) and section 7 (explain); drop the two added columns.
